local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse, assertNear =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNear
local S = NS.Schema

test("Schema.Register: every path resolves against the defaults (architecture-§5)", function()
  -- A typo in a path otherwise reads nil forever and fails silently. 0 unresolved is the gate.
  assertEqual(S:Register(), 0)
end)

test("Schema: every row declares a group, label, type and widget", function()
  for _, row in ipairs(S.Schema) do
    assertTrue(row.group ~= nil, row.path .. " has no group")
    assertTrue(row.label ~= nil, row.path .. " has no label")
    assertTrue(row.type ~= nil, row.path .. " has no type")
    assertTrue(row.widget ~= nil, row.path .. " has no widget")
  end
end)

test("Schema: every row has a tooltip", function()
  for _, row in ipairs(S.Schema) do
    assertTrue(row.tooltip ~= nil and row.tooltip ~= "", row.path .. " has no tooltip")
  end
end)

test("Schema: paths are unique", function()
  local seen = {}
  for _, row in ipairs(S.Schema) do
    assertEqual(seen[row.path], nil, "duplicate schema path " .. row.path)
    seen[row.path] = true
  end
end)

test("Schema: session-only rows supply their own get and set", function()
  for _, row in ipairs(S.Schema) do
    if row.sessionOnly then
      assertTrue(type(row.get) == "function", row.path .. " has no get")
      assertTrue(type(row.set) == "function", row.path .. " has no set")
    end
  end
end)

test("Schema.FindRow: finds a real path and rejects a bogus one", function()
  assertTrue(S:FindRow("settings.gridSize") ~= nil)
  assertEqual(S:FindRow("settings.nonsense"), nil)
end)

test("Schema.Get / Set: round-trip a boolean", function()
  S:Set("settings.showLabels", false)
  assertFalse(S:Get("settings.showLabels"))
  S:Set("settings.showLabels", true)
  assertTrue(S:Get("settings.showLabels"))
end)

test("Schema.Set: rejects an unknown path", function()
  local ok, err = S:Set("settings.nonsense", 1)
  assertFalse(ok)
  assertTrue(err:find("unknown path", 1, true) ~= nil)
end)

test("Schema.Set: a failing validate blocks the write", function()
  local before = S:Get("settings.gridSize")
  local ok, err = S:Set("settings.gridSize", 99999)
  assertFalse(ok)
  assertEqual(err, "invalid value")
  assertEqual(S:Get("settings.gridSize"), before, "an invalid value was written anyway")
end)

test("Schema.Set: validates the strata dropdown", function()
  assertFalse((S:Set("settings.defaultStrata", "PARCHMENT")))
  assertTrue((S:Set("settings.defaultStrata", "TOOLTIP")))
  S:Set("settings.defaultStrata", "LOW")
end)

test("Schema.Set: a session-only row never touches the DB", function()
  S:Set("state.unlocked", true)
  assertEqual(NS.db.profile.state, nil, "a session-only row was persisted")
  assertTrue(NS.State.unlocked)
  S:Set("state.unlocked", false)
end)

test("Schema.Set: a session-only row reads back through its own get", function()
  S:Set("state.debugConsole", true)
  assertTrue(S:Get("state.debugConsole"))
  S:Set("state.debugConsole", false)
  assertFalse(S:Get("state.debugConsole"))
end)

test("Schema.Set: fires onChange", function()
  local fired = false
  local row = S:FindRow("settings.showLabels")
  local original = row.onChange
  row.onChange = function() fired = true end
  S:Set("settings.showLabels", true)
  row.onChange = original
  assertTrue(fired, "onChange did not run")
end)

test("Schema.Set: a table value is deep-copied, not aliased", function()
  -- Nothing in the current schema stores a table, but the seam must not alias one when a future row
  -- does: a stored alias lets an in-place mutation silently rewrite the shipped default.
  local row = { path = "settings.__probe", default = {}, type = "table" }
  S.Schema[#S.Schema + 1] = row
  local source = { a = 1 }
  S:Set("settings.__probe", source)
  source.a = 2
  assertEqual(NS.db.profile.settings.__probe.a, 1, "the stored table aliased the caller's")
  S.Schema[#S.Schema] = nil
  NS.db.profile.settings.__probe = nil
end)

test("Schema.Default: returns the row's default, deep-copied", function()
  assertEqual(S:Default("settings.gridSize"), 4)
  assertEqual(S:Default("settings.nonsense"), nil)
end)

test("Schema: the defaults match the shipped profile", function()
  -- The row default and defaults/Profile.lua are two places one value is written down, so they are
  -- exactly the pair that drifts.
  for _, row in ipairs(S.Schema) do
    if not row.sessionOnly then
      local shipped = S:ReadPath(NS.defaults.profile, row.path)
      assertEqual(shipped, row.default,
        row.path .. " default disagrees with defaults/Profile.lua")
    end
  end
end)

test("Schema: the master switch reaches the renderer", function()
  local R, Canvas = NS.Registry, NS.Canvas
  R:DeleteAll()
  local rec = R:New("Switched")
  S:Set("settings.enabled", false)
  assertFalse(Canvas:FrameFor(rec.id):IsShown())
  S:Set("settings.enabled", true)
  assertTrue(Canvas:FrameFor(rec.id):IsShown())
  R:DeleteAll()
end)

test("Schema: a gridSize write still changes where the next drag lands (F-012)", function()
  -- The grid rows lost their announce, NOT their effect: U.SnapPosition reads db.profile.settings
  -- live at drag-stop, so the new size applies to the very next drag without any repaint.
  local before = S:Get("settings.gridSize")
  S:Set("settings.snapToGrid", true)
  S:Set("settings.gridSize", 16)
  local x, y = NS.Unlock.SnapPosition(20, -20, NS.db.profile.settings)
  assertEqual(x, 16)
  assertEqual(y, -16)
  S:Set("settings.snapToGrid", false)
  x = NS.Unlock.SnapPosition(20, -20, NS.db.profile.settings)
  assertEqual(x, 20, "snapping stayed on after it was turned off")
  S:Set("settings.snapToGrid", true)
  S:Set("settings.gridSize", before)
end)

test("Schema: the settings message has exactly one sender", function()
  local files = {
    "core/PanelMaster.lua", "core/Database.lua", "modules/Registry.lua", "modules/Canvas.lua",
    "modules/Unlock.lua", "modules/DebugLog.lua", "settings/Slash.lua", "settings/Panel.lua",
  }
  for _, path in ipairs(files) do
    local f = io.open(path, "r")
    local body = f:read("*a")
    f:close()
    assertEqual(body:find("SendMessage%s*%(%s*[\"']Ka0s_PanelMaster_SettingsChanged"), nil,
      path .. " sends SettingsChanged; only settings/Schema.lua may")
  end
end)

test("Schema: the numeric rows declare min and max", function()
  for _, row in ipairs(S.Schema) do
    if row.widget == "Slider" then
      assertTrue(row.min ~= nil and row.max ~= nil, row.path .. " is a slider with no range")
      assertTrue(row.min < row.max, row.path .. " has an inverted range")
      assertTrue(row.default >= row.min and row.default <= row.max,
        row.path .. "'s default is outside its own range")
    end
  end
end)

test("Schema: defaultAlpha stays a fraction", function()
  assertNear(S:Default("settings.defaultAlpha"), 1.0)
  assertFalse((S:Set("settings.defaultAlpha", 255)))
end)
