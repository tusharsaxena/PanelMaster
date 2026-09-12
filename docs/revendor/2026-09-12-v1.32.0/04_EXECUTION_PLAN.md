# 04 — Execution plan

Every step is done. Order as run.

1. **Copy** both payloads whole from the tag, roll the provenance line in `CLAUDE.md`, record
   `01_DELTA.md`. Gate: 794 passed, luacheck 0/0. Commit `c3479a9`.
2. **Tests first** (`tests/test_debuglog.lua`, `tests/test_util.lua`): one `[Set]` line per act, the
   exact wording and count, no `[Panel]` line from the record verbs, a reset-all that is not also a
   switch, a copy and a switch worded by event, a library page reset bracketed, the mute released
   after a bracket, and a `profileReset` bracket that adds nothing. Red: 10 of 10 new cases failed
   before the change. The old `"reset 'Gateless2'"` wording check was kept as it is and stays green.
3. **The bracket**, in `settings/Schema.lua`: `S.BulkBegin` / `S.BulkEnd` / `S.BulkLine`, and the
   per-row line in `S:Set` muted inside it.
4. **The acts**: `R:Reset`, `R:CopyFrom`, `R:ResetPositions`, `R:Recover` log through `S.BulkLine`;
   `Sl:DoResetAll` snapshots the persisted rows and brackets `db:ResetProfile()`; the profile handler
   in `core/Database.lua` words its line by event; `R:ReloadProfile` stops logging.
5. **The correction after the v1.32.0 review**, applied before the commit: N is the host's own tally
   of values that changed, never the library's `count`; brackets nest by depth, only the outermost
   emits, and any `profileReset` level silences the line. New cases: 0-row re-runs of every act, a
   nested act logging once, a nested `profileReset` logging nothing. The nested case went red first
   (3 rows, not 2: the console row's nil default counted as a change until the seam compared the
   row's read-back value instead of the value handed in).
6. **Budget**: `modules/Registry.lua` held at 999 lines by moving the switch line out of it and
   folding two comment lines; `settings/PanelEditor.lua` untouched at 1476.
7. **Docs**: `docs/debug.md` (the line table), `docs/ARCHITECTURE.md`, `docs/settings-panel.md`,
   `docs/smoke-tests.md` (step 4a), `docs/test-cases.md` regenerated, README badge 805.
