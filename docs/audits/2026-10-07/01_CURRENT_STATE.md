# 01 — Current state (2026-10-07)

Standards-compliance snapshot of **Ka0s Panel Master** (`PanelMaster`), read-only.

## Provenance

| Item | Value |
|---|---|
| Standard audited against | **Ka0s WoW Addon Standard v2.76.1 (2026-10-07)**: `standards/STANDARDS.md` plus all **27** section files its Sections list links, and `standards/ADDONS.md` |
| Standard source | `https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`, `master` = `f47238929230` (`git ls-remote`, this run). Fetched with `curl -fsSL` and read verbatim, every section file in full |
| Playbook | `AUDIT.md` from the same commit (1157 lines) |
| Repository kind | **Addon.** `dev-copilot-profile` reports `kind=addon` (`reason=toc:## Interface`). The repo has `PanelMaster.toc` and a row in `ADDONS.md` (`ADDONS.md:26`, launcher menu entries "Enabled · Locked"). The detector and the table agree, so the whole addon rule set applies |
| Tree audited | `06f3c28` on `feat/2026-10-07-review-audit-remediation`. Clean except an untracked `docs/reviews/2026-10-07/`, which a concurrent review run wrote; it is not this audit's output and was not read as evidence |
| Tools | Lua 5.1.5, luacheck 1.2.0, lizard 1.24.0. Every heavy run went through `~/.claude/dev-copilot/bin/ka0s-bounded`; none exited 124 or 137 |
| Prior runs | `docs/audits/2026-07-30`, `-08-04`, `-08-05`, `-09-07`, `-09-08`, `-09-23`. The ID prefix **`PM-`** is reused. `PM-001`…`PM-048` are taken. New IDs this run start at **`PM-049`** |

Since the last audit (`afb30d7`) **120 commits** landed: the 2026-09-23 remediation (`PM-01`…`PM-24`),
the diagnostics rollout, the nav-rail and automated-tests sweeps, the 1.2.0 release, the
smoke-and-profile pass, the debug-logs pass, the GitHub-issue pass (`#54` instance-addressed panel
rows), the census adoption and seven re-vendors from LibKa0s v1.56.0 to **v1.70.0**.

## 1. Layout (`layout`)

- Modular skeleton: `core/` (14), `modules/` (8), `settings/` (7), `defaults/` (2), `locales/` (2),
  plus `media/`, `libs/`, `tests/`, `tools/`, `docs/`. Nothing loose at the root.
- **Authored-Lua census** (`git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'`): **71** files,
  33 source and 38 under `tests/`. **Nothing is over 1500 lines.** Two files sit in the 1000–1500
  band: `tests/test_libka0s.lua` (1184) and `tests/test_slash.lua` (1084, new to the band since the
  last recorded run). The largest shipped file is `modules/Registry.lua` (972).
- **Census heading:** `docs/ARCHITECTURE.md:372` `### Files over the 1500-line cap`, nested under
  `## Documented deviations` (`:323`), reading "Nothing is over the cap today" (`:384`). It agrees
  with the tree, and the kit's gate (`tests/run.lua:116`, pair form) passes. Its prose still quotes
  the 2026-09-30 sizes (1160 / 987), now 1184 / 972 (`PM-044`).
- **Generators:** `tools/artwork/{artwork_cleaner,make_poster,update_catalog}.py` and
  `tools/sunn/build_manifest.py`, all under `tools/`, none in the TOC or a load list, all
  `.pkgmeta`-ignored (`tools` at `.pkgmeta:18`). `DEPENDENCIES.md` names the interpreter.
- **Media:** `media/logos/` (5 files), `media/screenshots/`, `media/poster/` (ignored), and
  `media/artwork/<type>/` (this addon's own subject matter). No copy of the shared payload's
  fonts, icons or textures.
- **Logo:** `media/logos/panelmaster.logo.128.tga` header bytes `0 0 2 … 128 0 128 0 32 8`: type 2
  (uncompressed), 128×128, 32 bpp. The landing-page logo `panelmaster.logo.tga` sits beside it.

## 2. TOC (`toc-file`)

`PanelMaster.toc:1-13` in the templated field order: `Interface: 120100` (the collection's value;
all twelve TOCs on disk read the same), `Title: Ka0s Panel Master`, Notes, Author, `Version: 1.2.0`,
`IconTexture` at the 128 logo, `SavedVariables: PanelMasterDB` (one global; the `Perf` decline is
ratified), OptionalDeps, DefaultState, `Category-enUS: UI`, `X-License: MIT`, `X-Standard`,
`X-Curse-Project-ID: 1642836`. Section headers run Libraries → Locales → Core → Defaults → Modules →
Settings. `libs\LibKa0s\LibKa0s.xml` is listed once (`:36`).

**Load-bearing positions** are all annotated: `core\MediaSetup.lua` (`:48-52`), `core\Util.lua`
(`:59-61`), `core\CoreSetup.lua` (`:62-64`), `core\BusSetup.lua` (`:65-68`),
`core\DebugLogSetup.lua` (`:69-72`), `core\LauncherSetup.lua` (`:83-87`),
`settings\PanelSchema.lua` (`:116-120`), `settings\Slash.lua` (`:121-123`) and
`settings\OptionsSetup.lua` (`:129-132`). Conventional groups carry a note (`:44-47`, `:54-56`,
`:78-80`, `:89-90`, `:94-96`). `locales\PostLoad.lua` is empty, so it pins nothing. Compliant.

## 3. Libraries (`library-stack`)

- Vendored: LibStub, CallbackHandler, AceAddon/Event/Timer/Console/DB/GUI/Config, AceDBOptions,
  LibSharedMedia, AceGUI-SharedMediaWidgets, LibDataBroker-1.1, LibDBIcon-1.0 and the whole
  `libs/LibKa0s/` (37 top-level entries, 159 files; 34 Lua files, matching the standard's v2.76.1
  recount).
- **Provenance:** `CLAUDE.md:45` reads `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.70.0 (MIT).`
  `README.md` carries no such line and no library inventory heading.
- **Drift:** `diff -r` of `v1.70.0:LibKa0s` against `libs/LibKa0s` and of `v1.70.0:testkit`
  against `tests/_kit` both come back **empty** (`03_EVIDENCE.md` §3). The kit is **revision 37**.
  The suite's own vendored-payload gate agrees.
- **Adopted majors, 10 of 15:** Core, Env, Media, DebugLog, Lifecycle, Launcher, Bus (`Catalog`
  only), Slash, Options and Schema. Declined: Perf (ratified register row), Widgets, Item, Pool and
  Compat (`state:will-not-do` #43, #45, #46, #53; adoption is optional, so no register row is owed).
- **Stubs:** every adopted seam has a library-absent branch, and `tests/test_surface_parity.lua`
  holds eight parity cases (Core, DebugLog, Launcher, Slash, Options, Schema on both levels, Bus,
  Lifecycle), each naming the grep it was derived from. The Options stub is load-completing with
  hollow composers; the Schema stub is the runtime-completing shape and cites its API document
  (`settings/Schema.lua:215`). The Slash stub carries a copy of the library's coloured
  `key = value` formatter (`settings/Slash.lua:508-510`, `PM-050`).
- `lib.__PatchLSM30Border()` is called from `settings/OptionsSetup.lua:169`; there is no
  `RegisterWidgetType` in the addon's own code (`library-stack-§9`).

## 4. Architecture and patterns (`architecture`, `events-frames-taint`, `compat`)

- `core/PanelMaster.lua:4` calls `NewAddon(NS, …)`; `:14` reclaims `NS.Print` from `NS.Util.print`.
- **Bus:** three messages, each declared once through `LibKa0s-Bus-1.0`'s `Catalog`
  (`modules/Registry.lua:25-26`, `settings/Schema.lua:34`). No literal at any call site; every event
  name is PascalCase. Receivers register on their own targets (`modules/Canvas.lua:929-934`,
  `settings/PanelEditor.lua:708`, `:719`) from `NS.NewBusTarget`.
- **Events:** every registration goes through `NS.SafeRegisterEvent` (`core/LifecycleSetup.lua:141`,
  `core/PanelMaster.lua:67`), the rejected list is `NS.State.rejectedEvents` and the diagnostics
  report prints it. The degraded Core stub carries the one-rung `pcall` (`core/CoreSetup.lua:76-86`).
- **Compat:** `core/Compat.lua` publishes **8** shims (documentation-§3's grep). Two fallback rungs
  call globals no admitted client provides: `core/EnvSetup.lua:55-57` (`GetAddOnMetadata`, the
  standard's own worked case) and `core/Compat.lua:31-32` (`GetNumAddOns`, `GetAddOnInfo`) — `PM-051`.
- **Secret values:** the trigger-set sweep returns **0**; the only Unit API called is
  `UnitAffectingCombat` (`core/Compat.lua:88`).
- **Schema / registry (`architecture-§5`):** the panel set is a structural registry with one writer
  (`modules/Registry.lua`), its load pass named (`core/Database.lua`), and every per-panel field is
  an instance-addressed `panel.<field>` row since #54. The write-path grep finds only the writer and
  the load pass. LibDBIcon's `minimapPos` is mentioned in the launcher section of the hub but is not
  named as non-setting state in **Settings Schema** with an owner module (`PM-052`).
- Frames are non-secure. The one `OnUpdate` is the 10 Hz mouseover driver
  (`modules/Canvas.lua:647-652`, installed at `:662`, removed at `:680` when the set empties).

## 5. SavedVariables (`savedvariables`)

- AceDB with `profile` (`panels`, `nextID`, `settings`) and `global` (`schemaVersion = 0`,
  `minimap = { hide = false }`, `defaults/Global.lua:74-75`). `NS.SCHEMA_VERSION = 2`
  (`core/Namespace.lua:14`). The runner (`core/Database.lua:176-187`) owns the stamp, writes it
  only after the step returns, and runs its profile-scoped step over every stored profile
  (`:160-168`). `PM-038` and `PM-038a` from the last run are closed.
- No new `stored.k or D.k` over a user-choice field in the 120 commits since `afb30d7`.

## 6. Settings (`options-ui`, `launcher`, `preview-mode`)

- **Library wiring:** `NS.Helpers = lib:New{…}` (`settings/OptionsSetup.lua:171`) passes
  `addonName = addonName` (`:181`, standard v2.75.0) and `debug` (`:184`).
- **Pages and tabs** (from the schema): Landing (`buildMain`, exempt); General: **Master controls**
  (7 composed rows), **Editing** (4), **New panels** (4); Panels: **General**, Position and size,
  Background and border, Accent bar, Artwork, Opacity and fade, with the picker and create box in
  the band; Profiles (AceConfig, exempt). No nav rail (#55 declined a MAY).
- **Master controls:** composed by `H.MasterControls` (`settings/Schema.lua:575-617`) with
  `minimapPath` and `debugConsolePath`; no `testModePath`, because unlocking is the preview
  (`options-ui-§15` exemption; `SetMovable` sweep: `modules/Unlock.lua:195`, `:206`).
- **Colors:** no `disabledIf` on any color row; no scroll arrows; the media groups are composed.
- **Global reset:** `Sl:DoResetAll` (`settings/Slash.lua:36-47`) is `db:ResetProfile()`, confirmed
  with the verbatim text (`:73`). The General page Defaults button routes to the same act
  (`settings/Panel.lua:343-344`). **The session-only rows — `state.locked` and
  `state.debugConsole` — are not restored**: reproduced headlessly, an unlocked UI stays unlocked
  and the console stays open through *Reset all settings*, and the next panel created is drawn
  unlocked (`PM-049`, `03_EVIDENCE.md` §1).
- **Launcher:** one `LibKa0s-Launcher-1.0` object (`core/LauncherSetup.lua:169-249`), label
  `NS.BRAND`, icon `C.ICON_PATH`, `isEnabled`/`setEnabled` → `NS.Slash:CliEnable`,
  `isLocked`/`toggleLock` → `NS.Slash:CliLock`, `version`, `debug`, `debugAtEnable`. No `onClick`,
  no `onTooltipShow`. Matches `ADDONS.md`'s "Enabled · Locked". `minimap.hide` is global, the row
  is `global.minimap.shown`, and neither reset reaches it (`tests/test_launcher.lua`).

## 7. Slash (`slash-commands`)

- `/pm` and `/panelmaster` through `LibKa0s-Slash-1.0` (`settings/Slash.lua:609-679`).
  `NS.COMMANDS` (`:329-423`) holds **21** verbs. `perf` is reserved and unregistered (ratified Perf
  row). `diagnostics` is one row (`:420`) and `debug` routes through `DebugVerb` first (`:415`).
- **Disabled surface:** `liveVerbs` is `lib.LIVE_VERBS` plus `profile` (`:467-477`); feature verbs
  get the library's one refusal line. That is `slash-commands-§2` as restored in v2.57.0.

## 8. The disabled state (`slash-commands-§7`)

- One `LibKa0s-Lifecycle-1.0` latch (`core/LifecycleSetup.lua:230-246`) with `disabled` and `perf`
  holds and the gated `debug` sink. Stand-down (`:101-114`) unregisters the three game events and
  the renderer's three subscriptions (`modules/Canvas.lua:947-953`); the show-ladder rung strips the
  unlock overlay (`modules/Canvas.lua:810`, `:837`), closing `PM-034`.
- Registration census: 7 registration call sites in the shipped source (the stand-up loop over
  three game events, `PLAYER_LOGIN`, the renderer's three subscriptions and the Panels page's two),
  all undone on stand-down except the setup survivors (`PLAYER_LOGIN`, and the Panels page's two
  refresh subscriptions, which `open-evolutions` records and does not rule). No timer survives; the one-shot `ScheduleTimer` is the colour-picker throttle.
- `tests/test_disabled.lua` asserts on the mock's registration set across steps 1–10 and 5b, 7b–7d,
  9b and 10b, with nine `red under` comments. All pass.

## 9. Debug (`debug-logging`)

`core/DebugLogSetup.lua:115-192` builds the console with `name`, `addonName`, `title`, `font`,
`isEnabled`/`setEnabled`, `print`, `initSummary`, `brandName`, `diagnostics`,
`onVisibilityChanged`, `slash`. `NS.Debug` is bound bare (`:199`); `NS.DebugOnce` and
`NS.DebugAtEnable` wrap the console's own gates (`:227-237`). The stub answers every member,
including `RunDiagnostics` with the library-absent line (`:75-78`). Every descriptor that takes
`debug` gets it; no host line restates a library line. `docs/debug.md` documents the report.

## 10. Tests, lint, complexity (`testing`, `lint`, `automated-tests`, `performance`)

- `lua tests/run.lua`: **1035 passed, 0 failed, 1 skipped (1036 total)**, 10.7 s wall, 97 MB peak.
  The skip is the kit's diagnostics opt-out case, which does not apply. `docs/test-cases.md` matches
  `--list` byte for byte, and the README badge reads `1035%2F1035`.
- `luacheck .`: **0 warnings / 0 errors in 71 files**. `exclude_files` narrows the test tree to
  `tests/_kit/`; the harness global sits in `files["tests/"]`.
- Complexity, sighted (`run-automated-tests.sh --suite complexity --no-bundle`): **pass, 0 warnings,
  17349 NLOC, 2168 functions, avg CCN 2.0, max 15**, no blind file. Kit 37 wires
  `test_lizard_sighted`.
- **Record:** the newest bundle `20260927-032003` (`8cda106`, clean, unsighted: kit < 35) is
  **52 commits** behind HEAD. Watch list: one *Accepted* entry, one release run old. The
  `docs/automated-tests/README.md:29` gate table still quotes the raw blind `lizard -l lua …` line
  (`PM-054`).
- **Perf:** declined under the ratified `performance-§1` row; no `tests/perf.lua`.

## 11. Packaging and line endings (`packaging`, `line-endings`)

- `.pkgmeta`: no `externals:`; checks (a), (b) and (c) clean except `.git`.
- `.gitattributes`: the first 84 lines are byte-identical to the canonical client-bound body; the
  tail is a conforming `# --- line-endings-§5 appendix ---` marking
  `tools/artwork/bin/realesrgan-ncnn-vulkan`. Working-tree disagreement count **0**; the kit's
  `test_eol` agrees on both cases.

## 12. Root docs (`documentation-§1/§2/§7`)

- **README:** H1, five badges (bare standard badge), Description, Screenshots, Usage closing on the
  configuration line, `## How panels work`, `## Panel artwork`, FAQ, Troubleshooting with the
  reporting row, `## Reporting a bug` (verbatim), Issues, Version History, `## Credits`. No logo, no
  numbered list, no library inventory. Two `/pm profile <name>` placeholders (`:65`, `:229`) and an
  un-prefixed line in the 1.2.0 Highlights cell (`:271`) — `PM-046`, recurring.
- **`CLAUDE.md`:** H1, adherence line, `## Standards compliance (read first)`, pointer list,
  provenance line (`:45`), green-gate line (`:62`). The provenance line comes **before** the
  green-gate line, against documentation-§2's fixed order (`PM-053`).
- **`DEPENDENCIES.md`:** runtime / development / release groups, WSL2 commands, pipx for lizard,
  a verify command per tool. Every kit citation re-read resolves.

## 13. `docs/` (`documentation-§3`)

- **Tier 1:** all six present under their canonical names.
- **Tier 2:** `slash-dispatch.md` (21 verbs), `profiles.md`, `debug.md` and `compat-layer.md`
  (8 shims) present; `message-bus.md` (3 messages), `midnight-quirks.md` and
  `perf-analysis/README.md` correctly *Not applicable*. `PM-031` is closed.
- **Map:** four tables in order; every live `.md` registered exactly once; no dangling row; the
  hub's self-row is absent (a MAY, not filed). No retired doc, no `docs/pending/`.
- **Hub:** 422 lines (SHOULD ~400). Settings Schema 51 lines, Slash Commands 36. `## Documented
  deviations` with its census runs 100 lines, about half of it retirement and peel history
  (`PM-042`, recurring).
- **`module-map.md`:** all 75 authored `.lua` / `.py` files named.

## 14. The deviation register and stores (`audit-review-history`)

- `docs/ARCHITECTURE.md:346-350` holds three rows: `performance-§1`, `events-frames-taint-§8`,
  `localization-§1`. Every trigger was evaluated against this tree and none has fired; every cited
  id resolves; no cited rule has changed. The `events-frames-taint-§8` row's **Why** still names
  `UnitClass`, which the code no longer calls (`PM-044`).
- **Re-vendor store:** 21 bundles, all with both stable members. The two-listing check finds
  **51** tags vendored since the 2026-08-25 horizon and **49** recorded; **v1.69.0** and **v1.70.0**
  have no bundle (`PM-048`, recurring).
- **Issue store:** 55 issues, every one with exactly one `state:` and one `severity:` label in the
  canonical colours, no `[status]` prefix. **#47 is closed and labeled `state:triaged`**
  (`PM-055`). `PM-047`'s five stale open issues are all closed.

## 15. Closed since 2026-09-23

`PM-031` (compat-layer.md written), `PM-034`/`PM-034a` (overlay stripped while stood down, route
A/B/C case), `PM-035` (`SafeRegisterEvent`), `PM-036`/`PM-037` (TOC annotations), `PM-038`/`PM-038a`
(`schemaVersion = 0` declared), `PM-039` (row retired by #54), `PM-040` (Lifecycle parity case),
`PM-041` (frozen specs restored; kit 26 skips `docs/superpowers/`), `PM-043` (module-map complete),
`PM-045` (citations by function name) and `PM-047` (stale issues closed). `PM-042`, `PM-044`,
`PM-046` and `PM-048` recur with new instances; `PM-033` is carried. Details in `02_DEVIATIONS.md`.
