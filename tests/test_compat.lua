local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

test("Compat.GetAddOnMetadata: reads the TOC Version through C_AddOns", function()
  assertEqual(NS.Compat.GetAddOnMetadata("PanelMaster", "Version"), "0.1.0")
end)

test("Compat.GetAddOnMetadata: an unknown field is nil, not an error", function()
  assertEqual(NS.Compat.GetAddOnMetadata("PanelMaster", "Nonsense"), nil)
end)

test("Compat.GetScreenSize: returns the UIParent dimensions", function()
  local w, h = NS.Compat.GetScreenSize()
  assertEqual(w, 1920)
  assertEqual(h, 1080)
end)

test("Compat.GetUIScale: defaults to 1 when the frame cannot answer", function()
  -- The stub's GetEffectiveScale returns the frame itself (not a number), which must read as
  -- "cannot tell" and fall back to the identity scale rather than propagating a frame into the
  -- drag maths.
  assertEqual(NS.Compat.GetUIScale(), 1)
end)

test("Compat.FetchMedia: degrades to the flat texture when LibSharedMedia is absent", function()
  -- LSM is an OptionalDep and is deliberately missing from the headless mock set, so this is the
  -- soft-fallback path an install without it takes (library-stack-§6). It must produce the STOCK
  -- look, not nothing: a panel with an unresolvable texture should be plain, never invisible.
  assertEqual(NS.Compat.FetchMedia("background", "Solid"), NS.Constants.SOLID_TEXTURE)
  assertEqual(NS.Compat.FetchMedia("border", "Blizzard Tooltip"), NS.Constants.SOLID_TEXTURE)
end)

test("Compat.FetchMedia: an unresolvable name falls back rather than rendering nothing", function()
  -- The realistic case: the user picked a texture from another addon, then uninstalled it.
  assertEqual(NS.Compat.FetchMedia("background", "Some Addon's Texture"),
    NS.Constants.SOLID_TEXTURE)
end)

test("Compat.FetchMedia: 'None' is an explicit choice and resolves to nil", function()
  -- Distinct from a failed lookup: "None" means the user asked for no fill / no border.
  assertEqual(NS.Compat.FetchMedia("background", "None"), nil)
  assertEqual(NS.Compat.FetchMedia("border", "None"), nil)
end)

test("Compat.MediaList: always offers None first, then the built-in flat texture", function()
  -- "Draw nothing" is a choice this addon's UI must always be able to offer. LibSharedMedia ships
  -- it today, but depending on a third-party lib's defaults would make it a promise this addon does
  -- not control — so it is contributed here. LSM is absent headlessly, which is this exact path.
  local list = NS.Compat.MediaList("border")
  assertEqual(#list, 2)
  assertEqual(list[1], NS.Constants.NONE_MEDIA_NAME)
  assertEqual(list[2], NS.Constants.SOLID_MEDIA_NAME)
end)

test("Compat.MediaList: never lists a name twice", function()
  local seen = {}
  for _, name in ipairs(NS.Compat.MediaList("background")) do
    assertFalse(seen[name], "duplicate entry: " .. tostring(name))
    seen[name] = true
  end
end)

test("Compat.RegisterMedia: reports failure without LibSharedMedia rather than erroring", function()
  assertFalse(NS.Compat.RegisterMedia())
end)

test("Compat.GetClassColor: reads RAID_CLASS_COLORS by classFile token", function()
  local r, g, b = NS.Compat.GetClassColor()
  -- The mock player is a Priest (1, 1, 1). Matched on the "PRIEST" token, never on a localized
  -- class name (localization-§4).
  assertEqual(r, 1)
  assertEqual(g, 1)
  assertEqual(b, 1)
end)

test("Compat.GetClassColor: an unknown class is nil, not white", function()
  local saved = T.mocks.UnitClass
  T.mocks.UnitClass = function() return "Tinker", "TINKER", 99 end
  local r = NS.Compat.GetClassColor()
  T.mocks.UnitClass = saved
  -- nil lets the caller keep the user's stored color; white would silently repaint their panel.
  assertEqual(r, nil)
end)

test("Compat.MouseIsOver: answers without the frame taking mouse input", function()
  local frame = T.mocks.CreateFrame()
  assertFalse(NS.Compat.MouseIsOver(frame))
  T.mocks.__mouseIsOver = frame
  assertTrue(NS.Compat.MouseIsOver(frame))
  T.mocks.__mouseIsOver = nil
  -- The panel is never EnableMouse'd for this — that would break click-through, which is the one
  -- guarantee a backdrop cannot break.
  assertFalse(frame:IsMouseEnabled())
end)

test("Compat owns the deprecated-API surface: no flavor branching in the addon", function()
  -- compat / anti-patterns: a Retail-only addon must never branch on WOW_PROJECT_ID. Asserted here
  -- rather than by eye because it is a rule that only breaks when someone adds a line years later.
  local sources = {
    "core/Compat.lua", "core/Constants.lua", "core/Util.lua", "core/Database.lua",
    "core/PanelMaster.lua", "modules/Registry.lua", "modules/Canvas.lua", "modules/Unlock.lua",
    "modules/DebugLog.lua", "settings/Schema.lua", "settings/Slash.lua", "settings/Panel.lua",
  }
  for _, path in ipairs(sources) do
    local f = io.open(path, "r")
    assertTrue(f ~= nil, "missing source " .. path)
    local body = f:read("*a")
    f:close()
    assertEqual(body:find("WOW_PROJECT_ID", 1, true), nil,
      path .. " branches on WOW_PROJECT_ID")
  end
end)
