-- tests/test_options_groups.lua — the `options-ui-§16` gate over the Panels page.
--
-- WHAT IT PROVES. That `settings/PanelEditor.lua` types out none of `options-ui-§16`'s border, bar
-- or font blocks; that the three blocks it draws are composed through LibKa0s-Options' record-backed
-- arm (`spec.bind`, PanelMaster#48); and that `docs/ARCHITECTURE.md` ▸ `## Documented deviations`
-- carries no `options-ui-§16` row. Below those three gates sits what the composed blocks ARE, control
-- by control.
--
-- WHY IT EXISTS. `options-ui-§16` says the border, bar and font blocks are COMPOSED — the library
-- emits each from one declaration, and a hand-written copy is anti-pattern #73. Until LibKa0s v1.31.0
-- the composers emitted path-keyed schema rows only, the Panels page edits registry RECORDS, and the
-- three blocks were typed out under three ratified register rows that this file used to hold to the
-- code. OptionsCompose minor 4 added the record-backed arm, the blocks compose, and the rows retired
-- on 2026-09-12. What can rot now is a regression in either direction, and both are silent:
--
--   * a hand-written block coming BACK. Someone adds a font group to the Artwork tab by hand,
--     because a media-picker helper is sitting right there in the file, and nothing looks wrong.
--   * a register row coming back for a block that composes: a deviation this addon no longer has,
--     in a table `## Documented deviations` says in as many words is not a graveyard.
--
-- HOW A BLOCK IS RECOGNIZED. By its LEADING row, which `options-ui-§16` names: `Font`, `Border
-- style`, `Bar texture`. Each is a shared-media picker, and a hand-written one on this page would be
-- built by `makeMediaDropdown`, so the leading rows are exactly the `makeMediaDropdown` calls carrying
-- one of those three labels. `Background texture` is deliberately not among them: a group over a
-- background is not a bar group (`options-ui-§16`), it takes the swatch and its companion and nothing
-- else, and this page's background group does exactly that. It is also what keeps the scan honest:
-- the background picker is still a `makeMediaDropdown` call, so a scan that finds none has gone blind.
--
-- IT FAILS RATHER THAN PASSES WHEN IT CANNOT LOOK. No editor source, no ARCHITECTURE.md, no register
-- heading, no media picker found at all — every one of those is a failure, not a skip. A gate that
-- goes quiet when it is blind reports success, which is worse than not existing.

local T = _G.PM_TEST
local test, fail = T.test, T.fail

local EDITOR       = "settings/PanelEditor.lua"
local ARCHITECTURE = "docs/ARCHITECTURE.md"
local REGISTER     = "## Documented deviations"
-- The rule id, with the section sign written as its two UTF-8 bytes so this file stays ASCII the way
-- its siblings are. Split at the escape because Lua reads up to three digits after a backslash, and
-- `\16716` would otherwise have to be counted out by whoever reads it next.
local RULE         = "options-ui-\194\167" .. "16"

-- The three block-leading labels `options-ui-§16` mandates. A media picker carrying one of these is
-- the head of a canonical block; one carrying anything else is a media row standing alone, which the
-- rule says is a finder rather than a finding.
local BLOCK_HEADS = {
  ["Font"]         = "the font block",
  ["Border style"] = "the border block",
  ["Bar texture"]  = "the bar block",
}

--- Read a whole file, or fail naming it. Never returns nil.
local function readOrFail(path, why)
  local fh = io.open(path, "r")
  if not fh then fail("optionsgroups: " .. path .. " could not be opened, so " .. why) end
  local body = fh:read("*a") or ""
  fh:close()
  return (body:gsub("\r\n", "\n"))
end

--- Every hand-written canonical block on the Panels page, as { field, label } in source order.
---
--- `%b()` rather than a line pattern: the calls wrap, and their tooltips run to several lines. The
--- two quoted strings after `rec,` are the stored field and the row's label, in that order, and the
--- helper's own signature at the top of the file pins that order.
local function handWrittenBlocks()
  local src = readOrFail(EDITOR, "the gate cannot tell whether a block is typed out")

  local blocks, pickers = {}, 0
  for call in src:gmatch("makeMediaDropdown%b()") do
    local field, label = call:match('rec%s*,%s*"([%w_]+)"%s*,%s*"([^"]+)"')
    if field then pickers = pickers + 1 end
    if field and BLOCK_HEADS[label] then
      blocks[#blocks + 1] = { field = field, label = label }
    end
  end

  if pickers == 0 then
    fail("optionsgroups: no `makeMediaDropdown` call was found in " .. EDITOR .. " at all, not even "
      .. "the background picker. Either the helper has been renamed, in which case this gate has "
      .. "gone blind and must follow it, or the background has moved too, in which case say what "
      .. "a hand-written block would be built with now")
  end
  return blocks
end

--- The `options-ui-§16` rows of the deviation register, as { differs, trigger } .
---
--- A row is a table line inside the register section; the header and the `|---|` separator carry
--- fewer than the five cells a row has and fall out on their own. Reading stops at the next heading
--- of any level, so a later table cannot leak into this one.
local function registerRows()
  local body = readOrFail(ARCHITECTURE, "this gate cannot see the deviation register")

  local rows, inside, found = {}, false, false
  for line in (body .. "\n"):gmatch("([^\n]*)\n") do
    if line == REGISTER then
      inside, found = true, true
    elseif inside and line:sub(1, 1) == "#" then
      break
    elseif inside and line:sub(1, 1) == "|" then
      local cells = {}
      for cell in line:gmatch("|([^|]*)") do cells[#cells + 1] = cell end
      -- Five cells and a trailing empty one from the closing pipe: rule, what differs, why,
      -- decided, re-check trigger.
      if #cells >= 5 and cells[1]:find(RULE, 1, true) then
        rows[#rows + 1] = { differs = (cells[2]:gsub("^%s*(.-)%s*$", "%1")) }
      end
    end
  end

  if not found then
    fail("optionsgroups: " .. ARCHITECTURE .. " carries no '" .. REGISTER .. "' section. That "
      .. "table is the single home for a ratified deviation (`documentation-§3`), and it must not "
      .. "be removed or renamed while this gate names it")
  end
  return rows
end

-- ---------------------------------------------------------------------------
-- The three gates
-- ---------------------------------------------------------------------------

test("optionsgroups: the Panels editor types out no canonical block", function()
  local blocks = handWrittenBlocks()
  if #blocks > 0 then
    local names = {}
    for i, block in ipairs(blocks) do
      names[i] = block.field .. " (" .. BLOCK_HEADS[block.label] .. ")"
    end
    fail("optionsgroups: hand-written `" .. RULE .. "` blocks in " .. EDITOR .. ": "
      .. table.concat(names, ", ") .. " — compose them with O.BorderGroup / O.BarGroup / "
      .. "O.FontGroup and a `bind` over the panel record. A hand-written copy of a group is "
      .. "anti-pattern #73, and the record-backed arm is exactly what took the reason for one away")
  end
end)

test("optionsgroups: the three blocks are composed through the record-backed arm (#48)", function()
  local src = readOrFail(EDITOR, "the gate cannot see how the blocks are built")
  local found = { BorderGroup = 0, BarGroup = 0 }
  -- Either call form: `O.BorderGroup{ ... }` or `O.BorderGroup({ ... })`.
  for composer, body in src:gmatch("O%.(%a+Group)%s*%(?%s*(%b{})") do
    if found[composer] then
      if not body:find("bind%s*=") then
        fail("optionsgroups: an O." .. composer .. " call in " .. EDITOR .. " passes no `bind`. "
          .. "Without one it emits path-keyed schema rows, and a panel is a registry record with "
          .. "no path")
      end
      found[composer] = found[composer] + 1
    end
  end
  if found.BorderGroup ~= 2 or found.BarGroup ~= 1 then
    fail(("optionsgroups: %s composes %d border and %d bar blocks; the Panels page has two border "
      .. "blocks (the panel's, the accent bar's) and one bar block (the accent bar)"):format(
      EDITOR, found.BorderGroup, found.BarGroup))
  end
end)

test("optionsgroups: the deviation register carries no " .. RULE .. " row", function()
  local rows = registerRows()
  if #rows > 0 then
    local names = {}
    for i, row in ipairs(rows) do names[i] = "row " .. i .. " (" .. row.differs:sub(1, 60) .. "\226\128\166)" end
    fail("optionsgroups: `" .. RULE .. "` rows in " .. ARCHITECTURE .. ": " .. table.concat(names, ", ")
      .. " — the three blocks compose now (PanelMaster#48), so a row for one is a deviation this "
      .. "addon does not have. If a new block genuinely cannot compose, that is a question for the "
      .. "owner, not a row added to make this gate quiet")
  end
end)

-- ---------------------------------------------------------------------------
-- What the three blocks ARE, control by control (PanelMaster#48)
-- ---------------------------------------------------------------------------
--
-- Written against the hand-written blocks BEFORE they were composed, and kept green across the
-- swap: this is the characterization that says the composer changed where each control comes from
-- and not what a player sees or what it writes. Per control it pins the label, the widget type,
-- the width, which controls share a row, the slider range and whether it reads as a percentage,
-- the media list and its order, the value it opens on, the tooltip's title and body, a write
-- landing in the record THROUGH `NS.Registry:Set`, and a write made elsewhere reaching the control
-- through the page's refreshers.
--
-- The LSM30_* widget types are registered for the duration of each case, because the library's
-- dropdown maker falls back to a plain Dropdown when AceGUI-3.0-SharedMediaWidgets is absent (the
-- harness default) while the hand-written picker asked for the LSM type by name. With the types
-- registered both paths build the widget a player with SharedMediaWidgets gets.

local NS = T.NS
local E  = NS.PanelEditor
local assertEqual, assertTrue, assertNear = T.assertEqual, T.assertTrue, T.assertNear

local NOTE = NS.Helpers.CLASS_COLOR_NOTE or ""
local SWATCH_TIP = "Sets the color and its opacity. " .. NOTE
local function companionTip(what)
  return "Use your class color for " .. what .. ". The opacity from the color picker still "
    .. "applies \226\128\148 a class color at low opacity looks just as washed out as any other."
end

-- One row of the expectation table per control, in the order the tab draws them. An entry with no
-- `field` is a control outside the three blocks, pinned by label only so the block's position on
-- its tab is pinned too.
local BORDER = {
  { label = "Border style", type = "LSM30_Border", field = "borderTexture", media = "border",
    tip = "The edge style drawn around the panel. 'Solid' is a plain outline; 'None' removes it." },
  { label = "Border thickness (px)", type = "Slider", field = "borderSize", min = 0, max = 32, step = 1,
    tip = "Border thickness. 0 removes the border entirely." },
  { label = "Border color", type = "ColorPicker", field = "borderColor", tip = SWATCH_TIP },
  { label = "Use class color", type = "CheckBox", field = "borderClassColor",
    tip = companionTip("border color") },
  { label = "Border offset", type = "Slider", field = "borderOffset", min = -32, max = 32, step = 1,
    tip = "How far the border sits from the panel's edge. Positive pushes it outward, "
      .. "negative pulls it inward." },
}

local BAR = {
  { label = "Bar texture", type = "LSM30_Statusbar", field = "accentTexture", media = "statusbar",
    tip = "The texture the accent bar is drawn with, from your LibSharedMedia status-bar textures. "
      .. "'Solid' is a flat color." },
  { label = "Bar opacity", type = "Slider", field = "accentAlpha", min = 0, max = 1, step = 0.05,
    tip = "How solid the accent bar's fill is. Multiplies with the opacity in the bar color below and "
      .. "with the panel's own opacity, so a faded panel fades its bars with it." },
  { label = "Bar color", type = "ColorPicker", field = "accentColor", tip = SWATCH_TIP },
  { label = "Use class color", type = "CheckBox", field = "accentClassColor",
    tip = companionTip("bar color") },
  { label = "Bar thickness", type = "Slider", field = "accentThickness", min = 1, max = 32, step = 1,
    tip = "How thick the accent bar is, in screen units." },
  { label = "Bar offset", type = "Slider", field = "accentOffset", min = -32, max = 32, step = 1,
    tip = "How far the bar sits from the panel's edge. Positive detaches it from the panel, "
      .. "which is the look this is modeled on; 0 sits flush; negative overlaps the panel." },
}

local BAR_BORDER = {
  { label = "Border style", type = "LSM30_Border", field = "accentBorderTexture", media = "border",
    tip = "The edge style drawn around the accent bar. 'None' removes it, as does a thickness of 0." },
  { label = "Border thickness (px)", type = "Slider", field = "accentBorderSize", min = 0, max = 32,
    step = 1, tip = "Thickness of the accent bar's own border. 0 removes it entirely." },
  { label = "Border color", type = "ColorPicker", field = "accentBorderColor", tip = SWATCH_TIP },
  { label = "Use class color", type = "CheckBox", field = "accentBorderClassColor",
    tip = companionTip("border color") },
  { label = "Border offset", type = "Slider", field = "accentBorderOffset", min = -32, max = 32,
    step = 1, tip = "How far the bar's border sits from the bar. Positive pushes it outward, "
      .. "negative inward." },
}

local function concat(...)
  local out = {}
  for _, list in ipairs({ ... }) do
    for _, e in ipairs(list) do out[#out + 1] = e end
  end
  return out
end

-- An ordered list, not a map: the cases below are registered per tab, and `pairs` would register
-- them in a different order on different runs, which docs/test-cases.md cannot carry.
local TABS = {
  {
    name = "Background and border",
    blocks = { BORDER },
    order = concat({ { label = "Background texture" }, { label = "Background color" },
                     { label = "Use class color" } }, BORDER),
  },
  {
    name = "Accent bar",
    blocks = { BAR, BAR_BORDER },
    order = concat({ { label = "Enable accent bar" } }, BAR,
                   { { label = "Top" }, { label = "Bottom" }, { label = "Left" }, { label = "Right" } },
                   BAR_BORDER),
  },
}

local CONTROL_TYPES = { CheckBox = true, Slider = true, ColorPicker = true, Dropdown = true,
                        LSM30_Border = true, LSM30_Statusbar = true, LSM30_Background = true }

--- Register the LSM30_* widget types for the length of `fn`, then take them back out.
local function withLSMWidgets(fn)
  local gui = T.mocks.LibStub("AceGUI-3.0", true)
  local added = {}
  for _, wt in ipairs({ "LSM30_Border", "LSM30_Statusbar", "LSM30_Background" }) do
    if not gui.WidgetRegistry[wt] then
      added[#added + 1] = wt
      gui:RegisterWidgetType(wt, function() return T.mocks.__makeAceGUIWidget(wt) end, 1)
    end
  end
  local ok, err = pcall(fn)
  for _, wt in ipairs(added) do gui.WidgetRegistry[wt], gui.__widgetVersions[wt] = nil, nil end
  if not ok then error(err, 0) end
end

--- A Panels page on a fresh record, drawn on one tab: the controls it built, in order, and the
--- row (SimpleGroup) each one sits in.
local function renderTab(rec, tab)
  E.__setSelectedID(rec.id)
  local ctx = NS.Helpers.CreatePanel(nil, "Panels", { pageKey = "panels" })
  ctx.dropdowns, ctx.rebuilders = {}, {}
  ctx.refreshers = ctx.refreshers or {}
  E:BuildPage(ctx)
  local created = T.mocks.LibStub("AceGUI-3.0", true).__created
  local from = #created + 1
  ctx.activeTab = tab
  E:Rebuild(ctx)

  local controls, rowOf = {}, {}
  for i = from, #created do
    local w = created[i]
    if CONTROL_TYPES[w.type] and w.labelText then controls[#controls + 1] = w end
    if w.type == "SimpleGroup" then
      for _, child in ipairs(w.children or {}) do rowOf[child] = w end
    end
  end
  return ctx, controls, rowOf
end

--- The tooltip a control shows on hover: its title and its body.
local function tooltipOf(w)
  local saved, got = T.mocks.GameTooltip, {}
  T.mocks.GameTooltip = setmetatable({
    SetText = function(_, text) got.title = text end,
    AddLine = function(_, text) got.body = text end,
  }, { __index = function() return function() end end })
  local ok, err = pcall(w.__fire, w, "OnEnter")
  T.mocks.GameTooltip = saved
  if not ok then error(err, 0) end
  return got.title, got.body
end


local function colorOf(v)
  local c = NS.Util.Color(v)
  return { r = c[1], g = c[2], b = c[3], a = c[4] }
end

local function assertOpensOn(w, e, rec)
  local v = rec[e.field]
  if e.type == "ColorPicker" then
    local want = colorOf(v)
    for _, k in ipairs({ "r", "g", "b", "a" }) do
      assertNear(w.color and w.color[k], want[k], 1e-6, e.field .. " opened on the wrong " .. k)
    end
  else
    assertEqual(w.value, v, e.field .. " opened on the wrong value")
  end
end

--- Everything one block control is on its own: widget, width, tooltip, range, alpha, list, value.
local function assertControl(w, e, rec)
  assertEqual(w.type, e.type, e.label .. " (" .. e.field .. ") is the wrong widget")
  assertEqual(w.relativeWidth, 0.5, e.field .. " is not a half-width control")
  local title, body = tooltipOf(w)
  assertEqual(title, e.label, e.field .. "'s tooltip is titled wrongly")
  assertEqual(body, e.tip, e.field .. "'s tooltip body changed")
  if e.type == "Slider" then
    assertEqual(w.min, e.min, e.field .. " slider minimum")
    assertEqual(w.max, e.max, e.field .. " slider maximum")
    assertNear(w.step, e.step, 1e-9, e.field .. " slider step")
    assertTrue(not w.isPercent, e.field .. " renders as a percentage")
  end
  if e.type == "ColorPicker" then
    assertTrue(w.hasAlpha == true, e.field .. " lost its alpha channel")
  end
  if e.media then
    local names = NS.Compat.MediaList(e.media)
    assertEqual(table.concat(w.order or {}, ","), table.concat(names, ","),
      e.field .. " offers a different media list, or a different order")
    for _, name in ipairs(names) do
      assertEqual(w.list[name], name, e.field .. " labels '" .. name .. "' differently")
    end
  end
  assertOpensOn(w, e, rec)
end

--- One block's rows: [1][2] and [3][4] as two pairs, then this addon's own rows after them.
local function assertRows(spec, block, controls, rowOf)
  local first
  for i, e in ipairs(spec.order) do if e == block[1] then first = i break end end
  local w = function(k) return controls[first + k - 1] end
  assertTrue(rowOf[w(1)] ~= nil and rowOf[w(1)] == rowOf[w(2)],
    block[1].label .. " and " .. block[2].label .. " must share a row")
  assertTrue(rowOf[w(3)] == rowOf[w(4)], block[3].label .. " and its companion must share a row")
  assertTrue(rowOf[w(1)] ~= rowOf[w(3)], "the block's two pairs collapsed onto one row")
  assertTrue(rowOf[w(5)] ~= rowOf[w(3)], "an extra row joined the mandated pair")
  if block[6] then
    assertTrue(rowOf[w(5)] == rowOf[w(6)], block[5].label .. " and " .. block[6].label
      .. " must share a row")
  end
end

--- Fire one control the way a player would, and answer the value the record should now hold.
local function drive(w, e, rec)
  if e.media then
    w:__fire("OnValueChanged", "None")
    return "None"
  elseif e.type == "Slider" then
    local v = (e.max == 1) and 0.5 or 5
    w:__fire("OnMouseUp", v)
    return v
  elseif e.type == "CheckBox" then
    local v = not rec[e.field]
    w:__fire("OnValueChanged", v)
    return v
  else
    w:__fire("OnValueConfirmed", 0.1, 0.2, 0.3, 0.4)
    return { 0.1, 0.2, 0.3, 0.4 }
  end
end

local function assertHolds(rec, e, want)
  local got = NS.Registry:Get(rec.id)[e.field]
  if type(want) == "table" then
    for i = 1, 4 do
      assertNear(got[i], want[i], 1e-6, e.field .. " stored the wrong component " .. i)
    end
  elseif type(want) == "number" then
    assertNear(got, want, 1e-6, e.field .. " stored the wrong value")
  else
    assertEqual(got, want, e.field .. " stored the wrong value")
  end
end

--- A second value for a field, written from elsewhere, to prove the control follows the record.
local function elsewhere(e, rec)
  if e.media then return (rec[e.field] == "Solid") and "None" or "Solid" end
  if e.type == "Slider" then return (e.max == 1) and 0.25 or 3 end
  if e.type == "CheckBox" then return not rec[e.field] end
  return { 0.9, 0.8, 0.7, 0.6 }
end

for _, spec in ipairs(TABS) do
  local tab = spec.name
  test("optionsgroups: the " .. tab .. " tab draws its canonical blocks control by control (#48)",
  function()
    withLSMWidgets(function()
      NS.Registry:DeleteAll()
      local rec = NS.Registry:New("Characterized")
      local _, controls, rowOf = renderTab(rec, tab)

      -- The whole tab's control sequence, so a block moving, or a control appearing inside one, is red.
      -- Exact labels. The typed-out swatch gained a gray " (opacity)" while its companion was ticked
      -- (the accent bar's is ticked out of the box); the composed swatch keeps the canonical label and
      -- says it in its tooltip. That is the one label change the swap made, and it is named here.
      local labels = {}
      for i, w in ipairs(controls) do labels[i] = w.labelText end
      local want = {}
      for i, e in ipairs(spec.order) do want[i] = e.label end
      assertEqual(table.concat(labels, " | "), table.concat(want, " | "),
        tab .. " no longer draws its controls in the canonical order")

      for i, e in ipairs(spec.order) do
        if e.field then assertControl(controls[i], e, rec) end
      end

      -- Rows: the mandated four land as two pairs, and this addon's own rows after them.
      for _, block in ipairs(spec.blocks) do assertRows(spec, block, controls, rowOf) end

      -- Writes: every block control writes its own field, through NS.Registry:Set.
      local R = NS.Registry
      local realSet, calls = R.Set, {}
      R.Set = function(self, key, field, value)
        calls[#calls + 1] = { key = key, field = field }
        return realSet(self, key, field, value)
      end
      local ok, err = pcall(function()
        for i, e in ipairs(spec.order) do
          if e.field then
            local before = #calls
            local expected = drive(controls[i], e, R:Get(rec.id))
            assertTrue(#calls > before, e.field .. " did not write through NS.Registry:Set")
            assertEqual(calls[#calls].field, e.field, e.label .. " wrote to the wrong field")
            assertEqual(calls[#calls].key, rec.id, e.field .. " wrote to the wrong panel")
            assertHolds(rec, e, expected)
          end
        end
      end)
      R.Set = realSet
      if not ok then error(err, 0) end

      NS.Registry:DeleteAll()
      E.__setSelectedID(nil)
    end)
  end)

  test("optionsgroups: the " .. tab .. " blocks follow a write made elsewhere (#48)", function()
    withLSMWidgets(function()
      NS.Registry:DeleteAll()
      local rec = NS.Registry:New("Followed")
      local ctx, controls = renderTab(rec, tab)
      for i, e in ipairs(spec.order) do
        if e.field then
          local v = elsewhere(e, NS.Registry:Get(rec.id))
          assertTrue(NS.Registry:Set(rec.id, e.field, v), "the registry refused " .. e.field)
          for _, fn in ipairs(ctx.refreshers) do fn() end
          assertOpensOn(controls[i], e, NS.Registry:Get(rec.id))
        end
      end
      NS.Registry:DeleteAll()
      E.__setSelectedID(nil)
    end)
  end)
end
