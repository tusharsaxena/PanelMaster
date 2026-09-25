local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- NOTE: the two Compat.GetAddOnMetadata cases that used to open this file are gone with the shim.
-- The reader is now NS.Meta / NS.Version over LibKa0s-Env-1.0; tests/test_envsetup.lua covers the
-- seam, and the library's own suite covers the ladder inside it (testing-§8).

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

test("Compat: the class-color lookup is the library's, not a private copy here", function()
  -- options-ui-§17's ONE RESOLVER rule. `Compat.GetClassColor` used to read RAID_CLASS_COLORS in
  -- this file; LibKa0s-Core-1.0 minor 7 owns that for the whole collection now, and a host copy
  -- beside it is the drift the rule exists to end.
  --
  -- Both halves are asserted, because either alone passes against the wrong thing: the member is
  -- gone from Compat, AND the source no longer reads the table it read. Dies under re-adding the
  -- function, and under a differently-named private copy of its body.
  assertEqual(NS.Compat.GetClassColor, nil,
    "core/Compat.lua grew a class-color resolver back — options-ui-§17 allows exactly one, and it " ..
    "is LibKa0s-Core-1.0's")
  local f = assert(io.open("core/Compat.lua", "r"))
  local body = f:read("*a")
  f:close()
  -- The comment block that records the removal names the table, so the check is for a READ of it.
  assertEqual(body:find("RAID_CLASS_COLORS%s*%["), nil,
    "core/Compat.lua indexes RAID_CLASS_COLORS again")
  -- And the library really does answer for this addon's mock player, a Priest (1, 1, 1), matched
  -- on the "PRIEST" token and never on a localized class name (localization-§4).
  local r, g, b = NS.Core.ClassColor()
  assertEqual(r, 1)
  assertEqual(g, 1)
  assertEqual(b, 1)
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

-- Compat.InCombat answers the DISPLAY question -- is the player fighting? -- and that is
-- UnitAffectingCombat's flag, not InCombatLockdown's (events-frames-taint-§2). The two differ exactly
-- where it matters: lockdown starts after PLAYER_REGEN_DISABLED. The kit mock ties both APIs to the
-- one __inCombat flag, so these cases diverge them locally, inside the case, and put them back.
test("Compat.InCombat follows UnitAffectingCombat, not lockdown", function()
  local lockdown = T.mocks.InCombatLockdown
  T.mocks.__inCombat = true
  T.mocks.InCombatLockdown = function() return false end
  local ok, answer = pcall(NS.Compat.InCombat)
  T.mocks.InCombatLockdown = lockdown
  T.mocks.__inCombat = false
  assertTrue(ok, "Compat.InCombat raised")
  assertEqual(answer, true, "the combat flag was up, lockdown was not, and InCombat said false")
end)

test("Compat.InCombat falls back to InCombatLockdown when UnitAffectingCombat is absent", function()
  local unitCombat = T.mocks.UnitAffectingCombat
  T.mocks.UnitAffectingCombat = nil
  local ok1, inside = pcall(NS.Compat.InCombat)
  T.mocks.__inCombat = true
  local ok2, during = pcall(NS.Compat.InCombat)
  T.mocks.__inCombat = false
  local ok3, after = pcall(NS.Compat.InCombat)
  T.mocks.UnitAffectingCombat = unitCombat
  assertTrue(ok1 and ok2 and ok3, "Compat.InCombat raised on the fallback")
  assertEqual(inside, false)
  assertEqual(during, true, "the fallback did not follow InCombatLockdown")
  assertEqual(after, false)
end)

test("Compat.InCombat answers false when neither combat API exists", function()
  -- False keeps a panel on screen: an "Only out of combat" profile reading true on a client that
  -- cannot answer would hide the whole backdrop for the session.
  local unitCombat, lockdown = T.mocks.UnitAffectingCombat, T.mocks.InCombatLockdown
  T.mocks.UnitAffectingCombat, T.mocks.InCombatLockdown = nil, nil
  T.mocks.__inCombat = true
  local ok, answer = pcall(NS.Compat.InCombat)
  T.mocks.__inCombat = false
  T.mocks.UnitAffectingCombat, T.mocks.InCombatLockdown = unitCombat, lockdown
  assertTrue(ok, "Compat.InCombat raised with no API")
  assertEqual(answer, false)
end)

test("Compat owns the deprecated-API surface: no flavor branching in the addon", function()
  -- compat / anti-patterns: a Retail-only addon must never branch on WOW_PROJECT_ID. Asserted here
  -- rather than by eye because it is a rule that only breaks when someone adds a line years later.
  local sources = {
    "core/Compat.lua", "core/Constants.lua", "core/Util.lua", "core/Database.lua",
    "core/PanelMaster.lua", "modules/Registry.lua", "modules/Canvas.lua", "modules/Unlock.lua",
    "core/DebugLogSetup.lua", "settings/Schema.lua", "settings/Slash.lua", "settings/Panel.lua",
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
