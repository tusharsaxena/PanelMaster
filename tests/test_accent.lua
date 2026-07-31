local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse, assertNear =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNear
local R, Canvas, C, Util = NS.Registry, NS.Canvas, NS.Constants, NS.Util

local function fresh()
  T.mocks.__inCombat = false
  NS.Unlock:SetUnlocked(false)
  R:DeleteAll()
  Canvas:RenderAll()
end

-- ── Defaults ────────────────────────────────────────────────────────────────────

test("Accent: ON by default \226\128\148 the accent bar is the shipped look", function()
  -- A new panel arrives as a dark block with a class-colored strip along its top, so the addon
  -- shows what it is for without the user having to go and find the switch.
  assertTrue(C.PANEL_TEMPLATE.accentEnabled)
  fresh()
  assertTrue(R:New("Fresh").accentEnabled)
end)

test("Accent: the panel's OWN border is off, so only one thing defines the edge", function()
  -- The shipped look leans on the accent bar. A panel wearing both an outline and a bar reads as
  -- busy rather than framed.
  assertEqual(C.PANEL_TEMPLATE.borderSize, 0)
end)

test("Accent: defaults to the top edge only", function()
  local edges = Util.EdgeSet(C.PANEL_TEMPLATE.accentEdges)
  assertTrue(edges.TOP)
  assertEqual(edges.BOTTOM, nil)
  assertEqual(edges.LEFT, nil)
  assertEqual(edges.RIGHT, nil)
end)

test("Accent: defaults to 5px thick, flush against the panel", function()
  assertEqual(C.PANEL_TEMPLATE.accentThickness, 5)
  -- Flush (0), so the bar reads as part of the panel's frame. A positive offset is the opt-in
  -- detached look.
  assertEqual(C.PANEL_TEMPLATE.accentOffset, 0)
end)

test("Accent: the default bar texture is one LibSharedMedia always ships", function()
  -- "Blizzard" is LSM's OWN default statusbar, so the shipped default resolves on any install
  -- rather than depending on what the user happens to have added.
  assertEqual(C.PANEL_TEMPLATE.accentTexture, "Blizzard")
end)

test("Accent: defaults to CLASS color", function()
  assertTrue(C.PANEL_TEMPLATE.accentClassColor)
end)

test("Accent: the class-color flag is wired into the generic color map", function()
  -- The whole point of C.COLOR_FIELDS: the accent bar needed no new class-color code anywhere,
  -- only this row.
  assertEqual(C.COLOR_FIELDS.accentColor, "accentClassColor")
end)

test("Accent: the bar texture selects from the statusbar pool", function()
  -- Statusbar textures are authored to read as thin strips, which is what this is — and it is the
  -- pool a user has already curated for their bars.
  assertEqual(C.PANEL_FIELD_MEDIA.accentTexture, "statusbar")
end)

test("Accent: every accent field is typed and in the dump order", function()
  local inOrder = {}
  for _, f in ipairs(C.PANEL_FIELD_ORDER) do inOrder[f] = true end
  for _, field in ipairs({ "accentEnabled", "accentEdges", "accentTexture",
                           "accentThickness", "accentOffset", "accentColor",
                           "accentClassColor",
                           "accentBorderTexture", "accentBorderSize", "accentBorderOffset",
                           "accentBorderColor", "accentBorderClassColor" }) do
    assertTrue(C.PANEL_FIELD_TYPE[field] ~= nil, field .. " has no declared type")
    assertTrue(inOrder[field], field .. " missing from PANEL_FIELD_ORDER")
  end
end)

-- ── Edge sets ───────────────────────────────────────────────────────────────────

test("Util.EdgeSet: keeps only real edges, normalized to true", function()
  local set = Util.EdgeSet({ TOP = true, MIDDLE = true, LEFT = "yes", RIGHT = false })
  assertEqual(set.TOP, true)
  assertEqual(set.LEFT, true)
  -- A hand-edited SavedVariables file cannot smuggle a fifth "edge" into the renderer's loop.
  assertEqual(set.MIDDLE, nil)
  assertEqual(set.RIGHT, nil)
end)

test("Util.EdgeSet: a non-table is the empty set, not an error", function()
  assertEqual(next(Util.EdgeSet("top")), nil)
  assertEqual(next(Util.EdgeSet(nil)), nil)
end)

test("Util.ParseEdges: reads a comma list, any casing", function()
  local set = Util.ParseEdges("top, LEFT")
  assertTrue(set.TOP)
  assertTrue(set.LEFT)
  assertEqual(set.BOTTOM, nil)
end)

test("Util.ParseEdges: 'none' is the empty set", function()
  local set = Util.ParseEdges("none")
  assertTrue(set ~= nil, "'none' should parse, not fail")
  assertEqual(next(set), nil)
end)

test("Util.ParseEdges: rejects an unknown edge rather than dropping it", function()
  -- Silently ignoring "middle" would leave the user staring at a bar that never appeared.
  assertEqual(Util.ParseEdges("top,middle"), nil)
  assertEqual(Util.ParseEdges(""), nil)
  assertEqual(Util.ParseEdges(nil), nil)
end)

test("Util.FormatEdges: always renders in the declared order", function()
  -- Built in a different order each time; pairs() order is arbitrary, so the output must not be.
  assertEqual(Util.FormatEdges({ RIGHT = true, TOP = true }), "TOP, RIGHT")
  assertEqual(Util.FormatEdges({ TOP = true, RIGHT = true }), "TOP, RIGHT")
end)

test("Util.FormatEdges: the empty set prints (none)", function()
  assertEqual(Util.FormatEdges({}), "(none)")
end)

test("Util.FormatEdges: round-trips through ParseEdges", function()
  local original = { TOP = true, BOTTOM = true, RIGHT = true }
  local reparsed = Util.ParseEdges(Util.FormatEdges(original))
  for _, edge in ipairs(C.EDGES) do
    assertEqual(reparsed[edge], original[edge], edge .. " did not round-trip")
  end
end)

-- ── Registry ────────────────────────────────────────────────────────────────────

test("Registry.Set: parses an edge list from the CLI", function()
  fresh()
  local rec = R:New("Edged")
  assertTrue((R:Set(rec.id, "accentEdges", "bottom,right")))
  local edges = R:Get(rec.id).accentEdges
  assertTrue(edges.BOTTOM)
  assertTrue(edges.RIGHT)
  assertEqual(edges.TOP, nil)
end)

test("Registry.Set: an unknown edge is refused with the valid list", function()
  fresh()
  local rec = R:New("Edged")
  local ok, err = R:Set(rec.id, "accentEdges", "top,middle")
  assertFalse(ok)
  assertTrue(err:find("top", 1, true) ~= nil, "the error should list the valid edges")
end)

test("Registry.Set: an edge set is copied, not aliased", function()
  fresh()
  local rec = R:New("Edged")
  local mine = { TOP = true }
  R:Set(rec.id, "accentEdges", mine)
  mine.BOTTOM = true
  -- A stored alias would let a caller mutate the set behind the registry's back, skipping the
  -- write seam and the repaint entirely.
  assertEqual(R:Get(rec.id).accentEdges.BOTTOM, nil)
end)

test("Registry.Sanitize: an EMPTY edge set is preserved, not repopulated", function()
  -- Unticking every edge is a legitimate state. Defaulting it back to TOP would fight the user.
  local rec = R.Sanitize({ accentEdges = {} })
  assertEqual(next(rec.accentEdges), nil)
end)

test("Registry.Sanitize: a non-table edge set falls back to the template's", function()
  local rec = R.Sanitize({ accentEdges = "top" })
  assertTrue(rec.accentEdges.TOP)
end)

test("Registry.Sanitize: clamps thickness and offset", function()
  local rec = R.Sanitize({ accentThickness = 999, accentOffset = -999 })
  assertEqual(rec.accentThickness, C.MAX_ACCENT_THICKNESS)
  assertEqual(rec.accentOffset, C.MIN_ACCENT_OFFSET)
end)

test("Registry.Sanitize: thickness has a floor of 1, not 0", function()
  -- "No bar" is what the enable switch and the edge set are for; a 0px bar would be an invisible
  -- third way of saying it.
  assertEqual(R.Sanitize({ accentThickness = 0 }).accentThickness, C.MIN_ACCENT_THICKNESS)
end)

test("Registry.FormatField: renders an edge set readably", function()
  fresh()
  local rec = R:New("Edged")
  assertEqual(R.FormatField(rec, "accentEdges"), "TOP")
  R:Set(rec.id, "accentEdges", "none")
  assertEqual(R.FormatField(R:Get(rec.id), "accentEdges"), "(none)")
end)

test("Registry.Reset: puts the accent bar back to the shipped defaults", function()
  fresh()
  local rec = R:New("Accented")
  R:Set(rec.id, "accentEnabled", false)
  R:Set(rec.id, "accentEdges", "bottom")
  R:Set(rec.id, "accentThickness", 12)
  R:Reset(rec.id)
  local after = R:Get(rec.id)
  assertTrue(after.accentEnabled)
  assertTrue(after.accentEdges.TOP)
  assertEqual(after.accentThickness, C.PANEL_TEMPLATE.accentThickness)
end)

-- ── Spec ────────────────────────────────────────────────────────────────────────

test("Canvas.BuildSpec: carries the accent settings", function()
  local spec = Canvas.BuildSpec({
    accentEnabled = true, accentEdges = { LEFT = true },
    accentThickness = 5, accentOffset = 3, accentTexture = "Solid",
  }, {})
  assertTrue(spec.accent.enabled)
  assertTrue(spec.accent.edges.LEFT)
  assertEqual(spec.accent.thickness, 5)
  assertEqual(spec.accent.offset, 3)
end)

test("Canvas.BuildSpec: clamps accent thickness and offset", function()
  local spec = Canvas.BuildSpec({ accentThickness = 999, accentOffset = 999 }, {})
  assertEqual(spec.accent.thickness, C.MAX_ACCENT_THICKNESS)
  assertEqual(spec.accent.offset, C.MAX_ACCENT_OFFSET)
end)

test("Canvas.BuildSpec: the accent color goes through the shared resolver", function()
  local spec = Canvas.BuildSpec({
    accentColor = { 0, 0, 0, 0.5 }, accentClassColor = true,
  }, {})
  -- The mock player is a Priest (1, 1, 1); alpha is kept, as for every other color.
  assertNear(spec.accent.color[1], 1)
  assertNear(spec.accent.color[4], 0.5)
end)

test("Canvas.BuildSpec: accent class color is independent of the others", function()
  local spec = Canvas.BuildSpec({
    bgColor = { 0, 0, 0, 1 }, bgClassColor = false,
    accentColor = { 0, 0, 0, 1 }, accentClassColor = true,
  }, {})
  assertNear(spec.accent.color[1], 1)
  assertNear(spec.bg[1], 0)
end)

-- ── Render ──────────────────────────────────────────────────────────────────────

test("Canvas: no accent bar is shown when the feature is off", function()
  fresh()
  local rec = R:New("Plain")
  R:Set(rec.id, "accentEnabled", false)
  local f = Canvas:FrameFor(rec.id)
  for _, edge in ipairs(C.EDGES) do
    assertFalse(f.accents[edge]:IsShown(), edge .. " bar shown on a panel with accents off")
  end
end)

test("Canvas: enabling shows only the chosen edges", function()
  fresh()
  local rec = R:New("Accented", { accentEnabled = true, accentEdges = { TOP = true, LEFT = true } })
  local f = Canvas:FrameFor(rec.id)
  assertTrue(f.accents.TOP:IsShown())
  assertTrue(f.accents.LEFT:IsShown())
  assertFalse(f.accents.BOTTOM:IsShown())
  assertFalse(f.accents.RIGHT:IsShown())
end)

test("Canvas: all four edges at once is legal", function()
  fresh()
  local rec = R:New("Framed", { accentEnabled = true,
    accentEdges = { TOP = true, BOTTOM = true, LEFT = true, RIGHT = true } })
  local f = Canvas:FrameFor(rec.id)
  for _, edge in ipairs(C.EDGES) do
    assertTrue(f.accents[edge]:IsShown(), edge .. " bar missing")
  end
end)

test("Canvas: an empty edge set draws nothing even when enabled", function()
  fresh()
  local rec = R:New("Enabled", { accentEnabled = true })
  R:Set(rec.id, "accentEdges", "none")
  local f = Canvas:FrameFor(rec.id)
  for _, edge in ipairs(C.EDGES) do
    assertFalse(f.accents[edge]:IsShown(), edge .. " bar shown with no edges selected")
  end
end)

test("Canvas: the top bar spans the full edge and is offset outward", function()
  fresh()
  local rec = R:New("Top", { accentEnabled = true, accentThickness = 4, accentOffset = 6 })
  local tex = Canvas:FrameFor(rec.id).accents.TOP
  -- Pinned to BOTH top corners, which is what makes "covers the entirety of that edge" true by
  -- construction — the bar tracks the panel's width with no recalculation.
  assertEqual(tex:GetNumPoints(), 2)
  local p1, _, r1, x1, y1 = tex:GetPoint(1)
  local p2, _, r2 = tex:GetPoint(2)
  assertEqual(p1, "BOTTOMLEFT")
  assertEqual(r1, "TOPLEFT")
  assertEqual(p2, "BOTTOMRIGHT")
  assertEqual(r2, "TOPRIGHT")
  assertEqual(x1, 0)
  assertEqual(y1, 6, "a positive offset should push the top bar UP, away from the panel")
  assertEqual(tex:GetHeight(), 4)
end)

test("Canvas: the bottom bar is offset downward", function()
  fresh()
  local rec = R:New("Bottom", { accentEnabled = true, accentEdges = { BOTTOM = true },
                                accentOffset = 6 })
  local tex = Canvas:FrameFor(rec.id).accents.BOTTOM
  local point, _, rel, _, y = tex:GetPoint(1)
  assertEqual(point, "TOPLEFT")
  assertEqual(rel, "BOTTOMLEFT")
  assertEqual(y, -6, "a positive offset should push the bottom bar DOWN, away from the panel")
end)

test("Canvas: the left bar is vertical and offset leftward", function()
  fresh()
  local rec = R:New("Left", { accentEnabled = true, accentEdges = { LEFT = true },
                              accentThickness = 3, accentOffset = 5 })
  local tex = Canvas:FrameFor(rec.id).accents.LEFT
  local point, _, rel, x = tex:GetPoint(1)
  assertEqual(point, "TOPRIGHT")
  assertEqual(rel, "TOPLEFT")
  assertEqual(x, -5)
  -- A vertical bar takes its thickness from WIDTH, not height.
  assertEqual(tex:GetWidth(), 3)
end)

test("Canvas: the right bar is offset rightward", function()
  fresh()
  local rec = R:New("Right", { accentEnabled = true, accentEdges = { RIGHT = true },
                               accentOffset = 5 })
  local tex = Canvas:FrameFor(rec.id).accents.RIGHT
  local point, _, rel, x = tex:GetPoint(1)
  assertEqual(point, "TOPLEFT")
  assertEqual(rel, "TOPRIGHT")
  assertEqual(x, 5)
end)

test("Canvas: a negative offset pulls the bar over the panel", function()
  fresh()
  local rec = R:New("Inset", { accentEnabled = true, accentOffset = -4 })
  local _, _, _, _, y = Canvas:FrameFor(rec.id).accents.TOP:GetPoint(1)
  assertEqual(y, -4)
end)

test("Canvas: the bar is painted with the resolved color", function()
  fresh()
  local rec = R:New("Colored", { accentEnabled = true, accentClassColor = false,
                                  accentColor = { 0.15, 0.85, 0.40, 1 } })
  local c = Canvas:FrameFor(rec.id).accents.TOP.fill.__color
  assertTrue(c ~= nil, "the accent color was never applied")
  assertNear(c[1], 0.15)
  assertNear(c[2], 0.85)
end)

test("Canvas: the bar takes the class color by default", function()
  fresh()
  local rec = R:New("Classy", { accentEnabled = true })
  -- accentClassColor defaults true, so a brand-new accented panel is class-colored with no setup.
  local c = Canvas:FrameFor(rec.id).accents.TOP.fill.__color
  assertNear(c[1], 1)   -- Priest
end)

test("Canvas: the bar is re-anchored, not accumulated, on repaint", function()
  fresh()
  local rec = R:New("Repainted", { accentEnabled = true })
  R:Set(rec.id, "accentOffset", 4)
  R:Set(rec.id, "accentOffset", 8)
  -- Two anchors per bar (both corners of its edge). Without ClearAllPoints a panel repainted on
  -- every settings change would pin its bars in place.
  assertEqual(Canvas:FrameFor(rec.id).accents.TOP:GetNumPoints(), 2)
end)

test("Canvas: toggling accents off hides the bars again", function()
  fresh()
  local rec = R:New("Toggled", { accentEnabled = true })
  assertTrue(Canvas:FrameFor(rec.id).accents.TOP:IsShown())
  R:Set(rec.id, "accentEnabled", false)
  assertFalse(Canvas:FrameFor(rec.id).accents.TOP:IsShown())
end)

test("Canvas: the accent bar draws ABOVE the border", function()
  fresh()
  local rec = R:New("Stacked", { accentEnabled = true, borderSize = 4 })
  local f = Canvas:FrameFor(rec.id)
  -- Bottom-up: panel fill, then border, then accent. Left to itself a child frame merely defaults to
  -- parent + 1, which would put the border and the accent on the SAME level and leave their order to
  -- creation sequence.
  --
  -- The two offsets are read from Constants rather than written as literals: artwork interleaves
  -- with these (C.ART_FRAME_LEVEL), so the ladder is spread over six slots and the numbers move
  -- whenever a new layer is slotted in. Naming the constants means such a change fails in the ONE
  -- place that defines the ladder instead of here.
  local base = f:GetFrameLevel()
  assertEqual(f.borderFrame:GetFrameLevel(), base + C.BORDER_FRAME_LEVEL)
  assertEqual(f.accentFrame:GetFrameLevel(), base + C.ACCENT_FRAME_LEVEL)
  assertTrue(f.accentFrame:GetFrameLevel() > f.borderFrame:GetFrameLevel(),
    "the border would cover the accent bar")
end)

test("Canvas: the accent/border stacking survives a frame-level change", function()
  fresh()
  local rec = R:New("Levelled", { accentEnabled = true, borderSize = 4, level = 5 })
  local f = Canvas:FrameFor(rec.id)
  assertEqual(f.accentFrame:GetFrameLevel(), f:GetFrameLevel() + C.ACCENT_FRAME_LEVEL)
  R:Set(rec.id, "level", 20)
  -- Re-derived from the panel's own level on every repaint, not set once at creation.
  assertEqual(f.accentFrame:GetFrameLevel(), f:GetFrameLevel() + C.ACCENT_FRAME_LEVEL)
  assertTrue(f.accentFrame:GetFrameLevel() > f.borderFrame:GetFrameLevel())
end)

test("Canvas: the accent bars live on their own child frame", function()
  fresh()
  local rec = R:New("Owned", { accentEnabled = true })
  local f = Canvas:FrameFor(rec.id)
  -- Being a child of the panel is what makes the bars inherit its strata and alpha; being a
  -- SEPARATE child from the border is what lets them out-rank it.
  assertTrue(f.accentFrame ~= nil)
  assertTrue(f.accentFrame ~= f.borderFrame)
end)

-- ── The accent bar's own border ─────────────────────────────────────────────────

test("Accent border: a 1px BLACK hairline by default", function()
  -- Black rather than the panel border's gray because its job is to separate the bar from whatever
  -- is behind it: against a bright background a bare class color bleeds into the scenery, and a
  -- dark hairline restores the edge whatever the class color happens to be.
  assertEqual(C.PANEL_TEMPLATE.accentBorderSize, 1)
  assertFalse(C.PANEL_TEMPLATE.accentBorderClassColor)
  local c = C.PANEL_TEMPLATE.accentBorderColor
  assertEqual(c[1], 0)
  assertEqual(c[2], 0)
  assertEqual(c[3], 0)
  assertEqual(c[4], 1)
end)

test("Accent border: its class-color flag is wired into the generic color map", function()
  assertEqual(C.COLOR_FIELDS.accentBorderColor, "accentBorderClassColor")
end)

test("Accent border: selects from the BORDER media pool, not statusbar", function()
  assertEqual(C.PANEL_FIELD_MEDIA.accentBorderTexture, "border")
end)

test("Canvas.BuildSpec: carries the accent border settings", function()
  local spec = Canvas.BuildSpec({
    accentBorderSize = 3, accentBorderOffset = 2, accentBorderTexture = "Solid",
  }, {})
  assertEqual(spec.accent.borderSize, 3)
  assertEqual(spec.accent.borderOffset, 2)
  assertEqual(spec.accent.borderTexture, "Solid")
end)

test("Canvas.BuildSpec: clamps the accent border to the panel border's bounds", function()
  local spec = Canvas.BuildSpec({ accentBorderSize = 999, accentBorderOffset = -999 }, {})
  assertEqual(spec.accent.borderSize, C.MAX_BORDER)
  assertEqual(spec.accent.borderOffset, C.MIN_BORDER_OFFSET)
end)

test("Canvas: no border frame is built when the bar has no border", function()
  fresh()
  -- A name no other case uses, deliberately: the frame pool is keyed by frame NAME, so reusing a
  -- name whose frame once had a bar border would hand back that frame with its (hidden, cleared)
  -- border frame still attached — and the laziness this asserts would look broken when it is not.
  local rec = R:New("NeverOutlined", { accentEnabled = true, accentBorderSize = 0 })
  -- Still lazy, even though the shipped default now asks for one: a user who turns the bar border
  -- off must not be charged four frames for it.
  assertEqual(Canvas:FrameFor(rec.id).accents.TOP.borderFrame, nil)
end)

test("Canvas: the bar border is a backdrop edge at the set thickness", function()
  fresh()
  local rec = R:New("Outlined", { accentEnabled = true, accentBorderSize = 3 })
  local b = Canvas:FrameFor(rec.id).accents.TOP.borderFrame
  assertTrue(b ~= nil, "no border frame was built")
  local backdrop = b:GetBackdrop()
  assertTrue(backdrop ~= nil, "no backdrop applied to the bar border")
  assertEqual(backdrop.edgeSize, 3)
end)

test("Canvas: the bar border color is applied AFTER the backdrop", function()
  fresh()
  local rec = R:New("Colored", { accentEnabled = true, accentBorderSize = 3,
                                  accentBorderColor = { 1, 0.82, 0, 1 } })
  -- Applying a backdrop resets its border color to white, so coloring first is silently undone.
  local c = Canvas:FrameFor(rec.id).accents.TOP.borderFrame.__backdropBorderColor
  assertTrue(c ~= nil, "the bar border color was never applied")
  assertNear(c[1], 1)
  assertNear(c[2], 0.82)
end)

test("Canvas: the bar border takes the class color", function()
  fresh()
  local rec = R:New("ClassOutlined", { accentEnabled = true, accentBorderSize = 3,
                                       accentBorderColor = { 0, 0, 0, 1 },
                                       accentBorderClassColor = true })
  local c = Canvas:FrameFor(rec.id).accents.TOP.borderFrame.__backdropBorderColor
  assertNear(c[1], 1)   -- Priest
end)

test("Canvas: the bar border is offset from the bar", function()
  fresh()
  local rec = R:New("Offset", { accentEnabled = true, accentBorderSize = 2,
                                accentBorderOffset = 4 })
  local b = Canvas:FrameFor(rec.id).accents.TOP.borderFrame
  local _, _, _, x, y = b:GetPoint(1)
  assertEqual(x, -4)
  assertEqual(y, 4)
end)

test("Canvas: dropping the bar border to zero clears it", function()
  fresh()
  local rec = R:New("Shrinking", { accentEnabled = true, accentBorderSize = 3 })
  assertTrue(Canvas:FrameFor(rec.id).accents.TOP.borderFrame:GetBackdrop() ~= nil)
  R:Set(rec.id, "accentBorderSize", 0)
  local b = Canvas:FrameFor(rec.id).accents.TOP.borderFrame
  assertEqual(b:GetBackdrop(), nil, "a stale bar-border backdrop was left behind")
  assertFalse(b:IsShown())
end)

test("Canvas: a 'None' bar border texture removes it", function()
  fresh()
  local rec = R:New("NoneOutlined", { accentEnabled = true, accentBorderSize = 6,
                                      accentBorderTexture = C.NONE_MEDIA_NAME })
  assertEqual(Canvas:FrameFor(rec.id).accents.TOP.borderFrame, nil)
end)

test("Registry.Reset: puts the bar border back to the shipped hairline", function()
  fresh()
  local rec = R:New("Outlined", { accentEnabled = true })
  R:Set(rec.id, "accentBorderSize", 8)
  R:Reset(rec.id)
  assertEqual(R:Get(rec.id).accentBorderSize, 1)
end)

test("Canvas: a released frame hides its accent bars", function()
  fresh()
  local rec = R:New("Transient", { accentEnabled = true })
  local f = Canvas:FrameFor(rec.id)
  R:Delete(rec.id)
  -- The bars are anchored OUTSIDE the panel's bounds, so a pooled frame that kept them would leave
  -- colored strips floating where the panel used to be.
  for _, edge in ipairs(C.EDGES) do
    assertFalse(f.accents[edge]:IsShown(), edge .. " bar survived the panel")
  end
end)

-- ── Texture orientation ─────────────────────────────────────────────────────────

test("Canvas: a vertical bar rotates its texture 90 degrees", function()
  fresh()
  -- A statusbar texture is authored as a HORIZONTAL bar: the bevel runs across its height. Stretched
  -- into a tall thin LEFT/RIGHT bar unrotated, that bevel runs along the bar's LENGTH instead of
  -- across its thickness, which reads as a smear rather than an edge.
  local rec = R:New("Sided", { accentEnabled = true,
                               accentEdges = { LEFT = true, RIGHT = true } })
  local f = Canvas:FrameFor(rec.id)
  for _, edge in ipairs({ "LEFT", "RIGHT" }) do
    local got = f.accents[edge].fill.__texCoord
    assertTrue(got ~= nil, edge .. " bar never set a texcoord")
    for i = 1, 8 do
      assertEqual(got[i], C.ACCENT_TEXCOORD_ROT90[i],
        edge .. " bar texcoord differs at index " .. i)
    end
  end
end)

test("Canvas: a horizontal bar draws its texture as authored", function()
  fresh()
  -- The rotation is for the vertical edges only. TOP and BOTTOM already run along the texture's own
  -- axis, so rotating them would introduce exactly the defect it fixes on the other two.
  local rec = R:New("Capped", { accentEnabled = true,
                                accentEdges = { TOP = true, BOTTOM = true } })
  local f = Canvas:FrameFor(rec.id)
  for _, edge in ipairs({ "TOP", "BOTTOM" }) do
    local got = f.accents[edge].fill.__texCoord
    assertTrue(got ~= nil, edge .. " bar never set a texcoord")
    for i = 1, 8 do
      assertEqual(got[i], C.ACCENT_TEXCOORD_FLAT[i],
        edge .. " bar texcoord differs at index " .. i)
    end
  end
end)

test("Canvas: the orientation is re-applied on every repaint, not just the first", function()
  fresh()
  -- SetTexture resets a texture's coords on a live client, so the rotation has to follow it every
  -- time. A pooled frame reused for a different panel would otherwise draw the bar unrotated.
  local rec = R:New("Repainted", { accentEnabled = true, accentEdges = { LEFT = true } })
  local fill = Canvas:FrameFor(rec.id).accents.LEFT.fill
  fill.__texCoord = nil
  R:Set(rec.id, "accentThickness", 9)
  assertTrue(fill.__texCoord ~= nil, "the rotation was not re-applied on repaint")
  assertEqual(fill.__texCoord[2], C.ACCENT_TEXCOORD_ROT90[2])
end)
