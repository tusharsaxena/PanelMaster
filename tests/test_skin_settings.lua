-- tests/test_skin_settings.lua — this addon's own AceGUI acquisitions on the skin (PM-04;
-- core/SkinSetup.lua's NS.SkinPaintAce / NS.SkinPaintAceTree over LibKa0s-Skin-1.0's SkinAce,
-- skinning-§3).
--
-- What this pins: the Panels editor acquires from AceGUI itself, past the Options instance's owner
-- proxy (settings/PanelEditor.lua, settings/PanelEditorTabs.lua), so every widget it draws of a
-- painted type is painted for this owner when the Scope paints the settings panel, and none is
-- while the panel is ignored (a new profile's default, so Ka0s Default draws what it drew before);
-- a release hands each back stock; the page band's picker and create box, built once for the
-- session, follow a skin switch and the Scope in place; the Profiles page paints the tree
-- AceConfigDialog drew after every Open; and the degraded seam paints nothing. LootHistory's
-- tests/test_skin_settings.lua is the pattern.
--
-- The kit's widgets are recorders without AceGUI's regions, so "painted" is read where the library
-- keeps it: `Skin.__ace[widget].owner` (SkinAce.lua's weak state table), set while owned and
-- cleared by the restore. After tests/test_skin_picker.lua; leaves the skin on Ka0s Default with
-- the settings panel ignored, as a new profile has it.

local T = _G.PM_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
local AceGUI = mocks.LibStub("AceGUI-3.0", true)
local E = NS.PanelEditor
local OWNER = "PanelMaster"

-- The types SkinAce has a painter for among what the editor draws; a SimpleGroup has none and the
-- LSM30 pickers are stock by the library's rule.
local PAINTED = { CheckBox = true, Dropdown = true, EditBox = true, Slider = true, Heading = true,
                  Label = true, ColorPicker = true }

local function ownerOf(w)
  local st = Skin.__ace and Skin.__ace[w]
  return st and st.owner or nil
end

--- Back on Ka0s Default, stored and applied, the settings panel ignored (the profile default).
local function reset()
  NS.WriteSkinChoice("ka0s", "ka0s", { panel = true, fonts = false })
  Skin:SetChoice(OWNER, "ka0s", "ka0s")
  Skin:SetIgnore(OWNER, true, false)
  mocks.__fireTimers()
end

--- Run `fn` on `skin` with the settings panel painted (`panelIgnored` false) or the client's
--- (true), and one panel to edit; put everything back whatever `fn` raised.
local function onSkin(skin, panelIgnored, fn)
  return function()
    reset()
    NS.Registry:DeleteAll()
    local rec = NS.Registry:New("Skinned")
    E.__setSelectedID(rec.id)
    local ok, err = pcall(function()
      Skin:SetIgnore(OWNER, panelIgnored, false)
      NS.ApplySkinChoice("ka0s", skin)
      fn(rec)
    end)
    NS.Registry:DeleteAll()
    E.__setSelectedID(nil)
    reset()
    if not ok then error(err, 0) end
  end
end

--- A Panels page context of its own (tests/test_panels_page.lua's freshPanelsCtx), built and
--- rendered on `tab`; answers the ctx and every widget of a painted type the render acquired.
local function renderEditor(tab)
  local created = AceGUI.__created
  local from = #created + 1
  local ctx = NS.Helpers.CreatePanel(nil, "Panels", { pageKey = "panels" })
  ctx.dropdowns, ctx.rebuilders = {}, {}
  ctx.refreshers = ctx.refreshers or {}
  E:BuildPage(ctx)
  ctx.activeTab = tab
  E:Rebuild(ctx)
  local out = {}
  for i = from, #created do
    local w = created[i]
    if PAINTED[w.type] then out[#out + 1] = w end
  end
  return ctx, out
end

local TABS = { "General", "Size and position", "Background and border", "Accent bar", "Artwork",
               "Opacity and fade" }

-- ── the editor ──────────────────────────────────────────────────────────────────────────────────

test("skin settings: with the panel painted, every editor widget is painted for this owner", onSkin("obsidian", false, function()
  -- red under: dropping NS.SkinPaintAce from either editor file's acquire (the raw AceGUI handle
  -- paints nothing of its own).
  for _, tab in ipairs(TABS) do
    local _, ws = renderEditor(tab)
    assertTrue(#ws > 0, tab .. " acquired no widget of a painted type")
    for _, w in ipairs(ws) do
      assertEqual(ownerOf(w), OWNER, tab .. ": a " .. w.type .. " is painted for this owner")
      assertTrue(type(rawget(w, "OnRelease")) == "function", tab .. ": its release is wrapped")
    end
  end
end))

test("skin settings: Ka0s Default paints the editor like every other skin once the panel is", onSkin("ka0s", false, function()
  local _, ws = renderEditor("Background and border")
  assertTrue(#ws > 0)
  for _, w in ipairs(ws) do assertEqual(ownerOf(w), OWNER, "a " .. w.type .. " is painted") end
end))

test("skin settings: with the panel ignored (the default) the editor is left stock", onSkin("obsidian", true, function()
  -- The Scope's Ignore settings panel is on for a new profile, so Ka0s Default draws the editor
  -- exactly as it did before the skin seam. red under: an acquire that paints past the Scope.
  local _, ws = renderEditor("Accent bar")
  assertTrue(#ws > 0)
  for _, w in ipairs(ws) do assertEqual(ownerOf(w), nil, "a " .. w.type .. " was painted") end
end))

test("skin settings: a release hands every painted editor widget back stock", onSkin("obsidian", false, function()
  local _, ws = renderEditor("Opacity and fade")
  for _, w in ipairs(ws) do
    assertEqual(ownerOf(w), OWNER, "owned before the release")
    if not w.__released then AceGUI:Release(w) end
    assertEqual(ownerOf(w), nil, "nothing of this owner rides it to the next acquirer")
    assertEqual(rawget(w, "OnRelease"), nil, "the wrapper is taken back")
  end
end))

-- ── the band, held for the session ──────────────────────────────────────────────────────────────

test("skin settings: the band's picker and create box follow the Scope and a switch in place", onSkin("obsidian", true, function()
  -- The band is built once and never released, so nothing re-acquires it. red under: dropping the
  -- OnLooksChanged repaint in settings/PanelEditor.lua.
  local ctx = renderEditor("General")
  local picker, box = ctx.__pmPicker, ctx.__pmNewBox
  assertTrue(picker ~= nil and box ~= nil, "the band parked its picker and create box")
  assertEqual(ownerOf(picker), nil, "stock while the panel is ignored")
  NS.ApplySkinIgnore(false, nil)
  assertEqual(ownerOf(picker), OWNER, "the picker is painted when the Scope paints the panel")
  assertEqual(ownerOf(box), OWNER, "and the create box")
  NS.ApplySkinChoice("ka0s", "ka0s")
  assertEqual(ownerOf(picker), OWNER, "a switch repaints it for the same owner")
  NS.ApplySkinIgnore(true, nil)
  assertEqual(ownerOf(picker), nil, "the Scope hands it back stock, live")
  assertEqual(ownerOf(box), nil)
end))

-- ── the Profiles page ───────────────────────────────────────────────────────────────────────────

test("skin settings: the Profiles page paints the tree AceConfigDialog drew, after every Open", onSkin("obsidian", false, function()
  -- red under: dropping NS.SkinPaintAceTree from the Profiles renderer, or running it once only.
  local dialog = mocks.LibStub("AceConfigDialog-3.0", true)
  local open = dialog.Open
  local drawn = {}
  dialog.Open = function(self, app, container)
    open(self, app, container)
    container:ReleaseChildren()
    local row = AceGUI:Create("CheckBox")
    drawn[#drawn + 1] = row
    container:AddChild(row)
  end
  local ok, err = pcall(function()
    local panel = mocks.__settingsPanels["Profiles"]
    for _ = 1, 2 do
      panel:Show()
      panel:GetScript("OnShow")(panel)
    end
  end)
  dialog.Open = open
  if not ok then error(err, 0) end
  assertEqual(#drawn, 2, "the page re-opened the dialog on each show")
  for i, row in ipairs(drawn) do
    assertEqual(ownerOf(row), OWNER, "Open " .. i .. ": the drawn row is painted for this owner")
    AceGUI:Release(row)
  end
end))

-- ── the degraded seam ───────────────────────────────────────────────────────────────────────────

test("skin settings: degraded, PaintAce and PaintAceTree paint nothing", function()
  local dns, dm = dofile("tests/degraded_env.lua").loadDegraded()
  local w = dm.LibStub("AceGUI-3.0", true):Create("CheckBox")
  assertEqual(dns.SkinPaintAce(w), false, "PaintAce is a no-op")
  assertEqual(dns.SkinPaintAceTree(w), 0, "PaintAceTree paints nothing")
end)
