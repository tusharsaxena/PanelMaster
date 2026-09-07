# Proposed changes — Ka0s Panel Master, 2026-09-07

Design document for the findings in [`01_FINDINGS.md`](01_FINDINGS.md). HLD first (themes and the
alternatives rejected), then LLD (per-change, per-file).

**Standards cross-check: performed.** Standard resolved at **v2.38.0 (2026-09-02)**, fetched from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master/standards/STANDARDS.md` and
the section files its Sections list links. Every change below is confirmed not to introduce a new
deviation; where a rule shaped or vetoed an option, it is cited as `filename-§N`.

**Nothing in this document targets a path under `libs/` or `tests/_kit/`.** The one upstream item has
its own section and its remediation lands in the LibKa0s repo.

---

## HLD — themes

### Theme A — stop editing shared singletons; scope the fixup to the widgets this addon builds
**Covers:** F-001.

`core/LSMPatch.lua` fixes a real cosmetic problem (a 42px hole beside a closed border dropdown) with
a mechanism whose blast radius is the whole session. `AceGUI-3.0` is a LibStub singleton, so
`AceGUI:RegisterWidgetType` writes into one table every addon shares; five Ka0s addons ship the same
file, and each `PLAYER_LOGIN` wrapper wraps the previous one.

The change keeps the visual outcome and drops the reach: PanelMaster builds its own `LSM30_Border`
widgets in `settings/PanelEditor.lua`, so the same three operations applied to the widget instance
at its creation site produce an identical panel and touch nobody else's.

**Alternatives considered.**

- *Guard the wrapper so it only fires for widgets parented into a PanelMaster canvas.* Rejected: the
  constructor runs before the widget is parented, so the guard has nothing to read. It would also
  leave the registry slot owned by this addon, which is the part that is wrong.
- *Move the fixup into `libs/AceGUI-3.0-SharedMediaWidgets/` and fix it at source.* **Forbidden.**
  Vendored third-party code is read-only — the next re-vendor reverts it and the reversion looks like
  a regression with no commit behind it. `library-stack` (no lib forks); the file's own header
  already reaches the same conclusion (`core/LSMPatch.lua:23-24`).
- *Push the fixup into `LibKa0s-Options-1.0` so every consumer gets it.* Reasonable, and the right
  destination **if** the collection decides the look is canonical — but it must be an **additive,
  opt-in** helper on the widget makers, applied per widget, not another registry write. Noted as a
  follow-up rather than done here: it needs the 2+-consumers-same-semantics test of
  `library-stack`'s promotion bars, and four of the five copies would have to be retired in the same
  cycle. This change unblocks that by making the per-widget form exist.
- *Delete the fixup and live with the gap.* Rejected: it is a genuine layout defect in this addon's
  own panel, and `options-ui` is explicit that the settings surface is held to a visual standard.

### Theme B — make the two session-state sweeps one sweep
**Covers:** F-002.

`R:DeleteAll` and `dropSessionIDs` do the same job for the same reason and disagree by one line. The
fix is not to add the missing line twice over but to have one private sweep both call, so the class
of bug closes rather than the instance.

**Alternative considered.** *Just add `NS.State.preview = false` to `R:DeleteAll`.* Rejected on the
same grounds the repo already applies elsewhere (`settings/Schema.lua`'s single write seam,
`modules/Registry.lua`'s single fire point): two copies of a rule is two things that can be wrong,
and this pair has already been wrong once.

### Theme C — parse what the user meant, and pin it with a case that can go red
**Covers:** F-003, F-004.

Two small correctness items that share a shape: the code does something defensible, the comment
explains it, and the behaviour is still not what a user or a reader would predict. Both fixes are
one-liners; the value is in the tests, which in both cases today **cannot distinguish** the current
behaviour from the intended one.

**Alternative considered for F-003.** *Reject a 4-component byte colour outright and tell the user to
use fractions.* Rejected: `slash-commands-§5` wants a parse failure to be reported, but this input is
not a failure — it is unambiguous under the proposed rule, and refusing it would break the
byte-paste workflow the current comment is defending.

### Theme D — structural hygiene ahead of the cap
**Covers:** F-005, F-006, F-007.

Three items with no user-visible behaviour change: peel the file that is 150 lines from a MUST,
stop a ticker that has nothing to tick, and correct a rationale comment that describes a deleted
implementation.

### Theme E — evidence upkeep
**Covers:** F-008, F-009, F-010.

No code changes. F-008 is a release-time regeneration, F-009 is a note, F-010 is the audit's to
count. Recorded here so the execution plan can carry them without anyone treating them as tasks that
edit source.

---

## Upstream change-set (lands in another repo — **not** in this one)

### U-01 — normalise two LibKa0s source files to the repo's own line-ending pin
**Covers:** F-011.

| | |
|---|---|
| Owning repo | **LibKa0s** (`../LibKa0s`) |
| Files within the library | `LibKa0s/DebugLog.lua`, `LibKa0s/Pool.lua` |
| Fix | In the LibKa0s repo, re-normalise the working tree against its own `.gitattributes` (`git add --renormalize .`) so every source file's checkout representation matches the pin, as `Core.lua` and the rest already do |
| Minor bump | **None.** No source line changes, so `LibKa0s-DebugLog-1.0` stays at minor 12 and `LibKa0s-Pool-1.0` stays where it is. Bumping a minor for a checkout-representation change would falsely signal a behaviour change to every consumer's floor check |
| Re-vendor commit here | **Not required by this fix.** The vendored bytes in `libs/LibKa0s/` are already correct. The correction rides the next scheduled re-vendor, whenever that happens for other reasons |
| Explicitly not | A local edit under `libs/LibKa0s/`. `library-stack`'s whole-folder rule and anti-pattern #48 both forbid it, and the next copy would revert it silently |

---

## LLD — change-set

### C-01 — scope the LSM30_Border fixup to this addon's own widgets
**Findings:** F-001 · **Theme:** A · **Risk:** medium (touches the settings panel's dropdowns)

**Files:** `core/LSMPatch.lua` (becomes a helper, no registry write), `settings/PanelEditor.lua`
(call site), `PanelMaster.toc` (annotation only if the file's position stops being load-bearing),
`tests/test_panel.lua` or a new case in the PanelEditor coverage.

Before — `core/LSMPatch.lua:30-66`, abbreviated:

```lua
local hookFrame = CreateFrame("Frame")
hookFrame:RegisterEvent("PLAYER_LOGIN")
hookFrame:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
  ...
  AceGUI:RegisterWidgetType("LSM30_Border", function()
    local widget = current()
    ... hide displayButton, re-anchor label and DLeft ...
    return widget
  end, currentVer + 1)
end)
```

After — the same three operations, applied to one widget, by whoever built it:

```lua
-- core/LSMPatch.lua — no event, no registry write. A function the creator calls.
--
-- WHY THIS IS NOT A RegisterWidgetType WRAPPER ANY MORE: AceGUI-3.0 is a LibStub
-- singleton, so its WidgetRegistry is one table every addon in the session shares.
-- Re-registering LSM30_Border applied this addon's layout preference to every other
-- addon's border dropdown, unattributably, and five Ka0s addons shipped the same
-- wrapper — each one wrapping the last. The fixup is this addon's, so it is applied
-- to this addon's widgets.
function NS.FixBorderDropdown(widget)
  local f = widget and widget.frame
  if not (f and f.displayButton) then return widget end
  f.displayButton:Hide()
  if f.label then ... end   -- unchanged from :49-53
  if f.DLeft then ... end   -- unchanged from :59-62
  return widget
end
```

and at each `LSM30_Border` creation in `settings/PanelEditor.lua`:

```lua
local dd = NS.FixBorderDropdown(AceGUI:Create("LSM30_Border"))
```

**Notes.**
- The `PLAYER_LOGIN` frame and its `UnregisterAllEvents` go away entirely; the timing constraint the
  header describes (`core/LSMPatch.lua:11-14`) existed only to win a registry version race that no
  longer happens.
- Keep the `DLeft` offset comment (`:54-58`) verbatim — it records *why* the magic `-17, -21` is
  what it is, and losing it in a move is the failure the complexity guidance names.
- The header's "lives in core/, not libs/" paragraph stays; it is still the right answer for a
  different reason.

**Standards conformance.** `library-stack` (no forks of vendored code; a missing capability is added
upstream, additively, not patched locally) — this change moves *away* from touching shared library
state, so it strictly reduces deviation. `layout` keeps the file in `core/`. No new deviation. The
rejected option (editing `libs/AceGUI-3.0-SharedMediaWidgets/prototypes.lua`) breaks
`library-stack`'s read-only vendoring rule and anti-pattern #48.

**Regression pressure on the suite.** Adds at least one case (the helper hides `displayButton` and
re-anchors, and returns the widget unchanged when there is none) and should **delete** any case that
asserts on `AceGUI.WidgetRegistry`. Net pass count moves: `docs/test-cases.md` and the README
`[tests]` badge must move **in the same commit** (`testing-§7`).

### C-02 — one session-state sweep, called from both places
**Findings:** F-002 · **Theme:** B · **Risk:** low

**File:** `modules/Registry.lua`.

`dropSessionIDs` (`:559-566`) and `R:DeleteAll` (`:577-593`) both clear `unlockedPanels` and
`previewIDs`; only the first clears `NS.State.preview` (`:561`). Extract the common body:

```lua
-- Everything in NS.State that is keyed on a panel id, plus the preview flag those ids belong to.
-- ONE function, because the two callers below have already drifted by exactly one line: R:DeleteAll
-- cleared the ids and left `preview` true, which is the failure dropSessionIDs' own comment names.
local function clearIdState()
  for id in pairs(NS.State.unlockedPanels) do NS.State.unlockedPanels[id] = nil end
  for i = #NS.State.previewIDs, 1, -1 do NS.State.previewIDs[i] = nil end
  NS.State.preview = false
end
```

`dropSessionIDs` calls it and keeps its two extra steps (`Unlock:ForgetPending`,
`PanelEditor:ForgetSelection`); `R:DeleteAll` calls it in place of `:588-589`.

**Risk note.** `R:DeleteAll` gains a side effect it did not have: it now turns the preview flag off.
That is the intent — with every panel deleted there are, by construction, no preview placeholders
left — but it does mean the Test-mode checkbox now unticks on delete-all. Cover it as such in
`03_SMOKE_TESTS.md`.

**Standards conformance.** No rule constrains this; it is the repo's own single-implementation
convention (`architecture-§4`'s single-sender reasoning applied to state rather than to messages).
No new deviation.

**Regression pressure.** One added case in `tests/test_registry.lua`: *"DeleteAll clears the preview
flag, not only the ids"*, red under reverting the extraction. Pass count +1.

### C-03 — read a shorthand alpha as fractional under a byte-scale colour
**Findings:** F-003 · **Theme:** C · **Risk:** low

**File:** `core/Util.lua:104-106`.

```lua
-- before
(nums[4] == nil and 1 or nums[4] / scale),

-- after
-- The fourth component is decided SEPARATELY from the first three, because the two readings only
-- collide at one value and the collision is one-sided: `255,0,0,255` is unambiguously a byte alpha,
-- `255,0,0,1` is unambiguously the "fully opaque" a human types, and under the old blanket divide
-- the second one came out at 0.004 -- an invisible panel with no error to explain it.
(nums[4] == nil and 1) or (nums[4] > 1 and nums[4] / 255) or nums[4],
```

`Util.FormatColor` always emits fractions (`core/Util.lua:110-113`), so the documented round-trip
`FormatColor(ParseColor(s))` is untouched.

**Standards conformance.** `slash-commands-§5` (a refused value must say why) is satisfied — this
input is now accepted rather than mis-read, and genuinely unparseable input still returns `nil`. No
new deviation.

**Regression pressure.** Extend `tests/test_util.lua`'s ParseColor cases with `255,0,0,1` → alpha 1
and `255,0,0,255` → alpha 1, plus `0.5,0,0,0.5` unchanged. Pass count moves by the number of new
`test(` registrations.

### C-04 — `NS.InitSummary` reads the version seam
**Findings:** F-004 · **Theme:** C · **Risk:** low

**Files:** `core/Database.lua:141`, `tests/test_database.lua:160`, `tests/wow_mock.lua`.

```lua
-- core/Database.lua:140-141, before
return ("%s v%s, schema v%s, profile '%s', %s panels"):format(
  tostring(NS.name), tostring(NS.version), tostring(schema), tostring(profile), tostring(panels))

-- after: through the seam core/EnvSetup.lua:5-6 already promises this line uses.
-- NS.Version() prefers the packaged TOC's ## Version and falls back to NS.version, so a build whose
-- TOC has moved ahead of core/Namespace.lua:7 no longer reports the stale constant in the one line
-- a user pastes into a bug report.
  tostring(NS.name), tostring(NS.Version()), ...
```

**The test change is the load-bearing half.** `tests/test_database.lua:160` currently asserts
`s:find("v" .. NS.version)`, and the mock's TOC version equals `NS.version`, so the case passes under
both implementations — it cannot go red. Point the mock's `## Version` at a **different** string
(e.g. `"9.9.9"`, which `tests/test_envsetup.lua:41-46` already exercises) for the duration of the
case and assert the summary carries that, not the constant.

**Standards conformance.** `library-stack-§7` (adopted majors are reached through their seam, not
around them) and `testing-§12` (a case must be able to fail). No new deviation.

**Regression pressure.** No new case; one existing case becomes falsifiable. Pass count unchanged —
so `docs/test-cases.md` does not move, and that is correct.

### C-05 — peel `settings/PanelEditor.lua` along its section boundaries
**Findings:** F-005 · **Theme:** D · **Risk:** medium (large mechanical move) · **Sequence: last**

**Files:** `settings/PanelEditor.lua` → itself plus 2–3 siblings under `settings/`; `PanelMaster.toc`;
`tests/run.lua` needs **no** change (the load list is TOC-derived, `tests/run.lua:34`).

Split by the editor's own visual sections — geometry/placement, colour and border, artwork — each a
sibling file publishing onto `NS.PanelEditor`, with `settings/PanelEditor.lua` retained as the page
builder that calls them. Every new TOC line carries the **load-bearing / conventional** annotation
the file listing already uses throughout (`toc-file`).

**Explicitly not:** extracting a `buildRest`/`part2` helper (anti-pattern #52), and not building any
dispatch or defaults table inside a function that already runs per render.

**Standards conformance.** `layout-§1` (1500 LOC cap; 1000–1500 on notice) is the motivation;
`layout`'s folder rules keep the new files under `settings/`; `toc-file` governs the annotations.
Today's `lizard` run finds **zero** functions above CCN 15, so nothing here is justified as a
complexity fix — it is a file-size and cohesion split, and the write-up should say so rather than
claim a CCN improvement it will not produce.

**Note for the next release.** The next `/wow-addon:bump-version` regeneration should show
`settings/PanelEditor.lua` dropping out of the 1000–1500 band with the total NLOC essentially flat.
That is a confirmation to read afterwards, **not** a tool to run as part of this work.

### C-06 — unhook the mouseover `OnUpdate` when nothing is tracked
**Findings:** F-006 · **Theme:** D · **Risk:** low

**File:** `modules/Canvas.lua:642-665` (helper at `:642-653`, `SetMouseoverTracked` at `:658-665`).

```lua
-- Canvas.SetMouseoverTracked, after
function Canvas.SetMouseoverTracked(id, frame, tracked)
  if tracked then
    mouseoverPanels[id] = frame
    ensureMouseoverDriver()
  else
    mouseoverPanels[id] = nil
    -- The frame is kept -- creating it once is right -- but its script is not. An OnUpdate with an
    -- empty tracked set still runs every frame to accumulate a delta it will do nothing with, and
    -- that outlives the panel that installed it for the whole session.
    if mouseoverDriver and next(mouseoverPanels) == nil then
      mouseoverDriver:SetScript("OnUpdate", nil)
    end
  end
end
```

`ensureMouseoverDriver` must re-install the script on a frame it already created — restructure it so
the closure is built once at file scope and `ensureMouseoverDriver` only ever assigns it.

**Also.** Change `elapsed = 0` (`:649`) to `elapsed = elapsed - MOUSEOVER_INTERVAL` so the tick does
not drift below 10Hz on a low frame rate, or add a comment saying the drift is accepted.

**Standards conformance.** `performance-§2`'s dormant-work principle. The addon has no perf harness
by ratified decision, so **no number is claimed for this change** — the smoke-test check is
observational (`03_SMOKE_TESTS.md`), and this document does not assert a saving it cannot cite.

**Regression pressure.** One case in `tests/test_canvas.lua`: tracking then untracking the last panel
leaves `Canvas.__mouseoverPanels` empty and the driver scriptless. The headless mock has no real
`OnUpdate` (`modules/Canvas.lua:640` is the existing test seam), so assert on the script slot the
mock records. Pass count +1.

### C-07 — correct the `skipRestoreAll` rationale
**Findings:** F-007 · **Theme:** D · **Risk:** none (comment only)

**File:** `settings/OptionsSetup.lua:190-195`. Replace the session-only-rows argument with what is
actually true today:

> `skipRestoreAll / afterRestoreAll` — this addon does not use `O.RestoreAllDefaults` at all. Its
> global reset is a **profile** reset (`options-ui-§12`): `Sl:DoResetAll` calls `db:ResetProfile()`
> (`settings/Slash.lua:31-35`) and walks no rows. The library's version walks `allRows` calling
> `applyDefault`, which is a different act with a different blast radius, not a cheaper spelling of
> this one. Session-only state is cleared on the way out by `OnProfileReset` →
> `Registry:ReloadProfile` → `dropSessionIDs` (`modules/Registry.lua:559-566`); the global unlock
> flag and the console are deliberately left alone.

**Standards conformance.** `options-ui-§12` is the rule being cited correctly for the first time. No
new deviation.

### C-08 — evidence upkeep (no code)
**Findings:** F-008, F-009, F-010 · **Theme:** E

- **F-008:** `docs/automated-tests/RESULTS.md` is regenerated by `/wow-addon:bump-version` at the
  next release. **Do not** hand-edit it and **do not** run the recorder as part of this work —
  `automated-tests-§3` puts its checkpoint at release, and a hand-edited report is worse than a stale
  one because it reads as measured.
- **F-009:** no action. The `performance-§1` decline is ratified in `docs/performance.md` and carries
  its `## Documented deviations` row; this review does not reopen it. If C-06's driver ever grows
  beyond a `MouseIsOver` per tracked panel, that is the trigger to revisit.
- **F-010:** `/wow-addon:standards-audit` owns the sweep and the count (`line-endings-§2`). The
  mechanical correction is `git add --renormalize .` in this repo, run as its own commit by whoever
  owns that audit — **not** folded into any change above, because it rewrites the checkout
  representation of files those changes also touch and would bury a real diff.

---

## Change → finding map

| Change | Findings | Files | Behaviour change? |
|---|---|---|---|
| C-01 | F-001 | `core/LSMPatch.lua`, `settings/PanelEditor.lua`, tests | Yes — other addons' dropdowns stop being altered |
| C-02 | F-002 | `modules/Registry.lua`, tests | Yes — delete-all unticks Test mode |
| C-03 | F-003 | `core/Util.lua`, tests | Yes — `r,g,b,1` in bytes is now opaque |
| C-04 | F-004 | `core/Database.lua`, tests, `tests/wow_mock.lua` | No today; correct under a version bump |
| C-05 | F-005 | `settings/PanelEditor.lua` + siblings, `PanelMaster.toc` | No |
| C-06 | F-006 | `modules/Canvas.lua`, tests | No user-visible change |
| C-07 | F-007 | `settings/OptionsSetup.lua` | No (comment) |
| C-08 | F-008, F-009, F-010 | — | No |
| U-01 | F-011 | **LibKa0s repo only** | No |
