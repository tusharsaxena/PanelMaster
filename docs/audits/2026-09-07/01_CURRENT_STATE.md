# 01 — Current state (2026-09-07)

**Audited against:** Ka0s WoW Addon Standard **v2.38.0 (2026-09-02)** — `standards/STANDARDS.md`
plus **all 26** section files linked from its `## Sections` list, fetched verbatim with
`curl -fsSL` from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`, and the playbook
`AUDIT.md` from the same ref. Rule set used: the **addon** sections (the repo carries
`PanelMaster.toc`, so it is an addon, not a Ka0s-owned library repo — `AUDIT.md` step 1).

**Repo:** `/mnt/d/Profile/Users/Tushar/Documents/GIT/PanelMaster`, branch `main`, HEAD
`c5b4159` *Merge branch 'feat/settings-revamp-v2'*, working tree clean.
**Addon version:** `1.0.0` (`PanelMaster.toc:5`).

---

## Layout (`layout`)

The modular layout is present and complete: `core/` (11 files), `defaults/` (2), `locales/` (2),
`modules/` (6), `settings/` (5), `libs/` (13 vendored libraries), `media/`, `tests/`, `tools/`,
`docs/`. Folder casing is lower-case throughout. `media/` holds only the addon's own product —
`artwork/` (101 pieces), `logos/`, `poster/`, `screenshots/` — with **no** `fonts/`, `icons/` or
`textures/` subfolder duplicating `libs/LibKa0s/media/` (library-stack-§8 compliant;
anti-pattern #63 not present).

Files at or above `layout-§1`'s 1000-line on-notice band today: `tests/test_artwork.lua` (1356),
`settings/PanelEditor.lua` (1350), `modules/Artwork.lua` (1188), `tests/test_panel.lua` (1076),
`tests/test_libka0s.lua` (1064). None is over the 1500 cap.

## TOC (`toc-file`)

`PanelMaster.toc:1-14` carries the metadata block in the exact mandated order —
`Interface: 120007`, `Title`, `Notes`, `Author`, `Version`, `IconTexture`,
`SavedVariables: PanelMasterDB`, `OptionalDeps`, `DefaultState`, `Category-enUS: UI`,
`X-License: MIT`, `X-Standard`, `X-Curse-Project-ID: 1642836` — with no blank lines inside it and a
single Retail `Interface`. One SavedVariables global is declared, which is correct given the
**ratified `performance-§1` decline** (see the register, below).

The file listing is `#`-sectioned (`# Libraries`, `# Locales`, `# Core`, `# Defaults`, `# Modules`,
`# Settings`) and annotates its positions (toc-file-§5). Load-bearing positions are annotated **by
what resolves**, not merely as "order matters": `libs\LibKa0s\LibKa0s.xml` after LibStub/Ace3
(`:28-30`); `core\MediaSetup.lua` before `core\Constants.lua` because `C.FONT_MONO` resolves from
`NS.MediaFont` at file load (`:43-47`, confirmed at `core/Constants.lua:616`); `core\CoreSetup.lua`
after Namespace and Util (`:52-54`); `core\DebugLogSetup.lua` after Constants and CoreSetup
(`:55-58`); `settings\OptionsSetup.lua` after Schema and Slash and before Panel (`:84-88`).
Conventional positions are marked as conventional — `core\EnvSetup.lua` (`:38-41`) says so in
words. `core/Compat.lua` and `core/LSMPatch.lua` resolve nothing at file load
(`core/Compat.lua:1-14`, `core/LSMPatch.lua:31-35`), so their positions are conventional and the
`# Core (Compat loads first)` marker (`PanelMaster.toc:36`) is the SHOULD form, not an unannotated MUST.

## Library stack (`library-stack`)

Ace3 (AceAddon, AceEvent, AceTimer, AceConsole, AceDB, AceDBOptions, AceGUI, AceConfig),
CallbackHandler, LibStub, LibSharedMedia-3.0, AceGUI-3.0-SharedMediaWidgets and **LibKa0s** are all
vendored under `libs/` and committed. No `externals:` block. `LibKa0s` is listed in the TOC as the
single aggregate `libs\LibKa0s\LibKa0s.xml` (`PanelMaster.toc:30`) — never per-module files.

**Provenance:** `CLAUDE.md:44` — `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s)
v1.25.0 (MIT).` — present in root `CLAUDE.md` and **absent** from `README.md`. Six of the ten
majors are wired (`Core`, `Env`, `Media`, `DebugLog`, `Slash`, `Options`); `Perf`, `Item`, `Pool`,
`Widgets` are declined per issue decisions #31/#45/#46/#43. Vendoring is whole-folder: both
`diff -r` checks against tag `v1.25.0` are **empty** (`03_EVIDENCE.md`).

`media/` seam: `core/MediaSetup.lua:1` takes `addonName` — the addon's own first vararg — and
`:57-59` hands it to `Media.Icon(addonName, name)`; the file loads before `core/Constants.lua`
because of the `C.FONT_MONO` resolution. No hand-typed folder constant.

## Architecture (`architecture`)

`core/Namespace.lua:1-4` bootstraps `NS`; `core/PanelMaster.lua:6` publishes the closed message bus
(`NS.bus = addon`, AceAddon/AceEvent). Three messages — `MSG_PANELS`, `MSG_PANEL`
(`modules/Registry.lua:24`), `MSG_SETTINGS` (`settings/Schema.lua:35`) — consumed at
`modules/Canvas.lua:841-843` and `settings/PanelEditor.lua:1318,1329`. Schema is the single source
of truth for settings (`settings/Schema.lua`), validated at boot through the Options descriptor's
`validate` callback (`settings/OptionsSetup.lua:155`).

## SavedVariables (`savedvariables`)

AceDB with `global` + `profile` scopes; `NS.SCHEMA_VERSION = 2` (`core/Namespace.lua:14`);
`schemaVersion` is deliberately **not** seeded in defaults (`defaults/Global.lua:8-11`) so a v1
install actually reaches the runner; the migration runner is `NS:RunMigrations`
(`core/Database.lua:90-122`) with a real v1→v2 body. `defaults/Profile.lua:35-37` records that the
`settings.visibility` dropdown needed **no** migration because the addon never shipped a
*show only in combat* boolean.

## Settings panel (`options-ui`)

`settings/OptionsSetup.lua:118-201` builds `NS.Helpers` from `LibStub("LibKa0s-Options-1.0", true)`
(`:26`) with a descriptor; `:28-116` is the library-absent stub. Pages:

| Page | Strip |
|---|---|
| Landing (`buildMain`, `settings/Panel.lua:259`) | exempt — host-drawn body (options-ui-§5) |
| General (`settings/Panel.lua:361-424`) | `O.RenderTabbedSchema(c, "general", afterGroup)` at `:422` — tabs `Master controls`, `Editing`, `New panels` |
| Panels (`settings/Panel.lua:430`, body `settings/PanelEditor.lua`) | `H.TabStrip` at `settings/PanelEditor.lua:1079` — six tabs (`:164-174`) |
| Profiles (`settings/Panel.lua:480`) | exempt — AceConfig-rendered |

`Master controls` is the General page's first tab and is **composed**, not typed out:
`NS.Schema:InstallMaster(NS.Helpers)` (`settings/OptionsSetup.lua:214`) calls
`H.MasterControls{…}` (`settings/Schema.lua`, `InstallMaster`). One chrome block per page, unboxed
(`settings/PanelEditor.lua:1098-1130`); the ex-`InlineGroup` box was deliberately removed
(`:463-468`, anti-pattern #72). No `disabledIf` on any color row — the rule is cited in code at
`settings/PanelEditor.lua:357`. No paired reorder arrows anywhere in `settings/`. Every color
control is drawn through `makeColorPair` (`settings/PanelEditor.lua:361`), which emits the swatch
plus its `Use class color` companion from `C.COLOR_FIELDS`, with the class source declared in
`C.COLOR_CLASS_SOURCE`.

## Slash (`slash-commands`)

`NS.COMMANDS` at `settings/Slash.lua:273` carries **18** verbs, dispatched through
`LibKa0s-Slash-1.0`. `Sl.FormatKV` is published on **both** arms (`settings/Slash.lua:357`, with
the degraded-arm reasoning at `:350-356`).

## Debug console (`debug-logging`)

`core/DebugLogSetup.lua` resolves `LibKa0s-DebugLog-1.0` and hands it a descriptor; the degraded
arm prints a plain, uncolored ack at `:146` (`"debug logging is on"` / `"…is off"`), with the
reason at `:141`. No addon-owned console window exists.

## Close-button wrapper (`standalone-windows`, `debug-logging-§12`)

One wrapper, in the Core setup file: `core/CoreSetup.lua:119`
`return lib.MakeCloseButton(parent, onClick, addonName)`, three-argument, documented at `:112`.
The repo-wide grep finds **no** bypassing call site.

## Compat, events, taint (`compat`, `events-frames-taint`)

`core/Compat.lua` is the single home of client-varying API access (`:1-14`). Events are AceEvent
(`core/PanelMaster.lua:51-76`), including `PLAYER_REGEN_ENABLED/DISABLED`. Panels are non-secure
backdrop frames; no secure-frame or lockdown surface. The pre-formatting SHOULD is a **ratified**
register row (below).

## Preview mode (`preview-mode`)

Present — placeholder panels stood up as a batch (`modules/Registry.lua:324-394`).

## Public API (`public-api`)

Not applicable: no `NS.API` surface (`grep -rn 'NS.API'` over non-`libs/` source → no hit).

## Performance (`performance`)

`LibKa0s-Perf-1.0` is vendored but **not wired** — a **ratified deviation from `performance-§1`**,
recorded in `docs/ARCHITECTURE.md:193` and dated 2026-08-25. `performance-§12` is explicitly *not*
claimed (`modules/Canvas.lua:646` installs a shared 10 Hz `OnUpdate`). No `docs/perf-analysis/`,
no retired `docs/perf-runs/`, no `PanelMasterPerfDB` — all consistent with the row.

## `.gitattributes` (`line-endings`)

Present at the repo root. Pin recorded verbatim: `* text=auto eol=crlf` (`.gitattributes:26`) —
the client-bound kind, correct for a repo shipping a `.toc`. `*.sh text eol=lf` at `:34`.
21 ` binary` lines. The body diffs against the canonical client-bound body with exactly one extra
block, `tools/artwork/bin/realesrgan-ncnn-vulkan binary` (`.gitattributes:67-70`), which is a
**ratified** `line-endings-§5` row (`docs/ARCHITECTURE.md:197`).

## Lint / tests / automated tests

`.luacheckrc` sets `std = "lua51"`, an explicit `read_globals` list, and two narrow `ignore` codes.
`luacheck .` → **0 warnings / 0 errors in 27 files**. `lua tests/run.lua` → **763 passed, 0 failed,
0 skipped**. `tests/_kit/` is the vendored harness, mode `100755`. `docs/automated-tests/` holds
eight frozen bundles plus `README.md` and `RESULTS.md`; the newest is `20260825-103450`
(`git.sha 721c559`), which is **19 commits behind HEAD**.

## Root docs (`documentation`)

`README.md` — player-facing, five badges in the mandated order at `:3-7` with the standard badge in
its **bare** `![Standard](…)` form (`:6`), logo, description, `## Screenshots`, `## Usage`,
`## How panels work`, `## FAQ`, `## Troubleshooting`, `## Issues and feature requests`,
`## Version History`, `## Credits`. `## Credits` (`:382-386`) holds **external** credit only
(warcraft.wiki.gg artwork, CC BY-SA 4.0). No bundled-library inventory, no `## Libraries` heading,
no provenance line. `## What's new` is absent and is a **ratified** register row.
The `[tests]` badge reads `763/763`, matching `docs/test-cases.md`'s Totals table.

`CLAUDE.md` — 92 lines: H1, adherence line, `## Standards compliance (read first)`, the docs
pointer list, the green-gate line, and the provenance line at `:44`. `DEPENDENCIES.md` — 187 lines,
the WSL2/Ubuntu toolchain contract. No `CHANGELOG.md`, no `TODO.md`, no `docs/pending/`, no
`docs/agent-context.md`.

## `docs/` shape (`documentation-§3`)

**Tier 1 — all six present** under exactly the canonical names: `scope.md`, `module-map.md`,
`schema.md`, `settings-panel.md`, `data-flow.md`, `common-tasks.md`.

**Tier 2 — all seven accounted for** in `docs/ARCHITECTURE.md:137-147`: `slash-dispatch.md`
(present, 18 verbs), `profiles.md` (present), `debug.md` (present), `message-bus.md`
(*Not applicable* — three messages, verified against the code), `midnight-quirks.md`
(*Not applicable*), `compat-layer.md` (*Not applicable*), `perf-analysis/README.md`
(*Not applicable* — `Perf` declined, register row cited). Every "Not applicable" row's trigger was
re-checked against the code this run and each is true.

**`## Documentation map`** at `docs/ARCHITECTURE.md:119` covers every `.md` under `docs/` in
exactly one table, naming the frozen/generated directories once each. No orphan, no dangling row.
**Retired docs:** none — no `file-index.md`, no `conventions.md`, no `complexity.md`, no
`docs/perf-runs/`. **Hub shape:** `docs/ARCHITECTURE.md` is 199 lines, longest section 48 lines —
both inside the caps.

**Tier 3 / verification:** `rendering.md`, `artwork-spec.md`, `localization.md`, `media.md`,
`testing.md`, `smoke-tests.md`, `test-cases.md`, `performance.md`.

## Deviation register (`documentation-§3`, `audit-review-history`)

`docs/ARCHITECTURE.md:168-199` carries `## Documented deviations` with **seven** ratified rows —
`performance-§1`, `documentation-§1` (item 5), `events-frames-taint-§8`, `localization-§1`,
`line-endings-§5`, `options-ui-§1`, `documentation-§4` — each with Rule, What differs, Why, Decided
and Re-check trigger. Every gap this run found that matches a row is filed **accepted**, not
re-opened.

## Issue store (`audit-review-history`)

`gh issue list --state all --limit 200` returns 45 issues. Every one carries a `state:` label
(`state:done` / `state:will-not-do` closed; `state:triaged` open) **and** a `severity:` label. No
`[status]` title prefix survives anywhere (anti-pattern #62 clear). `docs/pending/LEDGER.md` does
not exist.
