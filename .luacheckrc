std = "lua51"
max_line_length = false
codes = true
exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/" }
ignore = {
  "212/self",   -- unused argument self
  "212/event",  -- unused argument event
}
read_globals = {
  -- Core Lua/WoW globals
  "_G", "LibStub", "CreateFrame", "GetTime", "time", "date", "unpack",
  "GetLocale", "C_Timer", "hooksecurefunc", "InCombatLockdown", "PlaySound",
  "C_AddOns", "GetAddOnMetadata", "strtrim",
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
