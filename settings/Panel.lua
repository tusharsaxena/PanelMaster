local addonName, NS = ...   -- luacheck: ignore addonName
NS.Panel = NS.Panel or {}
local P = NS.Panel
local C = NS.Constants
local print = NS.Print   -- secret-safe, [PM]-prefixed shared printer (events-frames-taint-§8)

-- The LibKa0s-Options-1.0 instance, built in settings/OptionsSetup.lua, which the TOC loads
-- immediately before this file. It IS the helpers table rather than a wrapper around one, so a page
-- builder here and a widget maker inside the library see the same object (options-ui-§1).
local O = NS.Helpers

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

-- The brand ("Ka0s Panel Master") is no longer restated here: it is the LibKa0s-Options-1.0
-- descriptor's `parentTitle` in settings/OptionsSetup.lua, which the library uses for the main
-- page and for every sub-page breadcrumb. One definition rather than two that can disagree.
-- The canonical one-line description of the addon: this is the sentence a player reads on the
-- landing page, so it is the one the other two copies quote. The TOC's `## Notes` carries a
-- shortened form of it (the client's addon list has room for one short line) and the README's
-- opening line quotes it whole.
local ADDON_TAGLINE =
  "Draws plain backdrop panels behind your UI, so a screen full of separate frames reads as a few "
  .. "deliberate groups."

-- Layout constants. The Ka0s values (options-ui-§8) now live in ONE place — LibKa0s-Options-1.0's
-- lib.LAYOUT, re-exported on the instance — rather than being restated here, so this page's spacing
-- and the flow engine's cannot drift apart. PADDING_X, HEADER_TOP, HEADER_HEIGHT and DEFAULTS_W are
-- entirely the library's now; the three below are read by this file or by settings/PanelEditor.lua.
local ROW_VSPACER       = O.ROW_VSPACER
local SECTION_HEADING_H = O.SECTION_HEADING_H
local BUTTON_PAIR_REL   = O.BUTTON_PAIR_REL
local PADDING_X         = 16   -- still needed for the Profiles page's hand-anchored container
local LOGO_SIZE         = 300  -- landing-page logo display size, this page's own

-- `mainCategoryID` is gone: the library owns the category handle and `O.OpenOptionsPanel` is the
-- only thing that needs it. `registered` stays, because P:Open explains an absent Settings API in
-- this addon's own words and the library simply returns.
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

-- ── What this file still owns, and what the library now draws ─────────────────
--
-- Deleted from here and taken from LibKa0s-Options-1.0 outright, because every one of them was a
-- hand-transcribed copy of the same thing every Ka0s addon has:
--
--   attachTooltip            -> O.AttachTooltip
--   addSpacer                -> O.AddSpacer
--   section                  -> O.Section
--   installAlwaysShownScrollbar -> O.PatchAlwaysShowScrollbar, called from O.EnsureScroll
--   ensureScroll             -> O.EnsureScroll (wrapped below, for the dropdown-close hooks)
--   createPanel / buildHeader / setDefaultsAction -> O.CreatePanel, which also stamps the Blizzard
--                               canvas contract (OnCommit / OnRefresh inert, OnDefault FORWARDING
--                               to the page's defaultsOnClick so the Settings window's footer
--                               control and the header Defaults button stay one implementation)
--   ensureDefaultsButton     -> O.EnsureDefaultsButton
--   makeCheckbox / makeDropdown / makeSlider -> O.RenderField, dispatching on row.type
--   renderSchema(ctx, companions) -> O.RenderRows(ctx, rows, afterGroup, pairWith)
--
-- ADAPTER 1 — the open-dropdown registry. The library's widget makers know nothing about it, and
-- they should not: it is this addon's own invention, born of a real bug, and no other host has one.
-- O.RenderField is resolved from the instance TABLE at call time by both RenderRows and RenderGrid,
-- so wrapping it here reaches every dropdown the library builds without the library changing.
local baseRenderField = O.RenderField
if baseRenderField then
  function O.RenderField(ctx, row, parent, relWidth)
    local widget = baseRenderField(ctx, row, parent, relWidth)
    -- Only a dropdown needs tracking, and only on a ctx that has a registry — the library's own
    -- suites build ctxs that do not.
    if widget and ctx.dropdowns and (widget.type == "Dropdown" or IS_LSM_WIDGET[widget.type]) then
      trackDropdown(ctx, widget)
    end
    return widget
  end
end

-- ADAPTER 2 — the scroll frame. The library's patch owns the always-shown scrollbar and the
-- inert-when-it-fits behavior; what it has no notion of is closing an open dropdown when the user
-- scrolls. Layered ON TOP of the library's MoveScroll rather than replacing it, so the gating stays
-- the library's and only the extra gesture is ours.
--
-- Wrapped ON THE INSTANCE, exactly like RenderField above, and for the same reason: O.RenderRows
-- calls O.EnsureScroll itself, so a plain host-side helper beside it would be bypassed by every page
-- the flow engine draws. A test caught precisely that — the hooks were installed on the landing page
-- and on the panel editor, and missing from the one page with a dropdown on it.
local baseEnsureScroll = O.EnsureScroll
function O.EnsureScroll(ctx)
  local scroll = baseEnsureScroll(ctx)
  if not scroll or scroll.__pmDropdownHooks then return scroll end
  scroll.__pmDropdownHooks = true

  -- The wheel path. MoveScroll is only ever called from the wheel handler, so this is a genuine
  -- user gesture and closing a dropdown here can never fight a programmatic scroll.
  local libMoveScroll = scroll.MoveScroll
  scroll.MoveScroll = function(self, value)
    closeOpenDropdowns(ctx)
    if libMoveScroll then return libMoveScroll(self, value) end
  end

  -- The drag path. Hooked on OnMouseDown rather than the slider's OnValueChanged, because
  -- OnValueChanged also fires from FixScroll's own SetValue during layout — closing there would
  -- shut a dropdown the instant it opened, since opening one triggers a relayout.
  local bar = scroll.scrollbar
  if bar and bar.HookScript then
    bar:HookScript("OnMouseDown", function() closeOpenDropdowns(ctx) end)
  end
  return scroll
end
local ensureScroll = O.EnsureScroll

-- ── Widget makers this file still owns ──────────────────────────────────────────

-- The single seam for a paired action button's width — insets to BUTTON_PAIR_REL so the right
-- border isn't shaved by the ScrollFrame clip. Never hand-set 0.5 on a paired button.
--
-- NOT O.InlineButtonPair, which builds its own Flow row and adds it to the scroll: this addon's
-- paired buttons are added into a row somebody ELSE is building — the companion beside Grid size,
-- and the Reset/Delete pair inside the panel editor's own row — so a maker that owned the row would
-- have nowhere to put them.
local function makePairButton(text, onClick)
  local btn = O.AceGUI:Create("Button")
  btn:SetText(text)
  btn:SetRelativeWidth(BUTTON_PAIR_REL)
  if onClick then btn:SetCallback("OnClick", onClick) end
  return btn
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
-- Six of the ten are now LibKa0s-Options-1.0's; the table keeps its shape and its names so
-- settings/PanelEditor.lua is untouched by the adoption. It binds these LAZILY inside its own
-- rebuild, so nothing here pins the TOC order.
P.__ui = {
  attachTooltip   = O.AttachTooltip,   -- library
  addSpacer       = O.AddSpacer,       -- library
  section         = O.Section,         -- library
  ROW_VSPACER     = ROW_VSPACER,       -- library (lib.LAYOUT)
  ensureScroll    = ensureScroll,      -- library, plus this file's dropdown-close layer
  makePairButton  = makePairButton,    -- host: adds INTO a caller's row, which O.InlineButtonPair
                                       --       cannot do — it builds and owns the row itself
  BUTTON_PAIR_REL = BUTTON_PAIR_REL,   -- library: the same inset, for a NON-button widget that has
                                       --       to line up with one (the editor's path box)
  trackDropdown   = trackDropdown,     -- host: the open-dropdown registry is this addon's own
  forgetDropdowns = forgetDropdowns,   -- host: same
  safeRun         = safeRun,           -- host: the library pcalls its own closures, not the
                                       --       editor's rebuilders
  LSM_WIDGET      = LSM_WIDGET,        -- host: the per-panel media pickers are PanelEditor's, drawn
                                       --       from NS.Registry rather than from a schema row
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
  O.AddSpacer(scroll, 8)

  local desc = AceGUI:Create("Label")
  desc:SetFullWidth(true); desc:SetText(ADDON_TAGLINE)
  if desc.label and desc.label.SetFontObject and _G.GameFontHighlight then
    desc.label:SetFontObject(_G.GameFontHighlight)
  end
  scroll:AddChild(desc)
  O.AddSpacer(scroll, 12)

  local heading = AceGUI:Create("Heading")
  heading:SetFullWidth(true); heading:SetHeight(SECTION_HEADING_H); heading:SetText("Slash Commands")
  if heading.label and heading.label.SetFontObject and _G.GameFontNormalLarge then
    heading.label:SetFontObject(_G.GameFontNormalLarge)
  end
  scroll:AddChild(heading)
  O.AddSpacer(scroll, 6)

  -- Rendered through the ONE command-row formatter, LibKa0s-Slash-1.0's, rather than this file's own
  -- (options-ui-§5). This page used to carry a SECOND formatter for the same NS.COMMANDS data — a
  -- chat one in settings/Slash.lua and this one here — which had already drifted apart: this one put
  -- double spaces either side of the em dash, wrapped the dash itself in white and left the
  -- description bare. `Sl:LandingRows()` returns exactly the rows `Sl:HelpRows()` does, minus the
  -- two-space chat indent, so the two surfaces can no longer disagree. The collapse to single
  -- spaces, the dash losing its color span and the description gaining one are the accepted cost.
  local rows = (NS.Slash and NS.Slash.LandingRows) and NS.Slash:LandingRows() or {}
  for _, row in ipairs(rows) do
    local labelRow = AceGUI:Create("Label")
    labelRow:SetFullWidth(true)
    labelRow:SetText(row)
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

-- NOT O.RefreshScalars, and the difference is the reason it survives. The library's version sweeps
-- EVERY registered ctx, which is right for a write that could be showing anywhere; this one is
-- called by name from one page's own code — the console checkbox mirroring the debug window — and
-- sweeping every page for that would refresh three pages to repaint one. Each library widget maker
-- already calls O.RefreshScalars from its own set(), so the fan-out IS wired; this is the targeted
-- path beside it.
--
-- There WAS a second of these, P:RefreshPanels, doing the same for the Panels page's editor. It is
-- gone: its one caller was settings/PanelEditor.lua's MSG_PANEL handler, which now calls the
-- library's O.RefreshPanel(ctx, false) instead — same refresher run, but the shown/hidden decision
-- and the dirty flag belong to the library rather than being hand-rolled here. Nothing else ever
-- called it.

function P:RestoreDefaults()
  if NS.Slash and NS.Slash.CliResetAll then NS.Slash:CliResetAll() end
  P:Refresh()
end

-- ── Registration ───────────────────────────────────────────────────────────────
--
-- Four canvas pages, registered through LibKa0s-Options-1.0's page registry rather than by calling
-- Settings.RegisterCanvasLayoutSubcategory four times here. The library owns the queue, runs each
-- builder ONCE and pcalls each one SEPARATELY — so a page that raises costs only itself and is
-- reported by key, where previously one bad builder killed every page after it in the list and the
-- user saw a half-registered options tree with nothing naming the culprit.
--
-- Each body is still built LAZILY on its first OnShow, but through O.SetRenderer rather than a
-- hand-rolled `rendered` flag per page. That is not a simplification: SetRenderer also gives every
-- page the combat guard (the Blizzard AddOns sidebar reaches a panel without going through
-- /pm config, so its guard is bypassed on exactly the path a user is most likely to take mid-fight)
-- and the dirty-re-render, which the Panels page used to hand-roll and the other three did without.
function P:Register()
  if registered then return end
  if not (AceGUI and Settings and Settings.RegisterCanvasLayoutCategory
          and Settings.RegisterCanvasLayoutSubcategory) then return end
  registered = true

  -- The landing page's body lives in this file; the descriptor in settings/OptionsSetup.lua closes
  -- over a forward declaration, which this fills in.
  NS.SetBuildMain(buildMainContent)

  -- General = the addon's own settings.
  O.RegisterOptionsPage("general", "General", function(mainCategory)
    local ctx = O.CreatePanel(nil, "General", {
      pageKey = "general",
      defaultsButton = true,
      defaultsTooltip = "Reset every setting on this page to its default. Your panels are untouched.",
    })
    -- This addon's own per-page state, added onto the ctx the library hands back: the open-dropdown
    -- registry (see the top of this file), and the two flags the Panels page's editor drives.
    ctx.dropdowns, ctx.rebuilders = {}, {}
    P.general = ctx

    -- Non-destructive: this resets settings only and never touches the user's panels, so it is safe
    -- behind Blizzard's un-gated footer control. O.CreatePanel's OnDefault FORWARDS to this, so the
    -- footer control and the header Defaults button are one implementation rather than two.
    -- Deleting panels stays behind the confirm-gated KA0S_PANELMASTER_DELETEALL popup.
    ctx.panel.defaultsOnClick = function() P:RestoreDefaults() end

    O.SetRenderer(ctx, function(c)
      O.ClearScroll(c)
      forgetDropdowns(c)
      -- RenderSchema, not RenderRows with an explicit list: the per-page wrapper routes through the
      -- descriptor's `rowsForPage`, which is what makes that field load-bearing rather than
      -- decorative. Handing the flow engine NS.Schema.Schema directly worked identically and left
      -- `rowsForPage` dead — a mutation that emptied it changed nothing and failed no case.
      O.RenderSchema(c, "general", nil, {
        -- "Recover panels" sits to the right of Grid size: it is the other thing you reach for when
        -- a layout has gone wrong. `pairWith` is the library's name for what this file called
        -- `companions` — a non-schema widget attached as the RIGHT half of a named path's row.
        ["settings.gridSize"] = function(_, parentRow)
          parentRow:AddChild(makePairButton("Recover panels", function()
            if NS.Slash then NS.Slash:CliRecover() end
          end))
        end,
      })
    end)
    return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, "General")
  end)

  -- Panels = create, edit and delete the panels themselves. The page is registered and laid out
  -- here; its BODY is settings/PanelEditor.lua's, which this file only ever drives through the
  -- three calls below.
  O.RegisterOptionsPage("panels", "Panels", function(mainCategory)
    local pctx = O.CreatePanel(nil, "Panels", {
      pageKey = "panels",
      defaultsButton = true,
      defaultsTooltip = "Delete every panel. This cannot be undone.",
    })
    pctx.dropdowns, pctx.rebuilders = {}, {}
    P.panels = pctx
    NS.PanelEditor:WireBus(pctx)

    -- Defaults here = delete every panel, which IS the stock state of this page (a fresh install
    -- has none). Destructive, so it is confirm-gated — on BOTH entry points, since O.CreatePanel's
    -- OnDefault forwards the Settings window's footer control to this same closure.
    pctx.panel.defaultsOnClick = function()
      if type(StaticPopup_Show) == "function" then
        StaticPopup_Show("KA0S_PANELMASTER_DELETEALL")
      else
        NS.Registry:DeleteAll()
      end
    end

    -- The editor's own two-phase build: BuildPage lays down the chrome that never changes, Rebuild
    -- repaints the list. SetRenderer re-runs this whole closure when the page is marked dirty while
    -- hidden — and marking it is the library's job now, through O.RefreshPanel. The host-owned
    -- `pctx.dirty` flag this file used to seed here is GONE: it sat one underscore away from the
    -- library's own `_dirty`, settings/PanelEditor.lua wrote it, the gate read the other one, and a
    -- profile switch left this page showing the previous profile's panels for the rest of the
    -- session. See the bus-policy comment in settings/PanelEditor.lua.
    local built = false
    O.SetRenderer(pctx, function(c)
      if not built then
        built = true
        NS.PanelEditor:BuildPage(c)
      end
      NS.PanelEditor:Rebuild(c)
    end)
    return Settings.RegisterCanvasLayoutSubcategory(mainCategory, pctx.panel, "Panels")
  end)

  -- Profiles = AceDB's own profile management, rendered into our canvas.
  --
  -- This is the ONE place AceConfigDialog is permitted (anti-patterns forbids it for content, and
  -- explicitly carves out Profiles). AceDBOptions hands back a complete, correct options table for
  -- create / switch / copy / reset / delete plus the per-character/class/realm/faction scopes —
  -- reimplementing that by hand in AceGUI would be a large pile of code whose only distinction
  -- would be its own bugs.
  --
  -- Guarded rather than assumed: both libs are OptionalDeps, and their absence means no Profiles
  -- page rather than a broken one (library-stack-§6). Returning nil from the builder is how the
  -- library is told a page opted out.
  O.RegisterOptionsPage("profiles", "Profiles", function(mainCategory)
    local AceDBOptions    = LibStub and LibStub("AceDBOptions-3.0", true)
    local AceConfig       = LibStub and LibStub("AceConfig-3.0", true)
    local AceConfigDialog = LibStub and LibStub("AceConfigDialog-3.0", true)
    if not (AceDBOptions and AceConfig and AceConfigDialog and NS.db) then return nil end

    AceConfig:RegisterOptionsTable("PanelMaster-Profiles", AceDBOptions:GetOptionsTable(NS.db))

    -- No Defaults button: profile management carries its own destructive controls, and a second
    -- "reset" meaning something different from the page's own Reset Profile would be a trap.
    local prctx = O.CreatePanel(nil, "Profiles", { pageKey = "profiles" })
    prctx.dropdowns, prctx.rebuilders = {}, {}
    P.profiles = prctx

    -- AceConfigDialog renders into any AceGUI container, so it is pointed at a group parented to
    -- our body — the widgets land inside the canvas rather than opening their own window. Guarded
    -- like every other AceGUI create on this page: a container that failed to build must leave the
    -- page inert, not raise during registration and take the whole addon's load with it.
    local container = O.AceGUI:Create("SimpleGroup")
    if container and container.frame then
      container:SetLayout("Fill")
      container.frame:SetParent(prctx.body)
      container.frame:ClearAllPoints()
      container.frame:SetPoint("TOPLEFT",     prctx.body, "TOPLEFT",      PADDING_X, -8)
      container.frame:SetPoint("BOTTOMRIGHT", prctx.body, "BOTTOMRIGHT", -PADDING_X, 8)
    end

    -- Re-opened on every show, not just the first: after a profile switch the whole options tree is
    -- stale, and AceConfigDialog reuses its existing widget tree, so this is cheap. SetRenderer only
    -- re-runs on first show and on a dirty re-render, so the page marks ITSELF dirty each time —
    -- which is the honest way to say "this page has no cached state worth keeping".
    O.SetRenderer(prctx, function(c)
      c._dirty = true
      if not (container and container.frame) then return end
      AceConfigDialog:Open("PanelMaster-Profiles", container)
    end)
    return Settings.RegisterCanvasLayoutSubcategory(mainCategory, prctx.panel, "Profiles")
  end)

  -- Resolves AceGUI, hands it to the descriptor's onAceGUI, runs the schema validation, registers
  -- the main canvas, then drains the queue above.
  O.CreateOptionsPanel()
end

function P:Open()
  -- The combat refusal (options-ui-§2) and the open itself are the library's: it REFUSES under
  -- lockdown and never defers-and-replays, because Blizzard's category switch is protected and
  -- calling it under lockdown taints the panel for the rest of the session, while a panel that pops
  -- itself open the instant combat drops steals focus during post-pull recovery.
  if InCombatLockdown and InCombatLockdown() then return O.OpenOptionsPanel() end

  -- What the library does NOT do is explain an ABSENT category — it simply returns. Both eager
  -- registration attempts (OnInitialize's and the PLAYER_LOGIN retry's, core/PanelMaster.lua) can
  -- find no Settings API on an old client, and a command that returns silently reads as broken
  -- where a named prerequisite reads as a missing one.
  if not (Settings and Settings.OpenToCategory and registered) then
    print("settings are not available on this client, so there is no page to open")
    return
  end
  O.OpenOptionsPanel()
end

-- Test seam. `registered` is a file-local written only by Register, so the branch above is
-- unreachable in a suite where registration succeeded — this drives it directly.
function P.__setCategoryIDForTest(id)
  registered = id ~= nil
end
