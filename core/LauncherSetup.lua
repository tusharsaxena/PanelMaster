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
-- its folder name, its logo, how its settings panel opens, and the toggles its options menu offers.
--
-- ── LEFT OPENS SETTINGS, RIGHT OPENS THE OPTIONS MENU (launcher-§2, v2.67.0) ────
--
-- Both buttons are the library's (Launcher minor 4): LEFT-click calls `openSettings`, on every
-- addon and in either state; RIGHT-click opens the client's own context menu, titled with the
-- label, with one checkbox per toggle this descriptor supplies. The left-click rungs are retired,
-- and with them this addon's rung (b) left click that toggled the lock -- that toggle is now the
-- menu's *Locked* entry.
--
-- THE MENU IS "Enabled · Locked", which is the row the standard's own ADDONS.md records for this
-- addon. Enabled, because every addon has the master switch. Locked, because the *Lock frame* row
-- is this addon's lock and unlocking IS its preview. No *Test mode* -- there is none, deliberately
-- (settings/Schema.lua's InstallMaster passes no `testModePath`, standard v2.49.0): unlocking
-- already draws every panel with its outline and its name label, which is what a test mode would
-- have shown. No *Show window* -- this addon has no primary window; its product is the panels
-- themselves, drawn on the world, and the settings panel is the only window it owns.
--
-- EACH ENTRY CALLS THE SAME HANDLER ITS SLASH VERB CALLS, and never a second copy of the state.
-- *Enabled* is `NS.Slash:CliEnable`, the body of `/pm enable` and `/pm disable`; *Locked* is
-- `NS.Slash:CliLock`, the body of `/pm lock` and `/pm unlock`. Each of those is `CliSet` on its
-- row's path whenever the row exists, so a click is the single write seam (options-ui-§1): the
-- same call the Master-controls checkbox makes, validated the same way, logged once, echoed with
-- the same `path = value` line read back from the store, and -- for the lock -- ending in the same
-- `NS.Unlock:SetUnlocked` with its combat deferral. A player who clicks an entry and then opens the
-- panel sees the checkbox already agreeing, because there was only ever one answer.
--
-- WHILE DISABLED the library grays *Locked* and notes "enable the addon first" (slash-commands-§7:
-- features refuse while disabled); *Enabled* stays live, and so does the left click, because the
-- settings panel is where a disabled addon is switched back on.
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

--- Open the settings panel. LEFT-click always calls this (Launcher minor 4), in either state; so
--- does right-click on a client with no context-menu API.
local function openSettings()
  if NS.Panel then NS.Panel:Open() end
end

--- Whether the addon is enabled: the MASTER SWITCH, not `NS.Lifecycle:IsDown()`. The latch answers
--- "is the addon stood down for any reason", which a `perf` hold also makes true; the tooltip's
--- `Enabled:` line, the menu's *Enabled* checkbox and the graying of *Locked* are all about the
--- DISABLED state specifically. Same question the slash gate asks, through the same seam.
local function isEnabled()
  if NS.IsAddonEnabled then return NS.IsAddonEnabled() end
  return true
end

--- The menu's *Enabled* entry: `/pm enable` / `/pm disable`'s own body, handed the state the addon
--- is moving TO. Resolved at call time, because settings/Slash.lua loads after this file.
local function setEnabled(on)
  if NS.Slash and NS.Slash.CliEnable then NS.Slash:CliEnable(on and true or false) end
end

--- Whether the panels are locked: the SAME accessor the Master-controls *Lock frame* row reads
--- (`state.locked` through the write seam), so the tooltip, the menu and the checkbox cannot
--- disagree.
local function isLocked()
  return NS.Schema and NS.Schema:Get("state.locked") and true or false
end

--- The menu's *Locked* entry: `/pm lock` / `/pm unlock`'s own body, `NS.Slash:CliLock`, with the
--- sense read back from the row. Never `NS.Unlock` directly -- see the header.
local function toggleLock()
  if NS.Slash and NS.Slash.CliLock then NS.Slash:CliLock(not isLocked()) end
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
  -- write seam has already written the row's store, S.MINIMAP_STORE (`db.global.minimap.hide`),
  -- itself before it calls here, so a second write would be this file keeping a copy of the one
  -- boolean launcher-§3 says there must be only one of. What is lost on this path is the button
  -- moving, and there is no button.
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

  -- ── THE OPTIONS MENU (launcher-§2, standard v2.67.0; Launcher minor 4) ───────
  --
  -- One accessor-and-toggle pair per state this addon really has, in the library's order. The
  -- accessors are read on every menu open and every hover; the toggles are the slash verbs' own
  -- handlers (see the header). `isEnabled` and `isLocked` also feed the status tooltip.
  isEnabled  = isEnabled,
  setEnabled = setEnabled,
  isLocked   = isLocked,
  toggleLock = toggleLock,

  -- ── THE STATUS TOOLTIP (launcher-§1, standard v2.66.0; Launcher minor 3) ──────
  --
  -- The library draws all of it -- title, Enabled, Locked, the click hints -- on every hover and
  -- while the addon is disabled. The version is the TOC's `## Version`, through the same seam
  -- `/pm version` reads.
  version = function() return NS.Version() end,

  print = function(line) NS.Print(line) end,
  debug = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end,

  -- DELIBERATELY NOT PASSED:
  --
  --   isTestMode / toggleTestMode — this addon HAS no test mode: unlocking is its preview, and
  --                settings/Schema.lua passes the composer no `testModePath`. A `Test mode:` line or
  --                menu entry would report a state that does not exist.
  --   isWindowShown / toggleWindow — this addon has no primary window; the settings panel is the
  --                only window it owns, and the left click already opens it.
  --   onClick, leftClickLabel, disabledLine, slash — retired at Launcher minor 4 (the left button
  --                has one meaning, and there is no disabled refusal left to word). The library
  --                ignores them; passing them would be dead configuration (launcher-§5).
  --   onTooltipShow — this addon has no line of its own to add. The title, the status lines and
  --                the click hints are the library's, and a host that drew any of them again would
  --                draw a second copy (anti-pattern #89).
  --   L          — this addon overrides none of the library's `lib.STRINGS` (locales/enUS.lua ships
  --                English-only by an explicit 1.0.0 scope decision). Passing NS.L here would be the
  --                `L` trap: its metatable answers every key with the key itself. The library reads
  --                this table with rawget, so that trap could not fire here — but the field would
  --                still be a claim to override strings this addon has no words of its own for.
})
