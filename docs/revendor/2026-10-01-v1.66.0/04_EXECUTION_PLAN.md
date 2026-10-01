# Execution plan (PanelMaster)

One commit, `GI-PM-RV`, carries:

1. Both payloads copied whole from `git archive v1.66.0` (`libs/LibKa0s/`, `tests/_kit/`); no file
   deleted, because the diff named none only on this side.
2. The `CLAUDE.md` provenance line rolled v1.65.0 -> v1.66.0.
3. `{ name = "test_lizard_sighted", dir = "tests/_kit/" }` wired in `tests/run.lua`.
4. `docs/test-cases.md` regenerated (eight new cases) and the README badge moved with it.
5. The raw `lizard -l lua -x ...` command replaced by `bash tests/_kit/run-automated-tests.sh
   --suite complexity` in `DEPENDENCIES.md` and `docs/testing.md`. `CLAUDE.md` quotes no lizard
   command.
6. The one file the sighted suite found lizard blind in, `tests/test_slash.lua` (155 of 156
   functions listed): a function literal in a `for ... in` header (`:48`), hoisted into a local, as
   the kit 35 document prescribes. No case changes.
7. This bundle and the span bundle `docs/revendor/2026-10-01-v1.64.0-v1.65.0/`.
