# 03 — Evidence (2026-09-08)

Every finding in `02_DEVIATIONS.md` and every compliance claim in `01_CURRENT_STATE.md` is backed
here by a `file:line` citation with the cited text quoted beside it, or by a recorded command with
its real output **and the scope it covered**.

**Two rules were applied to this file after it was written**, and both are checks rather than
intentions:

1. **Every `file:line` in all five artifacts was re-read and the cited text quoted beside it.**
   Eight citations drafted from memory of a nearby line did not resolve to the claimed content and
   were **corrected before this bundle was written out**, not shipped: the tab-pitch measurement
   (drafted `OptionsWidgets.lua:434`/`:429`, actually `:447`/`:452` with the declaration at `:421`),
   the eight chrome-band controls (drafted `:1078/:1090/:1113/:1130/:1147/:1158/:1176/:1187`,
   actually `:1075/:1091/:1111/:1126/:1150/:1164/:1182/:1192`), the slash descriptor (drafted `:385`,
   actually `:386`), the Options descriptor (drafted `:160`, actually `:154`), the Options stub
   (drafted `:44`, actually `:45`), `S:InstallMaster` (drafted `:200`, actually `:199`),
   `Util.ResolveColor`'s range (drafted `:225-236`, actually `:225-235`), and the `options-ui-§16`
   ruling (drafted `:192`, actually `:191`). The corrections are recorded here rather than silently
   applied.
2. **Every count below is produced by a recorded command whose scope is stated** — which paths it
   swept and which it did not. A count whose scope is unstated is not a count.

---

## 0. Provenance of the standard

```
$ RAW=https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master
$ curl -fsSL "$RAW/standards/STANDARDS.md" -o STANDARDS.md && head -1 STANDARDS.md
# Ka0s WoW Addon Standard (v2.39.0, 2026-09-07)
```

**v2.39.0 confirmed at line 1 before any measurement was taken.** Had it read v2.38.0 this run would
have stopped.

The Sections list was then **followed** — never hard-coded — and every linked file fetched:

```
$ grep -oE '\(standards/[a-z-]+\.md\)' STANDARDS.md | tr -d '()' | sed 's|standards/||' | sort -u | wc -l
26
$ for f in $(cat secs.txt); do curl -fsSL "$RAW/standards/standards/$f" -o "$f" || echo "FAIL $f"; done
$ ls *.md | wc -l
29                       # 26 sections + STANDARDS.md + AUDIT.md + ADDONS.md
```

No `FAIL` line was printed. md5s of the fetched set, so this run is reproducible:

| File | md5 |
|---|---|
| `STANDARDS.md` | `2836822ed938424f86e40b17f5963111` |
| `AUDIT.md` | `5f61e900761f01d0840143a1b69c87a5` |
| `anti-patterns.md` | `2193032cb6abe1f2631b9069cea8529d` |
| `documentation.md` | `46923aa04d3420a772a6fdd61bbeb1e0` |
| `localization.md` | `5e5c94dda981ed78532eba22c774d386` |
| `line-endings.md` | `de9dacd037d14cc38c0a2c7ce152216d` |
| `lint.md` | `2e1c200885da2b130dadae10347d5f2b` |
| `library-stack.md` | `a70f66138421d3cfa6c048286fe858ba` |
| `options-ui.md` | `d994d91d563879c4ed81421bda6192c9` |
| `toc-file.md` | `c50f333f616b0d4ba7990d6074631015` |
| `automated-tests.md` | `e89888be538944779012aac1359c1e0f` |
| `audit-review-history.md` | `ec0f73a45796ae4a44cdc51d0a3a77ec` |
| `layout.md` | `77e2a88e4f43b5db67429158a3f32e15` |
| `standalone-windows.md` | `fdfeb9e05d9e3c7b4ff7d49cba848da3` |
| `packaging.md` | `fad5bccef6dda2082d48a29bcdedfd6b` |

(The remaining 11 sections were fetched in the same loop and read; their md5s are omitted only for
length.)

---

## 1. Lint and the headless suite

```
$ luacheck .

Total: 0 warnings / 0 errors in 57 files

$ lua tests/run.lua

783 passed, 0 failed, 0 skipped, 783 total
```

**Scope of the `0/0`, which is the half that matters (`lint`, amended this release).**
`.luacheckrc:12`, quoted:

> `exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/_kit/" }`

So the sweep **covered** `core/`, `defaults/`, `locales/`, `modules/`, `settings/`, `tests/` (all of
it except the vendored kit) and any Lua under a live `docs/` directory. It **did not cover**
`libs/` (vendored, linted upstream), `tests/_kit/` (the vendored kit, linted in the LibKa0s repo),
`_dev/` (absent here) and the frozen `docs/audits/` and `docs/reviews/` bundles.

`lint`'s amended requirements are met exactly:

- **`exclude_files` narrows to `tests/_kit/`, not bare `tests/`.** It does, and `.luacheckrc:4-9`
  states why — *"tests/_kit/ is that same fact one level down: it is a byte copy of the library's
  testkit/ … That reason reaches the vendored copy and nothing else: the rest of tests/ is ours, and
  it is linted (lint-§1)."*
- **The harness global sits in a `files["tests/"]` stanza, never top-level `read_globals`.**
  `.luacheckrc:58-74`, quoted at `:58`: `files["tests/"] = {` and at `:60-61`:
  *"The harness's exposed table, written at tests/run.lua:75 and read back by every suite file."* /
  `"_G.PM_TEST",`. `.luacheckrc:50-53` states the reason — *"A name granted at the top level is
  granted to core/, modules/ and settings/ as much as to a suite."*
- **No blanket `ignore`, and the tree is not turned on behind one.** `.luacheckrc:13`, quoted:
  *"NO TOP-LEVEL `ignore`, and none is coming back (lint-§1, `M4c-06`)."* Every surviving `ignore` is
  a per-file stanza naming `212/self` for one file (`.luacheckrc:104-185`, ten stanzas), and
  `tests/test_lintconfig.lua` gates that shape in four cases, all PASS.

The **57 files** figure versus the record's **55** is `PM-033`'s drift, not a scope change.

---

## 2. Line endings (`line-endings`) — the five checks, run

```
$ test -f .gitattributes && echo present
present

$ grep -n '^\* text=auto eol=\(crlf\|lf\)$' .gitattributes
26:* text=auto eol=crlf

$ grep -n '^\*\.sh text eol=lf$' .gitattributes
34:*.sh text eol=lf

$ grep -c ' binary$' .gitattributes
21

$ git ls-files -z | xargs -0 -I{} sh -c '
    set -- $(git check-attr text eol -- "{}" | sed "s/.*: //")
    [ "$1" = unset ] && exit
    cr=$(tr -dc "\r" < "{}" | wc -c); lf=$(tr -dc "\n" < "{}" | wc -c)
    case "$2" in crlf) [ "$lf" -gt 0 ] && [ "$cr" -ne "$lf" ] && echo "{}";;
                 lf)   [ "$cr" -gt 0 ] && echo "{}";; esac' 2>/dev/null | wc -l
0
```

**Scope of (e): the whole tracked set.** `git ls-files` with no path argument, so it swept `libs/`,
`tests/_kit/`, `docs/` including every frozen audit, review, revendor and automated-test bundle, and
`media/`. Files git marks `binary` are skipped by the `text = unset` guard, and a file with no `\n`
at all is skipped by construction. **Nothing was excluded.**

**(b) is right for this repo's kind.** `PanelMaster.toc` exists and the repo ships Lua to the client,
so it is client-bound and pins `eol=crlf`. Correct.

**§5 body diff — a diff, not a reading, and the tail is the sanctioned appendix.** The canonical
client-bound body was extracted from `line-endings.md` §5 (81 lines) and §5's own three lines were
run. `tr -d '\r'` is applied because the working tree is CRLF by the pin and the published body is
LF; without it the diff is 81 whitespace hunks and says nothing:

```
$ n=$(wc -l < canonical_client.gitattributes) ; echo $n
81
$ diff <(head -n "$n" .gitattributes | tr -d '\r') canonical_client.gitattributes ; echo "EXIT=$?"
EXIT=0
$ tail -n +82 .gitattributes | tr -d '\r' | grep -m1 .
# --- line-endings-§5 appendix ---
```

**Empty, and the tail's first non-blank line is exactly the delimiter.** `.gitattributes`
is 87 lines. Lines 1-81 are the canonical client-bound body byte-for-byte; `:82` is blank and `:83` is, quoted:

> `# --- line-endings-§5 appendix ---`

followed by `:84-86` (one comment per entry) and `:87`, quoted:

> `tools/artwork/bin/realesrgan-ncnn-vulkan binary`

One delimiter line, one path-keyed mark, one path per entry, a comment per entry, nothing spliced
into the body. That is exactly the shape v2.39.0 sanctioned, so it files **nothing** — neither a §5
finding nor a register row — and the register row that used to record the old in-body placement was
correctly retired (`docs/ARCHITECTURE.md:251-263`).

**(e) has an owner in the repo, and the owner agrees with this audit.** `line-endings-§7` MUSTs the
vendored gate. `tests/_kit/test_eol.lua` is present at kit revision 15
(`tests/_kit/framework.lua:20` — `Kit.VERSION = 15`), and it ran in this suite:

```
  PASS  eol: every tracked file carries the terminator .gitattributes declares for it
```

A repo that has the gate, reports green and still fails (e) would be a **gate** finding. This one
reports green and (e) is 0, so there is nothing to file in either direction. Contrast the
2026-09-07 bundle, which measured **5** — that run predates `M4-10`'s renormalize; the frozen bundle
is never edited, and this note is how the two numbers sit side by side without contradicting.

---

## 3. Complexity (`performance-§10`, `automated-tests`) — measured, not read

The standard's **exact** invocation, from the repo root, verbatim:

```
$ lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .
===============================================================================================================
No thresholds exceeded (cyclomatic_complexity > 15 or length > 1000 or nloc > 1000000 or parameter_count > 100)
==========================================================================================
Total nloc   Avg.NLOC  AvgCCN  Avg.token   Fun Cnt  Warning cnt   Fun Rt   nloc Rt
------------------------------------------------------------------------------------------
     12848       7.4     2.0       57.6     1501            0      0.00    0.00
```

**Scope:** the whole repo bar `./libs/*` and `./tests/_kit/*`, which is what the two `-x` flags say.
`docs/`, `tools/` and `media/` contain no Lua that `lizard -l lua` reads. No flag was added, no path
narrowed, no threshold re-tuned.

**Compared against the latest run bundle**, `docs/automated-tests/20260908-181416/complexity.txt`
(tail) and its `manifest.json`:

```
     12627       7.4     2.0       57.4     1494            0      0.00    0.00
"git": { "sha": "564acbdcca0522d5abc75ed5934d41e0e3544170", "branch": "feat/2026-09-07-audit-review-remediation", "dirty": false }
"complexity": { "status": "pass", ... "maxCcn": 15, "nloc": 12627, "functions": 1494, ... "bandFiles": 4, "overCapFiles": 0 }
```

```
$ git rev-list --count 564acbdcca0522d5abc75ed5934d41e0e3544170..HEAD
4
$ git log --oneline 564acbd..HEAD
bb7b9fe Merge branch 'feat/2026-09-07-audit-review-remediation'
c422422 M4c-06: the blanket ignore goes, and half of it had been silencing nothing
ba46db8 M5-08: § 22, because the names are what this addon reads
0b36008 M5-01: the record is regenerated, and PanelEditor's own trigger comes due
```

**Drift, stated:** nloc 12627 → 12848, functions 1494 → 1501, cases 778 → 783, lint files 55 → 57.
**No function crossed a `lizard` threshold** and **no file entered or left the `layout-§1`
1000–1500 band** — this is `PM-033`, and it is Info for the reasons that entry gives.

**The band, re-measured at HEAD with the census's own command:**

```
$ git ls-files '*.lua' | grep -v '^libs/' | grep -v '^tests/_kit/' | xargs wc -l | sort -rn | head -6
  21395 total
   1488 settings/PanelEditor.lua
   1356 tests/test_artwork.lua
   1222 tests/test_panel.lua
   1188 modules/Artwork.lua
    999 modules/Registry.lua
```

Identical to `docs/ARCHITECTURE.md:290-293`, the census's own rows. Nothing over the 1500 cap; four in the band; the nearest
file outside it is `modules/Registry.lua` at 999.

**Max CCN 15, and which kind it is.** `lizard` warns on nothing, so no function is above 15. The
addon's densest function is `refreshHeaderActs` (`settings/PanelEditor.lua:1301`) at exactly 15 —
**dense defaulting and guarding**, not tangled control flow: its body re-points six band widgets at
whatever the picker shows and bails on a single nil check (`:1202-1205`, quoted at `:1202-1203`: *"Parked as one
      -- table rather than six fields so that refreshHeaderActs can bail on a single nil check"*, the
table itself at `:1205`). `lizard`
counts every `and`/`or` short-circuit as a decision, which is why a run of `rec and rec.id or nil`
lines scores like a branch tree and is not one.

**The watch list read as a decision record, not an inventory** (anti-pattern #53):

```
$ git log --oneline --follow -- docs/automated-tests/RESULTS.md | head -4
0b36008 M5-01: the record is regenerated, and PanelEditor's own trigger comes due
5d6b7eb automated-tests: record run 20260825-103450 — green on a 3.7s suite
f83a5a9 release: 1.0.0 — the addon's first published version
090dc5d automated-tests: record run 20260807-114409 — green
$ for d in docs/automated-tests/2026*/; do grep -o '"release": [^,]*' $d/manifest.json | head -1; done
"release": null      (x6)
"release": "1.0.0"   (20260807-160022)
"release": null      (x2)
```

**One** release run on record, so no *Accepted* disposition has been carried across three consecutive
**release** runs — the shelf-life clock has not tripped. And the list is four entries long with one
of them not reading *accepted* (`docs/automated-tests/RESULTS.md:83`, quoted: *"**The trigger has
fired, and it is tracked: issue [#47]…**"*), so it is not a backlog wearing a watch list's clothes.

**Complexity refactors since the last audit, audited against `performance-§11`.** `M4c-06` and
`M4-18` are the only diffs in that window that touch function bodies. Neither dumps a body into an
unnamed helper (#52); neither builds a dispatch or defaults table inside a function (#43 — the
band's six-widget table at `settings/PanelEditor.lua:1205` is built once in `BuildPage`, not
per-call); and no `t.k = stored.k or D.k` was introduced over a field whose stored `false` is a user
choice — the repo's falsy-state defaulting is `== nil` throughout (`core/Util.lua:19`, `:105`,
`:114`; `settings/Schema.lua:284`, `:388`; `modules/Registry.lua:292`, `:743`, `:749`).

**Artifact audit against `automated-tests`:** runner vendored and executable —
`git ls-files -s tests/_kit/run-automated-tests.sh` → `100755`; `docs/automated-tests/README.md` and
`RESULTS.md` both exist; **no retired `docs/complexity.md`**; nine frozen bundles, none pruned.

---

## 4. Vendored Ka0s-owned library drift

Sibling repo found at `../LibKa0s`. The tag to diff against is the one the addon **says** it
vendored, read from root `CLAUDE.md:44`, quoted:

> `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.27.0 (MIT). That line is the`

```
$ git -C ../LibKa0s archive v1.27.0 | tar -x -C /tmp/lk
$ diff -r /tmp/lk/LibKa0s libs/LibKa0s ; echo "SHIP_DIFF_EXIT=$?"
SHIP_DIFF_EXIT=0
$ diff -r /tmp/lk/testkit tests/_kit ; echo "KIT_DIFF_EXIT=$?"
KIT_DIFF_EXIT=0
```

**Both empty**, over the **whole** folder — every module, not just the wired ones. Diffed against the
**tag**, not the sibling's `HEAD`; `v1.27.0` also happens to be the newest tag
(`git -C ../LibKa0s tag --sort=-v:refname | head -1` → `v1.27.0`), so there is no scheduling gap
either. Anti-patterns **#45** (drift) and **#48** (partial vendoring) both clean.

The harness lives under `tests/_kit/`, never `libs/`. Confirmed by the second diff's target path.

**The provenance line's own location — three greps, and their output is the evidence:**

```
$ grep -n 'Bundles \[LibKa0s\]' CLAUDE.md
44:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.27.0 (MIT). That line is the
$ grep -n 'Bundles \[LibKa0s\]' README.md
(no output)
$ grep -nE '^## (Libraries|Bundled libraries|Libraries and credits|Credits and libraries|Credits and bundled libraries)' README.md
(no output)
$ grep -n 'WoW_Addon_Standard' README.md
6:![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
```

Exactly one hit in `CLAUDE.md` naming the vendored tag; none in `README.md`; no library-inventory
heading; and the badge is the **bare** `![Standard](…)` form with underscores, not the linked
`[![Standard](…)](…)` form. Anti-patterns **#58** and **#59** clean, `documentation-§1` item 2 clean.
The README's intro prose was read as well as grepped — `README.md:1-42` is title, five badges, logo
and a two-paragraph description with no library roll-call.

The consumer-side gate agrees:

```
  PASS  libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles
  PASS  tests/_kit is the test kit that shipped with that release
```

---

## 5. `PM-031` — the `compat-layer.md` trigger, counted with the published grep

`documentation-§3`'s own command, over the addon's own file and nothing else:

```
$ grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua
8
$ grep -nE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua
27:function Compat.AddOnFolders()
56:function Compat.GetScreenSize()
65:function Compat.GetUIScale()
79:function Compat.InCombat()
103:function Compat.RegisterMedia()
124:function Compat.FetchMedia(mediaType, name)
139:function Compat.MediaList(mediaType)
164:function Compat.MouseIsOver(frame)
$ wc -l core/Compat.lua
173 core/Compat.lua
```

**Scope: `core/Compat.lua` only**, which is what the rule specifies — shims `LibKa0s` supplies are
not counted and must not be re-documented.

**8 ≥ 3, so the trigger has fired.** The doc does not exist:

```
$ ls docs/compat-layer.md
ls: cannot access 'docs/compat-layer.md': No such file or directory
```

And the map asserts otherwise. `docs/ARCHITECTURE.md:145`, quoted in full:

> `| `compat-layer.md` | Not applicable | `core/Compat.lua` normalizes the addon roster, screen size, UI scale, LSM and class color — no addon-specific shim beyond what the row in `module-map.md` records |`

That the eight are the addon's own, not the library's, is stated in the file itself.
`core/Compat.lua:5-7`, quoted:

> `-- Retail-only addon: no game-flavor branching (compat). Every varying / deprecated API is gated by a`
> `-- direct C_*/global presence check here, so a shim degrades to nil/false when its API is absent —`
> `-- never by reading a game-flavor project id. Feature modules call NS.Compat.X, never the raw API.`

and `core/Compat.lua:11-14`, quoted:

> `-- NOTE: the TOC-metadata reader that used to head this file is gone. It now lives in`
> `-- core/EnvSetup.lua as NS.Meta / NS.Version, over LibKa0s-Env-1.0 — it was the same eleven-times`
> `-- duplicated ladder in every addon of this collection, which is what made it the library's rather`
> `-- than ours. The readers below stay: they are PanelMaster's own.`

**The other six Tier 2 triggers, re-evaluated against the code in the same pass:**

| Doc | Trigger | Measured | Map row | Verdict |
|---|---|---|---|---|
| `slash-dispatch.md` | ≥ 8 commands, or any subcommand tree | 18 rows in `NS.COMMANDS`, `settings/Slash.lua:273-326` | Present | correct |
| `message-bus.md` | > 10 distinct messages | 3 — `Ka0s_PanelMaster_PanelsChanged`, `…PanelChanged`, `…SettingsChanged` (`modules/Registry.lua:24`, `settings/Schema.lua:31`) | Not applicable | correct |
| `midnight-quirks.md` | ≥ 1 client-version workaround of its own | 0 — the one it had is now the library's, `settings/OptionsSetup.lua:152` `lib.__PatchLSM30Border()` | Not applicable | correct |
| `profiles.md` | AceDB profiles user-visible | Profiles page at `settings/Panel.lua:480` | Present | correct |
| `debug.md` | surfaces beyond the default console | `D:Diagnose`, `NS.DebugBuild` (`core/DebugLogSetup.lua`) | Present | correct |
| `perf-analysis/README.md` | the perf harness is wired | not wired, and ratified | Not applicable | correct |

**Documentation-map completeness, counted:**

```
$ ls docs/*.md | wc -l
18
$ ls docs/automated-tests/*.md | wc -l
2
```

**20 live `.md`.** The four tables hold **23** rows — Tier 1: 6, Conditional: 7, Verification and
record: 6, Addon-specific: 4 — and the gap between 23 and 20 is not an error: four of the seven
Conditional rows are ***Not applicable*** status rows, which `documentation-§3` **requires** for a
Tier 2 doc whose trigger has not fired and which by definition name no file.

Counted the way the rule actually asks — every existing `.md` in exactly one table — the rows that
point at a file are Tier 1's **6**, Conditional's **3** *Present*, Verification's **6** and Tier 3's
**4** = **19**, which is 20 minus `ARCHITECTURE.md` itself. **No dangling row**: all 19 were
`test -f`'d and every one exists. **No orphan**: the 19 plus the hub is the whole of `ls docs/*.md`
and `ls docs/automated-tests/*.md`. `ARCHITECTURE.md`'s own row is absent, and per the amended rule
its presence and its absence are both unfileable, so it is reported in neither direction.

**Retired-doc sweep, scope named:** `find docs -maxdepth 2` returns no `file-index.md`, no
`conventions.md`, no `complexity.md`, no `docs/perf-runs/`, no `docs/pending/`.

**Hub shape:** `wc -l docs/ARCHITECTURE.md` → **322**, under the ~400 SHOULD. Section lengths from
`grep -n '^## '`: Overview 10, Module Map 10, Settings Schema 22, Message bus 31, Slash Commands 12,
Event Subscriptions 12, Taint 7, Known Limitations 6, Documentation map 49, Documented deviations 97,
File sizes 57. The two over ~60 are the register and the size census — **neither is one of the four
the spill rule names** (Module Map, Settings Schema, Slash Commands, Message Bus), and the register
is by `documentation-§3`'s own words the single home rather than a summary. Reported as shape, with
the arithmetic, and not argued.

---

## 6. `PM-032` / `PM-032a` — the spelling gate against the canonical list

The published `BRITISH` and `ALLOWED` lists were copied **whole** out of `localization-§5` into a
throwaway scanner and run over the authored tree. The scanner removes `ALLOWED` as whole words first,
then matches `BRITISH` substrings case-insensitively — which is what §5 specifies and what the repo's
own gate does not do.

**Scope, stated file-set by file-set:**

```
$ git ls-files | grep -E '\.(lua|md|toc)$' \
    | grep -v '^libs/' | grep -v '^tests/_kit/' \
    | grep -v '^docs/audits/' | grep -v '^docs/reviews/' \
    | grep -v '^docs/automated-tests/2026' | grep -v '^docs/revendor/' \
    | grep -v '^modules/SunnArtPacks.lua' > files.txt
$ wc -l < files.txt
84
```

**Covered:** all authored `.lua` under `core/ defaults/ locales/ modules/ settings/ tests/`, the
`.toc`, `README.md`, `CLAUDE.md`, `DEPENDENCIES.md` and every live `.md` under `docs/`.
**Excluded, and why, one directory at a time:** `libs/` and `tests/_kit/` (vendored, not this repo's
to respell); `docs/audits/`, `docs/reviews/`, `docs/automated-tests/<run>/` and `docs/revendor/`
(frozen dated records); `modules/SunnArtPacks.lua` (another addon's theme names, reproduced verbatim
— the repo's own per-file exemption at `tests/test_spelling.lua:99-104`). `docs/superpowers/` was
**deliberately left in** so its result would be on the record.

```
$ lua spell.lua files.txt | grep -v '^tests/test_spelling.lua'
docs/performance.md:107: artefact | `performance-§12` asks for this as evidence. It is committed here because it is the artefact that
docs/superpowers/specs/2026-07-31-panel-artwork-design.md:5: catalogue | > converted by `tools/artwork/artwork_cleaner.py` and catalogued by
docs/superpowers/specs/2026-08-02-wiki-artwork-import-design.md:5: catalogue | > converted by `tools/artwork/artwork_cleaner.py` and catalogued by
TOTAL HITS: 90
```

The 90 total is 87 hits inside `tests/test_spelling.lua` itself — its own copy of its own word list,
which `localization-§5` explicitly exempts (*"the gate's own copy of the lists"*) — plus the three
above. Of those three:

- **`docs/performance.md:107` is `PM-032a`.** Quoted: *"`performance-§12` asks for this as evidence.
  It is committed here because it is the **artefact** that settles the question either way, and
  re-running it is how anyone checks whether the answer has changed."* Authored prose, not a quote,
  not a symbol, not a proper noun.
- The two `docs/superpowers/specs/` hits are **frozen dated records** and are not filed —
  `docs/ARCHITECTURE.md:121-123` names `docs/superpowers/` among the directories registered once and
  never enumerated, and §5 excludes *"frozen dated bundles … which are the record and are not
  rewritten."*

**Why the repo's own gate is green over this.** `tests/test_spelling.lua:50` already carries
`artefact`, quoted:

> `  "practise", "fulfilment", "offence", "pretence", "artefact", "judgement", "acknowledgement",`

but `docs/performance.md` is not in the scanned set. `tests/test_spelling.lua:143-147` is the whole
doc list, quoted:

> `  for _, doc in ipairs({ "README.md", "CLAUDE.md", "docs/ARCHITECTURE.md",`
> `                         "docs/smoke-tests.md", "docs/test-cases.md", "docs/testing.md",`
> `                         "docs/artwork-spec.md", ".luacheckrc",`
> `                         "tools/artwork/make_poster.py", "tools/artwork/artwork_cleaner.py",`
> `                         "tools/artwork/update_catalog.py", "tools/sunn/build_manifest.py" }) do`

**Seven markdown documents — two at the root and five of the twenty live `docs/` pages.** The
**fifteen** `docs/` pages outside it: `scope.md`, `module-map.md`, `schema.md`, `settings-panel.md`,
`data-flow.md`, `common-tasks.md`, `slash-dispatch.md`, `profiles.md`, `debug.md`, `rendering.md`,
`localization.md`, `media.md`, `performance.md`, `automated-tests/README.md` and
`automated-tests/RESULTS.md`. **Every Tier 1 page is among them.**

**The list is a private one, and says so.** `tests/test_spelling.lua:41`, quoted:
`local BRITISH = {`, and `:35`, quoted: *"Anything found later belongs here too; the list is meant to
grow, not to be complete."* There is no `ALLOWED` table anywhere in the file:

```
$ grep -c 'ALLOWED' tests/test_spelling.lua
0
```

Its substitute is the `-is`-suffix heuristic at `tests/test_spelling.lua:71-79`, quoted at `:71-74`:

> `local function hits(lower, word)`
> `  if word:sub(-2) == "is" then`
> `    return lower:find(word .. "e", 1, true)`
> `        or lower:find(word .. "a", 1, true)`

**Set difference against the published lists, computed rather than eyeballed.** The canonical
`BRITISH` has **91** entries; this gate has **98**; the intersection is **58**, so **33**
canonical entries are missing here and **40** entries here are not published there. Both directions are non-empty,
which is `localization-§5`'s two-sided MUST failing in both directions at once, and the entries are
listed in `02_DEVIATIONS.md` § `PM-032`.

---

## 7. The decision register — read first, and all three of `audit-review-history`'s MUSTs run

**MUST 1 — read it before filing.** Done; the seven live rows are in `02_DEVIATIONS.md` §
*Recorded deviations*, and no gap matching one of them was filed as an open MUST failure.

**MUST 2 — report a row whose cited rule the standard has since changed.** Every row's rule was
re-read in the v2.39.0 text:

- `performance-§1` — unchanged. `performance-§12` **was** re-read for the row's own trigger and is
  unchanged in the way that matters: `performance.md:338-342`, quoted — *"**(a) — no combat path.**
  The addon has **no `OnUpdate` handler**, no repeating ticker …"*. No bounded-cost clause was added,
  so the exemption is still unclaimable here and the row still correctly declines to claim it.
- `documentation-§1` item 5 — unchanged; still a MUST with the same roll-forward rule.
- `events-frames-taint-§8` — unchanged. Its trigger set is still *"unit absorb/health totals, threat,
  some aura amounts"* (`events-frames-taint.md:75`), so the row's sweep is still the right sweep.
- `localization-§1`/`§3` — the two terminal states survive; `§5` gained the canonical lists, which is
  a different subsection and does not touch this row.
- `options-ui-§16` ×3 — **amended this release**, and the rows survive it. The amendment adds the
  broadcast meta-row exemption and rules the shared-media grep a *finder rather than the finding*.
  Neither reaches these three: each block reproduces a mandated block **with its companions** —
  border style + thickness + colour + class-colour companion, bar texture + opacity + colour +
  companion — which is precisely the shape the finder-not-finding reading says **is** the deviation.
  No broadcast *All surfaces* row exists in this addon to claim the exemption with. Reported here
  because the check is owed even when it comes back clean.

**MUST 3 — evaluate every row's re-check trigger against the tree, and resolve every evidence id.**
Trigger results are in `02_DEVIATIONS.md`'s *Recorded deviations* table, one row each; the evidence
behind the two that needed a measurement:

```
$ grep -rn 'SetScript("OnUpdate"\|C_Timer\|ScheduleRepeatingTimer' --include='*.lua' core modules settings defaults locales
modules/Canvas.lua:660:  mouseoverDriver:SetScript("OnUpdate", mouseoverTick)
modules/Canvas.lua:678:      mouseoverDriver:SetScript("OnUpdate", nil)
```

One driver, installed and removed. `settings/OptionsSetup.lua:215` reaches `ScheduleTimer`, a
one-shot through AceTimer, not a repeating ticker. The `performance-§1` row's trigger has **not**
fired.

```
$ grep -n 'row.path' libs/LibKa0s/OptionsCompose.lua
105:  row.path     = row.path or ((spec.prefix or "") .. (keys[leaf] or leaf))
$ grep -n 'local MAJOR, MINOR' libs/LibKa0s/Options.lua
24:local MAJOR, MINOR = "LibKa0s-Options-1.0", 15
```

`emit` still writes a `path` unconditionally and there is no `get`/`set` arm; the major is still
`1.0`. The three `options-ui-§16` triggers have **not** fired.

**Evidence ids resolved.** The register cites `PM-029` (retired-row block), issues **#31**, **#44**,
**#47**, and `M5-09`. `PM-029` resolves to `docs/audits/2026-09-07/02_DEVIATIONS.md`; #31/#44/#47 all
exist in the issue store below; `M5-09` resolves to
`Ka0sAddonsCommonTasks/docs/2026-09-07-REVIEW_AND_STANDARDS_AUDIT_REMEDIATION/05_TRACEABILITY.md:464`.
The repo also gates this itself:

```
  PASS  every deviation id the register cites is assigned by a bundle in docs/audits/
```

**The issue store (`audit-review-history`), read with the sanctioned surface.**

```
$ gh issue list --state all --limit 200 --json number,title,state,labels
```

47 issues. **Every one carries both a `state:` label and a `severity:` label.** No `[status]` title
prefix survives anywhere — anti-pattern #62 clean. No `gh api graphql` was used and no title-prefix
filtering was done.

Closed `state:will-not-do`: **#27, #28, #29, #30, #31, #43, #45, #46** — eight.

**The inverse rule, run explicitly.** #31 (Perf) has its register row at `docs/ARCHITECTURE.md:221`.
The other seven need none: #27/#28/#29/#30 decline to *adopt a library surface* and #43/#45/#46
decline to *wire a major*, and `library-stack-§7` makes the **ship payload** whole-folder while the
**adoption** is only what you use — so there is no deviation to ratify. **No un-ratified decline was
found**, in the issue store, in root `CLAUDE.md`, in `docs/scope.md`, or in a `docs/pending/LEDGER.md`
(there is none).

**One issue-store observation, not a deviation.** #27's *will-not-do* body argues *"A host-side
re-export would have no caller"*, and `core/CoreSetup.lua:118-119` now publishes
`NS.MakeCloseButton` anyway. The wrapper's existence is what `standalone-windows` wants, so the code
is right and the closed issue's reasoning is simply older than the code. Recorded here so a future
reader does not mistake the mismatch for drift.

---

## 8. Against the 2026-09-07 remediation plan — what was supposed to close

Every PanelMaster row of
`Ka0sAddonsCommonTasks/docs/2026-09-07-REVIEW_AND_STANDARDS_AUDIT_REMEDIATION/05_TRACEABILITY.md:213-232`
checked against this tree.

| Finding | Item | Disposition | This audit's ID | Verified in the tree |
|---|---|---|---|---|
| `PANELMASTER-A-01` | `M4-15` | fix | PM-023 | **Closed.** `settings/PanelEditor.lua:1047` `drawPageHeader`, `:1051` `H.PageHeader`, the eight controls at `:1075/:1091/:1111/:1126/:1150/:1164/:1182/:1192`; `TAB_GENERAL` gone. |
| `PANELMASTER-A-03` | `M5-09` | ruling then rows | PM-024 | **Closed as ratified.** Three rows, `docs/ARCHITECTURE.md:225-227`; ruling at `:191-215`; issue #48 open as the upstream carrier. |
| `PANELMASTER-A-04` | `M2-19` | fix | PM-025 | **Closed.** `.pkgmeta:8-15`. |
| `PANELMASTER-A-06` | `M5-02` | fix | PM-029 | **Closed.** Row retired, `docs/ARCHITECTURE.md:231-238`. |
| `PANELMASTER-A-07` | `M1-LK-08` | **deferred** | PM-030 | **Open, as planned.** `05_TRACEABILITY.md:231` is the disposition; `:528` states `M1-LK-08` stops at the additive half. |
| `PANELMASTER-A-08` | `M5-01` | fix-forward | PM-028 | **Closed**, and the amended `automated-tests-§5` makes fix-forward the only permitted answer. `docs/automated-tests/20260908-181416/ANALYSIS.md:106-109`. |
| `PANELMASTER-R-08` | `M5-01` | record-regen | PM-027 | **Closed.** Bundle `20260908-181416`; `docs/automated-tests/RESULTS.md:65` re-anchored; band table `:82-85`. |
| `PANELMASTER-R-09` | `M4-10` | fix | PM-026 | **Closed.** Working-tree count 0 (§ 2). |
| `PANELMASTER-R-10` | `M1-LK-00` | fix | — | **Closed.** `diff -r` against `v1.27.0` is empty on both payloads (§ 4). |
| `PANELMASTER-R-01` | `M4-05` | fix | — | **Closed.** `core/LSMPatch.lua` deleted; `settings/OptionsSetup.lua:152` calls `lib.__PatchLSM30Border()`, reasoned at `:119-134`. Anti-pattern #76 clean. |
| `PANELMASTER-R-05` | `M4-14` | register-row | — | **Closed.** `docs/ARCHITECTURE.md:265-322`, the `## File sizes (layout-§1)` census, gated by `tests/test_layout_cap.lua` (3 PASS). |
| `PANELMASTER-R-07` | `M5-05` | fix | — | **Closed.** `settings/Slash.lua:45-51` — one act, `db:ResetProfile()`, one wording, reasoned at `:55-57`. |
| `PANELMASTER-R-02/03` | `M4-18` | fix | — | **Closed.** `== nil` defaulting throughout; no `or`-defaulting over a user-chosen falsy (anti-pattern #54 clean). |
| `PANELMASTER-R-04` | `M4-19` | fix | — | **Closed.** `core/Database.lua:149` reads the version through `NS.Version()`, reasoned at `:136-141`, the `core/EnvSetup.lua` seam. |
| `PANELMASTER-R-06` | `M4-22` | fix | — | **Closed.** `modules/Canvas.lua:667-679` — the comment now describes a driver whose script comes off when the tracked set empties, which is what the code does. |

**Nothing scheduled to close is open.** The one carry is dispositioned `deferred` at source.

---

## 9. `options-ui` content checks — nine, from the schema rather than the screen

**(a) Every page draws a tab strip.** Pages and their distinct `group` values, in declaration order:

| Page | Tabs | Source |
|---|---|---|
| landing | — (host `buildMain`, **mandated** in that shape, exempt) | `settings/Panel.lua:358` |
| General | `Master controls`, `Editing`, `New panels` | `settings/Schema.lua:199` (spliced) + `:51/:60/:74/:88` and `:109/:116/:121/:128` |
| Panels | `Position and size`, `Background and border`, `Accent bar`, `Artwork`, `Opacity and fade` | `settings/PanelEditor.lua:190-194`, list at `:199` |
| Profiles | — (AceConfig-drawn, exempt) | `settings/Panel.lua:480` |

The renderer was read as well as the pages: there is **no** fallback to the untabbed form below some
tab count, and the one early return that used to skip the strip is gone.
`settings/PanelEditor.lua:1376-1384`, quoted:

> `    -- THE STRIP IS DRAWN FIRST, AND ALWAYS (options-ui-§13).`
> `    -- It used to be RELEASED when there were no panels … That is the conditional no-strip state`
> `    -- the rule forbids`

with `drawTabStrip(ctx)` unconditional at `:1389`.

**(b) `Master controls` first, composed, canonical rows.** `settings/Schema.lua:199` calls
`H.MasterControls{...}` with `prefix = "settings."`, `page = "general"`, `debugConsolePath =
"state.debugConsole"`, `onResetPosition`, `onResetAll` and
`defaults = { enabled = true, visibility = "always", scale = 1, alpha = 1, locked = true }`
(`:220`). The addon draws positionable frames — proven, not assumed:

```
$ grep -rn 'SetMovable' --include='*.lua' core modules settings | grep -v '/libs/'
modules/Unlock.lua:186:  f:SetMovable(false)
modules/Unlock.lua:197:  f:SetMovable(true)
settings/Schema.lua:208:    -- SetMovable on each one. The frame-only rows therefore all apply.
```

so the frame-only rows all apply and none is legitimately omitted.

**The migration question, asked.** `settings.visibility` is a four-value dropdown. It did **not**
replace a stored boolean here:

```
$ git log --all --oneline -S'combatOnly'   → (no output)
$ git log --all --oneline -S'hideInCombat' → (no output)
$ git log --oneline -S'settings.visibility' | tail -1
081ee2c feat(settings): Create and Edit move above the tab strip
```

The path is new, so no stored type changed and no migration is owed. `NS.SCHEMA_VERSION = 2`
(`core/Namespace.lua:14`) with a live runner at `core/Database.lua:91-122`.

**(c) Class-colour companions.** `settings/PanelEditor.lua:393` `makeColorPair` builds the swatch and
its companion together, driven from `C.COLOR_FIELDS`, so the companion is always the next control.
The companion's label is the literal the rule names — `settings/PanelEditor.lua:452`, quoted:
`cb:SetLabel("Use class color")`. `classColorSource` is declared per field at
`core/Constants.lua:436-442`, all five `"player"`, and that matches what the render path means:
`core/Util.lua:232`, quoted — *"local unit = C.COLOR_CLASS_SOURCE[field] == "unit" and rec.unit or
nil"*, with the comment at `:230-231` saying every panel colour is player-scoped. The resolver is one
function, `Util.ResolveColor` (`core/Util.lua:225-235`), the stored alpha is used under both modes,
and an unresolvable class falls through to **the stored swatch**, not a literal grey — `:229`,
quoted: *"if not (flag and rec and rec[flag] and core and core.ResolveColor) then return stored end"*.

**(d) No `disabledIf` on a colour row.**

```
$ grep -rn 'disabledIf' --include='*.lua' settings/
settings/PanelEditor.lua:389:-- else: `disabledIf` on a color row is anti-pattern #74. A color's ALPHA is not overridden — it
```

The single hit is a comment forbidding it. Clean.

**(e) Ordering is a drag.**

```
$ grep -rn 'ScrollUp-Up\|ScrollDown-Up' --include='*.lua' settings/ | grep -v '/libs/'
(no output)
$ grep -rn 'MoveUp\|MoveDown' --include='*.lua' settings/ modules/ core/
(no output)
```

No stored array is reordered by this addon at all, so the reorder-list half is not reached.

**(f) Hand-written media groups — the grep as a finder, then the reading.**

```
$ grep -rn 'LSM30_Font\|LSM30_Border\|LSM30_Statusbar\|LSM30_Background' --include='*.lua' settings/
settings/Panel.lua:93:  background = "LSM30_Background",
settings/Panel.lua:94:  border     = "LSM30_Border",
settings/Panel.lua:95:  statusbar  = "LSM30_Statusbar",
settings/OptionsSetup.lua:119: (comment)
settings/OptionsSetup.lua:122: (comment)
```

`settings/Panel.lua:93-95` is a widget-name map, not a group. The actual hand-written blocks are in
`settings/PanelEditor.lua` and each **does** carry its block's companions — which is what makes them
findings rather than lone media rows — and all three are **ratified** register rows dated 2026-09-08.
There is no addon-wide broadcast *All surfaces* meta row here, so §16's named exemption is not
claimed and does not need bounding. Subsection headings use the shared widget:
`settings/PanelEditor.lua:298`, quoted: `local h = AceGUI:Create("Heading")` — no hand-rolled coloured
`Label` stands in for one (anti-pattern #71 clean).

**(g) One chrome block, not boxed twice.** `settings/PanelEditor.lua:1025-1032`, quoted:

> `-- ONE chrome block per page, and this is it. H.PageHeader and H.PageBanner release the same ledger`
> `-- and write the same reserved height, so the picker goes INSIDE this block and no banner is drawn`
> `-- separately`
> `-- NOT BOXED, either. The band is already separated from the page by its own divider and by the`
> `-- content panel's top edge`

The band's container is a plain `SimpleGroup` with `SetLayout("List")` (`:1057-1059`) — no
`InlineGroup`, no backdrop, no hand-drawn border. Anti-pattern #72 clean. **No page-wide control is
declared inside a `group`**: the eight are all built in `drawPageHeader`, and
`sections[TAB_*]` (`:596`, `:637`, `:686`, `:755`, `:937`) hold only per-tab appearance controls —
`:966`, quoted: *"Delete and Reset are not repeated here: they are page-wide acts and live in the
chrome band"*.

**(h) A wrapped strip's geometry does not move with the selection.** The library half is right —
`libs/LibKa0s/OptionsWidgets.lua:447` measures from `TAB_ATLAS[false][1]` and `:452` caches into the
`:421` upvalue. The suite half is **missing**, and it is reported as missing rather than passing:

```
$ grep -rn -i 'wrap\|band height\|measuredArtH\|TAB_ATLAS' tests/test_panel.lua
tests/test_panel.lua:623:  -- Its prose is hard-wrapped, so the line break in the middle of the sentence is flattened first.
```

The one hit is about prose wrapping. This is `PM-030`.

**(i) A secondary strip lives in the scroll, and there is no third level.** This addon draws no
secondary strip — `settings/OptionsSetup.lua:64-67`, quoted at `:64`: *"SubTabStrip has no caller here and is
present for the parity case"*, with the stub member itself at `:67`. The check is not reached and nothing is filed.

---

## 10. Reconciliation between `02_DEVIATIONS.md` and `05_EXECUTION_PLAN.md`

Read as one document, per the playbook. Every figure appearing in both was cross-checked after both
were written:

| Figure | `02` | `05` | Agree |
|---|---|---|---|
| Headline tally (roots) | 4 | 4 | yes |
| Total including dependents | 5 | 5 | yes |
| MUST failures, roots | 3 | 3 | yes |
| Compat shims counted | 8 | 8 | yes |
| Live `docs/` pages the gate reaches | 5 of 20 | 5 of 20 | yes |
| Live `docs/` pages outside it | 15 | 15 | yes |
| Line-ending stragglers | 0 | 0 | yes |
| Commits behind the record run | 4 | 4 | yes |
| Prior-run roots / total | 8 / 9 | 8 / 9 | yes |

---

## 11. Package ignore list — listed, not read

```
$ for e in .luacheckrc .pkgmeta .gitignore .gitattributes .claude .superpowers docs tests _dev; do
    grep -q "^  - $e\b" .pkgmeta || echo "NOT IGNORED — $e"; done
NOT IGNORED — .claude
NOT IGNORED — .superpowers

$ for e in .[!.]*; do [ -e "$e" ] || continue; grep -q "^  - $e\b" .pkgmeta || echo "UNACCOUNTED — $e"; done
UNACCOUNTED — .git

$ ls -d .[!.]*
.git  .gitattributes  .gitignore  .luacheckrc  .pkgmeta
```

**Check (b) — the one that cannot go stale — prints only `.git`**, which is the single exempt entry.
Check (a)'s two lines are the enumeration going stale in the other direction: neither directory
exists at this root, and `.pkgmeta:10-15` records that as a decision rather than an omission, quoted:

> `  # Those four are every root dot-entry this repo actually has, which is what`
> `  # packaging.md:28's strong form asks for. There is deliberately no .claude or`
> `  # .superpowers line: neither directory exists at this root, and the audit`
> `  # finding that named them was rejected this cycle for exactly that`

Nothing filed. **`PM-025` is closed.**

---

## 12. Shared media and the close-button wrapper

**No private copy** (anti-pattern #63): `media/` holds `artwork/`, `logos/`, `poster/`,
`screenshots/` and **no** `fonts/`, `icons/` or `textures/` — those arrive with
`libs/LibKa0s/media/`. `core/MediaSetup.lua:3-13` records the move.

**The seam is fed the folder name, not a look-alike.** `core/MediaSetup.lua:1`, quoted:
`local addonName, NS = ...` — the addon's own first vararg — and `:58`, quoted:
`  return Media.Icon(addonName, name)`. It loads at `PanelMaster.toc:46`, before
`core\Constants.lua` at `:47`, which is the load-bearing position the TOC annotates.

**No one-off marks.** `grep -rn 'SetAtlas' core modules settings` → no output. Texture paths under
`Interface\` are three: the addon's own artwork prefix (`core/Constants.lua:133`), its logo
(`:621`), and Blizzard's `WHITE8X8` (`:526`) — none is a catalog mark drawn locally.

**The console was told its name.** `core/DebugLogSetup.lua:171`, quoted: `    addonName = addonName,`.

**The close-button grep, run:**

```
$ grep -rn 'MakeCloseButton(' --include='*.lua' . | grep -v '/libs/' | grep -v '/tests/'
core/CoreSetup.lua:112:-- THREE ARGUMENTS, not two. `lib.MakeCloseButton(parent, onClick, addonName)` is the signature, and
core/CoreSetup.lua:118:NS.MakeCloseButton = function(parent, onClick)
core/CoreSetup.lua:119:  return lib.MakeCloseButton(parent, onClick, addonName)
```

**One wrapper definition and nothing else.** No direct `lib.MakeCloseButton(...)`, no
`Core.MakeCloseButton(...)`, no `NS.DebugLog.MakeCloseButton(...)` in a perf-panel hook — and there is
no perf panel here at all, so the decoration-hook check is not reached. This addon draws **one**
standalone window, the debug console, and the library draws it, so there is no host title bar, no
decline to ratify and no register row owed. Anti-pattern #65 clean.

---

## 13. Degradation stubs — every called member answered

`tests/test_surface_parity.lua` compares each stub's member **set** against the live surface using
kit 15's `Kit.assertSurfaceParity`, rather than a presence check over the members somebody
remembered. Four cases, all PASS. Deliberate omissions are named with reasons in the `ignore` sets
(`tests/test_surface_parity.lua:82-90` for Core, `:105-125` for DebugLog) — a decision, not a gap.

The **Options** stub is the documented exception and is correct as it stands:
`settings/OptionsSetup.lua:68-77`, quoted at `:68-69`:

> `    -- The schema composers (OptionsCompose). Each answers an EMPTY ROW LIST, and that is a real`
> `    -- degradation rather than an oversight: what they emit is the library's canonical row data`

which is exactly `options-ui-§1`'s **hollow composer**, the shape v2.39.0 ruled compliant and whose
register row this repo retired in the same cycle (`docs/ARCHITECTURE.md:239-249`). Flagging it would
be a false positive.
