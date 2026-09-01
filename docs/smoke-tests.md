# Smoke Tests — Ka0s Panel Master

In-client checks for the things the headless harness genuinely cannot reach: how a panel actually
looks, dragging with a real mouse, layering against other addons' frames, and the debug console's
rendering. Run these before tagging a release, after any change to `modules/Canvas.lua`,
`modules/Artwork.lua`, `modules/Unlock.lua`, `settings/Panel.lua` or `settings/PanelEditor.lua`,
and whenever the `## Interface:` is bumped.

The unit suites ([`testing.md`](testing.md)) cover the logic; this page covers the pixels.

Start each run from a clean state: `/reload`, then `/pm resetall` (confirm it) — which is a **profile
reset** and takes the panels with it, so `/pm panel deleteall` is no longer needed alongside it.

---

## 1. Load and first contact

1. Log in. **Expect:** no Lua error, and nothing at all on screen — a fresh install draws no panels.
2. `/pm` → **Expect:** the help index, every line prefixed with a cyan `[PM]`, one row per command,
   no trailing colons.
3. `/pm version` → **Expect:** `[PM] v1.0.0`, matching the TOC.
4. `/pm panels` → **Expect:** "No panels yet", suggesting `/pm new`.

## 2. Preview mode

1. `/pm preview` → **Expect:** three sample panels appear (bottom-left, bottom-center, top-right),
   each outlined in gold with its name across the middle, and panels are now unlocked.
2. Confirm each is a **different color and size** — that is what proves color, size and position
   are all really being applied rather than one default being drawn three times.
3. `/pm preview` again → **Expect:** all three vanish, the registry is empty (`/pm panels`), and
   panels are **locked** again — test mode undoes the unlock it turned on.
4. Now `/pm unlock` first, then test mode on and off. **Expect:** you are left **unlocked**, because
   you already were before test mode started.
5. Make a panel of your own, then `/pm preview` on and off again → **Expect:** your panel survives.
6. With test mode on, open **Panels ▸ Edit**, select a `Preview: *` panel and press **Reset**.
   **Expect:** a cyan-tagged refusal naming test mode, and the placeholder is unchanged.
7. Turn test mode off → **Expect:** all three placeholders go, including the one you tried to reset.
   Then `/reload` with test mode ON, and `/pm panels` after → **Expect:** no `Preview: *` panels
   survive. Reset must never be able to promote a placeholder into a permanent panel.

## 3. Creating and placing a panel

1. `/pm new Chat BG` → **Expect:** a confirmation naming the panel and suggesting `/pm unlock`.
2. `/pm unlock` → **Expect:** the panel appears with a gold outline and its name in the middle.
3. **Drag it** to sit behind your chat frame. **Expect:** it follows the mouse smoothly and stays
   where you drop it.
4. `/pm lock` → **Expect:** the outline and label vanish; the panel is now a plain block.
5. **Click through it** — click something in the chat frame behind it. **Expect:** the click lands on
   the chat frame. A locked panel must be completely mouse-transparent.
6. `/reload` → **Expect:** the panel is exactly where you left it, and panels are **locked** again
   (unlock is session-only).

## 4. Snapping

1. `/pm set settings.gridSize 32` and `/pm set settings.snapToGrid true`.
2. `/pm unlock`, drag a panel slowly. **Expect:** on release it jumps to a 32-unit multiple.
3. `/pm panel <name> x` → **Expect:** a value divisible by 32.
4. `/pm set settings.snapToGrid false`, drag again → **Expect:** it lands wherever you dropped it.
5. Reset with `/pm reset settings.gridSize`.

## 4b. The three settings promoted out of the code

All three are new rows in the tabbed-panel pass — `settings.unlockOutlineSize` on **Editing**, and
`settings.defaultWidth` / `settings.defaultHeight` on **New panels** — and each ships at exactly the
number it replaced, so the first half of every check is that **nothing moved**.

1. On a fresh profile, `/pm get settings.unlockOutlineSize` → **Expect:** `2 px`. `/pm unlock` and
   look at a panel's gold outline: it is the same hairline it has always been.
2. `/pm set settings.unlockOutlineSize 8` **while unlocked** → **Expect:** every unlocked panel's
   outline thickens immediately, with no `/reload` and no re-unlock.
3. `/pm set settings.unlockOutlineSize 0` → **Expect:** refused (`Invalid value`), because an
   outline nobody can see reads as unlock mode being broken. Same for `400`.
4. Hand-edit `unlockOutlineSize = 0` into `PanelMaster.lua` in `WTF/.../SavedVariables`, reload, and
   `/pm unlock` → **Expect:** the outline is drawn at **1**, not at 0. The value is clamped on the
   way out as well as on the way in.
5. `/pm reset settings.unlockOutlineSize` puts it back to `2 px`.
6. `/pm get settings.defaultWidth` / `settings.defaultHeight` → **Expect:** `240 px` and `120 px`,
   which is the size a new panel has always been. Make a panel and confirm it.
7. `/pm set settings.defaultWidth 500`, `/pm set settings.defaultHeight 60`, then `/pm new Wide` →
   **Expect:** a 500x60 panel. **Every existing panel is untouched** — check one you made earlier.
8. `/pm panel Wide reset` → **Expect:** it comes back at **500x60**, not 240x120: "reset this panel"
   and "make a new one" land on the same state, which is what the shared code path is for.
9. Put both back with `/pm reset settings.defaultWidth` and `/pm reset settings.defaultHeight`.

## 5. Appearance

With a panel created and locked:

1. `/pm panel <name> bgColor 1,0,0,0.5` → **Expect:** it turns translucent red immediately.
2. `/pm panel <name> borderSize 6` (it starts at 0) and `/pm panel <name> borderColor 0,1,0,1` → **Expect:** a thick
   green border, with the four edges **meeting cleanly at the corners** — no darker overlap squares,
   which is what a translucent border would reveal.
3. `/pm panel <name> borderSize 0` → **Expect:** the border disappears entirely, leaving a plain fill.
4. `/pm panel <name> alpha 0.2` → **Expect:** it fades. `/pm panel <name> alpha 9` → **Expect:** the
   echo reads `1.00`, i.e. it clamped rather than accepting the value.
5. `/pm panel <name> strata HIGH` → **Expect:** it now covers UI it previously sat behind.
   `/pm panel <name> strata BACKGROUND` → **Expect:** it drops behind again.

## 5b. Textures (LibSharedMedia)

0. **New as of the LibKa0s-Media adoption, and expected:** the addon now registers the collection's
   shared media with LibSharedMedia at load, so the **font** dropdowns gain `JetBrains Mono` and the
   **Accent bar texture** dropdown gains seven `Ka0s …` entries (`Ka0s Gradient`, `Ka0s Underline 1`
   / `2` / `4`, `Ka0s Overline 1` / `2` / `4`). Nothing you had already chosen moves — registration
   only adds names — and the shipped default is still a texture LSM itself always ships.
   **A regression looks like** those names being absent on a complete install, which means
   `core/MediaSetup.lua` never reached `Media.RegisterLSM`.
1. In **Panels ▸ Edit**, open the **Background texture** dropdown. **Expect:** a list with a preview
   swatch per entry, `Solid` among them, plus anything other addons have registered (ElvUI,
   WeakAuras, Details all contribute).
2. Pick a decorative one — `Blizzard Parchment`, say. **Expect:** the panel fills with it
   immediately, tinted by its background color.
3. Reopen the dropdown. **Expect:** it still reads the texture you picked. (If it has reverted to the
   old name while the panel visibly changed, the LSM widget's value push has regressed — see
   `settings-panel.md` ▸ *Three widget workarounds*.)
4. Open **Border texture** and pick `Blizzard Tooltip`. **Expect:** a proper decorative edge, with
   corners drawn correctly — not four flat bars.
5. Check the closed **Border texture** dropdown is flush with the controls beside it, with no ~42px
   empty gap on its left. A gap means `core/LSMPatch.lua` is not taking effect.
6. Raise **Border size** to 8 and back to 1. **Expect:** the edge scales with it.
7. Set **Border texture** to `None`. **Expect:** the border disappears entirely while **Border size**
   stays where it was. Set it back and the border returns.
8. Set **Background texture** to `None`. **Expect:** the fill disappears, the border stays.
9. Reload. **Expect:** both texture choices survived.
10. **The uninstall case:** pick a texture supplied by another addon, disable that addon, `/reload`.
   **Expect:** the panel renders **plain** — not invisible, not an error — and re-enabling the addon
   brings the texture straight back. The choice was never overwritten.

## 5b-2. Color pickers (regression: they used to do nothing)

AceGUI's ColorPicker only fires `OnValueConfirmed` when the **opacity slider** is touched, so binding
that alone meant an ordinary color change never reached the addon — the swatch updated and the panel
did not. Both pickers now bind `OnValueChanged` too. This is live-client-only: the headless suite
stubs AceGUI out entirely, so **nothing below is covered by a unit test.**

1. Click the **Background color** swatch. Pick a strong color (bright green). **Do not touch the
   opacity slider.** Click **OK**.
2. **Expect:** the panel is green. Both the swatch *and* the panel must change — a green swatch over
   an unchanged panel is exactly the old bug.
3. Watch the panel while dragging inside the color wheel, before clicking OK. **Expect:** it
   updates live.
4. Repeat both steps for **Border color** with a border thickness of 4 or more. **Expect:** the
   border takes the color.
5. Open a picker, change the color, and press **Cancel**. **Expect:** the panel returns to its
   previous color.
6. Change a color, `/reload`. **Expect:** the color persisted.
7. Now change a color **and** drag the opacity slider. **Expect:** both apply, and the panel's
   opacity is the picker's alpha multiplied by the **Panel opacity** slider (under **Opacity and
   fade**).

## 5b-3. Border offset

1. With a visible border of 2–4px, drag **Border offset** positive. **Expect:** the border moves
   *outward*, away from the panel's fill, leaving a gap between the two — a halo.
2. Drag it negative. **Expect:** the border moves *inward*, overlapping the fill — an inset frame.
3. Return it to 0. **Expect:** the border sits exactly on the panel's edge.
4. With a non-zero offset, drag the panel. **Expect:** the border moves with it, keeping its offset.
5. With a non-zero offset, change the **Frame strata**. **Expect:** the border stays with the panel —
   it is a child frame, so it cannot end up on a different layer.
6. `/reload`. **Expect:** the offset persisted.

## 5b-4. Accent bar

The BenikUI-style strip. Everything below is per panel, under **Accent bar** in the editor.

1. On a fresh panel, confirm **Enable accent bar** is **ticked** and a bar is already drawn along the
   **top** edge only — running the panel's full width, **5px thick, flush against the panel**, in
   the **Blizzard** status-bar texture, in **your class color**, outlined by a **1px black**
   hairline. That is the shipped look, with no configuration at all.
1b. Confirm the panel's **own** border starts at size **0** — the accent bar defines the edge, and
   both at once reads as busy.
2. Untick **Enable accent bar**. **Expect:** the strip vanishes, leaving a plain block. Tick it
   again and it returns exactly as before.
2b. **Z-order.** Give the panel a border of 4 or more in a contrasting color. **Expect:** the accent
   bar draws **over** the border where they meet, not under it. Change **Frame strata** and confirm
   the stacking holds.
3. Tick **Bottom**, **Left** and **Right** in turn. **Expect:** each edge gains a bar spanning that
   edge in full. With all four on it reads as a detached outline.
4. Untick every edge. **Expect:** no bars, and the enable switch stays **on** — unticking edges must
   not silently re-tick Top.
5. Resize the panel (drag the Width and Height sliders). **Expect:** every bar tracks the new size
   and still spans its whole edge, with no gap at either end.
6. Raise **Bar thickness**. **Expect:** top/bottom bars get taller, left/right bars get wider.
7. Drag **Bar offset** positive. **Expect:** the bars move *away* from the panel on all sides at
   once. Set it to 0 — they sit flush, and start to look like a thick border. Negative — they
   overlap the panel.
8. Untick **Class color** next to **Bar color**. **Expect:** the bar turns the stored green. Pick
   your own color and confirm it applies (see §5b-2 — same picker, same fix).
9. Change **Bar texture** to a gradient status-bar texture. **Expect:** the bar renders with it,
   tinted by the bar color. The list should be your **status-bar** textures, not backgrounds.
9b. **The bar's own border.** Raise **Bar border size** to 3. **Expect:** an outline appears around
    each bar. Change **Bar border texture**, **Bar border color** and its **Class color** — all
    behave like the panel's border. Push **Bar border offset** positive and negative. Drop the size
    back to 0 and confirm the outline goes completely.
10. Set **Panel opacity** to 0.3. **Expect:** the bars fade *with* the panel — they are part of it,
    not separate.
11. Change **Frame strata**. **Expect:** the bars move with the panel; they can never be on a
    different layer.
12. With bars on, **click through** where a bar is drawn. **Expect:** the click lands on whatever is
    behind. Accent bars must not take the mouse either.
13. Turn on **Show on mouseover only** with a faded opacity of 0. **Expect:** the bars vanish and
    reappear with the panel.
14. Delete a panel that had bars. **Expect:** no colored strips left floating where it was — they
    are anchored *outside* the panel's bounds, so this is a real failure mode.
15. `/reload`. **Expect:** every accent setting persisted.
16. From the command line: `/pm panel <name> accentEdges top,left`, then
    `/pm panel <name> accentEdges none`, then a deliberate typo like `accentEdges middle`.
    **Expect:** the first two apply, the third is refused with the valid list.

## 5c. Class color

1. Tick **Class color** next to **Background color**. **Expect:** the panel takes your class
   color. The picker beside it stays **enabled**, its label gaining an `(opacity)` suffix.
2. Check the panel's **opacity is unchanged** — class color replaces the hue, not the alpha. Drag
   **Panel opacity** and confirm it still works.
3. Tick **Class color** next to **Border color** too, and confirm the two are independent: untick
   the background one and the border stays class-colored.
4. Untick both. **Expect:** the original colors come back exactly — they were never overwritten.
4b. **The picker stays usable under class color.** With **Class color** ticked, the picker's label
   reads `… (opacity)` and the control is still **enabled**. Open it and drag the opacity slider →
   **Expect:** the class-colored border/fill gets more or less solid. This is the only control that
   sets opacity, so it must not be grayed out.
4c. **Definition check.** A 1px border reads as sharp or soft mostly by *contrast*, not by which
   color mode produced it. Compare a picked bright color against your class color at the **same
   opacity and size** — a darker class color will legitimately look softer. If they differ at
   matched luminance, that is a real bug; raise it. Bumping **Border size** to 2 makes any color
   crisp regardless of UI scale.
5. Log in on a character of a **different class**. **Expect:** that character's panels (if
   class-colored) show the new class color.

## 5d. Mouseover fade

1. Tick **Show on mouseover only** and set **Faded opacity** to `0`.
2. Move the cursor away. **Expect:** the panel disappears completely.
3. Move the cursor over where it was. **Expect:** it appears at its normal opacity, promptly (within
   about a tenth of a second) and without stutter.
4. **The critical one:** with the cursor over the faded-in panel, **click something behind it**.
   **Expect:** the click lands on the frame underneath. The mouseover fade must not have made the
   panel mouse-interactive — that would break click-through, which is the one thing a backdrop
   cannot do.
5. Set **Faded opacity** to `0.3`. **Expect:** it rests dim rather than invisible.
6. Set **Faded opacity** above **Opacity**. **Expect:** it is clamped — the panel must never fade
   *out* when you mouse over it.
7. Tick **Unlock** on that panel. **Expect:** it is held fully visible while unlocked, regardless of
   the cursor, so it can be found and dragged. Untick and the fade resumes.
8. Create half a dozen mouseover panels and watch your frame rate. **Expect:** no measurable change —
   one shared 10Hz ticker drives all of them.

## 5e. Artwork — does it load at all

**Run this first.** A malformed `.tga` renders as *nothing* with no Lua error, which is
indistinguishable from having picked **None** — so every check below it is meaningless until this
one passes.

1. Create a panel, size it around 300x300, and open its **Artwork** section.
2. Set **Artwork** to `Class: Death Knight`. **Expect:** the emblem appears inside the panel.
3. Step through every other catalog entry. **Expect:** each one draws. If any renders blank, that
   file is bad — the headless suite only proves the file *exists*, never that the client can decode
   it.
4. Set **Artwork** back to **None**. **Expect:** the panel returns to a plain block.

## 5e-2. Artwork — fill types under resize

The one behavior the whole feature turns on, and the reason to resize rather than eyeball a static
panel: three of the five fills only differ once the panel stops matching the art's aspect.

1. With artwork on, drag the panel's **Width** slider from minimum to maximum at each fill:
   - **Fit (contain)** → the whole emblem stays visible, never cropped, aspect never distorted.
   - **Fill (crop)** → the art always covers the panel edge to edge, aspect never distorted, and the
     overflow is cropped evenly on both sides.
   - **Stretch** → the art distorts to match the panel. This one is *supposed* to look wrong.
   - **Native size** → the emblem's size never changes as the panel resizes.
   - **Tile** → more copies appear as the panel grows, and each copy stays the same size.
2. Now do the same with **Height**.
3. **The one that shipped broken:** set **Rotation** to `90` and repeat step 1 at **Fit**, **Fill**,
   **Native size** and **Tile**. **Expect:** the art is turned a quarter-turn and its proportions are
   otherwise unchanged. A squashed or stretched emblem here means the axis transpose regressed.

## 5e-3. Artwork — layers and clipping

1. Give the panel a solid opaque background and a thick border.
2. **Draw layer → Behind background.** **Expect:** the artwork is hidden behind the fill. Drop the
   background's alpha and it shows through.
3. **→ Above background.** **Expect:** the art sits on the fill but *under* the border and the
   accent bar.
4. **→ Above border and accent.** **Expect:** the art now covers both.
5. **Clipping:** set **Fill type** to `Native size`, **Scale** to `4`, and drag **X** and **Y**
   around. **Expect:** the art is cut off exactly at the panel's edges and never spills outside them.
   Confirm the **accent bar still hangs outside** the panel — it is deliberately unclipped, and
   clipping it would be a regression.
6. **Blend mode → Glow.** **Expect:** the art brightens whatever is behind it and never darkens
   anything — strongest over a dark panel, barely visible over a pale one. Set it back to **Normal**
   and the art paints over the panel obeying its own transparency. Only those two modes are offered:
   the other three of WoW's five cannot be correct for art defined by its alpha channel.

## 5e-4. Artwork — color, class color and Desaturate

1. On any piece: change **Color**. **Expect:** the art takes the color. Tick **Class color** → it
   takes your class color. Drop **Opacity** → it fades independently of the panel's own background
   alpha.
2. **Expect:** the Color and Class color controls are present for **every** piece, and do not appear
   and disappear as you page through the artwork dropdown. They used to be hidden for full-color
   art, which shoved every row below them up and down.
3. On a full-color piece with a strong tint set, tick **Desaturate**. **Expect:** the muddy
   average turns into a clean, saturated version of the color you picked. Untick it and the mud
   comes back. On a white-on-black piece Desaturate should make no visible difference — it is
   already neutral.

## 5e-5. Artwork — the two z-order regressions

Both of these broke panels that have **no artwork at all**, so run them on a plain panel.

1. On a panel with the default opaque-ish background and **Artwork = None**, `/pm unlock`.
   **Expect:** the gold outline and the panel's name are clearly visible **on top of** the
   background fill. If they are dim or invisible, the unlock overlay has fallen behind the fill
   again.
2. `/pm preview` → **Expect:** all three sample panels show their gold outline and name legibly.
3. Create two overlapping panels, same strata. Set one to **Level** `0` and the other to `1`.
   **Expect:** the level-1 panel draws entirely in front — its background covers the other panel's
   accent bar and border, not just part of them. Repeat with levels `0` and `3`; the result must be
   the same. Interleaved layers here mean the level stride regressed.

## 5e-6. Artwork — custom paths and persistence

1. Set **Artwork** to `Custom path…` and enter `Interface\Icons\INV_Misc_QuestionMark`.
   **Expect:** the question-mark icon renders under the current fill.
2. Enter deliberate nonsense. **Expect:** nothing draws, and **no Lua error**.
3. Clear the box. **Expect:** nothing draws.
4. Set up a panel with artwork, a tint, a rotation, a flip and an offset. `/reload`.
   **Expect:** every one of those survives exactly.
5. **Copy settings from another panel** onto a second panel. **Expect:** all the artwork settings
   travel with it.
6. Switch profiles and back. **Expect:** the artwork settings are intact.
7. `/pm panel <name>` → **Expect:** the `art*` fields print. Try
   `/pm panel set <name> artFill SQUISH` → **Expect:** a refusal listing the five legal values, not
   a silent store.

## 6. Layering (the actual point of the addon)

1. Create a panel, place it behind your action bars, `strata BACKGROUND`, `/pm lock`.
2. **Expect:** the action bars are fully visible and usable on top of it; the panel never intercepts
   a click, a keybind or a tooltip.
3. Enter combat. **Expect:** the panel is unchanged, and pressing an action button works normally.

## 7. Enable / disable

1. `/pm panel <name> enabled false` → **Expect:** it vanishes but still appears (dimmed) in
   `/pm panels`.
2. `/pm unlock` → **Expect:** the disabled panel is **shown anyway**, with its outline and label —
   you cannot move what you cannot see.
3. `/pm lock` → **Expect:** it disappears again.
4. `/pm set settings.enabled false` → **Expect:** every panel vanishes. `true` → all return.

## 8. Combat gating

1. Pull a training dummy.
2. `/pm unlock` **in combat** → **Expect:** a gray "unlock queued" notice; panels stay locked.
3. Leave combat → **Expect:** panels unlock by themselves and print "panels unlocked".
4. Pull again, `/pm unlock`, then `/pm lock` while still in combat, then leave combat.
   **Expect:** panels stay **locked** — the explicit lock cleared the queue.
4b. Pull again and tick a panel's **Unlock** box in the settings editor. **Expect:** the same gray
   notice, and the checkbox **unticks itself** rather than claiming a state the panel is not in.
   Leave combat → that one panel unlocks.
5. `/pm config` **in combat** → **Expect:** a gray "cannot open settings during combat" notice and
   **no** panel opens.
6. Leave combat → **Expect:** the options panel does **not** pop open by itself. Run `/pm config`
   yourself and it opens.

## 9. Options panel

1. `/pm config` → **Expect:** the landing page with the logo, the tagline and the slash-command list,
   which matches `/pm help` exactly.
2. Click **General** → **Expect:** a **tab strip** pinned at the top reading **Master controls |
   Editing | New panels**, the first tab active (drawn as a disabled button, which is how a Ka0s
   strip marks selection), a two-column grid of settings under it with **no** section headings — the
   tab is the heading — and a **Defaults** button top-right in the standard dark/gold style, **not**
   Blizzard's red stone button. (A red button means it was created too early; see `options-ui-§5`.)
2b. **Click each tab.** **Expect:** only that tab's controls are on the page, the strip stays put,
   and clicking the tab you are already on does nothing at all (the active tab is drawn disabled).
   Master controls has 3 rows, Editing 5 plus a **Recover panels** button under them, New panels 4.
3. Confirm the scrollbar is **present but grayed out** on a page that fits, and that the body does not
   jump width when you tab between pages.
4. Toggle **Unlock panels** and **Test mode** → **Expect:** they do exactly what the slash
   commands do.
5. Click **Panels** → **Expect:** a six-tab strip — **General | Position and size | Background and
   border | Accent bar | Artwork | Opacity and fade** — and, under it, a **Create** section (name
   box + Create button) and an **Edit** section (a panel dropdown + the active tab's editor).
   **Create and Edit are not tabs**: they stay on the page whichever tab is selected. With **no
   panels at all** there is no strip either — the band is given back rather than left standing over
   the "No panels yet" line.
5b. **Layout check.** The panel dropdown spans the **full width** with **no "Panel" label** above it,
   and there is **no heading naming the selected panel** between it and the editor box. The gap
   below `Create` and the gap below `Edit` must look **identical** — the dropdown carries no label,
   so a compensating spacer keeps the two headings evenly spaced. Inside the editor there are **no
   divider-flanked subsection headings any more** — the strip says which subject you are on — and no
   two unrelated controls share a line. On **Opacity and fade**, **Panel opacity** is alone on its
   row, with **Faded opacity** and **Show on mouseover only** paired on the next. Compare against
   KickCD's Icons page for the house rhythm.
5b-2. **Dropdown vs scrolling.** Open any dropdown on the Panels page (the panel selector, Anchor,
   Frame strata, or either texture picker) and — without closing it — **scroll the page**, first with
   the mouse wheel and then by dragging the scrollbar. **Expect:** the open list closes immediately
   in both cases. It must never be left floating over, or outside, the settings window while the
   control it belongs to scrolls away. Re-open it afterwards to confirm one click still opens it
   (rather than the click being eaten as a toggle-shut).
5c. **Top action row.** On the **General** tab, **Reset** and **Delete** sit directly under
   **Enabled** and **Unlock**, at the top of the editor — not at the bottom, and not on any other
   tab. The frame name is **not** a label of its own: it lives
   on the **Panel name** box's tooltip, so nothing crowds that box's Okay button.
5d. **Rename.** Change **Panel name** and press Enter. **Expect:** the dropdown entry updates and
   the **Frame name** on the tooltip does **not** — it is fixed at create, so anchors survive. Try
   renaming to an existing panel's name → **Expect:** a cyan-tagged error and the box reverts to the
   old name rather than showing a lie. Renaming to a name that merely *slugs* the same as another
   panel's ("Chat-BG" while "Chat BG" exists) is now **allowed**, since no frame name is claimed.
5e. **Reset.** Configure a panel heavily — resize it, move it, change both textures and both colors,
   turn on mouseover — then press **Reset**. **Expect:** it returns to a brand-new panel's
   appearance *and position* (center of the screen), every control in the editor re-reads the new
   values, and the **name and Frame name are unchanged**. Confirm anything anchored to it is still
   anchored. Other panels must be untouched.
6. Type a name, then click **away** from the box without pressing Enter. **Expect:** *nothing is
   created* — AceGUI's EditBox does not commit on focus loss, only on Enter or the Okay button.
7. Type a name and press **Enter** (or click the **Okay** button that appears as you type).
   **Expect:** the panel appears in the middle of the screen, the name box clears, and the editor
   jumps to the panel you just made.
7b. Try a name that already exists. **Expect:** a cyan-tagged error and the text is **left in the
   box** so it can be corrected rather than retyped.
8. Create two more, then use the **Panel** dropdown to switch between them. **Expect:** exactly one
   editor is shown at a time, and the page does not grow as panels are added.
9. Disable a panel and reopen the dropdown. **Expect:** it is listed as `<name> (disabled)`.
10. Change a panel's width slider and color picker → **Expect:** the panel updates as you release.
11. Tick **Unlock** on the selected panel → **Expect:** *only that panel* grows an outline and a
    drag handle; the others stay inert. Drag it, then untick.
12. Hover the **Panel name** box → **Expect:** its tooltip reads `Frame name: PanelMaster_Panel_<slug>`
    for that panel.
13. Click **Delete** → **Expect:** the panel goes from the screen and the dropdown, and the editor
    falls back to another panel rather than going blank.
14. Press **Defaults** on the Panels page → **Expect:** a confirmation dialog, and nothing deleted
    until you accept.
15. Press **Defaults** on the General page → **Expect:** settings reset and **your panels survive**.
16. Close the options window, run `/pm new Offscreen`, reopen → **Expect:** the new panel is in the
    dropdown (it was rebuilt on show, not missed).

## 10. Off-screen recovery

1. `/pm panel <name> x 9000` → **Expect:** the panel disappears off the right edge.
2. `/pm recover` → **Expect:** "moved 1 panel back on screen" and the panel reappears.
3. `/pm recover` again → **Expect:** "every panel is already on screen".
4. Confirm recovery did **not** run by itself at login: park a panel half off-screen deliberately,
   `/reload`, and expect it to still be where you put it.

## 11. Debug console

1. `/pm debug` → **Expect:** the console opens: monospace, timestamped, a `Debug: OFF` toggle in red
   at the left of the title bar, a scrollbar on the right, `0 / 1500 lines` bottom-right.
1b. **Look at the right end of the title bar.** **Expect:** three small square controls of the same
   size, evenly pitched — a copy mark, a clear mark and a close mark, gray, each turning white (the
   close one red) as the pointer crosses it. **No words, and no tooltips**: a label anchored under a
   control on a window that is 700px of text lands on the first line of the log, which is the thing
   the window exists to show.
   **What a regression looks like:** the words *Clear* and *Copy* and a **multiplication sign** where
   the close mark should be, with the strip visibly wider. That is the shape the library falls back
   to when it cannot build a texture path, and it means the addon folder name stopped reaching
   `core/DebugLogSetup.lua`'s descriptor — or that `libs/LibKa0s/media/icons/` did not survive a
   re-vendor. Nothing raises either way: a texture that does not load draws nothing.
1c. Look at the log text itself. **Expect:** fixed-width columns — the `<HH:MM:SS> | [Tag]` prefixes
   line up down the window. **A regression looks like** proportional text with ragged columns, which
   means `NS.MediaFont` answered nil and `C.FONT_MONO` fell back to the client's own face. That is
   the correct behavior for a missing library and a bug on a complete install.
2. `/pm debug on` → **Expect:** a cyan-tagged chat ack with **ON in green**; the console shows
   `[Debug] logging enabled` followed by an `[Init]` line naming the addon, version, schema and
   profile.
3. Create, drag and recolor a panel → **Expect:** one `[Panel]` line per action, and the line counter
   climbing.
4. Change a setting → **Expect:** exactly **one** `[Set]` line (not one per reactor).
5. **Drag the scrollbar** → **Expect:** the log scrolls. **Wheel-scroll the log** → **Expect:** the
   thumb follows. No Lua error either way.
6. Click the **copy mark** → **Expect:** a selectable window with the same lines, no color codes, and
   a close mark of its own in its title bar — the same art, not a multiplication sign. Ctrl+C, Esc.
7. Click the **clear mark** → **Expect:** an empty log and `0 / 1500 lines`.
8. Click the `Debug: ON` toggle → **Expect:** it flips to red `OFF` and prints the matching chat ack.
9. `/pm debug dump` → **Expect:** a `[Dump]` block listing each panel with `frame=yes`, and
   `0 orphaned`. Any `frame=NO` or a non-zero orphan count is a rendering bug.
10. `Esc` with the console focused → **Expect:** it closes (`UISpecialFrames`).
11. `/reload` → **Expect:** logging is **off** again (session-only) and the console is closed.

## 11b. Frame names and anchoring

The addon's public contract, and the one thing no unit test can prove works in a live client.

1. Create a panel called **Chat BG**. Hovering the editor's **Panel name** box should report
   `Frame name: PanelMaster_Panel_Chat_BG`.
2. In a macro or a `/run`, confirm the frame really exists under that name:
   `/run print(PanelMaster_Panel_Chat_BG:GetWidth())` → **Expect:** the panel's width.
3. Anchor something to it:
   `/run local f=CreateFrame("Frame",nil,UIParent);f:SetSize(20,20);local t=f:CreateTexture();t:SetAllPoints();t:SetColorTexture(1,0,0);f:SetPoint("TOPLEFT","PanelMaster_Panel_Chat_BG","TOPLEFT",0,0)`
   → **Expect:** a red square appears at the panel's top-left corner and **follows it** when you
   unlock and drag the panel.
4. Try creating a second panel called **Chat-BG**. **Expect:** refused, with a message naming the
   frame name it would have collided on.
5. Rename **Chat BG** to **Chat Backdrop**. **Expect:** the frame name on the **Panel name**
   tooltip is **still `PanelMaster_Panel_Chat_BG`**, and the red square from step 3 **keeps
   following the panel**. The frame name is stamped at create and a rename does not touch it.
6. Rename it back and forth a few more times, then `/pm debug dump`. **Expect:** the pooled-frame
   count does not grow — renaming abandons no frames.
7. Try creating a new panel called **Chat BG**, the name freed up in step 5. **Expect:** refused,
   naming **Chat Backdrop** as the panel still holding `PanelMaster_Panel_Chat_BG`.
8. `/reload` and repeat step 2. **Expect:** the name is the same — it is persisted on the record,
   not recomputed.

## 12. Profiles

1. Create a couple of panels on one character.
2. Log in on an alt → **Expect:** the SAME panels — every character starts on the shared "Default"
   profile. This is the check for the `true` third argument to `AceDB:New`.
3. Back on the first character → **Expect:** the panels are exactly as you left them.

### 12b. The Profiles page

1. `/pm config` → **Profiles**. **Expect:** Ace's standard profile UI — Reset Profile, current
   profile name, New / Existing Profiles, Copy From, Delete a Profile. No **Defaults** button in the
   header (profile management has its own destructive controls).
2. Type a new profile name and press Enter. **Expect:** the profile is created and switched to, and
   **the screen clears of panels immediately** — you are now on an empty profile. This is the check
   that matters: without the profile callbacks the old panels would just stay there.
3. Create a panel on the new profile, then switch back via **Existing Profiles**. **Expect:** the
   original character's panels return and the new profile's panel disappears, at once.
4. Use **Copy From** to pull the other profile's panels in. **Expect:** they appear immediately.
5. Press **Reset Profile**. **Expect:** every panel on this profile goes.
6. Switch to a profile, `/reload`, and confirm you are still on it with the right panels.
7. Open the **Panels** page, then switch profile from the Profiles page and come back. **Expect:**
   the panel dropdown lists the new profile's panels, not the old ones — **and so does Copy settings
   from panel**, and the editor below is showing one of them rather than a panel you never chose.
   This check is older than the bug it now catches, and it went unrun: the page kept the widget tree
   it had built for the previous profile, because the deferred repaint was marked on a flag nothing
   read. Everything on this page is one rebuild, so if the dropdown is right the rest is too.

### 12b-2. Session state does not cross a profile switch

Panel ids are handed out **per profile** — a fresh profile starts at 1 — so anything the session
remembers by id names a *different* panel after a switch. These are the checks that it is dropped
rather than carried, and the first is the one that could destroy a layout.

1. `/pm preview on` → **Expect:** the three sample panels appear, unlocked.
2. Without turning preview off, switch to another profile from the **Profiles** page, and make a
   real panel there if it has none.
3. `/pm preview off`. **Expect:** **your real panel is still there.** It used to be deleted: preview
   held the previous profile's ids, and turning it off resolved them against the profile you had
   switched to.
4. `/pm preview on` again. **Expect:** it starts — preview is genuinely off, not merely claiming to
   be. A stale "on" flag made this a no-op with nothing on screen.
5. Unlock a single panel with the per-panel control, switch profile, and look at the incoming
   profile's panels. **Expect:** none of them is unlocked. No stray drag handle or gold outline on a
   panel you never touched.
6. Do the same while a per-panel unlock is **queued by combat** (unlock during a fight, then switch
   profile before it drops). **Expect:** on leaving combat nothing unlocks. The queued request named
   a panel that no longer exists; the *global* `/pm unlock` request is deliberately kept and does
   still fire.

## 12c. Copy settings from another panel

1. Make two panels. Style the first heavily — size, textures, both colors, border, accent bar.
   Move the second somewhere clearly different.
2. On the **second** panel, pick the first from **Copy settings from panel**.
3. **Expect:** the second takes on the first's entire appearance **and size**, and a cyan-tagged
   confirmation names the source.
4. **Expect: it does not move.** Position is deliberately not copied — otherwise the two would land
   exactly on top of each other. Its name and **frame name** are unchanged too, so anything anchored
   to it is still anchored.
5. **Expect:** the dropdown snaps back to empty. It is an action, not a stored setting — a lingering
   selection would imply an ongoing link between the two panels.
6. Now change a color on the **first** panel. **Expect:** the second does not change — the copy was
   a snapshot, not a link.
7. On a lone panel (delete all others), **Expect:** the dropdown is disabled with a tooltip saying to
   make another panel first.

## 13. Standalone

1. Disable every other addon except PanelMaster and its libraries. **Expect:** it loads and behaves
   identically — no suite, no other addon, is a dependency.
2. Re-enable a UI skin (ElvUI or similar) and reopen `/pm config` → **Expect:** the Defaults button is
   skinned like the rest of the AceGUI widgets, not left on stock red art.

---

## 14. LibKa0s — the degraded install

The one thing no headless case can reach: what a player sees when `libs/LibKa0s` is genuinely not
on disk. The suite loads the addon without it and asserts the wording; only the client can say the
addon still *works*.

1. Quit the client. Rename `Interface/AddOns/PanelMaster/libs/LibKa0s` to `libs/_LibKa0s`.
2. Launch, log in.
3. **Zero Lua errors.** Turn on `/console scriptErrors 1` first if it is off.
4. Your panels are **still drawn**, exactly as before. The addon's own function has nothing to do
   with a shared library, and an install missing `libs/` must still draw panels.
5. `/pm panels` → a **complete** listing, every panel, every field.
6. `/pm new SmokeTest`, `/pm unlock`, drag it, `/pm lock`, `/pm delete SmokeTest` — all work.
7. The **first** line the addon prints carries the notice, once:
   `[PM] The LibKa0s library is missing from this installation of Ka0s Panel Master (expected in
   libs/LibKa0s); running on reduced built-in fallbacks.`
   Every later line is untagged by it — the notice is once per session, not once per line.
8. `/pm debug` → `[PM] …(expected in libs/LibKa0s), so the debug console window is unavailable.`
   Said **once**; a second `/pm debug` repeats nothing.
9. `/pm debug on` → still acknowledges `debug logging ON` in green, because logging is a session
   flag this addon owns and only the *window* went away.
9b. The **font and texture dropdowns lose their Ka0s entries** — `JetBrains Mono` and the seven
    `Ka0s …` bars are inside the payload that is not there, so there is nothing to register. A panel
    whose profile still names one of them renders **plain**, exactly as it does when any other
    addon's texture goes away (§5b step 10). Nothing raises, and nothing is overwritten: reinstate
    `libs/LibKa0s` and the names come straight back.
10. `/pm debug dump` → still answers with the state dump.
11. `/pm list` → `…, so the slash help index and the settings CLI (list/get/set/reset) are
    unavailable.`
12. `/pm resetall` → **still works**, popup and all: it is the one schema verb with no library
    dependency, and since `options-ui-§12` its body is `db:ResetProfile()`, which needs the db
    rather than the library.
13. `/pm config` → `…, so the settings panel is unavailable.` Run it **three times**: it must answer
    every time. Unlike step 8's console notice, which rides other output, this line *is* the verb's
    whole answer, and a second invocation that printed nothing would read as a broken command.
14. **The cause clause is word-for-word the same in every one of those four**, differing only after
    the comma. Compare against any other adopted Ka0s addon on the same install; a user with a
    broken install must not get a different sentence depending on which addon they open.
15. **Rename the folder back**, `/reload`, and confirm normal operation returns.

## 15. LibKa0s — the `L` trap

Three of the ten majors take a locale override, and a descriptor handed this addon's `NS.L` would
render every user-visible string as its own key. The source guard and the rendered assertions in
`tests/test_libka0s.lua` are both blind to what the client actually draws.

Walk **every** surface and confirm not one `SCREAMING_SNAKE_CASE` string is on screen:

1. `/pm config` → the landing page, then **General**, **Panels** and **Profiles**. Every label,
   every tooltip, every section heading, the breadcrumb, and the **Defaults** button.
2. `/pm debug` → the console. Title bar (`Panel Master — Debug`), the `Debug: OFF` toggle, `Copy`,
   `Clear`, and the `N / 1500 lines` counter. Click **Copy** and read that window's title too
   (`Copy log — Ctrl+C, then Esc`).
3. `/pm help`, `/pm list`, `/pm version` in chat.

Anything reading `DEBUG_ON`, `COPY_TITLE`, `LINES`, `LIST_HEADER`, `DEFAULTS_LABEL` or similar is
the trap, and it fails for every key at once rather than one at a time.

## 16. LibKa0s — the rendered changes, and the parity check

Everything below **changed deliberately** in the adoption. Confirm each looks right; anything else
that looks different is the finding.

**Changed on purpose:**

1. **The debug console wears the Ka0s window edge.** `/pm debug`. A flat 1px black outer border with
   a 1px light-gray highlight just inside it, a **gold** title, a gray divider under the title bar.
   It used to be a plain dark background with no edge at all. Side by side with another adopted Ka0s
   addon's console, the two must read as one suite.
2. **Its close control is the library's ×**, 18×18, gray, turning **red** on hover — not the old
   flat `X` that turned gold. `Copy` and `Clear` sit to its left with a 6px gap, unmoved.
3. **`/pm help` rows are indented two spaces** under the header, and the header now carries an em
   dash: `v1.0.0 — slash commands (/panelmaster is an alias for /pm)`.
4. **The settings landing page's command list** lost its double spacing: `/pm config — Open
   settings`, one space either side of the dash, the dash gold-to-white rather than white-wrapped.
   It should now look **identical** to `/pm help`'s rows minus their indent — compare them directly.
5. **`/pm set settings.gridSize 99999` clamps** to `64 px` and echoes the clamped value, where it
   used to refuse with `error: invalid value`.
6. **A bad value gives two lines**: `Invalid value for settings.snapToGrid`, then the reason
   indented beneath it.
7. **The combat refusal is a lighter gray.** Pull a mob, `/pm config` → the refusal is still
   `cannot open settings during combat — Blizzard's category-switch is protected`, word for word,
   just lighter.
8. **The Defaults button now has a tooltip** on General and on Panels. Hover both.
9. **Esc-closing the debug console now updates the settings checkbox.** Open `/pm config` →
   General, tick **Debug console**, press **Esc** to close the console, return to General: the
   checkbox is **unticked**. It used to stay ticked — the console synced only through its own
   Hide, which Esc bypasses.

**Parity — "nothing moved". Anything that looks different here is a defect:**

10. Open `/pm config` → **General**. The two-column grid, the row spacing, the header, the gold
    divider and the breadcrumb `Ka0s Panel Master ▸ General` are all **unchanged**. The three
    sections are the three **tabs** now (`Master controls`, `Editing`, `New panels`) rather than
    headings down one scrolling page — that change is the tabbed-panel pass, not a defect.
11. **Recover panels** is a button **under** the Editing tab's last row now, rather than to the
    right of **Grid size** — which pairs with **Snap to grid** instead. It does the same thing.
12. The **Panels** page's create box and selector are untouched; the editor below them is one tab at
    a time.
13. The scrollbar is **always visible** on every page and grays out when the page fits, so the body
    width does not jump as you tab between pages.
14. Open the **Default frame strata** dropdown, then **scroll the page**: the list closes. Do it
    again with the scrollbar **drag** rather than the wheel. This is the one behavior the library's
    widget makers know nothing about, and it is re-attached by hand.
15. `/pm list` — the green header, the azure `[group]` headings in schema order (which is tab order
    now: `Master controls`, `Editing`, `New panels`), four-space indented rows, `4 px` on grid size. Only the gold/white escapes changed case, which is invisible.

## 17. LibKa0s — the destructive path still has its guard

The one destructive verb this addon has is not a schema reset, so no convergence touched it — but
it reaches its confirmation from **two** entry points and a check that only clicks the button
proves nothing about the verb.

1. `/pm new GuardA`, `/pm new GuardB`.
2. `/pm panel deleteall` → the **confirm popup** appears. Choose **No**. Both panels survive.
3. `/pm config` → **Panels** → **Defaults** → the **same** popup appears. Choose **No**. Both
   panels survive.
4. Now choose **Yes** from either. Both panels are gone, and chat says `deleted 2 panels.`
5. `/pm resetall` → the **confirm popup** appears first, carrying the collection's one wording
   (`options-ui-§12`), verbatim: *"Reset this profile to the addon's defaults? Everything you have
   configured or added in it is discarded — your other profiles are not affected."* Choose **No**:
   nothing changes. Choose **Yes**: every setting is back to shipped **and the panels are gone**, and
   chat says `this profile reset to defaults` — not the library's own `All settings reset to
   defaults`, and no longer the old *"your panels are untouched"*, which a profile reset does not
   keep. **Config → Panels → Defaults** shows the same popup and does the same thing.

## 18. Sunn — Viewport Art packs, and the composite renderer

The one claim the headless suite cannot make: that a real pack's textures actually **resolve** in
the client. Every path this addon builds is asserted against SunnArt's own construction, never
against a load — so a wrong folder, a missing pack or a `.blp`-only theme looks identical to
correct code until someone logs in.

**Skip this whole section if you do not have Sunn - Viewport Art installed.** Everything below needs
at least SunnArt and one art pack; the rest of the addon must behave identically without them, which
is step 1.

1. With **no Sunn folder installed at all**, `/pm config` → **Panels** → **Artwork**. **Expect:** no
   `Sunn ->` entries anywhere in the dropdown. The feature is silent on a machine that does not have
   it. (Installed-but-disabled is a different case — step 16.)
2. Enable SunnArt and at least one pack, `/reload`, and reopen the dropdown. **Expect:** entries
   grouped under `Sunn -> Art Pack 2` (or `Sunn -> Built in`), **one per theme**, each under the
   theme's own plain name. There must be no `(left)` / `(middle)` / `(right)` entries at all — the
   sections are not offered separately.
3. Pick one and set **Fill** to **Stretch** and the panel to something wide — say 800 × 140.
   **Expect:** the art draws, with all sections **edge to edge**, in order, as one continuous bar.
   This is also the step that proves the path resolves; if it draws nothing, nothing else in this
   section will either, and the fault is the path rather than the renderer. The failure this replaces is the left section stretched across the whole
   panel, so a bar that looks like one repeated piece means the composite path did not run.
5. Look hard at the **seams**. **Expect:** no bright line, no dark gap and no doubled pixel where
   two sections meet. A seam means the slicing and the texture coordinates disagree.
6. Press **Fit to artwork**. **Expect:** the panel becomes the bar's exact size — 1536 × 256 for a
   typical three-section theme — and chat reports both numbers. Now drag the panel smaller: it must
   **not** snap back on its own. Press the button again and it returns to the artwork's size.
7. Set **Rotation** to **90°** and press **Fit to artwork** again. **Expect:** 256 × 1536 — the axes
   swap, because the art is presented turned. Set **Scale** to `0.5`, press again: every number
   halves. Both are part of how big the art actually is on screen, so both are part of the fit.
8. Set **Fill** to **Fill (crop)** and make the panel much taller relative to its width. **Expect:**
   the bar covers the panel and the outer sections are cropped away entirely — on a three-section
   bar in a panel of a third its aspect, only the middle section remains. It should **disappear**,
   not thin down to a hairline.
9. Set **Rotation** to **90°**. **Expect:** the sections stack **vertically**, section 1 at the top,
   and the whole bar still covers the panel.
10. Back to 0°, and tick **Flip horizontally**. **Expect:** the section order reverses — the piece
    that was on the left is now on the right — and each section is itself mirrored.
11. Set **Fill** to **Tile** and shrink **Scale**. **Expect:** the whole **bar** repeats across the
    panel, not each section repeating in its own slot. Keep shrinking: past the cap the repeats stop
    getting smaller and simply stay larger. **The panel must never show a bare strip.**
12. Set a **Color** and tick **Desaturate**. **Expect:** every section takes the tint equally. One
    section tinted differently from its neighbors means the tint is being applied per texture from
    the wrong source.
13. Switch the panel from the bar back to a **single bundled piece**. **Expect:** exactly one image,
    with no leftover section still drawn beside or behind it.
14. Pick a theme whose art has a transparent strip along its top (most do). **Expect:** after **Fit
    to artwork**, the art sits **flush** in the panel with no empty band above it. Then set **Fill** to
    **Tile**: the gaps reappear between repeats, which is expected and is the one case the strip is
    not trimmed.
15. Disable the pack addon but not SunnArt, `/reload`. **Expect:** the panel that used it draws **no
    artwork** and raises no error, and its size is unchanged — uninstalling a pack must not reshape a
    layout.
16. **The case the manifest exists for.** Disable **Sunn - Viewport Art** itself in the AddOn list,
    leaving the pack folders installed, and `/reload`. The packs are hard-dependent on it, so
    nothing registers and no Sunn global exists at all. **Expect:** the official packs' themes are
    *still* listed under `Sunn ->`, and still draw. This is the whole point of
    `modules/SunnArtPacks.lua`; if the dropdown is empty here, the folder roster or the manifest is
    not being read.
17. Still with SunnArt disabled, pick **Sunn -> Art Pack 6: Fractal** (or Pack 9's **Wrath**) and
    press **Fit to artwork**. **Expect:** a panel 1536 × 512 — square sections, not 2:1 ones —
    those themes are authored at 512×512 and are the reason the manifest measures rather than
    assumes. Compare against any Pack 2 theme, which should still fit to 2:1.
18. Re-enable SunnArt, `/reload`, and check a theme you have renamed in **SunnArt's own** options.
    **Expect:** your name, not the manifest's — live registration always wins.
19. **Only what is installed is listed.** Count the `Sunn ->` groups in the dropdown against the
    `SunnArt*` folders you actually have in `Interface/AddOns`. **Expect:** they match exactly. Then
    delete (or rename) one pack folder, `/reload`, and reopen the dropdown. **Expect:** that pack's
    group is gone and the rest are untouched. If SunnArt still remembers the deleted pack in its own
    options, that is precisely the case this checks — a remembered theme with no files behind it
    must not be offered.

