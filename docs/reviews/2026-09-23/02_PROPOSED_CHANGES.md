# PanelMaster — proposed changes (HLD + LLD), 2026-09-23

Derived from `01_FINDINGS.md`. The standards cross-check was performed against **Ka0s WoW Addon Standard v2.64.0 (2026-09-23)**. The index and all 27 section files were fetched verbatim from `tusharsaxena/WowAddonStandards@master`.

Nothing here edits `libs/` or `tests/_kit/`. This review raised no upstream findings, so the upstream change-set below is empty. No change bumps `NS.SCHEMA_VERSION`: none of them changes the shape of a stored value.

---

## HLD — themes

### T1. One show ladder: the latch outranks the unlock decoration (F-001, F-006)

**What.** Today the stand-down rung (`modules/Canvas.lua:802`) and the unlock decoration (`modules/Unlock.lua:148-178`) are two independent answers to "is this frame shown", and the second one runs last. The change makes `Canvas:Render` decide once:
- while the latch is **down**, every frame is hidden and stripped of its overlay;
- while it is **up**, the decoration applies as today.

**Why this shape.** `slash-commands-§7` requires hiding to be enforced *at the source, inside the addon's own show-decision ladder*. Putting the check where the ladder already lives means every future re-render (combat transition, profile switch, settings change, per-panel unlock) inherits it for free.

**Alternatives rejected:**
- **An imperative sweep in `NS.StandDown`** that locks everything and hides every frame. §7 names this failure: hidden frames come back.
- **A disabled gate on each unlock surface** (*Lock frame* row, `/pm set state.locked`, the editor tick). That makes three gates to keep in step and a fourth for the next surface. It also refuses settings writes the player makes on purpose, which §7 explicitly allows while disabled: a write the **player** causes is not a game-event write. The unlock *state* may still change while the addon is off. It just cannot draw until the addon is back up.
- **A second teardown path** beside the latch. That is anti-pattern #85's other face.

**Trade-off.** A player who unlocks while disabled sees nothing until they re-enable, and then the panels come up unlocked. That is consistent with how every other setting behaves while off, and `performance-§6`'s "stand back up from current state" rule requires it.

### T2. Combat state comes from the event and the combat flag, not from lockdown (F-002, F-005)

**What.**
- The two transition handlers pass the transition's own truth into the repaint: `OnRegenDisabled` → in combat, `OnRegenEnabled` → out of combat.
- `Compat.InCombat()` answers from `UnitAffectingCombat("player")` (presence-guarded), with `InCombatLockdown()` as the fallback, for every other render.

**Why.** Lockdown begins after `PLAYER_REGEN_DISABLED` and ends before `PLAYER_REGEN_ENABLED`, so it reads `false` inside both handlers. `events-frames-taint-§2` states the rule outright: display state SHOULD use `UnitAffectingCombat`, and transitions SHOULD be driven off the two events. `compat` puts the shim in `core/Compat.lua` behind a direct presence check, never a flavor check.

**Alternatives rejected:**
- **A one-frame `C_Timer.After(0, …)` deferral** of the repaint. It adds a timer that the stand-down would then have to cancel (§7), and it still reads the wrong API for a display decision.
- **A session `State.inCombat` flag maintained by the handlers.** It cannot be maintained while the addon is stood down, because the events are unregistered, so it would be stale on stand-up.

**Trade-off.** `BuildSpec` stays pure. It already takes `inCombat` as an argument. The override is threaded through `RenderForCombat` → `RenderAll` → `Render` as an optional argument, so every existing caller keeps its behavior.

### T3. Recovery measures in the frame's own units (F-003)

**What.** `R:Recover` divides the screen extent by each record's **effective** scale before bounding its offsets. The effective scale is the panel's own scale times the master Scale.

**Why.** `applySpec` sets the scale before the anchor, so offsets are scaled units. The fix is one computation, and it has to agree with the renderer.

**Alternatives rejected:**
- **Converting stored offsets to UIParent units at every write.** That is a stored-value change: it would need a migration and would move every existing scaled panel.
- **Duplicating `masterScale` inside Registry.** That creates a second copy of a rule that must agree with the renderer, which is the copy that goes stale.

The helper moves to `core/Util.lua`, which both modules already depend on, and both call it.

### T4. The pool bound the renderer promises is actually kept (F-004)

**What.** `Canvas:RenderAll` releases every retired **or mismatched** frame before acquiring any. A frame is then always back in the pool before another id asks for its name.

**Why.** WoW never collects frames. The file's own header promises "one per distinct FRAME name used this session", and `events-frames-taint-§6` asks for pooled high-churn UI. `Render(id)` keeps its one-id path unchanged.

### T5. Small coherence fixes (F-007, F-008, F-009)

- One grid maximum.
- An editor tick that cannot show a state the panel is not in.
- Comments and two docs that describe the code as it is now.

No behavior change beyond F-008's widget state.

---

## Upstream change-set

**None.** No `[upstream]` finding was raised. `libs/LibKa0s/` and `tests/_kit/` are byte-identical to `../LibKa0s` at `v1.55.0`, and no change below targets either path.

---

## LLD — per change

### C-01 — Latch-aware decoration in `Canvas:Render` (F-001)

- **Target:** `modules/Canvas.lua`, `Canvas:Render` (`:779-825`).
- **Before (`:802`, `:822-823`):**
  ```lua
  if NS.Lifecycle and NS.Lifecycle:IsDown() then spec.shown = false end
  ...
  applySpec(f, spec)
  if NS.Unlock and NS.Unlock.Decorate then NS.Unlock:Decorate(f, rec) end
  ```
- **After:**
  ```lua
  local down = NS.Lifecycle and NS.Lifecycle:IsDown()
  if down then spec.shown = false end
  ...
  applySpec(f, spec)
  -- The latch outranks the unlock decoration: a stood-down addon draws nothing, unlocked or not
  -- (slash-commands-§7). Stripping keeps the frame mouse-transparent while it waits.
  if down then
    if NS.Unlock and NS.Unlock.StripOverlay then NS.Unlock:StripOverlay(f) end
  elseif NS.Unlock and NS.Unlock.Decorate then
    NS.Unlock:Decorate(f, rec)
  end
  ```
- **Standing up:** `NS.StandUp` → `RenderAll` → `Render` finds the latch up and decorates again, so an unlocked session comes back unlocked, from current state (`performance-§6`). No change to `NS.StandDown`.
- **Risk:** Low. `StripOverlay` is already called on `release`, and it is idempotent. The `Decorate` call keeps its existing method-presence guard, which is the convention this file's header records (`modules/Canvas.lua:21-24`).
- **Standards:**
  - Satisfies `slash-commands-§7` ("hidden at the source").
  - Avoids anti-pattern #85, because there is no second teardown path.
  - Does not narrow the slash surface (`slash-commands-§2`).
- **Rejected:** a `NS.Lifecycle:IsDown()` gate inside `Unlock:SetUnlocked`. It would refuse a settings write while the page stays live, and §7 lets a player write settings while disabled.

### C-02 — Stand-down conformance cases for the unlock rung (F-006)

- **Target:** `tests/test_disabled.lua` (this addon's own suite; the kit is not touched).
- **New cases:**
  1. `Disabled N: an unlocked session hides every panel when the addon is disabled`. Seed, `S:Set("state.locked", false)`, `S:Set(ENABLED, false)`. Assert `shownPanels()` is empty and no panel frame has mouse enabled.
  2. `Disabled N: the Lock frame row cannot bring panels back while disabled`. Disable, then `S:Set("state.locked", false)`. Assert empty.
  3. `Disabled N: /pm set state.locked false cannot bring panels back while disabled`. The same thing, through `NS.Slash:OnSlash("set state.locked false")`.
  4. `Disabled N: a per-panel unlock cannot bring a panel back while disabled`. `NS.Unlock:SetPanelUnlocked(id, true)` while disabled. Assert empty. Then re-enable and assert the panel comes up **decorated**, which is the positive half so the case cannot pass on a dead render.
- **Falsifiability:** Each case carries `-- red under: revert C-01 (call Decorate unconditionally after applySpec)`. Each was already red against today's code in the scratch probe recorded in `01_FINDINGS.md` F-001.
- **Movement:** The pass count and `docs/test-cases.md` move **in the same change** as C-01, as does the README `Tests-` badge (`testing-§5`/§7).

### C-03 — Combat truth from the event and the combat flag (F-002)

- **Targets:** `core/Compat.lua` (`Compat.InCombat`, `:79-82`), `modules/Canvas.lua` (`Render`, `RenderAll`, `RenderForCombat`), `core/PanelMaster.lua` (`OnRegenEnabled` / `OnRegenDisabled`, `:116-127`), `.luacheckrc` (`read_globals`).
- **Compat (before → after):**
  ```lua
  function Compat.InCombat()
    if type(InCombatLockdown) ~= "function" then return false end
    return InCombatLockdown() and true or false
  end
  ```
  ```lua
  -- Display state, so the COMBAT FLAG rather than lockdown (events-frames-taint-§2): lockdown
  -- begins after PLAYER_REGEN_DISABLED and ends before PLAYER_REGEN_ENABLED, so it reads false
  -- inside both transition handlers. Lockdown stays as the fallback on a client without the flag.
  function Compat.InCombat()
    if type(UnitAffectingCombat) == "function" then
      return UnitAffectingCombat("player") and true or false
    end
    if type(InCombatLockdown) ~= "function" then return false end
    return InCombatLockdown() and true or false
  end
  ```
- **Canvas:**
  - `function Canvas:Render(id, inCombat)`. Inside it, `if inCombat == nil then inCombat = NS.Compat.InCombat() end` before `BuildSpec`.
  - `function Canvas:RenderAll(inCombat)` forwards the argument to each `Render`. It pairs with C-05, which restructures the same function, and C-05's sketch includes it.
  - `function Canvas:RenderForCombat(inCombat)` passes it to `RenderAll`.
  - The bus handlers already call `RenderAll()` / `Render(id)` with explicit argument lists (`modules/Canvas.lua:878-880`), so no message payload can leak into the new parameter.
- **Handlers:**
  - `OnRegenDisabled` → `NS.Canvas:RenderForCombat(true)`.
  - `OnRegenEnabled` → `NS.Canvas:RenderForCombat(false)`, after `ResumePending` as today.
- **Lint:** add `"UnitAffectingCombat"` to `read_globals` in `.luacheckrc`, so the gate stays 0/0.
- **Unchanged:** the unlock deferral (`modules/Unlock.lua:132`, `:234`) stays on `InCombatLockdown()`. That is out of scope and still correct.
- **Risk:**
  - Low. `UnitAffectingCombat("player")` is not a secret-returning API, and the addon reads no trigger-set API (`events-frames-taint-§8` row).
  - Verify in-client that the explicit transition argument is honored. `03_SMOKE_TESTS.md` C-03 covers it.
- **Standards:** `events-frames-taint-§2` (both SHOULDs), and `compat` (a presence-guarded shim in `core/Compat.lua`, no flavor check).

### C-04 — Make the combat case model the client (F-005)

- **Target:** `tests/test_canvas.lua:422-446`, and `tests/test_compat.lua` for one new case.
- **Change:**
  - Deliver `OnRegenDisabled()` while `T.mocks.__inCombat` is still **false** (the real ordering), and assert the `outOfCombat` panel hides.
  - Mirror the change for an `inCombat` profile: shown after `OnRegenDisabled`, hidden after `OnRegenEnabled` with the flag still **true**.
  - Add a `test_compat` case asserting that `Compat.InCombat()` follows `UnitAffectingCombat` when present. The kit's mock base already models it (`tests/_kit/mock_base.lua:1103`), and `tests/wow_mock.lua:269` models `InCombatLockdown`.
- **Falsifiability:** The reordered case is **red against today's code**, and must be run red before C-03 lands (`testing-§12`, `testing-§4`). Record `-- red under: drop the explicit inCombat argument from OnRegenDisabled`.
- **Rules:** Never weaken the assertion to stay green. `docs/test-cases.md` and the README badge move in the same change.

### C-05 — Two-pass `RenderAll` (F-004)

- **Target:** `modules/Canvas.lua:829-842`.
- **After:**
  ```lua
  function Canvas:RenderAll(inCombat)
    -- Release every retired or mismatched frame BEFORE acquiring any, so a frame is always back
    -- in the pool before another id asks for its name. One pass at a time let a profile switch
    -- that swapped two ids' frame names CreateFrame a second copy of a live global name.
    local want = {}
    local records = NS.Registry:All()
    for _, rec in ipairs(records) do want[rec.id] = NS.Registry.FrameName(rec) end
    for id, f in pairs(active) do
      if want[id] == nil or f.__frameName ~= want[id] then release(f); active[id] = nil end
    end
    for _, rec in ipairs(records) do Canvas:Render(rec.id, inCombat) end
    NS.Debug("Canvas", "rendered %s panels", #records)
  end
  ```
  One table per `RenderAll`, the same count as today's `seen`. `RenderAll` is event-driven, not per-frame.
- **Test:** add a `test_profiles.lua` case that plants `{1 A, 2 B}` → `{1 B, 2 A}` through `OnProfileChanged` several times. It counts named `CreateFrame` calls through `mocks.CreateFrame` and asserts **zero** after the first render, plus `_G`-name ⇄ `active` frame identity.
- **Falsifiability:** The case is red today. The scratch probe recorded 6 calls over 6 swaps.
- **Risk:** Low. The `Render(id)` mismatch branch stays as the single-id fallback.
- **Standards:** `events-frames-taint-§6`.

### C-06 — Recover in scaled units (F-003)

- **Targets:** `core/Util.lua` (new `Util.EffectiveScale`), `modules/Canvas.lua` `addGeometry` (`:112-113`) and `masterScale` (`:85-89`), `modules/Registry.lua` `R:Recover` (`:876-904`).
- **Util:**
  ```lua
  -- The scale a panel's frame is actually drawn at: its own, clamped, times the addon-wide master
  -- (options-ui-§15). One definition, because the renderer and recovery must agree on it.
  function Util.EffectiveScale(rec, settings)
    local own = Util.Clamp(rec and rec.scale, C.MIN_PANEL_SCALE, C.MAX_PANEL_SCALE,
      C.PANEL_TEMPLATE.scale)
    local master = tonumber(settings and settings.scale)
    if not master or master <= 0 then master = 1 end
    return own * master
  end
  ```
- **Canvas:** `spec.scale = Util.EffectiveScale(rec, settings)`. Remove the now-unused `masterScale`. `masterAlpha` stays.
- **Recover:**
  ```lua
  local settings = (NS.db and NS.db.profile and NS.db.profile.settings) or {}
  ...
  local s = Util.EffectiveScale(rec, settings)
  local minX, maxX = offsetRange(relPoint, w / s)
  local minY, maxY = offsetRangeY(relPoint, h / s)
  ```
- **Tests:** add two `test_registry.lua` cases:
  - a visible TOPLEFT panel at `x = 3000`, `scale = 0.5` is **not** moved;
  - an off-screen TOPLEFT panel at `x = 1500`, `scale = 2` **is** moved.

  Both are red today. Keep the existing five cases unchanged; they are the scale-1 characterization (`testing-§13`).
- **Risk:** This changes what `/pm recover` does for scaled layouts, which is the intent. `README.md:261`'s prose stays true.
- **Complexity:** `R:Recover` (CCN 12 today, `modules/Registry.lua@876-904`) gains no branches.

### C-07 — One grid maximum (F-007)

- **Target:** `settings/Schema.lua:72`.
- **Change:** `max = C.MAX_GRID` in place of `max = 64`, **or** lower `C.MAX_GRID` to 64 (`core/Constants.lua:100`). This is a product choice. **Recommended:** lower the constant to 64. Every UI and CLI path has only ever been able to store up to 64, so no install moves, and the slider does not grow.
- **Test:** one `test_schema.lua` case asserting `S:FindRow("settings.gridSize").max == C.MAX_GRID`.

### C-08 — Editor *Unlock* tick tells the truth (F-008)

- **Target:** `settings/PanelEditor.lua:743-758`, with one guarded call-out from `modules/Unlock.lua`. The precedent is `modules/Registry.lua:516`, which already calls `NS.PanelEditor:ForgetSelection()` behind a presence guard.
- **Change:**
  - Give the tick a scalar refresher that reads `NS.Unlock:IsPanelUnlocked(rec.id)`.
  - Disable the tick, with a tooltip line, while the global unlock is on.
  - From the end of `U:SetUnlocked`, `U:SetPanelUnlocked` and `U:ResumePending`, call `if NS.PanelEditor and NS.PanelEditor.RefreshUnlock then NS.PanelEditor:RefreshUnlock() end`. That runs `NS.Helpers.RefreshPanel(ctx, false)` when the Panels page is open.
- **Layout constraint:** `settings/PanelEditor.lua` is **1476 lines**, 24 under `layout-§1`'s 1500 cap, and its split is open as issue #47. This change must be net-small (target ≤ 12 added lines) or land **after** the #47 split. It must never push the file over the cap. `docs/automated-tests/RESULTS.md` already names this file in the watch list.
- **Rejected:** a new `UnlockChanged` bus message that the editor subscribes to. It would add a fourth survivor registration to the named set `tests/test_disabled.lua` pins, and it lands in the open-evolutions question §7 records about settings-panel subscriptions.

### C-09 — Comment and doc corrections (F-009)

Text only. Each sentence is rewritten to the current mechanism:

| File | Correction |
|---|---|
| `core/PanelMaster.lua:10` | The printer is defined in `core/CoreSetup.lua` |
| `core/CoreSetup.lua:17-18` | AceConsole's `:Print`, not AceGUI's |
| `settings/Slash.lua:292-293` | The enabled row's `onChange` is `NS.RefreshEnabled()`, and it does not announce |
| `defaults/Profile.lua:4-5`, `core/Database.lua:16` | `global` carries LibDBIcon's `minimap` table and the runner-written stamp (not a default) |
| `core/Database.lua:170` | Example line reads `schema v2` |
| `core/PanelMaster.lua:101-103`, `core/LifecycleSetup.lua:112-115`, `docs/ARCHITECTURE.md:228`, `docs/data-flow.md:200` | State the real reason for painting at PEW (the world and UIParent are final there; the boot stand-up runs inside OnEnable). Drop the claim that recovery measures at render |

If `tests/test_docs.lua` pins any of these strings, move it in the same change.

---

## Regression pressure and movement

- **Pass count.** About +11 new cases: C-02 +4, C-04 +2 (one reordered case replaced, one mirrored and one compat case added), C-05 +1, C-06 +2, C-07 +1, C-08 +1. The expected total is ≈ 895. The **exact** number comes from `lua tests/run.lua --list`, never from this estimate. `docs/test-cases.md` and the README `Tests-` badge move **in the same change** as each case, never as a deferred follow-up (`testing-§5`). No test is weakened or deleted to turn a suite green.
- **Complexity.** No function is expected to cross CCN 15:
  - `Canvas:RenderAll` gains one loop and one comparison.
  - `Compat.InCombat` gains one branch (CCN ~4).
  - `R:Recover` is unchanged in branches.
  - `settings/PanelEditor.lua`'s LOC is the one number to watch (C-08).

  The next release's regeneration (`/wow-addon:bump-version`) confirms all of this. Nothing is regenerated here.
- **SavedVariables.** No schema bump and no migration: no stored value changes shape.
- **Perf evidence.** The addon has no `tests/perf.lua` and no captures (the ratified decline). C-05's allocation claim ("one table per RenderAll, as today") is by inspection. C-03 adds one API call per panel render. Both are event-driven paths with no per-frame work.

## Standards conformance (per change)

| Change | Rules satisfied / constraints honored | Tempting option rejected, and the rule it broke |
|---|---|---|
| C-01 | `slash-commands-§7` (hidden at source), `performance-§6` (stand up from current state) | Imperative hide or lock in `NS.StandDown` (`slash-commands-§7`, anti-pattern #85). Per-surface disabled gates (§7's survivor list keeps the settings writes live) |
| C-02 | `slash-commands-§7` conformance test, `testing-§12` (`red under` lines) | Asserting on a handler's return value (§7's own test rule) |
| C-03 | `events-frames-taint-§2`, `compat` (presence-guarded shim in `core/Compat.lua`) | A `C_Timer.After(0)` repaint, which adds a timer the stand-down must cancel (§7) |
| C-04 | `testing-§12`, `testing-§4` (red first) | Leaving the mock order as is (a case that cannot fail for the real sequence) |
| C-05 | `events-frames-taint-§6` | Anonymous pooled frames plus `_G` aliases (rejected in the file's own header; breaks the public frame-name contract) |
| C-06 | One definition shared by render and recover (options-ui-§15 master rows as multipliers) | Converting stored offsets (`savedvariables-§1` migration for no gain) |
| C-07 | Single source for a bound | n/a |
| C-08 | `layout-§1` cap respected; precedent guarded cross-module call | A new bus message, which widens §7's named survivor set |
| C-09 | `documentation` | n/a |

None of these changes introduces a new deviation. `docs/ARCHITECTURE.md`'s `## Documented deviations` register is unaffected.
