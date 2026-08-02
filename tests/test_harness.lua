local T = _G.PM_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- Guards on the harness itself, added with the shared test kit (tests/_kit/).
--
-- The kit's runner SKIPS a listed suite whose file is not on disk, rather than raising. That is a
-- deliberate kit decision — a suite can be listed while it is being written — but it is also a
-- silently-green hole this repo did not have before: a typo in the suite list, or a suite file
-- renamed and not re-listed, is a run that reports success while covering less than it claims.
-- These cases close it in both directions.

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

-- `ls tests/test_*.lua` without shelling out, so the case works wherever lua runs.
local function suiteFilesOnDisk()
  local out = {}
  local pipe = io.popen("ls tests/test_*.lua 2>/dev/null")
  if pipe then
    for line in pipe:lines() do
      local base = line:match("([^/]+)%.lua$")
      if base then out[#out + 1] = base end
    end
    pipe:close()
  end
  return out
end

test("Harness: every suite the runner lists exists on disk", function()
  -- The direction the kit's skip hides. A listed name with no file contributes zero cases and says
  -- nothing about it.
  local missing = {}
  for _, suite in ipairs(declaredSuites()) do
    if not io.open("tests/" .. suite .. ".lua", "r") then missing[#missing + 1] = suite end
  end
  assertEqual(#missing, 0,
    "tests/run.lua lists suites with no file — they are SKIPPED silently: " ..
    table.concat(missing, ", "))
end)

test("Harness: every suite on disk is listed by the runner", function()
  -- The other direction, which no skip is involved in: a suite file that exists and is not listed
  -- simply never runs, and nothing anywhere says so.
  local onDisk = suiteFilesOnDisk()
  assertTrue(#onDisk > 0, "could not enumerate tests/test_*.lua")
  local listed = {}
  for _, suite in ipairs(declaredSuites()) do listed[suite] = true end
  local unlisted = {}
  for _, base in ipairs(onDisk) do
    if not listed[base] then unlisted[#unlisted + 1] = base end
  end
  assertEqual(#unlisted, 0,
    "these suite files exist but tests/run.lua never loads them: " .. table.concat(unlisted, ", "))
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
