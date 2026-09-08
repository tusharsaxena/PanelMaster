# 05 — Execution plan (2026-09-08)

The hand-off to the remediation engagement. Ordered, checkable, each step tied to its deviation ID.
Design rationale is in `04_TECHNICAL_DESIGN.md`; evidence is in `03_EVIDENCE.md`.

**Counts this plan is written against** — reconciled with `02_DEVIATIONS.md`, which is read as one
document with this file (`03_EVIDENCE.md` § 10):

- **Headline tally, roots only: 4** — `PM-030`, `PM-031`, `PM-032`, `PM-033`.
- **Total including dependents: 5** — the four plus `PM-032a`.
- **MUST failures, roots only: 3** — `PM-030`, `PM-031`, `PM-032`.
- By grade, roots: **High 0 · Medium 0 · Low 3 · Info 1**.

**Two of the four are new only because the standard moved.** `PM-031` and `PM-032` measure rules
v2.39.0 turned from judgment into a published count. Neither is a regression in this addon.

**Prior run: 8 roots, 9 including dependents. Seven of the eight are closed** and one — `PM-030` —
persists as a documented deferral. **Nothing scheduled to close in the 2026-09-07 cycle is open.**

**Read-only boundary.** This audit changed no addon file. Everything below is work for the follow-up
engagement.

---

## Sprint 1 — the doc the trigger now demands (`PM-031`)

Smallest, most self-contained, and the one an outside reader of `docs/` notices first. No code.

| # | Step | Files | Done when |
|---|---|---|---|
| 1.1 | Write `docs/compat-layer.md` to `04_TECHNICAL_DESIGN.md`'s three-part shape — the layer's contract, one subsection per shim with *what varies / absent-API answer / callers*, and a one-line pointer saying the TOC-metadata reader is `LibKa0s-Env-1.0`'s and is deliberately not re-documented here. | `docs/compat-layer.md` (new) | The page names all **8** shims — `AddOnFolders`, `GetScreenSize`, `GetUIScale`, `InCombat`, `RegisterMedia`, `FetchMedia`, `MediaList`, `MouseIsOver` — and every *Callers* cell is filled from a real grep, not from memory. |
| 1.2 | Change the map row from *Not applicable* to *Present*, carrying the count and the threshold. | `docs/ARCHITECTURE.md:145` | The row reads `\| \`compat-layer.md\` \| Present \| 8 shims in \`core/Compat.lua\` (threshold is 3) \|`, matching the form of the `slash-dispatch.md` row at `:140`. |
| 1.3 | Re-run the trigger grep and confirm the row's number is the file's number. | — | `grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua` → `8`, equal to what `:145` claims. |
| 1.4 | **Optional, recommended.** Add a case to `tests/test_docs.lua` asserting the shim count equals the number of shim subsections in `docs/compat-layer.md`. | `tests/test_docs.lua` | The case fails when a ninth `function Compat.` is added without a subsection, and fails when a subsection is added for a shim that does not exist. Verified red under both mutations. |
| 1.5 | Green gate. | — | `lua tests/run.lua` and `luacheck .` both clean. |

**Do not** add a `## Documented deviations` row for this. A Tier 2 doc whose trigger has fired is a
doc that is owed, not a deviation to ratify (`documentation-§3`).

---

## Sprint 2 — the spelling gate, then the word it finds (`PM-032`, `PM-032a`)

**One change, in this order.** Widening the gate before fixing the word is what makes the suite the
proof rather than a reviewer's eye. Steps 2.1–2.4 land together; 2.5 is the same commit.

| # | Step | Files | Done when |
|---|---|---|---|
| 2.1 | Replace the private `BRITISH` table with `localization-§5`'s published one, copied **whole** — all **91** entries, as plain string literals, dropping the `"colo" .. "ur"` half-word trick (§5 exempts the gate's own copy of the lists). | `tests/test_spelling.lua:41-59` | The table is textually equal to the published list. **No entry is added, removed or re-spelled locally.** |
| 2.2 | Add `localization-§5`'s `ALLOWED` list, all **30** entries, and delete the `-is`-suffix heuristic. | `tests/test_spelling.lua:71-79` | `hits()` is gone; the scan delimits on non-letters, drops `ALLOWED` tokens **as whole words** with a length-preserving substitution, then runs `BRITISH` as substrings over what remains. |
| 2.3 | Widen `authoredFiles()`'s doc set from the hand-named list to every tracked `.md` under `docs/` plus the three root documents, naming each exclusion **directory by directory in the gate itself**: `docs/audits/`, `docs/reviews/`, `docs/revendor/`, `docs/superpowers/` and the frozen `docs/automated-tests/<run>/` folders — while keeping `automated-tests/README.md` and `RESULTS.md` **in** scope. | `tests/test_spelling.lua:143-147` | The scan covers all **20** live `docs/` pages, up from **5**. Assert the floor in the coverage case: the existing `#paths > 30` check gains named spot-checks for `docs/scope.md`, `docs/schema.md` and `docs/performance.md`, so a broken walk fails loudly instead of scanning less. |
| 2.4 | Extend the matcher case with the canonical `ALLOWED` words, so the swap cannot quietly turn the gate off. | `tests/test_spelling.lua:170-190` | The case asserts `analysis`, `paralysis`, `synthesis`, `emphasis`, `specialist`, `organism`, `optimistic`, `programmer`, `fulfillment` all pass, and `analysed`, `paralysed`, `practise`, `recognise`, `metre`, `learnt` all fail. |
| 2.5 | **`PM-032a`.** `artefact` → `artifact`. | `docs/performance.md:107` | The widened gate goes green. Confirm the ordering held by checking out step 2.5 alone first and watching the suite go **red** — a fix that was never seen failing proves nothing. |
| 2.6 | Green gate, and record the suite delta. | — | `lua tests/run.lua` clean; `luacheck .` clean. The pass count moves by however many cases 2.3/2.4 add — note the number, because the README `[tests]` badge and `docs/test-cases.md` move with it (`documentation-§1` item 2's keep-in-sync MUST). |

**Escalation rule.** If the widened scan reddens on anything beyond `docs/performance.md:107`, each
hit is a real `localization-§5` MUST failure and is fixed in the same commit. If it reddens on a word
that is **correct US English**, the answer is an `ALLOWED` amendment **upstream in
`WowAddonStandards`**, then a re-sync here — never a local subset. `03_EVIDENCE.md` § 6 swept 84
files with the canonical lists and found exactly three hits, two of them in frozen bundles, so the
surprise budget is one word.

---

## Sprint 3 — the wrapped-strip geometry case (`PM-030`)

The oldest open item and the only one that touches test fidelity. Deliberately last: it is the
largest, and the two sprints above are independent of it.

| # | Step | Files | Done when |
|---|---|---|---|
| 3.1 | Give `tests/wow_mock.lua`'s `SetAtlas` a per-atlas height sourced from the kit's `ATLAS_SIZES` (`tests/_kit/mock_base.lua:68`), keeping the arming **opt-in** so no existing case changes behaviour. | `tests/wow_mock.lua` | `lua tests/run.lua` reports the **same** pass count as before the change. An unchanged count is the whole point of an additive mock change. |
| 3.2 | Add the invariance case against the **Panels** page's five tabs, at a container width that forces the strip to wrap to two rows. | `tests/test_panel.lua` | The case first asserts the strip actually wrapped (two rows), then asserts the reserved band height and every row's y offset are equal across all five values of `ctx.activeTab`. |
| 3.3 | **Prove it dies.** Mutate the vendored library, run, confirm red, restore. | `libs/LibKa0s/OptionsWidgets.lua` (temporarily) | Red under `TAB_ATLAS[false][1]` → `TAB_ATLAS[true][1]` at `:447`. Red under deleting the `measuredArtH` assignment at `:452`. Then `git checkout -- libs/LibKa0s/OptionsWidgets.lua` and confirm `diff -r ../LibKa0s/LibKa0s libs/LibKa0s` is empty again — the vendored copy **must not** be left modified (anti-pattern #45). |
| 3.4 | Green gate and the vendor gates. | — | `lua tests/run.lua` clean, including *"libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles"* and *"tests/\_kit is the test kit that shipped with that release"*. |
| 3.5 | Watch the file size. | `tests/test_panel.lua` | Still under 1400, its census re-check threshold (`docs/ARCHITECTURE.md:292`). If it crosses, update that row in the same commit rather than leaving the census stale. |

**Scope note.** The pitch measurement is `LibKa0s`'s and is audited in its own repo. This case is the
**consumer-side** guard `testing-§12` asks for and is not a substitute for the library's own.

---

## Sprint 4 — release hygiene (`PM-033`)

No file changes, and no commit gate.

| # | Step | Files | Done when |
|---|---|---|---|
| 4.1 | At the **next tag** — not before — run `tests/_kit/run-automated-tests.sh` from the repo root, freeze the bundle, and let the runner overwrite `docs/automated-tests/RESULTS.md`. | `docs/automated-tests/` | A new frozen `<stamp>/` bundle whose `manifest.json` `git.sha` is the tag's commit, with `"release"` set. |
| 4.2 | Carry the four `Disposition` cells forward verbatim; leave a **new** band entry's cell blank. | `docs/automated-tests/RESULTS.md` | The `Disposition` column is the only hand-touched cell in the file (`automated-tests-§4`, *the one boundary*). Everything else is the runner's output. |
| 4.3 | Write the release run's `ANALYSIS.md`. | `docs/automated-tests/<stamp>/ANALYSIS.md` | A MUST at a release run (`automated-tests-§5`). Do **not** backfill `20260807-110543` or `20260825-103450` — §5 forbids it, and the forward note already exists at `docs/automated-tests/20260908-181416/ANALYSIS.md:106-109`. |

**Explicitly not in scope:** gating commits on complexity. The checkpoint is release, and
`docs/automated-tests/RESULTS.md:10-16` already states which suites gate what.

---

## Ordering, and what may run in parallel

```
Sprint 1 (PM-031)  ──┐
Sprint 2 (PM-032,     ├── independent of each other; either order, or together
          PM-032a) ──┘
                      └── Sprint 3 (PM-030)   ← last: largest, touches mock fidelity
                            └── Sprint 4 (PM-033) ← at the tag, after all of the above
```

Sprints 1 and 2 have no file in common and no dependency. Sprint 3 is last because it is the only one
that reaches a shared fixture, and doing it under a clean tree makes the *"pass count unchanged"*
assertion in 3.1 meaningful. Sprint 4 is the release, so it comes after everything.

---

## Definition of done for the whole plan

- `docs/compat-layer.md` exists and the map row asserts *Present* with the count.
- `tests/test_spelling.lua` carries `localization-§5`'s two lists **whole**, scans 20 live docs, and
  is green with `docs/performance.md` respelled.
- `tests/test_panel.lua` carries a strip-invariance case that has been **seen red** under both named
  mutations.
- `luacheck .` → 0/0; `lua tests/run.lua` → all green, no skips.
- `diff -r ../LibKa0s/LibKa0s libs/LibKa0s` and `diff -r ../LibKa0s/testkit tests/_kit` both empty.
- The working-tree line-ending count is still **0**, and `tests/_kit/test_eol.lua` is still green.
- **No new `## Documented deviations` row.** Nothing in this plan ratifies a deviation; all four items
  are things to do, not decisions to record.

---

## Deviation → step index

| ID | Grade | Section | Steps |
|---|---|---|---|
| `PM-030` | Low (MUST) | `options-ui-§13`, `testing-§12` | 3.1 – 3.5 |
| `PM-031` | Low (MUST) | `documentation-§3` | 1.1 – 1.5 |
| `PM-032` | Low (MUST) | `localization-§5` | 2.1 – 2.4, 2.6 |
| `PM-032a` | Low (MUST) — *derived from PM-032* | `localization-§5` | 2.5 |
| `PM-033` | Info | `automated-tests-§4` | 4.1 – 4.3 |
