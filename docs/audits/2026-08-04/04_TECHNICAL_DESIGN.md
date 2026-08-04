# 04 — Technical design (2026-08-04)

Remediation design for the deviations in `02_DEVIATIONS.md`. This document says **how** to close
each gap; `05_EXECUTION_PLAN.md` says in what order. Nothing here has been applied — the audit is
read-only.

The work falls into four independent tracks. Only Track A has meaningful internal ordering.

---

## Track A — Adopt `LibKa0s-Perf-1.0` (PM-001, PM-002, PM-003, PM-004, PM-005, PM-006, PM-012)

This is one change with seven deviation IDs hanging off it, because the standard's
`performance-§1` adoption-strength paragraph makes the five wiring pieces a single unit: vendor the
lib (already done), create the instance, expose the verb, declare the SV global, implement
suspend/resume.

### A first decision that is the user's, not the engineer's

`CLAUDE.md:34` and `docs/pending/LEDGER.md:117` record `Perf` as **declined**, with a real argument:
PanelMaster registers only `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD` and `PLAYER_REGEN_ENABLED`, none
of which fires during combat, and every repaint is driven by a settings change or a panel edit — both
of which require the options panel to be open, which `options-ui-§2` refuses in combat. Nearly every
bucket would read `0.000` by construction.

`CLAUDE.md`'s own standards-compliance clause says such a case is classified by the user as either
**(a)** an accepted deviation recorded with its reason, or **(b)** a change to the standard made
upstream. **Do not begin Track A until that call is made**, because the two outcomes have completely
different work:

- **(a) accepted deviation** — no code changes. The ledger row and `CLAUDE.md` already carry the
  reasoning; add a pointer from this audit bundle and from `docs/ARCHITECTURE.md` so the next audit
  finds the classification without re-deriving it, and close PM-001 … PM-006 and PM-012 as
  *accepted*. Roughly an hour.
- **(b) standard change** — the argument ("an addon with no combat-time code path wires the harness
  anyway, or is exempted") lands in `WowAddonStandards` as an amendment to `performance-§1`'s
  adoption strength, after which this addon follows whatever the amended rule says.
- **(c) implement** — the design below.

The design assumes (c). If (a) or (b) is chosen, Track A collapses to a documentation change and the
rest of this document still stands.

### A1 — `core/PerfSetup.lua` (PM-001, PM-012)

New file, modeled exactly on the three seams the addon already has, because their shape is proven
here and reviewers already know how to read them.

```lua
local addonName, NS = ...

local UNAVAILABLE = NS.LIBKA0S_MISSING .. ", so performance capture is unavailable."

local lib = LibStub and LibStub("LibKa0s-Perf-1.0", true)

if not lib then
  -- member-answering stub: `on` (the hot-path gate), `Note` (the sink), and every member the
  -- slash layer and the show-decision ladder touch.
  local said = false
  local function explain() if not said then said = true; NS.Print(UNAVAILABLE) end end
  NS.Perf = {
    on = false,
    Note = function() end,
    suspended = false,
    Command = function() explain(); return {} end,
    ...
  }
  return
end

NS.Perf = lib:New({
  name    = addonName,
  version = function() return NS.Slash:Version() end,
  svName  = "PanelMasterPerfDB",
  print   = function(line) NS.Print(line) end,
  debug   = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end,
  buckets = { ... },          -- see A2
  suspend = function() ... end,   -- see A3
  resume  = function() ... end,
})
```

**Stub coverage is the part to get right**, and the addon's own house rule is the method: derive the
member list by grepping the call sites (`grep -rn "NS\.Perf" core modules settings`) once the
brackets exist, and confirm the library-absent branch answers every one. A stub missing a member is
a crash relocated, which is exactly the defect PM-007 documents in the slash seam.

**TOC placement.** In the `# Core` block, after `core/CoreSetup.lua` (the descriptor's `print`
forwarder) and after `core/DebugLogSetup.lua` (the `debug` forwarder), and **before**
`modules/Canvas.lua`, which will take `local Perf = NS.Perf` as a load-time upvalue. Follow the
existing comment convention in `PanelMaster.toc:42-48` — every ordering constraint in that file is
written down beside the line it constrains.

### A2 — Buckets and brackets (PM-001, `performance-§2/§3`)

The honest answer here is **few buckets**, and the ledger row is right that most of the addon's work
is not combat-time. The declared set should be exactly what a real bracket reaches, because
`performance-§3` makes a bucket no bracket reaches "a lie in every report":

| Bucket | `within` | Entry point |
|---|---|---|
| `renderAll` | — | `Canvas:RenderAll()` — the coalesced pass over every panel |
| `renderPanel` | `renderAll` | `Canvas:Render(rec)` — the per-panel work inside it |
| `mouseoverTick` | — | the 10 Hz shared mouseover ticker, `modules/Canvas.lua:459-486` — the addon's only genuinely repeating path |

The bracket idiom is mandated verbatim and must not be paraphrased:

```lua
local Perf = NS.Perf                       -- load-time upvalue, never an NS lookup
local t0 = Perf.on and debugprofilestop()
-- ... work ...
if t0 then Perf.Note("renderPanel", debugprofilestop() - t0) end
```

Nothing else may appear inside a bracket while capture is off — no key building, no table, no format
string (anti-pattern #43). The mouseover ticker is the one place where this actually matters, so it
is also the one to inspect hardest in review.

### A3 — Suspend / resume (PM-012)

`performance-§6` requires the addon to go **inert without a `/reload`**, and to enforce that **at the
source** rather than by hiding frames — which matters here, because `Canvas:RenderAll` re-shows
panels on a settings change, a profile switch or `PLAYER_ENTERING_WORLD`, and would walk straight
back over an imperative hide.

- `suspend`: unregister the addon's three events, cancel any queued `ScheduleTimer` work, stop the
  mouseover ticker, and set a session-only `NS.State.perfSuspended`.
- The **show decision** in `Canvas` gains one early return on that flag. That is the load-bearing
  line: it is what makes suspend survive a repaint.
- `resume`: rebuild registrations from the enabled set **as it is now**, not from a snapshot, then
  `Canvas:RenderAll()`.
- The flag is **never** persisted, and resume runs **before** any save or report.

**Risk.** A stray early return in the renderer's show ladder is a "my panels vanished" bug for every
user, not just one running a capture. It must be gated on a session-only flag that is `false` at
load, and it must be covered by a test that asserts the ladder refuses only while suspended.

### A4 — The `perf` verb (PM-002)

One positional triple in `NS.COMMANDS` (`settings/Slash.lua:202-255`), placed beside `debug` so the
two diagnostic verbs read together:

```lua
{ "perf", "Measure performance — try `/pm perf` for the workflow",
  function(rest) for _, line in ipairs(NS.Perf:Command(rest)) do NS.Print(line) end end },
```

The library returns lines; the **host** prints them through its tagged printer. The library must not
register a chat command. A bare `/pm perf` opens the guided step panel, it does not merely print a
status line.

Two ripples that must land in the same change, because both are generated from `NS.COMMANDS`:
`/pm help` and the settings landing page pick the verb up automatically, but the README's
`### Slash commands` table (`README.md:72-125`) is hand-maintained prose and must gain the row.

### A5 — `PanelMasterPerfDB` (PM-003) and lint (PM-006)

- `PanelMaster.toc:7` → `## SavedVariables: PanelMasterDB, PanelMasterPerfDB` (that order).
- The ring's **name** goes to the descriptor; the library owns the ring, the schema stamp and the
  bound (default 10). It stays outside the AceDB tree by construction — nothing in `core/Database.lua`
  changes.
- `.luacheckrc`: `"debugprofilestop"` into `read_globals` (the bracket call sites are addon code and
  *are* linted, even though the lib under `libs/` is not), `"PanelMasterPerfDB"` into `globals` with a
  comment, matching the existing `PanelMasterDB` line's style.

### A6 — `tests/perf.lua` (PM-004) and the integration suite

`tests/perf.lua` runs as `lua tests/perf.lua`, is **not** called by `tests/run.lua`, and asserts only
on deterministic quantities — API call counts and bytes allocated per iteration, isolated by a full
`collectgarbage("collect")` either side of the measured loop. **Never** on wall-clock time.

Its mandatory scenario is **zero-overhead**: run `Canvas:Render` with capture off and pin that it
allocates no more than the same path with the instrumentation absent. That measurement is the
*required evidence* for the bracket rule; without it, "free when off" is an unverified claim.

Its load list is TOC-derived like the runner's (`testing-§9`), and because it is outside the gate,
that derivation is pinned by a case in the gated suite that **reads its source** for the derivation
call.

Per `testing-§8`, the gated suite gains a small integration set — not a duplicate of the library's
coverage, which lives in the library repo:

- the descriptor is well-formed and `NS.Perf` exists;
- **every declared bucket is reached by a real bracket**, driving each bucket's genuine entry point;
- suspend genuinely makes *this* addon inert — events unregistered, ticker stopped, show ladder
  refusing — and resume restores from current state;
- the degraded path, verified by **actually loading the addon with `Perf.lua` absent** from the load
  list, never by hand-stubbing `NS.Perf`.

Each negative assertion (a bucket *not* counted, the ladder *not* showing) must be proved falsifiable
by mutation, with the mutation named in a one-line comment — `testing-§12`. Take a `cp` backup before
mutating; never `git checkout` a file mid-change.

### A7 — Docs (PM-005)

- `docs/performance.md` — which paths are bracketed and why, how to run a capture, how to read the
  report, and what the harness can and cannot resolve for *this* addon. It **points at** the library's
  protocol and record contract rather than restating them.
- `docs/perf-runs/README.md` — the standing capture store: naming (`<YYYY-MM-DD>-<source>-<label>.json`),
  a schema summary, and a pointer to the library's canonical field-by-field contract. The directory is
  cumulative, not tied to one investigation.
- `docs/testing.md` gains a line for the ungated runner beside the existing artwork gate note, which
  is where this repo already documents its out-of-gate checks.

---

## Track B — Close the slash degradation stub (PM-007)

**The smallest change in the bundle and the highest-value one**, because it is a live crash rather
than a missing feature: a user whose `libs/LibKa0s` failed to install gets an error the moment they
type `/pm panel <name>`.

The fix is one assignment **inside** the stub branch of `settings/Slash.lua` (before the `return` at
`:304`):

```lua
  -- Deliberately NOT the library's styled formatter and NOT a copy of its color escapes
  -- (slash-commands-§1 forbids re-implementing the rendering in a stub). A degraded line renders
  -- plainly, which is also how a user can tell the library is missing.
  Sl.FormatKV = function(k, v) return tostring(k) .. " = " .. tostring(v) end
```

**The tempting wrong fix is `Sl.FormatKV = lib.FormatKV` hoisted above the branch, or a hand-copy of
the library's `|cFFFFFF00…|r` escapes.** Both are anti-pattern #47 — hand-copying the exact strings
whose drift the extraction exists to end. Guard against it with a case asserting the degraded
formatter is **not** the library's function value, which goes red the day someone "fixes" it that way.

Tests to add, both in the degraded block at `tests/test_libka0s.lua:480+`:

1. every `/pm panel` verb answers in a degraded install — `CliPanel`, `BuildPanelShowLines`,
   `CliPanels`, `fitart` — driven through the real `loadDegraded()` environment, not a hand-built stub;
2. the degraded `FormatKV` is a different function value from `lib.FormatKV`.

Case 1 goes **red before the fix** — the probe in `03_EVIDENCE.md` §4 is exactly that case in
miniature — which is the correct TDD order and also the falsifiability proof `testing-§12` wants.

**Risk:** none to the library-present path, which does not execute the stub branch at all.

---

## Track C — Printer call sites (PM-008)

~22 chat sites plus 3 debug sites, listed in `03_EVIDENCE.md` §6. Purely mechanical, but large
enough that it wants its own commit so the diff is legible.

The shape is already established by `NS.Debug(tag, fmt, ...)`, which defers formatting behind the
gate. Chat call sites converge on the same idea: pass the format string and its arguments separately
and let the printer's stringifier handle each vararg.

```lua
-- before
print(("deleted %d %s."):format(n, n == 1 and "panel" or "panels"))
print("error: " .. tostring(err))
-- after
print("deleted %d %s.", n, n == 1 and "panel" or "panels")
print("error: %s", err)
```

**A prerequisite that must not be skipped.** `NS.Print` today takes a single already-built line on
both paths — `LibKa0s-Core-1.0`'s printer factory and the fallback at `core/CoreSetup.lua:55-66`. If
the library's printer does **not** already accept a format-plus-varargs form, this track **must not**
be implemented by wrapping it locally: that is a host-side re-implementation of a library seam
(anti-pattern #47). The correct move is an **additive** descriptor/API change pushed upstream into
`LibKa0s-Core-1.0`, re-vendored into every consumer — `library-stack-§7` says a floor bump is a
re-vendor trigger and must be called out as one in the changelog.

**Therefore: establish the library's supported shape first.** If Core already supports varargs, this
is a same-day sweep. If not, Track C is blocked on a LibKa0s release and should be scheduled after
it, not before.

The three debug sites are unconditionally safe to fix now — drop the redundant `tostring()` wrappers
and let the sink's `safeToString` do its job:

```lua
-- settings/Schema.lua:144
NS.Debug("Set", "%s = %s", path, value)
```

Order within the sweep: fix the sites, then add one test that a secret-shaped value (the suite's
mock can produce one that raises in `table.concat`) routed through each surviving surface renders
`<secret>` instead of raising. That test is what stops the next call site regressing.

**Risk:** low but not zero — a mis-transcribed format string prints garbage rather than erroring.
The 696-case suite covers most of these surfaces' output text already; run it after every file.

---

## Track D — Documentation (PM-009, PM-010, PM-011)

Independent of everything above and safe to land first.

- **PM-009** — `README.md:489-493`: add the **Date** column and rename `Notes` → `Highlights`.
  `0.1.0`'s date is the first release date; leave it as the release date once known rather than
  back-dating it to a commit. Keep most-recent-first.
- **PM-010** — `README.md:143`: insert a `| Tab | Covers |` table above the existing per-setting rows
  (`General` — the addon-level settings; `Panels` — the per-panel editor; `Profiles` — AceDBOptions,
  if that page ships). Keep the per-setting table beneath it; `documentation-§1` explicitly permits
  per-panel prose after the table.
- **PM-011** — run `lizard` over the addon's own source excluding `libs/`, commit as
  `docs/complexity.md`, and state in the file that it is generated and by what command. It is a
  **report**, never a commit gate. If `lizard` is not installed locally, that makes the report
  absent rather than the addon non-compliant — but the two 1000+ LOC files make it worth having.

Documentation drift is the standard's own stated #1 audit gripe, so all three land with a
`docs+readme:` commit and no code alongside them.

---

## Cross-cutting constraints

- **Green gate on every commit** — `lua tests/run.lua` (696+ passing) and `luacheck .` (0/0). PM-006's
  `.luacheckrc` additions must land in the *same* commit as the first `debugprofilestop` bracket, or
  lint goes red between commits and `versioning-git` forbids committing there.
- **Never edit `libs/` or `tests/_kit/`.** Track C may surface a library need; it goes upstream to
  `../LibKa0s` and comes back as a re-vendor commit that stands alone (`library-stack-§7`).
  `tests/test_vendor_sync.lua` will go red the moment a local edit happens, which is the intended
  behavior.
- **Test-inventory lockstep** — every track that adds a case must regenerate `docs/test-cases.md`
  (`lua tests/run.lua --list > docs/test-cases.md`) and update the README `[tests]` badge in the
  **same** change (`testing-§5`).
- **`tests/perf.lua` scenarios are not test cases** and must not be counted in either the inventory
  or the badge (`testing-§7`).
