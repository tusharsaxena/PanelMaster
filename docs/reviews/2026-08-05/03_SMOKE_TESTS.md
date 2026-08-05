# PanelMaster — in-client smoke tests (2026-08-05)

Executed **after** the changes in `02_PROPOSED_CHANGES.md` are applied. Everything that runs in a
shell already ran in Step 0 and is recorded in `01_FINDINGS.md` — it is not repeated here.

**Pre-flight, one line:** from the repo root, `luacheck .` and `lua5.1 tests/run.lua` must both be
clean before you log in. If either is red, stop; nothing below is meaningful.

---

## Pre-flight (in-client)

1. Copy the working tree to `World of Warcraft/_retail_/Interface/AddOns/PanelMaster/`. The TOC
   declares `## Interface: 120007` — use a Retail client on that build or later.
2. `/console scriptErrors 1` — Lua errors must be visible, not swallowed. Reload.
3. Any character will do; a **second** character on the same account is needed for the profile test
   (R-6) and for C-05.
4. Have a target dummy reachable (Stormwind / Orgrimmar training dummies) for the combat tests.
5. Keep a copy of your existing `WTF/Account/<ACCT>/SavedVariables/PanelMaster.lua` before you start.
   Several tests below deliberately mutate it.

**The degraded-install arm.** Four of the ten changes only manifest with the vendored library
missing. Prepare it once, now, and switch between arms by renaming the folder:

- Healthy arm: `Interface/AddOns/PanelMaster/libs/LibKa0s/`
- Degraded arm: rename that folder to `libs/_LibKa0s_off/` and `/reload`.

Never test both arms in one session without a `/reload` between them.

---

## C-01 — the Slash stub answers `FormatKV`

**Change covered:** C-01 — `/pm panel …` no longer raises in a degraded install (F-001).

**Setup:** degraded arm (`libs/LibKa0s` renamed away), `/reload`, at least one panel:
`/pm new SmokeA`.

**Steps:**
1. `/pm panel SmokeA`
2. `/pm panel SmokeA width`
3. `/pm panel SmokeA width 320`
4. `/pm panel SmokeA fitart`
5. `/pm panels`

**Expected:**
- Step 1 prints a `Panel SmokeA (id N)` header followed by one `key = value` line per field. No red
  error text, no `attempt to call field 'FormatKV'`.
- Step 2 prints a single line, `width = 200` (or whatever it currently is).
- Step 3 prints `width = 320` and the panel visibly widens.
- Step 4 prints `this panel draws no artwork to fit to`.
- Step 5 prints the list with `SmokeA` in it.

**Pass / Fail:** PASS only if none of the five steps produces a Lua error popup or red
`Interface action failed` / `attempt to call` text, and steps 1–3 each print at least one line.

---

## C-02 — the schema boot validation actually fires

**Change covered:** C-02 — `Schema:Register` reports an unresolvable path (F-002).

**Setup:** healthy arm, fresh login.

**Steps:**
1. `/reload` and watch chat during load.
2. `/pm list` — confirm every setting still lists with a value.
3. `/pm set settings.gridSize 8`, then `/pm get settings.gridSize`.

**Expected:**
- Step 1: **no** `schema path missing default:` line. (There is no bad path today; the corrected
  guard must not invent one.)
- Step 2: every row shows a real value, none shows `nil`.
- Step 3: `settings.gridSize = 8 px`.

**Pass / Fail:** PASS if login is silent on this and steps 2–3 behave exactly as before the change.
FAIL if any `schema path missing default:` line appears — that means a real typo exists and the
finding was worse than reported.

---

## C-03 — the degraded console acknowledges in its own words

**Change covered:** C-03 (F-003).

**Setup:** degraded arm, `/reload`.

**Steps:**
1. `/pm debug on`
2. `/pm debug off`
3. Switch to the healthy arm (`/reload` after restoring `libs/LibKa0s`), then `/pm debug on` and
   `/pm debug off` again.

**Expected:**
- Degraded arm: a plain `[PM] debug logging is on` / `… is off`, with **no** green/red color on the
  state word, plus (once per session) the "…so the debug console window is unavailable." notice.
- Healthy arm: the library's `debug logging ON` / `OFF` with the green/red state word, and the
  console window opens on `/pm debug`.

**Pass / Fail:** PASS if the two arms differ in wording as described and both flip the flag (verify
with `/pm debug dump` — the dump must appear either way).

---

## C-04 — `/pm config` answers every time in a degraded install

**Change covered:** C-04 (F-007).

**Setup:** degraded arm, `/reload`.

**Steps:**
1. `/pm config`
2. `/pm config`
3. `/pm config`
4. Restore `libs/LibKa0s`, `/reload`, then `/pm config`.
5. Esc → Options → AddOns → Ka0s Panel Master.

**Expected:**
- Steps 1–3 each print `[PM] The LibKa0s library is missing … so the settings panel is unavailable.`
  — **three lines, one per invocation.**
- Step 4 opens the settings panel on the landing page (logo, tagline, slash-command list).
- Step 5 reaches the same panel and its four subcategories (General, Panels, Profiles).

**Pass / Fail:** PASS only if step 2 and step 3 each produce a line. A silent second `/pm config` is
a FAIL — that is the finding unfixed.

---

## C-05 — profile switching still repairs incoming records

**Change covered:** C-05 — `RunMigrations` removed from the profile callback (F-004).

**Setup:** healthy arm. Character A with two or three panels created and moved.

**Steps:**
1. On character A: `/pm new ProfA`, drag it somewhere distinctive, note its size/position from
   `/pm panel ProfA`.
2. Open Settings → Ka0s Panel Master → Profiles. Create a new profile `SmokeProfile`.
3. Observe the screen: the old panels should disappear (the new profile is empty).
4. `/pm new ProfB`, place it.
5. Switch back to `Default` on the Profiles page.
6. `/pm panels` and `/pm panel ProfA`.
7. `/reload`, then `/pm panels` again.
8. Log in as character B (same account), `/pm panels`.

**Expected:**
- Step 3: `ProfA` vanishes from the screen and from `/pm panels`.
- Step 5–6: `ProfA` reappears, at the exact position and size recorded in step 1; `ProfB` is gone.
- Step 6: `frameName` in the dump is a non-empty `PanelMaster_Panel_…` string.
- Step 7: unchanged after reload.
- Step 8: character B lands on the shared `Default` profile and sees `ProfA`.

**Pass / Fail:** PASS if no panel loses its position, its size or its `frameName` across any switch,
and no Lua error fires on a switch. This is the regression the removed call was nominally guarding.

---

## C-07 — the mouseover ticker survives a missing Unlock module

**Change covered:** C-07 (F-006).

**Setup:** healthy arm. `/pm new Fader`, then `/pm panel Fader mouseover true` and
`/pm panel Fader mouseoverAlpha 0.1`.

**Steps:**
1. Move the cursor off the panel — it should fade to near-invisible within ~0.1 s.
2. Move the cursor over it — it should return to full alpha.
3. `/pm unlock` — the panel should hold at full alpha with a gold outline and its name, and stay
   there while you move the cursor away.
4. `/pm lock` — the fade resumes.
5. **Negative arm (optional, requires editing the TOC):** comment out `modules\Unlock.lua` in
   `PanelMaster.toc`, `/reload`, and watch chat for 30 seconds with `Fader` on screen.

**Expected:**
- Steps 1–4 exactly as described.
- Step 5: at most one error at load (from the missing module), and **no repeating error every 0.1 s**
  from `modules/Canvas.lua`. Restore the TOC line afterward.

**Pass / Fail:** PASS if steps 1–4 behave and step 5 produces no repeating `Canvas.lua:551` error.

---

## C-08 — the settings message still reaches the renderer

**Change covered:** C-08 — the receiver reads `NS.Schema.MSG_SETTINGS` (F-011).

**Setup:** healthy arm, at least two panels on screen.

**Steps:**
1. Open Settings → Ka0s Panel Master → General.
2. Untick **Enable panels**.
3. Tick it again.
4. Untick **Show names while unlocked**, then `/pm unlock`, then re-tick it.
5. `/pm set settings.enabled false`, then `/pm set settings.enabled true`.

**Expected:**
- Step 2: every panel disappears **immediately**, without a reload and without toggling test mode.
- Step 3: every panel reappears in its stored position.
- Step 4: the name labels vanish and reappear on the unlocked panels, live.
- Step 5: identical behavior from the CLI.

**Pass / Fail:** PASS if the panels react on the same frame as the click. Any need to `/reload` or
to toggle `/pm preview` to see the change is a FAIL — that is the exact bug
`core/PanelMaster.lua:57-60` documents.

---

## C-10 — the settings pages still build with one AceGUI

**Change covered:** C-10 (F-012, F-008).

**Setup:** healthy arm, fresh login (so no page has been shown yet).

**Steps:**
1. `/pm config` → landing page renders (logo, tagline, "Slash Commands" heading and rows).
2. Click **General** → every row renders; scroll to the bottom with the mouse wheel.
3. Open the **Grid size** row's companion **Recover panels** button — press it.
4. Click **Panels** → the create box, the panel selector dropdown and one panel's editor render.
5. Open a texture dropdown (Background), scroll the page with the wheel while it is open.
6. Click **Profiles** → AceDB's profile controls render inside the canvas.

**Expected:**
- Every page renders on first show; the scrollbar is always shown and is inert where the content
  fits.
- Step 3 prints either `every panel is already on screen` or `moved N panel(s) back on screen`.
- Step 5: the open dropdown **closes** as soon as the wheel turns; the page keeps scrolling
  afterward (no dead mouse wheel).
- No Lua error on any page.

**Pass / Fail:** PASS if all six steps render and step 5's dropdown closes without breaking the
wheel.

---

## Regression suite (not tied to one change)

| # | Check | Expected |
|---|---|---|
| R-1 | `/reload` with panels on screen | Every panel returns at its exact position, size, color and artwork. No error. |
| R-2 | Delete `PanelMaster.lua` from SavedVariables, log in | Addon loads, `/pm panels` says `No panels yet`, nothing is drawn uninvited. |
| R-3 | ADDON_LOADED → PLAYER_LOGIN → PLAYER_ENTERING_WORLD | No error at any stage; panels appear at PLAYER_ENTERING_WORLD, not before. |
| R-4 | Enter combat with a dummy while panels are visible | Panels stay drawn, keep their alpha, and the mouseover fade keeps working. No `Interface action failed because of an AddOn`. |
| R-5 | `/pm unlock` **during** combat | Prints `unlock queued — panels unlock when you leave combat`; nothing becomes draggable. On leaving combat, panels unlock and `panels unlocked` prints. |
| R-6 | Profile switch (covered fully in C-05) | See C-05. |
| R-7 | Every General option toggled once, then `/reload` | Every value persists; the panel reopens showing the persisted value. |
| R-8 | `/pm preview` on, `/reload`, `/pm panels` | The three placeholders are **gone** after the reload — the sweep found them — and no placeholder survives as a real panel. |
| R-9 | `/pm resetall` | Prints `all settings reset to defaults (your panels are untouched)`; every panel still exists. |
| R-10 | `/pm panel deleteall` | A confirm popup appears; Yes wipes every panel, No wipes nothing. |
| R-11 | `/pm help`, and the landing page's command list | Both list the same 18 verbs, in the same order, with the same descriptions. |
| R-12 | `/pm version` | One line, matching the TOC's `## Version`. |

---

## Taint-specific tests

The review raised **no** taint findings — panels are non-secure frames and nothing here writes to a
secure one. These two are run anyway because the changes touch the options-open path and the combat
deferral:

| # | Steps | Expected |
|---|---|---|
| T-1 | Enter combat on a dummy. `/pm config`. | The panel **refuses** to open and does not queue itself; nothing pops open when combat ends. No red `Interface action failed` text. Leave combat, `/pm config` opens normally. |
| T-2 | Enter combat. Click an action bar slot over a panel's area. Then `/pm unlock`, click the slot again. | The action fires normally both times; the panel is mouse-transparent while locked and the queued unlock does not make it grab the click. |

---

## Localization sanity

The review raised **no** locale findings and this build ships English-only by an explicit scope
decision (`locales/enUS.lua:7-9`). One check only, to confirm the seam is inert rather than broken:

| # | Steps | Expected |
|---|---|---|
| L-1 | Switch the client to deDE, `/reload`, `/pm config`, `/pm help` | Every string renders as **English prose**. Nothing renders as a raw key (`DEBUG_ON`, `COPY_TITLE`, `LINES`, `RESET_ALL`) — that would be the `L` trap escaping into a real client. |

---

## Performance spot-checks

This addon ships no perf harness, so there is **no** `/pm perf` capture protocol to run and no
`docs/perf-runs/` record to compare against. Two coarse in-client observations only, and neither is
recorded as a number the project stands behind:

| # | Steps | Expected |
|---|---|---|
| P-1 | With ~10 panels, half with `mouseover true`: `/run collectgarbage("collect"); print(collectgarbage("count"))`, wait 60 s idle, print again. | The delta is small and does not grow with time. The 10 Hz driver at `modules/Canvas.lua:565` should not be accumulating. |
| P-2 | `/console scriptProfile 1` → `/reload` → sit idle 60 s → `/run UpdateAddOnCPUUsage(); print(GetAddOnCPUUsage("PanelMaster"))` | A small number. Read it as an order of magnitude only — the profiler attributes shared frame work coarsely and this is not the addon's true cost. |

---

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-01 | | | |
| C-02 | | | |
| C-03 | | | |
| C-04 | | | |
| C-05 | | | |
| C-06 | n/a (headless) | | verified by `lua5.1 tests/run.lua` |
| C-07 | | | |
| C-08 | | | |
| C-09 | n/a (comments) | | |
| C-10 | | | |
| R-1 … R-12 | | | |
| T-1, T-2 | | | |
| L-1 | | | |
| P-1, P-2 | | | |
</content>
