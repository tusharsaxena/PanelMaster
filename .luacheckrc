std = "lua51"
max_line_length = false
codes = true
-- libs/ holds vendored code, including libs/LibKa0s/, whose upstream is the LibKa0s repo and which
-- is linted THERE as source. tests/_kit/ is that same fact one level down: it is a byte copy of the
-- library's testkit/, so linting the copy as well would report every finding twice and let the copy
-- drift green while the original went red -- the one state tests/test_vendor_sync.lua exists to
-- forbid. That reason reaches the vendored copy and nothing else: the rest of tests/ is ours, and
-- it is linted (lint.md).
-- Under docs/ only the FROZEN evidence bundles are excluded. A blanket docs/ exclude would silently
-- drop any Lua a future doc directory carries out of the gate.
exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/_kit/" }
-- NO TOP-LEVEL `ignore`, and none is coming back (lint.md, `M4-11`). This file carried
-- `ignore = { "212/self", "212/event" }` until `M4c-06`. Both entries already named a variable,
-- which is narrower than most blankets start out, and it still reached all 56 files the tree then
-- had: the ten that earn a 212 and the forty-six that do not. Removing the two lines reported
-- 101 findings, every
-- one of them `212/self`, and NOT ONE of them `212/event` -- that half of the blanket had been
-- silencing nothing at all, which is the plainest statement there is of what a blanket is worth.
-- It is deleted rather than re-homed.
--
-- The 101 are answered by the per-file stanzas at the foot of this file, one per file that earns
-- one, each naming the obligation that forces the receiver. What the blanket sat NEXT to was
-- fixed at source in the same commit rather than moved into a stanza: eighteen files opened
-- `local addonName, NS = ...` over a folder name they never read, each behind its own inline
-- `-- luacheck: ignore addonName`, and now open `local _, NS = ...`; locales/PostLoad.lua, which
-- read neither name, lost the header outright.
--
-- tests/test_lintconfig.lua is what keeps the blanket from re-entering.
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

-- ---------------------------------------------------------------------------
-- The narrowed 212s (lint.md, `M4c-06`)
-- ---------------------------------------------------------------------------
--
-- Every stanza below names ONE file, and every entry inside it names the code AND the variable, in
-- luacheck's `<code>/<variable>` form. That is the whole difference from the blanket this replaced:
-- an unused argument under any other name -- in these ten files or in the other forty-six -- still
-- reports, and so does an unused `self` in any file with no stanza. Measured rather than assumed:
-- a no-op `function NS.Util:DeadProbe()` appended to core/Util.lua -- a file with no stanza --
-- reports `core/Util.lua:264:17: (W212) unused argument 'self'` under this config and reported
-- nothing at all under the blanket. A dead argument under a NEW name was already caught by the
-- old entries, which were `<code>/<variable>` themselves; the file scope is what changed.
--
-- Every one is a receiver a CALLING CONVENTION forces on a body that has no use for it, which is
-- the only shape that earns a stanza. The convention here is one the addon states out loud and its
-- callers depend on: a module publishes its surface on a table hung off `NS`, and the call sites
-- reach it as `if NS.X and NS.X.Method then NS.X:Method() end` -- the load-order probe that lets
-- one file fail to load without taking its callers down with it. A probe needs the member ON the
-- table, and a colon call hands the table over whether the body reads it or not. Dot-form
-- functions would answer the lint and break every probe, which is why these are narrowed and not
-- rewritten. Anything that is NOT that shape -- a name this addon chose to bind and then never
-- read -- is dead code, and `M4c-06` deleted nineteen of those rather than listing them here.

-- The four database entry points publish onto `NS` itself and are reached by the name every other
-- file already holds: `NS:InitDB()` (core/PanelMaster.lua:32), and `NS:RunMigrations()`,
-- `NS:SweepPreviewPanels()`, `NS:RegisterProfileCallbacks()` from InitDB's own body (:19-:21) and
-- from the profile callback at :79. The receiver and the file's `NS` upvalue are the same table,
-- so the bodies read the upvalue; the colon is what the call sites are written with.
files["core/Database.lua"] = {
  ignore = { "212/self" },
}

-- The degradation arm, plus one method attached to both arms. Fifteen stubs stand in for the
-- LibKa0s-DebugLog-1.0 instance when the library is absent, and their member set is not this
-- addon's to choose: tests/test_surface_parity compares it against the live instance as a SET,
-- and every caller -- `NS.DebugLog:IsShown()` on settings/Schema.lua's console row,
-- `NS.DebugLog:Show()` from the slash verb -- reaches whichever arm loaded through the same colon
-- call. A stub that answers nothing still has to accept the receiver the live method accepts.
-- The sixteenth is `D:Diagnose` (:82), defined once and attached to BOTH arms (:155, :249)
-- because it reads the addon's own state rather than the window's, so it too is called on a
-- table it does not need to read.
files["core/DebugLogSetup.lua"] = {
  ignore = { "212/self" },
}

-- AceEvent-3.0 invokes a handler registered by NAME as `self[handler](self, event, ...)`, so the
-- three handlers registered at core/PanelMaster.lua:72-:76 receive the addon object they are
-- already defined on. The two colon methods in this file that DO read `self` -- OnInitialize and
-- OnEnable, which call `self:RegisterEvent` -- are why the entry is `212/self` and not a file-wide
-- switch: they prove the code is checked here, not waived.
files["core/PanelMaster.lua"] = {
  ignore = { "212/self" },
}

-- The renderer, reached through four probes in core/PanelMaster.lua alone (:61 Enable, :84
-- RenderAll, :94 and :102 RenderForCombat) because Canvas is the one module whose absence the boot
-- path is written to survive. The frame map and the pool are this file's own upvalues, not fields
-- of the published table, so no body has a use for the receiver.
files["modules/Canvas.lua"] = {
  ignore = { "212/self" },
}

-- The panel registry's one writer (architecture-§5, named in docs/ARCHITECTURE.md -> Settings
-- Schema), and the most-called table in the addon. Records live in `NS.db.profile`, which every method reaches through the
-- file's `NS` upvalue, so the receiver is spare in all nineteen; the colon is what the call sites
-- and the probe at core/Database.lua:80 are written with.
files["modules/Registry.lua"] = {
  ignore = { "212/self" },
}

-- The unlock overlay, probed from three files rather than one -- core/PanelMaster.lua:93
-- (ResumePending, the deferred combat replay), modules/Canvas.lua:756 and :802 (StripOverlay and
-- Decorate, on every frame release and every render) and modules/Registry.lua:573 (ForgetPending).
-- Overlay state is a file-scope table here, which is why no body reads the receiver.
files["modules/Unlock.lua"] = {
  ignore = { "212/self" },
}

-- The settings page. `Register` and `Refresh` are both probed rather than called outright --
-- core/PanelMaster.lua:37 and :52 for the first, core/DebugLogSetup.lua:197 for the second -- so
-- that a missing options library costs the page and nothing else.
files["settings/Panel.lua"] = {
  ignore = { "212/self" },
}

-- The Panels page's four published verbs. Three are called from settings/Panel.lua (:438 WireBus,
-- :462 BuildPage, :464 Rebuild) with the page context as the argument, and ForgetSelection is
-- probed from modules/Registry.lua:576 so a delete can clear the editor's selection without
-- depending on the editor having loaded. The selection itself is this file's upvalue.
files["settings/PanelEditor.lua"] = {
  ignore = { "212/self" },
}

-- The schema seam, and the one place the calling convention is written down in another repository:
-- settings/OptionsSetup.lua:169-:171 hands `function(path) return NS.Schema:Get(path) end` and its
-- two siblings to the LibKa0s-Options descriptor, and core/PanelMaster.lua:33 probes `Register`.
-- The schema table is a file-scope array; the receiver is the addon's own convention around it.
files["settings/Schema.lua"] = {
  ignore = { "212/self" },
}

-- Two arms of one table again, and tests/test_surface_parity compares them the way it compares the
-- DebugLog stubs -- except that here BOTH arms are this addon's, because `NS.Slash` republishes the
-- LibKa0s-Slash dispatcher's verbs beside host-owned ones rather than being the dispatcher. Twenty
-- seven methods across the two arms, every one reached by colon: `NS.Slash:Register()` behind the
-- probe at core/PanelMaster.lua:34, `NS.Slash:ConfirmResetAll()` behind the one at
-- settings/Panel.lua:333, and the verbs themselves through the COMMANDS table.
files["settings/Slash.lua"] = {
  ignore = { "212/self" },
}
