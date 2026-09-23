# 05 — Summary: LibKa0s v1.54.2 → v1.55.0, Steps 5–8

Run on 2026-09-23 by a workflow subagent (Phase 6 of the 2026-09-22 suite sweep). The interview
was replaced by the owner's CP-6 delegation (`03_DECISIONS.md`). Branch
`suite/2026-09-22-standards-sweep`. Nothing was pushed, and the addon version did not move.

## The tag and the minors

`v1.54.2` → `v1.55.0` (tag `bb161b7` → commit `6f9c5e0`). No existing file's minor moved. Three
new majors arrived: `Compat.lua` minor 1, `Bus.lua` minor 1 and `Schema.lua` minor 1. The kit went
from revision 24 to 25. The full per-file table is in `01_DELTA.md` 3c.

## Reached the addon for free (class A)

- Kit revision 25's gates. They were wired in the re-vendor commit `b7edc9f`, and no runner input
  was needed.
- The three new majors load from `LibKa0s.xml`. They are additive, and they change nothing this
  addon already consumed.

## Contract blockers

None (`01_DELTA.md` 3g).

## Adopted

**C-1 `LibKa0s-Schema-1.0`**, full adopter, per `schema.md` §11 (`:569`–`:577`).

| Commit | What |
|---|---|
| `d830303` | Six characterization cases in `tests/test_schema.lua`, green against the host's own seam before any code moved. They cover refusal texts and arity, a write answering exactly `true`, the `[Set]` line before `onChange`, a raising `onChange` propagating after the store, an interior-path read answering the stored table, and the library's `RestoreDefaults("general")` walk closing an open console (a walk no player reaches; see Open). |
| `af8a935` | The adoption. `settings/Schema.lua` builds `NS.SchemaRuntime` and keeps every seam name as a delegate. The minimap inversion moves onto the row's own `get`/`set`. `defaults.debugConsole = false` (JC-5). The refusal texts are kept through `L`. `Register` becomes `Validate`, and `hostSchemaStub` is added. The Options and Slash descriptors are bound to the instance's members. There is a parity case on both levels, with the major added to `Kit.setSurfaceSource`. Four library-absent cases (one live-seam identity case beside them) and the docs complete the commit. |

Tests added: 6 characterization and 5 adoption, 872 → 883 (`lua tests/run.lua`, Totals row).
Mutation checks, run by hand and then reverted, each went red:

- dropping a stub member: the parity case fails, naming `BulkAdd`;
- a stub `Set` that refuses: three stub cases fail;
- dropping `debugConsole = false`: the `RestoreDefaults` walk characterization case and a stub case
  fail. A later correction added the player's path, `/pm reset state.debugConsole` through
  `NS.Slash:OnSlash`, as its own case (884 total); the same mutation turns it red too.

What changed on purpose, and what did not:

- **Unchanged.** Stored bytes, refusal texts, the `[Set]` line and its place before `onChange`, the
  bulk lines (every `tests/test_debuglog.lua` line pin passes unedited), the row order and the tab
  partition, and the minimap row's store and inversion.
- **Changed, not observable.** The descriptors' `set` now answers `true` / `false, err` where the
  wrapper answered nothing. Neither library reads it (`OptionsWidgets.lua:1021`–`:1025`,
  `Slash.lua:688`). A `validate` refusal from `NS.Schema:Set` now carries a third return value,
  `why`, which is `nil` for every row here. It is pinned.
- **Changed, developer-facing only.** `S:Register` prints the library's `schema error` line
  instead of the host's wording, and it also counts shape errors (`type`, `group`, duplicates). It
  answers 0 on this schema.
- **Changed, crash path only.** A write or read before `NS.db` exists used to raise on a nil index.
  A write is now refused (`NO_ROOT`), and a read answers `nil`.
- **Degraded load.** It used to run the host's own full seam. It now runs the log-silent stub: writes
  land and no `[Set]` line is written. The boot shape check is skipped silently, where the host
  used to still check paths. The degraded console discards the line either way.

## Declined

| Candidate | Issue | State | Severity | Why |
|---|---|---|---|---|
| C-2 `LibKa0s-Bus-1.0` `Catalog` | [#52](https://github.com/tusharsaxena/PanelMaster/issues/52) (open) | `state:triaged` | `severity:low` | `bus.md` §12 `:638`–`:640`: "compliant today ... not debt. Optional" |
| C-3 `LibKa0s-Compat-1.0` | [#53](https://github.com/tusharsaxena/PanelMaster/issues/53) (closed, not planned) | `state:will-not-do` | `severity:low` | `compat.md` §8.8 `:542`–`:545`: no member fits; this addon reads no spell, spec or secret value |

## Skipped or unreached

None. All three candidates were decided.

## Suite results at each gate

All through `~/.claude/wow-addon/bin/ka0s-bounded`.

| Gate | `lua tests/run.lua` | lint (`.luacheckrc`) |
|---|---|---|
| Baseline, `b7edc9f` | 872 passed, 0 failed, 0 skipped, 872 total | 0 warnings / 0 errors in 60 files |
| `d830303` | 878 passed, 0 failed, 0 skipped, 878 total | 0 warnings / 0 errors in 60 files |
| `af8a935` | 883 passed, 0 failed, 0 skipped, 883 total | 0 warnings / 0 errors in 60 files |
| Bundle commit | 883 passed, 0 failed, 0 skipped, 883 total | 0 warnings / 0 errors in 60 files |

Complexity: the CCN 15 warning run (`-l lua -C 15 -w`) over `settings/Schema.lua`,
`settings/OptionsSetup.lua` and `settings/Slash.lua` reports no function above CCN 15. The highest
in `settings/Schema.lua` is the stub's `R.Set` at 12. `settings/Schema.lua` is 663 lines (`wc -l`),
below the 1000-line watch band. Perf (`tests/perf.lua`) was not run: this repo carries no measured
read-path ceiling, so the API document's re-run note does not apply.

## Open

- **`resetExempt` for the minimap row was not passed.** It would change what the library's own
  `RestoreDefaults("general")` walk does to that row, and no player reaches that walk:
  `settings/Panel.lua` rebinds the Defaults button to the profile reset, and `tests/test_launcher.lua`
  pins the rebinding. It is a candidate for the next pass if the rebinding is ever dropped.
- **The `architecture-§5` register row (the fields on a panel) should be re-checked.** Its trigger
  is "the schema helper gains instance addressing for registry records". The library seam now has
  `Set(path, value, instanceId)` plus `resolveRoot(parts, instanceId)`, which is that capability.
  This host's `NS.Schema:Set` does not take the argument yet, so the row stands. Retiring it is a
  separate, larger change that needs the owner's decision.
- **`NS.Util.SplitPath` has no production caller left.** The runtime owns the walk, and only
  `tests/test_util.lua` still calls it. It was left in place so this adoption changed no count
  outside its own seam.
- **In-game checks owed.** Two, and they are separate on purpose. (1) JC-5: open the debug
  console, then type `/pm reset state.debugConsole`. The console should close. That row reset is
  where a player meets `defaults.debugConsole = false`: with the default dropped, the console
  stays open (a scratch mutation run confirmed it, and `tests/test_schema.lua` now pins it).
  (2) Open `/pm`, toggle the Minimap button checkbox, then Reset all settings (General →
  Defaults, or `/pm resetall`) and accept. The minimap choice should survive. General → Defaults is
  the profile reset (`settings/Panel.lua` rebinds it to `P:RestoreDefaults`, which ends in
  `db:ResetProfile()`). It never writes the session-only `state.debugConsole` row, so it leaves an
  open console open, as it did before this pass. Only the headless cases reach the library's
  `RestoreDefaults("general")` walk, which does close the console.
