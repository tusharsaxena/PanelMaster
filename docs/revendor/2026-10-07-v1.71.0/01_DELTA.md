Delta: LibKa0s v1.70.0 -> v1.71.0

# 01 — Delta (PanelMaster)

Item RV-PM of the 2026-10-07 review-and-audit remediation
(`Ka0sAddonsCommonTasks/docs/2026-10-07-REVIEW_AND_STANDARDS_AUDIT_REMEDIATION/`), branch
`feat/2026-10-07-review-audit-remediation`, run mechanically per `/dev-copilot:wow-revendor-libka0s`
under the plan's owner ruling 5 (no interview, no issue filing). Copied from the **local** annotated
tag `v1.71.0` (tag object `3bf1b97`, commit `cb274a4`) with
`git -C ../LibKa0s archive v1.71.0 LibKa0s testkit | tar -x -C <scratch>`, never a branch tip and never
a checkout in the library's working tree. The tag is not pushed yet.

## 3a. Base

`grep -n 'Bundles' CLAUDE.md` -> `45:Bundles [LibKa0s](...) v1.70.0 (MIT).` The last payload commit is
`f61f2b7` (`chore: re-vendor LibKa0s v1.70.0`), whose CLAUDE.md names v1.70.0, and `diff -rq` of the
v1.70.0 archive against both payloads printed `payload-matches`. Base **v1.70.0**.

`git -C ../LibKa0s log --oneline v1.70.0..v1.71.0`: 20 commits (LK-01..LK-12 and the RA-00 record,
plus the LineChart-deviation merge). `git -C ../LibKa0s diff --stat v1.70.0 v1.71.0 -- LibKa0s testkit`:
10 files changed, 369 insertions, 140 deletions.

## 3b/3c. Per-file minors that moved

| File | Before | After | Major key |
|---|---|---|---|
| `Env.lua` | 1 | 2 | `LibKa0s-Env-1.0` 2 |
| `Slash.lua` | 19 | 20 | `LibKa0s-Slash-1.0` key 20.2 |
| `SlashParse.lua` | 1 | 2 | (same) |
| `WidgetsLineChart.lua` | 2 | 3 | `LibKa0s-Widgets-1.0` key 12.1.4.3.2 |
| `WidgetsAutocomplete.lua` | 1 | 2 | (same) |
| `OptionsIdList.lua` | 3 | 4 | `LibKa0s-Options-1.0` key 28.2.34.2.4.8.1.7.4.2 |

Every other file is at its v1.70.0 minor. No file is added to or removed from `LibKa0s/`; no
`NEEDS_*` floor rises; no cross-major skew.

## 3d. Diffs (before the copy)

- `diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s`: exactly the six files above.
- `diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit`: `README.md`, `framework.lua`,
  `inventory.lua` differ, and `Only in <scratch>/testkit: secrets.lua`. No `Only in tests/_kit` line,
  so nothing is deleted.

## 3e. Consumption

PanelMaster consumes ten majors: `Core`, `Env`, `Media`, `DebugLog`, `Slash`, `Options`, `Launcher`,
`Lifecycle`, `Schema`, and `Bus` (for its `Catalog` alone). `Widgets` is a settled decline (#43), so
the WidgetsLineChart and WidgetsAutocomplete moves are carried and not consumed. Moves that reach a
consumed major: Env 2, Slash 20 / SlashParse 2, OptionsIdList 4.

## 3f. Kit revision

`Kit.VERSION` 37 -> **38** (`tests/_kit/framework.lua:20`). Revision 38 (LK-01) makes `--list`'s
Totals count only cases that run, with a declared skip on its own `| Skipped | n |` row, and rewords
the inventory header so it agrees with testing-§5; and (LK-02) adds `testkit/secrets.lua`
(`Kit.SECRET_ERROR`, `Kit.secret`, `Kit.isSecret`, `Kit.reveal`, `Kit.installSecretValue`), which
installs nothing by default. Both payloads are copied whole in one commit, so the revision pairing
rule holds by construction.

## 3g. Contract changes under unchanged signatures

- **`Env.GetAddOnMetadata` (Env 2) no longer reads the bare `GetAddOnMetadata` global**: it answers
  `C_AddOns.GetAddOnMetadata` where that exists, else nil. Every admitted client has `C_AddOns`, so
  in game nothing changes. PanelMaster's own library-absent fallback in `core/EnvSetup.lua:51-57`
  still carries the bare-global rung; that is not a mechanical consequence of the copy and is the
  owning item PM-09's to delete.
- **`Slash.ParseValue` (SlashParse 2) refuses `nan`, `inf`, `-inf` and overflowing literals on a
  number row** with the existing `ERR_NUMBER`. PanelMaster's `/pm set` reaches number rows through
  this parser, so non-finite input is now refused at the slash seam for free. The panel's own number
  fields are PM-06's.
- **`OptionsIdList` 4**: the help mark's loaded-addon check reads only `C_AddOns.IsAddOnLoaded`, no
  bare global. Same in-game behavior on every admitted client.
- `Slash.lua` 20 changes one comment only.

`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` is empty:
the addon hands the library no callback members through an attach seam.

## 3h. Unrecorded tags

The walk from the store's horizon (2026-08-25) found 51 tags vendored and 49 recorded before this
run: v1.69.0 and v1.70.0 (`4e15691`, `f61f2b7`). They are back-filled in the span bundle
`docs/revendor/2026-10-07-v1.69.0-v1.70.0/`.

## After the copy

`rm -rf libs/LibKa0s tests/_kit`, then `cp -r` of both payloads; `diff -r` of `<scratch>/LibKa0s`
against `libs/LibKa0s` and of `<scratch>/testkit` against `tests/_kit` both print nothing.
`tests/_kit/run-automated-tests.sh` stays recorded `100755`. In the same commit: CLAUDE.md:45's
provenance line rolled v1.70.0 -> v1.71.0, and `docs/test-cases.md` regenerated under kit 38.
`docs/testing.md:242` ("kit revision 36") is left for PM-11, which makes it defer to the provenance
line.
