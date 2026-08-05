local addonName, NS = ...   -- luacheck: ignore addonName

-- Account-wide defaults. The persisted-DB version stamp is what this scope is FOR: everything the
-- user configures is per-character (defaults/Profile.lua), but the schema shape is a property of the
-- BUILD, not of a character, so a migration must run once per SavedVariables file rather than once
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
NS.defaults = NS.defaults or {}
NS.defaults.global = {}
