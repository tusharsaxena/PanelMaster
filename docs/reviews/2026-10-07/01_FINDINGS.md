# PanelMaster review: findings (2026-10-07)

**Verdict: minor issues.** No load failure, no taint path and no protected-API leak. Lint, tests and complexity are all green. There are two **High** findings, and both reach a normal install. Non-Latin panel names collide on the frame-name contract, so a player on a ruRU, koKR, zhCN or zhTW client can create only one panel named in their own script. The *Delete all panels* confirmation says "on this character", but the addon's default profile is shared, so the delete removes the layout from every character on that profile.

**Resolved scope:** `all`. This is the whole repository at `06f3c28` on `feat/2026-10-07-review-audit-remediation`, with a clean tree. Vendored `libs/` and `tests/_kit/` were read only to route upstream findings. Profile: `wow`, kind `addon`. Standard cross-check against **Ka0s WoW Addon Standard v2.76.1 (2026-10-07)**: the index and all 27 section files were fetched to scratch.

## Measurement run

Every suite was re-run today from the repo root through `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded`. Output went to a scratch path outside the repo, and nothing was written into the repo except this bundle.

| Suite | Result | Command and counts |
|---|---|---|
| luacheck | **pass** | `ka0s-bounded luacheck .` → `0 warnings / 0 errors in 71 files` (exit 0). Scope is `.luacheckrc`'s: `libs/`, `tests/_kit/`, `_dev/`, `docs/audits/` and `docs/reviews/` are excluded. |
| Headless suite | **pass** | `ka0s-bounded lua5.1 tests/run.lua` → `1035 passed, 0 failed, 1 skipped, 1036 total` (exit 0). The one SKIP is the kit's `diagnostics contract: an addon that opts out …`, which is expected because this addon keeps `enablesLogging`. |
| Fresh `--list` inventory | **pass, no drift** | `ka0s-bounded lua5.1 tests/run.lua --list` to scratch, then `diff` against `docs/test-cases.md` after CR normalization: **empty**. Totals 1036 match. |
| `tests/perf.lua` | **not applicable** | The repo ships no `tests/perf.lua`. `Perf` is declined by a ratified `performance-§1` row in `docs/ARCHITECTURE.md`. |
| Complexity (sighted) | **pass** | `ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` → `0 warnings, 17349 NLOC / 2168 funcs, avg CCN 2.0 (max 15)`, blindFiles 0 (no blind note; kit revision 37 ≥ 35, so the run is sighted). |
| `make test` | not applicable | There is no root `Makefile`. |
| Vendor sync | **pass** | Tag v1.70.0 (provenance line `CLAUDE.md:45`; `../LibKa0s` on the same tag, clean). `diff -r --strip-trailing-cr` and the byte `diff -r` for `../LibKa0s/LibKa0s` vs `libs/LibKa0s` and `../LibKa0s/testkit` vs `tests/_kit` give **0 lines each**. Against `git archive v1.70.0` also 0/0. `tests/test_vendor_sync.lua` (3 cases) green. |
| Cross-addon (4 classes) | **pass, matches baseline shape** | Run from `GIT/` over the 11 `ADDONS.md` rows, with each addon's TOC-derived load list as the scope. **Class 1:** 22 roots, `uniq -d` empty, zero raw `SLASH_*`. **Class 2:** a single minors line `Bus:2 Compat:1 Core:10 DebugLog:19 Env:1 Item:2 Launcher:5 Lifecycle:3 Media:4 Options:28 Perf:14 Pool:3 Schema:2 Slash:19 Widgets:12`. **Class 3:** `diff -rq AbsorbTracker/libs/LibKa0s <each>` empty for all 11, with AbsorbTracker as the reference. **Class 4:** a single `## Interface: 120100`. All 11 provenance lines read v1.70.0. The tag has moved since the brief's v1.56.0 baseline, so the library-derived figures differ (stale brief, not drift). |

Committed artifacts that disagree with today's run. All of them are stale rather than non-compliant:

- `docs/automated-tests/RESULTS.md`, newest bundle `20260927-032003` (measured `8cda106`, 52 commits behind HEAD per the runner): 964 cases, 1917 funcs, 16138 NLOC. Today: 1036 cases (1035 passed + 1 skip), 2168 funcs, 17349 NLOC, max CCN unchanged at 15, warnings 0 in both.
- `RESULTS.md` watch list: `tests/test_libka0s.lua` is recorded at 1131 LOC. Today `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | xargs wc -l` gives **1184**, still under its recorded re-check trigger of 1300.
- `docs/ARCHITECTURE.md` › *Files over the 1500-line cap* is a dated census ("Measured 2026-09-30"). It records `test_libka0s.lua` 1160 and `modules/Registry.lua` 987. Today they are 1184 and 972 with the same command. The census is dated, so this is not a finding.

Two other probes ran headlessly in scratch only. Both reuse the `tests/run.lua` bootstrap (`Loader.tocFiles` plus `wow_mock.lua`) and edit nothing in the repo. They are cited where used:
`$SCRATCH/probe/probe.lua` (non-finite numbers), `probe2.lua` (Sanitize coverage), `probe3.lua` (non-ASCII names, `LC_ALL=C`) and `probe4.lua` (held unlock across a stand-down).

In-client checks are deliberately absent here; they live in `03_SMOKE_TESTS.md`.

---

## High

### F-001: Non-Latin panel names collapse to one frame name, so only one can exist `[locale]` `[correctness]`

- **Where:** `core/Util.lua:199` `local s = tostring(name or ""):gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")` and `core/Util.lua:200` `if s == "" then return "Panel" end`. The refusal comes from `modules/Registry.lua:434` `local clash = frameNameTaken(frameName)`.
- **Problem:** Lua's `%w` is ASCII-only, so every byte of a UTF-8 letter is treated as punctuation. A name written wholly in Cyrillic, Hangul or Han slugs to `""`, which falls back to `"Panel"`. Every such panel therefore wants the global `PanelMaster_Panel_Panel`. Latin names with diacritics lose their accented letters, so `Ärger` and `Örger` both become `rger`.
- **Impact:** The second native-script panel is refused with `'Фон' would share the frame name PanelMaster_Panel_Panel with 'Чат' — pick another name`. An English panel named `Panel` is then refused too. README.md:98-99 promises the slug turns "anything that is not a letter or number" into an underscore, and for these players their letters are exactly what gets dropped.
- **Reachability:** Any player on a ruRU, koKR, zhCN or zhTW client who names a second panel in their own script, through the documented `/pm new` or the Panels page's *Create new panel* box, on a default install. deDE and frFR players hit it only on accent-only collisions.
- **Evidence (measured, scratch `probe3.lua`, `LC_ALL=C lua5.1`):** `Чат → ok PanelMaster_Panel_Panel`, then `Фон`, `聊天` and `Panel` are all **REFUSED** naming `PanelMaster_Panel_Panel`. `Ärger → PanelMaster_Panel_rger`, then `Örger` is **REFUSED**. The client's own `%w` class is expected to be ASCII as well. That is unverified in-client and is pinned by smoke step LOC-2 / LOC-6.
- **Coverage:** `tests/test_media.lua:19-27` (`Util.Slugify`) and `tests/test_registry.lua` feed ASCII only. `tests/test_docs.lua:13` names the hole in a comment and asserts only that the smoke document mentions it. So the inventory carries no case over this path.
- **Disposition (adversarial):** **Address.** This is a real broken flow for a real locale population, and a smoke checklist does not stand in for a fix. `docs/smoke-tests.md` LOC-2 itself says "a refusal is a finding to file". The fix is cheap and only affects panels created after it, because existing frame names are stamped on the record.

### F-002: The *Delete all panels* confirmation understates its blast radius `[ux]` `[correctness]`

- **Where:** `settings/Slash.lua:81` `text = "Delete ALL Ka0s Panel Master panels on this character? This cannot be undone.",` The same popup is reached from `/pm panel deleteall` (`settings/Slash.lua:180-186`) and from the Panels page's Defaults button (`settings/Panel.lua:454-460`, tooltip `settings/Panel.lua:445` `"Delete every panel. This cannot be undone."`).
- **Problem:** `R:DeleteAll` empties `db.profile.panels`, the **active profile**. `core/Database.lua:19` `NS.db = LibStub("AceDB-3.0"):New(addonName .. "DB", NS.defaults, true)` puts every new character on the shared `"Default"` profile, so on a default install the profile is shared across the account. The popup tells the player the delete is scoped to this character.
- **Impact:** A player who accepts expecting their alts to keep their panels loses the layout on every character that uses the profile. The standard's own reasoning names this failure: "an `OnAccept` that does something the text did not warn about is how a player loses a layout they spent an evening on" (`options-ui-§12`).
- **Reachability:** Any player on the default config with more than one character who uses `/pm panel deleteall` or Panels ▸ Defaults. Both are documented surfaces.
- **Coverage:** `tests/test_slash.lua:546` asserts only that the popup key is shown, never its wording.
- **Disposition (adversarial):** **Address.** It is a one-string fix, and this is unwarned loss of data the player owns.

## Medium

### F-003: Panel number fields accept NaN and ±infinity, and `/pm recover` cannot repair a NaN `[correctness]` `[error-handling]`

- **Where:** `settings/PanelSchema.lua:41` `local n = tonumber(value)` (`COERCE.number`); `core/Util.lua:18-22` (`Util.Clamp`: `n = tonumber(n)` … `if n < lo then return lo end` … `return n`); `modules/Registry.lua:241` `local function freeNumber(v, t) return tonumber(v) or t end`; `modules/Registry.lua:902` `return Util.Clamp(rec.x, minX, maxX, 0), Util.Clamp(rec.y, minY, maxY, 0)`.
- **Problem:** `tonumber("1e999")` is `inf` and, where the C runtime parses it, `tonumber("nan")` is NaN. `Clamp` lets NaN through because both comparisons are false, and `freeNumber` lets ±inf and NaN through for `x`, `y`, `artX` and `artY`. Profile rows are safe, because their `validate` refuses NaN. The panel rows have no `validate`, only `normalize`.
- **Impact:** The value is stored, handed to `SetSize` and `SetPoint` (`modules/Canvas.lua:112` `spec.x = tonumber(rec.x) or 0` keeps NaN), and written to SavedVariables. A NaN `x` makes `/pm recover` report "moved 1 panel" on every run while leaving it NaN, because `x ~= rec.x` is always true for NaN (`modules/Registry.lua:924`). How the client serializes a non-finite number into SavedVariables is **unverified** (smoke step NUM-3).
- **Reachability:** Only a player who types a non-finite literal into the panel CLI, for example `/pm panel <name> x 1e999` (certain) or `… width nan` (client-dependent). The editor's sliders cannot produce one.
- **Evidence (measured, scratch `probe.lua`):** `x nan → stored nan`, `x 1e999 → inf`, `width nan → nan`, `alpha nan → nan`, `scale nan → nan`, `artX 1e999 → inf`. With `x = nan`, `recover1 1 nan`, `recover2 1 nan`, and `BuildSpec` gives `width nan x nan`. `settings.scale = 0/0` is refused (`invalid value`).
- **Disposition (adversarial):** **Address.** The trigger is unusual but the hardening is a few lines at the trust boundary. Today the result is an unrepairable record, and possibly a corrupt SavedVariables file.

### F-004: `R.Sanitize` leaves four template fields unfilled and unrepaired, a 2026-08-03 finding that never landed `[correctness]` `[tests]`

- **Where:** The contract is `modules/Registry.lua:295` `-- Fill every missing field from the template and clamp every numeric one into range.`, but the loop at `modules/Registry.lua:321` `for field, repair in pairs(REPAIR) do …` walks only fields that have a rule. The rule lists omit four fields: `modules/Registry.lua:224` `local ENUM_FIELDS = { "artFill", "artRotation", "artLayer" }` (no `artBlend`), `modules/Registry.lua:228` `local BOOL_FIELDS = { "mouseover", "accentEnabled", "artFlipH", "artFlipV" }` (no `artDesaturate`), and `modules/Registry.lua:273` `REPAIR.bgColor, REPAIR.borderColor, REPAIR.artColor = color, color, color` (no `accentColor`, no `accentBorderColor`).
- **Problem:** A record missing those keys stays missing them, and junk in them survives every write. `R:CopyFrom` (`modules/Registry.lua:574` `if not COPY_EXCLUDED[field] and source[field] ~= nil then`) runs as a record write, so it skips the parse and copies the junk onto the target. The editor's color reads have no template fallback (`settings/PanelEditorTabs.lua:223` `local c = NS.Util.Color(v)`, `settings/PanelEditor.lua:334` `local col = NS.Util.Color(rec[field])`). For a record without `accentColor` the swatch shows white while the renderer draws the template color through `Util.ResolveColor`.
- **History:** `docs/reviews/2026-08-03/01_FINDINGS.md` F-002 raised the `artBlend` / `artDesaturate` half. Its plan (C-03, tasks T-2.1 and T-2.2) included a property test asserting that "no template field is ever skipped again". No commit carries those ids (`git log --all --grep="F-002\|C-03\|T-2.1\|T-2.2"` → only unrelated 2026-07-30 commits), and no such test exists today. The gap also predates the `b58cba5` REPAIR-table refactor (`git show b58cba5^:modules/Registry.lua` has the same three-item enum list). The fix was planned and never made.
- **Reachability:** Records written by a build older than these fields, records in a hand-edited or imported SavedVariables file, and any `Copy settings from panel` whose source holds such a record. The renderer itself degrades correctly. The visible effects are a wrong editor swatch, `artDesaturate = nil` / `artBlend = <junk>` in `/pm panel <name>`, and junk copied between panels.
- **Evidence (measured, scratch `probe2.lua`):** `template fields NOT filled by Sanitize: accentBorderColor, accentColor, artBlend, artDesaturate`. A junk record after Sanitize gives `BOGUS yes`. `CopyFrom` from a source with `artBlend = "BOGUS"` gives the target `BOGUS`.
- **Disposition (adversarial):** **Address.** The table-driven REPAIR claims a coverage property it does not have, and a review already found this once and lost the fix. The property test is what stops it recurring.

### F-005: The editor's per-panel *Delete* and *Reset* run on one click, and a comment claims Reset is confirmed `[ux]` `[naming]`

- **Where:** `settings/PanelEditorTabs.lua:390` `local resetBtn = makePairButton("Reset", function() pageAction.reset(rec) end)` and `:396` `local deleteBtn = makePairButton("Delete", function() pageAction.delete(rec) end)`. They are drawn side by side as a button pair and go straight to `settings/PanelEditor.lua:154-157` (`NS.Registry:Delete(rec.id)`). The false claim is at `modules/Registry.lua:945-946`: `-- … R:Reset is the per-panel verb that does take the / -- whole record, and it is confirmed on its own control.`
- **Problem:** Both are irreversible: Delete removes the record, and Reset rewrites about 50 fields. Neither asks first. The two sit as adjacent halves of one row, so a misclick on one lands on the other. The tooltip itself says "This cannot be undone."
- **Impact:** A single misclick loses a panel, or every setting of a panel, with no undo. The Registry comment leads a maintainer to believe a guard exists.
- **Reachability:** Any player who uses the Panels page's General tab.
- **Disposition (adversarial):** **Address**, with the reasoning stated. The standard mandates a confirmation only for the *global* reset (`options-ui-§12`), so this is not a compliance fix. The addon already confirm-gates its two bulk destructive acts, though, and the per-panel pair is the one destructive surface left ungated. At minimum the false comment must go.

## Low

### F-006: A combat-held unlock survives a stand-down and fires later, unasked `[correctness]`

- **Where:** `modules/Unlock.lua:257-261` (`pendingUnlock = true` … `print("…unlock queued — panels unlock when you leave combat…")` … `return nil`). `NS.StandDown` (`core/LifecycleSetup.lua:101-110`) unregisters `PLAYER_REGEN_ENABLED` and never drops the queue. The comment at `core/LifecycleSetup.lua:63-66` says the unlock deferral "has nothing to defer while the addon is down", which is false.
- **Problem:** `set` is a live verb while disabled (`settings/Slash.lua:389`), so `/pm set state.locked false` in combat on a disabled addon queues an unlock and promises it "when you leave combat". No handler is registered to keep that promise. The same happens to a queue taken while enabled followed by `/pm disable` mid-fight. On the next `/pm enable`, the **next** combat exit, possibly hours later, unlocks every panel and prints `panels unlocked`.
- **Reachability:** Only a player who requests an unlock during combat and has the addon disabled (or disables it) before that combat ends. It is narrow but real.
- **Evidence (measured, scratch `probe4.lua`):** `held while disabled: true` → `still held after re-enable: true unlocked: false` → `after next combat exit -> unlocked: true`.
- **Disposition (adversarial):** **Address, cheaply.** A stood-down addon draws nothing, so there is no mid-pull hazard to defer. Apply the state immediately while down, and drop the held queue in `NS.StandDown`.

### F-007: The panel list and picker read `enabled == nil` as disabled, while the renderer reads it as enabled `[correctness]`

- **Where:** `settings/Slash.lua:156` `local name = rec.enabled and ("|cffffff00%s|r"):format(rec.name)` and `settings/PanelEditor.lua:601` `list[rec.id] = rec.enabled and rec.name or (rec.name .. " |cff808080(disabled)|r")`. The repair rule is `modules/Registry.lua:264` `function REPAIR.enabled(v) return v ~= false end`, and the renderer uses `modules/Canvas.lua:203` `and (rec.enabled ~= false),`.
- **Impact:** A record with no `enabled` key, which no build writes but which an unsanitized hand-edited or imported record can have, is drawn but listed as "(disabled)" in gray.
- **Reachability:** Only a record that has never been written since it arrived without an `enabled` key. Nothing sanitizes at login.
- **Disposition (adversarial):** **Optional.** It is cosmetic and nearly unreachable. It is worth doing only because the fix is the same two-token change in each place.

### F-008: A comment cites a line that moved `[naming]`

- **Where:** `core/Database.lua:86` `-- includes the same frame-name backfill the v1 → v2 body performs (modules/Registry.lua:218-220).` The backfill is now at `modules/Registry.lua:317-319` (`if type(rec.frameName) ~= "string" or rec.frameName == "" then` / `rec.frameName = Util.FrameName(rec.name)` / `end`).
- **Reachability:** A comment, with no runtime effect.
- **Disposition (adversarial):** **Address** while touching nearby code. Cite the function (`R.Sanitize`) rather than a line, so it cannot rot again.

## Upstream (does not land in this repo as an edit)

### F-009 `[upstream]`: The kit's generated inventory header contradicts `testing-§5` about skips (LibKa0s, `testkit/framework.lua`), Low

- **Where (vendored copy, read-only):** `tests/_kit/framework.lua:576-577`: `out("lives in. The `## Totals` table below is the **authoritative pass count** — the README test")` / `out("badge and any count quoted in the docs must agree with it.")`.
- **Problem:** The `--list` Totals count every *registered* case, so 1036 here. `testing-§5` says a skip "**MUST NOT** be folded into either the passed count or the total". This repo's badge, `README.md:7` `Tests-1035%2F1035_passing`, is therefore **correct**, and it disagrees with the header that calls Totals the badge's authority. Any consumer carrying a kit case that SKIPs by design gets a header that contradicts its own correct badge. (Several sibling badges, such as `1201/1202`, appear to have folded a skip into the total. That is noted only as cross-addon context and is not graded here.)
- **Reachability:** Documentation text in a generated file, with no runtime effect.
- **Remedy:** Fix in `../LibKa0s` `testkit/framework.lua` (`renderInventory`): say that the badge counts passes and excludes skips, so it can sit below Totals by the skip count. Bump `Kit.VERSION`, release, then **re-vendor `tests/_kit/` whole** into this addon as its own commit, and regenerate `docs/test-cases.md` in that same commit. **Not a local edit:** `tests/_kit/` is overwritten by the next re-vendor.
- **Disposition (adversarial):** **Optional, upstream.** It is a wording fix, worth bundling into the next LibKa0s release rather than a dedicated one.

---

## Considered and not raised (adversarial notes)

- **`settings/Schema.lua`'s ~230-line `hostSchemaStub`** re-implements the Schema runtime on the library-absent arm. This is sanctioned rather than anti-pattern #47: `options-ui` permits a RUNTIME-COMPLETING stub where the major's API document prescribes one, the file cites that document, and `tests/test_surface_parity.lua` holds it to the live surface.
- **The README badge at 1035/1035 against Totals at 1036** is correct per `testing-§5` (see F-009).
- **The committed `RESULTS.md` is behind** by 52 commits. It is a release artifact and stale, not non-compliant. It is regenerated at release and never by a review.
- **`R:Rename` writes `rec.name` directly**, outside the schema seam. This is documented: `name` is identity with no schema row (`architecture-§5`, retired row #54).
- **The Canvas `R:Get` linear scan** gives an O(n²) `RenderAll`. It is negligible at realistic panel counts, and with no perf runner there is no number to ground a finding on.
