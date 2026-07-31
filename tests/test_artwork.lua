local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse, assertNear =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNear
local R, Canvas, C, Util, Art = NS.Registry, NS.Canvas, NS.Constants, NS.Util, NS.Artwork

-- The art list itself, aliased once. Bound by REFERENCE, so the fixture helper below appends to the
-- real table rather than to a copy — which is the whole point, since the lookup under test rescans
-- that table on every call.
local Catalog = Art.Catalog

local function fresh()
  T.mocks.__inCombat = false
  NS.Unlock:SetUnlocked(false)
  R:DeleteAll()
  Canvas:RenderAll()
end

-- ── Fixtures ────────────────────────────────────────────────────────────────────

-- A record with the shipped defaults under it. Building the fill cases from a bare `{ artFill = }`
-- table would test a record shape the addon never actually produces — Sanitize guarantees every
-- field is present — and would quietly make each case depend on BuildArtSpec's own fallbacks
-- instead of on the arithmetic under test.
local function record(overrides)
  local rec = Util.DeepCopy(C.PANEL_TEMPLATE)
  for k, v in pairs(overrides or {}) do rec[k] = v end
  return rec
end

-- Append catalog rows for the duration of one test.
--
-- Appending at runtime is the extension path the catalog exists to offer — Artwork.Entry rescans
-- on every call rather than caching an index, precisely so an art pack loading later still resolves
-- — so a fixture row is exercising the real lookup, not a back door around it.
--
-- The rows come off again even when the body throws, or every catalog test after this one would
-- inherit a fixture as though it were shipped art.
local function withRows(rows, fn)
  local base = #Catalog
  for _, row in ipairs(rows) do Catalog[#Catalog + 1] = row end
  local ok, err = pcall(fn)
  for i = #Catalog, base + 1, -1 do Catalog[i] = nil end
  if not ok then error(err, 0) end
end

-- One fixture row of a given native size. The shipped catalog is a single 512x512 piece, and a
-- fill matrix that only ever sees square art proves almost nothing: FIT and FILL agree EXACTLY
-- whenever the panel and the art share an aspect, which is the one case where the branch under test
-- never runs. Non-square art on both sides is what separates them.
--
-- `file` points at the real shipped .tga so that a fixture which somehow escaped cleanup would fail
-- the uniqueness check — a loud, accurate failure — rather than the on-disk check with a confusing
-- complaint about a file nobody ever shipped.
local TEST_ART_ID = "pm-test-art"
local function withArt(w, h, tintable, fn)
  withRows({ { id = TEST_ART_ID, category = "General", label = "Test Art", file = "runic-sigil-bw",
               w = w, h = h, tintable = tintable, credit = "test fixture" } }, fn)
end

-- Wide, tall and square on both sides of the math. Nine combinations per fill is the whole cross
-- product, and it is the only shape of test that catches an aspect branch taken the wrong way
-- round: a wide panel holding tall art and a tall panel holding wide art crop on OPPOSITE axes, and
-- a bug that swaps them looks perfectly correct on every square case.
local PANELS = {
  { name = "wide panel",   W = 400, H = 100 },
  { name = "tall panel",   W = 100, H = 400 },
  { name = "square panel", W = 200, H = 200 },
}
local ARTS = {
  { name = "wide art",   w = 512, h = 128 },
  { name = "tall art",   w = 128, h = 512 },
  { name = "square art", w = 256, h = 256 },
}

-- Run `fn(spec, panel, art, where)` once per panel x art combination at one fill. `where` names the
-- combination, because a bare "expected 400, got 100" out of a nine-case loop says nothing about
-- WHICH case broke — and the aspect bugs this matrix exists to catch always break a subset.
local function forEachCombo(fill, overrides, fn)
  for _, p in ipairs(PANELS) do
    for _, a in ipairs(ARTS) do
      withArt(a.w, a.h, true, function()
        local rec = record(overrides)
        rec.artTexture = TEST_ART_ID
        rec.artFill = fill
        local where = (" [%s: %s / %s]"):format(fill, p.name, a.name)
        local spec = Art.BuildArtSpec(rec, p.W, p.H)
        assertTrue(spec ~= nil, "no spec at all" .. where)
        fn(spec, p, a, where)
      end)
    end
  end
end

-- A spec for one panel size, with the shipped square catalog piece unless a fixture is in scope.
local function specFor(overrides, W, H)
  return Art.BuildArtSpec(record(overrides), W or 200, H or 200)
end

-- The crop rectangle a spec carries, un-flipped and un-rotated. The uv list is emitted flat in
-- SetTexCoord's own UL, LL, UR, LR order, so u0/v0 sit at the head and u1/v1 at the tail.
local function cropOf(spec)
  return spec.uv[1], spec.uv[2], spec.uv[5], spec.uv[4]   -- u0, v0, u1, v1
end

local function assertUV(got, want, msg)
  for i = 1, 8 do
    assertNear(got[i], want[i], 1e-9, (msg or "uv") .. " component " .. i)
  end
end

local RUNIC = C.ARTWORK_PATH_PREFIX .. "runic-sigil-bw.tga"

-- ── Catalog ─────────────────────────────────────────────────────────────────────

test("Artwork: every catalog id is unique", function()
  -- An id is the STORED value. Two rows sharing one means the second is unreachable forever and the
  -- panel that picked it silently renders the first — a duplicate that only shows up as "my artwork
  -- is wrong" with nothing to point at.
  local seen = {}
  for _, row in ipairs(Catalog) do
    assertEqual(seen[row.id], nil, "duplicate catalog id: " .. tostring(row.id))
    seen[row.id] = true
  end
end)

test("Artwork: no catalog row claims one of the two reserved ids", function()
  for _, row in ipairs(Catalog) do
    assertTrue(row.id ~= C.ARTWORK_NONE and row.id ~= C.ARTWORK_CUSTOM,
      "a catalog row shadows a reserved id: " .. tostring(row.id))
  end
end)

test("Artwork: every catalog row sits in a declared category", function()
  -- Categories are the dropdown's grouping order. A row in an undeclared one still sorts (last)
  -- rather than erroring, so nothing else would ever report it.
  for _, row in ipairs(Catalog) do
    assertTrue(C.ARTWORK_CATEGORY_SET[row.category] == true,
      ("row '%s' has category '%s'"):format(tostring(row.id), tostring(row.category)))
  end
end)

test("Artwork: every catalog row declares the fields the fill math needs", function()
  -- w/h are declared rather than measured because Texture:GetWidth() reads 0 until the file has
  -- loaded. A row missing them would make STATIC, FIT and TILE uncomputable — which BuildArtSpec
  -- degrades to "draw nothing", i.e. bundled art that silently never appears.
  for _, row in ipairs(Catalog) do
    local at = " on row " .. tostring(row.id)
    assertEqual(type(row.file), "string", "file" .. at)
    assertEqual(type(row.label), "string", "label" .. at)
    assertTrue(type(row.w) == "number" and row.w > 0, "w" .. at)
    assertTrue(type(row.h) == "number" and row.h > 0, "h" .. at)
    -- Redistribution needs the attribution, and the only moment anybody will remember to write it
    -- is when the row is added.
    assertEqual(type(row.credit), "string", "credit" .. at)
  end
end)

test("Artwork: every catalog row's derived path points at a file that exists", function()
  -- The whole "store an id, derive the path" bargain rests on the file actually being there. A
  -- catalog row for art that was never committed renders as nothing in-game with no error, which
  -- is indistinguishable from the user having picked None.
  --
  -- Read back through BuildArtSpec rather than a helper of its own, so the derivation being checked
  -- is the one the RENDERER actually uses. A dedicated accessor existed for exactly this and had no
  -- other caller, which made it a second path to the same answer — free to drift from the real one.
  for _, row in ipairs(Catalog) do
    local spec = Art.BuildArtSpec(record({ artTexture = row.id }), 200, 200)
    assertTrue(spec ~= nil, "no spec for catalog row " .. tostring(row.id))
    local path = spec.path
    assertEqual(path, C.ARTWORK_PATH_PREFIX .. row.file .. ".tga", "derived path for " .. row.id)
    -- The stored path is a WoW virtual path; the repo copy is the same tail with forward slashes.
    local onDisk = path:gsub("^Interface\\AddOns\\PanelMaster\\", ""):gsub("\\", "/")
    local fh = io.open(onDisk, "rb")
    assertTrue(fh ~= nil, "catalog row '" .. row.id .. "' points at a missing file: " .. onDisk)
    if fh then fh:close() end
  end
end)

test("Artwork: the shipped seed row is the runic sigil, tintable and square", function()
  local row = Art.Entry("runic-sigil-bw")
  assertTrue(row ~= nil, "the seed catalog row is gone")
  assertEqual(row.category, "General")
  assertEqual(row.w, 512)
  assertEqual(row.h, 512)
  -- Authored white-on-transparent, so the per-panel tint is what gives it its color.
  assertTrue(row.tintable)
end)

test("Artwork.Entry: finds a row by id and forgives its case", function()
  -- The CLI is the reason: `/pm panel set Art runic-Sigil` should find the row rather than refuse
  -- it, mirroring how the media field kind already forgives case.
  assertEqual(Art.Entry("runic-sigil-bw").id, "runic-sigil-bw")
  assertEqual(Art.Entry("RUNIC-SIGIL-BW").id, "runic-sigil-bw")
  assertEqual(Art.Entry("nope"), nil)
  assertEqual(Art.Entry(nil), nil)
  assertEqual(Art.Entry(42), nil)
end)

test("Artwork.List: brackets the catalog with None first and Custom last", function()
  -- Neither reserved entry is art: one is the off switch, the other an escape hatch. A user
  -- scanning for either wants it at a predictable end, not sorted in among the G's.
  local list = Art.List()
  assertEqual(list[1].id, C.ARTWORK_NONE)
  assertEqual(list[1].label, "None")
  assertEqual(list[#list].id, C.ARTWORK_CUSTOM)
  assertEqual(#list, #Catalog + 2)
end)

test("Artwork.List: a catalog label carries its category as a prefix", function()
  -- The widget is a FLAT list, so the prefix is what keeps it readable until there is enough art to
  -- justify a grouped one.
  local list = Art.List()
  local found
  for _, entry in ipairs(list) do
    if entry.id == "runic-sigil-bw" then found = entry end
  end
  assertTrue(found ~= nil, "the seed row is missing from the list")
  assertEqual(found.label, "General: Runic Sigil (B&W)")
  assertEqual(found.category, "General")
end)

test("Artwork.List: orders the catalog by category, then by label", function()
  withRows({
    { id = "zzz-general", category = "General",  label = "Zebra", file = "runic-sigil-bw",
      w = 8, h = 8, tintable = true, credit = "test fixture" },
    { id = "aaa-factions", category = "Factions", label = "Aardvark", file = "runic-sigil-bw",
      w = 8, h = 8, tintable = true, credit = "test fixture" },
  }, function()
    local order = {}
    for i, entry in ipairs(Art.List()) do order[entry.id] = i end
    -- General outranks Factions on the CATEGORY, even though the labels sort the other way — which
    -- is the whole point of ranking by C.ARTWORK_CATEGORIES rather than sorting the label strings.
    assertTrue(order["zzz-general"] < order["aaa-factions"], "category order lost to label order")
    -- And within one category, the label decides.
    assertTrue(order["runic-sigil-bw"] < order["zzz-general"], "labels are not sorted within category")
  end)
end)

-- ── Fill: FIT ───────────────────────────────────────────────────────────────────

test("Artwork FIT: the whole image lands inside the panel at every aspect pairing", function()
  forEachCombo("FIT", nil, function(spec, p, a, where)
    -- Contain: never larger than the panel on either axis. A FIT that overflows has cropped
    -- something, which is FILL's job, not this one's.
    assertTrue(spec.width  <= p.W + 1e-9, "overflows horizontally" .. where)
    assertTrue(spec.height <= p.H + 1e-9, "overflows vertically" .. where)
    -- And the aspect survives, or the art is distorted, which is STRETCH's job.
    assertNear(spec.width / spec.height, a.w / a.h, 1e-9, "aspect" .. where)
    -- Exactly one axis touches: any less and the fit is not maximal, any more and it overflowed.
    local touches = math.abs(spec.width - p.W) < 1e-9 or math.abs(spec.height - p.H) < 1e-9
    assertTrue(touches, "does not touch either panel edge" .. where)
  end)
end)

test("Artwork FIT: never crops \226\128\148 the texture coordinates stay the full image", function()
  forEachCombo("FIT", nil, function(spec, _, _, where)
    assertUV(spec.uv, C.ACCENT_TEXCOORD_FLAT, "fit uv" .. where)
    assertFalse(spec.tile, "fit asked to wrap" .. where)
  end)
end)

test("Artwork FIT: scale multiplies the fitted size and nothing else", function()
  forEachCombo("FIT", { artScale = 0.5 }, function(spec, p, a, where)
    local r = math.min(p.W / a.w, p.H / a.h) * 0.5
    assertNear(spec.width,  a.w * r, 1e-9, "scaled width" .. where)
    assertNear(spec.height, a.h * r, 1e-9, "scaled height" .. where)
    -- Scale is a size knob for FIT, never a crop: the whole image is still shown, smaller.
    assertUV(spec.uv, C.ACCENT_TEXCOORD_FLAT, "scaled fit uv" .. where)
  end)
end)

test("Artwork FIT: scale is clamped to the artwork bounds, not applied raw", function()
  withArt(100, 100, true, function()
    local huge = Art.BuildArtSpec(
      record({ artTexture = TEST_ART_ID, artFill = "FIT", artScale = 999 }), 200, 200)
    local tiny = Art.BuildArtSpec(
      record({ artTexture = TEST_ART_ID, artFill = "FIT", artScale = -5 }), 200, 200)
    assertNear(huge.width, 200 * C.MAX_ART_SCALE)
    assertNear(tiny.width, 200 * C.MIN_ART_SCALE)
  end)
end)

-- ── Fill: FILL ──────────────────────────────────────────────────────────────────

test("Artwork FILL: covers the panel exactly, at every panel and art aspect", function()
  forEachCombo("FILL", nil, function(spec, p, _, where)
    -- Cover means the drawn rectangle IS the panel. The overflow comes off the texture coordinates
    -- instead, which is what lets it fill exactly and keep the aspect at the same time.
    assertNear(spec.width,  p.W, 1e-9, "width" .. where)
    assertNear(spec.height, p.H, 1e-9, "height" .. where)
  end)
end)

test("Artwork FILL: the crop preserves the art's aspect", function()
  forEachCombo("FILL", nil, function(spec, p, a, where)
    local u0, v0, u1, v1 = cropOf(spec)
    -- The visible slice of texture, measured in the art's own pixels, must have the panel's aspect
    -- — otherwise the art is stretched inside a rectangle that merely happens to be the right size.
    local visibleW, visibleH = (u1 - u0) * a.w, (v1 - v0) * a.h
    assertNear(visibleW / visibleH, p.W / p.H, 1e-9, "cropped aspect" .. where)
  end)
end)

test("Artwork FILL: crops the binding axis not at all, and centers what it does crop", function()
  forEachCombo("FILL", nil, function(spec, _, _, where)
    local u0, v0, u1, v1 = cropOf(spec)
    local uSpan, vSpan = u1 - u0, v1 - v0
    -- One axis is always kept whole: cropping both would throw away more than cover requires.
    local whole = math.abs(uSpan - 1) < 1e-9 or math.abs(vSpan - 1) < 1e-9
    assertTrue(whole, "both axes were cropped" .. where)
    assertTrue(uSpan <= 1 + 1e-9 and vSpan <= 1 + 1e-9, "the crop samples past the image" .. where)
    -- Centered, so the middle of the art is what survives — the subject of a centered motif.
    assertNear(u0 + u1, 1, 1e-9, "horizontal crop is off-center" .. where)
    assertNear(v0 + v1, 1, 1e-9, "vertical crop is off-center" .. where)
  end)
end)

test("Artwork FILL: a wide panel crops vertically and a tall panel crops horizontally", function()
  withArt(256, 256, true, function()
    local wide = Art.BuildArtSpec(record({ artTexture = TEST_ART_ID, artFill = "FILL" }), 400, 100)
    local tall = Art.BuildArtSpec(record({ artTexture = TEST_ART_ID, artFill = "FILL" }), 100, 400)
    local wu0, wv0, wu1, wv1 = cropOf(wide)
    -- Wider panel than art: the horizontal axis binds, so the top and bottom come off.
    assertNear(wu1 - wu0, 1)
    assertNear(wv1 - wv0, 0.25)
    local tu0, tv0, tu1, tv1 = cropOf(tall)
    assertNear(tu1 - tu0, 0.25)
    assertNear(tv1 - tv0, 1)
  end)
end)

test("Artwork FILL: scale tightens both surviving ranges, so a bigger scale zooms in", function()
  withArt(256, 256, true, function()
    local one = Art.BuildArtSpec(record({ artTexture = TEST_ART_ID, artFill = "FILL" }), 400, 100)
    local two = Art.BuildArtSpec(
      record({ artTexture = TEST_ART_ID, artFill = "FILL", artScale = 2 }), 400, 100)
    local au0, av0, au1, av1 = cropOf(one)
    local bu0, bv0, bu1, bv1 = cropOf(two)
    -- Dividing rather than multiplying is what makes the slider agree with every other fill, where
    -- a larger scale also makes the art bigger.
    assertNear(bu1 - bu0, (au1 - au0) / 2)
    assertNear(bv1 - bv0, (av1 - av0) / 2)
    -- Still covering the panel exactly, and still centered.
    assertNear(two.width, 400)
    assertNear(two.height, 100)
    assertNear(bu0 + bu1, 1)
    assertNear(bv0 + bv1, 1)
  end)
end)

-- ── Fill: STATIC ────────────────────────────────────────────────────────────────

test("Artwork STATIC: draws at the authored pixel size and ignores the panel entirely", function()
  forEachCombo("STATIC", nil, function(spec, _, a, where)
    assertNear(spec.width,  a.w, 1e-9, "width" .. where)
    assertNear(spec.height, a.h, 1e-9, "height" .. where)
    assertUV(spec.uv, C.ACCENT_TEXCOORD_FLAT, "static uv" .. where)
  end)
end)

test("Artwork STATIC: scale multiplies the authored size", function()
  forEachCombo("STATIC", { artScale = 2 }, function(spec, _, a, where)
    assertNear(spec.width,  a.w * 2, 1e-9, "width" .. where)
    assertNear(spec.height, a.h * 2, 1e-9, "height" .. where)
  end)
end)

-- ── Fill: STRETCH ───────────────────────────────────────────────────────────────

test("Artwork STRETCH: matches the panel exactly, at every panel and art aspect", function()
  forEachCombo("STRETCH", nil, function(spec, p, _, where)
    assertNear(spec.width,  p.W, 1e-9, "width" .. where)
    assertNear(spec.height, p.H, 1e-9, "height" .. where)
    assertUV(spec.uv, C.ACCENT_TEXCOORD_FLAT, "stretch uv" .. where)
  end)
end)

test("Artwork STRETCH: deliberately ignores scale", function()
  -- Stretching IS "match the panel exactly", so a scaled stretch is really FILL or STATIC depending
  -- on which the user meant. Honouring scale here would draw art that no longer matches the panel
  -- while still claiming to be stretched to it.
  forEachCombo("STRETCH", { artScale = C.MAX_ART_SCALE }, function(spec, p, _, where)
    assertNear(spec.width,  p.W, 1e-9, "width" .. where)
    assertNear(spec.height, p.H, 1e-9, "height" .. where)
  end)
end)

-- ── Fill: TILE ──────────────────────────────────────────────────────────────────

test("Artwork TILE: the uv range is how many copies fit across the panel", function()
  forEachCombo("TILE", nil, function(spec, p, a, where)
    assertNear(spec.width,  p.W, 1e-9, "width" .. where)
    assertNear(spec.height, p.H, 1e-9, "height" .. where)
    local u0, v0, u1, v1 = cropOf(spec)
    assertNear(u0, 0, 1e-9, "u origin" .. where)
    assertNear(v0, 0, 1e-9, "v origin" .. where)
    assertNear(u1, p.W / a.w, 1e-9, "u copies" .. where)
    assertNear(v1, p.H / a.h, 1e-9, "v copies" .. where)
    -- The flag is the one bit of this spec the renderer cannot infer from the numbers, and without
    -- REPEAT wrapping every coordinate past 1 clamps to the edge pixel instead of repeating.
    assertTrue(spec.tile, "tile did not ask to wrap" .. where)
  end)
end)

test("Artwork TILE: the copy count scales linearly with the panel", function()
  withArt(64, 64, true, function()
    local rec = record({ artTexture = TEST_ART_ID, artFill = "TILE" })
    local small = Art.BuildArtSpec(rec, 128, 128)
    local big   = Art.BuildArtSpec(rec, 256, 512)
    local _, _, su1, sv1 = cropOf(small)
    local _, _, bu1, bv1 = cropOf(big)
    -- Doubling the panel must show twice as many tiles, not the same tiles twice the size — that
    -- distinction is the whole difference between TILE and STRETCH.
    assertNear(bu1, su1 * 2)
    assertNear(bv1, sv1 * 4)
  end)
end)

test("Artwork TILE: scale sizes the tile, so a bigger scale means fewer copies", function()
  withArt(64, 64, true, function()
    local spec = Art.BuildArtSpec(
      record({ artTexture = TEST_ART_ID, artFill = "TILE", artScale = 2 }), 256, 256)
    local _, _, u1, v1 = cropOf(spec)
    assertNear(u1, 256 / (64 * 2))
    assertNear(v1, 256 / (64 * 2))
  end)
end)

test("Artwork: only TILE asks the renderer to wrap", function()
  for _, fill in ipairs(C.ART_FILL) do
    withArt(128, 128, true, function()
      local spec = Art.BuildArtSpec(record({ artTexture = TEST_ART_ID, artFill = fill }), 300, 200)
      assertEqual(spec.tile, fill == "TILE", "wrap flag for " .. fill)
    end)
  end
end)

-- ── Resize ──────────────────────────────────────────────────────────────────────

test("Artwork: all five fills behave as the panel is resized", function()
  -- The acceptance criterion, expressed as arithmetic. Each fill has exactly one thing it promises
  -- to hold constant while the panel moves under it, and this is that promise per fill.
  for _, fill in ipairs(C.ART_FILL) do
    withArt(200, 100, true, function()
      local rec = record({ artTexture = TEST_ART_ID, artFill = fill })
      local prev
      for _, size in ipairs({ { 100, 100 }, { 400, 100 }, { 100, 400 }, { 800, 600 } }) do
        local W, H = size[1], size[2]
        local spec = Art.BuildArtSpec(rec, W, H)
        local where = (" [%s at %dx%d]"):format(fill, W, H)
        if fill == "STATIC" then
          -- Static is the one fill the panel size must not reach at all.
          assertNear(spec.width, 200, 1e-9, "static width drifted" .. where)
          assertNear(spec.height, 100, 1e-9, "static height drifted" .. where)
          if prev then assertUV(spec.uv, prev.uv, "static uv drifted" .. where) end
        elseif fill == "FIT" then
          assertTrue(spec.width <= W + 1e-9 and spec.height <= H + 1e-9, "fit overflowed" .. where)
          assertNear(spec.width / spec.height, 2, 1e-9, "fit distorted" .. where)
        else
          -- STRETCH, FILL and TILE all cover the panel by definition, at any size.
          assertNear(spec.width, W, 1e-9, "does not cover" .. where)
          assertNear(spec.height, H, 1e-9, "does not cover" .. where)
        end
        prev = spec
      end
    end)
  end
end)

-- ── Position ────────────────────────────────────────────────────────────────────

test("Artwork: position is honoured by STATIC and FIT, which leave room to move", function()
  for _, fill in ipairs({ "STATIC", "FIT" }) do
    withArt(64, 64, true, function()
      local spec = Art.BuildArtSpec(record({
        artTexture = TEST_ART_ID, artFill = fill,
        artPoint = "TOPLEFT", artX = 12, artY = -8,
      }), 400, 300)
      assertEqual(spec.point, "TOPLEFT", "point for " .. fill)
      assertEqual(spec.x, 12, "x for " .. fill)
      assertEqual(spec.y, -8, "y for " .. fill)
    end)
  end
end)

test("Artwork: STRETCH, FILL and TILE force center, since they already cover the panel", function()
  -- An anchor or an offset could only shove a panel-sized rectangle off the panel and leave a bare
  -- strip, so the setting would be actively harmful rather than merely inert. The spec states where
  -- the art really sits, rather than the renderer having to know which fills to ignore.
  for _, fill in ipairs({ "STRETCH", "FILL", "TILE" }) do
    withArt(64, 64, true, function()
      local spec = Art.BuildArtSpec(record({
        artTexture = TEST_ART_ID, artFill = fill,
        artPoint = "BOTTOMRIGHT", artX = 40, artY = 40,
      }), 400, 300)
      assertEqual(spec.point, "CENTER", "point for " .. fill)
      assertEqual(spec.x, 0, "x for " .. fill)
      assertEqual(spec.y, 0, "y for " .. fill)
    end)
  end
end)

test("Artwork: a nonsense art anchor falls back to the template's own", function()
  withArt(64, 64, true, function()
    local spec = Art.BuildArtSpec(
      record({ artTexture = TEST_ART_ID, artFill = "FIT", artPoint = "MIDDLE" }), 200, 200)
    assertEqual(spec.point, C.PANEL_TEMPLATE.artPoint)
  end)
end)

-- ── UV composition ──────────────────────────────────────────────────────────────

test("Artwork: an unturned, unflipped quad is the identity texture coordinate", function()
  assertUV(specFor({ artTexture = "runic-sigil-bw", artFill = "FIT" }).uv, { 0, 0, 0, 1, 1, 0, 1, 1 })
end)

test("Artwork: one quarter turn reproduces C.ACCENT_TEXCOORD_ROT90 exactly", function()
  -- The accent bars already turn a horizontal statusbar texture onto a vertical edge with this
  -- permutation. If artwork's rotation is a different transform from that one, then two things in
  -- the same addon mean different things by "90 degrees" — so this equality is the contract, and
  -- Artwork.lua's own comment asserts it.
  local spec = specFor({ artTexture = "runic-sigil-bw", artFill = "FIT", artRotation = 90 })
  assertUV(spec.uv, C.ACCENT_TEXCOORD_ROT90, "quarter turn")
end)

test("Artwork: half a turn is the identity quad reversed", function()
  local spec = specFor({ artTexture = "runic-sigil-bw", artFill = "FIT", artRotation = 180 })
  assertUV(spec.uv, { 1, 1, 1, 0, 0, 1, 0, 0 }, "half turn")
end)

test("Artwork: three quarter turns are the quarter turn applied three times", function()
  local spec = specFor({ artTexture = "runic-sigil-bw", artFill = "FIT", artRotation = 270 })
  assertUV(spec.uv, { 1, 0, 0, 0, 1, 1, 0, 1 }, "three quarter turns")
end)

test("Artwork: a horizontal flip swaps the left and right columns", function()
  local spec = specFor({ artTexture = "runic-sigil-bw", artFill = "FIT", artFlipH = true })
  assertUV(spec.uv, { 1, 0, 1, 1, 0, 0, 0, 1 }, "flipH")
end)

test("Artwork: a vertical flip swaps the top and bottom rows", function()
  local spec = specFor({ artTexture = "runic-sigil-bw", artFill = "FIT", artFlipV = true })
  assertUV(spec.uv, { 0, 1, 0, 0, 1, 1, 1, 0 }, "flipV")
end)

test("Artwork: flipping both ways is the same as turning it half way round", function()
  local both = specFor({ artTexture = "runic-sigil-bw", artFill = "FIT",
                         artFlipH = true, artFlipV = true })
  local half = specFor({ artTexture = "runic-sigil-bw", artFill = "FIT", artRotation = 180 })
  assertUV(both.uv, half.uv, "flipH+flipV vs 180")
end)

test("Artwork: flips are applied BEFORE the turn, and the order is part of the contract", function()
  -- Flip-then-rotate is not the same transform as rotate-then-flip. Picking one and stating it is
  -- the only way the two checkboxes and the dropdown mean something stable together.
  local spec = specFor({ artTexture = "runic-sigil-bw", artFill = "FIT",
                         artFlipH = true, artRotation = 90 })
  assertUV(spec.uv, { 1, 1, 0, 1, 1, 0, 0, 0 }, "flipH then 90")
end)

test("Artwork: a quarter turn transposes a FILL crop rather than discarding it", function()
  -- Crop, flip and turn compose on the SAME four corners. A rotation implemented as a separate step
  -- would either reset the crop or sample outside it, which under CLAMP smears the edge pixels
  -- across the corners — the reason arbitrary angles were rejected outright.
  withArt(256, 256, true, function()
    local spec = Art.BuildArtSpec(record({
      artTexture = TEST_ART_ID, artFill = "FILL", artRotation = 90,
    }), 400, 100)
    -- The crop is computed in SCREEN terms and then transposed onto the texture's axes, because the
    -- turn is what decides which texture axis each screen axis samples. On a 4:1 panel that means
    -- cropping u to 0.25 and leaving v whole — the exact mirror of the unturned case, which crops v.
    --
    -- This literal was previously the UNtransposed crop, which drew this case at a 16:1 squash and
    -- passed, because the assertion had been written from the implementation rather than derived.
    assertUV(spec.uv, { 0.375, 1, 0.625, 1, 0.375, 0, 0.625, 0 }, "turned crop")
  end)
end)

-- The invariant the literal above is a single instance of, checked across the whole matrix.
--
-- Aspect-preserving means one thing measurably: the texels-per-pixel along the screen's horizontal
-- equals the texels-per-pixel down its vertical. Asserting THAT rather than a coordinate literal is
-- what makes the check independent of how the crop happens to be expressed — and it is what a
-- literal transcribed from a buggy implementation can never do.
local function texelsPerPixel(spec, w, h)
  local ulU, ulV, llU, llV, urU, urV = spec.uv[1], spec.uv[2], spec.uv[3], spec.uv[4],
                                       spec.uv[5], spec.uv[6]
  local acrossH = math.abs(urU - ulU) * w + math.abs(urV - ulV) * h
  local downV   = math.abs(llU - ulU) * w + math.abs(llV - ulV) * h
  return acrossH / spec.width, downV / spec.height
end

for _, fill in ipairs({ "FILL", "FIT", "STATIC", "TILE" }) do
  test("Artwork " .. fill .. ": every quarter turn preserves the art's aspect", function()
    -- STRETCH is excluded on purpose: distorting to the panel is what it is FOR.
    --
    -- Square art cannot catch a missing transpose — both axes are the same length, so swapping them
    -- is a no-op — which is exactly how this shipped broken. Wide and tall art on a wide and a tall
    -- panel is the smallest matrix that sees it.
    for _, rot in ipairs(C.ART_ROTATION) do
      for _, p in ipairs(PANELS) do
        for _, a in ipairs(ARTS) do
          withArt(a.w, a.h, true, function()
            local rec = record({ artTexture = TEST_ART_ID, artFill = fill, artRotation = rot })
            local spec = Art.BuildArtSpec(rec, p.W, p.H)
            local where = (" [%s %d: %s / %s]"):format(fill, rot, p.name, a.name)
            local across, down = texelsPerPixel(spec, a.w, a.h)
            assertNear(across, down, 1e-9, "aspect is not preserved" .. where)
          end)
        end
      end
    end
  end)
end

test("Artwork: a rotation that is not a quarter turn falls back to the template's", function()
  local spec = specFor({ artTexture = "runic-sigil-bw", artFill = "FIT", artRotation = 45 })
  assertUV(spec.uv, C.ACCENT_TEXCOORD_FLAT, "45 degrees")
end)

-- ── Color ───────────────────────────────────────────────────────────────────────

test("Artwork: the tint carries the stored color through", function()
  local spec = specFor({ artTexture = "runic-sigil-bw", artColor = { 0.2, 0.4, 0.6, 1 } })
  assertNear(spec.color[1], 0.2)
  assertNear(spec.color[2], 0.4)
  assertNear(spec.color[3], 0.6)
end)

test("Artwork: artAlpha multiplies the tint's own alpha rather than replacing it", function()
  -- The color picker's alpha and the opacity slider compose, so neither silently wins.
  local spec = specFor({ artTexture = "runic-sigil-bw", artColor = { 1, 1, 1, 0.5 }, artAlpha = 0.5 })
  assertNear(spec.color[4], 0.25)
end)

test("Artwork: artClassColor overrides the RGB and keeps the computed alpha", function()
  -- Through Util.ResolveColor, so class color cost one C.COLOR_FIELDS row and no code in Artwork.
  -- The mock player is a Priest (1, 1, 1) against a stored black, so the override is visible.
  local spec = specFor({
    artTexture = "runic-sigil-bw", artColor = { 0, 0, 0, 0.5 }, artClassColor = true, artAlpha = 0.5,
  })
  assertNear(spec.color[1], 1)
  assertNear(spec.color[2], 1)
  assertNear(spec.color[3], 1)
  assertNear(spec.color[4], 0.25)
end)

test("Artwork: the class-color row is wired up in C.COLOR_FIELDS", function()
  assertEqual(C.COLOR_FIELDS.artColor, "artClassColor")
end)

test("Artwork: full-color art is forced white, and keeps the computed alpha", function()
  -- Tinting finished full-color art can only drag it toward the tint, never improve it, and a user
  -- who has picked a color would see a muddy result with no indication why. "Make it fainter" is
  -- still a sensible thing to ask of it, so the alpha survives.
  withArt(128, 128, false, function()
    local spec = Art.BuildArtSpec(record({
      artTexture = TEST_ART_ID, artColor = { 1, 0, 0, 0.8 }, artAlpha = 0.5,
    }), 200, 200)
    assertNear(spec.color[1], 1)
    assertNear(spec.color[2], 1)
    assertNear(spec.color[3], 1)
    assertNear(spec.color[4], 0.4)
  end)
end)

test("Artwork: full-color art ignores class color too", function()
  withArt(128, 128, false, function()
    local spec = Art.BuildArtSpec(record({
      artTexture = TEST_ART_ID, artColor = { 0, 0, 0, 1 }, artClassColor = true,
    }), 200, 200)
    assertNear(spec.color[1], 1)
    assertNear(spec.color[2], 1)
    assertNear(spec.color[3], 1)
  end)
end)

test("Artwork: a custom path counts as tintable", function()
  -- It has no catalog row to declare otherwise, and tinting your own art white is a no-op, so the
  -- permissive default costs nothing.
  local spec = specFor({
    artTexture = C.ARTWORK_CUSTOM, artCustomPath = "Interface\\Icons\\INV_Misc_QuestionMark",
    artColor = { 1, 0, 0, 1 },
  })
  assertTrue(spec ~= nil, "a custom path built no spec")
  assertNear(spec.color[1], 1)
  assertNear(spec.color[2], 0)
end)

-- ── Degenerate input ────────────────────────────────────────────────────────────

test("Artwork.BuildArtSpec: no artwork selected is nil, the cheapest possible answer", function()
  assertEqual(specFor({ artTexture = C.ARTWORK_NONE }), nil)
  assertEqual(specFor({ artTexture = "" }), nil)
  assertEqual(Art.BuildArtSpec({}, 200, 200), nil)
end)

test("Artwork.BuildArtSpec: an id that no longer exists draws nothing, not an error", function()
  -- An art pack the user uninstalled leaves records naming rows that are gone. Degrading to "no
  -- artwork" is what makes that recoverable — the id stays in the file and resolves again if the
  -- pack comes back.
  assertEqual(specFor({ artTexture = "no-such-artwork" }), nil)
end)

test("Artwork.BuildArtSpec: Custom with nothing typed yet draws nothing", function()
  assertEqual(specFor({ artTexture = C.ARTWORK_CUSTOM, artCustomPath = "" }), nil)
  assertEqual(specFor({ artTexture = C.ARTWORK_CUSTOM, artCustomPath = "   " }), nil)
  assertEqual(specFor({ artTexture = C.ARTWORK_CUSTOM, artCustomPath = 42 }), nil)
end)

test("Artwork.BuildArtSpec: a zero-sized panel is nil rather than a division by zero", function()
  -- Every fill divides by at least one of W, H, w or h. An inf or a nan reaches SetTexCoord
  -- silently and renders as a garbage smear, so it has to be refused before the arithmetic.
  local rec = record({ artTexture = "runic-sigil-bw", artFill = "TILE" })
  assertEqual(Art.BuildArtSpec(rec, 0, 100), nil)
  assertEqual(Art.BuildArtSpec(rec, 100, 0), nil)
  assertEqual(Art.BuildArtSpec(rec, -10, 100), nil)
  assertEqual(Art.BuildArtSpec(rec, nil, nil), nil)
  assertEqual(Art.BuildArtSpec(rec, "wide", 100), nil)
end)

test("Artwork.BuildArtSpec: a catalog row with a broken native size draws nothing", function()
  -- A typo'd `w` reaches the same divisions the panel size does, and an inf or a nan out of one of
  -- them renders as a garbage smear rather than as an error anybody would notice.
  withArt(0, 128, true, function()
    assertEqual(Art.BuildArtSpec(record({ artTexture = TEST_ART_ID }), 200, 200), nil)
  end)
  withArt(128, -1, true, function()
    assertEqual(Art.BuildArtSpec(record({ artTexture = TEST_ART_ID }), 200, 200), nil)
  end)
  withArt("wide", 128, true, function()
    assertEqual(Art.BuildArtSpec(record({ artTexture = TEST_ART_ID }), 200, 200), nil)
  end)
end)

test("Artwork.BuildArtSpec: a catalog row with NO declared size falls back to the nominal one",
  function()
    -- A row that omits w/h entirely is treated like a custom path: there is no size to work
    -- from, so
    -- the nominal one stands in. That is the accepted behavior rather than the accident it looks
    -- like — the catalog-integrity test above is what keeps it unreachable for shipped art, and
    -- degrading to a plausible size beats a bundled piece that silently never draws.
    withRows({ { id = "pm-sizeless-art", category = "General", label = "Sizeless",
                 file = "runic-sigil-bw", tintable = true, credit = "test fixture" } }, function()
      local spec = Art.BuildArtSpec(
        record({ artTexture = "pm-sizeless-art", artFill = "STATIC" }), 200, 200)
      assertTrue(spec ~= nil, "a row with no declared size drew nothing at all")
      assertNear(spec.width, Art.CUSTOM_NATIVE_SIZE)
      assertNear(spec.height, Art.CUSTOM_NATIVE_SIZE)
    end)
  end)

test("Artwork.BuildArtSpec: a non-table record is nil, not a crash", function()
  assertEqual(Art.BuildArtSpec(nil, 200, 200), nil)
  assertEqual(Art.BuildArtSpec("runic-sigil-bw", 200, 200), nil)
end)

test("Artwork.BuildArtSpec: an unknown fill or layer falls back to the template", function()
  -- A hand-edited SavedVariables file must not reach the renderer with artFill = "COVER": every
  -- branch computes a different rectangle, and an unknown token would produce a nil size that lands
  -- in SetSize — a Lua error inside a paint, which leaves the panel half-drawn.
  local spec = specFor({ artTexture = "runic-sigil-bw", artFill = "COVER",
                         artLayer = "MIDDLE" })
  local t = C.PANEL_TEMPLATE
  assertEqual(spec.layer, t.artLayer)
  assertEqual(spec.level, C.ART_FRAME_LEVEL[t.artLayer])
  -- FIT is the template default, and on a square panel with square art it fits exactly.
  assertNear(spec.width, 200)
end)

test("Artwork.BuildArtSpec: the layer resolves to the frame level the renderer must use", function()
  -- Resolved in the spec so the ladder is stated once, in Constants, rather than re-derived by the
  -- renderer from a string it would have to know the meaning of.
  for _, layer in ipairs(C.ART_LAYER) do
    local spec = specFor({ artTexture = "runic-sigil-bw", artLayer = layer })
    assertEqual(spec.layer, layer)
    assertEqual(spec.level, C.ART_FRAME_LEVEL[layer], "level for " .. layer)
  end
end)

-- ── Upgrade inertness ───────────────────────────────────────────────────────────

test("Artwork: a panel straight from the template renders no artwork at all", function()
  -- Load-bearing. Every panel that predates this feature gains these fields on the next Sanitize
  -- and must look exactly as it did before; any other default would restyle the user's whole UI on
  -- upgrade.
  assertEqual(C.PANEL_TEMPLATE.artTexture, C.ARTWORK_NONE)
  local spec = Canvas.BuildSpec(record({}), {})
  assertEqual(spec.art, nil, "the shipped default drew artwork")
end)

test("Artwork: a record that predates the feature entirely renders no artwork", function()
  -- A record read from an old SavedVariables file has none of the art fields at all, and reaches
  -- the renderer before anything sanitizes it on some paths.
  local spec = Canvas.BuildSpec({ name = "Old", width = 200, height = 100 }, {})
  assertEqual(spec.art, nil)
end)

test("Artwork: Canvas.BuildSpec fits the art to the CLAMPED panel size", function()
  -- Art fitted to a width the panel will never be drawn at is art that lands in the wrong place the
  -- moment the clamp bites.
  local spec = Canvas.BuildSpec(record({
    artTexture = "runic-sigil-bw", artFill = "STRETCH", width = 99999, height = 99999,
  }), {})
  assertEqual(spec.width, C.MAX_SIZE)
  assertNear(spec.art.width, C.MAX_SIZE)
  assertNear(spec.art.height, C.MAX_SIZE)
end)

-- ── Persistence ─────────────────────────────────────────────────────────────────

-- Every art field, with a value that differs from the template's, so a field silently dropped by a
-- copy or a profile switch cannot pass by matching the default.
local ART_SETTINGS = {
  artTexture = "runic-sigil-bw", artCustomPath = "Interface\\Icons\\INV_Misc_QuestionMark",
  artColor = { 0.2, 0.3, 0.4, 0.5 }, artClassColor = true, artAlpha = 0.75,
  artFill = "TILE", artPoint = "TOPLEFT", artX = 11, artY = -13, artScale = 2.5,
  artRotation = 270, artFlipH = true, artFlipV = true,
  artLayer = "ABOVE_ALL",
}

local function assertArtIntact(rec, msg)
  for field, want in pairs(ART_SETTINGS) do
    if type(want) == "table" then
      for i = 1, 4 do
        assertNear(rec[field][i], want[i], 1e-9, (msg or "") .. field .. "[" .. i .. "]")
      end
    else
      assertEqual(rec[field], want, (msg or "") .. field)
    end
  end
end

test("Artwork: Sanitize leaves a fully-specified artwork record alone", function()
  local rec = R.Sanitize(record(ART_SETTINGS))
  assertArtIntact(rec, "sanitized ")
end)

test("Artwork: every art field is in the template, the type map and the dump order", function()
  -- The three lists are what make the CLI, the settings page and the field dump pick these up with
  -- no per-field work. A field present in one and missing from another is invisible until somebody
  -- tries to set it.
  local order = {}
  for _, f in ipairs(C.PANEL_FIELD_ORDER) do order[f] = true end
  for field in pairs(ART_SETTINGS) do
    assertTrue(C.PANEL_TEMPLATE[field] ~= nil, field .. " is missing from the template")
    assertTrue(C.PANEL_FIELD_TYPE[field] ~= nil, field .. " has no declared type")
    assertTrue(order[field], field .. " is missing from PANEL_FIELD_ORDER")
  end
end)

test("Artwork: Registry.CopyFrom carries every art field across", function()
  fresh()
  local source = R:New("Source", ART_SETTINGS)
  local target = R:New("Target")
  assertTrue((R:CopyFrom(target.id, source.id)))
  assertArtIntact(R:Get(target.id), "copied ")
end)

test("Artwork: a copy deep-copies the art color rather than sharing it", function()
  fresh()
  local source = R:New("Source", { artColor = { 0.1, 0.2, 0.3, 1 } })
  local target = R:New("Target")
  R:CopyFrom(target.id, source.id)
  R:Get(target.id).artColor[1] = 0.99
  -- A shared array would mean recoloring one panel's artwork silently recolored the other's.
  assertNear(R:Get(source.id).artColor[1], 0.1)
end)

test("Artwork: a profile round-trip keeps every art field intact", function()
  fresh()
  -- The profile in force is captured and put back rather than switched to a hardcoded name: which
  -- profile a character starts on is itself asserted by the database suite, and a suite that hands
  -- the environment back changed makes a later, unrelated test fail for reasons nothing names.
  local was = NS.db:GetCurrentProfile()
  T.mocks.__switchProfile("Artwork Round Trip")
  local rec = R:New("Arty", ART_SETTINGS)
  -- ReloadProfile re-sanitizes every incoming record, which is the moment a profile written by an
  -- older build would lose anything it does not recognize.
  R:ReloadProfile()
  assertArtIntact(R:Get(rec.id), "after reload ")
  R:DeleteAll()
  T.mocks.__switchProfile(was)
end)

test("Artwork: R:Set stores an art field through the normal write seam", function()
  fresh()
  local rec = R:New("Settable")
  assertTrue((R:Set(rec.id, "artTexture", "runic-sigil-bw")))
  assertTrue((R:Set(rec.id, "artFill", "FILL")))
  assertEqual(R:Get(rec.id).artTexture, "runic-sigil-bw")
  assertEqual(R:Get(rec.id).artFill, "FILL")
  -- And the panel repainted, rather than waiting for a full rebuild.
  assertTrue(Canvas:FrameFor(rec.id).artFrame:IsShown())
end)

-- ── Renderer ────────────────────────────────────────────────────────────────────

test("Canvas: a panel with artwork shows its art frame and applies the resolved path", function()
  fresh()
  local rec = R:New("Arted", { artTexture = "runic-sigil-bw" })
  local f = Canvas:FrameFor(rec.id)
  assertTrue(f.artFrame:IsShown(), "the art frame stayed hidden")
  assertEqual(f.art:GetTexture(), RUNIC)
end)

test("Canvas: the art frame takes the level its layer names, for all three layers", function()
  fresh()
  local rec = R:New("Layered", { artTexture = "runic-sigil-bw" })
  for _, layer in ipairs(C.ART_LAYER) do
    R:Set(rec.id, "artLayer", layer)
    local f = Canvas:FrameFor(rec.id)
    assertEqual(f.artFrame:GetFrameLevel(), f:GetFrameLevel() + C.ART_FRAME_LEVEL[layer],
      "frame level for " .. layer)
  end
end)

test("Canvas: there is ONE art frame, whose level is reassigned per render", function()
  fresh()
  local rec = R:New("Reassigned", { artTexture = "runic-sigil-bw", artLayer = "BELOW_BG" })
  local frame = Canvas:FrameFor(rec.id).artFrame
  R:Set(rec.id, "artLayer", "ABOVE_ALL")
  -- Three frames for three choices would be two frames per panel created to sit hidden forever.
  assertEqual(Canvas:FrameFor(rec.id).artFrame, frame, "a second art frame appeared")
end)

test("Canvas: the artwork ladder interleaves with the fill, the border and the accent", function()
  fresh()
  local rec = R:New("Ladder", { artTexture = "runic-sigil-bw", borderSize = 4, accentEnabled = true })
  local f = Canvas:FrameFor(rec.id)
  local base = f:GetFrameLevel()
  assertEqual(f.bgFrame:GetFrameLevel(), base + C.BG_FRAME_LEVEL)
  assertEqual(f.borderFrame:GetFrameLevel(), base + C.BORDER_FRAME_LEVEL)
  assertEqual(f.accentFrame:GetFrameLevel(), base + C.ACCENT_FRAME_LEVEL)
  -- Bottom-up, the three artwork slots have to land on either side of each of the others, or
  -- "behind the background" and "above the accent bar" cannot both be expressible at once.
  assertTrue(C.ART_FRAME_LEVEL.BELOW_BG < C.BG_FRAME_LEVEL)
  assertTrue(C.ART_FRAME_LEVEL.ABOVE_BG > C.BG_FRAME_LEVEL)
  assertTrue(C.ART_FRAME_LEVEL.ABOVE_BG < C.BORDER_FRAME_LEVEL)
  assertTrue(C.ART_FRAME_LEVEL.ABOVE_ALL > C.ACCENT_FRAME_LEVEL)
end)

test("Canvas: the fill lives on its own child frame, so BELOW_BG is reachable", function()
  fresh()
  local rec = R:New("Underneath", { artTexture = "runic-sigil-bw", artLayer = "BELOW_BG" })
  local f = Canvas:FrameFor(rec.id)
  -- A child frame always draws above its PARENT's textures whatever draw layer they use, so with
  -- the fill on the panel itself there would be no level a child could take to get underneath it.
  assertTrue(f.bgFrame ~= nil, "the fill is still a texture on the panel frame")
  assertTrue(f.artFrame:GetFrameLevel() < f.bgFrame:GetFrameLevel(),
    "the artwork cannot get behind the background")
end)

test("Canvas: the art frame clips its children, so offset art stays inside the panel", function()
  fresh()
  local rec = R:New("Clipped", { artTexture = "runic-sigil-bw", artFill = "STATIC",
                                 artPoint = "TOPLEFT", artScale = 4 })
  -- Clipping is on the ART frame specifically, never on the panel: the accent bars deliberately
  -- hang OUTSIDE the panel's bounds and a clip one level up would eat them.
  assertTrue(Canvas:FrameFor(rec.id).artFrame.__clipsChildren, "the art frame does not clip")
end)

test("Canvas: the art texture takes the spec's size, anchor and texture coordinates", function()
  fresh()
  local rec = R:New("Placed", { width = 400, height = 400, artTexture = "runic-sigil-bw",
                                artFill = "STATIC", artScale = 0.5,
                                artPoint = "TOPLEFT", artX = 10, artY = -10 })
  local tex = Canvas:FrameFor(rec.id).art
  assertNear(tex:GetWidth(), 256)
  assertNear(tex:GetHeight(), 256)
  local point, _, _, x, y = tex:GetPoint(1)
  assertEqual(point, "TOPLEFT")
  assertEqual(x, 10)
  assertEqual(y, -10)
  assertEqual(#tex.__texCoord, 8, "the eight-argument SetTexCoord form was not used")
end)

test("Canvas: tiled artwork asks SetTexture to wrap; nothing else does", function()
  fresh()
  local rec = R:New("Tiled", { artTexture = "runic-sigil-bw", artFill = "TILE" })
  local tex = Canvas:FrameFor(rec.id).art
  assertEqual(tex.__wrapH, "REPEAT")
  assertEqual(tex.__wrapV, "REPEAT")
  -- Passing the wrap unconditionally would let a FILL crop's rounding sample the OPPOSITE edge
  -- instead of clamping to the border pixel.
  R:Set(rec.id, "artFill", "FILL")
  tex = Canvas:FrameFor(rec.id).art
  assertEqual(tex.__wrapH, nil)
  assertEqual(tex.__wrapV, nil)
end)

test("Canvas: the artwork tint reaches the texture, and the blend mode is always Normal", function()
  -- The blend mode is a CONSTANT, not a setting. Two of WoW's five modes cannot be correct for art
  -- defined by its alpha channel, so rather than ship a dropdown with two traps in it the whole
  -- setting was dropped. Asserted here because the texture is POOLED: it is set explicitly on every
  -- repaint so a future mode change could never leak from one panel into the next.
  fresh()
  local rec = R:New("Tinted", { artTexture = "runic-sigil-bw", artClassColor = false,
                                artColor = { 0.25, 0.5, 0.75, 1 }, artAlpha = 0.5 })
  local tex = Canvas:FrameFor(rec.id).art
  assertNear(tex.__color[1], 0.25)
  assertNear(tex.__color[4], 0.5)
  assertEqual(tex.__blend, C.ART_BLEND_MODE)
  assertEqual(C.ART_BLEND_MODE, "BLEND")
end)

test("Canvas: turning artwork off clears the texture as well as hiding the frame", function()
  fresh()
  local rec = R:New("Fickle", { artTexture = "runic-sigil-bw" })
  R:Set(rec.id, "artTexture", C.ARTWORK_NONE)
  local f = Canvas:FrameFor(rec.id)
  assertFalse(f.artFrame:IsShown(), "the art frame stayed shown")
  -- A hidden frame still holds its texture's file reference, and this frame is about to be handed
  -- to whatever panel the pool gives it to next.
  assertEqual(f.art:GetTexture(), nil)
end)

test("Canvas: a released frame keeps no artwork for the next panel to inherit", function()
  fresh()
  local rec = R:New("Doomed", { artTexture = "runic-sigil-bw" })
  local frameName = Util.FrameName("Doomed")
  R:Delete(rec.id)
  local pooled = Canvas.__pool[frameName]
  assertTrue(pooled ~= nil, "the frame was not pooled under its own name")
  -- Anything that shows a pooled frame before applySpec runs again — Unlock's overlay, a debug
  -- dump, a stray Show() — would otherwise put the PREVIOUS panel's artwork on screen.
  assertEqual(pooled.art:GetTexture(), nil, "the pooled frame kept its artwork")
  assertFalse(pooled.artFrame:IsShown(), "the pooled art frame stayed shown")
end)

test("Canvas: a reused frame draws the new panel's artwork, not the old panel's", function()
  fresh()
  local first = R:New("Recycled", { artTexture = "runic-sigil-bw" })
  R:Delete(first.id)
  local second = R:New("Recycled")
  local f = Canvas:FrameFor(second.id)
  assertEqual(f.art:GetTexture(), nil, "the recycled frame inherited the old panel's artwork")
  assertFalse(f.artFrame:IsShown())
end)

test("Canvas: a panel with no artwork never shows its art frame", function()
  fresh()
  local rec = R:New("Bare")
  assertFalse(Canvas:FrameFor(rec.id).artFrame:IsShown())
end)
