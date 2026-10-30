-- tests/test_settings_layout.lua — the settings layout of item 020, line by line.
--
-- WHAT IT PROVES. That each settings tab the layout pass touched (Ka0sAddonsCommonTasks
-- docs/2026-10-24-KEYBINDS_LAYOUT_STRATA, item PM-LY) draws its controls on the designed LINES,
-- under the designed subsection headings, with the designed labels; and that the tooltips the pass
-- reworded say what it decided they say. The owner's rule for the pass was "move, regroup and
-- relabel only", so tests/test_settings_guard.lua holds the other half: no stored path, default or
-- range moved.
--
-- HOW A TAB IS READ. The Panels page's editor is bespoke (settings/PanelEditorTabs.lua): it adds a
-- Heading per subsection and one Flow row (a SimpleGroup) per line to one List container. So a tab
-- reads as that container's children in order: "# <heading>" for a Heading, and the captions of a
-- row's widgets joined by " | " for a line -- a label for a labeled control, "[text]" for a button.
-- Spacers carry no layout and are skipped. The General page is the library's flow engine over the
-- schema, which pairs consecutive rows, so its order is read from the rows themselves.
--
-- WRITTEN OUT, NOT DERIVED. Each expectation is the designed table, on purpose: a derived one agrees
-- with any arrangement, including the one where a row has drifted.
local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local E = NS.PanelEditor
local C = NS.Constants

local ELLIPSIS = "\226\128\166"

local function freshPanelsCtx()
  local ctx = NS.Helpers.CreatePanel(nil, "Panels", { pageKey = "panels" })
  ctx.dropdowns, ctx.rebuilders = {}, {}
  ctx.refreshers = ctx.refreshers or {}
  E:BuildPage(ctx)
  return ctx
end

local function created()
  return T.mocks.LibStub("AceGUI-3.0", true).__created
end

local function caption(w)
  if w.type == "Button" then return "[" .. tostring(w.text) .. "]" end
  return w.labelText or ("<" .. tostring(w.type) .. ">")
end

local function isFlowRow(w)
  return w.type == "SimpleGroup" and w.layout == "Flow"
end

-- The editor body: a List group holding at least one Flow row (the last such group wins).
local function isEditorBody(w)
  if w.type ~= "SimpleGroup" or w.layout ~= "List" then return false end
  for _, c in ipairs(w.children or {}) do
    if isFlowRow(c) then return true end
  end
  return false
end

-- One child of the editor body as a line: "# heading" for a Heading, "a | b" for a Flow row, nil
-- for anything else.
local function lineOf(c)
  if c.type == "Heading" then return "# " .. tostring(c.text) end
  if not isFlowRow(c) then return nil end
  local caps = {}
  for _, k in ipairs(c.children or {}) do caps[#caps + 1] = caption(k) end
  return table.concat(caps, " | ")
end

-- Render one editor tab and answer (lines, widgets): the tab as "# heading" / "a | b" strings, and
-- every widget it created, for the tooltip cases.
local function renderTab(ctx, tab)
  local list = created()
  local from = #list + 1
  ctx.activeTab = tab
  E:Rebuild(ctx)
  local editor, widgets = nil, {}
  for i = from, #list do
    local w = list[i]
    widgets[#widgets + 1] = w
    if isEditorBody(w) then editor = w end
  end
  local lines = {}
  for _, c in ipairs(editor and editor.children or {}) do
    local line = lineOf(c)
    if line then lines[#lines + 1] = line end
  end
  return lines, widgets
end

-- The tooltip a widget shows on hover, as (title, body): its OnEnter fired against a recording
-- GameTooltip, which is what O.AttachTooltip draws into.
local function tooltipOf(w)
  local saved, got = T.mocks.GameTooltip, {}
  T.mocks.GameTooltip = setmetatable({
    SetText = function(_, text) got.title = text end,
    AddLine = function(_, text) got.body = text end,
  }, { __index = function() return function() end end })
  local ok, err = pcall(w.__fire, w, "OnEnter")
  T.mocks.GameTooltip = saved
  assertTrue(ok, tostring(err))
  return got.title, got.body
end

local function find(widgets, cap)
  for _, w in ipairs(widgets) do
    if caption(w) == cap then return w end
  end
end

local function assertLines(tab, got, want)
  local shown = "\n  " .. table.concat(got, "\n  ")
  assertEqual(#got, #want, ("the '%s' tab draws %d lines, not %d:%s"):format(tab, #got, #want, shown))
  for i, line in ipairs(want) do
    assertEqual(got[i], line, ("the '%s' tab, line %d:%s"):format(tab, i, shown))
  end
end

local function withPanels(fn)
  NS.Registry:DeleteAll()
  local rec = NS.Registry:New("Laid out")
  NS.Registry:New("Other")
  E.__setSelectedID(rec.id)
  local ok, err = pcall(fn, freshPanelsCtx(), rec)
  NS.Registry:DeleteAll()
  E.__setSelectedID(nil)
  if not ok then error(err, 0) end
end

local function startsWith(s, prefix) return type(s) == "string" and s:sub(1, #prefix) == prefix end
local function endsWith(s, suffix) return type(s) == "string" and s:sub(-#suffix) == suffix end

local NEW_PANELS_NOTE = "New panels start at the size, layer and opacity set on the General page "
  .. "> New panels."

-- ── The Panels page ─────────────────────────────────────────────────────────────

test("Layout: the Panels page's tabs draw their designed lines and headings", function()
  withPanels(function(ctx)
    local DESIGN = {
      { "General", {
        "Panel name | Copy settings from panel",
        "Enable this panel | Unlock this panel",
        "[Reset panel" .. ELLIPSIS .. "] | [Delete panel" .. ELLIPSIS .. "]",
      } },
      { "Size and position", {
        "# Size",
        "Width | Height",
        "Panel scale",
        "# Position",
        "Screen anchor point",
        "X offset | Y offset",
        "# Layer",
        "Frame strata | Frame level",
      } },
      { "Background and border", {
        "# Background",
        "Background texture",
        "Background color | Use class color",
        "# Border",
        "Border style | Border thickness (px)",
        "Border color | Use class color",
        "Border offset",
      } },
      { "Accent bar", {
        "Enable accent bar",
        "# Edges",
        "Top | Bottom | Left | Right",
        "# Fill",
        "Bar texture | Bar opacity",
        "Bar color | Use class color",
        "Bar thickness | Bar offset",
        "# Border",
        "Border style | Border thickness (px)",
        "Border color | Use class color",
        "Border offset",
      } },
      { "Artwork", {
        "# Image",
        "Artwork",
        "Custom texture path | [Fit to artwork]",
        "# Layout",
        "Fill | Artwork scale",
        "Artwork position | Draw layer",
        "Artwork X offset | Artwork Y offset",
        "# Orientation",
        "Rotation",
        "Flip horizontal | Flip vertical",
        "# Color and blending",
        "Artwork opacity | Blend mode",
        "Artwork color | Use class color",
        "Desaturate",
      } },
      { "Opacity and fade", {
        "Panel opacity | Faded opacity",
        "Fade unless hovered",
      } },
    }
    assertEqual(#E.TABS, #DESIGN, "the editor has a different number of tabs than designed")
    for i, entry in ipairs(DESIGN) do
      assertEqual(E.TABS[i], entry[1], ("editor tab %d"):format(i))
      local lines = renderTab(ctx, entry[1])
      assertLines(entry[1], lines, entry[2])
    end
  end)
end)

test("Layout: the band's create box is labeled New panel and says where new panels start", function()
  NS.Registry:DeleteAll()
  local list = created()
  local from = #list + 1
  freshPanelsCtx()
  local box
  for i = from, #list do
    if list[i].type == "EditBox" and list[i].labelText == "New panel" then box = list[i] end
  end
  assertTrue(box ~= nil, "the band drew no New panel box")
  local title, body = tooltipOf(box)
  assertEqual(title, "New panel")
  assertTrue(endsWith(body, NEW_PANELS_NOTE),
    "the New panel tooltip does not point at the General page > New panels: " .. tostring(body))
  NS.Registry:DeleteAll()
end)

test("Layout: the General tab's reworded labels and tooltips", function()
  withPanels(function(ctx)
    local _, widgets = renderTab(ctx, "General")

    local _, copy = tooltipOf(assert(find(widgets, "Copy settings from panel")))
    assertEqual(copy, "Copy everything from another panel except its name and its position (anchor "
      .. "and offsets): size and scale, layer, opacity and fade, background, border, accent bar, "
      .. "artwork, and whether it is enabled. This panel stays where it is.")

    assertEqual((tooltipOf(assert(find(widgets, "Enable this panel")))), "Enable this panel")
    assertEqual((tooltipOf(assert(find(widgets, "Unlock this panel")))), "Unlock this panel")

    local resetTitle, reset = tooltipOf(assert(find(widgets, "[Reset panel" .. ELLIPSIS .. "]")))
    assertEqual(resetTitle, "Reset panel" .. ELLIPSIS)
    assertTrue(endsWith(reset, NEW_PANELS_NOTE),
      "the Reset panel tooltip does not point at the General page > New panels")
    local deleteTitle = tooltipOf(assert(find(widgets, "[Delete panel" .. ELLIPSIS .. "]")))
    assertEqual(deleteTitle, "Delete panel" .. ELLIPSIS)
  end)
end)

test("Layout: the copy tooltip's exclusions are exactly what Registry.CopyFrom skips", function()
  -- The tooltip says "everything except its name and its position (anchor and offsets)". That is
  -- true only while the copy skips id, name, frameName, point, relPoint, x and y and nothing else,
  -- so the claim is checked against a real copy rather than taken on trust.
  local R = NS.Registry
  R:DeleteAll()
  local source = R:New("Source")
  local target = R:New("Target")
  local SKIPPED = { id = true, name = true, frameName = true,
                    point = true, relPoint = true, x = true, y = true }
  R:Set(source.id, "point", "TOPLEFT")
  R:Set(source.id, "x", 40)
  R:Set(source.id, "y", -30)
  R:Set(source.id, "width", 333)
  R:Set(source.id, "enabled", false)
  assertTrue((R:CopyFrom(target.id, source.id)), "the copy was refused")
  local s, t = R:Get(source.id), R:Get(target.id)
  for _, field in ipairs(C.PANEL_FIELD_ORDER) do
    if not SKIPPED[field] then
      assertTrue(NS.Util.DeepEqual(s[field], t[field]),
        ("the copy did not carry %s, so the tooltip's 'everything' is wrong"):format(field))
    end
  end
  assertEqual(t.name, "Target")
  assertEqual(t.point, "CENTER", "the copy moved the anchor")
  assertEqual(t.x, 0, "the copy moved the panel")
  R:DeleteAll()
end)

test("Layout: the Size and position, Accent bar, Artwork and fade tooltips", function()
  withPanels(function(ctx)
    local _, size = renderTab(ctx, "Size and position")
    local _, strataTip = tooltipOf(assert(find(size, "Frame strata")))
    assertEqual(strataTip, NS.Helpers.StrataTooltip(C.STRATA),
      "the editor's Frame strata row does not carry the library's one strata tooltip")

    local _, accent = renderTab(ctx, "Accent bar")
    local _, enable = tooltipOf(assert(find(accent, "Enable accent bar")))
    assertTrue(endsWith(enable, "Everything below on this tab applies only while this is ticked."),
      "the Enable accent bar tooltip does not state the dependency: " .. tostring(enable))
    local _, thick = tooltipOf(assert(find(accent, "Bar thickness")))
    assertEqual(thick, "How thick the accent bar is, in UI units.")

    local _, art = renderTab(ctx, "Artwork")
    local _, fit = tooltipOf(assert(find(art, "[Fit to artwork]")))
    assertTrue(startsWith(fit, "Overwrites this panel's Width and Height (Size and position tab) "
      .. "with "), "the Fit to artwork tooltip does not say what it overwrites: " .. tostring(fit))

    local _, fade = renderTab(ctx, "Opacity and fade")
    local _, opacity = tooltipOf(assert(find(fade, "Panel opacity")))
    assertTrue(startsWith(opacity, "How visible the whole panel is: background, border, accent "
      .. "bars and artwork together."), "the Panel opacity tooltip understates its reach")
    local _, faded = tooltipOf(assert(find(fade, "Faded opacity")))
    assertTrue(faded:find("'Fade unless hovered'", 1, true) ~= nil,
      "the Faded opacity tooltip still quotes the old switch label")
  end)
end)

-- ── The General page ────────────────────────────────────────────────────────────

local MOVING_NOTE = "These only matter while panels are unlocked: untick Lock frame on the General "
  .. "page > Master controls, or tick Unlock this panel on Panels > General."

test("Layout: Moving panels pairs each switch with what it governs", function()
  -- The flow engine pairs consecutive rows of a group, so this order IS the two lines:
  -- [Show names while unlocked][Unlock outline thickness] / [Snap to grid][Grid size].
  local want = { "settings.showLabels", "settings.unlockOutlineSize",
                 "settings.snapToGrid", "settings.gridSize" }
  local got = {}
  for _, row in ipairs(NS.Schema.ProfileRows()) do
    if row.group == "Moving panels" then got[#got + 1] = row.path end
  end
  assertEqual(#got, #want, "Moving panels holds a different number of rows")
  for i, path in ipairs(want) do
    assertEqual(got[i], path, ("Moving panels row %d"):format(i))
    local row = NS.Schema:FindRow(path)
    assertTrue(not row.startsLine and not row.wide and not row.solo,
      path .. " forces a line break, so the pairing above is not what renders")
    assertTrue(endsWith(row.tooltip, MOVING_NOTE), path .. " lost the unlock cross-reference")
  end
end)

test("Layout: each New panels default says where panels are made", function()
  for _, path in ipairs({ "settings.defaultWidth", "settings.defaultHeight",
                          "settings.defaultStrata", "settings.defaultAlpha" }) do
    local row = NS.Schema:FindRow(path)
    assertEqual(row.group, "New panels")
    assertTrue(row.tooltip:find("Panels are made on the Panels page.", 1, true) ~= nil,
      path .. " does not say where panels are made")
  end
  -- And the strata row still carries the library's tier text, once (PAN-L20 is O.StrataTooltip).
  local strata = NS.Schema:FindRow("settings.defaultStrata")
  local tip = NS.Helpers.StrataTooltip(C.STRATA)
  local first = strata.tooltip:find(tip, 1, true)
  assertTrue(first ~= nil, "Default frame strata lost the library's strata tooltip")
  assertTrue(strata.tooltip:find(tip, first + 1, true) == nil, "the strata tiers are stated twice")
end)

-- Show the General page on one tab and answer the widgets it created.
local function generalTab(tab)
  local ctx = NS.Panel.general
  local list = created()
  local from = #list + 1
  ctx.activeTab = tab
  ctx._dirty = true
  ctx.panel:GetScript("OnShow")(ctx.panel)
  local out = {}
  for i = from, #list do out[#out + 1] = list[i] end
  return out
end

test("Layout: Recover panels leads the Master controls tab's buttons, above the resets", function()
  local order, recover = {}, nil
  for _, w in ipairs(generalTab("Master controls")) do
    if w.type == "Button" and w.text then
      order[#order + 1] = w.text
      if w.text == "Recover panels" then recover = w end
    end
  end
  local joined = table.concat(order, ", ")
  assertTrue(recover ~= nil, "the Master controls tab drew no Recover panels button: " .. joined)
  local at = {}
  for i, text in ipairs(order) do at[text] = at[text] or i end
  assertTrue(at["Reset position"] ~= nil and at["Recover panels"] < at["Reset position"],
    "Recover panels is not above Reset position: " .. joined)
  local _, body = tooltipOf(recover)
  assertTrue(endsWith(body, "Unlike Reset position below, panels that are on screen stay where "
    .. "they are."), "the Recover panels tooltip does not contrast it with Reset position")

  -- And it is no longer drawn on Moving panels.
  for _, w in ipairs(generalTab("Moving panels")) do
    assertTrue(not (w.type == "Button" and w.text == "Recover panels"),
      "Recover panels is still drawn on the Moving panels tab")
  end
end)
