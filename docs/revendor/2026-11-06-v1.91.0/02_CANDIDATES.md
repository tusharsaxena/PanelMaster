# Candidates, v1.90.0 -> v1.91.0

Sources: `git -C ../LibKa0s log --oneline v1.90.0..v1.91.0` (7 commits since the v1.90.0 merge), the
tag's `CHANGELOG.md` block v1.91.0 (`:13`), and the `docs/api/` documents of every major whose minor
moved (Core 17.1, Widgets 26.1.6.13.7.8.5, Skin 17.1.27.8.19.19.1.1.17.4.9).

## Class A: delivered on the re-vendor, not offered

- **WidgetsLineChart 7** (`FU-L1`). The chart's axis, grid, markers, crosshair and series are physical
  pixels at any UI scale; "No member, option or data field moves" (CHANGELOG v1.91.0, *The line chart's
  lines in physical pixels*; `docs/api/Widgets/version-26.1.6.13.7.8.5-docs.md`). PanelMaster draws no
  line chart (no Widgets lookup, 01_DELTA 3e), so nothing visible moves here.
- **Core 17 + CorePixel 1, Widgets 26 + WidgetsDropdown 1, SkinPaintExtras 19 + SkinPaintHud 1 +
  SkinAceConfirm 1** (`FU-L2`). Pure moves along each file's seam: "No member, option or behavior
  changes" (CHANGELOG v1.91.0, *The band files peeled*); Core's API is additive-only
  (`docs/api/Core/version-17.1-docs.md:608-611`). The vendored `LibKa0s.xml` loads the new files in
  order, and this addon's suites read that XML, so nothing is owed.

## Class B: host change required

None. The release adds no public surface: "v1.91.0 adds no Skin facade, major or instance member"
(`docs/releasing.md`, step 8, at the tag).

## Class C: whole-module adoption

None new in this range (no major added). IconBrowser stays settled
(`../2026-11-06-v1.89.0/03_DECISIONS.md`).
