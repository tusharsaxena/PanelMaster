local addonName, NS = ...

-- AceDB init, using the SHARED "Default" profile (the `true` third argument, which AceDB maps to the
-- profile named "Default").
--
-- Every character therefore starts on one common layout rather than each getting a private
-- character-keyed profile. That is the right default for this addon: a panel layout is a description
-- of a UI, and most people run one UI. Someone who genuinely wants a per-character layout makes one
-- on the Profiles page in two clicks; under the opposite default, someone who wants a shared layout
-- has to rebuild or copy it on every alt.
--
-- Note AceDB's precedence — `sv.profileKeys[charKey] or defaultProfile or charKey` — so a character
-- that has ALREADY been assigned a profile keeps it. This changes where new characters land, not
-- where existing ones already are.
--
-- `global` holds only the schema stamp; everything the user configures lives in `profile`.
function NS:InitDB()
  NS.db = LibStub("AceDB-3.0"):New(addonName .. "DB", NS.defaults, true)
  NS:RunMigrations()   -- normalize the persisted schema before any panel is read
  NS:RegisterProfileCallbacks()
end

-- React to the Profiles page switching, copying into, or resetting the active profile.
--
-- Without this, switching profiles leaves the previous profile's panels on screen: `NS.db.profile`
-- is swapped wholesale by AceDB, and nothing else would ever look at it again. All three events mean
-- the same thing to this addon — "the panel set you were showing is no longer the panel set that is
-- stored" — so all three take the same path.
--
-- The reload is delegated to NS.Registry so that the panels message keeps a single sender
-- (architecture-§4).
function NS:RegisterProfileCallbacks()
  if not (NS.db and NS.db.RegisterCallback) then return end
  local function reload()
    NS:RunMigrations()   -- the incoming profile may predate the current schema
    if NS.Registry and NS.Registry.ReloadProfile then NS.Registry:ReloadProfile() end
  end
  NS.db.RegisterCallback(NS, "OnProfileChanged", reload)
  NS.db.RegisterCallback(NS, "OnProfileCopied", reload)
  NS.db.RegisterCallback(NS, "OnProfileReset", reload)
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
