# 04 — Execution plan (2026-07-30)

Ordered plan for an agent team to implement `02_PROPOSED_CHANGES.md`. Five milestones, each with a
hard exit criterion. **TDD is mandatory** (`testing`, anti-pattern #24): every task writes its
covering test first and leaves `lua tests/run.lua` green and `luacheck .` at 0/0. No task stages,
commits, pushes, or bumps the version without an explicit instruction from the user.

---

## Milestone M1 — Correctness in the data layer

*The two bugs that can damage or silently rewrite a user's saved layout. Nothing else should land
before these.*

| Task | Role | Implements | Files touched |
|---|---|---|---|
| **M1-T1** | lua-refactorer | C-01 (F-001) | `core/Constants.lua`, `modules/Unlock.lua`, `core/Database.lua`, `modules/Registry.lua`, `tests/test_unlock.lua`, `tests/test_database.lua`, `docs/ARCHITECTURE.md` |
| **M1-T2** | lua-refactorer | C-02 (F-014, F-015) | `modules/Unlock.lua`, `modules/Registry.lua`, `tests/test_unlock.lua`, `tests/test_registry.lua` |
| **M1-T3** | lua-refactorer | C-06 second half — anchor-aware `Recover` (F-006) | `modules/Registry.lua`, `tests/test_registry.lua` |

**Concurrency:** M1-T1 and M1-T2 both touch `modules/Unlock.lua` and `modules/Registry.lua` →
**must serialize**, in the order T1 → T2 (T2's `R:NewBatch` is easiest to write once T1 has settled
the preview record's shape). M1-T3 touches `modules/Registry.lua` too → **serialize after T2**.

**Done when:** a `/reload` with test mode on leaves zero `Preview: *` records (smoke test C-01
steps 1–5 pass in-client); leaving preview clears per-panel unlocks; `/pm recover` moves an
on-screen `TOPLEFT` panel zero times and an off-screen panel once. Suite green.

**Checkpoint CP-1 (human):** run the C-01, C-02 and C-06 smoke sections in a live client before
starting M2. These are the only changes in the whole plan that alter persisted data; verifying them
against a real SavedVariables file is worth the pause.

---

## Milestone M2 — Settings-page refresh contract

*The Panels page's rebuild/refresh model, fixed as one coherent change rather than three patches.*

| Task | Role | Implements | Files touched |
|---|---|---|---|
| **M2-T1** | ux-cleanup | C-05 — per-context dropdown tracking (F-005) | `settings/Panel.lua`, `tests/test_panel.lua` |
| **M2-T2** | ux-cleanup | C-03 — single rebuild trigger (F-002) | `settings/Panel.lua`, `tests/test_panel.lua` |
| **M2-T3** | ux-cleanup | C-04 — per-editor refreshers on `MSG_PANEL` (F-004) | `settings/Panel.lua`, `tests/test_panel.lua` |

**Concurrency:** all three touch `settings/Panel.lua` → **fully serialized**, in the order
T1 → T2 → T3. T1 first because it is the smallest and independent; T2 before T3 because T3's
refresher-clearing hooks into the rebuild path T2 rewrites.

**Done when:** delete / rename / create / copy from the Panels page each produce exactly one rebuild
and no Lua error (smoke C-03); a `/pm panel … width …` or a drag updates the open editor in place
with no rebuild (smoke C-04); the General page's dropdown still closes on scroll after a Panels
rebuild (smoke C-05). Suite green.

**Checkpoint CP-2 (human):** this milestone is the highest-risk UI work in the plan and its failure
mode (a released AceGUI widget) is invisible headlessly. Run the whole C-03/C-04/C-05 smoke block
in-client before the refactor in M3 moves this code into a new file.

---

## Milestone M3 — Structural refactors

*Behavior-neutral by construction. Deliberately after M2 so the peel moves already-correct code.*

| Task | Role | Implements | Files touched |
|---|---|---|---|
| **M3-T1** | lua-refactorer | C-07 — peel `settings/PanelEditor.lua` (F-007) | new `settings/PanelEditor.lua`, `settings/Panel.lua`, `PanelMaster.toc`, `tests/test_panel.lua`, `docs/ARCHITECTURE.md`, `docs/agent-context.md` |
| **M3-T2** | lua-refactorer | C-09 — move `NS.COMMANDS` to `settings/Slash.lua` (F-010) | `settings/Schema.lua`, `settings/Slash.lua`, `tests/test_slash.lua`, `tests/test_schema.lua`, `docs/ARCHITECTURE.md` |
| **M3-T3** | lua-refactorer | C-08 — one debug gate (F-009) | `modules/Registry.lua`, `modules/Canvas.lua`, `modules/Unlock.lua`, `modules/DebugLog.lua`, `settings/Schema.lua`, `settings/Panel.lua`, `core/Database.lua`, `tests/test_debuglog.lua` |
| **M3-T4** | lua-refactorer | C-06 first half — editor slider bounds from Constants (F-003) | `core/Constants.lua`, `settings/PanelEditor.lua`, `tests/test_constants.lua` |

**Concurrency:**
- M3-T1 and M3-T3 both touch `settings/Panel.lua` → **serialize**, T1 → T3 (so T3 edits the
  post-peel files).
- M3-T2 and M3-T3 both touch `settings/Schema.lua` → **serialize**, T2 → T3.
- M3-T4 touches `settings/PanelEditor.lua`, which does not exist until T1 → **after T1**.
- M3-T2 is **parallelizable** with M3-T1 *only if* the peel does not move `NS.COMMANDS` (it does not
  — the table lives in `settings/Schema.lua`, the editor in `settings/Panel.lua`). Safe to run
  concurrently; serialize both before T3.

Recommended serial order: **T1 → T4 → T2 → T3** (T2 anywhere before T3).

**Done when:** `settings/Panel.lua` is under ~800 LOC, `settings/PanelEditor.lua` exists and is
listed before it in the TOC, no `if NS.State.debug and NS.Debug then` remains outside
`modules/DebugLog.lua`, `NS.COMMANDS` is defined in `settings/Slash.lua`, and no slider in the editor
carries an inline bound. Suite green; smoke C-07, C-08, C-09 pass.

**Checkpoint CP-3 (human):** confirm all four settings subcategories still render and the Defaults
buttons are skinned (not red) after the peel — the `options-ui-§5` lazy-build rule is easy to break
in a file move.

---

## Milestone M4 — Surface and vocabulary

*Everything the user reads. Grouped so the code labels, the README and the help index move together.*

| Task | Role | Implements | Files touched |
|---|---|---|---|
| **M4-T1** | ux-cleanup | C-10 — US English sweep (F-008) | `settings/Panel.lua`, `settings/PanelEditor.lua`, `core/Constants.lua`, `core/Namespace.lua`, `core/Util.lua`, `modules/Registry.lua`, `modules/Canvas.lua`, `modules/Unlock.lua`, `modules/DebugLog.lua`, `README.md`, `docs/ARCHITECTURE.md`, `docs/agent-context.md`, `tests/*` |
| **M4-T2** | ux-cleanup | C-11 — surface `debug dump` / `panel deleteall` (F-011, F-025) | `settings/Slash.lua`, `README.md`, `tests/test_slash.lua` |
| **M4-T3** | ux-cleanup | C-12 — comments, tagline, `panelID` (F-017, F-018, F-019, F-021, F-024) | `settings/PanelEditor.lua`, `modules/Registry.lua`, `modules/Canvas.lua`, `PanelMaster.toc`, `README.md` |

**Concurrency:** M4-T1 touches nearly every file → **run it alone**, first in the milestone, and let
T2/T3 rebase onto it. M4-T2 and M4-T3 are **parallelizable** with each other except for `README.md`
→ serialize their README edits (or have one agent own the README for the whole milestone).

**Done when:** `grep -rin 'colour\|behaviour\|recognis\|centre\b\|cancelled' --include='*.lua' --include='*.md' .`
(excluding `libs/`) returns nothing; `/pm help`, the settings landing page and the README's command
table list the same verbs with the same descriptions; one tagline. Suite green.

---

## Milestone M5 — Robustness and cleanups

*Lowest risk, last, so a mistake here cannot mask anything above.*

| Task | Role | Implements | Files touched |
|---|---|---|---|
| **M5-T1** | wow-api-migrator | C-14 — registration retry + spoken `/pm config` failure (F-013) | `settings/Panel.lua`, `core/PanelMaster.lua`, `tests/test_panel.lua` |
| **M5-T2** | lua-refactorer | C-13 — grid settings stop repainting (F-012) | `settings/Schema.lua`, `tests/test_canvas.lua`, `tests/test_schema.lua` |
| **M5-T3** | lua-refactorer | C-15 — small cleanups (F-016, F-020, F-022, F-023) | `core/Compat.lua`, `core/Util.lua`, `modules/Registry.lua`, `settings/Slash.lua`, `tests/test_compat.lua`, `tests/test_util.lua`, `tests/test_registry.lua`, `tests/test_slash.lua` |

**Concurrency:** M5-T1 (`settings/Panel.lua`, `core/PanelMaster.lua`), M5-T2 (`settings/Schema.lua`)
and M5-T3 (`core/*`, `modules/Registry.lua`, `settings/Slash.lua`) have **disjoint** source file sets
→ **fully parallelizable**. Their test files are also disjoint. `tests/run.lua`'s manifest may need a
single coordinated edit if any new test file is added — assign that to one agent.

**Done when:** the addon appears in Esc → Options from login without `/pm config` ever being run;
`/pm set settings.gridSize 8` produces no repaint but snapping still works; `/pm set … nope` errors
instead of storing `false`; `Compat.HasBackdrop` is gone. Suite green.

**Checkpoint CP-4 (human):** full `03_SMOKE_TESTS.md` pass — per-change sections, the R-01…R-16
regression suite, the T-01…T-05 taint block, the localization pass and the perf spot-checks — with
the sign-off table filled in.

---

## Critical path

```
M1-T1 ─► M1-T2 ─► M1-T3 ─► [CP-1]
                              │
                              ▼
                 M2-T1 ─► M2-T2 ─► M2-T3 ─► [CP-2]
                                              │
                                              ▼
                              M3-T1 ─► M3-T4 ─┐
                              M3-T2 ──────────┼─► M3-T3 ─► [CP-3]
                                                            │
                                                            ▼
                                       M4-T1 ─► { M4-T2 ‖ M4-T3 }
                                                            │
                                                            ▼
                                       { M5-T1 ‖ M5-T2 ‖ M5-T3 } ─► [CP-4]
```

**Serialization callouts**
- `modules/Registry.lua` is touched by M1-T1, M1-T2, M1-T3, M3-T3, M4-T1, M4-T3, M5-T3 — the single
  most contended file in the plan. Never run two of those concurrently.
- `settings/Panel.lua` is touched by M2-T1/T2/T3, M3-T1, M3-T3, M4-T1, M5-T1 — same rule.
- `README.md` is touched by M4-T1, M4-T2, M4-T3 — one owner for the milestone.
- `tests/run.lua` — only M3-T1 adds a test file; that agent owns the manifest edit.

**Genuinely parallel windows:** M3-T1 ‖ M3-T2 (before T3); M4-T2 ‖ M4-T3 (with a README owner);
M5-T1 ‖ M5-T2 ‖ M5-T3.

---

## Incremental commit strategy

One commit per task, so any single change is revertible in isolation. **Do not create a branch and
do not commit without an explicit instruction** — `versioning-git` is trunk-based and anti-pattern
#21 forbids an unrequested topic branch. Version is **not** bumped by this work; the
`## What's new` / `## Version History` roll-forward (`documentation-§1` item 5) belongs to whichever
change bumps the version, not to these.

Suggested messages:

```
M1-T1  fix(preview): sweep orphaned preview panels left by a reload (F-001)
M1-T2  fix(preview): route lock state through SetUnlocked and broadcast once (F-014, F-015)
M1-T3  fix(registry): make off-screen recovery anchor-aware (F-006)
M2-T1  fix(settings): track open dropdowns per page, not globally (F-005)
M2-T2  fix(settings): rebuild the Panels page once, from the bus only (F-002)
M2-T3  fix(settings): refresh the panel editor in place on field changes (F-004)
M3-T1  refactor(settings): peel the panel editor into settings/PanelEditor.lua (F-007)
M3-T4  refactor(settings): source editor slider bounds from Constants (F-003)
M3-T2  refactor(slash): move NS.COMMANDS beside its dispatcher (F-010)
M3-T3  refactor(debug): keep the debug gate at the sink only (F-009)
M4-T1  style(lang): US English across strings, identifiers and docs (F-008)
M4-T2  docs(slash): surface 'debug dump' and 'panel deleteall' in help (F-011, F-025)
M4-T3  docs: one tagline, corrected comments, clear panelID on release (F-017…F-024)
M5-T1  fix(settings): retry category registration on PLAYER_LOGIN (F-013)
M5-T2  perf(canvas): stop repainting on grid-only settings writes (F-012)
M5-T3  fix: stricter boolean parsing, DeleteAll cleanup, drop dead Compat shim (F-016…F-023)
```

Each commit runs the green gate before it is offered. If the user asks for a squash, M1+M2 read
naturally as one "settings page and preview lifecycle fixes" commit and M3–M5 as one "refactor and
polish" commit.
