local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

test("Database: InitDB opened both scopes", function()
  assertTrue(type(NS.db.global) == "table")
  assertTrue(type(NS.db.profile) == "table")
end)

test("Database: a fresh install ships the current schema version", function()
  -- The shipped default and the migration runner's target both read NS.SCHEMA_VERSION, so a fresh
  -- install must start AT the current shape rather than replaying a migration over an empty
  -- registry.
  assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
  assertEqual(NS.defaults.global.schemaVersion, NS.SCHEMA_VERSION)
end)

test("Database: the panel registry is per-profile, not global", function()
  -- Per PROFILE, so the Profiles page can give a character its own layout. Storing it in `global`
  -- would put it outside the profile system entirely and make that impossible.
  assertTrue(NS.db.profile.panels ~= nil)
  assertEqual(NS.db.global.panels, nil)
end)

test("Database: every character starts on the shared 'Default' profile", function()
  -- The `true` third argument to AceDB:New, which AceDB maps to the profile named "Default".
  -- Without it each character would be handed a private profile keyed on its own name, and anyone
  -- running one UI across their alts would have to rebuild or copy it on every single one.
  assertEqual(T.mocks.__dbDefaultProfile, true,
    "AceDB was not asked for the shared Default profile")
  assertEqual(NS.db:GetCurrentProfile(), "Default")
end)

test("Database: a fresh profile ships no panels", function()
  -- An addon whose job is putting opaque blocks on screen must never put one there uninvited.
  assertEqual(#NS.defaults.profile.panels, 0)
end)

test("Database: the debug flag is NOT persisted (debug-logging-§5)", function()
  assertEqual(NS.defaults.profile.debug, nil)
  assertEqual(NS.defaults.profile.settings.debug, nil)
  assertEqual(NS.defaults.global.debug, nil)
end)

test("Database: unlock state is NOT persisted", function()
  -- Unlock is an editing state, not a preference: persisting it means logging in to a screen full
  -- of drag handles.
  assertEqual(NS.defaults.profile.settings.unlocked, nil)
  assertEqual(NS.defaults.profile.unlocked, nil)
end)

test("Database.RunMigrations: is idempotent", function()
  local before = NS.db.global.schemaVersion
  NS:RunMigrations()
  NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, before)
end)

test("Database.RunMigrations: stamps a version onto an unstamped DB", function()
  local saved = NS.db.global.schemaVersion
  NS.db.global.schemaVersion = nil
  NS:RunMigrations()
  assertTrue(NS.db.global.schemaVersion ~= nil, "an unstamped DB was left unstamped")
  NS.db.global.schemaVersion = saved
end)

test("Database.RunMigrations: upgrades an older DB to the current version", function()
  local saved = NS.db.global.schemaVersion
  NS.db.global.schemaVersion = 0
  NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
  NS.db.global.schemaVersion = saved
end)

test("Database.RunMigrations: survives being called before the DB exists", function()
  local saved = NS.db
  NS.db = nil
  NS:RunMigrations()   -- must not error
  NS.db = saved
end)

test("Database.MigrationSummary: is a pure, readable line", function()
  assertEqual(NS.MigrationSummary(1, 2, 4), "v1 -> v2, 4 panels touched")
end)

test("Database.InitSummary: names the addon, version, schema, profile and count", function()
  NS.Registry:DeleteAll()
  NS.Registry:New("One")
  local s = NS.InitSummary()
  assertTrue(s:find("PanelMaster", 1, true) ~= nil)
  assertTrue(s:find("v" .. NS.version, 1, true) ~= nil)
  assertTrue(s:find("schema v" .. NS.SCHEMA_VERSION, 1, true) ~= nil)
  assertTrue(s:find("Default", 1, true) ~= nil)
  assertTrue(s:find("1 panels", 1, true) ~= nil)
  NS.Registry:DeleteAll()
end)

test("Database.InitSummary: survives a missing DB", function()
  local saved = NS.db
  NS.db = nil
  local s = NS.InitSummary()
  assertTrue(type(s) == "string")
  NS.db = saved
end)
