# Candidates (PanelMaster)

Sources: the `CHANGELOG.md` block for v1.66.0 at the tag, and the `Since` markers in
`docs/api/Slash/version-19.1-docs.md`, `docs/api/DebugLog/version-19.2.1-docs.md`,
`docs/api/Options/version-27.2.34.2.2.8.1.7.4.2-docs.md` and `docs/api/testkit/version-35-docs.md`.
Listed, not interviewed: the 2026-10-01 issue pass (spec S4) defers adoption to `GI-LK-13`'s
consumer census.

## A. Reached the addon on the re-vendor alone (delivered)

- **Kit 35's sighted complexity suite**: the release battery now measures lizard through the
  sanitized shadow and fails on a parity mismatch. Wired in `tests/run.lua` in the re-vendor commit
  (the kit's inventory gate requires it), so it is delivered, not offered.
- **DebugLog 19 / Slash 19 / Perf 14 internal refactors**: no member, field, default or string
  moved.
- **The parser, `ReorderList`, the Perf capture and command surface peeled to secondary files**:
  loaded through `LibKa0s.xml`, no member moved.

## B. Host change required

| # | Candidate | Evidence | Would touch | Recommendation |
|---|---|---|---|---|
| B1 | Thread Slash 19's `textOf` resolver through the host `parse` adapter (`function(row, text, textOf) return lib.ParseValue(row, ..., textOf) end`), so a future `L` override of a parse refusal reaches the case-insensitive enum path too | CHANGELOG v1.66.0 *Slash minor 19*; `settings/Slash.lua:657` | `settings/Slash.lua`, `tests/test_slash.lua` | Defer to `GI-LK-13`: the host `L` carries `RESET_ALL` alone today, so nothing a player sees changes |
| B2 | `O.RenderGrid(ctx, items, parent, opts)` (`parent`, `opts.gap`) | CHANGELOG v1.66.0 *OptionsWidgets minor 34* | none today: this addon renders through `RenderTabbedSchema` and its own editor rows | Not applicable today; note for the census |
| B3 | `RenderTabbedSchema` opts `untabbedSkipRender`, `disabledReplaces`, `rerender` | CHANGELOG v1.66.0 *OptionsTabs minor 8* | `settings/Panel.lua:432` | Defer to `GI-LK-13`: no defect in this addon's General page asks for them |

## C. Whole-module adoption

Perf minor 14 adds report-only budgets and the declared-parent row. Neither touches the premise of
the ratified `Perf` decline (`docs/ARCHITECTURE.md` ▸ *Documented deviations*, `performance-§1`:
the bounded-cost argument). Not re-offered.
