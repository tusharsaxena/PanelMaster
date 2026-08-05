# 01 — Current state (2026-08-05)

**Addon:** Ka0s Panel Master (`PanelMaster`), version `0.1.0` (`PanelMaster.toc:5`), unreleased.
**Audited against:** **Ka0s WoW Addon Standard v2.21.0 (2026-08-04)**.

**Provenance of the rules.** `AUDIT.md` and `standards/STANDARDS.md` were fetched with
`curl -fsSL` from `https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`, and
**every one of the 25 section files** linked from `STANDARDS.md`'s Sections list was then fetched
from `$RAW/standards/standards/<file>.md` by following those links — `layout`, `toc-file`,
`library-stack`, `architecture`, `savedvariables`, `options-ui`, `standalone-windows`,
`preview-mode`, `slash-commands`, `localization`, `events-frames-taint`, `public-api`, `compat`,
`debug-logging`, `packaging`, `lint`, `testing`, `performance`, `automated-tests`, `documentation`,
`audit-review-history`, `versioning-git`, `naming-cheatsheet`, `anti-patterns`, `open-evolutions`.
All 25 resolved (HTTP 200, non-empty). No rule below is reconstructed from memory and no section
went unassessed. Section references use the `filename-§N` scheme; the retired global `§N.M` form is
not used.

**Scope note (affects one evidence item).** This run was constrained to the `PanelMaster`
repository plus the read-only standards repo. The playbook's `diff -r ../LibKa0s/…` vendor-drift
commands were therefore **not run**; see `03_EVIDENCE.md` ▸ *Vendored Ka0s-owned library drift* for
what was recorded in their place and why it is a substitute rather than the check itself.

---

## Layout (`layout`)

Modular layout, present and correct: `core/`, `defaults/`, `settings/`, `locales/`, `modules/`,
plus `libs/`, `media/`, `tests/`, `docs/`, `tools/`. No source file sits loose at the root. Folder
casing is lowercase throughout; Lua files are PascalCase (`core/Database.lua`,
`modules/Registry.lua`).

`media/` holds only typed subfolders — `media/artwork/`, `media/fonts/`, `media/logos/`,
`media/poster/`, `media/screenshots/` — and nothing loose (`find media -maxdepth 1 -type f` →
empty). `media/logos/` carries the runtime `.tga` beside the editable `.png`/`.jpg`;
`media/fonts/` carries `JetBrainsMono-Regular.ttf` with `OFL.txt` (the sanctioned exception,
`debug-logging-§2`).

**File sizes.** No file exceeds the 1500-LOC cap. Three sit in the 1000–1500 on-notice band:
`tests/test_artwork.lua` (1356), `modules/Artwork.lua` (1188), `settings/PanelEditor.lua` (1064).
All three carry a disposition in `docs/automated-tests/RESULTS.md`.

## TOC (`toc-file`)

`PanelMaster.toc:1-12` carries the metadata block in the mandated field order — `Interface`,
`Title`, `Notes`, `Author`, `Version`, `IconTexture`, `SavedVariables`, `OptionalDeps`,
`DefaultState`, `Category-enUS`, `X-License`, `X-Standard` — with no blank lines inside it. Single
Retail `## Interface: 120007` (`:1`), `## X-License: MIT` (`:11`), `## X-Standard:` pointing at the
standards repo (`:12`). No `## Dependencies:`. `## X-Curse-Project-ID` is absent, which is correct
for an unpublished addon.

`## SavedVariables: PanelMasterDB` (`:7`) declares **one** global; `toc-file-§2` requires exactly
two (`PanelMasterPerfDB` is missing) — see `PM-003`.

The file listing uses `#` section headers in the mandated order — `# Libraries` → `# Locales` →
`# Core` → `# Defaults` → `# Modules` → `# Settings` — and ends with a single trailing newline.
Libraries are listed one per line; `libs\LibKa0s\LibKa0s.xml` appears **once**, after Ace3
(`PanelMaster.toc:29`). No addon-authored `embeds.xml` (anti-pattern #38 clean).

## Library stack (`library-stack`)

All libraries are vendored under `libs/` and committed: LibStub, CallbackHandler-1.0, AceAddon-3.0,
AceEvent-3.0, AceTimer-3.0, AceConsole-3.0, AceDB-3.0, AceGUI-3.0, AceConfig-3.0, AceDBOptions-3.0,
LibSharedMedia-3.0, AceGUI-3.0-SharedMediaWidgets, LibKa0s. AceConfig/AceDBOptions are present
because the addon ships a Profiles sub-page, which is the sanctioned use (`options-ui-§3`).

`libs/LibKa0s/` holds the **whole** ship folder — `Core.lua`, `DebugLog.lua`, `Slash.lua`,
`Options.lua`, `OptionsWidgets.lua`, `OptionsScroll.lua`, `Perf.lua`, `PerfPanel.lua`, plus
`LibKa0s.xml` and `LICENSE`. `libs/LibKa0s/LibKa0s.xml` lists all eight `.lua` files. The two
`Perf` files are carried although the module is not wired, which is what the ship-payload rule
requires (anti-pattern #48 clean). `README.md:378` carries the provenance line
"bundles [LibKa0s](…) v1.7.0 (MIT)".

`LibStub("AceGUI-3.0", true)` is resolved in **three** places — `core/LSMPatch.lua:35`,
`settings/PanelEditor.lua:7`, `settings/Panel.lua:12` — beside the library's own `onAceGUI` seam
that already stashes it as `NS.AceGUI` (`settings/OptionsSetup.lua:98`). See `PM-021`.

## Shared subsystems — descriptors and stubs, not implementations

The addon owns **no** console window, **no** widget makers or flow engine, **no** slash
dispatcher/parser, **no** test framework, and nothing under `libs/` or `tests/_kit/` is patched.
What it owns is one setup file per adopted module, each a `LibStub(major, true)` lookup, a
descriptor, and a degradation stub:

| Module | Seam file | Lookup | Stub branch |
|---|---|---|---|
| `LibKa0s-Core-1.0` | `core/CoreSetup.lua` | `:32` | `:34-70` |
| `LibKa0s-DebugLog-1.0` | `core/DebugLogSetup.lua` | `:102` | `:104-148` |
| `LibKa0s-Slash-1.0` | `settings/Slash.lua` | `:283` | `:285-317` |
| `LibKa0s-Options-1.0` | `settings/OptionsSetup.lua` | `:26` | `:28-61` |
| `LibKa0s-Perf-1.0` | **absent** | — | — |
| test kit | `tests/_kit/` (vendored) | — | — |

`LibKa0s-Perf-1.0` is vendored but **never resolved or instantiated**:
`grep -rn "LibKa0s-Perf\|NS\.Perf\|debugprofilestop\|PerfDB\|suspend"` over `core/ modules/
settings/ tests/run.lua .luacheckrc PanelMaster.toc` returns **no hit**. `core/PerfSetup.lua` does
not exist. This is the single largest cluster of deviations in the run (`PM-001` … `PM-006`,
`PM-012`).

`CLAUDE.md:34-39` states the position plainly: four of five majors adopted, `Perf` declined.

## Architecture (`architecture`)

Every file opens `local addonName, NS = ...`; there is no `_G[addonName]` table. AceAddon is
registered with `NS` as the first argument (`core/PanelMaster.lua:4`), and the printer is
**reclaimed** from `NS.Util.print` immediately after the embed (`:13`) — the `architecture-§2`
fix, pinned by `tests/test_libka0s.lua`.

The message bus is `NS.bus = addon` (`core/PanelMaster.lua:6`) with a per-receiver target factory
`NS.NewBusTarget()` (`:20-26`); `modules/Canvas.lua:700-706` registers its three subscriptions on
its own `Canvas.__ev` target rather than on the shared bus (anti-pattern #32 clean). Messages are
`Ka0s_PanelMaster_*`-prefixed and documented in `docs/ARCHITECTURE.md:287-317`.

Schema-as-single-source is in place: one row table (`settings/Schema.lua:27-98`), one write seam
`S:Set` (`:132-147`) that both the options panel (`settings/OptionsSetup.lua:79`) and the slash CLI
(`settings/Slash.lua:332`) route through, and boot validation `S:Register` (`:163-175`) that the
library runs once via the descriptor's `validate` (`settings/OptionsSetup.lua:94`). Panel records
are a deliberate storage carve-out owned by `modules/Registry.lua` and documented as such
(`settings/Schema.lua:14-16`).

## SavedVariables (`savedvariables`)

`NS.db = AceDB:New(addonName .. "DB", NS.defaults, true)` (`core/Database.lua:18`). `schemaVersion`
is declared in `defaults/Global.lua:13` from the single constant `NS.SCHEMA_VERSION = 2`
(`core/Namespace.lua:14`), and `NS:RunMigrations()` (`core/Database.lua:84-116`) ships a real v1→v2
step. Profile callbacks are wired at `:68-78`. The second sanctioned global `PanelMasterPerfDB`
does not exist (`PM-003`).

## Options UI (`options-ui`)

`NS.Helpers` **is** the library instance (`settings/OptionsSetup.lua:63`), not a copy-across. The
descriptor supplies `parentTitle`, `mainPanelName`, `get`/`set`/`applyDefault`/`allRows`,
`rowsForPage`, `validate`, `onAceGUI`, `buildMain`, `scheduleTimer`, `print`, `debug`, with each
omission (`colorDecode`/`colorEncode`, `getLSM`, `skipRestoreAll`/`afterRestoreAll`,
`sliderCommit`, `L`) documented at `:112-131`. The category is registered **eagerly** at
`OnInitialize` with a `PLAYER_LOGIN` retry (`core/PanelMaster.lua:37,51-53`) — anti-pattern #22
clean. The combat refusal is the library's, reached from `settings/Panel.lua`; there is no second
un-gated open path.

The Options stub (`:28-61`) is **load-completing rather than member-answering**, which is the one
documented exception in `options-ui-§1` and is **not** a deviation. Every member the page files
touch at load is published, including `LSMValues` returning a closure yielding an empty table
(`:48`) and the three layout constants deliberately set to `0` rather than to plausible geometry
(`:56`, with the reason at `:32-34`).

## Standalone windows (`standalone-windows`) / preview (`preview-mode`)

The addon draws no main window of its own; its only standalone window is the debug console, which
is the library's frame wearing `Core.SKIN` — `core/DebugLogSetup.lua:186-204` documents why
`applySkin`, `makeCloseButton` and `skin` are deliberately **not** passed.

Preview mode is implemented (`NS.State.preview`, `core/State.lua:28`; `/pm preview` at
`settings/Slash.lua:234-238`; the `state.preview` schema row at `settings/Schema.lua:43-48`), feeds
placeholder panels through the real render path, and is swept on reload
(`core/Database.lua:41-57`).

## Slash commands (`slash-commands`)

Registered through AceConsole (`settings/Slash.lua:22-25`) as `/pm` + `/panelmaster`; no `SLASH_*`
globals. `NS.COMMANDS` (`:214-267`) is the host's, positional triples, passed into the descriptor
(`:322`). The cyan tag is a single shared constant `NS.PREFIX = "|cff00ffff[PM]|r"`
(`core/Namespace.lua:19`). `version` is registered and reads TOC metadata (`:31-34`). The
`FormatKV` value formatter is taken from the library (`:381`).

**The reserved `perf` verb is not registered** (`PM-002`), and the degradation stub at `:285-317`
does not publish `Sl.FormatKV`, which five host verbs call (`PM-007`).

## Localization (`localization`)

`locales/enUS.lua:6` exports `NS.L` with the key-returning metatable; `locales/PostLoad.lua` exists;
no non-enUS files ship. No user-facing string routes through `NS.L` yet — recorded at `:8-14` as an
explicit 0.1.0 scope decision (`PM-013`, advisory). Game data is matched on stable tokens, never on
localized display strings (`:16-19` states the rule; `modules/SunnArt.lua` keys on folder names and
globals). US English is enforced mechanically by `tests/test_spelling.lua` (3 cases, passing).

## Events / frames / taint (`events-frames-taint`)

AceEvent throughout; no per-module event frames. Panels are non-secure, so nothing is
combat-gated for taint; the unlock overlay refuses in combat and replays on
`PLAYER_REGEN_ENABLED` (`core/PanelMaster.lua:89-91`), which is the deferred-secure-write shape.
Frame pooling is implemented in `modules/Canvas.lua` (pool + `PooledCount`). The secret-safe
stringifier and printer are the library's, published from `core/CoreSetup.lua:75-85`.

**Approximately 25 chat/debug call sites pre-build their line with `:format()` / `..` before
reaching the shared printer** (`PM-008`).

## Compat (`compat`)

`core/Compat.lua` (178 lines) is the only file calling varying/deprecated APIs; every shim is a
direct `C_*`/global presence check with a documented nil-vs-empty distinction (`:33-52`). No
`WOW_PROJECT_ID` branching anywhere.

## Debug / logging (`debug-logging`)

`core/DebugLogSetup.lua:150-205` builds the console from a descriptor with all five required fields
(`name`, `title`, `font`, `isEnabled`, `setEnabled`) plus `print`, `initSummary`,
`onVisibilityChanged`, `slash`. The sink is bound bare (`:212`), the flag is session-only and lives
in `NS.State.debug` (`core/State.lua:10`), the `[Init]` summary rides enable
(`core/Database.lua:128-135`), and settings changes are logged once at the write seam
(`settings/Schema.lua:144`). A structured dump verb exists (`:82-100`, `/pm debug dump`).

The stub answers every member the addon calls — `Add`, `Diagnose`, `Hide`, `IsShown`, `SetEnabled`,
`Show`, `Toggle`, plus `NS.Debug`/`NS.DebugBuild` — verified by enumerating call sites. It does,
however, hand-copy the library's ack wording and its `ON`/`OFF` color escapes (`PM-022`).

## Packaging (`packaging`) / lint (`lint`)

`.pkgmeta` declares `package-as: PanelMaster`, has **no** `externals:` block, and ignores
`.luacheckrc`, `.gitignore`, `docs`, `tests`, `tools`, `_dev`, `*.bak` plus several
client-unloadable media paths, each with its reason. No `enable-toc-creation`.

`.luacheckrc` uses `std = "lua51"`, `max_line_length = false`, `codes = true`, the mandated
`exclude_files` set, and the two mandated `ignore` codes. `globals` carries `PanelMasterDB` with a
comment plus a commented `StaticPopupDialogs`. It is **missing** `debugprofilestop` from
`read_globals` and `PanelMasterPerfDB` from `globals` (`PM-006`).

## Testing (`testing`) / automated tests (`automated-tests`)

`tests/_kit/` is vendored whole (`framework.lua`, `loader.lua`, `mock_base.lua`, `README.md`,
`run-automated-tests.sh`) and sits under `tests/`, never `libs/`. `tests/wow_mock.lua` is a thin
extender over `mock_base`. `tests/run.lua:37` derives the addon's own load list from the TOC via
`Loader.tocFiles`, and `tests/test_harness.lua` pins the derivation. 21 suites, **706/706 passing**.
`docs/test-cases.md` is generated by `--list` and is byte-identical to a fresh regeneration today.

`tests/run.lua:24-31` lists only **six** of `LibKa0s.xml`'s eight files — `Perf.lua` and
`PerfPanel.lua` are omitted (`PM-017`).

`docs/automated-tests/` holds `README.md`, `RESULTS.md` and three frozen bundles
(`20260804-182223`, `20260804-215132`, `20260804-233329`), each with `manifest.json`, `ANALYSIS.md`,
`lint.txt`, `tests.txt`, `test-cases.md` and `complexity.txt`. `RESULTS.md` is one file with the
four-suite table and the two watch-list tables (warned functions: "None."; files by `layout-§1`
band, with **Band** as a column). The runner is the vendored one and `.gitattributes` carries
`*.sh   text eol=lf`. `docs/complexity.md` — retired in v2.19.0 — is **not** present. The vendored
runner is **not executable** in git (`PM-018`), and no document states the v2.21.0 **release gate**
(`PM-019`).

## Documentation (`documentation`)

**Root** carries exactly the three docs plus `LICENSE`: a full `README.md`, a stub `CLAUDE.md`
(4236 bytes, with the verbatim-in-substance `## Standards compliance (read first)` section at
`CLAUDE.md:6-23`), and `DEPENDENCIES.md` with Runtime / Development / Release-and-assets groups,
WSL2-Ubuntu commands and per-tool verification. No fourth root doc, no `TODO.md`, no
`docs/agent-context.md`.

**The `docs/` canonical trio** is present: `ARCHITECTURE.md` (1000+ lines, all mandated sections),
`testing.md`, `smoke-tests.md`.

**The five required topic-detail docs:** `test-cases.md` ✅, `automated-tests/README.md` ✅,
`automated-tests/RESULTS.md` ✅, `performance.md` ❌, `perf-runs/README.md` ❌ (`PM-005`;
`docs/automated-tests/README.md:44` links to a `../perf-runs/` that does not exist).

**The three-place standards reference** is complete: TOC `## X-Standard:` (`PanelMaster.toc:12`),
the README standard badge (`README.md:5`), and `CLAUDE.md`'s `## Standards compliance (read first)`
(`:6`). Anti-pattern #34 clean.

README structure follows documentation-§1 in order — H1, badge row (4 of 5; the published-version
badge is correctly absent pre-publish), logo, description, `## What's new in 0.1.0` immediately
above `## Screenshots`, `## Usage` with `### Slash commands` and `### Settings panel`,
`## How panels work`, `## FAQ`, `## Troubleshooting`, `## Issues and feature requests`,
`## Version History` (now a Version | Date | Highlights table, closing the prior run's `PM-009`).
`### Settings panel` is still a per-setting table rather than the mandated `Tab | Covers` table
(`PM-010`), and `## Screenshots` is a placeholder (`PM-014`, SHOULD until published). No
angle-bracket placeholders appear in shipped README content; the only `<…>` tokens are real `<br>`
tags in a table cell.

## Audit & review history (`audit-review-history`)

`docs/audits/` holds `2026-07-30` and `2026-08-04`; `docs/reviews/` holds `2026-07-30`,
`2026-08-03` and `2026-08-05`. Every prior run is retained and untouched by this one. `docs/` is
ignored by `.pkgmeta`.

## Versioning & git (`versioning-git`)

Semver `0.1.0` in the TOC and as the `NS.version` fallback (`core/Namespace.lua:7`). Trunk-based;
the working tree at the start of this run was clean apart from the untracked `docs/reviews/2026-08-05/`
bundle. The addon's own `## Version:` and the vendored library's file minors are kept as separate
axes (`CLAUDE.md:34-39`, `README.md:378`).

## Public API (`public-api`)

The addon exposes no `NS.API` surface — N/A, and correctly so.
