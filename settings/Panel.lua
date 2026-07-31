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
--
-- This file is the page CHROME — header, scroll frame, tooltip, schema renderer, landing page and
-- registration. The Panels page's body (the create box, the selector and one panel's editor) is
-- settings/PanelEditor.lua, a sibling peeled out of here once this file outgrew a single screenful
-- of responsibilities (layout-§1).

local ADDON_TITLE   = "Ka0s Panel Master"
-- The canonical one-line description of the addon: this is the sentence a player reads on the
-- landing page, so it is the one the other two copies quote. The TOC's `## Notes` carries a
-- shortened form of it (the client's addon list has room for one short line) and the README's
-- opening line quotes it whole.
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
--
-- The registry lives on the RENDER CONTEXT, one per page, not at file level. A single shared list
-- was a bug in both directions: the Panels page's rebuild emptied it wholesale, so the General
-- page's still-live dropdown stopped closing on scroll, while widgets released by an earlier build
-- lingered in it and were handed to `pullout:Close()` after release. A page tracks and forgets its
-- own, because a page is exactly the unit that releases them.
local function trackDropdown(ctx, widget)
  ctx.dropdowns[#ctx.dropdowns + 1] = widget
end

-- Test seams. The headless harness stubs AceGUI out, so no real widget is ever built — these let the
-- close routine be exercised against hand-built stand-ins, which is how the type-dispatch bug below
-- is pinned. Each takes the context whose dropdowns it is talking about.
P.__registerDropdownForTest = trackDropdown
function P.__openDropdownCount(ctx) return #ctx.dropdowns end

-- Forget widgets released by a rebuild. Called at the top of every rebuild rather than on release,
-- because AceGUI has no per-widget "you were released" callback we can hook from here.
local function forgetDropdowns(ctx)
  for i = #ctx.dropdowns, 1, -1 do ctx.dropdowns[i] = nil end
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
function P.__closeOpenDropdowns(ctx)
  local AGSMW
  for _, widget in ipairs(ctx.dropdowns) do
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
  -- `dropdowns` is this page's own open-dropdown registry — see the note at the top of the file.
  return { panel = panel, body = body, scroll = nil, dropdowns = {},
           refreshers = {}, rebuilders = {}, dirty = false, lastGroup = nil }
end

-- Keep the settings-panel scrollbar ALWAYS visible — and inert when the page fits — so the reserved
-- right gutter, and therefore the body width, is identical across short and long subcategories
-- (options-ui-§10). AceGUI's stock FixScroll hides the bar and reclaims the 20px gutter when content
-- fits, which shifts the body width between pages and makes the panel jitter as you tab around.
-- Mirrors the stock FixScroll maths — note AceGUI's swapped names: `height` is the visible frame
-- height, `viewheight` the content height.
local function installAlwaysShownScrollbar(ctx, scroll)
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
    closeOpenDropdowns(ctx)
    return stockMoveScroll(self, value)
  end

  -- The drag path. Hooked on OnMouseDown rather than the slider's OnValueChanged, because
  -- OnValueChanged also fires from FixScroll's own SetValue during layout — closing there would
  -- shut a dropdown the instant it opened, since opening one triggers a relayout.
  if bar.HookScript then
    bar:HookScript("OnMouseDown", function() closeOpenDropdowns(ctx) end)
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
      self.scrollbar:SetValue(0)   -- content fits: park the thumb and gray the bar out
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
  installAlwaysShownScrollbar(ctx, scroll)
  ctx.scroll = scroll
  return scroll
end

local function addSpacer(scroll, height)
  local sp = AceGUI:Create("SimpleGroup")
  sp:SetLayout(nil); sp:SetFullWidth(true); sp:SetHeight(height)
  scroll:AddChild(sp)
end

-- A section heading: a centered gold label flanked by dividers (options-ui-§7). The same widget the
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
  trackDropdown(ctx, dd)
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

-- Run one page closure, and let a broken one break only itself. A refresher or rebuilder that
-- raised used to abort every closure queued behind it, leaving half the page showing stale values.
local function safeRun(fn, tag)
  local ok, err = pcall(fn)
  if not ok then
    NS.Debug("Panel", "%s failed: %s", tostring(tag), tostring(err))
  end
end

-- ── What settings/PanelEditor.lua draws with ────────────────────────────────────
-- The panel editor was peeled into a sibling file (C-07), but it is still drawn INTO this page: it
-- emits into this file's scroll frame, under this file's section headings, with this file's tooltip
-- attacher, paired-button width and open-dropdown registry. Those helpers are published here rather
-- than duplicated there, so the two halves cannot drift into two different looks.
--
-- Internal (`__`), not API: nothing outside settings/ may reach for these.
P.__ui = {
  attachTooltip   = attachTooltip,
  addSpacer       = addSpacer,
  section         = section,
  ensureScroll    = ensureScroll,
  makePairButton  = makePairButton,
  trackDropdown   = trackDropdown,
  forgetDropdowns = forgetDropdowns,
  safeRun         = safeRun,
  LSM_WIDGET      = LSM_WIDGET,
  ROW_VSPACER     = ROW_VSPACER,
}

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

-- The same contract for the Panels page's editor: run each control's updater against the live
-- record, and never rebuild. A hidden page is skipped — its `dirty` flag already has it queued for a
-- rebuild on the next OnShow.
function P:RefreshPanels(ctx)
  ctx = ctx or P.panels
  if not (ctx and ctx.refreshers) then return end
  for i, fn in ipairs(ctx.refreshers) do safeRun(fn, "Panel refresher " .. i) end
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

  -- Panels subcategory = create, edit and delete the panels themselves. The page is registered and
  -- laid out here; its BODY is settings/PanelEditor.lua's, which this file only ever drives through
  -- the three calls below.
  local pctx = createPanel("Panels", { defaultsButton = true })
  P.panels = pctx
  NS.PanelEditor:WireBus(pctx)
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
      NS.PanelEditor:BuildPage(pctx)
      NS.PanelEditor:Rebuild(pctx)   -- first paint of the editor list
    elseif pctx.dirty then
      NS.PanelEditor:Rebuild(pctx)   -- panels changed while hidden → repaint once (options-ui-§11)
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
  -- lockdown taints the panel for the rest of the session. A gray notice and an early return; never
  -- defer-and-replay on PLAYER_REGEN_ENABLED (a panel that pops itself open the instant combat drops
  -- steals focus during post-pull recovery). \226\128\148 = em-dash.
  if InCombatLockdown and InCombatLockdown() then
    print("|cff808080cannot open settings during combat \226\128\148 "
      .. "Blizzard's category-switch is protected|r")
    return
  end
  -- No category means BOTH eager registration attempts found no Settings API — OnInitialize's and
  -- the PLAYER_LOGIN retry's (core/PanelMaster.lua). Say so: a command that returns silently reads
  -- as broken, where a named prerequisite reads as a missing one.
  if not (Settings and Settings.OpenToCategory and mainCategoryID) then
    print("settings are not available on this client, so there is no page to open")
    return
  end
  Settings.OpenToCategory(mainCategoryID)
end

-- Test seam. mainCategoryID is a file-local written only by Register, so the branch above is
-- unreachable in a suite where registration succeeded — this drives it directly.
function P.__setCategoryIDForTest(id) mainCategoryID = id end
