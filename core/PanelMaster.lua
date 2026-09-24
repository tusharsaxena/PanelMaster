local addonName, NS = ...

local AceAddon = LibStub("AceAddon-3.0")
local addon = AceAddon:NewAddon(NS, addonName, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")
NS.addon = addon
NS.bus = addon   -- closed message bus: SendMessage / RegisterMessage (architecture-§4)

-- Reclaim NS.Print from AceConsole. NewAddon(NS, …, "AceConsole-3.0") embeds AceConsole's mixins
-- directly onto NS, and its :Print method OVERWRITES the secret-safe, cyan-[PM]-prefixed NS.Print
-- built by core/CoreSetup.lua (the LibKa0s-Core printer) — after which every `local print =
-- NS.Print` call site would render AceConsole's green "|cff33ff99<msg>|r:" form (no tag, trailing
-- colon) and lose secret-safety. The embed never touches NS.Util.print, so restore the real printer
-- from it (architecture-§2).
if NS.Util and NS.Util.print then NS.Print = NS.Util.print end

-- Bus-receiver factory. A module that CONSUMES Ka0s_PanelMaster_* messages must register on its OWN
-- AceEvent target, never on the shared bus-as-self: CallbackHandler keys callbacks by
-- (message, target), so two consumers that share a target silently clobber each other — only the
-- last registrant of a given message ever receives it. Each call returns a fresh AceEvent-embedded
-- table (nil if AceEvent is unavailable); SendMessage on NS.bus still fans out to every target.
function NS.NewBusTarget()
  local AceEvent = LibStub and LibStub("AceEvent-3.0", true)
  if not AceEvent then return nil end
  local t = {}
  AceEvent:Embed(t)
  return t
end

function addon:OnInitialize()
  -- Contribute the addon's own media before anything reads a texture name, so the shipped default
  -- ("Solid") resolves on the very first render rather than falling back for one frame.
  NS.Compat.RegisterMedia()
  NS:InitDB()
  if NS.Schema and NS.Schema.Register then NS.Schema:Register() end
  if NS.Slash and NS.Slash.Register then NS.Slash:Register() end
  -- The launcher (launcher-§1), AFTER NS:InitDB() above and for one reason: the descriptor's
  -- `minimap` closure answers `db.global.minimap`, and LibDBIcon is handed that table HERE, at
  -- Register time, so it has to exist by now. Idempotent by the library's own design, so a second
  -- call from anywhere cannot build a second button over the first.
  if NS.Launcher then NS.Launcher:Register() end
  -- Eager settings-category registration (options-ui-§1): the entry is present in the Blizzard
  -- options list from load, even though each panel BODY is built lazily on its first OnShow.
  if NS.Panel and NS.Panel.Register then NS.Panel:Register() end

  -- A SECOND eager attempt at the same registration, not a deferral. P:Register's guard returns
  -- without setting `registered` when Settings or AceGUI are not there yet, and nothing used to try
  -- again — so a load order that lost that race left the addon absent from Blizzard's options list
  -- for the whole session, with `/pm config` doing nothing and saying nothing. Register is
  -- idempotent, so on a normal login (where the call above succeeded) this costs one table lookup.
  --
  -- Subscribed HERE and not from OnEnable, which is the only placement that can be delivered:
  -- AceAddon runs OnEnable from inside its own PLAYER_LOGIN handler, and a frame that subscribes to
  -- an event mid-dispatch does not receive that firing — for a non-LoD addon there is no second one.
  -- OnInitialize runs at ADDON_LOADED, strictly before PLAYER_LOGIN. Registering from a
  -- PLAYER_LOGIN bootstrap is exactly what options-ui-§1 sanctions; waiting for the user's first
  -- /pm config is what anti-pattern #22 forbids.
  --
  -- IT IS SETUP, SO IT SURVIVES THE DISABLED STATE (slash-commands-§7's own survivor list). This
  -- registration is the settings-category registration's deferred half and nothing else -- it
  -- registers a page and reads nothing about panels -- so NS.StandDown leaves it alone. Standing it
  -- down would be the addon deciding, while it is off, to make the one surface a player uses to
  -- switch it back on unreachable on the load order that lost the race. It is one of exactly three
  -- registrations tests/test_disabled.lua names as the survivor set; a fourth fails that suite.
  --
  -- Pcalled through Core like every other registration (events-frames-taint-§1): a refusal lands in
  -- NS.State.rejectedEvents, which /pm debug dump prints, instead of raising out of OnInitialize.
  NS.SafeRegisterEvent(self, "PLAYER_LOGIN", function()
    if NS.Panel and NS.Panel.Register then NS.Panel:Register() end
  end, NS.State.rejectedEvents)
end

function addon:OnEnable()
  -- Discover user-installed Sunn - Viewport Art packs and add them to the artwork catalog. Here in
  -- OnEnable rather than at file scope because a pack addon is a SEPARATE addon: its Lua has not
  -- necessarily run when modules/SunnArt.lua loads, and the globals it leaves behind are only
  -- guaranteed to exist once every addon has loaded. Adds nothing when no pack is installed.
  --
  -- Above the latch and outside the stand-down on purpose: it mutates an in-memory CATALOG, takes no
  -- registration, arms no timer and draws nothing, so there is nothing here for a stand-down to
  -- reclaim. What reads the catalog is the renderer, and the renderer is what stands down.
  if NS.SunnArt and NS.SunnArt.Inject then NS.SunnArt.Inject() end

  -- THE LATCH, and this is where the addon's features are wired up or not wired up at all
  -- (slash-commands-§7). Everything OnEnable used to do here -- Canvas:Enable and the three event
  -- registrations -- moved into NS.StandUp, because a disabled addon must not register them in the
  -- first place. Registering and then tearing down one frame later would be the draw gate with extra
  -- steps: the addon would still have watched, however briefly.
  --
  -- `Set` then the explicit first stand-up, rather than Reevaluate: the latch starts UP with an
  -- empty hold set and has never fired a callback, so there is no edge for Reevaluate to find. This
  -- is the one moment a host has to say "and if nothing is holding you down, come up".
  NS.Lifecycle:Set(NS.HOLD_DISABLED, not NS.IsAddonEnabled())
  if not NS.Lifecycle:IsDown() then NS.StandUp() end
  -- LAST, and after that stand-up rather than before it. It is what tells NS.StandUp that the boot
  -- one is over: from here on a stand-up repaints immediately, because there is no
  -- PLAYER_ENTERING_WORLD still to come. See NS.StandUp's own note for why it is not "have we seen
  -- that event" -- an addon disabled at login never registers it.
  NS.__booted = true

  -- No [Init] line here: the debug flag is session-only and off at login, so a boot-time summary
  -- would always be gated off and never render. It rides the DebugLog:SetEnabled seam instead,
  -- emitted when capture is actually enabled (debug-logging-§5/§8).
end

-- Panels are drawn on PLAYER_ENTERING_WORLD rather than at OnEnable. Every panel is anchored to
-- UIParent (modules/Canvas.lua), and UIParent's final size and the frame anchors are settled by this
-- event, not at OnEnable — painting earlier would lay panels out against a screen still changing
-- under them. (Off-screen recovery never runs here: it is on demand only, `/pm recover`.)
--
-- Registered by NS.StandUp and unregistered by NS.StandDown, so a disabled addon does not watch for
-- it at all (slash-commands-§7).
function addon:OnEnterWorld()
  if NS.Canvas and NS.Canvas.RenderAll then NS.Canvas:RenderAll() end
end

-- Panels are non-secure frames, so nothing here is combat-gated (standalone-windows) — but the
-- UNLOCK overlay deliberately is: it makes panels mouse-interactive, and handing the user draggable
-- frames mid-pull is a UX hazard rather than a taint one. Unlock refuses during combat and is
-- replayed here, which is the events-frames-taint-§2 deferred-write shape (and NOT the options-panel
-- case, which refuses outright and never replays — options-ui-§2).
--
-- The pending unlock is resumed FIRST, then the combat repaint runs with `false` passed explicitly:
-- the event is the truth of the transition, so the render does not re-ask a combat API about it.
function addon:OnRegenEnabled()
  if NS.Unlock and NS.Unlock.ResumePending then NS.Unlock:ResumePending() end
  if NS.Canvas and NS.Canvas.RenderForCombat then NS.Canvas:RenderForCombat(false) end
end

-- Leaving combat has a second job above; entering it has only this one. Both go through
-- RenderForCombat, which repaints only when the general-visibility setting is one of the two that
-- actually depend on the combat state — so the overwhelmingly common "Always" costs one table read
-- per pull rather than a repaint of every panel.
--
-- `true` is passed EXPLICITLY because PLAYER_REGEN_DISABLED fires before lockdown begins and before
-- the combat flag can be relied on, so a render that re-read the state here drew the out-of-combat
-- look for the whole fight (events-frames-taint-§2: transitions ride the REGEN events).
function addon:OnRegenDisabled()
  if NS.Canvas and NS.Canvas.RenderForCombat then NS.Canvas:RenderForCombat(true) end
end
