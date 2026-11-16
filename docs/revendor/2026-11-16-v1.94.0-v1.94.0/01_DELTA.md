Delta: LibKa0s v1.94.0 -> v1.94.0 (span: v1.94.0)

# 01 Delta: the consolidated span v1.94.0

Written 2026-11-16 by RV-PM (Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/`), beside `docs/revendor/2026-11-16-v1.105.0/`. One tag this addon vendored has no bundle naming it. This is a back-fill record in the consolidated span shape: nothing here was copied.

The tag vendored immediately before it is **v1.93.0** (d931387), recorded by `docs/revendor/2026-11-07-v1.93.0/`.

## The two listings

`/dev-copilot:wow-revendor-libka0s` Step 3h, run before this bundle existed:

- Vendored: 69 tags. Recorded: 68.
- Vendored minus recorded: `v1.94.0`, the tag on line 1.

## The vendoring commit

| Tag | Vendoring commit | Date | Run |
|---|---|---|---|
| v1.94.0 | `e75f69c` (W2-PM-01) | 2026-11-08 | Ka0sAddonsCommonTasks WoW Forever port wave 2, merged in `c2244af` |

`git -C ../LibKa0s diff --shortstat v1.93.0 v1.94.0 -- LibKa0s testkit`: 2 files, 121 insertions, 7 deletions (`Skin.lua` and `Compat.lua`; the kit was unchanged). The commit's own message is the record of what that re-vendor moved.
