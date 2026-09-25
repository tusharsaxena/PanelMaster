# 04 — Technical design (2026-09-23)

How to close every deviation in `02_DEVIATIONS.md` (17 roots and 2 dependents). The work is keyed
by ID and grouped by where it lands. **Upstream (LibKa0s, WowAddonStandards) lands first**, then
the whole-folder re-vendor, then the addon. Nothing here changes a stored path or a
`schemaVersion`.

## A. Upstream

### A1 — LibKa0s test kit: the prose gate skips every frozen store (`PM-041`, upstream half)

- **Where:** `../LibKa0s/testkit/test_prose.lua`, the `SKIPPED_DIRS` table (the vendored copy is
  `tests/_kit/test_prose.lua:209-213`).
- **Change:** add `"docs/superpowers/"` and `"docs/investigations/"`, so the list matches
  `documentation-§3`'s frozen-store list (*"`docs/audits/`, `docs/reviews/`, `docs/automated-tests/<run>/`,
  `docs/perf-analysis/<run>/`, `docs/revendor/<date>-v<tag>/`, `docs/superpowers/` and
  `docs/investigations/`"*). Add a kit self-test that a British spelling planted under each named
  frozen store is not reported, and that the same spelling one directory up is.
- **Release:** this is a kit revision (26) and a LibKa0s patch tag, following the library's own
  release order (changelog, then `testing-§11`'s kit-sync gate green in the library, then tag).
- **Risk:** it widens an exclusion. The added paths are frozen by rule, so no authored text leaves
  the gate. The self-test pins the narrowness.

### A2 — WowAddonStandards: two items for the documentation lane (`PM-038`, `PM-048`; not blocking)

- `open-evolutions` → *Migration-stamp ownership*: this addon is a worked instance of "declared
  default masks legacy accounts" (`defaults/Global.lua:8-20`, `febf108`). A ruling that sanctions
  "stamped by the runner, never declared in defaults" for AceDB hosts would turn `PM-038`'s row into
  compliance.
- `AUDIT.md` → the re-vendor check calls an unrecorded tag **High**, while step 5's table grades a
  missing record **Low**. Reconcile the two. This run graded by step 5 and says so in `PM-048`.

These are proposals for the owner. The addon work below does not wait on them: `PM-038` closes with
a register row either way.

## B. Re-vendor (after A1 is tagged)

### B1 — Whole-folder re-vendor of LibKa0s at the A1 tag (`PM-041` delivery, `PM-045` re-check)

- `cp -r ../LibKa0s/LibKa0s/. libs/LibKa0s/` and `cp -r ../LibKa0s/testkit/. tests/_kit/` from the
  **tag**. Move the provenance line at `CLAUDE.md:44` to the new tag in the same commit. Run
  `git update-index --chmod=+x tests/_kit/run-automated-tests.sh`.
- Gates: `diff -r` against the tag for both payloads must come back empty, and
  `tests/test_vendor_sync.lua` must be green.
- Write the tag's bundle under `docs/revendor/<date>-v<tag>/` (`01_DELTA.md`, `05_SUMMARY.md`).
- Re-derive every `tests/_kit/*:NN` citation in `DEPENDENCIES.md` against the new payload (`PM-045`).

### B2 — One consolidated re-vendor bundle for the backlog (`PM-048`)

- A single folder, `docs/revendor/<date>-v1.18.0-to-v1.53.0/`, containing `01_DELTA.md` (the span,
  the 25 tags, and the 32 commits that carried them, from `git log --since=2026-08-25 -- libs/LibKa0s`)
  and `05_SUMMARY.md` (what the sweeps adopted; "nothing, carried by a sweep" where that is the
  truth).
- Its `01_DELTA.md` first line names the span in the form the check reads:
  `# 01 — Delta: LibKa0s v1.18.0 → v1.53.0 (consolidated)`. Confirm that the playbook's
  recorded-side reader resolves **every** tag in the span. If the reader only takes the last
  version on the line, list every tag in the folder name or first line so the two-listing check
  comes back empty.
- Do not write a folder per tag.

## C. The addon: code

### C1 — The latch outranks unlock (`PM-034`, `PM-034a`) — **the High**

- **Where:** `modules/Canvas.lua:Render` (`:779-825`).
- **Shape:** after `applySpec(f, spec)`, check the latch first:

  ```lua
  if NS.Lifecycle and NS.Lifecycle:IsDown() then
    if NS.Unlock and NS.Unlock.StripOverlay then NS.Unlock:StripOverlay(f) end
  elseif NS.Unlock and NS.Unlock.Decorate then
    NS.Unlock:Decorate(f, rec)
  end
  ```

  This keeps one show decision (`slash-commands-§7`: enforced at the source). `StripOverlay`
  (`modules/Unlock.lua:181-190`) already hides the edges and the label, and turns off the mouse,
  `SetMovable` and drag. The session unlock state (`NS.State.unlocked`, `unlockedPanels`) is left as
  it is, so `NS.StandUp` → `RenderAll` restores the outlines from current state
  (`performance-§6`).
- **Rejected alternative:** force-locking in `NS.StandDown`. That writes session state as a side
  effect of disabling, loses the player's editing state on re-enable, and still leaves route B
  (untick *Lock frame* while disabled) open.
- **Tests (write first; they must fail against today's tree):** extend `tests/test_disabled.lua`
  step 5 with:
  - route A: unlock, then disable, and assert 0 shown and 0 mouse-enabled panel frames;
  - route B: disabled, then `S:Set("state.locked", false)`, with the same asserts;
  - route C: disabled, then `NS.Unlock:SetPanelUnlocked(id, true)`, with the same asserts;
  - after re-enable, assert the unlocked panels come back **outlined** (current state).

  Add `-- red under: call Unlock:Decorate unconditionally in Canvas:Render`.
- **Smoke test:** add a case to `docs/smoke-tests.md` for unlock, `/pm disable`, then confirm
  nothing is drawn and clicks reach the UI beneath.

### C2 — Registration survives a bad event name (`PM-035`)

- **Where:** `core/LifecycleSetup.lua` (a new file-local helper) and `core/PanelMaster.lua:63`.
- **Shape:** `local function safeRegister(event, handler)` runs
  `pcall(NS.addon.RegisterEvent, NS.addon, event, handler)`. On failure it appends
  `event .. ": " .. tostring(err)` to `NS.State.rejectedEvents` (a session list) and does
  `NS.Debug("Events", "rejected %s", event)`. It returns ok. `NS.StandUp`'s three calls and
  `OnInitialize`'s `PLAYER_LOGIN` go through it. `NS.StandDown` keeps its bare `UnregisterEvent`,
  which does not raise on an unknown name. `C_EventUtils.IsEventValid` is optional (the SHOULD).
- **Reachability:** `D:Diagnose()` (`core/DebugLogSetup.lua`) adds a line
  `rejected events: <n> (<names>)`. That is on the `debug` verb and console path, which the MUST names.
- **Tests:** use the kit mock's `M.__badEvents` (`events-frames-taint-§1`). Mark one of the three
  bad, stand up, then assert the other two registered and the name is recorded, and that
  `Diagnose()` prints it. Add a `red under` comment.

### C3 — TOC annotations (`PM-036`, `PM-037`)

- `PanelMaster.toc`, above `:56`:
  `# Util AFTER Constants, and that position is load-bearing: core/Util.lua takes NS.Constants as a FILE-SCOPE upvalue (local C), so a Util that loaded first would hold nil forever.`
- Above `:97`:
  `# Slash AFTER Schema, load-bearing: its dispatcher descriptor takes NS.SchemaRuntime's members as VALUES at file load (settings/Slash.lua:554-558).`
- Add one "conventional from here" note for `core\Namespace.lua` / `State` / `PanelMaster` /
  `Database`, the defaults group and `modules\Canvas.lua` / `Unlock.lua` (the SHOULD).
- `tests/test_harness.lua` already pins TOC order. No test change is needed.

### C4 — Lifecycle parity case (`PM-040`)

- **Where:** `tests/test_surface_parity.lua`, `tests/run.lua`'s `Kit.setSurfaceSource`, and
  `tests/degraded_env.lua` if it needs a Lifecycle-less file list.
- **Shape:** add `["LibKa0s-Lifecycle-1.0"] = NS.Lifecycle` to `Kit.setSurfaceSource`, then
  `test("Parity: the Lifecycle seam's degraded surface matches the live one", …)`, with the degraded
  arm built by `loadPartial` omitting `Lifecycle.lua` and a comment naming
  `grep -rn "NS\.Lifecycle[:.]" core modules settings`. `name` is a field rather than a member, so
  it goes in the `ignore` set with its reason if the kit's `publicMembers` walks it.
- Update `tests/test_surface_parity.lua:3` ("Seven"), `docs/testing.md:340-351`, and keep the two
  claims (`core/LifecycleSetup.lua:147-148`, `docs/module-map.md:19`), which become true.

## D. The addon: register, docs, issues

### D1 — Register maintenance (`PM-038`, `PM-038a`, `PM-039`)

- **PM-038:** add a row to `docs/ARCHITECTURE.md` → `## Documented deviations`:
  `| toc-file-§2 / savedvariables-§1 | schemaVersion is written by the migration runner (core/Database.lua:132, :158), not declared in NS.defaults.global | A declared AceDB default is served for a missing key, so every unstamped (legacy) account reads as current and the v1→v2 body never runs; M4-22 / febf108; open-evolutions "Migration-stamp ownership" | 2026-08-05 | The standard rules on migration-stamp ownership, or a PanelMaster schema bump that no longer needs a shape-driven legacy check |`.
  Then fix `docs/ARCHITECTURE.md:34` and `docs/common-tasks.md:12-13` (`PM-038a`).
- **PM-039:** this needs the owner's decision.
  - *Option (a), adopt:* `resolveRoot = function(parts, id)`. With an `id`, answer the panel record
    as the root, resolving `panels.<id>.<field>` or an instance-relative path, `first` and `id`.
    Register instance-relative rows for `C.PANEL_FIELD_TYPE`'s fields, route `Registry:Set` field
    writes through `NS.SchemaRuntime.Set(path, v, id)`, and retire the row. This is large. Size it
    before committing to it, and it wants its own `state:triaged` issue.
  - *Option (b), keep:* re-word the trigger to the host-side condition, re-date the row, and file a
    `state:triaged` issue with the option-(a) plan as the body.
  - Either way the register must stop being ambiguous.

### D2 — `compat-layer.md` (`PM-031`)

- A new `docs/compat-layer.md` with one section per shim (`AddOnFolders`, `GetScreenSize`,
  `GetUIScale`, `InCombat`, `RegisterMedia`, `FetchMedia`, `MediaList`, `MouseIsOver`): what varies,
  what the guard answers when the API is absent, and who calls it. It links `#53` for why none of
  the eight is a library member.
- Change `docs/ARCHITECTURE.md:327` to `| compat-layer.md | Present | 8 shims in core/Compat.lua (threshold is 3) |`.
- If `tests/test_docs.lua` pins the map, it picks the change up.

### D3 — Hub shape (`PM-042`)

- Move `docs/ARCHITECTURE.md:47-78` (the runtime adoption narrative, the stub, the Master controls
  composition) into `docs/schema.md` under `## The schema runtime`. Keep a summary of five lines or
  fewer, plus the registry naming at `:80-103` (mandated here) and one link.
- Collapse the retired-row narratives at `:380-428` to one line per retirement, citing
  `PM-029`, #48 and the bundle date.
- Rename `## Message bus (architecture-§4)` → `## Message Bus` and `## Taint` → `## Taint Notes`.
  Check `tests/test_docs.lua` for heading pins and update any it holds.
- The target is `wc -l docs/ARCHITECTURE.md` < 400.

### D4 — Module map covers the whole tree (`PM-043`)

- Add `## tests/` to `docs/module-map.md`: one row per non-suite file (`run.lua`, `wow_mock.lua`,
  `degraded_env.lua`, `prose_waivers.lua`) and one row per suite, or a suite-family table that names
  every file. Add `## tools/` with four rows. The re-check command is in `03_EVIDENCE.md` §10.

### D5 — Docs and comment sync (`PM-044`, `PM-045`)

- Recount and rewrite every row in `02_DEVIATIONS.md`'s `PM-044` table, including the
  `settings/PanelEditor.lua` comment blocks at `:178-190` and `:1191-1223`, which should say that
  `General` is back and the band is one row. Drop the `.gitignore:6` reference to the absent
  `wiki_import.py`, or re-point it at the script that writes `manifest.tsv.root` and `.stamps.tsv`
  if one does.
- Re-point `DEPENDENCIES.md:63`'s kit citations **after** B1 (they move again with the re-vendor),
  and cite by function name as well.

### D6 — README (`PM-046`)

- `README.md:51`, `:79-80`: write the arguments bare. Move the configuration signpost (`:67-69`) to
  the last line of Usage. Merge the two disabled-state paragraphs (`:86-95`) so Usage ends on the
  signpost. Run the `/humanize` pass (`documentation-§1`).

### D7 — Frozen specs (`PM-041`, host half)

- After B1, the gate no longer scans `docs/superpowers/`. Restore line 5 of both specs from
  `git show e30e329^:<path>`, then confirm the gate stays green. If B1 has to wait, add
  `skipDirs = { "docs/superpowers/" }` to `tests/prose_waivers.lua` first, with a reason; the gate
  permits a named directory. Remove it after B1 so there are not two exclusions for one rule.

### D8 — Issue store (`PM-047`) and the record (`PM-033`)

- Close #19, #20, #22 and #23 as `state:done`, and #24 as `state:will-not-do`, each with a one-line
  evidence comment (`gh issue close N --comment …` plus `gh issue edit N --add-label … --remove-label state:triaged`).
  Space the writes out.
- `PM-033`: at the next release, run the full four-suite bundle as a release run. Its
  `ANALYSIS.md` notes that 1.1.1 has no release bundle. There is no backfill.

## Ordering constraints

1. **A1 before B1 before D7.** The frozen-spec restore must not redden the gate.
2. **B1 before D5's `DEPENDENCIES.md` re-point.** Kit line numbers move on every re-vendor.
3. **C1 test-first.** The step-5 extension must be seen red against `afb30d7`'s behavior before
   `Canvas:Render` changes (`testing-§4`, `testing-§12`).
4. **C4 before D5's `testing.md` recount**, so the recount states seven parity cases rather than
   six.
5. **D1 `PM-039`** is the owner's decision and does not block anything else.
6. Regenerate `docs/test-cases.md` and the README `[tests]` badge in every commit that changes the
   case count (`testing-§5`).
