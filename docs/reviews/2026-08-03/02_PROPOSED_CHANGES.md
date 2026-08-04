# Ka0s Panel Master — Proposed Changes (HLD + LLD), 2026-08-03

Derived from `01_FINDINGS.md`. Nothing here has been applied.

**Standard resolved: Ka0s WoW Addon Standard v2.17.1 (2026-08-03).** The network fetch of
`raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master/standards/…` timed out in this
environment; the index and all 24 section files were read from the local clean `master` checkout
(commit `2141229`, working tree clean) instead. That is the same content the fetch would have
returned. No rule below is reconstructed from memory.

**Upstream change-set: none.** No defect was found in `libs/` or `tests/_kit/`, so there is no
cross-repo work and no re-vendor commit in this cycle. **No change in this document targets a path
under `libs/` or `tests/_kit/`.**

---

## HLD — themes

### Theme A — Make the degradation stubs answer what the addon actually calls (F-001, F-007)

**Rationale.** This addon consumes four LibKa0s majors, and its half of each contract is a
descriptor plus a stub. Three of the four stubs are exemplary — `core/DebugLogSetup.lua:81-124`
even writes down the `grep` that produced its member list, and `core/CoreSetup.lua:36-38` does the
same. The Slash stub does not, and it is the one that is wrong: `FormatKV` is assigned *after* the
stub's early `return`, and five host panel-CLI call sites use it. The class of bug is exactly what
debug-logging-§7 and slash-commands-§1 name — a member the stub omits is a crash relocated, not a
fallback.

The fix is therefore two-part and the second part is the durable one: publish the missing member,
**and** put a test in front of the member set so the next member added to the live path cannot
silently skip the stub again.

**Alternatives considered and rejected.**

1. *Copy the library's `FormatKV` body into the stub.* Rejected outright: slash-commands-§1 forbids
   the stub carrying "a copied row formatter, a copied parser, a copied `key = value` shape", and
   anti-pattern #47 names hand-copying the strings whose drift the extraction exists to end. The
   copy would also be invisible — it renders identically until the library's escapes change.
2. *Guard every call site (`if Sl.FormatKV then … else … end`).* Rejected: five guards restating one
   fact, and the sixth call site added later forgets. The seam is the stub, not the caller.
3. *Move the panel verbs behind the library too.* Rejected: they act on registry records, not schema
   rows (architecture-§5's storage carve-out), and `settings/Slash.lua:38-42` already argues this
   correctly. Pushing them upstream would be an additive descriptor field nobody else needs.
4. *Do nothing, on the grounds that a LibKa0s-less install is not a supported configuration.* Rejected:
   the addon has deliberately built four degradation paths and tests three of them; the configuration
   is supported by construction, and library-stack-§7's whole point is that the folder can be absent.

**Trade-off accepted.** The degraded `FormatKV` renders a visibly plainer line than the library's.
That is intended — a degraded install should *look* degraded — and it is what keeps the stub from
being a second copy of the formatter.

### Theme B — Close the `Sanitize` contract (F-002)

**Rationale.** `modules/Registry.lua` is the single write seam for panel records and its comment is
categorical: sanitizing runs on the way *in*, so "the stored file is always already valid". Two
fields escape it. The repair belongs in `Sanitize` rather than in a schema migration because
`Sanitize` is the seam every non-login route (import, copy-profile, `R:Set`, `R:CopyFrom`,
`R:ReloadProfile`) already passes through — a migration would only cover the login path and would
need a schema bump for a field-level default the template already states.

**Alternative rejected.** *Bump `NS.SCHEMA_VERSION` to 3 and stamp both fields in `RunMigrations`.*
Rejected: savedvariables-§1's runner exists for shape changes that cannot be expressed as a
per-record repair; this one can, and `Sanitize` already repairs `frameName` the same way
(`modules/Registry.lua:98-100`) with the migration merely being the bulk path. Adding a version bump
for it would also force every existing profile through a migration that changes nothing on a
correctly-shaped record.

### Theme C — Retire dead surface (F-003, F-006, F-007)

**Rationale.** Three published names have zero readers. Each is small; together they are the shape
that makes a codebase stop being trustworthy — a reader cannot tell which comments describe
behavior and which describe intentions. This addon already has a convention for the legitimate
case (a `__`-prefixed test seam, argued at `modules/Unlock.lua:273-284`), so each name has an
obvious correct destination: delete it, wire it, or `__`-prefix it.

### Theme D — Make the documentation executable again (F-004, F-005, F-008)

**Rationale.** Two documented commands cannot be run (`runic-sigil`; `/pm panel set …`) and one bus
consumer is unlisted. `docs/smoke-tests.md` is a *gate*, so a step that fails for the wrong reason
is worse than a missing step — it consumes a tester's attention and verifies nothing.
documentation-§5 makes keeping docs in sync a requirement; architecture-§4 makes documenting every
consumer of a bus message a MUST.

### Theme E — Naming honesty (F-009)

**Rationale.** Two call sites bind a failure sentence to a variable named for a width, and both
needed a comment to explain it. Renaming removes the comment as well as the confusion.

---

## LLD — change-set

Change IDs are `C-nn`. Each names its target file(s), the finding IDs it closes, the shape of the
edit, the risk, and its standards conformance.

---

### C-01 — Publish a degraded `FormatKV` from the Slash stub

**Covers:** F-001 (primary). **File:** `settings/Slash.lua` (stub block, currently lines 273-305).

**Before** — the stub returns without ever defining `FormatKV`; the live assignment is at line 369,
after the `return`:

```lua
  function Sl:OnSlash(input) … end
  return
end
…
Sl.FormatKV = lib.FormatKV
```

**After** — add to the stub, above its `return`:

```lua
  -- The panel verbs above are the addon's OWN and keep working, so the one formatter they share
  -- has to answer here too: settings/Slash.lua:101/156/157/169/176 all call it, and a stub that
  -- omitted it would move the library's absence into a crash inside `/pm panel` (slash-commands-§1,
  -- debug-logging-§7).
  --
  -- DELIBERATELY NOT the library's rendering. Copying FormatKV's gold-key/white-value escapes here
  -- is the copy that goes stale, and it is the exact duplication slash-commands-§1 and
  -- anti-patterns #47 forbid in a stub. A degraded install renders a plain, obviously-degraded line
  -- instead — which is also the honest signal that something is missing.
  function Sl.FormatKV(path, valueStr)
    return tostring(path) .. " = " .. tostring(valueStr)
  end
```

**Also decide `Sl:Text`** (F-001 secondary). It has no production caller today. Two compliant
options, pick one and write the reason down beside it:

- **(preferred)** leave it absent and add one line to the stub's opening comment saying so and why —
  matching how `core/DebugLogSetup.lua:163-181` records each *deliberately not passed* descriptor
  field; or
- publish `function Sl:Text(key) return tostring(key) end`, which is honest but risks reading as an
  invitation to render raw `SCREAMING_SNAKE` keys — the `L` trap the suite already has a tripwire
  for.

**Risk:** none to the live path — the stub block is unreachable when `libs/LibKa0s` is present, and
`tests/test_slash.lua:151-156` already pins that the *live* `FormatKV` is the library's.

**Standards conformance:** shaped by **slash-commands-§1** (the stub MUST carry every member the
addon calls; the stub MUST NOT re-implement the library's rendering) and **debug-logging-§7** (same
rule, stated for the sibling module). The rejected "copy the formatter" option would have violated
slash-commands-§1 and **anti-patterns #47**.

---

### C-02 — Pin the Slash stub's member set with a degraded-load test

**Covers:** F-001 (the durable half). **File:** `tests/test_libka0s.lua` (the `-- degradation`
block, after line 479).

Two cases, both built on the existing `loadDegraded()` helper — i.e. by *actually loading the addon
with the library files absent*, never by hand-stubbing `lib = nil`:

```lua
test("Degraded install: the slash stub answers every member the addon calls", function()
  local ns = loadDegraded()
  -- The list is `grep -n "Sl\.\|Sl:" settings/Slash.lua` for members reached from a host verb,
  -- plus every member settings/Panel.lua calls. FormatKV is on it because the PANEL verbs — which
  -- the stub's own comment promises keep working — print through it.
  for _, member in ipairs({ "OnSlash", "PrintHelp", "BuildListLines", "CliList", "CliGet", "CliSet",
                            "CliReset", "CliResetAll", "CliVersion", "LandingRows", "HelpRows",
                            "FormatKV" }) do
    assertTrue(ns.Slash[member] ~= nil, "the degraded slash stub cannot answer " .. member)
  end
end)

test("Degraded install: every /pm panel verb still answers", function()
  local ns = loadDegraded()
  local rec = ns.Registry:New("Degraded")
  assertTrue(rec ~= nil)
  for _, line in ipairs({ "Degraded", "Degraded width", "Degraded width 300", "Degraded fitart" }) do
    local ok, err = pcall(function() ns.Slash:CliPanel(line) end)
    assertTrue(ok, "/pm panel " .. line .. " raised in a degraded install: " .. tostring(err))
  end
end)
```

A third, cheap guard is worth adding beside them — that the degraded `FormatKV` is **not** the
library's function value, which is what would go red the day someone "fixes" C-01 by copying:

```lua
  local sl = mocks.LibStub("LibKa0s-Slash-1.0", true)
  assertTrue(ns.Slash.FormatKV ~= sl.FormatKV,
    "the degraded FormatKV is the library's — the stub is not actually degraded")
```

**Risk:** none. `pcall` around a verb that currently raises is the only thing that turns red before
C-01 lands, which is the correct TDD order (testing-§4: write the failing case first).

**Standards conformance:** **testing-§8** (a degraded path MUST be verified by loading the addon with
the lib missing, not by hand-stubbing the member under test) and **testing-§12** (a test that cannot
fail is worse than no test — hence the third guard, which fails on the forbidden fix).

---

### C-03 — Normalize `artDesaturate` and `artBlend` in `Registry.Sanitize`

**Covers:** F-002. **File:** `modules/Registry.lua`, in the `-- ── Artwork ──` block
(currently ending at line 205).

**Before:**

```lua
  rec.artFill     = enumMatch("artFill",     rec.artFill)     or t.artFill
  rec.artRotation = enumMatch("artRotation", rec.artRotation) or t.artRotation
  rec.artLayer    = enumMatch("artLayer",    rec.artLayer)    or t.artLayer
```

**After:**

```lua
  rec.artFill     = enumMatch("artFill",     rec.artFill)     or t.artFill
  rec.artRotation = enumMatch("artRotation", rec.artRotation) or t.artRotation
  rec.artLayer    = enumMatch("artLayer",    rec.artLayer)    or t.artLayer
  -- artBlend is a closed list like the three above and takes the same seam — its row already
  -- exists in C.PANEL_FIELD_ENUM. It was missed when the field was added, so an upgraded or
  -- hand-edited record could carry "MOD" through every write: harmless at render time
  -- (modules/Artwork.lua re-guards it) but a value `/pm panel <name>` then reports back as though
  -- the addon had accepted it.
  rec.artBlend    = enumMatch("artBlend",    rec.artBlend)    or t.artBlend

  -- The last unsanitized boolean on the record. Without it a record written before the field
  -- existed reaches the editor with nil, and the Desaturate checkbox shows unticked for a value
  -- that was never stored either way.
  rec.artDesaturate = rec.artDesaturate and true or false
```

**Risk:** low, and worth naming precisely. `enumMatch("artBlend", …)` up-cases its argument
(`modules/Registry.lua:47-62`), so a lower-case `"blend"` in a hand-edited file is now *repaired*
rather than replaced — an improvement, and consistent with the other three. A record already holding
a legal value is untouched, so no user-visible change occurs on a healthy profile.

**Test to add** (`tests/test_registry.lua`), the property rather than the two fields:

```lua
test("Registry.Sanitize: every template field is normalized, none skipped", function()
  local rec = {}
  NS.Registry.Sanitize(rec)
  for field in pairs(NS.Constants.PANEL_TEMPLATE) do
    assertTrue(rec[field] ~= nil, "Sanitize left template field '" .. field .. "' unset")
  end
end)
```

That case fails today on `artDesaturate` and — crucially — will fail again for the *next* field
somebody adds to the template and forgets, which is the actual defect class.

**Standards conformance:** stays inside the addon's single write path (**architecture-§5**: every
mutation routes through one helper). The rejected alternative — a `schemaVersion` 3 bump in
`NS:RunMigrations` — was declined because **savedvariables-§1**'s runner is for shape changes, and a
migration would cover only the login path while leaving import/copy/`R:Set` unrepaired.

---

### C-04 — Resolve `SunnArt.Installed()`

**Covers:** F-003. **File:** `modules/SunnArt.lua:246-248` (plus `tests/test_sunnart.lua` if
renamed).

Pick one, deliberately, and record the reason in the comment:

- **(a) delete** the function and the "keep the whole feature silent" paragraph above it, updating
  the seven `tests/test_sunnart.lua` assertions to call `#S.Themes() > 0` directly; or
- **(b) rename** to `S.__installed` — the repo's own convention for a seam with no production caller
  (`modules/Unlock.lua:273-284` states it and why) — and trim the comment to what it actually is; or
- **(c) wire it**, if the described gate is genuinely wanted: the honest caller would be the artwork
  dropdown's category emission in `settings/PanelEditor.lua:719-726`.

**Recommendation: (b).** The assertions it holds up are real and the function is cheap to keep; only
its advertised role is fiction. (b) is also the smallest diff and touches no test.

**Risk:** (a) and (b) touch the suite; (c) changes user-visible dropdown content and would need its
own smoke test. Do not pick (c) without one.

**Standards conformance:** neutral. **naming-cheatsheet** governs the `__` prefix for internals.

---

### C-05 — Delete `C.MEDIA_FALLBACK`

**Covers:** F-006. **File:** `core/Constants.lua:508-514`.

Delete the table and its comment. The rule it states is implemented — and correctly documented — at
`core/Compat.lua:120-135`, which returns `C.SOLID_TEXTURE`. If a reviewer prefers to keep the
indirection instead, the equivalent-and-also-compliant edit is to have `Compat.FetchMedia` resolve
`C.MEDIA_FALLBACK[mediaType]` and fall back to `C.SOLID_TEXTURE` — but that adds a lookup to buy
nothing, since all three entries are the same value.

**Risk:** none — zero readers, confirmed by `grep` including `tests/`.

**Standards conformance:** neutral.

---

### C-06 — Resolve `NS.Format`

**Covers:** F-007. **File:** `core/CoreSetup.lua:86` (and the stub block at `:34-69` if kept).

Either delete the line, or keep it **and** add the matching member to the degraded branch so the two
paths stay symmetric — the stub's own comment at `:36-38` enumerates the members it must answer, and
that list must move with the decision.

**Recommendation: delete.** `NS.Print` covers every call site; `Format` is a second entry point to
the same printer with no consumer, and leaving it half-published is precisely the asymmetry that
produced F-001 one file over.

**Risk:** none — zero readers repo-wide, including the suite.

**Standards conformance:** **events-frames-taint-§8** requires *one* shared secret-safe printer;
removing a second unused entry point moves toward that, not away.

---

### C-07 — Fix the artwork id in README and smoke tests

**Covers:** F-004. **Files:** `README.md:115`, `docs/smoke-tests.md:223`.

- `README.md:115`: `/pm panel ChatBG artTexture runic-sigil` → `/pm panel ChatBG artTexture class-mage`.
- `docs/smoke-tests.md:223`: `General: Runic Sigil (B&W)` → `Class: Mage` (the dropdown label
  `Artwork.List` actually produces for that row — `modules/Artwork.lua:676-684` composes it as
  `category .. ": " .. label`).

Leave `docs/superpowers/specs/2026-07-31-panel-artwork-design.md` alone: it is a frozen design
record of what was planned, and rewriting history there would be worse than the drift.

**Risk:** none. Verify the chosen id exists in the generated catalog block before committing — the
generator owns those rows and a future regeneration could rename them.

**Standards conformance:** **documentation-§1** (the README renders on GitHub *and* CurseForge —
keep the argument bare, no `<…>` placeholders, which the current line already does) and
**documentation-§5** (docs move with the code).

---

### C-08 — Correct the `/pm panel set …` grammar in five places

**Covers:** F-005. **Files:** `core/Util.lua:81`, `core/Constants.lua:151`, `core/Constants.lua:420`,
`modules/Artwork.lua:603`, `docs/smoke-tests.md:296`.

Each occurrence of `/pm panel set <name> <field> <value>` (and the two abbreviated forms) becomes
`/pm panel <name> <field> <value>`. `modules/Artwork.lua:603` additionally names the retired
`runic-Sigil` id and should become e.g. `/pm panel Chat artTexture Class-Mage`, which preserves the
point it is making (case-insensitive matching).

**Risk:** none — comments and one doc line. The `docs/smoke-tests.md:296` edit makes a previously
mis-firing gate step actually exercise the enum refusal it was written for.

**Standards conformance:** **documentation-§5**; slash grammar itself is unchanged, so
**slash-commands-§2/§3** are untouched.

---

### C-09 — Add the missing bus consumer to `docs/ARCHITECTURE.md`

**Covers:** F-008. **File:** `docs/ARCHITECTURE.md:288`.

The `Ka0s_PanelMaster_PanelChanged` row's consumer column becomes
`Canvas`, `the Panels settings page` — matching the `PanelsChanged` row above it, and matching
`settings/PanelEditor.lua:1045-1048`.

**Risk:** none.

**Standards conformance:** **architecture-§4** makes documenting every consumer a MUST — this change
is required by it, not merely permitted.

---

### C-10 — Rename the width/reason variables

**Covers:** F-009. **Files:** `settings/Slash.lua:152-160`, `settings/PanelEditor.lua:768-777`.

```lua
-- before
local ok, w, h = NS.Registry:FitToArtwork(rec.id)
…
print(w)   -- on failure the second return is the reason

-- after
local ok, widthOrReason, height = NS.Registry:FitToArtwork(rec.id)
if ok then
  print(Sl.FormatKV("width",  tostring(widthOrReason)))
  print(Sl.FormatKV("height", tostring(height)))
else
  print(widthOrReason)
end
```

The explanatory comments shrink to nothing, which is the point.

**Risk:** none — pure rename, no control-flow change. Note this file is also touched by C-01; see the
concurrency map in `04_EXECUTION_PLAN.md`.

**Standards conformance:** **naming-cheatsheet**; US English throughout (**localization-§5**) — no
new user-facing string is introduced.

---

## Not proposed, and why

- **F-010 (linear registry lookups).** No change proposed. An id→record index must be invalidated on
  create, delete, profile switch and profile copy, which is more moving parts than the measured cost
  justifies at this addon's panel counts. Recorded in `05_FINAL_SUMMARY.md` ▸ *Known follow-ups* so a
  future panel-cap increase reaches it.
- **The pre-concatenated printer arguments** noted at the top of `01_FINDINGS.md`. Out of scope for a
  review: it is a pre-existing conformance question across ~20 call sites and belongs to
  `wow-addon:standards-audit`, which is the agent chartered to measure the addon against
  events-frames-taint-§8 section by section.
- **No `core/PerfSetup.lua`.** Same reason — an adoption decision already recorded in `CLAUDE.md`,
  and a conformance question rather than a defect.
