# Settings panel

The Blizzard-canvas options UI: the four pages, what each covers, and the three widget workarounds
that keep AceGUI usable inside a canvas.

Blizzard `Settings.RegisterCanvasLayoutCategory` + raw AceGUI (`options-ui`). A parent category and
three subcategories:

- **Ka0s Panel Master** (parent) — logo, tagline, the generated slash-command list. One of the
  **two** pages `options-ui-§13` exempts from the strip, and it is exempt because the host draws it
  outside the flow engine: it declares no `group` and names no sections, so there is nothing for a
  strip to be a strip of.
- **General** — the schema rows, in a two-column grid under a three-tab strip.
- **Panels** — create, edit and delete the panels themselves; the editor sits under a six-tab
  strip whose **General** first tab carries everything that acts on the panel as a whole, with the
  picker and the create box on the one row of band **above** it.
- **Profiles** — AceDBOptions' own options table, rendered by AceConfigDialog into a container
  parented to our canvas. The other exempt page, and for the same reason rather than a different
  one: AceConfigDialog draws it whole and it never reaches the flow engine.

## What each page covers

The page-granularity summary, moved here out of the README when documentation-§1 made that section
prose (standard v2.41.0). Open the pages with `/pm config`, or find **Ka0s Panel Master** in the
game's own Settings ▸ AddOns list.

| Page | Covers |
|---|---|
| Ka0s Panel Master | The landing page — the logo, one line on what the addon does, and the same slash-command list `/pm help` prints. |
| General | Every addon-wide setting, under three tabs: **Master controls**, **Editing** and **New panels**. |
| Panels | The panels themselves — make one and choose which to edit from the band at the top, then rename, copy, reset, delete and style the selected one under six tabs: **General**, **Position and size**, **Background and border**, **Accent bar**, **Artwork** and **Opacity and fade**. |
| Profiles | Ace's standard profile management: create, switch between, copy and reset profiles, or bind one per character, class, realm or faction. |

**General** carries these, a tab at a time:

| Tab | Setting | What it does |
|---|---|---|
| Master controls | Enable Ka0s Panel Master | Master switch. Off hides every panel without deleting any. |
| Master controls | General visibility | When your panels are drawn at all: always, only in combat, only out of combat, or never. |
| Master controls | Master scale | Magnifies every panel at once, on top of each panel's own scale. |
| Master controls | Master alpha | Fades every panel at once, on top of each panel's own opacity. |
| Master controls | Lock frame | Ticked (the default) means locked. Unticking gives every panel a drag handle and a name label. Locked again when you reload. |
| Master controls | Debug console | Show the debug window. Resets when you reload. |
| Master controls | Test mode | Put three sample panels on screen. |
| Master controls | Reset position | A button under the tab rather than a setting: puts every panel back in the middle of the screen. Sizes, colors and artwork are left alone. |
| Master controls | Reset all settings | The other button: resets this profile to the addon's defaults — settings **and** panels. It asks first. The same thing `/pm resetall` and the header **Defaults** button do. |
| Editing | Show names while unlocked | Print each panel's name across it while unlocked. |
| Editing | Snap to grid | Round a dragged panel's position to the grid size below. |
| Editing | Grid size | How coarse that grid is, in screen units. |
| Editing | Unlock outline thickness | How thick the gold outline around an unlocked panel is. Raise it if you are hunting for a small panel on a busy screen. |
| Editing | Recover panels | A button under the tab rather than a setting: brings any panel whose anchor has ended up beyond a screen edge back into view. The same thing `/pm recover` does. |
| New panels | Default width, Default height | The size new panels start at. Existing panels are not touched. |
| New panels | Default frame strata | The layer new panels start in. |
| New panels | Default opacity | How see-through new panels start out. |

On **Profiles**, everyone starts on the shared **Default** profile, and switching profiles redraws
your panels immediately.

On **Panels**, type a name in the box at the top and press Enter (or click **Okay**), then pick any
panel from the **Panel** picker beside it to edit it. One panel is shown at a time, so the page stays
the same size whether you have two panels or twenty. The controls, in full:

| Control | What it does |
|---|---|
| Enabled | Draw this panel at all. |
| Unlock | Give **just this panel** a drag handle, without unlocking the rest. |
| Reset | Put the panel back to how a new one starts. Its name and frame name are kept, so anything anchored to it stays anchored. Test mode's sample panels cannot be reset. |
| Delete | Remove the panel. |
| Panel name | Rename the panel. Press Enter, or click Okay. Its tooltip shows the frame name other addons can anchor to — renaming does not change it. |
| Copy settings from panel | Take on another panel's whole appearance. Its position is **not** copied, so this panel stays put. |
| Width, Height, X offset, Y offset | Size and position. |
| Anchor | Which corner or edge of the screen the offsets are measured from. |
| Frame strata | Which layer the panel sits in. |
| Panel scale | Magnifies the whole panel — its size, its border, its accent bars and its artwork — as one piece, the way the game's own UI scale does. Not the same as changing Width and Height: those resize the panel and leave the border and bars at the thickness you set. Width and Height keep showing the numbers you typed; what changes is how big they turn out on screen. A scaled panel is anchored in its own scaled units, so it also shifts relative to its anchor — nudge the offsets afterwards if it matters. |
| Background texture | Any background texture LibSharedMedia knows about, or **None** for no fill. |
| Background color / Use class color | The fill color, or your class color. Its opacity controls the fill alone. |
| Border style | Any border style LibSharedMedia knows about, or **None** for no border. |
| Border thickness (px) | Thickness. Starts at 0 — the accent bar defines the edge instead. |
| Border color / Use class color | The border color, or your class color. The opacity you set applies either way. |
| Border offset | How far the border sits from the panel's edge. Positive pushes it out, negative pulls it in. |
| Enable accent bar | Draw a thin strip along the panel's edges. **On** by default. |
| Bar texture | Any status-bar texture LibSharedMedia knows about. |
| Bar opacity | How solid the bar's own fill is, on top of the opacity in the bar color. |
| Bar color / Use class color | The bar color. Class color is **on** by default. |
| Bar thickness | How thick the bar is. |
| Bar offset | How far the bar sits from the panel. 0 sits flush (the default), positive detaches it, negative overlaps the panel. |
| Edges | Which edges get a bar — Top, Bottom, Left, Right, in any combination. Left and right bars turn the texture a quarter turn, so a bar reads the same way round whichever edge it is on. |
| Border style, Border thickness (px), Border color / Use class color, Border offset (under the *Accent bar* tab's **Border** heading) | The bar's own outline, with the same four controls the panel's border has. Defaults to a 1px black hairline. |
| Panel opacity | How visible the whole panel is — background, border and accent bar together. Multiplies with the opacity in each color. |
| Faded opacity | How visible it is the rest of the time. 0 hides it completely. Sits beside *Panel opacity*, because you choose one against the other. |
| Show on mouseover only | Keep the panel faded until your cursor is over it. |
| Defaults (the page's own button, not the editor's) | On the **Panels** page this means *delete every panel* — your settings are left alone. It asks first, and nothing goes until you say yes. |

**Two opacities, and they do different things.** Each color carries its own opacity, which affects
only what that color paints — so you can have a see-through fill inside a solid border. **Panel
opacity** is on top of that and fades the whole panel at once, and it is the level a mouseover panel
fades *up* to.

## The tab strip

Both of this addon's own pages are **tabbed** (`options-ui-§13`). A tab is pinned in the page's
chrome band, above the scroll, and only the active tab's controls are built — so a page is one
subject at a time rather than a column you scroll.

The two pages get there by different routes, because their content is not the same kind of thing:

- **General** is schema-driven, so `H.RenderTabbedSchema` does the work: it partitions
  `settings/Schema.lua`'s rows by `group`, **in declaration order**, and draws one tab per distinct
  group. The array's order *is* the strip's order, and a group's rows must stay contiguous.
- **Panels** is bespoke — a panel is a registry record, not a row with a path — so there is nothing
  for `RenderTabbedSchema` to partition. `settings/PanelEditor.lua` draws the strip directly with
  `H.TabStrip` over its own ordered `EDITOR_TABS` list, and dispatches on `ctx.activeTab` to one
  section builder per tab.

**Nothing that acts on the panel as a whole is in the scroll, and only one row of it is in the
band.** Creating a panel and choosing which one to edit are the band's two controls, in a single
`H.PageHeader` block; naming it, copying another's look onto it and the four acts — Enabled,
Unlock, Reset, Delete — are the strip's **`General` first tab** (`options-ui-§14`). Every one of them
applies to the panel whole rather than to one aspect of it, and a page-wide control drawn under a
*subject* tab reads as belonging to that tab and vanishes the moment the player clicks another —
which is exactly why `General` has to be **first**: the tab the page opens on is where the player
already is. The shape both arrangements replace is the original one, where *Create* and *Edit* were
untabbed sections at the top of the scroll.

A page draws **at most one** such block, so the picker goes **inside** it and no `H.PageBanner` is
drawn separately: `PageHeader` and `PageBanner` release the same ledger and reserve the same band,
and two blocks would push the page down twice. The block is not boxed either — the band already has
its own divider and the content panel's top edge below it.

The block is built **once**, on the page's first `OnShow`, and no rebuild releases it. The create box
is the reason: `Registry:New` broadcasts before it returns, so the rebuild lands while the user's own
callback is still on the stack, and releasing the box would hand the widget they are typing into back
to AceGUI's pool. Everything beside it is refreshed **in place** — `SetList` and `SetValue` on the
widget already there — which is the same scalar path every other control on the page takes.

**Built once is also why the block re-lays itself out on `OnSizeChanged`.** `ctx.chrome` is zero-wide
until the settings canvas has laid itself out, and the **first page a player opens is rendered before
that happens** — the library documents this at its own `replaceOnResize`, which is how the tab strip
heals when the width arrives. Every control here takes a **relative** width, so a layout run at that
moment gives each of them a fraction of nothing: controls that exist, are shown, and occupy no
pixels. The band keeps its reserved height, so the page draws an **empty strip of chrome above the
tabs** with everything in it simply gone. The strip heals; this block, built once for the
session, never got a second chance — a session that happened to open Panels first stayed that way
until a `/reload`. The hook goes on the **header frame**, not on `ctx.chrome`, whose `OnSizeChanged`
the library has already claimed for the strip (`SetScript` replaces, so hooking there would trade
this bug for a strip that never re-wraps), and it answers only a **change** in width because
`SetChromeHeight` fires the same script.

| Page | Tabs | Rows per tab |
|---|---|---|
| General | **Master controls**, **Editing**, **New panels** | 7, 4, 4 — 15 schema rows |
| Panels | **General**, **Position and size**, **Background and border**, **Accent bar**, **Artwork**, **Opacity and fade** | 6, 7, 6, 11, 16, 3 — bespoke controls, not schema rows. `General` carries the six page-wide acts and is **first**, which is what `options-ui-§14` requires of the escape it grants (standard v2.40.0); the chrome band keeps the picker and the create box, one row. |
| Profiles | none | AceDBOptions' own page |

A **color** is one control in those counts even though it emits two widgets (the swatch and its
*Use class color* companion), and the accent bar's **Edges** is one control holding four checkboxes.

### The Master controls tab

The General page's **first** tab, named exactly that, and it is **composed** rather than declared
(`options-ui-§15`): `settings/Schema.lua` calls `LibKa0s-Options-1.0`'s `MasterControls` and splices
what it returns at the head of the row array. The set, the order, the labels and the ranges are the
library's, so nine addons cannot drift into nine versions of the same tab.

| | |
|---|---|
| Enable Ka0s Panel Master | General visibility |
| Master scale | Master alpha |
| Lock frame | Debug console |
| Test mode | |
| *Reset position* | *Reset all settings* |

The last row is the group's closing **button pair**, drawn by the `afterGroup` hook the composer
returns beside the rows. The group name *is* the hook's key, so `settings/Panel.lua` reads it off
the composed rows rather than writing the literal out again — a key that disagreed would detach the
hook silently and the tab would simply have no buttons.

Four of these are new, and each is honored by drawing code rather than merely declared:

- **General visibility** — `Always` / `Only in combat` / `Only out of combat` / `Never`, honored in
  `Canvas.VisibilityShows` and folded into `spec.shown`. There was no *show only in combat* boolean
  here to migrate: the addon never shipped one, so `always` is both the default and what every
  existing profile already meant.
- **Master scale** and **Master alpha** — addon-wide **multipliers** over each panel's own scale and
  opacity, applied in `Canvas.BuildSpec`. They are deliberately not the same settings as the
  per-panel ones on the Panels page: the editor's sliders keep showing what the player typed for
  that panel, and these two move all of them together. Both ship at 1, the identity.
- **Reset position** — `Registry:ResetPositions`, which puts every panel's anchor back where a new
  one starts and reports how many moved. The **anchor only**: a button labeled *Reset position* that
  also reset an evening's worth of sizing would be doing something its own label did not warn about.

**Lock frame** is the old *Unlock panels* switch, moved here and **un-inverted**. It stays
session-only — unlocking is an editing mode, not a preference, and a player who unlocks, drags a
panel and reloads comes back to a locked UI, which is what this addon has always done. There is no
stored value behind it, so the sense change is not a migration; the negation is pinned in both
directions in `tests/test_schema.lua`.

**Test mode** is *not* canonical. It is this addon's own, and it rides the composer's `extra`, which
appends after the mandated block and never interleaves with it.

**Reset all settings** is `options-ui-§12`'s global reset, verbatim and confirm-gated, and it is the
same entry point the header **Defaults** button and `/pm resetall` already share — `Sl:ConfirmResetAll`.
Deleting every panel stays the separate, separately-confirmed act it was, on the Panels page's own
Defaults button behind `KA0S_PANELMASTER_DELETEALL`.

### Subsection headings

Three of the Panels page's tabs mix more than one kind of control, and each says where one stops and
the next starts (`options-ui-§7`) — the same AceGUI `Heading` widget every other header in the
collection uses, drawn into the editor's own container because the library's `O.Section` emits into
the page's scroll:

| Tab | Headings |
|---|---|
| Background and border | **Background**, **Border** |
| Accent bar | **Bar**, **Edges**, **Border** |
| Artwork | **Image**, **Layout**, **Appearance** |

The **Edges** one replaces a hand-rolled gold `|cffffd100Edges|r` Label that stood in for a heading,
which is anti-pattern #71. The *Background and border* merge is not undone by the rule — it is
argued for above, and what the rule adds is the pair of headings inside it.

The border and bar blocks are **composed** (`options-ui-§16`): `O.BorderGroup` for the panel's border
and again for the accent bar's own border, `O.BarGroup` for the accent bar, each with `spec.bind`
over the panel record ([#48](https://github.com/tusharsaxena/PanelMaster/issues/48)). So each carries
the canonical row set and order: **Border style**, **Border thickness (px)**, **Border color**, **Use
class color**, and then this addon's own **Border offset** *after* them rather than among them; **Bar
texture**, **Bar opacity**, **Bar color**, **Use class color**, then bar thickness and bar offset.
**Bar opacity** is a stored field of its own (`accentAlpha`) multiplied into the bar color's alpha.
The panel-wide opacity could not stand in for it, because that one fades background, border and bars
together.

The panel **background** is not a bar group and takes no opacity row of its own: a group over a
background takes the swatch and its companion, and the alpha in the swatch plus the panel-wide
opacity are already the two controls that decide how solid the fill is.

**How the page composes blocks it cannot put in a schema.** A panel is a registry record with no
`path`, so these rows are not settings. The composers take a `bind` in place of a path: the
record-backed arm LibKa0s v1.31.0 added for this page (OptionsCompose minor 4, read by OptionsWidgets
minor 15). One bind serves all three blocks. It reads the live record by id, writes through
`NS.Registry:Set` like every other control on the page, and converts colors between the record's
`{ r, g, b, a }` arrays and the named keys the library's codec reads. The rows are drawn two to a line
with `O.RenderField` into the editor's own rows and never enter `NS.Schema.Schema`, so the CLI keeps
reaching these fields through `/pm panel <name> set`.

Composed rows are plain tables, and the page retunes them before drawing so a player sees what the
typed-out blocks showed: this page's own tooltips, the media lists from `NS.Compat.MediaList` (with
this addon's `None` and `Solid`, in that order), the Constants ranges (a border here reaches 32 px, not
the composer's 16), and **Bar opacity** as a 0–1 ratio rather than a percentage. Two things follow the
library rather than the old code, because no row field can express them. A composed swatch keeps its
label while its companion is ticked instead of gaining a gray `(opacity)` suffix; its tooltip already
says the alpha still applies, in `O.CLASS_COLOR_NOTE`'s words. And a live color drag commits through
the library's 50 ms throttle. The two swatches still drawn by hand, **Background color** and
**Artwork color**, follow the composed ones: no swatch on the page carries the suffix (owner's
decision, 2026-09-12), and every swatch's tooltip says the opacity still applies.

The library-less stub in `settings/OptionsSetup.lua` answers `BorderGroup` and `BarGroup` with an
empty row list, so a degraded install draws none of the three blocks rather than raising, which is
`options-ui-§1`'s ruling for composed content. `tests/test_options_groups.lua` holds the result: no
hand-written block on the page, the three composer calls bound, no `options-ui-§16` row in
`ARCHITECTURE.md` ▸ *Documented deviations*, and a control-by-control characterization of what the
composed blocks draw and write.
The **General** page has no color, font, border or bar row at all, so `§16` does not engage there.

The class-color intent `options-ui-§17` requires per control is declared in `C.COLOR_CLASS_SOURCE`,
one entry per color. The three composed swatches also carry it on their rows (`classColor = { source =
C.COLOR_CLASS_SOURCE.<field> }`, stamped as `classColorSource`); the two hand-drawn ones have no row, so
the map is their only declaration. All five entries are
`"player"` — a panel is chrome and tracks no unit — and the map is what an audit reads.

Counts come from `settings/Schema.lua` and `settings/PanelEditor.lua`, and are pinned by the
partition cases in `tests/test_schema.lua` — which are written out as the *designed* table rather
than derived from the schema, because an expectation derived from the schema agrees with any
arrangement of rows, including one where a row has drifted into the wrong tab.

Three names changed with the strip, and all three for the same rule — a tab is named for its
subject, not for its drawer:

- **New Panel Defaults → New panels.** Every row on it already says "Default".
- **Background + Border → Background and border.** Two subsections of two and four controls; the
  fill and the edge are two halves of one question, and a two-control tab is not a subject.
- **Visibility → Opacity and fade.** Its three controls are two opacity sliders and a mouseover
  switch. The old name promised the where/when rules of a visibility engine this addon has not got.

  The two sliders **share a row** and the switch sits **alone below them**. They are the same
  question asked twice — how visible, and how visible while the cursor is elsewhere — on the same
  `0..1` scale, so one is chosen against the other and they belong side by side. The switch decides
  whether the second is consulted at all; beside a slider it reads as governing *that* slider, and
  on its own line it governs the line above, which is what it does. It was the other way round:
  *Panel opacity* alone, then *Faded opacity* paired with the checkbox.

**Unlock panels** left the Editing tab in the settings-revamp pass and is `Lock frame` on Master
controls now. The four rows it used to lead still only mean anything while the panels are unlocked,
which was the argument for putting it there — what changed is that the canonical set is not a menu
to take the convenient half of.

Profiles is the **one** place `AceConfigDialog` is used. `anti-patterns` forbids it for content and
carves out Profiles explicitly, and the carve-out earns itself: AceDBOptions returns a complete,
correct table for create / switch / copy / reset / delete plus the per-character, class, realm and
faction scopes, and a hand-rolled AceGUI equivalent would be a large pile of code whose only
distinguishing feature would be its own bugs. It has no Defaults button — the page already carries
its own destructive controls, and a second "reset" meaning something else would be a trap. Both libs
are `OptionalDeps`, so their absence means no Profiles page rather than a broken one.

Switching profile swaps `db.profile` wholesale, so `core/Database.lua` registers AceDB's
`OnProfileChanged` / `OnProfileCopied` / `OnProfileReset` callbacks and delegates to
`Registry:ReloadProfile` — in the registry rather than the database so `PanelsChanged` keeps exactly
one sender. Without it the previous profile's panels would simply stay on screen. Each event is
logged once, by its own handler: `[Set] reset profile '<name>' to defaults (N rows)`,
`[Set] copied profile '<src>' → '<dst>'`, or the `[Profile] switched to …` trace
(`debug-logging-§10`; `docs/debug.md` has the table).

The reload does **not** re-run migrations, and `core/Database.lua` says why: the schema stamp lives
in `db.global`, which is account-wide and already written by `InitDB` before any switch can happen,
so a second call could only be a no-op. What an incoming profile actually needs is the per-record
repair, and the reload re-sanitizes every record it finds — an incoming profile may predate the
current build, or have been copied from one that did.

**It also drops every session table keyed by panel id, before it sanitizes or broadcasts.** Ids are
allocated per profile (`nextID` lives in `db.profile` and a fresh profile starts at 1), so an id held
across a switch is not stale-but-harmless — it is a live reference to a *different* panel. Four
things held one: `NS.State.previewIDs` (the destructive case — `/pm preview` off called
`DeleteBatch` with the outgoing profile's ids, which resolve against the incoming one and destroyed
real panels), `NS.State.preview` itself, `NS.State.unlockedPanels`, `NS.Unlock`'s deferred
`pendingPanels` (via `Unlock:ForgetPending`), and the Panels editor's own selection (via
`PanelEditor:ForgetSelection`). The global unlock flag is deliberately kept: it is a mode the user
put the screen in, not a claim about any particular panel.

The Panels page shows **one** panel's editor at a time, chosen from a dropdown. Stacking every
panel's editor grew past a screen at three panels and past a scrollbar's usefulness at ten, and
rebuilding all of them on every create or delete is exactly the O(N) teardown `options-ui-§11`
exists to prevent.

Creating a panel is committed by the EditBox's own **Okay** button, the same gesture as the rename
box on the `General` tab. That is safe because AceGUI's EditBox does **not** commit on focus loss:
`OnEnterPressed` is fired only by the Enter key, the Okay button and a drag-receive, and
`OnEditFocusLost` is never registered at all. (An earlier version added a separate Create button on
the mistaken assumption that tabbing away would create a panel.)

There is deliberately **no heading naming the selected panel** above the editor: the picker in the
band already shows which panel is selected, so a heading repeating it was a third band of chrome
between choosing a panel and editing it. The picker carries a **label** now (`Panel`), which it did
not when it sat under an *Edit* section heading that said what it was for; in the band there is no
heading above it, and an unlabeled dropdown beside a labeled edit box reads as a control that lost
its caption. The `LABEL_ROW_H` spacer that compensated the unlabeled control went with the heading.

**Zero panels is a state of the page, not a different page.** The strip is drawn first and always,
and the empty state is a line of content underneath it. It used to be the other way round — the band
was released and the strip taken down when the registry was empty — which is the conditional
no-strip state `options-ui-§13` forbids, and which is no longer survivable anyway: the only control
that can make a panel now lives in that band.

### One row of band, and a `General` first tab

The band above the strip is **one row** of two controls, and both stay put on every tab:

| Row | Controls |
|---|---|
| 1 | **Panel** (the picker), **Create new panel** |

Everything else that acts on the panel whole is the strip's first tab, **General**, in three rows
of two:

| Row | Controls |
|---|---|
| 1 | **Panel name**, **Copy settings from panel** |
| 2 | **Enabled**, **Unlock** |
| 3 | **Reset**, **Delete** |

**That tab existed, was deleted, and is back — and the standard moved first both times.** Under the
v2.38.0 wording of `options-ui-§14`, every control applying to all of a page's tabs had to sit above
the strip, so the six acts went into the band and the tab went with them. The deletion was correct
against the rule; the rule was wrong about a page this size. Six acts stacked into the band made a
second page above the page, pushing the strip and everything under it down for controls a player
touches once a session, and the four bare ones ended up quarter-width — reported from the game as
hard to parse, and it was. Standard v2.40.0 bounds the band at **one row** carrying the identity
controls and lets a page's remaining page-wide acts move to a first tab named `General`, on the
condition that carries the whole argument: a page-wide control under a tab is hidden, and a
page-wide control on the tab the page *opens* on is simply where the player already is.

**A pair per row is the point of the move rather than a detail of it.** Three rows of two is the
shape every other row on this page uses; four acts sharing one band row is what made them
quarter-width. `LibKa0s-Options-1.0` still names this exact set at `O.PageHeader` — *creating the
thing the page edits, choosing which one is being edited, and the acts that apply to it whole
(enable, unlock, copy, reset, delete) are all page-wide* — and the split here is between the first
two, which stay in the band, and the rest, which do not.

**The name box travels with the acts.** Leaving it in the band would put the create box and the
rename box in two different places and leave `General` a five-control tab; it belongs with them on
the merits as well, since a panel's name is its identity and is what the picker in the band
displays. The frame name stays on the name box's **tooltip** rather than becoming a second label: it
is reference information you need once, when wiring something else up to this panel.

**The acts are rebuilt per selection, which is why the band's re-pointing machinery is gone.** While
they lived in the chrome band they were built ONCE for the session, so every callback had to resolve
the record fresh through `currentRecord()`, a `refreshHeaderActs` pass had to push every value back
in place on each rebuild, and the rename box needed a `dressNameBox` guard against being overwritten
while the user was mid-edit — machinery nothing else on this page needed. On the `General` tab they
are built against the `rec` the editor already holds, so acting on the right panel is true by
construction, so `refreshHeaderActs` and the `dressNameBox` guard were deleted rather than moved.
`currentRecord()` survives — `settings/PanelEditor.lua:77`, called at `:1328` — because the page
rebuilder still needs it; it is the two band-only helpers that went. **Enabled** keeps a refresher, and it is
the only one that needs one: `/pm panel <name> enabled false`, a Reset and a CopyFrom all broadcast
`PanelChanged` without rebuilding, so the checkbox has to follow.

With no panel selected the acts are **absent rather than disabled**, which is the opposite of what
the band did and is correct for a tab: there is no record for them to act on, and the empty state is
what the editor draws in their place. The band keeps the picker and the create box in every state,
including an empty registry — releasing them would take the only control that can make a panel off
the screen at the moment the player needs it most. The picker is **disabled rather than removed**
when there is nothing to pick, so it does not take its label with it and leave a hole in the band.

`Registry:CopyFrom` copies every field except `id`, `name` and the four geometry fields. Position is
excluded because the point of copying is to make a panel *match* another while staying where it is —
copying position too would land the two exactly on top of each other. Size **is** copied: matching
dimensions is usually what was wanted, and unlike position it cannot make a panel disappear. Values
are deep-copied, or the two panels would share a color array and editing one would change the other.

`Reset` and `Delete` close the `General` tab's third row, under `Enabled` and `Unlock`, because the
two irreversible acts belong together and because "am I done with this panel" is not a question
about how it looks. A Delete parked at the foot of a long scrolling form is one the user only
reaches after scrolling past everything they might have wanted to change instead — and a Delete
under one of the five *subject* tabs is one they have to go looking for.
`Registry:Reset` restores the whole record from the template plus the profile's
New-Panel-Defaults — the same path `Registry:New` takes, so "reset" and "make a new one" cannot
drift — keeping only `id` and `name`, so the frame name survives and external anchors stay attached.

The editor emits a sequence of full-width **rows** into a `List`-layout `SimpleGroup` rather than
pouring every widget into one `Flow`. A single Flow reflows controls of differing heights into
whatever gaps it can find, so a checkbox rides up beside a slider's label and two unrelated settings
share a line — which is what made the first version look cluttered. Explicit rows and three named gap
sizes (`EDITOR_TOP_GAP` > `EDITOR_HEADING_GAP` > `EDITOR_ROW_GAP`) mean the spacing itself carries
the structure. **The `General` tab is built the same way and for the same reason**: three explicit
`Flow` rows of two, not one Flow with six children in it — the bare checkboxes and buttons would
otherwise ride up beside the labels above them. The band's single row is a `List` block for the same
reason it is a block at all: it has to be reachable to be re-laid out when the canvas width arrives.

That container was a **titleless `InlineGroup`**, and the box is what changed rather than the layout.
The editor sits under a strip whose content panel already draws a boundary around the whole page, so
a second bounded box inside it was a border stating a boundary the page already states
(`options-ui-§14`, anti-pattern #72). `EDITOR_TOP_GAP` exists because that box contributed an inset of
its own — an empty title bar plus padding, near twenty pixels — and with it gone the gap is stated
rather than inherited from a widget that happened to have one. `EDITOR_SELECT_GAP` went the other
way: it spaced the panel dropdown from the editor, and the picker is in the band now.

#### Three widget workarounds

All three are live-client-only and none can be caught by the headless suite, which stubs AceGUI out.

**`AceGUI-3.0` ColorPicker (v28) does not reliably fire `OnValueConfirmed`.** Its `ColorCallback` is
invoked twice — once from `swatchFunc` (`isAlpha` nil) and once from `opacityFunc` (`isAlpha` true) —
and both read the *same* `GetColorRGB`/`GetColorAlpha`. The first call applies the color and returns
via the `IsVisible()` branch; the second hits the function's own "no change, skip update" guard and
returns **before** reaching the `OnValueConfirmed` fire. So changing a color without touching the
opacity slider — the overwhelmingly common case — fires `OnValueConfirmed` never. The widget's own
swatch still updates, because it calls `SetColor` on itself first, which is why the symptom was "the
swatch is the color I picked but the panel is unchanged". Both color pickers therefore bind
**`OnValueChanged` as well**, which fires while the picker is open and gives a live preview besides.

**`AceGUI-3.0-SharedMediaWidgets` fire `OnValueChanged` without calling `SetValue` first**, because
upstream assumes AceConfigDialog re-renders the whole panel afterwards. This is a canvas panel that
does not, so each callback pushes the value back explicitly or the dropdown keeps displaying the old
name even though the write landed. There is a further fixup for the same library, and it is no longer
this addon's: `lib.__PatchLSM30Border()` (`LibKa0s-Options-1.0` minor 15, called once from
`settings/OptionsSetup.lua`) collapses the `LSM30_Border` widget's 42px preview tile, which otherwise
leaves a gap beside the closed dropdown. It lives in the library because AceGUI's widget registry is
process-global — one slot every addon in the client shares — so five Ka0s addons each fixing it
privately meant the last one loaded owned the dropdown for all of them.

**An open dropdown does not follow, or close with, a scrolling page.** AceGUI parents a dropdown's
open list to `UIParent` so it can overflow the panel, which means scrolling slides the control away
while its list stays floating where it was — frequently outside the settings window entirely. Nothing
in AceGUI closes it, so the page tracks every dropdown it builds (`trackDropdown`) and closes the
open one on any **user-driven** scroll. Tracking lives on the **render context** (`ctx.dropdowns`),
one registry per page: a single file-level list meant the Panels page's rebuild emptied the General
page's tracking too, after which scrolling General left its open list floating.

Closing dispatches on the widget's **`type`**, never on which fields it happens to carry. A stock
AceGUI `Dropdown` also has a `.dropdown` field — its Blizzard `UIDropDownMenuTemplate` frame — so an
earlier field-presence check handed that frame to the SharedMedia library's pool-return, which
iterates a `contentRepo` a Blizzard frame does not have. The error propagated out of `MoveScroll` and
killed mouse-wheel scrolling on the whole page. A unit test pins the dispatch against hand-built
widget stand-ins, since the headless harness builds no real widgets.

The two scroll hooks: the `MoveScroll` override (the wheel path) and the
scrollbar's `OnMouseDown` (the drag path). `OnMouseDown` rather than the slider's `OnValueChanged`,
because that also fires from `FixScroll`'s own `SetValue` during layout — and opening a dropdown
triggers a relayout, so closing there would shut it the instant it opened. The registry is emptied at
the top of each rebuild, since AceGUI offers no per-widget "you were released" callback.

The **category is registered eagerly** at `OnInitialize` so the entry is always in the options list;
each **body is built lazily** on first `OnShow`, because AceGUI lays out against a width that is 0
until then. The header **Defaults button is also built in the first `OnShow`** (`options-ui-§5`,
anti-pattern #42): AceGUI is shared and UI skins restyle it by hooking `RegisterAsWidget`, so a
widget created during load is a race against every other addon's load order and can be left on
Blizzard's stock red art for the session.

The Panels page is the structural one — its content depends on how many panels exist — so it lives
behind `rebuilders` and repaints only on first paint, on an on-screen change, or on the next
`OnShow` after an off-screen one (`options-ui-§11`), never on every `OnShow`.

Its body lives in `settings/PanelEditor.lua`, a sibling in the same folder (`layout-§1`): the editor
was by far the largest thing in `settings/Panel.lua` and shares none of the page chrome around it.
`P:Register` wires the bus (`E:WireBus`) at registration and the page's `OnShow` calls `E:BuildPage`
then `E:Rebuild`, so the lazy-build contract is unchanged. The editor draws with the page's own
helpers — the scroll frame, the tooltip attacher, the heading height, the paired-button width and
the open-dropdown registry — published once as the internal `NS.Panel.__ui` and bound on first use,
since the TOC loads the editor *before* the page. `section`, `addSpacer` and `ROW_VSPACER` left that
table with the *Create* and *Edit* sections: `O.Section` emits into the page's **scroll**, and the
editor's headings go into its own container so a rebuild can release the editor without taking the
rest of the page with it. `SECTION_HEADING_H` arrived in their place, so the editor's heading is the
library's number rather than a host copy of it (`options-ui-§8`).

It has exactly **two** triggers, both on the bus, and no widget callback rebuilds the page itself:

| Message | Meaning | Response |
|---|---|---|
| `MSG_PANELS` | the SET of panels changed (create, delete, rename, profile switch) | `O.RefreshPanel(ctx, true)` — structural, so one rebuild |
| `MSG_PANEL` | one field of one panel changed (CLI, drag, `Reset`, `CopyFrom`) | `O.RefreshPanel(ctx, false)` — the open editor's per-control `refreshers`, in place; never a rebuild (anti-pattern #39) |

Both go through the **library's** per-page refresh (LibKa0s `Options` minor 8), which owns the
shown/hidden decision: an on-screen page repaints now, a hidden one is flagged and repaints on its
next `OnShow`. This file used to hand-roll that branch and marked `ctx.dirty` — one underscore away
from the `ctx._dirty` the library's `OnShow` gate actually reads, so the flag was written in four
places and read in none. A profile switch happens while the user is on the *Profiles* page, i.e.
with the Panels page hidden, so the deferred repaint never landed and the page kept the widget tree
it had built for the previous profile: its dropdown, its copy-from list and its editor all listed
panels that were no longer in the registry, while the panels themselves had correctly left the
screen. Nothing here writes `_dirty` any more.

`MSG_PANEL` returns early unless the id is the one the editor is showing. A mutating control sets the
selection *before* it mutates, so the single rebuild lands on the right panel; the create box, whose
id does not exist yet, parks the new panel's **name** in `ctx.pendingSelect` and the bus handler
resolves it. A rebuild clears `ctx.refreshers` first, since every closure in it holds a widget the
rebuild is about to release. The color-picker refresher uses `SetColor`, which fires no callback and
therefore cannot re-enter `Registry:Set`.

Defaults actions differ by page, and **both are destructive now**: **General**'s is the shared
profile reset described above (`Sl:ConfirmResetAll`, behind `KA0S_PANELMASTER_RESETALL`), so the
player's panels go with the settings; **Panels**' is "delete every panel" (the genuine stock state of
that page), behind `KA0S_PANELMASTER_DELETEALL`. Blizzard's own un-gated footer control forwards to
the same closure on each page through `O.CreatePanel`'s `OnDefault`, so the footer and the header
button are one implementation and the confirmation cannot be reached round.

**The General page's Defaults tooltip still reads *"Your panels are untouched"*, and so does the
comment above `ctx.panel.defaultsOnClick` (`settings/Panel.lua:365`, `:372`).** Both predate
`options-ui-§12` turning `resetall` into a profile reset and neither matches what the button now
does. That is a code fix, not a doc one, and it is recorded here so the next reader does not take
the tooltip for the contract.
