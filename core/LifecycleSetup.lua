local addonName, NS = ...

-- LibKa0s-Lifecycle-1.0 seam: the STAND-DOWN LATCH (slash-commands-§7).
--
-- ── WHAT "DISABLED" MEANS HERE NOW ──────────────────────────────────────────────
--
-- Disabled means the addon is NOT RUNNING. Not hidden, not quiet, not skipping a repaint. Until
-- standard v2.55.0 this addon -- like all eleven in the collection -- implemented it as a DRAW
-- GATE: `settings.enabled ~= false` was one rung of modules/Canvas.lua's show ladder and one
-- condition on the slash verbs, and NOTHING else changed. Every message subscription stayed
-- registered, PLAYER_ENTERING_WORLD and both combat events stayed registered, and the 10Hz
-- mouseover OnUpdate kept ticking over a set of panels nobody could see. The addon had stopped
-- REACTING; it had not stopped WATCHING, and it went on paying the dispatch on every one of those
-- events. That cost is exactly what a player switching an addon off is trying to stop paying, and
-- it is invisible from every surface they can see -- which is how the draw gate survived five
-- audits of this repo.
--
-- ── ONE LATCH, TWO NAMED HOLDS, AND NO SECOND TEARDOWN PATH ─────────────────────
--
-- The addon is stood down whenever AT LEAST ONE hold is taken and stood back up only when the LAST
-- one is released. `disabled` is taken from the stored enable path; `perf` is the hold
-- LibKa0s-Perf-1.0's suspended arm takes. This addon declines `Perf` (docs/performance.md, and the
-- `performance-§1` row in docs/ARCHITECTURE.md's `## Documented deviations`), so nothing takes the
-- `perf` hold here today -- and the latch is still the right shape, because the reason it exists is
-- that RELEASING ONE HOLD MUST NOT RESURRECT AN ADDON THE OTHER IS STILL HOLDING DOWN. A boolean
-- cannot express that, a second teardown path beside the first is the parallel-lifecycle
-- anti-pattern (#85), and both failures arrive on the day the second hold does rather than on the
-- day it is written.
--
-- There is no `:StandUp()` on the library and that absence is deliberate: the only route out is
-- releasing the hold that put the addon down.
--
-- ── WHAT STANDS DOWN, AND WHAT SURVIVES ─────────────────────────────────────────
--
-- Stands down (NS.StandDown below): the renderer's three bus subscriptions, the three game events
-- core/PanelMaster.lua registers, the shared 10Hz mouseover OnUpdate, and every panel frame -- the
-- last one AT THE SOURCE, through the rung modules/Canvas.lua:Render consults, never by an
-- imperative sweep of Hide(). A hidden frame comes back: a combat transition, a profile switch or a
-- settings change re-renders it, and an addon that hides imperatively is visibly running again
-- while it still claims to be off.
--
-- Survives, because it is SETUP and not a feature (slash-commands-§7's own list):
--   * the chat command registration, the dispatcher and NS.COMMANDS (settings/Slash.lua);
--   * the settings-category registration and the panel body (settings/Panel.lua) -- INCLUDING the
--     PLAYER_LOGIN bootstrap in core/PanelMaster.lua, which is that registration's deferred half
--     and nothing else (options-ui-§1 sanctions it by name), and INCLUDING the Panels page's own
--     two bus subscriptions (settings/PanelEditor.lua), which exist only to keep the OPEN page in
--     step with the store. Both are named in tests/test_disabled.lua as the whole survivor set, so
--     a third one cannot arrive unremarked;
--   * the AceDB handle, NS.Schema:Set and AceDB's three profile callbacks (core/Database.lua) --
--     a profile switch can flip the enable path with nothing else being touched, so the addon MUST
--     be able to re-evaluate the latch there;
--   * the launcher's registration (core/LauncherSetup.lua). The button stays on the minimap; what
--     its LEFT click does changes, and that gate is in that file.
--
-- ── NO SECURE WORK, SO NO PENDING COMPLETION ────────────────────────────────────
--
-- slash-commands-§7 permits a disabled addon exactly one kept registration: a PLAYER_REGEN_ENABLED
-- held so that secure-attribute and state-driver work refused under combat lockdown can finish the
-- moment the lockdown lifts. THIS ADDON HAS NONE TO HOLD. Every frame it draws is a plain,
-- non-secure `CreateFrame("Frame")` backdrop: it calls no SetAttribute, registers no state or
-- attribute driver, and installs no secure hook anywhere in core/, modules/ or settings/. So the
-- stand-down completes in the same turn as the write in every case, PLAYER_REGEN_ENABLED goes with
-- the rest, and this addon never exercises the carve-out. The unlock module's own combat deferral
-- (modules/Unlock.lua) is a UX rule about handing the player draggable frames mid-pull, not a taint
-- rule, and it has nothing to defer while the addon is down.

local Lifecycle = LibStub and LibStub("LibKa0s-Lifecycle-1.0", true)

-- The three game events NS.StandUp registers, as { event, handler method } in registration order.
-- NS.StandDown unregisters the same three by name.
local STAND_UP_EVENTS = {
  { "PLAYER_ENTERING_WORLD", "OnEnterWorld" },
  { "PLAYER_REGEN_ENABLED",  "OnRegenEnabled" },
  { "PLAYER_REGEN_DISABLED", "OnRegenDisabled" },
}

--- Is the addon's own master switch ON? Read from the SCHEMA, never from a flag of this file's
--- own: `settings.enabled` is the one path the *Enable Ka0s Panel Master* checkbox, `/pm enable`
--- and `/pm disable` all write (slash-commands-§2), and a second copy here would answer the player
--- differently from the row they just ticked. Guarded on NS.db because the latch is asked at load,
--- and on a client that failed to build the DB at all `S:Get` would index a nil profile.
---
--- Absent a value -- a fresh profile before the composed row's default has landed -- it answers
--- ENABLED, which is what `defaults/Profile.lua` ships and the only answer that cannot leave a
--- first-run player looking at a blank screen.
function NS.IsAddonEnabled()
  if not (NS.db and NS.Schema) then return true end
  return NS.Schema:Get(NS.Schema.ENABLED_PATH) ~= false
end

--- Tear the addon's FEATURES down. Called by the latch on the empty -> non-empty edge, and never
--- directly: a caller that reaches past the latch is the bare stand-up/stand-down the latch exists
--- to make unreachable.
---
--- ORDER MATTERS. RenderAll runs FIRST, while the frames are still reachable, so the show ladder's
--- stand-down rung hides every one of them and `Canvas.SetMouseoverTracked` drops each from the
--- mouseover set -- which is what takes the shared OnUpdate script off the driver frame. Only then
--- does the bus subscription go, because a RenderAll after the teardown would be a render nothing
--- asked for.
function NS.StandDown()
  if NS.Canvas then
    NS.Canvas:RenderAll()
    NS.Canvas:Disable()
  end
  if NS.addon and NS.addon.UnregisterEvent then
    NS.addon:UnregisterEvent("PLAYER_ENTERING_WORLD")
    NS.addon:UnregisterEvent("PLAYER_REGEN_ENABLED")
    NS.addon:UnregisterEvent("PLAYER_REGEN_DISABLED")
  end
  NS.Debug("Lifecycle", "stood down (%s)", table.concat(NS.Lifecycle:Holds(), ", "))
end

--- Build the addon's features back, FROM CURRENT STATE and never from a snapshot taken on the way
--- down (performance-§6). Nothing here reads a saved registration list: it re-registers the same
--- three events core/PanelMaster.lua's OnEnable registers, re-subscribes the renderer, and repaints
--- from the registry and the settings AS THEY ARE NOW -- so a panel created, a setting changed or a
--- profile switched while the addon was off comes back correct rather than stale.
---
--- THE REPAINT IS GATED ON THE BOOT STAND-UP, which is not a micro-optimization: panels are drawn on
--- PLAYER_ENTERING_WORLD rather than at OnEnable because UIParent's final size and the frame
--- anchors every panel hangs from are settled by that event and not that early. The FIRST stand-up
--- of a session runs from inside `addon:OnEnable` and must leave the painting to that event; every later
--- one runs long after it and must paint immediately, or a player who re-enables mid-session looks
--- at a blank screen until the next zone change.
---
--- The flag is `NS.__booted`, set at the END of OnEnable, and NOT "have we seen
--- PLAYER_ENTERING_WORLD" -- which was the first shape and is wrong in exactly the case that
--- matters. An addon DISABLED at login never registers that event, so the world flag would still be
--- false when the player ticks the box an hour later, and the stand-up would register everything and
--- paint nothing. What the gate actually needs to know is "are we still inside OnEnable", and that
--- is a question about the addon's own boot rather than about the client's.
function NS.StandUp()
  if NS.addon and NS.addon.RegisterEvent then
    -- Through Core's pcalled helper (events-frames-taint-§1): a name the client refuses is recorded
    -- in NS.State.rejectedEvents, which /pm debug dump prints, and costs only itself -- the other
    -- registrations, Canvas:Enable and the repaint below still happen.
    for _, reg in ipairs(STAND_UP_EVENTS) do
      if not NS.SafeRegisterEvent(NS.addon, reg[1], reg[2], NS.State.rejectedEvents) then
        NS.Debug("Events", "rejected %s", reg[1])
      end
    end
  end
  if NS.Canvas then
    NS.Canvas:Enable()
    if NS.__booted then NS.Canvas:RenderAll() end
  end
  NS.Debug("Lifecycle", "stood up")
end

--- The one entry point every surface that can change the answer calls: the composed *Enable Ka0s
--- Panel Master* row's onChange, `/pm enable`, `/pm disable` (which are that row's write by another
--- name), and the three AceDB profile callbacks. Written once, in the library's shape, rather than
--- as a branch each caller writes for itself -- a branch written four times is a branch one caller
--- writes backwards.
---
--- `Reevaluate` after `Set` is what the profile callbacks need and what costs the other callers
--- nothing: it is idempotent and fires a callback only on an actual edge, so a profile switch that
--- agrees with the outgoing one is silent.
---
--- Defined ABOVE the degradation branch, which returns early: it reads `NS.Lifecycle` at call time,
--- so it serves the stub latch and the library's alike. Below the branch it did not exist on a
--- Lifecycle-less load, where the profile callbacks call it and Sl:CliEnable's write-through
--- route needs it to move the latch (PM-09).
function NS.RefreshEnabled()
  NS.Lifecycle:Set(NS.HOLD_DISABLED, not NS.IsAddonEnabled())
  NS.Lifecycle:Reevaluate()
end

if not Lifecycle then
  -- Degrade, never error -- and here the stub does the job rather than answering false, which is
  -- the opposite of what core/LauncherSetup.lua's stub does and is the right call for the opposite
  -- reason. A launcher stub that does nothing costs a button nobody can click; a LATCH stub that
  -- does nothing costs the stand-down itself, so a player who switched the addon off on a client
  -- with no LibKa0s payload would get the draw gate back and no surface would say so. The hold set
  -- is six lines and the edge rule is one comparison, so the honest degradation is to keep them.
  --
  -- It is NOT a second lifecycle mechanism (anti-pattern #85): it is the same one latch, on the arm
  -- where the library that owns it is absent, and tests/test_surface_parity.lua compares the two
  -- member sets so it cannot drift into being a different thing.
  local holds, taken, down = {}, 0, false
  local LC = { name = addonName }
  local function edge()
    local wanted = taken > 0
    if wanted == down then return false end
    down = wanted
    if wanted then NS.StandDown() else NS.StandUp() end
    return true
  end
  -- Written in the DOT form with a discarded receiver rather than the colon form, so every member
  -- still answers a colon call from the host while luacheck sees no unused `self`. Nothing here
  -- reads the instance: the hold set is the upvalue above, because there is exactly one latch.
  LC.Hold = function(_, key)
    if holds[key] then return false end
    holds[key], taken = true, taken + 1
    return edge()
  end
  LC.Release = function(_, key)
    if not holds[key] then return false end
    holds[key], taken = nil, taken - 1
    return edge()
  end
  LC.Set = function(self, key, held)
    if held then return self:Hold(key) end
    return self:Release(key)
  end
  LC.IsHeld = function(_, key) return holds[key] == true end
  LC.IsDown = function() return taken > 0 end
  LC.Holds = function()
    local out = {}
    for key in pairs(holds) do out[#out + 1] = key end
    table.sort(out)
    return out
  end
  LC.Reevaluate = function() return edge() end
  LC.PrintHolds = function() return false end

  NS.Lifecycle = LC
  -- The two reserved keys, spelled here because the library that exports them is absent. They are
  -- the collection's, not this addon's: LibKa0s-Perf-1.0 and every host have to spell them the same
  -- way or a hold is taken that nothing releases.
  NS.HOLD_DISABLED, NS.HOLD_PERF = "disabled", "perf"
  return
end

NS.HOLD_DISABLED, NS.HOLD_PERF = Lifecycle.HOLD_DISABLED, Lifecycle.HOLD_PERF

NS.Lifecycle = Lifecycle:New({
  -- The FOLDER name. Diagnostic only -- nothing in the library branches on it -- and `addonName` is
  -- the first vararg every TOC-loaded file gets, so it cannot go stale the day the folder is
  -- renamed.
  name      = addonName,
  standDown = function() NS.StandDown() end,
  standUp   = function() NS.StandUp() end,
  -- Used by :PrintHolds() and by nothing else. The library emits no line of its own: a latch that
  -- narrated every edge would print into a player's chat on every profile switch.
  print     = function(line) NS.Print(line) end,
})
