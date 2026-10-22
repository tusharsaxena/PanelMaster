Delta: LibKa0s v1.71.0 -> v1.75.0

# 01 — Delta (PanelMaster)

Item PM-RV of the 2026-10-22 LibKa0s issues #45-#58 run
(`Ka0sAddonsCommonTasks/docs/2026-10-22-LIBKA0S_ISSUES_45_58/`), branch
`feat/2026-10-22-libka0s-issues-45-58`, run per the installed `/dev-copilot:wow-revendor-libka0s`
2.4.0. M2 is non-interactive under the run's ruling: no interview and no GitHub issue; candidates
are listed in `02_CANDIDATES.md`. Copied from the **local** annotated tag `v1.75.0` (tag object
`eae0ee5`, commit `265a89e`) with `git -C ../LibKa0s archive v1.75.0 LibKa0s testkit tools | tar -x
-C <scratch>`, never a branch tip and never a checkout in the library's working tree. The tag is not
pushed yet.

## Step 0. Pre-flight

The newest single-tag bundle, `docs/revendor/2026-10-07-v1.71.0/`, states base v1.70.0 on line 1;
the provenance line before its re-vendor commit `9fa5c52` named v1.70.0. `ok`, so no correction is
owed.

## 3a. Base

`grep -n '[Bb]undles' CLAUDE.md` -> `50:Bundles [LibKa0s](...) v1.71.0 (MIT). That line is the`
(the provenance sentence ran on into prose; see 3i). The last payload commit is `9fa5c52`
(`RV-PM: Re-vendor LibKa0s v1.71.0 (kit 38)`), whose `CLAUDE.md` names v1.71.0, and `diff -rq` of
the v1.71.0 archive against both payloads printed `payload-matches`. Base **v1.71.0**.

`git -C ../LibKa0s log --oneline v1.71.0..v1.75.0`: 56 commits, spanning v1.72.0, v1.73.0, v1.74.0
and v1.75.0. PanelMaster never vendored the middle three, so they need no record of their own.
`git -C ../LibKa0s diff --stat v1.71.0 v1.75.0 -- LibKa0s testkit`: 5752 files changed, 8798
insertions, 121 deletions. Of those, 5726 are `LibKa0s/media` (the v1.74.0 icon sets), 18 are
the rest of `LibKa0s/` (3903 insertions, 69 deletions) and 8 are `testkit/` (633 insertions, 52
deletions).

## 3b/3c. Per-file minors that moved (from the tag's `LibKa0s.xml`)

| File | Before | After | Major key at the tag |
|---|---|---|---|
| `Core.lua` | 10 | 11 | `LibKa0s-Core-1.0` 11 (comment-only, #57) |
| `Item.lua` | 2 | 3 | `LibKa0s-Item-1.0` 3 (`BonusIDsFromLink`) |
| `Glow.lua` | — | 1 | `LibKa0s-Glow-1.0` 1 (**new major**) |
| `Media.lua` | 4 | 5 | `LibKa0s-Media-1.0` 5.1 |
| `MediaIcons.lua` | — | 1 | (same; new file) |
| `Widgets.lua` | 12 | 13 | `LibKa0s-Widgets-1.0` 13.1.4.3.2 (`SearchBox`, `TestStrip`) |
| `DebugLog.lua` | 19 | 20 | `LibKa0s-DebugLog-1.0` 20.3.1 (comment-only, #57) |
| `DebugLogDiagnostics.lua` | 2 | 3 | (same; Glow and Sim in the identity header) |
| `Options.lua` | 28 | 29 | `LibKa0s-Options-1.0` 29.2.34.2.5.9.1.7.4.2.1 |
| `OptionsIdList.lua` | 4 | 5 | (same; comment-only, #57) |
| `OptionsTabs.lua` | 8 | 9 | (same; `O.__releaseChrome` no longer exported, #45) |
| `OptionsDrawer.lua` | — | 1 | (same; new file, `O.Drawer`) |
| `Perf.lua` | 14 | 15 | `LibKa0s-Perf-1.0` 15.1.1.7 (`Note` with `parentKey = false`) |
| `PerfPanel.lua` | 6 | 7 | (same; comment-only) |
| `Sim.lua` | — | 1 | `LibKa0s-Sim-1.0` 1.1.1 (**new major**) |
| `SimTimeline.lua` | — | 1 | (same; new file) |
| `SimPanel.lua` | — | 1 | (same; new file, the Sim-private step panel) |

Every other file is at its v1.71.0 minor (`Env` 2, `Compat` 1, `Lifecycle` 3, `Bus` 2, `Schema` 2,
`Pool` 3, `Slash` key 20.2, `Launcher` 5, and the unmoved secondary files). No `NEEDS_*` floor
rises. `WidgetsStepPanel.lua` is **not** in the tag: LK-11's outcome B withdrew `W.StepPanel` and
moved the renderer Sim-private into `SimPanel.lua`. The library is seventeen majors across forty
files (`grep -h 'local MAJOR,' libs/LibKa0s/*.lua | sort -u` counts 17). No cross-major skew.

## 3d. Diffs

Before the copy, `diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s` printed the twelve
moved files, `LibKa0s.xml` and `Only in <scratch>` for the six new files and 113 `media/icons`
entries (the 111 new Open Iconic marks and the `phosphor/` and `game-icons/` folders). The testkit
diff printed seven changed files and `Only in <scratch>/testkit: latch.lua`. Neither printed an
`Only in libs/LibKa0s` or `Only in tests/_kit` line, so nothing was deleted on inference.

## 3e. Consumption

`LibStub("LibKa0s-*-1.0", true)` outside `libs/` and `tests/`: Core, Launcher, Lifecycle, Env, Media,
Bus, DebugLog (`core/`), Options, Slash, Schema (`settings/`). Ten majors, unchanged. `Widgets`,
`Pool`, `Item`, `Compat`, `Glow` and `Sim` have no lookup site; `Perf` is the ratified decline.

## 3f. Kit revision

`Kit.VERSION` 38 -> **41**. Revision 39: `testkit/latch.lua` (`Kit.assertLatchHoldOrder`), and
`M.__fireUnconditional` reaches a method-name or function handler after unregister through
`__kitEver`. Revision 40: `vendor_sync.lua` holds `media/icons/` to the `LibKa0s icons:`
declaration. Revision 41: `Kit.__deviationRows` / `Kit.__declineFor` no longer exported, and a
crashed or bounded lizard run is a complexity `fail` with its own `crashed` bucket. Both payloads
are copied whole in one commit, so the pairing rule holds by construction.

## 3g. Contract changes under unchanged signatures

`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` is empty:
the addon hands the library no callback member through an attach seam. What still moves under it:

- **Options minor 29, scroll kept on a structural refresh.** `O.RefreshPanel(ctx, true)` and
  `RefreshAllPanels` now restore a shown page's scroll offset (Options
  `version-29.2.34.2.5.9.1.7.4.2.1-docs.md:76-80`; through minor 28 the render's first `AddChild`
  zeroed it). `settings/PanelEditor.lua:745` calls `RefreshPanel(ctx, true)`, so the Panels page
  now stays where the player was after a re-rendering write. Class A, delivered on the copy; smoke
  PANEL-34.
- **Options minor 29 / OptionsDrawer 1, `O.Drawer`.** A new public member, so the by-name parity
  case `tests/test_surface_parity.lua` ("Parity: the Options seam's degraded surface matches the
  live one") goes red until the degraded stub gains `Drawer`. **Blocker a**, fixed.
- **Kit 39, `__fireUnconditional` reach.** `tests/test_disabled.lua` "Disabled 6" part (b) fired the
  bus message names at the renderer's target and asserted 0. The helper reads the target's
  `__events` / `__kitEver` / a same-named method, never the message registry
  (`tests/_kit/mock_record.lua`, `M.__fireUnconditional`), so those zeros held whether or not the
  subscription survived. **Blocker c**, fixed.
- **Kit 40, declared icons.** With a declaration, `media/icons/` must equal the declared names plus
  the shipped sets' license files. Two suites assumed the whole catalog: `tests/test_mediasetup.lua`
  ("every name the library ships has a file in the vendored copy") and `tests/test_libka0s.lua`
  ("the info art the descriptor's addonName points at is on disk"). **Blockers d and e**, fixed
  (3j).
- **Kit 41, a crashed lizard run is a fail.** Release-only (`complexity` never gates a commit here);
  `docs/testing.md`'s suite table now says so (**blocker f**).
- **#57's comment-only minors (Core 11, DebugLog 20, OptionsIdList 5).** A host that passes its
  addon name and did not declare an icon gets a **blank** control, not the text fallback. This
  addon passes `addonName` to DebugLog (`core/DebugLogSetup.lua:127`), so the declaration below is
  what keeps the console's marks.

### Blockers (all fixed in the re-vendor commit)

- **a.** `settings/OptionsSetup.lua`: `Drawer = noop` beside `NavRail = noop`, with its comment.
- **b.** `O.__releaseChrome` mirror: none to delete. The stub carries no `__` internals
  (`settings/OptionsSetup.lua`, the block after `NavRail`), and
  `grep -rn __releaseChrome core modules settings tests/*.lua` returns one historical comment,
  `tests/test_panels_page.lua:556`. Left.
- **c.** `tests/test_disabled.lua` "Disabled 6": (b) now reads `mocks.__msgRegistry[...]` for
  `NS.Registry.MSG.PANELS` and `NS.Schema.MSG.SETTINGS` and asserts the renderer's target is
  absent; a new (b2) fires `PLAYER_ENTERING_WORLD`, `PLAYER_REGEN_ENABLED` and
  `PLAYER_REGEN_DISABLED` at `NS.addon` through `__fireUnconditional`, each asserted to answer 1,
  ahead of the existing SavedVariables, chat and shown-frame assertions.
- **d.** `tests/test_mediasetup.lua`: the whole-catalog loop is replaced by "the CLAUDE.md icon
  declaration names exactly the marks the console draws", through the kit's
  `VendorSync.iconDeclaration`, both ways against `DRAWN`, then a file check per drawn name.
- **e.** `tests/test_libka0s.lua`: the `info.tga` case becomes "info is declared exactly when a
  page builds an IdList". No `settings/` file on the TOC calls `IdList(` outside comments, and the
  declaration does not name `info`.
- **f.** `docs/testing.md`'s `complexity` row names the kit-41 `crashed` bucket.
- **g.** `grep -rn '__deviationRows\|__declineFor' tests/*.lua` returns nothing; no consumer.
- **h.** Glow and Sim load through `libs/LibKa0s/LibKa0s.xml` (`PanelMaster.toc:37`);
  `tests/test_harness.lua`'s every-major-registers case covers both and is green, so Glow
  registers without LibCustomGlow-1.0.

## 3h. Unrecorded tags

The walk from the store's horizon (2026-08-25) found 52 tags vendored, every one recorded. No span
bundle.

## 3i. The icon declaration

No line before this run. Provenance split (3i b): `CLAUDE.md:50` ran on into prose
(`... v1.71.0 (MIT). That line is the`), so the provenance sentence now ends its line, the
declaration sits directly under it, and the prose resumes after a blank line. Decided by the run's
item spec (PM-RV) and recorded here, not re-asked:

    LibKa0s icons: clear, close, copy.

Derivation. No literal icon call of the addon's own: `NS.Icon` (`core/MediaSetup.lua:56-59`) has no
caller in `core/`, `modules/` or `settings/`, and the launcher draws `C.ICON_PATH`, the addon's own
art. Every mark is library-drawn on the addon's behalf, read against the tag's `docs/releasing.md`
(*Library-drawn icons are the host's to declare*, line 312) and the v1.75.0 *What a consumer owes*:

- `close`: `Core.MakeCloseButton` given the addon name, reached through the DebugLog console and its
  copy window (`core/DebugLogSetup.lua:116-127`, `addonName = addonName`), and through
  `NS.MakeCloseButton` (`core/CoreSetup.lua:142-144`), which no standalone window calls yet.
- `copy`, `clear`: the DebugLog console's title-bar buttons (same descriptor).
- `info` is **not** declared. The Options descriptor passes `addonName`
  (`settings/OptionsSetup.lua:184`), but no page builds an `IdList` (the stub's `IdList = noop`), so
  OptionsIdList's help mark is never drawn. No `W.TestStrip`, no Sim panel, no host-passed art.
- `Perf` is declined, so there is no PerfPanel close.

Hand lists have drifted before (KickCD and WhatGroup `tests/test_mediasetup.lua`); the owner's
in-client smoke DIAG-2 is the backstop, because a pruned icon still resolves to a path and draws
blank.

## 3j. Tests that assumed the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'` found
`tests/test_libka0s.lua:202-203` (info.tga) and `tests/test_mediasetup.lua:76`, `:90-91`. The `:76`
case (every drawn name is in the catalog) stays; the other two are blockers d and e above.
