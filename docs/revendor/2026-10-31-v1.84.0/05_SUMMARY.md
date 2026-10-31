# 05 — Summary (PanelMaster)

LibKa0s v1.83.0 -> v1.84.0 from the local annotated tag (`0c32e37`, commit `e917ccd`). The base,
v1.83.0, comes from the `CLAUDE.md` provenance line and agrees with the last payload commit
`e63877d`. Kit revision 46 -> 47. The provenance line rolled in the same commit as the bytes.

- **Minors moved:** the table in `01_DELTA.md`: nine files new, thirteen bumped. Twenty majors across
  sixty-four files. Nothing was deleted from either payload by the copy.
- **Span bundle:** none (61 tags vendored, 61 recorded). No base correction was owed (Step 0 `ok`).
- **Class A (for free):** see `02_CANDIDATES.md`.
- **Contract blocker:** the Options degradation stub owed `PositionBlock`
  (`tests/test_surface_parity.lua` red after the copy). Fixed in `settings/OptionsSetup.lua`'s stub in
  the re-vendor commit, inert answers only.
- **Icon declaration:** `LibKa0s icons: clear, close, copy, settings.` kept. The prune printed
  `4 icon(s) declared; kept 5 file(s), removed 5835`, all of which arrived with the copy and never
  reached git. No provenance split was needed.
- **Credits and dead stub mirrors:** README `## Credits` unchanged. `__releaseChrome` is only the
  historical comment in `tests/test_panels_page.lua`; no mirror.
- **Refresh file:** none.
- **Adopted here:** nothing. **Declined:** five candidates, none filed (`03_DECISIONS.md`).
  **Unreached:** none.
- **LibKa0s#67:** none. **LibKa0s#68:** fits by computation (`03_DECISIONS.md`).
- **Gate after the copy, through `ka0s-bounded`:** `lua tests/run.lua` 1161 passed, 0 failed, 1 skipped, 1162 total, including
  `tests/test_vendor_sync.lua`. `luacheck .` 0 warnings / 0 errors in 84 files. Largest authored `.lua`
  is `tests/test_slash.lua`, 1167 lines.
  Complexity is a release check and was not run.
