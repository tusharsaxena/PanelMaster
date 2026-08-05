# PanelMaster — execution plan (2026-08-05)

Implements `02_PROPOSED_CHANGES.md`. Ten changes, four milestones. No `[upstream]` findings were
raised, so there is **no** cross-repo milestone and **no** re-vendor commit in this plan; nothing
below touches `libs/` or `tests/_kit/`.

---

## Milestone M1 — the degradation seam (the only user-visible defect)

**Done when:** a degraded install (`libs/LibKa0s` renamed away) survives the full panel CLI and
answers `/pm config` on every invocation, and the suite has a case that would have caught the
original crash.

| Task | Owner-agent role | Implements | Files touched |
|---|---|---|---|
| M1-T1 | lua-refactorer | C-01 (F-001) | `settings/Slash.lua` |
| M1-T2 | test-author | C-01 coverage | `tests/test_libka0s.lua` |
| M1-T3 | ux-cleanup | C-04 (F-007) | `settings/OptionsSetup.lua` |
| M1-T4 | lua-refactorer | C-03 (F-003) | `core/DebugLogSetup.lua` |

**Concurrency:** M1-T1, M1-T3 and M1-T4 touch three disjoint files — **parallelizable**. M1-T2 must
follow M1-T1 (it asserts the members that task adds).

**Order note:** write M1-T2 to go **red first** against the unpatched `settings/Slash.lua`, then
apply M1-T1. A degradation case that was never seen red is the shape `testing-§12` warns about.

---

## Milestone M2 — guards and tests that can actually fail

**Done when:** `Schema:Register` reports an unresolvable path whose row carries a default, a test
pins that it does, and the vendor-sync pair no longer prints an unqualified PASS when it verified
nothing.

| Task | Owner-agent role | Implements | Files touched |
|---|---|---|---|
| M2-T1 | lua-refactorer | C-02 (F-002) | `settings/Schema.lua` |
| M2-T2 | test-author | C-02 coverage | `tests/test_schema.lua` |
| M2-T3 | test-author | C-06 (F-005) | `tests/test_vendor_sync.lua` |

**Concurrency:** M2-T3 is disjoint from M2-T1/T2 — **parallelizable**. M2-T2 follows M2-T1.

**Serialization against M1:** none of these files overlaps M1's. M1 and M2 may run in parallel if
two agents are available; M2-T2 and M1-T2 both regenerate the test inventory, so whichever lands
second owns the regeneration (see the checkpoint below).

---

## Milestone M3 — correctness and consistency

**Done when:** the profile-switch path says what it does, the mouseover ticker cannot spam, and the
settings message registers through its published constant.

| Task | Owner-agent role | Implements | Files touched |
|---|---|---|---|
| M3-T1 | lua-refactorer | C-05 (F-004) | `core/Database.lua`, possibly `tests/test_profiles.lua` |
| M3-T2 | lua-refactorer | C-07 (F-006) | `modules/Canvas.lua` |
| M3-T3 | lua-refactorer | C-08 (F-011) | `modules/Canvas.lua` |

**Concurrency:** **M3-T2 and M3-T3 both touch `modules/Canvas.lua` → must serialize.** Do them as
one task if the same agent takes both; they are seven lines apart. M3-T1 is disjoint —
**parallelizable** with either.

**Watch:** M3-T1 must first read `tests/test_profiles.lua` for a case asserting `RunMigrations` is
reached from a profile switch. If one exists it is asserting the no-op and moves with the change —
it does not get deleted to make the suite green.

---

## Milestone M4 — tidy-up and the inventory

**Done when:** the comments describe the code, the dead export is resolved, `docs/test-cases.md` and
the README `[Tests]` badge match a fresh `--list`, and all four out-of-game suites are re-run clean.

| Task | Owner-agent role | Implements | Files touched |
|---|---|---|---|
| M4-T1 | doc-cleanup | C-09 (F-009, F-010) | `core/CoreSetup.lua`, `tests/test_vendor_sync.lua` |
| M4-T2 | lua-refactorer | C-10 (F-012, F-008) | `settings/Panel.lua`, `core/CoreSetup.lua` |
| M4-T3 | release-hygiene | inventory + badge | `docs/test-cases.md`, `README.md` |

**Concurrency:** **M4-T1 and M4-T2 both touch `core/CoreSetup.lua` → must serialize.**
**M4-T1 and M2-T3 both touch `tests/test_vendor_sync.lua` → must serialize** (M2-T3 first; M4-T1 is
a comment edit on the header the rename may have already reflowed). M4-T3 is last, always.

**M4-T3 is mechanical and must not be hand-written:**
```
lua5.1 tests/run.lua --list > docs/test-cases.md
```
then update the README `[Tests]` badge to the count the suite actually printed. Never hand-edit
either number.

---

## Critical path and concurrency map

```
M1-T1 ──► M1-T2 ─────────────┐
M1-T3 (parallel)             │
M1-T4 (parallel)             │
                             ├──► CP-1 ──► M3-T2 ──► M3-T3 ──┐
M2-T1 ──► M2-T2 ─────────────┤            (same file)        ├──► CP-2 ──► M4-T1 ──► M4-T2 ──► M4-T3
M2-T3 (parallel) ────────────┘   M3-T1 (parallel) ───────────┘                (same file)
```

**Shared-file serialization, explicitly:**

- `modules/Canvas.lua` — M3-T2, M3-T3
- `core/CoreSetup.lua` — M4-T1, M4-T2
- `tests/test_vendor_sync.lua` — M2-T3, M4-T1
- `docs/test-cases.md` / `README.md` — M4-T3 only, and only after every other task has landed

Everything not listed above has a disjoint file set and is parallelizable.

---

## Checkpoints

**CP-1 — after M1 and M2, before any refactor.** Human (or coordinator) verifies:
- `luacheck .` clean.
- `lua5.1 tests/run.lua` green, and the pass count has **risen** by the number of cases M1-T2 and
  M2-T2 added. A flat count means a new case did not register.
- The degraded-install repro from `01_FINDINGS.md` F-001 no longer raises. Re-run the same probe.
- **In-client:** `03_SMOKE_TESTS.md` sections C-01 and C-04, both arms. This is the checkpoint the
  user-visible defect is signed off at; do not start M3 before it passes.

**CP-2 — after M3, before the tidy-up.** Human verifies:
- `lua5.1 tests/run.lua` still green at the CP-1 count.
- **In-client:** `03_SMOKE_TESTS.md` sections C-05, C-07, C-08 and regression rows R-1, R-5, R-8.
  C-08 is the one to watch — a mis-ordered constant would show as panels that stop reacting to
  settings changes, which is exactly the bug `core/PanelMaster.lua:57-60` records.

**CP-3 — before the tag.** Not part of this plan's tasks, but stated so it is not missed:
`/wow-addon:bump-version` produces the full `docs/automated-tests/<stamp>/` bundle and evaluates the
release gate (all four suites, plus `suites.complexity.warnings == 0`). Today's baseline is
706/706, 0 lint, 0 CCN warnings, max CCN 15 — the bundle after this work should show a higher test
count and an unchanged complexity picture. Do **not** regenerate a bundle as part of any task above;
`automated-tests-§6` puts it at release, never at a commit.

---

## Incremental commit strategy

One commit per task, each independently revertable. Suggested messages:

| Task | Message |
|---|---|
| M1-T1 | `slash: the degradation stub answers FormatKV, so /pm panel works without LibKa0s` |
| M1-T2 | `tests: the Slash stub gets the member sweep the console stub already had` |
| M1-T3 | `options: a degraded /pm config answers every time, not once` |
| M1-T4 | `debuglog: the degraded ack speaks plainly instead of copying the library's string` |
| M2-T1 | `schema: Register reports an unresolvable path even when the row has a default` |
| M2-T2 | `tests: Register's zero gets the falsifying twin it never had` |
| M2-T3 | `tests: the vendor-sync pair names its skip instead of printing a bare PASS` |
| M3-T1 | `database: drop the profile-switch migration call that could never run, and say why` |
| M3-T2+T3 | `canvas: guard the ticker's Unlock reach and register the settings message by constant` |
| M4-T1 | `docs: two comments that outlived their subject` |
| M4-T2 | `panel: one AceGUI on the settings pages; drop the unread NS.Format export` |
| M4-T3 | `tests: regenerate the case inventory and move the badge` |

M4-T3 must be in the **same** change as whichever commit last moved the pass count if the project
prefers a single atomic move; the standard requires the inventory and badge to move with the change
that moved the count, not as a deferred follow-up. Squashing M1-T2, M2-T2 and M4-T3 into their
respective code commits also satisfies it and is the tidier option.
</content>
