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
  NS:RunMigrations()          -- normalize the persisted schema before any panel is read
  NS:SweepPreviewPanels()     -- orphans from a /reload with test mode on
  NS:RegisterProfileCallbacks()
end

-- Remove every preview placeholder left in the profile, and report how many went.
--
-- Preview panels are real records (that is what makes preview exercise the real render path), and
-- they are withdrawn on the way out of preview — but a /reload with test mode on never gets to that
-- exit, and the ids that tracked them died with the session. The marker on the record is the
-- durable half of that pair, so this is the only thing that can find them afterwards.
--
-- Walks BACKWARDS so removing an entry cannot make the loop skip the one after it. Runs in
-- OnInitialize, i.e. before Canvas:Enable and before the first RenderAll, so no orphan is ever
-- drawn. Idempotent by construction: a second pass finds nothing left to remove.
--
-- Deliberately not routed through NS.Registry:Delete — there is nothing on the bus to tell yet at
-- this point in the lifecycle, and a per-record broadcast here would be N rebuilds of a UI that does
-- not exist.
--
-- Known trade-off: a preview panel the user ran `/pm panel <name> reset` on has lost its marker and
-- survives as a real panel. Strictly better than every preview panel surviving.
function NS:SweepPreviewPanels()
  local p = NS.db and NS.db.profile
  if not (p and p.panels) then return 0 end

  local removed = 0
  for i = #p.panels, 1, -1 do
    if p.panels[i][NS.Constants.PREVIEW_FIELD] then
      table.remove(p.panels, i)
      removed = removed + 1
    end
  end

  if removed > 0 then
    NS.Debug("Preview", "swept %s orphaned preview panel(s)", removed)
  end
  return removed
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
--
-- NS:RunMigrations is deliberately NOT called from here. The stamp it gates on lives in `db.global`,
-- which is ACCOUNT-WIDE and already written by InitDB before any profile can be switched — so a
-- second call could only ever be a no-op, and a no-op that reads as a safety net is worse than
-- none. What an incoming profile actually needs is the per-RECORD repair, and that is R.Sanitize's:
-- NS.Registry:ReloadProfile sanitizes every record it finds, which includes the same frame-name
-- backfill the v1 → v2 body performs (modules/Registry.lua:200-202). That is the path that reaches
-- a profile the account-wide stamp has already declared current.
function NS:RegisterProfileCallbacks()
  if not (NS.db and NS.db.RegisterCallback) then return end
  local function reload()
    NS:SweepPreviewPanels()   -- a copied profile can carry someone else's preview orphans
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
    local from = g.schemaVersion
    local rows = 0

    -- v1 → v2: stamp each panel's frame name onto its record.
    --
    -- Before v2 the frame name was derived from the panel's name on every read, so a rename produced
    -- a DIFFERENT frame name — which abandoned the old frame and silently orphaned every external
    -- anchor pointed at it. Storing it makes it identity, like the id, and a rename becomes a
    -- relabel.
    --
    -- Deriving it here from the name is what makes the upgrade invisible: it reproduces exactly the
    -- name the previous build already gave that panel's frame, so nothing anchored to it moves.
    -- Guarded on the key being absent rather than rewritten unconditionally, so this is idempotent
    -- and so a record already stamped by R.Sanitize on some earlier path is left alone.
    if from < 2 then
      local p = NS.db.profile
      for _, rec in ipairs((p and p.panels) or {}) do
        if type(rec.frameName) ~= "string" or rec.frameName == "" then
          rec.frameName = NS.Util.FrameName(rec.name)
          rows = rows + 1
        end
      end
    end

    g.schemaVersion = NS.SCHEMA_VERSION
    NS.Debug("Migrate", "%s", NS.MigrationSummary(from, NS.SCHEMA_VERSION, rows))
  end
end

-- Pure migration summary for the [Migrate] debug line.
function NS.MigrationSummary(from, to, rows)
  return ("v%s -> v%s, %s panels touched"):format(tostring(from), tostring(to), tostring(rows))
end

-- Pure [Init] session summary for the SetEnabled seam (debug-logging-§5/§8): addon name + version,
-- schema version, active profile, and panel count — e.g.
-- "PanelMaster v1.0.0, schema v1, profile 'Mock - Realm', 3 panels".
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
