local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

test("Database: InitDB opened both scopes", function()
  assertTrue(type(NS.db.global) == "table")
  assertTrue(type(NS.db.profile) == "table")
end)

test("Database: InitDB runs the migration runner, so the live DB comes back stamped", function()
  -- What this case is for is the INVOCATION: NS:InitDB calls NS:RunMigrations before any panel is
  -- read (core/Database.lua:19), and the runner is the only thing that writes the stamp. Drop that
  -- call and an upgrading account reaches the renderer un-migrated.
  --
  -- It deliberately says nothing about the SHAPE of NS.defaults.global. Whether the stamp is absent
  -- there or seeded pre-ladder is an implementation choice no user can see; what a user CAN see is
  -- whether the v1 -> v2 body ran for their file, and that is the case below — which drives the
  -- runner against a v1 SavedVariables file and reads the migrated frameName back.
  assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION,
    "the live DB is unstamped — InitDB did not run the migration runner")
end)

test("Database.RunMigrations: a v1 SavedVariables file reaches the v1 -> v2 body", function()
  local savedDB = NS.db

  -- The DB AceDB hands back for a SavedVariables file written by a v1 build: `global` is whatever
  -- the shipped defaults carry — copied, not hand-written, so this drives the shape that actually
  -- ships — and the profile holds panels with no `frameName`, because v1 derived the frame name on
  -- every read instead of storing it.
  local g = {}
  for k, v in pairs(NS.defaults.global) do g[k] = v end

  NS.db = {
    global  = g,
    profile = { panels = { { id = "p1", name = "Old Panel" } } },
    GetCurrentProfile = savedDB.GetCurrentProfile,
  }

  NS:RunMigrations()

  -- Derived from the name, which is exactly what v1 rendered this panel's frame as — so the upgrade
  -- moves nobody's anchors. This is the assertion the seeded default silently made unreachable.
  assertEqual(NS.db.profile.panels[1].frameName, "PanelMaster_Panel_Old_Panel",
    "the v1 -> v2 body did not run for a v1 SavedVariables file")
  assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)

  NS.db = savedDB
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

test("Database.RunMigrations: v2 stamps a frame name onto every unstamped panel", function()
  local R = NS.Registry
  local saved = NS.db.global.schemaVersion
  R:DeleteAll()
  local rec = R:New("Old Panel")
  rec.frameName = nil            -- as a v1 profile would have stored it: derived, never persisted

  NS.db.global.schemaVersion = 1
  NS:RunMigrations()

  -- Derived from the name, which is exactly what v1 rendered this panel's frame as — so the upgrade
  -- moves nobody's anchors. Without it, the first rename after upgrading would still swap frames.
  assertEqual(rec.frameName, "PanelMaster_Panel_Old_Panel")
  assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)

  R:DeleteAll()
  NS.db.global.schemaVersion = saved
end)

test("Database.RunMigrations: v2 leaves an already-stamped frame name alone", function()
  local R = NS.Registry
  local saved = NS.db.global.schemaVersion
  R:DeleteAll()
  local rec = R:New("Renamed Panel")
  R:Rename(rec.id, "Something Else")   -- the stored frame name no longer matches the name

  NS.db.global.schemaVersion = 1
  NS:RunMigrations()

  -- Re-deriving here would undo the very thing the stored field exists to protect: it would hand the
  -- panel a frame name it has never answered to and orphan the anchors the rename kept.
  assertEqual(rec.frameName, "PanelMaster_Panel_Renamed_Panel")

  R:DeleteAll()
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

test("Database.SweepPreviewPanels: removes the marked records and nothing else", function()
  local R, C = NS.Registry, NS.Constants
  R:DeleteAll()
  R:New("Mine")
  R:New("Ghost One", { [C.PREVIEW_FIELD] = true })
  R:New("Ghost Two", { [C.PREVIEW_FIELD] = true })
  R:New("Also Mine")

  -- Orphans left behind by a /reload with test mode on: the ids that tracked them are gone with the
  -- session, so the marker on the record is the only way back.
  assertEqual(NS:SweepPreviewPanels(), 2)
  assertEqual(R:Count(), 2)
  assertTrue(R:FindByName("Mine") ~= nil, "the user's own panel was swept")
  assertTrue(R:FindByName("Also Mine") ~= nil, "the user's own panel was swept")
  R:DeleteAll()
end)

test("Database.SweepPreviewPanels: is idempotent", function()
  local R, C = NS.Registry, NS.Constants
  R:DeleteAll()
  R:New("Ghost", { [C.PREVIEW_FIELD] = true })
  assertEqual(NS:SweepPreviewPanels(), 1)
  assertEqual(NS:SweepPreviewPanels(), 0, "a second sweep found something to remove")
  R:DeleteAll()
end)

test("Database.SweepPreviewPanels: survives being called before the DB exists", function()
  local saved = NS.db
  NS.db = nil
  assertEqual(NS:SweepPreviewPanels(), 0)   -- must not error
  NS.db = saved
end)

test("Database: InitDB sweeps preview orphans before anything can read the panels", function()
  -- Asserted against the source because the ORDER is the whole point: the sweep has to land after
  -- the migrations (which normalize the records it inspects) and before the profile callbacks, so
  -- no orphan is ever rendered.
  local f = io.open("core/Database.lua", "r")
  local body = f:read("*a")
  f:close()
  local migrate = body:find("NS:RunMigrations()", 1, true)
  local sweep   = body:find("NS:SweepPreviewPanels()", 1, true)
  local callbacks = body:find("NS:RegisterProfileCallbacks()", 1, true)
  assertTrue(sweep ~= nil, "InitDB never sweeps preview orphans")
  assertTrue(migrate < sweep, "the sweep runs before the migrations")
  assertTrue(sweep < callbacks, "the sweep runs after the profile callbacks are registered")
end)

test("Database.InitSummary: survives a missing DB", function()
  local saved = NS.db
  NS.db = nil
  local s = NS.InitSummary()
  assertTrue(type(s) == "string")
  NS.db = saved
end)
