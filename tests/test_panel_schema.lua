local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse
local R = NS.Registry
local C = NS.Constants

-- PanelMaster#54: every per-panel field write goes through the ONE schema seam, with the panel id
-- as the instance id (architecture-§5). This suite holds two halves.
--
-- The CHARACTERIZATION half pins what each whole-record and bulk verb does today -- what it
-- stores, what it broadcasts and how often -- so moving those verbs onto SchemaRuntime.Set/SetMany
-- is provably a change of route and not of behavior. It is green before the move and after it.

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
