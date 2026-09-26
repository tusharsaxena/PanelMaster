# LibKa0s v1.61.0 -> v1.62.0: the delta (PanelMaster)

Copied from the tag `v1.62.0` (`e660362`, `git archive v1.62.0 LibKa0s testkit`), never from a
working tree. Sweep item `PM-ATS-RV` (ATS-20, ATS-21).

## libs/LibKa0s (`diff -rq --strip-trailing-cr`, before the copy)

```
Files <tag>/LibKa0s/LibKa0s.xml and libs/LibKa0s/LibKa0s.xml differ
Files <tag>/LibKa0s/Options.lua and libs/LibKa0s/Options.lua differ
Only in <tag>/LibKa0s: OptionsCombat.lua
Only in <tag>/LibKa0s: OptionsIdList.lua
Only in <tag>/LibKa0s: OptionsIds.lua
Only in <tag>/LibKa0s: OptionsRegistry.lua
Files <tag>/LibKa0s/OptionsTabs.lua and libs/LibKa0s/OptionsTabs.lua differ
Files <tag>/LibKa0s/OptionsWidgets.lua and libs/LibKa0s/OptionsWidgets.lua differ
```

No `Only in libs/LibKa0s` line: nothing was removed upstream, so nothing is deleted here.

| File | Constant | v1.61.0 | v1.62.0 |
|---|---|---|---|
| `Options.lua` | `MINOR` | 25 | 26 |
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 31 | 32 |
| `OptionsTabs.lua` | `TABS_MINOR` | 5 | 6 |
| `OptionsRegistry.lua` (new) | `REGISTRY_MINOR` | - | 1 |
| `OptionsIds.lua` (new) | `IDS_MINOR` | - | 1 |
| `OptionsIdList.lua` (new) | `IDLIST_MINOR` | - | 1 |
| `OptionsCombat.lua` (new) | `COMBAT_MINOR` | - | 1 |

The four new files are peels, moved unchanged out of `Options.lua` (the page registry and its combat
park), `OptionsWidgets.lua` (the id surface, in two files) and `OptionsTabs.lua` (the combat lock's
page chrome). `LibKa0s.xml` loads each right after the file it left. The Options major key moves from
`25.31.5.7.4.1` to `26.1.32.1.1.6.1.7.4.1`. Every other file is unchanged.

## tests/_kit (`diff -rq --strip-trailing-cr`, before the copy)

```
Files <tag>/testkit/README.md and tests/_kit/README.md differ
Files <tag>/testkit/framework.lua and tests/_kit/framework.lua differ
Only in <tag>/testkit: inventory.lua
Only in <tag>/testkit: prose_coverage.lua
Only in <tag>/testkit: prose_selftests.lua
Files <tag>/testkit/run-automated-tests.sh and tests/_kit/run-automated-tests.sh differ
Files <tag>/testkit/test_layout_cap.lua and tests/_kit/test_layout_cap.lua differ
Files <tag>/testkit/test_prose.lua and tests/_kit/test_prose.lua differ
```

`Kit.VERSION` 27 -> 31: revision 28 peels the suite inventory into `inventory.lua`, 29 peels the
prose gate into `prose_coverage.lua` and `prose_selftests.lua`, 30 prints `None.` under an empty
watch-list table in `RESULTS.md` (ATS-20), and 31 leaves `Kit.layoutCap.exempt`'s generated files out
of the runner's band table (ATS-21). Both payloads move together in one commit, as the pairing rule
requires.

## Consumption map

Unchanged: the same ten majors are looked up (`Core`, `Env`, `Media`, `DebugLog`, `Slash`, `Options`,
`Launcher`, `Lifecycle`, `Schema`, `Bus`), and `Perf` stays declined.

## Contract delta (blockers)

None. The v1.62.0 changelog block states that no member, descriptor field or row field changes and no
`NEEDS_*` floor rises; every moved member is attached to the same instance in the same order. The
library-absent stub in `settings/OptionsSetup.lua` owes nothing new (the surface-parity case stays
green), and no hand-typed library list in this repo names the moved files.
