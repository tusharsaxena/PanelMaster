# 03 — Evidence (2026-08-04)

Every finding in `02_DEVIATIONS.md` is backed here, and every mechanical check was **run** rather
than reasoned about. Commands were executed from the repo root
(`/mnt/d/Profile/Users/Tushar/Documents/GIT/PanelMaster`) unless stated.

---

## 0. Standard provenance

```
$ cd /mnt/d/Profile/Users/Tushar/Documents/GIT/WowAddonStandards && git status --porcelain && git log -1 --format='%H %s'
214122996c6c2db2e1c4a88a1f5d152dce2de928 v2.17.1 — finish the v2.17.0 rollout: no fourth slot, no drop-in imperative
```

(empty `git status --porcelain` → clean tree)

```
$ curl -fsSL --max-time 15 -o AUDIT.md    .../master/AUDIT.md              ; echo rc=$?   -> rc=0
$ curl -fsSL --max-time 15 -o STANDARDS.md .../master/standards/STANDARDS.md; echo rc2=$? -> rc2=0
$ for f in <24 names discovered from the STANDARDS.md Sections list>; do
    curl -fsSL --max-time 15 -o fresh/$f.md ".../master/standards/standards/$f.md" & done; wait
  -> 24/24 retrieved
$ diff -r fresh /mnt/.../WowAddonStandards/standards/standards/ && echo BYTE_IDENTICAL
BYTE_IDENTICAL
$ diff STANDARDS.md /mnt/.../WowAddonStandards/standards/STANDARDS.md && echo STD_IDENTICAL
STD_IDENTICAL
$ diff AUDIT.md /mnt/.../WowAddonStandards/AUDIT.md && echo AUDIT_IDENTICAL
AUDIT_IDENTICAL
```

Standard version line, `STANDARDS.md:1`:
`# Ka0s WoW Addon Standard (v2.17.1, 2026-08-03)`

`tiered-layout.md` returned HTTP 404. Confirmed **not a live section**: `grep -n 'tiered-layout' STANDARDS.md`
returns only lines `114`, `124`, `127` — all inside frozen changelog entries recording the v2.0.0
rename to `layout.md`. The live Sections list names 24 files; all 24 were fetched and verified.

---

## 1. `luacheck .` — MUST be 0 errors (`lint`, `testing-§2/§4`)

```
$ luacheck .
Checking core/Compat.lua        OK
... (25 files) ...
Checking settings/Slash.lua     OK

Total: 0 warnings / 0 errors in 25 files
EXIT=0
```

**Result: pass.** `libs/`, `tests/`, `docs/audits/`, `docs/reviews/` are excluded per
`.luacheckrc:4`, as the standard's template specifies.

## 2. `lua tests/run.lua` — the green gate (`testing-§4`)

```
$ lua tests/run.lua
...
  PASS  libs/LibKa0s is the LibKa0s release the README says this addon bundles
  PASS  tests/_kit is the test kit that shipped with that release

696 passed, 0 failed, 696 total
```

**Result: pass, 696/696.** Matches `docs/test-cases.md`'s generated total (`| **Total** | **696** |`)
and the README badge `Tests-696%2F696_passing` (`README.md:6`) — the three are in lockstep
(`testing-§5`).

## 3. Vendored Ka0s-owned library drift (`library-stack-§7`, anti-patterns #45 / #48)

The only Ka0s-owned vendored library is `LibKa0s`. Its source repo was located as a sibling and
confirmed (`CHANGELOG.md`, `LICENSE`, `LibKa0s/` ship folder, `README.md`, `docs/`, `testkit/`,
`tests/`):

```
$ ls /mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s
CHANGELOG.md  LICENSE  LibKa0s  README.md  docs  testkit  tests
```

**Ship payload — MUST be empty:**

```
$ diff -r /mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s/LibKa0s \
          /mnt/d/Profile/Users/Tushar/Documents/GIT/PanelMaster/libs/LibKa0s
$ echo SHIP_DIFF_EXIT=$?
SHIP_DIFF_EXIT=0
```

**Vendored headless harness — MUST be empty:**

```
$ diff -r /mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s/testkit \
          /mnt/d/Profile/Users/Tushar/Documents/GIT/PanelMaster/tests/_kit
$ echo KIT_DIFF_EXIT=$?
KIT_DIFF_EXIT=0
```

**Result: both empty — no drift, no partial vendoring.** No output at all from either `diff -r`,
which also proves no file is missing on the addon side. The harness lives under `tests/_kit/` and
**not** under `libs/`, as required.

Whole-folder confirmation of the ship payload (all eight files of the five majors present, including
the two the addon does not wire):

```
$ ls libs/LibKa0s
Core.lua  DebugLog.lua  LICENSE  LibKa0s.xml  Options.lua  OptionsScroll.lua
OptionsWidgets.lua  Perf.lua  PerfPanel.lua  Slash.lua
```

TOC lists the single aggregate once — `PanelMaster.toc:29`:

```
libs\LibKa0s\LibKa0s.xml
```

No individual `LibKa0s` `.lua` file appears in the TOC.

## 4. PM-007 — the slash degradation stub omits `Sl.FormatKV` (`slash-commands-§1`)

**Static evidence.** The stub branch opens at `settings/Slash.lua:273` and returns at `:304`:

```
273  if not lib then
...
303  end
304  return
305  end
```

`Sl.FormatKV` is assigned only at `settings/Slash.lua:369`, i.e. after that `return`:

```
369  Sl.FormatKV = lib.FormatKV
```

Host-owned code that calls it — none of which is behind a library guard:

```
settings/Slash.lua:101      lines[#lines + 1] = "  " .. Sl.FormatKV(field, NS.Registry.FormatField(rec, field))
settings/Slash.lua:156        print(Sl.FormatKV("width", tostring(w)))
settings/Slash.lua:157        print(Sl.FormatKV("height", tostring(h)))
settings/Slash.lua:169      print(Sl.FormatKV(field, NS.Registry.FormatField(rec, field)))
settings/Slash.lua:176      print(Sl.FormatKV(field, NS.Registry.FormatField(NS.Registry:Get(rec.id), field)))
```

**Mechanical evidence — reproduced, not inferred.** A read-only probe (written to a scratch path
outside the repo, run with the repo as cwd) loads the addon through the addon's own kit loader with
no `libs/` entries — the same `loadDegraded` shape `tests/test_libka0s.lua:44-52` uses — then drives
a panel verb:

```
$ lua $SCRATCH/degraded_formatkv.lua
Sl.FormatKV in degraded install = nil
CliPanel ok=false  err=settings/Slash.lua:101: attempt to call field 'FormatKV' (a nil value)
BuildPanelShowLines ok=false  err=settings/Slash.lua:101: attempt to call field 'FormatKV' (a nil value)
```

**Why the suite is green anyway.** The seven degraded cases at `tests/test_libka0s.lua:480-577`
cover the printer, the cause clause, the announce-once behavior and the console — none drives a
`/pm panel` verb, so nothing reaches `:101`. This is precisely the failure the stub-coverage rule
describes: a crash relocated to a rarer code path.

The 2026-08-03 review proposed exactly this fix as **C-01**
(`docs/reviews/2026-08-03/02_PROPOSED_CHANGES.md:98`) and its summary describes it as landed
(`.../05_FINAL_SUMMARY.md:44-46`), but the change is **not in the code**: the review bundle is
untracked and `git log --oneline -3 -- settings/Slash.lua` shows the file's last three commits are
`0562030`, `cd660f0`, `4ead483` — none of them the review's. The finding is therefore live.

## 5. PM-001 / PM-002 / PM-003 / PM-004 / PM-005 / PM-006 / PM-012 — the performance cluster

```
$ ls core/PerfSetup.lua tests/perf.lua docs/performance.md docs/perf-runs
ls: cannot access 'core/PerfSetup.lua': No such file or directory
ls: cannot access 'tests/perf.lua': No such file or directory
ls: cannot access 'docs/performance.md': No such file or directory
ls: cannot access 'docs/perf-runs': No such file or directory
```

```
$ grep -rn "LibKa0s-Perf\|NS.Perf\|debugprofilestop\|suspend\|Suspend" core defaults locales modules settings
(no matches)
```

TOC, `PanelMaster.toc:7` — one SavedVariables global where the standard requires two:

```
## SavedVariables: PanelMasterDB
```

`.luacheckrc:9-21` (`read_globals`) contains no `debugprofilestop`; `.luacheckrc:22-27` (`globals`)
contains `PanelMasterDB` and `StaticPopupDialogs` but no `PanelMasterPerfDB`.

`NS.COMMANDS` verbs, `settings/Slash.lua:202-255` — `config, new, delete, rename, panels, panel,
unlock, lock, preview, recover, version, get, set, list, reset, resetall, debug, help`. **No `perf`.**

**The non-adoption is recorded, which is why it is catalogued rather than reported as an oversight.**
`CLAUDE.md:33-34`:

> Four of the five majors are adopted (`Core`, `DebugLog`, `Slash`, `Options`); `Perf` is declined.

and `docs/pending/LEDGER.md:117` (row `LIBKA0S-31`, status `wont-do`) carries the full reasoning —
every event the addon registers is `PLAYER_LOGIN` / `PLAYER_ENTERING_WORLD` / `PLAYER_REGEN_ENABLED`,
none of which fires during combat, so most buckets would read `0.000`. That is a real argument, and
it belongs in the record; it is not, however, a dispensation the standard grants — `performance-§1`
makes the **wiring** a MUST independently of coverage, and `slash-commands-§2` reserves `perf`
collection-wide. Classification is the user's call per `CLAUDE.md`'s own accepted-deviation clause.

The library files themselves are correctly present (`libs/LibKa0s/Perf.lua`, `PerfPanel.lua`) — the
ship payload is whole, so this is a non-adoption, **not** anti-pattern #48.

## 6. PM-008 — pre-built printer arguments (`events-frames-taint-§8`)

```
$ grep -rn 'print((\|print(".*"\s*\.\.\|print(.*):format(\|NS\.Print(.*\.\.' --include="*.lua" core defaults modules settings | wc -l
24
```

Two of those 24 are the printer's own definition (`core/CoreSetup.lua:55`) and are not call sites,
leaving ~22 chat sites. Representative lines:

```
settings/Slash.lua:15    print(("deleted %d %s."):format(n, n == 1 and "panel" or "panels"))
settings/Slash.lua:48    if not rec then print("error: " .. tostring(err)); return end
settings/Slash.lua:49-50 print(("created panel '%s' (id %d). Use |cffffff00/pm unlock|r to place it."):format(...))
settings/Slash.lua:71    print(("renamed '%s' to '%s'"):format(tostring(result), NS.Util.CleanName(new)))
settings/Slash.lua:165   print(("unknown field '%s'. Try: %s"):format(field, table.concat(C.PANEL_FIELD_ORDER, ", ")))
settings/Slash.lua:287   function Sl:CliVersion() print("v" .. tostring(Sl:Version())) end
settings/Slash.lua:301   print("unknown command '" .. tostring(verb) .. "'")
settings/PanelEditor.lua:91,104,118,125   print("error: " .. tostring(err|result))
settings/Schema.lua:171  print("schema path missing default: " .. tostring(row.path))
core/DebugLogSetup.lua:114 NS.Print("debug logging " .. (on and "|cff40ff40ON|r" or "|cffff4040OFF|r"))
settings/Slash.lua:225   NS.Print("preview " .. (on and "on" or "off"))
```

Debug-sink sites pre-stringifying their varargs, which defeats the library's `safeToString` routing:

```
settings/Schema.lua:144   NS.Debug("Set", "%s = %s", tostring(path), tostring(value))
modules/Registry.lua:641  NS.Debug("Panel", "fit '%s' to artwork: %sx%s -> %sx%s", rec.name, tostring(beforeW), ...
settings/Panel.lua:218    NS.Debug("Panel", "%s failed: %s", tostring(tag), tostring(err))
```

Note `settings/Slash.lua:165` reaches `table.concat` directly at a chat call site — the one operation
a combat-protected value raises on. Today its argument is a constant field list, so it cannot raise;
the rule is written to make that reasoning unnecessary. The 2026-08-03 review reached the same
conclusion and routed it here rather than sweeping it
(`docs/reviews/2026-08-03/05_FINAL_SUMMARY.md:234-238`).

## 7. PM-009 / PM-010 — README structure (`documentation-§1`)

`README.md:489-493`:

```
## Version History

| Version | Notes |
|---|---|
| 0.1.0 | First release. Create, place and style backdrop panels; ... |
```

No **Date** column (mandated shape: `Version | Date | Highlights`).

`README.md:143-149`:

```
### Settings panel

| Setting | What it does |
|---|---|
| Enable panels | Master switch. ... |
```

A per-setting table where `documentation-§1` item 7 mandates a `Tab | Covers` table, one row per
settings subcategory.

Section order is otherwise canonical — H1 (`:1`), badges (`:3-6`), logo (`:11`), description,
`## What's new in 0.1.0` (`:28`), `## Screenshots` (`:63`), `## Usage` (`:70`) with
`### Slash commands` (`:72`) and `### Settings panel` (`:143`), `## How panels work` (`:205`),
`## FAQ` (`:399`), `## Troubleshooting` (`:427`), `## Issues and feature requests` (`:484`),
`## Version History` (`:489`). The extra addon-specific `## Panel artwork` (`:237`) sits between the
"How it works" and FAQ sections and does not disturb the relative order of any required section.

CurseForge-renderer rules checked and **clean**: `grep -n '<[a-z][a-z0-9 _-]*>' README.md` returns
nothing (no angle-bracket placeholders), and the standard badge at `README.md:5` uses `_` not `%20`.
The `[wow]` badge reads `WoW-Midnight_12.0.7-purple`, in lockstep with `## Interface: 120007`.

## 8. PM-011 — complexity report

```
$ ls docs/
ARCHITECTURE.md  artwork-spec.md  audits  pending  reviews  smoke-tests.md
superpowers  test-cases.md  testing.md
```

No `complexity.md`. Largest authored files, from `wc -l`:

```
1087 modules/Artwork.lua
1064 settings/PanelEditor.lua
 848 modules/Registry.lua
 706 modules/Canvas.lua
```

All under the 1500 hard cap (`layout-§1`); the top two are in the 1000–1500 "on notice" band.

---

## Evidence for the compliance claims

### Shared subsystems — descriptors and stubs, not implementations

Per `AUDIT.md` step 6, these cite the **addon's setup files**, never the library's source.

- **Core** — `core/CoreSetup.lua:32` `local lib = LibStub and LibStub("LibKa0s-Core-1.0", true)`;
  descriptor at `:83` `local printer = lib:New({ prefix = NS.PREFIX })`; republished at `:75-76,85-92`;
  stub branch `:34-70` answering the four members `grep` finds (`NS.IsConcatSafe`, `NS.SafeToString`,
  `NS.Print`, `NS.Util.print`), with the concat probe reproduced because losing it would turn a
  secret into a Lua error.
- **DebugLog** — `core/DebugLogSetup.lua:79` guarded lookup; descriptor `:127-182`; bare sink bound
  at `:189` (`NS.Debug = NS.DebugLog.Debug`); stub `:81-125`. Members the addon actually calls,
  from `grep -rhoE 'NS\.DebugLog[:.][A-Za-z_]+' core modules settings`: `Debug`, `Add`, `Diagnose`,
  `Hide`, `IsShown`, `SetEnabled`, `Show`, `Toggle` — **all eight answered** by the stub
  (`:97-116`, `:118-123`), plus `Clear`, `ShowCopy`, `BufferSize`, `LastLine`, `FindLine`,
  `UpdateScrollBar`, `UpdateStatus`, `RefreshHeader` answered defensively. Each omitted descriptor
  field is justified in writing at `:163-181`.
- **Options** — `settings/OptionsSetup.lua:26` guarded lookup; descriptor `:63-132`;
  `NS.Helpers = lib:New(...)` **is** the instance (`:63`). The stub (`:28-61`) is deliberately
  **load-completing rather than member-answering**, which is the standard's one documented exception
  (`options-ui-§1`): it publishes `LSMValues` returning a closure over `{}` (`:48`), sets the three
  layout constants to **zero** rather than plausible values (`:56`, with the reason written at
  `:31-34`), and no-ops the rest. Cross-checked against every member the addon reaches —
  `AceGUI, AddSpacer, AttachTooltip, BUTTON_PAIR_REL, ClearScroll, CreateOptionsPanel, CreatePanel,
  EnsureDefaultsButton, EnsureScroll, InlineButtonPair, LSMValues, OpenOptionsPanel,
  PatchAlwaysShowScrollbar, ROW_VSPACER, RefreshScalars, RegisterOptionsPage, RenderField,
  RenderRows, RenderSchema, RestoreAllDefaults, SECTION_HEADING_H, Section, SetRenderer` — **all
  present** in the stub table. This is **not** flagged.
- **Slash** — `settings/Slash.lua:271` guarded lookup; descriptor `:307-348` including the two
  written-up adapters (`groupKey`, `parse`) and a plain `L` table rather than `NS.L` (the "L trap");
  stub `:273-305`. Members reached from outside the file — `Register`, `CliRecover`, `CliResetAll`,
  `LandingRows`, `HelpRows`, `Version` — are all answered; **`FormatKV` is the single gap**, and it is
  PM-007.
- **Test harness** — `tests/_kit/` (vendored, byte-identical per §3), `tests/wow_mock.lua` extending
  `mock_base.lua`, `tests/run.lua` deriving the addon's list from the TOC. Pinned by
  `tests/test_harness.lua` ("the runner derives the addon's load list from the TOC", "the shared kit
  is present and is reached through tests/_kit", "wow_mock extends the kit's mock_base rather than
  replacing it") — all green in §2.

No addon-owned console, widget maker, flow engine, dispatcher, parser or test framework exists:
`ls modules/` returns only `Artwork.lua Canvas.lua Registry.lua SunnArt.lua SunnArtPacks.lua
Unlock.lua`. Anti-pattern #47 is **clear**, and the absence of those files is the evidence of
compliance rather than of a gap.

### Architecture

```
core/PanelMaster.lua:4   local addon = AceAddon:NewAddon(NS, addonName, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")
core/PanelMaster.lua:13  if NS.Util and NS.Util.print then NS.Print = NS.Util.print end
core/PanelMaster.lua:20-26  function NS.NewBusTarget() ... AceEvent:Embed(t) ... end
modules/Canvas.lua:705   ev:RegisterMessage("Ka0s_PanelMaster_SettingsChanged", function() Canvas:RenderAll() end)
settings/Schema.lua:20   local MSG_SETTINGS = "Ka0s_PanelMaster_SettingsChanged"   -- sole sender
modules/Registry.lua:19-20  local MSG_PANELS / MSG_PANEL                            -- sole sender
docs/ARCHITECTURE.md:279-309  message table: name | sender | payload | consumers
```

`grep -rn '_G\[addonName\]\|_G\[NS.name\]' core modules settings` → no matches (anti-pattern #1 clear;
`public-api` N/A).

### Options / combat / preview

```
core/PanelMaster.lua:37     if NS.Panel and NS.Panel.Register then NS.Panel:Register() end   -- eager
core/PanelMaster.lua:51-53  self:RegisterEvent("PLAYER_LOGIN", ... Register ...)             -- retry, not a deferral
settings/Panel.lua:488      if InCombatLockdown and InCombatLockdown() then return O.OpenOptionsPanel() end
modules/Unlock.lua:114,222  combat-gated unlock, replayed on PLAYER_REGEN_ENABLED (core/PanelMaster.lua:89-91)
settings/Schema.lua:43-48   state.preview row -> NS.Unlock:SetPreview (preview-mode)
```

### SavedVariables / migrations

```
core/Database.lua:18   NS.db = LibStub("AceDB-3.0"):New(addonName .. "DB", NS.defaults, true)
core/Namespace.lua:14  NS.SCHEMA_VERSION = 2
core/Database.lua:84-116  NS:RunMigrations() with a real v1 -> v2 body
core/Database.lua:128-135 NS.InitSummary() -> the [Init] line the DebugLog descriptor supplies
```

### Docs / standards references

```
PanelMaster.toc:12   ## X-Standard: https://github.com/tusharsaxena/WowAddonStandards
README.md:5          [![Standard](...Ka0s-WoW_Addon_Standard-yellow)](https://github.com/tusharsaxena/WowAddonStandards)
CLAUDE.md:6-23       ## Standards compliance (read first)  — verbatim in substance
CLAUDE.md:44-59      "docs/agent-context.md does not exist in this repo and MUST NOT be created."
```

`ls docs/agent-context.md` → no such file (anti-pattern #49 clear).

### Localization

```
locales/enUS.lua:6   NS.L = setmetatable(NS.L or {}, { __index = function(_, k) return k end })
locales/enUS.lua:8-14 the documented 0.1.0 English-only scope decision (PM-013)
```

`tests/test_spelling.lua` — three cases, green in §2, including *"the TOC and run.lua between them
name every authored source"*, so the US-English sweep cannot silently stop covering a file
(`localization-§5`, anti-pattern #46).

---

## Checks not run

None. Both `diff -r` checks had their sibling repo present and were executed; `luacheck` and the
headless runner were executed; the degraded-path finding was reproduced rather than inferred.

`docs/smoke-tests.md` catalogs the in-game checks that complement this suite; no live client was
available to this run, so nothing in this bundle asserts on in-client rendering.
