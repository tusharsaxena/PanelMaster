# 05 — Execution plan (2026-10-07)

Ordered, checkable steps for the remediation engagement. Each step names its deviation ID(s) from
`02_DEVIATIONS.md` (12 roots, 13 with the dependent; 1 Medium, 10 Low including the dependent, 2
Info) and the design in `04_TECHNICAL_DESIGN.md`. The green gate after every step is
`lua tests/run.lua` (currently 1035 passed / 1 skipped / 1036) and `luacheck .` (0/0 over 71 files),
both through `ka0s-bounded`. A step that adds or removes a case regenerates `docs/test-cases.md` and
the README `[tests]` badge in the same commit.

## Sprint 1 — the one behavior fix (Medium)

- [ ] **S1.1 `PM-049a`** — Add the blast-radius case to `tests/test_slash.lua` (three panels, two
  profiles, unlocked, console open; assert zero panels, the profile list unchanged and current,
  `state.locked` true, console hidden, one `PanelsChanged`). Carry
  `-- red under: drop the session-row restore in Sl:DoResetAll`. **Run it and watch it fail** on
  today's tree (`state.locked` false, console shown).
- [ ] **S1.2 `PM-049`** — Restore every `sessionOnly` profile row through
  `NS.SchemaRuntime.ApplyDefault` inside `Sl:DoResetAll`'s bracket, after `db:ResetProfile()`
  returns. Confirm the composed `state.debugConsole` row carries `sessionOnly`; wire it in
  `S:InstallMaster` if not. Rewrite `settings/OptionsSetup.lua:285-294`. S1.1 goes green; the full
  suite stays green.
- [ ] **S1.3** — Add an in-game smoke row to `docs/smoke-tests.md`: unlock, open the console, *Reset
  all settings* → panels gone, *Lock frame* ticked, console closed, a new panel arrives locked. The
  owner runs it; do not mark it passed.

## Sprint 2 — code-level Lows

- [ ] **S2.1 `PM-050`** — Degraded `Sl.FormatKV` renders `path = value` with no colour escape;
  replace the byte-for-byte pins at `tests/test_surface_parity.lua:193-194` with a no-`|c` assertion
  plus a presence check; rewrite the `settings/Slash.lua:501-507` comment.
- [ ] **S2.2 `PM-051`** — In the live 12.1 client, `/dump GetAddOnMetadata`, `/dump GetNumAddOns`,
  `/dump GetAddOnInfo`; record the answers in the commit body. Delete each rung whose global is nil:
  `core/EnvSetup.lua:55-57`, `core/Compat.lua:30-33`. Drop the matching names from
  `.luacheckrc:34`. Adjust `tests/test_envsetup.lua` / `tests/test_compat.lua` cases that drove the
  global rung. If a global turns out to be present, keep its rung and note why.

## Sprint 3 — docs and records (Low)

- [ ] **S3.1 `PM-046`** — `README.md:65`, `:229`: no angle-bracket placeholder; `:271`: prefix the
  last 1.2.0 highlight with `- `. De-AI pass on the changed sentences.
- [ ] **S3.2 `PM-053`** — Reorder root `CLAUDE.md`: pointer list, green-gate paragraph, LibKa0s
  paragraph, provenance line, Perf paragraph, release paragraph, docs set. Re-run
  `tests/test_vendor_sync.lua`.
- [ ] **S3.3 `PM-054` + part of `PM-044`** — `docs/automated-tests/README.md:29` quotes
  `bash tests/_kit/run-automated-tests.sh --suite complexity`; `docs/testing.md:242` says kit 37.
  One commit, so the two tables agree.
- [ ] **S3.4 `PM-044`** — The rest of the sweep: the census figures (`docs/ARCHITECTURE.md:384-391`,
  re-measured), the `events-frames-taint-§8` row's API list (`:349`, after S2.2, re-swept), and the
  comments at `core/LifecycleSetup.lua:53-54`, `:117-118`, `core/LauncherSetup.lua:226`,
  `settings/Slash.lua:317`, `:367`, `:699-701`. Re-derive each from the tree.
- [ ] **S3.5 `PM-052`** — One sentence in `docs/ARCHITECTURE.md` → `## Settings Schema` naming
  `db.global.minimap.minimapPos`, its owner `core/LauncherSetup.lua`, and LibDBIcon's drag as its
  only writer.
- [ ] **S3.6 `PM-042`** — After S3.4 and S3.5, trim `docs/ARCHITECTURE.md` under 400 lines: the
  Perf preamble (`:333-344`), the retired rows (`:352-370`), the census narrative (`:384-420`).
  `tests/_kit/test_layout_cap.lua` must stay green (it parses the census).
- [ ] **S3.7 `PM-048`** — Write `docs/revendor/<date>-v1.69.0-v1.70.0/` with `01_DELTA.md` (line 1
  `Delta: LibKa0s v1.68.1 -> v1.70.0 (span: v1.69.0 v1.70.0)`) and `05_SUMMARY.md` (one line per
  tag). Re-run the playbook's two-listing check; it prints nothing.

## Sprint 4 — store hygiene (Info)

- [ ] **S4.1 `PM-055`** — `gh issue edit 47 --remove-label state:triaged --add-label state:done`,
  with a comment citing `5119ae1`. Only on the owner's go-ahead for GitHub writes.
- [ ] **S4.2 `PM-033`** — At the **next release**, not before: the full four-suite battery as a
  release run (first sighted release record), a disposition for `tests/test_slash.lua` (1084) in the
  band table, and an `ANALYSIS.md` that says the previous record (`20260927-032003`) was unsighted.

## Closing checks

- [ ] `ka0s-bounded lua tests/run.lua` green; inventory regenerated; badge matches.
- [ ] `ka0s-bounded luacheck .` → 0 / 0.
- [ ] `ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` → pass,
  0 warnings, no blind file.
- [ ] The playbook's line-ending (e) one-liner → 0 (new files written CRLF, per the repo's pin).
- [ ] The re-vendor two-listing check → nothing unrecorded.
- [ ] `docs/ARCHITECTURE.md` under 400 lines; `## Documentation map` still covers every live `.md`.
- [ ] The three register rows unchanged in **Decided**; only `:349`'s **Why** inventory restated.

## Not in this plan

- Upstream (WowAddonStandards, documentation lane): `testing-§8`'s worked example still cites
  `PanelMaster/settings/Slash.lua:316` (now `:508`) and should say the cure is a plain member
  (`PM-050`).
- Outside the standard, for review: the *Delete all panels* confirmation's "on this character"
  (`settings/Slash.lua:81`) understates a shared-profile wipe.
