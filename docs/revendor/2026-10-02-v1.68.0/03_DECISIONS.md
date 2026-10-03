# Decisions (PanelMaster)

The owner delegated every decision for plan item `TP-PM-01`
(`Ka0sAddonsCommonTasks/docs/2026-10-02-LIBKA0S_TOOLTIP_PLACE/00_PLAN.md`: "The other seven:
re-vendor only (no strip)"). There was no interview, so each decision below is written with its
reasoning.

| # | Candidate | Decision | Reasoning | Issue |
|---|---|---|---|---|
| B1 | `DragHandle` `tooltipPlace` / `place` (Widgets 12.1.4, `WidgetsDragHandle.lua` minor 4) | **declined: not applicable** | PanelMaster builds no `lib.DragHandle` and does not look up `LibKa0s-Widgets-1.0`. Unlock mode drags the panel frame itself, with no strip and no tooltip, so the hook has no host here. This is not a gap: nothing in the addon is waiting for it | none filed. The plan files a decline only when the reason is a real gap, and this one is a missing premise. The Widgets major's own decline is already on record in #43 |

Nothing was adopted, so there is no `04_EXECUTION_PLAN.md`.
