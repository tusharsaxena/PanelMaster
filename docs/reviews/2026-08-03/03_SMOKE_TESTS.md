# Ka0s Panel Master — Manual Smoke Tests (2026-08-03 review)

Run **after** the changes in `02_PROPOSED_CHANGES.md` have been applied. Every section maps to one
change ID. Fill in the sign-off table at the bottom.

---

## Pre-flight

1. **Green gates first — these are not optional and they run before the client starts.**
   ```
   cd <repo>
   lua tests/run.lua       # expect: N passed, 0 failed  (696 before this review's new cases)
   luacheck .              # expect: 0 warnings / 0 errors
   ```
   If either is red, stop — nothing below is meaningful (testing-§4).

2. **Install.** Copy (or symlink) the repo folder to
   `World of Warcraft/_retail_/Interface/AddOns/PanelMaster`. Confirm `PanelMaster.toc` reads
   `## Interface: 120007` and that `libs/LibKa0s/` contains eight `.lua` files plus `LibKa0s.xml`.

3. **Client setup.**
   ```
   /console scriptErrors 1     # errors surface as a popup instead of silently
   /reload
   ```
   Retail only. Any character, any spec, any realm type — nothing in this addon is class-, spec- or
   instance-sensitive. A **fresh `SavedVariables`** is required for §C-03-b and §R-2: to get one,
   exit the client and delete
   `WTF/Account/<ACCOUNT>/SavedVariables/PanelMaster.lua` (and the per-character copy if present).

4. **Second install for the degraded cases (§C-01, §C-02).** Copy the addon folder a second time as
   `PanelMaster` in a *separate* WoW install or, more simply, temporarily rename
   `PanelMaster/libs/LibKa0s` to `PanelMaster/libs/_LibKa0s_disabled` and `/reload`. **Rename it back
   before running any other section.** Expected on login in that state: one chat line beginning
   `[PM] The LibKa0s library is missing from this installation of Ka0s Panel Master (expected in
   libs/LibKa0s); running on reduced built-in fallbacks.`

---

## C-01 — Degraded `FormatKV`: the panel CLI survives a missing library

**Change covered:** C-01 — publish a degraded `FormatKV` from the Slash stub (F-001).

**Setup:** the degraded install from Pre-flight step 4 (`libs/LibKa0s` renamed away), `/reload`.

**Steps:**
1. `/pm new SmokeA`
2. `/pm panel SmokeA`
3. `/pm panel SmokeA width`
4. `/pm panel SmokeA width 300`
5. `/pm panel SmokeA fitart`
6. `/pm panels`
7. Rename `libs/_LibKa0s_disabled` back to `libs/LibKa0s` and `/reload`.
8. `/pm panel SmokeA` again.

**Expected:**
- Steps 2-6 produce chat output and **no Lua error popup**. Before this change, steps 2-5 each raised
  `settings/Slash.lua:101: attempt to call field 'FormatKV' (a nil value)`.
- Step 2 lists every panel field, one per line, in plain `field = value` form (the degraded
  formatter — deliberately **not** the gold-key/white-value styling).
- Step 4 echoes the stored width, i.e. `width = 300`.
- Step 5 either reports a fitted size or the sentence `this panel draws no artwork to fit to`.
- Step 8 lists the same fields with the **library's** styling (gold key, white value) — proving the
  degraded formatter is a fallback, not a replacement.

**Pass / Fail:** PASS iff no Lua error appears in the degraded install for any of steps 2-6, **and**
the step-2 line style visibly differs from the step-8 line style.

---

## C-02 — The degraded-path test cases actually gate this

**Change covered:** C-02 — degraded-load test cases for the Slash stub (F-001).

**Setup:** repo checkout, no client needed.

**Steps:**
1. `lua tests/run.lua` → note the count.
2. Temporarily delete the `Sl.FormatKV` definition you added to the stub in C-01.
3. `lua tests/run.lua`
4. Restore it. Now temporarily replace the stub's body with `Sl.FormatKV = lib and lib.FormatKV`
   — i.e. the forbidden "just use the library's" shortcut.
5. `lua tests/run.lua`
6. Restore the correct implementation and re-run.

**Expected:**
- Step 3 is **RED**, naming `FormatKV` in the member sweep and in the `/pm panel` verb case.
- Step 5 is **RED** on the third guard (`the degraded FormatKV is the library's`).
- Steps 1 and 6 are **GREEN** with the same count (previous total + 2 or +3 depending on how the
  guard was placed).

**Pass / Fail:** PASS iff the suite is red in both step 3 and step 5. A suite that stays green in
either is not testing the invariant (testing-§12).

---

## C-03 — `Sanitize` normalizes `artDesaturate` and `artBlend`

**Change covered:** C-03 (F-002).

### C-03-a — an illegal stored value is repaired on the next write

**Setup:** normal install (library present). One panel named `SmokeB` with artwork set.

**Steps:**
1. `/pm new SmokeB`
2. `/pm panel SmokeB artTexture class-mage`
3. Log out fully (to flush SavedVariables).
4. Edit `WTF/Account/<ACCOUNT>/SavedVariables/PanelMaster.lua`: find the `SmokeB` record and set
   `["artBlend"] = "MOD",` and delete its `["artDesaturate"]` line entirely.
5. Log back in.
6. `/pm panel SmokeB artBlend`
7. `/pm panel SmokeB width 250`  (any write, to drive the record through the seam)
8. `/pm panel SmokeB artBlend`
9. `/pm panel SmokeB artDesaturate`
10. Open **Options → AddOns → Ka0s Panel Master → Panels**, select `SmokeB`, look at the
    **Blend mode** and **Desaturate** controls.

**Expected:**
- Step 8 reports `artBlend = BLEND` (repaired to the template default; `MOD` is not a member of
  `C.ART_BLEND`).
- Step 9 reports `artDesaturate = false`, **not** `nil`.
- Step 10: the Blend mode dropdown shows **Normal** selected (not blank) and Desaturate is unticked.
- The panel still draws its Mage artwork throughout — the repair must not change what is on screen.

**Pass / Fail:** PASS iff steps 8, 9 and 10 all report the repaired values and no Lua error occurs.

### C-03-b — a healthy profile is untouched

**Setup:** fresh `SavedVariables` (Pre-flight step 3).

**Steps:**
1. `/pm new SmokeC`, `/pm panel SmokeC artTexture race-orc`, `/pm panel SmokeC artBlend ADD`,
   `/pm panel SmokeC artDesaturate true`
2. `/reload`
3. `/pm panel SmokeC artBlend` and `/pm panel SmokeC artDesaturate`

**Expected:** `artBlend = ADD` and `artDesaturate = true` — the change must not reset a value the
user chose.

**Pass / Fail:** PASS iff both values survive the reload unchanged.

---

## C-04 — `SunnArt.Installed()` resolution

**Change covered:** C-04 (F-003).

**Setup:** normal install. No Sunn pack required.

**Steps:**
1. `lua tests/run.lua` → green.
2. In game: `/pm new SmokeD`, open **Options → AddOns → Ka0s Panel Master → Panels**, select
   `SmokeD`, open the **Artwork** dropdown.
3. Scroll the whole list.

**Expected:** the dropdown opens without error and lists `None` first, the bundled catalog grouped by
category, and `Custom path…` last. If option **(c)** (wire the gate) was chosen, additionally confirm
that with no Sunn pack installed there is **no** `Sunn -> …` category, and that installing one makes
it appear after a `/reload`.

**Pass / Fail:** PASS iff the suite is green and the dropdown is unchanged in content from before the
change (options (a) and (b)), or changes exactly as described (option (c)).

---

## C-05 / C-06 — Dead-surface removal does not break loading

**Changes covered:** C-05 (`C.MEDIA_FALLBACK`, F-006), C-06 (`NS.Format`, F-007).

**Setup:** normal install, then the degraded install.

**Steps:**
1. `luacheck .` → 0/0 (catches an orphaned reference immediately).
2. `lua tests/run.lua` → green.
3. `/reload` in game; confirm no Lua error popup.
4. `/pm panel SmokeB bgTexture None` then `/pm panel SmokeB bgTexture Solid`.
5. Rename `libs/LibKa0s` away, `/reload`, run `/pm panels`, rename it back, `/reload`.

**Expected:** step 4 shows the panel's fill disappearing and returning — the media fallback path
still resolves through `Compat.FetchMedia`. Step 5 produces the degraded notice and a panel list, no
error.

**Pass / Fail:** PASS iff steps 1-5 are clean.

---

## C-07 — The README artwork example actually works

**Change covered:** C-07 (F-004).

**Setup:** normal install, one panel named `ChatBG`.

**Steps:**
1. `/pm new ChatBG`
2. Type, verbatim from the edited `README.md` line, the artwork command — i.e.
   `/pm panel ChatBG artTexture class-mage`
3. `/pm panel ChatBG artFill FILL`
4. `/pm unlock` and look at the panel.

**Expected:** step 2 echoes `artTexture = class-mage` (**not** `unknown artwork. Available: …`), and
step 4 shows the Mage emblem filling the panel. Then repeat the whole of `docs/smoke-tests.md`'s
artwork section (around its line 223) and confirm the label it names now exists in the dropdown.

**Pass / Fail:** PASS iff the README's own example runs without a refusal, and the smoke-test doc's
artwork step names a label present in the dropdown.

---

## C-08 — The corrected `/pm panel` grammar

**Change covered:** C-08 (F-005).

**Setup:** normal install, panel `ChatBG` from C-07.

**Steps:**
1. `/pm panel ChatBG artFill SQUISH`   (the corrected form of `docs/smoke-tests.md:296`)
2. `/pm panel set ChatBG artFill FILL` (the *old, wrong* documented form — confirm it is wrong)

**Expected:**
- Step 1 → `error: expected one of: STATIC, STRETCH, FILL, FIT, TILE` — the enum refusal the step was
  written to test.
- Step 2 → `no panel called 'set'` — demonstrating why the old documentation was misleading.

**Pass / Fail:** PASS iff step 1 produces the enum list (and not a name-lookup failure).

---

## C-09 / C-10 — Documentation and rename

**Changes covered:** C-09 (F-008), C-10 (F-009).

**Steps:**
1. Read `docs/ARCHITECTURE.md`'s bus table: confirm the `Ka0s_PanelMaster_PanelChanged` row now names
   both `Canvas` and the Panels settings page.
2. With the Panels page **open** and a panel selected, run `/pm panel <that panel> width 400` in
   chat. Watch the page.
3. `/pm panel <a panel with no artwork> fitart`
4. Open the Panels page, select a panel with no artwork, press **Fit to artwork**.

**Expected:**
- Step 2: the Width slider on the open editor moves to 400 **in place** — no page flicker, no
  teardown. This is the consumer C-09 documents.
- Steps 3 and 4 both print the sentence `this panel draws no artwork to fit to` (C-10 changed the
  variable name, not the message — the message must be identical to before).

**Pass / Fail:** PASS iff the doc row is correct, the slider updates in place, and both failure
messages read as sentences rather than numbers.

---

## Regression suite

Not tied to a single change; these cover what the changes could plausibly break.

| # | Check | Expected |
|---|---|---|
| R-1 | `/reload` with 3+ panels on screen | no error popup; every panel redraws in the same place |
| R-2 | Fresh `SavedVariables` → login | no panels drawn (ships empty by design); `/pm panels` says `No panels yet` |
| R-3 | Cold login: `ADDON_LOADED` → `PLAYER_LOGIN` → `PLAYER_ENTERING_WORLD` | no error; panels appear after the loading screen, not before |
| R-4 | Enter combat with panels visible, leave combat | panels stay drawn and correctly positioned throughout (they are non-secure and deliberately not gated) |
| R-5 | `/pm unlock` **during** combat | chat: `unlock queued — panels unlock when you leave combat`; on leaving combat, `panels unlocked` and the handles appear |
| R-6 | `/pm config` **during** combat | refuses with a message; does **not** open, and does **not** open by itself when combat ends |
| R-7 | Options → AddOns → Ka0s Panel Master: open **each** of General, Panels, Profiles | every page renders; no error; the scrollbar is present on all of them even when the content is short |
| R-8 | On the General page, toggle every option once and move both sliders | each write echoes/applies; the Debug console checkbox tracks the window when it is closed with **Esc** |
| R-9 | Profiles page: create a new profile, switch to it, switch back | panels disappear and reappear correctly; no orphaned frames (check with `/pm debug dump` → `0 orphaned`) |
| R-10 | `/pm preview` on, `/reload` while on, then look | the three placeholders are swept on login (`/pm debug on` first to see the `[Preview] swept …` line) |
| R-11 | `/pm resetall` | `all settings reset to defaults (your panels are untouched)`; `/pm panels` still lists your panels |
| R-12 | `/pm help` and the settings landing page's command list | identical rows, identical wording, all 18 verbs present |
| R-13 | Drag a panel while unlocked, with snap on | position snaps to the grid and survives `/reload` |
| R-14 | Rename a panel, then `/framestack` over it | the frame name is **unchanged** from before the rename |

---

## Performance spot-check

Only one change touches a hot-ish path (C-03 adds two operations to `Sanitize`, which runs per
write). A full profiler pass is not warranted; a sanity check is.

1. `/run collectgarbage("collect"); print(collectgarbage("count"))` — note the number.
2. Create 20 panels, drag several, change ten fields.
3. Repeat step 1.

**Expected:** the delta is dominated by the 20 records themselves and is stable across repeats — no
growth on repeated drags of the same panel (which would indicate a per-write allocation leak).

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
| C-07 | | | |
| C-08 | | | |
| C-09 | | | |
| C-10 | | | |
| Regression R-1…R-14 | | | |
| Perf spot-check | | | |
