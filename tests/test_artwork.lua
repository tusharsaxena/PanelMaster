-- The artwork catalog, upgrade inertness, persistence, the renderer and composite artwork. The
-- single-texture BuildArtSpec cases (the five fills, resize, position, UV composition, the tint and
-- degenerate input) were peeled out along the catalog / geometry seam into
-- tests/test_artwork_geometry.lua, which the runner lists straight after this suite.

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
-- A real shipped row, used wherever a test needs "some valid catalog art" rather than a specific
-- piece. Chosen over a synthetic fixture so the geometry cases exercise a row that actually ships.
--
-- Declared HERE, above withRows/withArt, because a Lua local is only visible after its declaration:
-- referencing it from an earlier line silently reads a nil GLOBAL, and a fixture row with file=nil
-- resolves to no path, which surfaces as "no spec at all" a long way from the cause.
local SEED_ID   = "class-warrior"
local SEED_FILE = "class\\warrior"                            -- the stem, not the id
local SEED_PATH = C.ARTWORK_PATH_PREFIX .. SEED_FILE .. ".tga"

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
  withRows({ { id = TEST_ART_ID, category = "General", label = "Test Art", file = SEED_FILE,
               w = w, h = h, tintable = tintable } }, fn)
end

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

test("Artwork: every catalog row carries a non-empty category", function()
  -- There is no declared category list any more: categories are derived from the artwork's folder
  -- path by tools/artwork/update_catalog.py, so membership cannot be checked against a fixed set.
  -- What still matters is that every row HAS one, because Artwork.List groups on it and a nil
  -- would silently sort the row to the end of the dropdown under no heading at all.
  for _, row in ipairs(Catalog) do
    assertEqual(type(row.category), "string",
      ("row '%s' has category '%s'"):format(tostring(row.id), tostring(row.category)))
    assertTrue(#row.category > 0, "empty category on row " .. tostring(row.id))
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

test("Artwork: every catalog row is square and a power of two", function()
  -- Replaces an assertion about one hand-authored seed row, which no longer exists: the catalog is
  -- generated from media/artwork/ by tools/artwork/update_catalog.py, so what is worth pinning is
  -- the property EVERY row must hold rather than the identity of any single piece.
  --
  -- Power-of-two on both axes is not cosmetic. WoW cannot wrap a non-power-of-two texture, so the
  -- TILE fill would render corrupt (or refuse to load at all on some drivers) for a row that slipped
  -- through at, say, 1000x1000.
  -- Halved rather than masked with `&`: this addon targets WoW's Lua 5.1, which has no bitwise
  -- operators at all, and the test suite runs on the same dialect the client does.
  local function isPowerOfTwo(n)
    if type(n) ~= "number" or n < 1 or n % 1 ~= 0 then return false end
    while n > 1 do
      if n % 2 ~= 0 then return false end
      n = n / 2
    end
    return true
  end

  for _, row in ipairs(Catalog) do
    local at = " on row " .. tostring(row.id)
    assertEqual(row.w, row.h, "not square" .. at)
    assertTrue(isPowerOfTwo(row.w), "not a power of two" .. at)
  end
end)

test("Artwork.Entry: finds a row by id and forgives its case", function()
  -- The CLI is the reason: `/pm panel set Art Class-Warrior` should find the row rather than refuse
  -- it, mirroring how the media field kind already forgives case.
  assertEqual(Art.Entry(SEED_ID).id, SEED_ID)
  assertEqual(Art.Entry(SEED_ID:upper()).id, SEED_ID)
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
  -- justify a grouped one. Categories are now derived from the folder path, so the prefix can be
  -- several levels deep ("Faction -> Expansion -> 12 Midnight").
  local list = Art.List()
  local row = Art.Entry(SEED_ID)
  local found
  for _, entry in ipairs(list) do
    if entry.id == SEED_ID then found = entry end
  end
  assertTrue(found ~= nil, "the seed row is missing from the list")
  assertEqual(found.label, row.category .. ": " .. row.label)
  assertEqual(found.category, row.category)
end)

test("Artwork.List: orders the catalog by category, then by label", function()
  withRows({
    { id = "zzz-alpha", category = "Aaa",  label = "Zebra",    file = SEED_FILE,
      w = 8, h = 8, tintable = true },
    { id = "aaa-omega", category = "Zzz",  label = "Aardvark", file = SEED_FILE,
      w = 8, h = 8, tintable = true },
    { id = "mid-two",   category = "Aaa",  label = "Antelope", file = SEED_FILE,
      w = 8, h = 8, tintable = true },
  }, function()
    local order = {}
    for i, entry in ipairs(Art.List()) do order[entry.id] = i end
    -- CATEGORY decides first, even though the labels sort the other way. This is the whole reason
    -- the sort is two-level rather than a plain label sort.
    assertTrue(order["zzz-alpha"] < order["aaa-omega"], "category order lost to label order")
    -- Categories rank ALPHABETICALLY now. There is no declared list to rank against, because they
    -- are derived from the artwork's folder path, so "Aaa" precedes "Zzz" by string comparison.
    -- That also keeps a folder's children next to it: a child's category starts with its parent's.
    assertTrue(order["zzz-alpha"] < order["aaa-omega"], "categories are not alphabetical")
    -- And within one category, the label decides.
    assertTrue(order["mid-two"] < order["zzz-alpha"], "labels are not sorted within category")
  end)
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
    artTexture = SEED_ID, artFill = "STRETCH", width = 99999, height = 99999,
  }), {})
  assertEqual(spec.width, C.MAX_SIZE)
  assertNear(spec.art.width, C.MAX_SIZE)
  assertNear(spec.art.height, C.MAX_SIZE)
end)

-- ── Persistence ─────────────────────────────────────────────────────────────────

-- Every art field, with a value that differs from the template's, so a field silently dropped by a
-- copy or a profile switch cannot pass by matching the default.
local ART_SETTINGS = {
  artTexture = SEED_ID, artCustomPath = "Interface\\Icons\\INV_Misc_QuestionMark",
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
  assertTrue((R:Set(rec.id, "artTexture", SEED_ID)))
  assertTrue((R:Set(rec.id, "artFill", "FILL")))
  assertEqual(R:Get(rec.id).artTexture, SEED_ID)
  assertEqual(R:Get(rec.id).artFill, "FILL")
  -- And the panel repainted, rather than waiting for a full rebuild.
  assertTrue(Canvas:FrameFor(rec.id).artFrame:IsShown())
end)

-- ── Renderer ────────────────────────────────────────────────────────────────────

test("Canvas: a panel with artwork shows its art frame and applies the resolved path", function()
  fresh()
  local rec = R:New("Arted", { artTexture = SEED_ID })
  local f = Canvas:FrameFor(rec.id)
  assertTrue(f.artFrame:IsShown(), "the art frame stayed hidden")
  assertEqual(f.art:GetTexture(), SEED_PATH)
end)

test("Canvas: the art frame takes the level its layer names, for all three layers", function()
  fresh()
  local rec = R:New("Layered", { artTexture = SEED_ID })
  for _, layer in ipairs(C.ART_LAYER) do
    R:Set(rec.id, "artLayer", layer)
    local f = Canvas:FrameFor(rec.id)
    assertEqual(f.artFrame:GetFrameLevel(), f:GetFrameLevel() + C.ART_FRAME_LEVEL[layer],
      "frame level for " .. layer)
  end
end)

test("Canvas: there is ONE art frame, whose level is reassigned per render", function()
  fresh()
  local rec = R:New("Reassigned", { artTexture = SEED_ID, artLayer = "BELOW_BG" })
  local frame = Canvas:FrameFor(rec.id).artFrame
  R:Set(rec.id, "artLayer", "ABOVE_ALL")
  -- Three frames for three choices would be two frames per panel created to sit hidden forever.
  assertEqual(Canvas:FrameFor(rec.id).artFrame, frame, "a second art frame appeared")
end)

test("Canvas: the artwork ladder interleaves with the fill, the border and the accent", function()
  fresh()
  local rec = R:New("Ladder", { artTexture = SEED_ID, borderSize = 4, accentEnabled = true })
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
  local rec = R:New("Underneath", { artTexture = SEED_ID, artLayer = "BELOW_BG" })
  local f = Canvas:FrameFor(rec.id)
  -- A child frame always draws above its PARENT's textures whatever draw layer they use, so with
  -- the fill on the panel itself there would be no level a child could take to get underneath it.
  assertTrue(f.bgFrame ~= nil, "the fill is still a texture on the panel frame")
  assertTrue(f.artFrame:GetFrameLevel() < f.bgFrame:GetFrameLevel(),
    "the artwork cannot get behind the background")
end)

test("Canvas: the art frame clips its children, so offset art stays inside the panel", function()
  fresh()
  local rec = R:New("Clipped", { artTexture = SEED_ID, artFill = "STATIC",
                                 artPoint = "TOPLEFT", artScale = 4 })
  -- Clipping is on the ART frame specifically, never on the panel: the accent bars deliberately
  -- hang OUTSIDE the panel's bounds and a clip one level up would eat them.
  assertTrue(Canvas:FrameFor(rec.id).artFrame.__clipsChildren, "the art frame does not clip")
end)

test("Canvas: the art texture takes the spec's size, anchor and texture coordinates", function()
  fresh()
  local rec = R:New("Placed", { width = 400, height = 400, artTexture = SEED_ID,
                                artFill = "STATIC", artScale = 0.5,
                                artPoint = "TOPLEFT", artX = 10, artY = -10 })
  local tex = Canvas:FrameFor(rec.id).art
  -- Derived from the row rather than hard-coded, so re-importing the art at a different size
  -- changes one number in the catalog and nothing here.
  local native = Art.Entry(SEED_ID).w
  assertNear(tex:GetWidth(), native * 0.5)
  assertNear(tex:GetHeight(), native * 0.5)
  local point, _, _, x, y = tex:GetPoint(1)
  assertEqual(point, "TOPLEFT")
  assertEqual(x, 10)
  assertEqual(y, -10)
  assertEqual(#tex.__texCoord, 8, "the eight-argument SetTexCoord form was not used")
end)

test("Canvas: tiled artwork asks SetTexture to wrap; nothing else does", function()
  fresh()
  local rec = R:New("Tiled", { artTexture = SEED_ID, artFill = "TILE" })
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

test("Canvas: the artwork tint and blend mode reach the texture", function()
  -- The blend mode is a CONSTANT, not a setting. Two of WoW's five modes cannot be correct for art
  -- defined by its alpha channel, so rather than ship a dropdown with two traps in it the whole
  -- setting was dropped. Asserted here because the texture is POOLED: it is set explicitly on every
  -- repaint so a future mode change could never leak from one panel into the next.
  fresh()
  withArt(512, 512, true, function()
    local rec = R:New("Tinted", { artTexture = TEST_ART_ID, artClassColor = false,
                                  artColor = { 0.25, 0.5, 0.75, 1 }, artAlpha = 0.5 })
    local tex = Canvas:FrameFor(rec.id).art
    assertNear(tex.__color[1], 0.25)
    assertNear(tex.__color[4], 0.5)
    assertEqual(tex.__blend, "BLEND")
  end)
end)

test("Canvas: turning artwork off clears the texture as well as hiding the frame", function()
  fresh()
  local rec = R:New("Fickle", { artTexture = SEED_ID })
  R:Set(rec.id, "artTexture", C.ARTWORK_NONE)
  local f = Canvas:FrameFor(rec.id)
  assertFalse(f.artFrame:IsShown(), "the art frame stayed shown")
  -- A hidden frame still holds its texture's file reference, and this frame is about to be handed
  -- to whatever panel the pool gives it to next.
  assertEqual(f.art:GetTexture(), nil)
end)

test("Canvas: a released frame keeps no artwork for the next panel to inherit", function()
  fresh()
  local rec = R:New("Doomed", { artTexture = SEED_ID })
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
  local first = R:New("Recycled", { artTexture = SEED_ID })
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

-- ── Composite artwork: the Sunn whole-bar rows ───────────────────────────────────
--
-- A composed row is N section files laid flush into one bar, and it is the only row shape in the
-- addon that is not a single texture. The design is that it is treated as ONE virtual image of the
-- bar's size, so every fill, flip, rotation and tint runs untouched and the bar is sliced only
-- afterwards. These cases are what hold that claim up: each one asserts against the arithmetic a
-- single texture would have produced, rather than against a second set of composite rules.

local BAR_ID = "test-composite-bar"
local BAR_PATHS = { "Interface\\Addons\\P\\bar1", "Interface\\Addons\\P\\bar2",
  "Interface\\Addons\\P\\bar3" }

-- A three-section bar at the Sunn declared size: 512x256 per section, so 1536x256 for the bar.
local function barRow(overrides)
  local row = {
    id       = BAR_ID,
    category = "Sunn -> Test",
    label    = "Composite",
    path     = BAR_PATHS[1],
    w        = 1536,
    h        = 256,
    sections = BAR_PATHS,
  }
  for k, v in pairs(overrides or {}) do row[k] = v end
  return row
end

-- The quads sorted by where they sit, so a case can talk about "the left one" without depending on
-- emission order — which rotation and flip legitimately change.
local function spanOf(quads, axis)
  local out = {}
  for i, q in ipairs(quads) do out[i] = { q = q, at = axis == "x" and q.x or q.y } end
  table.sort(out, function(a, b) return a.at < b.at end)
  return out
end

test("Artwork composite: a bar splits into one quad per section", function()
  withRows({ barRow() }, function()
    local art = Art.BuildArtSpec(record({ artTexture = BAR_ID, artFill = "STRETCH" }), 600, 100)
    assertEqual(#art.quads, 3, "a three-section bar did not produce three quads")
    for i, q in ipairs(art.quads) do
      assertEqual(q.path, BAR_PATHS[i], "quad " .. i .. " drew the wrong section file")
    end
  end)
end)

test("Artwork composite: the sections tile the bar rect with no gap and no double-cover", function()
  withRows({ barRow() }, function()
    local art = Art.BuildArtSpec(record({ artTexture = BAR_ID, artFill = "STRETCH" }), 600, 100)
    -- STRETCH covers the panel exactly, so the three quads must partition it: each a third of the
    -- width, full height, and butted edge to edge. A gap draws a bare stripe through the art; an
    -- overlap double-blends the seam and shows as a bright line.
    local sorted = spanOf(art.quads, "x")
    local expectedX = { -200, 0, 200 }
    for i, entry in ipairs(sorted) do
      assertNear(entry.q.width, 200, 1e-9, "quad " .. i .. " is not a third of the panel")
      assertNear(entry.q.height, 100, 1e-9, "quad " .. i .. " is not the full panel height")
      assertNear(entry.q.x, expectedX[i], 1e-9, "quad " .. i .. " sits at the wrong offset")
      assertEqual(entry.q.point, "CENTER", "a quad drifted off the bar rect's own anchor")
    end
  end)
end)

test("Artwork composite: each section samples its whole file", function()
  withRows({ barRow() }, function()
    local art = Art.BuildArtSpec(record({ artTexture = BAR_ID, artFill = "STRETCH" }), 600, 100)
    -- The slice is taken in BAR space and rescaled back to the 0-1 of the one file it came from.
    -- Getting that rescale wrong is the failure that renders each section as a sliver of itself.
    for i, q in ipairs(art.quads) do
      assertEqual(table.concat(q.uv, ","), "0,0,0,1,1,0,1,1", "quad " .. i .. " cropped its file")
    end
  end)
end)

test("Artwork composite: a FILL crop drops the sections it pushed off the panel", function()
  withRows({ barRow() }, function()
    -- The bar is 6:1 and the panel is 2:1, so cover crops to the middle third — which is exactly
    -- section 2's band. The outer two are not drawn at all rather than drawn at zero width.
    local art = Art.BuildArtSpec(record({ artTexture = BAR_ID, artFill = "FILL" }), 600, 300)
    assertEqual(#art.quads, 1, "the cropped-away sections were still drawn")
    assertEqual(art.quads[1].path, BAR_PATHS[2], "the surviving quad is the wrong section")
    assertNear(art.quads[1].width, 600, 1e-9, "the surviving section did not cover the panel")
  end)
end)

test("Artwork composite: a quarter turn stacks the sections instead of ranging them", function()
  withRows({ barRow() }, function()
    local art = Art.BuildArtSpec(
      record({ artTexture = BAR_ID, artFill = "STRETCH", artRotation = 90 }), 600, 100)
    assertEqual(#art.quads, 3)
    -- After a turn the screen's vertical axis runs along the texture's u, so the bar reads top to
    -- bottom. Every quad is full WIDTH and a third of the height — the transpose of the unturned
    -- case, which is the whole point of deriving the placement from composeUV's own permutation.
    for i, q in ipairs(art.quads) do
      assertNear(q.width, 600, 1e-9, "quad " .. i .. " was not turned")
      assertNear(q.height, 100 / 3, 1e-9, "quad " .. i .. " kept its unturned height")
      assertNear(q.x, 0, 1e-9, "quad " .. i .. " ranged horizontally after a turn")
    end
    local sorted = spanOf(art.quads, "y")
    -- Sorted by y ASCENDING and WoW's y runs up, so the last entry is the topmost — section 1.
    assertEqual(sorted[3].q.path, BAR_PATHS[1], "section 1 is not at the top after a 90 turn")
    assertEqual(sorted[1].q.path, BAR_PATHS[3], "section 3 is not at the bottom after a 90 turn")
  end)
end)

test("Artwork composite: a horizontal flip reverses the section order", function()
  withRows({ barRow() }, function()
    local art = Art.BuildArtSpec(
      record({ artTexture = BAR_ID, artFill = "STRETCH", artFlipH = true }), 600, 100)
    local sorted = spanOf(art.quads, "x")
    -- Not special-cased anywhere: the mirror is applied to the placement fractions by the same
    -- helper, in the same order, that mirrors the texture coordinates.
    assertEqual(sorted[1].q.path, BAR_PATHS[3], "section 3 is not leftmost under a flip")
    assertEqual(sorted[3].q.path, BAR_PATHS[1], "section 1 is not rightmost under a flip")
  end)
end)

test("Artwork composite: a tiled bar repeats the whole bar, not each section", function()
  withRows({ barRow() }, function()
    -- Two bar copies across: the panel is twice the bar's native width at scale 1.
    local art = Art.BuildArtSpec(
      record({ artTexture = BAR_ID, artFill = "TILE" }), 3072, 512)
    assertEqual(#art.quads, 6, "two copies of a three-section bar is six quads")
    for i, q in ipairs(art.quads) do
      -- CLAMP horizontally because the horizontal repeat crosses section boundaries and is drawn
      -- as separate quads; REPEAT vertically because that one stays inside a single file.
      assertEqual(q.wrapH, "CLAMP", "quad " .. i .. " would wrap across a section boundary")
      assertEqual(q.wrapV, "REPEAT", "quad " .. i .. " lost its vertical repeat")
    end
    assertFalse(art.tileClamped, "an affordable tile was clamped")
  end)
end)

test("Artwork composite: a tiled bar is clamped rather than allowed to cost hundreds of textures",
  function()
    withRows({ barRow() }, function()
      -- At the smallest scale a bar this wide asks for far more copies than any panel should pay
      -- for. The tile is grown until the budget holds, so the panel stays COVERED — a bald strip
      -- would look broken in a way that fewer, larger tiles does not.
      local art = Art.BuildArtSpec(
        record({ artTexture = BAR_ID, artFill = "TILE", artScale = C.MIN_ART_SCALE }), 4000, 200)
      assertTrue(art.tileClamped, "a runaway tile was not clamped")
      assertTrue(#art.quads <= Art.MAX_ART_QUADS,
        "the clamp let " .. #art.quads .. " quads through a budget of " .. Art.MAX_ART_QUADS)
      -- Still covering: the quads reach both panel edges.
      local sorted = spanOf(art.quads, "x")
      assertNear(sorted[1].q.x - sorted[1].q.width / 2, -2000, 1e-6, "the tiling left a bare edge")
    end)
  end)

test("Artwork composite: the overlap crop moves the sampled window off the transparent band",
  function()
    -- A Sunn theme declaring 25% overlap has 25% of its file height as transparent padding at the
    -- top. The row's `h` is already the CONTENT height, so the fill math above ran in content
    -- space; only the sampled window moves.
    withRows({ barRow({ h = 192, contentV0 = 0.25 }) }, function()
      local art = Art.BuildArtSpec(record({ artTexture = BAR_ID, artFill = "STRETCH" }), 600, 100)
      for i, q in ipairs(art.quads) do
        assertEqual(table.concat(q.uv, ","), "0,0.25,0,1,1,0.25,1,1",
          "quad " .. i .. " sampled the transparent band")
      end
    end)
  end)

test("Artwork composite: a tiled bar drops the overlap crop rather than applying it wrongly",
  function()
    withRows({ barRow({ h = 192, contentV0 = 0.25 }) }, function()
      -- A REPEAT wrap repeats a whole FILE, not a sub-range of one, so the band cannot be kept out
      -- of a tiled repeat. Dropping the crop is the honest answer; applying it would slide every
      -- repeat against its own pixels.
      local art = Art.BuildArtSpec(record({ artTexture = BAR_ID, artFill = "TILE" }), 3072, 512)
      assertNear(art.quads[1].uv[2], 0, 1e-9, "a tiled composite tried to honor the crop")
    end)
  end)

test("Artwork: a single texture is a one-quad spec that matches the flat rect", function()
  fresh()
  -- The invariant that keeps ONE renderer honest: the flat fields are the whole-bar rect, and for
  -- everything that is not a composite that rect IS the only quad. If these ever diverge, the
  -- renderer and the fill math have stopped describing the same picture.
  local art = Art.BuildArtSpec(record({ artTexture = SEED_ID, artFill = "FIT" }), 300, 200)
  assertEqual(#art.quads, 1, "a single piece of art produced more than one quad")
  local q = art.quads[1]
  assertEqual(q.path, art.path)
  assertNear(q.width, art.width, 1e-9)
  assertNear(q.height, art.height, 1e-9)
  assertEqual(q.point, art.point)
  assertNear(q.x, art.x, 1e-9)
  assertNear(q.y, art.y, 1e-9)
  assertEqual(table.concat(q.uv, ","), table.concat(art.uv, ","))
end)

test("Canvas: a composed bar draws one texture per section", function()
  fresh()
  withRows({ barRow() }, function()
    local rec = R:New("Bar", { artTexture = BAR_ID, artFill = "STRETCH", width = 600, height = 100 })
    local f = Canvas:FrameFor(rec.id)
    assertEqual(#f.artTextures, 3, "the renderer did not grow to three textures")
    for i = 1, 3 do
      assertEqual(f.artTextures[i]:GetTexture(), BAR_PATHS[i],
        "texture " .. i .. " drew the wrong section")
    end
  end)
end)

test("Canvas: switching from a bar to a single piece clears the sections it no longer draws",
  function()
    fresh()
    withRows({ barRow() }, function()
      local rec = R:New("Switcher", { artTexture = BAR_ID, artFill = "STRETCH" })
      local f = Canvas:FrameFor(rec.id)
      assertEqual(#f.artTextures, 3)
      R:Set(rec.id, "artTexture", SEED_ID)
      -- Kept, not destroyed — a panel toggling between art types should not churn objects — but
      -- cleared, because a hidden texture still holds its file reference and this frame is pooled.
      assertEqual(f.artTextures[1]:GetTexture(), SEED_PATH, "the single piece did not take slot 1")
      assertEqual(f.artTextures[2]:GetTexture(), nil, "a leftover section kept its texture")
      assertEqual(f.artTextures[3]:GetTexture(), nil, "a leftover section kept its texture")
      assertFalse(f.artTextures[2]:IsShown(), "a leftover section stayed shown")
    end)
  end)

test("Artwork composite: an anchored FIT offsets each section from the same edge", function()
  withRows({ barRow() }, function()
    -- The case the placement math is most likely to get wrong. FIT does not cover the panel, so
    -- unlike STRETCH the bar rect has its own anchor and offset — and every quad has to hang off
    -- the edge THAT point names. Re-anchoring the slices to CENTER would look right at one size and
    -- drift the bar apart on the next resize.
    local art = Art.BuildArtSpec(record({
      artTexture = BAR_ID, artFill = "FIT", artPoint = "TOPLEFT", artX = 12, artY = -8,
    }), 600, 300)
    assertEqual(#art.quads, 3)
    assertEqual(art.point, "TOPLEFT", "the bar rect lost its own anchor")
    -- 6:1 art contained in a 2:1 panel binds on width: 600 x 100, so a third is 200 wide.
    for i, q in ipairs(art.quads) do
      assertEqual(q.point, "TOPLEFT", "quad " .. i .. " was re-anchored")
      assertNear(q.width, 200, 1e-9)
      assertNear(q.height, 100, 1e-9)
      assertNear(q.x, 12 + (i - 1) * 200, 1e-9, "quad " .. i .. " is not flush with its neighbor")
      assertNear(q.y, -8, 1e-9, "quad " .. i .. " drifted vertically")
    end
  end)
end)
