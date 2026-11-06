Delta: LibKa0s v1.89.0 -> v1.90.0

Item `SF1-RV-PM` of Ka0sAddonsCommonTasks `docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/` (`SF1_SMOKE_FEEDBACK.md`,
*The items*, SF1-RV-<X>). The tag is **local**: `git -C ../LibKa0s ls-remote --tags origin v1.90.0`
prints nothing, which is expected for this run (it is pushed only at the owner's go-ahead), and this is
not a refresh: the provenance line names v1.89.0, not v1.90.0. `git -C ../LibKa0s rev-parse 'v1.90.0^{commit}'`
is `4485b8f589077b47e61f261405b3008bc4d81838`. Extract:
`git -C ../LibKa0s archive v1.90.0 LibKa0s testkit tools | tar -x -C /tmp/claude-1000/pm-v190`.

Written before the copy.

## Step 0 pre-flight (this addon)

    PanelMaster  2026-11-06-v1.89.0  base v1.85.0  vendored-before v1.85.0@604a336  ok

No base correction is owed.

## 3a. Claimed version, and the base

    $ grep -n '[Bb]undles' CLAUDE.md
    58:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.89.0 (MIT).

    $ c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)      # 604a336 V89-PM: Re-vendor LibKa0s v1.89.0
    $ git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+'
    Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.89.0

    $ git log --format='%h %s' "$c..HEAD" -- CLAUDE.md
    (nothing)

The two answers agree. `diff -rq` of `git -C ../LibKa0s archive v1.89.0 LibKa0s testkit` against
`libs/LibKa0s` prints only `Only in <extract>/LibKa0s/media/icons…` lines (the undeclared icons), and
against `tests/_kit` nothing. **Base: v1.89.0.**

    $ git -C ../LibKa0s log --oneline v1.89.0..v1.90.0
    4485b8f SF1-L3: Release v1.90.0 adds the release run's record and its notes
    4ac9f3c SF1-L3: Release v1.90.0 moves every version line to the tag and records the consumer sweep
    b9f7651 SF1-L2: RegisterOwner's keepScope, a Scope another addon's skin copy never writes
    7d42f4e SF1-L1: Every Widgets edge is one physical pixel at any UI scale, with no skin and under every skin
    e809ca3 Merge feat/2026-11-06-harvest-standards: the 2026-11-06 harvest, standard re-vendor and sync-docs
    72733ee SYNC-DOCS: Name the IconBrowser major everywhere the docs list majors, and DebugLog's current version
    1ca12c6 LK-K3: Merge feat/2026-11-05-kit-unregister-guard (LibKa0s v1.89.0, kit revision 51)
    $ git -C ../LibKa0s diff --stat v1.89.0 v1.90.0 | tail -1
    37 files changed, 35494 insertions(+), 94 deletions(-)

(Most insertions are the release's automated-test bundle and the new API documents.)

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` reports every
minor equal to the v1.89.0 tag's. The line and the bytes agree.

## 3c. Per-file minor delta (the tag's `LibKa0s/LibKa0s.xml` order)

Only the moved rows; every other file in the XML reads the same minor on both sides. No new file.

| File | v1.89.0 | v1.90.0 |
|---|---|---|
| `Core.lua` | `LibKa0s-Core-1.0` 15 | **16** |
| `Skin.lua` | `LibKa0s-Skin-1.0` 16 | **17** |
| `SkinPaint.lua` | `PAINT_MINOR` 18 | **19** |
| `SkinPaintExtras.lua` | `EXTRAS_MINOR` 17 | **18** |
| `Widgets.lua` | `LibKa0s-Widgets-1.0` 23 | **24** |
| `WidgetsAutocomplete.lua` | `AUTOCOMPLETE_MINOR` 7 | **8** |
| `OptionsAppearance.lua` | `APPEARANCE_MINOR` 6 | **7** |

No file is behind: no cross-major skew.

## 3d. Both diffs, before the copy

    $ diff -rq --strip-trailing-cr <extract>/LibKa0s libs/LibKa0s | grep -v 'Only in <extract>/LibKa0s/media/icons'
    Files …/Core.lua, OptionsAppearance.lua, Skin.lua, SkinPaint.lua, SkinPaintExtras.lua,
          Widgets.lua, WidgetsAutocomplete.lua … differ
    $ diff -rq --strip-trailing-cr <extract>/testkit tests/_kit
    (nothing)

The byte diffs list the same seven lines and nothing for the kit: no line-ending drift. No
`Only in libs/LibKa0s` line, so nothing upstream removed survives here.

## 3e. Consumption map

    $ grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
    core/BusSetup.lua:28 Bus · core/LauncherSetup.lua:128 Launcher · core/DebugLogSetup.lua:22 DebugLog
    core/CoreSetup.lua:34 Core · core/EnvSetup.lua:41 Env · core/MediaSetup.lua:42 Media
    core/LifecycleSetup.lua:70 Lifecycle · core/SkinSetup.lua:93 Skin · settings/OptionsSetup.lua:26 Options
    settings/Schema.lua:549 Schema · settings/Slash.lua:498 Slash

Eleven majors, one site each, unchanged. Widgets has no lookup: the addon draws no `W.Dropdown` or
`W.SearchBox` (`grep -rnE 'W\.Dropdown|W\.SearchBox' core settings modules` is empty).

## 3f. Kit revision

    $ grep -n 'Kit.VERSION' <extract>/testkit/framework.lua tests/_kit/framework.lua
    <extract>/testkit/framework.lua:20:Kit.VERSION = 51
    tests/_kit/framework.lua:20:Kit.VERSION = 51

Kit 51 on both sides. The pairing rule (both payloads move together) is satisfied by the whole-folder
copy.

## 3g. Contract delta

Moved majors intersected with consumed ones: **Core** (16), **Skin** (Skin 17, SkinPaint 19,
SkinPaintExtras 18) and **Options** (OptionsAppearance 7). Widgets moves but is not looked up.

- Core 16: "No public member is added, removed or renamed" (`docs/api/Core/version-16-docs.md:25`);
  the pixel-edge members are internal (`__`).
- Skin 17: `RegisterOwner(owner, { keepScope = true })` is additive, "a host's Skin facade owes
  nothing" (`docs/api/Skin/version-17.1.27.8.19.18.17.4.9-docs.md:21`); SkinPaint 19 / SkinPaintExtras
  18 move no member (`:31`).
- OptionsAppearance 7: `lib.__copySkinTo` skips the Scope only of a `keepScope` target; "every other
  host owes nothing" (`docs/api/Options/version-37.4.44.2.7.2.9.15.2.4.19.13.5.5.7.7.11.1.1.4-docs.md:26`).
  PanelMaster's Scope default is the collection's (`settings/Schema.lua:182` `skin.ignorePanel`
  default `true`), not a documented deviation, so it registers without `keepScope`
  (`core/SkinSetup.lua:578`) and takes a copy's Scope as before.
- Widgets 24: "What a host owes: nothing" (`docs/api/Widgets/version-24.5.12.6.8.5-docs.md:27`).

    $ grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit
    tests/test_libka0s.lua:669:  -- stays swept: lib.__AttachFlow in OptionsFlow.lua receives the descriptor too.

No host-supplied member reaches a moved call site. No suite pins a moved minor
(`grep -rnE 'Core = 15|Skin = 16|minor 15|minor 16' tests` finds only `tests/test_slash.lua:969`,
a Slash comment).

### Blockers

None.

## 3h. Tags vendored and never recorded

The skill's 3h listing (horizon `2026-08-25`, the store's first bundle) prints nothing. No span bundle.

## 3i. The icon declaration

    $ grep -n 'LibKa0s icons:' CLAUDE.md
    59:LibKa0s icons: chevron-down, chevron-up, clear, close, confirm, copy, eye, info, move, reset, settings, volume-high.

The next non-blank line under the provenance line, which ends its own sentence. **Kept as is**, as
the run decides (SF1-RV-<X> re-vendors; it adds no surface): nothing in v1.89.0..v1.90.0 draws a new
catalog name. Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup
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

No `__` member was removed in this range.
