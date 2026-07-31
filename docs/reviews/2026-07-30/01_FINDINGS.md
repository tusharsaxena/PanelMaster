# 01 — Findings (2026-07-30)

**Verdict: minor issues.** The addon is architecturally sound, loads cleanly, passes its own gate
(`lua tests/run.lua` → 415/415, `luacheck .` → 0/0), and its module boundaries, message bus, write
seams and Compat layer are all in the right places. Five **High** findings are functional bugs in the
preview lifecycle and the Panels settings page that should land before a first public release;
nothing is blocking in the sense of "does not load" or "taints the client".

**Scope:** whole addon (`core/`, `defaults/`, `locales/`, `modules/`, `settings/`, TOC, `.pkgmeta`,
`.luacheckrc`, README). `libs/` (vendored) and `tests/` were read for context but are not reviewed
for style.

## Standards cross-check

The Ka0s WoW Addon Standard was fetched successfully and resolved at **v2.13.1 (2026-07-30)**
(`standards/STANDARDS.md` + all 24 section files discovered from its Sections list). Every fix
direction below was checked against it; where a rule shaped or vetoed a fix it is cited as
`filename-§N`.

Two notes that are **not** findings, recorded so the reader is not misled:

- This is a **review**, not a compliance audit. The full section-by-section deviation sweep belongs
  to `wow-addon:standards-audit`. Pre-existing deviations unrelated to the findings below are not
  enumerated here.
- The in-repo audit bundle (`docs/audits/2026-07-30/`) was measured against standard **v2.11.0**.
  The standard has moved to v2.13.1 since, and at least two sections that are now **MUST** wiring
  (`performance-§1`–`§4`: vendored `LibKa0s-Perf-1.0`, the `perf` reserved verb, `PanelMasterPerfDB`)
  have no counterpart in this addon and no entry in that bundle's deviation table. That gap belongs
  to a re-run of the audit agent against v2.13.1, not to this review — flagged here only so it is not
  assumed to have been checked.

---

## High

### F-001 — Preview panels are written into persisted SavedVariables but tracked only in session state `[bug]`
`modules/Unlock.lua:255-292` (with `core/State.lua:28-32`, `core/Constants.lua:256-263`)

`U:SetPreview(true)` creates the three `Preview: *` placeholders through `NS.Registry:New`, which
writes them into `db.profile.panels` — persisted — while the only record of *which* panels are
placeholders is `NS.State.previewIDs`, which is session-only and is wiped by any `/reload` or logout.

**Impact:** a user who reloads or logs out with test mode on is left with three real panels in their
saved layout forever, and cannot remove them with the feature that created them: re-running
`/pm preview` on hits the registry's name-uniqueness check, silently skips all three placeholders,
leaves `previewIDs` empty, and the subsequent `off` therefore deletes nothing. They must be deleted
by hand, one at a time. This also breaks `preview-mode`'s "**MUST** clear the preview … when the
preview verb is toggled off".

**Fix direction:** the preview lifecycle must survive a reload. Mark preview records at creation and
sweep them once at DB init (before the first render), or keep placeholders out of the persisted
registry entirely. Do **not** "fix" it by persisting `NS.State.preview` — `preview-mode` and this
addon's own `core/State.lua` rationale both make preview an editing state, and persisting it would
also contradict the session-only treatment `debug-logging-§5` establishes for the sibling flags.

### F-002 — Panels-page mutations rebuild the page twice, releasing the widget whose handler is still running `[bug]`
`settings/Panel.lua:678-689, 720-729, 770-790, 965-975` and `settings/Panel.lua:1057-1065`

Every registry mutation made from the Panels page fires `Ka0s_PanelMaster_PanelsChanged`
*synchronously* inside the call. `P.__evPanels` is subscribed to it and, because the page is on
screen, runs `runRebuilders(ctx)` — which calls `listGroup:ReleaseChildren()` and returns the Delete
button (or the rename `EditBox`) to the AceGUI pool **while that widget's own callback is still on
the stack**. The callback then continues and runs `runRebuilders(ctx)` a second time.

**Impact:** a use-after-release on a shared AceGUI widget (AceGUI's `Button_OnClick` touches
`frame.obj` again after `Fire` returns), plus a full double teardown/rebuild of the editor for every
delete, rename and create. On delete the first rebuild also still sees the stale `selectedID`, so the
selection lands on `records[1]` twice rather than once.

**Fix direction:** one rebuild trigger. Let the bus subscription be the sole rebuild path and drop
the manual `runRebuilders` after each mutation (setting `selectedID` *before* mutating), so no
handler can release itself.

### F-003 — Panel-editor sliders carry inline bounds that disagree with the registry's clamps `[bug]`
`settings/Panel.lua:796-802` (`1200`, `-2000`, `2000`) vs `core/Constants.lua:61-62`
(`C.MAX_SIZE = 4096`) and `modules/Registry.lua:56-61` (x/y deliberately unclamped)

`numberField(sizeRow, "Width", "width", C.MIN_SIZE, 1200)` and the ±2000 offset sliders are the only
place in the addon that decides a bound with a literal — the file's own header comment says
"Named, never inlined (options-ui-§8)".

**Impact:** a panel legitimately sized 2000px wide (CLI, or a hand-edited SV) shows a slider pinned
at 1200, and the first touch of that slider silently rewrites the stored value down to 1200. The same
happens to a large `x`/`y` on the multi-monitor layout that `Registry.Sanitize`'s comment (and audit
decision A-003) explicitly protects from clamping.

**Fix direction:** source both bounds from `core/Constants.lua`; add named offset bounds there rather
than inlining new numbers in the panel (`options-ui-§8`).

### F-004 — An open panel editor goes stale on any field-level change `[ux]`
`settings/Panel.lua:1057-1065` subscribes only to `NS.Registry.MSG_PANELS`

Field edits broadcast `Ka0s_PanelMaster_PanelChanged`, which the Panels page never listens to.

**Impact:** with the Panels page open, `/pm panel Chat width 400`, a drag in unlock mode, a
`Registry:Reset` triggered from elsewhere, or a `CopyFrom` all change the panel while every slider,
dropdown and colour swatch in the editor keeps showing the old value. The drag case is the common
one — unlock, drag, look back at the settings page, and the X/Y sliders are wrong.

**Fix direction:** react to `MSG_PANEL` for the currently-selected panel with an **in-place** scalar
refresh (`options-ui-§11` mandates in-place refresh for scalars and forbids a full rebuild per
mutation — anti-pattern #39), i.e. give the editor its own `refreshers` list rather than adding a
second rebuild trigger.

### F-005 — One global open-dropdown registry is shared by every subcategory and cleared by one page `[bug]`
`settings/Panel.lua:48-65, 999-1004`

`openDropdowns` is a single file-level list. `trackDropdown` appends the General page's strata
dropdown, every media dropdown and every editor dropdown to it; `forgetDropdowns()` — called only
from the Panels page's rebuilder — clears the **whole** list.

**Impact:** after the Panels page rebuilds once, the General page's still-live dropdown is no longer
in the registry, so scrolling the General page no longer closes its open list and the detached list
floats over the settings window (exactly the defect the mechanism exists to prevent). Conversely,
released widgets from previous builds linger in the list until the next Panels rebuild and are handed
to `pullout:Close()` / `AGSMW:ReturnDropDownFrame` after release.

**Fix direction:** scope the registry per render context (`ctx.dropdowns`) so each page tracks and
forgets its own, and forget on the release path that produced the widgets.

---

## Medium

### F-006 — `Registry:Recover` applies a CENTER-relative bound to every anchor point `[bug]`
`modules/Registry.lua:497-516`

The bound is `±w/2, ±h/2`, which is correct only for `point = "CENTER"`. For a `TOPLEFT`-anchored
panel the legal on-screen range is `0 … w`, and for `BOTTOMRIGHT` it is `-w … 0`.

**Impact:** `/pm recover` (and the "Recover panels" button) moves panels that are fully on screen —
e.g. a `TOPLEFT` panel at `x = 1000` on a 1600-wide UI is dragged to 800. The command promises to
touch only unreachable panels and its own comment says "Nothing here runs automatically … a panel
deliberately parked mostly off-screen is a legitimate design".

**Fix direction:** derive the legal offset range from the record's `point`/`relPoint` (and its
size), not from a fixed half-screen.

### F-007 — `settings/Panel.lua` is 1253 LOC and holds four unrelated concerns `[design]`
`settings/Panel.lua` (whole file)

Scroll/tooltip/header infrastructure, the schema two-column renderer, the ~320-line per-panel editor,
the landing page and the category registration all live in one file. It is inside the 1500 LOC cap
but in `layout-§1`'s explicit "on notice" 1000–1500 band, and the low cohesion is already showing
(F-005 and the spliced comment in F-017 are both artefacts of it).

**Fix direction:** peel the panel editor into a sibling `settings/PanelEditor.lua`.
`layout-§1` explicitly **MAY**s peeling into 2–3 siblings *in the same folder* — so the split must
stay under `settings/`, not move to `modules/` (which is for feature modules), and the TOC's
`# Settings` block must list it before `settings/Panel.lua`.

### F-008 — British spelling throughout user-facing strings, identifiers and comments `[locale]`
`settings/Panel.lua:549-603, 823, 843, 885, 905` ("Background colour", "Class colour", "Accent bar
colour"), `core/Constants.lua:85`, `core/Namespace.lua:14-17` ("colour", "recognises"),
`modules/Registry.lua:85`, `README.md` (throughout)

`anti-patterns` #46 / `localization-§5` make US English the collection's source dialect and call out
locale keys as the worst case, because the key *is* the English string.

**Impact:** today it is cosmetic drift against the collection. It becomes a breaking change the
moment `locales/enUS.lua` starts carrying keys — every `L["Background colour"]` key and call site
must move in the same change or the metatable falls through and renders the raw key. Since
`locales/enUS.lua` explicitly ships as the seam for a future localization pass, fixing the strings
now is strictly cheaper than fixing them later.

**Fix direction:** US spelling in every authored English string, identifier and comment. Blizzard
symbols (`SetTextColor`, `RAID_CLASS_COLORS`) are already correct and stay verbatim.

### F-009 — The `NS.State.debug` gate is duplicated at every debug call site `[design]`
`modules/Registry.lua:212, 237, 270, 311, 328, 366, 448, 462`; `modules/Canvas.lua:484`;
`modules/Unlock.lua:99, 203, 288`; `settings/Schema.lua:142`; `core/Database.lua:56`;
`settings/Panel.lua:442`

`NS.Debug` (`modules/DebugLog.lua:400-401`) already gates on `NS.State.debug` as its very first line
and is documented as zero-allocation when off, yet all fourteen call sites re-spell
`if NS.State.debug and NS.Debug then …`.

**Impact:** the same invariant restated fourteen times; each site is an opportunity to spell it
differently (one already does — `settings/Schema.lua:142` adds a redundant `NS.State and`). It also
obscures where the real gate lives.

**Fix direction:** call `NS.Debug(...)` directly (the `NS.Debug` nil-guard is only needed where load
order genuinely permits it — nowhere, since `modules/DebugLog.lua` precedes `settings/*` in the TOC
and all these sites run post-init). `debug-logging-§4` requires the gate to be the sink's first line,
which it already is; nothing in the standard asks for a second one at the call site.

### F-010 — `NS.COMMANDS` lives in `settings/Schema.lua`, away from every other part of the slash surface `[design]`
`settings/Schema.lua:180-228`

The command table is defined in the schema file while the dispatcher (`Sl:OnSlash`), the generated
help (`Sl:PrintHelp`) and all sixteen `Cli*` implementations live in `settings/Slash.lua` — and every
entry's `fn` is a one-line trampoline back into `NS.Slash`. `layout-§1` gives `settings/Slash.lua` as
the home of the AceConsole binding; `slash-commands-§3` treats the table and its dispatch as one
surface.

**Fix direction:** move `NS.COMMANDS` into `settings/Slash.lua`. It must stay a `COMMANDS` table
walked by the dispatcher (`anti-patterns` #6 forbids an `if/elseif` chain) and the help index and the
landing page must keep generating from it (`slash-commands-§4`, `options-ui-§5`).

### F-011 — Two working sub-verbs appear in no help output and no documentation `[ux]`
`settings/Schema.lua:220-224` (`/pm debug dump`), `settings/Slash.lua:268-276`
(`/pm panel deleteall`)

`slash-commands-§4` makes the generated help index the complete answer to "what can I type". Neither
sub-verb appears in it, on the settings landing page (which generates from the same table), or in the
README's command table.

**Impact:** `debug dump` is the single most useful thing to ask a user for in a bug report and it is
undiscoverable; `panel deleteall` is destructive and undiscoverable.

**Fix direction:** surface both in the `desc` of their owning `COMMANDS` rows (the generated help and
landing page then pick them up for free) and in the README's command table. Do not add a
hand-maintained help string — `slash-commands-§3` forbids it.

### F-012 — Every settings change triggers a full `Canvas:RenderAll()` `[perf]`
`modules/Canvas.lua:506` ← `settings/Schema.lua:23-25, 66-79`

`snapToGrid` and `gridSize` cannot change any panel's appearance — they only affect the next drag —
yet both `announce()` and therefore repaint every panel. `showLabels` only needs the unlock overlay
refreshed.

**Impact:** dragging the Grid size slider repaints N panels on each mouse-up. Small today; it is the
kind of thing that is only cheap because the panel count is small, and `Ka0s_PanelMaster_SettingsChanged`
already carries a `what` payload that the handler discards.

**Fix direction:** have the Canvas handler act on the payload it is already sent, or drop `onChange`
from the two rows that cannot affect a rendered panel.

### F-013 — `P:Register()` gives up permanently if `Settings`/AceGUI are not yet available `[design]`
`settings/Panel.lua:1123-1127`

The guard returns without setting `registered` and nothing ever retries, so if `Settings` is not
present when `OnInitialize` runs, the addon is absent from the options list for the whole session and
`/pm config` silently does nothing (`P:Open` no-ops on a nil `mainCategoryID`).

**Impact:** low probability on current retail, but the failure is silent and total, and it directly
contradicts `options-ui-§1`/`§9`'s "the addon's entry is **always present** in the Blizzard options
list".

**Fix direction:** retry once from `PLAYER_LOGIN` (registration stays eager per anti-pattern #22 —
**do not** defer it to first `/pm config`), and have `P:Open` say something when there is no category
rather than returning silently.

### F-014 — `U:SetPreview` writes `NS.State.unlocked` directly instead of going through `SetUnlocked` `[design]`
`modules/Unlock.lua:275, 284`

**Impact:** leaving preview sets `unlocked = false` without the cleanup `U:SetUnlocked(false)`
performs — `NS.State.unlockedPanels` and `pendingPanels` are left populated, so a panel unlocked
individually before preview stays unlocked (and a combat-deferred unlock stays queued) after the
global flag says everything is locked. The two lock paths have already drifted.

**Fix direction:** route both transitions through `U:SetUnlocked`, keeping the deliberate
combat-gate bypass documented in the comment (the frames are already on screen, so no secure write is
involved — `events-frames-taint-§2` is not in play).

### F-015 — Turning preview on repaints every panel four times `[perf]`
`modules/Unlock.lua:265-287`

Each `Registry:New` fires `MSG_PANELS` → `Canvas:RenderAll()`; three placeholders means three full
rebuilds, then `SetPreview` calls `RenderAll` again itself.

**Fix direction:** the same batching seam F-002 needs. (`Registry:DeleteAll` at
`modules/Registry.lua:336-343` already demonstrates the "mutate N, broadcast once" shape.)

---

## Low

### F-016 — `Compat.HasBackdrop()` has zero callers in addon source `[dead-code]`
`core/Compat.lua:148-149` — referenced only by `tests/test_compat.lua`. Its own docstring claims "the
panels degrade to plain textures without it", but `modules/Canvas.lua:277` guards on the frame's
`SetBackdrop` method instead, which is the better test. Remove it, or use it.

### F-017 — A comment block for one function is spliced into another's `[naming]`
`settings/Panel.lua:452-457` — the `selectedID` doc block opens with two lines describing
`buildPanelEditor` ("One panel's editor: a titled group holding its geometry, layer and colour
fields. Every control") that break off mid-sentence.

### F-018 — Two comments describe a layout the code does not have `[naming]`
`settings/Panel.lua:668-670` and `:940` both say Delete and Reset "live at the TOP of the editor,
beside Enabled and Unlock". They are in their own `actions` row *below* the switches row
(`settings/Panel.lua:767-790`).

### F-019 — The addon's one-line description exists in three different wordings `[ux]`
`PanelMaster.toc:3` ("Draws backdrop panels behind your UI, so separate frames read as deliberate
groups"), `settings/Panel.lua:21-23` ("Draws plain backdrop panels … a screen full of separate frames
reads as a few deliberate groups"), `README.md:12-13` ("draws plain coloured panels behind your
interface…"). Pick one and let the other two quote it.

### F-020 — `Registry:DeleteAll` leaves stale entries in `NS.State.unlockedPanels` `[bug]`
`modules/Registry.lua:336-343` — `R:Delete` is careful to clear the session entry
(`modules/Registry.lua:235`) and explains why; `DeleteAll` does not. Same for
`NS.State.previewIDs` when preview is on.

### F-021 — `R:Set` skips its own write-seam debug line for the `name` field `[naming]`
`modules/Registry.lua:387` early-returns into `R:Rename` before the "Every panel mutation is logged
ONCE, here at the write seam" block at `:446-450`. `Rename` does log, under the same `Panel` tag but
a different line shape, so the comment's claim is not quite true.

### F-022 — `/pm panel deleteall` shadows a panel genuinely named "deleteall" `[ux]`
`settings/Slash.lua:268` — the name check runs before `Registry:Resolve`, so such a panel can never
be inspected or edited from the CLI. Cheap to guard (only treat it as the verb when no panel resolves
by that name), or accept and note it.

### F-023 — `/pm set` coerces any unrecognized boolean token to `false` `[ux]`
`settings/Slash.lua:153-154` — `/pm set settings.enabled ture` turns panels **off** and echoes
`settings.enabled = false` as though that had been asked for. `Registry:Set` has the same shape at
`modules/Registry.lua:393-397`. Every other type in both paths reports a parse failure; booleans
should too.

### F-024 — A released frame keeps `panelID` set `[naming]`
`modules/Canvas.lua:401-427` — `release()` clears `__spec` and the mouseover tracking but leaves
`f.panelID` pointing at the retired record, so a pooled frame carries a stale id until reacquired.
Harmless today (`Canvas:Render` reassigns it) but misleading in a `/pm debug dump`.

### F-025 — "Defaults" on the Panels page means "delete every panel" `[ux]`
`settings/Panel.lua:1174-1180` — it is confirm-gated and the code comment justifies it, but the
Blizzard footer control and the header button labelled *Defaults* mean "restore settings" everywhere
else in the client and on the sibling General page. The README's Panels-page table does not mention
it at all.
