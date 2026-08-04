# Ka0s Panel Master — Execution Plan (2026-08-03 review)

Implements `02_PROPOSED_CHANGES.md`. Four milestones, ordered so the one user-visible defect lands
first and behind a test that would have caught it.

**No upstream milestone exists in this cycle.** No `[upstream]` findings were raised — nothing under
`libs/` or `tests/_kit/` is defective and the vendor-sync gate is green — so there is no cross-repo
handoff and no re-vendor commit. Had there been one, it would be its own milestone with the
re-vendor commit in this repo as its exit criterion, never folded into a task that edits this
addon's files.

**Standing rule for every task:** no task may edit a path under `libs/` or `tests/_kit/`. If an
implementer believes one must, stop and re-open the review — that is an upstream finding that was
missed, not a local edit.

---

## Milestone M1 — The degraded panel CLI (red → green)

**Done when:** `lua tests/run.lua` is green with the two new degraded cases present, and
`03_SMOKE_TESTS.md` §C-01 and §C-02 pass.

| Task | Owner-agent role | Implements | Files touched |
|---|---|---|---|
| **T-1.1** Write the two failing degraded cases first (member sweep + `/pm panel` verbs), plus the "is not the library's function" guard | test-author | C-02 / F-001 | `tests/test_libka0s.lua` |
| **T-1.2** Publish the degraded `FormatKV` from the Slash stub; record the `Sl:Text` decision in the stub's comment | lua-refactorer | C-01 / F-001 | `settings/Slash.lua` |

**Order:** T-1.1 strictly before T-1.2 — the cases must be observed red first (testing-§4). They
touch disjoint files but are **not** parallelizable for that reason.

**Checkpoint CP-1 (human):** confirm the suite went red on T-1.1 and green on T-1.2, and that the
degraded `FormatKV` is visibly not a copy of the library's rendering. This is the finding the whole
review turns on; do not proceed past it on a green-only report.

---

## Milestone M2 — The `Sanitize` contract

**Done when:** the "every template field is normalized" property test passes, and
`03_SMOKE_TESTS.md` §C-03-a and §C-03-b pass in-client.

| Task | Owner-agent role | Implements | Files touched |
|---|---|---|---|
| **T-2.1** Add the property test asserting `Sanitize` fills every `C.PANEL_TEMPLATE` key | test-author | C-03 / F-002 | `tests/test_registry.lua` |
| **T-2.2** Normalize `artBlend` (via `enumMatch`) and `artDesaturate` in `Registry.Sanitize` | lua-refactorer | C-03 / F-002 | `modules/Registry.lua` |

**Order:** T-2.1 before T-2.2, same reason as M1.

**Concurrency:** M2 is fully **parallelizable with M1** — disjoint file sets
(`modules/Registry.lua` + `tests/test_registry.lua` vs. `settings/Slash.lua` +
`tests/test_libka0s.lua`). If run in parallel, merge M1 first so CP-1 is not delayed.

**Checkpoint CP-2 (human):** verify in-client that a healthy profile's `artBlend = ADD` survives a
`/reload` (§C-03-b). A repair that also resets legitimate values is worse than the defect.

---

## Milestone M3 — Dead surface

**Done when:** `luacheck .` is 0/0, `lua tests/run.lua` is green, and `03_SMOKE_TESTS.md` §C-04 and
§C-05/§C-06 pass.

| Task | Owner-agent role | Implements | Files touched |
|---|---|---|---|
| **T-3.1** Resolve `SunnArt.Installed()` — recommended: rename to `S.__installed` and trim the comment | lua-refactorer | C-04 / F-003 | `modules/SunnArt.lua`, `tests/test_sunnart.lua` |
| **T-3.2** Delete `C.MEDIA_FALLBACK` | lua-refactorer | C-05 / F-006 | `core/Constants.lua` |
| **T-3.3** Delete `NS.Format` (or publish it from the stub too — decide, don't drift) | lua-refactorer | C-06 / F-007 | `core/CoreSetup.lua` |

**Concurrency:** T-3.1, T-3.2 and T-3.3 touch **disjoint** files and are all **parallelizable** with
each other. All three are parallelizable with M4.

**Serialization note:** T-3.3 touches `core/CoreSetup.lua`, which **no** other task in this plan
edits — but if the reviewer chooses the "publish from the stub" option instead of deleting, that
task must land **after** CP-1, because it is the same stub-symmetry judgment CP-1 signs off.

---

## Milestone M4 — Documentation and naming

**Done when:** `03_SMOKE_TESTS.md` §C-07, §C-08, §C-09 and §C-10 pass, and the spelling suite
(`tests/test_spelling.lua`) is still green over the edited prose.

| Task | Owner-agent role | Implements | Files touched |
|---|---|---|---|
| **T-4.1** Replace the retired `runic-sigil` id in the README and the smoke-test doc | docs-editor | C-07 / F-004 | `README.md`, `docs/smoke-tests.md` |
| **T-4.2** Correct the `/pm panel set …` grammar in four comments and one doc line | docs-editor | C-08 / F-005 | `core/Util.lua`, `core/Constants.lua`, `modules/Artwork.lua`, `docs/smoke-tests.md` |
| **T-4.3** Add the missing bus consumer to the architecture doc | docs-editor | C-09 / F-008 | `docs/ARCHITECTURE.md` |
| **T-4.4** Rename the `w`/`h` width-or-reason variables at both call sites | ux-cleanup | C-10 / F-009 | `settings/Slash.lua`, `settings/PanelEditor.lua` |

---

## Critical-path / concurrency map

**Serialize — shared files:**

- **T-1.2 and T-4.4 both touch `settings/Slash.lua`.** T-4.4 edits lines 152-160 (the `fitart`
  branch), which call `Sl.FormatKV` — the very member T-1.2 adds. **T-1.2 must land first**; T-4.4
  then rebases onto it. Running them concurrently produces a conflict in the same hunk.
- **T-4.2 touches `docs/smoke-tests.md` (line ~296) and T-4.1 touches it too (line ~223).** Different
  hunks, but the same file — **serialize** T-4.1 → T-4.2 rather than merging two branches over one
  doc.
- **T-4.2 touches `core/Constants.lua` (two comment lines) and T-3.2 deletes `C.MEDIA_FALLBACK` from
  it.** Different regions; still **serialize** — T-3.2 → T-4.2 — because a doc edit reverting a
  deletion is the classic silent regression.

**Parallelizable — disjoint file sets:**

- M1 (`settings/Slash.lua`, `tests/test_libka0s.lua`) ∥ M2 (`modules/Registry.lua`,
  `tests/test_registry.lua`).
- T-3.1 (`modules/SunnArt.lua`, `tests/test_sunnart.lua`) ∥ T-3.3 (`core/CoreSetup.lua`) ∥ T-4.3
  (`docs/ARCHITECTURE.md`).

**Critical path:** T-1.1 → T-1.2 → **CP-1** → T-4.4 → CP-4. Everything else can be scheduled around
it.

---

## Checkpoints

| ID | After | The human verifies |
|---|---|---|
| **CP-1** | M1 | The new cases went **red** before T-1.2 and green after; the degraded `FormatKV` is not a copy of the library's rendering (slash-commands-§1); §C-01 passes in the degraded install. |
| **CP-2** | M2 | §C-03-b — a healthy profile's chosen `artBlend`/`artDesaturate` survive a reload unchanged. |
| **CP-3** | M3 | `luacheck .` 0/0 and the suite green after each deletion; `/reload` clean in both the normal and the degraded install. |
| **CP-4** | M4 | Every command in the README's Usage section is typed verbatim in-client and none is refused; `tests/test_spelling.lua` green (localization-§5 — US English in all edited prose). |
| **CP-5** | Final | The whole of `03_SMOKE_TESTS.md` signed off, including the regression table. Only then is the review closed. |

---

## Incremental commit strategy

One commit per task; each commit must be independently green (`lua tests/run.lua` + `luacheck .` —
versioning-git's commit-only-on-green gate). Suggested messages:

| Task | Message |
|---|---|
| T-1.1 | `test(slash): pin the degraded stub's member set and every /pm panel verb (F-001)` |
| T-1.2 | `fix(slash): the degraded stub must answer FormatKV — /pm panel crashed without LibKa0s (F-001)` |
| T-2.1 | `test(registry): assert Sanitize normalizes every template field (F-002)` |
| T-2.2 | `fix(registry): Sanitize artBlend and artDesaturate like every other art field (F-002)` |
| T-3.1 | `refactor(sunnart): Installed() has no production caller — name it as the test seam it is (F-003)` |
| T-3.2 | `chore(constants): drop C.MEDIA_FALLBACK, which nothing reads (F-006)` |
| T-3.3 | `chore(core): drop NS.Format, published with no callers and absent from the stub (F-007)` |
| T-4.1 | `docs: the artwork example named a catalog id that no longer exists (F-004)` |
| T-4.2 | `docs: /pm panel takes no 'set' sub-verb — correct four comments and one smoke step (F-005)` |
| T-4.3 | `docs(architecture): the Panels page is a second consumer of PanelChanged (F-008)` |
| T-4.4 | `refactor(slash): name the width-or-reason returns for what they are (F-009)` |

**Branching:** work trunk-based on `master` (versioning-git; anti-pattern #21 — do not create a
topic branch unless the user explicitly asks). Do not push or tag; the release decision is the
user's.
