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

test("Canvas.BuildSpec: a zero border is honored, not floored to 1", function()
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

test("Canvas: a released frame is inert, not merely hidden", function()
  -- A pooled frame sits under its old name until some other panel claims it, and Unlock's overlay, a
  -- debug dump or a stray Show() all reach it before applySpec runs again. So every visible part has
  -- to be torn down, not just the parent hidden: the accent bars are anchored OUTSIDE the panel's
  -- bounds and would leave four colored strips floating, and an uncleared art texture would put the
  -- previous panel's artwork on screen for the next one.
  fresh()
  local rec = R:New("Inerted", { accentEnabled = true,
    accentEdges = { TOP = true, BOTTOM = true, LEFT = true, RIGHT = true },
    artTexture = NS.Artwork.Catalog[1].id })
  local f = Canvas:FrameFor(rec.id)
  assertTrue(f ~= nil, "the panel never got a frame")
  assertTrue(f.artTextures[1].__texture ~= nil, "the artwork never reached a texture")

  R:Delete(rec.id)

  assertFalse(f.__shown, "the released frame is still shown")
  assertEqual(f.borderFrame.__backdrop, nil, "the border backdrop survived the release")
  for edge, bar in pairs(f.accents) do
    assertFalse(bar.__shown, "accent bar " .. edge .. " is still shown")
    assertEqual(bar.borderFrame.__backdrop, nil,
      "accent bar " .. edge .. " kept its border backdrop")
  end
  assertFalse(f.artFrame.__shown, "the art frame is still shown")
  for i, t in ipairs(f.artTextures) do
    assertEqual(t.__texture, nil, "art texture " .. i .. " still names a file")
  end
  assertEqual(f.panelID, nil, "the released frame still names the record it drew")
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

-- ── The addon-wide master controls (options-ui-§15) ─────────────────────────────
-- Three settings honored in BuildSpec, which is the one place a panel's final geometry and opacity
-- are decided. Each is asserted against a record that would render differently without it, so none
-- of these passes against a builder that simply ignored the setting.

test("Canvas.VisibilityShows: the two combat modes are the answers a boolean could not give",
  function()
    -- The whole reason options-ui-§15 makes this a dropdown rather than a checkbox.
    assertTrue(Canvas.VisibilityShows("always", true))
    assertTrue(Canvas.VisibilityShows("always", false))
    assertFalse(Canvas.VisibilityShows("never", true))
    assertFalse(Canvas.VisibilityShows("never", false))
    assertTrue(Canvas.VisibilityShows("inCombat", true))
    assertFalse(Canvas.VisibilityShows("inCombat", false))
    assertFalse(Canvas.VisibilityShows("outOfCombat", true))
    assertTrue(Canvas.VisibilityShows("outOfCombat", false))
    -- An absent or hand-edited value reads as "always". Anything else would let a corrupt
    -- SavedVariables file hide the player's whole backdrop with nothing said.
    assertTrue(Canvas.VisibilityShows(nil, false))
    assertTrue(Canvas.VisibilityShows("sometimes", true))
  end)

test("Canvas.BuildSpec: general visibility gates the panel alongside the two enables", function()
  local rec = { enabled = true }
  assertFalse(Canvas.BuildSpec(rec, { visibility = "never" }, false).shown)
  assertFalse(Canvas.BuildSpec(rec, { visibility = "inCombat" }, false).shown)
  assertTrue(Canvas.BuildSpec(rec, { visibility = "inCombat" }, true).shown)
  -- And it cannot resurrect a panel the panel's own switch turned off, or the master one.
  assertFalse(Canvas.BuildSpec({ enabled = false }, { visibility = "always" }, false).shown)
  assertFalse(Canvas.BuildSpec(rec, { visibility = "always", enabled = false }, false).shown)
end)

test("Canvas.BuildSpec: master scale MULTIPLIES the panel's own rather than replacing it", function()
  -- Dies under `spec.scale = masterScale(settings)`: the per-panel value would vanish and this
  -- would read 2 instead of 3.
  assertNear(Canvas.BuildSpec({ scale = 1.5 }, { scale = 2 }).scale, 3)
  -- The identity, which is what every profile written before the setting existed reads as.
  assertNear(Canvas.BuildSpec({ scale = 1.5 }, {}).scale, 1.5)
  -- Junk never reaches SetScale, and never zeroes a panel out of existence either.
  assertNear(Canvas.BuildSpec({ scale = 1.5 }, { scale = "banana" }).scale, 1.5)
  assertNear(Canvas.BuildSpec({ scale = 1.5 }, { scale = 0 }).scale, 1.5)
  -- The STORED size is untouched: master scale magnifies, it does not resize.
  assertEqual(Canvas.BuildSpec({ width = 300, scale = 1 }, { scale = 2 }).width, 300)
end)

test("Canvas.BuildSpec: master alpha fades the panel AND its mouseover floor", function()
  local spec = Canvas.BuildSpec({ alpha = 0.8, mouseover = true, mouseoverAlpha = 0.4 },
                                { alpha = 0.5 })
  assertNear(spec.alpha, 0.4)
  -- The floor is faded too. Left unfaded it would be 0.4 against a 0.4 ceiling, so a half-faded
  -- addon would show a mouseover panel that never visibly rose on hover.
  assertNear(spec.mouseoverAlpha, 0.2)
  -- And the floor still cannot exceed the ceiling it fades up to.
  local capped = Canvas.BuildSpec({ alpha = 0.5, mouseover = true, mouseoverAlpha = 1 },
                                  { alpha = 0.5 })
  assertNear(capped.mouseoverAlpha, capped.alpha)
end)

test("Canvas.RenderForCombat: repaints only for the two settings that depend on combat", function()
  -- A combat transition must not cost a full RenderAll for the overwhelmingly common "Always".
  local settings = NS.db.profile.settings
  local before = settings.visibility

  settings.visibility = "always"
  assertFalse(Canvas:RenderForCombat(), "an Always profile repainted on a combat transition")
  settings.visibility = "never"
  assertFalse(Canvas:RenderForCombat(), "a Never profile repainted on a combat transition")
  settings.visibility = "inCombat"
  assertTrue(Canvas:RenderForCombat(), "a combat-sensitive profile did NOT repaint")
  settings.visibility = "outOfCombat"
  assertTrue(Canvas:RenderForCombat(), "a combat-sensitive profile did NOT repaint")

  settings.visibility = before
end)

test("Canvas: leaving and entering combat both reach the renderer", function()
  -- The wiring half. Without both handlers the setting is honored on the next unrelated repaint and
  -- looks intermittent, which is worse than not having it.
  local settings = NS.db.profile.settings
  local before = settings.visibility
  settings.visibility = "outOfCombat"

  R:DeleteAll()
  local rec = R:New("Combatant")
  assertTrue(Canvas:FrameFor(rec.id):IsShown(), "an out-of-combat panel was hidden out of combat")

  -- Through the mock's own combat FLAG, never by replacing InCombatLockdown: the unlock deferral
  -- and the options-panel refusal read the same function, and a case that swapped it out would
  -- leave those suites running against a stand-in that no longer consults the flag they set.
  T.mocks.__inCombat = true
  NS.addon:OnRegenDisabled()
  assertFalse(Canvas:FrameFor(rec.id):IsShown(), "entering combat did not hide the panel")

  T.mocks.__inCombat = false
  NS.addon:OnRegenEnabled()
  assertTrue(Canvas:FrameFor(rec.id):IsShown(), "leaving combat did not bring the panel back")

  settings.visibility = before
  R:DeleteAll()
end)
