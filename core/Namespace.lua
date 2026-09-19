local addonName, NS = ...

-- Shared namespace bootstrap. Runs early so common metadata exists regardless of load order.
NS.name = addonName
-- Fallback only: `/pm version` and the help header both resolve through Sl:Version(), which prefers
-- the TOC's ## Version and degrades to this when the metadata API is unavailable (headlessly, say).
NS.version = "1.1.1"

-- The persisted-DB shape this build writes. ONE source for both the shipped default
-- (defaults/Global.lua) and the migration runner's target (NS:RunMigrations), so the two cannot
-- drift and a fresh install can never ship a value the runner immediately migrates off.
-- v2 stamped the derived frame name onto every panel record, making it identity rather than
-- something recomputed from the panel's name on every read (see NS:RunMigrations).
NS.SCHEMA_VERSION = 2

-- Shared chat tag. Cyan (00ffff) is the Ka0s Standard house color (slash-commands-§4) — every Ka0s
-- addon prints the same cyan bracketed tag so a user running several recognizes them at a glance.
-- MUST NOT be substituted with another color.
NS.PREFIX = "|cff00ffff[PM]|r"

-- The BRAND NAME in plain text — `Ka0s <Name>`, no escape sequence of any kind (launcher-§1). Three
-- surfaces have to spell it identically and one string is what makes that true: the LDB object's
-- `label`, which a broker display prints beside the other ten rows (core/LauncherSetup.lua); the
-- LibKa0s-Slash-1.0 descriptor's `brandName`, which builds the one refusal line a disabled addon
-- prints (settings/Slash.lua, slash-commands-§7); and the composed *Enable Ka0s Panel Master* row's
-- own label (settings/Schema.lua).
--
-- It is NOT the TOC's `## Title` and the two are deliberately not wired to each other, although this
-- addon's Title happens to read the same. A Title MAY carry color escapes and one in the collection
-- does, which a broker display drawing the string raw splatters across a row where every other row
-- is plain text. It is not the folder name either: `PanelMaster` is an identifier, `Ka0s Panel
-- Master` is a name.
NS.BRAND = "Ka0s Panel Master"

-- Modules publish themselves idempotently (`NS.X = NS.X or {}`); nothing to wire here yet.
