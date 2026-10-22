# 05 — Summary (PanelMaster)

LibKa0s v1.71.0 -> v1.75.0 from the local annotated tag (`eae0ee5`, commit `265a89e`). The base,
v1.71.0, comes from the `CLAUDE.md` provenance line and agrees with the last payload commit
`9fa5c52`. The range covers v1.72.0, v1.73.0 and v1.74.0, which PanelMaster never vendored, so no
span bundle is owed. Kit revision 38 -> 41. Provenance and declaration rolled in the same commit as
the bytes.

- **Minors moved:** Core 10 -> 11, Item 2 -> 3, Media 4 -> 5 (+ MediaIcons 1), Widgets 12 -> 13,
  DebugLog 19 -> 20 / DebugLogDiagnostics 2 -> 3, Options 28 -> 29 / OptionsIdList 4 -> 5 /
  OptionsTabs 8 -> 9 (+ OptionsDrawer 1), Perf 14 -> 15 / PerfPanel 6 -> 7. New majors
  `LibKa0s-Glow-1.0` 1 and `LibKa0s-Sim-1.0` 1.1.1 (Sim, SimTimeline, SimPanel). Seventeen majors
  across forty files. The kit gains `latch.lua`. Nothing was deleted from either payload by the copy.
- **Icon declaration:** `LibKa0s icons: clear, close, copy.`, written directly under the provenance
  line. It is derived from the library-drawn set this addon wires: the DebugLog console's close,
  copy and clear marks (`core/DebugLogSetup.lua:127` passes `addonName`). `info` is left out because
  no page builds an `IdList`. `NS.Icon` has no caller. Details in `01_DELTA.md` 3i.
- **Provenance split:** `CLAUDE.md:50` ran on into prose (`... v1.71.0 (MIT). That line is the`). The
  provenance sentence now ends its line, the declaration follows, and the prose resumes below with
  one sentence on the declaration. `grep -c '^LibKa0s icons:' CLAUDE.md` = 1.
- **Prune:** `lua <scratch>/tools/prune-icons.lua .` printed `3 icon(s) declared; kept 4 file(s),
  removed 5836`. By set: Open Iconic 221 marks (224 less the three declared), Phosphor 1435 files
  (1434 marks and its license) and Game-icons 4180 files (4178 marks, `LICENSE-game-icons.txt` and
  `AUTHORS.txt`). `libs/LibKa0s/media/icons/` now holds `clear.tga`, `close.tga`, `copy.tga` and
  `LICENSE-open-iconic.txt`. Of the removals, 110 were tracked files (v1.71.0's 113 marks less the
  three kept); the rest arrived with the copy and never reached git.
- **Blockers fixed (a-h, `01_DELTA.md`):** (a) the Options stub gains `Drawer = noop`; (b) no
  `O.__releaseChrome` mirror to delete, because the stub carries no `__` internals and
  `grep -rn __releaseChrome core modules settings tests/*.lua` gives one comment hit,
  `tests/test_panels_page.lua:556`; (c) Disabled 6's bus half now reads the message registry, and a
  new (b2) asserts `__fireUnconditional` reaches each game-event handler (count 1) before the
  no-effect checks; (d) the whole-catalog icon case is replaced by a declaration-equals-drawn case
  through the kit's parser; (e) the `info.tga` case becomes "info is declared exactly when a page
  builds an IdList"; (f) `docs/testing.md`'s complexity row names the kit-41 crashed bucket; (g) no
  consumer of `Kit.__deviationRows` / `__declineFor`; (h) Glow and Sim register under the harness.
- **Credit added:** README `## Credits` gains the Open Iconic line for the console's copy, clear and
  close marks (Waybury, MIT, license beside the art). No Phosphor or Game-icons line, because
  neither set ships. No credit names LibKa0s as a library.
- **Docs:** `CLAUDE.md` and `docs/module-map.md` count ten of seventeen majors adopted and list
  `Glow` and `Sim` as vendored but not consumed. `docs/testing.md` re-vendor remedy adds the prune
  and counts sixteen of seventeen majors resolving Core. The provenance paragraph names the icon line
  as the gate's second input. The step-6 paragraph is updated. A `PanelMaster.toc` comment and
  `docs/smoke-tests.md` DIAG-2's fail cause are revised. New smoke checks INSTALL-9 and PANEL-34 are
  listed with DIAG-2 under *Pending sign-off*. `docs/test-cases.md` is regenerated.
- **Adopted:** nothing. **Declined:** nothing filed (M2 is non-interactive; no candidate has an
  adoption site, see `02_CANDIDATES.md`). **Unreached:** none.
- **Reds from the fresh payload:** three, all expected and all fixed in this commit:
  "MediaSetup: every name the library ships has a file in the vendored copy", "Options seam: the
  info art the descriptor's addonName points at is on disk" (both after the prune) and "Parity: the
  Options seam's degraded surface matches the live one" (`Drawer`). Disabled 6's vacuous zeros were
  not red; they were rewritten for the reason kit 39 names.
- **Gate after the commit's changes, every run through `ka0s-bounded`:** `lua tests/run.lua` 1064
  passed, 0 failed, 1 skipped, 1065 total, including `tests/test_vendor_sync.lua` (both payloads
  match v1.75.0 in the declared icon shape) and the Options parity case. `luacheck .` 0 warnings /
  0 errors in 71 files. The 1500-line cap holds (kit `test_layout_cap` green). `docs/test-cases.md`
  **Total** stays 1064, equal to the README badge, which does not move. Complexity is a release
  check and was not run.
