# Ka0s Panel Master

![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.0-purple)
![CurseForge Version](https://img.shields.io/curseforge/v/1642836)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-789%2F789_passing-green)

Ka0s Panel Master draws plain backdrop panels behind your UI, so separate frames read as deliberate
groups.

A panel is a rectangle with a color, a border and a position. That is the whole of it. It sits
**behind** everything, holds nothing, and never moves or touches another addon's frames: your action
bars, your chat window and your unit frames stay exactly where their own addons put them, with
something deliberate behind them.

If you have used kgPanels, or the panels built into ElvUI, this will feel familiar.

## Screenshots

**_Panel Master in action_**

![Panel Master in action](https://media.forgecdn.net/attachments/1936/709/panelmaster-screenshot-04-jpg.jpg)

**_Basic panel_**

![Basic panel](https://media.forgecdn.net/attachments/1936/706/panelmaster-screenshot-01-png.png)

**_Panels with bundled artwork_**

![Panels with bundled artwork](https://media.forgecdn.net/attachments/1936/707/panelmaster-screenshot-02-png.png)

**_Panels with SunnArt artwork_**

![Panels with SunnArt artwork](https://media.forgecdn.net/attachments/1936/708/panelmaster-screenshot-03-png.png)

## Usage

`/pm new ChatBG` and you have a panel. It arrives mid-sized and dark, in the middle of the screen,
with a class-colored strip along its top. Nothing else: no artwork, and no border either, because
that strip already defines the edge.

Placing it starts with `/pm unlock`. Every panel puts on a gold outline and its own name and becomes
draggable, so you pull it to where it belongs and let go. Dragging snaps to a four-pixel grid, which
keeps a row of panels level; make the grid finer, or turn snapping off, when you want a panel
somewhere the grid will not put it, and thicken the unlock outline if you are hunting a small panel
on a busy screen. `/pm lock` puts it all back. The outline and the label go away and the panel stops
taking the mouse entirely, and clicks, tooltips and keybinds pass straight through to whatever is on
top of it. Unlocking mid-fight is queued, with a gray notice saying so, and happens by itself the
second you drop out of combat. A panel that has wandered past a screen edge comes back with
`/pm recover`.

How it looks is the Panels page in the settings window. Pick a panel from the picker at the top and
it opens underneath, one tab at a time: **General** first — its name, the two switches, and the
buttons that reset or delete it — then position and size, background and border, accent bar,
artwork, and opacity and fade. **Copy settings from panel**, on that first tab, takes another
panel's entire look without touching this one's position, which is what stops your second and third
panels from being the first one built again by hand. All of it is reachable from the command line too, and for a small
adjustment that is quicker than opening the page: `/pm panel ChatBG width 420`.

`/pm preview` drops three sample panels on screen so you can judge a color or a texture against your
real UI without building anything to try it on. Same command clears them. `/pm panels` lists what
you have, with anything switched off shown in gray. **Show on mouseover only** fades a panel away
until your cursor crosses it, and it still never claims the click. Every character shares one set of
panels out of the box, so an alt that should differ wants a profile of its own, with your existing
layout copied in as a starting point.

Everything else is configuration, and it lives in two places: the addon's own page under Settings ▸
AddOns in game, and `/pm` (or `/panelmaster`), which prints the full command list.

## How panels work

Frame strata is what makes a panel a backdrop rather than an obstruction. New panels start in `LOW`,
which sits above the game world and Blizzard's parchment art but underneath essentially every
interface frame, so you can click straight through to whatever is on top. All eight of the game's
layers are offered. `BACKGROUND` puts a panel under absolutely everything, while `DIALOG` and above
will cover normal UI, which is occasionally what you want and usually not.

A panel never takes your mouse, whatever layer it is in. That stays true with **Show on mouseover
only** turned on, because the panel watches where your cursor is without claiming the click.

A key part of a panel's look is the **accent bar**, a thin colored strip running the full length of
an edge. It is the look BenikUI's panels are known for, and it is on out of the box. Tick whichever
edges you want and pick a thickness. Push the offset positive if you would rather it detached into a
floating stripe of its own. It draws above the panel's border,
can carry a thin border itself, and takes any status-bar texture you have installed. Untick **Enable
accent bar** for a plain block.

### Anchoring other things to a panel

*Only useful if you write your own UI code or edit a config that takes frame names. Skip it
otherwise.*

Every panel has a fixed frame name built from the name you gave it when you created it:
`PanelMaster_Panel_` followed by that name with anything that is not a letter or number turned into
an underscore. A panel created as **Chat BG** is `PanelMaster_Panel_Chat_BG`. Other addons can
anchor to that name:

```lua
myFrame:SetPoint("TOPLEFT", "PanelMaster_Panel_Chat_BG", "TOPLEFT", 4, -4)
```

The frame name is fixed at that moment and never changes again. Renaming a panel does not touch it,
so anything anchored to the panel keeps following it. The cost of that is a frame name which, after
a rename, no longer matches the panel's name and can no longer be worked out from it. Hover the
**Panel name** box in the settings window to see the current one.

## Panel artwork

A panel can carry a picture as well as a color. Pick one of the pieces bundled with the addon, or
point it at a texture file of your own, and it is drawn inside the panel's bounds. Clipped there,
too, so art that is offset or scaled up cannot spill out over the rest of your UI.

Every panel starts with no artwork at all (`artTexture` is `None`), so nothing you already have
changes until you choose something.

### What you can set per panel:

| Setting | What it does |
|---|---|
| Artwork | Which piece. **None**, one of the bundled pieces, or **Custom path…** for your own file. |
| Custom path | The texture to draw when **Custom** is picked. Only read in that case, so switching to a bundled piece and back does not lose what you typed. |
| Artwork color / Use class color | Tints the art, whichever piece it is. The white-on-black pieces are drawn in white, so the tint is what gives them their color; full-color art wants **Desaturate** below first, or the tint only muddies it. Class color works here like it does everywhere else. |
| Desaturate | Drains the art to grayscale *before* the tint applies, so tinting full-color art gives you a clean version of the color you picked instead of mud. Off by default, so nothing you already have changes. |
| Blend mode | **Normal** paints over the panel obeying the image's transparency. **Glow** adds the art's light instead: it can only brighten, never darken, and reads as a lit emblem over a dark panel. |
| Opacity | How solid the art is, on top of the panel's own opacity. |
| Fill | **Native size** draws it at its authored pixel size; **Stretch** fills the panel exactly and ignores scale; **Fill (crop)** covers the panel and crops the overflow; **Fit (contain)**, the default, fits the whole image inside the panel; **Tile** repeats it across the panel. |
| Position, X, Y | Where the art sits in the panel. Only **Native size** and **Fit** honor it — the other three cover the panel exactly, so there is nothing to move. |
| Scale | 0.1 to 4. On **Fill (crop)** it zooms the crop; **Stretch** ignores it. |
| Rotation, Flip | Quarter turns (0°, 90°, 180°, 270°) and a horizontal and vertical mirror. Flips apply first, then the rotation. |
| Layer | Behind the background, above the background (the default), or above the border and accent bar. |
| Fit to artwork | A button, next to the custom path box. Press it and the panel is resized to the artwork's **exact pixel size**, taking **Scale** and **Rotation** into account: a bundled piece is 1024×1024 and gives a square panel that big, the same piece at scale 0.5 gives 512×512, and a three-section Sunn bar turned 90° gives 256×1536. Large art gives a large panel, so drag it back to the size you want afterwards; press this again any time to return to the artwork's own size. A panel with no artwork, or whose art is not installed, says so and is left alone. |

### Bundled Artwork

The addon ships with a bundle of 100+ images. All the images were sourced from
[warcraft.wiki.gg](https://warcraft.wiki.gg/) and were upscaled and enhanced by the author. The
WarcraftWiki originals are published under
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) and the upscales ship under that
same license, so if you reuse them, credit the source and keep them under CC BY-SA 4.0.

![Bundled artwork](https://media.forgecdn.net/attachments/1849/100/artwork-poster-jpg.jpg)

### Sunn — Viewport Art packs

If you have [Sunn - Viewport Art](https://www.curseforge.com/wow/addons/sunn-viewport-art) or any
of its [official art packs](https://www.curseforge.com/members/sunn6/projects) installed, their
themes appear in the artwork dropdown too, grouped under **Sunn ->**. Nothing is bundled or copied.
The addon reads what is already on your disk.

It borrows Sunn's *artwork* and nothing more. The viewport itself, the black bars that letterbox the
game world, is not something Panel Master does anything with. If enough people want viewport
support, it can be added later as an enhancement; say so on the issue tracker.

Only packs you actually have are listed, so nothing in the dropdown is an entry that would draw a
blank panel. A pack you uninstall stops being offered on the next login, even if Sunn's own saved
settings still remember it.

You do not need Sunn itself loaded. The art packs are ordinary texture folders, and Panel Master can
draw them whether or not the addon that came with them is running: it knows what the twelve official
packs contain, and offers a theme only when that pack's folder is really installed. So leave Sunn -
Viewport Art disabled if you like. The original addon has not been updated in a while and is
incompatible with WoW 12.x.x, so it will show up as incompatible, which is a shame and does not stop
its art packs working here.

A **Sunn theme** is several files laid side by side into one wide bar, and that whole bar is what you
get: one dropdown entry per theme, under the theme's own name. Every setting above works on it
exactly as it works on a single piece, since it is treated as one wide image and cut up only at the
last moment. So **Fit** fits the entire bar, **Fill (crop)** crops it and may leave only the middle
section on screen, a 90° rotation stacks the sections vertically, and a horizontal flip reverses
their order. **Fit to artwork** is worth pressing here. It gives you the bar at its authored size,
1536×256 for a typical three-section theme, which is the shape it was drawn for.

Two things to know. Packs whose art has a transparent strip along the top declare how much (Sunn
uses it to hang that strip over the game world), and since a panel has nothing to hang it over, the
strip is trimmed instead: the art sits flush in the panel, and **Fit to artwork** measures what you
can see rather than the padding. The other is tiling. **Tile** on a whole bar repeats the entire bar
rather than each section, and is capped so one panel cannot cost hundreds of textures; past the cap
you get fewer, larger repeats, never a bare strip. Tiling is also the one case where that
transparent strip is not trimmed, so a tiled bar shows its gaps.

### Using your own artwork

Any picture can become panel artwork, but it has to be in a format WoW can load: a `.tga` or `.blp`
sitting inside an addon folder, addressed the way the game addresses it, e.g.
`Interface\AddOns\MyStuff\art\crest.tga`. The game cannot read `.png` or `.jpg` at all, and a path
it cannot resolve draws nothing and raises no error.

Converting one is the fiddly part, so the converter this addon's own art was made with is yours to
use, and you do not have to be a developer to run it. It takes any image and writes the TGA the
client wants, upscaling a source that is too small, giving one transparency if it has none, and
cleaning up the halo an upscaler otherwise smears along every edge:

```bash
python3 tools/artwork/artwork_cleaner.py --single ~/Pictures/crest.png
python3 tools/artwork/artwork_cleaner.py --batch  ~/Pictures/art ~/my-wow-art
```

`--single` writes the `.tga` beside the image you pointed it at; `--batch` converts a whole tree
into a folder of your choosing. It needs Python with [Pillow](https://python-pillow.org/) and numpy,
and it lives in the [source repo](https://github.com/tusharsaxena/PanelMaster) rather than in the
addon you downloaded, since the packaged addon carries no build tools. Put the result in a folder
under `Interface\AddOns\`, then point the editor's **Custom path** at it. That takes any texture
path, so nothing else has to be set up.

What makes a good file: 32-bit TGA with an alpha channel, square, and a power of two on both axes.
WoW cannot wrap a non-power-of-two texture at all, which the **Tile** fill needs. The background
wants to be genuinely transparent (alpha 0, not white and not black), because the panel's own fill,
texture and opacity show through it.

If you would like a piece added to the bundled set instead of keeping it to yourself, open an issue.
Art has to be redistributable. CC0, MIT and public domain are all fine; non-commercial and
no-derivatives licenses are not, and neither is traced Blizzard art submitted as your own. The full
conversion guide, including how to pick good sources, is in
[`docs/artwork-spec.md`](docs/artwork-spec.md).

## FAQ

| Question | Answer |
|----------|--------|
| Does this move my frames around? | No. It never touches another addon's frames, or Blizzard's; it only draws its own rectangles behind them. If you want a frame moved, you still move it with whatever addon owns it. Panel Master just puts something nice behind it. |
| Can I put a frame *inside* a panel? | No, and that is deliberate. A panel is scenery, not a container. Nothing is ever parented into it. |
| Will a panel block my clicks? | Not when locked. A locked panel ignores the mouse completely, so clicks, tooltips and keybinds all pass straight through to whatever is on top of it. It only takes the mouse while you have the screen unlocked, which is the whole point of unlocking. |
| Do my panels follow me to my alts? | Yes, by default. Every character starts on the same shared profile, so a layout you build once shows up everywhere. If you want one character to differ, give it its own profile on the **Profiles** page. |
| How many panels can I have? | As many as you like. They are cheap: a panel is a handful of flat textures and it costs nothing while it sits there. |
| There is so much artwork bundled with this addon — will it affect my performance? | No. The bundled art costs disk space and nothing else. WoW does not load a texture because it is sitting in the addon folder; it loads one when something on screen asks for it, so the only art in memory is the art your panels are actually drawing. A hundred unused pieces and none at all are the same to the client while you play. |
| Do I need Sunn - Viewport Art installed? | Only if you want its themes in the artwork list. Its packs are read straight off your disk if you have them, and Sunn itself does not even have to be enabled. Nothing is bundled or copied. |
| Does it work without any other addons? | Yes. It is completely self-contained and does not need ElvUI or any suite. It works alongside them perfectly well, but it never depends on one. |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| I made a panel and cannot see it | Three usual causes. It might be behind something opaque: run `/pm unlock`, which outlines and names every panel regardless. It might be switched off; check `/pm panels`, where a disabled panel is listed in gray. Or the master switch is off, so `/pm set settings.enabled true`. |
| A panel has ended up off the edge of the screen | `/pm recover` brings every stray panel back into view. This never happens by itself, so a panel you deliberately parked half off-screen stays exactly where you put it. |
| I unlocked panels but nothing became draggable | You were in combat, so the unlock was queued rather than applied, and you will have seen a gray notice saying so. It happens by itself the moment you leave combat. |
| `/pm config` says it cannot open during combat | Blizzard's restriction, not a bug: the settings window cannot be switched to while you are fighting. Run it again once you are out. |
| I picked a texture and the panel went plain | That texture came from another addon which is no longer loaded. Panel Master keeps your choice and falls back to a flat fill until the addon is back, so nothing is lost. Pick another texture if you would rather not wait. |
| I picked artwork and nothing appeared | If it was your own file, the path is the likely cause: WoW loads a `.tga` or `.blp` only from inside an addon folder, addressed the way the game addresses it, and a path it cannot resolve draws nothing and raises no error, so a typo looks exactly like having picked **None**. Check the file is a power of two on both sides too; one that is not may fail to load outright. If it is a bundled piece and *still* nothing shows, check the **Draw layer**: **Behind background** puts the art under the panel's own fill, which hides it unless that fill is transparent. |
| The addon will not let me create a panel with a name | Two panels cannot share a frame name, and the frame name ignores punctuation and spacing, so "Chat BG" and "Chat-BG" want the same one. Pick something that differs by more than punctuation. This also happens with a name that looks free: a panel *created* as "Alpha" and later renamed still holds `PanelMaster_Panel_Alpha`, and the message names whichever panel is holding it. Renaming is never refused for this reason, only creating. |
| I renamed a panel and want to know its frame name | Renaming does not change it, so anything anchored to the panel still works. But the frame name still reflects the name the panel was *created* with, so it is no longer something you can work out. Hover the **Panel name** box in the settings window and it shows you. |
| I cannot address a panel whose name has spaces | `/pm panel` and `/pm rename` read the name as the first word only. Use the Panels page in the settings window for those, or give the panel a one-word name. |
| I dragged a panel and it jumped somewhere slightly different | Snap-to-grid is on. Turn it off (`/pm set settings.snapToGrid false`) or make the grid finer (`/pm set settings.gridSize 1`). |
| Something is genuinely broken | Run `/pm debug on`, reproduce it, then `/pm debug` to open the log and **Copy** to grab the text. Attaching that to an issue makes it far easier to work out what happened. |

## Issues and feature requests

Bugs and feature requests are tracked at
[github.com/tusharsaxena/PanelMaster/issues](https://github.com/tusharsaxena/PanelMaster/issues).
Please file them there rather than in comments; it is the single place the project's to-do list
lives. A debug log (see above) helps a great deal for anything that looks like a bug.

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| 1.1.0 | 2026-09-10 | Page-wide actions moved onto a **General** first tab, and **Create** and **Edit** now sit above the tab strip<br>Fixed the page band failing when it was built before the canvas existed<br>Fixed the landing tagline wrapping onto a second line<br>The **Defaults** tooltip no longer implies your panels are safe from the reset<br>Updated for game patch 12.1.0 |
| 1.0.0 | 2026-08-07 | - First release: create, place and style as many backdrop panels as you like<br>- LibSharedMedia background and border textures, with a class-color option for both<br>- Accent bars along any edge, with their own texture, border and class color<br>- Per-panel scale, mouseover-only fade, and all eight frame strata<br>- Per-panel artwork from the bundled catalog, your own texture, or a Sunn - Viewport Art pack you already own — with tint, desaturate, blend mode, fill, position, scale, rotation, flip, draw layer and fit-to-artwork<br>- Fixed frame names so other addons can anchor to a panel, unaffected by renaming<br>- Global and per-panel unlock with snap-to-grid, test mode and copy-settings-between-panels<br>- Full command-line control and AceDB profiles |

## Credits

The bundled panel artwork comes from [warcraft.wiki.gg](https://warcraft.wiki.gg/), AI-upscaled to
the sizes the client wants and redistributed under
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), the same license as the originals.

