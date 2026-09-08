-- tests/test_surface_parity.lua — every degradation stub carries the whole live surface.
--
-- Four LibKa0s seams are adopted — Core, DebugLog, Slash, Options — and each setup file carries an
-- `if not lib then` branch whose member set is what a library-less install actually runs on. A stub
-- is a second implementation of somebody else's surface, so it drifts the moment the live half
-- grows a member the host starts calling: the live path stays green and the degraded path raises in
-- exactly the install the stub exists for. That is not hypothetical here. `Sl.FormatKV` was
-- assigned at the foot of settings/Slash.lua and not in the degraded branch, so `/pm panel <name>`
-- raised "attempt to call field 'FormatKV' (a nil value)" from `Sl:CliPanel`, which prints every
-- field through it. A presence check over the
-- members somebody remembered misses that exactly as the branch did; only a SET comparison catches
-- it, which is `Kit.assertSurfaceParity`.
--
-- Two rules every case here follows, both from testing-§8:
--
--   * The degraded arm comes from a REAL LOAD with a partial file list (tests/degraded_env.lua),
--     never from a hand-written stub. Hand-stubbing `lib = nil` inside a seam tests a branch rather
--     than an install, and hand-stubbing the member under test asserts the test author's typing.
--   * Where a member is live-only ON PURPOSE it is named in the `ignore` set with its reason,
--     because otherwise a deliberate omission and a bug read identically.
--
-- TWO SEAMS CALL THE KIT'S BY-NAME FORM AND TWO DO NOT, and which is which is the thing to get
-- right rather than a style choice.
--
-- `assertSurfaceParity(stub, major, ignore)` arrived with kit 15 and was vendored by M4-01. What it
-- changes is which keys of the live half get walked: it compares only `Kit.publicMembers`, which
-- drops LibStub's own MAJOR / MINOR / MODULES and every `__`-prefixed key. Those are the library
-- talking to itself across its own file boundaries — `__bannerBand`, `__layoutTabs`,
-- `__tabPlacement`, `__print` — and a stub is obliged to carry none of them.
--
--   * DebugLog and Options use it. Both stubs stand in for an INSTANCE — what `lib:New(descriptor)`
--     returned — and `tests/run.lua` registers those two instances by major name with
--     `Kit.setSurfaceSource`, because LibStub answers the LIBRARY TABLE for the same name and that
--     is not the surface the addon's files call.
--   * Core does not, because it is not a major's surface at all: its two halves are two blocks of
--     `core/CoreSetup.lua`, and what they have in common is a set of names hung on `NS`. There is no
--     name to look up.
--   * Slash does not, for a different reason worth stating plainly: `NS.Slash` is not the library
--     instance either. `settings/Slash.lua` keeps `dispatcher` as a file-scope local and REPUBLISHES
--     its verbs onto the addon's own table beside host-owned ones (`CliResetAll`, `ConfirmResetAll`,
--     `Version`), so the two halves being compared are two versions of this addon's table. Pointing
--     the by-name form at `LibKa0s-Slash-1.0` would compare the stub against a surface it was never
--     mirroring.

local T = _G.PM_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local assertSurfaceParity = T.assertSurfaceParity

local Env = dofile("tests/degraded_env.lua")
local loadPartial = Env.loadPartial

-- ── Core ───────────────────────────────────────────────────────────────────────

test("Parity: the Core seam's degraded surface matches the live one", function()
  -- Core publishes onto NS itself rather than onto one table, so both arms are PROJECTED over the
  -- names the seam assigns. The names are DERIVED FROM THE SOURCE rather than typed here — the list
  -- used to be five hand-kept strings with a comment telling the next reader to re-run the grep,
  -- which is the hand-maintenance this whole file exists to end. The live arm's publications sit at
  -- column zero; the degradation branch's are indented inside `if not lib then`, so anchoring on a
  -- newline separates the two halves of the file without a parser:
  --   grep -nE "^NS\.[A-Za-z_]+ *=" core/CoreSetup.lua
  local f = io.open("core/CoreSetup.lua", "r")
  assertTrue(f ~= nil, "cannot open core/CoreSetup.lua (tests run from the repo root)")
  local src = f:read("*a")
  f:close()

  local degradedNS = loadPartial({ Core = true })
  local live, degraded = {}, {}
  local n = 0
  for name in src:gmatch("\nNS%.([A-Za-z_]+)%s*=") do
    if NS[name] ~= nil then
      live[name], degraded[name] = NS[name], degradedNS[name]
      n = n + 1
    end
  end
  -- A pattern that matches nothing passes this case without looking at anything, so the derivation
  -- states its own floor. Five names is what core/CoreSetup.lua published when this was written.
  assertTrue(n >= 5, "the derivation found only " .. n .. " NS publications in core/CoreSetup.lua " ..
    "— fix the pattern rather than lowering this floor")

  assertSurfaceParity(live, degraded, "Core stub", {
    -- The library instance itself. Its absence IS the degraded state; a stub standing in for it
    -- would be a second LibKa0s.
    "Core",
    -- The close-button wrapper. Its whole body is a call into the library that is not there, and
    -- nothing in this addon calls it yet — a stub answering it would be a frame factory that
    -- cannot make a frame.
    "MakeCloseButton",
  })
  -- NS.Util.print is the real name NS.Print is reclaimed from after the AceConsole embed, and it
  -- has to survive on both paths or the reclaim in core/PanelMaster.lua restores nil.
  assertTrue(type(degradedNS.Util.print) == "function", "the degraded NS.Util.print is missing")
  assertEqual(degradedNS.Util.print, degradedNS.Print)
end)

-- ── DebugLog ───────────────────────────────────────────────────────────────────

test("Parity: the DebugLog seam's degraded surface matches the live one", function()
  -- The live half is the LibKa0s-DebugLog-1.0 instance core/DebugLogSetup.lua:159 builds, which
  -- tests/run.lua registers under that name. The addon's own call sites are
  --   grep -rn "NS\.DebugLog[:.]" core modules settings
  local degradedNS = loadPartial({ DebugLog = true })
  assertTrue(degradedNS.DebugLog ~= nil, "the DebugLog degradation arm is missing")
  assertSurfaceParity(degradedNS.DebugLog, "LibKa0s-DebugLog-1.0", {
    -- Window internals with no addon caller: the console is what went away, so a stub that
    -- answered them would be pretending to own a frame it never built.
    "ConsoleCheckbox", "CopyText", "MakeCloseButton",
    -- The library's line formatters. Reproducing them in the branch is the debug-logging-§7
    -- defect, not the fix — a stub with the right member set and a hand-copied line format is
    -- exactly what a parity case cannot catch, so it is kept out rather than faked.
    "FormatColored", "FormatPlain",
    -- D.Debug is the instance method; the addon calls the BARE NS.Debug, which the branch assigns
    -- itself (core/DebugLogSetup.lua) and which is asserted below.
    "Debug",
    -- The descriptor's string accessor, forwarded on the live path for the L-trap probe in
    -- tests/test_libka0s.lua. No addon code path calls it; a stub member with no caller is the
    -- anti-pattern.
    "Text",
    -- The library's own test affordances, which it attaches to the live instance the first time the
    -- console is built — so they are present here only because tests/test_debuglog.lua ran Show()
    -- earlier in the same process. They are hooks for a test, not members the addon calls. SINGLE
    -- underscore, so Kit.publicMembers does not filter them: that exclusion is the `__` prefix.
    "_frameForTest", "_toggleClickForTest",
  })
  assertTrue(type(degradedNS.Debug) == "function", "the degraded NS.Debug is missing")
  assertTrue(type(degradedNS.DebugBuild) == "function", "the degraded NS.DebugBuild is missing")
end)

-- ── Slash ──────────────────────────────────────────────────────────────────────

test("Parity: the Slash seam's degraded surface matches the live one", function()
  -- Both halves are THIS ADDON'S NS.Slash, not the library's dispatcher — see the header. Members
  -- from:
  --   grep -rn "Slash[:.]\|Sl[:.]" core modules settings \
  --     | grep -oE "(NS\.Slash|Sl)[:.][A-Za-z_]+" | sort -u
  local degradedNS = loadPartial({ Slash = true })
  local Sl = degradedNS.Slash
  assertTrue(NS.Slash ~= nil and Sl ~= nil, "a Slash arm is missing")
  assertSurfaceParity(NS.Slash, Sl, "Slash stub", {
    -- The descriptor's string accessor, forwarded on the live path for the L-trap probe in
    -- tests/test_libka0s.lua and called by no addon code path.
    "Text",
  })

  -- The other direction, which the primitive does not walk: a stub that grew a member the live
  -- path does not have is a divergence too, and it is how a branch quietly re-implements the
  -- library.
  local extra = {}
  for name, value in pairs(Sl) do
    if type(value) == "function" and NS.Slash[name] == nil then extra[#extra + 1] = name end
  end
  table.sort(extra)
  assertEqual(#extra, 0, "the degraded slash surface grew members the live one lacks (" ..
    table.concat(extra, ", ") .. ")")

  -- And the limit the primitive states in its own docs: it cannot see a stub with the right member
  -- set and a WRONG implementation. FormatKV has no library to route to on this path, so its one
  -- line is reproduced — and pinned against the library's own so the two cannot drift.
  local libSlash = mocks.LibStub("LibKa0s-Slash-1.0", true)
  assertTrue(libSlash ~= nil, "LibKa0s-Slash-1.0 did not register on the live path")
  assertEqual(Sl.FormatKV("a.b", "7"), libSlash.FormatKV("a.b", "7"))
  assertEqual(Sl.FormatKV("a.b", "7"), "|cFFFFFF00a.b|r = |cFFFFFFFF7|r")
end)

-- ── Options ────────────────────────────────────────────────────────────────────

test("Parity: the Options seam's degraded surface matches the live one", function()
  -- The live half is the LibKa0s-Options-1.0 instance the live arm of settings/OptionsSetup.lua
  -- assigns to NS.Helpers, registered under that name by tests/run.lua. Options is ONE major over
  -- THREE files, so all three come out of the partial list together: omitting one and keeping the
  -- others leaves the major registered and half-built, which is not a state any install is in.
  --   grep -rn "NS\.Helpers[:.]\|\bO[:.]" core modules settings   names the addon's call sites.
  local degradedNS = loadPartial({ Options = true, OptionsWidgets = true, OptionsScroll = true })
  assertTrue(degradedNS.Helpers ~= nil, "the Options degradation arm is missing")
  assertTrue(degradedNS.Helpers.__degraded == true, "the Options arm did not take its stub branch")
  assertSurfaceParity(degradedNS.Helpers, "LibKa0s-Options-1.0", {
    -- The library's AceGUI handle. The branch sets the key to nil ON PURPOSE: handing back a real
    -- AceGUI with no panel to build into is worse than a nil a caller must guard.
    "AceGUI",
    -- Library-side page builders and layout this addon never calls: its landing page is its own
    -- (settings/Panel.lua), and the three layout constants it DOES read are answered by the branch
    -- as zero rather than as plausible geometry.
    "BuildLandingPage", "TextRow", "PADDING_X",
    -- WHAT IS NO LONGER ON THIS LIST, and why the change made the STUB shorter rather than this
    -- file laxer. `__print` was exempted here by hand when LibKa0s v1.27.0 published it, and the
    -- library's own comment at O.__print says a degradation stub does not mirror it BECAUSE
    -- Kit.assertSurfaceParity skips the `__` prefix — which was true of the kit's by-name form and
    -- not of the four-argument form this case used to call. On the other side of the same rule,
    -- settings/OptionsSetup.lua's stub carried twelve `__` members of its own whose only stated
    -- reason was "the parity case reads the WHOLE live surface". It does not any more, and they
    -- went with this change.
  })
  -- The three layout constants the addon reads are present and are ZERO, not the library's values:
  -- a stub reporting plausible geometry lets a caller lay something out against numbers no widget
  -- was ever built from.
  for _, k in ipairs({ "ROW_VSPACER", "SECTION_HEADING_H", "BUTTON_PAIR_REL" }) do
    assertEqual(degradedNS.Helpers[k], 0, "the Options stub reports a real-looking " .. k)
  end
end)
