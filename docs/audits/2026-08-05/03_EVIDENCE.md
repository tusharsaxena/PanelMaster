# 03 — Evidence (2026-08-05)

Every claim in `01_CURRENT_STATE.md` and `02_DEVIATIONS.md` is sourced here. Mechanical checks were
**run**, not reasoned about; each records the exact command and its real output. Where a check could
not be run, it is recorded as **not run** with the reason — never inferred, never skipped silently.

Machine: WSL2 / Ubuntu. Repo root: `/mnt/d/Profile/Users/Tushar/Documents/GIT/PanelMaster`, branch
`master`, working tree clean apart from the untracked `docs/reviews/2026-08-05/` bundle.

---

## 1. Standard resolution

```
$ RAW=https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master
$ curl -fsSL "$RAW/AUDIT.md" -o AUDIT.md            # 158 lines
$ curl -fsSL "$RAW/standards/STANDARDS.md" -o STANDARDS.md   # 141 lines, "v2.21.0, 2026-08-04"
$ grep -oE '\(standards/[a-z0-9-]+\.md\)' STANDARDS.md | tr -d '()' | sed 's|standards/||' | sort -u
```

25 filenames were discovered by following the Sections links (no filename hard-coded), and all 25
fetched from `$RAW/standards/standards/<file>.md`:

```
$ ls sections/ | wc -l
25
$ wc -c sections/*.md | tail -1
 286871 total
```

Smallest `public-api.md` (802 B), largest `options-ui.md` (30650 B). No 404, no empty file.

## 2. Lint — RUN

```
$ luacheck .
...
Total: 0 warnings / 0 errors in 25 files
exit=0
```

Matches `docs/automated-tests/20260804-233329/manifest.json` → `"lint": {"status":"pass",
"warnings":0,"errors":0,"files":25}`. **No drift.**

`.luacheckrc` config: `std = "lua51"` (`:1`), `max_line_length = false` (`:2`), `codes = true`
(`:3`), the mandated `exclude_files` set (`:4`), the two mandated `ignore` codes (`:5-8`).
`read_globals` (`:9-21`) does **not** contain `debugprofilestop`; `globals` (`:22-27`) contains
`PanelMasterDB` (commented) and `StaticPopupDialogs` (commented) but **not** `PanelMasterPerfDB` —
evidence for **PM-006**.

## 3. Headless suite — RUN

```
$ lua5.1 tests/run.lua
...
706 passed, 0 failed, 706 total
exit=0
```

Matches the latest bundle's `"tests": {"passed":706,"failed":0,"total":706}` and the README badge
`Tests-706%2F706_passing` (`README.md:6`). **No drift.**

Inventory regeneration:

```
$ lua5.1 tests/run.lua --list > /tmp/tc.md
$ diff /tmp/tc.md docs/test-cases.md
(no output)
```

`docs/test-cases.md` is byte-identical to a fresh `--list`. **No drift** (`testing-§5`).

`tests/perf.lua`:

```
$ ls tests/perf.lua
ls: cannot access 'tests/perf.lua': No such file or directory
```

Evidence for **PM-004**. Consistent with the bundle's
`"perf": {"status":"skip","skipReason":"no tests/perf.lua — this addon ships no offline scenarios"}`,
which is the correct way to record it (`automated-tests-§3`).

## 4. Complexity — RUN, verbatim invocation

```
$ lizard --version
1.23.0
$ lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .
...
No thresholds exceeded (cyclomatic_complexity > 15 or length > 1000 or nloc > 1000000 or parameter_count > 100)
Total nloc   Avg.NLOC  AvgCCN  Avg.token   Fun Cnt  Warning cnt   Fun Rt   nloc Rt
     10941       7.1     2.0       55.6     1348            0      0.00    0.00
```

The invocation is the standard's, verbatim — no added flag, no narrowed path, no re-tuned threshold.

**Drift against the latest bundle (`docs/automated-tests/20260804-233329/`, stamped
`2026-08-04T23:33:29+05:30`, ~2.5 hours before this audit):**

| Figure | Bundle `manifest.json` | Re-run today | Drift |
|---|---|---|---|
| NLOC | 10941 | 10941 | none |
| Functions | 1348 | 1348 | none |
| Avg NLOC | 7.1 | 7.1 | none |
| Avg CCN | 2.0 | 2.0 | none |
| Max CCN | 15 | 15 | none |
| Warnings | 0 | 0 | none |
| Files in 1000–1500 band | 3 | 3 | none |
| Files over the 1500 cap | 0 | 0 | none |

`tail -12` of the bundle's `complexity.txt` is identical to today's footer. **No function crossed a
`lizard` threshold and no file entered the `layout-§1` band since that run.** The record is not
stale (anti-pattern #51 clean) and shows no sign of hand-editing.

Highest CCN in the addon, measured:

```
15  R.ApplyArtSize@604-632@./modules/Registry.lua
15  Compat.AddOnFolders@34-52@./core/Compat.lua
13  Artwork.BuildArtSpec@1104-1188@./modules/Artwork.lua
```

Both 15s are **defaulting/guarding density**, not tangled control flow: `Compat.AddOnFolders`
(`core/Compat.lua:34-52`) is a ladder of `type(x) ~= "function"` presence checks over two API
generations, and `R.ApplyArtSize` is a clamp/ratio chain. `performance-§10`'s reading rule applies —
`lizard` counts each `and`/`or` as a decision. Both sit exactly on the cap, so one added branch
warns; `RESULTS.md` already says so.

**Watch-list audit (`automated-tests-§4`, anti-pattern #53).** `docs/automated-tests/RESULTS.md`
carries both tables. Warned functions: **"None."** — written as a result, with the nine functions
that warned at the baseline named individually rather than counted. Files by band: three rows, each
with a **Band** column and a one-line disposition, one of which is a scheduled peel ("Split along the
catalog / geometry seam before the next feature lands in it"). Every manifest records
`"release": null`, so **no** entry has been carried as accepted across three consecutive *release*
runs. The list reads in one pass. #53 is **not** engaged.

**Artifact audit (`automated-tests`).**

```
$ git ls-files -s tests/_kit/run-automated-tests.sh
100644 30da7c0713a07740c7d91828f07fe0adb04205d4 0	tests/_kit/run-automated-tests.sh
```

Mode `100644` — **not executable**. Evidence for **PM-018**; both `docs/testing.md:111` and
`docs/automated-tests/README.md:10` document invoking it as `tests/_kit/run-automated-tests.sh`.

```
$ cat .gitattributes
# Shell scripts are LF, ALWAYS. …
*.sh   text eol=lf
```

Present and correct (`automated-tests-§2`).

```
$ ls docs/automated-tests/
20260804-182223  20260804-215132  20260804-233329  README.md  RESULTS.md
$ ls docs/complexity.md
ls: cannot access 'docs/complexity.md': No such file or directory
```

`README.md` and `RESULTS.md` both exist; the **retired** `docs/complexity.md` is correctly absent
(the v2.19.0 finding does **not** apply here). Each bundle carries `manifest.json`, `ANALYSIS.md`,
`lint.txt`, `tests.txt`, `test-cases.md`, `complexity.txt` — one file per suite that produced
output.

## 5. Vendored Ka0s-owned library drift — NOT RUN (recorded as unverified)

The playbook's two commands are:

```
diff -r ../LibKa0s/LibKa0s   libs/LibKa0s
diff -r ../LibKa0s/testkit   tests/_kit
```

**Neither was run.** This audit was invoked under an explicit single-repository constraint —
`PanelMaster` plus the read-only standards repo, no other sibling under
`/mnt/d/Profile/Users/Tushar/Documents/GIT/` — so the sibling `../LibKa0s` was not read. A
reachability probe only (`git -C ../LibKa0s show HEAD:LibKa0s/Core.lua > /dev/null`) confirmed the
sibling checkout **exists on this machine**; no content was compared. **This check is therefore
reported as unverified, not as a pass.**

What was recorded in its place, and why it is a substitute rather than the check:

- The addon carries its own byte-identity gate, `tests/test_vendor_sync.lua`, which compares the
  **file set** and then the **raw bytes** of `libs/LibKa0s/` against `git show <tag>:LibKa0s/*` and
  of `tests/_kit/` against `git show <tag>:testkit/*` in the sibling repo, where `<tag>` is read out
  of `README.md`'s provenance line rather than hardcoded (`:104-116`). Both cases ran in today's
  green suite and asserted (they are the last two lines of the run: *"libs/LibKa0s is the LibKa0s
  release the README says this addon bundles"* / *"tests/\_kit is the test kit that shipped with that
  release"*, both PASS), and the provenance line resolves: `README.md:378` reads
  "bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.7.0 (MIT)".
- **Why that is weaker than the playbook's diff.** It compares against a **tag**, not the sibling's
  working tree, so library work committed past `v1.7.0` — the very drift window `library-stack-§7`
  calls "a single afternoon" — is invisible to it. And it can go quiet: see **PM-020**.
- **Structural** evidence against anti-pattern #48 was gathered locally and is conclusive on its own
  terms: `libs/LibKa0s/` holds `Core.lua`, `DebugLog.lua`, `Slash.lua`, `Options.lua`,
  `OptionsWidgets.lua`, `OptionsScroll.lua`, `Perf.lua`, `PerfPanel.lua`, `LibKa0s.xml`, `LICENSE`
  — all five majors across all eight files, including the two the addon does not wire — and
  `libs/LibKa0s/LibKa0s.xml` lists exactly those eight in dependency order. `tests/_kit/` holds
  `framework.lua`, `loader.lua`, `mock_base.lua`, `README.md`, `run-automated-tests.sh` and sits
  under `tests/`, never `libs/`.

**Action for the next run:** execute both `diff -r` commands. An unverifiable check is reported as
unverified, and drift here is invisible to both repos' test suites.

## 6. Degraded-install reproduction — RUN (evidence for PM-007)

A read-only script in `/tmp` loaded the addon through the vendored kit with **no** `libs/LibKa0s/`
files fed to the loader — a real degraded install, not a hand-stubbed namespace (`testing-§8`):

```lua
Loader.loadAll(Loader.tocFiles("PanelMaster.toc"), NS, mocks)   -- no libs/LibKa0s/* line
NS.addon:OnInitialize(); NS.addon:OnEnable()
```

Output:

```
loaded degraded OK; NS.Slash.FormatKV = nil
                    NS.Slash.Text     = nil
created panel id 1
/pm panel audit  -> ok=false  err=settings/Slash.lua:101: attempt to call field 'FormatKV' (a nil value)
/pm panels       -> ok=true  err=nil
```

The addon **does** load and `/pm panels` **does** answer — the degradation works for most of the
surface — but `/pm panel <name>` raises. `Sl.FormatKV` is assigned once, at `settings/Slash.lua:381`,
after the stub branch returns at `:316`. Call sites: `:101`, `:124`, `:125`, `:181`, `:188`.

`Sl.Text` is likewise nil in the stub. Its only callers are tests
(`tests/test_libka0s.lua:296`, `:301`); there is no production caller, and the 2026-08-03 review
recorded a decision to leave it out — but that reason is **not written in the stub branch**
(`settings/Slash.lua:285-317` contains no mention of either member), so it does not meet the
"omitted with the reason written down" bar.

## 7. Stub coverage sweep (the other three seams) — all clean

Call sites were enumerated with `grep -rhno` over `core/ modules/ settings/ tests/run.lua` and
compared against each stub branch.

**Core** (`core/CoreSetup.lua:34-70`). Members reached: `NS.IsConcatSafe`, `NS.SafeToString`,
`NS.Print`, `NS.Util.print`. Stub publishes all four (`:44`, `:45`, `:55`, `:68`) and reproduces the
`table.concat` probe rather than a `..` probe (`:43`) — which `events-frames-taint-§8` names as the
**only** sanctioned second copy. `NS.Format` is published on the live path (`:86`) and absent from
the stub, but has no caller (`grep -rn "NS\.Format\b"` → the definition only), so nothing reaches it.

**DebugLog** (`core/DebugLogSetup.lua:104-148`). Members reached on `NS.DebugLog`: `Add`, `Diagnose`,
`Hide`, `IsShown`, `SetEnabled`, `Show`, `Toggle` — plus the bare `NS.Debug` and `NS.DebugBuild`
bindings. The stub answers all of them (`:120-139`), attaches `Diagnose` on both paths (`:146`,
`:229`), and no-ops `NS.Debug`/`NS.DebugBuild` (`:142-143`). It also answers six members nothing
calls (`ShowCopy`, `Clear`, `BufferSize`, `LastLine`, `FindLine`, `UpdateScrollBar`, `UpdateStatus`,
`RefreshHeader`) — surplus, not a gap. **Complete.**

The one defect is stylistic, not coverage: `:137` emits the ack as
`"debug logging " .. (on and "|cff40ff40ON|r" or "|cffff4040OFF|r")`, which reproduces the library's
own `ACK` / `STATE_ON` / `STATE_OFF` (`libs/LibKa0s/DebugLog.lua:68-70`) and the exact escapes it
applies at `:633-637`. Evidence for **PM-022**.

**Options** (`settings/OptionsSetup.lua:28-61`). Members reached on `NS.Helpers`/`O`: `AceGUI`,
`AddSpacer`, `AttachTooltip`, `BUTTON_PAIR_REL`, `ClearScroll`, `CreateOptionsPanel`, `CreatePanel`,
`EnsureDefaultsButton`, `EnsureScroll`, `InlineButtonPair`, `LSMValues`, `OpenOptionsPanel`,
`PatchAlwaysShowScrollbar`, `ROW_VSPACER`, `RefreshScalars`, `RegisterOptionsPage`, `RenderField`,
`RenderRows`, `RenderSchema`, `RestoreAllDefaults`, `SECTION_HEADING_H`, `Section`, `SetRenderer`.
All 23 are published by the stub (`:42-58`). This stub is **load-completing rather than
member-answering** — `OpenOptionsPanel` is the one that explains itself (`:50`) and the rest are
no-ops — which is the single documented exception in `options-ui-§1`. **Flagging it would be a false
positive, and it is not flagged.** The three layout constants are `0` rather than the library's real
values, with the reason at `:32-34`; `RestoreAllDefaults` is a no-op, which is correct here because
this addon's global reset is `Sl:CliResetAll` and the Slash stub keeps **that** genuinely working
(`settings/Slash.lua:302-305`).

## 8. Anti-pattern #47 — no hand-rolled subsystem

```
$ ls core/ modules/ settings/
core:     Compat.lua Constants.lua CoreSetup.lua Database.lua DebugLogSetup.lua LSMPatch.lua
          Namespace.lua PanelMaster.lua State.lua Util.lua
modules:  Artwork.lua Canvas.lua Registry.lua SunnArt.lua SunnArtPacks.lua Unlock.lua
settings: OptionsSetup.lua Panel.lua PanelEditor.lua Schema.lua Slash.lua
```

No `modules/DebugLog.lua`, no widget-maker file, no dispatcher/parser file, no test framework. The
addon owns descriptors and stubs only. `core/DebugLogSetup.lua:5-9` records that the previous
429-line hand-written console was deleted in favor of the library. Nothing under `libs/` or
`tests/_kit/` carries a local patch (both are gated by `tests/test_vendor_sync.lua`, §5 above).

## 9. Perf non-adoption

```
$ grep -rn "LibKa0s-Perf\|NS\.Perf\|debugprofilestop\|PerfDB\|suspend\|Suspend" \
    core modules settings tests/run.lua .luacheckrc PanelMaster.toc
(no output)
$ ls core/PerfSetup.lua
ls: cannot access 'core/PerfSetup.lua': No such file or directory
$ grep -n "SavedVariables" PanelMaster.toc
7:## SavedVariables: PanelMasterDB
```

Evidence for **PM-001**, **PM-003**, **PM-006**, **PM-012**. `NS.COMMANDS`
(`settings/Slash.lua:214-267`) contains `config, new, delete, rename, panels, panel, unlock, lock,
preview, recover, version, get, set, list, reset, resetall, debug, help` — no `perf`
(**PM-002**). `CLAUDE.md:36` states the position: "`Perf` is declined."

`docs/performance.md` and `docs/perf-runs/` do not exist (**PM-005**);
`docs/automated-tests/README.md:44` already links `../perf-runs/`.

## 10. Runner load list (PM-017)

`tests/run.lua:24-31`:

```lua
Loader.loadAll({
  "libs/LibKa0s/Core.lua",
  "libs/LibKa0s/DebugLog.lua",
  "libs/LibKa0s/Slash.lua",
  "libs/LibKa0s/Options.lua",
  "libs/LibKa0s/OptionsWidgets.lua",
  "libs/LibKa0s/OptionsScroll.lua",
}, NS, mocks)
```

`libs/LibKa0s/LibKa0s.xml` lists eight: the six above plus `Perf.lua` and `PerfPanel.lua`.
`testing-§9` requires **every** file of the library's XML, "all of them, in dependency order".

## 11. Documentation evidence

**Root doc set.** `ls -la` at root: `CLAUDE.md`, `DEPENDENCIES.md`, `LICENSE`, `PanelMaster.toc`,
`README.md` plus dotfiles and source folders. Exactly three docs plus `LICENSE`; no fourth doc, no
`TODO.md` at root.

**`CLAUDE.md` (documentation-§2).** H1 `# CLAUDE.md — Ka0s Panel Master` (`:1`); adherence line with
the repo URL (`:3-4`); `## Standards compliance (read first)` verbatim in substance (`:6-23`),
including the stop-and-flag instruction and both classifications; the read-the-docs pointer list
(`:27-32`) naming `docs/ARCHITECTURE.md`, `docs/testing.md`, `DEPENDENCIES.md`; the green-gate line
(`:41-44`). It also states there is no `docs/agent-context.md` and must never be one (`:52-67`).
All five required items present, in order.

**`DEPENDENCIES.md` (documentation-§7).** `## Runtime (in-game)` (`:20`), `## Development` (`:42`)
with `### The commands this repo is verified with` (`:72`), `## Release and assets` (`:86`) with
`### Python and its packages` (`:96`) and `### The vendored upscaler` (`:129`), plus
`### What is deliberately NOT listed here` (`:168`) and `## Keeping this file honest` (`:182`).
Runtime / development / release-only are separated as required.

**`docs/` trio.** `docs/ARCHITECTURE.md` (Overview at `:9`, Module map `:20`, Data model `:98`,
Message bus `:287`, Slash surface `:749`, Options UI `:766`, Debug console `:912`, Localization
`:928`, Taint `:953`, Known limitations `:1015`), `docs/testing.md`, `docs/smoke-tests.md`. All
three present.

**Five required topic-detail docs.** `docs/test-cases.md` ✅ · `docs/automated-tests/README.md` ✅ ·
`docs/automated-tests/RESULTS.md` ✅ · `docs/performance.md` ❌ · `docs/perf-runs/README.md` ❌
(**PM-005**).

**Three-place standards reference (documentation-§6).** `PanelMaster.toc:12` ·
`README.md:5` (`[![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)](…)`,
underscore form, not `%20`) · `CLAUDE.md:6`. All three present.

**README (documentation-§1).** Section order as rendered:

```
1:# Ka0s Panel Master          23:## What's new in 0.1.0     58:## Screenshots
62:## Usage                    64:### Slash commands        138:### Settings panel
200:## How panels work         345:## FAQ                   358:## Troubleshooting
386:## Issues and feature requests                          393:## Version History
```

Badge row (`:3-6`): `[wow]` `Midnight_12.0.7` (matching `## Interface: 120007`), `[license]`,
standard (linked), `[tests]` `706%2F706`. The published-version badge is absent, correct
pre-publish (**PM-015**). `## What's new in 0.1.0` sits immediately above `## Screenshots` and its
bullets match the top Version History row. `## Version History` at `:395-397` is
`| Version | Date | Highlights |` — **PM-009 closed**. `### Settings panel` at `:138-152` is a
per-setting table with no `Tab | Covers` table (**PM-010**). `## Screenshots` at `:58-60` is a
placeholder (**PM-014**). `grep -n '<[a-z][a-z]*>' README.md` returns one line, and its only
matches are real `<br>` tags inside a Version History cell — **no** angle-bracket placeholders in
shipped README content (documentation-§1's CurseForge rule).

**Commit gate vs release gate (PM-019).** The repo states the commit half correctly and the
release half not at all:

- `docs/testing.md:116-122` — gate table: `lint` **yes**, `tests` **yes**, `perf` *no — recorded
  only*, `complexity` *no — recorded only*.
- `docs/testing.md:123-126` — "**`perf` and `complexity` never fail a run.**"
- `docs/testing.md:131-132` — "**At release, not at commit.** A full bundle is produced as part of
  every version bump, before the tag… Commits are gated on lint + tests only."
- `docs/automated-tests/README.md:21-35` — the same table and the same "never used to fail a run"
  paragraph.
- `CLAUDE.md:46-50` — "This is a **release** step and **not** a commit gate: nothing about it may
  ever block a commit."

Nothing anywhere states `automated-tests-§3`'s *The release gate*: all four suites at `pass` and
`suites.complexity.warnings == 0` at the tag, a `skip` treated as NOT EVALUATED, evaluated by the
release command from `manifest.json` rather than by the runner's exit code. This matters here
concretely, because `perf` is a permanent `skip` (PM-004) and the sanctioned exception —
*skipped because the addon ships no `tests/perf.lua`* — "**MUST** be stated as such in the release
notes".

## 12. Miscellaneous sourced points

- **`layout-§1` LOC cap.** `wc -l` over authored source: largest is `tests/test_artwork.lua` (1356),
  then `modules/Artwork.lua` (1188), `settings/PanelEditor.lua` (1064). None over 1500.
- **`layout-§3`.** `find media -maxdepth 1 -type f` → empty; subfolders `artwork/`, `fonts/`,
  `logos/`, `poster/`, `screenshots/`. `media/fonts/` carries `JetBrainsMono-Regular.ttf` **and**
  `OFL.txt` (`debug-logging-§2`, sanctioned).
- **`packaging`.** `.pkgmeta` has `package-as: PanelMaster`, no `externals:`, and ignores
  `.luacheckrc`, `.gitignore`, `docs`, `tests`, `tools`, `_dev`, `*.bak` plus commented
  client-unloadable media paths. No `enable-toc-creation`.
- **`architecture-§2`.** `core/PanelMaster.lua:4` `NewAddon(NS, …, "AceConsole-3.0")`; `:13`
  `if NS.Util and NS.Util.print then NS.Print = NS.Util.print end`.
- **`architecture-§4`.** `NS.NewBusTarget()` at `core/PanelMaster.lua:20-26`; consumed at
  `modules/Canvas.lua:700-706` (three `RegisterMessage` calls on `Canvas.__ev`, not on `NS.bus`).
  `settings/Schema.lua:20-25` is the sole sender of `Ka0s_PanelMaster_SettingsChanged`.
- **`architecture-§5`.** Row table `settings/Schema.lua:27-98`; write seam `S:Set` `:132-147`;
  boot validation `S:Register` `:163-175`, invoked once by the library via the descriptor's
  `validate` (`settings/OptionsSetup.lua:94`) and again from `core/PanelMaster.lua:33`.
- **`options-ui-§1`.** `NS.Helpers = lib:New({…})` at `settings/OptionsSetup.lua:63` — the instance
  **is** the namespace member.
- **`options-ui-§9`.** Eager registration at `core/PanelMaster.lua:37` with a `PLAYER_LOGIN` retry
  at `:51-53`, documented at `:39-50`.
- **`slash-commands-§4`.** `NS.PREFIX = "|cff00ffff[PM]|r"` at `core/Namespace.lua:19` — cyan,
  single constant.
- **`debug-logging-§5`.** Session-only flag at `core/State.lua:10`; never in SavedVariables
  (`defaults/Global.lua` holds only `schemaVersion`).
- **`localization-§5`.** `tests/test_spelling.lua` runs three cases, including one asserting the
  matcher itself catches a British verb and spares the US noun — a falsifiability check in the
  `testing-§12` spirit. All pass.
- **`compat`.** `core/Compat.lua:1-7` states the Retail-only, presence-check-only policy;
  `grep -rn "WOW_PROJECT_ID"` → no hit.
- **`audit-review-history`.** `docs/audits/{2026-07-30,2026-08-04}` and
  `docs/reviews/{2026-07-30,2026-08-03,2026-08-05}` are all retained and were not touched by this
  run; this run writes only `docs/audits/2026-08-05/`.

## 13. Not verifiable by an audit (recorded as unverified, not as deviations)

- **`testing-§12` mutation testing.** Whether each negative-asserting case has been proven to go red
  by mutating the implementation leaves no artifact, so it is **unverified**, not a deviation. Some
  cases do carry the recommended falsification comment (`tests/test_spelling.lua`'s matcher case is
  the clearest); most do not.
- **`testing-§13` characterization tests.** The CCN work recorded in
  `docs/superpowers/plans/2026-08-04-ccn-elimination.md` and in `RESULTS.md` extracted nine warned
  functions into helpers. Ten cases were added at `20260804-215132` and `RESULTS.md` describes them
  as "the CCN work's own cover", including eight pinning `tests/wow_mock.lua`'s frame stub "which
  nothing had asserted on before that stub was rewritten". Whether each was written **before** its
  refactor and run against the unrefactored code is not recoverable from the tree; recorded as
  unverified. Spot-checking the refactor against `performance-§11`'s forbidden shapes found none of
  them: the extracted helpers carry descriptive names (no `part2`/`doTheRest`), the artwork
  fill-dispatch table is built at **file scope** rather than per call, and no `== nil` ladder was
  respelled as `or`-defaulting (anti-patterns #52/#43/#54 clean on inspection).
