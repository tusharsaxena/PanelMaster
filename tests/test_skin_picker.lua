-- tests/test_skin_picker.lua — the first-run skin picker on this addon's seam (core/SkinSetup.lua;
-- LibKa0s OptionsSkinPicker 1; rollout rulings O3 and X6, PanelMaster decision D6).
--
-- What this addon owes the picker, and nothing the library pins itself: the spec it hands
-- O.SkinPicker (its owner, its two seams, the Skin tab's page and key, the close, and NO eye: the
-- addon has no window or test mode to preview in); WHEN it shows (a profile whose `skin.pickerSeen`
-- is false, once after login and after every profile event, never while the addon stands down, held
-- through combat); and that only the player's close marks it seen. The trigger cases spy on
-- O.SkinPicker; the last cases drive the library's real window. LootHistory's
-- tests/test_skin_picker.lua is the pattern, cut to what this addon wires.
--
-- After test_skin_unlock; leaves the harness on `Default`, the picker down and marked unseen, and
-- the skin on Ka0s Default.

local T = _G.PM_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local O = NS.Helpers
local PATH = "skin.pickerSeen"
local OWNER = "PanelMaster"
local Skin = mocks.LibStub("LibKa0s-Skin-1.0")

-- Every frame built from here on, by parent, so a case can reach the picker list's rows: the
-- harness's frames do not list their children, and the picker builds its window, rows included,
-- on its first show, which is in this file.
local childrenOf = setmetatable({}, { __mode = "k" })
do
  local create = mocks.CreateFrame
  mocks.CreateFrame = function(frameType, name, parent, ...)
    local f = create(frameType, name, parent, ...)
    if parent ~= nil then
      local list = childrenOf[parent] or {}
      childrenOf[parent] = list
      list[#list + 1] = f
    end
    return f
  end
end

--- Open the window's list and click the row for skin `key`, as the player does.
local function pickRow(f, key)
  f.dd:GetScript("OnClick")(f.dd)
  local hit = false
  for _, r in ipairs(childrenOf[f.list] or {}) do
    if r.key == key then r:GetScript("OnClick")(r); hit = true end
  end
  assertTrue(hit, "no row for " .. key)
end

--- Run `fn(calls)` with O.SkinPicker replaced by a recorder: each call's spec, in order.
local function spying(fn)
  local real = O.SkinPicker
  local calls = {}
  O.SkinPicker = function(spec)
    calls[#calls + 1] = spec
    return { spy = true }
  end
  local ok, err = pcall(fn, calls)
  O.SkinPicker = real
  if not ok then error(err, 0) end
end

--- The picker down (quietly), the skin on Ka0s Default and this profile's key back to false,
--- whatever `fn` raised.
local function clean(fn)
  return function()
    NS.HideSkinPicker()
    NS.Schema:Set(PATH, false)
    local ok, err = pcall(fn)
    NS.HideSkinPicker()
    if NS.db:GetCurrentProfile() ~= "Default" then NS.db:SetProfile("Default") end
    NS.WriteSkinChoice("ka0s", "ka0s")
    Skin:SetChoice(OWNER, "ka0s", "ka0s")
    NS.Schema:Set(PATH, false)
    mocks.__inCombat = false
    if not ok then error(err, 0) end
  end
end

local function quietly(fn)
  local cf = mocks.DEFAULT_CHAT_FRAME
  local add = cf.AddMessage
  cf.AddMessage = function() end
  local ok, err = pcall(fn)
  cf.AddMessage = add
  if not ok then error(err, 0) end
end

-- ── the key and the spec ─────────────────────────────────────────────────────────────────────

test("Skin picker: the spec names this owner, its seams, the General page's Skin tab, no eye", function()
  -- red under: a set that is not the write seam (Apply would never reach the profile), a page or
  -- tab key O.SelectTab does not know (the gear would open the wrong tab), or an eye with nothing
  -- to preview (X6, D6).
  local spec = NS.SkinPickerSpec()
  assertEqual(spec.owner, OWNER)
  assertTrue(rawequal(spec.get, NS.SkinChoice), "get is the read seam")
  assertTrue(rawequal(spec.set, NS.WriteSkinChoice), "set is the write seam")
  assertEqual(spec.page, "general", "the key the General page was registered under")
  assertEqual(spec.tab, "Appearance", "the Skin tab's key")
  assertEqual(spec.onPreview, nil, "no eye: the addon has no window or test mode to preview in")
  assertEqual(type(spec.onClose), "function")
end)

-- ── when it shows ────────────────────────────────────────────────────────────────────────────

test("Skin picker: an unseen profile shows it; a seen one does not", clean(function()
  spying(function(calls)
    NS.MaybeShowSkinPicker()
    assertEqual(#calls, 1, "pickerSeen false: the picker shows")
    assertEqual(calls[1].owner, OWNER)
    NS.Schema:Set(PATH, true)
    NS.MaybeShowSkinPicker()
    assertEqual(#calls, 1, "pickerSeen true: it does not show again")
  end)
end))

test("Skin picker: it shows once after login, two seconds in, from OnEnterWorld", clean(function()
  -- red under: dropping the call from addon:OnEnterWorld, a start per loading screen, or a start
  -- the stand-down cannot cancel. The session's start is given back first (NS.State), since the
  -- suite's earlier entering-world edges took it.
  mocks.__fireTimers()
  NS.State.skinPickerArmed = false
  spying(function(calls)
    local delays = {}
    local schedule = NS.addon.ScheduleTimer
    NS.addon.ScheduleTimer = function(self, fn, delay, ...)
      delays[#delays + 1] = delay
      return schedule(self, fn, delay, ...)
    end
    local ok, err = pcall(function()
      NS.addon:OnEnterWorld()
      NS.addon:OnEnterWorld()
    end)
    NS.addon.ScheduleTimer = schedule
    if not ok then error(err, 0) end
    local twos = 0
    for _, d in ipairs(delays) do if d == 2 then twos = twos + 1 end end
    assertEqual(twos, 1, "two entering-world edges arm ONE two-second start")
    assertEqual(#calls, 0, "nothing shows before the start fires")
    mocks.__fireTimers()
    assertEqual(#calls, 1, "the login start shows the picker")
  end)
end))

test("Skin picker: the stand-down cancels an unfired login start and gives it back", clean(function()
  mocks.__fireTimers()
  NS.State.skinPickerArmed = false
  spying(function(calls)
    NS.addon:OnEnterWorld()
    quietly(function() NS.Schema:Set("settings.enabled", false) end)
    local ok, err = pcall(function()
      mocks.__fireTimers()
      assertEqual(#calls, 0, "a start the stand-down dropped showed the picker")
      assertFalse(NS.State.skinPickerArmed, "the session's start is given back")
    end)
    quietly(function() NS.Schema:Set("settings.enabled", true) end)
    if not ok then error(err, 0) end
  end)
end))

test("Skin picker: in combat a start waits for PLAYER_REGEN_ENABLED, once", clean(function()
  spying(function(calls)
    mocks.__inCombat = true
    assertEqual(NS.MaybeShowSkinPicker(), nil)
    NS.MaybeShowSkinPicker()
    assertEqual(#calls, 0, "nothing shows in combat")
    mocks.__inCombat = false
    mocks.__fireEvent("PLAYER_REGEN_ENABLED")
    assertEqual(#calls, 1, "the combat edge shows it, once for two held starts")
    mocks.__fireEvent("PLAYER_REGEN_ENABLED")
    assertEqual(#calls, 1, "the one-shot target is gone")
  end)
end))

test("Skin picker: a held start is dropped by the stand-down's HideSkinPicker", clean(function()
  spying(function(calls)
    mocks.__inCombat = true
    NS.MaybeShowSkinPicker()
    NS.HideSkinPicker()
    mocks.__inCombat = false
    mocks.__fireEvent("PLAYER_REGEN_ENABLED")
    assertEqual(#calls, 0, "a dropped start must not fire on the combat edge")
  end)
end))

test("Skin picker: never while the addon is switched off", clean(function()
  quietly(function()
    spying(function(calls)
      NS.Schema:Set("settings.enabled", false)
      local ok, err = pcall(function()
        assertTrue(NS.Lifecycle:IsDown(), "the switch stood the addon down")
        NS.MaybeShowSkinPicker()
        assertEqual(#calls, 0, "a disabled addon shows no picker")
      end)
      NS.Schema:Set("settings.enabled", true)
      if not ok then error(err, 0) end
    end)
  end)
end))

test("Skin picker: a new profile and a reset profile show it again", clean(function()
  -- Both start from the defaults, pickerSeen false (O3). red under: no call on the profile reload
  -- path, or one before the latch re-reads the new profile's switch.
  local db = NS.db
  NS.Schema:Set(PATH, true)
  quietly(function()
    spying(function(calls)
      db:SetProfile("PickerProbe")
      assertEqual(#calls, 1, "a new profile shows the picker")
      NS.Schema:Set(PATH, true)
      db:ResetProfile()
      assertEqual(#calls, 2, "a reset profile shows it again")
      -- (The harness's AceDB keeps no profile it leaves, so a switch back to one that has seen the
      -- picker is the unseen case above with another name; the seen case is the first test's.)
    end)
  end)
  if mocks.__profiles then mocks.__profiles.PickerProbe = nil end
end))

-- ── the real window ──────────────────────────────────────────────────────────────────────────

test("Skin picker: the player's close marks it seen; this addon's own hide does not", clean(function()
  local f = NS.MaybeShowSkinPicker()
  assertTrue(f ~= nil and f:IsShown(), "the library's picker did not show")
  assertEqual(f.title:GetText(), "Choose a skin for " .. NS.BRAND, "the title names this addon")
  assertFalse(f.preview:IsShown(), "no eye on a picker with nothing to preview")
  NS.HideSkinPicker()
  assertEqual(NS.Schema:Get(PATH), false, "a stand-down hide is not the player's close")
  f = NS.MaybeShowSkinPicker()
  assertTrue(f ~= nil and f:IsShown(), "it shows again while unseen")
  O.HideSkinPicker()
  assertEqual(NS.Schema:Get(PATH), true, "the player's close sets pickerSeen")
  assertEqual(NS.MaybeShowSkinPicker(), nil, "and it does not show again")
end))

test("Skin picker: a profile that has seen it takes a shown picker down, unmarked", clean(function()
  local f = NS.MaybeShowSkinPicker()
  assertTrue(f ~= nil and f:IsShown())
  NS.db.profile.skin.pickerSeen = true
  NS.MaybeShowSkinPicker()
  assertFalse(f:IsShown(), "the picker stayed up on a profile that has seen it")
end))

test("Skin picker: Apply saves the pick through the write seam and marks the picker seen", clean(function()
  -- red under: a spec.set that is not the write seam (Apply would save nothing), or an onClose
  -- that does not write pickerSeen (the picker would come back on the next login).
  quietly(function()
    local f = NS.MaybeShowSkinPicker()
    assertTrue(f ~= nil and f:IsShown(), "the library's picker did not show")
    pickRow(f, "obsidian")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "obsidian", "the pick is worn at once")
    assertEqual(select(2, NS.SkinChoice()), "ka0s", "a pick alone writes nothing to the profile")
    f.apply:GetScript("OnClick")(f.apply)
    assertFalse(f:IsShown(), "Apply closes the window")
    assertEqual(select(2, NS.SkinChoice()), "obsidian", "Apply saves through NS.WriteSkinChoice")
    assertEqual(NS.Schema:Get(PATH), true, "Apply marks the picker seen")
  end)
end))

test("Skin picker: a profile event takes a shown picker down before the new profile's skin", clean(function()
  -- red under: the reload applying the new profile's skin with the picker (and its pending
  -- preview) still up, so the preview's put-back would land over the profile's own choice.
  local f = NS.MaybeShowSkinPicker()
  assertTrue(f ~= nil and f:IsShown())
  local apply, upAtApply = NS.ApplySkinChoice, nil
  NS.ApplySkinChoice = function(...)
    if upAtApply == nil then upAtApply = f:IsShown() end
    return apply(...)
  end
  local ok, err = pcall(function() quietly(function() NS.db:SetProfile("PickerProbe") end) end)
  NS.ApplySkinChoice = apply
  if mocks.__profiles then mocks.__profiles.PickerProbe = nil end
  if not ok then error(err, 0) end
  assertEqual(upAtApply, false, "the picker was still up when the new profile's skin was applied")
  assertEqual(NS.Schema:Get(PATH), false, "the profile event's hide is not the player's close")
end))

test("Skin picker: the stand-down takes a shown picker down unseen", clean(function()
  local f = NS.MaybeShowSkinPicker()
  assertTrue(f ~= nil and f:IsShown())
  quietly(function() NS.Schema:Set("settings.enabled", false) end)
  local ok, err = pcall(function()
    assertFalse(f:IsShown(), "the picker outlived the stand-down")
    assertEqual(NS.Schema:Get(PATH), false, "a stand-down is not the player's close")
  end)
  quietly(function() NS.Schema:Set("settings.enabled", true) end)
  if not ok then error(err, 0) end
end))
