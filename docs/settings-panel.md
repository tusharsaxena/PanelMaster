# Settings panel

The Blizzard-canvas options UI: the four pages, what each covers, and the three widget workarounds
that keep AceGUI usable inside a canvas.

Blizzard `Settings.RegisterCanvasLayoutCategory` + raw AceGUI (`options-ui`). A parent category and
three subcategories:

- **Ka0s Panel Master** (parent) — logo, tagline, the generated slash-command list.
- **General** — the schema rows, in a two-column grid.
- **Panels** — create, edit and delete the panels themselves.
- **Profiles** — AceDBOptions' own options table, rendered by AceConfigDialog into a container
  parented to our canvas.

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

There is deliberately **no heading naming the selected panel** between the dropdown and the editor:
the dropdown already shows which panel is selected, so a heading repeating it was a third band of
chrome between choosing a panel and editing it. The panel selector carries no label either, which
makes it 14px shorter than a labeled control — so a compensating spacer (`LABEL_ROW_H`) sits above
it, or the `Edit` heading would look tighter than every other heading on the page.

The editor opens with a **General** section in decision order — which panel is this (name, and the
option to copy another's look), is it on (Enabled / Unlock), am I done with it (Reset / Delete). The
frame name lives in the name box's **tooltip** rather than as a permanent second label: it is
reference information you need once, when wiring something else up to this panel.

`Registry:CopyFrom` copies every field except `id`, `name` and the four geometry fields. Position is
excluded because the point of copying is to make a panel *match* another while staying where it is —
copying position too would land the two exactly on top of each other. Size **is** copied: matching
dimensions is usually what was wanted, and unlike position it cannot make a panel disappear. Values
are deep-copied, or the two panels would share a color array and editing one would change the other.

`Reset` and `Delete` sit at the **top** of the editor beside `Enabled` and `Unlock`, because that is
where you look once you have decided you are done with a panel. A Delete parked at the foot of a long
scrolling form is one the user only reaches after scrolling past everything they might have wanted to
change instead. `Registry:Reset` restores the whole record from the template plus the profile's
New-Panel-Defaults — the same path `Registry:New` takes, so "reset" and "make a new one" cannot
drift — keeping only `id` and `name`, so the frame name survives and external anchors stay attached.

The editor emits a sequence of full-width **rows** into a `List`-layout group rather than pouring
every widget into one `Flow`. A single Flow reflows controls of differing heights into whatever gaps
it can find, so a checkbox rides up beside a slider's label and two unrelated settings share a line —
which is what made the first version look cluttered. Explicit rows, `Heading`-separated subsections,
and three named gap sizes (`EDITOR_SELECT_GAP` > `EDITOR_SECTION_GAP` > `EDITOR_ROW_GAP`) mean the
spacing itself carries the structure.

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
helpers — the scroll frame, the tooltip attacher, the section heading, the paired-button width and
the open-dropdown registry — published once as the internal `NS.Panel.__ui` and bound on first use,
since the TOC loads the editor *before* the page.

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
