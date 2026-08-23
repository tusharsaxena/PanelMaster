local T = _G.PM_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue, assertNil =
  T.test, T.assertEqual, T.assertTrue, T.assertNil
local C = NS.Constants

-- core/MediaSetup.lua — the LibKa0s-Media-1.0 seam.
--
-- THE CASE THAT EARNS THIS FILE is the cross-repo one. Every mark on this addon's console is named
-- as a plain string — three of them, inside the library, on this addon's behalf — and resolved
-- against a catalog that lives in ANOTHER repo. If the library renames a mark, or a re-vendor drops
-- a file, the answer is nil, the library falls back to words and a multiplication sign, and the
-- console quietly stops being what the screenshots show. With every suite green, because a texture
-- that does not load draws nothing and raises nothing. That is the one class of art bug the client
-- gives you no signal for, and this is the first version of it that can be caught out of game.

local Loader = dofile("tests/_kit/loader.lua")
local buildMocks = dofile("tests/wow_mock.lua")

local VENDORED = "Interface\\AddOns\\PanelMaster\\libs\\LibKa0s\\media\\"

-- The marks this addon puts on screen. They are drawn by LibKa0s-DebugLog-1.0 rather than by any
-- file in this repo — the descriptor in core/DebugLogSetup.lua hands over `addonName` and the
-- library resolves these three names with it — which is exactly why they are listed here: nothing
-- in core/, modules/ or settings/ mentions them, so nothing else in this suite would notice a
-- rename on either side of the seam.
local DRAWN = { "close", "clear", "copy" }

-- ── the seam ────────────────────────────────────────────────────────────────────

test("MediaSetup: NS.Icon answers the vendored path, extensionless", function()
  -- Extensionless is not a preference. The library's own note records it from a live client: a path
  -- carrying `.tga` is one of the two spellings that draws nothing. The client appends it.
  assertEqual(NS.Icon("close"), VENDORED .. "icons\\close")
end)

test("MediaSetup: an icon the library does not ship answers nil", function()
  -- nil is a value a caller can branch on, and it is what sends the library down to its text
  -- button. A plausible path to a texture that is not there is a control that is simply absent.
  assertNil(NS.Icon("nosuchicon"))
end)

test("MediaSetup: NS.MediaFont answers the vendored face, extension and all", function()
  -- Font paths KEEP the extension where icon paths lose theirs: SetFont is handed a file, not a
  -- texture name, so the two rules differ on purpose and neither is a typo for the other.
  assertEqual(NS.MediaFont("JetBrains Mono"), VENDORED .. "fonts\\JetBrainsMono-Regular.ttf")
  assertNil(NS.MediaFont("Comic Sans"))
end)

test("MediaSetup: the font this addon names is the face the library registers", function()
  -- Two names for one thing, in two repos. C.FONT_MONO_NAME is the key core/MediaSetup.lua hands
  -- LibSharedMedia and the key a profile would store; the library's FONTS is what it registers
  -- from. A name nobody registered renders in Blizzard's proportional fallback, which is the exact
  -- outcome shipping a monospace face was meant to prevent.
  local Media = mocks.LibStub("LibKa0s-Media-1.0", true)
  assertTrue(Media ~= nil, "the vendored library did not load")
  assertTrue(Media.FONTS[C.FONT_MONO_NAME] ~= nil,
    "FONT_MONO_NAME is '" .. tostring(C.FONT_MONO_NAME)
    .. "', which the library's FONTS does not carry")
  assertEqual(C.FONT_MONO, NS.MediaFont(C.FONT_MONO_NAME))
end)

test("MediaSetup: the console's font is the payload's, not a copy of it", function()
  -- The local media/fonts/ copy is gone. A path back into this addon's own folder would be a file
  -- that is not there, and SetFont answers that by drawing nothing at all.
  assertTrue(C.FONT_MONO:find("libs\\LibKa0s\\media\\fonts", 1, true) ~= nil,
    "C.FONT_MONO no longer points into the vendored payload: " .. tostring(C.FONT_MONO))
end)

-- ── the catalog, against what this addon actually asks for ──────────────────────

test("MediaSetup: every mark this addon's console draws is one the library ships", function()
  -- red under: any name here the catalog does not carry, on either side of a re-vendor.
  local Media = mocks.LibStub("LibKa0s-Media-1.0", true)
  local known = {}
  for _, name in ipairs(Media.ICONS) do known[name] = true end
  for _, name in ipairs(DRAWN) do
    assertTrue(known[name] == true,
      "the console draws '" .. name .. "', which LibKa0s-Media does not ship")
    assertTrue(NS.Icon(name) ~= nil, "NS.Icon answered nil for " .. name)
  end
end)

test("MediaSetup: every name the library ships has a file in the vendored copy", function()
  -- The library's own suite checks its catalog against its own directory. This checks the COPY: a
  -- re-vendor that dropped a file, or a packaging step that filtered one out, leaves a catalog
  -- naming art this build does not carry.
  local Media = mocks.LibStub("LibKa0s-Media-1.0", true)
  local missing = {}
  for _, name in ipairs(Media.ICONS) do
    local fh = io.open("libs/LibKa0s/media/icons/" .. name .. ".tga", "rb")
    if fh then fh:close() else missing[#missing + 1] = name end
  end
  assertEqual(table.concat(missing, ", "), "")
end)

test("MediaSetup: the face the seam names exists in the vendored copy", function()
  local path = (NS.MediaFont(C.FONT_MONO_NAME):gsub("\\", "/")
    :gsub("^Interface/AddOns/PanelMaster/", ""))
  local fh = io.open(path, "rb")
  assertTrue(fh ~= nil, "missing shipped asset: " .. path)
  if fh then fh:close() end
end)

-- ── the TOC position, which is load-bearing ─────────────────────────────────────

test("MediaSetup: the TOC loads it before the file that resolves the font path", function()
  -- C.FONT_MONO is resolved at FILE LOAD from NS.MediaFont, so a seam published after
  -- core/Constants.lua would leave the constant holding STANDARD_TEXT_FONT forever — on a working
  -- install, with the payload present and every other case green.
  local order = {}
  for i, path in ipairs(Loader.tocFiles("PanelMaster.toc")) do order[path] = i end
  assertTrue(order["core/MediaSetup.lua"] ~= nil, "core/MediaSetup.lua is not in the TOC")
  assertTrue(order["core/Constants.lua"] ~= nil, "core/Constants.lua is not in the TOC")
  assertTrue(order["core/MediaSetup.lua"] < order["core/Constants.lua"],
    "core/MediaSetup.lua must load BEFORE core/Constants.lua")
end)

-- ── degraded ────────────────────────────────────────────────────────────────────

test("MediaSetup: with no library there is no art and no face, and that is not an error", function()
  -- Built from the REAL loader fed a partial file list, not from a hand-stubbed `Media = nil`: a
  -- hand-stub tests a branch rather than an install, and never catches a seam that raises at load
  -- before it reaches its own guard.
  local m = buildMocks()
  local ns = {}
  Loader.addonName = "PanelMaster"
  local libs = {}
  for _, path in ipairs(Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml")) do
    if path:match("([^/]+)%.lua$") ~= "Media" then libs[#libs + 1] = path end
  end
  Loader.loadAll(libs, ns, m)
  Loader.loadAll(Loader.tocFiles("PanelMaster.toc"), ns, m)
  ns.addon:OnInitialize()
  ns.addon:OnEnable()

  assertNil(ns.Icon("close"))
  assertNil(ns.MediaFont("JetBrains Mono"))
  -- And the console still has a face to draw with: the client's own, never a dead path.
  assertEqual(ns.Constants.FONT_MONO, _G.STANDARD_TEXT_FONT)
  assertTrue(type(ns.Constants.FONT_MONO) == "string" and ns.Constants.FONT_MONO ~= "",
    "the degraded fallback must be a real client font, not nil")
end)
