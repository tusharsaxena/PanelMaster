local addonName, NS = ...   -- luacheck: ignore addonName
NS.Registry = NS.Registry or {}
local R = NS.Registry
local C = NS.Constants
local Util = NS.Util

-- The panel registry: the one owner of `db.profile.panels`. Every create, delete, rename and field
-- edit goes through here, so validation, clamping and the change broadcast can never be skipped by a
-- caller. The settings panel, the CLI and unlock-mode dragging are all just callers.
--
-- Panel records are a storage carve-out (architecture-§5): they are variable-length user-created
-- objects rather than fixed settings with widgets, so they are NOT Schema rows and are mutated here
-- instead of through Schema:Set.

-- Sole senders (architecture-§4): the two panel messages below are sent from this file and nowhere
-- else. `PanelsChanged` means the SET changed (a panel was added, deleted or renamed) and the whole
-- view must be rebuilt; `PanelChanged` means one panel's fields changed and only it needs
-- repainting. Keeping them distinct is what lets a drag repaint one frame instead of all of them.
local MSG_PANELS = "Ka0s_PanelMaster_PanelsChanged"
local MSG_PANEL  = "Ka0s_PanelMaster_PanelChanged"
R.MSG_PANELS, R.MSG_PANEL = MSG_PANELS, MSG_PANEL

local function fire(message, ...)
  if NS.bus then NS.bus:SendMessage(message, ...) end
end

-- The write seam's log arguments, built only once NS.DebugBuild is past the gate. A plain function
-- taking (rec, field) rather than a closure over them: a closure would be created at the call site
-- on every field write whether or not logging is on, which is the cost this defers.
local function describeWrite(rec, field)
  return rec.name, field, R.FormatField(rec, field)
end

-- The live registry array. Returns an empty table (not nil) before the DB exists, so every caller
-- can iterate unconditionally.
function R:All()
  local p = NS.db and NS.db.profile
  return (p and p.panels) or {}
end

function R:Count()
  return #R:All()
end

-- ── Sanitize ────────────────────────────────────────────────────────────────────
-- Fill every missing field from the template and clamp every numeric one into range. PURE with
-- respect to the DB — it mutates the record it is handed and returns it, so it is equally usable on
-- a stored record, on a candidate that has not been stored yet, and in a headless test.
--
-- This runs on the way IN (every write) rather than on the way out, so the stored file is always
-- already valid: an old record missing a field added in a later build is repaired the first time it
-- is touched, and a hand-edited SavedVariables file cannot feed a string width into SetWidth.
function R.Sanitize(rec)
  if type(rec) ~= "table" then return nil end
  local t = C.PANEL_TEMPLATE

  rec.name    = Util.CleanName(rec.name) or t.name
  rec.enabled = (rec.enabled ~= false)   -- anything but an explicit false means enabled

  rec.width  = Util.Clamp(rec.width,  C.MIN_SIZE, C.MAX_SIZE, t.width)
  rec.height = Util.Clamp(rec.height, C.MIN_SIZE, C.MAX_SIZE, t.height)

  -- Offsets are intentionally NOT clamped to the screen here: a legitimate multi-monitor or
  -- high-resolution layout can carry offsets far outside the current UIParent, and clamping on every
  -- write would quietly destroy that layout the first time the user logged in at a lower resolution.
  -- Recovering a genuinely unreachable panel is R.Recover's job, and it runs on demand.
  rec.x = tonumber(rec.x) or t.x
  rec.y = tonumber(rec.y) or t.y

  if not Util.IsPoint(rec.point)    then rec.point    = t.point end
  if not Util.IsPoint(rec.relPoint) then rec.relPoint = t.relPoint end
  if not Util.IsStrata(rec.strata)  then rec.strata   = t.strata end

  rec.level      = Util.Clamp(rec.level, 0, 100, t.level)
  rec.borderSize = Util.Clamp(rec.borderSize, C.MIN_BORDER, C.MAX_BORDER, t.borderSize)
  rec.borderOffset =
    Util.Clamp(rec.borderOffset, C.MIN_BORDER_OFFSET, C.MAX_BORDER_OFFSET, t.borderOffset)
  rec.alpha      = Util.Clamp(rec.alpha, 0, 1, t.alpha)

  rec.bgColor     = Util.Color(rec.bgColor, t.bgColor)
  rec.borderColor = Util.Color(rec.borderColor, t.borderColor)

  -- Media names are kept as free strings and NOT validated against the live LibSharedMedia list: an
  -- addon that registers a texture may load after this one, so a name that resolves to nothing right
  -- now can be perfectly valid a second later. Compat.FetchMedia degrades at render time instead,
  -- which keeps the user's choice in the file rather than silently rewriting it to the default.
  if type(rec.bgTexture) ~= "string" or rec.bgTexture == "" then rec.bgTexture = t.bgTexture end
  if type(rec.borderTexture) ~= "string" or rec.borderTexture == "" then
    rec.borderTexture = t.borderTexture
  end

  -- Class-color flags, driven off C.COLOR_FIELDS so a color added later needs no edit here.
  for _, flag in pairs(C.COLOR_FIELDS) do
    rec[flag] = rec[flag] and true or false
  end

  rec.mouseover      = rec.mouseover and true or false
  rec.mouseoverAlpha = Util.Clamp(rec.mouseoverAlpha, 0, 1, t.mouseoverAlpha)

  -- Accent bar. The edge set is normalized rather than defaulted: an EMPTY set is a legitimate state
  -- (the user unticked every edge) and must not be quietly repopulated with TOP, so only a
  -- non-table falls back to the template's.
  rec.accentEnabled = rec.accentEnabled and true or false
  rec.accentEdges = Util.EdgeSet(
    type(rec.accentEdges) == "table" and rec.accentEdges or t.accentEdges)
  if type(rec.accentTexture) ~= "string" or rec.accentTexture == "" then
    rec.accentTexture = t.accentTexture
  end
  rec.accentThickness = Util.Clamp(rec.accentThickness,
    C.MIN_ACCENT_THICKNESS, C.MAX_ACCENT_THICKNESS, t.accentThickness)
  rec.accentOffset = Util.Clamp(rec.accentOffset,
    C.MIN_ACCENT_OFFSET, C.MAX_ACCENT_OFFSET, t.accentOffset)

  -- The accent bar's own border. Shares the panel border's bounds, so a value legal on one is legal
  -- on the other.
  if type(rec.accentBorderTexture) ~= "string" or rec.accentBorderTexture == "" then
    rec.accentBorderTexture = t.accentBorderTexture
  end
  rec.accentBorderSize = Util.Clamp(rec.accentBorderSize,
    C.MIN_BORDER, C.MAX_BORDER, t.accentBorderSize)
  rec.accentBorderOffset = Util.Clamp(rec.accentBorderOffset,
    C.MIN_BORDER_OFFSET, C.MAX_BORDER_OFFSET, t.accentBorderOffset)

  return rec
end

-- ── Frame name ──────────────────────────────────────────────────────────────────

-- The deterministic global frame name this panel's frame carries, e.g. `PanelMaster_Panel_Chat_BG`.
-- Part of the addon's public contract: other addons anchor to it by name (see C.FRAME_NAME_PREFIX).
function R.FrameName(rec)
  return Util.FrameName(rec and rec.name)
end

-- Is `slug` already taken by a panel other than `exceptID`?
--
-- Names are unique, but SLUGS are coarser than names — "Chat BG" and "Chat-BG" are two legal names
-- that slugify to one frame name. Two frames cannot share a global name, so the second would either
-- fail to be created or silently steal the first's global, and anything anchored to it would end up
-- attached to the wrong panel. Cheaper to refuse the name.
local function slugTaken(slug, exceptID)
  for _, rec in ipairs(R:All()) do
    if rec.id ~= exceptID and Util.Slugify(rec.name) == slug then return rec end
  end
  return nil
end

-- ── Lookup ──────────────────────────────────────────────────────────────────────

function R:Get(id)
  for _, rec in ipairs(R:All()) do
    if rec.id == id then return rec end
  end
  return nil
end

-- Find by name, case-insensitively. Names are what the user types at the CLI, and requiring them to
-- reproduce the exact casing of a name they chose themselves is friction with no upside. Returns the
-- record and its index.
function R:FindByName(name)
  name = Util.CleanName(name)
  if not name then return nil end
  local lowered = name:lower()
  for i, rec in ipairs(R:All()) do
    if tostring(rec.name):lower() == lowered then return rec, i end
  end
  return nil
end

-- Resolve whatever the user typed — a name or a numeric id — to a record. The CLI accepts both, so
-- this is the one place that decides which is which. A name wins over an id: a user who names a
-- panel "2" means that panel, not the one whose id happens to be 2.
function R:Resolve(key)
  if key == nil then return nil end
  local byName = R:FindByName(key)
  if byName then return byName end
  local id = tonumber(key)
  if id then return R:Get(id) end
  return nil
end

-- ── Create / delete / rename ────────────────────────────────────────────────────

-- Create a panel. Returns (record) on success, or (nil, reason) — never a bare nil, so every caller
-- has something to print.
--
-- `overrides` is an optional partial record (preview mode and the CLI both pass one). New panels
-- pick up the profile's default strata/alpha, which is what makes those settings meaningful.
-- The create itself, WITHOUT the broadcast. Split out so a batch (preview mode stands up three
-- placeholders at once) can make every record and then announce the new set exactly once, rather
-- than making every consumer rebuild itself once per record.
local function create(name, overrides)
  local p = NS.db and NS.db.profile
  if not p then return nil, "database not ready" end

  name = Util.CleanName(name)
  if not name then return nil, "a panel needs a name" end
  if R:FindByName(name) then return nil, ("a panel named '%s' already exists"):format(name) end
  local clash = slugTaken(Util.Slugify(name))
  if clash then
    return nil, ("'%s' would share the frame name %s with '%s' \226\128\148 pick another name")
      :format(name, Util.FrameName(name), clash.name)
  end

  local rec = Util.DeepCopy(C.PANEL_TEMPLATE)
  rec.name = name
  rec.strata = p.settings.defaultStrata
  rec.alpha  = p.settings.defaultAlpha

  if type(overrides) == "table" then
    for k, v in pairs(overrides) do
      if k ~= "id" then rec[k] = Util.DeepCopy(v) end   -- the id is ours to assign, never theirs
    end
  end

  rec.id = p.nextID or 1
  p.nextID = rec.id + 1

  R.Sanitize(rec)
  p.panels[#p.panels + 1] = rec

  NS.Debug("Panel", "created '%s' (id %s)", rec.name, rec.id)
  return rec
end

function R:New(name, overrides)
  local rec, reason = create(name, overrides)
  if not rec then return nil, reason end
  fire(MSG_PANELS)
  return rec
end

-- Create several panels as ONE structural change. Returns the records that were made, in order.
--
-- A spec that cannot be created (a name the user has already taken) is SKIPPED rather than failing
-- the batch: preview mode's placeholders are a convenience, and refusing all three because one name
-- collides would be the wrong trade. Callers that need the reason use R:New per record.
function R:NewBatch(specs)
  local made = {}
  for _, spec in ipairs(specs or {}) do
    local rec = create(spec.name, spec)
    if rec then made[#made + 1] = rec end
  end
  if #made > 0 then fire(MSG_PANELS) end
  return made
end

-- The delete itself, WITHOUT the broadcast — the mirror of `create`, and there for the same reason:
-- withdrawing preview's placeholders is one structural change, not three.
local function destroy(p, rec)
  for i, candidate in ipairs(p.panels) do
    if candidate.id == rec.id then
      table.remove(p.panels, i)
      break
    end
  end

  -- Drop any session state keyed on this id. Ids are never reused, so a stale entry would never be
  -- read again — but it would accumulate for the session and show up in a debug dump as an unlocked
  -- panel that does not exist.
  NS.State.unlockedPanels[rec.id] = nil

  NS.Debug("Panel", "deleted '%s' (id %s)", rec.name, rec.id)
end

function R:Delete(key)
  local p = NS.db and NS.db.profile
  if not p then return false, "database not ready" end
  local rec = R:Resolve(key)
  if not rec then return false, ("no panel called '%s'"):format(tostring(key)) end

  destroy(p, rec)
  fire(MSG_PANELS)
  return true, rec.name
end

-- Remove several panels as ONE structural change. Returns how many went. Anything that no longer
-- resolves is skipped silently: the caller's list is a snapshot, and a panel the user deleted in the
-- meantime is not an error.
function R:DeleteBatch(keys)
  local p = NS.db and NS.db.profile
  if not p then return 0 end
  local gone = 0
  for _, key in ipairs(keys or {}) do
    local rec = R:Resolve(key)
    if rec then
      destroy(p, rec)
      gone = gone + 1
    end
  end
  if gone > 0 then fire(MSG_PANELS) end
  return gone
end

-- Restore one panel to how a freshly created panel would look, keeping only its identity.
--
-- "Reset" means the whole record — size, position, anchor, strata, textures, colors, mouseover —
-- not just appearance. A partial reset that left the panel where it was would be a different,
-- fuzzier promise, and the user would have to work out which half it covered.
--
-- `id` and `name` survive, because they are what the panel IS rather than how it looks: resetting
-- must not change the frame name and break anything anchored to it.
--
-- The profile's New-Panel-Defaults are applied exactly as R:New applies them, so "reset" and "make a
-- new one" land on the same state — otherwise the two would drift the moment a user changed their
-- defaults.
function R:Reset(key)
  local p = NS.db and NS.db.profile
  if not p then return false, "database not ready" end
  local rec = R:Resolve(key)
  if not rec then return false, ("no panel called '%s'"):format(tostring(key)) end

  local id, name = rec.id, rec.name
  for k in pairs(rec) do rec[k] = nil end
  for k, v in pairs(C.PANEL_TEMPLATE) do rec[k] = Util.DeepCopy(v) end
  rec.id, rec.name = id, name
  rec.strata = p.settings.defaultStrata
  rec.alpha  = p.settings.defaultAlpha
  R.Sanitize(rec)

  NS.Debug("Panel", "reset '%s' (id %s)", rec.name, rec.id)
  -- A field-level change, not a structural one: the SET of panels is unchanged, so the targeted
  -- repaint is the honest message. The settings editor rebuilds itself separately — its widgets all
  -- hold stale values now, which is a UI concern rather than something the bus should imply.
  fire(MSG_PANEL, rec.id)
  return true, rec.name
end

-- Fields a copy never carries across, because they are what make a panel *that* panel rather than
-- a description of how it looks.
--
-- `id` and `name` are identity: copying them would either clash or rename. The four geometry fields
-- are position — the whole reason to copy settings from another panel is to make this one MATCH it
-- while staying where it is; a copy that also moved it would land the two exactly on top of each
-- other, which is never what was wanted. Size IS copied: two panels of matching appearance usually
-- want matching dimensions, and unlike position that does not make one of them disappear.
--
-- The preview marker is excluded for a different reason: it is not appearance at all but a lifetime
-- flag, and smearing it onto a real panel would make that panel vanish at the next sweep.
local COPY_EXCLUDED = {
  id = true, name = true,
  point = true, relPoint = true, x = true, y = true,
  [C.PREVIEW_FIELD] = true,
}

-- Copy every appearance setting from one panel onto another.
--
-- Returns (true, sourceName) or (false, reason). Deep-copies each value, so the two panels do not
-- end up sharing a color array — an in-place edit of one would otherwise silently change the other.
function R:CopyFrom(targetKey, sourceKey)
  local target = R:Resolve(targetKey)
  if not target then return false, ("no panel called '%s'"):format(tostring(targetKey)) end
  local source = R:Resolve(sourceKey)
  if not source then return false, ("no panel called '%s'"):format(tostring(sourceKey)) end
  if source.id == target.id then return false, "a panel cannot copy from itself" end

  for field, value in pairs(source) do
    if not COPY_EXCLUDED[field] then
      target[field] = Util.DeepCopy(value)
    end
  end
  R.Sanitize(target)

  NS.Debug("Panel", "'%s' copied settings from '%s'", target.name, source.name)
  fire(MSG_PANEL, target.id)
  return true, source.name
end

-- Re-read the registry after the active AceDB profile changed underneath it.
--
-- Lives here, rather than in core/Database.lua where the profile callbacks are registered, so that
-- `Ka0s_PanelMaster_PanelsChanged` keeps exactly ONE sender (architecture-§4). A profile switch IS a
-- wholesale change to the set of panels, so that message is precisely the right one.
--
-- Every record is re-sanitized on the way in: a profile created by an older build, or copied from
-- one, can be missing fields this build expects, and this is the first moment it is looked at.
function R:ReloadProfile()
  for _, rec in ipairs(R:All()) do R.Sanitize(rec) end
  NS.Debug("Profile", "switched to '%s', %s panels",
    (NS.db and NS.db.GetCurrentProfile and NS.db:GetCurrentProfile()) or "?", R:Count())
  fire(MSG_PANELS)
end

-- Remove every panel. Returns how many went, so the caller can report it.
function R:DeleteAll()
  local p = NS.db and NS.db.profile
  if not p then return 0 end
  local n = #p.panels
  for i = n, 1, -1 do p.panels[i] = nil end

  -- Same sweep `destroy` does per panel, and for the same reason: an id that no longer exists would
  -- linger in the session state for the rest of the session and show up in a debug dump as an
  -- unlocked (or previewed) panel that is not there. Nothing survives an empty registry, so both
  -- tables go wholesale rather than id by id.
  for id in pairs(NS.State.unlockedPanels) do NS.State.unlockedPanels[id] = nil end
  for i = #NS.State.previewIDs, 1, -1 do NS.State.previewIDs[i] = nil end

  if n > 0 then fire(MSG_PANELS) end
  return n
end

function R:Rename(key, newName)
  local rec = R:Resolve(key)
  if not rec then return false, ("no panel called '%s'"):format(tostring(key)) end
  newName = Util.CleanName(newName)
  if not newName then return false, "a panel needs a name" end

  -- Renaming a panel to a different case of its own name is a legitimate edit ("chat bg" → "Chat
  -- BG"), so the collision check must ignore the panel being renamed rather than just testing for
  -- any match.
  local clash = R:FindByName(newName)
  if clash and clash.id ~= rec.id then
    return false, ("a panel named '%s' already exists"):format(newName)
  end
  local slugClash = slugTaken(Util.Slugify(newName), rec.id)
  if slugClash then
    return false, ("'%s' would share the frame name %s with '%s' \226\128\148 pick another name")
      :format(newName, Util.FrameName(newName), slugClash.name)
  end

  local old = rec.name
  rec.name = newName
  NS.Debug("Panel", "renamed '%s' -> '%s'", old, newName)
  fire(MSG_PANELS)   -- structural: the name is how every list and dropdown labels the panel
  return true, old
end

-- ── Field edits ─────────────────────────────────────────────────────────────────

-- The single write seam for a panel's fields. Every edit — settings widget, CLI, drag-stop — routes
-- through here, so validation, sanitizing, the debug trace and the repaint broadcast happen exactly
-- once and identically for all three.
function R:Set(key, field, value)
  local rec = R:Resolve(key)
  if not rec then return false, ("no panel called '%s'"):format(tostring(key)) end

  local kind = C.PANEL_FIELD_TYPE[field]
  if not kind then return false, ("unknown field '%s'"):format(tostring(field)) end

  -- `name` is routed to Rename rather than written directly: it is the only field with a uniqueness
  -- constraint, and duplicating that check here is how the two would eventually disagree.
  if field == "name" then return R:Rename(rec.id, value) end

  if kind == "number" then
    local n = tonumber(value)
    if n == nil then return false, "expected a number" end
    value = n
  elseif kind == "boolean" then
    local parsed = Util.ParseBool(value)
    if parsed == nil then return false, Util.BOOL_USAGE end
    value = parsed
  elseif kind == "point" then
    value = tostring(value):upper()
    if not Util.IsPoint(value) then
      return false, "expected one of: " .. table.concat(C.POINTS, ", ")
    end
  elseif kind == "strata" then
    value = tostring(value):upper()
    if not Util.IsStrata(value) then
      return false, "expected one of: " .. table.concat(C.STRATA, ", ")
    end
  elseif kind == "color" then
    if type(value) ~= "table" then
      local parsed = Util.ParseColor(value)
      if not parsed then return false, "expected r,g,b[,a] (0-1 or 0-255)" end
      value = parsed
    end
  elseif kind == "edges" then
    if type(value) ~= "table" then
      local parsed = Util.ParseEdges(value)
      if not parsed then
        return false, ("expected any of: %s (or 'none')")
          :format(table.concat(C.EDGES, ", "):lower())
      end
      value = parsed
    end
    -- Copied, not aliased: a caller that keeps its table would otherwise be able to mutate the
    -- stored set behind the registry's back, skipping the write seam entirely.
    value = Util.EdgeSet(value)
  elseif kind == "media" then
    -- Matched case-insensitively against the LIVE LibSharedMedia list so the CLI accepts
    -- `/pm panel X bgTexture blizzard marble` for "Blizzard Marble", and so a typo is refused with
    -- the real list rather than silently stored and resolved to the fallback at render time.
    value = tostring(value)
    local mediaType = C.PANEL_FIELD_MEDIA[field]
    local names = NS.Compat.MediaList(mediaType)
    local wanted, matched = value:lower(), nil
    for _, candidate in ipairs(names) do
      if candidate:lower() == wanted then matched = candidate break end
    end
    if not matched then
      return false, ("unknown %s texture. Available: %s"):format(mediaType, table.concat(names, ", "))
    end
    value = matched
  end

  rec[field] = value
  R.Sanitize(rec)

  -- Every panel mutation is logged ONCE, here at the write seam, mirroring the settings rule
  -- (debug-logging-§10). Downstream reactors must not re-echo the same change. The one field this
  -- seam does not log is `name`: it returned into R:Rename above, which logs the old and new names
  -- itself, and only once its uniqueness checks have passed.
  --
  -- Through DebugBuild rather than Debug: R.FormatField formats (and for colors and edge sets,
  -- builds) a string, and this seam runs on every field write — every slider mouse-up, every drag
  -- stop, every `/pm panel set`. describeWrite is called only once past the sink's gate, so a user
  -- with logging off pays nothing for a line nobody reads, and the gate stays in one place.
  NS.DebugBuild("Panel", "'%s'.%s = %s", describeWrite, rec, field)
  fire(MSG_PANEL, rec.id)
  return true
end

-- Move a panel to an absolute offset. Its own seam rather than two R:Set calls because a drag
-- changes x and y together, and two calls would fire two repaints for one gesture.
function R:SetPosition(key, x, y)
  local rec = R:Resolve(key)
  if not rec then return false, ("no panel called '%s'"):format(tostring(key)) end
  rec.x, rec.y = tonumber(x) or rec.x, tonumber(y) or rec.y
  R.Sanitize(rec)
  NS.Debug("Panel", "'%s' moved to %s, %s", rec.name, rec.x, rec.y)
  fire(MSG_PANEL, rec.id)
  return true
end

-- ── Formatting ──────────────────────────────────────────────────────────────────

-- One field → display string, shared by `/pm panel show`, the CLI set echo and the debug trace, so
-- the three can never render the same value differently.
function R.FormatField(rec, field)
  local v = rec and rec[field]
  if v == nil then return "nil" end
  local kind = C.PANEL_FIELD_TYPE[field]
  if kind == "color" then return Util.FormatColor(v) end
  if kind == "edges" then return Util.FormatEdges(v) end
  if type(v) == "boolean" then return v and "true" or "false" end
  if type(v) == "number" then
    -- Alpha is fractional; everything else is a whole UI unit and reads better without ".00".
    if field == "alpha" then return ("%.2f"):format(v) end
    return tostring(Util.Round(v) == v and Util.Round(v) or v)
  end
  return tostring(v)
end

-- ── Off-screen recovery ─────────────────────────────────────────────────────────

-- Drag a panel back into view if its anchor has ended up outside the screen — after a resolution
-- change, a UI-scale change, or a copied profile from a different monitor.
--
-- Returns the number of panels moved, so the caller can report "recovered 2 panels" rather than
-- silently rearranging the user's layout. Nothing here runs automatically: a panel deliberately
-- parked mostly off-screen is a legitimate design, so recovery is `/pm recover` and the settings
-- button, never a login-time sweep.
-- The legal offset range depends on WHICH point the offset is measured from: a CENTER-anchored
-- panel runs -w/2..+w/2, a LEFT-anchored one 0..w, a RIGHT-anchored one -w..0. Using the CENTER
-- range for all nine points is what let `recover` drag a perfectly visible TOPLEFT panel inward.
local function offsetRange(point, extent)
  if point:find("LEFT")   then return 0, extent end
  if point:find("RIGHT")  then return -extent, 0 end
  return -extent / 2, extent / 2
end

-- The same rule on the vertical axis, where WoW's y grows UPWARD: a TOP-anchored panel is already at
-- the top edge, so it runs -h..0, and a BOTTOM-anchored one 0..h.
local function offsetRangeY(point, extent)
  if point:find("TOP")    then return -extent, 0 end
  if point:find("BOTTOM") then return 0, extent end
  return -extent / 2, extent / 2
end

function R:Recover()
  local w, h = NS.Compat.GetScreenSize()
  if not w then return 0 end   -- cannot measure the screen: do nothing rather than guess

  -- A panel counts as lost when its anchor offset alone puts it beyond the screen edge. The bound is
  -- taken from `relPoint` — the point on UIParent the offset is measured FROM, i.e. where on the
  -- screen the panel's origin sits — not from `point`, which only says which corner of the panel
  -- lands there.
  local moved = 0
  for _, rec in ipairs(R:All()) do
    -- Guarded the way the renderer guards it (Canvas.BuildSpec): Sanitize runs per write and on a
    -- profile switch, never as a login sweep, so a hand-edited or pre-anchor SavedVariables record
    -- reaches this loop with relPoint missing or non-string. Indexing it would throw out of the
    -- loop, leaving the panels already visited rewritten in the DB with no broadcast and no
    -- repaint — a half-applied recover is worse than none.
    local relPoint = Util.IsPoint(rec.relPoint) and rec.relPoint or C.PANEL_TEMPLATE.relPoint
    local minX, maxX = offsetRange(relPoint, w)
    local minY, maxY = offsetRangeY(relPoint, h)
    local x = Util.Clamp(rec.x, minX, maxX, 0)
    local y = Util.Clamp(rec.y, minY, maxY, 0)
    if x ~= rec.x or y ~= rec.y then
      rec.x, rec.y = x, y
      moved = moved + 1
    end
  end
  if moved > 0 then fire(MSG_PANELS) end
  return moved
end
