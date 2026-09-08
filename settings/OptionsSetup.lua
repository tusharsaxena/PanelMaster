local _, NS = ...

-- LibKa0s-Options-1.0 seam: the Blizzard settings-canvas shell (options-ui).
--
-- What moves to the library: the canvas factory and its unified header, the breadcrumb, the lazily
-- built Defaults button, the always-shown scrollbar patch, the lazy AceGUI ScrollFrame, section
-- headings and spacers, the tooltip attacher, the five widget makers, the two-column flow engine,
-- the page registry, the refresh fan-out and the combat-gated open.
--
-- What stays this addon's, and why each one is a decision rather than an omission, is documented on
-- the descriptor below and in `settings/Panel.lua`, which keeps the open-dropdown registry, the
-- paired-button width, the landing page and the Profiles page.
--
-- WHERE THIS FILE SITS: after settings/Schema.lua (the descriptor's callbacks read it) and after
-- settings/Slash.lua (`buildMain` renders the command rows through Sl:LandingRows), and BEFORE
-- settings/Panel.lua, which captures this instance at file scope. `settings/PanelEditor.lua` binds
-- its helpers LAZILY inside its own rebuild, so it pins nothing here.

local UNAVAILABLE = NS.LIBKA0S_MISSING .. ", so the settings panel is unavailable."

-- Forward declaration. The landing page's body lives in settings/Panel.lua, which loads AFTER this
-- file, so the descriptor closes over an upvalue that file fills in through the setter below rather
-- than capturing nil forever.
local buildMainBody

local lib = LibStub and LibStub("LibKa0s-Options-1.0", true)

if not lib then
  -- Degrade, never error. `/pm config` is registered unconditionally and says why; everything else
  -- must merely LOAD, because settings/Panel.lua and settings/PanelEditor.lua both run at file
  -- scope against this table. The member set is therefore whatever those two files call, and the
  -- three layout constants are set to ZERO rather than to the library's real values: a stub that
  -- reported plausible geometry would let a caller lay something out against numbers no widget was
  -- ever built from.
  -- Answers EVERY time, and this is the one place in the addon where that is the rule rather than
  -- the exception. The once-per-session latches elsewhere — the Core printer's notice, the
  -- console's — sit on lines that RIDE OTHER OUTPUT, where repeating would drown the line the user
  -- actually asked for. Nothing rides this one: `/pm config` is a verb the user invoked and this
  -- line is its whole answer, so a latch makes the second invocation do nothing at all, which reads
  -- as the command being broken rather than as the panel being unavailable (PM-R-07).
  local function explain()
    NS.Print(UNAVAILABLE)
  end
  local noop = function() end
  NS.Helpers = {
    __degraded = true,
    CreatePanel = function() return { panel = nil, body = nil, refreshers = {} } end,
    EnsureDefaultsButton = noop, EnsureScroll = function() return nil end, ClearScroll = noop,
    Section = noop, AddSpacer = noop, AttachTooltip = noop, InlineButtonPair = noop,
    RenderField = noop, SessionCheckbox = noop, RenderRows = noop, RenderSchema = noop,
    RenderGrid = noop, LSMValues = function() return function() return {} end end,
    RegisterOptionsPage = noop, CreateOptionsPanel = noop,
    OpenOptionsPanel = explain,
    RestoreDefaults = noop, RestoreAllDefaults = noop,
    RefreshAllPanels = noop, RefreshScalars = noop, RefreshPanel = noop, SetRenderer = noop,
    PatchAlwaysShowScrollbar = noop,
    -- The tabbed page (options-ui-§13) and the page banner (options-ui-§14). Both of this addon's
    -- tabbed pages call these at render time, so the stub answers them for the same reason it
    -- answers RenderSchema: a missing member is a raise inside a page build rather than a page
    -- that quietly draws nothing.
    SetChromeHeight = noop, TabStrip = noop, PageBanner = noop,
    -- The chrome BLOCK (options-ui-§14) and the secondary strip (options-ui-§13). PageHeader is
    -- called by settings/PanelEditor.lua on every Panels-page build, so the stub has to answer it;
    -- SubTabStrip has no caller here and is present for the parity case, answering the SHAPE its
    -- live counterpart does (the buttons, then the height it occupies).
    PageHeader = function() return nil end,
    SubTabStrip = function() return {}, 0 end,
    -- The schema composers (OptionsCompose). Each answers an EMPTY ROW LIST, and that is a real
    -- degradation rather than an oversight: what they emit is the library's canonical row data --
    -- the order, the labels, the ranges, the defaults -- and a hand-copied set here would be the
    -- one that goes stale, which is anti-pattern #47 and the whole reason the composers exist.
    -- So a library-less install loses the Master controls rows from the schema and keeps every
    -- other row; tests/test_schema.lua pins that count difference by name so it can never widen
    -- silently (options-ui-§1's measurement rule).
    ColorPair = function() return {} end, FontGroup = function() return {} end,
    BorderGroup = function() return {} end, BarGroup = function() return {} end,
    MasterControls = function() return {}, noop end,
    -- The composers' published constants. Empty tables and empty strings rather than the library's
    -- real values, for the reason the three layout constants above are zero: a stub answering
    -- plausible data lets a caller build a dropdown out of a value set no row was composed from.
    FONT_FLAGS = {}, FONT_FLAGS_SORT = {}, VISIBILITY_VALUES = {}, VISIBILITY_SORT = {},
    MASTER_GROUP = "", CLASS_COLOR_NOTE = "",
    -- RenderTabbedSchema answers a LIST on the live path (the group names, in tab order), so the
    -- stub answers an empty one rather than nil: a host that iterates the result gets a page with
    -- no tabs, which is exactly what a degraded install has, instead of an error.
    RenderTabbedSchema = function() return {} end,
    -- NO `__`-PREFIXED LIBRARY INTERNALS BELOW, and their absence is a decision rather than an
    -- oversight. Twelve of them used to sit here -- __pages, __panels, __panelFor, the six chrome
    -- band primitives, __tabArtHeight and __resetTabArtHeight -- and the only reason recorded for
    -- any of them was that the parity case read the WHOLE live surface, so an internal the stub
    -- omitted was indistinguishable from one it forgot. That is no longer how the gate works:
    -- tests/test_surface_parity.lua calls Kit.assertSurfaceParity's by-name form, which compares
    -- Kit.publicMembers and drops the whole `__` prefix, and libs/LibKa0s/Options.lua says the
    -- same thing where it publishes O.__print -- an internal is the library talking to itself
    -- across a file boundary, and a stub does not mirror it. Nothing in this addon calls one:
    --   grep -rn '__pages\|__panels\|__panelFor\|__bannerBand\|__tabBand\|__tabPlacement' \
    --     core modules settings
    -- returns settings/PanelEditor.lua's own unrelated __panelsByName and nothing else. So they
    -- were twelve members with no caller and no gate, which is the copy that goes stale.
    --
    -- `__degraded` above STAYS: it is this addon's own flag, not the library's, and it is how the
    -- suite tells which arm ran.
    ROW_VSPACER = 0, SECTION_HEADING_H = 0, BUTTON_PAIR_REL = 0,
    -- The three chrome heights, ZERO for exactly the reason the three above are: a stub reporting
    -- the library's real band geometry would let a caller lay something out against numbers no
    -- widget was ever built from.
    CHROME_GAP = 0, TAB_H = 0, BANNER_H = 0,
    AceGUI = nil,
  }
  function NS.SetBuildMain() end
  -- Called on BOTH arms, because the Master controls block is composed rather than declared
  -- (settings/Schema.lua) and this is the first moment NS.Helpers exists. Here it answers false
  -- and the schema keeps the rows it declared itself, which is the measured degradation the stub
  -- above documents.
  NS.Schema:InstallMaster(NS.Helpers)
  return
end

-- The LSM30_Border fixup, and why it is a call rather than a file.
--
-- A LIBRARY ACT, NOT AN ADDON ONE. AceGUI's widget registry is process-global: one slot named
-- "LSM30_Border" that every addon in the client shares, Ka0s or not, and the highest version
-- registered for the name wins for the rest of the session. This addon carried the fixup privately
-- in core/LSMPatch.lua, and so did AbsorbTracker, ConsumableMaster, KickCD and MultiMeters -- five
-- copies, five distinct md5s, each wrapping whatever it found and registering one version above
-- it. Load all five and the wrapper a Border dropdown actually gets belongs to whichever addon the
-- client reached last. Nothing in any of the five repos could see that: each suite loads a single
-- copy, registers once and passes.
--
-- lib.__PatchLSM30Border (LibKa0s-Options-1.0 minor 15) is the same wrapper published once, behind
-- lib.__lsmBorderPatched. LibStub hands five vendored copies of the library the same instance, so
-- five callers produce one registration and the return value says which call made it. Calling it
-- is unconditional and needs no agreement with any sibling addon.
--
-- HERE, AT FILE LOAD, is early enough. PanelMaster.toc pulls
-- libs\AceGUI-3.0-SharedMediaWidgets\widget.xml in with the other libraries (:27), well before
-- settings\OptionsSetup.lua (:86), so the slot already holds AGSMW's own constructor when this
-- line runs. A registration whose version is not strictly higher than the one already held is
-- refused, so another addon's later copy of AGSMW cannot take the slot back at its own fixed
-- version. (Worded around the AceGUI entry point on purpose: C02's acceptance is a grep for that
-- identifier over core/, modules/ and settings/ returning nothing, and a prose mention is a hit an
-- auditor has to read and dismiss.)
--
-- It sits in THIS file because this is where the addon's options surface is wired, which is where
-- the library's own note on the member says to call it from -- and because this is the live arm:
-- an install with no libs/LibKa0s took the degraded return above and has no library to ask.
--
-- core/LSMPatch.lua IS GONE, deleted in the same commit that added this line. Keeping it would
-- have been a second registration of a wrapper the library has already installed -- harmless in
-- effect, since both hide the same tile and re-anchor the same two regions, but it is the exact
-- shape the promotion exists to remove.
lib.__PatchLSM30Border()

NS.Helpers = lib:New({
  -- The brand: shown on the main page and as every sub-page's breadcrumb prefix. The library's
  -- BREADCRUMB_SEP is the same inline forward-arrow atlas this addon composed by hand, so
  -- "Ka0s Panel Master ▸ General" renders byte-for-byte as before.
  parentTitle   = "Ka0s Panel Master",
  -- Names the main canvas so /framestack attributes it to this addon. The old createPanel passed
  -- nil here, so every one of this addon's canvases was anonymous and unattributable.
  mainPanelName = "PanelMasterOptionsPanel",

  print = function(line) NS.Print(line) end,
  debug = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end,

  -- The write seam. NS.Schema:Set is already the two-argument shape the library calls with — it is
  -- this addon's single write path, validating, logging once and firing onChange — so no arity
  -- adapter is needed and a panel write takes exactly the path a slash write does.
  get          = function(path) return NS.Schema:Get(path) end,
  set          = function(path, v) NS.Schema:Set(path, v) end,
  applyDefault = function(row) NS.Schema:Set(row.path, NS.Schema:Default(row.path)) end,
  allRows      = function() return NS.Schema.Schema end,

  -- ADAPTER. This addon's schema has no `page` field: every settings row belongs to the one General
  -- page, and the groups within it are section headings rather than pages.
  --
  -- BOTH ARGUMENTS ARE NAMED even though only the first is read. The library calls this as
  -- `rowsForPage(pageKey, ctx.unit)`, and a callback declared one argument short of the seam that
  -- calls it is the forwarder anti-pattern in its quietest form: nothing raises, the second value is
  -- simply gone, and the day a per-unit page appears the filter is dropped by a signature nobody
  -- would think to look at. `filter` is ctx.unit, which this addon never sets — it has no per-unit
  -- pages — so it is ignored HERE, visibly, rather than never arriving.
  rowsForPage = function(pageKey, filter)   -- luacheck: ignore 212/filter
    if pageKey ~= "general" then return {} end
    return NS.Schema.Schema
  end,

  -- Boot validation (architecture-§5): every schema path must resolve against the defaults table,
  -- so a typo in a path is caught loudly at load instead of reading nil forever. The library runs
  -- this once, before the page builders.
  validate = function() if NS.Schema and NS.Schema.Register then NS.Schema:Register() end end,

  -- `onAceGUI` is DELIBERATELY NOT PASSED. It used to stash the handle as `NS.AceGUI` on the claim
  -- that this meant "no page file makes its own LibStub call" — which was never true and had no
  -- reader: the library already publishes the handle on the instance as `O.AceGUI`, which is what
  -- settings/Panel.lua reads where it needs the library's own resolution, and a second addon-side
  -- home for the same singleton is exactly the drift a stash like that invites.
  --
  -- The two remaining `LibStub("AceGUI-3.0", true)` calls each resolve that one singleton once and
  -- keep it as an upvalue — settings/Panel.lua and settings/PanelEditor.lua, both at file scope,
  -- which is BEFORE this descriptor's instance exists. Neither can be served from a build-time
  -- seam, so removing the stash removes a duplicate, not a consumer. There were THREE until the
  -- Border fixup above became a library call: core/LSMPatch.lua resolved AceGUI itself, inside a
  -- PLAYER_LOGIN handler that ran with no options page in play at all.

  -- The landing page's body. Through the forward-declared upvalue, so settings/Panel.lua can define
  -- it after this file has loaded.
  buildMain = function(ctx) if buildMainBody then buildMainBody(ctx) end end,

  -- Backs the color picker's and the live slider's 50 ms drag throttle. A descriptor field rather
  -- than an AceTimer embed inside the library, which would be its second dependency-budget breach.
  -- Resolved at CALL time: NS.addon is created in core/PanelMaster.lua, which loads earlier, but a
  -- closure costs nothing and cannot be wrong.
  scheduleTimer = function(fn, delay)
    if NS.addon and NS.addon.ScheduleTimer then return NS.addon:ScheduleTimer(fn, delay) end
  end,

  -- DELIBERATELY NOT PASSED:
  --
  --   colorDecode / colorEncode — this addon has no COLOR schema row. Its colors all live on
  --                panel RECORDS, which settings/PanelEditor.lua draws by hand from
  --                NS.Registry, not from the schema, so there is nothing here for a codec to
  --                translate. If a color row is ever added, both majors take the same pair.
  --   getLSM     — same reasoning. The three LSM-backed dropdowns are per-PANEL media pickers that
  --                PanelEditor builds itself with the LSM30_* widgets; no schema row is media-backed,
  --                so O.LSMValues would have no caller.
  --   skipRestoreAll / afterRestoreAll — this addon does not use O.RestoreAllDefaults at all,
  --                because its global reset is not a row walk. `Sl:CliResetAll` confirms and then
  --                calls `Sl:DoResetAll`, which is `db:ResetProfile()` on the active profile and
  --                nothing else (options-ui-§12, and settings/Slash.lua's header states the rule).
  --                Both hooks exist to shape a walk of `allRows`, so with no walk there is nothing
  --                for them to shape.
  --
  --                The session-only rows -- `state.locked`, `state.preview`, `state.debugConsole` --
  --                are outside BOTH acts, and that is deliberate rather than an oversight. They
  --                store nothing in the DB (settings/Schema.lua's `S:Set` sends a sessionOnly row
  --                to its own `set` and never to WritePath), so a profile reset has nothing of
  --                theirs to reset, while the library's walk would call `applyDefault` on each and
  --                write a default the row does not store. What a reset DOES sweep is the durable
  --                half: `OnProfileReset` reaches the `reload` closure in core/Database.lua, which
  --                clears preview placeholder RECORDS out of the profile and reloads the registry.
  --                The session flags themselves are cleared by their own `set`, or by a /reload.
  --   sliderCommit — the default (commit on release) is what this addon has always done. Neither
  --                slider drives anything the user can see mid-drag: grid size applies to the next
  --                drag, and default opacity applies to the next panel created.
  --   L          — LibKa0s-Options-1.0 reads no descriptor `L` at all, so there is nothing to pass.
  --                tests/test_libka0s.lua carries a tripwire that goes red the day it grows one.
})

-- The General page's FIRST tab (options-ui-§15), composed out of the instance built just above and
-- spliced at the head of NS.Schema.Schema. It happens HERE rather than in settings/Schema.lua for
-- the reason that file states: the composer lives on this instance, and this file loads after it.
--
-- Before settings/Panel.lua, which reads NS.Schema.MasterAfterGroup at render time — but the
-- ordering that actually binds is NS.addon:OnInitialize's `NS.Schema:Register()`, which validates
-- every path against the defaults and can only reach the composed rows once this has run. Four of
-- the seven are db-backed and resolve against defaults/Profile.lua; the other three are
-- session-only (state.locked, state.debugConsole, state.preview) and Register exempts those by
-- design. Run this any later and the rows are simply not in the array yet — nothing is reported
-- because nothing is checked.
NS.Schema:InstallMaster(NS.Helpers)

--- Let settings/Panel.lua install the landing page's body after this file has loaded.
function NS.SetBuildMain(fn) buildMainBody = fn end
