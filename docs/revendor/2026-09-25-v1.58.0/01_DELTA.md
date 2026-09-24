Delta: LibKa0s v1.57.0 -> v1.58.0

# 01 — Delta

Run: 2026-09-25, item M6-PM of the 2026-09-23 review and standards-audit remediation plan (milestone
M6, the launcher's left-click settings and right-click options menu). Steps 0–4 of
`/wow-addon:revendor-libka0s`, taken by hand the way M5-PM took them for v1.57.0. Nothing was
pushed. Target: this repo, branch `feat/2026-09-23-review-audit-remediation` @ `efbd2d9`.

Source: the sibling checkout `../LibKa0s`, **tag `v1.58.0` (tag object `93cf3ad` → commit
`34931c9`)**, extracted with `git -C ../LibKa0s archive v1.58.0 LibKa0s testkit | tar -x -C <scratch>/`,
never the working tree and never a checkout there. The tag is local to `../LibKa0s` and not yet
pushed; `tests/test_vendor_sync.lua` compares against the tag the provenance line names, so the
local tag is enough.

`git -C ../LibKa0s log --oneline v1.57.0..v1.58.0` lists 2 commits, both `LK-37` (the Launcher
change, and its release run). `git -C ../LibKa0s diff --stat v1.57.0 v1.58.0 -- LibKa0s testkit` →
1 file changed, 163 insertions, 94 deletions (`LibKa0s/Launcher.lua`); the kit is byte-identical.

## Baseline, before anything moved

- `ka0s-bounded lua5.1 tests/run.lua` → **928 passed, 0 failed, 0 skipped, 928 total**.
- `ka0s-bounded luacheck .` → **0 warnings / 0 errors in 61 files**.

## Step 0 — Pre-flight

Newest single-tag bundle `docs/revendor/2026-09-24-v1.57.0/`: line 1 names base `v1.56.0`, and its
own commit (`f993d63`) rolled the provenance line `v1.56.0` → `v1.57.0`. **ok**, no base correction.

## 3a — Claimed version

`grep -n 'Bundles' CLAUDE.md` → `CLAUDE.md:45`: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s)
**v1.57.0** (MIT). The last commit touching `libs/LibKa0s` or `tests/_kit` is `f993d63` (M5-PM),
whose line names `v1.57.0`. **The base is `v1.57.0`.**

## 3b — Actual version

`diff -rq` of the `v1.58.0` extract against both payloads before the copy: only
`libs/LibKa0s/Launcher.lua` differs, so the vendored bytes were exactly v1.57.0's. Kit revision
**26** (`tests/_kit/framework.lua:20`) on both sides.

## 3c — Per-file minor delta

| File | Constant | v1.57.0 | v1.58.0 |
|---|---|---|---|
| Launcher.lua | MINOR | 3 | **4** |

Every other file is unchanged: Core 8, Env 1, Compat 1, Lifecycle 2, Bus 2, Schema 2, Pool 3, Item 2,
Media 4, Widgets 10 / WidgetsDragHandle 2, DebugLog 13, Slash 15, Options 24.31.4.7.4, Perf 13 /
PerfPanel 5. No file added or removed, no `NEEDS_*` floor rises.

## 3d — Both diffs, before the copy

`diff -rq` and `diff -rq --strip-trailing-cr` agree: `libs/LibKa0s/Launcher.lua` differs;
`tests/_kit/` is empty both ways. Nothing is `Only in` either side, and nothing was to be deleted.

## 3e — Consumption map

`grep -n 'LibStub("LibKa0s-' core/*.lua settings/*.lua`:

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
| Schema | `settings/Schema.lua:459` |
| Slash | `settings/Slash.lua:423` |

The one major that moved (Launcher) is consumed, at `core/LauncherSetup.lua`.

## 3f — Kit revision, and the pairing rule

Revision **26 → 26**; the kit bytes are v1.57.0's. Both payloads are still copied whole in one
commit, so the pairing rule holds by construction.

## 3g — Contract delta

Walked `../LibKa0s/docs/api/Launcher/version-3-docs.md` → `version-4-docs.md` at the tag, and the
`CHANGELOG.md` entry *What a consumer owes on re-vendoring v1.58.0*.

| Major | What moved | This addon |
|---|---|---|
| Launcher 4 | Left-click always calls `openSettings`, in either state; the rungs and minor 2's disabled refusal are retired. Right-click opens `MenuUtil.CreateContextMenu` with one checkbox per supplied pair: `isEnabled` + `setEnabled(bool)`, `isLocked` + `toggleLock`, `isTestMode` + `toggleTestMode`, `isWindowShown` + `toggleWindow`; every entry but *Enabled* is grayed while disabled. `onClick`, `leftClickLabel`, `disabledLine` and `slash` are retired and ignored. The tooltip hints are fixed (`Open settings` / `Options menu`). No member added or removed (`members-4.json` = `members-3.json`). | This host passed `onClick = toggleLock` (rung (b)), `leftClickLabel` and `disabledLine`. On the copy alone its left click opens the panel instead of toggling the lock, and right-click still opens the panel (no pair supplied). `launcher-§2` (standard v2.67.0) owes `setEnabled` and `toggleLock`; this addon has no test mode and no primary window, so no `toggleTestMode` and no `isWindowShown` / `toggleWindow`. The standard's `ADDONS.md` row reads **Enabled · Locked**, which matches the code. Taken in the same M6-PM commit. |

Nine host launcher cases and `Disabled 8` pinned what minor 4 retires (the rung (b) left click, the
disabled refusal, the rung hints) and went red on the copy alone; the adoption re-pins them. The
Launcher degradation stub does not move (the member manifest is unchanged);
`tests/test_surface_parity.lua` stays green.

### Blockers

**None.** The contracts that tightened (the left click's meaning, the retired fields) are the ones
this host owes an adoption for, and the library ignores the retired fields rather than raising.

## 3h — Tags vendored and never recorded

None: `v1.57.0` has its bundle, and `v1.58.0` is this one.

## Step 4 — after the copy

Both payloads replaced whole from the extract (`rm -rf libs/LibKa0s tests/_kit`, then
`cp -r <scratch>/LibKa0s/. libs/LibKa0s/` and `cp -r <scratch>/testkit/. tests/_kit/`). Re-diffed
both with and without `--strip-trailing-cr`: **all four empty**. `git status` shows only
`libs/LibKa0s/Launcher.lua` among the payloads. `CLAUDE.md:45` provenance line rolled `v1.57.0` →
`v1.58.0` in the same commit.

After the copy alone: the suite ran 918 passed, **10 failed** (the ten cases above, all pinning
retired behavior); `tests/test_vendor_sync.lua` passes against the new line.
