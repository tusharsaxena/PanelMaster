Delta: LibKa0s v1.76.0 -> v1.77.0

# 01 — Delta (PanelMaster)

Item PM-RV of the 2026-10-24 keybindings, settings layout and frame strata run
(`Ka0sAddonsCommonTasks/docs/2026-10-24-KEYBINDS_LAYOUT_STRATA/`), branch
`feat/2026-10-24-keybinds-layout-strata`, run per the installed `/dev-copilot:wow-revendor-libka0s`
2.4.0. The run's ruling makes the re-vendor non-interactive: no interview and no GitHub issue; the
adoptions this run needs are its own items (for PanelMaster, PM-ZS), and every other candidate is
recorded as deferred in `02_CANDIDATES.md`. Copied from the **local** annotated tag `v1.77.0` (tag
object `7380d36`, commit `78240f7`) with `git -C ../LibKa0s archive v1.77.0 LibKa0s testkit tools |
tar -x -C <scratch>`, never a branch tip and never a checkout in the library's working tree. The
tag is not pushed yet (`git -C ../LibKa0s ls-remote --tags origin v1.77.0` prints nothing).

## Step 0. Pre-flight

The newest single-tag bundle, `docs/revendor/2026-10-23-v1.76.0/`, states base v1.75.2 on line 1;
the provenance line before its re-vendor commit `85aca33` named v1.75.2. `ok`, so no correction is
owed.

## 3a. Base

`grep -n '[Bb]undles' CLAUDE.md` -> `51:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s)
v1.76.0 (MIT).` The last payload commit is `9c950c3` (`PM-RV2: Re-vendor LibKa0s from the moved
local tag v1.76.0 (LK-91)`), whose `CLAUDE.md` names v1.76.0, and no `CLAUDE.md` commit follows it.
`diff -rq` of the v1.76.0 archive against both payloads showed only the `Only in
<scratch>/LibKa0s/media/icons` lines of the undeclared icons, which is the declaration working (3d).
Base **v1.76.0**.

`git -C ../LibKa0s log --oneline v1.76.0..v1.77.0`: 15 commits (LK-00 to LK-04, LK-10 to LK-13,
LK-20, LK-90 and the v1.76.0 merge). `git -C ../LibKa0s diff --stat v1.76.0 v1.77.0`: 82 files
changed, 43353 insertions, 140 deletions, most of them the library's own release record.

## 3b/3c. Per-file minors that moved (from the tag's `LibKa0s.xml`)

| File | Before | After | Major key at the tag |
|---|---|---|---|
| `Core.lua` | 11 | 12 | `LibKa0s-Core-1.0` 12 (`RaiseStaticPopups`) |
| `DebugLog.lua` | 20 | 21 | `LibKa0s-DebugLog-1.0` 21.3.1 (the console is toplevel) |
| `PerfPanel.lua` | 8 | 9 | `LibKa0s-Perf-1.0` 15.1.1.9 (toplevel) |
| `SimPanel.lua` | 5 | 6 | `LibKa0s-Sim-1.0` 2.3.6 (toplevel) |
| `Widgets.lua` | 14 | 15 | `LibKa0s-Widgets-1.0` 15.1.5.3.3 (dropdown menu clamped) |
| `WidgetsDragHandle.lua` | 4 | 5 | (same; `spec.level`, `ApplyLevel`, `ignoreParentAlpha`) |
| `WidgetsAutocomplete.lua` | 2 | 3 | (same; list clamped) |
| `Options.lua` | 29 | 30 | `LibKa0s-Options-1.0` 30.2.34.3.5.9.2.8.4.2.1.3 |
| `OptionsIds.lua` | 2 | 3 | (same; suggestion list closes at combat start) |
| `OptionsCombat.lua` | 1 | 2 | (same) |
| `OptionsCompose.lua` | 7 | 8 | (same; `O.StrataTooltip`) |
| `OptionsKeybinds.lua` | (new) | 3 | (same; the Keybindings tab, a twelfth Options file) |

Every other file is at its v1.76.0 minor. Still seventeen majors, now across forty-one files. The
claim (provenance v1.76.0) and the fact (every vendored minor equal to v1.76.0's) agreed before the
copy. No cross-major skew.

## 3d. Diffs

Before the copy, `diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s` printed the twelve
moved files, `LibKa0s.xml`, `Only in <scratch>/LibKa0s: OptionsKeybinds.lua` and the undeclared-icon
`Only in <scratch>` lines; `diff -rq <scratch>/testkit tests/_kit` printed `README.md` and
`framework.lua` differing and `bindings_xml.lua`, `mock_bindings.lua` and `mock_layers.lua` only in
the tag. After `cp -r <scratch>/LibKa0s/. libs/LibKa0s/` and `cp -r <scratch>/testkit/. tests/_kit/`,
all four diffs, content (`--strip-trailing-cr`) and bytes, were empty in both payloads. Neither
printed an `Only in libs/LibKa0s` or `Only in tests/_kit` line, so nothing was deleted on inference.
After the prune, `diff -rq <scratch>/LibKa0s libs/LibKa0s` prints only
`Only in <scratch>/LibKa0s/media/icons…` lines.

## 3e. Consumption

`LibStub("LibKa0s-*-1.0", true)` outside `libs/` and `tests/`: Core, Launcher, Lifecycle, Env, Media,
Bus, DebugLog (`core/`), Options, Slash, Schema (`settings/`). Ten majors, unchanged. Of the majors
that moved, Core, DebugLog and Options are consumed; Widgets (#43), Perf (ratified) and Sim are not.

## 3f. Kit revision

`Kit.VERSION` 41 -> **42** (`grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua
tests/_kit/framework.lua`). Revision 42 adds `mock_bindings.lua`, `mock_layers.lua` and
`bindings_xml.lua` (`Kit.assertBindingsXml`, `Kit.keybindThroughTab`), all opt-in. Both payloads are
copied whole in one commit, so the pairing rule holds by construction.

## 3g. Contract changes under unchanged signatures

`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` is empty, so
no host-supplied member can have had its call site moved. The consumed majors that moved, read
against their documents at both tags:

- **Core 12** (`docs/api/Core/version-12-docs.md:14`, `:394`): one member added,
  `RaiseStaticPopups()`; nothing tightened.
- **DebugLog 21.3.1** (`docs/api/DebugLog/version-21.3.1-docs.md:14`, `:52-64`): no member change.
  The console is now toplevel and re-raises a shown StaticPopup on show. The tag's `CHANGELOG.md`
  asks an addon whose own surface sits at DIALOG or above to say in its LAYERS comment that the
  console can cover it; PanelMaster's layering table is PM-ZS's (this run), so it is forwarded there.
- **Options 30.2.34.3.5.9.2.8.4.2.1.3** (`docs/api/Options/version-30.2.34.3.5.9.2.8.4.2.1.3-docs.md`,
  header `:15` superseding `version-29.2.34.2.5.9.1.7.4.2.1`): four instance members added,
  `KeybindingsTab`, `KeybindRows`, `KEYBINDS_UNCHANGED` (`:1539-1541`) and `StrataTooltip` (`:1581`),
  nothing removed (`:2787`). `O.__releaseOwnedFocus` now also closes the IdInput suggestion list
  (OptionsCombat 2); PanelMaster builds no IdInput, so nothing on screen moves here.

### Blockers

- **The Options degradation stub owes four members** (`:1994` and `:2789`; the tag's
  `CHANGELOG.md` *What a consumer owes*). `Kit.assertSurfaceParity` turned
  `tests/test_surface_parity.lua:207` red after the copy:
  `KEYBINDS_UNCHANGED is missing (live: string); KeybindRows is missing (live: function);
  KeybindingsTab is missing (live: function); StrataTooltip is missing (live: function)`. Fixed in
  the re-vendor commit, in `settings/OptionsSetup.lua`'s library-absent stub: `KeybindRows` answers
  nil (as the live member does when it cannot draw), `KeybindingsTab` an inert tab entry, and
  `KEYBINDS_UNCHANGED` and `StrataTooltip` the empty string, for the reason `ID_NAME_HINT` is empty
  there (a copy of the library's sentences in the stub is the one that goes stale).

## 3h. Unrecorded tags

The walk from the store's horizon (2026-08-25) found 56 tags vendored and 56 recorded. Nothing
unrecorded, so no span bundle.

## 3i. The icon declaration

Kept, unchanged, directly under the provenance line (`CLAUDE.md:52`):

    LibKa0s icons: clear, close, copy.

Its derivation is `docs/revendor/2026-10-22-v1.75.0/01_DELTA.md` 3i. v1.77.0 adds no library-drawn
mark: the Keybindings tab draws text rows, and the toplevel and clamp changes draw nothing new. The
prune, `lua <scratch>/tools/prune-icons.lua .`, printed `3 icon(s) declared; kept 4 file(s), removed
5836`. Hand lists have drifted before (KickCD and WhatGroup `tests/test_mediasetup.lua`); the owner's
in-client smoke DIAG-2 stays the backstop.

## 3j. Tests that assumed the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'` finds the
v1.75.0 bundle's narrowed cases (`tests/test_mediasetup.lua:78`, `:105`, `tests/test_libka0s.lua:200`),
all declaration-aware already. Nothing to change.
