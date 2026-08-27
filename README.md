# Ka0s Panel Master

![WoW](https://img.shields.io/badge/WoW-Midnight_12.0.7-purple)
![CurseForge Version](https://img.shields.io/curseforge/v/1642836)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-732%2F732_passing-green)

![Logo](https://media.forgecdn.net/attachments/1849/99/panelmaster-logo-jpg.jpg)

Ka0s Panel Master draws plain backdrop panels behind your UI, so a screen full of separate frames
reads as a few deliberate groups.

That is all a panel is: a rectangle with a color, a border and a position. It sits **behind**
everything, it holds nothing, and it never moves or touches any of your other frames. Your action
bars, your chat window and your unit frames stay exactly where their own addons put them — the panel
is just the backdrop they sit on. 

If you have used kgPanels, or the panels built into ElvUI, this will feel familiar.

Make one with `/pm new`, unlock the screen with `/pm unlock`, drag it where you want it, then `/pm
lock`. Everything else lives in the settings panel or under `/pm config`.

## Screenshots

**_Panel Master in action_**

![Panel Master in action](https://media.forgecdn.net/attachments/1849/188/panelmaster-screenshot-04-jpg.jpg)

**_Basic panel_**

![Basic panel](https://media.forgecdn.net/attachments/1849/185/panelmaster-screenshot-01-png.png)

**_Panels with bundled artwork_**

![Panels with bundled artwork](https://media.forgecdn.net/attachments/1849/186/panelmaster-screenshot-02-png.png)

**_Panels with SunnArt artwork_**

![Panels with SunnArt artwork](https://media.forgecdn.net/attachments/1849/187/panelmaster-screenshot-03-png.png)

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
| `/pm panel name [field] [value]` | Look at, or change, one panel. `/pm panel name fitart` fits it to its artwork; `/pm panel deleteall` removes every panel |
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
`x`, `y`, `strata`, `level`, `scale`, `alpha`, `bgTexture`, `bgColor`, `bgClassColor`, `borderTexture`,
`borderSize`, `borderOffset`, `borderColor`, `borderClassColor`, `mouseover`, `mouseoverAlpha`,
`accentEnabled`, `accentEdges`, `accentTexture`, `accentThickness`, `accentOffset`, `accentColor`,
`accentClassColor`, `accentBorderTexture`, `accentBorderSize`, `accentBorderOffset`,
`accentBorderColor`, `accentBorderClassColor`, `artTexture`, `artCustomPath`, `artColor`,
`artClassColor`, `artAlpha`, `artFill`, `artPoint`, `artX`, `artY`, `artScale`, `artRotation`,
`artFlipH`, `artFlipV`, `artDesaturate`, `artBlend` and `artLayer`. So:

```
/pm panel ChatBG width 420
/pm panel ChatBG bgColor 0.1,0.1,0.12,0.8
/pm panel ChatBG bgTexture blizzard marble
/pm panel ChatBG borderClassColor on
/pm panel ChatBG strata LOW
/pm panel ChatBG accentEnabled on
/pm panel ChatBG accentEdges top,left
/pm panel ChatBG artTexture class-death-knight
/pm panel ChatBG artFill FILL
```

Colors take either `r,g,b` or `r,g,b,a`, in 0–1 or 0–255 — `1,0,0,0.5` and `255,0,0,128` both mean
half-transparent red. Texture names are whatever LibSharedMedia has, and are matched however you
type the capitals. `accentEdges` takes a comma list of `top`, `bottom`, `left`, `right` — or `none`
for no bars at all. `artTexture` takes the id of a bundled artwork (matched however you type the
capitals), `None`, or `Custom`; the five `art*` dropdown fields refuse anything that is not one of
their values and print the real list back at you.

### Anchoring other things to a panel

*Only useful if you write your own UI code or edit a config that takes frame names — skip it
otherwise.*

Every panel has a fixed frame name built from the name you gave it when you created it:
`PanelMaster_Panel_` followed by that name with anything that is not a letter or number turned into
an underscore. A panel created as **Chat BG** is `PanelMaster_Panel_Chat_BG`.

Other addons can anchor to that name:

```lua
myFrame:SetPoint("TOPLEFT", "PanelMaster_Panel_Chat_BG", "TOPLEFT", 4, -4)
```

The frame name is fixed at that moment and never changes again — **renaming a panel does not change
it**, so anything anchored to the panel keeps following it. The trade is that after a rename the
frame name no longer matches the panel's name, and you can no longer work it out from the name
alone. Hover the **Panel name** box in the settings window to see the current one.

### Settings panel

Open it with `/pm config`, or find **Ka0s Panel Master** in the game's own Settings ▸ AddOns list. It
has a landing page and three tabs beneath it:

| Tab | Covers |
|---|---|
| Ka0s Panel Master | The landing page — the logo, one line on what the addon does, and the same slash-command list `/pm help` prints. |
| General | Every addon-wide setting: the master switch, unlock and test mode, the debug console, the snap grid, and the strata and opacity new panels start with. |
| Panels | The panels themselves — create, rename, copy, reset and delete them, and edit the selected one's size, position, background, border, accent bar and fading. |
| Profiles | Ace's standard profile management: create, switch between, copy and reset profiles, or bind one per character, class, realm or faction. |

**General** carries these:

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

On **Profiles**, everyone starts on the shared **Default** profile, and switching profiles redraws
your panels immediately.

On **Panels**, type a name at the top and press Enter (or click **Okay**), then pick any panel from
the dropdown to edit it. One panel is shown at a time, so the page stays the same size whether you
have two panels or twenty. Each panel's editor has:

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
| Background color / Class color | The fill color, or your class color. Its opacity controls the fill alone. |
| Border texture | Any border style LibSharedMedia knows about, or **None** for no border. |
| Border size | Thickness. Starts at 0 — the accent bar defines the edge instead. |
| Border offset | How far the border sits from the panel's edge. Positive pushes it out, negative pulls it in. |
| Border color / Class color | The border color, or your class color. The opacity you set applies either way. |
| Enable accent bar | Draw a thin strip along the panel's edges. **On** by default. |
| Accent bar texture | Any status-bar texture LibSharedMedia knows about. |
| Edges | Which edges get a bar — Top, Bottom, Left, Right, in any combination. Left and right bars turn the texture a quarter turn, so a bar reads the same way round whichever edge it is on. |
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

1. Create a panel and give it a name. It starts as a mid-sized dark rectangle in the middle of
   the screen.
2. Unlock the screen. Every panel puts on a gold outline and its name, and becomes draggable.
3. Drag it where you want it, and resize and recolor it from the settings panel or the command
   line.
4. Lock the screen again. The outline and the label go away, the panel stops taking mouse clicks
   entirely, and it settles into the background layer — behind your bars, your chat and your unit
   frames.

The frame strata is what makes a panel a backdrop rather than an obstruction. New panels start in
`LOW`, which sits above the game world and Blizzard's parchment art but underneath essentially every
interface frame — so you can click straight through it to whatever is on top. All eight of the
game's layers are offered: `BACKGROUND` puts a panel under absolutely everything, and `DIALOG` and
above will cover normal UI, which is occasionally what you want and usually not.

A panel never takes your mouse, whatever layer it is in. That stays true even with **Show on
mouseover only** turned on — the panel watches where your cursor is without claiming the click.

A key part of a panel's look is the **accent bar** — a thin colored strip running the full length of an
edge, the look BenikUI's panels are known for. It is on out of the box, so a new panel arrives as a
dark block with a class-colored strip along its top, and the panel's own border starts off so one
thing defines the edge rather than two. Tick whichever edges you want, pick a thickness, and push the
offset positive if you would rather it detached into a separate floating stripe. It draws above the
panel's border, can carry a thin border of its own, and takes any status-bar texture you have
installed. Untick **Enable accent bar** for a plain block.

Out of the box every character shares one set of panels, because most people run one UI. If you want
a character to differ, make it a profile of its own on the **Profiles** page — you can copy your
existing layout into it as a starting point, so nothing has to be rebuilt.

## Panel artwork

A panel can carry a picture as well as a color. Pick one of the pieces bundled with the addon, or
point it at a texture file of your own, and it is drawn inside the panel's bounds — clipped there,
so art that is offset or scaled up cannot spill out over the rest of your UI.

Every panel starts with no artwork at all (`artTexture` is `None`), so nothing you already have
changes until you choose something.

### What you can set per panel:

| Setting | What it does |
|---|---|
| Artwork | Which piece. **None**, one of the bundled pieces, or **Custom path…** for your own file. |
| Custom path | The texture to draw when **Custom** is picked. Only read in that case, so switching to a bundled piece and back does not lose what you typed. |
| Color / Class color | Tints the art, whichever piece it is. The white-on-black pieces are drawn in white, so the tint is what gives them their color; full-color art wants **Desaturate** below first, or the tint only muddies it. Class color works here like it does everywhere else. |
| Desaturate | Drains the art to grayscale *before* the tint applies, so tinting full-color art gives you a clean version of the color you picked instead of mud. Off by default, so nothing you already have changes. |
| Blend mode | **Normal** paints over the panel obeying the image's transparency. **Glow** adds the art's light instead — it can only brighten, never darken, and reads as a lit emblem over a dark panel. |
| Opacity | How solid the art is, on top of the panel's own opacity. |
| Fill | **Native size** draws it at its authored pixel size; **Stretch** fills the panel exactly and ignores scale; **Fill (crop)** covers the panel and crops the overflow; **Fit (contain)** — the default — fits the whole image inside the panel; **Tile** repeats it across the panel. |
| Position, X, Y | Where the art sits in the panel. Only **Native size** and **Fit** honor it — the other three cover the panel exactly, so there is nothing to move. |
| Scale | 0.1 to 4. On **Fill (crop)** it zooms the crop; **Stretch** ignores it. |
| Rotation, Flip | Quarter turns — 0°, 90°, 180°, 270° — and a horizontal and vertical mirror. Flips apply first, then the rotation. |
| Layer | Behind the background, above the background (the default), or above the border and accent bar. |
| Fit to artwork | A button, next to the custom path box. Press it and the panel is resized to the artwork's **exact pixel size**, taking **Scale** and **Rotation** into account — a bundled piece is 1024×1024 and gives a square panel that big; the same piece at scale 0.5 gives 512×512, and a three-section Sunn bar turned 90° gives 256×1536. Large art gives a large panel, so drag it back to the size you want afterwards; press this again any time to return to the artwork's own size. A panel with no artwork, or whose art is not installed, says so and is left alone. |

### Bundled Artwork

The addon ships with a bundle of 100+ images. All the images were sourced from [warcraft.wiki.gg](https://warcraft.wiki.gg/) and were upscaled and enhanced
by the author. The WarcraftWiki originals are published under
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) and the upscales ship under that same license - so if you reuse them, credit the source and keep them under CC BY-SA 4.0.

![Bundled artwork](https://media.forgecdn.net/attachments/1849/100/artwork-poster-jpg.jpg)

### Sunn — Viewport Art packs

If you have [Sunn - Viewport Art](https://www.curseforge.com/wow/addons/sunn-viewport-art) or any
of its [official art packs](https://www.curseforge.com/members/sunn6/projects) installed, their
themes appear in the artwork dropdown too, grouped under **Sunn ->**. Nothing is bundled or copied —
the addon reads what is already on your disk.

**The art packs only.** Panel Master borrows Sunn's *artwork*; it does not do anything with Sunn's
viewport — the black bars that letterbox the game world. If enough people want viewport support, it
can be added later as an enhancement; say so on the issue tracker.

**Only packs you actually have are listed.** A pack you uninstall stops being offered on the next
login, even if Sunn's own saved settings still remember it — so nothing in the dropdown is an entry
that would draw a blank panel.

**You do not need Sunn itself loaded.** The art packs are ordinary texture folders, and Panel
Master can draw them whether or not the addon that came with them is running — it knows what the
twelve official packs contain, and offers a theme only when that pack's folder is really installed.
So you can leave Sunn - Viewport Art disabled. Sadly the original addon has not been updated in a
while and is incompatible with WoW 12.x.x, so it will show up as incompatible — but its art packs work with Panel Master regardless.

A **Sunn theme** is several files laid side by side into one wide bar, and that whole bar is what you
get: one dropdown entry per theme, under the theme's own name. Every setting above works on it
exactly as it works on a single piece — it is treated as one wide image and cut up only at the last
moment. So **Fit** fits the entire bar, **Fill (crop)**
crops it and may leave only the middle section on screen, a 90° rotation stacks the sections
vertically, and a horizontal flip reverses their order. **Fit to artwork** is worth pressing here: it
gives you the bar at its authored size — 1536×256 for a typical three-section theme — which is the
shape it was drawn for.

**Two things to know:**

- Packs whose art has a transparent strip along the top declare how much (Sunn uses it to hang that
  strip over the game world). A panel has nothing to hang it over, so that strip is **trimmed**
  instead — the art sits flush in the panel, and **Fit to artwork** measures what you can see rather than the
  padding.
- **Tile** on a whole bar repeats the entire bar rather than each section, and is capped so one
  panel cannot cost hundreds of textures. Past the cap you get fewer, larger repeats — never a bare
  strip. Tiling is also the one case where the transparent strip above is not trimmed, so a tiled
  bar shows its gaps.

### Using your own artwork

Any picture can become panel artwork, but it has to be in a format WoW can load: a `.tga` or `.blp`
sitting inside an addon folder, addressed the way the game addresses it, e.g.
`Interface\AddOns\MyStuff\art\crest.tga`. The game cannot read `.png` or `.jpg` at all, and a path
it cannot resolve draws nothing and raises no error.

Converting one is the fiddly part, so the converter this addon's own art was made with is yours to
use — you do not have to be a developer to run it. It takes any image and writes the TGA the client
wants, upscaling a source that is too small, giving one transparency if it has none, and cleaning up
the halo an upscaler otherwise smears along every edge:

```bash
python3 tools/artwork/artwork_cleaner.py --single ~/Pictures/crest.png
python3 tools/artwork/artwork_cleaner.py --batch  ~/Pictures/art ~/my-wow-art
```

`--single` writes the `.tga` beside the image you pointed it at; `--batch` converts a whole tree
into a folder of your choosing. It needs Python with [Pillow](https://python-pillow.org/) and numpy,
and it lives in the [source repo](https://github.com/tusharsaxena/PanelMaster) rather than in the
addon you downloaded — the packaged addon carries no build tools. Put the result in a folder under
`Interface\AddOns\`, then point the editor's **Custom path** at it: that takes any texture path, so
nothing else has to be set up.

**What makes a good file.** 32-bit TGA with an alpha channel, square, and a power of two on both
axes — WoW cannot wrap a non-power-of-two texture at all, which the **Tile** fill needs. The
background wants to be genuinely transparent (alpha 0, not white and not black), because the panel's
own fill, texture and opacity show through it.

If you would like a piece added to the bundled set instead of keeping it to yourself, open an issue.
Art has to be redistributable — CC0, MIT and public domain are all fine, non-commercial and
no-derivatives licenses are not, and neither is traced Blizzard art submitted as your own. The full
conversion guide, including how to pick good sources, is in
[`docs/artwork-spec.md`](docs/artwork-spec.md).

## FAQ

| Question | Answer |
|----------|--------|
| Does this move my frames around? | No. It never touches another addon's frames, or Blizzard's — it only draws its own rectangles behind them. If you want a frame moved, you still move it with whatever addon owns it; Panel Master just puts something nice behind it. |
| Can I put a frame *inside* a panel? | No, and that is deliberate. A panel is scenery, not a container. Nothing is ever parented into it. |
| Will a panel block my clicks? | Not when locked. A locked panel ignores the mouse completely, so clicks, tooltips and keybinds all pass straight through to whatever is on top of it. It only takes the mouse while you have the screen unlocked, which is the whole point of unlocking. |
| Do my panels follow me to my alts? | Yes, by default — every character starts on the same shared profile, so a layout you build once shows up everywhere. If you want one character to differ, give it its own profile on the **Profiles** page. |
| How many panels can I have? | As many as you like. They are cheap: a panel is a handful of flat textures and it costs nothing while it sits there. |
| There is so much artwork bundled with this addon — will it affect my performance? | No. The bundled art costs disk space and nothing else. WoW does not load a texture because it is sitting in the addon folder; it loads one when something on screen asks for it, so the only art in memory is the art your panels are actually drawing. A hundred unused pieces and none at all are the same to the client while you play. |
| Do I need Sunn - Viewport Art installed? | Only if you want its themes in the artwork list. Its packs are read straight off your disk if you have them, and Sunn itself does not even have to be enabled. Nothing is bundled or copied. |
| Does it work without any other addons? | Yes. It is completely self-contained and does not need ElvUI or any suite. It works alongside them perfectly well, but it never depends on one. |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| I made a panel and cannot see it | Three usual causes. It might be behind something opaque — run `/pm unlock`, which outlines and names every panel regardless. It might be switched off — check `/pm panels`, where a disabled panel is listed in gray. Or the master switch is off — `/pm set settings.enabled true`. |
| A panel has ended up off the edge of the screen | `/pm recover` brings every stray panel back into view. This never happens by itself, so a panel you deliberately parked half off-screen stays exactly where you put it. |
| I unlocked panels but nothing became draggable | You were in combat, so the unlock was queued rather than applied — you will have seen a gray notice saying so. It happens by itself the moment you leave combat. |
| `/pm config` says it cannot open during combat | Blizzard's restriction, not a bug: the settings window cannot be switched to while you are fighting. Run it again once you are out. |
| I picked a texture and the panel went plain | That texture came from another addon which is no longer loaded. Panel Master keeps your choice and falls back to a flat fill until the addon is back, so nothing is lost — pick another texture if you would rather not wait. |
| I picked artwork and nothing appeared | If it was your own file, the path is the likely cause: WoW loads a `.tga` or `.blp` only from inside an addon folder, addressed the way the game addresses it, and a path it cannot resolve draws nothing and raises no error — so a typo looks exactly like having picked **None**. Check the file is a power of two on both sides too; one that is not may fail to load outright. If it is a bundled piece and *still* nothing shows, check the **Draw layer**: **Behind background** puts the art under the panel's own fill, which hides it unless that fill is transparent. |
| The addon will not let me create a panel with a name | Two panels cannot share a frame name, and the frame name ignores punctuation and spacing — so "Chat BG" and "Chat-BG" want the same one. Pick something that differs by more than punctuation. This also happens with a name that looks free: a panel *created* as "Alpha" and later renamed still holds `PanelMaster_Panel_Alpha`, and the message names whichever panel is holding it. Renaming is never refused for this reason — only creating. |
| I renamed a panel and want to know its frame name | Renaming does not change it, so anything anchored to the panel still works — but the frame name still reflects the name the panel was *created* with, so it is no longer something you can work out. Hover the **Panel name** box in the settings window and it shows you. |
| I cannot address a panel whose name has spaces | `/pm panel` and `/pm rename` read the name as the first word only. Use the Panels page in the settings window for those, or give the panel a one-word name. |
| I dragged a panel and it jumped somewhere slightly different | Snap-to-grid is on. Turn it off (`/pm set settings.snapToGrid false`) or make the grid finer (`/pm set settings.gridSize 1`). |
| Something is genuinely broken | Run `/pm debug on`, reproduce it, then `/pm debug` to open the log and **Copy** to grab the text. Attaching that to an issue makes it far easier to work out what happened. |

## Credits

The bundled panel artwork comes from [warcraft.wiki.gg](https://warcraft.wiki.gg/), AI-upscaled to
the sizes the client wants and redistributed under
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), the same license as the originals.

## Issues and feature requests

Bugs and feature requests are tracked at
[github.com/tusharsaxena/PanelMaster/issues](https://github.com/tusharsaxena/PanelMaster/issues).
Please file them there rather than in comments — it is the single place the project's to-do list
lives. A debug log (see above) helps a great deal for anything that looks like a bug.

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| 1.0.0 | 2026-08-07 | - First release: create, place and style as many backdrop panels as you like<br>- LibSharedMedia background and border textures, with a class-color option for both<br>- Accent bars along any edge, with their own texture, border and class color<br>- Per-panel scale, mouseover-only fade, and all eight frame strata<br>- Per-panel artwork from the bundled catalog, your own texture, or a Sunn - Viewport Art pack you already own — with tint, desaturate, blend mode, fill, position, scale, rotation, flip, draw layer and fit-to-artwork<br>- Fixed frame names so other addons can anchor to a panel, unaffected by renaming<br>- Global and per-panel unlock with snap-to-grid, test mode and copy-settings-between-panels<br>- Full command-line control and AceDB profiles |
