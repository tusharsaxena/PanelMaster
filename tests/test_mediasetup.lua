local T = _G.PM_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue, assertNil =
  T.test, T.assertEqual, T.assertTrue, T.assertNil
local C = NS.Constants

-- core/MediaSetup.lua — the LibKa0s-Media-1.0 seam.
--
-- THE CASE THAT EARNS THIS FILE is the cross-repo one. Every mark on this addon's console is named
-- as a plain string — three of them, inside the library, on this addon's behalf — and resolved
-- against a catalog that lives in ANOTHER repo, then drawn from a vendored copy whose media/icons/
-- is pruned to the `LibKa0s icons:` declaration in CLAUDE.md (kit revision 40). If the library
-- renames a mark, the answer is nil; if the declaration drops one, the prune removes its file and
-- the path still resolves, so the control draws BLANK. Either way the console quietly stops being
-- what the screenshots show, with every suite green, because a texture that does not load draws
-- nothing and raises nothing. That is the one class of art bug the client gives you no signal
-- for, so this file pins the drawn set against the catalog AND against the declaration.

local Loader = dofile("tests/_kit/loader.lua")
local buildMocks = dofile("tests/wow_mock.lua")

local VENDORED = "Interface\\AddOns\\PanelMaster\\libs\\LibKa0s\\media\\"

-- The marks this addon puts on screen. They are drawn by the library rather than by any file in
-- this repo — the descriptor in core/DebugLogSetup.lua hands over `addonName` and LibKa0s-DebugLog-1.0
-- resolves close, clear and copy with it, and the first-run skin picker (LibKa0s-Options-1.0's
-- OptionsSkinPicker) draws the settings gear; its eye is not drawn, because no onPreview is passed
-- (Ka0sAddonsCommonTasks docs/2026-10-29-SKINNING_ROLLOUT, X6) — which is exactly why they are
-- listed here: nothing in core/, modules/ or settings/ mentions them, so nothing else in this suite
-- would notice a rename on either side of the seam.
local DRAWN = { "close", "clear", "copy", "settings" }

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

test("MediaSetup: the CLAUDE.md icon declaration names exactly the marks the console draws", function()
  -- red under: dropping copy from the `LibKa0s icons:` line (a drawn mark the prune would remove,
  -- so the button draws blank), or adding info to it (a declared mark nothing here draws). The
  -- kit's vendor gate holds the folder to the declaration; this holds the declaration to DRAWN.
  -- The parser is the kit's own, never a second one written here.
  local VendorSync = dofile("tests/_kit/vendor_sync.lua")
  local fh = assert(io.open("CLAUDE.md", "rb"))
  local text = fh:read("*a")
  fh:close()
  local decl, why = VendorSync.iconDeclaration(text)
  assertTrue(decl ~= nil, "CLAUDE.md carries no valid `LibKa0s icons:` line: " .. tostring(why))
  assertEqual(decl.mode, "list")
  local declared, drawn = {}, {}
  for _, name in ipairs(decl.names) do declared[#declared + 1] = name end
  for _, name in ipairs(DRAWN) do drawn[#drawn + 1] = name end
  table.sort(declared)
  table.sort(drawn)
  assertEqual(table.concat(declared, ", "), table.concat(drawn, ", "))
  for _, name in ipairs(DRAWN) do
    local art = io.open("libs/LibKa0s/media/icons/" .. name .. ".tga", "rb")
    assertTrue(art ~= nil, "the console draws '" .. name .. "', which the vendored copy does not ship")
    if art then art:close() end
  end
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
