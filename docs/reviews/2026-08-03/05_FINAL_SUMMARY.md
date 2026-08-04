# Ka0s Panel Master — Review Cycle Summary (2026-08-03)

> **Status: written ahead of implementation.** This document is the "what shipped" record for the
> 2026-08-03 review, drafted on the assumption that every change in `02_PROPOSED_CHANGES.md` lands
> and every case in `03_SMOKE_TESTS.md` passes. Until the sign-off table in that file is filled in,
> treat this as the intended outcome rather than the achieved one, and correct any section the
> implementation diverges from.

---

## Headline

A full-scope review of Ka0s Panel Master found the addon structurally sound — clean module
boundaries, one write seam per storage kind, a real (not decorative) LibKa0s adoption, no taint
exposure, no deprecated API, 696 green tests and clean lint. It found **one defect worth blocking a
release for**: the slash-command degradation stub, which is what runs when `libs/LibKa0s` is
missing, omitted the `FormatKV` formatter that five panel-CLI call sites use — so in that
configuration every `/pm panel …` command raised a Lua error instead of printing. This cycle fixes
that, puts a test in front of the stub's member set so the same class of omission cannot recur,
closes a matching gap where the panel-record sanitizer skipped two artwork fields, retires three
published names nothing calls, and makes four pieces of documentation executable again.

---

## Counts

**Critical fixed: 0, High fixed: 1, Medium fixed: 4, Low fixed: 4.**

Deliberately deferred:

- **F-010** (registry lookups are linear, making a full rebuild quadratic) — no change. The cost is
  unmeasurable at this addon's panel counts and an id→record index needs invalidation on create,
  delete, profile switch and profile copy. Recorded under *Known follow-ups* so a future panel-cap
  increase reaches it rather than rediscovering it.

Out of scope by charter (routed to `wow-addon:standards-audit`, not defects): chat call sites that
pre-concatenate arguments before `NS.Print`, and the absence of `core/PerfSetup.lua`.

---

## Changes by theme

### Theme A — Degradation stubs answer what the addon actually calls

**What changed.** The slash degradation stub now publishes a `FormatKV` of its own — a deliberately
plain `path = value` line, visibly different from the library's styled one — so the panel commands,
which are this addon's own code and were always meant to keep working without LibKa0s, do. Two new
test cases load the whole addon with the library files absent and assert both the stub's full member
set and that every `/pm panel` verb answers; a third asserts the degraded formatter is **not** the
library's function value, so the tempting wrong fix goes red.

**Why it mattered.** A stub that omits a member is not a fallback — it is a crash relocated to a
rarer code path, where nothing fails until a user hits it. The library's own contract
(slash-commands-§1, debug-logging-§7) says so in as many words, and this addon's three other stubs
follow it exactly; this one silently did not, because the missing assignment sat *after* the stub's
early `return`.

**Finding IDs covered:** F-001. **Change IDs implemented:** C-01, C-02.

**Files touched:**
- `settings/Slash.lua`
- `tests/test_libka0s.lua`

### Theme B — The `Sanitize` contract is closed

**What changed.** `Registry.Sanitize` now normalizes `artBlend` (through the same `enumMatch` seam
the other three artwork enums use) and `artDesaturate` (through the same boolean coercion every
other flag uses). A new property test asserts that *every* key of `C.PANEL_TEMPLATE` comes back set
after a sanitize, so the next field added to the template and forgotten fails immediately.

**Why it mattered.** The sanitizer's stated contract is that the stored file is always already
valid — but a record from an older build, an imported profile or a hand-edited SavedVariables could
carry `artDesaturate = nil` and an illegal `artBlend` such as `"MOD"` through every write. Nothing
crashed (the renderer re-guards both), which is exactly why it went unnoticed: what the user saw was
`/pm panel <name>` reporting `nil`, an unticked Desaturate box and a blank Blend dropdown for values
the addon had in fact accepted.

**Finding IDs covered:** F-002. **Change IDs implemented:** C-03.

**Files touched:**
- `modules/Registry.lua`
- `tests/test_registry.lua`

### Theme C — Dead surface retired

**What changed.** Three published names with zero readers were resolved: `SunnArt.Installed()`
(renamed to the repo's own `__` test-seam convention, with its inaccurate "keeps the feature silent"
comment trimmed to what it is), `C.MEDIA_FALLBACK` (deleted — the rule it stated is implemented in
`Compat.FetchMedia`) and `NS.Format` (deleted — a second entry point to a printer nothing reaches
that way, and one the degradation stub did not provide either).

**Why it mattered.** Each is trivially small; together they are the shape that makes a codebase stop
being trustworthy, because a reader cannot tell which comments describe behavior and which describe
intentions. `NS.Format` in particular was the same live-path/stub asymmetry that produced the
Theme A defect one file over.

**Finding IDs covered:** F-003, F-006, F-007. **Change IDs implemented:** C-04, C-05, C-06.

**Files touched:**
- `modules/SunnArt.lua`, `tests/test_sunnart.lua`
- `core/Constants.lua`
- `core/CoreSetup.lua`

### Theme D — Documentation made executable again

**What changed.** The README's worked artwork example and the corresponding smoke-test step named
`runic-sigil` / `General: Runic Sigil` — the retired seed catalog entry — and now name a real
bundled piece. A `/pm panel set <name> <field> <value>` grammar that the dispatcher does not
implement was corrected in four code comments and one smoke-test step. The architecture doc's bus
table now lists the Panels settings page as the second consumer of `Ka0s_PanelMaster_PanelChanged`.

**Why it mattered.** The first artwork command in the user-facing documentation failed with
`unknown artwork`. The smoke-test step that was supposed to verify an enum refusal instead failed on
a name lookup, so it verified nothing — a gate step that fails for the wrong reason is worse than a
missing one. And architecture-§4 makes documenting every consumer of a bus message a MUST, which the
row above it already satisfied.

**Finding IDs covered:** F-004, F-005, F-008. **Change IDs implemented:** C-07, C-08, C-09.

**Files touched:**
- `README.md`
- `docs/smoke-tests.md`
- `docs/ARCHITECTURE.md`
- `core/Util.lua`, `core/Constants.lua`, `modules/Artwork.lua`

### Theme E — Naming honesty

**What changed.** Both callers of `Registry:FitToArtwork` bound its second return — a width on
success, a sentence on failure — to a variable named `w`, each with a comment explaining the lie.
The variables are now named for what they hold and the comments are gone.

**Why it mattered.** A comment that exists only to explain a name is a name that should change.

**Finding IDs covered:** F-009. **Change IDs implemented:** C-10.

**Files touched:**
- `settings/Slash.lua`
- `settings/PanelEditor.lua`

---

## API / behavior changes

**Externally observable, in a normal install (LibKa0s present):**

- **`/pm panel <name>` output** — for a record written by an older build or edited by hand,
  `artDesaturate` now prints `false` instead of `nil`, and an illegal `artBlend` is repaired to
  `BLEND` on the next write to that panel. On a healthy profile nothing changes.
- Nothing else. No slash verb was added, renamed or removed; the 18 entries of `NS.COMMANDS` are
  unchanged and still match the README table exactly.

**Externally observable, in a degraded install (`libs/LibKa0s` absent):**

- `/pm panel <name>`, `/pm panel <name> <field>`, `/pm panel <name> <field> <value>` and
  `/pm panel <name> fitart` **now work** where they previously raised a Lua error. They render a
  plain `field = value` line rather than the library's styled one — this difference is deliberate
  and is the visible signal that the install is degraded.

**Removed internals** (none were public API; all had zero callers): `C.MEDIA_FALLBACK`, `NS.Format`,
and `SunnArt.Installed` (renamed, not removed, under the `__` internal convention).

**Locale keys:** none added, renamed or removed — this release is still English-only by the recorded
0.1.0 scope decision, and no user-facing string routes through `NS.L` yet.

---

## Saved-variable / migration notes

**No schema bump. `NS.SCHEMA_VERSION` stays at 2 and no new migration was added.**

The `artBlend`/`artDesaturate` repair was deliberately placed in `Registry.Sanitize` rather than in
`NS:RunMigrations`, because `Sanitize` is the seam that *every* route into a record already passes
through — the login sweep, an imported profile, a copied profile, `R:Set`, `R:CopyFrom` and
`R:ReloadProfile` alike. A migration would have covered only the login path.

**Migration path for existing users: automatic and lazy.** A panel with a missing or illegal artwork
field is repaired the first time anything writes to it (a slider, a drag, a `/pm panel … <value>`, a
profile switch, or a copy). Until then the record is untouched and the panel renders exactly as it
did — the renderer has always re-guarded both fields. **No `/pm reset` is required**, and none should
be recommended: it would discard the user's panels to fix a field that repairs itself.

Old → new shape, for the affected records only:

| Field | Before (older build / hand-edited) | After first write |
|---|---|---|
| `artDesaturate` | absent (`nil`) | `false` |
| `artBlend` | absent, or any string | `"BLEND"` if not one of `BLEND` / `ADD`; case-corrected otherwise |

---

## Deprecated-API migrations

**None — the sweep found nothing to migrate.** Recorded here so a future reviewer does not repeat
the search: `core/Compat.lua` already owns every varying API, guarding `C_AddOns.GetAddOnMetadata`,
`C_AddOns.GetNumAddOns` and `C_AddOns.GetAddOnInfo` with bare-global fallbacks, and no call to
`GetSpellInfo`, `UnitAura`/`UnitBuff`/`UnitDebuff`, `GetContainerNumSlots`/`GetContainerItemInfo`,
`IsAddOnLoaded`/`LoadAddOn` or `InterfaceOptions_AddCategory` exists anywhere under `core/`,
`defaults/`, `locales/`, `modules/` or `settings/`. Backdrops are created with `BackdropTemplate`
and additionally method-guarded on the frame instance (`modules/Canvas.lua:357-381`).

| Old API | New API | Files |
|---|---|---|
| *(none)* | — | — |

---

## Performance impact

No performance-tagged change was made, so there are no before/after numbers to report. The only
change touching a repeated path is the two added operations in `Registry.Sanitize`, which runs once
per record write (a slider mouse-up, a drag stop, a CLI set) — not per frame — and whose cost is a
table lookup and a boolean coercion. The smoke-test suite's garbage spot-check exists to confirm no
per-write allocation was introduced, not to measure a gain.

---

## Known follow-ups

- **F-010 — linear registry lookups.** `R:Get` / `R:FindByName` / `R:Resolve` are O(N) scans, so
  `Canvas:RenderAll` is O(N²) and every field write pays two scans. Unmeasurable at realistic panel
  counts and deliberately not fixed: an id→record index must be invalidated on create, delete,
  profile switch and profile copy, which is more machinery than the cost justifies today.
  **Revisit if** the panel count is ever uncapped, or if any per-frame code starts calling `R:Get`.
- **`Sl:Text` in the degraded stub.** Left absent (with the reason written down beside it) because it
  has no production caller. **Revisit if** any host code ever calls it — at which point it becomes
  the same defect as F-001 and must be added to the stub in the same change.
- **Pre-concatenated printer arguments.** ~20 call sites build their line with `..` before handing it
  to `NS.Print`, which events-frames-taint-§8 asks call sites not to do. Not a bug today (none of
  those values can be combat-protected) and deliberately routed to `wow-addon:standards-audit`
  rather than swept here.
- **`core/PerfSetup.lua` does not exist.** `LibKa0s-Perf-1.0` is vendored (correctly — the whole
  folder is the unit of vendoring) but not wired. A recorded adoption decision in `CLAUDE.md`, not
  an oversight; the audit agent owns whether it should change.

---

## Verification evidence

- **Manual gate:** `docs/reviews/2026-08-03/03_SMOKE_TESTS.md`, with its sign-off table completed —
  including §C-01 and §C-02, which must be run against an install with `libs/LibKa0s` deliberately
  renamed away, and the 14-row regression table.
- **Automated gate:** `lua tests/run.lua` green (696 + the new cases from C-02 and C-03) and
  `luacheck .` at 0 warnings / 0 errors, on every individual commit, not just at the end
  (versioning-git).
- **Vendor gate:** `tests/test_vendor_sync.lua` green — `libs/LibKa0s` remains byte-identical to
  LibKa0s v1.5.0. **No file under `libs/` or `tests/_kit/` was touched by this cycle.**
- **Commit range / PR:** _fill in when the work lands._

---

## Suggested commit message / PR description

```
fix: the degraded slash stub crashed every /pm panel verb (F-001)

An install missing libs/LibKa0s falls back to the stub in settings/Slash.lua. The
stub publishes every schema verb and every host verb — but not FormatKV, which is
assigned after its early return and which the five panel-CLI call sites all use. So
/pm panel <name>, /pm panel <name> <field>, /pm panel <name> <field> <value> and
/pm panel <name> fitart each raised "attempt to call field 'FormatKV' (a nil value)"
in exactly the configuration the stub exists to survive.

The stub now answers it, with a deliberately plain `path = value` line rather than a
copy of the library's styled formatter — copying it is what slash-commands-§1 and
anti-patterns #47 forbid, and the copy is the one that goes stale. Two new degraded-
load cases pin the stub's whole member set and drive every /pm panel verb through it,
plus a guard that goes red if anyone "fixes" it by reaching for the library's function.

Also in this cycle:

- fix(registry): Registry.Sanitize skipped artBlend and artDesaturate, so an upgraded
  or hand-edited record kept an illegal blend mode and an unset flag through every
  write. Both now go through the same seams as every other artwork field, and a
  property test asserts no template field is ever skipped again. (F-002)
- chore: retire three published names with zero readers — SunnArt.Installed (renamed
  to the __ test-seam convention), C.MEDIA_FALLBACK, NS.Format. (F-003, F-006, F-007)
- docs: the README's artwork example and one smoke-test step named a catalog id that
  no longer exists, and a `/pm panel set …` grammar the dispatcher never implemented
  appeared in four comments and one smoke step. Both corrected; the architecture doc
  now lists the Panels page as the second consumer of PanelChanged. (F-004, F-005,
  F-008)
- refactor: name FitToArtwork's width-or-reason returns honestly. (F-009)

No schema bump; affected records repair themselves on the next write, so no /pm reset
is needed. No file under libs/ or tests/_kit/ was touched.

Review: docs/reviews/2026-08-03/
```
