# 03 — Decisions

This run was **non-interactive**. The orchestrator of the 2026-09-12 triage, acting on the owner's
instruction, set the calls in advance (the bulk-logging rollout brief, and its correction after the
v1.32.0 review) and asked that nothing be filed and nothing pushed.

| Candidate | Decision | Record |
|---|---|---|
| C1 — the Options bulk bracket | **adopt**, defensively | `f25a8af`. `settings/OptionsSetup.lua` hands the library `NS.Schema.BulkBegin` / `NS.Schema.BulkEnd`, always as a pair. |
| C2 — the Slash bulk bracket | **not wired** | Unreachable: the dispatcher's `CliResetAll` is overridden by the addon's own confirm-gated profile reset. Not a decline of the surface, so no issue was filed. |
| The host's own acts | **convert**, all five | `f25a8af`. One counted `[Set]` line each; see `05_SUMMARY.md`. |

Class A items were delivered, not offered, so they carry no decision.
