# 06 — Refresh 1 (PanelMaster)

Item M3-RV of the findings remediation. The local tag `v1.84.0` moved before its release was pushed, so
this is a refresh of the re-vendor in this bundle and not a new one. `git -C ../LibKa0s ls-remote --tags
origin v1.84.0` prints nothing.

| | Commit |
|---|---|
| Old `git -C ../LibKa0s rev-parse v1.84.0^{commit}` | `e917ccd` |
| New `git -C ../LibKa0s rev-parse v1.84.0^{commit}` | `7a8bc0f133ed118d2c79c7c5288b97964e24fae5` |

The new commit carries `LK-M3`, the owner's ruling of 2026-11-01: `Ka0sMedia_*` is the only media picker
in the collection (LibKa0s#73).

## Per-file minor delta

3c's loop, run against each commit. Every other file is unchanged, and the kit stays at revision 47.

| File | Constant | Old | New |
|---|---|---|---|
| `Options.lua` | `MINOR` | 35 | 36 |
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 40 | 41 |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 15 | 16 |
| `OptionsScroll.lua` | `SCROLL_MINOR` | 9 | 10 |
| `OptionsMedia.lua` | `MEDIA_MINOR` | 1 | 2 |
| `SkinAce.lua` | `ACE_MINOR` | 5 | 6 |

## The copy

Both payloads were copied whole from the extract. Content and byte diffs were empty in both directions
before the prune. `tools/prune-icons.lua` kept the 4 declared icons and the licence file, and removed the
5835 undeclared files. The `LibKa0s icons:` line and the provenance line did not move.

## What a consumer owes

From the tag's CHANGELOG (`One media picker`), and all of it fixed in this commit or in M3-MEDIA:

- `tests/test_libka0s.lua` pinned `__PatchLSM30Border` wrapping a widget, and it is now a no-op that answers
  false. The case is deleted here, and M3-MEDIA removes the host's call.
- `tests/test_options_groups.lua` pinned the `LSM30_*` type on composed rows, which now write
  `dialogControl = "Ka0sMedia_*"`. The expected types moved here.
- `settings/PanelEditor.lua` creates its pickers itself, so it must ask `lib.__MediaWidgetType(kind)`.
  That change is M3-MEDIA.

## Gate

After the test moves: `lua tests/run.lua` 1160 passed, 0 failed, 1 skipped, 1161 total, and
`luacheck .` 0 warnings / 0 errors in 84 files, both through `ka0s-bounded`. Before them the suite failed
those 3 cases and nothing else. No new adoption and no GitHub issue came out of this refresh.
