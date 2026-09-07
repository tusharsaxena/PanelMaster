# 03 — Evidence (2026-09-07)

Every command below was **run** from the repo root on this machine on 2026-09-07 and its real
output pasted. Every `file:line` in this bundle was re-read before it was written, and the cited
text is quoted beside it. Nothing here is re-typed from an earlier bundle.

---

## 1. Standard provenance

```
$ curl -fsSL https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master/AUDIT.md -o AUDIT.md
$ curl -fsSL .../standards/STANDARDS.md -o STANDARDS.md
$ head -1 STANDARDS.md
# Ka0s WoW Addon Standard (v2.38.0, 2026-09-02)
```

All 26 section files linked from `## Sections` were then fetched individually from
`.../standards/standards/<file>.md`. Section files fetched: `anti-patterns`, `architecture`,
`audit-review-history`, `automated-tests`, `compat`, `debug-logging`, `documentation`,
`events-frames-taint`, `layout`, `library-stack`, `line-endings`, `lint`, `localization`,
`naming-cheatsheet`, `open-evolutions`, `options-ui`, `packaging`, `performance`, `preview-mode`,
`public-api`, `savedvariables`, `slash-commands`, `standalone-windows`, `testing`, `toc-file`,
`versioning-git`. No fetch failed.

**Repo state.**

```
$ git -C <repo> log -1 --format='%h %ad %s' --date=short
c5b4159 2026-09-03 Merge branch 'feat/settings-revamp-v2'
$ git -C <repo> status --porcelain | wc -l
0
```

---

## 2. Lint — `luacheck .`

**Scope:** everything except `.luacheckrc`'s `exclude_files = { "libs/", "docs/audits/",
"docs/reviews/", "_dev/", "tests/" }` (`.luacheckrc:4`). So `libs/` and the whole of `tests/` —
roughly 6,000 lines — are **not** linted; the 27 files are the addon's shipped source plus
`tools/`-adjacent Lua.

```
$ luacheck .
...
Checking settings/Slash.lua                       OK

Total: 0 warnings / 0 errors in 27 files
```

---

## 3. Headless suite — `lua tests/run.lua`

**Scope:** the 22 `tests/test_*.lua` suites over the load list the runner derives from
`PanelMaster.toc` and `libs/LibKa0s/LibKa0s.xml`.

```
$ lua tests/run.lua
...
  PASS  Spelling: authored English is US English
  PASS  libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles
  PASS  tests/_kit is the test kit that shipped with that release

763 passed, 0 failed, 0 skipped, 763 total
```

`763` agrees with `docs/test-cases.md` `## Totals` → `| **Total** | **763** |` and with the README
badge at `README.md:7` — `![Tests](https://img.shields.io/badge/Tests-763%2F763_passing-green)`.
Three figures, one number, reconciled.

---

## 4. Vendored Ka0s-owned library — the two `diff -r` checks

**The tag comes from the addon, not from the sibling's `HEAD`:**

```
$ grep -n 'Bundles \[LibKa0s\]' CLAUDE.md
44:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.25.0 (MIT). That line is the
$ grep -n 'Bundles \[LibKa0s\]' README.md
(no output)
$ grep -nE '^## (Libraries|Bundled libraries|Libraries and credits|Credits and libraries|Credits and bundled libraries)' README.md
(no output)
$ grep -n 'WoW_Addon_Standard' README.md
6:![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
```

The provenance line is in `CLAUDE.md` and only there (anti-patterns #58 and #59 both clear). The
standard badge is the **bare** `![Standard](…)` form, not link-wrapped. `README.md:382` `## Credits`
holds external credit only — warcraft.wiki.gg artwork under CC BY-SA 4.0 — and no library
roll-call.

**The diffs**, taken against the sibling checked out at the tag the line names:

```
$ git -C ../LibKa0s rev-parse -q --verify v1.25.0^{}
d3fc4a0753b50c3c806cb0726e1d7c8c52418d1c
$ git -C ../LibKa0s archive v1.25.0 LibKa0s testkit | tar -x -C /tmp/lk

$ diff -r /tmp/lk/LibKa0s <repo>/libs/LibKa0s && echo EMPTY
EMPTY
$ diff -r /tmp/lk/testkit <repo>/tests/_kit && echo EMPTY
EMPTY
```

Both empty, over the **whole** folder — all 13 payload files plus `media/`, not only the six majors
the addon wires. No anti-pattern #45 drift, no anti-pattern #48 partial vendoring. The harness is
under `tests/_kit/`, not `libs/`.

**TOC listing (library-stack-§7, toc-file-§5):**

- `PanelMaster.toc:30` — `libs\LibKa0s\LibKa0s.xml` — the single aggregate, listed once, after
  Ace3, with the reason at `:28-29`: *"# LibKa0s AFTER LibStub and after Ace3: Core resolves
  LibStub, and DebugLog/Slash/Options each resolve LibKa0s-Core-1.0 before calling NewLibrary."*
  No individual module `.lua` line anywhere in the TOC.

---

## 5. Line endings

```
$ test -f .gitattributes && echo present
present
$ grep -n '^\* text=auto eol=\(crlf\|lf\)$' .gitattributes
26:* text=auto eol=crlf
$ grep -n '^\*\.sh text eol=lf$' .gitattributes
34:*.sh text eol=lf
$ grep -c ' binary$' .gitattributes
21
```

The pin matches the repo's kind: the repo ships a `.toc`, so it is client-bound and pins CRLF.
The `*.sh` carve-out is present, and this is not the "only the carve-out" near-miss —
`line-endings-§1`'s failure shape — because the pin sits above it at `:26`.

**Body diff against the canonical client-bound body** (`line-endings-§5`), CR stripped so only
content differs:

```
$ diff <(tr -d '\r' < .gitattributes) canonical-crlf.txt
67,71d66
< # Extensionless binaries — marked by PATH, because no extension rule can
< # reach them. This block is a ratified deviation from line-endings-§5's
< # byte-for-byte rule; see docs/ARCHITECTURE.md ▸ ## Documented deviations.
< tools/artwork/bin/realesrgan-ncnn-vulkan binary
<
```

One extra block, exactly the one `docs/ARCHITECTURE.md:197` ratifies. Nothing else differs.

**Working tree vs the declared pin (`line-endings-§7`) — PM-026.** Run verbatim as the playbook
gives it. **Scope: every tracked file in the repo**, `git ls-files` — including `docs/`, `tests/`
and `libs/`, and including the frozen bundles under `docs/audits/`, `docs/reviews/` and
`docs/automated-tests/`. Files whose `text` attribute is `unset` (the `binary`-marked ones) are
skipped by the command itself, and a file with no `\n` at all is skipped.

```
$ git ls-files -z | xargs -0 -I{} sh -c '
    set -- $(git check-attr text eol -- "{}" | sed "s/.*: //")
    [ "$1" = unset ] && exit
    cr=$(tr -dc "\r" < "{}" | wc -c); lf=$(tr -dc "\n" < "{}" | wc -c)
    case "$2" in crlf) [ "$lf" -gt 0 ] && [ "$cr" -ne "$lf" ] && echo "{}";;
                 lf)   [ "$cr" -gt 0 ] && echo "{}";; esac' 2>/dev/null | wc -l
5
```

**5** tracked files disagree with the declared pin. Reported as one rolled-up finding; the paths
are deliberately not listed, because the fix is a single `git add --renormalize .` plus a
re-checkout and a per-file tally would inflate the count for one action.

---

## 6. Packaging — PM-025

```
$ for e in .luacheckrc .gitignore .gitattributes .claude .superpowers docs tests _dev; do
    grep -q "^  - $e\b" .pkgmeta || echo "NOT IGNORED — $e"; done
NOT IGNORED — .gitattributes
NOT IGNORED — .claude
NOT IGNORED — .superpowers

$ for e in .[!.]*; do [ -e "$e" ] || continue;
    grep -q "^  - $e\b" .pkgmeta || echo "UNACCOUNTED — $e"; done
UNACCOUNTED — .git
UNACCOUNTED — .gitattributes
UNACCOUNTED — .pkgmeta
```

`.git` is the one entry the packager never sees and needs no row. `.claude` and `.superpowers` do
not exist in this repo — check (b) does not print them — so their absence from the list ships
nothing today; the standard names them regardless. The live gaps are **`.gitattributes`** (a named
MUST entry that would ship into the packaged AddOn) and **`.pkgmeta`** itself (no row, no
justifying comment).

For the record, what **is** ignored — `.pkgmeta:5-12` and `:14-31`:

```
5:ignore:
6:  - .luacheckrc
7:  - .gitignore
8:  - docs        # holds docs/audits/ and docs/reviews/ too — all dev-only
9:  - tests
10:  - tools       # the artwork importer — build-time only, and not even Lua
11:  - _dev
12:  - "*.bak"
```

plus `media/screenshots`, `media/logos/*.png`, `media/logos/*.jpg`, `media/artwork/raw` and
`media/poster`, each with a justifying comment. No `externals:` block. No
`enable-toc-creation`.

---

## 7. Complexity — measured, not read

**Invocation taken verbatim from `AUDIT.md` step 6 / `performance-§10`.** `lizard` 1.23.0 is
installed at `/home/tushar/.local/bin/lizard`.

```
$ lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .
...
    711      10.5     2.4       72.6        72     ./settings/PanelEditor.lua
...
===============================================================================================================
No thresholds exceeded (cyclomatic_complexity > 15 or length > 1000 or nloc > 1000000 or parameter_count > 100)
==========================================================================================
Total nloc   Avg.NLOC  AvgCCN  Avg.token   Fun Cnt  Warning cnt   Fun Rt   nloc Rt
------------------------------------------------------------------------------------------
     12122       7.2     2.0       56.3     1472            0      0.00    0.00
```

**Compared against the latest committed run**, `docs/automated-tests/20260825-103450/`:

| | Latest bundle | Today | Drift |
|---|---|---|---|
| Total NLOC | 11223 | 12122 | +899 |
| Functions | 1379 | 1472 | +93 |
| Avg CCN | 1.9 | 2.0 | +0.1 |
| `lizard` warnings | 0 | 0 | — |

The bundle's own numbers are read back from
`docs/automated-tests/20260825-103450/complexity.txt` (`11223  7.1  1.9  55.9  1379  0`) and
`manifest.json` (`"nloc": 11223, "functions": 1379, "warnings": 0, "maxCcn": 15`).

**How stale the run is.**

```
$ git rev-list --count 721c5593b2cc1cd08a8c790b039971c97b9a94b3..HEAD
19
$ git log -1 --format='%h %ad %s' --date=short 721c559
721c559 2026-08-25 refactor(env): read the TOC through LibKa0s-Env-1.0
```

`manifest.json` records `"git": { "sha": "721c5593…", "dirty": false }` and `"release": null`.
Nineteen commits — the entire `feat/settings-revamp-v2` branch — landed after it.

**Files that entered or moved within `layout-§1`'s 1000–1500 band since that run** (LOC at the run's
sha versus LOC today):

```
$ for f in settings/PanelEditor.lua tests/test_panel.lua tests/test_libka0s.lua \
           modules/Artwork.lua tests/test_artwork.lua; do
    echo "$f  at-run=$(git show 721c559:$f | wc -l)  now=$(wc -l < $f)"; done
settings/PanelEditor.lua  at-run=1091  now=1350
tests/test_panel.lua      at-run=700   now=1076
tests/test_libka0s.lua    at-run=925   now=1064
modules/Artwork.lua       at-run=1188  now=1188
tests/test_artwork.lua    at-run=1356  now=1356
```

Two files **entered** the band (`tests/test_panel.lua`, `tests/test_libka0s.lua`) and are in no
table. `settings/PanelEditor.lua` grew +259 within it. This is the evidence for **PM-027**.

**No function crossed a `lizard` threshold.** The highest CCN in the addon is still **15**, in the
two functions the watch list already names — `Compat.AddOnFolders`, **today at
`core/Compat.lua:27`**, and `R.ApplyArtSize`, **today at `modules/Registry.lua:658`**. Both line
numbers in `docs/automated-tests/RESULTS.md` are stale — the file says `core/Compat.lua:34-52` and
`modules/Registry.lua:604-632` at `:123-124`, and `modules/Registry.lua:639` / `core/Compat.lua:34`
at `:174-175`; none of the four resolves to the named function today, which is further evidence for **PM-027**. Both are dense
**defaulting and guarding**, not tangled control flow: `lizard` counts each `and`/`or`
short-circuit as a decision, so a run of `t.k = rec.k or D.k` scores high with no branching. Both
sit exactly on the release gate's line.

**The artifact itself (`automated-tests`).**

```
$ ls -l tests/_kit/run-automated-tests.sh
-rwxrwxrwx ... tests/_kit/run-automated-tests.sh
$ git ls-files -s tests/_kit/run-automated-tests.sh
100755 c35d4239… 0	tests/_kit/run-automated-tests.sh
$ ls docs/automated-tests/README.md docs/automated-tests/RESULTS.md
docs/automated-tests/README.md  docs/automated-tests/RESULTS.md
$ ls docs/complexity.md docs/perf-runs 2>&1
ls: cannot access 'docs/complexity.md': No such file or directory
ls: cannot access 'docs/perf-runs': No such file or directory
```

Runner vendored and executable (PM-018 confirmed closed); both record docs present; the retired
`docs/complexity.md` and the retired `docs/perf-runs/` are absent.

**`ANALYSIS.md` per bundle — PM-028.**

```
$ for d in docs/automated-tests/2026*/; do
    printf '%s %s %s\n' "$d" "$([ -f $d/ANALYSIS.md ] && echo yes || echo NO)" \
      "$(grep -o '"release": [^,}]*' $d/manifest.json | head -1)"; done
docs/automated-tests/20260804-182223/ yes "release": null
docs/automated-tests/20260804-215132/ yes "release": null
docs/automated-tests/20260804-233329/ yes "release": null
docs/automated-tests/20260807-023000/ yes "release": null
docs/automated-tests/20260807-110543/ NO  "release": null
docs/automated-tests/20260807-114409/ yes "release": null
docs/automated-tests/20260807-160022/ yes "release": "1.0.0"
docs/automated-tests/20260825-103450/ NO  "release": null
```

The one **release** run has its write-up, so `automated-tests-§5`'s MUST is met; two non-release
runs miss the SHOULD.

---

## 8. The watch list as a decision record

`docs/automated-tests/RESULTS.md` — the `Accepted` entries and their run counts:

- `### Functions `lizard` warned on` (`:106`, with **"None."** at `:111`) — not a backlog; a real result. A second copy of the heading sits at `:170`, which is a duplicated section in the record rather than a second list.
- `### Files by `layout-§1` band` (`:151`, rows `:155-157`) — **three** entries, all *Accepted*:
  `tests/test_artwork.lua` (1356), `modules/Artwork.lua` (1188), `settings/PanelEditor.lua` (1091).

**Anti-pattern #53's clock has not tripped.** `automated-tests-§4` retires an *Accepted* carried
across three consecutive **release** runs.

```
$ grep -l '"release": "' docs/automated-tests/*/manifest.json
docs/automated-tests/20260807-160022/manifest.json
```

Exactly **one** release run exists (`1.0.0`), so no entry has been carried across three. The
`RESULTS.md` prose says the same at `:163-168` — *"None has yet been carried as Accepted across
three consecutive RELEASE runs, because 1.0.0 is the first release this addon has had."* Nothing is
owed a tracked deviation ID on shelf-life grounds today. The list is three entries long and
readable in one pass.

What **is** wrong with it is staleness, not shelf life:

- `docs/automated-tests/RESULTS.md:102` — *"Current state as of [`20260807-114409`](20260807-114409/)
  — not that run's diff."* Two newer runs exist.
- `docs/automated-tests/RESULTS.md:157` — *"…First movement across four runs; if the next change
  also grows it, execute the split rather than re-accept."* The next change grew it by 259 lines
  (§7 above), and neither the split nor a re-accept has been recorded.

`git log` on the single path, showing the trend line is maintained by prepend:

```
$ git log --oneline -4 -- docs/automated-tests/RESULTS.md
5d6b7eb automated-tests: record run 20260825-103450 — green on a 3.7s suite
f83a5a9 release: 1.0.0 — the addon's first published version
090dc5d automated-tests: record run 20260807-114409 — green
43e6e22 vendor: re-vendor LibKa0s v1.8.2 — test kit revision 10
```

**Complexity refactors since the last audit (`performance-§11`).** The `feat/settings-revamp-v2`
diff contains no watch-list-driven refactor: no function was extracted to hit a number, no dispatch
or defaults table was moved inside a function (anti-pattern #43), and no `t.k = stored.k or D.k`
was introduced over a field whose stored `false` is a user choice — `defaults/Profile.lua:35-37`
shows the opposite instinct, recording explicitly that no boolean needed migrating.

---

## 9. The recorded-deviation register — read before anything was filed

`docs/ARCHITECTURE.md:168` — `## Documented deviations`, with the register's own statement of
purpose at `:170-173`: *"The **single home** for a ratified deviation from the Ka0s WoW Addon
Standard (`documentation-§3`). … a deviation that is not in this table is **not ratified**."*
Seven rows, each carrying `| Rule | What differs | Why | Decided | Re-check trigger |`:

| Line | Rule | Decided | Trigger fired? |
|---|---|---|---|
| `:193` | `performance-§1` (the wiring MUST) | 2026-08-25 | No — the triggers name a second `OnUpdate`, unbounded work, or an upstream `§12` change |
| `:194` | `documentation-§1` (item 5) | 2026-08-07 | No — trigger is the first release **after** 1.0.0; version is still `1.0.0` |
| `:195` | `events-frames-taint-§8` (the pre-formatting SHOULD) | 2026-08-05 | No — trigger is the first site handed a combat-protected return |
| `:196` | `localization-§1` | 2026-08-05 | No — trigger is the first non-English locale file |
| `:197` | `line-endings-§5` | 2026-08-07 | No — trigger is upstream provision for extensionless binaries |
| `:198` | `options-ui-§1` (the degradation rule) | 2026-09-02 | No — trigger is a library-side composer that runs without the library |
| `:199` | `documentation-§4` | 2026-08-05 | **YES** — see below |

**The one fired trigger — PM-029.** `docs/ARCHITECTURE.md:199` reads, verbatim in its Why and
Trigger cells: *"The addon is pre-release, so the rule is not yet engaged."* … *"The first published
release, which is when `documentation-§4` engages"*.

```
$ grep -n '^## Version' PanelMaster.toc
5:## Version: 1.0.0
$ ls TODO.md docs/TODO.md 2>&1
ls: cannot access 'TODO.md': No such file or directory
ls: cannot access 'docs/TODO.md': No such file or directory
```

`1.0.0` released 2026-08-07 (`README.md` Version History row `| 1.0.0 | 2026-08-07 | …`), so the
rule is engaged — and the addon **satisfies it**: no `TODO.md` anywhere. The row now records
compliance as if it were a deviation and should be retired.

**No register row cites a rule the standard has since changed.** Each of the seven `filename-§N`
references resolves in v2.38.0 to a section that still says what the row says it says.

**The inverse check — a decline recorded only in the issue store.**

```
$ gh issue list --state all --limit 200 --json number,title,state,labels \
    -q '.[] | [(.number|tostring), .state, ([.labels[].name]|join(",")), .title] | @tsv'
46 CLOSED state:will-not-do,severity:low  LibKa0s-Pool-1.0: declined — the pool is keyed by frame name…
45 CLOSED state:will-not-do,severity:low  LibKa0s-Item-1.0: declined — a backdrop-panel addon has no item domain
44 CLOSED state:done,severity:medium      The Perf decline is recorded as will-not-do, but this repo's own performance.md argues against it
43 CLOSED state:will-not-do,severity:low  LibKa0s-Widgets-1.0: declined — no control in this addon wants it
…
31 CLOSED state:will-not-do,severity:low  Adopt LibKa0s-Perf-1.0 and wire a performance capture
30 CLOSED state:will-not-do,severity:low  Adopt LibKa0s Options' RestoreAllDefaults, InlineButtonPair, LSMValues and color codecs
29 CLOSED state:will-not-do,severity:low  Port the /pm list LIST_GROUP_ORDER constant onto LibKa0s-Slash-1.0
28 CLOSED state:will-not-do,severity:low  Adopt LibKa0s-DebugLog-1.0's ConsoleCheckbox() for the debug console row
27 CLOSED state:will-not-do,severity:low  Re-export LibKa0s-Core-1.0's window chrome (SKIN, ApplySkin, MakeCloseButton)
…
```

45 issues, every one carrying both a `state:` and a `severity:` label; **no** `[status]` title
prefix survives (anti-pattern #62 clear); no `docs/pending/` directory exists.

Nine issues are `state:will-not-do`. **Only #31 needed a register row, and it has one** (`:193`,
alongside #44). The other eight decline **adopting a LibKa0s surface**, which
`library-stack-§7` explicitly does not make a deviation: *"What you **copy** is all of it; what you
**wire** is only what you use."* #27 in particular is not a `MakeCloseButton` decline — the wrapper
exists (§10 below). So there is **no** un-ratified `state:will-not-do` decline to file.

---

## 10. Shared-subsystem wiring — the descriptors, not the behavior

Each claim below cites the addon's **own** setup file, never the library's source.

**Core** — `core/CoreSetup.lua:119`, the one close-button wrapper:

```lua
  return lib.MakeCloseButton(parent, onClick, addonName)
```

with `:112` reading *"-- THREE ARGUMENTS, not two. `lib.MakeCloseButton(parent, onClick,
addonName)` is the signature, and"*.

```
$ grep -rn 'MakeCloseButton(' --include='*.lua' . | grep -v '/libs/' | grep -v '/tests/'
core/CoreSetup.lua:112:-- THREE ARGUMENTS, not two. `lib.MakeCloseButton(parent, onClick, addonName)` is the signature, and
core/CoreSetup.lua:119:  return lib.MakeCloseButton(parent, onClick, addonName)
```

Two lines, both the wrapper. **No** direct `lib.MakeCloseButton(...)`, `Core.MakeCloseButton(...)`
or `NS.DebugLog.MakeCloseButton(...)` call site anywhere in addon code. Anti-pattern #65 clear.

**Media** — `core/MediaSetup.lua:1` `local addonName, NS = ...`, and `:58`
`return Media.Icon(addonName, name)`. The folder name is the addon's own first vararg, not a
frame-name prefix or a hand-typed constant. Its TOC position is load-bearing and says why
(`PanelMaster.toc:43-47`); `core/Constants.lua:616` is the resolution it protects:
`C.FONT_MONO = NS.MediaFont and NS.MediaFont(C.FONT_MONO_NAME) or _G.STANDARD_TEXT_FONT`.

**Private media copy (anti-pattern #63)** — `find media -type d` returns `artwork/`, `logos/`,
`poster/`, `screenshots/` only. No `fonts/`, no `icons/`, no `textures/`. The monospace face and
the icon catalog come from `libs/LibKa0s/media/`.

**One-off marks where the catalog has one** —

```
$ grep -rn 'SetAtlas' --include='*.lua' core/ modules/ settings/ locales/ defaults/
(no output)
$ grep -rn 'Interface\\\\' --include='*.lua' core/ modules/ settings/ locales/ defaults/
core/Constants.lua:133:C.ARTWORK_PATH_PREFIX = "Interface\\AddOns\\PanelMaster\\media\\artwork\\"
core/Constants.lua:526:C.SOLID_TEXTURE = "Interface\\Buttons\\WHITE8X8"
core/Constants.lua:621:C.LOGO_PATH = "Interface\\AddOns\\PanelMaster\\media\\logos\\panelmaster.logo.tga"
modules/SunnArt.lua:21, :388  — the Sunn pack path the adapter reconstructs
settings/PanelEditor.lua:892-893 — example paths inside a tooltip string
```

Every one is the addon's own artwork, the client's solid-fill texture, or documentation prose —
none is a chrome mark the shared catalog already ships.

**DebugLog** — `core/DebugLogSetup.lua` resolves the major and hands it a descriptor; the degraded
arm prints `:146`:

```lua
    NS.Print(on and "debug logging is on" or "debug logging is off")
```

plain and uncolored, with `:141` recording why the library's own hexes are not reproduced
(*"…and both of its state hexes — ON green, OFF red — which is exactly the"*). PM-022 closed.

**Options** — `settings/OptionsSetup.lua:26` `local lib = LibStub and LibStub("LibKa0s-Options-1.0",
true)`; descriptor `:118-201`; stub `:28-116`. The stub is **load-completing rather than
member-answering**, which is the one documented exception and not a finding — `:29-34` says so:
*"Degrade, never error… everything else must merely LOAD, because settings/Panel.lua and
settings/PanelEditor.lua both run at file scope against this table."*

**Slash** — `settings/Slash.lua:273` `NS.COMMANDS = {`, 18 verbs. `Sl.FormatKV` is published on
**both** arms — `:357` `Sl.FormatKV       = function(path, valueStr)` — with `:350-356` recording
that the degraded arm must answer it. PM-007 closed.

**Stub coverage.** Rather than reasoning about it, the suite asserts it, and the assertions ran
green this session:

```
  PASS  Parity: the Core seam's degraded surface matches the live one
  PASS  Parity: the DebugLog seam's degraded surface matches the live one
  PASS  Parity: the Slash seam's degraded surface matches the live one
  PASS  Parity: the Options seam's degraded surface matches the live one
  PASS  Degraded install: /pm config answers on EVERY invocation, not once
  PASS  Degraded install: the schema loses the composed Master controls rows and NOTHING else
```

---

## 11. Settings-panel content — the nine `options-ui` checks

**(a) Every page draws a tab strip.**

| Page | Builder | Groups / tabs, declaration order | Verdict |
|---|---|---|---|
| Landing | `settings/Panel.lua:259` `local function buildMainContent(ctx)`, installed at `:358` | none — logo, tagline, one Label per `COMMANDS` row | **Exempt and mandated** (options-ui-§5) |
| General | `settings/Panel.lua:361` `O.RegisterOptionsPage("general", …)`; `:422` `O.RenderTabbedSchema(c, "general", afterGroup)` | `Master controls`, `Editing`, `New panels` | Pass |
| Panels | `settings/Panel.lua:430`; strip at `settings/PanelEditor.lua:1079` `NS.Helpers.TabStrip(ctx, {` over `:164-174` | `General`, `Position and size`, `Background and border`, `Accent bar`, `Artwork`, `Opacity and fade` | Pass |
| Profiles | `settings/Panel.lua:480` | AceConfig-rendered | **Exempt** |

No fallback to an untabbed renderer, and no early return that skips the strip for an empty list:
`settings/PanelEditor.lua:1256` calls `drawTabStrip(ctx)` unconditionally, and the file's own note
at `:1248-1252` records that the `if #records > 0` branch was deleted for exactly this reason.

**(b) The General page's first tab is `Master controls`.** It is not written out — it is composed.
`settings/OptionsSetup.lua:214` `NS.Schema:InstallMaster(NS.Helpers)`, whose body
(`settings/Schema.lua`, `function S:InstallMaster(H)`) calls `H.MasterControls{ prefix =
"settings.", page = "general", addonName = "Ka0s Panel Master", … }` and splices the result at the
head of the array. The canonical rows are all present — enable, general visibility, master scale,
master alpha, lock frame, debug console, reset position, reset all settings — and the addon is
**not** frameless: `modules/Unlock.lua:186` and `:197` call `f:SetMovable(false)` / `(true)`, which
is the `SetMovable` sweep the rule asks for, so none of the frame rows may be omitted, and none is.

**The migration this check then asks for does not apply, and the addon says so.**
`defaults/Profile.lua:35-37`:

```lua
    -- there is no boolean to migrate, because this addon never shipped a "show only in combat"
    visibility  = "always",
```

The runner exists regardless — `core/Database.lua:90` `function NS:RunMigrations()`, `:94`
`g.schemaVersion = g.schemaVersion or 1`, real v1→v2 body at `:110-118`, `NS.SCHEMA_VERSION = 2` at
`core/Namespace.lua:14`.

**(c) Class-color companion beside every color row.** All five colors go through one function —
`settings/PanelEditor.lua:361` `local function makeColorPair(ctx, row, rec, field, label)` — called
at `:735` (`bgColor`), `:750` (`borderColor`), `:794` (`accentColor`), `:827`
(`accentBorderColor`), `:1001` (`artColor`). The companion is emitted as the **next** half-width
widget, so it lands in the right-hand column. The class source is declared, not inferred:
`:352-354` — *"WHICH CLASS is declared in C.COLOR_CLASS_SOURCE, not decided here: all five of this
addon's colors are panel chrome and take the PLAYER's class."* Resolution is the library's, through
`NS.Util.ResolveColor`, and the stored alpha survives the mode (`:368` labels the swatch
`label .. " |cff808080(opacity)|r"` while class color is on).

**(d) No `disabledIf` on a color row.**

```
$ grep -rn 'disabledIf' --include='*.lua' settings/
settings/PanelEditor.lua:357:-- else: `disabledIf` on a color row is anti-pattern #74. A color's ALPHA is not overridden — it
```

One hit, and it is the comment recording the rule. Zero actual uses.

**(e) Ordering is a drag.**

```
$ grep -rn 'ScrollUp-Up\|ScrollDown-Up' --include='*.lua' settings/
(no output)
$ grep -rn 'MoveUp\|MoveDown\|ReorderList' --include='*.lua' settings/ modules/
(no output)
```

No paired arrows, no swap handler, no numeric position field. Anti-pattern #75 clear. The addon
also has no stored ordered array to reorder.

**(f) Font, border and bar groups — PM-024.**

```
$ grep -rn 'LSM30_' --include='*.lua' settings/
settings/Panel.lua:93:  background = "LSM30_Background",
settings/Panel.lua:94:  border     = "LSM30_Border",
settings/Panel.lua:95:  statusbar  = "LSM30_Statusbar",
settings/OptionsSetup.lua:188:  --                PanelEditor builds itself with the LSM30_* widgets; no schema row is media-backed,
```

None of these is a composer call site, and none can be: the composers emit **schema rows**
(`libs/LibKa0s/OptionsCompose.lua:262` `function O.BorderGroup(spec)` and `:297`
`function O.BarGroup(spec)`, both building `{ type=…, label=…, default=… }` rows keyed by path),
while this page draws **registry records** — `settings/PanelEditor.lua:148-149`: *"a panel is a
registry record, not a set of schema rows with paths -- so H.RenderTabbedSchema has nothing here to
partition"*.

The three hand-written blocks, and the mandated row order each of them keeps:

| Block | Lines | Rows, in order |
|---|---|---|
| Panel border | `:738-757` | `Border style` (`:743`) · `Border thickness (px)` (`:745`) · `Border color` + companion (`:750`) · then `Border offset` (`:754`), appended after |
| Accent bar | `:770-800` | `Bar texture` (`:785`) · `Bar opacity` (`:788`) · `Bar color` + companion (`:794`) · then `Bar thickness` / `Bar offset`, appended after |
| Accent-bar border | `:814-830` | `Border style` (`:819`) · `Border thickness (px)` (`:821`) · `Border color` + companion (`:827`) · then `Border offset` |

Every mandated row is present, in order, with the canonical labels and the extras appended rather
than interleaved — which is why PM-024 is Low. **No font group exists** in this addon (it draws no
text on a panel), so the font block is inapplicable rather than missing.

Subsection headings are the shared `Heading` widget via `editorHeading`, never a colored `Label`
(anti-pattern #71): `:721` `editorHeading(group, "Background")`, `:738` `…"Border"`, `:770` `…"Bar"`,
`:808` `…"Edges"`, `:814` `…"Border"`, with `:762` recording that the last hand-rolled gold Label
in the collection was replaced here — *"one replaces the collection's last hand-rolled heading, a
gold |cffffd100Edges|r Label standing"*.

**(g) One chrome block, unboxed — the finding is what is *missing* from it.**
`settings/PanelEditor.lua:1098-1105` states the rule the code follows: *"ONE chrome block per page,
and this is it. H.PageHeader and H.PageBanner release the same ledger… NOT BOXED, either."*
`drawPageHeader` runs `:1112-1199`; `H.PageHeader(ctx, {…})` at `:1116`; the create box at `:1141`
`nameBox:SetLabel("Create new panel")`; the picker at `:1154` `picker:SetLabel("Panel")`.

```
$ grep -rn 'InlineGroup' --include='*.lua' settings/
settings/PanelEditor.lua:201: … titleless InlineGroup that contributed an inset of its own …
settings/PanelEditor.lua:463:  -- A plain List container, NOT an InlineGroup, and the box is the point rather than the widget.
settings/PanelEditor.lua:466: … (options-ui-§14, anti-pattern #72). The InlineGroup was also titleless, so it was never
```

Three hits, all comments recording the removal. No live `InlineGroup`, no backdropped
`SimpleGroup`, no hand-drawn border around the band. Anti-pattern #72 clear.

What the band does **not** hold is the §14 finding, **PM-023**. In `sections[TAB_GENERAL]`
(`settings/PanelEditor.lua:565`):

| Control | Line | §14 classification |
|---|---|---|
| `nameBox:SetLabel("Panel name")` (rename) | `:572` | identity of the edited instance |
| `copyFrom:SetLabel("Copy settings from panel")` | `:607` | **copy** — named page-wide |
| `enabled:SetLabel("Enabled")` | `:633` | **enable** — named page-wide |
| `unlocked:SetLabel("Unlock")` | `:648` | **unlock** — named page-wide |
| `makePairButton("Reset", …)` | `:667` | **reset** — named page-wide |
| `makePairButton("Delete", …)` | `:673` | **delete** — named page-wide |

The file's own comment at `:566-567` describes the intent — *"Identity first, then the switches,
then the two whole-panel actions"* — which is precisely the §14 category. All six vanish when the
player clicks any of the other five tabs.

**(h) A wrapped strip's geometry does not move with the selection — PM-030.**

*First read, the library.* `libs/LibKa0s/OptionsWidgets.lua:428` `local function tabArtHeight()`,
`:429` `if measuredArtH then return measuredArtH end`, `:434`
`tex:SetAtlas(TAB_ATLAS[false][1], true)`. Measured from the **unselected** art and cached once —
correct, and it is what `:423-427` documents. Consumed as the wrapped-row pitch at `:1001` and
`:1236` (`local pitch = tabArtHeight()`), distinct from `L.TAB_H`.

*Second read, the suite.*

```
$ grep -rn 'TabStrip' tests/*.lua
tests/test_panel.lua:973: -- IDENTITY, not just the count. TabStrip drains its ledger into a FRESH table every time it
tests/test_panel.lua:976: … and what the `if #records > 0 then drawTabStrip(ctx) end` mutation this case exists to
```

Two comment lines about a different property. **No case asserts the reserved band and every row's
y offset are identical for every value of the selection.** And a naive one would be green against
nothing: `tests/_kit/mock_base.lua:97` `function f:GetHeight() return 0 end` answers one height for
every frame and every atlas. Reported as a **missing** case per `testing-§12`.

**(i) A secondary strip lives in the scroll, and there is no third level.** There is no secondary
strip at all: `settings/OptionsSetup.lua:64-67` records that `SubTabStrip` *"has no caller here and
is present for the parity case"*. No `subgroup` heading is used to fake a level — the headings in
`sections[TAB_*]` are within-tab section headings, which `options-ui-§7` provides for. Nothing to
find.

---

## 12. `docs/` shape (`documentation-§3`) — measured as a listing

**(a) Tier 1 — all six present, under exactly the canonical names.**

```
$ ls docs/scope.md docs/module-map.md docs/schema.md docs/settings-panel.md \
      docs/data-flow.md docs/common-tasks.md
docs/common-tasks.md  docs/data-flow.md  docs/module-map.md
docs/schema.md  docs/scope.md  docs/settings-panel.md
```

**(b) Tier 2 — all seven answered, and every "Not applicable" trigger re-checked against the code.**
The rows are `docs/ARCHITECTURE.md:140-146`, under the `### Conditional (documentation-§3, Tier 2)` heading at `:136`.

| Doc | Row says | Code says |
|---|---|---|
| `slash-dispatch.md` | Present — *"18 verbs in `NS.COMMANDS` (threshold is 8)"* | `settings/Slash.lua:273`, 18 entries counted |
| `profiles.md` | Present | `settings/Panel.lua:480` Profiles page |
| `debug.md` | Present | `D:Diagnose()`, `NS.DebugBuild` |
| `message-bus.md` | *Not applicable* — *"Three messages; threshold is more than ten"* | Exactly three: `MSG_PANELS`, `MSG_PANEL` (`modules/Registry.lua:24`), `MSG_SETTINGS` (`settings/Schema.lua:35`) — **true** |
| `midnight-quirks.md` | *Not applicable* — *"`core/LSMPatch.lua` fixes a vendored **widget**, not a client behavior"* | `core/LSMPatch.lua:1-24` is an AceGUI-SharedMediaWidgets layout fixup — **true** |
| `compat-layer.md` | *Not applicable* — *"no addon-specific shim beyond what the row in `module-map.md` records"* | `core/Compat.lua:5-7` — *"Every varying / deprecated API is gated by a direct C_*/global presence check here"* — **true** |
| `perf-analysis/README.md` | *Not applicable* — Perf declined, cites the register | No `PerfSetup`, no `PanelMasterPerfDB`, no captures — **true** |

No "Not applicable" row asserts something false.

**(c) `## Documentation map`.** `docs/ARCHITECTURE.md:119`, with the coverage rule stated at `:121`:
*"Every `.md` under `docs/` appears in exactly one table below (`documentation-§3`)."* Cross-check,
excluding the frozen/generated directories the map names once each:

```
$ find docs -name '*.md' -not -path 'docs/audits/*' -not -path 'docs/reviews/*' \
        -not -path 'docs/automated-tests/2026*' -not -path 'docs/revendor/*' \
        -not -path 'docs/superpowers/*' | sort
docs/ARCHITECTURE.md          docs/artwork-spec.md
docs/automated-tests/README.md  docs/automated-tests/RESULTS.md
docs/common-tasks.md          docs/data-flow.md      docs/debug.md
docs/localization.md          docs/media.md          docs/module-map.md
docs/performance.md           docs/profiles.md       docs/rendering.md
docs/schema.md                docs/scope.md          docs/settings-panel.md
docs/slash-dispatch.md        docs/smoke-tests.md    docs/test-cases.md
docs/testing.md
```

Nineteen files besides the hub itself, and the map carries a row for **all nineteen** plus the four
Tier-2 *Not applicable* rows. **No orphan, no dangling row.**

**(d) Non-canonical filenames holding Tier 1/2 content.** None. `rendering.md`, `media.md`,
`localization.md`, `artwork-spec.md` are Tier 3 addon-specific; `performance.md`, `test-cases.md`,
`testing.md`, `smoke-tests.md` are the verification-and-record set. No `data-model.md`,
`saved-variables.md`, `pipeline.md`, `settings-system.md`, `wow-quirks.md`, `slash-commands.md` or
`debug-console.md`.

**(e) Retired docs.** None — no `file-index.md`, no `conventions.md`, no `complexity.md`, no
`docs/perf-runs/` (verified in §7 above), no `docs/agent-context.md`, no `docs/pending/`.

**(f) Hub shape.**

```
$ wc -l docs/ARCHITECTURE.md
199 docs/ARCHITECTURE.md
$ awk '/^## /{if(h)print h": "n; h=$0; n=0; next}{n++}END{if(h)print h": "n}' docs/ARCHITECTURE.md
## Overview: 9          ## Module Map: 9        ## Settings Schema: 21
## Message bus: 30      ## Slash Commands: 11   ## Event Subscriptions: 11
## Taint: 6             ## Known Limitations: 5 ## Documentation map: 48
## Documented deviations: 31
```

199 lines against the ~400 cap; longest mandated section 48 lines against the ~60 cap. Nothing has
failed to spill.

---

## 13. Root doc set (`documentation-§1/§2/§7`)

**README structure**, headings in file order:

```
$ grep -n '^#\{1,2\} ' README.md
1:# Ka0s Panel Master
24:## Screenshots
42:## Usage
198:## How panels work
230:## Panel artwork
340:## FAQ
353:## Troubleshooting
369:## Issues and feature requests
376:## Version History
382:## Credits
```

Order preserved. Badge row `:3-7`, five badges in the mandated order, the standard badge bare at
`:6`. Logo at `:9`. `## What's new` is absent and is the ratified row at
`docs/ARCHITECTURE.md:194`. `### Settings panel` at `README.md:118` now leads with the mandated
`| Page | Covers |` table at `:123-128` — PM-010 closed. `## Credits` at `:382-386` is external
credit only.

**`CLAUDE.md`** — 92 lines; H1 `:1`; adherence line `:3-4`; `## Standards compliance (read first)`
`:6`; the docs pointer list `:28-35` (and `:72` records that `docs/agent-context.md` must never be
created — anti-pattern #49 clear); the green-gate line `:61-64`; the provenance line `:44`.

**`DEPENDENCIES.md`** — present, 187 lines, the WSL2/Ubuntu toolchain contract.

**No `CHANGELOG.md` at the addon root**, and no `TODO.md` anywhere.
