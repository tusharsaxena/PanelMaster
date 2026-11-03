-- tests/test_skin_picker.lua — the first-run skin picker on this addon's seam (core/SkinSetup.lua;
-- LibKa0s OptionsSkinPicker 1; rollout ruling O3; the preview, OptionsSkinPicker 11 and R6-PV).
--
-- What this addon owes the picker, and nothing the library pins itself: the spec it hands
-- O.SkinPicker (its owner, its two seams, the Skin tab's page and key, the close, and the eye's
-- unlock mode, `spec.preview`, through the `/pm unlock` / `/pm lock` seam); WHEN it shows (a profile whose `skin.pickerSeen`
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

test("Skin picker: the spec names this owner, its seams, the General page's Skin tab, the unlock eye", function()
  -- red under: a set that is not the write seam (Apply would never reach the profile), a page or
  -- tab key O.SelectTab does not know (the gear would open the wrong tab), or the old one-shot eye
  -- (R6-PV: the eye's mode is unlock, entered at show, toggled, restored at close).
  local spec = NS.SkinPickerSpec()
  assertEqual(spec.owner, OWNER)
  assertTrue(rawequal(spec.get, NS.SkinChoice), "get is the read seam")
  assertTrue(rawequal(spec.set, NS.WriteSkinChoice), "set is the write seam")
  assertEqual(spec.page, "general", "the key the General page was registered under")
  assertEqual(spec.tab, "Appearance", "the Skin tab's key")
  assertEqual(spec.onPreview, nil, "no one-shot eye: spec.preview replaces it")
  local h = spec.preview
  assertEqual(type(h), "table", "the eye's preview contract")
  assertEqual(h.mode, "unlock", "unlocking is this addon's preview (00_PLAN.md call 2)")
  for _, k in ipairs({ "enter", "exit", "isActive", "isShown" }) do
    assertEqual(type(h[k]), "function", "spec.preview." .. k)
  end
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
  -- LibKa0s v1.81.0 (OptionsSkinPicker minor 2): the title is "Choose a skin" and the addon's
  -- name has its own line above the dropdown. That the window widens so the name is never cut off
  -- is the library's to pin (the mock measures every string 0 wide); the smoke check SKIN-15 sees it.
  assertEqual(f.title:GetText(), "Choose a skin", "the title no longer carries the addon's name")
  assertEqual(f.ownerLabel:GetText(), NS.BRAND, "the line above the dropdown names this addon")
  assertTrue(f.preview:IsShown(), "the eye shows: the preview is the unlock mode")
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

-- ── the eye: unlock mode (R6-PV; LibKa0s OptionsSkinPicker 11, spec.preview) ─────────────────
--
-- The owner's rule (Ka0sAddonsCommonTasks docs/2026-11-03-SMOKE_ROUND6, call 2): with the panels
-- locked, a showing picker unlocks them; the eye locks and unlocks; every close puts back the state
-- the picker opened on. Every move goes through NS.Schema:Set("state.locked"), the write seam
-- `/pm lock`, `/pm unlock`, the launcher and the Lock frame row share, never NS.Unlock directly.

local function locked() return NS.Schema:Get("state.locked") and true or false end

--- `fn()` with the panels in a known global state, put back locked whatever it raised.
local function fromLock(isLocked, fn)
  return clean(function()
    quietly(function() NS.Unlock:SetUnlocked(not isLocked) end)
    local ok, err = pcall(quietly, fn)
    mocks.__inCombat = false
    quietly(function()
      NS.HideSkinPicker()
      NS.Unlock:DropPending("test")
      NS.Unlock:SetUnlocked(false)
    end)
    if not ok then error(err, 0) end
  end)
end

--- `fn(calls)` with the write seam's `state.locked` writes recorded: each value, in order.
local function lockCalls(fn)
  local S = NS.Schema
  local real = S.Set
  local calls = {}
  S.Set = function(self, path, v, ...)
    if path == "state.locked" then calls[#calls + 1] = v end
    return real(self, path, v, ...)
  end
  local ok, err = pcall(fn, calls)
  S.Set = real
  if not ok then error(err, 0) end
end

local function eye(f) f.preview:GetScript("OnClick")(f.preview) end

--- Escape, as the client runs it: UISpecialFrames hides the window, then its OnHide script fires
--- (the harness records SetScript handlers rather than firing them from Hide).
local function escape(f)
  f:Hide()
  local onHide = f:GetScript("OnHide")
  if onHide then onHide(f) end
end

test("Skin picker preview: shown with the panels locked, it unlocks them through the write seam",
  fromLock(true, function()
  -- red under: no spec.preview (nothing enters at show), or an enter that goes round the seam.
  lockCalls(function(calls)
    local f = NS.MaybeShowSkinPicker()
    assertTrue(f ~= nil and f:IsShown(), "the library's picker did not show")
    assertFalse(locked(), "the picker's show unlocks the panels")
    assertTrue(NS.State.unlocked, "the unlock is the session state every panel reads")
    assertEqual(calls[1], false, "through NS.Schema:Set(\"state.locked\", false)")
    assertTrue(f.preview.lit, "the eye is lit while unlocked")
  end)
end))

test("Skin picker preview: the eye locks and unlocks, through the seam each time", fromLock(true, function()
  lockCalls(function(calls)
    local f = NS.MaybeShowSkinPicker()
    eye(f)
    assertTrue(locked(), "the eye locks")
    assertFalse(f.preview.lit, "and dims")
    eye(f)
    assertFalse(locked(), "the eye unlocks again")
    assertTrue(f.preview.lit, "and lights")
    assertEqual(table.concat({ tostring(calls[1]), tostring(calls[2]), tostring(calls[3]) }, ","),
      "false,true,false", "every move is the write seam")
  end)
end))

-- Every close route the library has, each from a locked start: the panels are locked again after.
local ROUTES = {
  { "the close control", function(f) f.close:GetScript("OnClick")(f.close) end },
  { "Escape", escape },
  { "Apply", function(f) f.apply:GetScript("OnClick")(f.apply) end },
  { "Apply to all", function(f) f.applyAll:GetScript("OnClick")(f.applyAll) end },
  { "the gear", function(f) f.settings:GetScript("OnClick")(f.settings) end },
  { "the library's HideSkinPicker", function() O.HideSkinPicker() end },
  { "this addon's own hide (stand-down, profile event)", function() NS.HideSkinPicker() end },
}
for _, route in ipairs(ROUTES) do
  test("Skin picker preview: " .. route[1] .. " locks the panels it unlocked", fromLock(true, function()
    -- red under: a restore that skips this route (the panels stay unlocked after the picker).
    local f = NS.MaybeShowSkinPicker()
    assertFalse(locked(), "unlocked at show")
    route[2](f)
    assertFalse(f:IsShown(), "the route closes the picker")
    assertTrue(locked(), "the close put the lock back")
  end))
end

test("Skin picker preview: an eye that locked again leaves the close nothing to undo", fromLock(true, function()
  lockCalls(function(calls)
    local f = NS.MaybeShowSkinPicker()
    eye(f)
    local n = #calls
    O.HideSkinPicker()
    assertTrue(locked(), "still locked")
    assertEqual(#calls, n, "no write at the close")
  end)
end))

test("Skin picker preview: panels already unlocked are left alone, and stay unlocked", fromLock(false, function()
  -- red under: an isShown or isActive that misreads the unlock (the show or the close would move it).
  lockCalls(function(calls)
    local f = NS.MaybeShowSkinPicker()
    assertFalse(locked(), "still unlocked")
    assertEqual(#calls, 0, "the show writes nothing over an unlock the player made")
    O.HideSkinPicker()
    assertFalse(locked(), "the close leaves the player's unlock")
    assertFalse(f:IsShown())
  end)
end))

test("Skin picker preview: opened unlocked, locked by the eye, the close unlocks again", fromLock(false, function()
  local f = NS.MaybeShowSkinPicker()
  eye(f)
  assertTrue(locked(), "the eye locks")
  escape(f)
  assertFalse(locked(), "the close put back the unlock the picker opened on")
end))

test("Skin picker preview: a panel unlocked on its own is unlocked again after the close", fromLock(true, function()
  -- red under: the preview's lock dropping every per-panel unlock (SetUnlocked(false) clears them),
  -- or putting back one for a panel deleted while the picker was up.
  local kept = NS.Registry:New("PreviewKept", {})
  local gone = NS.Registry:New("PreviewGone", {})
  local ok, err = pcall(function()
    NS.Unlock:SetPanelUnlocked(kept.id, true)
    NS.Unlock:SetPanelUnlocked(gone.id, true)
    local f = NS.MaybeShowSkinPicker()
    assertFalse(locked())
    NS.Registry:Delete(gone.id)
    escape(f)
    assertTrue(locked(), "the global lock is back")
    assertTrue(NS.State.unlockedPanels[kept.id] == true, "the panel's own unlock survives the preview")
    assertEqual(NS.State.unlockedPanels[gone.id], nil, "a deleted panel is not unlocked back")
  end)
  NS.Registry:DeleteAll()
  if not ok then error(err, 0) end
end))

test("Skin picker preview: a profile event forgets the per-panel unlocks the preview found", fromLock(true, function()
  -- Panel ids are per profile (modules/Registry.lua, clearPanelSessionState): a profile event shows
  -- the new profile's picker BEFORE the registry reloads, so its unlock finds the old profile's ids.
  -- red under: a close that unlocks those ids again, in a profile where they name other panels.
  NS.State.unlockedPanels[4242] = true
  NS.db:SetProfile("PreviewProbe")
  local ok, err = pcall(function()
    assertFalse(locked(), "the new profile's picker unlocked the panels")
    O.HideSkinPicker()
    assertTrue(locked(), "the close locked them")
    assertEqual(NS.State.unlockedPanels[4242], nil, "an id from the profile left behind came back")
  end)
  NS.db:SetProfile("Default")
  if mocks.__profiles then mocks.__profiles.PreviewProbe = nil end
  NS.State.unlockedPanels[4242] = nil
  if not ok then error(err, 0) end
end))

test("Skin picker preview: in combat the eye refuses the unlock rather than queue it", fromLock(true, function()
  -- red under: an enter that hands the seam a combat-held unlock, which would land on the combat
  -- exit after the picker had closed, unlocking the panels with nothing left to lock them.
  local f = NS.MaybeShowSkinPicker()
  eye(f)
  assertTrue(locked(), "locked by the eye")
  mocks.__inCombat = true
  eye(f)
  assertTrue(locked(), "no unlock in combat")
  assertFalse(f.preview.lit, "the eye stays dimmed")
  escape(f)
  mocks.__inCombat = false
  mocks.__fireEvent("PLAYER_REGEN_ENABLED")
  assertTrue(locked(), "nothing was held to unlock at the combat exit")
end))

test("Skin picker preview: in combat the close still locks what the picker unlocked", fromLock(true, function()
  local f = NS.MaybeShowSkinPicker()
  assertFalse(locked())
  mocks.__inCombat = true
  f.close:GetScript("OnClick")(f.close)
  assertTrue(locked(), "a lock is never deferred")
end))
