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

-- Bare `/pm` prints the help index (slash-commands-§4). Only the VERB is lower-cased — `rest` keeps
-- its case, so panel names and schema paths survive `/pm rename Chat BG ChatBG`.
function Sl:OnSlash(input)
  if input == nil or input:match("^%s*$") then
    return Sl:PrintHelp()
  end
  local verb, rest = input:match("^(%S+)%s*(.-)$")
  verb = verb and verb:lower()
  for _, cmd in ipairs(NS.COMMANDS) do
    if cmd.name == verb then return cmd.fn(rest) end
  end
  print("unknown command '" .. tostring(verb) .. "'")
  Sl:PrintHelp()
end

-- The help index, generated from NS.COMMANDS (slash-commands-§4): a version/alias header, then one
-- prefixed row per command — gold command, em-dash, white description. Never hand-maintained.
function Sl:PrintHelp()
  print("v" .. tostring(Sl:Version()) ..
    " slash commands (|cffffff00/panelmaster|r is an alias for |cffffff00/pm|r)")
  for _, cmd in ipairs(NS.COMMANDS) do
    print(("|cffffff00/pm %s|r — |cffffffff%s|r"):format(cmd.name, cmd.desc))
  end
end

-- `/pm version` → the canonical single-line answer every Ka0s addon shares (slash-commands-§3). Read
-- from the TOC metadata so it can't drift from the packaged manifest, with the in-code constant as
-- the fallback. `/pm version` and the help header both come through here, so they cannot report
-- different numbers.
function Sl:Version()
  return (NS.Compat and NS.Compat.GetAddOnMetadata
    and NS.Compat.GetAddOnMetadata(NS.name, "Version")) or NS.version or "?"
end

function Sl:CliVersion()
  print("v" .. tostring(Sl:Version()))
end

-- ── Schema-driven CLI: list / get / set / reset (slash-commands-§5 output format) ──

-- The shared value formatter for list/get/set, so the three can never diverge. Type-aware and
-- schema-driven: a row's optional `fmt` formats numbers (gridSize "%d px" → "4 px"); booleans render
-- true/false.
function Sl.FormatSchemaValue(row, v)
  if v == nil then return "nil" end
  if row and row.fmt and type(v) == "number" then return row.fmt:format(v) end
  if row and row.type == "boolean" then return v and "true" or "false" end
  return tostring(v)
end

-- The shared coloured `key = value` line — gold key, white value, ` = ` left default — reused by the
-- list rows and the get/set echo so the colouring can't drift (slash-commands-§5).
function Sl.FormatKV(path, valueStr)
  return ("|cffffff00%s|r = |cffffffff%s|r"):format(tostring(path), tostring(valueStr))
end

-- The declared group order for `/pm list` (slash-commands-§5's "stable, declared page order"). These
-- are SCHEMA GROUP NAMES and must match them exactly — a name that matches nothing fails invisibly,
-- so a test asserts each one still resolves. Any group not named here is appended in first-seen
-- order, so a new group is never silently dropped from the listing.
local LIST_GROUP_ORDER = { "Master Controls", "Editing", "New Panel Defaults" }
Sl.LIST_GROUP_ORDER = LIST_GROUP_ORDER

-- Build the `/pm list` lines (tag-less content; CliList prints each through NS.Print, which prepends
-- the cyan tag) as a pure array, so the output shape is unit-testable without capturing chat. Header
-- green, [group] headers azure, value rows via FormatKV — two-space indent on group headers,
-- four-space on value rows (slash-commands-§5).
function Sl:BuildListLines()
  local lines = { "|cff33ff99Available settings|r" }

  local byGroup, seenOrder = {}, {}
  for _, row in ipairs(NS.Schema.Schema) do
    local g = row.group or "?"
    if not byGroup[g] then byGroup[g] = {}; seenOrder[#seenOrder + 1] = g end
    byGroup[g][#byGroup[g] + 1] = row
  end

  local emitted = {}
  local function emit(g)
    if emitted[g] or not byGroup[g] then return end
    emitted[g] = true
    lines[#lines + 1] = "  |cff3399ff[" .. g .. "]|r"
    for _, row in ipairs(byGroup[g]) do
      local v = NS.Schema:Get(row.path)
      lines[#lines + 1] = "    " .. Sl.FormatKV(row.path, Sl.FormatSchemaValue(row, v))
    end
  end

  for _, g in ipairs(LIST_GROUP_ORDER) do emit(g) end
  for _, g in ipairs(seenOrder) do emit(g) end
  return lines
end

function Sl:CliList()
  for _, line in ipairs(Sl:BuildListLines()) do print(line) end
end

function Sl:CliGet(arg)
  local path = (strtrim and strtrim(tostring(arg or "")) or tostring(arg or "")):match("^(%S+)")
  if not path then
    print("Usage: /pm get <path>")
    return
  end
  local row = NS.Schema:FindRow(path)
  if not row then
    print("Setting not found: " .. path)
    return
  end
  print(Sl.FormatKV(path, Sl.FormatSchemaValue(row, NS.Schema:Get(path))))
end

function Sl:CliSet(arg)
  local path, raw = tostring(arg or ""):match("^(%S+)%s+(.+)$")
  if not path then
    print("Usage: /pm set <path> <value>  (try /pm list)")
    return
  end
  local row = NS.Schema:FindRow(path)
  if not row then
    print("Setting not found: " .. path)
    return
  end
  local value = raw
  if row.type == "number" then
    value = tonumber(raw)
    if not value then print("expected a number"); return end
  elseif row.type == "boolean" then
    value = (raw == "true" or raw == "1" or raw == "on" or raw == "yes")
  elseif row.type == "string" and row.options then
    -- A dropdown-backed string (the strata list) stores an upper-case token; accepting any casing
    -- from the CLI keeps `/pm set settings.defaultStrata low` working.
    value = raw:upper()
  end
  local ok, err = NS.Schema:Set(path, value)
  if ok then
    -- Read back the STORED value so the echo reflects any clamping or coercion (slash-commands-§5).
    print(Sl.FormatKV(path, Sl.FormatSchemaValue(row, NS.Schema:Get(path))))
  else
    print("error: " .. tostring(err))
  end
end

function Sl:CliReset(arg)
  local path = arg and tostring(arg):match("^%S+") or nil
  if not path then print("Usage: /pm reset <path>"); return end
  local row = NS.Schema:FindRow(path)
  local def = NS.Schema:Default(path)
  if not row or def == nil then print("Setting not found: " .. tostring(path)); return end
  NS.Schema:Set(path, def)
  print(Sl.FormatKV(path, Sl.FormatSchemaValue(row, NS.Schema:Get(path))))
end

-- Reset every setting to its default. Non-destructive: the user's PANELS are left completely alone,
-- because "reset my settings" and "delete my work" are different requests. Deleting panels is the
-- confirm-gated `/pm panel deleteall`.
function Sl:CliResetAll()
  for _, row in ipairs(NS.Schema.Schema) do
    NS.Schema:Set(row.path, row.default)
  end
  print("all settings reset to defaults (your panels are untouched)")
end

-- ── Panel CLI ───────────────────────────────────────────────────────────────────

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
-- unit-testable and colour-consistent with the settings listing (slash-commands-§5).
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

-- `/pm panel <name>`              → dump every field
-- `/pm panel <name> <field>`      → one field
-- `/pm panel <name> <field> <v>`  → set it
-- `/pm panel deleteall`           → the confirm-gated wipe
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

  if key:lower() == "deleteall" then
    if type(StaticPopup_Show) == "function" then
      StaticPopup_Show("KA0S_PANELMASTER_DELETEALL")
    else
      local n = NS.Registry:DeleteAll()
      print(("deleted %d %s."):format(n, n == 1 and "panel" or "panels"))
    end
    return
  end

  local rec = NS.Registry:Resolve(key)
  if not rec then print(("no panel called '%s'"):format(key)); return end

  local field, value = tail:match("^(%S+)%s+(.+)$")
  if not field then field = tail:match("^(%S+)$") end

  if not field then
    for _, line in ipairs(Sl:BuildPanelShowLines(rec)) do print(line) end
    return
  end
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
