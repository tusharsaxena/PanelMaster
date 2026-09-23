# 04 — Execution plan

One adopted candidate, C-1 (`LibKa0s-Schema-1.0`). C-2 and C-3 are declined (`03_DECISIONS.md`) and
touch no code. Written before any code moved.

Gate at every commit, both through `~/.claude/wow-addon/bin/ka0s-bounded`: `lua tests/run.lua`
green and `luacheck .` at 0/0. Baseline on `b7edc9f`: **872 passed, 0 failed, 0 skipped, 872
total**; luacheck **0 warnings / 0 errors in 60 files**.

## Commit 1 — characterization tests, against the host's own seam

Test-only. Every case must pass on the code as it stands **before** the library takes the seam, so
it pins what the adoption has to keep rather than what it produces. All in `tests/test_schema.lua`.

| Case | What it pins | Why it matters to this adoption |
|---|---|---|
| a refusal answers the host's own words and stores nothing | unknown path: `false, "unknown path: settings.nonsense"`, 2 values, nothing stored; invalid value: `false, "invalid value"`, the stored value unchanged | The library's own texts differ (`Setting not found: %s`, `Invalid value for %s`); `descriptor.L` has to restore these |
| a write answers exactly `true` | `select("#", S:Set(...)) == 1` | Return arity through the kept `NS.Schema:Set` wrapper |
| a write logs its `[Set]` line, then runs `onChange` once | the call order `debug`, then `onChange`, with the line `settings.showLabels = false` | The pipeline order moves from host code into the library |
| a raising `onChange` propagates, and the write has landed | `pcall` fails with the raised value; `Get` reads the new value | Hard invariant 5; the host never swallowed it and must not start |
| a read of an interior path answers the stored table itself | `S:Get("settings") == NS.db.profile.settings` (identity) | A path with no row is still read, through `resolveRoot` |
| the page Defaults closes an open debug console | `state.debugConsole` true, then `NS.Helpers.RestoreDefaults("general")`, then false | JC-5: the row declares no default today and the host writes `nil`; the library's `default == nil` means no restore |

## Commit 2 — adopt `LibKa0s-Schema-1.0`

**`settings/Schema.lua`.**

- Resolve `LibStub("LibKa0s-Schema-1.0", true) or HostSchemaStub`. Publish the resolved library as
  `NS.SchemaLib` and the instance as `NS.SchemaRuntime`.
- `SchemaLib:New{ rows = S.Schema, resolveRoot = function() return NS.db and NS.db.profile, 1 end,
  debug = <NS.Debug at call time>, print = <NS.Print>, L = { NOT_FOUND = "unknown path: %s",
  INVALID = "invalid value" } }`. No `announce`: every row that broadcasts already does it in its
  own `onChange`. No `format`: the library's `tostring` fallback is the host's line byte for byte.
  No `debugEnabled`: `NS.Debug` gates itself, as it did. No `resetExempt`: see below.
- The kept names delegate, colon-called so no call site moves: `S:FindRow`, `S:Get`, `S:Set`,
  `S:Default`, `S:ReadPath` / `S:WritePath` (to `SchemaLib.Read` / `.Write`). `S.BulkBegin` and
  `S.BulkEnd` are the instance's members. `S.BulkLine(act, scope, n)` becomes
  `R.BulkRun(act, scope, function() R.BulkAdd(n) end)`, and its callers in `modules/Registry.lua`
  do not change.
- The minimap branch in `S:Set` / `S:Get` moves onto the composed row as `get`/`set` in
  `S:InstallMaster` (`wire(rows, S.MINIMAP_PATH, {...})`), reading and writing `db.global` through
  `SchemaLib.Read` / `.Write` and calling `NS.Launcher:SetShown`. The same negation, in the same
  place a reader looks for the row.
- The head splice becomes `R.AddRows(rows, 1)` after the `wire` calls.
- `defaults` gains `debugConsole = false` (JC-5).
- `S:Register` becomes `R.Validate{ defaultsRoot = ... }` (`global.` paths from `NS.defaults`,
  every other path from `NS.defaults.profile`) and answers `errors + missing`.
- `S:SnapshotPersisted` / `S:CountChangedSince` stay (`schema.md` §6 MAY), reading through
  `S:ReadPath`.
- `HostSchemaStub`: the API document's write-completing, log-silent reference stub, lib level
  included, refusing in this addon's own words. Its `Validate` answers `0, 0, 0` **silently**. The
  reference prints one line, but here that line would be a second unprompted login line on a
  degraded install. `core/CoreSetup.lua` already names the cause, and the launcher stub declines its
  own line for the same reason (`tests/test_launcher.lua`).

**Descriptors.** `settings/OptionsSetup.lua` and `settings/Slash.lua` bind `get`, `set`,
`applyDefault`, `findRow`, `allRows`, `bulkBegin` and `bulkEnd` straight to the instance members.
They are values, not wrappers, which is safe because this host has no pre-seam gate. Neither
library reads `set`'s return (`OptionsWidgets.lua:1021`–`:1025` returns it to a caller that discards
it; `Slash.lua:688` ignores it), so the move from a wrapper returning nothing to a member returning
`true` is not observable.

**Tests.**

- `tests/test_schema.lua`: the two cases that append a probe row to `S.Schema` in place and then
  write it go through `R.AddRows` and `R.Reindex`, as the library's index requires (API document,
  `Reindex`). The refusal case pins the arity the library answers for `validate` (`false, err, why`,
  with `why` nil here).
- `tests/test_debuglog.lua`: `S.bulk.depth == 0` becomes `not NS.SchemaRuntime.InBulk()`.
- `tests/test_surface_parity.lua`: a Schema section built from a real load with `Schema.lua` left
  out (`loadPartial({ Schema = true })`). `assertSurfaceParity(NS.SchemaRuntime, stub instance)`
  (two-table form) and `assertSurfaceParity(stub library, "LibKa0s-Schema-1.0", { "STRINGS" })`
  (by name).
- The library-absent writes, one per writer kind this addon has: a host verb (`/pm set`,
  `/pm disable`), Reset All (`Sl:DoResetAll`), the page Defaults sweep and a runtime writer
  (`Registry:Reset` through `S.BulkLine`). Each lands in the store and closes its bracket. On the
  whole-library-absent load: `S:Register()` answers 0 and prints nothing, and a write lands.
- `tests/test_libka0s.lua`: `settings/Schema.lua` joins `SEAM_FILES`, since it now resolves a
  LibKa0s major.
- `tests/run.lua`: `["LibKa0s-Schema-1.0"]` joins the `Kit.setSurfaceSource` map (the library
  table, which is what the by-name call compares the stub library against).

**Docs.** `docs/ARCHITECTURE.md` → `## Settings Schema` re-names the seam (the library instance
behind the host's names, the minimap row's own `get`/`set`, the stub). Also any
`docs/module-map.md` / `docs/schema.md` / `docs/debug.md` line that describes the retired host
walker, bracket or `S.bulk`.

**Not done, on purpose.**

- `resetExempt = { [S.MINIMAP_PATH] = true }`. It would change what the library's own
  `RestoreDefaults("general")` walk does to the minimap row. No player reaches that walk:
  `settings/Panel.lua` rebinds the page's Defaults button to the profile reset, and
  `tests/test_launcher.lua` pins that rebinding. Adding the veto would be a behavior change inside
  a mechanical diff. It is recorded in `05_SUMMARY.md` as open.
- `ResetCounted` / `ConsumeResetCount` in place of the snapshot count: the spec allows the
  snapshot to stay, and the reset-all line is pinned byte for byte (`tests/test_debuglog.lua`).

Rollback boundary: `b7edc9f` plus commit 1. A red commit 2 is reverted to there and reported.
