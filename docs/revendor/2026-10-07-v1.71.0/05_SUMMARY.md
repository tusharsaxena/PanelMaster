# 05 — Summary (PanelMaster)

LibKa0s v1.70.0 -> v1.71.0 from the local annotated tag (`3bf1b97`, commit `cb274a4`); base v1.70.0
from the CLAUDE.md provenance line, agreeing with the last payload commit `f61f2b7`. Kit revision
37 -> 38. Provenance rolled in the same commit as the bytes.

- Minors moved: Env 1 -> 2, Slash 19 -> 20 / SlashParse 1 -> 2 (key 20.2), WidgetsLineChart 2 -> 3,
  WidgetsAutocomplete 1 -> 2, OptionsIdList 3 -> 4. No file added or removed in `LibKa0s/`; the kit
  gains `secrets.lua`.
- Delivered free (class A): `ParseValue` refuses nan/inf on `/pm set`; the library's dead
  bare-global addon-API rungs are gone; `--list` Totals count only cases that run.
- Contract blockers: none. Env and OptionsIdList now read only `C_AddOns`, present on every admitted
  client. Recorded, not fixed here (behavioral, owned by PM-09): `core/EnvSetup.lua`'s
  library-absent fallback still keeps its own bare `GetAddOnMetadata` rung.
- Adopted: nothing. Every candidate in `02_CANDIDATES.md` is "not adopted in this run" (owner ruling 5).
- Declined: nothing filed; no interview held.
- Unrecorded tags: v1.69.0 and v1.70.0, back-filled in `docs/revendor/2026-10-07-v1.69.0-v1.70.0/`.
- `docs/test-cases.md` regenerated under kit 38: the header now says Total counts the cases that
  run; `test_diagnostics_contract.lua` counts 8 and the declared opt-out skip sits on
  `| Skipped | 1 |`; `| **Total** | **1035** |` equals the README badge (1035/1035), resolving
  `PM-R-09`. The badge does not move.
- Reds from the fresh payload: none.
- Gate after the copy, every run through `ka0s-bounded`: `lua tests/run.lua` 1035 passed, 0 failed,
  1 skipped, 1036 total, including `tests/test_vendor_sync.lua`'s three cases (both payloads match
  the v1.71.0 tag; runner 100755). `luacheck .` 0 warnings / 0 errors in 71 files. `lizard -l lua
  -w -C 15 -x "./libs/*" -x "./tests/_kit/*" .` prints no warning.
