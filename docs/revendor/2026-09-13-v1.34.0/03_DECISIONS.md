# 03 — Decisions

This run was non-interactive. The orchestrating session relayed the owner's instruction of
2026-09-13. Re-vendor v1.34.0 and roll the live references. Keep the stricter strata parse, which
refuses `low junk`. Add a test for that refusal and for `low` alone being accepted. Check whether
the library's Reset-all control is rendered here and whether `resetProfile` would be accurate and
inert, and report that as an option rather than take it. Skip filing and pushing.

- **Adopted: the strata refusal, as a test.** A new `tests/test_slash.lua` case lands in its own
  commit after the re-vendor. It is a test-only commit; the adapter does not change.
- **Adopted in a follow-up: `resetProfile` with `profilesPage = true`.** It was reported as accurate and
  inert (see `02_CANDIDATES.md`) and then taken at the owner's instruction. The same commit makes the
  harness's own AceDB fake fire `OnProfileReset` with `(event, db)`, as AceDB-3.0 does.
- **The visibility refusal, found while checking the adapter.** It predates this release. It was
  reported first, then fixed in a follow-up commit at the owner's instruction ("do all of these"),
  with a test that is red against the old adapter.

Not now: none. Declined: none. Unreached: none. No issue
filed.
