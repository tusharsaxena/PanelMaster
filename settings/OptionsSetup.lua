local addonName, NS = ...   -- luacheck: ignore addonName

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
    __pages = function() return {} end, __panels = function() return {} end,
    __panelFor = function() return nil end,
    ROW_VSPACER = 0, SECTION_HEADING_H = 0, BUTTON_PAIR_REL = 0,
    AceGUI = nil,
  }
  function NS.SetBuildMain() end
  return
end

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
  rowsForPage = function(pageKey, filter)   -- luacheck: ignore filter
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
  -- The three remaining `LibStub("AceGUI-3.0", true)` calls each resolve that one singleton once and
  -- keep it as an upvalue — settings/Panel.lua and settings/PanelEditor.lua at file scope, which is
  -- BEFORE this descriptor's instance exists, and core/LSMPatch.lua once inside its one-shot
  -- PLAYER_LOGIN widget fixup, which runs with no options page in play at all. None of the three can
  -- be served from a build-time seam, so removing the stash removes a duplicate, not a consumer.

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
  --   skipRestoreAll / afterRestoreAll — this addon does not use O.RestoreAllDefaults at all. Its
  --                global reset is `Sl:CliResetAll`, which must ALSO reach the session-only rows
  --                (unlock, preview, the console) through each row's own `set`, and the library's
  --                version walks `allRows` calling `applyDefault`, which for a sessionOnly row would
  --                write a default the row does not store. One reset implementation, and it is the
  --                one both the slash verb and the Defaults button already share.
  --   sliderCommit — the default (commit on release) is what this addon has always done. Neither
  --                slider drives anything the user can see mid-drag: grid size applies to the next
  --                drag, and default opacity applies to the next panel created.
  --   L          — LibKa0s-Options-1.0 reads no descriptor `L` at all, so there is nothing to pass.
  --                tests/test_libka0s.lua carries a tripwire that goes red the day it grows one.
})

--- Let settings/Panel.lua install the landing page's body after this file has loaded.
function NS.SetBuildMain(fn) buildMainBody = fn end
