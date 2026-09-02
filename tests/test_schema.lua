local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse, assertNear =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNear
local S = NS.Schema

test("Schema.Register: every path resolves against the defaults (architecture-§5)", function()
  -- A typo in a path otherwise reads nil forever and fails silently. 0 unresolved is the gate.
  assertEqual(S:Register(), 0)

  -- And the gate can actually FIRE. Asserting 0 alone is worth nothing if the check is incapable of
  -- returning anything else, which is exactly what it was: a third conjunct required the row to
  -- carry no default, and every row carries one, so `S:Register() == 0` was asserting a constant.
  -- Two probes, because the bug's whole shape was that only the second was ever reachable — a bad
  -- path MUST report whether or not the row has a default of its own.
  local probes = {
    { path = "settings.snapToGird", default = true, type = "bool",
      group = "Editing", label = "typo'd path, WITH a default" },
    { path = "settings.snapToGird", type = "bool",
      group = "Editing", label = "typo'd path, no default" },
  }
  for _, probe in ipairs(probes) do
    S.Schema[#S.Schema + 1] = probe
    local n = S:Register()
    S.Schema[#S.Schema] = nil
    assertEqual(n, 1, probe.label .. " was not reported")
  end

  -- A session-only row is the ONE exemption and stays exempt: it has no db-backed home by design.
  S.Schema[#S.Schema + 1] = { path = "state.notAPath", sessionOnly = true, type = "bool",
    group = "Master controls", label = "session-only, unresolvable path",
    get = function() return false end, set = function() end }
  local sessionCount = S:Register()
  S.Schema[#S.Schema] = nil
  assertEqual(sessionCount, 0, "a session-only row must not be counted as unresolved")

  -- Every probe is off again, so the real schema is intact for the cases below.
  assertEqual(S:Register(), 0)
end)

test("Schema: EVERY row declares a group, and a label and a type with it", function()
  -- The `group` half is options-ui-§13's, and it is the one that catches a real defect rather than
  -- a typo: a page whose rows declare no group cannot draw a strip, so the library reports it and
  -- renders the page untabbed (anti-pattern #69). One row missing a group does not do that -- it
  -- lands in a nil group and simply never appears under any tab.
  --
  -- There is no `widget` assertion any more, and that is not a relaxation. RenderField dispatches
  -- on `type` alone, so `widget` named nothing and could disagree with what was drawn; the field is
  -- gone from every row (settings/Schema.lua's header says why) and asserting on it would have been
  -- asserting on a value with no reader.
  for _, row in ipairs(S.Schema) do
    assertTrue(row.group ~= nil, row.path .. " has no group")
    assertTrue(row.label ~= nil, row.path .. " has no label")
    assertTrue(row.type ~= nil, row.path .. " has no type")
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
  S:Set("state.locked", false)
  assertEqual(NS.db.profile.state, nil, "a session-only row was persisted")
  assertTrue(NS.State.unlocked)
  S:Set("state.locked", true)
end)

test("Schema: Lock frame is the unlock state un-inverted, and negates in BOTH directions", function()
  -- options-ui-§15's canonical row is `Lock frame`; this addon's session state is UNLOCKED. One of
  -- the two had to give and it was the addon's, so the row's get and set both negate.
  --
  -- There is NO stored value behind it, which is why this is a sense change and not a migration:
  -- the row it replaces (`state.unlocked`) was session-only too, so nothing was ever written into
  -- SavedVariables for a migration step to read. What a test can hold onto is the negation, and
  -- both directions are asserted because a get that negates and a set that does not is a control
  -- that reads back the opposite of what it was just told.
  S:Set("state.locked", false)
  assertTrue(NS.State.unlocked, "unticking Lock frame did not unlock the panels")
  assertFalse(S:Get("state.locked"), "the row read back locked while the panels were unlocked")

  S:Set("state.locked", true)
  assertFalse(NS.State.unlocked, "ticking Lock frame did not lock the panels")
  assertTrue(S:Get("state.locked"), "the row read back unlocked while the panels were locked")

  -- And the default is LOCKED, which is the shipped behavior the composer's own default reverses.
  assertTrue(S:Default("state.locked"),
    "Lock frame ships unticked — every install would come back from a reload with draggable panels")
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
    "modules/Unlock.lua", "core/DebugLogSetup.lua", "settings/Slash.lua", "settings/Panel.lua",
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
  -- Keyed on `type`, which is what RenderField dispatches on, so the composed rows are covered by
  -- it too. Under the old `widget == "Slider"` gate they were not: a composed row carries no
  -- `widget`, so master scale and master alpha would have been skipped silently.
  for _, row in ipairs(S.Schema) do
    if row.type == "number" then
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

test("Schema: the General page's tabs are the designed partition, in strip order", function()
  -- THE PARTITION CASE (options-ui-§13). RenderTabbedSchema draws one tab per distinct `group`, in
  -- DECLARATION ORDER, so this array's order is the strip a player sees and the group boundaries
  -- are where one tab ends and the next begins.
  --
  -- Written out as the DESIGNED table rather than derived from the schema, which is the whole
  -- point: a derived expectation agrees with any arrangement of rows, including the one where a row
  -- has quietly drifted into the wrong tab. Adding a row means adding it here too, deliberately.
  local EXPECTED = {
    { tab = "Master controls", count = 7 },
    { tab = "Editing",         count = 4 },
    { tab = "New panels",      count = 4 },
  }

  local order, counts = {}, {}
  for _, row in ipairs(S.Schema) do
    if counts[row.group] == nil then
      counts[row.group] = 0
      order[#order + 1] = row.group
    end
    counts[row.group] = counts[row.group] + 1
  end

  assertEqual(#order, #EXPECTED, "the General page has a different number of tabs than designed")
  for i, want in ipairs(EXPECTED) do
    assertEqual(order[i], want.tab, ("tab %d is '%s', not '%s'"):format(i, tostring(order[i]), want.tab))
    assertEqual(counts[want.tab], want.count, want.tab .. " holds a different number of rows")
  end
end)

test("Schema: a group's rows are contiguous, so no tab's heading prints twice", function()
  -- RenderTabbedSchema partitions in declaration order and RenderRows opens a group when the group
  -- CHANGES. A row filed under a group the array has already left therefore reopens it -- on a
  -- tabbed page that means the tab draws a second, disconnected block; on an untabbed one it prints
  -- the heading twice. Cheap to assert, invisible without a client.
  local seen, current = {}, nil
  for _, row in ipairs(S.Schema) do
    if row.group ~= current then
      assertFalse(seen[row.group] == true,
        row.path .. " reopens the '" .. tostring(row.group) .. "' group after the array left it")
      seen[row.group] = true
      current = row.group
    end
  end
end)

test("Schema: the Panels page's tab strip is the designed one, in strip order", function()
  -- The Panels page is BESPOKE -- a panel is a registry record, not a schema row -- so its strip is
  -- hand-drawn from settings/PanelEditor.lua's own ordered list rather than partitioned out of this
  -- file. It is pinned here anyway, because "which tabs does the settings panel have" is one
  -- question and answering half of it in a different suite is how the other half goes stale.
  local EXPECTED = {
    "General", "Position and size", "Background and border", "Accent bar", "Artwork",
    "Opacity and fade",
  }
  local actual = NS.PanelEditor.TABS
  assertEqual(type(actual), "table", "the editor publishes no tab order")
  assertEqual(#actual, #EXPECTED, "the Panels page has a different number of tabs than designed")
  for i, want in ipairs(EXPECTED) do
    assertEqual(actual[i], want, ("Panels tab %d is '%s', not '%s'"):format(i, tostring(actual[i]), want))
  end
end)

-- ── The Master controls tab (options-ui-§15) ────────────────────────────────────

test("Schema: Master controls is the FIRST tab, and holds exactly the rows it is entitled to",
  function()
    -- WRITTEN OUT as the canonical table, not derived from what the composer happened to emit.
    -- Deriving it would agree with any set in any order — including the one where a row has been
    -- dropped or two have swapped — which is the whole failure the standard's fixed order exists to
    -- prevent. The set is canonical, not a menu: this addon is not frameless (modules/Unlock.lua
    -- calls SetMovable), so every row applies, and `Test mode` is the only non-canonical one and
    -- comes LAST, after the mandated block.
    local EXPECTED = {
      { path = "settings.enabled",    label = "Enable Ka0s Panel Master" },
      { path = "settings.visibility", label = "General visibility" },
      { path = "settings.scale",      label = "Master scale" },
      { path = "settings.alpha",      label = "Master alpha" },
      { path = "state.locked",        label = "Lock frame" },
      { path = "state.debugConsole",  label = "Debug console" },
      { path = "state.preview",       label = "Test mode" },
    }

    assertEqual(S.Schema[1].group, "Master controls",
      "the General page's first tab is '" .. tostring(S.Schema[1].group) .. "'")

    local rows = {}
    for _, row in ipairs(S.Schema) do
      if row.group == "Master controls" then rows[#rows + 1] = row end
    end
    assertEqual(#rows, #EXPECTED, "the Master controls tab holds a different number of rows")
    for i, want in ipairs(EXPECTED) do
      assertEqual(rows[i].path, want.path,
        ("Master controls row %d is '%s', not '%s'"):format(i, tostring(rows[i].path), want.path))
      assertEqual(rows[i].label, want.label,
        ("Master controls row %d is labeled '%s', not '%s'")
          :format(i, tostring(rows[i].label), want.label))
    end
  end)

test("Schema: the Master controls rows are the COMPOSER's, not eight literals here", function()
  -- options-ui-§15/§16: a hand-written copy of a composed block is anti-pattern #73, and the whole
  -- point is that nine addons cannot drift into nine orders. Two halves, because either alone
  -- passes against the wrong thing: the composer really was called (the tail it returns is parked
  -- for settings/Panel.lua), and settings/Schema.lua does not name the canonical labels itself.
  assertEqual(type(S.MasterAfterGroup), "function",
    "no afterGroup hook was kept — the tab's Reset position / Reset all settings pair cannot draw")
  assertEqual(S.MasterGroup, "Master controls",
    "the afterGroup key and the group name disagree, so the hook is detached and nothing errors")

  local f = assert(io.open("settings/Schema.lua", "r"))
  local body = f:read("*a")
  f:close()
  for _, canonical in ipairs({ "Master scale", "Master alpha", "General visibility",
                               "Reset all settings" }) do
    assertEqual(body:find('"' .. canonical .. '"', 1, true), nil,
      "settings/Schema.lua writes out the canonical label " .. canonical ..
      " — those come from H.MasterControls")
  end
end)

test("Schema: no color row is ever disabled by its class-color companion", function()
  -- options-ui-§17 / anti-pattern #74. The swatch is STILL READ under class color — for its alpha —
  -- so graying it tells the player something untrue.
  --
  -- The row loop is vacuously true today and is here on purpose: this addon's colors live on panel
  -- RECORDS rather than on schema rows (settings/PanelEditor.lua draws them from C.COLOR_FIELDS),
  -- so there is no `type = "color"` row to walk. It goes red the day one is added carrying either
  -- defect, which is exactly when nobody would think to look.
  local rows = S.Schema
  for i, row in ipairs(rows) do
    assertEqual(row.disabledIf, nil, row.path .. " carries disabledIf")
    if row.type == "color" then
      local companion = rows[i + 1]
      assertTrue(companion ~= nil and companion.type == "bool"
        and companion.label == "Use class color",
        row.path .. " has no 'Use class color' companion immediately after it")
    end
  end

  -- And the surface this addon actually has: nothing in settings/ ASSIGNS a disabledIf, which is
  -- where the record-backed color pairs are drawn. An assignment rather than a mention, so the
  -- comment in settings/PanelEditor.lua that records why the picker is never grayed does not read
  -- as the defect it is warning about.
  for _, path in ipairs({ "settings/Schema.lua", "settings/PanelEditor.lua",
                          "settings/Panel.lua" }) do
    local f = assert(io.open(path, "r"))
    local body = f:read("*a")
    f:close()
    assertEqual(body:find("disabledIf%s*="), nil, path .. " disables a control by condition")
  end
end)
