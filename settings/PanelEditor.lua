local addonName, NS = ...   -- luacheck: ignore addonName
NS.PanelEditor = NS.PanelEditor or {}
local E = NS.PanelEditor
local C = NS.Constants
local print = NS.Print   -- secret-safe, [PM]-prefixed shared printer (events-frames-taint-§8)

local AceGUI = LibStub and LibStub("AceGUI-3.0", true)

-- ── The Panels subcategory's body ───────────────────────────────────────────────
-- The create control, the panel selector, and one panel's editor under a six-tab strip. This is the
-- structural page: its content depends on how many panels exist, so it lives behind `rebuilders`
-- and is repainted only when the SET of panels changes (options-ui-§11) or when a tab is clicked,
-- never on every OnShow.
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
local attachTooltip, ensureScroll, makePairButton
local trackDropdown, forgetDropdowns, safeRun, LSM_WIDGET
local BUTTON_PAIR_REL, SECTION_HEADING_H

-- `section`, `addSpacer` and `ROW_VSPACER` are no longer among them. They drew the two untabbed
-- "Create" and "Edit" headings and the gaps around them, and both sections have moved into the
-- page's chrome band (options-ui-§14) where a scroll-anchored heading cannot go. SECTION_HEADING_H
-- arrives in their place, for the in-tab subsection headings (options-ui-§7).
local function bindHelpers()
  local ui = NS.Panel and NS.Panel.__ui
  if not ui then return end
  attachTooltip,  ensureScroll,    makePairButton = ui.attachTooltip, ui.ensureScroll,
                                                    ui.makePairButton
  trackDropdown,  forgetDropdowns, safeRun        = ui.trackDropdown, ui.forgetDropdowns, ui.safeRun
  LSM_WIDGET                                      = ui.LSM_WIDGET
  BUTTON_PAIR_REL, SECTION_HEADING_H              = ui.BUTTON_PAIR_REL, ui.SECTION_HEADING_H
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

-- ── The editor's tabs (options-ui-§13) ──────────────────────────────────────────
-- The six subjects one panel is edited under, in strip order. This page's content is BESPOKE --
-- a panel is a registry record, not a set of schema rows with paths -- so H.RenderTabbedSchema has
-- nothing here to partition and the strip is drawn directly with H.TabStrip, exactly as the
-- reference implementation draws its own two bespoke pages.
--
-- The strip is only the EDITOR's. "Create" and "Edit" stay untabbed at the top of the scroll,
-- above whichever tab is showing: making a panel and choosing which panel to work on are not one
-- of the six subjects, and a tab you have to leave to pick a different panel would be one.
--
-- Named constants rather than repeated literals, because each one is used three times -- the tab
-- button, the section it dispatches to, and the strip's order array -- and a typo in any of the
-- three is a tab that draws an empty editor.
--
-- "Background" and "Border" used to be two subsections of two and four controls. They are one tab:
-- the fill and the edge are two halves of one question, and a two-control tab is not a subject.
-- "Visibility" is now "Opacity and fade", which is what its three controls actually are -- the old
-- name promised the where/when rules of a visibility engine this addon does not have.
local TAB_GENERAL  = "General"
local TAB_POSITION = "Position and size"
local TAB_SURFACE  = "Background and border"
local TAB_ACCENT   = "Accent bar"
local TAB_ARTWORK  = "Artwork"
local TAB_FADE     = "Opacity and fade"

-- Strip order: what you reach for first (which panel, is it on), then where it sits, then the three
-- appearance tabs read together, then the one you set once.
local EDITOR_TABS = {
  TAB_GENERAL, TAB_POSITION, TAB_SURFACE, TAB_ACCENT, TAB_ARTWORK, TAB_FADE,
}

-- Published for the partition case in tests/test_schema.lua, which is the only reader outside this
-- file: AceGUI is stubbed in the harness, so the strip itself is not observable and the ORDER is
-- the part a test can hold onto.
E.TABS = EDITOR_TABS

-- Membership, so a stale `ctx.activeTab` -- one left over from a build before a tab was renamed --
-- heals to the first tab instead of drawing an editor with nothing in it.
local IS_EDITOR_TAB = {}
for _, name in ipairs(EDITOR_TABS) do IS_EDITOR_TAB[name] = true end

-- ── Editor layout constants ─────────────────────────────────────────────────────
-- Vertical rhythm inside the panel editor. Named, never inlined (options-ui-§8), and deliberately
-- two distinct sizes so the spacing itself communicates structure: a big gap means "new part of
-- the page", a small one "still the same thought".
--
-- The middle size came back, and with it a heading. The editor's six SUBJECTS are tabs and are
-- announced by the strip -- that has not changed -- but a tab that mixes two kinds of control has
-- to say where one stops and the next starts (options-ui-§7), and three of the six do.
local EDITOR_ROW_GAP     = 6    -- between rows within one subsection
local EDITOR_HEADING_GAP = 10   -- above a subsection heading; below it the heading's own art reads
                                -- as the separation, so nothing is added there
-- The gap between the content panel's top edge and the editor's first control.
--
-- It used to be EDITOR_ROW_GAP and could afford to be, because the editor was wrapped in a
-- titleless InlineGroup that contributed an inset of its own -- an empty title bar plus the box's
-- padding, near twenty pixels of it. That box is gone (options-ui-§14: a bounded box inside a band
-- the content panel already bounds is a border stating a boundary twice), so the gap is stated here
-- rather than inherited from a widget that happened to have one.
local EDITOR_TOP_GAP     = 16
-- `EDITOR_SELECT_GAP` and `LABEL_ROW_H` went with the same change. The first spaced the panel
-- dropdown from the editor and the second compensated that dropdown for having no label; the picker
-- is in the chrome band now, carries a label, and is not above the editor at all.

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
-- graying it would tell the player something untrue. The label suffix says which half is live and
-- the tooltip says it in the collection's words.
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
  -- The note is the LIBRARY's string, not a paraphrase: options-ui-§17 fixes what a swatch says
  -- about its companion, and nine addons saying it nine ways is the drift the constant ends.
  attachTooltip(picker, label,
    "Sets the color and its opacity. "
    .. ((NS.Helpers and NS.Helpers.CLASS_COLOR_NOTE) or ""))
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
  -- `Use class color`, verbatim: options-ui-§17 names the control, and it was "Class color" here.
  cb:SetLabel("Use class color")
  cb:SetRelativeWidth(0.5)
  cb:SetValue(usingClass)
  cb:SetCallback("OnValueChanged", function(_, _, v)
    NS.Registry:Set(rec.id, flag, v and true or false)
    picker:SetLabel(labelFor(v and true or false))
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

-- One panel's editor: a single group holding the panel's geometry, layer, color and visibility
-- fields. Every control writes through NS.Registry:Set, which is the same seam the CLI and the drag
-- handler use.
local function buildPanelEditor(ctx, parent, rec)
  -- A plain List container, NOT an InlineGroup, and the box is the point rather than the widget.
  -- The editor sits under a tab strip whose content panel already draws a boundary around the whole
  -- page, and a second bounded box inside it was a border stating a boundary the page already
  -- states (options-ui-§14, anti-pattern #72). The InlineGroup was also titleless, so it was never
  -- naming anything -- it was drawing an edge and an inset and nothing else.
  local group = AceGUI:Create("SimpleGroup")
  group:SetFullWidth(true)
  group:SetLayout("List")

  editorSpacer(group, EDITOR_TOP_GAP)

  -- `rel` overrides the half-row default for a slider that has no partner on its line. Passed
  -- rather than inferred, because "is this row full" is not something a widget maker can see.
  local function numberField(row, label, field, minV, maxV, step, tooltip, rel)
    local s = AceGUI:Create("Slider")
    s:SetLabel(label)
    s:SetRelativeWidth(rel or 0.5)
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

  -- ── The tabs ──
  -- One function per tab, dispatched on ctx.activeTab below. The strip IS the heading, so
  -- no section draws one of its own any more; and only the active tab is built, which is
  -- why every control registers its refresher from inside its own section rather than
  -- from the top of this function.
  local sections = {}

  -- Identity first, then the switches, then the two whole-panel actions. Reading order matches
  -- decision order: which panel is this, is it on, and am I done with it.
  sections[TAB_GENERAL] = function()
    -- Identity first, then the switches, then the two whole-panel actions. Reading order matches
    -- decision order: which panel is this, is it on, and am I done with it.

    local nameRow = editorRow(group)

    local nameBox = AceGUI:Create("EditBox")
    nameBox:SetLabel("Panel name")
    nameBox:SetRelativeWidth(0.5)
    nameBox:SetText(rec.name)
    -- Renaming changes the selector entry and every label the panel appears under, so it is
    -- structural (the frame name is NOT affected — it is stamped at create): MSG_PANELS rebuilds
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
       .. "It is fixed when the panel is created and does not change when you rename the panel, so "
       .. "anything anchored to it keeps working.")
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
  end

  -- Where the panel is and how big it is, ending on the scale that acts on all of it at once.
  sections[TAB_POSITION] = function()
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

    editorSpacer(group, EDITOR_ROW_GAP)
    -- Full width, spanning both columns. Scale is the one control on this page that acts on
    -- EVERYTHING above it at once — width, height, border, accent bars and artwork together — so it
    -- reads as a footer to the section rather than as one of a pair, and pairing it with any single
    -- neighbor would imply a relationship it does not have.
    local scaleRow = editorRow(group)
    numberField(scaleRow, "Panel scale", "scale",
      C.MIN_PANEL_SCALE, C.MAX_PANEL_SCALE, 0.05,
      "Scales the whole panel \226\128\148 its size, its border, its accent bars and its artwork "
      .. "\226\128\148 as one piece.\n\nThis is not the same as changing Width and Height: those "
      .. "resize the panel and leave the border and bars at the thickness you set, while this "
      .. "magnifies all of it together, the way the game's own UI scale does.\n\nWidth and Height "
      .. "keep reading the numbers you typed; what changes is how big those turn out on screen. The "
      .. "panel is anchored in its own scaled units, so a scaled panel also moves relative to its "
      .. "anchor \226\128\148 nudge the offsets afterwards if it matters.", 1.0)
  end

  -- The panel's own surface: the fill inside it and the edge around it.
  --
  -- The MERGE STAYS. It is argued for at the tab list above -- the fill and the edge are two halves
  -- of one question, and a two-control tab is not a subject -- and options-ui-§7 does not undo a
  -- deliberate merge. What it adds is that a tab holding two kinds of control says where one stops
  -- and the next starts, so each half opens with a heading.
  sections[TAB_SURFACE] = function()
    editorHeading(group, "Background")

    local bgRow = editorRow(group)
    makeMediaDropdown(ctx, bgRow, rec, "bgTexture", "Background texture",
      "The texture the panel is filled with. 'Solid' is a flat color; 'None' draws no fill.")

    editorSpacer(group, EDITOR_ROW_GAP)
    local bgColorRow = editorRow(group)
    -- The fill's own opacity lives in this color's alpha. Panel opacity (on the Opacity and fade
    -- tab) is a separate, panel-wide multiplier — see the note there.
    --
    -- The swatch and its companion and nothing else. A background is NOT a bar group
    -- (options-ui-§16), so no opacity row is invented for it here: the alpha above and the
    -- panel-wide opacity are already the two controls that decide how solid the fill is.
    makeColorPair(ctx, bgColorRow, rec, "bgColor", "Background color")

    editorSpacer(group, EDITOR_HEADING_GAP)
    editorHeading(group, "Border")

    -- The canonical border block, in the mandated order: style, thickness, color, companion. This
    -- addon's own offset comes AFTER all four and is never interleaved with them (options-ui-§16).
    local borderRow = editorRow(group)
    makeMediaDropdown(ctx, borderRow, rec, "borderTexture", "Border style",
      "The edge style drawn around the panel. 'Solid' is a plain outline; 'None' removes it.")
    numberField(borderRow, "Border thickness (px)", "borderSize", C.MIN_BORDER, C.MAX_BORDER, 1,
      "Border thickness. 0 removes the border entirely.")

    editorSpacer(group, EDITOR_ROW_GAP)
    local borderColorRow = editorRow(group)
    makeColorPair(ctx, borderColorRow, rec, "borderColor", "Border color")

    editorSpacer(group, EDITOR_ROW_GAP)
    local borderOffsetRow = editorRow(group)
    numberField(borderOffsetRow, "Border offset", "borderOffset",
      C.MIN_BORDER_OFFSET, C.MAX_BORDER_OFFSET, 1,
      "How far the border sits from the panel's edge. Positive pushes it outward, "
      .. "negative pulls it inward.")
  end

  -- The BenikUI-style strip along a panel's edges, which edges it runs along, and the strip's own
  -- border. Three kinds of control on one tab, so three headings (options-ui-§7) — and the middle
  -- one replaces the collection's last hand-rolled heading, a gold |cffffd100Edges|r Label standing
  -- in for a Heading widget (anti-pattern #71).
  --
  -- The controls are named for what they are within their own subsection — `Bar texture`, not
  -- `Accent bar texture` — because the tab already says "Accent bar" and the heading already says
  -- which of the three parts you are in. That is also what lets the bar and border blocks carry the
  -- canonical names options-ui-§16 gives them.
  sections[TAB_ACCENT] = function()
    editorHeading(group, "Bar")

    local accentRow = editorRow(group)
    boolField(accentRow, "Enable accent bar", "accentEnabled",
      "Draw a thin colored strip along the panel's edges, in the style of BenikUI's panels.")

    -- The canonical bar block (options-ui-§16): texture, opacity, color, companion.
    --
    -- `Bar opacity` is NEW, and it is a stored field rather than a re-labeling of something that
    -- was already here. The panel-wide opacity on the Opacity and fade tab fades the whole frame —
    -- background, border and bars together — so it could not be this row without the mandated
    -- control meaning something different on this page from every other page in the collection.
    -- It multiplies the bar color's own alpha; modules/Canvas.lua does the composition.
    editorSpacer(group, EDITOR_ROW_GAP)
    local barRow = editorRow(group)
    makeMediaDropdown(ctx, barRow, rec, "accentTexture", "Bar texture",
      "The texture the accent bar is drawn with, from your LibSharedMedia status-bar textures. "
      .. "'Solid' is a flat color.")
    numberField(barRow, "Bar opacity", "accentAlpha", 0, 1, 0.05,
      "How solid the accent bar's fill is. Multiplies with the opacity in the bar color below and "
      .. "with the panel's own opacity, so a faded panel fades its bars with it.")

    editorSpacer(group, EDITOR_ROW_GAP)
    local accentColorRow = editorRow(group)
    makeColorPair(ctx, accentColorRow, rec, "accentColor", "Bar color")

    -- This addon's own bar rows, AFTER the mandated four rather than among them.
    editorSpacer(group, EDITOR_ROW_GAP)
    local accentSizeRow = editorRow(group)
    numberField(accentSizeRow, "Bar thickness", "accentThickness",
      C.MIN_ACCENT_THICKNESS, C.MAX_ACCENT_THICKNESS, 1,
      "How thick the accent bar is, in screen units.")
    numberField(accentSizeRow, "Bar offset", "accentOffset",
      C.MIN_ACCENT_OFFSET, C.MAX_ACCENT_OFFSET, 1,
      "How far the bar sits from the panel's edge. Positive detaches it from the panel, "
      .. "which is the look this is modeled on; 0 sits flush; negative overlaps the panel.")

    editorSpacer(group, EDITOR_HEADING_GAP)
    editorHeading(group, "Edges")

    local edgeRow = editorRow(group)
    makeEdgeChecks(ctx, edgeRow, rec)

    editorSpacer(group, EDITOR_HEADING_GAP)
    editorHeading(group, "Border")

    -- The bar's own border. The same canonical four in the same order as the panel's, so the two
    -- read alike — the only difference is what they outline.
    local accentBorderRow = editorRow(group)
    makeMediaDropdown(ctx, accentBorderRow, rec, "accentBorderTexture", "Border style",
      "The edge style drawn around the accent bar. 'None' removes it, as does a thickness of 0.")
    numberField(accentBorderRow, "Border thickness (px)", "accentBorderSize",
      C.MIN_BORDER, C.MAX_BORDER, 1,
      "Thickness of the accent bar's own border. 0 removes it entirely.")

    editorSpacer(group, EDITOR_ROW_GAP)
    local accentBorderColorRow = editorRow(group)
    makeColorPair(ctx, accentBorderColorRow, rec, "accentBorderColor", "Border color")

    editorSpacer(group, EDITOR_ROW_GAP)
    local accentBorderOffsetRow = editorRow(group)
    numberField(accentBorderOffsetRow, "Border offset", "accentBorderOffset",
      C.MIN_BORDER_OFFSET, C.MAX_BORDER_OFFSET, 1,
      "How far the bar's border sits from the bar. Positive pushes it outward, negative inward.")
  end

  -- Artwork is drawn INTO the panel the three tabs before it describe, which is why it sits
  -- after them: it is the decision you make once the panel itself looks right.
  sections[TAB_ARTWORK] = function()
    -- The dropdowns are all label-carrying option lists rather than raw tokens — see optionDropdown.
    --
    -- The longest tab on the page, and three kinds of control deep: which image, where it sits, and
    -- what it looks like. options-ui-§7 wants a heading between each pair of those, and the runs
    -- were already in that order — the only row that moved is the artwork offset pair, which sat at
    -- the very bottom under the color controls and belongs with the rest of the placement.
    editorHeading(group, "Image")

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
    -- Half a row each, sharing the line with Fit to artwork. The path box was full width once, on the
    -- reasoning that a texture path is long — which is true, and it still scrolls horizontally when it
    -- has to. Pairing them costs the box some visible characters and buys the button a home beside the
    -- other artwork controls rather than a row of its own with empty space next to it.
    local artPathRow = editorRow(group)
    local pathBox = AceGUI:Create("EditBox")
    pathBox:SetLabel("Custom texture path")
    pathBox:SetRelativeWidth(BUTTON_PAIR_REL)
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

    -- A BUTTON rather than a checkbox, because fitting a panel to its art is something you do once,
    -- not a mode you leave running. As a stored flag it reshaped the panel on every width change and
    -- overwrote a height typed by hand, which is why it shipped off by default and why `height` needed
    -- an explicit carve-out to stop the two fighting. Pressed once, the height is an ordinary field
    -- again and stays where it is put.
    local fitBtn = makePairButton("Fit to artwork", function()
      local ok, w, h = NS.Registry:FitToArtwork(rec.id)
      -- Said out loud either way. The two failures — no artwork, or art that is not installed — look
      -- identical to a silent no-op, and a button that does nothing without saying why reads as
      -- broken. On failure the second return is the reason, not a width.
      if ok then
        print(("fitted '%s' to its artwork (%dx%d)."):format(rec.name, w, h))
      else
        print(w)
      end
    end)
    attachTooltip(fitBtn, "Fit to artwork",
      "Resizes this panel to the artwork's |cffffff00exact pixel size|r.\n\nA bundled piece is "
      .. "1024x1024 and gives a square panel that big; a three-section Sunn bar is 1536x256 and gives "
      .. "a long thin one. A composed bar uses the size of the WHOLE bar, not one section.\n\nOnly "
      .. "when you press this \226\128\148 nothing resizes on its own. Very large art gives a very "
      .. "large panel, so drag it back to a size you want afterwards; press this again any time to "
      .. "return to the artwork's own size.")
    artPathRow:AddChild(fitBtn)

    editorSpacer(group, EDITOR_HEADING_GAP)
    editorHeading(group, "Layout")

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

    editorSpacer(group, EDITOR_HEADING_GAP)
    editorHeading(group, "Appearance")

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
  end

  -- Last, because it is the tab you set once: the panel's own opacity and the mouseover fade.
  sections[TAB_FADE] = function()
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

    -- Delete and Reset are not repeated here: they have their own actions row on the General tab,
    -- just below the Enabled/Unlock switches, so the two irreversible buttons sit together and on
    -- the tab that is about the panel's identity rather than among the styling controls.
    editorSpacer(group, EDITOR_ROW_GAP)
  end

  -- A stale pointer heals to the first tab rather than leaving the editor blank, the same
  -- way the library's own RenderTabbedSchema heals one. Cheap on every build, and the
  -- alternative is a page that shows nothing until the user clicks something.
  local build = sections[ctx.activeTab] or sections[TAB_GENERAL]
  build()

  parent:AddChild(group)
end

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
-- Making a panel and choosing which panel to edit apply to EVERY tab, so they belong in the band
-- the page banner occupies rather than in the scroll below the strip. They were in the scroll —
-- two untabbed "Create" and "Edit" sections drawn under whichever tab happened to be showing — and
-- the rule names exactly that shape: a control that governs the whole page but is drawn under one
-- tab reads as belonging to that tab.
--
-- ONE chrome block per page, and this is it. H.PageHeader and H.PageBanner release the same ledger
-- and write the same reserved height, so the picker goes INSIDE this block and no banner is drawn
-- separately: two blocks would be two bands, and the second would push the page down for nothing.
--
-- NOT BOXED, either. The band is already separated from the page by its own divider and by the
-- content panel's top edge, and a bounded box around these two controls would be a border stating a
-- boundary the band already states.
--
-- Built ONCE, from BuildPage, and never released by a rebuild. The create box is the reason and it
-- was true before the move too: a create broadcasts MSG_PANELS from inside R:New, so the rebuild
-- lands while the user's own callback is still on the stack, and releasing the box would hand the
-- widget they are typing into back to AceGUI's pool. The picker beside it is refreshed IN PLACE
-- instead — SetList and SetValue on the widget that is already there, which is the same scalar path
-- every other control on this page takes.
local function drawPageHeader(ctx)
  local H = NS.Helpers
  if not (H and H.PageHeader) then return end

  H.PageHeader(ctx, {
    -- The library's own floor for this band, which is roughly an AceGUI control WITH a label —
    -- exactly what both of these are. Read rather than restated (options-ui-§8).
    height = H.BANNER_H,
    build = function(_, frame)
      local block = AceGUI:Create("SimpleGroup")
      if not (block and block.frame) then return end
      block:SetLayout("Flow")
      block.frame:SetParent(frame)
      block.frame:ClearAllPoints()
      block.frame:SetPoint("TOPLEFT",     frame, "TOPLEFT",     0, 0)
      block.frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

      -- The EditBox's own "Okay" button is the confirm, matching the rename box in the editor
      -- below — one confirmation gesture for both places you type a panel name.
      --
      -- Safe because AceGUI's EditBox does NOT commit on focus loss: `OnEnterPressed` is fired only
      -- by the Enter key, the Okay button and a drag-receive. `OnEditFocusLost` is not even
      -- registered. (An earlier version disabled the button and added a separate Create button on
      -- the mistaken assumption that tabbing away would create a panel.)
      local nameBox = AceGUI:Create("EditBox")
      nameBox:SetLabel("New panel name")
      nameBox:SetRelativeWidth(0.5)
      nameBox:SetCallback("OnEnterPressed", function(widget, _, text)
        pageAction.create(ctx, widget, text)
      end)
      attachTooltip(nameBox, "New panel name",
        "Type a name and press Enter, or click Okay, to create the panel.")
      block:AddChild(nameBox)

      -- The picker carries a LABEL now. It did not when it lived under an "Edit" section heading
      -- that said what it was for; in the band there is no heading above it, and an unlabeled
      -- dropdown beside a labeled edit box reads as a control that lost its caption.
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
      block:AddChild(picker)

      if block.DoLayout then block:DoLayout() end
      ctx.__pmPicker = picker
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
    refreshPicker(ctx, records)

    if #records == 0 then
      -- The empty state is CONTENT, under the same strip every other state draws.
      local empty = AceGUI:Create("Label")
      empty:SetFullWidth(true)
      empty:SetText("No panels yet. Type a name in the box above and press Enter to make one.")
      listGroup:AddChild(empty)
    else
      -- No heading naming the panel: the picker in the band above already shows which one is
      -- selected, and a heading repeating it was a third line of chrome between choosing a panel
      -- and editing it.
      buildPanelEditor(ctx, listGroup, NS.Registry:Get(selectedID))
    end

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
-- THAT SCOPING IS THE LIBRARY'S, not this file's, and it is why both handlers are one call to
-- O.RefreshPanel. This file used to hand-roll the branch — `if ctx.panel:IsShown() then rebuild else
-- ctx.dirty = true end` — and the flag was WRONG: the gate in LibKa0s's SetRenderer OnShow reads
-- `ctx._dirty`, with the underscore, so `ctx.dirty` was written in four places and read in none. The
-- deferral silently never happened. A profile switch fires MSG_PANELS from Registry:ReloadProfile
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
    NS.Helpers.RefreshPanel(ctx, true)
  end)

  ev:RegisterMessage(NS.Registry.MSG_PANEL, function(_, id)
    if id ~= selectedID then return end   -- some other panel changed; this editor is not showing it
    NS.Helpers.RefreshPanel(ctx, false)
  end)

  E.__evPanels = ev
end

-- ── The three things settings/Panel.lua drives this file with ───────────────────
-- Subscribe the page's context to the panel bus. Called from P:Register, not from the build, so a
-- page that has never been shown still tracks changes made while it was hidden.
function E:WireBus(ctx) wirePanelsBus(ctx) end

-- Emit the page's static furniture (the create box, the two section headings, the selector's
-- container) and install the rebuilder that draws the tab strip and the editor itself. First OnShow
-- only: the strip and the editor belong to the rebuilder, because both change with the panel list
-- and with the selected tab, while Create and Edit never do.
function E:BuildPage(ctx) buildPanelsPage(ctx) end

-- Repaint the selector and the open editor. The one structural entry point: first paint, a page that
-- went dirty while hidden, and every MSG_PANELS.
function E:Rebuild(ctx) runRebuilders(ctx) end
