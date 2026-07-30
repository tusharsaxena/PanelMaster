-- Headless test runner for Ka0s Panel Master.
-- Run from the repo root:  lua tests/run.lua        (add --list to emit docs/test-cases.md)

local Loader     = dofile("tests/loader.lua")
local buildMocks = dofile("tests/wow_mock.lua")

-- --- tiny test framework (exposed to test files via _G.PM_TEST) ---
local tests = {}
local currentSuite = nil
local function test(name, fn) tests[#tests + 1] = { name = name, fn = fn, suite = currentSuite } end

local function fail(msg, level) error(msg, (level or 1) + 1) end
local function assertEqual(got, want, msg)
  if got ~= want then
    fail((msg or "assertEqual") ..
      string.format(" (expected %s, got %s)", tostring(want), tostring(got)), 1)
  end
end
local function assertTrue(c, msg) if not c then fail(msg or "assertTrue failed", 1) end end
local function assertFalse(c, msg) if c then fail(msg or "assertFalse failed", 1) end end
-- Float comparison for the geometry and colour maths, where an exact == would be a false failure.
local function assertNear(got, want, tol, msg)
  tol = tol or 1e-6
  if type(got) ~= "number" or math.abs(got - want) > tol then
    fail((msg or "assertNear") ..
      string.format(" (expected ~%s, got %s)", tostring(want), tostring(got)), 1)
  end
end

-- --- build the shared addon environment once (mirrors the in-game TOC load + OnInitialize) ---
local mocks = buildMocks()
local NS = {}

Loader.loadAll({
  "locales/enUS.lua",
  "locales/PostLoad.lua",
  "core/Compat.lua",
  "core/Constants.lua",
  "core/Namespace.lua",
  "core/State.lua",
  "core/Util.lua",
  "core/PanelMaster.lua",
  "core/Database.lua",
  "defaults/Profile.lua",
  "defaults/Global.lua",
  "modules/Registry.lua",
  "modules/Canvas.lua",
  "modules/Unlock.lua",
  "modules/DebugLog.lua",
  "settings/Schema.lua",
  "settings/Slash.lua",
  "settings/Panel.lua",
}, NS, mocks)

-- Run the addon's REAL lifecycle entry points, rather than hand-calling the pieces they are
-- supposed to call.
--
-- This is not a style preference. The first version of this harness listed the setup steps itself
-- (InitDB, Schema:Register, Slash:Register, Panel:Register, Canvas:Enable) — and because it called
-- Canvas:Enable() directly, every bus test passed against wiring that OnEnable never actually
-- performed. In-game, no settings change or panel edit ever reached the renderer: only the two paths
-- that call Canvas:RenderAll() directly (lock/unlock and test mode) repainted anything.
--
-- A harness that reproduces the lifecycle by hand can drift from it silently. Calling the real
-- functions means a step dropped from OnInitialize or OnEnable fails the suite instead of hiding
-- in it.
NS.addon:OnInitialize()
NS.addon:OnEnable()

_G.PM_TEST = {
  NS = NS, mocks = mocks, test = test,
  assertEqual = assertEqual, assertTrue = assertTrue, assertFalse = assertFalse,
  assertNear = assertNear,
}

-- --- load the test suites ---
local SUITE_FILES = {
  "test_util.lua", "test_compat.lua", "test_constants.lua",
  "test_registry.lua", "test_canvas.lua", "test_unlock.lua", "test_media.lua",
  "test_database.lua", "test_debuglog.lua",
  "test_schema.lua", "test_slash.lua", "test_panel.lua",
}
for _, s in ipairs(SUITE_FILES) do
  currentSuite = s
  dofile("tests/" .. s)
end
currentSuite = nil

-- --- inventory mode: emit docs/test-cases.md and exit without running (testing-§5) ---
if arg and arg[1] == "--list" then
  local order, byS = {}, {}
  for _, t in ipairs(tests) do
    if not byS[t.suite] then byS[t.suite] = {}; order[#order + 1] = t.suite end
    local b = byS[t.suite]; b[#b + 1] = t.name
  end
  print("# Test Cases")
  print("")
  print("The full inventory of every headless test case, grouped by suite. This file is the")
  print("**authoritative pass count** for the addon.")
  print("")
  print("**Generated — do not hand-edit.** Regenerate with `lua tests/run.lua --list > docs/test-cases.md`")
  print("whenever the suite changes (see [testing.md](testing.md)).")
  print("")
  for _, s in ipairs(order) do
    local b = byS[s]
    print(string.format("### %s (%d)", s, #b))
    print("")
    for _, n in ipairs(b) do print("- " .. n) end
    print("")
  end
  print("## Totals")
  print("")
  print("| Suite | Cases |")
  print("|-------|------:|")
  for _, s in ipairs(order) do print(string.format("| %s | %d |", s, #byS[s])) end
  print(string.format("| **Total** | **%d** |", #tests))
  os.exit(0)
end

-- --- run ---
local passed, failed = 0, 0
for _, t in ipairs(tests) do
  local ok, err = pcall(t.fn)
  if ok then
    passed = passed + 1
    print("  PASS  " .. t.name)
  else
    failed = failed + 1
    print("  FAIL  " .. t.name .. "\n          " .. tostring(err))
  end
end
print(string.format("\n%d passed, %d failed, %d total", passed, failed, passed + failed))
os.exit(failed == 0 and 0 or 1)
