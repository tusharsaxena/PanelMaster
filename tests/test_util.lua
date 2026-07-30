local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse, assertNear =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNear
local Util = NS.Util

test("Util.SplitPath: splits a dotted path", function()
  local parts = Util.SplitPath("settings.gridSize")
  assertEqual(#parts, 2)
  assertEqual(parts[1], "settings")
  assertEqual(parts[2], "gridSize")
end)

test("Util.SplitPath: a single segment is one part", function()
  assertEqual(#Util.SplitPath("panels"), 1)
end)

test("Util.Clamp: passes a value already in range", function()
  assertEqual(Util.Clamp(5, 0, 10), 5)
end)

test("Util.Clamp: clamps below and above", function()
  assertEqual(Util.Clamp(-3, 0, 10), 0)
  assertEqual(Util.Clamp(99, 0, 10), 10)
end)

test("Util.Clamp: a non-number falls back, then to the low bound", function()
  assertEqual(Util.Clamp("banana", 2, 10, 7), 7)
  assertEqual(Util.Clamp(nil, 2, 10), 2)
end)

test("Util.Round: rounds away from zero on both signs", function()
  assertEqual(Util.Round(2.5), 3)
  -- floor(n + 0.5) would give -2 here, which is the bug this function exists to avoid: panel
  -- offsets are routinely negative, so a sign-asymmetric round would drift a dragged panel.
  assertEqual(Util.Round(-2.5), -3)
  assertEqual(Util.Round(-2.4), -2)
end)

test("Util.Snap: a grid of 1 or less is the identity", function()
  assertEqual(Util.Snap(37.4, 1), 37)
  assertEqual(Util.Snap(37.4, 0), 37)
end)

test("Util.Snap: rounds to the nearest multiple", function()
  assertEqual(Util.Snap(37, 4), 36)
  assertEqual(Util.Snap(38, 4), 40)
  assertEqual(Util.Snap(-37, 4), -36)
end)

test("Util.Color: fills a missing alpha with 1", function()
  local c = Util.Color({ 0.2, 0.4, 0.6 })
  assertNear(c[4], 1)
end)

test("Util.Color: clamps out-of-range components", function()
  local c = Util.Color({ -1, 5, 0.5, 2 })
  assertEqual(c[1], 0)
  assertEqual(c[2], 1)
  assertEqual(c[4], 1)
end)

test("Util.Color: a non-table falls back rather than erroring", function()
  local c = Util.Color("not a colour", { 0.1, 0.2, 0.3, 0.4 })
  assertNear(c[1], 0.1)
end)

test("Util.ParseColor: reads a 0-1 triple and defaults alpha", function()
  local c = Util.ParseColor("0.1,0.2,0.3")
  assertNear(c[1], 0.1)
  assertNear(c[4], 1)
end)

test("Util.ParseColor: reads a 0-255 tuple and scales it", function()
  local c = Util.ParseColor("255,0,0,255")
  assertNear(c[1], 1)
  assertNear(c[2], 0)
  assertNear(c[4], 1)
end)

test("Util.ParseColor: the byte decision reads RGB only", function()
  -- "0.5,0.5,0.5,1" is unambiguously fractional; a rule that looked at alpha too would see the 1,
  -- call the whole thing bytes, and render a near-black panel.
  local c = Util.ParseColor("0.5,0.5,0.5,1")
  assertNear(c[1], 0.5)
  assertNear(c[4], 1)
end)

test("Util.ParseColor: rejects junk and wrong-length input", function()
  assertEqual(Util.ParseColor("red"), nil)
  assertEqual(Util.ParseColor("1,2"), nil)
  assertEqual(Util.ParseColor("1,2,3,4,5"), nil)
  assertEqual(Util.ParseColor(nil), nil)
end)

test("Util.FormatColor: round-trips through ParseColor", function()
  local original = { 0.25, 0.5, 0.75, 0.5 }
  local reparsed = Util.ParseColor(Util.FormatColor(original))
  for i = 1, 4 do assertNear(reparsed[i], original[i], 0.01) end
end)

test("Util.CleanName: trims and collapses whitespace", function()
  assertEqual(Util.CleanName("  Chat   BG  "), "Chat BG")
end)

test("Util.CleanName: empty and whitespace-only names are nil", function()
  assertEqual(Util.CleanName(""), nil)
  assertEqual(Util.CleanName("   "), nil)
  assertEqual(Util.CleanName(nil), nil)
end)

test("Util.DeepCopy: copies nested tables rather than aliasing", function()
  local src = { a = { b = 1 } }
  local copy = Util.DeepCopy(src)
  copy.a.b = 2
  assertEqual(src.a.b, 1)
end)

test("Util.IsPoint / IsStrata: accept valid tokens, reject the rest", function()
  assertTrue(Util.IsPoint("TOPLEFT"))
  assertFalse(Util.IsPoint("topleft"))
  assertTrue(Util.IsStrata("BACKGROUND"))
  assertTrue(Util.IsStrata("TOOLTIP"))
  assertFalse(Util.IsStrata("background"))
  assertFalse(Util.IsStrata("PARCHMENT"))
end)

test("NS.SafeToString: renders ordinary values and booleans", function()
  assertEqual(NS.SafeToString(nil), "nil")
  assertEqual(NS.SafeToString(true), "true")
  assertEqual(NS.SafeToString(42), "42")
end)

test("NS.IsConcatSafe: a plain value is concat-safe", function()
  assertTrue(NS.IsConcatSafe("hello"))
  assertTrue(NS.IsConcatSafe(7))
end)

test("NS.Print: prepends the cyan [PM] tag", function()
  local chat = T.mocks.__chat
  local before = #chat
  NS.Print("hello")
  assertEqual(#chat, before + 1)
  assertEqual(chat[#chat], NS.PREFIX .. " hello")
end)

test("NS.Print survived the AceConsole embed (architecture-§2)", function()
  -- AceConsole's :Print mixin is stamped onto NS by the AceAddon mock and would render
  -- "|cff33ff99…|r:" — green, trailing colon, no tag. core/PanelMaster.lua reclaims the real printer
  -- from NS.Util.print right after NewAddon; this asserts the reclaim actually happened.
  assertEqual(NS.Print, NS.Util.print)
  local chat = T.mocks.__chat
  NS.Print("tagged")
  assertTrue(chat[#chat]:find("00ffff", 1, true) ~= nil, "expected the cyan tag")
  assertFalse(chat[#chat]:find("33ff99", 1, true) ~= nil, "AceConsole's printer leaked through")
end)
