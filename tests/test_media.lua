local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse, assertNear =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNear
local R, Canvas, C, Util = NS.Registry, NS.Canvas, NS.Constants, NS.Util

-- Every case starts from an empty registry AND a locked screen: the suites share one addon
-- environment, and an unlock left on by an earlier suite would hold every panel at full alpha and
-- mouse-enabled, quietly invalidating each mouseover assertion below.
local function fresh()
  T.mocks.__inCombat = false
  NS.Unlock:SetUnlocked(false)
  R:DeleteAll()
  Canvas:RenderAll()
end

-- ── Slugs and the deterministic frame name ──────────────────────────────────────

test("Util.Slugify: keeps alphanumerics and collapses everything else", function()
  assertEqual(Util.Slugify("Chat BG"), "Chat_BG")
  assertEqual(Util.Slugify("Chat-BG"), "Chat_BG")
  assertEqual(Util.Slugify("Chat   BG!!!"), "Chat_BG")
end)

test("Util.Slugify: trims leading and trailing separators", function()
  assertEqual(Util.Slugify("  Chat BG  "), "Chat_BG")
  assertEqual(Util.Slugify("!!Chat!!"), "Chat")
end)

test("Util.Slugify: preserves case", function()
  -- Frame names are case-sensitive, and PanelMaster_Panel_ChatBG reads better than _chatbg. Two
  -- names differing only in case can never coexist — the registry rejects them as duplicates.
  assertEqual(Util.Slugify("ChatBG"), "ChatBG")
end)

test("Util.Slugify: a name with no alphanumerics falls back rather than slugging to empty", function()
  -- An empty slug would give every such panel the bare prefix as its frame name.
  assertEqual(Util.Slugify("!!!"), "Panel")
  assertEqual(Util.Slugify(""), "Panel")
end)

test("Util.Slugify: is deterministic", function()
  -- The whole contract: another addon works the frame name out from the panel name, so the same
  -- input must always give the same output.
  for _ = 1, 3 do assertEqual(Util.Slugify("Unit Frames 2"), "Unit_Frames_2") end
end)

test("Util.FrameName: prefixes the slug", function()
  assertEqual(Util.FrameName("Chat BG"), "PanelMaster_Panel_Chat_BG")
end)

test("Registry.FrameName: matches Util.FrameName for a record", function()
  fresh()
  local rec = R:New("Action Bars")
  assertEqual(R.FrameName(rec), "PanelMaster_Panel_Action_Bars")
end)

test("Registry.FrameName: is stamped onto the record at create, not derived on every read", function()
  fresh()
  local rec = R:New("Action Bars")
  -- Stored, so it can survive a rename. That is the whole difference between this build and the one
  -- where renaming orphaned every external anchor.
  assertEqual(rec.frameName, "PanelMaster_Panel_Action_Bars")
end)

test("Registry.FrameName: derives one for a record that predates the stored field", function()
  fresh()
  local rec = R:New("Legacy")
  rec.frameName = nil   -- a record written by a build before frame names were stored
  -- The fallback must reproduce EXACTLY what the old build rendered that panel's frame as, or an
  -- upgrade would move somebody's anchors.
  assertEqual(R.FrameName(rec), "PanelMaster_Panel_Legacy")
  R.Sanitize(rec)
  assertEqual(rec.frameName, "PanelMaster_Panel_Legacy", "Sanitize left the record unstamped")
end)

test("Registry.New: refuses a name whose frame name a RENAMED panel still carries", function()
  fresh()
  local rec = R:New("Alpha")           -- born as PanelMaster_Panel_Alpha
  R:Rename(rec.id, "Beta")             -- keeps that frame name
  -- The name "Alpha" is free again, but its frame name is not — and two frames cannot share a
  -- global. Refusing is the honest answer; the message has to name the panel actually holding it.
  local made, err = R:New("Alpha")
  assertEqual(made, nil)
  assertTrue(err:find("frame name", 1, true) ~= nil)
  assertTrue(err:find("Beta", 1, true) ~= nil, "the error should name the holder: " .. tostring(err))
end)

test("Canvas: the frame is created under its deterministic global name", function()
  fresh()
  local rec = R:New("Chat BG")
  local f = Canvas:FrameFor(rec.id)
  -- This is the public anchor contract: another addon does
  -- SetPoint("TOPLEFT", "PanelMaster_Panel_Chat_BG", ...).
  assertEqual(f:GetName(), "PanelMaster_Panel_Chat_BG")
end)

test("Registry.New: refuses a name whose slug collides with an existing panel", function()
  fresh()
  R:New("Chat BG")
  local rec, err = R:New("Chat-BG")
  -- Two legal, distinct names that slugify to one frame name. Two frames cannot share a global
  -- name, so the second would steal the first's and break anything anchored to it.
  assertEqual(rec, nil)
  assertTrue(err:find("frame name", 1, true) ~= nil, "the error should explain why")
  assertTrue(err:find("PanelMaster_Panel_Chat_BG", 1, true) ~= nil)
end)

test("Registry.Rename: does NOT refuse a slug collision, because renaming claims no frame name",
  function()
    fresh()
    R:New("Chat BG")
    local bars = R:New("Bars")
    -- "Chat.BG" slugs to the frame name "Chat BG" already carries — which used to be refused,
    -- because the rename would have gone on to claim that global. It no longer does: the frame name
    -- is stamped at create, so this panel keeps PanelMaster_Panel_Bars whatever it is called.
    assertTrue((R:Rename("Bars", "Chat.BG")))
    assertEqual(R.FrameName(R:Get(bars.id)), "PanelMaster_Panel_Bars")
  end)

test("Registry.Rename: a panel may still be renamed to its own slug", function()
  fresh()
  R:New("Chat BG")
  assertTrue((R:Rename("Chat BG", "Chat-BG")))
end)

test("Registry.Rename: keeps the panel on the frame it already had", function()
  fresh()
  local rec = R:New("Before")
  local old = Canvas:FrameFor(rec.id)
  local frameName = R.FrameName(rec)
  R:Rename(rec.id, "After")
  local new = Canvas:FrameFor(rec.id)

  -- The fix for #7. A frame's name cannot change, so deriving the frame name from the panel name
  -- meant a rename had to swap frames and silently orphan every external anchor. The frame name is
  -- identity now, so the rename is a relabel: same frame, same global, anchors intact.
  assertTrue(new == old, "the rename swapped the panel onto a different frame")
  assertEqual(new:GetName(), frameName)
  assertEqual(R.FrameName(R:Get(rec.id)), "PanelMaster_Panel_Before")
  assertEqual(R:Get(rec.id).name, "After")
  assertTrue(new:IsShown(), "the panel's frame was retired by its own rename")
end)

test("Canvas: renaming a panel N times leaves no abandoned frames", function()
  fresh()
  local before = Canvas.PooledCount()
  local rec = R:New("Churn 0")
  -- The fix for #6. Each of these used to retire a frame into the pool under the name it was born
  -- with, never to be claimed again — one permanently-live frame per distinct name typed.
  for i = 1, 5 do
    assertTrue((R:Rename(rec.id, "Churn " .. i)))
  end
  assertEqual(Canvas.PooledCount(), before, "renaming abandoned frames into the pool")
  assertEqual(Canvas:FrameFor(rec.id):GetName(), "PanelMaster_Panel_Churn_0")
end)

-- ── LibSharedMedia textures ─────────────────────────────────────────────────────

test("Constants: new panels default to the solid texture on both surfaces", function()
  assertEqual(C.PANEL_TEMPLATE.bgTexture, C.SOLID_MEDIA_NAME)
  assertEqual(C.PANEL_TEMPLATE.borderTexture, C.SOLID_MEDIA_NAME)
end)

test("Constants: both media fields declare their LSM media type", function()
  for field, kind in pairs(C.PANEL_FIELD_TYPE) do
    if kind == "media" then
      assertTrue(C.PANEL_FIELD_MEDIA[field] ~= nil, field .. " has no LSM media type")
    end
  end
end)

test("Canvas.BuildSpec: carries both texture names", function()
  local spec = Canvas.BuildSpec({ bgTexture = "Blizzard Marble", borderTexture = "Blizzard Dialog" },
    {})
  assertEqual(spec.bgTexture, "Blizzard Marble")
  assertEqual(spec.borderTexture, "Blizzard Dialog")
end)

test("Canvas.BuildSpec: a missing texture name falls back to the template's", function()
  local spec = Canvas.BuildSpec({}, {})
  assertEqual(spec.bgTexture, C.SOLID_MEDIA_NAME)
end)

test("Canvas: the background is drawn with the resolved texture path", function()
  fresh()
  local rec = R:New("Textured")
  local f = Canvas:FrameFor(rec.id)
  -- LSM is absent headlessly, so every name resolves to the built-in flat white — which is the
  -- point: the panel still renders.
  assertEqual(f.bg:GetTexture(), C.SOLID_TEXTURE)
end)

test("Canvas: the border is drawn as a backdrop edge, at the set thickness", function()
  fresh()
  local rec = R:New("Bordered", { borderSize = 4 })
  local backdrop = Canvas:FrameFor(rec.id).borderFrame:GetBackdrop()
  -- An edge FILE, not four flat textures: that is what lets any LSM border texture be used.
  assertTrue(backdrop ~= nil, "no backdrop was applied")
  assertEqual(backdrop.edgeSize, 4)
  assertEqual(backdrop.edgeFile, C.SOLID_TEXTURE)
end)

test("Canvas: the border color is applied AFTER the backdrop", function()
  fresh()
  local rec = R:New("Colored", { borderSize = 4, borderColor = { 1, 0.82, 0, 1 } })
  local b = Canvas:FrameFor(rec.id).borderFrame
  -- Applying a backdrop resets its border color to white, so coloring first is silently undone.
  -- The recorded color proves SetBackdropBorderColor ran, and ran second.
  local c = b.__backdropBorderColor
  assertTrue(c ~= nil, "the border color was never applied")
  assertNear(c[1], 1)
  assertNear(c[2], 0.82)
  assertNear(c[3], 0)
end)

test("Canvas: the border picks up a color change", function()
  fresh()
  local rec = R:New("Recolored", { borderSize = 4 })
  R:Set(rec.id, "borderColor", { 0, 1, 0, 1 })
  local c = Canvas:FrameFor(rec.id).borderFrame.__backdropBorderColor
  assertNear(c[2], 1)
  assertNear(c[1], 0)
end)

test("Canvas: the border takes the class color too", function()
  fresh()
  local rec = R:New("ClassBordered", { borderSize = 4, borderColor = { 0, 0, 0, 1 } })
  R:Set(rec.id, "borderClassColor", true)
  local c = Canvas:FrameFor(rec.id).borderFrame.__backdropBorderColor
  assertNear(c[1], 1)   -- the mock player is a Priest: 1, 1, 1
end)

test("Canvas: a zero border applies no backdrop at all", function()
  fresh()
  local rec = R:New("Borderless", { borderSize = 0 })
  -- Not a backdrop drawn at zero size — no backdrop, so there is nothing to draw.
  local b = Canvas:FrameFor(rec.id).borderFrame
  assertEqual(b:GetBackdrop(), nil)
  assertFalse(b:IsShown())
end)

test("Canvas: the 'None' border texture removes the border", function()
  fresh()
  local rec = R:New("NoneBordered", { borderSize = 8, borderTexture = C.NONE_MEDIA_NAME })
  -- Distinct from a zero thickness: the user picked a texture that explicitly means "draw nothing".
  assertEqual(Canvas:FrameFor(rec.id).borderFrame:GetBackdrop(), nil)
end)

test("Canvas: dropping the border to zero clears an existing backdrop", function()
  fresh()
  local rec = R:New("Shrinking", { borderSize = 4 })
  assertTrue(Canvas:FrameFor(rec.id).borderFrame:GetBackdrop() ~= nil)
  R:Set(rec.id, "borderSize", 0)
  assertEqual(Canvas:FrameFor(rec.id).borderFrame:GetBackdrop(), nil,
    "a stale backdrop was left behind")
end)

-- ── Border offset ───────────────────────────────────────────────────────────────

test("Canvas.BuildSpec: carries the border offset", function()
  assertEqual(Canvas.BuildSpec({ borderOffset = 6 }, {}).borderOffset, 6)
  assertEqual(Canvas.BuildSpec({}, {}).borderOffset, 0)
end)

test("Canvas.BuildSpec: clamps the border offset", function()
  assertEqual(Canvas.BuildSpec({ borderOffset = 9999 }, {}).borderOffset, C.MAX_BORDER_OFFSET)
  assertEqual(Canvas.BuildSpec({ borderOffset = -9999 }, {}).borderOffset, C.MIN_BORDER_OFFSET)
end)

test("Canvas: a positive border offset pushes the border outward", function()
  fresh()
  local rec = R:New("Haloed", { borderSize = 2, borderOffset = 5 })
  local b = Canvas:FrameFor(rec.id).borderFrame
  local _, _, _, x, y = b:GetPoint(1)
  -- TOPLEFT moves up and left by the offset, so the border sits outside the panel's bounds.
  assertEqual(x, -5)
  assertEqual(y, 5)
end)

test("Canvas: a negative border offset pulls the border inward", function()
  fresh()
  local rec = R:New("Inset", { borderSize = 2, borderOffset = -4 })
  local b = Canvas:FrameFor(rec.id).borderFrame
  local _, _, _, x, y = b:GetPoint(1)
  assertEqual(x, 4)
  assertEqual(y, -4)
end)

test("Canvas: a zero border offset sits exactly on the panel edge", function()
  fresh()
  local rec = R:New("Flush", { borderSize = 2, borderOffset = 0 })
  local b = Canvas:FrameFor(rec.id).borderFrame
  local _, _, _, x, y = b:GetPoint(1)
  assertEqual(x, 0)
  assertEqual(y, 0)
end)

test("Canvas: the border frame is re-anchored, not accumulated, on repaint", function()
  fresh()
  local rec = R:New("Repainted", { borderSize = 2 })
  R:Set(rec.id, "borderOffset", 4)
  R:Set(rec.id, "borderOffset", 8)
  -- Two SetPoints per apply (TOPLEFT + BOTTOMRIGHT), and ClearAllPoints before them — so a panel
  -- repainted on every settings change must not collect anchors until the border is pinned.
  assertEqual(Canvas:FrameFor(rec.id).borderFrame:GetNumPoints(), 2)
end)

test("Registry.Sanitize: clamps the border offset", function()
  assertEqual(R.Sanitize({ borderOffset = 500 }).borderOffset, C.MAX_BORDER_OFFSET)
  assertEqual(R.Sanitize({ borderOffset = "nonsense" }).borderOffset, 0)
end)

-- ── Per-panel reset ─────────────────────────────────────────────────────────────

test("Registry.Reset: restores every appearance field to the template", function()
  fresh()
  local rec = R:New("Configured", {
    width = 500, height = 400, borderSize = 9, borderOffset = 7,
    bgTexture = "None", mouseover = true, mouseoverAlpha = 0.3,
  })
  assertTrue((R:Reset(rec.id)))
  local after = R:Get(rec.id)
  assertEqual(after.width, C.PANEL_TEMPLATE.width)
  assertEqual(after.height, C.PANEL_TEMPLATE.height)
  assertEqual(after.borderSize, C.PANEL_TEMPLATE.borderSize)
  assertEqual(after.borderOffset, C.PANEL_TEMPLATE.borderOffset)
  assertEqual(after.bgTexture, C.PANEL_TEMPLATE.bgTexture)
  assertFalse(after.mouseover)
end)

test("Registry.Reset: restores position and anchor too", function()
  fresh()
  local rec = R:New("Moved", { x = 400, y = -300, point = "BOTTOMRIGHT" })
  R:Reset(rec.id)
  local after = R:Get(rec.id)
  -- A partial reset that left the panel where it was would be a fuzzier promise, and the user would
  -- have to work out which half "reset" covered.
  assertEqual(after.x, 0)
  assertEqual(after.y, 0)
  assertEqual(after.point, "CENTER")
end)

test("Registry.Reset: keeps the panel's id and name", function()
  fresh()
  local rec = R:New("Keep My Name", { width = 900 })
  local frameName = R.FrameName(rec)
  R:Reset(rec.id)
  local after = R:Get(rec.id)
  assertEqual(after.id, rec.id)
  assertEqual(after.name, "Keep My Name")
  -- Identity must survive, or a reset would silently rename the frame and break every external
  -- anchor pointed at it.
  assertEqual(R.FrameName(after), frameName)
end)

test("Registry.Reset: applies the profile's New-Panel-Defaults, like New does", function()
  fresh()
  NS.db.profile.settings.defaultStrata = "MEDIUM"
  NS.db.profile.settings.defaultAlpha = 0.4
  local rec = R:New("Defaulted")
  R:Set(rec.id, "strata", "TOOLTIP")
  R:Reset(rec.id)
  local after = R:Get(rec.id)
  -- "Reset" and "make a new one" must land on the same state, or the two drift the moment a user
  -- changes their defaults.
  assertEqual(after.strata, "MEDIUM")
  assertNear(after.alpha, 0.4)
  NS.db.profile.settings.defaultStrata = "LOW"
  NS.db.profile.settings.defaultAlpha = 1.0
end)

test("Registry.Reset: clears class-color flags", function()
  fresh()
  local rec = R:New("Classy")
  R:Set(rec.id, "bgClassColor", true)
  R:Set(rec.id, "borderClassColor", true)
  R:Reset(rec.id)
  local after = R:Get(rec.id)
  assertFalse(after.bgClassColor)
  assertFalse(after.borderClassColor)
end)

test("Registry.Reset: does not alias the shared template", function()
  fresh()
  local a = R:New("A")
  R:Reset(a.id)
  R:Get(a.id).bgColor[1] = 0.99
  local b = R:New("B")
  -- A reset that copied the template by reference would let one panel's later edit rewrite the
  -- shipped default for every panel made afterwards.
  assertNear(b.bgColor[1], C.PANEL_TEMPLATE.bgColor[1])
end)

test("Registry.Reset: repaints the panel", function()
  fresh()
  local rec = R:New("Repainted", { width = 800 })
  R:Reset(rec.id)
  assertEqual(Canvas:FrameFor(rec.id):GetWidth(), C.PANEL_TEMPLATE.width)
end)

test("Registry.Reset: an unknown panel is an error, not a silent no-op", function()
  fresh()
  local ok, err = R:Reset("Ghost")
  assertFalse(ok)
  assertTrue(err:find("no panel", 1, true) ~= nil)
end)

test("Registry.Reset: leaves other panels alone", function()
  fresh()
  local one = R:New("One", { width = 700 })
  local two = R:New("Two", { width = 900 })
  R:Reset(one.id)
  assertEqual(R:Get(two.id).width, 900)
end)

-- ── Class color vs a picked color: identical apart from RGB ───────────────────
-- Raised as "the border looks less well defined in class-color mode". It is not: both paths go
-- through Util.ResolveColor and produce the same backdrop, the same edge size, the same alpha and
-- the same anchoring. These pin that, so a future change cannot quietly introduce the asymmetry
-- that was suspected.

test("Border: class color and a picked color produce the same backdrop", function()
  fresh()
  local picked = R:New("Picked", { borderSize = 1, borderColor = { 0, 1, 0, 1 },
                                   borderClassColor = false })
  local classy = R:New("Classy", { borderSize = 1, borderColor = { 0, 1, 0, 1 },
                                   borderClassColor = true })
  local a = Canvas:FrameFor(picked.id).borderFrame
  local b = Canvas:FrameFor(classy.id).borderFrame

  assertEqual(a:GetBackdrop().edgeFile, b:GetBackdrop().edgeFile, "different edge texture")
  assertEqual(a:GetBackdrop().edgeSize, b:GetBackdrop().edgeSize, "different edge size")
  assertEqual(a:GetNumPoints(), b:GetNumPoints(), "different anchoring")
end)

test("Border: class color preserves the picked color's ALPHA exactly", function()
  fresh()
  -- The half of the color a class color does NOT override. If this drifted, a class-colored
  -- border really would render fainter than a picked one — which is the defect that was suspected.
  local picked = R:New("Picked", { borderSize = 1, borderColor = { 0, 1, 0, 0.6 },
                                   borderClassColor = false })
  local classy = R:New("Classy", { borderSize = 1, borderColor = { 0, 1, 0, 0.6 },
                                   borderClassColor = true })
  local a = Canvas:FrameFor(picked.id).borderFrame.__backdropBorderColor
  local b = Canvas:FrameFor(classy.id).borderFrame.__backdropBorderColor
  assertNear(a[4], 0.6)
  assertNear(b[4], 0.6, 1e-6, "the class-colored border lost the stored alpha")
end)

test("Border: only the RGB differs between the two modes", function()
  fresh()
  local rec = R:New("Toggling", { borderSize = 1, borderColor = { 0, 1, 0, 1 } })
  local before = Canvas:FrameFor(rec.id).borderFrame.__backdropBorderColor
  local pickedAlpha = before[4]
  R:Set(rec.id, "borderClassColor", true)
  local after = Canvas:FrameFor(rec.id).borderFrame.__backdropBorderColor
  assertNear(after[4], pickedAlpha, 1e-6, "toggling class color changed the alpha")
  -- The mock player is a Priest (1,1,1), so the RGB does change — that is the whole point.
  assertNear(after[1], 1)
end)

test("Accent bar: class color likewise preserves alpha", function()
  fresh()
  local rec = R:New("Accented", { accentEnabled = true,
                                  accentColor = { 0, 1, 0, 0.4 }, accentClassColor = true })
  local c = Canvas:FrameFor(rec.id).accents.TOP.fill.__color
  assertNear(c[4], 0.4)
end)

-- ── Background color actually reaches the frame ────────────────────────────────

test("Canvas: the background color is applied to the fill texture", function()
  fresh()
  local rec = R:New("Filled", { bgColor = { 0.2, 0.9, 0.3, 0.75 } })
  local c = Canvas:FrameFor(rec.id).bg.__color
  assertTrue(c ~= nil, "the background color was never applied")
  assertNear(c[1], 0.2)
  assertNear(c[2], 0.9)
  assertNear(c[4], 0.75)
end)

test("Canvas: the background picks up a color change", function()
  fresh()
  local rec = R:New("Repainted")
  R:Set(rec.id, "bgColor", { 1, 0, 0, 1 })
  local c = Canvas:FrameFor(rec.id).bg.__color
  assertNear(c[1], 1)
  assertNear(c[2], 0)
end)

test("Registry.Set: a media name is matched case-insensitively against the live list", function()
  fresh()
  local rec = R:New("Media")
  assertTrue((R:Set(rec.id, "bgTexture", "solid")))
  assertEqual(R:Get(rec.id).bgTexture, C.SOLID_MEDIA_NAME, "the stored name was not normalized")
end)

test("Registry.Set: an unknown media name is refused with the available list", function()
  fresh()
  local rec = R:New("Media")
  local ok, err = R:Set(rec.id, "bgTexture", "Not A Texture")
  assertFalse(ok)
  assertTrue(err:find("Available", 1, true) ~= nil)
end)

test("Registry.Sanitize: does NOT rewrite an unresolvable texture name", function()
  -- An addon that registers a texture may load after this one, so a name that resolves to nothing
  -- right now can be valid a second later. The user's choice stays in the file; Compat.FetchMedia
  -- degrades at render time instead.
  local rec = R.Sanitize({ bgTexture = "Some Other Addon's Texture" })
  assertEqual(rec.bgTexture, "Some Other Addon's Texture")
end)

test("Registry.Sanitize: an empty or non-string texture falls back to the default", function()
  assertEqual(R.Sanitize({ bgTexture = "" }).bgTexture, C.SOLID_MEDIA_NAME)
  assertEqual(R.Sanitize({ borderTexture = 42 }).borderTexture, C.SOLID_MEDIA_NAME)
end)

-- ── Class color ────────────────────────────────────────────────────────────────

test("Constants: every class-color flag names a real color field", function()
  for colorField, flag in pairs(C.COLOR_FIELDS) do
    assertEqual(C.PANEL_FIELD_TYPE[colorField], "color", colorField .. " is not a color field")
    assertEqual(C.PANEL_FIELD_TYPE[flag], "boolean", flag .. " is not a boolean field")
    assertTrue(C.PANEL_TEMPLATE[flag] ~= nil, flag .. " is missing from the template")
  end
end)

test("Util.ResolveColor: returns the stored color when the flag is off", function()
  local rec = { bgColor = { 0.2, 0.3, 0.4, 0.5 }, bgClassColor = false }
  local c = Util.ResolveColor(rec, "bgColor")
  assertNear(c[1], 0.2)
  assertNear(c[4], 0.5)
end)

test("Util.ResolveColor: the class color replaces RGB but keeps the stored alpha", function()
  -- "Class colored" is a statement about hue, not about how see-through the user wanted it.
  local rec = { bgColor = { 0.2, 0.3, 0.4, 0.5 }, bgClassColor = true }
  local c = Util.ResolveColor(rec, "bgColor")
  assertNear(c[1], 1)      -- the mock player is a Priest: 1, 1, 1
  assertNear(c[2], 1)
  assertNear(c[4], 0.5, 1e-6, "the stored alpha was overwritten")
end)

test("Util.ResolveColor: falls back to the stored color when the class is unknown", function()
  -- LibKa0s-Core-1.0 memoizes the PLAYER's answer ON SUCCESS, so the memo is dropped through the
  -- library's own suite seam before the class is made unresolvable. Without that this case reads a
  -- cached Priest, passes, and proves nothing at all about the fallback.
  local saved = T.mocks.UnitClass
  T.mocks.UnitClass = function() return "Tinker", "TINKER", 99 end
  NS.Core.__ResetClassColor()
  local c = Util.ResolveColor({ bgColor = { 0.2, 0.3, 0.4, 1 }, bgClassColor = true }, "bgColor")
  T.mocks.UnitClass = saved
  NS.Core.__ResetClassColor()
  -- Never a white panel: an unresolvable class color keeps what the user picked.
  assertNear(c[1], 0.2)
end)

test("Util.ResolveColor: a color with no class-color companion is returned as stored", function()
  local c = Util.ResolveColor({ someColor = { 0.1, 0.2, 0.3, 1 } }, "someColor")
  assertNear(c[1], 0.1)
end)

test("Canvas.BuildSpec: applies the class color to the background", function()
  local spec = Canvas.BuildSpec({ bgColor = { 0, 0, 0, 0.5 }, bgClassColor = true }, {})
  assertNear(spec.bg[1], 1)
  assertNear(spec.bg[4], 0.5)
end)

test("Canvas.BuildSpec: applies the class color to the border independently", function()
  local spec = Canvas.BuildSpec({
    bgColor = { 0, 0, 0, 1 }, bgClassColor = false,
    borderColor = { 0, 0, 0, 1 }, borderClassColor = true,
  }, {})
  -- The two flags are separate: class-coloring the border must not drag the background with it.
  assertNear(spec.bg[1], 0)
  assertNear(spec.border[1], 1)
end)

test("Registry.Set: the class-color flags coerce from the CLI", function()
  fresh()
  local rec = R:New("Classy")
  assertTrue((R:Set(rec.id, "bgClassColor", "on")))
  assertTrue(R:Get(rec.id).bgClassColor)
end)

test("Registry.Sanitize: class-color flags are always booleans", function()
  local rec = R.Sanitize({ bgClassColor = "yes", borderClassColor = nil })
  assertEqual(rec.bgClassColor, true)
  assertEqual(rec.borderClassColor, false)
end)

-- ── Mouseover ───────────────────────────────────────────────────────────────────

test("Canvas.BuildSpec: mouseover off means the resting alpha IS the alpha", function()
  local spec = Canvas.BuildSpec({ alpha = 0.8, mouseover = false, mouseoverAlpha = 0.1 }, {})
  assertNear(spec.mouseoverAlpha, 0.8)
end)

test("Canvas.BuildSpec: mouseover on carries the faded resting alpha", function()
  local spec = Canvas.BuildSpec({ alpha = 0.8, mouseover = true, mouseoverAlpha = 0.1 }, {})
  assertNear(spec.alpha, 0.8)
  assertNear(spec.mouseoverAlpha, 0.1)
end)

test("Canvas.BuildSpec: a faded alpha above the hover alpha is clamped down", function()
  -- Otherwise the panel would FADE when moused over, which is not what the setting says it does.
  local spec = Canvas.BuildSpec({ alpha = 0.4, mouseover = true, mouseoverAlpha = 0.9 }, {})
  assertNear(spec.mouseoverAlpha, 0.4)
end)

test("Canvas: a mouseover panel rests at its faded alpha", function()
  fresh()
  local rec = R:New("Fader", { mouseover = true, mouseoverAlpha = 0.2, alpha = 1 })
  assertNear(Canvas:FrameFor(rec.id):GetAlpha(), 0.2)
end)

test("Canvas: a mouseover panel rises to full alpha under the cursor", function()
  fresh()
  local rec = R:New("Fader", { mouseover = true, mouseoverAlpha = 0.2, alpha = 1 })
  local f = Canvas:FrameFor(rec.id)
  T.mocks.__mouseIsOver = f
  Canvas.__updateMouseover()
  assertNear(f:GetAlpha(), 1)
  T.mocks.__mouseIsOver = nil
  Canvas.__updateMouseover()
  assertNear(f:GetAlpha(), 0.2)
end)

test("Canvas: a mouseover panel never takes mouse input", function()
  fresh()
  local rec = R:New("Fader", { mouseover = true })
  -- The fade is polled precisely so the panel can stay click-through. Enabling mouse for OnEnter
  -- would break the one guarantee a backdrop cannot break.
  assertFalse(Canvas:FrameFor(rec.id):IsMouseEnabled())
end)

test("Canvas: only mouseover panels are tracked by the ticker", function()
  fresh()
  local plain = R:New("Plain")
  local fader = R:New("Fader", { mouseover = true })
  assertEqual(Canvas.__mouseoverPanels[plain.id], nil)
  assertTrue(Canvas.__mouseoverPanels[fader.id] ~= nil)
end)

test("Canvas: turning mouseover off untracks the panel and restores its alpha", function()
  fresh()
  local rec = R:New("Fader", { mouseover = true, mouseoverAlpha = 0.2, alpha = 1 })
  R:Set(rec.id, "mouseover", false)
  assertEqual(Canvas.__mouseoverPanels[rec.id], nil, "the panel is still on the ticker")
  assertNear(Canvas:FrameFor(rec.id):GetAlpha(), 1)
end)

test("Canvas: a deleted mouseover panel leaves the ticker", function()
  fresh()
  local rec = R:New("Fader", { mouseover = true })
  R:Delete(rec.id)
  -- A stale entry would poll a pooled frame forever.
  assertEqual(Canvas.__mouseoverPanels[rec.id], nil)
end)

test("Canvas: an unlocked mouseover panel is held fully visible", function()
  fresh()
  local rec = R:New("Fader", { mouseover = true, mouseoverAlpha = 0, alpha = 1 })
  NS.Unlock:SetUnlocked(true)
  Canvas.__updateMouseover()
  -- A panel resting at 0 alpha would be invisible to place, so editing suspends the fade.
  assertNear(Canvas:FrameFor(rec.id):GetAlpha(), 1)
  NS.Unlock:SetUnlocked(false)
end)

test("Canvas: a panel unlocked ON ITS OWN also suspends the fade", function()
  fresh()
  local rec = R:New("Fader", { mouseover = true, mouseoverAlpha = 0, alpha = 1 })
  NS.Unlock:SetPanelUnlocked(rec.id, true)
  Canvas.__updateMouseover()
  assertNear(Canvas:FrameFor(rec.id):GetAlpha(), 1)
  NS.Unlock:SetPanelUnlocked(rec.id, false)
end)

-- ── Per-panel unlock ────────────────────────────────────────────────────────────

test("Unlock.IsPanelUnlocked: false by default", function()
  fresh()
  local rec = R:New("Locked")
  assertFalse(NS.Unlock:IsPanelUnlocked(rec.id))
end)

test("Unlock.SetPanelUnlocked: unlocks just that panel", function()
  fresh()
  local one = R:New("One")
  local two = R:New("Two")
  NS.Unlock:SetPanelUnlocked(one.id, true)
  assertTrue(NS.Unlock:IsPanelUnlocked(one.id))
  assertFalse(NS.Unlock:IsPanelUnlocked(two.id), "unlocking one panel unlocked another")
  assertTrue(Canvas:FrameFor(one.id):IsMouseEnabled())
  assertFalse(Canvas:FrameFor(two.id):IsMouseEnabled())
  NS.Unlock:SetPanelUnlocked(one.id, false)
end)

test("Unlock.IsPanelUnlocked: the global unlock covers every panel", function()
  fresh()
  local rec = R:New("Covered")
  NS.Unlock:SetUnlocked(true)
  assertTrue(NS.Unlock:IsPanelUnlocked(rec.id))
  NS.Unlock:SetUnlocked(false)
end)

test("Unlock: a global lock clears the per-panel unlocks", function()
  fresh()
  local rec = R:New("Individual")
  NS.Unlock:SetPanelUnlocked(rec.id, true)
  NS.Unlock:SetUnlocked(false)
  -- Pressing lock is an unambiguous "put everything away"; leaving one draggable would be a frame
  -- the user thought they had dismissed.
  assertFalse(NS.Unlock:IsPanelUnlocked(rec.id))
end)

test("Unlock: a per-panel unlock during combat is deferred", function()
  fresh()
  local rec = R:New("Queued")
  T.mocks.__inCombat = true
  assertEqual(NS.Unlock:SetPanelUnlocked(rec.id, true), nil)
  assertFalse(NS.Unlock:IsPanelUnlocked(rec.id))
  assertTrue(NS.Unlock.__hasPending(rec.id))
  T.mocks.__inCombat = false
end)

test("Unlock: a deferred per-panel unlock is replayed when combat ends", function()
  fresh()
  local rec = R:New("Queued")
  T.mocks.__inCombat = true
  NS.Unlock:SetPanelUnlocked(rec.id, true)
  T.mocks.__inCombat = false
  assertTrue(NS.Unlock:ResumePending())
  assertTrue(NS.Unlock:IsPanelUnlocked(rec.id))
  assertFalse(NS.Unlock.__hasPending(rec.id))
  NS.Unlock:SetPanelUnlocked(rec.id, false)
end)

test("Unlock: a panel deleted mid-combat is not resurrected on replay", function()
  fresh()
  local rec = R:New("Doomed")
  T.mocks.__inCombat = true
  NS.Unlock:SetPanelUnlocked(rec.id, true)
  R:Delete(rec.id)
  T.mocks.__inCombat = false
  NS.Unlock:ResumePending()
  -- Replaying it would leave an unlock entry for a record that no longer exists.
  assertFalse(NS.Unlock:IsPanelUnlocked(rec.id))
  assertEqual(NS.State.unlockedPanels[rec.id], nil)
end)

test("Registry.Delete: drops the panel's session unlock state", function()
  fresh()
  local rec = R:New("Transient")
  NS.Unlock:SetPanelUnlocked(rec.id, true)
  R:Delete(rec.id)
  assertEqual(NS.State.unlockedPanels[rec.id], nil)
end)

test("Database: per-panel unlock state is NOT persisted", function()
  assertEqual(NS.defaults.profile.unlockedPanels, nil)
  assertEqual(NS.defaults.profile.settings.unlockedPanels, nil)
end)
