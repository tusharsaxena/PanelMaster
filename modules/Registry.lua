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

  -- Class-colour flags, driven off C.COLOR_FIELDS so a colour added later needs no edit here.
  for _, flag in pairs(C.COLOR_FIELDS) do
    rec[flag] = rec[flag] and true or false
  end

  rec.mouseover      = rec.mouseover and true or false
  rec.mouseoverAlpha = Util.Clamp(rec.mouseoverAlpha, 0, 1, t.mouseoverAlpha)

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
function R:New(name, overrides)
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

  if NS.State.debug and NS.Debug then
    NS.Debug("Panel", "created '%s' (id %s)", rec.name, rec.id)
  end
  fire(MSG_PANELS)
  return rec
end

function R:Delete(key)
  local p = NS.db and NS.db.profile
  if not p then return false, "database not ready" end
  local rec = R:Resolve(key)
  if not rec then return false, ("no panel called '%s'"):format(tostring(key)) end

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

  if NS.State.debug and NS.Debug then
    NS.Debug("Panel", "deleted '%s' (id %s)", rec.name, rec.id)
  end
  fire(MSG_PANELS)
  return true, rec.name
end

-- Restore one panel to how a freshly created panel would look, keeping only its identity.
--
-- "Reset" means the whole record — size, position, anchor, strata, textures, colours, mouseover —
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

  if NS.State.debug and NS.Debug then
    NS.Debug("Panel", "reset '%s' (id %s)", rec.name, rec.id)
  end
  -- A field-level change, not a structural one: the SET of panels is unchanged, so the targeted
  -- repaint is the honest message. The settings editor rebuilds itself separately — its widgets all
  -- hold stale values now, which is a UI concern rather than something the bus should imply.
  fire(MSG_PANEL, rec.id)
  return true, rec.name
end

-- Remove every panel. Returns how many went, so the caller can report it.
function R:DeleteAll()
  local p = NS.db and NS.db.profile
  if not p then return 0 end
  local n = #p.panels
  for i = n, 1, -1 do p.panels[i] = nil end
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
  if NS.State.debug and NS.Debug then
    NS.Debug("Panel", "renamed '%s' -> '%s'", old, newName)
  end
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
    if type(value) ~= "boolean" then
      local s = tostring(value):lower()
      value = (s == "true" or s == "1" or s == "on" or s == "yes")
    end
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
  -- (debug-logging-§10). Downstream reactors must not re-echo the same change.
  if NS.State.debug and NS.Debug then
    NS.Debug("Panel", "'%s'.%s = %s", rec.name, field, R.FormatField(rec, field))
  end
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
  if NS.State.debug and NS.Debug then
    NS.Debug("Panel", "'%s' moved to %s, %s", rec.name, rec.x, rec.y)
  end
  fire(MSG_PANEL, rec.id)
  return true
end

-- ── Formatting ──────────────────────────────────────────────────────────────────

-- One field → display string, shared by `/pm panel show`, the CLI set echo and the debug trace, so
-- the three can never render the same value differently.
function R.FormatField(rec, field)
  local v = rec and rec[field]
  if v == nil then return "nil" end
  if C.PANEL_FIELD_TYPE[field] == "color" then return Util.FormatColor(v) end
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
function R:Recover()
  local w, h = NS.Compat.GetScreenSize()
  if not w then return 0 end   -- cannot measure the screen: do nothing rather than guess

  -- A panel counts as lost when its anchor offset alone puts it beyond the screen edge. Half the
  -- screen in each direction is the bound because offsets are measured from an anchor POINT, and
  -- CENTER — the default — sits at the middle.
  local maxX, maxY = w / 2, h / 2
  local moved = 0
  for _, rec in ipairs(R:All()) do
    local x = Util.Clamp(rec.x, -maxX, maxX, 0)
    local y = Util.Clamp(rec.y, -maxY, maxY, 0)
    if x ~= rec.x or y ~= rec.y then
      rec.x, rec.y = x, y
      moved = moved + 1
    end
  end
  if moved > 0 then fire(MSG_PANELS) end
  return moved
end
