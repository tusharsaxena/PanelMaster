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

test("Constants: new panels default to an unscaled 1.0", function()
  -- The identity, so adding the field left every panel that already existed untouched and SetScale
  -- is a no-op until someone asks for one.
  assertEqual(C.PANEL_TEMPLATE.scale, 1.0)
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
  -- The sliders are on the editor's tabs, which settings/PanelEditorTabs.lua draws (#47).
  local f = assert(io.open("settings/PanelEditorTabs.lua", "r"))
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

test("Constants: the mono font and logo point at this addon's folder", function()
  -- Both paths are absolute from Interface\AddOns\, so both have to name THIS folder — the font's
  -- by way of the vendored payload underneath it (libs/LibKa0s/media/fonts/), the logo's directly.
  -- A path naming a sibling addon, or a payload that is not there, renders nothing and raises no
  -- error, which is why it is worth pinning at all.
  assertTrue(C.FONT_MONO:find("PanelMaster", 1, true) ~= nil)
  assertTrue(C.LOGO_PATH:find("PanelMaster", 1, true) ~= nil)
  assertTrue(C.ICON_PATH:find("PanelMaster", 1, true) ~= nil)
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

-- The face is the LIBRARY's now, so this maps into libs/LibKa0s/media/fonts/ rather than into this
-- addon's own media/. That is the point of the case: a re-vendor that dropped the font leaves
-- C.FONT_MONO naming a file nobody ships, and SetFont answers a missing file by drawing nothing.
-- ── the addon's icon (launcher-§4, layout-§4) ───────────────────────────

test("Constants: the icon file named by ICON_PATH exists", function()
  local path = repoPathFor(C.ICON_PATH)
  local f = io.open(path, "rb")
  assertTrue(f ~= nil, "missing shipped asset: " .. path)
  if f then f:close() end
end)

test("Constants: the icon is an uncompressed 32-bit 128x128 Targa, by its own header bytes",
  function()
    -- THE HEADER IS READ rather than the extension trusted, and this is the one case in this file
    -- where that distinction is the whole point. layout-§4 fixes the format because an icon the
    -- client cannot decode draws NOTHING and raises NOTHING -- no gate anywhere else would ever
    -- report it, which is anti-pattern #82's subtler half. Only TGA image type 2 at 32 bpp is
    -- proven to render in the IconTexture role; the RLE-compressed (type 10) logos this collection
    -- also ships are unproven there. 128 is a power of two, so nothing rescales it.
    local f = assert(io.open(repoPathFor(C.ICON_PATH), "rb"), "the icon is missing")
    local header = f:read(18)
    local size = f:seek("end")
    f:close()
    assertEqual(#header, 18, "the icon is too short to be a Targa at all")
    local byte = string.byte
    assertEqual(byte(header, 3), 2,
      "TGA image type is not 2 -- an RLE or color-mapped icon draws nothing and raises nothing")
    assertEqual(byte(header, 17), 32, "TGA is not 32 bpp -- convert('RGBA') is what buys that")
    -- Little-endian 16-bit width and height, at offsets 12 and 14.
    assertEqual(byte(header, 13) + byte(header, 14) * 256, 128, "the icon is not 128 wide")
    assertEqual(byte(header, 15) + byte(header, 16) * 256, 128, "the icon is not 128 tall")
    -- 128 * 128 * 4 pixel bytes, the 18-byte header and Pillow's 26-byte TGA 2.0 footer, which is
    -- the trailing "TRUEVISION-XFILE." block the recipe's writer emits. Exact rather than a floor:
    -- a compressed file of the same declared type is SMALLER, and that is the whole failure this
    -- line catches. If the recipe is ever re-run with a writer that omits the footer, the number
    -- moves by 26 and this case says so rather than going quiet.
    assertEqual(size, 18 + 128 * 128 * 4 + 26,
      "the icon is not the size an uncompressed 32-bit 128 is")
  end)

test("Constants: ICON_PATH and the TOC's ## IconTexture are the same file", function()
  -- One asset, three surfaces: the AddOns list reads the TOC directive, the minimap button and any
  -- broker display read C.ICON_PATH through core/LauncherSetup.lua. A TOC directive cannot read a
  -- Lua constant, so the string is written twice and this is what keeps the two spellings one file.
  local f = assert(io.open("PanelMaster.toc", "r"))
  local toc = f:read("*a")
  f:close()
  local declared = toc:match("##%s*IconTexture:%s*([^\r\n]+)")
  assertTrue(declared ~= nil, "the TOC declares no ## IconTexture at all")
  assertEqual((declared:gsub("%s+$", "")), C.ICON_PATH,
    "the AddOns list and the minimap button draw different files")
  -- Never a Blizzard icon and never a numeric file id (anti-pattern #82): the addon has to look
  -- like itself in the one list where the player is choosing what to turn off.
  assertEqual(declared:find("Interface\\Icons", 1, true), nil,
    "the TOC still points at a borrowed Blizzard icon")
  assertEqual(tonumber(declared), nil, "the TOC points at a numeric file id")
end)

test("Constants: the debug console's mono font exists", function()
  local path = repoPathFor(C.FONT_MONO)
  local f = io.open(path, "rb")
  assertTrue(f ~= nil, "missing shipped asset: " .. path)
  if f then f:close() end
end)
