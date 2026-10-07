Delta: LibKa0s v1.69.0 -> v1.70.0 (span: v1.69.0 v1.70.0)

# 01 — Delta: the consolidated span v1.69.0 to v1.70.0

Written 2026-10-07 by plan item `RV-PM` (`Ka0sAddonsCommonTasks/docs/2026-10-07-REVIEW_AND_STANDARDS_AUDIT_REMEDIATION/`),
beside `docs/revendor/2026-10-07-v1.71.0/`. Two tags this addon vendored on 2026-10-06 and 2026-10-07
have no bundle naming them (the 2026-10-07 audit's `PM-048`, remediation finding `PM-A-11`). This is a
back-fill record in the consolidated span shape, not a re-run of the re-vendor procedure: nothing here
was copied.

The tag vendored immediately before the span is **v1.68.1** (`cbc3743`, DC-REV-01), recorded by
`docs/revendor/2026-10-04-v1.68.1/`. That is the span's base.

## The two listings

`/dev-copilot:wow-revendor-libka0s` Step 3h (the same walk `docs/revendor/2026-10-01-v1.64.0-v1.65.0/01_DELTA.md`
prints in full), run before this bundle existed:

- Vendored: 51 tags. Recorded: 49.
- Vendored minus recorded: `v1.69.0`, `v1.70.0`, the tags on line 1.

## The vendoring commits

| Tag | Vendoring commit | Date |
|---|---|---|
| v1.69.0 | `4e15691` (`chore: re-vendor LibKa0s v1.69.0 (kit 37; adds the line chart widget)`) | 2026-10-06 |
| v1.70.0 | `f61f2b7` (`chore: re-vendor LibKa0s v1.70.0`) | 2026-10-07 |

Each tag is read off the `Bundles [LibKa0s](…) vX.Y.Z` provenance line in root `CLAUDE.md` at that
commit. Each commit's own message is the record of what that re-vendor moved; the earlier frozen
bundles are not edited.

## Per tag, from the library's CHANGELOG at each tag

- **v1.69.0** (base v1.68.1): **WidgetsLineChart minor 1**, a new file (`LibKa0s-Widgets-1.0` key
  12.1.4.1), and **test kit revision 36 -> 37** (`testkit/mock_lines.lua` new, `mock_base.lua` +2
  lines). Every other file unchanged; no `NEEDS_*` floor rises. `git diff --stat v1.68.1 v1.69.0 --
  LibKa0s testkit`: 6 files, 554 insertions, 2 deletions.
- **v1.70.0**: **WidgetsAutocomplete minor 1**, a new file, and **WidgetsLineChart minor 2**
  (per-chart point spacing; `LibKa0s-Widgets-1.0` key 12.1.4.2.1). Kit stays at 37. `git diff --stat
  v1.69.0 v1.70.0 -- LibKa0s testkit`: 3 files, 382 insertions, 4 deletions.

## Consumption

Both tags move only `LibKa0s-Widgets-1.0`. PanelMaster consumes ten majors (`Core`, `Env`, `Media`,
`DebugLog`, `Slash`, `Options`, `Launcher`, `Lifecycle`, `Schema`, and `Bus` for its `Catalog`), not
`Widgets`, which is a settled decline ([#43](https://github.com/tusharsaxena/PanelMaster/issues/43),
`state:will-not-do`). The line chart and the autocomplete box were carried in the payload and are not
consumed.
