local _, NS = ...
NS.Slash = NS.Slash or {}
local Sl = NS.Slash
local C = NS.Constants
local print = NS.Print   -- secret-safe, [PM]-prefixed shared printer (events-frames-taint-§8)

-- The acknowledgment, named once and handed to the library as its RESET_ALL override below. It no
-- longer says "your panels are untouched", because they are not: the reset is a PROFILE reset now
-- and `db.profile.panels` is in the profile. A reassurance that has stopped being true is worse
-- than no reassurance.
Sl.RESET_ALL_TEXT = "this profile reset to defaults"

--- The global reset, and it is a PROFILE reset (options-ui-§12).
---
--- `Reset all settings` and the Profiles page's `Reset Profile` are the same act across the whole
--- collection: `db:ResetProfile()` on the ACTIVE profile, never a second walk of the schema, and
--- never a touch on another profile or on the profile list.
---
--- WHAT CHANGED FOR THIS ADDON: it used to walk `NS.Schema.Schema` writing each row's default and
--- print *"your panels are untouched"*. It is a profile reset now, and `db.profile.panels` is IN
--- the profile — so the panels go with it and what comes back is a profile indistinguishable from
--- one the player had just created. That is what the rule asks for, and it is why this verb grew a
--- confirmation it did not have before: a schema sweep that spared your panels and a profile reset
--- that deletes them are not the same act, whatever the verb is called.
---
--- The rebuild is the one every profile switch already takes: `OnProfileReset` reaches the `reload`
--- closure NS:RegisterProfileCallbacks installed (core/Database.lua), which sweeps preview orphans
--- and calls Registry:ReloadProfile.
---
--- Shared by the popup's OnAccept and by the headless fallback, so the two cannot diverge.
---
--- It is logged ONCE, by that same handler: `[Set] reset profile 'X' to defaults (N rows)`
--- (debug-logging-§10). The snapshot taken here is what lets the handler count the rows the reset
--- CHANGED, and the bracket, reporting `profileReset`, keeps anything the reset runs from adding a
--- line of its own. A reset that raised never reached the handler, so the bracket logs instead.
function Sl:DoResetAll()
  local db, S = NS.db, NS.Schema
  if db and db.ResetProfile then
    S.BulkBegin("reset", "all")
    S.resetSnapshot = S:SnapshotPersisted()
    local ok, err = pcall(db.ResetProfile, db)
    S.resetSnapshot = nil
    S.BulkEnd("reset", "all", nil, err, { profileReset = ok })
    if not ok then error(err, 0) end
  end
  print(Sl.RESET_ALL_TEXT)
end

--- The confirm-gated entry point, and the one every CONTROL uses.
---
--- options-ui-§12 puts the confirmation on the control, not on the act: a reset that deletes the
--- player's panels must ask first. The typed verb goes through it too -- this addon has no reason
--- to make `/pm resetall` the one door with no lock on it.
---
--- The StaticPopup fallback is what lets the headless suite drive the act without a popup, the same
--- bargain doDeleteAll strikes.
function Sl:ConfirmResetAll()
  if type(StaticPopup_Show) == "function" then
    StaticPopup_Show("KA0S_PANELMASTER_RESETALL")
  else
    Sl:DoResetAll()
  end
end

-- Confirm dialogs for the destructive actions. Registered once; in-game only.
if type(StaticPopupDialogs) == "table" then
  -- THE COLLECTION'S ONE WORDING (options-ui-§12), verbatim. Addon-agnostic on purpose -- no addon
  -- enumerates its own nouns -- and explicit about the destruction, which for this addon means the
  -- player's panels. `/pm resetall` used to spare them and say so; a profile reset does not, and a
  -- verb that silently deleted a screen full of panels because its wording stayed the same is the
  -- exact failure the standard's fixed text exists to prevent.
  StaticPopupDialogs["KA0S_PANELMASTER_RESETALL"] = {
    text = "Reset this profile to the addon's defaults? Everything you have configured or added in it is discarded \226\128\148 your other profiles are not affected.",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function() NS.Slash:DoResetAll() end,
    timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
    preferredIndex = 3,
  }
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
-- the fallback — both of which now live in core/EnvSetup.lua, over LibKa0s-Env-1.0. This wrapper
-- stays because `/pm version` and the help header both come through it, so they cannot report
-- different numbers.
function Sl:Version()
  return NS.Version()
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
  -- THE RESERVED PAIR (slash-commands-§2), and they are ALIASES rather than a second switch. Both
  -- write `NS.Schema.ENABLED_PATH` -- the very path the Master controls *Enable Ka0s Panel Master*
  -- checkbox writes -- through the very seam it writes through, so the two surfaces can never show
  -- the player two different answers and `settings/Schema.lua`'s `announce("enabled")` runs
  -- whichever one was used. They hold NO state of their own: no second key, no session flag, no
  -- `NS.enabled` local.
  --
  -- Routed through `CliSet` rather than calling `NS.Schema:Set` directly, and that is the point
  -- rather than a shortcut. `/pm enable` is then LITERALLY `/pm set settings.enabled true` -- the
  -- same parse, the same write, and the same canonical `path = value` echo read back from the
  -- STORE after the write (slash-commands-§5). Formatting the acknowledgment here instead would be
  -- a private variant of the one shared formatter, which §5 forbids in as many words.
  { "enable",   "Turn the addon on",
    function() NS.Slash:CliSet(NS.Schema.ENABLED_PATH .. " true") end },
  { "disable",  "Turn the addon off without unloading it",
    function() NS.Slash:CliSet(NS.Schema.ENABLED_PATH .. " false") end },
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
  { "recover",  "Bring off-screen panels back into view",
    function() NS.Slash:CliRecover() end },
  { "version",  "Print addon version", function() NS.Slash:CliVersion() end },
  { "get",      "Get a setting value", function(a) NS.Slash:CliGet(a) end },
  { "set",      "Set a setting value", function(a) NS.Slash:CliSet(a) end },
  { "list",     "List all settings", function() NS.Slash:CliList() end },
  { "reset",    "Reset one setting", function(a) NS.Slash:CliReset(a) end },
  { "resetall", "Reset this profile to defaults", function() NS.Slash:ConfirmResetAll() end },
  -- Every sub-verb a handler below accepts is named in its own `desc`, because the generated help
  -- index (`:377`) and the LibKa0s-Slash descriptor that feeds the settings landing page (`:389`)
  -- read these strings and nothing else. The README's command prose is hand-written and does NOT
  -- read them, so it drifts separately and is checked separately. A sub-verb missing here is a
  -- sub-verb nobody can discover (slash-commands-§4).
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

-- ── The disabled gate, in ONE place (slash-commands-§2) ─────────────────────────
--
-- A disabled addon answers a FEATURE verb by saying so and naming `/pm enable`, and does nothing
-- else. That was a trailing SHOULD nobody implemented until standard v2.54.0 made it precise enough
-- to audit; it is still a SHOULD, and this addon takes it because eight of its nineteen verbs create,
-- delete, rename, list, edit, unlock, lock or recover the panels it is currently standing down from
-- drawing, and a silent no-op on any of them leaves the player with no clue why nothing happened.
--
-- IT IS THE VERB TABLE THAT IS GATED, NOT THE VERBS. A guard pasted into each handler is eight
-- places to keep in step and a ninth to forget, and the next verb added forgets it by DEFAULT --
-- which is the wrong default for a courtesy nobody will notice is missing. `NS.COMMANDS` is the one
-- seam every verb passes through: the library's dispatcher reads `entry[3]` out of this very table,
-- and so does the degraded arm's own `run()` below, so wrapping the handlers HERE -- once, before
-- either reader exists -- reaches both surfaces and every future verb. The cost of the choice is
-- that a verb OPTS OUT by being named in ALWAYS_LIVE below, which is a list a reviewer can read.
--
-- ALWAYS_LIVE IS THE STANDARD'S OWN SET, spelled as data rather than as a chain of conditions: a
-- player must be able to READ AND REPAIR SETTINGS and REACH THE PANEL while the addon is off --
-- which is precisely when they are most likely to need to -- and `enable` above all, or the pair is
-- one-way again. `debug` and `perf` are diagnostics rather than features, since the usual reason to
-- reach for either is that the addon is misbehaving. `perf` is listed although this addon registers
-- no such verb: the set is the rule, not an inventory of today's table, and a `perf` arriving later
-- must not have to remember to come back here.
local ALWAYS_LIVE = {
  help = true, config = true, version = true, enable = true, disable = true,
  debug = true, perf = true,
  get = true, set = true, list = true, reset = true, resetall = true,
}
Sl.ALWAYS_LIVE = ALWAYS_LIVE

-- ONE tagged line, and nothing else. No second line explaining the state: a paragraph is a lecture
-- stapled to a command the player is about to re-run anyway. Through NS.L with the English source
-- string as the key (localization-§1/§2) -- the FIRST string in this addon to route through the
-- seam, which locales/enUS.lua records. The verb is a `%s` rather than part of the key so a
-- translator never has to retype a slash command, and it is resolved at CALL time so a locale file
-- loaded after this one still wins.
local DISABLED_KEY = "the addon is disabled \226\128\148 %s turns it back on"

--- Is the addon's own master switch off? Guarded on NS.db because a verb can be typed before
--- `NS:InitDB()` has run on a client that failed to load the DB at all, and `S:Get` would index a
--- nil profile. Read from the SCHEMA, never from a flag of this file's own: `settings.enabled` is
--- the one path the checkbox and `/pm enable` both write (slash-commands-§2), and a second copy
--- here would answer the player differently from the row they just ticked.
local function isDisabled()
  return NS.db ~= nil and NS.Schema:Get(NS.Schema.ENABLED_PATH) == false
end

for _, cmd in ipairs(NS.COMMANDS) do
  if not ALWAYS_LIVE[cmd[1]] then
    local act = cmd[3]
    cmd[3] = function(rest)
      if isDisabled() then
        print(NS.L[DISABLED_KEY]:format("|cffffff00/pm enable|r"))
        return
      end
      return act(rest)
    end
  end
end

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
  -- FormatKV is NOT a schema verb and must not be explained away: it is the `key = value` renderer
  -- the PANEL verbs call directly (`/pm panel <name>` at :101, `/pm panel <name> fitart`, and the
  -- field read and write echoes), and those verbs are exactly the ones this branch exists to keep
  -- working. Left unassigned it is nil, and `/pm panel <name>` raises "attempt to call field
  -- 'FormatKV'" — a degraded install that hard-errors on its own host-owned verb. The one line is
  -- reproduced rather than routed, because there is no library here to route to; it is asserted
  -- byte-for-byte against `lib.FormatKV` by the degradation suite so the two cannot drift.
  Sl.FormatKV       = function(path, valueStr)
    return ("|cFFFFFF00%s|r = |cFFFFFFFF%s|r"):format(tostring(path), tostring(valueStr))
  end
  Sl.PrintHelp      = explain
  Sl.BuildListLines = function() return { UNAVAILABLE } end
  Sl.CliList        = explain
  Sl.CliGet         = explain
  Sl.CliSet         = explain
  Sl.CliReset       = explain
  Sl.LandingRows    = function() return {} end
  Sl.HelpRows       = function() return {} end
  function Sl:CliVersion() print("v" .. tostring(Sl:Version())) end
  -- Kept WORKING rather than explained away: it is the one reset verb with no library dependency.
  -- Not because it walks the schema -- it does not, here or on the live arm -- but because
  -- ConfirmResetAll ends in `db:ResetProfile()`, which is AceDB's and needs nothing of LibKa0s.
  function Sl:CliResetAll() Sl:ConfirmResetAll() end
  -- A bare `/pm` runs the `config` row, the same rule the library's dispatcher follows
  -- (slash-commands-§4): bare opens the settings page and `help` prints the list. The row is looked
  -- up rather than called directly, so a table with no `config` falls back to the help answer.
  local function run(verb, rest)
    for _, cmd in ipairs(NS.COMMANDS) do
      if cmd[1] == verb then cmd[3](rest); return true end
    end
    return false
  end
  function Sl:OnSlash(input)
    if input == nil or input:match("^%s*$") then
      if not run("config", "") then explain() end
      return
    end
    local verb, rest = input:match("^(%S+)%s*(.-)$")
    verb = verb and verb:lower()
    if run(verb, rest) then return end
    print("unknown command '" .. tostring(verb) .. "'")
    explain()
  end
  return
end

--- The spelling `row` stores for `text`, matched against the row's own `values` without regard to
--- case, or nil when the row is not an enum or nothing matches. `values` is an array of
--- { value = ... } entries (strata) or a map of value -> label (the composed General visibility),
--- or a function returning either. The whole trimmed value is compared, never its first word.
local function canonicalEnumValue(row, text)
  if not (row and row.type == "string" and row.values) then return nil end
  local values = row.values
  if type(values) == "function" then values = values() end
  if type(values) ~= "table" then return nil end
  local typed = tostring(text or ""):match("^%s*(.-)%s*$"):lower()
  for key, entry in pairs(values) do
    local value = key
    if type(entry) == "table" and entry.value ~= nil then value = entry.value end
    if type(value) == "string" and value:lower() == typed then return value end
  end
  return nil
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
  -- wrong for a player typing a token: `/pm set settings.defaultStrata low` has always worked here.
  -- The typed value is matched against the ROW'S OWN values without regard to case, and the library
  -- is handed the spelling the row stores. That keeps strata (stored upper-case) and the composed
  -- General visibility (always / inCombat / outOfCombat / never) on one rule. The old adapter
  -- up-cased every enum row, which refused every visibility value. No match falls through with the
  -- text as typed, so the library's own refusal and its allowed-values line still answer, and the
  -- whole value has to match (Slash minor 10): `low junk` is refused. Every other type stays on
  -- the library's parser, including the number clamping and the color rescaling.
  parse = function(row, text)
    return lib.ParseValue(row, canonicalEnumValue(row, text) or text)
  end,

  -- A PLAIN table of the one string this addon actually overrides — never NS.L, whose metatable
  -- answers every key with the key itself (the `L` trap). The library's own RESET_ALL is "All
  -- settings reset to defaults"; this addon's names the PROFILE, because that is the blast radius
  -- (options-ui-§12) and because the old wording promised the panels were safe, which a profile
  -- reset does not keep. Named once at the top of this file, so the acknowledgment the library
  -- prints and the one the headless fallback prints cannot drift.
  L = { RESET_ALL = Sl.RESET_ALL_TEXT },
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
-- NOT the dispatcher's: the library's CliResetAll is a row walk, and a global reset is a PROFILE
-- reset (options-ui-§12). Every other verb here still delegates.
function Sl:CliResetAll()        return Sl:ConfirmResetAll()        end
function Sl:CliVersion()         return dispatcher:CliVersion()     end
function Sl:Text(key)            return dispatcher:Text(key)        end

-- The one `key = value` formatter, now the library's, so a panel field printed by BuildPanelLines
-- and a setting printed by CliGet render identically. This is a byte-level change: the library's
-- color escapes are UPPERCASE (|cFFFFFF00) where this addon's were lowercase. WoW is
-- case-insensitive about them, so the pixels are the same and only the source bytes move.
Sl.FormatKV = lib.FormatKV
