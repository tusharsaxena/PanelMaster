# In-client smoke tests — Ka0s Panel Master, 2026-09-07

Run **after** the changes in [`02_PROPOSED_CHANGES.md`](02_PROPOSED_CHANGES.md) have been applied.

Everything here needs a logged-in game client. The headless suites — `luacheck .`,
`lua5.1 tests/run.lua`, `lua5.1 tests/run.lua --list`, `lizard` — already ran in Step 0 of the
review and are recorded in `01_FINDINGS.md`'s Measurement run block; they are **not** restated as
manual steps.

---

## Pre-flight

1. **Re-run the headless gate once, from the repo root**, before installing anything:
   `luacheck . && lua5.1 tests/run.lua`. Both must be clean, and the suite's total must equal the
   number in `docs/test-cases.md` and the README `[tests]` badge. If C-01, C-02, C-03 or C-06 added
   cases, all three must already have moved together in the same commit.
2. Copy the addon folder to `Interface/AddOns/PanelMaster`. Interface `120007` (Midnight 12.0.7) —
   the value in `PanelMaster.toc`. Retail only; there are no per-version TOCs to keep in step.
3. **Install at least one other AceGUI-configured addon that exposes a border dropdown** — this is
   required for C-01 and cannot be faked. Anything using `AceGUI-3.0-SharedMediaWidgets`'
   `LSM30_Border` will do; a second Ka0s addon (AbsorbTracker, ConsumableMaster, KickCD or
   MultiMeters) is the most convenient, since all four ship the same fixup and are the other half of
   the wrapper-chain problem.
4. `/console scriptErrors 1` and reload, so a Lua error raises a visible popup rather than being
   swallowed.
5. Start from **fresh SavedVariables** for the first pass: delete
   `WTF/Account/<ACCOUNT>/SavedVariables/PanelMaster.lua` and the per-character copy. Keep a backup
   of a *populated* one — several cases below need existing panels.
6. Any character, any spec. A target dummy is needed for the combat cases: Stormwind (Valley of
   Heroes) or Orgrimmar (Valley of Honor).

---

## C-01 — the border-dropdown fixup no longer reaches other addons

**Change covered:** C-01 — the `LSM30_Border` fixup is applied per widget, not by re-registering the
shared AceGUI widget type.

**Setup.** PanelMaster plus at least one other addon with a border dropdown (pre-flight step 3).
Fresh login, no reload in between.

**Steps.**
1. Log in. Do **not** open anything yet.
2. Open the *other* addon's configuration and navigate to a border dropdown (in a Ka0s sibling this
   is the Panels/appearance area; in a third-party addon, any "Border" media picker).
3. Observe the **closed** dropdown.
4. Open the dropdown and hover two or three rows.
5. Now open `/pm config` → **Panels** → select or create a panel → find the panel's **Border** media
   dropdown.
6. Observe that closed dropdown, then open it and hover two or three rows.
7. `/reload`, then repeat steps 2–3 (the old bug fired at `PLAYER_LOGIN`, so a reload is the second
   chance for it to reappear).

**Expected.**
- Step 3 and step 7: the other addon's closed border dropdown shows its **42×42 preview swatch** at
  the left, and its bar starts to the right of it — the upstream appearance, unmodified.
- Step 4: the popup's per-row hover preview still swaps the popup backdrop's border, unchanged.
- Step 6: PanelMaster's own closed border dropdown shows **no** swatch and its bar starts flush at
  the frame's left edge, aligned with the sliders and checkboxes above and below it — i.e. exactly
  what the old global patch produced, now only here.
- No Lua error popup at any step.

**Pass / Fail.** PASS iff the other addon's dropdown is untouched **and** PanelMaster's own dropdown
is still flush-left. Either one alone is a FAIL: an unchanged other-addon dropdown with a gap in
PanelMaster means the fixup was dropped instead of scoped.

---

## C-02 — delete-all clears the Test-mode flag with the panels

**Change covered:** C-02 — one session-state sweep, shared by `dropSessionIDs` and `R:DeleteAll`.

**Setup.** Fresh SavedVariables. Log in.

**Steps.**
1. `/pm preview` — three sample panels appear and the screen unlocks.
2. `/pm config` → **General** → **Master controls**. Confirm **Test mode** is ticked.
3. Close the settings window.
4. `/pm panel deleteall`. Confirm **Yes** in the popup.
5. Re-open `/pm config` → **General** → **Master controls**.
6. Press **Test mode** once.

**Expected.**
- Step 4: chat reads `[PM] deleted 3 panels.` and the screen is empty.
- Step 5: **Test mode is unticked.** (Before this change it stayed ticked with nothing on screen.)
- Step 6: the three sample panels come back **on the first press** — not the second.
- No Lua error at any step.

**Pass / Fail.** PASS iff Test mode reads unticked at step 5 **and** one press at step 6 restores the
samples.

**Regression watch.** Repeat steps 1–6 substituting the settings-panel **Delete all** button for the
slash verb at step 4; both reach `R:DeleteAll` and must behave identically.

---

## C-03 — a byte colour with a shorthand alpha is opaque

**Change covered:** C-03 — `Util.ParseColor` decides the fourth component separately.

**Setup.** Fresh SavedVariables. `/pm new Smoke`.

**Steps.**
1. `/pm unlock` and drag `Smoke` somewhere clearly visible against the game world.
2. `/pm panel Smoke bgColor 255,0,0,1`
3. Observe the panel.
4. `/pm panel Smoke` and read the `bgColor` line back.
5. `/pm panel Smoke bgColor 255,0,0,255` — observe and read back.
6. `/pm panel Smoke bgColor 0.5,0,0,0.5` — observe and read back.
7. `/pm panel Smoke bgColor banana` — read the chat response.

**Expected.**
- Step 3: a **fully opaque red** panel. (Before this change it was effectively invisible.)
- Step 4: `bgColor = 1.00,0.00,0.00,1.00`.
- Step 5: identical to steps 3–4 — opaque red, `1.00,0.00,0.00,1.00`.
- Step 6: a half-opacity dark red, reading back `0.50,0.00,0.00,0.50`.
- Step 7: a refusal naming the expected format; **no** silent white panel and no Lua error.

**Pass / Fail.** PASS iff steps 3–5 all give an opaque red reading `1.00,0.00,0.00,1.00`, step 6 is
unchanged from before the change, and step 7 refuses.

---

## C-04 — the `[Init]` line reports the packaged version

**Change covered:** C-04 — `NS.InitSummary` resolves through `NS.Version()`.

**Setup.** Before installing, **edit the installed copy's `PanelMaster.toc`** so `## Version:` reads
something other than the constant in `core/Namespace.lua:7` — e.g. `1.0.0-smoke`. (This is a
temporary edit to the *installed* copy under `Interface/AddOns/`, never to the repo.)

**Steps.**
1. Log in.
2. `/pm debug on`.
3. Read the `[Init]` line in chat.
4. `/pm version`.
5. Restore the installed TOC's `## Version` afterward.

**Expected.**
- Step 3: `[PM] [Init] PanelMaster v1.0.0-smoke, schema v2, profile 'Default', N panels` — the
  **TOC's** version, not `1.0.0`.
- Step 4: `[PM] v1.0.0-smoke` — the same string. The two surfaces agree.

**Pass / Fail.** PASS iff both lines carry `1.0.0-smoke`. A `[Init]` line reading `v1.0.0` while
`/pm version` reads `v1.0.0-smoke` is the exact defect F-004 describes and is a FAIL.

---

## C-05 — the PanelEditor split changed nothing a user can see

**Change covered:** C-05 — `settings/PanelEditor.lua` peeled into siblings.

**Setup.** Restore the **populated** SavedVariables backup from pre-flight step 5, so there are
several panels with varied settings (different colours, borders, accents, artwork).

**Steps.**
1. Log in. Confirm every stored panel is on screen, in its stored position, at its stored size.
2. `/pm config` → **Panels**. Confirm the panel list is populated and in the same order.
3. Select each panel in turn. For each, confirm the editor's every section renders: name, position
   and size, background colour, border, accent bars, artwork.
4. On one panel, change one control in **each** section and confirm the panel updates on screen.
5. On a panel with artwork, press **Fit to artwork** and confirm the panel resizes.
6. `/reload`. Confirm everything from step 4 and 5 persisted.
7. Create a new panel from the Panels page, edit it, delete it.

**Expected.** Identical behaviour to before the split at every step. No section missing, no control
inert, no Lua error, no `attempt to call a nil value` from a builder that moved file.

**Pass / Fail.** PASS iff every section renders and every edited control takes effect and persists.
**Any** missing section is a FAIL — a builder was left behind in the move.

---

## C-06 — the mouseover ticker stops when nothing is tracked

**Change covered:** C-06 — the `OnUpdate` script is cleared once the tracked set empties.

**Setup.** Fresh SavedVariables. `/pm new Fade`.

**Steps.**
1. `/pm config` → **Panels** → `Fade` → enable **mouseover fade** and set a mouseover opacity
   clearly different from the panel's opacity (e.g. resting 0.2, full 1.0).
2. Close the settings window. Move the cursor **onto** the panel and off it several times.
3. `/run print(collectgarbage("count"))` — note the number. Wait ~30 seconds without moving the
   cursor over the panel, then run it again.
4. Re-open the editor and **disable** mouseover fade on `Fade`.
5. Move the cursor over the panel repeatedly.
6. `/pm debug on`, then `/pm debug dump`. Read the `frames:` line.
7. Re-enable mouseover fade and confirm the effect comes back.

**Expected.**
- Step 2: the panel fades to the resting opacity when the cursor leaves and goes to full when it
  enters, promptly (within ~0.1s).
- Step 3: no runaway growth between the two readings. This is a coarse observation, **not** a
  measurement — the addon ships no perf harness (a ratified `performance-§1` deviation), so no
  numeric claim is made or expected here.
- Step 5: the panel's opacity no longer changes on hover. It stays at its own opacity.
- Step 6: the dump renders with no error and reports the live frame counts.
- Step 7: fading works again immediately — the driver's script was re-installed, not lost.

**Pass / Fail.** PASS iff fading works at step 2, stops at step 5, and **comes back at step 7**. Step
7 is the one that catches the likely regression: a driver unhooked and never re-hooked.

---

## Regression suite

Not tied to any one change; these cover what the change-set could plausibly break.

| # | Check | Expected |
|---|---|---|
| R-1 | `/reload` with panels on screen | No Lua error; every panel returns in position |
| R-2 | Cold login on **empty** SavedVariables | Defaults populate; **no** panel appears (a fresh install draws nothing by design); no error |
| R-3 | `ADDON_LOADED` → `PLAYER_LOGIN` → `PLAYER_ENTERING_WORLD` | No error popup across the whole boot |
| R-4 | Enter and leave combat at a dummy with panels visible | Panels behave per the **General visibility** setting; no `Interface action failed because of an AddOn` |
| R-5 | `/pm unlock` **during** combat | `[PM] unlock queued — panels unlock when you leave combat`; panels unlock on leaving combat, once |
| R-6 | `/pm config` **during** combat | The panel refuses to open and says so; it does **not** pop open when combat ends |
| R-7 | Open the settings panel from **Esc → Options → AddOns → Ka0s Panel Master** as well as `/pm config` | Both reach the same page; the breadcrumb reads `Ka0s Panel Master ▸ …` |
| R-8 | Every tab on the **General** page, every control toggled once | Each takes effect; each survives `/reload` unless it is marked session-only |
| R-9 | Profiles page: create, switch, copy, reset, delete | Panels follow the profile; no stale panel from the outgoing profile stays on screen |
| R-10 | `/pm resetall` → confirm **Yes** | The profile resets, **panels are deleted** (the popup says so), and nothing from the old profile is left drawn |
| R-11 | `/pm help`, `/pm panels`, `/pm list`, `/pm get`, `/pm set`, `/pm reset`, `/pm recover`, `/pm version` | Each answers with a `[PM]`-prefixed line; no raw uncoloured `print` output |
| R-12 | `/panelmaster` alias | Reaches the same dispatcher as `/pm` |
| R-13 | The debug console: `/pm debug`, `debug on`, `debug off`, `debug dump`, its **Copy** button, and closing it with **Esc** | Window opens/closes; the Master-controls **Debug console** checkbox stays in step with the window, including after an Esc close |
| R-14 | With **SunnArt** and a pack addon installed, open the artwork picker | The pack's themes appear in the catalog; with none installed, the picker is silent, not empty-with-an-error |

**Taint.** No taint findings were raised — every panel is a non-secure frame and the only combat
gates are UX ones — so there is no taint-specific section. R-4, R-5 and R-6 are the combat coverage.

**Localization.** No locale findings were raised (the addon ships English-only by an explicit 1.0.0
scope decision and no string routes through `NS.L`), so no non-enUS pass is required.

**Performance.** No numeric perf check is prescribed. The addon declines the perf harness as a
ratified `performance-§1` deviation, so there is no `/pm perf` verb, no two-arm capture protocol and
no `docs/perf-analysis/` bundle to produce. C-06's step 3 is an observation, not a measurement, and
no claim in this bundle rests on it.

---

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-01 | | | |
| C-02 | | | |
| C-03 | | | |
| C-04 | | | |
| C-05 | | | |
| C-06 | | | |
| C-07 | n/a (comment only) | | |
| C-08 | n/a (no code) | | |
| R-1 … R-14 | | | |
