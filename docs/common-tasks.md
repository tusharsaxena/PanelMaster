# Common tasks

Recipes for the changes made most often in this addon. Each names real files; where a step has a trap,
the trap is stated rather than implied.

## Add an addon-level setting

A row in `settings/Schema.lua` drives the widget on the **General** page, the
`/pm get|set|list|reset` CLI and the defaults reset at once. Never write a parallel mutator for a
path that already has a row.

1. Add the shipped value to `defaults/Profile.lua`'s settings block (or `defaults/Global.lua` if it
   describes the saved file rather than the character's UI — today only `schemaVersion` qualifies).
2. Add the row to `settings/Schema.lua` at the position you want it rendered. **The position is the
   layout.** `group` is the TAB it lands on (`options-ui-§13`), the array's order is the tab order,
   and consecutive rows are paired two per line — so a row filed under a group the array has already
   left reopens that tab's block further down, which is what the contiguity case in
   `tests/test_schema.lua` exists to catch.
3. Update the **partition case** in `tests/test_schema.lua`: it is the designed page-tab-count table,
   written out by hand rather than derived, so that a row drifting into the wrong tab fails it.
4. **Decide deliberately whether it broadcasts.** A row gets an `onChange` sending
   `Ka0s_PanelMaster_SettingsChanged` only when the change is one **a panel can show**.
   `settings.snapToGrid` and `settings.gridSize` carry none on purpose: `Unlock.SnapPosition` reads
   them live at drag-stop and nothing renders from them, so announcing would repaint every panel on
   each tick of the Grid size slider for no visible difference.
5. Every write goes through `NS.Schema:Set` — already the two-argument shape the library calls with,
   so the panel widget and the slash line take exactly one path.

## Add a field to the panel record

This is the change with the most places to touch, and `core/Constants.lua` is nearly all of them.

1. Add the field to `C.PANEL_TEMPLATE` (`core/Constants.lua:262`) with its shipped default.
2. Add it to `C.PANEL_FIELD_TYPE`, and to `C.PANEL_FIELD_ORDER` (`:504`) at the position it should
   appear in `/pm panel <name>` output and in the editor.
3. Add its media / enum / color map entry if it needs one.
4. Teach `Registry:Sanitize` to validate and clamp it. **Sanitize is the repair path, not just the
   create path** — `Registry:ReloadProfile` sanitizes every record it finds, which is how an incoming
   profile gets per-record repairs without a migration.
5. Teach `Canvas.BuildSpec` to consume it. `BuildSpec` is **pure** — record + settings → exactly what
   the frame should look like, every value already validated and clamped — so the new behavior gets a
   headless test with no frames involved. `applySpec` stays a thin application of the result.
6. If the field should **not** be reachable from the CLI, leave it out of `PANEL_FIELD_TYPE`,
   `PANEL_FIELD_ORDER` and `PANEL_TEMPLATE` — that omission is the mechanism, and
   `core/Constants.lua:550` documents the existing case.

## Add a slash verb

Append one triple to `NS.COMMANDS` (`settings/Slash.lua:273`), shaped
`{ name, description, handler }`. The help index, the settings landing page's command list and the
README table are all generated from it, so nothing else needs editing — regenerate the README with
`/wow-addon:sync-docs`.

A **panel** verb acts on registry records rather than schema rows, so it stays host-owned; a
schema-driven verb can bind to the library's CLI. See [slash-dispatch.md](slash-dispatch.md).

Output follows `slash-commands-§4/§5`: the cyan `[PM]` tag on every line, green headers, azure
`[group]` headers, gold keys, white values, **no trailing colons**. Build the lines into an array and
return it — `Slash:BuildListLines`, `BuildPanelLines` and `BuildPanelShowLines` all do — so the
output shape is asserted in tests without capturing chat.

## Add a bundled artwork entry

1. Prepare the image per [artwork-spec.md](artwork-spec.md) — the folder tree, the naming rules and
   the cleaner are all specified there, and **the `id` is permanent** once shipped.
2. Add the catalog row in `modules/Artwork.lua`. That module is **pure**: it holds the catalog and the
   `BuildArtSpec` geometry — fill math, UV crop/flip/rotation composition, tint resolution — and it
   touches no frames and calls no WoW API. Keep it that way; it is what makes the geometry
   headlessly testable.
3. `modules/Artwork.lua` loads **before** `modules/Canvas.lua`, which reads it. Do not invert that.

For a **Sunn** pack, nothing goes in the catalog by hand: `modules/SunnArtPacks.lua` is the generated
manifest (`tools/sunn/build_manifest.py`, with **measured** section dimensions) and
`modules/SunnArt.lua` synthesizes catalog rows at `OnEnable`. It ships no pack bytes — see
[rendering.md](rendering.md).

## Add a message

Three exist, one sender each, and a test asserts that no other file sends any of them. Before adding
a fourth, check whether the split you want is already served: `PanelsChanged` means *the set changed,
rebuild everything*; `PanelChanged` means *one panel's fields changed, repaint just it*. That split is
what lets a drag repaint one frame instead of all of them.

Consumers register on their **own** target via `NS.NewBusTarget()`. CallbackHandler keys callbacks by
`(message, target)`, so two consumers sharing a target silently clobber each other.

If a caller changes the set N times at once, use the **batch seams** — `Registry:NewBatch(specs)` and
`Registry:DeleteBatch(keys)` mutate N records and broadcast once. Preview mode is the caller that
needed them: standing up three placeholders used to rebuild every consumer three times.

## Add a migration

1. Bump `NS.SCHEMA_VERSION` in `core/Namespace.lua`.
2. Add the step to `NS:RunMigrations` in `core/Database.lua`, gated on the current stamp, idempotent.
3. **Do not call `RunMigrations` from the profile-change callback.** The stamp it gates on lives in
   `db.global`, which is account-wide and already written by `InitDB` before any profile can be
   switched — so a second call could only ever be a no-op, and a no-op that reads as a safety net is
   worse than none. What an incoming profile actually needs is the per-**record** repair, and that is
   `Registry:Sanitize`'s job via `Registry:ReloadProfile`.

## Add a page to the settings UI

`settings/Panel.lua` owns the four page builders and what LibKa0s-Options-1.0 does **not** own: the
open-dropdown registry that closes a list on scroll, the paired-button width, the landing page's body
and the Profiles page. The canvas factory, header, breadcrumb, lazy Defaults button, scroll frame,
scrollbar patch, section headings, spacers, tooltips, the five widget makers, the two-column flow
engine and the **tab strip** are the library's.

A new page is **tabbed** unless it is one of the two `options-ui-§13` exempts (the landing page and
Profiles). A schema-driven page gets its strip from one `H.RenderTabbedSchema` call, which
partitions the rows by `group` in declaration order; a bespoke page draws its own with `H.TabStrip`
and dispatches on `ctx.activeTab`, the way `settings/PanelEditor.lua` does. A control that governs
the whole page rather than one tab belongs in the chrome band, in the page's single `H.PageHeader`
block (`options-ui-§14`) — not under a tab, and not in the scroll.

If you need to change how a field renders, wrap the library member **on the instance** — `RenderField`
and `EnsureScroll` already are — because the flow engine resolves both from the instance table at
call time, so a host-side helper sitting beside them is bypassed by every page it draws.

`AceConfigDialog` is used in exactly one place, the Profiles page. Do not add a second.

## Add a locale string

`locales/enUS.lua` publishes `NS.L` with a metatable whose `__index` returns the key itself, so an
unwrapped string renders as its English source rather than erroring. **Keys are the English source
strings** (`localization-§2`). `locales/PostLoad.lua` holds derived-key aliases and loads after every
locale file, so it reads whatever the active locale resolved. See
[localization.md](localization.md).

## Debug a rendering problem

`/pm debug dump` prints the registry's and the renderer's views of the world side by side, including
orphaned frames. A panel in the registry with no frame — or the reverse — is the shape of **every**
rendering bug this addon can have, so start there. See [debug.md](debug.md).

## Before committing

`lua tests/run.lua` green **and** `luacheck .` clean. Full instructions in [testing.md](testing.md).
