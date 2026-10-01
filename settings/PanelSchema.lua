local _, NS = ...
NS.PanelSchema = NS.PanelSchema or {}
local PS = NS.PanelSchema
local S = NS.Schema
local R = NS.Registry
local C = NS.Constants
local Util = NS.Util

-- The per-panel fields as schema rows: `panel.<field>`, one per C.PANEL_FIELD_ORDER field but
-- `name`, addressed by the PANEL ID as the schema runtime's instance id (architecture-§5,
-- PanelMaster#54). settings/Schema.lua's S.ResolveRoot maps that id to the Registry record, so a
-- write to `panel.width` for panel 3 lands on panel 3's record through the one seam every profile
-- setting takes -- validated and repaired by the row, logged once in the library's `[Set]` shape,
-- and announced by modules/Registry.lua, which stays the sole sender of the panel messages.
--
-- WHY A FILE OF ITS OWN. settings/Schema.lua is the profile schema and modules/Registry.lua the
-- panel set; both are large, and these rows are neither: they are the bridge, generated from
-- core/Constants.lua's field tables rather than written out, so a field added there gets its row,
-- its parse and its repair with no edit here.
--
-- WHAT THE ROWS ARE NOT. They are not profile settings, so no profile surface may show them:
-- `/pm list|get|set|reset|resetall`, the Options pages, the reset snapshot and the diagnostics dump
-- all read S.ProfileRows / S.FindProfileRow below, never the runtime's raw AllRows / FindRow. The
-- rows also carry `hidden` and `skipRender`, so a library consumer that did reach them would still
-- draw and dump nothing. `/pm panel <name> <field> <value>` stays the panel CLI, and the Panels page
-- stays the panel editor; both reach these rows through NS.Registry:Set.
--
-- `name` and `frameName` have no row: they are identity, not preferences. Create, delete and rename
-- stay structural, in the Registry.

-- kind -> coerce(value, field), returning the value to store, or nil plus the sentence to show the
-- user. Built once at file load and keyed off C.PANEL_FIELD_TYPE, so each row's normalize is a
-- lookup rather than a chain of `elseif kind ==` arms. Moved here from modules/Registry.lua with
-- PanelMaster#54: parsing what a player typed is the rows' job now, and R:Set only routes.
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

-- One coercer for every closed-list field. See enumMatch in modules/Registry.lua for why the
-- artwork enums share a kind instead of getting a branch each: they differ only in their contents,
-- so the next one is a C.PANEL_FIELD_ENUM row rather than another copy of this code.
function COERCE.enum(value, field)
  local matched, list = R.EnumMatch(field, value)
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


--- Parse one value a player typed for `field` into what the field stores: the value, or nil plus
--- the sentence to show. A field whose kind has no coercer (a free string) passes through.
function PS.Coerce(field, value)
  local coerce = COERCE[C.PANEL_FIELD_TYPE[field]]
  if not coerce then return value end
  return coerce(value, field)
end

-- The row `type` per field kind. The rows are never drawn, so this is what the boot shape check
-- reads (settings/Schema.lua's S:Register passes the five types it accepts), not a widget choice.
local ROW_TYPE = { number = "number", boolean = "bool", color = "color", edges = "table" }

-- The row's normalize: parse what a player typed (unless a record-to-record verb is writing -- see
-- R.InRecordWrite), then the field's repair, so the value stored is the value R.Sanitize would have
-- left. A nil answer is the seam's refusal, and the parse's sentence is its `why`.
local function normalizer(field)
  return function(value)
    if not R.InRecordWrite() then
      local parsed, why = PS.Coerce(field, value)
      if why then return nil, why end
      value = parsed
    end
    return R.SanitizeField(field, value)
  end
end

local function buildRows()
  local rows = {}
  for _, field in ipairs(C.PANEL_FIELD_ORDER) do
    if field ~= "name" then
      rows[#rows + 1] = {
        path = "panel." .. field, field = field, scope = "panel",
        default = C.PANEL_TEMPLATE[field],
        type = ROW_TYPE[C.PANEL_FIELD_TYPE[field]] or "string",
        group = "Panel", label = field,
        tooltip = "A per-panel field, set on the Panels page or with /pm panel <name> " .. field
          .. " <value>.",
        hidden = true, skipRender = true,
        normalize = normalizer(field),
      }
    end
  end
  return rows
end

PS.Rows = buildRows()
NS.SchemaRuntime.AddRows(PS.Rows)

-- ── The profile surfaces' view: every row but the panel rows ───────────────────
--
-- A cached array, rebuilt when the runtime's row array changes size or head (S:InstallMaster splices
-- the composed block in at the head, after this file has loaded). One array per shape, so a reader
-- that holds it across calls sees a stable table.
local profileRows, seenCount, seenHead

--- Every schema row a profile surface may show: the runtime's rows minus the `panel.*` ones.
function S.ProfileRows()
  local all = NS.SchemaRuntime.AllRows()
  if profileRows and seenCount == #all and seenHead == all[1] then return profileRows end
  local out = {}
  for _, row in ipairs(all) do
    if row.scope ~= "panel" then out[#out + 1] = row end
  end
  profileRows, seenCount, seenHead = out, #all, all[1]
  return out
end

--- The runtime's FindRow, refusing a panel row: `/pm set panel.width 5` is an unknown setting.
function S.FindProfileRow(path)
  local row = NS.SchemaRuntime.FindRow(path)
  if row and row.scope == "panel" then return nil end
  return row
end
