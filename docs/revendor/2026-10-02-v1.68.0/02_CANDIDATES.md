# Candidates (PanelMaster)

Sources: the `CHANGELOG.md` block for v1.68.0 at the tag (`git -C ../LibKa0s show
v1.68.0:CHANGELOG.md`, `:13`), and the `Since 4` markers in
`docs/api/Widgets/version-12.1.4-docs.md` read against `version-12.1.3-docs.md`. Widgets is the only
major whose minor moved.

## A. Reached the addon on the re-vendor alone (delivered)

- **WidgetsDragHandle minor 4's hook plumbing**: library-internal and latent here. A host that sets
  neither `tooltipPlace` nor `place` gets minor 3's calls in minor 3's order
  (`version-12.1.4-docs.md:44-45`), and this addon builds no drag handle at all.

## B. Host change required

| # | Surface | Evidence | Files it would touch | Blast radius | Recommendation |
|---|---|---|---|---|---|
| B1 | `DragHandle` spec `tooltipPlace(tip, frame)` and tooltip descriptor `place`, both **Since 4** | `version-12.1.4-docs.md:20-46`, `:692`, `:736`, `:756`; CHANGELOG v1.68.0 | none: `grep -rn 'DragHandle\|tooltipPlace' core modules settings` is empty | additive, but there is nothing to add it to | **Decline, not applicable.** The hook belongs to `lib.DragHandle`'s strip, and this addon has no strip. Its one drag surface, unlock mode (`modules/Unlock.lua:204-229`, `U:ArmDrag`), drags the panel frame itself and shows no tooltip (`grep -n 'Tooltip\|OnEnter' modules/Unlock.lua` is empty) |

## C. Whole-module adoption

**`LibKa0s-Widgets-1.0`: settled, not re-offered.** It has no lookup in the addon's own code
(`01_DELTA.md`, *Consumption map*), and its decline is recorded in
[#43](https://github.com/tusharsaxena/PanelMaster/issues/43) (`state:will-not-do`, closed
2026-08-24). That issue names what would reopen it: a new hand-rolled flat dropdown in this addon, or
Widgets growing AceGUI-widget-protocol support, scrolling or per-row previews. v1.68.0 changes none
of those premises; it touches only the drag handle's tooltip.

`Perf` stays declined (ratified, `docs/ARCHITECTURE.md` > *Documented deviations*). `Pool`, `Item`
and `Compat` are untouched by this range.
