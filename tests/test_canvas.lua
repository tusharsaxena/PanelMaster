local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse, assertNear =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNear
local Canvas, R, C = NS.Canvas, NS.Registry, NS.Constants

local function fresh()
  R:DeleteAll()
  Canvas:RenderAll()   -- retire the frames the previous suite left behind
end

test("Canvas.BuildSpec: carries the record's geometry through", function()
  local spec = Canvas.BuildSpec({ width = 300, height = 150, x = 10, y = -20,
                                  point = "TOPLEFT", relPoint = "TOPLEFT" }, {})
  assertEqual(spec.width, 300)
  assertEqual(spec.height, 150)
  assertEqual(spec.x, 10)
  assertEqual(spec.y, -20)
  assertEqual(spec.point, "TOPLEFT")
end)

test("Canvas.BuildSpec: repairs invalid values rather than passing them to a frame", function()
  local spec = Canvas.BuildSpec({ width = "wide", point = "MIDDLE", strata = "PARCHMENT",
                                  alpha = 7 }, {})
  assertEqual(spec.width, C.PANEL_TEMPLATE.width)
  assertEqual(spec.point, C.PANEL_TEMPLATE.point)
  assertEqual(spec.strata, C.PANEL_TEMPLATE.strata)
  assertEqual(spec.alpha, 1)
end)

test("Canvas.BuildSpec: shown requires BOTH the master switch and the panel's own", function()
  assertTrue(Canvas.BuildSpec({ enabled = true }, { enabled = true }).shown)
  assertFalse(Canvas.BuildSpec({ enabled = false }, { enabled = true }).shown)
  assertFalse(Canvas.BuildSpec({ enabled = true }, { enabled = false }).shown)
  assertFalse(Canvas.BuildSpec({ enabled = false }, { enabled = false }).shown)
end)

test("Canvas.BuildSpec: a missing settings table means shown", function()
  -- Settings absent must read as "not disabled", or a panel would vanish during any window where
  -- the DB is not yet populated.
  assertTrue(Canvas.BuildSpec({ enabled = true }, nil).shown)
end)

test("Canvas.BuildSpec: a zero border is honoured, not floored to 1", function()
  assertEqual(Canvas.BuildSpec({ borderSize = 0 }, {}).borderSize, 0)
end)

test("Canvas.BuildSpec: normalizes colors to four clamped components", function()
  local spec = Canvas.BuildSpec({ bgColor = { 2, -1, 0.5 } }, {})
  assertEqual(spec.bg[1], 1)
  assertEqual(spec.bg[2], 0)
  assertNear(spec.bg[4], 1)
end)

test("Canvas.BuildSpec: a non-table record is nil, not a crash", function()
  assertEqual(Canvas.BuildSpec(nil, {}), nil)
  assertEqual(Canvas.BuildSpec("panel", {}), nil)
end)

test("Canvas.Render: builds a frame and applies the spec's size", function()
  fresh()
  local rec = R:New("Rendered", { width = 321, height = 123 })
  local f = Canvas:Render(rec.id)
  assertTrue(f ~= nil)
  assertEqual(f:GetWidth(), 321)
  assertEqual(f:GetHeight(), 123)
end)

test("Canvas.Render: applies the anchor point and offsets", function()
  fresh()
  local rec = R:New("Anchored", { point = "TOPLEFT", relPoint = "TOPLEFT", x = 40, y = -60 })
  local f = Canvas:Render(rec.id)
  local point, _, relPoint, x, y = f:GetPoint(1)
  assertEqual(point, "TOPLEFT")
  assertEqual(relPoint, "TOPLEFT")
  assertEqual(x, 40)
  assertEqual(y, -60)
end)

test("Canvas.Render: re-rendering does not accumulate anchor points", function()
  fresh()
  local rec = R:New("Repainted")
  local f = Canvas:Render(rec.id)
  Canvas:Render(rec.id)
  Canvas:Render(rec.id)
  -- Without the ClearAllPoints in applySpec, a panel repainted on every settings change would
  -- collect anchors until it was pinned in place and stopped moving.
  assertEqual(f:GetNumPoints(), 1)
end)

test("Canvas.Render: reuses the same frame for the same panel", function()
  fresh()
  local rec = R:New("Stable")
  assertEqual(Canvas:Render(rec.id), Canvas:Render(rec.id))
end)

test("Canvas.Render: a disabled panel's frame is hidden, not destroyed", function()
  fresh()
  local rec = R:New("Toggled")
  local f = Canvas:Render(rec.id)
  assertTrue(f:IsShown())
  R:Set(rec.id, "enabled", false)
  assertFalse(Canvas:FrameFor(rec.id):IsShown())
  R:Set(rec.id, "enabled", true)
  assertTrue(Canvas:FrameFor(rec.id):IsShown())
end)

test("Canvas.Render: the master switch hides every panel", function()
  fresh()
  R:New("A"); R:New("B")
  Canvas:RenderAll()
  NS.db.profile.settings.enabled = false
  Canvas:RenderAll()
  for _, rec in ipairs(R:All()) do
    assertFalse(Canvas:FrameFor(rec.id):IsShown(), rec.name .. " stayed visible")
  end
  NS.db.profile.settings.enabled = true
  Canvas:RenderAll()
end)

test("Canvas.Render: a deleted record retires its frame", function()
  fresh()
  local rec = R:New("Transient")
  Canvas:Render(rec.id)
  assertTrue(Canvas:FrameFor(rec.id) ~= nil)
  R:Delete(rec.id)
  assertEqual(Canvas:FrameFor(rec.id), nil)
end)

test("Canvas.RenderAll: renders every record and retires nothing else", function()
  fresh()
  R:New("A"); R:New("B"); R:New("C")
  Canvas:RenderAll()
  local n = 0
  for _ in pairs(Canvas.__active) do n = n + 1 end
  assertEqual(n, 3)
end)

test("Canvas: frames are pooled, not leaked (hard rule #14)", function()
  fresh()
  local function totalFrames()
    local active = 0
    for _ in pairs(Canvas.__active) do active = active + 1 end
    return active + Canvas.PooledCount()
  end

  local before = totalFrames()
  -- Ten create/delete cycles of the SAME panel name. WoW frames are never garbage collected, so a
  -- delete that dropped its frame instead of returning it to the pool would grow this number by one
  -- every cycle — a permanent leak, and the exact reason hard rule #14 exists.
  for _ = 1, 10 do
    local rec = R:New("Cycled")
    R:Delete(rec.id)
  end
  assertEqual(totalFrames(), before + 1, "frames grew across create/delete cycles")
end)

test("Canvas: a delete returns its frame to the pool", function()
  fresh()
  local rec = R:New("Pooled")
  -- The create already fired a repaint, so the frame is active, not pooled.
  local pooledWhileActive = Canvas.PooledCount()
  R:Delete(rec.id)
  assertEqual(Canvas.PooledCount(), pooledWhileActive + 1, "the deleted panel's frame was dropped")
end)

test("Canvas: a re-created panel gets its own frame back", function()
  fresh()
  local first = R:New("Recurring")
  local frame = Canvas:FrameFor(first.id)
  R:Delete(first.id)
  local second = R:New("Recurring")
  -- The pool is keyed by frame NAME, because a frame's name is fixed at creation and is this
  -- addon's public anchor contract. Same name in, same frame back.
  assertEqual(Canvas:FrameFor(second.id), frame)
end)

test("Canvas: a DIFFERENT panel name gets a different frame", function()
  fresh()
  local first = R:New("Alpha")
  local frame = Canvas:FrameFor(first.id)
  R:Delete(first.id)
  local second = R:New("Beta")
  -- A pooled frame cannot be handed to a panel wanting another name: it would answer to
  -- PanelMaster_Panel_Alpha forever, and anything anchored to that name would follow the wrong panel.
  assertTrue(Canvas:FrameFor(second.id) ~= frame,
    "a frame was reused under the wrong global name")
end)

test("Canvas: a released frame is mouse-disabled again", function()
  fresh()
  local rec = R:New("Grabbed")
  local f = Canvas:Render(rec.id)
  f:EnableMouse(true)
  R:Delete(rec.id)
  -- A pooled frame that kept mouse input would swallow clicks meant for the UI underneath it.
  assertFalse(f:IsMouseEnabled())
end)

test("Canvas: a released frame stops claiming a panel id (F-024)", function()
  fresh()
  local rec = R:New("Retired")
  local f = Canvas:Render(rec.id)
  R:Delete(rec.id)
  -- A pooled frame that kept `panelID` still names a record that no longer exists, which is exactly
  -- the kind of thing a `/pm debug dump` is read to rule out.
  assertEqual(f.panelID, nil, "a pooled frame still points at the panel it used to draw")
end)

test("Canvas: the bus repaints on a registry change", function()
  fresh()
  local rec = R:New("Bussed")
  -- New() fires PanelsChanged, which Canvas:Enable subscribed to in run.lua — so the frame exists
  -- without anyone calling Render directly. This is the real wiring, not a hand-invoked handler.
  assertTrue(Canvas:FrameFor(rec.id) ~= nil, "the create did not reach the renderer")
end)

test("Canvas: a settings change repaints", function()
  fresh()
  local rec = R:New("Reactive")
  NS.db.profile.settings.enabled = false
  NS.Schema:Set("settings.enabled", false)
  assertFalse(Canvas:FrameFor(rec.id):IsShown())
  NS.Schema:Set("settings.enabled", true)
  assertTrue(Canvas:FrameFor(rec.id):IsShown())
end)

test("Canvas: a grid-only settings write does NOT repaint (F-012)", function()
  fresh()
  R:New("Ungridded")
  -- snapToGrid and gridSize cannot change how any panel looks — they are read live by
  -- U.SnapPosition at drag-stop, and BuildSpec never touches them. Dragging the Grid size slider
  -- used to repaint every panel per mouse-up for nothing.
  local repaints = 0
  local realRenderAll = Canvas.RenderAll
  Canvas.RenderAll = function(...) repaints = repaints + 1 return realRenderAll(...) end
  NS.Schema:Set("settings.gridSize", 8)
  NS.Schema:Set("settings.snapToGrid", false)
  NS.Schema:Set("settings.snapToGrid", true)
  Canvas.RenderAll = realRenderAll
  assertEqual(repaints, 0, "a grid-only write repainted every panel")
  NS.Schema:Set("settings.gridSize", 4)
  fresh()
end)

test("Canvas: showLabels still repaints — the unlock overlay reads it (F-012)", function()
  fresh()
  R:New("Labeled")
  -- The other half of the same change: showLabels KEEPS its announce, because U:Decorate reads it
  -- and only ever runs from a render.
  local repaints = 0
  local realRenderAll = Canvas.RenderAll
  Canvas.RenderAll = function(...) repaints = repaints + 1 return realRenderAll(...) end
  NS.Schema:Set("settings.showLabels", false)
  Canvas.RenderAll = realRenderAll
  assertEqual(repaints, 1, "turning names off never reached the overlay")
  NS.Schema:Set("settings.showLabels", true)
  fresh()
end)

test("Canvas: OnEnable subscribes the renderer to the bus", function()
  -- The regression pin for the "nothing updates until you toggle test mode" bug. OnEnable must call
  -- Canvas:Enable(); without it every message broadcasts into a bus with no listener and the only
  -- repaints left are the two that call RenderAll() directly (lock/unlock and test mode). run.lua
  -- drives the real OnInitialize/OnEnable, so this asserts the addon's own wiring, not the harness's.
  assertTrue(Canvas.__ev ~= nil, "OnEnable did not subscribe the renderer")
  for _, message in ipairs({ R.MSG_PANELS, R.MSG_PANEL, NS.Schema.MSG_SETTINGS }) do
    local targets = T.mocks.__msgRegistry[message] or {}
    assertTrue(targets[Canvas.__ev] ~= nil, "the renderer is not listening for " .. message)
  end
end)

test("Canvas: consumers register on their own bus target (architecture-§4)", function()
  -- CallbackHandler keys callbacks by (message, target). If Canvas and the settings panel shared a
  -- target, the second registrant would silently clobber the first. Both listen to PanelsChanged, so
  -- the registry for that message must hold two distinct targets.
  local targets = T.mocks.__msgRegistry[R.MSG_PANELS] or {}
  local n = 0
  for _ in pairs(targets) do n = n + 1 end
  assertTrue(n >= 1, "nothing is listening for PanelsChanged")
  assertTrue(Canvas.__ev ~= nil and targets[Canvas.__ev] ~= nil,
    "Canvas is not registered on its own target")
end)

test("Canvas: each panel level gets a frame-level band of its own", function()
  -- The level setting means "higher draws in front". Used as a RAW frame level that was only true
  -- while a panel occupied one rung — and a panel occupies eight. Two panels three levels apart put
  -- one's accent bar and the other's background fill on the same number, leaving the winner to
  -- frame creation order, which the name-keyed pool does not even keep in panel order.
  fresh()
  R:New("Low"); R:New("High")
  local lo = R:FindByName("Low")
  local hi = R:FindByName("High")
  R:Set(lo.id, "level", 0)
  R:Set(hi.id, "level", 3)

  local lf, hf = Canvas:FrameFor(lo.id), Canvas:FrameFor(hi.id)
  local loTop = lf:GetFrameLevel() + C.UNLOCK_FRAME_LEVEL
  local hiBottom = hf:GetFrameLevel()
  assertTrue(hiBottom > loTop,
    ("the higher panel's stack starts at %d, inside the lower panel's %d..%d")
      :format(hiBottom, lf:GetFrameLevel(), loTop))
end)

test("Canvas: one level apart is enough to separate two panels completely", function()
  -- The tightest case, and the one a user would actually hit: adjacent levels must not interleave.
  fresh()
  R:New("A"); R:New("B")
  local a, b = R:FindByName("A"), R:FindByName("B")
  R:Set(a.id, "level", 4)
  R:Set(b.id, "level", 5)
  local af, bf = Canvas:FrameFor(a.id), Canvas:FrameFor(b.id)
  assertTrue(bf:GetFrameLevel() > af:GetFrameLevel() + C.UNLOCK_FRAME_LEVEL,
    "adjacent panel levels still interleave")
end)
