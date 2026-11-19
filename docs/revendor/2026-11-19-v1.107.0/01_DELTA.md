Delta: LibKa0s v1.106.0 -> v1.107.0

Recorded with the copy, before anything was committed. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.107.0 LibKa0s testkit tools` (tag commit 5e96365, a local tag, not on origin yet: `git -C ../LibKa0s ls-remote --tags origin v1.107.0` prints nothing). Run under Ka0sAddonsCommonTasks `docs/2026-11-19-ADOPTION_FEEDBACK/`, item AF-RV-PM. The copy-and-bundle half of `/dev-copilot:wow-revendor-libka0s` (dev-copilot 2.9.0) only: the run's bundle lists this addon's adoption items (none beyond AF-RV-PM), so there is no interview and no GitHub issue.

## 3a Base
- `grep -n '[Bb]undles' CLAUDE.md` named v1.106.0 before the roll (CLAUDE.md:59).
- Last payload commit, `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = ce1c83a ("Re-vendor LibKa0s v1.106.0"); its CLAUDE.md names v1.106.0. They agree.
- Payload before the copy equalled the library at v1.106.0: `diff -rq --strip-trailing-cr` of both payloads against a v1.106.0 extract printed only `Only in <extract>/LibKa0s/media/sounds: callout` and the undeclared icons, both the declarations working (payload-matches).
- Library range: `git -C ../LibKa0s log --oneline v1.106.0..v1.107.0` is 6 commits (AF-LK-01, AF-LK-02, AF-DR-LK, AF-LK-03 x3); `git -C ../LibKa0s diff --stat v1.106.0 v1.107.0 -- LibKa0s testkit` is 2 files, 195 insertions, 197 deletions.
- Step 0: the newest single-tag bundle, `2026-11-16-v1.105.0`, states base v1.94.0, which is the provenance tag before its re-vendor (7025008). No correction.

## 3b/3c Per-file minors that moved (old = this addon at v1.106.0, new = v1.107.0)
Loop over the tag's `LibKa0s/LibKa0s.xml`, each file's `local (MAJOR, )?[A-Z_]*MINOR` constant; only the changed rows:
```
WidgetsDragHandle.lua     old: local DRAG_MINOR = 14     new: local DRAG_MINOR = 15
WidgetsDragHandleTip.lua  old: local DRAGTIP_MINOR = 1   new: local DRAGTIP_MINOR = 2
```
The claimed version (v1.106.0) and the minors on disk agreed before the copy. No cross-major skew.

## 3d Diffs
After the copy and before the prune, `diff -rq --strip-trailing-cr` and `diff -rq` of `<extract>/LibKa0s` against `libs/LibKa0s` and of `<extract>/testkit` against `tests/_kit` all printed nothing. After the prune the only differences are the undeclared icons and the Callout sound packs.

## 3e Consumption map
`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' --include='*.lua' . | grep -vE '^(\./)?(libs|tests)/'`: Bus, Compat, Core, DebugLog, Env, Launcher, Lifecycle, Media, Options, Schema, Skin, Slash. The addon looks up no Widgets major of its own (the Options toolkit and the debug console reach it inside the library), and no addon file calls `Widgets.DragHandle` or passes `tooltipPlace` (`grep -rn "DragHandle\|tooltipPlace" --include='*.lua' . | grep -vE '^(\./)?(libs|tests/_kit)/'` prints nothing): PanelMaster draws its own unlock overlay (`modules/Unlock.lua`). The library's own strips (the Callout's and the WaypointArrow's) belong to majors this addon never instantiates.

## 3f Kit revision
`grep -n 'Kit.VERSION'`: 57 in the tag and 57 here. The kit did not move; both payloads were still copied whole.

## 3g Contract delta
The two moved files belong to the Widgets major, which this addon reaches only through the library. The changed contract (marks [?][settings][close], the settings mark built unless `spec.settings == false`, close only with `spec.onClose`, header tints, `spec.tooltipPlace` ignored and the strip tooltip always above) binds a `Widgets.DragHandle` host. PanelMaster builds no strip, so none of it reaches this addon's code. `grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` finds no member that the moved files call back.

**Blockers:** none.

## 3h Unrecorded tags
The Step 3h listing printed `v1.106.0` (vendored 71 tags, recorded 70): ce1c83a vendored it on 2026-11-19 with no bundle. Back-filled in `docs/revendor/2026-11-19-v1.106.0-v1.106.0/`.

## 3i Icon declaration
`grep -n 'LibKa0s icons:' CLAUDE.md` = CLAUDE.md:60, the next non-blank line after the provenance line. Kept as written (12 names). `settings`, which v1.107.0 strip consumers must declare, is already on it for the skin picker's gear. No `LibKa0s sounds:` line, which means none. No provenance split needed.

## 3j Tests assuming the whole icon folder
`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'`: no new hit since v1.105.0's bundle. None is a blocker.
