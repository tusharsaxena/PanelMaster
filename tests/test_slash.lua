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
  NS.COMMANDS[#NS.COMMANDS + 1] = { "__probe", "test", function() ran = true end }
  Sl:OnSlash("__probe")
  NS.COMMANDS[#NS.COMMANDS] = nil
  assertTrue(ran)
end)

test("Slash.OnSlash: the verb is case-insensitive", function()
  local got
  NS.COMMANDS[#NS.COMMANDS + 1] = { "__probe", "test", function(a) got = a end }
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
  assertTrue(lines[3]:find("|cFFFFFF00", 1, true) ~= nil, "no gold key")
end)

test("Slash.BuildListLines: indentation is two spaces for groups, four for rows", function()
  for _, line in ipairs(Sl:BuildListLines()) do
    if line:find("|cff3399ff", 1, true) then
      assertTrue(line:sub(1, 2) == "  " and line:sub(3, 3) ~= " ", "bad group indent: " .. line)
    elseif line:find("|cFFFFFF00", 1, true) then
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

test("Slash.BuildListLines: groups appear in schema DECLARATION order", function()
  -- This replaces the hand-maintained Sl.LIST_GROUP_ORDER constant, which named the three schema
  -- groups in the order they are already declared in — pure duplication, and a name that matched
  -- nothing would have failed invisibly. LibKa0s-Slash-1.0 groups in declaration order outright, on
  -- the reasoning that a schema's own order is the order its panel shows and a listing that
  -- disagreed with the panel would be its own puzzle. The property is now asserted directly.
  local declared, seen = {}, {}
  for _, row in ipairs(NS.Schema.Schema) do
    local g = row.group or "?"
    if not seen[g] then seen[g] = true; declared[#declared + 1] = g end
  end
  local rendered = {}
  for _, line in ipairs(Sl:BuildListLines()) do
    local g = line:match("^  |cff3399ff%[(.-)%]|r$")
    if g then rendered[#rendered + 1] = g end
  end
  assertEqual(#rendered, #declared, "the listing and the schema disagree about how many groups exist")
  for i, g in ipairs(declared) do
    assertEqual(rendered[i], g, "group " .. i .. " is out of declaration order")
  end
end)

test("Slash.BuildListLines: every group in the schema reaches the listing", function()
  local rendered = {}
  for _, line in ipairs(Sl:BuildListLines()) do
    local g = line:match("^  |cff3399ff%[(.-)%]|r$")
    if g then rendered[g] = true end
  end
  for _, row in ipairs(NS.Schema.Schema) do
    assertTrue(rendered[row.group], "group '" .. tostring(row.group) .. "' never reaches /pm list")
  end
end)

test("Slash value rendering: a row's fmt still reaches the number", function()
  -- Sl.FormatSchemaValue is gone; LibKa0s-Slash-1.0's lib.FormatValue renders every list/get/set
  -- echo now. It reads the same `fmt` field, so "4 px" survives — asserted through the rendered
  -- line rather than by calling the formatter, because the rendered line is what a user sees.
  Sl:CliReset("settings.gridSize")
  local lines = capture(function() Sl:CliGet("settings.gridSize") end)
  assertEqual(#lines, 1)
  assertTrue(lines[1]:find("4 px", 1, true) ~= nil, "the row's fmt was dropped: " .. lines[1])
end)

test("Slash value rendering: booleans render true/false", function()
  Sl:CliSet("settings.snapToGrid on")
  local on = capture(function() Sl:CliGet("settings.snapToGrid") end)
  assertTrue(on[1]:find("= |cFFFFFFFFtrue|r", 1, true) ~= nil, "not rendered as true: " .. on[1])
  Sl:CliSet("settings.snapToGrid off")
  local off = capture(function() Sl:CliGet("settings.snapToGrid") end)
  assertTrue(off[1]:find("= |cFFFFFFFFfalse|r", 1, true) ~= nil, "not rendered as false: " .. off[1])
  Sl:CliSet("settings.snapToGrid on")
end)

test("Slash.FormatKV: gold key, white value, no trailing colon", function()
  -- This formatter is now LibKa0s-Slash-1.0's, so the color escapes are UPPERCASE where this
  -- addon's own were lowercase. WoW's escape parser is case-insensitive, so the rendered pixels are
  -- identical and only the source bytes moved — but the bytes are what a test can see, so they are
  -- what it asserts.
  local line = Sl.FormatKV("a.b", "7")
  assertEqual(line, "|cFFFFFF00a.b|r = |cFFFFFFFF7|r")
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
  -- Two lines now, not one: LibKa0s-Slash-1.0 emits "Invalid value for <path>" and then the reason,
  -- indented, on its own line. The reason still lists every accepted token.
  assertTrue(lines[1]:find("Invalid value for settings.snapToGrid", 1, true) ~= nil,
    "the refusal does not name the setting: " .. lines[1])
  assertTrue(lines[2]:find("expected true/false", 1, true) ~= nil,
    "the refusal does not list the accepted tokens: " .. tostring(lines[2]))
  -- `/pm set settings.enabled ture` used to turn panels OFF and echo `= false`. Every other type in
  -- this dispatcher reports a parse failure; booleans do too now.
  assertTrue(NS.Schema:Get("settings.snapToGrid"), "a typo turned the setting off")
end)

test("Slash.CliSet: accepts a lower-case dropdown token", function()
  -- Moved OFF the value under test first. This case used to set "low" against a row whose default
  -- is already LOW, so it passed whether or not the up-casing happened at all — a mutation that
  -- deleted the adapter outright left it green. `settings.defaultStrata` is the addon's one enum
  -- row, and LibKa0s-Slash-1.0's parser matches an enum CASE-SENSITIVELY, so this affordance now
  -- lives in a `parse` adapter on the descriptor and this is the only thing holding it.
  Sl:CliSet("settings.defaultStrata HIGH")
  assertEqual(NS.Schema:Get("settings.defaultStrata"), "HIGH", "the precondition did not take")
  Sl:CliSet("settings.defaultStrata low")
  assertEqual(NS.Schema:Get("settings.defaultStrata"), "LOW",
    "a lower-case enum token was refused — the parse adapter is gone")
  Sl:CliReset("settings.defaultStrata")
end)

test("Slash.CliSet: a non-number for a number row is refused", function()
  local before = NS.Schema:Get("settings.gridSize")
  local lines = capture(function() Sl:CliSet("settings.gridSize banana") end)
  assertTrue(lines[1]:find("Invalid value for settings.gridSize", 1, true) ~= nil)
  assertTrue(lines[2]:find("expected a number", 1, true) ~= nil)
  assertEqual(NS.Schema:Get("settings.gridSize"), before)
end)

test("Slash.CliSet: an out-of-range number CLAMPS to the row's max (LIBKA0S-17)", function()
  -- A USER-VISIBLE CHANGE, and a deliberate one. This addon used to refuse an out-of-range number
  -- and print "error: invalid value"; LibKa0s-Slash-1.0's parser clamps instead, on the reasoning
  -- that a user typing a width larger than the panel allows means "as wide as it goes". The echo
  -- re-READS the stored value, so what actually landed is what gets reported — which is the only
  -- reason a clamp is honest rather than silent.
  local lines = capture(function() Sl:CliSet("settings.gridSize 99999") end)
  local row = NS.Schema:FindRow("settings.gridSize")
  assertEqual(NS.Schema:Get("settings.gridSize"), row.max)
  assertTrue(lines[1]:find(tostring(row.max) .. " px", 1, true) ~= nil,
    "the echo does not report the clamped value: " .. lines[1])
  Sl:CliReset("settings.gridSize")
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

test("COMMANDS: every entry is a { name, description, handler } triple", function()
  -- POSITIONAL since the LibKa0s adoption: LibKa0s-Slash-1.0 reads entry[1]/[2]/[3], and the table
  -- is passed to it rather than owned by it. A keyed entry left behind would dispatch as an
  -- unknown verb and render a help row reading "nil".
  for i, cmd in ipairs(NS.COMMANDS) do
    assertTrue(type(cmd[1]) == "string" and cmd[1] ~= "", "entry " .. i .. " has no name")
    assertTrue(type(cmd[2]) == "string" and cmd[2] ~= "", "entry " .. i .. " has no description")
    assertTrue(type(cmd[3]) == "function", tostring(cmd[1]) .. " has no handler")
    assertEqual(cmd.name, nil, tostring(cmd[1]) .. " still carries a keyed `name`")
    assertEqual(cmd.desc, nil, tostring(cmd[1]) .. " still carries a keyed `desc`")
    assertEqual(cmd.fn, nil, tostring(cmd[1]) .. " still carries a keyed `fn`")
  end
end)

test("COMMANDS: names are unique and lower-case", function()
  local seen = {}
  for _, cmd in ipairs(NS.COMMANDS) do
    assertEqual(seen[cmd[1]], nil, "duplicate command " .. cmd[1])
    assertEqual(cmd[1], cmd[1]:lower(), cmd[1] .. " is not lower-case")
    seen[cmd[1]] = true
  end
end)

test("COMMANDS: the standard's required verbs are present (slash-commands-§3)", function()
  local have = {}
  for _, cmd in ipairs(NS.COMMANDS) do have[cmd[1]] = true end
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
  for _, cmd in ipairs(NS.COMMANDS) do desc[cmd[1]] = cmd[2] end
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

test("Slash.CliPanel: fitart is an action in the field slot, and reshapes the panel", function()
  fresh()
  local rec = R:New("Fitted")
  R:Set(rec.id, "width", 300)
  R:Set(rec.id, "height", 137)
  R:Set(rec.id, "artTexture", "class-warrior")       -- 1024x1024
  local lines = capture(function() Sl:CliPanel("Fitted fitart") end)
  local live = R:Get(rec.id)
  assertEqual(live.width, 1024, "fitart did not fit the panel to its artwork")
  assertEqual(live.height, 1024)
  -- Both axes echoed, read back off the record so the lines reflect the clamp.
  assertEqual(#lines, 2)
  assertTrue(lines[1]:find("1024", 1, true) ~= nil, "the echo did not report the new width")
  assertTrue(lines[2]:find("1024", 1, true) ~= nil, "the echo did not report the new height")
end)

test("Slash.CliPanel: fitart explains itself when there is nothing to fit to", function()
  fresh()
  local rec = R:New("Bare")
  R:Set(rec.id, "height", 90)
  local lines = capture(function() Sl:CliPanel("Bare fitart") end)
  -- A silent no-op is indistinguishable from a broken command, so the reason is printed.
  assertEqual(R:Get(rec.id).height, 90)
  assertTrue(lines[1]:find("no artwork", 1, true) ~= nil, "no reason was given: " .. tostring(lines[1]))
end)

test("Slash.CliPanel: artAutosize is no longer a field anyone can set", function()
  fresh()
  R:New("Legacy")
  -- The stored flag became a button. A leftover command from a macro must be refused with the real
  -- field list rather than quietly writing a key nothing reads.
  local lines = capture(function() Sl:CliPanel("Legacy artAutosize on") end)
  assertTrue(lines[1]:find("unknown field", 1, true) ~= nil,
    "artAutosize was still accepted: " .. tostring(lines[1]))
end)
