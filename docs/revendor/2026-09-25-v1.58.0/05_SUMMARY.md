# 05 — Summary: LibKa0s v1.57.0 → v1.58.0

Run on 2026-09-25 as plan item M6-PM (2026-09-23 remediation plan, milestone M6: left-click opens
settings, right-click opens the options menu), branch `feat/2026-09-23-review-audit-remediation`.
One commit carries the copy, this record, the adoption the release owes and its docs, because the
copy alone reddens ten host cases that pinned retired behavior. Nothing was pushed, and the addon version did not move.

## The tag and the minors

`v1.57.0` → `v1.58.0` (tag `93cf3ad` → commit `34931c9`). One file moved a minor, Launcher 3 → 4;
the kit stays at revision 26 with identical bytes. No base correction was owed. Full detail in
`01_DELTA.md`.

## Reached the addon for free (class A)

- Left-click opens the settings panel, in either state; the tooltip's hints read
  `Left-click: Open settings` / `Right-click: Options menu`.
- Right-click opens the client's context menu once the host supplies a pair (below), and falls back
  to the panel on a client with no `MenuUtil`.

## Contract blockers

None (`01_DELTA.md` 3g).

## Adopted (M6-PM)

`core/LauncherSetup.lua`, per `launcher-§2` (standard v2.67.0). The menu is **Enabled · Locked**,
matching the standard's `ADDONS.md` row:

- `setEnabled(on)` → `NS.Slash:CliEnable(on)`, the body of `/pm enable` / `/pm disable`, beside the
  existing `isEnabled` (the master switch).
- `toggleLock()` → `NS.Slash:CliLock(not isLocked())`, the body of `/pm lock` / `/pm unlock`, beside
  the existing `isLocked` (`state.locked`, the *Lock frame* row). Through `CliSet`, so the single
  write seam, one `[Set]` trace, the `path = value` echo and the combat deferral all hold.
- Removed: `onClick` (rung (b)), `leftClickLabel` (and its two `NS.L` keys in `locales/enUS.lua`),
  `disabledLine`. Kept: `version`, `isLocked`, `isEnabled`.
- **Not** `toggleTestMode` (no test mode: unlocking is the preview) and **not** `isWindowShown` /
  `toggleWindow` (no primary window).

Pinned in `tests/test_launcher.lua` through `tests/mock_menu.lua`, a copy of the library's own
repo-local menu mock (the kit ships none). The cases cover: left opens settings, right opens the
titled menu, exactly Enabled | Locked, state read on each open, each entry routing to its slash
handler both ways, the write seam and combat deferral, grayed-while-disabled, and the no-`MenuUtil`
fallback. The tooltip cases re-pin the fixed hints. `tests/test_disabled.lua` case 8 now proves the
disabled left click opens the panel and the grayed *Locked* entry writes nothing.

## Declined

None in this run.

## Suite results at each gate

All through `~/.claude/wow-addon/bin/ka0s-bounded`.

| Gate | Headless suite | Lint |
|---|---|---|
| Baseline, `efbd2d9` | 928 passed, 0 failed, 0 skipped, 928 total | 0 warnings / 0 errors in 61 files |
| After the copy | 918 passed, 10 failed, 0 skipped, 928 total | 0 warnings / 0 errors in 61 files |
| After the adoption | 933 passed, 0 failed, 0 skipped, 933 total | 0 warnings / 0 errors in 62 files |

Complexity: lizard's CCN 15 warning run over the authored tree reports nothing; the largest
authored file is 1447 lines.
