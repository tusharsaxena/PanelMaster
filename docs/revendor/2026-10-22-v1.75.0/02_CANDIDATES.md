# 02 — Candidates (PanelMaster)

Sources: `git -C ../LibKa0s log --oneline v1.71.0..v1.75.0`, the tag's `CHANGELOG.md` blocks for
v1.72.0 to v1.75.0, and the `Since` markers in the tag's `docs/api/` documents for every major whose
minor moved. The run's ruling makes M2 non-interactive: no interview, no GitHub issue. The run's
`OWNER_SCOPE.md` assigns PanelMaster no adoption, and every new surface below has no adoption site
here, so nothing is offered and nothing is declined.

## Class B (host change required): no adoption site

- **`W.SearchBox` (Widgets 13, #52).** Widgets `version-13.1.4.3.2-docs.md:20`. PanelMaster has no
  filter bar and no standalone window to put one in; `Widgets` is not consumed (#43).
- **`W.TestStrip` (Widgets 13, #48).** Widgets `version-13.1.4.3.2-docs.md:21`. There is no explicit
  test mode: unlocking is the preview (`settings/Schema.lua:608`, "No `testModePath`, on purpose"),
  which `OWNER_SCOPE.md` F puts outside the preview-mode marker rule.
- **`W.StepPanel`.** Not in the tag. LK-11's outcome B withdrew it before release; the renderer is
  Sim-private inside `SimPanel.lua`, with no public contract.
- **`LibKa0s-Glow-1.0` (Glow 1, #56).** Glow `version-1-docs.md:42`. Nothing here glows; no
  LibCustomGlow-1.0 is vendored.
- **`LibKa0s-Sim-1.0` (Sim 1.1.1, #54).** Sim `version-1.1.1-docs.md:61`. No simulator: the addon
  reads no combat or group events whose answers a scenario would fake.
- **`Item.BonusIDsFromLink` (Item 3, #51).** Item `version-3-docs.md:20`. The addon reads no items;
  `Item` is not consumed (#45).
- **`O.Drawer` (OptionsDrawer 1).** Tag `CHANGELOG.md:556`. No page here has a per-subject
  collapsible group; the Panels page edits one panel at a time behind a tab strip. Only the stub
  member is added, for parity (blocker a in `01_DELTA.md`).
- **`Kit.assertLatchHoldOrder` (kit 39).** `testkit/latch.lua`. This addon has a hand-written
  slash-commands-§7 step-10 case; swapping it for the helper is a test refactor with no defect
  behind it, so it is not taken in this mechanical re-vendor.

## Class A (delivered on the copy)

- Options 29: a structural refresh of a shown page keeps its scroll offset (smoke PANEL-34).
- Kit 39: `__fireUnconditional` reaches method-name handlers, which Disabled 6's new (b2) now uses.
- Kit 41: a crashed lizard run is a release-gate fail, never a pass.
- DebugLogDiagnostics 3: the report's `LibKa0s running:` line names Glow and Sim when present.
- Perf 15 and PerfPanel 7: carried, not consumed (Perf declined).

## Class C (whole module)

`Glow` and `Sim` are new and have no adoption site (above). The settled declines keep their
premises: `Widgets` #43, `Pool` #46, `Item` #45, `Compat` #53, `Perf` ratified. v1.75.0 moves none
of them.
