# Summary, LibKa0s v1.85.0 -> v1.89.0 (V89-PM)

- **Tag:** v1.85.0 -> v1.89.0 (commit `df00e5f`, tag object `0bd4839`, pushed). Base from the
  `CLAUDE.md:58` provenance line, confirmed by the last payload commit `763455c` and a clean payload
  match against v1.85.0.
- **Minors moved:** Toast 3 -> 4, Widgets 22 -> 23, DebugLogDiagnostics 6 -> 7; new major
  `LibKa0s-IconBrowser-1.0` (IconBrowserSources 1, IconBrowserWindow 1, IconBrowser 1). Kit 50 -> 51.
  No file behind, no skew.
- **Span bundle:** none (3h printed nothing). **Base correction:** none (pre-flight `ok`).
- **Delivered for free (A):** the diagnostics report names IconBrowser when it runs; the kit's
  unregister guard; Widgets 23 draws flat menus as 22 did.
- **Contract blockers:** none. DebugLog's document change has no member change and no suite pins
  minor 6; the Launcher/Options R7-L1 `isSimMode` statement does not apply (no sim).
- **Icons:** `LibKa0s icons:` line kept (twelve Open Iconic names). `tools/prune-icons.lua` printed
  `12 icon(s) declared; kept 13 file(s), removed 5827` against the whole copy; the shipped set is
  unchanged from v1.85.0, so `media/icons/` has no diff and the README credits are untouched. No
  provenance split owed; no README provenance line to remove.
- **Dead stub mirrors:** none (no `__` member removed; `tests/test_panels_page.lua:557` is history).
- **CLAUDE.md:** provenance line rolled to v1.89.0; the majors count (`CLAUDE.md:45-48`) now reads
  twenty-one majors in the v1.89.0 payload, with IconBrowser among the vendored-not-consumed.
- **Adopted:** nothing (the plan names no PanelMaster adoption). **Declined / filed:** nothing.
  **Not applicable, recorded:** Widgets 23 cascading-menu fields (no `W.ContextMenu` site), Toast 4
  stack (no Toast lookup). **Settled:** IconBrowser (no icon chooser). See `03_DECISIONS.md`.
- **Gate (after the prune and the CLAUDE.md edits):** `ka0s-bounded luacheck .` 0 warnings / 0 errors
  in 86 files; `ka0s-bounded lua tests/run.lua` 1194 passed, 0 failed, 1 skipped, 1195 total
  (`tests/test_vendor_sync.lua` included). Largest authored file 1167 lines, under the 1500 cap.
- **Smoke:** the owner's; a clean load on v1.89.0 is the backstop for the icon list.
