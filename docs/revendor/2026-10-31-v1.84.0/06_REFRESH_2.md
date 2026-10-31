# 06 — Refresh 2 (PanelMaster)

Item M4-RV of the findings remediation. The local tag `v1.84.0` moved again before its release was pushed,
so this is a second refresh of the re-vendor in this bundle and not a new one.
`git -C ../LibKa0s ls-remote --tags origin v1.84.0` prints nothing.

| | Commit |
|---|---|
| Old `git -C ../LibKa0s rev-parse v1.84.0^{commit}` | `7a8bc0f133ed118d2c79c7c5288b97964e24fae5` |
| New `git -C ../LibKa0s rev-parse v1.84.0^{commit}` | `b5229b876e803768322fb4d8c66be69f01c8e4a1` |

The new commit range carries `LK-M4`, the owner's ruling of 2026-11-01: `lib.__PatchLSM30Border` is deleted,
with no stub left behind.

## Per-file minor delta

3c's loop, run against each commit. Every other file is unchanged, and the kit stays at revision 47.

| File | Constant | Old | New |
|---|---|---|---|
| `Options.lua` | `MINOR` | 36 | 37 |
| `OptionsDrawer.lua` | `DRAWER_MINOR` | 3 | 4 |
| `OptionsMedia.lua` | `MEDIA_MINOR` | 2 | 3 |

## The copy

Both payloads were copied whole from the extract. The content diff was empty in both directions before the
prune. `tools/prune-icons.lua` kept the 4 declared icons and the licence file, and removed the 5835
undeclared files. The `LibKa0s icons:` line and the provenance line did not move.

## What a consumer owes

Nothing in this repo. M3-MEDIA already removed the host's call, and M3-RV the test case that pinned the
member, so no authored file or test names `__PatchLSM30Border`:

`git grep -n "__PatchLSM30Border" -- ':!libs' ':!tests/_kit' ':!docs'` prints nothing. The frozen bundles
under `docs/` keep their mentions. No stub or guard was added, and no pinned minor needed moving.

## Gate

`lua tests/run.lua` 1162 passed, 0 failed, 1 skipped, 1163 total, and `luacheck .` 0 warnings / 0 errors in
84 files, both through `ka0s-bounded`.
