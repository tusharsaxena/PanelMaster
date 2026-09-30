local T = _G.PM_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local D, Sl = NS.DebugLog, NS.Slash

-- The lines LibKa0s v1.65.0 writes into THIS addon's log, and the absence of a second copy of any
-- of them (the 2026-09-30 debug-gaps adoption, standard v2.73.0's debug-logging §4 / §8 / §9).
--
-- Each module decides something a support read of the log needs -- a slash refusal, a stand-down
-- edge, a combat-locked settings act, a launcher that registered at OnEnable -- and writes it itself
-- through the `debug` sink this addon passes on its descriptor. So every case asserts two things:
-- the library's line LANDED here (the descriptor carries the sink), and it landed ONCE (no host
-- line repeats it). A host that stopped passing `debug` reddens the first half; a host that kept
-- its own line reddens the second.
--
-- The line texts are the library's contract, quoted from its docs/api (Slash version 18, Lifecycle
-- version 3, Launcher version 5, DebugLog version 18.2.1), and asserted exactly so a drift in
-- either direction is seen.

local Env = dofile("tests/degraded_env.lua")

--- The messages of every `[tag]` line in `buffer` (the console's own buffer by default).
local function tagged(tag, buffer)
  local out, pat = {}, "%[" .. tag .. "%] (.*)$"
  for _, line in ipairs(buffer or D.buffer) do
    local msg = line:match(pat)
    if msg then out[#out + 1] = msg end
  end
  return out
end

--- How many lines in `buffer` carry `fragment`, under any tag.
local function count(fragment, buffer)
  local n = 0
  for _, line in ipairs(buffer or D.buffer) do
    if line:find(fragment, 1, true) then n = n + 1 end
  end
  return n
end

--- A clean console with logging on, as a support read starts: set the flag directly, so no
--- `[Debug]` or `[Init]` line enters the buffer the case reads.
local function logging()
  mocks.__inCombat = false
  NS.State.debug = false
  D:Clear()
  NS.State.debug = true
end

local function done()
  mocks.__inCombat = false
  NS.State.debug = false
  D:Clear()
end

--- The chat lines `fn` printed.
local function chatOf(fn)
  local chat = mocks.__chat
  local before = #chat
  fn()
  local out = {}
  for i = before + 1, #chat do out[#out + 1] = chat[i] end
  return out
end

-- ── Slash (G1): the dispatcher's own refusals ──────────────────────────────────

test("library lines: a feature verb refused while disabled is one [Cmd] line, and chat is unchanged", function()
  -- Red without `debug` on settings/Slash.lua's descriptor (no line), or with a host line of its
  -- own for the gate (two). The chat line is the library's DisabledLine, once, as before.
  logging()
  Sl:CliEnable(false)
  D:Clear()
  local said = chatOf(function() Sl:OnSlash("new Refused") end)
  Sl:CliEnable(true)
  assertEqual(#said, 1, "the refusal printed more or less than one chat line")
  assertTrue(said[1]:find(Sl:DisabledLine(), 1, true) ~= nil, said[1])
  local cmd = tagged("Cmd")
  assertEqual(#cmd, 1, "not exactly one [Cmd] line for the refusal")
  assertEqual(cmd[1], "refused new: disabled")
  assertEqual(#tagged("Panel"), 0, "the refused verb still reached the Registry")
  done()
end)

test("library lines: an unknown verb is one [Cmd] line", function()
  logging()
  Sl:OnSlash("notaverb")
  local cmd = tagged("Cmd")
  assertEqual(#cmd, 1, "not exactly one [Cmd] line for the unknown verb")
  assertEqual(cmd[1], "refused notaverb: unknown verb")
  done()
end)

test("library lines: a /pm set the parser refuses is one [Cmd] line and no [Set] line", function()
  -- The schema seam writes `[Set]` only for a write it made, so a refused value is the
  -- dispatcher's line alone.
  logging()
  Sl:OnSlash("set settings.gridSize wide")
  local cmd = tagged("Cmd")
  assertEqual(#cmd, 1, "not exactly one [Cmd] line for the parse refusal")
  assertTrue(cmd[1]:find("^refused set settings%.gridSize: parse") ~= nil, cmd[1])
  assertEqual(#tagged("Set"), 0, "a refused value logged a write")
  done()
end)

test("library lines: /pm get of an unknown path and /pm profile to the current one are one line each", function()
  logging()
  Sl:OnSlash("get settings.nothingHere")
  local current = NS.db:GetCurrentProfile()
  Sl:OnSlash("profile " .. current)
  local cmd = tagged("Cmd")
  assertEqual(#cmd, 2, "not one [Cmd] line per refusal")
  assertEqual(cmd[1], "refused get settings.nothingHere: not found")
  assertEqual(cmd[2], "refused profile " .. current .. ": already current")
  done()
end)

test("library lines: a verb that succeeds writes no [Cmd] line", function()
  logging()
  Sl:OnSlash("version")
  Sl:OnSlash("get settings.gridSize")
  assertEqual(#tagged("Cmd"), 0, "an answered verb logged a refusal")
  done()
end)

-- ── Lifecycle (G5): the stand-down and stand-up edges ──────────────────────────

test("library lines: each stand-down and stand-up edge is one [Lifecycle] line, with its holds", function()
  -- Red without `debug` on core/LifecycleSetup.lua's descriptor (no line), or if NS.StandDown /
  -- NS.StandUp kept their own `[Lifecycle]` lines (two per edge).
  logging()
  Sl:CliEnable(false)
  assertTrue(NS.Lifecycle:IsDown(), "disabling did not stand the addon down")
  local lines = tagged("Lifecycle")
  assertEqual(#lines, 1, "not exactly one line for the stand-down edge")
  assertEqual(lines[1], "stood down: added disabled (holds: disabled)")
  Sl:CliEnable(true)
  lines = tagged("Lifecycle")
  assertEqual(#lines, 2, "not exactly one line for the stand-up edge")
  assertEqual(lines[2], "stood up: released disabled (holds: none)")
  done()
end)

test("library lines: a latch call that fires no edge writes no [Lifecycle] line", function()
  logging()
  NS.RefreshEnabled()
  NS.RefreshEnabled()
  NS.Lifecycle:Reevaluate()
  assertEqual(#tagged("Lifecycle"), 0, "a call that changed nothing logged an edge")
  done()
end)

-- ── Options (G3): the combat lock ──────────────────────────────────────────────

test("library lines: the settings panel refused in combat is one [Cfg] line", function()
  logging()
  mocks.__inCombat = true
  NS.Panel:Open()
  mocks.__inCombat = false
  assertEqual(count("[Cfg] open refused (in combat)"), 1, "not exactly one line for the refusal")
  done()
end)

-- ── DebugLog (G2): the change gate is the console's ────────────────────────────

test("library lines: NS.DebugOnce is re-armed by a console Clear", function()
  -- Red with a seen-set of this addon's own: a Clear could not reach it, so a cleared console
  -- stayed silent about an error that was still recurring.
  logging()
  for _ = 1, 3 do NS.DebugOnce("clear site", "boom", "Test", "once %s", "boom") end
  assertEqual(#tagged("Test"), 1, "not once before the Clear")
  D:Clear()
  for _ = 1, 3 do NS.DebugOnce("clear site", "boom", "Test", "once %s", "boom") end
  assertEqual(#tagged("Test"), 1, "the Clear did not re-arm the gate")
  done()
end)

test("library lines: NS.DebugOnce keys on site and key together", function()
  -- The two-level key survives the move onto the console's one-key gate: two sites meeting one
  -- error are two lines, and "a" .. "bc" is not "ab" .. "c".
  logging()
  NS.DebugOnce("a", "bc", "Test", "one")
  NS.DebugOnce("ab", "c", "Test", "two")
  NS.DebugOnce("a", "bc", "Test", "one again")
  assertEqual(#tagged("Test"), 2)
  done()
end)

-- ── the at-enable queue (G4): state lines written at OnEnable land ─────────────

test("library lines: the launcher's registration and the Sunn scan land the first time logging is on", function()
  -- A fresh load, so the lines are the ones this boot's OnEnable wrote with logging off. Red
  -- without `debugAtEnable` on core/LauncherSetup.lua's descriptor, or with modules/SunnArt.lua's
  -- line back on NS.Debug: both were gated off at OnEnable and never landed.
  local ns = Env.loadPartial({})
  local console = ns.DebugLog
  assertEqual(count("[Launcher] registered", console.buffer), 0, "a state line landed with logging off")
  console:SetEnabled(true)
  local buf = console.buffer
  assertEqual(count("[Launcher] registered", buf), 1, "the launcher's registration did not land once")
  assertEqual(count("[Artwork] Sunn adapter: ", buf), 1, "the Sunn scan did not land once")
  local init, launcher
  for i, line in ipairs(buf) do
    if not init and line:find("[Init] ", 1, true) then init = i end
    if line:find("[Launcher] registered", 1, true) then launcher = i end
  end
  assertTrue(init ~= nil and launcher > init, "the held lines were written ahead of the [Init] summary")
  -- One-shot: a second enable edge writes them again nowhere.
  console:SetEnabled(false)
  console:SetEnabled(true)
  assertEqual(count("[Launcher] registered", console.buffer), 1, "a held line was written twice")
  console:SetEnabled(false)
end)
