local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse, assertNil =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local S, Artwork = NS.SunnArt, NS.Artwork

-- The Sunn - Viewport Art adapter (issue #12).
--
-- Every fixture below is the REAL registration shape, copied from an installed SunnArt 4.01 and Art
-- Pack 2 and from the community SunnArtErgoZPack. That matters more than usual here: this module's
-- entire job is to read another addon's undocumented globals, so a fixture invented to match our
-- code would test nothing except that the code agrees with itself.

-- The globals the adapter reads are real _G entries in-game, so the mock has to place them there
-- too. Cleared between cases: a leftover pack from an earlier case would make later ones pass for
-- the wrong reason.
local function clearSunn()
  _G.SunnArtPack = nil
  _G.SunnCustomTheme = nil
  _G.SunnCustomPanels = nil
  _G.SunnArt = nil
  -- Drop any rows a previous case injected, so the catalog starts as the bundled set again.
  for i = #Artwork.Catalog, 1, -1 do
    local id = Artwork.Catalog[i].id
    if type(id) == "string" and id:sub(1, #S.ID_PREFIX) == S.ID_PREFIX then
      table.remove(Artwork.Catalog, i)
    end
  end
end

-- SunnArtPack2.lua, verbatim in shape: five `SunnArt.options.args.theme.values[path] = name` lines
-- and nothing else. The pack states no section count, so the adapter must fall back to SunnArt's
-- own default of 3.
local function officialPack()
  _G.SunnArt = {
    options = { args = { theme = { values = {
      ["SunnArtPack2\\blackrock"]      = "Blackrock",
      ["SunnArtPack2\\blueglow"]       = "Blue Glow",
      ["SunnArtPack2\\burningcrusade"] = "Burning Crusade",
      -- SunnArt's reserved flat-fill pseudo-theme, which has no files behind it. The KEY is what
      -- the adapter reserves on and is verbatim; the display name is not reproduced, because
      -- SunnArt spells it in British English and this repo's US-English gate scans whole files
      -- rather than trying to tell authored text from a quoted foreign string. Nothing asserts on
      -- the name, so there is nothing to lose by not copying it.
      ["solid"]                        = "Solid fill",
    } } } },
    ThemeDB = { index = {}, overlap = {}, panels = {}, length = {} },
  }
end

-- SunnArtErgoZPack.lua: a community pack, which self-initializes its own global and therefore works
-- with no SunnArt installed at all. It DOES state section counts.
local function communityPack()
  _G.SunnArtPack = {
    theme  = { ["SunnArtErgoZPack\\wc3_horde\\wc3_horde-"] = "Warcraft III - Horde" },
    panels = { ["SunnArtErgoZPack\\wc3_horde\\wc3_horde-"] = 2 },
    overlap = {}, length = {},
  }
end

-- ── Detection ───────────────────────────────────────────────────────────────────

test("SunnArt: nothing is installed — the adapter is completely silent", function()
  clearSunn()
  assertFalse(S.Installed(), "reported a pack with no Sunn global present")
  assertEqual(#S.Themes(), 0)
  assertEqual(#S.Rows(), 0)
  local before = #Artwork.Catalog
  assertEqual(S.Inject(), 0)
  assertEqual(#Artwork.Catalog, before, "Inject added rows with no pack installed")
end)

test("SunnArt: an official pack is discovered through SunnArt's options table", function()
  clearSunn()
  officialPack()
  assertTrue(S.Installed())
  local themes = S.Themes()
  -- Three real themes; "solid" is reserved and must not become a row.
  assertEqual(#themes, 3)
  for _, t in ipairs(themes) do
    assertTrue(t.file ~= "solid", "the reserved 'solid' pseudo-theme was offered as artwork")
  end
end)

test("SunnArt: a community pack is discovered with NO SunnArt addon present", function()
  -- The case that makes the four-source read worth its length: these packs create their own global
  -- and do not need the base addon, so a lookup that started at SunnArt would find nothing.
  clearSunn()
  communityPack()
  assertTrue(S.Installed())
  assertEqual(#S.Themes(), 1)
  assertEqual(S.Themes()[1].name, "Warcraft III - Horde")
end)

test("SunnArt: both kinds of pack are merged into one list", function()
  clearSunn()
  officialPack()
  communityPack()
  assertEqual(#S.Themes(), 4)
end)

-- ── Section counts ──────────────────────────────────────────────────────────────

test("SunnArt: a theme with no declared section count defaults to 3, as SunnArt does", function()
  clearSunn()
  officialPack()
  for _, t in ipairs(S.Themes()) do assertEqual(t.sections, 3) end
end)

test("SunnArt: a declared section count is honored", function()
  clearSunn()
  communityPack()
  assertEqual(S.Themes()[1].sections, 2)
end)

test("SunnArt: a nonsense section count is clamped rather than trusted", function()
  clearSunn()
  _G.SunnArtPack = {
    theme  = { ["P\\a"] = "A", ["P\\b"] = "B", ["P\\c"] = "C" },
    panels = { ["P\\a"] = 0, ["P\\b"] = 99, ["P\\c"] = "not a number" },
    overlap = {}, length = {},
  }
  local got = {}
  for _, t in ipairs(S.Themes()) do got[t.name] = t.sections end
  assertEqual(got.A, 1)    -- floor of the range
  assertEqual(got.B, 5)    -- SunnArt's documented ceiling
  assertEqual(got.C, 3)    -- unparseable falls back to the default
end)

-- ── Row synthesis ───────────────────────────────────────────────────────────────

test("SunnArt: a 3-section theme yields three section rows AND one composed row", function()
  clearSunn()
  _G.SunnArtPack = {
    theme = { ["SunnArtPack2\\blackrock"] = "Blackrock" },
    panels = { ["SunnArtPack2\\blackrock"] = 3 }, overlap = {}, length = {},
  }
  local rows = S.Rows()
  assertEqual(#rows, 4)

  local byID = {}
  for _, r in ipairs(rows) do byID[r.id] = r end

  -- Per-section rows: one texture each, at the declared section size, named by POSITION.
  local expected = { "Blackrock (left)", "Blackrock (middle)", "Blackrock (right)" }
  for i = 1, 3 do
    local r = byID["sunn-sunnartpack2-blackrock-" .. i]
    assertTrue(r ~= nil, "missing section row " .. i)
    assertEqual(r.label, expected[i])
    assertEqual(r.w, S.SECTION_W)
    assertEqual(r.h, S.SECTION_H)
    assertNil(r.sections, "a per-section row must not carry the composite marker")
    assertEqual(r.path, "Interface\\Addons\\SunnArtPack2\\blackrock" .. i)
  end

  -- The composed row: the whole bar, so the width multiplies and the height does not. It wears the
  -- BARE theme name, so scanning for "Blackrock" finds the whole thing and the parts read as
  -- qualified variants of it.
  local bar = byID["sunn-sunnartpack2-blackrock-bar"]
  assertTrue(bar ~= nil, "missing the composed row")
  assertEqual(bar.label, "Blackrock")
  assertEqual(bar.w, S.SECTION_W * 3)
  assertEqual(bar.h, S.SECTION_H)
  assertEqual(#bar.sections, 3)
  assertEqual(bar.sections[3], "Interface\\Addons\\SunnArtPack2\\blackrock3")
end)

test("SunnArt: a one-section theme yields exactly one row, not a duplicate pair", function()
  clearSunn()
  _G.SunnArtPack = {
    theme = { ["P\\solo"] = "Solo" }, panels = { ["P\\solo"] = 1 }, overlap = {}, length = {},
  }
  local rows = S.Rows()
  assertEqual(#rows, 1)
  assertEqual(rows[1].id, "sunn-p-solo")
  assertEqual(rows[1].label, "Solo")           -- no "1/1", no "(full bar)"
  assertNil(rows[1].sections, "a single section is not a composite")
end)

test("SunnArt: the texture path is extensionless and rooted at Interface\\Addons", function()
  -- SunnArt_Core.lua:309 builds exactly this, and WoW resolves the extension itself. Appending
  -- .tga here would break every pack that ships .blp, and rooting it at this addon cannot reach
  -- another addon's folder at all.
  assertEqual(S.SectionPath("SunnArtPack2\\blackrock", 2),
    "Interface\\Addons\\SunnArtPack2\\blackrock2")
end)

test("SunnArt: rows are grouped under a readable pack category", function()
  clearSunn()
  officialPack()
  local rows = S.Rows()
  assertEqual(rows[1].category, "Sunn -> Art Pack 2")
end)

test("SunnArt: the order is stable across scans", function()
  -- Themes come out of hash tables, whose iteration order is an accident. A dropdown that reorders
  -- itself between logins reads as a bug.
  clearSunn()
  officialPack()
  communityPack()
  local first = {}
  for i, r in ipairs(S.Rows()) do first[i] = r.id end
  for _ = 1, 5 do
    local again = S.Rows()
    for i, r in ipairs(again) do assertEqual(r.id, first[i], "row order moved between scans") end
  end
end)

-- ── Catalog integration ─────────────────────────────────────────────────────────

test("SunnArt: injected rows resolve through the normal artwork seam", function()
  clearSunn()
  officialPack()
  S.Inject()

  local row = Artwork.Entry("sunn-sunnartpack2-blackrock-1")
  assertTrue(row ~= nil, "an injected row is not findable by id")
  local spec = Artwork.BuildArtSpec({
    artTexture = "sunn-sunnartpack2-blackrock-1",
    artFill = "STRETCH", artAlpha = 1, artLayer = "ARTWORK", artBlend = "BLEND",
    artColor = { r = 1, g = 1, b = 1, a = 1 },
  }, 400, 200)
  assertTrue(spec ~= nil, "an injected row produced no art spec")
  assertEqual(spec.path, "Interface\\Addons\\SunnArtPack2\\blackrock1")
end)

test("SunnArt: Inject is idempotent — a re-scan replaces rather than duplicates", function()
  clearSunn()
  officialPack()
  local n = S.Inject()
  local afterFirst = #Artwork.Catalog
  assertEqual(S.Inject(), n)
  assertEqual(#Artwork.Catalog, afterFirst, "a second Inject grew the catalog")
end)

test("SunnArt: injection never disturbs the bundled catalog", function()
  clearSunn()
  local bundled = #Artwork.Catalog
  officialPack()
  S.Inject()
  clearSunn()                                  -- clearSunn removes only sunn- rows
  assertEqual(#Artwork.Catalog, bundled, "the bundled catalog changed size")
end)

test("SunnArt: an uninstalled pack degrades to drawing nothing, and recovers", function()
  -- The acceptance criterion that matters most for saved variables: a panel keeps its stored id
  -- when the pack is gone, draws nothing rather than erroring, and comes back when it returns.
  clearSunn()
  local rec = {
    artTexture = "sunn-sunnartpack2-blackrock-1",
    artFill = "STRETCH", artAlpha = 1, artLayer = "ARTWORK", artBlend = "BLEND",
    artColor = { r = 1, g = 1, b = 1, a = 1 },
  }
  assertNil(Artwork.BuildArtSpec(rec, 400, 200), "a missing pack should draw nothing")

  officialPack()
  S.Inject()
  local spec = Artwork.BuildArtSpec(rec, 400, 200)
  assertTrue(spec ~= nil, "the panel did not recover when the pack was reinstalled")
  assertEqual(spec.path, "Interface\\Addons\\SunnArtPack2\\blackrock1")
  clearSunn()
end)

-- ── Section naming ──────────────────────────────────────────────────────────────

test("SunnArt: sections are named by position, not by number", function()
  -- "Blackrock (left)" says which piece you are picking. "Blackrock 2/3" made a player count.
  local function labelsFor(n)
    clearSunn()
    _G.SunnArtPack = {
      theme = { ["P\\t"] = "T" }, panels = { ["P\\t"] = n }, overlap = {}, length = {},
    }
    local out = {}
    for _, r in ipairs(S.Rows()) do out[#out + 1] = r.label end
    return out
  end

  local two = labelsFor(2)
  assertEqual(two[1], "T (left)")
  assertEqual(two[2], "T (right)")
  assertEqual(two[3], "T")                       -- the composed bar, bare

  local three = labelsFor(3)
  assertEqual(three[1], "T (left)")
  assertEqual(three[2], "T (middle)")
  assertEqual(three[3], "T (right)")

  -- More than one middle: numbering them is what keeps two rows from sharing a label.
  local five = labelsFor(5)
  assertEqual(five[1], "T (left)")
  assertEqual(five[2], "T (middle 1)")
  assertEqual(five[3], "T (middle 2)")
  assertEqual(five[4], "T (middle 3)")
  assertEqual(five[5], "T (right)")
  local seen = {}
  for _, l in ipairs(five) do
    assertTrue(not seen[l], "two sections share the label " .. l)
    seen[l] = true
  end
  clearSunn()
end)

test("SunnArt: the dropdown renders as Sunn -> <Pack>: <Texture>", function()
  clearSunn()
  officialPack()
  S.Inject()
  local found
  for _, entry in ipairs(Artwork.List()) do
    if entry.id == "sunn-sunnartpack2-blackrock-1" then found = entry.label end
  end
  assertEqual(found, "Sunn -> Art Pack 2: Blackrock (left)")
  clearSunn()
end)

-- ── Autosize ────────────────────────────────────────────────────────────────────

local R = NS.Registry

local function panel(name, fields)
  local rec = R:New(name)
  for k, v in pairs(fields or {}) do R:Set(rec.id, k, v) end
  return R:Get(rec.id)
end

test("Autosize: off by default, so no upgrade reshapes a panel anyone already had", function()
  R:DeleteAll()
  assertFalse(NS.Constants.PANEL_TEMPLATE.artAutosize)
  local rec = panel("Untouched", { width = 400, height = 137 })
  R:Set(rec.id, "artTexture", "class-warrior")
  assertEqual(R:Get(rec.id).height, 137, "the height moved with autosize off")
end)

test("Autosize: square bundled art gives a 1:1 panel", function()
  R:DeleteAll()
  local rec = panel("Square", { width = 300, artAutosize = true })
  R:Set(rec.id, "artTexture", "class-warrior")     -- 1024x1024
  assertEqual(R:Get(rec.id).height, 300)
end)

test("Autosize: a Sunn section gives 2:1, and its composed bar gives 6:1", function()
  R:DeleteAll()
  clearSunn()
  _G.SunnArtPack = {
    theme = { ["SunnArtPack2\\blackrock"] = "Blackrock" },
    panels = { ["SunnArtPack2\\blackrock"] = 3 }, overlap = {}, length = {},
  }
  S.Inject()

  -- 512x256 -> half the width.
  local sec = panel("Section", { width = 600, artAutosize = true })
  R:Set(sec.id, "artTexture", "sunn-sunnartpack2-blackrock-1")
  assertEqual(R:Get(sec.id).height, 300)

  -- The bar is 1536x256, so a sixth. Proving the composed row's native size is the BAR's and not a
  -- section's — the whole reason w multiplies by the section count.
  local bar = panel("Bar", { width = 600, artAutosize = true })
  R:Set(bar.id, "artTexture", "sunn-sunnartpack2-blackrock-bar")
  assertEqual(R:Get(bar.id).height, 100)
  clearSunn()
end)

test("Autosize: a custom path falls back to the nominal square", function()
  R:DeleteAll()
  local rec = panel("Custom", { width = 250, artAutosize = true, artTexture = "Custom" })
  R:Set(rec.id, "artCustomPath", "Interface\\Whatever\\Thing")
  assertEqual(R:Get(rec.id).height, 250)
end)

test("Autosize: changing the width re-derives the height", function()
  R:DeleteAll()
  clearSunn()
  _G.SunnArtPack = {
    theme = { ["P\\x"] = "X" }, panels = { ["P\\x"] = 1 }, overlap = {}, length = {},
  }
  S.Inject()
  local rec = panel("Resized", { width = 400, artAutosize = true })
  R:Set(rec.id, "artTexture", "sunn-p-x")          -- 512x256, so 2:1
  assertEqual(R:Get(rec.id).height, 200)
  R:Set(rec.id, "width", 800)
  assertEqual(R:Get(rec.id).height, 400, "the height did not follow the width")
  clearSunn()
end)

test("Autosize: setting the height by hand is NOT fought back", function()
  -- height is deliberately absent from C.ART_AUTOSIZE_FIELDS: re-deriving on a height write would
  -- undo the user's own edit on every keystroke. Autosize reasserts on the next width/art change.
  R:DeleteAll()
  local rec = panel("Manual", { width = 300, artAutosize = true, artTexture = "class-warrior" })
  assertEqual(R:Get(rec.id).height, 300)
  R:Set(rec.id, "height", 120)
  assertEqual(R:Get(rec.id).height, 120)
  R:Set(rec.id, "width", 300)                      -- same width, but an art-affecting write
  assertEqual(R:Get(rec.id).height, 300, "autosize did not reassert itself")
end)

test("Autosize: art that is not installed leaves the panel's shape alone", function()
  -- Uninstalling a pack must not silently reshape a layout, and reinstalling it must not have to
  -- un-reshape one.
  R:DeleteAll()
  clearSunn()
  local rec = panel("Missing", { width = 400, height = 90, artAutosize = true })
  R:Set(rec.id, "artTexture", "None")
  assertEqual(R:Get(rec.id).height, 90)
end)

test("Autosize: the derived height is clamped like any stored height", function()
  R:DeleteAll()
  clearSunn()
  -- A 1x4096 strip against a wide panel would derive a height far past C.MAX_SIZE. ApplyAutosize
  -- runs BEFORE Sanitize precisely so the clamp still gets the last word.
  _G.SunnArtPack = {
    theme = { ["P\\tall"] = "Tall" }, panels = { ["P\\tall"] = 1 }, overlap = {}, length = {},
  }
  S.Inject()
  local row = Artwork.Entry("sunn-p-tall")
  row.w, row.h = 1, 4096                            -- an extreme aspect, on purpose
  local rec = panel("Clamped", { width = 400, artAutosize = true })
  R:Set(rec.id, "artTexture", "sunn-p-tall")
  local h = R:Get(rec.id).height
  assertTrue(h <= NS.Constants.MAX_SIZE, "the derived height escaped the clamp: " .. tostring(h))
  assertTrue(h >= NS.Constants.MIN_SIZE, "the derived height fell below the floor")
  clearSunn()
end)
