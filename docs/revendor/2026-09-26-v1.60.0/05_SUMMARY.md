# 05 — Summary: LibKa0s v1.58.0 → v1.60.0

Run on 2026-09-26 as plan item **DR-PM-01** (2026-09-25 diagnostics rollout, milestone M3), branch
`feat/2026-09-25-diagnostics-rollout` from `master` @ `82b9382`. One commit carries both payloads,
the provenance line, the edits the copy made owed, this record, the regenerated `docs/test-cases.md`
and the README badge. Nothing was pushed, and the addon version did not move.

## The tag and the minors

`v1.58.0` → `v1.60.0` (tag `ac59511` → commit `bed0eb1`), carrying v1.59.0 in the same copy.

| File | v1.58.0 | v1.60.0 |
|---|---|---|
| `DebugLog.lua` | 13 | 14 |
| `DebugLogDiagnostics.lua` | — | 1 (new) |
| `Slash.lua` | 15 | 16 |
| `WidgetsDragHandle.lua` | 2 | 3 |
| test kit | revision 26 | revision 27 |

Every other file is unchanged. No `NEEDS_*` floor rises; no file was deleted. Detail in `01_DELTA.md`.

## Reached the addon for free (class A)

- The debug console keeps 3000 lines instead of 1500 (compaction slack 128).
- `lib.TIME_COPY`, a by-hand copy-timing switch.
- `diagnostics` is exempt from the disabled gate on the library arm (Slash 16).

## Contract blockers

None. The copy made four edits owed, all in this commit:

- `core/DebugLogSetup.lua`: the library-absent stub gains `RunDiagnostics` (the collection's line,
  `/pm diagnostics is unavailable: the LibKa0s library did not load.`, nothing written, returns 0),
  `BuildDiagnostics` (the empty report in the library's shape) and `DebugVerb` (`diagnostics`, `on`,
  `off` → true; anything else → false). Without them `tests/test_surface_parity.lua`'s DebugLog case
  is red; renaming `RunDiagnostics` away was checked to redden it and the new stub case.
- `settings/Slash.lua`: the degraded `LIVE_VERBS` fallback gains `diagnostics`, and its comment now
  says thirteen verbs at Slash minor 16.
- `tests/test_slash.lua`: the live-set pin gains `diagnostics` in both its lists.
- `tests/run.lua`: declares the kit's `test_diagnostics_contract` suite. It skips, with its reason,
  until DR-PM-03 sets `Kit.diagnostics`.

One new host case, in `tests/test_libka0s.lua`: *Degraded install: the diagnostics report says the
library is absent and writes nothing*.

## Adopted

The diagnostics report is adopted but not in this commit: under the rollout plan it lands in DR-PM-02
to DR-PM-05 (`03_DECISIONS.md`, `04_EXECUTION_PLAN.md`).

## Declined

None, and no issue filed (the plan decided every surface in this release).

## Skipped or unreached

- WidgetsDragHandle's close mark is not a candidate: this addon has no DragHandle.
- `core/DebugLogSetup.lua:9` still says the console has a 1500-line cap. That comment is DR-PM-05's
  under the plan.

## Suite results at each gate

All through `~/.claude/wow-addon/bin/ka0s-bounded`.

| Gate | Headless suite | Lint | Complexity |
|---|---|---|---|
| Baseline, `82b9382` | 933 passed, 0 failed, 0 skipped, 933 total | 0 warnings / 0 errors in 62 files | — |
| After the copy | aborted by the kit's suite inventory: `test_diagnostics_contract.lua` not declared | — | — |
| After the owed edits | 934 passed, 0 failed, 1 skipped, 935 total | 0 warnings / 0 errors in 62 files | `lizard -C 15`: no function above CCN 15 |

The README badge reads **934/934**: the skip is shown in `docs/test-cases.md` with its reason and
counted in neither figure (`testing-§5`).
