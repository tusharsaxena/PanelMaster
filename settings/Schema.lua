local addonName, NS = ...   -- luacheck: ignore addonName
NS.Schema = NS.Schema or {}
local S = NS.Schema
local C = NS.Constants
local print = NS.Print   -- secret-safe, [PM]-prefixed shared printer (events-frames-taint-§8)

-- One row per setting. This single table drives the AceDB defaults check, the panel widgets, and the
-- slash get/set/list/reset dispatch (architecture-§5) — add a setting here and all three surfaces
-- pick it up with no other edit. Paths resolve against NS.db.profile (per-character).
--
-- `group` names the panel section header, and row order within a group drives the two-column
-- pairing. `wide` forces a full-width row.
--
-- NOTE: these are the addon's settings. The PANELS themselves are not rows here — each is a
-- variable-length user-created object with no fixed widget, so the registry owns them
-- (modules/Registry.lua) as an architecture-§5 storage carve-out.

-- Sole sender (architecture-§4): every settings mutation that the renderer must react to broadcasts
-- this one message, from this file only.
local MSG_SETTINGS = "Ka0s_PanelMaster_SettingsChanged"
S.MSG_SETTINGS = MSG_SETTINGS

local function announce(what)
  if NS.bus then NS.bus:SendMessage(MSG_SETTINGS, what) end
end

S.Schema = {
  -- ── Master Controls ──
  { path = "settings.enabled", default = true, type = "bool", widget = "CheckBox",
    group = "Master Controls", label = "Enable panels",
    tooltip = "Master switch. Turning this off hides every panel without deleting any of them.",
    onChange = function() announce("enabled") end },

  -- A session-only row (never persisted): unlock is an editing state, not a preference. get/set
  -- route to NS.Unlock, and Schema:Set skips the db write for sessionOnly rows. Mirrors `/pm unlock`.
  { path = "state.unlocked", sessionOnly = true, default = false, type = "bool",
    widget = "CheckBox", group = "Master Controls", label = "Unlock panels",
    tooltip = "Show every panel with a drag handle and a name label so it can be moved. "
      .. "Session-only \226\128\148 always locked again after a reload.",
    get = function() return NS.State.unlocked end,
    set = function(v) if NS.Unlock then NS.Unlock:SetUnlocked(v) end end },

  { path = "state.preview", sessionOnly = true, default = false, type = "bool",
    widget = "CheckBox", group = "Master Controls", label = "Test mode",
    tooltip = "Put three sample panels on screen so you can see what a panel looks like. "
      .. "They are removed again when you turn this off.",
    get = function() return NS.State.preview end,
    set = function(v) if NS.Unlock then NS.Unlock:SetPreview(v) end end },

  -- Session-only: the value is the debug console WINDOW's visibility, not the NS.State.debug
  -- logging flag. Mirrors `/pm debug` with no argument.
  { path = "state.debugConsole", sessionOnly = true, default = false, type = "bool",
    widget = "CheckBox", group = "Master Controls", label = "Debug console",
    tooltip = "Show or hide the on-screen debug console. Session-only \226\128\148 resets on reload.",
    get = function() return NS.DebugLog ~= nil and NS.DebugLog:IsShown() end,
    set = function(v)
      if not NS.DebugLog then return end
      if v then NS.DebugLog:Show() else NS.DebugLog:Hide() end
    end },

  -- ── Editing ──
  -- How dragging behaves while unlocked.
  { path = "settings.showLabels", default = true, type = "bool", widget = "CheckBox",
    group = "Editing", label = "Show names while unlocked",
    tooltip = "Print each panel's name across the middle of it while panels are unlocked.",
    onChange = function() announce("showLabels") end },

  -- No onChange on either grid row: neither can change how a panel LOOKS. U.SnapPosition reads
  -- db.profile.settings live at drag-stop, so a new grid applies to the very next drag on its own —
  -- announcing would repaint every panel per mouse-up on the slider for nothing. `showLabels` above
  -- keeps its announce because U:Decorate reads it, and Decorate only ever runs from a render.
  { path = "settings.snapToGrid", default = true, type = "bool", widget = "CheckBox",
    group = "Editing", label = "Snap to grid",
    tooltip = "Round a dragged panel's position to the grid size below." },

  { path = "settings.gridSize", default = 4, type = "number",
    min = C.MIN_GRID, max = 64, step = 1, widget = "Slider",
    fmt = "%d px",   -- grid → "4 px" in the slash list/get output (slash-commands-§5)
    group = "Editing", label = "Grid size",
    tooltip = "The grid a dragged panel snaps to, in UI units. Ignored when snapping is off.",
    validate = function(v) return type(v) == "number" and v >= C.MIN_GRID and v <= C.MAX_GRID end },

  -- ── New Panel Defaults ──
  -- Applied to panels created AFTER a change here; existing panels are never retroactively altered,
  -- which is why these are separate settings rather than a global override.
  { path = "settings.defaultStrata", default = "LOW", type = "string", widget = "Dropdown",
    group = "New Panel Defaults", label = "Default frame strata", values = C.STRATA_OPTIONS,
    tooltip = "The layer a newly created panel sits in. LOW keeps it under essentially all "
      .. "interface frames, which is what a backdrop usually wants. DIALOG and above cover normal UI.",
    validate = function(v) return NS.Util.IsStrata(v) end },

  { path = "settings.defaultAlpha", default = 1.0, type = "number", min = 0, max = 1, step = 0.05,
    widget = "Slider",
    fmt = "%.2f",
    group = "New Panel Defaults", label = "Default opacity",
    tooltip = "The opacity a newly created panel starts at.",
    validate = function(v) return type(v) == "number" and v >= 0 and v <= 1 end },
}
-- NOTE: the debug LOGGING flag (NS.State.debug) is deliberately NOT a schema setting — it is
-- session-only, set via `/pm debug on|off`, and always off after a reload (debug-logging-§5). The
-- console WINDOW's visibility IS the `state.debugConsole` row above.

function S:FindRow(path)
  for _, row in ipairs(S.Schema) do
    if row.path == path then return row end
  end
  return nil
end

function S:ReadPath(root, path)
  local node = root
  for _, key in ipairs(NS.Util.SplitPath(path)) do
    if type(node) ~= "table" then return nil end
    node = node[key]
  end
  return node
end

function S:WritePath(root, path, value)
  local parts = NS.Util.SplitPath(path)
  local node = root
  for i = 1, #parts - 1 do
    local key = parts[i]
    if type(node[key]) ~= "table" then node[key] = {} end
    node = node[key]
  end
  node[parts[#parts]] = value
end

-- The single write seam. Panel widgets and the slash `set` both route through here, so validation,
-- the debug trace and the onChange reaction can never be skipped by one caller.
function S:Set(path, value)
  local row = S:FindRow(path)
  if not row then return false, "unknown path: " .. tostring(path) end
  if row.validate and not row.validate(value) then return false, "invalid value" end
  if row.sessionOnly then
    -- Session-only rows never touch the DB; the row's own set() applies the value.
    if row.set then row.set(value) end
  else
    S:WritePath(NS.db.profile, path, NS.Util.DeepCopy(value))
  end
  -- Every settings mutation is logged ONCE, here at the write seam (debug-logging-§10). Downstream
  -- reactors must not re-echo the same value.
  NS.Debug("Set", "%s = %s", tostring(path), tostring(value))
  if row.onChange then row.onChange(value) end
  return true
end

function S:Get(path)
  local row = S:FindRow(path)
  if row and row.get then return row.get() end
  return S:ReadPath(NS.db.profile, path)
end

function S:Default(path)
  local row = S:FindRow(path)
  return row and NS.Util.DeepCopy(row.default)
end

-- Boot validation (architecture-§5): every schema path must resolve against the defaults table, so a
-- typo in a path is caught loudly at load instead of silently reading nil forever. Returns the
-- number of unresolved paths, which is what the headless test asserts on.
--
-- THE ROW'S OWN `default` IS NOT AN ESCAPE HATCH, and used to be. This loop carried a third
-- conjunct, `and row.default == nil`, so a path only counted as unresolved when the row ALSO
-- declared no default — and every row in S.Schema declares one, which made the whole check
-- structurally unable to fire. It reported 0 for a typo'd path exactly as it did for a correct one,
-- and the headless case asserting `S:Register() == 0` was asserting a constant.
--
-- The two facts are independent. `row.default` is what the widget shows and what Defaults restores;
-- resolving against NS.defaults.profile is what says the setting has somewhere to be WRITTEN. A row
-- with a good default and a typo'd path is the worst case, not the exempt one: the panel renders,
-- the widget reads its default, the write lands on a key nothing else ever reads, and nothing
-- anywhere says so. So the default is not consulted at all — a path that does not resolve is
-- reported, full stop (savedvariables-§2: the declaration site is defaults/, not the row).
function S:Register()
  local p = NS.defaults and NS.defaults.profile
  if not p then return 0 end
  local unresolved = 0
  for _, row in ipairs(S.Schema) do
    -- Session-only rows (state.*) are the ONE exemption: they route through their own get/set and
    -- are never persisted, so they have no db-backed home to resolve against by design.
    if not row.sessionOnly and S:ReadPath(p, row.path) == nil then
      unresolved = unresolved + 1
      print("schema path does not resolve against the defaults: " .. tostring(row.path))
    end
  end
  return unresolved
end
