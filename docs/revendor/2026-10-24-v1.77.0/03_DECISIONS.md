# 03 — Decisions (PanelMaster)

Pre-decided by the run's bundle, `Ka0sAddonsCommonTasks/docs/2026-10-24-KEYBINDS_LAYOUT_STRATA/`
(`items.tsv`, `plan-data/items.json` PM-RV and PM-ZS). No interview and no GitHub issue, per the
item spec.

| Candidate | Decision | Source |
|---|---|---|
| `O.StrataTooltip` | adopt, in PM-ZS | `items.tsv` PM-ZS (item 030); tag `CHANGELOG.md` *Consumers planned at v1.77.0* names PanelMaster |
| Kit `mock_layers.lua` | adopt in PM-ZS if its tests need it | PM-ZS |
| Keybindings tab (`KeybindingsTab`, `KeybindRows`, `KEYBINDS_UNCHANGED`) | deferred (run 2026-10-24) | PM-RV spec; PanelMaster has no PM-KB item and no binding |
| Kit `mock_bindings.lua`, `assertBindingsXml`, `keybindThroughTab` | deferred (run 2026-10-24) | PM-RV spec |
| `Core.RaiseStaticPopups` | deferred (run 2026-10-24) | PM-RV spec |
| DragHandle `level` / `ApplyLevel` / `ignoreParentAlpha` | deferred (run 2026-10-24); under the settled Widgets decline #43 | PM-RV spec |

The Options degradation stub's four new members are a 3g blocker, not a candidate, and were fixed in
the re-vendor commit (`01_DELTA.md`).
