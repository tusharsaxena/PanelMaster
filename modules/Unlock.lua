local addonName, NS = ...   -- luacheck: ignore addonName
NS.Unlock = NS.Unlock or {}
local U = NS.Unlock
local C = NS.Constants
local Util = NS.Util
local print = NS.Print   -- secret-safe, [PM]-prefixed shared printer (events-frames-taint-§8)

-- Unlock mode and preview mode: the two ways a panel becomes visible and grabbable.
--
-- A locked panel is deliberately inert scenery — mouse-transparent, unlabeled, often nearly
-- invisible. That is the product, and it is also why it needs an explicit editing mode: you cannot
-- drag what does not take the mouse, and you cannot tell two dark rectangles apart without labels.

-- Unlock requests deferred because they arrived during combat. Replayed from PLAYER_REGEN_ENABLED
-- (core/PanelMaster.lua). `pendingUnlock` is the global one; `pendingPanels` holds per-panel ids.
local pendingUnlock = false
local pendingPanels = {}

-- The per-panel lock line's arguments, built only once NS.DebugBuild is past the gate. A plain
-- function taking (id, on) rather than a closure over them: a closure would be created on every
-- per-panel lock change whether or not logging is on, which is the scan this defers.
local function describeLock(id, on)
  local rec = NS.Registry:Get(id)
  return rec and rec.name or id, on and "unlocked" or "locked"
end

-- ── Snap ────────────────────────────────────────────────────────────────────────

-- PURE: a dragged position → the position that is actually stored. The whole of the drag maths lives
-- here so it is unit-testable without a frame, and so the CLI and the drag handler can never round
-- differently.
function U.SnapPosition(x, y, settings)
  settings = settings or {}
  if not settings.snapToGrid then
    return Util.Round(x), Util.Round(y)
  end
  local grid = Util.Clamp(settings.gridSize, C.MIN_GRID, C.MAX_GRID, 1)
  return Util.Snap(x, grid), Util.Snap(y, grid)
end

-- ── Overlay ─────────────────────────────────────────────────────────────────────

-- Give a panel frame its unlock-mode furniture: a gold outline and a centered name label. Built
-- lazily on first unlock — a user who never unlocks never pays for four textures and a FontString
-- per panel.
local function ensureOverlay(f)
  if f.overlay then return f.overlay end
  local o = { edges = {} }
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    -- OVERLAY, above the panel's own BORDER-layer edges, so the unlock outline is visible even on a
    -- panel whose own border is the same color.
    o.edges[side] = f:CreateTexture(nil, "OVERLAY")
  end
  o.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  o.label:SetPoint("CENTER")
  f.overlay = o
  return o
end

local function layoutOutline(f, o, px)
  local e = o.edges
  e.TOP:ClearAllPoints()
  e.TOP:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  e.TOP:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  e.TOP:SetHeight(px)

  e.BOTTOM:ClearAllPoints()
  e.BOTTOM:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  e.BOTTOM:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  e.BOTTOM:SetHeight(px)

  e.LEFT:ClearAllPoints()
  e.LEFT:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -px)
  e.LEFT:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, px)
  e.LEFT:SetWidth(px)

  e.RIGHT:ClearAllPoints()
  e.RIGHT:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -px)
  e.RIGHT:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, px)
  e.RIGHT:SetWidth(px)
end

-- Is this specific panel unlocked? Either the global unlock is on, or the panel has been unlocked on
-- its own from its editor.
--
-- Per-panel unlock exists because the global one is all-or-nothing: with a dozen panels, unlocking
-- everything to nudge one of them puts eleven draggable rectangles in the way of the one you meant.
-- Session-only, like the global flag and for the same reason — an unlocked panel is an editing
-- state, not a preference (see core/State.lua).
function U:IsPanelUnlocked(id)
  if NS.State.unlocked then return true end
  return id ~= nil and NS.State.unlockedPanels[id] == true
end

-- Unlock or lock one panel. Returns the resulting state, or nil when the request was deferred
-- because of combat — the same contract as the global SetUnlocked, and gated for the same reason.
function U:SetPanelUnlocked(id, on)
  on = not not on
  if on and InCombatLockdown and InCombatLockdown() then
    pendingPanels[id] = true
    print("|cff808080unlock queued \226\128\148 that panel unlocks when you leave combat|r")
    return nil
  end
  NS.State.unlockedPanels[id] = on or nil
  if not on then pendingPanels[id] = nil end
  if NS.Canvas then NS.Canvas:Render(id) end
  -- Through DebugBuild rather than Debug: R:Get scans every panel to turn the id into a name, which
  -- is work nobody with logging off should pay for. describeLock runs only past the sink's gate.
  NS.DebugBuild("Unlock", "'%s' %s", describeLock, id, on)
  return on
end

-- Called by Canvas after every render, so a panel repainted while unlocked keeps its handles.
-- Locked is the common case and returns before building anything.
function U:Decorate(f, rec)
  if not U:IsPanelUnlocked(rec and rec.id) then
    if f.overlay then U:StripOverlay(f) end
    return
  end
  local o = ensureOverlay(f)
  local rgba = C.UNLOCK_OUTLINE_RGB
  layoutOutline(f, o, C.UNLOCK_OUTLINE_PX)
  for _, tex in pairs(o.edges) do
    tex:SetColorTexture(rgba[1], rgba[2], rgba[3], rgba[4])
    tex:Show()
  end

  local labels = (NS.db and NS.db.profile and NS.db.profile.settings.showLabels) ~= false
  o.label:SetText(labels and tostring(rec.name) or "")
  o.label:SetTextColor(C.UNLOCK_LABEL_RGB[1], C.UNLOCK_LABEL_RGB[2], C.UNLOCK_LABEL_RGB[3])
  o.label:SetShown(labels)

  -- An unlocked panel is always shown regardless of its own enabled flag: you cannot move a panel
  -- you cannot see, and a disabled panel is exactly the one a user is most likely to be looking for.
  -- The same applies to the mouseover fade — a panel resting at 0 alpha would be invisible to place,
  -- so editing holds it at its full alpha and the fade resumes when it is locked again.
  if f.__spec then f:SetAlpha(f.__spec.alpha) end
  f:Show()
  U:ArmDrag(f)
end

-- Remove the unlock furniture and make the panel inert again.
function U:StripOverlay(f)
  if not f then return end
  if f.overlay then
    for _, tex in pairs(f.overlay.edges) do tex:Hide() end
    f.overlay.label:Hide()
  end
  f:EnableMouse(false)
  f:SetMovable(false)
  f:RegisterForDrag()
end

-- ── Drag ────────────────────────────────────────────────────────────────────────

-- Wire a frame for dragging, once. The stored position is read back from the FRAME after the drag
-- (GetPoint), not accumulated from mouse deltas: the frame is the thing the user actually
-- positioned, and re-deriving it from deltas would drift by a rounding error per drag.
function U:ArmDrag(f)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  if f.__dragArmed then return end
  f.__dragArmed = true

  -- The handler's frame argument is named `frame`, not `self`: `self` here would shadow ArmDrag's
  -- own `f` upvalue and read as though the module were the frame.
  f:SetScript("OnDragStart", function(frame) frame:StartMoving() end)
  f:SetScript("OnDragStop", function(frame)
    frame:StopMovingOrSizing()
    local rec = NS.Registry:Get(frame.panelID)
    if not rec then return end
    local point, _, relPoint, x, y = frame:GetPoint(1)
    if not point then return end
    local settings = (NS.db and NS.db.profile and NS.db.profile.settings) or {}
    x, y = U.SnapPosition(x, y, settings)
    -- The anchor point can change during a drag (StartMoving re-anchors to whichever corner the
    -- frame ends up nearest), so both the point and the offset are written back — storing only the
    -- offset against a stale point would teleport the panel on the next login.
    rec.point, rec.relPoint = point, relPoint
    NS.Registry:SetPosition(rec.id, x, y)
  end)
end

-- ── Lock / unlock ───────────────────────────────────────────────────────────────

-- Enter or leave unlock mode. Returns the resulting state, or nil when the request was deferred.
--
-- Combat gate: unlocking hands the user draggable frames, which is a bad thing to do mid-pull, so
-- the request is DEFERRED to PLAYER_REGEN_ENABLED (events-frames-taint-§2) rather than refused.
-- Locking is never deferred — it only ever makes the UI quieter, and refusing to lock during combat
-- would be the one case where the gate made things worse.
--
-- `immediate` skips the gate. It has exactly one caller — preview mode, which is bypassing the gate
-- deliberately (see U:SetPreview): its frames are plain non-secure placeholders it has just created
-- itself, so there is no secure write for the gate to protect and events-frames-taint-§2 is not in
-- play. Deferring only preview's half would leave the user mid-pull with unlabeled scenery. It is a
-- private argument, not part of the lock surface: the CLI, the schema switch and Toggle all go
-- through the gated path.
function U:SetUnlocked(on, immediate)
  on = not not on
  if on and not immediate and InCombatLockdown and InCombatLockdown() then
    pendingUnlock = true
    print("|cff808080unlock queued \226\128\148 panels unlock when you leave combat|r")
    return nil
  end
  NS.State.unlocked = on
  if not on then
    pendingUnlock = false
    -- A global lock is an unambiguous "put everything away", so it clears the per-panel unlocks too.
    -- Leaving one panel unlocked after the user pressed lock would be a draggable frame they thought
    -- they had dismissed.
    for id in pairs(NS.State.unlockedPanels) do NS.State.unlockedPanels[id] = nil end
    for id in pairs(pendingPanels) do pendingPanels[id] = nil end
  end
  if NS.Canvas then NS.Canvas:RenderAll() end
  NS.Debug("Unlock", "panels %s", on and "unlocked" or "locked")
  return on
end

function U:Toggle()
  return U:SetUnlocked(not NS.State.unlocked)
end

-- Replay every combat-deferred unlock. Called from PLAYER_REGEN_ENABLED (core/PanelMaster.lua).
function U:ResumePending()
  local resumed = false

  if pendingUnlock then
    pendingUnlock = false
    U:SetUnlocked(true)
    print("panels unlocked")
    resumed = true
  end

  -- Per-panel unlocks queued during the same fight. Collected before applying, because
  -- SetPanelUnlocked writes to the very table being iterated.
  local ids = {}
  for id in pairs(pendingPanels) do ids[#ids + 1] = id end
  for _, id in ipairs(ids) do
    pendingPanels[id] = nil
    -- Skip a panel deleted mid-combat: replaying it would resurrect an entry for a record that has
    -- gone, and the unlock set would never be cleaned up.
    if NS.Registry:Get(id) then
      U:SetPanelUnlocked(id, true)
      resumed = true
    end
  end

  return resumed
end

-- Exposed so a test can assert the deferral without reaching into a file-local.
function U:HasPending(id)
  if id ~= nil then return pendingPanels[id] == true end
  return pendingUnlock
end

-- ── Preview mode (preview-mode) ─────────────────────────────────────────────────

-- Stand up a few placeholder panels through the REAL render path, so what the user sees while
-- previewing is exactly what a real panel looks like — not a mock-up that can drift from it.
--
-- The placeholders are written into the registry like any other panel and removed again on the way
-- out, which is what keeps the render path singular. Their ids are tracked in session state so
-- turning preview off withdraws exactly what it added, never a panel the user made in the meantime.
function U:SetPreview(on)
  on = not not on
  if on == NS.State.preview then return on end

  if on then
    -- Remember whether the screen was already unlocked, so turning preview off can put it back.
    -- Preview implies unlock (below), and without this the implied unlock outlived the preview that
    -- caused it — you turned test mode off and were left with every panel still draggable.
    U.__unlockBeforePreview = NS.State.unlocked
    NS.State.previewIDs = {}
    -- Marked on the way in, so a /reload that never reaches the exit below can still find them
    -- (NS:SweepPreviewPanels). A name collision with a real panel is the user's, not ours: NewBatch
    -- skips that placeholder rather than refusing the whole preview or overwriting their panel.
    local specs = {}
    for _, spec in ipairs(C.PREVIEW_PANELS) do
      local marked = Util.DeepCopy(spec)
      marked[C.PREVIEW_FIELD] = true
      specs[#specs + 1] = marked
    end
    -- Registry first, lock second: SetUnlocked repaints, so the placeholders have to exist before it
    -- runs or the repaint draws the screen as it was.
    for _, rec in ipairs(NS.Registry:NewBatch(specs)) do
      NS.State.previewIDs[#NS.State.previewIDs + 1] = rec.id
    end
    NS.State.preview = true
    -- Preview is worthless locked — the placeholders would be unlabeled scenery — so it implies
    -- unlock. Routed through SetUnlocked rather than writing the flag here, so the implied unlock is
    -- the SAME unlock as every other one: it repaints, it logs, and it leaves the per-panel sets in
    -- a state the matching lock can undo. Writing NS.State directly was what let preview leave the
    -- screen unlocked with nothing tracking it.
    --
    -- The combat gate is bypassed on purpose (`immediate`). These placeholders are non-secure frames
    -- this call has just put on screen, so no secure write is involved and events-frames-taint-§2 is
    -- not in play. Queueing this half would apply preview and defer its unlock — three anonymous,
    -- mouse-transparent rectangles mid-pull, under a message that never mentions preview.
    U:SetUnlocked(true, true)
  else
    NS.Registry:DeleteBatch(NS.State.previewIDs)
    NS.State.previewIDs = {}
    NS.State.preview = false
    -- Undo the implied unlock, unless the user had already unlocked before starting preview — in
    -- which case they were mid-edit and leaving them locked would be just as surprising. Routed
    -- through SetUnlocked so a lock also clears the per-panel unlocks it is supposed to clear, and
    -- past the gate for the same reason the way in was: restoring the state the user was in is not
    -- a request they should have to wait out a fight for.
    U:SetUnlocked(U.__unlockBeforePreview and true or false, true)
  end

  NS.Debug("Preview", "preview %s", on and "on" or "off")
  return on
end

function U:TogglePreview()
  return U:SetPreview(not NS.State.preview)
end
