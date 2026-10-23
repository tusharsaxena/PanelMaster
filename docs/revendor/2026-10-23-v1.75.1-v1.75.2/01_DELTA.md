Delta: LibKa0s v1.75.1 -> v1.75.2 (span: v1.75.1 v1.75.2)

# 01 — Delta: the consolidated span v1.75.1 to v1.75.2

Written 2026-10-23 by plan item `PM-RV` of the sim auto-run, QC preview selector, mode strips and
MM/KCD simulators run (`Ka0sAddonsCommonTasks/docs/2026-10-23-SIM_PREVIEW_MODE_STRIPS/`), beside
`docs/revendor/2026-10-23-v1.76.0/`. Two tags this addon vendored on 2026-10-23, outside any planned
run, have no bundle naming them. This is a back-fill record in the consolidated span shape, not a
re-run of the re-vendor procedure: nothing here was copied.

The tag vendored immediately before the span is **v1.75.0** (`8beece7`, refreshed by PM-RV2),
recorded by `docs/revendor/2026-10-22-v1.75.0/`. That is the span's base.

## The two listings

`/dev-copilot:wow-revendor-libka0s` Step 3h, run before this bundle existed (the walk from the
store's horizon, 2026-08-25, over `libs/LibKa0s`, `tests/_kit` and the `CLAUDE.md` commits that roll
the provenance line, against every bundle's tags):

- Vendored: 55 tags. Recorded: 53.
- Vendored minus recorded: `v1.75.1`, `v1.75.2`, the tags on line 1.

## The vendoring commits

| Tag | Vendoring commit | Date |
|---|---|---|
| v1.75.1 | `e24db99` (`Re-vendor LibKa0s v1.75.1 (SimPanel minor 3)`), merged in `171e2de` | 2026-10-23 |
| v1.75.2 | `b534579` (`Re-vendor LibKa0s v1.75.2 (SimPanel minor 4)`), merged in `f500bc7` | 2026-10-23 |

Each tag is read off the `Bundles [LibKa0s](…) vX.Y.Z` provenance line in root `CLAUDE.md` at that
commit. Each commit's own message is the record of what that re-vendor moved.

## Per tag, from the library's CHANGELOG at each tag

- **v1.75.1** (base v1.75.0): **SimPanel minor 3** (`LibKa0s-Sim-1.0` key 2.2.3). Every row and
  control of the step panel keeps its hover scripts while disabled. Kit revision 41 unchanged.
  `git -C ../LibKa0s diff --stat v1.75.0 v1.75.1 -- LibKa0s testkit`: 1 file, 10 insertions,
  1 deletion.
- **v1.75.2**: **SimPanel minor 4** (key 2.2.4). The picker's scenario dropdown takes the width the
  bar leaves. Kit 41 unchanged. `git -C ../LibKa0s diff --stat v1.75.1 v1.75.2 -- LibKa0s testkit`:
  1 file, 14 insertions, 3 deletions.

## Consumption

Both tags move only `LibKa0s-Sim-1.0`. PanelMaster consumes ten majors (`Core`, `Env`, `Media`,
`DebugLog`, `Slash`, `Options`, `Launcher`, `Lifecycle`, `Schema`, and `Bus` for its `Catalog`), not
`Sim`: it has no simulator (`docs/revendor/2026-10-22-v1.75.0/02_CANDIDATES.md`). Both re-vendors
carried the payload only.
