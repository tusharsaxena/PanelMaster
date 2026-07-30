local addonName, NS = ...   -- luacheck: ignore addonName

-- Account-wide defaults. Only the persisted-DB version stamp lives here: everything the user
-- configures is per-character (defaults/Profile.lua), but the schema shape is a property of the
-- BUILD, not of a character, so a migration must run once per SavedVariables file rather than once
-- per profile.
NS.defaults = NS.defaults or {}
NS.defaults.global = {
  -- 0.1.0 ships schema v1. NS:RunMigrations (core/Database.lua) reads/writes this field once at
  -- init — the idempotent seam future schema changes hook into (savedvariables-§1). Taken from
  -- NS.SCHEMA_VERSION so the shipped default and the runner's target cannot drift apart; a fresh
  -- install starts at the current shape instead of replaying a migration over an empty registry.
  schemaVersion = NS.SCHEMA_VERSION,
}
