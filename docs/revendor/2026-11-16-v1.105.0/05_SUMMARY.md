# 05 Summary

- Tag moved v1.94.0 -> v1.105.0, base taken from the CLAUDE.md provenance line (it agrees with the last payload commit, e75f69c). Kit revision 53 -> 57. 33 files moved a minor, 10 of them new, with four new majors (Role, Callout, WaypointArrow, Tooltip). Per-file table: 01_DELTA.md.
- Span bundle: `docs/revendor/2026-11-16-v1.94.0-v1.94.0/`, one tag (v1.94.0, vendored by e75f69c with no bundle). Base correction: none.
- Delivered for free (class A): header marks with a settings mark on the library's windows, the console footer and plain-text Copy, library tooltips through the placers, the skin row and hot-mark colors, kit 57's frame hold, two new faces.
- Contract blockers: none. Forced fixes in this commit: `Report` and `Serialize` on the DebugLog stub (`core/DebugLogSetup.lua`), `SideTabs` on the Options stub (`settings/OptionsSetup.lua`), and the console title-bar case re-pinned to four marks (`tests/test_libka0s.lua`).
- LibKa0s icons: line kept as written (12 names, `settings` included). Prune: kept 13 files, removed 5827 icon files (every set's undeclared marks) and 362 Callout sound files. No provenance split.
- README credits: unchanged (Open Iconic is still the only set shipped). Dead stub mirrors: none.
- Adopted: nothing. Declined: nothing filed. Owed in phase [3]: LibKa0s#79 (`/pm panels`, to verify). Not applicable: #80 #81 #85 #86 #87 #88 #89 #92.
- Gate: `ka0s-bounded lua tests/run.lua` 1201 passed, 0 failed, 1 skipped (1202) under KA0S_KIT_CLIENT=retail and =forever; the skip is the kit's diagnostics opt-out case, skipped before this run too. `ka0s-bounded luacheck .` 0 warnings / 0 errors in 86 files. Largest addon file 1167 lines (tests/test_slash.lua), under the 1500 cap.
- Smoke owed (owner): the lines in Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/06_SMOKE_TESTS.md` that apply to this addon (console header marks and footer, skin colors, library tooltips).
