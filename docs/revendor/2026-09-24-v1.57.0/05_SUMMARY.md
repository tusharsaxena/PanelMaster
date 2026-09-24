# 05 — Summary: LibKa0s v1.56.0 → v1.57.0

Run on 2026-09-24 as plan item M5-PM (2026-09-23 remediation plan, milestone M5: the always-on
launcher status tooltip), branch `feat/2026-09-23-review-audit-remediation`. Two commits: the copy
and this record, then the one adoption the release owes. Nothing was pushed, and the addon version
did not move.

## The tag and the minors

`v1.56.0` → `v1.57.0` (tag `d03e836` → commit `aa37bc9`). One file moved a minor, Launcher 2 → 3;
the kit stays at revision 26 with identical bytes. No base correction was owed. Full detail in
`01_DELTA.md`.

## Reached the addon for free (class A)

- The minimap button and the broker row answer a hover with the library's status tooltip, enabled
  or disabled. On the copy alone it is incomplete for this addon (always `Enabled: Yes`, no
  `Locked:` line, `Left-click: Toggle`), which is what the adoption below corrects.

## Contract blockers

None (`01_DELTA.md` 3g).

## Adopted (the second M5-PM commit)

`core/LauncherSetup.lua` passes the launcher-§1 (standard v2.66.0) fields, each read on every show:

- `version` → `NS.Version()`, the TOC's `## Version` through the seam `/pm version` reads.
- `isEnabled` → the master switch (`NS.IsAddonEnabled`), with `disabledLine` → the Slash
  dispatcher's `DisabledLine()`. This makes `Enabled:` true and the disabled hint read
  `Left-click: disabled — /pm enable`. It also moves the disabled left-click refusal into the
  library's gate (Launcher minor 2); the host's own copy in `toggleLock` is removed so there is one.
- `isLocked` → `state.locked`, the accessor the *Lock frame* row reads.
- `leftClickLabel` → `Unlock frame` while locked, `Lock frame` while unlocked (rung (b), "lock /
  unlock" in the standard's `ADDONS.md`), through `NS.L` (two keys in `locales/enUS.lua`).
- **Not** `isTestMode`: this addon has no test mode (unlocking is its preview). **Not**
  `onTooltipShow`: it has no line of its own.

Pinned in `tests/test_launcher.lua` through the object's `OnTooltipShow` (seven cases: the whole
block enabled and disabled, the TOC version, re-read on every show, the colors, no Test mode line,
and the library's gate refusing once).

## Declined

None in this run.

## Suite results at each gate

All through `~/.claude/wow-addon/bin/ka0s-bounded`.

| Gate | `lua5.1 tests/run.lua` | `luacheck .` |
|---|---|---|
| Baseline, `a3b4390` | 921 passed, 0 failed, 0 skipped, 921 total | 0 warnings / 0 errors in 61 files |
| After the copy | 921 passed, 0 failed, 0 skipped, 921 total | 0 warnings / 0 errors in 61 files |
| After the adoption | 928 passed, 0 failed, 0 skipped, 928 total | 0 warnings / 0 errors in 61 files |

Complexity: lizard's CCN 15 warning run over the authored tree reports nothing at each gate; the
largest authored file is 1447 lines.
