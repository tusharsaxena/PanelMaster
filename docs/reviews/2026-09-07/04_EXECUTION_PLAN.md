# Execution plan — Ka0s Panel Master, 2026-09-07

Implements [`02_PROPOSED_CHANGES.md`](02_PROPOSED_CHANGES.md); findings in
[`01_FINDINGS.md`](01_FINDINGS.md); verification in [`03_SMOKE_TESTS.md`](03_SMOKE_TESTS.md).

Nothing here is urgent. The verdict is *minor issues* and the suites are green today
(`luacheck` 0/0 in 27 files; `763 passed, 0 failed`; `lizard` no thresholds exceeded), so this is
scheduled work, not a hotfix.

---

## Milestone M0 — baseline

**Done when:** a clean tree, a recorded baseline, and a branch.

| Task | Role | Implements | Files |
|---|---|---|---|
| M0-T1 | release-eng | — | none |

**M0-T1.** From the repo root, record the pre-change baseline into the branch's own notes (not into
any committed artifact): `luacheck .`, `lua5.1 tests/run.lua`,
`lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .`. Today's values are `0 warnings / 0 errors in 27
files`, `763 passed, 0 failed, 0 skipped, 763 total`, and `12122 NLOC / 1472 functions / max CCN 15
/ 0 warnings`. Branch from `main`.

**Checkpoint C0 (human).** Confirm the baseline matches those numbers. If it does not, the tree has
moved since this review and the findings need re-checking against it before anything is edited.

---

## Milestone M1 — correctness (the three behaviour fixes)

**Done when:** C-01, C-02 and C-03 are implemented, the suite is green at its new count, and
`docs/test-cases.md` plus the README `[tests]` badge have moved **in the same commits**.

| Task | Role | Implements | Files touched |
|---|---|---|---|
| M1-T1 | wow-api-migrator | C-01 (F-001) | `core/LSMPatch.lua`, `settings/PanelEditor.lua`, `tests/test_panel.lua`, `docs/test-cases.md`, `README.md` |
| M1-T2 | lua-refactorer | C-02 (F-002) | `modules/Registry.lua`, `tests/test_registry.lua`, `docs/test-cases.md`, `README.md` |
| M1-T3 | lua-refactorer | C-03 (F-003) | `core/Util.lua`, `tests/test_util.lua`, `docs/test-cases.md`, `README.md` |

**Concurrency.** M1-T1, M1-T2 and M1-T3 have **disjoint source files** and are
**parallelizable** on that axis. They are **not** parallel on `docs/test-cases.md` and `README.md`:
all three move the pass count, and the inventory is a generated whole-file rewrite. Serialize the
regeneration — each task runs `lua5.1 tests/run.lua --list > docs/test-cases.md` and updates the
badge **as the last step of its own commit**, and the tasks land one after another. Two tasks
regenerating concurrently produce a conflicted inventory that a human then has to hand-resolve,
which is exactly what the generated-file rule exists to prevent.

**Ordering note.** M1-T1 touches `settings/PanelEditor.lua`, which M2-T1 (C-05) rewrites wholesale.
M1-T1 **must land before** M2-T1. See the critical path below.

**Checkpoint C1 (human).** Suite green at the new count; inventory and badge agree with it; run the
C-01, C-02 and C-03 sections of `03_SMOKE_TESTS.md` in-client **before** M2 begins. C-01 in
particular cannot be verified headlessly at all — it needs a second addon installed — and it is the
only High finding, so it should not be sitting unverified underneath a large refactor.

---

## Milestone M2 — structure and hygiene

**Done when:** C-04, C-05, C-06 and C-07 are implemented, the suite is green, and no file in the
repo is above 1000 LOC except by deliberate record.

| Task | Role | Implements | Files touched |
|---|---|---|---|
| M2-T1 | lua-refactorer | C-05 (F-005) | `settings/PanelEditor.lua` → + 2–3 siblings under `settings/`, `PanelMaster.toc` |
| M2-T2 | lua-refactorer | C-06 (F-006) | `modules/Canvas.lua`, `tests/test_canvas.lua`, `docs/test-cases.md`, `README.md` |
| M2-T3 | test-hardening | C-04 (F-004) | `core/Database.lua`, `tests/test_database.lua`, `tests/wow_mock.lua` |
| M2-T4 | docs | C-07 (F-007) | `settings/OptionsSetup.lua` |

**Concurrency.**
- M2-T1 and M2-T2 touch disjoint files (`settings/` vs `modules/Canvas.lua`) — **parallelizable**,
  except that M2-T2 moves the pass count and M2-T1 does not, so only M2-T2 regenerates the
  inventory.
- M2-T3 touches `tests/wow_mock.lua`, which **every** suite loads. It changes the mock's TOC version
  handling, so it can perturb any case that reads a version. Run it **serialized against M2-T2**
  rather than beside it, so a failure has one candidate cause.
- M2-T4 is a comment-only edit to a file nothing else in this milestone touches —
  **parallelizable with everything**.
- **M2-T1 must not start until M1-T1 has landed** (both edit `settings/PanelEditor.lua`).

**Note on M2-T3.** Its point is not the one-line source change; it is that
`tests/test_database.lua:160` currently asserts against the same constant the code reads and
therefore cannot fail. Do not sign the task off on a green run — sign it off on a **demonstrated
red**: revert `core/Database.lua` to `NS.version` with the new mock in place and confirm the case
goes red, then restore.

**Checkpoint C2 (human).** Suite green; `wc -l settings/*.lua modules/*.lua core/*.lua` shows
`settings/PanelEditor.lua` out of the 1000–1500 band; run the C-04, C-05 and C-06 sections of
`03_SMOKE_TESTS.md`. C-05 is a large mechanical move and its smoke section is the only thing that
proves no builder was left behind.

---

## Milestone M3 — upstream (**cross-repo; does not edit this addon**)

**Done when:** the LibKa0s repo's working tree agrees with its own line-ending pin.

| Task | Role | Implements | Files touched |
|---|---|---|---|
| M3-T1 | release-eng | U-01 (F-011) | **`../LibKa0s` only** — `LibKa0s/DebugLog.lua`, `LibKa0s/Pool.lua` |

**Handoff.** Raise this in the **LibKa0s** repo, not here. The fix is
`git add --renormalize .` against that repo's own `.gitattributes`; the content of both files is
already byte-identical to this addon's vendored copies once CR is stripped, so there is **no source
change**, **no LibStub minor bump**, and **no behavioural difference for any consumer**.

**Exit criterion.** Normally an upstream milestone exits on a **re-vendor commit** in this addon.
This one does not, and the difference is worth stating: the vendored bytes under `libs/LibKa0s/`
are **already correct** — the divergence is in the source repo's checkout, not in the payload. So
the exit criterion here is *the LibKa0s commit exists*, and the correction reaches this addon
incidentally on the next scheduled re-vendor, whenever that happens for its own reasons.

**Explicitly forbidden.** No edit under `libs/LibKa0s/` in this repo, for any reason, at any point in
this plan. A local patch is reverted by the next whole-folder copy, and the reversion then reads as
a regression with no commit anywhere in this addon's history behind it.

**Not blocking.** M3 is independent of M0–M2 and can run at any time, by anyone, in parallel.

---

## Milestone M4 — evidence and release hygiene

**Done when:** the deferred evidence items are recorded as scheduled, not done ad hoc.

| Task | Role | Implements | Files touched |
|---|---|---|---|
| M4-T1 | standards-audit | F-010 | whole repo (`git add --renormalize .`) |
| M4-T2 | release-eng | F-008 | `docs/automated-tests/` — **at the next release only** |

**M4-T1** is the line-ending renormalisation for the five straggler files. It must be **its own
commit**, landing after M2, because it rewrites the checkout representation of files M1 and M2 also
touch and would otherwise bury a real diff under a whole-file line-ending change. It belongs to
`/wow-addon:standards-audit`, which owns the authoritative count.

**M4-T2** is **not a task to execute now.** `docs/automated-tests/RESULTS.md` is regenerated in place
by `/wow-addon:bump-version` at release (`automated-tests-§3`). Do not run the recorder as part of
this work, do not hand-edit the table, and do not gate any commit on complexity — a complexity gate
on commits is a documented anti-pattern, not a remedy. The expected movement at that release: pass
count up by however many cases M1 and M2 added, NLOC roughly flat, `settings/PanelEditor.lua` no
longer the largest file, max CCN unchanged at 15.

---

## Critical path and concurrency map

```
M0-T1
  |
  +-- M1-T1 (LSMPatch + PanelEditor) ----+
  +-- M1-T2 (Registry)                   |   parallel on source,
  +-- M1-T3 (Util)                       |   SERIALIZED on docs/test-cases.md + README badge
                                         |
                                    [C1: human + in-client C-01/02/03]
                                         |
                                         v
                              M2-T1 (PanelEditor split)   <-- BLOCKED BY M1-T1 (same file)
                              M2-T2 (Canvas)              <-- parallel with M2-T1
                              M2-T3 (Database + wow_mock) <-- serialize after M2-T2 (mock is global)
                              M2-T4 (OptionsSetup comment)<-- parallel with everything
                                         |
                                    [C2: human + in-client C-04/05/06]
                                         |
                                         v
                                     M4-T1 (renormalise, own commit)

M3-T1 (LibKa0s repo)  ---- fully independent, any time, different repo ----
M4-T2 (RESULTS.md)    ---- deferred to the next release, not executed here ----
```

**File-collision callouts.**

| File | Tasks | Resolution |
|---|---|---|
| `settings/PanelEditor.lua` | M1-T1, M2-T1 | **Must serialize.** M1-T1 first — M2-T1 moves the code M1-T1 edits |
| `docs/test-cases.md`, `README.md` | M1-T1, M1-T2, M1-T3, M2-T2 | **Must serialize.** Generated whole-file; each task regenerates as the last step of its own commit |
| `tests/wow_mock.lua` | M2-T3 | Loaded by every suite — serialize against M2-T2 so a failure has one cause |
| `core/LSMPatch.lua` | M1-T1 | Sole owner |
| `modules/Registry.lua` | M1-T2 | Sole owner |
| `core/Util.lua` | M1-T3 | Sole owner |
| `modules/Canvas.lua` | M2-T2 | Sole owner |
| `settings/OptionsSetup.lua` | M2-T4 | Sole owner |
| `libs/**`, `tests/_kit/**` | **none** | Read-only. Any diff here is a mistake, not a task |

---

## Commit strategy

One commit per task, each self-contained and green.

| Task | Suggested message |
|---|---|
| M1-T1 | `fix(settings): the border-dropdown fixup stops editing the shared AceGUI registry` — body cites F-001, names the four sibling addons carrying the same wrapper, and states that the visual outcome inside this addon is unchanged |
| M1-T2 | `fix(registry): DeleteAll clears the preview flag with the ids it belongs to` — cites F-002 and quotes `dropSessionIDs`' own comment as the argument |
| M1-T3 | `fix(util): a byte colour with a shorthand alpha parses as opaque` — cites F-003, gives `255,0,0,1` as the worked example |
| M2-T1 | `refactor(settings): peel PanelEditor along its own section boundaries` — cites F-005 and `layout-§1`; states explicitly that no behaviour changes and that no CCN threshold was involved |
| M2-T2 | `perf(canvas): the mouseover ticker unhooks when nothing is tracked` — cites F-006; **claims no number**, because the addon ships no perf harness by ratified decision |
| M2-T3 | `fix(db): the Init summary resolves the version through the Env seam` — cites F-004 and says the test change is the load-bearing half |
| M2-T4 | `docs(options): correct the skipRestoreAll rationale` — cites F-007 |
| M3-T1 | *(in the LibKa0s repo)* `chore: renormalise DebugLog.lua and Pool.lua to the repo's line-ending pin` |
| M4-T1 | `chore: renormalise line endings to the .gitattributes pin` — nothing else in the commit |

Every commit that moves the pass count carries `docs/test-cases.md` and the README `[tests]` badge
**in the same commit** (`testing-§7`). No commit hand-edits a generated file, weakens or deletes a
test to reach green, or touches `docs/perf-analysis/`, `docs/automated-tests/` or anything under
`libs/`.
