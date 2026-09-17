local addonName, NS = ...

-- LibKa0s-Launcher-1.0 seam: the minimap button and the broker plugin (launcher).
--
-- ── ONE OBJECT, REGISTERED TWICE ────────────────────────────────────────────────
--
-- Not two features. There is a single LibDataBroker-1.1 object; LibDBIcon-1.0 draws the minimap
-- button from it and any broker display the player runs (Titan Panel, ElvUI data texts, Bazooka)
-- draws its own row from the very same object. One OnClick, one icon, one label, one identity. An
-- addon that builds a button with its own handler and a broker object with a second one has written
-- the feature twice and drifts on the first behavior change (anti-pattern #81) — which is why every
-- line of that wiring is the library's and this file supplies only what is genuinely PanelMaster's:
-- its folder name, its logo, what its left button does, and how its settings panel opens.
--
-- ── THE RUNG IS (b), AND LOCK FRAME IS THE SWITCH ───────────────────────────────
--
-- launcher-§2's left-click ladder is first-match-wins. (a) does not apply: this addon has no primary
-- window — its product is the panels themselves, drawn on the world, and the settings panel is the
-- only window it owns. (b) does: unlocking IS this addon's preview. There is no separate test mode
-- and deliberately so (settings/Schema.lua's InstallMaster passes no `testModePath`, standard
-- v2.49.0) — unlocking already draws every panel with its outline and its name label, which is
-- exactly what a test mode would have shown. So the launcher's left button toggles lock, and the
-- rung is recorded in the standard's own ADDONS.md as "(b) lock / unlock".
--
-- IT DRIVES THE SAME SEAM THE CHECKBOX DRIVES, and never a second copy of the state. `onClick`
-- below writes `state.locked` through `NS.Schema:Set`, which is this addon's single write seam
-- (options-ui-§1): the same call the Master-controls *Lock frame* checkbox makes, validated the same
-- way, logged once the same way, and ending in the same `NS.Unlock:SetUnlocked` — including its
-- combat deferral, which is why the click must not reach modules/Unlock.lua directly. A player who
-- clicks the button and then opens the panel sees the checkbox already agreeing, because there was
-- only ever one answer.
--
-- RIGHT-click always opens the settings panel, on every addon in the collection whatever rung its
-- left click sits on. That is what lets rung (b) spend the left button on something better.
--
-- ── WHY `minimap` IS A FUNCTION AND NOT A TABLE ─────────────────────────────────
--
-- This file runs at TOC load. `NS.db` does not exist yet — AceDB builds it in `NS:InitDB()`, from
-- `addon:OnInitialize` — so a table captured here would be nil, and a table captured after InitDB
-- would still be one AceDB replaces on a profile switch. The library resolves the closure at
-- Register time instead, which is what keeps the table LibDBIcon holds and the table the settings
-- row writes THE SAME TABLE. Two copies of one boolean disagree the first time either is used.
--
-- The scope is GLOBAL rather than profile, and that is the decision rather than an accident
-- (launcher-§3): a minimap button belongs to the INSTALLATION. Switching profiles must not move a
-- player's buttons. `defaults/Global.lua` declares it.
--
-- SURVIVING A RESET IS A PROPERTY OF THE SETTING, NOT A CONSEQUENCE OF THAT SCOPE (launcher-§3, as
-- amended at standard v2.54.0). Whether the button is shown is a per-installation display
-- preference, in the same class as the POSITION the player dragged it to -- which LibDBIcon keeps in
-- this very table and which no reset touches. So it must survive options-ui-§12's *Reset all
-- settings* AND a page-scoped Defaults button, and the global store is not the argument for that:
-- an addon with no profile at all resets its global store wholesale, and a page Defaults button
-- that walks every Master-controls row with a `default` reaches the row wherever it is stored.
-- What this addon's two resets actually do is in defaults/Global.lua, which owns the finding.
--
-- ── WHERE THIS FILE SITS ────────────────────────────────────────────────────────
--
-- After core/Constants.lua, for `C.ICON_PATH`, which is read at FILE LOAD into the descriptor and
-- is the only thing that binds this file's position. Everything else — NS.db, NS.Schema, NS.Panel,
-- NS.Print, NS.Debug — is reached through a CLOSURE and resolved at call time. Register is
-- called from `addon:OnInitialize` AFTER `NS:InitDB()`, because that is the first moment
-- `db.global.minimap` exists for the closure to answer with.
--
-- ── WHAT A DEGRADED INSTALL GETS ────────────────────────────────────────────────
--
-- Three separate absences, and each is survivable on its own. No LibKa0s means no Launcher major,
-- and the stub below answers every member this addon calls. No LibDataBroker means no object at all
-- and the library says so on one line. No LibDBIcon means the broker plugin still registers and only
-- the minimap button is missing — which is the honest half-state, and why `Register` answers false
-- there. None of the three raises, and `tests/test_libka0s.lua` pins that.

local C = NS.Constants

--- LibDBIcon's own table, resolved at CALL time. See the header.
---
--- Answers nil before `NS:InitDB()` has run, which the library treats as "nowhere to keep the
--- button's position" and reports. It is never seeded here: the table materializes from the
--- declared default in `defaults/Global.lua`, which is what architecture-§5 requires of a path a
--- schema row addresses -- LibDBIcon's own `minimapPos` writes land in the same table and need no
--- row of their own.
local function minimapTable()
  return NS.db and NS.db.global and NS.db.global.minimap
end

--- Open the settings panel. RIGHT-click always calls this; so would left-click on rung (c).
local function openSettings()
  if NS.Panel then NS.Panel:Open() end
end

--- THE LEFT CLICK, and the rung (launcher-§2 (b)).
---
--- Through `NS.Schema:Set`, never through `NS.Unlock` directly: see the header. The row's sense is
--- LOCKED, so toggling it is a plain negation of what the row reads back.
---
--- REFUSED WHILE THE ADDON IS DISABLED (launcher-§2, slash-commands-§7), on one line and with no
--- other effect. This rung drives a PREVIEW SWITCH -- unlocking is this addon's preview -- and a
--- preview of panels that are not drawn is not a coherent request. The refusal is placed before the
--- write and not after it, which is the whole of the rule: the audit's live example is a minimap
--- button with no disabled gate at all, writing the stored tree of an addon the player switched off,
--- and a click is a game event in every sense that matters.
---
--- RUNG (c)'s CARVE-OUT DOES NOT REACH THIS ADDON, and it is worth saying so rather than leaving it
--- to be re-derived: a rung-(c) left-click opens the settings panel, which §7 lists among the things
--- that SURVIVE, so refusing it would decline one button for doing exactly what the right button
--- beside it is required to keep doing. This addon is on rung (b) (the standard's own `ADDONS.md`
--- records it), its left button drives a feature, and so it is refused. RIGHT-click is untouched in
--- either state -- `openSettings` above carries no gate, deliberately, because §7 nominates that
--- click as one of the two routes to the panel and a mouse click is not a slash command.
---
--- The line is the DISPATCHER'S (`Sl:DisabledLine()`), not a second copy worded here: the refusal is
--- one shape collection-wide, and eleven addons each spelling it slightly differently is the drift
--- the shared printer exists to end. Guarded on the forwarder existing so a client with no LibKa0s
--- at all -- where this file is already the stub above -- cannot raise inside a button click.
local function toggleLock()
  if not NS.Schema then return end
  -- The MASTER SWITCH, not `NS.Lifecycle:IsDown()`. The latch answers "is the addon stood down for
  -- any reason", which a `perf` hold also makes true; launcher-§2's refusal is about the DISABLED
  -- state specifically, and the line it prints names `/pm enable`, which would be the wrong advice
  -- to a player mid-capture. Same question the slash gate asks, through the same seam.
  if NS.IsAddonEnabled and not NS.IsAddonEnabled() then
    if NS.Slash and NS.Slash.DisabledLine then NS.Print(NS.Slash:DisabledLine()) end
    return
  end
  NS.Schema:Set("state.locked", not NS.Schema:Get("state.locked"))
end

local lib = LibStub and LibStub("LibKa0s-Launcher-1.0", true)

if not lib then
  -- Degrade, never error. The member set is what this addon actually calls -- `Register` from
  -- `addon:OnInitialize`, and `SetShown` from the *Minimap button* row's `set` in
  -- settings/Schema.lua -- plus the three the live instance publishes beside them, so a future
  -- caller degrades to nothing happening rather than to a raise. Same bargain the DebugLog and
  -- Options stubs strike, and `tests/test_surface_parity.lua` compares the set.
  --
  -- THIS STUB SAYS NOTHING, and that is the decision rather than an omission. Every other seam's
  -- stub explains itself the moment the player reaches for the thing that is gone: `/pm debug`
  -- opens no console and says why, `/pm config` opens no panel and says why. The launcher has no
  -- such act. Its two surfaces are a minimap button that was never drawn and a *Minimap button*
  -- checkbox composed by `LibKa0s-Options-1.0` -- the SAME missing payload -- so on this arm the
  -- row does not exist either and there is nothing left for a player to invoke. A notice with no
  -- act behind it would be a second unprompted login line on top of core/CoreSetup.lua's, which
  -- has already named the cause.
  --
  -- SetShown ANSWERS FALSE rather than pretending, and deliberately does NOT write the store: the
  -- write seam has already written `db.global.minimap.hide` itself before it calls here, so a
  -- second write would be this file keeping a copy of the one boolean launcher-§3 says there must
  -- be only one of. What is lost on this path is the button moving, and there is no button.
  --
  -- IsShown reads the STORE rather than its receiver, exactly as the live instance does, so the
  -- answer is still the player's own choice rather than `true` because nothing contradicted it.
  local L = {}
  function L:Register() return false end
  function L:IsRegistered() return false end
  function L:Object() return nil end
  function L:IsShown()
    local t = minimapTable()
    if not t then return true end
    return not t.hide
  end
  function L:SetShown() return false end

  NS.Launcher = L
  return
end

NS.Launcher = lib:New({
  -- THE FOLDER NAME, and it is not cosmetic: LibDBIcon keys the button's SAVED POSITION by it, so a
  -- second spelling here would drop the angle the player dragged the button to and label the broker
  -- plugin with the other name. `addonName` is the first vararg every TOC-loaded file gets — not
  -- NS.PREFIX ("[PM]"), not the `## Title` ("Ka0s Panel Master"), not a hand-typed literal that goes
  -- stale the day the folder is renamed. Same rule core/MediaSetup.lua and core/EnvSetup.lua state.
  name  = addonName,
  -- THE BRAND NAME IN PLAIN TEXT -- `Ka0s <Name>` (launcher-§1). This is what a broker display
  -- prints in its own row, and it prints it BESIDE THE OTHER TEN, so it is the one field that
  -- decides whether the collection reads as one collection in Titan Panel or as eleven unrelated
  -- addons that happen to be installed together. Across the eleven adoptions it came out three ways
  -- because nothing said what it was; standard v2.54.0 says what it is, and a display sorting its
  -- plugins alphabetically now files all eleven together under K.
  --
  -- IT IS NOT THE TOC `## Title`, and the two are deliberately NOT wired to each other even though
  -- this addon's Title happens to read the same. A Title MAY carry color escapes and one in the
  -- collection does -- Ka0s Pretty Chat's is `Ka0s |cffff0000P|cffff9900r|cffffff00e|...` -- which a
  -- display drawing the string raw splatters across a row where every other row is plain text, and
  -- one stripping escapes delivers mangled. So: no escape sequence of any kind, and a literal here
  -- rather than a read of the manifest, which is the wiring the rule forbids.
  --
  -- It is not the folder name either. That is `name` above, which LibDBIcon keys the saved position
  -- by and which a player reads nowhere as prose: `PanelMaster` is an identifier,
  -- `Ka0s Panel Master` is a name. Two fields, two jobs.
  --
  -- READ FROM `NS.BRAND` (core/Namespace.lua) rather than re-typed here, and that is the point of
  -- the constant rather than a tidy-up: slash-commands-§7 requires the refusal line a disabled addon
  -- prints to carry THE SAME string this field takes, precisely because launcher-§1 already forbids
  -- escapes in it. Two literals is two spellings, and the day one of them is edited the button and
  -- the chat line name two different addons. It is still a literal -- just one of them.
  label = NS.BRAND,
  -- The same file the TOC's `## IconTexture` names (launcher-§4) — one asset, three surfaces.
  icon  = C.ICON_PATH,

  minimap      = minimapTable,
  openSettings = openSettings,
  -- THE RUNG. Its presence is the whole declaration: rung (c) passes nothing here, and passing
  -- `openSettings` would make a skipped rule look like a choice.
  onClick      = toggleLock,

  print = function(line) NS.Print(line) end,
  debug = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end,

  -- DELIBERATELY NOT PASSED:
  --
  --   onTooltipShow — this addon has nothing to say on hover that the button does not already say
  --                by being there. A tooltip listing the click actions would restate launcher-§2's
  --                fixed ladder, which is the same in all eleven addons, and a per-addon copy of a
  --                collection-wide rule is the copy that goes stale.
  --   L          — this addon translates nothing (locales/enUS.lua ships English-only by an explicit
  --                1.0.0 scope decision), so there is no override to pass. Passing NS.L would be the
  --                `L` trap: its metatable answers every key with the key itself. The library reads
  --                this table with rawget, so that trap could not fire here — but the field would
  --                still be a claim to override strings this addon has no words of its own for.
})
