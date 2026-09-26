# Summary (PanelMaster)

LibKa0s v1.61.0 -> v1.62.0 from the tag: Options 25 -> 26, OptionsWidgets 31 -> 32, OptionsTabs
5 -> 6, and new OptionsRegistry, OptionsIds, OptionsIdList and OptionsCombat at minor 1 (Options key
`26.1.32.1.1.6.1.7.4.1`). `tests/_kit` kit revision 27 -> 31, with the new `inventory.lua`,
`prose_coverage.lua` and `prose_selftests.lua`. CLAUDE.md provenance rolled. No blockers, no
candidates, no host code change, no stub change.

Gate after the copy:

- tests: 964 passed, 0 failed, 0 skipped, 964 total (964 before)
- `docs/test-cases.md` regenerated with `lua tests/run.lua --list`: byte-identical, 964 cases
- luacheck: 0 warnings / 0 errors in 64 files
- lizard (excluding `libs/` and `tests/_kit/`): no function above CCN 15
- vendor gate: both payloads content- and byte-identical to the tag and to `../LibKa0s`
