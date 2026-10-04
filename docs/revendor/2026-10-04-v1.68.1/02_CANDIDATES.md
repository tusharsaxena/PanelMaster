# 02 — Candidates (PanelMaster)

Sources: `git -C ../LibKa0s log --oneline v1.68.0..v1.68.1`, LibKa0s `CHANGELOG.md:13-49` (the v1.68.1
block: "No LibStub minor moves, no `NEEDS_*` floor rises, no member is added or removed"), and
`docs/api/testkit/version-36-docs.md` at the tag ("No public member is added, removed or renamed, no
kit case is added, removed or renamed"). No library major moved a minor, so there is no
`docs/api/<Major>/` document pair and no `Since` marker in range.

**Zero adoption candidates.**

- **Class A (delivered on the copy):** the kit's command names. The runner's `RESULTS.md` lead-in now
  names `/dev-copilot:bump-version` as the command that evaluates the release gate (was
  `/wow-addon:bump-version`); the next bundle-writing `run-automated-tests.sh` run rewrites that one line
  of `docs/automated-tests/RESULTS.md`. Three comments follow the rename. Nothing for the host to do.
- **Class B (host change):** none. No new descriptor field, surface, row type or seam.
- **Class C (whole module):** none offered. No major is new. The unconsumed majors keep their settled
  declines — `Widgets` ([#43](https://github.com/tusharsaxena/PanelMaster/issues/43), `state:will-not-do`),
  `Perf` (ratified, `docs/ARCHITECTURE.md` > *Documented deviations*, LIBKA0S-31), `Pool` (#46) and
  `Item` (#45) — and v1.68.1 moves no premise of any of them: it touches only test-kit comments and one
  runner-printed line.
