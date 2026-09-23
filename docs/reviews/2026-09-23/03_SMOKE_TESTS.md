# PanelMaster — in-client smoke tests, 2026-09-23

These are the checks only the game client can make, run **after** C-01 … C-09 from `02_PROPOSED_CHANGES.md` have landed. Everything that runs headless already ran in Step 0 (`01_FINDINGS.md` ▸ Measurement run).

## Pre-flight

1. From the repo root, re-run the green gate once:
   ```
   ~/.claude/wow-addon/bin/ka0s-bounded lua5.1 tests/run.lua
   ~/.claude/wow-addon/bin/ka0s-bounded luacheck .
   ```
   Both must be green (luacheck 0/0). Record the new pass count, which must equal `docs/test-cases.md`'s `## Totals` and the README badge.
2. Install: copy or symlink the repo folder to `World of Warcraft\_retail_\Interface\AddOns\PanelMaster` on a **Retail 12.1.0** client (`## Interface: 120100`).
3. Use one character, anywhere with a **target dummy** (for example Valdrakken or Dornogal training dummies), so combat can be entered and left at will.
4. In chat, run `/console scriptErrors 1` and then `/reload`. Keep BugSack or the default error frame visible. Any Lua error during a step is a **Fail** for that step.
5. Make three panels:
   - `/pm new SmokeA`, `/pm new SmokeB`, `/pm new SmokeC`
   - `/pm panel SmokeA scale 0.5`
   - `/pm panel SmokeB scale 2`
   - Leave SmokeC at scale 1.
6. Keep `/pm debug on` running for the session. The console (`/pm debug`) shows the `[Set]`, `[Lifecycle]` and `[Canvas]` lines the steps below cite.

---

## C-01 — The latch outranks the unlock decoration (F-001)

**Setup:** Addon enabled, panels locked, all three panels visible.

**Steps:**
1. Open `/pm config` → General → Master controls. Untick **Lock frame**. The three panels show gold outlines and name labels.
2. On the same tab, untick **Enable Ka0s Panel Master**.
3. Look at the screen, and try to drag where SmokeA was.
4. Tick **Lock frame** and then untick it again, still disabled.
5. Type `/pm set state.locked false`.
6. Go to the **Panels** page, select SmokeB and tick its **Unlock** box.
7. Go back to General and tick **Enable Ka0s Panel Master**.

**Expected:**
- After step 2: every panel disappears (outlines, labels and fills). The console shows `[Lifecycle] stood down (disabled)`.
- Steps 3–6: nothing appears on screen, and there is nothing to grab. The mouse clicks through to the world or UI underneath.
- Step 5: chat echoes `state.locked = false`. The write is accepted, but nothing is drawn.
- Step 7: all three panels reappear **unlocked** (outlines and labels), because that is the current state. The console shows `[Lifecycle] stood up`.

**Pass / Fail:** Pass only if no panel pixel and no drag handle is visible at any point between step 2 and step 7, and step 7 restores the unlocked view. Anything else is Fail.

## C-02 — Stand-down conformance cases

Headless only (`tests/test_disabled.lua`). Covered by pre-flight step 1. **Pass:** the four new `Disabled` cases appear in the `--list` inventory and pass.

## C-03 / C-04 — Combat visibility follows the pull (F-002)

**Setup:** Addon enabled, panels **locked**, standing next to a target dummy, out of combat.

**Steps:**
1. General → Master controls → **General visibility** → **Only in combat**. Close the settings window.
2. Confirm no panel is visible.
3. Attack the dummy.
4. Stop attacking and step away until you leave combat (the regen icon returns).
5. Set **General visibility** → **Only out of combat**, and close settings.
6. Attack the dummy again, then leave combat again.
7. Set **General visibility** back to **Always**.

**Expected:**
- Step 3: all three panels appear **the moment combat starts**, with no waiting for any other change.
- Step 4: they disappear the moment combat ends.
- Step 6: panels visible → hidden on entering combat → visible again on leaving.
- No Lua error, and no "Interface action failed" line.

**Pass / Fail:** Pass only if every transition in steps 3, 4 and 6 takes effect on the combat edge itself. Fail if any panel keeps its pre-combat state for the fight.

## C-05 — No frame leak across profile switches (F-004)

**Setup:** Profiles page. Make profile **P1** with panels created in order `Alpha`, `Xray`. Make profile **P2** with the same two names created in the **opposite** order (`Xray` first, then `Alpha`).

**Steps:**
1. `/run print(PanelMaster_Panel_Alpha, PanelMaster_Panel_Xray)` and note the two table addresses.
2. Switch P1 → P2 → P1 → P2 → P1 on the Profiles page (four switches).
3. Repeat the `/run` from step 1.
4. `/pm debug dump` and read the `frames:` line.

**Expected:**
- Step 3 prints the **same two addresses** as step 1: no new frame was created under either global name.
- Step 4: `frames: 2 active, N pooled, 0 orphaned`, where N does not grow with the number of switches.
- Both panels are drawn correctly after every switch.

**Pass / Fail:** Pass if the addresses are unchanged and the pooled count is stable across repeated switching.

## C-06 — Recover respects scale (F-003)

**Setup:** The three panels from pre-flight: SmokeA at scale 0.5, SmokeB at scale 2, SmokeC at scale 1. Addon enabled.

**Steps:**
1. `/pm panel SmokeA x 3000`, `/pm panel SmokeA point TOPLEFT`, `/pm panel SmokeA relPoint TOPLEFT`. SmokeA stays **visible** at about screen x 1500 on a 1920-wide UI scale.
2. `/pm panel SmokeB x 1500`, `/pm panel SmokeB point TOPLEFT`, `/pm panel SmokeB relPoint TOPLEFT`. SmokeB is now **off the right edge**, at about 3000 screen units.
3. `/pm recover`.
4. `/pm panel SmokeA x` and `/pm panel SmokeB x`.

**Expected:**
- Step 3 prints `moved 1 panel back on screen`.
- SmokeA is **unchanged** (`x = 3000`).
- SmokeB is pulled back on screen (`x` at most 960).
- A single `[Set] recover positions: N rows` line in the console.

**Pass / Fail:** Pass if only the genuinely off-screen panel moved. Fail if SmokeA moved or SmokeB stayed off-screen.

## C-07 — One grid maximum (F-007)

**Steps:** General → Editing → **Grid size**. Drag the slider to its right end. Type `/pm set settings.gridSize 100`.

**Expected:** The slider's maximum and the CLI's clamp both report the same ceiling (64 if the recommended option was taken): `settings.gridSize = 64 px`.

**Pass / Fail:** Pass if the slider max equals the CLI clamp.

## C-08 — Editor Unlock tick (F-008)

**Setup:** Panels page open with SmokeC selected.

**Steps:**
1. Tick SmokeC's **Unlock**. Only SmokeC gets an outline.
2. With the Panels page still open, type `/pm lock`.
3. Tick **Lock frame** off on General (global unlock), then return to the Panels page.
4. Attack a dummy, tick SmokeC's **Unlock** (it is deferred), then leave combat.

**Expected:**
- Step 2: SmokeC's box unticks by itself.
- Step 3: the box is ticked and **disabled**, with a tooltip explaining the global unlock.
- Step 4: after combat ends, the box shows **ticked** and SmokeC has its outline.

**Pass / Fail:** Pass if the box always matches what is drawn.

## C-09 — Comment and doc corrections

No in-client check. Review the diff.

---

## Regression suite

| # | Check | Expected |
|---|---|---|
| R1 | `/reload` with the addon enabled | No error. Panels draw at `PLAYER_ENTERING_WORLD` in their stored places |
| R2 | Delete `WTF\Account\<acct>\SavedVariables\PanelMaster.lua` and log in | Defaults populate. No panels. `/pm panels` says `No panels yet …`. `/pm version` prints `v1.1.1` (or the bumped version) |
| R3 | Log in with the addon **disabled** (`/pm disable`, then `/reload`) | No panel drawn. `/pm` opens settings. Ticking Enable draws panels immediately, with no zone change needed |
| R4 | Enter and leave combat with **Always** visibility | Panels never flicker. No error |
| R5 | Profile switch, copy and reset on the Profiles page | Panels follow the active profile. *Reset all settings* asks first |
| R6 | Every Master-controls row toggled once, plus Editing / New panels rows | Each takes effect. No error |
| R7 | Minimap button: left click toggles lock (enabled). Left click prints the refusal line (disabled). Right click opens settings in both states | As described |
| R8 | `/pm debug dump` | Registry and frame counts agree, with `0 orphaned` |

## Cross-addon (fold into any session with several Ka0s addons loaded)

1. Type each root and confirm it reaches its own addon: `/at`, `/am`, `/bl`, `/cm`, `/kcd`, `/lh`, `/mm`, `/pm`, `/pc`, `/wg`, and the full-name forms.
2. Open Settings → AddOns. Each Ka0s addon appears **once**. PanelMaster's General, Panels and Profiles pages appear once each.

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-01 | | | |
| C-02 | | | headless |
| C-03 | | | |
| C-04 | | | headless |
| C-05 | | | |
| C-06 | | | |
| C-07 | | | |
| C-08 | | | |
| C-09 | | | diff review |
| R1–R8 | | | |
| Cross-addon | | | |
