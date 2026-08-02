local addonName, NS = ...   -- luacheck: ignore addonName
NS.Canvas = NS.Canvas or {}
local Canvas = NS.Canvas
local C = NS.Constants
local Util = NS.Util

-- The renderer: turns panel records into on-screen frames and keeps them in step with the registry.
--
-- Panels are NON-SECURE frames (standalone-windows), so none of this is combat-gated — creating,
-- moving, recoloring and hiding a plain backdrop frame is all legal in combat, and gating it would
-- mean a panel that visibly failed to follow a settings change mid-pull. Unlock mode is the one part
-- that IS gated, and for a UX reason rather than a taint one (modules/Unlock.lua).

-- Frame pool (hard rule #14: ≥10 dynamic frames use a pool). A user with thirty panels who toggles
-- the master switch twice would otherwise leak sixty frames — WoW frames are never garbage
-- collected, so "create one per record on every rebuild" is a permanent leak, not a slow one.
--
-- The pool is keyed by GLOBAL FRAME NAME rather than being a flat stack, because every panel frame
-- carries a deterministic name (`PanelMaster_Panel_<slug>`) that other addons anchor to — and a
-- frame's name is fixed at CreateFrame time and can never be changed afterwards. So a released
-- frame can only be reused by a panel that wants the same name, which in practice means: delete a
-- panel and re-create it with the same name and you get the same frame back.
--
-- The bound on frames is therefore "one per distinct panel name used this session", not "one per
-- create". Renaming a panel ten times does leave ten frames behind — hidden, unparented and inert —
-- which is the price of the deterministic-name contract and is bounded by how often a human renames
-- things. The alternative (anonymous pooled frames plus `_G` aliases) keeps a flat pool but hands
-- out frames whose `GetName()` is nil, which breaks every consumer that expects a real named frame.
local pool = {}      -- globalName → a released frame, ready to be reused under that same name
local active = {}    -- panel id → the frame currently on screen for it
Canvas.__pool, Canvas.__active = pool, active

-- Panels currently running the mouseover fade, so one shared ticker drives all of them.
local mouseoverPanels = {}
local mouseoverDriver

-- ── The render spec ─────────────────────────────────────────────────────────────
-- PURE: record + settings → exactly what the frame should look like. No frames touched, so the whole
-- of "what does this panel render as" is unit-testable headlessly, and the frame code below becomes
-- a thin, uninteresting application of the result.
--
-- `shown` folds the two independent switches — the addon-wide master and the panel's own — into one
-- answer, so no call site has to remember both.
function Canvas.BuildSpec(rec, settings)
  if type(rec) ~= "table" then return nil end
  settings = settings or {}
  local alpha = Util.Clamp(rec.alpha, 0, 1, 1)
  local mouseover = rec.mouseover and true or false
  -- Hoisted out of the table below because the artwork geometry needs the CLAMPED size, not the raw
  -- record fields: art fitted to a width the panel will never actually be drawn at is art that lands
  -- in the wrong place the moment the clamp bites.
  local width  = Util.Clamp(rec.width,  C.MIN_SIZE, C.MAX_SIZE, C.PANEL_TEMPLATE.width)
  local height = Util.Clamp(rec.height, C.MIN_SIZE, C.MAX_SIZE, C.PANEL_TEMPLATE.height)
  return {
    id        = rec.id,
    name      = rec.name,
    frameName = Util.FrameName(rec.name),
    shown     = (settings.enabled ~= false) and (rec.enabled ~= false),
    width     = width,
    height    = height,
    point     = Util.IsPoint(rec.point) and rec.point or C.PANEL_TEMPLATE.point,
    relPoint  = Util.IsPoint(rec.relPoint) and rec.relPoint or C.PANEL_TEMPLATE.relPoint,
    x         = tonumber(rec.x) or 0,
    y         = tonumber(rec.y) or 0,
    strata    = Util.IsStrata(rec.strata) and rec.strata or C.PANEL_TEMPLATE.strata,
    level     = Util.Clamp(rec.level, 0, 100, 0),
    alpha     = alpha,
    -- Colors come from the shared resolver, so the class-color override is applied in exactly one
    -- place for every color the addon will ever have (C.COLOR_FIELDS).
    bg        = Util.ResolveColor(rec, "bgColor"),
    border    = Util.ResolveColor(rec, "borderColor"),
    bgTexture     = rec.bgTexture or C.PANEL_TEMPLATE.bgTexture,
    borderTexture = rec.borderTexture or C.PANEL_TEMPLATE.borderTexture,
    -- A zero border is a real choice (a plain block with no outline), so it is honoured rather than
    -- floored to 1 — it means no backdrop is applied at all rather than one drawn at zero size.
    borderSize = Util.Clamp(rec.borderSize, C.MIN_BORDER, C.MAX_BORDER, 1),
    borderOffset =
      Util.Clamp(rec.borderOffset, C.MIN_BORDER_OFFSET, C.MAX_BORDER_OFFSET, 0),
    mouseover  = mouseover,
    -- The alpha the panel rests at when the cursor is elsewhere. Clamped to at most `alpha`: a
    -- resting alpha above the hover alpha would make the panel FADE when you moused over it, which
    -- is not what the setting says it does.
    mouseoverAlpha = mouseover and math.min(Util.Clamp(rec.mouseoverAlpha, 0, 1, 0), alpha) or alpha,

    -- The accent bar, resolved into one sub-table so the renderer takes a single decision per edge
    -- rather than re-reading and re-validating the record four times.
    accent = {
      enabled   = rec.accentEnabled and true or false,
      edges     = Util.EdgeSet(rec.accentEdges),
      texture   = rec.accentTexture or C.PANEL_TEMPLATE.accentTexture,
      thickness = Util.Clamp(rec.accentThickness,
        C.MIN_ACCENT_THICKNESS, C.MAX_ACCENT_THICKNESS, C.PANEL_TEMPLATE.accentThickness),
      offset    = Util.Clamp(rec.accentOffset,
        C.MIN_ACCENT_OFFSET, C.MAX_ACCENT_OFFSET, C.PANEL_TEMPLATE.accentOffset),
      -- Through the same shared resolver as every other color, so the class-color override needed
      -- no new code here at all — just the C.COLOR_FIELDS row.
      color     = Util.ResolveColor(rec, "accentColor"),
      -- The bar's own border, sharing the panel border's bounds so the two sliders read alike.
      borderTexture = rec.accentBorderTexture or C.PANEL_TEMPLATE.accentBorderTexture,
      borderSize    = Util.Clamp(rec.accentBorderSize,
        C.MIN_BORDER, C.MAX_BORDER, C.PANEL_TEMPLATE.accentBorderSize),
      borderOffset  = Util.Clamp(rec.accentBorderOffset,
        C.MIN_BORDER_OFFSET, C.MAX_BORDER_OFFSET, C.PANEL_TEMPLATE.accentBorderOffset),
      borderColor   = Util.ResolveColor(rec, "accentBorderColor"),
    },

    -- The artwork layer, resolved entirely by modules/Artwork.lua — every fill, crop, flip and
    -- quarter-turn is arithmetic on the record, and none of it belongs in a renderer. nil means
    -- "this panel draws no artwork", which is the default and stays the cheapest answer.
    --
    -- Guarded on the module existing so a partial load (or a test harness that skips it) yields a
    -- panel with no art rather than an error out of the spec builder, which every render path calls.
    art = NS.Artwork and NS.Artwork.BuildArtSpec(rec, width, height) or nil,
  }
end

local function currentSettings()
  local p = NS.db and NS.db.profile
  return (p and p.settings) or {}
end

-- ── Frame construction ──────────────────────────────────────────────────────────

-- Build a bare panel frame under its deterministic global name.
--
-- The name is passed to CreateFrame rather than assigned afterwards because a frame's name is
-- immutable — this is the only moment it can be set, and it is what makes
-- `PanelMaster_Panel_<slug>` a real, anchorable frame rather than a table in `_G`.
--
-- `BackdropTemplate` is required: the border is drawn as a backdrop `edgeFile` so it can use any
-- LibSharedMedia border texture. (The first version used four flat textures, which cannot render an
-- edge file's corners at all.) The BACKGROUND fill stays a plain texture, because a backdrop's
-- `bgFile` insets under the edge and a panel wants its fill to run to the frame's actual bounds.
local function newFrame(globalName)
  local f = CreateFrame("Frame", globalName, UIParent)
  f:SetClampedToScreen(false)   -- a panel may legitimately hang off the screen edge
  f:EnableMouse(false)          -- locked panels are mouse-transparent; Unlock flips this

  -- The fill lives on its OWN child frame rather than on the panel, for one reason: a child frame
  -- always draws above its parent's textures whatever draw layer those use, so with the fill on the
  -- panel itself there is NO level a child frame could take to get underneath it — and "artwork
  -- behind the background" would be unreachable. The texture keeps the field name `f.bg` so every
  -- call site and test that paints it is unchanged; only what it hangs off moved.
  f.bgFrame = CreateFrame("Frame", nil, f)
  f.bgFrame:EnableMouse(false)
  f.bgFrame:SetAllPoints(f)

  f.bg = f.bgFrame:CreateTexture(nil, "BACKGROUND")
  f.bg:SetAllPoints(f.bgFrame)

  -- The border lives on its own child frame rather than on the panel itself, so it can be OFFSET
  -- from the panel's edge (borderOffset). A backdrop is always drawn at its own frame's bounds, so
  -- the only way to move the border in or out is to move the frame carrying it.
  --
  -- It is a child, so it inherits the panel's strata, level and alpha automatically — the border can
  -- never end up on a different layer from the panel it belongs to.
  f.borderFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
  f.borderFrame:EnableMouse(false)

  -- Accent bars, one texture per edge, created up front and shown/hidden per render. Four textures
  -- is cheaper than creating and destroying them as the edge set changes, and it keeps the render
  -- path allocation-free.
  --
  -- They live on their OWN child frame rather than directly on the panel, purely for z-order: a
  -- child frame always draws above its parent's textures whatever draw layer those use, so with the
  -- border on one child frame and the bars on the panel itself, the border covered the bars no
  -- matter what. Two child frames with explicit levels (see applySpec) put the accent above the
  -- border, which is the way round it has to be — the bar is the top decoration.
  --
  -- Still a child of the panel, so it inherits strata and alpha: an accent bar can never end up on a
  -- different layer from the panel it accents, and it fades with the mouseover fade for free.
  f.accentFrame = CreateFrame("Frame", nil, f)
  f.accentFrame:EnableMouse(false)
  f.accentFrame:SetAllPoints(f)

  -- One FRAME per edge rather than a bare texture, because a bar can carry its own border and a
  -- backdrop needs a frame to live on. The fill is a texture filling that frame.
  f.accents = {}
  for _, edge in ipairs(C.EDGES) do
    local bar = CreateFrame("Frame", nil, f.accentFrame)
    bar:EnableMouse(false)
    bar.fill = bar:CreateTexture(nil, "ARTWORK")
    bar.fill:SetAllPoints(bar)
    f.accents[edge] = bar
  end

  -- ONE artwork frame, not three. The layer choice (behind the background, above it, above
  -- everything) is expressed by reassigning this frame's level per render — frame levels are mutable
  -- at any time — so three frames for three choices would be two frames created to sit hidden
  -- forever on every panel the user owns.
  f.artFrame = CreateFrame("Frame", nil, f)
  f.artFrame:EnableMouse(false)
  f.artFrame:SetAllPoints(f)
  -- This is what makes "artwork renders inside the panel's bounds" true for offset and scaled art:
  -- without it, STATIC art anchored near an edge simply hangs off the panel. Guarded on the METHOD
  -- being present rather than a build check, exactly as SetBackdrop is — a headless stub frame has
  -- no real clipping either, and both cases must degrade to unclipped art instead of erroring.
  --
  -- Clipping is on the ART frame specifically, never on the panel: the accent bars deliberately hang
  -- OUTSIDE the panel's bounds, and a clip one level up would eat them.
  if type(f.artFrame.SetClipsChildren) == "function" then
    f.artFrame:SetClipsChildren(true)
  end
  f.art = f.artFrame:CreateTexture(nil, "ARTWORK")

  return f
end

-- The accent bar's own border frame, built on first use.
--
-- Lazy because most panels never give their bars a border (it ships at size 0), and this would
-- otherwise be four more frames per panel created for nothing. Same shape as the panel's border: a
-- separate frame, so the border can be OFFSET from the bar it outlines.
local function ensureAccentBorder(bar)
  if bar.borderFrame then return bar.borderFrame end
  bar.borderFrame = CreateFrame("Frame", nil, bar, "BackdropTemplate")
  bar.borderFrame:EnableMouse(false)
  return bar.borderFrame
end

-- Paint one accent bar's border. Mirrors applyBorder exactly — including that
-- SetBackdropBorderColor MUST follow SetBackdrop, which resets it to white.
local function applyAccentBorder(bar, spec)
  local a = spec.accent
  local wanted = a.borderSize > 0 and NS.Compat.FetchMedia("border", a.borderTexture) or nil
  if not wanted then
    -- Never built one, and none wanted: nothing to do. This is the common case and is why the
    -- border frame is lazy.
    if not bar.borderFrame then return end
    bar.borderFrame:SetBackdrop(nil)
    bar.borderFrame:Hide()
    return
  end

  local b = ensureAccentBorder(bar)
  if type(b.SetBackdrop) ~= "function" then return end
  b:ClearAllPoints()
  b:SetPoint("TOPLEFT", bar, "TOPLEFT", -a.borderOffset, a.borderOffset)
  b:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", a.borderOffset, -a.borderOffset)
  b:Show()
  b:SetBackdrop({ edgeFile = wanted, edgeSize = a.borderSize })
  b:SetBackdropBorderColor(
    a.borderColor[1], a.borderColor[2], a.borderColor[3], a.borderColor[4])
end

-- Lay out and paint the accent bars.
--
-- Each bar spans its edge in full and is offset OUTWARD from the panel: positive pushes it away
-- (the detached BenikUI look), negative pulls it over the panel's own area. The anchor pair per edge
-- is what makes "covers the entirety of that edge" true by construction — the bar is pinned to both
-- corners of that side, so it tracks the panel's size with no recalculation.
local function applyAccents(f, spec)
  local accents = f.accents
  if not accents then return end

  local a = spec.accent
  local thickness, offset = a.thickness, a.offset

  for _, edge in ipairs(C.EDGES) do
    local bar = accents[edge]
    if not a.enabled or not a.edges[edge] then
      bar:Hide()
    else
      bar:ClearAllPoints()
      if edge == "TOP" then
        bar:SetPoint("BOTTOMLEFT",  f, "TOPLEFT",     0, offset)
        bar:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT",    0, offset)
        bar:SetHeight(thickness)
      elseif edge == "BOTTOM" then
        bar:SetPoint("TOPLEFT",     f, "BOTTOMLEFT",  0, -offset)
        bar:SetPoint("TOPRIGHT",    f, "BOTTOMRIGHT", 0, -offset)
        bar:SetHeight(thickness)
      elseif edge == "LEFT" then
        bar:SetPoint("TOPRIGHT",    f, "TOPLEFT",     -offset, 0)
        bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT",  -offset, 0)
        bar:SetWidth(thickness)
      else -- RIGHT
        bar:SetPoint("TOPLEFT",     f, "TOPRIGHT",    offset, 0)
        bar:SetPoint("BOTTOMLEFT",  f, "BOTTOMRIGHT", offset, 0)
        bar:SetWidth(thickness)
      end

      local path = NS.Compat.FetchMedia("statusbar", a.texture)
      if path then
        bar.fill:SetTexture(path)
        bar.fill:SetVertexColor(a.color[1], a.color[2], a.color[3], a.color[4])
      else
        bar.fill:SetColorTexture(a.color[1], a.color[2], a.color[3], a.color[4])
      end
      -- A statusbar texture is authored horizontally, so the vertical edges need it turned a quarter
      -- turn or the bevel runs the wrong way (see C.ACCENT_TEXCOORD_ROT90). Applied AFTER SetTexture,
      -- which resets a texture's coords, and on every repaint rather than once at creation — a
      -- pooled frame reused for another panel would otherwise keep whatever the last one asked for.
      local coord = (edge == "LEFT" or edge == "RIGHT")
        and C.ACCENT_TEXCOORD_ROT90 or C.ACCENT_TEXCOORD_FLAT
      bar.fill:SetTexCoord(coord[1], coord[2], coord[3], coord[4],
                           coord[5], coord[6], coord[7], coord[8])
      applyAccentBorder(bar, spec)
      bar:Show()
    end
  end
end

-- Paint the background fill. An LSM background name resolves to a texture path that is tinted with
-- the panel's color via SetVertexColor; the "None" entry means draw no fill at all.
local function applyBackground(f, spec)
  local path = NS.Compat.FetchMedia("background", spec.bgTexture)
  if not path then
    f.bg:SetTexture(nil)
    f.bg:Hide()
    return
  end
  f.bg:Show()
  f.bg:SetTexture(path, "REPEAT", "REPEAT")
  f.bg:SetVertexColor(spec.bg[1], spec.bg[2], spec.bg[3], spec.bg[4])
end

-- Paint the border as a backdrop edge. `edgeSize` is the border thickness the user set, which for
-- the flat "Solid" texture is a literal pixel width and for a decorative edge file is the size its
-- slices are drawn at — the same knob either way, which is why it stays one setting.
--
-- Guarded on the METHOD being present, rather than on a build check: it is the frame in hand that
-- has to answer, and a headless stub has no real SetBackdrop either. Both cases degrade to a plain
-- borderless panel instead of erroring.
local function applyBorder(f, spec)
  local b = f.borderFrame
  if not b or type(b.SetBackdrop) ~= "function" then return end

  -- Offset the border frame from the panel's edge. Positive pushes it outward (a halo), negative
  -- pulls it inward (an inset frame); 0 sits exactly on the edge.
  b:ClearAllPoints()
  b:SetPoint("TOPLEFT", f, "TOPLEFT", -spec.borderOffset, spec.borderOffset)
  b:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", spec.borderOffset, -spec.borderOffset)

  local path = spec.borderSize > 0 and NS.Compat.FetchMedia("border", spec.borderTexture) or nil
  if not path then
    -- No border at all: a zero thickness, or the "None" texture. Clearing the backdrop is what
    -- removes it — a backdrop drawn at zero size still costs a draw call and can leave artefacts.
    b:SetBackdrop(nil)
    b:Hide()
    return
  end
  b:Show()
  -- BackdropTemplate wants the table verbatim on every call; it is not merged with the previous one.
  b:SetBackdrop({ edgeFile = path, edgeSize = spec.borderSize })
  -- MUST follow SetBackdrop: applying a backdrop resets its border color to white, so coloring
  -- first would be silently undone.
  b:SetBackdropBorderColor(spec.border[1], spec.border[2], spec.border[3], spec.border[4])
end

-- Paint the artwork layer. Every decision worth making was already made in Artwork.BuildArtSpec —
-- this is the dumb applier, which is the point: the fill math is arithmetic on a record and is
-- verified headlessly, so nothing here needs a judgement call.
local function applyArtwork(f, spec)
  local frame, tex = f.artFrame, f.art
  if not frame or not tex then return end

  local art = spec.art
  if not art then
    -- Cleared as well as hidden. A hidden frame still holds its texture's file reference, and this
    -- same frame is about to be handed to whatever panel the pool gives it to next.
    tex:SetTexture(nil)
    frame:Hide()
    return
  end
  frame:Show()

  -- The one place the ladder is not a fixed offset: which of the three artwork levels this panel
  -- wants is a per-record choice, resolved into a number by the spec.
  local base = f:GetFrameLevel() or 0
  frame:SetFrameLevel(base + art.level)

  -- REPEAT wrapping is the only thing that makes TILE's out-of-range coords mean anything; passing
  -- it unconditionally would let a FILL crop's rounding sample the opposite edge instead of clamping
  -- to the border pixel, so the wrap arguments are omitted entirely when the art does not tile.
  if art.tile then
    tex:SetTexture(art.path, "REPEAT", "REPEAT")
  else
    tex:SetTexture(art.path)
  end

  tex:SetSize(art.width, art.height)
  tex:ClearAllPoints()
  tex:SetPoint(art.point, frame, art.point, art.x, art.y)

  -- MUST follow SetTexture, which resets a texture's coords — the same rule the accent bars already
  -- document, and the reason the crop/flip/rotation is reapplied on every repaint rather than once.
  local uv = art.uv
  tex:SetTexCoord(uv[1], uv[2], uv[3], uv[4], uv[5], uv[6], uv[7], uv[8])
  -- Desaturate BEFORE the tint, because the two compose: grayscale art multiplied by a color comes
  -- back as a clean, saturated version of that color, where full-color art multiplied by the same
  -- one comes back as a darkened average of whatever hues it already had.
  --
  -- Guarded because SetDesaturated is not universally present on every texture object across
  -- flavors, and a missing method here would take down the whole repaint rather than lose one
  -- effect. Compat owns the deprecated-API surface, but this is an absence rather than a rename.
  if tex.SetDesaturated then
    tex:SetDesaturated(art.desaturate)
  end

  tex:SetVertexColor(art.color[1], art.color[2], art.color[3], art.color[4])

  -- Both of these are set explicitly rather than left to the texture's default, because this
  -- texture is POOLED: it is the same object a previous panel drew with, so any value one panel
  -- changed would otherwise leak into the next.
  tex:SetBlendMode(art.blend)
end

-- Apply a spec to a frame. Idempotent — running it twice with the same spec is a no-op — so the
-- repaint path never has to track what changed.
local function applySpec(f, spec)
  f:SetSize(spec.width, spec.height)
  f:ClearAllPoints()
  f:SetPoint(spec.point, UIParent, spec.relPoint, spec.x, spec.y)
  f:SetFrameStrata(spec.strata)
  -- Multiplied by the stride, so each panel's whole stack gets a band of its own rather than
  -- interleaving with the next panel's. The user's `level` is a relative ordering ("higher draws in
  -- front"), not a raw frame level — and used raw it stopped meaning that as soon as a panel
  -- occupied more than one rung. See C.PANEL_LEVEL_STRIDE.
  f:SetFrameLevel(spec.level * C.PANEL_LEVEL_STRIDE)

  -- Explicit child levels, stacked bottom-up over seven slots:
  --
  --   +1  artwork, BELOW_BG          +4  border          +7  unlock overlay (modules/Unlock.lua)
  --   +2  background fill            +5  accent bars
  --   +3  artwork, ABOVE_BG          +6  artwork, ABOVE_ALL
  --
  -- The unlock overlay is not set here — Unlock owns it and builds it lazily — but it is part of
  -- this ladder and is why the stride is 8 rather than 7.
  --
  -- Left to itself every child frame merely defaults to parent + 1, which would pile the fill, the
  -- border and the accent onto one level and leave their order to creation sequence. The six numbers
  -- are spread out — rather than the artwork taking one slot next to the others — because the art
  -- has to INTERLEAVE with the rest: three of the six slots are the same single art frame, whose
  -- level is reassigned per render from C.ART_FRAME_LEVEL. That is the only way "behind the
  -- background" and "above the accent bar" can both be reachable without three art frames per panel.
  -- The numbers live in Constants so this ladder is stated once; do not renumber without updating
  -- both.
  --
  -- Read back with GetFrameLevel rather than reusing spec.level, because the client clamps a frame's
  -- level to a minimum and the value that landed may not be the value asked for.
  local base = f:GetFrameLevel() or 0
  if f.bgFrame then f.bgFrame:SetFrameLevel(base + C.BG_FRAME_LEVEL) end
  if f.borderFrame then f.borderFrame:SetFrameLevel(base + C.BORDER_FRAME_LEVEL) end
  if f.accentFrame then f.accentFrame:SetFrameLevel(base + C.ACCENT_FRAME_LEVEL) end

  applyBackground(f, spec)
  applyBorder(f, spec)
  applyAccents(f, spec)
  applyArtwork(f, spec)

  -- The resting alpha. While unlocked this is overridden to full opacity by Unlock:Decorate — you
  -- cannot place a panel you cannot see — so the mouseover fade is an editing-mode-off behavior.
  f.__spec = spec
  f:SetAlpha(spec.mouseover and spec.mouseoverAlpha or spec.alpha)
  Canvas.SetMouseoverTracked(spec.id, f, spec.mouseover)

  f:SetShown(spec.shown)
end

-- ── Mouseover fade ──────────────────────────────────────────────────────────────
-- One shared OnUpdate drives every mouseover panel, rather than one script per panel: the work is a
-- MouseIsOver call per tracked panel and a shared ticker keeps that a single scheduled callback no
-- matter how many panels the user has.
--
-- Deliberately polled rather than driven by OnEnter/OnLeave, because those require the frame to take
-- mouse input — and a panel that takes the mouse stops being click-through, which is the one
-- guarantee a backdrop must never break. Polling reads the cursor without claiming it.
local MOUSEOVER_INTERVAL = 0.1   -- 10Hz; well under a frame budget and imperceptible as a delay

local function updateMouseover()
  local unlocked = NS.State.unlocked
  for id, f in pairs(mouseoverPanels) do
    local spec = f.__spec
    if not spec then
      mouseoverPanels[id] = nil
    elseif unlocked or NS.Unlock:IsPanelUnlocked(id) then
      -- Editing this panel: hold it fully visible so it can be found and dragged.
      f:SetAlpha(spec.alpha)
    else
      f:SetAlpha(NS.Compat.MouseIsOver(f) and spec.alpha or spec.mouseoverAlpha)
    end
  end
end
Canvas.__updateMouseover = updateMouseover   -- test seam: the headless build has no OnUpdate

local function ensureMouseoverDriver()
  if mouseoverDriver then return mouseoverDriver end
  mouseoverDriver = CreateFrame("Frame")
  local elapsed = 0
  mouseoverDriver:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + (delta or 0)
    if elapsed < MOUSEOVER_INTERVAL then return end
    elapsed = 0
    updateMouseover()
  end)
  return mouseoverDriver
end

-- Add or drop a panel from the mouseover ticker, and start the ticker on first use. The driver is
-- never destroyed once created — it is one frame, and it stops doing any work the moment the tracked
-- set is empty.
function Canvas.SetMouseoverTracked(id, frame, tracked)
  if tracked then
    mouseoverPanels[id] = frame
    ensureMouseoverDriver()
  else
    mouseoverPanels[id] = nil
  end
end

Canvas.__mouseoverPanels = mouseoverPanels   -- test seam

-- ── Pool ────────────────────────────────────────────────────────────────────────

-- Get the frame that carries `globalName`, reusing a released one if that exact name has been seen
-- before. A frame can only ever answer to the name it was created with, so the pool is a lookup, not
-- a stack.
local function acquire(globalName)
  local f = pool[globalName]
  if f then
    pool[globalName] = nil
    return f
  end
  return newFrame(globalName)
end

local function release(f)
  if not f then return end
  f:Hide()
  f:ClearAllPoints()
  f:EnableMouse(false)
  f.__spec = nil
  if f.panelID then Canvas.SetMouseoverTracked(f.panelID, nil, false) end
  -- Cleared only after the untrack above, which reads it. A pooled frame that kept `panelID` would
  -- name a record it no longer draws — harmless (Canvas:Render reassigns it) but misleading in a
  -- `/pm debug dump`.
  f.panelID = nil
  if f.borderFrame and type(f.borderFrame.SetBackdrop) == "function" then
    f.borderFrame:SetBackdrop(nil)
    f.borderFrame:Hide()
  end
  -- Accent bars are anchored OUTSIDE the panel's bounds, so a pooled frame that kept them would
  -- leave four colored strips floating where the panel used to be.
  for _, bar in pairs(f.accents or {}) do
    bar:Hide()
    if bar.borderFrame and type(bar.borderFrame.SetBackdrop) == "function" then
      bar.borderFrame:SetBackdrop(nil)
      bar.borderFrame:Hide()
    end
  end
  -- Same reasoning as the bars: a released frame must be inert, not merely hidden. It sits in the
  -- pool until some other panel claims its name, and anything that shows it before applySpec runs
  -- again — Unlock's overlay, a debug dump, a stray Show() — would put the PREVIOUS panel's artwork
  -- on screen for the new one. Clearing the texture as well as hiding the frame also drops the file
  -- reference for a panel that may never come back.
  if f.artFrame then f.artFrame:Hide() end
  if f.art then f.art:SetTexture(nil) end
  if NS.Unlock and NS.Unlock.StripOverlay then NS.Unlock:StripOverlay(f) end
  -- `__frameName` is the authority, not `GetName()`: the headless stub frame answers every
  -- PascalCase call with itself, so GetName() there returns a table and would key the pool on a
  -- frame object.
  local name = f.__frameName or (f.GetName and f:GetName())
  if type(name) == "string" then pool[name] = f end
end

-- How many frames are parked in the pool. A helper rather than `#pool` because the pool is keyed by
-- frame name, so it has no array part to take a length of.
function Canvas.PooledCount()
  local n = 0
  for _ in pairs(pool) do n = n + 1 end
  return n
end

-- ── Render ──────────────────────────────────────────────────────────────────────

-- Repaint one panel by id. Cheap and targeted: the drag path and every single-field edit come
-- through here, so moving a panel does not touch the other twenty-nine.
function Canvas:Render(id)
  local rec = NS.Registry:Get(id)
  if not rec then
    -- The record is gone: retire its frame rather than leaving it on screen. This is what makes a
    -- delete visible without a full rebuild.
    if active[id] then release(active[id]); active[id] = nil end
    return nil
  end
  local spec = Canvas.BuildSpec(rec, currentSettings())
  local f = active[id]
  -- A rename changes the panel's frame NAME, and a frame's name cannot change — so the old frame is
  -- retired and the one belonging to the new name is brought in. Anything anchored to the old global
  -- name is now anchored to a hidden frame, which is the documented consequence of renaming a panel.
  if f and f.__frameName ~= spec.frameName then
    release(f)
    active[id] = nil
    f = nil
  end
  if not f then
    f = acquire(spec.frameName)
    f.__frameName = spec.frameName
    active[id] = f
  end
  f.panelID = rec.id
  applySpec(f, spec)
  if NS.Unlock and NS.Unlock.Decorate then NS.Unlock:Decorate(f, rec) end
  return f
end

-- Rebuild the whole set: render every record, and retire any frame whose record no longer exists.
-- The structural path — a create, a delete, a rename or a master-switch flip.
function Canvas:RenderAll()
  local seen = {}
  for _, rec in ipairs(NS.Registry:All()) do
    seen[rec.id] = true
    Canvas:Render(rec.id)
  end
  for id, f in pairs(active) do
    if not seen[id] then
      release(f)
      active[id] = nil
    end
  end
  NS.Debug("Canvas", "rendered %s panels", NS.Registry:Count())
end

-- The frame currently showing a given panel, or nil. Unlock mode needs it to attach drag handles;
-- the tests use it to assert that a record really produced a frame.
function Canvas:FrameFor(id)
  return active[id]
end

-- ── Bus wiring ──────────────────────────────────────────────────────────────────
-- Registered on this module's OWN AceEvent target, never on the shared bus-as-self: CallbackHandler
-- keys callbacks by (message, target), so two consumers sharing a target silently clobber each other
-- (architecture-§4).
function Canvas:Enable()
  if Canvas.__ev then return end
  local ev = NS.NewBusTarget()
  if not ev then return end
  Canvas.__ev = ev
  ev:RegisterMessage(NS.Registry.MSG_PANELS, function() Canvas:RenderAll() end)
  ev:RegisterMessage(NS.Registry.MSG_PANEL, function(_, id) Canvas:Render(id) end)
  ev:RegisterMessage("Ka0s_PanelMaster_SettingsChanged", function() Canvas:RenderAll() end)
end
