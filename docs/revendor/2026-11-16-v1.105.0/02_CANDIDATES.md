# 02 Candidates, LibKa0s v1.94.0 -> v1.105.0

Sources: `git -C ../LibKa0s log --oneline v1.94.0..v1.105.0`; the tag's CHANGELOG.md blocks v1.95.0 to v1.105.0 (each block's *What a consumer owes*); Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/03_ADOPTION_PLAN.md` and its research note R8 section 3 (this addon's site counts). Site counts re-checked here with `grep -rn <pattern> --include='*.lua' --exclude-dir=libs --exclude-dir=tests --exclude-dir=tools .`, comment lines dropped.

**Class A, delivered on the copy alone**
- Header marks on every library window (LibKa0s#86; DebugLogWindow 5, WidgetsCopyWindow 6, OptionsSkinPicker 12, Launcher 11, Core 18): the debug console, its copy window and the skin picker carry extras · settings · close. The settings mark opens this addon's settings through `d.openSettings`, which the launcher registers in Core's registry from the re-vendor alone. `settings` was already declared.
- The console (LibKa0s#79, #90): its status line is a 24 px Widgets footer with the counter in `text.muted`, and Copy hands out plain text.
- Library tooltips placed by `LibKa0s-Tooltip-1.0` (LibKa0s#92 part B): dropdown entries and the skin picker's toolbar tips. This addon's own settings tooltips go through the Options library's `AttachTooltip`.
- Skin colors (LibKa0s#82, #84; SkinDefs 28, SkinDefsOthers 10): Ka0s Default's list rows and seven skins' `icon.hot`. This addon defines no host token that follows `icon.hot` or copies the list values (`grep -rn 'hot\|list\.stripe\|list\.hover\|list\.sel'` finds none).
- Kit revision 57's frame hold (LibKa0s#75) and the opt-in `mock_screen.lua`.
- Two new faces in `media/fonts/` (Bebas Neue, Russo One, v1.97.0), offered by the library's font pickers.

**Class B, host change required (candidates), owed in phase [3]**
- **LibKa0s#79, `D:Report` / `D:Serialize`.** Candidate: the `/pm panels` listing (`settings/Slash.lua:415`, built by the pure line builder at `settings/Slash.lua:188`). To be checked against the owner's report-routing ruling of 2026-11-08 before it moves, since a list verb can stay in chat. `DevTools_Dump`: no call.
- **LibKa0s#92, tooltip placers:** not applicable. 0 `SetOwner(` and 0 `ANCHOR_` sites in this addon's source.
- **LibKa0s#86, `W.HeaderButtons` on the host's own windows:** not applicable. This addon draws no window of its own with title marks (the panels are the player's content; the settings panel is the library's).
- **LibKa0s#88 (docked strip), #89 (`W.Footer`):** not applicable. 0 `TestStrip` calls and no footer of its own.
- **LibKa0s#87, `Sim.Sample(client)`:** not applicable. No sample characters or sim data here (`grep 'Sample[a-z]\|Mock[a-z]'` finds none).
- **LibKa0s#85 (Callout), #80 (`W.Bar`), #81 (Launcher `extraEntries`):** not applicable; their consumers are named in the adoption plan and this addon is not one.

**Class C, whole-module**: Callout, Role, Tooltip and WaypointArrow are new majors vendored and not consumed. Charts, Glow, IconBrowser, Item, Pool, Sim, Toast and Widgets stay unconsumed. Perf stays declined (ratified 2026-08-25, PanelMaster#24, #31, #44).

**Blockers (3g)**: none; the stub members and the moved title-bar pin are fixed in this commit (01_DELTA.md).
