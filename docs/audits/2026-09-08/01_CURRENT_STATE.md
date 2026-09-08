# 01 — Current state (2026-09-08)

**Audited against the Ka0s WoW Addon Standard `v2.39.0 (2026-09-07)`** — resolved from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`, line 1 of
`standards/STANDARDS.md` verified as `# Ka0s WoW Addon Standard (v2.39.0, 2026-09-07)` before any
measurement was taken. The index plus **all 26** linked section files were fetched verbatim with
`curl -fsSL` and read from disk; the `AUDIT.md` playbook and `standards/ADDONS.md` were fetched the
same way. Provenance and md5s are in `03_EVIDENCE.md` § 0.

**Repo:** `PanelMaster`, branch `master`, HEAD `bb7b9fe` (`Merge branch
'feat/2026-09-07-audit-review-remediation'`), working tree clean.

**Rule set used:** the **addon** sections. The repo has a `.toc` (`PanelMaster.toc`), so step 1's
switch to `library-stack-§7`'s applicability list does not apply.

**Prior run:** `docs/audits/2026-09-07/` (v2.38.0). That bundle is frozen and is not edited by this
run. The comparison is in `02_DEVIATIONS.md` § *Closed since 2026-09-07*.

---

## 1. Layout (`layout`)

The single modular layout, folder order as the standard states it:

```
libs/ → locales/ → core/ → defaults/ → modules/ → settings/
```

- `core/` — `Compat`, `EnvSetup`, `MediaSetup`, `Constants`, `Namespace`, `State`, `Util`,
  `CoreSetup`, `DebugLogSetup`, `PanelMaster`, `Database` (11 files).
- `defaults/` — `Profile.lua`, `Global.lua`.
- `locales/` — `enUS.lua`, `PostLoad.lua`.
- `modules/` — `Registry`, `Artwork`, `SunnArtPacks`, `SunnArt`, `Canvas`, `Unlock` (6).
- `settings/` — `Schema`, `Slash`, `PanelEditor`, `OptionsSetup`, `Panel` (5).
- `media/` — `artwork/` (101 `.tga`), `logos/`, `poster/`, `screenshots/`. **No `media/fonts/`,
  `media/icons/` or `media/textures/`** — those come from `libs/LibKa0s/media/` with the vendored
  payload (`library-stack-§8`).

**`core/LSMPatch.lua` is gone.** It existed at the 2026-09-07 audit and was deleted at `M4-05`; the
widget-registry re-registration is now the library's, called once from
`settings/OptionsSetup.lua:152`.

**The 1500-line cap (`layout-§1`, amended this release to name its scope).** Measured over every
authored `.lua` the repo tracks, `tests/` included, with `libs/` and `tests/_kit/` the carve-outs:
**nothing is over the cap**, and four files sit in the 1000–1500 on-notice band —
`settings/PanelEditor.lua` 1488, `tests/test_artwork.lua` 1356, `tests/test_panel.lua` 1222,
`modules/Artwork.lua` 1188. All four are remarked in `docs/ARCHITECTURE.md` → `## File sizes
(layout-§1)`, and `tests/test_layout_cap.lua` gates the membership of that census in both
directions.

## 2. TOC (`toc-file`)

`PanelMaster.toc`, 87 lines. Metadata block `:1-13` in the required order, single latest-Retail
`## Interface: 120007`, `## X-License: MIT`, `## X-Standard:` pointing at the standards repo, and a
**real** `## X-Curse-Project-ID: 1642836` matching the README's CurseForge badge — not a placeholder
(anti-pattern #67 clean).

`#`-sectioned listing in the mandated header order Libraries → Locales → Core → Defaults → Modules →
Settings. `libs\LibKa0s\LibKa0s.xml` is listed **once**, at `:30`, after Ace3 — never individual
module `.lua` files.

**Position annotations (`toc-file-§5`, whose denominator this release states explicitly).** The
denominator was established by reading the seam files and `core/Constants.lua`, not by counting
lines. Every load-bearing position carries a comment naming what resolves: `libs\LibKa0s\LibKa0s.xml`
(`:28-29`), `core\MediaSetup.lua` (`:42-45`, naming `C.FONT_MONO` ← `NS.MediaFont` at file load),
`core\CoreSetup.lua` (`:51-52`), `core\DebugLogSetup.lua` (`:54-56`),
`settings\OptionsSetup.lua` (`:83-85`), and the module ordering at `:65`, `:67`, `:69-70`, `:72-74`.
`core\EnvSetup.lua` (`:38-40`) carries the **conventional** statement in the standard's own worded
form. `core\Constants.lua` and `settings\Panel.lua` carry nothing and are compliant — each is pinned
by the annotated line above it, which is exactly the worked example `toc-file-§5` publishes.

## 3. Libraries (`library-stack`)

Vendored and committed under `libs/`, no `externals:`. Ace3 set: `AceAddon-3.0`, `AceEvent-3.0`,
`AceTimer-3.0`, `AceConsole-3.0`, `AceDB-3.0`, `AceDBOptions-3.0`, `AceGUI-3.0`, `AceConfig-3.0`,
`CallbackHandler-1.0`, `LibStub`, plus `LibSharedMedia-3.0` and
`AceGUI-3.0-SharedMediaWidgets`. Every one is reached in one of `library-stack-§3`'s three ways —
a direct `LibStub` call, an Ace3 mixin **name string** AceAddon resolves, or a vendored lib reaching
another vendored lib (`CallbackHandler-1.0`).

`libs/LibKa0s/` is the whole ship folder: **14 module files** (`Core`, `DebugLog`, `Env`, `Item`,
`Media`, `Options`, `OptionsCompose`, `OptionsScroll`, `OptionsWidgets`, `Perf`, `PerfPanel`, `Pool`,
`Slash`, `Widgets`) plus `LibKa0s.xml`, `LICENSE` and `media/`. The provenance line is in root
`CLAUDE.md:44` — `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.27.0 (MIT).` — and
**not** in `README.md`. Both `diff -r` runs against the sibling repo at tag `v1.27.0` are empty
(`03_EVIDENCE.md` § 4).

## 4. Shared subsystems — the descriptors and the stubs

The console, the options toolkit, the slash dispatcher and the test harness are **LibKa0s modules**.
What this addon owns is a descriptor and a degradation stub per module:

| Module | Setup file | Descriptor | Degradation stub |
|---|---|---|---|
| `LibKa0s-Core-1.0` | `core/CoreSetup.lua` | `lib:New{ prefix }`, `NS.IsConcatSafe` / `NS.SafeToString`, `NS.MakeCloseButton` wrapper at `:118-120` | `if not lib then` branch |
| `LibKa0s-DebugLog-1.0` | `core/DebugLogSetup.lua` | `name`/`addonName` at `:163`/`:171` | 15 stubs + `D:Diagnose` on both arms |
| `LibKa0s-Slash-1.0` | `settings/Slash.lua` | `lib:New{ slash="/pm", commands=NS.COMMANDS, get/set/findRow }` at `:386-428` | degraded arm from `:339` |
| `LibKa0s-Options-1.0` | `settings/OptionsSetup.lua` | `lib:New` descriptor at `:154`, `buildMain` at `:208` | `NS.Helpers` stub from `:45` |
| `LibKa0s-Media-1.0` | `core/MediaSetup.lua` | the addon's own first vararg, `:1` → `:58` | — |
| test harness | `tests/_kit/` | `Kit.VERSION = 15` | — |

`LibKa0s-Perf-1.0`, `-Widgets-1.0`, `-Item-1.0` and `-Pool-1.0` are **declined** — the payload ships
whole, the adoption is only what is used (`library-stack-§7`). The Perf decline is ratified in the
register; the other three are declines to wire a major, which is not a deviation.

`tests/test_surface_parity.lua` compares each stub's member **set** against the live one, using
kit 15's `Kit.assertSurfaceParity` by-name form for DebugLog and Options. The Options stub is the
documented **load-completing** kind and its composer members answer an **empty row list**, which
`options-ui-§1` now names as the compliant hollow-composer shape.

**Close-button wrapper (`standalone-windows`).** The grep returns exactly the one wrapper definition
(`core/CoreSetup.lua:118-119`) and nothing else outside `libs/` and `tests/`. This addon draws **one**
standalone window — the debug console — and the library draws it, so there is no host title bar to
route and no decline to ratify.

## 5. Settings panel (`options-ui`)

Four canvas pages registered through `LibKa0s-Options-1.0`'s page registry
(`settings/Panel.lua:358`, `:361`, `:430`, `:480`): the **landing** page (host `buildMain`, exempt), **General**
(`O.RenderTabbedSchema` at `:422`), **Panels** (bespoke, `settings/PanelEditor.lua`), and
**Profiles** (AceConfig-drawn, exempt).

- **General** tabs, in declaration order: `Master controls` (composed and spliced at the head by
  `S:InstallMaster`, `settings/Schema.lua:199`), `Editing`, `New panels`. First tab is exactly
  `Master controls`; the canonical row set arrives from `H.MasterControls` rather than being typed
  out, with `defaults = { enabled, visibility, scale, alpha, locked }`, `debugConsolePath`,
  `onResetPosition` and `onResetAll` supplied by the host.
- **Panels** tabs: `Position and size`, `Background and border`, `Accent bar`, `Artwork`,
  `Opacity and fade`. The strip is drawn **first and always** — the old "no panels, no strip" branch
  and `releaseTabStrip` are both gone (`settings/PanelEditor.lua:1376-1389`).
- **Chrome band.** One block per page, unboxed, built once from `BuildPage`
  (`settings/PanelEditor.lua:1047-1210`). It now holds all **eight** page-wide controls: create box,
  picker, panel name, copy-from, Enabled, Unlock, Reset, Delete. The `General` tab that used to hold
  six of them is gone; `TAB_GENERAL` no longer exists.
- Every colour control has its `Use class color` companion as the next row, driven from
  `C.COLOR_FIELDS`, with `C.COLOR_CLASS_SOURCE` declaring `player` for all five and
  `Util.ResolveColor` (`core/Util.lua:225-235`) resolving through the library and falling back to the
  **stored swatch**, never a literal grey.
- No `disabledIf` on a colour row; no paired up/down reorder arrows; no hand-rolled coloured `Label`
  standing in for `Heading`.
- Three canonical media blocks (panel border, accent bar, accent-bar border) are **hand-written** and
  are **ratified** in the deviation register as of 2026-09-08.

## 6. Slash (`slash-commands`)

AceConsole registration through `LibKa0s-Slash-1.0`. `NS.COMMANDS` carries **18** verbs
(`settings/Slash.lua:273-331`). Cyan chat tag `NS.PREFIX = "|cff00ffff[PM]|r"`
(`core/Namespace.lua:19`). Schema get/set/findRow routed to the one write seam,
`NS.Schema:Set(path, value)`. The global reset is one act — `db:ResetProfile()` behind
`Sl:ConfirmResetAll()` (`settings/Slash.lua:45-51`) — reached identically by the header Defaults
button, the `Master controls` row and `/pm resetall`, under the collection's one verbatim wording
(`:55-57`).

## 7. Debug (`debug-logging`)

The on-screen console is `LibKa0s-DebugLog-1.0`'s. The descriptor carries `addonName`
(`core/DebugLogSetup.lua:171`), so the console's chrome draws the shared catalog marks. `D:Diagnose`
and `NS.DebugBuild` are the addon's own additions and are what `docs/debug.md` documents.

## 8. SavedVariables (`savedvariables`)

One SV global, `PanelMasterDB` (`PanelMaster.toc:7`). AceDB with profile + global scopes,
`NS.SCHEMA_VERSION = 2` (`core/Namespace.lua:14`) and a migration runner at
`core/Database.lua:91-122` with a real v1→v2 body. `schemaVersion` is deliberately **not** seeded in
`defaults/Global.lua` (`:8-17`), so an existing install is not stamped current on first read.
Falsy-state defaulting uses `== nil`, not `or`, on every field where the stored value is a user
choice (anti-pattern #54 clean).

## 9. Events, frames, taint (`events-frames-taint`)

AceEvent through the AceAddon mixin. One `OnUpdate` in the whole repo — the shared 10Hz mouseover
driver at `modules/Canvas.lua:645-651` — installed only while at least one panel has *Show on
mouseover only* ticked and removed when the tracked set empties. Combat-deferred unlock in
`modules/Unlock.lua`. Frame pool keyed by global name in `modules/Canvas.lua`. `§8`'s MUST does not
engage: the addon reads none of the combat-protected trigger APIs; the residual pre-formatting SHOULD
is ratified in the register.

## 10. Tests (`testing`, `automated-tests`)

`lua tests/run.lua` → **783 passed, 0 failed, 0 skipped, 783 total**. `luacheck .` → **0 warnings /
0 errors in 57 files**. Vendored kit at `tests/_kit/`, `Kit.VERSION = 15`, `run-automated-tests.sh`
mode `100755`. The three pinned load lists, the stub-surface parity case, both vendored-payload
gates and the new `tests/_kit/test_eol.lua` line-ending gate all pass.

Nine frozen run bundles under `docs/automated-tests/`, newest `20260908-181416` (sha `564acbd`,
verdict green). `RESULTS.md` is the single-path trend line and states the one authored cell
(`:5`, `:69-72`).

## 11. Performance (`performance`)

`LibKa0s-Perf-1.0` is **not** wired, and this is a ratified deviation from `performance-§1` — not a
`§12` exemption, which the register says in as many words is unclaimable here because criterion (a)
fails on the mouseover driver. `perf` is a permanent `skip` in the record for
`automated-tests-§3`'s first sanctioned reason (nothing to run). No `docs/perf-analysis/`, no
retired `docs/perf-runs/`, no retired `docs/complexity.md`.

Today's `lizard` run, verbatim invocation: **0 warnings over 1501 functions**, max CCN 15, nothing
above any threshold.

## 12. Packaging (`packaging`)

`.pkgmeta` names the vendored-libs position, no `externals:`. The ignore list covers `.luacheckrc`,
`.gitignore`, `.gitattributes` (`:8`), `.pkgmeta` itself (`:9` — the self-reference this release
added to the standard's own template), `docs`, `tests`, `tools`, `_dev`, `*.bak`, `CLAUDE.md`,
`DEPENDENCIES.md` and four `media/` paths. The dot-entry sweep prints only `.git`, which is the one
exempt entry.

## 13. `.gitattributes` (`line-endings`) — recorded verbatim

The file is present, 87 lines. The pin, the carve-out and the appendix delimiter, quoted from the
file:

```
26: * text=auto eol=crlf
34: *.sh text eol=lf
83: # --- line-endings-§5 appendix ---
87: tools/artwork/bin/realesrgan-ncnn-vulkan binary
```

21 `binary` marks. The first 81 lines are the canonical client-bound body; the tail is the
`line-endings-§5` **appendix** this release sanctioned, holding one path-keyed mark with its reason.
The register row that used to record the old in-body placement was retired on 2026-09-08.
**Working-tree agreement: 0 files disagree with the declared pin.**

## 14. Root documents (`documentation-§1/§2/§7`)

- **`README.md`** — 391 lines, player-facing, canonical section order: H1, badge row, logo,
  description, `## Screenshots`, `## Usage` (`### Slash commands` + `### Settings panel` tables),
  `## How panels work`, `## FAQ`, `## Troubleshooting`, `## Issues and feature requests`,
  `## Version History`, `## Credits`. Five badges in the exact canonical order and form; the
  standard badge at `:6` is the **bare** `![Standard](…)` with underscores, not wrapped in a link.
  `## Credits` holds only external credit (warcraft.wiki.gg artwork, CC BY-SA 4.0). **No** bundled
  library inventory — no `## Libraries`-family heading and no roll-call in the intro. `## What's new`
  is absent and ratified.
- **`CLAUDE.md`** — 92 lines, a stub: H1, adherence line, `## Standards compliance (read first)`,
  the docs pointer list, the green-gate line, the LibKa0s provenance line at `:44`. It states
  outright that there is no `docs/agent-context.md` (`:72`), and there is not.
- **`DEPENDENCIES.md`** — 187 lines, the WSL2/Ubuntu toolchain contract: Runtime, Development,
  Release and assets, plus a *Keeping this file honest* section.

## 15. `docs/` (`documentation-§3`) — measured as a directory listing

**20 live `.md` files** (18 at `docs/` top level plus `automated-tests/README.md` and
`automated-tests/RESULTS.md`). Frozen and generated directories — `audits/`, `reviews/`,
`automated-tests/<run>/`, `revendor/`, `superpowers/` — are named once each and not enumerated.

- **Tier 1 — all six present** under the canonical names: `scope.md`, `module-map.md`, `schema.md`,
  `settings-panel.md`, `data-flow.md`, `common-tasks.md`.
- **Tier 2 — seven triggers, all answered**, and each trigger re-evaluated against the code this run:
  `slash-dispatch.md` present (18 verbs ≥ 8); `profiles.md` present (AceDB profiles user-visible);
  `debug.md` present (`D:Diagnose`, `NS.DebugBuild`); `message-bus.md` *Not applicable* (3 messages,
  threshold > 10 — correct); `midnight-quirks.md` *Not applicable* (no client-version workaround of
  the addon's own — correct); `perf-analysis/README.md` *Not applicable* (Perf declined and ratified
  — correct); **`compat-layer.md` *Not applicable* — and this one is now wrong.** The trigger became
  a published count this release (**three or more** shims) and `core/Compat.lua` publishes **eight**.
  Filed as `PM-031`.
- **`## Documentation map`** present at `docs/ARCHITECTURE.md:119`, **four** tables in the mandated
  order — Required, Conditional, `### Verification and record` (six rows, exactly the mandated set),
  Addon-specific. Every one of the 19 non-hub `.md` files appears in exactly one table and every row
  points at a file that exists. `ARCHITECTURE.md`'s own row is absent; per the amended rule its
  presence and absence are both unfileable and it is not reported in either direction.
- **Non-canonical filenames:** none. `rendering.md`, `artwork-spec.md`, `localization.md` and
  `media.md` are Tier 3 under the addon's own names, each cross-linking rather than duplicating its
  Tier 1 neighbour.
- **Retired docs:** no `file-index.md`, no `conventions.md`, no `complexity.md`, no
  `docs/perf-runs/`, no `docs/pending/LEDGER.md`.
- **Hub shape:** `docs/ARCHITECTURE.md` is 322 lines, under the ~400 SHOULD. Its longest sections are
  `## Documented deviations` (97 lines) and `## File sizes` (57) — neither is one of the four the
  spill rule names, and the register is by definition the storage rather than a summary.

## 16. Decision stores read before anything was filed

- **`docs/ARCHITECTURE.md` → `## Documented deviations`** (`:168-227`; the table itself is `:219-227`): seven live rows —
  `performance-§1`, `documentation-§1` item 5, `events-frames-taint-§8`, `localization-§1`, and
  **three** new `options-ui-§16` rows dated 2026-09-08. Three rows were **retired** on 2026-09-08
  (`documentation-§4`, `options-ui-§1`, `line-endings-§5`), each with its reason written out.
- **The issue store** — `gh issue list --state all --limit 200`: 47 issues, every one carrying both a
  `state:` and a `severity:` label, and **no `[status]` title prefix** anywhere. Eight closed
  `state:will-not-do` issues; the only one that needs a register row (#31, Perf) has one.
- **`docs/scope.md`** and root `CLAUDE.md` carry no separate accepted-deviation note.

All seven live rows had their re-check triggers evaluated against this tree and every evidence id
they cite resolved. Details in `03_EVIDENCE.md` § 7.
