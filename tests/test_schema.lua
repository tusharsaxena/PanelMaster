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
  --
  -- The probe goes in through the runtime's AddRows and comes out through Reindex, because the
  -- write seam answers from an INDEX of the rows (LibKa0s-Schema-1.0), not a scan: a row appended
  -- to the array by hand is not a row the seam knows about until it is re-indexed.
  local R = NS.SchemaRuntime
  local row = { path = "settings.__probe", default = {}, type = "table" }
  R.AddRows({ row })
  local source = { a = 1 }
  local ok = S:Set("settings.__probe", source)
  source.a = 2
  S.Schema[#S.Schema] = nil
  R.Reindex()
  assertTrue(ok, "the probe row was refused")
  assertEqual(NS.db.profile.settings.__probe.a, 1, "the stored table aliased the caller's")
  NS.db.profile.settings.__probe = nil
  assertEqual(S:FindRow("settings.__probe"), nil, "the probe row outlived its case")
end)

test("Schema.Default: returns the row's default, deep-copied", function()
  assertEqual(S:Default("settings.gridSize"), 4)
  assertEqual(S:Default("settings.nonsense"), nil)
end)

test("Schema: the defaults match the shipped profile", function()
  -- The row default and defaults/Profile.lua are two places one value is written down, so they are
  -- exactly the pair that drifts.
  --
  -- The minimap row is checked against the GLOBAL defaults and INVERTED, because both halves of
  -- that row are different from every other stored row's: it lives in db.global (launcher-§3) and
  -- its boolean says SHOWN where the stored key says hidden. Skipping it would leave the one row
  -- whose default is written down twice AND negated between the two spellings unchecked, which is
  -- the drift this case exists for.
  for _, row in ipairs(S.Schema) do
    if row.path == S.MINIMAP_PATH then
      assertEqual(S:ReadPath(NS.defaults, row.path), not row.default,
        row.path .. " default disagrees with defaults/Global.lua, or the inversion has been dropped")
    elseif not row.sessionOnly then
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
  --
  -- SIX, and `General` is FIRST. It holds the name box, the copy-from dropdown, Enabled, Unlock,
  -- Reset and Delete — every one an act on the panel WHOLE. That made them page-wide controls under
  -- a tab, which options-ui-§14 forbade outright until v2.40.0 of the standard bounded the chrome
  -- band at ONE ROW and let a page's remaining acts move to a `General` first tab instead. Six of
  -- them stacked the band three rows deep, which is a second page above the page.
  --
  -- Position matters more than membership here: the escape rests entirely on the page OPENING on
  -- this tab, so a `General` anywhere but first is the finding, not `General` existing.
  local EXPECTED = {
    "General", "Position and size", "Background and border", "Accent bar", "Artwork",
    "Opacity and fade",
  }
  local actual = NS.PanelEditor.TABS
  assertEqual(actual[1], "General",
    "General is not first, so its page-wide acts are behind a click again (options-ui-§14)")
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
    -- calls SetMovable), so every frame row applies. `Test mode` does not: unlocking already shows
    -- every panel with its outline and name, so options-ui-§15 exempts it and Lock frame is its switch.
    -- `Minimap button` is the seventh and it is UNCONDITIONAL (launcher-§3): every addon in the
    -- collection has one. With no Test mode to pair beside it, it opens the fourth line alone.
    local EXPECTED = {
      { path = "settings.enabled",    label = "Enable Ka0s Panel Master" },
      { path = "settings.visibility", label = "General visibility" },
      { path = "settings.scale",      label = "Master scale" },
      { path = "settings.alpha",      label = "Master alpha" },
      { path = "state.locked",        label = "Lock frame" },
      { path = "state.debugConsole",  label = "Debug console" },
      { path = "global.minimap.hide", label = "Minimap button" },
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

test("Schema: no Test mode row — Lock frame is this addon's switch (options-ui-§15)", function()
  -- Unlocking already shows every panel with its outline and name, so the unlocked view IS the
  -- test mode, and §15 (standard v2.49.0) exempts an addon like that from a second switch.
  for _, row in ipairs(S.Schema) do
    assertTrue(row.label ~= "Test mode", "a Test mode row is back at " .. tostring(row.path))
    assertTrue(row.path ~= "state.preview", "the state.preview row is back")
  end
  local f = assert(io.open("settings/Schema.lua", "r"))
  local body = f:read("*a")
  f:close()
  -- An assignment, not the word: the spec's comment names the field to say why it is absent.
  assertEqual(body:find("testModePath%s*="), nil,
    "settings/Schema.lua hands the composer a testModePath again")
end)

test("Preview: the sample-panel machinery is gone, and only the sweep's marker remains", function()
  local C = NS.Constants
  assertEqual(NS.Unlock.SetPreview, nil, "U:SetPreview is back")
  assertEqual(NS.Unlock.TogglePreview, nil, "U:TogglePreview is back")
  assertEqual(NS.Unlock.EndPreviewForCombat, nil, "U:EndPreviewForCombat is back")
  assertEqual(NS.State.preview, nil, "NS.State.preview is back")
  assertEqual(NS.State.previewIDs, nil, "NS.State.previewIDs is back")
  assertEqual(C.PREVIEW_PANELS, nil, "C.PREVIEW_PANELS is back")
  assertEqual(NS.Registry.NewBatch, nil, "R:NewBatch is back, with no caller")
  assertEqual(NS.Registry.DeleteBatch, nil, "R:DeleteBatch is back, with no caller")
  -- Kept: an older build's SavedVariables can still hold marked sample panels, and the load sweep
  -- (NS:SweepPreviewPanels) finds them by this field.
  assertEqual(C.PREVIEW_FIELD, "preview", "the sweep's marker field went with the machinery")
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

-- ── The write seam's contract, pinned before LibKa0s-Schema-1.0 took it ─────────
--
-- Written against the host's own `S:Set` / `S:Get` and green there FIRST, so each case below states
-- what the library seam has to keep rather than what it happens to produce. The kept names
-- (`NS.Schema:Set`, `:Get`, `:Default`) are what every caller reaches, so they are what is pinned.

test("Schema seam: a refusal answers the host's own words, and stores nothing", function()
  -- The library's own texts are `Setting not found: %s` and `Invalid value for %s`; this addon
  -- keeps its own through the descriptor's `L`, and this case is what says so.
  local n = select("#", S:Set("settings.nonsense", 1))
  local ok, err = S:Set("settings.nonsense", 1)
  assertFalse(ok)
  assertEqual(err, "unknown path: settings.nonsense")
  assertEqual(n, 2, "an unknown-path refusal answered a different number of values")
  assertEqual(NS.db.profile.settings.nonsense, nil, "a refused path was stored anyway")

  local before = S:Get("settings.gridSize")
  ok, err = S:Set("settings.gridSize", -1)
  assertFalse(ok)
  assertEqual(err, "invalid value")
  assertEqual(S:Get("settings.gridSize"), before, "a refused value was stored anyway")
end)

test("Schema seam: a write answers exactly true", function()
  local before = S:Get("settings.showLabels")
  assertEqual(select("#", S:Set("settings.showLabels", not before)), 1)
  assertEqual(S:Set("settings.showLabels", before), true)
end)

test("Schema seam: a write logs its [Set] line, then runs onChange once", function()
  -- The order is the contract (architecture-5, debug-logging-10): the trace of a write that
  -- landed is written BEFORE any reaction runs, so a reaction that raises cannot erase it.
  -- NS.Debug is read at call time by the seam, so replacing it here reaches the seam's own call.
  local calls = {}
  local row = S:FindRow("settings.showLabels")
  local origDebug, origChange = NS.Debug, row.onChange
  local before = S:Get("settings.showLabels")
  NS.Debug = function(tag, fmt, ...) calls[#calls + 1] = tag .. ": " .. fmt:format(...) end
  row.onChange = function(v) calls[#calls + 1] = "onChange " .. tostring(v) end
  local ok = pcall(S.Set, S, "settings.showLabels", not before)
  NS.Debug, row.onChange = origDebug, origChange
  assertTrue(ok)
  assertEqual(table.concat(calls, " | "),
    ("Set: settings.showLabels = %s | onChange %s"):format(tostring(not before), tostring(not before)))
  S:Set("settings.showLabels", before)
end)

test("Schema seam: a raising onChange propagates, and the write has already landed", function()
  local row = S:FindRow("settings.showLabels")
  local orig = row.onChange
  local before = S:Get("settings.showLabels")
  local boom = {}
  row.onChange = function() error(boom) end
  local ok, err = pcall(S.Set, S, "settings.showLabels", not before)
  row.onChange = orig
  assertFalse(ok, "the seam swallowed a raising onChange")
  assertTrue(err == boom, "the error came back changed")
  assertEqual(S:Get("settings.showLabels"), not before, "the value was not stored before the reaction")
  S:Set("settings.showLabels", before)
end)

test("Schema seam: a read of an interior path answers the stored table itself", function()
  -- A path with no row is still read: `/pm get settings` is a player asking a real question.
  assertTrue(S:Get("settings") == NS.db.profile.settings, "an interior read did not reach the store")
  assertEqual(S:FindRow("settings"), nil, "the probe path has become a row")
end)

test("Schema seam: the library's RestoreDefaults walk over General closes an open debug console", function()
  -- The console row is session-only and composed; what it resets TO is the part at risk. Driven
  -- through the library's own page walk, which calls the descriptor's applyDefault per row. No
  -- player reaches this walk: the General page's Defaults BUTTON is rebound to the profile reset
  -- (settings/Panel.lua), which never writes this row. The player's path is the case below.
  S:Set("state.debugConsole", true)
  assertTrue(S:Get("state.debugConsole"), "the precondition did not take")
  NS.Helpers.RestoreDefaults("general", nil)
  assertFalse(S:Get("state.debugConsole"), "the RestoreDefaults walk left the debug console open")
end)

test("Schema seam: /pm reset state.debugConsole closes an open debug console", function()
  -- JC-5 as a player meets it: the row reset reads `defaults.debugConsole = false`. Without that
  -- default the runtime reads nil as "no restore" and the console stays open.
  S:Set("state.debugConsole", true)
  assertTrue(S:Get("state.debugConsole"), "the precondition did not take")
  assertTrue(NS.DebugLog:IsShown(), "the console window did not open")
  NS.Slash:OnSlash("reset state.debugConsole")
  assertFalse(S:Get("state.debugConsole"), "/pm reset state.debugConsole left the row on")
  assertFalse(NS.DebugLog:IsShown(), "/pm reset state.debugConsole left the console window open")
end)

-- ── The library-absent seam: settings/Schema.lua's host stub ────────────────────
--
-- The stub is WRITE-COMPLETING and LOG-SILENT (docs/api/Schema/version-1-docs.md, "The degradation
-- stub"). One degraded write per writer kind this addon has is pinned landing in the store: a host
-- verb, Reset All, the page Defaults sweep and a runtime writer (a Registry bulk act). Each arm is a
-- REAL LOAD from a partial payload (tests/degraded_env.lua), never a hand-stubbed `lib = nil`.

local Env = dofile("tests/degraded_env.lua")

--- Every [Set] line in a degraded environment's live console buffer.
local function setLines(ns)
  local out = {}
  assertEqual(type(ns.DebugLog.buffer), "table", "the degraded load has no live console buffer to read")
  for _, line in ipairs(ns.DebugLog.buffer) do
    if line:find("[Set]", 1, true) then out[#out + 1] = line end
  end
  return out
end

test("Schema stub: a host verb's write lands, reacts, and refuses in the host's own words", function()
  local ns = Env.loadPartial({ Schema = true })
  assertTrue(ns.SchemaLib ~= NS.SchemaLib, "the degraded load resolved the live library")

  -- `/pm set`, through the live Slash major onto the stub seam, and the row's onChange with it.
  local row = ns.Schema:FindRow("settings.showLabels")
  local seen
  row.onChange = function(v) seen = v end
  ns.State.debug = true
  ns.Slash:OnSlash("set settings.showLabels false")
  assertEqual(ns.db.profile.settings.showLabels, false, "a /pm set did not land on a degraded load")
  assertEqual(seen, false, "the row's onChange did not run on a degraded write")
  -- Log-silent: the stub writes no [Set] line, and that is the whole of what it drops.
  assertEqual(#setLines(ns), 0, "the stub logged a [Set] line")

  -- The reserved pair (slash-commands-§2) writes the master switch through the same seam.
  ns.Slash:OnSlash("disable")
  assertEqual(ns.db.profile.settings.enabled, false, "/pm disable did not land on a degraded load")
  assertFalse(ns.IsAddonEnabled(), "the addon did not stand down")
  ns.Slash:OnSlash("enable")
  assertTrue(ns.IsAddonEnabled(), "the addon did not stand back up")

  local ok, err = ns.Schema:Set("settings.nonsense", 1)
  assertFalse(ok)
  assertEqual(err, "unknown path: settings.nonsense")
  assertEqual(ns.db.profile.settings.nonsense, nil, "the stub stored a path no row declares")
  ok, err = ns.Schema:Set("settings.gridSize", -1)
  assertFalse(ok)
  assertEqual(err, "invalid value")
end)

test("Schema stub: Reset All, the page Defaults and a Registry bulk act all complete", function()
  local ns = Env.loadPartial({ Schema = true })
  local R = ns.SchemaRuntime

  assertTrue(ns.Schema:Set("settings.gridSize", 16), "the precondition was refused")
  ns.Slash:DoResetAll()
  assertEqual(ns.Schema:Get("settings.gridSize"), 4, "Reset All did not reset on a degraded load")
  assertFalse(R.InBulk(), "Reset All left the stub's bracket open")

  assertTrue(ns.Schema:Set("settings.gridSize", 16), "the precondition was refused")
  assertTrue(ns.Schema:Set("state.debugConsole", true), "the precondition was refused")
  assertTrue(ns.Schema:Get("state.debugConsole"), "the console did not open")
  ns.Helpers.RestoreDefaults("general", nil)
  assertEqual(ns.Schema:Get("settings.gridSize"), 4, "the page Defaults did not reset a stored row")
  assertFalse(ns.Schema:Get("state.debugConsole"), "the page Defaults left the console open")
  assertFalse(R.InBulk(), "the page Defaults left the stub's bracket open")

  local rec = ns.Registry:New("Stubbed", { width = 500 })
  assertTrue((ns.Registry:Reset(rec.id)), "a Registry bulk act failed on a degraded load")
  assertEqual(rec.width, ns.Schema:Get("settings.defaultWidth"))
  assertFalse(R.InBulk(), "S.BulkLine left the stub's bracket open")
end)

test("Schema stub: with no LibKa0s at all, the boot check is silent and a write still lands", function()
  local ns, m = Env.loadDegraded()
  local lines = #m.__chat
  assertEqual(ns.Schema:Register(), 0)
  assertEqual(#m.__chat, lines, "the degraded boot check printed a line: " .. tostring(m.__chat[#m.__chat]))
  assertTrue(ns.Schema:Set("settings.gridSize", 8), "a host write was refused on a degraded load")
  assertEqual(ns.db.profile.settings.gridSize, 8)
  assertTrue(ns.IsAddonEnabled(), "the master switch read wrong through the stub")
end)

-- The stub keeps pace with Schema minor 2 (LibKa0s v1.56.0): the all-or-nothing batch SetMany,
-- row.normalize, and the instance id forwarded through Get and ApplyDefault.
-- red under: delete R.SetMany from hostSchemaStub

--- Every answer of a call, with its count, so an arity difference is visible too.
local function pack(...) return { n = select("#", ...), ... } end

--- The two grid rows of `ns`, each with an onChange spy appending `path=value` to the returned log.
local function spyGridRows(ns)
  local log = {}
  for _, path in ipairs({ "settings.gridSize", "settings.snapToGrid" }) do
    ns.Schema:FindRow(path).onChange = function(v) log[#log + 1] = path .. "=" .. tostring(v) end
  end
  return log
end

test("Schema stub: SetMany stores every entry in order and runs each onChange", function()
  local ns = Env.loadPartial({ Schema = true })
  local log = spyGridRows(ns)
  local ok = ns.SchemaRuntime.SetMany({ { path = "settings.gridSize", value = 16 },
                                        { path = "settings.snapToGrid", value = false } })
  assertEqual(ok, true)
  assertEqual(ns.db.profile.settings.gridSize, 16)
  assertEqual(ns.db.profile.settings.snapToGrid, false)
  assertEqual(table.concat(log, ","), "settings.gridSize=16,settings.snapToGrid=false")
end)

test("Schema stub: SetMany is all-or-nothing", function()
  local ns = Env.loadPartial({ Schema = true })
  local R = ns.SchemaRuntime
  local log = spyGridRows(ns)
  local before = ns.db.profile.settings.snapToGrid
  local r = pack(R.SetMany({ { path = "settings.snapToGrid", value = not before },
                             { path = "settings.gridSize", value = 999 } }))
  assertEqual(r.n, 4)
  assertEqual(r[1], false)
  assertEqual(r[2], "invalid value")
  assertEqual(r[3], nil)
  assertEqual(r[4], 2)
  assertEqual(ns.db.profile.settings.snapToGrid, before, "entry 1 was stored by a refused batch")
  assertEqual(#log, 0, "a refused batch ran an onChange")
  r = pack(R.SetMany({ { path = "settings.nonsense", value = 1 } }))
  assertEqual(r[1], false)
  assertEqual(r[2], "unknown path: settings.nonsense")
  assertEqual(r[4], 1)
end)

test("Schema stub: SetMany with opts.act runs inside one bracket", function()
  local ns = Env.loadPartial({ Schema = true })
  local R = ns.SchemaRuntime
  local inside
  ns.Schema:FindRow("settings.gridSize").onChange = function() inside = R.InBulk() end
  assertTrue((R.SetMany({ { path = "settings.gridSize", value = 12 } }, { act = "Import", scope = "grid" })))
  assertEqual(inside, true, "onChange ran outside the batch's bracket")
  assertFalse(R.InBulk(), "SetMany left the bracket open")
  assertTrue((R.SetMany({ { path = "settings.gridSize", value = 10 } })))
  assertEqual(inside, false, "a batch without opts.act opened a bracket")
end)

test("Schema: the live runtime and the stub answer SetMany identically", function()
  local arms = { live = NS, stub = Env.loadPartial({ Schema = true }) }
  local live = NS.db.profile.settings
  local saved = { gridSize = live.gridSize, snapToGrid = live.snapToGrid }
  local batches = {
    { { path = "settings.gridSize", value = 20 }, { path = "settings.snapToGrid", value = false } },
    { { path = "settings.gridSize", value = 8 }, { path = "settings.gridSize", value = 999 } },
    { { path = "settings.snapToGrid", value = true }, { path = "settings.nonsense", value = 1 } },
  }
  local answers = {}
  for name, ns in pairs(arms) do
    answers[name] = {}
    for b, entries in ipairs(batches) do
      local r = pack(ns.SchemaRuntime.SetMany(entries))
      local st = ns.db.profile.settings
      answers[name][b] = string.format("%d|%s|%s|%s|%s|grid=%s|snap=%s", r.n, tostring(r[1]),
        tostring(r[2]), tostring(r[3]), tostring(r[4]), tostring(st.gridSize), tostring(st.snapToGrid))
    end
  end
  live.gridSize, live.snapToGrid = saved.gridSize, saved.snapToGrid
  for b = 1, #batches do
    assertEqual(answers.stub[b], answers.live[b], "batch " .. b .. " answered differently")
  end
end)

test("Schema stub: row.normalize replaces the value, and a nil from it refuses", function()
  local ns = Env.loadPartial({ Schema = true })
  local R = ns.SchemaRuntime
  ns.Schema:FindRow("settings.gridSize").normalize = function(v)
    if v == 13 then return nil, "unlucky" end
    return math.floor(v)
  end
  assertTrue((R.Set("settings.gridSize", 7.6)))
  assertEqual(ns.db.profile.settings.gridSize, 7, "Set stored the value before normalize")
  local r = pack(R.Set("settings.gridSize", 13))
  assertEqual(r[1], false)
  assertEqual(r[2], "invalid value")
  assertEqual(r[3], "unlucky")
  assertEqual(ns.db.profile.settings.gridSize, 7, "a refused normalize stored")
  r = pack(R.SetMany({ { path = "settings.gridSize", value = 9.9 }, { path = "settings.gridSize", value = 13 } }))
  assertEqual(r[3], "unlucky")
  assertEqual(r[4], 2)
  assertTrue((R.SetMany({ { path = "settings.gridSize", value = 9.9 } })))
  assertEqual(ns.db.profile.settings.gridSize, 9, "SetMany stored the value before normalize")
end)

test("Schema stub: Get and ApplyDefault forward the instance id", function()
  local ns = Env.loadPartial({ Schema = true })
  local R = ns.SchemaRuntime
  local gotId, changedId
  R.AddRows({ { path = "settings.probe", default = 1, type = "number",
    get = function(id) gotId = id return 1 end, set = function() end } })
  R.Get("settings.probe", "inst-1")
  assertEqual(gotId, "inst-1", "Get did not hand the id to row.get")
  local row = ns.Schema:FindRow("settings.gridSize")
  row.onChange = function(_, rid) changedId = rid end
  assertTrue((R.ApplyDefault(row, "inst-2")))
  assertEqual(changedId, "inst-2", "ApplyDefault did not forward the id to Set")
end)

test("Schema seam: the live seam is the library's instance, and NS.Schema's names answer it", function()
  -- The adoption in one assertion per half: the instance came from LibKa0s-Schema-1.0 rather than
  -- the stub, and NS.Schema's kept names answer what the instance answers.
  assertTrue(NS.SchemaLib == T.mocks.LibStub("LibKa0s-Schema-1.0"), "the live load fell back to the stub")
  local R = NS.SchemaRuntime
  assertTrue(R.AllRows() == S.Schema, "the runtime holds a copy of the rows, not the array")
  assertTrue(S:FindRow("settings.gridSize") == R.FindRow("settings.gridSize"))
  -- The one refusal whose arity the library sets: `false, err, why`, and this addon's validators
  -- answer no `why`.
  assertEqual(select("#", S:Set("settings.gridSize", -1)), 3)
  assertEqual(select(3, S:Set("settings.gridSize", -1)), nil)
end)

test("Schema: the grid-size slider and the write seam share one maximum", function()
  -- The slider's max was a literal 64 while validate and the drag clamp read C.MAX_GRID (128), so
  -- the three disagreed on what the largest grid is. One constant now bounds all of them.
  local C = NS.Constants
  assertEqual(S:FindRow("settings.gridSize").max, C.MAX_GRID, "the slider's max is not C.MAX_GRID")
  local before = S:Get("settings.gridSize")
  assertFalse(S:Set("settings.gridSize", C.MAX_GRID + 1), "a grid above C.MAX_GRID was accepted")
  assertEqual(S:Get("settings.gridSize"), before, "the refused write still landed")
  assertTrue(S:Set("settings.gridSize", C.MAX_GRID), "C.MAX_GRID itself was refused")
  S:Set("settings.gridSize", S:Default("settings.gridSize"))
end)
