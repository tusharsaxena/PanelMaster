local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse, assertNear =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNear
local Util = NS.Util

test("Util.DeepEqual: compares plain data by value, nested tables included", function()
  assertTrue(Util.DeepEqual({ 1, { a = 2 } }, { 1, { a = 2 } }))
  assertFalse(Util.DeepEqual({ 1, { a = 2 } }, { 1, { a = 3 } }))
  assertFalse(Util.DeepEqual({ a = 1 }, { a = 1, b = 2 }), "an extra key on the right was missed")
  assertFalse(Util.DeepEqual({ a = 1, b = 2 }, { a = 1 }), "an extra key on the left was missed")
  assertFalse(Util.DeepEqual(1, "1"))
end)

test("Util.SplitPath: splits a dotted path", function()
  local parts = Util.SplitPath("settings.gridSize")
  assertEqual(#parts, 2)
  assertEqual(parts[1], "settings")
  assertEqual(parts[2], "gridSize")
end)

test("Util.SplitPath: a single segment is one part", function()
  assertEqual(#Util.SplitPath("panels"), 1)
end)

test("Util.EffectiveScale: the own scale clamped to the panel bounds, times the master scale", function()
  local C = NS.Constants
  assertEqual(Util.EffectiveScale({ scale = 1.5 }, { scale = 2 }), 3)
  assertEqual(Util.EffectiveScale({ scale = 0.01 }, { scale = 1 }), C.MIN_PANEL_SCALE)
  assertEqual(Util.EffectiveScale({ scale = 99 }, { scale = 1 }), C.MAX_PANEL_SCALE)
  assertEqual(Util.EffectiveScale({}, { scale = 1 }), C.PANEL_TEMPLATE.scale)
  assertEqual(Util.EffectiveScale(nil, nil), C.PANEL_TEMPLATE.scale)
  -- A master scale that is missing, zero or negative is guarded to 1, never multiplied in.
  assertEqual(Util.EffectiveScale({ scale = 2 }, {}), 2)
  assertEqual(Util.EffectiveScale({ scale = 2 }, { scale = 0 }), 2)
  assertEqual(Util.EffectiveScale({ scale = 2 }, { scale = -1 }), 2)
  assertEqual(Util.EffectiveScale({ scale = 2 }, { scale = "junk" }), 2)
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

-- PanelMaster-R-03 (PM-06): NaN and +/-inf are numbers to tonumber, so they used to slip past every
-- "is it a number" guard. NaN fails both comparisons and came back out of Clamp unchanged.
-- red under: Util.IsFinite absent (nil call); Clamp returning NaN / the bound for a non-finite n.
test("Util.IsFinite: true for ordinary numbers, false for NaN, infinities and non-numbers", function()
  assertTrue(Util.IsFinite(0))
  assertTrue(Util.IsFinite(-12.5))
  assertTrue(Util.IsFinite(1e308))
  assertFalse(Util.IsFinite(0 / 0), "NaN")
  assertFalse(Util.IsFinite(math.huge), "+inf")
  assertFalse(Util.IsFinite(-math.huge), "-inf")
  assertFalse(Util.IsFinite(tonumber("1e999")), "1e999 overflows to +inf")
  assertFalse(Util.IsFinite("5"), "a numeric string is not a number")
  assertFalse(Util.IsFinite(nil))
end)

test("Util.Clamp: a non-finite value falls back like a non-number, then to the low bound", function()
  assertEqual(Util.Clamp(0 / 0, 1, 10, 5), 5)
  assertEqual(Util.Clamp(math.huge, 1, 10, 5), 5)
  assertEqual(Util.Clamp(-math.huge, 1, 10, 5), 5)
  assertEqual(Util.Clamp(0 / 0, 1, 10), 1)
  assertEqual(Util.Clamp(math.huge, 1, 10), 1)
  assertEqual(Util.Clamp(0 / 0, 1, 10, 0 / 0), 1, "a non-finite fallback is no fallback")
  assertEqual(Util.Clamp(0 / 0, 1, 10, math.huge), 1)
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

test("Util.ParseBool: accepts every documented token, in any casing", function()
  for _, token in ipairs({ "true", "on", "yes", "1", "TRUE", "On", "YES" }) do
    assertEqual(Util.ParseBool(token), true, token .. " did not read as true")
  end
  for _, token in ipairs({ "false", "off", "no", "0", "FALSE", "Off", "NO" }) do
    assertEqual(Util.ParseBool(token), false, token .. " did not read as false")
  end
end)

test("Util.ParseBool: a boolean passes straight through", function()
  assertEqual(Util.ParseBool(true), true)
  assertEqual(Util.ParseBool(false), false)
end)

test("Util.ParseBool: an unrecognized token is nil, NOT false (F-023)", function()
  -- The whole point of the function: `false` and "I could not read that" must be distinguishable,
  -- or a typo silently turns a setting off and the echo confirms it as though it had been asked for.
  assertEqual(Util.ParseBool("ture"), nil)
  assertEqual(Util.ParseBool(""), nil)
  assertEqual(Util.ParseBool("2"), nil)
  assertEqual(Util.ParseBool(nil), nil)
  assertEqual(Util.ParseBool({}), nil)
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
  local c = Util.Color("not a color", { 0.1, 0.2, 0.3, 0.4 })
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

test("Util.ParseColor: a byte triple's alpha of 1 or less is already fractional (PANELMASTER-R-03)",
  function()
  -- The scale is chosen from R, G and B and it is right to choose it there. Applying it to alpha as
  -- well is what this case rejects: "255,0,0,1" is the form a user reaches for after reading that
  -- the parser takes bytes, and it used to yield alpha 1/255 = 0.0039 — a panel invisible on screen
  -- with no error anywhere to explain it.
  local c = Util.ParseColor("255,0,0,1")
  assertNear(c[1], 1)
  assertNear(c[4], 1, 0.001)
  -- Not only about 1: any alpha the user could have meant fractionally reads that way, and a byte
  -- alpha still scales, because a byte alpha above 1 is unambiguous.
  assertNear(Util.ParseColor("128,64,32,0.5")[4], 0.5, 0.001)
  assertNear(Util.ParseColor("255,0,0,128")[4], 128 / 255, 0.001)
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

test("Util.FormatColor: round-trips the mixed-scale byte form too (PANELMASTER-R-03)", function()
  -- FormatColor always emits the fractional form, so the round trip that matters for the byte
  -- reading is the FIRST hop: whatever ParseColor made of the bytes has to survive being written
  -- out and read back. The pre-fix parse round-tripped perfectly — 0.0039 formats "0.00" and reads
  -- back 0.00 — which is why this asserts the COLOR, not merely that the trip is stable.
  local reparsed = Util.ParseColor(Util.FormatColor(Util.ParseColor("255,0,0,1")))
  assertNear(reparsed[1], 1, 0.01)
  assertNear(reparsed[2], 0, 0.01)
  assertNear(reparsed[3], 0, 0.01)
  assertNear(reparsed[4], 1, 0.01)
end)

test("Util.CleanName: trims and collapses whitespace", function()
  assertEqual(Util.CleanName("  Chat   BG  "), "Chat BG")
end)

test("Util.CleanName: empty and whitespace-only names are nil", function()
  assertEqual(Util.CleanName(""), nil)
  assertEqual(Util.CleanName("   "), nil)
  assertEqual(Util.CleanName(nil), nil)
end)

-- Non-Latin panel names (PM-R-01, PanelMaster#26). The strings are written as decimal byte escapes so
-- the source stays ASCII; each is named in the comment beside it.
local CYR_OBZOR   = "\208\158\208\177\208\183\208\190\209\128"             -- Cyrillic "Obzor"
local CYR_SPISOK  = "\208\161\208\191\208\184\209\129\208\190\208\186"     -- Cyrillic "Spisok"
local CYR_OBZOR_U = "\208\158\208\145\208\151\208\158\208\160"             -- the same, upper case
local CJK_A       = "\230\166\130\232\166\129"                             -- Han "overview"
local CJK_B       = "\232\174\190\231\189\174"                             -- Han "settings"
local A_UMLAUT    = "\195\132rger"                                         -- "Aerger", A with umlaut
local O_UMLAUT    = "\195\150rger"                                         -- "Oerger", O with umlaut
local U_UPPER     = "\195\156bersicht"                                     -- "Uebersicht", capital U umlaut
local U_LOWER     = "\195\188bersicht"                                     -- the same, lower case

test("Util.Slugify: distinct non-Latin names give distinct slugs (PM-R-01)", function()
  -- red under: Slugify matching [^%w]+ on raw bytes, which drops every byte >= 0x80
  assertTrue(Util.Slugify(CYR_OBZOR) ~= Util.Slugify(CYR_SPISOK), "two Cyrillic names share a slug")
  assertTrue(Util.Slugify(CJK_A) ~= Util.Slugify(CJK_B), "two Han names share a slug")
  assertTrue(Util.Slugify(CJK_A) ~= "Panel", "a Han name fell back to the punctuation slug")
  assertTrue(Util.Slugify(A_UMLAUT) ~= Util.Slugify(O_UMLAUT), "an accented pair shares a slug")
end)

test("Util.Slugify: bytes >= 0x80 are written as upper-case hex, joined to the ASCII text", function()
  -- red under: Slugify matching [^%w]+ on raw bytes
  assertEqual(Util.Slugify(A_UMLAUT), "C384rger")
  assertEqual(Util.Slugify(CYR_OBZOR), "D09ED0B1D0B7D0BED180")
end)

test("Util.Slugify: ASCII names keep the slug they always had", function()
  assertEqual(Util.Slugify("Chat  BG!"), "Chat_BG")
  assertEqual(Util.Slugify("!!!"), "Panel")
end)

test("Util.FoldName: folds case across Latin-1, Latin Extended-A, Greek and Cyrillic", function()
  -- red under: no Util.FoldName (FindByName folding with ASCII-only string.lower)
  assertEqual(Util.FoldName(U_UPPER), Util.FoldName(U_LOWER))
  assertEqual(Util.FoldName(CYR_OBZOR_U), Util.FoldName(CYR_OBZOR))
  assertEqual(Util.FoldName("\206\163"), "\207\131")           -- Greek U+03A3 -> U+03C3
  assertEqual(Util.FoldName("Chat BG"), "chat bg")
  -- Latin Extended-A pairs are not all upper-even: U+0139/U+013A (L acute) is upper-odd.
  assertEqual(Util.FoldName("\196\185"), "\196\186")
  assertEqual(Util.FoldName("\196\128"), "\196\129")          -- U+0100 -> U+0101
  -- U+00D7 (multiplication sign) has no case and must not fold to U+00F7 (division sign).
  assertEqual(Util.FoldName("\195\151"), "\195\151")
  -- Distinct letters stay distinct.
  assertTrue(Util.FoldName(A_UMLAUT) ~= Util.FoldName(O_UMLAUT))
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
