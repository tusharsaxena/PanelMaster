local _, NS = ...

-- Canonical locale. The metatable fallback returns the key itself, so English strings work
-- untranslated and a missing key never errors (localization-§1). Non-enUS files gate with
-- `if GetLocale() ~= "<locale>" then return end` at the top of the file.
NS.L = setmetatable(NS.L or {}, { __index = function(_, k) return k end })

-- English-only remains the shipped scope: almost every label, tooltip and message is still hardcoded
-- English (an accepted scope decision, not an oversight), and the NS.L seam is kept so a later
-- localization pass can wrap them (`NS.L["Enable panels"]`) without touching call sites.
--
-- Keys are the English source strings (localization-§2); only overrides need listing, e.g.:
-- NS.L["Enable panels"] = "Enable panels"
--
-- ── THE ONE STRING THAT ROUTES THROUGH THE SEAM TODAY ──────────────────────────
--
-- The disabled-verb refusal (settings/Slash.lua, slash-commands-§2): while the addon is off, a verb
-- that drives its FEATURES answers on this one line and does nothing else. It is listed here rather
-- than left to the metatable -- which would resolve it identically -- because it is the only entry
-- a translator has to find, and because the `%s` is a CONTRACT: the call site substitutes the
-- gold-wrapped `/pm enable`, so a translation that drops the placeholder loses the one thing the
-- line exists to name. The slash command is not part of the key for the same reason: nobody should
-- have to retype a command to translate a sentence.
NS.L["the addon is disabled \226\128\148 %s turns it back on"] =
  "the addon is disabled \226\128\148 %s turns it back on"
--
-- Note for a future pass: panel NAMES are user-supplied data, not UI strings, and must never be run
-- through NS.L. Neither must the stored `point` / `strata` tokens — those are matched on stable
-- identifiers, never on a localized display string (localization-§4).
