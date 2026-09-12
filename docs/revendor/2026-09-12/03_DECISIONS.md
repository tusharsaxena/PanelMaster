# 03 — Decisions

This run was **non-interactive**. The orchestrator that launched it supplied standing answers in
place of the interview:

- **adopt** a candidate where the kit now provides the same contract and the suite stays green,
  with characterization first;
- **decline** anything that needs a harness migration;
- **file nothing and push nothing.** A decline is written here and handed back to the orchestrator
  as a proposed issue, not created with `gh`.

| Candidate | Decision | Record |
|---|---|---|
| B1 — #29, event half on an Embed target | **adopt** | Implemented in the re-vendor commit. See `04_EXECUTION_PLAN.md`. |
| B2 — #30, `Printf` on the NewAddon target (and the kit's recorded event half there too) | **not now**, because it needs a harness migration | **Not filed.** Returned to the orchestrator as a proposed `enhancement` issue at severity `low`. There is no live exposure: this addon has no `NS.Printf`. |

Class A items (#27, #28) were delivered, not offered, so they carry no decision.
