local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local Sl, R = NS.Slash, NS.Registry

-- Capture what the addon printed while running `fn`.
local function capture(fn)
  local chat = T.mocks.__chat
  local before = #chat
  fn()
  local out = {}
  for i = before + 1, #chat do out[#out + 1] = chat[i] end
  return out
end

local function fresh()
  R:DeleteAll()
  NS.Canvas:RenderAll()
end

test("Slash.Register: registers both the short verb and the full-name alias", function()
  assertTrue(T.mocks.__chatCommands["pm"], "/pm was never registered")
  assertTrue(T.mocks.__chatCommands["panelmaster"], "/panelmaster alias missing")
end)

test("Slash.Version: prefers the TOC metadata over the in-code fallback", function()
  assertEqual(Sl:Version(), "0.1.0")
end)

test("Slash.PrintHelp: one row per command, plus a header", function()
  local lines = capture(function() Sl:PrintHelp() end)
  assertEqual(#lines, #NS.COMMANDS + 1)
  assertTrue(lines[1]:find("v0.1.0", 1, true) ~= nil)
end)

test("Slash.PrintHelp: no line ends in a colon (slash-commands-§4)", function()
  for _, line in ipairs(capture(function() Sl:PrintHelp() end)) do
    assertFalse(line:match(":%s*$") ~= nil, "trailing colon: " .. line)
  end
end)

test("Slash.OnSlash: a bare command prints help", function()
  local bare = capture(function() Sl:OnSlash("") end)
  local nilled = capture(function() Sl:OnSlash(nil) end)
  assertEqual(#bare, #NS.COMMANDS + 1)
  assertEqual(#nilled, #NS.COMMANDS + 1)
end)

test("Slash.OnSlash: dispatches from the COMMANDS table", function()
  local ran = false
  NS.COMMANDS[#NS.COMMANDS + 1] = { name = "__probe", desc = "test", fn = function() ran = true end }
  Sl:OnSlash("__probe")
  NS.COMMANDS[#NS.COMMANDS] = nil
  assertTrue(ran)
end)

test("Slash.OnSlash: the verb is case-insensitive", function()
  local got
  NS.COMMANDS[#NS.COMMANDS + 1] = { name = "__probe", desc = "test", fn = function(a) got = a end }
  Sl:OnSlash("__PROBE  Keep My Case")
  NS.COMMANDS[#NS.COMMANDS] = nil
  -- Only the verb is lower-cased; the rest keeps its case, or panel names and schema paths would be
  -- mangled on the way in.
  assertEqual(got, "Keep My Case")
end)

test("Slash.OnSlash: an unknown verb reports it and prints help", function()
  local lines = capture(function() Sl:OnSlash("nonsense") end)
  assertTrue(lines[1]:find("unknown command", 1, true) ~= nil)
  assertEqual(#lines, #NS.COMMANDS + 2)
end)

test("Slash.BuildListLines: the header, then group headers, then rows", function()
  local lines = Sl:BuildListLines()
  assertTrue(lines[1]:find("|cff33ff99Available settings|r", 1, true) ~= nil)
  assertTrue(lines[2]:find("|cff3399ff[", 1, true) ~= nil, "no azure group header")
  assertTrue(lines[3]:find("|cffffff00", 1, true) ~= nil, "no gold key")
end)

test("Slash.BuildListLines: indentation is two spaces for groups, four for rows", function()
  for _, line in ipairs(Sl:BuildListLines()) do
    if line:find("|cff3399ff", 1, true) then
      assertTrue(line:sub(1, 2) == "  " and line:sub(3, 3) ~= " ", "bad group indent: " .. line)
    elseif line:find("|cffffff00", 1, true) then
      assertTrue(line:sub(1, 4) == "    ", "bad row indent: " .. line)
    end
  end
end)

test("Slash.BuildListLines: lists every schema row exactly once", function()
  local rows = 0
  for _, line in ipairs(Sl:BuildListLines()) do
    if line:sub(1, 4) == "    " then rows = rows + 1 end
  end
  assertEqual(rows, #NS.Schema.Schema)
end)

test("Slash.LIST_GROUP_ORDER: every declared group actually exists", function()
  -- A name that matches nothing fails invisibly: the listing silently falls through to first-seen
  -- order and nobody notices until the pages come out shuffled.
  local groups = {}
  for _, row in ipairs(NS.Schema.Schema) do groups[row.group] = true end
  for _, name in ipairs(Sl.LIST_GROUP_ORDER) do
    assertTrue(groups[name], "LIST_GROUP_ORDER names a group that does not exist: " .. name)
  end
end)

test("Slash.LIST_GROUP_ORDER: covers every group in the schema", function()
  local declared = {}
  for _, name in ipairs(Sl.LIST_GROUP_ORDER) do declared[name] = true end
  for _, row in ipairs(NS.Schema.Schema) do
    assertTrue(declared[row.group], "group '" .. row.group .. "' is not in LIST_GROUP_ORDER")
  end
end)

test("Slash.FormatSchemaValue: applies a row's fmt to numbers", function()
  local row = NS.Schema:FindRow("settings.gridSize")
  assertEqual(Sl.FormatSchemaValue(row, 4), "4 px")
end)

test("Slash.FormatSchemaValue: booleans render true/false", function()
  local row = NS.Schema:FindRow("settings.snapToGrid")
  assertEqual(Sl.FormatSchemaValue(row, true), "true")
  assertEqual(Sl.FormatSchemaValue(row, false), "false")
end)

test("Slash.FormatKV: gold key, white value, no trailing colon", function()
  local line = Sl.FormatKV("a.b", "7")
  assertEqual(line, "|cffffff00a.b|r = |cffffffff7|r")
  assertFalse(line:match(":%s*$") ~= nil)
end)

test("Slash.CliGet: prints the key = value line", function()
  local lines = capture(function() Sl:CliGet("settings.gridSize") end)
  assertEqual(#lines, 1)
  assertTrue(lines[1]:find("settings.gridSize", 1, true) ~= nil)
end)

test("Slash.CliGet: an unknown path is reported", function()
  local lines = capture(function() Sl:CliGet("settings.nope") end)
  assertTrue(lines[1]:find("Setting not found", 1, true) ~= nil)
end)

test("Slash.CliGet: with no argument, prints usage", function()
  local lines = capture(function() Sl:CliGet("") end)
  assertTrue(lines[1]:find("Usage", 1, true) ~= nil)
end)

test("Slash.CliSet: writes and echoes the STORED value", function()
  local lines = capture(function() Sl:CliSet("settings.gridSize 8") end)
  assertEqual(NS.Schema:Get("settings.gridSize"), 8)
  assertTrue(lines[1]:find("8 px", 1, true) ~= nil, "the echo did not use the row's fmt")
  Sl:CliSet("settings.gridSize 4")
end)

test("Slash.CliSet: coerces booleans from words", function()
  Sl:CliSet("settings.snapToGrid off")
  assertFalse(NS.Schema:Get("settings.snapToGrid"))
  Sl:CliSet("settings.snapToGrid on")
  assertTrue(NS.Schema:Get("settings.snapToGrid"))
end)

test("Slash.CliSet: an unreadable boolean is refused, not stored as false (F-023)", function()
  Sl:CliSet("settings.snapToGrid on")
  local lines = capture(function() Sl:CliSet("settings.snapToGrid ture") end)
  assertTrue(lines[1]:find("expected true/false", 1, true) ~= nil,
    "the refusal does not list the accepted tokens")
  -- `/pm set settings.enabled ture` used to turn panels OFF and echo `= false`. Every other type in
  -- this dispatcher reports a parse failure; booleans do too now.
  assertTrue(NS.Schema:Get("settings.snapToGrid"), "a typo turned the setting off")
end)

test("Slash.CliSet: accepts a lower-case dropdown token", function()
  Sl:CliSet("settings.defaultStrata low")
  assertEqual(NS.Schema:Get("settings.defaultStrata"), "LOW")
  Sl:CliSet("settings.defaultStrata background")
end)

test("Slash.CliSet: a non-number for a number row is refused", function()
  local before = NS.Schema:Get("settings.gridSize")
  local lines = capture(function() Sl:CliSet("settings.gridSize banana") end)
  assertTrue(lines[1]:find("expected a number", 1, true) ~= nil)
  assertEqual(NS.Schema:Get("settings.gridSize"), before)
end)

test("Slash.CliSet: a rejected validate is reported as an error", function()
  local lines = capture(function() Sl:CliSet("settings.gridSize 99999") end)
  assertTrue(lines[1]:find("error", 1, true) ~= nil)
end)

test("Slash.CliReset: restores one setting's default", function()
  Sl:CliSet("settings.gridSize 16")
  Sl:CliReset("settings.gridSize")
  assertEqual(NS.Schema:Get("settings.gridSize"), 4)
end)

test("Slash.CliResetAll: restores every setting and leaves panels alone", function()
  fresh()
  R:New("Survivor")
  Sl:CliSet("settings.gridSize 16")
  Sl:CliResetAll()
  assertEqual(NS.Schema:Get("settings.gridSize"), 4)
  -- "Reset my settings" and "delete my work" are different requests.
  assertEqual(R:Count(), 1, "resetall deleted the user's panels")
  fresh()
end)

test("Slash.CliVersion: prints v<version>", function()
  local lines = capture(function() Sl:CliVersion() end)
  assertTrue(lines[1]:find("v0.1.0", 1, true) ~= nil)
end)

-- ── Panel CLI ───────────────────────────────────────────────────────────────────

test("Slash.CliNew: creates a panel and confirms", function()
  fresh()
  local lines = capture(function() Sl:CliNew("Chat BG") end)
  assertEqual(R:Count(), 1)
  assertTrue(lines[1]:find("Chat BG", 1, true) ~= nil)
end)

test("Slash.CliNew: with no name, prints usage", function()
  fresh()
  local lines = capture(function() Sl:CliNew("") end)
  assertTrue(lines[1]:find("Usage", 1, true) ~= nil)
  assertEqual(R:Count(), 0)
end)

test("Slash.CliNew: a duplicate is reported as an error", function()
  fresh()
  Sl:CliNew("Dup")
  local lines = capture(function() Sl:CliNew("Dup") end)
  assertTrue(lines[1]:find("error", 1, true) ~= nil)
  assertEqual(R:Count(), 1)
end)

test("Slash.CliDelete: removes the panel", function()
  fresh()
  Sl:CliNew("Doomed")
  Sl:CliDelete("Doomed")
  assertEqual(R:Count(), 0)
end)

test("Slash.CliRename: renames and reports both names", function()
  fresh()
  Sl:CliNew("Old")
  local lines = capture(function() Sl:CliRename("Old Brand New") end)
  assertTrue(lines[1]:find("Old", 1, true) ~= nil)
  assertTrue(lines[1]:find("Brand New", 1, true) ~= nil)
  assertTrue(R:FindByName("Brand New") ~= nil)
end)

test("Slash.CliRename: with one word, prints usage", function()
  fresh()
  local lines = capture(function() Sl:CliRename("OnlyOne") end)
  assertTrue(lines[1]:find("Usage", 1, true) ~= nil)
end)

test("Slash.BuildPanelLines: an empty registry says so and suggests the next step", function()
  fresh()
  local lines = Sl:BuildPanelLines()
  assertEqual(#lines, 1)
  assertTrue(lines[1]:find("/pm new", 1, true) ~= nil)
end)

test("Slash.BuildPanelLines: one row per panel, plus a header", function()
  fresh()
  R:New("A"); R:New("B")
  local lines = Sl:BuildPanelLines()
  assertEqual(#lines, 3)
  assertTrue(lines[1]:find("(2)", 1, true) ~= nil)
end)

test("Slash.BuildPanelLines: a disabled panel is dimmed, not hidden", function()
  fresh()
  local rec = R:New("Off")
  R:Set(rec.id, "enabled", false)
  local lines = Sl:BuildPanelLines()
  -- The listing is how you find a disabled panel to re-enable it, so it must still appear.
  assertEqual(#lines, 2)
  assertTrue(lines[2]:find("|cff808080", 1, true) ~= nil, "a disabled panel was not dimmed")
end)

test("Slash.CliPanel: with no field, dumps every field in the declared order", function()
  fresh()
  R:New("Dumped")
  local lines = capture(function() Sl:CliPanel("Dumped") end)
  assertEqual(#lines, #NS.Constants.PANEL_FIELD_ORDER + 1)
  assertTrue(lines[2]:find("name", 1, true) ~= nil, "the dump is not in declared order")
end)

test("Slash.CliPanel: with a field, prints just that field", function()
  fresh()
  R:New("Queried")
  local lines = capture(function() Sl:CliPanel("Queried width") end)
  assertEqual(#lines, 1)
  assertTrue(lines[1]:find("width", 1, true) ~= nil)
end)

test("Slash.CliPanel: with a value, sets it and echoes the stored result", function()
  fresh()
  local rec = R:New("Edited")
  local lines = capture(function() Sl:CliPanel("Edited width 500") end)
  assertEqual(R:Get(rec.id).width, 500)
  assertTrue(lines[1]:find("500", 1, true) ~= nil)
end)

test("Slash.CliPanel: the echo reflects clamping, not what was typed", function()
  fresh()
  R:New("Clamped")
  local lines = capture(function() Sl:CliPanel("Clamped alpha 9") end)
  assertTrue(lines[1]:find("1.00", 1, true) ~= nil, "the echo showed the typed value, not the stored one")
end)

test("Slash.CliPanel: sets a color from a string", function()
  fresh()
  local rec = R:New("Painted")
  Sl:CliPanel("Painted bgColor 1,0,0,0.5")
  local c = R:Get(rec.id).bgColor
  assertEqual(c[1], 1)
end)

test("Slash.CliPanel: an unknown panel is reported", function()
  fresh()
  local lines = capture(function() Sl:CliPanel("Ghost") end)
  assertTrue(lines[1]:find("no panel", 1, true) ~= nil)
end)

test("Slash.CliPanel: an unknown field lists the valid ones", function()
  fresh()
  R:New("Strict")
  local lines = capture(function() Sl:CliPanel("Strict sparkles 1") end)
  assertTrue(lines[1]:find("unknown field", 1, true) ~= nil)
  assertTrue(lines[1]:find("width", 1, true) ~= nil, "the error should list the valid fields")
end)

test("Slash.CliPanel deleteall: goes through the confirm popup", function()
  fresh()
  R:New("A"); R:New("B")
  local before = #T.mocks.__popupsShown
  Sl:CliPanel("deleteall")
  assertEqual(#T.mocks.__popupsShown, before + 1, "no confirm was raised")
  assertEqual(T.mocks.__popupsShown[#T.mocks.__popupsShown], "KA0S_PANELMASTER_DELETEALL")
  -- Destructive, so nothing is deleted until the user accepts.
  assertEqual(R:Count(), 2, "panels were deleted before the confirm was accepted")
  fresh()
end)

test("Slash.CliPanel: a panel genuinely named 'deleteall' is still reachable (F-022)", function()
  fresh()
  local rec = R:New("deleteall")
  local before = #T.mocks.__popupsShown
  local lines = capture(function() Sl:CliPanel("deleteall") end)
  -- The verb only wins when no panel answers to the name, so the one panel whose name collides with
  -- it can still be inspected and edited from the CLI instead of being permanently shadowed.
  assertEqual(#T.mocks.__popupsShown, before, "the wipe confirm fired for a panel lookup")
  assertTrue(lines[1]:find("deleteall", 1, true) ~= nil, "the panel dump never appeared")
  assertEqual(R:Count(), 1, "the panel was deleted instead of shown")
  R:Delete(rec.id)
  fresh()
end)

test("Slash.CliRecover: reports when nothing needed moving", function()
  fresh()
  R:New("Fine", { x = 10, y = 10 })
  local lines = capture(function() Sl:CliRecover() end)
  assertTrue(lines[1]:find("already on screen", 1, true) ~= nil)
end)

test("Slash.CliRecover: reports how many it moved", function()
  fresh()
  R:New("Lost", { x = 9000, y = 0 })
  local lines = capture(function() Sl:CliRecover() end)
  assertTrue(lines[1]:find("moved 1 panel", 1, true) ~= nil)
  fresh()
end)

test("Slash: every printed line carries the shared cyan tag", function()
  fresh()
  R:New("Tagged")
  local lines = capture(function()
    Sl:CliPanels(); Sl:CliList(); Sl:PrintHelp(); Sl:CliVersion()
  end)
  for _, line in ipairs(lines) do
    assertTrue(line:sub(1, #NS.PREFIX) == NS.PREFIX, "untagged line: " .. line)
  end
  fresh()
end)

-- ── The command table ──
-- These live here rather than beside the settings schema because the table, the dispatcher, the
-- generated help and the sixteen Cli* implementations are one surface (slash-commands-§3).

test("COMMANDS: the table is defined beside its dispatcher", function()
  -- It used to sit in settings/Schema.lua, one file away from everything that reads it. A source
  -- scan is the only way to assert WHERE it lives: at runtime NS.COMMANDS is just a namespace field
  -- and every file has already loaded by the time the suite looks at it.
  local f = assert(io.open("settings/Slash.lua", "r"))
  local slash = f:read("*a")
  f:close()
  assertTrue(slash:find("\nNS.COMMANDS = {", 1, true) ~= nil,
    "NS.COMMANDS should be defined in settings/Slash.lua")

  f = assert(io.open("settings/Schema.lua", "r"))
  local schema = f:read("*a")
  f:close()
  assertEqual(schema:find("NS.COMMANDS", 1, true), nil,
    "settings/Schema.lua should no longer mention the command table")
end)

test("COMMANDS: every entry has a name, description and function", function()
  for _, cmd in ipairs(NS.COMMANDS) do
    assertTrue(type(cmd.name) == "string" and cmd.name ~= "")
    assertTrue(type(cmd.desc) == "string" and cmd.desc ~= "")
    assertTrue(type(cmd.fn) == "function", cmd.name .. " has no function")
  end
end)

test("COMMANDS: names are unique and lower-case", function()
  local seen = {}
  for _, cmd in ipairs(NS.COMMANDS) do
    assertEqual(seen[cmd.name], nil, "duplicate command " .. cmd.name)
    assertEqual(cmd.name, cmd.name:lower(), cmd.name .. " is not lower-case")
    seen[cmd.name] = true
  end
end)

test("COMMANDS: the standard's required verbs are present (slash-commands-§3)", function()
  local have = {}
  for _, cmd in ipairs(NS.COMMANDS) do have[cmd.name] = true end
  for _, required in ipairs({ "config", "version", "get", "set", "list",
                              "reset", "resetall", "debug", "help" }) do
    assertTrue(have[required], "missing the required '" .. required .. "' verb")
  end
end)

test("COMMANDS: the descs name the sub-verbs their handlers accept (F-011)", function()
  -- `/pm debug dump` and `/pm panel deleteall` both work, and neither used to appear in the
  -- generated help index, on the settings landing page or in the README — all three of which
  -- generate from these descs (slash-commands-§3 forbids a hand-maintained help string, so the desc
  -- is the only place the text can go).
  local desc = {}
  for _, cmd in ipairs(NS.COMMANDS) do desc[cmd.name] = cmd.desc end
  assertTrue(desc.debug:find("dump", 1, true) ~= nil,
    "the debug row never mentions 'dump', the verb a bug report asks for")
  assertTrue(desc.panel:find("deleteall", 1, true) ~= nil,
    "the panel row never mentions 'deleteall', which destroys every panel")
end)

test("PrintHelp: the generated rows carry the sub-verbs too", function()
  -- The help index is generated, so surfacing a sub-verb in the desc is enough. This is the
  -- assertion that the generation still holds — a hand-written help block would break it.
  local lines = capture(function() Sl:PrintHelp() end)
  local found = { dump = false, deleteall = false }
  for _, line in ipairs(lines) do
    if line:find("dump", 1, true) then found.dump = true end
    if line:find("deleteall", 1, true) then found.deleteall = true end
  end
  assertTrue(found.dump, "'dump' reaches no help row")
  assertTrue(found.deleteall, "'deleteall' reaches no help row")
end)
