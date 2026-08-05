# 05 — Execution plan (2026-08-05)

Ordered, checkable remediation steps for `02_DEVIATIONS.md`, designed in `04_TECHNICAL_DESIGN.md`.
This is the hand-off to the remediation engagement; the audit itself changed no addon code.

**Standing rules for every step below.**

- Trunk-based; commit directly to `master` unless the human asks for a branch (`versioning-git`).
- **Every commit is green**: `lua tests/run.lua` (all suites pass) **and** `luacheck .` (0/0)
  (`testing-§4`). `tests/_kit/run-automated-tests.sh --suite lint --suite tests --no-bundle` is
  exactly this pair and writes nothing.
- **Test-first.** New behavior gets a failing test first (`testing-§4`); a behavior-preserving
  refactor gets a characterization test that passes against the *unrefactored* code first
  (`testing-§13`).
- **Never edit `libs/` or `tests/_kit/`.** A library or kit problem is fixed in `../LibKa0s` and
  re-vendored (`library-stack-§7`). Sprint 3 is the only step that touches `tests/_kit/`, and it
  changes a **file mode**, not a byte.
- The full four-suite bundle is a **release** artifact and **MUST NOT** gate a commit
  (`automated-tests-§6`).

---

## Sprint 1 — the cheap MUSTs and the honesty fixes

Independent of everything else, small, and each removes a live defect. Do these first so the perf
workstream starts from a clean board.

| # | Step | IDs | Files | Done when |
|---|---|---|---|---|
| 1.1 | Write a **failing** degraded-load case: partial file list with no `libs/LibKa0s/*`, create a panel, run `/pm panel <name>`, assert it does not raise. Watch it go red with `attempt to call field 'FormatKV'`. | PM-007 | `tests/test_libka0s.lua` (or a new `tests/test_degraded.lua`) | The case is red, for the right reason |
| 1.2 | Publish a **plain** `Sl.FormatKV` inside the stub branch (no `\|c` escapes), and record the `Sl.Text` omission as a decision in a comment beside it. | PM-007 | `settings/Slash.lua:285-317` | 1.1 goes green |
| 1.3 | Add a case asserting the degraded `Sl.FormatKV` is **not** `lib.FormatKV` and emits no `\|c` sequence. | PM-007 | as 1.1 | Green |
| 1.4 | Add a **degradation member-sweep** for the Slash and Options seams, mirroring the DebugLog one: enumerate every member the addon's own source calls on each instance and assert the library-absent branch answers it. | PM-007 | as 1.1 | Green; a member removed from either stub turns it red |
| 1.5 | `git update-index --chmod=+x tests/_kit/run-automated-tests.sh`. Verify with `git ls-files -s`. | PM-018 | `tests/_kit/run-automated-tests.sh` (mode only) | Mode reads `100755` |
| 1.6 | Add the `chmod +x` step to the re-vendor instructions, so the next re-vendor cannot drop the bit. Optionally add a `git ls-files -s` assertion to `tests/test_vendor_sync.lua`. | PM-018 | `docs/testing.md` ▸ *The vendor gate* | Documented; case green if added |
| 1.7 | Make the two vendor-sync cases honest when the sibling is unreachable: **fail** (preferred), or rename both to say "…, or the sibling checkout is absent" and emit one visible line. | PM-020 | `tests/test_vendor_sync.lua:104-116,138,144` | No case can print PASS without having compared anything |
| 1.8 | Correct the file header's `.gitattributes` claim (`* text=auto eol=crlf` is not what this repo pins; `*.sh text eol=lf` is). Keep the CR normalization, fix the reason written beside it. | PM-020 | `tests/test_vendor_sync.lua:110-116` | Header matches `cat .gitattributes` |
| 1.9 | Print the degraded debug ack plainly — no `\|cff40ff40` / `\|cffff4040`, no library `ACK`/`STATE_*` wording. Keep the flag write and `explainOnce()`. | PM-022 | `core/DebugLogSetup.lua:137` | `grep -n "40ff40\|ff4040" core/` → no hit |
| 1.10 | Read `NS.AceGUI` in `settings/Panel.lua` and `settings/PanelEditor.lua` instead of resolving LibStub; make `core/LSMPatch.lua` prefer the stash at call time and fall back with a comment. | PM-021 | `settings/Panel.lua:12`, `settings/PanelEditor.lua:7`, `core/LSMPatch.lua:35` | One resolution at load; the two fallbacks documented |
| 1.11 | Add the `\| Tab \| Covers \|` table above the existing per-setting table in `### Settings panel`. | PM-010 | `README.md:138` | Table present, existing prose retained |

**Sprint 1 exit:** `luacheck .` 0/0 · suite green with the new degraded cases · a degraded install
answers `/pm panel <name>` without raising.

## Sprint 2 — the Perf adoption

The seven-deviation cluster. Land as one workstream; do not stop halfway.

| # | Step | IDs | Files | Done when |
|---|---|---|---|---|
| 2.1 | **Prerequisite.** Add `libs/LibKa0s/Perf.lua` and `libs/LibKa0s/PerfPanel.lua` to the runner's library load list, in `LibKa0s.xml` order. | PM-017 | `tests/run.lua:24-31` | Suite green, count unchanged |
| 2.2 | Add a case parsing `libs/LibKa0s/LibKa0s.xml` for its `<Script file=…>` entries and asserting the runner's library list equals that sequence, in order. | PM-017 | `tests/test_harness.lua` | Removing a file from the list turns it red |
| 2.3 | `.luacheckrc`: add `"debugprofilestop"` to `read_globals` and `"PanelMasterPerfDB"` to `globals`, each with a one-line reason. | PM-006 | `.luacheckrc:9-27` | `luacheck .` 0/0 |
| 2.4 | TOC: `## SavedVariables: PanelMasterDB, PanelMasterPerfDB`. | PM-003 | `PanelMaster.toc:7` | Two globals, in that order |
| 2.5 | Write failing cases for the seam: the instance exists, the descriptor's declared buckets are the intended set, and the degraded branch answers every member. | PM-001 | `tests/test_libka0s.lua` | Red |
| 2.6 | Add `core/PerfSetup.lua` — guarded `LibStub("LibKa0s-Perf-1.0", true)`, descriptor, **member-answering** stub with a plain boolean gate field and a dot-callable no-op sink. List it in the TOC's `# Core` block before any module taking `NS.Perf` as an upvalue. | PM-001 | new file, `PanelMaster.toc` | 2.5 green |
| 2.7 | Declare the four buckets with `within` nesting: `renderAll`, `renderPanel` (in `renderAll`), `applySpec` (in `renderPanel`), `mouseoverTick`. | PM-001 | `core/PerfSetup.lua` | Declared in report order |
| 2.8 | Write a failing case per bucket asserting a **real** bracket reaches it by driving its genuine entry point. | PM-001 | `tests/test_canvas.lua` | Red |
| 2.9 | Add the gated brackets at the four entry points, with `Perf` as a module-level load-time upvalue. No allocation, no concat, no `NS` lookup inside a bracket when capture is off. | PM-001 | `modules/Canvas.lua` | 2.8 green; `luacheck .` 0/0 |
| 2.10 | Write failing cases for suspend/resume: events unregistered, ticker canceled, the show-decision ladder refusing while suspended, and resume rebuilding from **current** state. | PM-012 | `tests/test_canvas.lua` | Red |
| 2.11 | Implement `suspend`/`resume` in the descriptor: unregister events, cancel the ticker, set a session-only `NS.State.suspended` consulted **inside** `Canvas`'s show decision — never a `Hide()` sweep. Never persist the flag. Resume before saving/reporting. | PM-012 | `core/PerfSetup.lua`, `modules/Canvas.lua`, `core/State.lua` | 2.10 green |
| 2.12 | Add the `perf` triple to `NS.COMMANDS`, dispatching to the library's entry point and printing its returned lines through `NS.Print`. The library registers no chat command. | PM-002 | `settings/Slash.lua:214-267` | `/pm perf` answers; `/pm help` and the landing page list it |
| 2.13 | Ship `tests/perf.lua` — TOC-derived load list, deterministic assertions only (call counts, bytes/iteration), **no wall-clock assertion**, outside the green gate and never called from `tests/run.lua`. | PM-004 | new file | `lua tests/perf.lua` runs standalone |
| 2.14 | Add the **zero-overhead scenario**: `updateMouseover` over N panels with capture off allocates no more than the same loop with brackets absent. | PM-004 | `tests/perf.lua` | The number is committed, not claimed |
| 2.15 | Pin `tests/perf.lua`'s derivation by **reading its source** for the `Loader.tocFiles` call from a gated case. | PM-004, PM-017 | `tests/test_harness.lua` | Green |
| 2.16 | Write `docs/performance.md` — the four buckets and their nesting, how to run `/pm perf`, the two-arm protocol, how to read a report, what the harness cannot resolve. Point at the library's record contract; do not restate it. | PM-005 | new file | Present |
| 2.17 | Write `docs/perf-runs/README.md` — naming `<YYYY-MM-DD>-ingame-<label>.json`, schema summary, pointer to the library contract, and the note that offline runs live in `docs/automated-tests/`. | PM-005 | new file | The dangling link at `docs/automated-tests/README.md:44` resolves |

**Sprint 2 exit:** `NS.Perf` is a real instance with four bracketed buckets, `/pm perf` opens the
guided panel, `PanelMasterPerfDB` is declared, suspend genuinely makes the addon inert,
`lua tests/perf.lua` runs with a committed zero-overhead number, and both perf docs exist. Ten of
the run's MUSTs are closed.

## Sprint 3 — the release-process documentation

| # | Step | IDs | Files | Done when |
|---|---|---|---|---|
| 3.1 | Add a *"The release gate"* subsection immediately after the existing "what gates" table: all four suites at `pass` and zero CCN > 15 at the tag; a `skip` blocks as NOT EVALUATED; evaluated by `/wow-addon:bump-version` from `manifest.json`, never by the runner's exit code; every failed gate reported; nothing bumped/tagged/pushed on failure. | PM-019 | `docs/automated-tests/README.md` | Both halves of the distinction stated in one place |
| 3.2 | Mirror the paragraph into `docs/testing.md` beside its existing *"At release, not at commit"* text — keeping that text, which is correct about commits. | PM-019 | `docs/testing.md:123-132` | Consistent with 3.1 |
| 3.3 | Add one sentence to `CLAUDE.md`'s release paragraph so an agent reading the first doc gets the tag half too. | PM-019 | `CLAUDE.md:46-50` | Present |
| 3.4 | If PM-004 has **not** landed, state the `perf`-skipped-because-no-`tests/perf.lua` exception and that it must appear in the release notes. If PM-004 **has** landed, omit it entirely. | PM-019, PM-004 | as above | Text matches reality |

## Sprint 4 — at first publish (not now)

| # | Step | IDs | Done when |
|---|---|---|---|
| 4.1 | Add `## X-Curse-Project-ID:` to the TOC in the mandated field position and the CurseForge version badge as badge #2 in the README row. | PM-015 | Both present, badge order Curse → Wago → WoWI preserved |
| 4.2 | Replace the `## Screenshots` placeholder with captioned images of the addon and its settings sub-panels. | PM-014 | Images present |
| 4.3 | Decide whether `docs/pending/LEDGER.md`'s open rows belong in GitHub issues; delete or migrate before the first tag. | PM-016 | Decision recorded |
| 4.4 | Fill the `## Version History` Date cell for `0.1.0` in the same change that cuts the tag. | PM-009 (follow-on) | Date present |
| 4.5 | Produce the full four-suite bundle **before** the tag, with `ANALYSIS.md`, and evaluate the release gate from its `manifest.json`. | `automated-tests-§6` | Bundle committed in the release change |

## Deferred, deliberately

- **PM-013** (`localization`) — the `NS.L` seam exists and both section MUSTs are met; wrapping
  strings is a scope decision for the first translation pass, recorded at `locales/enUS.lua:8-14`.
  Not scheduled.
- **PM-008** (`events-frames-taint-§8`) — ~25 call sites pre-build their line before the shared
  printer. This is a genuine MUST and it is **not** deferred on merit; it is deferred in **ordering**
  because it is a single mechanical sweep touching four files, and doing it during Sprint 2 would
  bury the perf diff in unrelated noise. Schedule it as its own commit immediately after Sprint 2,
  with the test that a secret-shaped value routed through each surviving site renders `<secret>`
  rather than raising. **Do not let it slip past the first release** — the whole point of the single
  seam is that no call site has to reason about whether today's value can become secret tomorrow.

## Verification checklist for the whole engagement

- [ ] `luacheck .` → 0 warnings / 0 errors
- [ ] `lua tests/run.lua` → all green; case count moved and `docs/test-cases.md` regenerated with
      `--list` in the same change, README `[tests]` badge updated to match (`testing-§5`)
- [ ] `lua tests/perf.lua` → runs, deterministic assertions only
- [ ] `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` → run **verbatim**; any function that newly
      crossed a threshold gets a disposition in `RESULTS.md` (`performance-§10`)
- [ ] `diff -r ../LibKa0s/LibKa0s libs/LibKa0s` and `diff -r ../LibKa0s/testkit tests/_kit` → both
      empty. **This run could not execute them** (`03_EVIDENCE.md` §5); the remediation engagement
      must, because drift here is invisible to both repos' suites
- [ ] `git ls-files -s tests/_kit/run-automated-tests.sh` → `100755`
- [ ] A degraded install (`libs/LibKa0s` removed) loads, answers `/pm panel <name>`, `/pm config`,
      `/pm debug on` and `/pm resetall` without raising
- [ ] `docs/` carries the trio plus all **five** required topic-detail docs
- [ ] The commit-gate / release-gate distinction is stated in full in `docs/automated-tests/README.md`,
      `docs/testing.md` and `CLAUDE.md`
