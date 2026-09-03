local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local P = NS.Panel
local E = NS.PanelEditor

test("PanelEditor: the editor is its own module (architecture-§3)", function()
  -- C-07 peeled the panel editor out of settings/Panel.lua into settings/PanelEditor.lua. It is a
  -- sibling module with its own namespace table, not a second half hidden inside the page's.
  assertEqual(type(NS.PanelEditor), "table", "the editor is not published on NS")
  assertEqual(type(E.BuildPage), "function", "the page cannot ask the editor to build itself")
  assertEqual(type(E.Rebuild), "function", "the page cannot ask the editor to repaint")
  assertEqual(type(E.WireBus), "function", "the page cannot wire the editor to the bus")
end)

test("PanelEditor: the bus is wired at registration, not at first paint", function()
  -- The Panels page builds lazily, so a subscription made from the build would miss every change
  -- until the user first opened the page. P:Register wires it instead.
  assertTrue(E.__evPanels ~= nil, "the editor never subscribed to the panel bus")
end)

test("Panel: all four categories survive the peel and still build on OnShow (options-ui-§5)", function()
  -- The peel moved the Panels page's builder into another file, and the lazy-build contract is the
  -- easiest thing to drop on the way — a page whose builder moved out and was never called back is
  -- an empty page, not an error.
  for _, name in ipairs({ "Ka0s Panel Master", "General", "Panels", "Profiles" }) do
    local panel = T.mocks.__settingsPanels[name]
    assertTrue(panel ~= nil, name .. " is no longer registered")
    assertEqual(type(panel:GetScript("OnShow")), "function", name .. " has no OnShow builder")
  end
end)

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
  -- A second call must not register a duplicate category. This is what makes the PLAYER_LOGIN retry
  -- below free on a normal login, where OnInitialize already succeeded.
  local before = P.general
  P:Register()
  P:Register()
  assertTrue(T.mocks.__settingsPanels["General"] ~= nil)
  assertEqual(P.general, before, "a second Register rebuilt the General page")
end)

test("Panel.Register: a second attempt is made on PLAYER_LOGIN (F-013)", function()
  -- The guard in Register returns WITHOUT setting `registered`, so a login where Settings or AceGUI
  -- were not yet loaded used to leave the addon absent from Blizzard's options list for the whole
  -- session, silently. Registration stays eager (anti-pattern #22) — this is a second eager attempt,
  -- not a deferral to first /pm config.
  local retry = T.mocks.__events["PLAYER_LOGIN"]
  assertEqual(type(retry), "function", "nothing retries registration at login")
  local before = P.general
  retry()
  assertEqual(P.general, before, "the retry re-registered an already-registered category")
end)

test("Panel.Register: the retry is SUBSCRIBED before PLAYER_LOGIN fires (F-013)", function()
  -- Where the subscription is made decides whether it can ever be delivered. AceAddon runs
  -- OnEnable from inside its OWN PLAYER_LOGIN handler (libs/AceAddon-3.0), and a frame that
  -- subscribes to an event while that event is already being dispatched does not receive that
  -- firing — and PLAYER_LOGIN never fires twice for a non-LoD addon. So a retry registered from
  -- OnEnable is dead on arrival. OnInitialize runs at ADDON_LOADED, strictly before PLAYER_LOGIN,
  -- which is the bootstrap shape options-ui-§1 sanctions. The mock stores whatever handler it is
  -- given, so only the source can show which lifecycle hook made the call.
  -- CR-stripped: this repo is CRLF-pinned (line-endings-§2), so a scan that anchors on "\nend\n"
  -- must not depend on the checkout's representation.
  local function slurp(path)
    local f = assert(io.open(path, "r"))
    local text = f:read("*a")
    f:close()
    return (text:gsub("\r\n", "\n"))
  end

  local src = slurp("core/PanelMaster.lua")
  local init = src:match("function addon:OnInitialize%(%)(.-)\nend\n")
  assertTrue(init ~= nil, "OnInitialize is no longer a plain function block; the scan needs updating")
  assertTrue(init:find('RegisterEvent%("PLAYER_LOGIN"') ~= nil,
    "the settings-registration retry is not subscribed from OnInitialize")

  local seen = 0
  for _ in src:gmatch('RegisterEvent%("PLAYER_LOGIN"') do seen = seen + 1 end
  assertEqual(seen, 1, "PLAYER_LOGIN is registered more than once")
end)

test("PanelEditor: a slider REACHES an out-of-range value rather than clamping it (F-003)", function()
  -- Registry.Sanitize deliberately leaves x/y unclamped (audit decision A-003): a multi-monitor
  -- layout legitimately carries an offset far outside the editor's nominal span. A Blizzard slider
  -- clamps both its thumb AND the value it reports, so a nominal span would silently rewrite that
  -- offset to the bound on the first click, drag or mouse-wheel. The span therefore widens to reach
  -- the stored value. AceGUI is stubbed in the suite, so the widget itself never exists — the span
  -- arithmetic is exposed for exactly this assertion.
  local span = NS.PanelEditor.SliderSpan
  assertEqual(type(span), "function", "the editor's slider span is not reachable from a test")

  local lo, hi = span(3000, -NS.Constants.EDITOR_OFFSET_RANGE, NS.Constants.EDITOR_OFFSET_RANGE)
  assertEqual(hi, 3000, "the slider still clamps a large positive offset")
  assertEqual(lo, -NS.Constants.EDITOR_OFFSET_RANGE, "reaching upward moved the lower bound")

  lo, hi = span(-3000, -NS.Constants.EDITOR_OFFSET_RANGE, NS.Constants.EDITOR_OFFSET_RANGE)
  assertEqual(lo, -3000, "the slider still clamps a large negative offset")
  assertEqual(hi, NS.Constants.EDITOR_OFFSET_RANGE, "reaching downward moved the upper bound")

  -- An in-range value leaves the nominal span exactly as Constants named it.
  lo, hi = span(120, NS.Constants.MIN_SIZE, NS.Constants.MAX_SIZE)
  assertEqual(lo, NS.Constants.MIN_SIZE)
  assertEqual(hi, NS.Constants.MAX_SIZE)

  -- A missing or non-numeric field reads as 0, the same value the widget is given.
  lo, hi = span(nil, NS.Constants.MIN_SIZE, NS.Constants.MAX_SIZE)
  assertEqual(lo, 0, "a missing value left the span unable to show the 0 it displays")
  assertEqual(hi, NS.Constants.MAX_SIZE)
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

test("Panel: the header Defaults action and Blizzard's OnDefault reach ONE implementation", function()
  -- Two routes to one action; setting them apart is how they would drift. They are no longer the
  -- same OBJECT, and that is a deliberate library change rather than a regression: LibKa0s's
  -- O.CreatePanel stamps OnDefault as a FORWARDER that resolves panel.defaultsOnClick at CALL time,
  -- because every host parks its click handler on the panel AFTER CreatePanel returns — the button
  -- does not exist yet, being built on first OnShow. A plain assignment there would capture nil
  -- forever while looking perfectly correct.
  --
  -- So the assertion moves from identity to BEHAVIOR: firing Blizzard's footer control must run
  -- the same closure the header button runs.
  for _, ctx in ipairs({ P.general, P.panels }) do
    assertEqual(type(ctx.panel.defaultsOnClick), "function", "no parked Defaults callback")
    assertEqual(type(ctx.panel.OnDefault), "function", "no Blizzard OnDefault")
    local ran = 0
    local parked = ctx.panel.defaultsOnClick
    ctx.panel.defaultsOnClick = function() ran = ran + 1 end
    ctx.panel.OnDefault()
    ctx.panel.defaultsOnClick = parked
    assertEqual(ran, 1, "Blizzard's footer Defaults control does not reach the page's own action")
  end
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
    "no gray refusal notice")
end)

test("Panel.Open: the combat refusal is gray", function()
  T.mocks.__inCombat = true
  local chat = T.mocks.__chat
  P:Open()
  T.mocks.__inCombat = false
  -- |cffaaaaaa, not this addon's old |cff808080: the refusal string is LibKa0s-Options-1.0's now,
  -- one implementation shared with every other Ka0s addon rather than six copies of the sentence.
  -- The wording is byte-identical; only the shade of gray moved, and it moved lighter.
  assertTrue(chat[#chat]:find("|cffaaaaaa", 1, true) ~= nil, "the refusal is not gray")
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

test("Panel.Open: says so when there is no category to open (F-013)", function()
  -- Both eager attempts can still fail on a build with no Settings API. `/pm config` used to return
  -- silently in that case, which reads as a broken command rather than a missing prerequisite.
  T.mocks.__openedCategory = nil
  T.mocks.__inCombat = false
  local chat = T.mocks.__chat
  P.__setCategoryIDForTest(nil)
  P:Open()
  P.__setCategoryIDForTest(1)
  assertEqual(T.mocks.__openedCategory, nil, "something was opened without a category")
  assertTrue(chat[#chat]:find("settings are not available", 1, true) ~= nil,
    "the failure was swallowed instead of spoken")
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

test("Panel.RestoreDefaults: CONFIRMS, because the reset now deletes panels", function()
  -- The header Defaults button IS the global reset here, one implementation shared with
  -- `/pm resetall`. Since options-ui-§12 made that a PROFILE reset it is destructive, so the button
  -- asks first: a single click that emptied a screen full of panels is exactly what the standard's
  -- fixed confirmation wording exists to prevent.
  -- red under: RestoreDefaults calling CliResetAll's act instead of ConfirmResetAll.
  NS.Registry:DeleteAll()
  NS.Registry:New("Survivor")
  NS.Schema:Set("settings.gridSize", 16)

  P:RestoreDefaults()

  assertEqual(T.mocks.__popupsShown[#T.mocks.__popupsShown], "KA0S_PANELMASTER_RESETALL")
  assertEqual(NS.Schema:Get("settings.gridSize"), 16, "the button reset before anyone confirmed")
  assertEqual(NS.Registry:Count(), 1)
  NS.Registry:DeleteAll()
end)

-- ── Closing an open dropdown on scroll ──────────────────────────────────────────
-- An open dropdown's list is parented to UIParent, so scrolling would otherwise leave it floating
-- detached over (or outside) the settings window. The page closes it on any user-driven scroll.
--
-- These drive P.__closeOpenDropdowns against hand-built widget stand-ins, because the headless
-- harness stubs AceGUI out entirely and no real widget is ever constructed. Tracking is per RENDER
-- CONTEXT, so each one takes the context whose dropdowns it is talking about.

local function fakeCtx() return { dropdowns = {} } end

test("Panel: every render context owns its own dropdown registry", function()
  for _, ctx in ipairs({ P.general, P.panels }) do
    assertEqual(type(ctx.dropdowns), "table", "a page has nowhere to track its dropdowns")
  end
end)

test("Panel: one page's rebuild does not deregister another page's dropdowns", function()
  -- The F-005 defect exactly: a single file-level list meant the Panels page's rebuild emptied the
  -- General page's tracking too, after which scrolling General left its open list floating.
  local general, panels = fakeCtx(), fakeCtx()
  P.__registerDropdownForTest(general, { type = "Dropdown" })
  P.__registerDropdownForTest(panels, { type = "Dropdown" })

  P.__forgetDropdownsForTest(panels)

  assertEqual(P.__openDropdownCount(panels), 0, "the rebuilding page kept its own stale entries")
  assertEqual(P.__openDropdownCount(general), 1,
    "a rebuild on one page deregistered another page's live dropdown")
end)

test("Panel: closing dropdowns dispatches on widget TYPE, not on field presence", function()
  -- The regression pin. A stock AceGUI Dropdown ALSO has a `.dropdown` field (its Blizzard
  -- UIDropDownMenuTemplate frame), so a field-presence check handed that frame to the SharedMedia
  -- library's pool-return, which iterates a `contentRepo` the Blizzard frame does not have. The
  -- error propagated out of MoveScroll and killed mouse-wheel scrolling on the entire page.
  local closed, returned = false, false
  local stock = {
    type = "Dropdown",
    dropdown = { itIsABlizzardFrame = true },   -- present, and MUST NOT be touched
    pullout = { Close = function() closed = true end },
  }
  local lsm = {
    type = "LSM30_Border",
    dropdown = { contentRepo = {}, __returned = function() returned = true end },
  }
  local ctx = fakeCtx()
  P.__registerDropdownForTest(ctx, stock)
  P.__registerDropdownForTest(ctx, lsm)

  P.__closeOpenDropdowns(ctx)

  assertTrue(closed, "the stock dropdown's pullout was not closed")
  assertFalse(returned, "the stock dropdown was routed down the SharedMedia path")
end)

test("Panel: closing an unopened dropdown is a no-op, not an error", function()
  -- Every tracked dropdown is visited on every scroll, and almost all of them are shut.
  local ctx = fakeCtx()
  P.__registerDropdownForTest(ctx, { type = "Dropdown" })
  P.__registerDropdownForTest(ctx, { type = "LSM30_Statusbar" })
  P.__closeOpenDropdowns(ctx)
end)

test("Panel: an unknown widget type is skipped rather than guessed at", function()
  -- A future widget family must not be pushed down whichever branch happens to match its fields.
  local touched = false
  local ctx = fakeCtx()
  P.__registerDropdownForTest(ctx, {
    type = "SomeFutureWidget",
    dropdown = { contentRepo = {} },
    setDropdown = function() touched = true end,
  })
  P.__closeOpenDropdowns(ctx)
  assertFalse(touched)
end)

test("Panel: the tracking registry is emptied between rebuilds", function()
  local ctx = fakeCtx()
  P.__registerDropdownForTest(ctx, { type = "Dropdown" })
  P.__forgetDropdownsForTest(ctx)
  -- A stale entry would point at a released widget, which AceGUI has already recycled into
  -- something else by the time the next scroll fires.
  assertEqual(P.__openDropdownCount(ctx), 0)
end)

-- ── The Panels page's repaint policy (F-002, F-004) ─────────────────────────────
-- The page has exactly TWO triggers: MSG_PANELS (the set of panels changed) rebuilds it once, and
-- MSG_PANEL (one panel's field changed) refreshes the open editor in place. No widget callback
-- rebuilds the page itself — doing so released the very widget whose handler was still running.
--
-- The real rebuilder is installed by buildPanelsPage, which needs AceGUI widgets and so never runs
-- headlessly. These tests install counting stand-ins instead: what is under test is how MANY times
-- a mutation makes the page rebuild or refresh, not what a rebuild draws.

local pctx    = P.panels
local actions = E.__pageActions

local function watch()
  local n = { rebuilds = 0, refreshes = 0, selectedAtRebuild = false, recordsAtRebuild = nil }
  pctx.rebuilders[#pctx.rebuilders + 1] = function()
    n.rebuilds = n.rebuilds + 1
    n.selectedAtRebuild = E.__getSelectedID()
    n.recordsAtRebuild  = #NS.Registry:All()
  end
  pctx.refreshers[#pctx.refreshers + 1] = function() n.refreshes = n.refreshes + 1 end
  return n
end

local function unwatch()
  for i = #pctx.rebuilders, 1, -1 do pctx.rebuilders[i] = nil end
  for i = #pctx.refreshers, 1, -1 do pctx.refreshers[i] = nil end
  pctx.panel:Hide()
  E.__setSelectedID(nil)
  NS.Registry:DeleteAll()
end

test("Panel: deleting from the page rebuilds it exactly once (F-002)", function()
  NS.Registry:DeleteAll()
  NS.Registry:New("Keeper")
  local doomed = NS.Registry:New("Doomed")
  E.__setSelectedID(doomed.id)
  pctx.panel:Show()
  local n = watch()

  actions.delete(doomed)

  assertEqual(n.rebuilds, 1, "the delete rebuilt the page more than once")
  assertEqual(n.selectedAtRebuild, nil, "the selection was not cleared BEFORE the rebuild")
  unwatch()
end)

test("Panel: renaming from the page rebuilds it exactly once", function()
  NS.Registry:DeleteAll()
  local rec = NS.Registry:New("Before")
  E.__setSelectedID(rec.id)
  pctx.panel:Show()
  local n = watch()

  actions.rename({ SetText = function() end }, rec, "After")

  assertEqual(n.rebuilds, 1, "the rename rebuilt the page more than once")
  assertEqual(NS.Registry:Get(rec.id).name, "After")
  unwatch()
end)

test("Panel: a rejected rename puts the old name back and does not rebuild", function()
  NS.Registry:DeleteAll()
  local rec = NS.Registry:New("Taken")
  local other = NS.Registry:New("Other")
  E.__setSelectedID(other.id)
  pctx.panel:Show()
  local n = watch()
  local restored
  actions.rename({ SetText = function(_, t) restored = t end }, other, "Taken")

  assertEqual(n.rebuilds, 0, "a refused rename still tore the page down")
  assertEqual(restored, "Other", "the rejected edit was left on screen")
  assertEqual(NS.Registry:Get(rec.id).name, "Taken")
  unwatch()
end)

test("Panel: creating from the page rebuilds once and lands on the NEW panel", function()
  -- The id does not exist until R:New has already broadcast, so the create hands its selection over
  -- by name and the bus handler resolves it before the one rebuild runs.
  NS.Registry:DeleteAll()
  NS.Registry:New("Existing")
  E.__setSelectedID(nil)
  pctx.panel:Show()
  local n = watch()
  local cleared = false

  actions.create(pctx, { SetText = function(_, t) cleared = (t == "") end }, "Fresh")

  local fresh = NS.Registry:FindByName("Fresh")
  assertEqual(n.rebuilds, 1, "the create rebuilt the page more than once")
  assertEqual(n.selectedAtRebuild, fresh.id, "the one rebuild did not land on the new panel")
  assertTrue(cleared, "the create box kept the name that was just used")
  assertEqual(pctx.pendingSelect, nil, "the pending selection was never consumed")
  unwatch()
end)

test("Panel: a refused create leaves the typed name alone and does not rebuild", function()
  NS.Registry:DeleteAll()
  NS.Registry:New("Dup")
  E.__setSelectedID(nil)
  pctx.panel:Show()
  local n = watch()
  local cleared = false

  actions.create(pctx, { SetText = function() cleared = true end }, "Dup")

  assertEqual(n.rebuilds, 0, "a refused create still rebuilt the page")
  assertFalse(cleared, "the name the user must correct was wiped")
  assertEqual(pctx.pendingSelect, nil, "a failed create left a pending selection behind")
  unwatch()
end)

test("Panel: deleting the LAST panel reaches the empty-state branch cleanly", function()
  NS.Registry:DeleteAll()
  local only = NS.Registry:New("Only")
  E.__setSelectedID(only.id)
  pctx.panel:Show()
  local n = watch()

  actions.delete(only)

  assertEqual(n.rebuilds, 1, "the last delete rebuilt the page more than once")
  assertEqual(n.recordsAtRebuild, 0, "the rebuild did not see an empty registry")
  assertEqual(n.selectedAtRebuild, nil, "the rebuild still pointed at the panel that was deleted")
  unwatch()
end)

test("Panel: a field change on the SELECTED panel refreshes in place and never rebuilds", function()
  -- options-ui-§11 / anti-pattern #39: a full AceGUI teardown per scalar write would release the
  -- slider the user is still dragging.
  NS.Registry:DeleteAll()
  local rec = NS.Registry:New("Live")
  E.__setSelectedID(rec.id)
  pctx.panel:Show()
  local n = watch()

  NS.Registry:Set(rec.id, "width", 321)

  assertEqual(n.refreshes, 1, "the open editor went stale on a field change (F-004)")
  assertEqual(n.rebuilds, 0, "a scalar write tore the whole page down")
  unwatch()
end)

test("Panel: a field change on a DIFFERENT panel neither refreshes nor rebuilds", function()
  NS.Registry:DeleteAll()
  local shown = NS.Registry:New("Shown")
  local elsewhere = NS.Registry:New("Elsewhere")
  E.__setSelectedID(shown.id)
  pctx.panel:Show()
  local n = watch()

  NS.Registry:Set(elsewhere.id, "width", 321)

  assertEqual(n.refreshes, 0, "the editor refreshed for a panel it is not showing")
  assertEqual(n.rebuilds, 0)
  unwatch()
end)

test("Panel: a hidden page is only marked dirty by a field change, never refreshed", function()
  -- THE FLAG IS THE LIBRARY'S — `_dirty`, with the underscore — and asserting the name is the whole
  -- point of this case. It used to assert `pctx.dirty`, a host-owned field settings/PanelEditor.lua
  -- wrote and NOTHING read: LibKa0s's SetRenderer OnShow gate reads `_dirty`, so every deferred
  -- repaint was dropped on the floor and this case passed anyway. That is how a profile switch could
  -- leave the Panels page listing the previous profile's panels for the rest of the session with a
  -- green suite. A test that checks the flag was WRITTEN rather than that the repaint HAPPENS is a
  -- test of the wrong thing, so the case below this one closes the loop on the show.
  NS.Registry:DeleteAll()
  local rec = NS.Registry:New("Hidden")
  E.__setSelectedID(rec.id)
  pctx.panel:Hide()
  local n = watch()
  pctx._dirty = false

  NS.Registry:Set(rec.id, "width", 321)

  assertEqual(n.refreshes, 0, "an off-screen page ran its refreshers (options-ui-§11)")
  assertTrue(pctx._dirty, "the off-screen change was not flagged for the next OnShow")
  unwatch()
end)

test("Panel: the deferred repaint actually lands on the next show", function()
  -- The half the old dirty case never checked. A flag is only correct if something acts on it.
  NS.Registry:DeleteAll()
  NS.Registry:New("Deferred")
  local onShow = pctx.panel:GetScript("OnShow")
  assertTrue(onShow ~= nil, "the page has no OnShow — SetRenderer never ran")
  pctx.panel:Show(); onShow(pctx.panel)            -- render once, so the gate is armed
  pctx.panel:Hide()

  local n = watch()
  NS.Registry:New("AddedWhileHidden")
  assertEqual(n.rebuilds, 0, "a hidden page must not rebuild in place")
  assertTrue(pctx._dirty, "and it must be flagged")

  pctx.panel:Show(); onShow(pctx.panel)
  assertFalse(pctx._dirty, "the show consumed the flag")
  assertTrue(#E.__panelsByName() == 2, "both panels are in the registry")
  unwatch()
end)

test("Panel: a profile switch drops the editor's selection", function()
  -- Panel ids are allocated PER PROFILE, so an id held across a switch resolves to a different
  -- panel in the incoming profile — and the rebuilder's `Registry:Get(selectedID)` check cannot
  -- tell the difference. The editor would silently open on a panel nobody chose.
  NS.Registry:DeleteAll()
  local rec = NS.Registry:New("Selected")
  E.__setSelectedID(rec.id)
  assertEqual(E.__getSelectedID(), rec.id)

  NS.Registry:ReloadProfile()

  assertTrue(E.__getSelectedID() == nil,
    "the selection survived a profile switch and now names someone else's panel")
end)

test("Panel: a rebuild drops the old refreshers before it releases their widgets", function()
  -- Every refresher closure points at a widget the rebuild is about to hand back to AceGUI's pool.
  NS.Registry:DeleteAll()
  NS.Registry:New("A")
  pctx.panel:Show()
  local n = watch()
  local leftOver
  pctx.rebuilders[#pctx.rebuilders + 1] = function() leftOver = #pctx.refreshers end

  NS.Registry:New("B")   -- structural → one rebuild

  assertEqual(leftOver, 0, "a refresher survived into the rebuild that released its widget")
  assertEqual(n.refreshes, 0, "a stale refresher ran during the rebuild")
  unwatch()
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

test("Tagline: the landing page, the TOC Notes and the README say one thing (F-019)", function()
  -- The one-line description used to exist in three different wordings, so whichever one a player
  -- read first was contradicted by the next. `ADDON_TAGLINE` in settings/Panel.lua is canonical —
  -- it is the sentence on the settings landing page — and the other two quote it. It is a
  -- file-local, so a source scan is the only way to compare the three.
  -- CR-stripped for the same reason as the OnInitialize scan above: the blank-line anchor
  -- ("\n\n") is a representation detail, and this repo is CRLF-pinned (line-endings-§2).
  local function slurp(path)
    local f = assert(io.open(path, "r"))
    local text = f:read("*a")
    f:close()
    return (text:gsub("\r\n", "\n"))
  end

  local panel = slurp("settings/Panel.lua")
  local tagline = panel:match("local ADDON_TAGLINE%s*=%s*(.-)\n\n")
  assertTrue(tagline ~= nil, "ADDON_TAGLINE is no longer a plain string literal")
  local sentence = ""
  for chunk in tagline:gmatch('"([^"]*)"') do sentence = sentence .. chunk end
  assertTrue(#sentence > 40, "the tagline came out empty; the scan needs updating")

  -- The shared opening is what makes the three recognizably the same sentence. The TOC drops the
  -- middle for the client's addon list, which has room for one short line.
  local opening = sentence:match("^(.-,%s*so)")
  assertTrue(opening ~= nil, "the tagline no longer has a ', so' clause to share")

  local notes = slurp("PanelMaster.toc"):match("## Notes:%s*(.-)\r?\n")
  assertTrue(notes:sub(1, #opening) == opening,
    "the TOC Notes is not a shortened form of the tagline:\n  " .. notes .. "\n  " .. sentence)

  -- The README quotes the tagline whole, only lower-casing the first word behind the addon name.
  -- Its prose is hard-wrapped, so the line break in the middle of the sentence is flattened first.
  local readme = slurp("README.md"):gsub("%s+", " ")
  assertTrue(readme:find(sentence:sub(1, 1):lower() .. sentence:sub(2), 1, true) ~= nil,
    "the README's opening line no longer quotes the tagline")
end)

test("PanelEditor: the panel dropdowns are ordered by name, not by creation", function()
  -- Reported from the game: the Edit picker listed "Lower Bar, Action Bar Center, Artwork #1,
  -- Hiding Bar, Artwork #2" — creation order, which is effectively arbitrary once there are more
  -- than a few panels and is the wrong order for a list you have to find a name in.
  local E = NS.PanelEditor
  NS.Registry:DeleteAll()
  for _, name in ipairs({ "Lower Bar", "Action Bar Center", "Artwork #1", "Hiding Bar", "Artwork #2" }) do
    NS.Registry:New(name)
  end

  local got = {}
  for i, rec in ipairs(E.__panelsByName()) do got[i] = rec.name end
  local want = { "Action Bar Center", "Artwork #1", "Artwork #2", "Hiding Bar", "Lower Bar" }
  for i = 1, #want do
    assertEqual(got[i], want[i], ("position %d"):format(i))
  end

  -- The STORED order is untouched. All() hands back the live saved-variables array, so sorting it
  -- in place would silently reorder the user's file and shift the index Registry:FindByName returns.
  local stored = NS.Registry:All()
  assertEqual(stored[1].name, "Lower Bar", "creation order was mutated")
end)

-- ── Panel scale ─────────────────────────────────────────────────────────────────

local R, Canvas, PC = NS.Registry, NS.Canvas, NS.Constants

local function freshPanels()
  T.mocks.__inCombat = false
  R:DeleteAll()
  Canvas:RenderAll()
end

test("Panel scale: defaults to 1, which is the identity", function()
  freshPanels()
  assertEqual(PC.PANEL_TEMPLATE.scale, 1.0)
  local rec = R:New("Unscaled")
  assertEqual(R:Get(rec.id).scale, 1.0)
  assertEqual(Canvas.BuildSpec(R:Get(rec.id), {}).scale, 1.0)
end)

test("Panel scale: is clamped to its own bounds, not the artwork's", function()
  freshPanels()
  local rec = R:New("ClampedScale")
  -- Tighter than C.MIN_ART_SCALE (0.1) on purpose: the artwork's scale resizes a texture inside a
  -- panel whose clickable area is unchanged, while this resizes the frame itself, and 0.1 would
  -- walk straight around the C.MIN_SIZE floor that exists to keep a panel grabbable.
  R:Set(rec.id, "scale", 99)
  assertEqual(R:Get(rec.id).scale, PC.MAX_PANEL_SCALE)
  R:Set(rec.id, "scale", 0.01)
  assertEqual(R:Get(rec.id).scale, PC.MIN_PANEL_SCALE)
  assertTrue(PC.MIN_PANEL_SCALE > PC.MIN_ART_SCALE,
    "the panel scale floor is no tighter than the artwork's")
end)

test("Panel scale: reaches the frame, and does not change the stored size", function()
  freshPanels()
  local rec = R:New("ScaledPanel")
  R:Set(rec.id, "width", 200)
  R:Set(rec.id, "height", 100)
  R:Set(rec.id, "scale", 2)
  local f = Canvas:FrameFor(rec.id)
  assertEqual(f.__scale, 2, "the frame was not scaled")
  -- Width and Height keep reading what the user typed. Folding the scale into them would make the
  -- editor's sliders show a size nobody set, and the frame is sized in its OWN scaled units anyway.
  local live = R:Get(rec.id)
  assertEqual(live.width, 200)
  assertEqual(live.height, 100)
  assertEqual(f.__w, 200, "the scale was multiplied into the frame size as well")
  assertEqual(f.__h, 100)
end)

test("Panel scale: a junk value falls back rather than reaching SetScale", function()
  freshPanels()
  local rec = R:New("JunkScale")
  -- Straight onto the record, bypassing R:Set's type check, the way a hand-edited SavedVariables
  -- file arrives. BuildSpec is the last line of defense before SetScale, which errors on a string.
  R:Get(rec.id).scale = "banana"
  assertEqual(Canvas.BuildSpec(R:Get(rec.id), {}).scale, 1.0)
end)

-- ── The Panels page's tab strip (options-ui-§13) ────────────────────────────────
-- The editor's six subjects are TABS now, and only the active one is built. These cases drive the
-- real builder -- E:BuildPage, the real rebuilder, the real AceGUI mock -- rather than the counting
-- stand-ins above, because "which controls exist right now" is exactly what a stand-in cannot say.
--
-- Into a page context of their OWN, not P.panels. The repaint-policy block above empties that
-- page's rebuilder list wholesale, the real rebuilder included, and BuildPage runs once per session
-- so nothing puts it back; building a second context is also what keeps these cases from leaving a
-- built page and a live selection behind for whatever runs next.
local function freshPanelsCtx()
  local ctx = NS.Helpers.CreatePanel(nil, "Panels", { pageKey = "panels" })
  ctx.dropdowns, ctx.rebuilders = {}, {}
  ctx.refreshers = ctx.refreshers or {}
  E:BuildPage(ctx)
  return ctx
end

-- Every AceGUI widget created while `fn` runs, by the label it was given.
local function labelsBuiltBy(fn)
  local created = T.mocks.LibStub("AceGUI-3.0", true).__created
  local from = #created + 1
  fn()
  local labels = {}
  for i = from, #created do
    local w = created[i]
    if w.labelText then labels[w.labelText] = true end
  end
  return labels
end

-- Render one named tab of a freshly built Panels page, and answer the labels it drew.
local function labelsOfTab(ctx, tab)
  return labelsBuiltBy(function()
    ctx.activeTab = tab
    E:Rebuild(ctx)
  end)
end

test("Panels page: only the active tab's controls are built", function()
  NS.Registry:DeleteAll()
  local rec = NS.Registry:New("Tabbed")
  E.__setSelectedID(rec.id)
  local ctx = freshPanelsCtx()

  local general = labelsOfTab(ctx, "General")
  assertTrue(general["Panel name"], "the General tab did not build the name box")
  assertFalse(general["Width"] == true, "the General tab built a Position and size control")
  assertFalse(general["Background texture"] == true, "the General tab built a surface control")

  local position = labelsOfTab(ctx, "Position and size")
  assertTrue(position["Width"], "the Position and size tab did not build Width")
  assertTrue(position["Panel scale"], "the Position and size tab did not build Panel scale")
  assertFalse(position["Panel name"] == true, "the Position tab rebuilt the General tab's name box")

  -- The merged tab: the fill AND the edge, which were two subsections of two and four controls.
  -- The merge stays; what options-ui-§7 added is a heading per half, and options-ui-§16 the
  -- canonical border names -- "Border style", not "Border texture".
  local surface = labelsOfTab(ctx, "Background and border")
  assertTrue(surface["Background texture"], "the merged tab lost the background")
  assertTrue(surface["Border style"], "the merged tab lost the border")

  local fade = labelsOfTab(ctx, "Opacity and fade")
  assertTrue(fade["Panel opacity"], "the Opacity and fade tab did not build Panel opacity")
  assertTrue(fade["Show on mouseover only"], "the Opacity and fade tab lost the mouseover switch")

  NS.Registry:DeleteAll()
  E.__setSelectedID(nil)
end)

-- THE BAND MUST SURVIVE BEING BUILT BEFORE THE CANVAS HAS A WIDTH.
--
-- `ctx.chrome` is zero-wide until the settings canvas lays itself out, and the
-- FIRST page a player opens is rendered before that happens -- the library says
-- so in its own words at `replaceOnResize`, which is how the tab strip heals
-- itself when the width arrives. Both controls in this band take
-- SetRelativeWidth(0.5), so a layout run at that moment gives each of them half
-- of nothing: two controls that exist, are shown, and occupy no pixels. The band
-- keeps its reserved height, so the page draws an empty strip of chrome above the
-- tabs and the create box and the panel picker are simply gone.
--
-- The strip gets a second chance and this block does not: it is built ONCE for
-- the session (settings/Panel.lua's `built` flag), so a session that opened
-- Panels first stayed broken until a /reload.
--
-- red under: dropping the OnSizeChanged hook, or re-laying out on every size
-- event (the height change SetChromeHeight causes fires the same script, and a
-- layout that answered it would loop).
test("Panels page: the header block re-lays out when the canvas learns its width", function()
  NS.Registry:DeleteAll()
  NS.Registry:New("Sized")
  local ctx = freshPanelsCtx()

  -- The header frame is the chrome kid carrying the hook.
  local header
  for _, kid in ipairs(ctx.__chromeKids or {}) do
    if kid.__scripts and kid.__scripts.OnSizeChanged then header = kid end
  end
  assertTrue(header ~= nil,
    "the page header frame carries no OnSizeChanged hook, so a band built at zero width stays empty")

  local block = ctx.__pmHeaderBlock
  assertTrue(block ~= nil, "the header block must be reachable to be re-laid out")
  local before = block.layoutCount or 0

  header.__scripts.OnSizeChanged(header, 0)
  assertEqual(block.layoutCount or 0, before, "a zero width is not a width to lay out against")

  header.__scripts.OnSizeChanged(header, 640)
  assertTrue((block.layoutCount or 0) > before, "the block did not re-lay out when the width arrived")

  local settled = block.layoutCount
  header.__scripts.OnSizeChanged(header, 640)
  assertEqual(block.layoutCount, settled,
    "the same width must be a no-op — SetChromeHeight fires this script too")

  NS.Registry:DeleteAll()
end)

-- The create box says what pressing Enter DOES. It read "New panel name", which
-- names the field's contents and answers a question nobody had -- the band holds
-- two controls that both name a panel, and the reader's question at this one is
-- which of them makes one. The picker beside it already reads as the picker.
--
-- red under: reverting the label, or leaving the tooltip title on the old wording
-- (the title is what the tooltip's own heading shows, so the two drifting apart
-- is a control that introduces itself twice under different names).
test("Panels page: the create box is labeled for the act, not for its contents", function()
  NS.Registry:DeleteAll()
  local labels = labelsBuiltBy(function() freshPanelsCtx() end)
  assertTrue(labels["Create new panel"], "the page header lost the create box's label")
  assertFalse(labels["New panel name"] == true, "the old, contents-naming label came back")
  NS.Registry:DeleteAll()
end)

-- The Opacity and fade tab's LAYOUT, not just its contents. The two sliders are
-- the same question asked twice -- how visible, and how visible while the cursor
-- is elsewhere -- both 0..1, and they belong side by side where a reader can
-- compare them. The switch that decides whether the second one applies at all
-- goes underneath, on its own line.
--
-- It was the other arrangement: Panel opacity alone on the first row, then Faded
-- opacity paired with the checkbox. That put the two numbers on different lines
-- and gave the checkbox a slider to look like a companion to.
--
-- red under: pairing either slider with the checkbox again, or splitting the two
-- sliders across rows.
test("Panels page: the two opacity sliders share a row, and the switch is below", function()
  NS.Registry:DeleteAll()
  local rec = NS.Registry:New("Faded")
  E.__setSelectedID(rec.id)
  local ctx = freshPanelsCtx()

  local created = T.mocks.LibStub("AceGUI-3.0", true).__created
  local from = #created + 1
  ctx.activeTab = "Opacity and fade"
  E:Rebuild(ctx)

  --- The row (a SimpleGroup) that holds a widget with this label, or nil.
  local function rowHolding(label)
    for i = from, #created do
      local w = created[i]
      if w.type == "SimpleGroup" then
        for _, child in ipairs(w.children or {}) do
          if child.labelText == label then return w end
        end
      end
    end
  end

  local panelRow  = rowHolding("Panel opacity")
  local fadedRow  = rowHolding("Faded opacity")
  local switchRow = rowHolding("Show on mouseover only")
  assertTrue(panelRow ~= nil, "the tab did not build Panel opacity")
  assertTrue(fadedRow ~= nil, "the tab did not build Faded opacity")
  assertTrue(switchRow ~= nil, "the tab lost the mouseover switch")

  assertTrue(panelRow == fadedRow, "the two opacity sliders must share one row")
  assertFalse(switchRow == panelRow, "the switch must not sit beside a slider")

  NS.Registry:DeleteAll()
  E.__setSelectedID(nil)
end)

test("Panels page: an unknown active tab heals to the first one rather than drawing nothing",
  function()
    NS.Registry:DeleteAll()
    local rec = NS.Registry:New("Healed")
    E.__setSelectedID(rec.id)
    local ctx = freshPanelsCtx()

    -- The shape a renamed tab leaves behind in a context that outlives the rename.
    local labels = labelsOfTab(ctx, "Visibility")
    assertTrue(labels["Panel name"],
      "a stale tab pointer drew an empty editor instead of falling back to the first tab")
    assertEqual(ctx.activeTab, E.TABS[1], "the stale pointer was not healed")

    NS.Registry:DeleteAll()
    E.__setSelectedID(nil)
  end)

test("Panels page: creating and picking a panel are ABOVE the strip, in the chrome band", function()
  -- The strip is the EDITOR's alone. Making a panel and choosing which panel to edit are not two of
  -- the six subjects, and a tab you have to leave to pick a different panel would be one.
  for _, name in ipairs(E.TABS) do
    assertFalse(name == "Create", "Create was folded into the tab strip")
    assertFalse(name == "Edit", "Edit was folded into the tab strip")
  end

  -- They used to be two untabbed sections at the top of the SCROLL, which put page-wide controls
  -- under whichever tab happened to be showing (options-ui-§14). They are in the page's chrome
  -- band now, and the source half of this assertion is what pins the direction of that move: a
  -- host that put them back would do it by calling `section` again.
  local src = assert(io.open("settings/PanelEditor.lua", "r"))
  local body = src:read("*a")
  src:close()
  assertEqual(body:find('section(ctx, "Create")', 1, true), nil,
    "the Create section is back in the scroll, below the strip")
  assertEqual(body:find('section(ctx, "Edit")', 1, true), nil,
    "the Edit section is back in the scroll, below the strip")

  -- And the rendered half, which is the one that can fail for a reason the grep cannot see: the
  -- block really is drawn, and the picker inside it is the widget the page keeps a handle on.
  local ctx = freshPanelsCtx()
  NS.Registry:DeleteAll()
  local rec = NS.Registry:New("Banded")
  E.__setSelectedID(rec.id)
  E:Rebuild(ctx)
  assertTrue(ctx.__pmPicker ~= nil, "the page drew no panel picker in its chrome band")
  assertEqual(ctx.__pmPicker.labelText, "Panel",
    "the picker lost the label it needs now that no section heading names it")
  NS.Registry:DeleteAll()
  E.__setSelectedID(nil)
end)

test("Panels page: the strip is drawn with ZERO panels, and the empty state is content", function()
  -- options-ui-§13. The page used to RELEASE its strip and give the band back when the registry was
  -- empty, on the argument that a strip over nothing is chrome for its own sake -- which is exactly
  -- the conditional no-strip state the rule forbids. It is also no longer survivable: the create
  -- box and the panel picker are IN that band now (options-ui-§14), so releasing it would take the
  -- only control that can make a panel off the screen at the moment the player needs it most.
  NS.Registry:DeleteAll()
  E.__setSelectedID(nil)
  local ctx = freshPanelsCtx()

  -- The strip's buttons are plain frames rather than AceGUI widgets, so they are counted off the
  -- library's own chrome ledger rather than out of the widget capture. Compared against the count
  -- for a page that HAS a panel rather than against a literal: the ledger also carries the content
  -- panel, and the invariant worth pinning is that the strip is the same either way, not what the
  -- library happens to park beside it.
  local populated = NS.Registry:New("Present")
  E.__setSelectedID(populated.id)
  E:Rebuild(ctx)
  local withPanels = #(ctx.__tabKids or {})
  local stripBefore = ctx.__tabKids
  assertTrue(withPanels >= #E.TABS, "the populated page drew fewer frames than it has tabs")

  NS.Registry:DeleteAll()
  E.__setSelectedID(nil)
  local labels = labelsBuiltBy(function()
    ctx.activeTab = E.TABS[1]
    E:Rebuild(ctx)
  end)

  -- IDENTITY, not just the count. TabStrip drains its ledger into a FRESH table every time it
  -- draws, so a rebuild that skipped the strip would leave the previous one's table sitting there
  -- with the same number of entries in it -- which is exactly what a count-only assertion passes
  -- against, and what the `if #records > 0 then drawTabStrip(ctx) end` mutation this case exists to
  -- kill would have produced.
  assertFalse(ctx.__tabKids == stripBefore,
    "the strip was not redrawn for an empty registry — the old buttons were left standing")
  assertEqual(#(ctx.__tabKids or {}), withPanels,
    "the Panels page drew a different strip once the last panel was deleted")
  -- And the band itself is still occupied. The branch this replaces called __releaseChrome, which
  -- empties exactly this ledger -- taking the create box and the picker with it.
  assertTrue(#(ctx.__chromeKids or {}) > 0, "the chrome band was given back with the panels")
  assertTrue((ctx.__bannerHeight or 0) > 0, "the band's reserved height was given back")
  assertTrue(ctx.__pmPicker ~= nil, "the picker went with the band")

  -- And the empty state is INSIDE the page rather than in place of it. No editor control was built.
  assertFalse(labels["Panel name"] == true, "an editor was built for a registry with no panels")

  E.__setSelectedID(nil)
end)

test("Panels page: the Master controls tab closes on the canonical button pair", function()
  -- options-ui-§15: the two resets are the tab's closing button pair, and the hook that draws them
  -- is keyed on the GROUP NAME. A key that disagreed with the group would detach silently -- the
  -- tab would simply have no buttons, and nothing would error.
  local ctx = P.general
  local created = T.mocks.LibStub("AceGUI-3.0", true).__created
  local from = #created + 1
  ctx.activeTab = "Master controls"
  ctx._dirty = true
  local onShow = ctx.panel:GetScript("OnShow")
  onShow(ctx.panel)

  local seen = {}
  for i = from, #created do
    local w = created[i]
    if w.type == "Button" and w.text then seen[w.text] = true end
  end
  assertTrue(seen["Reset position"], "the Master controls tab drew no Reset position button")
  assertTrue(seen["Reset all settings"], "the Master controls tab drew no Reset all settings button")
end)

test("Panels page: every color swatch is followed by a 'Use class color' companion", function()
  -- options-ui-§17, and the assertion that is NOT vacuous for this addon: its colors live on panel
  -- RECORDS rather than on schema rows, so the row-walk in tests/test_schema.lua cannot see them.
  -- Every pair is emitted by one function driven off C.COLOR_FIELDS, and this walks the tabs those
  -- five colors are drawn on and checks what the editor actually built.
  --
  -- Dies under renaming the checkbox back to "Class color", which is what it was called before the
  -- standard named it, and under a color that gains no companion at all.
  NS.Registry:DeleteAll()
  local rec = NS.Registry:New("Companioned")
  E.__setSelectedID(rec.id)
  local ctx = freshPanelsCtx()

  local WANTED = {
    ["Background and border"] = { "Background color", "Border color" },
    ["Accent bar"]            = { "Bar color", "Border color" },
    ["Artwork"]               = { "Artwork color" },
  }
  -- Matched on the PREFIX, because a swatch whose class color is already on carries a live
  -- `(opacity)` suffix saying which half of it is still read -- `accentClassColor` ships true, so
  -- the Bar color picker is labeled that way from the first render.
  local function drewSwatch(labels, swatch)
    for label in pairs(labels) do
      if label == swatch or label:sub(1, #swatch + 1) == swatch .. " " then return true end
    end
    return false
  end

  local seen = 0
  for tab, swatches in pairs(WANTED) do
    local labels = labelsOfTab(ctx, tab)
    for _, swatch in ipairs(swatches) do
      assertTrue(drewSwatch(labels, swatch), tab .. " lost its " .. swatch .. " swatch")
      seen = seen + 1
    end
    assertTrue(labels["Use class color"],
      tab .. " drew a color swatch with no 'Use class color' companion beside it")
  end
  -- Every color the record has is accounted for, so a sixth added later cannot slip past this.
  local total = 0
  for _ in pairs(NS.Constants.COLOR_FIELDS) do total = total + 1 end
  assertEqual(seen, total, "the editor draws a color this case does not walk")

  NS.Registry:DeleteAll()
  E.__setSelectedID(nil)
end)

test("Panels page: every color declares WHOSE class it means, and all five are the player's",
  function()
    -- options-ui-§17 requires the intent DECLARED rather than inferred from the path, because a
    -- path cannot be trusted to say it. A panel is chrome: it tracks no unit and has no unit token
    -- to ask about, so every one of them is the player's and `Util.ResolveColor` passes a nil unit.
    local C = NS.Constants
    for field in pairs(C.COLOR_FIELDS) do
      assertEqual(C.COLOR_CLASS_SOURCE[field], "player",
        field .. " has no declared class source — an audit reads that declaration, not the path")
    end
    for field in pairs(C.COLOR_CLASS_SOURCE) do
      assertTrue(C.COLOR_FIELDS[field] ~= nil,
        field .. " declares a class source but has no class-color companion")
    end
  end)
