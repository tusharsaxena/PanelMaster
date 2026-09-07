# Review findings — Ka0s Panel Master, 2026-09-07

**Verdict: minor issues.** The addon is ship-ready. Every out-of-game suite is green today, the
generated inventory and the README badge agree with the live run, the LibKa0s seams are the
best-documented in the collection, and nothing found here is a taint, secret-value or data-loss
defect. One finding (the shared AceGUI widget-registry patch) reaches outside this addon and is
graded High for that reason; the rest are correctness nits, a stale rationale comment and structural
notes.

Standards cross-check: **performed**. Standard resolved at **v2.38.0 (2026-09-02)**, fetched from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master/standards/STANDARDS.md`
and its Sections list.

---

## Measurement run (Step 0 — everything re-run from scratch today)

All commands run from the repo root
`/mnt/d/Profile/Users/Tushar/Documents/GIT/PanelMaster`. Scratch output was written outside the
repo; **no committed artifact was modified**.

| Suite | Command | Result |
|---|---|---|
| luacheck | `luacheck .` | **pass** — `Total: 0 warnings / 0 errors in 27 files` |
| Headless tests | `lua5.1 tests/run.lua` | **pass** — `763 passed, 0 failed, 0 skipped, 763 total` |
| Test-case inventory | `lua5.1 tests/run.lua --list > <scratch>/list.md` | **pass** — 864 lines, **byte-identical** to the committed `docs/test-cases.md` |
| Offline perf runner | — | **skipped (absent by ratified decision)** — `tests/perf.lua` does not exist; `docs/performance.md` records this as a ratified `performance-§1` deviation with a `## Documented deviations` row in `ARCHITECTURE.md`. Not re-litigated here (see F-009 for what remains unverified as a consequence) |
| Complexity | `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` | **pass** — `No thresholds exceeded`; 12122 NLOC, 1472 functions, avg CCN 2.0, **max CCN 15** (`R.ApplyArtSize@658-686` and `Compat.AddOnFolders@27-45`), 0 warnings |
| `make test` | — | **n/a** — no root `Makefile` |
| Vendor sync (LibKa0s) | `diff -r libs/LibKa0s/ ../LibKa0s/LibKa0s/` | **pass on content.** Two files report as differing (`DebugLog.lua`, `Pool.lua`); after `tr -d '\r'` on both sides the diff is empty. The difference is line endings in the **source** repo, not content drift — see F-011 |
| Vendor sync (test kit) | `diff -r tests/_kit/ ../LibKa0s/testkit/` | **pass** — no differences |
| In-suite vendor gate | (part of the 763) | **pass** — both `test_vendor_sync` cases ran and passed against the sibling checkout; not skipped |

### Committed artifact vs. fresh run

| Artifact | Agreement |
|---|---|
| `docs/test-cases.md` | **current** — identical to today's `--list` output |
| `README.md` `[Tests]` badge (`763/763`) | **current** — matches today's run |
| `docs/automated-tests/RESULTS.md` (newest row `20260825-103450`) | **stale** — records 731/731 tests, 11223 NLOC, 1379 funcs, max CCN 15. Today: 763/763, 12122 NLOC, 1472 funcs, max CCN 15. See F-008 |
| `docs/performance.md` | consistent with the repo as-is (no harness, no `docs/perf-analysis/`, `perf` verb unregistered) |

**Nothing in this bundle was verified in-client.** Taint, frame behaviour, locale rendering and the
capture protocol are `03_SMOKE_TESTS.md`'s business.

---

## High

### F-001 — `core/LSMPatch.lua` mutates the shared AceGUI widget registry for every addon in the session
`core/LSMPatch.lua:44` — `[design]` `[ux]` `[likely-cross-cutting]`

**Problem.** At `PLAYER_LOGIN` the file wraps whatever constructor `AceGUI-3.0` currently holds for
`LSM30_Border` and re-registers the wrapper at `currentVer + 1`
(`AceGUI:RegisterWidgetType("LSM30_Border", …, currentVer + 1)`, `core/LSMPatch.lua:44,65`).
`AceGUI-3.0` is a **LibStub singleton**: `AceGUI.WidgetRegistry` is one table shared by every addon
in the session. From that moment on, **every** addon that creates an `LSM30_Border` dropdown gets
PanelMaster's construction — `f.displayButton:Hide()` plus the re-anchored `label` and `DLeft`
(`core/LSMPatch.lua:47-62`) — whether or not the widget is inside PanelMaster's own canvas.

**Impact.** A third-party Ace3-configured addon's border dropdown silently loses its 42×42 preview
swatch and shifts its bar left, with no attribution to PanelMaster. The blast radius grows with the
collection: `core/LSMPatch.lua` is also present in **AbsorbTracker, ConsumableMaster, KickCD and
MultiMeters**, so five addons each wrap the previous wrapper at `PLAYER_LOGIN` and the chain is as
long as the number of Ka0s addons installed. The file's own header explains why the patch lives in
`core/` rather than `libs/` (`core/LSMPatch.lua:23-24`), which is correct, but says nothing about the
singleton it edits.

**Reachability:** *Any player running PanelMaster alongside any other addon that draws an AceGUI
`LSM30_Border` dropdown — a default profile, every session, from `PLAYER_LOGIN` onward. No
PanelMaster window need ever be opened.*

**Fix direction.** Scope the fixup to widgets this addon builds rather than to the registry: hide
the `displayButton` and re-anchor on the widget instance at PanelMaster's own creation site
(`settings/PanelEditor.lua` builds the LSM30 pickers), leaving `AceGUI.WidgetRegistry` untouched.
Do **not** move the file under `libs/` — vendored code is read-only. If the collection wants the
look uniformly, the compliant direction is an additive helper in `LibKa0s-Options-1.0`'s widget
makers that consumers opt into per-widget (`library-stack`), not five addons racing to own a shared
registry slot.

---

## Medium

### F-002 — `R:DeleteAll` clears `previewIDs` but leaves `NS.State.preview` true
`modules/Registry.lua:577-592` (`NS.State.previewIDs` cleared at `:588`) — `[bug]`

**Problem.** `R:DeleteAll` performs the same session sweep `dropSessionIDs` does — except for one
line. `dropSessionIDs` clears the ids **and** the flag (`modules/Registry.lua:560-561`), and its
comment states exactly why the flag must go with them: *"Cleared with the `preview` flag itself,
because a flag left true makes `SetPreview(true)` return early and the user cannot even restart
preview to clear it"* (`modules/Registry.lua:543-545`). `R:DeleteAll` clears only the ids
(`modules/Registry.lua:588`); `NS.State.preview` stays `true`.

**Impact.** After `/pm panel deleteall` (or the `KA0S_PANELMASTER_DELETEALL` popup) with test mode
on, the Master-controls **Test mode** checkbox reads ticked with no sample panels on screen, and the
next press of it is a no-op the user can see nothing from — it merely flips the stale flag off.
Preview only comes back on the press after that. Not destructive; `SetPreview(false)` then calls
`DeleteBatch({})`, which is empty.

**Reachability:** *Any player who runs `/pm panel deleteall`, or presses the Delete-all button,
while test mode is on. Both are documented, UI-reachable actions on a default profile.*

**Fix direction.** Set `NS.State.preview = false` beside the `previewIDs` clear in `R:DeleteAll`, or
route both call sites through one private sweep so the two can no longer diverge.

### F-003 — `Util.ParseColor` scales a fractional alpha by 255 when RGB were bytes
`core/Util.lua:91-107` (the return at `:104-106`) — `[bug]` `[ux]`

**Problem.** The byte-vs-fraction decision reads only R, G and B (`core/Util.lua:101-103`) and then
divides **all four** components by the chosen scale (`core/Util.lua:104-106`). So
`/pm panel Chat bgColor 255,0,0,1` — bytes for the colour, the conventional `1` for "fully opaque" —
is read as alpha `1/255 ≈ 0.004`, i.e. an invisible panel. The header comment
(`core/Util.lua:80-87`) argues the case for following the scale through, on the grounds that a hex
colour pasted as bytes carries a byte alpha too; that is true for `…,255`, but it silently
mis-reads the one alpha value users type most.

**Impact.** A panel the player believes they made opaque red comes out effectively transparent, and
`/pm panel <name>` echoes `1.00,0.00,0.00,0.00` — which reads as "the value did not take" rather
than as "your alpha was rescaled". There is no error, so nothing points at the cause.

**Reachability:** *Any player who types a byte-scale colour with a shorthand alpha at
`/pm panel <name> <colorField> …` — a documented verb reachable on a default profile.*

**Fix direction.** When `scale == 255`, treat a fourth component `<= 1` as already fractional and a
component `> 1` as a byte. `Util.FormatColor` always emits fractions, so the round-trip property the
comment relies on is unaffected; extend the round-trip case in `tests/test_util.lua` to pin the new
reading in both directions.

### F-004 — `NS.InitSummary` reports the fallback constant, not the seam the docs say it uses
`core/Database.lua:141` vs `core/EnvSetup.lua:5-6` — `[design]` `[tests]`

**Problem.** `core/EnvSetup.lua:5-6` states the seam's contract in as many words: *"`/pm version`,
the help header and **the database's debug summary** all resolve through here."* `NS.InitSummary`
does not — it formats `tostring(NS.version)` (`core/Database.lua:141`), the fallback constant
declared at `core/Namespace.lua:7` and explicitly labelled *"Fallback only"* there. `NS.Version()`
(`core/EnvSetup.lua:71-74`), which prefers the TOC's `## Version`, is never called from this file.

**Impact.** Two sources of truth for one string. Today both read `1.0.0`, so there is no visible
symptom; the moment the packaged TOC version and the constant diverge, the `[Init]` line that rides
`DebugLog:SetEnabled` — the line a user pastes into a bug report — reports the stale one, and every
other version surface reports the other.

The suite cannot catch it: `tests/test_database.lua:160` asserts
`s:find("v" .. NS.version, 1, true) ~= nil`, i.e. it asserts against the very constant the code
reads, and the mock TOC answers the same string. The case passes identically under both
implementations. **This is a coverage gap under a finding, not a failing test.**

**Reachability:** *Anyone who enables `/pm debug` and reads the `[Init]` line. No effect today
because the two values are equal; the defect is the divergence the seam exists to prevent.*

**Fix direction.** Call `NS.Version()` in `NS.InitSummary`, and change the case to assert against
`NS.Version()` while pointing the mock's TOC version at a value **different** from `NS.version`, so
the case can actually go red.

### F-005 — 1350-line `settings/PanelEditor.lua` is deep in `layout-§1`'s on-notice band and still growing
`settings/PanelEditor.lua` (1350 LOC), `modules/Artwork.lua` (1188 LOC) — `[complexity]` `[structure]`

**Problem.** `layout-§1` caps a single `.lua` at 1500 LOC and puts the 1000–1500 band **on notice**.
Two files sit in it. `settings/PanelEditor.lua` grew **+543 lines net** across the settings-revamp-v2
branch (`git diff --stat f04a413~5 HEAD`) — the single largest movement in the tree — and is now 150
lines from the hard cap.

Today's `lizard` run finds **no** function over CCN 15 anywhere, so this is a file-size and cohesion
concern rather than a tangle: `PanelEditor` holds 72 functions at an average of 10.5 NLOC, which is
a long list of small builders rather than a knot. That is the argument for peeling by **section**
(the geometry pickers, the colour/border block, the artwork block) rather than by extracting a
`part2` helper.

**Impact.** The next feature on the Panels page pushes the file over a documented MUST, at which
point the split happens under schedule pressure instead of deliberately.

**Reachability:** *Maintainers only; no runtime effect. Graded Medium as a structural hazard, not a
user-facing one.*

**Fix direction.** Peel `settings/PanelEditor.lua` along its own section boundaries into sibling
files under `settings/`, keeping the TOC annotation convention this repo already uses on every line.
Do **not** extract into a helper whose name describes nothing (anti-pattern #52).

### F-006 — the mouseover `OnUpdate` driver ticks forever once created, including with nothing tracked
`modules/Canvas.lua:642-653` (`MOUSEOVER_INTERVAL` at `:624`) — `[perf]`

**Problem.** `ensureMouseoverDriver` creates one frame and installs an `OnUpdate` that is never
removed; the comment at `modules/Canvas.lua:655-657` states the design decision openly (*"never
destroyed once created … it stops doing any work the moment the tracked set is empty"*). The
`OnUpdate` closure itself still runs **every frame** for the rest of the session, accumulating
`delta`, and every 0.1s enters `updateMouseover` to iterate an empty table
(`modules/Canvas.lua:626-638`).

**Impact.** Small and bounded — a per-frame accumulate plus a 10Hz empty `pairs` — but it is
per-frame work that exists after the user has turned mouseover off on every panel, and
`SetScript("OnUpdate", nil)` when `next(mouseoverPanels) == nil` removes it entirely.

Note also `elapsed = 0` (`modules/Canvas.lua:649`) rather than `elapsed = elapsed -
MOUSEOVER_INTERVAL`: the tick drifts by up to one frame each period, so the real rate is slightly
under 10Hz on a low frame rate. Cosmetic here, but worth a comment if it is deliberate.

**Reachability:** *Any player who has ever enabled mouseover fade on a panel and later turned it
off — the driver survives the panel that created it, for the session.*

**Cited as unverified.** `docs/performance.md` records a ratified `performance-§1` decline, so there
is no `tests/perf.lua` scenario and no `docs/perf-analysis/` capture to put a number against this.
The claim above is read off the source, **not measured** (see F-009).

**Fix direction.** In `Canvas.SetMouseoverTracked`, clear the script when the tracked set empties and
re-install it in `ensureMouseoverDriver`. Keep the frame — creating it once is right.

---

## Low

### F-007 — the descriptor's rationale for declining `skipRestoreAll` describes an implementation that no longer exists
`settings/OptionsSetup.lua:190-195` — `[naming]` `[docs]`

**Problem.** The `DELIBERATELY NOT PASSED` block says the library's `RestoreAllDefaults` was rejected
because this addon's global reset *"must ALSO reach the session-only rows (unlock, preview, the
console) through each row's own `set`"*. That described the **old** row-walk. Since
`000273a "Adopt options-ui-§12"` the reset is `Sl:DoResetAll` — `db:ResetProfile()` and a print
(`settings/Slash.lua:31-35`) — which touches no schema row at all, session-only or otherwise.
(The outcome is still largely right: `OnProfileReset` reaches `dropSessionIDs`, which clears
`NS.State.preview` and `unlockedPanels` at `modules/Registry.lua:559-561`. The debug console and the
global unlock flag are deliberately left alone.)

**Impact.** The decision is still correct; its stated reason is not. A future reader checking whether
the library's version would now be adequate will test the wrong proposition.

**Reachability:** *A comment; no runtime effect.*

**Fix direction.** Restate the reason as what it actually is — a global reset here is a **profile**
reset (`options-ui-§12`), and the library's row walk is a different act — and note where the
session-only state is actually cleared.

### F-008 — `docs/automated-tests/RESULTS.md` no longer describes this tree
`docs/automated-tests/RESULTS.md` (newest row `20260825-103450`) — `[docs]` `[tests]`

The newest recorded run predates the whole `feat/settings-revamp-v2` merge. Recorded: 731/731 tests,
11223 NLOC, 1379 functions. Today: **763/763, 12122 NLOC, 1472 functions** (commands and full output
in the Measurement run block above). Max CCN is 15 in both, and both are at zero warnings, so the
watch list itself has not moved — only the totals. The record's own prose (*"It becomes worth a
second look the moment shipped source moves and this number does not"*) is the right instinct
pointed the other way here: the source moved and the record did not follow it.

Stale is stale, not non-compliant — regeneration belongs to `/wow-addon:bump-version` at release, and
nothing in this bundle regenerated it.

**Reachability:** *A reader of the record; no runtime effect.*

### F-009 — no zero-overhead evidence exists for the one polled path, by ratified decision
`modules/Canvas.lua:642-653`, `docs/performance.md` — `[perf]` `[unverified]`

The `performance-§1` decline is ratified and documented, and this review does not re-litigate it.
What follows from it, and is worth stating once: the addon **does** ship a repeating `OnUpdate`
(F-006), and there is no offline scenario and no committed capture that puts a number on it. Every
perf statement in this bundle is therefore read off source rather than measured. If the mouseover
driver ever grows past a `MouseIsOver` call per tracked panel, that is the point at which the
declined harness stops being free.

**Reachability:** *Evidence-quality note; no runtime effect.*

### F-010 — five tracked text files are LF in a tree pinned `eol=crlf`
`settings/Slash.lua`, `tests/test_slash.lua`, `tests/wow_mock.lua`, `docs/revendor/2026-08-25/05_SUMMARY.md`, and `docs/revendor/2026-08-25/01_DELTA.md` (mixed) — `[line-endings]`

`.gitattributes` pins `* text=auto eol=crlf` with the `*.sh text eol=lf` carve-out and the binary
markings — the correct client-bound variant, and the carve-out is honoured
(`tests/_kit/run-automated-tests.sh` is `w/lf` as intended, `tools/artwork/bin/models/*.param` is
`attr/-text`). Five other tracked files disagree with the pin in the working tree:

```
$ git ls-files --eol | grep -E 'w/lf|w/mixed'
i/lf  w/mixed  attr/text=auto eol=crlf   docs/revendor/2026-08-25/01_DELTA.md
i/lf  w/lf     attr/text=auto eol=crlf   docs/revendor/2026-08-25/05_SUMMARY.md
i/lf  w/lf     attr/text=auto eol=crlf   settings/Slash.lua
i/lf  w/lf     attr/text eol=lf          tests/_kit/run-automated-tests.sh   <- correct
i/lf  w/lf     attr/text=auto eol=crlf   tests/test_slash.lua
i/lf  w/lf     attr/text=auto eol=crlf   tests/wow_mock.lua
```

Scope of that count: every tracked path in the repo, `libs/` and `tests/_kit/` included. The index
side is LF throughout, which is correct — the divergence is checkout-side only, and
`settings/Slash.lua` is a file that ships to the client.

This is recorded here as a **review observation**. The authoritative sweep, with its rolled-up
straggler count, belongs to `/wow-addon:standards-audit` (`line-endings-§2`).

**Reachability:** *Working-tree only; git stores LF and re-normalises on the next `add`. No runtime
effect.*

---

## Upstream

### F-011 — `[upstream]` two LibKa0s source files are LF in a CRLF-pinned repo, so a naive vendor diff reports false drift
`../LibKa0s/LibKa0s/DebugLog.lua`, `../LibKa0s/LibKa0s/Pool.lua` — owning repo: **LibKa0s** — `[upstream]` `[line-endings]`

**Problem.** Today's vendor-sync `diff -r libs/LibKa0s/ ../LibKa0s/LibKa0s/` reports both files as
differing in their entirety (`1,793c1,793` for `DebugLog.lua`). After stripping CR from both sides
the diff is empty: the vendored copies are CRLF (correct, per this repo's pin) and the **source**
copies are LF. `file` confirms it — `../LibKa0s/LibKa0s/DebugLog.lua: … UTF-8 text` against
`libs/LibKa0s/DebugLog.lua: … with CRLF line terminators` — while `Core.lua` is CRLF on both sides.

**Impact.** No behavioural effect in this addon; the bytes are identical and the in-suite
`test_vendor_sync` cases pass because the kit normalises. The cost is on the human path: a
maintainer running the documented `diff -r` sees two whole-file differences and has to work out that
they are not drift. That is exactly the signal the vendor-sync check exists to make trustworthy.

**Reachability:** *A maintainer running the vendor-sync diff by hand. No runtime effect in any
install.*

**Fix direction — NOT a local edit.** Nothing under `libs/` may be touched: the next whole-folder
re-vendor overwrites it, and the reversion would appear as a regression with no commit behind it.
Fix in the **LibKa0s** repo — normalise those two files against that repo's own `.gitattributes` pin
(`git add --renormalize .` there) — and let the correction reach consumers on the next scheduled
re-vendor. **No minor bump is warranted**: no source line changes, so `DebugLog.lua`'s LibStub minor
stays at 12 and `Pool.lua`'s stays where it is. There is nothing for this repo to do until then.

---

## Notes that are deliberately *not* findings

- **No taint, secret-value or protected-API finding.** Every panel is a non-secure frame; the only
  combat gating is the unlock overlay, which defers to `PLAYER_REGEN_ENABLED`
  (`modules/Unlock.lua:238-243`, replayed at `core/PanelMaster.lua:92-95`), and the settings open
  refuses under lockdown without replaying (`settings/Panel.lua:529`) — the `options-ui-§2` shape,
  correctly distinguished from the `events-frames-taint-§2` one in the code's own comments.
- **No deprecated-API finding.** `C_AddOns.*` is preferred with a guarded legacy ladder
  (`core/Compat.lua:29-35`), `BackdropTemplate` is used, and `Settings.RegisterCanvasLayoutSubcategory`
  is the modern registration.
- **No `COMMANDS`-dispatcher mismatch.** Every entry in `NS.COMMANDS` is reachable through the
  library dispatcher or the degraded one (`settings/Slash.lua:374-379`), and the descriptor does not
  double-register the slash (the library registers nothing; `Sl:Register` at `settings/Slash.lua:81`
  is the only registrar).
- **No single-write-path bypass.** `grep -rEn 'db\.profile\.[A-Za-z.]+ *=[^=]' core modules settings`
  returns nothing; every settings mutation goes through `NS.Schema:Set` (`settings/Schema.lua:335`),
  and panel records are the documented `architecture-§5` storage carve-out owned by `NS.Registry`.
- **No unfalsifiable-test finding.** The negative assertions sampled (`tests/test_canvas.lua:33-35,
  357-376`, `tests/test_unlock.lua`) assert on values a real code path produced, and eleven cases
  carry an explicit `-- red under:` note naming the mutation that reddens them. `tests/run.lua`
  derives the addon's load list from the TOC (`:34`) and the library's from `LibKa0s.xml` (`:28`),
  and the suite list is inventory-gated in both directions (`:59-62`) — none of `testing-§9`'s rot
  modes are open here.
- **No drawn-mark finding.** `grep` finds no word, Unicode glyph or Blizzard atlas standing in for a
  shipped mark, `addonName` is passed to both `MakeCloseButton` (`core/CoreSetup.lua:118-120`) and
  the DebugLog descriptor (`core/DebugLogSetup.lua:171`), and `media/` holds no copy of a library
  asset (no `media/fonts/`, no `media/icons/`).
- **The `NS.L` seam is unused by design** (`locales/enUS.lua:8-11`) — an explicit 1.0.0 scope
  decision, and both seam files correctly refuse to hand `NS.L` to a library descriptor
  (`core/DebugLogSetup.lua:219-222`, `settings/Slash.lua:420-425`), which the suite tripwires.
