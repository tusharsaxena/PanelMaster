# 05 — Summary: LibKa0s v1.55.0 → v1.56.0

Run on 2026-09-24 as plan item RV-PM (2026-09-23 remediation plan), branch
`feat/2026-09-23-review-audit-remediation`. The copy and the record only: adoption is split into
this addon's M3 plan items, so this bundle has no `02`–`04`. Nothing was pushed, and the addon
version did not move.

## The tag and the minors

`v1.55.0` → `v1.56.0` (tag `4622018` → commit `514fc0a`), base taken from the `CLAUDE.md`
provenance line and confirmed against the payload (`01_DELTA.md` 3a). Fifteen library files moved a
minor, none was added or removed, and no `NEEDS_*` floor rose. The kit went from revision 25 to 26.
The full per-file table is in `01_DELTA.md` 3c. No base correction was owed (Step 0 ok), and no span
bundle was written here: PM-18 owns the back-fill.

## Reached the addon for free (class A)

- Slash 15: `/pm set` and `/pm reset <path>` print the schema runtime's refusal, and `NO_DEFAULT`,
  instead of echoing an unchanged value.
- Options 24: an options registration requested in combat parks and replays at
  `PLAYER_REGEN_ENABLED`; `OpenOptionsPanel` answers a boolean. The host has no park to delete.
- Options minors 31 and 4: the drag throttles keep their own armed flag; banner and header chrome
  stops leaking a widget per render (this addon draws neither, so this is latent here).
- Core 8's `printer.Format` secret-value fix, Media 4's `RegisterLSM` locale flags, DebugLog 13's
  batched trim, Launcher 2's once-only, untagged notices.
- Kit revision 26's stricter mocks and gates (frames start shown, the AceDB fake raises, recorded
  `EventRegistry`, lone-CR counting, store-root prose). None reddens this repo.

## Contract blockers

None (`01_DELTA.md` 3g).

## Adopted

Nothing in this run, by design. The opt-ins are plan items: PM-01 (the Schema stub gains `SetMany`,
id forwarding and `normalize`), PM-08 (Core's `SafeRegisterEvent` family), PM-09 (`writeThrough` and
the Slash stub's `DisabledLine` pinned with `Kit.assertLibraryConstant`), PM-12 (Bus `Catalog`,
#52), PM-13 (Lifecycle stub parity).

## Declined

None in this run. #53 (`LibKa0s-Compat-1.0`) stays declined from the v1.55.0 pass.

## Skipped or unreached

- `docs/test-cases.md` and the README `Tests` badge are stale against kit revision 26's renamed
  cases. PM-DOCS regenerates them; this commit does not.
- Perf (`tests/perf.lua`) was not run: this repo carries no measured read-path ceiling.

## Suite results at each gate

All through `~/.claude/wow-addon/bin/ka0s-bounded`.

| Gate | `lua5.1 tests/run.lua` | `luacheck .` |
|---|---|---|
| Baseline, `7183100` | 884 passed, 0 failed, 0 skipped, 884 total | 0 warnings / 0 errors in 60 files |
| After the copy (this commit) | 883 passed, **1 failed**, 0 skipped, 884 total | 0 warnings / 0 errors in 60 files |

The one failure is the Schema two-level surface parity case (`SetMany is missing`), the churn the
release names for this addon. PM-01 clears it. Complexity: lizard's CCN 15 warning run over the
authored tree reports nothing, and the largest authored file is 1476 lines.
