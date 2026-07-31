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
