-- tests/test_skin_verb.lua — the reserved `skin` verb (LibKa0s v1.82.0, OptionsSkinPicker minor 3's
-- O.SkinVerb; PM-01 of Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-16):
-- a `skin` row after `config` runs NS.RunSkinVerb, which hands O.SkinVerb the first-run spec, so
-- `/pm skin` shows the picker a new profile shows whatever skin.pickerSeen says. Refused while the
-- addon is disabled (the dispatcher's gate), a gray line on every call in combat (the library's),
-- and the library-absent line without LibKa0s. LibKa0sSkinTester's tests/test_skin_verb.lua is the
-- pattern, cut to this harness.
--
-- After test_skin_picker; leaves the picker down and unseen, the addon enabled and out of combat.

local T = _G.PM_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local PATH = "skin.pickerSeen"
local Env = dofile("tests/degraded_env.lua")

local function strings() return mocks.LibStub("LibKa0s-Options-1.0").SKIN_PICKER_STRINGS end

local function chatSince(at)
  local out = {}
  for i = at + 1, #mocks.__chat do out[#out + 1] = mocks.__chat[i] end
  return out
end

local function anyLine(lines, fragment)
  for _, l in ipairs(lines) do if l:find(fragment, 1, true) then return true end end
  return false
end

--- Run `fn(rec)` with O.SkinVerb replaced by a recorder (rec.spec, rec.calls), answering `answer`.
local function spying(answer, fn)
  local O = NS.Helpers
  local real, rec = O.SkinVerb, { calls = 0 }
  O.SkinVerb = function(spec) rec.calls = rec.calls + 1; rec.spec = spec; return answer() end
  local ok, err = pcall(fn, rec)
  O.SkinVerb = real
  if not ok then error(err, 0) end
end

--- The picker down and this profile marked seen, so only the verb can bring it back; put back
--- unseen, enabled and out of combat whatever `fn` raised.
local function seen(fn)
  return function()
    NS.HideSkinPicker()
    NS.Schema:Set(PATH, true)
    local ok, err = pcall(fn)
    mocks.__inCombat = false
    NS.HideSkinPicker()
    if NS.Schema:Get("settings.enabled") == false then NS.Schema:Set("settings.enabled", true) end
    NS.Schema:Set(PATH, false)
    NS.HideSkinPicker()
    if not ok then error(err, 0) end
  end
end

test("Skin verb: the row sits right after config, with the library's help words", function()
  local at
  for i, c in ipairs(NS.COMMANDS) do if c[1] == "skin" then at = i end end
  assertTrue(at ~= nil, "a skin row")
  assertEqual(NS.COMMANDS[at - 1][1], "config", "after config")
  assertEqual(NS.COMMANDS[at][2], strings().VERB_HELP, "one wording for every host")
  assertFalse(NS.Slash.ALWAYS_LIVE.skin == true, "a feature verb, not a live one")
end)

test("Skin verb: /pm skin shows the picker on a profile that has closed it", seen(function()
  -- red under: no skin row (the dispatcher answers "unknown command").
  local at = #mocks.__chat
  local win
  spying(function() return { spy = true } end, function(rec)
    NS.Slash:OnSlash("skin")
    assertEqual(rec.calls, 1, "the verb reached O.SkinVerb")
    win = rec.spec
  end)
  assertFalse(anyLine(chatSince(at), "unknown command"), "a known verb")
  assertTrue(win ~= nil, "a spec was handed over")
  -- And through the library's real window: shown whatever pickerSeen says.
  local f = NS.RunSkinVerb()
  assertTrue(f ~= nil and f:IsShown(), "the library's picker is up on a seen profile")
  assertEqual(NS.Schema:Get(PATH), true, "showing it writes nothing")
end))

test("Skin verb: NS.RunSkinVerb hands O.SkinVerb this addon's first-run spec", seen(function()
  spying(function() return nil, "queued" end, function(rec)
    local win, why = NS.RunSkinVerb()
    assertEqual(rec.spec.owner, "PanelMaster")
    assertTrue(rawequal(rec.spec.get, NS.SkinChoice), "the read seam")
    assertTrue(rawequal(rec.spec.set, NS.WriteSkinChoice), "the write seam")
    assertEqual(rec.spec.page, "general")
    assertEqual(rec.spec.tab, "Appearance")
    assertEqual(win, nil, "nothing shown")
    assertEqual(why, "queued", "the library's reason, passed on")
  end)
end))

test("Skin verb: in combat every call prints the library's gray line and shows nothing", seen(function()
  mocks.__inCombat = true
  local at = #mocks.__chat
  local first = NS.RunSkinVerb()
  local mid = #mocks.__chat
  local second = NS.RunSkinVerb()
  assertEqual(first, nil)
  assertEqual(second, nil)
  assertTrue(anyLine(chatSince(at), strings().VERB_COMBAT), "the first call says why")
  local tail = {}
  for i = mid + 1, #mocks.__chat do tail[#tail + 1] = mocks.__chat[i] end
  assertTrue(anyLine(tail, strings().VERB_COMBAT), "and so does every later one")
end))

test("Skin verb: refused while the addon is disabled, and no picker shows", seen(function()
  NS.Schema:Set("settings.enabled", false)
  spying(function() return { spy = true } end, function(rec)
    local at = #mocks.__chat
    NS.Slash:OnSlash("skin")
    local out = chatSince(at)
    assertEqual(#out, 1, "one refusal line")
    assertEqual(out[1], NS.PREFIX .. " " .. NS.Slash:DisabledLine())
    assertEqual(rec.calls, 0, "the verb never reached O.SkinVerb")
  end)
end))

test("Skin verb: without LibKa0s the verb prints the library-absent line", function()
  local ns, m = Env.loadDegraded()
  ns.Print("warm up the notice")
  local at = #m.__chat
  local ok, err = pcall(ns.Slash.OnSlash, ns.Slash, "skin")
  assertTrue(ok, "/pm skin raised: " .. tostring(err))
  assertEqual(#m.__chat, at + 1, "exactly one line")
  assertEqual(m.__chat[#m.__chat], ns.PREFIX .. " " ..
    ns.L["%s is unavailable: the LibKa0s library did not load."]:format("/pm skin"))
end)
