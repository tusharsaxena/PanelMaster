Delta: LibKa0s v1.94.0 -> v1.105.0

Recorded with the copy, before anything was committed. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.105.0 LibKa0s testkit tools` (tag commit 79b1d9c, a local annotated tag, not yet pushed). Run under Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/`, item RV-PM. The copy-and-bundle half of `/dev-copilot:wow-revendor-libka0s` (dev-copilot 2.10.0) only: no adoption interview and no GitHub issue in this run (design section 5).

## 3a Base
- `grep -n '[Bb]undles' CLAUDE.md` named v1.94.0 before the roll (CLAUDE.md:59).
- Last payload commit, `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = e75f69c (W2-PM-01); its CLAUDE.md names v1.94.0. They agree.
- Payload before the copy equalled the library at v1.94.0: `diff -rq --strip-trailing-cr` of both payloads against a v1.94.0 extract printed nothing outside the undeclared icons (payload-matches).
- Library range: `git -C ../LibKa0s log --oneline v1.94.0..v1.105.0` is 114 commits; `git -C ../LibKa0s diff --shortstat v1.94.0 v1.105.0 -- LibKa0s testkit` is 417 files, 10204 insertions, 714 deletions.
- Step 0: the newest single-tag bundle, `2026-11-07-v1.93.0`, states base v1.92.0, which is the provenance tag before its re-vendor (9421643). No correction.

## 3b/3c Per-file minors that moved (old = this addon at v1.94.0, new = v1.105.0)
Loop over the tag's `LibKa0s/LibKa0s.xml`, each file's `local (MAJOR, )?[A-Z_]*MINOR` constant:
```
Core.lua  old: 17  new: 18
Tooltip.lua  old: none  new: 1
Role.lua  old: none  new: 1
Callout.lua  old: none  new: 4
CalloutSettings.lua  old: none  new: 5
WaypointArrow.lua  old: none  new: 2
WaypointArrowSettings.lua  old: none  new: 2
Charts.lua  old: 1  new: 2
Media.lua  old: 12  new: 13
SkinDefs.lua  old: 27  new: 28
SkinDefsOthers.lua  old: 8  new: 10
Widgets.lua  old: 26  new: 27
WidgetsDropdown.lua  old: 1  new: 2
WidgetsReorder.lua  old: 6  new: 7
WidgetsDragHandle.lua  old: 13  new: 14
WidgetsDragHandleTip.lua  old: none  new: 1
WidgetsCopyWindow.lua  old: 5  new: 6
WidgetsHeader.lua  old: none  new: 1
WidgetsBar.lua  old: none  new: 1
DebugLog.lua  old: 22  new: 23
DebugLogDiagnostics.lua  old: 7  new: 11
DebugLogWindow.lua  old: 4  new: 5
Launcher.lua  old: 9  new: 11
OptionsWidgets.lua  old: 45  new: 46
OptionsNav.lua  old: 6  new: 7
OptionsSkinPicker.lua  old: 11  new: 12
OptionsSkinPickerQueue.lua  old: none  new: 1
IconBrowserWindow.lua  old: 1  new: 2
IconBrowser.lua  old: 1  new: 2
PerfPanel.lua  old: 13  new: 14
Sim.lua  old: 2  new: 3
SimPanel.lua  old: 10  new: 11
SimPanelRender.lua  old: 3  new: 4
```
Every file not listed matched v1.94.0 before the copy, so there is no cross-major skew. Ten files are new in this range (`old: none`), among them four new majors: `LibKa0s-Role-1.0` (v1.95.0), `LibKa0s-Callout-1.0` (v1.96.0), `LibKa0s-WaypointArrow-1.0` (v1.99.0) and `LibKa0s-Tooltip-1.0` (v1.105.0). The payload now carries 25 majors (21 at v1.94.0).

## 3d Diffs
Before the prune, `diff -r --strip-trailing-cr` and `diff -r` of both payloads against the v1.105.0 extract printed nothing. After the prune, the only differences are `Only in <extract>/LibKa0s/media/icons` (undeclared icons) and `Only in <extract>/LibKa0s/media/sounds: callout` (no `LibKa0s sounds:` line, so the sound subset is none). `tests/test_vendor_sync.lua` is green.

## 3e Consumption map
```
core/BusSetup.lua:28:LibStub("LibKa0s-Bus-1.0", true)
core/Compat.lua:12:LibStub("LibKa0s-Compat-1.0", true)
core/CoreSetup.lua:34:LibStub("LibKa0s-Core-1.0", true)
core/DebugLogSetup.lua:22:LibStub("LibKa0s-DebugLog-1.0", true)
core/EnvSetup.lua:41:LibStub("LibKa0s-Env-1.0", true)
core/LauncherSetup.lua:128:LibStub("LibKa0s-Launcher-1.0", true)
core/LifecycleSetup.lua:70:LibStub("LibKa0s-Lifecycle-1.0", true)
core/MediaSetup.lua:42:LibStub("LibKa0s-Media-1.0", true)
core/SkinSetup.lua:95:LibStub("LibKa0s-Skin-1.0", true)
settings/OptionsSetup.lua:26:LibStub("LibKa0s-Options-1.0", true)
settings/Schema.lua:550:LibStub("LibKa0s-Schema-1.0", true)
settings/Slash.lua:498:LibStub("LibKa0s-Slash-1.0", true)
```
Twelve of the 25 majors. Not looked up here: Callout, Charts, Glow, IconBrowser, Item, Perf (declined, ratified), Pool, Role, Sim, Toast, Tooltip, WaypointArrow, Widgets. CLAUDE.md:46 and docs/module-map.md:45 move from "twenty-one" to "twenty-five" in this commit.

## 3f Kit revision
```
old: tests/_kit/framework.lua:20:Kit.VERSION = 53
new: testkit/framework.lua:20:Kit.VERSION = 57
```
Kit revision 57 pairs with v1.105.0. Both payloads are copied whole in one commit, which is why the two move together.

## 3g Contract delta and Blockers
Consumed majors whose minors moved: Core (18), Media (13), Skin (SkinDefs 28, SkinDefsOthers 10), DebugLog (23, DebugLogDiagnostics 11, DebugLogWindow 5), Launcher (11) and Options (OptionsWidgets 46, OptionsNav 7, OptionsSkinPicker 12, OptionsSkinPickerQueue 1). Read against the tag's CHANGELOG blocks v1.95.0 to v1.105.0 and their *What a consumer owes* lists.

`__Attach*` sites in this addon (`grep -rn '__Attach[A-Za-z]*' --exclude-dir=libs --exclude-dir=_kit`):
```
./tests/test_libka0s.lua:669:  -- stays swept: lib.__AttachFlow in OptionsFlow.lua receives the descriptor too.
```
A comment only: this addon hands the library no member through an `__Attach*` entry point.

**Blockers: none.** What the release asked of this host, all in this commit:
- **Stub members** (`Kit.assertSurfaceParity`). The DebugLog stub in `core/DebugLogSetup.lua` gains `Report` and `Serialize` (DebugLog minor 23, DebugLogDiagnostics minor 11). The Options stub in `settings/OptionsSetup.lua` gains `SideTabs` (OptionsNav minor 7, LibKa0s v1.100.0). Both are inert: nothing in this addon calls them.
- **A moved pin.** `tests/test_libka0s.lua`'s console title-bar case pinned three marks (close -6, clear -30, copy -54). DebugLogWindow minor 5 (LibKa0s#86) puts a settings mark beside the close, so the bar is four marks at the same icon pitch: close -6, settings -30, clear -54, copy -78, the library's own `tests/test_debuglog.lua` figures. The case keeps its discriminating power: the word fallback puts Copy at -102. It now also pins the settings mark.
- **Kit-57 frame hold** (LibKa0s#75): no suite here relied on a garbage collection dropping a registered frame; nothing went red.
- **`settings` in the declaration** (the vendor gate's `LIBRARY_MARKS`): already declared.
- No hand-written loader list here (the suite loads `libs/LibKa0s/LibKa0s.xml`), so no loader lines are owed.

## 3h Unrecorded vendored tags
The audit's walk plus the provenance rolls since the store's first bundle (2026-08-25): 69 vendored tags, 68 recorded.
```
v1.94.0
```
Written as the span bundle `docs/revendor/2026-11-16-v1.94.0-v1.94.0/`.

## 3i Icon declaration
- `grep -n 'LibKa0s icons:' CLAUDE.md`: 60:LibKa0s icons: chevron-down, chevron-up, clear, close, confirm, copy, eye, info, move, reset, settings, volume-high.
- Kept as written. It is the next non-blank line under the provenance line; no split needed. `settings`, which kit revision 57 owes every host, is already on it.
- Prune: `lua <extract>/tools/prune-icons.lua .` printed `12 icon(s) declared; kept 13 file(s), removed 5827` and `sounds none (no LibKa0s sounds: line); kept 0 file(s), removed 362`. All removed files are icons the addon does not declare (Open Iconic, Phosphor and Game-icons) and the Callout voice packs.
- Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`). The owner's in-client smoke is the backstop: a pruned icon still resolves to a path and draws blank.

## 3j Tests that assume the whole icon folder
```
tests/test_libka0s.lua:201:  -- The vendored media/icons/ is pruned to the CLAUDE.md `LibKa0s icons:` line (kit revision 40).
tests/test_mediasetup.lua:11:-- against a catalog that lives in ANOTHER repo, then drawn from a vendored copy whose media/icons/
tests/test_mediasetup.lua:82:  for _, name in ipairs(Media.ICONS) do known[name] = true end
tests/test_mediasetup.lua:109:    local art = io.open("libs/LibKa0s/media/icons/" .. name .. ".tga", "rb")
```
Unchanged from v1.93.0's bundle: line 82 builds a name set and line 109 opens declared names only. No blocker.

## Dead stub mirrors
`grep -rn '__releaseChrome'` outside libs and the kit: `tests/test_panels_page.lua:557`, a history comment, not a mirror. Nothing removed.
