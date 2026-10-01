# Smoke tests — Ka0s Panel Master

In-client checks for what the headless suite ([`testing.md`](testing.md)) cannot reach: how a panel
actually looks, dragging with a real mouse, layering against other addons' frames, the settings
window, the debug console, combat, a second character and a missing library. The unit suites cover
the logic; this page covers the pixels. Run it before tagging a release, after any change to
`modules/Canvas.lua`, `modules/Artwork.lua`, `modules/ArtworkGeometry.lua`, `modules/Unlock.lua`,
`settings/Panel.lua`, `settings/PanelEditor.lua` or `settings/PanelEditorTabs.lua`, and whenever the
`## Interface:` is bumped. Start from the state in **Before you start**, turn debug logging on where a
step says so, and record each check on its `Result:` line (date, PASS or FAIL, who, and what you saw
when it failed). Check IDs are `<THEME>-<n>`; an ID is never reused or renumbered, and a new check
takes the next free number in its theme. The **Non-English client** section needs a deDE or frFR
client and is run when one is available, not per release.

## Index

| IDs | Theme | What it covers |
|---|---|---|
| INSTALL-1 to 8 | Install and load | First login, version, standalone, raw string keys, the old test-mode sweep, the `[Init]` version |
| SLASH-1 to 7 | Slash commands | Bare `/pm`, help and the landing list, unknown verbs, `set` clamps and refusals, `/pm list` |
| FRAME-1 to 29 | Panels | Create, drag, lock, click-through, snapping, default sizes, master scale, recovery, frame names, rename, copy, reset, delete |
| LOOK-1 to 29 | Appearance | Colors, borders, textures, color pickers, border offset, class color, mouseover fade |
| ACCENT-1 to 14 | Accent bar | The BenikUI-style strip: edges, size, color, texture, its border, opacity |
| ART-1 to 30 | Artwork | The bundled catalog, fills, layers, color, custom paths, Sunn Viewport Art packs |
| PANEL-1 to 32 | Settings panel | General tabs, Master controls, resets, the Panels page band and editor, dropdowns, the tab strip, panel writes through the schema seam |
| PROFILE-1 to 18 | Profiles | The shared Default, the Profiles page, session state across a switch, the `/pm profile` verb |
| STATE-1 to 7 | Enable and disable | The master switch, live and refused verbs while disabled, the total stand-down |
| COMBAT-1 to 6 | Combat | Queued unlocks, the settings lockout, General visibility |
| DIAG-1 to 30 | Debug console and diagnostics | Console chrome, log lines, copy and clear, the diagnostics report, resizing the console and its copy window, the Diagnostics link, the report turning logging on, the library's own refusal, edge and at-enable lines |
| LAUNCH-1 to 12 | Launcher | Minimap button, its menu and tooltip, the account-wide button state, broker rows |
| DEGRADED-1 to 14 | Library-absent install | What still works and what explains itself without `libs/LibKa0s` |
| LOC-1 to 5 | Non-English client | Panel names with non-ASCII letters: slugs, case folding, sort, round trip |

## Before you start

- `/console scriptErrors 1`, then `/reload`, then `/pm resetall` and confirm. That is a **profile
  reset**: the settings and the panels on the current profile both go, so no separate panel wipe is
  needed.
- `<name>` in a step means any panel you have made. `/pm panel <name> ...` reads only the first
  word as the name, so use a one-word panel for those steps (FRAME-1's `Chat BG` cannot be addressed
  there). Several themes need two or three panels; make them with `/pm new <name>`.
- COMBAT and several other checks need a training dummy. PROFILE-1 needs a second character, and
  LOOK-23 a character of a different class.
- Optional, each only for the checks that name it: another Ka0s addon with a settings page and a debug
  console (DIAG-1, DIAG-23, PANEL-3, PANEL-4, PANEL-12, DEGRADED-13), KickCD for its Icons page (PANEL-14),
  KickCD, AbsorbTracker, ConsumableMaster and MultiMeters together (LOOK-10), a UI skin
  such as ElvUI (INSTALL-6), another addon that registers an LSM texture, such as ElvUI, WeakAuras,
  Details or SharedMedia (LOOK-13), Titan Panel, ElvUI or Bazooka (LAUNCH-12), Sunn - Viewport Art and
  at least one of its packs (ART-14 to ART-30; ART-13 is the check with no Sunn folder installed),
  and a deDE or frFR client (LOC).

## INSTALL

- **INSTALL-1. First login.** On a fresh install, log in → no Lua error, and nothing at all on screen:
  a fresh install draws no panels. Result:
- **INSTALL-2. Version.** `/pm version` → `[PM] v1.2.0`, matching the TOC's `## Version`. Result:
- **INSTALL-3. Empty panel list.** `/pm panels` on a fresh profile → "No panels yet", suggesting
  `/pm new`. Result:
- **INSTALL-4. No raw string keys on any surface.** Walk `/pm config` (landing page, **General**,
  **Panels**, **Profiles**: every label, tooltip, heading, the breadcrumb and the **Defaults**
  button), the `/pm debug` console (title `Panel Master — Debug`, the `Debug: OFF` toggle, the
  `N / 3000 lines` counter, and the copy window's title `Copy log — Ctrl+C, then Esc`), and `/pm help`,
  `/pm list`, `/pm version` in chat → not one `SCREAMING_SNAKE_CASE` string anywhere. **Fail:**
  anything reading `DEBUG_ON`, `COPY_TITLE`, `LINES`, `LIST_HEADER`, `DEFAULTS_LABEL` or similar,
  which means a library descriptor was handed `NS.L` and every key renders as itself at once. Result:
- **INSTALL-5. Standalone.** Disable every addon except PanelMaster and its libraries, `/reload` → it
  loads and behaves identically; no other addon is a dependency. Result:
- **INSTALL-6. Skinned Defaults button.** With a UI skin (ElvUI or similar) enabled, open
  `/pm config` → the **Defaults** button is skinned like the other AceGUI widgets, not left on stock
  red art. Result:
- **INSTALL-7. Old test-mode samples are swept.** Only with SavedVariables from a build that still had
  test mode, saved with it on: log in → `/pm panels` lists no `Preview: *` panels. The sweep runs at
  load, before `/pm debug on` can be typed, and logging is session-only (DIAG-12), so there is no
  `[Preview]` line to look for. Result:
- **INSTALL-8. The `[Init]` line reports the packaged version.** In the **installed** copy under
  `Interface/AddOns/PanelMaster/` (never the repo), set `PanelMaster.toc`'s `## Version:` to
  `1.2.0-smoke`. Log in, `/pm debug on`, read the `[Init]` line in the console (it is not echoed
  to chat), then `/pm version`; afterwards restore the TOC and `/reload` → the `[Init]` line reads
  `PanelMaster v1.2.0-smoke, schema v2, profile '<yours>', N panels` and `/pm version` reads
  `[PM] v1.2.0-smoke`. **Fail:** an `[Init]` line reading `v1.2.0` while `/pm version` reads
  `v1.2.0-smoke`: the manifest read had not resolved when the line was built, and that line is the
  one a user pastes into a bug report. `tests/test_database.lua` proves the line's content against a
  mock; only the client can witness the timing. Result:

## SLASH

- **SLASH-1. Bare `/pm`.** `/pm` → the settings window opens on the **Ka0s Panel Master** landing
  page, not a sub-page, and nothing prints. Result:
- **SLASH-2. Help index.** `/pm help` → a header `v1.2.0 — slash commands (/panelmaster is an alias
  for /pm)`, then one row per command indented two spaces, every line prefixed with a cyan `[PM]`,
  no trailing colons, and a `profile` row reading *List profiles, or switch to one: profile
  <name>*. Result:
- **SLASH-3. Landing list matches help.** `/pm config` → the landing page shows the logo, the tagline
  and the command list. Each row reads like `/pm config — Open settings`, one space either side of a
  gold-to-white dash, and the list is **identical** to `/pm help`'s rows minus their indent. Compare
  them directly. Result:
- **SLASH-4. `test` is not a verb.** `/pm test` → an unknown-command answer and nothing on screen.
  `/pm config` → **General ▸ Master controls** has no **Test mode** row. Unlocking is this addon's
  test mode (`options-ui-§15`). Result:
- **SLASH-5. Out-of-range numbers clamp.** `/pm set settings.gridSize 99999` → it clamps to `64 px`
  and the echo reports the clamped value. `/pm reset settings.gridSize` afterwards. Result:
- **SLASH-6. A bad value explains itself.** `/pm set settings.snapToGrid banana` → two lines:
  `Invalid value for settings.snapToGrid`, then the reason indented beneath it. Nothing is
  written. Result:
- **SLASH-7. `/pm list`.** `/pm list` → a green header, azure `[group]` headings in tab order
  (`Master controls`, `Editing`, `New panels`), four-space-indented rows, and grid size reading
  `4 px`. Result:

## FRAME

- **FRAME-1. Create.** `/pm new Chat BG` → a confirmation naming the panel and suggesting
  `/pm unlock`. Result:
- **FRAME-2. Unlock and drag.** `/pm unlock` → the panel appears with a gold outline and its name in
  the middle. Drag it behind your chat frame → it follows the mouse smoothly and stays where you drop
  it. Result:
- **FRAME-3. Lock and click-through.** `/pm lock` → the outline and label vanish, leaving a plain
  block. Click something in the chat frame behind it → the click lands on the chat frame; a locked
  panel is completely mouse-transparent. Result:
- **FRAME-4. Behind the action bars.** Place a panel behind your action bars, `/pm panel <name> strata
  BACKGROUND`, `/pm lock` → the bars are fully visible and usable on top of it; the panel never takes
  a click, a keybind or a tooltip. Result:
- **FRAME-5. Position persists, unlock does not.** After FRAME-2, `/reload` → the panel is exactly
  where you left it and panels are **locked** again (unlock is session-only). Result:
- **FRAME-6. Snapping.** `/pm set settings.gridSize 32`, `/pm set settings.snapToGrid true`,
  `/pm unlock`, drag a panel slowly → on release it jumps to a 32-unit multiple, and
  `/pm panel <name> x` prints a value divisible by 32. `/pm set settings.snapToGrid false`, drag
  again → it lands wherever you dropped it. `/pm reset settings.gridSize` and
  `/pm reset settings.snapToGrid` afterwards. Result:
- **FRAME-7. Unlock outline thickness.** On a fresh profile `/pm get settings.unlockOutlineSize` →
  `2 px`, and `/pm unlock` draws the usual hairline. `/pm set settings.unlockOutlineSize 8` **while
  unlocked** → every unlocked outline thickens at once, with no `/reload` and no re-unlock.
  `/pm reset settings.unlockOutlineSize` → back to `2 px`. Result:
- **FRAME-8. The outline is never invisible.** `/pm set settings.unlockOutlineSize 0` → clamps to
  `1 px` (and `400` to `12 px`); an outline of 0 is never stored. Then hand-edit
  `unlockOutlineSize = 0` into `PanelMaster.lua` under `WTF/.../SavedVariables`, log in and
  `/pm unlock` → the outline is drawn at **1**, not 0: the value is clamped on the way out as well.
  Reset it afterwards. Result:
- **FRAME-9. Default size of a new panel.** `/pm get settings.defaultWidth` and
  `settings.defaultHeight` → `240 px` and `120 px`; a new panel is that size. `/pm set
  settings.defaultWidth 500`, `/pm set settings.defaultHeight 60`, `/pm new Wide` → a 500x60 panel,
  and **every existing panel is untouched**. Widen it, then press **Reset** on its **General** tab on
  the Panels page → back at **500x60**, not 240x120: a reset panel and a new one land on the same
  state. Reset both settings afterwards. Result:
- **FRAME-10. One panel disabled.** `/pm panel <name> enabled false` → it vanishes but is still
  listed, dimmed, in `/pm panels`. `/pm unlock` → it is **shown anyway** with its outline and label,
  since you cannot move what you cannot see. `/pm lock` → it disappears again. Result:
- **FRAME-11. The unlock overlay draws on top.** On a panel with the default background and
  **Artwork** set to **None**, and two more panels in different colors, `/pm unlock` → every panel
  shows its gold outline and name clearly **on top of** its fill. **Fail:** a dim or invisible
  outline, which means the overlay fell behind the fill. Result:
- **FRAME-12. Level stride.** Two overlapping panels in the same strata. On **Panels**, select the
  first and set **Position and size ▸ Frame level** to 0, then the second to 1 (or, from chat,
  `/pm panel <first> level 0` and `/pm panel <second> level 1`) → the level-1 panel draws entirely in
  front, covering the other's accent bar and border, not just part of them. Set the second to 3 → the
  same. **Fail:** interleaved layers. Result: pass (owner, 2026-10-02)
- **FRAME-13. Master scale and alpha.** **General ▸ Master controls ▸ Master scale** to 1.5 → every
  panel grows together, border, accent bars and artwork included, and each panel's own **Panel
  scale** on the Panels page still reads what you set: the two multiply. **Master alpha** to 0.4 →
  every panel fades on top of its own opacity. Put both back to 1. Result:
- **FRAME-14. Reset position.** **Master controls ▸ Reset position** → every panel jumps to the middle
  of the screen, a chat line says how many moved, and nothing else about any panel changes (size,
  colors, artwork). Result:
- **FRAME-15. Off-screen recovery.** `/pm panel <name> x 9000` → the panel disappears off the right
  edge. `/pm recover` → "moved 1 panel back on screen" and it reappears. `/pm recover` again →
  "every panel is already on screen". Result:
- **FRAME-16. Recovery never runs by itself.** Park a panel half off-screen, `/reload` → it is still
  where you put it. Result:
- **FRAME-17. Recovery measures in scaled units.** Master scale 0.5, drag a panel into the far right
  half of the screen, `/pm recover` → "every panel is already on screen" and it does not move. Master
  scale 2, `/pm panel <name> x 1500` on a TOPLEFT-anchored panel, `/pm recover` → "moved 1 panel back
  on screen" and it comes into view. Master scale back to 1. Result:
- **FRAME-18. The frame name exists.** Create **Chat BG**, open **Panels**, and hover the **Panel
  name** box → its tooltip includes `Frame name: PanelMaster_Panel_Chat_BG`. `/run
  print(PanelMaster_Panel_Chat_BG:GetWidth())` → the panel's width. This name is the addon's public
  contract. Result:
- **FRAME-19. Anchoring to it.**
  `/run local f=CreateFrame("Frame",nil,UIParent);f:SetSize(20,20);local t=f:CreateTexture();t:SetAllPoints();t:SetColorTexture(1,0,0);f:SetPoint("TOPLEFT","PanelMaster_Panel_Chat_BG","TOPLEFT",0,0)`
  → a red square at the panel's top-left corner that **follows it** when you unlock and drag the
  panel. Result:
- **FRAME-20. A colliding slug is refused.** `/pm new Chat-BG` → refused, with a message naming the
  frame name it would have collided on. Result:
- **FRAME-21. Rename keeps the frame name.** On **Panels**, change **Panel name** from **Chat BG** to
  **Chat Backdrop** and press Enter → the picker entry updates, the tooltip still reads
  `PanelMaster_Panel_Chat_BG`, and FRAME-19's red square keeps following the panel. Result:
- **FRAME-22. Rename to a taken name.** Rename a panel to another panel's exact name → a cyan-tagged
  error, and the box reverts to the old name. Renaming to a name that only **slugs** like another
  (`Chat-BG` while `Chat BG` exists) is allowed, since no frame name is claimed. Result:
- **FRAME-23. Renames abandon no frames.** Rename a panel back and forth several times, then
  `/pm diagnostics` → the pooled count on the `frames:` line has not grown. Result:
- **FRAME-24. A freed name stays claimed.** After FRAME-21, `/pm new Chat BG` → refused, naming
  **Chat Backdrop** as the panel still holding `PanelMaster_Panel_Chat_BG`. Result:
- **FRAME-25. The frame name is stored.** `/reload` and repeat FRAME-18's `/run` → the same name
  answers; it is persisted on the record, not recomputed. Result:
- **FRAME-26. Copy settings from another panel.** Make two panels; style the first heavily (size,
  textures, both colors, border, accent bar, artwork) and move the second somewhere else. On the
  second, pick the first in **Copy settings from panel** (the **General** tab's first row) → the
  second takes the first's whole appearance, artwork **and size**, and a cyan-tagged line names the
  source. It does **not** move, its name and frame name are unchanged, and the dropdown snaps back to
  empty. Change a color on the first → the second does not follow (a snapshot, not a link). Result:
- **FRAME-27. Copy with a lone panel.** Delete all but one panel → **Copy settings from panel** is
  disabled, with a tooltip saying to make another panel first. Result:
- **FRAME-28. Reset one panel.** Resize, move, retexture, recolor and set a panel to mouseover, then
  press **Reset** on its **General** tab → it returns to a new panel's look **and position** (the
  middle of the screen), every editor control re-reads, the name and frame name are unchanged, anything
  anchored to it stays anchored, and other panels are untouched. Result:
- **FRAME-29. Delete-all asks first, from both entry points.** `/pm new GuardA`, `/pm new GuardB`.
  `/pm panel deleteall` → a confirm popup; **No** → both survive. **Panels ▸ Defaults** → the same
  popup; **No** → both survive. **Yes** from either → both gone, and chat says `deleted 2 panels.`
  Result:

## LOOK

- **LOOK-1. Background color.** `/pm panel <name> bgColor 1,0,0,0.5` → translucent red at once.
  Result:
- **LOOK-2. Byte colors with a fractional alpha.** `/pm panel <name> bgColor 255,0,0,0.5` → the
  identical translucent red as LOOK-1, echoing `1.00,0.00,0.00,0.50`. `/pm panel <name> bgColor
  255,0,0,1` → the same red, **fully opaque**, echoing `1.00,0.00,0.00,1.00`. `/pm panel <name>
  bgColor 255,0,0,128` → half-transparent, echoing `0.50`. **Fail:** the alpha-1 form leaves the panel
  invisible, the old bug where the byte scale chosen from R, G and B was applied to alpha too. Result:
- **LOOK-3. Border.** `/pm panel <name> borderSize 6`, `/pm panel <name> borderColor 0,1,0,1` → a
  thick green border whose four edges meet cleanly at the corners, with no darker overlap squares.
  `/pm panel <name> borderSize 0` → the border disappears, leaving a plain fill. Result:
- **LOOK-4. Opacity clamps.** `/pm panel <name> alpha 0.2` → it fades. `/pm panel <name> alpha 9` →
  the echo reads `1.00`. Result:
- **LOOK-5. Strata.** `/pm panel <name> strata HIGH` → it covers UI it sat behind before.
  `strata BACKGROUND` → it drops behind again. Result:
- **LOOK-6. Shared media is registered.** With PanelMaster the only Ka0s addon enabled (the names
  live in the shared LibSharedMedia, so any other Ka0s addon registers them too), the **Accent bar**
  tab's **Bar texture** dropdown lists `Ka0s Gradient`, `Ka0s Underline 1`, `2`, `4` and `Ka0s
  Overline 1`, `2`, `4`, and nothing you had chosen moved. PanelMaster has no font dropdown, so
  `/dump LibStub("LibSharedMedia-3.0"):IsValid("font", "JetBrains Mono")` → `true`. **Fail:** a
  name absent on a complete install: `core/MediaSetup.lua` never reached `Media.RegisterLSM`.
  Result:
- **LOOK-7. Background texture.** **Panels ▸ Background and border ▸ Background texture** → a list
  with a preview swatch per entry, `Solid` among them, plus textures other addons registered. Pick
  `Blizzard Parchment` → the panel fills with it at once, tinted by its background color. Reopen the
  dropdown → it still reads your pick. **Fail:** it reverted while the panel changed (the LSM
  widget's value push; `settings-panel.md` ▸ *Three widget workarounds*). Result:
- **LOOK-8. Border style.** **Border style** → `Blizzard Tooltip` → a decorative edge with correct
  corners, not four flat bars. **Border thickness (px)** to 8 and back to 1 → the edge scales.
  **Border style** → `None` → the border disappears while the thickness stays; set it back and the
  border returns. Result:
- **LOOK-9. The Border dropdown sits flush.** With PanelMaster alone, the closed **Border style**
  dropdown is flush with the controls stacked with it, with no ~42px gap on its left. **Fail:** a
  gap, meaning `lib.__PatchLSM30Border()` is not taking effect. This passing alone proves nothing
  about LOOK-10. Result:
- **LOOK-10. The Border dropdown with five Ka0s addons loaded.** Enable KickCD, PanelMaster,
  AbsorbTracker, ConsumableMaster and MultiMeters, log in, and open each addon's Border dropdown
  (here: **Panels** → a panel → **Border style**). Change the load order (disable and re-enable
  addons, or rename folders), `/reload`, and walk all five again → in every one the closed control is
  flush with no ~42px gap, and opening it still draws the per-row previews; nothing differs between
  passes, and no Lua error. **Fail:** any dropdown that differs from the other four, or changes with
  load order: AceGUI's `LSM30_Border` slot is process-global, and one library-level registration is
  what makes the answer independent of who loaded last. Result:
- **LOOK-11. No background texture.** **Background texture** → `None` → the fill disappears and the
  border stays. Result:
- **LOOK-12. Appearance persists.** Set textures, both colors, a border offset and accent settings on
  a panel, `/reload` → every choice survived. Result:
- **LOOK-13. A texture whose addon is gone.** Pick a texture another addon supplies, disable that
  addon, `/reload` → the panel renders **plain** (not invisible, no error). Re-enable the addon →
  the texture comes straight back; the choice was never overwritten. Result:
- **LOOK-14. Color pickers apply without the opacity slider.** Click the **Background color** swatch,
  pick bright green **without touching the opacity slider**, and click **OK** → the swatch **and** the
  panel are green. Drag inside the color wheel before OK → the panel updates live. Repeat for
  **Border color** with a thickness of 4 or more → the border takes the color. **Fail:** a green
  swatch over an unchanged panel (the picker bound only `OnValueConfirmed`). The headless suite
  stubs AceGUI, so no unit test covers this. Result:
- **LOOK-15. Picker Cancel.** Open a picker, change the color, press **Cancel** → the panel returns to
  its previous color. Result:
- **LOOK-16. Picker opacity multiplies.** Change a color and drag the picker's opacity slider → both
  apply, and the panel's opacity is the picker alpha times **Panel opacity** (on **Opacity and
  fade**). Result:
- **LOOK-17. Border offset.** With a 2 to 4px border, drag **Border offset** positive → the border
  moves outward, leaving a gap (a halo); negative → inward over the fill (an inset); 0 → exactly on
  the edge. With a non-zero offset, drag the panel and change **Frame strata** → the border keeps its
  offset and stays with the panel. Result:
- **LOOK-18. Class color on the background.** Tick **Use class color** next to **Background color** →
  the panel takes your class color, its opacity is unchanged, and **Panel opacity** still works. The
  picker stays **enabled**, its label stays **Background color** with no `(opacity)` suffix, and its
  tooltip ends with *not read while Use class color is on, except for its opacity, which always
  applies*. Result:
- **LOOK-19. Class color is per control and reversible.** Also tick it next to **Border color**, then
  untick the background one → the border stays class-colored. Untick both → the original colors
  return exactly; they were never overwritten. Result:
- **LOOK-20. The picker still sets opacity under class color.** With **Use class color** ticked, all
  five swatches (**Background color**, **Border color** twice, **Bar color**, **Artwork color**) stay
  enabled with their plain label and a tooltip saying the opacity still applies. Open one and drag
  its opacity slider → the class-colored fill or border gets more or less solid. Result:
- **LOOK-21. The composed blocks.** On **Background and border**, and on **Accent bar** for the bar
  and its border, work every control: pick a style or texture, drag the thickness, pick a color,
  tick and untick **Use class color**, drag the offset (and **Bar opacity**, **Bar thickness**,
  **Bar offset**) → each applies at once, a new style or texture name shows in its dropdown straight
  away, **Border thickness (px)** reaches **32**, **Bar opacity** reads as 0 to 1 (not a
  percentage), and each control keeps its tooltip. `/reload` → every value persisted. Result:
- **LOOK-22. Border definition.** Compare a 1px border in a picked bright color against your class
  color at the same opacity and size → any softness tracks contrast (a darker class color can look
  softer). **Fail:** a visible difference at matched luminance. At **Border thickness (px)** 2 any
  color is crisp regardless of UI scale. Result:
- **LOOK-23. Another class.** Log in on a character of a different class → its class-colored panels
  show that class's color. Result:
- **LOOK-24. Mouseover fade.** On **Opacity and fade**, tick **Show on mouseover only** with **Faded
  opacity** `0`. Move the cursor away → the panel disappears. Move over where it was → it appears at
  its normal opacity within about a tenth of a second, without stutter. Result:
- **LOOK-25. Faded in, still click-through.** With the cursor over the faded-in panel, click
  something behind it → the click lands on the frame underneath. Result:
- **LOOK-26. Faded opacity bounds.** **Faded opacity** `0.3` → it rests dim, not invisible. Set it
  above **Panel opacity** → clamped; the panel never fades *out* on mouseover. Result:
- **LOOK-27. Unlocked panels ignore the fade.** Tick **Unlock** on that panel → it stays fully
  visible regardless of the cursor; untick and the fade resumes. Result:
- **LOOK-28. Many faders are cheap.** Make half a dozen mouseover panels → no measurable frame-rate
  change (one shared 10Hz ticker drives them all). Result:
- **LOOK-29. The fade ticker comes back.** Untick **Show on mouseover only** on **every** panel that
  has it (the last one takes the `OnUpdate` off the shared driver), then tick it on one panel and
  hover → the fade works as in LOOK-24. **Fail:** the panel stays at one opacity for the rest of the
  session. Headless cases call `Canvas.__updateMouseover` directly and never go through the script
  slot, so only the client sees this. Result:

## ACCENT

All per panel, on the **Accent bar** tab of the Panels page.

- **ACCENT-1. The shipped look.** On a new panel → **Enable accent bar** is ticked and a bar runs the
  full width of the **top** edge only: 5px thick, flush against the panel, the **Blizzard** status-bar
  texture, your class color, a 1px black outline. The panel's own border starts at **0**. Result:
- **ACCENT-2. The enable switch.** Untick **Enable accent bar** → the strip vanishes; tick it → it
  returns exactly as before. Result:
- **ACCENT-3. Drawn over the border.** Give the panel a contrasting border of 4 or more → the bar
  draws **over** the border where they meet, and still does after a **Frame strata** change.
  Result:
- **ACCENT-4. Edges.** Tick **Bottom**, **Left** and **Right** in turn → each edge gains a bar
  spanning it in full; all four read as a detached outline. Untick every edge → no bars, and the
  enable switch stays **on** (Top is not re-ticked). Result:
- **ACCENT-5. Bars track a resize.** Drag the Width and Height sliders → every bar still spans its
  whole edge with no gap at either end. Result:
- **ACCENT-6. Thickness and offset.** Raise **Bar thickness** → top and bottom bars get taller, left
  and right wider. **Bar offset** positive → the bars move away from the panel on all sides; 0 →
  flush; negative → they overlap the panel. Result:
- **ACCENT-7. Bar color.** Untick **Use class color** next to **Bar color** → the stored white; pick a
  color → it applies (the same picker as LOOK-14). Result:
- **ACCENT-8. Bar texture.** **Bar texture** → a gradient status-bar texture → it renders tinted by
  the bar color. The list holds **status-bar** textures, not backgrounds. Result:
- **ACCENT-9. The bar's own border.** Under the tab's **Border** heading, **Border thickness (px)**
  to 3 → an outline around each bar. **Border style**, **Border color** and its **Use class color**
  behave like the panel's; **Border offset** works both ways; thickness 0 → the outline goes
  completely. Result:
- **ACCENT-10. Bar opacity.** **Bar opacity** to 0.3 → the bars get see-through while the panel's
  background and border do not. Back to 1 → exactly the solidity the bar color's own alpha gives.
  Result:
- **ACCENT-11. Bars belong to the panel.** **Panel opacity** 0.3 → the bars fade with the panel.
  **Frame strata** change → they move with it. **Show on mouseover only** with **Faded opacity** 0
  → they vanish and reappear with it. Result:
- **ACCENT-12. Bars are click-through.** Click where a bar is drawn → the click lands on whatever is
  behind. Result:
- **ACCENT-13. Deleting leaves nothing behind.** Delete a panel that had bars → no colored strips
  float where it was (they are anchored outside the panel's bounds). Result:
- **ACCENT-14. Edges from the command line.** `/pm panel <name> accentEdges top,left`, then
  `accentEdges none`, then `accentEdges middle` → the first two apply; the third is refused with
  the valid list. Result:

## ART

Run ART-1 first: a malformed `.tga` renders as nothing with no Lua error, which looks the same as
**None**, so every other ART check is meaningless until it passes.

- **ART-1. The catalog loads.** Size a panel around 300x300, open **Artwork**, pick `Class: Death
  Knight` → the emblem appears. Step through every catalog entry → each one draws (the headless
  suite proves a file exists, never that the client decodes it). **None** → a plain block again.
  Result:
- **ART-2. Fill types under resize.** With art on, drag **Width** from minimum to maximum, then
  **Height**, at each fill → **Fit (contain)**: the whole emblem visible, never cropped or distorted.
  **Fill (crop)**: edge to edge, never distorted, overflow cropped evenly. **Stretch**: distorts to
  match (it is meant to). **Native size**: the emblem's size never changes. **Tile**: more copies as
  the panel grows, each the same size. Result:
- **ART-3. Rotation keeps proportions.** **Rotation** `90`, repeat ART-2's width drag at **Fit**,
  **Fill**, **Native size** and **Tile** → turned a quarter-turn, otherwise unchanged. **Fail:** a
  squashed or stretched emblem (the axis transpose regressed). Result:
- **ART-4. Draw layers.** On a panel with a solid opaque background and a thick border: **Draw layer
  → Behind background** → hidden behind the fill (shows through when you lower the background's
  alpha). **Above background** → on the fill, under the border and accent bar. **Above border and
  accent** → covers both. Result:
- **ART-5. Clipping.** **Fill type** `Native size`, **Scale** `4`, drag **X** and **Y** → the art is
  cut off exactly at the panel's edges. The **accent bar still hangs outside** the panel; it is
  deliberately unclipped. Result:
- **ART-6. Blend mode.** **Glow** → the art brightens what is behind it and never darkens anything
  (strongest over a dark panel). **Normal** → it paints over obeying its own transparency. Only these
  two are offered. Result:
- **ART-7. Artwork color.** Change **Artwork color** → the art takes it. **Use class color** → your
  class color. Lower **Opacity** → the art fades independently of the background. Result:
- **ART-8. The color controls stay put.** Page through the artwork dropdown → **Artwork color** and
  **Use class color** are present for **every** piece, and no row below them jumps. Result:
- **ART-9. Desaturate.** On a full-color piece with a strong tint, tick **Desaturate** → the muddy
  average becomes a clean version of your color; untick → the mud returns. On a white-on-black piece
  it makes no visible difference. Result:
- **ART-10. Custom path.** **Artwork** → `Custom path…`, enter
  `Interface\Icons\INV_Misc_QuestionMark` → the question-mark icon renders under the current fill.
  Enter nonsense → nothing draws and **no Lua error**. Clear the box → nothing draws. Result:
- **ART-11. Artwork persists.** Set artwork, a tint, a rotation, a flip and an offset, `/reload` →
  every one survives exactly. Result:
- **ART-12. Artwork from the command line.** `/pm panel <name>` → the `art*` fields print.
  `/pm panel <name> artFill SQUISH` → `error: expected one of: STATIC, STRETCH, FILL, FIT, TILE`, and
  nothing stored. Result:

ART-13 needs no Sunn folder installed at all. ART-14 to ART-30 need Sunn - Viewport Art (SunnArt)
and at least one art pack; skip those without it.

- **ART-13. No Sunn, no Sunn entries.** With **no** Sunn folder installed, **Panels ▸ Artwork** → no
  `Sunn ->` entries anywhere. Result:
- **ART-14. One entry per theme.** Enable SunnArt and a pack, `/reload` → entries grouped under
  `Sunn -> Art Pack 2` (or `Sunn -> Built in`), one per theme under its plain name, and no `(left)`,
  `(middle)` or `(right)` entries. Result:
- **ART-15. The composite draws.** Pick a theme, **Fill** → **Stretch**, panel about 800 x 140 →
  every section draws edge to edge, in order, as one continuous bar. **Fail:** nothing drawn (the
  path does not resolve) or one section stretched across the panel (the composite path did not
  run). Result:
- **ART-16. Seams.** Look where sections meet → no bright line, dark gap or doubled pixel. Result:
- **ART-17. Fit to artwork.** Press **Fit to artwork** → the panel becomes the bar's exact size
  (1536 x 256 for a typical three-section theme) and chat reports both numbers. Drag the panel smaller
  → it does **not** snap back; press the button again → it returns to the art's size. Result:
- **ART-18. Fit follows rotation and scale.** **Rotation** 90°, **Fit to artwork** → 256 x 1536.
  **Scale** `0.5`, press again → every number halves. Result:
- **ART-19. Crop drops whole sections.** **Fill** → **Fill (crop)**, panel much taller than wide →
  the bar covers the panel and the outer sections are cropped away entirely (at a third of the aspect,
  only the middle remains), never thinned to a hairline. Result:
- **ART-20. Rotated sections stack.** **Rotation** 90° → sections stack vertically, section 1 on top,
  and the bar still covers the panel. Result:
- **ART-21. Flip.** Back to 0°, **Flip horizontally** → the section order reverses and each section is
  mirrored. Result:
- **ART-22. Tile repeats the bar.** **Fill** → **Tile**, shrink **Scale** → the whole bar repeats,
  not each section in its own slot; past the cap the repeats stop shrinking. The panel never shows a
  bare strip. Result:
- **ART-23. Tint is even.** Set a **Color** and tick **Desaturate** → every section takes the tint
  equally. Result:
- **ART-24. Back to a single piece.** Switch the panel to a bundled piece → exactly one image, no
  leftover section. Result:
- **ART-25. The transparent strip is trimmed.** A theme with a transparent strip along its top, **Fit
  to artwork** → the art sits flush with no empty band above it. **Tile** → the gaps reappear between
  repeats, which is expected. Result:
- **ART-26. A pack goes away.** Disable the pack addon but not SunnArt, `/reload` → that panel draws no
  artwork, raises no error, and keeps its size. Result:
- **ART-27. SunnArt disabled, packs installed.** Disable **Sunn - Viewport Art** itself, leave the pack
  folders, `/reload` → the official packs' themes are still listed under `Sunn ->` and still draw
  (`modules/SunnArtPacks.lua`'s manifest). **Fail:** an empty dropdown: the folder roster or the
  manifest is not being read. Result:
- **ART-28. Measured, not assumed.** Still with SunnArt disabled, pick **Sunn -> Art Pack 6: Fractal**
  (or Pack 9's **Wrath**), **Fit to artwork** → 1536 x 512 (square sections). A Pack 2 theme still
  fits to 2:1. Result:
- **ART-29. Live names win.** Re-enable SunnArt, `/reload`, and look at a theme you renamed in
  SunnArt's own options → your name, not the manifest's. Result:
- **ART-30. Only installed packs are listed.** Count the `Sunn ->` groups against the `SunnArt*`
  folders in `Interface/AddOns` → they match. Delete or rename one pack folder, `/reload` → that
  group is gone and the rest are untouched, even if SunnArt still remembers the pack. Result:

## PANEL

- **PANEL-1. The General page.** `/pm config` → **General** → a tab strip pinned at the top reading
  **Master controls | Editing | New panels**, the first tab active (drawn as a disabled button), a
  two-column grid with no section headings under it, and a **Defaults** button top-right in the dark
  and gold style, not Blizzard's red stone button (a red one was created too early;
  `options-ui-§5`). Result:
- **PANEL-2. The General tabs.** Click each tab → only that tab's controls show, the strip stays put,
  and clicking the active tab does nothing. **Master controls** has 7 rows plus a **Reset position |
  Reset all settings** button pair; **Editing** has 4 rows, two per line (**Show names while
  unlocked | Snap to grid**, then **Grid size | Unlock outline thickness**), plus a **Recover
  panels** button under the last row; **New panels** has 4. Result:
- **PANEL-3. Master controls in the canonical order.** Two per line: **Enable Ka0s Panel Master |
  General visibility**, **Master scale | Master alpha**, **Lock frame | Debug console**, then
  **Minimap button** alone on a fourth line (PanelMaster has no **Test mode** to pair beside it), then
  the button pair, with nothing else on the tab (`options-ui-§15`). Compare against another Ka0s
  addon → the same rows in the same order, except that an addon with a Test mode pairs it beside
  **Minimap button**. Result:
- **PANEL-4. General page chrome.** The row spacing, the header, the gold divider and the breadcrumb
  `Ka0s Panel Master ▸ General` match the other Ka0s addons' pages. Result:
- **PANEL-5. The scrollbar.** On a page that fits, the scrollbar is **present but grayed out**, and
  the body does not change width as you move between pages and tabs. Result:
- **PANEL-6. Lock frame.** Untick **Lock frame** → the panels unlock exactly as `/pm unlock` does;
  tick it → they lock. It ships ticked and is ticked again after every `/reload`. Result:
- **PANEL-7. The Reset all settings tooltip.** Hover **Reset all settings** → *"Reset the current
  profile to its defaults — the same thing Profiles -> Reset Profile does. Your other profiles are
  not affected."* **Fail:** *"Restore every setting in this addon to its default."* (the Options
  descriptor lost `resetProfile` or `profilesPage`). Result:
- **PANEL-8. Reset all is a profile reset, from all three entry points.** **Reset all settings**, the
  General page's **Defaults** button, and `/pm resetall` each raise the same popup, word for word:
  *"Reset this profile to the addon's defaults? Everything you have configured or added in it is
  discarded — your other profiles are not affected."* **No** → nothing changes. **Yes** → every setting
  is back to shipped **and the panels are gone**, and chat says `this profile reset to defaults` (not
  `All settings reset to defaults`, and not *"your panels are untouched"*). Result:
- **PANEL-9. Defaults button tooltips.** Hover **Defaults** on **General** → *Reset this profile to
  the addon's defaults. Your panels go with it.* On **Panels** → *Delete every panel. This cannot be
  undone.* Result:
- **PANEL-10. The Panels page band.** Click **Panels** → a six-tab strip (**General | Position and
  size | Background and border | Accent bar | Artwork | Opacity and fade**) with **General** active,
  and above it, in the page's chrome band, a **single row**: the **Panel** picker on the left and
  **Create new panel** on the right, separated from the strip by a hairline rule. Neither is a tab or
  in the scroll area, they stay put on every tab, and no second box is drawn around them. **Fail:** a
  band two or three rows deep (`options-ui-§14`). Result:
- **PANEL-11. Panels opened first.** On a fresh login, `/pm config` and click **Panels** before any
  other page → the band holds its one row, and the picker and the create box each take **half the
  band's width**, not a fixed 150 pixels. Resize the Settings window → both follow. Result:
- **PANEL-12. Panels opened after another addon.** On a fresh login, open another addon's settings
  first (for example **AuraMaster ▸ Containers**) and switch a few of its tabs, then open **Panel
  Master ▸ Panels** → the picker and the create box are **visible**, each half the band. **Fail:** a
  band of the right height with nothing in it (a pooled, hidden `SimpleGroup` nobody showed).
  Result:
- **PANEL-13. The empty state.** Delete every panel → the strip and the band stay, at the same height;
  the page reads "No panels yet…"; the create box stays usable; the picker is **grayed out, not gone**;
  and the six acts on the **General** tab are absent. **Fail:** a band that shrinks or loses its row,
  or a page without its strip. Result:
- **PANEL-14. Editor layout.** The picker carries its label and sits beside the create box, with no
  heading naming the selected panel. On **General**, the three rows keep to their own lines, each
  control is half width, and **Delete**'s right border clears the page edge. No boxed border around
  the editor, and no two unrelated controls share a line. Subsection headings (the landing page's
  divider-flanked style): **Background / Border** on *Background and border*, **Bar / Edges /
  Border** on *Accent bar*, **Image / Layout / Appearance** on *Artwork*. On **Opacity and fade**,
  **Panel opacity** and **Faded opacity** share the first row and **Show on mouseover only** sits
  alone on the next. Compare against KickCD's Icons page. Result:
- **PANEL-15. An open dropdown closes when the page scrolls.** Open any dropdown (the panel picker,
  Anchor, Frame strata, a texture picker, or **General**'s **Default frame strata**) and, without
  closing it, scroll the page with the mouse wheel, then with the scrollbar drag → the list closes
  both times and never floats over or outside the window. Reopen it → one click opens it. Result:
- **PANEL-16. The General tab's acts.** **Panels** opens on **General**, whose three rows of two are
  **Panel name** and **Copy settings from panel**, **Enabled** and **Unlock**, **Reset** and
  **Delete**. Walk the other five tabs → none of the six follows you. Back on **General**, with a
  panel picked: tick and untick **Enabled** (the panel goes and returns), tick **Unlock** (only that
  panel grows a handle), press **Reset**, then **Delete** → each acts on the panel the picker shows.
  Pick another panel → the six rebuild against it. **Fail:** an act landing on the previously picked
  panel. The frame name is only on the **Panel name** tooltip, not a label of its own. Result:
- **PANEL-17. The rename box keeps what you type.** Pick a panel, type into **Panel name** without
  pressing Enter, then run `/pm new Interloper` from chat → the new panel appears in the picker and
  your text is still in the box. With nothing typed, `/pm rename <selected panel> Renamed` (a one-word
  old name; the CLI reads the first word) → the box follows to the new name. Result:
- **PANEL-18. The create box.** Type a name and click away without Enter → **nothing is created**.
  Type a name and press **Enter** (or the **Okay** button) → the panel appears in the middle of the
  screen, the box clears, and the editor jumps to it. Result:
- **PANEL-19. Creating a duplicate name.** Type an existing name and press Enter → a cyan-tagged error
  and the text stays in the box for correction. Result:
- **PANEL-20. One editor at a time.** With three panels, switch with the **Panel** picker → exactly
  one editor shows, and the page does not grow as panels are added. Result:
- **PANEL-21. Disabled panels in the picker.** Disable a panel, reopen the picker → it reads
  `<name> (disabled)`. Result:
- **PANEL-22. Controls apply on release.** Drag a panel's width slider and pick a color → the panel
  updates as you release. Result:
- **PANEL-23. Per-panel Unlock.** Tick **Unlock** on the selected panel → only that panel grows an
  outline and drag handle; drag it, untick. With a panel open on **Panels**, untick **General ▸ Lock
  frame** → back on **Panels**, **Unlock** shows ticked and grayed; tick **Lock frame** → unticked and
  enabled again. Result:
- **PANEL-24. Delete in the editor.** Click **Delete** → the panel leaves the screen and the picker,
  and the editor falls back to another panel rather than going blank. Result:
- **PANEL-25. The picker rebuilds on show.** Close the options window, `/pm new Offscreen`, reopen
  **Panels** → the new panel is in the picker. Result:
- **PANEL-26. The tab strip survives pooling.** `/pm` → **Panels**, and cycle every tab three times,
  ending on the first. On each pass the label is that tab's own, the selected tab is the one you
  pressed, and the band height does not move. Then `Esc`, `/pm` again, and cycle once more →
  everything still named and selected correctly. **Fail:** a label carried over from another tab, a
  highlight on the wrong button, a body under the wrong tab, or a band that changes height: the
  per-`ctx` pool handed back a frame it did not finish dressing. The headless mock answers
  `GetHeight` with 0, so no automated check sees this. Result:
- **PANEL-27. The Frame level slider.** Two overlapping panels in the same strata, with one-word
  names. `/pm panel <first> level 7`, then open **Panels**, select it and go to **Position and
  size** → **Frame level** sits on its own half-width row directly under **Frame strata** and reads
  **7**; its tooltip says strata decides first and level orders panels within one strata. Drag the
  second panel's **Frame level** above 7 → it moves in front of the first live, as you release, and
  back below 7 → behind again. `/pm panel <second> level 150` → the slider reads **100**. Result: pass (owner, 2026-10-02)
- **PANEL-28. Every editor control still repaints live.** Select a panel and visit each of the six
  editor tabs (**General**, **Position and size**, **Background and border**, **Accent bar**,
  **Artwork**, **Opacity and fade**). Change every control once: each slider on release, each
  dropdown, each checkbox, each color swatch → the panel changes on screen at once, and the control
  reads back what you set when you leave the tab and come back. No Lua error. Result: pass (owner, 2026-10-02)
- **PANEL-29. A drag persists.** Unlock, drag a panel into the top-left corner (the frame re-anchors to
  the corner it ends nearest), lock, `/reload` → the panel is exactly where you left it, and
  `/pm panel <name>` shows the new `point`, `relPoint`, `x` and `y`. Result: pass (owner, 2026-10-02)
- **PANEL-30. One `[Set]` line per panel write.** `/pm debug on`, open the console. Drag a panel's
  **Width** slider and release → exactly one line, `[Set] panel.width = <n> on '<name>'`, and no
  `[Panel]` line for it. Drag the panel in unlock mode → four `[Set] panel.…` lines (point,
  relPoint, x, y) naming it. Then press **Reset** on the General tab → one
  `[Set] reset '<name>': N rows`; **Copy from** another panel → one `[Set] copy from '<a>' to '<b>':
  N rows`; `/pm recover` with a panel off-screen → one `[Set] recover positions: N rows`; **Master
  controls ▸ Reset position** → one `[Set] reset positions: N rows`. Result: pass (owner, 2026-10-02)
- **PANEL-31. Panel fields are not profile settings.** `/pm list` → no `panel.` row anywhere in the
  listing, and **General** has no extra tab. `/pm set panel.width 500` → refused as an unknown
  setting, and no panel changes. `/pm panel <name> width 500` → that panel takes it. Result: pass (owner, 2026-10-02)
- **PANEL-32. The panel still opens with the folder name on its descriptor.** `/reload`, then
  `/pm config` → no Lua error on load or on open, and the General, Panels and Profiles pages each
  render exactly as before. No list on these pages carries help marks, so there is no art to check:
  `settings/OptionsSetup.lua` now passes `addonName = addonName,` to the Options descriptor
  (LibKa0s#42), which is latent until a list here gains a help line. Result:

## PROFILE

- **PROFILE-1. Every character starts on the shared Default.** Create a couple of panels, log in on an
  alt → the **same** panels (the `true` third argument to `AceDB:New`). Back on the first character →
  the panels are exactly as you left them. Result:
- **PROFILE-2. The Profiles page.** `/pm config` → **Profiles** → Ace's standard profile UI (Reset
  Profile, the current profile, New and Existing Profiles, Copy From, Delete a Profile), and **no
  Defaults** button in the header. Result:
- **PROFILE-3. A new profile clears the screen.** Type a new profile name and press Enter → it is
  created and switched to, and the screen clears of panels **at once**. **Fail:** the old panels stay
  (the profile callbacks did not run). Result:
- **PROFILE-4. Switching back.** Make a panel on the new profile, then switch back via **Existing
  Profiles** → the original panels return and the new profile's panel disappears, at once, with every
  setting and artwork choice intact. Result:
- **PROFILE-5. Copy From.** **Copy From** the other profile → its panels appear immediately. Result:
- **PROFILE-6. Reset Profile.** Press **Reset Profile** → every panel on this profile goes. Result:
- **PROFILE-7. The profile persists.** Switch to a profile, `/reload` → still on it, with its panels.
  Result:
- **PROFILE-8. The Panels page follows a switch.** Open **Panels**, switch profile on the Profiles
  page, come back → the picker **and** **Copy settings from panel** list the new profile's panels, and
  the editor shows one of them, not a panel you never chose. Result:
- **PROFILE-9. A per-panel unlock does not cross a switch.** Unlock one panel with its **Unlock**
  control, switch profile → none of the incoming profile's panels is unlocked (panel ids restart per
  profile). Result:
- **PROFILE-10. Swapped names leave no orphans.** On profile A create `Alpha` then `Xray`; on profile
  B create `Xray` then `Alpha`. Switch between them five times, `/pm diagnostics` → the `frames: N
  active, M pooled, 0 orphaned` line shows no orphans, and `/framestack` over each panel names the
  expected `PanelMaster_Panel_<slug>`. Result:
- **PROFILE-11. `/pm profile` lists the profiles.** With two or three profiles, `/pm profile` → a
  green `Profiles` header, one row per profile indented two spaces and sorted without regard to case,
  the current one suffixed `(current)`, then `/pm profile <name> switches profile`. Every line is
  `[PM]`-tagged and none ends in a colon. Result:
- **PROFILE-12. `/pm profile <name>` switches.** `/pm debug on`, then `/pm profile <another profile>`
  → `Switched to profile '<name>'.`, the panels change at once exactly as a Profiles-page switch does,
  and the console gets one `[Profile] switched to '<name>', N panels` line. `/pm profile <that same
  name>` again → `Already on profile '<name>'.` and nothing changes. Result:
- **PROFILE-13. An unknown name is refused.** `/pm profile Nope` → `No profile named 'Nope'.` followed
  by the list, and no `Nope` appears in the Profiles page's **Existing Profiles**. `/pm profile
  default` (wrong case) → refused the same way, with `Did you mean 'Default'?` before the list.
  Result:
- **PROFILE-14. Quotes and spaces.** Create a profile named `Raid Night` on the Profiles page, switch
  away, then `/pm profile "Raid Night"` → it switches. `/pm profile Default`, then `/pm profile 'Raid
  Night'` → it switches too. `/pm profile raid night` → refused, with `Did you mean 'Raid Night'?`.
  Result:
- **PROFILE-15. Profiles switch while disabled.** Make profile B with the addon enabled, then on
  profile A `/pm disable`. `/pm profile` → the list, not the disabled line. `/pm profile B` → the
  panels come up without touching a checkbox or a verb; `/pm profile A` → they go down again. Repeat
  the pair from the Profiles page → the same. Result:
- **PROFILE-16. No switch in combat.** Pull a training dummy, `/pm profile <another profile>` →
  `Can't switch profiles in combat.` and nothing changes. Bare `/pm profile` still lists. After
  combat the same command switches. Result:
- **PROFILE-17. An open General page refreshes.** Give two profiles different **Master scale**
  values. Open **General ▸ Master controls**, then `/pm profile <the other>` from chat with the window
  still open → the slider shows the new profile's value without reopening the page. Result:
- **PROFILE-18. The Profiles page lines up with its header.** `/pm config` → **Profiles** → the left
  edge of Ace's profile controls (the **Reset Profile** button, the **Current Profile** label) sits in
  line with the left end of the gold divider and the page title, and the right edge of the widest
  control stops in line with the right end of the divider. There is no horizontal scrollbar and
  nothing is clipped at either edge. Compare with **General**: its body starts on the same vertical
  line as the Profiles controls. Result:

## STATE

- **STATE-1. One master switch.** `/pm set settings.enabled false` → every panel vanishes; `true` →
  they return. `/pm disable` → the same, with the same `settings.enabled = false` echo; `/pm enable`
  → back (`slash-commands-§2`). Result:
- **STATE-2. Checkbox and verbs agree.** Untick and re-tick **General ▸ Master controls ▸ Enable Ka0s
  Panel Master**, mixing in `/pm disable` and `/pm enable` → the checkbox always agrees with whichever
  you used last. Result:
- **STATE-3. Live verbs answer while disabled.** `/pm disable`, then run `/pm help`, `/pm version`,
  `/pm list`, `/pm get settings.gridSize`, `/pm set settings.gridSize 8`, `/pm reset
  settings.gridSize`, `/pm debug`, `/pm config` and a bare `/pm` → every one answers normally, the
  `set` really writes, and `/pm config` and the bare `/pm` open the settings panel. `/pm help` prints
  the whole index, with the disabled line straight under its version header. `/pm enable` → the
  panels return. Result:
- **STATE-4. Feature verbs are refused and inert.** While disabled, `/pm new Ghost` → exactly one line,
  `[PM] Ka0s Panel Master is disabled — enable it with /pm enable`, and no panel: confirm with
  `/pm enable` then `/pm panels`. Disable again, `/pm unlock` → the same line, and the panels stay
  locked. **Fail:** the line prints and the verb acts anyway, or the wording differs by a word or a
  color from the line every Ka0s addon prints (`slash-commands-§7`). Result:
- **STATE-5. A typo is a typo while disabled.** While disabled, `/pm nwe Ghost` → `unknown command
  'nwe'` and the help index, not the disabled line (`slash-commands-§3`). Result:
- **STATE-6. The stand-down is total.** First, on the Profiles page, make a profile `Idle`, run
  `/pm disable` on it, and switch back to your own. With a **Show on mouseover only** panel,
  `/pm disable`, then enter and leave combat, change zones, and on the **Profiles page** switch to
  `Idle` and back (not with `/pm profile`, which answers in chat; PROFILE-15 owns that route) →
  nothing is drawn and **nothing is printed**. `/pm enable` → exactly the panels and settings as
  they are **now**, including anything changed while off. **Fail:** any chat line from a combat or
  zone change while disabled, which means a registration survived the stand-down. Result:
- **STATE-7. Unlock does not beat the stand-down.** With two panels, `/pm unlock`, then `/pm disable`
  → no outline, panel or label, and dragging the empty spot moves nothing. While disabled, untick
  **Master controls ▸ Lock frame** and tick a panel's **Unlock** on the Panels page → still nothing
  drawn. `/pm enable` → the outlines return and the panels drag. **Fail:** any outline or draggable
  panel while disabled. Result:

## COMBAT

- **COMBAT-1. Panels are inert in combat.** With FRAME-4's panel behind the action bars, pull a
  training dummy → the panel is unchanged and action buttons work normally. Result:
- **COMBAT-2. Unlock waits for combat to end.** `/pm unlock` in combat → a gray "unlock queued"
  notice, and the panels stay locked. Leave combat → they unlock by themselves and print "panels
  unlocked". Result:
- **COMBAT-3. Lock clears the queue.** In combat, `/pm unlock`, then `/pm lock`, then leave combat →
  the panels stay **locked**. Result:
- **COMBAT-4. No settings in combat.** `/pm config` in combat → `cannot open settings during combat
  — Blizzard's category-switch is protected`, word for word, in light gray, and no panel opens. Leave
  combat → the options panel does not open by itself; `/pm config` then opens it. Result:
- **COMBAT-5. An open settings window locks.** Open `/pm config` out of combat, then pull with it open
  → every page, tab strip included, is covered by a gray *"Settings are locked during combat."*;
  controls, **Defaults** and tabs do nothing; switching category in the sidebar raises no Lua error
  and the window stays open; exactly **one** gray chat notice per combat. Leave combat → the cover
  lifts and the page shows current values. Result:
- **COMBAT-6. General visibility.** **Master controls ▸ General visibility** → `Only in combat` →
  panels hidden out of combat; pull → they appear on the first swing; leave → they hide. `Only out of
  combat` → the reverse, the instant combat starts and ends. `Never` → nothing draws at all. Back to
  `Always`. Result:

## DIAG

- **DIAG-1. The console window.** `/pm debug` → the console opens: monospace, timestamped, a red
  `Debug: OFF` toggle at the left of the title bar, a scrollbar on the right, `0 / 3000 lines`
  bottom-right. It wears the Ka0s window edge (a 1px black outer border with a 1px light-gray
  highlight inside it), a **gold** title and a gray divider under the title bar, and reads as one
  suite beside another Ka0s addon's console. Result:
- **DIAG-2. Title-bar controls.** At the right end of the title bar → three small square controls of
  one size, evenly spaced: a copy mark, a clear mark and a close mark, gray, each turning white (the
  close mark red) under the pointer. No words and no tooltips. **Fail:** the words *Copy* and *Clear*
  and a multiplication sign instead of the close mark, with a wider strip: the addon folder name
  stopped reaching `core/DebugLogSetup.lua`'s descriptor, or `libs/LibKa0s/media/icons/` did not
  survive a re-vendor. Result:
- **DIAG-3. Monospace columns.** The `<HH:MM:SS> | [Tag]` prefixes line up down the window.
  **Fail:** proportional text with ragged columns on a complete install (`NS.MediaFont` answered
  nil). Result:
- **DIAG-4. Logging on.** `/pm debug on` → a cyan-tagged chat ack with **ON** in green; the console
  shows `[Debug] logging enabled`, then an `[Init]` line naming the addon, version, schema and
  profile. Result:
- **DIAG-5. One line per act.** Create, drag and recolor a panel → one `[Panel]` line per action, and
  the counter climbs. Change one setting → exactly **one** `[Set]` line. Result:
- **DIAG-6. Bulk acts log once.** Widen a panel and press its **Reset** → one `[Set] reset '<name>': N
  rows` line and no `[Panel]` line; again → `…: 0 rows`. Copy settings from another panel, press
  **Reset position**, and **Recover panels** → one `[Set]` line each, with a count (`copy from '…' to
  '…': N rows`, `reset positions: N rows`, `recover positions: N rows`). `/pm resetall`, confirmed →
  exactly one `[Set] reset profile '<name>' to defaults (N rows)` and no `[Profile] switched` line.
  `[Canvas]` repaint lines after a `[Set]` line are expected (`debug-logging-§10`). Result:
- **DIAG-7. Scrolling.** Drag the scrollbar → the log scrolls. Wheel-scroll the log → the thumb
  follows. No Lua error. Result:
- **DIAG-8. Copy.** Click the copy mark → a selectable window with the same lines, no color codes,
  and its own close mark in the same art. Ctrl+C, Esc. Result:
- **DIAG-9. Clear.** Click the clear mark → an empty log and `0 / 3000 lines`. Result:
- **DIAG-10. The toggle button.** Click `Debug: ON` → it flips to red `OFF` and prints the matching
  chat ack. Result:
- **DIAG-11. Esc closes it, and the checkbox follows.** Tick **General ▸ Master controls ▸ Debug
  console**, focus the console, press **Esc** → it closes (`UISpecialFrames`), and back on General the
  checkbox is **unticked**. Result:
- **DIAG-12. Logging is session-only.** `/reload` → logging is off and the console closed. Result:
- **DIAG-13. The diagnostics report.** `/pm diagnostics` → a report appended below the log, from
  `==== Ka0s Panel Master diagnostics begin ====` to `==== Ka0s Panel Master diagnostics end: N
  line(s) ====`, every line tagged `[Diag]`, sections in order (state, master, unlock queue,
  settings, screen, panels, frames, mouseover, artwork, events), each panel with `frame=yes`, and
  `0 orphaned`; one chat line says *Diagnostic report written to the debug console: N lines. Use Copy
  to share it.* **Fail:** any `frame=NO` or a non-zero orphan count. Result:
- **DIAG-14. The report keeps the trace.** `/pm debug on`, drag a panel, `/pm diagnostics` → the
  `[Panel]` lines stay above the begin marker. Copy and paste into an editor → the trace, both
  branded markers, and no `|c` escapes. Result:
- **DIAG-15. The report lands with logging off.** `/pm debug off`, `/pm diagnostics` → the full
  report lands, begin marker to end marker, none of it held back by the flag. What the run does to
  the flag is DIAG-27. Result:
- **DIAG-16. The report while disabled.** `/pm disable`, then `/pm diagnostics` and `/pm debug
  diagnostics` → each writes a full report; `state` reads `enabled (stored)=false stood down=true`
  with its lifecycle hold, and each panel's renderer line reads `renderer: stood down`. `/pm enable`
  afterwards. Result:
- **DIAG-17. The report in combat.** Queue `/pm unlock` in combat and run `/pm diagnostics` before
  combat ends → no Lua error, the `unlock queue` section shows `global=true`, and the unlock still
  happens when combat ends. An unreadable number prints `match=unknown` or `<secret>`. Result:
- **DIAG-18. No aliases.** `/pm debug dump`, then `/pm debug diag` → neither runs the report; each
  toggles the console, as any unknown `debug` word does. `/pm diag` → an unknown verb. Result:
- **DIAG-19. The line cap.** With logging on, fill past 3000 lines (drag panels, or repeat
  `/pm diagnostics`) → the counter pins at `3000 / 3000 lines`, and the copy mark opens its window
  without a noticeable hitch. Result:
- **DIAG-20. The console resizes.** `/pm debug` → a small grip sits in the console's bottom-right
  corner, clear of the `0 / 3000 lines` counter. Drag it out on both axes → the log, the scrollbar
  and the counter follow the new edges, the title-bar controls stay at the right end, and the lines
  and the scroll position are kept. Wheel-scroll and drag the scrollbar → both still work at the new
  size. Result:
- **DIAG-21. The console's minimum holds.** Drag the grip as far in as it goes → it stops while the
  `Debug:` toggle, the orange **Diagnostics** link, the gold title and the three title-bar controls
  still fit without overlapping, and a few log lines still show between the title bar and the status
  bar. Result:
- **DIAG-22. The console keeps its size for the session.** Resize the console, close it with its
  close mark, `/pm debug` → it reopens at the size you left. Close it with **Esc** and reopen → the
  same. `/reload`, `/pm debug` → it opens at the default 700 × 344 again. **Fail:** the resized size
  survives the `/reload` (the size reached the client's layout cache; debug-logging-§1 keeps it on
  the window for the session only). Result:
- **DIAG-23. Another addon's console is its own.** With another Ka0s addon installed, resize this
  console, then open the other addon's console → it opens at its own size, unchanged; resize it →
  this one is unchanged. Result:
- **DIAG-24. The copy window resizes.** Click the copy mark → its window has a grip in the
  bottom-right corner, and the scroll bar's down button sits above the grip and takes a click on
  its whole face. Drag the grip out on both axes → the text area widens and deepens with it and the
  lines rewrap to the new width; drag it in → it stops at a minimum that still shows the close mark
  and some text. Result:
- **DIAG-25. The copy window keeps its size for the session.** Resize the copy window, close it,
  click the copy mark again → it reopens at the size you left, and resizing it did not change the
  console's size. `/reload`, open the console and the copy window → both at their defaults. Result:
- **DIAG-26. The Diagnostics link.** `/pm debug` → just right of the `Debug: OFF` toggle, after a
  small gap, the word **Diagnostics** in **orange**: plain text like the toggle, with no button frame,
  border or background, turning brighter under the pointer. Click the toggle so it reads `Debug: ON`
  → the link moves with the longer word and keeps the same gap. Click **Diagnostics** → a report is
  written into the console exactly as `/pm diagnostics` writes it (DIAG-13), with the same chat line.
  **Fail:** a framed or gold button, the link overlapping the toggle, or a click that writes nothing.
  Result:
- **DIAG-27. Diagnostics turns logging on for the session.** `/reload` (logging off, DIAG-12),
  `/pm diagnostics` → above the begin marker the console shows `[Debug] logging enabled` and the
  `[Init]` line, and the title bar reads `Debug: ON`; drag a panel → a `[Panel]` line lands.
  `/pm diagnostics` again → a second report, and no second `logging enabled` line. `/reload`,
  `/pm debug` → `Debug: OFF`, and dragging a panel logs nothing. Repeat from a fresh `/reload` with
  the console's **Diagnostics** link, then with `/pm debug diagnostics` → the same each time.
  **Fail:** `Debug: OFF` after a report, the enable line below the report, or logging still on after
  the `/reload`. Result:
- **DIAG-28. A slash refusal shows in the console.** `/pm debug on`, open the console, then type
  `/pm notaverb` → chat says the command is unknown and prints the help index, and the console
  gains exactly one `[Cmd] refused notaverb: unknown verb` line. `/pm disable`, `/pm new Refused` →
  chat prints the one *is disabled — enable it with /pm enable* line, and the console gains exactly
  one `[Cmd] refused new: disabled` line and no `[Panel]` line. `/pm enable` afterwards. **Fail:** no
  `[Cmd]` line (the Slash descriptor lost its `debug`), or two lines for one refusal. Result:
- **DIAG-29. A stand-down edge shows in the console.** `/pm debug on`, then `/pm disable` → the
  console shows exactly one `[Lifecycle] stood down: added disabled (holds: disabled)` line. `/pm
  disable` again → no second `[Lifecycle]` line. `/pm enable` → exactly one `[Lifecycle] stood up:
  released disabled (holds: none)` line. **Fail:** no `[Lifecycle]` line, the old `stood down
  (disabled)` wording, or two lines for one edge. Result:
- **DIAG-30. The launcher's registration lands at enable.** `/reload` (logging off), then `/pm debug
  on` → below the `[Debug] logging enabled` and `[Init]` lines the console shows `[Launcher]
  registered` and `[Artwork] Sunn adapter: N themes, M rows`, once each. `/pm debug off`, `/pm debug
  on` → neither is written a second time. **Fail:** neither line after the `[Init]` line (the lines
  were gated off at OnEnable). Result:

## LAUNCH

Every step here fails silently in the client, so run the theme in full after any change to the icon or
the launcher seam.

- **LAUNCH-1. The logo.** Log in → a round minimap button wearing **this addon's logo** (not a
  Blizzard icon, not a blank square), and the same logo beside **Ka0s Panel Master** in Esc ▸ AddOns.
  **Fail:** a blank square: the `.tga` is missing or not uncompressed 32-bit. Result:
- **LAUNCH-2. Left-click.** Left-click the button → the settings open on the landing page, and the
  panels do **not** unlock (`launcher-§2`). Result:
- **LAUNCH-3. Right-click Locked.** Right-click → a menu titled **Ka0s Panel Master** with exactly two
  ticks, in order: **Enabled** (ticked) and **Locked** (ticked while locked); no *Test mode* and no
  *Show window*. Click **Locked** → the menu closes, the panels unlock exactly as `/pm unlock` does,
  and chat shows the same `state.locked = false` line. Right-click → **Locked** is unticked; click it
  → they lock. **General ▸ Master controls ▸ Lock frame** agrees. In combat, clicking **Locked**
  unlocks nothing until combat ends. Result:
- **LAUNCH-4. Right-click Enabled.** Click **Enabled** → the addon disables exactly as `/pm disable`
  does (panels go, `settings.enabled = false` in chat). Right-click → **Enabled** unticked and
  **Locked** grayed, reading `Locked (enable the addon first)`; clicking it does nothing and writes
  nothing. Left-click now → the settings open, no chat line. Click **Enabled** → back as with
  `/pm enable`. Result:
- **LAUNCH-5. The tooltip.** Hover → `Ka0s Panel Master  v<the TOC version>`, `Enabled: Yes` (green),
  `Locked: Yes`, `Left-click: Open settings`, `Right-click: Options menu`, and no `Test mode` line
  (`launcher-§1`). Unlock and hover → `Locked: No` (red). `/pm disable` and hover → still shown, with
  `Enabled: No` (red) and the same hints. `/pm enable` afterwards. Result:
- **LAUNCH-6. Its place persists.** Drag the button a third of the way around the ring, `/reload` →
  it is still there. Result:
- **LAUNCH-7. It survives a profile switch.** Switch profile on the Profiles page → the button does
  not move or vanish (it is stored account-wide, `launcher-§3`). Result:
- **LAUNCH-8. No reset touches it.** Hide the button (untick **Master controls ▸ Minimap button**),
  then **Reset all settings** (confirm) → still hidden, checkbox still unticked. Then the General
  page's **Defaults** → the same. Neither reset may show a hidden button or hide a shown one
  (`launcher-§3`). **Fail:** the button returns or the checkbox re-ticks. Tick it back on. Result:
- **LAUNCH-9. The Minimap button checkbox.** Untick **Minimap button** → the button goes at once;
  `/reload` → it stays gone. Tick it → it returns at the angle you dragged it to. Result:
- **LAUNCH-10. The menu has no hide entry.** Right-click → no entry hides the button. Result:
- **LAUNCH-11. The CLI path is `shown`.** With the button visible, `/pm get global.minimap.shown` →
  `global.minimap.shown = true`. `/pm set global.minimap.shown false` → the button goes at once.
  Bring it back, hide it with the checkbox, `/pm get global.minimap.shown` →
  `global.minimap.shown = false`; `/reload` → still hidden. `/pm get global.minimap.hide` →
  `Setting not found: global.minimap.hide` (the old path is not an alias). **Fail:** `get`
  answers `true` while hidden, or the old path answers. Show the button again. Result:
- **LAUNCH-12. Broker rows.** Only with Titan Panel, ElvUI or Bazooka → a row labeled **Ka0s Panel
  Master** in plain text (not `PanelMaster`, no `|cff…` escapes) wearing the same logo, whose left and
  right clicks do what LAUNCH-2 and LAUNCH-3 do, with no enable setting of this addon's for the row.
  Result:

## DEGRADED

What a player sees when `libs/LibKa0s` is genuinely missing. The suite loads the addon without it and
asserts the wording; only the client can say the addon still works. Quit the client, rename
`Interface/AddOns/PanelMaster/libs/LibKa0s` to `libs/_LibKa0s`, and log in for DEGRADED-1 to 13.

- **DEGRADED-1. It loads and draws.** Log in with `scriptErrors` on → zero Lua errors, and your panels
  are drawn exactly as before. Result:
- **DEGRADED-2. Panel verbs work.** `/pm panels` → a complete listing, every panel and field.
  `/pm new SmokeTest`, then `/pm delete SmokeTest` → both work. Result:
- **DEGRADED-3. The notice, once.** The first line the addon prints carries `[PM] The LibKa0s library
  is missing from this installation of Ka0s Panel Master (expected in libs/LibKa0s); running on
  reduced built-in fallbacks.`, once per session; later lines do not repeat it. Result:
- **DEGRADED-4. The console is unavailable, logging is not.** `/pm debug` → `[PM] …(expected in
  libs/LibKa0s), so the debug console window is unavailable.`, said once; a second `/pm debug`
  repeats nothing. `/pm debug on` → still acknowledges, in plain words: `[PM] debug logging is on`.
  Result:
- **DEGRADED-5. Ka0s media is gone, harmlessly.** Before the rename, set one panel's **Bar texture**
  to a `Ka0s …` entry. Now, with PanelMaster the only Ka0s addon enabled (any other one registers
  the same names into the shared LibSharedMedia), `/dump
  LibStub("LibSharedMedia-3.0"):IsValid("statusbar", "Ka0s Gradient")` and `/dump
  LibStub("LibSharedMedia-3.0"):IsValid("font", "JetBrains Mono")` → `false` each. That panel's
  bars render **plain**, as in LOOK-13, and `/pm panel <name> accentTexture` still prints the stored
  name. Nothing raises, and nothing is overwritten (DEGRADED-14 shows the names come back). Result:
- **DEGRADED-6. Diagnostics explain themselves.** `/pm diagnostics`, then `/pm debug diagnostics` →
  each prints `/pm diagnostics is unavailable: the LibKa0s library did not load.` and writes nothing.
  Result:
- **DEGRADED-7. The settings CLI and help.** `/pm list` → `…, so the settings CLI (list/get/set/reset)
  is unavailable.` `/pm help` → that line once, then one plain `/pm <cmd>  <desc>` row per verb (no
  colors, no em dash). Result:
- **DEGRADED-8. Disable and enable still work.** `/pm disable`, then `/pm enable` → the panels go and
  return, each printing its `settings.enabled = false` or `= true` echo, with no Lua error. Result:
- **DEGRADED-9. Unlock and lock explain themselves.** `/pm unlock` → `/pm unlock is unavailable: the
  LibKa0s library did not load.` and nothing moves; `/pm lock` → the same with its own verb. Result:
- **DEGRADED-10. Reset all still works.** `/pm resetall` → the popup, and **Yes** resets the profile:
  it needs AceDB, not the library. Result:
- **DEGRADED-11. Config answers every time.** `/pm config` three times → `…, so the settings panel is
  unavailable.` each time. A bare `/pm` → the same answer. Result:
- **DEGRADED-12. The profile verb explains itself.** `/pm profile` and `/pm profile Default` → each
  prints `/pm profile is unavailable: the LibKa0s library did not load.` and nothing switches.
  Result:
- **DEGRADED-13. One cause clause.** Across DEGRADED-3, 4, 7 and 11, the cause clause is word for
  word the same, differing only after the closing parenthesis of `(expected in libs/LibKa0s)`, and
  matches another Ka0s addon on the same install. Result:
- **DEGRADED-14. Restore.** Rename the folder back, `/reload` → normal operation returns: the **Bar
  texture** dropdown lists the seven `Ka0s …` bars again, both of DEGRADED-5's `/dump` lines answer
  `true`, and DEGRADED-5's panel draws its `Ka0s …` bars again instead of plain. Result:

## Non-English client

Run on a client set to **deDE or frFR**, the two the collection's other locale checks use
(`ConsumableMaster/docs/smoke-tests.md` LOC-1, `KickCD/docs/smoke-tests.md` LOC-1).

This addon reads almost nothing the client translates: no chat or tooltip `_G` constant, no tooltip
line parsed in place of an API return, no `subType` where a `classID` exists
(`grep -rn '_G\[' core modules settings` returned no lines when this section was last revised).
Recheck that grep rather than trusting this sentence. The exposure runs the other way, through the
panel names a player types, and two seams treat non-ASCII bytes as punctuation:

- **`Util.Slugify`** (`core/Util.lua:198-202`) collapses every run of `[^%w]+` to one underscore, and
  Lua's `%w` is ASCII-only: `Übersicht` slugs to `bersicht`, and `Ärger` and `Örger` both slug to
  `rger`. That slug is the public contract `PanelMaster_Panel_<slug>` (FRAME-18 to FRAME-25).
- **Case folding.** `Registry:FindByName` (`modules/Registry.lua:373-381`) and the Panels list's sort
  (`settings/PanelEditor.lua:195`) use `string.lower`, which folds ASCII only.

Every label the addon prints is hardcoded English and stays English here; that is scope, not a
regression. Steps LOC-1 to LOC-4 can be provoked on an English client by typing the same letters into
`/pm new`, which is worth doing but is not the same test: it says nothing about the client's own
fonts, its text input, or what a player of that language types. `tests/test_util.lua` and
`tests/test_registry.lua` feed ASCII names throughout.

- **LOC-1. A panel named in the client's language.** `/pm new Übersicht` (or `Écran` on frFR), pick it
  on **Panels**, hover **Panel name** on its **General** tab for the frame name, then `/run
  print(PanelMaster_Panel_<the reported slug>:GetWidth())` → the panel is created, the name renders
  correctly in the band's **Panel** picker, the **Panel name** box and `/pm panels`, and the reported
  frame name resolves. **Fail:** `?` or mojibake anywhere, or a reported frame name that does not
  resolve. Write down the slug the tooltip reports: a player who cannot work the frame name out from
  the panel name in their own alphabet has no contract. Result:
- **LOC-2. Two names, one slug.** `/pm new Ärger`, then `/pm new Örger` → two panels with two distinct
  frame names if the contract holds. **Fail:** the second refused with a message naming
  `PanelMaster_Panel_rger`, a name that looks like neither. Record which happened; a refusal is a
  finding to file, not a step to re-run. Result:
- **LOC-3. Name lookup folds only ASCII.** With `Übersicht` created, `/pm panel übersicht` (lower-case
  `ü`) and another verb that takes a name → the panel resolves, the way `/pm panel wide` resolves a
  panel named `Wide`. **Fail:** `no panel called 'übersicht'`. Then `/pm new übersicht` and read which
  refusal answers: `a panel named 'übersicht' already exists` means the name guard folded it, while
  `'übersicht' would share the frame name … with 'Übersicht'` means only the frame-name check caught
  it and the duplicate-name guard has the same hole. Record which. Result:
- **LOC-4. Sort order.** With three or four panels starting with accented and plain letters, open
  **Panels** → sorted the way a reader of the language expects. **Fail:** accented names clumped at
  one end; cosmetic, but worth knowing. Result:
- **LOC-5. The round trip.** `/reload`, check LOC-1 to LOC-4 again, then switch profiles and back
  (PROFILE-4) → names, frame names and anchors identical. **Fail:** a name that changed shape, meaning
  it was re-slugified or re-encoded on its way out of SavedVariables. Result:

## Pending sign-off

Every check below still needs a client run and a filled `Result:` line; sign one off there, then take
it out of this table. Eight carried-over checks have a recorded pass (owner, 2026-09-26) and
unchanged expectations, so they are not listed: PANEL-11 and PANEL-25 (§ 9 step 5-w and § 9 step 16,
passed in this doc), PANEL-12 (§ 9 step 5-x, passed in the 2026-09-26 navrail adoption's report),
and DIAG-14, DIAG-16, DIAG-17, DIAG-19 and DEGRADED-6 (§ 11 steps 12, 14, 15 and 17,
§ 14 step 10, passed as PM-S1 to PM-S5, PM-S7 and PM-X1 in the 2026-09-25 diagnostics plan's
report). Six checks from the 2026-10-01 GitHub issue pass passed on the owner's run of 2026-10-02
and are signed off on their own `Result:` lines, so they are not listed either: FRAME-12 (corrected
for the **Frame level** slider, #15), PANEL-27 (new with it) and PANEL-28 to PANEL-31 (new with the
instance-addressed panel rows, #54).
Every other check carried over is owed, and so is every check new in this rewrite or
corrected in it against the code.

| New ID | Origin (old section and step) | Why it is owed |
|---|---|---|
| INSTALL-1 to INSTALL-6 | § 1 steps 1, 3 and 4, § 13, § 15 | No result recorded |
| INSTALL-7 | § 2 step 2 | No result recorded; corrected: the sweep runs at load with logging off, so the `[Preview]` line the old step expected never prints |
| INSTALL-8 | § 21 (`M4-19`) | Not yet run since `NS.InitSummary` moved to `NS.Version()`; corrected: the `[Init]` line is written to the console only |
| SLASH-1, SLASH-3 to SLASH-7 | § 1 step 2, § 2 step 1, § 9 step 1, § 16 steps 4 to 6 and 15 | No result recorded |
| SLASH-2 | § 1 step 2, § 16 step 3 | No result recorded; its `profile` row is new |
| FRAME-1 to FRAME-7, FRAME-10, FRAME-11, FRAME-13 to FRAME-29 | § 3, § 4, § 4b steps 1, 2 and 5, § 5e-5 steps 1-2, § 5e-6 step 5, § 6 steps 1-2, § 7 steps 1-3, § 9 steps 2d, 5d, 5e, 12 and 14, § 10, § 11b, § 12c, § 17 steps 1-4 | No result recorded |
| FRAME-8 | § 4b steps 3-4 | No result recorded; corrected: the CLI clamps an out-of-range outline rather than refusing it |
| FRAME-9 | § 4b steps 6-9 | No result recorded; corrected: `/pm panel Wide reset` was never a command, so the reset is the General tab's **Reset** |
| LOOK-1, LOOK-3 to LOOK-5, LOOK-7 to LOOK-9, LOOK-11 to LOOK-28 | § 5 steps 1-5, § 5b steps 1-10, § 5b-2, § 5b-3, § 5b-4 step 15, § 5c, § 5d steps 1-8 | No result recorded |
| LOOK-2 | § 5 step 1a (`M4-18`) | Not yet run since the byte-alpha fix |
| LOOK-6 | § 5b step 0 | No result recorded; corrected: PanelMaster has no font dropdown, so `JetBrains Mono` is checked with `/dump` |
| LOOK-10 | § 20 (`M4-05`) | Not yet run since the LSM Border patch moved into LibKa0s |
| LOOK-29 | § 5d step 9 (`M4-22`) | Not yet run since the mouseover driver drops its `OnUpdate` |
| ACCENT-1 to ACCENT-14 | § 5b-4 steps 1-14 and 16 | No result recorded |
| ART-1 to ART-11, ART-13 to ART-30 | § 5e, § 5e-2, § 5e-3, § 5e-4, § 5e-6 steps 1-4, § 18 | No result recorded |
| ART-12 | § 5e-6 step 7 | No result recorded; corrected: `/pm panel set <name> …` read `set` as the panel name |
| PANEL-1, PANEL-4 to PANEL-7, PANEL-9, PANEL-13 to PANEL-15, PANEL-18 to PANEL-24 | § 9 steps 2, 2d, 3, 4, 5a, 5b, 5b-2, 6 to 11 and 13, § 16 steps 8, 10, 13 and 14 | No result recorded |
| PANEL-2 | § 9 step 2b, § 16 step 11 | No result recorded; corrected: Master controls has 7 rows, and **Grid size** shares its line with **Unlock outline thickness**, not **Snap to grid** |
| PANEL-3 | § 9 step 2c | No result recorded; corrected: **Minimap button** sits alone on a fourth line above the button pair |
| PANEL-8 | § 9 steps 2d and 15, § 17 step 5 | No result recorded; corrected: the Panels page's **Defaults** is the delete-all, not this popup |
| PANEL-10 | § 9 step 5, § 16 step 12 | No result recorded; corrected: the six panel acts are on the General tab, not in the band |
| PANEL-16, PANEL-17 | § 9 steps 5c and 5c-2 (session 3) | Not yet run since the acts and the rename box moved to the General tab |
| PANEL-26 | § 19 (`M4-01`) | Not yet run since the pooled `TabStrip` (LibKa0s v1.27.0) |
| PANEL-32 | none | New with the Options descriptor passing `addonName` (LibKa0s v1.67.0, LibKa0s#42) |
| PROFILE-1 to PROFILE-10 | § 5e-6 step 6, § 12, § 12b, § 12b-2 steps 1 and 3 | No result recorded |
| PROFILE-11 to PROFILE-14, PROFILE-16, PROFILE-17 | none | New with the `/pm profile` verb |
| PROFILE-15 | § 7 step 12 | No result recorded; `/pm profile` is new in it |
| PROFILE-18 | none | New with the Profiles container reading `O.PADDING_X` (PanelMaster#56) |
| STATE-1, STATE-2, STATE-4, STATE-5, STATE-7 | § 7 steps 4-5, 7, 8, 10 and 13 | No result recorded |
| STATE-3 | § 7 steps 6 and 9 | No result recorded; corrected: the disabled line prints under the help index's version header |
| STATE-6 | § 7 step 11 | No result recorded; corrected: the switch goes through the Profiles page between two disabled profiles, since `/pm profile` answers in chat |
| COMBAT-1 to COMBAT-6 | § 6 step 3, § 8 steps 1-9 (not 4b), § 9 step 2d, § 16 step 7 | No result recorded |
| DIAG-1, DIAG-3 to DIAG-12 | § 11 steps 1, 1c, 2-8, 10 and 11, § 16 steps 1 and 9 | No result recorded |
| DIAG-13, DIAG-18 | § 11 steps 9 and 16 | Partly run: the 2026-09-26 pass (PM-S2, PM-S8) did not check the section order, `frame=yes` and `0 orphaned`, or `/pm debug diag` |
| DIAG-2 | § 11 step 1b, § 16 step 2 | No result recorded; corrected: the icon marks replaced the words *Copy* and *Clear* |
| DIAG-15 | § 11 step 13 | Passed on 2026-09-26, but corrected: a report now turns logging on for the session (`debug-logging-§14` at v2.71.0), so the title bar no longer stays `Debug: OFF` afterwards; the flag is DIAG-27 |
| DIAG-20 to DIAG-25 | none | New with the resizable console and copy window (LibKa0s v1.64.0) |
| DIAG-26, DIAG-27 | none | New with the console's Diagnostics link (DebugLog minor 16) and the report turning logging on (DebugLogDiagnostics minor 2), LibKa0s v1.64.0 |
| DIAG-28 to DIAG-30 | none | New with the library's own debug lines (Slash minor 18, Lifecycle minor 3, the at-enable queue in DebugLogGates minor 1), LibKa0s v1.65.0 |
| LAUNCH-1 to LAUNCH-12 | § 7b | No result recorded |
| DEGRADED-1, DEGRADED-3, DEGRADED-7, DEGRADED-8, DEGRADED-10, DEGRADED-11 | § 14 steps 1-4, 7, 11, 11b, 11c, 12, 13 and 13b | No result recorded |
| DEGRADED-2, DEGRADED-9 | § 14 steps 5, 6 and 11d | No result recorded; corrected: `/pm unlock` and `/pm lock` print the library-absent line |
| DEGRADED-4 | § 14 steps 8-9 | No result recorded; corrected: the degraded ack reads `debug logging is on`, not the library's green `ON` |
| DEGRADED-5, DEGRADED-14 | § 14 steps 9b and 15 | No result recorded; corrected: with no settings panel and no font dropdown the media check is a `/dump` |
| DEGRADED-12 | none | New with the `/pm profile` verb |
| DEGRADED-13 | § 14 step 14 | No result recorded; corrected: it compares DEGRADED-3, 4, 7 and 11, the four lines that carry the cause clause |
| LOC-1 to LOC-5 | § 22 steps 1-5 (`M5-08`) | No deDE or frFR client has run them yet; LOC-1 (where **Panel name** is) and LOC-3 (the lookup comparison and the refusal to read) are also corrected |
