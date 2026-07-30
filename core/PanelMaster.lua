local addonName, NS = ...

local AceAddon = LibStub("AceAddon-3.0")
local addon = AceAddon:NewAddon(NS, addonName, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")
NS.addon = addon
NS.bus = addon   -- closed message bus: SendMessage / RegisterMessage (architecture-§4)

-- Reclaim NS.Print from AceConsole. NewAddon(NS, …, "AceConsole-3.0") embeds AceConsole's mixins
-- directly onto NS, and its :Print method OVERWRITES the secret-safe, cyan-[PM]-prefixed NS.Print
-- defined in core/Util.lua — after which every `local print = NS.Print` call site would render
-- AceConsole's green "|cff33ff99<msg>|r:" form (no tag, trailing colon) and lose secret-safety. The
-- embed never touches NS.Util.print, so restore the real printer from it (architecture-§2).
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
  -- Eager settings-category registration (options-ui-§1): the entry is present in the Blizzard
  -- options list from load, even though each panel BODY is built lazily on its first OnShow.
  if NS.Panel and NS.Panel.Register then NS.Panel:Register() end
end

function addon:OnEnable()
  -- Subscribe the renderer to the message bus. Without this NOTHING is live: every settings change
  -- and every panel edit broadcasts into a bus with no listener, and the only things that repaint
  -- are the two paths that call Canvas:RenderAll() directly (lock/unlock and test mode). That was
  -- the shape of the bug — panels appeared frozen until test mode was toggled.
  if NS.Canvas and NS.Canvas.Enable then NS.Canvas:Enable() end

  -- Panels are drawn on PLAYER_ENTERING_WORLD rather than here. UIParent's size is what the
  -- registry's off-screen recovery measures against, and it is not final at OnEnable — reading it
  -- too early would judge every stored position against the wrong screen.
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnterWorld")
  self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
  -- No [Init] line here: the debug flag is session-only and off at login, so a boot-time summary
  -- would always be gated off and never render. It rides the DebugLog:SetEnabled seam instead,
  -- emitted when capture is actually enabled (debug-logging-§5/§8).
end

function addon:OnEnterWorld()
  if NS.Canvas and NS.Canvas.RenderAll then NS.Canvas:RenderAll() end
end

-- Panels are non-secure frames, so nothing here is combat-gated (standalone-windows) — but the
-- UNLOCK overlay deliberately is: it makes panels mouse-interactive, and handing the user draggable
-- frames mid-pull is a UX hazard rather than a taint one. Unlock refuses during combat and is
-- replayed here, which is the events-frames-taint-§2 deferred-write shape (and NOT the options-panel
-- case, which refuses outright and never replays — options-ui-§2).
function addon:OnRegenEnabled()
  if NS.Unlock and NS.Unlock.ResumePending then NS.Unlock:ResumePending() end
end
