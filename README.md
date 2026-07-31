# Ka0s Panel Master

![WoW](https://img.shields.io/badge/WoW-Midnight_12.0.7-purple)
![License](https://img.shields.io/badge/License-MIT-orange)
[![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)](https://github.com/tusharsaxena/WowAddonStandards)
![Tests](https://img.shields.io/badge/Tests-471%2F471_passing-green)

<!-- The repo-relative path renders on GitHub today. At first publish this can be swapped for the
     CurseForge CDN URL, which also renders on the project page. The .tga beside it is the asset the
     addon actually loads in-game — WoW cannot read .png or .jpg at runtime. -->
![Logo](media/logos/panelmaster.logo.256.jpg)

Ka0s Panel Master draws plain backdrop panels behind your UI, so a screen full of separate frames
reads as a few deliberate groups.

That is all a panel is: a rectangle with a color, a border and a position. It sits **behind**
everything, it holds nothing, and it never moves or touches any of your other frames. Your action
bars, your chat window and your unit frames stay exactly where their own addons put them — the panel
is just the backdrop they sit on.

If you have used kgPanels, or the panels built into ElvUI, this will feel familiar.

Make one with `/pm new`, unlock the screen with `/pm unlock`, drag it where you want it, then `/pm
lock`. Everything else lives in the settings panel or under `/pm config`.

## What's new in 0.1.0

- First release.
- Create as many backdrop panels as you like, each with its own size, position, textures, colors,
  border and frame strata.
- Pick any background and border texture you have installed — anything that uses LibSharedMedia
  shares its textures with Panel Master.
- Class-color a panel's background or border with one tick, and it follows whoever you log in as.
- Show a panel only when your cursor is over it, faded to whatever opacity you like the rest of the
  time — without it ever swallowing a click.
- Offset the border away from the panel's edge for a halo, or inward for an inset frame.
- **Accent bars** — a thin strip along any edge of a panel, in the style of BenikUI's panels. On
  out of the box, class-colored, with any status-bar texture you have installed.
- Unlock everything at once, or just the one panel you are editing, with a gold outline, a name
  label, a drag handle and optional snap-to-grid.
- Every panel gets a fixed frame name like `PanelMaster_Panel_Chat_BG`, so other addons can anchor
  to it.
- Test mode drops three sample panels on screen, so you can see what a panel looks like before
  making one of your own.
- Full command-line control: create, rename, delete and edit any field of any panel from `/pm`.
- Copy one panel's whole look onto another in a single click — everything except where it sits.
- Every character shares one layout out of the box, with a **Profiles** page for giving a character
  its own — create, switch, copy and reset profiles.

## Screenshots

<!-- Captured at first release and served from the CurseForge CDN, per .pkgmeta (media/screenshots is
     not shipped to players). -->

*Screenshots are added with the first published release.*

## Usage

### Slash commands

`/pm` is the command; `/panelmaster` does the same thing. Running `/pm` on its own lists everything
below.

| Command | What it does |
|---|---|
| `/pm config` | Open the settings panel |
| `/pm new name` | Create a panel |
| `/pm delete name` | Delete a panel |
| `/pm rename old new` | Rename a panel |
| `/pm panels` | List your panels |
| `/pm panel name [field] [value]` | Look at, or change, one panel. `/pm panel deleteall` removes every panel |
| `/pm unlock` | Show every panel with a drag handle |
| `/pm lock` | Put them back to normal |
| `/pm preview` | Toggle three sample panels |
| `/pm recover` | Bring off-screen panels back into view |
| `/pm version` | Print the version you are running |
| `/pm get setting` | Read a setting |
| `/pm set setting value` | Change a setting |
| `/pm list` | List every setting |
| `/pm reset setting` | Put one setting back to normal |
| `/pm resetall` | Put every setting back to normal (your panels are kept) |
| `/pm debug` | Show the debug window. `/pm debug on`/`off` turns logging on and off, `/pm debug dump` writes a state dump into the log |
| `/pm help` | Show this list |

The fields you can change on a panel are `name`, `enabled`, `width`, `height`, `point`, `relPoint`,
`x`, `y`, `strata`, `level`, `alpha`, `bgTexture`, `bgColor`, `bgClassColor`, `borderTexture`,
`borderSize`, `borderOffset`, `borderColor`, `borderClassColor`, `mouseover`, `mouseoverAlpha`,
`accentEnabled`, `accentEdges`, `accentTexture`, `accentThickness`, `accentOffset`, `accentColor`,
`accentClassColor`, `accentBorderTexture`, `accentBorderSize`, `accentBorderOffset`,
`accentBorderColor` and `accentBorderClassColor`. So:

```
/pm panel ChatBG width 420
/pm panel ChatBG bgColor 0.1,0.1,0.12,0.8
/pm panel ChatBG bgTexture blizzard marble
/pm panel ChatBG borderClassColor on
/pm panel ChatBG strata LOW
/pm panel ChatBG accentEnabled on
/pm panel ChatBG accentEdges top,left
```

Colors take either `r,g,b` or `r,g,b,a`, in 0–1 or 0–255 — `1,0,0,0.5` and `255,0,0,128` both mean
half-transparent red. Texture names are whatever LibSharedMedia has, and are matched however you
type the capitals. `accentEdges` takes a comma list of `top`, `bottom`, `left`, `right` — or `none`
for no bars at all.

### Anchoring other things to a panel

Every panel has a fixed frame name built from its own name: `PanelMaster_Panel_` followed by the
panel name with anything that is not a letter or number turned into an underscore. A panel called
**Chat BG** is `PanelMaster_Panel_Chat_BG`. The settings page shows you the exact name.

Other addons can anchor to that name:

```lua
myFrame:SetPoint("TOPLEFT", "PanelMaster_Panel_Chat_BG", "TOPLEFT", 4, -4)
```

Renaming a panel changes its frame name, so anything anchored to the old one stops following it.

### Settings panel

| Setting | What it does |
|---|---|
| Enable panels | Master switch. Off hides every panel without deleting any. |
| Unlock panels | Show every panel with a drag handle and a name label. Resets when you reload. |
| Test mode | Put three sample panels on screen. |
| Debug console | Show the debug window. Resets when you reload. |
| Show names while unlocked | Print each panel's name across it while unlocked. |
| Snap to grid | Round a dragged panel's position to the grid size below. |
| Grid size | How coarse that grid is, in screen units. |
| Default frame strata | The layer new panels start in. |
| Default opacity | How see-through new panels start out. |

The **Profiles** page is Ace's standard profile management: create, switch between, copy and reset
profiles, or bind one per character, class, realm or faction. Everyone starts on the shared
**Default** profile. Switching profiles redraws your panels immediately.

The **Panels** page is where the panels themselves live. Type a name at the top and press Enter (or
click **Okay**), then pick any panel from the dropdown to edit it. One panel is shown at a time, so
the page stays the same size whether you have two panels or twenty.

Each panel's editor has:

| Control | What it does |
|---|---|
| Enabled | Draw this panel at all. |
| Unlock | Give **just this panel** a drag handle, without unlocking the rest. |
| Reset | Put the panel back to how a new one starts. Its name is kept, so anything anchored to it stays anchored. |
| Delete | Remove the panel. |
| Panel name | Rename the panel. Press Enter, or click Okay. Its tooltip shows the frame name other addons can anchor to. |
| Copy settings from panel | Take on another panel's whole appearance. Its position is **not** copied, so this panel stays put. |
| Width, Height, X offset, Y offset | Size and position. |
| Anchor | Which corner or edge of the screen the offsets are measured from. |
| Frame strata | Which layer the panel sits in. |
| Background texture | Any background texture LibSharedMedia knows about, or **None** for no fill. |
| Background color / Class color | The fill color, or your class color. Its opacity controls the fill alone. |
| Border texture | Any border style LibSharedMedia knows about, or **None** for no border. |
| Border size | Thickness. Starts at 0 — the accent bar defines the edge instead. |
| Border offset | How far the border sits from the panel's edge. Positive pushes it out, negative pulls it in. |
| Border color / Class color | The border color, or your class color. The opacity you set applies either way. |
| Enable accent bar | Draw a thin strip along the panel's edges. **On** by default. |
| Accent bar texture | Any status-bar texture LibSharedMedia knows about. |
| Edges | Which edges get a bar — Top, Bottom, Left, Right, in any combination. |
| Accent bar thickness | How thick the bar is. |
| Accent bar offset | How far the bar sits from the panel. 0 sits flush (the default), positive detaches it, negative overlaps the panel. |
| Accent bar color / Class color | The bar color. Class color is **on** by default. |
| Accent bar border texture | An edge style for the bar itself, or **None**. |
| Accent bar border size | Thickness of the bar's own border. Defaults to a 1px black hairline. |
| Accent bar border offset | How far that border sits from the bar. |
| Accent bar border color / Class color | The bar border's color, or your class color. |
| Panel opacity | How visible the whole panel is — background, border and accent bar together. Multiplies with the opacity in each color. |
| Show on mouseover only | Keep the panel faded until your cursor is over it. |
| Faded opacity | How visible it is the rest of the time. 0 hides it completely. |
| Defaults (the page's own button, not the editor's) | On the **Panels** page this means *delete every panel* — your settings are left alone. It asks first, and nothing goes until you say yes. |

**Two opacities, and they do different things.** Each color carries its own opacity, which affects
only what that color paints — so you can have a see-through fill inside a solid border. **Panel
opacity** is on top of that and fades the whole panel at once, and it is the level a mouseover panel
fades *up* to.

## How panels work

1. You create a panel and give it a name. It starts as a mid-sized dark rectangle in the middle of
   the screen.
2. You unlock the screen. Every panel puts on a gold outline and its name, and becomes draggable.
3. You drag it where you want it, and resize and recolor it from the settings panel or the command
   line.
4. You lock the screen again. The outline and the label go away, the panel stops taking mouse clicks
   entirely, and it settles into the background layer — behind your bars, your chat and your unit
   frames.

The frame strata is what makes a panel a backdrop rather than an obstruction. New panels start in
`LOW`, which sits above the game world and Blizzard's parchment art but underneath essentially every
interface frame — so you can click straight through it to whatever is on top. All eight of the
game's layers are offered: `BACKGROUND` puts a panel under absolutely everything, and `DIALOG` and
above will cover normal UI, which is occasionally what you want and usually not.

A panel never takes your mouse, whatever layer it is in. That stays true even with **Show on
mouseover only** turned on — the panel watches where your cursor is without claiming the click.

Most of a panel's look is the **accent bar** — a thin colored strip running the full length of an
edge, the look BenikUI's panels are known for. It is on out of the box, so a new panel arrives as a
dark block with a class-colored strip along its top, and the panel's own border starts off so one
thing defines the edge rather than two. Tick whichever edges you want, pick a thickness, and push the
offset positive if you would rather it detached into a separate floating stripe. It draws above the
panel's border, can carry a thin border of its own, and takes any status-bar texture you have
installed. Untick **Enable accent bar** for a plain block.

Out of the box every character shares one set of panels, because most people run one UI. If you want
a character to differ, make it a profile of its own on the **Profiles** page — you can copy your
existing layout into it as a starting point, so nothing has to be rebuilt.

## FAQ

**Does this move my frames around?**
No. It never touches another addon's frames, or Blizzard's. It only draws its own rectangles behind
them. If you want a frame moved, you still move it with whatever addon owns it — Panel Master just
puts something nice behind it.

**Can I put a frame *inside* a panel?**
No, and that is deliberate. A panel is scenery, not a container. Nothing is ever parented into it.

**Will a panel block my clicks?**
Not when locked. A locked panel ignores the mouse completely, so clicks, tooltips and keybinds all
pass straight through to whatever is on top of it. It only takes the mouse while you have the screen
unlocked, which is the whole point of unlocking.

**Do my panels follow me to my alts?**
Yes, by default — every character starts on the same shared profile, so a layout you build once
shows up everywhere. If you want one character to differ, give it its own profile on the **Profiles**
page.

**How many panels can I have?**
As many as you like. They are cheap: a panel is a handful of flat textures and it costs nothing while
it sits there.

**Does it work without any other addons?**
Yes. It is completely self-contained and does not need ElvUI or any suite. It works alongside them
perfectly well, but it never depends on one.

## Troubleshooting

**I made a panel and cannot see it.**
Three usual causes. It might be behind something opaque — try `/pm unlock`, which shows every panel
with an outline and a name regardless. It might be switched off — check `/pm panels`, where a
disabled panel is listed in gray. Or the master switch might be off — `/pm set settings.enabled
true`.

**A panel has ended up off the edge of the screen.**
`/pm recover` brings every stray panel back into view. This never happens by itself, so a panel you
deliberately parked half off-screen stays exactly where you put it.

**I unlocked panels but nothing became draggable.**
If you were in combat, the unlock was queued rather than applied — you will have seen a gray notice
saying so. It happens by itself the moment you leave combat.

**`/pm config` says it cannot open during combat.**
That one is Blizzard's restriction, not a bug: the settings window cannot be switched to while you
are fighting. Run it again once you are out.

**I picked a texture and the panel went plain.**
That texture came from another addon which is no longer loaded. Panel Master keeps your choice and
falls back to a flat fill until the addon is back, so nothing is lost — pick another texture if you
would rather not wait.

**The addon will not let me use a name.**
Two panels cannot share a frame name, and the frame name ignores punctuation and spacing — so "Chat
BG" and "Chat-BG" are the same name as far as anchoring is concerned. Pick something that differs by
more than punctuation.

**I renamed a panel and something stopped lining up with it.**
Renaming changes the panel's frame name, so anything anchored to the old one is now pointing at a
frame that is no longer used. Update the anchor to the new name, which the settings page shows you.

**I cannot address a panel whose name has spaces.**
`/pm panel` and `/pm rename` read the name as the first word only. Use the Panels page in the
settings window for those, or give the panel a one-word name.

**I dragged a panel and it jumped somewhere slightly different.**
Snap-to-grid is on. Either turn it off (`/pm set settings.snapToGrid false`) or make the grid finer
(`/pm set settings.gridSize 1`).

**Something is genuinely broken.**
Run `/pm debug on`, reproduce it, then `/pm debug` to open the log and **Copy** to grab the text.
Attaching that to an issue makes it far easier to work out what happened.

## Issues and feature requests

Bugs and ideas both go to [GitHub issues](https://github.com/tusharsaxena/PanelMaster/issues). A
debug log (see above) helps a great deal for anything that looks like a bug.

## Version History

| Version | Notes |
|---|---|
| 0.1.0 | First release. Create, place and style backdrop panels; LibSharedMedia background and border textures; class-color option for both; mouseover-only fade; all eight frame strata; per-panel and global unlock with snap-to-grid; fixed frame names for anchoring; accent bars with their own border; test mode; copy-settings-between-panels; full command-line control; AceDB profiles. |
