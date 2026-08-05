# PanelMaster — code review findings (2026-08-05)

**Verdict: minor issues.** One High defect (a reproduced crash on the degraded-install slash path),
five Medium, five Low. Nothing blocks a release of the healthy-install path; the High is a real
runtime error a user hits the moment `libs/LibKa0s/` is missing, which is the exact case the addon's
seams were written to survive.

Standards cross-check: performed against the Ka0s WoW Addon Standard **v2.21.0 (2026-08-04)**,
fetched from `https://github.com/tusharsaxena/WowAddonStandards`. 25 of the 26 section files listed
in `STANDARDS.md` fetched cleanly; `standards/standards/tiered-layout.md` returned **404** (the index
links a file that is not at that path upstream), so no rule from that section shaped anything below.

---

## Measurement run (Step 0 — everything re-run from scratch today)

| Suite | Command (from repo root) | Result |
|---|---|---|
| luacheck | `luacheck .` | **pass** — 0 warnings / 0 errors in 25 files |
| Headless tests | `lua5.1 tests/run.lua` | **pass** — 706 passed, 0 failed, 706 total (exit 0) |
| Test-case inventory | `lua5.1 tests/run.lua --list` → scratch | **pass** — 799 lines; `diff` against committed `docs/test-cases.md` is **empty** |
| Offline perf | `lua5.1 tests/perf.lua` | **skipped** — `tests/perf.lua` does not exist; this addon ships no offline scenarios |
| Complexity | `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` → scratch | **pass** — 1348 functions, 10941 NLOC, avg CCN 2.0, **0 warnings**, max CCN 15 |
| `make test` | — | **skipped** — no root `Makefile` |
| Vendor sync | run in-suite by `tests/test_vendor_sync.lua` | **pass** — sibling `../LibKa0s` present, README provenance `v1.7.0` resolved, both cases really executed (see F-005 for why that is not self-evident from the output) |

**Every function above CCN 15: none.** The two highest are both exactly at the cap:
`R.ApplyArtSize` (`modules/Registry.lua:604-632`, CCN 15) and `Compat.AddOnFolders`
(`core/Compat.lua:34-52`, CCN 15). Next are `Artwork.BuildArtSpec` (13), `applyAccents` (12),
`buildSectionQuads` (12), `Sl:CliPanel` (12), `sources` (`modules/SunnArt.lua`, 12),
`resolve` (`modules/Artwork.lua`, 12), `R.FormatField` (12).

**Committed artifacts vs. today's run — no drift.** `docs/automated-tests/RESULTS.md` and the newest
bundle `docs/automated-tests/20260804-233329/manifest.json` (git sha `645868a`, dirty) record
706/706, 0 lint, 0 CCN warnings, max CCN 15, 10941 NLOC, 1348 functions, perf `skip` — all of which
today's fresh runs reproduce exactly. `docs/test-cases.md` is byte-identical to the fresh `--list`.
The README `[Tests]` badge reads `706/706 passing`, which matches. Nothing here is stale.

Two things this measurement therefore **cannot** say, and does not:
`performance-§9`'s zero-overhead evidence does not exist for this addon (no perf harness ships), and
no in-client capture exists under `docs/perf-runs/`. Every perf-flavored remark below is marked
**unverified** for that reason. The absence of the harness itself is a compliance matter for
`wow-addon:standards-audit`, not a review finding.

In-client checks (taint, locale, real `/reload`, real combat) are deliberately absent from this
block — they are in `03_SMOKE_TESTS.md`.

---

## High

### F-001 — the LibKa0s-Slash degradation stub omits `FormatKV`, so `/pm panel` crashes in a degraded install `[design]` `[bug]`

`settings/Slash.lua:285-317` (the `if not lib then … return end` stub) never assigns `Sl.FormatKV`
or `Sl.Text`; both are only bound after the stub returns, at `settings/Slash.lua:375` and
`settings/Slash.lua:381`. But `FormatKV` is called from **host-owned** panel verbs that live *above*
the branch and are unaffected by the library's absence:
`settings/Slash.lua:101` (`Sl:BuildPanelShowLines`), `:124`, `:125` (`doFitArt`), `:181` and `:188`
(`Sl:CliPanel`).

**Impact.** With `libs/LibKa0s/` missing, `/pm panel <name>`, `/pm panel <name> <field>` and
`/pm panel <name> <field> <value>` all raise `settings/Slash.lua:101: attempt to call field
'FormatKV' (a nil value)`. That is the panel CLI — the surface the stub's own comment
(`settings/Slash.lua:288-289`) singles out as "the only way to reach this addon at all when the
settings panel is also gone."

**Reproduced today**, headlessly, by loading the TOC with the library files never loaded:

```
Sl.FormatKV = nil
CliPanel ok= false  err= settings/Slash.lua:101: attempt to call field 'FormatKV' (a nil value)
CliPanel set ok= false  err= settings/Slash.lua:188: attempt to call field 'FormatKV' (a nil value)
OnSlash panel ok= false err= settings/Slash.lua:101: attempt to call field 'FormatKV' (a nil value)
```

**Coverage gap under this finding.** `tests/test_libka0s.lua:524-533` enumerates every member the
**DebugLog** stub must answer and asserts each is a function. There is no equivalent case for the
Slash stub or the Options stub, so this hole is invisible to a green 706/706 run. That missing case
is the more valuable half of this finding.

**Fix direction.** Answer the member in the stub, in the stub's own words — not by re-implementing
the library's format. `Sl.FormatKV` must produce a `key = value` line; the stub is allowed a plain
one, because a degraded install is not promising byte-identical chrome. Do **not** copy the
library's color escapes (that is the F-003 mistake in the other direction), and do **not** patch
`libs/` (`library-stack-§7`).

---

## Medium

### F-002 — `Schema:Register`'s boot validation can never fire, and its test can never go red `[design]` `[tests]`

`settings/Schema.lua:165-175`. The guard is

```lua
if not row.sessionOnly and S:ReadPath(p, row.path) == nil and row.default == nil then
```

The `and row.default == nil` conjunct means a row whose path does **not** resolve against
`defaults/Profile.lua` is only reported when the row *also* declares no `default`. Every one of the
eleven shipped rows declares a `default`, so the counter is structurally pinned at 0 — which
contradicts the function's own docstring at `settings/Schema.lua:161-163` ("every schema path must
resolve against the defaults table, so a typo in a path is caught loudly at load") and the
`architecture-§5` obligation it cites.

**Measured today** by injecting two probe rows into a real load:

```
Register() with a typo'd path that HAS a default -> 0     (should be 1)
Register() with a typo'd path and NO default     -> 1
```

**Impact.** The in-game boot check is inert: a mistyped `path` reads `nil` forever and says nothing,
which is precisely the failure the check exists to prevent. It is currently masked by a *different*
case — `tests/test_schema.lua:118-127` ("the defaults match the shipped profile") does catch a
typo'd path — but that is a suite-only guard, and the runtime one that `architecture-§5` requires is
dead.

**Unfalsifiable test.** `tests/test_schema.lua:8-11` asserts `assertEqual(S:Register(), 0)`. Because
the counter cannot increment for any row shaped like the shipped ones, that assertion passes
regardless of what `Register` does; it reads as coverage and provides none (`testing-§12`). It
carries no `-- red under: …` note, and none would be truthful as written.

**Fix direction.** Drop the `and row.default == nil` conjunct so an unresolvable path is reported
whether or not the row declares a fallback, and give the test a positive case (a deliberately
unresolvable probe row asserted to return 1) alongside the 0.

### F-003 — the DebugLog degradation stub hand-copies the library's acknowledgement string and color hexes `[design]`

`core/DebugLogSetup.lua:135-140`:

```lua
NS.Print("debug logging " .. (on and "|cff40ff40ON|r" or "|cffff4040OFF|r"))
```

That is a byte-level reproduction of `libs/LibKa0s/DebugLog.lua:68` (`ACK = "debug logging %s"`),
`:69-70` (`STATE_ON`/`STATE_OFF`) and the `40ff40`/`ff4040` hexes the library applies at
`libs/LibKa0s/DebugLog.lua:632-634`. A degradation stub that re-implements the library's *strings*
is the stale-copy hazard in the opposite direction from F-001: nothing fails when the library
rewords `ACK`, and the two installs then say different things about the same flag with no test
between them.

**Fix direction.** Keep the stub's *behavior* (it correctly still flips the session flag and
acknowledges — that half is right and deliberate) but let it speak in the addon's own plain words
rather than in a copy of the library's format. The compliant direction if the wording genuinely must
match is an additive export of the string from the library, pushed upstream — never a local copy and
never a `libs/` edit.

### F-004 — the profile-switch migration call is a guaranteed no-op, and its comment says otherwise `[design]`

`core/Database.lua:68-78`. `reload()` runs `NS:RunMigrations()` on `OnProfileChanged`,
`OnProfileCopied` and `OnProfileReset`, commented "the incoming profile may predate the current
schema". But `RunMigrations` gates on `db.global.schemaVersion` (`core/Database.lua:85-88`), which is
**account-wide** and was already bumped to `NS.SCHEMA_VERSION` at `InitDB` time
(`core/Database.lua:113`). By the time any profile callback fires, the guard is always false and the
body — including the v1→v2 `frameName` stamp at `core/Database.lua:103-111`, which only ever walks
`NS.db.profile`, the **active** profile — never runs again.

**Impact today: none observable**, because `R:ReloadProfile` (`modules/Registry.lua:515-520`)
re-sanitizes every incoming record and `R.Sanitize` (`modules/Registry.lua:200-202`) independently
stamps a missing `frameName`. The defect is structural: the migration runner claims to cover a case
it cannot cover, so the next migration whose repair `Sanitize` does *not* duplicate will silently
skip every profile that was not active at the moment the stamp was bumped.

**Fix direction.** Either make the stamp per-profile (`db.profile.schemaVersion`, with `global`
retained for account-wide shape), or keep the account-wide stamp and correct the comment plus drop
the no-op call — but do not leave a call whose stated purpose the code cannot deliver.
`savedvariables-§1` requires the runner to be an idempotent seam invoked before any read of
`db.profile.panels`; either shape satisfies it, the current comment does not describe either.

### F-005 — the vendor-sync cases print PASS when they verified nothing, and the mitigation the file claims is not there `[tests]`

`tests/test_vendor_sync.lua:104-116` (`siblingTag`) returns `nil` when `../LibKa0s` is absent, and
both cases at `:138` and `:144` then `return` immediately — printing `PASS` and counting toward
706/706. The file's own header at `:105-108` says "A missing sibling is the ONE case where this pair
may go quiet, and it is said in the case name rather than hidden." It is **not** said in the case
name: the two names are *"libs/LibKa0s is the LibKa0s release the README says this addon bundles"*
and *"tests/\_kit is the test kit that shipped with that release"*. Neither mentions the sibling, so
a reader of a run cannot tell a verified vendor from an unverified one.

**Today it genuinely ran** — I confirmed the sibling resolves and the README provenance line
(`README.md:379-380`, "…it\nbundles [LibKa0s](…) v1.7.0 (MIT)…") matches the file's pattern. That is
a fact about this machine, not about the gate.

**Fix direction.** Emit a visible skip rather than a silent pass — the kit exposes `T.fail` and the
framework counts cases, so the compliant local shape is to keep one case that asserts the sibling
either verified or was explicitly reported absent, and to name the quiet case accordingly. This is
this addon's own test file, so the fix lands here; it is **not** a `tests/_kit/` change.

### F-006 — the 10 Hz mouseover ticker reaches `NS.Unlock` unguarded, against the file's own convention `[bug]`

`modules/Canvas.lua:551`:

```lua
elseif unlocked or NS.Unlock:IsPanelUnlocked(id) then
```

Every other cross-module reach in the same file guards first —
`modules/Canvas.lua:659` (`if NS.Unlock and NS.Unlock.StripOverlay`) and
`modules/Canvas.lua:705` (`if NS.Unlock and NS.Unlock.Decorate`). If `modules/Unlock.lua` fails to
load (a TOC edit, a syntax error in that file, a partial install), `updateMouseover` raises on every
tick of the driver installed at `modules/Canvas.lua:565` — a repeating error, ten times a second,
for the rest of the session.

**Fix direction.** Guard it the way its two siblings are guarded. (Not a perf change; the added test
is a nil check on an upvalue-free lookup already being performed.)

### F-007 — in a degraded install `/pm config` answers once and is silent forever afterward `[ux]`

`settings/OptionsSetup.lua:35-40` — the Options stub's `explain()` latches on `said`, and
`OpenOptionsPanel = explain` (`:49`). `P:Open` (`settings/Panel.lua:483-499`) routes to
`O.OpenOptionsPanel()` on every invocation.

**Measured today** against a degraded load:

```
first  /pm config -> 1 line  "[PM] The LibKa0s library is missing …, so the settings panel is unavailable."
second /pm config -> 0 lines (silence)
third  /pm config -> 0 lines (silence)
```

**Impact.** A slash verb the user typed deliberately does nothing and says nothing. The once-only
latch is right for `DebugLog:Show`/`Toggle` (a window that quietly fails to appear) but wrong for an
explicit command: `slash-commands` requires a command to answer. The latch reads as a
copy-paste of the console seam's pattern into a place where the trade inverts.

**Fix direction.** Give the Options stub two behaviors: latch the *unsolicited* notice, but let the
`OpenOptionsPanel` path print every time it is called. Do not remove the shared cause clause — the
wording is the collection's (`core/CoreSetup.lua:29-30`).

---

## Low

### F-008 — `NS.Format` is a dead export, and one the degradation stub does not answer `[dead-code]`

`core/CoreSetup.lua:86` publishes `NS.Format = printer.Format`. `grep` across `core/`, `modules/`,
`settings/`, `locales/`, `defaults/` and `tests/` finds **no caller** — the only other occurrence is
its own assignment. It is also absent from the stub at `core/CoreSetup.lua:34-69`, whose comment at
`:36-38` states the stub's member set is exactly the four the addon calls. So the first caller added
would work on a healthy install and raise on a degraded one. Either drop it or add it to the stub;
leaving it as the one asymmetric member undermines the seam's own stated invariant.

### F-009 — a load-order comment names a file that no longer exists `[naming]`

`core/CoreSetup.lua:21` lists `modules/DebugLog.lua` among the six files that take the printer as a
load-time upvalue. That file was replaced by `core/DebugLogSetup.lua` (see that file's own header at
`:5-8`), and the replacement deliberately does **not** take the printer as an upvalue — it resolves
it through a closure, for the reason its own comment gives at `core/DebugLogSetup.lua:167-169`. The
comment is a stale ordering constraint, which is the kind that gets honored long after it stopped
being real.

### F-010 — a test file asserts a `.gitattributes` pin this repo does not have `[naming]`

`tests/test_vendor_sync.lua:28-31` states "the working tree is CRLF because `.gitattributes` pins
`* text=auto eol=crlf`". The repo's `.gitattributes` carries **only** `*.sh   text eol=lf`;
`git check-attr -a` reports no attributes for `core/Util.lua`, `PanelMaster.toc` or `README.md`, and
`file(1)` shows the tree is LF. The `\r\n → \n` normalization the comment justifies is therefore a
no-op. Harmless as behavior, wrong as documentation — and the `*.sh` carve-out (correct per
`automated-tests-§2`) currently guards against a pin that is not there.

### F-011 — the settings message is registered by literal, while the two panel messages use their published constants `[design]`

`modules/Canvas.lua:743` registers `"Ka0s_PanelMaster_SettingsChanged"` as a raw string, two lines
below `:741` and `:742` which correctly use `NS.Registry.MSG_PANELS` and `NS.Registry.MSG_PANEL`.
`settings/Schema.lua:21` publishes `S.MSG_SETTINGS` for exactly this purpose and nothing reads it.
The single-sender test at `tests/test_schema.lua:129-142` greps for the literal, so a rename of the
constant would leave this receiver silently unsubscribed and the test still green.

### F-012 — three names for one AceGUI `[design]`

`settings/Panel.lua:12` resolves AceGUI itself at file scope (`local AceGUI = LibStub(...)`) and uses
it at `:254`, `:263`, `:271`, `:288`, while `settings/OptionsSetup.lua:97`'s `onAceGUI` stashes the
library's resolved instance on `NS.AceGUI` and `O.AceGUI` is the instance member used at
`settings/Panel.lua:206` and `:457`. Three names for one object, one of which (`NS.AceGUI`) has no
reader. `settings/PanelEditor.lua:7` makes a fourth resolution. Not a bug — the same LibStub call
returns the same table — but the guard at `settings/Panel.lua:342` tests the file-scope copy while
the widget makers use the descriptor-resolved one, which is a divergence waiting for a reason.

---

## Not raised, deliberately

- **The absent perf harness** (`tests/perf.lua`, `docs/performance.md`, `docs/perf-runs/`) is
  recorded above as a skip and as the reason perf claims are unverified. Its *absence* is a
  compliance matter for `wow-addon:standards-audit`, not a review finding.
- **`libs/` and `tests/_kit/` defects**: none found. No `[upstream]` findings in this review.
- **`modules/Artwork.lua` (1188 LOC) and `settings/PanelEditor.lua` (1064 LOC)** sit in
  `layout-§1`'s on-notice band and are named as such in `docs/automated-tests/RESULTS.md`. Both are
  cohesive and neither is flagged by today's `lizard` run; no split is recommended.
</content>
</invoke>
