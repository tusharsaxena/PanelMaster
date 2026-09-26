local _, NS = ...
NS.PanelEditor = NS.PanelEditor or {}
local E = NS.PanelEditor
local C = NS.Constants
local print = NS.Print   -- secret-safe, [PM]-prefixed shared printer (events-frames-taint-§8)

local AceGUI = LibStub and LibStub("AceGUI-3.0", true)

-- ── The Panels subcategory's body ───────────────────────────────────────────────
-- The chrome band's two controls — the panel picker and the create box, one row — and one panel's
-- appearance editor under a six-tab strip. The six page-wide acts live on the editor's own General
-- tab, which is first (options-ui-§14, standard v2.40.0). This is the structural page: its content depends on how many panels exist, so it lives
-- behind `rebuilders` and is repainted only when the SET of panels changes (options-ui-§11) or when
-- a tab is clicked, never on every OnShow.
--
-- It lives in its own file rather than in settings/Panel.lua because the editor is the largest thing
-- on the page by a wide margin and has nothing to do with the page's chrome (layout-§1 permits an
-- oversized file to be peeled into siblings in the same folder). settings/Panel.lua keeps the
-- header, the scroll frame, the tooltip, the schema renderer, the landing page and registration, and
-- drives this file through E:WireBus / E:BuildPage / E:Rebuild.
--
-- What is ON each of the editor's six tabs lives one file further out, in
-- settings/PanelEditorTabs.lua (layout-§1, PanelMaster#47): the tab names, the editor's vertical
-- rhythm and buildPanelEditor. This file keeps the page -- the selection, the mutation actions, the
-- control kit the tabs are drawn with, the strip, the chrome band, the rebuilder and the bus -- and
-- reaches the tabs through one call, buildPanelEditor, plus the strip's two tab tables.

-- ── Helpers shared with settings/Panel.lua ──────────────────────────────────────
-- The editor draws with the PAGE's helpers: the scroll frame it is emitted into, the tooltip
-- attacher, the section heading, the paired-button width and the open-dropdown registry all belong
-- to settings/Panel.lua, and a second copy here would give the two halves two subtly different looks
-- the first time either was edited.
--
-- They are bound on first use rather than captured at load, because the TOC loads THIS file before
-- settings/Panel.lua — the page has to be able to reach the editor by the time it registers, so the
-- editor cannot depend on the page existing yet at load time.
local attachTooltip, ensureScroll
local trackDropdown, forgetDropdowns, safeRun, LSM_WIDGET
local SECTION_HEADING_H

-- The editor tabs' half, published by settings/PanelEditorTabs.lua as E.__editorTabs and bound here
-- the same way, so the two editor files may load in either order. `makePairButton` and
-- `BUTTON_PAIR_REL` are no longer bound here: the only controls that used them are on the tabs.
local EDITOR_TABS, IS_EDITOR_TAB, buildPanelEditor

-- `section`, `addSpacer` and `ROW_VSPACER` are no longer among them. They drew the two untabbed
-- "Create" and "Edit" headings and the gaps around them, and both sections have moved into the
-- page's chrome band (options-ui-§14) where a scroll-anchored heading cannot go. SECTION_HEADING_H
-- arrives in their place, for the in-tab subsection headings (options-ui-§7).
local function bindHelpers()
  local tabs = E.__editorTabs
  if tabs then
    EDITOR_TABS, IS_EDITOR_TAB, buildPanelEditor = tabs.EDITOR_TABS, tabs.IS_EDITOR_TAB,
                                                   tabs.buildPanelEditor
  end
  local ui = NS.Panel and NS.Panel.__ui
  if not ui then return end
  attachTooltip,  ensureScroll                    = ui.attachTooltip, ui.ensureScroll
  trackDropdown,  forgetDropdowns, safeRun        = ui.trackDropdown, ui.forgetDropdowns, ui.safeRun
  LSM_WIDGET                                      = ui.LSM_WIDGET
  SECTION_HEADING_H                               = ui.SECTION_HEADING_H
end

local function runRebuilders(ctx)
  bindHelpers()
  -- Every refresher closure holds a widget this rebuild is about to hand back to AceGUI's pool, so
  -- the list is emptied FIRST and repopulated as each control is built again. A survivor would
  -- re-sync a released widget the next time a field changed — by which point AceGUI has recycled it
  -- into something else entirely.
  for i = #ctx.refreshers, 1, -1 do ctx.refreshers[i] = nil end
  for i, fn in ipairs(ctx.rebuilders) do safeRun(fn, "Panels rebuilder " .. i) end
end

-- The panel currently being edited, as an id. The Panels page shows ONE editor at a time, chosen
-- from a dropdown: a page that stacked every panel's editor grew past a screen at three panels and
-- past a scrollbar's usefulness at ten, and rebuilding all of them on every create/delete is the
-- O(N) teardown options-ui-§11 exists to prevent. nil means "nothing selected yet".
local selectedID

-- Test seams for the selection. It is a file-local, and the whole of the page's scalar-refresh
-- policy is phrased in terms of it ("is this the panel the user is looking at?"), so a test has to
-- be able to read it and to put the page on a chosen panel.
function E.__getSelectedID() return selectedID end
function E.__setSelectedID(id) selectedID = id end

-- The record the page is showing, resolved FRESH, or nil when nothing is selected.
--
-- Every control in the chrome band calls this from inside its own callback rather than closing over
-- a record, and that is the difference between the band and the editor below it. The editor is
-- rebuilt per selection, so a `rec` upvalue is correct there by construction. The band is built once
-- per session: a record captured at build time would be whichever panel happened to be selected the
-- first time the page was shown, and Delete would go on deleting it forever.
local function currentRecord()
  if not selectedID then return nil end
  return NS.Registry:Get(selectedID)
end

-- Forget the selection, so the next rebuild falls back to the first panel by name.
--
-- Called on a profile switch, and only there. Everywhere else a surviving selection is exactly what
-- is wanted — the id is stable across a rename, a field write and a create. A profile switch is the
-- one event that invalidates it, because ids are allocated per profile: the check the rebuilder
-- makes is `NS.Registry:Get(selectedID)`, which after a switch happily resolves to whatever
-- DIFFERENT panel the incoming profile has under that id. So the editor would open on an arbitrary
-- panel rather than on the first, with no way for the user to tell it had been chosen for them.
--
-- Nil rather than "clamp to the first" here: choosing the fallback is the rebuilder's job and it
-- already does it, and duplicating the choice is how the two get to disagree.
function E:ForgetSelection() selectedID = nil end

-- ── The page's mutation actions ─────────────────────────────────────────────────
-- Every control that changes the SET of panels routes through one of these, and every one has the
-- same shape: decide the selection first, mutate, and then do nothing at all.
--
-- Doing nothing is the point. `NS.Registry` broadcasts synchronously from inside the mutating call,
-- and the page's bus subscription rebuilds on that broadcast — so a handler that also called
-- runRebuilders itself rebuilt the page twice, the first time while the widget whose callback was
-- still on the stack had already been released back to AceGUI's pool (F-002). The bus is the single
-- rebuild trigger; the selection is set BEFORE the mutation so that the one rebuild lands on the
-- right panel rather than on a stale or deleted one.
--
-- They are named rather than left inline for a second reason: the headless harness stubs AceGUI out,
-- so a body that lives inside a SetCallback closure is never built and cannot be tested.
local pageAction = {}
E.__pageActions = pageAction

-- Create. The one case where the selection cannot be decided in advance: the id does not exist until
-- R:New has made the record, and R:New has already broadcast by the time it returns. The NAME is
-- known, though, so it is parked on the context and the bus handler resolves it to an id before it
-- rebuilds.
function pageAction.create(ctx, widget, text)
  ctx.pendingSelect = text
  local rec, err = NS.Registry:New(text)
  if not rec then
    ctx.pendingSelect = nil
    print("error: " .. tostring(err))
    return   -- leave the text in place so the user can correct it rather than retype it
  end
  -- Safe after the rebuild: the create box lives above the selector and is not one of the widgets a
  -- rebuild releases.
  widget:SetText("")
end

-- Rename. Structural (the name is how every list and dropdown labels the panel), so it rebuilds —
-- but the id does not change, so the selection needs no help.
function pageAction.rename(widget, rec, text)
  local ok, err = NS.Registry:Rename(rec.id, text)
  if not ok then
    print("error: " .. tostring(err))
    widget:SetText(rec.name)   -- put the rejected edit back rather than leaving a lie on screen
  end
end

function pageAction.delete(rec)
  selectedID = nil   -- cleared BEFORE the mutation: the rebuild must not look for a deleted panel
  NS.Registry:Delete(rec.id)
end

-- Reset and CopyFrom both broadcast MSG.PANEL, not MSG.PANELS: the set of panels is unchanged and
-- only this editor's values are stale, so they refresh in place instead of rebuilding.
function pageAction.reset(rec)
  local ok, err = NS.Registry:Reset(rec.id)
  if not ok then print("error: " .. tostring(err)) end
end

function pageAction.copyFrom(widget, rec, sourceID)
  -- On success the second return is the SOURCE's name, not an error.
  local ok, result = NS.Registry:CopyFrom(rec.id, sourceID)
  widget:SetValue(nil)   -- snap back: nothing is selected, something was done
  if not ok then print("error: " .. tostring(result)); return end
  print(("copied settings from '%s'"):format(tostring(result)))
end

-- ── Editor building blocks ──────────────────────────────────────────────────────
-- The editor emits into a List-layout container as a sequence of full-width ROWS, rather than
-- pouring every widget into one Flow group. A single Flow reflows controls of differing heights into
-- whatever gaps it can find — which is what made the first version look cluttered: a checkbox would
-- ride up beside a slider's label and two unrelated settings would end up sharing a line.
-- Explicit rows mean a row holds exactly what it is meant to and nothing drifts into it.
-- The panels, ordered for a HUMAN reading a dropdown rather than for storage.
--
-- Registry:All() returns the live `db.profile.panels` array in creation order, which is the right
-- order for the file and the wrong one for a list you have to find a name in — after a few panels
-- it is effectively arbitrary. Sorting a COPY is not fussiness: All() hands back the stored table
-- itself, so sorting it in place would silently reorder the user's saved variables, and
-- Registry:FindByName returns a positional index alongside its record.
--
-- Compared case-insensitively so "artwork #2" and "Artwork #2" cannot straddle a run of capitals,
-- and tie-broken on id because table.sort is NOT stable: two panels sharing a name would otherwise
-- be free to swap places between rebuilds and make the list flicker for no reason.
local function panelsByName()
  local sorted = {}
  for i, rec in ipairs(NS.Registry:All()) do sorted[i] = rec end
  table.sort(sorted, function(a, b)
    local na, nb = tostring(a.name or ""):lower(), tostring(b.name or ""):lower()
    if na ~= nb then return na < nb end
    return tostring(a.id) < tostring(b.id)
  end)
  return sorted
end

-- Test seam, matching __getSelectedID above: the ordering is a decision worth asserting, and the
-- dropdown it feeds is built by AceGUI, which the headless harness stubs out.
E.__panelsByName = panelsByName

local function editorRow(parent)
  local row = AceGUI:Create("SimpleGroup")
  row:SetLayout("Flow")
  row:SetFullWidth(true)
  parent:AddChild(row)
  return row
end

local function editorSpacer(parent, height)
  local sp = AceGUI:Create("SimpleGroup")
  sp:SetLayout(nil)
  sp:SetFullWidth(true)
  sp:SetHeight(height)
  parent:AddChild(sp)
end

-- A subsection heading INSIDE one tab (options-ui-§7).
--
-- The same AceGUI `Heading` widget, at the same height and under the same font object, that
-- LibKa0s-Options-1.0's O.Section draws -- one heading widget in the collection, and a colored
-- full-width Label standing in for it is anti-pattern #71. What it cannot do is call O.Section:
-- that function adds to the PAGE's scroll, and the editor emits into its own container so that a
-- rebuild can release the editor without taking the rest of the page with it.
local function editorHeading(parent, text)
  local h = AceGUI:Create("Heading")
  h:SetText(text)
  h:SetFullWidth(true)
  h:SetHeight(SECTION_HEADING_H)
  if h.label and h.label.SetFontObject and _G.GameFontNormalLarge then
    h.label:SetFontObject(_G.GameFontNormalLarge)
  end
  parent:AddChild(h)
  return h
end

-- ── Per-editor scalar refreshers (options-ui-§11) ───────────────────────────────
-- Every control in the editor registers one: a closure that re-reads the LIVE record and pushes the
-- value back into the widget. MSG.PANEL runs them in place, so a drag, a `/pm panel Chat width 400`
-- or a Reset updates the open editor without a teardown — a full rebuild per field write is
-- anti-pattern #39, and would release the very control the user is still holding.
--
-- The record is looked up again rather than closed over: `rec` is the table the editor was built
-- from, and a profile switch replaces the whole panel list with different tables for the same ids.
local function addRefresher(ctx, rec, apply)
  ctx.refreshers[#ctx.refreshers + 1] = function()
    local live = NS.Registry:Get(rec.id)
    if live then apply(live) end
  end
end

-- The span a numeric slider covers for one record: the bounds Constants names, widened when needed
-- to REACH the value the record actually holds.
--
-- A Blizzard slider clamps both its thumb and the value it reports, so a record living outside the
-- nominal span would be silently rewritten to the bound on the first click, drag or mouse-wheel.
-- That matters for x/y, which Registry.Sanitize deliberately leaves unclamped so a multi-monitor
-- layout can carry a large offset (audit decision A-003) — a bound the editor cannot exceed would
-- turn C.EDITOR_OFFSET_RANGE from a reach into the clamp its own comment says it is not. Width and
-- height cannot exceed C.MAX_SIZE, so this is a no-op for them.
--
-- Published on the module rather than kept file-local because AceGUI is stubbed in the headless
-- suite: the widget never exists there, so this arithmetic is the only part a test can see.
function E.SliderSpan(value, minV, maxV)
  local v = tonumber(value) or 0
  return math.min(minV, v), math.max(maxV, v)
end

-- A LibSharedMedia picker for one of a panel's media fields.
local function makeMediaDropdown(ctx, row, rec, field, label, tooltip)
  local mediaType = C.PANEL_FIELD_MEDIA[field]
  local dd = AceGUI:Create(LSM_WIDGET[mediaType] or "Dropdown")
  trackDropdown(ctx, dd)
  dd:SetLabel(label)
  dd:SetRelativeWidth(0.5)

  -- The list is rebuilt at build time rather than captured once at file load: other addons register
  -- media throughout the session, so a list snapshotted early would be missing whatever loaded after
  -- this addon.
  local list, order = {}, {}
  for i, name in ipairs(NS.Compat.MediaList(mediaType)) do
    list[name] = name
    order[i] = name
  end
  dd:SetList(list, order)
  dd:SetValue(rec[field])

  dd:SetCallback("OnValueChanged", function(_, _, value)
    NS.Registry:Set(rec.id, field, value)
    -- The AceGUI-3.0-SharedMediaWidgets widgets fire OnValueChanged from their own click handler
    -- WITHOUT calling SetValue first — upstream assumes AceConfigDialog re-renders the whole panel
    -- afterwards. This is a canvas panel that does not re-render on a value change, so without this
    -- push the widget keeps displaying the old name even though the write landed. Harmlessly
    -- idempotent for the stock Dropdown, which already SetValue'd itself.
    dd:SetValue(value)
  end)
  attachTooltip(dd, label, tooltip)
  row:AddChild(dd)
  addRefresher(ctx, rec, function(live) dd:SetValue(live[field]) end)
  return dd
end

-- A color control plus its "Use class color" companion (options-ui-§17).
--
-- Driven off C.COLOR_FIELDS rather than written out per color, so a color added to the panel
-- record later gets its class-color checkbox for free. That map is why this addon met §17's
-- "immediately to its right" rule before the rule existed; what the adoption changed is the
-- companion's LABEL (the standard names it), the swatch's tooltip (which now carries the
-- collection's own sentence rather than this file's paraphrase of it) and where the color is
-- resolved (LibKa0s-Core-1.0, through Util.ResolveColor).
--
-- WHICH CLASS is declared in C.COLOR_CLASS_SOURCE, not decided here: all five of this addon's
-- colors are panel chrome and take the PLAYER's class. There is no per-color branch in this
-- function because there is no per-color difference to branch on.
--
-- The picker stays ENABLED while the class color is on, and it is now forbidden to be anything
-- else: `disabledIf` on a color row is anti-pattern #74. A color's ALPHA is not overridden — it
-- still decides how solid the result is, and the picker is the only control that sets it — so
-- graying it would tell the player something untrue. The tooltip says so in the collection's words;
-- the label carries no `(opacity)` suffix, like the composed swatches (owner's decision 2026-09-12).
local function makeColorPair(ctx, row, rec, field, label)
  local flag = C.COLOR_FIELDS[field]
  local usingClass = flag and rec[flag] and true or false
  local classCheck   -- the companion checkbox, built below when the field has a class-color flag

  local picker = AceGUI:Create("ColorPicker")
  picker:SetLabel(label)
  picker:SetRelativeWidth(0.5)
  picker:SetHasAlpha(true)
  local col = NS.Util.Color(rec[field])
  picker:SetColor(col[1], col[2], col[3], col[4])

  local function store(_, _, r, g, b, a)
    NS.Registry:Set(rec.id, field, { r, g, b, a })
  end

  -- BOTH callbacks, and this is a correctness fix rather than belt-and-braces.
  --
  -- AceGUI's ColorPicker (v28) only fires OnValueConfirmed from the ALPHA callback, after the
  -- Blizzard picker closes — and its own "no change, skip update" guard returns early when the alpha
  -- callback reports the same values the color callback already applied. So for the overwhelmingly
  -- common case of changing the color WITHOUT touching the opacity slider, OnValueConfirmed never
  -- fires at all: the widget's swatch updated (it calls SetColor on itself first) while the value
  -- was never handed to the addon. That is exactly the shape of "the swatch is green but the panel
  -- is still black".
  --
  -- OnValueChanged fires while the picker is open, so binding it also gives a live preview as the
  -- user drags — which is what a color picker should do anyway.
  picker:SetCallback("OnValueChanged", store)
  picker:SetCallback("OnValueConfirmed", store)
  -- The note is the LIBRARY's string, not a paraphrase: options-ui-§17 fixes what a swatch says
  -- about its companion, and nine addons saying it nine ways is the drift the constant ends.
  attachTooltip(picker, label,
    "Sets the color and its opacity. "
    .. ((NS.Helpers and NS.Helpers.CLASS_COLOR_NOTE) or ""))
  row:AddChild(picker)

  -- SetColor, NEVER SetValue: SetColor updates the swatch without firing a callback, whereas
  -- SetValue would re-enter `store` and turn a refresh into a write — a MSG.PANEL handler writing
  -- back through Registry:Set is a loop, not a repaint.
  addRefresher(ctx, rec, function(live)
    local c = NS.Util.Color(live[field])
    picker:SetColor(c[1], c[2], c[3], c[4])
    if classCheck then classCheck:SetValue(live[flag] and true or false) end
  end)

  if not flag then return end

  local cb = AceGUI:Create("CheckBox")
  classCheck = cb
  -- `Use class color`, verbatim: options-ui-§17 names the control, and it was "Class color" here.
  cb:SetLabel("Use class color")
  cb:SetRelativeWidth(0.5)
  cb:SetValue(usingClass)
  cb:SetCallback("OnValueChanged", function(_, _, v)
    NS.Registry:Set(rec.id, flag, v and true or false)
  end)
  attachTooltip(cb, "Use class color",
    "Use your class color for " .. label:lower() .. ". The opacity from the color picker still "
    .. "applies \226\128\148 a class color at low opacity looks just as washed out as any other.")
  row:AddChild(cb)
end

-- The four edge checkboxes for the accent bar, as one quarter-width row.
--
-- A set of independent booleans rather than a dropdown, because the edges are not exclusive — "top
-- and left" is an ordinary choice, and a dropdown would have to enumerate all fifteen combinations
-- to offer it. Each tick writes the WHOLE set through Registry:Set, so the single write seam still
-- sees one complete value rather than four partial ones.
local function makeEdgeChecks(ctx, row, rec)
  for _, edge in ipairs(C.EDGES) do
    local cb = AceGUI:Create("CheckBox")
    cb:SetLabel(C.EDGE_LABEL[edge])
    cb:SetRelativeWidth(0.25)
    cb:SetValue(NS.Util.EdgeSet(rec.accentEdges)[edge] and true or false)
    cb:SetCallback("OnValueChanged", function(_, _, v)
      local edges = NS.Util.EdgeSet(rec.accentEdges)
      edges[edge] = v and true or nil
      NS.Registry:Set(rec.id, "accentEdges", edges)
    end)
    attachTooltip(cb, C.EDGE_LABEL[edge],
      ("Draw an accent bar along the %s edge."):format(C.EDGE_LABEL[edge]:lower()))
    row:AddChild(cb)
    addRefresher(ctx, rec, function(live)
      cb:SetValue(NS.Util.EdgeSet(live.accentEdges)[edge] and true or false)
    end)
  end
end

-- The control kit, published for settings/PanelEditorTabs.lua, which draws every tab with it. One
-- kit rather than a copy per file, for the reason the Panel.lua helpers are shared: two copies are
-- two looks the first time either is edited.
E.__controls = {
  editorRow         = editorRow,
  editorSpacer      = editorSpacer,
  editorHeading     = editorHeading,
  addRefresher      = addRefresher,
  makeMediaDropdown = makeMediaDropdown,
  makeColorPair     = makeColorPair,
  makeEdgeChecks    = makeEdgeChecks,
}

-- ── The editor's tab strip ──────────────────────────────────────────────────────
-- Drawn straight onto the page's chrome band with H.TabStrip. `ctx.activeTab` is the one piece of
-- state it needs, and buildPanelEditor dispatches on the same field, so the strip and the editor
-- cannot disagree about which tab is showing.
--
-- A click re-runs the page's rebuilders rather than re-rendering the whole page: the create box and
-- the panel picker in the band above are untouched by a tab change, and releasing them to build the
-- same two widgets again would drop whatever the user had typed into the create box.
local function drawTabStrip(ctx)
  if not (NS.Helpers and NS.Helpers.TabStrip) then return end
  if not IS_EDITOR_TAB[ctx.activeTab] then ctx.activeTab = EDITOR_TABS[1] end

  local tabs = {}
  for i, name in ipairs(EDITOR_TABS) do tabs[i] = { key = name, label = name } end

  NS.Helpers.TabStrip(ctx, {
    tabs  = tabs,
    value = ctx.activeTab,
    onSelect = function(key)
      if key == ctx.activeTab then return end
      ctx.activeTab = key
      runRebuilders(ctx)
    end,
  })
end

-- ── The page-wide block, ABOVE the strip (options-ui-§14) ───────────────────────
--
-- ONE ROW: the Panel picker and the Create new panel box, the two controls that stay put on every
-- tab. The panel's other page-wide acts are on the `General` tab; the tab constants in
-- settings/PanelEditorTabs.lua say why.
--
-- ONE chrome block per page, and this is it. H.PageHeader and H.PageBanner release the same ledger
-- and write the same reserved height, so the picker goes INSIDE this block and no banner is drawn
-- separately: two blocks would be two bands, and the second would push the page down for nothing.
--
-- NOT BOXED, either. The band is already separated from the page by its own divider and by the
-- content panel's top edge, and a bounded box would state a boundary the band already states.
--
-- Built ONCE, from BuildPage, and never released by a rebuild. The create box is the reason: a
-- create broadcasts MSG.PANELS from inside R:New, so the rebuild lands while the user's own
-- callback is still on the stack, and releasing the box would hand the widget they are typing into
-- back to AceGUI's pool. The picker is refreshed in place instead, through ctx.__pmPicker.
local function drawPageHeader(ctx)
  local H = NS.Helpers
  if not (H and H.PageHeader) then return end

  H.PageHeader(ctx, {
    -- ONE ROW of LABELED controls, at the library's own floor for exactly that -- which is what
    -- H.BANNER_H is, and it is read rather than restated (options-ui-§8).
    --
    -- It was three rows until v2.40.0 of the standard bounded the band at one and let the acts move
    -- to the `General` tab. Reserving the old height now would leave a hole of precisely the size
    -- the acts used to fill, which is the argument this file already makes for not hiding controls
    -- when there is no panel -- running the other way.
    height = H.BANNER_H,
    build = function(_, frame)
      local block = AceGUI:Create("SimpleGroup")
      if not (block and block.frame) then return end
      block:SetLayout("List")
      block.frame:SetParent(frame)
      block.frame:ClearAllPoints()
      block.frame:SetPoint("TOPLEFT",     frame, "TOPLEFT",     0, 0)
      block.frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
      -- SHOWN HERE, BECAUSE NOTHING ELSE SHOWS IT. AceGUI pools widgets: Release hides the frame,
      -- and a later Create of the same type hands it back hidden -- only a parent container's
      -- layout shows a child. This block is parented by hand and is no container's child, so once
      -- any addon had released a SimpleGroup in the session, the band kept its height and divider
      -- and lost the picker and the create box inside it.
      block.frame:Show()

      local makeRow = editorRow(block)

      -- The picker carries a LABEL. It did not when it lived under an "Edit" section heading that
      -- said what it was for; in the band there is no heading above it, and an unlabeled dropdown
      -- beside a labeled edit box reads as a control that lost its caption.
      local picker = AceGUI:Create("Dropdown")
      picker:SetLabel("Panel")
      picker:SetRelativeWidth(0.5)
      picker:SetCallback("OnValueChanged", function(_, _, id)
        selectedID = id
        runRebuilders(ctx)
      end)
      attachTooltip(picker, "Panel",
        "Which panel the tabs below are editing. A disabled panel is marked in the list, so it is "
        .. "obvious why editing it changes nothing on screen.")
      makeRow:AddChild(picker)
      -- The EditBox's own "Okay" button is the confirm, matching the rename box beside it — one
      -- confirmation gesture for both places you type a panel name, and now on adjacent rows where
      -- that pairing is visible rather than argued for in a comment.
      --
      -- Safe because AceGUI's EditBox does NOT commit on focus loss: `OnEnterPressed` is fired only
      -- by the Enter key, the Okay button and a drag-receive. `OnEditFocusLost` is not even
      -- registered. (An earlier version disabled the button and added a separate Create button on
      -- the mistaken assumption that tabbing away would create a panel.)
      local newBox = AceGUI:Create("EditBox")
      -- "Create new panel", not "New panel name". The band holds three controls that name a panel,
      -- and the reader's question at this one is which of them MAKES a panel — a label naming the
      -- field's contents answered a question nobody had.
      newBox:SetLabel("Create new panel")
      newBox:SetRelativeWidth(0.5)
      newBox:SetCallback("OnEnterPressed", function(widget, _, text)
        pageAction.create(ctx, widget, text)
      end)
      attachTooltip(newBox, "Create new panel",
        "Type a name and press Enter, or click Okay, to create the panel.")
      makeRow:AddChild(newBox)


      local builtWidth = frame.GetWidth and frame:GetWidth()
      if type(builtWidth) == "number" and builtWidth > 0 then
        block.__pmLaidOutAt = builtWidth
        block:SetWidth(builtWidth)
      end
      if block.DoLayout then block:DoLayout() end
      ctx.__pmPicker = picker
      -- The picker is the only band control left to park. The six acts moved to the `General`
      -- tab (options-ui-§14, v2.40.0): three band rows for controls touched once a session was
      -- a second page above the page, and the tab the editor OPENS on is not a tab anything is
      -- hidden behind. They are rebuilt with the editor now, so nothing has to re-point them.
      -- Parked for the same reason the picker is: the block has to be reachable to be re-laid out
      -- below, and for a case to assert that it was.
      ctx.__pmHeaderBlock = block

      -- THE ROW IS LAID OUT AT THE BAND'S WIDTH, WHICH ONLY SetWidth CAN TELL IT. AceGUI's List
      -- layout reads `content.width` before it asks the frame, and a SimpleGroup's OnAcquire sets
      -- that to 300. Anchoring the block to both sides of the header stretches the frame and
      -- leaves `content.width` alone, so a bare DoLayout lays the row out at 300 pixels, and each
      -- half-width control gets 150, whatever the band's real width is. SetWidth writes the width
      -- the layout reads; the two anchors still decide the frame's size.
      --
      -- The width arrives late on the first page a player opens, which is rendered before the
      -- settings canvas has laid itself out, so the build above passes it on only when the header
      -- already has one, and this hook passes on every later one. The block is built ONCE for the
      -- session (settings/Panel.lua's `built` flag, which exists so a rebuild cannot pool the
      -- widget the user is typing into), so this hook is its only way to learn a new width.
      --
      -- (An earlier version of this comment blamed a layout run at zero width for a band that
      -- showed its height and divider with nothing inside. That was never the mechanism: the List
      -- layout never saw zero, because of the 300 above. The band was hidden, and the Show above is
      -- the fix.)
      --
      -- Hooked on the HEADER FRAME rather than on ctx.chrome, whose OnSizeChanged the library has
      -- already claimed for the strip -- SetScript replaces, so hooking there would trade this for
      -- a strip that never re-wraps. The header frame is anchored to both of the chrome's sides, so
      -- its width is the chrome's width.
      --
      -- Guarded on a CHANGE in width, like the library's: SetChromeHeight fires this same script,
      -- and a layout that answered every event would run on every height change for nothing.
      frame:SetScript("OnSizeChanged", function(_, width)
        if type(width) ~= "number" or width <= 0 then return end
        if block.__pmLaidOutAt == width then return end
        block.__pmLaidOutAt = width
        block:SetWidth(width)
        if block.DoLayout then block:DoLayout() end
      end)
    end,
  })
end

-- Re-point the picker at the current panel list, without releasing it.
--
-- Re-registered for scroll-close on every rebuild because `forgetDropdowns` empties that registry
-- at the top of one: the widget survives the rebuild, so it has to be put back rather than left out
-- of a list every other dropdown on the page rejoins.
local function refreshPicker(ctx, records)
  local picker = ctx.__pmPicker
  if not picker then return end
  trackDropdown(ctx, picker)

  local list, order = {}, {}
  for i, rec in ipairs(records) do
    -- A disabled panel is marked in the list, so it is obvious why editing it changes nothing
    -- on screen.
    list[rec.id] = rec.enabled and rec.name or (rec.name .. " |cff808080(disabled)|r")
    order[i] = rec.id
  end
  picker:SetList(list, order)
  picker:SetValue(selectedID)
  -- Nothing to pick from is a disabled control rather than an absent one: a picker that vanished
  -- with the last panel would take its label with it and leave a hole in the band.
  picker:SetDisabled(#records == 0)
end



local function buildPanelsPage(ctx)
  bindHelpers()
  local scroll = ensureScroll(ctx)

  drawPageHeader(ctx)

  -- Everything a rebuild repaints lives in here, so a rebuild releases exactly the editor and
  -- nothing in the band above it.
  local listGroup = AceGUI:Create("SimpleGroup")
  listGroup:SetLayout("List"); listGroup:SetFullWidth(true)
  scroll:AddChild(listGroup)

  ctx.rebuilders[#ctx.rebuilders + 1] = function()
    -- The widgets about to be released include every dropdown registered for scroll-close, so the
    -- registry is emptied before the new ones re-register.
    forgetDropdowns(ctx)
    listGroup:ReleaseChildren()

    -- THE STRIP IS DRAWN FIRST, AND ALWAYS (options-ui-§13).
    --
    -- It used to be RELEASED when there were no panels, on the argument that a strip over nothing
    -- is chrome for its own sake. That is the conditional no-strip state the rule forbids: a page
    -- that loses its strip is the page that looks broken, and the empty state belongs INSIDE the
    -- page rather than in place of it. `releaseTabStrip` went with the branch — it existed only to
    -- serve it, and with the create box and the picker now in the chrome band, giving the band back
    -- would have taken them off the screen as well.
    --
    -- Redrawn on every rebuild rather than once at BuildPage: H.TabStrip owns its own ledger and
    -- drains it, and the ACTIVE tab is drawn as a disabled button, so the highlight can only move
    -- by rebuilding the buttons. A rebuild is also exactly when the band's height can change (a
    -- strip that wrapped to two rows on a narrow panel).
    drawTabStrip(ctx)

    local records = panelsByName()

    -- Keep the selection if it still exists, otherwise fall back to the first panel. A deleted
    -- selection must not leave the page blank with a picker pointing at nothing.
    if not (selectedID and NS.Registry:Get(selectedID)) then
      selectedID = records[1] and records[1].id or nil
    end
    local rec = currentRecord()
    refreshPicker(ctx, records)

    if not rec then
      -- The empty state is CONTENT, under the same strip every other state draws.
      local empty = AceGUI:Create("Label")
      empty:SetFullWidth(true)
      empty:SetText("No panels yet. Type a name in the box above and press Enter to make one.")
      listGroup:AddChild(empty)
    else
      -- No heading naming the panel: the picker in the band above already shows which one is
      -- selected, and a heading repeating it was a third line of chrome between choosing a panel
      -- and editing it.
      buildPanelEditor(ctx, listGroup, rec)
    end

    if ctx.scroll and ctx.scroll.DoLayout then ctx.scroll:DoLayout() end
  end
end

-- The Panels page's whole repaint policy, and its only two triggers (options-ui-§11).
--
--   MSG.PANELS is STRUCTURAL — a panel was created, deleted or renamed, so the selector's contents
--   and the editor's identity both change. One rebuild.
--   MSG.PANEL is SCALAR — one field of one panel changed, from the CLI, a drag, Reset or CopyFrom.
--   The open editor re-syncs in place and nothing is released. Rebuilding here instead would be a
--   full AceGUI teardown per field write (anti-pattern #39) and would take the control out from
--   under a user mid-drag, which is precisely why it is not done.
--
-- Both are scoped to the on-screen page: an off-screen page is only flagged dirty, so a `/pm new`
-- with the options window closed costs nothing and is picked up by the next OnShow.
--
-- THAT SCOPING IS THE LIBRARY'S, not this file's, and it is why both handlers are one call to
-- O.RefreshPanel. This file used to hand-roll the branch — `if ctx.panel:IsShown() then rebuild else
-- ctx.dirty = true end` — and the flag was WRONG: the gate in LibKa0s's SetRenderer OnShow reads
-- `ctx._dirty`, with the underscore, so `ctx.dirty` was written in four places and read in none. The
-- deferral silently never happened. A profile switch fires MSG.PANELS from Registry:ReloadProfile
-- while this page is hidden (the user is on the Profiles page to make the switch), so the page kept
-- the widget tree it had built for the OLD profile: its panel dropdown, its copy-from list and its
-- editor still showed panels that were no longer in the registry, while Canvas — which is not a
-- settings page and never consulted the flag — had correctly cleared the screen.
--
-- The fix is not a corrected flag name. A private field the host has to guess is the defect; the
-- library now publishes O.RefreshPanel(ctx, structural), which owns the shown/hidden decision, the
-- flag and both tiers. Nothing here writes `_dirty`, and there is no second copy of the rule to get
-- out of step. Needs LibKa0s Options minor >= 8.
--
-- Wired at REGISTRATION rather than from the page build, because the build is lazy: a page that has
-- never been shown would otherwise miss every change made before its first OnShow.
local function wirePanelsBus(ctx)
  E.__ctx = ctx
  if E.__evPanels then return end
  local ev = NS.NewBusTarget()
  if not ev then return end

  ev:RegisterMessage(NS.Registry.MSG.PANELS, function()
    -- A create hands its selection over by NAME, because the id did not exist when the mutation
    -- started and this message arrives from inside R:New (see pageAction.create).
    if ctx.pendingSelect then
      local rec = NS.Registry:FindByName(ctx.pendingSelect)
      ctx.pendingSelect = nil
      if rec then selectedID = rec.id end
    end
    NS.Helpers.RefreshPanel(ctx, true)
  end)

  ev:RegisterMessage(NS.Registry.MSG.PANEL, function(_, id)
    if id ~= selectedID then return end   -- some other panel changed; this editor is not showing it
    NS.Helpers.RefreshPanel(ctx, false)
  end)

  E.__evPanels = ev
end

-- ── The three things settings/Panel.lua drives this file with ───────────────────
-- Subscribe the page's context to the panel bus. Called from P:Register, not from the build, so a
-- page that has never been shown still tracks changes made while it was hidden.
function E:WireBus(ctx) wirePanelsBus(ctx) end

-- Re-read the Unlock tick after an unlock transition (modules/Unlock.lua); scalar tier, no new message.
function E:RefreshUnlock()
  local ctx = E.__ctx
  if ctx and NS.Helpers and NS.Helpers.RefreshPanel then NS.Helpers.RefreshPanel(ctx, false) end
end

-- Emit the page's static furniture (the create box, the two section headings, the selector's
-- container) and install the rebuilder that draws the tab strip and the editor itself. First OnShow
-- only: the strip and the editor belong to the rebuilder, because both change with the panel list
-- and with the selected tab, while Create and Edit never do.
function E:BuildPage(ctx) buildPanelsPage(ctx) end

-- Repaint the selector and the open editor. The one structural entry point: first paint, a page that
-- went dirty while hidden, and every MSG.PANELS.
function E:Rebuild(ctx) runRebuilders(ctx) end
