Delta: LibKa0s v1.90.0 -> v1.91.0

Item `FU-RV-PM` of Ka0sAddonsCommonTasks `docs/2026-11-06-FOLLOWUPS_V1_91/` (`00_PLAN.md`, M2). The
tag is **local**: `git -C ../LibKa0s ls-remote --tags origin v1.91.0` prints nothing, which this run
expects (it is pushed only at the finalize), and this is not a refresh: the provenance line names
v1.90.0, not v1.91.0. `git -C ../LibKa0s rev-parse 'v1.91.0^{commit}'` is
`55bfbb47180ad0b8eb53c8c5277ea7176ab42c36`. Extract:
`git -C ../LibKa0s archive v1.91.0 LibKa0s testkit tools | tar -x -C /tmp/claude-1000/fu-rv-pm/x`.

Written before the copy.

## Step 0 pre-flight

**Skipped, stated.** The installed skill's roster regex (`\]\(\.\./\.\./…/\)`) expects markdown links,
and `../WowAddonStandards/standards/ADDONS.md` writes `` `../../<Folder>/` ``, so the loop matches no
addon and prints nothing. That is a known dev-copilot defect, fixed upstream in this run (`FU-DC1`).
The newest single-tag bundle, `2026-11-06-v1.90.0`, states base v1.89.0, and its own 3a records the
history check that confirms it. No base correction is owed.

## 3a. Claimed version, and the base

    $ grep -n '[Bb]undles' CLAUDE.md
    58:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.90.0 (MIT).

    $ c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)      # 127a500 SF2-RV-PM: Refresh LibKa0s v1.90.0
    $ git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+'
    Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.90.0

The two answers agree. **Base: v1.90.0.**

    $ git -C ../LibKa0s log --oneline v1.90.0..v1.91.0
    55bfbb4 FU-L3: Release v1.91.0 adds the release run's record and its notes
    1938837 FU-L3: Release v1.91.0 moves every version line to the tag and records the consumer sweep
    3f7be30 FU-L2: Peel the toast stack cases out of test_toast.lua into test_toast_stack.lua
    acc9640 FU-L2: Peel the confirmation box and the HUD looks out of SkinPaintExtras.lua
    c1ed261 FU-L2: Peel the dropdown and its shared menu out of Widgets.lua into WidgetsDropdown.lua
    d72dc4a FU-L2: Peel the pixel edges section out of Core.lua into CorePixel.lua
    55d3b0f FU-L1: The line chart's axis, grid, markers, crosshair and series are physical pixels at any UI scale
    f4be157 Merge feat/2026-11-06-revendor-libka0s-v1-89: LibKa0s v1.90.0 (physical-pixel Widgets edges and lines, RegisterOwner keepScope)
    06d97b0 V89-FIN: Sync docs to the v1.90.0 re-vendor run
    $ git -C ../LibKa0s diff --stat v1.90.0 v1.91.0 | tail -1
    62 files changed, 30753 insertions(+), 1835 deletions(-)
    $ git -C ../LibKa0s diff --stat v1.90.0 v1.91.0 -- LibKa0s | tail -1     # the payload alone
    9 files changed, 1414 insertions(+), 1203 deletions(-)

(Most insertions are the release's automated-test bundle and the three new API documents.)

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` reports every
minor equal to the v1.90.0 tag's. The line and the bytes agree.

## 3c. Per-file minor delta (the tag's `LibKa0s/LibKa0s.xml` order)

The skill's loop over `git -C ../LibKa0s show v1.91.0:LibKa0s/LibKa0s.xml`. Only the moved or new rows;
every other file reads the same minor on both sides. An empty old column is a file new in this range.

| File | v1.90.0 | v1.91.0 |
|---|---|---|
| `Core.lua` | `LibKa0s-Core-1.0` 16 | **17** |
| `CorePixel.lua` | (new) | `PIXEL_MINOR` **1** |
| `SkinPaintExtras.lua` | `EXTRAS_MINOR` 18 | **19** |
| `SkinPaintHud.lua` | (new) | `HUD_MINOR` **1** |
| `SkinAceConfirm.lua` | (new) | `CONFIRM_MINOR` **1** |
| `Widgets.lua` | `LibKa0s-Widgets-1.0` 25 | **26** |
| `WidgetsDropdown.lua` | (new) | `DROPDOWN_MINOR` **1** |
| `WidgetsLineChart.lua` | `CHART_MINOR` 6 | **7** |

No file is behind the tag: no cross-major skew. No `NEEDS_*` floor rises (CHANGELOG v1.91.0, *Versions
in this release*).

## 3d. Both diffs (before the copy)

    $ diff -rq --strip-trailing-cr <extract>/LibKa0s libs/LibKa0s | grep -v media/icons
    Files …/Core.lua and libs/LibKa0s/Core.lua differ
    Only in <extract>/LibKa0s: CorePixel.lua
    Files …/LibKa0s.xml and libs/LibKa0s/LibKa0s.xml differ
    Only in <extract>/LibKa0s: SkinAceConfirm.lua
    Files …/SkinPaintExtras.lua and libs/LibKa0s/SkinPaintExtras.lua differ
    Only in <extract>/LibKa0s: SkinPaintHud.lua
    Files …/Widgets.lua and libs/LibKa0s/Widgets.lua differ
    Only in <extract>/LibKa0s: WidgetsDropdown.lua
    Files …/WidgetsLineChart.lua and libs/LibKa0s/WidgetsLineChart.lua differ
    (214 further lines, all `Only in <extract>/LibKa0s/media/icons…`: the undeclared icons)
    $ diff -rq --strip-trailing-cr <extract>/testkit tests/_kit
    (nothing)

Exactly the release's payload files. No `Only in libs/LibKa0s` line: nothing was removed upstream.

## 3e. Consumption map

    $ grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
    core/DebugLogSetup.lua:22   DebugLog      core/LauncherSetup.lua:128  Launcher
    core/LifecycleSetup.lua:70  Lifecycle     core/EnvSetup.lua:41        Env
    core/BusSetup.lua:28        Bus           core/MediaSetup.lua:42      Media
    core/CoreSetup.lua:34       Core          core/SkinSetup.lua:93       Skin
    settings/OptionsSetup.lua:26 Options      settings/Slash.lua:498      Slash
    settings/Schema.lua:549     Schema

Eleven lookups, unchanged since v1.90.0. No Widgets lookup.

## 3f. Kit revision

    $ grep -n 'Kit.VERSION' <extract>/testkit/framework.lua tests/_kit/framework.lua
    <extract>/testkit/framework.lua:20:Kit.VERSION = 51
    tests/_kit/framework.lua:20:Kit.VERSION = 51

Unchanged at 51. The pairing rule (LibKa0s v1.9.0+ with kit revision 11+) holds; both payloads move
together in one commit regardless.

## 3g. Contract delta

The majors that moved and that this addon looks up: **Core** (17, with CorePixel 1) and **Skin**
(SkinPaintExtras 19, SkinPaintHud 1, SkinAceConfirm 1). Widgets moves (26, WidgetsDropdown 1,
WidgetsLineChart 7) but is not looked up here.

- Core: the peel moves `__PixelSize`, `__OnPixelScale`, `__WatchPixels`, `__PixelBackdrop` and
  `__RefreshPixelBackdrops` into `CorePixel.lua` unchanged; "The API is **additive-only**"
  (`docs/api/Core/version-17.1-docs.md:608-611`).
- Skin: `__AceConfirm*`, `S.BarGloss`, `S.HudFont` move into the two new files unchanged; the release
  says "v1.91.0 adds no Skin facade, major or instance member" (`docs/releasing.md`, step 8).

    $ diff <(git show v1.90.0:docs/api/Core/version-16-docs.md) <(git show v1.91.0:docs/api/Core/version-17.1-docs.md) | grep -E '^>' | grep -iE 'MUST|host|consumer'
    (nothing)
    $ diff <(git show v1.90.0:docs/api/Skin/version-17.1.27.8.19.18.17.4.9-docs.md) <(git show v1.91.0:docs/api/Skin/version-17.1.27.8.19.19.1.1.17.4.9-docs.md) | grep -E '^>' | grep -iE 'MUST|host owes|consumer'
    (nothing)
    $ grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit
    tests/test_libka0s.lua:669:  -- stays swept: lib.__AttachFlow in OptionsFlow.lua receives the descriptor too.

No host-supplied member reaches a moved call site.

### Blockers

The run's blocker classes, checked:

- **Library file lists.** `tests/run.lua`, `tests/test_harness.lua:227` and `tests/test_libka0s.lua:671`
  read the vendored `LibKa0s.xml` through the kit's `Loader.xmlFiles`, so the four new files load in
  the tag's order with no edit. No suite names a peeled file beside its peel (`grep -rn 'Widgets.lua\|
  Core.lua\|SkinPaintExtras' tests` finds only `tests/test_libka0s.lua:696`, which reads `Core.lua`'s
  source for a STRINGS / descriptor-`L` absence that the peel does not change). Nothing to add.
- **Minor pins.** No suite pins Core 16, Widgets 25, SkinPaintExtras 18 or WidgetsLineChart 6
  (`tests/test_libka0s.lua:47` compares `MODULES.Core` with `MINOR`, not a number). Nothing to move.
- **Stub mirrors of moved members.** `grep -rnE '__Pixel|__WatchPixels|__OnPixelScale' --include='*.lua'`
  outside `libs/` and `tests/_kit/` finds nothing. Nothing to update.

None owed.

## 3h. Tags vendored and never recorded

The skill's 3h listing, with `tag_at` rewritten on a named variable (`rev="$1"`; the installed text's
positionals arrive as argument words, a known defect fixed in `FU-DC1`), horizon `2026-08-25`:
65 tags vendored, 65 recorded, none unrecorded. No span bundle.

## 3i. The icon declaration

    $ grep -n 'LibKa0s icons:' CLAUDE.md
    59:LibKa0s icons: chevron-down, chevron-up, clear, close, confirm, copy, eye, info, move, reset, settings, volume-high.

The next non-blank line under the provenance line, which ends its own sentence. **Kept as is**, as the
run decides (`00_PLAN.md`: nothing to adopt; the peels are internal): nothing in v1.90.0..v1.91.0 draws
a new catalog name. Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup
`tests/test_mediasetup.lua:19`); the owner's in-client smoke is the backstop.

## 3j. Tests that assume the whole icon folder

    $ grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'
    tests/test_libka0s.lua:201   (a comment)
    tests/test_mediasetup.lua:11 (a comment)
    tests/test_mediasetup.lua:82 (iterates Media.ICONS to build a lookup, opens no file)
    tests/test_mediasetup.lua:109 (opens a file per DRAWN name, the declared set)

Not a blocker.

## Dead stub mirrors

    $ grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit
    tests/test_panels_page.lua:557  (a history comment, not a mirror)

No `__` member was removed in this range; the peeled members moved files and kept their names.
