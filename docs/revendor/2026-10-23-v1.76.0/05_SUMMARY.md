# 05 — Summary (PanelMaster)

LibKa0s v1.75.2 -> v1.76.0 from the local annotated tag (`546e284`, commit `9949368`). The base,
v1.75.2, comes from the `CLAUDE.md` provenance line and agrees with the last payload commit
`b534579`. Kit revision 41 unchanged. The provenance line rolled in the same commit as the bytes.

- **Minors moved:** Widgets 13 -> 14 (`LibKa0s-Widgets-1.0` 14.1.4.3.2), SimTimeline 2 -> 3 and
  SimPanel 4 -> 5 (`LibKa0s-Sim-1.0` 2.3.5). Seventeen majors across forty files. Nothing was
  deleted from either payload by the copy.
- **Span bundle:** `docs/revendor/2026-10-23-v1.75.1-v1.75.2/`, two tags (v1.75.1, v1.75.2) vendored
  on 2026-10-23 with no bundle. No base correction was owed (Step 0 `ok`).
- **Class A (for free):** the simulator's auto-run and the strip's simulation flavor arrive in the
  payload; PanelMaster consumes neither major, so nothing on screen changes here.
- **Contract blockers:** none. No `__Attach*` site, and neither moved major is consumed.
- **Icon declaration:** `LibKa0s icons: clear, close, copy.` kept. The prune printed
  `3 icon(s) declared; kept 4 file(s), removed 5836` (Open Iconic 221 undeclared marks, Phosphor 1435
  files, Game-icons 4180 files), all of which arrived with the copy and never reached git. No
  provenance split was needed.
- **Credits and dead stub mirrors:** README `## Credits` unchanged (Open Iconic still the only set
  shipping). `grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`
  gives only the historical comment `tests/test_panels_page.lua:556`; no mirror.
- **Refresh file:** none (a new tag, so a new bundle).
- **Adopted:** nothing. **Declined:** nothing filed (non-interactive under the run's ruling; the one
  new surface, `TestStrip`'s `kind`, has no adoption site, see `02_CANDIDATES.md`). **Unreached:**
  none.
- **Reds from the fresh payload:** none. No suite here drives `Sim` or `TestStrip`.
- **Gate after the copy, every run through `ka0s-bounded`:** `lua tests/run.lua` 1064 passed,
  0 failed, 1 skipped, 1065 total, including `tests/test_vendor_sync.lua` (both payloads match
  v1.76.0 in the declared icon shape). `luacheck .` 0 warnings / 0 errors in 71 files. The
  1500-line cap holds (kit `test_layout_cap` green). Complexity is a release check and was not run.

## The standard reference (same item, part 2)

Run per the installed `/dev-copilot:wow-revendor-standards` 2.4.0 against standard **v2.87.0,
2026-10-23**, read from the local `../WowAddonStandards` checkout on
`feat/2026-10-23-sim-preview-mode-strips` (the run's ruling; GitHub master is still v2.86.0).
`documentation.md` is unchanged between v2.86.0 and v2.87.0, and no section file was added or
removed. Nothing needed changing:

- **3a, the three places:** `PanelMaster.toc:12` `## X-Standard:
  https://github.com/tusharsaxena/WowAddonStandards`; `README.md:6` the bare
  `![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)`; `CLAUDE.md`
  `## Standards compliance (read first)` with the stop-and-flag directive and the two-way
  classification. The command writes no version into any of them (its Step 5 rule), so none moves.
- **3b:** `grep -rEn '§[0-9]+\.[0-9]' . --exclude-dir=.git --exclude-dir=libs --exclude-dir=_kit
  --exclude-dir=audits --exclude-dir=reviews --exclude-dir=automated-tests` gives 4 hits, all inside
  the frozen `docs/revendor/2026-09-23-v1.55.0/` bundle citing LibKa0s's `compat.md`, not the
  standard; left as evidence. Every `filename-§N` reference outside the frozen bundles was
  range-checked against the v2.87.0 section files: none out of range or malformed (the one
  non-match, `CLAUDE.md:20`'s `filename-§N`, is the template wording itself).
- **3c-3e:** no forbidden pointer, no `docs/agent-context.md`, no quirks section upstream to vendor.
- **3f:** v2.87.0 does not change `automated-tests-§3`'s gate statements; it adds a release-run
  `## Preview and simulation data` section, which `/dev-copilot:bump-version` writes at release.
  The `docs/automated-tests/RESULTS.md` lead-in is runner-generated and was not swept.
- **3g:** `.gitattributes` present, pin `* text=auto eol=crlf` (client-bound), `*.sh` and `*.py`
  carve-outs and binary markings present; the worktree straggler count is 0. Renormalization was
  not performed (nothing to do).
