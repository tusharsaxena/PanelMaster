# PanelMaster — full-scope review, 2026-09-23

**Verdict: blocking issues.** Three High findings sit on normal-install paths: a disabled addon still draws and arms drag on every unlocked panel, the *Only in combat* / *Only out of combat* visibility setting never changes state when a fight starts, and `/pm recover` measures stored offsets against the wrong unit whenever a panel is scaled. Every suite is green. Two of these bugs sit on paths that `docs/test-cases.md` claims to cover, which is the more serious signal.

Reviewed at `afb30d7` (branch `feat/2026-09-23-review-audit-remediation`), addon version 1.1.1, LibKa0s v1.55.0 vendored.
Standards cross-check: **performed**, against Ka0s WoW Addon Standard **v2.64.0 (2026-09-23)**. The index and all 27 section files were fetched verbatim with `curl`.

## Measurement run

`ka0s-bounded` is not on `PATH` in this shell, but it exists at `~/.claude/wow-addon/bin/ka0s-bounded`, so every run below went through it by full path. No run exited 124 or 137. All output went to a scratch path outside the repo, and no committed artifact was modified.

| Suite | Result | Command (from repo root) |
|---|---|---|
| luacheck | **pass**: 0 warnings / 0 errors in 60 files | `ka0s-bounded luacheck .` |
| Headless suite | **pass**: 884 passed, 0 failed, 0 skipped, 884 total | `ka0s-bounded lua5.1 tests/run.lua` |
| Fresh `--list` inventory | **generated**: 884 cases. Byte-identical to committed `docs/test-cases.md` after CR-normalisation (`diff` empty) | `ka0s-bounded lua5.1 tests/run.lua --list > <scratch>/test-cases.md` |
| Offline perf runner | **skipped**: there is no `tests/perf.lua`. That is the ratified `performance-§1` deviation (`docs/ARCHITECTURE.md` ▸ Documented deviations), so there is nothing to run | n/a |
| lizard | **pass**: 0 warnings, max CCN 15 (`Compat.AddOnFolders` `core/Compat.lua@27-45`, `R.ApplyArtSize` `modules/Registry.lua@607-635`), 1687 functions, 14325 NLOC | `ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" . > <scratch>/complexity.txt` |
| `make test` | **skipped**: no root `Makefile` | n/a |
| Vendor sync | **pass**: both diffs are empty, and `../LibKa0s` HEAD's payload equals tag `v1.55.0` (`git diff --stat v1.55.0 HEAD -- LibKa0s testkit` is empty) | `diff -r libs/LibKa0s ../LibKa0s/LibKa0s`; `diff -r tests/_kit ../LibKa0s/testkit` |
| Cross-addon, class 1 (slash tokens) | **clean**: 20 roots across 10 addons, `uniq -d` empty, zero raw `SLASH_*` in loaded source. PanelMaster owns `pm` and `panelmaster` | the four commands in the review brief, run from `GIT/` over the **ten**-addon roster (the nine plus AuraMaster), TOC-derived load list |
| Cross-addon, class 2 (LibKa0s minors) | **clean**: one line, shared by all ten: `Bus:1 Compat:1 Core:7 DebugLog:12 Env:1 Item:1 Launcher:1 Lifecycle:1 Media:3 Options:23 Perf:12 Pool:3 Schema:1 Slash:14 Widgets:9` | same |
| Cross-addon, class 3 (payload bytes) | **clean**: `diff -rq PanelMaster/libs/LibKa0s <each>/libs/LibKa0s` is empty for all ten. PanelMaster was the reference | same |
| Cross-addon, class 4 (`## Interface:`) | **clean**: one value, `120100`, in all ten | same |

**The cross-addon results moved against the 2026-09-07 baseline, and every move is uniform, so none of them is a finding:**
- The roster went from 9 addons to 10, so 18 roots became 20 (`am`/`auramaster` added).
- The Interface value moved `120007` → `120100`, in all ten.
- Five majors were added (Bus, Compat, Launcher, Lifecycle, Schema, each at minor 1) and three minors moved (Options 14→23, Slash 7→14, Perf 7→12). The other five are unchanged. All of it is identical in all ten.
- The PrettyChat CR straggler recorded in the baseline no longer appears.

**Committed artifacts that disagree with today's run:**
- `docs/automated-tests/RESULTS.md` is the run of `20260916-184500`: 834 tests, 1624 functions, 13887 NLOC, SHA `3c4005a`, addon 1.1.0. Today's run has 884 tests, 1687 functions and 14325 NLOC. The file is **stale by date, not wrong**, and it is regenerated at release. **Watch-list drift: none.**
  - No function is warned in either run.
  - The layout-§1 band has the same four files at the same LOC: `modules/Artwork.lua` 1188, `settings/PanelEditor.lua` 1476, `tests/test_artwork.lua` 1356, `tests/test_panel.lua` 1353.
  - The two CCN-15 functions are unchanged.
- `docs/test-cases.md` and the README `Tests-884/884` badge **agree** with the fresh run.
- `docs/performance.md` has no offline scenarios to contradict.

Census scope for the LOC line above: the default scope, `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | tr '\n' '\0' | xargs -0 wc -l | awk '$2!="total" && $1>1000'`. It covers tracked authored Lua including `tests/`, and excludes the vendored `libs/` and `tests/_kit/`. Result: 4 files in the 1000–1500 band and 0 over the 1500 cap.

In-client checks are deliberately absent from this block. They live in `03_SMOKE_TESTS.md`.

## Conventions detected (sweep)

| Convention | Present? | Where |
|---|---|---|
| Chat prefix / wrapped printer | yes | `NS.PREFIX` (`core/Namespace.lua:19`). The printer comes from LibKa0s-Core via `core/CoreSetup.lua`. Files take `local print = NS.Print` |
| `COMMANDS` table | yes | `NS.COMMANDS` (`settings/Slash.lua:285-368`), dispatched by LibKa0s-Slash |
| Single write path | yes, two seams by ratified design | `NS.Schema:Set` for settings rows, `NS.Registry:Set` / `:SetPosition` for panel records (the `architecture-§5` deviation row) |
| Flat-row `Schema.lua` | yes | `settings/Schema.lua` over LibKa0s-Schema-1.0 |
| Secret-values doc | no | The addon reads no trigger-set API. The `events-frames-taint-§8` row is re-graded in ARCHITECTURE |
| `.gitattributes` | pinned `* text=auto eol=crlf`, with `*.sh`/`*.py` LF carve-outs and binary markings | The kit's `test_eol` case is green: every tracked file carries its declared terminator. This is an observation; `/wow-addon:standards-audit` owns the check |
| Own marks where the library ships one | none found | The debug console and its copy window are the library's. The landing logo and the artwork catalog are product content, not chrome |
| LibKa0s majors wired | Core, Env, Media, DebugLog, Slash, Options, Launcher, Lifecycle, Schema | One setup file each under `core/` and `settings/`. Perf is declined (ratified) |
| Shared test kit | yes | `tests/_kit/` (vendored). Load list derived via `Loader.tocFiles` + `Loader.xmlFiles` (`tests/run.lua:28,34`) |
| Evidence | `docs/test-cases.md`, `docs/performance.md`, `docs/automated-tests/` (12 bundles + RESULTS.md) | No `tests/perf.lua` and no `docs/perf-analysis/` (both declined) |

---

## High

### F-001 — A disabled addon still draws, outlines and arms drag on every unlocked panel `[design]` `[ux]`

- **Where:**
  - `modules/Unlock.lua:171-177`. `U:Decorate` ends with `if f.__spec then f:SetAlpha(f.__spec.alpha) end` / `f:Show()` / `U:ArmDrag(f)`.
  - `modules/Canvas.lua:802`, `if NS.Lifecycle and NS.Lifecycle:IsDown() then spec.shown = false end`, followed at `:823` by `if NS.Unlock and NS.Unlock.Decorate then NS.Unlock:Decorate(f, rec) end`.
- **Problem:** The stand-down rung in `Canvas:Render` sets `spec.shown = false`, and `applySpec` hides the frame. But `Unlock:Decorate` runs **after** it and calls `f:Show()`, `EnableMouse(true)` and `RegisterForDrag` on every panel that `U:IsPanelUnlocked` answers true for. It never consults the latch. So the show decision has a second rung that overrides the stand-down.
- **Unguarded routes:** Unlocking has three routes that no disabled gate covers:
  - the Master-controls *Lock frame* row (`settings/Schema.lua:503-509`, whose `set` calls `NS.Unlock:SetUnlocked(not v)` unconditionally);
  - `/pm set state.locked false` (`set` is a live verb, `settings/Slash.lua:342`);
  - the Panels page's per-panel *Unlock* tick (`settings/PanelEditor.lua:749-750`).

  Only `/pm unlock` and the launcher's left click refuse.
- **Impact:** This breaks `slash-commands-§7`'s first MUST: every owned frame must be hidden at the source and stay hidden. A player who disables the addon while unlocked, or unlocks from the settings panel while disabled, sees every panel on screen with its gold outline, name label and a live drag handle. Dragging one writes `db.profile.panels` through `R:SetPosition`, even though the addon claims to be off.
- **Evidence:** A headless probe loaded the real TOC through the kit loader and ran the real lifecycle; the script was in scratch, not committed. With two panels:
  - `unlocked then DISABLED: shown = 2`
  - `disabled + per-panel unlock: shown = 1`
  - `disabled + Lock frame unticked: shown = 2`
  - For comparison, `disabled + relocked: shown = 0`.
- **Coverage:** `tests/test_disabled.lua` has no case that unlocks a panel. Its `shownPanels()` survey is only ever taken with the panels locked (see F-006).
- **Reachability:** Any player on a default profile who unticks *Lock frame* on the General page and then unticks *Enable Ka0s Panel Master* on the same tab, or who ticks a panel's *Unlock* on the Panels page while the addon is off. Both are ordinary settings-panel clicks, in every session.
- **Fix direction:** Enforce the latch inside the one show ladder. The unlock decoration must be applied only while the latch is up. Stripping the overlay while the addon is down keeps "hidden at the source" true through every re-render (`slash-commands-§7`, `performance-§6`). Do **not** add an imperative `Hide()` sweep to `NS.StandDown`; that is the pattern §7 rejects.

### F-002 — *Only in combat* / *Only out of combat* never flip when a fight starts `[logic]` `[deprecated-api-adjacent]`

- **Where:**
  - `core/Compat.lua:79-82`, where `Compat.InCombat()` returns `InCombatLockdown() and true or false`.
  - `modules/Canvas.lua:787`, `Canvas.BuildSpec(rec, currentSettings(), NS.Compat.InCombat())`.
  - `core/PanelMaster.lua:125-127`, where `OnRegenDisabled` calls `RenderForCombat()`.
- **Problem:** Combat lockdown begins **after** `PLAYER_REGEN_DISABLED` fires and ends **before** `PLAYER_REGEN_ENABLED` fires (warcraft.wiki.gg, *API InCombatLockdown*). So `InCombatLockdown()` returns `false` inside **both** transition handlers. The combat-entry repaint therefore recomputes every panel with `inCombat = false`:
  - an `inCombat` profile stays hidden for the whole fight;
  - an `outOfCombat` profile stays visible for the whole fight.

  The exit repaint is correct only by coincidence. Nothing else repaints on a combat edge, so the wrong state holds until an unrelated settings or panel change mid-fight.
- **Impact:** Two of the four values of the General-visibility dropdown do nothing at the moment they exist for. `events-frames-taint-§2` names this exact shape: display state gated on `InCombatLockdown()` instead of `UnitAffectingCombat("player")`, with the AbsorbTracker bug as its live example. It also says transitions SHOULD be driven off the two events.
- **Reachability:** Any player who sets *General visibility* on the Master controls tab to *Only in combat* or *Only out of combat*. That is a composed canonical row on a normal install, and the bug fires on every pull.
- **Fix direction:**
  - Carry the transition's truth from the event: `OnRegenDisabled` → `true`, `OnRegenEnabled` → `false`, threaded into the combat repaint.
  - Answer `Compat.InCombat()` from `UnitAffectingCombat("player")` (presence-guarded, with `InCombatLockdown` as the fallback) for every non-transition render (`events-frames-taint-§2`, `compat`).
  - Keep `BuildSpec` pure: it already takes `inCombat` as an argument.
  - Keep the unlock deferral on `InCombatLockdown()`. It is a UX gate either way, and the standard does not require moving it.
- **Coverage:** The test that claims this path models the event order backwards (F-005).

### F-003 — `/pm recover` bounds stored offsets against UIParent units while the frame is scaled `[logic]`

- **Where:** `modules/Registry.lua:876-904`. The bound is taken at `:892-895` (`offsetRange(relPoint, w)` / `offsetRangeY(relPoint, h)`, then `Util.Clamp(rec.x, minX, maxX, 0)`).
- **Problem:** `applySpec` calls `f:SetScale(spec.scale)` **before** `f:SetPoint(..., spec.x, spec.y)` (`modules/Canvas.lua:566-569`). `spec.scale` is the panel's own scale times the master Scale (`modules/Canvas.lua:112-113`), so the stored offsets are in the frame's scaled coordinate space. The drag-stop also reads them back that way, through `frame:GetPoint(1)` at `modules/Unlock.lua:211`. `R:Recover` compares those scaled offsets against `Compat.GetScreenSize()`, which is UIParent units.
- **Impact:**
  - At effective scale `s < 1`, recover drags panels that are fully visible. A TOPLEFT-anchored panel stored at `x = 3000` with `s = 0.5` sits at screen x 1500 on a 1920-wide UI, which is visible. Recover clamps it to `x = 1920`, so it is drawn at screen x 960.
  - At `s > 1`, recover leaves a genuinely off-screen panel in place.
  - Either way it rewrites the player's stored layout on the case it should not touch, and says `moved N panels back on screen`.
- **Reachability:** Any player who has set a panel's *Scale* (Panels page) or the Master-controls *Scale* row to anything other than 1, and then runs `/pm recover` or the General page's *Recover panels* button. Both are documented (`README.md:261`).
- **Fix direction:** Divide the screen extent by the record's effective scale before bounding. Resolve that scale through the same clamp the renderer uses, so recover and render cannot disagree, and keep the per-anchor range functions. Add a case at `s = 0.5` and `s = 2`.

---

## Medium

### F-004 — A profile switch that swaps which id owns which frame name leaks a named frame per switch `[perf]` `[design]`

- **Where:** `modules/Canvas.lua:811-820`, the mismatch branch in `Canvas:Render`: `release(f)` of the wrong-named frame, then `acquire(spec.frameName)`. Also `modules/Canvas.lua:696-703` (`acquire`) and `:829-840` (`RenderAll` renders id by id).
- **Problem:** `RenderAll` resolves mismatches one id at a time. Consider two profiles that hold the same two frame names under swapped ids. When id 1 now wants `PanelMaster_Panel_Xray`, that frame is still `active[2]`, not in the pool. So `acquire` calls `CreateFrame("Frame", "PanelMaster_Panel_Xray", UIParent)` a **second time**, which also re-points the global. When id 2 is reached, its old frame goes back to the pool and overwrites the pool slot for that name. The earlier frame is then unreachable forever. Each leaked panel frame carries its bg, border, accent (×5) and art child frames.
- **Evidence:** A headless probe (scratch script, real TOC, kit loader) alternated `OnProfileChanged` between `{1 Alpha, 2 Xray}` and `{1 Xray, 2 Alpha}` six times. It recorded **6 named `CreateFrame` calls**, one duplicate global per switch. `PooledCount()` stayed at 1, so each switch's extra frame is orphaned.
- **Impact:** Unbounded frame growth across a session of profile switching. WoW never collects frames, so this contradicts `events-frames-taint-§6`'s pooling intent and the bound this file's own header claims ("one per distinct FRAME name used this session", `modules/Canvas.lua:36-40`). Nothing is visibly wrong because the leaked frames are hidden, so the problem is silent.
- **Reachability:** Any player with two or more profiles whose panels share names under different ids (built independently, or in a different order) who switches profiles in-session from the Profiles page. It needs several profiles, but those are ordinary UI clicks.
- **Fix direction:** Make `RenderAll` two-pass: release every mismatched or retired frame first, then acquire. A frame is then always back in the pool before any id asks for its name. `Render(id)` keeps its single-id path. Pin it with a case that counts named `CreateFrame` calls across swaps.

### F-005 — The combat-visibility case feeds the renderer the client's events in an order the client never uses `[tests]`

- **Where:** `tests/test_canvas.lua:422-446`, "Canvas: leaving and entering combat both reach the renderer". At `:436-437` it sets `T.mocks.__inCombat = true` and then calls `NS.addon:OnRegenDisabled()`.
- **Problem:** The case raises the lockdown flag **before** delivering `PLAYER_REGEN_DISABLED`. The client does the reverse. So the case passes against exactly the implementation F-002 shows is broken in-game. It is the case `docs/test-cases.md` lists over this path, which makes it the "coverage that is asleep" shape: it reads as coverage and provides none for the real sequence (the `testing-§12` class).
- **Reachability:** Only the test inventory. The shipped defect is F-002.
- **Fix direction:** Deliver the event with the flag still **false** (the real ordering), and assert the panel hides. The case goes red today, and that red is F-002's regression guard. Never weaken it to stay green.

### F-006 — The stand-down conformance suite never unlocks a panel `[tests]`

- **Where:** `tests/test_disabled.lua`. Its `seed()` / `shownPanels()` surveys are taken with every panel locked. The only unlock reference is the launcher-refusal case (`:424`).
- **Problem:** `slash-commands-§7`'s conformance test must fail on any frame that survives the stand-down. This suite cannot see the one rung (F-001) that re-shows frames behind the latch, so its green `shownPanels() == 0` assertions are true only for the locked configuration.
- **Reachability:** Only the test inventory. The shipped defect is F-001.
- **Fix direction:** Add cases for:
  - unlock (via `state.locked`) and then disable;
  - disable and then unlock via the *Lock frame* row, via `/pm set state.locked false`, and via `Unlock:SetPanelUnlocked`.

  Each asserts `shownPanels()` is empty and the frame's mouse is disabled. Each carries a `-- red under:` line naming the latch check in the decoration path.

---

## Low

### F-007 — Grid size carries two maxima `[design]`

- **Where:** `settings/Schema.lua:71-76`. The row declares `max = 64` while its `validate` accepts up to `C.MAX_GRID`, which `core/Constants.lua:100` sets to `128`. `modules/Unlock.lua:39` clamps with `C.MAX_GRID`.
- **Problem:** The slider and the CLI parser (which clamps to `row.max`) stop at 64. The validate seam and the snap math allow 128. There are two answers to one bound.
- **Reachability:** Only a hand-edited SavedVariables value between 65 and 128, which the renderer honors and the slider cannot display. There is no UI path to reach it.
- **Fix direction:** Declare `max = C.MAX_GRID` or lower `C.MAX_GRID` to 64. Either way it becomes one constant.

### F-008 — The Panels page's per-panel *Unlock* tick can show a state the panel is not in `[ux]`

- **Where:** `settings/PanelEditor.lua:743-754` ("No refresher: … a rebuild is the only thing that can change it"), with `modules/Unlock.lua:123-126` and `:245`.
- **Problem:** The tick goes stale in three ways:
  - It reads `U:IsPanelUnlocked(id)`, which is true whenever the **global** unlock is on. Unticking it while globally unlocked clears only the per-panel entry, so the box shows unticked on a panel that is still unlocked.
  - A global lock (`/pm lock`, *Lock frame*, the minimap click) clears every per-panel unlock but fires no panel message, so an open editor keeps showing a ticked box.
  - A combat-deferred unlock replayed on `PLAYER_REGEN_ENABLED` leaves the box unticked.
- **Reachability:** Any player with the Panels page open who uses the global lock or unlock, or who unticks the per-panel box while globally unlocked.
- **Fix direction:** Refresh the tick from a real source whenever unlock state changes: a scalar refresher run on the unlock paths, or a message the unlock module sends. When the global unlock is on, render the tick as disabled or explain it, rather than accept an untick that cannot take effect.

### F-009 — Stale or wrong comments `[naming]`

- **Reachability:** Comments and docs only; no runtime effect.
- **Stale or wrong comments:**
  - `core/PanelMaster.lua:10` says the secret-safe `NS.Print` is "defined in core/Util.lua". It has been built in `core/CoreSetup.lua` since the LibKa0s-Core adoption, and `core/Util.lua:237-243` says so.
  - `core/CoreSetup.lua:17-18` says the embed "overwrites NS.Print with AceGUI's own :Print". It is AceConsole's (the addon is created with `"AceConsole-3.0"`, `core/PanelMaster.lua:4`).
  - `settings/Slash.lua:292-293` claims `settings/Schema.lua`'s `announce("enabled")` runs for `enable`/`disable`. The enabled row deliberately does **not** announce (`settings/Schema.lua:463-474`); its `onChange` is `NS.RefreshEnabled()`.
  - `defaults/Profile.lua:4-5` and `core/Database.lua:16` say `global` carries only the schema stamp. `defaults/Global.lua` deliberately does **not** seed the stamp (`:8-20`), and the one declared global default is LibDBIcon's `minimap` table (`:74-76`).
  - `core/Database.lua:170` gives `schema v1` as the example `[Init]` line, but `NS.SCHEMA_VERSION = 2` (`core/Namespace.lua:14`).
- **The PEW rationale is stated as a mechanism that does not exist.** These sites justify painting on `PLAYER_ENTERING_WORLD` because "UIParent's size is what the registry's off-screen recovery measures against":
  - `core/PanelMaster.lua:101-103`
  - `core/LifecycleSetup.lua:112-115`
  - `docs/ARCHITECTURE.md:228`
  - `docs/data-flow.md:200`

  But recovery never runs on a render. It is on-demand only (`modules/Registry.lua:854-858`, "Nothing here runs automatically"). Painting at PEW is still reasonable. The stated reason is not the real one.
- **Fix direction:** Correct each sentence to the current mechanism. No code changes.

---

## Upstream findings

**None.** No defect was found in `libs/LibKa0s/` or `tests/_kit/`, and both are byte-identical to `../LibKa0s` at `v1.55.0`. Every finding above lands in this repo's own files.

## Findings with no case over them today

| Finding | Covered by an existing case? |
|---|---|
| F-001 | No. `test_disabled.lua` never unlocks (F-006) |
| F-002 | Nominally yes, but the case models the wrong event order (F-005) and is asleep |
| F-003 | No. The five `Registry.Recover` cases (`tests/test_registry.lua:283-330`) never set `scale` or the master Scale, so every one runs at scale 1 |
| F-004 | No. `test_profiles.lua` switches only to empty or fresh profiles, so no id swap occurs |

## Counts

Critical 0 · High 3 · Medium 3 · Low 3 · Upstream 0
