# 03 — Decisions (PanelMaster)

Pre-decided by the run's brief (`Ka0sAddonsCommonTasks/docs/2026-10-31-FINDINGS_REMEDIATION/`, M2):
no named adoption here, candidates beyond the brief recorded as declined, no interview and no GitHub
issue.

| Candidate | Decision | Source |
|---|---|---|
| `beforeGroup` / `afterSubgroup` | declined (run 2026-10-31) | M2 brief |
| `note` row | declined (run 2026-10-31) | M2 brief |
| `O.PositionBlock` | declined (run 2026-10-31) | M2 brief |
| `O.PageBanner{ acts }` | declined (run 2026-10-31) | M2 brief |
| `LibKa0s-Charts-1.0` | declined (run 2026-10-31) | M2 brief |

The Options degradation stub's `PositionBlock` is a 3g blocker, not a candidate, and was fixed in the
re-vendor commit (`01_DELTA.md`).

## LibKa0s#67, the sections sweep (options-ui §22)

**None.** No schema row here carries `disabledIf` or `shownWhen`, and no selector in `settings/Schema.lua`
or `settings/PanelSchema.lua` picks a group: `values` rows are the frame strata and the Skin tab's
`skipRender` rows, which the library draws. The Panels editor is bespoke AceGUI with no schema rows
(`settings/PanelEditorTabs.lua:60`), so `shownWhen` does not reach it, and two things there were
weighed and left:

- *Custom texture path* (`settings/PanelEditorTabs.lua:649`) is one box dimmed unless Artwork is
  *Custom path*. A single row sharing its line with *Fit to artwork*, which applies to every piece,
  so it is not a group a value owns.
- *Artwork position* and the two offsets are ignored by three of the five Fill values, and their
  tooltips say so. They are shared rows that do not describe any value's own section.

Hiding either would need a hand-rolled re-render, which §22 refuses.

## LibKa0s#68, the mover widths

**Fits by computation.** `modules/Unlock.lua:114-115` is its own label, not `DragHandle`, on a single
`CENTER` point with no width, so a name cannot truncate. A long name can overrun a narrow panel's
edge, and it still reads whole. No host change. The in-client sweep and the screenshots are the
owner's.
