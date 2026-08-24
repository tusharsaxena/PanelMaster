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

-- The vendored library, loaded FIRST and DERIVED from its own XML. Loader.tocFiles skips every
-- `libs\` line — a vendored library is pulled in through its own XML, which a TOC scan cannot see —
-- so this list used to be re-typed here by hand. It was re-typed SHORT: six of the eight files.
-- A short load list does not raise, it just leaves a module undefined for whichever cases never
-- reach it, which is how the harness ran for a year without Perf.lua or PerfPanel.lua present.
--
-- Loader.xmlFiles reads LibKa0s.xml and returns directory-prefixed paths in XML order, which is
-- load-order-sensitive: Core first, because DebugLog, Slash and Options each resolve
-- LibKa0s-Core-1.0 and return WITHOUT registering when it is absent.
Loader.loadAll(Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml"), NS, mocks)

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
-- BASENAMES, not filenames: the kit appends `.lua` itself. Because `dir` is passed explicitly below,
-- Kit.run calls Kit.assertSuiteInventory(dir, suites) BEFORE loading anything, so this list and
-- `tests/test_*.lua` must agree in both directions or the run dies naming every divergence.
-- tests/test_harness.lua states the same gate as a named case, which is what puts it in
-- docs/test-cases.md.
local SUITES = {
  "test_util", "test_compat", "test_constants",
  "test_mediasetup", "test_envsetup",
  "test_registry", "test_canvas", "test_unlock", "test_media",
  "test_accent", "test_artwork",
  "test_database", "test_debuglog",
  "test_schema", "test_slash", "test_panel", "test_profiles",
  "test_sunnart",
  "test_libka0s", "test_harness",
  "test_spelling",
  "test_vendor_sync",
}

Kit.run({ dir = "tests/", suites = SUITES })
