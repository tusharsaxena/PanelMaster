# 01 — Current state (2026-09-23)

Standards-compliance snapshot of **Ka0s Panel Master** (`PanelMaster`), read-only.

## Provenance

| Item | Value |
|---|---|
| Standard audited against | **Ka0s WoW Addon Standard v2.64.0 (2026-09-23)**: `standards/STANDARDS.md` plus all **27** section files its Sections list links, and `standards/ADDONS.md` |
| Standard source | `https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`, `master` = `e68795f5cd64` (`git ls-remote`, this run). Fetched with `curl -fsSL`, read verbatim |
| Playbook | `AUDIT.md` from the same commit |
| Repository kind | **Addon.** It has a `.toc` (`PanelMaster.toc`) and a row in `ADDONS.md` (`ADDONS.md:26`). The whole addon rule set applies |
| Tree audited | `afb30d7` on `feat/2026-09-23-review-audit-remediation`. Clean except an untracked `docs/reviews/2026-09-23/`, which a concurrent review run wrote; it is not this audit's output and was not read as evidence |
| Bounded runner | `~/.claude/wow-addon/bin/ka0s-bounded` exists; it is not on `PATH`, so every heavy run used its absolute path. The `timeout 900` fallback was not needed |
| Prior runs | `docs/audits/2026-07-30`, `-08-04`, `-08-05`, `-09-07`, `-09-08`. The ID prefix **`PM-`** is reused. `PM-001`…`PM-033` are taken. New IDs this run start at **`PM-034`** |

## 1. Layout (`layout`)

- Modular skeleton present: `core/` (12 files), `defaults/` (2), `modules/` (6), `settings/` (6),
  `locales/` (2), plus `media/`, `libs/`, `tests/`, `tools/`, `docs/`. No source sits loose at the root.
- **Authored-Lua census:** `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'` returns **60**
  files: 28 source and 32 under `tests/`. Nothing is over 1500 lines. Four files are in the
  1000–1500 band: `settings/PanelEditor.lua` (1476), `tests/test_artwork.lua` (1356),
  `tests/test_panel.lua` (1353) and `modules/Artwork.lua` (1188).
- **Census heading:** `docs/ARCHITECTURE.md:430` `### Files over the 1500-line cap`, nested under
  `## Documented deviations` (`:350`), reading "Nothing is over the cap today" (`:442`). It agrees
  with the tree. The kit's gate is wired by the pair form (`tests/run.lua:111`) and passes.
- **Generators:** `tools/artwork/{artwork_cleaner,make_poster,update_catalog}.py` and
  `tools/sunn/build_manifest.py`, all under `tools/` and all ignored by `.pkgmeta`. Each opens with
  `#!/usr/bin/env python3` and each has 0 CR bytes. `DEPENDENCIES.md:102-111` names the
  interpreter and the packages.
- **Media:** `media/logos/` (5 files), `media/screenshots/`, `media/poster/`, and
  `media/artwork/<type>/` (this addon's own subject matter). There is no `fonts/`, `icons/` or
  `textures/` copy of the shared payload.
- **Logo:** `media/logos/panelmaster.logo.128.tga` header bytes are `0 0 2 … 128 0 128 0 32 8`,
  which means type 2 (uncompressed), 128×128, 32 bpp. The landing logo `panelmaster.logo.tga` sits
  beside it.

## 2. TOC (`toc-file`)

`PanelMaster.toc:1-13`, field order as templated: `Interface: 120100`, `Title: Ka0s Panel Master`,
Notes, Author, `Version: 1.1.1`, `IconTexture: Interface\AddOns\PanelMaster\media\logos\panelmaster.logo.128.tga`,
`SavedVariables: PanelMasterDB` (one global, because the `Perf` decline is ratified), OptionalDeps,
DefaultState, `Category-enUS: UI`, `X-License: MIT`, `X-Standard`, `X-Curse-Project-ID: 1642836`
(the addon is published). Section headers run Libraries → Locales → Core → Defaults → Modules →
Settings. `libs\LibKa0s\LibKa0s.xml` is listed once (`:36`) and the file ends with a single CRLF.

**Load-bearing positions.** These are annotated: `core\MediaSetup.lua` (`:48-52`),
`core\CoreSetup.lua` (`:57-59`), `core\DebugLogSetup.lua` (`:60-63`), `core\LifecycleSetup.lua`
(`:64-68`), `core\LauncherSetup.lua` (`:71-75`) and `settings\OptionsSetup.lua` (`:99-102`). Two
are **not** annotated: `core\Util.lua` (`:56`) takes `local C = NS.Constants` at file load
(`core/Util.lua:4`), and `settings\Slash.lua` (`:97`) resolves `NS.SchemaRuntime.Get/Set/FindRow/AllRows/ApplyDefault`
at file load (`settings/Slash.lua:532`, `:554-558`). These are `PM-037` and `PM-036`.

## 3. Libraries (`library-stack`)

- Vendored under `libs/`: LibStub, CallbackHandler, AceAddon/Event/Timer/Console/DB/GUI/Config,
  AceDBOptions, LibSharedMedia, AceGUI-SharedMediaWidgets, LibDataBroker-1.1, LibDBIcon-1.0 and the
  whole `libs/LibKa0s/` (24 top-level entries, 146 files).
- **Provenance:** `CLAUDE.md:44` reads `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.55.0 (MIT).`.
  `README.md` has no such line.
- **Drift check against the tag:** `diff -r` between `v1.55.0:LibKa0s` and `libs/LibKa0s`, and
  between `v1.55.0:testkit` and `tests/_kit`, both came back **empty**
  (`03_EVIDENCE.md` §3). The vendored kit is revision 25.
- **Adopted majors, 9 of 15:** Core (`core/CoreSetup.lua`), Env (`core/EnvSetup.lua`), Media
  (`core/MediaSetup.lua`), DebugLog (`core/DebugLogSetup.lua`), Lifecycle
  (`core/LifecycleSetup.lua`), Launcher (`core/LauncherSetup.lua`), Slash (`settings/Slash.lua`),
  Options (`settings/OptionsSetup.lua`) and Schema (`settings/Schema.lua:375`,
  `NS.SchemaRuntime`). Declined: Perf (ratified row), and Widgets, Item, Pool and Compat
  (`state:will-not-do` #43, #45, #46 and #53; adoption is optional, so no register row is owed).
  Bus is `state:triaged` #52 (optional; `architecture-§4` permits module-scoped constants).
- **Stubs:** each adopted seam has a library-absent branch. `tests/test_surface_parity.lua` pins
  six of them (Core, DebugLog, Launcher, Slash, Options, and Schema on both levels). Env and Media
  branch inside the same functions, so their degraded surface cannot diverge from the live one.
  Lifecycle has a separate stub table (`core/LifecycleSetup.lua:149-190`) and **no** parity case
  (`PM-040`). The Schema stub is the runtime-completing shape and cites its API document
  (`settings/Schema.lua:200-212`).

## 4. Architecture and patterns (`architecture`, `events-frames-taint`, `compat`)

- `core/PanelMaster.lua:4` calls `NewAddon(NS, …)` and `:13` reclaims `NS.Print` from
  `NS.Util.print`.
- **Bus:** three messages, each declared once as a module-scoped constant:
  `modules/Registry.lua:19-20` and `settings/Schema.lua:31`. The literal grep over call sites
  returns 0 hits. Every event name is PascalCase. Receivers register on their own targets
  (`modules/Canvas.lua:873-881`, `settings/PanelEditor.lua:1444`, `:1455`), made by
  `NS.NewBusTarget` (`core/PanelMaster.lua:20-26`).
- **Events:** PLAYER_ENTERING_WORLD and PLAYER_REGEN_ENABLED/DISABLED are registered by `NS.StandUp`
  (`core/LifecycleSetup.lua:126-129`), and PLAYER_LOGIN by `OnInitialize`
  (`core/PanelMaster.lua:63`). Each is a bare `RegisterEvent` call: no per-event `pcall` and no
  record of rejected names (`PM-035`).
- **Compat:** `core/Compat.lua` publishes 8 shims, counted with documentation-§3's own grep. No
  flavor branching and no deprecated spell or spec APIs (`03_EVIDENCE.md` §9).
- **Secret values:** the only Unit API referenced is `UnitClass`, and no trigger-set API is called.
  The ratified `events-frames-taint-§8` row stands.
- Frames are non-secure, and the one `OnUpdate` is `modules/Canvas.lua:666`: the 10 Hz mouseover
  driver, removed when the tracked set empties (`:684`).

## 5. SavedVariables (`savedvariables`)

- AceDB with `profile` (`panels`, `nextID`, `settings`) and `global` (`minimap`)
  (`defaults/Profile.lua`, `defaults/Global.lua:73-76`). `NS.SCHEMA_VERSION = 2`
  (`core/Namespace.lua:14`). The migration runner is `core/Database.lua:129-161`, with a real
  v1→v2 body.
- `schemaVersion` is **deliberately not declared in the defaults** (`defaults/Global.lua:8-20`):
  AceDB would backfill it as current and mask legacy accounts. This is the hard case
  `open-evolutions` records. The reasoning exists only in that code comment, and the register has
  no row for it (`PM-038`).
- `or`-defaulting sweep of the 96 commits since the last audit (`daa4981..HEAD`): no new
  `stored.k or D.k` over a user-choice field.

## 6. Settings (`options-ui`, `launcher`, `preview-mode`)

- **Library wiring:** `NS.Helpers = lib:New(...)` in `settings/OptionsSetup.lua`. The panel open is
  the library's and its combat gate is in `settings/Panel.lua:531-547`. The grep for
  `SettingsPanel|HideUIPanel|ToggleGameMenu|OpenToCategory` hits only `Panel.lua:542`, a presence
  guard.
- **Pages and tabs** (from the schema):
  - Landing: `buildMain`, exempt from tabs.
  - General: **Master controls** (composed, 7 rows), **Editing** (4), **New panels** (4).
  - Panels: **General**, Position and size, Background and border, Accent bar, Artwork, Opacity
    and fade. The band holds the picker and the create box on one row
    (`settings/PanelEditor.lua:1224-1322`), and `General` is first (`:209-211`). This is
    `options-ui-§14`'s v2.40.0 escape, and all three conditions hold.
  - Profiles: AceConfig, exempt.
- **Master controls:** composed by `H.MasterControls` (`settings/Schema.lua:410-452`). It passes
  `minimapPath`, `debugConsolePath` and the reset hooks. It passes no `testModePath`, because
  unlocking is the preview (the `options-ui-§15` exemption, and ADDONS.md rung (b)).
- **Colors:** no `disabledIf` on any color row. The three `options-ui-§16` blocks on Panels are
  composed through the record-backed `bind` arm (`tests/test_options_groups.lua`). No scroll arrows.
- **Global reset:** `db:ResetProfile()`, confirmed with the verbatim text at `settings/Slash.lua:73`
  and the house button pair at `:77`.
- **Launcher:** `core/LauncherSetup.lua` builds one `LibKa0s-Launcher-1.0` object with
  `label = NS.BRAND` ("Ka0s Panel Master", `core/Namespace.lua:33`) and `icon = C.ICON_PATH`
  (`core/Constants.lua:625`). Left-click toggles `state.locked` through `NS.Schema:Set`, and is
  refused while the addon is disabled. `minimap.hide` is global, and no reset reaches it
  (`docs/ARCHITECTURE.md:215-222`, pinned by `tests/test_launcher.lua`).

## 7. Slash (`slash-commands`)

- `/pm` and `/panelmaster` go through `LibKa0s-Slash-1.0` (`settings/Slash.lua:532-585`).
  `NS.COMMANDS` (`:285`) holds **19** verbs: config, enable, disable, new, delete, rename, panels,
  panel, unlock, lock, recover, version, get, set, list, reset, resetall, debug and help. `perf` is
  reserved and deliberately unregistered (ratified Perf row).
- **Disabled surface:** the library gate (`isEnabled` and `brandName`, `:541-546`) leaves every
  reserved verb, the schema CLI and bare `/pm` live, and refuses only feature verbs, on one line.
  That is `slash-commands-§2` as restored in v2.57.0. No prior bundle graded this area against
  v2.56.0's two-verb surface.

## 8. The disabled state (`slash-commands-§7`)

- **Latch:** one `LibKa0s-Lifecycle-1.0` instance (`core/LifecycleSetup.lua:196-206`) with two
  named holds. Stand-down (`:93-104`) unregisters the three events and the three renderer
  messages (`modules/Canvas.lua:893-899`), and the mouseover `OnUpdate` goes through the show
  ladder. Survivors: PLAYER_LOGIN (setup) and the Panels page's two refresh subscriptions. The
  second is recorded in `open-evolutions` rather than ruled, so it is not filed.
- **Suite:** `tests/test_disabled.lua` is listed in `tests/run.lua:101` and asserts on the mock's
  registration set. Steps 1, 3–10, 7b, 9b and 10b are present, and steps 3, 6 and 10 carry
  `red under` comments. All pass.
- **Defect found:** the stand-down rung (`modules/Canvas.lua:802`) is overridden by
  `NS.Unlock:Decorate` (`:823` → `modules/Unlock.lua:176-177`). An unlocked panel is **shown and
  mouse-enabled while the addon is disabled**. This was reproduced headlessly
  (`03_EVIDENCE.md` §1). It is `PM-034`. The suite never drives the unlocked state (`PM-034a`).

## 9. Debug (`debug-logging`)

`core/DebugLogSetup.lua` builds `lib:New{ name, addonName, title, font = C.FONT_MONO, isEnabled, setEnabled, print (forwarder), initSummary, onVisibilityChanged, slash }`
and binds `NS.Debug = NS.DebugLog.Debug`. It has a member-answering stub with `D:Diagnose`
attached on both arms, and a session-only flag (`NS.State.debug`). The close-button grep returns
only the wrapper at `core/CoreSetup.lua:119`.

## 10. Tests, lint, complexity (`testing`, `lint`, `automated-tests`, `performance`)

- `lua tests/run.lua`: **884 passed, 0 failed, 0 skipped** in 8.15 s wall time. The load list comes
  from the TOC and `LibKa0s.xml`. Kit suites are declared by the pair form (`test_prose`,
  `test_layout_cap`, `test_eol`). `docs/test-cases.md` matches `--list` byte for byte, and the
  README badge reads `884%2F884`.
- `luacheck .`: **0 warnings / 0 errors in 60 files**. `exclude_files` narrows the test tree to
  `tests/_kit/`, the harness global is in `files["tests/"]`, and there is no top-level `ignore`.
- `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` (lizard 1.24.0): **14325 NLOC, 1687
  functions, avg NLOC 7.4, avg CCN 2.0, 0 warnings**. Max CCN is 15, at `R.ApplyArtSize`
  (`modules/Registry.lua@607-635`) and `Compat.AddOnFolders` (`core/Compat.lua@27-45`), the same
  two as the recorded run.
- **Record:** the newest bundle is `docs/automated-tests/20260916-184500` (sha `3c4005a`, clean),
  29 commits behind HEAD. Its `RESULTS.md` row predates kit revision 25, so its commit cells are
  carried as unknown. The watch list is four band entries and no warned functions. There have been
  2 release runs (1.0.0 and 1.1.0), so no entry is past the 3-release shelf life. The 1.1.1 tag (a
  rebuild of 1.1.0) has no release bundle (`PM-033`).
- **Perf:** declined under the ratified `performance-§1` row. There is no `tests/perf.lua`,
  `perf` is a permanent `skip` with the sanctioned reason (`RESULTS.md:58-64`), and
  `docs/performance.md` states the position.

## 11. Packaging and line endings (`packaging`, `line-endings`)

- `.pkgmeta` has no `externals:`, and every root dot-entry except `.git` is ignored. Checks (a),
  (b) and (c) are clean, and `tools` is ignored because it exists.
- `.gitattributes`: `* text=auto eol=crlf` (`:26`), `*.sh` and `*.py` `text eol=lf` (`:36-37`),
  21 `binary` marks. The first 84 lines are byte-identical to the canonical client-bound body. A
  conforming `# --- line-endings-§5 appendix ---` marks
  `tools/artwork/bin/realesrgan-ncnn-vulkan`. The working-tree disagreement count is **0**, and the
  kit's `test_eol` agrees.

## 12. Root docs (`documentation-§1/§2/§7`)

- **README:** H1, the five badges in order (the standard badge is bare, and the CurseForge badge is
  present), Description, Screenshots, Usage, `## How panels work`, `## Panel artwork` (addon
  extra), FAQ, Troubleshooting, Issues, Version History (`- `-prefixed cells), and `## Credits`
  (external art only). There is no logo image and no library inventory. Findings: angle-bracket
  placeholders at `README.md:51`, `:79` and `:80`, and a Usage section that does not close on the
  configuration line (`PM-046`).
- **`CLAUDE.md`:** the stub shape is correct: H1, adherence line, `## Standards compliance (read
  first)`, doc pointers, green-gate line, and the provenance line at `:44`.
- **`DEPENDENCIES.md`:** runtime, development and release groups, WSL2 commands, pipx for lizard,
  and a verify command per tool. Two citations into the vendored kit went stale with the kit-25
  re-vendor (`PM-045`).

## 13. `docs/` (`documentation-§3`)

- **Tier 1:** all six are present under their canonical names.
- **Tier 2:**
  - `slash-dispatch.md` is present (19 verbs, threshold 8).
  - `profiles.md` is present (a Profiles page ships).
  - `debug.md` is present (`D:Diagnose` and `NS.DebugBuild`).
  - `message-bus.md` is correctly N/A (3 messages).
  - `midnight-quirks.md` is N/A.
  - `perf-analysis/README.md` is N/A: harness declined, no store.
  - **`compat-layer.md` is absent while its trigger has fired**: 8 shims against a threshold of 3.
    The map row still claims *Not applicable* (`docs/ARCHITECTURE.md:327`). This is `PM-031`,
    carried.
- **Map:** `## Documentation map` has the four tables in order and names the frozen stores as
  directories. Every live `.md` under `docs/` is registered exactly once, with no dangling rows.
  There are no retired docs (`file-index.md`, `conventions.md`, `complexity.md`, `perf-runs/`) and
  no `docs/pending/LEDGER.md`.
- **Hub:** 471 lines. The Settings Schema section is 102 lines (`:30-131`) (`PM-042`).
- **`module-map.md`:** covers `core/`, `defaults/`, `modules/`, `settings/`, `locales/` and
  `tools/sunn`. It does not cover `tests/` or three `tools/artwork` generators (`PM-043`).

## 14. The deviation register (`audit-review-history`)

`docs/ARCHITECTURE.md:373-378` holds four rows: `performance-§1`, `events-frames-taint-§8`,
`localization-§1` and `architecture-§5` (the fields on a panel). Each trigger was evaluated and
each cited issue resolved (`03_EVIDENCE.md` §7). Three rows stand. The `architecture-§5` row's
trigger ("the schema helper gains instance addressing") is now met at the library layer
(`libs/LibKa0s/Schema.lua:236`, `:432`) and needs the owner's decision (`PM-039`).

**Re-vendor store:** 8 bundles under `docs/revendor/`, the first dated 2026-08-25. The two-listing
check finds 31 tags vendored since then and 8 recorded, which leaves 25 unrecorded (`PM-048`).

**Issue store:** 53 issues. Every one carries a `state:` label and a `severity:` label, the label
colors match the canon, and no title has a `[status]` prefix. Five open `state:triaged` issues
rest on premises that are gone (`PM-047`).

## 15. Closed since 2026-09-08

`PM-030` (closed: the invariant is the library's and is pinned upstream, so the addon must not
duplicate it — `testing-§8`), `PM-032` and `PM-032a` (closed: the private spelling gate was
deleted and the kit's `test_prose` wired, e30e329). `PM-031` and `PM-033` persist. Details are in
`02_DEVIATIONS.md`.
