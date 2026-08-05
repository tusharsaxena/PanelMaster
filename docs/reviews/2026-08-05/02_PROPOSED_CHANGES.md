# PanelMaster — proposed changes (HLD + LLD), 2026-08-05

Derived from `01_FINDINGS.md`. Standard resolved: **Ka0s WoW Addon Standard v2.21.0 (2026-08-04)**,
fetched from `https://github.com/tusharsaxena/WowAddonStandards`; 25 of 26 section files retrieved
(`standards/standards/tiered-layout.md` 404s upstream — no rule from it was used).

**No entry in this document targets a path under `libs/` or `tests/_kit/`.** No `[upstream]` findings
were raised, so there is no upstream change-set section.

---

## HLD — themes

### T1. A degradation stub must answer every member, and must answer in its own words

Two findings sit on opposite sides of one rule. F-001 is a stub that **omits** a member the addon
calls, which relocates a crash to the rarest code path in the addon. F-003 is a stub that
**re-implements** a member the library owns the wording of, which relocates staleness instead. The
theme is the seam contract itself: *the stub answers everything, and it answers plainly.*

F-007 is the same theme one step out — the Options stub answers `OpenOptionsPanel`, but latches it,
so it stops answering after the first call. A degraded seam is allowed to be quiet about things
nobody asked for; it is not allowed to be quiet about a command the user typed.

*Alternative rejected:* make `FormatKV` unconditional by hoisting a local copy above the branch and
letting the live path overwrite it. Rejected — that is a second implementation of the library's
formatter living permanently in this repo, i.e. F-003's mistake applied to F-001, and
`library-stack-§7` is explicit that a vendored lib's behavior is not re-kept in the consumer.

*Alternative rejected:* add `FormatKV` to `libs/LibKa0s/` fallbacks. Rejected outright — a local edit
under `libs/` is reverted by the next whole-folder re-vendor and comes back as a regression with no
cause in this repo's history.

### T2. A guard that cannot fire is worse than no guard, and so is the test that green-lights it

F-002 (`Schema:Register` inert, and its test unfalsifiable) and F-005 (vendor-sync passing without
verifying) are the same failure: an assertion whose green carries no information. Both are fixed by
making the negative reachable — a probe row that must be reported, and an explicit skip that must be
visible — rather than by loosening anything.

*Alternative rejected:* delete the `assertEqual(S:Register(), 0)` case as vacuous. Rejected —
`testing` forbids weakening or removing a case to change a result; the case becomes real once the
guard does.

### T3. Say what the code does

F-004 (a migration call that cannot migrate), F-009 (a comment naming a deleted file) and F-010 (a
test header asserting a `.gitattributes` pin the repo lacks) are all documentation that outlived its
subject. F-004 is the one with teeth, because the next migration will believe it.

### T4. One name per thing

F-006 (a guard convention broken in one place), F-011 (a message literal beside two constants) and
F-012 (three resolutions of AceGUI) are consistency debt in code that is otherwise disciplined about
exactly this. Small, low-risk, and each removes a way for a later edit to be silently wrong.

---

## LLD — change-set

### C-01 — the Slash stub answers `FormatKV` and `Text` (covers F-001)

**Files:** `settings/Slash.lua`, `tests/test_libka0s.lua`

Inside the `if not lib then` block (`settings/Slash.lua:285-317`), before the `return`:

```lua
  -- The panel verbs above are host-owned and untouched by the library's absence, but they format
  -- through Sl.FormatKV — so a stub that omits it turns `/pm panel <name>` into a Lua error on the
  -- one surface a degraded install still has. Deliberately NOT a copy of the library's escapes:
  -- this is the plain form, and its job is to stay readable, not to be byte-identical.
  function Sl.FormatKV(key, value)
    return ("|cffffff00%s|r = |cffffffff%s|r"):format(tostring(key), tostring(value))
  end
  function Sl:Text(key) return tostring(key) end
```

Then a new case in `tests/test_libka0s.lua`, modeled on the existing DebugLog member sweep at
`:524-533` and using the same `loadDegraded()` helper — enumerate every member of `NS.Slash` the
addon calls and assert each is callable, then drive `ns.Slash:CliPanel("<name>")` against a real
record and assert it did not raise **and** produced a line.

**Risk:** low. Adds members to a branch that currently has none of them; the healthy path is
untouched (`Sl.FormatKV = lib.FormatKV` at `:381` still wins, because the stub branch `return`s).

**Standards:** `library-stack-§6` (degrade, never error) is the rule this satisfies;
`library-stack-§7` is the rule that forbids the rejected alternatives above. The stub's plain
formatter is **not** a second implementation of the library's — it is the fallback the seam contract
requires, and it deliberately does not reproduce the library's color bytes.

**Test movement:** +1 or +2 cases. `docs/test-cases.md` and the README `[Tests]` badge move in the
same change (`testing`).

### C-02 — `Schema:Register` reports an unresolvable path regardless of the row's default (covers F-002)

**Files:** `settings/Schema.lua`, `tests/test_schema.lua`

`settings/Schema.lua:168`, before → after:

```lua
-- before
if not row.sessionOnly and S:ReadPath(p, row.path) == nil and row.default == nil then
-- after
if not row.sessionOnly and S:ReadPath(p, row.path) == nil then
```

The comment above it (`:161-163`) already describes the corrected behavior, so it stands as written.

In `tests/test_schema.lua`, keep the existing `assertEqual(S:Register(), 0)` and add its falsifying
twin: append a probe row with a path that resolves nowhere **and** a `default`, assert `Register()`
returns 1, remove the row. Annotate the pair with `-- red under: restoring the `and row.default ==
nil` conjunct`.

**Risk:** low, but it can surface a pre-existing typo as a new chat line at load. Today there is
none — `tests/test_schema.lua:118-127` independently proves every non-session row resolves against
`defaults/Profile.lua`, and it is green.

**Standards:** `architecture-§5` (schema as single source; boot validation must catch a bad path).
`savedvariables` is untouched — no stored shape changes.

**Test movement:** +1 case.

### C-03 — the DebugLog stub speaks in its own words (covers F-003)

**File:** `core/DebugLogSetup.lua`

`:135-140`, before → after:

```lua
-- before
NS.Print("debug logging " .. (on and "|cff40ff40ON|r" or "|cffff4040OFF|r"))
-- after
-- Deliberately NOT the library's ACK/STATE_ON/STATE_OFF strings or its color bytes: a stub that
-- reproduces the library's wording is a copy that goes stale silently the day the library rewords.
-- A degraded install is allowed to say this plainly.
NS.Print(on and "debug logging is on" or "debug logging is off")
```

`tests/test_libka0s.lua:551-559` asserts the flag flips, not the wording, so it is unaffected. If any
case does assert the old bytes, it moves with this change rather than pinning them.

**Risk:** negligible — degraded-install chat text only.

**Standards:** `debug-logging-§5` requires the flag to be session-only and acknowledged; it does not
mandate the wording. `library-stack-§7` is why the copy goes rather than the library string being
re-exported here.

### C-04 — the Options stub's `/pm config` answers every time (covers F-007)

**File:** `settings/OptionsSetup.lua`

`:35-40` / `:49`, before → after:

```lua
-- before
local said = false
local function explain() if said then return end; said = true; NS.Print(UNAVAILABLE) end
...
OpenOptionsPanel = explain,
-- after
-- Latched for anything the addon volunteers; UNLATCHED for the one path the user asked for by
-- name. `/pm config` that says nothing reads as a broken command, which is the opposite of what a
-- degradation notice is for.
local said = false
local function explainOnce() if said then return end; said = true; NS.Print(UNAVAILABLE) end
local function explainAlways() said = true; NS.Print(UNAVAILABLE) end
...
OpenOptionsPanel = explainAlways,
```

Every other stub member that used `explain` keeps `explainOnce` (today only `OpenOptionsPanel` uses
it, so this is a rename plus one new function).

**Risk:** none on the healthy path.

**Standards:** `slash-commands` — a command answers. `options-ui-§2`'s combat refusal is untouched;
this is the *degraded* path, which `settings/Panel.lua:488` reaches before the combat branch only
when the library is absent, and the refusal remains the library's on the healthy path.

### C-05 — the profile-switch migration says what it does (covers F-004)

**Files:** `core/Database.lua`

Chosen shape: keep the account-wide stamp (it is correct for a shape that is a property of the
build, exactly as `defaults/Global.lua:8-13` argues) and make the callback honest:

```lua
-- before
local function reload()
  NS:RunMigrations()        -- the incoming profile may predate the current schema
  NS:SweepPreviewPanels()
  ...
-- after
local function reload()
  -- No RunMigrations here, and that is the correction rather than an omission: the version stamp
  -- is ACCOUNT-WIDE (db.global.schemaVersion) and was bumped at InitDB, so a call here could never
  -- do anything. What actually repairs an incoming profile is Registry:ReloadProfile below, which
  -- re-sanitizes every record — and R.Sanitize is where a per-record repair belongs, because it is
  -- reached from every write path rather than only from a profile switch.
  NS:SweepPreviewPanels()   -- a copied profile can carry someone else's preview orphans
  ...
```

Plus a one-line note on `NS:RunMigrations` (`core/Database.lua:80-83`) stating the invariant that
falls out of the account-wide stamp: **a migration that must touch stored records has to be
expressible in `R.Sanitize` as well, because `RunMigrations` only ever walks the profile that was
active at the moment the stamp was bumped.**

*Alternative considered:* move the stamp to `db.profile.schemaVersion` so every profile migrates on
first activation. Rejected for 0.1.0 — it is a saved-variable shape change requiring its own
migration to introduce, for a runner whose only migration is already idempotent under `Sanitize`.
Recorded in `05_FINAL_SUMMARY.md` as a known follow-up rather than done here.

**Risk:** low. Behavior is unchanged by construction (the removed call provably did nothing).
`tests/test_profiles.lua` should be read for any case that asserts `RunMigrations` is reached from a
profile switch; if one exists it is asserting the no-op and moves with this change.

**Standards:** `savedvariables-§1` — the migration seam survives, invoked once at init before any
read of `db.profile.panels`, which is where it already is (`core/Database.lua:19`).

### C-06 — the vendor-sync pair reports its skip (covers F-005)

**File:** `tests/test_vendor_sync.lua`

Rename both cases to name the condition, and make the quiet path visible rather than
indistinguishable from a verification:

```
"libs/LibKa0s matches the LibKa0s tag the README names (skipped when ../LibKa0s is absent)"
"tests/_kit matches the test kit of that tag (skipped when ../LibKa0s is absent)"
```

and inside each, on the `not tag` path, emit one line through the kit's reporting so a reader of the
run sees the reason. If the framework has no first-class skip, print the reason and keep the early
return — the case name then carries the caveat, which is what the file's header already claims.

**Risk:** none. Assertion strength is unchanged where the sibling exists.

**Standards:** `testing-§12` — a case that passes without exercising anything reads as coverage and
provides none. This is the addon's own test file; `tests/_kit/` is not touched.

### C-07 — guard the mouseover ticker's Unlock reach (covers F-006)

**File:** `modules/Canvas.lua`

`:551`, before → after:

```lua
-- before
elseif unlocked or NS.Unlock:IsPanelUnlocked(id) then
-- after
elseif unlocked or (NS.Unlock and NS.Unlock:IsPanelUnlocked(id)) then
```

Matching `:659` and `:705`, whose guards exist for the same reason.

**Risk:** none. **Perf:** no measurable change is claimed, and none can be — this addon ships no
offline scenario runner, so any such claim would be unverified. The added test is a nil check on a
table lookup already being performed.

**Standards:** none constrains this; it is the file's own convention.

### C-08 — the settings message registers through its published constant (covers F-011)

**File:** `modules/Canvas.lua`

`:743`, before → after:

```lua
-- before
ev:RegisterMessage("Ka0s_PanelMaster_SettingsChanged", function() Canvas:RenderAll() end)
-- after
ev:RegisterMessage(NS.Schema.MSG_SETTINGS, function() Canvas:RenderAll() end)
```

`settings/Schema.lua:21` already publishes it. Ordering is safe: `Canvas:Enable` runs from
`OnEnable` (`core/PanelMaster.lua:61`), long after `settings/Schema.lua` has loaded — the same
call-time resolution the two lines above it already rely on for `NS.Registry.MSG_*`.

**Risk:** low, but it is a real ordering assertion. The existing bus tests
(`tests/test_canvas.lua`, `tests/test_schema.lua:143-149`) cover the wiring end to end.

**Standards:** `architecture-§4` (closed message bus, one sender per message) — this makes the
receiver read the sender's own constant, which is the shape the section describes.

### C-09 — comment corrections (covers F-009, F-010)

**Files:** `core/CoreSetup.lua`, `tests/test_vendor_sync.lua`

- `core/CoreSetup.lua:21`: replace `modules/DebugLog.lua` in the upvalue list with a note that
  `core/DebugLogSetup.lua` resolves the printer through a closure and therefore pins nothing.
- `tests/test_vendor_sync.lua:28-31`: state the actual `.gitattributes` (`*.sh text eol=lf` only,
  per `automated-tests-§2`), and that the `\r\n` normalization is defensive for a CRLF-pinned
  consumer of this same file rather than a description of this repo.

**Risk:** none — comments only.

### C-10 — one AceGUI resolution on the settings pages (covers F-012, F-008)

**Files:** `settings/Panel.lua`, `core/CoreSetup.lua`

Two small tidy-ups, batched because both are "an export with no reader":

- `settings/Panel.lua`: use `O.AceGUI` at `:254`, `:263`, `:271`, `:288` and drop the file-scope
  `local AceGUI` at `:12`; keep the registration guard at `:342` but test `O.AceGUI` (the object the
  page will actually build with) rather than a second resolution of the same library. If `NS.AceGUI`
  (`settings/OptionsSetup.lua:97`) still has no reader afterward, leave the descriptor field —
  it is the library's contract, not this addon's export.
- `core/CoreSetup.lua:86`: either delete `NS.Format` or add the matching member to the stub at
  `:34-69`. Recommendation: **delete**, since nothing calls it and the comment at `:36-38` names the
  stub's member set as exactly the four the addon uses. Re-add it symmetrically if a caller appears.

**Risk:** low. Both are behavior-preserving; the `settings/Panel.lua` guard change is the only line
with any reach, and it is exercised by `tests/test_panel.lua` and
`tests/test_libka0s.lua:342`.

**Standards:** `architecture-§2` (namespace publishes what it uses). Nothing here introduces a new
deviation.

---

## Standards conformance summary

| Change | Rules that shaped it | New deviation introduced |
|---|---|---|
| C-01 | `library-stack-§6`, `library-stack-§7`, `testing` | none |
| C-02 | `architecture-§5`, `testing-§12` | none |
| C-03 | `debug-logging-§5`, `library-stack-§7` | none |
| C-04 | `slash-commands`, `options-ui-§2` (unchanged) | none |
| C-05 | `savedvariables-§1` | none |
| C-06 | `testing-§12` | none |
| C-07 | — (file convention) | none |
| C-08 | `architecture-§4` | none |
| C-09 | `automated-tests-§2` | none |
| C-10 | `architecture-§2` | none |

**Test-count movement.** C-01 (+1/+2) and C-02 (+1) add cases; C-06 renames two. `docs/test-cases.md`
is regenerated by `lua tests/run.lua --list` and the README `[Tests]` badge updated **in the same
change** as the code, never as a follow-up.

**Complexity movement.** None expected. The two functions at the CCN 15 cap
(`R.ApplyArtSize`, `Compat.AddOnFolders`) are untouched by every change above; C-04 adds one small
function to a file whose maximum is well under the cap. The next release's
`/wow-addon:bump-version` regeneration should confirm max CCN is still 15 with 0 warnings.

**Performance.** No change above is claimed to be cheaper or dearer. This addon ships no
`tests/perf.lua` and no `docs/perf-runs/` capture, so any such claim would be an assertion without a
record and is deliberately not made.
</content>
