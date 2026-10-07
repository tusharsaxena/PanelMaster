# PanelMaster review: proposed changes (2026-10-07)

The standard was resolved at **Ka0s WoW Addon Standard v2.76.1 (2026-10-07)**: the index plus 27 section files, fetched to scratch with `curl`. Every change below was checked against it. Finding ids refer to `01_FINDINGS.md`.

## HLD: themes

### T1: The frame-name contract holds for every alphabet (F-001)

**What.** `Util.Slugify` keeps every non-ASCII byte as two hex digits instead of discarding it, so a panel name always produces a non-empty slug that tells names apart. `Чат` becomes `D0A7D0B0D182` and `Фон` becomes `D0A4D0BED0BD`. `Ärger` / `Örger` become `C384rger` / `C396rger`.

**Why this shape.** The contract is that another addon can work out `PanelMaster_Panel_<slug>` from the panel name alone (README.md:96-103, `docs/data-flow.md:130`). Hex encoding keeps it deterministic and derivable. Uniqueness still comes from the Registry's existing frame-name check.

**Alternatives rejected.**
- *Append the panel id when the slug is empty or collides.* The frame name would then depend on creation order, which breaks the derivable-from-the-name contract.
- *Keep the raw UTF-8 bytes in the global name.* WoW accepts them, but nobody can type them into a WeakAura anchor box reliably, and any downstream `%w`-based tooling breaks on them too.
- *Transliterate.* That needs a table per script, and it would still collide (ä/a).

**Trade-offs.** Non-Latin frame names get long and are not human-readable. The tooltip on *Panel name* already shows the frame name, so a player never has to derive it by hand. **Existing panels are untouched**, because `rec.frameName` is stamped at create and never re-derived (`modules/Registry.lua:317-319`). The one edge is a pre-v2 record with no stamp, from an imported old SavedVariables file with a non-ASCII name. Its fallback name would differ from what the old build drew. v1→v2 has already stamped every profile on every account that ran a v2 build, so this is accepted.

### T2: Destructive acts say what they destroy and ask first (F-002, F-005)

The *Delete all* popup names the profile scope. The per-panel Delete and Reset in the editor each go through their own `StaticPopupDialogs` confirmation naming the panel, with the same headless fallback shape `doDeleteAll` uses, so the suite can drive the act. The false comment at `modules/Registry.lua:945-946` becomes true.

*Alternative rejected:* an undo buffer. It costs more, and nothing else in the collection has one.

### T3: Harden the panel rows at the trust boundary (F-003, F-004)

A typed number must be finite. `R.Sanitize` / `R.SanitizeField` must cover **every** `C.PANEL_TEMPLATE` field, pinned by a property test, so the coverage cannot silently regress a third time. The editor's color reads fall back to the template, as the renderer's already do. Defense in depth goes in `Util.Clamp` and `freeNumber`, because SavedVariables can still hand them a non-finite value written by an older build.

### T4: Nothing deferred outlives a stand-down (F-006)

A stood-down addon draws nothing, so there is no mid-pull UX hazard to defer. `SetUnlocked` and `SetPanelUnlocked` apply state immediately while `NS.Lifecycle:IsDown()`, and `NS.StandDown` drops any held request. That drop is part of the existing teardown, not a second path (anti-pattern #85, `slash-commands-§7`).

### T5: Small consistency and comment fixes (F-007, F-008)

### Upstream change-set (separate; no entry targets `libs/` or `tests/_kit/` here)

| Finding | Owning repo / file | Fix | Version bump | Consumer step |
|---|---|---|---|---|
| F-009 | `../LibKa0s`, `testkit/framework.lua` (`renderInventory` header text) | State that the README badge counts passes and excludes skips (`testing-§5`), so Totals may exceed it by the number of SKIP cases. Optionally print a "badge = Totals − skips at run time" hint. | `Kit.VERSION` +1 (kit revision 38); ride the next LibKa0s minor release | Re-vendor `tests/_kit/` whole into PanelMaster (and every consumer) in its own commit, regenerating `docs/test-cases.md` in that commit. Never patch `tests/_kit/framework.lua` in place. |

---

## LLD: change-set per finding

### C-01: Hex-encode non-ASCII bytes in `Util.Slugify` (F-001)

- **Files:** `core/Util.lua` (`Util.Slugify`, lines 185-202 plus its header comment); `README.md:96-100` (contract prose) and the *I cannot create a panel* troubleshooting row at `README.md:246`; `docs/data-flow.md:130-131`; `docs/smoke-tests.md` LOC section (expectations change from "finding to file" to "passes").
- **Sketch:**

  ```lua
  -- before
  local s = tostring(name or ""):gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  -- after: a non-ASCII byte is a letter of somebody's alphabet, not punctuation
  local s = tostring(name or "")
    :gsub("[\128-\255]", function(c) return ("%02X"):format(c:byte()) end)
    :gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  ```

  Keep the `"Panel"` fallback, which is still reachable for a name made entirely of ASCII punctuation.
- **Tests (pass count moves):** `tests/test_media.lua` gets `Util.Slugify: non-ASCII letters survive as hex` (Cyrillic, CJK, and an Ä/Ö pair that must differ). `tests/test_registry.lua` gets `Registry:New: two names in one non-Latin script both create, with distinct frame names` and `…an existing panel's stamped frame name is not re-derived`, the second as a characterization case that should already pass. Red under: reverting the `[\128-\255]` gsub.
- **Risk:** Low. Only new panels change. `R:FindByName`'s case folding is still ASCII-only (`modules/Registry.lua:376`), so `übersicht` and `Übersicht` become two legal, distinct panels instead of one refused pair. Record that in `docs/smoke-tests.md` LOC-3 as accepted behavior.
- **Standards:** No rule fixes the slug alphabet. `localization-§4` keeps user data out of `NS.L`, which this respects.

### C-02: Name the profile in the delete-all popup (F-002)

- **Files:** `settings/Slash.lua:81`; `settings/Panel.lua:445` (tooltip); `docs/smoke-tests.md:207` (expected text).
- **After:** `text = "Delete every Ka0s Panel Master panel in this profile? Every character using this profile loses them \226\128\148 this cannot be undone."`. Tooltip: `"Delete every panel in this profile, for every character using it. This cannot be undone."`.
- **Tests:** `tests/test_slash.lua` gets a case asserting the dialog text names the profile and does not contain `character?`. Red under: restoring the old string. The pass count moves by 1.
- **Standards:** `options-ui-§12`'s fixed wording binds only the global reset, and this is the separate *delete all* act that the same section says is "separately-confirmed". Its own principle, that the text warns of what `OnAccept` does, is what shapes this change.

### C-03: Finite numbers only on the panel rows (F-003)

- **Files:** `settings/PanelSchema.lua` (`COERCE.number`); `core/Util.lua` (`Util.Clamp`); `modules/Registry.lua` (`freeNumber`).
- **Sketch:**

  ```lua
  -- core/Util.lua: one predicate, shared
  function Util.IsFinite(n) return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge end
  -- Util.Clamp: treat NaN like a non-number (±inf still clamps to the bound)
  n = tonumber(n)
  if n == nil or n ~= n then n = tonumber(fallback) or lo end
  -- freeNumber
  local function freeNumber(v, t) local n = tonumber(v); return Util.IsFinite(n) and n or t end
  -- COERCE.number
  local n = tonumber(value)
  if not NS.Util.IsFinite(n) then return nil, "expected a finite number" end
  ```

- **Tests (+3):** `Registry:Set refuses nan and 1e999 for x and width`, `Util.Clamp: NaN falls back`, and `Registry:Recover repairs a stored NaN offset`. Red under: removing the `n ~= n` clause, or under COERCE accepting `inf`.
- **Risk:** Low. The `Clamp` change touches every caller, but NaN was never a meaningful input to any of them.
- **Standards:** `savedvariables-§5` (`== nil`, not `or`) is respected, because the new guard tests nil-ness and NaN explicitly.

### C-04: Sanitize covers every template field, with a property test (F-004)

- **Files:** `modules/Registry.lua` (rule lists at :224, :228, :273); `settings/PanelEditorTabs.lua:223`; `settings/PanelEditor.lua:334, :366`.
- **Sketch:**

  ```lua
  local ENUM_FIELDS = { "artFill", "artRotation", "artLayer", "artBlend" }
  local BOOL_FIELDS = { "mouseover", "accentEnabled", "artFlipH", "artFlipV", "artDesaturate" }
  REPAIR.bgColor, REPAIR.borderColor, REPAIR.artColor = color, color, color
  REPAIR.accentColor, REPAIR.accentBorderColor = color, color
  -- editor reads: fall back to the shipped value, as Util.ResolveColor does
  local c = NS.Util.Color(v, C.PANEL_TEMPLATE[field])
  ```

  Better still, derive the enum and color lists from `C.PANEL_FIELD_TYPE` (`"enum"`, `"color"`) so a new field cannot be missed. That is the cleaner shape, and the property test pins it either way.
- **Tests (+2):** `Registry.Sanitize: fills EVERY C.PANEL_TEMPLATE field on an empty record` (iterates the template, excluding `id` and `name`) and `Registry.Sanitize: repairs junk in every enum and boolean field`. Red under: deleting any one rule. This is the test the 2026-08-03 plan (T-2.1) described and never landed.
- **Risk:** Low. Records already valid are unchanged. A stored junk `artBlend` is now repaired to `BLEND` on the next write, which matches what the renderer already drew.
- **Standards:** This follows `architecture-§5` (one repair table behind both the whole-record and per-field writes).

### C-05: Confirm the per-panel Delete and Reset (F-005)

- **Files:** `settings/Slash.lua` (two new `StaticPopupDialogs` entries beside the existing two: `KA0S_PANELMASTER_DELETEPANEL` and `KA0S_PANELMASTER_RESETPANEL`, text with `%s` for the panel name, `OnAccept = function(_, data) … end`); `settings/PanelEditor.lua:154-164` (`pageAction.delete` / `pageAction.reset` go through a confirm helper that falls back to the direct call when `StaticPopup_Show` is absent, the same shape as `doDeleteAll`); `modules/Registry.lua:945-946` (the comment becomes true); `settings/PanelEditorTabs.lua:391-397` (tooltips mention the confirmation).
- **Sketch:**

  ```lua
  local function confirmPanelAct(key, rec, act)
    if type(StaticPopup_Show) ~= "function" then return act(rec) end
    StaticPopup_Show(key, rec.name, nil, { id = rec.id })   -- OnAccept re-resolves by id
  end
  ```

  `OnAccept` resolves `data.id` through `NS.Registry:Get` at accept time, so a panel deleted or switched away from in the meantime is a no-op.
- **Tests (+2):** `PanelEditor: Delete goes through its confirm popup` and the same for `Reset` (assert `mocks.__popupsShown` and that the record still exists before accept). The existing direct-act cases keep passing through the headless fallback.
- **Risk:** Low. The `/pm delete <name>` verb stays unconfirmed: a typed verb with the name spelled out is already deliberate, and §12's confirm-on-the-control logic is about one-click surfaces.
- **Standards:** `options-ui-§12` places the confirmation on the control. This extends that to the two per-panel controls, with no rule against it.

### C-06: No held unlock outlives a stand-down (F-006)

- **Files:** `modules/Unlock.lua` (`U:SetUnlocked`, `U:SetPanelUnlocked`, and a new `U:DropHeld(reason)` that clears `pendingUnlock` and `pendingPanels` and logs one `[Unlock]` line); `core/LifecycleSetup.lua` (`NS.StandDown` calls `NS.Unlock:DropHeld("stood down")`, and the comment at :63-66 is corrected).
- **Sketch:**

  ```lua
  local function mustDefer(on)
    return on and InCombatLockdown and InCombatLockdown()
      and not (NS.Lifecycle and NS.Lifecycle:IsDown())   -- nothing is drawn while down
  end
  ```

- **Tests (+2):** in `tests/test_disabled.lua`, `a combat unlock while disabled is applied, not held` and `a held unlock is dropped on the stand-down edge`. Both assert `U.__hasPending()` is false **and** that `NS.State.unlocked` holds the requested value. That second assertion is what keeps them from being negative-only (`testing-§12`). Red under: removing the `IsDown` clause or the `DropHeld` call.
- **Risk:** Low. It is one teardown path, not two (anti-pattern #85). `ForgetPending` stays for the profile-switch case.
- **Standards:** `slash-commands-§7`. Nothing the addon owns survives the stand-down, and nothing is replayed from before it on the way up (`performance-§6`).

### C-07: `enabled ~= false` in the list and picker (F-007)

- **Files:** `settings/Slash.lua:156`, `settings/PanelEditor.lua:601`. Change `rec.enabled and …` to `rec.enabled ~= false and …`.
- **Tests:** +1 (`/pm panels lists an enabled-nil record as enabled`), optional.
- **Standards:** This applies `savedvariables-§5` and anti-pattern #54 in spirit: test `nil` explicitly.

### C-08: Cite the function, not a line (F-008)

- **File:** `core/Database.lua:86`. Change `(modules/Registry.lua:218-220)` to `(R.Sanitize, modules/Registry.lua)`.

### Test-count and record movement

C-01 through C-07 add about 12 cases (1036 → ~1048 registered, ~1047 passed + 1 skip). `docs/test-cases.md` (regenerated by `lua tests/run.lua --list`) and the README `[tests]` badge move **in the same commit** as each case-adding change (`testing-§5`). The badge counts passes only, not the skip. The complexity watch list should not move. `Util.Slugify` and `COERCE.number` each gain one branch, which the next release regeneration confirms. No `docs/automated-tests/` regeneration is part of this work: that is release-only.

## Standards conformance (per change)

| Change | New deviation? | Rule that shaped it |
|---|---|---|
| C-01 | No | `localization-§4` (names are data, never `NS.L`) |
| C-02 | No | `options-ui-§12` (its warn-what-OnAccept-does principle; the fixed text is not applicable) |
| C-03 | No | `savedvariables-§5` (`== nil` style guards) |
| C-04 | No | `architecture-§5` (one repair table behind the single write seam) |
| C-05 | No | `options-ui-§12` (confirmation on the control) |
| C-06 | No | `slash-commands-§7`, `performance-§6`, anti-pattern #85 (no second teardown path) |
| C-07 | No | `savedvariables-§5` / anti-pattern #54 |
| C-08 | No | none |
| F-009 (upstream) | No | `testing-§5`, `library-stack-§5` / `testing-§1` (vendored kit is never edited in place) |
