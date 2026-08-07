local addonName, NS = ...

-- Shared namespace bootstrap. Runs early so common metadata exists regardless of load order.
NS.name = addonName
-- Fallback only: `/pm version` and the help header both resolve through Sl:Version(), which prefers
-- the TOC's ## Version and degrades to this when the metadata API is unavailable (headlessly, say).
NS.version = "1.0.0"

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

-- Modules publish themselves idempotently (`NS.X = NS.X or {}`); nothing to wire here yet.
