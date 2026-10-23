Delta: LibKa0s v1.75.2 -> v1.76.0

# 01 — Delta (PanelMaster)

Item PM-RV of the 2026-10-23 sim auto-run, QC preview selector, mode strips and MM/KCD simulators
run (`Ka0sAddonsCommonTasks/docs/2026-10-23-SIM_PREVIEW_MODE_STRIPS/`), branch
`feat/2026-10-23-sim-preview-mode-strips`, run per the installed `/dev-copilot:wow-revendor-libka0s`
2.4.0. The run's ruling makes the re-vendor non-interactive: no interview and no GitHub issue;
candidates are listed in `02_CANDIDATES.md`. Copied from the **local** annotated tag `v1.76.0` (tag
object `546e284`, commit `9949368`) with `git -C ../LibKa0s archive v1.76.0 LibKa0s testkit tools |
tar -x -C <scratch>`, never a branch tip and never a checkout in the library's working tree. The
tag is not pushed yet (`git -C ../LibKa0s ls-remote --tags origin v1.76.0` prints nothing).

## Step 0. Pre-flight

The newest single-tag bundle, `docs/revendor/2026-10-22-v1.75.0/`, states base v1.71.0 on line 1;
the provenance line before its re-vendor commit `8beece7` named v1.71.0. `ok`, so no correction is
owed.

## 3a. Base

`grep -n '[Bb]undles' CLAUDE.md` -> `51:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s)
v1.75.2 (MIT).` The last payload commit is `b534579` (`Re-vendor LibKa0s v1.75.2 (SimPanel minor
4)`), whose `CLAUDE.md` names v1.75.2, and `diff -rq` of the v1.75.2 archive against both payloads
showed only the `Only in <scratch>/LibKa0s/media/icons` lines of the undeclared icons, which is the
declaration working (3d). Base **v1.75.2**.

`git -C ../LibKa0s log --oneline v1.75.2..v1.76.0`: 8 commits (LK-00, LK-01, LK-10, LK-25, LK-90
and the v1.75.2 merge). `git -C ../LibKa0s diff --stat v1.75.2 v1.76.0 -- LibKa0s testkit`: 3 files
changed, 148 insertions, 53 deletions (`SimPanel.lua`, `SimTimeline.lua`, `Widgets.lua`).

## 3b/3c. Per-file minors that moved (from the tag's `LibKa0s.xml`)

| File | Before | After | Major key at the tag |
|---|---|---|---|
| `Widgets.lua` | 13 | 14 | `LibKa0s-Widgets-1.0` 14.1.4.3.2 (`TestStrip` `kind = "sim"`) |
| `SimTimeline.lua` | 2 | 3 | `LibKa0s-Sim-1.0` 2.3.5 (a verb start plays on its own) |
| `SimPanel.lua` | 4 | 5 | (same; Run all removed, Pause/Resume, Restart, Stop) |

Every other file is at its v1.75.2 minor. No `NEEDS_*` floor rises; still seventeen majors across
forty files. The claim (provenance v1.75.2) and the fact (every vendored minor equal to v1.75.2's)
agreed before the copy. No cross-major skew.

## 3d. Diffs

Before the copy, the content diff against the tag printed the three moved files and the
undeclared-icon `Only in <scratch>` lines; the testkit diff printed nothing. After
`cp -r <scratch>/LibKa0s/. libs/LibKa0s/` and `cp -r <scratch>/testkit/. tests/_kit/`, both diffs,
content (`--strip-trailing-cr`) and bytes, were empty in both payloads. Neither printed an
`Only in libs/LibKa0s` or `Only in tests/_kit` line, so nothing was deleted on inference. After the
prune, `diff -rq <scratch>/LibKa0s libs/LibKa0s` prints only `Only in <scratch>/LibKa0s/media/icons…`
lines.

## 3e. Consumption

`LibStub("LibKa0s-*-1.0", true)` outside `libs/` and `tests/`: Core, Launcher, Lifecycle, Env, Media,
Bus, DebugLog (`core/`), Options, Slash, Schema (`settings/`). Ten majors, unchanged. `Widgets` and
`Sim`, the two majors that moved, have no lookup site here; `Widgets` is a settled decline (#43) and
`Sim` has no simulator to host.

## 3f. Kit revision

`Kit.VERSION` 41 -> **41** (`grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua
tests/_kit/framework.lua`). The testkit is byte-identical to v1.75.2's. Both payloads are copied whole
in one commit, so the pairing rule holds by construction.

## 3g. Contract changes under unchanged signatures

`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` is empty.
The majors that moved (Widgets, Sim) intersect the consumed set (3e) in nothing, so there is no
consumed contract to read. Two internal reaches, checked anyway:

- `libs/LibKa0s/DebugLog.lua:33` resolves Widgets for the console's copy window. Widgets 14 adds
  `opts.kind` and `strip.kind` to `TestStrip` only (Widgets `version-14.1.4.3.2-docs.md:20-35`);
  the copy window's contract is unchanged.
- The v1.76.0 *What a consumer owes* list (tag `CHANGELOG.md`): no code; re-true suites that typed
  `start` then ran or clicked Run all; reword docs and strings naming Run all; no host overrides
  `RUN_ALL`. `grep -rniE 'run all|RUN_ALL|TestStrip|sim start' --include='*.lua' --include='*.md' .`
  outside `libs/`, `tests/_kit/` and the frozen bundles finds nothing, so none applies.

### Blockers

None.

## 3h. Unrecorded tags

The walk from the store's horizon (2026-08-25) found 55 tags vendored and 53 recorded: `v1.75.1`
and `v1.75.2`, both vendored on 2026-10-23 outside a planned run, had no bundle. They are recorded
by the consolidated span bundle `docs/revendor/2026-10-23-v1.75.1-v1.75.2/`.

## 3i. The icon declaration

Kept, unchanged, directly under the provenance line (`CLAUDE.md:52`):

    LibKa0s icons: clear, close, copy.

Its derivation is `docs/revendor/2026-10-22-v1.75.0/01_DELTA.md` 3i. v1.76.0 adds no library-drawn
mark this addon wires: the strip's simulation flavor draws the host's own mark, and PanelMaster builds
no strip. The prune, `lua <scratch>/tools/prune-icons.lua .`, printed `3 icon(s) declared; kept 4
file(s), removed 5836`. Hand lists have drifted before (KickCD and WhatGroup
`tests/test_mediasetup.lua`); the owner's in-client smoke DIAG-2 stays the backstop.

## 3j. Tests that assumed the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'` finds the
v1.75.0 bundle's narrowed cases (`tests/test_mediasetup.lua:78`, `:105`, `tests/test_libka0s.lua:200`),
all declaration-aware already. Nothing to change.
