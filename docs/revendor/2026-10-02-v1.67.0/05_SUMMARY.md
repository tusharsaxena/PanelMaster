# Summary (PanelMaster)

LibKa0s v1.66.0 -> v1.67.0 from the local tag: Core 9 -> 10, Options 27 -> 28, OptionsIdList
2 -> 3; kit revision 35 unchanged (35 -> 35, no kit file differs). Run on 2026-10-02 as plan item
`CA-PM-RV`, branch `feat/2026-10-02-libka0s-census-adoption` from `master` @ `eeb9143`. One commit
carries the three library files, the `CLAUDE.md` provenance line and this record. Nothing was
pushed, and the addon version did not move.

- Span bundle: none owed; the base `v1.66.0` has its own bundle.
- Delivered: the OptionsIdList loaded-addon guard (latent: no id list here) and Options 28's
  docblock correction.
- Blockers: none (`01_DELTA.md`, *Contract delta*).
- Candidates: `addonName` goes to `CA-PM-NM`; the `MakeResizable` opts to none
  (`02_CANDIDATES.md`). No issue is filed.
- Live vendor stamps: only `CLAUDE.md`'s provenance line names the vendored tag. The other
  `LibKa0s v1.6x.0` mentions in `docs/debug.md` and `docs/module-map.md` date when a behaviour
  arrived and stay as written, as at v1.66.0.

Gate after the copy, all through `~/.claude/wow-addon/bin/ka0s-bounded`:

- tests: 1032 passed, 0 failed, 1 skipped, 1033 total (the same before the copy); no case added,
  so `docs/test-cases.md` regenerates byte-identical and the README badge stays 1032/1032
- luacheck: 0 warnings / 0 errors in 71 files
- complexity, sighted (`run-automated-tests.sh --suite complexity --no-bundle`): pass, 0 warnings,
  max CCN 15, 2161 functions
- vendor parity: `diff -r --strip-trailing-cr` of both payloads against the tag is empty
