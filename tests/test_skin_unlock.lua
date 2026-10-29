-- tests/test_skin_unlock.lua — the unlock overlay in the skin's colors (PM-03; inventory S6, S7).
--
-- PanelMaster's one on-screen surface of its own is the furniture an unlocked panel wears: the
-- outline and the name label (modules/Unlock.lua). The panels themselves are the player's content
-- and no skin repaints them (rollout E8, D1), so there are no fromSkin companions and no one-time
-- reset here. What this suite holds:
--
--   * the outline reads `list.dropLine` and draws, on Ka0s Default, the {1, 0.82, 0, 0.9} gold it
--     was typed as, byte for byte;
--   * a skin switch repaints the outline of every unlocked panel live (NS.Skin.OnLooksChanged ->
--     U:Reskin), and leaves a locked panel and the panel's own colors alone;
--   * the label is handed to the skin's `accent` text role once, at creation, which the library
--     records and repaints by itself.
--
-- After test_skin_literals; every case puts the skin back on Ka0s Default and locks everything.

local T = _G.PM_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
local OWNER = "PanelMaster"
local U, R, Canvas = NS.Unlock, NS.Registry, NS.Canvas

local function fmt(c) return ("%.3f %.3f %.3f %.3f"):format(c[1], c[2], c[3], c[4] or 1) end

local function fresh()
  mocks.__inCombat = false
  U:SetUnlocked(false)
  R:DeleteAll()
  Canvas:RenderAll()
end

--- Run `fn` on a clean slate and put Ka0s Default back, locked and empty, whatever `fn` raised.
local function clean(fn)
  return function()
    Skin:SetChoice(OWNER, "ka0s", "ka0s")
    fresh()
    local ok, err = pcall(fn)
    Skin:SetChoice(OWNER, "ka0s", "ka0s")
    fresh()
    if not ok then error(err, 0) end
  end
end

--- A panel named `name`, unlocked on its own, and its frame.
local function unlockedPanel(name)
  local rec = R:New(name)
  U:SetPanelUnlocked(rec.id, true)
  return rec, Canvas:FrameFor(rec.id)
end

local function edgeColors(f)
  local out = {}
  for side, tex in pairs(f.overlay.edges) do out[side] = tex.__color end
  return out
end

test("Skin unlock: the outline is today's gold on Ka0s Default", clean(function()
  local _, f = unlockedPanel("Outlined")
  assertTrue(f.overlay ~= nil, "unlocking built no overlay")
  local n = 0
  for side, c in pairs(edgeColors(f)) do
    n = n + 1
    assertTrue(c ~= nil, side .. ": the edge was never colored")
    assertEqual(fmt(c), fmt({ 1, 0.82, 0, 0.9 }), side .. ": Ka0s Default's outline moved")
  end
  assertEqual(n, 4, "the overlay has four edges")
end))

test("Skin unlock: the outline reads the skin's list.dropLine", clean(function()
  Skin:SetChoice(OWNER, "ka0s", "obsidian")
  local want = { NS.Skin.Color("list.dropLine") }
  assertTrue(want[1] ~= nil, "the obsidian skin answers no list.dropLine")
  local _, f = unlockedPanel("Obsidian")
  for side, c in pairs(edgeColors(f)) do
    assertEqual(fmt(c), fmt(want), side .. ": the outline did not take the skin's color")
  end
end))

test("Skin unlock: a skin switch repaints an unlocked panel's outline live", clean(function()
  local _, f = unlockedPanel("Live")
  Skin:SetChoice(OWNER, "ka0s", "obsidian")
  local want = { NS.Skin.Color("list.dropLine") }
  assertTrue(fmt(want) ~= fmt({ 1, 0.82, 0, 0.9 }),
    "obsidian's list.dropLine is Ka0s Default's, so this case could not see a missed repaint")
  -- No Render in between: the repaint is OnLooksChanged's alone.
  for side, c in pairs(edgeColors(f)) do
    assertEqual(fmt(c), fmt(want), side .. ": the switch left the old skin's outline")
  end
  Skin:SetChoice(OWNER, "ka0s", "ka0s")
  for side, c in pairs(edgeColors(f)) do
    assertEqual(fmt(c), fmt({ 1, 0.82, 0, 0.9 }), side .. ": switching back left obsidian's outline")
  end
end))

test("Skin unlock: the repaint touches unlocked panels only, and never the panel's own colors",
  clean(function()
    local open, fo = unlockedPanel("Open")
    local shut = R:New("Shut")
    U:SetPanelUnlocked(shut.id, true)
    U:SetPanelUnlocked(shut.id, false)
    local fs = Canvas:FrameFor(shut.id)
    assertTrue(fs.overlay ~= nil, "the once-unlocked panel kept no overlay to test")
    local before = fmt(fs.overlay.edges.TOP.__color)
    local fill = fmt(fo.bg.__color)
    assertEqual(U:Reskin(), 1, "Reskin painted a panel that is not unlocked")
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    assertEqual(fmt(fs.overlay.edges.TOP.__color), before, "a locked panel's hidden outline was repainted")
    assertEqual(fmt(fo.bg.__color), fill, "the skin repainted the player's own panel fill (E8)")
    U:SetPanelUnlocked(open.id, false)
  end))

test("Skin unlock: the label takes the skin's accent text role once, at creation", clean(function()
  local real, calls = NS.Skin.Text, {}
  NS.Skin.Text = function(fs, role) calls[#calls + 1] = { fs = fs, role = role } end
  local ok, err = pcall(function()
    local rec, f = unlockedPanel("Labeled")
    assertEqual(#calls, 1, "the label was not handed to S.Text exactly once")
    assertTrue(calls[1].fs == f.overlay.label, "S.Text painted something other than the label")
    assertEqual(calls[1].role, "accent")
    U:SetPanelUnlocked(rec.id, false)
    U:SetPanelUnlocked(rec.id, true)
    Canvas:Render(rec.id)
    assertEqual(#calls, 1, "a re-decorate painted the label again (the library repaints it)")
  end)
  NS.Skin.Text = real
  if not ok then error(err, 0) end
end))
