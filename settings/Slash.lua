local addonName, NS = ...   -- luacheck: ignore addonName
NS.Slash = NS.Slash or {}
local Sl = NS.Slash
local C = NS.Constants
local print = NS.Print   -- secret-safe, [PM]-prefixed shared printer (events-frames-taint-§8)

-- Confirm dialogs for the destructive actions. Registered once; in-game only.
if type(StaticPopupDialogs) == "table" then
  StaticPopupDialogs["KA0S_PANELMASTER_DELETEALL"] = {
    text = "Delete ALL Ka0s Panel Master panels on this character? This cannot be undone.",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function()
      local n = NS.Registry:DeleteAll()
      print(("deleted %d %s."):format(n, n == 1 and "panel" or "panels"))
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
    preferredIndex = 3,
  }
end

function Sl:Register()
  NS.addon:RegisterChatCommand("pm", function(input) Sl:OnSlash(input) end)
  NS.addon:RegisterChatCommand("panelmaster", function(input) Sl:OnSlash(input) end)
end

-- `/pm version` → the canonical single-line answer every Ka0s addon shares (slash-commands-§3). Read
-- from the TOC metadata so it can't drift from the packaged manifest, with the in-code constant as
-- the fallback. `/pm version` and the help header both come through here, so they cannot report
-- different numbers.
function Sl:Version()
  return (NS.Compat and NS.Compat.GetAddOnMetadata
    and NS.Compat.GetAddOnMetadata(NS.name, "Version")) or NS.version or "?"
end

-- ── Panel CLI ───────────────────────────────────────────────────────────────────
--
-- These verbs stay HOST-OWNED and are untouched by the LibKa0s adoption. They act on PANEL RECORDS
-- — variable-length user-created objects the registry owns (architecture-§5) — not on schema rows,
-- so the library's schema CLI has nothing to say about them. What they DO now share with it is the
-- one `key = value` formatter: `Sl.FormatKV` below is the library's, so a panel field and a setting
-- read identically wherever either is printed.

function Sl:CliNew(arg)
  local name = NS.Util.CleanName(arg)
  if not name then print("Usage: /pm new <name>"); return end
  local rec, err = NS.Registry:New(name)
  if not rec then print("error: " .. tostring(err)); return end
  print(("created panel '%s' (id %d). Use |cffffff00/pm unlock|r to place it.")
    :format(rec.name, rec.id))
end

function Sl:CliDelete(arg)
  local name = NS.Util.CleanName(arg)
  if not name then print("Usage: /pm delete <name>"); return end
  local ok, result = NS.Registry:Delete(name)
  if not ok then print("error: " .. tostring(result)); return end
  print(("deleted panel '%s'"):format(tostring(result)))
end

-- `/pm rename <old> <new>`. The old name is taken as the FIRST word and the new name as the rest, so
-- a rename can give a panel a name with spaces ("/pm rename bg Chat Backdrop"). Renaming a panel
-- whose existing name has spaces goes through the settings panel instead — a two-name command line
-- has no unambiguous split for that case, and inventing one (quotes, a separator token) would be a
-- syntax the user has to learn for a job the UI already does well.
function Sl:CliRename(arg)
  local old, new = tostring(arg or ""):match("^(%S+)%s+(.+)$")
  if not old then print("Usage: /pm rename <old> <new>"); return end
  local ok, result = NS.Registry:Rename(old, new)
  if not ok then print("error: " .. tostring(result)); return end
  print(("renamed '%s' to '%s'"):format(tostring(result), NS.Util.CleanName(new)))
end

-- Build the `/pm panels` lines as a pure array, mirroring BuildListLines so the panel listing is
-- unit-testable and color-consistent with the settings listing (slash-commands-§5).
function Sl:BuildPanelLines()
  local records = NS.Registry:All()
  if #records == 0 then
    return { "|cff33ff99No panels yet|r \226\128\148 make one with |cffffff00/pm new <name>|r" }
  end
  local lines = { ("|cff33ff99Panels|r (%d)"):format(#records) }
  for _, rec in ipairs(records) do
    -- A disabled panel is dimmed rather than hidden from the list: it still exists, and the listing
    -- is how you find it again to re-enable it.
    local name = rec.enabled and ("|cffffff00%s|r"):format(rec.name)
      or ("|cff808080%s|r"):format(rec.name)
    lines[#lines + 1] = ("  %s |cffffffff%dx%d @ %s %d,%d|r"):format(
      name, rec.width, rec.height, rec.point, rec.x, rec.y)
  end
  return lines
end

function Sl:CliPanels()
  for _, line in ipairs(Sl:BuildPanelLines()) do print(line) end
end

-- Full per-panel field dump, in the declared field order rather than pairs() order.
function Sl:BuildPanelShowLines(rec)
  local lines = { ("|cff33ff99Panel|r |cffffff00%s|r (id %d)"):format(rec.name, rec.id) }
  for _, field in ipairs(C.PANEL_FIELD_ORDER) do
    lines[#lines + 1] = "  " .. Sl.FormatKV(field, NS.Registry.FormatField(rec, field))
  end
  return lines
end

-- The confirm-gated wipe. The StaticPopup fallback is what lets the headless suite drive DeleteAll
-- without a popup, so the test is on the function's presence rather than a nil check on some other
-- global that happens to be absent too.
local function doDeleteAll()
  if type(StaticPopup_Show) == "function" then
    StaticPopup_Show("KA0S_PANELMASTER_DELETEALL")
  else
    local n = NS.Registry:DeleteAll()
    print(("deleted %d %s."):format(n, n == 1 and "panel" or "panels"))
  end
end

-- The CLI half of the editor's Fit to artwork button.
local function doFitArt(rec)
  local ok, w, h = NS.Registry:FitToArtwork(rec.id)
  if ok then
    -- Both axes echoed, and read back off the record, so the line reflects the MIN/MAX clamp
    -- rather than what the artwork asked for.
    print(Sl.FormatKV("width", tostring(w)))
    print(Sl.FormatKV("height", tostring(h)))
  else
    print(w)   -- on failure the second return is the reason
  end
end

-- `<field> <value>` from the tail, or just `<field>`, or neither.
local function parseFieldValue(tail)
  local field, value = tail:match("^(%S+)%s+(.+)$")
  if not field then field = tail:match("^(%S+)$") end
  return field, value
end

-- `/pm panel <name>`              → dump every field
-- `/pm panel <name> <field>`      → one field
-- `/pm panel <name> <field> <v>`  → set it
-- `/pm panel deleteall`           → the confirm-gated wipe, unless a panel is named that
--
-- The name is the first word, so a panel whose name has spaces is addressed from the settings UI
-- rather than here — the same trade-off `rename` makes, and for the same reason.
function Sl:CliPanel(arg)
  local rest = tostring(arg or "")
  local key, tail = rest:match("^(%S+)%s*(.-)$")
  if not key then
    print("Usage: /pm panel <name> [field] [value]  (try /pm panels)")
    return
  end

  -- The panel wins the name. `deleteall` is only the verb when nothing answers to it, so a user who
  -- names a panel "deleteall" can still inspect and edit it from the CLI instead of having it
  -- permanently shadowed by the wipe — and the wipe stays reachable the moment that panel is gone.
  local rec = NS.Registry:Resolve(key)

  if not rec and key:lower() == "deleteall" then return doDeleteAll() end

  if not rec then print(("no panel called '%s'"):format(key)); return end

  local field, value = parseFieldValue(tail)

  if not field then
    for _, line in ipairs(Sl:BuildPanelShowLines(rec)) do print(line) end
    return
  end

  -- `fitart` sits in the FIELD slot but is an ACTION, the CLI half of the editor's Fit to artwork
  -- button. It is checked before the field table for the same reason `deleteall` is checked before
  -- the panel lookup: a verb and a name occupying one slot need a stated precedence. There is no
  -- ambiguity to lose here — no field is called `fitart` and none can be, because the field names
  -- are the record's own keys.
  if field:lower() == "fitart" then return doFitArt(rec) end

  if not C.PANEL_FIELD_TYPE[field] then
    print(("unknown field '%s'. Try: %s"):format(field, table.concat(C.PANEL_FIELD_ORDER, ", ")))
    return
  end
  if value == nil then
    print(Sl.FormatKV(field, NS.Registry.FormatField(rec, field)))
    return
  end

  local ok, err = NS.Registry:Set(rec.id, field, value)
  if not ok then print("error: " .. tostring(err)); return end
  -- Read back the STORED value so the echo reflects clamping and coercion, exactly as CliSet does.
  print(Sl.FormatKV(field, NS.Registry.FormatField(NS.Registry:Get(rec.id), field)))
end

function Sl:CliRecover()
  local moved = NS.Registry:Recover()
  if moved == 0 then
    print("every panel is already on screen")
  else
    print(("moved %d %s back on screen"):format(moved, moved == 1 and "panel" or "panels"))
  end
end

-- Slash command table. It sits at the BOTTOM of this file, below every Cli* function its entries
-- call, so the whole slash surface — table, dispatcher, generated help and the implementations —
-- reads as one thing. `/pm help`, the README's command table and the settings landing page all
-- generate from this, so they can never drift (slash-commands-§3).
--
-- POSITIONAL `{ name, description, handler }` triples, which is the shape LibKa0s-Slash-1.0 reads.
-- They used to be keyed (`{ name =, desc =, fn = }`); the flip moved 18 entries, the dispatcher, the
-- help renderer, the settings landing page and seven test cases together.
--
-- The table STAYS THIS ADDON'S and is passed in rather than owned, and that is the load-bearing
-- decision rather than an oversight: the settings landing page renders these same rows, and if the
-- library owned the table then the options major drawing that page would have to resolve the slash
-- major to read it — a real dependency cycle between two majors at load time. Crossing between them
-- as plain data is what keeps them independent.
NS.COMMANDS = {
  { "config",   "Open settings", function()
      if NS.Panel then NS.Panel:Open() end
    end },
  { "new",      "Create a panel: /pm new <name>",
    function(a) NS.Slash:CliNew(a) end },
  { "delete",   "Delete a panel: /pm delete <name>",
    function(a) NS.Slash:CliDelete(a) end },
  { "rename",   "Rename a panel: /pm rename <old> <new>",
    function(a) NS.Slash:CliRename(a) end },
  { "panels",   "List your panels", function() NS.Slash:CliPanels() end },
  { "panel",    "Inspect or edit one: /pm panel <name> [field] [value]; "
                            .. "'fitart' fits it to its artwork; 'deleteall' removes every panel",
    function(a) NS.Slash:CliPanel(a) end },
  { "unlock",   "Unlock panels for dragging", function()
      if NS.Unlock then NS.Unlock:SetUnlocked(true) end
    end },
  { "lock",     "Lock panels again", function()
      if NS.Unlock and NS.Unlock:SetUnlocked(false) ~= nil then NS.Print("panels locked") end
    end },
  { "preview",  "Toggle sample panels", function()
      if not NS.Unlock then return end
      local on = NS.Unlock:TogglePreview()
      NS.Print("preview " .. (on and "on" or "off"))
    end },
  { "recover",  "Bring off-screen panels back into view",
    function() NS.Slash:CliRecover() end },
  { "version",  "Print addon version", function() NS.Slash:CliVersion() end },
  { "get",      "Get a setting value", function(a) NS.Slash:CliGet(a) end },
  { "set",      "Set a setting value", function(a) NS.Slash:CliSet(a) end },
  { "list",     "List all settings", function() NS.Slash:CliList() end },
  { "reset",    "Reset one setting", function(a) NS.Slash:CliReset(a) end },
  { "resetall", "Reset all settings", function() NS.Slash:CliResetAll() end },
  -- Every sub-verb a handler below accepts is named in its own `desc`, because the generated help
  -- index, the settings landing page and the README's command table all read these strings and
  -- nothing else. A sub-verb missing here is a sub-verb nobody can discover (slash-commands-§4).
  { "debug",    "Window; 'on'/'off' set logging, 'dump' writes a state dump",
    function(rest)
      -- `/pm debug` toggles the WINDOW only (the logging flag is untouched); `/pm debug on|off` sets
      -- the session-only logging flag through the DebugLog seam. Logging runs even with the console
      -- closed, so a bug can be reproduced first and the log read afterwards.
      local arg = rest and tostring(rest):lower():match("^%s*(%S*)") or ""
      if not NS.DebugLog then return end
      if arg == "on" then NS.DebugLog:SetEnabled(true)
      elseif arg == "off" then NS.DebugLog:SetEnabled(false)
      elseif arg == "dump" then
        -- Structured dump verb (debug-logging-§4): the registry's and the renderer's views of the
        -- world, side by side. Uses the RAW append, so it works whether or not logging is enabled.
        NS.DebugLog:Show()
        for _, line in ipairs(NS.DebugLog:Diagnose()) do NS.DebugLog:Add("Dump", line) end
      else NS.DebugLog:Toggle() end
    end },
  { "help",     "Show this help", function() NS.Slash:PrintHelp() end },
}

-- ── LibKa0s-Slash-1.0 seam ──────────────────────────────────────────────────────
--
-- What moves to the library: the dispatcher, the help renderer, the landing-page row formatter, the
-- schema CLI (list/get/set/reset/resetall/version) and the type-aware value parser. What stays here:
-- NS.COMMANDS above (see its note) and every PANEL verb, which act on registry records rather than
-- on schema rows.
--
-- This file sits after settings/Schema.lua, which the descriptor's callbacks read, and before
-- settings/Panel.lua, whose landing page calls Sl:LandingRows(). Every callback below resolves
-- through NS at CALL time, so the only ordering that actually binds is NS.COMMANDS existing above.

local UNAVAILABLE = NS.LIBKA0S_MISSING ..
  ", so the slash help index and the settings CLI (list/get/set/reset) are unavailable."

local lib = LibStub and LibStub("LibKa0s-Slash-1.0", true)

if not lib then
  -- Degrade, never error — and here that matters more than anywhere else, because the slash surface
  -- is the only way to reach this addon at all when the settings panel is also gone. The PANEL verbs
  -- above are untouched by the library and keep working; a minimal dispatcher is re-implemented so
  -- they stay reachable, and every schema verb explains itself instead of drawing nothing.
  local function explain() print(UNAVAILABLE) end
  Sl.PrintHelp      = explain
  Sl.BuildListLines = function() return { UNAVAILABLE } end
  Sl.CliList        = explain
  Sl.CliGet         = explain
  Sl.CliSet         = explain
  Sl.CliReset       = explain
  Sl.LandingRows    = function() return {} end
  Sl.HelpRows       = function() return {} end
  function Sl:CliVersion() print("v" .. tostring(Sl:Version())) end
  -- Kept WORKING rather than explained away: it is the one schema verb with no library dependency —
  -- it is a loop over the schema through this addon's own write seam.
  function Sl:CliResetAll()
    for _, row in ipairs(NS.Schema.Schema) do NS.Schema:Set(row.path, row.default) end
    print("all settings reset to defaults (your panels are untouched)")
  end
  function Sl:OnSlash(input)
    if input == nil or input:match("^%s*$") then return explain() end
    local verb, rest = input:match("^(%S+)%s*(.-)$")
    verb = verb and verb:lower()
    for _, cmd in ipairs(NS.COMMANDS) do
      if cmd[1] == verb then return cmd[3](rest) end
    end
    print("unknown command '" .. tostring(verb) .. "'")
    explain()
  end
  return
end

local dispatcher = lib:New({
  slash        = "/pm",
  slashAliases = { "/panelmaster" },
  commands     = NS.COMMANDS,

  print   = function(line) print(line) end,
  version = function() return Sl:Version() end,

  -- The schema seam. This addon's write path is already the two-argument shape the library calls
  -- with, so `set` needs no arity adapter — NS.Schema:Set(path, value) IS the single write seam that
  -- validates, logs once and fires onChange, and routing the CLI through it is what keeps a slash
  -- write and a panel write the same event.
  get          = function(path) return NS.Schema:Get(path) end,
  set          = function(path, v) NS.Schema:Set(path, v) end,
  findRow      = function(path) return NS.Schema:FindRow(path) end,
  allRows      = function() return NS.Schema.Schema end,
  applyDefault = function(row) NS.Schema:Set(row.path, NS.Schema:Default(row.path)) end,

  -- ADAPTER. The library groups `/pm list` by `row.page`; this addon's schema has always grouped by
  -- `row.group`, which is also the section heading its settings panel draws. One name, two readers.
  groupKey = function(row) return row.group or "?" end,

  -- ADAPTER, and a deliberate divergence from the library's own parser rather than a translation of
  -- it. `lib.ParseValue` matches an enum case-sensitively, which is right for a texture name but
  -- wrong for this addon's one enum: strata tokens are stored upper-case and `/pm set
  -- settings.defaultStrata low` has always worked. Up-casing only for a row that actually declares
  -- an enum, then delegating, keeps every other type on the library's parser — including the number
  -- clamping and the color rescaling this addon never had.
  parse = function(row, text)
    if row and row.type == "string" and row.values then
      text = tostring(text or ""):upper()
    end
    return lib.ParseValue(row, text)
  end,

  -- A PLAIN table of the one string this addon actually overrides — never NS.L, whose metatable
  -- answers every key with the key itself (the `L` trap). The library's own RESET_ALL is "All
  -- settings reset to defaults"; this addon's says what it deliberately does NOT touch, and that
  -- reassurance is the whole reason the message is worded the way it is. Deleting panels is the
  -- confirm-gated `/pm panel deleteall`, which is a different request.
  L = { RESET_ALL = "all settings reset to defaults (your panels are untouched)" },
})

-- Republished under the method names this addon's own callers already use, as forwarders, so
-- settings/Panel.lua, the command handlers above and every test reach one implementation.
function Sl:OnSlash(input)       return dispatcher:OnSlash(input)   end
function Sl:PrintHelp()          return dispatcher:PrintHelp()      end
function Sl:HelpRows()           return dispatcher:HelpRows()       end
function Sl:LandingRows()        return dispatcher:LandingRows()    end
function Sl:BuildListLines()     return dispatcher:BuildListLines() end
function Sl:CliList()            return dispatcher:CliList()        end
function Sl:CliGet(a)            return dispatcher:CliGet(a)        end
function Sl:CliSet(a)            return dispatcher:CliSet(a)        end
function Sl:CliReset(a)          return dispatcher:CliReset(a)      end
function Sl:CliResetAll()        return dispatcher:CliResetAll()    end
function Sl:CliVersion()         return dispatcher:CliVersion()     end
function Sl:Text(key)            return dispatcher:Text(key)        end

-- The one `key = value` formatter, now the library's, so a panel field printed by BuildPanelLines
-- and a setting printed by CliGet render identically. This is a byte-level change: the library's
-- color escapes are UPPERCASE (|cFFFFFF00) where this addon's were lowercase. WoW is
-- case-insensitive about them, so the pixels are the same and only the source bytes move.
Sl.FormatKV = lib.FormatKV
