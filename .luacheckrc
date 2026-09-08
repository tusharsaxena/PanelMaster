std = "lua51"
max_line_length = false
codes = true
-- libs/ holds vendored code, including libs/LibKa0s/, whose upstream is the LibKa0s repo and which
-- is linted THERE as source. tests/_kit/ is that same fact one level down: it is a byte copy of the
-- library's testkit/, so linting the copy as well would report every finding twice and let the copy
-- drift green while the original went red -- the one state tests/test_vendor_sync.lua exists to
-- forbid. That reason reaches the vendored copy and nothing else: the rest of tests/ is ours, and
-- it is linted (lint-§1).
-- Under docs/ only the FROZEN evidence bundles are excluded. A blanket docs/ exclude would silently
-- drop any Lua a future doc directory carries out of the gate.
exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/_kit/" }
ignore = {
  "212/self",   -- unused argument self
  "212/event",  -- unused argument event
}
read_globals = {
  -- Core Lua/WoW globals
  "_G", "LibStub", "CreateFrame", "GetTime", "time", "date", "unpack",
  "GetLocale", "C_Timer", "hooksecurefunc", "InCombatLockdown", "PlaySound",
  "C_AddOns", "GetAddOnMetadata", "GetNumAddOns", "GetAddOnInfo", "strtrim",
  -- Class color (the classFile token and the palette every UI addon agrees on) and the
  -- cursor test the mouseover fade polls with.
  "UnitClass", "RAID_CLASS_COLORS", "MouseIsOver",
  -- UI globals used by the panels, the console and the settings pages
  "UIParent", "UISpecialFrames", "DEFAULT_CHAT_FRAME", "GameTooltip",
  "Settings", "CreateColor", "BackdropTemplateMixin", "STANDARD_TEXT_FONT",
  "StaticPopup_Show", "YES", "NO",
}
globals = {
  "PanelMasterDB",     -- the SavedVariables write target, declared in the TOC
  -- Registering a confirm dialog means writing a new key into Blizzard's table; that is the only
  -- API FrameXML offers for it, and every addon that ships a StaticPopup does the same.
  "StaticPopupDialogs",
}

-- Everything below is scoped to tests/ and is deliberately NOT in the top-level tables above. A name
-- granted at the top level is granted to core/, modules/ and settings/ as much as to a suite, and a
-- shipped file reaching for the test harness -- or writing a foreign addon's globals -- is exactly
-- what this gate exists to refuse.
--
-- Every name is spelled as a field of _G, because that is how the suites write them and because "_G"
-- is a read_global above: without these declarations luacheck reports each write as W122, setting a
-- read-only field. `globals` rather than `read_globals` for the same reason -- these are writes.
files["tests/"] = {
  globals = {
    -- The harness's exposed table, written at tests/run.lua:75 and read back by every suite file.
    "_G.PM_TEST",
    -- SunnArt's own globals, and those of the art packs and the player's saved customizations.
    -- They belong to a foreign addon that may or may not be installed, which is why modules/
    -- SunnArt.lua reads all five through `rawget(_G, "...")` (:116-181) and why they are absent
    -- from read_globals above: a string key is not a global reference and never was one. A suite
    -- that plants one is standing SunnArt up so the reader has something to read.
    "_G.SunnArt", "_G.SunnArtPack",
    "_G.SunnCustomTheme", "_G.SunnCustomPanels", "_G.SunnCustomOverlap",
    -- The client's default font face. It is read-only above because core/Constants.lua only ever
    -- READS it; tests/wow_mock.lua:312 is the one writer, planting the client's own value into the
    -- real global table because a sandboxed chunk's _G never reaches the mock's __index.
    "_G.STANDARD_TEXT_FONT",
  },
}
