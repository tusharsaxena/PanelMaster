Delta: LibKa0s v1.106.0 -> v1.106.0 (span: v1.106.0)

# 01 Delta: the consolidated span v1.106.0

Written 2026-11-19 by AF-RV-PM (Ka0sAddonsCommonTasks `docs/2026-11-19-ADOPTION_FEEDBACK/`), beside `docs/revendor/2026-11-19-v1.107.0/`. One tag this addon vendored has no bundle naming it. This is a back-fill record in the consolidated span shape: nothing here was copied.

The tag vendored immediately before it is **v1.105.0** (7025008), recorded by `docs/revendor/2026-11-16-v1.105.0/`.

## The two listings

`/dev-copilot:wow-revendor-libka0s` Step 3h, run before this bundle existed:

- Vendored: 71 tags. Recorded: 70.
- Vendored minus recorded: `v1.106.0`, the tag on line 1.

## The vendoring commit

| Tag | Vendoring commit | Date | Run |
|---|---|---|---|
| v1.106.0 | `ce1c83a` | 2026-11-19 | the HUD dock guard (RangeMaster#17), carried on the v1.105 adoption branch and merged in `94f16f3` |

`git -C ../LibKa0s diff --shortstat v1.105.0 v1.106.0 -- LibKa0s testkit`: 1 file, 26 insertions, 8 deletions (`Widgets.lua`, minor 28; the kit was unchanged). The commit's own message is the record of what that re-vendor moved.
