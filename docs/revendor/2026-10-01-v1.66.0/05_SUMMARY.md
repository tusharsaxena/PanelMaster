# Summary (PanelMaster)

LibKa0s v1.65.0 -> v1.66.0 from the local tag: Widgets 11 -> 12 (+ WidgetsReorder 1), DebugLog
18 -> 19, Slash 18 -> 19 (+ SlashParse 1), OptionsWidgets 33 -> 34, OptionsTabs 7 -> 8, Perf
13 -> 14 (+ PerfSampler 1, PerfCommands 1); kit revision 34 -> 35. Run on 2026-10-01 as plan item
`GI-PM-RV`, branch `feat/2026-10-01-github-issue-pass` from `master` @ `8b84c47`. One commit
carries both payloads, the provenance line, the kit suite's wiring and this record. Nothing was
pushed, and the addon version did not move.

- Span bundle: `docs/revendor/2026-10-01-v1.64.0-v1.65.0/` records the two tags vendored without a
  bundle (v1.64.0, v1.65.0). No base correction owed.
- Delivered: kit 35's sighted complexity suite and gate; the library's internal peels and refactors.
- Blockers: none (`01_DELTA.md`, *Contract delta*).
- Adopted / declined: none. Three candidates left unreached for `GI-LK-13` (`03_DECISIONS.md`).

Gate after the copy, all through `~/.claude/wow-addon/bin/ka0s-bounded`:

- tests: 1011 passed, 0 failed, 1 skipped, 1012 total (1003 / 0 / 1 / 1004 before; +8 are the kit's
  `test_lizard_sighted` cases)
- luacheck: 0 warnings / 0 errors in 69 files
- complexity, sighted (`run-automated-tests.sh --suite complexity --no-bundle`): before the hoist,
  `fail`, lizard blind in 1 file (`tests/test_slash.lua`, 155 of 156); after it, `pass`, 0
  warnings, max CCN 15, blindFiles 0, 2086 functions
- vendor parity: `diff -r` of both payloads against `git archive v1.66.0` is empty
