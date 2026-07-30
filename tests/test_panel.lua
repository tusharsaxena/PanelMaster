local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local P = NS.Panel

test("Panel.Register: the category is registered EAGERLY at load (options-ui-§1)", function()
  -- Registration happens in OnInitialize, not on first /pm config, so the entry is always visible in
  -- Blizzard's options list. run.lua called P:Register() as part of the lifecycle.
  assertTrue(T.mocks.__settingsPanels["Ka0s Panel Master"] ~= nil,
    "the parent category was never registered")
end)

test("Panel.Register: both subcategories are registered", function()
  assertTrue(T.mocks.__settingsPanels["General"] ~= nil)
  assertTrue(T.mocks.__settingsPanels["Panels"] ~= nil)
end)

test("Panel.Register: is idempotent", function()
  -- A second call must not register a duplicate category.
  P:Register()
  P:Register()
  assertTrue(T.mocks.__settingsPanels["General"] ~= nil)
end)

test("Panel: every registered frame carries the framework contract (options-ui-§1)", function()
  -- Blizzard's Settings window calls all three on a canvas frame; a missing one is a runtime error
  -- inside Blizzard code, which is both fatal and hard to attribute.
  for name, panel in pairs(T.mocks.__settingsPanels) do
    assertEqual(type(panel.OnCommit), "function", name .. " has no OnCommit")
    assertEqual(type(panel.OnRefresh), "function", name .. " has no OnRefresh")
    assertEqual(type(panel.OnDefault), "function", name .. " has no OnDefault")
  end
end)

test("Panel: the body is built lazily — each page has an OnShow", function()
  -- AceGUI lays out against the panel's current width, which is 0 until it is first shown.
  for name, panel in pairs(T.mocks.__settingsPanels) do
    assertEqual(type(panel:GetScript("OnShow")), "function", name .. " has no OnShow builder")
  end
end)

test("Panel: the Defaults button is NOT created at registration (anti-pattern #42)", function()
  -- Creating it during OnInitialize races every other addon's load order: a UI skin that hooks
  -- AceGUI's RegisterAsWidget later leaves this one button on Blizzard's stock red art. It must be
  -- built in the first OnShow instead — so at registration time it must not exist yet.
  assertEqual(P.general.panel.defaultsBtn, nil, "the Defaults button was built too early")
  assertEqual(P.panels.panel.defaultsBtn, nil, "the Defaults button was built too early")
end)

test("Panel: the pages that want a Defaults button declare the intent and park a callback", function()
  for _, ctx in ipairs({ P.general, P.panels }) do
    assertTrue(ctx.panel.wantsDefaultsButton, "the page did not record its Defaults intent")
    assertEqual(type(ctx.panel.defaultsOnClick), "function", "no parked Defaults callback")
  end
end)

test("Panel: the header Defaults action and Blizzard's OnDefault are the same function", function()
  -- Two routes to one action; setting them apart is how they would drift.
  assertEqual(P.general.panel.defaultsOnClick, P.general.panel.OnDefault)
  assertEqual(P.panels.panel.defaultsOnClick, P.panels.panel.OnDefault)
end)

test("Panel: the landing page is the parent category, not a subcategory", function()
  -- /pm config opens the parent, so the logo + slash list is what a user lands on.
  assertTrue(T.mocks.__settingsPanels["Ka0s Panel Master"] ~= P.general.panel)
end)

test("Panel.Open: refuses during combat and does NOT open (options-ui-§2)", function()
  T.mocks.__openedCategory = nil
  T.mocks.__inCombat = true
  local chat = T.mocks.__chat
  P:Open()
  T.mocks.__inCombat = false
  assertEqual(T.mocks.__openedCategory, nil, "the protected category-switch ran under lockdown")
  assertTrue(chat[#chat]:find("cannot open settings during combat", 1, true) ~= nil,
    "no grey refusal notice")
end)

test("Panel.Open: the combat refusal is grey", function()
  T.mocks.__inCombat = true
  local chat = T.mocks.__chat
  P:Open()
  T.mocks.__inCombat = false
  assertTrue(chat[#chat]:find("|cff808080", 1, true) ~= nil, "the refusal is not grey")
end)

test("Panel.Open: does NOT defer-and-replay on leaving combat", function()
  -- A panel that pops itself open the instant combat drops steals focus during recovery. The user
  -- re-runs /pm config when they choose. This is the opposite of the unlock deferral, deliberately.
  T.mocks.__openedCategory = nil
  T.mocks.__inCombat = true
  P:Open()
  T.mocks.__inCombat = false
  if NS.Unlock then NS.Unlock:ResumePending() end
  assertEqual(T.mocks.__openedCategory, nil, "the options panel replayed itself after combat")
end)

test("Panel.Open: opens out of combat", function()
  T.mocks.__openedCategory = nil
  T.mocks.__inCombat = false
  P:Open()
  assertEqual(T.mocks.__openedCategory, 1, "the parent category was not opened")
end)

test("Panel.Refresh: a hidden page is not refreshed", function()
  -- The page is hidden headlessly (createPanel hides it), so Refresh must be a clean no-op rather
  -- than running every widget updater against widgets that were never built.
  local ran = false
  P.general.refreshers[#P.general.refreshers + 1] = function() ran = true end
  P.general.panel:Hide()
  P:Refresh()
  P.general.refreshers[#P.general.refreshers] = nil
  assertFalse(ran, "a hidden page ran its refreshers")
end)

test("Panel.RestoreDefaults: resets settings and leaves panels alone", function()
  NS.Registry:DeleteAll()
  NS.Registry:New("Survivor")
  NS.Schema:Set("settings.gridSize", 16)
  P:RestoreDefaults()
  assertEqual(NS.Schema:Get("settings.gridSize"), 4)
  assertEqual(NS.Registry:Count(), 1, "RestoreDefaults deleted the user's panels")
  NS.Registry:DeleteAll()
end)

test("Panel: the Panels page's Defaults action is confirm-gated", function()
  NS.Registry:DeleteAll()
  NS.Registry:New("A")
  local before = #T.mocks.__popupsShown
  P.panels.panel.OnDefault()
  assertEqual(#T.mocks.__popupsShown, before + 1, "deleting every panel skipped the confirm")
  assertEqual(NS.Registry:Count(), 1, "panels went before the confirm was accepted")
  NS.Registry:DeleteAll()
end)
