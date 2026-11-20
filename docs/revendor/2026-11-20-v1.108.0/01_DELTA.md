Delta: LibKa0s v1.107.0 -> v1.108.0

Recorded with the copy, before anything was committed. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.108.0 LibKa0s testkit tools` (tag commit 56c20b76, a local tag on the LibKa0s branch `feat/2026-11-20-libka0s-94-97-99-100`, not on origin yet: `git -C ../LibKa0s ls-remote --tags origin v1.108.0` prints nothing). Run under Ka0sAddonsCommonTasks `docs/2026-11-20-LIBKA0S_94_97_99_100/`, item SD-RV-PM. The copy-and-bundle half of `/dev-copilot:wow-revendor-libka0s` (dev-copilot 2.10.1) only: the run's bundle decides this addon's work (SD-SK-PM and the owner's U-23), so there is no interview and no GitHub issue.

## 3a Base
- `grep -n '[Bb]undles' CLAUDE.md` named v1.107.0 before the roll (CLAUDE.md:59).
- Last payload commit, `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = 0f4a663 ("Re-vendor the re-cut LibKa0s v1.107.0"); its CLAUDE.md names v1.107.0. They agree.
- Payload before the copy equalled the library at v1.107.0 (87ae35f): `diff -rq --strip-trailing-cr` of both payloads against a v1.107.0 extract printed only `Only in <extract>/LibKa0s/media/sounds: callout` and the undeclared icons, both the declarations working (payload-matches).
- Library range: `git -C ../LibKa0s log --oneline v1.107.0..v1.108.0` is 15 commits; `git -C ../LibKa0s diff --stat v1.107.0 v1.108.0 -- LibKa0s testkit` is 23 files, 1363 insertions, 306 deletions.
- Step 0: the newest single-tag bundle, `2026-11-19-v1.107.0`, states base v1.106.0, the provenance tag before its re-vendor (7bec747). No correction.

## 3b/3c Per-file minors that moved (old = this addon at v1.107.0, new = v1.108.0)
Loop over the tag's `LibKa0s/LibKa0s.xml`, each file's `local (MAJOR, )?[A-Z_]*MINOR` constant; only the changed rows:
```
Core.lua                   old: 18  new: 19
Callout.lua                old: 4   new: 5
CalloutSettings.lua        old: 5   new: 6
WaypointArrow.lua          old: 2   new: 3
WaypointArrowSettings.lua  old: 2   new: 3
Charts.lua                 old: 2   new: 3
ChartsRender.lua           old: 1   new: 2
SkinPaint.lua              old: 19  new: 20
SkinPaintHud.lua           old: 1   new: 2
SkinPaintControls.lua      old: 18  new: 19
Widgets.lua                old: 29  new: 30
WidgetsDropdown.lua        old: 2   new: 3
WidgetsDragHandle.lua      old: 15  new: 16
WidgetsDragHandleTip.lua   old: 2   new: 3
WidgetsLineChart.lua       old: 7   new: 8
WidgetsBar.lua             old: 1   new: 2
OptionsCompose.lua         old: 19  new: 20
```
The claimed version (v1.107.0) and the minors on disk agreed before the copy. No cross-major skew.

## 3d Diffs
After the copy and before the prune, `diff -rq --strip-trailing-cr` and `diff -rq` of `<extract>/LibKa0s` against `libs/LibKa0s` and of `<extract>/testkit` against `tests/_kit` all printed nothing. After the prune the only differences are the undeclared icons and the Callout sound packs.

## 3e Consumption map
The addon's own lookups (`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' --include='*.lua' .`, the addon's files only): Bus, Compat, Core, DebugLog, Env, Launcher, Lifecycle, Media, Options, Schema, Skin, Slash, the same twelve as at v1.107.0. Of the moved majors it consumes Options (OptionsCompose minor 20), Skin (SkinPaint, SkinPaintHud, SkinPaintControls) and Core. It builds no `W.Bar`, Charts context, Callout, WaypointArrow, `W.ContextMenu`, drag strip or footer, and calls no `S.ApplyBarFill` (`grep -rn "W\.Bar\b\|ApplyBarFill(\|ContextMenu(\|Callout\|Waypoint\|Charts" --include='*.lua' core modules settings` finds only the facade's name list in `core/SkinSetup.lua:506`).

## 3f Kit revision
`grep -n 'Kit.VERSION'`: 58 in the tag, 57 here before the copy. Both payloads copied whole, together.

## 3g Contract delta
**One blocker, fixed in the re-vendor commit.** OptionsCompose minor 20 (Options document `version-38.5.46.3.7.2.9.17.3.1.4.20.13.7.5.8.7.12.1.1.1.4-docs.md`, *Moving to this version: what each addon owes at its re-vendor*, lines 34-44) turns every composer's companions on by default: `O.BorderGroup` and `O.BarGroup` called with no `fromSkin` now emit *Use the skin's border* / *Use the skin's texture* and *Use the skin's color*. No signature moved. PanelMaster's panel editor composes three blocks (`settings/PanelEditorTabs.lua`, the Background and border tab's `O.BorderGroup`, the Accent bar tab's `O.BarGroup` and its `O.BorderGroup`), and the panels are the player's content: the owner's U-23 (2026-11-20, Ka0sAddonsCommonTasks `docs/2026-11-20-LIBKA0S_94_97_99_100/SD_RULE.md`) keeps the new-panel look as content, and the document's item 2 names exactly this case ("PanelMaster's panel editor, U-23 ... passes `fromSkin = false` ... and owes nothing else"). Under minor 20 unmodified the editor drew four dead companion rows, which nothing reads, and the suite caught it (`optionsgroups` #48 canonical-order and write-elsewhere cases, the Layout tab-line count). Fix: `fromSkin = false` on each of the three calls with the ruling cited, minor 19's block byte for byte.

**Kit revision 58's scanner.** `test_skin_values` now reads tables of three or four numbers and flagged the new-panel template's five colors (`core/Constants.lua` `bgColor`, `borderColor`, `accentColor`, `accentBorderColor`, `artColor`) and the panel color normalizer's white fallback (`core/Util.lua`, `Util.Color`). Each is the player's panel content (A8, owner U-23): six `Kit.skinValues` rows in `tests/run.lua`, each citing the ruling. The skin-switch test's new family and StatusBar checks pass on this addon's six declared surfaces unchanged (no surface holds a StatusBar).

`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` finds only a test comment; no host-supplied member's call site moved.

## 3h Unrecorded tags
The Step 3h listing printed nothing (vendored 72 tags, recorded 72). No span bundle.

## 3i Icon declaration
`grep -n 'LibKa0s icons:' CLAUDE.md` = CLAUDE.md:60, the next non-blank line after the provenance line. Kept as written (12 names). v1.108.0 adds no library-drawn icon this addon's surfaces need. No `LibKa0s sounds:` line, which means none. No provenance split needed.

## 3j Tests assuming the whole icon folder
`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'`: the same four hits as at v1.107.0, none a whole-catalog loop. None is a blocker. `__releaseChrome` appears only in a history comment (`tests/test_panels_page.lua:557`); no mirror.
