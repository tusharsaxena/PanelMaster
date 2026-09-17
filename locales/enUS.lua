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
-- ── THE ONE STRING THAT IS DELIBERATELY NOT HERE ───────────────────────────────
--
-- The disabled-verb refusal used to be listed here, in this addon's own wording, as the single
-- string routing through the seam. It is gone, and its absence is the entry.
--
-- slash-commands-§7 fixes that line's shape for the whole collection -- `<BrandName> is disabled —
-- enable it with /<slash> enable`, the command in the help index's gold and carrying its leading
-- slash, an em dash with a single space either side, no trailing period -- and LibKa0s-Slash-1.0
-- builds it from `lib.DISABLED_LINE_FORMAT`. The library's own contract says so in as many words:
-- the locale override a host passes DOES NOT REACH the refusal line, because that wording is the
-- collection's and not the addon's. Eleven addons each translating it slightly differently is the
-- drift the one shared formatter exists to end.
--
-- So nothing in this file overrides it, and settings/Slash.lua asks the dispatcher for the line
-- rather than composing one. What a translator gets instead is the brand name -- which launcher-§1
-- already forbids escapes in, which is exactly what makes it safe to drop into a colored line --
-- and that is a NAME, so localization-§4 keeps it untranslated too.
--
-- Note for a future pass: panel NAMES are user-supplied data, not UI strings, and must never be run
-- through NS.L. Neither must the stored `point` / `strata` tokens — those are matched on stable
-- identifiers, never on a localized display string (localization-§4).
