# 02 — Candidates (PanelMaster)

Sources: `git -C ../LibKa0s log --oneline v1.76.0..v1.77.0`, the tag's `CHANGELOG.md` block for
v1.77.0, and the `Since` markers in the tag's `docs/api/` documents for the majors whose minors moved.
The run's ruling makes the re-vendor non-interactive: no interview, no GitHub issue. The one adoption
the run assigns PanelMaster is PM-ZS (`03_DECISIONS.md`); every other candidate is
**deferred (run 2026-10-24)** and nothing is filed.

## Class B (host change required)

- **`O.StrataTooltip(values[, strings])`** (OptionsCompose 8). Options
  `version-30.2.34.3.5.9.2.8.4.2.1.3-docs.md:86-92`, `:1581`, `:2745`. Site: the "Default frame
  strata" row, `settings/Schema.lua:123`, and any other strata row the addon declares. Additive (the
  row gains the shared sentence in place of its own). **Decided: PM-ZS of this run.**
- **The Keybindings tab, `O.KeybindingsTab` / `O.KeybindRows` / `O.KEYBINDS_UNCHANGED`**
  (OptionsKeybinds 2-3). Options `version-30.2.34.3.5.9.2.8.4.2.1.3-docs.md:61-63`, `:1539-1541`,
  `:1821-1994`. PanelMaster ships no `Bindings.xml` and is not one of the seven addons the run gives a
  Keybindings tab, so there is no row to draw. **Deferred (run 2026-10-24).**
- **Kit revision 42's `mock_layers.lua`** (testkit `version-42-docs.md`). Opt-in; the run's ZS items
  install it. **Decided with PM-ZS** if that item's tests use it; otherwise deferred (run 2026-10-24).
- **Kit revision 42's `mock_bindings.lua`, `Kit.assertBindingsXml`, `Kit.keybindThroughTab`.** No
  binding here. **Deferred (run 2026-10-24).**
- **`Core.RaiseStaticPopups()`** (Core 12, `docs/api/Core/version-12-docs.md:394`). PanelMaster owns
  no tool window the library does not already cover. **Deferred (run 2026-10-24).**

## Class A (delivered on the copy)

- DebugLog 21: the debug console is toplevel and re-raises a shown StaticPopup on show.
- Options 30 / OptionsIds 3 / OptionsCombat 2: the IdInput suggestion list closes at combat start
  (no IdInput here, so carried, not seen).
- Widgets 15 / WidgetsAutocomplete 3: the shared dropdown menu and the autocomplete list are clamped
  to screen. The console's copy window, the only Widgets surface the library reaches on this addon's
  behalf, is unchanged.
- PerfPanel 9 and SimPanel 6: toplevel. Carried, not consumed.

## Class C (whole module)

`WidgetsDragHandle` 5's `spec.level`, `ApplyLevel` and `ignoreParentAlpha`
(`docs/api/Widgets/version-15.1.5.3.3-docs.md:39-49`) sit under `Widgets`, a settled decline (#43):
no control in this addon wants it, and `grep -rln DragHandle core modules settings` is empty.
v1.77.0 does not move that premise. **Deferred (run 2026-10-24).** The other settled declines keep their premises: `Pool` #46, `Item` #45,
`Compat` #53, `Perf` ratified; `Sim` still has no simulator to host.
