local _, NS = ...
NS.Diagnostics = NS.Diagnostics or {}
local Dx = NS.Diagnostics
local C = NS.Constants

-- The diagnostics report's sections (debug-logging-§14, DX-PM): `/pm diagnostics` and
-- `/pm debug diagnostics`. The report itself is the library's (LibKa0s-DebugLog-1.0, 14.1): the
-- markers, the identity header, a pcall per section, the cap and the ungated append are all written
-- around these. This file only says what PanelMaster knows about itself.
--
-- READ-ONLY, and that is the contract rather than a style. Nothing here writes a setting, moves or
-- shows a frame, recovers a panel, fits one to its artwork or replays the combat unlock queue. Each
-- question the addon can answer by acting — would `/pm recover` move this panel, what would the
-- renderer draw — is answered by the PURE half of the code that acts: Registry.IsOffScreen,
-- Canvas.BuildSpec, Artwork.BuildArtSpec and Unlock:PendingSnapshot.
--
-- SECRET-SAFE. Every value reaches a line through `out:add`, which stringifies it before any format
-- sees it; a number read off a frame is tested with `out:readable` before it is compared, because a
-- frame fed a secret in combat hands one back. Each section is pcall'd by the library, and each
-- panel by `out:section` here, so one bad panel costs one line and the next one still prints.
--
-- Everything is resolved through NS at CALL time. The descriptor in core/DebugLogSetup.lua asks
-- for Dx.Sections() when the report runs, long after every module has loaded.

local TAG = "Diag"

-- Record fields that name the panel rather than style it. They head the panel's first line, so
-- they are left out of its difference from the template.
local IDENTITY = { id = true, name = true, frameName = true }

local function sortedIds(set)
  local ids = {}
  for id, on in pairs(set or {}) do
    if on then ids[#ids + 1] = id end
  end
  table.sort(ids, function(a, b)
    if type(a) == "number" and type(b) == "number" then return a < b end
    return tostring(a) < tostring(b)
  end)
  return ids
end

local function profileSettings()
  local p = NS.db and NS.db.profile
  return (p and p.settings) or {}
end

local function isDown()
  return NS.Lifecycle and NS.Lifecycle:IsDown() and true or false
end

-- Two readable numbers equal to within display rounding. A value that is not readable (a secret, or
-- nil from a frame that has no answer) is never compared: the caller prints "unknown".
local function near(out, a, b)
  if not (out:readable(a) and out:readable(b)) then return nil end
  return math.abs(a - b) < 0.001
end

local function yesNo(v)
  if v == nil then return "unknown" end
  return v and "yes" or "NO"
end

-- ── state ──────────────────────────────────────────────────────────────────────────

-- What the library's header does not know: the schema stamp, the profile, the stored switch
-- against the latch, and the holds that stood the addon down.
local function stateSection(out)
  local g = NS.db and NS.db.global
  out:add(TAG, "schema: stored=%s code=%s", g and g.schemaVersion, NS.SCHEMA_VERSION)
  out:add(TAG, "profile: %s", NS.db and NS.db:GetCurrentProfile() or "no database")
  out:add(TAG, "enabled (stored)=%s stood down=%s",
    NS.Schema and NS.Schema:Get(NS.Schema.ENABLED_PATH), isDown())
  out:joined(TAG, "lifecycle holds:", NS.Lifecycle and NS.Lifecycle:Holds() or {})
  -- Unlock mode IS this addon's test mode (options-ui-§15): it shows every panel, disabled ones
  -- included, with its outline and name.
  out:add(TAG, "test mode: %s", NS.State.unlocked and "unlock mode" or "none")
end

-- ── master switches and unlock state ───────────────────────────────────────────────

local function masterSection(out)
  local s = profileSettings()
  out:add(TAG, "master: enabled=%s visibility=%s alpha=%s scale=%s",
    s.enabled, s.visibility, s.alpha, s.scale)
  out:add(TAG, "unlock: global=%s snap=%s grid=%s outline=%s labels=%s",
    NS.State.unlocked, s.snapToGrid, s.gridSize, s.unlockOutlineSize, s.showLabels)
  out:list(TAG, "unlocked panels:", sortedIds(NS.State.unlockedPanels))
end

-- The unlock requests combat deferred. Read through the snapshot, a copy, so reading it can never
-- flush or replay the queue.
local function queueSection(out)
  local snap = NS.Unlock:PendingSnapshot()
  out:add(TAG, "unlock queue: global=%s", snap.unlock)
  out:list(TAG, "queued panels:", snap.panels)
end

-- ── settings ───────────────────────────────────────────────────────────────────────

local function settingsSection(out)
  local S = NS.Schema
  local n = out:nonDefaults(S.Schema, function(row) return S:Get(row.path) end, nil, nil,
    { always = { S.ENABLED_PATH }, tag = TAG })
  -- Session-only, so the walk skips it; printed by hand because a locked or unlocked UI is the
  -- first thing a report about panels needs.
  out:add(TAG, "state.locked = %s (session-only)", S:Get("state.locked"))
  out:add(TAG, "settings printed: %s", n)
end

-- ── screen ─────────────────────────────────────────────────────────────────────────

local function screenSection(out)
  local w, h = NS.Compat.GetScreenSize()
  out:add(TAG, "screen: %s x %s uiscale=%s", w, h, NS.Compat.GetUIScale())
end

-- ── per panel ──────────────────────────────────────────────────────────────────────

--- A field value on one line: a table as `{k=v, ...}` with its keys sorted, anything else as is.
local function fieldText(out, v)
  if type(v) ~= "table" then return out:str(v) end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for i, k in ipairs(keys) do parts[i] = out:str(k) .. "=" .. fieldText(out, v[k]) end
  return "{" .. table.concat(parts, " ") .. "}"
end

-- Every field of the record that differs from C.PANEL_TEMPLATE, including one the template does
-- not carry at all, keys sorted so two reports diff cleanly.
local function templateDiff(out, rec)
  local T = C.PANEL_TEMPLATE
  local keys, seen = {}, {}
  for _, t in ipairs({ rec, T }) do
    for k in pairs(t) do
      if not seen[k] and not IDENTITY[k] then
        seen[k] = true
        keys[#keys + 1] = k
      end
    end
  end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for _, k in ipairs(keys) do
    if not NS.Util.DeepEqual(rec[k], T[k]) then
      parts[#parts + 1] = out:str(k) .. "=" .. fieldText(out, rec[k])
    end
  end
  out:joined(TAG, "  differs from template:", parts)
end

-- How one media name resolves, the way Compat.FetchMedia resolves it at render time, without
-- going through it: FetchMedia answers the SAME path for a found "Solid" and a missing name, so it
-- cannot tell the two apart.
local function mediaState(mediaType, name)
  if name == C.NONE_MEDIA_NAME then return "none" end
  local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
  if not (LSM and LSM.Fetch) then return "no LSM -> Solid" end
  if name and LSM:Fetch(mediaType, name, true) then return "ok" end
  return "missing -> Solid"
end

local function mediaLine(out, spec)
  local a = spec.accent
  local fields = {
    { "bgTexture", "background", spec.bgTexture },
    { "borderTexture", "border", spec.borderTexture },
    { "accentTexture", "statusbar", a.texture },
    { "accentBorderTexture", "border", a.borderTexture },
  }
  local parts = {}
  for i, f in ipairs(fields) do
    parts[i] = ("%s=%s (%s)"):format(f[1], out:str(f[3]), mediaState(f[2], f[3]))
  end
  out:add(TAG, "  media: %s", table.concat(parts, ", "))
end

-- The artwork a record names and what it resolved to. A custom path is printed verbatim: it is the
-- one value the player typed, and "the file is not where I said" is the usual bug.
local function artLine(out, rec, spec)
  local id = rec.artTexture
  local quads = spec.art and #spec.art.quads or 0
  if type(id) ~= "string" or id == "" or id == C.ARTWORK_NONE then
    out:add(TAG, "  art: none")
  elseif id == C.ARTWORK_CUSTOM then
    out:add(TAG, "  art: custom path=%s resolved=%s quads=%s", rec.artCustomPath,
      spec.art and "yes" or "NO", quads)
  else
    local row = NS.Artwork and NS.Artwork.Entry(id)
    out:add(TAG, "  art: %s catalog=%s path=%s quads=%s", id, row and "yes" or "NO",
      spec.art and spec.art.path or "-", quads)
  end
end

-- Where the record puts the panel, where the frame really is, and whether `/pm recover` would move
-- it. Registry.IsOffScreen is recover's own test, answered without recovering anything.
local function positionLine(out, rec, spec, f)
  local w, h = NS.Compat.GetScreenSize()
  local off = "unknown"
  if w and h then off = NS.Registry.IsOffScreen(rec, w, h, profileSettings()) and "yes" or "no" end
  local live = "no frame"
  if f and not isDown() then
    local point, _, relPoint, x, y = f:GetPoint(1)
    live = ("%s %s %s,%s"):format(out:str(point), out:str(relPoint), out:str(x), out:str(y))
  end
  out:add(TAG, "  position: record %s %s %s,%s scale=%s strata=%s live %s offscreen=%s",
    spec.point, spec.relPoint, spec.x, spec.y, spec.scale, spec.strata, live, off)
end

-- The renderer's frame against the record: present, shown, its live size against the size the
-- spec asks for, and its live alpha against the alpha it should hold.
local function rendererLines(out, spec, f)
  if not f then
    out:add(TAG, "  renderer: frame=NO (the record has no frame)")
    return
  end
  local w, h = f:GetWidth(), f:GetHeight()
  local sizeOk = near(out, w, spec.width)
  if sizeOk ~= nil then sizeOk = sizeOk and near(out, h, spec.height) end
  out:add(TAG, "  renderer: frame=yes shown=%s want=%s live %sx%s record %sx%s match=%s",
    f:IsShown(), spec.shown, w, h, spec.width, spec.height, yesNo(sizeOk))

  local live = f:GetAlpha()
  local tracked = (NS.Canvas.__mouseoverPanels or {})[spec.id] ~= nil
  local alphaOk = near(out, live, spec.alpha)
  if alphaOk == false and spec.mouseover then alphaOk = near(out, live, spec.mouseoverAlpha) end
  out:add(TAG, "  alpha: live=%s target=%s floor=%s mouseover=%s tracked=%s match=%s",
    live, spec.alpha, spec.mouseoverAlpha, spec.mouseover, tracked, yesNo(alphaOk))
end

local function panelLines(out, rec)
  local spec = NS.Canvas.BuildSpec(rec, profileSettings(), NS.Compat.InCombat())
  local f = NS.Canvas:FrameFor(rec.id)
  out:add(TAG, "[%s] '%s' enabled=%s frame=%s unlocked=%s", rec.id, rec.name, rec.enabled,
    spec.frameName, NS.Unlock:IsPanelUnlocked(rec.id) and "yes" or "no")
  templateDiff(out, rec)
  if isDown() then
    out:add(TAG, "  renderer: stood down")
  else
    rendererLines(out, spec, f)
  end
  positionLine(out, rec, spec, f)
  mediaLine(out, spec)
  artLine(out, rec, spec)
end

local function panelsSection(out)
  local records = NS.Registry:All()
  out:add(TAG, "registry: %s panels", #records)
  for _, rec in ipairs(records) do
    out:section("panel " .. out:str(rec.id), panelLines, rec)
  end
end

-- ── the renderer's own state ───────────────────────────────────────────────────────

-- A frame with no record is a leak; the pool count is how you tell a leak from healthy reuse.
local function framesSection(out)
  local orphans, count = 0, 0
  for id in pairs(NS.Canvas.__active or {}) do
    count = count + 1
    if not NS.Registry:Get(id) then orphans = orphans + 1 end
  end
  out:add(TAG, "frames: %s active, %s pooled, %s orphaned", count, NS.Canvas.PooledCount(),
    orphans)
end

local function mouseoverSection(out)
  local tracked = 0
  for _ in pairs(NS.Canvas.__mouseoverPanels or {}) do tracked = tracked + 1 end
  local driver = NS.Canvas.__mouseoverDriver
  local running = driver ~= nil and driver:GetScript("OnUpdate") ~= nil
  out:add(TAG, "mouseover: tracked=%s ticker=%s", tracked, running and "on" or "off")
end

local function artworkSection(out)
  local sunn, prefix = 0, NS.SunnArt and NS.SunnArt.ID_PREFIX
  local catalog = NS.Artwork.Catalog
  for _, row in ipairs(catalog) do
    if prefix and type(row.id) == "string" and row.id:sub(1, #prefix) == prefix then
      sunn = sunn + 1
    end
  end
  out:add(TAG, "artwork catalog: %s rows, %s from Sunn packs", #catalog, sunn)
  local themes = NS.SunnArt and NS.SunnArt.Themes and NS.SunnArt.Themes() or {}
  out:add(TAG, "sunn themes installed: %s", #themes)
end

-- The event names the client refused this session (NS.State.rejectedEvents): the record
-- events-frames-taint-§1 requires the player can reach. It says 0 rather than going quiet.
local function eventsSection(out)
  local rejected = NS.State.rejectedEvents or {}
  out:list(TAG, ("rejected events (%d):"):format(#rejected), rejected)
end

local SECTIONS = {
  { "state", stateSection },
  { "master", masterSection },
  { "unlock queue", queueSection },
  { "settings", settingsSection },
  { "screen", screenSection },
  { "panels", panelsSection },
  { "frames", framesSection },
  { "mouseover", mouseoverSection },
  { "artwork", artworkSection },
  { "events", eventsSection },
}

--- The sections, in report order, as `{ name, fn }` pairs for the DebugLog descriptor's
--- `diagnostics` field. The same table every call: the library only reads it.
function Dx.Sections()
  return SECTIONS
end
