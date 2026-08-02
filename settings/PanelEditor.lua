local addonName, NS = ...   -- luacheck: ignore addonName
NS.PanelEditor = NS.PanelEditor or {}
local E = NS.PanelEditor
local C = NS.Constants
local print = NS.Print   -- secret-safe, [PM]-prefixed shared printer (events-frames-taint-§8)

local AceGUI = LibStub and LibStub("AceGUI-3.0", true)

-- ── The Panels subcategory's body ───────────────────────────────────────────────
-- One editor block per panel, plus the create control. This is the structural page: its content
-- depends on how many panels exist, so it lives behind `rebuilders` and is repainted only when the
-- SET of panels changes (options-ui-§11), never on every OnShow.
--
-- It lives in its own file rather than in settings/Panel.lua because the editor is the largest thing
-- on the page by a wide margin and has nothing to do with the page's chrome (layout-§1 permits an
-- oversized file to be peeled into siblings in the same folder). settings/Panel.lua keeps the
-- header, the scroll frame, the tooltip, the schema renderer, the landing page and registration, and
-- drives this file through E:WireBus / E:BuildPage / E:Rebuild.

-- ── Helpers shared with settings/Panel.lua ──────────────────────────────────────
-- The editor draws with the PAGE's helpers: the scroll frame it is emitted into, the tooltip
-- attacher, the section heading, the paired-button width and the open-dropdown registry all belong
-- to settings/Panel.lua, and a second copy here would give the two halves two subtly different looks
-- the first time either was edited.
--
-- They are bound on first use rather than captured at load, because the TOC loads THIS file before
-- settings/Panel.lua — the page has to be able to reach the editor by the time it registers, so the
-- editor cannot depend on the page existing yet at load time.
local attachTooltip, addSpacer, section, ensureScroll, makePairButton
local trackDropdown, forgetDropdowns, safeRun, LSM_WIDGET, ROW_VSPACER

local function bindHelpers()
  local ui = NS.Panel and NS.Panel.__ui
  if not ui then return end
  attachTooltip,  addSpacer,       section     = ui.attachTooltip, ui.addSpacer, ui.section
  ensureScroll,   makePairButton               = ui.ensureScroll, ui.makePairButton
  trackDropdown,  forgetDropdowns, safeRun     = ui.trackDropdown, ui.forgetDropdowns, ui.safeRun
  LSM_WIDGET,     ROW_VSPACER                  = ui.LSM_WIDGET, ui.ROW_VSPACER
end

local function runRebuilders(ctx)
  bindHelpers()
  -- Every refresher closure holds a widget this rebuild is about to hand back to AceGUI's pool, so
  -- the list is emptied FIRST and repopulated as each control is built again. A survivor would
  -- re-sync a released widget the next time a field changed — by which point AceGUI has recycled it
  -- into something else entirely.
  for i = #ctx.refreshers, 1, -1 do ctx.refreshers[i] = nil end
  for i, fn in ipairs(ctx.rebuilders) do safeRun(fn, "Panels rebuilder " .. i) end
  ctx.dirty = false
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

-- Reset and CopyFrom both broadcast MSG_PANEL, not MSG_PANELS: the set of panels is unchanged and
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

-- ── Editor layout constants ─────────────────────────────────────────────────────
-- Vertical rhythm inside the panel editor. Named, never inlined (options-ui-§8), and deliberately
-- three distinct sizes so the spacing itself communicates structure: a big gap means "new part of
-- the page", a medium one "new group of settings", a small one "still the same thought".
local EDITOR_SELECT_GAP  = 20   -- panel dropdown → the editor box
local EDITOR_SECTION_GAP = 14   -- between subsections inside the editor
local EDITOR_ROW_GAP     = 6    -- between rows within one subsection
-- The height an AceGUI control's label row occupies (a labeled Dropdown is 40 tall, an unlabeled
-- one 26). A section heading is followed by a fixed gap, so a control with NO label starts 14px
-- higher than a labeled one and the heading above it looks tighter than every other heading on the
-- page. Adding this back before an unlabeled control makes the gaps read as equal.
local LABEL_ROW_H        = 14

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

-- A subsection heading inside the editor: the same divider-flanked Heading the page-level sections
-- use, at the DEFAULT font rather than the larger one, so it reads as a level below them.
local function editorHeading(parent, text)
  editorSpacer(parent, EDITOR_SECTION_GAP)
  local h = AceGUI:Create("Heading")
  h:SetText(text)
  h:SetFullWidth(true)
  parent:AddChild(h)
  editorSpacer(parent, EDITOR_ROW_GAP)
end

-- ── Per-editor scalar refreshers (options-ui-§11) ───────────────────────────────
-- Every control in the editor registers one: a closure that re-reads the LIVE record and pushes the
-- value back into the widget. MSG_PANEL runs them in place, so a drag, a `/pm panel Chat width 400`
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

-- A color control plus its "use class color" companion.
--
-- Driven off C.COLOR_FIELDS rather than written out per color, so a color added to the panel
-- record later gets its class-color checkbox for free.
--
-- The picker stays ENABLED while the class color is on, and this is a deliberate reversal. It used
-- to be grayed out on the reasoning that its RGB was being overridden — but a color's ALPHA is not
-- overridden, it still decides how solid the result is, and the picker is the only control that sets
-- it. Disabling it therefore contradicted its own tooltip ("the opacity you picked still applies")
-- and left the user unable to fix a washed-out class-colored border at all. The label says which
-- half is live instead.
local function makeColorPair(ctx, row, rec, field, label)
  local flag = C.COLOR_FIELDS[field]
  local usingClass = flag and rec[flag] and true or false
  local classCheck   -- the companion checkbox, built below when the field has a class-color flag

  -- What the control actually governs right now: everything, or only the opacity.
  local function labelFor(classOn)
    if classOn then return label .. " |cff808080(opacity)|r" end
    return label
  end

  local picker = AceGUI:Create("ColorPicker")
  picker:SetLabel(labelFor(usingClass))
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
  attachTooltip(picker, label,
    "Sets the color and its opacity. With Class color ticked the color part is overridden, "
    .. "but the opacity you set here still decides how solid the result is.")
  row:AddChild(picker)

  -- SetColor, NEVER SetValue: SetColor updates the swatch without firing a callback, whereas
  -- SetValue would re-enter `store` and turn a refresh into a write — a MSG_PANEL handler writing
  -- back through Registry:Set is a loop, not a repaint.
  addRefresher(ctx, rec, function(live)
    local c = NS.Util.Color(live[field])
    picker:SetColor(c[1], c[2], c[3], c[4])
    local classOn = flag and live[flag] and true or false
    picker:SetLabel(labelFor(classOn))
    if classCheck then classCheck:SetValue(classOn) end
  end)

  if not flag then return end

  local cb = AceGUI:Create("CheckBox")
  classCheck = cb
  cb:SetLabel("Class color")
  cb:SetRelativeWidth(0.5)
  cb:SetValue(usingClass)
  cb:SetCallback("OnValueChanged", function(_, _, v)
    NS.Registry:Set(rec.id, flag, v and true or false)
    picker:SetLabel(labelFor(v and true or false))
  end)
  attachTooltip(cb, "Class color",
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

-- One panel's editor: a single group holding the panel's geometry, layer, color and visibility
-- fields. Every control writes through NS.Registry:Set, which is the same seam the CLI and the drag
-- handler use.
local function buildPanelEditor(ctx, parent, rec)
  local group = AceGUI:Create("InlineGroup")
  -- No title: the panel's name is rendered above this box as a full section heading (editorTitle),
  -- so repeating it here as the group's small left-aligned caption would say the same thing twice.
  group:SetTitle("")
  group:SetFullWidth(true)
  group:SetLayout("List")

  editorSpacer(group, EDITOR_ROW_GAP)

  local function numberField(row, label, field, minV, maxV, step, tooltip)
    local s = AceGUI:Create("Slider")
    s:SetLabel(label)
    s:SetRelativeWidth(0.5)
    -- Bounds and value are set together, every time, because the span depends on the value: see
    -- E.SliderSpan. Re-run on refresh too, or a drag that pushes x past the nominal reach would
    -- leave the slider unable to show where the panel actually is.
    local function apply(live)
      local v = tonumber(live[field]) or 0
      local lo, hi = E.SliderSpan(v, minV, maxV)
      s:SetSliderValues(lo, hi, step or 1)
      s:SetValue(v)
    end
    apply(rec)
    s:SetCallback("OnMouseUp", function(_, _, v) NS.Registry:Set(rec.id, field, v) end)
    if tooltip then attachTooltip(s, label, tooltip) end
    row:AddChild(s)
    addRefresher(ctx, rec, apply)
    return s
  end

  local function tokenDropdown(row, label, field, tokens, tooltip)
    local dd = AceGUI:Create("Dropdown")
    trackDropdown(ctx, dd)
    dd:SetLabel(label)
    dd:SetRelativeWidth(0.5)
    local list, order = {}, {}
    for i, token in ipairs(tokens) do list[token] = token; order[i] = token end
    dd:SetList(list, order)
    dd:SetValue(rec[field])
    dd:SetCallback("OnValueChanged", function(_, _, key) NS.Registry:Set(rec.id, field, key) end)
    if tooltip then attachTooltip(dd, label, tooltip) end
    row:AddChild(dd)
    addRefresher(ctx, rec, function(live) dd:SetValue(live[field]) end)
    return dd
  end

  -- A dropdown over a {value=, label=} option list — the shape C.STRATA_OPTIONS and the four
  -- C.ART_*_OPTIONS already come in.
  --
  -- Kept separate from tokenDropdown rather than folded into it, because the two answer different
  -- questions. A token dropdown SHOWS the stored token, which is right for anchor points and strata:
  -- those tokens are also what you type at the CLI, so displaying them teaches the CLI. An artwork
  -- enum stores "FIT" and has to read "Fit (contain)" — nobody should have to know the token to pick
  -- a fill mode.
  -- `width` is a relative width, defaulting to the half-row every other control uses. Only the
  -- artwork picker asks for a full row, and it needs one: its labels carry the whole derived
  -- category ("Faction -> Expansion -> 12 Midnight: Harati") and truncate to nothing at half width.
  local function optionDropdown(row, label, field, options, tooltip, width)
    local dd = AceGUI:Create("Dropdown")
    trackDropdown(ctx, dd)
    dd:SetLabel(label)
    dd:SetRelativeWidth(width or 0.5)
    local list, order = {}, {}
    for i, opt in ipairs(options) do list[opt.value] = opt.label; order[i] = opt.value end
    dd:SetList(list, order)
    dd:SetValue(rec[field])
    dd:SetCallback("OnValueChanged", function(_, _, key) NS.Registry:Set(rec.id, field, key) end)
    if tooltip then attachTooltip(dd, label, tooltip) end
    row:AddChild(dd)
    addRefresher(ctx, rec, function(live) dd:SetValue(live[field]) end)
    return dd
  end

  -- A boolean switch on the record. Same two halves as everything else here: the write goes through
  -- Registry:Set, and the refresher reads the live record back.
  local function boolField(row, label, field, tooltip)
    local cb = AceGUI:Create("CheckBox")
    cb:SetLabel(label)
    cb:SetRelativeWidth(0.5)
    cb:SetValue(rec[field] and true or false)
    cb:SetCallback("OnValueChanged", function(_, _, v)
      NS.Registry:Set(rec.id, field, v and true or false)
    end)
    attachTooltip(cb, label, tooltip)
    row:AddChild(cb)
    addRefresher(ctx, rec, function(live) cb:SetValue(live[field] and true or false) end)
    return cb
  end

  -- ── General ──
  -- Identity first, then the switches, then the two whole-panel actions. Reading order matches
  -- decision order: which panel is this, is it on, and am I done with it.
  editorHeading(group, "General")

  local nameRow = editorRow(group)

  local nameBox = AceGUI:Create("EditBox")
  nameBox:SetLabel("Panel name")
  nameBox:SetRelativeWidth(0.5)
  nameBox:SetText(rec.name)
  -- Renaming changes the frame name and the selector entry, so it is structural: MSG_PANELS rebuilds
  -- the page once, and this box is one of the widgets that rebuild releases. Nothing below the call
  -- may touch `widget` on the success path.
  --
  -- No refresher either — the box is the one control the user may be mid-edit in, and a MSG_PANEL
  -- arriving while they type would overwrite what they had typed.
  nameBox:SetCallback("OnEnterPressed", function(widget, _, text)
    pageAction.rename(widget, rec, text)
  end)
  -- The frame name lives in the TOOLTIP rather than as a second label beside the box. It is
  -- reference information you need once, when wiring something else up to this panel — not
  -- something worth a permanent line of chrome in the editor.
  attachTooltip(nameBox, "Panel name",
    ("Frame name: |cffffff00%s|r\n\nOther addons and WeakAuras can anchor to this frame by name. "
     .. "Renaming the panel changes it, so anything anchored to the old name will need updating.")
      :format(NS.Registry.FrameName(rec)))
  nameRow:AddChild(nameBox)

  -- Copy every appearance setting from another panel. Position is deliberately not copied — see
  -- Registry.CopyFrom — so the panel takes on the other's look without moving on top of it.
  local others, order = {}, {}
  for _, other in ipairs(panelsByName()) do
    if other.id ~= rec.id then
      others[other.id] = other.name
      order[#order + 1] = other.id
    end
  end

  local copyFrom = AceGUI:Create("Dropdown")
  trackDropdown(ctx, copyFrom)
  copyFrom:SetLabel("Copy settings from panel")
  copyFrom:SetRelativeWidth(0.5)
  copyFrom:SetList(others, order)
  -- Deliberately valueless: this is an ACTION, not a stored setting. Showing a "current" entry would
  -- imply an ongoing link between the two panels, when the copy is a one-off.
  copyFrom:SetValue(nil)
  if #order == 0 then
    copyFrom:SetDisabled(true)
  end
  -- Every control in this editor now holds a stale value — but CopyFrom broadcasts MSG_PANEL, and
  -- the page answers that with an in-place refresh, so no widget is released and this callback can
  -- go on to reset its own dropdown afterwards.
  copyFrom:SetCallback("OnValueChanged", function(widget, _, sourceID)
    pageAction.copyFrom(widget, rec, sourceID)
  end)
  attachTooltip(copyFrom, "Copy settings from panel",
    #order == 0
      and "Make another panel first, then you can copy its settings onto this one."
      or ("Take on another panel's appearance \226\128\148 size, textures, colors, border and "
          .. "accent bar. Its POSITION is not copied, so this panel stays where it is."))
  nameRow:AddChild(copyFrom)

  editorSpacer(group, EDITOR_ROW_GAP)
  local switches = editorRow(group)

  local enabled = AceGUI:Create("CheckBox")
  enabled:SetLabel("Enabled")
  enabled:SetRelativeWidth(0.5)
  enabled:SetValue(rec.enabled ~= false)
  enabled:SetCallback("OnValueChanged", function(_, _, v)
    NS.Registry:Set(rec.id, "enabled", v and true or false)
  end)
  attachTooltip(enabled, "Enabled", "Draw this panel. Unticking hides it without deleting it.")
  switches:AddChild(enabled)
  -- `~= false`, not truthiness: a record that predates the field is enabled, which is what the
  -- initial SetValue above says too.
  addRefresher(ctx, rec, function(live) enabled:SetValue(live.enabled ~= false) end)

  -- Per-panel unlock, alongside Enabled. The global unlock is all-or-nothing; this one puts a drag
  -- handle on just the panel being edited, which is what you want with a dozen of them on screen.
  local unlocked = AceGUI:Create("CheckBox")
  unlocked:SetLabel("Unlock")
  unlocked:SetRelativeWidth(0.5)
  unlocked:SetValue(NS.Unlock:IsPanelUnlocked(rec.id))
  unlocked:SetCallback("OnValueChanged", function(widget, _, v)
    local result = NS.Unlock:SetPanelUnlocked(rec.id, v and true or false)
    -- nil means the unlock was deferred to the end of combat, so the box goes back to unticked
    -- rather than claiming a state the panel is not in.
    if result == nil then widget:SetValue(false) end
  end)
  attachTooltip(unlocked, "Unlock",
    "Give just this panel a drag handle and a name label, so it can be moved. "
    .. "Session-only \226\128\148 always locked again after a reload.")
  switches:AddChild(unlocked)
  -- No refresher: per-panel unlock is session state (NS.State.unlockedPanels), not a record field,
  -- so no MSG_PANEL ever describes it.

  editorSpacer(group, EDITOR_ROW_GAP)
  local actions = editorRow(group)

  local resetBtn = makePairButton("Reset", function() pageAction.reset(rec) end)
  attachTooltip(resetBtn, "Reset",
    "Put this panel back to how a new one starts \226\128\148 size, position, textures, colors and "
    .. "all. Its name is kept, so anything anchored to it stays anchored.")
  actions:AddChild(resetBtn)

  local deleteBtn = makePairButton("Delete", function() pageAction.delete(rec) end)
  attachTooltip(deleteBtn, "Delete", "Remove this panel. This cannot be undone.")
  actions:AddChild(deleteBtn)

  -- ── Position and size ──
  editorHeading(group, "Position and size")

  local sizeRow = editorRow(group)
  numberField(sizeRow, "Width", "width", C.MIN_SIZE, C.MAX_SIZE)
  numberField(sizeRow, "Height", "height", C.MIN_SIZE, C.MAX_SIZE)

  editorSpacer(group, EDITOR_ROW_GAP)
  local offsetRow = editorRow(group)
  numberField(offsetRow, "X offset", "x", -C.EDITOR_OFFSET_RANGE, C.EDITOR_OFFSET_RANGE)
  numberField(offsetRow, "Y offset", "y", -C.EDITOR_OFFSET_RANGE, C.EDITOR_OFFSET_RANGE)

  editorSpacer(group, EDITOR_ROW_GAP)
  local anchorRow = editorRow(group)
  tokenDropdown(anchorRow, "Anchor", "point", C.POINTS,
    "Which corner or edge of the screen the offsets are measured from.")
  tokenDropdown(anchorRow, "Frame strata", "strata", C.STRATA,
    "Which layer the panel sits in. LOW keeps it under essentially all interface frames, which is "
    .. "what a backdrop usually wants. DIALOG and above will cover normal UI.")

  -- ── Background ──
  editorHeading(group, "Background")

  local bgRow = editorRow(group)
  makeMediaDropdown(ctx, bgRow, rec, "bgTexture", "Background texture",
    "The texture the panel is filled with. 'Solid' is a flat color; 'None' draws no fill.")

  editorSpacer(group, EDITOR_ROW_GAP)
  local bgColorRow = editorRow(group)
  -- The fill's own opacity lives in this color's alpha. Panel opacity (under Visibility) is a
  -- separate, panel-wide multiplier — see the note there.
  makeColorPair(ctx, bgColorRow, rec, "bgColor", "Background color")

  -- ── Border ──
  editorHeading(group, "Border")

  local borderRow = editorRow(group)
  makeMediaDropdown(ctx, borderRow, rec, "borderTexture", "Border texture",
    "The edge style drawn around the panel. 'Solid' is a plain outline; 'None' removes it.")
  numberField(borderRow, "Border size", "borderSize", C.MIN_BORDER, C.MAX_BORDER, 1,
    "Border thickness. 0 removes the border entirely.")

  editorSpacer(group, EDITOR_ROW_GAP)
  local borderOffsetRow = editorRow(group)
  numberField(borderOffsetRow, "Border offset", "borderOffset",
    C.MIN_BORDER_OFFSET, C.MAX_BORDER_OFFSET, 1,
    "How far the border sits from the panel's edge. Positive pushes it outward, "
    .. "negative pulls it inward.")

  editorSpacer(group, EDITOR_ROW_GAP)
  local borderColorRow = editorRow(group)
  makeColorPair(ctx, borderColorRow, rec, "borderColor", "Border color")

  -- ── Accent bar ──
  editorHeading(group, "Accent bar")

  local accentRow = editorRow(group)
  boolField(accentRow, "Enable accent bar", "accentEnabled",
    "Draw a thin colored strip along the panel's edges, in the style of BenikUI's panels. "
    .. "Off by default.")

  makeMediaDropdown(ctx, accentRow, rec, "accentTexture", "Accent bar texture",
    "The texture the accent bar is drawn with, from your LibSharedMedia status-bar textures. "
    .. "'Solid' is a flat color.")

  editorSpacer(group, EDITOR_ROW_GAP)
  local edgeLabel = AceGUI:Create("Label")
  edgeLabel:SetFullWidth(true)
  edgeLabel:SetText("|cffffd100Edges|r")
  group:AddChild(edgeLabel)
  local edgeRow = editorRow(group)
  makeEdgeChecks(ctx, edgeRow, rec)

  editorSpacer(group, EDITOR_ROW_GAP)
  local accentSizeRow = editorRow(group)
  numberField(accentSizeRow, "Accent bar thickness", "accentThickness",
    C.MIN_ACCENT_THICKNESS, C.MAX_ACCENT_THICKNESS, 1,
    "How thick the accent bar is, in screen units.")
  numberField(accentSizeRow, "Accent bar offset", "accentOffset",
    C.MIN_ACCENT_OFFSET, C.MAX_ACCENT_OFFSET, 1,
    "How far the bar sits from the panel's edge. Positive detaches it from the panel, "
    .. "which is the look this is modeled on; 0 sits flush; negative overlaps the panel.")

  editorSpacer(group, EDITOR_ROW_GAP)
  local accentColorRow = editorRow(group)
  makeColorPair(ctx, accentColorRow, rec, "accentColor", "Accent bar color")

  -- The bar's own border. Same four controls as the panel's, in the same order, so the two read
  -- alike — the only difference is what they outline.
  editorSpacer(group, EDITOR_ROW_GAP)
  local accentBorderRow = editorRow(group)
  makeMediaDropdown(ctx, accentBorderRow, rec, "accentBorderTexture", "Accent bar border texture",
    "The edge style drawn around the accent bar. 'None' removes it, as does a size of 0.")
  numberField(accentBorderRow, "Accent bar border size", "accentBorderSize",
    C.MIN_BORDER, C.MAX_BORDER, 1,
    "Thickness of the accent bar's own border. 0 removes it entirely, which is the default.")

  editorSpacer(group, EDITOR_ROW_GAP)
  local accentBorderOffsetRow = editorRow(group)
  numberField(accentBorderOffsetRow, "Accent bar border offset", "accentBorderOffset",
    C.MIN_BORDER_OFFSET, C.MAX_BORDER_OFFSET, 1,
    "How far the bar's border sits from the bar. Positive pushes it outward, negative inward.")

  editorSpacer(group, EDITOR_ROW_GAP)
  local accentBorderColorRow = editorRow(group)
  makeColorPair(ctx, accentBorderColorRow, rec, "accentBorderColor", "Accent bar border color")

  -- ── Artwork ──
  -- Last of the appearance sections, and deliberately so: artwork is drawn INTO the panel the three
  -- sections above describe, so it reads as a decision you make once the panel itself looks right.
  --
  -- The dropdowns are all label-carrying option lists rather than raw tokens — see optionDropdown.
  editorHeading(group, "Artwork")

  -- Full width. Catalog labels carry their whole derived category, so a row reads
  -- "Faction -> Expansion -> 12 Midnight: Harati" — half a row truncates that to uselessness.
  local artRow = editorRow(group)

  -- Built from Artwork.List() rather than from the catalog, because that function already places
  -- the two reserved entries where they were agreed to go ("None" first, "Custom path" last) and
  -- prefixes each catalog row with its category. Rebuilt per editor build for the same reason the
  -- media lists are: an art pack appending to the catalog may well have loaded after this addon.
  local artOptions = {}
  for i, entry in ipairs(NS.Artwork.List()) do
    artOptions[i] = { value = entry.id, label = entry.label }
  end
  optionDropdown(artRow, "Artwork", "artTexture", artOptions,
    "The image drawn inside this panel. 'None' draws nothing at all, which is what every panel "
    .. "starts as. 'Custom path\226\128\166' uses the file you name below instead of a bundled "
    .. "piece.", 1.0)

  editorSpacer(group, EDITOR_ROW_GAP)
  -- Also full width: a texture path is long, and the useful ones are longer than half a row.
  local artPathRow = editorRow(group)
  local pathBox = AceGUI:Create("EditBox")
  pathBox:SetLabel("Custom texture path")
  pathBox:SetRelativeWidth(1.0)
  local function applyArtPath(live)
    -- The disabled state is pushed unconditionally: it tracks artTexture, and a stale one would let
    -- you type into a box whose contents nothing reads.
    pathBox:SetDisabled(live.artTexture ~= C.ARTWORK_CUSTOM)
    -- The TEXT is not, while the box has focus. This is the one control in the editor holding a
    -- half-typed value, and a MSG_PANEL from somewhere else entirely — a drag, a `/pm panel set`,
    -- another field in this very editor — would otherwise wipe the path mid-keystroke. The rename
    -- box solves the same problem by having no refresher at all; this one cannot, because it has a
    -- disabled state to keep honest.
    local eb = pathBox.editbox
    if eb and eb.HasFocus and eb:HasFocus() then return end
    pathBox:SetText(live.artCustomPath or "")
  end
  applyArtPath(rec)
  pathBox:SetCallback("OnEnterPressed", function(_, _, text)
    NS.Registry:Set(rec.id, "artCustomPath", text)
  end)
  attachTooltip(pathBox, "Custom texture path",
    "A texture file of your own, given as a full path \226\128\148 either one of the game's own, "
    .. "like |cffffff00Interface\\DialogFrame\\UI-DialogBox-Gold-Dragon|r, or your own, like "
    .. "|cffffff00Interface\\AddOns\\MyAddon\\art\\logo.tga|r. Only used while Artwork is set "
    .. "to 'Custom path\226\128\166'.\n\nWoW loads TGA and BLP files whose width and height are "
    .. "both powers of two. Anything else draws as a green square or as nothing, with no error.")
  artPathRow:AddChild(pathBox)
  addRefresher(ctx, rec, applyArtPath)

  editorSpacer(group, EDITOR_ROW_GAP)
  local artFillRow = editorRow(group)
  optionDropdown(artFillRow, "Fill", "artFill", C.ART_FILL_OPTIONS,
    "How the image is sized inside the panel.\n\n"
    .. "|cffffff00Native size|r draws it at its authored pixel size, aspect intact.\n"
    .. "|cffffff00Stretch|r matches the panel exactly and distorts the aspect to do it.\n"
    .. "|cffffff00Fill (crop)|r covers the panel with the aspect intact, cropping whatever "
    .. "overflows.\n"
    .. "|cffffff00Fit (contain)|r shows the whole image with the aspect intact, leaving space on "
    .. "two sides.\n"
    .. "|cffffff00Tile|r repeats it at native size across the panel.\n\n"
    .. "Stretch ignores Scale \226\128\148 a scaled stretch is really Fill or Native size.")
  tokenDropdown(artFillRow, "Artwork position", "artPoint", C.POINTS,
    "Which part of the panel the artwork is anchored to, and what the offsets below are measured "
    .. "from.\n\nIgnored by Stretch, Fill and Tile: those three cover the panel exactly, so there "
    .. "is nowhere for the art to move to.")

  editorSpacer(group, EDITOR_ROW_GAP)
  editorSpacer(group, EDITOR_ROW_GAP)
  local artScaleRow = editorRow(group)
  numberField(artScaleRow, "Artwork scale", "artScale", C.MIN_ART_SCALE, C.MAX_ART_SCALE, 0.05,
    "Size multiplier for the artwork.\n\nIgnored entirely by Stretch, which always matches the "
    .. "panel exactly. Under Fill and Tile the art still covers the panel, so this changes what you "
    .. "SEE rather than how big the art is drawn: above 1 Fill crops tighter (it zooms in) and Tile "
    .. "lays down fewer, larger copies.")
  optionDropdown(artScaleRow, "Rotation", "artRotation", C.ART_ROTATION_OPTIONS,
    "Turn the artwork. Quarter turns only: those are an exact swap of the texture's corners, with "
    .. "no blurring and no smeared edges. An arbitrary angle cannot be drawn that cleanly on a "
    .. "cropped image, so it is not offered.")

  editorSpacer(group, EDITOR_ROW_GAP)
  local artFlipRow = editorRow(group)
  boolField(artFlipRow, "Flip horizontal", "artFlipH",
    "Mirror the artwork left to right. Applied BEFORE the rotation, so flipping and then turning "
    .. "is not the same result as turning and then flipping.")
  boolField(artFlipRow, "Flip vertical", "artFlipV",
    "Mirror the artwork top to bottom. Applied before the rotation, like the horizontal flip.")

  editorSpacer(group, EDITOR_ROW_GAP)
  local artOpacityRow = editorRow(group)
  numberField(artOpacityRow, "Artwork opacity", "artAlpha", 0, 1, 0.05,
    "How visible the artwork is. Multiplies with the opacity in the artwork color AND with the "
    .. "panel's own opacity, so a faded panel fades its art with it.")
  optionDropdown(artOpacityRow, "Draw layer", "artLayer", C.ART_LAYER_OPTIONS,
    "Where the artwork sits in the panel's stack.\n\n"
    .. "|cffffff00Behind background|r puts it under the fill, so it only shows through a "
    .. "background that is transparent or partly so \226\128\148 with a solid background it is "
    .. "invisible.\n"
    .. "|cffffff00Above background|r is the default: over the fill, under the border and accent "
    .. "bar.\n"
    .. "|cffffff00Above border and accent|r draws it over everything, which is what a logo wants.")

  editorSpacer(group, EDITOR_ROW_GAP)
  -- The color pair gets a row to ITSELF, because makeColorPair emits TWO half-width widgets — the
  -- swatch and its Class color companion. Sharing the row with anything else puts three half-width
  -- controls on one line and the third wraps under, which is exactly how it looked in game.
  --
  -- The pair is also unconditional now. It used to exist only while the selected art was "tintable",
  -- so it appeared and vanished as you paged the dropdown and shoved every row below it up and down.
  -- Every piece takes a tint, and the default tint is white, so the control is always honest.
  local artColorRow = editorRow(group)
  makeColorPair(ctx, artColorRow, rec, "artColor", "Artwork color")

  editorSpacer(group, EDITOR_ROW_GAP)
  local artToneRow = editorRow(group)
  boolField(artToneRow, "Desaturate", "artDesaturate",
    "Drains the color out of the artwork before the tint is applied.\n\nThis is what makes "
    .. "|cffffff00Artwork color|r work properly on full-color art: tinting a gold-and-crimson crest "
    .. "blue only drags every hue toward blue and muddies it, but draining it to grayscale first "
    .. "means the tint comes back as a clean blue.")
  optionDropdown(artToneRow, "Blend mode", "artBlend", C.ART_BLEND_OPTIONS,
    "How the artwork's pixels combine with what is behind them.\n\n"
    .. "|cffffff00Normal|r paints over the panel, obeying the image's transparency.\n"
    .. "|cffffff00Glow|r ADDS the artwork's light to the panel instead: it can only brighten, "
    .. "never darken, and reads as a lit emblem. Strongest over a dark panel.")

  editorSpacer(group, EDITOR_ROW_GAP)
  local artOffsetRow = editorRow(group)
  -- The same span as the panel's own X/Y, and for the same reason: C.EDITOR_OFFSET_RANGE is a
  -- reach, not a clamp, and E.SliderSpan widens it to whatever the record actually holds.
  numberField(artOffsetRow, "Artwork X offset", "artX",
    -C.EDITOR_OFFSET_RANGE, C.EDITOR_OFFSET_RANGE, 1,
    "Nudge the art horizontally from its position anchor. Ignored by Stretch, Fill and Tile, which "
    .. "have no room to move in.")
  numberField(artOffsetRow, "Artwork Y offset", "artY",
    -C.EDITOR_OFFSET_RANGE, C.EDITOR_OFFSET_RANGE, 1,
    "Nudge the art vertically from its position anchor. Ignored by Stretch, Fill and Tile, which "
    .. "have no room to move in.")

  editorSpacer(group, EDITOR_ROW_GAP)

  -- ── Visibility ──
  editorHeading(group, "Visibility")

  -- Panel opacity gets its own row: it applies whatever else is set, whereas the two controls below
  -- are a pair that only mean anything together. Putting the checkbox up here beside it implied the
  -- opposite grouping.
  --
  -- "Panel opacity", not "Background opacity". It is the FRAME's alpha, so it fades the border as
  -- well as the fill, and it multiplies with the alpha already carried by each color. It is also
  -- the value the mouseover fade rises to — which is why it cannot simply be folded into the
  -- background color's alpha, however much the two look alike.
  local opacityRow = editorRow(group)
  numberField(opacityRow, "Panel opacity", "alpha", 0, 1, 0.05,
    "How visible the whole panel is \226\128\148 background and border together. Multiplies with "
    .. "the opacity set in each color. This is also the opacity a mouseover panel fades up to.")

  editorSpacer(group, EDITOR_ROW_GAP)
  local mouseoverRow = editorRow(group)
  numberField(mouseoverRow, "Faded opacity", "mouseoverAlpha", 0, 1, 0.05,
    "How visible the panel is while the cursor is elsewhere. 0 hides it completely. "
    .. "Only used when 'Show on mouseover only' is ticked.")

  boolField(mouseoverRow, "Show on mouseover only", "mouseover",
    "Keep the panel faded until the cursor is over it. The panel still never takes your clicks.")

  -- Delete and Reset are not repeated down here: they have their own actions row up in General, just
  -- below the Enabled/Unlock switches, so the two irreversible buttons sit together and nowhere near
  -- the styling controls you scroll past on the way down.
  editorSpacer(group, EDITOR_ROW_GAP)

  parent:AddChild(group)
end

local function buildPanelsPage(ctx)
  bindHelpers()
  local scroll = ensureScroll(ctx)

  -- ── Create ──
  section(ctx, "Create")

  local createRow = AceGUI:Create("SimpleGroup")
  createRow:SetLayout("Flow"); createRow:SetFullWidth(true)

  local nameBox = AceGUI:Create("EditBox")
  nameBox:SetLabel("New panel name")
  nameBox:SetFullWidth(true)
  -- The EditBox's own "Okay" button is the confirm, matching the rename box in the editor below —
  -- one confirmation gesture for both places you type a panel name.
  --
  -- Safe because AceGUI's EditBox does NOT commit on focus loss: `OnEnterPressed` is fired only by
  -- the Enter key, the Okay button and a drag-receive. `OnEditFocusLost` is not even registered. (An
  -- earlier version disabled the button and added a separate Create button on the mistaken
  -- assumption that tabbing away would create a panel.)
  nameBox:SetCallback("OnEnterPressed", function(widget, _, text)
    pageAction.create(ctx, widget, text)
  end)
  attachTooltip(nameBox, "New panel name",
    "Type a name and press Enter, or click Okay, to create the panel.")
  createRow:AddChild(nameBox)
  scroll:AddChild(createRow)
  addSpacer(scroll, ROW_VSPACER)

  -- ── Edit ──
  section(ctx, "Edit")

  -- The selector, plus the editor container beneath it. Both are rebuilt together: the dropdown's
  -- contents and the editor's contents are two views of the same panel list.
  local selectRow = AceGUI:Create("SimpleGroup")
  selectRow:SetLayout("List"); selectRow:SetFullWidth(true)
  -- The panel dropdown carries no label, so without this it would sit 14px closer to the "Edit"
  -- heading than the Create box sits to "Create", and the two headings would look inconsistently
  -- spaced despite both using the same section spacer.
  addSpacer(scroll, LABEL_ROW_H)
  scroll:AddChild(selectRow)

  local listGroup = AceGUI:Create("SimpleGroup")
  listGroup:SetLayout("List"); listGroup:SetFullWidth(true)
  scroll:AddChild(listGroup)

  ctx.rebuilders[#ctx.rebuilders + 1] = function()
    -- The widgets about to be released include every dropdown registered for scroll-close, so the
    -- registry is emptied before the new ones re-register.
    forgetDropdowns(ctx)
    selectRow:ReleaseChildren()
    listGroup:ReleaseChildren()

    local records = panelsByName()
    if #records == 0 then
      local empty = AceGUI:Create("Label")
      empty:SetFullWidth(true)
      empty:SetText("No panels yet. Type a name above and press Create.")
      listGroup:AddChild(empty)
      if ctx.scroll and ctx.scroll.DoLayout then ctx.scroll:DoLayout() end
      return
    end

    -- Keep the selection if it still exists, otherwise fall back to the first panel. A deleted
    -- selection must not leave the page blank with a dropdown pointing at nothing.
    if not (selectedID and NS.Registry:Get(selectedID)) then
      selectedID = records[1].id
    end

    local dd = AceGUI:Create("Dropdown")
    trackDropdown(ctx, dd)
    -- No label, full width. The section heading directly above already says "Edit", and the
    -- dropdown's only content is panel names — a "Panel" label above it was restating the obvious
    -- while costing a row of height and leaving the control stranded in the left column.
    dd:SetLabel("")
    dd:SetFullWidth(true)
    local list, order = {}, {}
    for i, rec in ipairs(records) do
      -- A disabled panel is marked in the list, so it is obvious why editing it changes nothing
      -- on screen.
      list[rec.id] = rec.enabled and rec.name or (rec.name .. " |cff808080(disabled)|r")
      order[i] = rec.id
    end
    dd:SetList(list, order)
    dd:SetValue(selectedID)
    dd:SetCallback("OnValueChanged", function(_, _, id)
      selectedID = id
      runRebuilders(ctx)
    end)
    selectRow:AddChild(dd)
    -- The gap between the selector and the editor's title. The largest of the editor's three gaps:
    -- it separates two different things (choosing a panel, and configuring it) rather than two
    -- groups of the same thing.
    editorSpacer(selectRow, EDITOR_SELECT_GAP)

    -- No heading naming the panel: the dropdown directly above already shows which one is selected,
    -- and a heading repeating it was a third line of chrome between choosing a panel and editing it.
    buildPanelEditor(ctx, listGroup, NS.Registry:Get(selectedID))
    if ctx.scroll and ctx.scroll.DoLayout then ctx.scroll:DoLayout() end
  end

end

-- The Panels page's whole repaint policy, and its only two triggers (options-ui-§11).
--
--   MSG_PANELS is STRUCTURAL — a panel was created, deleted or renamed, so the selector's contents
--   and the editor's identity both change. One rebuild.
--   MSG_PANEL is SCALAR — one field of one panel changed, from the CLI, a drag, Reset or CopyFrom.
--   The open editor re-syncs in place and nothing is released. Rebuilding here instead would be a
--   full AceGUI teardown per field write (anti-pattern #39) and would take the control out from
--   under a user mid-drag, which is precisely why it is not done.
--
-- Both are scoped to the on-screen page: an off-screen page is only flagged dirty, so a `/pm new`
-- with the options window closed costs nothing and is picked up by the next OnShow.
--
-- Wired at REGISTRATION rather than from the page build, because the build is lazy: a page that has
-- never been shown would otherwise miss every change made before its first OnShow.
local function wirePanelsBus(ctx)
  if E.__evPanels then return end
  local ev = NS.NewBusTarget()
  if not ev then return end

  ev:RegisterMessage(NS.Registry.MSG_PANELS, function()
    -- A create hands its selection over by NAME, because the id did not exist when the mutation
    -- started and this message arrives from inside R:New (see pageAction.create).
    if ctx.pendingSelect then
      local rec = NS.Registry:FindByName(ctx.pendingSelect)
      ctx.pendingSelect = nil
      if rec then selectedID = rec.id end
    end
    if ctx.panel:IsShown() then runRebuilders(ctx) else ctx.dirty = true end
  end)

  ev:RegisterMessage(NS.Registry.MSG_PANEL, function(_, id)
    if id ~= selectedID then return end   -- some other panel changed; this editor is not showing it
    if ctx.panel:IsShown() then NS.Panel:RefreshPanels(ctx) else ctx.dirty = true end
  end)

  E.__evPanels = ev
end

-- ── The three things settings/Panel.lua drives this file with ───────────────────
-- Subscribe the page's context to the panel bus. Called from P:Register, not from the build, so a
-- page that has never been shown still tracks changes made while it was hidden.
function E:WireBus(ctx) wirePanelsBus(ctx) end

-- Emit the page's static furniture (the create box, the two section headings, the selector's
-- container) and install the rebuilder that draws the editor itself. First OnShow only.
function E:BuildPage(ctx) buildPanelsPage(ctx) end

-- Repaint the selector and the open editor. The one structural entry point: first paint, a page that
-- went dirty while hidden, and every MSG_PANELS.
function E:Rebuild(ctx) runRebuilders(ctx) end
