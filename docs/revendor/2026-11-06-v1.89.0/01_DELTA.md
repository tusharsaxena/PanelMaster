Delta: LibKa0s v1.85.0 -> v1.89.0

Item `V89-PM` of Ka0sAddonsCommonTasks `docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/`. The tag is pushed
(`git -C ../LibKa0s ls-remote --tags origin v1.89.0` prints `0bd4839c935c812a8dea58c190422aa476870b77`,
the annotated tag object); `git -C ../LibKa0s rev-parse 'v1.89.0^{commit}'` is
`df00e5f09fc71b59001b9e83afb22f868573b3d2`. Extract:
`git -C ../LibKa0s archive v1.89.0 LibKa0s testkit tools | tar -x -C /tmp/claude-1000/v89-pm-1492310/tag`.

Written before the copy.

## Step 0 pre-flight

Ka0sAddonsCommonTasks `docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/inputs/step0-preflight.txt:12`:

    PanelMaster  2026-11-01-v1.85.0  base v1.84.0  vendored-before v1.84.0@2cac205  ok

No base correction is owed.

## 3a. Claimed version, and the base

    $ grep -n '[Bb]undles' CLAUDE.md
    58:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.85.0 (MIT).

    $ c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)      # 763455c R6-RV2: Re-vendor LibKa0s v1.85.0 ...
    $ git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+'
    Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.85.0

    $ git log --format='%h %s' "$c..HEAD" -- CLAUDE.md
    a595642 SYNC-DOCS: Cite own code by symbol, scope the majors count, fix drift (documentation-§6)

The two answers agree (v1.85.0); `a595642` leaves the provenance line alone. The payload today is the
library's at v1.85.0: `diff -rq` against `git -C ../LibKa0s archive v1.85.0 LibKa0s testkit` prints
only `Only in <extract>/LibKa0s/media/icons…` lines (the undeclared icons) for `libs/LibKa0s`, and
nothing for `tests/_kit`. **Base: v1.85.0.**

    $ git -C ../LibKa0s log --oneline v1.85.0..v1.89.0 | wc -l
    27
    $ git -C ../LibKa0s diff --stat v1.85.0 v1.89.0 | tail -1
    83 files changed, 125301 insertions(+), 321 deletions(-)

(The insertion count is mostly the IconBrowser source catalog.)

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` reports every
minor equal to the v1.85.0 tag's (Toast 3, Widgets 22, DebugLogDiagnostics 6, the rest as below). The
line and the bytes agree.

## 3c. Per-file minor delta (the tag's `LibKa0s/LibKa0s.xml` order)

Only the moved rows; every other file in the XML reads the same minor on both sides.

| File | v1.85.0 | v1.89.0 |
|---|---|---|
| `Toast.lua` | `LibKa0s-Toast-1.0` 3 | **4** |
| `Widgets.lua` | `LibKa0s-Widgets-1.0` 22 | **23** |
| `DebugLogDiagnostics.lua` | `DIAG_MINOR` 6 | **7** |
| `IconBrowserSources.lua` | (new) | `LibKa0s-IconBrowser-1.0` 1 |
| `IconBrowserWindow.lua` | (new) | `WINDOW_MINOR` 1 |
| `IconBrowser.lua` | (new) | `BROWSER_MINOR` 1 |

No file is behind: no cross-major skew.

## 3d. Both diffs, before the copy

    $ diff -rq --strip-trailing-cr <extract>/LibKa0s libs/LibKa0s | grep -v 'Only in <extract>/LibKa0s/media/icons'
    Files .../DebugLogDiagnostics.lua and libs/LibKa0s/DebugLogDiagnostics.lua differ
    Only in .../LibKa0s: IconBrowser.lua
    Only in .../LibKa0s: IconBrowserSources.lua
    Only in .../LibKa0s: IconBrowserWindow.lua
    Files .../LibKa0s.xml and libs/LibKa0s/LibKa0s.xml differ
    Files .../Toast.lua and libs/LibKa0s/Toast.lua differ
    Files .../Widgets.lua and libs/LibKa0s/Widgets.lua differ
    $ diff -rq --strip-trailing-cr <extract>/testkit tests/_kit
    Files .../README.md, framework.lua, mock_ace.lua differ

The byte diffs list the same seven and three lines: no line-ending drift. No `Only in libs/LibKa0s`
line, so nothing upstream removed survives here. The `Only in <extract>/LibKa0s/media/icons…` lines are
the icons the declaration leaves out.

## 3e. Consumption map

    $ grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
    core/EnvSetup.lua:41        Env
    core/CoreSetup.lua:34       Core
    core/MediaSetup.lua:42      Media
    core/LifecycleSetup.lua:70  Lifecycle
    core/BusSetup.lua:28        Bus
    core/LauncherSetup.lua:128  Launcher
    core/DebugLogSetup.lua:22   DebugLog
    core/SkinSetup.lua:93       Skin
    settings/OptionsSetup.lua:26 Options
    settings/Schema.lua:549     Schema
    settings/Slash.lua:498      Slash

Eleven majors, one site each, as before. Toast, Widgets (directly) and IconBrowser have no lookup.
`grep -rnE 'Widgets|ContextMenu' core settings modules` finds only a comment
(`settings/OptionsSetup.lua:130`): the addon opens no `W.ContextMenu`.

## 3f. Kit revision

    $ grep -n 'Kit.VERSION' <extract>/testkit/framework.lua tests/_kit/framework.lua
    <extract>/testkit/framework.lua:20:Kit.VERSION = 51
    tests/_kit/framework.lua:20:Kit.VERSION = 50

Kit 50 -> 51 travels with the library in the one commit (the pairing rule: both payloads move
together, satisfied by the whole-folder copy).

## 3g. Contract delta

Moved majors intersected with consumed ones: **DebugLog** (Diagnostics 6 -> 7). Toast and Widgets move
but are not looked up by this addon. Two consumed majors' documents changed without a minor:

- `docs/api/DebugLog/version-22.6.1.4-docs.md` -> `version-22.7.1.4-docs.md`: "No member change"
  (`version-22.7.1.4-docs.md:21`); the report's `LibKa0s running:` line also lists IconBrowser when it
  runs, and "a host suite that pins `DebugLogDiagnostics 6` re-pins it at 7" (`:948-951`).
  `grep -rnE 'DebugLogDiagnostics|DIAG_MINOR' tests` finds no pin (only a comment,
  `tests/test_diagnostics.lua:386`).
- `docs/api/Launcher/version-7-docs.md:33-40` and the Options C19 document's line 43 state the R7-L1
  rule for `isSimMode`. PanelMaster has no simulation (`grep -rnE 'isSimMode|toggleSim' core settings
  modules` is empty), so it passes neither and owes nothing.

    $ grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit
    tests/test_libka0s.lua:669:  -- stays swept: lib.__AttachFlow in OptionsFlow.lua receives the descriptor too.

No host-supplied member reaches a moved call site.

### Blockers

None.

## 3h. Tags vendored and never recorded

The skill's 3h listing (horizon `2026-08-25`, the store's first bundle) prints nothing. No span bundle.

## 3i. The icon declaration

    $ grep -n 'LibKa0s icons:' CLAUDE.md
    59:LibKa0s icons: chevron-down, chevron-up, clear, close, confirm, copy, eye, info, move, reset, settings, volume-high.

The next non-blank line under the provenance line, which ends its own sentence. **Kept as is**: nothing
in v1.85.0..v1.89.0 draws a new catalog name for a surface this addon wires (Widgets 23's submenu arrow
is client art, `Interface\ChatFrame\ChatFrameExpandArrow`, `docs/api/Widgets/version-23.5.12.6.7.5-docs.md:27`,
and the addon opens no context menu). `tests/test_mediasetup.lua` holds the declaration to its `DRAWN`
list. Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup
`tests/test_mediasetup.lua:19`); the owner's in-client smoke is the backstop.

## 3j. Tests that assume the whole icon folder

    $ grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'
    tests/test_libka0s.lua:201   (a comment)
    tests/test_mediasetup.lua:11 (a comment)
    tests/test_mediasetup.lua:82 (iterates Media.ICONS to build a lookup, opens no file)
    tests/test_mediasetup.lua:109 (opens a file per DRAWN name, the declared set)

No whole-catalog file loop and no undeclared-file assertion: not a blocker.

## Dead stub mirrors

    $ grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit
    tests/test_panels_page.lua:557  (a history comment, not a mirror)

No `__` member was removed in this range; nothing to remove.
