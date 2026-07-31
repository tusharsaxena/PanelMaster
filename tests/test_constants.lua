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

test("Constants: the editor's offset reach is named, symmetric and wide enough to be useful", function()
  -- It is a slider REACH, not a clamp — Registry.Sanitize leaves x/y unbounded on purpose — so the
  -- only thing to pin is that it exists, is a positive number, and is not narrower than the screen
  -- sizes the addon already contemplates.
  assertEqual(type(C.EDITOR_OFFSET_RANGE), "number")
  assertTrue(C.EDITOR_OFFSET_RANGE > 0)
  assertTrue(C.EDITOR_OFFSET_RANGE >= C.MAX_SIZE / 4, "the X/Y sliders should reach off-center far")
end)

test("Constants: no slider in the panel editor decides its own bounds", function()
  -- options-ui-§8, "Named, never inlined". The editor used to pin Width/Height at 1200 and X/Y at
  -- ±2000, which silently rewrote any panel that lived outside those numbers the first time its
  -- slider was touched. A source scan is the only headless way to catch a relapse: AceGUI is stubbed
  -- in the suite, so the editor's builders never run and the bounds are never observable at runtime.
  local f = assert(io.open("settings/PanelEditor.lua", "r"))
  local src = f:read("*a")
  f:close()

  local expected = {
    ['"Width", "width"']      = "C.MIN_SIZE, C.MAX_SIZE",
    ['"Height", "height"']    = "C.MIN_SIZE, C.MAX_SIZE",
    ['"X offset", "x"']       = "-C.EDITOR_OFFSET_RANGE, C.EDITOR_OFFSET_RANGE",
    ['"Y offset", "y"']       = "-C.EDITOR_OFFSET_RANGE, C.EDITOR_OFFSET_RANGE",
  }
  for field, bounds in pairs(expected) do
    local call = src:match("numberField%([%w_]+, " .. field:gsub("%p", "%%%0") .. ", ([^)]*)%)")
    assertTrue(call ~= nil, "no numberField call for " .. field)
    assertEqual(call, bounds, field .. " should take its bounds from Constants")
  end
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

-- The shipped media paths actually resolve to files on disk.
--
-- This is the one class of asset bug the client gives you nothing for: a missing texture renders
-- NOTHING and raises NO error, so a wrong path or a file that never got committed shows up as a
-- blank settings page that looks like a layout problem. A sibling addon shipped exactly that for a
-- while. Cheap to check here, since the in-game path maps directly onto the repo path.
local function repoPathFor(interfacePath)
  -- "Interface\AddOns\PanelMaster\media\..." → "media/..."
  return (interfacePath:gsub("\\", "/"):gsub("^Interface/AddOns/PanelMaster/", ""))
end

test("Constants: the logo file named by LOGO_PATH exists", function()
  local path = repoPathFor(C.LOGO_PATH)
  local f = io.open(path, "rb")
  assertTrue(f ~= nil, "missing shipped asset: " .. path)
  if f then f:close() end
end)

test("Constants: the logo is a Targa, which is the only format WoW loads at runtime", function()
  -- .png and .jpg cannot be loaded by the client at all, so a path pointing at one is a blank page.
  assertTrue(C.LOGO_PATH:lower():find("%.tga$") ~= nil)
end)

test("Constants: the debug console's mono font exists", function()
  local path = repoPathFor(C.FONT_MONO)
  local f = io.open(path, "rb")
  assertTrue(f ~= nil, "missing shipped asset: " .. path)
  if f then f:close() end
end)
