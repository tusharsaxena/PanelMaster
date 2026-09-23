# 01 — Delta: LibKa0s v1.54.2 → v1.55.0

Run: 2026-09-23, Steps 2–4 of `/wow-addon:revendor-libka0s` taken non-interactively by a workflow
subagent (Phase 5 of the 2026-09-22 suite sweep). Steps 5–8 (candidates, interview, adoption) are a
later pass and are not in this bundle. No filing and no push. Target: this repo, branch
`suite/2026-09-22-standards-sweep` @ `eb4b4a8`.

Source: the sibling checkout `../LibKa0s`, **tag `v1.55.0` (tag object `bb161b7` → commit
`6f9c5e0`)**, resolved with `git -C ../LibKa0s tag --sort=-v:refname | head -1` and extracted with
`git -C ../LibKa0s archive v1.55.0 LibKa0s testkit | tar -x -C <scratch>/`, never the working tree.
The tag is local to `../LibKa0s` and not yet pushed; `tests/test_vendor_sync.lua` compares against
the tag the provenance line names, so the local tag is enough.

```
git -C ../LibKa0s log --oneline v1.54.2..v1.55.0
  6f9c5e0 Record the v1.55.0 release run
  ae48f3f Make the v1.55.0 record true after the complexity split
  244c752 Bring collectKitHoles and repoKind under the CCN 15 ceiling
  be91249 Split Schema's Set and Validate under the CCN 15 gate
  18ca82a Release v1.55.0
  c051bef Re-vendor the standards reference, and make the v1.55.0 docs true
  06b4051 Add three majors: Compat, Bus, and the Schema runtime's portable half
  2a5e06f Test-kit revision 25: the four gates standard v2.63.0 already cites
```

## Baseline, before anything moved

- `ka0s-bounded lua tests/run.lua` → **848 passed, 0 failed, 0 skipped, 848 total**.
- `ka0s-bounded luacheck .` → **0 warnings / 0 errors in 61 files**.

## 3a — Claimed version

`grep -n '[Bb]undles' CLAUDE.md` → `CLAUDE.md:44`: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s)
**v1.54.2** (MIT).

## 3b — Actual version

`grep -hoE 'local (MAJOR, )?([A-Z_]*MINOR) *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua`:
Core 7, Env 1, Lifecycle 1, Pool 3, Item 1, Media 3, Widgets 9, WidgetsDragHandle 2, DebugLog 12,
Slash 14, Launcher 1, Options 23, OptionsWidgets 30, OptionsTabs 3, OptionsCompose 7,
OptionsScroll 3, Perf 12, PerfPanel 5; kit revision **24** (`tests/_kit/framework.lua:20`). That is
v1.54.2's version block, so the line and the bytes agreed before the copy.

## 3c — Per-file minor delta

File list read from the tag's `LibKa0s/LibKa0s.xml`, not from a table.

| File | Constant | v1.54.2 | v1.55.0 |
|---|---|---|---|
| Core.lua | MINOR | 7 | 7 |
| Env.lua | MINOR | 1 | 1 |
| **Compat.lua** | MINOR | — | **1 (new major `LibKa0s-Compat-1.0`)** |
| Lifecycle.lua | MINOR | 1 | 1 |
| **Bus.lua** | MINOR | — | **1 (new major `LibKa0s-Bus-1.0`)** |
| **Schema.lua** | MINOR | — | **1 (new major `LibKa0s-Schema-1.0`)** |
| Pool.lua | MINOR | 3 | 3 |
| Item.lua | MINOR | 1 | 1 |
| Media.lua | MINOR | 3 | 3 |
| Widgets.lua | MINOR | 9 | 9 |
| WidgetsDragHandle.lua | DRAG_MINOR | 2 | 2 |
| DebugLog.lua | MINOR | 12 | 12 |
| Slash.lua | MINOR | 14 | 14 |
| Launcher.lua | MINOR | 1 | 1 |
| Options.lua | MINOR | 23 | 23 |
| OptionsWidgets.lua | WIDGETS_MINOR | 30 | 30 |
| OptionsTabs.lua | TABS_MINOR | 3 | 3 |
| OptionsCompose.lua | COMPOSE_MINOR | 7 | 7 |
| OptionsScroll.lua | SCROLL_MINOR | 3 | 3 |
| Perf.lua | MINOR | 12 | 12 |
| PerfPanel.lua | PANEL_MINOR | 5 | 5 |

**No cross-major skew.** No existing file's minor moves; the release adds three files and three
`<Script>` rows to `LibKa0s.xml`, which is the one existing payload file whose bytes change.

## 3d — Both diffs, before the copy

`diff -rq --strip-trailing-cr` and `diff -rq` (tag extract against the vendored copy) agree exactly,
so there is no line-ending-only drift on either payload:

- `libs/LibKa0s/`: `Only in <tag>: Bus.lua`, `Compat.lua`, `Schema.lua`; `LibKa0s.xml differ`.
  Nothing is `Only in libs/LibKa0s`, so nothing is to be deleted.
- `tests/_kit/`: `Only in <tag>: test_layout_cap.lua`; `README.md`, `framework.lua`,
  `run-automated-tests.sh`, `test_eol.lua`, `test_prose.lua` differ. Nothing is `Only in tests/_kit`.

## 3e — Consumption map

`grep -rnoE 'LibKa0s-[A-Za-z]+-1\.0' --include='*.lua' --exclude-dir=libs --exclude-dir=tests .`
names Core, Env, DebugLog, Slash, Launcher, Lifecycle, Media, Options and Perf (Perf only as the
`core/LifecycleSetup.lua:22,188` reference; the addon wires no Perf harness under its ratified
`performance-§1` row). The `LibStub("…", true)` lookup sites are `core/CoreSetup.lua:34`,
`core/EnvSetup.lua:40`, `core/MediaSetup.lua:42`, `core/DebugLogSetup.lua:102`,
`core/LauncherSetup.lua:128`, `core/LifecycleSetup.lua:68`, `settings/OptionsSetup.lua:26` and
`settings/Slash.lua:384`.

**Unadopted majors in the payload:** `LibKa0s-Compat-1.0`, `LibKa0s-Bus-1.0`, `LibKa0s-Schema-1.0`
(all three new), plus `Pool`, `Item`, `Widgets` reached only through the library itself. These feed
Step 5 (class C) and are **not** adopted in this pass. The addon keeps its own `core/Compat.lua`
(`NS.Compat`), its own bus and its own `settings/Schema.lua` runtime; the new majors register under
their own LibStub names and collide with none of them.

The harness loads the library by `Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml")`
(`tests/run.lua:28`), and the TOC loads `libs\LibKa0s\LibKa0s.xml` (`PanelMaster.toc:36`), so the
three new files load in both with no list to re-type.

## 3f — Kit revision, and the pairing rule

`grep -n 'Kit.VERSION' <tag>/testkit/framework.lua tests/_kit/framework.lua` → **24 → 25**.
Both payloads are copied whole in one commit, so the pairing rule (LibKa0s ≥ v1.9.0 takes kit ≥ 11
in the same commit) holds by construction.

Revision 25's consumer-side obligations (`docs/api/testkit/version-25-docs.md`, *Adoption*):

- declare `{ name = "test_layout_cap", dir = "tests/_kit/" }` and **delete** the local
  `tests/test_layout_cap.lua` plus the bare `"test_layout_cap"` entry that wired it — this repo
  carries exactly that local copy, so under the (basename, directory) key the bare entry is a
  **collision** and the run aborts until it is retired;
- `test_prose` is already declared in the pair form (`tests/run.lua:98`) and there is no local
  `tests/test_prose.lua`, so no collision there;
- `Kit.layoutCap` needs nothing: the hub is the default `docs/ARCHITECTURE.md` and the repo has no
  generated data;
- the kit gate reads the census under `### Files over the 1500-line cap` **beneath**
  `## Documented deviations`. This repo's census is headed ``### Files by the `layout-§1` band``,
  sits under a separate `## File sizes` section, and gates the 1000–1500 band; `layout-§1` (standard
  v2.64.0) now puts the band in the release watch list alone. The heading is renamed and moved, and
  the band rows drop out of it, in the same commit as the payload (the old local gate keys on the old
  heading, so the rename cannot land green before the kit does);
- nothing for `test_eol`'s second case (the `.gitattributes` body already landed in `eb4b4a8`), and
  nothing for the runner's two new `RESULTS.md` cells.

## 3g — Contract delta

**Majors whose minor moved ∩ majors this addon looks up = ∅.** No existing file's minor moved
(3c), and the three majors that are new are consumed nowhere (3e). There is therefore no API
document pair to diff for a consumed major.

- `git -C ../LibKa0s diff v1.54.2 v1.55.0 -- docs/api` touches, outside the three new folders and
  the kit document, only `docs/api/README.md` (index rows) and `docs/api/Widgets/version-9.1-docs.md`
  / `version-9.2-docs.md`, which repair the status header of the 9.2 document and add a "Moving to
  9.2" note. `WidgetsDragHandle` minor 2 has been vendored since v1.48.1 and this addon draws no
  drag handle, so nothing there reaches it.
- `grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` → no
  hits: the addon hands no member to an `__Attach*` entry point.
- The kit's revision-25 document states "No member a suite calls is removed, renamed or
  resignatured"; the one contract that widens is the suite-list key (name → pair), handled in 3f.

### Blockers

**None.**

## Step 4 — after the copy

Both payloads copied whole from the extract (`cp -r <scratch>/LibKa0s/. libs/LibKa0s/`,
`cp -r <scratch>/testkit/. tests/_kit/`). Re-diffed both directions with and without
`--strip-trailing-cr`: **all four empty**. Nothing was deleted inside `libs/` or `tests/_kit/`
(no `Only in <Addon>` line before the copy). The kit's automated-test shell runner keeps mode
`100755` in the index.

In the same commit as the payload:

- `CLAUDE.md:44` provenance line rolled `v1.54.2` → `v1.55.0`; no README provenance line exists.
- `tests/run.lua`: bare `"test_layout_cap"` → `{ name = "test_layout_cap", dir = "tests/_kit/" }`;
  local `tests/test_layout_cap.lua` deleted (the collision 3f names).
- `docs/ARCHITECTURE.md`: the `## File sizes (layout-§1)` section and its
  ``### Files by the `layout-§1` band`` census are replaced by `### Files over the 1500-line cap`
  under `## Documented deviations`, stating "Nothing is over the cap today" (largest authored file
  `settings/PanelEditor.lua`, 1476 lines, by the `git ls-files '*.lua' … | xargs wc -l` sweep); the
  band rows are dropped in favor of the release watch list in `docs/automated-tests/RESULTS.md`,
  which already dispositions all four band files.
- `docs/testing.md`, `docs/module-map.md`, `docs/test-cases.md` (regenerated) and the README
  `Tests` badge brought to what the tree now does.

Gate (both through `ka0s-bounded`): `lua tests/run.lua` → **872 passed, 0 failed, 0 skipped, 872
total**, `tests/test_vendor_sync.lua` included; the linter → **0 warnings / 0 errors in 60 files**.
