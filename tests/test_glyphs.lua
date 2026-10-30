-- tests/test_glyphs.lua -- the display-glyph guard over this addon's own Lua (LibKa0s v1.82.0, kit
-- revision 45's tests/_kit/glyphs.lua; PM-02 of Ka0sAddonsCommonTasks
-- docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, Addendum 07, ruling D-19).
--
-- Ten skins draw this addon's text in a dozen faces, and a character one of them lacks is a box in
-- that skin only. So every string literal in a tracked .lua file outside libs/ and tests/ carries
-- only characters every shipped face draws (the kit's safe set, read from their cmaps). The degree
-- signs of the rotation choices, the ellipsis of "Custom path..." and the em dashes of the messages
-- are all in that set; the one arrow (core/Database.lua's profile-copy line) is a debug-log
-- argument, which the kit skips because the debug console draws in mono. The guard found nothing
-- to fix or mark when it was added.

local T = _G.PM_TEST
local test = T.test

test("glyphs: display strings use only characters every shipped skin face draws", function()
  -- red under: a character outside the kit's safe set (a U+2248, a U+2192, a U+25BC ...) in a
  -- string the addon paints in a skin face, with no `glyph: mono` or `glyph: data` mark.
  T.assertDisplayGlyphs{ label = "PanelMaster" }
end)
