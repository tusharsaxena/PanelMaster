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
- **Panels** — create, edit and delete the panels themselves; the editor sits under a six-tab strip,
  with the create box and the panel picker pinned in the band **above** it.
- **Profiles** — AceDBOptions' own options table, rendered by AceConfigDialog into a container
  parented to our canvas. The other exempt page, and for the same reason rather than a different
  one: AceConfigDialog draws it whole and it never reaches the flow engine.

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

**Creating a panel and choosing which panel to edit are not tabs, and they are not in the scroll
either.** They sit in the page's **chrome band**, above the strip, in a single `H.PageHeader` block
(`options-ui-§14`). Both apply to every tab, and a control that governs the whole page but is drawn
under one tab reads as belonging to that tab — which is what these two did, as two untabbed
*Create* and *Edit* sections at the top of the scroll.

A page draws **at most one** such block, so the picker goes **inside** it and no `H.PageBanner` is
drawn separately: `PageHeader` and `PageBanner` release the same ledger and reserve the same band,
and two blocks would push the page down twice. The block is not boxed either — the band already has
its own divider and the content panel's top edge below it.

The block is built **once**, on the page's first `OnShow`, and no rebuild releases it. The create box
is the reason: `Registry:New` broadcasts before it returns, so the rebuild lands while the user's own
callback is still on the stack, and releasing the box would hand the widget they are typing into back
to AceGUI's pool. The picker beside it is refreshed **in place** — `SetList` and `SetValue` on the
widget already there — which is the same scalar path every other control on the page takes.

| Page | Tabs | Rows per tab |
|---|---|---|
| General | **Master controls**, **Editing**, **New panels** | 7, 4, 4 — 15 schema rows |
| Panels | **General**, **Position and size**, **Background and border**, **Accent bar**, **Artwork**, **Opacity and fade** | 6, 7, 6, 11, 16, 3 — bespoke controls, not schema rows |
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

The border and bar blocks carry the canonical row sets and order (`options-ui-§16`): **Border style**,
**Border thickness (px)**, **Border color**, **Use class color**, and then this addon's own **Border
offset** *after* them rather than among them; **Bar texture**, **Bar opacity**, **Bar color**, **Use
class color**, then bar thickness and bar offset. **Bar opacity** is a new stored field
(`accentAlpha`) multiplied into the bar color's alpha — the panel-wide opacity could not stand in for
it, because that one fades background, border and bars together.

The panel **background** is not a bar group and takes no opacity row of its own: a group over a
background takes the swatch and its companion, and the alpha in the swatch plus the panel-wide
opacity are already the two controls that decide how solid the fill is.

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
one sender. Without it the previous profile's panels would simply stay on screen.

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
box in the editor below. That is safe because AceGUI's EditBox does **not** commit on focus loss:
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

The editor opens on its **General** tab, in decision order — which panel is this (name, and the
option to copy another's look), is it on (Enabled / Unlock), am I done with it (Reset / Delete). The
frame name lives in the name box's **tooltip** rather than as a permanent second label: it is
reference information you need once, when wiring something else up to this panel.

`Registry:CopyFrom` copies every field except `id`, `name` and the four geometry fields. Position is
excluded because the point of copying is to make a panel *match* another while staying where it is —
copying position too would land the two exactly on top of each other. Size **is** copied: matching
dimensions is usually what was wanted, and unlike position it cannot make a panel disappear. Values
are deep-copied, or the two panels would share a color array and editing one would change the other.

`Reset` and `Delete` sit on the **General** tab beside `Enabled` and `Unlock`, because that is
where you look once you have decided you are done with a panel — and because General is the tab about
which panel this is, rather than about how it looks. A Delete parked at the foot of a long
scrolling form is one the user only reaches after scrolling past everything they might have wanted to
change instead. `Registry:Reset` restores the whole record from the template plus the profile's
New-Panel-Defaults — the same path `Registry:New` takes, so "reset" and "make a new one" cannot
drift — keeping only `id` and `name`, so the frame name survives and external anchors stay attached.

The editor emits a sequence of full-width **rows** into a `List`-layout `SimpleGroup` rather than
pouring every widget into one `Flow`. A single Flow reflows controls of differing heights into
whatever gaps it can find, so a checkbox rides up beside a slider's label and two unrelated settings
share a line — which is what made the first version look cluttered. Explicit rows and three named gap
sizes (`EDITOR_TOP_GAP` > `EDITOR_HEADING_GAP` > `EDITOR_ROW_GAP`) mean the spacing itself carries
the structure.

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
name even though the write landed. `core/LSMPatch.lua` is a further fixup for the same library: it
collapses the `LSM30_Border` widget's 42px preview tile, which otherwise leaves a gap beside the
closed dropdown.

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

Defaults actions differ by page and by destructiveness: **General**'s resets settings only and is
safe behind Blizzard's un-gated footer control; **Panels**' is "delete every panel" (the genuine
stock state of that page) and is therefore confirm-gated behind `KA0S_PANELMASTER_DELETEALL`.
