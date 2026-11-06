# Summary, LibKa0s v1.89.0 -> v1.90.0 (SF1-RV-PM)

- **Tag:** v1.89.0 -> v1.90.0 (commit `4485b8f`, a **local** tag: `ls-remote` prints nothing, as this
  run expects). Base from the `CLAUDE.md:58` provenance line, confirmed by the last payload commit
  `604a336` and a clean payload match against v1.89.0.
- **Minors moved:** Core 15 -> 16, Skin 16 -> 17, SkinPaint 18 -> 19, SkinPaintExtras 17 -> 18,
  Widgets 23 -> 24, WidgetsAutocomplete 7 -> 8, OptionsAppearance 6 -> 7. Kit 51, unchanged. No file
  behind, no skew.
- **Span bundle:** none (3h printed nothing). **Base correction:** none (pre-flight `ok`).
- **Delivered for free (A):** the one-physical-pixel edge mechanism (Core 16, Skin paint), the Widgets
  controls' pixel edges (drawn by no window of this addon), and the copy's `keepScope` rule (this addon
  takes a copy's Scope as before).
- **Contract blockers:** none. Every moved document says a host owes nothing, apart from `keepScope`
  for a documented Scope deviation, which this addon is not.
- **Icons:** `LibKa0s icons:` line kept (twelve Open Iconic names). `tools/prune-icons.lua` printed
  `12 icon(s) declared; kept 13 file(s), removed 5827` against the whole copy; the shipped set is
  unchanged, so `media/icons/` has no diff and the README credits are untouched. No provenance split
  owed; no README provenance line to remove.
- **Dead stub mirrors:** none (no `__` member removed).
- **CLAUDE.md:** provenance line rolled to v1.90.0; the majors sentence (`CLAUDE.md:45`) names the
  v1.90.0 payload (still twenty-one majors).
- **Adopted:** nothing. **Declined / filed:** nothing. **Not applicable, recorded:** `keepScope`.
  See `03_DECISIONS.md`.
- **Gate (after the prune and the CLAUDE.md edits):** `ka0s-bounded luacheck .` 0 warnings / 0 errors
  in 86 files; `ka0s-bounded lua tests/run.lua` 1194 passed, 0 failed, 1 skipped, 1195 total
  (`tests/test_vendor_sync.lua` included). Largest authored file 1167 lines, under the 1500 cap.
- **Smoke:** the owner's.
