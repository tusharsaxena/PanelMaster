# 02 — Deviations (2026-09-08)

Measured against **Ka0s WoW Addon Standard v2.39.0 (2026-09-07)**, the index plus all 26 linked
section files. Provenance in `01_CURRENT_STATE.md`; evidence in `03_EVIDENCE.md`.

**ID scheme.** Per-addon prefix **`PM-`**, adopted 2026-08-04 and reused. `PM-001` … `PM-030` were
issued by earlier runs. `PM-030` persists and keeps its ID. The new IDs this run are **`PM-031`,
`PM-032`, `PM-033`**, plus the dependent `PM-032a`.

**This bundle and `05_EXECUTION_PLAN.md` are read as one document.** Every figure that appears in
both was reconciled after both were written; the reconciliation is recorded in `03_EVIDENCE.md`
§ 10.

## Counts — both numbers, with their basis

| | Count | Basis |
|---|---|---|
| **Headline tally (roots only)** | **4** | `PM-030`, `PM-031`, `PM-032`, `PM-033`. Excludes `derived from` dependents and excludes gaps already ratified in `docs/ARCHITECTURE.md` → `## Documented deviations`. |
| **Total including dependents** | **5** | The four roots plus `PM-032a`. |
| **MUST failures (roots only)** | **3** | `PM-030`, `PM-031`, `PM-032`. `PM-033` is an observation, not a failure — see its entry. |
| **MUST failures incl. dependents** | **4** | `PM-032a` fails `localization-§5`'s dialect MUST in its own right. |

By impact grade — **High 0 · Medium 0 · Low 3 · Info 1** (roots).
Including dependents — **High 0 · Medium 0 · Low 4 · Info 1**.

All three MUST failures are graded **Low**: every one is a doc, a config file or a missing test
case, and none is reachable by a player in the current code. The grade is impact; the MUST is named
in every entry.

**Two of the four are visible only against v2.39.0** — `PM-031` and `PM-032` measure rules this
release changed from judgment into a published, countable criterion. That is the amendments doing
their job, and it is why this pass rather than M1's keyword greps is the gate.

---

## Low

### PM-030 — `options-ui-§13` (with `testing-§12`) — carried from 2026-09-07

**MUST.** **No suite case pins that a wrapped tab strip's geometry does not move with the
selection.** The library half is correct and was re-verified this run:
`libs/LibKa0s/OptionsWidgets.lua:447` measures the row pitch with `tex:SetAtlas(TAB_ATLAS[false][1], true)` — the
**unselected** art — and `:452` caches it in the file-scope `measuredArtH` declared at `:421`, which is what `options-ui-§13` and
anti-pattern #70 ask for. What is still missing is the consumer-side guard: no case in `tests/`
asserts that the reserved band height and every row's y offset are identical for every value of the
active tab.

**What changed since 2026-09-07: the blocker is gone.** That run reported the case as unwritable,
because `tests/_kit/mock_base.lua` answered `GetHeight() → 0` for every frame and every atlas, so a
naive case would have been green against nothing. Test-kit **revision 15** landed with `M1-LK-08` and
is vendored here: `tests/_kit/mock_base.lua:141` publishes `f:__setGeom(w, h)`, `:132` makes
`GetHeight` answer the recorded value once geometry is armed, and `:153` gives `SetAtlas` a
kit-published size table. The case is now writable against the shared mock. `tests/wow_mock.lua:165`
still answers `__h` only, so the arming has to be explicit in the case.

**This was a planned carry, not a missed close.** `05_TRACEABILITY.md:231` dispositions
`PANELMASTER-A-07` as **deferred** to `M1-LK-08`, and `05_TRACEABILITY.md:528` states that
`M1-LK-08` ships the additive half and **stops there**, with the four `C12` findings deliberately
held for kit 16. Kit 15 turns out to be enough for the consumer-side case even though `GetHeight`'s
default was not flipped, which is what makes this newly actionable rather than still blocked.

The mutation the case must die under: change `TAB_ATLAS[false][1]` to `TAB_ATLAS[true][1]` at
`libs/LibKa0s/OptionsWidgets.lua:447`, or delete the `measuredArtH` assignment at `:452`.

**Fix direction.** In `tests/test_panel.lua`, arm the strip's probe texture through the kit's
`__setGeom` (or the kit atlas table) so selected art is taller than unselected, render the Panels
page's five-tab strip at a width that forces a wrap, and assert the band height and every row
y-offset are byte-equal across all five selections. Verify red under the mutation above. The pitch
measurement itself is the library's and is audited in its own repo.

---

### PM-031 — `documentation-§3` — **new, and visible only against v2.39.0**

**MUST.** **`docs/compat-layer.md` is absent while its Tier 2 trigger has fired, and
`## Documentation map` asserts *Not applicable*, which is now false.**

v2.39.0 turned this trigger from the only pure-judgment one in the tier model into a published
count: *"`core/Compat.lua` publishes **three or more** addon-specific shims"*, counted by
`documentation-§3`'s own grep over the addon's own file and nothing else. Run here, that grep returns
**8** (`03_EVIDENCE.md` § 5) — `Compat.AddOnFolders` `:27`, `GetScreenSize` `:56`, `GetUIScale` `:65`,
`InCombat` `:79`, `RegisterMedia` `:103`, `FetchMedia` `:124`, `MediaList` `:139`, `MouseIsOver`
`:164`. The standard's own §3 text names this repo's figure in its rationale: *"`PanelMaster/core/Compat.lua` at 173
lines (8 shims) does not"* have the doc — written when it was a judgment call and there was no number
to fail.

`docs/ARCHITECTURE.md:145` reads:

> `| `compat-layer.md` | Not applicable | `core/Compat.lua` normalizes the addon roster, screen size, UI scale, LSM and class color — no addon-specific shim beyond what the row in `module-map.md` records |`

The playbook grades this **above a bare omission**, because the row asserts something that is now
untrue: an auditor reading the map cannot tell *not applicable* from *not written*, which is the one
thing the row exists to answer. It is still doc-only, so the impact grade is **Low** and the rule it
fails is still a **MUST**.

**Not a rules-change escape.** The eight are genuinely the addon's own — `core/Compat.lua:5-7` states
the file's contract, and the TOC-metadata reader that used to head it moved out to
`core/EnvSetup.lua` over `LibKa0s-Env-1.0` precisely so that what remains is PanelMaster's
(`core/Compat.lua:11-14`). Nothing in the eight is a LibKa0s shim being re-documented.

**Fix direction.** Write `docs/compat-layer.md` — one section per shim: what varies, what the guard
returns when the API is absent, and which module calls it. Then change the `## Documentation map`
row from `Not applicable` to `Present`, carrying the count and the threshold the way the
`slash-dispatch.md` row already does (`| Present | 8 shims in core/Compat.lua (threshold is 3) |`).
The `midnight-quirks.md` row's *Not applicable* is unaffected and stays.

---

### PM-032 — `localization-§5` — **new, and visible only against v2.39.0**

**MUST.** **The spelling gate runs a private word list instead of the canonical one this release
published, and it reaches 5 of the 20 live `docs/` pages.**

v2.39.0 publishes `BRITISH` and `ALLOWED` once, in `localization-§5`, and rules that every mechanical
gate **MUST** use them **whole** — *"A gate MUST carry every `BRITISH` entry and every `ALLOWED`
entry, and MUST NOT carry an entry that is not published here."* The section names this collection's
own private lists as the reason the rule exists.

`tests/test_spelling.lua:41-59` is a private list. Measured against the published pair
(`03_EVIDENCE.md` § 6):

- **Missing canonical entries** include `metre`, `fibre`, `calibre`, `theatre`, `centring`,
  `analogue`, `amongst`, `learnt`, `ageing`, `enquir`, `sulphur`, `memois`, `cancellable`, `fulfil`,
  and the `-lled`/`-lling` pairs the canonical list spells out per inflection.
- **Entries not in the published list** include `savour`, `odour`, `valour`, `harbour`, `splendour`,
  `ardour`, `clamour`, `candour`, `demeanour`, `fervour`, `parlour`, `tumour`, `marvellous`,
  `skilful`, `wilful`, `instalment`, `enrolment`, `aluminium`, `focussed`, `targetted`, `storey`,
  `plough`, `draught`, `kerb`, `smoulder`, `canceller`, `synchronis`, `finalis`.
- **There is no `ALLOWED` list at all.** `tests/test_spelling.lua:71-79` substitutes a bespoke
  heuristic — an `-is` stem is matched only when followed by `e`, `a` or `i` — where the standard
  specifies removing `ALLOWED` **as whole words, before the scan**. The two are not equivalent: the
  heuristic passes `analyses` and `synthesis` by never listing `analys`/`synthesis` at all, and it
  cannot be reconciled with a canonical list it does not carry.
- **The scan's own scope is hand-named and short.** `tests/test_spelling.lua:143-147` lists seven
  documents — `README.md`, `CLAUDE.md`, `docs/ARCHITECTURE.md`, `docs/smoke-tests.md`,
  `docs/test-cases.md`, `docs/testing.md`, `docs/artwork-spec.md` — plus `.luacheckrc` and four
  `tools/` Python files. That is two root documents and **five** of the twenty live `docs/` pages, so
  **fifteen `docs/` pages are outside it**, including every Tier 1 page and
  `docs/performance.md`. `localization-§5` scopes the gate to *"prose in `README.md` and every file
  under `docs/`"*.

The list is deliberately grown rather than canonical, and the file says so — *"the list is meant to
grow, not to be complete"* (`tests/test_spelling.lua:35`). That was the right instinct under v2.38.0
and is the exact shape v2.39.0 forbids: a private list is a coverage claim nobody outside this repo
can check, and *"a private addition MUST NOT outlive the change that discovered it."*

**Grade.** A test-config failure that no player can reach → **Low**. The rule is a **MUST**. What it
costs is real but bounded, and `PM-032a` is what it cost here.

**Fix direction.** Replace `BRITISH` with `localization-§5`'s published list copied whole, add the
published `ALLOWED` list, and remove `ALLOWED` as whole words before running the `BRITISH`
substrings — deleting the `-is`-suffix heuristic, which the `ALLOWED` list replaces. Widen
`authoredFiles()` to every `.md` under `docs/` by directory walk rather than by hand-named list,
excluding — **file by file or directory by directory in the gate itself**, as §5 requires —
`docs/audits/`, `docs/reviews/`, `docs/automated-tests/<run>/`, `docs/revendor/`,
`docs/superpowers/`, `libs/`, `tests/_kit/`, and `tests/test_spelling.lua`'s own copy of the lists.
Then fix whatever the widened gate reddens on, starting with `PM-032a`. Any British form the
canonical list misses is amended **upstream in the standard first**, never added here.

#### PM-032a — `localization-§5` — *derived from PM-032* — Low

**MUST.** **`docs/performance.md:107` ships a British spelling in authored prose** — *"It is
committed here because it is the **artefact** that settles the question either way"*. US English is
`artifact`. It is not quoted external text, not a locale key and not a proper noun, so none of §5's
four exceptions reaches it.

The gate's own `BRITISH` list already carries `artefact` (`tests/test_spelling.lua:50`). It stays
green because `docs/performance.md` is not in the hand-named doc set — which is precisely the
`testing-§12` failure mode §5 describes: a check that reads as coverage and provides none.

**Why it does not graduate to a root.** `PM-032` is neither closed nor accepted; the word is not
reachable by any user, so its impact is not independent of the root; and its grade is the same
**Low**, not higher. It is discovered and closed by the same single action — widen the gate, then
respell what it reddens on — so filing it as a second root would double one fix.

**Also swept and deliberately not filed:** `docs/superpowers/specs/2026-07-31-panel-artwork-design.md:5`
and `docs/superpowers/specs/2026-08-02-wiki-artwork-import-design.md:5` both carry *catalogued*.
Both are **frozen dated records** under a directory `docs/ARCHITECTURE.md:121-123` names as such and
that `localization-§5` excludes as *"frozen dated bundles … which are the record and are not
rewritten"*. Naming them here so the sweep's full output is on the record and the exclusion is a
decision rather than an omission.

**Fix direction.** `artefact` → `artifact` at `docs/performance.md:107`, in the same change that
widens the gate, so the gate proves the fix rather than the fix being taken on trust.

---

## Info

### PM-033 — `automated-tests-§4` (anti-pattern #51)

**Observation, not a failure, and the distinction is the point.** The newest frozen bundle
`docs/automated-tests/20260908-181416/` was written **today** at sha `564acbd`, and HEAD is **4**
commits past it (`git rev-list --count` in `03_EVIDENCE.md` § 3). Re-measuring at HEAD moves four
numbers:

| Figure | Recorded `20260908-181416` | At HEAD `bb7b9fe` |
|---|---|---|
| `lizard` total nloc | 12627 | 12848 |
| `lizard` function count | 1494 | 1501 |
| suite cases | 778 | 783 |
| `luacheck` files | 55 | 57 |

**Nothing crossed a threshold.** `lizard` warns on nothing at either sha, max CCN is 15 at both, and
the 1000–1500 band is the same four files at the same line counts. The drift is entirely
`tests/test_lintconfig.lua` (275 lines, added at `c422422`) and `tests/test_docs.lua`'s new cases.

**Why this is Info and not Low.** Anti-pattern #51 is about a record that *reads as measured and is
not*. This one stamps its own sha, its own branch and its own clean/dirty state in
`manifest.json`, so every number in it is true of a commit it names. The checkpoint is **release**,
not commit, and there has been no tag since. Filing it as a MUST failure would be filing the release
process for not having run yet.

**What it is worth saying anyway:** the record and its watch list were regenerated on the branch and
then the branch grew four more commits, one of which changed `.luacheckrc`. The `## Lint` section
(`docs/automated-tests/RESULTS.md:51`) quotes the exclusion list verbatim and that quote is still
correct, so the one figure in the file that could have gone actively wrong did not.

**Checked in the same pass and clean:** anti-pattern #53's shelf-life clock has **not** tripped. Only
one run on record is a release run (`20260807-160022`, `"release": "1.0.0"`), so no *Accepted*
disposition has been carried across three consecutive release runs. And the list is not a backlog
wearing a watch list's clothes: four entries, readable in one pass, and one of the four
(`settings/PanelEditor.lua`, `docs/automated-tests/RESULTS.md:83`) reads *"The trigger has fired, and it is tracked: issue
#47"* rather than *accepted*.

**Fix direction.** Regenerate at the tag, not before. `tests/_kit/run-automated-tests.sh` from the
repo root as part of the next release, freeze the bundle, and let `RESULTS.md` be overwritten by the
runner — carrying the four `Disposition` cells forward verbatim, which is the one authored cell in
the file (`automated-tests-§4`).

---

## Recorded deviations — accepted, not counted

Each of these is a gap this run would otherwise have filed, matched to a **ratified** row in
`docs/ARCHITECTURE.md` → `## Documented deviations`. None counts toward either tally or toward the
MUST count. Every row's re-check trigger was evaluated against this tree and every evidence id it
cites was resolved (`03_EVIDENCE.md` § 7). **Nothing found this run is new evidence that any of the
reasoning is now wrong.**

| Prior ID | Rule | Row | Decided | Trigger evaluated |
|---|---|---|---|---|
| PM-001 … PM-006, PM-012 | `performance-§1` | `docs/ARCHITECTURE.md:221` — the Perf wiring declined on a bounded-cost argument, explicitly **not** a `§12` exemption | 2026-08-25 | **Not fired.** One `OnUpdate` in the repo, no repeating ticker; `updateMouseover` is still two API calls per tracked panel; the panel count is player-bounded; and `performance-§12` in v2.39.0 still requires criterion (a) with no bounded-cost clause. |
| — | `documentation-§1` (item 5) | `docs/ARCHITECTURE.md:222` — no `## What's new` on an initial release | 2026-08-07 | **Not fired.** `PanelMaster.toc:5` is still `## Version: 1.0.0`; there has been no release after it. |
| PM-008 | `events-frames-taint-§8` (the pre-formatting SHOULD) | `docs/ARCHITECTURE.md:223` — the MUST does not engage; no call site reads a combat-protected API | 2026-08-05 | **Not fired.** §8's trigger list is unchanged in v2.39.0, and the repo sweep still returns nothing from it. |
| PM-013 | `localization-§1` | `docs/ARCHITECTURE.md:224` — English-only, the second terminal state `localization-§3` names | 2026-08-05 | **Not fired.** `locales/` still holds only `enUS.lua` and `PostLoad.lua`. |
| PM-024 (the border block) | `options-ui-§16` | `docs/ARCHITECTURE.md:225` — no composer arm fits a record-backed bind; ratified 2026-09-08 as `M5-09` | 2026-09-08 | **Not fired.** `libs/LibKa0s/OptionsCompose.lua:105` still sets `row.path` unconditionally — there is no `get`/`set` arm — and `LibKa0s-Options-1.0` is still major `1.0` (`libs/LibKa0s/Options.lua:24`). |
| PM-024 (the bar block) | `options-ui-§16` | `docs/ARCHITECTURE.md:226` | 2026-09-08 | **Not fired**, same evidence. |
| PM-024 (the bar's border block) | `options-ui-§16` | `docs/ARCHITECTURE.md:227` | 2026-09-08 | **Not fired**, same evidence. |

**No register row cites a rule the standard has since changed.** Two rows' cited sections *were*
amended in v2.39.0 and both survive the amendment intact: `options-ui-§16` gained the broadcast
meta-row exemption and the finder-not-finding reading of its grep, neither of which reaches a
hand-written block that reproduces the mandated rows; and `performance-§12` was not loosened.
Reported here because `audit-review-history`'s second MUST asks for exactly this check even when it
comes back clean.

**The inverse check — a decline with no register row — also comes back clean.** Eight closed
`state:will-not-do` issues were cross-read against the register: **#31** (Perf) has its row;
**#43**/**#45**/**#46** (Widgets, Item, Pool) and **#27**/**#28**/**#29**/**#30** (library-surface
adoptions) need none, because `library-stack-§7` makes the **ship payload** whole-folder and the
**adoption** only what you use — declining to wire a major is not a deviation and so has nothing to
ratify. No un-ratified decline was found in root `CLAUDE.md`, `docs/scope.md` or a leftover
`docs/pending/LEDGER.md` (there is none).

---

## Closed since 2026-09-07

The prior run filed 8 roots and 1 dependent. **Seven of the eight are closed and one persists.**

| ID | Rule | Status | Evidence it is closed |
|---|---|---|---|
| PM-023 | `options-ui-§14` | **Closed** (`M4-15`) | All eight page-wide controls are in the chrome band: `settings/PanelEditor.lua:1047` `drawPageHeader`, `:1051` `H.PageHeader`, create box `:1075`, picker `:1091`, name `:1111`, copy-from `:1126`, Enabled `:1150`, Unlock `:1164`, Reset `:1182`, Delete `:1192`. `TAB_GENERAL` no longer exists — the only surviving mention is the comment recording its removal at `:977`. |
| PM-023a | `documentation-§5` | **Closed** (`M4-15`) | `docs/settings-panel.md:38` now reads *"four acts — Enabled, Unlock, Reset, Delete — all sit in the page's **chrome band**, above the strip"*; the paragraph that argued the old placement is gone. |
| PM-024 | `options-ui-§16` | **Ratified, not fixed** (`M5-09`) | Three register rows at `docs/ARCHITECTURE.md:225-227`, each with its own re-check trigger, plus the ruling at `:191-215`. `tests/test_options_groups.lua` pins the pairing in both directions. Moves from the tally to the *Recorded deviations* table above. |
| PM-025 | `packaging` | **Closed** (`M2-19`) | `.pkgmeta:8` ignores `.gitattributes`, `:9` ignores `.pkgmeta` itself, and `:10-15` records why `.claude` and `.superpowers` are deliberately absent. The dot-entry sweep now prints only `.git`. |
| PM-026 | `line-endings-§7` | **Closed** (`M4-10`) | The working-tree count is **0** (`03_EVIDENCE.md` § 2). The repo also now carries the gate the amended `§7` MUSTs — `tests/_kit/test_eol.lua`, kit 15 — and it reports green over the whole tracked set, agreeing with this audit's independent count. Gate and audit agreeing is the state `§7` was rewritten to produce. |
| PM-027 | `automated-tests-§4` | **Closed** (`M5-01`) | Run `20260908-181416` replaced the 19-commit-stale record; `docs/automated-tests/RESULTS.md:65` re-anchors the watch list to it; the two test files that had entered the band are now rows at `:84-85`; and `settings/PanelEditor.lua`'s fired trigger is tracked as issue #47 (`:83`). Superseded by `PM-033`, which is a much smaller and differently-graded observation. |
| PM-028 | `automated-tests-§5` | **Closed by the amendment** | v2.39.0 makes backfilling a bundle **MUST NOT** and closes the gap **forward**: *"the next run in that repository writes its analysis and notes, once, how many earlier bundles carry none."* `docs/automated-tests/20260908-181416/ANALYSIS.md:106-109` is that note — *"Three of nine bundles here carry no `ANALYSIS.md` … The first two are not getting one."* The compliant answer to this finding turned out to be the one the fix-forward disposition already chose. |
| PM-029 | `audit-review-history` | **Closed** (`M5-02`) | The `documentation-§4` row is retired, with the reason written out at `docs/ARCHITECTURE.md:231-238` and the deviation id cited. Two further rows were retired in the same pass — `options-ui-§1` and `line-endings-§5` — both because the rule moved under them, which is exactly what the register's second MUST asks a repo to do. |
| PM-030 | `options-ui-§13` | **Open** — see above | Deferred by plan at `05_TRACEABILITY.md:231`. |

**Nothing this cycle was scheduled to close and did not.** Every PanelMaster item in
`/mnt/d/Profile/Users/Tushar/Documents/GIT/Ka0sAddonsCommonTasks/docs/2026-09-07-REVIEW_AND_STANDARDS_AUDIT_REMEDIATION/05_TRACEABILITY.md`
was checked against this tree; the mapping and the per-item evidence are in `03_EVIDENCE.md` § 8.
The single carry, `PM-030`, is dispositioned **deferred** there rather than *fix*.
