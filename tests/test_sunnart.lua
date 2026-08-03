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
  _G.SunnCustomOverlap = nil
  _G.SunnArt = nil

  -- Two defaults that every case starts from, and both are opt-IN rather than opt-out.
  --
  -- The MANIFEST is emptied. It knows 88 real themes, so leaving it live would fold six extra
  -- themes into a fixture that registered three and make every count assertion about the fixture
  -- into an assertion about somebody else's art packs. Cases that are about the manifest take it
  -- back with withManifest().
  --
  -- The ROSTER is made unreadable. Compat.AddOnFolders returns nil when the API is absent, which is
  -- the documented "cannot tell", and the folder gate then offers the theme. That is the right
  -- default for the discovery cases below: they are about reading another addon's registrations,
  -- not about which folders exist, and requiring each to also declare a folder would put a second
  -- unrelated concern in every fixture. Cases that ARE about the gate call installed(), which turns
  -- the roster back on with exactly the folders they name.
  NS.SunnArtPacks = {}
  T.mocks.__addons = nil
  -- Drop any rows a previous case injected, so the catalog starts as the bundled set again.
  for i = #Artwork.Catalog, 1, -1 do
    local id = Artwork.Catalog[i].id
    if type(id) == "string" and id:sub(1, #S.ID_PREFIX) == S.ID_PREFIX then
      table.remove(Artwork.Catalog, i)
    end
  end
end

-- Turn the addon roster ON, listing exactly these folders as present on disk.
--
-- Calling it at all is what switches the folder gate from "cannot tell" to a real answer, so a case
-- that calls it is opting into being gated — and a folder it does not name is a folder the player
-- does not have. Additive, so a case can build the roster up across several calls.
local function installed(...)
  T.mocks.__addons = T.mocks.__addons or {}
  for _, folder in ipairs({ ... }) do
    T.mocks.__addons[#T.mocks.__addons + 1] = folder
  end
end

-- Put the REAL manifest back for one case. See clearSunn for why it is empty by default.
local REAL_PACKS = NS.SunnArtPacks

local function withManifest(fn)
  NS.SunnArtPacks = REAL_PACKS
  local ok, err = pcall(fn)
  NS.SunnArtPacks = {}
  if not ok then error(err, 0) end
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

test("SunnArt: a multi-section theme yields ONE row -- the whole bar", function()
  clearSunn()
  _G.SunnArtPack = {
    theme = { ["SunnArtPack2\\blackrock"] = "Blackrock" },
    panels = { ["SunnArtPack2\\blackrock"] = 3 }, overlap = {}, length = {},
  }
  local rows = S.Rows()
  -- Per-section rows are deliberately gone. They turned the twelve official packs' 88 themes into
  -- 270 dropdown entries, four fifths of them fragments of something listed three lines above.
  assertEqual(#rows, 1, "a theme contributed more than the bar")

  local bar = rows[1]
  assertEqual(bar.id, "sunn-sunnartpack2-blackrock-bar")
  assertEqual(bar.label, "Blackrock")            -- the bare theme name; nothing to qualify now
  -- The whole bar, so the width multiplies and the height does not.
  assertEqual(bar.w, S.SECTION_W * 3)
  assertEqual(bar.h, S.SECTION_H)
  assertEqual(#bar.sections, 3)
  assertEqual(bar.sections[1], "Interface\\Addons\\SunnArtPack2\\blackrock1")
  assertEqual(bar.sections[3], "Interface\\Addons\\SunnArtPack2\\blackrock3")
end)

test("SunnArt: no row anywhere points at a single section of a multi-section theme", function()
  clearSunn()
  officialPack()
  S.Inject()
  -- The property a player sees, asserted over the injected catalog rather than over S.Rows: every
  -- Sunn entry in the dropdown is a whole theme.
  for _, row in ipairs(Artwork.Catalog) do
    if type(row.id) == "string" and row.id:sub(1, #S.ID_PREFIX) == S.ID_PREFIX then
      assertFalse(row.id:match("%-%d$") ~= nil, "a per-section row survived: " .. row.id)
      assertFalse(row.label:find("(left)", 1, true) ~= nil, "a positional label survived")
    end
  end
  clearSunn()
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

  local row = Artwork.Entry("sunn-sunnartpack2-blackrock-bar")
  assertTrue(row ~= nil, "an injected row is not findable by id")
  local spec = Artwork.BuildArtSpec({
    artTexture = "sunn-sunnartpack2-blackrock-bar",
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
    artTexture = "sunn-sunnartpack2-blackrock-bar",
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

-- ── Labels ──────────────────────────────────────────────────────────────────────

test("SunnArt: a theme is labeled by its own name, whatever its section count", function()
  -- Positional section labels ("T (left)", "T (middle 2)") went with the per-section rows. A theme
  -- is now one entry under one name, and the count is invisible in the dropdown.
  local function labelsFor(n)
    clearSunn()
    _G.SunnArtPack = {
      theme = { ["P\\t"] = "T" }, panels = { ["P\\t"] = n }, overlap = {}, length = {},
    }
    local out = {}
    for _, r in ipairs(S.Rows()) do out[#out + 1] = r.label end
    return out
  end

  for _, n in ipairs({ 1, 2, 3, 5 }) do
    local labels = labelsFor(n)
    assertEqual(#labels, 1, "a " .. n .. "-section theme produced more than one row")
    assertEqual(labels[1], "T")
  end
  clearSunn()
end)

test("SunnArt: the dropdown renders as Sunn -> <Pack>: <Texture>", function()
  clearSunn()
  officialPack()
  S.Inject()
  local found
  for _, entry in ipairs(Artwork.List()) do
    if entry.id == "sunn-sunnartpack2-blackrock-bar" then found = entry.label end
  end
  assertEqual(found, "Sunn -> Art Pack 2: Blackrock")
  clearSunn()
end)

-- ── Fit to artwork ──────────────────────────────────────────────────────────────
--
-- An ACTION, not a stored mode, and it adopts the artwork's EXACT pixel size on both axes.
--
-- Both halves of that were different once. It was a boolean field, so the panel reshaped itself on
-- every width or artwork change; and it derived only the height, keeping the width the user had
-- chosen. The cases below are what changed with it: nothing re-derives on its own, and fitting
-- moves both axes.

local R = NS.Registry

local function panel(name, fields)
  local rec = R:New(name)
  for k, v in pairs(fields or {}) do R:Set(rec.id, k, v) end
  return R:Get(rec.id)
end

test("Fit: nothing is reshaped until it is asked for", function()
  R:DeleteAll()
  -- The property the old boolean needed a default of `false` to get: picking artwork must never
  -- move a size the user set.
  local rec = panel("Untouched", { width = 400, height = 137 })
  R:Set(rec.id, "artTexture", "class-warrior")
  assertEqual(R:Get(rec.id).height, 137, "choosing artwork reshaped the panel on its own")
  R:Set(rec.id, "width", 800)
  assertEqual(R:Get(rec.id).height, 137, "resizing the width reshaped the panel on its own")
end)

test("Fit: there is no artAutosize field left to set", function()
  -- The record field and its re-derive trigger are both gone. A stale `/pm panel X artAutosize on`
  -- has to be REFUSED rather than silently stored on the record, where nothing would ever read it.
  assertNil(NS.Constants.PANEL_TEMPLATE.artAutosize)
  assertNil(NS.Constants.PANEL_FIELD_TYPE.artAutosize)
  assertNil(NS.Constants.ART_AUTOSIZE_FIELDS)
  R:DeleteAll()
  local rec = panel("NoField", { width = 300 })
  local ok = R:Set(rec.id, "artAutosize", true)
  assertFalse(ok, "artAutosize was still accepted as a field")
end)

test("Fit: the panel takes the artwork's exact pixel size, on BOTH axes", function()
  R:DeleteAll()
  -- Not "derive the height from the width" — the whole size. A 1024x1024 piece gives a 1024x1024
  -- panel whatever the panel was before, which is large, and is exactly what the button promises.
  local rec = panel("Square", { width = 300, height = 40, artTexture = "class-warrior" })
  local ok, w, h = R:FitToArtwork(rec.id)
  assertTrue(ok)
  assertEqual(w, 1024, "the width was left alone")
  assertEqual(h, 1024)
  local live = R:Get(rec.id)
  assertEqual(live.width, 1024)
  assertEqual(live.height, 1024)
end)

test("Fit: a composed bar takes the VIRTUAL bar's size, not one section's", function()
  R:DeleteAll()
  clearSunn()
  _G.SunnArtPack = {
    theme = { ["SunnArtPack2\\blackrock"] = "Blackrock" },
    panels = { ["SunnArtPack2\\blackrock"] = 3 }, overlap = {}, length = {},
  }
  S.Inject()

  -- Three 512x256 sections laid flush is 1536x256, and that is the panel. Proving the composed
  -- row's native size is the BAR's — the whole reason w multiplies by the section count.
  local bar = panel("Bar", { width = 600, height = 40,
                             artTexture = "sunn-sunnartpack2-blackrock-bar" })
  assertTrue(R:FitToArtwork(bar.id))
  local live = R:Get(bar.id)
  assertEqual(live.width, 1536)
  assertEqual(live.height, 256)
  clearSunn()
end)

test("Fit: an overlap crop is fitted to the VISIBLE art, and lands on a whole pixel", function()
  R:DeleteAll()
  clearSunn()
  -- 256 * (1 - 0.29297) = 181.00, which is where the rounding in ApplyArtSize earns its keep: a
  -- fractional frame size renders on a half-pixel boundary and blurs the border.
  _G.SunnArtPack = {
    theme = { ["P\\crop"] = "Crop" }, panels = { ["P\\crop"] = 1 },
    overlap = { ["P\\crop"] = 29.297 }, length = {},
  }
  S.Inject()
  local rec = panel("Cropped", { width = 100, artTexture = "sunn-p-crop" })
  assertTrue(R:FitToArtwork(rec.id))
  local live = R:Get(rec.id)
  assertEqual(live.width, 512)
  assertEqual(live.height, 181, "the transparent band was included in the fitted size")
  assertEqual(live.height, math.floor(live.height), "the height is not a whole pixel")
  clearSunn()
end)

test("Fit: a custom path falls back to the nominal square", function()
  R:DeleteAll()
  -- Nothing can measure a user's own file, so Artwork.CUSTOM_NATIVE_SIZE is what it fits to.
  local rec = panel("Custom", { width = 250, artTexture = "Custom",
                                artCustomPath = "Interface\\Whatever\\Thing" })
  assertTrue(R:FitToArtwork(rec.id))
  local live = R:Get(rec.id)
  assertEqual(live.width, NS.Artwork.CUSTOM_NATIVE_SIZE)
  assertEqual(live.height, NS.Artwork.CUSTOM_NATIVE_SIZE)
end)

test("Fit: a resized panel returns to the artwork's size when it is pressed again", function()
  R:DeleteAll()
  clearSunn()
  _G.SunnArtPack = {
    theme = { ["P\\x"] = "X" }, panels = { ["P\\x"] = 1 }, overlap = {}, length = {},
  }
  S.Inject()
  local rec = panel("Resized", { width = 400, artTexture = "sunn-p-x" })   -- 512x256
  assertTrue(R:FitToArtwork(rec.id))
  assertEqual(R:Get(rec.id).width, 512)
  assertEqual(R:Get(rec.id).height, 256)

  -- Resizing afterwards sticks: nothing re-fits on its own.
  R:Set(rec.id, "width", 800)
  assertEqual(R:Get(rec.id).width, 800)
  assertEqual(R:Get(rec.id).height, 256, "the height moved without being asked")
  assertTrue(R:FitToArtwork(rec.id))
  assertEqual(R:Get(rec.id).width, 512, "pressing it again did not restore the artwork's size")
  clearSunn()
end)

test("Fit: a size set by hand afterwards stays put", function()
  R:DeleteAll()
  local rec = panel("Manual", { width = 300, artTexture = "class-warrior" })
  assertTrue(R:FitToArtwork(rec.id))
  assertEqual(R:Get(rec.id).height, 1024)
  -- The whole reason this is a button. As a flag, `height` had to be carved out of the re-derive
  -- set or typing one undid itself on every keystroke; now it is an ordinary field again.
  R:Set(rec.id, "height", 120)
  assertEqual(R:Get(rec.id).height, 120)
  R:Set(rec.id, "width", 300)
  assertEqual(R:Get(rec.id).height, 120, "something re-derived the size behind the user")
end)

test("Fit: pressing it twice changes nothing the second time", function()
  R:DeleteAll()
  local rec = panel("Idempotent", { width = 300, artTexture = "class-warrior" })
  assertTrue(R:FitToArtwork(rec.id))
  -- False plus a reason, not a silent no-op: the button says so rather than looking broken.
  local ok, why = R:FitToArtwork(rec.id)
  assertFalse(ok)
  assertEqual(why, "already fitted to its artwork")
end)

test("Fit: a panel with no artwork is told so rather than reshaped", function()
  -- Also covers art that is not installed, which resolves to no path by the same route: uninstalling
  -- a pack must not let this button collapse a panel.
  R:DeleteAll()
  clearSunn()
  local rec = panel("Bare", { width = 400, height = 90 })
  local ok, why = R:FitToArtwork(rec.id)
  assertFalse(ok)
  assertEqual(why, "this panel draws no artwork to fit to")
  local live = R:Get(rec.id)
  assertEqual(live.width, 400, "a panel with no art was reshaped anyway")
  assertEqual(live.height, 90)
end)

test("Fit: an unknown panel is refused by name", function()
  R:DeleteAll()
  local ok, why = R:FitToArtwork("NoSuchPanel")
  assertFalse(ok)
  assertTrue(why:find("NoSuchPanel", 1, true) ~= nil, "the error did not name the panel")
end)

test("Fit: the adopted size is clamped like any stored size", function()
  R:DeleteAll()
  clearSunn()
  -- A 1x4096 strip would adopt a height far past C.MAX_SIZE and a width below C.MIN_SIZE.
  -- FitToArtwork sanitizes AFTER the sizing precisely so the clamp still gets the last word, on
  -- both axes.
  _G.SunnArtPack = {
    theme = { ["P\\tall"] = "Tall" }, panels = { ["P\\tall"] = 1 }, overlap = {}, length = {},
  }
  S.Inject()
  local row = Artwork.Entry("sunn-p-tall")
  row.w, row.h = 1, 4096                            -- an extreme aspect, on purpose
  local rec = panel("Clamped", { width = 400, artTexture = "sunn-p-tall" })
  R:FitToArtwork(rec.id)
  local live = R:Get(rec.id)
  for _, axis in ipairs({ "width", "height" }) do
    assertTrue(live[axis] <= NS.Constants.MAX_SIZE,
      axis .. " escaped the clamp: " .. tostring(live[axis]))
    assertTrue(live[axis] >= NS.Constants.MIN_SIZE,
      axis .. " fell below the floor: " .. tostring(live[axis]))
  end
  clearSunn()
end)


-- ── Section counts and overlap: their own merge order ────────────────────────────
--
-- SunnArt uses two different merge orders and this module has to reproduce both. GetThemeList
-- merges NAMES with SunnArtPack first and db.global last (SunnArt_Core.lua:123); ImportThemes
-- merges panels and overlap the other way round, db.global first and SunnArtPack overwriting it
-- (SunnArt_Core.lua:132-152). Pairing each count table with its name table, as this module first
-- did, silently inverted the second one.

test("SunnArt: a pack's section count beats a stale entry in the player's saved globals", function()
  clearSunn()
  _G.SunnArt = {
    options = { args = { theme = { values = { ["SunnArtPack\\t"] = "T" } } } },
    ThemeDB = { index = {}, overlap = {}, panels = {}, length = {} },
    db = { global = { themes = {}, panels = { ["SunnArtPack\\t"] = 5 }, overlaps = {} } },
  }
  _G.SunnArtPack = {
    theme = { ["SunnArtPack\\t"] = "T" }, panels = { ["SunnArtPack\\t"] = 2 },
    overlap = {}, length = {},
  }
  -- ImportThemes absorbs db.global.panels FIRST and then lets SunnArtPack.panels overwrite it, so
  -- the pack wins — even though the player's theme NAME would win the other merge.
  assertEqual(S.Themes()[1].sections, 2, "the saved-globals count beat the pack's own declaration")
end)

test("SunnArt: a hand-edited SunnCustomPanels is honored, which SunnArt itself never does",
  function()
    clearSunn()
    -- CustomTheme.lua:2-3 declares SunnCustomPanels and invites the player to fill it in, and
    -- ImportThemes then never reads it — so in SunnArt a player who sets it silently gets 3
    -- sections. This is a deliberate DIVERGENCE, and it is ordered last because a hand-edited file
    -- is the only source a human actually typed.
    _G.SunnCustomTheme = { ["SunnArt\\mine"] = "Mine" }
    _G.SunnCustomPanels = { ["SunnArt\\mine"] = 4 }
    _G.SunnArtPack = {
      theme = {}, panels = { ["SunnArt\\mine"] = 2 }, overlap = {}, length = {},
    }
    assertEqual(S.Themes()[1].sections, 4, "the player's own declaration was overridden")
  end)

-- ── Overlap: the transparent band, not a section overlap ─────────────────────────

test("SunnArt: overlap becomes a content crop, not a wider bar", function()
  clearSunn()
  _G.SunnArtPack = {
    theme   = { ["P\\t"] = "T" },
    panels  = { ["P\\t"] = 3 },
    -- CustomTheme.lua's own worked example: 75 transparent pixels of 256.
    overlap = { ["P\\t"] = 29.297 },
    length  = {},
  }
  local theme = S.Themes()[1]
  assertTrue(math.abs(theme.overlap - 0.29297) < 1e-9, "the percentage was not normalized")

  local rows = S.Rows()
  local bar = rows[#rows]
  -- Sections are laid FLUSH (SunnArt_Core.lua:322 anchors each to the previous one's TOPRIGHT), so
  -- overlap never touches the width. It comes off the HEIGHT, because it is a transparent band at
  -- the top of the artwork that a panel has no viewport to hang over.
  assertEqual(bar.w, S.SECTION_W * 3, "overlap wrongly changed the bar's width")
  assertTrue(math.abs(bar.h - S.SECTION_H * (1 - 0.29297)) < 1e-9, "the content height is wrong")
  assertTrue(math.abs(bar.contentV0 - 0.29297) < 1e-9, "the sampled window did not move")
  -- Every section row carries the same crop, so a player picking one piece of a bar gets the same
  -- treatment as the bar.
  assertTrue(math.abs(rows[1].h - S.SECTION_H * (1 - 0.29297)) < 1e-9,
    "a section row kept the transparent band")
end)

test("SunnArt: a theme with no overlap carries no crop at all", function()
  clearSunn()
  communityPack()
  local rows = S.Rows()
  -- Absent rather than zero: a row that does not crop should carry no field to reason about, and
  -- takes the identity path in BuildArtSpec by absence.
  assertNil(rows[#rows].contentV0, "a theme with no overlap still declared a crop")
  assertEqual(rows[#rows].h, S.SECTION_H)
end)

test("SunnArt: a broken or extreme overlap value cannot crop the art out of existence", function()
  clearSunn()
  _G.SunnArtPack = {
    theme   = { ["P\\a"] = "A", ["P\\b"] = "B", ["P\\c"] = "C" },
    panels  = { ["P\\a"] = 1, ["P\\b"] = 1, ["P\\c"] = 1 },
    -- 100 is a legal value on SunnArt's own slider (min 0, max 100); the other two are the kinds
    -- of garbage another addon's saved variables can hold.
    overlap = { ["P\\a"] = 100, ["P\\b"] = -10, ["P\\c"] = "nonsense" },
    length  = {},
  }
  local byName = {}
  for _, row in ipairs(S.Rows()) do byName[row.label] = row end
  assertTrue(byName.A.h > 0, "a 100% overlap left no art at all")
  assertTrue(math.abs(byName.A.contentV0 - S.MAX_OVERLAP) < 1e-9, "the clamp did not hold")
  assertNil(byName.B.contentV0, "a negative overlap was not treated as none")
  assertNil(byName.C.contentV0, "a non-numeric overlap was not treated as none")
end)

test("SunnArt: autosize shapes a panel around the visible art, not the transparent band", function()
  clearSunn()
  _G.SunnArtPack = {
    theme = { ["P\\t"] = "T" }, panels = { ["P\\t"] = 3 },
    overlap = { ["P\\t"] = 25 }, length = {},
  }
  S.Inject()
  local id = S.ID_PREFIX .. "p-t-bar"
  -- The whole reason the crop is worth consuming: NativeSize is what autosize divides by, so a bar
  -- declaring 25% padding would otherwise shape a panel a third taller than the art a player can
  -- see, and letterbox it under FIT.
  local w, h = Artwork.NativeSize({ artTexture = id })
  assertEqual(w, S.SECTION_W * 3)
  assertEqual(h, S.SECTION_H * 0.75)
end)

-- ── The known-pack fallback ─────────────────────────────────────────────────────
--
-- Every official pack TOC carries `## Dependencies: SunnArt`, enforced by the client before any Lua
-- runs, so a disabled or broken SunnArt means NOTHING registers. The textures are unaffected — they
-- are ordinary files — so modules/SunnArtPacks.lua remembers what the packs contain and the folder
-- roster says which of them the player actually has.

local Packs = REAL_PACKS

-- A known theme to assert against, taken from the manifest itself rather than written out here: a
-- literal would be a second copy of generated data and would rot the moment a pack is updated.
local function anyKnown(pred)
  local best
  for file, row in pairs(Packs) do
    if (not pred or pred(file, row)) and (not best or file < best) then best = file end
  end
  return best, Packs[best]
end

test("SunnArt: the packs manifest loaded and is keyed by unescaped theme paths", function()
  local n = 0
  for file, row in pairs(Packs) do
    n = n + 1
    -- The generator reads Lua SOURCE, where a path is spelled with escaped backslashes. Emitting
    -- those unescaped would produce `SunnArtPack2\\blackrock`, a path no texture ever resolves —
    -- and it would fail silently, as a dropdown entry that draws nothing.
    assertFalse(file:find("\\\\", 1, true) ~= nil, file .. " has a double-escaped separator")
    assertTrue(file:find("\\", 1, true) ~= nil, file .. " has no folder separator at all")
    assertTrue(type(row.name) == "string" and row.name ~= "", file .. " has no name")
    assertTrue(row.sections >= 1 and row.sections <= 5, file .. " has an impossible section count")
    assertTrue(row.w > 0 and row.h > 0, file .. " has no measured size")
  end
  assertTrue(n > 50, "the manifest looks truncated (" .. n .. " themes)")
end)

test("SunnArt: with no Sunn globals at all, an installed pack folder still yields its themes",
  function()
    clearSunn()
    local file, row = anyKnown()
    -- The whole point: SunnArt disabled, so not one global exists and nothing registered. The
    -- folder is on disk, so the art is drawable and the manifest is what knows about it.
    installed(file:match("^([^\\]+)"))
    withManifest(function()
      assertTrue(S.Installed(), "a known pack folder on disk did not count as installed")

      local found
      for _, t in ipairs(S.Themes()) do if t.file == file then found = t end end
      assertTrue(found ~= nil, "the manifest did not supply " .. file)
      assertEqual(found.name, row.name)
      assertEqual(found.sections, row.sections)
      assertTrue(found.known, "a remembered theme was not marked as one")
    end)
  end)

test("SunnArt: a pack that is NOT installed is never offered", function()
  clearSunn()
  -- The manifest knows 88 themes. Advertising them to a player who has none of the packs would be
  -- a dropdown full of entries that draw nothing.
  installed("SomeUnrelatedAddon")
  withManifest(function()
    assertFalse(S.Installed(), "claimed an install with no Sunn folder present")
    assertEqual(#S.Themes(), 0, "offered themes for packs that are not on disk")
  end)
end)

test("SunnArt: live registration beats the manifest for a theme they both name", function()
  clearSunn()
  local file = anyKnown()
  installed(file:match("^([^\\]+)"))
  -- A player who renamed a theme, or changed its section count, in SunnArt's own options must see
  -- their version. The manifest fills gaps; it never overrides.
  _G.SunnArtPack = {
    theme = { [file] = "Renamed By Player" }, panels = { [file] = 5 },
    overlap = {}, length = {},
  }
  withManifest(function()
    local found
    for _, t in ipairs(S.Themes()) do if t.file == file then found = t end end
    assertEqual(found.name, "Renamed By Player", "the manifest overrode a live registration")
    assertEqual(found.sections, 5, "the manifest overrode a live section count")
    assertNil(found.known, "a live discovery was marked as remembered")
  end)
end)

test("SunnArt: a theme the manifest measured is drawn at its real shape, not the declared 2:1",
  function()
    clearSunn()
    -- SunnArt hard-codes 2:1 (`h = w * scale / 2`), and eight official themes are not 2:1 — five
    -- are square. Those are drawn squashed by SunnArt itself; the measurement is what lets this
    -- addon draw them as authored. The dimensions come from the manifest even when the theme was
    -- discovered LIVE, because registration never carries them.
    local file, row = anyKnown(function(_, r) return r.h == r.w end)
    if not file then return end          -- no square theme in the manifest; nothing to assert
    installed(file:match("^([^\\]+)"))
    _G.SunnArtPack = {
      theme = { [file] = row.name }, panels = { [file] = row.sections },
      overlap = {}, length = {},
    }
    withManifest(function()
      local rows = S.Rows()
      local bar = rows[#rows]
      assertEqual(bar.h, row.h, "a square theme was flattened to the declared 2:1 height")
      assertEqual(bar.w, row.w * row.sections)
      assertTrue(row.h ~= S.SECTION_H, "fixture chose a theme that cannot show the difference")
    end)
  end)

test("SunnArt: an unreadable addon roster does not silently disable a working install", function()
  clearSunn()
  local file = anyKnown()
  -- Compat.AddOnFolders returns nil when the API is absent. That is "cannot tell", not "nothing
  -- installed": withholding every theme would disable a feature that works, where offering one
  -- whose files are missing merely draws nothing.
  --
  -- Swapped on T.mocks rather than on _G: the loader env resolves mocks from that table, so a
  -- `_G.C_AddOns = nil` here would set a global the addon code never reads and the case would pass
  -- while testing nothing. wow_mock says the same thing about this exact global.
  local saved = T.mocks.C_AddOns
  T.mocks.C_AddOns = { GetAddOnMetadata = saved.GetAddOnMetadata }
  local ok, names = pcall(function()
    local out = {}
    withManifest(function()
      for _, t in ipairs(S.Themes()) do out[t.file] = true end
    end)
    return out
  end)
  T.mocks.C_AddOns = saved
  assertTrue(ok, "reading themes with no roster API errored: " .. tostring(names))
  assertTrue(names[file], "an unreadable roster dropped every known pack")
end)

-- ── The folder gate applies to LIVE discovery too ───────────────────────────────

test("SunnArt: a theme left in saved variables by an UNINSTALLED pack is not offered", function()
  clearSunn()
  -- `db.global.themes` is saved variables, so a theme the player built in SunnArt's Advanced
  -- options outlives the pack being deleted. Offering it would put an entry in the dropdown that
  -- draws nothing, which reads as this addon being broken rather than the art being gone.
  _G.SunnArt = {
    options = { args = { theme = { values = { ["SunnArtPack2\\blackrock"] = "Blackrock" } } } },
    ThemeDB = { index = {}, overlap = {}, panels = {}, length = {} },
    db = { global = { themes = { ["SunnArtPack99\\deleted"] = "Long Gone" }, panels = {},
                      overlaps = {} } },
  }
  installed("SunnArt", "SunnArtPack2")     -- Pack 99 is NOT on disk

  local byFile = {}
  for _, t in ipairs(S.Themes()) do byFile[t.file] = t end
  assertTrue(byFile["SunnArtPack2\\blackrock"] ~= nil, "an installed pack's theme was dropped")
  assertNil(byFile["SunnArtPack99\\deleted"], "a theme from an uninstalled pack was still offered")
end)

test("SunnArt: a hand-edited custom theme naming a missing folder is not offered", function()
  clearSunn()
  -- SunnCustomTheme is a text file the player edits by hand, so it can name anything at all,
  -- including a folder that was never installed or one whose files have been removed.
  _G.SunnCustomTheme = {
    ["SunnArt\\mine"]       = "Mine",
    ["NeverInstalled\\art"] = "Typo",
  }
  installed("SunnArt")

  local byFile = {}
  for _, t in ipairs(S.Themes()) do byFile[t.file] = t end
  assertTrue(byFile["SunnArt\\mine"] ~= nil, "a custom theme in an installed folder was dropped")
  assertNil(byFile["NeverInstalled\\art"], "a custom theme naming a missing folder was offered")
end)

test("SunnArt: Installed() agrees with the dropdown rather than with the globals", function()
  clearSunn()
  -- The drift this guards: the earlier version answered yes whenever any Sunn global existed, so a
  -- SunnArt whose every theme named a deleted pack would light up the category and then show
  -- nothing under it. Installed() is now defined as "does this yield anything to offer".
  _G.SunnArtPack = {
    theme = { ["SunnArtPack99\\deleted"] = "Long Gone" }, panels = {}, overlap = {}, length = {},
  }
  installed("SomeUnrelatedAddon")
  assertFalse(S.Installed(), "claimed an install whose every theme is uninstalled")
  assertEqual(#S.Rows(), 0, "synthesized rows for art that is not on disk")
end)

test("SunnArt: Inject offers only what is installed, across both discovery paths", function()
  clearSunn()
  -- End to end, because this is the property a player actually sees: the artwork dropdown lists
  -- Sunn entries they can pick and have something appear. Every row Inject appends must name a
  -- folder that exists, whether the theme came from a live registration or from the manifest.
  _G.SunnArtPack = {
    theme = { ["SunnArtPack99\\deleted"] = "Long Gone" }, panels = {}, overlap = {}, length = {},
  }
  installed("SunnArtPack2")
  withManifest(function()
    S.Inject()
    local n = 0
    for _, row in ipairs(Artwork.Catalog) do
      if type(row.id) == "string" and row.id:sub(1, #S.ID_PREFIX) == S.ID_PREFIX then
        n = n + 1
        local folder = row.path:match("^Interface\\Addons\\([^\\]+)")
        assertEqual(folder, "SunnArtPack2", "offered a row from a pack that is not installed")
      end
    end
    assertTrue(n > 0, "the installed pack contributed no rows at all")
  end)
end)

-- ── Fit against the artwork's PRESENTED size ────────────────────────────────────
--
-- Rotation and scale are part of how big the art is on screen, so they are part of the answer.
-- Ignoring either produced a panel the art then sat inside letterboxed, which is the exact outcome
-- pressing this is meant to eliminate.

test("Fit: a quarter turn transposes the fitted size", function()
  R:DeleteAll()
  clearSunn()
  _G.SunnArtPack = {
    theme = { ["SunnArtPack2\\blackrock"] = "Blackrock" },
    panels = { ["SunnArtPack2\\blackrock"] = 3 }, overlap = {}, length = {},
  }
  S.Inject()
  local rec = panel("Turned", { artTexture = "sunn-sunnartpack2-blackrock-bar" })

  R:Set(rec.id, "artRotation", 0)
  assertTrue(R:FitToArtwork(rec.id))
  assertEqual(R:Get(rec.id).width, 1536)
  assertEqual(R:Get(rec.id).height, 256)

  -- 90 and 270 swap the axes; 180 does not. Asserted on the RESULT rather than on the return value,
  -- because 270 asks for the same size 90 already produced and correctly reports "nothing moved".
  for _, turn in ipairs({ 90, 270 }) do
    R:Set(rec.id, "artRotation", turn)
    R:FitToArtwork(rec.id)
    local live = R:Get(rec.id)
    assertEqual(live.width, 256, "the " .. turn .. " turn did not transpose the width")
    assertEqual(live.height, 1536)
  end

  R:Set(rec.id, "artRotation", 180)
  assertTrue(R:FitToArtwork(rec.id))
  assertEqual(R:Get(rec.id).width, 1536, "a half turn wrongly transposed the size")
  assertEqual(R:Get(rec.id).height, 256)
  clearSunn()
end)

test("Fit: the artwork scale multiplies the fitted size", function()
  R:DeleteAll()
  local rec = panel("Scaled", { artTexture = "class-warrior" })      -- 1024x1024

  R:Set(rec.id, "artScale", 0.5)
  assertTrue(R:FitToArtwork(rec.id))
  assertEqual(R:Get(rec.id).width, 512)
  assertEqual(R:Get(rec.id).height, 512)

  R:Set(rec.id, "artScale", 2)
  assertTrue(R:FitToArtwork(rec.id))
  assertEqual(R:Get(rec.id).width, 2048)
  assertEqual(R:Get(rec.id).height, 2048)
end)

test("Fit: scale and rotation compose, and the result is a whole pixel", function()
  R:DeleteAll()
  clearSunn()
  _G.SunnArtPack = {
    theme = { ["P\\x"] = "X" }, panels = { ["P\\x"] = 1 }, overlap = {}, length = {},
  }
  S.Inject()
  -- 512x256, turned (256x512), at 0.75 -> 192x384. Both exact; the rounding is exercised by the
  -- overlap case above.
  local rec = panel("Both", { artTexture = "sunn-p-x", artRotation = 90, artScale = 0.75 })
  assertTrue(R:FitToArtwork(rec.id))
  local live = R:Get(rec.id)
  assertEqual(live.width, 192)
  assertEqual(live.height, 384)
  clearSunn()
end)

test("Fit: after fitting, STATIC draws the art at exactly the panel's size", function()
  R:DeleteAll()
  -- The property that makes "fitted" mean something: the panel is the size the art is drawn at.
  local rec = panel("Exact", { artTexture = "class-warrior", artFill = "STATIC",
                               artScale = 0.5, artRotation = 90 })
  assertTrue(R:FitToArtwork(rec.id))
  local live = R:Get(rec.id)
  local spec = NS.Artwork.BuildArtSpec(live, live.width, live.height)
  assertTrue(math.abs(spec.width - live.width) < 0.001,
    "STATIC drew " .. spec.width .. " wide into a " .. live.width .. " panel")
  assertTrue(math.abs(spec.height - live.height) < 0.001,
    "STATIC drew " .. spec.height .. " tall into a " .. live.height .. " panel")
end)

test("Fit: FIT still shrinks below a scale of 1, and fitting does not spiral", function()
  R:DeleteAll()
  -- FIT contains the art in the panel and THEN applies artScale, so it is not a fixed point below
  -- scale 1. Fitting targets STATIC's size precisely so that pressing the button twice is stable
  -- rather than quartering the panel each time.
  local rec = panel("Contained", { artTexture = "class-warrior", artFill = "FIT", artScale = 0.5 })
  assertTrue(R:FitToArtwork(rec.id))
  assertEqual(R:Get(rec.id).width, 512)
  local ok = R:FitToArtwork(rec.id)
  assertFalse(ok, "a second press moved a panel that was already fitted")
  assertEqual(R:Get(rec.id).width, 512, "fitting a FIT panel spiralled downward")
end)

test("Fit: a junk rotation or scale fits to what will actually be drawn", function()
  R:DeleteAll()
  -- Both are read through the same enum/clamp seams the fill math uses, so a record holding
  -- nonsense cannot fit to one size and render at another.
  local rec = R:New("Junk")
  local live = R:Get(rec.id)
  live.artTexture, live.artRotation, live.artScale = "class-warrior", "banana", "nonsense"
  assertTrue(R:FitToArtwork(rec.id))
  assertEqual(R:Get(rec.id).width, 1024, "junk did not fall back to the drawn size")
  assertEqual(R:Get(rec.id).height, 1024)
end)
