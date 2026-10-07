# 03 — Evidence (2026-10-07)

Every command below was run from the PanelMaster repo root on tree `06f3c28` unless stated, and every
heavy run through `~/.claude/dev-copilot/bin/ka0s-bounded`. Each count states its scope. Each
`file:line` was re-read before it was written here, and the quoted text is what is on disk.

## §1 — `PM-049`: the session-only rows survive *Reset all settings* (reproduced)

A scratch script **outside the repo** (session scratchpad, deleted with it) built the environment
exactly as `tests/run.lua:9-49` does — the kit's framework and loader, `tests/wow_mock.lua`, the
LibKa0s XML list, the TOC-derived list, the real `OnInitialize` / `OnEnable` — then drove the act:

```lua
NS.Registry:New("A"); NS.Registry:New("B")
NS.Unlock:SetUnlocked(true)
NS.DebugLog:Show()
-- print state
NS.Slash:DoResetAll()        -- what every global-reset surface ends in (settings/Slash.lua:36)
-- print state
local rec = NS.Registry:New("C")
-- print NS.Unlock:IsPanelUnlocked(rec.id)
```

Output (`ka0s-bounded lua <scratch>/repro_pm049.lua`):

```
before: panels=2 State.unlocked=true state.locked=false console=true
after DoResetAll: panels=0 State.unlocked=true state.locked=false console=true
new panel after reset: IsPanelUnlocked=true
```

The code that produces it:

- `settings/Slash.lua:36-47` — `function Sl:DoResetAll()` … `local ok, err = pcall(db.ResetProfile, db)` … `print(Sl.RESET_ALL_TEXT)`. No session-row restore.
- `settings/Panel.lua:343-344` — `function P:RestoreDefaults()` / `if NS.Slash and NS.Slash.ConfirmResetAll then NS.Slash:ConfirmResetAll() end` (the General page's Defaults button is the same act).
- `settings/Schema.lua:669` — `path = "state.locked", sessionOnly = true,`; `:672` — `get = function() return not NS.State.unlocked end,`.
- `modules/Registry.lua:620-633` — `dropSessionIDs()` clears per-panel state and the pending queue; `R:ReloadProfile` calls it. `NS.State.unlocked` is untouched.
- `settings/OptionsSetup.lua:285-286` — "The session-only rows -- `state.locked` and `state.debugConsole` -- / are outside `Sl:DoResetAll`, and that is deliberate rather than an oversight."; `:294` — "their own `set`, or by a /reload."
- The rule, `options-ui-§12`: "What the walk **MUST** keep is exactly what a profile reset cannot reach: **session-only rows** … Those survive a profile reset and **MUST** be restored row by row or they outlive a reset that took everything around them."

`PM-049a`: `tests/test_slash.lua:378` `test("Slash.CliResetAll: CONFIRMS first, …")` and `:395`
`test("Slash: accepting the reset empties the PROFILE, panels included")` each create one panel
(`R:New("Survivor")`) and assert `settings.gridSize` and `R:Count()`. A search of the reset tests
for the profile list, the session rows and the message finds none:
`grep -n 'GetProfiles\|profile list\|PanelsChanged\|MSG.PANELS' tests/test_slash.lua tests/test_debuglog.lua tests/test_profiles.lua tests/test_schema.lua`
returns only `tests/test_slash.lua:945` (a profile-verb comment) and `tests/test_profiles.lua:247`
(the reload's single sender), neither a reset case.

## §2 — The gate, measured

| Command | Scope | Result |
|---|---|---|
| `ka0s-bounded lua tests/run.lua` | the 38 declared suites (`tests/run.lua:95-133`), 5 of them the kit's | **1035 passed, 0 failed, 1 skipped, 1036 total**, exit 0; 10.69 s wall, 97 384 KB peak RSS (`/usr/bin/time -v`) |
| `ka0s-bounded lua tests/run.lua --list` vs `docs/test-cases.md` | inventory | `diff` (CR stripped) empty |
| `ka0s-bounded luacheck .` | everything except `.luacheckrc:4`'s `exclude_files` (`libs/`, `docs/audits/`, `docs/reviews/`, `_dev/`, `tests/_kit/`) | `Total: 0 warnings / 0 errors in 71 files`, exit 0 |
| `ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` | the fixed invocation over the sighted shadow (`libs/`, `tests/_kit/` excluded) | `complexity  pass — 0 warnings (fun rate 0.00), 17349 NLOC / 2168 funcs, avg NLOC 7.4, avg CCN 2.0 (max 15)`; `verdict: green`; `record: newest bundle 20260927-032003 measured 8cda106, 52 commit(s) behind HEAD` |

The one skip: `SKIP diagnostics contract: an addon that opts out lands the report and leaves logging
off — this addon keeps the default …`. A blind file would have set the status to `fail`
(`tests/_kit/run-automated-tests.sh:606-610`: `ST[complexity]="pass"` / `if [ "${CCN_BLIND:-0}" -gt 0 ]; then ST[complexity]="fail"`), so `pass` means 0.
`Kit.VERSION = 37` (`tests/_kit/framework.lua:20`). README badge: `README.md:7`
`![Tests](https://img.shields.io/badge/Tests-1035%2F1035_passing-green)` — passes over passes, the
skip outside both figures (testing-§5).

## §3 — Vendored payload drift (`library-stack-§7`)

Provenance: `grep -n 'Bundles \[LibKa0s\]' CLAUDE.md` → `45:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.70.0 (MIT).`;
the same grep on `README.md` → nothing; the library-section heading grep on `README.md` → nothing;
`grep -n 'WoW_Addon_Standard' README.md` → `6:![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)` (bare).

The sibling `../LibKa0s` has tag `v1.70.0`. The tag's tree was extracted with
`git -C ../LibKa0s archive v1.70.0 LibKa0s testkit | tar -x -C <scratch>/lk170`, then:

```
diff -r --strip-trailing-cr <scratch>/lk170/LibKa0s libs/LibKa0s   → empty
diff -r --strip-trailing-cr <scratch>/lk170/testkit tests/_kit     → empty
diff -rq <scratch>/lk170/LibKa0s libs/LibKa0s                       → empty (byte-identical without stripping too)
find … -type f | wc -l                                              → 159 and 159
```

`git ls-files -s tests/_kit/run-automated-tests.sh` → `100755 685cbcc… 0`. The suite's own gate
agrees: `PASS libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles`, `PASS tests/_kit
is the test kit that shipped with that release`, `PASS the automated-test runner is recorded
executable (100755)`.

## §4 — Line endings and packaging

```
test -f .gitattributes                          → present
grep '^\* text=auto eol=…'                      → 26:* text=auto eol=crlf
grep -nE '^\*\.(sh|py) text eol=lf'             → 36:*.sh text eol=lf, 37:*.py text eol=lf
grep -c ' binary'                               → 24
head -n 84 .gitattributes | tr -d '\r' vs line-endings-§5's client-bound body (84 lines) → identical
tail -n +85 … | grep -m1 .                      → # --- line-endings-§5 appendix ---
(e) the playbook's one-liner over `git ls-files -z` (whole tracked set, no exclusions) → 0
```

The kit agrees: `PASS eol: every tracked file carries the terminator .gitattributes declares for it`,
`PASS eol: .gitattributes is line-endings-§5's canonical body for this repo kind`.

Packaging, the playbook's three loops run under `bash` (the session shell is `zsh`, which does not
word-split an unquoted variable, and a first run under it printed one malformed line; re-run under
`bash -c`): (a) nothing printed, (b) `UNACCOUNTED — .git` only, (c) nothing printed. No `externals:`.

## §5 — LOC census (`layout-§1`)

```
git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | wc -l          → 71
git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | xargs wc -l | sort -rn | head
  28634 total
   1184 tests/test_libka0s.lua
   1084 tests/test_slash.lua
    972 modules/Registry.lua
    956 tests/test_sunnart.lua
    953 modules/Canvas.lua
```

Scope: every tracked authored `.lua`, `tests/` included; `libs/` and `tests/_kit/` excluded. No
generated-data exemption is declared (`docs/ARCHITECTURE.md:376-377`: "Nothing in this repo is
generated non-shipping data … `tests/run.lua` sets no `Kit.layoutCap`"). Over 1500: none. Band:
two. The census prose (`docs/ARCHITECTURE.md:390-391`) reads "The largest authored file is
`tests/test_libka0s.lua` at 1160 lines, and the largest shipped one / `modules/Registry.lua` at 987"
— `PM-044`.

## §6 — Seams and stubs (`library-stack-§7`, `testing-§8`)

`tests/test_surface_parity.lua` cases at `:65` Core, `:109` DebugLog, `:145` Launcher, `:163` Slash,
`:204` Options, `:240` Schema (both levels), `:263` Bus, `:286` Lifecycle; each names its grep in a
comment (`:72`, `:112`, `:148`, `:166-167`, `:209`, `:266`, `:303`).

`PM-050`: `settings/Slash.lua:508-509` — `Sl.FormatKV = function(path, valueStr)` /
`return ("|cFFFFFF00%s|r = |cFFFFFFFF%s|r"):format(tostring(path), tostring(valueStr))`;
`tests/test_surface_parity.lua:193-194` — `assertEqual(Sl.FormatKV("a.b", "7"), libSlash.FormatKV("a.b", "7"))` /
`assertEqual(Sl.FormatKV("a.b", "7"), "|cFFFFFF00a.b|r = |cFFFFFFFF7|r")`. The rule:
slash-commands-§1 "The stub **MUST NOT** re-implement the library's rendering — no copied row
formatter, no copied parser, no copied `key = value` shape." The sanctioned constant:
`settings/Slash.lua:547` `Sl.DISABLED_LINE_FORMAT = "%s is disabled \226\128\148 enable it with |cFFFFFF00%s|r"`,
pinned with `T.assertLibraryConstant` (`tests/test_surface_parity.lua`, Slash case).

Descriptor `debug` fields (debug-logging-§4): Slash `settings/Slash.lua:678`
`debug = function(tag, message) NS.Debug(tag, message) end,`; Options
`settings/OptionsSetup.lua:184`; Launcher `core/LauncherSetup.lua:224` and `debugAtEnable` `:229`;
Lifecycle `core/LifecycleSetup.lua:245`. Options `addonName = addonName` at
`settings/OptionsSetup.lua:181`.

## §7 — The deviation register (`audit-review-history`)

`docs/ARCHITECTURE.md:346` header `| Rule | What differs | Why | Decided | Re-check trigger |`; rows at
`:348` (`performance-§1`), `:349` (`events-frames-taint-§8`), `:350` (`localization-§1`).

- `performance-§1` trigger "a second `OnUpdate` or repeating ticker …": census
  `git ls-files '*.lua' ':!libs' ':!tests' | xargs grep -nE 'OnUpdate|C_Timer|NewTicker|ScheduleTimer|ScheduleRepeatingTimer'`
  → one `SetScript("OnUpdate", mouseoverTick)` (`modules/Canvas.lua:662`), its removal (`:680`), a
  read in the diagnostics (`modules/Diagnostics.lua:274`), and one `ScheduleTimer`
  (`settings/OptionsSetup.lua:260`, the colour-picker throttle); the rest are comments.
  `modules/Canvas.lua:647-652` is `local function mouseoverTick(_, delta)` … `updateMouseover()`, as
  the row cites; `core/Constants.lua:317` is `mouseover      = false,`, as the row cites. Not fired.
  #31 and #44 resolve (closed).
- `events-frames-taint-§8` trigger: `grep -nE 'UnitGetTotalAbsorbs|UnitGetTotalHealAbsorbs|UnitGetIncomingHeals|UnitHealth|UnitThreatSituation|UnitDetailedThreatSituation|GetAuraData|GetPlayerAuraBySpellID|UNIT_AURA'`
  over the shipped source → **0**. The non-comment `Unit*(` calls: `core/Compat.lua:88`
  `return UnitAffectingCombat("player") and true or false` only. The row's **Why** says "the only
  unit/client APIs it calls at all are `UnitClass` and `C_AddOns.GetAddOnMetadata`" — `PM-044`.
- `localization-§1` trigger: `ls locales/` → `enUS.lua`, `PostLoad.lua`. `locales/enUS.lua:6`
  `NS.L = setmetatable(NS.L or {}, { __index = function(_, k) return k end })` resolves; `:8-10` is
  the English-only reasoning.

## §8 — The disabled state (`slash-commands-§7`)

```
git ls-files '*.lua' ':!libs' ':!tests/_kit' ':!tests' | xargs grep -nE 'Register(Unit)?Event|RegisterMessage|RegisterBucketEvent'
git ls-files '*.lua' ':!libs' ':!tests/_kit' ':!tests' | xargs grep -nE 'Unregister(All)?Events?|UnregisterMessage|UnregisterBucket|CancelTimer|CancelAllTimers|:Cancel\(|SetScript\("OnUpdate", *nil\)'
```

Scope: the shipped authored source (tests excluded; this is a runtime claim). Registration call
sites: `core/LifecycleSetup.lua:141` (the stand-up loop over `PLAYER_ENTERING_WORLD`,
`PLAYER_REGEN_ENABLED`, `PLAYER_REGEN_DISABLED`, `:72-76`), `core/PanelMaster.lua:67`
(`PLAYER_LOGIN`), `modules/Canvas.lua:932-934` (three messages), `settings/PanelEditor.lua:708`,
`:719` (two messages). Undone: `core/LifecycleSetup.lua:106-109` (three `UnregisterEvent`),
`modules/Canvas.lua:951` (`ev:UnregisterAllMessages()`), `:680` (the `OnUpdate`). Survivors:
`PLAYER_LOGIN` (setup) and the two Panels-page subscriptions (recorded in `open-evolutions`, not
ruled). The rung: `modules/Canvas.lua:810` `local down = NS.Lifecycle and NS.Lifecycle:IsDown()`,
`:837` strips the overlay. The suite: `tests/test_disabled.lua` cases at `:155`, `:175`, `:200`,
`:221`, `:253` (5b), `:306`, `:352`, `:400`, `:451`, `:484`, `:522`, `:557`, `:586`, `:613`, `:656`,
plus `:670`, `:686`; `grep -c 'red under'` → 9. All pass.

## §9 — Compat and dead rungs (`compat`, `PM-051`)

`grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua` → **8** (`:27`, `:56`, `:65`,
`:86`, `:115`, `:136`, `:157`, `:182`).

- `core/EnvSetup.lua:52-57` — `if C_AddOns and C_AddOns.GetAddOnMetadata then` / `return C_AddOns.GetAddOnMetadata(addonName, field)` / `end` / `if type(GetAddOnMetadata) == "function" then` / `return GetAddOnMetadata(addonName, field)` / `end`.
- `core/Compat.lua:28-33` — `local count = C_AddOns and C_AddOns.GetNumAddOns` / `local info  = C_AddOns and C_AddOns.GetAddOnInfo` / `if type(count) ~= "function" or type(info) ~= "function" then` / `count = type(GetNumAddOns) == "function" and GetNumAddOns or nil` / `info  = type(GetAddOnInfo) == "function" and GetAddOnInfo or nil` / `end`.
- `.luacheckrc:34` — `"C_AddOns", "GetAddOnMetadata", "GetNumAddOns", "GetAddOnInfo", "strtrim",`.
- The rule, `compat`: "Two worked cases: `GetAddOnMetadata` behind `C_AddOns.GetAddOnMetadata` in a library-absent stub (the global survives only as the newer namespace's member) …". `PanelMaster.toc:1` `## Interface: 120100`, the same value as every TOC under `GIT/` (`grep -h '^## Interface' */*.toc | sort | uniq -c` → `12 ## Interface: 120100`).

## §10 — Issue store (`audit-review-history`)

`gh issue list --state all --limit 200 --json number,title,state,labels` → **55** issues;
`gh label list --json name,color` → `state:untriaged ff0000`, `state:triaged ffff00`, `state:done
00ff00`, `state:will-not-do 0000ff`, `severity:critical 110000`, `severity:high 110800`,
`severity:medium 111100`, `severity:low 001100` (canonical). A per-issue check (exactly one
`state:`, exactly one `severity:`, open ⇒ triaged/untriaged, closed ⇒ done/will-not-do, no `[`
title prefix) prints one line: `47 ['closed-with-state:triaged'] settings/PanelEditor.lua has crossed
its own recorded split`. `gh issue view 47` → `CLOSED 2026-09-26T17:41:39Z [state:triaged,severity:medium]`.
Open issues: #2, #5, #8, #10, #11, #13, #26, all `state:triaged`. No `gh api graphql` was used.

## §11 — Re-vendor bundles (`audit-review-history`, `PM-048`)

The playbook's two-listing check, run verbatim under `bash`:

```
horizon=2026-08-25
commits=54            # git log --since="2026-08-25 00:00" --format=%H -- libs/LibKa0s tests/_kit
vendored=51 recorded=49
UNRECORDED:
v1.69.0
v1.70.0
```

`git log -3 -- libs/LibKa0s tests/_kit` → `f61f2b7 2026-10-07 chore: re-vendor LibKa0s v1.70.0`,
`4e15691 2026-10-06 chore: re-vendor LibKa0s v1.69.0 (kit 37; adds the line chart widget)`,
`cbc3743 2026-10-04 DC-REV-01: re-vendor LibKa0s v1.68.1 (kit 36; rename-only)`;
`git show f61f2b7:CLAUDE.md` and `4e15691:CLAUDE.md` carry `v1.70.0` and `v1.69.0`. Newest bundle:
`docs/revendor/2026-10-04-v1.68.1/`. Every bundle (21) has `01_DELTA.md` and `05_SUMMARY.md`.

## §12 — Docs, citations and notation (`documentation`)

- **Map** (`documentation-§3`): `git ls-files 'docs/*.md'` minus `docs/(audits|reviews|revendor|superpowers|investigations)/` and the dated `automated-tests/` / `perf-analysis/` bundles → 21 files; rows in `docs/ARCHITECTURE.md:274-321` → 23. On disk, not in the map: `ARCHITECTURE.md` (the MAY self-row). In the map, not on disk: `message-bus.md`, `midnight-quirks.md`, `perf-analysis/README.md` — the three *Not applicable* rows. No duplicate.
- **Module map:** every one of the 75 tracked authored `.lua` / `.py` files (`libs/`, `tests/_kit/` excluded) is named in `docs/module-map.md` (loop under `bash`, `checked=75`, nothing printed).
- **Citation range check** (`documentation-§6`): every `filename-§N` in the tracked set minus `libs/`, `tests/_kit/` and the frozen stores, checked against each section file's `grep -c '^### [0-9]'`: **1250** citations, **0** unknown filenames, **0** out of range.
- **Elided short forms:** `grep -noE '(^|[^a-z-])§[0-9]+'` over the same `.lua`/`.md`/`.toc`/dotfile set → **74** (11 in `docs/ARCHITECTURE.md`, 9 in `settings/Slash.lua`, 8 in `tests/test_disabled.lua`, …). Not filed (`02_DEVIATIONS.md`, *Not filed*), except `settings/Slash.lua:700` "(launcher-§2, §7)", folded into `PM-044`.
- **Retired `§N.M` notation**, two scopes recorded because they disagree: `git ls-files | grep -vE '^(libs/|tests/_kit/|docs/(audits|reviews|automated-tests|revendor)/)' | xargs grep -nE '§[0-9]+\.[0-9]'` → **0**. A first `grep -rn` pass with `--include` filters returned **7** — all seven inside frozen bundles (`docs/audits/2026-07-30/05_EXECUTION_PLAN.md:36`, `:38`, `:40`; `docs/revendor/2026-09-23-v1.55.0/…` four lines), which its path filter failed to drop because `grep -r` prefixes no `./`. The `git ls-files` scope is the question asked; the count is 0.
- **README** (`documentation-§1`): numbered-list grep outside fences → nothing; placeholder grep → `README.md:65` `… and \`/pm profile <name>\`` and `:229` `… \`/pm profile <name>\` switches to it from chat. |`; `git blame` dates both to `9bceeab` (2026-09-29). `:271` ends `<br>Released on lint, tests and complexity only: Panel Master ships no \`tests/perf.lua\`, so the perf suite was skipped, not measured. |`. `## Reporting a bug` at `:252` is the fixed body with `/pm`.
- **CLAUDE.md order** (`documentation-§2`): `:45` `Bundles [LibKa0s](…) v1.70.0 (MIT).`, `:62` `Green gate before every commit: \`lua tests/run.lua\` and \`luacheck .\` (0/0).`
- **`PM-054`:** `docs/automated-tests/README.md:29` `| \`complexity\` | \`lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .\` | no — recorded only | **yes** |`; `docs/testing.md:242` `| \`complexity\` | \`bash tests/_kit/run-automated-tests.sh --suite complexity\` (lizard over the kit's sighted shadow, kit revision 36; …`.
- **`PM-044` comment drift**, re-read: `core/LifecycleSetup.lua:53-54` "the launcher's registration (core/LauncherSetup.lua). The button stays on the minimap; what / its LEFT click does changes, and that gate is in that file."; `:117-118` "it re-registers the same / three events core/PanelMaster.lua's OnEnable registers"; `core/LauncherSetup.lua:226` "Register runs at OnEnable, where the session-only flag is always off"; `settings/Slash.lua:317` "`/pm help`, the README's command table and the settings landing page all"; `:367` "checkbox and the minimap button's left click write through"; `:700` "`slash`. Republished because the LAUNCHER'S left click prints it too (launcher-§2, §7) and must". Against: `core/PanelMaster.lua:40` `if NS.Launcher then NS.Launcher:Register() end` inside `addon:OnInitialize` (`:29`).
- **Hub shape** (`PM-042`): `tr -d '\r' < docs/ARCHITECTURE.md | wc -l` → 422; headings at `:9`, `:19`, `:29`, `:80`, `:114`, `:150`, `:191`, `:212`, `:261`, `:268`, `:274`, `:323`, `:372`.
- **`PM-052`:** `docs/ARCHITECTURE.md:169` "`minimap = { hide = false }`, **declared** rather than seeded … `minimapPos` is LibDBIcon's to write and has no row." (the launcher table, not Settings Schema `:29-78`); `defaults/Global.lua:70` "exactly this key, inverted. `minimapPos` is deliberately absent: it is LibDBIcon's to write and".

## §13 — Reconciliation and the re-read pass

- Every `file:line` in all five artifacts was re-read after writing. Corrected before shipping: the
  `.luacheckrc` line for the AddOns globals (first written `:37`, actual `:34`), the reset tests'
  span (first written `:378-410`, actual `:378-409`), and the registration census in
  `01_CURRENT_STATE.md` §8 (first written "6 sites", recounted as 7 call sites).
- Figures quoted in more than one artifact and reconciled: roots **12**, total **13**, MUST
  failures **10** / **11**; tests **1035/1/1036**; luacheck **71** files; complexity **17349** NLOC,
  **2168** functions, max **15**; record **52** commits behind; re-vendor **54 / 51 / 49**, two
  unrecorded; LOC **1184 / 1084 / 972**; issues **55**; citations **1250** / elisions **74**.
- Nothing was written outside `docs/audits/2026-10-07/`. The scratch reproduction script and the
  extracted tag tree live in the session scratchpad.
