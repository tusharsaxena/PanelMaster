# 02 — Candidates (PanelMaster)

Sources: `git -C ../LibKa0s log --oneline v1.75.2..v1.76.0`, the tag's `CHANGELOG.md` block for
v1.76.0, and the `Since` markers in the tag's `docs/api/` documents for the two majors whose minors
moved, Widgets (`version-14.1.4.3.2-docs.md`) and Sim (`version-2.3.5-docs.md`). The run's ruling
makes the re-vendor non-interactive: no interview, no GitHub issue. The run's `OWNER_SCOPE.md`
assigns PanelMaster no adoption, so nothing is offered and nothing is declined.

## Class B (host change required): no adoption site

- **`W.TestStrip(parent, { kind = "sim" })` and `strip.kind` (Widgets 14).** Widgets
  `version-14.1.4.3.2-docs.md:27` and `:33` (**Since 14**). PanelMaster has neither a test mode nor a
  simulator: unlocking is the preview (`settings/Schema.lua`, "No `testModePath`, on purpose"), and
  `Widgets` is a settled decline (#43).

## Class A (delivered on the copy)

- SimTimeline 3 and SimPanel 5: a verb start plays on its own; Run all removed. Carried, not
  consumed (no simulator here).
- Widgets 14: the strip's simulation flavor. Carried; the console's copy window, the only Widgets
  surface the library reaches on this addon's behalf, is unchanged.

## Class C (whole module)

`Sim` stays without an adoption site. The settled declines keep their premises: `Widgets` #43,
`Pool` #46, `Item` #45, `Compat` #53, `Perf` ratified. v1.76.0 moves none of them.
