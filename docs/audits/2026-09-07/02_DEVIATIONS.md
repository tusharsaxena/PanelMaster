# 02 — Deviations (2026-09-07)

Measured against **Ka0s WoW Addon Standard v2.38.0 (2026-09-02)**, index plus all 26 linked section
files (provenance in `01_CURRENT_STATE.md`).

**ID scheme.** Per-addon prefix **`PM-`**, adopted 2026-08-04 and reused. `PM-001` … `PM-022` were
issued by earlier runs; the new IDs this run are **`PM-023` … `PM-030`**. A deviation that persists
keeps its ID.

## Counts — both numbers, with their basis

| | Count | Basis |
|---|---|---|
| **Headline tally (roots only)** | **8** | `PM-023` … `PM-030`. Excludes `derived from` dependents and excludes rows already ratified in `docs/ARCHITECTURE.md` → `## Documented deviations`. |
| **Total including dependents** | **9** | The eight roots plus `PM-023a`. |
| **MUST failures (roots only)** | **7** | `PM-023`, `PM-024`, `PM-025`, `PM-026`, `PM-027`, `PM-029`, `PM-030`. `PM-028` fails a SHOULD. |
| **MUST failures incl. dependents** | **7** | `PM-023a` is a doc-sync consequence, not a separate MUST. |

By impact grade — **High 0 · Medium 1 · Low 7 · Info 0** (roots).
Six of the seven MUST failures are graded **Low**: they are doc, config, record or latent-risk
failures that no user can reach in the current code. The grade is impact; the MUST is still named
in every entry.

---

## Medium

### PM-023 — `options-ui-§14`

**MUST.** The Panels page's **page-wide acts sit in the scroll, under one tab, instead of in the
chrome band above the strip.** `options-ui-§14` names them explicitly — *"Creating the thing the
page edits, choosing which one is being edited, and the acts that apply to it whole — enable,
unlock, copy, reset, delete — are page-wide and go above the strip."* The band
(`settings/PanelEditor.lua:1112-1199`, `H.PageHeader` at `:1116`) correctly holds **Create new panel** (`:1141`) and the **panel picker** (`:1154`), and is correctly unboxed. But **Panel name** (rename), **Copy settings from panel**, **Enabled**,
**Unlock**, **Reset** and **Delete** are all declared inside `sections[TAB_GENERAL]`
(`settings/PanelEditor.lua:565-677`), so a player editing on *Artwork* or *Accent bar* cannot
enable, unlock, copy, reset or delete the panel they are looking at without first clicking back to
*General* — and the controls read as belonging to that tab, which is exactly the failure the rule
names.

**Fix direction.** Move the five whole-panel acts (and rename) into the existing `H.PageHeader`
block beside the create box and the picker: one chrome block, still unboxed, the band's height
raised to fit. `sections[TAB_GENERAL]` then keeps only the settings genuinely scoped to *general*
appearance. Because the band is built once from `BuildPage` and never released by a rebuild
(`settings/PanelEditor.lua:1106-1111`), the moved controls need in-place refresh (`SetValue` /
`SetList`) rather than a rebuild, the same path the picker already takes.

#### PM-023a — `documentation-§5` — *derived from PM-023* — Low

`docs/settings-panel.md:257-261` argues the current placement in prose — *"`Reset` and `Delete` sit
on the **General** tab beside `Enabled` and `Unlock`, because that is …"*. The doc is correct about
today's code and wrong against `options-ui-§14`; it must move with the code, in the same change.
Not counted in the headline tally, and not a second MUST.

---

## Low

### PM-024 — `options-ui-§16` (anti-pattern #73)

**MUST.** **The panel's border group, the accent bar group and the accent bar's border group are
hand-written rather than composed.** `options-ui-§16` says *"These groups are COMPOSED, not typed
out. The library emits each block from one declaration; a hand-written copy is anti-pattern #73."*
The three blocks are typed out in `settings/PanelEditor.lua` — border at `:738-757`
(`Border style` `:743`, `Border thickness (px)` `:745`), bar at `:770-800` (`Bar texture` `:785`,
`Bar opacity` `:788`), bar-border at `:814-830` (`:819`, `:821`).

**Mitigating, and why this is Low rather than Medium:** every block is currently in the canonical
row order with the canonical labels, the mandated rows are all present, this addon's own extras
(`Border offset`, `Bar thickness`, `Bar offset`) are appended **after** the mandated four rather
than interleaved, and each block says so in a comment. Nothing a player can see is wrong today. The
risk the MUST exists to prevent — the day the group grows a row, it grows in one addon — is latent.

**Blocked upstream.** `libs/LibKa0s/OptionsCompose.lua:262` (`O.BorderGroup`) and `:297`
(`O.BarGroup`) emit **schema rows** carrying `path` / `type` / `default`, consumed by the
schema-driven flow engine. This addon's panel editor draws **registry records**, not schema rows
(`settings/OptionsSetup.lua:138-150` — *"this addon's schema has no `page` field"*;
`settings/PanelEditor.lua:148-149` — *"a panel is a registry record, not a set of schema rows with
paths"*). There is no record-backed composer form to call.

**Fix direction.** Upstream in `LibKa0s`: give `O.BorderGroup` / `O.BarGroup` / `O.FontGroup` a
record-backed arm — a `get`/`set` pair per row instead of a `path` — so a per-instance editor can
emit the canonical block from one declaration. Then adopt it here and delete the three hand-written
blocks. Until then, record the state as a deviation row in `docs/ARCHITECTURE.md` →
`## Documented deviations` citing `options-ui-§16`, with the re-check trigger *"LibKa0s gains a
record-backed composer"*.

### PM-025 — `packaging`

**MUST.** **`.pkgmeta`'s ignore list omits `.gitattributes`, and two root dot-entries are
unaccounted for.** `packaging` makes `.gitattributes` a named entry of the mandatory ignore set
(*"the root dev-only dotfiles `.luacheckrc`, `.gitignore` and `.gitattributes`"*), and its strong
form requires that **every** root dotfile either appear in the list or be justified in a comment
beside it. `.pkgmeta:5-12` lists `.luacheckrc`, `.gitignore`, `docs`, `tests`, `tools`, `_dev`,
`"*.bak"` and three `media/` paths. The mechanical sweep reports `.gitattributes` and `.pkgmeta`
unaccounted (`.git` is the one exempt entry). `.claude` and `.superpowers` do not exist in this
repo, so their absence from the list is not a live packaging defect — but the standard names them,
and a future agent-tooling directory would ship silently.

**Fix direction.** Add to the `ignore:` block: `- .gitattributes   # dev-only: the repo's
line-ending policy (line-endings)`, `- .claude          # dev-only: agent tooling`,
`- .superpowers     # dev-only: agent tooling`, and either a `- .pkgmeta` row or a one-line comment
recording that the packager consumes it and never ships it.

### PM-026 — `line-endings-§7`

**MUST.** **Five tracked files disagree with the declared `eol=crlf` pin.** The pin
(`.gitattributes:26`), the `*.sh` carve-out (`:34`) and the 21 `binary` markers are all correct, and
the body diffs against the canonical client-bound body with only the ratified extensionless-ELF
block — so this is the working-tree half of the rule, not the file half. `line-endings-§1` names
the correct-file-over-unrenormalized-tree case as the one this check exists to catch.

Reported as **one** rolled-up finding, per the playbook. The files are deliberately not enumerated:
the fix is a single `git add --renormalize .` plus a re-checkout, and a per-file tally inflates the
count for one action. The reproducing command and its raw output are in `03_EVIDENCE.md`.

**Not comparable with the 2026-08-05 bundle's figure.** That run used the pre-v2.28.1 command,
which counted every binary and every JSON file as a stray. The frozen bundle is never edited; this
note is how the two numbers sit side by side without contradicting each other.

**Fix direction.** `git add --renormalize .`, review, commit; then for each remaining working-tree
straggler `rm <path> && git checkout -- <path>` and re-run the count.

### PM-027 — `automated-tests-§4` (anti-pattern #51)

**MUST.** **The automated-test record and its watch list no longer describe the code.** The newest
bundle is `docs/automated-tests/20260825-103450/`, whose `manifest.json` records
`git.sha 721c5593…`; HEAD is **19 commits** past it (`git rev-list --count` in `03_EVIDENCE.md`),
and the whole `feat/settings-revamp-v2` merge landed after it. Three concrete drifts:

1. **The watch list's prose is anchored two runs back.** `docs/automated-tests/RESULTS.md:102`
   reads *"Current state as of [`20260807-114409`] — not that run's diff."*, although
   `20260825-103450` and `20260807-160022` are both newer.
2. **A watch-list disposition's own condition fired and was not honored.** `RESULTS.md:157` says of
   `settings/PanelEditor.lua` — *"if the next change also grows it, execute the split rather than
   re-accept."* It has since grown **1091 → 1350** lines (+259).
3. **Two files newly entered `layout-§1`'s 1000–1500 on-notice band and are in no table.**
   `tests/test_panel.lua` 700 → 1076 and `tests/test_libka0s.lua` 925 → 1064, both measured at the
   last run's sha versus HEAD.

Today's `lizard` run is otherwise clean — **0 warnings over 1472 functions**, no threshold
exceeded, max CCN unchanged at 15 in `Compat.AddOnFolders` and `R.ApplyArtSize`, both of which are
dense **defaulting and guarding** (`and`/`or` short-circuits counted as decisions) rather than
tangled control flow.

**This is a finding about the release process, not about the commit gate.** The checkpoint is
release; nothing here is a reason to gate commits on complexity. Anti-pattern #53's shelf-life
clock has **not** tripped: only one run on record (`20260807-160022`) is a release run, so no
*Accepted* entry has been carried across three consecutive release runs.

**Fix direction.** Run `tests/_kit/run-automated-tests.sh` from the repo root, freeze the bundle,
prepend the `RESULTS.md` row, re-anchor the watch-list prose to the new run, add the two test files
to the band table, and either split `settings/PanelEditor.lua` along the page/editor seam or record
a fresh, argued disposition for it. Do this **before** the next tag.

### PM-028 — `automated-tests-§5`

**SHOULD.** **Two frozen bundles carry no `ANALYSIS.md`** — `docs/automated-tests/20260807-110543/`
and `docs/automated-tests/20260825-103450/`. `automated-tests-§5` makes the write-up a MUST at a
**release** run and a SHOULD otherwise; both of these have `"release": null`, so this is the SHOULD.
The six other bundles have one, including the `1.0.0` release run `20260807-160022`, so the MUST is
met.

**Fix direction.** Write the two missing write-ups, or state in `docs/automated-tests/README.md`
that non-release runs may ship without one — the standard permits the second, and a silent gap in
an otherwise complete series reads as an oversight.

### PM-029 — `audit-review-history` (with `documentation-§3`)

**MUST.** **A register row's re-check trigger fired 2026-08-07 and the row was not re-checked.**
`docs/ARCHITECTURE.md:199` carries a `documentation-§4` row whose Why reads *"The addon is
pre-release, so the rule is not yet engaged"* and whose Re-check trigger reads *"The first published
release, which is when `documentation-§4` engages"*. The addon released **1.0.0 on 2026-08-07**
(`PanelMaster.toc:5`; `README.md` Version History). `documentation-§4` is now engaged — and the
addon **satisfies it outright**: there is no `TODO.md` at the root or under `docs/`, and pending
work lives in GitHub issues, which is what the rule asks for. So the row now records a compliance
as if it were a deviation.

`audit-review-history` binds this run to report exactly this: a register that quietly accumulates
entries for behavior the standard now mandates or permits. This is a register-hygiene finding, not
a behavior defect — no user can reach a table row, hence Low.

**Fix direction.** Retire the `documentation-§4` row. The register is not a graveyard; the decision
survives in issue history and in `README.md`'s `## Issues and feature requests` section.

**Checked and found clean in the same pass:** the other six rows' triggers have **not** fired —
`documentation-§1` item 5 waits on the first release *after* 1.0.0; `performance-§1`,
`events-frames-taint-§8`, `localization-§1`, `line-endings-§5` and `options-ui-§1` each name an
upstream or code condition that still holds. And every `state:will-not-do` issue was cross-checked
against the register: **#31**/**#44** (Perf) have their row; **#43**/**#45**/**#46** (Widgets,
Item, Pool declined) and **#27**/**#28**/**#29**/**#30** (library-surface adoptions declined) need
none, because `library-stack-§7` makes the **ship payload** whole-folder and the **adoption** only
what you use — declining to wire a major is not a deviation. No un-ratified decline was found.

### PM-030 — `options-ui-§13` (with `testing-§12`)

**MUST.** **No suite case pins that a wrapped tab strip's geometry does not move with the
selection.** The library half is correct and was verified this run:
`libs/LibKa0s/OptionsWidgets.lua:428-443` measures the row pitch from `TAB_ATLAS[false]` — the
**unselected** art — and caches it in `measuredArtH`, which is exactly what `options-ui-§13` and
anti-pattern #70 ask for. What is missing is the guard: no case in `tests/` asserts that the
reserved band and every row's y offset are identical for every value of the active tab.

And a case written naively would be green against nothing: `tests/_kit/mock_base.lua:97` answers
`function f:GetHeight() return 0 end` for every frame and every atlas, so a harness that cannot
report two different heights cannot fail the invariant. Per `testing-§12` this is reported as a
**missing** case rather than a passing one.

The mutation the case must die under: change `TAB_ATLAS[false]` to `TAB_ATLAS[true]` at
`libs/LibKa0s/OptionsWidgets.lua:434`, or delete the `measuredArtH` cache at `:429`.

**Fix direction.** Stub a height-varying atlas in `tests/wow_mock.lua` (selected art taller than
unselected), then add a case in `tests/test_panel.lua` that renders the Panels page's six-tab strip
at a width that forces a wrap and asserts the band height and every row y-offset are byte-equal
across all six selections. The pitch measurement itself is the library's and is audited in its own
repo; this case is the consumer-side guard `testing-§12` asks for.

---

## Recorded deviations — accepted, not counted

Each of these is a gap this run would otherwise have filed, matched to a **ratified** row in
`docs/ARCHITECTURE.md` → `## Documented deviations`. None counts toward the tally or the MUST
count. Nothing found this run is new evidence that any of the reasoning is now wrong.

| Prior ID | Rule | Row | Decided |
|---|---|---|---|
| PM-001, PM-002, PM-003, PM-004, PM-005, PM-006, PM-012 | `performance-§1` | `docs/ARCHITECTURE.md:193` — the Perf wiring declined on a bounded-cost argument, explicitly **not** a `§12` exemption | 2026-08-25 |
| PM-008 | `events-frames-taint-§8` (the pre-formatting SHOULD) | `docs/ARCHITECTURE.md:195` — the MUST does not engage; no call site reads a combat-protected API | 2026-08-05 |
| PM-013 | `localization-§1` | `docs/ARCHITECTURE.md:196` — English-only, the second terminal state `localization-§3` names; `NS.L` seam and `enUS.lua` both ship | 2026-08-05 |
| — | `documentation-§1` (item 5) | `docs/ARCHITECTURE.md:194` — no `## What's new` on an initial release | 2026-08-07 |
| — | `line-endings-§5` | `docs/ARCHITECTURE.md:197` — one extra block marking an extensionless ELF binary, which `§4` requires and no `*.ext` rule can reach | 2026-08-07 |
| — | `options-ui-§1` | `docs/ARCHITECTURE.md:198` — the Options stub loses the composed `Master controls` rows; the loss is measured and pinned by a case | 2026-09-02 |

---

## Closed since 2026-08-05

| ID | Rule | Evidence it is closed |
|---|---|---|
| PM-007 | `slash-commands-§1` | `Sl.FormatKV` is now published on the degraded arm — `settings/Slash.lua:357`, reasoned at `:350-356` |
| PM-009 | `documentation-§1` (item 12) | Version History table with a real date — `README.md` `1.0.0 \| 2026-08-07` |
| PM-010 | `documentation-§1` (item 7) | `README.md:123-128` is now a `\| Page \| Covers \|` table |
| PM-011 | `performance-§10` | No `docs/complexity.md`; the record is `docs/automated-tests/` |
| PM-014 | `documentation-§1` (item 6) | Four captioned screenshots at `README.md:24-42`, served from the CurseForge CDN |
| PM-015 | `toc-file-§1`, `documentation-§1` (item 2) | `PanelMaster.toc:14` `X-Curse-Project-ID: 1642836`; `README.md:4` CurseForge version badge |
| PM-016 | `documentation-§4` | `docs/pending/LEDGER.md` is gone; decisions live in GitHub issues with `state:` + `severity:` labels |
| PM-017 | `testing-§9` | `tests/test_harness.lua` — *"the runner derives the vendored library's load list from LibKa0s.xml"* and *"every module LibKa0s.xml declares is live"*, both PASS |
| PM-018 | `automated-tests-§2` | `git ls-files -s tests/_kit/run-automated-tests.sh` → `100755` |
| PM-019 | `automated-tests-§3` | `docs/automated-tests/RESULTS.md:13-15` states the release gate: all four suites plus zero CCN > 15, evaluated from `manifest.json` |
| PM-020 | `testing-§12` | The vendor-sync cases now assert: *"libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles"* and *"tests/_kit is the test kit that shipped with that release"*, both PASS with the sibling present |
| PM-021 | `library-stack-§4` | Downgraded to **compliant**. `library-stack-§4` is a SHOULD, and the standard's reading guide makes a SHOULD deviation compliant when a code comment explains why. `settings/OptionsSetup.lua:157-167` records the decision in full: the library already publishes the handle as `O.AceGUI`, and all three remaining `LibStub("AceGUI-3.0", true)` calls (`core/LSMPatch.lua:35`, `settings/Panel.lua:12`, `settings/PanelEditor.lua:7`) resolve at file scope **before** the instance exists, so no build-time seam can serve them |
| PM-022 | `debug-logging-§7`/`§3` | `core/DebugLogSetup.lua:146` prints a plain uncolored ack; the reason is at `:141` |
