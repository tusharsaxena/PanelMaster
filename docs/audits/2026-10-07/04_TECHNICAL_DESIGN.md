# 04 — Technical design (2026-10-07)

How to close each deviation in `02_DEVIATIONS.md`. Nothing here changes behavior except `PM-049`,
which is the one code fix with a player-visible effect; everything else is a dead-code deletion, a
degraded-path cosmetic, or documentation.

## Design principles for this pass

- **One write seam.** Every session-row restore goes through `NS.SchemaRuntime.ApplyDefault`, so the
  lock keeps its combat deferral (`NS.Unlock:SetUnlocked`) and the console its own `Hide`.
- **Test-first where behavior changes** (`testing-§4`, `testing-§12`): `PM-049a` goes red against
  today's tree before `PM-049` lands, with a `red under` comment naming the mutation.
- **No library edits.** Nothing here touches `libs/` or `tests/_kit/`. The two upstream notes below
  are for `WowAddonStandards`, not for this repo.

## PM-049 / PM-049a — the global reset restores the session-only rows

**Where.** `settings/Slash.lua` `Sl:DoResetAll` (`:36-47`); the comment in
`settings/OptionsSetup.lua:285-294`; a new case in `tests/test_slash.lua` beside `:395`.

**Shape.**

```lua
function Sl:DoResetAll()
  local db, S = NS.db, NS.Schema
  if db and db.ResetProfile then
    S.BulkBegin("reset", "all")
    S.resetSnapshot = S:SnapshotPersisted()
    local ok, err = pcall(db.ResetProfile, db)
    S.resetSnapshot = nil
    -- options-ui-§12: a profile reset cannot reach a session-only row (its storage is its own
    -- set()), so each one is put back to its declared default here, through the write seam.
    if ok then
      for _, row in ipairs(S.ProfileRows()) do
        if row.sessionOnly then NS.SchemaRuntime.ApplyDefault(row) end
      end
    end
    S.BulkEnd("reset", "all", nil, err, { profileReset = ok })
    if not ok then error(err, 0) end
  end
  print(Sl.RESET_ALL_TEXT)
end
```

**Which rows.** `state.locked` carries `sessionOnly = true` (`settings/Schema.lua:669`). Confirm the
composed `state.debugConsole` row carries the same flag before relying on the filter; if the
composer does not set it, wire `sessionOnly = true` onto it in `S:InstallMaster` (`:675-682`) beside
its `get`/`set`, which is the same move the lock row already makes. Do **not** list paths by hand —
a hand list is the "enumerate the keys" shape options-ui-§12 forbids for the wholesale half.

**Ordering.** After `ResetProfile` returns and inside the bracket: the profile handler has already
run `reload()` (`core/Database.lua:118-128`), so `ApplyDefault` on `state.locked` → `SetUnlocked(false)`
locks an already-reloaded registry and its repaint is the last one. Inside the bracket keeps the
`[Set] reset profile …` line the only one (debug-logging-§10).

**Combat.** `SetUnlocked(false)` has no combat gate (only an unlock defers), so a reset in combat
still locks. The Options library's combat lock already refuses the panel controls in combat; the
typed `/pm resetall` path reaches this with the same rule as today.

**Test (`PM-049a`).** One case: `fresh()`; `R:New` ×3; a second profile created through the AceDB
fake so the list has two; `NS.Unlock:SetUnlocked(true)`; `NS.DebugLog:Show()`; a recording receiver
on `NS.Registry.MSG.PANELS`; accept `KA0S_PANELMASTER_RESETALL`. Assert: `R:Count() == 0`; the
profile list unchanged and current; `NS.Schema:Get("state.locked") == true`;
`NS.DebugLog:IsShown() == false`; the receiver fired. Comment:
`-- red under: drop the session-row restore in Sl:DoResetAll`.

**Risk.** Low. The restore is the same write a player makes by ticking *Lock frame*. The only new
visible effect is the one the rule asks for.

## PM-050 — the degraded `FormatKV` renders plainly

**Where.** `settings/Slash.lua:501-510`; `tests/test_surface_parity.lua:190-194`.

**Shape.** `Sl.FormatKV = function(path, valueStr) return tostring(path) .. " = " .. tostring(valueStr) end`
on the degraded arm only. The live arm keeps `Sl.FormatKV = lib.FormatKV` (`:711`). Replace the two
byte-for-byte assertions with: the line contains the path, ` = ` and the value, and contains no
`|c`. Rewrite the `:501-507` comment to say why the member exists (the panel verbs call it) and why
it is plain (slash-commands-§1).

**Upstream note (WowAddonStandards, documentation lane).** `testing-§8` cites
`PanelMaster/settings/Slash.lua:316` as a stub missing `FormatKV`; that line has moved to `:508`,
and the example should say the cure is a plain member, so the two MUSTs read as one rule.

## PM-051 — delete the dead AddOns rungs

**Where.** `core/EnvSetup.lua:55-57`, `core/Compat.lua:30-33`, `.luacheckrc:34`, and any case in
`tests/test_envsetup.lua` / `tests/test_compat.lua` that drives the global rung.

**Shape.** `NS.Meta` keeps `Env` → `C_AddOns.GetAddOnMetadata` → `nil`. `Compat.AddOnFolders` keeps
`C_AddOns.GetNumAddOns` / `C_AddOns.GetAddOnInfo` → `nil`. Remove the three globals from
`read_globals`. **Verify first** in the live 12.1 client that `GetNumAddOns`, `GetAddOnInfo` and
`GetAddOnMetadata` are `nil` (`/dump GetNumAddOns`); the rule deletes a rung only when every admitted
client lacks the global. If any one is still present, keep that rung and say so in the comment.

**Risk.** None on a 12.x client. The headless mock may expose the globals; a case that relied on
them is rewritten against `C_AddOns`.

## PM-052 — name `minimapPos`

**Where.** `docs/ARCHITECTURE.md` `## Settings Schema` (`:29-78`).

**Shape.** One sentence after the registry block: *Named non-setting state (`architecture-§5`):
`db.global.minimap.minimapPos`, owned by `core/LauncherSetup.lua` (which hands LibDBIcon the
`minimap` table), written only by LibDBIcon-1.0 when the player drags the minimap button; no row
addresses it and no reset touches it.*

## PM-053 — `CLAUDE.md` in the stub's order

Move `CLAUDE.md:62-65` (the green-gate paragraph) to directly after the pointer list (`:28-35`).
The LibKa0s paragraph (`:37-43`), the provenance line (`:45-51`) and the Perf paragraph (`:53-60`)
follow it. No wording changes. `tests/test_vendor_sync.lua` reads the line by pattern, so it is
unaffected; re-run it anyway.

## PM-054 — the automated-tests README quotes the runner

Replace `docs/automated-tests/README.md:29`'s command cell with
`` `bash tests/_kit/run-automated-tests.sh --suite complexity` (lizard over the kit's sighted shadow; a function-count parity mismatch is a fail) ``,
the same wording as `docs/testing.md:242` (whose "kit revision 36" becomes 37 under `PM-044`).

## PM-046 — README placeholders and the Highlights prefix

`README.md:65`: "`/pm profile` with the profile's name switches to it from chat". `README.md:229`: the
same. `README.md:271`: `<br>- Released on lint, tests and complexity only: …`. De-AI pass on the
changed sentences (documentation-§1); nothing else in the README moves.

## PM-044 — doc and comment sweep

One commit, each item re-derived from the tree rather than edited by hand:

| Item | Change |
|---|---|
| `docs/ARCHITECTURE.md:384-391` | Re-run the census command; restate the two sizes; date it |
| `docs/ARCHITECTURE.md:349` | Re-run the trigger-set sweep; the **Why** names `UnitAffectingCombat` and `C_AddOns.GetAddOnMetadata` (or, after `PM-051`, only what remains). Decided date unchanged |
| `docs/testing.md:242` | "kit revision 36" → 37 |
| `core/LifecycleSetup.lua:53-54`, `:117-118` | Left click opens settings in either state; `NS.StandUp` registers the events |
| `core/LauncherSetup.lua:226` | `Register` runs from `OnInitialize` |
| `settings/Slash.lua:317`, `:367`, `:699-701` | Drop the README command table; the lock's writers are the checkbox, the verbs and the menu's *Locked* entry; `DisabledLine` is republished for the stub parity and the suites, and the citation reads `slash-commands-§7` |

## PM-042 — trim the hub under 400

`docs/ARCHITECTURE.md:333-344` (the Perf preamble) shrinks to two sentences that point at the row;
`:352-370` (retired rows) keeps one line each — rule, date, evidence id; `:384-420` (the census
narrative) keeps the result, the command and one line naming the automated-tests bundles that
recorded the peels. Expected result ≈ 370 lines. The kit's cap gate parses the census, so run it.

## PM-048 — one span bundle

`docs/revendor/<date>-v1.69.0-v1.70.0/01_DELTA.md`, line 1 exactly
`Delta: LibKa0s v1.68.1 -> v1.70.0 (span: v1.69.0 v1.70.0)`; `05_SUMMARY.md` one line per tag,
*carried by sweep, nothing adopted* (v1.69.0: `WidgetsLineChart.lua`, kit 37; v1.70.0:
`WidgetsAutocomplete.lua`). Re-run the two-listing check: it prints nothing.

## PM-055 — relabel #47

`gh issue edit 47 --remove-label state:triaged --add-label state:done` and one comment citing
`5119ae1`. Throttle against any other bulk GitHub write in the same session.

## PM-033 — at the next release

Full battery as a release run; disposition `tests/test_slash.lua` (1084) in the band table; the
bundle's `ANALYSIS.md` notes it is the first **sighted** release record and that `20260927-032003`
was the last unsighted one.

## Ordering constraints

1. `PM-049a` before `PM-049` (red first).
2. `PM-051` before `PM-044`'s register-row line, so the row states the post-deletion API list once.
3. `PM-054` and `PM-044`'s `docs/testing.md` edit in the same commit, so the two gate tables agree.
4. `PM-042` after `PM-044` and `PM-052`, which both edit the hub; trim last and re-count.
5. Regenerate `docs/test-cases.md` and the README `[tests]` badge in the same commit as any test
   added or removed (`PM-049a`, `PM-050`, `PM-051`).
