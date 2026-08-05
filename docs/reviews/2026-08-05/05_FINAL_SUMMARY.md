# PanelMaster — post-implementation summary (2026-08-05)

> Written under the assumption that every change in `02_PROPOSED_CHANGES.md` was applied per
> `04_EXECUTION_PLAN.md` and every check in `03_SMOKE_TESTS.md` passed. Fill in the verification
> pointers at the bottom before using this as a PR description.

---

## Headline

This cycle fixed the one way PanelMaster could still crash on a user's screen — a degraded install
(one where `libs/LibKa0s/` was never copied) hitting the panel CLI — and then went after the reason
nobody had noticed: three separate checks in this repo were passing without checking anything. The
addon's degradation seams are the feature that makes the vendored shared library optional rather than
mandatory, and they were being tested on one of the three seams. The other two are now tested, the
schema's boot validation now reports a fault it was structurally unable to report, and the
vendor-sync gate now tells you when it verified nothing rather than printing PASS either way. Along
the way, a migration call that could never run, a comment naming a deleted file, and a per-frame
guard broken in exactly one place were cleaned up. No user-visible behavior on a healthy install
changed.

---

## Counts

**Critical fixed: 0 · High fixed: 1 · Medium fixed: 5 · Low fixed: 5**

Nothing was deferred from the finding list. Two items were deliberately scoped **down** rather than
dropped, and both are in *Known follow-ups*: the per-profile schema stamp (F-004's larger fix), and
the missing offline perf harness (not a review finding — a compliance matter recorded in
`01_FINDINGS.md`'s measurement block so no perf claim in this cycle reads as verified).

---

## Changes by theme

### Theme 1 — a degradation stub answers everything, and answers in its own words

**What changed.** The LibKa0s-Slash degradation stub now provides `FormatKV` and `Text`, which the
addon's own host-owned panel verbs call unconditionally. The LibKa0s-Options stub's `/pm config`
handler stopped latching after its first invocation. The LibKa0s-DebugLog stub stopped reproducing
the library's acknowledgement string and its green/red color bytes and now says the same thing in
plain words. And the suite gained the member sweep for the Slash stub that the console stub has had
since the adoption.

**Why it mattered.** In an install missing `libs/LibKa0s/`, `/pm panel <name>` raised
`attempt to call field 'FormatKV' (a nil value)` — on the surface the stub's own comment identifies
as the last way to reach the addon when the settings panel is also gone. That is a fallback that is
really a crash moved to a rarer path, and nothing in a green 706/706 run could see it. The Options
latch was the same class of defect one step milder: a command the user typed answered once per
session and was silent thereafter. The DebugLog copy was the mirror image — not a missing member but
a duplicated one, guaranteed to go stale the day the library rewords `ACK`.

**Finding IDs covered:** F-001, F-003, F-007
**Change IDs implemented:** C-01, C-03, C-04
**Files touched:**
- `settings/Slash.lua`
- `settings/OptionsSetup.lua`
- `core/DebugLogSetup.lua`
- `tests/test_libka0s.lua`

### Theme 2 — checks that can fail

**What changed.** `Schema:Register`'s condition dropped the `and row.default == nil` conjunct, so an
unresolvable schema path is reported at load whether or not the row declares a fallback. The test
that asserted `Register()` returns 0 kept its assertion and gained a falsifying twin (a probe row
that must come back 1), annotated with what reddens it. The two vendor-sync cases were renamed to
name their own quiet condition and now report a visible skip instead of an unqualified PASS when
`../LibKa0s` is absent.

**Why it mattered.** `Schema:Register` is `architecture-§5`'s boot validation, and it could not fire
for any row the addon actually ships — every one declares a `default`. Its guarding test therefore
passed regardless of what the function did: coverage that reads as coverage and provides none. The
vendor-sync pair had the same property in a different shape — a run gave no way to distinguish
"the vendored bytes match the tag" from "the sibling repo wasn't there, so nobody looked."

**Finding IDs covered:** F-002, F-005
**Change IDs implemented:** C-02, C-06
**Files touched:**
- `settings/Schema.lua`
- `tests/test_schema.lua`
- `tests/test_vendor_sync.lua`

### Theme 3 — say what the code does

**What changed.** The `NS:RunMigrations()` call inside the AceDB profile-change callback was removed
and replaced with a note explaining why it could never have done anything, plus a stated invariant on
`RunMigrations` itself: because the schema stamp is account-wide, any future migration that touches
stored records must also be expressible in `R.Sanitize`. Two stale comments were corrected — one
naming `modules/DebugLog.lua`, a file replaced by `core/DebugLogSetup.lua`, and one asserting a
`.gitattributes` CRLF pin this repo does not carry.

**Why it mattered.** The profile callback claimed to migrate an incoming profile that "may predate
the current schema." It could not: `db.global.schemaVersion` is account-wide and had already been
bumped at `InitDB`, so the guard was always false. Today that is masked, because `R:ReloadProfile`
re-sanitizes every record and `R.Sanitize` independently repairs the one field v2 stamps. The next
migration whose repair `Sanitize` does not duplicate would have silently skipped every profile that
was not active when the stamp moved — and the comment would have said it was covered.

**Finding IDs covered:** F-004, F-009, F-010
**Change IDs implemented:** C-05, C-09
**Files touched:**
- `core/Database.lua`
- `core/CoreSetup.lua`
- `tests/test_vendor_sync.lua`

### Theme 4 — one name per thing

**What changed.** The 10 Hz mouseover ticker's reach into `NS.Unlock` is now guarded the same way
the two other cross-module reaches in the same file already were. The settings-changed message is
registered through `NS.Schema.MSG_SETTINGS` rather than a literal, matching the two panel messages
beside it. The settings pages resolve AceGUI once, through the Options instance, instead of three
times under three names; and the unread `NS.Format` export was removed.

**Why it mattered.** None of these was a live bug. Each was a way for a later edit to be silently
wrong: an unguarded reach that would have spammed an error ten times a second if `modules/Unlock.lua`
ever failed to load; a literal that would survive a rename of the constant published for it, leaving
the renderer unsubscribed with the single-sender test still green; and an export that worked on a
healthy install and would have raised on a degraded one the moment anyone called it.

**Finding IDs covered:** F-006, F-008, F-011, F-012
**Change IDs implemented:** C-07, C-08, C-10
**Files touched:**
- `modules/Canvas.lua`
- `settings/Panel.lua`
- `core/CoreSetup.lua`

---

## API / behavior changes

Externally observable, all confined to the **degraded-install** path except where noted:

- `/pm panel <name>`, `/pm panel <name> <field>` and `/pm panel <name> <field> <value>` now work in a
  degraded install instead of raising. Their output uses a plain `key = value` form there; the
  healthy install is byte-unchanged (still the library's `FormatKV`).
- `/pm config` in a degraded install now prints its "settings panel is unavailable" line on **every**
  invocation instead of only the first.
- `/pm debug on|off` in a degraded install now prints `debug logging is on` / `debug logging is off`
  instead of a copy of the library's `debug logging ON` / `OFF` with its color bytes. The healthy
  install is unchanged.
- **Healthy install, potentially visible:** if any schema row's `path` did not resolve against
  `defaults/Profile.lua`, a `schema path missing default: <path>` line now appears once at load. No
  such row exists in this build, so in practice nothing new is printed.

No slash subcommand was added, renamed or removed — `NS.COMMANDS` and the README's command table
both still carry the same 18 verbs, and they still agree in both directions. No locale key was added
or renamed (this build ships English-only by an explicit `locales/enUS.lua` scope decision).

---

## Saved-variable / migration notes

**No schema bump. `NS.SCHEMA_VERSION` stays 2.** No stored shape changed and no migration was added,
so every existing profile is carried forward untouched and no user needs `/pm reset` or any manual
step.

One structural note for whoever writes the next migration: the version stamp lives in
`db.global.schemaVersion` (account-wide), and `NS:RunMigrations` only ever walks the profile that is
active at init. A migration that must touch stored panel records therefore has to be expressible in
`R.Sanitize` as well — that is what actually repairs a profile on the way in, from every write path
rather than only from a login. This is now written down in `core/Database.lua`.

---

## Deprecated-API migrations

**None.** The sweep found no deprecated or removed API in this addon's own code. `core/Compat.lua`
already routes every varying API through a presence-checked shim — `C_AddOns.GetAddOnMetadata` with
a fallback to the bare global (`:13-21`), `C_AddOns.GetNumAddOns` / `GetAddOnInfo` with the same
(`:34-52`) — and `modules/Canvas.lua` guards `SetBackdrop` on the frame instance rather than on a
build check (`:376`, `:607`), with `BackdropTemplate` correctly passed at `CreateFrame` time
(`:185`, `:265`). `RAID_CLASS_COLORS` is keyed on the `classFile` token, never the localized name
(`core/Compat.lua:91-99`).

---

## Performance impact

**Omitted — no perf-tagged change was made, and this addon ships no measurement to make one
against.** There is no `tests/perf.lua`, no `docs/performance.md` and no `docs/perf-runs/` capture,
so any before/after figure here would be an assertion without a record. C-07 (the ticker guard) adds
one nil test to a lookup already being performed; that is stated as a fact about the code, not as a
measured improvement.

---

## Test and complexity movement

| | Before | After |
|---|---|---|
| Test cases | 706 / 706 | *(fill in: expect 709–710)* |
| `luacheck` | 0 warnings / 0 errors, 25 files | 0 / 0 |
| `lizard` warnings (CCN > 15) | 0 over 1348 functions | 0 |
| Max CCN | 15 (`R.ApplyArtSize`, `Compat.AddOnFolders`) | 15, unchanged |

`docs/test-cases.md` and the README `[Tests]` badge were regenerated and moved **in the same change**
as the code that moved the count — `lua5.1 tests/run.lua --list > docs/test-cases.md`, never by hand
(`testing`).

**Complexity watch list.** No entry is expected to move. The two functions at the CCN 15 cap are
untouched by every change in this cycle; C-04 adds one small function to `settings/OptionsSetup.lua`,
whose maximum is well under the cap. The next release's `/wow-addon:bump-version` regeneration
should confirm max CCN is still 15 with zero warnings — that regeneration belongs to the release, not
to this work.

---

## Known follow-ups

- **Per-profile schema stamp (the larger F-004 fix).** Moving the version stamp from
  `db.global.schemaVersion` to `db.profile.schemaVersion` would let every profile migrate on first
  activation, removing the invariant this cycle merely wrote down. Deferred because introducing it is
  itself a saved-variable shape change needing its own migration, for a runner whose only migration
  is already idempotent under `R.Sanitize`. Worth doing before the *second* migration exists, not
  after.
- **No offline perf harness.** `tests/perf.lua` does not exist, so `performance-§9`'s zero-overhead
  evidence does not exist for this addon and the `perf` column in every `docs/automated-tests/`
  bundle is a permanent `skip`. Not a review finding — recorded here so it is not mistaken for one,
  and left to `wow-addon:standards-audit`.
- **`NS.AceGUI` may now have no reader.** After C-10 the descriptor's `onAceGUI` stash
  (`settings/OptionsSetup.lua:97`) may be write-only. It is the library's contract field, not this
  addon's export, so it stays; revisit if the library ever drops it.
- **`modules/Artwork.lua` (1188 LOC) and `settings/PanelEditor.lua` (1064 LOC)** remain in
  `layout-§1`'s on-notice band. Both are cohesive and neither is flagged by `lizard`; no split is
  recommended, and this is noted so the next reviewer does not re-derive it.
- **`standards/standards/tiered-layout.md` 404s upstream.** The standard's own Sections list links a
  file that is not at that path. Not this repo's to fix; worth reporting to
  `WowAddonStandards`, since it means no consumer can read that section.

---

## Verification evidence

- **Smoke tests:** `docs/reviews/2026-08-05/03_SMOKE_TESTS.md`, sign-off table completed.
  *(fill in: tester, date, client build)*
- **Commit range / PR:** *(fill in)*
- **Findings:** `docs/reviews/2026-08-05/01_FINDINGS.md` (F-001 … F-012)
- **Design:** `docs/reviews/2026-08-05/02_PROPOSED_CHANGES.md` (C-01 … C-10)
- **Baseline measurement (2026-08-05, pre-change):** `luacheck .` 0/0 over 25 files ·
  `lua5.1 tests/run.lua` 706/706 · `--list` byte-identical to `docs/test-cases.md` ·
  `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` 1348 functions, 0 warnings, max CCN 15 ·
  `tests/perf.lua` absent (skip) · no `Makefile` (skip) · vendor-sync verified in-suite against
  `../LibKa0s` at README-declared `v1.7.0`.

---

## Suggested commit message / PR description

```
review 2026-08-05: the degradation seam, and three checks that could not fail

The one user-visible defect: a degraded install (libs/LibKa0s absent) raised
"attempt to call field 'FormatKV' (a nil value)" on /pm panel — the surface the
Slash stub's own comment calls the last way to reach the addon when the settings
panel is gone too. The stub omitted a member the addon's host-owned panel verbs
call unconditionally. It answers it now, in its own plain words rather than in a
copy of the library's, and the suite gained the member sweep the console stub has
had all along.

That it went unseen is the rest of this change. Schema:Register's boot validation
carried an `and row.default == nil` conjunct that pinned it at zero for every row
the addon ships, and the test asserting that zero could not go red. The two
vendor-sync cases printed PASS whether they compared the vendored bytes against
the LibKa0s tag or found no sibling checkout and returned. Both now have a
reachable negative.

Also: a profile-switch RunMigrations() call that could never fire (the stamp is
account-wide and already bumped), replaced by the invariant that actually holds;
a 10Hz ticker reaching NS.Unlock unguarded against its own file's convention; the
settings message registered by literal beside two constants; an unread NS.Format
export; and two comments naming things that no longer exist.

No schema bump. No healthy-install behavior change. No deprecated API found.

Findings: F-001 (High), F-002 F-003 F-004 F-005 F-006 F-007 (Medium),
F-008 F-009 F-010 F-011 F-012 (Low).
Changes: C-01 … C-10. Full detail in docs/reviews/2026-08-05/.

Tests 706 -> <N>. luacheck 0/0. lizard 0 warnings, max CCN 15 (unchanged).
```
</content>
