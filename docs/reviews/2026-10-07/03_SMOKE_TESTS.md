# PanelMaster review: in-client smoke tests (2026-10-07)

Run these after the changes in `02_PROPOSED_CHANGES.md` land. Everything headless has already run (see `01_FINDINGS.md` › Measurement run). The one pre-flight line is to re-run `lua tests/run.lua` and `luacheck .` from the repo root and confirm 0 failures and 0/0. The owner runs every step here; nothing below is marked passed by the agent.

## Pre-flight

- Retail client, `## Interface: 120100`. Load PanelMaster from the `GIT/PanelMaster` symlink, never from a side worktree.
- `/console scriptErrors 1`, so a Lua error raises a popup.
- Use at least **two characters on one account**, both on the default `Default` profile (fresh installs land there; check with `/pm profile`).
- For the locale steps, use a client set to **ruRU** or **koKR**. If none is available, type the same strings into an enUS client and record which you used. On enUS, LOC-6 checks the slug arithmetic but not the client's font or input.
- `/pm debug on` before starting, so `[Set]`, `[Panel]` and `[Unlock]` lines are in the console for the record.

## Per-change tests

### C-01: non-Latin names keep distinct frame names (F-001)

**Setup:** Panels page open; no existing panel named `Panel`.

1. **LOC-6.** `/pm new Чат`, then `/pm new Фон`, then `/pm new Panel`.
2. Hover *Panel name* on each panel's General tab and note the frame name in the tooltip.
3. `/run print(PanelMaster_Panel_D0A7D0B0D182 ~= nil, PanelMaster_Panel_D0A4D0BED0BD ~= nil, PanelMaster_Panel_Panel ~= nil)`.
4. `/pm new Ärger`, then `/pm new Örger`.
5. Existing panels: any panel created **before** the change still reports its old frame name in the tooltip.

**Expected:** All five creates succeed. Step 3 prints `true true true`. The tooltips read `PanelMaster_Panel_D0A7D0B0D182`, `…_D0A4D0BED0BD`, `…_Panel`, `…_C384rger` and `…_C396rger`. The names render correctly in the band's *Panel* picker and in `/pm panels`. No refusal line.
**Pass / Fail:** Pass if every create succeeds with the listed frame names and step 5's old frame names are unchanged. Fail on any `would share the frame name` refusal, any `?` or mojibake, or a pre-existing panel whose frame name changed.

### C-02: delete-all names the profile (F-002)

**Setup:** Character A and character B both on profile `Default`, with two panels.

1. On character A, `/pm panel deleteall`. **Read the popup** and press **No**.
2. Settings ▸ AddOns ▸ Ka0s Panel Master ▸ Panels. Hover the header **Defaults** button and read the tooltip.
3. Press **Defaults**. The same popup appears. Press **Yes**.
4. Log in on character B.

**Expected:** The popup reads *"Delete every Ka0s Panel Master panel in this profile? Every character using this profile loses them — this cannot be undone."* The tooltip says it deletes every panel in this profile for every character using it. After step 3, `/pm panels` on A says `No panels yet`. On B, panels are also gone, which is exactly what the popup warned.
**Pass / Fail:** Pass if both texts name the profile and none says "this character". Fail if "on this character" appears anywhere.

### C-03: non-finite numbers are refused (F-003)

1. **NUM-1.** `/pm new Num`, then `/pm panel Num x 1e999`.
2. **NUM-2.** `/pm panel Num width nan`, then `/pm panel Num x nan`.
3. `/pm panel Num` (dump) and `/pm recover`.
4. **NUM-3.** `/reload`, then open `WTF/Account/<acct>/SavedVariables/PanelMaster.lua` and look at the `Num` record.

**Expected:** Steps 1 and 2 each print `error: expected a finite number`, and the stored values are unchanged. Step 3 shows finite `x`, `y` and `width`, and recover reports `every panel is already on screen`. In step 4 the file holds plain finite numbers, with no `inf`, `nan`, `-nan(ind)` or `1.#INF`.
**Pass / Fail:** Pass if every non-finite input is refused and the SavedVariables file is clean. Fail if any of those tokens appears or a panel vanishes off-screen.
*Pre-change note:* run NUM-3 **before** C-03 once, with `x 1e999`, to record what the client actually writes for a non-finite number. That answers the "unverified" in F-003.

### C-04: Sanitize covers every field (F-004)

1. Log out. In `SavedVariables/PanelMaster.lua`, pick one panel record and delete its `accentColor` key. Set `artBlend = "BOGUS"` and `artDesaturate = "yes"`. Log in.
2. Open that panel's **Accent bar** tab and look at the bar color swatch.
3. On its Opacity tab, nudge *Panel opacity* and release (any write triggers the record repair). Then `/pm panel <name> artBlend` and `/pm panel <name> artDesaturate`.
4. Pick another panel ▸ General ▸ *Copy settings from panel* ▸ choose the edited one. Then `/pm panel <other> artBlend`.

**Expected:** Step 2's swatch shows the shipped accent color, not white. Step 3 prints `artBlend = BLEND` and `artDesaturate = false`. Step 4 prints `artBlend = BLEND`.
**Pass / Fail:** Pass if all three hold. Fail on a white swatch, `BOGUS`, `yes` or `nil`.

### C-05: per-panel Delete and Reset confirm (F-005)

1. Panels ▸ pick a panel ▸ General ▸ **Reset**, then **No**.
2. **Reset**, then **Yes**.
3. **Delete**, then **No**.
4. **Delete**, then **Yes**.

**Expected:** Each press opens a popup naming the panel. **No** changes nothing: the panel stays, with all its settings. Step 2 resets the panel's size, colors and position to new-panel values while its name and frame name survive. Step 4 removes it, and the picker moves to the next panel.
**Pass / Fail:** Pass if no click acts without a popup and **No** is always a no-op. Fail otherwise.

### C-06: no held unlock outlives a stand-down (F-006)

1. With the addon **enabled**, start combat on a target dummy and type `/pm unlock`. Read the chat line. While still in combat, `/pm disable`. Leave combat.
2. `/pm enable`. Enter and leave combat once more.
3. `/pm disable`. In combat, `/pm set state.locked false`. Leave combat, then `/pm enable`.

**Expected:** Step 1: after `/pm disable` the held unlock is dropped (debug console: one `[Unlock]` line saying it was dropped because the addon stood down). Step 2: panels stay **locked** after the second combat exit. Step 3: no "unlock queued" line, because the write applies at once while down. After `/pm enable`, panels come up **unlocked**, matching `state.locked = false`, and nothing flips at the next combat exit.
**Pass / Fail:** Pass if panels never unlock by themselves at a later combat exit. Fail if `panels unlocked` appears at a combat exit you did not ask for.

### C-07: enabled-nil lists as enabled (F-007)

1. Log out. In SavedVariables, remove `enabled` from one panel record. Log in.
2. `/pm panels`, then open the Panels picker.

**Expected:** The panel is drawn, shows in yellow in `/pm panels`, and carries no `(disabled)` in the picker.
**Pass / Fail:** Pass if the list and the picker both agree with what is on screen.

### C-08: comment only

There is no in-client step.

### F-009 (upstream re-vendor)

There is no in-client step. After the re-vendor, the headless gate and `docs/test-cases.md` regeneration are the evidence.

## Localization sanity

Repeat **C-01** on a ruRU or koKR client if the first run used enUS. Also confirm the existing `docs/smoke-tests.md` LOC-1 to LOC-5, with LOC-2's expectation updated: two Ä/Ö names now both create.

## Regression suite

- `/reload` cleanly with zero Lua errors. Run login → first-time defaults on a fresh character: no panels, Lock frame ticked.
- ADDON_LOADED → PLAYER_LOGIN → PLAYER_ENTERING_WORLD: panels draw on the loading-screen exit, not before.
- Combat enter and leave with visibility *Only in combat* and *Only out of combat*: panels switch at the moment combat starts and ends.
- Profile switch with `/pm profile <name>` and from the Profiles page: panels follow the profile, and no individually unlocked panel carries over.
- `/pm unlock`, drag a panel, `/pm lock`, `/reload`: the panel stays where it was dropped, locked.
- Open every Panels-page tab and General-page tab and toggle each option once. There should be no errors, and every write should show in the `[Set]` log.
- `/pm disable` → every panel hidden, `/pm diagnostics` shows `stood down=true` and `mouseover: ticker=off`. `/pm enable` → everything back.
- **Cross-addon (in-client half):** with several Ka0s addons loaded, type each addon's root slash (`/at /am /bl /cm /kcd /lh /mm /pm /pfe /pc /wg`) and confirm each reaches its own addon. Then confirm Settings ▸ AddOns lists each addon exactly once and each multi-page addon's pages once each.

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-01 (LOC-6) | | | |
| C-02 | | | |
| C-03 (NUM-1..3) | | | NUM-3 pre-change result: |
| C-04 | | | |
| C-05 | | | |
| C-06 | | | |
| C-07 | | | |
| Regression suite | | | |
| Cross-addon in-client | | | |
