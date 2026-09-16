local _, NS = ...

-- Account-wide defaults. The persisted-DB version stamp is what this scope is FOR: everything the
-- user configures is profile-scoped (defaults/Profile.lua), but the schema shape is a property of
-- the BUILD, not of a profile, so a migration must run once per SavedVariables file rather than once
-- per profile.
--
-- `schemaVersion` IS DELIBERATELY NOT SEEDED HERE (savedvariables-§1).
--
-- An AceDB default is served for any key the SavedVariables file does not carry, so seeding the
-- stamp with NS.SCHEMA_VERSION made `db.global.schemaVersion` read as CURRENT on every account that
-- had never been stamped — which is every account, because the runner only writes the field from
-- inside its own `<` gate. The gate could therefore never open, and every migration body behind it
-- (core/Database.lua's v1 -> v2 frame-name stamp) was unreachable for every real install: an
-- upgrading v1 profile was silently declared current and never repaired.
--
-- Absent, the field reads nil, NS:RunMigrations floors it to 1, the gate opens, the bodies run and
-- the runner writes the real stamp into the SavedVariables file — after which the run is idempotent
-- for the same reason it always was. A genuinely fresh install pays one pass over an empty registry,
-- which touches zero rows.
--
-- ── THE MINIMAP TABLE IS LibDBIcon'S OWN, AND IT LIVES HERE ────────────────────
--
-- `minimap` below is not a settings table of this addon's design: it is the table LibDBIcon-1.0
-- itself reads and writes, handed to it whole by core/LauncherSetup.lua. The library writes `hide`
-- when the player uses its own right-click menu and `minimapPos` when they drag the button, so a
-- second key of ours beside `hide` would be a copy of one state that is free to disagree the first
-- time either surface is used (launcher-§3, anti-pattern #81).
--
-- GLOBAL RATHER THAN PROFILE, and that is the decision rather than an accident of where the other
-- rows live. A minimap button belongs to the INSTALLATION: switching profiles is how a player
-- changes what this addon DRAWS, while the ring of buttons around the minimap is furniture they
-- arranged once, and profile-scoped it would appear and vanish on a switch made for an unrelated
-- reason. It also keeps options-ui-§12's *Reset all settings* -- a PROFILE reset by definition
-- (settings/Slash.lua's Sl:DoResetAll) -- from un-hiding a button the player deliberately hid.
--
-- `hide = false` is DECLARED, not written. That is what materializes the table for the closure in
-- core/LauncherSetup.lua to answer with, and declaring it here rather than seeding it at runtime is
-- what architecture-§5 asks of a path a schema row addresses -- the *Minimap button* row addresses
-- exactly this key, inverted. `minimapPos` is deliberately absent: it is LibDBIcon's to write and
-- it has no row, so a declared default would only be this addon guessing an angle.
NS.defaults = NS.defaults or {}
NS.defaults.global = {
  minimap = { hide = false },
}
