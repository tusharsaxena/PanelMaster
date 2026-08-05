local T = _G.PM_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- Guards on the harness itself, added with the shared test kit (tests/_kit/).
--
-- The suite-inventory gate below is the kit's own primitive now. This repo hand-rolled it in two
-- directional cases while the kit still SKIPPED a listed suite whose file was not on disk; kit
-- version 8 raises on that instead, exports Kit.assertSuiteInventory, and runs it automatically
-- whenever Kit.run is given an explicit `dir`. Two hand-rolled halves became one call: the kit
-- reports EVERY divergence in both directions in a single message, with a different sentence per
-- direction because the two fixes are different.

local function readFile(path)
  local f = assert(io.open(path, "r"), "missing file " .. path)
  local src = f:read("*a")
  f:close()
  return src
end

local function declaredSuites()
  local block = readFile("tests/run.lua"):match("local SUITES = {(.-)}")
  assertTrue(block ~= nil, "tests/run.lua no longer declares `local SUITES = {`")
  local out = {}
  for name in block:gmatch('"([^"]+)"') do out[#out + 1] = name end
  return out
end

test("Harness: the suite list and tests/test_*.lua agree in both directions", function()
  -- Named here as well as run automatically, because a named case is what docs/test-cases.md
  -- counts — the automatic call inside Kit.run dies before any case is registered and would leave
  -- the published inventory silent about the gate that protects it.
  T.assertSuiteInventory("tests/", declaredSuites())
end)

test("Harness: the shared kit is present and is reached through tests/_kit", function()
  -- The kit is vendored whole-folder from ../LibKa0s/testkit and is never edited here. Byte
  -- fidelity is the shell gate in docs/testing.md (this repo cannot see the library repo); what a
  -- case CAN say is that the four files are here and that the runner consumes them rather than a
  -- local copy.
  for _, path in ipairs({ "tests/_kit/framework.lua", "tests/_kit/loader.lua",
                          "tests/_kit/mock_base.lua", "tests/_kit/README.md" }) do
    assertTrue(io.open(path, "r") ~= nil, "the vendored test kit is missing " .. path)
  end
  local runner = readFile("tests/run.lua")
  assertTrue(runner:find('dofile("tests/_kit/framework.lua")', 1, true) ~= nil,
    "tests/run.lua no longer uses the kit's framework")
  assertTrue(runner:find('dofile("tests/_kit/loader.lua")', 1, true) ~= nil,
    "tests/run.lua no longer uses the kit's loader")
  assertTrue(io.open("tests/loader.lua", "r") == nil,
    "tests/loader.lua is back — the kit's loader replaced it, and two loaders will drift")
end)

test("Harness: wow_mock extends the kit's mock_base rather than replacing it", function()
  -- The base is the only source of a LibStub with a real NewLibrary and of a fireable AceGUI. A
  -- mock that stopped extending it would take both away, and every LibKa0s case would fall back to
  -- the degraded path while still passing.
  local src = readFile("tests/wow_mock.lua")
  assertTrue(src:find('dofile("tests/_kit/mock_base.lua")', 1, true) ~= nil,
    "tests/wow_mock.lua no longer builds on the kit's mock_base")
  assertTrue(src:find("local M = buildBase()", 1, true) ~= nil,
    "tests/wow_mock.lua no longer starts from the base environment")
  assertTrue(T.mocks.LibStub.NewLibrary ~= nil,
    "the mock LibStub has no NewLibrary — no vendored library can register")
  local aceGUI = T.mocks.LibStub("AceGUI-3.0", true)
  assertTrue(aceGUI ~= nil and aceGUI.Create ~= nil, "AceGUI-3.0 is missing from the mock")
  local widget = aceGUI:Create("CheckBox")
  assertTrue(widget ~= nil and widget.__fire ~= nil,
    "the AceGUI mock is not fireable — the schema -> widget -> write path stays untestable")
end)

test("Harness: the runner derives the addon's load list from the TOC", function()
  -- A second hand-maintained load order is a second thing that can be wrong, and only one of them
  -- is what the client reads.
  local runner = readFile("tests/run.lua")
  assertTrue(runner:find('Loader.tocFiles("PanelMaster.toc")', 1, true) ~= nil,
    "tests/run.lua hand-lists the addon's files again instead of reading the TOC")
  local Loader = dofile("tests/_kit/loader.lua")
  local files = Loader.tocFiles("PanelMaster.toc")
  assertTrue(#files > 15, "the TOC parse yielded suspiciously few files (" .. #files .. ")")
  local seen = {}
  for _, p in ipairs(files) do seen[p] = true end
  for _, expected in ipairs({ "core/CoreSetup.lua", "core/Util.lua", "settings/Panel.lua" }) do
    assertTrue(seen[expected], "the TOC-derived load list is missing " .. expected)
  end
  for _, p in ipairs(files) do
    assertTrue(not p:match("^libs/"), "libs/ must not come through tocFiles: " .. p)
  end
end)

test("Harness: the runner derives the vendored library's load list from LibKa0s.xml", function()
  -- The other hand-maintained load order, and the one that was actually wrong: the runner listed
  -- SIX of the eight files LibKa0s.xml pulls in. A short library list does not raise — it leaves
  -- the missing modules undefined for whichever cases never reach them, which is how PM-A-10
  -- survived every green run.
  -- A LINT, deliberately spelled loosely: it asks that the runner go through Loader.xmlFiles and
  -- that no library .lua path be typed here at all. Pinning the exact call text would redden the
  -- moment someone hoists the XML path to a local while loading precisely the right eight files —
  -- the behavioral half of this guarantee is the case below, which reads the loaded environment.
  local runner = readFile("tests/run.lua")
  assertTrue(runner:find("Loader.xmlFiles(", 1, true) ~= nil,
    "tests/run.lua no longer derives the vendored library's load list through Loader.xmlFiles")
  local typed = runner:match('"(libs/LibKa0s/[^"]+%.lua)"')
  assertEqual(typed, nil, "tests/run.lua hand-lists a vendored library file again: " .. tostring(typed))
  local Loader = dofile("tests/_kit/loader.lua")
  local files = Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml")

  -- Every entry in the XML, and nothing else. Read straight off the XML rather than re-typed, so
  -- this case cannot become the third copy of the list it exists to abolish.
  local declared = {}
  for line in readFile("libs/LibKa0s/LibKa0s.xml"):gmatch("[^\r\n]+") do
    if not line:match("^%s*<!%-%-") then
      local f = line:match('file%s*=%s*"([^"]+%.lua)"')
      if f then declared[#declared + 1] = "libs/LibKa0s/" .. f:gsub("\\", "/") end
    end
  end
  assertTrue(#declared >= 8, "LibKa0s.xml declares only " .. #declared .. " scripts")
  assertEqual(#files, #declared, "the derived list and LibKa0s.xml disagree on how many files there are")
  for i = 1, #declared do
    assertEqual(files[i], declared[i], "entry " .. i .. " is out of XML order, which is load order")
    assertTrue(io.open(files[i], "r") ~= nil, "LibKa0s.xml names a file that is not vendored: " .. files[i])
  end
end)

test("Harness: every module LibKa0s.xml declares is live in the loaded environment", function()
  -- The case above compares one parse of the XML against another — neither half observes what the
  -- runner actually LOADED. This one does, in the environment tests/run.lua already built: the two
  -- files that were missing for a year (Perf.lua, PerfPanel.lua) are the last two entries in the
  -- XML, and their absence is silent. A short load list does not raise; it just leaves the module
  -- undefined, which is what PM-A-10 was.
  --
  -- PerfPanel.lua deliberately has no major of its own — it attaches to LibKa0s-Perf-1.0 (see its
  -- header) — so it is observed through the MODULES table the pair publishes, not through LibStub.
  local core = T.mocks.LibStub("LibKa0s-Core-1.0", true)
  assertTrue(core ~= nil, "LibKa0s-Core-1.0 did not register — the library half of the load list is dead")

  local perf = T.mocks.LibStub("LibKa0s-Perf-1.0", true)
  assertTrue(perf ~= nil, "LibKa0s-Perf-1.0 did not register — Perf.lua was not loaded")
  assertEqual(perf.MODULES.Perf, perf.MINOR, "Perf.lua did not publish its own minor")
  assertTrue(type(perf.MODULES.PerfPanel) == "number",
    "PerfPanel.lua did not attach — the last entry in LibKa0s.xml never loaded")

  -- One assertion per major the XML declares, derived from the files themselves rather than a
  -- fourth hand-typed list, so a major added to the library is observed here the day it ships.
  local declaredMajors = {}
  for _, path in ipairs(dofile("tests/_kit/loader.lua").xmlFiles("libs/LibKa0s/LibKa0s.xml")) do
    local f = assert(io.open(path, "r"))
    local src = f:read("*a")
    f:close()
    local major = src:match('local MAJOR[^=]*=%s*"(LibKa0s%-[%w]+%-1%.0)"')
    if major then declaredMajors[major] = true end
  end
  local n = 0
  for major in pairs(declaredMajors) do
    n = n + 1
    assertTrue(T.mocks.LibStub(major, true) ~= nil, major .. " did not register in the loaded environment")
  end
  assertTrue(n >= 4, "only " .. n .. " majors were found in the vendored files — the scan stopped working")
end)

-- ── The frame stub itself ───────────────────────────────────────────────────────
-- Every suite in this repo builds its frames through tests/wow_mock.lua's stubFrame, so a break in
-- it is loud — but nothing asserted on the stub ITSELF, which meant the pieces that are deliberate
-- divergences (frames start shown, a recorded 0 is not the default, a child region is a FRESH stub)
-- rested on nothing. These cases pin them.

local assertNil = T.assertNil

local function newStub()
  return T.mocks.CreateFrame("Frame")
end

test("Mock frame: visibility starts shown and Show/Hide/SetShown flip it", function()
  local f = newStub()
  assertTrue(f:IsShown(), "a fresh stub frame must start SHOWN, as a real frame does")
  assertTrue(f:IsVisible(), "IsVisible answers the same flag as IsShown")
  f:Hide()
  assertEqual(f:IsShown(), false)
  f:Show()
  assertEqual(f:IsShown(), true)
  f:SetShown(false)
  assertEqual(f:IsShown(), false)
  f:SetShown(true)
  assertEqual(f:IsShown(), true)
end)

test("Mock frame: Hide fires each OnHide hook once, and only from shown", function()
  local f = newStub()
  local fired = 0
  f:HookScript("OnHide", function() fired = fired + 1 end)
  f:Hide()
  assertEqual(fired, 1, "hiding a shown frame runs its OnHide hook")
  f:Hide()
  assertEqual(fired, 1, "hiding an already-hidden frame is not a transition and fires nothing")
  f:Show()
  f:Hide()
  assertEqual(fired, 2)
end)

test("Mock frame: SetPoint records both overloads and GetPoint hands them back", function()
  local f = newStub()
  f:SetPoint("TOPLEFT", 10, -20)
  local point, relativeTo, relPoint, x, y = f:GetPoint(1)
  assertEqual(point, "TOPLEFT")
  assertEqual(relativeTo, nil)
  assertEqual(relPoint, "TOPLEFT", "the short form's relative point is the point itself")
  assertEqual(x, 10)
  assertEqual(y, -20)

  local anchor = newStub()
  f:SetPoint("CENTER", anchor, "BOTTOM", 3, 4)
  assertEqual(f:GetNumPoints(), 2)
  local p2, rel2, rp2, x2, y2 = f:GetPoint(2)
  assertEqual(p2, "CENTER")
  assertTrue(rel2 == anchor, "the long form keeps the relativeTo frame")
  assertEqual(rp2, "BOTTOM")
  assertEqual(x2, 3)
  assertEqual(y2, 4)

  f:ClearAllPoints()
  assertEqual(f:GetNumPoints(), 0)
  assertNil(f:GetPoint(1), "GetPoint on a frame with no points is nil, not an error")
end)

test("Mock frame: a recorded 0 survives and GetScale defaults to 1", function()
  -- The stub's readers hand back exactly what was stored: a border size of 0 and an alpha of 0 are
  -- real user choices, and reporting the default for either would hide the bug that put it there.
  -- 0 is truthy in Lua, so an `or` fallback would not have swallowed one anyway — only nil and
  -- false fall through an `or`, which is why GetScale's `or 1` and a nil test agree on every value
  -- this addon can produce. The `false` case below pins which of the two the stub actually does.
  local f = newStub()
  assertEqual(f:GetWidth(), 0, "a fresh stub is 0 wide, not nil")
  f:SetSize(120, 40)
  assertEqual(f:GetWidth(), 120)
  assertEqual(f:GetHeight(), 40)
  f:SetWidth(0)
  assertEqual(f:GetWidth(), 0, "a width of 0 is recorded, not swapped for the default")
  f:SetAlpha(0)
  assertEqual(f:GetAlpha(), 0)
  assertEqual(f:GetScale(), 1, "a frame nothing scaled reads 1, the way a real frame does")
  f:SetScale(0.5)
  assertEqual(f:GetScale(), 0.5)
  f:SetScale(0)
  assertEqual(f:GetScale(), 0, "0 is truthy, so a recorded 0 scale survives the `or 1` fallback")
  -- Pins GetScale's `or` against a rewrite to `if v == nil then return default end`. Nothing in the
  -- addon can store a false scale (Canvas hands SetScale a clamped number), but the two spellings
  -- diverge exactly here, so the assertion is what makes the next refactor of the stub prove it
  -- kept the same semantics rather than merely kept the tests green.
  f:SetScale(false)
  assertEqual(f:GetScale(), 1, "a stored false is not a scale; `or` falls through to the default")
end)

test("Mock frame: a lowercase or custom key misses through to nil", function()
  -- This is what lets addon code do `if not f.someCustomField then f.someCustomField = ... end`.
  local f = newStub()
  assertNil(f.someCustomField, "a lowercase key must not answer with a no-op function")
  assertNil(f.panelID)
  f.panelID = 7
  assertEqual(f.panelID, 7)
  assertTrue(type(f.SomeFutureApiMethod) == "function",
    "an unmodeled PascalCase method is a no-op")
  assertTrue(f:SomeFutureApiMethod() == f, "and the no-op returns the frame, so calls chain")
end)

test("Mock frame: child regions are fresh stubs, never the parent", function()
  -- Aliasing them onto the parent would collapse every accent edge into one color slot.
  local f = newStub()
  local tex = f:CreateTexture()
  local fs = f:CreateFontString()
  assertTrue(tex ~= f, "CreateTexture must not hand back the frame itself")
  assertTrue(fs ~= f, "CreateFontString must not hand back the frame itself")
  assertTrue(tex ~= fs, "two child regions are two objects")
  tex:SetColorTexture(1, 0, 0, 1)
  fs:SetVertexColor(0, 1, 0, 1)
  assertEqual(tex.__color[1], 1)
  assertEqual(fs.__color[2], 1)
  assertNil(f.__color, "a child's color must not land on the parent")
end)

test("Mock frame: SetTexture keeps the wrap arguments and SetTexCoord the flat list", function()
  -- Tiled artwork's correctness lives entirely in the wrap arguments; the tex-coord list is stored
  -- in SetTexCoord's own UL, LL, UR, LR order so a case asserts on exactly what the renderer said.
  local f = newStub()
  f:SetTexture("Interface\\Art", "REPEAT", "REPEAT")
  assertEqual(f:GetTexture(), "Interface\\Art")
  assertEqual(f.__wrapH, "REPEAT")
  assertEqual(f.__wrapV, "REPEAT")
  f:SetTexture(nil)
  assertNil(f:GetTexture())
  assertNil(f.__wrapH, "clearing a texture clears the wrap arguments with it")
  f:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)
  assertEqual(#f.__texCoord, 8)
  assertEqual(f.__texCoord[4], 1)
  f:SetTexCoord(0, 0.5, 0, 1)
  assertEqual(#f.__texCoord, 4, "the 4-argument crop form is recorded too")
end)

test("Mock frame: the recorded odds and ends round-trip", function()
  local f = newStub()
  assertEqual(f:IsMouseEnabled(), false)
  f:EnableMouse(true)
  assertEqual(f:IsMouseEnabled(), true)
  f:EnableMouse(nil)
  assertEqual(f:IsMouseEnabled(), false, "the mouse flag is coerced to a real boolean")
  f:SetFrameStrata("HIGH")
  assertEqual(f:GetFrameStrata(), "HIGH")
  f:SetFrameLevel(12)
  assertEqual(f:GetFrameLevel(), 12)
  f:SetText("hello")
  assertEqual(f:GetText(), "hello")
  f:SetBackdrop({ edgeSize = 2 })
  assertEqual(f:GetBackdrop().edgeSize, 2)
  f:SetBackdropBorderColor(1, 1, 0, 0.5)
  assertEqual(f.__backdropBorderColor[4], 0.5)
  f:SetBlendMode("ADD")
  assertEqual(f.__blend, "ADD")
  f:SetClipsChildren(1)
  assertEqual(f.__clipsChildren, true, "the clip flag is coerced to a real boolean")
  local handler = function() end
  f:SetScript("OnUpdate", handler)
  assertTrue(f:GetScript("OnUpdate") == handler, "scripts are recorded, not dropped")
  assertNil(f:GetScript("OnEvent"))
  assertEqual(T.mocks.CreateFrame("Frame", "PanelMaster_Panel_Chat"):GetName(),
    "PanelMaster_Panel_Chat", "the frame name is recorded — it is this addon's public contract")
end)
