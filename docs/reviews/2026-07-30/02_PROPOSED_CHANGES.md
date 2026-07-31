# 02 — Proposed changes (HLD + LLD) — 2026-07-30

**Standard resolved:** Ka0s WoW Addon Standard **v2.13.1 (2026-07-30)**, fetched from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master/standards/STANDARDS.md`
plus all 24 section files discovered from its Sections list. Every change below was checked against
it; citations use `filename-§N`. The standards cross-check was **not** skipped.

This is a **guardrail**, not a compliance audit: the conformance notes below cover only whether
*these* changes stay inside the standard. Pre-existing deviations unrelated to them belong to
`wow-addon:standards-audit`.

**Green gate applies to every change:** `lua tests/run.lua` and `luacheck .` must both be clean
before anything is considered done. Every behavior change below gets a covering test first
(`testing`, anti-pattern #24). Nothing here stages, commits, pushes or bumps the version.

---

## HLD — themes

### T1 — Preview mode must survive a reload
*Covers F-001, F-014, F-015.*

Preview writes placeholder panels into `db.profile.panels` (persisted) while tracking them only in
`NS.State.previewIDs` (session). Any reload orphans them permanently, and the feature that created
them cannot remove them afterwards. The registry write path is otherwise the right call — it is what
makes `preview-mode`'s "same render path" true — so the fix is to make the *tracking* as durable as
the data, not to move the data.

**Chosen:** stamp each placeholder record with `preview = true` at creation, and sweep every
`rec.preview` record once in `NS:InitDB` before the first render (and on profile reload).
`NS.State.previewIDs` stays as the fast in-session path; the marker is the recovery path.

**Alternatives considered:**
- *Keep placeholders out of the registry entirely* (a parallel in-memory record list the Canvas also
  renders). Architecturally the cleanest, and it removes the name-collision skip-path too — but it
  forks the render input, which is precisely the thing `preview-mode`'s "feed the preview through the
  same render path … so it exercises the real layout, not a separate mock" is protecting. Rejected
  for 0.1.0; recorded as a follow-up.
- *Persist `NS.State.preview`* so `off` can find them after a reload. Rejected: `preview-mode` and
  the addon's own `core/State.lua` rationale both make preview an editing state, and it would put the
  addon on the wrong side of the session-only treatment `debug-logging-§5` sets for the sibling
  flags.
- *Persist `previewIDs` in `db.profile`.* Works, but adds a profile key (and therefore a
  `savedvariables-§1` migration) for something the record itself can carry, and it breaks if a
  profile is copied.

**Trade-off:** a preview panel that the user runs `/pm panel <name> reset` on loses its marker and
becomes a real panel. Acceptable, and documented in the code.

### T2 — The Panels page has exactly one rebuild trigger, and scalars refresh in place
*Covers F-002, F-004, F-005.*

Today a mutation from the page fires the bus, the bus rebuilds the page mid-callback, and the
callback rebuilds it again — while field-level changes from *outside* the page do not refresh it at
all. Both halves come from the same root cause: the page owns no refresh contract, only a rebuild.

**Chosen:** give the Panels context the same two-tier contract the General page already has
(`options-ui-§11`): `rebuilders` for structural change (`MSG_PANELS`), a new per-editor `refreshers`
list for scalar change (`MSG_PANEL`, and only for the selected panel). Manual `runRebuilders` calls
after a mutation are removed — the bus is the single trigger — and `selectedID` is set *before* the
mutating call so the one rebuild lands on the right selection.

**Alternatives considered:**
- *Defer the rebuild with `C_Timer.After(0, …)`* to get the widget off the stack. Fixes the
  use-after-release but keeps the double rebuild and adds a frame of latency. Rejected.
- *Rebuild the whole page on `MSG_PANEL` too.* Directly forbidden — a full AceGUI teardown per
  scalar mutation is `options-ui-§11` / anti-pattern #39.

`openDropdowns` moves onto the render context alongside it, so the two pages stop clearing each
other's tracking.

### T3 — Every bound comes from `core/Constants.lua`
*Covers F-003, F-006.*

Two places decide a geometric bound with a literal: the editor's sliders, and `Registry:Recover`'s
half-screen. Both disagree with the registry's actual clamps, and both silently move the user's data.
`options-ui-§8` ("Named, never inlined") and this file's own header comment already require the
first; the second is a logic fix.

### T4 — Peel the panel editor, and stop restating the debug gate
*Covers F-007, F-009, F-010.*

Structural cleanups with no behavior change, each individually revertible.

### T5 — One vocabulary, US English, and a help index that is the whole truth
*Covers F-008, F-011, F-019, F-025, and the comment fixes F-017, F-018, F-021, F-024.*

The user-facing surface currently says "colour" (against `localization-§5`), describes the addon in
three different sentences, and hides two working sub-verbs from the generated help. All three are
cheapest to fix before `locales/enUS.lua` starts carrying keys.

### T6 — Robustness and cheap perf
*Covers F-012, F-013, F-016, F-020, F-022, F-023.*

---

## LLD — change set

Change IDs are `C-nn`. Each lists target files, the shape of the edit, risk, the finding IDs it
covers, and its standards conformance note.

---

### C-01 — Preview records are marked and swept
**Covers:** F-001. **Files:** `core/Constants.lua`, `modules/Unlock.lua`, `core/Database.lua`,
`modules/Registry.lua`, `tests/test_unlock.lua`, `docs/ARCHITECTURE.md`.

1. `core/Constants.lua` — name the marker so nothing spells it inline:

```lua
-- The field a preview placeholder carries in the registry. Preview panels are REAL records (that is
-- what makes preview exercise the real render path, preview-mode) but they are not the user's work,
-- so they must not survive a reload. The marker is the durable half of the pair whose session half
-- is NS.State.previewIDs: ids are lost on /reload, this is not.
C.PREVIEW_FIELD = "preview"
```

Deliberately **not** added to `C.PANEL_FIELD_TYPE`, `C.PANEL_FIELD_ORDER` or `C.PANEL_TEMPLATE`, so
the CLI cannot set it, `/pm panel <name>` does not print it, and a normally-created panel never has
it. Add it to `modules/Registry.lua`'s `COPY_EXCLUDED` so `CopyFrom` cannot smear it onto a real
panel.

2. `modules/Unlock.lua:265-270` — stamp it on the way in:

```lua
-- before
local rec = NS.Registry:New(spec.name, spec)
-- after
local overrides = NS.Util.DeepCopy(spec)
overrides[C.PREVIEW_FIELD] = true
local rec = NS.Registry:New(spec.name, overrides)
```

3. `core/Database.lua` — sweep once, before anything reads `db.profile.panels`:

```lua
function NS:InitDB()
  NS.db = LibStub("AceDB-3.0"):New(addonName .. "DB", NS.defaults, true)
  NS:RunMigrations()
  NS:SweepPreviewPanels()   -- orphans from a /reload with test mode on
  NS:RegisterProfileCallbacks()
end
```

`NS:SweepPreviewPanels()` walks `db.profile.panels` backwards, removes every record carrying the
marker, returns the count, and emits a `[Preview]` debug line when any were removed. Call it from the
profile-reload path too (`NS:RegisterProfileCallbacks`'s `reload`), since a copied profile can carry
orphans.

The sweep runs in `OnInitialize`, i.e. before `Canvas:Enable()` and before `PLAYER_ENTERING_WORLD`'s
first `RenderAll`, so no orphan is ever drawn.

**Risk:** a preview record that was `Registry:Reset` while preview was on loses the marker and
becomes a permanent panel. Documented in the code comment; it is strictly better than today.

**Standards conformance:** no new deviation. The record shape change needs no `savedvariables-§1`
migration (the marker is additive and the sweep is idempotent, so `NS.SCHEMA_VERSION` stays at 1);
`preview-mode`'s "MUST clear the preview … when the preview verb is toggled off" moves from broken to
satisfied. The rejected alternative — persisting `NS.State.preview` — was rejected precisely because
it would put the addon on the wrong side of `preview-mode` and `debug-logging-§5`.

---

### C-02 — Preview transitions go through `SetUnlocked`, and broadcast once
**Covers:** F-014, F-015. **Files:** `modules/Unlock.lua`, `modules/Registry.lua`,
`tests/test_unlock.lua`.

- Replace the two direct `NS.State.unlocked = …` writes with `U:SetUnlocked(true/false)`, keeping the
  existing comment explaining why the combat gate is deliberately not in play here (no secure write
  is involved, so `events-frames-taint-§2` does not apply).
- Add `R:NewBatch(specs)` to `modules/Registry.lua` — create N records, fire `MSG_PANELS` **once** —
  mirroring the shape `R:DeleteAll` already uses, and use it from `U:SetPreview`. Same for the
  teardown: collect, delete, broadcast once.

**Risk:** `SetUnlocked` itself calls `Canvas:RenderAll`, so ordering matters — mutate the registry
first, then flip the lock, then let the single broadcast repaint. Covered by test.

**Standards conformance:** `architecture-§4`'s one-sender rule is preserved — `MSG_PANELS` still
originates only from `modules/Registry.lua`.

---

### C-03 — The Panels page rebuilds once, from the bus only
**Covers:** F-002. **Files:** `settings/Panel.lua` (or `settings/PanelEditor.lua` after C-07),
`tests/test_panel.lua`.

Every mutation site loses its trailing rebuild:

```lua
-- before (delete button)
NS.Registry:Delete(rec.id)
selectedID = nil
ctx.dirty = true
if ctx.panel:IsShown() then runRebuilders(ctx) end

-- after
selectedID = nil            -- decided BEFORE the mutation, so the one rebuild lands correctly
NS.Registry:Delete(rec.id)  -- fires MSG_PANELS -> P.__evPanels -> single rebuild
```

Same shape for the create `EditBox` (`selectedID` cannot be known before the record exists — so keep
the assignment after, and have the bus handler read a `ctx.pendingSelect` field the mutation sets
first), the rename `EditBox`, and `CopyFrom`/`Reset` (which fire `MSG_PANEL` and after C-04 refresh
in place rather than rebuilding).

**Risk:** the AceGUI widget whose callback triggered the rebuild is still released — that is
unavoidable when a rebuild is what the interaction asks for — but it now happens **once**, after the
handler has finished touching it, rather than mid-handler and then again. Verify by clicking Delete
on the last remaining panel (the empty-state branch).

**Standards conformance:** keeps `options-ui-§11`'s on-screen-only scoping (`ctx.panel:IsShown()`
gate stays in the bus handler, `ctx.dirty` still marks the hidden case).

---

### C-04 — Per-editor scalar refreshers, driven by `MSG_PANEL`
**Covers:** F-004. **Files:** `settings/Panel.lua` / `settings/PanelEditor.lua`,
`tests/test_panel.lua`.

- `createPanel`'s context already carries `refreshers`; the Panels page currently never populates it.
  Have every editor control push an updater closure as it is built, exactly as `makeCheckbox` /
  `makeSlider` / `makeDropdown` do on the General page:

```lua
ctx.refreshers[#ctx.refreshers + 1] = function()
  local live = NS.Registry:Get(rec.id)
  if live then s:SetValue(tonumber(live[field]) or 0) end
end
```

- `runRebuilders` clears `ctx.refreshers` before a rebuild (the closures it holds point at released
  widgets).
- Register a second bus target for `MSG_PANEL`:

```lua
ev:RegisterMessage(NS.Registry.MSG_PANEL, function(_, id)
  if id ~= selectedID then return end
  if ctx.panel:IsShown() then P:RefreshPanels(ctx) else ctx.dirty = true end
end)
```

`P:RefreshPanels` runs the refreshers through the existing `safeRun`, never a rebuild.

**Risk:** a refresher firing during a rebuild would touch a released widget — hence clearing the list
first. A colour-picker refresher must not re-enter `Registry:Set`; use `SetColor`, which does not
fire callbacks.

**Standards conformance:** this is the `options-ui-§11` in-place-refresh mandate applied to the page
that was missing it, and the reason the obvious fix (rebuild on `MSG_PANEL`) was rejected —
anti-pattern #39.

---

### C-05 — Dropdown tracking is per render context
**Covers:** F-005. **Files:** `settings/Panel.lua` (+ `settings/PanelEditor.lua`),
`tests/test_panel.lua`.

`openDropdowns` → `ctx.dropdowns`; `trackDropdown(ctx, widget)`; `forgetDropdowns(ctx)`;
`closeOpenDropdowns(ctx)` bound into that context's `MoveScroll` / scrollbar `OnMouseDown` hooks.
The existing test seams (`P.__registerDropdownForTest`, `P.__openDropdownCount`,
`P.__forgetDropdownsForTest`, `P.__closeOpenDropdowns`) keep their names and take a context, so the
existing tests move rather than disappear.

**Risk:** none beyond mechanical. Keep the `type`-based dispatch in `__closeOpenDropdowns` exactly as
it is — the comment there records a real bug (a stock AceGUI Dropdown also has a `.dropdown` field)
and must not be re-simplified.

**Standards conformance:** no rule touched; `anti-patterns` #8 (no forking Ace libs) is respected —
this is addon-side tracking around the stock widgets, not a widget fork.

---

### C-06 — Bounds come from Constants; `Recover` is anchor-aware
**Covers:** F-003, F-006. **Files:** `core/Constants.lua`, `settings/Panel.lua` /
`settings/PanelEditor.lua`, `modules/Registry.lua`, `tests/test_constants.lua`,
`tests/test_registry.lua`.

1. `core/Constants.lua` — add the two bounds the editor currently inlines, next to the existing
   `MIN_/MAX_` block and with the same style of comment:

```lua
-- The range the editor's X/Y sliders span. NOT a clamp: Registry.Sanitize deliberately does not
-- bound offsets (a multi-monitor layout legitimately carries large ones), so this is only how far
-- the slider can reach, and it is named here so the panel cannot invent its own number.
C.EDITOR_OFFSET_RANGE = 2000
```

and have the width/height sliders span `C.MIN_SIZE … C.MAX_SIZE`.

2. `modules/Registry.lua:497-516` — replace the fixed `±w/2` with a per-record range derived from the
   anchor:

```lua
-- The legal offset range depends on WHICH point the offset is measured from: a CENTER-anchored
-- panel runs -w/2..+w/2, a LEFT-anchored one 0..w, a RIGHT-anchored one -w..0. Using the CENTER
-- range for all nine points is what let `recover` drag a perfectly visible TOPLEFT panel inward.
local function offsetRange(point, extent)
  if point:find("LEFT")   then return 0, extent end
  if point:find("RIGHT")  then return -extent, 0 end
  return -extent / 2, extent / 2
end
```

with the vertical axis keyed on `TOP`/`BOTTOM` the same way, and `Util.Clamp` applied against the
resulting pair.

**Risk:** `Recover`'s test expectations change. This is a behavior change users can see — it makes
`/pm recover` move strictly fewer panels, which is the direction the feature's own documentation
promises.

**Standards conformance:** `options-ui-§8` ("named constants … never inline magic numbers") is the
rule that shapes the first half. No rule constrains the second.

---

### C-07 — Peel the panel editor out of `settings/Panel.lua`
**Covers:** F-007. **Files:** new `settings/PanelEditor.lua`, `settings/Panel.lua`,
`PanelMaster.toc`, `tests/test_panel.lua`, `docs/ARCHITECTURE.md`.

Move `buildPanelEditor` and its helpers (`editorRow`, `editorSpacer`, `editorHeading`,
`makeMediaDropdown`, `makeColorPair`, `makeEdgeChecks`, the editor layout constants,
`buildPanelsPage`, `selectedID`) into `settings/PanelEditor.lua`, published as
`NS.PanelEditor = NS.PanelEditor or {}` (`architecture-§3`). `settings/Panel.lua` keeps the header,
scroll, tooltip, schema renderer, landing page and registration, and calls
`NS.PanelEditor:BuildPage(pctx)`.

TOC `# Settings` block becomes:

```
settings\Schema.lua
settings\Slash.lua
settings\PanelEditor.lua
settings\Panel.lua
```

Target: `settings/Panel.lua` under ~800 LOC, `settings/PanelEditor.lua` under ~500.

**Risk:** pure move; the risk is an accidental behavior change during it. Do it as its own commit
with no other edit, and run the suite before and after.

**Standards conformance:** `layout-§1` explicitly **MAY**s peeling an oversized file into 2–3
siblings **in the same folder** — hence `settings/`, not `modules/` (which is for feature modules)
and not a root-level file (`layout-§1` forbids loose root source). Naming is PascalCase per
`layout-§2`. The new file opens with `local addonName, NS = ...` per `architecture-§1`.

---

### C-08 — One debug gate, at the sink
**Covers:** F-009. **Files:** all fourteen call sites listed in F-009.

```lua
-- before
if NS.State.debug and NS.Debug then
  NS.Debug("Panel", "created '%s' (id %s)", rec.name, rec.id)
end
-- after
NS.Debug("Panel", "created '%s' (id %s)", rec.name, rec.id)
```

`modules/DebugLog.lua`'s comment on `NS.Debug` gains one line noting that it is the *only* gate and
that call sites must not re-spell it.

**Risk:** the arguments are now always evaluated (they are all field reads and constants at every
site — no call, no concat, no allocation, so the zero-cost-when-off property holds). Verify by
reading each of the fourteen sites; if any ever grows an expensive argument, that site — and only
that site — takes a gate back.

**Standards conformance:** `debug-logging-§4` requires the gate to be the sink's first line, which it
already is. `anti-patterns` #43 (ungated instrumentation in a hot path) is not engaged — none of
these sites are per-frame; the one per-frame path in the addon (`updateMouseover`) contains no debug
call and must not gain one.

---

### C-09 — `NS.COMMANDS` moves to `settings/Slash.lua`
**Covers:** F-010. **Files:** `settings/Schema.lua`, `settings/Slash.lua`, `tests/test_slash.lua`,
`docs/ARCHITECTURE.md`.

Straight move of the table (and the `MSG_SETTINGS`-unrelated block around it) to the bottom of
`settings/Slash.lua`, below the `Cli*` functions it calls. The TOC already loads `Schema.lua` before
`Slash.lua`, and `settings/Panel.lua` (which generates the landing-page list from `NS.COMMANDS`)
loads after both, so no load-order change is needed.

**Risk:** none functionally. `settings/Schema.lua` shrinks to what its name says.

**Standards conformance:** the table stays `NS.COMMANDS`, ordered, walked by the dispatcher
(`slash-commands-§3`); the help index and the landing page keep generating from it
(`slash-commands-§4`, `options-ui-§5`). Rejected alternative: inlining dispatch into `Sl:OnSlash` as
an `if/elseif` — `anti-patterns` #6.

---

### C-10 — US English across authored strings, identifiers and comments
**Covers:** F-008. **Files:** `settings/Panel.lua` / `settings/PanelEditor.lua`,
`core/Constants.lua`, `core/Namespace.lua`, `core/Util.lua`, `modules/Registry.lua`,
`modules/Canvas.lua`, `README.md`, `docs/ARCHITECTURE.md`.

`colour` → `color`, `recognise` → `recognize`, `behaviour` → `behavior`, `centre` → `center`
throughout authored English. User-facing labels move together with their tooltips
("Background colour" → "Background color", "Class colour" → "Class color").

Do it as a **single** change: `localization-§1/§2` warns that a locale key *is* the English string,
so a half-applied rename is worse than none. `locales/enUS.lua` carries no keys today, so there is
nothing to move alongside — which is exactly why now is the cheap moment.

**Do not touch:** Blizzard/library symbols (`SetTextColor`, `RAID_CLASS_COLORS`, `SetVertexColor`,
`GRAY_FONT_COLOR`), quoted external text, or the `bgColor`/`accentColor` **stored field names**
(already US-spelled, and renaming a stored field would need a `savedvariables-§1` migration for no
benefit).

**Risk:** the README's Settings tables and the code's labels must move together or the docs lie.
A `grep -rin colour` returning nothing (outside `libs/`) is the exit criterion.

**Standards conformance:** this change exists *because of* `anti-patterns` #46 / `localization-§5`.

---

### C-11 — Hidden sub-verbs surface in the generated help and the README
**Covers:** F-011, F-025. **Files:** `settings/Slash.lua` (after C-09), `README.md`.

```lua
{ name = "debug", desc = "Window; 'on'/'off' set logging, 'dump' writes a state dump", fn = … },
{ name = "panel", desc = "Inspect or edit one: /pm panel <name> [field] [value]; "
                      .. "'deleteall' removes every panel", fn = … },
```

README's command table gains the same two clarifications, and its Panels-page control table gains a
**Defaults** row explaining that on that page it means "delete every panel (confirm-gated)".

**Risk:** none. The landing page picks the new `desc` up for free because it generates from the same
table.

**Standards conformance:** `slash-commands-§3`'s "no hand-maintained help string" is why the text
goes in `desc` rather than into `Sl:PrintHelp`. Row text keeps the gold-command / em-dash / white-desc
shape and no trailing colon (`slash-commands-§4`).

---

### C-12 — Comment, tagline and naming corrections
**Covers:** F-017, F-018, F-019, F-021, F-024. **Files:** `settings/Panel.lua` /
`settings/PanelEditor.lua`, `modules/Registry.lua`, `modules/Canvas.lua`, `PanelMaster.toc`,
`README.md`.

- Split the spliced comment block above `selectedID` back into two.
- Correct the two "Delete and Reset live at the TOP" comments to describe the actual `actions` row.
- Pick one tagline. Proposal: `settings/Panel.lua`'s `ADDON_TAGLINE` is canonical (it is the one the
  user reads on the landing page); the TOC `## Notes` carries a shortened form of the *same*
  sentence, and the README's opening line quotes it.
- `modules/Registry.lua:387` — either log before delegating to `Rename`, or amend the write-seam
  comment to say `name` is logged by `Rename`.
- `modules/Canvas.lua` `release()` — add `f.panelID = nil`.

**Risk:** none. `f.panelID = nil` must come *after* the `SetMouseoverTracked` call that reads it.

**Standards conformance:** the TOC `## Notes` edit keeps `toc-file-§1`'s required field order
untouched (value change only).

---

### C-13 — `SettingsChanged` stops repainting for settings that cannot repaint
**Covers:** F-012. **Files:** `settings/Schema.lua`, `modules/Canvas.lua`, `tests/test_canvas.lua`.

`snapToGrid` and `gridSize` lose their `onChange`/`announce` (they affect only the *next* drag, which
reads `db.profile.settings` live in `U.SnapPosition`). `showLabels` keeps announcing — the unlock
overlay reads it in `U:Decorate`, which only runs from a render.

**Risk:** confirm nothing else consumes those two values at render time — `Canvas.BuildSpec` does
not, and `U.SnapPosition` reads them at drag-stop. Test asserts a `gridSize` write produces no
repaint.

**Standards conformance:** the message keeps its single sender (`architecture-§4`); no receiver is
added or removed.

---

### C-14 — Settings registration retries once, and `/pm config` says when it can't
**Covers:** F-013. **Files:** `settings/Panel.lua`, `core/PanelMaster.lua`, `tests/test_panel.lua`.

`P:Register()` already returns early without setting `registered`, so it is safe to call twice. Add a
single retry from `PLAYER_LOGIN` in `addon:OnEnable`:

```lua
self:RegisterEvent("PLAYER_LOGIN", function()
  if NS.Panel and NS.Panel.Register then NS.Panel:Register() end
end)
```

and have `P:Open` print a tagged notice when `mainCategoryID` is nil rather than returning silently.

**Risk:** `P:Register` must stay idempotent — the `registered` flag already guarantees that. On a
normal login `PLAYER_LOGIN` fires after `OnInitialize`, so the retry is a no-op in the common case.

**Standards conformance:** registration stays **eager** — this adds a second eager attempt, it does
**not** defer to first `/pm config`, which `anti-patterns` #22 and `options-ui-§9` forbid outright.
`options-ui-§1` explicitly sanctions registering from a bootstrap on `PLAYER_LOGIN`. `P:Open`'s
combat refusal (`options-ui-§2`) is untouched.

---

### C-15 — Small correctness cleanups
**Covers:** F-016, F-020, F-022, F-023. **Files:** `core/Compat.lua`, `modules/Registry.lua`,
`settings/Slash.lua`, `tests/*`.

- **F-016:** delete `Compat.HasBackdrop` and its test (`modules/Canvas.lua` already guards on the
  frame's own `SetBackdrop` method, which is the better check and is documented as such).
- **F-020:** `R:DeleteAll` clears `NS.State.unlockedPanels` and `NS.State.previewIDs`, matching what
  `R:Delete` already does and why.
- **F-022:** `Sl:CliPanel` treats `deleteall` as the verb only when no panel resolves under that name.
- **F-023:** a shared `Util.ParseBool(s)` returning `nil` on an unrecognized token, used by both
  `Sl:CliSet` and `Registry:Set`; both then report `expected true/false (or on/off, yes/no, 1/0)`
  instead of silently storing `false`.

**Risk:** F-023 is a user-visible behavior change — `/pm set settings.enabled 0` still works, but
`/pm set settings.enabled nope` now errors instead of turning panels off. That is the point.

**Standards conformance:** `anti-patterns` #10 — removing `Compat.HasBackdrop` does not move a
deprecated API out of Compat; the API it wrapped (`BackdropTemplateMixin`) is not called directly
anywhere, only `frame:SetBackdrop` is, and that is guarded on the instance. `slash-commands-§5`'s
"a missing / empty argument → a `Usage: …` line" shape is followed for the new error.

---

## Standards conformance summary

| Change | Rules that shaped it | New deviation introduced? |
|---|---|---|
| C-01 | `preview-mode`, `savedvariables-§1`, `debug-logging-§5` | No |
| C-02 | `architecture-§4`, `events-frames-taint-§2` | No |
| C-03 | `options-ui-§11`, anti-pattern #39 | No |
| C-04 | `options-ui-§11`, anti-pattern #39 | No |
| C-05 | anti-pattern #8 | No |
| C-06 | `options-ui-§8` | No |
| C-07 | `layout-§1`, `layout-§2`, `architecture-§1`, `architecture-§3`, `toc-file-§5` | No |
| C-08 | `debug-logging-§4`, anti-pattern #43 | No |
| C-09 | `slash-commands-§3`, `slash-commands-§4`, `options-ui-§5`, anti-pattern #6 | No |
| C-10 | `localization-§1`, `localization-§2`, `localization-§5`, anti-pattern #46 | No — removes one |
| C-11 | `slash-commands-§3`, `slash-commands-§4` | No |
| C-12 | `toc-file-§1` | No |
| C-13 | `architecture-§4` | No |
| C-14 | `options-ui-§1`, `options-ui-§2`, `options-ui-§9`, anti-pattern #22 | No |
| C-15 | `anti-patterns` #10, `slash-commands-§5` | No |

**Rejected because the standard forbids it:** deferring settings-category registration to first
`/pm config` (anti-pattern #22 / `options-ui-§9`) — see C-14; rebuilding the Panels page on every
`MSG_PANEL` (anti-pattern #39 / `options-ui-§11`) — see C-04; persisting `NS.State.preview`
(`preview-mode`, `debug-logging-§5`) — see C-01; moving the peeled editor outside `settings/`
(`layout-§1`) — see C-07.
