local addonName, NS = ...

-- AceDB init. Deliberately PER-CHARACTER (no defaultProfile argument): a panel layout is tied to the
-- UI a given character runs, and a healer's frame arrangement is rarely the tank alt's. AceDB's
-- profile machinery is what lets a user copy one character's layout to another when they do want it
-- shared, which a single forced account-wide profile would take away.
--
-- `global` holds only the schema stamp; everything the user configures lives in `profile`.
function NS:InitDB()
  NS.db = LibStub("AceDB-3.0"):New(addonName .. "DB", NS.defaults)
  NS:RunMigrations()   -- normalize the persisted schema before any panel is read
end

-- Schema-migration runner (savedvariables-§1). Reads/writes db.global.schemaVersion and ships even
-- with an effectively empty body — the *seam* is the requirement: future schema changes get a
-- single, idempotent upgrade path invoked once at init, before any read of db.profile.panels. Safe
-- no-op when the DB isn't ready yet.
function NS:RunMigrations()
  local g = NS.db and NS.db.global
  if not g then return end
  g.schemaVersion = g.schemaVersion or 1
  if g.schemaVersion < NS.SCHEMA_VERSION then
    -- No migrations yet — 0.1.0 ships schema v1, so this branch cannot be reached on a current
    -- build. It exists so the first real schema change is a body edit rather than a structural one.
    local from = g.schemaVersion
    g.schemaVersion = NS.SCHEMA_VERSION
    if NS.State.debug and NS.Debug then
      NS.Debug("Migrate", "%s", NS.MigrationSummary(from, NS.SCHEMA_VERSION, 0))
    end
  end
end

-- Pure migration summary for the [Migrate] debug line.
function NS.MigrationSummary(from, to, rows)
  return ("v%s -> v%s, %s panels touched"):format(tostring(from), tostring(to), tostring(rows))
end

-- Pure [Init] session summary for the SetEnabled seam (debug-logging-§5/§8): addon name + version,
-- schema version, active profile, and panel count — e.g.
-- "PanelMaster v0.1.0, schema v1, profile 'Mock - Realm', 3 panels".
-- Guarded so it can't error before the DB is ready. All values are plain constants/counts, so a raw
-- tostring is secret-safe here.
function NS.InitSummary()
  local g = NS.db and NS.db.global
  local schema = (g and g.schemaVersion) or 0
  local profile = (NS.db and NS.db.GetCurrentProfile and NS.db:GetCurrentProfile()) or "?"
  local panels = (NS.db and NS.db.profile and NS.db.profile.panels and #NS.db.profile.panels) or 0
  return ("%s v%s, schema v%s, profile '%s', %s panels"):format(
    tostring(NS.name), tostring(NS.version), tostring(schema), tostring(profile), tostring(panels))
end
