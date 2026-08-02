local T = _G.PM_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- The LibKa0s adoption's own suite: the seams, the degradation, and the `L` trap.
--
-- Everything here answers one of three questions that no other suite in this repo can:
--   * is the addon actually running the LIBRARY, or has a seam silently fallen back? Every
--     degradation stub is written to keep working, which is exactly what makes a failed adoption
--     invisible — the addon behaves, the suite passes, and the library is dead weight in libs/.
--   * does the DEGRADED install still work, said once, in the collection's shared wording?
--   * can a descriptor render raw SCREAMING_SNAKE keys in place of English?

local Loader = dofile("tests/_kit/loader.lua")
local buildMocks = dofile("tests/wow_mock.lua")

local LIB_FILES = {
  "libs/LibKa0s/Core.lua",
  "libs/LibKa0s/DebugLog.lua",
  "libs/LibKa0s/Slash.lua",
  "libs/LibKa0s/Options.lua",
  "libs/LibKa0s/OptionsWidgets.lua",
  "libs/LibKa0s/OptionsScroll.lua",
}

local function readFile(path)
  local f = assert(io.open(path, "r"), "missing file " .. path)
  local src = f:read("*a")
  f:close()
  return src
end

--- Load the WHOLE addon into a fresh environment with libs/LibKa0s deliberately absent.
---
--- The library files are simply never loaded, so `LibStub("LibKa0s-Core-1.0", true)` answers nil
--- exactly as it does in an install where the folder was not copied. That is the point: hand-
--- stubbing `lib = nil` inside a seam would test a branch, not an install, and would not catch a
--- seam that raises at load before it ever reaches its own guard.
local function loadDegraded()
  local m = buildMocks()
  local ns = {}
  Loader.addonName = "PanelMaster"
  Loader.loadAll(Loader.tocFiles("PanelMaster.toc"), ns, m)
  ns.addon:OnInitialize()
  ns.addon:OnEnable()
  return ns, m
end

-- ── the library is actually loaded ─────────────────────────────────────────────

test("LibKa0s: the vendored library registered for real", function()
  for _, path in ipairs(LIB_FILES) do
    assertTrue(io.open(path, "r") ~= nil, "vendored library file missing: " .. path)
  end
  local core = mocks.LibStub("LibKa0s-Core-1.0", true)
  assertTrue(core ~= nil, "LibKa0s-Core-1.0 did not register")
  assertEqual(core.MAJOR, "LibKa0s-Core-1.0")
  assertTrue(type(core.MINOR) == "number" and core.MINOR >= 1, "Core has no usable MINOR")
  -- The minor the addon is actually running, published for in-game version-skew diagnosis.
  assertEqual(core.MODULES.Core, core.MINOR)
end)

test("LibKa0s: NS.Core is the live Core library, not a stub", function()
  assertEqual(NS.Core, mocks.LibStub("LibKa0s-Core-1.0", true))
end)

-- ── Core: the printer seam ─────────────────────────────────────────────────────
--
-- The load-bearing assertion is IDENTITY, not behavior. The degradation stub reproduces the
-- printer's behavior deliberately (six files take it as a load-time upvalue and must keep working),
-- so a behavioral assertion passes on BOTH paths and proves nothing about which one ran.

test("Core seam: NS.Print is the library's printer, not the fallback", function()
  local core = mocks.LibStub("LibKa0s-Core-1.0", true)
  assertEqual(NS.SafeToString, core.SafeToString, "NS.SafeToString must be Core's own function")
  assertEqual(NS.IsConcatSafe, core.IsConcatSafe, "NS.IsConcatSafe must be Core's own function")
  -- The fallback printer in core/CoreSetup.lua is a DIFFERENT function object from anything the
  -- library hands out, and the degraded environment below proves the two are distinguishable.
  local degraded = loadDegraded()
  assertTrue(degraded.Print ~= NS.Print,
    "the degraded printer and the library printer are the same object — the seam is not switching")
  assertTrue(degraded.SafeToString ~= core.SafeToString,
    "the degraded SafeToString is Core's — the degraded path is not actually degraded")
end)

test("Core seam: NS.Print survived the AceConsole embed and both keys are one object", function()
  -- core/PanelMaster.lua reclaims NS.Print FROM NS.Util.print after NewAddon embeds AceConsole's
  -- own :Print over it. Publishing on both keys is what keeps that reclaim correct.
  assertEqual(NS.Print, NS.Util.print)
  assertEqual(NS.Print, mocks.LibStub("LibKa0s-Core-1.0", true) and NS.Print)
  local before = #mocks.__chat
  NS.Print("hello")
  assertEqual(#mocks.__chat, before + 1)
  assertEqual(mocks.__chat[#mocks.__chat], NS.PREFIX .. " hello",
    "the library printer must render the cyan tag, one space, then the body")
end)

test("Core seam: the rendered line is byte-identical to the printer this replaced", function()
  -- The old core/Util.lua printer built { NS.PREFIX, arg1, arg2 } and concatenated with " ".
  -- Core's builds the body then emits `tag .. sep .. body` with sep defaulting to " ". Those are
  -- the same bytes for every arity, and this pins that rather than trusting it.
  local before = #mocks.__chat
  NS.Print("a", "b", "c")
  assertEqual(mocks.__chat[#mocks.__chat], NS.PREFIX .. " a b c")
  NS.Print(42, true, nil)
  assertEqual(mocks.__chat[#mocks.__chat], NS.PREFIX .. " 42 true nil",
    "nil and booleans must render, never be masked as the secret sentinel")
  assertEqual(#mocks.__chat, before + 2)
end)

test("Core seam: the secret guard survived the swap", function()
  assertTrue(NS.IsConcatSafe("plain"))
  assertTrue(NS.IsConcatSafe(7))
  assertEqual(NS.SafeToString(nil), "nil")
  assertEqual(NS.SafeToString(true), "true")
  assertEqual(NS.SafeToString(42), "42")
  -- The sentinel is the library's exported constant, so this addon's docs, its tests and the
  -- implementation cannot drift apart.
  assertEqual(mocks.LibStub("LibKa0s-Core-1.0", true).SECRET, "<secret>")
end)

-- ── DebugLog: the console seam ─────────────────────────────────────────────────

test("DebugLog seam: the console is the library's instance, not a host re-implementation", function()
  local dl = mocks.LibStub("LibKa0s-DebugLog-1.0", true)
  assertTrue(dl ~= nil, "LibKa0s-DebugLog-1.0 did not register")
  assertEqual(dl.MODULES.DebugLog, dl.MINOR)
  -- Members the OLD modules/DebugLog.lua never had. Their presence is what distinguishes the
  -- library instance from the 429-line file it replaced and from the degradation stub.
  for _, member in ipairs({ "Text", "CopyText", "FindLine", "BufferSize", "ConsoleCheckbox" }) do
    assertTrue(type(NS.DebugLog[member]) == "function",
      "NS.DebugLog has no " .. member .. " — this is not the library instance")
  end
  -- The formatters are the lib-level ones, shared rather than copied.
  assertEqual(NS.DebugLog.FormatPlain, dl.FormatPlain)
  assertEqual(NS.DebugLog.FormatColored, dl.FormatColored)
  assertEqual(NS.DebugLog.buffer, NS.DebugLog.buffer, "the buffer must be the instance's own table")
end)

test("DebugLog seam: the survivors kept their names and their shapes", function()
  -- NS.Debug is bound BARE off the instance: it is a plain function, not a method, because 35 call
  -- sites do `NS.Debug("Tag", "fmt", v)` with no self.
  assertEqual(NS.Debug, mocks.LibStub("LibKa0s-DebugLog-1.0", true) and NS.Debug)
  assertTrue(type(NS.Debug) == "function")
  assertTrue(type(NS.DebugBuild) == "function", "NS.DebugBuild has no library equivalent and must " ..
    "survive the swap")
  assertTrue(type(NS.DebugLog.Diagnose) == "function", "D:Diagnose has no library equivalent")
end)

test("DebugLog seam: the frame globals are byte-for-byte the ones this addon shipped", function()
  -- Derived by the library from the descriptor's `name`. If they ever stop matching, anything a
  -- user anchored to them — /framestack, a macro, UISpecialFrames — silently breaks.
  NS.DebugLog:Show()
  local frame = NS.DebugLog._frameForTest
  assertTrue(frame ~= nil, "the console frame was never built")
  assertEqual(frame:GetName(), "PanelMasterDebugWindow")
  NS.DebugLog:Hide()
end)

test("DebugLog seam: the console wears the LIBRARY's close button, not this addon's", function()
  -- `makeCloseButton` is deliberately not passed (the Ka0s window edge and its close control are
  -- the library's — standalone-windows). The title-bar offsets are DERIVED from the button's width,
  -- so they are the one readable evidence that Core's 18-wide x is what got built: an anchor cannot
  -- be read back through the frame API.
  NS.DebugLog:Show()
  local offsets = NS.DebugLog._frameForTest.titleBarOffsets
  assertTrue(offsets ~= nil, "the library records no title-bar offsets")
  assertEqual(offsets.close, -6)
  assertEqual(offsets.clear, -30, "Clear is not at Core's 18-wide close-button offset")
  assertEqual(offsets.copy, -78, "Copy is not at Core's 18-wide close-button offset")
  NS.DebugLog:Hide()
end)

test("L trap (DebugLog): every rendered console string resolves to prose, not to its own key",
  function()
    -- DebugLog is one of the three majors that CAN express the trap, so this is a real rendered
    -- assertion rather than a tripwire. A resolved string is prose; an unresolved one is the key,
    -- and no English label is SCREAMING_SNAKE_CASE.
    local SCREAMING = "^[A-Z][A-Z0-9_]+$"

    -- Reached through real accessors, and each is coupled to a non-vacuous expectation so the case
    -- cannot pass by the accessor simply not existing.
    NS.DebugLog:Show()
    local title = NS.DebugLog._frameForTest.titleText
    assertTrue(type(title) == "string" and title ~= "", "the console has no composed title")
    assertFalse(title:match(SCREAMING) ~= nil, "the console title rendered a raw key: " .. title)
    assertEqual(title, "Panel Master \226\128\148 Debug",
      "the composed title must be this addon's title plus the library's own suffix")
    NS.DebugLog:Hide()

    local cb = NS.DebugLog:ConsoleCheckbox()
    assertTrue(type(cb.label) == "string" and cb.label ~= "", "the checkbox has no label")
    assertFalse(cb.label:match(SCREAMING) ~= nil, "the checkbox label rendered a raw key: " .. cb.label)
    assertTrue(type(cb.tooltip) == "string" and cb.tooltip ~= "", "the checkbox has no tooltip")
    assertFalse(cb.tooltip:match(SCREAMING) ~= nil, "the checkbox tooltip rendered a raw key")
    -- The tooltip is composed from the descriptor's `slash`, so a resolved one names the command.
    assertTrue(cb.tooltip:find("/pm debug", 1, true) ~= nil,
      "the checkbox tooltip did not resolve the slash reference")

    for _, key in ipairs({ "DEBUG_ON", "DEBUG_OFF", "CLEAR", "COPY", "COPY_TITLE", "LINES",
                           "CHECKBOX_LABEL", "TITLE_SUFFIX", "LOG_ENABLED", "LOG_DISABLED" }) do
      local rendered = NS.DebugLog:Text(key)
      assertTrue(type(rendered) == "string" and rendered ~= "", key .. " resolved to nothing")
      assertFalse(rendered:match(SCREAMING) ~= nil,
        key .. " rendered as its own key: " .. rendered)
    end
  end)

-- ── Slash: the dispatcher, the help renderer and the schema CLI ────────────────

local function capture(fn)
  local before = #mocks.__chat
  fn()
  local out = {}
  for i = before + 1, #mocks.__chat do out[#out + 1] = mocks.__chat[i] end
  return out
end

test("Slash seam: the dispatcher is the library's, not a host re-implementation", function()
  local sl = mocks.LibStub("LibKa0s-Slash-1.0", true)
  assertTrue(sl ~= nil, "LibKa0s-Slash-1.0 did not register")
  assertEqual(sl.MODULES.Slash, sl.MINOR)
  -- Surfaces the old settings/Slash.lua never had. LandingRows in particular is the convergence:
  -- this addon carried two divergent formatters for NS.COMMANDS and now has one.
  for _, member in ipairs({ "LandingRows", "HelpRows", "Text" }) do
    assertTrue(type(NS.Slash[member]) == "function",
      "NS.Slash has no " .. member .. " — this is not the library dispatcher")
  end
  -- And the ones it DID have are gone rather than shadowing the library's.
  assertEqual(NS.Slash.FormatSchemaValue, nil,
    "the host's own value formatter survived — two formatters will drift")
  assertEqual(NS.Slash.LIST_GROUP_ORDER, nil,
    "the hand-maintained group-order constant survived; the library groups in declaration order")
  assertEqual(NS.Slash.FormatKV, sl.FormatKV, "FormatKV must be the library's one implementation")
end)

test("Convergence #2: the landing page and the chat help render the SAME rows", function()
  -- ADOPTED. settings/Panel.lua's landing page used to carry its own formatter for NS.COMMANDS —
  -- double spaces around the em dash, the dash white-wrapped, the description bare — beside the
  -- chat one in settings/Slash.lua. Both now come from lib.FormatRow.
  local landing = NS.Slash:LandingRows()
  local help    = NS.Slash:HelpRows()
  assertEqual(#landing, #NS.COMMANDS, "the landing page dropped or gained a row")
  assertEqual(#help, #NS.COMMANDS)
  for i = 1, #landing do
    -- Same bytes, except the chat form's two-space indent: a chat row sits under a header, a
    -- settings-panel label does not.
    assertEqual(help[i], "  " .. landing[i], "row " .. i .. " differs beyond the indent")
  end
  -- The rendered shape, pinned to bytes, because this is the user-visible half of the convergence.
  assertEqual(landing[1], "|cFFFFFF00/pm config|r \226\128\148 |cFFFFFFFFOpen settings|r",
    "the command row is no longer lib.FormatRow's shape: " .. landing[1])
  assertTrue(landing[1]:find("  ", 1, true) == nil,
    "the landing row still carries the old double spacing")
end)

test("Convergence #2: settings/Panel.lua no longer carries a second row formatter", function()
  -- A grep would answer about the NAME; this reads the render path. The landing page must reach
  -- NS.COMMANDS only through the library, so the file must not format a command row itself.
  local src = readFile("settings/Panel.lua")
  assertTrue(src:find("NS.Slash:LandingRows()", 1, true) ~= nil,
    "the landing page does not render through Sl:LandingRows()")
  assertEqual(src:find("/pm %%s|r"), nil,
    "settings/Panel.lua still formats a command row of its own")
end)

test("Convergence #1: /pm reset takes a PATH and /pm resetall is the global form", function()
  -- ADOPTED, and it was already converged before the adoption — which is not the same as "not
  -- applicable". Both verbs now delegate to the library.
  local verbs = {}
  for _, cmd in ipairs(NS.COMMANDS) do verbs[cmd[1]] = cmd[2] end
  assertTrue(verbs.reset ~= nil and verbs.resetall ~= nil, "a reset verb went missing")
  NS.Slash:CliSet("settings.gridSize 16")
  NS.Slash:CliReset("settings.gridSize")
  assertEqual(NS.Schema:Get("settings.gridSize"), 4, "path-scoped reset did not restore the default")
  -- There is deliberately no page-shaped form: a page is a property of a settings panel, not of the
  -- data, and the panel's own Defaults button is where page-scoped reset lives.
  local lines = capture(function() NS.Slash:CliReset("Editing") end)
  assertTrue(lines[1]:find("Setting not found", 1, true) ~= nil,
    "`/pm reset <page>` resolved something — the page-shaped form is supposed to be gone")
end)

test("L trap (Slash): the ONE overridden string lands, and nothing renders as its own key",
  function()
    local SCREAMING = "^[A-Z][A-Z0-9_]+$"
    -- This addon passes a PLAIN table holding exactly one key. The override must actually win —
    -- a descriptor L that silently did nothing is the other half of the trap.
    local lines = capture(function() NS.Slash:CliResetAll() end)
    assertEqual(lines[#lines], NS.PREFIX .. " all settings reset to defaults (your panels are " ..
      "untouched)", "the RESET_ALL override did not reach the rendered line")
    assertEqual(NS.Slash:Text("RESET_ALL"),
      "all settings reset to defaults (your panels are untouched)")
    -- And the library's own strings still resolve for every key this addon does NOT override.
    for _, key in ipairs({ "HELP_HEADER", "LIST_HEADER", "LIST_EMPTY", "NOT_FOUND", "INVALID",
                           "ERR_BOOL", "ERR_NUMBER", "ERR_COLOR", "NONE", "USAGE_GET" }) do
      local rendered = NS.Slash:Text(key)
      assertTrue(type(rendered) == "string" and rendered ~= "", key .. " resolved to nothing")
      assertFalse(rendered:match(SCREAMING) ~= nil, key .. " rendered as its own key: " .. rendered)
    end
    -- Reached through the real render path too, not only through Text().
    for _, line in ipairs(NS.Slash:BuildListLines()) do
      assertFalse(line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match(SCREAMING) ~= nil,
        "a /pm list line rendered as a raw key: " .. line)
    end
  end)

-- ── degradation ────────────────────────────────────────────────────────────────

test("Degraded install: the addon loads with no LibKa0s at all", function()
  local ns = loadDegraded()
  assertTrue(ns.Print ~= nil, "the fallback printer is missing")
  assertTrue(ns.Util.print ~= nil, "NS.Util.print is missing, so the AceConsole reclaim would break")
  assertEqual(ns.Print, ns.Util.print)
  assertTrue(ns.SafeToString ~= nil and ns.IsConcatSafe ~= nil,
    "the degraded stub must answer every member the addon calls, not just the printer")
end)

test("Degraded install: the shared cause clause is set on BOTH paths", function()
  -- Set OUTSIDE the `if not lib` branch, because the later seams append their own consequence to
  -- it whether or not the library is present. The wording is the whole Ka0s collection's and is
  -- not this addon's to reword.
  local EXPECTED = "The LibKa0s library is missing from this installation of Ka0s Panel Master " ..
    "(expected in libs/LibKa0s)"
  assertEqual(NS.LIBKA0S_MISSING, EXPECTED, "the cause clause must be set on the present-library " ..
    "path too — the later seams read it either way")
  local ns = loadDegraded()
  assertEqual(ns.LIBKA0S_MISSING, EXPECTED)
end)

test("Degraded install: the notice is announced exactly ONCE, before the first line", function()
  local ns, m = loadDegraded()
  local before = #m.__chat
  ns.Print("first")
  ns.Print("second")
  ns.Print("third")
  local lines = {}
  for i = before + 1, #m.__chat do lines[#lines + 1] = m.__chat[i] end
  local notices = 0
  for _, line in ipairs(lines) do
    if line:find("running on reduced built-in fallbacks.", 1, true) then notices = notices + 1 end
  end
  assertEqual(notices, 1, "the degraded notice must be said once per session, not per line")
  assertEqual(lines[1], ns.PREFIX .. " " .. ns.LIBKA0S_MISSING ..
    "; running on reduced built-in fallbacks.",
    "the notice must lead with the shared cause clause and this seam's own consequence")
  -- And it must not have eaten the line the user actually asked for.
  assertEqual(lines[2], ns.PREFIX .. " first")
  assertEqual(lines[#lines], ns.PREFIX .. " third")
end)

test("Degraded install: the console explains itself once and every member still answers", function()
  local ns, m = loadDegraded()
  local D = ns.DebugLog
  assertTrue(D ~= nil, "NS.DebugLog is nil in a degraded install — settings/Schema.lua's console " ..
    "row calls IsShown on every panel refresh")
  -- Every member the addon actually calls, per `grep -n "NS.DebugLog" -r`.
  for _, member in ipairs({ "IsShown", "Show", "Hide", "Toggle", "SetEnabled", "Add", "Diagnose" }) do
    assertTrue(type(D[member]) == "function", "the degraded console cannot answer " .. member)
  end
  assertFalse(D:IsShown())
  assertTrue(type(ns.Debug) == "function" and type(ns.DebugBuild) == "function")

  ns.Print("warm up the Core notice")
  local before = #m.__chat
  D:Show(); D:Toggle(); D:ShowCopy()
  local notices = 0
  for i = before + 1, #m.__chat do
    if m.__chat[i]:find("so the debug console window is unavailable.", 1, true) then
      notices = notices + 1
    end
  end
  assertEqual(notices, 1, "the console's absence must be explained once, not on every call")
  -- The consequence is appended to the SHARED cause clause, so a degraded install says the same
  -- thing about why at every site and a different thing about what at each one.
  local found = false
  for i = before + 1, #m.__chat do
    if m.__chat[i]:find(ns.LIBKA0S_MISSING, 1, true) then found = true end
  end
  assertTrue(found, "the console's notice does not carry the shared cause clause")
end)

test("Degraded install: /pm debug on|off still flips the flag and acknowledges", function()
  -- Logging is a session flag the ADDON owns; only the window went away. A stub that swallowed
  -- SetEnabled would make the degraded install look like the flag was stuck off.
  local ns = loadDegraded()
  ns.DebugLog:SetEnabled(true)
  assertTrue(ns.State.debug, "the degraded console did not set the logging flag")
  ns.DebugLog:SetEnabled(false)
  assertFalse(ns.State.debug)
end)

test("Degraded install: /pm debug dump still answers", function()
  -- Diagnose reads the addon's own state and has nothing to do with whether a window exists, so it
  -- is attached on both paths from one definition.
  local ns = loadDegraded()
  local lines = ns.DebugLog:Diagnose()
  assertTrue(type(lines) == "table" and #lines > 0, "Diagnose returned nothing in a degraded install")
end)

test("Degraded install: the fallback printer renders the same bytes as the library's", function()
  local ns, m = loadDegraded()
  ns.Print("warm up the notice")
  local before = #m.__chat
  ns.Print("a", "b")
  assertEqual(m.__chat[#m.__chat], ns.PREFIX .. " a b")
  assertEqual(#m.__chat, before + 1)
  assertEqual(ns.SafeToString(nil), "nil")
  assertEqual(ns.SafeToString(true), "true")
end)

-- ── the `L` trap ───────────────────────────────────────────────────────────────
--
-- Three of the five majors take a descriptor `L` and can render raw keys if handed a table whose
-- __index synthesises one. Core CANNOT express the trap at all — it ships no STRINGS and reads no
-- descriptor L — so a "rendered label is prose" case there would be a case that cannot fail, which
-- is worse than no case because it reads as coverage. The stand-in is a TRIPWIRE on the library
-- itself: it passes today and goes red the day Core grows a user-visible string, which is the day
-- this repo needs a real rendered assertion instead.

test("L trap (Core tripwire): Core cannot express the trap", function()
  local core = mocks.LibStub("LibKa0s-Core-1.0", true)
  assertTrue(rawget(core, "STRINGS") == nil,
    "Core has grown a STRINGS table — replace this tripwire with a real rendered-string assertion")
  local src = readFile("libs/LibKa0s/Core.lua")
  assertTrue(src:find("STRINGS", 1, true) == nil,
    "Core.lua names STRINGS — it can now render a user-visible string and needs a real assertion")
  assertTrue(src:find("d.L", 1, true) == nil and src:find("d%.L") == nil,
    "Core.lua reads a descriptor L — the trap is now expressible there")
end)

-- The host-side guard. A descriptor field is not observable after `lib:New` returns, so the only
-- way to see one is to read the source that wrote it.
--
-- The matcher deliberately decides on what the expression EVALUATES TO rather than on one spelling:
--
--   L = NS.L                     the table itself                       OFFENDER
--   L = NS.L or { ... }          NS.L is always truthy, so: the table   OFFENDER
--   L = NS.L and { ... } or nil  evaluates to the plain table           fine
--
-- An end-of-line-anchored `L = NS.L` misses the `or` spelling completely, and never looks at the
-- third line at all — which is the legitimate form, one `and`→`or` typo away from being the trap.
local function findsLocaleTableDescriptor(src)
  for line in src:gmatch("[^\r\n]+") do
    -- Skip comments outright: this file's own explanatory prose above would otherwise match.
    if not line:match("^%s*%-%-") then
      local tail = line:match("[,{%s]L%s*=%s*(.*)$") or line:match("^L%s*=%s*(.*)$")
      if tail then
        local rest = tail:match("^NS%.L%s*(.*)$")
        -- Only `and` rescues it. Bare, or `or`-defaulted, both evaluate to the locale table.
        if rest and not rest:match("^and%f[%W]") then return true end
      end
    end
  end
  return false
end

test("L trap (matcher): the guard catches every offending spelling, not one", function()
  -- Its own case, driven against all three spellings. A matcher nothing tests can be narrowed back
  -- to a single anchored form while still reporting green — which is exactly how it got there.
  assertTrue(findsLocaleTableDescriptor("  L = NS.L,"), "bare assignment not caught")
  assertTrue(findsLocaleTableDescriptor("  L = NS.L\n"), "bare assignment at end of line not caught")
  assertTrue(findsLocaleTableDescriptor('  L = NS.L or { A = "a" },'), "the `or` spelling not caught")
  assertTrue(findsLocaleTableDescriptor('descriptor = { L = NS.L }'), "an inline table not caught")
  assertFalse(findsLocaleTableDescriptor('  L = NS.L and { A = "a" } or nil,'),
    "the legitimate `and`/`or` form must pass")
  assertFalse(findsLocaleTableDescriptor('  L = { A = NS.L["a"] },'),
    "a plain table whose VALUES come from the locale table must pass")
  assertFalse(findsLocaleTableDescriptor('  -- L = NS.L would be the trap'),
    "a comment must not trip the guard")
end)

-- Every file that builds a LibKa0s descriptor. A seam added without being listed here is a seam
-- with no guard, so the list is asserted against the filesystem rather than trusted.
local SEAM_FILES = {
  "core/CoreSetup.lua",
  "core/DebugLogSetup.lua",
  "settings/Slash.lua",
}

test("L trap: no seam file hands a descriptor this addon's locale table", function()
  for _, path in ipairs(SEAM_FILES) do
    assertFalse(findsLocaleTableDescriptor(readFile(path)),
      path .. " passes NS.L as a descriptor L — every key would render as its own name")
  end
end)

test("L trap: the seam-file list covers every file that calls lib:New", function()
  -- The guard above is only worth what its list covers. Derive the real set from the TOC and
  -- compare, so a new seam cannot be added without either being guarded or failing here.
  local listed = {}
  for _, p in ipairs(SEAM_FILES) do listed[p] = true end
  local missing = {}
  for _, path in ipairs(Loader.tocFiles("PanelMaster.toc")) do
    local src = readFile(path)
    if src:find('LibStub("LibKa0s-', 1, true) and not listed[path] then
      missing[#missing + 1] = path
    end
  end
  assertEqual(#missing, 0,
    "these files resolve a LibKa0s major but are not in SEAM_FILES: " .. table.concat(missing, ", "))
end)
