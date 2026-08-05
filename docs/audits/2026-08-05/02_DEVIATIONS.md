# 02 — Deviations (2026-08-05)

Measured against **Ka0s WoW Addon Standard v2.21.0 (2026-08-04)**, index plus all 25 linked section
files (provenance in `01_CURRENT_STATE.md`).

**ID scheme.** The per-addon prefix is **`PM-`**, adopted in the 2026-08-04 run and reused here.
A deviation that persists keeps its ID and its number. IDs `PM-001` … `PM-016` carry forward;
`PM-017` … `PM-022` are new this run.

**Counts: MUST 10 · SHOULD 6 · advisory 4. Resolved since 2026-08-04: 2.**

---

## MUST

| ID | Section | Deviation | Fix direction |
|---|---|---|---|
| **PM-001** | `performance-§1` | **No `core/PerfSetup.lua`, no `NS.Perf` instance.** `LibKa0s-Perf-1.0` is vendored (`libs/LibKa0s/Perf.lua`, `PerfPanel.lua`) but never resolved. `grep -rn "LibKa0s-Perf\|NS\.Perf" core modules settings` → no hit. `performance-§1` makes the wiring a MUST. | Add `core/PerfSetup.lua`: guarded `LibStub("LibKa0s-Perf-1.0", true)`, a descriptor (declared buckets with `within` nesting, the `PanelMasterPerfDB` name, `suspend`/`resume`, the host printer), and a **member-answering** stub. List it in the TOC's `# Core` block before any module taking `NS.Perf` as an upvalue. |
| **PM-002** | `performance-§4`, `slash-commands-§2` | **The reserved `perf` verb is not registered.** `NS.COMMANDS` (`settings/Slash.lua:214-267`) carries 18 verbs; `perf` is not one, so `/pm perf` answers `unknown command 'perf'`. `perf` is reserved collection-wide and MUST mean the same thing in every addon. | Add a `{"perf", …, handler}` triple to `NS.COMMANDS` dispatching to the library's command entry point and printing its returned lines through `NS.Print`. The library must never register the command itself. |
| **PM-003** | `toc-file-§2`, `savedvariables-§4`, `performance-§5` | **Only one SavedVariables global is declared.** `PanelMaster.toc:7` reads `## SavedVariables: PanelMasterDB`; the standard requires exactly two, `<Addon>DB` then `<Addon>PerfDB`. | Extend the line to `PanelMasterDB, PanelMasterPerfDB` and hand the ring's **name** to the Perf descriptor (PM-001). It stays outside the AceDB tree by construction. |
| **PM-004** | `performance-§9` | **No `tests/perf.lua`,** so the mandated **zero-overhead scenario** — the required evidence that instrumentation is free when capture is off — does not exist. `ls tests/perf.lua` → no such file; the `perf` suite is a permanent `skip` in every bundle. | Ship `tests/perf.lua`, run as `lua tests/perf.lua`, outside the green gate, asserting only on call counts and bytes allocated per iteration. Derive its load list from the TOC (`testing-§9`) and pin the derivation by reading its source. |
| **PM-005** | `documentation-§3` | **Two of the five required topic-detail docs are missing:** `docs/performance.md` and `docs/perf-runs/README.md`. `docs/automated-tests/README.md:44` already links `../perf-runs/`, which does not exist. | Write `docs/performance.md` (which paths are bracketed and why, how to run `/pm perf`, how to read the report, what the harness cannot resolve) and create `docs/perf-runs/README.md` documenting the naming convention, a schema summary, a pointer to the library's canonical record contract, and the note that offline runs live in `docs/automated-tests/`. |
| **PM-006** | `lint`, `performance-§2`, `performance-§5` | **`.luacheckrc` is missing both perf entries.** `debugprofilestop` is absent from `read_globals` (`.luacheckrc:9-21`) although bracket call sites are addon code and *are* linted; `PanelMasterPerfDB` is absent from `globals` (`:22-27`), which the standard requires to be declared with a comment beside the addon's own SV global. | Add `"debugprofilestop"` to `read_globals` and `"PanelMasterPerfDB"` to `globals` with a one-line comment. Land with PM-001/PM-003 so lint stays 0/0 in the same commit. |
| **PM-007** | `slash-commands-§1` | **The slash degradation stub omits `Sl.FormatKV`, and the omission crashes host code.** `Sl.FormatKV` is assigned only at `settings/Slash.lua:381`, *after* the `if not lib then … return end` block closes at `:316`. Five host-owned panel call sites use it — `:101`, `:124`, `:125`, `:181`, `:188`. **Reproduced mechanically this run** (`03_EVIDENCE.md` ▸ *Degraded-install reproduction*): `/pm panel audit` → `settings/Slash.lua:101: attempt to call field 'FormatKV' (a nil value)`. This is exactly the "crash moved to a rarer code path" the stub rule names. Secondary: `Sl.Text` is also nil in the stub; it has no production caller today, but the omission is **not** written down in the stub, so it does not qualify as the sanctioned documented-decision case. | Publish a deliberately plain `Sl.FormatKV` **inside** the stub branch — a bare `path = value` line that is visibly *not* the library's styled one, and **not** a copy of the library's color escapes (`slash-commands-§1` forbids re-implementing its rendering). Record the `Sl.Text` decision in a comment in the same branch. Add a degraded-load case that drives `/pm panel <name>` and one asserting the degraded formatter is not the library's function value. |
| **PM-008** | `events-frames-taint-§8` | **~25 chat/debug call sites pre-build their line before the shared printer.** Call sites MUST NOT feed args through `..` / `tostring` / `table.concat` / `string.format` before `NS.Print` — the single seam exists so no call site has to reason about secrets, and a site is non-compliant "even if it is never handed a secret today". Chat: `settings/Slash.lua:15`, `:49-50`, `:58`, `:71`, `:114`, `:124`, `:125`, `:160`, `:177`, `:181`, `:186`, `:188`, `:196`; `settings/PanelEditor.lua` (four sites); `settings/Schema.lua:171`; `core/DebugLogSetup.lua:137`. Debug sink: `settings/Schema.lua:144`, `modules/Registry.lua`, `settings/Panel.lua`. | Move the formatting behind the seam: pass the format string and its arguments separately (`print("deleted %d %s.", n, word)`) and let the printer's stringifier handle each vararg, exactly as `NS.Debug(tag, fmt, ...)` already does. Mechanical sweep; land with a test that a secret-shaped value routed through each surviving site renders `<secret>` rather than raising. |
| **PM-012** | `performance-§6` | **The suspend / resume host contract is not implemented.** No suspended check exists in the renderer's show-decision ladder, and nothing unregisters events or cancels queued work for a capture arm. `grep -rn "suspend\|Suspend" core modules settings` → no hit. This is one of the five wiring MUSTs in `performance-§1`'s adoption-strength paragraph. | Implement `suspend`/`resume` in the Perf descriptor (PM-001): unregister the addon's events, cancel queued work, and enforce visibility **at the source** inside `Canvas`'s show decision rather than by hiding frames. Never persist the flag; restore from current state on resume; resume before saving or reporting. |
| **PM-017** | `testing-§9` | **The runner's vendored-library load list is incomplete.** `tests/run.lua:24-31` spells out six of `libs/LibKa0s/LibKa0s.xml`'s eight files; `Perf.lua` and `PerfPanel.lua` are omitted. `testing-§9` requires **every** file of the library's XML, in dependency order — the omission is precisely the failure mode it names (a library file left out makes the dependent module refuse to register, and the suite then happily measures the stub). New this run. | Append `"libs/LibKa0s/Perf.lua"` and `"libs/LibKa0s/PerfPanel.lua"` to the `Loader.loadAll` list in XML order, and extend the existing derivation cases in `tests/test_harness.lua` to assert the runner's library list equals `LibKa0s.xml`'s `<Script file=…>` list. Do this **before** PM-001 so the Perf wiring is exercised, not stubbed, the day it lands. |
| **PM-018** | `automated-tests-§2` | **The vendored runner is not executable.** `git ls-files -s tests/_kit/run-automated-tests.sh` → mode `100644`. `automated-tests-§2` requires the runner to be run as `tests/_kit/run-automated-tests.sh`, and states that re-vendoring ends with `chmod +x`; both `docs/testing.md:111` and `docs/automated-tests/README.md:10` document invoking it directly, which fails on a fresh checkout. `.gitattributes`'s `*.sh   text eol=lf` carve-out is correctly present, so this is the other half of the same rule. New this run. | `git update-index --chmod=+x tests/_kit/run-automated-tests.sh`, and add the `chmod +x` step to the re-vendor instructions in `docs/testing.md` ▸ *The vendor gate*. |

## SHOULD

| ID | Section | Deviation | Fix direction |
|---|---|---|---|
| **PM-010** | `documentation-§1` (item 7) | **README `### Settings panel` is a per-setting table, not the mandated `Tab \| Covers` table.** `README.md:138-152` lists one row per *setting*; the standard asks for one row per settings **subcategory**, with per-panel prose permitted after it. | Lead the subsection with a `\| Tab \| Covers \|` table (General, Panels, Profiles), then keep the existing per-setting rows as the sanctioned follow-on prose. |
| **PM-019** | `automated-tests-§3` (*The release gate*), `documentation-§5` | **No document states the release gate; the commit-gate half is stated alone.** `docs/testing.md:123` and `docs/automated-tests/README.md:28-30` say `perf` and `complexity` "never fail a run" and both gate tables read "no — recorded only"; `docs/testing.md:131` says "At release, not at commit… Commits are gated on lint + tests only"; `CLAUDE.md:46-50` says the bundle "is a **release** step and **not** a commit gate: nothing about it may ever block a commit". All of that is correct about **commits** and silent about the **tag**, where v2.21.0 requires all four suites at `pass` and `suites.complexity.warnings == 0`, treats a `skip` as NOT EVALUATED, and evaluates it from the run's `manifest.json` rather than from the runner's exit code. Because this addon's `perf` suite is a permanent `skip` (PM-004), the one narrow sanctioned exception — *skipped because the addon ships no `tests/perf.lua`* — has to be stated in the release notes, and nothing here says so. New this run. | Add a short *"The release gate"* paragraph to `docs/automated-tests/README.md` and `docs/testing.md`: at the tag, all four suites `pass` and zero functions above CCN 15, read from `manifest.json` by `/wow-addon:bump-version`; a `skip` blocks; the runner's exit code is deliberately unchanged because the same script is the commit gate. Name the `tests/perf.lua` exception explicitly and say it must appear in the release notes until PM-004 is closed. Mirror one sentence into `CLAUDE.md` so the distinction is in the first doc an agent reads. |
| **PM-020** | `testing-§12` | **Two vendor-sync cases print PASS without asserting when the sibling checkout is unreachable.** `tests/test_vendor_sync.lua` guards both cases with `if not tag then return end` (`:138`, `:144`), where `siblingTag()` returns nil the moment `git show HEAD:LibKa0s/Core.lua` fails (`:104-116`). Neither case name says so — they read "libs/LibKa0s is the LibKa0s release the README says this addon bundles" and "tests/\_kit is the test kit that shipped with that release". A gate that goes quiet when it cannot look reads as coverage and provides none; the file's own header at `:110-116` claims the case name says so, which it does not. New this run. | Either fail the pair when the sibling is unreachable (the `testing-§11` shape — a gate that cannot run reports, it does not pass), or rename both cases to say *"…, or the sibling checkout is absent"* and emit one visible skip line. Failing is preferable: the vendored copy is the one thing neither other suite can see. |
| **PM-021** | `library-stack-§4` | **AceGUI is resolved from LibStub in three places** — `core/LSMPatch.lua:35`, `settings/PanelEditor.lua:7`, `settings/Panel.lua:12` — beside the library's own `onAceGUI` seam that already stashes it as `NS.AceGUI` (`settings/OptionsSetup.lua:98`). The section asks for one resolution at load, stashed on the namespace. New this run. | Keep the `onAceGUI` stash as the single source and have the three call sites read `NS.AceGUI`. `core/LSMPatch.lua` loads before `settings/OptionsSetup.lua`, so it needs its resolution deferred to call time rather than file scope; note that constraint in the change. |
| **PM-022** | `debug-logging-§7` (with `debug-logging-§3`) | **The DebugLog degradation stub hand-copies the library's ack string and its state colors.** `core/DebugLogSetup.lua:137` emits `"debug logging " .. (on and "\|cff40ff40ON\|r" or "\|cffff4040OFF\|r")`, reproducing `ACK` / `STATE_ON` / `STATE_OFF` (`libs/LibKa0s/DebugLog.lua:68-70`) and the exact hexes the library applies at `:633-637`. `debug-logging-§3` forbids reproducing the library's color codes in a fallback stub; `§5` says the coloring of the state word "is not the addon's to restyle". The stub **must** still flip the flag and print the ack (`§7`) — it just must not do it in the library's own escapes. Recorded as SHOULD because `§3`'s MUST NOT is worded around the two line formatters, and the ack is `§5`'s. New this run. | Print the degraded ack plainly — `"debug logging on"` / `"debug logging off"` with no color escapes — which is also the honest signal that the console is gone. Keep the flag write and `explainOnce()` exactly as they are. |

## Advisory (recorded, not deviations today)

| ID | Section | Note |
|---|---|---|
| **PM-013** | `localization-§1/§3` | `locales/enUS.lua:6` exports `NS.L` correctly, but **no user-facing string routes through it** — every label, tooltip and message is hardcoded English, documented at `:8-14` as an explicit 0.1.0 scope decision with the seam kept. Both section MUSTs (export `NS.L`, ship `enUS.lua`) are met. Revisit at the first translation. |
| **PM-014** | `documentation-§1` (item 6) | `README.md:58-60` carries a placeholder in `## Screenshots`. The section is SHOULD, becoming MUST **once published**. Carried from `D-004` (2026-07-30). |
| **PM-015** | `toc-file-§1`, `documentation-§1` (item 2) | No `## X-Curse-Project-ID:` and no CurseForge version badge (the README row has four of five). Both are due **only once published**; the addon is unreleased at `0.1.0`. Carried from `D-001`/`D-002`. Add both in the change that publishes. |
| **PM-016** | `documentation-§4` | `docs/pending/LEDGER.md` is a standing decision ledger that also functions as a backlog. It is not named `TODO.md` and the addon is pre-release, so the rule is not engaged. Flagged so the first release decides whether its open rows belong in GitHub issues. |

## Resolved since the 2026-08-04 run

| ID | Section | Resolution |
|---|---|---|
| **PM-009** | `documentation-§1` (item 12) | **Closed.** `README.md:395-397` now renders `\| Version \| Date \| Highlights \|`. The Date cell reads `—` for the unreleased `0.1.0`, which is honest rather than a drift; it becomes a date at the first tag. |
| **PM-011** | `performance-§10` | **Closed as no-longer-applicable.** The prior run asked for `docs/complexity.md`; that doc was **retired** in standard v2.19.0 (`automated-tests-§7`). Its raw output is now each bundle's `complexity.txt` and its watch-list/trend role is `docs/automated-tests/RESULTS.md`, both of which exist and are current. The addon correctly carries **no** `docs/complexity.md`, and `docs/testing.md:139-140` records the retirement. |

## Confirmed compliant (each re-checked against v2.21.0 this run, sourced in `03_EVIDENCE.md`)

- **No hand-rolled shared subsystem (anti-pattern #47).** No console, no widget makers, no flow
  engine, no dispatcher, no parser, no test framework in addon code. Four descriptors + four
  degradation stubs, plus the vendored `tests/_kit/`. Nothing under `libs/` or `tests/_kit/` is patched.
- **Whole-folder vendoring (anti-pattern #48).** `libs/LibKa0s/` carries all eight ship files plus
  `LibKa0s.xml` and `LICENSE`, including the two `Perf` files the addon does not wire — which is the
  rule, not an oversight. The TOC lists `libs\LibKa0s\LibKa0s.xml` **once** (`PanelMaster.toc:29`),
  never individual module files.
- **The Options stub is load-completing, not member-answering** (`settings/OptionsSetup.lua:28-61`) —
  the one documented exception in `options-ui-§1`, correctly applied, with the reasoning written at
  `:29-34`. Flagging it would be a false positive.
- **The DebugLog and Core stubs answer every member the addon calls** (call sites enumerated in
  `03_EVIDENCE.md`).
- **`architecture-§2`** printer reclaim at `core/PanelMaster.lua:13`; **`architecture-§4`** per-receiver
  bus targets via `NS.NewBusTarget()` (`:20-26`), one sender per message; **`architecture-§5`** one
  schema table, one `S:Set` write seam, boot validation.
- **`options-ui-§9`** eager category registration with a `PLAYER_LOGIN` retry (`core/PanelMaster.lua:37,51-53`).
- **`toc-file-§1/§3/§5`** field order, single Interface, `#`-sections in load order, trailing newline.
- **`documentation-§6`** three-place standards reference complete (anti-pattern #34 clean).
- **Root doc set** exactly three docs plus `LICENSE`; no `docs/agent-context.md` (anti-pattern #49
  clean); no `TODO.md`; the `docs/` trio present.
- **`docs/complexity.md` absent** — correct as of v2.19.0.
- **`.gitattributes`** carries `*.sh   text eol=lf` (`automated-tests-§2`).
- **`automated-tests-§4`** `RESULTS.md` is one overwritten path with the four-suite table, both watch
  lists, **Band** as a column, and a standing paragraph per suite. Its instrument-fault note on the
  `Max CCN` `0` is exactly the "record the fault, never edit the frozen number" discipline the
  section asks for.
- **`lint`** `luacheck .` → 0 warnings / 0 errors over 25 files (measured this run).
- **`testing`** 706/706 passing (measured this run); `docs/test-cases.md` byte-identical to a fresh
  `--list` regeneration.
- **`performance-§10`** the complexity report is current: a verbatim re-run today reproduces the
  latest bundle's figures **exactly**, and no function has crossed a threshold since. No
  anti-pattern #51 staleness.
- **Anti-pattern #53** not engaged: the warned-function watch list reads "None." over 1348 functions,
  and the three band entries carry real dispositions (one of them a scheduled peel), across three
  runs **none of which was a release run** (`"release": null` in every manifest).
