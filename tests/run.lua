-- Headless test runner for Ka0s Panel Master.
-- Run from the repo root:  lua tests/run.lua        (add --list to emit docs/test-cases.md)
--
-- The registry, the assertions, the `--list` renderer and the source loader are the SHARED test kit
-- (tests/_kit/, vendored whole-folder from ../LibKa0s/testkit — never edited here). What stays this
-- addon's is the environment: tests/wow_mock.lua, which extends the kit's mock_base, and the
-- lifecycle call below.

local Kit    = dofile("tests/_kit/framework.lua")
local Loader = dofile("tests/_kit/loader.lua")
local buildMocks = dofile("tests/wow_mock.lua")

Loader.addonName = "PanelMaster"

-- --- build the shared addon environment once (mirrors the in-game TOC load + OnInitialize) ---
local mocks = buildMocks()
local NS = {}

-- The vendored library, loaded FIRST and by hand. Loader.tocFiles skips every `libs\` line — a
-- vendored library is pulled in through its own XML, which the loader cannot read — so the one
-- library this addon's own code resolves has to be listed here. Order matches LibKa0s.xml: Core
-- first, because DebugLog, Slash and Options each resolve LibKa0s-Core-1.0 and return WITHOUT
-- registering when it is absent.
Loader.loadAll({
  "libs/LibKa0s/Core.lua",
  "libs/LibKa0s/DebugLog.lua",
  "libs/LibKa0s/Slash.lua",
  "libs/LibKa0s/Options.lua",
  "libs/LibKa0s/OptionsWidgets.lua",
  "libs/LibKa0s/OptionsScroll.lua",
}, NS, mocks)

-- The addon's own files, IN TOC ORDER, derived from the TOC rather than hand-listed. The list used
-- to be a second copy maintained here, and a second copy of a load order is a second thing that can
-- be wrong: a file added to the TOC but not to this list simply never loaded in the suite, and the
-- suite stayed green while the addon was untested.
Loader.loadAll(Loader.tocFiles("PanelMaster.toc"), NS, mocks)

-- Run the addon's REAL lifecycle entry points, rather than hand-calling the pieces they are
-- supposed to call.
--
-- This is not a style preference. The first version of this harness listed the setup steps itself
-- (InitDB, Schema:Register, Slash:Register, Panel:Register, Canvas:Enable) — and because it called
-- Canvas:Enable() directly, every bus test passed against wiring that OnEnable never actually
-- performed. In-game, no settings change or panel edit ever reached the renderer: only the two paths
-- that call Canvas:RenderAll() directly (lock/unlock and test mode) repainted anything.
--
-- A harness that reproduces the lifecycle by hand can drift from it silently. Calling the real
-- functions means a step dropped from OnInitialize or OnEnable fails the suite instead of hiding
-- in it.
NS.addon:OnInitialize()
NS.addon:OnEnable()

-- The kit's registry and assertions are MERGED into this addon's existing global test table, under
-- its existing name and beside its existing keys, so not one suite file's `local T = _G.PM_TEST`
-- header changes. Kit.expose adds three assertions this repo did not have (fail, assertNil,
-- assertError) and replaces the four it did with byte-compatible equivalents.
_G.PM_TEST = Kit.expose({ NS = NS, mocks = mocks })

-- --- the suites ---
-- BASENAMES, not filenames: the kit appends `.lua` itself. A name with no file on disk is SKIPPED
-- rather than fatal, which is a silently-green hole — tests/test_harness.lua closes it by asserting
-- this list and `tests/test_*.lua` agree in both directions.
local SUITES = {
  "test_util", "test_compat", "test_constants",
  "test_registry", "test_canvas", "test_unlock", "test_media",
  "test_accent", "test_artwork",
  "test_database", "test_debuglog",
  "test_schema", "test_slash", "test_panel", "test_profiles",
  "test_libka0s", "test_harness",
  "test_spelling",
}

Kit.run({ dir = "tests/", suites = SUITES })
