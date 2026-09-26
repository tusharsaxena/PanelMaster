# Ka0s Panel Master

![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.0-purple)
![CurseForge Version](https://img.shields.io/curseforge/v/1642836)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-964%2F964_passing-green)

Ka0s Panel Master draws plain backdrop panels behind your UI, so separate frames read as deliberate
groups.

A panel is a rectangle with a color, a border and a position, and that is all it is. It sits behind
everything and holds nothing. It never moves or touches another addon's frames, so your action bars,
your chat window and your unit frames stay exactly where their own addons put them. They just get
something deliberate behind them.

If you have used kgPanels, or the panels built into ElvUI, this will feel familiar.

## Screenshots

**_Panel Master in action_**

![Panel Master in action](https://media.forgecdn.net/attachments/1936/709/panelmaster-screenshot-04-jpg.jpg)

**_Basic panel_**

![Basic panel](https://media.forgecdn.net/attachments/1936/706/panelmaster-screenshot-01-png.png)

**_Panels with bundled artwork_**

![Panels with bundled artwork](https://media.forgecdn.net/attachments/1950/134/artwork-poster-jpg.jpg)

**_Panels with SunnArt artwork_**

![Panels with SunnArt artwork](https://media.forgecdn.net/attachments/1936/708/panelmaster-screenshot-03-png.png)

## Usage

`/pm new ChatBG` and you have a panel. It arrives mid-sized and dark, in the middle of the screen,
with a class-colored strip along its top. That is all you get at first: no artwork, and no border
either, because the strip already defines the edge.

To place it, type `/pm unlock`. Every panel shows a gold outline and its own name and becomes
draggable, so you pull it where it belongs and let go. Dragging snaps to a four-pixel grid, which
keeps a row of panels level. When you want a panel somewhere the grid will not put it, make the grid
finer or turn snapping off. If you are hunting for a small panel on a busy screen, thicken the unlock
outline.

`/pm lock` puts it all back. The outline and the label go away, the panel stops taking the mouse
entirely, and clicks, tooltips and keybinds pass straight through to whatever is on top of it. If
you unlock mid-fight, the unlock is queued (a gray notice tells you so) and happens by itself the
second you drop out of combat. A panel that has wandered past a screen edge comes back with
`/pm recover`. When you are done with a panel, `/pm delete ChatBG` removes it along with its
settings.

You change how a panel looks on the Panels page of the settings window. Pick a panel from the picker
at the top and it opens underneath, one tab at a time. **General** comes first, with its name, the
two switches, and the buttons that reset or delete it. After that come position and size, background
and border, accent bar, artwork, and opacity and fade. **Copy settings from panel**, on that first
tab, takes another panel's entire look without touching this one's position. It saves you from
building your second and third panels as hand-made copies of the first. Everything on the page can
be reached from the command line too, and for a small adjustment that is quicker than opening the
page: `/pm panel ChatBG width 420`.

`/pm panels` lists what you have, with anything switched off shown in gray. **Show on mouseover
only** fades a panel away until your cursor crosses it, and even then the panel never claims the
click. Out of the box, every character shares one set of panels. If an alt should look different,
give it a profile of its own and copy your existing layout in as a starting point.

The **minimap button** carries the addon's logo. Left-click opens the settings page. Right-click
opens a small menu with two ticks: **Enabled** switches the whole addon on or off, and **Locked**
unlocks your panels for dragging and locks them again. They do exactly what `/pm enable` /
`/pm disable` and `/pm lock` / `/pm unlock` do. Drag the button anywhere around the ring and it
stays there. If you would rather not have it, untick **Minimap button** under General ▸ Master
controls. It goes, and it stays gone on every character until you tick it back. If you run Titan
Panel, ElvUI's data texts or Bazooka, the same button shows up there as a row, and clicking it does
the same two things. Hover it and the tooltip shows the version, whether the addon is enabled,
whether your panels are locked, and what each click does.

If you would rather type than click, you can read every setting from chat. `/pm list` prints each
one with its current value, `/pm get settings.gridSize` answers for one, and
`/pm reset settings.gridSize` puts one back to its default. `/pm resetall` returns the whole profile
to defaults, and asks before it does. `/pm version` prints the version. Quote it in any bug report.

`/pm disable` turns the whole addon off without unloading it, and `/pm enable` brings it back. They
are the same switch as the **Enable Ka0s Panel Master** tick at the top of the settings page. Off
really is off, rather than hidden. Your panels keep their places but are not drawn, and the addon
stops watching the game's events, stops its mouseover ticker and writes nothing. It costs what
unticking it in Blizzard's own AddOns list would, without the `/reload`.

You can still get back in. `/pm` still opens the settings page, and `help`, `version`, `config`,
`debug`, `diagnostics` and the settings commands above still answer and still write. Reading and
repairing your settings is the thing you are most likely to want while the addon is off. Only the
verbs that make and edit panels refuse, and each one answers with a line naming `/pm enable`. The
minimap button stays as well. Left-click still opens the settings page, the right-click menu's
**Enabled** tick turns the addon back on, **Locked** is grayed out with a note to enable the addon
first, and the tooltip says **Enabled: No**.

Everything else is configuration, and it lives in three places: the button on your minimap, the
addon's own page under Settings ▸ AddOns in game, and the `/pm` (or `/panelmaster`) command. A bare
`/pm` opens that settings page, and `/pm help` prints the full command list.

## How panels work

Frame strata is what makes a panel a backdrop rather than an obstruction. New panels start in `LOW`,
which sits above the game world and Blizzard's parchment art but underneath almost every interface
frame, so you can click straight through to whatever is on top. You can pick any of the game's eight
layers. `BACKGROUND` puts a panel under absolutely everything, while `DIALOG` and above will cover
normal UI, which is occasionally what you want and usually not.

Whatever layer it is in, a panel never takes your mouse. That holds with **Show on mouseover only**
turned on too, because the panel watches where your cursor is without claiming the click.

Then there is the **accent bar**, a thin colored strip running the full length of an edge. It is the
look BenikUI's panels are known for, and it is on out of the box. Tick whichever edges you want and
pick a thickness. Push the offset positive if you would rather it detached into a floating stripe.
The bar draws above the panel's border, can carry a thin border of its own, and takes any status-bar
texture you have installed. Untick **Enable accent bar** for a plain block.

### Anchoring other things to a panel

*This only matters if you write your own UI code or edit a config that takes frame names. Otherwise,
skip it.*

Every panel has a fixed frame name built from the name you gave it when you created it:
`PanelMaster_Panel_` followed by that name, with anything that is not a letter or number turned into
an underscore. A panel created as **Chat BG** is `PanelMaster_Panel_Chat_BG`. Other addons can
anchor to that name:

```lua
myFrame:SetPoint("TOPLEFT", "PanelMaster_Panel_Chat_BG", "TOPLEFT", 4, -4)
```

The frame name is set at that moment and never changes again. Renaming a panel does not touch it, so
anything anchored to the panel keeps following it. The catch is that after a rename, the frame name
no longer matches the panel's name, and you can no longer work it out from that name. Hover the
**Panel name** box in the settings window to see the current one.

## Panel artwork

A panel can carry a picture as well as a color. Pick one of the pieces bundled with the addon, or
point it at a texture file of your own. The art is drawn inside the panel's bounds and clipped to
them, so art that is offset or scaled up cannot spill out over the rest of your UI.

Every panel starts with no artwork at all (`artTexture` is `None`), so nothing you already have
changes until you choose something.

### What you can set per panel:

| Setting | What it does |
|---|---|
| Artwork | Which piece. **None**, one of the bundled pieces, or **Custom path…** for your own file. |
| Custom path | The texture to draw when **Custom** is picked. It is only read in that case, so switching to a bundled piece and back does not lose what you typed. |
| Artwork color / Use class color | Tints the art, whichever piece it is. The white-on-black pieces are drawn in white, so the tint is what gives them their color. Full-color art wants **Desaturate** below first, or the tint only muddies it. Class color works here as it does everywhere else. |
| Desaturate | Drains the art to grayscale *before* the tint applies, so tinting full-color art gives you a clean version of the color you picked instead of mud. It is off by default, so nothing you already have changes. |
| Blend mode | **Normal** paints over the panel and obeys the image's transparency. **Glow** adds the art's light instead. It can only brighten, never darken, and reads as a lit emblem over a dark panel. |
| Opacity | How solid the art is, on top of the panel's own opacity. |
| Fill | **Native size** draws it at its authored pixel size; **Stretch** fills the panel exactly and ignores scale; **Fill (crop)** covers the panel and crops the overflow; **Fit (contain)**, the default, fits the whole image inside the panel; **Tile** repeats it across the panel. |
| Position, X, Y | Where the art sits in the panel. Only **Native size** and **Fit** honor it. The other three cover the panel exactly, so there is nothing to move. |
| Scale | 0.1 to 4. On **Fill (crop)** it zooms the crop; **Stretch** ignores it. |
| Rotation, Flip | Quarter turns (0°, 90°, 180°, 270°) and a horizontal and vertical mirror. Flips apply first, then the rotation. |
| Layer | Behind the background, above the background (the default), or above the border and accent bar. |
| Fit to artwork | A button next to the custom path box. Press it and the panel is resized to the artwork's exact pixel size, taking **Scale** and **Rotation** into account. A bundled piece is 1024×1024 and gives a square panel that big, the same piece at scale 0.5 gives 512×512, and a three-section Sunn bar turned 90° gives 256×1536. Large art gives a large panel, so drag it back to the size you want afterwards, and press this again any time to return to the artwork's own size. If a panel has no artwork, or its art is not installed, the button says so and leaves the panel alone. |

### Bundled artwork

The addon ships with a bundle of 100+ images. All of them come from
[warcraft.wiki.gg](https://warcraft.wiki.gg/), upscaled and enhanced by the author. The
WarcraftWiki originals are published under
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) and the upscales ship under that
same license. If you reuse them, credit the source and keep them under CC BY-SA 4.0.

![Bundled artwork](https://media.forgecdn.net/attachments/1849/100/artwork-poster-jpg.jpg)

### Sunn — Viewport Art packs

If you have [Sunn - Viewport Art](https://www.curseforge.com/wow/addons/sunn-viewport-art) or any
of its [official art packs](https://www.curseforge.com/members/sunn6/projects) installed, their
themes appear in the artwork dropdown too, grouped under **Sunn ->**. Panel Master bundles and
copies nothing here. It reads what is already on your disk.

It borrows Sunn's *artwork* and nothing more. Panel Master does nothing with the viewport itself,
the black bars that letterbox the game world. If enough people want viewport support, it can be
added later as an enhancement, so say so on the issue tracker.

The dropdown lists only the packs you actually have, so none of its entries would draw a blank
panel. A pack you uninstall stops being offered on the next login, even if Sunn's own saved settings
still remember it.

You do not need Sunn itself loaded. The art packs are ordinary texture folders, and Panel Master can
draw them whether or not the addon that came with them is running. It knows what the twelve official
packs contain, and it offers a theme only when that pack's folder is really installed. So leave Sunn -
Viewport Art disabled if you like. The original addon has not been updated in a while and is
incompatible with WoW 12.x.x, so it will show up as incompatible. That is a shame, but it does not
stop its art packs working here.

A Sunn theme is several files laid side by side into one wide bar, and you get the whole bar: one
dropdown entry per theme, under the theme's own name. Every setting above works on it exactly as it
works on a single piece, because Panel Master treats it as one wide image and only cuts it up at the
last moment. So **Fit** fits the entire bar, **Fill (crop)** crops it and may leave only the middle
section on screen, a 90° rotation stacks the sections vertically, and a horizontal flip reverses
their order. **Fit to artwork** is worth pressing here. It gives you the bar at its authored size,
1536×256 for a typical three-section theme, which is the shape it was drawn for.

Two things to know. Some packs have art with a transparent strip along the top, and they declare how
much. Sunn uses that strip to hang the art over the game world. A panel has nothing to hang it over,
so Panel Master trims the strip instead. The art sits flush in the panel, and **Fit to artwork**
measures what you can see rather than the padding.

The other is tiling. **Tile** on a whole bar repeats the entire bar rather than each section. It is
capped so that one panel cannot cost hundreds of textures, and past the cap you get fewer, larger
repeats rather than a bare strip. Tiling is also the one case where the transparent strip is not
trimmed, so a tiled bar shows its gaps.

### Using your own artwork

Any picture can become panel artwork, but it has to be in a format WoW can load: a `.tga` or `.blp`
sitting inside an addon folder, addressed the way the game addresses it, e.g.
`Interface\AddOns\MyStuff\art\crest.tga`. The game cannot read `.png` or `.jpg` at all, and a path
it cannot resolve draws nothing and raises no error.

Converting an image is the fiddly part. The converter this addon's own art was made with is yours to
use, and you do not have to be a developer to run it. It takes any image and writes the TGA the
client wants. Along the way it upscales a source that is too small, adds transparency if the image
has none, and cleans up the halo an upscaler otherwise smears along every edge:

```bash
python3 tools/artwork/artwork_cleaner.py --single ~/Pictures/crest.png
python3 tools/artwork/artwork_cleaner.py --batch  ~/Pictures/art ~/my-wow-art
```

`--single` writes the `.tga` beside the image you pointed it at; `--batch` converts a whole tree
into a folder of your choosing. It needs Python with [Pillow](https://python-pillow.org/) and numpy.
It lives in the [source repo](https://github.com/tusharsaxena/PanelMaster), not in the addon you
downloaded, because the packaged addon carries no build tools. Put the result in a folder under
`Interface\AddOns\`, then point the editor's **Custom path** at it. That box takes any texture path,
so there is nothing else to set up.

A good file is a 32-bit TGA with an alpha channel, square, with a power of two on both axes. WoW
cannot wrap a non-power-of-two texture at all, and the **Tile** fill needs that. The background
should be genuinely transparent (alpha 0, not white and not black), because the panel's own fill,
texture and opacity show through it.

If you would like a piece added to the bundled set instead of keeping it to yourself, open an issue.
The art has to be redistributable. CC0, MIT and public domain are all fine. Non-commercial and
no-derivatives licenses are not, and neither is traced Blizzard art submitted as your own. The full
conversion guide, including how to pick good sources, is in
[`docs/artwork-spec.md`](docs/artwork-spec.md).

## FAQ

| Question | Answer |
|----------|--------|
| Does this move my frames around? | No. It never touches another addon's frames, or Blizzard's. It only draws its own rectangles behind them. If you want a frame moved, you still move it with whatever addon owns it. Panel Master just puts something nice behind it. |
| Can I put a frame *inside* a panel? | No, and that is on purpose. A panel is scenery, and nothing is ever parented into it. |
| Will a panel block my clicks? | Not when locked. A locked panel ignores the mouse completely, so clicks, tooltips and keybinds all pass straight through to whatever is on top of it. It only takes the mouse while you have the screen unlocked, which is the whole point of unlocking. |
| Do my panels follow me to my alts? | Yes, by default. Every character starts on the same shared profile, so a layout you build once shows up everywhere. If you want one character to differ, give it its own profile on the **Profiles** page. |
| How many panels can I have? | As many as you like. They are cheap: a panel is a handful of flat textures and it costs nothing while it sits there. |
| There is so much artwork bundled with this addon. Will it affect my performance? | No. The bundled art costs disk space and nothing else. WoW does not load a texture because it is sitting in the addon folder. It loads one when something on screen asks for it, so the only art in memory is the art your panels are actually drawing. While you play, a hundred unused pieces cost the client the same as none at all. |
| Do I need Sunn - Viewport Art installed? | Only if you want its themes in the artwork list. If you have its packs, Panel Master reads them straight off your disk, and Sunn itself does not even have to be enabled. Nothing is bundled or copied. |
| Does it work without any other addons? | Yes. It is self-contained and needs neither ElvUI nor any other suite. It runs fine alongside them; it just never depends on one. |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| I made a panel and cannot see it | There are three usual causes. It might be behind something opaque: run `/pm unlock`, which outlines and names every panel regardless. It might be switched off, so check `/pm panels`, where a disabled panel is listed in gray. Or the whole addon is off, in which case `/pm panels` tells you so and names `/pm enable`. |
| A panel has ended up off the edge of the screen | `/pm recover` brings every stray panel back into view. It never runs by itself, so a panel you deliberately parked half off-screen stays exactly where you put it. |
| I unlocked panels but nothing became draggable | You were in combat, so the unlock was queued rather than applied, and you will have seen a gray notice saying so. It happens by itself the moment you leave combat. |
| `/pm config` says it cannot open during combat | That is Blizzard's restriction, not a bug: the game will not let the settings window be switched to while you are fighting. Run it again once you are out. |
| The settings page is covered with "Settings are locked during combat." | Nothing is wrong. Settings cannot be changed while you are in combat, and the page comes back, live and up to date, the moment combat ends. |
| I picked a texture and the panel went plain | That texture came from another addon which is no longer loaded. Panel Master keeps your choice and falls back to a flat fill until the addon is back, so you lose nothing. Pick another texture if you would rather not wait. |
| I picked artwork and nothing appeared | If it was your own file, the path is the likely cause. WoW loads a `.tga` or `.blp` only from inside an addon folder, addressed the way the game addresses it, and a path it cannot resolve draws nothing and raises no error. A typo looks exactly like having picked **None**. Check that the file is a power of two on both sides too, because one that is not may fail to load outright. If it is a bundled piece and *still* nothing shows, check the **Draw layer**. **Behind background** puts the art under the panel's own fill, which hides it unless that fill is transparent. |
| The addon will not let me create a panel with a name | Two panels cannot share a frame name, and the frame name ignores punctuation and spacing, so "Chat BG" and "Chat-BG" want the same one. Pick something that differs by more than punctuation. It can also happen with a name that looks free. A panel *created* as "Alpha" and later renamed still holds `PanelMaster_Panel_Alpha`, and the message names whichever panel is holding it. Only creating a panel is refused for this reason, never renaming one. |
| I renamed a panel and want to know its frame name | Renaming does not change it, so anything anchored to the panel still works. The frame name still reflects the name the panel was *created* with, though, so you can no longer work it out. Hover the **Panel name** box in the settings window and it shows you. |
| I cannot address a panel whose name has spaces | `/pm panel` and `/pm rename` read only the first word as the name. Use the Panels page in the settings window for those, or give the panel a one-word name. |
| I dragged a panel and it jumped somewhere slightly different | Snap-to-grid is on. Turn it off (`/pm set settings.snapToGrid false`) or make the grid finer (`/pm set settings.gridSize 1`). |
| Something looks wrong and I want to report it | Follow [Reporting a bug](#reporting-a-bug) below. |

## Reporting a bug

1. Type `/pm debug on` and reproduce the bug.
2. Type `/pm diagnostics`.
3. If the debug window isn't open, open it with `/pm debug`. Press **Copy**, copy the entire output, and include it with your bug report.

The report is added after the debug trace in the same window, so one copy carries both.

## Issues and feature requests

Bugs and feature requests are tracked at
[github.com/tusharsaxena/PanelMaster/issues](https://github.com/tusharsaxena/PanelMaster/issues).
Please file them there rather than in comments, because that is the one place the project's to-do
list lives. If it looks like a bug, follow [Reporting a bug](#reporting-a-bug) above.

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| 1.1.1 | 2026-09-11 | - A rebuild of 1.1.0 with no functional changes: the release build was re-triggered |
| 1.1.0 | 2026-09-10 | - Page-wide actions moved onto a **General** first tab, and **Create** and **Edit** now sit above the tab strip<br>- Fixed the page band failing when it was built before the canvas existed<br>- Fixed the landing tagline wrapping onto a second line<br>- The **Defaults** tooltip no longer implies your panels are safe from the reset<br>- Updated for game patch 12.1.0 |
| 1.0.0 | 2026-08-07 | - First release: create, place and style as many backdrop panels as you like<br>- LibSharedMedia background and border textures, with a class-color option for both<br>- Accent bars along any edge, with their own texture, border and class color<br>- Per-panel scale, mouseover-only fade, and all eight frame strata<br>- Per-panel artwork from the bundled catalog, your own texture, or a Sunn - Viewport Art pack you already own, with tint, desaturate, blend mode, fill, position, scale, rotation, flip, draw layer and fit-to-artwork<br>- Fixed frame names so other addons can anchor to a panel, unaffected by renaming<br>- Global and per-panel unlock with snap-to-grid, test mode and copy-settings-between-panels<br>- Full command-line control and AceDB profiles |

## Credits

The bundled panel artwork comes from [warcraft.wiki.gg](https://warcraft.wiki.gg/), AI-upscaled to
the sizes the client wants and redistributed under
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), the same license as the originals.

