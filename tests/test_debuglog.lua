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

test("DebugLog.Diagnose: reports the registry and the renderer together", function()
  quiet()
  NS.Registry:DeleteAll()
  NS.Canvas:RenderAll()
  NS.Registry:New("Inspected")
  local lines = D:Diagnose()
  local joined = table.concat(lines, "\n")
  assertTrue(joined:find("registry: 1 panels", 1, true) ~= nil)
  assertTrue(joined:find("Inspected", 1, true) ~= nil)
  assertTrue(joined:find("frame=yes", 1, true) ~= nil,
    "the panel has no frame, or Diagnose cannot see it")
  assertTrue(joined:find("orphaned", 1, true) ~= nil)
  NS.Registry:DeleteAll()
end)

test("DebugLog.Diagnose: counts active, pooled and orphaned frames", function()
  quiet()
  NS.Registry:DeleteAll()
  NS.Canvas:RenderAll()
  NS.Registry:New("Counted")
  NS.Registry:New("Tallied")
  -- The pool count is how you tell a leak from healthy reuse, and a frame with no record IS the
  -- leak. The orphan half is asserted against a real orphan rather than against the zero every
  -- healthy fixture already reads: a "0 orphaned" that never sees one passes just as happily
  -- against code that never counts one.
  local pooled = NS.Canvas.PooledCount()
  local joined = table.concat(D:Diagnose(), "\n")
  assertTrue(joined:find(("frames: 2 active, %d pooled, 0 orphaned"):format(pooled), 1, true) ~= nil,
    "the frame-count line does not read as expected: " .. joined)

  -- A record that went away without the renderer being told is exactly that leak, so it is made the
  -- same way: the record is lifted straight out of the array Registry owns, leaving Canvas still
  -- holding its frame. Going through R:Delete would release the frame too, and there would be
  -- nothing left to count.
  local records = NS.Registry:All()
  local stolen = table.remove(records)
  joined = table.concat(D:Diagnose(), "\n")
  assertTrue(joined:find(("frames: 2 active, %d pooled, 1 orphaned"):format(pooled), 1, true) ~= nil,
    "an orphaned frame is not counted: " .. joined)

  -- Put it back, so the frame is released through the normal path and no orphan is left in the
  -- counts the later cases assert on.
  records[#records + 1] = stolen
  NS.Registry:DeleteAll()
end)

test("DebugLog.Diagnose: works with logging off", function()
  quiet()
  -- It is a structured DUMP verb, not a log line: it must work whether or not capture is enabled
  -- (debug-logging-§4), otherwise you cannot inspect a live problem without first perturbing it.
  assertTrue(#D:Diagnose() > 0)
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
  -- deletes are traced by its writer (debug-logging-§10). Delete and DeleteBatch go through
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

test("bulk log: R:ResetPositions is one [Set] line counting the panels it moved", function()
  bulkFresh()
  NS.Registry:New("Off1", { x = 100, y = 50 })
  NS.Registry:New("Off2", { point = "TOPLEFT", relPoint = "TOPLEFT", x = 10, y = -10 })
  NS.Registry:New("Home")
  NS.State.debug = true
  assertEqual(NS.Registry:ResetPositions(), 2)
  assertEqual(#tagged("Set"), 1)
  assertEqual(tagged("Set")[1], "reset positions: 2 panels")
  assertEqual(#tagged("Panel"), 0)
  D:Clear()
  assertEqual(NS.Registry:ResetPositions(), 0)
  assertEqual(tagged("Set")[1], "reset positions: 0 panels")
  bulkFresh()
end)

test("bulk log: R:Recover is one [Set] line counting the panels it moved", function()
  bulkFresh()
  NS.Registry:New("Lost1", { x = 9000, y = -9000 })
  NS.Registry:New("Lost2", { x = -9000, y = 9000 })
  NS.Registry:New("Fine", { x = 100, y = 100 })
  NS.State.debug = true
  assertEqual(NS.Registry:Recover(), 2)
  assertEqual(#tagged("Set"), 1)
  assertEqual(tagged("Set")[1], "recover positions: 2 panels")
  assertEqual(#tagged("Panel"), 0)
  D:Clear()
  assertEqual(NS.Registry:Recover(), 0)
  assertEqual(tagged("Set")[1], "recover positions: 0 panels")
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
