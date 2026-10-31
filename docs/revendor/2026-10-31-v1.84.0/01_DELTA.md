Delta: LibKa0s v1.83.0 -> v1.84.0

# 01 — Delta (PanelMaster)

Item XX-RV of the findings remediation's library release
(`Ka0sAddonsCommonTasks/docs/2026-10-31-FINDINGS_REMEDIATION/M2_LIBRARY_RELEASE.md`), branch
`feat/2026-10-31-findings-remediation`, run per the installed `/dev-copilot:wow-revendor-libka0s`
2.6.1. The run makes the re-vendor non-interactive: no interview and no GitHub issue; candidates
beyond the brief are recorded as declined in `02_CANDIDATES.md`. Copied from the **local** annotated
tag `v1.84.0` (tag object `0c32e37`, commit `e917ccd`) with `git -C ../LibKa0s archive v1.84.0 LibKa0s
testkit tools | tar -x -C <scratch>`. The tag is not pushed yet (`git -C ../LibKa0s ls-remote --tags
origin v1.84.0` prints nothing).

## Step 0. Pre-flight

The newest single-tag bundle, `docs/revendor/2026-10-24-v1.77.0/`, states base v1.76.0 on line 1, and
its own `01_DELTA.md` records the provenance line before that re-vendor naming v1.76.0. `ok`, so no
correction is owed.

## 3a. Base

`grep -n '[Bb]undles' CLAUDE.md` names v1.83.0. The last payload commit is `e63877d` (`PM-RV3: Take
the re-cut LibKa0s v1.83.0`), whose `CLAUDE.md` names v1.83.0. `diff -rq` of the v1.83.0 archive
against both payloads printed only the `Only in <scratch>/LibKa0s/media/icons` lines of the
undeclared icons. Base **v1.83.0**.

`git -C ../LibKa0s log --oneline v1.83.0..v1.84.0`: 26 commits. `git -C ../LibKa0s diff --stat v1.83.0
v1.84.0`: 145 files changed, 84134 insertions, 6820 deletions, most of them the library's own record.

## 3b/3c. Per-file minors that moved (from the tag's `LibKa0s.xml`)

| File | Before | After |
|---|---|---|
| `Schema.lua` | 2 | 3 |
| `Charts.lua` | (new) | 1 |
| `ChartsRender.lua` | (new) | 1 |
| `Skin.lua` | 10 | 11 |
| `SkinOwnerTokens.lua` | (new) | 1 |
| `SkinDefs.lua` | 18 | 19 |
| `SkinDefsOthers.lua` | (new) | 1 |
| `WidgetsDragHandle.lua` | 8 | 10 |
| `DebugLogDiagnostics.lua` | 5 | 6 |
| `Slash.lua` | 20 | 21 |
| `Options.lua` | 34 | 35 |
| `OptionsWidgets.lua` | 38 | 40 |
| `OptionsFlow.lua` | (new) | 2 |
| `OptionsIds.lua` | 5 | 6 |
| `OptionsIdSuggest.lua` | (new) | 1 |
| `OptionsTabs.lua` | 11 | 13 |
| `OptionsTabbed.lua` | (new) | 2 |
| `OptionsCompose.lua` | 14 | 15 |
| `OptionsSkinPicker.lua` | 4 | 5 |
| `OptionsSkinPickerRows.lua` | (new) | 1 |
| `SimPanel.lua` | 8 | 9 |
| `SimPanelRender.lua` | (new) | 1 |

Every other file is at its v1.83.0 minor. Twenty majors across sixty-four files. The claim
(provenance v1.83.0) and the fact (every vendored minor equal to v1.83.0's) agreed before the copy.
No cross-major skew.

## 3d. Diffs

Before the copy the only `Only in` lines on either side were the undeclared icons (see 3a); nothing
had forked.

## 3e. Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' core modules settings`: one lookup site each
for Bus, Core, DebugLog, Env, Launcher, Lifecycle, Media, Options, Schema, Skin and Slash. The new
major `Charts` has none, and neither do `Perf`, `Widgets`, `Pool`, `Item`, `Compat`, `Glow`, `Sim` and
`Toast`.

## 3f. Kit revision

46 -> 47 (`grep -n 'Kit.VERSION'`). Both payloads move together; the pairing rule holds by
construction.

## 3g. Contract delta

Moved and looked up: Options, Schema, Slash, Skin, DebugLog. Read as a `diff` of each major's previous
and new document (Options `version-34.4.38.5.7.11.3.14.9.4.3.6.5.4.1.1-docs.md` to
`version-35.4.40.2.6.1.7.13.2.3.15.9.4.3.6.5.5.1.1.1-docs.md`, Schema 2 to 3, Slash 20.2 to 21.2, Skin
10.18.13.7.11.2.5 to 11.1.19.1.13.7.11.2.5, DebugLog 22.5.1.2 to 22.6.1.2). `grep -rn '__Attach'` over
the addon's own code finds nothing, so no host member's call site moved.

### Blockers

- **`O.PositionBlock`** (OptionsCompose 15, `C15`): new public member of Options, and the document's
  "What changed at this version" says a consumer's degradation stub owes it at the re-vendor.
  `tests/test_surface_parity.lua` enforces it. Fixed in the re-vendor commit, in
  `settings/OptionsSetup.lua`'s stub, with an inert answer.

## 3h. Tags vendored and unrecorded

The listing prints nothing (61 vendored, 61 recorded). No span bundle.

## 3i. The icon declaration

`LibKa0s icons: clear, close, copy, settings.` kept. It sits on the line under the provenance line,
and no split is needed. v1.84.0 adds no library-drawn name for a surface this addon wires.

## 3j. Tests that assume the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v /_kit/`: the three hits
in `tests/test_mediasetup.lua` and the comment in `tests/test_libka0s.lua` hold to declared names
only. Nothing to fix.
