local T = _G.PM_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse
local S, R, Sl = NS.Schema, NS.Registry, NS.Slash

-- ── The stand-down conformance suite (slash-commands-§7) ───────────────────────
--
-- WHAT THIS FILE IS FOR, AND WHAT IT REFUSES TO BE. Disabled means the addon is NOT RUNNING: it
-- stops drawing, it stops watching, it stops writing, and the only thing left alive is the surface
-- that can turn it back on. Eleven addons in this collection -- this one until today -- implemented
-- that as a DRAW GATE: frames hidden, a boolean consulted by an early return, and every event,
-- message and ticker still registered and still dispatching. From outside, a draw gate and a genuine
-- stand-down are indistinguishable, which is exactly how the draw gate survived five audits of this
-- repo.
--
-- SO EVERY ASSERTION BELOW IS ON THE REGISTRATION SET, never on a handler's return value. "Call the
-- handler and assert it returned early" is the draw gate passing its own test: an early return IS
-- what a draw gate does. The kit's `M.__registrations()` (revision 22) answers over the LIVE set and
-- LOSES entries when the addon gives something up, which is the half that matters.
--
-- THE SURVIVOR SET IS NAMED, NOT WAIVED. slash-commands-§7 exempts SETUP -- the things that come up
-- on load in either state and are not features -- and this addon's setup includes three
-- registrations. They are listed once, in `isSurvivor` below, with the reason each one is setup, and
-- the suite asserts the survivor set is EXACTLY those three: a fourth registration cannot arrive
-- unremarked, and a feature that quietly joins the list reddens this file rather than passing it.
--
-- WHAT IS NOT HERE, because this addon does not have it: there is no secure-attribute or
-- state-driver work anywhere in `core/`, `modules/` or `settings/` (every panel is a plain
-- non-secure `CreateFrame("Frame")` backdrop), so the one PLAYER_REGEN_ENABLED registration §7
-- permits a disabled addon to keep is never taken here -- the stand-down completes in the same turn
-- as the write, every time, and that event goes down with the rest. There is no `perf` verb and no
-- `core/PerfSetup.lua` either (docs/performance.md, and the ratified `performance-§1` row), so the
-- `perf` hold is exercised below by this suite taking it directly, which is the only caller it has.

local ENABLED = S.ENABLED_PATH
local COMBAT_ENTRY = "PLAYER_REGEN_DISABLED"   -- named, per §7 step 6

-- ── survey helpers ─────────────────────────────────────────────────────────────

--- Is this registration one of the three SETUP registrations §7's survivor list exempts?
---
---   * `PLAYER_LOGIN` on the addon object is the settings-category registration's DEFERRED HALF and
---     nothing else: its handler calls `NS.Panel:Register()` and reads nothing about panels. §7
---     keeps "the settings-category registration and the panel body", and options-ui-§1 sanctions
---     the PLAYER_LOGIN bootstrap by name. Standing it down would make the addon absent from
---     Blizzard's options list -- the surface a player uses to switch it back on by hand -- on
---     exactly the load order that lost the race at ADDON_LOADED.
---   * the Panels page's two bus subscriptions (`NS.PanelEditor.__evPanels`) are the PANEL BODY.
---     They exist only to keep an OPEN settings page in step with the store, they are ADDON
---     messages rather than game events so the client never dispatches them, and tearing them down
---     would leave the page §7 requires to keep working showing a panel list that is no longer
---     true.
---
--- Everything else is a feature and must be gone.
local function isSurvivor(r)
  if r.kind == "event" and r.event == "PLAYER_LOGIN" then return true end
  if r.kind == "message" and r.target == NS.PanelEditor.__evPanels then return true end
  return false
end

--- Every LIVE registration that is not on the survivor list, as sorted `kind|event` strings.
local function featureRegistrations()
  local out = {}
  for _, r in ipairs(mocks.__registrations()) do
    if not isSurvivor(r) then out[#out + 1] = r.kind .. "|" .. tostring(r.event) end
  end
  table.sort(out)
  return out
end

local function survivorRegistrations()
  local out = {}
  for _, r in ipairs(mocks.__registrations()) do
    if isSurvivor(r) then out[#out + 1] = r.kind .. "|" .. tostring(r.event) end
  end
  table.sort(out)
  return out
end

--- A deep, order-independent fingerprint of everything this addon persists. The kit's
--- `M.__svWrites()` reports over the AceDB fake it builds itself, and `tests/wow_mock.lua` replaces
--- that fake wholesale (it models the profile SWAP this addon's profile suites drive), so the
--- survey cannot see these writes. A snapshot diff answers the same question over the tree the
--- addon actually writes -- both roots, because the minimap's stored state lives in `global`.
local function svFingerprint()
  local parts = {}
  local function walk(node, path)
    if type(node) ~= "table" then
      parts[#parts + 1] = path .. "=" .. tostring(node)
      return
    end
    local keys = {}
    for k in pairs(node) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    for _, k in ipairs(keys) do
      local v = rawget(node, k)
      if v == nil then v = node[k] end
      walk(v, path .. "." .. k)
    end
  end
  walk(NS.db.profile, "profile")
  walk(NS.db.global, "global")
  return table.concat(parts, "\n")
end

--- Every panel frame that is currently shown, by panel id.
local function shownPanels()
  local out = {}
  for _, rec in ipairs(R:All()) do
    local f = NS.Canvas:FrameFor(rec.id)
    if f and f:IsShown() then out[#out + 1] = rec.id end
  end
  table.sort(out)
  return out
end

--- Is the shared 10Hz mouseover ticker armed? The driver frame outlives the tracked set but its
--- script does not, so the SCRIPT is the question -- a frame that exists with no OnUpdate on it is
--- not a cost.
local function mouseoverArmed()
  local d = NS.Canvas.__mouseoverDriver
  return d ~= nil and d:GetScript("OnUpdate") ~= nil
end

local function chatSince(n)
  local out = {}
  for i = n + 1, #mocks.__chat do out[#out + 1] = mocks.__chat[i] end
  return out
end

--- Two panels, one of them mouseover-tracked so the ticker is genuinely armed, drawn for real
--- through the event the client draws them on. Leaves the addon enabled and painted.
local function seed()
  S:Set(ENABLED, true)
  R:DeleteAll()
  local a = R:New("StandDown A")
  local b = R:New("StandDown B")
  R:Set(b.id, "mouseover", true)
  -- The REAL entry point, not Canvas:RenderAll() called by hand: it is the event the client draws
  -- these panels on, and driving it through the live registration set is also a check that the
  -- registration is actually there.
  mocks.__fire("PLAYER_ENTERING_WORLD")
  return a.id, b.id
end

local function cleanup()
  S:Set(ENABLED, true)
  R:DeleteAll()
  NS.Canvas:RenderAll()
end

-- ── 1. baseline ────────────────────────────────────────────────────────────────

test("Disabled 1: enabled, the addon registers, draws and arms its ticker", function()
  -- An addon that registers nothing while ENABLED would pass every later assertion trivially, which
  -- is why this case exists and why it asserts the positive of all three surveys.
  seed()

  local R_on = featureRegistrations()
  assertTrue(#R_on > 0, "the addon registers nothing at all when enabled -- every later assertion "
    .. "in this file would pass for the wrong reason")
  assertEqual(table.concat(R_on, ", "),
    "event|PLAYER_ENTERING_WORLD, event|PLAYER_REGEN_DISABLED, event|PLAYER_REGEN_ENABLED, "
    .. "message|Ka0s_PanelMaster_PanelChanged, message|Ka0s_PanelMaster_PanelsChanged, "
    .. "message|Ka0s_PanelMaster_SettingsChanged",
    "the enabled registration set has changed shape; this file's survivor list needs re-reading")
  assertEqual(#shownPanels(), 2, "the two seeded panels are not drawn")
  assertTrue(mouseoverArmed(), "the mouseover ticker is not armed, so step 4 cannot fail")
  cleanup()
end)

-- ── 2 & 3. the registration set ────────────────────────────────────────────────

test("Disabled 3: every registration the addon owns is UNREGISTERED, not gated", function()
  -- THE ASSERTION THIS WHOLE FILE EXISTS FOR. Not "the handler returned early" -- an early return is
  -- what a draw gate does, and a suite written against one certifies the thing it was written to
  -- catch. This reads the live registration set out of the mock.
  --
  -- red under: drop the three UnregisterEvent calls from NS.StandDown (core/LifecycleSetup.lua), or
  -- drop the Canvas:Disable() beside them, and this case fails naming exactly what survived.
  seed()
  -- Through the SINGLE WRITE SEAM -- the route the checkbox and `/pm disable` both take -- never by
  -- calling NS.StandDown directly.
  S:Set(ENABLED, false)

  assertEqual(table.concat(featureRegistrations(), ", "), "",
    "these registrations survived the disabled state: " .. table.concat(featureRegistrations(), ", "))
  -- And the survivor set is EXACTLY the three named ones, by count and by name, so a feature cannot
  -- join the exemption quietly.
  assertEqual(table.concat(survivorRegistrations(), ", "),
    "event|PLAYER_LOGIN, message|Ka0s_PanelMaster_PanelChanged, "
    .. "message|Ka0s_PanelMaster_PanelsChanged",
    "the SETUP survivor set has changed; see isSurvivor at the head of this file")
  cleanup()
end)

-- ── 4. timers ──────────────────────────────────────────────────────────────────

test("Disabled 4: no timer, ticker or OnUpdate is left armed", function()
  -- The coalescing repaint that re-arms ten times a second and then finds nothing to paint is the
  -- most expensive shape §7 exists to kill. This addon's is the shared mouseover driver.
  seed()
  S:Set(ENABLED, false)

  assertFalse(mouseoverArmed(), "the 10Hz mouseover OnUpdate is still armed on a disabled addon")
  assertEqual(next(NS.Canvas.__mouseoverPanels), nil, "panels are still mouseover-tracked")
  assertEqual(#mocks.__timers(), 0, "an AceTimer or C_Timer ticker is still armed")

  -- And nothing re-arms it for the rest of the run: the paths that normally would -- a settings
  -- change and a panel edit -- are exercised while the addon is down.
  S:Set("settings.scale", 1.2)
  local rec = R:All()[1]
  R:Set(rec.id, "mouseover", true)
  assertFalse(mouseoverArmed(), "a write made while disabled re-armed the ticker")
  cleanup()
end)

-- ── 5. frames ──────────────────────────────────────────────────────────────────

test("Disabled 5: every frame that was shown is hidden, and stays hidden", function()
  -- Hidden AT THE SOURCE (modules/Canvas.lua's Render rung), not by an imperative sweep -- so the
  -- things that normally re-show a panel cannot bring it back behind the switch's back.
  seed()
  S:Set(ENABLED, false)
  assertEqual(#shownPanels(), 0, "a panel is still drawn on a disabled addon")

  -- The three paths that re-show a panel in the client: a combat transition, a repaint and a
  -- settings change. None of them is reachable through a registration any more, so each is driven
  -- directly -- which is the stronger claim, not the weaker one.
  NS.addon:OnRegenDisabled()
  NS.addon:OnRegenEnabled()
  NS.Canvas:RenderAll()
  S:Set("settings.visibility", "always")
  assertEqual(#shownPanels(), 0, "a panel came back on a disabled addon")

  -- AND UNDER THE OTHER HOLD, which is the arm the old draw gate could not answer. With
  -- `settings.enabled` left TRUE, the `settings.enabled ~= false` rung in Canvas.BuildSpec says
  -- SHOW -- so the only thing that can hide these frames is the latch rung in Canvas:Render, and
  -- this is the assertion that proves it is there.
  --
  -- red under: delete the `NS.Lifecycle:IsDown()` line from Canvas:Render (modules/Canvas.lua) and
  -- every panel is drawn while the addon is stood down.
  S:Set(ENABLED, true)
  NS.Lifecycle:Hold(NS.HOLD_PERF)
  NS.Canvas:RenderAll()
  assertEqual(#shownPanels(), 0, "a panel is drawn while the addon is stood down for perf")
  assertFalse(mouseoverArmed(), "the ticker is armed while the addon is stood down for perf")
  NS.Lifecycle:Release(NS.HOLD_PERF)
  cleanup()
end)

test("Disabled 5b: an unlocked panel is hidden, stripped and undraggable while stood down (routes A, B, C)",
  function()
    -- Unlock:Decorate shows the frame and arms drag on its own (an unlocked panel is shown whatever
    -- its enabled flag says), so the latch has to decide WHICH of the two overlay calls Render makes,
    -- not only spec.shown. Three routes reach an unlocked panel on a stood-down addon: unlock then
    -- disable (A), unlock via the Lock frame row or `/pm set` while disabled (B), and the per-panel
    -- tick while disabled (C). The session unlock state survives all three, so re-enabling brings
    -- the outlines back from state as it is now.
    --
    -- red under: call NS.Unlock:Decorate unconditionally in Canvas:Render (modules/Canvas.lua)
    local a, b = seed()
    local function assertStoodDown(route)
      assertEqual(#shownPanels(), 0, "route " .. route .. ": a panel is drawn on a disabled addon")
      for _, rec in ipairs(R:All()) do
        assertFalse(NS.Canvas:FrameFor(rec.id):IsMouseEnabled(),
          "route " .. route .. ": panel " .. rec.id .. " takes the mouse on a disabled addon")
      end
    end

    -- Route A: unlock, then disable.
    NS.Unlock:SetUnlocked(true)
    S:Set(ENABLED, false)
    assertStoodDown("A")
    NS.Unlock:SetUnlocked(false)

    -- Route B: disabled, then the Lock frame row, and again through the slash surface.
    S:Set("state.locked", false)
    assertStoodDown("B (schema)")
    NS.Unlock:SetUnlocked(false)
    Sl:OnSlash("set state.locked false")
    assertStoodDown("B (slash)")
    NS.Unlock:SetUnlocked(false)

    -- Route C: disabled, then one panel's own Unlock tick.
    NS.Unlock:SetPanelUnlocked(a, true)
    assertStoodDown("C")

    -- The positive half: the session unlock state was left alone, so re-enabling decorates again.
    NS.Unlock:SetUnlocked(true)
    assertStoodDown("A (re-unlocked while disabled)")
    S:Set(ENABLED, true)
    assertEqual(#shownPanels(), 2, "re-enabling did not bring the unlocked panels back")
    for _, id in ipairs({ a, b }) do
      assertTrue(NS.Canvas:FrameFor(id):IsMouseEnabled(),
        "re-enabling did not re-arm drag on panel " .. id)
    end

    NS.Unlock:SetUnlocked(false)
    cleanup()
  end)

-- ── 6. fire everything anyway ──────────────────────────────────────────────────

test("Disabled 6: firing the events anyway writes nothing, prints nothing, shows nothing", function()
  -- The client will not fire these -- nothing is registered. A SURVIVOR would, so they are fired
  -- anyway, and the addon's own handler METHODS are called directly beside them. That second half is
  -- what stops this case asserting on its own silence: an empty registry dispatches nothing whether
  -- the addon stood down or the harness lost the ability to dispatch at all.
  --
  -- red under: put the registrations back in NS.StandUp's list but not in NS.StandDown's, so the
  -- events stay live -- __fire then reaches a handler and the counts below stop being zero.
  seed()
  local canvasEv = NS.Canvas.__ev
  assertTrue(canvasEv ~= nil, "the renderer was never subscribed, so there is nothing to lose")
  S:Set(ENABLED, false)

  local before = svFingerprint()
  local chatAt = #mocks.__chat

  -- (a) through the live registration set, which is what the client walks.
  local fired = 0
  for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", COMBAT_ENTRY }) do
    fired = fired + mocks.__fire(event)
  end
  assertEqual(fired, 0, "a game event still reached a handler on a disabled addon")

  -- (b) the bus, at the target the renderer used to hold. Nothing answers, because the
  -- subscriptions were unregistered rather than gated.
  assertEqual(mocks.__fireUnconditional(canvasEv, NS.Registry.MSG.PANELS), 0,
    "the renderer's PanelsChanged subscription survived the stand-down")
  assertEqual(mocks.__fireUnconditional(canvasEv, NS.Schema.MSG.SETTINGS), 0,
    "the renderer's SettingsChanged subscription survived the stand-down")

  -- (c) the handler methods themselves, reached past the registration set entirely. Combat entry is
  -- named explicitly: an addon writing to its store or printing a line on entering combat while it
  -- is disabled is §7's purest failure, because the player's evidence that it is off is the absence
  -- of exactly that line.
  NS.addon:OnRegenDisabled()
  NS.addon:OnRegenEnabled()
  NS.addon:OnEnterWorld()

  assertEqual(svFingerprint(), before, "a disabled addon wrote SavedVariables from a game event")
  assertEqual(#chatSince(chatAt), 0, "a disabled addon printed a line from a game event")
  assertEqual(#shownPanels(), 0, "a game event showed a frame on a disabled addon")
  cleanup()
end)

-- ── 7. the slash surface ───────────────────────────────────────────────────────

test("Disabled 7: every reserved verb answers, and only FEATURE verbs are refused", function()
  -- THIS STEP IS NOT THE STAND-DOWN -- steps 1-6 are, and a green step 7 says nothing about whether
  -- the addon is inert. What it pins is the surface standard v2.57.0 RESTORED after v2.56.0 narrowed
  -- it to `enable` and `help`: while disabled every reserved verb answers normally and the bare
  -- `/pm` opens the settings panel, which is the case that settled the reversal. Only the addon's
  -- own feature verbs refuse, which is §2's SHOULD and the choice this addon made.
  seed()
  local rec = R:All()[1]
  S:Set(ENABLED, false)

  local refusal = NS.PREFIX .. " " .. Sl:DisabledLine()

  for _, cmd in ipairs(NS.COMMANDS) do
    local verb = cmd[1]
    local at = #mocks.__chat
    local before = svFingerprint()
    NS.Slash:OnSlash(verb)
    local lines = chatSince(at)
    if Sl.ALWAYS_LIVE[verb] then
      assertFalse(#lines == 1 and lines[1] == refusal,
        "/pm " .. verb .. " was refused, and the standard says it may never be")
    else
      assertEqual(#lines, 1, "/pm " .. verb .. " answered " .. #lines .. " lines; the refusal is "
        .. "exactly one and nothing else")
      assertEqual(lines[1], refusal, "/pm " .. verb .. " did not answer the collection's line")
      assertEqual(svFingerprint(), before, "/pm " .. verb .. " reached a write seam while refused")
    end
  end

  -- The bare command, which is the whole reason v2.56.0 was reversed.
  local opened = mocks.__openedCategory
  mocks.__openedCategory = nil
  NS.Slash:OnSlash("")
  assertTrue(mocks.__openedCategory ~= nil, "a bare /pm did not open the settings panel while "
    .. "disabled -- that is the narrowing standard v2.57.0 reversed")
  mocks.__openedCategory = opened

  -- The schema CLI still READS and REPAIRS, which is precisely when a player needs it most.
  NS.Slash:OnSlash("set settings.gridSize 16")
  assertEqual(S:Get("settings.gridSize"), 16, "/pm set could not repair a setting while disabled")
  NS.Slash:OnSlash("reset settings.gridSize")
  assertEqual(S:Get("settings.gridSize"), 4, "/pm reset could not repair a setting while disabled")

  -- A refused feature verb reached no write seam: the panel it names is untouched.
  assertEqual(R:Get(rec.id).name, "StandDown A", "a refused verb renamed a panel anyway")
  cleanup()
end)

test("Disabled 7b: a reserved verb this addon never registered answers the SAME in both states",
  function()
    -- THE BUG LibKa0s-Slash-1.0 MINOR 14 FIXED, pinned here so it cannot come back. This addon
    -- declines LibKa0s-Perf-1.0 (the ratified `performance-§1` row), so it registers no `perf`
    -- verb at all -- `perf` is reserved always but REGISTERED WHEN WIRED, and an addon that ships
    -- none simply does not have that command. Minor 13 answered it with the refusal line while
    -- disabled and with `unknown command` while enabled: one input, two answers, and the disabled
    -- one told a player the addon had swallowed a command it never had. Nothing was refused, so
    -- nothing says it was.
    --
    -- red under: put the `isDown and liveVerbs[cmd]` branch back above the `entry` lookup in
    -- lib:New's OnSlash, and the disabled answer collapses to one refusal line.
    seed()
    for _, cmd in ipairs(NS.COMMANDS) do
      assertFalse(cmd[1] == "perf", "this addon now ships a `perf` verb, so this case no longer "
        .. "exercises an UNREGISTERED reserved verb -- rewrite it against one that is")
    end
    assertTrue(Sl.ALWAYS_LIVE["perf"], "`perf` is not on the live list, so the gate never saw it")

    local at = #mocks.__chat
    NS.Slash:OnSlash("perf")
    local on = chatSince(at)

    S:Set(ENABLED, false)
    at = #mocks.__chat
    NS.Slash:OnSlash("perf")
    local off = chatSince(at)

    local unknown = NS.PREFIX .. " " .. Sl:Text("UNKNOWN_COMMAND"):format("perf")
    assertEqual(on[1], unknown, "/pm perf did not report an unknown command while ENABLED")
    assertEqual(off[1], unknown, "/pm perf did not report an unknown command while DISABLED")
    assertTrue(#on > 1, "/pm perf printed no help index while enabled, so there is nothing to match")
    assertFalse(#off == 1 and off[1] == NS.PREFIX .. " " .. Sl:DisabledLine(),
      "/pm perf answered the refusal line for a verb this addon never registered")

    -- And the WHOLE answer matches, not just its first line. The only difference the disabled state
    -- is allowed is the library's state note under the help header -- a note above an answer, not a
    -- refusal instead of one -- so the enabled answer with that one line spliced in after the
    -- header IS the disabled answer, row for row.
    local expected = {}
    for i, line in ipairs(on) do
      expected[#expected + 1] = line
      -- [1] is the unknown-command report, [2] is the help header, and the state note sits
      -- immediately under the header and above the rows.
      if i == 2 then expected[#expected + 1] = NS.PREFIX .. " " .. Sl:DisabledLine() end
    end
    assertEqual(table.concat(off, "\n"), table.concat(expected, "\n"),
      "/pm perf answers differently disabled than enabled, which is the bug minor 14 removed")
    cleanup()
  end)

-- ── 8. the launcher ────────────────────────────────────────────────────────────

test("Disabled 8: left-click opens the panel and writes nothing; the menu grays Locked",
  function()
    -- launcher-§2 as of standard v2.67.0 (Launcher minor 4): the left button opens the settings
    -- panel in either state -- the panel is setup, and where the addon is switched back on -- so it
    -- is not refused. The right button opens the options menu, whose Enabled entry stays live while
    -- Locked is grayed; a grayed entry clicked anyway writes nothing (slash-commands-§7).
    seed()
    local Menu = dofile("tests/mock_menu.lua")(mocks)
    local object = NS.Launcher:Object()
    assertTrue(object ~= nil, "there is no broker object to click")
    S:Set(ENABLED, false)

    local before = svFingerprint()
    local at = #mocks.__chat
    mocks.__openedCategory = nil
    object.OnClick(object, "LeftButton")
    assertTrue(mocks.__openedCategory ~= nil, "left-click does not open the settings panel while disabled")

    object.OnClick(object, "RightButton")
    local menu = assert(Menu.last, "right-click opened no options menu while disabled")
    assertTrue(menu:Find("Enabled").enabled, "the Enabled entry is grayed while disabled")
    assertFalse(menu:Find("Locked").enabled, "the Locked entry is live while disabled")
    menu:ForceClick("Locked")
    local lines = chatSince(at)

    assertEqual(svFingerprint(), before,
      "a launcher click wrote SavedVariables on an addon the player switched off")
    assertEqual(#shownPanels(), 0, "a launcher click showed a frame on a disabled addon")
    assertEqual(#lines, 0, "the launcher printed " .. #lines .. " lines while disabled")
    assertFalse(NS.State.unlocked, "a launcher click unlocked the panels anyway")
    cleanup()
  end)

-- ── 9. restoration, from CURRENT state ─────────────────────────────────────────

test("Disabled 9: re-enabling restores the registration set, from state as it is NOW", function()
  -- performance-§6's restore-from-current-state rule, which the latch inherits: standing up rebuilds
  -- from the settings and the registry AS THEY ARE, never from a snapshot taken on the way down.
  seed()
  local R_on = table.concat(featureRegistrations(), ", ")

  S:Set(ENABLED, false)
  assertEqual(table.concat(featureRegistrations(), ", "), "", "the stand-down did not complete")

  S:Set(ENABLED, true)
  assertEqual(table.concat(featureRegistrations(), ", "), R_on,
    "the registration set did not come back the way it went down")

  -- And again, with the world CHANGED while the addon was off. A panel created and a panel
  -- mouseover-ticked while disabled must both be reflected on the way up -- a rebuild from a
  -- snapshot would draw the old set and arm nothing.
  S:Set(ENABLED, false)
  local late = R:New("Created While Off")
  R:Set(late.id, "mouseover", true)
  assertEqual(#shownPanels(), 0, "creating a panel while disabled drew it")
  assertFalse(mouseoverArmed(), "creating a mouseover panel while disabled armed the ticker")

  S:Set(ENABLED, true)
  local shown = shownPanels()
  assertEqual(#shown, 3, "the panel created while the addon was off is not drawn on the way back up")
  assertTrue(mouseoverArmed(), "the ticker was not re-armed from the tracked set as it is NOW")
  cleanup()
end)

test("Disabled 9b: the boot stand-up leaves the painting to PLAYER_ENTERING_WORLD", function()
  -- The other side of step 9, and the reason the gate is `NS.__booted` rather than "have we seen
  -- PLAYER_ENTERING_WORLD". Panels are drawn on that event because UIParent's size is not final at
  -- OnEnable, so the FIRST stand-up of a session must not paint -- but an addon DISABLED at login
  -- never registers that event, so a world-flag gate would still be false when the player ticks the
  -- box an hour later and the stand-up would register everything and draw nothing.
  --
  -- The boot branch is driven by clearing the flag, which is the only way to reach it once OnEnable
  -- has run; the mid-session branch is step 9 above.
  seed()
  S:Set(ENABLED, false)

  local booted = NS.__booted
  NS.__booted = nil
  S:Set(ENABLED, true)
  assertTrue(#featureRegistrations() > 0, "the boot stand-up registered nothing")
  assertEqual(#shownPanels(), 0, "the boot stand-up painted before PLAYER_ENTERING_WORLD")
  NS.__booted = booted

  -- And the event it just registered still does the painting.
  mocks.__fire("PLAYER_ENTERING_WORLD")
  assertEqual(#shownPanels(), 2, "PLAYER_ENTERING_WORLD did not draw after the boot stand-up")
  cleanup()
end)

-- ── 10. the latch ──────────────────────────────────────────────────────────────

test("Disabled 10: releasing one hold does not resurrect an addon the other still holds down",
  function()
    -- The trap the latch exists for, and it is reachable: `/pm disable` is a live verb, so a player
    -- can disable the addon during a suspended perf arm, and `/pm enable` is live too. A resume that
    -- called a bare stand-up would bring the addon back under a player who switched it off.
    --
    -- This addon declines LibKa0s-Perf-1.0 (a ratified `performance-§1` row), so this suite is the
    -- only caller the `perf` hold has -- and the rule is asserted anyway, because the day a perf arm
    -- arrives is not the day to find out which way the branch was written.
    --
    -- red under: replace NS.RefreshEnabled's `Set` + `Reevaluate` with a direct NS.StandUp() call on
    -- the enable path, and the first assertion below goes green-to-red immediately -- the addon
    -- stands up mid-capture.
    seed()
    local LC = NS.Lifecycle

    -- perf first, then disabled.
    LC:Hold(NS.HOLD_PERF)
    assertTrue(LC:IsDown(), "the perf hold did not stand the addon down")
    S:Set(ENABLED, false)
    LC:Release(NS.HOLD_PERF)
    assertTrue(LC:IsDown(), "releasing perf stood up an addon the player had disabled")
    assertEqual(table.concat(featureRegistrations(), ", "), "",
      "releasing perf rebuilt the registrations of a disabled addon")
    assertEqual(table.concat(LC:Holds(), ", "), "disabled", "the hold set is not { disabled }")

    S:Set(ENABLED, true)
    assertFalse(LC:IsDown(), "releasing the last hold did not stand the addon up")
    assertTrue(#featureRegistrations() > 0, "the addon stood up without rebuilding anything")

    -- And the other order: disabled first, then perf.
    S:Set(ENABLED, false)
    LC:Hold(NS.HOLD_PERF)
    S:Set(ENABLED, true)
    assertTrue(LC:IsDown(), "enabling stood up an addon the perf arm was still holding down")
    assertEqual(table.concat(featureRegistrations(), ", "), "",
      "enabling rebuilt the registrations of a perf-suspended addon")
    LC:Release(NS.HOLD_PERF)
    assertFalse(LC:IsDown(), "releasing the last hold did not stand the addon up")
    assertTrue(#featureRegistrations() > 0, "the addon stood up without rebuilding anything")
    cleanup()
  end)

test("Disabled 10b: the hold keys are the library's exported constants, not local literals",
  function()
    -- Two majors and every host in the collection have to spell these the same way. Typed at each
    -- call site there are fourteen spellings, and the day one of them reads "Perf" the perf arm
    -- takes a hold nothing releases.
    local lib = mocks.LibStub("LibKa0s-Lifecycle-1.0", true)
    assertTrue(lib ~= nil, "the Lifecycle major is not loaded")
    assertEqual(NS.HOLD_DISABLED, lib.HOLD_DISABLED, "the disabled hold key is a local literal")
    assertEqual(NS.HOLD_PERF, lib.HOLD_PERF, "the perf hold key is a local literal")
    assertEqual(NS.Lifecycle.name, "PanelMaster", "the latch is not named for the addon folder")
  end)

-- ── the seam itself ────────────────────────────────────────────────────────────

test("Disabled: a profile switch that flips the enable path re-evaluates the latch", function()
  -- Why AceDB's three callbacks are on the survivor list: `settings.enabled` is a stored setting,
  -- and a profile switch can flip it with no checkbox and no verb being touched. A player switching
  -- to a profile where the addon is enabled expects it to come up.
  seed()
  S:Set(ENABLED, false)
  assertTrue(NS.Lifecycle:IsDown(), "the addon is not down")

  -- The profile SWAP the mock models, followed by the callback AceDB fires.
  mocks.__switchProfile("StandDownProfile")
  assertFalse(NS.Lifecycle:IsDown(),
    "switching to a profile where the addon is enabled left it stood down")
  assertTrue(#featureRegistrations() > 0, "the profile switch stood it up without rebuilding")
  cleanup()
end)

test("Disabled: `/pm disable` and the checkbox are one write, and the latch is its only reader",
  function()
    -- The verbs are ALIASES onto `settings.enabled` and hold no state of their own, so the latch has
    -- exactly one input. Driving it from the verb rather than from S:Set is what proves the route
    -- the player actually takes reaches the stand-down.
    seed()
    NS.Slash:OnSlash("disable")
    assertEqual(S:Get(ENABLED), false, "/pm disable did not write the shared path")
    assertTrue(NS.Lifecycle:IsHeld(NS.HOLD_DISABLED), "/pm disable did not take the disabled hold")
    assertEqual(table.concat(featureRegistrations(), ", "), "", "/pm disable did not stand it down")

    NS.Slash:OnSlash("enable")
    assertEqual(S:Get(ENABLED), true, "/pm enable did not write the shared path")
    assertFalse(NS.Lifecycle:IsHeld(NS.HOLD_DISABLED), "/pm enable did not release the hold")
    assertTrue(#featureRegistrations() > 0, "/pm enable did not stand it back up")
    cleanup()
  end)

-- ── Events: a refused name costs only itself (events-frames-taint-§1) ────────────
--
-- Every registration goes through NS.SafeRegisterEvent (core/CoreSetup.lua), which pcalls the one
-- call and appends a refused name to NS.State.rejectedEvents. The kit's `M.__badEvents` makes the
-- client refuse a name; `C_EventUtils.IsEventValid` answers from the same table, so the live arm is
-- front-gated by it, and the second case below removes it so the probe-frame rung decides instead.

local function wipe(t) for i = #t, 1, -1 do t[i] = nil end end

--- The diagnostics report's text (debug-logging-§14), built as data and written nowhere. It is how
--- events-frames-taint-§1's record reaches the player: `/pm diagnostics` prints it.
local function reportText()
  local out = {}
  for i, line in ipairs(NS.DebugLog:BuildDiagnostics().lines) do out[i] = line[2] end
  return table.concat(out, "\n")
end

local function registeredEvents()
  local out = {}
  for _, r in ipairs(mocks.__registrations()) do
    if r.kind == "event" then out[r.event] = true end
  end
  return out
end

--- Two full stand-down/stand-up cycles through the single write seam with PLAYER_REGEN_DISABLED
--- refused, then the assertions the finding asks for. Restores the bad-event table, the list and a
--- clean registration set afterwards, whether the body passed or not.
local function driveRejection(label)
  local rejected = NS.State.rejectedEvents
  assertTrue(type(rejected) == "table", "NS.State.rejectedEvents does not exist")
  wipe(rejected)
  S:Set(ENABLED, true)
  local savedBad = mocks.__badEvents
  mocks.__badEvents = { [COMBAT_ENTRY] = true }
  local ok, err = pcall(function()
    for _ = 1, 2 do
      S:Set(ENABLED, false)
      S:Set(ENABLED, true)
    end
  end)
  mocks.__badEvents = savedBad
  local ev = registeredEvents()
  local list = table.concat(rejected, ",")
  local dump = reportText()
  local hadCanvas = NS.Canvas.__ev ~= nil

  wipe(rejected)
  S:Set(ENABLED, false)
  S:Set(ENABLED, true)

  assertTrue(ok, label .. ": a refused event name raised out of the stand-up: " .. tostring(err))
  assertTrue(ev.PLAYER_ENTERING_WORLD, label .. ": PLAYER_ENTERING_WORLD did not register")
  assertTrue(ev.PLAYER_REGEN_ENABLED, label .. ": PLAYER_REGEN_ENABLED did not register")
  assertTrue(hadCanvas, label .. ": Canvas:Enable never ran after the refused registration")
  assertEqual(list, COMBAT_ENTRY, label .. ": the rejected list is not exactly the refused name, once")
  assertTrue(dump:find("rejected events (1): " .. COMBAT_ENTRY, 1, true) ~= nil,
    label .. ": /pm diagnostics does not report the rejected name")
end

test("Events: a rejected event name is recorded and the rest still register", function()
  -- red under: bare NS.addon:RegisterEvent in NS.StandUp -- the Set raises
  -- 'Attempt to register unknown event "PLAYER_REGEN_DISABLED"' and Canvas:Enable never runs.
  driveRejection("IsEventValid rung")
end)

test("Events: with no C_EventUtils the refused name is still caught and recorded", function()
  -- An older client has no IsEventValid; the probe frame and the target's own pcall decide.
  local saved = mocks.C_EventUtils
  mocks.C_EventUtils = nil
  local ok, err = pcall(driveRejection, "pcall rung")
  mocks.C_EventUtils = saved
  assertTrue(ok, tostring(err))
end)

test("Events: the report says 'rejected events (0)' when nothing was refused", function()
  wipe(NS.State.rejectedEvents)
  local dump = reportText()
  assertTrue(dump:find("rejected events (0): -", 1, true) ~= nil,
    "the diagnostics report has no rejected-events line")
end)

test("Events: the degraded Core stub's SafeRegisterEvent pcalls and records once", function()
  -- No LibKa0s-Core: the one-rung stub in core/CoreSetup.lua is all that stands between a refused
  -- name and a raise out of NS.StandUp.
  local degradedNS = dofile("tests/degraded_env.lua").loadPartial({ Core = true })
  local calls = 0
  local target = {
    RegisterEvent = function(_, event)
      calls = calls + 1
      if event == "BAD_EVENT" then error("Attempt to register unknown event \"BAD_EVENT\"") end
    end,
  }
  local list = {}
  assertTrue(degradedNS.SafeRegisterEvent(target, "GOOD_EVENT", "H", list), "a valid name was refused")
  assertFalse(degradedNS.SafeRegisterEvent(target, "BAD_EVENT", "H", list), "a refused name answered true")
  assertFalse(degradedNS.SafeRegisterEvent(target, "BAD_EVENT", "H", list), "a refused name answered true")
  assertEqual(table.concat(list, ","), "BAD_EVENT", "the stub did not record the refusal exactly once")
  assertEqual(calls, 3, "the stub did not hand every name to the target")
  assertTrue(degradedNS.SafeRegisterEvent(target, "GOOD_EVENT", "H", nil), "a nil list broke the stub")
end)
