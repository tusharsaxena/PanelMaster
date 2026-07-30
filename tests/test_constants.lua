local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local C = NS.Constants

test("Constants: the strata list runs lowest to highest and starts at BACKGROUND", function()
  assertEqual(C.STRATA[1], "BACKGROUND")
  assertEqual(C.STRATA[#C.STRATA], "TOOLTIP")
  assertEqual(#C.STRATA, 8, "the full WoW strata set should be offered")
end)

test("Constants: new panels default to LOW", function()
  -- One step above BACKGROUND: high enough to clear the world and Blizzard's parchment art, low
  -- enough to stay under essentially every interface frame — which is what a backdrop wants.
  assertEqual(C.PANEL_TEMPLATE.strata, "LOW")
end)

test("Constants: new panels default to CENTER at 0,0", function()
  -- Both halves of the anchor, or the offsets would be measured from a different point than the
  -- panel is pinned by. A new panel lands in the middle of the screen where it cannot be missed.
  assertEqual(C.PANEL_TEMPLATE.point, "CENTER")
  assertEqual(C.PANEL_TEMPLATE.relPoint, "CENTER")
  assertEqual(C.PANEL_TEMPLATE.x, 0)
  assertEqual(C.PANEL_TEMPLATE.y, 0)
end)

test("Constants: STRATA_SET agrees with STRATA", function()
  local n = 0
  for _ in pairs(C.STRATA_SET) do n = n + 1 end
  assertEqual(n, #C.STRATA)
  for _, s in ipairs(C.STRATA) do assertTrue(C.STRATA_SET[s]) end
end)

test("Constants: nine anchor points, all in POINT_SET", function()
  assertEqual(#C.POINTS, 9)
  for _, p in ipairs(C.POINTS) do assertTrue(C.POINT_SET[p], p .. " missing from POINT_SET") end
end)

test("Constants: STRATA_OPTIONS is dropdown-shaped", function()
  assertEqual(#C.STRATA_OPTIONS, #C.STRATA)
  for _, opt in ipairs(C.STRATA_OPTIONS) do
    assertTrue(opt.value ~= nil and opt.label ~= nil)
  end
end)

test("Constants: every template field has a declared type", function()
  -- The CLI coerces `/pm panel set` values from PANEL_FIELD_TYPE, so a template field with no type
  -- would be silently un-settable from the command line.
  for field in pairs(C.PANEL_TEMPLATE) do
    assertTrue(C.PANEL_FIELD_TYPE[field] ~= nil, "no declared type for " .. field)
  end
end)

test("Constants: every typed field appears in the display order", function()
  local inOrder = {}
  for _, f in ipairs(C.PANEL_FIELD_ORDER) do inOrder[f] = true end
  for field in pairs(C.PANEL_FIELD_TYPE) do
    assertTrue(inOrder[field], field .. " missing from PANEL_FIELD_ORDER")
  end
end)

test("Constants: the template's own values are valid by its own rules", function()
  assertTrue(NS.Util.IsPoint(C.PANEL_TEMPLATE.point))
  assertTrue(NS.Util.IsPoint(C.PANEL_TEMPLATE.relPoint))
  assertTrue(NS.Util.IsStrata(C.PANEL_TEMPLATE.strata))
  assertTrue(C.PANEL_TEMPLATE.width >= C.MIN_SIZE and C.PANEL_TEMPLATE.width <= C.MAX_SIZE)
  assertTrue(C.PANEL_TEMPLATE.height >= C.MIN_SIZE and C.PANEL_TEMPLATE.height <= C.MAX_SIZE)
end)

test("Constants: preview panels are valid panel overrides", function()
  for _, spec in ipairs(C.PREVIEW_PANELS) do
    assertTrue(NS.Util.IsPoint(spec.point), spec.name .. " has a bad anchor")
    assertTrue(spec.width >= C.MIN_SIZE and spec.height >= C.MIN_SIZE)
  end
end)

test("Constants: the mono font and logo point at this addon's folder", function()
  -- A path copied from a sibling addon renders nothing and raises no error, so it is worth pinning.
  assertTrue(C.FONT_MONO:find("PanelMaster", 1, true) ~= nil)
  assertTrue(C.LOGO_PATH:find("PanelMaster", 1, true) ~= nil)
end)
