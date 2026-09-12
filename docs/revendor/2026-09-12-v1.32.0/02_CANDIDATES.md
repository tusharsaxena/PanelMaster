# 02 — Candidates

What v1.32.0 offers this addon, and where it would land. The library moved two files and added no
member; the only new surface is one optional descriptor pair.

## Class A — delivered by the copy, nothing to decide

- **Options minor 16 and Slash minor 8 run minor 15's and minor 7's exact walks** for a host that
  supplies neither new field (`docs/api/Options/version-16.15.4.3-docs.md`, "A host that supplies
  neither runs exactly minor 15's walk"). Before C1 below, that was this addon: 794 cases stayed
  green on the copy alone.

## Class B — adoptable

### C1 — `bulkBegin` / `bulkEnd` on the Options descriptor

- **Surface.** `bulkBegin(act, scope)` and `bulkEnd(act, scope, count, err, info)`, called around
  `O.RestoreDefaults(pageKey, ctx)` (act `"reset"`, scope `pageKey`) and `O.RestoreAllDefaults()`
  (scope `"all"`). `info.profileReset` is true only when `resetProfile` was called and returned.
- **Reach here.** None of this addon's controls reaches either walk today.
  `settings/Panel.lua:339` `P:RestoreDefaults` sends the header Defaults to `Sl:ConfirmResetAll`,
  and the global reset is `db:ResetProfile()` (`settings/Slash.lua`, `Sl:DoResetAll`), not a row
  walk. `settings/OptionsSetup.lua`'s own comment records that the addon does not use
  `O.RestoreAllDefaults` at all. A page left on the library's default Defaults would reach
  `O.RestoreDefaults`, and unbracketed that is one `[Set]` line per row.
- **Recommendation.** Adopt, defensively, as the rollout brief allows. The cost is two descriptor
  lines and a bracket this addon needs anyway for its own record verbs (below).

### C2 — the same pair on the Slash descriptor

- **Reach here.** None. `settings/Slash.lua` overrides the dispatcher's `CliResetAll` with its own
  (`Sl:CliResetAll` → `Sl:ConfirmResetAll`), because a global reset here is a profile reset and the
  library's `CliResetAll` is a row walk. The bracket would wrap a walk that never runs.
- **Recommendation.** Do not wire. Nothing to bracket.

## The host's own bulk acts (the rollout, not a library surface)

The library brackets only its own walks (`docs/api/Options/version-16.15.4.3-docs.md`, "What the
bracket does not do"). This addon's bulk acts are its own, and `debug-logging-§10` binds them the
same way: `R:Reset`, `R:CopyFrom`, `R:ResetPositions`, `R:Recover` (`modules/Registry.lua`) and
`Sl:DoResetAll` through the `OnProfileReset` handler (`core/Database.lua`).
