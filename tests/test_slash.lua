local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local Sl, R = NS.Slash, NS.Registry
-- The schema and the mocks, for the reserved enable/disable pair at the foot of this file:
-- those two verbs are ALIASES onto a schema path (slash-commands-§2), so asserting they hold
-- no state of their own means reading the row they write from both ends.
local S, mocks = NS.Schema, T.mocks

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
  -- AceConsole's own record of what was registered (kit revision 17, #50).
  local commands = T.mocks.LibStub("AceConsole-3.0").commands
  assertTrue(commands["pm"], "/pm was never registered")
  assertTrue(commands["panelmaster"], "/panelmaster alias missing")
end)

test("Slash.Version: prefers the TOC metadata over the in-code fallback", function()
  -- The title is the claim, so the assertion has to be able to break it. tests/wow_mock.lua's TOC
  -- answers a string core/Namespace.lua:7's constant is not, which is the only reason "prefers"
  -- means anything here: while both read "1.0.0" this line passed whether Sl:Version() went
  -- through the seam or read the constant directly.
  assertEqual(Sl:Version(), "1.2.3-toc")
  assertTrue(Sl:Version() ~= NS.version, "the in-code fallback won over a readable TOC")
end)

test("Slash.PrintHelp: one row per command, plus a header", function()
  local lines = capture(function() Sl:PrintHelp() end)
  assertEqual(#lines, #NS.COMMANDS + 1)
  assertTrue(lines[1]:find("v" .. NS.Version(), 1, true) ~= nil)
end)

test("Slash.PrintHelp: no line ends in a colon (slash-commands-§4)", function()
  for _, line in ipairs(capture(function() Sl:PrintHelp() end)) do
    assertFalse(line:match(":%s*$") ~= nil, "trailing colon: " .. line)
  end
end)

test("Slash: no `test` or `preview` verb — `/pm lock` and `/pm unlock` are the switch", function()
  -- options-ui-§15's exemption: the unlocked view is this addon's test mode, so it ships no test
  -- verb and the lock verbs drive it.
  local have = {}
  for _, cmd in ipairs(NS.COMMANDS) do have[cmd[1]] = true end
  assertFalse(have.test == true, "a `test` verb is back in NS.COMMANDS")
  assertFalse(have.preview == true, "a `preview` verb is back in NS.COMMANDS")
  assertTrue(have.lock == true and have.unlock == true, "`/pm lock` or `/pm unlock` is missing")
end)

test("Slash: `/pm lock` and `/pm unlock` write the checkbox's path through the ONE seam (§8)",
  function()
    -- slash-commands-§8 makes the PAIR a MAY and this addon takes it -- but once taken, both verbs
    -- MUST write the same stored path, through the same single write seam, as the *Lock frame*
    -- checkbox and the launcher's left click. They used to call NS.Unlock:SetUnlocked directly,
    -- which was the one surface in this addon that went round the seam: no validation, no single
    -- `[Set]` line, and a wording of its own for the acknowledgment.
    --
    -- Asserted from BOTH ends, because "one state" is what the rule is actually about: the verb's
    -- effect is read back off NS.State (what the world does) and off the row (what the checkbox
    -- shows), and those two can never disagree if there is only one value.
    NS.Slash:OnSlash("unlock")
    assertTrue(NS.State.unlocked, "/pm unlock did not unlock")
    assertEqual(S:Get("state.locked"), false, "the Lock frame row disagrees with /pm unlock")

    local lines = capture(function() NS.Slash:OnSlash("lock") end)
    assertFalse(NS.State.unlocked, "/pm lock did not lock")
    assertEqual(S:Get("state.locked"), true, "the Lock frame row disagrees with /pm lock")
    -- §8's confirmation SHOULD, in §5's `set` shape -- the same acknowledgment `enable` / `disable`
    -- print, because it is the same write by another name.
    assertEqual(#lines, 1, "/pm lock answered " .. #lines .. " lines")
    assertEqual(lines[1], NS.PREFIX .. " " .. Sl.FormatKV("state.locked", "true"),
      "/pm lock did not confirm in the shared `path = value` shape: " .. tostring(lines[1]))

    -- And no second state anywhere: the verbs hold nothing of their own.
    S:Set("state.locked", false)
    assertTrue(NS.State.unlocked, "the checkbox's own write did not reach the verbs' state")
    S:Set("state.locked", true)
  end)

-- Swap the `config` row's handler for a probe while `fn` runs, and return what reached it: the
-- argument of each call, in order. Restored afterwards, so a failing assertion leaves no probe behind.
local function probeConfig(fn)
  local row
  for _, cmd in ipairs(NS.COMMANDS) do if cmd[1] == "config" then row = cmd end end
  assertTrue(row ~= nil, "NS.COMMANDS has no `config` row for a bare /pm to reach")
  local real, got = row[3], {}
  row[3] = function(a) got[#got + 1] = a end
  local ok, err = pcall(fn)
  row[3] = real
  if not ok then error(err, 0) end
  return got
end

test("Slash.OnSlash: a bare command runs `config` (slash-commands-§4)", function()
  -- Bare `/pm` opens the settings page; it used to print the help index. The library hands the
  -- `config` row an empty string, and nil input (AceConsole with nothing typed) takes the same road.
  local lines
  local got = probeConfig(function()
    lines = capture(function() Sl:OnSlash("") end)
    Sl:OnSlash(nil)
  end)
  assertEqual(#got, 2, "a bare /pm did not reach `config`")
  assertEqual(got[1], "")
  assertEqual(got[2], "")
  assertEqual(#lines, 0, "a bare /pm still printed something alongside opening settings")
end)

test("Slash.OnSlash: a whitespace-only command is bare too", function()
  local got = probeConfig(function() Sl:OnSlash("   \t ") end)
  assertEqual(#got, 1, "whitespace-only input did not reach `config`")
  assertEqual(got[1], "")
end)

test("Slash.OnSlash: `help` prints the index", function()
  local lines
  local got = probeConfig(function()
    lines = capture(function() Sl:OnSlash("help") end)
  end)
  assertEqual(#got, 0, "`/pm help` opened settings")
  assertEqual(#lines, #NS.COMMANDS + 1)
  assertTrue(lines[1]:find("v" .. NS.Version(), 1, true) ~= nil, "the index lost its header")
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

test("Slash.CliSet: a dropdown token followed by more words is refused, and the token alone takes", function()
  -- LibKa0s-Slash-1.0 minor 10 matches an enum row against the WHOLE value rather than its first
  -- word, so the adapter's up-cased "LOW JUNK" matches nothing. Through minor 9 this stored LOW and
  -- dropped "junk" without a word. Moved off LOW first, so a silent partial write would show.
  Sl:CliSet("settings.defaultStrata HIGH")
  assertEqual(NS.Schema:Get("settings.defaultStrata"), "HIGH", "the precondition did not take")
  local lines = capture(function() Sl:CliSet("settings.defaultStrata low junk") end)
  assertTrue(lines[1] and lines[1]:find("Invalid value for settings.defaultStrata", 1, true) ~= nil,
    "the refusal does not name the setting: " .. tostring(lines[1]))
  assertTrue(lines[2] and lines[2]:find("allowed values:", 1, true) ~= nil,
    "the refusal does not list the allowed values: " .. tostring(lines[2]))
  assertEqual(NS.Schema:Get("settings.defaultStrata"), "HIGH", "a token with trailing words was stored")
  Sl:CliSet("settings.defaultStrata low")
  assertEqual(NS.Schema:Get("settings.defaultStrata"), "LOW", "the token on its own was refused")
  Sl:CliReset("settings.defaultStrata")
end)

test("Slash.CliSet: an enum row matches its own values in any case and stores their spelling", function()
  -- The adapter used to up-case EVERY enum row. That is right for strata, whose tokens are stored
  -- upper-case, and wrong for the composed General visibility, whose values are always / inCombat /
  -- outOfCombat / never: every `/pm set settings.visibility <value>` was refused. It now matches the
  -- typed value against the row's own values without regard to case and hands the library the
  -- spelling the row stores. Each value differs from the one before, so a refusal cannot pass.
  for _, v in ipairs({ "never", "outOfCombat", "inCombat", "always" }) do
    Sl:CliSet("settings.visibility " .. v)
    assertEqual(NS.Schema:Get("settings.visibility"), v, "a valid visibility value was refused: " .. v)
  end
  Sl:CliSet("settings.visibility INCOMBAT")
  assertEqual(NS.Schema:Get("settings.visibility"), "inCombat",
    "a value typed in another case did not store the row's own spelling")
  -- Strata keeps working the way it always has, and the whole value still has to match.
  Sl:CliSet("settings.defaultStrata HIGH")
  Sl:CliSet("settings.defaultStrata low")
  assertEqual(NS.Schema:Get("settings.defaultStrata"), "LOW", "a lower-case strata token did not store upper-case")
  local lines = capture(function() Sl:CliSet("settings.defaultStrata low junk") end)
  assertTrue(lines[2] and lines[2]:find("allowed values:", 1, true) ~= nil,
    "a token with trailing words was not refused: " .. tostring(lines[1]))
  assertEqual(NS.Schema:Get("settings.defaultStrata"), "LOW", "a token with trailing words was stored")
  Sl:CliReset("settings.visibility")
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

test("Slash.CliResetAll: CONFIRMS first, and never resets on the call itself", function()
  -- The reset deletes the player's panels now (options-ui-§12), so the standard puts a
  -- confirmation on the control and the act does not run on the click. This addon puts the typed
  -- verb behind the same door -- there is no reason for `/pm resetall` to be the one with no lock.
  -- red under: CliResetAll calling DoResetAll directly.
  fresh()
  R:New("Survivor")
  Sl:CliSet("settings.gridSize 16")

  Sl:CliResetAll()

  assertEqual(T.mocks.__popupsShown[#T.mocks.__popupsShown], "KA0S_PANELMASTER_RESETALL")
  assertEqual(NS.Schema:Get("settings.gridSize"), 16, "the reset ran before anyone confirmed it")
  assertEqual(R:Count(), 1, "the reset ran before anyone confirmed it")
  fresh()
end)

test("Slash: accepting the reset empties the PROFILE, panels included", function()
  -- It used to walk the schema and print "your panels are untouched". It is a profile reset now,
  -- `db.profile.panels` is in the profile, and what comes back is indistinguishable from a profile
  -- the player had just created -- which is what the standard asks a global reset to be.
  -- red under: DoResetAll going back to a row walk.
  fresh()
  R:New("Survivor")
  Sl:CliSet("settings.gridSize 16")

  T.mocks.StaticPopupDialogs["KA0S_PANELMASTER_RESETALL"].OnAccept()

  assertEqual(NS.Schema:Get("settings.gridSize"), 4)
  assertEqual(R:Count(), 0, "a profile reset keeps the panels the player added")
  fresh()
end)

test("Slash.CliVersion: prints v<version>", function()
  local lines = capture(function() Sl:CliVersion() end)
  assertTrue(lines[1]:find("v" .. NS.Version(), 1, true) ~= nil)
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
                              "reset", "resetall", "debug", "enable", "disable", "help" }) do
    assertTrue(have[required], "missing the required '" .. required .. "' verb")
  end
end)

test("COMMANDS: the descs name the sub-verbs their handlers accept (F-011)", function()
  -- `/pm debug dump` and `/pm panel deleteall` both work, and neither used to appear in the
  -- generated help index or on the settings landing page — both of which generate from these descs
  -- (slash-commands-§3 forbids a hand-maintained help string, so the desc is the only place the
  -- text can go).
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


-- ── the reserved verbs (slash-commands-§2) ─────────────────────────────────────

test("Verbs: /pm enable and /pm disable write the Enable row's own path", function()
  -- ALIASES, never a second switch. They write `settings.enabled` -- the path the Master controls
  -- *Enable Ka0s Panel Master* checkbox writes -- so the two surfaces cannot show the player two
  -- different answers.
  assertEqual(S.ENABLED_PATH, "settings.enabled")
  NS.Slash:OnSlash("disable")
  assertEqual(NS.db.profile.settings.enabled, false, "/pm disable did not write the stored path")
  assertEqual(S:Get(S.ENABLED_PATH), false, "the checkbox disagrees with the verb")

  NS.Slash:OnSlash("enable")
  assertEqual(NS.db.profile.settings.enabled, true, "/pm enable did not write the stored path")
  assertEqual(S:Get(S.ENABLED_PATH), true)
end)

test("Verbs: they hold no state of their own -- the checkbox drives them too", function()
  -- Approached from the other end: write the ROW, then read what the verbs read. A verb keeping a
  -- flag of its own agrees with the checkbox until one of the two is used twice.
  S:Set(S.ENABLED_PATH, false)
  assertEqual(S:Get(S.ENABLED_PATH), false)
  NS.Slash:OnSlash("enable")
  assertEqual(S:Get(S.ENABLED_PATH), true, "the verb toggled from a copy of its own")
  assertEqual(NS.enabled, nil, "an NS.enabled flag is back")
end)

test("Verbs: the acknowledgment is the shared path = value echo, read back from the store",
  function()
    -- slash-commands-§5: one shared formatter for list/get/set/reset, never a private variant. The
    -- echo reads the STORED value back after the write, which is why `/pm enable` is literally
    -- `/pm set settings.enabled true` rather than a second implementation beside it.
    local chat = mocks.__chat
    NS.Slash:OnSlash("disable")
    assertEqual(chat[#chat], NS.PREFIX .. " " .. NS.Slash.FormatKV(S.ENABLED_PATH, "false"),
      "the disable acknowledgment is not the collection's shared key = value line")
    NS.Slash:OnSlash("enable")
    assertEqual(chat[#chat], NS.PREFIX .. " " .. NS.Slash.FormatKV(S.ENABLED_PATH, "true"))
  end)

test("Verbs: the dispatcher survives the disabled state, so the pair is never one-way", function()
  -- The failure this prevents is a switch that only goes one way: the player turns the addon off,
  -- the verb that turns it back on no longer exists, and the only route left is the settings panel
  -- they were trying not to open. Disabled means the addon stands its FEATURES down. The chat
  -- command, the COMMANDS table and the settings registration are SETUP and stay up.
  S:Set(S.ENABLED_PATH, false)

  local commands = mocks.LibStub("AceConsole-3.0").commands
  assertTrue(commands["pm"] ~= nil, "the disabled addon unregistered its own slash command")
  assertTrue(commands["panelmaster"] ~= nil, "the disabled addon unregistered its alias")

  -- enable above all.
  NS.Slash:OnSlash("enable")
  assertEqual(S:Get(S.ENABLED_PATH), true, "/pm enable is unreachable once the addon is disabled")

  -- and with it help, config and version.
  S:Set(S.ENABLED_PATH, false)
  local chat = mocks.__chat
  local before = #chat
  NS.Slash:OnSlash("help")
  assertTrue(#chat > before, "/pm help answered nothing while disabled")
  NS.Slash:OnSlash("version")
  assertTrue(chat[#chat]:find("v", 1, true) ~= nil, "/pm version answered nothing while disabled")
  mocks.__openedCategory = nil
  mocks.__inCombat = false
  NS.Slash:OnSlash("config")
  assertEqual(mocks.__openedCategory, 1, "/pm config did not open the panel while disabled")
  -- A bare /pm reaches the config row (slash-commands-§4), and it must reach it while disabled too.
  mocks.__openedCategory = nil
  NS.Slash:OnSlash("")
  assertEqual(mocks.__openedCategory, 1, "a bare /pm answered nothing while disabled")

  S:Set(S.ENABLED_PATH, true)
end)

-- ── a disabled addon refuses its FEATURE verbs (slash-commands-§2) ─────────────
--
-- The trailing SHOULD that nobody implemented until standard v2.54.0 made it precise. The failure
-- these cases prevent is the one a message-only assertion walks straight past: a verb that prints
-- the refusal AND THEN ACTS ANYWAY. So every case below reads the world afterwards, not the chat.

--- Run `fn` with the addon disabled, and put the switch back however it ends.
local function whileDisabled(fn)
  S:Set(S.ENABLED_PATH, false)
  local ok, err = pcall(fn)
  S:Set(S.ENABLED_PATH, true)
  if not ok then error(err, 0) end
end

test("Disabled: every feature verb refuses on ONE line naming /pm enable", function()
  -- DERIVED FROM THE TABLE, not from a list written out here, which is the whole point of gating
  -- the verb table in one place: a verb added to NS.COMMANDS tomorrow is covered by this case the
  -- day it lands, and a verb that quietly opted itself out is what turns it red.
  fresh()
  R:New("Probe")

  whileDisabled(function()
    for _, cmd in ipairs(NS.COMMANDS) do
      if not Sl.ALWAYS_LIVE[cmd[1]] then
        local lines = capture(function() NS.Slash:OnSlash(cmd[1] .. " Probe") end)
        assertEqual(#lines, 1, "/pm " .. cmd[1] .. " answered " .. #lines .. " lines while "
          .. "disabled -- the refusal is one line and nothing else")
        assertTrue(lines[1]:find("/pm enable", 1, true) ~= nil,
          "/pm " .. cmd[1] .. " did not name the verb that turns the addon back on: " .. lines[1])
      end
    end
  end)
  fresh()
end)

test("Disabled: a feature verb does not ACT -- the refusal is instead of the work, not before it",
  function()
    -- The half a chat assertion cannot see. Each verb below has a crisp observable effect, read
    -- back from the registry and from the unlock state rather than from what was printed.
    -- red under: a per-verb guard that prints and falls through.
    fresh()
    local rec = R:New("Probe")
    local width = R:Get(rec.id).width
    NS.Unlock:SetUnlocked(false)

    whileDisabled(function()
      NS.Slash:OnSlash("new Second")
      assertEqual(R:Count(), 1, "/pm new created a panel while the addon was disabled")

      NS.Slash:OnSlash("panel Probe width 500")
      assertEqual(R:Get(rec.id).width, width, "/pm panel edited a panel while disabled")

      NS.Slash:OnSlash("rename Probe Renamed")
      assertEqual(R:Get(rec.id).name, "Probe", "/pm rename renamed a panel while disabled")

      NS.Slash:OnSlash("unlock")
      assertFalse(NS.State.unlocked, "/pm unlock unlocked the panels while the addon was disabled")

      NS.Slash:OnSlash("delete Probe")
      assertEqual(R:Count(), 1, "/pm delete deleted a panel while the addon was disabled")
    end)

    -- And the same verbs work the moment it is back on, so the gate is a gate and not a removal.
    NS.Slash:OnSlash("delete Probe")
    assertEqual(R:Count(), 0, "/pm delete stayed refused after the addon was re-enabled")
    fresh()
  end)

test("Disabled: the live verbs are never refused (slash-commands-§2)", function()
  -- The other side of the same rule, and the reason it is spelled out: "refuse while disabled",
  -- read literally, takes the entire command surface down with it. A player must be able to read
  -- and repair settings and reach the panel while the addon is off -- and `enable` above all.
  --
  -- "NOT REFUSED" IS TESTED AS "DID NOT ANSWER WITH THE REFUSAL AND NOTHING ELSE", not as "printed
  -- no line mentioning the state". The two differ on `help`, which the library heads with the
  -- disabled line before printing the whole index -- a state NOTE above an answer, not a refusal
  -- instead of one. A blanket string ban would redden that and would be the narrowing standard
  -- v2.57.0 reversed, arriving through the back door of an assertion.
  fresh()
  whileDisabled(function()
    for _, cmd in ipairs(NS.COMMANDS) do
      if Sl.ALWAYS_LIVE[cmd[1]] then
        local lines = capture(function() NS.Slash:OnSlash(cmd[1]) end)
        assertFalse(#lines == 1 and lines[1] == NS.PREFIX .. " " .. Sl:DisabledLine(),
          "/pm " .. cmd[1] .. " answered the refusal and nothing else, and it is on the live list")
      end
    end

    -- Read AND repair, not merely answer: the schema CLI has to still write.
    NS.Slash:OnSlash("set settings.gridSize 16")
    assertEqual(S:Get("settings.gridSize"), 16, "/pm set could not repair a setting while disabled")
    NS.Slash:OnSlash("reset settings.gridSize")
    assertEqual(S:Get("settings.gridSize"), 4, "/pm reset could not repair a setting while disabled")
  end)
  fresh()
end)

test("Disabled: the gate is the VERB TABLE's, so the live set is the standard's own", function()
  -- ALWAYS_LIVE is data, named once, and this is what stops it drifting into an ad-hoc list. Every
  -- name the standard puts on the live list is here whether or not this addon registers the verb --
  -- `perf` does not exist in NS.COMMANDS today, and a `perf` arriving later must not have to
  -- remember to come back and add itself.
  for _, verb in ipairs({ "help", "config", "version", "enable", "disable", "debug", "perf",
                          "get", "set", "list", "reset", "resetall" }) do
    assertTrue(Sl.ALWAYS_LIVE[verb], "'" .. verb .. "' is a feature verb here, and the standard "
      .. "says it may never be refused")
  end
  -- And nothing else has been quietly added to it: the live set is a carve-out, not a preference.
  local extra = 0
  for verb in pairs(Sl.ALWAYS_LIVE) do
    local named = false
    for _, ok in ipairs({ "help", "config", "version", "enable", "disable", "debug", "perf",
                          "get", "set", "list", "reset", "resetall" }) do
      if verb == ok then named = true end
    end
    if not named then extra = extra + 1 end
  end
  assertEqual(extra, 0, "a verb has been exempted from the disabled gate that the standard does not "
    .. "exempt")
end)

test("Disabled: the refusal is the COLLECTION'S line, built by the library (slash-commands-§7)",
  function()
    -- One shape, collection-wide: `<BrandName> is disabled — enable it with /<slash> enable`, the
    -- brand name in plain text, an em dash with a single space either side, the command in the help
    -- index's gold and carrying its leading slash, no trailing colon and no trailing period.
    --
    -- It used to be this addon's own wording, routed through NS.L. That was right under the rule as
    -- it stood and is wrong now: the wording is not the addon's to spell, which is why
    -- LibKa0s-Slash-1.0's own contract says the host's locale override does not reach this line.
    -- So the assertion is against the LIBRARY's format string rather than against a copy here --
    -- a copy would pass while the library moved underneath it.
    local lib = T.mocks.LibStub("LibKa0s-Slash-1.0", true)
    assertEqual(Sl:DisabledLine(), lib.DISABLED_LINE_FORMAT:format(NS.BRAND, "/pm enable"),
      "the refusal line is not the library's, built from this addon's brand name")
    -- The brand name is the ONE spelling launcher-§1 already pins as the LDB label, not a second
    -- one invented for this message.
    assertEqual(NS.BRAND, T.mocks.__brokerObjects["PanelMaster"].label,
      "the refusal names a different brand from the one the broker row prints")

    fresh()
    whileDisabled(function()
      local lines = capture(function() NS.Slash:OnSlash("panels") end)
      assertEqual(#lines, 1, "the refusal is one line and nothing else")
      assertEqual(lines[1], NS.PREFIX .. " " .. Sl:DisabledLine(),
        "the refusal is not the line the dispatcher builds: " .. tostring(lines[1]))
    end)
    fresh()
  end)
