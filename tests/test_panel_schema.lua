local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse, assertNil =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local R = NS.Registry
local C = NS.Constants

-- PanelMaster#54: every per-panel field write goes through the ONE schema seam, with the panel id
-- as the instance id (architecture-§5). This suite holds two halves.
--
-- The CHARACTERIZATION half pins what each whole-record and bulk verb does today -- what it
-- stores, what it broadcasts and how often -- so moving those verbs onto SchemaRuntime.Set/SetMany
-- is provably a change of route and not of behavior. It is green before the move and after it.
--
-- The INSTANCE-ROW half pins the seam itself: the resolver, the generated rows, the write path, the
-- [Set] line's shape, and that the rows never reach a profile surface.

local function fresh()
  R:DeleteAll()
end

-- Every panel message sent while `fn` runs, as "PANEL:<id>" / "PANELS" strings, in order. The bus
-- is wrapped rather than a receiver registered, so nothing else listening is disturbed and a
-- message nobody receives is still counted.
local function messages(fn)
  local bus, log = NS.bus, {}
  local orig = bus.SendMessage
  bus.SendMessage = function(self, msg, ...)
    if msg == R.MSG.PANEL then
      log[#log + 1] = "PANEL:" .. tostring((...))
    elseif msg == R.MSG.PANELS then
      log[#log + 1] = "PANELS"
    end
    return orig(self, msg, ...)
  end
  local ok, err = pcall(fn)
  bus.SendMessage = orig
  if not ok then error(err, 0) end
  return log
end

-- ── Characterization: the verbs' stored effect and broadcast ───────────────────

test("Panel verbs: R:Set stores the value and repaints that one panel once", function()
  fresh()
  local rec = R:New("CharSet")
  local log = messages(function() assertTrue(R:Set(rec.id, "width", 300)) end)
  assertEqual(R:Get(rec.id).width, 300)
  assertEqual(table.concat(log, ","), "PANEL:" .. rec.id)
end)

test("Panel verbs: R:Set of `name` is a rename -- the SET changed, so PANELS and no PANEL", function()
  fresh()
  local rec = R:New("CharOld")
  local log = messages(function() assertTrue(R:Set(rec.id, "name", "CharNew")) end)
  assertEqual(R:Get(rec.id).name, "CharNew")
  assertEqual(table.concat(log, ","), "PANELS")
end)

test("Panel verbs: R:Reset lands on the new-panel state, keeps identity, one PANEL", function()
  fresh()
  local rec = R:New("CharReset", { width = 500, x = 40, bgTexture = "Solid", borderSize = 6 })
  local id, frameName = rec.id, rec.frameName
  local log = messages(function() assertTrue(R:Reset(rec.id)) end)
  local live = R:Get(id)
  assertEqual(live.name, "CharReset")
  assertEqual(live.frameName, frameName)
  assertEqual(live.width, NS.db.profile.settings.defaultWidth)
  assertEqual(live.x, 0)
  assertEqual(live.borderSize, C.PANEL_TEMPLATE.borderSize)
  assertEqual(table.concat(log, ","), "PANEL:" .. id)
end)

test("Panel verbs: R:CopyFrom copies appearance, not identity or position, one PANEL", function()
  fresh()
  local src = R:New("CharSrc", { width = 500, borderSize = 6, x = 100, point = "TOPLEFT" })
  local dst = R:New("CharDst", { x = -20 })
  local log = messages(function() assertTrue(R:CopyFrom(dst.id, src.id)) end)
  local live = R:Get(dst.id)
  assertEqual(live.width, 500)
  assertEqual(live.borderSize, 6)
  assertEqual(live.x, -20, "the copy moved the target")
  assertEqual(live.point, "CENTER", "the copy re-anchored the target")
  assertEqual(live.name, "CharDst")
  assertEqual(table.concat(log, ","), "PANEL:" .. dst.id)
end)

test("Panel verbs: R:FitToArtwork adopts the art's size with one PANEL; a refusal sends none", function()
  fresh()
  local rec = R:New("CharFit", { width = 300, height = 40, artTexture = "class-warrior" })
  local log = messages(function() assertTrue((R:FitToArtwork(rec.id))) end)
  assertEqual(R:Get(rec.id).width, 1024)
  assertEqual(R:Get(rec.id).height, 1024)
  assertEqual(table.concat(log, ","), "PANEL:" .. rec.id)
  log = messages(function() assertFalse((R:FitToArtwork(rec.id))) end)
  assertEqual(#log, 0, "an already-fitted panel still broadcast")
end)

test("Panel verbs: R:Recover moves every lost panel and sends ONE PANELS, no per-panel PANEL",
  function()
  fresh()
  local a = R:New("CharLost1", { x = 9000, y = -9000 })
  local b = R:New("CharLost2", { x = -9000, y = 0 })
  R:New("CharFine", { x = 100, y = 100 })
  local log = messages(function() assertEqual(R:Recover(), 2) end)
  assertEqual(R:Get(a.id).x, 960)
  assertEqual(R:Get(a.id).y, -540)
  assertEqual(R:Get(b.id).x, -960)
  assertEqual(table.concat(log, ","), "PANELS")
  log = messages(function() assertEqual(R:Recover(), 0) end)
  assertEqual(#log, 0, "a recover that moved nothing still broadcast")
end)

test("Panel verbs: R:ResetPositions re-homes every panel and sends ONE PANELS", function()
  fresh()
  local a = R:New("CharOff1", { x = 100, y = 50 })
  local b = R:New("CharOff2", { point = "TOPLEFT", relPoint = "TOPLEFT", x = 10, y = -10 })
  local log = messages(function() assertEqual(R:ResetPositions(), 2) end)
  for _, id in ipairs({ a.id, b.id }) do
    local live = R:Get(id)
    assertEqual(live.point, "CENTER")
    assertEqual(live.relPoint, "CENTER")
    assertEqual(live.x, 0)
    assertEqual(live.y, 0)
  end
  assertEqual(table.concat(log, ","), "PANELS")
end)

-- A frame armed by Unlock exactly as the renderer arms one, anchored where a drag would leave it.
local function draggedFrame(rec, point, relPoint, x, y)
  local f = T.mocks.CreateFrame("Frame")
  f.panelID = rec.id
  f:SetPoint(point, T.mocks.CreateFrame("Frame"), relPoint, x, y)
  NS.Unlock:ArmDrag(f)
  return f
end

test("Panel verbs: a drag-stop stores point, relPoint and both offsets, with ONE PANEL", function()
  fresh()
  local rec = R:New("CharDrag")
  local f = draggedFrame(rec, "TOPLEFT", "BOTTOMRIGHT", 40, -80)
  local log = messages(function() f:GetScript("OnDragStop")(f) end)
  local live = R:Get(rec.id)
  assertEqual(live.point, "TOPLEFT")
  assertEqual(live.relPoint, "BOTTOMRIGHT")
  assertEqual(live.x, 40)
  assertEqual(live.y, -80)
  assertEqual(table.concat(log, ","), "PANEL:" .. rec.id)
end)

test("Panel verbs: R:SetPosition writes both offsets with ONE PANEL", function()
  fresh()
  local rec = R:New("CharMove")
  local log = messages(function() assertTrue(R:SetPosition(rec.id, 12, -34)) end)
  assertEqual(R:Get(rec.id).x, 12)
  assertEqual(R:Get(rec.id).y, -34)
  assertEqual(table.concat(log, ","), "PANEL:" .. rec.id)
end)

-- ── The instance rows (panel.<field>) ──────────────────────────────────────────

local S = NS.Schema
local D = NS.DebugLog

local function quiet()
  NS.State.debug = false
  D:Clear()
end

-- The message of every buffered debug line carrying `tag`, in order.
local function tagged(tag)
  local out, pat = {}, "%[" .. tag .. "%] (.*)$"
  for _, line in ipairs(D.buffer) do
    local msg = line:match(pat)
    if msg then out[#out + 1] = msg end
  end
  return out
end

-- Every runtime Set / SetMany call made while `fn` runs, as "Set panel.width @3" and
-- "SetMany panel.x,panel.y @3" strings. Registry reaches the runtime at call time, so wrapping the
-- two members sees every write the verbs make.
local function seamCalls(fn)
  local rt, log = NS.SchemaRuntime, {}
  local set, many = rt.Set, rt.SetMany
  rt.Set = function(path, value, id)
    log[#log + 1] = ("Set %s @%s"):format(tostring(path), tostring(id))
    return set(path, value, id)
  end
  rt.SetMany = function(entries, opts)
    local paths = {}
    for i, e in ipairs(entries) do paths[i] = e.path end
    log[#log + 1] = ("SetMany %s @%s"):format(table.concat(paths, ","),
      tostring(type(opts) == "table" and opts.instanceId))
    return many(entries, opts)
  end
  local ok, err = pcall(fn)
  rt.Set, rt.SetMany = set, many
  if not ok then error(err, 0) end
  return log
end

-- Whether any entry of `log` starts with `prefix` and ends naming `id`.
local function called(log, prefix, id)
  for _, entry in ipairs(log) do
    if entry:sub(1, #prefix) == prefix and entry:sub(-#("@" .. id)) == "@" .. id then return true end
  end
  return false
end

test("Panel rows: S.ResolveRoot answers the record and first = 2 for a known panel id", function()
  fresh()
  local rec = R:New("ResolveMe")
  local root, first, rid = S.ResolveRoot({ "panel", "width" }, rec.id)
  assertTrue(root == R:Get(rec.id), "the resolver did not answer the panel's own record")
  assertEqual(first, 2)
  assertEqual(rid, rec.id)
end)

test("Panel rows: S.ResolveRoot refuses an unknown or missing id, and still answers the profile",
  function()
  fresh()
  local root, why = S.ResolveRoot({ "panel", "width" }, 9999)
  assertNil(root)
  assertEqual(why, "no such panel")
  root, why = S.ResolveRoot({ "panel", "width" }, nil)
  assertNil(root)
  assertEqual(why, "panel rows need a panel")
  local profile, first = S.ResolveRoot({ "settings", "gridSize" })
  assertTrue(profile == NS.db.profile, "a settings path no longer resolves against the profile")
  assertEqual(first, 1)
end)

test("Panel rows: one hidden panel.<field> row per panel field but name, defaulting to the template",
  function()
  local n = 0
  for _, field in ipairs(C.PANEL_FIELD_ORDER) do
    local row = S:FindRow("panel." .. field)
    if field == "name" then
      assertNil(row, "`name` is identity and must not be a schema row")
    else
      assertTrue(row ~= nil, "no row for panel field " .. field)
      assertTrue(NS.Util.DeepEqual(row.default, C.PANEL_TEMPLATE[field]),
        field .. "'s row default is not the template's")
      assertEqual(row.scope, "panel", field)
      assertEqual(row.hidden, true, field)
      assertEqual(row.skipRender, true, field)
      n = n + 1
    end
  end
  local rows = 0
  for _, row in ipairs(NS.SchemaRuntime.AllRows()) do
    if row.scope == "panel" then rows = rows + 1 end
  end
  assertEqual(rows, n, "a panel row exists for a field C.PANEL_FIELD_ORDER does not list")
  for field in pairs(C.PANEL_FIELD_TYPE) do
    if field ~= "name" then
      assertTrue(S:FindRow("panel." .. field) ~= nil, "typed field " .. field .. " has no row")
    end
  end
end)

test("Panel rows: a seam write stores, clamps, refuses in the coercer's words, repaints once",
  function()
  fresh()
  local rec = R:New("SeamWrite")
  local log = messages(function() assertTrue(S:Set("panel.width", 300, rec.id)) end)
  assertEqual(R:Get(rec.id).width, 300)
  assertEqual(table.concat(log, ","), "PANEL:" .. rec.id)
  assertTrue(S:Set("panel.width", 99999, rec.id))
  assertEqual(R:Get(rec.id).width, C.MAX_SIZE)
  local ok, _, why = S:Set("panel.width", "abc", rec.id)
  assertFalse(ok)
  assertEqual(why, "expected a number")
  assertEqual(R:Get(rec.id).width, C.MAX_SIZE, "a refused write still stored")
  assertEqual(S:Get("panel.width", rec.id), C.MAX_SIZE)
end)

-- PanelMaster-R-03 (PM-06): tonumber reads "nan", "inf" and "1e999" as numbers, so the number rows
-- used to store NaN or infinity and hand it to SetSize / SetPoint and the SavedVariables file.
-- red under: COERCE.number as a bare tonumber (the write succeeds and stores the non-finite value).
test("Panel rows: a non-finite number is refused as 'expected a number' and nothing is stored",
  function()
  fresh()
  local rec = R:New("Finite", { x = 40, y = -20 })
  local width = R:Get(rec.id).width
  for _, field in ipairs({ "width", "x" }) do
    local before = R:Get(rec.id)[field]
    for _, typed in ipairs({ "nan", "inf", "-inf", "1e999", "-1e999" }) do
      local ok, _, why = S:Set("panel." .. field, typed, rec.id)
      assertFalse(ok, field .. " = " .. typed .. " was accepted")
      assertEqual(why, "expected a number", field .. " = " .. typed)
      assertEqual(R:Get(rec.id)[field], before, field .. " = " .. typed .. " still stored")
    end
  end
  assertEqual(R:Get(rec.id).width, width)
  assertEqual(R:Get(rec.id).x, 40)
end)

test("Panel rows: a panel write logs ONE [Set] line in the library's shape, naming the panel",
  function()
  fresh()
  local rec = R:New("Alpha")
  quiet()
  NS.State.debug = true
  assertTrue(R:Set(rec.id, "width", 300))
  assertEqual(table.concat(tagged("Set"), " | "), "panel.width = 300 on 'Alpha'")
  assertEqual(#tagged("Panel"), 0, "the Registry still writes its own per-write line")
  D:Clear()
  assertTrue(R:Set(rec.id, "alpha", 0.5))
  assertEqual(tagged("Set")[1], "panel.alpha = 0.50 on 'Alpha'", "the value is not R.FormatField's")
  quiet()
end)

test("Panel rows: R:Set and every record verb write through the seam with the panel id", function()
  fresh()
  local rec = R:New("Routed", { artTexture = "class-warrior" })
  local src = R:New("RoutedSrc", { width = 480 })
  local lost = R:New("RoutedLost", { x = 9000, y = 9000 })
  local log = seamCalls(function()
    R:Set(rec.id, "width", 310)
    R:SetPosition(rec.id, 8, 12)
    R:FitToArtwork(rec.id)
    R:CopyFrom(rec.id, src.id)
    R:Reset(rec.id)
  end)
  assertTrue(called(log, "Set panel.width", rec.id), "R:Set bypassed the seam:\n" .. table.concat(log, "\n"))
  assertTrue(called(log, "SetMany panel.x,panel.y", rec.id), "R:SetPosition bypassed the seam")
  assertTrue(called(log, "SetMany panel.width,panel.height", rec.id), "R:FitToArtwork bypassed the seam")
  local many = 0
  for _, entry in ipairs(log) do
    if entry:sub(1, 8) == "SetMany " and entry:sub(-#("@" .. rec.id)) == "@" .. rec.id then many = many + 1 end
  end
  assertEqual(many, 4, "CopyFrom and Reset did not each take one SetMany:\n" .. table.concat(log, "\n"))
  log = seamCalls(function() R:Recover() end)
  assertTrue(called(log, "SetMany panel.x,panel.y", lost.id), "R:Recover bypassed the seam")
  R:SetPosition(rec.id, 30, 30)
  log = seamCalls(function() R:ResetPositions() end)
  assertTrue(called(log, "SetMany", rec.id), "R:ResetPositions bypassed the seam")
end)

test("Panel rows: a drag-stop writes point, relPoint, x and y as ONE act", function()
  fresh()
  local rec = R:New("DragAct")
  local f = draggedFrame(rec, "TOPLEFT", "BOTTOMRIGHT", 40, -80)
  local log = seamCalls(function() f:GetScript("OnDragStop")(f) end)
  assertEqual(table.concat(log, " | "), "SetMany panel.point,panel.relPoint,panel.x,panel.y @" .. rec.id)
end)

test("Panel rows: the profile surfaces never see a panel row", function()
  for _, row in ipairs(S.ProfileRows()) do
    assertTrue(row.scope ~= "panel", tostring(row.path) .. " reached the profile rows")
  end
  assertNil(S.FindProfileRow("panel.width"), "FindProfileRow answered a panel row")
  assertTrue(S.FindProfileRow("settings.gridSize") ~= nil)
  for _, line in ipairs(NS.Slash:BuildListLines()) do
    assertEqual(line:find("panel%."), nil, "/pm list shows a panel row: " .. line)
  end
  for path in pairs(S:SnapshotPersisted()) do
    assertEqual(path:find("^panel%."), nil, "the reset snapshot holds " .. path)
  end
  fresh()
  local rec = R:New("NotAProfileRow")
  NS.Slash:OnSlash("set panel.width 500")
  assertEqual(R:Get(rec.id).width, C.PANEL_TEMPLATE.width, "/pm set wrote a panel row")
end)

test("Panel rows: the boot shape check resolves every panel row against the template", function()
  assertEqual(S:Register(), 0)
  local rows = NS.SchemaRuntime.AllRows()
  rows[#rows + 1] = { path = "panel.noSuchField", scope = "panel", default = 1, type = "number",
    group = "Panel", label = "probe", tooltip = "probe", hidden = true, skipRender = true }
  local n = S:Register()
  rows[#rows] = nil
  assertEqual(n, 1, "a panel row naming no template field was not reported")
end)

test("Panel rows: R:Reset drops a key the template does not declare, as the wipe did", function()
  fresh()
  local rec = R:New("Legacy", { width = 500 })
  rec.legacyKey = 5
  quiet()
  NS.State.debug = true
  assertTrue((R:Reset(rec.id)))
  assertNil(R:Get(rec.id).legacyKey, "the reset kept a key the template does not declare")
  assertEqual(tagged("Set")[1], "reset 'Legacy': 2 rows")
  quiet()
end)

local Env = dofile("tests/degraded_env.lua")

test("Panel rows: a library-less Schema load drives the same panel writes", function()
  local ns = Env.loadPartial({ Schema = true })
  local rec = ns.Registry:New("Stubbed")
  assertTrue(ns.Registry:Set(rec.id, "width", 300))
  assertEqual(rec.width, 300)
  assertTrue(ns.Schema:Set("panel.height", 200, rec.id))
  assertEqual(rec.height, 200)
  assertTrue(ns.Registry:SetPosition(rec.id, 5, 6))
  assertEqual(rec.x, 5)
  assertEqual(rec.y, 6)
  assertFalse((ns.Registry:Set(rec.id, "width", "wide")))
  assertEqual(rec.width, 300)
end)
