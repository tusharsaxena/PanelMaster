# 03 — Smoke tests (2026-07-30)

Manual, in-client checklist to run **after** the changes in `02_PROPOSED_CHANGES.md` are applied.
Derived one section per change ID. Headless coverage (`lua tests/run.lua`) is assumed green before
any of this starts — these tests exist to catch what a headless mock cannot see.

---

## Pre-flight

1. **Build/install.** Copy the working tree to
   `World of Warcraft/_retail_/Interface/AddOns/PanelMaster/`. Confirm `PanelMaster.toc` still reads
   `## Interface: 120007` and — after C-07 — lists `settings\PanelEditor.lua` **before**
   `settings\Panel.lua` in the `# Settings` block.
2. **Green gate.** From the repo root: `lua tests/run.lua` (expect `N passed, 0 failed`) and
   `luacheck .` (expect `0 warnings / 0 errors`). Do not proceed if either is red.
3. **Client setup.** Retail only (this addon is Retail-only by design — no flavor branching).
   - `/console scriptErrors 1` — Lua errors surface as a popup rather than silently.
   - Log in on a character with a class colour distinct from grey (any class), so class-colour
     behavior is observable.
   - Have **at least one other LibSharedMedia-providing addon** loaded if you want to exercise the
     media dropdowns beyond `Solid`/`None`; optional.
4. **Baseline SavedVariables.** For the tests marked *fresh SV*, log out, delete
   `WTF/Account/<ACCT>/SavedVariables/PanelMaster.lua` (and the `.bak`), and log back in.
5. **Combat rig.** Stormwind / Orgrimmar training dummies for every in-combat step.
6. Keep `/pm debug on` **off** unless a step says otherwise — several assertions are about output
   that only appears when it is on.

---

## Per-change tests

### C-01 — Preview records are marked and swept

**Change covered:** C-01 — a `/reload` with test mode on no longer orphans three panels
(finding F-001).

**Setup:** fresh SV. `/pm panels` prints the "No panels yet" line.

**Steps**
1. `/pm new Keep` → chat confirms `created panel 'Keep' (id 1)`.
2. `/pm preview` → chat prints `preview on`; three sample panels appear (bottom-left, bottom-centre,
   top-right) with gold outlines and name labels.
3. `/pm panels` → **five** rows: `Keep`, `Preview: Chat`, `Preview: Bars`, `Preview: Minimap`.
   (Order: `Keep` first.)
4. `/reload` — **while preview is still on**.
5. After the UI reloads, `/pm panels`.

**Expected:** exactly **one** row, `Keep`. No `Preview: *` panel is on screen. No Lua error popup.

**Steps (continued — the round trip still works)**
6. `/pm preview` → `preview on`, three placeholders appear.
7. `/pm preview` again → `preview off`, all three disappear.
8. `/pm panels` → one row, `Keep`.

**Pass / Fail:** PASS if step 5 shows one panel and step 8 shows one panel, and `Keep`'s size,
position and colours are unchanged throughout. FAIL if any `Preview: *` record survives a reload, or
if `Keep` is affected.

**Regression guard for the sweep:** repeat step 2, then `/pm panel "Preview: Chat"` (no field) and
confirm the field dump does **not** list a `preview` field — the marker must be invisible to the CLI.

---

### C-02 — Preview goes through `SetUnlocked` and broadcasts once

**Change covered:** C-02 — leaving preview cleans up per-panel unlocks; preview no longer repaints
four times (F-014, F-015).

**Setup:** fresh SV. `/pm new A`, `/pm new B`.

**Steps**
1. Open `/pm config` → **Panels** page → select `A` → tick **Unlock**. Panel A gets a gold outline;
   B does not.
2. Close settings. `/pm preview` → placeholders appear, everything is unlocked.
3. `/pm preview` → preview off.
4. Look at panels A and B.

**Expected:** after step 3, **neither** A nor B carries a gold outline or a name label, and neither
is draggable. (Before this change, A stayed individually unlocked.)

**Pass / Fail:** PASS if step 4 shows both panels fully locked and click-through (click through A
onto whatever is behind it and confirm the click lands there). FAIL if A is still draggable.

**Perf side-check (optional):** `/pm debug on`, then `/pm preview`. In the console, count `[Canvas]
rendered N panels` lines produced by the single preview toggle: expect **one**, not four.

---

### C-03 — The Panels page rebuilds once, from the bus only

**Change covered:** C-03 — no double rebuild and no widget released mid-callback (F-002).

**Setup:** fresh SV. `/pm new One`, `/pm new Two`, `/pm new Three`.

**Steps**
1. `/pm config` → **Panels**. The dropdown shows three panels; `One` is selected.
2. Select `Two` in the dropdown. The editor below repaints to `Two`'s values.
3. Click **Delete**.
4. Observe the page and the chat frame.
5. In the panel-name box type `Renamed` and press Enter.
6. In the **Create** box at the top type `Four` and press Enter.
7. Select `One`, then use **Copy settings from panel** → `Four`.

**Expected**
- Step 4: no Lua error popup. The dropdown now lists two panels and the editor shows one of them
  (not a blank editor, not a stale `Two`). The page does not visibly flash twice.
- Step 5: the dropdown entry updates to `Renamed`; the tooltip on the name box shows the **new**
  frame name (`PanelMaster_Panel_Renamed`).
- Step 6: the box clears, `Four` is created **and selected** — the editor below shows `Four`.
- Step 7: chat prints `copied settings from 'Four'`; the editor's controls show `Four`'s appearance
  values but `One`'s position (X/Y unchanged).

**Pass / Fail:** PASS if all four interactions complete with no Lua error and each lands on the
correct selection first time. FAIL on any `attempt to index` / `AceGUI` error, or if step 6 leaves
the editor on a panel other than `Four`.

**Edge case:** delete panels until **none** remain. Expected: the "No panels yet. Type a name above
and press Create." label, no error, no orphan editor.

---

### C-04 — Per-editor scalar refreshers driven by `MSG_PANEL`

**Change covered:** C-04 — an open editor tracks field-level changes made elsewhere (F-004).

**Setup:** fresh SV. `/pm new Live`.

**Steps**
1. `/pm config` → **Panels** → `Live` selected. Note the **Width** slider value (240) and the
   **X offset** value (0).
2. Leaving the settings window open, click into chat and run
   `/pm panel Live width 400`.
3. Look at the Width slider **without** re-selecting the panel.
4. Run `/pm panel Live bgColor 1,0,0,1`.
5. Look at the Background colour swatch.
6. Close settings, `/pm unlock`, drag `Live` a visible distance, `/pm lock`, reopen
   `/pm config` → **Panels**.
7. Now the harder case: reopen settings on the **Panels** page, `/pm unlock` in chat (settings stays
   open), drag `Live`, and watch the X/Y sliders.

**Expected**
- Step 3: the Width slider reads **400**.
- Step 5: the swatch is red.
- Step 6: X/Y match where you dropped it.
- Step 7: X/Y update in place as soon as the drag ends — with **no** visible teardown/rebuild of the
  editor (the dropdown selection and scroll position must not jump).

**Pass / Fail:** PASS if every value tracks and step 7 shows no page rebuild. FAIL if any control is
stale, or if step 7 rebuilds the page (that would be the anti-pattern #39 shape the change exists to
avoid).

---

### C-05 — Per-context dropdown tracking

**Change covered:** C-05 — the General page's dropdown is still closed on scroll after the Panels
page has rebuilt (F-005).

**Setup:** enough panels that the Panels page scrolls (`/pm new P1` … `/pm new P5`).

**Steps**
1. `/pm config` → **Panels**. Create one more panel so the page rebuilds at least once.
2. Switch to the **General** subcategory.
3. Open the **Default frame strata** dropdown so its list is showing.
4. Without closing it, scroll the General page with the mouse wheel.
5. Repeat on the **Panels** page: open the **Anchor** dropdown in the editor, then wheel-scroll.
6. Repeat step 5 using the **scrollbar drag** instead of the wheel.

**Expected:** in steps 4, 5 and 6 the open list closes the instant the page scrolls. It never remains
floating detached over (or outside) the settings window.

**Pass / Fail:** PASS if all three close correctly and no Lua error appears (in particular no error
mentioning `contentRepo` — that is the stock-Dropdown-vs-LSM misdispatch the code comment records).
FAIL on any detached list or error.

---

### C-06 — Bounds from Constants; anchor-aware `Recover`

**Change covered:** C-06 — sliders no longer truncate large stored values; `/pm recover` no longer
moves on-screen panels (F-003, F-006).

**Setup:** fresh SV.

**Steps (slider bounds)**
1. `/pm new Big`, then `/pm panel Big width 2500`. Chat echoes `width = 2500`.
2. `/pm config` → **Panels** → `Big`. Read the **Width** slider.
3. Nudge the **Height** slider one step (do **not** touch Width).
4. `/pm panel Big width` → read the stored value back.

**Expected:** step 2's slider reads 2500 and its max is 4096; step 4 still reports `2500`.

**Steps (recover)**
5. `/pm new Corner`, then `/pm panel Corner point TOPLEFT`, `/pm panel Corner relPoint TOPLEFT`,
   `/pm panel Corner x 900`, `/pm panel Corner y -200`. On a 1920-wide UI the panel is visibly on
   screen, right of centre, near the top.
6. `/pm recover`.
7. `/pm new Lost`, `/pm panel Lost x 9000`, then `/pm recover`.

**Expected**
- Step 6: chat prints `every panel is already on screen`, and `Corner` has **not** moved.
- Step 7: chat prints `moved 1 panel back on screen`, and `Lost` is visible.

**Pass / Fail:** PASS if step 4 reads 2500, step 6 moves nothing, and step 7 moves exactly one panel.
FAIL if `Corner` is dragged, or if the width slider clamps.

---

### C-07 — Panel-editor peel

**Change covered:** C-07 — file split with no behavior change (F-007).

**Setup:** none beyond the build.

**Steps**
1. Log in with a clean `WTF` `Errors` folder. Watch for a load-time error popup.
2. `/pm config` → visit **all four** subcategories in order: landing page, **General**, **Panels**,
   **Profiles**.
3. On the landing page confirm the logo renders (300×300, not a green/black box), the tagline reads,
   and every `/pm` command from `/pm help` appears in the list.
4. On **General**, toggle every checkbox once and move every slider once.
5. On **Panels**, exercise one control of each kind: a slider, a token dropdown (Anchor), a media
   dropdown (Background texture), a colour picker, an edge checkbox, the name box.
6. `/reload` and repeat step 2.

**Expected:** identical behavior and layout to before the peel; no Lua error at any point; the
**Defaults** button on General and Panels renders in the dark/gold options look, not the red stone
`UI-Panel-Button-Up` art.

**Pass / Fail:** PASS if every page renders and every control works. FAIL on any error, missing page,
or red Defaults button (that would mean the lazy-build rule of `options-ui-§5` was broken during the
move).

---

### C-08 — One debug gate

**Change covered:** C-08 — the call sites lost their gate; the sink keeps it (F-009).

**Setup:** fresh SV, `/pm new Gate`.

**Steps**
1. With debug **off**, run `/pm panel Gate width 300`, `/pm new Second`, `/pm delete Second`,
   `/pm unlock`, `/pm lock`.
2. `/pm debug` (opens the console window).
3. Read the console.
4. `/pm debug on`, then repeat the mutations from step 1.
5. Read the console again.

**Expected:** step 3 shows **no** lines from step 1 (the sink swallowed them because the flag was
off). Step 5 shows one `[Panel]`, `[Unlock]` etc. line per mutation, exactly one per mutation
(no duplicates).

**Pass / Fail:** PASS if nothing is logged while off and each mutation logs exactly once while on.
FAIL if anything leaks while off, or if a mutation produces two lines.

---

### C-09 — `NS.COMMANDS` moved

**Change covered:** C-09 — the command table moved file (F-010).

**Steps**
1. `/pm` (bare) → the help index prints.
2. Count the rows and compare against the README's command table and the settings landing page's
   Slash Commands list.
3. Run every verb at least once: `config version get set list reset resetall new delete rename
   panels panel unlock lock preview recover debug help`.
4. `/pm bogusverb`.

**Expected:** step 2 — all three lists carry the same verbs in the same order. Step 3 — every verb
produces output and none errors. Step 4 — `unknown command 'bogusverb'` followed by the full help
index.

**Pass / Fail:** PASS if the three surfaces agree and every verb works. FAIL on any missing verb or
divergence.

---

### C-10 — US English

**Change covered:** C-10 — spelling swept (F-008).

**Steps**
1. Repo-side: `grep -rin 'colour\|behaviour\|recognis\|centre\b\|cancelled' --include='*.lua' --include='*.md' . | grep -v '^./libs/'` → **no output**.
2. In client: `/pm config` → **Panels** → read the labels: "Background color", "Border color",
   "Accent bar color", "Class color".
3. Hover each of those four controls and read the tooltip.
4. `/pm panel <name> bgColor 1,0,0` still works (the **stored field name** is unchanged).

**Expected:** step 1 clean; steps 2–3 show US spelling everywhere; step 4 unaffected.

**Pass / Fail:** PASS if the grep is empty and no CLI field name changed. FAIL if any stored field
name was renamed (that would need a migration and is out of scope).

---

### C-11 — Hidden sub-verbs surfaced

**Change covered:** C-11 — `debug dump` and `panel deleteall` are discoverable (F-011, F-025).

**Steps**
1. `/pm help` → read the `debug` and `panel` rows.
2. `/pm config` → landing page → read the same two rows.
3. `/pm debug dump` → the console opens and fills with `[Dump]` lines.
4. Read the dump: it must name the master switch, unlock/preview state, screen size and scale, each
   panel with its frame name, and the `frames: N active, N pooled, N orphaned` line.
5. `/pm panel deleteall` → the confirm popup appears. Click **No**; `/pm panels` still lists them.
6. README: the command table mentions both, and the Panels-page control table has a **Defaults** row.

**Expected:** `dump` and `deleteall` are named in both the chat help and the landing page.

**Pass / Fail:** PASS if both are discoverable from `/pm help` alone. FAIL if either is still
undocumented, or if the confirm popup is missing on step 5.

---

### C-12 — Comments, tagline, `panelID`

**Change covered:** C-12 — cosmetic/consistency (F-017, F-018, F-019, F-021, F-024).

**Steps**
1. Compare `## Notes:` in the TOC (visible in the in-game AddOns list), the tagline on the settings
   landing page, and the README's opening sentence.
2. `/pm debug on`, `/pm panel <name> name NewName` → read the console.
3. `/pm debug dump` after deleting a panel → read the `frames:` line.

**Expected:** step 1 — one description, consistently worded. Step 2 — the rename produces exactly one
`[Panel]` line. Step 3 — `0 orphaned`.

**Pass / Fail:** PASS on all three. FAIL if the dump reports orphans after a clean delete.

---

### C-13 — Grid settings stop repainting

**Change covered:** C-13 — `snapToGrid`/`gridSize` no longer trigger a full render (F-012).

**Setup:** `/pm new G1` … `/pm new G5`. `/pm debug on`.

**Steps**
1. `/pm set settings.gridSize 8` → read the console.
2. `/pm set settings.snapToGrid false` → read the console.
3. `/pm set settings.enabled false` → read the console, and look at the screen.
4. `/pm set settings.enabled true`.
5. `/pm set settings.snapToGrid true`, `/pm set settings.gridSize 16`, then `/pm unlock`, drag a
   panel, `/pm lock`, `/pm panel G1 x`.

**Expected:** steps 1–2 produce a `[Set]` line but **no** `[Canvas] rendered N panels` line. Step 3
produces both, and every panel disappears. Step 5's stored X is a multiple of 16 — i.e. snapping
still works despite no longer broadcasting.

**Pass / Fail:** PASS if grid writes do not repaint **and** snapping still applies. FAIL if snapping
stopped working (that would mean the setting is read from a stale cache rather than live).

---

### C-14 — Registration retry and a spoken `/pm config` failure

**Change covered:** C-14 — the options entry is always present; `config` is never a silent no-op
(F-013).

**Steps**
1. Fresh login. Press **Esc → Options → AddOns** and confirm **Ka0s Panel Master** is listed
   **before** ever running `/pm config`.
2. Expand it: **General**, **Panels**, **Profiles** subcategories are present.
3. `/pm config` → the window opens on the landing page.
4. `/reload`, then repeat steps 1–3 (registration must be idempotent — no duplicate entry in the
   list).

**Expected:** exactly **one** Ka0s Panel Master entry with three subcategories, present from login.

**Pass / Fail:** PASS if the entry is present pre-`config` and appears exactly once after a reload.
FAIL on a duplicate entry (idempotence broken) or a missing one.

---

### C-15 — Small correctness cleanups

**Change covered:** C-15 (F-016, F-020, F-022, F-023).

**Steps**
1. **F-023:** `/pm set settings.enabled nope` → read the reply, then `/pm get settings.enabled`.
2. `/pm set settings.enabled off` → then `/pm get settings.enabled`. Then `on`.
3. **F-023 (panel path):** `/pm panel <name> mouseover nope` → read the reply, then
   `/pm panel <name> mouseover`.
4. **F-022:** `/pm new deleteall`, then `/pm panel deleteall` → observe.
5. Then `/pm delete deleteall`, then `/pm panel deleteall` → observe.
6. **F-020:** `/pm new U1`, unlock U1 individually from the Panels page, then `/pm panel deleteall`
   → confirm **Yes**. Then `/pm debug dump` and read the state lines.

**Expected**
- Step 1: an error naming the accepted tokens; `settings.enabled` is still `true`.
- Step 2: `false`, then `true`.
- Step 3: an error; `mouseover` unchanged.
- Step 4: the **panel** named `deleteall` is dumped (its fields listed) — the destructive verb does
  not fire.
- Step 5: with no such panel, the confirm popup appears.
- Step 6: the dump reports no unlocked panels and `registry: 0 panels`.

**Pass / Fail:** PASS on all six. FAIL if step 1 or 3 silently stores `false`, or if step 4 shows the
delete-all popup.

---

## Regression suite

Run after **all** changes are in, regardless of which ones you were testing.

| # | Check | Expected |
|---|---|---|
| R-01 | Fresh SV login | No Lua error; `/pm panels` reports no panels; SavedVariables file created on logout with `PanelMasterDB` and `global.schemaVersion = 1` |
| R-02 | `/reload` with 5 panels placed | All five reappear in the same place, same size, same colours; no error |
| R-03 | ADDON_LOADED → PLAYER_LOGIN → PLAYER_ENTERING_WORLD | No error at any stage; panels appear once world is entered, not before |
| R-04 | Zone change / loading screen | Panels persist; no duplicate frames (`/pm debug dump` → `0 orphaned`) |
| R-05 | Enter combat with all panels visible, leave combat | Panels unaffected; no *"Interface action failed because of an AddOn"* red text |
| R-06 | `/pm unlock` **in combat** | Grey queued notice; nothing becomes draggable; on leaving combat panels unlock and chat says `panels unlocked` |
| R-07 | `/pm config` **in combat** | Grey refusal notice, exactly the `options-ui-§2` text; the window does **not** open; it is **not** auto-opened when combat ends |
| R-08 | Profile switch on the Profiles page | Panels of the incoming profile appear immediately; outgoing panels gone; no error |
| R-09 | Profile copy, then profile reset | Same; the Panels page reflects the new set on next open |
| R-10 | Every General-page option toggled once | Each takes effect; each echoes exactly one `[Set]` console line when debug is on |
| R-11 | Master switch off → on | All panels hide, then reappear exactly as before |
| R-12 | Class colour on/off for bg, border, accent, accent border | Each follows the player's class colour; alpha from the picker is preserved in both states |
| R-13 | `Solid` / `None` on each of the four media fields | `None` draws nothing for that element; `Solid` draws the flat colour; no error |
| R-14 | Mouseover fade: set `mouseoverAlpha 0`, `mouseover on`, lock | Panel invisible until the cursor is over it; clicks still pass through to what is behind |
| R-15 | Rename a panel that another frame is anchored to | Old global name still exists but is hidden; new global name is live; the name box tooltip shows the new one |
| R-16 | 30 panels created, then master switch toggled 5 times | `/pm debug dump` frame count stays bounded — `active` ≤ 30, `pooled` small, `orphaned` 0 |

---

## Taint-specific tests

The review flagged no taint findings, but the addon has two deliberate lockdown gates that the
changes touch indirectly (C-02, C-14) — verify them:

| # | Steps | Expected |
|---|---|---|
| T-01 | Pull a training dummy. While in combat: click an action bar slot that sits over a panel | The ability fires; **no** `Interface action failed because of an AddOn` red text |
| T-02 | In combat, `/pm config` | Grey refusal, no window, no taint popup. Leave combat — the window does **not** open by itself |
| T-03 | Leave combat, `/pm config`, then close with Esc, then open the panel from **Esc → Options → AddOns → Ka0s Panel Master** | Both routes reach the same landing page; switching subcategories works from both |
| T-04 | In combat, tick **Unlock** on a panel from the Panels page (open the page before pulling) | Checkbox snaps back to unticked; grey queued notice; on leaving combat that one panel unlocks |
| T-05 | In combat, drag an already-unlocked panel | Drag works (non-secure frame, no gate) and no red text |

---

## Localization sanity

The review flagged a locale finding (F-008 / C-10). `locales/enUS.lua` carries no keys yet, so there
is nothing to fall through — but verify the strings the change touched still render.

1. Set the client to **deDE** (or frFR) and log in.
2. `/pm config` → **Panels**.
3. Confirm the English labels render as plain English text (not as a raw key, not as a box glyph),
   and that the em-dash and `▸` breadcrumb arrow render correctly.
4. `/pm help` → the cyan `[PM]` tag, the gold commands and the em-dash all render.
5. Switch back to enUS.

**Pass / Fail:** PASS if nothing renders as a missing glyph or a raw key.

---

## Performance spot-checks

Only for the perf-tagged changes (C-13, C-15's batching via C-02).

1. **Memory around a preview toggle.** With 10 panels placed:
   `/run collectgarbage("collect") print(collectgarbage("count"))` → note the number.
   `/pm preview`, `/pm preview`, then repeat the measurement. The delta should be small and should
   **not** grow with each repetition of the pair (run it five times).
2. **Render count on a grid write.** `/pm debug on`, `/pm set settings.gridSize 8`. Expect **zero**
   `[Canvas] rendered` lines (C-13).
3. **Render count on a preview toggle.** `/pm preview`. Expect **one** `[Canvas] rendered` line, not
   four (C-02).
4. **Mouseover ticker cost.** Turn `mouseover` on for 20 panels. `/console scriptProfile 1` →
   `/reload` → stand still for 60s → `/run UpdateAddOnCPUUsage() print(GetAddOnCPUUsage("PanelMaster"))`.
   Record the number as the baseline for future passes; the 10Hz shared ticker should be a small
   fraction of a millisecond per second of play.

---

## Sign-off

Run in a live Retail client on **2026-07-31** by Tushar Saxena, against the working tree at
471/471 headless tests and `luacheck .` 0/0. Reported as a blanket pass across the whole document —
the per-row notes below record scope, not separate verdicts.

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-01 | Yes | Pass | |
| C-02 | Yes | Pass | Includes the combat-gate bypass restored during the repair pass — preview is usable immediately in combat. |
| C-03 | Yes | Pass | |
| C-04 | Yes | Pass | |
| C-05 | Yes | Pass | |
| C-06 | Yes | Pass | Slider reach now widens to an out-of-range stored value (`E.SliderSpan`) rather than clamping it. |
| C-07 | Yes | Pass | All four subcategories render and build lazily after the peel. |
| C-08 | Yes | Pass | Two sites keep their gate by C-08's own escape clause — see 05_FINAL_SUMMARY "Accepted deviations". |
| C-09 | Yes | Pass | |
| C-10 | Yes | Pass | Labels and tooltips read in-client; headless coverage is impossible (AceGUI is stubbed). |
| C-11 | Yes | Pass | |
| C-12 | Yes | Pass | |
| C-13 | Yes | Pass | |
| C-14 | Yes | Pass | Retry subscribes from `OnInitialize`; the `OnEnable` placement was dead. |
| C-15 | Yes | Pass | |
| Regression R-01…R-16 | Yes | Pass | |
| Taint T-01…T-05 | Yes | Pass | No *"Interface action failed because of an AddOn"* text observed. |
| Localization | Yes | Pass | |
| Performance | Partial | Pass | Items 2 and 3 (render counts on a grid write and a preview toggle) pass. Items 1 and 4 ask for a recorded *baseline number* — memory delta across five preview cycles, and `GetAddOnCPUUsage` over 60s — and **no numbers were captured**, so those two rows stay open for a future pass. |
