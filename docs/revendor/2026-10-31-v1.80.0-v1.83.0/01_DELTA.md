Delta: LibKa0s v1.80.0 -> v1.83.0 (span: v1.80.0 v1.81.0 v1.82.0 v1.83.0)

# 01 — Delta: the consolidated span v1.80.0 to v1.83.0

Written 2026-10-31 by plan item `FX-PM-DOCS` of the findings remediation
(`Ka0sAddonsCommonTasks/docs/2026-10-31-FINDINGS_REMEDIATION/`). Four tags this addon vendored in
planned runs have no bundle naming them. This is a back-fill record in the consolidated span shape,
not a re-run of the re-vendor procedure: nothing here was copied.

The tag vendored immediately before the span is **v1.77.0** (`dfcfbf2`), recorded by
`docs/revendor/2026-10-24-v1.77.0/`. That is the span's base. v1.78.0 and v1.79.0 were never
vendored here, so they are not on the span line; what they owed arrived with v1.80.0.

## The two listings

`/dev-copilot:wow-revendor-libka0s` Step 3h, run before this bundle existed:

- Vendored: 61 tags. Recorded: 57.
- Vendored minus recorded: `v1.80.0`, `v1.81.0`, `v1.82.0`, `v1.83.0`, the tags on line 1.

## The vendoring commits

| Tag | Vendoring commit | Date | Run |
|---|---|---|---|
| v1.80.0 | `b30096b` | 2026-10-29 | `docs/2026-10-29-SKINNING_ROLLOUT/`, merged in `febaed5` |
| v1.81.0 | `e946f75` | 2026-10-30 | `docs/2026-10-30-SKIN_LIBRARY_FOLLOWUPS/`, merged in `f7adca7` |
| v1.82.0 | `f0a9a1b` | 2026-10-30 | `docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK/`, merged in `e05b6b4` |
| v1.83.0 | `d2e3757`, re-cuts `e71c813`, `b520b0b`, `e63877d` | 2026-10-31 | `docs/2026-10-31-FONT_PICKERS_AND_SKIN_FACES/`, merged in `e05b6b4` |

The run folders are in Ka0sAddonsCommonTasks. Each tag is read off the `Bundles [LibKa0s](…) vX.Y.Z`
provenance line in root `CLAUDE.md` at that commit. Each commit's own message is the record of what
that re-vendor moved.

## Per tag

`git -C ../LibKa0s diff --shortstat <base> <tag> -- LibKa0s testkit`:

- **v1.80.0** (base v1.77.0): 74 files, 10923 insertions, 795 deletions. The Skin and Toast majors,
  and the Options stub's `AppearanceTab`, `AppearanceRows`, `SkinPicker` and `HideSkinPicker`. The
  `LibKa0s icons:` line gained `settings`.
- **v1.81.0**: 24 files, 971 insertions, 320 deletions. The picker's title became "Choose a skin", with
  the addon's name on `frame.ownerLabel`. No kit file moved.
- **v1.82.0**: 31 files, 3520 insertions, 456 deletions. Kit revision 45 (`glyphs.lua`), the Font
  outline and `O.SkinVerb`.
- **v1.83.0**: 33 files, 2083 insertions, 246 deletions, at the final cut `6c816fd`. Kit revision 46,
  `OptionsMedia.lua`, the picker's rows (LK-A3).

## Consumption

PanelMaster adopted `LibKa0s-Skin-1.0` across this span, its eleventh consumed major; `Toast` is
vendored and not consumed. The adoption was planned in the runs above, so its decisions are in their
`DECISIONS.md` files and not here.
