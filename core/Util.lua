local addonName, NS = ...   -- luacheck: ignore addonName
NS.Util = NS.Util or {}
local Util = NS.Util
local C = NS.Constants

-- Split a dotted settings path ("panels.gridSize") into components.
function Util.SplitPath(path)
  local parts = {}
  for p in tostring(path):gmatch("[^.]+") do
    parts[#parts + 1] = p
  end
  return parts
end

-- Clamp n into [lo, hi]. Non-numbers fall back to `fallback` (then to lo), so a hand-edited
-- SavedVariables string can never propagate into a SetWidth call.
function Util.Clamp(n, lo, hi, fallback)
  n = tonumber(n)
  if n == nil then n = tonumber(fallback) or lo end
  if n < lo then return lo end
  if n > hi then return hi end
  return n
end

-- Round to the nearest whole number. Lua 5.1 has no math.round, and floor(n + 0.5) is wrong for
-- negatives (it biases toward +inf), which matters because panel offsets are routinely negative.
function Util.Round(n)
  n = tonumber(n) or 0
  if n < 0 then return -math.floor(-n + 0.5) end
  return math.floor(n + 0.5)
end

-- Snap a coordinate to the nearest multiple of `grid`. A grid of 1 (or less) is the identity, which
-- is what "snapping off" means — the caller never has to branch.
function Util.Snap(n, grid)
  grid = tonumber(grid) or 1
  if grid <= 1 then return Util.Round(n) end
  return Util.Round((tonumber(n) or 0) / grid) * grid
end

-- ── Booleans ────────────────────────────────────────────────────────────────────

-- The accepted spellings of yes and no, shared so the CLI and the registry can never disagree about
-- what "on" means. The error text below lists exactly these, so the two stay in step.
local BOOL_TOKENS = {
  ["true"] = true, ["on"] = true,  ["yes"] = true, ["1"] = true,
  ["false"] = false, ["off"] = false, ["no"] = false, ["0"] = false,
}

-- The message every caller prints when ParseBool comes back nil. One string, so `/pm set` and
-- `/pm panel` refuse a typo in the same words (slash-commands-§5).
Util.BOOL_USAGE = "expected true/false (or on/off, yes/no, 1/0)"

-- A user-typed boolean → true, false, or nil for "I could not read that".
--
-- The nil is the whole point. Both call sites used to coerce with `s == "true" or s == "1" or …`,
-- which reads every typo as false — so `/pm set settings.enabled ture` turned panels OFF and echoed
-- `= false` as though that had been asked for. Every other type in both dispatchers reports a parse
-- failure; booleans do too now, which is a deliberate user-visible change.
function Util.ParseBool(s)
  if type(s) == "boolean" then return s end
  if type(s) ~= "string" and type(s) ~= "number" then return nil end
  return BOOL_TOKENS[tostring(s):lower()]
end

-- ── Colors ─────────────────────────────────────────────────────────────────────

-- A normalized {r, g, b, a} array from an arbitrary stored value. Every component is clamped to
-- 0..1 and alpha defaults to 1, so a partial or malformed color still renders something visible
-- instead of erroring inside SetColorTexture.
function Util.Color(v, fallback)
  local src = (type(v) == "table") and v or fallback or { 1, 1, 1, 1 }
  return {
    Util.Clamp(src[1], 0, 1, 1),
    Util.Clamp(src[2], 0, 1, 1),
    Util.Clamp(src[3], 0, 1, 1),
    Util.Clamp(src[4] == nil and 1 or src[4], 0, 1, 1),
  }
end

-- "r,g,b,a" → a color array, for `/pm panel set <name> bgColor 0.1,0.1,0.1,0.8`. Accepts 3 or 4
-- components (alpha defaults to 1) and 0-255 byte input as well as 0-1.
--
-- The byte-vs-fraction decision reads only R, G and B, and then applies to all four: a hex color
-- pasted as bytes carries its alpha as a byte too, and alpha alone is not a reliable signal (a
-- fully-opaque byte alpha is 255, but a fully-opaque fractional one is 1, and "1" is a legal value
-- in both readings). Deciding on the three unambiguous components and following through is the only
-- rule that round-trips both forms.
--
-- Returns nil on anything unparseable, which the CLI reports rather than silently storing white.
function Util.ParseColor(s)
  if type(s) ~= "string" then return nil end
  local nums = {}
  for part in s:gmatch("[^,%s]+") do
    local n = tonumber(part)
    if n == nil then return nil end
    nums[#nums + 1] = n
  end
  if #nums < 3 or #nums > 4 then return nil end
  local scale = 1
  for i = 1, 3 do
    if nums[i] > 1 then scale = 255 break end
  end
  return {
    nums[1] / scale, nums[2] / scale, nums[3] / scale,
    (nums[4] == nil and 1 or nums[4] / scale),
  }
end

-- A color array → the "r,g,b,a" form ParseColor accepts, for the CLI echo and `/pm panel show`.
-- Round-trips: FormatColor(ParseColor(s)) parses back to the same color.
function Util.FormatColor(c)
  c = Util.Color(c)
  return ("%.2f,%.2f,%.2f,%.2f"):format(c[1], c[2], c[3], c[4])
end

-- ── Edge sets ───────────────────────────────────────────────────────────────────

-- A normalized edge set from an arbitrary stored value: only the four real edge keys survive, and
-- every value becomes a plain `true`. A hand-edited SavedVariables file cannot smuggle a fifth
-- "edge" into the renderer's loop this way.
function Util.EdgeSet(v)
  local out = {}
  if type(v) ~= "table" then return out end
  for edge, on in pairs(v) do
    if on and C.EDGE_SET[edge] then out[edge] = true end
  end
  return out
end

-- "top,left" → { TOP = true, LEFT = true }, for `/pm panel X accentEdges top,left`.
-- "none" (or an empty list) → the empty set, which is how the CLI says "no bars".
-- Returns nil for anything containing a name that is not an edge, so a typo is reported with the
-- valid list rather than silently dropping that edge.
function Util.ParseEdges(s)
  if type(s) ~= "string" then return nil end
  if s:lower():match("^%s*none%s*$") then return {} end
  local out, any = {}, false
  for part in s:gmatch("[^,%s]+") do
    local edge = part:upper()
    if not C.EDGE_SET[edge] then return nil end
    out[edge] = true
    any = true
  end
  if not any then return nil end
  return out
end

-- An edge set → the "TOP, LEFT" form ParseEdges accepts, always in C.EDGES order so the same set
-- never renders two different ways. The empty set prints "(none)", matching how the CLI reports
-- every other empty collection.
function Util.FormatEdges(v)
  local set = Util.EdgeSet(v)
  local parts = {}
  for _, edge in ipairs(C.EDGES) do
    if set[edge] then parts[#parts + 1] = edge end
  end
  if #parts == 0 then return "(none)" end
  return table.concat(parts, ", ")
end

-- ── Names ───────────────────────────────────────────────────────────────────────

-- Trim and collapse whitespace in a user-supplied panel name. Returns nil for an empty result, so
-- callers get one "no name given" answer instead of having to test for "", " " and nil separately.
function Util.CleanName(s)
  if s == nil then return nil end
  s = tostring(s):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
  if s == "" then return nil end
  return s
end

-- A panel name → the slug used in its global frame name. Deterministic and stable: the same name
-- always produces the same slug, which is the whole point — another addon anchors to
-- `PanelMaster_Panel_<slug>` and must be able to work that name out from the panel name alone.
--
-- Every run of non-alphanumerics collapses to a single underscore, and leading/trailing underscores
-- are trimmed, so "Chat  BG!" and "Chat-BG" both give "Chat_BG". Case is PRESERVED (frame names are
-- case-sensitive and "ChatBG" reads better than "chatbg"), which means two panel names differing
-- only in case would collide — but the registry already rejects those as duplicates, so that pair
-- can never both exist.
--
-- A name made entirely of punctuation slugs to "" and would produce a bare-prefix frame name shared
-- by every such panel, so it falls back to "Panel". The registry's slug-uniqueness check turns any
-- remaining collision into a rejected rename rather than two frames fighting over one global.
function Util.Slugify(name)
  local s = tostring(name or ""):gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  if s == "" then return "Panel" end
  return s
end

-- The global frame name for a panel. One definition, used by the renderer that creates the frame,
-- the settings page that displays it and the tests that assert on it.
function Util.FrameName(name)
  return C.FRAME_NAME_PREFIX .. Util.Slugify(name)
end

-- Resolve a panel's color field to the {r, g, b, a} that is actually drawn.
--
-- This is the single seam every color read goes through, and it is now a pure ADAPTER: the three
-- rules that make a class color a color -- the stored alpha survives the mode, an unresolvable
-- class falls through to the stored swatch, and the swatch is read under both modes -- are
-- `LibKa0s-Core-1.0`'s `ResolveColor`, shared with every other Ka0s addon (options-ui-§17). What
-- stays here is the two things the library cannot know: which flag pairs with which color
-- (C.COLOR_FIELDS), and that a panel is CHROME so the class is the player's and never a unit's
-- (C.COLOR_CLASS_SOURCE).
--
-- The record's own shape is decoded FIRST, through Util.Color against the template, so a record
-- missing the field falls back to what this addon ships rather than to the library's own white.
--
-- Degrades to the stored color with no library, which is the same answer the old private resolver
-- gave when UnitClass was unavailable: a panel with a plain color, never a white one.
function Util.ResolveColor(rec, field)
  local stored = Util.Color(rec and rec[field], C.PANEL_TEMPLATE[field])
  local flag = C.COLOR_FIELDS[field]
  local core = NS.Core
  if not (flag and rec and rec[flag] and core and core.ResolveColor) then return stored end
  -- nil unit, because C.COLOR_CLASS_SOURCE says every panel color is player-scoped. Read from the
  -- table rather than hardcoded, so the declaration is what decides and not this line.
  local unit = C.COLOR_CLASS_SOURCE[field] == "unit" and rec.unit or nil
  local r, g, b, a = core.ResolveColor(stored, true, unit)
  return { r, g, b, a }
end

-- ── Secret-safe chat printer (events-frames-taint-§8) ────────────────────────────
-- MOVED to core/CoreSetup.lua, which builds it from LibKa0s-Core-1.0 (library-stack). NS.Print,
-- NS.Util.print, NS.SafeToString and NS.IsConcatSafe all still answer under those exact names — the
-- five files doing `local print = NS.Print` at file scope are unchanged — and the secret-value guard
-- is the library's identical table.concat probe rather than a seventh hand-written copy of it.
-- CoreSetup.lua loads immediately after this file and before core/PanelMaster.lua's AceConsole
-- reclaim; see the ordering note at the top of that file.

-- Deep copy, used wherever a template or a schema default must not be aliased into the DB. A stored
-- panel that aliased C.PANEL_TEMPLATE would let one panel's edit rewrite the shipped default for
-- every panel created afterwards in the same session.
function Util.DeepCopy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, val in pairs(v) do out[k] = Util.DeepCopy(val) end
  return out
end

-- Is `point` one of the nine anchor points? Kept here rather than inline so the CLI, the settings
-- panel and the sanitizer all agree on what a valid anchor is.
function Util.IsPoint(point)
  return C.POINT_SET[point] == true
end

function Util.IsStrata(strata)
  return C.STRATA_SET[strata] == true
end
