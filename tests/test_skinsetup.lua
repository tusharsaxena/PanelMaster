-- tests/test_skinsetup.lua — the LibKa0s-Skin-1.0 seam (core/SkinSetup.lua, skinning-§1-§3).
--
-- What this addon owes the skin engine, and nothing the library pins itself: the owner is
-- registered under the folder name with this addon's read and write seams; the skin.* keys default
-- to Ka0s Default and are skipRender schema rows in the "Appearance" group; the Skin tab is the
-- General page's last tab (there is no Keybindings tab here); the profile's skin is applied right
-- after AceDB exists and FIRST on every profile event; and one pick, from this addon's tab or from
-- another addon's copy, is ONE effective SetChoice (one OnLooksChanged, no reload request), however
-- many store writes follow it. The pattern is LootHistory's tests/test_skinsetup.lua.
--
-- After the panel and profile suites; every case here puts the skin back on Ka0s Default and the
-- General page back on the tab it found.

local T = _G.PM_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
local OWNER = "PanelMaster"

-- ONE listener of each kind for the whole file: the library keeps a listener for the session and
-- the same function twice is one entry, so each case resets the counters instead of registering.
local looks, reloads = 0, 0
NS.Skin.OnLooksChanged(function() looks = looks + 1 end)
Skin:OnReloadRequest(OWNER, function() reloads = reloads + 1 end)

--- Back on Ka0s Default, stored and applied, with the counters cleared.
local function reset()
  NS.WriteSkinChoice("ka0s", "ka0s", { panel = true, fonts = false }, { font = false, texture = false })
  NS.Schema:Set("skin.pickerSeen", false)
  Skin:SetChoice(OWNER, "ka0s", "ka0s")
  Skin:SetIgnore(OWNER, true, false)
  Skin:SetOverride(OWNER, false, false)
  looks, reloads = 0, 0
end

--- Run `fn` with the skin reset before and after, whatever `fn` raised.
local function clean(fn)
  return function()
    reset()
    local ok, err = pcall(fn)
    reset()
    if not ok then error(err, 0) end
  end
end

--- Render the General page on `tab` and answer the widgets that render built, and the page's ctx.
local function renderTab(tab)
  local ctx = NS.Panel.general
  assertTrue(ctx ~= nil, "the General page was never registered")
  local created = mocks.LibStub("AceGUI-3.0", true).__created
  local from = #created + 1
  ctx.activeTab = tab
  ctx._dirty = true
  local onShow = ctx.panel:GetScript("OnShow")
  assertTrue(onShow ~= nil, "the General page has no OnShow")
  onShow(ctx.panel)
  local out = {}
  for i = from, #created do out[#out + 1] = created[i] end
  return out, ctx
end

--- Open the Skin tab and answer the check box (a radio choice or a Scope box) whose label ends
--- with `name`, with the tab the page was on before.
local function choiceNamed(name)
  local before = NS.Panel.general and NS.Panel.general.activeTab
  local widgets = renderTab("Appearance")
  for _, w in ipairs(widgets) do
    local label = tostring(w.labelText or "")
    if w.type == "CheckBox" and label:sub(-#name) == name then return w, before end
  end
  return nil, before
end

local function park(tab)
  local ctx = NS.Panel.general
  if ctx and tab then ctx.activeTab = tab end
end

-- ── the owner ────────────────────────────────────────────────────────────────────────────────

test("Skin seam: the owner is the folder name, and NS.Skin is its facade", function()
  -- red under: registering under the brand or a typo (the library keys every frame and every
  -- listener by owner), or publishing a facade of some other owner.
  assertTrue(Skin:IsOwner(OWNER), "core/SkinSetup.lua did not register the owner")
  assertTrue(rawequal(NS.Skin, Skin:For(OWNER)), "NS.Skin is not Skin:For(\"PanelMaster\")")
  assertEqual(NS.Skin.owner, OWNER)
  assertEqual(Skin:OwnerLabel(OWNER), NS.BRAND, "the copy confirmation names the addon by its brand")
end)

test("Skin seam: the read answers Ka0s Default before the profile store exists", function()
  -- RegisterOwner calls `get` at FILE LOAD, before NS:InitDB; a getter that raised there would be a
  -- visible Lua error on every login.
  local db = NS.db
  NS.db = nil
  local ok, source, skin = pcall(NS.SkinChoice)
  local okO, font, texture = pcall(NS.SkinOverride)
  NS.db = db
  assertTrue(ok, "NS.SkinChoice raised without a store: " .. tostring(source))
  assertEqual(source, "ka0s")
  assertEqual(skin, "ka0s")
  assertTrue(okO, "NS.SkinOverride raised without a store: " .. tostring(font))
  assertEqual(font, false)
  assertEqual(texture, false)
end)

test("Skin seam: the TOC loads the seam after Namespace and before the first file that reads it", function()
  -- red under: SkinSetup moved below settings/Schema.lua (its rows read NS.SKIN_OPTIONS at file
  -- load) or below core/DebugLogSetup.lua, or above core/Namespace.lua (NS.BRAND, the label).
  local Loader = dofile("tests/_kit/loader.lua")
  local at = {}
  for i, path in ipairs(Loader.tocFiles("PanelMaster.toc")) do at[path] = i end
  local seam = at["core/SkinSetup.lua"]
  assertTrue(seam ~= nil, "core/SkinSetup.lua is not in the TOC")
  assertTrue(at["core/Namespace.lua"] < seam, "SkinSetup loads before Namespace")
  assertTrue(seam < at["core/DebugLogSetup.lua"], "SkinSetup loads after DebugLogSetup")
  assertTrue(seam < at["settings/Schema.lua"], "SkinSetup loads after Schema")
end)

test("Skin seam: the TOC lists EllesmereUI as an optional dependency", function()
  -- skinning-§5: OptionalDeps, never Dependencies, so EllesmereUI loads first where installed.
  local fh = assert(io.open("PanelMaster.toc", "rb"))
  local toc = fh:read("*a")
  fh:close()
  local opt = toc:match("## OptionalDeps:([^\r\n]*)") or ""
  assertTrue((", " .. opt .. ","):find("[%s,]EllesmereUI[%s,]") ~= nil, "EllesmereUI is not in OptionalDeps")
  assertTrue(toc:find("## Dependencies:", 1, true) == nil, "a hard dependency line appeared")
end)

-- ── the keys and the rows ────────────────────────────────────────────────────────────────────

test("Skin seam: the skin.* keys default to Ka0s Default, as skipRender Appearance rows", function()
  -- red under: a default other than today's look, a picker already marked seen (O3), or a row that
  -- renders itself on top of the library's tab.
  local d = NS.defaults.profile.skin
  assertEqual(d.source, "ka0s")
  assertEqual(d.skin, "ka0s")
  assertEqual(d.ignorePanel, true)
  assertEqual(d.ignoreFonts, false)
  assertEqual(d.font, "")
  assertEqual(d.texture, "")
  assertEqual(d.pickerSeen, false)
  for _, leaf in ipairs({ "source", "skin", "ignorePanel", "ignoreFonts", "font", "texture", "pickerSeen" }) do
    local path = "skin." .. leaf
    local row = NS.Schema:FindRow(path)
    assertTrue(row ~= nil, path .. " is not a schema row")
    assertEqual(row.group, "Appearance", path .. ": group")
    assertTrue(row.skipRender == true, path .. ": the tab draws it, so it must be skipRender")
    assertEqual(row.default, d[leaf], path .. ": the row's default is the defaults table's")
  end
end)

test("Skin seam: the skin row's values are every registered skin, in the library's order", function()
  local values = NS.Schema:FindRow("skin.skin").values
  local skins = Skin:Skins()
  assertEqual(#values, #skins, "one value per registered skin")
  for i, def in ipairs(skins) do assertEqual(values[i].value, def.key, "value " .. i) end
  assertEqual(values[1].value, "ka0s", "Ka0s Default first")
end)

test("Skin seam: /pm set refuses a skin that is not registered and applies one that is", clean(function()
  -- The `values` check is the CLI parser's (LibKa0s-Slash-1.0), so this drives the verb.
  NS.Slash:OnSlash("set skin.skin no-such-skin")
  assertEqual(NS.db.profile.skin.skin, "ka0s", "an unknown skin was stored")
  assertEqual(looks, 0, "a refused set repainted")
  NS.Slash:OnSlash("set skin.skin obsidian")
  assertEqual(NS.db.profile.skin.skin, "obsidian", "a registered skin was refused")
  local _, applied = Skin:GetChoice(OWNER)
  assertEqual(applied, "obsidian", "a bare set must move the applied skin (the row's onChange)")
  assertEqual(looks, 1, "one set, one repaint")
end))

test("Skin seam: /pm set reaches an exception, and only its own half", clean(function()
  NS.Slash:OnSlash("set skin.ignoreFonts true")
  local panel, fonts = Skin:GetIgnore(OWNER)
  assertEqual(fonts, true, "the set applied")
  assertEqual(panel, true, "the other half untouched")
end))

test("Skin seam: the write seam stores media's halves, \"\" for the skin's own", clean(function()
  NS.WriteSkinChoice(nil, nil, nil, { font = "Friz Quadrata TT", texture = false })
  assertEqual(NS.db.profile.skin.font, "Friz Quadrata TT")
  assertEqual(NS.db.profile.skin.texture, "")
  local font, texture = NS.SkinOverride()
  assertEqual(font, "Friz Quadrata TT")
  assertEqual(texture, false)
end))

-- ── the tab ──────────────────────────────────────────────────────────────────────────────────

test("Skin seam: the Skin tab is the General page's last tab, keyed Appearance", function()
  -- skinning-§3: last where the page has no Keybindings tab; four tabs, inside options-ui-§13's
  -- budget. Read off the call itself, so the strip's order is the library's own answer.
  local O = NS.Helpers
  local real, keys, opts = O.RenderTabbedSchema, nil, nil
  O.RenderTabbedSchema = function(...)
    local args = { ... }
    opts = args[5]
    local groups, k = real(...)
    keys = k
    return groups, k
  end
  local before = NS.Panel.general and NS.Panel.general.activeTab
  local ok, err = pcall(renderTab, before)
  O.RenderTabbedSchema = real
  park(before)
  if not ok then error(err, 0) end
  assertTrue(type(opts) == "table" and type(opts.tabs) == "table", "the page passed no host tabs")
  assertEqual(#opts.tabs, 1, "one host tab, the Skin tab")
  assertEqual(opts.tabs[1].key, "Appearance")
  assertEqual(opts.tabs[1].label, "Skin", "the strip names the tab Skin")
  assertTrue(type(keys) == "table", "the render answered no strip")
  -- red under: dropping `untabbedSkipRender`, which brings back the empty tab of the hidden
  -- `panel.*` rows' "Panel" group.
  assertEqual(#keys, 4, table.concat(keys, "|"))
  for _, k in ipairs(keys) do assertTrue(k ~= "Panel", "the hidden panel.* rows drew a tab") end
  assertEqual(keys[#keys], "Appearance", "the Skin tab is last")
end)

test("Skin seam: one tab pick is one effective SetChoice, one repaint and no reload", clean(function()
  -- The tab calls SetChoice first, then the write seam, which writes both rows through
  -- NS.Schema:Set; each row's onChange applies only its own half and finds it applied already.
  -- red under: an onChange that re-applies the whole stored pair (two repaints, the first to a
  -- half-written skin), or a seam that writes the profile around NS.Schema:Set.
  local cb, before = choiceNamed("Obsidian")
  local ok, err = pcall(function()
    assertTrue(cb ~= nil, "the Skin tab drew no Obsidian choice")
    cb:SetValue(true); cb:__fire("OnValueChanged", true)
    assertEqual(looks, 1, "one pick must repaint exactly once")
    assertEqual(reloads, 0, "a Ka0s-to-Ka0s pick asks for no reload")
    local source, skin = Skin:GetChoice(OWNER)
    assertEqual(source, "ka0s")
    assertEqual(skin, "obsidian", "the pick did not move the applied skin")
    assertEqual(NS.db.profile.skin.skin, "obsidian", "the pick did not reach the profile")
  end)
  park(before)
  if not ok then error(err, 0) end
end))

test("Skin seam: the tab's Ignore fonts reaches the library and the profile, one repaint", clean(function()
  -- red under: NS.WriteSkinChoice dropping its third argument, or a row onChange that re-applies
  -- both halves (a second repaint).
  local cb, before = choiceNamed("Ignore fonts")
  local ok, err = pcall(function()
    assertTrue(cb ~= nil, "the Skin tab drew no Ignore fonts box")
    cb:SetValue(true); cb:__fire("OnValueChanged", true)
    local panel, fonts = Skin:GetIgnore(OWNER)
    assertEqual(fonts, true, "the library's exception moved")
    assertEqual(panel, true, "and the other kept")
    assertEqual(NS.db.profile.skin.ignoreFonts, true, "the profile holds it")
    assertEqual(NS.db.profile.skin.ignorePanel, true)
    assertEqual(looks, 1, "one toggle repaints once")
  end)
  park(before)
  if not ok then error(err, 0) end
end))

test("Skin seam: another addon's copy to every Ka0s addon repaints PanelMaster once", clean(function()
  -- The library's copy calls SetChoice for each other owner, then WriteChoice, which reaches this
  -- addon's registered setter. Driven through a fake second owner.
  Skin:RegisterOwner("SkinProbeAddon", { label = "Skin Probe", get = function() return "ka0s", "ember" end,
    set = function() end })
  Skin:SetChoice("SkinProbeAddon", "ka0s", "ember")
  Skin:SetChoice(OWNER, "ka0s", "ember")
  assertTrue(Skin:WriteChoice(OWNER, "ka0s", "ember"), "the copy's write did not reach this addon's setter")
  assertEqual(looks, 1, "a copy must repaint this addon exactly once")
  assertEqual(NS.db.profile.skin.skin, "ember", "the copy did not land in the profile")
  assertEqual(select(2, Skin:GetChoice(OWNER)), "ember")
end))

-- ── the profile events ───────────────────────────────────────────────────────────────────────

test("Skin seam: a profile switch applies the new profile's skin first, before the panels reload", clean(function()
  -- The spy stands in for the registry reload and records what was applied by then.
  -- red under: applying the skin after the reload, or not at all on a switch.
  local R = NS.Registry
  local home = NS.db:GetCurrentProfile()
  local reloadProfile, seen = R.ReloadProfile, nil
  NS.Schema:Set("skin.skin", "glass")
  assertEqual(select(2, Skin:GetChoice(OWNER)), "glass")
  looks = 0
  R.ReloadProfile = function(...)
    seen = select(2, Skin:GetChoice(OWNER))
    return reloadProfile(...)
  end
  local ok, err = pcall(function()
    mocks.__switchProfile("SkinProbe")
    assertEqual(seen, "ka0s", "the new profile's skin was not applied before the panels reloaded")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "ka0s", "the switch did not move the applied skin")
    assertEqual(looks, 1, "one switch, one repaint")
  end)
  R.ReloadProfile = reloadProfile
  mocks.__switchProfile(home)
  if not ok then error(err, 0) end
end))

test("Skin seam: a profile reset puts the skin, its exceptions and overrides back to Ka0s Default", clean(function()
  -- Reset all settings is db:ResetProfile() (options-ui-§12); skinning-§3 says the choice returns
  -- to Ka0s Default and is re-applied. The reset also takes the panels, so the case keeps none.
  NS.Registry:DeleteAll()
  NS.WriteSkinChoice("ka0s", "midnight", { panel = false, fonts = true }, { font = "Friz Quadrata TT", texture = false })
  assertEqual(select(2, Skin:GetChoice(OWNER)), "midnight")
  NS.db:ResetProfile()
  assertEqual(select(2, Skin:GetChoice(OWNER)), "ka0s", "the reset left the old skin applied")
  local panel, fonts = Skin:GetIgnore(OWNER)
  assertEqual(panel, true, "the reset left the panel exception moved")
  assertEqual(fonts, false, "the reset left the fonts exception moved")
  assertEqual(NS.db.profile.skin.font, "", "the reset left the font override stored")
end))

test("Skin seam: a profile's stored exceptions and overrides are applied with its skin", clean(function()
  -- addon:OnInitialize and the profile events call NS.ApplySkinChoice() with no argument.
  -- red under: applying the stored pair and not the exceptions or the overrides.
  local s = NS.db.profile.skin
  s.ignorePanel, s.ignoreFonts = true, true
  NS.ApplySkinChoice()
  local panel, fonts = Skin:GetIgnore(OWNER)
  assertEqual(panel, true, "the stored panel exception")
  assertEqual(fonts, true, "the stored fonts exception")
end))
