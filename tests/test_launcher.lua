local T = _G.PM_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse
local S = NS.Schema

-- The launcher's own suite: the minimap button, the broker plugin, the rung and the Minimap button
-- row (launcher). The two reserved verbs the same standard version added are in
-- tests/test_slash.lua, beside the rest of this addon's slash surface -- they are aliases onto a
-- schema path and have nothing to do with the button.
--
-- WHAT ONLY THIS FILE CAN ANSWER. Every one of these surfaces is invisible to the rest of the
-- harness, and each fails silently in the client rather than raising:
--   * a launcher wired to a SECOND copy of the lock state behaves correctly the first time and
--     drifts on the first change made from the other surface (anti-pattern #81);
--   * a `hide` written without the inversion turns the button off when the player turns it on, and
--     the checkbox reads back its own wrong answer, so nothing contradicts it;
--   * a table COPIED rather than handed to LibDBIcon reads and writes correctly on both sides
--     until the player uses the library's own right-click menu;
--   * a `Register` that is not idempotent builds a second button over the first, and the two
--     answer different clicks.
-- None of those raises. All of them are one assertion away from being impossible.

local Env = dofile("tests/degraded_env.lua")
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
  assertEqual(object.label, "Ka0s Panel Master")
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

-- ── the rung: (b) lock / unlock (launcher-§2) ──────────────────────────────────

test("Launcher: LEFT-click toggles the addon's lock, which is its preview", function()
  -- Rung (b). This addon has no primary window and no test mode -- unlocking IS the preview, which
  -- is why settings/Schema.lua passes the composer no testModePath -- so the left button spends
  -- itself on the switch that shows every panel with its outline and its name.
  NS.Unlock:SetUnlocked(false)
  assertFalse(NS.State.unlocked, "the fixture did not start locked")

  click("LeftButton")
  assertTrue(NS.State.unlocked, "the left click did not unlock")

  click("LeftButton")
  assertFalse(NS.State.unlocked, "the left click does not toggle -- it only ever unlocks")
end)

test("Launcher: the left click drives the SAME state the Lock frame checkbox drives", function()
  -- The load-bearing case of the whole rung (anti-pattern #81). A launcher holding a second copy of
  -- the lock state behaves correctly until one surface is used and then the other is read.
  NS.Unlock:SetUnlocked(false)

  -- Click, then read the CHECKBOX. The row's sense is LOCKED, so an unlocked addon reads false.
  click("LeftButton")
  assertFalse(S:Get("state.locked"),
    "the button unlocked the panels and the Lock frame checkbox still reads ticked")

  -- Write the CHECKBOX, then read the addon. Same one state, approached from the other end.
  S:Set("state.locked", true)
  assertFalse(NS.State.unlocked, "the checkbox re-locked and the addon stayed unlocked")
  click("LeftButton")
  assertTrue(NS.State.unlocked, "the click after a checkbox write toggled from a stale copy")
  NS.Unlock:SetUnlocked(false)
end)

test("Launcher: the left click goes through the write seam, so it is traced once", function()
  -- Every settings mutation is logged ONCE at the write seam (debug-logging-§10). A click that
  -- reached modules/Unlock.lua directly would move the panels and leave no [Set] line at all, which
  -- is exactly how a second write path hides.
  NS.Unlock:SetUnlocked(false)
  NS.DebugLog:SetEnabled(true)
  NS.DebugLog:Clear()
  click("LeftButton")
  NS.DebugLog:SetEnabled(false)
  assertTrue(NS.DebugLog:FindLine("state.locked") ~= nil,
    "the click left no [Set] line -- it did not take the single write seam")
  NS.Unlock:SetUnlocked(false)
end)

test("Launcher: the left click respects the unlock's combat deferral", function()
  -- Unlocking hands the player draggable frames, so modules/Unlock.lua refuses during combat and
  -- replays on PLAYER_REGEN_ENABLED. Reaching that module through the write seam is what keeps the
  -- click on the same rules as the checkbox; a click that called SetMovable itself would not.
  NS.Unlock:SetUnlocked(false)
  mocks.__inCombat = true
  click("LeftButton")
  assertFalse(NS.State.unlocked, "the click unlocked mid-combat")
  mocks.__inCombat = false
  NS.Unlock:ResumePending()
  assertTrue(NS.State.unlocked, "the deferred unlock was never replayed")
  NS.Unlock:SetUnlocked(false)
end)

-- ── right-click always opens the settings panel (launcher-§2) ──────────────────

test("Launcher: RIGHT-click opens the settings panel", function()
  -- On every addon, whatever rung its left click sits on. That is what lets rungs (a) and (b) spend
  -- the left button on something better -- the panel is never more than one click away.
  mocks.__openedCategory = nil
  mocks.__inCombat = false
  click("RightButton")
  assertEqual(mocks.__openedCategory, 1, "the right click did not open the settings panel")
end)

test("Launcher: RIGHT-click does not touch the lock, and LEFT-click does not open the panel",
  function()
    -- The two buttons are separate acts. A launcher whose right click also toggled, or whose left
    -- click opened the panel, would be one button doing both jobs -- and an addon on rung (b) whose
    -- left click opens the settings panel has skipped the rule rather than chosen a design.
    NS.Unlock:SetUnlocked(false)
    mocks.__openedCategory = nil
    click("RightButton")
    assertFalse(NS.State.unlocked, "the right click moved the lock")

    mocks.__openedCategory = nil
    click("LeftButton")
    assertEqual(mocks.__openedCategory, nil, "the left click opened the settings panel too")
    NS.Unlock:SetUnlocked(false)
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

test("Minimap row: the path is LibDBIcon's own key, in the GLOBAL store", function()
  -- launcher-§3 fixes both halves. `hide` is the boolean LibDBIcon itself writes when the player
  -- uses its right-click menu, so a parallel `minimap.show` here would be a second copy of one
  -- state. And the scope is global so that switching profiles does not move a player's buttons and
  -- options-ui-§12's profile reset does not un-hide one they hid.
  assertEqual(S.MINIMAP_PATH, "global.minimap.hide")
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
  -- sides until the player uses LibDBIcon's OWN right-click menu, which writes `hide` directly --
  -- after which the checkbox reports the opposite of the button and nothing anywhere says so.
  assertEqual(button().db, NS.db.global.minimap,
    "LibDBIcon was handed a copy, so its own menu writes a boolean the checkbox never reads")

  -- Drive it from LibDBIcon's end, as its menu does, and read the checkbox.
  mocks.LibStub("LibDBIcon-1.0"):Hide(NAME)
  assertEqual(S:Get(S.MINIMAP_PATH), false,
    "the library hid the button and the checkbox still reads ticked")
  mocks.LibStub("LibDBIcon-1.0"):Show(NAME)
  assertEqual(S:Get(S.MINIMAP_PATH), true)
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
  -- It is the ONE stored row outside db.profile, so the boot check reads it against the GLOBAL
  -- defaults. Exempting it instead would leave the addon's only cross-store path unchecked, which
  -- is the escape hatch settings/Schema.lua's own header spent a paragraph removing.
  assertEqual(S:Register(), 0)
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
  -- The one object is still clickable from the display that does exist.
  local object = ns.Launcher:Object()
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
