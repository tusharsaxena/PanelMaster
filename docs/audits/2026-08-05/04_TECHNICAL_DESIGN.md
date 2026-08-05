# 04 — Technical design (2026-08-05)

Remediation design for the deviations in `02_DEVIATIONS.md`. Keyed by deviation ID. This document
designs the change; it does not make it — the audit is read-only and remediation is a separate
engagement.

The run's shape is dominated by one decision: **`LibKa0s-Perf-1.0` was vendored and declined.**
Seven of the ten MUST deviations (`PM-001` … `PM-006`, `PM-012`) are that one omission seen from
seven sections, and they must land as one coherent workstream or not at all — half a perf adoption
is worse than none, because a declared bucket no bracket reaches "is a lie in every report"
(`performance-§3`). The remaining three MUSTs (`PM-007`, `PM-017`, `PM-018`) are small, independent
and can land first.

---

## A. The Perf adoption (PM-001, PM-002, PM-003, PM-004, PM-006, PM-012, and PM-017 as its prerequisite)

### A.0 Prerequisite — the runner's library load list (PM-017)

**File:** `tests/run.lua:24-31`, `tests/test_harness.lua`.

Append `"libs/LibKa0s/Perf.lua"` and `"libs/LibKa0s/PerfPanel.lua"` to the `Loader.loadAll` list, in
`LibKa0s.xml` order (after `OptionsScroll.lua`). Then close the hole permanently: add a case that
parses `libs/LibKa0s/LibKa0s.xml` for its `<Script file="…"/>` entries and asserts the runner's
library list equals that sequence, in order. `tests/test_harness.lua` already pins the *addon*
half of the load list against the TOC; this is the missing library half.

**Why first.** Without it, every case written for A.1–A.5 would exercise the **stub** rather than
the library — `Perf.lua` returns before `LibStub:NewLibrary` when its Core floor is unmet, so the
setup file's degraded branch takes over and the suite goes green having tested nothing
(`testing-§9`'s second failure mode, verbatim). This is a two-line change that decides whether the
rest of the workstream is real.

**Risk:** loading two more library files changes nothing at runtime but does add their file-scope
side effects to the harness environment. Expect the case count to be unchanged and the suite to stay
green; if it does not, that is a genuine finding about the mock, not about this change.

### A.1 `core/PerfSetup.lua` (PM-001)

**New file**, listed in the TOC's `# Core` block **before** any module that would take
`local Perf = NS.Perf` as a load-time upvalue. The natural slot is immediately after
`core/DebugLogSetup.lua` and before `core/PanelMaster.lua`, matching the file's own placement
comment style: it needs `NS.PREFIX`, `NS.Print` (via a call-time closure) and `NS.LIBKA0S_MISSING`,
all of which `core/CoreSetup.lua` has published by then.

Shape, following the three seams already in the repo exactly:

```lua
local addonName, NS = ...
local UNAVAILABLE = NS.LIBKA0S_MISSING .. ", so performance capture is unavailable."
local lib = LibStub and LibStub("LibKa0s-Perf-1.0", true)
if not lib then
  -- member-answering stub: every member the addon calls
  ...
  return
end
NS.Perf = lib:New({ ... })
```

**Descriptor fields:** `name`, `svName = "PanelMasterPerfDB"`, `print` (call-time closure over
`NS.Print`, matching `core/DebugLogSetup.lua:169`), `debug`/log routing through the console sink
(`debug-logging-§12`), `version`, `buckets` (A.2), `suspend`/`resume` (A.4), and a `showLog` hook so
the harness can reveal the console at the moments that warrant it. Every omitted field gets a
`DELIBERATELY NOT PASSED` comment, which is this repo's established and good habit
(`core/DebugLogSetup.lua:186-204`, `settings/OptionsSetup.lua:112-131`).

**The stub is member-answering, not load-completing.** The Options stub's exception does not apply
here: nothing calls a Perf member inside a file-load literal. Enumerate the member set the same way
the other stubs did — grep the call sites — and answer **all** of them, including the hot-path gate
field. The gate **must** be a plain boolean field (`Perf.on = false`) and the sink a plain
dot-callable no-op, so a bracket costs one upvalue read, one field read and one boolean test in the
degraded build too (`performance-§2`).

### A.2 Buckets and brackets (PM-001 continued)

The addon's genuine hot paths, from `01_CURRENT_STATE.md`'s reading of the renderer:

| Bucket | Entry point | Nesting |
|---|---|---|
| `renderAll` | `modules/Canvas.lua` `Canvas:RenderAll` | — |
| `renderPanel` | `Canvas:Render` / the per-record path | `within = "renderAll"` |
| `applySpec` | `applySpec(f, spec)` | `within = "renderPanel"` |
| `mouseoverTick` | `updateMouseover` (`modules/Canvas.lua:545-558`) | — |

`mouseoverTick` is the one that actually matters: it is a 10 Hz ticker walking every faded panel, and
it is the only per-frame path the addon has. `renderAll` is structural (create/delete/rename/settings
change), which makes it the useful denominator rather than a hot path in its own right.

**Constraint (`performance-§3`):** every declared bucket must be reached by a real bracket, pinned by
a test. Declare exactly these four; do not declare a bucket for a path that runs twice a session.

**Constraint (anti-pattern #43):** the bracket is `local t0 = Perf.on and debugprofilestop()` … `if
t0 then Perf.Note(key, debugprofilestop() - t0) end`, with `Perf` a **load-time upvalue** in each
module — never an `NS.Perf` lookup inside the loop. `modules/Canvas.lua` already takes module-level
upvalues, so this is idiomatic there.

### A.3 `PanelMasterPerfDB` (PM-003, PM-006)

- `PanelMaster.toc:7` → `## SavedVariables: PanelMasterDB, PanelMasterPerfDB` (that order).
- `.luacheckrc` `globals` → add `"PanelMasterPerfDB"` with a one-line comment beside the existing
  `PanelMasterDB` comment.
- `.luacheckrc` `read_globals` → add `"debugprofilestop"` with the `performance-§2` reason.
- The ring stays **outside** the AceDB tree; the library writes it from the name in the descriptor.
  Nothing in `core/Database.lua` changes.

Land these three edits in the **same commit** as A.1 so `luacheck .` stays 0/0 throughout: adding
`debugprofilestop` before any bracket exists is harmless, but adding a bracket before the
`read_globals` entry is a lint failure.

### A.4 Suspend / resume (PM-012)

The contract is the host's, and it has one hard rule: enforce inertness **at the source**, never by
hiding frames (`performance-§6`).

- **Suspend:** unregister the addon's events (`PLAYER_ENTERING_WORLD`, `PLAYER_REGEN_ENABLED`, and
  the renderer's three bus subscriptions on `Canvas.__ev`), cancel the mouseover ticker, and set a
  session-only `NS.State.suspended` flag that `Canvas`'s show decision consults — so a settings
  change, a profile switch or a combat transition **cannot** re-show a panel behind suspend's back.
- **Resume:** rebuild from **current** state — re-register events, restart the ticker from the
  enabled set as it is now, and `Canvas:RenderAll()`. Not from a snapshot taken at suspend.
- **Never persist the flag.** `core/State.lua` is exactly the right home: it already documents
  "nothing here is ever persisted".
- **Resume before saving or reporting** when a run ends, so a formatting error cannot strand the
  addon inert until `/reload`.

The show-decision hook is the delicate part. `modules/Canvas.lua`'s render path currently decides
visibility from `rec.enabled` and the master switch; the suspended check belongs in that same ladder,
as one more early return, not as a `frame:Hide()` sweep.

### A.5 `/pm perf` (PM-002)

Add one triple to `NS.COMMANDS` (`settings/Slash.lua:214-267`), between `recover` and `version` so
the help index reads sensibly:

```lua
{ "perf", "Measure performance — try `/pm perf` for the workflow",
  function(rest) … end },
```

The handler calls the library's command entry point, which **returns lines**, and prints them
through `NS.Print` (`performance-§4`). The library must not register a chat command. A bare
`/pm perf` opens the guided step panel and prints the current phase — it is the entry point to a
run, not a status line.

The panel is the library's frame; per `debug-logging-§12` it is decorated through
`LibKa0s-Core-1.0`'s `MakeCloseButton`/`ApplySkin` reached **through Core itself**. Note that
`core/CoreSetup.lua:94-98` currently and deliberately does not re-export Core's chrome half, with
the stated reason "a host-side re-export would have no caller" — that reason expires here, and
`NS.Core` (`:72`) is already the seam the comment says it is. The addon should pass **no**
`applySkin` hook and let the library's own default draw it, for the same reason the console does.

### A.6 `tests/perf.lua` (PM-004)

**New file**, run as `lua tests/perf.lua`, **outside** the green gate and never called from
`tests/run.lua`.

- Load list derived from the TOC via `Loader.tocFiles` (`testing-§9`), with the library files spelled
  out — the same list A.0 fixes in `tests/run.lua`. Because this runner is ungated, the derivation is
  pinned by a case in `tests/run.lua` that **reads `tests/perf.lua`'s source** for the
  `Loader.tocFiles` call.
- **Assertions on deterministic quantities only** — API call counts and bytes allocated per
  iteration, isolated by a full `collectgarbage("collect")` either side of the measured loop. **No
  wall-clock assertion.**
- **The zero-overhead scenario is the point of the file:** run `updateMouseover` over N panels with
  `Perf.on = false` and pin that it allocates no more than the same loop with the brackets absent.
  That number is the evidence `performance-§2` requires; without it "free when off" is a comment.
- Scenario output states plainly that timings are for orientation only.

### A.7 `docs/performance.md` and `docs/perf-runs/README.md` (PM-005)

- **`docs/performance.md`** — which paths are bracketed and why (the four buckets and their nesting),
  how to run a capture (`/pm perf`, the two-arm protocol, why both arms must be the same session and
  the same load order), how to read the report, and what the harness can and cannot resolve. It
  **points at** the library's canonical record contract rather than restating it.
- **`docs/perf-runs/README.md`** — the naming convention `<YYYY-MM-DD>-ingame-<label>.json`, a schema
  summary, a pointer to the library's field-by-field contract, and the sentence that offline runs
  live in `docs/automated-tests/`. This also fixes the already-dangling link at
  `docs/automated-tests/README.md:44`.

Both are release-checked docs (`documentation-§5`), so they land with the workstream rather than
after it.

---

## B. The slash degradation stub (PM-007)

**File:** `settings/Slash.lua:285-317`.

Publish, inside the stub branch:

```lua
-- The library's FormatKV is assigned at the bottom of this file, on the LIVE path only, so the five
-- host panel verbs above (:101, :124, :125, :181, :188) would call nil here. A deliberately PLAIN
-- formatter — no color escapes, because slash-commands-§1 forbids the stub re-implementing the
-- library's rendering, and because a degraded line SHOULD look degraded.
function Sl.FormatKV(key, value) return tostring(key) .. " = " .. tostring(value) end

-- Sl.Text is NOT published. It has no production caller (only tests/test_libka0s.lua), and a stub
-- member nothing calls is surface to maintain for nothing. Recorded here so the omission reads as a
-- decision rather than the same oversight FormatKV was.
```

Two properties matter and both are testable:

1. **It is a plain function, not a copy of the library's escapes.** A test asserts the degraded
   `Sl.FormatKV` is **not** `lib.FormatKV` and that its output contains no `|c` sequence.
2. **The crash is gone.** A test drives a **real** degraded load — feed the loader a partial file
   list with no `libs/LibKa0s/*`, exactly as `03_EVIDENCE.md` §6 does — creates a panel and runs
   `/pm panel <name>`, asserting it does not raise. `testing-§8` is explicit that the degraded path
   is verified by loading the addon with the module missing, **not** by hand-stubbing the member.

**Wider gap this exposes.** The suite carries a degradation member-sweep for **DebugLog** only. The
same sweep should exist for **Slash** and **Options**: enumerate the members each live path
publishes, load degraded, and assert that every member the addon's own source calls is answered.
That case is what makes PM-007 unrepeatable; the fix alone is not.

## C. The vendored runner's executable bit (PM-018)

```
git update-index --chmod=+x tests/_kit/run-automated-tests.sh
```

One index change, no content change. Then add `chmod +x tests/_kit/run-automated-tests.sh` to the
re-vendor steps in `docs/testing.md` ▸ *The vendor gate*, because `cp` does not reliably carry the
bit and the next re-vendor would drop it again (`automated-tests-§2`).

Consider extending `tests/test_vendor_sync.lua` with a case asserting the mode via
`git ls-files -s`; it is one `io.popen` and it removes the "next re-vendor" risk entirely.

## D. Documentation (PM-019, PM-010)

### D.1 The release gate (PM-019)

Add a *"The release gate"* subsection to **`docs/automated-tests/README.md`** and a matching
paragraph to **`docs/testing.md`**, immediately after each file's existing "what gates" table so a
reader cannot get the first half without the second:

- At the **tag**, all four suites must be `pass` and `suites.complexity.warnings` must be `0` —
  i.e. no function above CCN 15.
- A **`skip` is not a pass**; it blocks as NOT EVALUATED.
- It is evaluated by `/wow-addon:bump-version` reading the run's `manifest.json` — **not** by the
  runner's exit code, which is deliberately unchanged because the same script is the commit gate.
- Every failed gate is reported, not just the first; nothing is bumped, tagged or pushed on failure.
- **This addon's standing exception:** `perf` is skipped because it ships no `tests/perf.lua`
  (PM-004). That is the one narrow sanctioned case, and it **must be stated in the release notes**
  until PM-004 closes.

Mirror one sentence into `CLAUDE.md` beside the existing release paragraph (`:46-50`), which today
says only that nothing about the bundle may block a **commit**. Keep that sentence — it is correct
and load-bearing — and add the tag half beside it.

If PM-004 lands first, the exception disappears and this text simplifies; write it so that removal is
a deletion rather than a rewrite.

### D.2 README `### Settings panel` (PM-010)

Lead `README.md:138` with:

```markdown
| Tab | Covers |
|---|---|
| General | ... |
| Panels | ... |
| Profiles | ... |
```

then keep the existing per-setting table and prose as the sanctioned follow-on. Nothing is deleted;
a table is added above.

## E. Test honesty (PM-020)

**File:** `tests/test_vendor_sync.lua:104-116`, `:138`, `:144`.

Preferred fix: **fail** when `siblingTag()` cannot resolve, rather than returning. The vendored copy
is the one thing neither `luacheck` nor the rest of the suite can see, and `testing-§11`'s rule for
exactly this shape is that a gate which cannot look must not go quiet.

If a hard failure is unacceptable because contributors legitimately check out `PanelMaster` alone,
then the minimum is: rename both cases to end *"…, or the sibling checkout is absent"*, and emit one
visible line saying which of the two happened. What must not survive is a `PASS` whose name asserts
a comparison that never ran.

While in the file, correct its header: `:110-112` claims `.gitattributes` pins
`* text=auto eol=crlf`, and the repo's `.gitattributes` carries only `*.sh   text eol=lf`
(`git check-attr` reports no `text` attribute on `.lua`). The `gsub("\r\n", "\n")` normalization is
still harmless, but the reason written beside it is not true of this repo.

## F. Small consistency fixes (PM-021, PM-022)

### F.1 One AceGUI resolution (PM-021)

`settings/OptionsSetup.lua:98` already stashes `NS.AceGUI` through the library's `onAceGUI` seam.
Have `settings/Panel.lua:12` and `settings/PanelEditor.lua:7` read `NS.AceGUI` instead of calling
`LibStub` themselves.

`core/LSMPatch.lua:35` is the awkward one: it loads in the `# Core` block, long before
`settings/OptionsSetup.lua`, so it cannot read the stash at file scope. It already resolves at
**call** time inside a function, which is the right shape — change it to prefer `NS.AceGUI` and fall
back to its own `LibStub` call only when the stash is not yet populated, and say so in a comment.
This is a SHOULD, so a deliberate exception documented in place is also an acceptable outcome.

### F.2 A plain degraded ack (PM-022)

`core/DebugLogSetup.lua:137` → print `"debug logging on"` / `"debug logging off"` with no color
escapes. The flag write (`:136`) and `explainOnce()` (`:138`) stay exactly as they are: the stub
must still flip the flag and still acknowledge (`debug-logging-§7`); it just must not do so in the
library's own strings and hexes.

---

## Ordering constraints

1. **PM-017 strictly before PM-001.** Otherwise every perf test measures the stub.
2. **PM-006 in the same commit as PM-001/PM-003.** Lint must stay 0/0 at every commit
   (`testing-§4`), and the `read_globals` entry and the first bracket have to move together.
3. **PM-004 after PM-001/A.2.** There is nothing to measure until the buckets and brackets exist.
4. **PM-005 after PM-002/PM-004.** `docs/performance.md` documents a `perf` verb and a scenario
   runner that must exist first.
5. **PM-019 after PM-004 is decided.** Whether the release-gate text carries the `tests/perf.lua`
   exception depends on whether PM-004 is being closed in the same cycle.
6. **PM-007, PM-018, PM-020, PM-021, PM-022 and PM-010 are independent** of everything above and of
   each other.
7. **Every commit is green** — `lua tests/run.lua` + `luacheck .` (`testing-§4`). The full four-suite
   bundle is a **release** artifact and must not be made a commit gate.

## Risks

- **The perf workstream is the largest change this addon has taken since the LibKa0s adoption**, and
  it touches the renderer's show-decision ladder (A.4), which is the code path every visible bug in
  this addon lives in. `modules/Canvas.lua` has real coverage (`tests/test_canvas.lua`), but the
  suspend ladder is new behavior: it is TDD territory (`testing-§4`), not a refactor.
- **A declared bucket with no bracket is worse than no bucket.** Pin each one
  (`performance-§3`/`testing-§8`) in the same change that declares it.
- **Do not introduce `or`-defaulting** while adding descriptor plumbing over stored settings
  (`savedvariables-§5`, anti-pattern #54). The addon currently has no such pattern; keep it that way.
- **PM-018's mode change is invisible in a content diff.** Verify with `git ls-files -s` after the
  commit, not by looking at the file.
- **PM-007's fix is three lines; its test is the valuable half.** Landing the formatter without the
  real degraded-load case leaves the class of bug alive in the other two stubs.
