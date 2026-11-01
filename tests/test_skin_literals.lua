-- tests/test_skin_literals.lua — the cases around the typed-value gate that the gate cannot be.
--
-- The gate itself is the kit's since revision 50 (tests/_kit/test_skin_values.lua, skinning-§1,
-- anti-pattern #107), wired through Kit.skinValues in tests/run.lua; this suite held a copy of it
-- until then. What stays is what a scan of the source cannot see: that the seam's host copy of Ka0s
-- Default (NS.SKIN_FALLBACK) and NS.SkinEscape keep the bytes they replaced, and that the settings
-- pages' typed markup follows the skin with the Scope cleared and stays stock while the panel is
-- ignored. The skin-switch half of the same surfaces is declared in tests/skin_surfaces.lua.

local T = _G.PM_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- ── the seam's helpers and the host copy ─────────────────────────────────────────────────────

local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
local OWNER = "PanelMaster"

--- Run `fn` on `skin`, then put Ka0s Default back whatever `fn` raised.
local function onSkin(skin, fn)
  Skin:SetChoice(OWNER, "ka0s", skin)
  local ok, err = pcall(fn)
  Skin:SetChoice(OWNER, "ka0s", "ka0s")
  if not ok then error(err, 0) end
end

test("Skin literals: the host copy of Ka0s Default equals the library's Ka0s Default", function()
  onSkin("ka0s", function()
    local n = 0
    for name, c in pairs(NS.SKIN_FALLBACK) do
      n = n + 1
      local r, g, b, a = NS.Skin.Color(name)
      assertTrue(r ~= nil, name .. ": the library answers no such color token")
      assertEqual(("%.3f %.3f %.3f %.3f"):format(r, g, b, a or 1),
        ("%.3f %.3f %.3f %.3f"):format(c[1], c[2], c[3], c[4] or 1),
        name .. ": the degraded facade's copy drifted from the library")
    end
    assertTrue(n > 0, "NS.SKIN_FALLBACK is empty, but the disabled marker reads text.disabled")
  end)
end)

test("Skin literals: NS.SkinEscape keeps the bytes of the literal it replaced", function()
  onSkin("ka0s", function()
    assertEqual(NS.SkinEscape("text.disabled"), "|cff808080",
      "Ka0s Default's disabled gray is the |cff808080 the marker was typed as")
    assertEqual(NS.SkinEscape("no.such.token"), nil)
  end)
end)

-- ── the Panels page picker's "(disabled)" marker (inventory S12) ──────────────────────────────

local E = NS.PanelEditor

--- The picker's entry for a disabled panel, built on a fresh Panels page under `skin`.
local function disabledEntry(skin)
  local entry
  onSkin(skin, function()
    NS.Registry:DeleteAll()
    local rec = NS.Registry:New("Dimmed", { enabled = false })
    E.__setSelectedID(rec.id)
    local ctx = NS.Helpers.CreatePanel(nil, "Panels", { pageKey = "panels" })
    ctx.dropdowns, ctx.rebuilders = {}, {}
    ctx.refreshers = ctx.refreshers or {}
    E:BuildPage(ctx)
    E:Rebuild(ctx)
    assertTrue(ctx.__pmPicker ~= nil and ctx.__pmPicker.list ~= nil, "the page drew no panel picker")
    entry = ctx.__pmPicker.list[rec.id]
    NS.Registry:DeleteAll()
    E.__setSelectedID(nil)
  end)
  return entry
end

test("Skin literals: the picker's (disabled) marker is today's gray on Ka0s Default", function()
  assertEqual(disabledEntry("ka0s"), "Dimmed |cff808080(disabled)|r")
end)

--- Run `fn` with the owner's applied "Ignore settings panel" set to `panel`, then put back the
--- exceptions it found, whatever `fn` raised.
local function withPanelIgnored(panel, fn)
  local was, fonts = Skin:GetIgnore(OWNER)
  Skin:SetIgnore(OWNER, panel, fonts)
  local ok, err = pcall(fn)
  Skin:SetIgnore(OWNER, was, fonts)
  if not ok then error(err, 0) end
end

test("Skin literals: the picker's (disabled) marker follows the skin's text.disabled", function()
  withPanelIgnored(false, function()
    local want
    onSkin("obsidian", function() want = NS.SkinEscape("text.disabled") end)
    assertTrue(want ~= nil and want ~= "|cff808080",
      "the obsidian skin's text.disabled is Ka0s Default's, so this case could not see a miss")
    assertEqual(disabledEntry("obsidian"), "Dimmed " .. want .. "(disabled)|r")
  end)
end)

-- Change that turns this red: building the marker from NS.SkinEscape (the worn skin) instead of
-- NS.SkinPanelEscape, so the one settings-page value leaks past Ignore settings panel (review PM-02).
test("Skin literals: the picker's (disabled) marker stays today's gray while the panel is ignored",
  function()
    withPanelIgnored(true, function()
      assertEqual(disabledEntry("obsidian"), "Dimmed |cff808080(disabled)|r",
        "the ignored settings panel took the worn skin's disabled gray")
    end)
  end)

-- ── the editor tooltips' inline emphasis (cause L5, FS-PM-FIX) ──────────────────────────────────

--- The Panel name row's tooltip body on a fresh editor under `skin`, read through a recording
--- GameTooltip, which is what O.AttachTooltip draws into.
local function nameTooltip(skin)
  local body
  onSkin(skin, function()
    NS.Registry:DeleteAll()
    local rec = NS.Registry:New("Emphasis", {})
    E.__setSelectedID(rec.id)
    local ctx = NS.Helpers.CreatePanel(nil, "Panels", { pageKey = "panels" })
    ctx.dropdowns, ctx.rebuilders = {}, {}
    ctx.refreshers = ctx.refreshers or {}
    E:BuildPage(ctx)
    local list = mocks.LibStub("AceGUI-3.0", true).__created
    local from = #list + 1
    E:Rebuild(ctx)
    local box
    for i = from, #list do
      if list[i].labelText == "Panel name" then box = list[i] end
    end
    assertTrue(box ~= nil, "the editor drew no Panel name row")
    local saved = mocks.GameTooltip
    mocks.GameTooltip = setmetatable({
      AddLine = function(_, text) body = text end,
    }, { __index = function() return function() end end })
    local ok, err = pcall(box.__fire, box, "OnEnter")
    mocks.GameTooltip = saved
    NS.Registry:DeleteAll()
    E.__setSelectedID(nil)
    assertTrue(ok, tostring(err))
  end)
  return body
end

-- Change that turns these red: typing |cffffff00 back into settings/PanelEditorTabs.lua (the first
-- case and the kit's gate), or building the word from NS.SkinEscape (the third).
test("Skin literals: the editor tooltips' emphasis is today's yellow on Ka0s Default", function()
  withPanelIgnored(false, function()
    assertTrue(nameTooltip("ka0s"):find("|cffffff00", 1, true) ~= nil)
  end)
end)

test("Skin literals: the editor tooltips' emphasis follows gtip.emphasis with the Scope cleared",
  function()
    withPanelIgnored(false, function()
      local want
      onSkin("obsidian", function() want = NS.SkinEscape("gtip.emphasis") end)
      assertTrue(want ~= nil and want ~= "|cffffff00",
        "the obsidian skin's gtip.emphasis is Ka0s Default's, so this case could not see a miss")
      assertTrue(nameTooltip("obsidian"):find(want, 1, true) ~= nil,
        "the tooltip did not draw the worn skin's emphasis")
    end)
  end)

test("Skin literals: the editor tooltips' emphasis stays today's yellow while the panel is ignored",
  function()
    withPanelIgnored(true, function()
      assertTrue(nameTooltip("obsidian"):find("|cffffff00", 1, true) ~= nil,
        "the ignored settings panel took the worn skin's emphasis")
    end)
  end)

-- ── the editor's subsection headings (cause L4, FS-PM-FIX) ─────────────────────────────────────

-- Change that turns this red: setting the label's font object directly, which the skin cannot see,
-- so with the Scope cleared the heading drops the skin's face at the first paint's stock font.
test("Skin fonts: an editor heading sets its font through O.LabelFont, so the skin keeps its face",
  function()
    withPanelIgnored(false, function()
      NS.Registry:DeleteAll()
      local rec = NS.Registry:New("Heading", {})
      E.__setSelectedID(rec.id)
      local ctx = NS.Helpers.CreatePanel(nil, "Panels", { pageKey = "panels" })
      ctx.dropdowns, ctx.rebuilders = {}, {}
      ctx.refreshers = ctx.refreshers or {}
      E:BuildPage(ctx)
      -- The mock's Heading has no font object to set, so the seam's call is what can be seen.
      local seen, real = 0, NS.Helpers.LabelFont
      NS.Helpers.LabelFont = function(w, font)
        if w.type == "Heading" and font == "GameFontNormalLarge" then seen = seen + 1 end
        return real(w, font)
      end
      local ok, err = pcall(function() ctx.activeTab = E.TABS[2]; E:Rebuild(ctx) end)
      NS.Helpers.LabelFont = real
      NS.Registry:DeleteAll()
      E.__setSelectedID(nil)
      assertTrue(ok, tostring(err))
      assertTrue(seen > 0, "no editor heading went through O.LabelFont")
    end)
  end)
