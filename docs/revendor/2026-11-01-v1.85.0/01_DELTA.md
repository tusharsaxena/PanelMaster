Delta: LibKa0s v1.84.0 -> v1.85.0

Part of Ka0sAddonsCommonTasks `docs/2026-11-01-FULL_SKINNING/` (FS-PM-RV). The tag is local, cut by that run's `FS-REL`; `git -C ../LibKa0s rev-parse v1.85.0^{commit}` was 09a835c736fe9d85a1e52b518ed7204292dbf3f4 at the copy.

## Base (3a)

`CLAUDE.md`'s provenance line named v1.84.0, and `diff -rq` of both payloads against `git archive v1.84.0` was clean apart from the pruned icons. Newest single-tag bundle `2026-10-31-v1.84.0` states the same history; no correction owed.

## Per-file minors (3c), moved files only

| File | old | new |
|---|---|---|
| DebugLogWindow.lua | 2 | 3 |
| OptionsAppearance.lua | 5 | 6 |
| OptionsCompose.lua | 16 | 17 |
| OptionsDrawer.lua | 4 | 5 |
| OptionsIdList.lua | 7 | 8 |
| OptionsIds.lua | 6 | 7 |
| OptionsKeybinds.lua | 6 | 7 |
| OptionsMedia.lua | 3 | 4 |
| OptionsNav.lua | 4 | 5 |
| OptionsScroll.lua | 10 | 13 |
| OptionsSkinPicker.lua | 5 | 7 |
| OptionsTabs.lua | 13 | 15 |
| OptionsWidgets.lua | 41 | 44 |
| PerfPanel.lua | 11 | 12 |
| SimPanel.lua | 9 | 10 |
| SimPanelRender.lua | 1 | 2 |
| SkinAce.lua | 6 | 9 |
| SkinDefs.lua | 19 | 24 |
| SkinDefsOthers.lua | 1 | 6 |
| SkinEUI.lua | 2 | 3 |
| SkinPaint.lua | 13 | 16 |
| SkinPaintControls.lua | 11 | 14 |
| SkinPaintExtras.lua | 7 | 15 |
| WidgetsAutocomplete.lua | 5 | 6 |
| WidgetsCopyWindow.lua | 2 | 4 |
| WidgetsDragHandle.lua | 10 | 12 |
| WidgetsLineChart.lua | 5 | 6 |
| WidgetsReorder.lua | 3 | 5 |

Files carrying no `local *MINOR =` constant at the top (Skin.lua, Glow.lua, Toast.lua, Launcher.lua, Widgets.lua among them) are read from the library's CHANGELOG v1.85.0 block. No file is behind the old tag.

## Kit (3f)

`Kit.VERSION`: revision 47 -> 49. The two payloads move together.

## Consumption (3e)

Unchanged, per `CLAUDE.md`: Core, Env, Media, DebugLog, Slash, Options, Launcher, Lifecycle, Schema, Skin, and Bus for its Catalog.

## Blockers (3g, 3j)

- **Facade.** The degraded Skin facade (`core/SkinSetup.lua`) gains `Mark`, `MarkText`, `HudTextColor`, `HudLabelColor`, `BarFillColor`, `HudShadow`, `BarGloss` and `HudFont`; the Options stub (`settings/OptionsSetup.lua`) gains `LabelFont`.
- **Icons.** Decided by the plan and `docs/releasing.md` Step 8 for v1.85.0: `chevron-down, chevron-up, close, confirm, info, move, reset, volume-high`, added to `clear, close, copy, settings`.
- **3j.** `tests/test_libka0s.lua` asserted `info` undeclared and `tests/test_mediasetup.lua` pinned four names. Both moved in the re-vendor commit.

## Unrecorded tags (3h)

None. v1.84.0 has its bundle.
