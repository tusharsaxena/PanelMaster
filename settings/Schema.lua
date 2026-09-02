local addonName, NS = ...   -- luacheck: ignore addonName
NS.Schema = NS.Schema or {}
local S = NS.Schema
local C = NS.Constants
local print = NS.Print   -- secret-safe, [PM]-prefixed shared printer (events-frames-taint-§8)

-- One row per setting. This single table drives the AceDB defaults check, the panel widgets, and the
-- slash get/set/list/reset dispatch (architecture-§5) — add a setting here and all three surfaces
-- pick it up with no other edit. Paths resolve against NS.db.profile (per-character).
--
-- `group` names the TAB (options-ui-§13): the General page draws itself with
-- H.RenderTabbedSchema, which partitions these rows by `group` in DECLARATION ORDER and draws one
-- tab per distinct group. So this array's order IS the tab order, and a group's rows must stay
-- contiguous -- a row filed under a group the array has already left prints that heading twice.
-- Row order within a group drives the two-column pairing. `wide` forces a full-width row.
--
-- THE FIRST TAB IS NOT DECLARED HERE. `Master controls` is composed and spliced at the head by
-- S:InstallMaster, below the array — see the block that defines it for why it cannot be a literal.
--
-- There is no `widget` field on a row any more, and its absence is the point: LibKa0s-Options-1.0's
-- RenderField dispatches on `type` alone (a `number` carrying `values` is a dropdown, everything
-- else numeric is a slider), so a second field naming the widget was a second selector to keep in
-- step and nothing read it. options-ui-§1 argues against exactly that shape.
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
  -- ── Editing ──
  -- Tab 2: everything about moving a panel around, in the order the flow engine pairs it —
  -- [names] [snap], [grid size] [outline thickness].
  --
  -- "Unlock panels" used to lead this tab. It is `Lock frame` on the Master controls tab now
  -- (options-ui-§15), un-inverted: the canonical row says LOCKED and this addon's state says
  -- UNLOCKED, and one of the two had to give. The four rows below still only mean anything while
  -- the panels are unlocked, which is the argument that put the switch here in the first place —
  -- what changed is that the canonical set is not a menu to take the convenient half of.

  -- How dragging behaves while unlocked.
  { path = "settings.showLabels", default = true, type = "bool",
    group = "Editing", label = "Show names while unlocked",
    tooltip = "Print each panel's name across the middle of it while panels are unlocked.",
    onChange = function() announce("showLabels") end },

  -- No onChange on either grid row: neither can change how a panel LOOKS. U.SnapPosition reads
  -- db.profile.settings live at drag-stop, so a new grid applies to the very next drag on its own —
  -- announcing would repaint every panel per mouse-up on the slider for nothing. `showLabels` above
  -- keeps its announce because U:Decorate reads it, and Decorate only ever runs from a render.
  { path = "settings.snapToGrid", default = true, type = "bool",
    group = "Editing", label = "Snap to grid",
    tooltip = "Round a dragged panel's position to the grid size below." },

  -- Declared immediately after the switch that modes it, so the flow engine puts the two on ONE
  -- line and the reader sets the mode and its size without moving down a row.
  --
  -- "Recover panels" no longer rides this row's right half. It was there on the argument that it is
  -- the other thing you reach for when a layout has gone wrong, which still holds — but pairing the
  -- snap switch with its own slider is the stronger claim, and a button cannot be the right half of
  -- a line whose left half is already taken. It is drawn as this tab's afterGroup footer instead
  -- (settings/Panel.lua), which is where the flow engine puts a group's buttons.
  { path = "settings.gridSize", default = 4, type = "number",
    min = C.MIN_GRID, max = 64, step = 1,
    fmt = "%d px",   -- grid → "4 px" in the slash list/get output (slash-commands-§5)
    group = "Editing", label = "Grid size",
    tooltip = "The grid a dragged panel snaps to, in UI units. Ignored when snapping is off.",
    validate = function(v) return type(v) == "number" and v >= C.MIN_GRID and v <= C.MAX_GRID end },

  -- Promoted from the hardcoded C.UNLOCK_OUTLINE_PX, which was 2 and still is: the default IS the
  -- literal it replaced, so every existing install draws its unlock outline exactly as it did.
  -- The constant stays as the fallback modules/Unlock.lua reads when the db is not up yet, and as
  -- the one place the shipped number is written down.
  --
  -- Clamped on the way in as well as on the way out: this arrives from SavedVariables, and an
  -- outline of 0 (or of 400) is not an error, it is a panel that cannot be found in unlock mode.
  { path = "settings.unlockOutlineSize", default = 2, type = "number",
    min = C.MIN_UNLOCK_OUTLINE, max = C.MAX_UNLOCK_OUTLINE, step = 1,
    fmt = "%d px",
    group = "Editing", label = "Unlock outline thickness",
    tooltip = "How thick the gold outline around an unlocked panel is, in UI units. Raise it if "
      .. "you are hunting for a small panel on a busy screen.",
    validate = function(v)
      return type(v) == "number" and v >= C.MIN_UNLOCK_OUTLINE and v <= C.MAX_UNLOCK_OUTLINE
    end,
    onChange = function() announce("unlockOutlineSize") end },

  -- ── New panels ──
  -- Tab 3, and last because it is the one you set once and leave: it changes nothing on screen
  -- until the next time you make a panel.
  --
  -- Applied to panels created AFTER a change here; existing panels are never retroactively altered,
  -- which is why these are separate settings rather than a global override. `/pm panel X reset`
  -- lands on the same four values, so "reset this panel" and "make a new one" cannot drift.
  --
  -- Size first: it is the thing a player notices about a new panel, and the two read across as one
  -- line. Then the layer and the opacity.
  { path = "settings.defaultWidth", default = 240, type = "number",
    min = C.MIN_SIZE, max = C.MAX_SIZE, step = 1,
    fmt = "%d px",
    group = "New panels", label = "Default width",
    tooltip = "How wide a newly created panel starts. Existing panels are not touched.",
    validate = function(v) return type(v) == "number" and v >= C.MIN_SIZE and v <= C.MAX_SIZE end },

  { path = "settings.defaultHeight", default = 120, type = "number",
    min = C.MIN_SIZE, max = C.MAX_SIZE, step = 1,
    fmt = "%d px",
    group = "New panels", label = "Default height",
    tooltip = "How tall a newly created panel starts. Existing panels are not touched.",
    validate = function(v) return type(v) == "number" and v >= C.MIN_SIZE and v <= C.MAX_SIZE end },

  { path = "settings.defaultStrata", default = "LOW", type = "string",
    group = "New panels", label = "Default frame strata", values = C.STRATA_OPTIONS,
    tooltip = "The layer a newly created panel sits in. LOW keeps it under essentially all "
      .. "interface frames, which is what a backdrop usually wants. DIALOG and above cover normal UI.",
    validate = function(v) return NS.Util.IsStrata(v) end },

  { path = "settings.defaultAlpha", default = 1.0, type = "number", min = 0, max = 1, step = 0.05,
    fmt = "%.2f",
    group = "New panels", label = "Default opacity",
    tooltip = "The opacity a newly created panel starts at.",
    validate = function(v) return type(v) == "number" and v >= 0 and v <= 1 end },
}
-- NOTE: the debug LOGGING flag (NS.State.debug) is deliberately NOT a schema setting — it is
-- session-only, set via `/pm debug on|off`, and always off after a reload (debug-logging-§5). The
-- console WINDOW's visibility IS the `state.debugConsole` row the Master controls block emits.

-- ── Master controls (options-ui-§15) ────────────────────────────────────────────
--
-- Tab 1 of the General page, and the array above does NOT declare it: it is COMPOSED, out of
-- LibKa0s-Options-1.0's `MasterControls`, and spliced at the head by S:InstallMaster below. Nine
-- addons were about to hand-write the same eight rows in eight orders; the composer is what makes
-- them identical without nine people agreeing to be careful, and it owns the set, the order, the
-- labels and the ranges outright.
--
-- WHY IT IS NOT IN THE ARRAY. The composer lives on NS.Helpers, and settings/OptionsSetup.lua —
-- which builds that instance — loads AFTER this file (the descriptor reads NS.Schema). So the rows
-- cannot exist at this file's load time, and the seam that CAN build them calls in.
--
-- WHAT A LIBRARY-LESS INSTALL LOSES, said out loud because options-ui-§1 requires it measured
-- rather than assumed: these six rows, and nothing else. The stub's composers answer an empty list
-- (settings/OptionsSetup.lua explains why a hand-copied set there would be the copy that goes
-- stale), so `/pm list|get|set` in a degraded install reaches the Editing and New panels rows only.
-- tests/test_schema.lua pins that count by name so it can never widen silently.

-- "Test mode" is NOT canonical. It is this addon's own, and it rides the composer's `extra`, which
-- appends AFTER the mandated block and never interleaves with it (options-ui-§16). Hoisted to a
-- file constant because a composer never writes to what it is handed, so this table is safe to
-- re-use across renders.
local TEST_MODE_ROW = {
  path = "state.preview", sessionOnly = true, default = false, type = "bool",
  label = "Test mode",
  tooltip = "Put three sample panels on screen so you can see what a panel looks like. "
    .. "They are removed again when you turn this off.",
  get = function() return NS.State.preview end,
  set = function(v) if NS.Unlock then NS.Unlock:SetPreview(v) end end,
}

-- Wire this addon's half onto one composed row, found by the path the composer gave it.
--
-- The composers emit ordinary schema rows and NOTHING else — no get, no set, no onChange, no
-- validate — because none of those is canonical: they are where a value lives in THIS addon, which
-- is exactly what the descriptor (settings/OptionsSetup.lua) says a host owns. So the block is
-- composed first and wired here, by path.
--
-- Reported rather than silent when the path does not match, because the failure it catches is the
-- one nothing else can see: a composer that renamed a leaf leaves the row on the page, drawn,
-- reading and writing nowhere.
local function wire(rows, path, fields)
  for _, row in ipairs(rows) do
    if row.path == path then
      for key, value in pairs(fields) do row[key] = value end
      return row
    end
  end
  print("master controls: no composed row at " .. tostring(path) ..
    " — the canonical set has moved and settings/Schema.lua has not")
  return nil
end

--- Compose the Master controls block and splice it at the HEAD of the schema.
---
--- Called from settings/OptionsSetup.lua on both arms, the moment NS.Helpers exists. Idempotent,
--- and answers whether the rows arrived so a test can assert on the degraded case.
---
--- @param H table  the LibKa0s-Options-1.0 instance (or its degradation stub)
--- @return boolean true when the canonical rows were spliced in
function S:InstallMaster(H)
  if S.__masterInstalled then return true end
  if not (H and type(H.MasterControls) == "function") then return false end

  local rows, tail = H.MasterControls{
    prefix    = "settings.",
    page      = "general",
    addonName = "Ka0s Panel Master",
    -- NOT frameless: every panel this addon draws is positionable, and modules/Unlock.lua calls
    -- SetMovable on each one. The frame-only rows therefore all apply.
    --
    -- They are the ADDON-WIDE ones (options-ui-§15). This addon's frames are per-panel, so the
    -- per-panel scale, opacity and unlock stay on the Panels page's own editor and are different
    -- settings from these: master scale multiplies every panel's own, master opacity multiplies
    -- every panel's own, and Lock frame is the all-or-nothing switch the per-panel Unlock tick
    -- sits under.
    debugConsolePath = "state.debugConsole",
    -- The addon's shipped values, so the composer changes what is DECLARED and never what is
    -- stored. `locked` ships TRUE because a panel is locked until the player says otherwise —
    -- the composer's own default is the other way round, and adopting it would hand every
    -- install a screen full of draggable, labeled panels on the next login.
    defaults  = { enabled = true, visibility = "always", scale = 1, alpha = 1, locked = true },
    extra     = { TEST_MODE_ROW },
    onResetPosition = function()
      local n = NS.Registry:ResetPositions()
      print(("moved %d %s back to the middle of the screen."):format(n, n == 1 and "panel" or "panels"))
    end,
    -- options-ui-§12's global reset, verbatim and confirm-gated, and the SAME entry point the
    -- header Defaults button and `/pm resetall` use. Not a third door onto the same act.
    onResetAll = function() if NS.Slash then NS.Slash:ConfirmResetAll() end end,
  }
  if #rows == 0 then return false end

  wire(rows, "settings.enabled", {
    tooltip = "Master switch. Turning this off hides every panel without deleting any of them.",
    onChange = function() announce("enabled") end,
  })
  wire(rows, "settings.visibility", {
    tooltip = "When your panels are drawn at all. Combat is the game's own in-combat state, so "
      .. "\"Only out of combat\" hides every panel the moment a fight starts.",
    onChange = function() announce("visibility") end,
  })
  wire(rows, "settings.scale", {
    fmt = "%.2f",
    tooltip = "Scales every panel at once, on top of each panel's own scale. The stored size of a "
      .. "panel is unchanged \226\128\148 what moves is how big it turns out on screen.",
    onChange = function() announce("scale") end,
  })
  wire(rows, "settings.alpha", {
    fmt = "%.2f",
    tooltip = "Fades every panel at once, on top of each panel's own opacity and the opacity in "
      .. "each of its colors.",
    onChange = function() announce("alpha") end,
  })
  -- Lock frame is SESSION-ONLY here, and its path moves out of the block's own prefix for exactly
  -- the reason the composer moves the debug console's: session state does not live under
  -- `settings.`. Unlocking is an editing mode, not a preference — a player who unlocks, drags a
  -- panel and reloads must come back to a locked UI, which is what this addon has always done and
  -- what its own tooltip promises.
  --
  -- The SENSE is un-inverted, which is the change: the row says LOCKED where NS.State says
  -- UNLOCKED, so both halves of the seam negate. There is no stored value to migrate — the old
  -- `state.unlocked` row was session-only too, so nothing was ever written for a migration to
  -- read — and tests/test_schema.lua pins the negation in both directions.
  wire(rows, "settings.locked", {
    path = "state.locked", sessionOnly = true,
    tooltip = "Stop your panels being dragged. Unticking gives every panel a drag handle and a "
      .. "name label so it can be moved. Session-only \226\128\148 always locked again after a reload.",
    get = function() return not NS.State.unlocked end,
    set = function(v) if NS.Unlock then NS.Unlock:SetUnlocked(not v) end end,
  })
  wire(rows, "state.debugConsole", {
    tooltip = "Show or hide the on-screen debug console. Session-only \226\128\148 resets on reload.",
    get = function() return NS.DebugLog ~= nil and NS.DebugLog:IsShown() end,
    set = function(v)
      if not NS.DebugLog then return end
      if v then NS.DebugLog:Show() else NS.DebugLog:Hide() end
    end,
  })

  -- Range and membership validation for the composed rows, built from each row's OWN bounds rather
  -- than from a second copy of them here: the canonical range is the library's, and a host constant
  -- beside it is the one that goes stale. This is what makes `/pm set settings.scale 40` refuse at
  -- the write seam, exactly as every hand-written slider above already does.
  for _, row in ipairs(rows) do
    if row.validate == nil then
      if row.type == "number" and row.min and row.max then
        local lo, hi = row.min, row.max
        row.validate = function(v) return type(v) == "number" and v >= lo and v <= hi end
      elseif row.type == "string" and type(row.values) == "table" then
        local values = row.values
        row.validate = function(v) return values[v] ~= nil end
      end
    end
  end

  -- At the HEAD, in order, because the array's order IS the tab order and Master controls is tab 1.
  for i = #rows, 1, -1 do
    table.insert(S.Schema, 1, rows[i])
  end

  -- The group name IS the afterGroup key (options-ui-§15), so settings/Panel.lua reads the tail
  -- from here rather than re-deriving a name that could disagree with the rows'.
  S.MasterGroup = rows[1].group
  S.MasterAfterGroup = tail
  S.__masterInstalled = true
  return true
end

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
