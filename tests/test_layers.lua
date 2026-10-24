local T = _G.PM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local C, R, U, Canvas = NS.Constants, NS.Registry, NS.Unlock, NS.Canvas

-- Frame layering (frame-layering-§1..§5): where every frame this addon creates sits, read back
-- through the kit's opt-in frame-layer recorder (tests/_kit/mock_layers.lua). The table every write
-- reads is core/Constants.lua's NS.Constants.LAYERS.
--
-- Panel frames are pooled BY NAME, so a frame built before the recorder was installed answers from
-- the base mock. Every case that reads layers therefore makes panels under names no other suite
-- uses, inside withLayers, so the frames are created fresh with the recorder's methods on them.

local LAYERS = C.LAYERS

local function fresh()
  M.__inCombat = false
  U:SetUnlocked(false)
  R:DeleteAll()
  Canvas:RenderAll()
end

-- This addon's own mock CreateFrame (tests/wow_mock.lua) records the frame's name but not its
-- parent, and the recorder reads inheritance through `__parent`. So the parent is recorded first,
-- under the recorder, for the frames these cases build.
local function withLayers(body)
  local plain = M.CreateFrame
  M.CreateFrame = function(kind, name, parent, ...)
    local f = plain(kind, name, parent, ...)
    if type(f) == "table" then rawset(f, "__parent", parent) end
    return f
  end
  local restore = dofile("tests/_kit/mock_layers.lua")(M)
  local ok, err = pcall(body)
  restore()
  M.CreateFrame = plain
  fresh()
  if not ok then error(err, 0) end
end

local probes = 0
local function probe(fields)
  probes = probes + 1
  return R:New("LayersProbe" .. probes, fields)
end

local function explicit(frame) return rawget(frame, "__level") end

-- ── the table ────────────────────────────────────────────────────────────────────────────────

test("LAYERS names the strata this addon writes or compares against", function()
  assertEqual(type(LAYERS), "table", "NS.Constants.LAYERS is missing")
  assertEqual(LAYERS.STRATA.BACKDROP, "LOW")
  assertEqual(LAYERS.STRATA.CHROME, "HIGH")
  assertEqual(LAYERS.STRATA.MODAL, "DIALOG")
  -- The template's strata IS the backdrop tier, so a new panel and a new frame agree.
  assertEqual(C.PANEL_TEMPLATE.strata, LAYERS.STRATA.BACKDROP)
end)

test("LAYERS: the panel ladder is strictly increasing and ends under the stride (PAN-Z01, Z08)", function()
  local L = LAYERS.LEVEL
  local ladder = { "ART_BELOW_BG", "BG", "ART_ABOVE_BG", "BORDER", "ACCENT", "ACCENT_BAR",
                   "ACCENT_BAR_BORDER", "ART_ABOVE_ALL", "UNLOCK" }
  local prev = 0
  for _, k in ipairs(ladder) do
    assertEqual(type(L[k]), "number", "LAYERS.LEVEL." .. k .. " is not a number")
    assertTrue(L[k] > prev, ("LAYERS.LEVEL.%s (%d) is not above the rung under it (%d)")
      :format(k, L[k], prev))
    prev = L[k]
  end
  assertEqual(LAYERS.PANEL_STRIDE, L.UNLOCK + 1, "the stride is derived from the top rung")
  assertTrue(L.UNLOCK < LAYERS.PANEL_STRIDE)
  -- Above-all art is above the accent bar's own border, which is the point of Z01.
  assertTrue(L.ART_ABOVE_ALL > L.ACCENT_BAR_BORDER)
  -- The stored artLayer token maps onto the ladder; no stored value moves.
  assertEqual(C.ART_FRAME_LEVEL.BELOW_BG, L.ART_BELOW_BG)
  assertEqual(C.ART_FRAME_LEVEL.ABOVE_BG, L.ART_ABOVE_BG)
  assertEqual(C.ART_FRAME_LEVEL.ABOVE_ALL, L.ART_ABOVE_ALL)
end)

test("LAYERS: the highest panel level's whole stack fits the client's level ceiling", function()
  assertTrue(C.MAX_PANEL_LEVEL * LAYERS.PANEL_STRIDE + LAYERS.LEVEL.UNLOCK < 10000)
end)

-- ── the panel root ───────────────────────────────────────────────────────────────────────────

test("a new panel frame states the backdrop strata at creation, then takes its own (PAN-Z07)", function()
  withLayers(function()
    local calls
    local layered = M.CreateFrame
    M.CreateFrame = function(kind, name, ...)
      local f = layered(kind, name, ...)
      if type(name) == "string" and name:find("^PanelMaster_Panel_") then
        calls = {}
        local set = f.SetFrameStrata
        rawset(f, "SetFrameStrata", function(self, s)
          calls[#calls + 1] = s
          return set(self, s)
        end)
      end
      return f
    end
    local ok, err = pcall(probe, { strata = "HIGH" })
    M.CreateFrame = layered
    if not ok then error(err, 0) end
    assertTrue(calls ~= nil, "no panel frame was created")
    assertEqual(calls[1], LAYERS.STRATA.BACKDROP, "the first strata write is not the backdrop tier")
    assertEqual(calls[#calls], "HIGH", "the record's strata is not the last word")
  end)
end)

test("a panel root is not toplevel, not clamped, and sits at level x stride", function()
  withLayers(function()
    local rec = probe({ level = 3, strata = "MEDIUM" })
    local f = Canvas:FrameFor(rec.id)
    local s = M.__layers(f)
    assertEqual(s.strata, "MEDIUM")
    assertEqual(s.level, 3 * LAYERS.PANEL_STRIDE)
    assertFalse(s.toplevel, "a backdrop must not rise over its peers on a click")
    assertFalse(s.clamped, "a panel may legitimately hang off the screen edge")
  end)
end)

-- ── the ladder ───────────────────────────────────────────────────────────────────────────────

test("every child frame takes an explicit rung of the ladder, accent bars and their border included (PAN-Z02, Z08)", function()
  withLayers(function()
    local rec = probe({ artTexture = "class-warrior", artLayer = "ABOVE_ALL", borderSize = 4,
                        accentEnabled = true, accentBorderSize = 1, accentOffset = -2, level = 2 })
    local f = Canvas:FrameFor(rec.id)
    local L, base = LAYERS.LEVEL, f:GetFrameLevel()
    local want = {
      { f.bgFrame, L.BG, "background fill" },
      { f.borderFrame, L.BORDER, "border" },
      { f.accentFrame, L.ACCENT, "accent container" },
      { f.artFrame, L.ART_ABOVE_ALL, "above-all artwork" },
    }
    for _, edge in ipairs(C.EDGES) do
      want[#want + 1] = { f.accents[edge], L.ACCENT_BAR, edge .. " accent bar" }
    end
    local bordered = 0
    for _, edge in ipairs(C.EDGES) do
      local b = f.accents[edge].borderFrame
      if b then
        bordered = bordered + 1
        want[#want + 1] = { b, L.ACCENT_BAR_BORDER, edge .. " accent bar border" }
      end
    end
    assertTrue(bordered > 0, "no accent bar built its border, so the border rung went unchecked")
    for _, w in ipairs(want) do
      assertTrue(explicit(w[1]) ~= nil, w[3] .. " has no explicit level (it would default to parent + 1)")
      assertEqual(w[1]:GetFrameLevel(), base + w[2], w[3])
      assertEqual(M.__layers(w[1]).strata, M.__layers(f).strata, w[3] .. " left the panel's strata")
    end
  end)
end)

test("the accent rungs follow the panel when its level changes", function()
  withLayers(function()
    local rec = probe({ accentEnabled = true, accentBorderSize = 1 })
    R:Set(rec.id, "level", 9)
    local f = Canvas:FrameFor(rec.id)
    local L, base = LAYERS.LEVEL, f:GetFrameLevel()
    assertEqual(base, 9 * LAYERS.PANEL_STRIDE)
    for _, edge in ipairs(C.EDGES) do
      assertEqual(f.accents[edge]:GetFrameLevel(), base + L.ACCENT_BAR, edge)
      local b = f.accents[edge].borderFrame
      if b then assertEqual(b:GetFrameLevel(), base + L.ACCENT_BAR_BORDER, edge .. " border") end
    end
  end)
end)

-- ── the unlock overlay (T2 edit chrome) ──────────────────────────────────────────────────────

test("U.ChromeStrata lifts to HIGH and never below the panel (PAN-Z04)", function()
  assertEqual(U.ChromeStrata("BACKGROUND"), "HIGH")
  assertEqual(U.ChromeStrata("LOW"), "HIGH")
  assertEqual(U.ChromeStrata("MEDIUM"), "HIGH")
  assertEqual(U.ChromeStrata("HIGH"), "HIGH")
  assertEqual(U.ChromeStrata("DIALOG"), "DIALOG")
  assertEqual(U.ChromeStrata("FULLSCREEN"), "FULLSCREEN")
  assertEqual(U.ChromeStrata("TOOLTIP"), "TOOLTIP")
end)

test("an unlocked LOW panel's overlay floats at HIGH while the panel stays LOW (PAN-Z04)", function()
  withLayers(function()
    local rec = probe({ strata = "LOW" })
    U:SetPanelUnlocked(rec.id, true)
    local f = Canvas:FrameFor(rec.id)
    local o = M.__layers(f.overlay.frame)
    assertEqual(M.__layers(f).strata, "LOW", "unlocking moved the panel itself")
    assertEqual(o.strata, "HIGH")
    assertTrue(o.fixedStrata, "a child given its own strata must be fixed (frame-layering-§2)")
    assertEqual(f.overlay.frame:GetFrameLevel(), f:GetFrameLevel() + LAYERS.LEVEL.UNLOCK)
    assertFalse(f.overlay.frame:IsMouseEnabled(), "the HIGH floor holds only for mouse-off chrome")
  end)
end)

test("the overlay of a FULLSCREEN panel stays FULLSCREEN, and follows a strata change (PAN-Z04)", function()
  withLayers(function()
    local rec = probe({ strata = "FULLSCREEN" })
    U:SetPanelUnlocked(rec.id, true)
    local f = Canvas:FrameFor(rec.id)
    assertEqual(M.__layers(f.overlay.frame).strata, "FULLSCREEN")
    R:Set(rec.id, "strata", "BACKGROUND")
    assertEqual(M.__layers(f.overlay.frame).strata, "HIGH")
    R:Set(rec.id, "strata", "TOOLTIP")
    assertEqual(M.__layers(f.overlay.frame).strata, "TOOLTIP")
  end)
end)

test("locking puts the overlay back in the panel's strata, unfixed (PAN-Z04)", function()
  withLayers(function()
    local rec = probe({ strata = "LOW" })
    U:SetPanelUnlocked(rec.id, true)
    U:SetPanelUnlocked(rec.id, false)
    local f = Canvas:FrameFor(rec.id)
    local o = M.__layers(f.overlay.frame)
    assertEqual(o.strata, "LOW")
    assertFalse(o.fixedStrata)
  end)
end)

-- ── the addon's own confirmations stay answerable (PAN-Z05) ──────────────────────────────────

local POPUPS = { "KA0S_PANELMASTER_RESETALL", "KA0S_PANELMASTER_DELETEALL",
                 "KA0S_PANELMASTER_DELETE", "KA0S_PANELMASTER_RESET" }

test("every confirmation popup yields the mouse from unlocked DIALOG-and-up panels while shown", function()
  for _, key in ipairs(POPUPS) do
    fresh()
    local dlg = M.StaticPopupDialogs[key]
    assertTrue(dlg ~= nil, key .. " is not registered")
    assertEqual(type(dlg.OnShow), "function", key .. " has no OnShow")
    assertEqual(type(dlg.OnHide), "function", key .. " has no OnHide")
    local high = probe({ strata = "DIALOG" })
    local top = probe({ strata = "TOOLTIP" })
    local low = probe({ strata = "LOW" })
    U:SetUnlocked(true)
    local hf, tf, lf = Canvas:FrameFor(high.id), Canvas:FrameFor(top.id), Canvas:FrameFor(low.id)
    assertTrue(hf:IsMouseEnabled(), "an unlocked panel takes the drag")
    dlg.OnShow()
    assertFalse(hf:IsMouseEnabled(), key .. ": a DIALOG panel still swallows the popup's clicks")
    assertFalse(tf:IsMouseEnabled(), key .. ": a TOOLTIP panel still swallows the popup's clicks")
    assertTrue(lf:IsMouseEnabled(), key .. ": a LOW panel cannot cover the popup and keeps the drag")
    -- A repaint while the popup is up does not re-arm it.
    Canvas:RenderAll()
    assertFalse(hf:IsMouseEnabled(), key .. ": a render re-armed the panel under the popup")
    dlg.OnHide()
    assertTrue(hf:IsMouseEnabled(), key .. ": the panel was not re-armed when the popup closed")
    assertTrue(tf:IsMouseEnabled())
  end
  fresh()
end)

test("two popups up at once: the panels re-arm only when the last one closes", function()
  fresh()
  local a = M.StaticPopupDialogs.KA0S_PANELMASTER_DELETE
  local b = M.StaticPopupDialogs.KA0S_PANELMASTER_RESETALL
  local rec = probe({ strata = "FULLSCREEN" })
  U:SetUnlocked(true)
  local f = Canvas:FrameFor(rec.id)
  a.OnShow(); b.OnShow()
  a.OnHide()
  assertFalse(f:IsMouseEnabled(), "the first popup to close re-armed a panel the second still needs")
  b.OnHide()
  assertTrue(f:IsMouseEnabled())
  -- An unmatched hide never drives the count below zero.
  b.OnHide()
  a.OnShow()
  assertFalse(f:IsMouseEnabled())
  a.OnHide()
  assertTrue(f:IsMouseEnabled())
  fresh()
end)

test("a locked panel is not touched by a popup", function()
  fresh()
  local rec = probe({ strata = "DIALOG" })
  local f = Canvas:FrameFor(rec.id)
  local dlg = M.StaticPopupDialogs.KA0S_PANELMASTER_DELETE
  dlg.OnShow()
  assertFalse(f:IsMouseEnabled())
  dlg.OnHide()
  assertFalse(f:IsMouseEnabled(), "closing a popup armed a locked panel")
  fresh()
end)

-- ── strata rows' tooltips (PAN-Z06, Z03b) ────────────────────────────────────────────────────

local function readFile(path)
  local fh = assert(io.open(path, "rb"))
  local body = fh:read("*a")
  fh:close()
  return body
end

test("the Default frame strata row's tooltip is the library's O.StrataTooltip over its values", function()
  local row
  for _, r in ipairs(NS.Schema.Schema) do
    if r.path == "settings.defaultStrata" then row = r end
  end
  assertTrue(row ~= nil, "no settings.defaultStrata row")
  local tip = NS.Helpers.StrataTooltip(C.STRATA)
  assertTrue(tip ~= "", "the live library answered an empty strata tooltip")
  assertTrue(row.tooltip:sub(-#tip) == tip,
    "the row's tooltip does not end on O.StrataTooltip(C.STRATA): " .. tostring(row.tooltip))
end)

test("the panel editor's Frame strata row reads O.StrataTooltip, and Frame level says panels interleave", function()
  local src = readFile("settings/PanelEditorTabs.lua")
  assertTrue(src:find('tokenDropdown%(anchorRow, "Frame strata", "strata", C%.STRATA,%s*O%.StrataTooltip%(C%.STRATA%)%)') ~= nil,
    "the Frame strata dropdown does not take O.StrataTooltip(C.STRATA)")
  assertTrue(src:find("interleave", 1, true) ~= nil,
    "the Frame level tooltip does not say equal levels interleave (PAN-Z03b)")
  assertTrue(src:find("no guaranteed order", 1, true) == nil,
    "the Frame level tooltip still understates equal levels as 'no guaranteed order'")
end)

-- ── one table, read everywhere (frame-layering-§5) ───────────────────────────────────────────

test("every strata and level write in the addon reads LAYERS", function()
  for _, path in ipairs({ "modules/Canvas.lua", "modules/Unlock.lua", "core/Constants.lua",
                          "settings/Slash.lua", "settings/PanelEditor.lua",
                          "settings/PanelEditorTabs.lua", "settings/Panel.lua" }) do
    local n = 0
    for line in readFile(path):gmatch("[^\n]+") do
      if not line:match("^%s*%-%-") then
        assertTrue(not line:find('SetFrameStrata%("'), path .. ": a literal strata: " .. line)
        if line:find("SetFrameLevel%(") then
          n = n + 1
          assertTrue(not line:find("SetFrameLevel%(%s*%d"), path .. ": an absolute level: " .. line)
          assertTrue(line:find("LAYERS", 1, true) ~= nil or line:find("art%.level") ~= nil,
            path .. ": a level that does not name a LAYERS rung: " .. line)
        end
      end
    end
    if path == "modules/Canvas.lua" then assertTrue(n >= 6, "Canvas lost its level writes") end
  end
end)
