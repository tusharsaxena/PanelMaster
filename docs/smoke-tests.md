# Smoke Tests — Ka0s Panel Master

In-client checks for the things the headless harness genuinely cannot reach: how a panel actually
looks, dragging with a real mouse, layering against other addons' frames, and the debug console's
rendering. Run these before tagging a release, after any change to `modules/Canvas.lua`,
`modules/Unlock.lua` or `settings/Panel.lua`, and whenever the `## Interface:` is bumped.

The unit suites ([`testing.md`](testing.md)) cover the logic; this page covers the pixels.

Start each run from a clean state: `/reload`, then `/pm resetall` and `/pm panel deleteall`.

---

## 1. Load and first contact

1. Log in. **Expect:** no Lua error, and nothing at all on screen — a fresh install draws no panels.
2. `/pm` → **Expect:** the help index, every line prefixed with a cyan `[PM]`, one row per command,
   no trailing colons.
3. `/pm version` → **Expect:** `[PM] v0.1.0`, matching the TOC.
4. `/pm panels` → **Expect:** "No panels yet", suggesting `/pm new`.

## 2. Preview mode

1. `/pm preview` → **Expect:** three sample panels appear (bottom-left, bottom-centre, top-right),
   each outlined in gold with its name across the middle, and panels are now unlocked.
2. Confirm each is a **different colour and size** — that is what proves colour, size and position
   are all really being applied rather than one default being drawn three times.
3. `/pm preview` again → **Expect:** all three vanish, the registry is empty (`/pm panels`), and
   panels are **locked** again — test mode undoes the unlock it turned on.
4. Now `/pm unlock` first, then test mode on and off. **Expect:** you are left **unlocked**, because
   you already were before test mode started.
5. Make a panel of your own, then `/pm preview` on and off again → **Expect:** your panel survives.

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

## 5. Appearance

With a panel created and locked:

1. `/pm panel <name> bgColor 1,0,0,0.5` → **Expect:** it turns translucent red immediately.
2. `/pm panel <name> borderSize 6` and `/pm panel <name> borderColor 0,1,0,1` → **Expect:** a thick
   green border, with the four edges **meeting cleanly at the corners** — no darker overlap squares,
   which is what a translucent border would reveal.
3. `/pm panel <name> borderSize 0` → **Expect:** the border disappears entirely, leaving a plain fill.
4. `/pm panel <name> alpha 0.2` → **Expect:** it fades. `/pm panel <name> alpha 9` → **Expect:** the
   echo reads `1.00`, i.e. it clamped rather than accepting the value.
5. `/pm panel <name> strata HIGH` → **Expect:** it now covers UI it previously sat behind.
   `/pm panel <name> strata BACKGROUND` → **Expect:** it drops behind again.

## 5b. Textures (LibSharedMedia)

1. In **Panels ▸ Edit**, open the **Background texture** dropdown. **Expect:** a list with a preview
   swatch per entry, `Solid` among them, plus anything other addons have registered (ElvUI,
   WeakAuras, Details all contribute).
2. Pick a decorative one — `Blizzard Parchment`, say. **Expect:** the panel fills with it
   immediately, tinted by its background colour.
3. Reopen the dropdown. **Expect:** it still reads the texture you picked. (If it has reverted to the
   old name while the panel visibly changed, the LSM widget's value push has regressed — see
   `ARCHITECTURE.md` ▸ Options UI.)
4. Open **Border texture** and pick `Blizzard Tooltip`. **Expect:** a proper decorative edge, with
   corners drawn correctly — not four flat bars.
5. Check the closed **Border texture** dropdown is flush with the controls beside it, with no ~42px
   empty gap on its left. A gap means `core/LSMPatch.lua` is not taking effect.
6. Raise **Border size** to 8 and back to 1. **Expect:** the edge scales with it.
7. Set **Border texture** to `None`. **Expect:** the border disappears entirely while **Border size**
   stays where it was. Set it back and the border returns.
8. Set **Background texture** to `None`. **Expect:** the fill disappears, the border stays.

## 5b-3. Border offset

1. With a visible border of 2–4px, drag **Border offset** positive. **Expect:** the border moves
   *outward*, away from the panel's fill, leaving a gap between the two — a halo.
2. Drag it negative. **Expect:** the border moves *inward*, overlapping the fill — an inset frame.
3. Return it to 0. **Expect:** the border sits exactly on the panel's edge.
4. With a non-zero offset, drag the panel. **Expect:** the border moves with it, keeping its offset.
5. With a non-zero offset, change the **Frame strata**. **Expect:** the border stays with the panel —
   it is a child frame, so it cannot end up on a different layer.
6. `/reload`. **Expect:** the offset persisted.
8. Reload. **Expect:** both texture choices survived.
9. **The uninstall case:** pick a texture supplied by another addon, disable that addon, `/reload`.
   **Expect:** the panel renders **plain** — not invisible, not an error — and re-enabling the addon
   brings the texture straight back. The choice was never overwritten.

## 5b-2. Colour pickers (regression: they used to do nothing)

AceGUI's ColorPicker only fires `OnValueConfirmed` when the **opacity slider** is touched, so binding
that alone meant an ordinary colour change never reached the addon — the swatch updated and the panel
did not. Both pickers now bind `OnValueChanged` too. This is live-client-only: the headless suite
stubs AceGUI out entirely, so **nothing below is covered by a unit test.**

1. Click the **Background colour** swatch. Pick a strong colour (bright green). **Do not touch the
   opacity slider.** Click **OK**.
2. **Expect:** the panel is green. Both the swatch *and* the panel must change — a green swatch over
   an unchanged panel is exactly the old bug.
3. Watch the panel while dragging inside the colour wheel, before clicking OK. **Expect:** it
   updates live.
4. Repeat both steps for **Border colour** with a border thickness of 4 or more. **Expect:** the
   border takes the colour.
5. Open a picker, change the colour, and press **Cancel**. **Expect:** the panel returns to its
   previous colour.
6. Change a colour, `/reload`. **Expect:** the colour persisted.
7. Now change a colour **and** drag the opacity slider. **Expect:** both apply, and the panel's
   opacity is the picker's alpha multiplied by the **Panel opacity** slider (under Visibility).

## 5c. Class colour

1. Tick **Class colour** next to **Background colour**. **Expect:** the panel takes your class
   colour, and the colour swatch beside it greys out.
2. Check the panel's **opacity is unchanged** — class colour replaces the hue, not the alpha. Drag
   **Opacity** and confirm it still works.
3. Tick **Class colour** next to **Border colour** too, and confirm the two are independent: untick
   the background one and the border stays class-coloured.
4. Untick both. **Expect:** the original colours come back exactly — they were never overwritten.
5. Log in on a character of a **different class**. **Expect:** that character's panels (if
   class-coloured) show the new class colour.

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
2. `/pm unlock` **in combat** → **Expect:** a grey "unlock queued" notice; panels stay locked.
3. Leave combat → **Expect:** panels unlock by themselves and print "panels unlocked".
4. Pull again, `/pm unlock`, then `/pm lock` while still in combat, then leave combat.
   **Expect:** panels stay **locked** — the explicit lock cleared the queue.
4b. Pull again and tick a panel's **Unlock** box in the settings editor. **Expect:** the same grey
   notice, and the checkbox **unticks itself** rather than claiming a state the panel is not in.
   Leave combat → that one panel unlocks.
5. `/pm config` **in combat** → **Expect:** a grey "cannot open settings during combat" notice and
   **no** panel opens.
6. Leave combat → **Expect:** the options panel does **not** pop open by itself. Run `/pm config`
   yourself and it opens.

## 9. Options panel

1. `/pm config` → **Expect:** the landing page with the logo, the tagline and the slash-command list,
   which matches `/pm help` exactly.
2. Click **General** → **Expect:** a two-column grid of settings, section headings, a **Defaults**
   button top-right in the standard dark/gold style — **not** Blizzard's red stone button. (A red
   button means it was created too early; see `options-ui-§5`.)
3. Confirm the scrollbar is **present but greyed out** on a page that fits, and that the body does not
   jump width when you tab between pages.
4. Toggle **Unlock panels** and **Test mode** → **Expect:** they do exactly what the slash
   commands do.
5. Click **Panels** → **Expect:** a **Create** section (name box + Create button) and an **Edit**
   section (a panel dropdown + one editor).
5b. **Layout check.** The panel dropdown spans the **full width** with **no "Panel" label** above it,
   and there is **no heading naming the selected panel** between it and the editor box. The gap
   below `Create` and the gap below `Edit` must look **identical** — the dropdown carries no label,
   so a compensating spacer keeps the two headings evenly spaced. Inside the editor, `Name`,
   `Position and size`, `Background`, `Border` and `Visibility` each have a divider-flanked heading
   with breathing room, and no two unrelated controls share a line. Under `Visibility`, **Panel
   opacity** is alone on its row, with **Faded opacity** and **Show on mouseover only** paired on the
   next. Compare against KickCD's Icons page for the house rhythm.
5b-2. **Dropdown vs scrolling.** Open any dropdown on the Panels page (the panel selector, Anchor,
   Frame strata, or either texture picker) and — without closing it — **scroll the page**, first with
   the mouse wheel and then by dragging the scrollbar. **Expect:** the open list closes immediately
   in both cases. It must never be left floating over, or outside, the settings window while the
   control it belongs to scrolls away. Re-open it afterwards to confirm one click still opens it
   (rather than the click being eaten as a toggle-shut).
5c. **Top action row.** **Reset** and **Delete** sit directly under **Enabled** and **Unlock**, at
   the top of the editor — not at the bottom. The **Frame name** text has a clear gap between it and
   the name box's Okay button.
5d. **Rename.** Change **Panel name** and press Enter. **Expect:** the dropdown entry and the
   **Frame name** line both update. Try renaming to an existing panel's name →
   **Expect:** a cyan-tagged error and the box reverts to the old name rather than showing a lie.
5e. **Reset.** Configure a panel heavily — resize it, move it, change both textures and both colours,
   turn on mouseover — then press **Reset**. **Expect:** it returns to a brand-new panel's
   appearance *and position* (centre of the screen), every control in the editor re-reads the new
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
10. Change a panel's width slider and colour picker → **Expect:** the panel updates as you release.
11. Tick **Unlock** on the selected panel → **Expect:** *only that panel* grows an outline and a
    drag handle; the others stay inert. Drag it, then untick.
12. Check the **Frame name** line in the editor reads `PanelMaster_Panel_<slug>` for that panel.
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
   at the left of the title bar, a scrollbar on the right, `0 / 500 lines` bottom-right.
2. `/pm debug on` → **Expect:** a cyan-tagged chat ack with **ON in green**; the console shows
   `[Debug] logging enabled` followed by an `[Init]` line naming the addon, version, schema and
   profile.
3. Create, drag and recolour a panel → **Expect:** one `[Panel]` line per action, and the line counter
   climbing.
4. Change a setting → **Expect:** exactly **one** `[Set]` line (not one per reactor).
5. **Drag the scrollbar** → **Expect:** the log scrolls. **Wheel-scroll the log** → **Expect:** the
   thumb follows. No Lua error either way.
6. Click **Copy** → **Expect:** a selectable window with the same lines, no colour codes. Ctrl+C, Esc.
7. Click **Clear** → **Expect:** an empty log and `0 / 500 lines`.
8. Click the `Debug: ON` toggle → **Expect:** it flips to red `OFF` and prints the matching chat ack.
9. `/pm debug dump` → **Expect:** a `[Dump]` block listing each panel with `frame=yes`, and
   `0 orphaned`. Any `frame=NO` or a non-zero orphan count is a rendering bug.
10. `Esc` with the console focused → **Expect:** it closes (`UISpecialFrames`).
11. `/reload` → **Expect:** logging is **off** again (session-only) and the console is closed.

## 11b. Frame names and anchoring

The addon's public contract, and the one thing no unit test can prove works in a live client.

1. Create a panel called **Chat BG**. The editor's **Frame name** line should read
   `PanelMaster_Panel_Chat_BG`.
2. In a macro or a `/run`, confirm the frame really exists under that name:
   `/run print(PanelMaster_Panel_Chat_BG:GetWidth())` → **Expect:** the panel's width.
3. Anchor something to it:
   `/run local f=CreateFrame("Frame",nil,UIParent);f:SetSize(20,20);local t=f:CreateTexture();t:SetAllPoints();t:SetColorTexture(1,0,0);f:SetPoint("TOPLEFT","PanelMaster_Panel_Chat_BG","TOPLEFT",0,0)`
   → **Expect:** a red square appears at the panel's top-left corner and **follows it** when you
   unlock and drag the panel.
4. Try creating a second panel called **Chat-BG**. **Expect:** refused, with a message naming the
   frame name it would have collided on.
5. Rename **Chat BG** to **Chat Backdrop**. **Expect:** the Frame name line updates, and the red
   square from step 3 stops following the panel — the documented consequence of renaming.
6. `/reload` and repeat step 2. **Expect:** the name is the same, because it is derived from the
   panel name rather than assigned at runtime.

## 12. Profiles

1. Create a couple of panels on one character.
2. Log in on an alt → **Expect:** no panels; the layout is per-character.
3. Back on the first character → **Expect:** the panels are exactly as you left them.

## 13. Standalone

1. Disable every other addon except PanelMaster and its libraries. **Expect:** it loads and behaves
   identically — no suite, no other addon, is a dependency.
2. Re-enable a UI skin (ElvUI or similar) and reopen `/pm config` → **Expect:** the Defaults button is
   skinned like the rest of the AceGUI widgets, not left on stock red art.
