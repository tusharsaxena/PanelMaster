# 02 — Candidates (PanelMaster)

Sources: `git -C ../LibKa0s log --oneline v1.83.0..v1.84.0`, the tag's `CHANGELOG.md` block for
v1.84.0, and the `Since` markers in the tag's `docs/api/` documents for the majors whose minors moved.
The run names no adoption for PanelMaster, so every candidate here is **declined (run 2026-10-31)**,
with no interview and no GitHub issue.

## Class B (host change required)

- **`opts.beforeGroup`, `opts.afterSubgroup`** (OptionsFlow 2), on `O.RenderRows`, `O.RenderSchema` and
  `O.RenderTabbedSchema`. Options `version-35.4.40.2.6.1.7.13.2.3.15.9.4.3.6.5.5.1.1.1-docs.md`, *What
  changed at this version*. The General page has no block between groups to draw. Additive. Declined.
- **The `note` row** (OptionsFlow 2, Schema 3, Slash 21). Same section. Additive; a host that walks
  `AllRows()` itself, as `settings/PanelSchema.lua:202` does, would have to skip notes. Declined.
- **`O.PositionBlock`** (OptionsCompose 15). Same section. The Panels editor's X and Y are on a bespoke
  page with no schema rows (`settings/PanelEditorTabs.lua`), so the composer's rows have nowhere to go.
  Declined. The stub member is a 3g blocker, not this candidate.
- **`O.PageBanner{ acts }`** (OptionsTabs 13). Same section. The Panels page's band is at the options-ui
  §14 limit of one row, and it needs no act. Declined.

## Class C (whole-module adoption)

- **`LibKa0s-Charts-1.0`** (new). `docs/api/Charts/version-1.1-docs.md`. This addon draws no chart.
  Declined.
- `Perf`: settled, ratified in `CLAUDE.md`. `Widgets`: settled, #43.

## Class A (delivered on the copy)

- WoW Default's Friz is measured and guarded (LibKa0s#69); no size moves.
- The diagnostics report's library line names Charts (DebugLogDiagnostics 6).
- `O.ClearScroll` keeps the band's refresher (Options 35).
- The library's peels: pure moves, no public member and no pixel.
- The drag handle's fit (WidgetsDragHandle 10) is carried, not seen: no `DragHandle` call here.
