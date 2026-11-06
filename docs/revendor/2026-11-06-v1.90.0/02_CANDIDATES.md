# Candidates, v1.89.0 -> v1.90.0

Sources: `git -C ../LibKa0s log --oneline v1.89.0..v1.90.0` (7 commits), the tag's `CHANGELOG.md`
block v1.90.0 (`:13`), and the `docs/api/` documents of every major whose minor moved (Core 16,
Skin 17.1.27.8.19.18.17.4.9, Widgets 24.5.12.6.8.5, Options 37.4.44.2.7.2.9.15.2.4.19.13.5.5.7.7.11.1.1.4).

## Class A: delivered on the re-vendor, not offered

- **Core 16, SkinPaint 19, SkinPaintExtras 18** (`SF1-L1`). The pixel-edge mechanism moves into Core
  (`__PixelSize`, `__WatchPixels`, `__PixelBackdrop`; `docs/api/Core/version-16-docs.md:25`); the Skin
  major's `P.px` calls it, and a WoW Default `bevelIn` holder edge on a Core pixel-exact frame is sized
  in physical pixels. "No member of the major or of a facade is added, removed or renamed"
  (`docs/api/Skin/version-17.1.27.8.19.18.17.4.9-docs.md:31`). Nothing for this addon to wire.
- **Widgets 24, WidgetsAutocomplete 8** (`SF1-L1`). The library's dropdown, search box, menus and
  autocomplete list draw a one-physical-pixel edge; "What a host owes: nothing"
  (`docs/api/Widgets/version-24.5.12.6.8.5-docs.md:27`). PanelMaster draws none of these controls in
  its own windows (no Widgets lookup, 3e), so nothing visible moves here.
- **OptionsAppearance 7** (`SF1-L2`). A Skin-tab copy or Apply to all leaves a `keepScope` target's
  Scope alone; every other target, this addon included, takes the Scope as before
  (`docs/api/Options/version-37.4.44.2.7.2.9.15.2.4.19.13.5.5.7.7.11.1.1.4-docs.md:26`).

## Class B: host change required

- **`RegisterOwner(owner, { keepScope = true })`** (Skin 17;
  `docs/api/Skin/version-17.1.27.8.19.18.17.4.9-docs.md:21-27`). For a host whose Scope is a
  documented deviation. **Not applicable**: PanelMaster's Scope default is the collection's
  (`settings/Schema.lua:182`, `skin.ignorePanel` default `true`), so a copy writing its Scope is the
  intended behaviour. The run names only Ka0s Skin Tester for it (`SF1-ST`). Blast radius: none.
  Recommendation: record, no issue.

## Class C: whole-module adoption

None new in this range. IconBrowser stays settled (`../2026-11-06-v1.89.0/03_DECISIONS.md`).
