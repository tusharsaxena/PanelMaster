Delta: LibKa0s v1.65.0 -> v1.66.0

# LibKa0s v1.65.0 -> v1.66.0: the delta (PanelMaster)

Copied from the local tag `v1.66.0` (annotated, on `178ee0b`; `git archive v1.66.0 LibKa0s testkit`),
never from a branch tip. Plan item `GI-PM-RV`
(`Ka0sAddonsCommonTasks/docs/2026-10-01-GITHUB_ISSUE_PASS/`, spec S4). The adoption interview is out
of scope this cycle: candidates are listed in `02_CANDIDATES.md` and left for `GI-LK-13`'s census.

## The base

```sh
grep -n '[Bb]undles' CLAUDE.md          # Bundles [LibKa0s](...) v1.65.0 (MIT).
git log -1 --format=%h -- libs/LibKa0s tests/_kit   # a0d81a9, whose CLAUDE.md names v1.65.0
```

The two agree. The payload before the copy is byte-identical to `git archive v1.65.0` (`diff -rq`
on both folders, empty), so the base is `v1.65.0`.

The newest single-tag bundle before this one is `docs/revendor/2026-09-29-v1.63.0/`; this addon
vendored v1.64.0 (`9f7ca36`, re-cut in `29dc70d`) and v1.65.0 (`a0d81a9`) with no bundle. Step 3h's
listing (vendored minus recorded) printed exactly those two tags, so a consolidated span bundle,
`docs/revendor/2026-10-01-v1.64.0-v1.65.0/`, is written beside this one. The newest bundle's own
base (`v1.62.0`) matches the provenance line before its re-vendor (`ada4eee^`), so no base
correction is owed.

## libs/LibKa0s (`diff -rq --strip-trailing-cr`, before the copy)

```
Files <tag>/LibKa0s/DebugLog.lua and libs/LibKa0s/DebugLog.lua differ
Files <tag>/LibKa0s/LibKa0s.xml and libs/LibKa0s/LibKa0s.xml differ
Files <tag>/LibKa0s/OptionsTabs.lua and libs/LibKa0s/OptionsTabs.lua differ
Files <tag>/LibKa0s/OptionsWidgets.lua and libs/LibKa0s/OptionsWidgets.lua differ
Files <tag>/LibKa0s/Perf.lua and libs/LibKa0s/Perf.lua differ
Only in <tag>/LibKa0s: PerfCommands.lua
Only in <tag>/LibKa0s: PerfSampler.lua
Files <tag>/LibKa0s/Slash.lua and libs/LibKa0s/Slash.lua differ
Only in <tag>/LibKa0s: SlashParse.lua
Files <tag>/LibKa0s/Widgets.lua and libs/LibKa0s/Widgets.lua differ
Only in <tag>/LibKa0s: WidgetsReorder.lua
```

No `Only in libs/LibKa0s` line: nothing was removed upstream, so nothing is deleted here. The byte
diff names the same eleven entries, so no line-ending drift hid under it.

| File | Constant | v1.65.0 | v1.66.0 |
|---|---|---|---|
| `Widgets.lua` | `MINOR` | 11 | 12 |
| `WidgetsReorder.lua` | `REORDER_MINOR` | (new) | 1 |
| `DebugLog.lua` | `MINOR` | 18 | 19 |
| `Slash.lua` | `MINOR` | 18 | 19 |
| `SlashParse.lua` | `PARSE_MINOR` | (new) | 1 |
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 33 | 34 |
| `OptionsTabs.lua` | `TABS_MINOR` | 7 | 8 |
| `Perf.lua` | `MINOR` | 13 | 14 |
| `PerfSampler.lua` | `SAMPLER_MINOR` | (new) | 1 |
| `PerfCommands.lua` | `COMMANDS_MINOR` | (new) | 1 |

Every other file is unchanged. No `NEEDS_*` floor rises and no major is added. The payload goes
from 28 to 32 files. `PanelMaster.toc` loads the library through `libs\LibKa0s\LibKa0s.xml`, and
`tests/run.lua` and `tests/degraded_env.lua` derive their load lists from that XML
(`Loader.xmlFiles`), so the four new files load with no TOC or harness edit.

## tests/_kit (`diff -rq --strip-trailing-cr`, before the copy)

```
Files <tag>/testkit/README.md and tests/_kit/README.md differ
Files <tag>/testkit/asserts.lua and tests/_kit/asserts.lua differ
Files <tag>/testkit/framework.lua and tests/_kit/framework.lua differ
Files <tag>/testkit/inventory.lua and tests/_kit/inventory.lua differ
Only in <tag>/testkit: lizard_sighted.lua
Files <tag>/testkit/mock_base.lua and tests/_kit/mock_base.lua differ
Files <tag>/testkit/run-automated-tests.sh and tests/_kit/run-automated-tests.sh differ
Files <tag>/testkit/test_eol.lua and tests/_kit/test_eol.lua differ
Only in <tag>/testkit: test_lizard_sighted.lua
```

`Kit.VERSION` 34 -> 35. Both payloads move in one commit, as the pairing rule requires. Kit 35 adds
a fifth kit suite, `test_lizard_sighted`, which `Kit.assertSuiteInventory` refuses to run without:
it is wired in `tests/run.lua` in the same commit (`docs/api/testkit/version-35-docs.md`,
*Adoption*).

## Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' core modules settings
```

Unchanged: ten majors are looked up (`Core`, `Env`, `Media`, `DebugLog`, `Slash`, `Options`,
`Launcher`, `Lifecycle`, `Schema`, `Bus`). `Perf`, `Widgets`, `Pool`, `Item` and `Compat` have no
lookup; `Perf` stays declined (ratified, `docs/ARCHITECTURE.md` ▸ *Documented deviations*).

## Contract delta (blockers)

None. Read against the majors this addon consumes whose minor moved:

- **Slash 19** (`docs/api/Slash/version-19.1-docs.md`): `ParseValue` / `FormatValue` take an
  optional third resolver and a host `parse` is handed it as a third argument.
  `settings/Slash.lua:657` declares `parse = function(row, text)` and calls the two-argument
  `lib.ParseValue`, which answers as before; the host `L` (`settings/Slash.lua:667`) carries
  `RESET_ALL` alone, none of the parse keys, so no wording changes. The parser's move to
  `SlashParse.lua` keeps every member.
- **DebugLog 19**: `lib:New`'s refusals and defaults moved to file-level helpers, no member, field,
  default or string moved.
- **OptionsWidgets 34 / OptionsTabs 8**: `RenderGrid`'s new `parent` / `opts.gap` and the three
  `RenderTabbedSchema` opts are opt-in; `settings/Panel.lua:432` passes none of them, and the
  degraded stub (`settings/OptionsSetup.lua:51`, `:86`) keeps the same members.

## Complexity (kit 35, sighted)

Recorded in the commit and `05_SUMMARY.md` after the copy.
