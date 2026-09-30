local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local D = NS.DebugLog

local function quiet()
  NS.State.debug = false
  D:Clear()
end

test("DebugLog.FormatPlain: '<ts> | [<tag>] <msg>' with no color codes", function()
  assertEqual(D.FormatPlain("12:34:56", "Panel", "created"), "12:34:56 | [Panel] created")
end)

test("DebugLog.FormatPlain: a nil tag renders as empty brackets, not 'nil'", function()
  assertEqual(D.FormatPlain("12:00:00", nil, "x"), "12:00:00 | [] x")
end)

test("DebugLog.FormatColored: colors the timestamp and the tag", function()
  local line = D.FormatColored("12:34:56", "Panel", "created")
  assertTrue(line:find("|cff6f8faf12:34:56|r", 1, true) ~= nil, "timestamp not steel-blue")
  assertTrue(line:find("|cffc9a66b[Panel]|r", 1, true) ~= nil, "tag not tan/gold")
  assertTrue(line:find("created", 1, true) ~= nil)
end)

test("DebugLog.FormatColored / FormatPlain: the two carry the same content", function()
  -- The copy buffer mirrors the view. If the two formatters drifted, a pasted log would not match
  -- what the user was looking at when they copied it.
  local plain = D.FormatPlain("01:02:03", "Tag", "message body")
  local colored = D.FormatColored("01:02:03", "Tag", "message body")
  for _, fragment in ipairs({ "01:02:03", "Tag", "message body" }) do
    assertTrue(plain:find(fragment, 1, true) ~= nil)
    assertTrue(colored:find(fragment, 1, true) ~= nil)
  end
end)

test("DebugLog.Add: appends to the copy buffer", function()
  quiet()
  D:Add("Test", "one")
  D:Add("Test", "two")
  assertEqual(#D.buffer, 2)
  assertTrue(D.buffer[2]:find("two", 1, true) ~= nil)
end)

test("DebugLog.Clear: empties the buffer", function()
  quiet()
  D:Add("Test", "x")
  D:Clear()
  assertEqual(#D.buffer, 0)
end)

test("NS.Debug: is a no-op when logging is off (zero-alloc gate)", function()
  quiet()
  NS.Debug("Test", "should not appear")
  assertEqual(#D.buffer, 0)
end)

test("NS.Debug: writes when logging is on", function()
  quiet()
  NS.State.debug = true
  NS.Debug("Test", "visible")
  assertTrue(#D.buffer > 0)
  assertTrue(D.buffer[#D.buffer]:find("visible", 1, true) ~= nil)
  quiet()
end)

test("NS.Debug: formats varargs through the secret-safe stringifier", function()
  quiet()
  NS.State.debug = true
  NS.Debug("Test", "%s and %s", "left", 42)
  assertTrue(D.buffer[#D.buffer]:find("left and 42", 1, true) ~= nil)
  quiet()
end)

test("NS.Debug: a boolean arg survives (booleans are never secret)", function()
  quiet()
  NS.State.debug = true
  NS.Debug("Test", "flag=%s", true)
  assertTrue(D.buffer[#D.buffer]:find("flag=true", 1, true) ~= nil)
  quiet()
end)

test("DebugLog.SetEnabled: flips the session flag and brackets the log", function()
  quiet()
  D:SetEnabled(true)
  assertTrue(NS.State.debug)
  -- Both the enable bracket and the [Init] summary land, in that order (debug-logging-§5/§8).
  local enabledAt, initAt
  for i, line in ipairs(D.buffer) do
    if line:find("logging enabled", 1, true) then enabledAt = i end
    if line:find("[Init]", 1, true) then initAt = i end
  end
  assertTrue(enabledAt ~= nil, "no enable bracket")
  assertTrue(initAt ~= nil, "no [Init] session summary on enable")
  assertTrue(initAt > enabledAt, "[Init] must follow the enable bracket")
  quiet()
end)

test("DebugLog.SetEnabled: the disable line lands AFTER the flag flips off", function()
  quiet()
  D:SetEnabled(true)
  D:SetEnabled(false)
  assertFalse(NS.State.debug)
  -- Written through the raw append, not the gated NS.Debug sink — which would have swallowed it.
  assertTrue(D.buffer[#D.buffer]:find("logging disabled", 1, true) ~= nil,
    "the disable bracket was swallowed by the gate")
  quiet()
end)

test("DebugLog.SetEnabled: emits no [Init] summary on disable", function()
  quiet()
  D:SetEnabled(true)
  D:Clear()
  D:SetEnabled(false)
  for _, line in ipairs(D.buffer) do
    assertFalse(line:find("[Init]", 1, true) ~= nil, "[Init] emitted on disable")
  end
  quiet()
end)

test("DebugLog.SetEnabled: the chat ack is color-coded ON green / OFF red", function()
  quiet()
  local chat = T.mocks.__chat
  D:SetEnabled(true)
  assertTrue(chat[#chat]:find("|cff40ff40ON|r", 1, true) ~= nil, "ON is not green")
  D:SetEnabled(false)
  assertTrue(chat[#chat]:find("|cffff4040OFF|r", 1, true) ~= nil, "OFF is not red")
  quiet()
end)

test("DebugLog: the title-bar toggle drives the same seam", function()
  quiet()
  D:Show()   -- builds the frame, and with it the toggle
  assertTrue(D._toggleClickForTest ~= nil, "the header toggle was never built")
  D._toggleClickForTest()
  assertTrue(NS.State.debug, "the header toggle did not flip the flag")
  D._toggleClickForTest()
  assertFalse(NS.State.debug)
  D:Hide()
  quiet()
end)

test("DebugLog: window visibility is independent of the logging flag", function()
  quiet()
  D:SetEnabled(true)
  assertFalse(D:IsShown(), "enabling logging should not open the window")
  D:Show()
  D:SetEnabled(false)
  assertTrue(D:IsShown(), "disabling logging should not close the window")
  D:Hide()
  quiet()
end)

test("DebugLog.Toggle: alternates window visibility", function()
  quiet()
  local before = D:IsShown()
  D:Toggle()
  assertEqual(D:IsShown(), not before)
  D:Toggle()
  assertEqual(D:IsShown(), before)
end)

-- ── One gate, at the sink (debug-logging-§4) ──

test("NS.Debug: call sites do not restate the gate", function()
  -- The sink's first line already gates on NS.State.debug, so `if NS.State.debug and NS.Debug then`
  -- at a call site is the same invariant spelled a second time — and every restatement is a chance
  -- to spell it differently (one site used to add a redundant `NS.State and`). There are now NO
  -- exceptions: the two sites that used to guard their expensive ARGUMENTS go through NS.DebugBuild,
  -- which defers building them past the gate. An empty table here is the point of that change.
  local allowed = {}
  local files = {
    "core/Database.lua", "core/PanelMaster.lua", "core/State.lua", "core/Util.lua",
    "modules/Registry.lua", "modules/Canvas.lua", "modules/Unlock.lua",
    "settings/Schema.lua", "settings/Slash.lua", "settings/Panel.lua", "settings/PanelEditor.lua",
    "settings/PanelEditorTabs.lua",
  }
  for _, path in ipairs(files) do
    local f = assert(io.open(path, "r"), "missing source file " .. path)
    local src = f:read("*a")
    f:close()
    local found = 0
    for _ in src:gmatch("NS%.State[^\n]-%.debug[^\n]-NS%.Debug") do found = found + 1 end
    assertEqual(found, allowed[path] or 0, path .. " restates the NS.Debug gate")
  end
end)

test("NS.Debug: the ungated call sites still log when logging is on", function()
  quiet()
  NS.Registry:DeleteAll()
  NS.State.debug = true
  local rec = NS.Registry:New("Gateless")
  NS.Registry:Rename(rec.id, "Gateless2")
  NS.Registry:Reset(rec.id)
  NS.Registry:Delete(rec.id)
  local joined = table.concat(D.buffer, "\n")
  for _, fragment in ipairs({ "created 'Gateless'", "renamed 'Gateless'", "reset 'Gateless2'",
                              "deleted 'Gateless2'" }) do
    assertTrue(joined:find(fragment, 1, true) ~= nil, "missing log line: " .. fragment)
  end
  quiet()
  NS.Registry:DeleteAll()
end)

test("NS.Debug: deleting every panel at once is traced, with the count (debug-logging-§8)",
function()
  -- A user-initiated purge is a data mutation the log has to show, and a structural registry's
  -- deletes are traced by its writer (debug-logging-§10). Delete goes through
  -- `destroy`, which logs each panel; DeleteAll empties the registry in one sweep, so it has to say
  -- so itself, or `/pm deleteall` and the Panels page's Defaults leave no line behind.
  quiet()
  NS.Registry:DeleteAll()
  NS.Registry:New("Purged1")
  NS.Registry:New("Purged2")
  NS.State.debug = true
  assertEqual(NS.Registry:DeleteAll(), 2)
  local joined = table.concat(D.buffer, "\n")
  assertTrue(joined:find("deleted all 2 panel(s)", 1, true) ~= nil, "DeleteAll left no log line")
  quiet()
end)

test("NS.Debug: the ungated call sites stay silent when logging is off", function()
  quiet()
  NS.Registry:DeleteAll()
  local rec = NS.Registry:New("Silent")
  NS.Registry:Set(rec.id, "width", 300)
  NS.Registry:Delete(rec.id)
  NS.Canvas:RenderAll()
  assertEqual(#D.buffer, 0, "something logged with the flag off")
  NS.Registry:DeleteAll()
end)

-- ── Deferred arguments (NS.DebugBuild) ──

test("NS.DebugBuild: does not call its builder when logging is off", function()
  quiet()
  NS.State.debug = false
  -- The whole point. A site whose arguments cost something to make — a scan, a formatted string —
  -- used to restate the gate to avoid paying for them. Deferring the build past the sink's own gate
  -- removes the reason without moving the invariant back out to the call site.
  local calls = 0
  local function build() calls = calls + 1; return "x" end
  NS.DebugBuild("Test", "%s", build)
  assertEqual(calls, 0, "the builder ran with logging off")
end)

test("NS.DebugBuild: calls the builder and logs when logging is on", function()
  quiet()
  NS.State.debug = true
  local calls = 0
  local function build(a, b) calls = calls + 1; return a .. b end
  NS.DebugBuild("Test", "value %s", build, "on", "e")
  assertEqual(calls, 1)
  assertTrue(D.buffer[#D.buffer]:find("value one", 1, true) ~= nil,
    "the built argument never reached the message")
  quiet()
end)

test("NS.DebugBuild: passes the builder's arguments through unbound", function()
  quiet()
  NS.State.debug = true
  -- Arguments travel separately from the builder rather than captured in a closure. A closure would
  -- be allocated at the CALL SITE, before this function is entered — which is exactly the cost the
  -- deferral exists to avoid, so the shape matters as much as the gate.
  local got
  local function build(...) got = { ... }; return "ok" end
  NS.DebugBuild("Test", "%s", build, 1, "two", true)
  assertEqual(got[1], 1)
  assertEqual(got[2], "two")
  assertEqual(got[3], true)
  NS.State.debug = false
end)

-- ── Bulk copy and reset: one [Set] line per act (debug-logging-§10, standard v2.44.0) ──
--
-- A bulk copy or reset is ONE `[Set]` line naming the act, its scope and the rows it actually wrote,
-- and never one line per row. A profile-wide reset, copy or switch is logged once, by the profile
-- handler, worded by the event. Each case below counts every line of each tag, so a stray per-row
-- line or a second line from another layer fails it.

-- The message of every buffered line carrying `tag`, in order.
local function tagged(tag)
  local out, pat = {}, "%[" .. tag .. "%] (.*)$"
  for _, line in ipairs(D.buffer) do
    local msg = line:match(pat)
    if msg then out[#out + 1] = msg end
  end
  return out
end

local function bulkFresh()
  quiet()
  NS.Registry:DeleteAll()
end

test("bulk log: R:Reset is one [Set] line counting the fields it rewrote", function()
  bulkFresh()
  local rec = NS.Registry:New("Bulky", { width = 500, borderSize = 6 })
  NS.State.debug = true
  assertTrue((NS.Registry:Reset(rec.id)))
  assertEqual(#tagged("Set"), 1)
  assertEqual(tagged("Set")[1], "reset 'Bulky': 2 rows")
  assertEqual(#tagged("Panel"), 0, "the reset still wrote a [Panel] line")
  -- N is rows actually WRITTEN: a second reset finds every field already at its default.
  D:Clear()
  NS.Registry:Reset(rec.id)
  assertEqual(tagged("Set")[1], "reset 'Bulky': 0 rows")
  bulkFresh()
end)

test("bulk log: R:CopyFrom is one [Set] line counting the fields it rewrote", function()
  bulkFresh()
  local src = NS.Registry:New("Src", { width = 500, height = 300, borderSize = 6 })
  local dst = NS.Registry:New("Dst")
  NS.State.debug = true
  assertTrue((NS.Registry:CopyFrom(dst.id, src.id)))
  assertEqual(#tagged("Set"), 1)
  assertEqual(tagged("Set")[1], "copy from 'Src' to 'Dst': 3 rows")
  assertEqual(#tagged("Panel"), 0, "the copy still wrote a [Panel] line")
  -- N is rows actually WRITTEN: copying again finds every field already equal to the source's.
  D:Clear()
  NS.Registry:CopyFrom(dst.id, src.id)
  assertEqual(#tagged("Set"), 1)
  assertEqual(tagged("Set")[1], "copy from 'Src' to 'Dst': 0 rows")
  bulkFresh()
end)

-- The position verbs count ROWS like every other bulk act: the point/relPoint/x/y fields that
-- actually changed, not the panels. They still RETURN the panels moved, for the caller to print.
test("bulk log: R:ResetPositions is one [Set] line counting the position fields it changed",
  function()
  bulkFresh()
  NS.Registry:New("Off1", { x = 100, y = 50 })                                         -- x, y
  NS.Registry:New("Off2", { point = "TOPLEFT", relPoint = "TOPLEFT", x = 10, y = -10 }) -- all four
  NS.Registry:New("Home")                                                               -- none
  NS.State.debug = true
  assertEqual(NS.Registry:ResetPositions(), 2)
  assertEqual(#tagged("Set"), 1)
  assertEqual(tagged("Set")[1], "reset positions: 6 rows")
  assertEqual(#tagged("Panel"), 0)
  D:Clear()
  assertEqual(NS.Registry:ResetPositions(), 0)
  assertEqual(tagged("Set")[1], "reset positions: 0 rows")
  bulkFresh()
end)

test("bulk log: R:Recover is one [Set] line counting the position fields it changed", function()
  bulkFresh()
  NS.Registry:New("Lost1", { x = 9000, y = -9000 })   -- both offsets clamped
  NS.Registry:New("Lost2", { x = -9000, y = 0 })      -- x alone
  NS.Registry:New("Fine", { x = 100, y = 100 })
  NS.State.debug = true
  assertEqual(NS.Registry:Recover(), 2)
  assertEqual(#tagged("Set"), 1)
  assertEqual(tagged("Set")[1], "recover positions: 3 rows")
  assertEqual(#tagged("Panel"), 0)
  D:Clear()
  assertEqual(NS.Registry:Recover(), 0)
  assertEqual(tagged("Set")[1], "recover positions: 0 rows")
  bulkFresh()
end)

-- A bulk act that raises still logs its ONE line, marked ` (stopped by an error)`, still releases
-- the mute, and the error still reaches the caller unchanged.
test("bulk log: a reset-all that raises logs one marked line, unmutes and re-raises", function()
  bulkFresh()
  local S = NS.Schema
  S:Set("settings.gridSize", S:Default("settings.gridSize"))
  local orig = NS.db.ResetProfile
  NS.db.ResetProfile = function()
    S:Set("settings.gridSize", 8)   -- one bracketed row changes before the reset gives up
    error("boom", 0)
  end
  quiet()
  NS.State.debug = true
  local ok, err = pcall(NS.Slash.DoResetAll, NS.Slash)
  NS.db.ResetProfile = orig
  assertFalse(ok)
  assertEqual(err, "boom")
  assertEqual(#tagged("Set") + #tagged("Profile"), 1, table.concat(D.buffer, "\n"))
  assertEqual(tagged("Set")[1], "reset all: 1 rows (stopped by an error)")
  assertFalse(NS.SchemaRuntime.InBulk(), "the bracket stayed open after the act raised")
  assertEqual(S.resetSnapshot, nil)
  D:Clear()
  S:Set("settings.gridSize", S:Default("settings.gridSize"))
  assertEqual(tagged("Set")[1], "settings.gridSize = " .. tostring(S:Default("settings.gridSize")),
    "the seam stayed muted after a raising bracket")
  bulkFresh()
end)

test("bulk log: a page Defaults that raises logs one marked line, unmutes and re-raises", function()
  bulkFresh()
  local S = NS.Schema
  NS.Helpers.RestoreDefaults("general", nil)
  S:Set("settings.gridSize", 8)
  local row = S:FindRow("settings.gridSize")
  local orig = row.onChange
  row.onChange = function() error("boom", 0) end   -- the walk stops at this row, after writing it
  quiet()
  NS.State.debug = true
  local ok, err = pcall(NS.Helpers.RestoreDefaults, "general", nil)
  row.onChange = orig
  assertFalse(ok)
  assertEqual(err, "boom")
  assertEqual(#tagged("Set"), 1, table.concat(D.buffer, "\n"))
  assertEqual(tagged("Set")[1], "reset general: 1 rows (stopped by an error)")
  assertFalse(NS.SchemaRuntime.InBulk(), "the bracket stayed open after the act raised")
  D:Clear()
  NS.Helpers.RestoreDefaults("general", nil)
  assertEqual(tagged("Set")[1], "reset general: 0 rows", "the failure mark outlived its act")
  bulkFresh()
end)

test("bulk log: the global reset is ONE line in total, counting the rows it changed", function()
  bulkFresh()
  local name = NS.db:GetCurrentProfile()
  NS.Slash:DoResetAll()   -- start from the shipped profile
  NS.Schema:Set("settings.gridSize", 8)
  NS.Schema:Set("settings.snapToGrid", false)
  quiet()
  NS.State.debug = true
  NS.Slash:DoResetAll()
  -- A reactor's line (the canvas repainting) is not a [Set] line and stays; what the rule forbids is
  -- a second line for the reset itself, from a bracket or from the switch trace.
  assertEqual(#tagged("Set") + #tagged("Profile"), 1, "a reset-all logged the reset "
    .. (#tagged("Set") + #tagged("Profile")) .. " times:\n" .. table.concat(D.buffer, "\n"))
  assertEqual(tagged("Set")[1], ("reset profile '%s' to defaults (2 rows)"):format(name))
  -- N is rows CHANGED: a reset of a profile already at its defaults logs 0, and still one line.
  D:Clear()
  NS.Slash:DoResetAll()
  assertEqual(#tagged("Set"), 1)
  assertEqual(tagged("Set")[1], ("reset profile '%s' to defaults (0 rows)"):format(name))
  -- The Profiles page's own Reset Profile takes no snapshot: still one line, with no count.
  D:Clear()
  NS.db:ResetProfile()
  assertEqual(#tagged("Set") + #tagged("Profile"), 1)
  assertEqual(tagged("Set")[1], ("reset profile '%s' to defaults"):format(name))
  bulkFresh()
end)

test("bulk log: a profile copy and a profile switch are each worded by their event", function()
  bulkFresh()
  local name = NS.db:GetCurrentProfile()
  NS.State.debug = true
  T.mocks.__db.__fire("OnProfileCopied", NS.db, "Elsewhere")
  assertEqual(#tagged("Set") + #tagged("Profile"), 1)
  assertEqual(tagged("Set")[1], ("copied profile 'Elsewhere' \226\134\146 '%s'"):format(name))
  D:Clear()
  T.mocks.__switchProfile("BulkAlt")
  assertEqual(#tagged("Set"), 0, "a switch rewrote no rows and must not log a [Set] line")
  assertEqual(#tagged("Profile"), 1)
  assertTrue(tagged("Profile")[1]:find("switched to 'BulkAlt'", 1, true) ~= nil)
  quiet()
  T.mocks.__switchProfile(name)
  bulkFresh()
end)

test("bulk log: an act inside another logs once, the outermost, with the total", function()
  bulkFresh()
  local rec = NS.Registry:New("Nested", { width = 500 })
  NS.Helpers.RestoreDefaults("general", nil)
  NS.Schema:Set("settings.gridSize", 8)
  quiet()
  NS.State.debug = true
  NS.Schema.BulkBegin("reset", "everything")
  NS.Helpers.RestoreDefaults("general", nil)   -- a library bracket inside: one row changes
  NS.Registry:Reset(rec.id)                     -- a Registry act inside: one field changes
  NS.Schema.BulkEnd("reset", "everything", nil, nil, { profileReset = false })
  assertEqual(#tagged("Set"), 1, "a nested act logged its own line:\n" .. table.concat(D.buffer, "\n"))
  assertEqual(tagged("Set")[1], "reset everything: 2 rows")
  -- A level that reset the whole profile leaves the line to the profile handler, however deep.
  D:Clear()
  NS.Schema.BulkBegin("reset", "outer")
  NS.Schema.BulkBegin("reset", "all")
  NS.Schema.BulkEnd("reset", "all", 0, nil, { profileReset = true })
  NS.Schema.BulkEnd("reset", "outer", nil, nil, { profileReset = false })
  assertEqual(#tagged("Set"), 0, "a bracket that saw a profile reset logged a line")
  bulkFresh()
end)

test("bulk log: the Options page reset is one [Set] line, N the rows it changed", function()
  bulkFresh()
  NS.Helpers.RestoreDefaults("general", nil)   -- every row at its default first
  NS.Schema:Set("settings.gridSize", 8)
  NS.Schema:Set("settings.snapToGrid", false)
  quiet()
  NS.State.debug = true
  NS.Helpers.RestoreDefaults("general", nil)
  assertEqual(#tagged("Set"), 1, "the page walk logged per row:\n" .. table.concat(D.buffer, "\n"))
  assertEqual(tagged("Set")[1], "reset general: 2 rows")
  -- An all-default Defaults press still logs its one line, with 0, and never a line per row.
  D:Clear()
  NS.Helpers.RestoreDefaults("general", nil)
  assertEqual(#tagged("Set"), 1)
  assertEqual(tagged("Set")[1], "reset general: 0 rows")
  D:Clear()
  NS.Schema:Set("settings.gridSize", 8)
  assertEqual(tagged("Set")[1], "settings.gridSize = 8", "the seam stayed muted after the bracket")
  NS.Schema:Set("settings.gridSize", NS.Schema:Default("settings.gridSize"))
  bulkFresh()
end)

test("bulk log: bulkEnd adds nothing when the act was a whole-profile reset", function()
  bulkFresh()
  NS.State.debug = true
  NS.Schema.BulkBegin("reset", "all")
  NS.Schema:Set("settings.gridSize", 8)
  NS.Schema.BulkEnd("reset", "all", 1, nil, { profileReset = true })
  assertEqual(#tagged("Set"), 0, "a profile-reset bracket logged a line of its own")
  NS.Schema:Set("settings.gridSize", NS.Schema:Default("settings.gridSize"))
  assertEqual(#tagged("Set"), 1, "the seam stayed muted after the bracket")
  bulkFresh()
end)

-- ── Coverage: the diagnosis checklist and the quiet steady state (debug-logging-§8, §9) ──
--
-- The lines a support read of a pasted log needs beyond the flows: the combat and loading-screen
-- edges the renderer acts on, the combat-held unlocks and their flush, the refusals with the guard
-- that said no, the dependencies, and the errors a pcall swallows. Each case below names what goes
-- red without the line it pins. docs/debug.md ▸ Coverage lists every tag.

local function covFresh()
  quiet()
  T.mocks.__inCombat = false
  NS.Unlock:SetUnlocked(false)
  NS.Registry:DeleteAll()
  NS.Canvas:RenderAll()
  quiet()
end

local function has(tag, fragment)
  for _, msg in ipairs(tagged(tag)) do
    if msg:find(fragment, 1, true) then return true end
  end
  return false
end

test("coverage: a combat-held unlock logs its hold and its flush", function()
  -- Red without the hold lines in U:SetUnlocked / U:SetPanelUnlocked, or the flush line in
  -- U:ResumePending: "I unlocked in combat and nothing happened" reads as a lost request, because
  -- the chat line is the only trace and it never reaches a pasted log.
  covFresh()
  local rec = NS.Registry:New("Held")
  NS.State.debug = true
  T.mocks.__inCombat = true
  NS.Unlock:SetUnlocked(true)
  NS.Unlock:SetPanelUnlocked(rec.id, true)
  T.mocks.__inCombat = false
  assertTrue(has("Unlock", "unlock all held: in combat"), "the global hold left no line")
  assertTrue(has("Unlock", "'Held' unlock held: in combat"), "the panel hold left no line")
  NS.Unlock:ResumePending()
  assertTrue(has("Unlock", "combat over: flushed held unlocks (all=yes, 1 panel(s), 0 gone)"),
    "the flush left no line, so the holds above read as never flushed")
  covFresh()
end)

test("coverage: a hold that ends in a lock or a profile change says where it went", function()
  -- Red without the dropped count on the lock line, or ForgetPending's line: a hold with no flush
  -- after it is exactly the shape §8 says must be visible, and these are the two ways it never
  -- flushes on purpose.
  covFresh()
  local a, b = NS.Registry:New("DropA"), NS.Registry:New("DropB")
  NS.State.debug = true
  T.mocks.__inCombat = true
  NS.Unlock:SetUnlocked(true)
  NS.Unlock:SetPanelUnlocked(a.id, true)
  NS.Unlock:SetUnlocked(false)
  assertTrue(has("Unlock", "panels locked, 2 held unlock(s) dropped"), "the lock hid the drop")
  NS.Unlock:SetPanelUnlocked(b.id, true)
  NS.Unlock:ForgetPending()
  assertTrue(has("Unlock", "dropped 1 held panel unlock(s): profile changed"),
    "a profile change dropped a held unlock without a line")
  T.mocks.__inCombat = false
  covFresh()
end)

test("coverage: a combat exit with nothing held writes nothing", function()
  -- The quiet half of the flush: every pull ends in PLAYER_REGEN_ENABLED, so a flush line written
  -- unconditionally would be one line per pull for a whole dungeon.
  covFresh()
  NS.State.debug = true
  local before = #D.buffer
  for _ = 1, 20 do NS.addon:OnRegenEnabled() end
  assertEqual(#D.buffer, before, "an empty combat exit logged")
  covFresh()
end)

test("coverage: the combat edge is logged only when the renderer acts on it", function()
  -- Red without the edge line in Canvas:RenderForCombat (a repaint with no cause), or if it moved
  -- above the visibility test (an Always profile writing two lines per pull).
  covFresh()
  local settings = NS.db.profile.settings
  local was = settings.visibility
  NS.State.debug = true
  settings.visibility = "always"
  local before = #D.buffer
  NS.addon:OnRegenDisabled()
  NS.addon:OnRegenEnabled()
  assertEqual(#D.buffer, before, "an edge the renderer ignores still logged")
  settings.visibility = "inCombat"
  NS.addon:OnRegenDisabled()
  assertTrue(has("Canvas", "combat entered: repainting for visibility 'inCombat'"),
    "the combat entry the renderer acted on left no line")
  NS.addon:OnRegenEnabled()
  assertTrue(has("Canvas", "combat left: repainting for visibility 'inCombat'"),
    "the combat exit the renderer acted on left no line")
  settings.visibility = was
  covFresh()
end)

test("coverage: a loading screen names itself ahead of the repaint it causes", function()
  -- Red without OnEnterWorld's line: every zone change repaints, and without it the log shows a
  -- "rendered" line nothing asked for.
  covFresh()
  NS.State.debug = true
  NS.addon:OnEnterWorld()
  local canvas = tagged("Canvas")
  assertEqual(canvas[1], "entered world: repainting")
  assertTrue(canvas[2] ~= nil and canvas[2]:find("^rendered ") ~= nil, "no repaint after the edge")
  covFresh()
end)

test("coverage: the render summary carries how many panels the ladder left shown", function()
  -- Red if the summary loses its second figure: "rendered 2 panels" cannot tell "my panel is gone"
  -- from "my panel is hidden by a setting" without a diagnostics run.
  covFresh()
  NS.Registry:New("Shown")
  NS.Registry:New("Hidden", { enabled = false })
  NS.State.debug = true
  NS.Canvas:RenderAll()
  assertTrue(has("Canvas", "rendered 2 panels, 1 shown"), "the summary lost its shown count")
  covFresh()
end)

test("coverage: a refused panel verb logs the guard's reason", function()
  -- Red without R's `refuse` helper: the editor and the slash both reach these verbs, and a refusal
  -- that only reached chat left the log saying nothing happened.
  covFresh()
  local rec = NS.Registry:New("Taken")
  NS.State.debug = true
  NS.Registry:New("Taken")
  NS.Registry:Rename("Nobody", "X")
  NS.Registry:Set(rec.id, "width", "wide")
  assertTrue(has("Panel", "create refused: a panel named 'Taken' already exists"))
  assertTrue(has("Panel", "rename refused: no panel called 'Nobody'"))
  assertTrue(has("Panel", "set 'Taken'.width refused: expected a number"))
  covFresh()
end)

test("coverage: the [Init] summary names the optional dependencies", function()
  -- Red without NS.DependencySummary: the flag is off at login, so the summary on enable is the
  -- only place a pasted log learns whether LibSharedMedia (every texture name) and LibDBIcon (the
  -- minimap button) loaded. The headless client ships LibDBIcon and deliberately no LSM.
  local line = NS.InitSummary()
  assertTrue(line:find("LSM no, LibDBIcon yes, Sunn themes %d+$") ~= nil, line)
end)

test("NS.DebugOnce: one line per distinct key, and a key met while off still logs once on", function()
  quiet()
  NS.DebugOnce("test site", "k1", "Test", "first %s", "k1")
  assertEqual(#D.buffer, 0, "DebugOnce logged with the flag off")
  NS.State.debug = true
  for _ = 1, 5 do NS.DebugOnce("test site", "k1", "Test", "first %s", "k1") end
  NS.DebugOnce("test site", "k2", "Test", "second")
  assertEqual(#tagged("Test"), 2, "not one line per distinct key")
  quiet()
end)

-- The one steady-state repeating path: the shared 10Hz mouseover OnUpdate. Driven through the
-- driver's real script, so a line added anywhere under the tick is counted.
local function tick(n)
  local driver = NS.Canvas.__mouseoverDriver
  local script = driver and driver:GetScript("OnUpdate")
  assertTrue(script ~= nil, "no mouseover tick to drive")
  for _ = 1, n do script(driver, 0.1) end
end

test("quiet steady state: 100 mouseover ticks with nothing changing write nothing", function()
  covFresh()
  NS.Registry:New("Fader", { mouseover = true })
  NS.State.debug = true
  local before = #D.buffer
  tick(100)
  assertEqual(#D.buffer, before, "the 10Hz tick logged in steady state")
  covFresh()
end)

test("quiet steady state: an error the tick swallows is one line, not ten a second", function()
  -- Red both ways: without the line in Compat.MouseIsOver the error is invisible (0), and with a
  -- plain NS.Debug there it is one line per tick (100), evicting the log in under six minutes.
  covFresh()
  NS.Registry:New("Fader", { mouseover = true })
  local real = T.mocks.MouseIsOver
  T.mocks.MouseIsOver = function() error("coverage: mouseover boom", 0) end
  NS.State.debug = true
  tick(100)
  T.mocks.MouseIsOver = real
  local n = 0
  for _, msg in ipairs(tagged("Canvas")) do
    if msg:find("MouseIsOver failed: coverage: mouseover boom", 1, true) then n = n + 1 end
  end
  assertEqual(n, 1)
  covFresh()
end)

test("quiet steady state: a missing texture is one line however often it repaints", function()
  -- Red without the line in Compat.FetchMedia (a panel drawn plain with no reason in the log), or
  -- if it were not once per name: every repaint of the panel would repeat it.
  covFresh()
  local libs = T.mocks.__libs
  libs["LibSharedMedia-3.0"] = { Fetch = function() return nil end }
  local ok, err = pcall(function()
    local rec = NS.Registry:New("Plain")
    rec.bgTexture = "Coverage Gone Texture"
    NS.State.debug = true
    for _ = 1, 10 do NS.Canvas:RenderAll() end
  end)
  libs["LibSharedMedia-3.0"] = nil
  assertTrue(ok, tostring(err))
  local n = 0
  for _, msg in ipairs(tagged("Canvas")) do
    if msg:find("background texture 'Coverage Gone Texture' not found: drawn as Solid", 1, true) then
      n = n + 1
    end
  end
  assertEqual(n, 1)
  covFresh()
end)
