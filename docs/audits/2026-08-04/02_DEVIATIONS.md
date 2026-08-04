# 02 — Deviations (2026-08-04)

Measured against **Ka0s WoW Addon Standard v2.17.1 (2026-08-03)**.

**Provenance.** The playbook, the index and all 24 linked section files were fetched from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master` with
`curl -fsSL --max-time 15`, then verified **byte-identical** against the clean canonical checkout at
`/mnt/d/Profile/Users/Tushar/Documents/GIT/WowAddonStandards` (HEAD `2141229`, "v2.17.1") via `diff -r`.
No rule below is reconstructed from memory, and no section went unassessed.

**ID scheme.** The 2026-07-30 bundle used a non-addon-specific `D-00N` prefix, which `AUDIT.md`'s
stable-ID rule asks to be per-addon. This run adopts **`PM-`** and keeps it from here on; the
mapping to the prior run's rows is given at the bottom so nothing is orphaned.

**Counts: MUST 10 · SHOULD 2 · MAY/advisory 4.**

---

## MUST

| ID | Section | Deviation | Fix direction |
|---|---|---|---|
| **PM-001** | `performance-§1` | **No `core/PerfSetup.lua` and no `NS.Perf` instance.** `LibKa0s-Perf-1.0` is vendored but never resolved or instantiated. Evidence: `ls core/PerfSetup.lua` → no such file; `grep -rn "LibKa0s-Perf" core modules settings` → no hit. | Add `core/PerfSetup.lua` with the guarded `LibStub("LibKa0s-Perf-1.0", true)` lookup, a descriptor (buckets, `svName`, `suspend`/`resume`), and a member-answering stub; list it in the TOC's `# Core` block before any module taking `NS.Perf` as an upvalue. |
| **PM-002** | `performance-§4`, `slash-commands-§2` | **The reserved `perf` verb is not registered.** `NS.COMMANDS` (`settings/Slash.lua:202-255`) carries 18 verbs; `perf` is not among them, so `/pm perf` prints `unknown command 'perf'`. `perf` is reserved collection-wide and MUST mean the same thing in every addon. | Add a `{"perf", …, function(rest) … end}` triple to `NS.COMMANDS`, dispatching to the lib's command entry point and printing its returned lines through `NS.Print`. Never let the library register the command. |
| **PM-003** | `toc-file-§2`, `performance-§5`, `savedvariables-§4` | **Only one SavedVariables global is declared.** `PanelMaster.toc:7` reads `## SavedVariables: PanelMasterDB`; the standard requires exactly two, `<Addon>DB` **and** `<Addon>PerfDB`, in that order. | Extend the TOC line to `PanelMasterDB, PanelMasterPerfDB` and hand the ring's **name** to the Perf descriptor (PM-001). It stays outside the AceDB tree by construction. |
| **PM-004** | `performance-§9` | **No offline scenario runner `tests/perf.lua`,** so the mandated **zero-overhead scenario** — the required *evidence* that instrumentation is free when capture is off — does not exist. Evidence: `ls tests/perf.lua` → no such file. | Ship `tests/perf.lua`, run as `lua tests/perf.lua`, outside the green gate, asserting only on call counts and bytes allocated. Its load list must be TOC-derived (`testing-§9`) and pinned by reading its source. |
| **PM-005** | `documentation-§3` | **Two required topic-detail docs are missing:** `docs/performance.md` and `docs/perf-runs/README.md`. Evidence: `ls docs/performance.md docs/perf-runs` → neither exists; `docs/` holds `ARCHITECTURE.md`, `artwork-spec.md`, `smoke-tests.md`, `test-cases.md`, `testing.md`. | Write `docs/performance.md` (which paths are bracketed and why, how to run `/pm perf`, how to read the report, what the harness cannot resolve) and create `docs/perf-runs/` with its README documenting naming and pointing at the library's record contract. |
| **PM-006** | `lint`, `performance-§2`, `performance-§5` | **`.luacheckrc` is missing both perf entries.** `debugprofilestop` is absent from `read_globals` (`.luacheckrc:9-21`) — the bracket call sites are addon code and *are* linted — and `PanelMasterPerfDB` is absent from `globals` (`:22-27`), which the standard requires to be declared with a comment like the addon's own SV global. | Add `"debugprofilestop"` to `read_globals` and `"PanelMasterPerfDB"` to `globals` with a one-line comment. Land it with PM-001/PM-003 so lint stays 0/0 in the same commit. |
| **PM-007** | `slash-commands-§1` | **The slash degradation stub omits `Sl.FormatKV`, and the omission crashes host code.** `Sl.FormatKV` is assigned only at `settings/Slash.lua:369`, *after* the `if not lib then … return end` block ends at `:304`. Three host-owned panel verbs call it — `settings/Slash.lua:101`, `:156-157`, `:169`, `:176` — so with `libs/LibKa0s` absent, `/pm panel <name>` raises `attempt to call field 'FormatKV' (a nil value)`. **Reproduced mechanically** (see `03_EVIDENCE.md`), not inferred. This is the "crash moved to a rarer code path" the stub rule exists to prevent, and it is invisible to the current suite because no degraded case drives a panel verb. | Publish a deliberately plain `Sl.FormatKV` **inside** the stub branch — a bare `path = value` line that is visibly *not* the library's styled one, and **not** a copy of the library's color escapes (`slash-commands-§1` forbids re-implementing the rendering). Add a degraded case that drives `/pm panel` and one asserting the degraded formatter is not the library's function value. |
| **PM-008** | `events-frames-taint-§8` | **~22 chat call sites and 3 debug call sites pre-build their line before the shared printer.** Call sites MUST NOT feed args through `..` / `tostring` / `table.concat` / `string.format` before `NS.Print` — the single seam exists so no call site has to reason about secrets. Chat examples: `settings/Slash.lua:48`, `:49-50`, `:57`, `:58`, `:70`, `:71`, `:117`, `:131`, `:136`, `:156-157`, `:165`, `:174`, `:184`, `:287`, `:301`; `settings/PanelEditor.lua:91`, `:104`, `:118`, `:125`; `settings/Schema.lua:171`; `core/DebugLogSetup.lua:114`; `settings/Slash.lua:225`. Debug sink: `settings/Schema.lua:144`, `modules/Registry.lua:641`, `settings/Panel.lua:218`. None of these values can be combat-protected **today** — which the standard explicitly says does not make it compliant. | Move the formatting behind the seam: pass the format string and its arguments separately (`print("deleted %d %s.", n, word)` shape) and let the printer's stringifier handle each vararg, exactly as `NS.Debug(tag, fmt, ...)` already does. This is a mechanical sweep; do it in one commit with a test that a secret-shaped value routed through each surviving site renders `<secret>` rather than raising. |
| **PM-009** | `documentation-§1` (item 12) | **The README `## Version History` table has no Date column.** `README.md:489-493` renders `\| Version \| Notes \|`; the standard mandates a **Version \| Date \| Highlights** table. | Add the Date column and rename Notes → Highlights, keeping most-recent-first order. |
| **PM-012** | `performance-§6` | **The suspend / resume host contract is not implemented.** There is no suspended check in the renderer's show-decision ladder and nothing unregisters the addon's events or cancels queued work for a capture arm. Evidence: `grep -rn "suspend\|Suspend" core modules settings` → no hit. The contract is one of the five wiring MUSTs in `performance-§1`'s adoption-strength paragraph. | Implement `suspend`/`resume` seams in the Perf descriptor (PM-001): unregister the addon's events, cancel queued work, and enforce visibility **at the source** inside `Canvas`'s show decision rather than by hiding frames. Never persist the flag; resume from current state; resume before saving or reporting. |

## SHOULD

| ID | Section | Deviation | Fix direction |
|---|---|---|---|
| **PM-010** | `documentation-§1` (item 7) | **README `### Settings panel` is a per-setting table, not the mandated Tab \| Covers table.** `README.md:143-152` lists one row per *setting*; the standard asks for one row per settings **subcategory** (with per-panel prose permitted *after* it). | Lead the subsection with a `\| Tab \| Covers \|` table (General, Panels, Profiles as applicable), then keep the existing per-setting rows as the sanctioned follow-on prose. |
| **PM-011** | `performance-§10` | **No `docs/complexity.md`.** The `lizard` report over the addon's own source (excluding `libs/`) is a SHOULD, and two authored files sit in the 1000–1500 LOC "on notice" band (`modules/Artwork.lua` 1087, `settings/PanelEditor.lua` 1064) — exactly where the report earns its keep. | Run `lizard` excluding `libs/`, commit the output as `docs/complexity.md`, and state in the file that it is generated and how. Do **not** gate commits on it. |

## MAY / advisory

Recorded so a later run does not re-derive them; none is a deviation today.

| ID | Section | Note |
|---|---|---|
| **PM-013** | `localization-§1/§3` | `locales/enUS.lua:6` exports `NS.L` with the correct metatable, but **no user-facing string routes through it** — every label, tooltip and message is hardcoded English. The file documents this as an explicit 0.1.0 scope decision (`:8-14`) with the seam kept for a later pass. The section's MUSTs (export `NS.L`, ship `enUS.lua`) are met, so this is advisory. Revisit at the first translation. |
| **PM-014** | `documentation-§1` (item 6) | `README.md:63-68` carries a placeholder in `## Screenshots` rather than images. The section is SHOULD, becoming MUST **once published**. Carries forward the prior run's `D-004`. |
| **PM-015** | `toc-file-§1`, `documentation-§1` (item 2) | No `## X-Curse-Project-ID:` and no CurseForge version badge (the README row has four of five badges). Both are due **only once published on CurseForge**; the addon is unreleased at `0.1.0`. Carries forward the prior run's `D-001` and `D-002`. Add both in the same change as the first publish. |
| **PM-016** | `documentation-§4` | `docs/pending/LEDGER.md` is a standing decision ledger that also functions as a backlog. It is **not** named `TODO.md` and the addon is pre-release, so the rule is not engaged. Flagged only so the first release considers whether its open rows belong in GitHub issues. |

---

## Confirmed compliant (sourced)

Each of these was checked against the section text this run, not assumed from the prior bundle.

- **Vendoring is whole and undrifted.** `diff -r ../LibKa0s/LibKa0s libs/LibKa0s` and
  `diff -r ../LibKa0s/testkit tests/_kit` are **both empty** — no anti-pattern #45 drift, no #48
  partial vendoring. The two `Perf` files are carried despite not being wired, which is the rule.
- **No hand-rolled shared subsystem (anti-pattern #47).** The addon owns no console, no widget
  makers, no flow engine, no dispatcher, no parser, no test framework. It owns four descriptors and
  four degradation stubs: `core/CoreSetup.lua`, `core/DebugLogSetup.lua`, `settings/Slash.lua`,
  `settings/OptionsSetup.lua` (plus `tests/_kit/`). Nothing under `libs/` or `tests/_kit/` is patched.
- **TOC lists `libs\LibKa0s\LibKa0s.xml` once** (`PanelMaster.toc:29`), never individual module files.
- **Field order, `#`-sections, single Interface, trailing newline** — all correct (`toc-file-§1/§3/§5`).
- **`architecture-§2` printer reclaim** — `core/PanelMaster.lua:13`, pinned by
  `tests/test_libka0s.lua:91`.
- **`architecture-§4` receiver rule** — `NS.NewBusTarget()` at `core/PanelMaster.lua:20-26`, used at
  `modules/Canvas.lua:705`; every message documented at `docs/ARCHITECTURE.md:279-309`; one sender each.
- **`architecture-§5` schema-as-single-source** — one row table, one `S:Set` write seam
  (`settings/Schema.lua:132-147`) that both the panel and the CLI route through, boot validation at
  `:163-174`.
- **`options-ui-§1`** — `NS.Helpers` **is** the library instance (`settings/OptionsSetup.lua:63`),
  not a copy-across; the load-completing stub is the documented exception and is correct.
- **`options-ui-§9`** — category registered eagerly with a `PLAYER_LOGIN` retry
  (`core/PanelMaster.lua:37,51-53`); anti-pattern #22 clean.
- **`options-ui-§2`** — the combat refusal is the library's, reached at `settings/Panel.lua:488`;
  no second un-gated open path.
- **`debug-logging-§1/§5/§7`** — guarded lookup, bare sink binding, host-owned session-only flag,
  and a stub answering all eight members the addon calls.
- **`savedvariables-§1`** — one AceDB global, `schemaVersion` in `global`, a real migration runner
  with a v1→v2 body (`core/Database.lua:84-116`).
- **`library-stack-§5`** — no Ace fork; the LSM widget fixup extends via `RegisterWidgetType`
  (`core/LSMPatch.lua:44,65`) from `core/`, not from `libs/`.
- **`library-stack-§6`** — no suite dependency; the SunnArt integration is discovery-only,
  presence-guarded, and ships a manifest fallback so it degrades to nothing when absent.
- **`testing`** — kit vendored to `tests/_kit/` (never `libs/`), thin `wow_mock.lua` extender,
  TOC-derived load list, 696/696 green, `docs/test-cases.md` generated and in lockstep with the badge.
- **`lint` / `packaging` / `versioning-git`** — `luacheck .` 0 warnings / 0 errors across 25 files;
  `.pkgmeta` has no `externals:` and ignores `docs`, `tests`, `tools`, `_dev`; trunk-based history.
- **`documentation-§2/§6`** — `CLAUDE.md` is a stub with the verbatim
  `## Standards compliance (read first)` section; all three standard references present (TOC
  `X-Standard`, README badge, `CLAUDE.md`) — anti-pattern #34 clean.
- **`documentation-§3` (anti-pattern #49)** — no `docs/agent-context.md`, and `CLAUDE.md:44-59`
  forbids re-creating it.
- **`localization-§4/§5`** — matching is on stable tokens; `tests/test_spelling.lua` gates US English
  across the TOC-named source and passes.
- **`anti-patterns` #1, #5, #6, #7, #8, #13, #14, #15, #16, #20, #22, #25, #26, #29, #32, #34, #36,
  #38, #45, #46, #47, #48, #49** — all clear.

---

## ID continuity with 2026-07-30

| Prior | This run |
|---|---|
| `D-001` (no `X-Curse-Project-ID`) | `PM-015` |
| `D-002` (four badges, not five) | `PM-015` |
| `D-003` (missing logo `.tga`) | resolved before that run closed; verified present at `media/logos/panelmaster.logo.tga` |
| `D-004` (Screenshots placeholder) | `PM-014` |
| `D-005` (no README logo) | resolved; `README.md:11` |

Everything else in this run is new — either genuinely new code (PM-007) or newly in scope because
the prior run was measured against v2.11.0, before `performance` became MUST (PM-001 … PM-006,
PM-012) and before the current `documentation-§1` table shape (PM-009, PM-010).
