# 04 — Execution plan

Nothing is implemented as an adoption in this run. The one adopted candidate, the diagnostics report
(B1), is carried by the rollout plan's later items on this branch, one commit each:

1. **DR-PM-02**: a read-only accessor for `modules/Unlock.lua`'s combat unlock queue
   (`pendingUnlock` / `pendingPanels`), returning a copy, with its test.
2. **DR-PM-03**: `modules/Diagnostics.lua` on the library helper (the plan's `DX-PM` sections), both
   slash forms, `Kit.diagnostics` wired in `tests/run.lua` so the kit's contract suite runs instead of
   skipping, and `/pm debug dump` retired with its tests.
3. **DR-PM-04** (README) and **DR-PM-05** (docs).

What this run's commit (DR-PM-01) carries beside the payload is only what the copy made owed
(`01_DELTA.md` 3g): the stub's three members, the degraded live list, the live-set pin, and the kit
suite declared.
