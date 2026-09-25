# PanelMaster — final summary (post-implementation), 2026-09-23

*This summary is written ahead of time, assuming every change in `02_PROPOSED_CHANGES.md` has landed and every check in `03_SMOKE_TESTS.md` has passed. Before it is used as a PR description, replace every "expected" figure with the real one.*

## Headline

This cycle closed three player-visible bugs:
- **Disabling the addon now takes every panel off the screen.** Before, unlocked panels stayed visible and draggable while the addon claimed to be off.
- **The *Only in combat* and *Only out of combat* visibility options now switch at the moment a fight starts or ends.** Before, they read the combat-lockdown flag, which is always false inside the combat-transition events.
- **`/pm recover` now judges a panel's position in the panel's own scale.** Before, it moved visible panels drawn smaller than 1× and ignored lost panels drawn larger.

It also stopped a profile switch from leaking a hidden, duplicate-named frame, and brought the grid-size maximum, the Panels page's per-panel Unlock tick and several stale comments back in line with the code. No saved data changes shape, and no LibKa0s change or re-vendor was needed.

## Counts

Critical fixed: 0 · High fixed: 3 (F-001, F-002, F-003) · Medium fixed: 3 (F-004, F-005, F-006) · Low fixed: 3 (F-007, F-008, F-009). Deferred: none.

## Changes by theme

### T1 — One show ladder

- **What changed:** While the addon is stood down, `Canvas:Render` strips the unlock overlay instead of decorating it, so no route can draw or arm a panel while the addon is off. When the addon comes back, panels return in whatever lock state is current.
- **Why it mattered:** `slash-commands-§7` requires every frame to be hidden at the source. Before the fix, three settings-panel and CLI routes put panels back on screen, and dragging them wrote to SavedVariables.
- **Findings / changes:** F-001, F-006 / C-01, C-02
- **Files:**
  - `modules/Canvas.lua`
  - `tests/test_disabled.lua`
  - `docs/test-cases.md`
  - `README.md`

### T2 — Combat truth from the event

- **What changed:** The two combat-transition handlers tell the renderer which side of the edge it is on. The Compat seam reads `UnitAffectingCombat("player")`, falling back to `InCombatLockdown()`.
- **Why it mattered:** Lockdown is false inside both transition events, so two of the four general-visibility values never took effect. The test that claimed to cover this delivered the events in an order the client never uses.
- **Findings / changes:** F-002, F-005 / C-03, C-04
- **Files:**
  - `core/Compat.lua`
  - `core/PanelMaster.lua`
  - `modules/Canvas.lua`
  - `.luacheckrc`
  - `tests/test_canvas.lua`
  - `tests/test_compat.lua`
  - `docs/test-cases.md`
  - `README.md`

### T3 — Recovery in scaled units

- **What changed:** A new `Util.EffectiveScale` is the one definition of the scale a panel is drawn at. Both the renderer and `R:Recover` use it.
- **Why it mattered:** Recovery was comparing scaled offsets against unscaled screen bounds.
- **Findings / changes:** F-003 / C-06
- **Files:**
  - `core/Util.lua`
  - `modules/Canvas.lua`
  - `modules/Registry.lua`
  - `tests/test_registry.lua`
  - `docs/test-cases.md`
  - `README.md`

### T4 — The pool bound is kept

- **What changed:** `RenderAll` releases mismatched frames before acquiring any.
- **Why it mattered:** A profile switch that swapped ids between two frame names created a duplicate of a live global name and orphaned a frame, once per switch.
- **Findings / changes:** F-004 / C-05
- **Files:**
  - `modules/Canvas.lua`
  - `tests/test_profiles.lua`
  - `docs/test-cases.md`
  - `README.md`

### T5 — Coherence

- **What changed:**
  - The grid-size bound is one constant.
  - The editor's Unlock tick refreshes whenever the unlock state changes, and is disabled while the global unlock is on.
  - Comments and two docs describe the current mechanisms.
- **Findings / changes:** F-007, F-008, F-009 / C-07, C-08, C-09
- **Files:**
  - `settings/Schema.lua` or `core/Constants.lua`
  - `settings/PanelEditor.lua`
  - `modules/Unlock.lua`
  - `core/CoreSetup.lua`
  - `core/Database.lua`
  - `core/LifecycleSetup.lua`
  - `defaults/Profile.lua`
  - `settings/Slash.lua`
  - `docs/ARCHITECTURE.md`
  - `docs/data-flow.md`
  - tests and inventory

## API and behavior changes

- **No slash verbs were added, renamed or removed.**
- **Behavior changes:**
  - While disabled, `/pm set state.locked false`, the *Lock frame* row and the per-panel Unlock tick still write their state, but nothing is drawn until the addon is enabled again.
  - The visibility options switch on the combat edge.
  - `/pm recover` leaves visible scaled panels where they are.
- **API:**
  - `Compat.InCombat()` now prefers `UnitAffectingCombat("player")`.
  - `Canvas:Render`, `Canvas:RenderAll` and `Canvas:RenderForCombat` accept an optional `inCombat` argument.
  - `Util.EffectiveScale(rec, settings)` is new.
- **No defaults were added or removed.** If the recommended C-07 option is taken, `C.MAX_GRID` goes from 128 to 64. No stored value was reachable above 64.
- **No locale keys changed.** The addon ships English-only; this is a ratified deviation.

## Saved-variable and migration notes

There is no schema bump: `NS.SCHEMA_VERSION` stays 2, and no stored value changes shape. Existing profiles need no action.

## Deprecated-API migrations

| Old | New | Files |
|---|---|---|
| `InCombatLockdown()` for display state | `UnitAffectingCombat("player")`, with `InCombatLockdown()` as fallback | `core/Compat.lua` |

## Performance impact

This section is deliberately omitted. The addon ships no offline scenarios and no committed captures (`performance-§1` is declined, and ratified), so there is no measured before/after to report. The perf-tagged change, C-05, keeps `RenderAll` at one table allocation per call.

## Test and complexity movement

- **Pass count:** 884 before. About +11 cases are expected, for roughly 895; record the real figure from `--list`. `docs/test-cases.md` and the README badge moved in the same commits as the cases.
- **Complexity:** No function is expected to cross CCN 15. The one layout number to watch at the next release's regeneration is `settings/PanelEditor.lua` (1476 LOC before, 24 lines under the `layout-§1` cap, issue #47). The regeneration is `/wow-addon:bump-version`, and it confirms this. Nothing was regenerated in this cycle.

## Known follow-ups

- **Issue #47:** split `settings/PanelEditor.lua`. C-08 must fit inside the remaining headroom. If it did not, #47 goes first.
- **`R:Recover` heuristics:** the per-anchor bounds judge only the anchor offset, not the panel's extent. This is intentional and documented at `modules/Registry.lua:854-861`. It is not changed here.

## Verification evidence

- `03_SMOKE_TESTS.md`, with its sign-off table filled in.
- Commit range: *to be filled in*, on `feat/2026-09-23-review-audit-remediation`.

## Suggested commit or PR description

```
PanelMaster: fix the disabled state, combat visibility and recover

- The stand-down latch now outranks the unlock decoration: a disabled addon draws
  and arms nothing, whichever surface unlocked the panels (F-001, F-006).
- General visibility "Only in combat" / "Only out of combat" is driven off the
  combat transition and UnitAffectingCombat instead of combat lockdown, which is
  false inside both transition events (F-002, F-005; events-frames-taint-§2).
- /pm recover bounds offsets in the frame's own scaled units (F-003).
- RenderAll releases mismatched frames before acquiring, so a profile switch no
  longer leaks a duplicate-named frame (F-004).
- One grid maximum, a truthful per-panel Unlock tick, and stale comments
  corrected (F-007, F-008, F-009).

Tests: 884 -> <N> (docs/test-cases.md and the README badge updated in step).
No schema bump; no LibKa0s change.
Review bundle: docs/reviews/2026-09-23/
```
