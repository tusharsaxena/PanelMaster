local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local U, R, Canvas = NS.Unlock, NS.Registry, NS.Canvas

local function fresh()
  T.mocks.__inCombat = false
  if NS.State.preview then U:SetPreview(false) end
  U:SetUnlocked(false)
  R:DeleteAll()
  Canvas:RenderAll()
end

test("Unlock.SnapPosition: snapping off just rounds", function()
  local x, y = U.SnapPosition(37.6, -12.4, { snapToGrid = false })
  assertEqual(x, 38)
  assertEqual(y, -12)
end)

test("Unlock.SnapPosition: snaps to the configured grid", function()
  local x, y = U.SnapPosition(37, 38, { snapToGrid = true, gridSize = 4 })
  assertEqual(x, 36)
  assertEqual(y, 40)
end)

test("Unlock.SnapPosition: snapping is symmetric across zero", function()
  local x = U.SnapPosition(-37, 0, { snapToGrid = true, gridSize = 4 })
  assertEqual(x, -36)
end)

test("Unlock.SnapPosition: an out-of-range grid is clamped, not obeyed", function()
  local x = U.SnapPosition(100, 0, { snapToGrid = true, gridSize = 99999 })
  -- Clamped to MAX_GRID (128), so 100 snaps to 128 rather than to some absurd multiple.
  assertEqual(x, 128)
end)

test("Unlock.SnapPosition: a missing settings table does not error", function()
  local x, y = U.SnapPosition(10.4, 20.6)
  assertEqual(x, 10)
  assertEqual(y, 21)
end)

test("Unlock.SetUnlocked: flips the session flag", function()
  fresh()
  assertEqual(U:SetUnlocked(true), true)
  assertTrue(NS.State.unlocked)
  assertEqual(U:SetUnlocked(false), false)
  assertFalse(NS.State.unlocked)
end)

test("Unlock.Toggle: alternates", function()
  fresh()
  U:Toggle()
  assertTrue(NS.State.unlocked)
  U:Toggle()
  assertFalse(NS.State.unlocked)
end)

test("Unlock: unlocking during combat is deferred, not applied", function()
  fresh()
  T.mocks.__inCombat = true
  assertEqual(U:SetUnlocked(true), nil, "unlock should report deferral, not a state")
  assertFalse(NS.State.unlocked, "panels unlocked during combat")
  assertTrue(U.__hasPending())
  T.mocks.__inCombat = false
end)

test("Unlock: the deferred unlock is replayed when combat ends", function()
  fresh()
  T.mocks.__inCombat = true
  U:SetUnlocked(true)
  T.mocks.__inCombat = false
  assertTrue(U:ResumePending())
  assertTrue(NS.State.unlocked)
  assertFalse(U.__hasPending(), "the pending flag was not cleared")
end)

test("Unlock: ResumePending is a no-op with nothing queued", function()
  fresh()
  assertFalse(U:ResumePending())
end)

test("Unlock: LOCKING during combat is never deferred", function()
  fresh()
  U:SetUnlocked(true)
  T.mocks.__inCombat = true
  -- Locking only ever makes the UI quieter, so refusing it mid-combat would be the one case where
  -- the gate made things worse.
  assertEqual(U:SetUnlocked(false), false)
  assertFalse(NS.State.unlocked)
  T.mocks.__inCombat = false
end)

test("Unlock: locking clears a queued unlock", function()
  fresh()
  T.mocks.__inCombat = true
  U:SetUnlocked(true)          -- queued
  U:SetUnlocked(false)         -- explicit lock while still in combat
  T.mocks.__inCombat = false
  -- Otherwise the queued unlock would fire on leaving combat and undo the user's explicit lock.
  assertFalse(U.__hasPending())
end)

test("Unlock: an unlocked panel takes the mouse; a locked one does not", function()
  fresh()
  local rec = R:New("Draggable")
  assertFalse(Canvas:FrameFor(rec.id):IsMouseEnabled())
  U:SetUnlocked(true)
  assertTrue(Canvas:FrameFor(rec.id):IsMouseEnabled())
  U:SetUnlocked(false)
  assertFalse(Canvas:FrameFor(rec.id):IsMouseEnabled())
end)

test("Unlock: a DISABLED panel is still shown while unlocked", function()
  fresh()
  local rec = R:New("Hidden")
  R:Set(rec.id, "enabled", false)
  assertFalse(Canvas:FrameFor(rec.id):IsShown())
  U:SetUnlocked(true)
  -- You cannot move a panel you cannot see, and a disabled panel is exactly the one a user is most
  -- likely hunting for.
  assertTrue(Canvas:FrameFor(rec.id):IsShown())
  U:SetUnlocked(false)
end)

test("Unlock: the drag handler writes the dropped position back to the record", function()
  fresh()
  NS.db.profile.settings.snapToGrid = true
  NS.db.profile.settings.gridSize = 4
  local rec = R:New("Dropped")
  U:SetUnlocked(true)
  local f = Canvas:FrameFor(rec.id)

  -- Simulate the drag: the frame ends up somewhere new, then OnDragStop reads it back. Position is
  -- taken from the FRAME rather than accumulated from mouse deltas, which is what this exercises.
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", T.mocks.UIParent, "TOPLEFT", 103, -57)
  f:GetScript("OnDragStop")(f)

  local moved = R:Get(rec.id)
  assertEqual(moved.point, "TOPLEFT", "the drag's new anchor point was not stored")
  assertEqual(moved.x, 104, "x was not snapped to the 4px grid")
  assertEqual(moved.y, -56, "y was not snapped to the 4px grid")
  U:SetUnlocked(false)
end)

test("Unlock: the drag handler ignores a frame whose record is gone", function()
  fresh()
  local rec = R:New("Vanishing")
  U:SetUnlocked(true)
  local f = Canvas:FrameFor(rec.id)
  R:Delete(rec.id)
  -- The frame is pooled but its script survives; firing it must not error on the missing record.
  f:GetScript("OnDragStop")(f)
  U:SetUnlocked(false)
end)

test("Unlock.SetPreview: adds the sample panels and turns unlock on", function()
  fresh()
  assertEqual(U:SetPreview(true), true)
  assertEqual(R:Count(), #NS.Constants.PREVIEW_PANELS)
  assertTrue(NS.State.unlocked, "preview is useless locked")
  U:SetPreview(false)
end)

test("Unlock.SetPreview: off removes exactly what it added", function()
  fresh()
  R:New("Mine")
  U:SetPreview(true)
  U:SetPreview(false)
  -- The user's own panel must survive; only the tracked preview ids go.
  assertEqual(R:Count(), 1)
  assertTrue(R:FindByName("Mine") ~= nil)
  assertFalse(NS.State.preview)
end)

test("Unlock.SetPreview: preview panels really render", function()
  fresh()
  U:SetPreview(true)
  for _, rec in ipairs(R:All()) do
    assertTrue(Canvas:FrameFor(rec.id) ~= nil, rec.name .. " never reached the renderer")
  end
  U:SetPreview(false)
end)

test("Unlock.SetPreview: a name collision skips that placeholder, not the whole preview", function()
  fresh()
  local taken = NS.Constants.PREVIEW_PANELS[1].name
  R:New(taken)
  U:SetPreview(true)
  -- One placeholder is skipped; the other two still appear, alongside the user's panel.
  assertEqual(R:Count(), #NS.Constants.PREVIEW_PANELS)
  assertTrue(R:FindByName(taken) ~= nil)
  U:SetPreview(false)
  assertEqual(R:Count(), 1, "preview removal took the user's panel with it")
end)

test("Unlock.SetPreview: turning it on twice is a no-op", function()
  fresh()
  U:SetPreview(true)
  local count = R:Count()
  U:SetPreview(true)
  assertEqual(R:Count(), count, "preview panels were added twice")
  U:SetPreview(false)
end)

test("Unlock.SetPreview: every placeholder carries the preview marker", function()
  fresh()
  local mine = R:New("Mine")
  U:SetPreview(true)
  local marked = 0
  for _, rec in ipairs(R:All()) do
    if rec.id ~= mine.id then
      -- The marker is the durable half of the pair whose session half is NS.State.previewIDs: it is
      -- what lets a reload find these records again.
      assertTrue(rec[NS.Constants.PREVIEW_FIELD] == true, rec.name .. " was not marked as preview")
      marked = marked + 1
    end
  end
  assertEqual(marked, #NS.Constants.PREVIEW_PANELS)
  assertEqual(mine[NS.Constants.PREVIEW_FIELD], nil, "a normally-created panel carries the marker")
  U:SetPreview(false)
end)

test("Unlock.SetPreview: each transition broadcasts the panel set ONCE", function()
  fresh()
  local target, count = {}, 0
  NS.bus.RegisterMessage(target, R.MSG_PANELS, function() count = count + 1 end)

  U:SetPreview(true)
  assertEqual(count, 1, "preview on broadcast the panel set more than once")
  count = 0
  U:SetPreview(false)
  assertEqual(count, 1, "preview off broadcast the panel set more than once")

  NS.bus.UnregisterMessage(target, R.MSG_PANELS)
end)

test("Unlock.SetPreview: leaving preview puts the lock back through SetUnlocked", function()
  fresh()
  U:SetPreview(true)
  -- A per-panel unlock taken while previewing must not outlive the preview: leaving goes through
  -- SetUnlocked, which is the one place that clears the per-panel sets.
  local rec = R:New("Mine")
  U:SetPanelUnlocked(rec.id, true)
  T.mocks.__inCombat = true
  U:SetPanelUnlocked(rec.id, true)   -- queued rather than applied
  T.mocks.__inCombat = false

  U:SetPreview(false)
  assertFalse(NS.State.unlocked)
  assertEqual(next(NS.State.unlockedPanels), nil, "a per-panel unlock survived the preview")
  assertFalse(U.__hasPending(rec.id), "a queued per-panel unlock survived the preview")
end)

test("Unlock.SetPreview: preview during combat applies whole, it is never queued (F-014)", function()
  fresh()
  T.mocks.__inCombat = true
  -- The implied unlock goes through SetUnlocked, but with the combat gate deliberately bypassed:
  -- the placeholders are plain non-secure frames that this call has just put on screen, so no
  -- secure write is involved (events-frames-taint-§2 is not in play). Deferring only this half
  -- would leave the user mid-pull with three anonymous, mouse-transparent rectangles they cannot
  -- label, move or dismiss — the "worthless locked" state preview exists to avoid.
  U:SetPreview(true)
  assertTrue(NS.State.preview, "preview did not turn on during combat")
  assertTrue(NS.State.unlocked, "preview during combat left its own placeholders locked")
  assertFalse(U.__hasPending(), "preview queued its implied unlock instead of applying it")

  -- And leaving again is symmetrical: the lock lands now, not on the next PLAYER_REGEN_ENABLED,
  -- and it does not leave a stray "panels unlocked" queued behind it.
  U:SetPreview(false)
  assertFalse(NS.State.preview)
  assertFalse(NS.State.unlocked, "leaving preview during combat left the screen unlocked")
  assertFalse(U.__hasPending(), "leaving preview during combat queued an unlock")
  T.mocks.__inCombat = false
end)

test("Unlock.SetPreview: previewing while already unlocked in combat queues nothing (F-014)", function()
  fresh()
  U:SetUnlocked(true)
  T.mocks.__inCombat = true
  U:SetPreview(true)
  U:SetPreview(false)
  -- The user was unlocked before preview, so they are unlocked after it — and no phantom unlock is
  -- sitting in the queue to print "panels unlocked" at them when the fight ends.
  assertTrue(NS.State.unlocked, "preview took away an unlock the user already had")
  assertFalse(U.__hasPending(), "a preview round-trip queued a redundant unlock")
  T.mocks.__inCombat = false
end)

test("Unlock: the global combat gate still defers a plain unlock (F-014)", function()
  -- The bypass belongs to preview alone. A bare /pm unlock mid-pull must still be deferred.
  fresh()
  T.mocks.__inCombat = true
  assertEqual(U:SetUnlocked(true), nil, "the combat gate stopped deferring a plain unlock")
  assertFalse(NS.State.unlocked)
  assertTrue(U.__hasPending())
  T.mocks.__inCombat = false
  U:SetUnlocked(false)
end)

test("Unlock.TogglePreview: alternates", function()
  fresh()
  assertEqual(U:TogglePreview(), true)
  assertEqual(U:TogglePreview(), false)
  assertEqual(R:Count(), 0)
end)

test("Unlock: the overlay outranks every rung of the panel's own ladder", function()
  -- The outline and the name label used to live on the panel frame itself, above its art by DRAW
  -- LAYER alone. That stopped being enough the moment the fill, border, accent and artwork became
  -- child FRAMES: WoW orders by strata, then frame level, then draw layer, so a BACKGROUND texture
  -- on a child at base+2 buries an OVERLAY texture on the parent at base.
  --
  -- The symptom was a gold outline and a panel name rendered underneath the panel's own 85%-opaque
  -- fill on every unlock and every preview — i.e. exactly the panels a user is trying to find.
  fresh()
  local C = NS.Constants
  R:New("ZOrder")
  local rec = R:FindByName("ZOrder")
  U:SetUnlocked(true)
  local f = Canvas:FrameFor(rec.id)
  local o = f.overlay
  assertTrue(o ~= nil, "unlocking built no overlay")
  assertTrue(o.frame ~= nil, "the overlay has no frame of its own")

  local base = f:GetFrameLevel()
  local overlay = o.frame:GetFrameLevel()
  for name, lvl in pairs({
    bg     = C.BG_FRAME_LEVEL,
    border = C.BORDER_FRAME_LEVEL,
    accent = C.ACCENT_FRAME_LEVEL,
    art    = C.ART_FRAME_LEVEL.ABOVE_ALL,
  }) do
    assertTrue(overlay > base + lvl,
      ("the unlock overlay (%d) is not above %s (%d)"):format(overlay, name, base + lvl))
  end
  U:SetUnlocked(false)
end)

test("Unlock: the overlay follows the panel's level when the panel's level changes", function()
  -- Set once at creation, the overlay's level would silently stop clearing the ladder the moment
  -- the user raised the panel's own level — the bug would come back only for panels above level 0.
  fresh()
  R:New("ZFollow")
  local rec = R:FindByName("ZFollow")
  U:SetUnlocked(true)
  local f = Canvas:FrameFor(rec.id)
  R:Set(rec.id, "level", 7)
  f = Canvas:FrameFor(rec.id)
  assertEqual(f.overlay.frame:GetFrameLevel(),
    f:GetFrameLevel() + NS.Constants.UNLOCK_FRAME_LEVEL)
  U:SetUnlocked(false)
end)

test("Unlock: the outline thickness comes from the setting, and ships at the old literal", function()
  -- Promoted from the hardcoded C.UNLOCK_OUTLINE_PX in the tabbed-panel pass. The DEFAULT is the
  -- literal it replaced, which is the whole safety property: an install that never touches the
  -- slider draws exactly the outline it always drew.
  local C = NS.Constants
  assertEqual(NS.Schema:Default("settings.unlockOutlineSize"), C.UNLOCK_OUTLINE_PX,
    "the shipped default no longer matches the literal it replaced, so every install just moved")

  NS.Schema:Set("settings.unlockOutlineSize", 5)
  assertEqual(U.OutlineSize(), 5, "the overlay does not read the setting")

  NS.Schema:Set("settings.unlockOutlineSize", C.UNLOCK_OUTLINE_PX)
  assertEqual(U.OutlineSize(), C.UNLOCK_OUTLINE_PX)
end)

test("Unlock: a hand-edited outline thickness is clamped, not drawn", function()
  -- The slider cannot produce these; SavedVariables can, and an outline of 0 is a panel that cannot
  -- be found in unlock mode rather than an error anybody would see.
  local C = NS.Constants
  local settings = NS.db.profile.settings
  local before = settings.unlockOutlineSize

  settings.unlockOutlineSize = 0
  assertEqual(U.OutlineSize(), C.MIN_UNLOCK_OUTLINE, "a zero outline was drawn as zero")
  settings.unlockOutlineSize = 4000
  assertEqual(U.OutlineSize(), C.MAX_UNLOCK_OUTLINE, "an absurd outline was drawn at full size")
  settings.unlockOutlineSize = "thick"
  assertEqual(U.OutlineSize(), C.UNLOCK_OUTLINE_PX, "a non-number did not fall back to the shipped value")
  settings.unlockOutlineSize = nil
  assertEqual(U.OutlineSize(), C.UNLOCK_OUTLINE_PX, "a missing value did not fall back")

  settings.unlockOutlineSize = before
  -- And the schema refuses the same values the clamp exists for.
  assertFalse((NS.Schema:Set("settings.unlockOutlineSize", 0)))
  assertFalse((NS.Schema:Set("settings.unlockOutlineSize", 4000)))
end)
