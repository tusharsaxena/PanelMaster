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

test("Panel.RestoreDefaults: resets settings and leaves panels alone", function()
  NS.Registry:DeleteAll()
  NS.Registry:New("Survivor")
  NS.Schema:Set("settings.gridSize", 16)
  P:RestoreDefaults()
  assertEqual(NS.Schema:Get("settings.gridSize"), 4)
  assertEqual(NS.Registry:Count(), 1, "RestoreDefaults deleted the user's panels")
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
  NS.Registry:DeleteAll()
  local rec = NS.Registry:New("Hidden")
  E.__setSelectedID(rec.id)
  pctx.panel:Hide()
  local n = watch()
  pctx.dirty = false

  NS.Registry:Set(rec.id, "width", 321)

  assertEqual(n.refreshes, 0, "an off-screen page ran its refreshers (options-ui-§11)")
  assertTrue(pctx.dirty, "the off-screen change was not flagged for the next OnShow")
  unwatch()
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
