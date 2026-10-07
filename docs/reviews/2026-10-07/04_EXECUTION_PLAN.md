# PanelMaster review: execution plan (2026-10-07)

All work goes on branch `feat/2026-10-07-review-audit-remediation` (already checked out). Each task's commit subject starts with its task id. The commit gate for every task is `lua tests/run.lua` green, `luacheck .` at 0/0, and `docs/test-cases.md` plus the README `[tests]` badge regenerated **in the same commit** whenever the case count moves (`testing-§5`; the badge counts passes, not skips). Nothing is pushed, merged, tagged or version-bumped without the owner's go-ahead.

## Milestones

### M1: Correctness at the write seam (F-001, F-003, F-004)

**Done when:** C-01, C-03 and C-04 have landed, with their new cases green, and the scratch probes `probe.lua`, `probe2.lua` and `probe3.lua` (described in `01_FINDINGS.md`) show the fixed behavior: finite-only values, every template field filled, and distinct non-Latin frame names.

| Task | Role | Implements | Files |
|---|---|---|---|
| PM-RV-01 | lua-refactorer + test-author | C-04 / F-004 | `modules/Registry.lua` (rule lists :224, :228, :273), `settings/PanelEditorTabs.lua:223`, `settings/PanelEditor.lua:334, :366`, `tests/test_registry.lua`, `docs/test-cases.md`, `README.md` (badge) |
| PM-RV-02 | lua-refactorer + test-author | C-03 / F-003 | `core/Util.lua` (`Util.IsFinite`, `Util.Clamp`), `modules/Registry.lua` (`freeNumber`), `settings/PanelSchema.lua` (`COERCE.number`), `tests/test_util.lua`, `tests/test_registry.lua`, `docs/test-cases.md`, `README.md` (badge) |
| PM-RV-03 | lua-refactorer + test-author + docs | C-01 / F-001 | `core/Util.lua` (`Util.Slugify`), `tests/test_media.lua`, `tests/test_registry.lua`, `README.md:96-100, :246` (+ badge), `docs/data-flow.md:130-131`, `docs/smoke-tests.md` (LOC section), `docs/test-cases.md` |

### M2: Destructive and deferred UX (F-002, F-005, F-006)

**Done when:** C-02, C-05 and C-06 have landed with their cases green, and `tests/test_disabled.lua`'s survivor-set and registration assertions are unchanged.

| Task | Role | Implements | Files |
|---|---|---|---|
| PM-RV-04 | ux-cleanup + test-author | C-02 / F-002 | `settings/Slash.lua:81`, `settings/Panel.lua:445`, `tests/test_slash.lua`, `docs/smoke-tests.md:207`, `docs/test-cases.md`, `README.md` (badge) |
| PM-RV-05 | ux-cleanup + test-author | C-05 / F-005 | `settings/Slash.lua` (two new `StaticPopupDialogs`), `settings/PanelEditor.lua:154-164`, `settings/PanelEditorTabs.lua:391-397`, `modules/Registry.lua:945-946`, `tests/test_panels_page.lua`, `docs/test-cases.md`, `README.md` (badge) |
| PM-RV-06 | lua-refactorer + test-author | C-06 / F-006 | `modules/Unlock.lua`, `core/LifecycleSetup.lua` (`NS.StandDown`, comment :63-66), `tests/test_disabled.lua`, `docs/test-cases.md`, `README.md` (badge) |

### M3: Consistency and comments (F-007, F-008)

**Done when:** both changes have landed and the gate is green.

| Task | Role | Implements | Files |
|---|---|---|---|
| PM-RV-07 | ux-cleanup | C-07 / F-007 | `settings/Slash.lua:156`, `settings/PanelEditor.lua:601`, `tests/test_slash.lua` (optional case), `docs/test-cases.md`, `README.md` (badge) |
| PM-RV-08 | docs | C-08 / F-008 | `core/Database.lua:86` |

### M4: Upstream (F-009), a cross-repo handoff

**Done when:** LibKa0s has released the `testkit/framework.lua` wording fix (kit revision 38 or later), **and** PanelMaster carries a **re-vendor commit** of the whole `tests/_kit/` folder (plus `libs/LibKa0s/` if the release moved it), its `CLAUDE.md` provenance line updated, and `docs/test-cases.md` regenerated in that same commit. The work is never folded into an M1 to M3 task, and `tests/_kit/` is never edited in place.

| Task | Role | Implements | Repo / files |
|---|---|---|---|
| LK-RV-01 | library-maintainer | F-009 | `../LibKa0s`: `testkit/framework.lua` (`renderInventory`), `Kit.VERSION` +1, CHANGELOG |
| PM-RV-09 | revendor | F-009 consumer step | PanelMaster: `tests/_kit/` (whole-folder copy), `CLAUDE.md` provenance line, `docs/test-cases.md` (via `/dev-copilot:wow-revendor-libka0s`) |

## Critical path and concurrency map

- **`modules/Registry.lua`** is touched by PM-RV-01, PM-RV-02 and PM-RV-05. These **must serialize**, in the order 01 → 02 → 05.
- **`core/Util.lua`** is touched by PM-RV-02 and PM-RV-03. **Serialize** 02 → 03, because `IsFinite` lands first and Slugify's diff stays separate.
- **`settings/Slash.lua`** is touched by PM-RV-04, PM-RV-05 and PM-RV-07. **Serialize** 04 → 05 → 07.
- **`settings/PanelEditor.lua`** is touched by PM-RV-01, PM-RV-05 and PM-RV-07. **Serialize** 01 → 05 → 07.
- **`settings/PanelEditorTabs.lua`** is touched by PM-RV-01 and PM-RV-05. **Serialize.**
- **`tests/test_registry.lua`** is touched by PM-RV-01, PM-RV-02 and PM-RV-03. **Serialize.**
- **`docs/test-cases.md` and the `README.md` badge** move in nearly every task, so every case-adding task serializes on them. In practice the whole M1 to M3 chain runs as **one serial lane**: 01 → 02 → 03 → 04 → 05 → 06 → 07 → 08.
- **Parallelizable:** PM-RV-06 shares no source file with 01 to 05 (it touches `Unlock.lua`, `LifecycleSetup.lua` and `test_disabled.lua`), so it can be developed in parallel and rebased onto the inventory and badge at commit time. PM-RV-08 is a comment-only change that can go anywhere. LK-RV-01 runs in `../LibKa0s` fully in parallel with M1 to M3. PM-RV-09 waits for both LK-RV-01 and M3.

## Checkpoints

1. **After M1:** the owner re-runs `docs/smoke-tests.md` LOC-1 to LOC-6 and C-03 NUM-1 to NUM-3 in the client. In particular, NUM-3 is run **before** PM-RV-02 to record what the client writes for a non-finite number. This resolves F-003's "unverified".
2. **After M2:** the owner runs C-02, C-05 and C-06 in the client, plus the stand-down regression lines. Confirm that `tests/test_disabled.lua` "Disabled 3" (survivor set) still lists exactly three survivors.
3. **Before M4's re-vendor:** confirm `../LibKa0s` is on the new tag and clean. Run the vendor gate (`docs/testing.md` › *The vendor gate*): all four diffs empty against the claimed tag after the copy.
4. **Before any push:** full gate, then `/dev-copilot:execution-status`. The owner authorizes the push and merge.

## Incremental commit strategy

One commit per task, with the subject starting with its id:

- `PM-RV-01: Sanitize fills and repairs every template field; property test (F-004)`
- `PM-RV-02: panel number rows accept finite values only (F-003)`
- `PM-RV-03: non-ASCII letters survive the frame-name slug as hex (F-001)`
- `PM-RV-04: delete-all popup names the profile it empties (F-002)`
- `PM-RV-05: confirm the per-panel Delete and Reset (F-005)`
- `PM-RV-06: no held unlock outlives a stand-down (F-006)`
- `PM-RV-07: list and picker read enabled-nil as enabled (F-007)`
- `PM-RV-08: cite R.Sanitize, not a line (F-008)`
- `LK-RV-01: inventory header says the badge excludes skips (testing-§5)` (in LibKa0s)
- `PM-RV-09: re-vendor LibKa0s <tag> (kit <rev>)` (in PanelMaster)

Each message ends with the session's attribution trailers.
