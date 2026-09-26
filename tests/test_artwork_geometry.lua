-- Artwork.BuildArtSpec for a single texture: the five fills, resize, position, UV composition, the
-- tint and degenerate input. Peeled out of tests/test_artwork.lua (layout-§1, anti-pattern #53)
-- along the catalog / geometry seam that split modules/Artwork.lua from modules/ArtworkGeometry.lua;
-- that suite keeps the catalog, upgrade inertness, persistence, the renderer and the composite
-- cases. The runner lists this suite straight after it.

local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse, assertNear =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNear
local C, Util, Art = NS.Constants, NS.Util, NS.Artwork

-- ── Fixtures ────────────────────────────────────────────────────────────────────
--
-- record, the seed row, withRows and withArt are the same fixtures tests/test_artwork.lua declares,
-- and its header carries the reasoning behind each; they are restated here, not shared, so each
-- suite stays loadable on its own. The panel x art matrix and the uv helpers below them are this
-- suite's alone, and moved here whole.

-- A record with the shipped defaults under it (Sanitize guarantees every field is present).
local function record(overrides)
  local rec = Util.DeepCopy(C.PANEL_TEMPLATE)
  for k, v in pairs(overrides or {}) do rec[k] = v end
  return rec
end

-- A real shipped row, used wherever a test needs "some valid catalog art" rather than a specific
-- piece. Declared above withRows/withArt, because a Lua local is only visible after its declaration.
local SEED_ID   = "class-warrior"
local SEED_FILE = "class\\warrior"                            -- the stem, not the id

-- Append catalog rows for the duration of one test, and take them off again even when it throws.
local function withRows(rows, fn)
  local Catalog = Art.Catalog
  local base = #Catalog
  for _, row in ipairs(rows) do Catalog[#Catalog + 1] = row end
  local ok, err = pcall(fn)
  for i = #Catalog, base + 1, -1 do Catalog[i] = nil end
  if not ok then error(err, 0) end
end

-- One fixture row of a given native size, pointing at the real shipped .tga.
local TEST_ART_ID = "pm-test-art"
local function withArt(w, h, tintable, fn)
  withRows({ { id = TEST_ART_ID, category = "General", label = "Test Art", file = SEED_FILE,
               w = w, h = h, tintable = tintable } }, fn)
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
  -- on which the user meant. Honoring scale here would draw art that no longer matches the panel
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

test("Artwork: position is honored by STATIC and FIT, which leave room to move", function()
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
  assertUV(specFor({ artTexture = SEED_ID, artFill = "FIT" }).uv, { 0, 0, 0, 1, 1, 0, 1, 1 })
end)

test("Artwork: one quarter turn reproduces C.ACCENT_TEXCOORD_ROT90 exactly", function()
  -- The accent bars already turn a horizontal statusbar texture onto a vertical edge with this
  -- permutation. If artwork's rotation is a different transform from that one, then two things in
  -- the same addon mean different things by "90 degrees" — so this equality is the contract, and
  -- Artwork.lua's own comment asserts it.
  local spec = specFor({ artTexture = SEED_ID, artFill = "FIT", artRotation = 90 })
  assertUV(spec.uv, C.ACCENT_TEXCOORD_ROT90, "quarter turn")
end)

test("Artwork: half a turn is the identity quad reversed", function()
  local spec = specFor({ artTexture = SEED_ID, artFill = "FIT", artRotation = 180 })
  assertUV(spec.uv, { 1, 1, 1, 0, 0, 1, 0, 0 }, "half turn")
end)

test("Artwork: three quarter turns are the quarter turn applied three times", function()
  local spec = specFor({ artTexture = SEED_ID, artFill = "FIT", artRotation = 270 })
  assertUV(spec.uv, { 1, 0, 0, 0, 1, 1, 0, 1 }, "three quarter turns")
end)

test("Artwork: a horizontal flip swaps the left and right columns", function()
  local spec = specFor({ artTexture = SEED_ID, artFill = "FIT", artFlipH = true })
  assertUV(spec.uv, { 1, 0, 1, 1, 0, 0, 0, 1 }, "flipH")
end)

test("Artwork: a vertical flip swaps the top and bottom rows", function()
  local spec = specFor({ artTexture = SEED_ID, artFill = "FIT", artFlipV = true })
  assertUV(spec.uv, { 0, 1, 0, 0, 1, 1, 1, 0 }, "flipV")
end)

test("Artwork: flipping both ways is the same as turning it half way round", function()
  local both = specFor({ artTexture = SEED_ID, artFill = "FIT",
                         artFlipH = true, artFlipV = true })
  local half = specFor({ artTexture = SEED_ID, artFill = "FIT", artRotation = 180 })
  assertUV(both.uv, half.uv, "flipH+flipV vs 180")
end)

test("Artwork: flips are applied BEFORE the turn, and the order is part of the contract", function()
  -- Flip-then-rotate is not the same transform as rotate-then-flip. Picking one and stating it is
  -- the only way the two checkboxes and the dropdown mean something stable together.
  local spec = specFor({ artTexture = SEED_ID, artFill = "FIT",
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
  local spec = specFor({ artTexture = SEED_ID, artFill = "FIT", artRotation = 45 })
  assertUV(spec.uv, C.ACCENT_TEXCOORD_FLAT, "45 degrees")
end)

-- ── Color ───────────────────────────────────────────────────────────────────────

test("Artwork: the tint carries the stored color through", function()
  -- Through a TINTABLE fixture: every shipped row is full-color art, which deliberately forces the
  -- tint to white, so the shipped catalog cannot exercise this path at all.
  withArt(512, 512, true, function()
    local spec = specFor({ artTexture = TEST_ART_ID, artColor = { 0.2, 0.4, 0.6, 1 } })
    assertNear(spec.color[1], 0.2)
    assertNear(spec.color[2], 0.4)
    assertNear(spec.color[3], 0.6)
  end)
end)

test("Artwork: artAlpha multiplies the tint's own alpha rather than replacing it", function()
  -- The color picker's alpha and the opacity slider compose, so neither silently wins.
  local spec = specFor({ artTexture = SEED_ID, artColor = { 1, 1, 1, 0.5 }, artAlpha = 0.5 })
  assertNear(spec.color[4], 0.25)
end)

test("Artwork: artClassColor overrides the RGB and keeps the computed alpha", function()
  -- Through Util.ResolveColor, so class color cost one C.COLOR_FIELDS row and no code in Artwork.
  -- The mock player is a Priest (1, 1, 1) against a stored black, so the override is visible.
  local spec = specFor({
    artTexture = SEED_ID, artColor = { 0, 0, 0, 0.5 }, artClassColor = true, artAlpha = 0.5,
  })
  assertNear(spec.color[1], 1)
  assertNear(spec.color[2], 1)
  assertNear(spec.color[3], 1)
  assertNear(spec.color[4], 0.25)
end)

test("Artwork: the class-color row is wired up in C.COLOR_FIELDS", function()
  assertEqual(C.COLOR_FIELDS.artColor, "artClassColor")
end)

test("Artwork: the tint reaches every piece, full-color included", function()
  -- This REPLACES a pair of cases asserting the opposite. Full-color art used to have its RGB
  -- forced to white, on the reasoning that multiplying finished art by a color can only muddy it.
  -- That is still true, which is why Desaturate exists — but the answer is now to let the user
  -- desaturate and tint rather than to refuse the tint. The default tint is white, a no-op, so
  -- nothing changes for anyone who has not asked for a color.
  withArt(128, 128, false, function()
    local spec = Art.BuildArtSpec(record({
      artTexture = TEST_ART_ID, artColor = { 1, 0, 0, 0.8 }, artAlpha = 0.5,
    }), 200, 200)
    assertNear(spec.color[1], 1)
    assertNear(spec.color[2], 0)
    assertNear(spec.color[3], 0)
    -- The two opacities still compose rather than one winning.
    assertNear(spec.color[4], 0.4)
  end)
end)

test("Artwork: class color reaches full-color art too", function()
  withArt(128, 128, false, function()
    local spec = Art.BuildArtSpec(record({
      artTexture = TEST_ART_ID, artColor = { 0, 0, 0, 1 }, artClassColor = true,
    }), 200, 200)
    -- Whatever the mock's class color is, it is not the stored black it replaced.
    assertTrue(spec.color[1] + spec.color[2] + spec.color[3] > 0,
      "class color did not reach full-color art")
  end)
end)

test("Artwork: desaturate and blend mode are resolved into the spec", function()
  -- Resolved by BuildArtSpec rather than read off the record by the renderer, so "what does this
  -- panel draw" stays one pure answer the headless suite can assert on.
  withArt(128, 128, false, function()
    local spec = Art.BuildArtSpec(record({ artTexture = TEST_ART_ID }), 200, 200)
    assertEqual(spec.desaturate, false, "default is not desaturated")
    assertEqual(spec.blend, "BLEND", "default blend is not Normal")

    local glow = Art.BuildArtSpec(record({
      artTexture = TEST_ART_ID, artDesaturate = true, artBlend = "ADD",
    }), 200, 200)
    assertEqual(glow.desaturate, true)
    assertEqual(glow.blend, "ADD")

    -- A junk blend falls back rather than reaching SetBlendMode, which errors on an unknown mode.
    local junk = Art.BuildArtSpec(record({
      artTexture = TEST_ART_ID, artBlend = "NONSENSE",
    }), 200, 200)
    assertEqual(junk.blend, "BLEND", "an invalid blend mode was not defaulted")
  end)
end)

test("Artwork: a custom path takes the tint like anything else", function()
  -- Once the only distinction the catalog drew here is gone, a user's own file is not a special
  -- case at all; it takes the tint on exactly the same terms as a bundled piece.
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
  local rec = record({ artTexture = SEED_ID, artFill = "TILE" })
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
                 file = SEED_FILE, tintable = true } }, function()
      local spec = Art.BuildArtSpec(
        record({ artTexture = "pm-sizeless-art", artFill = "STATIC" }), 200, 200)
      assertTrue(spec ~= nil, "a row with no declared size drew nothing at all")
      assertNear(spec.width, Art.CUSTOM_NATIVE_SIZE)
      assertNear(spec.height, Art.CUSTOM_NATIVE_SIZE)
    end)
  end)

test("Artwork.BuildArtSpec: a non-table record is nil, not a crash", function()
  assertEqual(Art.BuildArtSpec(nil, 200, 200), nil)
  assertEqual(Art.BuildArtSpec(SEED_ID, 200, 200), nil)
end)

test("Artwork.BuildArtSpec: an unknown fill or layer falls back to the template", function()
  -- A hand-edited SavedVariables file must not reach the renderer with artFill = "COVER": every
  -- branch computes a different rectangle, and an unknown token would produce a nil size that lands
  -- in SetSize — a Lua error inside a paint, which leaves the panel half-drawn.
  local spec = specFor({ artTexture = SEED_ID, artFill = "COVER",
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
    local spec = specFor({ artTexture = SEED_ID, artLayer = layer })
    assertEqual(spec.layer, layer)
    assertEqual(spec.level, C.ART_FRAME_LEVEL[layer], "level for " .. layer)
  end
end)
