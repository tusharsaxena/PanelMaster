local _, NS = ...
NS.Schema = NS.Schema or {}
local S = NS.Schema
local C = NS.Constants
local print = NS.Print   -- secret-safe, [PM]-prefixed shared printer (events-frames-taint-§8)

-- One row per setting. This single table drives the AceDB defaults check, the panel widgets, and the
-- slash get/set/list/reset dispatch (architecture-§5) — add a setting here and all three surfaces
-- pick it up with no other edit. Paths resolve against NS.db.profile (the active profile).
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
-- NOTE: these are the addon's settings. The PANELS themselves are not rows here — the panel set is
-- a structural registry, and its one writer is modules/Registry.lua (architecture-§5, named in
-- docs/ARCHITECTURE.md → Settings Schema).

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
    min = C.MIN_GRID, max = C.MAX_GRID, step = 1,
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
-- LibKa0s-Options-1.0's `MasterControls`, and spliced at the head by S:InstallMaster below. Eleven
-- addons were about to hand-write the same canonical set in eleven orders; the composer is what
-- makes them identical without eleven people agreeing to be careful, and it owns the set, the
-- order, the labels and the ranges outright. The set is EIGHT rows at its fullest; this addon
-- takes seven of them, being exempt from Test mode (options-ui-§15 -- unlocking is its preview).
--
-- WHY IT IS NOT IN THE ARRAY. The composer lives on NS.Helpers, and settings/OptionsSetup.lua —
-- which builds that instance — loads AFTER this file (the descriptor reads NS.Schema). So the rows
-- cannot exist at this file's load time, and the seam that CAN build them calls in.
--
-- WHAT A LIBRARY-LESS INSTALL LOSES, said out loud because options-ui-§1 requires it measured
-- rather than assumed: these seven rows, and nothing else — all seven are the composer's. The stub's
-- composers answer an empty list (settings/OptionsSetup.lua explains why a hand-copied set there
-- would be the copy that goes stale), so `/pm list|get|set` in a degraded install reaches the
-- Editing and New panels rows only. tests/test_schema.lua pins that count by name so it can never
-- widen silently.

-- ── The addon-wide switch's stored path (slash-commands-§2) ────────────────────
--
-- Named because THREE surfaces write it and the standard requires that they be the same write:
-- the *Enable Ka0s Panel Master* checkbox composed below, and `/pm enable` and `/pm disable` in
-- settings/Slash.lua. The verbs are ALIASES and hold no state of their own -- no second key, no
-- session flag -- so the checkbox and the verbs can never show the player two different answers,
-- and one `onChange` runs whichever surface was used.
--
-- It is the composer's own leaf under this block's `settings.` prefix, so the string is what
-- `prefix .. "enabled"` produces. Spelled once here rather than at each of the three call sites.
S.ENABLED_PATH = "settings.enabled"

-- ── The minimap button's row path and its store (launcher-§3) ─────────────────
--
-- TWO NAMES, ONE STATE. `S.MINIMAP_PATH` is the ROW: its schema path, and so its CLI name
-- (slash-commands-§3). It reads in the row's own sense, SHOWN, so `/pm get global.minimap.shown`
-- answers true while the button is on the minimap. `S.MINIMAP_STORE` is where that state LIVES:
-- LibDBIcon's own `hide` key, the one its right-click menu writes, and the ONLY stored key. Nothing
-- is ever written or declared at the row's path -- a stored `shown` beside `hide` would be a second
-- copy of one state (anti-pattern #81) -- so the row owns its storage through its own `get`/`set`.
--
-- Both are named here because four places have to agree on them: `S:InstallMaster` hands the path
-- to the composer and wires the row's `get`/`set` onto the store, `S:SnapshotPersisted` leaves the
-- row out of the profile picture, and `S:Register` skips the row's path and checks the store
-- against the GLOBAL defaults instead. Four literals would be four chances to typo a path that
-- reads and writes nowhere while raising nothing.
--
-- TAKEN VERBATIM BY THE COMPOSER, unprefixed -- like the debug console's, and for a stricter
-- reason: the console's path is merely outside the block's `settings.` prefix, while this one is
-- outside the PROFILE. The table is LibDBIcon's own and it lives in the global store, because a
-- minimap button belongs to the installation rather than to a profile (defaults/Global.lua states
-- the argument).
--
-- THE SENSE INVERTS between the two. That inversion is the HOST's, not the library's -- the
-- composer emits an ordinary bool row and the row's own `get`/`set`, wired in `S:InstallMaster`,
-- negate. The single write seam calls them on every surface's write, which is the same place Lock
-- frame's un-inversion happens and for the same reason.
--
-- The path used to be the store's (`global.minimap.hide`), which made the CLI answer the opposite
-- of the checkbox. The rename moved NO storage: an existing `hide = true` reads as shown = false
-- with no SavedVariables migration and no schema-version bump, and the old path now answers the
-- unknown-setting refusal like any other path no row declares.
S.MINIMAP_PATH = "global.minimap.shown"
S.MINIMAP_STORE = "global.minimap.hide"

-- ── The runtime: LibKa0s-Schema-1.0 (architecture-§5, debug-logging-§10) ──────
--
-- The rows above are this addon's; the machinery around them is the library's. The path walk, the
-- row index, the single write seam, the bulk bracket and the boot shape check are ONE instance
-- built below, and every public name this file used to define for itself -- `S:Set`, `S:Get`,
-- `S:FindRow`, `S:Default`, `S:Register`, `S.BulkBegin`, `S.BulkEnd`, `S.BulkLine` -- now delegates
-- to it, so not one call site moved. The Options and Slash descriptors take the instance's members
-- as values (settings/OptionsSetup.lua, settings/Slash.lua), which is safe because nothing sits in
-- front of this seam: the minimap inversion that used to branch inside it is the row's own
-- `get`/`set` now.
--
-- The degradation stub (docs/api/Schema/version-2-docs.md, "The degradation stub"). A load without
-- the library is WRITE-COMPLETING and LOG-SILENT: reads, writes (Set, and minor 2's all-or-nothing
-- SetMany), each row's validate, normalize and onChange, the instance id forwarded through Get and
-- ApplyDefault, and the sweep bracket's depth all work, because host writers (the Registry's bulk
-- verbs, Reset All, `/pm set` where the Slash major survives) reach this seam on a degraded load
-- too. So does minor 2's `writeThrough`: `Set` and `SetMany` store a listed path that has no row
-- raw -- a copy, no validate, normalize or onChange -- and announce it with a synthetic
-- `{ path, writeThrough }` row, while every other row-less path is still refused. What it does not
-- reproduce is what only feeds the debug console -- the per-write `[Set]` line and the bracket's
-- tally -- and the degraded console stub discards those lines anyway. This is a documented
-- duplication rather than anti-pattern #47: options-ui-§1's no-copy MUST names widget makers, the
-- flow engine, the header and layout constants, not a runtime write path, and "the library is
-- absent" is not "the settings cannot be written". Its refusals are this addon's own words.
--
-- Built by a function, not written inline, so it closes over nothing of this file: it cannot reach
-- the library it stands in for. tests/test_surface_parity.lua holds both of its levels to the live
-- surface, and tests/test_schema.lua drives its writes.
local function hostSchemaStub()
  local stubLib = {}
  local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = copy(x) end
    return out
  end
  function stubLib.SplitPath(path)
    local parts = {}
    if path ~= nil then
      for seg in tostring(path):gmatch("[^%.]+") do parts[#parts + 1] = seg end
    end
    return parts
  end
  local function partsOf(p) return type(p) == "table" and p or stubLib.SplitPath(p) end
  function stubLib.Read(root, p, first)
    local parts, node = partsOf(p), root
    first = first or 1
    if type(root) ~= "table" or #parts < first then return nil end
    for i = first, #parts do
      if type(node) ~= "table" then return nil end
      node = node[parts[i]]
    end
    return node
  end
  function stubLib.Write(root, p, value, first)
    local parts, node = partsOf(p), root
    first = first or 1
    if type(root) ~= "table" or #parts < first then return end
    for i = first, #parts - 1 do
      if type(node[parts[i]]) ~= "table" then node[parts[i]] = {} end
      node = node[parts[i]]
    end
    node[parts[#parts]] = value
  end
  function stubLib.SameValue(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do if not stubLib.SameValue(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
  end

  function stubLib.New(_, d)
    local R, depth = {}, 0
    local rows = d.rows
    -- writeThrough (minor 2): read ONCE, here, as the live instance reads it. One synthetic row per
    -- listed path, handed to announce by identity so a write allocates nothing.
    local throughRows = {}
    if type(d.writeThrough) == "table" then
      for _, path in ipairs(d.writeThrough) do
        if type(path) == "string" and path ~= "" then
          throughRows[path] = { path = path, writeThrough = true }
        end
      end
    end
    local function resolve(parts, id)
      if type(d.resolveRoot) ~= "function" then return nil end
      return d.resolveRoot(parts, id)
    end
    function R.AllRows() return rows end
    function R.FindRow(path)
      if type(path) ~= "string" then return nil end
      for _, row in ipairs(rows) do
        if type(row) == "table" and row.path == path then return row end
      end
    end
    function R.AddRows(list, at)
      if type(list) ~= "table" then return 0 end
      at = type(at) == "number" and math.floor(at) or #rows + 1
      if at > #rows + 1 then at = #rows + 1 elseif at < 1 then at = 1 end
      for i, row in ipairs(list) do table.insert(rows, at + i - 1, row) end
      return #list
    end
    function R.Reindex() end
    function R.Get(path, id)
      local row = R.FindRow(path)
      if row and type(row.get) == "function" then return row.get(id) end
      if type(path) ~= "string" or (row and row.sessionOnly) then return nil end
      local parts = stubLib.SplitPath(path)
      local root, first = resolve(parts, id)
      if type(root) ~= "table" then return nil end
      return stubLib.Read(root, parts, first)
    end
    -- Where a STORED row's value lives now: parts, root, first and the resolved id, or no root.
    local function target(path, id)
      local parts = stubLib.SplitPath(path)
      local root, first, rid = resolve(parts, id)
      if type(root) ~= "table" then root = nil end
      if rid == nil then rid = id end
      return parts, root, first, rid
    end
    -- The value the row wants stored: `value`, or what row.normalize(value, rid) answers. A nil
    -- from it is a refusal, so a normalize cannot clear a setting to absence.
    local function normalized(row, value, rid)
      if type(row.normalize) ~= "function" then return value end
      local out, why = row.normalize(value, rid)
      if out == nil then return nil, "invalid value", why end
      return out
    end
    -- Everything checked before a store, shared by Set and SetMany so a batch refuses on the
    -- rules a single write does: validate, normalize, then nowhere-to-store. A plan to commit,
    -- or `nil, err, why` with nothing stored.
    local function prepare(row, path, value, id)
      local stored = type(row.set) ~= "function" and not row.sessionOnly
      local parts, root, first, rid = nil, nil, nil, id
      if stored then parts, root, first, rid = target(path, id) end
      if type(row.validate) == "function" then
        local ok, why = row.validate(value, rid)
        if not ok then return nil, "invalid value", why end
      end
      local err, why
      value, err, why = normalized(row, value, rid)
      if err then return nil, err, why end
      if stored and not root then return nil, "nowhere to store " .. path .. " yet" end
      return { row = row, path = path, parts = parts, root = root, first = first, rid = rid,
               value = value, stored = stored }
    end
    local function store(plan)
      if type(plan.row.set) == "function" then
        plan.row.set(plan.value)
      elseif plan.stored then
        stubLib.Write(plan.root, plan.parts, copy(plan.value), plan.first)
      end
    end
    local function react(plan)
      if type(plan.row.onChange) == "function" then plan.row.onChange(plan.value, plan.rid) end
    end
    local function announceOne(plan)
      if type(d.announce) == "function" then d.announce(plan.row, plan.path, plan.value, plan.rid) end
    end
    -- The row a write goes through: the indexed row, else the path's synthetic writeThrough row.
    -- That row carries no set, validate, normalize or onChange, so the ordinary plan below stores
    -- it raw (a copy, at the resolved root) and announces it with nothing reacting.
    local function writeRow(path)
      return R.FindRow(path) or (type(path) == "string" and throughRows[path]) or nil
    end
    -- The seam's order without its log and tally: refuse, validate, store, react, announce.
    function R.Set(path, value, id)
      local row = writeRow(path)
      if not row then return false, "unknown path: " .. tostring(path) end
      local plan, err, why = prepare(row, path, value, id)
      if not plan then return false, err, why end
      store(plan)
      react(plan)
      announceOne(plan)
      return true
    end
    -- Phase 1: every entry checked before any is stored. The plans, or `nil, err, why, i`.
    local function prepareBatch(entries, id)
      local plans = {}
      for i, e in ipairs(entries) do
        local path = type(e) == "table" and e.path or nil
        local row = writeRow(path)
        if not row then return nil, "unknown path: " .. tostring(path), nil, i end
        local plan, err, why = prepare(row, path, e.value, id)
        if not plan then return nil, err, why, i end
        plans[i] = plan
      end
      return plans
    end
    -- Phase 2 in the live seam's order: every store, then every onChange, so a reaction reading
    -- a sibling row sees the whole batch.
    local function commitBatch(plans)
      for _, plan in ipairs(plans) do store(plan) end
      for _, plan in ipairs(plans) do react(plan) end
    end
    -- The batch's tail: the host's announceBatch once when it has one, else announce per write.
    local function announceBatch(plans)
      if #plans == 0 then return end
      if type(d.announceBatch) ~= "function" then
        for _, plan in ipairs(plans) do announceOne(plan) end
        return
      end
      local writes = {}
      for i, p in ipairs(plans) do
        writes[i] = { row = p.row, path = p.path, value = p.value, rid = p.rid }
      end
      d.announceBatch(writes, plans[1].rid)
    end
    -- Several rows as ONE act, all or nothing: one refusal answers `false, err, why, index` with
    -- nothing stored and nothing called. `opts.act` runs the stores inside one bracket.
    function R.SetMany(entries, opts)
      if type(entries) ~= "table" then entries = {} end
      if type(opts) ~= "table" then opts = {} end
      local plans, err, why, at = prepareBatch(entries, opts.instanceId)
      if not plans then return false, err, why, at end
      if opts.act ~= nil then
        R.BulkRun(opts.act, opts.scope, function() commitBatch(plans) end)
      else
        commitBatch(plans)
      end
      announceBatch(plans)
      return true
    end
    function R.Default(path)
      local row = R.FindRow(path)
      return row and copy(row.default)
    end
    function R.ApplyDefault(row, id)
      if type(row) ~= "table" or type(row.path) ~= "string" or row.default == nil then return false end
      local exempt = d.resetExempt
      if depth > 0 and type(exempt) == "table" and exempt[row.path] then return false end
      return R.Set(row.path, copy(row.default), id)
    end
    -- The bracket keeps its depth, because the sweep veto above reads it; it counts nothing.
    function R.BulkBegin() depth = depth + 1 end
    function R.BulkEnd() if depth > 0 then depth = depth - 1 end end
    function R.BulkRun(act, scope, fn)
      R.BulkBegin(act, scope)
      local ok, err = pcall(fn, { profileReset = false })
      R.BulkEnd(act, scope)
      if not ok then error(err, 0) end
    end
    function R.BulkAdd() end
    function R.InBulk() return depth > 0 end
    function R.CountOffDefault() return 0 end
    function R.ResetCounted(fn) fn() end
    function R.ConsumeResetCount() return nil end
    -- SILENT, where the reference stub prints one line. That line would be a second unprompted
    -- login line on a degraded install, on top of the one core/CoreSetup.lua already prints to
    -- name the cause -- the reason the launcher stub stays quiet too. The shape check is a
    -- developer's gate, and the headless suite runs it on the live arm.
    function R.Validate() return 0, 0, 0 end
    return R
  end
  return stubLib
end

local SchemaLib = LibStub and LibStub("LibKa0s-Schema-1.0", true) or hostSchemaStub()

-- The instance. `rows` is the array above, held by reference, so the composed block
-- S:InstallMaster splices in through AddRows is in the same table every reader already holds.
local R = SchemaLib:New({
  rows = S.Schema,
  -- Every stored row but one lives in the active profile, and the one that does not (the minimap
  -- row) carries its own get/set, so it never reaches this resolver. `nil, 1` before the DB exists
  -- is "nowhere yet", which the seam refuses rather than raising on a nil index.
  resolveRoot = function() return NS.db and NS.db.profile, 1 end,
  -- Read at CALL time, so the sink is whatever core/DebugLogSetup.lua left in NS.Debug. No
  -- `debugEnabled`: NS.Debug gates on the session flag itself, as it always has. No `format`: the
  -- library's `tostring` fallback is the line this seam always wrote, byte for byte.
  debug = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end,
  print = function(line) print(line) end,
  -- A PLAIN table of the two refusals this addon has always answered with, never NS.L (the `L`
  -- trap: its metatable answers every key with the key itself).
  L = { NOT_FOUND = "unknown path: %s", INVALID = "invalid value" },
  -- No `announce`: every row that broadcasts does it from its own onChange. No `resetExempt`: see
  -- docs/revendor/2026-09-23-v1.55.0/05_SUMMARY.md -- no player reaches a library sweep of these rows.
  --
  -- `writeThrough` (Schema minor 2; options-ui-§1 route (a), slash-commands-§1). The master switch
  -- is a COMPOSED row, so whenever the Options composer is absent -- the whole library, or Options
  -- alone -- `settings.enabled` has no row, and `/pm enable` / `/pm disable` would be refused on the
  -- very load they most need to work. Listed here, the path is stored raw without a row: no
  -- validate and no onChange, so Sl:CliEnable re-evaluates the latch itself after the write. On a
  -- full load the composed row exists and takes the write, list or no list. The same list reaches
  -- the stub above, which reads it from this one descriptor.
  writeThrough = { S.ENABLED_PATH },
})

-- The resolved library (or the stub standing in for it) and the instance, published for the two
-- descriptors and for the parity suite.
NS.SchemaLib, NS.SchemaRuntime = SchemaLib, R

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
    addonName = NS.BRAND,
    -- NOT frameless: every panel this addon draws is positionable, and modules/Unlock.lua calls
    -- SetMovable on each one. The frame-only rows therefore all apply.
    --
    -- They are the ADDON-WIDE ones (options-ui-§15). This addon's frames are per-panel, so the
    -- per-panel scale, opacity and unlock stay on the Panels page's own editor and are different
    -- settings from these: master scale multiplies every panel's own, master opacity multiplies
    -- every panel's own, and Lock frame is the all-or-nothing switch the per-panel Unlock tick
    -- sits under.
    debugConsolePath = "state.debugConsole",
    -- The *Minimap button* row (launcher-§5, OptionsCompose minor 7). STORED, not session-only:
    -- a button the player hid stays hidden across a reload, which is the difference between it and
    -- the two rows above it. It opens its own line here, because this addon passes no
    -- `testModePath` for the composer to pair beside it.
    minimapPath = S.MINIMAP_PATH,
    -- The addon's shipped values, so the composer changes what is DECLARED and never what is
    -- stored. `locked` ships TRUE because a panel is locked until the player says otherwise —
    -- the composer's own default is the other way round, and adopting it would hand every
    -- install a screen full of draggable, labeled panels on the next login.
    --
    -- `debugConsole = false` is what the row RESETS to. The composer declares that row no default,
    -- and the schema runtime reads a nil default as "no restore", so without it a row reset --
    -- `/pm reset state.debugConsole`, or the library's RestoreDefaults("general") walk -- would
    -- leave an open console open. Both always closed it; tests/test_schema.lua pins both. The
    -- General page's Defaults BUTTON is neither: settings/Panel.lua rebinds it to the profile
    -- reset, which never writes this session-only row, so it leaves an open console open and
    -- always has.
    defaults  = { enabled = true, visibility = "always", scale = 1, alpha = 1, locked = true,
                  debugConsole = false },
    -- No `testModePath`, on purpose (options-ui-§15, standard v2.49.0): unlocking already shows
    -- every panel with its outline and name, so the unlocked view IS this addon's test mode and
    -- Lock frame is its switch. A second switch would only duplicate it.
    onResetPosition = function()
      local n = NS.Registry:ResetPositions()
      print(("moved %d %s back to the middle of the screen."):format(n, n == 1 and "panel" or "panels"))
    end,
    -- options-ui-§12's global reset, verbatim and confirm-gated, and the SAME entry point the
    -- header Defaults button and `/pm resetall` use. Not a third door onto the same act.
    onResetAll = function() if NS.Slash then NS.Slash:ConfirmResetAll() end end,
  }
  if #rows == 0 then return false end

  wire(rows, S.ENABLED_PATH, {
    tooltip = "Master switch. Turning this off stands the addon down: every panel is hidden, every "
      .. "event and message it watches is unregistered and the mouseover ticker stops. No panel is "
      .. "deleted, and the slash commands and this page keep working.",
    -- THE LATCH, not a repaint (slash-commands-§7). This row is the one stored path the *Enable Ka0s
    -- Panel Master* checkbox, `/pm enable` and `/pm disable` all write, so this onChange is where
    -- all three arrive -- and what they arrive at is a stand-down or a stand-up, not a hide.
    --
    -- IT DOES NOT `announce`, and that is the change rather than an omission. Every other row here
    -- broadcasts SettingsChanged because the renderer is the thing that has to react; this row's
    -- reaction is the LATCH, and NS.StandDown / NS.StandUp repaint as part of standing the addon
    -- down and back up. An announce beside them would be a second repaint path for one switch, and
    -- the two would have to agree about ordering -- the bus is torn down inside StandDown, so on the
    -- way down it would fire into nothing, and on the way up it would paint a second time. Worse,
    -- it would paint on the BOOT stand-up, which deliberately leaves the first paint to
    -- PLAYER_ENTERING_WORLD (core/LifecycleSetup.lua's NS.StandUp says why).
    --
    -- A write with no edge -- the value already stored -- correctly does nothing at all: nothing
    -- changed, so there is nothing to repaint.
    onChange = function() NS.RefreshEnabled() end,
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
  -- THE INVERSION (launcher-§3), on the row itself. The row's path says SHOWN; LibDBIcon's key,
  -- S.MINIMAP_STORE, says HIDDEN; these two negate, and every surface -- the checkbox,
  -- `/pm set global.minimap.shown false`, LibDBIcon's own right-click menu -- ends up agreeing
  -- because there is one negation and one store. The row's own path is never written: no `shown`
  -- key ever lands beside `hide` (anti-pattern #81).
  --
  -- `db.global`, not `db.profile`: the ONE stored row outside the profile, which is why it carries
  -- its own storage rather than going through the runtime's profile resolver. The store is read and
  -- written whole from the DB ROOT, so `global.minimap.hide` resolves as itself.
  --
  -- Answers SHOWN for a DB that is not up yet: `hide` absent means a button that was never hidden,
  -- the same answer the library's own IsShown gives and the one defaults/Global.lua produces the
  -- moment AceDB is there.
  wire(rows, S.MINIMAP_PATH, {
    get = function() return not SchemaLib.Read(NS.db, S.MINIMAP_STORE) end,
    set = function(v)
      SchemaLib.Write(NS.db, S.MINIMAP_STORE, not v)
      -- Then the button follows immediately rather than at the next reload. SetShown writes `hide`
      -- a second time with the same value, which is the library's own documented behavior. It
      -- answers false where LibDBIcon is absent; the store is still correct.
      if NS.Launcher then NS.Launcher:SetShown(v) end
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
  -- Through the runtime, which re-indexes, and after the `wire` calls above, so the index holds
  -- each row as wired (`state.locked`'s path is the wired one, not the composer's).
  R.AddRows(rows, 1)

  -- The group name IS the afterGroup key (options-ui-§15), so settings/Panel.lua reads the tail
  -- from here rather than re-deriving a name that could disagree with the rows'.
  S.MasterGroup = rows[1].group
  S.MasterAfterGroup = tail
  S.__masterInstalled = true
  return true
end

-- ── The seam, under the names every caller already uses ───────────────────────
--
-- Each is a one-line delegate to the runtime above. They are COLON methods because that is how
-- this addon has always called them (`NS.Schema:Set(path, v)`), and the instance's members are
-- dot-called closures, so a colon caller handed straight to one would pass the schema table as the
-- path. The descriptors do not go through these: they take the members themselves.

function S:FindRow(path) return R.FindRow(path) end

--- The path walk, for this file's own profile snapshot and for the suite. The library's pure
--- primitive (or the stub's), never a third walker.
function S:ReadPath(root, path) return SchemaLib.Read(root, path) end

-- The bulk bracket (debug-logging-§10). A bulk copy or reset through this seam is ONE
-- `[Set] <act> <scope>: N rows` line, never one per row: while a bracket is open the per-row line is
-- muted, and validation and each row's onChange still run per row. N is the rows the act actually
-- CHANGED, read back after each write, never the library walk's own `count` (which includes rows
-- already at their default). Brackets nest by depth and the outermost close speaks; a level that
-- reports `info.profileReset` silences it, because the OnProfileReset handler in core/Database.lua
-- logs that one line. All of that is the runtime's; the two descriptors hand it the pair.
S.BulkBegin, S.BulkEnd = R.BulkBegin, R.BulkEnd

--- A bulk act the host performs itself, outside the schema rows: the Registry's record verbs count
--- the fields they changed and hand the figure here. A bracket of its own, so inside an open one it
--- only adds to the tally and the outermost act's line carries it.
function S.BulkLine(act, scope, n)
  R.BulkRun(act, scope, function() R.BulkAdd(n) end)
end

-- A profile reset's row count. AceDB fires OnProfileReset AFTER it has replaced the profile, so the
-- rows it changed can only be counted against a picture taken before: Sl:DoResetAll takes one, and
-- the handler compares. The Profiles page's own Reset Profile takes none, and its line carries no
-- count (debug-logging-§10: the count MAY be omitted where it is not cheap). Session-only rows live
-- in NS.State, which AceDB never sees, so a profile reset changes none of them.
--
-- Kept rather than moved onto the runtime's ResetCounted / ConsumeResetCount (the design spec
-- allows either): the handler's line is pinned byte for byte in tests/test_debuglog.lua, and this
-- pair already answers it.
function S:SnapshotPersisted()
  local snap = {}
  for _, row in ipairs(S.Schema) do
    -- The minimap row is stored in db.GLOBAL, which AceDB's profile reset does not touch, so it is
    -- out of the picture by definition rather than by luck. Snapshotting it against db.profile
    -- would read nil on both sides and compare equal, which is the right answer reached by
    -- accident; skipping it says so. (That the row SURVIVES the reset is a property of the setting
    -- rather than of this store -- launcher-§3 as amended at v2.54.0, and defaults/Global.lua
    -- carries the finding for this addon's two resets.)
    if not row.sessionOnly and row.path ~= S.MINIMAP_PATH then
      snap[row.path] = NS.Util.DeepCopy(S:ReadPath(NS.db.profile, row.path))
    end
  end
  return snap
end

function S:CountChangedSince(snap)
  local n = 0
  for path, old in pairs(snap) do
    if not NS.Util.DeepEqual(old, S:ReadPath(NS.db.profile, path)) then n = n + 1 end
  end
  return n
end

--- The single write seam. Panel widgets, the slash `set` and every host writer route through it, so
--- validation, the debug trace and the onChange reaction can never be skipped by one caller.
--- Answers `true`, or `false, err[, why]` with nothing stored: an unknown path is refused, never
--- stored (architecture-§5 scopes the seam to schema-row paths).
function S:Set(path, value) return R.Set(path, value) end

function S:Get(path) return R.Get(path) end

function S:Default(path) return R.Default(path) end

-- Boot validation (architecture-§5): every schema path must resolve against the defaults table, so a
-- typo in a path is caught loudly at load instead of silently reading nil forever. Returns the
-- number of problems -- shape errors plus unresolved paths -- which is what the headless test
-- asserts on.
--
-- THE ROW'S OWN `default` IS NOT AN ESCAPE HATCH, and used to be. The old loop carried a third
-- conjunct, `and row.default == nil`, so a path only counted as unresolved when the row ALSO
-- declared no default -- and every row declares one, which made the check structurally unable to
-- fire. `row.default` is what the widget shows and what Defaults restores; resolving against the
-- defaults tree is what says the setting has somewhere to be WRITTEN, and the runtime's Validate
-- never consults the row's own default (savedvariables-§2: the declaration site is defaults/).
--
-- Session-only rows (state.*) are the ONE exemption: they route through their own get/set and are
-- never persisted. The minimap row is the one CLOSURE-BACKED row (architecture-§5, launcher-§3):
-- its path names the row and is never stored or declared, so the runtime is told it has no root
-- (`defaultsRoot` answers nil for it) and its STORE is checked instead, against NS.defaults whole
-- because it is spelled from the DB root and begins `global.`. Checked, not exempted: a store that
-- does not resolve counts one missing, with the same printed schema error the runtime gives.
function S:Register()
  if not (NS.defaults and NS.defaults.profile) then return 0 end
  local errors, _, missing = R.Validate({
    defaultsRoot = function(parts, row)
      if row and row.path == S.MINIMAP_PATH then return nil end
      if parts[1] == "global" then return NS.defaults, 1 end
      return NS.defaults.profile, 1
    end,
  })
  if SchemaLib.Read(NS.defaults, S.MINIMAP_STORE) == nil then
    missing = missing + 1
    print(("|cffff0000schema error|r: %s: store `%s` does not resolve against the defaults")
      :format(S.MINIMAP_PATH, S.MINIMAP_STORE))
  end
  return errors + missing
end
