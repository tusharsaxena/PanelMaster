# 05 — Final summary (2026-07-30)

> **Status: complete.** Implemented 2026-07-31 per `04_EXECUTION_PLAN.md`. Headless gate at
> **471 passed / 0 failed** (baseline 415) and `luacheck .` at **0 warnings / 0 errors in 20 files**.
> `03_SMOKE_TESTS.md`'s sign-off table is filled in: a live-client blanket pass on 2026-07-31, with
> two performance *baseline numbers* left uncaptured (noted there and in **Performance impact**
> below).
>
> Where implementation diverged from the design in `02_PROPOSED_CHANGES.md`, the divergence is
> recorded under **Accepted deviations** rather than the design being retro-edited to match.

## Headline

A full-scope review of Ka0s Panel Master at 0.1.0 found no taint, no deprecated-API use and no
load-order fragility — the addon's module boundaries, message bus, single write seams and Compat
layer are all sound — but it did find five functional bugs concentrated in two places: the **preview
(test mode) lifecycle**, where placeholder panels were written into persisted SavedVariables while
being tracked only in session state, and the **Panels settings page**, whose rebuild model both
double-rebuilt on every edit made *from* the page and never refreshed at all for edits made
*elsewhere*. This cycle fixes both, brings every geometric bound back under `core/Constants.lua`,
peels the 1253-line `settings/Panel.lua` along its editor seam, moves the addon's authored English to
the collection's US dialect, and makes two working-but-invisible slash sub-verbs discoverable. No
saved-variable schema bump was needed and no user has to reset anything.

## Counts

**Critical fixed: 0 · High fixed: 5 · Medium fixed: 10 · Low fixed: 10**

No findings deferred outright. Two items are recorded as follow-ups rather than deferrals, because
they are new work rather than unfinished work — see **Known follow-ups**.

---

## Changes by theme

### T1 — Preview mode survives a reload

**What changed.** Test-mode placeholder panels now carry an internal marker, and the addon sweeps any
marked record out of the saved layout once at database init — before the first panel is drawn.
Entering and leaving preview also routes through the same lock/unlock seam every other path uses, and
creates its three placeholders with a single repaint instead of four.

**Why it mattered.** Reloading or logging out with test mode on used to leave three `Preview: *`
panels permanently in the user's saved layout, and — because the ids that identified them were
session-only, and re-running `/pm preview` hit the name-uniqueness check and silently skipped —
the feature that created them could never remove them again. The user had to delete them by hand.
Leaving preview also failed to clear per-panel unlocks, so a panel could stay draggable after the
global state said everything was locked.

**Finding IDs covered:** F-001, F-014, F-015. **Change IDs:** C-01, C-02.

**Files touched**
- `core/Constants.lua`
- `core/Database.lua`
- `modules/Unlock.lua`
- `modules/Registry.lua`
- `tests/test_unlock.lua`, `tests/test_database.lua`, `tests/test_registry.lua`
- `docs/ARCHITECTURE.md`

### T2 — The Panels page has one rebuild trigger and refreshes scalars in place

**What changed.** The Panels settings page now rebuilds exactly once per structural change, driven
solely by the `Ka0s_PanelMaster_PanelsChanged` bus message, and refreshes individual controls in
place when a single panel's fields change — including from the command line or from a drag in unlock
mode. Open-dropdown tracking moved from one global list to a per-page one.

**Why it mattered.** Deleting, renaming or creating a panel from the page fired the bus
*synchronously*, which rebuilt the page and returned the very AceGUI widget whose callback was still
running to the shared pool; the callback then rebuilt the page a second time. Meanwhile any change
made outside the page left every slider, dropdown and colour swatch in the open editor showing stale
values — most visibly after dragging a panel. And because one global list tracked open dropdowns for
all subcategories, the Panels page's rebuild silently deregistered the General page's dropdown, so
scrolling that page no longer closed its detached list.

**Finding IDs covered:** F-002, F-004, F-005. **Change IDs:** C-03, C-04, C-05.

**Files touched**
- `settings/Panel.lua`
- `settings/PanelEditor.lua` (after the T4 peel)
- `tests/test_panel.lua`

### T3 — Every bound comes from `core/Constants.lua`

**What changed.** The panel editor's Width/Height sliders now span the registry's real limits
(`C.MIN_SIZE`…`C.MAX_SIZE`) and the X/Y sliders use a named `C.EDITOR_OFFSET_RANGE` instead of inline
literals. `Registry:Recover` derives each panel's legal offset range from its own anchor point rather
than assuming a CENTER-relative half-screen.

**Why it mattered.** A panel legitimately sized beyond 1200px — set from the CLI, or carried over
from a wider monitor — showed a slider pinned at 1200, and touching that slider silently truncated
the stored value. Separately, `/pm recover` used a CENTER-shaped bound for all nine anchor points, so
it dragged perfectly visible corner-anchored panels inward — the exact opposite of its documented
promise to leave deliberately-placed panels alone.

**Finding IDs covered:** F-003, F-006. **Change IDs:** C-06.

**Files touched**
- `core/Constants.lua`
- `modules/Registry.lua`
- `settings/PanelEditor.lua`
- `tests/test_constants.lua`, `tests/test_registry.lua`

### T4 — Structural: peel the editor, stop restating the debug gate, reunite the slash surface

**What changed.** The per-panel editor moved out of `settings/Panel.lua` into a sibling
`settings/PanelEditor.lua`; `NS.COMMANDS` moved from `settings/Schema.lua` to `settings/Slash.lua`
where its dispatcher, help renderer and every implementation already lived; and fourteen call sites
stopped re-spelling the `NS.State.debug` check that `NS.Debug` already performs as its first line.

**Why it mattered.** `settings/Panel.lua` was 1253 lines carrying four unrelated concerns —
inside the 1500 LOC cap but in the "on notice" band, and the low cohesion had already produced two of
this review's bugs. The command table living in the schema file meant the slash surface was split
across two files for no reason, with every entry a one-line trampoline back to the other one. And a
gate restated fourteen times is fourteen chances to spell it differently — one site already had.

**Finding IDs covered:** F-007, F-009, F-010. **Change IDs:** C-07, C-08, C-09.

**Files touched**
- `settings/PanelEditor.lua` (new)
- `settings/Panel.lua`, `settings/Schema.lua`, `settings/Slash.lua`
- `modules/Registry.lua`, `modules/Canvas.lua`, `modules/Unlock.lua`, `modules/DebugLog.lua`
- `core/Database.lua`
- `PanelMaster.toc`
- `tests/test_panel.lua`, `tests/test_slash.lua`, `tests/test_schema.lua`, `tests/test_debuglog.lua`
- `docs/ARCHITECTURE.md`, `docs/agent-context.md`

### T5 — One vocabulary, US English, and a help index that is the whole truth

**What changed.** Every authored English string, identifier, comment and doc line moved to US
spelling — most visibly the settings labels ("Background color", "Class color", "Accent bar color").
`/pm debug dump` and `/pm panel deleteall` are now named in the descriptions the help index and the
settings landing page generate from, and in the README's command table. The addon's one-line
description is one sentence again rather than three variants across the TOC, the landing page and the
README. Several comments that described a layout the code no longer had were corrected.

**Why it mattered.** British spelling is a documented anti-pattern in the collection's standard, and
it is at its most expensive in a locale key — where the key *is* the English string, so fixing it
later means moving every key and every call site in one change. `locales/enUS.lua` ships as the seam
for a future localization pass and carries no keys yet, which made this the cheapest possible moment.
Separately, `debug dump` is the single most useful thing to ask a user for in a bug report and it
appeared in no help output at all; `panel deleteall` is destructive and was equally invisible.

**Finding IDs covered:** F-008, F-011, F-017, F-018, F-019, F-021, F-024, F-025.
**Change IDs:** C-10, C-11, C-12.

**Files touched**
- `settings/Panel.lua`, `settings/PanelEditor.lua`, `settings/Slash.lua`
- `core/Constants.lua`, `core/Namespace.lua`, `core/Util.lua`
- `modules/Registry.lua`, `modules/Canvas.lua`, `modules/Unlock.lua`, `modules/DebugLog.lua`
- `PanelMaster.toc`, `README.md`
- `docs/ARCHITECTURE.md`, `docs/agent-context.md`

### T6 — Robustness and cheap perf

**What changed.** Settings-category registration retries once from `PLAYER_LOGIN`, and `/pm config`
now says something when there is no category rather than doing nothing. Grid-only settings writes no
longer repaint every panel. Boolean parsing rejects an unrecognized token instead of quietly storing
`false`. `Registry:DeleteAll` cleans up the session state `Registry:Delete` already cleaned up. The
unused `Compat.HasBackdrop` shim was removed.

**Why it mattered.** If `Settings` was unavailable when `OnInitialize` ran, the addon vanished from
the options list for the whole session and `/pm config` was a silent no-op — a total, silent failure
against the standard's "always present" requirement. `/pm set settings.enabled ture` used to turn
every panel off and echo `false` as though that had been asked for. And dragging the Grid size slider
repainted every panel on screen for a setting that only affects the *next* drag.

**Finding IDs covered:** F-012, F-013, F-016, F-020, F-022, F-023. **Change IDs:** C-13, C-14, C-15.

**Files touched**
- `settings/Panel.lua`, `settings/Schema.lua`, `settings/Slash.lua`
- `core/PanelMaster.lua`, `core/Compat.lua`, `core/Util.lua`
- `modules/Registry.lua`
- `tests/test_panel.lua`, `tests/test_canvas.lua`, `tests/test_schema.lua`, `tests/test_compat.lua`, `tests/test_util.lua`, `tests/test_registry.lua`, `tests/test_slash.lua`

---

## API / behavior changes

**Slash surface**
- No verb added, removed or renamed. `NS.COMMANDS` moved file (`settings/Schema.lua` →
  `settings/Slash.lua`) with its contents and order unchanged.
- Two `desc` strings extended, so `/pm help` and the settings landing page now mention
  `/pm debug dump` and `/pm panel deleteall`.
- `/pm set <boolean-path> <token>` and `/pm panel <name> <boolean-field> <token>` now **error** on an
  unrecognized token instead of storing `false`. Accepted: `true/false`, `on/off`, `yes/no`, `1/0`.
- `/pm panel deleteall` now resolves a panel actually named `deleteall` in preference to the verb.
- `/pm recover` moves strictly fewer panels: corner-anchored panels that are on screen are left
  alone.
- `/pm config` prints a tagged notice when the settings category could not be registered, instead of
  returning silently. The in-combat refusal is unchanged.

**Settings UI**
- Labels: "Background colour" → "Background color", "Border colour" → "Border color", "Accent bar
  colour" → "Accent bar color", "Class colour" → "Class color", and the matching tooltip text.
- The Panels page's editor now updates in place when a panel changes from outside the page.
- The README's Panels-page control table gained a **Defaults** row documenting that on that page it
  means "delete every panel (confirm-gated)".

**Removed defaults / new defaults:** none.

**Locale string keys:** none added or renamed — `locales/enUS.lua` still carries no keys. The
US-English sweep changed the *source* strings that a future pass will key on, which is why it was
done before any key existed.

**Internal (not a public contract):** panel records created by preview mode carry a `preview = true`
marker. It is deliberately absent from `C.PANEL_FIELD_TYPE`, `C.PANEL_FIELD_ORDER` and
`C.PANEL_TEMPLATE`, so it is invisible to `/pm panel <name>` and unsettable from the CLI, and it is
in `COPY_EXCLUDED` so `CopyFrom` cannot spread it.

**Public anchor contract:** unchanged. `PanelMaster_Panel_<slug>` frame names are untouched by every
change in this cycle.

---

## Saved-variable / migration notes

**No schema bump.** `NS.SCHEMA_VERSION` stays at **1** and `db.global.schemaVersion` is untouched.

The one persisted-shape change — the `preview` marker on placeholder records — is purely additive and
its consumer (`NS:SweepPreviewPanels`) is idempotent and safe against records that predate it: a
record with no marker is simply not a preview record, which is correct for every panel a user made
themselves. `savedvariables-§1`'s migration seam is therefore not engaged.

| Aspect | Before | After |
|---|---|---|
| `db.global.schemaVersion` | 1 | 1 (unchanged) |
| `db.profile.panels[n]` | fixed field set from `C.PANEL_TEMPLATE` | same, plus an optional internal `preview = true` on placeholders only |
| `db.profile.settings` | unchanged | unchanged |

**Existing profiles auto-migrate**, in the sense that there is nothing to migrate. Users who already
have orphaned `Preview: Chat` / `Preview: Bars` / `Preview: Minimap` panels from a pre-fix reload
will **not** have them swept automatically — those records predate the marker. They remain deletable
by hand (`/pm delete "Preview: Chat"` etc.), and the bug that created them cannot recur. No
`/pm resetall` or profile reset is required by any change in this cycle.

---

## Deprecated-API migrations

None. The review found **no** deprecated or removed API calls anywhere in addon source. Everything
that varies across builds already routes through `core/Compat.lua` per the standard, and the shims
present (`C_AddOns.GetAddOnMetadata` with a bare-global fallback, `RAID_CLASS_COLORS` keyed on the
`classFile` token, LibSharedMedia fetch/list, `MouseIsOver`, `BackdropTemplateMixin`) are all current.

The only Compat change in this cycle is a **removal**:

| Old API | New API | Files |
|---|---|---|
| `NS.Compat.HasBackdrop()` (unused shim over `BackdropTemplateMixin`) | *(removed)* — `modules/Canvas.lua` already guards on the frame instance's own `SetBackdrop` method, which is the stronger check | `core/Compat.lua`, `tests/test_compat.lua` |

---

## Performance impact

| Measurement | Before | After |
|---|---|---|
| `Canvas:RenderAll` calls per `/pm preview` toggle | 4 | 1 (confirmed in-client) |
| `Canvas:RenderAll` calls per `/pm set settings.gridSize N` | 1 | 0 (confirmed in-client) |
| Panels-page rebuilds per delete / rename / create | 2 | 1 (confirmed in-client) |
| `collectgarbage("count")` delta across 5 preview on/off cycles, 10 panels | — | **not captured** |
| `GetAddOnCPUUsage("PanelMaster")` over 60s idle, 20 mouseover panels | — | **not captured** |

The last two rows are baselines for *future* passes rather than pass/fail checks, and no numbers were
taken during the 2026-07-31 run. They remain open.

The mouseover ticker (one shared 10Hz `OnUpdate` for all tracked panels) and the name-keyed frame
pool were both reviewed and left alone — they are already the right shapes.

---

## Accepted deviations

Where the implementation departed from `02_PROPOSED_CHANGES.md`. Each was surfaced rather than
silently applied, per `CLAUDE.md`.

### The design was wrong, and the code is right

| Item | What the design said | What was built, and why |
|---|---|---|
| **C-14 / F-013** | Subscribe the retry from `addon:OnEnable`. | `OnEnable` is invoked by AceAddon *from inside its own `PLAYER_LOGIN` dispatch* — a frame that subscribes mid-dispatch does not receive that firing, and a non-LoD addon gets no second one. The retry as designed was **dead code**. Moved to `OnInitialize` (ADDON_LOADED, strictly earlier). Registration is still eager in `OnInitialize` too; nothing defers to `/pm config`. |
| **C-06 / F-003** | Have the X/Y sliders span `±C.EDITOR_OFFSET_RANGE`. | A Blizzard slider *clamps its reported value*, so a named constant alone left the bound a de-facto clamp: `/pm panel Chat x 3000` was still rewritten to 2000 on first touch, destroying exactly the multi-monitor offset `Registry.Sanitize` and audit decision A-003 exist to protect. `E.SliderSpan(value, min, max)` widens the nominal span to *reach* an out-of-range stored value; bounds and value are set together on build and on every in-place refresh. |
| **C-02 / F-014** | "Route both transitions through `U:SetUnlocked`." | Taken literally, this removed the deliberate combat-gate bypass: `/pm preview` mid-combat produced three anonymous, mouse-transparent placeholders plus an "unlock queued" message that never mentioned preview — the exact state `modules/Unlock.lua` says preview must never be in. `SetUnlocked(on, immediate)` gained a private second argument used **only** by `SetPreview`, in both directions, documented at both ends. The gated path is untouched for the CLI, the schema switch and `Toggle`, and is pinned by a test. |
| **C-06 / F-006** | The `offsetRange` helper, verbatim. | As written it indexes `rec.relPoint` with no type guard, so a nil or non-string `relPoint` from a hand-edited or older SavedVariables threw *out of* `R:Recover`'s loop — leaving already-visited panels rewritten in the DB with no broadcast and no repaint, a half-applied recover. Guarded with `Util.IsPoint`, matching `modules/Canvas.lua`'s existing shape. |
| **F-018** | Two stale "Delete and Reset live at the TOP" comments. | **Did not reproduce.** Only **one** exists — confirmed against `git show HEAD:settings/Panel.lua`, so not a peel artefact. The other comment at that location is accurate and was left alone. Ratified 2026-07-31: F-018 is recorded as a finding that was half wrong, not as work left undone. |

### Scope taken beyond the literal wording

- **`R:DeleteBatch(keys)`** added alongside `R:NewBatch`. C-02 mandates "a batched teardown" but names
  only `NewBatch`; `R:DeleteAll` would have deleted the user's own panels. Same shape, same
  one-sender guarantee. **Ratified 2026-07-31.**
- **`offsetRange` keys on `relPoint`, not `point`.** The offset is measured from the point on
  UIParent, so `relPoint` decides where the origin sits. F-006 says "point/relPoint"; drags write
  both together, so they agree in practice, and a nil or non-string `relPoint` falls back to the
  template via `Util.IsPoint`. **Ratified 2026-07-31.**
- **The peel moved slightly more than C-07's list** — `pageAction`, `runRebuilders` and
  `wirePanelsBus` went with the editor, because all three read and write the moved `selectedID`
  file-local; leaving them behind would have meant *rewriting* them rather than moving them.
  `safeRun` stayed in `settings/Panel.lua` (the General page still uses it) and is shared through a
  new internal `P.__ui` seam. `P:RefreshPanels` stayed on `NS.Panel` next to `P:Refresh`.
- **Bus subscriptions moved to `P:Register()`**, not `buildPanelsPage`. `buildPanelsPage` runs only
  on the Panels page's first `OnShow`, which needs real AceGUI widgets — so the subscriptions were
  untestable headlessly, and in-client a page never opened would miss every change made before its
  first show. Both messages share one bus target, per `architecture-§4`'s (message, target) keying.
- **Seven test seams** rather than C-05's four: `P.__pageActions`, `P.__getSelectedID`,
  `P.__setSelectedID` were needed because the headless AceGUI stub returns nil from `Create`, so page
  callbacks are never constructed and `selectedID` is a file-local. Each is commented in place.
- **`tests/wow_mock.lua`'s AceTimer-mock field `cancelled` → `canceled`** (mock-local; the vendored
  `libs/AceTimer-3.0` field is untouched), and the guarded stems inside `tests/test_spelling.lua` are
  written as concatenated halves so the guard file does not trip the grep it enforces.

### Targets missed

- **`settings/PanelEditor.lua` is 814 LOC against C-07's "~500" target.** **Accepted and closed
  2026-07-31.** `settings/Panel.lua` fell 1253 → 684, beating its own "~800". Hitting 500 on the new
  file would need a third settings file or a real restructure of the editor — neither authorized by a
  change scoped as a pure move. Both files are inside `layout-§1`'s 1000-line "on notice" threshold,
  so the stated goal of the split — no file in the oversized band — **is** met. The "~500" figure was
  an estimate made before the peel, not a requirement; it is not an outstanding target.
- ~~**Two debug gates survive C-08**~~ — **closed 2026-07-31.** C-08's risk note asserted every site's
  arguments are plain field reads, which was factually wrong for two of them: one wrapped
  `R.FormatField` (a `string.format` on a seam that fires on every field write), the other
  `NS.Registry:Get` (an O(n) scan). Rather than keep the exception, `modules/DebugLog.lua` gained
  `NS.DebugBuild(tag, fmt, build, ...)`, which calls `build` only past the sink's own gate. Both sites
  now use it with a plain file-local builder (`describeWrite`, `describeLock`) and their arguments
  passed unbound — deliberately **not** a closure, which would be allocated at the call site before
  the gate and would have been strictly worse than the gate it replaced. `grep -rn "NS.State.debug"`
  outside `modules/DebugLog.lua` is now empty, so C-08's exit criterion is met literally.
- ~~**Four sites were un-gated despite a call in their arguments**~~ — **closed 2026-07-31 by the same
  change.** `core/Database.lua`'s migrate line, `modules/Canvas.lua`'s `RenderAll` line,
  `modules/Registry.lua`'s `ReloadProfile` line and `settings/Panel.lua`'s `safeRun` stay un-gated.
  None is a repeated cost when logging is off (once per session, once per profile switch, already on
  an O(n) path, or only on a `pcall` failure), and with the deferral seam now available, any of them
  can move to `NS.DebugBuild` if that ever changes. Ratified as the intended end state.
- **Two opacity sliders still pass literal `0` and `1`.** `Constants` carries no `MIN_/MAX_ALPHA` and
  C-06 names only the size and offset sliders. `0..1` is the definition of a fraction rather than a
  chosen bound — but read literally, "no editor slider carries an inline bound" is not quite true.

### Open question for the user

**`docs/agent-context.md` was respelled to US English** as `04_EXECUTION_PLAN.md`'s M4-T1 row
instructs. That file is a verbatim local copy of the upstream Ka0s WoW Addon Standard brief, so it
now differs from `WowAddonStandards` by those words. Per `CLAUDE.md` this is either a change that
belongs **upstream** in the standard, or the local copy should be treated as **vendored text** and
restored. Not decided here.

## Known follow-ups

| Item | Why deferred |
|---|---|
| **Keep preview placeholders out of the persisted registry entirely** (a parallel in-memory record list the Canvas also renders). Architecturally cleaner than the marker-and-sweep, and it would remove the name-collision skip path too. | Rejected for this cycle because it forks the render input, which is exactly what `preview-mode`'s "same render path … not a separate mock" guidance protects. Worth revisiting if preview grows beyond three fixed placeholders. |
| **Re-run `wow-addon:standards-audit` against standard v2.13.1.** The in-repo audit bundle (`docs/audits/2026-07-30/`) was measured against **v2.11.0**; at least the `performance-§1`–`§4` wiring (vendored `LibKa0s-Perf-1.0`, the reserved `perf` verb, `PanelMasterPerfDB`) is now **MUST** and has no counterpart in this addon and no row in that bundle's deviation table. | Out of scope for a code review — that sweep is the audit agent's job, and doing it here would duplicate it. Flagged so it is not assumed to have been checked. |
| **`Registry:Reset` on a preview placeholder strips its marker**, promoting it to a permanent panel. | An acknowledged, documented edge of C-01 and strictly better than the pre-fix behavior. A cheap guard (refuse `Reset` on a marked record) is possible if it ever bites. |
| **`/pm rename` and `/pm panel` address a panel by its first word only.** | Pre-existing accepted deviation A-008 in the audit bundle, recorded in the README's Troubleshooting section. Not re-litigated here. |
| **Slider live preview.** Editor sliders commit on `OnMouseUp` only, so a panel does not follow the slider while it is being dragged. | Deliberate — a per-frame write through `Registry:Set` would broadcast a repaint per frame. Revisit only with a throttled preview path. |
| ~~**Lazy formatting at the debug sink**~~ | **Done 2026-07-31** — `NS.DebugBuild`. See **Accepted deviations**. |
| **Capture the two performance baselines** — memory delta across five preview cycles, and `GetAddOnCPUUsage` over 60s with 20 mouseover panels. | They are baselines for future comparison rather than pass/fail checks, and were not taken during the 2026-07-31 client run. Nothing depends on them. |

---

## Verification evidence

- **Smoke tests:** `docs/reviews/2026-07-30/03_SMOKE_TESTS.md` — per-change sections C-01…C-15, the
  R-01…R-16 regression suite, the T-01…T-05 taint block, the localization pass and the performance
  spot-checks. Sign-off table at the foot of that file: **blanket pass, live client, 2026-07-31**,
  with two performance baseline numbers uncaptured.
- **Headless gate:** `lua tests/run.lua` at **471 passed / 0 failed** and `luacheck .` at **0
  warnings / 0 errors in 20 files** (baseline before this work: 415/415, 0/0 in 19 files). The suite
  grew by 56 cases; the baseline was re-measured empirically from a worktree at `0283131` rather than
  assumed, and the pass-name lists diffed to confirm no case was deleted or silently skipped.
- **Adversarial verification:** five independent read-only verifiers re-read the post-remediation
  source attempting to *refute* each finding. Five claims were refuted (F-003, F-006, F-008, F-013,
  F-014); four were real defects and were repaired, one was a false alarm (preview-off cancelling a
  queued global unlock is the behavior F-014 asked for, not a regression). The repairs are the first
  table under **Accepted deviations**.
- **Commit range / PR:** _uncommitted at time of writing — the working tree carries all of it._
- **Findings:** `docs/reviews/2026-07-30/01_FINDINGS.md` (F-001…F-025).
- **Design:** `docs/reviews/2026-07-30/02_PROPOSED_CHANGES.md` (C-01…C-15, standard v2.13.1).

---

## Suggested commit message / PR description

```
fix(panelmaster): preview lifecycle, Panels-page refresh model, and bounds hygiene

Code-review pass 2026-07-30 (docs/reviews/2026-07-30/). 25 findings: 5 High,
10 Medium, 10 Low; all addressed. No schema bump, no user action required.

High
- F-001 Preview placeholders were persisted but tracked only in session state,
  so a /reload orphaned three panels permanently and `/pm preview` could never
  remove them. Records now carry an internal marker, swept once at DB init.
- F-002 Panels-page mutations rebuilt the page twice and released the AceGUI
  widget whose callback was still running. One rebuild, driven by the bus only.
- F-003 Editor sliders carried inline bounds (1200 / +/-2000) that disagreed with
  the registry's clamps, silently truncating larger stored values. Bounds now
  come from core/Constants.lua.
- F-004 An open panel editor went stale on any field change made elsewhere (CLI,
  drag, copy). Scalar controls now refresh in place on MSG_PANEL.
- F-005 One global open-dropdown list, cleared by one page, broke the other
  page's scroll-close. Tracking is per render context.

Medium / Low
- Anchor-aware /pm recover (F-006): corner-anchored on-screen panels are no
  longer dragged inward.
- settings/Panel.lua peeled into settings/PanelEditor.lua (F-007).
- US English across strings, identifiers and docs (F-008) before locales/enUS.lua
  carries any keys.
- NS.COMMANDS moved beside its dispatcher (F-010); `debug dump` and
  `panel deleteall` surfaced in the generated help and README (F-011, F-025).
- Debug gate lives only at the sink (F-009); grid-only writes no longer repaint
  (F-012); settings registration retries on PLAYER_LOGIN (F-013); stricter
  boolean parsing (F-023); assorted comment, naming and cleanup fixes.

Checked against Ka0s WoW Addon Standard v2.13.1 — no new deviation introduced;
see docs/reviews/2026-07-30/02_PROPOSED_CHANGES.md for the per-change
conformance notes.

Gate: lua tests/run.lua green, luacheck . 0/0.
```
