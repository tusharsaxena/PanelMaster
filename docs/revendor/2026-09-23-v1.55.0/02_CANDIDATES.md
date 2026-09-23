# 02 — Candidates: LibKa0s v1.55.0

Run: 2026-09-23, Steps 5–8 of `/wow-addon:revendor-libka0s`, taken by a workflow subagent (Phase 6
of the 2026-09-22 suite sweep) under the owner's CP-6 delegation: the interview is replaced by the
decision rules the orchestrator relayed, and each call is recorded with its reason in
`03_DECISIONS.md`. Branch `suite/2026-09-22-standards-sweep` @ `b7edc9f` (the re-vendor commit).

Sources, in the playbook's order:

- `git -C ../LibKa0s log --oneline v1.54.2..v1.55.0` (eight commits, listed in `01_DELTA.md`).
- The v1.55.0 block of `../LibKa0s/CHANGELOG.md` (`:13` onward; the three majors at `:39`–`:89`).
- The three new API documents: `../LibKa0s/docs/api/Compat/version-1-docs.md`,
  `../LibKa0s/docs/api/Bus/version-1-docs.md`, `../LibKa0s/docs/api/Schema/version-1-docs.md`. No
  existing major's minor moved (`01_DELTA.md` 3c), so there is no old/new document pair to diff.
- The candidate source the delegation names: the per-consumer adoption deltas in the sweep's design
  specs, `Ka0sAddonsCommonTasks/docs/2026-09-22-SUITE_STANDARDS_AND_LIBKA0S_SWEEP/3b-specs/`
  `compat.md` §8 (`:429`–`:545`), `bus.md` §12 (`:538`–`:640`) and `schema.md` §11 (`:465`–`:577`),
  each read with its "every consumer" common block.
- This repo's issue store (`gh issue list --search "LibKa0s" --state all`) and `docs/`, for a
  recorded reason to decline. None of the three new majors has one. The earlier structural declines
  (#31 Perf, #43 Widgets, #45 Item, #46 Pool) are other majors and are not re-opened.

## Contract blockers (3g)

None. `01_DELTA.md` 3g found the moved-minor set intersected with the consumed set empty.

## Class A: reached the addon on the re-vendor alone

- **Kit revision 25.** The kit's layout-§1 cap gate (`tests/_kit/test_layout_cap.lua`), the
  `.gitattributes` body case in `test_eol`, the (basename, directory) suite key and the commit SHA
  in the automated-test record. Wired in the Phase 5 commit `b7edc9f`; the runner needs no
  `Kit.layoutCap` input (the census lives in the default hub, `docs/ARCHITECTURE.md`) and no
  `Kit.prose.exempt` (this repo ships no generated data).
- **Three new majors loaded and unused.** `Compat.lua`, `Bus.lua` and `Schema.lua` load from
  `LibKa0s.xml`. They are additive: every existing file's minor is unchanged (`01_DELTA.md` 3c), so
  nothing this addon consumes behaves differently.

## Class B: host change required

None. The CHANGELOG block names no new descriptor field, row type or seam on a major this addon
already consumes. The two kit inputs (`Kit.layoutCap`, `Kit.prose.exempt`) are covered under
class A: this repo needs neither.

## Class C: whole-module adoption

Ordered by the playbook's rule (live defect, then recorded gap, then new capability; ties by the
smallest blast radius). None of the three fixes a live defect.

### C-1. `LibKa0s-Schema-1.0` as the settings runtime — full adopter

- **What.** The dotted-path primitives, the row index, the single write seam `Set`, the bulk bracket
  and `Validate` move from `settings/Schema.lua` onto one library instance. The host keeps its rows
  and every public name (`NS.Schema:Set`, `:Get`, `:FindRow`, `:Default`, `:Register`,
  `S.BulkBegin`, `S.BulkEnd`, `S.BulkLine`), so no call site moves.
- **Evidence.** CHANGELOG `:78`–`:89`; `docs/api/Schema/version-1-docs.md` "Instance surface"
  (`:115`), "The `Set` pipeline" (`:146`), "The degradation stub" (`:284`), "A gate in front of the
  seam" (`:375`), "Adoption notes" (`:385`); `schema.md` §11 common block `:465`–`:483` and the
  PanelMaster delta `:569`–`:577`, which names this repo a **full adopter**.
- **Files.** `settings/Schema.lua` (the seam, the stub, the minimap row's `get`/`set`),
  `settings/OptionsSetup.lua:180`–`:191` and `settings/Slash.lua:552`–`:556` (descriptors bound to
  instance members), `tests/run.lua` (surface source), `tests/test_schema.lua`,
  `tests/test_debuglog.lua`, `tests/test_surface_parity.lua`, `tests/test_libka0s.lua`,
  `docs/ARCHITECTURE.md` → `## Settings Schema`.
- **Recommendation: adopt.** The spec prescribes it for this repo and does not offer a deferral
  (the MAY-defer clause is for the partial adopters AuraMaster and MultiMeters only).
- **What the survey found against this host.** `S:Set` already refuses an unknown path, already
  deep-copies a stored table, already propagates a raising `onChange`, already logs before
  `onChange` and already uses a first-match `FindRow`, so five of the seven behavior changes the
  API document lists (`:387`–`:393`) are no change here. The two that are: (a) `default == nil`
  means no restore, which the `state.debugConsole` row depends on today (JC-5, fixed by
  `defaults.debugConsole = false`); (b) `Validate` also checks `type`, `group` and duplicates,
  and it prints in the library's wording. The refusal texts are restored through `descriptor.L`.
  No pre-seam gate: the minimap inversion is the only branch in front of the store, and the spec
  moves it onto the row's own `get`/`set`.
- **Blast radius: replaces host code.** About 160 lines of walker, index, seam and bracket code in
  `settings/Schema.lua` are removed. A host stub comes in for the library-absent load. The snapshot
  count (`SnapshotPersisted` / `CountChangedSince`) MAY stay (`schema.md` §6) and does.

### C-2. `LibKa0s-Bus-1.0` `Catalog` over the two module-scoped message tables — optional

- **What.** Wrap `modules/Registry.lua:19`–`:20` (`MSG_PANELS`, `MSG_PANEL`) and
  `settings/Schema.lua:31` (`MSG_SETTINGS`) in `Bus.Catalog`, one call per owning module, for the
  strict read (a mistyped key raises for a publisher as well as a subscriber).
- **Evidence.** CHANGELOG `:65`–`:77`; `docs/api/Bus/version-1-docs.md` "`Catalog`" (`:184`);
  `bus.md` §12 PanelMaster `:638`–`:640` ("compliant today by the module-scoped shape; not debt.
  Optional"), §6 `:318`–`:319` ("can use `Catalog` too ... Not required").
- **Files.** `modules/Registry.lua`, `settings/Schema.lua`, a Bus stub, a parity case.
- **Recommendation: not now.** The spec itself marks it optional for this repo. The record half
  (`New` / tracked targets) is not offered at all: the factory `core/PanelMaster.lua:20`–`:26`
  stays, per the same paragraph.
- **Blast radius: additive** (a strict copy of three constants), but it needs a stub and a parity
  gate to guard three string constants that are each spelled once today.

### C-3. `LibKa0s-Compat-1.0` — no member fits

- **What.** Nine members: the secret seam (`IsSecret`, `CanAccess`, `IsSafeKey`) and six spell and
  specialization readers.
- **Evidence.** CHANGELOG `:52`–`:64`; `docs/api/Compat/version-1-docs.md` "Lib-level surface"
  (`:43`); `compat.md` §8.8 `:542`–`:545` ("No member adopted: ... PanelMaster's Compat are wholly
  addon-specific (section 5.3)") and §5.3 `:279` (PanelMaster's members: `AddOnFolders`, screen
  size, UI scale, `InCombat`, LSM media, `MouseIsOver`).
- **Confirmed in this tree.** `core/Compat.lua` defines `AddOnFolders` (`:27`), `GetScreenSize`
  (`:56`), `GetUIScale` (`:65`), `InCombat` (`:79`), `RegisterMedia` (`:103`), `FetchMedia`
  (`:124`), `MediaList` (`:139`) and `MouseIsOver` (`:164`). A grep over `core modules settings` for
  the nine member names and `issecretvalue` finds no caller.
- **Recommendation: never.** A structural misfit the spec records: this addon reads no spell, no
  specialization and no secret value. The re-vendor already delivered the file (class A).
- **Blast radius: none** (nothing to replace).
