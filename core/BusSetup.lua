local _, NS = ...

-- core/BusSetup.lua — wires the addon into LibKa0s-Bus-1.0 (architecture-§4, library-stack-§7).
--
-- ── WHAT IS ADOPTED, AND WHAT IS NOT ────────────────────────────────────────────
--
-- `Catalog` ONLY. modules/Registry.lua and settings/Schema.lua each declare their bus messages
-- through `NS.BusLib.Catalog(addonName, { KEY = "Ka0s_PanelMaster_<Event>" })`, which validates the
-- declaration at load (SCREAMING_SNAKE keys, the `Ka0s_<Addon>_` prefix, a PascalCase event, one
-- key per wire name) and hands back a STRICT copy: reading an undeclared key raises at the read.
-- That closes the hole a plain constant table leaves open — a subscriber's mistyped name raises
-- inside CallbackHandler, but a publisher's `SendMessage(nil)` returns quietly.
--
-- The record half — `Bus:New` and its tracked targets — is NOT offered here. NS.NewBusTarget in
-- core/PanelMaster.lua stays this addon's receiver factory, and tests/test_surface_parity.lua names
-- `New` in its ignore set for that reason.
--
-- ── WHY THE POSITION IS LOAD-BEARING ────────────────────────────────────────────
--
-- Both catalogs are built at FILE LOAD, so this file must load before modules/Registry.lua and
-- settings/Schema.lua. It needs nothing but LibStub, so nothing else constrains where it sits.
--
-- ── WITH NO LIBRARY ─────────────────────────────────────────────────────────────
--
-- `Catalog` is dot-called and answers the host's own table unchanged: the same wire names, so the
-- bus still works, and only the strictness is lost (a mistyped key reads nil).

local lib = LibStub and LibStub("LibKa0s-Bus-1.0", true)
if not lib then
  NS.BusLib = { Catalog = function(_, messages) return messages end }
  return
end
NS.BusLib = lib
