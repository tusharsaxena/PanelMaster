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

-- Match a value against the closed list a field belongs to (C.PANEL_FIELD_ENUM), returning the
-- CANONICAL member and the list itself: the member to store, the list for the rejection message.
--
-- One generic enum seam rather than a branch per field: artFill, artRotation and artLayer
-- are all closed sets that differ only in their contents, so four near-identical `elseif` arms in
-- R:Set would be four places to keep the coercion, the membership test and the error text agreeing.
-- Driven off the table instead, a fifth enum field later costs one C.PANEL_FIELD_ENUM row and
-- nothing else — the CLI, the validation and the sanitizer all pick it up untouched.
--
-- The coercion is chosen from the list's OWN element type rather than declared per field, because
-- the two cases already in play need different ones: artRotation stores numbers (`90`, so that
-- `artRotation / 90` is arithmetic rather than a parse) and the rest store upper-case tokens. A CLI
-- argument is always a string, so without this a typed `90` could never equal the stored 90.
local function enumMatch(field, value)
  local list = C.PANEL_FIELD_ENUM[field]
  if not list then return nil, nil end

  local wanted
  if type(list[1]) == "number" then
    wanted = tonumber(value)
  else
    wanted = tostring(value):upper()
  end

  for _, candidate in ipairs(list) do
    if candidate == wanted then return candidate, list end
  end
  return nil, list
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

-- The repair rules, as data. Almost every field in a panel record is repaired by one of five
-- identical shapes, so they are DECLARED here and applied by a loop below rather than written out
-- as fifty near-identical statements: a field added to C.PANEL_TEMPLATE later costs one row, and
-- the fallback is always the template's own value, which is the one thing that must never diverge.
-- The fields whose repair carries a real decision stay written out in R.Sanitize itself.

-- {field, min, max} — clamped into range, falling back to t[field].
local CLAMPED = {
  { "width",              C.MIN_SIZE,             C.MAX_SIZE },
  { "height",             C.MIN_SIZE,             C.MAX_SIZE },
  { "level",              0,                      100 },
  { "scale",              C.MIN_PANEL_SCALE,      C.MAX_PANEL_SCALE },
  { "borderSize",         C.MIN_BORDER,           C.MAX_BORDER },
  { "borderOffset",       C.MIN_BORDER_OFFSET,    C.MAX_BORDER_OFFSET },
  { "alpha",              0,                      1 },
  { "mouseoverAlpha",     0,                      1 },
  { "accentAlpha",        0,                      1 },
  { "accentThickness",    C.MIN_ACCENT_THICKNESS, C.MAX_ACCENT_THICKNESS },
  { "accentOffset",       C.MIN_ACCENT_OFFSET,    C.MAX_ACCENT_OFFSET },
  -- The accent bar's own border shares the panel border's bounds, so a value legal on one is legal
  -- on the other.
  { "accentBorderSize",   C.MIN_BORDER,           C.MAX_BORDER },
  { "accentBorderOffset", C.MIN_BORDER_OFFSET,    C.MAX_BORDER_OFFSET },
  { "artAlpha",           0,                      1 },
  { "artScale",           C.MIN_ART_SCALE,        C.MAX_ART_SCALE },
}

-- Numbers deliberately left UNBOUNDED. The panel's own offsets are not clamped to the screen: a
-- legitimate multi-monitor or high-resolution layout can carry offsets far outside the current
-- UIParent, and clamping on every write would quietly destroy that layout the first time the user
-- logged in at a lower resolution. Recovering a genuinely unreachable panel is R.Recover's job, and
-- it runs on demand. The art offset is unbounded for the same reason: it is measured against a panel
-- whose size is not known here, and a bound invented at this point would clamp a perfectly good
-- placement on a large panel the first time the record was touched.
local FREE_NUMBERS = { "x", "y", "artX", "artY" }

-- Names that must be a NON-EMPTY string; an empty one is a dropped key rather than a choice.
--
-- Media names are kept as free strings and NOT validated against the live LibSharedMedia list: an
-- addon that registers a texture may load after this one, so a name that resolves to nothing right
-- now can be perfectly valid a second later. Compat.FetchMedia degrades at render time instead,
-- which keeps the user's choice in the file rather than silently rewriting it to the default.
--
-- artTexture is NOT validated against the live catalog here for the same reason: an id that resolves
-- to nothing right now can be perfectly valid a moment later (an art pack appending to the artwork
-- catalog loads after this addon), and BuildArtSpec already degrades an unresolvable id to "draw
-- nothing" at render time. Rewriting it to "None" on the first touch would destroy the user's choice
-- permanently to fix a problem that fixes itself. R:Set still refuses a typo up front, which is when
-- there is somebody to tell. artCustomPath is NOT on this list — see R.Sanitize.
local NONEMPTY_STRINGS = {
  "bgTexture", "borderTexture", "accentTexture", "accentBorderTexture", "artTexture",
}

local POINT_FIELDS = { "point", "relPoint", "artPoint" }

-- The closed lists snap back to their template default when what is stored is not a member.
-- A hand-edited SavedVariables file carrying artFill = "COVER" must not reach the renderer: every
-- fill branch computes a different rectangle and a different set of texture coordinates, so an
-- unknown token would either fall through to whichever branch happens to be last or produce a nil
-- size that lands in SetSize — a Lua error inside a paint, which aborts the rest of that panel's
-- render and leaves it half-drawn. Snapping to the default here means the worst outcome of a
-- corrupt file is artwork that looks wrong, which the user can see and re-pick.
--
-- enumMatch also normalizes case, so a lower-case token typed straight into the file is repaired
-- rather than discarded.
local ENUM_FIELDS = { "artFill", "artRotation", "artLayer" }

-- Flags coerced to a real boolean. `enabled` is NOT one of them — nil means enabled there, which is
-- the opposite default and is written out in R.Sanitize.
local BOOL_FIELDS = { "mouseover", "accentEnabled", "artFlipH", "artFlipV" }

local function sanitizeNumbers(rec, t)
  for _, rule in ipairs(CLAMPED) do
    rec[rule[1]] = Util.Clamp(rec[rule[1]], rule[2], rule[3], t[rule[1]])
  end
  for _, field in ipairs(FREE_NUMBERS) do
    rec[field] = tonumber(rec[field]) or t[field]
  end
end

local function sanitizeTokens(rec, t)
  for _, field in ipairs(NONEMPTY_STRINGS) do
    if type(rec[field]) ~= "string" or rec[field] == "" then rec[field] = t[field] end
  end
  for _, field in ipairs(POINT_FIELDS) do
    if not Util.IsPoint(rec[field]) then rec[field] = t[field] end
  end
  for _, field in ipairs(ENUM_FIELDS) do
    rec[field] = enumMatch(field, rec[field]) or t[field]
  end
end

local function sanitizeFlags(rec)
  for _, field in ipairs(BOOL_FIELDS) do
    rec[field] = rec[field] and true or false
  end
  -- Class-color flags, driven off C.COLOR_FIELDS so a color added later needs no edit here.
  for _, flag in pairs(C.COLOR_FIELDS) do
    rec[flag] = rec[flag] and true or false
  end
end

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

  -- The stored frame name is stamped at create and NEVER recomputed from the name afterwards — that
  -- is the whole point of storing it (see R.FrameName). So this fills it only when it is missing:
  -- a record from a build before frame names were stored, or a hand-edited SavedVariables file that
  -- dropped the key. Deriving it from the current name is exactly what the old build would have
  -- rendered it as, so an upgrade is invisible.
  --
  -- NS:RunMigrations stamps the whole profile at login; this is the same repair reached from the
  -- write seam, for a record that arrives by some other route (an imported profile, a test).
  if type(rec.frameName) ~= "string" or rec.frameName == "" then
    rec.frameName = Util.FrameName(rec.name)
  end

  -- Strata has its own predicate rather than a rule table row: it is the one token field that is not
  -- a point.
  if not Util.IsStrata(rec.strata) then rec.strata = t.strata end

  rec.bgColor     = Util.Color(rec.bgColor, t.bgColor)
  rec.borderColor = Util.Color(rec.borderColor, t.borderColor)
  rec.artColor    = Util.Color(rec.artColor, t.artColor)

  -- The accent edge set is normalized rather than defaulted: an EMPTY set is a legitimate state
  -- (the user unticked every edge) and must not be quietly repopulated with TOP, so only a
  -- non-table falls back to the template's.
  rec.accentEdges = Util.EdgeSet(
    type(rec.accentEdges) == "table" and rec.accentEdges or t.accentEdges)

  -- An EMPTY custom path is a legitimate state — the user has picked Custom and has not typed the
  -- path yet — so only a non-string falls back, the same distinction the accent edge set makes.
  if type(rec.artCustomPath) ~= "string" then rec.artCustomPath = t.artCustomPath end

  sanitizeNumbers(rec, t)
  sanitizeTokens(rec, t)
  sanitizeFlags(rec)

  return rec
end

-- ── Frame name ──────────────────────────────────────────────────────────────────

-- The global frame name this panel's frame carries, e.g. `PanelMaster_Panel_Chat_BG`. Part of the
-- addon's public contract: other addons anchor to it by name (see C.FRAME_NAME_PREFIX).
--
-- STORED on the record and stamped once at create time, rather than derived from the name on every
-- read. A frame's name is immutable after CreateFrame, so a name-derived frame name meant a rename
-- had to abandon the old frame and stand up a new one — which orphaned every external anchor
-- silently and leaked one frame per rename. Stamping it at create makes the frame name a property of
-- the panel's IDENTITY, like its id, so a rename is a relabel and nothing else.
--
-- The fallback is the migration path in one expression: a record written before this build carries
-- no `frameName`, and deriving it from the name reproduces exactly the name its frame already has.
function R.FrameName(rec)
  if not rec then return Util.FrameName(nil) end
  if type(rec.frameName) == "string" and rec.frameName ~= "" then return rec.frameName end
  return Util.FrameName(rec.name)
end

-- Is `frameName` already carried by a panel other than `exceptID`?
--
-- Two frames cannot share a global name: the second would either fail to be created or silently
-- steal the first's global, and anything anchored to it would end up attached to the wrong panel.
-- Names are unique, but frame names are COARSER than names — "Chat BG" and "Chat-BG" are two legal
-- panel names that slugify to one frame name — so this is a check of its own, not a corollary of the
-- name check.
--
-- Compares against the STORED frame name rather than re-slugifying each name, because after a rename
-- the two no longer agree and it is the stored one that a frame actually answers to.
local function frameNameTaken(frameName, exceptID)
  for _, rec in ipairs(R:All()) do
    if rec.id ~= exceptID and R.FrameName(rec) == frameName then return rec end
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

-- The four "new panel" settings, applied over C.PANEL_TEMPLATE.
--
-- ONE function with two callers, because the two callers must not be able to disagree: R:Reset's
-- own comment is that "reset this panel" and "make a new one" land on the same state, and that was
-- true only for as long as both were two hand-written lines. Size joined strata and opacity as a
-- setting in the tabbed-panel pass, and two more hand-written lines in each place is exactly how
-- the drift the comment forbids gets in.
--
-- A field falls back to whatever C.PANEL_TEMPLATE already put there, so a profile written before
-- these settings existed (or one hand-edited to nonsense) still creates the panel this addon has
-- always created rather than one with a nil width. Sanitize clamps afterwards either way.
local function applyNewPanelDefaults(rec, p)
  local s = p.settings or {}
  rec.width  = tonumber(s.defaultWidth)  or rec.width
  rec.height = tonumber(s.defaultHeight) or rec.height
  rec.strata = s.defaultStrata or rec.strata
  rec.alpha  = tonumber(s.defaultAlpha)  or rec.alpha
end

-- Create a panel. Returns (record) on success, or (nil, reason) — never a bare nil, so every caller
-- has something to print.
--
-- `overrides` is an optional partial record (preview mode and the CLI both pass one). New panels
-- pick up the profile's four new-panel defaults (size, strata, opacity), which is what makes those
-- settings meaningful; an override still wins, because it is applied afterwards.
-- The create itself, WITHOUT the broadcast. Split out so a batch (preview mode stands up three
-- placeholders at once) can make every record and then announce the new set exactly once, rather
-- than making every consumer rebuild itself once per record.
local function create(name, overrides)
  local p = NS.db and NS.db.profile
  if not p then return nil, "database not ready" end

  name = Util.CleanName(name)
  if not name then return nil, "a panel needs a name" end
  if R:FindByName(name) then return nil, ("a panel named '%s' already exists"):format(name) end
  -- The frame name this panel would be born with. Checked BEFORE the record is made, because the
  -- stamp is permanent: unlike the old derived name, a clash discovered later cannot be fixed by
  -- renaming the panel.
  local frameName = Util.FrameName(name)
  local clash = frameNameTaken(frameName)
  if clash then
    return nil, ("'%s' would share the frame name %s with '%s' \226\128\148 pick another name")
      :format(name, frameName, clash.name)
  end

  local rec = Util.DeepCopy(C.PANEL_TEMPLATE)
  rec.name = name
  applyNewPanelDefaults(rec, p)

  if type(overrides) == "table" then
    for k, v in pairs(overrides) do
      if k ~= "id" then rec[k] = Util.DeepCopy(v) end   -- the id is ours to assign, never theirs
    end
  end

  rec.id = p.nextID or 1
  p.nextID = rec.id + 1
  -- Stamped AFTER the overrides loop, alongside the id and for the same reason: both are identity,
  -- and neither is a caller's to supply. A preview spec or a CLI override that carried a frameName
  -- would otherwise hand this panel another panel's global.
  rec.frameName = frameName

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
-- `id`, `name` and `frameName` survive, because they are what the panel IS rather than how it looks:
-- resetting must not change the frame name and break anything anchored to it.
--
-- The profile's New-Panel-Defaults are applied exactly as R:New applies them, so "reset" and "make a
-- new one" land on the same state — otherwise the two would drift the moment a user changed their
-- defaults.
--
-- A PREVIEW PLACEHOLDER is refused outright. The reset rewrites the record from C.PANEL_TEMPLATE,
-- which deliberately carries no preview marker (see C.PREVIEW_FIELD), so resetting one stripped its
-- marker and promoted a throwaway placeholder into a permanent panel that survived the next sweep —
-- the one path by which test mode could leave litter in a real layout. Refusing rather than
-- re-stamping, because resetting a placeholder to the shipped template is not a meaningful thing to
-- want, and a reason the caller can print is more use than silently doing nothing.
function R:Reset(key)
  local p = NS.db and NS.db.profile
  if not p then return false, "database not ready" end
  local rec = R:Resolve(key)
  if not rec then return false, ("no panel called '%s'"):format(tostring(key)) end
  if rec[C.PREVIEW_FIELD] then
    return false, ("'%s' is a test-mode placeholder \226\128\148 turn test mode off to remove it")
      :format(rec.name)
  end

  local id, name, frameName = rec.id, rec.name, rec.frameName
  for k in pairs(rec) do rec[k] = nil end
  for k, v in pairs(C.PANEL_TEMPLATE) do rec[k] = Util.DeepCopy(v) end
  rec.id, rec.name, rec.frameName = id, name, frameName
  applyNewPanelDefaults(rec, p)
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
-- `id`, `name` and `frameName` are identity: copying them would either clash or rename — and
-- copying the frame name in particular would hand the target another panel's global, which is the
-- one collision the registry spends two checks preventing. The four geometry fields
-- are position — the whole reason to copy settings from another panel is to make this one MATCH it
-- while staying where it is; a copy that also moved it would land the two exactly on top of each
-- other, which is never what was wanted. Size IS copied: two panels of matching appearance usually
-- want matching dimensions, and unlike position that does not make one of them disappear.
--
-- The preview marker is excluded for a different reason: it is not appearance at all but a lifetime
-- flag, and smearing it onto a real panel would make that panel vanish at the next sweep.
local COPY_EXCLUDED = {
  id = true, name = true, frameName = true,
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
-- EVERY SESSION TABLE KEYED BY PANEL ID IS DROPPED FIRST, and this is the load-bearing half.
--
-- Panel ids are allocated per PROFILE — `nextID` lives in `db.profile` and a fresh profile starts at
-- 1 — so the same id names a different panel in every profile, and any id held in session state is
-- not stale-but-harmless after a switch, it is a live reference to somebody else's panel. Three
-- tables held one:
--
--   NS.State.previewIDs   — the destructive one. `/pm preview` on, switch profile, `/pm preview` off
--                           called DeleteBatch with the OLD profile's ids, which resolved against
--                           the NEW profile and destroyed real user panels. Cleared with the
--                           `preview` flag itself, because a flag left true makes SetPreview(true)
--                           return early and the user cannot even restart preview to clear it.
--   NS.State.unlockedPanels — a panel in the incoming profile came up individually unlocked, with a
--                           drag handle the user never asked for, because it happened to inherit an
--                           id someone unlocked in the profile they left.
--   NS.Unlock's pendingPanels — the same, for unlocks deferred by combat.
--
-- This is exactly the sweep R:DeleteAll already does, and for the same reason: an incoming profile
-- shares no identity with the outgoing one, so nothing keyed on the outgoing one survives. Done
-- BEFORE Sanitize and the broadcast, so no consumer can observe the half-swapped state.
--
-- The global unlock flag is deliberately NOT cleared. It is a mode the user put the SCREEN in, not a
-- claim about any particular panel, and a profile switch mid-edit that silently re-locked everything
-- would be its own surprise.
local function dropSessionIDs()
  for id in pairs(NS.State.unlockedPanels) do NS.State.unlockedPanels[id] = nil end
  for i = #NS.State.previewIDs, 1, -1 do NS.State.previewIDs[i] = nil end
  NS.State.preview = false
  if NS.Unlock and NS.Unlock.ForgetPending then NS.Unlock:ForgetPending() end
  -- The Panels page's open editor is the fourth holder of an id, for the same reason and with the
  -- same consequence: it would resolve to whichever panel the incoming profile has under that id.
  if NS.PanelEditor and NS.PanelEditor.ForgetSelection then NS.PanelEditor:ForgetSelection() end
end

function R:ReloadProfile()
  dropSessionIDs()
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

  -- No frame-name check here, deliberately. The frame name is stamped at create and a rename does
  -- not touch it (see R.FrameName), so renaming cannot produce a collision — there is no second
  -- global being claimed. That also means a rename no longer has to be refused for slugging to a
  -- name already in use: "Chat-BG" is now a legal new name for a panel even while "Chat BG" exists,
  -- because the two keep the distinct frame names they were born with.
  local old = rec.name
  rec.name = newName
  NS.Debug("Panel", "renamed '%s' -> '%s' (frame name stays %s)", old, newName, R.FrameName(rec))
  fire(MSG_PANELS)   -- structural: the name is how every list and dropdown labels the panel
  return true, old
end

-- ── Fit to artwork ──────────────────────────────────────────────────────────────

-- Set a panel to the artwork's own pixel dimensions -- BOTH axes.
--
-- A 1024x1024 bundled piece gives a 1024x1024 panel; a three-section Sunn bar is 1536x256 and gives
-- exactly that. For a composed row the size is the VIRTUAL bar's, not one section's, because
-- Artwork.NativeSize already answers for the whole piece a panel draws.
--
-- This deliberately replaces an earlier design that derived only the HEIGHT, keeping the width the
-- user had chosen. That was the right call while fitting was an always-on flag: a mode that
-- reshaped panels on every width change had to disturb as little as possible, and adopting native
-- size would have thrown a 1024px wall across the screen for one piece and a letterbox for another.
-- As a BUTTON the trade inverts -- nothing happens unless it is pressed, so the honest answer to
-- "fit this panel to its artwork" is the artwork's actual size, and a panel that comes out too big
-- is resized by the same hand that asked.
--
-- A no-op unless the panel actually draws something: one naming art that is not installed keeps the
-- shape it had, so pressing the button with a missing Sunn pack reports nothing rather than
-- collapsing the panel.
--
-- ROTATION and SCALE are part of the answer, because they are part of how big the art actually is
-- on screen. A quarter turn transposes the axes, so a 1536x256 bar turned 90 degrees wants a
-- 256x1536 panel; and artScale is the multiplier the art is drawn at, so a piece at 0.5 wants half
-- the panel. Ignoring either produced a panel the art then sat inside letterboxed, which is exactly
-- what pressing this is meant to eliminate.
--
-- The target is the size STATIC draws the art at -- the piece's own presented size, which is what
-- "fit the panel to the artwork" means. At the resulting size STRETCH, FILL and TILE have nothing
-- left to distort, crop or repeat either.
--
-- FIT is the one fill that will still not fill the panel, and that is FIT's own definition rather
-- than a miss here: it contains the art in the panel and THEN applies artScale, so at scale 0.5 it
-- draws at half of whatever it was given. Fitting to FIT's output instead would be a fixed point
-- only at scale 1 and a shrinking spiral below it -- press twice at 0.5 and the panel is a quarter
-- the size, press again and it is a sixteenth.
--
-- Unpublished and side-effect-free beyond the record: it mutates and reports whether anything moved,
-- but does not sanitize, fire or log. R:FitToArtwork below is the seam callers use.
function R.ApplyArtSize(rec)
  if type(rec) ~= "table" then return false end
  -- Guarded on its own line, NOT as `local w, h = NS.Artwork and ... and NativeSize(rec)`. An `and`
  -- chain is adjusted to ONE value in a multiple assignment, so that spelling silently drops `h` and
  -- the fit becomes a half-applied no-op that looks correct.
  if not (NS.Artwork and NS.Artwork.NativeSize) then return false end
  local w, h = NS.Artwork.NativeSize(rec)
  if not w or not h then return false end

  -- Read through the same enum/clamp seams the fill math uses, so a record holding junk fits to the
  -- size it will actually be DRAWN at rather than to the junk. A rotation of "banana" is 0 in both
  -- places, not 0 here and a fallback there.
  local rotation = C.PANEL_FIELD_ENUM.artRotation and tonumber(rec.artRotation) or nil
  if rotation ~= 90 and rotation ~= 180 and rotation ~= 270 then rotation = 0 end
  if rotation == 90 or rotation == 270 then w, h = h, w end

  local scale = Util.Clamp(rec.artScale, C.MIN_ART_SCALE, C.MAX_ART_SCALE,
    C.PANEL_TEMPLATE.artScale)
  w, h = w * scale, h * scale

  -- Rounded to whole pixels: a fractional frame size renders on a half-pixel boundary and blurs the
  -- border, and the stored value is what every later comparison reads. Both the overlap crop
  -- (256 x 0.70703 = 181.0) and any non-integer scale get here, so this is well traveled.
  local width = math.floor(w + 0.5)
  local height = math.floor(h + 0.5)
  if width == rec.width and height == rec.height then return false end
  rec.width, rec.height = width, height
  return true
end

-- Fit one panel to its artwork, once, and tell the caller what happened.
--
-- The published seam, and deliberately shaped like R:Set rather than like a widget callback: the
-- editor button and `/pm panel <name> fitart` are both callers, and an action that sanitized in one
-- path and not the other is the kind of divergence the single write seam exists to prevent.
--
-- Sanitize runs AFTER the sizing, so the adopted dimensions meet the same MIN/MAX clamp every stored
-- size does and a 4096px piece cannot push a panel outside C.MIN_SIZE/C.MAX_SIZE. A clamp is why the
-- success value is read back off the record rather than returned from the arithmetic.
--
-- Returns false plus a reason the caller can print, rather than failing silently. "This panel draws
-- no artwork" and "the art it names is not installed" are the two ways a player reaches this button
-- and sees nothing happen, and both deserve a sentence.
function R:FitToArtwork(key)
  local rec = R:Resolve(key)
  if not rec then return false, ("no panel called '%s'"):format(tostring(key)) end

  local beforeW, beforeH = rec.width, rec.height
  if not R.ApplyArtSize(rec) then
    if not (NS.Artwork and NS.Artwork.NativeSize and NS.Artwork.NativeSize(rec)) then
      return false, "this panel draws no artwork to fit to"
    end
    return false, "already fitted to its artwork"
  end
  R.Sanitize(rec)

  NS.Debug("Panel", "fit '%s' to artwork: %sx%s -> %sx%s", rec.name, tostring(beforeW),
    tostring(beforeH), tostring(rec.width), tostring(rec.height))
  fire(MSG_PANEL, rec.id)
  return true, rec.width, rec.height
end

-- ── Field edits ─────────────────────────────────────────────────────────────────

-- kind -> coerce(value, field), returning the value to store, or nil plus the sentence to show the
-- user. Built once at file load and keyed off C.PANEL_FIELD_TYPE, so the write seam below is a
-- lookup rather than a chain of `elseif kind ==` arms.
--
-- A kind ABSENT from this table is stored verbatim — that is "string" (artCustomPath), and it is
-- exactly what the old chain's fall-through did.
local COERCE = {}

function COERCE.number(value)
  local n = tonumber(value)
  if n == nil then return nil, "expected a number" end
  return n
end

function COERCE.boolean(value)
  local parsed = Util.ParseBool(value)
  if parsed == nil then return nil, Util.BOOL_USAGE end
  return parsed
end

function COERCE.point(value)
  value = tostring(value):upper()
  if not Util.IsPoint(value) then
    return nil, "expected one of: " .. table.concat(C.POINTS, ", ")
  end
  return value
end

function COERCE.strata(value)
  value = tostring(value):upper()
  if not Util.IsStrata(value) then
    return nil, "expected one of: " .. table.concat(C.STRATA, ", ")
  end
  return value
end

function COERCE.color(value)
  if type(value) ~= "table" then
    local parsed = Util.ParseColor(value)
    if not parsed then return nil, "expected r,g,b[,a] (0-1 or 0-255)" end
    return parsed
  end
  return value
end

function COERCE.edges(value)
  if type(value) ~= "table" then
    local parsed = Util.ParseEdges(value)
    if not parsed then
      return nil, ("expected any of: %s (or 'none')"):format(table.concat(C.EDGES, ", "):lower())
    end
    value = parsed
  end
  -- Copied, not aliased, on BOTH paths: a caller that keeps its table would otherwise be able to
  -- mutate the stored set behind the registry's back, skipping the write seam entirely.
  return Util.EdgeSet(value)
end

-- Matched case-insensitively against the LIVE LibSharedMedia list so the CLI accepts
-- `/pm panel X bgTexture blizzard marble` for "Blizzard Marble", and so a typo is refused with
-- the real list rather than silently stored and resolved to the fallback at render time.
function COERCE.media(value, field)
  value = tostring(value)
  local mediaType = C.PANEL_FIELD_MEDIA[field]
  local names = NS.Compat.MediaList(mediaType)
  local wanted, matched = value:lower(), nil
  for _, candidate in ipairs(names) do
    if candidate:lower() == wanted then matched = candidate break end
  end
  if not matched then
    return nil, ("unknown %s texture. Available: %s"):format(mediaType, table.concat(names, ", "))
  end
  return matched
end

-- One coercer for every closed-list field. See enumMatch above for why the artwork enums share a
-- kind instead of getting a branch each: they differ only in their contents, so the next one is a
-- C.PANEL_FIELD_ENUM row rather than another copy of this code.
function COERCE.enum(value, field)
  local matched, list = enumMatch(field, value)
  -- A field typed "enum" with no list is a Constants bug, not user error, so say so rather than
  -- crashing table.concat on a nil.
  if not list then return nil, ("'%s' has no value list"):format(tostring(field)) end
  if not matched then
    return nil, "expected one of: " .. table.concat(list, ", ")
  end
  return matched
end

-- Matched case-insensitively against the LIVE catalog, mirroring the media coercer above and
-- for the same reason: a typo must come back with the real list of ids rather than being stored
-- and then silently resolving to nothing at render time, which reads as "artwork is broken"
-- instead of "that is not one of the names".
--
-- Artwork.List() is the source rather than the raw catalog because it already carries the two
-- reserved ids in their agreed places — "None" first, "Custom" last — so accepting them costs
-- nothing here and the offered order matches what the dropdown shows.
function COERCE.artwork(value)
  value = tostring(value)
  local wanted, matched, ids = value:lower(), nil, {}
  for _, entry in ipairs(NS.Artwork.List()) do
    ids[#ids + 1] = entry.id
    if tostring(entry.id):lower() == wanted then matched = entry.id end
  end
  if not matched then
    return nil, ("unknown artwork. Available: %s"):format(table.concat(ids, ", "))
  end
  return matched
end

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

  -- `err` rather than a nil test on the coerced value: the boolean coercer's success value is
  -- legitimately `false`, and a nil test would refuse every `/pm panel X mouseover off`.
  local coerce = COERCE[kind]
  if coerce then
    local coerced, err = coerce(value, field)
    if err then return false, err end
    value = coerced
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

-- ── Reset position ──────────────────────────────────────────────────────────────

-- Put every panel back where a new one starts: the Master controls tab's `Reset position`
-- (options-ui-§15), which is addon-wide because this addon's frames are per-panel and the master
-- rows are the addon-wide ones.
--
-- The ANCHOR only — point, relPoint and the two offsets. Not the size, not the colors, not the
-- artwork: a button labeled "Reset position" that also reset an evening's worth of sizing would be
-- doing something its own label did not warn about, which is the failure options-ui-§12 spends its
-- whole length preventing at the global scale. R:Reset is the per-panel verb that does take the
-- whole record, and it is confirmed on its own control.
--
-- Distinct from R:Recover, which is the other thing on this page that moves panels: recover clamps
-- an anchor that has ended up beyond a screen edge and leaves everything already visible exactly
-- where it is, while this one moves every panel whatever it was doing.
--
-- Returns the number of panels moved, so the caller can say so rather than silently rearranging the
-- user's layout.
function R:ResetPositions()
  local t = C.PANEL_TEMPLATE
  local moved = 0
  for _, rec in ipairs(R:All()) do
    if rec.point ~= t.point or rec.relPoint ~= t.relPoint
       or rec.x ~= t.x or rec.y ~= t.y then
      rec.point, rec.relPoint, rec.x, rec.y = t.point, t.relPoint, t.x, t.y
      moved = moved + 1
    end
  end
  if moved > 0 then fire(MSG_PANELS) end
  return moved
end
