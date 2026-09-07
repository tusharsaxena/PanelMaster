# Final summary — Ka0s Panel Master review cycle, 2026-09-07

> **Written ahead of implementation.** This is the artifact to paste into the PR once
> [`04_EXECUTION_PLAN.md`](04_EXECUTION_PLAN.md) has been executed and every case in
> [`03_SMOKE_TESTS.md`](03_SMOKE_TESTS.md) has passed. Numbers marked *(to confirm)* are filled in
> from the post-change run; nothing here is a measurement until it is.

---

## Headline

A full-scope review of Ka0s Panel Master found the addon **ship-ready**, with every out-of-game
suite green on the day: `luacheck` clean across 27 files, 763 of 763 headless cases passing, zero
functions above the complexity threshold, and the generated test inventory and README badge both
already agreeing with the live run. The work in this cycle is therefore corrective rather than
rescuing.

The one finding that reaches outside the addon is a shared-library one: a cosmetic fixup for a
border dropdown was implemented by re-registering the `LSM30_Border` widget type in AceGUI's
**global** registry, so PanelMaster silently changed the appearance of that dropdown in every other
addon in the session — and four sibling Ka0s addons ship the same file, chaining wrappers on top of
each other. That is now scoped to the widgets this addon builds. Alongside it: two small parse and
state bugs a user can hit through documented commands, a diagnostic line that read a fallback
constant instead of the version seam the docs promised, a 1350-line file peeled before it hit the
size cap, a ticker that kept ticking after it had nothing to tick, and one rationale comment that
described an implementation deleted three commits earlier.

---

## Counts

`Critical fixed: 0 · High fixed: 1 · Medium fixed: 5 · Low fixed: 2`

**Deferred, with reasons:**

| Finding | Why deferred |
|---|---|
| F-008 (`docs/automated-tests/RESULTS.md` stale) | Regeneration in place is a **release** checkpoint owned by `/wow-addon:bump-version` (`automated-tests-§3`). Hand-editing it would be worse than leaving it stale, because it would read as measured |
| F-009 (no zero-overhead evidence for the polled path) | The `performance-§1` decline is **ratified** in `docs/performance.md` with a `## Documented deviations` row. Not reopened; recorded so the next reader knows every perf statement in the bundle is read off source, not measured |
| F-010 (five LF stragglers in a CRLF-pinned tree) | Owned by `/wow-addon:standards-audit`, which holds the authoritative count. Landed as its own commit (M4-T1) rather than folded into any code change, so a whole-file line-ending diff cannot bury a real one |
| F-011 (LibKa0s source line endings) | **Different repo.** No local edit is permitted under `libs/` |

---

## Changes by theme

### Theme A — stop editing shared singletons

**What changed.** PanelMaster's border-dropdown layout fixup is now applied to each dropdown it
builds, at the moment it builds it, instead of being installed into `AceGUI-3.0`'s shared
`WidgetRegistry` at `PLAYER_LOGIN`. The dropdowns inside PanelMaster's own settings panel look
exactly as they did; every other addon's border dropdown is left alone.

**Why it mattered.** `AceGUI-3.0` is a LibStub singleton, so its widget registry is one table the
whole session shares. Re-registering `LSM30_Border` meant a third-party addon's dropdown lost its
preview swatch and shifted, with nothing to attribute it to PanelMaster. The same file ships in
AbsorbTracker, ConsumableMaster, KickCD and MultiMeters, so a player running several Ka0s addons had
a chain of wrappers each wrapping the last.

**Findings covered:** F-001. **Change:** C-01.

**Files touched.**
- `core/LSMPatch.lua`
- `settings/PanelEditor.lua`
- `tests/test_panel.lua`

### Theme B — one session-state sweep instead of two that disagreed

**What changed.** `Registry:DeleteAll` and the profile-switch sweep now share a single function that
clears the per-panel unlock set, the preview id list **and** the preview flag. Previously
`DeleteAll` cleared the first two and left the flag set.

**Why it mattered.** After `/pm panel deleteall` with test mode on, the Master-controls **Test mode**
checkbox read ticked with nothing on screen, and the next press of it did nothing a user could see —
it merely flipped the stale flag off. The sibling function's own comment already named this exact
failure as the reason the flag must be cleared with the ids; the two copies of the rule had drifted.

**Findings covered:** F-002. **Change:** C-02.

**Files touched.**
- `modules/Registry.lua`
- `tests/test_registry.lua`

### Theme C — parse what the user meant, and pin it with a test that can fail

**What changed.** Two things. `Util.ParseColor` now decides the alpha component separately from RGB,
so a byte-scale colour with the conventional shorthand alpha (`255,0,0,1`) is read as fully opaque
instead of as alpha `0.004`. And the `[Init]` diagnostic summary now resolves the addon version
through `NS.Version()` — the `LibKa0s-Env-1.0` seam — instead of reading the fallback constant
directly.

**Why it mattered.** The colour case produced an invisible panel with no error to explain it, from
an input almost everyone would read as "opaque red". The version case had no symptom today, because
the TOC version and the fallback constant happen to be equal — but the seam exists precisely so the
packaged version wins, and its own header already claimed the database summary went through it. The
existing test could not tell the two apart: it asserted against the same constant the code read.
Both cases are now falsifiable.

**Findings covered:** F-003, F-004. **Changes:** C-03, C-04.

**Files touched.**
- `core/Util.lua`
- `core/Database.lua`
- `tests/test_util.lua`
- `tests/test_database.lua`
- `tests/wow_mock.lua`

### Theme D — structural hygiene ahead of the cap

**What changed.** `settings/PanelEditor.lua` was peeled along its own section boundaries into sibling
files under `settings/`; the mouseover fade driver clears its `OnUpdate` script when the last
tracked panel is untracked and re-installs it when one returns; and the settings descriptor's
rationale for declining the library's `RestoreAllDefaults` was rewritten to describe the reset this
addon actually performs.

**Why it mattered.** `PanelEditor` was 1350 lines and had grown 543 in one branch — 150 short of the
1500-line cap, which meant the next feature on that page would have forced the split under schedule
pressure. The ticker was doing per-frame work for a tracked set that could be empty for the rest of
the session. The comment described a row-walk reset that had been replaced by a profile reset, so
anyone re-evaluating the decision would have tested the wrong proposition.

**Findings covered:** F-005, F-006, F-007. **Changes:** C-05, C-06, C-07.

**Files touched.**
- `settings/PanelEditor.lua` and its new siblings under `settings/`
- `PanelMaster.toc`
- `modules/Canvas.lua`
- `settings/OptionsSetup.lua`
- `tests/test_canvas.lua`

### Theme E — evidence upkeep

**What changed.** Nothing in source. The five LF stragglers were renormalised as their own commit;
the stale automated-test record is left for the next release to regenerate.

**Findings covered:** F-008, F-009, F-010. **Change:** C-08.

---

## API / behaviour changes

| Surface | Change |
|---|---|
| `/pm panel <name> <colorField> r,g,b,a` | A byte-scale colour with a fourth component `<= 1` now reads that component as a **fraction**. `255,0,0,1` was alpha `0.004`; it is now alpha `1.0`. `255,0,0,255` is unchanged. Stored colours are unaffected — only new parses |
| `/pm panel deleteall` and the settings **Delete all** button | Now also turn **Test mode** off. Previously the checkbox stayed ticked with no sample panels behind it |
| `[Init]` debug line | Reports the packaged TOC `## Version` rather than `core/Namespace.lua`'s fallback constant. Identical output today (both `1.0.0`); differs the moment they diverge |
| Other addons' `LSM30_Border` dropdowns | **No longer modified by PanelMaster.** Anyone who had come to expect the swatch-less look collection-wide will see it only inside Ka0s panels that opt in |
| Slash grammar | **Unchanged.** No verb added, removed or renamed; `NS.COMMANDS` is untouched |
| Locale keys | **None added or renamed.** The addon still ships English-only with no string routed through `NS.L` |

---

## Saved-variable / migration notes

**No schema change.** `NS.SCHEMA_VERSION` stays at **2** and `NS:RunMigrations` is untouched. No
default was added, removed or altered in `defaults/Profile.lua` or `defaults/Global.lua`, and no
stored value's meaning changed. Existing profiles load unchanged and no `/pm reset` is required.

The colour-parse change (C-03) affects **parsing only** — a colour already stored as
`{1, 0, 0, 0.004}` from the old reading stays exactly that until the user re-enters it. If a panel
was accidentally made invisible this way, re-typing the colour is the fix; there is deliberately no
migration, because a stored `0.004` alpha is indistinguishable from one a user chose.

---

## Deprecated-API migrations

**None.** The review found no deprecated or removed API in use. `core/Compat.lua:29-35` already
prefers `C_AddOns.GetNumAddOns` / `C_AddOns.GetAddOnInfo` with a guarded legacy ladder,
`BackdropTemplate` is used wherever `SetBackdrop` is, and the settings pages register through
`Settings.RegisterCanvasLayoutCategory` / `RegisterCanvasLayoutSubcategory` rather than the removed
`InterfaceOptions_AddCategory`. This section is retained empty so a future reviewer can see the
sweep was done, not skipped.

---

## Performance impact

**No measured numbers, and deliberately none claimed.**

Ka0s Panel Master ships **no `tests/perf.lua`**, no `PanelMasterPerfDB`, no `perf` slash verb and no
`docs/perf-analysis/` bundles. That is a **ratified `performance-§1` deviation**, decided 2026-08-25,
reasoned in `docs/performance.md` and carrying its row in `ARCHITECTURE.md`'s
`## Documented deviations`. There is consequently no scenario and no capture to put a before/after
figure against C-06's ticker change.

What C-06 does is structural and can be stated without a number: an `OnUpdate` that ran every frame
for the remainder of the session no longer runs once the tracked set empties. The smoke-test step
that accompanies it is an observation, not a measurement, and no claim in this bundle rests on it.
An estimate is not offered in place of a record.

---

## Test and complexity movement

| | Before (measured 2026-09-07) | After |
|---|---|---|
| Headless cases | **763 passed, 0 failed, 0 skipped** | *(to confirm — expect +3 or more: C-01, C-02, C-03 and C-06 each add at least one)* |
| `luacheck` | **0 warnings / 0 errors in 27 files** | *(to confirm — must stay 0/0; file count rises with the C-05 split)* |
| `lizard` | **12122 NLOC, 1472 functions, avg CCN 2.0, max CCN 15, 0 warnings** | *(to confirm — NLOC roughly flat, max CCN unchanged)* |
| Largest file | `settings/PanelEditor.lua` at **1350 LOC** | *(to confirm — out of `layout-§1`'s 1000–1500 band)* |

`docs/test-cases.md` and the README `[tests]` badge moved **in the same commit** as every change that
moved the pass count, per `testing-§7`. Neither was hand-edited; the inventory is emitted by
`lua5.1 tests/run.lua --list`.

**Expected watch-list movement at the next release.** `docs/automated-tests/RESULTS.md` is
regenerated by `/wow-addon:bump-version`, not here. Its newest row currently records the state of
2026-08-25 (731/731 cases, 11223 NLOC, 1379 functions) and already understates today's tree, before
any of this work. The next regeneration should show the case count up, NLOC roughly flat, and
`settings/PanelEditor.lua` no longer the largest file. Max CCN should stay at 15 — nothing in this
cycle was justified as a complexity fix, and today's run finds zero functions above threshold.

---

## Known follow-ups

| Item | Rationale for deferring |
|---|---|
| Promote the border-dropdown fixup into `LibKa0s-Options-1.0`'s widget makers as an **opt-in** field | The right destination if the collection wants the look canonical — but it must clear `library-stack`'s promotion bars (2+ consumers with the same semantics, no per-consumer flags, a stable shape), and retiring the four sibling copies belongs in the same cycle. C-01 unblocks it by making the per-widget form exist |
| Retire `core/LSMPatch.lua` from AbsorbTracker, ConsumableMaster, KickCD and MultiMeters | Same defect, four other repos. Out of scope for a PanelMaster PR; the finding is tagged cross-cutting so it is not lost |
| `docs/automated-tests/RESULTS.md` regeneration | Release checkpoint (`automated-tests-§3`), never mid-cycle, never by hand |
| Revisit the `performance-§1` decline if the mouseover driver grows | Today it is a `MouseIsOver` call per tracked panel at 10Hz. The decline is ratified on that basis; the trigger to reopen it is the basis changing |
| `NS.L` remains unused | An explicit 1.0.0 scope decision recorded in `locales/enUS.lua`. Both seam files correctly refuse to hand `NS.L` to a library descriptor, and the suite tripwires that. Nothing to do until a localization pass is scheduled |

---

## Verification evidence

- Headless measurement: `01_FINDINGS.md`, **Measurement run** block — every command, its scope and
  its real output, all run 2026-09-07.
- In-client verification: `03_SMOKE_TESTS.md` with its sign-off table completed.
- Commit range / PR: *(fill in)*.

---

## Suggested PR description

```
fix: scope the border-dropdown fixup, and four smaller correctness fixes

Review bundle: docs/reviews/2026-09-07/

The one that reaches outside this addon (F-001): core/LSMPatch.lua installed its
LSM30_Border layout fixup into AceGUI-3.0's *shared* WidgetRegistry at PLAYER_LOGIN.
AceGUI is a LibStub singleton, so that changed the appearance of every other addon's
border dropdown for the session, unattributably -- and four sibling Ka0s addons ship
the same file, each wrapping the last. The fixup is now applied per widget, at
PanelMaster's own creation site. The look inside this addon is unchanged.

Also:
  F-002  Registry:DeleteAll cleared the preview ids but not the preview flag, so
         `/pm panel deleteall` with test mode on left the checkbox ticked with
         nothing behind it. One sweep now serves both call sites.
  F-003  Util.ParseColor divided the alpha by 255 whenever RGB were bytes, so
         `255,0,0,1` -- opaque red to any reader -- parsed as alpha 0.004 and drew
         an invisible panel. The fourth component is decided separately now.
  F-004  NS.InitSummary read core/Namespace.lua's fallback constant, not
         NS.Version(), which core/EnvSetup.lua's own header says it uses. The test
         asserted against the same constant and could not fail; it can now.
  F-005  settings/PanelEditor.lua (1350 LOC, +543 in one branch) peeled along its
         section boundaries, ahead of layout-§1's 1500-line cap. No behaviour change.
  F-006  The mouseover fade driver's OnUpdate ran every frame for the session once
         created. It unhooks when nothing is tracked.
  F-007  Corrected the settings descriptor's rationale for declining
         O.RestoreAllDefaults -- it described a row-walk reset replaced by a profile
         reset three commits earlier.

Not in this PR, on purpose:
  F-008  docs/automated-tests/RESULTS.md is stale (records 731/731 against today's
         763/763). Regenerated at release by /wow-addon:bump-version, never by hand.
  F-011  Two LibKa0s *source* files are LF in a CRLF-pinned repo, which makes a
         hand-run vendor diff report false drift. Fixed in LibKa0s; no minor bump,
         no re-vendor needed -- the bytes vendored here are already correct.

Baseline measured 2026-09-07: luacheck 0/0 in 27 files, 763/763 headless cases,
lizard 12122 NLOC / 1472 functions / max CCN 15 / 0 warnings.

No schema change (SCHEMA_VERSION stays 2), no slash-grammar change, no locale keys.
No perf figures are claimed: this addon declines the perf harness as a ratified
performance-§1 deviation, so there is no record to cite and an estimate is not offered
in its place.

Standard: Ka0s WoW Addon Standard v2.38.0 (2026-09-02).
```
