# 05 — Summary (PanelMaster)

LibKa0s v1.76.0 -> v1.77.0 from the local annotated tag (`7380d36`, commit `78240f7`). The base,
v1.76.0, comes from the `CLAUDE.md` provenance line and agrees with the last payload commit
`9c950c3`. Kit revision 41 -> 42. The provenance line rolled in the same commit as the bytes.

- **Minors moved:** Core 11 -> 12, DebugLog 20 -> 21, PerfPanel 8 -> 9, SimPanel 5 -> 6, Widgets
  14 -> 15, WidgetsDragHandle 4 -> 5, WidgetsAutocomplete 2 -> 3, Options 29 -> 30, OptionsIds 2 -> 3,
  OptionsCombat 1 -> 2, OptionsCompose 7 -> 8, and the new OptionsKeybinds at 3. Seventeen majors
  across forty-one files. Nothing was deleted from either payload by the copy.
- **Span bundle:** none (56 tags vendored, 56 recorded). No base correction was owed (Step 0 `ok`).
- **Class A (for free):** the debug console is toplevel and re-raises a shown confirmation; the shared
  dropdown menu is clamped to screen.
- **Contract blocker:** the Options degradation stub owed `KeybindingsTab`, `KeybindRows`,
  `KEYBINDS_UNCHANGED` and `StrataTooltip` (`tests/test_surface_parity.lua:207` red after the copy).
  Fixed in `settings/OptionsSetup.lua`'s stub in the re-vendor commit, inert answers only.
- **Icon declaration:** `LibKa0s icons: clear, close, copy.` kept. The prune printed
  `3 icon(s) declared; kept 4 file(s), removed 5836`, all of which arrived with the copy and never
  reached git. No provenance split was needed.
- **Credits and dead stub mirrors:** README `## Credits` unchanged (Open Iconic still the only set
  shipping). `grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`
  gives only the historical comment `tests/test_panels_page.lua:556`; no mirror.
- **Refresh file:** none (a new tag, so a new bundle).
- **Adopted here:** nothing. `O.StrataTooltip` is PM-ZS's. **Declined:** nothing filed; every other
  candidate is deferred (run 2026-10-24), see `03_DECISIONS.md`. **Unreached:** none.
- **Gate after the copy, every run through `ka0s-bounded`:** `lua tests/run.lua` 1064 passed,
  0 failed, 1 skipped, 1065 total, including `tests/test_vendor_sync.lua` (both payloads match
  v1.77.0 in the declared icon shape) and the Options parity case. `luacheck .` 0 warnings / 0 errors
  in 71 files. No authored `.lua` above 1500 lines (largest `tests/test_libka0s.lua`, 1203).
  Complexity is a release check and was not run.

## The standard reference (same item, part 2)

Run per the installed `/dev-copilot:wow-revendor-standards` 2.4.0 against standard **v2.88.0,
2026-10-24**, read from the local `../WowAddonStandards` checkout on
`feat/2026-10-24-keybinds-layout-strata` (WS-90 `897fbd3`; GitHub master is still v2.87.0).
Between master and v2.88.0 one section file is added, `frame-layering.md`, and `launcher.md`,
`options-ui.md`, `library-stack.md`, `anti-patterns.md` and five others change; `documentation.md`,
`toc-file.md` and `automated-tests.md` do not. Nothing needed changing:

- **3a, the three places:** `PanelMaster.toc:12` `## X-Standard:
  https://github.com/tusharsaxena/WowAddonStandards`; `README.md:6` the bare
  `![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)`; `CLAUDE.md`
  `## Standards compliance (read first)` with the stop-and-flag directive and the two-way
  classification. The command writes no version into any of them (its Step 5 rule), so none moves.
- **3b:** `grep -rEn '§[0-9]+\.[0-9]' . --exclude-dir=.git --exclude-dir=libs --exclude-dir=_kit
  --exclude-dir=audits --exclude-dir=reviews --exclude-dir=automated-tests` gives 4 hits, all inside
  the frozen `docs/revendor/2026-09-23-v1.55.0/` bundle citing LibKa0s's `compat.md`, not the
  standard; left as evidence. Every `filename-§N` reference outside `docs/revendor/` and the frozen
  bundles (74 distinct) was range-checked against the v2.88.0 section files' `### N.` heading
  counts: none unknown, out of range or malformed (the one non-match, `CLAUDE.md:20`'s `filename-§N`, is the template wording).
- **3c-3e:** no forbidden pointer, no `docs/agent-context.md`, every root and `docs/` canonical member
  present, no quirks section upstream to vendor.
- **3f:** `automated-tests.md` is unchanged at v2.88.0, so no gate statement moved. The
  `docs/automated-tests/RESULTS.md` lead-in is runner-generated and was not swept.
- **3g:** `.gitattributes` present, pin `* text=auto eol=crlf` (client-bound), `*.sh` and `*.py`
  carve-outs and binary markings present; the worktree straggler count is 0. Renormalization was not
  performed (nothing to do).
- **What v2.88.0 asks of PanelMaster beyond the reference** (frame-layering's one layers table and
  the shared strata tooltip) is PM-ZS's, not this sweep's.

## Re-vendor after the tag moved (M3)

LK-95 moved the local annotated tag v1.77.0 in `../LibKa0s` to carry the settings-layout surfaces
(item 020). Old: tag object `7380d3662be0568acf9a0d224a6aef8ac6df93ce`, commit
`78240f7b2d69df27b74fc9280cbfbf7b95dd4f1f`. New: tag object
`b2b8ee25c5f9fa26db146254bf786b366dec986b`, commit `afae2f75cb7ff61c57156d9a3d8a6b2b9f4c5e10`
(`git -C ../LibKa0s rev-parse v1.77.0^{}`). Both payloads were copied whole again from
`git -C ../LibKa0s archive v1.77.0 LibKa0s testkit`, per the installed
`/dev-copilot:wow-revendor-libka0s`; no new bundle, per PM-RV2.

- **Minors moved:** OptionsCompose 8 -> 11 (minor 9 `MasterControls` notes, `resetPositionTooltip`,
  `lockIsPreview`, the *Master opacity* label and the frameless packing; minor 10 `tooltips` on the
  group composers; minor 11 `O.ResetAllTooltip`). No other file in `libs/LibKa0s/` changed, and
  `tests/_kit/` is byte-identical (kit revision 42 both sides). The `CLAUDE.md` provenance line stays
  `v1.77.0` and records no sha or kit revision, so it does not move.
- **Icon declaration:** `LibKa0s icons: clear, close, copy.` kept; the tag's `tools/prune-icons.lua`
  printed `3 icon(s) declared; kept 4 file(s), removed 5836`.
- **Contract blocker:** `Kit.assertSurfaceParity` turned the Options parity case red
  (`ResetAllTooltip is missing (live: function)`). `settings/OptionsSetup.lua`'s library-absent stub
  now answers it inertly with an empty string, as `StrataTooltip` does.
- **Contract change under an unmoved surface:** minor 9 relabels the composed alpha row *Master
  alpha* -> *Master opacity* for every host (stored leaf `settings.alpha`, tooltip, range and default
  unchanged, nothing migrates). `tests/test_schema.lua` pinned the old label and went red; its two
  pins and `docs/settings-panel.md` now read *Master opacity*. The frameless packing does not reach
  PanelMaster, which draws *Lock frame*. The owner-marked smoke records in `docs/smoke-tests.md`
  (FRAME-13, PANEL-3) still name *Master alpha*; they are left as recorded, for PM-LY's smoke pass.
- **Adopted here:** nothing (PM-LY adopts notes, tooltips and `O.ResetAllTooltip`).
- **Standard reference:** WS-95 only adds `options-ui-§21` and edits text; no section file or range
  shrinks, so the installed `/dev-copilot:wow-revendor-standards` checks find no drift.
- **Gate after the copy, through `ka0s-bounded`:** `lua tests/run.lua` 1081 passed, 0 failed,
  1 skipped, 1082 total, including `tests/test_vendor_sync.lua` and the Options parity case.
  `luacheck .` 0 warnings / 0 errors in 72 files. No authored `.lua` above 1500 lines (largest
  `tests/test_libka0s.lua`, 1203).

## Re-vendor after the tag moved again (one key button)

LK-96 moved the local annotated tag v1.77.0 in `../LibKa0s` again, to carry the owner's 015
follow-up: one key button and Clear per row on the in-addon Keybindings tab (LK-40). Old: tag object
`b2b8ee25c5f9fa26db146254bf786b366dec986b`, commit `afae2f75cb7ff61c57156d9a3d8a6b2b9f4c5e10`. New:
tag object `e9b126d961c2970e5b14d0566480f7c1d8b5e5e8`, commit
`2f2b2e22b4c9219cd8a4101d7e894681c7aea16e` (`git -C ../LibKa0s rev-parse v1.77.0^{}`). Both payloads
were copied whole again from `git -C ../LibKa0s archive v1.77.0 LibKa0s testkit`, per the installed
`/dev-copilot:wow-revendor-libka0s`; no new bundle, as in PM-RV2.

- **Minors moved:** OptionsKeybinds 3 -> 4 (one key button and Clear per row; the second key is set
  on the client's Options -> Keybindings page and counted on the row). No other file in
  `libs/LibKa0s/` changed. In `tests/_kit/`, `bindings_xml.lua` (`Kit.keybindThroughTab` slot 2 on a
  one-button row) and `README.md` changed; the kit revision stays 42. The `CLAUDE.md` provenance line
  stays `v1.77.0` and records no sha or kit revision, so it does not move.
- **Icon declaration:** `LibKa0s icons: clear, close, copy.` kept; the tag's `tools/prune-icons.lua`
  printed `3 icon(s) declared; kept 4 file(s), removed 5836`.
- **Contract delta:** none reaches PanelMaster. It declares no bindings and draws no Keybindings tab,
  so the one-button row has no host site here. The Options parity case stays green: minor 4 adds no
  public Options member, so the degradation stub in `settings/OptionsSetup.lua` is unchanged.
- **Adopted here:** nothing.
- **Gate after the copy, through `ka0s-bounded`:** `lua tests/run.lua` 1091 passed, 0 failed,
  1 skipped, 1092 total, including `tests/test_vendor_sync.lua` (the README badge and
  `docs/test-cases.md` already read 1091, so neither moves). `luacheck .` 0 warnings / 0 errors in
  74 files. No authored `.lua` above 1500 lines (largest `tests/test_libka0s.lua`, 1204).
  `diff -r --strip-trailing-cr ../LibKa0s/LibKa0s libs/LibKa0s` is empty apart from the pruned
  `media/icons/`.
