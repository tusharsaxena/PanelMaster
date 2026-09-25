Delta: LibKa0s v1.58.0 -> v1.60.0

# 01 — Delta

Run: 2026-09-26, item **DR-PM-01** of the 2026-09-25 diagnostics rollout
(`Ka0sAddonsCommonTasks/docs/2026-09-25-DIAGNOSTICS_COMMAND`, milestone M3), through
`/wow-addon:revendor-libka0s --tag v1.60.0`. Nothing was pushed. Target: this repo, branch
`feat/2026-09-25-diagnostics-rollout`, created from `master` @ `82b9382`.

Source: the sibling checkout `../LibKa0s`, **tag `v1.60.0` (tag object `ac59511` → commit
`bed0eb1`)**, extracted with `git -C ../LibKa0s archive v1.60.0 LibKa0s testkit | tar -x -C <scratch>/`,
never the working tree. `git -C ../LibKa0s tag --sort=-v:refname | head -1` → `v1.60.0`.

The run spans two releases. `v1.59.0` (commit `53c141a`) was never vendored here and is carried in
the same copy. `git -C ../LibKa0s log --oneline v1.58.0..v1.60.0` lists 17 commits (B8-P8, DR-LK-01
to DR-LK-06 and their review follow-ups, and two merges). `git -C ../LibKa0s diff --stat v1.58.0 v1.60.0
-- LibKa0s testkit` → 8 files changed, 868 insertions, 39 deletions.

## Baseline, before anything moved

- `ka0s-bounded lua tests/run.lua` → **933 passed, 0 failed, 0 skipped, 933 total**.
- `ka0s-bounded luacheck .` → **0 warnings / 0 errors in 62 files**.

## 3a — Claimed version

`grep -n '[Bb]undles' CLAUDE.md` → `CLAUDE.md:45`: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s)
**v1.58.0** (MIT). No provenance line in `README.md`.

## 3b — Actual version

`diff -rq --strip-trailing-cr` of a `v1.58.0` extract against both payloads is empty both ways, so
the vendored bytes are exactly v1.58.0's. Line and bytes agree. Kit revision **26**
(`tests/_kit/framework.lua:20`).

## 3c — Per-file minor delta

File list read from the tag's `LibKa0s/LibKa0s.xml` (22 scripts; `DebugLogDiagnostics.lua` is new,
at `LibKa0s.xml:14`, after `DebugLog.lua`). Minors by `grep -oE 'local (MAJOR, )?([A-Z_]*MINOR) ...'`
over both trees, sorted and diffed:

| File | Constant | v1.58.0 | v1.60.0 |
|---|---|---|---|
| `DebugLog.lua` | `MINOR` | 13 | **14** |
| `DebugLogDiagnostics.lua` | `DIAG_MINOR` | — | **1** (new file) |
| `Slash.lua` | `MINOR` | 15 | **16** |
| `WidgetsDragHandle.lua` | `DRAG_MINOR` | 2 | **3** (v1.59.0) |

Every other file is unchanged: Core 8, Env 1, Compat 1, Lifecycle 2, Bus 2, Schema 2, Pool 3, Item 2,
Media 4, Widgets 10, Launcher 4, Options 24.31.4.7.4, Perf 13 / PerfPanel 5. No `NEEDS_*` floor
rises and no major is added. No cross-major skew: the consumer is behind on no file other than
these four.

## 3d — Both diffs, before the copy

Content (`--strip-trailing-cr`):

- `libs/LibKa0s/`: `DebugLog.lua`, `LibKa0s.xml`, `Slash.lua`, `WidgetsDragHandle.lua` differ;
  `Only in <tag>: DebugLogDiagnostics.lua`.
- `tests/_kit/`: `README.md`, `framework.lua` differ; `Only in <tag>: test_diagnostics_contract.lua`.

Bytes: the same five and three entries, so no line-ending drift. Nothing is `Only in` the addon's
side, so nothing is to be deleted.

## 3e — Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v /libs/ | grep -v /tests/`:

| Major | Lookup site |
|---|---|
| Bus (`Catalog` alone) | `core/BusSetup.lua:28` |
| Core | `core/CoreSetup.lua:34` |
| DebugLog | `core/DebugLogSetup.lua:115` |
| Env | `core/EnvSetup.lua:40` |
| Launcher | `core/LauncherSetup.lua:128` |
| Lifecycle | `core/LifecycleSetup.lua:68` |
| Media | `core/MediaSetup.lua:42` |
| Options (with Widgets, Tabs, Compose, Scroll) | `settings/OptionsSetup.lua:26` |
| Schema | `settings/Schema.lua:460` |
| Slash | `settings/Slash.lua:423` |

Of the majors that moved, **DebugLog** and **Slash** are consumed. `WidgetsDragHandle` is not:
`grep -rn DragHandle core settings modules` is empty, so this addon builds no drag strip.

## 3f — Kit revision, and the pairing rule

Revision **26 → 27** (`grep -n Kit.VERSION` on both `framework.lua`). The kit gains its fourth own
suite, `test_diagnostics_contract.lua`. Both payloads move in one commit, which satisfies the
pairing rule by construction.

## 3g — Contract delta

Read for the two consumed majors that moved, from `docs/api/DebugLog/version-14.1-docs.md` and
`docs/api/Slash/version-16-docs.md` at `v1.60.0`, against the `CHANGELOG.md` blocks for v1.59.0 and
v1.60.0 (*What a consumer owes on re-vendoring v1.60.0*).

- **DebugLog: the buffer is 3000 lines** (`version-14.1-docs.md:611-614`; was 1500 in version 13).
  `grep -rn '1500\|1564\|MAX_BUFFER\|BUFFER_SLACK' tests/*.lua` finds no literal: only a comment
  in `tests/run.lua:113` about the layout-cap band, which is unrelated. No suite re-pins. The one
  comment that still says the console holds 1500 lines, `core/DebugLogSetup.lua:9`, belongs to
  DR-PM-05 (the docs item) under the plan.
- **DebugLog: the library-absent stub gains three instance members** (`version-14.1-docs.md:615-619`):
  `RunDiagnostics` prints the collection's placeholder line with `/<slash> diagnostics`, writes
  nothing and returns 0; `BuildDiagnostics` and `DebugVerb` are carried for the parity case.
  `tests/test_surface_parity.lua:109` pins the stub with `assertSurfaceParity`, so it goes red on the
  copy until `core/DebugLogSetup.lua`'s stub gains them. **Owed in the copy commit.**
- **Slash 16: `diagnostics` joins `lib.LIVE_VERBS`** (CHANGELOG v1.60.0, *Slash minor 16*). This
  addon passes no `liveVerbs`, so the live arm picks it up unchanged. Two places carry the set as a
  literal and move: the degraded fallback array in `settings/Slash.lua:447-455` (the item this plan
  names) and the live-set pin in `tests/test_slash.lua:880-898`, which fails on the extra verb.
  **Owed in the copy commit.**
- **Kit: the new suite must be declared.** `tests/run.lua`'s `SUITES` gains
  `{ name = "test_diagnostics_contract", dir = "tests/_kit/" }`, or the kit's inventory gate fails the
  run. With `Kit.diagnostics` unset it registers one declared skip until DR-PM-03 wires the report.
  **Owed in the copy commit.**
- `grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` is empty:
  this addon hands the library no callback through an `__Attach*` seam, so no host-supplied member
  can have had its call site moved.

### Blockers

None. Every item above is a re-pin or a stub member the library's own changelog names, with no
decision in it.
