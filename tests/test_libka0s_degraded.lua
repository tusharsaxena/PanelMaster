local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- The degraded half of the LibKa0s adoption: what an install with no library, or a part of one,
-- still does, said once, in the collection's shared wording. Peeled out of tests/test_libka0s.lua,
-- which keeps the seams against the live library and the `L` trap. Listed right after it in
-- tests/run.lua. The environments come from tests/degraded_env.lua.

local Env = dofile("tests/degraded_env.lua")
local loadPartial, loadDegraded = Env.loadPartial, Env.loadDegraded

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
  for _, member in ipairs({ "IsShown", "Show", "Hide", "Toggle", "SetEnabled", "Add", "RunDiagnostics",
                          "DebugVerb" }) do
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
  local ns, m = loadDegraded()
  ns.Print("warm up the notice")

  local before = #m.__chat
  ns.DebugLog:SetEnabled(true)
  assertTrue(ns.State.debug, "the degraded console did not set the logging flag")

  local ackOn
  for i = before + 1, #m.__chat do
    if m.__chat[i]:lower():find("debug logging", 1, true) then ackOn = m.__chat[i] end
  end
  assertTrue(ackOn ~= nil, "the degraded console flipped the flag without acknowledging it")

  before = #m.__chat
  ns.DebugLog:SetEnabled(false)
  assertFalse(ns.State.debug)

  local ackOff
  for i = before + 1, #m.__chat do
    if m.__chat[i]:lower():find("debug logging", 1, true) then ackOff = m.__chat[i] end
  end
  assertTrue(ackOff ~= nil, "the degraded console flipped the flag off without acknowledging it")
  assertTrue(ackOn ~= ackOff, "the ack says the same thing on and off")

  -- And the ack must be the STUB's own line, not a hand-copy of the library's. The library owns
  -- `ACK` and the ON/OFF state hexes (libs/LibKa0s/DebugLog.lua); this path runs with the library
  -- ABSENT, so a copy of either is a transcription that nothing can keep in step (anti-pattern #47).
  for _, line in ipairs({ ackOn, ackOff }) do
    assertEqual(line:find("cff40ff40", 1, true), nil, "the stub re-implements the library's ON hex")
    assertEqual(line:find("cffff4040", 1, true), nil, "the stub re-implements the library's OFF hex")
  end
end)

test("Degraded install: both report forms answer with the library-absent line", function()
  -- debug-logging-§14 / STD-14: with no library there is no report, and both forms say so in the
  -- collection's line rather than going quiet or raising. Dispatched through the degraded arm's own
  -- dispatcher, which is the one a player reaches on this install.
  local ns, m = loadDegraded()
  ns.Print("warm up the notice")
  for _, form in ipairs({ "diagnostics", "debug diagnostics" }) do
    local before = #m.__chat
    ns.Slash:OnSlash(form)
    assertTrue(#m.__chat > before, "/pm " .. form .. " answered nothing on a degraded install")
    assertTrue(m.__chat[#m.__chat]:find("/pm diagnostics is unavailable", 1, true) ~= nil,
      "/pm " .. form .. " did not print the library-absent line")
  end
end)

test("Degraded install: the diagnostics report says the library is absent and writes nothing",
  function()
    -- debug-logging-§14 / DebugLog 14.1: the report is the library's, so the stub answers with the
    -- collection's library-absent line naming the command, writes nothing and returns 0.
    local ns, m = loadDegraded()
    ns.Print("warm up the notice")
    local D = ns.DebugLog
    local before = #m.__chat
    assertEqual(D:RunDiagnostics(), 0, "the stub's report claims to have written lines")
    assertEqual(#m.__chat, before + 1, "the stub's report is one chat line")
    assertEqual(m.__chat[#m.__chat], ns.PREFIX .. " "
      .. "/pm diagnostics is unavailable: the LibKa0s library did not load.")
    assertEqual(D:BufferSize(), 0, "the stub's report wrote into a console that does not exist")

    local data = D:BuildDiagnostics()
    assertEqual(#data.lines, 0)
    assertEqual(data.dropped, 0)
    assertFalse(data.capped)
    assertFalse(data.capsHit)

    -- DebugVerb: the library's three words answer true, anything else false for the host's fallback.
    before = #m.__chat
    assertTrue(D:DebugVerb("Diagnostics"), "the debug word is matched in any case")
    assertTrue(m.__chat[#m.__chat]:find("/pm diagnostics is unavailable", 1, true) ~= nil)
    assertTrue(D:DebugVerb("on"))
    assertTrue(ns.State.debug, "`on` did not reach SetEnabled")
    assertTrue(D:DebugVerb("off"))
    assertFalse(ns.State.debug, "`off` did not reach SetEnabled")
    assertFalse(D:DebugVerb("diag"), "a short name must not run the report")
    assertFalse(D:DebugVerb("dump"))
    assertFalse(D:DebugVerb(nil))
    assertTrue(#m.__chat > before)
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

test("Degraded install: /pm config answers on EVERY invocation, not once", function()
  -- PM-R-07. The stub latched its explanation behind a `said` flag, so the first `/pm config`
  -- printed why the panel was unavailable and every one after it did nothing at all — which reads
  -- as the command being broken rather than as the panel being missing.
  --
  -- The once-per-session latches elsewhere in this addon are correct and stay: they sit on notices
  -- that ride other output. This line rides nothing; it IS the answer to a verb the user invoked.
  local ns, m = loadPartial({ Options = true, OptionsWidgets = true, OptionsScroll = true })
  ns.Print("warm up the Core notice")
  local before = #m.__chat
  ns.Helpers.OpenOptionsPanel()
  ns.Helpers.OpenOptionsPanel()
  ns.Helpers.OpenOptionsPanel()
  local said = 0
  for i = before + 1, #m.__chat do
    if m.__chat[i]:find("so the settings panel is unavailable.", 1, true) then said = said + 1 end
  end
  assertEqual(said, 3, "`/pm config` went silent after the first invocation")
  -- It carries the collection's shared cause clause, like every other degraded notice here.
  assertTrue(m.__chat[before + 1]:find(ns.LIBKA0S_MISSING, 1, true) ~= nil,
    "the /pm config notice does not lead with the shared cause clause")
end)

test("Degraded install: a bare /pm runs `config`, and falls back to help without one", function()
  -- The stub dispatcher follows the library's rule (slash-commands-§4): bare runs the `config` row
  -- with an empty string, and only a table with no `config` row gets the help answer, which here is
  -- the unavailable notice.
  local ns, m = loadDegraded()
  local index, row
  for i, cmd in ipairs(ns.COMMANDS) do if cmd[1] == "config" then index, row = i, cmd end end
  assertTrue(row ~= nil, "the degraded install has no `config` row")

  local real, got = row[3], {}
  row[3] = function(a) got[#got + 1] = a end
  ns.Slash:OnSlash("")
  ns.Slash:OnSlash("  ")
  ns.Slash:OnSlash(nil)
  row[3] = real
  assertEqual(#got, 3, "a bare /pm did not reach `config` in a degraded install")
  for _, a in ipairs(got) do assertEqual(a, "") end

  ns.Print("warm up the Core notice")
  table.remove(ns.COMMANDS, index)
  local before = #m.__chat
  ns.Slash:OnSlash("")
  local rows = #ns.COMMANDS
  table.insert(ns.COMMANDS, index, row)
  -- The help answer is the degraded index (PM-09): the notice, then one row per remaining verb.
  assertEqual(#m.__chat, before + 1 + rows, "a bare /pm with no `config` row did not print the index")
  assertTrue(m.__chat[before + 1]:find(ns.LIBKA0S_MISSING, 1, true) ~= nil,
    "a bare /pm with no `config` row did not fall back to the help answer")
end)

-- ── the composed-row verbs on a library-absent load (slash-commands-§1, WS-02) ─
--
-- `enable`, `disable`, `lock` and `unlock` write rows the Options COMPOSER declares, so whenever the
-- Options major is absent -- the whole library, or Options alone -- there is no row for them to
-- write. `enable` / `disable` take route (a): the path is in the Schema seam's `writeThrough` list,
-- so the value is stored without a row and the verb re-evaluates the latch itself. `lock` /
-- `unlock` take route (b): the library-absent line, and nothing written.

--- The two library-absent loads the composed rows vanish on, in a fixed order.
local COMPOSERLESS = {
  { "degraded", function() return loadDegraded() end },
  { "partial", function()
      return loadPartial({ Options = true, OptionsWidgets = true, OptionsScroll = true,
                           OptionsCompose = true })
    end },
}

test("Degraded install: /pm disable and /pm enable write through and flip the latch without raising",
  function()
    for _, arm in ipairs(COMPOSERLESS) do
      local name, ns, m = arm[1], arm[2]()
      assertEqual(ns.Schema:FindRow(ns.Schema.ENABLED_PATH), nil, name .. ": the enabled row exists")
      ns.Print("warm up the notice")
      local ok, err = pcall(ns.Slash.OnSlash, ns.Slash, "disable")
      assertTrue(ok, name .. ": /pm disable raised: " .. tostring(err))
      assertEqual(ns.db.profile.settings.enabled, false, name .. ": /pm disable did not land")
      assertTrue(ns.Lifecycle:IsDown(), name .. ": /pm disable did not stand the addon down")
      assertEqual(m.__chat[#m.__chat],
        ns.PREFIX .. " " .. ns.Slash.FormatKV("settings.enabled", "false"), name)

      ok, err = pcall(ns.Slash.OnSlash, ns.Slash, "enable")
      assertTrue(ok, name .. ": /pm enable raised: " .. tostring(err))
      assertEqual(ns.db.profile.settings.enabled, true, name .. ": /pm enable did not land")
      assertFalse(ns.Lifecycle:IsDown(), name .. ": /pm enable did not stand the addon back up")
      assertEqual(m.__chat[#m.__chat],
        ns.PREFIX .. " " .. ns.Slash.FormatKV("settings.enabled", "true"), name)
    end
  end)

test("Degraded install: /pm unlock and /pm lock print the library-absent line and change nothing",
  function()
    for _, arm in ipairs(COMPOSERLESS) do
      local name, ns, m = arm[1], arm[2]()
      ns.Print("warm up the notice")
      for _, verb in ipairs({ "unlock", "lock" }) do
        local was = ns.State.unlocked
        local before = #m.__chat
        local ok, err = pcall(ns.Slash.OnSlash, ns.Slash, verb)
        assertTrue(ok, name .. ": /pm " .. verb .. " raised: " .. tostring(err))
        assertEqual(#m.__chat, before + 1, name .. ": /pm " .. verb .. " did not print exactly one line")
        assertEqual(m.__chat[#m.__chat], ns.PREFIX .. " " ..
          ns.L["%s is unavailable: the LibKa0s library did not load."]:format("/pm " .. verb), name)
        assertEqual(ns.State.unlocked, was, name .. ": /pm " .. verb .. " changed the unlock state")
      end
    end
  end)

test("Degraded install: /pm profile prints the library-absent line and switches nothing",
  function()
    -- Slash minor 17's degradation stub carries CliProfile AND ProfileSwitch on route (b): with no
    -- library there is no store adapter to trust, so each prints the library-absent line for
    -- `/pm profile` and switches nothing. AceDB itself is still there, which is why "switches
    -- nothing" is read back from the store rather than assumed. Only the whole-library arm: the
    -- composer-less partial load still has the Slash major, so its verb works.
    local ns, m = loadDegraded()
    assertEqual(m.__setProfileCalls, 0, "the fake counts no SetProfile call to start")
    m.__addProfile("Other")
    local was = m.__profileName
    ns.Print("warm up the notice")
    local absent = ns.PREFIX .. " " ..
      ns.L["%s is unavailable: the LibKa0s library did not load."]:format("/pm profile")
    for _, input in ipairs({ "profile", "profile Other" }) do
      local before = #m.__chat
      local ok, err = pcall(ns.Slash.OnSlash, ns.Slash, input)
      assertTrue(ok, "/pm " .. input .. " raised: " .. tostring(err))
      assertEqual(#m.__chat, before + 1, "/pm " .. input .. " did not print one line")
      assertEqual(m.__chat[#m.__chat], absent, "/pm " .. input)
    end
    local before = #m.__chat
    assertEqual(ns.Slash:ProfileSwitch("Other"), false, "ProfileSwitch claimed a switch")
    assertEqual(#m.__chat, before + 1, "ProfileSwitch did not print one line")
    assertEqual(m.__chat[#m.__chat], absent, "ProfileSwitch")
    assertEqual(m.__profileName, was, "the profile switched with no library")
    assertEqual(m.__setProfileCalls, 0, "SetProfile ran with no library")
  end)

test("Degraded install: the help index still lists every verb", function()
  local ns, m = loadDegraded()
  ns.Print("warm up the notice")
  local before = #m.__chat
  ns.Slash:OnSlash("help")
  assertEqual(#m.__chat, before + 1 + #ns.COMMANDS,
    "the degraded help is not the notice plus one row a verb")
  assertTrue(m.__chat[before + 1]:find(ns.LIBKA0S_MISSING, 1, true) ~= nil,
    "the degraded help does not lead with the library-absent notice")
  for i, cmd in ipairs(ns.COMMANDS) do
    assertEqual(m.__chat[before + 1 + i], ns.PREFIX .. " /pm " .. cmd[1] .. "  " .. cmd[2])
  end
end)

test("Degraded install: the schema loses the composed Master controls rows and NOTHING else",
  function()
    -- options-ui-§1 requires the stub's cost to be MEASURED rather than assumed, and pinned by the
    -- suite. The composers are the one thing the stub cannot answer honestly: what they emit is the
    -- library's canonical row data -- the order, the labels, the ranges, the defaults -- and a
    -- hand-copied set in the stub would be the copy that goes stale (anti-pattern #47).
    --
    -- So a library-less install reaches the Moving panels and New panels rows through `/pm list|get|set`
    -- and not the Master controls ones. That is the whole difference, and this case exists so it
    -- can never widen without somebody deciding to widen it.
    local degradedNS = loadPartial({ Options = true, OptionsWidgets = true, OptionsScroll = true,
                                     OptionsCompose = true })
    local live, degraded = NS.Schema.Schema, degradedNS.Schema.Schema

    local master = 0
    for _, row in ipairs(live) do
      if row.group == "Master controls" then master = master + 1 end
    end
    assertTrue(master > 0, "the live schema has no Master controls rows to lose")
    assertEqual(#degraded, #live - master,
      "the degraded schema is not exactly the live one minus the composed block")

    for _, row in ipairs(degraded) do
      assertFalse(row.group == "Master controls",
        "the degradation stub composed a Master controls row after all: " .. tostring(row.path))
    end
    assertFalse(degradedNS.Schema:InstallMaster(degradedNS.Helpers),
      "the stub reported that the canonical rows arrived")

    -- Every remaining row still resolves against the defaults, so the degraded install's CLI is
    -- narrower and not broken.
    assertEqual(degradedNS.Schema:Register(), 0)
  end)
