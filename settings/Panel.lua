local addonName, NS = ...   -- luacheck: ignore addonName
NS.Panel = NS.Panel or {}
local P = NS.Panel
local C = NS.Constants
local print = NS.Print   -- secret-safe, [PM]-prefixed shared printer (events-frames-taint-§8)

local AceGUI = LibStub and LibStub("AceGUI-3.0", true)

-- The Ka0s settings-panel pattern (options-ui):
--   * A parent canvas category renders the LANDING PAGE — logo, one-liner, slash-command list —
--     with the same gold header every subcategory uses.
--   * Each settings group is a canvas SUBCATEGORY with a breadcrumb header
--     ("Ka0s Panel Master ▸ General"), a Defaults button, and a gold divider.
--   * Bodies render schema rows into a TWO-COLUMN grid; AceGUI Headings group them into sections.
-- The category is registered EAGERLY at load so the entry is always in the options list; each body
-- is built LAZILY on its first OnShow, because AceGUI lays out against the panel's current width,
-- which is 0 before the panel is first shown.
-- Every settings write routes through NS.Schema:Set; every panel write through NS.Registry.

local ADDON_TITLE   = "Ka0s Panel Master"
local ADDON_TAGLINE =
  "Draws plain backdrop panels behind your UI, so a screen full of separate frames reads as a few "
  .. "deliberate groups."

-- Layout constants — the exact Ka0s values (options-ui-§8). Named, never inlined.
local PADDING_X     = 16    -- left/right edge inset for the header, divider and body
local HEADER_TOP    = 20    -- title + Defaults button inset from the panel top
local HEADER_HEIGHT = 54    -- panel top → divider; the body starts at HEADER_HEIGHT + 8
local DEFAULTS_W    = 110   -- Defaults button width
local LOGO_SIZE     = 300   -- landing-page logo display size
local ROW_VSPACER   = 8     -- gap between two-column rows
local SECTION_TOP_SPACER, SECTION_BOTTOM_SPACER, SECTION_HEADING_H = 10, 6, 26
-- A cell-filling paired ACTION button insets to this (not a flush 0.5) so its right border clears
-- the ScrollFrame's clip (options-ui-§6/§8). Label-inset controls (checkbox/dropdown/slider) reserve
-- that gutter already and stay at 0.5 — they are immune (options-ui-§10).
local BUTTON_PAIR_REL = 0.492

local mainCategoryID   -- the parent category, the target of /pm config
local registered

-- ── Open-dropdown tracking ──────────────────────────────────────────────────────
-- A dropdown's open list is NOT a child of the scroll frame — AceGUI parents it to UIParent so it
-- can overflow the panel — which means scrolling slides the control away while its list stays
-- floating exactly where it was, detached and often outside the settings window entirely.
--
-- Nothing in AceGUI closes it, so the page has to: every dropdown it builds is registered here, and
-- any user-driven scroll closes whichever one is open first.
local openDropdowns = {}

local function trackDropdown(widget)
  openDropdowns[#openDropdowns + 1] = widget
end

-- Test seams. The headless harness stubs AceGUI out, so no real widget is ever built — these let the
-- close routine be exercised against hand-built stand-ins, which is how the type-dispatch bug below
-- is pinned.
P.__registerDropdownForTest = trackDropdown
function P.__openDropdownCount() return #openDropdowns end

-- Forget widgets released by a rebuild. Called at the top of every rebuild rather than on release,
-- because AceGUI has no per-widget "you were released" callback we can hook from here.
local function forgetDropdowns()
  for i = #openDropdowns, 1, -1 do openDropdowns[i] = nil end
end
P.__forgetDropdownsForTest = forgetDropdowns

-- The LSM media type → the AceGUI widget registered by libs/AceGUI-3.0-SharedMediaWidgets. Those
-- widgets render a preview swatch of each texture in the dropdown, which for a texture picker is the
-- entire point — a list of names tells you nothing about what they look like.
local LSM_WIDGET = {
  background = "LSM30_Background",
  border     = "LSM30_Border",
  statusbar  = "LSM30_Statusbar",
}

-- The same names as a set, for telling the two families of dropdown apart when closing them.
local IS_LSM_WIDGET = {}
for _, widgetType in pairs(LSM_WIDGET) do IS_LSM_WIDGET[widgetType] = true end

-- Close whichever tracked dropdown is open.
--
-- Dispatch is on the widget's `type`, NOT on which fields it happens to have. That distinction is
-- the whole bug this function once had: a stock AceGUI Dropdown ALSO carries a `.dropdown` field —
-- its Blizzard `UIDropDownMenuTemplate` frame — so a field-presence check handed that frame to
-- AGSMW's pool-return, which expects one of its own frames and iterates a `contentRepo` the Blizzard
-- frame does not have. The resulting error propagated out of `MoveScroll` and killed mouse-wheel
-- scrolling on the whole page.
function P.__closeOpenDropdowns()
  local AGSMW
  for _, widget in ipairs(openDropdowns) do
    if IS_LSM_WIDGET[widget.type] then
      -- AceGUI-3.0-SharedMediaWidgets: a plain frame from its own pool, RETURNED rather than hidden,
      -- so the widget's next click opens it instead of toggling it shut.
      if widget.dropdown then
        AGSMW = AGSMW or (LibStub and LibStub("AceGUISharedMediaWidgets-1.0", true))
        if AGSMW and AGSMW.ReturnDropDownFrame then
          widget.dropdown = AGSMW:ReturnDropDownFrame(widget.dropdown)
        end
      end
    elseif widget.pullout and widget.pullout.Close then
      -- Stock AceGUI Dropdown: an AceGUI "Dropdown-Pullout" widget it owns.
      widget.pullout:Close()
    end
  end
end
local closeOpenDropdowns = P.__closeOpenDropdowns

-- ── Tooltip helper (an AceGUI widget via SetCallback, a plain frame via HookScript) ──
local function attachTooltip(widget, label, tooltip)
  if not widget or not tooltip then return end
  local anchor = widget.frame or widget
  if not anchor then return end
  local function show()
    if not GameTooltip then return end
    GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
    if label and label ~= "" then GameTooltip:SetText(label, 1, 1, 1) end
    GameTooltip:AddLine(tooltip, nil, nil, nil, true)
    GameTooltip:Show()
  end
  local function hide() if GameTooltip then GameTooltip:Hide() end end
  if widget.SetCallback then
    widget:SetCallback("OnEnter", show); widget:SetCallback("OnLeave", hide)
  elseif widget.HookScript then
    widget:HookScript("OnEnter", show); widget:HookScript("OnLeave", hide)
  end
end

-- ── Header: "Ka0s Panel Master ▸ <title>" + Defaults button + gold divider ────────
local function buildHeader(panel, title, opts)
  local displayTitle = title
  if not opts.isMain then
    displayTitle = ADDON_TITLE .. " |A:common-icon-forwardarrow:16:16|a " .. title
  end

  local titleFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  titleFS:SetPoint("TOPLEFT", panel, "TOPLEFT", PADDING_X, -HEADER_TOP)
  titleFS:SetText(displayTitle)

  local divider = panel:CreateTexture(nil, "ARTWORK")
  divider:SetAtlas("Options_HorizontalDivider", true)
  divider:SetPoint("TOPLEFT",  panel, "TOPLEFT",   PADDING_X, -HEADER_HEIGHT)
  divider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PADDING_X, -HEADER_HEIGHT)
  divider:SetVertexColor(titleFS:GetTextColor())   -- track the title's gold

  -- The button itself is built LAZILY (ensureDefaultsButton, below) — not here. buildHeader runs
  -- during OnInitialize, which is too early: see the note on that function.
  panel.wantsDefaultsButton = opts.defaultsButton and true or false
  return titleFS, divider
end

-- Build the header's Defaults button, once, on the panel's FIRST OnShow.
--
-- It MUST be an AceGUI Button, not a raw UIPanelButtonTemplate parented onto the canvas
-- (options-ui-§5) — but *when* it is created matters just as much as *what* creates it. AceGUI is a
-- shared library: UI-skinning addons restyle its widgets by hooking `RegisterAsWidget`, so a widget
-- created before that hook is installed keeps Blizzard's stock `UI-Panel-Button-Up` art (the red
-- stone button) forever, while every widget created afterwards comes out in the skin.
--
-- `P:Register()` runs in OnInitialize (ADDON_LOADED), so building the button there is a race against
-- the load order of every other addon — one this addon loses whenever it loads before the skinner,
-- and wins whenever it doesn't. Deferring to first OnShow removes the race: by then every addon has
-- loaded. It is the same rule options-ui-§1 already applies to the panel BODY (anti-pattern #42).
local function ensureDefaultsButton(panel)
  if panel.defaultsBtn or not panel.wantsDefaultsButton or not AceGUI then return end
  local btn = AceGUI:Create("Button")
  if not (btn and btn.frame) then return end
  btn:SetText("Defaults")
  btn:SetWidth(DEFAULTS_W)
  btn.frame:SetParent(panel)
  btn.frame:ClearAllPoints()
  btn.frame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PADDING_X, -HEADER_TOP)
  btn.frame:Show()
  panel.defaultsBtn = btn
  -- The click handler is registered before the button exists (P:Register), so it is parked on the
  -- panel and wired here.
  if panel.defaultsOnClick then btn:SetCallback("OnClick", panel.defaultsOnClick) end
end

-- One defaults action per page, reachable from both routes: the header Defaults button (via the
-- parked `defaultsOnClick` closure) and Blizzard's own Settings-window defaults control (via
-- `OnDefault`, options-ui-§1). Setting them together here is what keeps the two from drifting.
local function setDefaultsAction(panel, fn)
  panel.defaultsOnClick = fn
  panel.OnDefault       = fn
end

-- ── createPanel — a Frame for RegisterCanvasLayout(Sub)category, plus its render context ──
local function createPanel(title, opts)
  opts = opts or {}
  local panel = CreateFrame("Frame", nil)
  panel.name = title
  panel:Hide()

  -- options-ui-§1: every frame handed to RegisterCanvasLayout(Sub)category carries all three
  -- framework entry points, so Blizzard's Settings window never calls into a missing method.
  -- `OnCommit` and `OnRefresh` are deliberately inert: every write already lands immediately via
  -- NS.Schema:Set / NS.Registry (nothing is staged to apply), and the panel's own OnShow handler is
  -- the single refresh path — a second, differently-ordered one would double the work and race the
  -- rebuilders. `OnDefault` starts inert and is pointed at the page's real defaults action by
  -- setDefaultsAction.
  panel.OnCommit  = function() end
  panel.OnRefresh = function() end
  panel.OnDefault = function() end

  buildHeader(panel, title, opts)

  local body = CreateFrame("Frame", nil, panel)
  body:SetPoint("TOPLEFT",     panel, "TOPLEFT",     0, -(HEADER_HEIGHT + 8))
  body:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)

  -- `refreshers` re-sync scalar widget VALUES in place (cheap; run on every OnShow). `rebuilders`
  -- tear down and recreate list rows (structural, expensive). Per options-ui-§11 a structural
  -- rebuild runs only on first paint, on an on-screen edit, or when `dirty` marks an off-screen
  -- change — never on every OnShow.
  return { panel = panel, body = body, scroll = nil,
           refreshers = {}, rebuilders = {}, dirty = false, lastGroup = nil }
end

-- Keep the settings-panel scrollbar ALWAYS visible — and inert when the page fits — so the reserved
-- right gutter, and therefore the body width, is identical across short and long subcategories
-- (options-ui-§10). AceGUI's stock FixScroll hides the bar and reclaims the 20px gutter when content
-- fits, which shifts the body width between pages and makes the panel jitter as you tab around.
-- Mirrors the stock FixScroll maths — note AceGUI's swapped names: `height` is the visible frame
-- height, `viewheight` the content height.
local function installAlwaysShownScrollbar(scroll)
  local bar = scroll.scrollbar
  if not (bar and scroll.scrollframe and scroll.content) then return end

  local function setInert(inert)
    if inert then
      if bar.Disable then bar:Disable() end
    else
      if bar.Enable then bar:Enable() end
    end
    local up, down = bar.ScrollUpButton, bar.ScrollDownButton
    if up and up.SetEnabled then up:SetEnabled(not inert) end
    if down and down.SetEnabled then down:SetEnabled(not inert) end
  end

  -- Wheel-scroll must be inert when the page fits. AceGUI's stock MoveScroll gates only on
  -- `scrollBarShown`, which this override keeps permanently true (to reserve the gutter) — so
  -- without this guard the wheel would still drift the parked thumb on a short page.
  local stockMoveScroll = scroll.MoveScroll
  scroll.MoveScroll = function(self, value)
    local height, viewheight = self.scrollframe:GetHeight(), self.content:GetHeight()
    if viewheight < height + 2 then return end
    -- The wheel path. MoveScroll is only ever called from the wheel handler, so this is a genuine
    -- user gesture and closing an open dropdown here can never fight a programmatic scroll.
    closeOpenDropdowns()
    return stockMoveScroll(self, value)
  end

  -- The drag path. Hooked on OnMouseDown rather than the slider's OnValueChanged, because
  -- OnValueChanged also fires from FixScroll's own SetValue during layout — closing there would
  -- shut a dropdown the instant it opened, since opening one triggers a relayout.
  if bar.HookScript then
    bar:HookScript("OnMouseDown", closeOpenDropdowns)
  end

  scroll.FixScroll = function(self)
    if self.updateLock then return end
    self.updateLock = true
    local status = self.status or self.localstatus
    local height, viewheight = self.scrollframe:GetHeight(), self.content:GetHeight()
    local offset = status.offset or 0
    -- Reserve the gutter and show the bar once (the stock "show" branch minus the auto-hide path).
    -- Once shown it stays shown, so the body never reflows between pages.
    if not self.scrollBarShown then
      self.scrollBarShown = true
      self.scrollbar:Show()
      self.scrollframe:SetPoint("BOTTOMRIGHT", -20, 0)
      if self.content.original_width then
        self.content.width = self.content.original_width - 20
      end
      self:DoLayout()
    end
    if viewheight < height + 2 then
      self.scrollbar:SetValue(0)   -- content fits: park the thumb and grey the bar out
      setInert(true)
    else
      setInert(false)
      local value = (offset / (viewheight - height) * 1000)
      if value > 1000 then value = 1000 end
      self.scrollbar:SetValue(value)
      self:SetScroll(value)
      if value < 1000 then
        self.content:ClearAllPoints()
        self.content:SetPoint("TOPLEFT", 0, offset)
        self.content:SetPoint("TOPRIGHT", 0, offset)
        status.offset = offset
      end
    end
    self.updateLock = nil
  end
end

local function ensureScroll(ctx)
  if ctx.scroll then return ctx.scroll end
  local scroll = AceGUI:Create("ScrollFrame")
  scroll:SetLayout("List")
  scroll.frame:SetParent(ctx.body)
  scroll.frame:ClearAllPoints()
  scroll.frame:SetPoint("TOPLEFT",     ctx.body, "TOPLEFT",      PADDING_X - 4, -8)
  scroll.frame:SetPoint("BOTTOMRIGHT", ctx.body, "BOTTOMRIGHT", -(PADDING_X + 12), 8)
  scroll.frame:Show()
  installAlwaysShownScrollbar(scroll)
  ctx.scroll = scroll
  return scroll
end

local function addSpacer(scroll, height)
  local sp = AceGUI:Create("SimpleGroup")
  sp:SetLayout(nil); sp:SetFullWidth(true); sp:SetHeight(height)
  scroll:AddChild(sp)
end

-- A section heading: a centred gold label flanked by dividers (options-ui-§7). The same widget the
-- landing page uses for "Slash Commands", so headings read identically everywhere.
local function section(ctx, label)
  local scroll = ensureScroll(ctx)
  if ctx.lastGroup ~= nil then addSpacer(scroll, SECTION_TOP_SPACER) end
  local h = AceGUI:Create("Heading")
  h:SetText(label); h:SetFullWidth(true); h:SetHeight(SECTION_HEADING_H)
  if h.label and h.label.SetFontObject and _G.GameFontNormalLarge then
    h.label:SetFontObject(_G.GameFontNormalLarge)
  end
  scroll:AddChild(h)
  addSpacer(scroll, SECTION_BOTTOM_SPACER)
  ctx.lastGroup = label
end

-- ── Widget makers ───────────────────────────────────────────────────────────────
local function applyWidth(w, rel)
  if rel then w:SetRelativeWidth(rel) else w:SetFullWidth(true) end
end

-- The single seam for a paired action button's width — insets to BUTTON_PAIR_REL so the right border
-- isn't shaved by the ScrollFrame clip. Never hand-set 0.5 on a paired button.
local function makePairButton(text, onClick)
  local btn = AceGUI:Create("Button")
  btn:SetText(text)
  btn:SetRelativeWidth(BUTTON_PAIR_REL)
  if onClick then btn:SetCallback("OnClick", onClick) end
  return btn
end

local function makeCheckbox(ctx, row, parent, rel)
  local cb = AceGUI:Create("CheckBox")
  cb:SetLabel(row.label); applyWidth(cb, rel)
  cb:SetCallback("OnValueChanged", function(_, _, v) NS.Schema:Set(row.path, v and true or false) end)
  attachTooltip(cb, row.label, row.tooltip)
  parent:AddChild(cb)
  ctx.refreshers[#ctx.refreshers + 1] =
    function() cb:SetValue(NS.Schema:Get(row.path) and true or false) end
  cb:SetValue(NS.Schema:Get(row.path) and true or false)
  return cb
end

local function makeDropdown(ctx, row, parent, rel)
  local dd = AceGUI:Create("Dropdown")
  trackDropdown(dd)
  dd:SetLabel(row.label); applyWidth(dd, rel)
  local list, order = {}, {}
  for i, opt in ipairs(row.options) do list[opt.value] = opt.label; order[i] = opt.value end
  dd:SetList(list, order)
  dd:SetCallback("OnValueChanged", function(_, _, key) NS.Schema:Set(row.path, key) end)
  attachTooltip(dd, row.label, row.tooltip)
  parent:AddChild(dd)
  ctx.refreshers[#ctx.refreshers + 1] = function() dd:SetValue(NS.Schema:Get(row.path)) end
  dd:SetValue(NS.Schema:Get(row.path))
  return dd
end

local function makeSlider(ctx, row, parent, rel)
  local s = AceGUI:Create("Slider")
  s:SetLabel(row.label)
  s:SetSliderValues(row.min or 0, row.max or 1, row.step or 0.05)
  applyWidth(s, rel)
  s:SetCallback("OnMouseUp", function(_, _, v) NS.Schema:Set(row.path, v) end)
  attachTooltip(s, row.label, row.tooltip)
  parent:AddChild(s)
  ctx.refreshers[#ctx.refreshers + 1] =
    function() s:SetValue(NS.Schema:Get(row.path) or row.default) end
  s:SetValue(NS.Schema:Get(row.path) or row.default)
  return s
end

-- ── Two-column schema render (options-ui-§6) ────────────────────────────────────
-- Rows pair into 50%/50% Flow lines. A `wide = true` row breaks onto its own full-width line; a
-- group change emits a section heading. `companions` optionally maps a row's path →
-- function(parentRow) that adds a widget into the SAME row, right of the field.
local function renderSchema(ctx, companions)
  local scroll = ensureScroll(ctx)
  local pendingRow

  local function flushRow()
    if pendingRow then
      scroll:AddChild(pendingRow); addSpacer(scroll, ROW_VSPACER); pendingRow = nil
    end
  end
  local function startRow()
    local r = AceGUI:Create("SimpleGroup"); r:SetLayout("Flow"); r:SetFullWidth(true); return r
  end

  for _, row in ipairs(NS.Schema.Schema) do
    if row.group ~= ctx.lastGroup then
      flushRow()
      section(ctx, row.group)
    end

    local companion = companions and companions[row.path]
    if row.wide then
      flushRow()
      local full = startRow()
      if row.widget == "Slider" then makeSlider(ctx, row, full, nil)
      elseif row.widget == "Dropdown" then makeDropdown(ctx, row, full, nil)
      else makeCheckbox(ctx, row, full, nil) end
      scroll:AddChild(full); addSpacer(scroll, ROW_VSPACER)
    else
      if not pendingRow then pendingRow = startRow() end
      if row.widget == "Slider" then makeSlider(ctx, row, pendingRow, 0.5)
      elseif row.widget == "Dropdown" then makeDropdown(ctx, row, pendingRow, 0.5)
      else makeCheckbox(ctx, row, pendingRow, 0.5) end
      if companion then
        companion(pendingRow)
        flushRow()
      elseif pendingRow.children and #pendingRow.children >= 2 then
        flushRow()
      end
    end
  end
  flushRow()
end

-- ── Panels subcategory ──────────────────────────────────────────────────────────
-- One editor block per panel, plus the create control. This is the structural page: its content
-- depends on how many panels exist, so it lives behind `rebuilders` and is repainted only when the
-- SET of panels changes (options-ui-§11), never on every OnShow.

local function safeRun(fn, tag)
  local ok, err = pcall(fn)
  if not ok and NS.State.debug and NS.Debug then
    NS.Debug("Panel", "%s failed: %s", tostring(tag), tostring(err))
  end
end

local function runRebuilders(ctx)
  for i, fn in ipairs(ctx.rebuilders) do safeRun(fn, "Panels rebuilder " .. i) end
  ctx.dirty = false
end

-- One panel's editor: a titled group holding its geometry, layer and colour fields. Every control
-- The panel currently being edited, as an id. The Panels page shows ONE editor at a time, chosen
-- from a dropdown: a page that stacked every panel's editor grew past a screen at three panels and
-- past a scrollbar's usefulness at ten, and rebuilding all of them on every create/delete is the
-- O(N) teardown options-ui-§11 exists to prevent. nil means "nothing selected yet".
local selectedID

-- ── Editor layout constants ─────────────────────────────────────────────────────
-- Vertical rhythm inside the panel editor. Named, never inlined (options-ui-§8), and deliberately
-- three distinct sizes so the spacing itself communicates structure: a big gap means "new part of
-- the page", a medium one "new group of settings", a small one "still the same thought".
local EDITOR_SELECT_GAP  = 20   -- panel dropdown → the editor box
local EDITOR_SECTION_GAP = 14   -- between subsections inside the editor
local EDITOR_ROW_GAP     = 6    -- between rows within one subsection
-- The height an AceGUI control's label row occupies (a labelled Dropdown is 40 tall, an unlabelled
-- one 26). A section heading is followed by a fixed gap, so a control with NO label starts 14px
-- higher than a labelled one and the heading above it looks tighter than every other heading on the
-- page. Adding this back before an unlabelled control makes the gaps read as equal.
local LABEL_ROW_H        = 14

-- ── Editor building blocks ──────────────────────────────────────────────────────
-- The editor emits into a List-layout container as a sequence of full-width ROWS, rather than
-- pouring every widget into one Flow group. A single Flow reflows controls of differing heights into
-- whatever gaps it can find — which is what made the first version look cluttered: a checkbox would
-- ride up beside a slider's label and two unrelated settings would end up sharing a line.
-- Explicit rows mean a row holds exactly what it is meant to and nothing drifts into it.
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

-- A LibSharedMedia picker for one of a panel's media fields.
local function makeMediaDropdown(row, rec, field, label, tooltip)
  local mediaType = C.PANEL_FIELD_MEDIA[field]
  local dd = AceGUI:Create(LSM_WIDGET[mediaType] or "Dropdown")
  trackDropdown(dd)
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
  return dd
end

-- A colour control plus its "use class colour" companion.
--
-- Driven off C.COLOR_FIELDS rather than written out per colour, so a colour added to the panel
-- record later gets its class-colour checkbox for free.
--
-- The picker stays ENABLED while the class colour is on, and this is a deliberate reversal. It used
-- to be greyed out on the reasoning that its RGB was being overridden — but a colour's ALPHA is not
-- overridden, it still decides how solid the result is, and the picker is the only control that sets
-- it. Disabling it therefore contradicted its own tooltip ("the opacity you picked still applies")
-- and left the user unable to fix a washed-out class-coloured border at all. The label says which
-- half is live instead.
local function makeColorPair(row, rec, field, label)
  local flag = C.COLOR_FIELDS[field]
  local usingClass = flag and rec[flag] and true or false

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
  -- callback reports the same values the colour callback already applied. So for the overwhelmingly
  -- common case of changing the colour WITHOUT touching the opacity slider, OnValueConfirmed never
  -- fires at all: the widget's swatch updated (it calls SetColor on itself first) while the value
  -- was never handed to the addon. That is exactly the shape of "the swatch is green but the panel
  -- is still black".
  --
  -- OnValueChanged fires while the picker is open, so binding it also gives a live preview as the
  -- user drags — which is what a colour picker should do anyway.
  picker:SetCallback("OnValueChanged", store)
  picker:SetCallback("OnValueConfirmed", store)
  attachTooltip(picker, label,
    "Sets the colour and its opacity. With Class colour ticked the colour part is overridden, "
    .. "but the opacity you set here still decides how solid the result is.")
  row:AddChild(picker)

  if not flag then return end

  local cb = AceGUI:Create("CheckBox")
  cb:SetLabel("Class colour")
  cb:SetRelativeWidth(0.5)
  cb:SetValue(usingClass)
  cb:SetCallback("OnValueChanged", function(_, _, v)
    NS.Registry:Set(rec.id, flag, v and true or false)
    picker:SetLabel(labelFor(v and true or false))
  end)
  attachTooltip(cb, "Class colour",
    "Use your class colour for " .. label:lower() .. ". The opacity from the colour picker still "
    .. "applies \226\128\148 a class colour at low opacity looks just as washed out as any other.")
  row:AddChild(cb)
end

-- The four edge checkboxes for the accent bar, as one quarter-width row.
--
-- A set of independent booleans rather than a dropdown, because the edges are not exclusive — "top
-- and left" is an ordinary choice, and a dropdown would have to enumerate all fifteen combinations
-- to offer it. Each tick writes the WHOLE set through Registry:Set, so the single write seam still
-- sees one complete value rather than four partial ones.
local function makeEdgeChecks(row, rec)
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
  end
end

-- One panel's editor. Every control writes through NS.Registry:Set, which is the same seam the CLI
-- and the drag handler use.
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
    s:SetSliderValues(minV, maxV, step or 1)
    s:SetRelativeWidth(0.5)
    s:SetValue(tonumber(rec[field]) or 0)
    s:SetCallback("OnMouseUp", function(_, _, v) NS.Registry:Set(rec.id, field, v) end)
    if tooltip then attachTooltip(s, label, tooltip) end
    row:AddChild(s)
    return s
  end

  local function tokenDropdown(row, label, field, tokens, tooltip)
    local dd = AceGUI:Create("Dropdown")
    trackDropdown(dd)
    dd:SetLabel(label)
    dd:SetRelativeWidth(0.5)
    local list, order = {}, {}
    for i, token in ipairs(tokens) do list[token] = token; order[i] = token end
    dd:SetList(list, order)
    dd:SetValue(rec[field])
    dd:SetCallback("OnValueChanged", function(_, _, key) NS.Registry:Set(rec.id, field, key) end)
    if tooltip then attachTooltip(dd, label, tooltip) end
    row:AddChild(dd)
    return dd
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
  nameBox:SetCallback("OnEnterPressed", function(widget, _, text)
    local ok, err = NS.Registry:Rename(rec.id, text)
    if not ok then
      print("error: " .. tostring(err))
      widget:SetText(rec.name)   -- put the rejected edit back rather than leaving a lie on screen
      return
    end
    -- Renaming changes the frame name and the selector entry, so the page is rebuilt rather than
    -- patched in two places.
    ctx.dirty = true
    if ctx.panel:IsShown() then runRebuilders(ctx) end
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
  for _, other in ipairs(NS.Registry:All()) do
    if other.id ~= rec.id then
      others[other.id] = other.name
      order[#order + 1] = other.id
    end
  end

  local copyFrom = AceGUI:Create("Dropdown")
  trackDropdown(copyFrom)
  copyFrom:SetLabel("Copy settings from panel")
  copyFrom:SetRelativeWidth(0.5)
  copyFrom:SetList(others, order)
  -- Deliberately valueless: this is an ACTION, not a stored setting. Showing a "current" entry would
  -- imply an ongoing link between the two panels, when the copy is a one-off.
  copyFrom:SetValue(nil)
  if #order == 0 then
    copyFrom:SetDisabled(true)
  end
  copyFrom:SetCallback("OnValueChanged", function(widget, _, sourceID)
    -- On success the second return is the SOURCE's name, not an error.
    local ok, result = NS.Registry:CopyFrom(rec.id, sourceID)
    widget:SetValue(nil)   -- snap back: nothing is selected, something was done
    if not ok then print("error: " .. tostring(result)); return end
    print(("copied settings from '%s'"):format(tostring(result)))
    -- Every control in this editor now holds a stale value.
    ctx.dirty = true
    if ctx.panel:IsShown() then runRebuilders(ctx) end
  end)
  attachTooltip(copyFrom, "Copy settings from panel",
    #order == 0
      and "Make another panel first, then you can copy its settings onto this one."
      or ("Take on another panel's appearance \226\128\148 size, textures, colours, border and "
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

  editorSpacer(group, EDITOR_ROW_GAP)
  local actions = editorRow(group)

  local resetBtn = makePairButton("Reset", function()
    local ok, err = NS.Registry:Reset(rec.id)
    if not ok then print("error: " .. tostring(err)); return end
    -- Every widget in this editor now holds a stale value, so the page is rebuilt rather than each
    -- control being poked individually.
    ctx.dirty = true
    if ctx.panel:IsShown() then runRebuilders(ctx) end
  end)
  attachTooltip(resetBtn, "Reset",
    "Put this panel back to how a new one starts \226\128\148 size, position, textures, colours and "
    .. "all. Its name is kept, so anything anchored to it stays anchored.")
  actions:AddChild(resetBtn)

  local deleteBtn = makePairButton("Delete", function()
    NS.Registry:Delete(rec.id)
    selectedID = nil
    ctx.dirty = true
    if ctx.panel:IsShown() then runRebuilders(ctx) end
  end)
  attachTooltip(deleteBtn, "Delete", "Remove this panel. This cannot be undone.")
  actions:AddChild(deleteBtn)

  -- ── Position and size ──
  editorHeading(group, "Position and size")

  local sizeRow = editorRow(group)
  numberField(sizeRow, "Width", "width", C.MIN_SIZE, 1200)
  numberField(sizeRow, "Height", "height", C.MIN_SIZE, 1200)

  editorSpacer(group, EDITOR_ROW_GAP)
  local offsetRow = editorRow(group)
  numberField(offsetRow, "X offset", "x", -2000, 2000)
  numberField(offsetRow, "Y offset", "y", -2000, 2000)

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
  makeMediaDropdown(bgRow, rec, "bgTexture", "Background texture",
    "The texture the panel is filled with. 'Solid' is a flat colour; 'None' draws no fill.")

  editorSpacer(group, EDITOR_ROW_GAP)
  local bgColorRow = editorRow(group)
  -- The fill's own opacity lives in this colour's alpha. Panel opacity (under Visibility) is a
  -- separate, panel-wide multiplier — see the note there.
  makeColorPair(bgColorRow, rec, "bgColor", "Background colour")

  -- ── Border ──
  editorHeading(group, "Border")

  local borderRow = editorRow(group)
  makeMediaDropdown(borderRow, rec, "borderTexture", "Border texture",
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
  makeColorPair(borderColorRow, rec, "borderColor", "Border colour")

  -- ── Accent bar ──
  editorHeading(group, "Accent bar")

  local accentRow = editorRow(group)
  local accentOn = AceGUI:Create("CheckBox")
  accentOn:SetLabel("Enable accent bar")
  accentOn:SetRelativeWidth(0.5)
  accentOn:SetValue(rec.accentEnabled and true or false)
  accentOn:SetCallback("OnValueChanged", function(_, _, v)
    NS.Registry:Set(rec.id, "accentEnabled", v and true or false)
  end)
  attachTooltip(accentOn, "Enable accent bar",
    "Draw a thin coloured strip along the panel's edges, in the style of BenikUI's panels. "
    .. "Off by default.")
  accentRow:AddChild(accentOn)

  makeMediaDropdown(accentRow, rec, "accentTexture", "Accent bar texture",
    "The texture the accent bar is drawn with, from your LibSharedMedia status-bar textures. "
    .. "'Solid' is a flat colour.")

  editorSpacer(group, EDITOR_ROW_GAP)
  local edgeLabel = AceGUI:Create("Label")
  edgeLabel:SetFullWidth(true)
  edgeLabel:SetText("|cffffd100Edges|r")
  group:AddChild(edgeLabel)
  local edgeRow = editorRow(group)
  makeEdgeChecks(edgeRow, rec)

  editorSpacer(group, EDITOR_ROW_GAP)
  local accentSizeRow = editorRow(group)
  numberField(accentSizeRow, "Accent bar thickness", "accentThickness",
    C.MIN_ACCENT_THICKNESS, C.MAX_ACCENT_THICKNESS, 1,
    "How thick the accent bar is, in screen units.")
  numberField(accentSizeRow, "Accent bar offset", "accentOffset",
    C.MIN_ACCENT_OFFSET, C.MAX_ACCENT_OFFSET, 1,
    "How far the bar sits from the panel's edge. Positive detaches it from the panel, "
    .. "which is the look this is modelled on; 0 sits flush; negative overlaps the panel.")

  editorSpacer(group, EDITOR_ROW_GAP)
  local accentColorRow = editorRow(group)
  makeColorPair(accentColorRow, rec, "accentColor", "Accent bar colour")

  -- The bar's own border. Same four controls as the panel's, in the same order, so the two read
  -- alike — the only difference is what they outline.
  editorSpacer(group, EDITOR_ROW_GAP)
  local accentBorderRow = editorRow(group)
  makeMediaDropdown(accentBorderRow, rec, "accentBorderTexture", "Accent bar border texture",
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
  makeColorPair(accentBorderColorRow, rec, "accentBorderColor", "Accent bar border colour")

  -- ── Visibility ──
  editorHeading(group, "Visibility")

  -- Panel opacity gets its own row: it applies whatever else is set, whereas the two controls below
  -- are a pair that only mean anything together. Putting the checkbox up here beside it implied the
  -- opposite grouping.
  --
  -- "Panel opacity", not "Background opacity". It is the FRAME's alpha, so it fades the border as
  -- well as the fill, and it multiplies with the alpha already carried by each colour. It is also
  -- the value the mouseover fade rises to — which is why it cannot simply be folded into the
  -- background colour's alpha, however much the two look alike.
  local opacityRow = editorRow(group)
  numberField(opacityRow, "Panel opacity", "alpha", 0, 1, 0.05,
    "How visible the whole panel is \226\128\148 background and border together. Multiplies with "
    .. "the opacity set in each colour. This is also the opacity a mouseover panel fades up to.")

  editorSpacer(group, EDITOR_ROW_GAP)
  local mouseoverRow = editorRow(group)
  numberField(mouseoverRow, "Faded opacity", "mouseoverAlpha", 0, 1, 0.05,
    "How visible the panel is while the cursor is elsewhere. 0 hides it completely. "
    .. "Only used when 'Show on mouseover only' is ticked.")

  local mouseover = AceGUI:Create("CheckBox")
  mouseover:SetLabel("Show on mouseover only")
  mouseover:SetRelativeWidth(0.5)
  mouseover:SetValue(rec.mouseover and true or false)
  mouseover:SetCallback("OnValueChanged", function(_, _, v)
    NS.Registry:Set(rec.id, "mouseover", v and true or false)
  end)
  attachTooltip(mouseover, "Show on mouseover only",
    "Keep the panel faded until the cursor is over it. The panel still never takes your clicks.")
  mouseoverRow:AddChild(mouseover)

  -- Delete and Reset live at the TOP of the editor, beside Enabled and Unlock — see the note there.
  editorSpacer(group, EDITOR_ROW_GAP)

  parent:AddChild(group)
end

local function buildPanelsPage(ctx)
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
    local rec, err = NS.Registry:New(text)
    if not rec then
      print("error: " .. tostring(err))
      return   -- leave the text in place so the user can correct it rather than retype it
    end
    widget:SetText("")
    selectedID = rec.id            -- jump straight to the new panel's editor
    ctx.dirty = true
    if ctx.panel:IsShown() then runRebuilders(ctx) end
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
    forgetDropdowns()
    selectRow:ReleaseChildren()
    listGroup:ReleaseChildren()

    local records = NS.Registry:All()
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
    trackDropdown(dd)
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

  -- Repaint when the SET of panels changes. Scoped to the on-screen page (options-ui-§11): an
  -- off-screen page is only flagged dirty, so a `/pm new` while the options window is closed costs
  -- nothing and is picked up by the next OnShow.
  if not P.__evPanels then
    local ev = NS.NewBusTarget()
    if ev then
      ev:RegisterMessage(NS.Registry.MSG_PANELS, function()
        if ctx.panel:IsShown() then runRebuilders(ctx) else ctx.dirty = true end
      end)
      P.__evPanels = ev
    end
  end
end

-- ── Landing page: logo + tagline + slash-command list (options-ui-§5) ───────────
local function buildMainContent(ctx)
  local scroll = ensureScroll(ctx)

  local logoGroup = AceGUI:Create("SimpleGroup")
  logoGroup:SetLayout(nil); logoGroup:SetFullWidth(true); logoGroup:SetHeight(LOGO_SIZE)
  local tex = logoGroup.frame:CreateTexture(nil, "ARTWORK")
  tex:SetTexture(C.LOGO_PATH)
  tex:SetSize(LOGO_SIZE, LOGO_SIZE)
  tex:SetPoint("TOPLEFT", logoGroup.frame, "TOPLEFT", 0, 0)
  scroll:AddChild(logoGroup)
  addSpacer(scroll, 8)

  local desc = AceGUI:Create("Label")
  desc:SetFullWidth(true); desc:SetText(ADDON_TAGLINE)
  if desc.label and desc.label.SetFontObject and _G.GameFontHighlight then
    desc.label:SetFontObject(_G.GameFontHighlight)
  end
  scroll:AddChild(desc)
  addSpacer(scroll, 12)

  local heading = AceGUI:Create("Heading")
  heading:SetFullWidth(true); heading:SetHeight(SECTION_HEADING_H); heading:SetText("Slash Commands")
  if heading.label and heading.label.SetFontObject and _G.GameFontNormalLarge then
    heading.label:SetFontObject(_G.GameFontNormalLarge)
  end
  scroll:AddChild(heading)
  addSpacer(scroll, 6)

  -- Generated from NS.COMMANDS, so this list stays in lockstep with `/pm help` (options-ui-§5).
  for _, cmd in ipairs(NS.COMMANDS or {}) do
    local labelRow = AceGUI:Create("Label")
    labelRow:SetFullWidth(true)
    labelRow:SetText(("|cffffff00/pm %s|r  |cffffffff\226\128\148|r  %s"):format(cmd.name, cmd.desc))
    scroll:AddChild(labelRow)
  end
end

-- ── Refresh / Defaults ─────────────────────────────────────────────────────────

-- Scalar re-sync only: run each rendered widget's updater closure. Structural rebuilds are the
-- rebuilders' job and are gated separately (options-ui-§11). A hidden panel is not refreshed — its
-- widget values are re-synced by its own OnShow anyway.
function P:Refresh()
  local ctx = P.general
  if not (ctx and ctx.refreshers and ctx.panel and ctx.panel:IsShown()) then return end
  for i, fn in ipairs(ctx.refreshers) do safeRun(fn, "General refresher " .. i) end
end

function P:RestoreDefaults()
  if NS.Slash and NS.Slash.CliResetAll then NS.Slash:CliResetAll() end
  P:Refresh()
end

-- ── Registration ───────────────────────────────────────────────────────────────
function P:Register()
  if registered then return end
  if not (AceGUI and Settings and Settings.RegisterCanvasLayoutCategory
          and Settings.RegisterCanvasLayoutSubcategory) then return end
  registered = true

  -- Parent category = the landing page.
  local mainCtx = createPanel(ADDON_TITLE, { isMain = true })
  local mainRendered = false
  mainCtx.panel:SetScript("OnShow", function()
    if mainRendered then return end
    mainRendered = true
    buildMainContent(mainCtx)
    if mainCtx.scroll and mainCtx.scroll.DoLayout then mainCtx.scroll:DoLayout() end
  end)
  local mainCategory = Settings.RegisterCanvasLayoutCategory(mainCtx.panel, ADDON_TITLE)
  Settings.RegisterAddOnCategory(mainCategory)
  mainCategoryID = mainCategory and mainCategory.GetID and mainCategory:GetID()

  -- General subcategory = the addon's own settings.
  local ctx = createPanel("General", { defaultsButton = true })
  P.general = ctx
  -- Non-destructive: this resets settings only and never touches the user's panels, so it is safe
  -- behind Blizzard's un-gated footer control. Deleting panels stays behind the confirm-gated
  -- KA0S_PANELMASTER_DELETEALL popup.
  setDefaultsAction(ctx.panel, function() P:RestoreDefaults() end)
  local rendered = false
  ctx.panel:SetScript("OnShow", function()
    ensureDefaultsButton(ctx.panel)
    if not rendered then
      rendered = true
      renderSchema(ctx, {
        -- "Recover panels" sits to the right of Grid size: it is the other thing you reach for when
        -- a layout has gone wrong.
        ["settings.gridSize"] = function(parentRow)
          parentRow:AddChild(makePairButton("Recover panels", function()
            if NS.Slash then NS.Slash:CliRecover() end
          end))
        end,
      })
      if ctx.scroll and ctx.scroll.DoLayout then ctx.scroll:DoLayout() end
    end
    P:Refresh()
  end)
  Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, "General")

  -- Panels subcategory = create, edit and delete the panels themselves.
  local pctx = createPanel("Panels", { defaultsButton = true })
  P.panels = pctx
  -- Defaults here = delete every panel, which IS the stock state of this page (a fresh install has
  -- none). Destructive, so it is confirm-gated.
  setDefaultsAction(pctx.panel, function()
    if type(StaticPopup_Show) == "function" then
      StaticPopup_Show("KA0S_PANELMASTER_DELETEALL")
    else
      NS.Registry:DeleteAll()
    end
  end)
  local pRendered = false
  pctx.panel:SetScript("OnShow", function()
    ensureDefaultsButton(pctx.panel)
    if not pRendered then
      pRendered = true
      buildPanelsPage(pctx)
      runRebuilders(pctx)      -- first paint of the editor list
    elseif pctx.dirty then
      runRebuilders(pctx)      -- panels changed while hidden → repaint once (options-ui-§11)
    end
  end)
  Settings.RegisterCanvasLayoutSubcategory(mainCategory, pctx.panel, "Panels")

  -- Profiles subcategory = AceDB's own profile management, rendered into our canvas.
  --
  -- This is the ONE place AceConfigDialog is permitted (anti-patterns forbids it for content, and
  -- explicitly carves out Profiles). AceDBOptions hands back a complete, correct options table for
  -- create / switch / copy / reset / delete plus the per-character/class/realm/faction scopes —
  -- reimplementing that by hand in AceGUI would be a large pile of code whose only distinction would
  -- be its own bugs.
  --
  -- Guarded rather than assumed: both libs are OptionalDeps, and their absence means no Profiles
  -- page rather than a broken one (library-stack-§6).
  local AceDBOptions    = LibStub and LibStub("AceDBOptions-3.0", true)
  local AceConfig       = LibStub and LibStub("AceConfig-3.0", true)
  local AceConfigDialog = LibStub and LibStub("AceConfigDialog-3.0", true)
  if AceDBOptions and AceConfig and AceConfigDialog and NS.db then
    AceConfig:RegisterOptionsTable("PanelMaster-Profiles", AceDBOptions:GetOptionsTable(NS.db))

    -- No Defaults button: profile management carries its own destructive controls, and a second
    -- "reset" meaning something different from the page's own Reset Profile would be a trap.
    local prctx = createPanel("Profiles", {})

    -- AceConfigDialog renders into any AceGUI container, so it is pointed at a group parented to
    -- our body — the widgets land inside the canvas rather than opening their own window.
    -- Guarded like every other AceGUI create on this page: a container that failed to build must
    -- leave the page inert, not raise during OnInitialize and take the whole addon's load with it.
    local container = AceGUI:Create("SimpleGroup")
    if container and container.frame then
      container:SetLayout("Fill")
      container.frame:SetParent(prctx.body)
      container.frame:ClearAllPoints()
      container.frame:SetPoint("TOPLEFT",     prctx.body, "TOPLEFT",      PADDING_X, -8)
      container.frame:SetPoint("BOTTOMRIGHT", prctx.body, "BOTTOMRIGHT", -PADDING_X, 8)
    end

    -- The OnShow is installed unconditionally, so this page keeps the same lazy-build contract as
    -- every other one (options-ui-§1) even if the container failed to build. Re-opened on every
    -- show, not just the first: after a profile switch the whole options tree is stale, and
    -- AceConfigDialog reuses its existing widget tree, so this is cheap.
    prctx.panel:SetScript("OnShow", function()
      if not (container and container.frame) then return end
      AceConfigDialog:Open("PanelMaster-Profiles", container)
    end)
    Settings.RegisterCanvasLayoutSubcategory(mainCategory, prctx.panel, "Profiles")
    P.profiles = prctx
  end
end

function P:Open()
  -- options-ui-§2: REFUSE in combat — Blizzard's category-switch is protected, and calling it under
  -- lockdown taints the panel for the rest of the session. A grey notice and an early return; never
  -- defer-and-replay on PLAYER_REGEN_ENABLED (a panel that pops itself open the instant combat drops
  -- steals focus during post-pull recovery). \226\128\148 = em-dash.
  if InCombatLockdown and InCombatLockdown() then
    print("|cff808080cannot open settings during combat \226\128\148 "
      .. "Blizzard's category-switch is protected|r")
    return
  end
  if Settings and Settings.OpenToCategory and mainCategoryID then
    Settings.OpenToCategory(mainCategoryID)
  end
end
