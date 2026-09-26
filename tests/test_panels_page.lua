-- The Panels page as a built page: its tab strip, its chrome band and the editor tabs under it,
-- driven through the real E:BuildPage / E:Rebuild against the AceGUI mock. Peeled out of
-- tests/test_panel.lua (ATS-05), which keeps registration, opening, the repaint policy and panel
-- scale; the runner lists this suite straight after that one, so the cases run in the same order.

local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local P = NS.Panel
local E = NS.PanelEditor

-- ── The Panels page's tab strip (options-ui-§13) ────────────────────────────────
-- The editor's five subjects are TABS, and only the active one is built. These cases drive the
-- real builder -- E:BuildPage, the real rebuilder, the real AceGUI mock -- rather than the counting
-- stand-ins in tests/test_panel.lua, because "which controls exist right now" is exactly what a
-- stand-in cannot say.
--
-- Into a page context of their OWN, not P.panels. The repaint-policy block in tests/test_panel.lua
-- empties that page's rebuilder list wholesale, the real rebuilder included, and BuildPage runs
-- once per session so nothing puts it back; building a second context is also what keeps these
-- cases from leaving a built page and a live selection behind for whatever runs next.
local function freshPanelsCtx()
  local ctx = NS.Helpers.CreatePanel(nil, "Panels", { pageKey = "panels" })
  ctx.dropdowns, ctx.rebuilders = {}, {}
  ctx.refreshers = ctx.refreshers or {}
  E:BuildPage(ctx)
  return ctx
end

-- Every AceGUI widget created while `fn` runs, by the label it was given.
local function labelsBuiltBy(fn)
  local created = T.mocks.LibStub("AceGUI-3.0", true).__created
  local from = #created + 1
  fn()
  local labels = {}
  for i = from, #created do
    local w = created[i]
    if w.labelText then labels[w.labelText] = true end
  end
  return labels
end

-- Render one named tab of a freshly built Panels page, and answer the labels it drew.
local function labelsOfTab(ctx, tab)
  return labelsBuiltBy(function()
    ctx.activeTab = tab
    E:Rebuild(ctx)
  end)
end

test("Panels page: only the active tab's controls are built", function()
  NS.Registry:DeleteAll()
  local rec = NS.Registry:New("Tabbed")
  E.__setSelectedID(rec.id)
  local ctx = freshPanelsCtx()

  local position = labelsOfTab(ctx, "Position and size")
  assertTrue(position["Width"], "the Position and size tab did not build Width")
  assertTrue(position["Panel scale"], "the Position and size tab did not build Panel scale")
  assertFalse(position["Background texture"] == true,
    "the Position and size tab built a surface control")
  -- The name box is in the chrome band, built once for the session. A tab render that produced it
  -- would be the General tab coming back inside another one.
  assertFalse(position["Panel name"] == true, "a tab render rebuilt the band's name box")

  -- The merged tab: the fill AND the edge, which were two subsections of two and four controls.
  -- The merge stays; what options-ui-§7 added is a heading per half, and options-ui-§16 the
  -- canonical border names -- "Border style", not "Border texture".
  local surface = labelsOfTab(ctx, "Background and border")
  assertTrue(surface["Background texture"], "the merged tab lost the background")
  assertTrue(surface["Border style"], "the merged tab lost the border")

  local fade = labelsOfTab(ctx, "Opacity and fade")
  assertTrue(fade["Panel opacity"], "the Opacity and fade tab did not build Panel opacity")
  assertTrue(fade["Show on mouseover only"], "the Opacity and fade tab lost the mouseover switch")

  NS.Registry:DeleteAll()
  E.__setSelectedID(nil)
end)

-- THE BAND MUST SURVIVE BEING BUILT BEFORE THE CANVAS HAS A WIDTH.
--
-- `ctx.chrome` is zero-wide until the settings canvas lays itself out, and the
-- FIRST page a player opens is rendered before that happens -- the library says
-- so in its own words at `replaceOnResize`, which is how the tab strip heals
-- itself when the width arrives. The band's block is built ONCE for the session
-- (settings/Panel.lua's `built` flag), so the header frame's size hook is its only
-- way to learn the width it has to lay its row out at; the case below this one
-- pins that the width actually reaches the layout.
--
-- This case once claimed the hook fixed an empty band, on the theory that a layout
-- at zero width gave both controls half of nothing. It did not: the List layout
-- reads the 300 a SimpleGroup starts with, never zero. The empty band was a hidden
-- pooled block, and the pool case below pins that.
--
-- red under: dropping the OnSizeChanged hook, or re-laying out on every size
-- event (the height change SetChromeHeight causes fires the same script, and a
-- layout that answered it would loop).
test("Panels page: the header block re-lays out when the canvas learns its width", function()
  NS.Registry:DeleteAll()
  NS.Registry:New("Sized")
  local ctx = freshPanelsCtx()

  -- The header frame is the chrome kid carrying the hook.
  local header
  for _, kid in ipairs(ctx.__chromeKids or {}) do
    if kid.__scripts and kid.__scripts.OnSizeChanged then header = kid end
  end
  assertTrue(header ~= nil,
    "the page header frame carries no OnSizeChanged hook, so a band built at zero width stays empty")

  local block = ctx.__pmHeaderBlock
  assertTrue(block ~= nil, "the header block must be reachable to be re-laid out")
  local before = block.layoutCount or 0

  header.__scripts.OnSizeChanged(header, 0)
  assertEqual(block.layoutCount or 0, before, "a zero width is not a width to lay out against")

  header.__scripts.OnSizeChanged(header, 640)
  assertTrue((block.layoutCount or 0) > before, "the block did not re-lay out when the width arrived")

  local settled = block.layoutCount
  header.__scripts.OnSizeChanged(header, 640)
  assertEqual(block.layoutCount, settled,
    "the same width must be a no-op — SetChromeHeight fires this script too")

  NS.Registry:DeleteAll()
end)

-- THE BAND'S BLOCK IS SHOWN BY THE BAND, BECAUSE NOTHING ELSE WILL SHOW IT.
--
-- Real AceGUI pools its widgets. Release hides the frame and parks the widget, and a later Create of
-- the same type hands it back WITHOUT a Show: only a parent container's layout shows a child's frame
-- (AceGUI-3.0.lua, the List layout). The band's block is parented by hand to the header frame and is
-- no AceGUI container's child, so no layout ever shows it. Whenever any addon had released a
-- SimpleGroup earlier in the session -- every settings page with a row, and every re-render --
-- the band came back hidden: its height and divider stayed, and the Panel picker and the Create new
-- panel box inside it were gone.
--
-- The kit's factory never reuses a widget, so the case hands the band a hidden one, which is exactly
-- what the pool hands it. Inside the block, showing the row and its two controls is the List
-- layout's job, as it is in the client; the case asserts that they are the block's descendants and
-- that nothing hid them.
--
-- red under: dropping the Show after the SetParent.
test("Panels page: the band's block is shown even when AceGUI hands it back from the pool", function()
  NS.Registry:DeleteAll()
  NS.Registry:New("Pooled")
  local AceGUI = T.mocks.LibStub("AceGUI-3.0", true)
  local create = AceGUI.Create
  local first
  AceGUI.Create = function(self, wtype)
    local w = create(self, wtype)
    if wtype == "SimpleGroup" and not first then
      first = w
      w.frame:Hide()
    end
    return w
  end
  local ok, ctx = pcall(freshPanelsCtx)
  AceGUI.Create = create
  assertTrue(ok, tostring(ctx))

  local block = ctx.__pmHeaderBlock
  assertTrue(block ~= nil, "the header block must be reachable")
  assertTrue(block == first, "the band's block is no longer the first SimpleGroup the page creates")
  assertTrue(block.frame:IsShown(),
    "a pooled SimpleGroup comes back hidden, and the band's block is nobody's AceGUI child to show it")

  local inBlock = {}
  local function walk(w)
    for _, child in ipairs(w.children or {}) do inBlock[child] = true; walk(child) end
  end
  walk(block)
  local picker = ctx.__pmPicker
  assertTrue(picker ~= nil and inBlock[picker] == true, "the Panel picker is not inside the band's block")
  assertTrue(picker.frame:IsShown(), "the Panel picker is hidden")
  local box
  for w in pairs(inBlock) do
    if w.type == "EditBox" and w.labelText == "Create new panel" then box = w end
  end
  assertTrue(box ~= nil, "the Create new panel box is not inside the band's block")
  assertTrue(box.frame:IsShown(), "the Create new panel box is hidden")

  NS.Registry:DeleteAll()
end)

-- THE ROW IS LAID OUT AT THE BAND'S WIDTH, NOT AT 300.
--
-- AceGUI's List layout reads `content.width` before it asks the frame for a width, and a
-- SimpleGroup's OnAcquire sets that to 300 with SetWidth(300). Anchoring the block to both sides of
-- the header frame stretches the frame and leaves `content.width` alone, so a DoLayout on its own
-- lays the row out at 300 pixels whatever the band's real width is, and each half-width control gets
-- 150. The width reaches the layout through the widget's own SetWidth, which is what writes it.
--
-- red under: dropping the SetWidth before the DoLayout in the OnSizeChanged hook.
test("Panels page: a size change lays the band's row out at the band's own width", function()
  NS.Registry:DeleteAll()
  NS.Registry:New("Wide")
  local ctx = freshPanelsCtx()

  local header
  for _, kid in ipairs(ctx.__chromeKids or {}) do
    if kid.__scripts and kid.__scripts.OnSizeChanged then header = kid end
  end
  assertTrue(header ~= nil, "the page header frame carries no OnSizeChanged hook")

  local block = ctx.__pmHeaderBlock
  local widthAtLayout
  local doLayout = block.DoLayout
  block.DoLayout = function(self, ...)
    widthAtLayout = self.width
    return doLayout(self, ...)
  end

  header.__scripts.OnSizeChanged(header, 720)
  assertEqual(widthAtLayout, 720, "the row was laid out at a width other than the band's")

  NS.Registry:DeleteAll()
end)

-- The create box says what pressing Enter DOES. It read "New panel name", which
-- names the field's contents and answers a question nobody had -- the band holds
-- two controls that both name a panel, and the reader's question at this one is
-- which of them makes one. The picker beside it already reads as the picker.
--
-- red under: reverting the label, or leaving the tooltip title on the old wording
-- (the title is what the tooltip's own heading shows, so the two drifting apart
-- is a control that introduces itself twice under different names).
test("Panels page: the create box is labeled for the act, not for its contents", function()
  NS.Registry:DeleteAll()
  local labels = labelsBuiltBy(function() freshPanelsCtx() end)
  assertTrue(labels["Create new panel"], "the page header lost the create box's label")
  assertFalse(labels["New panel name"] == true, "the old, contents-naming label came back")
  NS.Registry:DeleteAll()
end)

-- The Opacity and fade tab's LAYOUT, not just its contents. The two sliders are
-- the same question asked twice -- how visible, and how visible while the cursor
-- is elsewhere -- both 0..1, and they belong side by side where a reader can
-- compare them. The switch that decides whether the second one applies at all
-- goes underneath, on its own line.
--
-- It was the other arrangement: Panel opacity alone on the first row, then Faded
-- opacity paired with the checkbox. That put the two numbers on different lines
-- and gave the checkbox a slider to look like a companion to.
--
-- red under: pairing either slider with the checkbox again, or splitting the two
-- sliders across rows.
test("Panels page: the two opacity sliders share a row, and the switch is below", function()
  NS.Registry:DeleteAll()
  local rec = NS.Registry:New("Faded")
  E.__setSelectedID(rec.id)
  local ctx = freshPanelsCtx()

  local created = T.mocks.LibStub("AceGUI-3.0", true).__created
  local from = #created + 1
  ctx.activeTab = "Opacity and fade"
  E:Rebuild(ctx)

  --- The row (a SimpleGroup) that holds a widget with this label, or nil.
  local function rowHolding(label)
    for i = from, #created do
      local w = created[i]
      if w.type == "SimpleGroup" then
        for _, child in ipairs(w.children or {}) do
          if child.labelText == label then return w end
        end
      end
    end
  end

  local panelRow  = rowHolding("Panel opacity")
  local fadedRow  = rowHolding("Faded opacity")
  local switchRow = rowHolding("Show on mouseover only")
  assertTrue(panelRow ~= nil, "the tab did not build Panel opacity")
  assertTrue(fadedRow ~= nil, "the tab did not build Faded opacity")
  assertTrue(switchRow ~= nil, "the tab lost the mouseover switch")

  assertTrue(panelRow == fadedRow, "the two opacity sliders must share one row")
  assertFalse(switchRow == panelRow, "the switch must not sit beside a slider")

  NS.Registry:DeleteAll()
  E.__setSelectedID(nil)
end)

test("Panels page: an unknown active tab heals to the first one rather than drawing nothing",
  function()
    NS.Registry:DeleteAll()
    local rec = NS.Registry:New("Healed")
    E.__setSelectedID(rec.id)
    local ctx = freshPanelsCtx()

    -- The shape a renamed tab leaves behind in a context that outlives the rename. "General" is
    -- now one of those names, and the fallback is keyed off EDITOR_TABS[1] rather than off a tab
    -- constant precisely so that removing a tab cannot leave the fallback pointing at nothing.
    local labels = labelsOfTab(ctx, "Nonexistent tab")
    assertTrue(labels["Panel name"],
      "a stale tab pointer drew an empty editor instead of falling back to the first tab")
    assertEqual(ctx.activeTab, E.TABS[1], "the stale pointer was not healed")

    NS.Registry:DeleteAll()
    E.__setSelectedID(nil)
  end)

test("Panels page: creating and picking a panel are ABOVE the strip, in the chrome band", function()
  -- The strip is the EDITOR's alone. Making a panel and choosing which panel to edit are not two of
  -- the five subjects, and a tab you have to leave to pick a different panel would be one.
  for _, name in ipairs(E.TABS) do
    assertFalse(name == "Create", "Create was folded into the tab strip")
    assertFalse(name == "Edit", "Edit was folded into the tab strip")
  end

  -- They used to be two untabbed sections at the top of the SCROLL, which put page-wide controls
  -- under whichever tab happened to be showing (options-ui-§14). They are in the page's chrome
  -- band now, and the source half of this assertion is what pins the direction of that move: a
  -- host that put them back would do it by calling `section` again.
  local src = assert(io.open("settings/PanelEditor.lua", "r"))
  local body = src:read("*a")
  src:close()
  assertEqual(body:find('section(ctx, "Create")', 1, true), nil,
    "the Create section is back in the scroll, below the strip")
  assertEqual(body:find('section(ctx, "Edit")', 1, true), nil,
    "the Edit section is back in the scroll, below the strip")

  -- And the rendered half, which is the one that can fail for a reason the grep cannot see: the
  -- block really is drawn, and the picker inside it is the widget the page keeps a handle on.
  local ctx = freshPanelsCtx()
  NS.Registry:DeleteAll()
  local rec = NS.Registry:New("Banded")
  E.__setSelectedID(rec.id)
  E:Rebuild(ctx)
  assertTrue(ctx.__pmPicker ~= nil, "the page drew no panel picker in its chrome band")
  assertEqual(ctx.__pmPicker.labelText, "Panel",
    "the picker lost the label it needs now that no section heading names it")
  NS.Registry:DeleteAll()
  E.__setSelectedID(nil)
end)

-- Every AceGUI widget under `w`, at any depth. The band is three Flow rows inside a List block, so
-- nothing in it is a direct child of the block itself.
local function descendants(w, out)
  out = out or {}
  for _, child in ipairs(w.children or {}) do
    out[#out + 1] = child
    descendants(child, out)
  end
  return out
end

-- Every AceGUI widget created while `fn` runs, keyed by the string it introduces itself with: the
-- label for a labeled control, and the button's own text for a Button, which carries no label.
local function captionsBuiltBy(fn)
  local created = T.mocks.LibStub("AceGUI-3.0", true).__created
  local from = #created + 1
  fn()
  local caps = {}
  for i = from, #created do
    local w = created[i]
    if w.labelText then caps[w.labelText] = true end
    if w.type == "Button" and w.text then caps[w.text] = true end
  end
  return caps
end

-- The six acts, read out of the CURRENT build of the General tab. They are rebuilt on every
-- selection change now, so there is no parked table to read and no stale widget to read it from --
-- which is the whole reason the re-pointing machinery the band needed could be deleted.
local function actsOnGeneral(ctx)
  ctx.activeTab = "General"
  local created = T.mocks.LibStub("AceGUI-3.0", true).__created
  local from = #created + 1
  E:Rebuild(ctx)
  local acts = {}
  local BY_LABEL = { ["Panel name"] = "name", ["Copy settings from panel"] = "copy",
                     ["Enabled"] = "enabled", ["Unlock"] = "unlocked" }
  local BY_TEXT  = { Reset = "reset", Delete = "delete" }
  for i = from, #created do
    local w = created[i]
    local key = (w.labelText and BY_LABEL[w.labelText])
             or (w.type == "Button" and w.text and BY_TEXT[w.text])
    if key then acts[key] = w end
  end
  return acts
end

-- THE SIX PAGE-WIDE ACTS ARE ON THE GENERAL FIRST TAB (options-ui-§14 as of standard v2.40.0).
--
-- Copy, Enabled, Unlock, Reset and Delete were all inside the editor's General tab, and every one of
-- them acts on the panel WHOLE rather than on the subject that tab was about -- which is the exact
-- shape the rule names, and which the library spells out at O.PageHeader. The name box went with
-- them, because what was left behind was a one-control tab.
--
-- Both halves matter and they fail for different reasons. That the acts EXIST in the band is the
-- move; that no TAB draws them is the move not having been half-made -- a host that copied the
-- controls into the band and left the section behind would pass the first half alone.
--
-- red under: putting any of the six back into a `sections[...]` function, or dropping one on the
-- way into the band.
test("Panels page: the panel-wide acts are on the General FIRST tab, and the band keeps the picker",
  function()
  NS.Registry:DeleteAll()
  local rec = NS.Registry:New("Banded acts")
  E.__setSelectedID(rec.id)
  local ctx = freshPanelsCtx()
  E:Rebuild(ctx)

  -- THE BAND KEEPS THE IDENTITY CONTROLS, and that half of §14 is untouched by v2.40.0: a page
  -- that edits one instance out of many still says which one, permanently, above the strip. A band
  -- left as a bare divider because the picker moved into a tab is the shape the rule exists to
  -- forbid, so this is the assertion that must not be relaxed with the others.
  local inBlock = {}
  for _, w in ipairs(descendants(assert(ctx.__pmHeaderBlock))) do inBlock[w] = true end
  assertTrue(inBlock[ctx.__pmPicker], "the picker left the band, which §14 forbids outright")

  -- ONE ROW now, not three. The band reserving three rows' height for controls that moved is a hole
  -- of exactly the size they used to fill.
  assertTrue((ctx.__bannerHeight or 0) < NS.Helpers.BANNER_H * 2,
    "the band still reserves three rows of height for acts that are on a tab now")

  -- The six draw on `General`, by the caption a player reads.
  local ACTS = { "Panel name", "Copy settings from panel", "Enabled", "Unlock", "Reset", "Delete" }
  local onGeneral = captionsBuiltBy(function()
    ctx.activeTab = "General"
    E:Rebuild(ctx)
  end)
  for _, caption in ipairs(ACTS) do
    assertTrue(onGeneral[caption] == true,
      ("the General tab does not draw '%s'"):format(caption))
  end

  -- And NO OTHER tab draws any of them. §14's third condition: acts split across the band and a tab
  -- -- or across two tabs -- are worse than either shape alone, because the player has to learn
  -- which is where. This is also the half that catches a move made by copying rather than cutting.
  for _, tab in ipairs(E.TABS) do
    if tab ~= "General" then
      local caps = captionsBuiltBy(function()
        ctx.activeTab = tab
        E:Rebuild(ctx)
      end)
      for _, caption in ipairs(ACTS) do
        assertFalse(caps[caption] == true,
          ("the '%s' tab draws '%s', which belongs to General alone"):format(tab, caption))
      end
    end
  end

  NS.Registry:DeleteAll()
  E.__setSelectedID(nil)
end)

-- THE ACTS FOLLOW THE PICKER, and under v2.40.0 they do it the easy way again.
--
-- In the band they were built ONCE for the session, so every callback had to resolve the record
-- fresh and every value had to be pushed back in place by a refreshHeaderActs pass on each rebuild
-- -- machinery nothing else on this page needed. On the General tab they are rebuilt per selection
-- against a `rec` upvalue, so acting on the right panel is true by construction and that pass is
-- gone.
--
-- The assertions are unchanged and that is the point: the property a player cares about does not
-- depend on which shape delivers it. Switching panels must move the name, the Enabled state and
-- the copy list, and Delete must remove what the picker is showing.
--
-- red under: a tab that is not rebuilt on the picker's callback, or one that closes over a stale
-- record (Delete goes on deleting the first panel ever selected).
test("Panels page: the acts follow the picker rather than the panel they were built on",
  function()
    NS.Registry:DeleteAll()
    local first  = NS.Registry:New("Alpha")
    local second = NS.Registry:New("Bravo")
    NS.Registry:Set(second.id, "enabled", false)

    E.__setSelectedID(first.id)
    local ctx = freshPanelsCtx()
    E:Rebuild(ctx)

    -- The tab is rebuilt per selection, so the widgets are read back out of the current build
    -- rather than off a parked table.
    ctx.activeTab = "General"
    E:Rebuild(ctx)
    local acts = actsOnGeneral(ctx)
    assertEqual(acts.name.text, "Alpha", "the tab opened on a panel the picker is not showing")
    assertEqual(acts.enabled.value, true, "Alpha is enabled and the tab's switch disagrees")

    -- Through the picker's own callback, which is what a click does.
    ctx.__pmPicker:__fire("OnValueChanged", second.id)
    acts = actsOnGeneral(ctx)
    assertEqual(acts.name.text, "Bravo", "the rename box stayed on the previous panel")
    assertEqual(acts.enabled.value, false, "the Enabled switch stayed on the previous panel")

    -- The copy list is every OTHER panel, so it moves with the selection too.
    assertEqual(acts.copy.list[first.id], "Alpha", "the copy list does not offer the other panel")
    assertEqual(acts.copy.list[second.id], nil, "the copy list offers the selected panel itself")

    -- And the destructive act lands on what the picker is showing. This is the assertion a stale
    -- captured record fails.
    acts.delete.callbacks.OnClick(acts.delete, "OnClick")
    assertEqual(NS.Registry:Get(second.id), nil, "Delete did not remove the selected panel")
    assertTrue(NS.Registry:Get(first.id) ~= nil, "Delete removed the panel the band was built on")

    NS.Registry:DeleteAll()
    E.__setSelectedID(nil)
  end)

test("Panels page: the strip is drawn with ZERO panels, and the empty state is content", function()
  -- options-ui-§13. The page used to RELEASE its strip and give the band back when the registry was
  -- empty, on the argument that a strip over nothing is chrome for its own sake -- which is exactly
  -- the conditional no-strip state the rule forbids. It is also no longer survivable: the create
  -- box and the panel picker are IN that band now (options-ui-§14), so releasing it would take the
  -- only control that can make a panel off the screen at the moment the player needs it most.
  NS.Registry:DeleteAll()
  E.__setSelectedID(nil)
  local ctx = freshPanelsCtx()

  -- The strip's buttons are plain frames rather than AceGUI widgets, so they are counted off the
  -- library's own chrome ledger rather than out of the widget capture. Compared against the count
  -- for a page that HAS a panel rather than against a literal: the ledger also carries the content
  -- panel, and the invariant worth pinning is that the strip is the same either way, not what the
  -- library happens to park beside it.
  local populated = NS.Registry:New("Present")
  E.__setSelectedID(populated.id)
  E:Rebuild(ctx)
  local withPanels = #(ctx.__tabKids or {})
  local stripBefore = ctx.__tabKids
  assertTrue(withPanels >= #E.TABS, "the populated page drew fewer frames than it has tabs")
  -- The acts are TAB CONTENT now, so with no panel they are absent rather than disabled -- there
  -- is no record for them to act on, and the empty state is what the tab draws instead. The band's
  -- picker and create box stay either way, which is the half that has to survive an empty registry
  -- (options-ui-§14: releasing them would take the only control that can make a panel off screen).

  NS.Registry:DeleteAll()
  E.__setSelectedID(nil)
  local labels = labelsBuiltBy(function()
    ctx.activeTab = E.TABS[1]
    E:Rebuild(ctx)
  end)

  -- IDENTITY, not just the count. TabStrip drains its ledger into a FRESH table every time it
  -- draws, so a rebuild that skipped the strip would leave the previous one's table sitting there
  -- with the same number of entries in it -- which is exactly what a count-only assertion passes
  -- against, and what the `if #records > 0 then drawTabStrip(ctx) end` mutation this case exists to
  -- kill would have produced.
  assertFalse(ctx.__tabKids == stripBefore,
    "the strip was not redrawn for an empty registry — the old buttons were left standing")
  assertEqual(#(ctx.__tabKids or {}), withPanels,
    "the Panels page drew a different strip once the last panel was deleted")
  -- And the band itself is still occupied. The branch this replaces called __releaseChrome, which
  -- empties exactly this ledger -- taking the create box and the picker with it.
  assertTrue(#(ctx.__chromeKids or {}) > 0, "the chrome band was given back with the panels")
  assertTrue((ctx.__bannerHeight or 0) > 0, "the band's reserved height was given back")
  assertTrue(ctx.__pmPicker ~= nil, "the picker went with the band")

  -- And the empty state is INSIDE the page rather than in place of it. No editor control was built.
  -- Asked of a control the FIRST tab draws, which is what an editor built against no record would
  -- have produced. It used to ask about "Panel name", and that question stopped being able to fail
  -- when the name box moved into the band: no tab render draws it at all now.
  assertFalse(labels["Width"] == true, "an editor was built for a registry with no panels")

  -- The acts are TAB CONTENT now, so with no panel they are absent rather than disabled: there is
  -- no record for them to act on, and the empty state is what the tab draws in their place. What
  -- MUST survive an empty registry is the band -- §14 keeps the picker there in every state, and
  -- releasing the create box would take the only control that can make a panel off the screen at
  -- the moment the player needs it most.
  assertTrue(ctx.__pmPicker ~= nil, "the picker went with the panels")
  local bandCaps = {}
  for _, w in ipairs(descendants(assert(ctx.__pmHeaderBlock))) do
    if w.labelText then bandCaps[w.labelText] = true end
  end
  assertTrue(bandCaps["Panel"], "the band lost its picker on an empty registry")
  assertTrue(bandCaps["Create new panel"], "the band lost the only control that can make a panel")

  E.__setSelectedID(nil)
end)

test("Panels page: the Master controls tab closes on the canonical button pair", function()
  -- options-ui-§15: the two resets are the tab's closing button pair, and the hook that draws them
  -- is keyed on the GROUP NAME. A key that disagreed with the group would detach silently -- the
  -- tab would simply have no buttons, and nothing would error.
  local ctx = P.general
  local created = T.mocks.LibStub("AceGUI-3.0", true).__created
  local from = #created + 1
  ctx.activeTab = "Master controls"
  ctx._dirty = true
  local onShow = ctx.panel:GetScript("OnShow")
  onShow(ctx.panel)

  local seen = {}
  for i = from, #created do
    local w = created[i]
    if w.type == "Button" and w.text then seen[w.text] = true end
  end
  assertTrue(seen["Reset position"], "the Master controls tab drew no Reset position button")
  assertTrue(seen["Reset all settings"], "the Master controls tab drew no Reset all settings button")
end)

test("Panels page: the Reset all settings tooltip says it resets this profile, as Profiles -> Reset Profile does", function()
  -- The composer picks the wording from the Options descriptor (LibKa0s-Options minor 18). With no
  -- `resetProfile` it says "Restore every setting in this addon to its default.", which overstates a
  -- reset that leaves every other profile alone. This addon's reset IS a profile reset
  -- (Sl:DoResetAll) and it ships the Profiles page, so it supplies `resetProfile` and
  -- `profilesPage = true`, and the tooltip names the equivalence options-ui-§12 asks for.
  local ctx = P.general
  local created = T.mocks.LibStub("AceGUI-3.0", true).__created
  local from = #created + 1
  ctx.activeTab = "Master controls"
  ctx._dirty = true
  ctx.panel:GetScript("OnShow")(ctx.panel)

  local button
  for i = from, #created do
    local w = created[i]
    if w.type == "Button" and w.text == "Reset all settings" then button = w end
  end
  assertTrue(button ~= nil, "the Master controls tab drew no Reset all settings button")
  local saved, got = T.mocks.GameTooltip, {}
  T.mocks.GameTooltip = setmetatable({
    SetText = function(_, text) got.title = text end,
    AddLine = function(_, text) got.body = text end,
  }, { __index = function() return function() end end })
  local ok, err = pcall(button.__fire, button, "OnEnter")
  T.mocks.GameTooltip = saved
  assertTrue(ok, tostring(err))
  assertEqual(got.title, "Reset all settings")
  assertEqual(got.body, "Reset the current profile to its defaults \226\128\148 the same thing Profiles "
    .. "-> Reset Profile does. Your other profiles are not affected.")
end)

test("Options descriptor: resetProfile resets the live db's active profile, exactly once", function()
  -- The descriptor's `resetProfile` is read in one other place, O.RestoreAllDefaults. This addon never
  -- calls that: its global reset is Sl:DoResetAll. So the field is driven here through the library's
  -- own reader, and it must be the active profile's reset, once, wiped in place, and nothing more.
  local db = NS.db
  local profile = db.profile
  NS.Schema:Set("settings.gridSize", 8)
  assertEqual(NS.Schema:Get("settings.gridSize"), 8, "the precondition did not take")
  local calls, real = 0, db.ResetProfile
  db.ResetProfile = function(...) calls = calls + 1; return real(...) end
  local ok, err = pcall(NS.Helpers.RestoreAllDefaults)
  db.ResetProfile = real
  assertTrue(ok, tostring(err))
  assertEqual(calls, 1, "the descriptor's resetProfile did not reset the profile exactly once")
  assertEqual(NS.Schema:Get("settings.gridSize"), NS.Schema:Default("settings.gridSize"),
    "the active profile kept a changed setting")
  assertTrue(db.profile == profile, "the reset replaced the profile table instead of wiping it in place")
end)

test("Panels page: every color swatch is followed by a 'Use class color' companion", function()
  -- options-ui-§17, and the assertion that is NOT vacuous for this addon: its colors live on panel
  -- RECORDS rather than on schema rows, so the row-walk in tests/test_schema.lua cannot see them.
  -- Every pair is emitted by one function driven off C.COLOR_FIELDS, and this walks the tabs those
  -- five colors are drawn on and checks what the editor actually built.
  --
  -- Dies under renaming the checkbox back to "Class color", which is what it was called before the
  -- standard named it, and under a color that gains no companion at all.
  NS.Registry:DeleteAll()
  local rec = NS.Registry:New("Companioned")
  E.__setSelectedID(rec.id)
  local ctx = freshPanelsCtx()

  local WANTED = {
    ["Background and border"] = { "Background color", "Border color" },
    ["Accent bar"]            = { "Bar color", "Border color" },
    ["Artwork"]               = { "Artwork color" },
  }
  -- Matched EXACTLY: no swatch carries a `(opacity)` suffix any more, hand-drawn or composed
  -- (owner's decision 2026-09-12; the case below holds that in both class-color states).
  local seen = 0
  for tab, swatches in pairs(WANTED) do
    local labels = labelsOfTab(ctx, tab)
    for _, swatch in ipairs(swatches) do
      assertTrue(labels[swatch], tab .. " lost its " .. swatch .. " swatch")
      seen = seen + 1
    end
    assertTrue(labels["Use class color"],
      tab .. " drew a color swatch with no 'Use class color' companion beside it")
  end
  -- Every color the record has is accounted for, so a sixth added later cannot slip past this.
  local total = 0
  for _ in pairs(NS.Constants.COLOR_FIELDS) do total = total + 1 end
  assertEqual(seen, total, "the editor draws a color this case does not walk")

  NS.Registry:DeleteAll()
  E.__setSelectedID(nil)
end)

test("Panels page: no swatch label carries '(opacity)', class color on or off", function()
  -- Owner's decision, 2026-09-12: the gray `(opacity)` suffix is gone from all five swatches. The
  -- composed three lost it with #48; the hand-drawn Background and Artwork colors kept it, so the
  -- page said the same thing two ways. Each tooltip already says the opacity still applies.
  --
  -- Both states, and both ways a label is set: the build (the flags read off the record) and the
  -- companion's own callback flipping them in place. Dies under the suffix returning on either path.
  local TABS = { "Background and border", "Accent bar", "Artwork" }
  for _, state in ipairs({ false, true }) do
    NS.Registry:DeleteAll()
    local rec = NS.Registry:New("Unsuffixed")
    for _, flag in pairs(NS.Constants.COLOR_FIELDS) do NS.Registry:Set(rec.id, flag, state) end
    E.__setSelectedID(rec.id)
    local ctx = freshPanelsCtx()
    local created = T.mocks.LibStub("AceGUI-3.0", true).__created
    for _, tab in ipairs(TABS) do
      local from = #created + 1
      ctx.activeTab = tab
      E:Rebuild(ctx)
      local to = #created
      for i = from, to do
        local w = created[i]
        if w.labelText == "Use class color" then w:__fire("OnValueChanged", not state) end
      end
      for i = from, to do
        local label = created[i].labelText
        assertFalse(type(label) == "string" and label:find("(opacity)", 1, true) ~= nil,
          ("%s drew %q with class color %s"):format(tab, tostring(label), tostring(state)))
      end
    end
  end

  NS.Registry:DeleteAll()
  E.__setSelectedID(nil)
end)

test("Panels page: every color declares WHOSE class it means, and all five are the player's",
  function()
    -- options-ui-§17 requires the intent DECLARED rather than inferred from the path, because a
    -- path cannot be trusted to say it. A panel is chrome: it tracks no unit and has no unit token
    -- to ask about, so every one of them is the player's and `Util.ResolveColor` passes a nil unit.
    local C = NS.Constants
    for field in pairs(C.COLOR_FIELDS) do
      assertEqual(C.COLOR_CLASS_SOURCE[field], "player",
        field .. " has no declared class source — an audit reads that declaration, not the path")
    end
    for field in pairs(C.COLOR_CLASS_SOURCE) do
      assertTrue(C.COLOR_FIELDS[field] ~= nil,
        field .. " declares a class source but has no class-color companion")
    end
  end)

-- THE PER-PANEL UNLOCK TICK FOLLOWS THE PANEL'S REAL STATE (review F-008 / PanelMaster-R-08).
--
-- It reads NS.Unlock:IsPanelUnlocked, which is session state no MSG.PANEL describes, so it had no
-- refresher: a global unlock left it unticked-but-meaningless, a global lock left it ticked, and a
-- combat-deferred tick replayed at PLAYER_REGEN_ENABLED left it unticked on an unlocked panel. The
-- unlock module now pokes NS.PanelEditor:RefreshUnlock at the end of every transition.
--
-- red under: dropping the refresher, the RefreshUnlock calls in modules/Unlock.lua, or the
-- SetDisabled while the global unlock is on.
test("Panels page: the per-panel Unlock tick tracks global, per-panel and deferred unlocks",
  function()
  T.mocks.__inCombat = false
  NS.Unlock:SetUnlocked(false)
  NS.Registry:DeleteAll()
  local rec = NS.Registry:New("Unlock tick")
  E.__setSelectedID(rec.id)
  local ctx = freshPanelsCtx()
  local savedCtx = E.__ctx
  E.__ctx = ctx
  local box = assert(actsOnGeneral(ctx).unlocked, "no Unlock tick on the General tab")
  assertFalse(box:GetValue() == true, "a locked panel's tick starts ticked")

  -- (a) The global unlock ticks and grays the box; the global lock puts it back.
  NS.Unlock:SetUnlocked(true)
  assertTrue(box:GetValue() == true, "the tick does not show the global unlock")
  assertTrue(box.disabled == true, "the tick stays live while every panel is already unlocked")
  NS.Unlock:SetUnlocked(false)
  assertFalse(box:GetValue() == true, "the tick survived a global lock")
  assertFalse(box.disabled == true, "the tick stayed grayed after the global lock")

  -- (b) A tick in combat is deferred and reads false; leaving combat replays it and the tick follows.
  T.mocks.__inCombat = true
  box:__fire("OnValueChanged", true)
  assertFalse(box:GetValue() == true, "a deferred unlock claims the panel is unlocked")
  T.mocks.__inCombat = false
  NS.addon:OnRegenEnabled()
  assertTrue(NS.Unlock:IsPanelUnlocked(rec.id), "the deferred unlock was not replayed")
  assertTrue(box:GetValue() == true, "the tick did not follow the replayed unlock")

  NS.Unlock:SetUnlocked(false)
  E.__ctx = savedCtx
  NS.Registry:DeleteAll()
  E.__setSelectedID(nil)
end)
