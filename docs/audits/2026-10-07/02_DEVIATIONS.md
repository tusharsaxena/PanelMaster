# 02 — Deviations (2026-10-07)

Measured against **Ka0s WoW Addon Standard v2.76.1 (2026-10-07)**: the index, all 27 linked
section files and `AUDIT.md` at WowAddonStandards `f472389`. Tree: `06f3c28`. Provenance is in
`01_CURRENT_STATE.md` and evidence in `03_EVIDENCE.md`.

**ID scheme.** The per-addon prefix **`PM-`** is reused. `PM-033` is carried; `PM-042`, `PM-044`,
`PM-046` and `PM-048` recur with new instances and keep their IDs. This run adds **`PM-049` …
`PM-055`** and one dependent, `PM-049a`.

**This file and `05_EXECUTION_PLAN.md` are one document.** Every figure that appears in both was
reconciled after both were written (`03_EVIDENCE.md` §13).

## Counts, with their basis

| | Count | Basis |
|---|---|---|
| **Headline tally (roots only)** | **12** | `PM-033`, `PM-042`, `PM-044`, `PM-046`, `PM-048`, `PM-049` … `PM-055`. Excludes the dependent `PM-049a` and the three gaps already ratified in `## Documented deviations` (the *Recorded deviations* table below). |
| **Total including dependents** | **13** | The 12 roots plus `PM-049a`. |
| **MUST failures (roots only)** | **10** | Every root except `PM-042` (a SHOULD) and `PM-033` (an observation). |
| **MUST failures including dependents** | **11** | `PM-049a` fails `options-ui-§12`'s Testing MUST of its own. |

**Impact grades, roots:** High 0 · Medium 1 · Low 9 · Info 2.
**Impact grades, including dependents:** High 0 · Medium 1 · Low 10 · Info 2.

Nine of the ten root MUST failures are graded **Low** or **Info**, because each is a doc, a config,
a dead code path or a degraded-load cosmetic that no player reaches on a normal install. The grade
measures impact. Every entry still names its MUST.

The one **Medium** is code behavior a player reaches on a default profile: *Reset all settings*
leaves the session-only rows where it found them (`PM-049`). Nothing this run is High. The two
behavioral Highs of the last cycle (`PM-034`) and every disabled-state check pass.

---

## Medium

### PM-049 — `options-ui-§12` (*What the row walk is left with*: session-only rows **MUST** be restored row by row) — Medium — **new**

**MUST. *Reset all settings* leaves the *Lock frame* and *Debug console* rows where they were.**

Every global-reset surface — `/pm resetall`, the composed *Reset all settings* button, the General
page's header **Defaults** button and the Settings window's footer control — ends in
`Sl:DoResetAll` (`settings/Slash.lua:36-47`), which is `db:ResetProfile()` and nothing else. That is
the right act for everything the profile holds. But `options-ui-§12` names the two things a profile
reset cannot reach — the **session-only rows**, whose storage is their own `set()` rather than the
db — and says they "MUST be restored row by row or they outlive a reset that took everything around
them". This addon has two: `state.locked` (`settings/Schema.lua:668-674`, read from
`NS.State.unlocked`) and `state.debugConsole` (`:675-682`). Neither is touched. The profile handler's
reload drops per-panel unlocks and the pending queue (`modules/Registry.lua:620-633`) but leaves the
global unlock alone.

`settings/OptionsSetup.lua:285-294` argues the omission ("deliberate rather than an oversight … The
session flags themselves are cleared by their own `set`, or by a /reload"). That is exactly the
state the rule forbids, and a decline argued in a code comment is not a register row.

**Reproduced headlessly** (`03_EVIDENCE.md` §1): two panels, unlocked, console open → accept the
reset → zero panels, `NS.State.unlocked = true`, `state.locked = false`, console still shown, and
the **next panel created is drawn unlocked** (`IsPanelUnlocked = true`).

**Why Medium.** A player reaches it on a default profile, through the control the standard makes
canonical, and the result is a profile that is not "indistinguishable from a profile the player had
just created": the *Lock frame* box stays unticked, new panels arrive outlined and draggable, and the
console stays on screen. Nothing errors and no data is lost, so it is degraded rather than broken.

**Fix direction.** After `db:ResetProfile()` returns in `Sl:DoResetAll`, restore each session-only
row to its declared default through the single write seam — `NS.SchemaRuntime.ApplyDefault` on every
`S.ProfileRows()` row carrying `sessionOnly` (or the composed `state.debugConsole` row, which the
composer marks session-only by its own `set`), so the lock goes through `NS.Unlock:SetUnlocked` with
its combat deferral and the console through `NS.DebugLog:Hide`. Keep it inside the existing bulk
bracket so the reset is still one `[Set]` line. Update the `OptionsSetup.lua:285-294` comment. Land it
test-first with `PM-049a`.

#### PM-049a — `options-ui-§12` (*Testing (MUST)*) — *derived from PM-049* — Low

**MUST.** The suite does not prove the global reset's blast radius. The reset cases
(`tests/test_slash.lua:378-409`) create **one** panel and check the count and one row; none asserts
the three other things §12's Testing paragraph names: that **two or more** created panels go, that
the **profile list** is unchanged and the active profile is still current, that the
**session-only rows were swept**, and that the **profile-changed message** (`PanelsChanged`) was
published. That is why `PM-049` shipped green.

**Why it does not graduate.** It shares its root's single change, no player reaches it separately,
and its grade is below the root's.

**Fix direction.** One case: create three panels, open a second profile, unlock and open the
console, accept the reset; assert zero panels, the profile list unchanged and current, `state.locked`
true and the console hidden, and one `PanelsChanged` on a recording receiver. Add
`-- red under: drop the session-row restore in Sl:DoResetAll` and watch it go red first.

---

## Low

### PM-050 — `slash-commands-§1` (the stub **MUST NOT** copy the library's rendering: "no copied `key = value` shape") — Low — **new**

**MUST NOT.** The library-absent Slash stub re-implements the library's coloured formatter:
`settings/Slash.lua:508-510` returns `("|cFFFFFF00%s|r = |cFFFFFFFF%s|r")`, and
`tests/test_surface_parity.lua:193-194` pins it byte for byte against `lib.FormatKV`. Pinning
prevents drift; it does not make the copy permitted. slash-commands-§1 allows a stub exactly one
library string (`DISABLED_LINE_FORMAT`, correctly carried and pinned at `:547`) and says a degraded
row "renders plainly and says so".

**Upstream tension, recorded rather than resolved here.** `testing-§8`'s worked example cites
`PanelMaster/settings/Slash.lua:316` as "a stub missing a `FormatKV` the host calls from five sites",
which is what the copy was written to cure. Both rules can be met at once: the member must exist, and
it must render plainly. The standard's example citation is stale (the stub is at `:508` now); that is
for the documentation-lane audit of WowAddonStandards.

**Grade.** Reachable only on an install missing `libs/LibKa0s`, and only as colour codes. Low.

**Fix direction.** Keep `Sl.FormatKV` on the degraded arm, uncoloured: `tostring(path) .. " = " ..
tostring(valueStr)`. Replace the byte-for-byte pin with a case that asserts the stub's line carries
the path and the value and **no** `|c` escape. Update the comment at `:501-507`.

### PM-051 — `compat` (*A dead fallback rung is deleted, not shimmed*) — Low — **new**

**MUST.** Two fallback rungs call globals no client admitted by `## Interface: 120100` provides:

- `core/EnvSetup.lua:55-57` — `GetAddOnMetadata(addonName, field)` behind
  `C_AddOns.GetAddOnMetadata`, in the Env seam's library-absent ladder. This is the section's own
  first worked case, word for word.
- `core/Compat.lua:30-33` — `GetNumAddOns` / `GetAddOnInfo` behind `C_AddOns.GetNumAddOns` /
  `C_AddOns.GetAddOnInfo` in `Compat.AddOnFolders`. The same class: the AddOns globals moved under
  `C_AddOns` before the 11.0 cut and the old names are not provided on 12.x. Confirm against the live
  client's global table (`/dump GetNumAddOns`) before deleting, as the rule asks ("dead only when
  every admitted client lacks the global").

**Grade.** Dead code: unreachable on every admitted client. Low.

**Fix direction.** Delete both rungs, keep the live rung and the caller-supplied `nil` after it.
Drop `"GetAddOnMetadata"`, `"GetNumAddOns"` and `"GetAddOnInfo"` from `.luacheckrc`'s
`read_globals` (`.luacheckrc:34`) in the same change, and update `tests/test_envsetup.lua` /
`tests/test_compat.lua` where a case drives the global rung.

### PM-052 — `architecture-§5` (named non-setting state: **naming is the compliance**) — Low — **new**

**MUST, doc-only.** LibDBIcon's own `minimapPos` writes into `db.global.minimap` — a vendored
library's writes into a table the addon hands it, class (d) of named non-setting state — are not
named in `docs/ARCHITECTURE.md` → **Settings Schema** with a storage key, one owner module and the
act that writes them. The hub mentions it only in the launcher section's table
(`docs/ARCHITECTURE.md:169`: "`minimapPos` is LibDBIcon's to write and has no row"), and
`defaults/Global.lua:70` says the same in a comment. The rule is specific about the home: Settings
Schema names each piece.

**Fix direction.** One sentence under `## Settings Schema`: storage key `db.global.minimap.minimapPos`,
owner `core/LauncherSetup.lua` (the module that hands LibDBIcon the table), written only by
LibDBIcon on a minimap-button drag. No register row.

### PM-053 — `documentation-§2` (the stub's items **MUST** appear in order) — Low — **new**

**MUST.** Root `CLAUDE.md` carries every required item, but item 6, the provenance line
(`CLAUDE.md:45`), sits **before** item 5, the green-gate line (`CLAUDE.md:62`). documentation-§2:
"It **MUST** contain, in this order". The perf-decline paragraph (`:53-60`) sits between them.

**Fix direction.** Move the green-gate paragraph (`:62-65`) up to follow the pointer list (`:28-35`),
then the LibKa0s paragraph and the provenance line. Content unchanged; the vendored-payload gate
reads the line by pattern, so its position does not affect `tests/test_vendor_sync.lua`.

### PM-054 — `automated-tests-§3` (*The complexity gate is sighted*: every gate line quotes the runner, never the raw `lizard`) — Low — **new**

**MUST.** `docs/automated-tests/README.md:29`, the gate table's `complexity` row, quotes
`` `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` `` as the command — the blind invocation,
without even the `-L 1500` the fixed command now carries. The section: the command "every gate line,
every playbook and every `CLAUDE.md` quotes" is `bash tests/_kit/run-automated-tests.sh --suite
complexity`; "the raw `lizard -l lua ...` line is the blind one" (anti-pattern #92). `docs/testing.md:242`
already quotes the runner correctly, so the two tables disagree.

**Fix direction.** Replace the cell with `bash tests/_kit/run-automated-tests.sh --suite complexity`
and the sighted-shadow note `docs/testing.md:242` carries.

### PM-046 — `documentation-§1` (README shipped content) — Low — **recurring**

**MUST ×2.** Closed by `PM-24` (`bf1291d`) and reintroduced by the `/pm profile` verb (`9bceeab`,
2026-09-29):

1. **Angle-bracket placeholders** in shipped README content: `README.md:65` and `:229`,
   `` `/pm profile <name>` ``. CurseForge strips `<name>` as an unknown tag, even in backticks, so
   players read `/pm profile` with the argument gone.
2. **An un-prefixed highlight.** The 1.2.0 row (`README.md:271`) ends
   `<br>Released on lint, tests and complexity only: …` with no `- `. documentation-§1 item 11:
   "Every highlight in the Highlights cell **MUST** be prefixed `- `".

**Fix direction.** Write the argument bare (`` `/pm profile Raid` `` or "`/pm profile` followed by
the profile's name"), and prefix the last 1.2.0 highlight with `- `. Run the de-AI pass the section
MUSTs on README edits.

### PM-044 — `documentation-§5` (keep docs in sync) — Low — **recurring**

**MUST.** Docs, the register and comments that no longer describe the tree, every item re-derived:

| Where | Says | Tree says |
|---|---|---|
| `docs/ARCHITECTURE.md:390-391` (census prose) | largest authored file `tests/test_libka0s.lua` at **1160**, largest shipped `modules/Registry.lua` at **987** | **1184** and **972** (`wc -l`, `03_EVIDENCE.md` §5) |
| `docs/ARCHITECTURE.md:349` (the `events-frames-taint-§8` register row's **Why**) | "the only unit/client APIs it calls at all are `UnitClass` and `C_AddOns.GetAddOnMetadata`" | no `UnitClass` call remains (the class lookup is LibKa0s Core's); `UnitAffectingCombat` is called (`core/Compat.lua:88`) |
| `docs/testing.md:242` | complexity measured over "kit revision 36" | kit **37** (`tests/_kit/framework.lua:20`) |
| `core/LifecycleSetup.lua:53-54` | the launcher's "LEFT click does changes, and that gate is in that file" | left-click opens settings in either state since Launcher minor 4 |
| `core/LifecycleSetup.lua:117-118` | re-registers "the same three events core/PanelMaster.lua's OnEnable registers" | `OnEnable` registers none; `NS.StandUp` does |
| `core/LauncherSetup.lua:226` | "Register runs at OnEnable" | `NS.Launcher:Register()` is called from `OnInitialize` (`core/PanelMaster.lua:40`) |
| `settings/Slash.lua:317-318` | "`/pm help`, **the README's command table** and the settings landing page all generate from this" | the README carries no command table (documentation-§1 item 5) |
| `settings/Slash.lua:366-367` | the lock verbs write through "the same single write seam the … checkbox and **the minimap button's left click** write through" | the left click opens settings; the menu's *Locked* entry is the writer |
| `settings/Slash.lua:699-701` | republished "because the LAUNCHER'S left click prints it too (launcher-§2, §7)" | the launcher prints no refusal line; and the bare `§7` reads as `launcher-§7`, which does not exist (launcher has five subsections) |

**Fix direction.** One doc-and-comment sweep. Re-derive every figure with the command beside it;
for the register row, re-run the trigger-set sweep and restate the API list. Re-date nothing in the
row's **Decided** column — the decision is unchanged.

### PM-042 — `documentation-§3` (the hub shape: *the whole file SHOULD stay under roughly 400 lines*) — Low — **recurring**

**SHOULD.** `docs/ARCHITECTURE.md` is **422** lines. Its mandated sections are inside the spill
threshold except `## Documented deviations`, which with its census runs **100** lines
(`:323-422`). Of those, about **50** are history rather than register: the Perf-decline preamble
(`:333-344`), the retired-row list (`:352-370`) and the census's peel narrative (`:384-420`). The
spill rule names no topic doc for the register, so this files the length SHOULD only.

**Fix direction.** Cut the peel narrative to one line citing the automated-tests bundles that
recorded each peel, the preamble to the row it explains, and each retired-row entry to its date and
evidence id. Target under 400.

### PM-048 — `audit-review-history` (*A re-vendor commit implies a bundle*) — Low — **recurring**

**MUST.** Two tags were vendored after the store's first bundle with no bundle naming them and no
register row: **v1.69.0** (`4e15691`, 2026-10-06) and **v1.70.0** (`f61f2b7`, 2026-10-07). The
playbook's two-listing check, run verbatim (`03_EVIDENCE.md` §11): 54 commits touching the payloads
since the `2026-08-25` horizon, 51 distinct tags vendored, 49 recorded. Last cycle's backlog of 25 is
discharged by the span bundle `docs/revendor/2026-09-24-v1.16.0-v1.54.2/` and the per-tag bundles
since.

**Fix direction.** One span bundle, `docs/revendor/<date>-v1.69.0-v1.70.0/`, with `01_DELTA.md`
line 1 `Delta: LibKa0s v1.68.1 -> v1.70.0 (span: v1.69.0 v1.70.0)` and a `05_SUMMARY.md` line per tag
(v1.69.0 added `WidgetsLineChart.lua`, v1.70.0 `WidgetsAutocomplete.lua`; neither adopted here).

---

## Info

### PM-055 — `audit-review-history` (the status is the label: `state:triaged` means **open**) — Info — **new**

**MUST.** Issue **#47** ("settings/PanelEditor.lua has crossed its own recorded split trigger") is
**closed** (2026-09-26) and still labeled `state:triaged`, a status the vocabulary reserves for open
issues. The work it tracked landed (`5119ae1`, `PM-ATS-02`). Every other issue's label and state
agree (`03_EVIDENCE.md` §10).

**Fix direction.** Relabel #47 `state:done` (`gh issue edit 47 --remove-label state:triaged
--add-label state:done`) with a one-line comment citing `5119ae1`.

### PM-033 — `automated-tests-§4` (anti-pattern #51) — Info — **carried**

**Observation.** The record is stale between releases, as expected. The newest bundle,
`20260927-032003` (`8cda106`, clean), is **52** commits behind HEAD, and it predates the sighted
gate (kit 35), so it is also the last **unsighted** record. Re-measured at HEAD with the verbatim
runner:

| Figure | Recorded `20260927-032003` | HEAD `06f3c28` (sighted) |
|---|---|---|
| tests (passed/skipped/total) | 964/0/964 | 1035/1/1036 |
| luacheck files | 68 | 71 |
| lizard NLOC | 16138 | 17349 |
| lizard functions | 1917 | 2168 |
| avg CCN / max CCN / warnings | 2.0 / 15 / 0 | 2.0 / 15 / 0, blind files 0 |

Nothing crossed CCN 15, so the first sighted measurement finds no hidden function above the
threshold. One file **newly entered** the 1000–1500 band: `tests/test_slash.lua` (1084); it will
arrive in the watch list with a blank disposition and owes one at the next release.
`tests/test_libka0s.lua` moved 1131 → 1184, still under its recorded 1300 trigger. The one
*Accepted* entry has one release run behind it, so no shelf-life breach. The generated lead-in at
`docs/automated-tests/RESULTS.md:15` still names `/wow-addon:bump-version`; the kit-37 runner emits
`/dev-copilot:bump-version`, so the next run corrects it.

**Fix direction.** At the next release, run the full battery as a release run, disposition
`tests/test_slash.lua`, and let the bundle's `ANALYSIS.md` note that this is the first sighted record.

---

## Recorded deviations — accepted, not counted

Each row below is a gap this run would otherwise file, matched to a ratified row in
`docs/ARCHITECTURE.md` → `## Documented deviations` (`:346-350`). None counts toward either tally.
Triggers were evaluated against `06f3c28` and every cited id resolved (`03_EVIDENCE.md` §7).

| Rule | Row | Decided | Trigger evaluated | Evidence ids |
|---|---|---|---|---|
| `performance-§1` | `:348` — Perf wiring declined, **not** a §12 exemption | 2026-08-25 | **Not fired.** One `OnUpdate` (`modules/Canvas.lua:662`); the only AceTimer use is the one-shot colour-picker throttle (`settings/OptionsSetup.lua:260`); `updateMouseover` is still one `MouseIsOver` and one `SetAlpha` per tracked panel (`:628-641`); `performance-§12` has no bounded-cost clause at v2.76.1 | #31 (closed, will-not-do), #44 (closed, done) — resolve; `modules/Canvas.lua:647-652` and `core/Constants.lua:317` re-read and resolve |
| `events-frames-taint-§8` (pre-formatting SHOULD) | `:349` | 2026-08-05 | **Not fired.** Trigger-set sweep over the shipped source returns 0; the trigger list is unchanged upstream. The row's API inventory is stale (filed under `PM-044`, not here) | — |
| `localization-§1` | `:350` — English-only, localization-§3's second terminal state | 2026-08-05 | **Not fired.** `locales/` holds `enUS.lua` and `PostLoad.lua` only | `locales/enUS.lua:6`, `:8-10` resolve |

**No row's cited rule has changed under it** at v2.76.1.

**Declines with no row, checked by inverse.** The closed `state:will-not-do` issues (#4, #16, #17,
#18, #24, #25, #27–#31, #43, #45, #46, #51, #53, #55) were cross-read. #31 has its row; #16
(player-class colour) is what `options-ui-§17` prescribes for chrome; #43/#45/#46/#53/#55 decline
optional adoptions or a MAY and owe no row; the rest are decisions with no rule behind them. The one
reasoned decline with **no** row is the session-only-row omission in `settings/OptionsSetup.lua:285-294`,
which is filed as a defect (`PM-049`) rather than as a missing row, because the rule leaves no room
to ratify it.

**Not filed, on purpose.**
- The Panels page's two live refresh subscriptions surviving the stand-down: `open-evolutions`
  records the question and rules neither reading.
- `lock`/`unlock` as verbs: a MAY, present and compliant.
- `docs/localization.md`, `media.md`, `rendering.md`, `artwork-spec.md`: Tier 3 names, registered.
- The hub's missing self-row: a MAY, filed in neither state.
- 74 elided short-form citations (`§2's`, `§7`) that follow a full `filename-§N` in the same
  sentence; the standard's own prose uses the same elision, and the full-form range check over
  1250 citations finds none malformed or out of range (`03_EVIDENCE.md` §12). The one ambiguous
  elision is folded into `PM-044`.
- `## Credits` names the LibKa0s payload as where the JetBrains Mono font ships (`README.md:282`);
  the line is the font's external credit, not a library inventory.
- **Outside the standard, passed to review:** the *Delete all panels* confirmation reads "on this
  character" (`settings/Slash.lua:81`), while panels live in the profile, which every character
  shares by default (`core/Database.lua:3-14`); the warning understates the blast radius.

---

## Closed since 2026-09-23

| ID | Rule | Status | Evidence |
|---|---|---|---|
| PM-031 | `documentation-§3` | **Closed** (`b81f450`) | `docs/compat-layer.md` present; map row "Present", `docs/ARCHITECTURE.md:300` |
| PM-034 / 034a | `slash-commands-§7` | **Closed** (`af56239`) | `modules/Canvas.lua:810`, `:837`; `tests/test_disabled.lua:253` (routes A, B, C) |
| PM-035 | `events-frames-taint-§1` | **Closed** (`8ccee1c`) | `core/LifecycleSetup.lua:141`, `core/PanelMaster.lua:67` |
| PM-036 / 037 | `toc-file-§5` | **Closed** (`10f750c`) | `PanelMaster.toc:59-61`, `:121-123` |
| PM-038 / 038a | `savedvariables-§1` | **Closed** (`dea8d67`) | `defaults/Global.lua:74`; `docs/ARCHITECTURE.md:32` |
| PM-039 | `audit-review-history` | **Closed** (`b58cba5`, #54) | row retired, `docs/ARCHITECTURE.md:354-359` |
| PM-040 | `testing-§8` | **Closed** (`e2a8ce9`) | `tests/test_surface_parity.lua:286` |
| PM-041 | `localization-§5` | **Closed** (`7db8c12`; kit 26 skip list) | spec line 5 reads "catalogued"; `tests/_kit/prose_lists.lua:82` |
| PM-043 | `documentation-§3` | **Closed** (`d4b014c`) | all 75 authored files named in `docs/module-map.md` |
| PM-045 | `documentation-§7` | **Closed** (`2e1dc64`) | every kit citation in `DEPENDENCIES.md:63` re-read and resolves |
| PM-047 | `audit-review-history` | **Closed** | #19, #20, #22, #23, #24 all closed with the right labels |
| PM-042, PM-044, PM-046, PM-048 | — | **Recurring**, new instances above | |
| PM-033 | `automated-tests-§4` | **Carried** (Info) | above |
