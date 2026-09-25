local T = _G.PM_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse
local S = NS.Schema

-- The launcher's own suite: the minimap button, the broker plugin, its two clicks and options menu,
-- its status tooltip, and the Minimap button row (launcher). The two reserved verbs the same standard version added are in
-- tests/test_slash.lua, beside the rest of this addon's slash surface -- they are aliases onto a
-- schema path and have nothing to do with the button.
--
-- WHAT ONLY THIS FILE CAN ANSWER. Every one of these surfaces is invisible to the rest of the
-- harness, and each fails silently in the client rather than raising:
--   * a menu entry wired to a SECOND copy of the lock state behaves correctly the first time and
--     drifts on the first change made from the other surface (anti-pattern #81);
--   * a `hide` written without the inversion turns the button off when the player turns it on, and
--     the checkbox reads back its own wrong answer, so nothing contradicts it;
--   * a table COPIED rather than handed to LibDBIcon reads and writes correctly on both sides
--     until the next login, when LibDBIcon draws the button from ITS copy of `hide` and not the
--     one the row wrote;
--   * a `Register` that is not idempotent builds a second button over the first, and the two
--     answer different clicks.
-- None of those raises. All of them are one assertion away from being impossible.

local Env = dofile("tests/degraded_env.lua")

-- The client's context-menu API (`MenuUtil`, 11.0+), faked headlessly. The file is LibKa0s's own
-- tests/mock_menu.lua at v1.58.0, copied into this repo because the kit does not ship it (the
-- library's CHANGELOG, "What a consumer owes on re-vendoring v1.58.0"). Installing it puts
-- `MenuUtil` and `MenuResponse` in the mock table the loader resolves globals through, so the
-- vendored Launcher reads it at right-click time exactly as it would in the client.
local Menu = dofile("tests/mock_menu.lua")(mocks)
local loadPartial, loadDegraded = Env.loadPartial, Env.loadDegraded

local NAME = "PanelMaster"

--- The live button record the LibDBIcon mock keeps, or nil when nothing registered.
local function button()
  return mocks.__minimapButtons[NAME]
end

--- Click the ONE object both surfaces dispatch into, exactly as the client does.
---
--- Through `object.OnClick` rather than through a helper of the suite's own: that field IS the
--- launcher's whole click contract, and a test that called some other entry point would pass while
--- the minimap button and the broker row called nothing.
local function click(btn)
  local object = NS.Launcher:Object()
  assertTrue(object ~= nil, "there is no broker object to click")
  object.OnClick(object, btn)
end

-- ── one object, registered twice (launcher-§1) ─────────────────────────────────

test("Launcher: one object is registered with BOTH libraries, under the FOLDER name", function()
  -- The name is not cosmetic: LibDBIcon keys the button's SAVED POSITION by it, so a second
  -- spelling on either registration drops the angle the player dragged the button to and labels the
  -- broker plugin with the other name. It is the folder name because that is the one name the addon
  -- cannot change without changing what the client loads -- not NS.PREFIX ("[PM]") and not the
  -- `## Title` ("Ka0s Panel Master"), both of which exist here and are both wrong for this job.
  assertTrue(NS.Launcher:IsRegistered(), "the launcher did not register")

  local object = NS.Launcher:Object()
  assertTrue(object ~= nil, "no LibDataBroker object was created")
  assertEqual(mocks.__brokerObjects[NAME], object,
    "the broker object is registered under some other name than the addon folder")

  local b = button()
  assertTrue(b ~= nil, "LibDBIcon was never handed a button under the addon folder name")
  assertEqual(b.object, object,
    "LibDBIcon holds a DIFFERENT object from the broker one -- that is two launchers, not one")
end)

test("Launcher: the object is type 'launcher' and wears the addon's own icon", function()
  local object = NS.Launcher:Object()
  -- `type` is read by a broker display to decide what to draw. "data source" promises a `text`
  -- value that updates, which this object does not have, and a display handed the wrong type draws
  -- an empty value cell beside the icon forever.
  assertEqual(object.type, "launcher")
  -- The addon's own logo, never a Blizzard path or a numeric file id (anti-pattern #82). The same
  -- file the TOC's `## IconTexture` names, which tests/test_constants.lua pins from the other side.
  assertEqual(object.icon, NS.Constants.ICON_PATH)
  assertFalse(object.icon:find("Interface\\Icons", 1, true) ~= nil,
    "the launcher wears a Blizzard icon, so the addon looks like something else")
end)

test("Launcher: the label is the BRAND NAME in plain text, not the Title and not the folder",
  function()
    -- launcher-§1, as it became explicit at standard v2.54.0. `label` is what a broker display
    -- prints in its row, beside the other ten Ka0s addons, so it is the one field that decides
    -- whether the collection reads as one collection or as eleven unrelated addons. Across the
    -- eleven adoptions it came out three ways -- "Absorb Tracker", "Ka0s KickCD", "Ka0s Pretty
    -- Chat" -- because nothing said what it was, and a display sorting alphabetically filed one of
    -- them under A while the rest sat under K.
    local object = NS.Launcher:Object()
    assertEqual(object.label, "Ka0s Panel Master")

    -- NO ESCAPE SEQUENCE OF ANY KIND, which is the half of the rule that cannot be read off the
    -- string above. A Title MAY carry color escapes and one in the collection does (Ka0s Pretty
    -- Chat's), and handed to a display that draws the string raw it splatters across a row in which
    -- every other row is plain text. This is what goes red if `label` is ever wired to `## Title`.
    assertEqual(object.label:find("|c", 1, true), nil, "the label carries a color escape")
    assertEqual(object.label:find("|r", 1, true), nil, "the label carries an escape sequence")
    assertEqual(object.label:find("|T", 1, true), nil, "the label carries a texture escape")

    -- And it is not the folder name, which is a different field with a different job: `name` is
    -- what LibDBIcon keys the saved position by, and a player reads it nowhere as prose.
    assertTrue(object.label ~= NAME, "the label is the folder name, which is an identifier")
    assertEqual(mocks.__brokerObjects[NAME], object,
      "the registration name stopped being the folder name")
  end)

test("Launcher.Register: a second call builds no second button", function()
  -- A host may call this from OnInitialize and again from a login handler. LibDBIcon's Register on
  -- a name it already holds would otherwise build a second button over the first, and the two would
  -- answer different clicks.
  local before = NS.Launcher:Object()
  assertTrue(NS.Launcher:Register(), "Register did not report the launcher already wired")
  assertEqual(NS.Launcher:Object(), before, "a second object replaced the first")
  assertEqual(button().object, before, "LibDBIcon was re-registered with a new object")
end)

-- ── the two clicks (launcher-§2, standard v2.67.0; Launcher minor 4) ───────────

local ENABLED = S.ENABLED_PATH

--- Right-click the ONE object and answer the menu it opened (the mock's record of it).
local function openMenu()
  Menu.install()
  Menu.reset()
  click("RightButton")
  assertEqual(Menu.opens, 1, "the right click did not open the options menu")
  return Menu.last
end

test("Launcher: LEFT-click opens the settings panel and touches nothing else", function()
  -- The rungs are retired: the left button has one meaning on every addon. This addon's old rung (b)
  -- toggled the lock from here; that toggle is the menu's Locked entry now.
  NS.Unlock:SetUnlocked(false)
  Menu.reset()
  mocks.__openedCategory = nil
  click("LeftButton")
  assertEqual(mocks.__openedCategory, 1, "the left click did not open the settings panel")
  assertFalse(NS.State.unlocked, "the left click still toggles the lock")
  assertEqual(Menu.opens, 0, "the left click opened the options menu")
end)

test("Launcher: RIGHT-click opens the options menu, titled with the brand, and not the panel",
  function()
    mocks.__openedCategory = nil
    local menu = openMenu()
    assertEqual(mocks.__openedCategory, nil, "the right click opened the settings panel as well")
    assertEqual(menu.titles[1], "Ka0s Panel Master", "the menu is not titled with the label")
  end)

test("Launcher menu: exactly Enabled and Locked, in that order (the ADDONS.md row)", function()
  -- No Test mode (unlocking IS the preview) and no Show window (no primary window). The standard's
  -- ADDONS.md records this addon's menu as "Enabled · Locked".
  NS.Unlock:SetUnlocked(false)
  assertEqual(table.concat(openMenu():Texts(), " | "), "Enabled | Locked")
end)

test("Launcher menu: the checkboxes read the current state on every open", function()
  NS.Unlock:SetUnlocked(false)
  S:Set("state.locked", true)
  local first = openMenu()
  assertTrue(first:Checked("Enabled"), "Enabled reads unchecked on an enabled addon")
  assertTrue(first:Checked("Locked"), "Locked reads unchecked while locked")
  S:Set("state.locked", false)
  assertFalse(openMenu():Checked("Locked"), "the menu cached the lock state across opens")
  NS.Unlock:SetUnlocked(false)
end)

test("Launcher menu: Locked routes to /pm lock|unlock's own handler, both ways", function()
  -- NS.Slash:CliLock is the body of both verbs; the entry must call it, handed the NEW sense, and
  -- nothing else.
  local Sl, real, calls = NS.Slash, NS.Slash.CliLock, {}
  Sl.CliLock = function(self, locked)
    calls[#calls + 1] = locked
    return real(self, locked)
  end
  NS.Unlock:SetUnlocked(false)
  openMenu():Click("Locked")
  local unlocked = NS.State.unlocked
  openMenu():Click("Locked")
  Sl.CliLock = real
  assertEqual(table.concat({ tostring(calls[1]), tostring(calls[2]) }, ","), "false,true",
    "the Locked entry did not call CliLock(false) then CliLock(true)")
  assertTrue(unlocked, "the first click did not unlock the panels")
  assertFalse(NS.State.unlocked, "the second click did not lock them again")
end)

test("Launcher menu: Locked drives the SAME state the Lock frame checkbox drives", function()
  -- The load-bearing case (anti-pattern #81): one state, reached from both ends.
  NS.Unlock:SetUnlocked(false)
  openMenu():Click("Locked")
  assertFalse(S:Get("state.locked"),
    "the menu unlocked the panels and the Lock frame checkbox still reads ticked")
  S:Set("state.locked", true)
  assertFalse(NS.State.unlocked, "the checkbox re-locked and the addon stayed unlocked")
  openMenu():Click("Locked")
  assertTrue(NS.State.unlocked, "the click after a checkbox write toggled from a stale copy")
  NS.Unlock:SetUnlocked(false)
end)

test("Launcher menu: Locked goes through the write seam, so it is traced once and echoed", function()
  -- Every settings mutation is logged ONCE at the write seam (debug-logging-§10), and the verb's
  -- body echoes the canonical `path = value` read back from the store (slash-commands-§5).
  NS.Unlock:SetUnlocked(false)
  NS.DebugLog:SetEnabled(true)
  NS.DebugLog:Clear()
  local at = #mocks.__chat
  openMenu():Click("Locked")
  NS.DebugLog:SetEnabled(false)
  assertTrue(NS.DebugLog:FindLine("state.locked") ~= nil,
    "the click left no [Set] line -- it did not take the single write seam")
  assertTrue(#mocks.__chat > at, "the click did not echo the verb's acknowledgment")
  NS.Unlock:SetUnlocked(false)
end)

test("Launcher menu: Locked respects the unlock's combat deferral", function()
  NS.Unlock:SetUnlocked(false)
  mocks.__inCombat = true
  openMenu():Click("Locked")
  assertFalse(NS.State.unlocked, "the menu unlocked mid-combat")
  mocks.__inCombat = false
  NS.Unlock:ResumePending()
  assertTrue(NS.State.unlocked, "the deferred unlock was never replayed")
  NS.Unlock:SetUnlocked(false)
end)

test("Launcher menu: Enabled routes to /pm enable|disable's own handler, both ways", function()
  local Sl, real, calls = NS.Slash, NS.Slash.CliEnable, {}
  Sl.CliEnable = function(self, on)
    calls[#calls + 1] = on
    return real(self, on)
  end
  openMenu():Click("Enabled")
  local off = S:Get(ENABLED)
  openMenu():Click("Enabled")
  Sl.CliEnable = real
  assertEqual(table.concat({ tostring(calls[1]), tostring(calls[2]) }, ","), "false,true",
    "the Enabled entry did not call CliEnable(false) then CliEnable(true)")
  assertFalse(off, "the first click did not disable the addon")
  assertTrue(S:Get(ENABLED), "the second click did not re-enable it")
end)

test("Launcher menu: while DISABLED, Enabled is live and Locked is grayed and writes nothing",
  function()
    NS.Unlock:SetUnlocked(false)
    S:Set(ENABLED, false)
    local menu = openMenu()
    local locked, enabled = menu:Find("Locked"), menu:Find("Enabled")
    local before = S:Get("state.locked")
    menu:ForceClick("Locked")
    local after = S:Get("state.locked")
    S:Set(ENABLED, true)
    assertTrue(enabled.enabled, "the Enabled entry is grayed while disabled")
    assertFalse(locked.enabled, "the Locked entry is live while disabled")
    assertEqual(locked.text, "Locked (enable the addon first)")
    assertEqual(after, before, "a grayed Locked entry wrote the lock anyway")
    assertFalse(NS.State.unlocked, "a grayed Locked entry unlocked the panels")
  end)

test("Launcher: with no context-menu API, RIGHT-click falls back to the settings panel", function()
  -- A client before 11.0, or one whose menu system failed to load: the library resolves MenuUtil
  -- on every right click and opens the panel instead, which holds every toggle the menu would.
  Menu.remove()
  mocks.__openedCategory = nil
  click("RightButton")
  Menu.install()
  assertEqual(mocks.__openedCategory, 1, "the fallback right click did not open the panel")
end)

-- ── the status tooltip (launcher-§1, standard v2.66.0; Launcher minor 3) ───────
--
-- The library draws the whole tooltip; this addon only answers its questions through the
-- descriptor: `version` (the TOC's ## Version), `isEnabled` (the master switch) and `isLocked` (the
-- Lock frame row); the click hints are fixed since Launcher minor 4. It passes no
-- `isTestMode`, because it has no test mode, and no `onTooltipShow`, because it has no line of its
-- own. So the tooltip is read here THROUGH THE OBJECT'S OnTooltipShow, exactly as LibDBIcon calls it
-- on hover, into a recording stand-in for GameTooltip.

--- Hover the ONE object, and answer every line it drew, raw (escapes kept).
local function hover()
  local object = NS.Launcher:Object()
  assertTrue(object ~= nil, "there is no broker object to hover")
  assertEqual(type(object.OnTooltipShow), "function", "the object has no OnTooltipShow")
  local lines = {}
  local tt = { AddLine = function(_, text) lines[#lines + 1] = text end }
  object.OnTooltipShow(tt)
  return lines
end

--- The same lines with every color escape stripped, which is what the player reads.
local function plain(lines)
  local out = {}
  for i, line in ipairs(lines) do
    out[i] = (line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
  end
  return out
end

--- The TOC's ## Version as the metadata API answers it (the fixture's "1.2.3-toc",
--- tests/wow_mock.lua), never the addon's fallback constant.
local function tocVersion()
  return mocks.C_AddOns.GetAddOnMetadata(NAME, "Version")
end

test("Launcher tooltip: enabled and locked, the whole block in the library's order", function()
  NS.Unlock:SetUnlocked(false)
  S:Set("state.locked", true)
  assertEqual(table.concat(plain(hover()), "\n"), table.concat({
    "Ka0s Panel Master  v" .. tocVersion(),
    "Enabled: Yes",
    "Locked: Yes",
    "Left-click: Open settings",
    "Right-click: Options menu",
  }, "\n"), "the tooltip is not the M6 shape for this addon")
end)

test("Launcher tooltip: the version is the TOC's, through the addon's own version seam", function()
  -- `version` is NS.Version (core/EnvSetup.lua), which prefers the TOC's ## Version -- the same
  -- answer `/pm version` gives -- so the tooltip and the CLI cannot name two builds.
  local v = tocVersion()
  assertTrue(v ~= nil and v ~= "", "the TOC carries no ## Version")
  assertTrue(v ~= NS.version, "the fixture cannot tell the TOC from the fallback constant")
  assertEqual(plain(hover())[1], NS.BRAND .. "  v" .. v,
    "the tooltip's version is not the TOC's")
end)

test("Launcher tooltip: Locked is read on EVERY show, and the hints stay fixed", function()
  -- Never cached: unlock between two hovers and the second one says so. The left-click hint no
  -- longer follows the lock (Launcher minor 4): the left button always opens settings.
  NS.Unlock:SetUnlocked(false)
  S:Set("state.locked", true)
  local first = plain(hover())
  S:Set("state.locked", false)
  local second = plain(hover())
  S:Set("state.locked", true)
  assertEqual(first[3], "Locked: Yes")
  assertEqual(first[4], "Left-click: Open settings")
  assertEqual(second[3], "Locked: No", "the tooltip cached the lock state")
  assertEqual(second[4], "Left-click: Open settings", "the left hint moved with the lock")
  NS.Unlock:SetUnlocked(false)
end)

test("Launcher tooltip: the status values are green for Yes and red for No", function()
  NS.Unlock:SetUnlocked(false)
  S:Set("state.locked", false)
  local raw = hover()
  S:Set("state.locked", true)
  assertTrue(raw[2]:find("|cFF00FF00Yes|r", 1, true) ~= nil, "Enabled: Yes is not green: " .. raw[2])
  assertTrue(raw[3]:find("|cFFFF0000No|r", 1, true) ~= nil, "Locked: No is not red: " .. raw[3])
  NS.Unlock:SetUnlocked(false)
end)

test("Launcher tooltip: no Test mode line, and nothing of the addon's own", function()
  -- This addon has no test mode (unlocking is its preview; settings/Schema.lua passes the composer
  -- no testModePath), so a `Test mode:` line would report a state that does not exist. And it passes
  -- no onTooltipShow, so no title, status or hint is drawn a second time (anti-pattern #89).
  local lines = plain(hover())
  assertEqual(#lines, 5, "the tooltip drew " .. #lines .. " lines, not five")
  for _, line in ipairs(lines) do
    assertFalse(line:find("Test mode", 1, true) ~= nil, "a Test mode line was drawn")
  end
end)

test("Launcher tooltip: it still shows while DISABLED, with the same fixed hints", function()
  -- The owner's M5 ruling: the button always answers a hover, disabled included, which is when a
  -- player most needs to ask. Since M6 neither click is refused while disabled -- the left opens
  -- the panel where the addon is switched back on -- so the hints do not change.
  NS.Unlock:SetUnlocked(false)
  S:Set("state.locked", true)
  S:Set(ENABLED, false)
  local lines = plain(hover())
  S:Set(ENABLED, true)
  assertEqual(table.concat(lines, "\n"), table.concat({
    "Ka0s Panel Master  v" .. tocVersion(),
    "Enabled: No",
    "Locked: Yes",
    "Left-click: Open settings",
    "Right-click: Options menu",
  }, "\n"), "the disabled tooltip is not the M6 shape")
end)

test("Launcher: a DISABLED left click opens the panel, prints nothing and writes nothing", function()
  -- Launcher minor 4 retired the disabled refusal: the settings panel is setup, not a feature.
  NS.Unlock:SetUnlocked(false)
  S:Set(ENABLED, false)
  local at = #mocks.__chat
  mocks.__openedCategory = nil
  click("LeftButton")
  local n = #mocks.__chat - at
  S:Set(ENABLED, true)
  assertEqual(mocks.__openedCategory, 1, "a disabled left click did not open the settings panel")
  assertEqual(n, 0, "a disabled left click printed " .. n .. " lines")
  assertFalse(NS.State.unlocked, "a disabled left click unlocked the panels")
end)

-- ── the Minimap button row (launcher-§3) ───────────────────────────────────────

test("Minimap row: it is a STORED row in the canonical position, not a session flag", function()
  local row = S:FindRow(S.MINIMAP_PATH)
  assertTrue(row ~= nil, "there is no Minimap button row")
  assertEqual(row.label, "Minimap button")
  assertEqual(row.group, "Master controls")
  assertEqual(row.type, "bool")
  -- STORED, unlike Debug console and unlike a test mode: a button the player hid stays hidden
  -- across a reload. The console is a window a reload closes; this is furniture.
  assertFalse(row.sessionOnly == true, "the minimap row is session-only, so a reload un-hides it")
  -- The row's own sense is SHOWN, which is what the label says.
  assertEqual(row.default, true)
end)

test("Minimap row: the path reads SHOWN, and the store is LibDBIcon's own key in the GLOBAL store", function()
  -- launcher-§3 (v2.65.0) fixes all three. The path is the row's CLI name, so it is spelled in the
  -- row's own sense: `/pm get global.minimap.shown` answers true while the button shows. The STORE
  -- is `hide`, LibDBIcon's own key -- the boolean it reads to decide whether to draw the button,
  -- and the one the row writes through NS.Launcher:SetShown -- so a
  -- stored `shown` beside it would be a second copy of one state (anti-pattern #81). And the scope
  -- is global so that switching profiles does not move a player's buttons and options-ui-§12's
  -- profile reset does not un-hide one they hid.
  assertEqual(S.MINIMAP_PATH, "global.minimap.shown")
  assertEqual(S.MINIMAP_STORE, "global.minimap.hide")
  assertEqual(NS.defaults.global.minimap.shown, nil, "a `shown` default is the second copy #81 forbids")
  assertEqual(type(NS.db.global.minimap), "table", "the declared default never materialized")
  assertEqual(NS.defaults.global.minimap.hide, false,
    "the shipped default is not 'shown' -- a fresh install starts with no button")
  assertEqual(NS.db.profile.minimap, nil, "there is a second minimap table under the profile")
end)

test("Minimap row: get INVERTS, so the label and the stored key disagree on purpose", function()
  NS.db.global.minimap.hide = false
  assertEqual(S:Get(S.MINIMAP_PATH), true, "hidden = false must read back as shown = true")
  NS.db.global.minimap.hide = true
  assertEqual(S:Get(S.MINIMAP_PATH), false, "hidden = true must read back as shown = false")
  NS.db.global.minimap.hide = false
end)

test("Minimap row: set INVERTS and moves the button in the same act", function()
  -- The set goes through the single write seam like every other row, and calls LibDBIcon's
  -- Show / Hide there, so the button follows the checkbox immediately rather than at the next
  -- reload.
  S:Set(S.MINIMAP_PATH, false)
  assertEqual(NS.db.global.minimap.hide, true, "unticking the row did not set hide = true")
  assertFalse(button().shown, "the button is still on the minimap after the row was unticked")
  assertEqual(S:Get(S.MINIMAP_PATH), false, "the row reads back the opposite of what was set")

  S:Set(S.MINIMAP_PATH, true)
  assertEqual(NS.db.global.minimap.hide, false)
  assertTrue(button().shown, "the button did not come back")
  assertEqual(S:Get(S.MINIMAP_PATH), true)
end)

test("Minimap row: the write seam inverts on its own, not only through the library", function()
  -- The seam writes `hide` itself and THEN calls SetShown, which the library documents as writing
  -- it a second time with the same value. That makes the two redundant on a healthy install -- and
  -- redundant is exactly the state in which a dropped inversion is invisible, because the library
  -- quietly corrects the seam's mistake. So this case removes the corrector: `Launcher.lua` alone
  -- is left out of the vendored payload, which is what a truncated libs/ folder looks like, and the
  -- stub's SetShown writes nothing. The store must still be right.
  local ns = loadPartial({ Launcher = true })
  local path = ns.Schema.MINIMAP_PATH
  assertTrue(ns.Schema:FindRow(path) ~= nil, "the row went with the launcher -- it is the Options major's")
  assertFalse(ns.Launcher:SetShown(false), "the stub claimed it moved a button")

  ns.Schema:Set(path, false)
  assertEqual(ns.db.global.minimap.hide, true, "the seam stored the row's own sense, un-inverted")
  ns.Schema:Set(path, true)
  assertEqual(ns.db.global.minimap.hide, false, "the seam stored the row's own sense, un-inverted")
  assertEqual(ns.Schema:Get(path), true)
end)

test("Minimap row: LibDBIcon holds the very table the row writes, not a copy", function()
  -- The identity is the rule (launcher-§3). Two tables holding one boolean read correctly on both
  -- sides only while nothing but the row writes: the row (through NS.Launcher:SetShown) writes
  -- `hide` on ITS table, LibDBIcon draws the button from the table IT holds and writes
  -- `minimapPos` there on drag, and the moment the two tables differ the checkbox reports the
  -- opposite of the button and nothing anywhere says so. (LibDBIcon ships no right-click menu of
  -- its own; right-click on this button opens the Ka0s options menu, which does not write `hide`.)
  assertEqual(button().db, NS.db.global.minimap,
    "LibDBIcon was handed a copy, so its own menu writes a boolean the checkbox never reads")

  -- Drive it from LibDBIcon's end (the mock's Show/Hide write `hide` on the table the library
  -- holds) and read the checkbox: only a shared table carries the write across.
  mocks.LibStub("LibDBIcon-1.0"):Hide(NAME)
  assertEqual(S:Get(S.MINIMAP_PATH), false,
    "the library hid the button and the checkbox still reads ticked")
  mocks.LibStub("LibDBIcon-1.0"):Show(NAME)
  assertEqual(S:Get(S.MINIMAP_PATH), true)
end)

--- Every line printed while running `fn`.
local function capture(fn)
  local chat = mocks.__chat
  local before = #chat
  fn()
  local out = {}
  for i = before + 1, #chat do out[#out + 1] = chat[i] end
  return out
end

test("Launcher: /pm get global.minimap.shown answers true while the button shows, and writes land on hide", function()
  -- The CLI name reads in the row's own sense (launcher-§3, v2.65.0). Before the rename the path
  -- was the stored key, so `/pm get global.minimap.hide` answered `true` while the button was ON
  -- the minimap and `set ... false` hid it -- a player reading the verb got the opposite answer.
  NS.db.global.minimap.hide = false
  local lines = capture(function() NS.Slash:OnSlash("get global.minimap.shown") end)
  assertEqual(#lines, 1)
  assertTrue(lines[1]:find("= |cFFFFFFFFtrue|r", 1, true) ~= nil,
    "the button shows and the verb did not answer true: " .. tostring(lines[1]))

  NS.Slash:OnSlash("set global.minimap.shown false")
  assertEqual(NS.db.global.minimap.hide, true, "the set did not land on LibDBIcon's `hide`")
  assertEqual(NS.db.global.minimap.shown, nil, "a `shown` key was written beside `hide` (#81)")
  assertFalse(button().shown, "the button is still on the minimap")

  -- The old path is not kept as an alias: it answers the unknown-setting refusal.
  lines = capture(function() NS.Slash:OnSlash("get global.minimap.hide") end)
  assertTrue(lines[1] ~= nil and lines[1]:find("Setting not found", 1, true) ~= nil,
    "the retired path still answers: " .. tostring(lines[1]))

  NS.Slash:OnSlash("set global.minimap.shown true")
  assertEqual(NS.db.global.minimap.hide, false)
  assertTrue(button().shown)
end)

test("Minimap row: a legacy store keeps its setting across the rename, with no migration", function()
  -- The stored key did not move, so an existing player's `hide = true` reads as shown = false with
  -- no code and no schema-version bump; LibDBIcon's `minimapPos` is untouched; and no write ever
  -- plants a `shown` key in the raw SavedVariables.
  --
  -- The legacy SavedVariables are laid over what the AceDB mock builds, in the window
  -- tests/degraded_env.lua opens before the addon's own files load, so LibDBIcon registers against
  -- the stored table exactly as it would on a player's login.
  local ns, m = loadPartial({}, function(m)
    local AceDB = m.__libs["AceDB-3.0"]
    local realNew = AceDB.New
    AceDB.New = function(...)
      local db = realNew(...)
      db.global.minimap = { hide = true, minimapPos = 200 }
      return db
    end
  end)
  local raw = ns.db.global.minimap
  local path = ns.Schema.MINIMAP_PATH
  assertEqual(ns.Schema:Get(path), false, "a legacy hide = true reads as shown")
  local lines = {}
  local chat = m.__chat
  local before = #chat
  ns.Slash:OnSlash("get " .. path)
  for i = before + 1, #chat do lines[#lines + 1] = chat[i] end
  assertTrue(lines[1] ~= nil and lines[1]:find("= |cFFFFFFFFfalse|r", 1, true) ~= nil,
    "the legacy hidden button does not read false on the CLI: " .. tostring(lines[1]))
  assertFalse(m.__minimapButtons[NAME].shown, "the legacy hidden button came back on the rename")
  assertEqual(raw.minimapPos, 200, "the dragged angle moved")
  assertEqual(raw.hide, true)

  ns.Slash:OnSlash("set " .. path .. " false")
  ns.Schema:Set(path, true)
  ns.Schema:Set(path, false)
  assertEqual(raw.shown, nil, "a `shown` key was written to the raw SV (#81)")
  assertEqual(raw.hide, true)
  assertEqual(raw.minimapPos, 200, "a write moved the dragged angle")
  assertFalse(m.__minimapButtons[NAME].shown)
end)

-- ── surviving a reset (launcher-§3, as amended at standard v2.54.0) ────────────
--
-- The rule is now a PROPERTY of the setting rather than something derived from where it is stored:
-- a player's minimap-button choice is a per-installation display preference, like the ANGLE
-- LibDBIcon keeps two keys away in the same table, and it must survive BOTH options-ui-§12's
-- *Reset all settings* AND a page-scoped Defaults button. The old derivation -- global table,
-- profile reset, therefore unreachable -- was withdrawn because it is not universal and because it
-- only ever spoke about one of the two controls.
--
-- So both controls are driven HERE, for real, from the entry point a player's click reaches. Each
-- case also asserts that the reset actually RAN: a case that only checks `hide` would pass over a
-- reset that did nothing at all, which is the shape of vacuous coverage this pair exists to avoid.

--- Hide the button, run `fn`, and assert it is still hidden and the reset genuinely happened.
local function assertSurvivesReset(fn, what)
  NS.Registry:DeleteAll()
  S:Set(S.MINIMAP_PATH, false)          -- the player hides the button
  S:Set("settings.gridSize", 16)        -- a profile row the reset must move, so it cannot no-op
  assertEqual(NS.db.global.minimap.hide, true, "the fixture never hid the button")

  fn()

  assertEqual(S:Get("settings.gridSize"), 4, what .. " did not actually reset anything")
  assertEqual(NS.db.global.minimap.hide, true,
    what .. " un-hid a button the player deliberately hid")
  assertEqual(S:Get(S.MINIMAP_PATH), false, what .. " left the checkbox disagreeing with the store")
  S:Set(S.MINIMAP_PATH, true)
end

test("Minimap row: Reset all settings does not un-hide the button", function()
  -- Driven through the popup's own OnAccept, which is what `/pm resetall`, the header Defaults
  -- button and the composed *Reset all settings* button all end in (Sl:ConfirmResetAll). That is
  -- `db:ResetProfile()` on the active profile; `db.global` is a different table and is untouched.
  assertSurvivesReset(function()
    NS.Slash:ConfirmResetAll()
    mocks.StaticPopupDialogs["KA0S_PANELMASTER_RESETALL"].OnAccept()
  end, "Reset all settings")
end)

test("Minimap row: the General page's Defaults button does not un-hide the button", function()
  -- THE SECOND SHAPE launcher-§3 names, and the one the old derivation said nothing about: a page
  -- Defaults button that walks every Master-controls row carrying a `default` reaches the row
  -- wherever it is stored. The library's O.RestoreDefaults WOULD -- `rowsForPage("general")`
  -- answers the whole schema and the composed *Minimap button* row is spliced at its head -- so
  -- what keeps this addon safe is that settings/Panel.lua rebinds the page's `defaultsOnClick` to
  -- P:RestoreDefaults, the same profile reset as above.
  --
  -- Driven through `ctx.panel.defaultsOnClick`, which is the field the button's OnClick is wired to
  -- and the field O.CreatePanel's OnDefault forwards the Blizzard footer control to. Calling
  -- P:RestoreDefaults directly instead would pass while the button was wired to the library's walk.
  -- red under: dropping the rebinding in settings/Panel.lua.
  local ctx = NS.Panel.general
  assertTrue(ctx ~= nil and ctx.panel ~= nil, "the General page never built")
  assertEqual(type(ctx.panel.defaultsOnClick), "function", "the Defaults button has no handler")

  assertSurvivesReset(function()
    ctx.panel.defaultsOnClick()
    mocks.StaticPopupDialogs["KA0S_PANELMASTER_RESETALL"].OnAccept()
  end, "the General page's Defaults button")
end)

test("Minimap row: Register validates it, rather than exempting it", function()
  -- It is the ONE stored row outside db.profile, and the one closure-backed row: its path names the
  -- row and is never declared, so the boot check skips the PATH and reads the STORE against the
  -- GLOBAL defaults. Exempting it instead would leave the addon's only cross-store path unchecked,
  -- which is the escape hatch settings/Schema.lua's own header spent a paragraph removing.
  assertEqual(S:Register(), 0)

  -- And the store check can fire: drop the declared `hide` and it counts one missing.
  local declared = NS.defaults.global.minimap.hide
  NS.defaults.global.minimap.hide = nil
  local problems = S:Register()
  NS.defaults.global.minimap.hide = declared
  assertEqual(problems, 1, "an undeclared store was not counted")
end)

-- ── degradation ────────────────────────────────────────────────────────────────

test("Degraded install: no LibDataBroker and no LibDBIcon must not raise", function()
  -- The broker libraries are resolved with LibStub(..., true) at REGISTER time, and a host carrying
  -- neither must get a launcher that reports itself absent rather than one that takes the addon
  -- out. `libs/` folders are not identical across eleven addons and a player can delete a folder.
  --
  -- Built by taking the two libraries back OUT of a real environment, in the window
  -- tests/degraded_env.lua opens between the library files and the addon's own -- rather than by
  -- stubbing `lib = nil` inside the seam, which tests a branch instead of an install.
  local ns = loadPartial({}, function(m)
    m.__libs["LibDataBroker-1.1"] = nil
    m.__libs["LibDBIcon-1.0"] = nil
  end)
  assertTrue(ns.Launcher ~= nil, "the seam did not publish NS.Launcher at all")
  assertFalse(ns.Launcher:IsRegistered(), "it claims to be registered with no broker library")
  assertEqual(ns.Launcher:Object(), nil, "an object was built with no LibDataBroker")

  -- And the row still reads and writes. The STORE is the addon's, not the library's, so the
  -- checkbox keeps working and only the button is missing.
  ns.Schema:Set(ns.Schema.MINIMAP_PATH, false)
  assertEqual(ns.db.global.minimap.hide, true, "the row stopped storing when the button went")
  assertEqual(ns.Schema:Get(ns.Schema.MINIMAP_PATH), false)
end)

test("Degraded install: LibDataBroker alone gets the broker plugin and no button", function()
  -- The honest half-state, and why Register answers false for it: a host with LibDataBroker but no
  -- LibDBIcon still gets its row in a broker display, and the section's headline surface -- the
  -- button -- is not there.
  local ns, m = loadPartial({}, function(mm) mm.__libs["LibDBIcon-1.0"] = nil end)
  assertFalse(ns.Launcher:IsRegistered(), "it claims the button is there with no LibDBIcon")
  assertTrue(ns.Launcher:Object() ~= nil, "the broker plugin went too")
  assertEqual(m.__minimapButtons[NAME], nil, "a button was registered with no library to draw it")
  -- The one object is still clickable from the display that does exist. This environment carries
  -- no MenuUtil, so the right click takes the library's fallback to the panel as well.
  local object = ns.Launcher:Object()
  m.__openedCategory = nil
  object.OnClick(object, "LeftButton")
  assertEqual(m.__openedCategory, 1, "the broker row's left click does not open the panel")
  m.__openedCategory = nil
  object.OnClick(object, "RightButton")
  assertEqual(m.__openedCategory, 1, "the broker row's right click does not open the panel")
end)

test("Degraded install: no LibKa0s leaves a launcher stub that answers and never raises", function()
  local ns = loadDegraded()
  assertTrue(ns.Launcher ~= nil, "NS.Launcher is nil, so core/PanelMaster.lua's Register call is a raise")
  assertFalse(ns.Launcher:Register(), "the stub claimed it registered something")
  assertFalse(ns.Launcher:IsRegistered())
  assertEqual(ns.Launcher:Object(), nil)
  assertFalse(ns.Launcher:SetShown(true), "the stub claimed it moved a button")
  -- IsShown reads the STORE rather than answering a constant, so it is still the player's own
  -- choice on a host where the button was never drawn.
  ns.db.global.minimap.hide = true
  assertFalse(ns.Launcher:IsShown())
  ns.db.global.minimap.hide = false
  assertTrue(ns.Launcher:IsShown())
end)

test("Degraded install: the launcher stub announces nothing at login", function()
  -- Deliberate, and the one place this addon's stubs differ from each other. Every other seam's
  -- stub explains itself when the player reaches for what is gone -- `/pm debug`, `/pm config`. The
  -- launcher has no such act: its button was never drawn and its checkbox is composed by the SAME
  -- missing payload, so on this arm the row does not exist either. A notice with no act behind it
  -- would be a second unprompted login line on top of core/CoreSetup.lua's, which has already named
  -- the cause -- and it would consume that seam's once-per-session notice before the first line the
  -- player actually asked for.
  local ns, m = loadDegraded()
  for _, line in ipairs(m.__chat) do
    assertFalse(line:find("minimap", 1, true) ~= nil,
      "the launcher stub printed a login line: " .. line)
  end
  assertEqual(ns.Schema:FindRow(ns.Schema.MINIMAP_PATH), nil,
    "the degraded schema composed a Minimap button row after all")
end)
