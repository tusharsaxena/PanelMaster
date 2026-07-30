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

-- ── Colours ─────────────────────────────────────────────────────────────────────

-- A normalized {r, g, b, a} array from an arbitrary stored value. Every component is clamped to
-- 0..1 and alpha defaults to 1, so a partial or malformed colour still renders something visible
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

-- "r,g,b,a" → a colour array, for `/pm panel set <name> bgColor 0.1,0.1,0.1,0.8`. Accepts 3 or 4
-- components (alpha defaults to 1) and 0-255 byte input as well as 0-1.
--
-- The byte-vs-fraction decision reads only R, G and B, and then applies to all four: a hex colour
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

-- A colour array → the "r,g,b,a" form ParseColor accepts, for the CLI echo and `/pm panel show`.
-- Round-trips: FormatColor(ParseColor(s)) parses back to the same colour.
function Util.FormatColor(c)
  c = Util.Color(c)
  return ("%.2f,%.2f,%.2f,%.2f"):format(c[1], c[2], c[3], c[4])
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

-- Resolve a panel's colour field to the {r, g, b, a} that is actually drawn.
--
-- This is the single seam every colour read goes through. If the field has a class-colour companion
-- in C.COLOR_FIELDS and that flag is set, the player's class RGB replaces the stored RGB — but the
-- stored ALPHA is kept, because "class coloured" is a statement about hue, not about how
-- see-through the user wanted their panel. Falls back to the stored colour whenever the class colour
-- cannot be determined, so a headless or early-login read is never a white panel.
function Util.ResolveColor(rec, field)
  local stored = Util.Color(rec and rec[field], C.PANEL_TEMPLATE[field])
  local flag = C.COLOR_FIELDS[field]
  if not (flag and rec and rec[flag]) then return stored end
  local r, g, b = NS.Compat.GetClassColor()
  if not r then return stored end
  return { r, g, b, stored[4] }
end

-- ── Secret-safe chat printer (events-frames-taint-§8) ────────────────────────────
-- In combat, retail protects combat-sensitive returns as "secret" values. A secret survives
-- tostring() AND the `..` operator (which silently propagates secretness), but RAISES the instant it
-- reaches table.concat. Because every chat line ends in a table.concat, an unguarded secret both
-- spams a Lua error and — inside a repeating ticker — can freeze the feature until /reload.
-- Detection MUST probe the operation that actually rejects a secret (table.concat), NOT `..`: a
-- `..`-based probe reports a secret as safe.
--
-- This addon reads no combat values today. The guard is still mandatory (events-frames-taint-§8 is a
-- MUST on the shared printer regardless of current call sites), and it is what makes it safe to log
-- an arbitrary value later without revisiting every call site.
local function probeConcat(v) return table.concat({ v }) end
function NS.IsConcatSafe(v)
  return (pcall(probeConcat, v))
end

-- Concat-safe stringifier used by every line the addon emits. Ordinary values → tostring(v); an
-- un-concatenable (secret) value → the sentinel "<secret>", so the surrounding table.concat can
-- never raise. nil and booleans are handled up front (table.concat rejects a boolean element too,
-- but booleans are never secret, so they must not be masked).
function NS.SafeToString(v)
  if v == nil then return "nil" end
  if type(v) == "boolean" then return tostring(v) end
  if NS.IsConcatSafe(v) then return tostring(v) end
  return "<secret>"
end

-- The single shared chat printer. Prepends the cyan NS.PREFIX tag (slash-commands-§4) and
-- space-joins each SafeToString'd arg, mirroring print(). Every file that emits chat does
-- `local print = NS.Print` so call sites stay `print("message")` — never the global print(), never a
-- hand-written tag, never raw `..`/tostring on an arg. The real name is NS.Util.print; NS.Print is
-- reclaimed from it after the AceConsole embed (core/PanelMaster.lua, architecture-§2).
function NS.Print(...)
  local n = select("#", ...)
  local parts = { NS.PREFIX }
  for i = 1, n do parts[i + 1] = NS.SafeToString((select(i, ...))) end
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(table.concat(parts, " "))
  end
end
Util.print = NS.Print

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
