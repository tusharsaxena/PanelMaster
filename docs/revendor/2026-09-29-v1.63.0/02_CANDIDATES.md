# Candidates (PanelMaster)

Sources: the `CHANGELOG.md` block for v1.63.0 at the tag and the `Since` markers in
`docs/api/Slash/version-17-docs.md`.

## A. Reached the addon on the re-vendor alone (delivered)

None. Every v1.63.0 member needs a host change before a player can reach it.

## B. Host change required

| # | Candidate | Evidence | Would touch | Recommendation |
|---|---|---|---|---|
| B1 | **The `profile` verb**: the `profiles` descriptor field, `Sl:CliProfile(rest)` behind a `profile` row in `NS.COMMANDS`, `Sl:ProfileSwitch(name)`, and `profile` added to the host's own `liveVerbs` | `version-17-docs.md`, *The profile verb* and *The degradation stub*; CHANGELOG v1.63.0 *Slash minor 17* | `settings/Slash.lua`, `locales/enUS.lua`, the degraded stub, tests, docs | **Adopt**, in `SP-PM-02` (owner decisions D1 to D3 of the rollout plan) |

`lib.ProfileNames(store)` is not a separate candidate: it serves a host's own profile sub-tree, and
this addon has none.

## C. Whole-module adoption

Nothing in v1.63.0 touches `Perf.lua` or `PerfPanel.lua`, so the ratified `Perf` decline
(`docs/ARCHITECTURE.md` ▸ *Documented deviations*, `performance-§1`) has no premise that moved. Not
re-offered.
