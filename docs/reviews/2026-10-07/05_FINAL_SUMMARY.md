# PanelMaster review: final summary (2026-10-07)

*This summary is written ahead of the work, on the assumption that every check in `03_SMOKE_TESTS.md` passed. Correct it against what actually landed. Finding ids are from `01_FINDINGS.md` and change ids from `02_PROPOSED_CHANGES.md`.*

## Headline

This cycle fixed the places where Panel Master could quietly lose or refuse what a player asked for. Players on Russian, Korean and Chinese clients can now name every panel in their own script, because before this only the first such name was accepted. The *Delete all panels* confirmation now says that it empties the shared profile for every character, where before it claimed to affect only the current one. The editor's per-panel **Delete** and **Reset** now ask before acting. Typed panel numbers must be finite, so a stray `1e999` or `nan` can no longer make a panel unrecoverable. The record repair now covers every panel field, closing a gap a review found in August whose fix never landed. Finally, an unlock requested in combat no longer fires hours later after the addon was turned off and on.

## Counts

Critical fixed: 0, High fixed: 2, Medium fixed: 3, Low fixed: 3 (+1 upstream Low, F-009, closed by the re-vendor).

Deferred: none planned. F-007 (C-07) is marked optional in `01_FINDINGS.md`. If it was skipped, record it here with the reason "unreachable without a hand-edited SavedVariables".

## Changes by theme

### T1: The frame-name contract holds for every alphabet

- **What changed:** The frame-name slug keeps non-ASCII letters as hex instead of dropping them, so every distinct name gets its own `PanelMaster_Panel_<slug>`. Panels that already existed keep the frame names they were born with.
- **Why it mattered:** For non-Latin names, a second panel was refused and the README's frame-name promise was false.
- **Finding / change ids:** F-001 / C-01.
- **Files:** `core/Util.lua`, `tests/test_media.lua`, `tests/test_registry.lua`, `README.md`, `docs/data-flow.md`, `docs/smoke-tests.md`, `docs/test-cases.md`.

### T2: Destructive acts say what they destroy and ask first

- **What changed:** The delete-all popup and tooltip name the profile. The per-panel Delete and Reset each confirm through a popup naming the panel.
- **Why it mattered:** The popup understated the blast radius on the shared default profile, and one misclick could destroy a panel or all its settings.
- **Finding / change ids:** F-002, F-005 / C-02, C-05.
- **Files:** `settings/Slash.lua`, `settings/Panel.lua`, `settings/PanelEditor.lua`, `settings/PanelEditorTabs.lua`, `modules/Registry.lua` (comment), `tests/test_slash.lua`, `tests/test_panels_page.lua`, `docs/smoke-tests.md`, `docs/test-cases.md`.

### T3: The panel rows are hardened at the trust boundary

- **What changed:** Panel number fields accept only finite values (`Util.IsFinite`, used by `COERCE.number`, `freeNumber` and `Util.Clamp`). `R.Sanitize` now fills and repairs `accentColor`, `accentBorderColor`, `artBlend` and `artDesaturate`, and a property test asserts that it covers every template field. The editor's color swatches fall back to the shipped color.
- **Why it mattered:** NaN and infinity reached `SetSize` / `SetPoint` and SavedVariables, a NaN offset defeated `/pm recover`, and four fields escaped the repair a comment promised.
- **Finding / change ids:** F-003, F-004 / C-03, C-04.
- **Files:** `core/Util.lua`, `modules/Registry.lua`, `settings/PanelSchema.lua`, `settings/PanelEditor.lua`, `settings/PanelEditorTabs.lua`, `tests/test_util.lua`, `tests/test_registry.lua`, `docs/test-cases.md`.

### T4: Nothing deferred outlives a stand-down

- **What changed:** While the addon is stood down, an unlock applies immediately instead of being held. The stand-down drops any held unlock.
- **Why it mattered:** A held unlock replayed at a combat exit long after the player turned the addon off and on.
- **Finding / change ids:** F-006 / C-06.
- **Files:** `modules/Unlock.lua`, `core/LifecycleSetup.lua`, `tests/test_disabled.lua`, `docs/test-cases.md`.

### T5: Consistency and comments

- **What changed:** The panel list and picker read an absent `enabled` as enabled. A rotted line citation now names the function instead.
- **Finding / change ids:** F-007, F-008 / C-07, C-08.
- **Files:** `settings/Slash.lua`, `settings/PanelEditor.lua`, `core/Database.lua`.

### Upstream

- **What changed:** LibKa0s's generated inventory header now says that the README badge counts passes and excludes skips. PanelMaster re-vendored the kit.
- **Finding / change ids:** F-009 / LK-RV-01, PM-RV-09.
- **Files:** `tests/_kit/` (re-vendored whole), `CLAUDE.md` provenance line, `docs/test-cases.md`.

## API / behavior changes

- **Frame names (public contract):** new panels with non-ASCII names get hex-encoded slugs (`Чат` → `PanelMaster_Panel_D0A7D0B0D182`). Existing panels are unchanged. ASCII names are unchanged.
- **CLI:** `/pm panel <name> <numberField> nan|1e999` is now refused with `expected a finite number`.
- **UI:** the per-panel Delete and Reset show a confirmation popup. The delete-all popup and the Panels ▸ Defaults tooltip have new wording.
- **No new slash verbs, no new settings keys and no schema rows added or removed.** No locale keys were added.

## Saved-variable / migration notes

There is no schema bump (`NS.SCHEMA_VERSION` stays 2). Stored junk in `artBlend` / `artDesaturate`, and missing `accentColor` / `accentBorderColor`, are repaired on the record's next write or profile switch, as every other field already was. No player action is required.

## Deprecated-API migrations

None.

## Test and complexity movement

- Pass count: 1035 passed + 1 skip (1036 registered) → about 1047 passed + 1 skip (about 1048 registered). Fill in the exact figure from the final `lua tests/run.lua`.
- `docs/test-cases.md` and the README `[tests]` badge moved in the same commit as each case-adding task. The badge shows passes over passes, with skips excluded (`testing-§5`).
- Complexity: `Util.Slugify` and `COERCE.number` each gain one branch, and no watch-list entry is expected to cross CCN 15. That is to be confirmed by the next release's `run-automated-tests.sh` regeneration, not here.

## Known follow-ups

- **Name case folding is still ASCII-only** (`R:FindByName`). `übersicht` and `Übersicht` are now two legal panels rather than a refused pair. This is accepted and recorded in `docs/smoke-tests.md` LOC-3. A UTF-8-aware fold would need a case table per script, which is out of proportion.
- **`/pm delete <name>` stays unconfirmed.** It is a typed verb naming its target, and the confirmation is for one-click controls.
- **No login-time sanitize sweep.** Records are repaired on their next write, by design (`modules/Registry.lua` header). The read paths now fall back to the template, so an unrepaired record still displays correctly.

## Verification evidence

- `03_SMOKE_TESTS.md` sign-off table: to be completed by the owner.
- Commit range: `PM-RV-01` … `PM-RV-08` on `feat/2026-10-07-review-audit-remediation`, plus `LK-RV-01` in LibKa0s and the `PM-RV-09` re-vendor.

## Suggested commit message / PR description

```
PanelMaster review 2026-10-07: frame names for every alphabet, honest destructive prompts, finite panel numbers

- F-001: non-ASCII letters survive the frame-name slug as hex, so a second Cyrillic/CJK panel is no
  longer refused; existing frame names are untouched (C-01)
- F-002: the delete-all popup names the profile it empties (C-02)
- F-003: panel number fields refuse NaN and infinity; /pm recover repairs a stored NaN (C-03)
- F-004: Sanitize covers every template field, pinned by a property test (C-04; the 2026-08-03 fix
  that never landed)
- F-005: per-panel Delete and Reset confirm first (C-05)
- F-006: no held unlock outlives a stand-down (C-06)
- F-007/F-008: enabled-nil reads as enabled in the list; a rotted citation names the function (C-07/C-08)
- F-009 (upstream): re-vendor LibKa0s for the inventory-header wording fix

Gate: lua tests/run.lua green, luacheck 0/0; docs/test-cases.md and the [tests] badge moved with each change.
No schema bump, no version bump.
```
