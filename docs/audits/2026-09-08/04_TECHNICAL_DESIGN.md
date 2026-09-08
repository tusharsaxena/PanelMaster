# 04 — Technical design (2026-09-08)

How to close what `02_DEVIATIONS.md` catalogues. Four roots and one dependent; none of them touches
shipped Lua that a player runs, and that is the shape of this cycle rather than a coincidence — the
addon's behavioural findings were closed by the 2026-09-07 remediation, and what is left is a doc, a
test config, a missing test case and an observation about a record.

**Ordering constraint that spans two items.** `PM-032` (widen and canonicalize the spelling gate) and
`PM-032a` (the one word it will find) are **one change**, and the gate must be widened *before* the
word is fixed. Fixing the word first leaves the gate exactly as blind as it was and turns a proof
into a promise.

**Nothing here needs an upstream `LibKa0s` change.** `PM-030` was blocked on the shared mock and is
not any more: test-kit revision 15 is vendored (`tests/_kit/framework.lua:20`) and carries both
halves the case needs.

---

## PM-031 — write `docs/compat-layer.md`, then correct the map row

**Files touched:** `docs/compat-layer.md` (new), `docs/ARCHITECTURE.md` (one row).
**Files NOT touched:** `core/Compat.lua`. Nothing about the code is wrong; the trigger moved.

### Shape of the doc

`documentation-§3` puts Tier 2 docs under canonical names and asks them to be the topic detail the
hub links to rather than a second copy of it. `core/Compat.lua` already carries the reasoning
inline — the file's contract at `:5-7`, and a comment block above each shim explaining what varies
and why the guard returns what it returns. The doc's job is to make that readable **without opening
the file**, and to say which module depends on each answer, which the file itself cannot know.

Proposed structure, one page, roughly 100–140 lines:

1. **What this layer is** — one paragraph: every varying or optional client API is reached through
   `NS.Compat.X`, gated by a direct presence check, never by a game-flavour project id. Link to
   `module-map.md`'s `core/Compat.lua` row rather than restating it.
2. **The eight shims**, one subsection each, in file order, each answering three questions:

   | Shim | What varies | Absent-API answer | Callers |
   |---|---|---|---|
   | `AddOnFolders` `:27` | `C_AddOns.GetNumAddOns`/`GetAddOnInfo` vs the bare globals | `nil`, deliberately **not** `{}` — *"cannot tell"* and *"nothing installed"* must stay distinguishable | `modules/SunnArt.lua` pack discovery |
   | `GetScreenSize` `:56` | `UIParent` is a real frame in-game and a 0×0 stub headlessly | `nil` on a zero reading | `modules/Registry.lua` off-screen recovery |
   | `GetUIScale` `:65` | — | — | — |
   | `InCombat` `:79` | `InCombatLockdown` presence | `false` | `core/PanelMaster.lua`, `modules/Unlock.lua` |
   | `RegisterMedia` `:103` | LibSharedMedia presence | no-op | `core/MediaSetup.lua` |
   | `FetchMedia` `:124` | LibSharedMedia presence | `nil` | `modules/Canvas.lua` |
   | `MediaList` `:139` | LibSharedMedia presence | empty list | `settings/PanelEditor.lua` |
   | `MouseIsOver` `:164` | `MouseIsOver` presence | `false` | `modules/Canvas.lua` mouseover driver |

   The *Callers* column is the part worth writing: it is what turns the page from a restatement of
   the source into the thing an author reaches for before adding a ninth shim.
3. **What is deliberately not here** — the TOC-metadata reader, which moved to `core/EnvSetup.lua`
   over `LibKa0s-Env-1.0`. `documentation-§3` **forbids** re-documenting a `LibKa0s` shim, so this is
   a one-line pointer, not a section.

### The map row

`docs/ARCHITECTURE.md:145` changes from a *Not applicable* assertion to a *Present* row carrying the
count and the threshold, matching the form the `slash-dispatch.md` row at `:140` already uses:

```
| `compat-layer.md` | Present | 8 shims in `core/Compat.lua` (threshold is 3) |
```

The count is the thing to write, not the prose — it is what makes the row re-checkable by the same
grep next cycle.

### Risks

Low. The one real risk is the doc drifting from the file. `documentation-§3`'s trigger is a count, so
the cheap guard is a case in `tests/test_docs.lua` asserting that the number of `function Compat.`
definitions equals the number of shim subsections in `docs/compat-layer.md` — a ninth shim then
fails the suite until it is documented. That is optional and is proposed as such in
`05_EXECUTION_PLAN.md`; without it the page is correct today and unguarded tomorrow.

---

## PM-032 / PM-032a — canonicalize the spelling gate, then fix what it finds

**Files touched:** `tests/test_spelling.lua`, `docs/performance.md` (one word).
**Files NOT touched:** the standard. Any British form the canonical list misses is amended
**upstream first**; §5 says a private addition MUST NOT outlive the change that discovered it, and
this repo has no standing to add one locally.

### 1. The two lists, copied whole

Replace `tests/test_spelling.lua:41-59`'s 98 hand-grown entries with `localization-§5`'s published
`BRITISH` (91 entries) and add its `ALLOWED` (30 entries). The file's long rationale block at `:13-39`
is largely about why *this* list was shaped the way it was; most of it retires with the list. What
survives, and should be kept as a short header, is the two facts a reader still needs: that a locale
key **is** the English string, so a spelling drift is a key change; and that the lists are copied
from the standard and are not this repo's to extend.

**The half-word trick goes.** `:41-42` currently writes the first four entries in halves —
`"colo" .. "ur"` — so a repo-wide grep for the forbidden words comes back empty. That was a real
consideration and it is now handled by the standard instead: §5 exempts *"the gate's own copy of the
lists"*, so the entries can be plain string literals. Keeping the concatenation would make the copied
list textually unequal to the published one, which is precisely what "copied whole" forbids.

### 2. `ALLOWED` replaces the `-is` heuristic

`tests/test_spelling.lua:71-79`'s `hits()` matches an `-is` stem only when followed by `e`, `a` or
`i`. Delete it. The canonical algorithm is:

```lua
-- Delimit on non-letters, drop ALLOWED tokens as WHOLE WORDS, then run BRITISH
-- as substrings over what remains (localization-§5).
local function offenders(text)
  local lower  = text:lower()
  local scrub  = lower:gsub("%a+", function(w) return ALLOWED[w] and (" "):rep(#w) or nil end)
  local hits   = {}
  for _, b in ipairs(BRITISH) do
    if scrub:find(b, 1, true) then hits[#hits + 1] = b end
  end
  return hits
end
```

The substitution has to preserve length (or at least not join neighbouring words), or removing
*analysis* out of `"the analysis"` can manufacture a match across the seam.

**This is not a like-for-like swap and the difference should be expected.** The canonical list
carries stems the heuristic never had (`analys`, `paralys`, `synthesis`, `emphasis`, `practis`,
`recognis`) and relies wholly on `ALLOWED` to spare `analysis`, `paralysis`, `synthesis`, `emphasis`,
`specialist`, `organism`, `optimistic` and the rest. The existing matcher case at
`tests/test_spelling.lua:170-190` already asserts both directions on literals and should be **kept
and extended** with the canonical `ALLOWED` words, because it is the one thing that proves the swap
did not quietly turn the gate off.

### 3. The scan's scope, widened by walk rather than by hand

`authoredFiles()` derives the Lua set from the TOC and `run.lua` — keep that, it is the part that
cannot go stale. Replace the hand-named doc list at `:143-147` with a directory walk of `docs/`
plus the three root documents, and name the exclusions **directory by directory in the gate itself**,
which is what §5 requires:

```lua
-- localization-§5 names its exclusions one path at a time so the list cannot quietly grow.
local SKIP_DIRS = {
  "docs/audits/",          -- frozen dated bundles: the record, not living text
  "docs/reviews/",         -- ditto
  "docs/revendor/",        -- ditto
  "docs/superpowers/",     -- ditto (dated design specs)
  "docs/automated-tests/2", -- the frozen <run>/ folders; README.md and RESULTS.md are IN scope
}
```

A directory walk in pure Lua 5.1 has no portable `readdir`, so the practical form is
`io.popen("git ls-files 'docs/*.md'")` — which has the side benefit of covering exactly the tracked
set and nothing else. `tests/run.lua` already runs from the repo root, and `tests/test_docs.lua`
already shells out this way, so the pattern is established here.

**Expected effect: fifteen more `docs/` pages come into
scope**, and the gate goes red on `docs/performance.md`.

### 4. The word

`docs/performance.md:107`: `artefact` → `artifact`. One word, in the same commit, **after** the gate
is widened, so the suite is what proves it rather than a reviewer's eye.

### Risks

The real risk is the widened scan reddening on something this audit's sweep did not see, because the
sweep used the canonical lists but the repo's own exclusion set. That is a feature — anything it
finds is a real `localization-§5` MUST failure — but it can turn a one-word commit into a five-word
one. The sweep in `03_EVIDENCE.md` § 6 covered 84 files and found exactly the three named there, so
the surprise budget is small.

The second risk is the opposite: a canonical entry that reddens on a **correct** word this repo uses.
The candidates are `grey` (already carried and green), `programme` (spared by `ALLOWED`'s
`programmer`/`programmed`) and `mould` (no US homograph in this tree). None is expected to fire, and
if one does, the answer is `ALLOWED` upstream, never a local subset.

---

## PM-030 — the wrapped-strip geometry case

**Files touched:** `tests/test_panel.lua` (one case), possibly `tests/wow_mock.lua` (one seam).
**Files NOT touched:** `libs/LibKa0s/`. The pitch measurement is the library's and is audited in its
own repo; this is the **consumer-side** guard `testing-§12` asks for.

### What the case has to be able to fail

`libs/LibKa0s/OptionsWidgets.lua:441-455` measures the wrapped strip's row pitch by calling
`tex:SetAtlas(TAB_ATLAS[false][1], true)` on a probe texture and reading `GetHeight()`, caching into
`measuredArtH` (`:421`, assigned `:452`). The invariant is that the number comes from the
**unselected** art and is therefore the same whichever tab is active. The case must die under either
mutation: `TAB_ATLAS[false][1]` → `TAB_ATLAS[true][1]`, or deleting the `:452` cache.

### Why it is writable now and was not on 2026-09-07

The 2026-09-07 bundle reported it as unwritable because `tests/_kit/mock_base.lua` answered
`GetHeight() → 0` for every frame and every atlas — a harness that cannot report two different
heights cannot fail the invariant. Kit 15 changed that in two additive ways:

- `tests/_kit/mock_base.lua:153` — `SetAtlas(name, useAtlasSize)` records the atlas name and, when
  `useAtlasSize` is true, a size from the kit's published `ATLAS_SIZES` table (`:68`).
- `tests/_kit/mock_base.lua:141` — `f:__setGeom(w, h)` arms geometry explicitly, and `:132`'s
  `GetHeight` answers the recorded value once `__geomLive` is set.

`:136-140` states why the arming is opt-in rather than automatic, and it is exactly this call path:
*"`OptionsWidgets.lua` measures its tab pitch by calling `SetAtlas` on a probe texture it builds
itself, so a `SetAtlas` that armed geometry on its own would silently switch"* the behaviour under
every existing consumer. So the case arms deliberately, which is the intended use rather than a
workaround.

`tests/wow_mock.lua:165` still defines `GetHeight` as `reader("__h")`, so this addon's own mock frames
answer `__h` and not the kit's `__geomH`. The case has two clean options and the second is preferred:

1. Arm `__h` on the probe texture through the addon mock's own `SetHeight`.
2. Give `tests/wow_mock.lua`'s `SetAtlas` a per-atlas height keyed off the kit's `ATLAS_SIZES`, so
   the addon mock and the shared kit answer the same question the same way. This is the one that
   makes the case a **fidelity** improvement rather than a local fixture, and it is what
   `PANELMASTER-A-07`'s triage note pointed at — *"wow_mock's `reader("__h")` is the effective
   definition, and `SetAtlas` never writes `__h`."*

### The case

Against the **Panels** page, which has five tabs (`settings/PanelEditor.lua:190-194`) and is the page
that actually wraps at a settings-canvas width:

```
test("Panels page: the tab strip's band and row offsets do not move with the selection", function()
  -- selected art deliberately TALLER than unselected, so a pitch read off the wrong
  -- one is a different number rather than the same number by luck.
  ... arm the atlas heights ...
  local shape = {}
  for _, tab in ipairs(EDITOR_TABS) do
    ctx.activeTab = tab
    drawTabStrip(ctx)
    shape[tab] = { band = <reserved height>, ys = { <every row's y offset> } }
  end
  -- assert every entry of `shape` is deep-equal to the first
end)
```

Two things make or break it, and both are assertions about the test rather than about the code:

- **The width must force a wrap.** Five tabs at one row proves nothing; the invariant is about
  wrapped rows. Set the container width so the strip is two rows, and assert that it is two rows
  before asserting anything about their offsets — otherwise a future label change silently reduces
  the case to a one-row tautology.
- **The mutation check is part of the work, not a follow-up.** Run the case with
  `TAB_ATLAS[false][1]` swapped to `TAB_ATLAS[true][1]` in the vendored copy, confirm red, then
  `git checkout -- libs/LibKa0s/OptionsWidgets.lua`. A case that has never been seen red is a case
  `testing-§12` calls green against nothing.

### Risks

Touching `tests/wow_mock.lua`'s `SetAtlas` reaches every suite that draws a strip — `test_panel.lua`
is 1222 lines and much of it is page rendering. The mitigation is the kit's own: make the height
opt-in (armed by the case) rather than global, so every existing case sees the same `0` it sees
today and the pass count moves by exactly one.

`tests/test_panel.lua` is in the `layout-§1` 1000–1500 band at 1222 lines and its census row
(`docs/ARCHITECTURE.md:292`) sets a re-check at 1400. One case does not reach that, but it is worth
knowing the number before adding to the file.

---

## PM-033 — nothing to design

The fix is *run the runner at the next tag*, which is the release process working as specified. No
file changes. It appears in `05_EXECUTION_PLAN.md` only so it is not lost, and it is explicitly
**not** a reason to gate a commit on complexity.

---

## What this design deliberately does not do

- **It does not touch `libs/LibKa0s/`.** Both `diff -r` runs are empty against the tag the provenance
  line names, and editing a vendored copy is anti-pattern #45 whatever the reason.
- **It does not add a `docs/compat-layer.md` row to `## Documented deviations`.** A Tier 2 doc whose
  trigger has fired is a doc that is owed, not a deviation to ratify. `documentation-§3` says so
  explicitly: *not applicable* is a map row, never a register row, and the same logic runs the other
  way for *not written*.
- **It does not re-open the three `options-ui-§16` blocks.** Their register rows are eight days old,
  their triggers were evaluated this run and have not fired, and the upstream carrier (issue #48) is
  open. Re-litigating a ratified decision on the same evidence is the failure the register exists to
  prevent.
- **It does not split `settings/PanelEditor.lua`.** At 1488 it complies with `layout-§1`; the peel is
  owed and is tracked as issue #47 with a named seam, which is one of the three terminal states the
  amended `layout-§1` allows.
