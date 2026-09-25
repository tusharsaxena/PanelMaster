# 03 — Evidence (2026-09-23)

Every claim in `01_CURRENT_STATE.md` and `02_DEVIATIONS.md` has its source here. Each `file:line`
cited in this bundle was re-read at `afb30d7` before being written, and the quoted text is what the
line holds. **Scope conventions.** A census starts from `git ls-files`. The default authored-Lua
denominator is `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'` (60 files: 28 source and 32
test). Any narrower or wider scope is stated where it is used. Files in this repo are CRLF, so the
`tr -d '\r'` in commands below changes nothing but the display.

## §1 — PM-034 / PM-034a: an unlocked panel survives the stand-down

**Code, quoted.**

```
modules/Canvas.lua:802  if NS.Lifecycle and NS.Lifecycle:IsDown() then spec.shown = false end
modules/Canvas.lua:822  applySpec(f, spec)
modules/Canvas.lua:823  if NS.Unlock and NS.Unlock.Decorate then NS.Unlock:Decorate(f, rec) end
modules/Unlock.lua:123  function U:IsPanelUnlocked(id)
modules/Unlock.lua:124    if NS.State.unlocked then return true end
modules/Unlock.lua:125    return id ~= nil and NS.State.unlockedPanels[id] == true
modules/Unlock.lua:176    f:Show()
modules/Unlock.lua:177    U:ArmDrag(f)
modules/Unlock.lua:198    f:EnableMouse(true)
modules/Unlock.lua:199    f:SetMovable(true)
settings/Schema.lua:504     path = "state.locked", sessionOnly = true,
settings/Schema.lua:508     set = function(v) if NS.Unlock then NS.Unlock:SetUnlocked(not v) end end,
```

`U:SetUnlocked` ends in `NS.Canvas:RenderAll()` (inside `modules/Unlock.lua:232-251`).
`U:SetPanelUnlocked` ends in `NS.Canvas:Render(id)` (`:139`). Neither checks the latch, so both
reach `Decorate` whether or not the addon is stood down.

**Reproduction.** A scratch script **outside the repo** (in the session scratchpad; nothing written
to the tree) replays `tests/run.lua`'s bootstrap, which loads `LibKa0s.xml` and the TOC, then runs
`OnInitialize` and `OnEnable`, and drives the addon through the single write seam:

```
$ ~/.claude/wow-addon/bin/ka0s-bounded lua <scratch>/repro_unlock_disabled.lua
baseline enabled, locked          -> shown: A, B
unlocked                           -> shown: A(mouse), B(mouse)
A: disabled while unlocked         -> IsDown=true shown: A(mouse), B(mouse)
B0: locked while disabled          -> shown:
B: Lock frame unticked while off   -> shown: A(mouse), B(mouse)
C: per-panel unlock while off      -> shown: A(mouse)
```

Script steps: `S:Set("settings.enabled", true)`, create panels A and B, fire `PLAYER_ENTERING_WORLD`,
`S:Set("state.locked", false)`, `S:Set("settings.enabled", false)`, `S:Set("state.locked", true)`,
`S:Set("state.locked", false)`, `S:Set("state.locked", true)`, and
`NS.Unlock:SetPanelUnlocked(<A>, true)`. "(mouse)" means `f:IsMouseEnabled()` is true on the mock
frame. `git status --short` afterwards showed no change the audit made.

**Why the suite is green (PM-034a).** `tests/test_disabled.lua:221-251` (step 5) calls `seed()`,
`S:Set(ENABLED, false)`, `OnRegenDisabled`, `OnRegenEnabled`, `Canvas:RenderAll` and
`S:Set("settings.visibility", "always")`, and then takes the `perf` hold. No line in the file sets
`state.locked`, calls `SetUnlocked` or calls `SetPanelUnlocked`
(`grep -n 'state.locked\|SetUnlocked\|SetPanelUnlocked' tests/test_disabled.lua` → no output).

## §2 — Line endings (`line-endings`), run as written

```
$ test -f .gitattributes && echo present                         → present
$ grep -n '^\* text=auto eol=\(crlf\|lf\)$' .gitattributes      → 26:* text=auto eol=crlf
$ grep -nE '^\*\.(sh|py) text eol=lf.?$' .gitattributes          → 36:*.sh text eol=lf / 37:*.py text eol=lf
$ grep -c ' binary.\?$' .gitattributes                           → 21
$ <the (e) one-liner from AUDIT.md, verbatim>                     → 0
```

Body diff: the client-bound canonical body was extracted from `line-endings.md` (84 lines) and
compared with `diff <(head -n 84 .gitattributes | tr -d '\r') <canonical>`, which came back empty
(exit 0). `tail -n +85 .gitattributes | tr -d '\r' | grep -m1 .` → `# --- line-endings-§5 appendix ---`.
The kit gate agrees: `PASS eol: every tracked file carries the terminator .gitattributes declares for it`
and `PASS eol: .gitattributes is line-endings-5's canonical body for this repo kind`.
**Scope:** (e) covers the whole tracked set, `libs/` included.

## §3 — Vendored payloads and provenance (`library-stack-§7`, `testing-§11`)

```
$ grep -n 'Bundles \[LibKa0s\]' CLAUDE.md README.md
CLAUDE.md:44:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.55.0 (MIT). That line is the
$ grep -nE '^## (Libraries|Bundled libraries|Libraries and credits|Credits and libraries|Credits and bundled libraries)' README.md   → (none)
$ grep -n 'WoW_Addon_Standard' README.md
6:![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
$ grep -nE '!\[[^]]*\]\(media/logos|<img' README.md                → (none)
```

Sibling `../LibKa0s` is present, and tag `v1.55.0` = `bb161b7`. The tagged tree was exported to
scratch with `git -C ../LibKa0s archive v1.55.0 LibKa0s testkit | tar -x`:

```
$ diff -r <scratch>/LibKa0s libs/LibKa0s     ; echo $?   → 0   (no output)
$ diff -r <scratch>/testkit tests/_kit       ; echo $?   → 0   (no output)
$ find libs/LibKa0s -type f | wc -l → 146 ; find <scratch>/LibKa0s -type f | wc -l → 146
$ git ls-files -s tests/_kit/run-automated-tests.sh
100755 31ff9b3e429dbb85d52d336bfb286b94bedd838b 0	tests/_kit/run-automated-tests.sh
```

The in-suite gate agrees: `PASS libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles`,
`PASS tests/_kit is the test kit that shipped with that release` and
`PASS the automated-test runner is recorded executable (100755)`. It reported no skip.

## §4 — Lint and tests

```
$ ~/.claude/wow-addon/bin/ka0s-bounded luacheck .
…
Total: 0 warnings / 0 errors in 60 files
luacheck exit 0

$ time ~/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua
…
884 passed, 0 failed, 0 skipped, 884 total
… 1.03s user 0.86s system 23% cpu 8.150 total          exit 0

$ ~/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua --list > <scratch>/list.md
$ diff <(tr -d '\r' < docs/test-cases.md) <(tr -d '\r' < <scratch>/list.md)   → (empty)
```

`.luacheckrc` scope: `exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/_kit/" }`.
The rest of `tests/` is linted, the harness global is declared in `files["tests/"]` (`_G.PM_TEST`),
and there is no top-level `ignore` (enforced by `tests/test_lintconfig.lua`). README badge:
`README.md:7` `Tests-884%2F884_passing`. The kit suites are declared by the pair form at
`tests/run.lua:104` (`test_prose`), `:111` (`test_layout_cap`) and `:119` (`test_eol`).
`test_disabled` is declared at `:101`.

## §5 — Complexity (`performance-§10`, `automated-tests-§4`)

```
$ ~/.claude/wow-addon/bin/ka0s-bounded lizard --version          → 1.24.0
$ ~/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .
No thresholds exceeded (cyclomatic_complexity > 15 or length > 1000 or nloc > 1000000 or parameter_count > 100)
Total nloc   Avg.NLOC  AvgCCN  Avg.token   Fun Cnt  Warning cnt   Fun Rt   nloc Rt
     14325       7.4     2.0       57.8     1687            0      0.00    0.00
```

The top CCNs at HEAD are 15 `R.ApplyArtSize@607-635@./modules/Registry.lua`, 15
`Compat.AddOnFolders@27-45@./core/Compat.lua`, 13 `Artwork.BuildArtSpec@1104-1188@./modules/Artwork.lua`
and 12 `sources@112-143@./modules/SunnArt.lua`. The same four head
`docs/automated-tests/20260916-184500/complexity.txt`, whose footer reads `13887 7.4 2.0 58.1 1624 0`.

Bundle manifests (`git` object): `20260916-184500` sha `3c4005a…`, `dirty: false`.
`git rev-list --count 3c4005a..HEAD` → **29**. Release runs: `"release": "1.0.0"` in
`20260807-160022` and `"release": "1.1.0"` in `20260910-234511`. No manifest carries 1.1.1.
`git log -1 1.1.1-release` → `dd04000 … Dummy commit to trigger a new build`. `940bb11` bumps the TOC
to 1.1.1 afterwards. The newest `RESULTS.md` row (`:26`) has no commit cells, because the row
predates kit revision 25.

Band census, default scope (`xargs wc -l | sort -rn`): 1476 `settings/PanelEditor.lua`, 1356
`tests/test_artwork.lua`, 1353 `tests/test_panel.lua`, 1188 `modules/Artwork.lua`, then 976
`tests/test_libka0s.lua`. Nothing exceeds 1500. **Scope:** 60 authored files. `libs/` and
`tests/_kit/` are excluded, and no generated data is declared (`docs/ARCHITECTURE.md:434-435`).

## §6 — Stub member census (PM-040, `testing-§8`)

```
$ git ls-files '*.lua' ':!libs' ':!tests' | xargs grep -ohE 'NS\.Lifecycle[:.][A-Za-z_]+' | sort | uniq -c
      3 NS.Lifecycle:IsDown
      1 NS.Lifecycle:Holds
      1 NS.Lifecycle:Reevaluate
      2 NS.Lifecycle:Set
```

**Scope:** authored source only. `tests/` is excluded here because the question is what the
*addon* calls; the suites also call `Hold`, `Release` and `IsHeld`. The stub at
`core/LifecycleSetup.lua:149-190` defines `Hold`, `Release`, `Set`, `IsHeld`, `IsDown`, `Holds`,
`Reevaluate`, `PrintHolds` and `name`, which covers all four host calls. The coverage claim at
`core/LifecycleSetup.lua:147-148` reads *"tests/test_surface_parity.lua compares the two member sets
so it cannot drift into being a different thing."* `docs/module-map.md:19` carries the same clause.
`tests/test_surface_parity.lua:3-4` reads *"Six LibKa0s seams carry a degradation stub here — Core,
DebugLog, Launcher, Slash, Options and Schema"*, and its `test(` calls sit at `:59`, `:103`, `:136`,
`:154`, `:190` and `:226`. `grep -n 'Lifecycle' tests/test_surface_parity.lua` → no output.

## §7 — The deviation register (`audit-review-history`, all three MUSTs)

Rows: `docs/ARCHITECTURE.md:375` (`performance-§1`), `:376` (`events-frames-taint-§8`), `:377`
(`localization-§1`) and `:378` (`architecture-§5`, fields on a panel).

- **performance-§1.** One `OnUpdate`: `modules/Canvas.lua:666` `mouseoverDriver:SetScript("OnUpdate", mouseoverTick)`,
  cleared at `:684`. The only other scheduling is `settings/OptionsSetup.lua:249`
  `NS.addon:ScheduleTimer(fn, delay)`, the color-picker commit throttle, which is one-shot.
  `updateMouseover` (`:632-645`) makes one `NS.Compat.MouseIsOver` and one `SetAlpha` per tracked
  panel. The row's `core/Constants.lua:306` citation holds `mouseover      = false,`. Issues #31
  (closed, will-not-do) and #44 (closed, done) resolve.
- **events-frames-taint-§8.** `git ls-files '*.lua' ':!libs' ':!tests' | xargs grep -nE 'UnitGetTotalAbsorbs|UnitGetTotalHealAbsorbs|UnitGetIncomingHeals|UnitHealth|UnitThreatSituation|UnitDetailedThreatSituation|C_UnitAuras|UNIT_AURA' | wc -l`
  → `0`. The only `Unit*` identifier is `UnitClass` (1 hit).
- **localization-§1.** `git ls-files locales` → `locales/PostLoad.lua`, `locales/enUS.lua`.
  `locales/enUS.lua:6` is `NS.L = setmetatable(NS.L or {}, { __index = function(_, k) return k end })`.
- **architecture-§5 (PM-039).** `libs/LibKa0s/Schema.lua:236`:
  `---   resolveRoot   function  (parts, instanceId) -> root, first, resolvedId | nil, reason`.
  `:432`: `function S.Set(path, value, instanceId)`. The host's
  `settings/Schema.lua:360` is `resolveRoot = function() return NS.db and NS.db.profile, 1 end,`.
  `docs/revendor/2026-09-23-v1.55.0/05_SUMMARY.md:94-98` flags the re-check and defers it to the
  owner. #49 (closed, done) resolves. No open issue carries the re-check.

**Inverse check.** `gh issue list --state all --limit 200 --json number,title,state,labels`
returns 53 issues, and every one carries exactly one `state:` and one `severity:` label.
`gh label list` colors: `state:untriaged ff0000`, `state:triaged ffff00`, `state:done 00ff00`,
`state:will-not-do 0000ff`, `severity:critical 110000`, `severity:high 110800`,
`severity:medium 111100`, `severity:low 001100`. The closed `state:will-not-do` issues are #27, #28,
#29, #30, #31, #43, #45, #46, #51 and #53. No `docs/pending/` exists.

**PM-038, the unregistered decline.** `defaults/Global.lua:8` reads
*"`schemaVersion` IS DELIBERATELY NOT SEEDED HERE (savedvariables-§1)."* `:73-76` declares
`NS.defaults.global = { minimap = { hide = false }, }` and nothing else. `core/Database.lua:132`
reads `g.schemaVersion = g.schemaVersion or 1` and `:158` reads `g.schemaVersion = NS.SCHEMA_VERSION`.
`git log -S'DELIBERATELY NOT SEEDED' -- defaults/Global.lua` → `febf108 2026-08-05 … [M4-22]`.
`grep -n schemaVersion docs/ARCHITECTURE.md` → `:34` only. That is prose, and none of the four
register rows mentions it.

**PM-047.** `gh issue view` bodies: #19 concerns *"`docs/agent-context.md` (US-English sweep)"*;
#20, *"registering this addon in the collection roster"*; #22, *"Blocked on a CurseForge project id
that does not exist until first upload"*; #23, *"the published-version badge … Same blocker"*; #24,
*"`performance-§1`–`§4` … no counterpart in this addon"*. The tree now has
`PanelMaster.toc:13` `## X-Curse-Project-ID: 1642836`,
`README.md:4` `![CurseForge Version](https://img.shields.io/curseforge/v/1642836)`, the roster row
`ADDONS.md:26` (Ka0s Panel Master), and `CLAUDE.md:83` saying `docs/agent-context.md` does not exist.

## §8 — Packaging (`packaging`), run under `bash`

```
(a) NOT IGNORED …   → (nothing)       entries: .luacheckrc .pkgmeta .gitignore .gitattributes docs tests _dev tools
(b) UNACCOUNTED …   → UNACCOUNTED — .git     (exempt by rule)
(c) FALSE CLAIM …   → (nothing)
```

The first run was under `zsh`, which did not word-split `$entries`, and printed one concatenated
line. It was discarded and re-run under `bash -c`. There is no `externals:` block.

## §9 — Compat, bus, events, close button, panel greps

```
$ grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua   → 8
  :27 Compat.AddOnFolders  :56 GetScreenSize  :65 GetUIScale  :79 InCombat
  :103 RegisterMedia  :124 FetchMedia  :139 MediaList  :164 MouseIsOver
$ grep -rnE '(Send|Register)Message\("Ka0s_' --include='*.lua' . | grep -v -e '/libs/' -e '/tests/_kit/'   → (none)
$ grep -rnoE '"Ka0s_[A-Za-z]+_[A-Za-z0-9_]+"' … → modules/Registry.lua:19, :20, settings/Schema.lua:31 (PascalCase tails)
$ git ls-files '*.lua' ':!libs' ':!tests/_kit' | xargs grep -nE 'Register(Unit)?Event|RegisterMessage|RegisterBucketEvent'   (source hits)
  core/LifecycleSetup.lua:127-129 (three RegisterEvent), core/PanelMaster.lua:63 (PLAYER_LOGIN),
  modules/Canvas.lua:878-880 (three RegisterMessage), settings/PanelEditor.lua:1444, :1455
$ … grep -nE 'Unregister(All)?Events?|UnregisterMessage|…|SetScript\("OnUpdate", *nil\)'
  core/LifecycleSetup.lua:99-101, modules/Canvas.lua:684   (+ Canvas:Disable's UnregisterAllMessages at :897)
$ grep -rn 'MakeCloseButton(' --include='*.lua' . | grep -v '/libs/' | grep -v '/tests/'
  core/CoreSetup.lua:112 (comment), :119 return lib.MakeCloseButton(parent, onClick, addonName)
$ grep -rn 'ScrollUp-Up\|ScrollDown-Up\|MoveUp\|MoveDown' settings/ modules/   → (none)
$ git ls-files '*.lua' ':!libs' ':!tests/_kit' | xargs grep -nE 'SettingsPanel|HideUIPanel|ToggleGameMenu|OpenToCategory'
  settings/Panel.lua:542 (presence guard in P:Open; the open is O.OpenOptionsPanel)
```

Event registration shape (PM-035), quoted:

```
core/LifecycleSetup.lua:126    if NS.addon and NS.addon.RegisterEvent then
core/LifecycleSetup.lua:127      NS.addon:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnterWorld")
core/LifecycleSetup.lua:128      NS.addon:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
core/LifecycleSetup.lua:129      NS.addon:RegisterEvent("PLAYER_REGEN_DISABLED", "OnRegenDisabled")
core/PanelMaster.lua:63          self:RegisterEvent("PLAYER_LOGIN", function()
```

`grep -rn 'pcall' core/LifecycleSetup.lua core/PanelMaster.lua` → no output.

TOC load-bearing reads (PM-036, PM-037):

```
core/Util.lua:4          local C = NS.Constants
settings/Slash.lua:532   local dispatcher = lib:New({
settings/Slash.lua:554     get          = NS.SchemaRuntime.Get,
settings/Slash.lua:558     applyDefault = NS.SchemaRuntime.ApplyDefault,
settings/Schema.lua:375  NS.SchemaLib, NS.SchemaRuntime = SchemaLib, R
PanelMaster.toc:53 core\Constants.lua   :56 core\Util.lua   :57-58 (# CoreSetup AFTER … Util (NS.Util) …)
PanelMaster.toc:95 # Settings (last …)  :96 settings\Schema.lua  :97 settings\Slash.lua  :98 settings\PanelEditor.lua
```

## §10 — `docs/` shape (`documentation-§3`)

**Map coverage.** The live `.md` files under `docs/`, excluding the stores the map names as frozen
(`audits/`, `reviews/`, `automated-tests/<run>/`, `revendor/`, `superpowers/`), are
`ARCHITECTURE.md`, `artwork-spec.md`, `automated-tests/README.md`, `automated-tests/RESULTS.md`,
`common-tasks.md`, `data-flow.md`, `debug.md`, `localization.md`, `media.md`, `module-map.md`,
`performance.md`, `profiles.md`, `rendering.md`, `schema.md`, `scope.md`, `settings-panel.md`,
`slash-dispatch.md`, `smoke-tests.md`, `test-cases.md` and `testing.md`. Each has exactly one row
in `docs/ARCHITECTURE.md:307-348`, the hub itself excepted (a MAY). No row is dangling. No retired
doc is present.

**Hub shape (PM-042).** `wc -l docs/ARCHITECTURE.md` → 471. Headings (`grep -n '^#'`): `:9`
Overview, `:19` Module Map, `:30` Settings Schema, `:132` Message bus, `:158` Slash Commands,
`:184` launcher, `:224` Event Subscriptions, `:239` disabled state, `:288` Taint, `:295` Known
Limitations, `:301` Documentation map, `:350` Documented deviations, `:430` census. Settings Schema
therefore runs from `:30` to `:131`, 102 lines.

**Module-map coverage (PM-043).** Scope: `git ls-files` for `core/`, `modules/`, `settings/`,
`defaults/`, `locales/`, `tools/` (excluding `tools/artwork/bin`, `tools/artwork/fonts`) and
`tests/*.lua` (excluding `tests/_kit`). Each basename was grepped in `docs/module-map.md`.
Missing: 28 test-tree files (`degraded_env.lua`, `prose_waivers.lua`, `run.lua`, `wow_mock.lua` and
24 `test_*.lua`) plus `tools/artwork/artwork_cleaner.py`, `make_poster.py` and `update_catalog.py`.
Every source file is present.

**Stale inventories (PM-044), quoted.** `docs/ARCHITECTURE.md:21` *"six of the eight LibKa0s"* and
`:24` *"the other two seams"*. `docs/testing.md:106` *"Nine of the ten majors resolve
`LibKa0s-Core-1.0`"*. `:340` *"Four LibKa0s seams are adopted — Core, DebugLog, Slash and Options"*.
`:347` *"One case per seam"*. `:350` *"Two of the four call the kit's"*.
`docs/module-map.md:69-70` *"`Core` resolves LibStub; the other nine resolve `LibKa0s-Core-1.0`"*.
`docs/ARCHITECTURE.md:339` *"One row per run; generated, never hand-edited"*.
`settings/PanelEditor.lua:178` *"\"General\" is GONE"* against `:191` *"`General` is FIRST"* and
`:209-211` `EDITOR_TABS = { TAB_GENERAL, …`. `:1191` *"EVERYTHING that acts on the panel as a whole
lives here, in the band"*, `:1210` *"THREE EXPLICIT ROWS"* and `:1220` *"by refreshHeaderActs below"*
against `:1229` *"ONE ROW of LABELED controls"*; `grep -n 'function refreshHeaderActs'` → no output.
`.gitignore:6` *"state from tools/artwork/wiki_import.py"*; `git ls-files | grep -c wiki_import` → 0.
The counts to compare against: nine seams (6 `core/*Setup.lua` plus `settings/Slash.lua`,
`settings/OptionsSetup.lua` and `settings/Schema.lua`), and `library-stack-§7` at v2.64.0
(*"Fourteen of the fifteen majors floor on `LibKa0s-Core-1.0`"*).

**DEPENDENCIES drift (PM-045).** `DEPENDENCIES.md:63` cites `tests/_kit/framework.lua:515-516`
and `:498-500`. In kit 25, `:515` reads `--- no runner here writes one.` and `:498` reads
`--- with a remedy that said to delete a vendored file.…`. The listing is at `:643`
`collect(('ls -A "%s" 2>/dev/null'):format(dir))` and `:644` (the `dir /b` fallback), and the
LuaFileSystem note is at `:627-628`. The other citations still resolve: `loader.lua:72`
`setfenv(chunk, makeEnv(mocks))`, `vendor_sync.lua:126` `find . -type f`, `:194`
`if not io.popen then return nil end` and `:195` `io.popen(('git -C "%s" …`.

**Tier 2 triggers.** `NS.COMMANDS` holds 19 entries (`settings/Slash.lua:285` onward, counted with
`grep -cE '^\s*\{ ?"[a-z]+"'` over `:285-380` → 19). There are 3 bus messages. There are 8 Compat
shims, so `compat-layer.md` is owed (PM-031). A Profiles page ships (`settings/Panel.lua:521-523`).
`D:Diagnose` is host-owned (`core/DebugLogSetup.lua`), so `debug.md` is owed and present.

## §11 — Re-vendor store, README, prose and citation sweeps

**Re-vendor bundles (PM-048).** The playbook's script was run verbatim under `bash`:

```
horizon=2026-08-25
VENDORED  v1.18.0 v1.18.1 v1.19.0 v1.23.0 v1.24.0 v1.25.0 v1.26.0 v1.27.0 v1.28.0 v1.29.0 v1.31.0
          v1.32.0 v1.33.0 v1.34.0 v1.35.0 v1.36.0 v1.36.1 v1.36.2 v1.37.0 v1.38.0 v1.39.0 v1.42.0
          v1.44.0 v1.45.0 v1.46.1 v1.47.0 v1.50.0 v1.51.0 v1.52.0 v1.53.0 v1.55.0          (31)
RECORDED  v1.15.0 v1.25.0 v1.30.0 v1.31.0 v1.32.0 v1.33.0 v1.34.0 v1.55.0          (8)
UNRECORDED v1.18.0 v1.18.1 v1.19.0 v1.23.0 v1.24.0 v1.26.0 v1.27.0 v1.28.0 v1.29.0 v1.35.0 v1.36.0
          v1.36.1 v1.36.2 v1.37.0 v1.38.0 v1.39.0 v1.42.0 v1.44.0 v1.45.0 v1.46.1 v1.47.0 v1.50.0
          v1.51.0 v1.52.0 v1.53.0                                                   (25)
git log --since=2026-08-25 --format=%h -- libs/LibKa0s | wc -l  → 32
```

The bare-dated bundles were resolved from their `01_DELTA.md` first lines:
`2026-08-25` → `… vs LibKa0s v1.15.0`, `2026-09-03` → `v1.24.0 → v1.25.0` and `2026-09-12` →
`v1.29.0 → v1.30.0`. `docs/revendor/2026-09-23-v1.55.0/01_DELTA.md:1` reads
`# 01 — Delta: LibKa0s v1.54.2 → v1.55.0`. `v1.54.2` was a kit-only re-vendor (`e30e329`, which
touches `tests/_kit/`, `CLAUDE.md` and docs but not `libs/LibKa0s/`), so the trigger does not
count it.

**README (PM-046).**
`grep -noE '<[A-Za-z][A-Za-z _-]*>' README.md | grep -v '<br>'` → `51:<name>`, `79:<setting>`,
`80:<setting>`. Usage runs from `README.md:37` to `:96`. The configuration signpost is at `:67-69`
(*"Everything else is configuration … `/pm help` prints the full command list."*), and the last
paragraph is `:90-95` (*"What stays is the way back in. …"*).

**Prose (PM-041, and closure of PM-032).** An independent sweep with localization-§5's `BRITISH`
and `ALLOWED` lists, `ALLOWED` removed as whole words first, ran over tracked text files excluding
`libs/`, `tests/_kit/`, `docs/audits/`, `docs/reviews/`, `docs/revendor/`, `docs/superpowers/`,
`docs/automated-tests/<run>/`, `media/` and `tools/artwork/{bin,fonts}`. `TOTAL 2`:
`modules/SunnArtPacks.lua:61` (the waived texture path) and `tests/prose_waivers.lua:9` (the
waiver's own reason). `git grep -n catalogd` →
`docs/superpowers/specs/2026-07-31-panel-artwork-design.md:5` and
`docs/superpowers/specs/2026-08-02-wiki-artwork-import-design.md:5`, both
`> converted by … and catalogd by`. `git show e30e329 -- docs/superpowers` shows `-… catalogued by`
and `+… catalogd by` for each. The kit's `tests/_kit/test_prose.lua:209-213` reads
`SKIPPED_DIRS = { "libs/", "Libs/", "tests/_kit/", "docs/audits/", "docs/automated-tests/", "docs/perf-analysis/", "docs/reviews/", "docs/revendor/" }`.
`docs/ARCHITECTURE.md:305` names `docs/superpowers/` as frozen.

**Citation sweeps (documentation-§6).** The retired-notation command, verbatim from the section,
returns **0**. **Scope:** the whole checkout, with `libs`, `_kit`, `audits`, `reviews`,
`automated-tests`, `revendor` and `.git` excluded. The range check extracted every
`<name>-§N` occurrence from tracked text files outside `libs/`, `tests/_kit/` and the frozen stores
(67 distinct citations). Each was checked against `grep -c '^### [0-9]'` of its section file. Out
of range: **0**. Unknown file name: **0**.

## §12 — Reconciliation of figures across `02_DEVIATIONS.md` and `05_EXECUTION_PLAN.md`

| Figure | 02 | 05 | Source |
|---|---|---|---|
| Roots / total / MUST roots / MUST total | 17 / 19 / 15 / 17 | 17 / 19 / 15 / 17 | the counts table |
| Compat shims | 8 | 8 | §9 |
| Unrecorded re-vendor tags | 25 | 25 | §11 |
| Test cases at HEAD | 884 | 884 | §4 |
| Commits since newest bundle | 29 | 29 | §5 |
| Unmapped test-tree files / generators | 28 / 3 | 28 / 3 | §10 |
| Hub lines / Settings Schema lines | 471 / 102 | 471 / 102 | §10 |
| Parity cases today | 6 | 6 (→ 7) | §6 |

All of these were checked after both files were written.
