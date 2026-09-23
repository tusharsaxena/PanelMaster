# 03 — Decisions

No interview was held. The owner delegated Step 6 (CP-6) to the workflow run, with these rules:
adopt each delta the design spec prescribes for this repo, one major per commit, characterization
test first; decline as *not now* (`state:triaged`) where the spec says the repo MAY defer, or where
an adoption cannot land green without changing behavior a test pins or a player would see (after
one honest attempt, rolled back to its commit boundary); decline as *never* (`state:will-not-do`)
only for a structural misfit the spec or this repo's docs record. Every decline is a public GitHub
issue on this repo, labeled with exactly one `state:` and one `severity:`.

Each decision was written here as it was made.

## C-1. `LibKa0s-Schema-1.0` — adopt

`schema.md` §11 (`:569`–`:577`) names PanelMaster a full adopter and offers it no deferral. The
survey in `02_CANDIDATES.md` found no pre-seam gate that would have to move into `validate` first:
the minimap inversion becomes the row's own `get`/`set`, as the spec says. Of the seven behavior
changes the API document lists, five already hold here. The other two are handled in the adoption
commit. JC-5 is kept by `defaults.debugConsole = false`, so a row reset still hides an open
console: `/pm reset state.debugConsole`, and the library's `RestoreDefaults("general")` walk. The
General page's Defaults button is neither; it is the profile reset, which never writes that
session-only row. `Validate`'s stricter shape check passes on this schema. The refusal texts are
kept through `descriptor.L`. Outcome: landed green in two commits, `d830303` (the six contract
cases, green against the host seam first) and `af8a935` (the adoption). See `05_SUMMARY.md`.

## C-2. `LibKa0s-Bus-1.0` `Catalog` — not now

Filed as [#52](https://github.com/tusharsaxena/PanelMaster/issues/52) (`state:triaged`,
`severity:low`, open). `bus.md` §12 (`:638`–`:640`) calls this repo "compliant today by the
module-scoped shape; not debt. Optional". An optional delta is one the spec lets this repo defer,
and the delegation's rule 2 reads that as *not now*. `severity:low` because it is polish: three
constants, each spelled once, and nothing is duplicated.

## C-3. `LibKa0s-Compat-1.0` — never

Filed as [#53](https://github.com/tusharsaxena/PanelMaster/issues/53) (`state:will-not-do`,
`severity:low`) and closed as not planned, like this repo's earlier structural declines (#43, #45,
#46). `compat.md` §8.8 (`:542`–`:545`) records the misfit: "No member adopted: ... PanelMaster's
Compat are wholly addon-specific". This tree agrees: no caller of any of the nine members.
