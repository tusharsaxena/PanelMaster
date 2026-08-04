# 05 — Execution plan (2026-08-04)

Ordered remediation steps for the deviations in `02_DEVIATIONS.md`, designed in
`04_TECHNICAL_DESIGN.md`. This is the hand-off to a separate remediation engagement — **the audit
changed no code.**

Every step ends green: `lua tests/run.lua` all passing **and** `luacheck .` at 0 warnings / 0 errors.
Work trunk-based on `master`; do not branch unless asked; do not push.

---

## Sprint 0 — Decide, before any code (PM-001 … PM-006, PM-012)

| # | Step | IDs | Done when |
|---|---|---|---|
| 0.1 | Put the `Perf` question to the user, framed as `CLAUDE.md`'s own three-way choice: **(a)** accepted deviation, **(b)** a change to `performance-§1` upstream, or **(c)** implement. Bring the ledger's argument (`docs/pending/LEDGER.md:117`) as the input, and this bundle's PM-001 … PM-006 / PM-012 as the cost of (c). | PM-001, PM-002, PM-003, PM-004, PM-005, PM-006, PM-012 | A recorded decision. |
| 0.2 | **If (a):** record the classification in `docs/pending/LEDGER.md` and add a one-line pointer in `docs/ARCHITECTURE.md` so the next audit reads the decision instead of re-deriving it. Close the seven IDs as *accepted*. **Skip Sprint 3 entirely.** | same | The ledger row cites this bundle by date, and `CLAUDE.md:34` still says `Perf` is declined. |
| 0.3 | **If (b):** raise the amendment in `WowAddonStandards` (that repo, not this one), then re-audit against the new version. **Skip Sprint 3.** | same | The standard's version has moved and a fresh `docs/audits/<date>/` measures against it. |
| 0.4 | **If (c):** proceed to Sprint 3 as written. | same | — |

Sprint 0 is first because Sprint 3 is by far the largest body of work in the bundle and it is
entirely contingent on this answer. Everything in Sprints 1, 2 and 4 is independent of it and can
proceed in parallel.

---

## Sprint 1 — Fix the live crash (PM-007)

Highest value per line changed in the whole bundle: this is a user-visible error today in any
install where `libs/LibKa0s` is missing or failed to extract.

| # | Step | IDs | Done when |
|---|---|---|---|
| 1.1 | **Write the failing test first.** Add a case in the degraded block of `tests/test_libka0s.lua` (beside `:480+`) that drives `/pm panel <name>`, `Sl:BuildPanelShowLines`, `/pm panels` and `panel <name> fitart` through the real `loadDegraded()` environment. Confirm it goes **red** with `settings/Slash.lua:101: attempt to call field 'FormatKV' (a nil value)`. | PM-007 | Red, with that exact error. |
| 1.2 | Add `Sl.FormatKV` **inside** the stub branch (`settings/Slash.lua`, before the `return` at `:304`) as a deliberately plain `k = v` line. **Do not** hoist `lib.FormatKV`, and **do not** copy the library's `\|cFFFFFF00…\|r` escapes — that is anti-pattern #47. Comment the reason on the line. | PM-007 | 1.1 goes green. |
| 1.3 | Add the guard case: the degraded `FormatKV` is **not** the same function value as `lib.FormatKV`. This is what reddens the tempting wrong fix. | PM-007 | Green, and provably red if 1.2 is replaced by a hoist. |
| 1.4 | Regenerate `docs/test-cases.md` (`lua tests/run.lua --list > docs/test-cases.md`) and update the README `[tests]` badge X/Y in the same commit. | PM-007 | `docs/test-cases.md` total, the run's total and `README.md:6` all agree. |
| 1.5 | Green gate; commit as one `fix(slash):` change. | PM-007 | Tests green, lint 0/0. |

---

## Sprint 2 — Documentation (PM-009, PM-010, PM-011)

No code, no ordering constraints, safe to run alongside Sprint 1.

| # | Step | IDs | Done when |
|---|---|---|---|
| 2.1 | `README.md:489-493` — add the **Date** column, rename `Notes` → `Highlights`, keep most-recent-first. | PM-009 | The table reads `\| Version \| Date \| Highlights \|`. |
| 2.2 | `README.md:143` — insert a `\| Tab \| Covers \|` table (one row per settings subcategory) above the existing per-setting rows; keep those rows as the sanctioned follow-on prose. | PM-010 | Both tables present, in that order. |
| 2.3 | Run `lizard` over the addon's source excluding `libs/`; commit the output as `docs/complexity.md` with a header stating it is generated and by what command. Do **not** gate anything on it. | PM-011 | The file exists and names its own generator. If `lizard` is unavailable locally, record that and defer — an absent tool means a stale report, not non-compliance. |
| 2.4 | Green gate; commit as one `docs:` change. | PM-009, PM-010, PM-011 | Tests green, lint 0/0. |

---

## Sprint 3 — Adopt `LibKa0s-Perf-1.0` — **only if Sprint 0 chose (c)**

Ordered so that lint and the gate stay green at every commit boundary.

| # | Step | IDs | Done when |
|---|---|---|---|
| 3.1 | **Lint and TOC first.** `.luacheckrc`: `"debugprofilestop"` → `read_globals`, `"PanelMasterPerfDB"` → `globals` with a comment. `PanelMaster.toc:7` → `## SavedVariables: PanelMasterDB, PanelMasterPerfDB`. These land **before** the first bracket so lint never goes red between commits. | PM-003, PM-006 | `luacheck .` 0/0; TOC declares two globals in the mandated order. |
| 3.2 | Add `core/PerfSetup.lua`: guarded `LibStub("LibKa0s-Perf-1.0", true)`, the descriptor (`name`, `version`, `svName`, `print`/`debug` forwarders, `buckets`, `suspend`/`resume`), and a member-answering stub. List it in the TOC's `# Core` block after `core/DebugLogSetup.lua` and before `modules/Canvas.lua`, with the ordering constraint written beside the line as this TOC already does at `:42-48`. | PM-001 | The addon loads with and without the lib; a test pins the descriptor is well-formed. |
| 3.3 | Add the three brackets — `renderAll`, `renderPanel` (`within = "renderAll"`), `mouseoverTick` — using the mandated idiom **verbatim**, with `local Perf = NS.Perf` as a load-time upvalue. Nothing may be allocated, concatenated or formatted inside a bracket while capture is off. | PM-001 | Each declared bucket is reached by a real bracket, pinned by a test that drives each genuine entry point. |
| 3.4 | Implement `suspend`/`resume`. Enforce inertness **at the source** — one early return in `Canvas`'s show ladder gated on a session-only flag — never by hiding frames. Rebuild registrations from current state on resume. Never persist the flag. | PM-012 | A test asserts events unregistered, ticker stopped, ladder refusing while suspended, and correct restoration after a setting changed *during* suspend. |
| 3.5 | Add the `perf` triple to `NS.COMMANDS` beside `debug`; the host prints the library's returned lines through `NS.Print`. Add the matching row to the README `### Slash commands` table in the **same** commit — the help index and landing page regenerate themselves, the README does not. | PM-002 | `/pm perf` opens the guided step panel; `/pm help`, the landing page and the README agree. |
| 3.6 | Extend the degraded-path suite: load the addon with `Perf.lua` deliberately absent from the load list and assert every surface answers rather than erroring. **Never** hand-stub `NS.Perf`. | PM-001, PM-012 | The degraded case exercises the real fallback, per `testing-§8`. |
| 3.7 | Add `tests/perf.lua`: TOC-derived load list, outside the gate, never called from `tests/run.lua`, asserting only on call counts and bytes allocated. Ship the mandatory **zero-overhead scenario** over `Canvas:Render` with capture off. Add a gated case that reads `tests/perf.lua`'s source to pin its derivation call. | PM-004 | `lua tests/perf.lua` runs; `lua tests/run.lua` does **not** run it; its scenarios are excluded from the inventory and the badge. |
| 3.8 | Prove every negative assertion added in 3.3, 3.4 and 3.6 can fail: mutate the implementation, watch the case go red, revert from a `cp` backup (**never** `git checkout` — the work is uncommitted). Record the mutation in a one-line comment on each case. | PM-001, PM-012 | Each negative case carries a `-- red under: …` comment. |
| 3.9 | Write `docs/performance.md` and `docs/perf-runs/README.md`; add the ungated-runner line to `docs/testing.md`. | PM-005 | Both required topic-detail docs exist and point at the library's contract rather than restating it. |
| 3.10 | Regenerate `docs/test-cases.md` and update the README `[tests]` badge. Green gate; commit the sprint as a small series (`feat(perf):` for 3.2–3.5, `test(perf):` for 3.6–3.8, `docs(perf):` for 3.9). | all Sprint 3 | Inventory, badge and run total agree; tests green; lint 0/0. |

---

## Sprint 4 — Printer call sites (PM-008)

| # | Step | IDs | Done when |
|---|---|---|---|
| 4.1 | **Establish the library's supported printer shape first.** Read `LibKa0s-Core-1.0`'s printer factory in `../LibKa0s`. If it already accepts format-plus-varargs, continue to 4.2. If it does **not**, stop: the change is an **additive** API addition made upstream in `../LibKa0s` and re-vendored back as its own standalone commit (`library-stack-§7`). **Do not** wrap the printer locally — that is anti-pattern #47. | PM-008 | A written answer, and if upstream work is needed, a LibKa0s issue rather than a local wrapper. |
| 4.2 | Fix the three debug-sink sites now — they are unconditionally safe. Drop the redundant `tostring()` wrappers at `settings/Schema.lua:144`, `modules/Registry.lua:641`, `settings/Panel.lua:218` and let the sink's `safeToString` handle each vararg. | PM-008 | Those three lines pass raw values. |
| 4.3 | Sweep the ~22 chat sites listed in `03_EVIDENCE.md` §6 — `settings/Slash.lua`, `settings/PanelEditor.lua`, `settings/Schema.lua`, `core/DebugLogSetup.lua` — converting `..` / `:format(` / `tostring()` pre-building into format-plus-varargs. Run the suite after each file; a mis-transcribed format string prints garbage rather than erroring, so the existing output assertions are the safety net. | PM-008 | `grep -rn 'print(.*\.\.\|print(.*):format(' core modules settings` returns only the printer's own definition. |
| 4.4 | Add a test that a secret-shaped value (one the mock makes raise inside `table.concat`) routed through each surviving chat and debug surface renders `<secret>` rather than raising. This is what stops the next call site regressing. | PM-008 | The case is green, and provably red if any swept site is reverted. |
| 4.5 | Regenerate `docs/test-cases.md`, update the badge, green gate, commit as one `refactor(print):` change. | PM-008 | Tests green, lint 0/0. |

---

## Sequencing summary

```
Sprint 0  (decision)      ──────────────┐
Sprint 1  (PM-007)        ── independent │
Sprint 2  (PM-009/10/11)  ── independent │
Sprint 3  (perf cluster)  ───────────────┘ only if Sprint 0 chose (c)
Sprint 4  (PM-008)        ── independent, but 4.3+ may block on a LibKa0s release
```

Sprints 1, 2 and 4.2 can all land today. Sprint 3 is the largest and is gated on a decision that is
not an engineering one. Sprint 4.3 is the only step with an external dependency, and 4.1 exists
precisely to discover that before anyone starts typing.

## Standing rules for the remediation engagement

- Commit only on green: `lua tests/run.lua` **and** `luacheck .` (0/0). Never mid-checkpoint.
- Never edit anything under `libs/` or `tests/_kit/`; `tests/test_vendor_sync.lua` will catch it.
  A library defect is fixed in `../LibKa0s` and re-vendored as a standalone commit.
- Whenever a case is added, removed or renamed, regenerate `docs/test-cases.md` and move the README
  `[tests]` badge **in the same change**.
- Any negative assertion added must be proved falsifiable by mutation, with the mutation named in a
  comment; restore from a `cp` backup, never `git checkout`.
- This bundle is **frozen**. A re-audit writes a new `docs/audits/<date>/`; it never edits this one.
