-- tests/degraded_env.lua — build a whole PanelMaster environment from a PARTIAL LibKa0s file list.
--
-- Not a suite: `tests/run.lua` never lists it and `Kit.assertSuiteInventory` never sees it, because
-- it does not match `tests/test_*.lua`. It is the one builder of degraded environments, shared by
-- `tests/test_libka0s.lua` (the seams, the shared cause clause, the `L` trap) and
-- `tests/test_surface_parity.lua` (the stub-surface gate).
--
-- It lived inside test_libka0s.lua until the parity cases moved out into a file of their own. A
-- second copy of a load list is a second thing that can be wrong — this file's own comment on
-- LIB_FILES says exactly that about the copy that used to sit here — so the builder moved rather
-- than being re-typed beside the cases that needed it.

local Loader = dofile("tests/_kit/loader.lua")
local buildMocks = dofile("tests/wow_mock.lua")

-- Derived from LibKa0s.xml, exactly as tests/run.lua derives it. This was the SECOND hand-typed
-- copy of the vendored library's load list, and it was short by the same two files — so the case
-- that asserted "the vendored library" was present never looked at Perf.lua or PerfPanel.lua.
-- Loader.xmlFiles raises on an XML path it cannot open, so a typo here cannot degrade into an empty
-- list that reads as a clean run.
local LIB_FILES = Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml")

--- Load the WHOLE addon into a fresh environment from a PARTIAL library file list.
---
--- `omit` names LibKa0s basenames to leave out (`{ Slash = true }`). Everything else in
--- LibKa0s.xml still loads, so `LibStub("LibKa0s-Slash-1.0", true)` answers nil for exactly the
--- one major under test while the rest of the addon runs on the real library — which is what an
--- install with a truncated libs/ folder looks like, and what a per-seam parity assertion needs.
---
--- The degraded arm is built THIS WAY on purpose. Hand-stubbing `lib = nil` inside a seam tests a
--- branch rather than an install, and never catches a seam that raises at load before it reaches
--- its own guard; hand-stubbing the member under test asserts the test's own typing.
---
--- `mutate(m, ns)`, when given, runs AFTER the library files and BEFORE the addon's own. That gap is
--- the only window in which the process-global state a Ka0s addon shares with the rest of the client
--- -- AceGUI's widget registry, above all -- can be made to look like a real session's before this
--- addon's files get their one chance to read it.
local function loadPartial(omit, mutate)
  local m = buildMocks()
  local ns = {}
  Loader.addonName = "PanelMaster"
  local libs = {}
  for _, path in ipairs(LIB_FILES) do
    if not omit[path:match("([^/]+)%.lua$")] then libs[#libs + 1] = path end
  end
  Loader.loadAll(libs, ns, m)
  if mutate then mutate(m, ns) end
  Loader.loadAll(Loader.tocFiles("PanelMaster.toc"), ns, m)
  ns.addon:OnInitialize()
  ns.addon:OnEnable()
  return ns, m
end

--- The whole library absent — the empty end of the same partial list, and the state a player who
--- never copied libs/ is actually in.
local function loadDegraded()
  local everything = {}
  for _, path in ipairs(LIB_FILES) do everything[path:match("([^/]+)%.lua$")] = true end
  return loadPartial(everything)
end

return {
  LIB_FILES    = LIB_FILES,
  loadPartial  = loadPartial,
  loadDegraded = loadDegraded,
}
