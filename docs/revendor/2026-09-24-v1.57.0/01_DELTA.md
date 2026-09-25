Delta: LibKa0s v1.56.0 -> v1.57.0

# 01 — Delta

Run: 2026-09-24, item M5-PM of the 2026-09-23 review and standards-audit remediation plan (milestone
M5, the always-on launcher status tooltip). Steps 0–4 of `/wow-addon:revendor-libka0s`, taken by hand
the way RV-PM took them for v1.56.0. The one adoption this release owes (the Launcher descriptor's
new fields) is the second `M5-PM` commit, not this one. Nothing was pushed. Target: this repo,
branch `feat/2026-09-23-review-audit-remediation` @ `a3b4390`.

Source: the sibling checkout `../LibKa0s`, **tag `v1.57.0` (tag object `d03e836` → commit
`aa37bc9`)**, extracted with `git -C ../LibKa0s archive v1.57.0 LibKa0s testkit | tar -x -C <scratch>/`,
never the working tree and never a checkout there. The tag is local to `../LibKa0s` and not yet
pushed; `tests/test_vendor_sync.lua` compares against the tag the provenance line names, so the
local tag is enough.

`git -C ../LibKa0s log --oneline v1.56.0..v1.57.0` lists 2 commits, both `LK-36` (the Launcher
change, and its release run). `git -C ../LibKa0s diff --stat v1.56.0 v1.57.0 -- LibKa0s testkit` →
1 file changed, 109 insertions, 4 deletions (`LibKa0s/Launcher.lua`); the kit is byte-identical.

## Baseline, before anything moved

- `ka0s-bounded lua5.1 tests/run.lua` → **921 passed, 0 failed, 0 skipped, 921 total**.
- `ka0s-bounded luacheck .` → **0 warnings / 0 errors in 61 files**.

## Step 0 — Pre-flight

Newest single-tag bundle `docs/revendor/2026-09-23-v1.56.0/`: line 1 names base `v1.55.0`, and its
own commit (`b26ab40`) rolled the provenance line `v1.55.0` → `v1.56.0`. **ok**, no base correction.

## 3a — Claimed version

`grep -n 'Bundles' CLAUDE.md` → `CLAUDE.md:45`: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s)
**v1.56.0** (MIT). The last commit touching `libs/LibKa0s` or `tests/_kit` is `b26ab40` (RV-PM),
whose line names `v1.56.0`. **The base is `v1.56.0`.**

## 3b — Actual version

`diff -rq` of the `v1.57.0` extract against both payloads before the copy: only
`libs/LibKa0s/Launcher.lua` differs, so the vendored bytes were exactly v1.56.0's. Kit revision
**26** (`tests/_kit/framework.lua:20`) on both sides.

## 3c — Per-file minor delta

| File | Constant | v1.56.0 | v1.57.0 |
|---|---|---|---|
| Launcher.lua | MINOR | 2 | **3** |

Every other file is unchanged: Core 8, Env 1, Compat 1, Lifecycle 2, Bus 2, Schema 2, Pool 3, Item 2,
Media 4, Widgets 10 / WidgetsDragHandle 2, DebugLog 13, Slash 15, Options 24.31.4.7.4, Perf 13 /
PerfPanel 5. No file added or removed, no `NEEDS_*` floor rises.

## 3d — Both diffs, before the copy

`diff -rq` and `diff -rq --strip-trailing-cr` agree: `libs/LibKa0s/Launcher.lua` differs;
`tests/_kit/` is empty both ways. Nothing is `Only in` either side, and nothing was to be deleted.

## 3e — Consumption map

`grep -n 'LibStub("LibKa0s-' core/*.lua settings/*.lua` at `a3b4390`:

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

Revision **26 → 26**; the kit bytes are v1.56.0's. Both payloads are still copied whole in one
commit, so the pairing rule holds by construction.

## 3g — Contract delta

Walked `../LibKa0s/docs/api/Launcher/version-2-docs.md` → `version-3-docs.md` at the tag, and the
`CHANGELOG.md` entry *What a consumer owes on re-vendoring v1.57.0*.

| Major | What moved | This addon |
|---|---|---|
| Launcher 3 | The LDB object's `OnTooltipShow` is always the library's, drawing the status block on every hover, disabled included. New optional descriptor fields `version`, `isLocked`, `isTestMode`, `leftClickLabel`, `slash`; `onTooltipShow` now appends instead of being the whole tooltip; fourteen `TOOLTIP_*` strings. No member added or removed (`members-3.json` = `members-2.json`). | This host passed no `onTooltipShow` (`core/LauncherSetup.lua`, *DELIBERATELY NOT PASSED*), so there is nothing to cut. The tooltip arrives on the copy alone, but reads `Enabled: Yes` always and `Left-click: Toggle`, because the host passed no `isEnabled` (it gated its own `toggleLock`) and no `leftClickLabel`. `launcher-§1` (standard v2.66.0) owes `version`, `leftClickLabel` for rung (b), and `isLocked` (this addon has the *Lock frame* lock); it has **no** test mode, so no `isTestMode`. Taken by the second `M5-PM` commit. |

No host test called `OnTooltipShow`, so none reddens on the copy. The Launcher degradation stub
does not move (the member manifest is unchanged); `tests/test_surface_parity.lua` stays green.

### Blockers

**None.** No host-supplied member's contract tightened; `onTooltipShow`'s changed meaning does not
reach a host that never passed one.

## 3h — Tags vendored and never recorded

None: `v1.56.0` has its bundle, and `v1.57.0` is this one.

## Step 4 — after the copy

Both payloads replaced whole from the extract (`rm -rf libs/LibKa0s tests/_kit`, then
`cp -r <scratch>/LibKa0s/. libs/LibKa0s/` and `cp -r <scratch>/testkit/. tests/_kit/`). Re-diffed
both with and without `--strip-trailing-cr`: **all four empty**. `git status` shows only
`libs/LibKa0s/Launcher.lua` among the payloads. `CLAUDE.md:45` provenance line rolled `v1.56.0` →
`v1.57.0` in the same commit.

Gates (all through `ka0s-bounded`):

- `lua5.1 tests/run.lua` → **921 passed, 0 failed, 0 skipped, 921 total**; `tests/test_vendor_sync.lua`
  passes against the new line.
- `luacheck .` → **0 warnings / 0 errors in 61 files**.
- `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .` → no function above CCN 15; the
  largest authored `.lua` file is `settings/PanelEditor.lua` at 1447 lines.
