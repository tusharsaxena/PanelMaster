# 03 — Decisions

The candidates were decided in advance by the diagnostics rollout plan
(`Ka0sAddonsCommonTasks/docs/2026-09-25-DIAGNOSTICS_COMMAND/03_EXECUTION_PLAN.md` §3 *M3: per addon*,
and `OWNER_RULINGS.md`), and the interview was answered from it. **No decline issue is filed**: the
plan says so explicitly for every surface in this release.

| # | Candidate | Outcome | Where it lands | Issue |
|---|---|---|---|---|
| B1 | The diagnostics report (helper, Slash 16 verb, `Kit.diagnostics`) | **adopt** | DR-PM-02 (read-only accessor for the combat unlock queue), then DR-PM-03 (`modules/Diagnostics.lua` on the helper; `/pm debug dump` retired), DR-PM-04 (README `## Reporting a bug`) and DR-PM-05 (docs) | none |
| — | WidgetsDragHandle close mark (`spec.onClose`) | not a candidate (no DragHandle here) | — | none |
| — | The 3000-line buffer | not an adoption (class A, delivered) | — | none |
