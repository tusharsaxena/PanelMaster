-- tests/test_skin_outline.lua — the font outline (LibKa0s v1.82.0, Skin minor 9; PM-01 of
-- Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-06): stored as
-- skin.outline ("all", the default, "hud", "off"), written only through the skin write seam
-- (NS.WriteSkinChoice's `media.outline`), and applied with Skin:SetOutline at load, on every
-- profile event and on the row's own write. LibKa0sSkinTester's tests/test_skin_outline.lua is the
-- pattern, cut to this harness (one shared environment, so every case puts "all" back).
--
-- After test_skinsetup; leaves the outline on "all", stored and applied.

local T = _G.PM_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
local OWNER = "PanelMaster"
local PATH = "skin.outline"

--- Run `fn` with the outline on "all" before and after, stored and applied, whatever `fn` raised.
local function clean(fn)
  return function()
    NS.Schema:Set(PATH, "all")
    Skin:SetOutline(OWNER, "all")
    local ok, err = pcall(fn)
    if NS.db:GetCurrentProfile() ~= "Default" then mocks.__switchProfile("Default") end
    NS.Schema:Set(PATH, "all")
    Skin:SetOutline(OWNER, "all")
    if not ok then error(err, 0) end
  end
end

test("Skin outline: a fresh profile stores All text, the library's default", function()
  assertEqual(NS.defaults.profile.skin.outline, "all")
  assertEqual(NS.defaults.profile.skin.outline, Skin.OUTLINE_DEFAULT)
  assertEqual(NS.db.profile.skin.outline, "all")
  assertEqual(Skin:GetOutline(OWNER), "all")
end)

test("Skin outline: the schema row offers the library's three modes, in its order", function()
  local row = NS.Schema:FindRow(PATH)
  assertTrue(row ~= nil, "a skin.outline row")
  assertTrue(row.skipRender == true, "the Skin tab draws it")
  assertEqual(row.group, "Appearance")
  assertEqual(row.default, NS.defaults.profile.skin.outline, "the row's default is the defaults table's")
  local got = {}
  for _, opt in ipairs(row.values) do got[#got + 1] = opt.value end
  assertEqual(table.concat(got, ","), table.concat(Skin.OUTLINE_MODES, ","))
end)

test("Skin outline: the write seam stores media.outline, and leaves it alone when it is nil", clean(function()
  -- red under: WriteSkinChoice dropping media.outline (the Skin tab's Font outline and another
  -- addon's copy would move the look and never store it).
  NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false, outline = "hud" })
  assertEqual(NS.db.profile.skin.outline, "hud")
  NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false })
  assertEqual(NS.db.profile.skin.outline, "hud", "a media without outline leaves it")
  NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false, outline = "off" })
  assertEqual(NS.db.profile.skin.outline, "off")
  assertEqual(NS.SkinOutline(), "off", "the reader answers the stored mode")
end))

test("Skin outline: another addon's copy reaches the store through WriteChoice", clean(function()
  Skin:WriteChoice(OWNER, "ka0s", "ka0s", nil, { font = false, texture = false, outline = "off" })
  assertEqual(NS.db.profile.skin.outline, "off")
end))

test("Skin outline: the row's write applies the mode live", clean(function()
  NS.Schema:Set(PATH, "hud")
  assertEqual(Skin:GetOutline(OWNER), "hud")
  assertEqual(NS.Skin.Token("font.outline"), "", "window text loses its outline")
  assertEqual(NS.Skin.Token("hud.outline"), "OUTLINE", "the HUD keeps it")
  NS.Schema:Set(PATH, "off")
  assertEqual(NS.Skin.Token("hud.outline"), "", "Off takes both")
  NS.Schema:Set(PATH, "all")
  assertEqual(NS.Skin.Token("font.outline"), "OUTLINE")
end))

test("Skin outline: /pm set takes a known mode and refuses one the library does not know", clean(function()
  NS.Slash:OnSlash("set skin.outline thick")
  assertEqual(NS.db.profile.skin.outline, "all", "an unknown mode was stored")
  NS.Slash:OnSlash("set skin.outline off")
  assertEqual(NS.db.profile.skin.outline, "off")
  assertEqual(Skin:GetOutline(OWNER), "off", "a bare set moves the applied mode (the row's onChange)")
end))

test("Skin outline: the stored mode is applied with the stored pair (load, profile events)", clean(function()
  -- red under: ApplySkinChoice's whole-pair path not applying the stored outline. addon:OnInitialize
  -- and core/Database.lua's profile events both call it with no argument.
  NS.db.profile.skin.outline = "hud"
  Skin:SetOutline(OWNER, "all")
  NS.ApplySkinChoice()
  assertEqual(Skin:GetOutline(OWNER), "hud")
end))

test("Skin outline: a profile switch applies the incoming profile's mode", clean(function()
  -- The harness's AceDB builds every switched-to profile from the defaults (tests/wow_mock.lua), so
  -- the incoming mode is "all": the switch must move the applied "hud" back to it.
  NS.Schema:Set(PATH, "hud")
  assertEqual(Skin:GetOutline(OWNER), "hud")
  mocks.__switchProfile("OutlineProbe")
  assertEqual(NS.db.profile.skin.outline, "all")
  assertEqual(Skin:GetOutline(OWNER), "all", "the switch applied the incoming profile's mode")
end))

test("Skin outline: a profile reset puts the outline back to All text", clean(function()
  NS.Registry:DeleteAll()
  NS.Schema:Set(PATH, "off")
  NS.db:ResetProfile()
  assertEqual(NS.db.profile.skin.outline, "all")
  assertEqual(Skin:GetOutline(OWNER), "all", "the reset re-applies the default")
end))
