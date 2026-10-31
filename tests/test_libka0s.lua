local T = _G.PM_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local P = NS.Panel

-- Resolved at CALL time, not captured: P.general is assigned inside the page builder the library
-- runs, so a file-scope capture here would be nil.
local function P_general() return P.general end

-- The LibKa0s adoption's own suite: the seams and the `L` trap. The degraded install's cases are in
-- tests/test_libka0s_degraded.lua.
--
-- The two suites answer three questions that no other suite in this repo can:
--   * is the addon actually running the LIBRARY, or has a seam silently fallen back? Every
--     degradation stub is written to keep working, which is exactly what makes a failed adoption
--     invisible — the addon behaves, the suite passes, and the library is dead weight in libs/.
--   * does the DEGRADED install still work, said once, in the collection's shared wording?
--   * can a descriptor render raw SCREAMING_SNAKE keys in place of English?

local Loader = dofile("tests/_kit/loader.lua")

-- The degraded-environment builder and the vendored library's derived load list, both shared with
-- tests/test_surface_parity.lua. They used to be file-scope locals here, and moved out whole when
-- the parity cases did: a second copy of a load list is a second thing that can be wrong, which is
-- the argument LIB_FILES itself carries in tests/degraded_env.lua.
local Env = dofile("tests/degraded_env.lua")
local LIB_FILES, loadPartial, loadDegraded = Env.LIB_FILES, Env.loadPartial, Env.loadDegraded

local function readFile(path)
  local f = assert(io.open(path, "r"), "missing file " .. path)
  local src = f:read("*a")
  f:close()
  return src
end

-- ── the library is actually loaded ─────────────────────────────────────────────

test("LibKa0s: the vendored library registered for real", function()
  for _, path in ipairs(LIB_FILES) do
    assertTrue(io.open(path, "r") ~= nil, "vendored library file missing: " .. path)
  end
  local core = mocks.LibStub("LibKa0s-Core-1.0", true)
  assertTrue(core ~= nil, "LibKa0s-Core-1.0 did not register")
  assertEqual(core.MAJOR, "LibKa0s-Core-1.0")
  assertTrue(type(core.MINOR) == "number" and core.MINOR >= 1, "Core has no usable MINOR")
  -- The minor the addon is actually running, published for in-game version-skew diagnosis.
  assertEqual(core.MODULES.Core, core.MINOR)
end)

test("LibKa0s: NS.Core is the live Core library, not a stub", function()
  assertEqual(NS.Core, mocks.LibStub("LibKa0s-Core-1.0", true))
end)

-- ── Core: the printer seam ─────────────────────────────────────────────────────
--
-- The load-bearing assertion is IDENTITY, not behavior. The degradation stub reproduces the
-- printer's behavior deliberately (five files take it as a load-time upvalue and must keep working),
-- so a behavioral assertion passes on BOTH paths and proves nothing about which one ran.

test("Core seam: NS.Print is the library's printer, not the fallback", function()
  local core = mocks.LibStub("LibKa0s-Core-1.0", true)
  assertEqual(NS.SafeToString, core.SafeToString, "NS.SafeToString must be Core's own function")
  assertEqual(NS.IsConcatSafe, core.IsConcatSafe, "NS.IsConcatSafe must be Core's own function")
  -- The fallback printer in core/CoreSetup.lua is a DIFFERENT function object from anything the
  -- library hands out, and the degraded environment below proves the two are distinguishable.
  local degraded = loadDegraded()
  assertTrue(degraded.Print ~= NS.Print,
    "the degraded printer and the library printer are the same object — the seam is not switching")
  assertTrue(degraded.SafeToString ~= core.SafeToString,
    "the degraded SafeToString is Core's — the degraded path is not actually degraded")
end)

test("Core seam: NS.Print survived the AceConsole embed and both keys are one object", function()
  -- core/PanelMaster.lua reclaims NS.Print FROM NS.Util.print after NewAddon embeds AceConsole's
  -- own :Print over it. Publishing on both keys is what keeps that reclaim correct.
  assertEqual(NS.Print, NS.Util.print)
  assertEqual(NS.Print, mocks.LibStub("LibKa0s-Core-1.0", true) and NS.Print)
  local before = #mocks.__chat
  NS.Print("hello")
  assertEqual(#mocks.__chat, before + 1)
  assertEqual(mocks.__chat[#mocks.__chat], NS.PREFIX .. " hello",
    "the library printer must render the cyan tag, one space, then the body")
end)

test("Core seam: the rendered line is byte-identical to the printer this replaced", function()
  -- The old core/Util.lua printer built { NS.PREFIX, arg1, arg2 } and concatenated with " ".
  -- Core's builds the body then emits `tag .. sep .. body` with sep defaulting to " ". Those are
  -- the same bytes for every arity, and this pins that rather than trusting it.
  local before = #mocks.__chat
  NS.Print("a", "b", "c")
  assertEqual(mocks.__chat[#mocks.__chat], NS.PREFIX .. " a b c")
  NS.Print(42, true, nil)
  assertEqual(mocks.__chat[#mocks.__chat], NS.PREFIX .. " 42 true nil",
    "nil and booleans must render, never be masked as the secret sentinel")
  assertEqual(#mocks.__chat, before + 2)
end)

test("Core seam: the secret guard survived the swap", function()
  assertTrue(NS.IsConcatSafe("plain"))
  assertTrue(NS.IsConcatSafe(7))
  assertEqual(NS.SafeToString(nil), "nil")
  assertEqual(NS.SafeToString(true), "true")
  assertEqual(NS.SafeToString(42), "42")
  -- The sentinel is the library's exported constant, so this addon's docs, its tests and the
  -- implementation cannot drift apart.
  assertEqual(mocks.LibStub("LibKa0s-Core-1.0", true).SECRET, "<secret>")
end)

-- ── DebugLog: the console seam ─────────────────────────────────────────────────

test("DebugLog seam: the console is the library's instance, not a host re-implementation", function()
  local dl = mocks.LibStub("LibKa0s-DebugLog-1.0", true)
  assertTrue(dl ~= nil, "LibKa0s-DebugLog-1.0 did not register")
  assertEqual(dl.MODULES.DebugLog, dl.MINOR)
  -- Members the OLD modules/DebugLog.lua never had. Their presence is what distinguishes the
  -- library instance from the 429-line file it replaced and from the degradation stub.
  for _, member in ipairs({ "Text", "CopyText", "FindLine", "BufferSize", "ConsoleCheckbox" }) do
    assertTrue(type(NS.DebugLog[member]) == "function",
      "NS.DebugLog has no " .. member .. " — this is not the library instance")
  end
  -- The formatters are the lib-level ones, shared rather than copied.
  assertEqual(NS.DebugLog.FormatPlain, dl.FormatPlain)
  assertEqual(NS.DebugLog.FormatColored, dl.FormatColored)
  assertEqual(NS.DebugLog.buffer, NS.DebugLog.buffer, "the buffer must be the instance's own table")
end)

test("DebugLog seam: the survivors kept their names and their shapes", function()
  -- NS.Debug is bound BARE off the instance: it is a plain function, not a method, because 35 call
  -- sites do `NS.Debug("Tag", "fmt", v)` with no self.
  assertEqual(NS.Debug, mocks.LibStub("LibKa0s-DebugLog-1.0", true) and NS.Debug)
  assertTrue(type(NS.Debug) == "function")
  assertTrue(type(NS.DebugBuild) == "function", "NS.DebugBuild has no library equivalent and must " ..
    "survive the swap")
  -- The diagnostics report is the library's (DebugLog 14.1); what the seam adds is the brand and
  -- the sections, both on the descriptor. The first report line is the branded begin marker.
  assertEqual(NS.DebugLog:BuildDiagnostics().lines[1][2],
    "==== " .. NS.BRAND .. " diagnostics begin ====", "the descriptor does not pass brandName")
end)

test("DebugLog seam: the frame globals are byte-for-byte the ones this addon shipped", function()
  -- Derived by the library from the descriptor's `name`. If they ever stop matching, anything a
  -- user anchored to them — /framestack, a macro, UISpecialFrames — silently breaks.
  NS.DebugLog:Show()
  local frame = NS.DebugLog._frameForTest
  assertTrue(frame ~= nil, "the console frame was never built")
  assertEqual(frame:GetName(), "PanelMasterDebugWindow")
  NS.DebugLog:Hide()
end)

test("DebugLog seam: the console's title bar is three marks, at the icon pitch", function()
  -- `makeCloseButton` is deliberately not passed (the Ka0s window edge and its close control are
  -- the library's — standalone-windows). The title-bar offsets are DERIVED from what was actually
  -- built, so they are the one readable evidence of WHICH controls got built: an anchor cannot be
  -- read back through the frame API and a texture path cannot be read back at all.
  --
  -- 6 / 30 / 54 is the ICON pitch — three 18-wide controls at 6px padding, which is what the
  -- library draws once it has been told the addon FOLDER name and can resolve `clear` and `copy`
  -- out of LibKa0s-Media. The old numbers were 6 / 30 / 78, where Clear was a 42-wide text button
  -- reading the word. So this case is the headless half of smoke check DIAG-2: a -78 here means
  -- `addonName` stopped reaching the descriptor and the console went back to words and a
  -- multiplication sign, silently, because a texture path that resolves to nothing draws nothing
  -- and raises nothing.
  NS.DebugLog:Show()
  local offsets = NS.DebugLog._frameForTest.titleBarOffsets
  assertTrue(offsets ~= nil, "the library records no title-bar offsets")
  assertEqual(offsets.close, -6)
  assertEqual(offsets.clear, -30, "Clear is not at Core's 18-wide close-button offset")
  assertEqual(offsets.copy, -54,
    "Copy is at the text-button pitch — the descriptor is no longer passing addonName")
  NS.DebugLog:Hide()
end)

test("DebugLog seam: the library is told the FOLDER name, not just the frame name", function()
  -- Two fields, two questions, one string in this addon: `name` seeds PanelMasterDebugWindow and
  -- its siblings, `addonName` is what the library builds a texture path from so its own close, copy
  -- and clear draw this collection's art. A host where the two diverge would hand the library a
  -- path into nowhere, so this is passed EXPLICITLY rather than inferred from `name`.
  -- red under: dropping `addonName` and letting the console keep its glyph and its two words.
  local src = readFile("core/DebugLogSetup.lua"):gsub("%-%-[^\r\n]*", "")
  assertTrue(src:match("addonName%s*=%s*addonName") ~= nil,
    "the descriptor does not pass addonName, so the console draws the minor-8 title bar")
end)

test("Options seam: the descriptor is told the FOLDER name, so IdList help art can resolve", function()
  -- LibKa0s#42. OptionsIdList draws a help mark from Media.Icon(d.addonName, "info"), a path into
  -- this addon's own folder; with no `addonName` it falls back to Blizzard's blue information disc.
  -- No list here carries `help` today, so this is latent: it protects the first help line anyone
  -- adds. The value must be the first vararg (the folder), never a display label such as the
  -- brand, which the library's loaded-addon check would reject. Comments are stripped first.
  -- red under: `local _, NS = ...` or a descriptor without `addonName = addonName,`.
  local src = readFile("settings/OptionsSetup.lua"):gsub("%-%-[^\r\n]*", "")
  assertTrue(src:match("^%s*local%s+addonName%s*,%s*NS%s*=%s*%.%.%.") ~= nil,
    "settings/OptionsSetup.lua no longer keeps its first vararg as addonName")
  local desc = src:match("lib:New%((%b{})%)")
  assertTrue(desc ~= nil, "the lib:New({ ... }) descriptor was not found in settings/OptionsSetup.lua")
  assertTrue(desc:match("addonName%s*=%s*addonName%s*,") ~= nil,
    "the Options descriptor does not pass addonName, so IdList help marks draw the client glyph")
end)

test("Options seam: info is declared exactly when a page builds an IdList", function()
  -- The vendored media/icons/ is pruned to the CLAUDE.md `LibKa0s icons:` line (kit revision 40),
  -- and OptionsIdList's help mark is the only thing that would draw `info` here. No page builds an
  -- IdList (the degraded stub's `IdList = noop` is the only mention), so `info` is NOT declared and
  -- its file is not shipped. The first page that builds one must declare it in the same commit, or
  -- its help mark resolves to a path the prune removed and draws blank.
  -- red under: a live `IdList(` call in settings/ with no `info` on the declaration, or `info`
  -- declared while nothing builds a list.
  local VendorSync = dofile("tests/_kit/vendor_sync.lua")
  local decl, why = VendorSync.iconDeclaration(readFile("CLAUDE.md"))
  assertTrue(decl ~= nil, "CLAUDE.md carries no valid `LibKa0s icons:` line: " .. tostring(why))
  local declaresInfo = false
  for _, name in ipairs(decl.names or {}) do
    if name == "info" then declaresInfo = true end
  end
  local builders, scanned = {}, 0
  for path in readFile("PanelMaster.toc"):gmatch("\n(settings\\[%w_]+%.lua)") do
    path = path:gsub("\\", "/")
    scanned = scanned + 1
    local src = readFile(path):gsub("%-%-[^\r\n]*", "")
    if src:find("IdList%s*%(") then builders[#builders + 1] = path end
  end
  assertTrue(scanned >= 7, "read only " .. scanned .. " settings/ files off the TOC")
  assertEqual(table.concat(builders, ", "), "")
  assertFalse(declaresInfo, "`info` is declared, but no page in settings/ builds an IdList")
end)

test("Core seam: MakeCloseButton is wrapped to say which addon folder is asking", function()
  -- The one Core member this addon WRAPS rather than republishes, and the wrapper exists for its
  -- third argument alone. `lib.MakeCloseButton(parent, onClick, addonName)` — a two-argument
  -- passthrough is the forwarder anti-pattern, and it is invisible in game: the library falls back
  -- to a multiplication sign and nothing raises.
  -- red under: NS.MakeCloseButton = lib.MakeCloseButton.
  local seen
  local lib = mocks.LibStub("LibKa0s-Core-1.0", true)
  local real = lib.MakeCloseButton
  lib.MakeCloseButton = function(_, _, name) seen = name; return nil end
  NS.MakeCloseButton(mocks.CreateFrame("Frame"), function() end)
  lib.MakeCloseButton = real

  assertEqual(seen, "PanelMaster",
    "the library was not told which addon folder to build the close mark's path from")
end)

test("L trap (DebugLog): every rendered console string resolves to prose, not to its own key",
  function()
    -- DebugLog is one of the three majors that CAN express the trap, so this is a real rendered
    -- assertion rather than a tripwire. A resolved string is prose; an unresolved one is the key,
    -- and no English label is SCREAMING_SNAKE_CASE.
    local SCREAMING = "^[A-Z][A-Z0-9_]+$"

    -- Reached through real accessors, and each is coupled to a non-vacuous expectation so the case
    -- cannot pass by the accessor simply not existing.
    NS.DebugLog:Show()
    local title = NS.DebugLog._frameForTest.titleText
    assertTrue(type(title) == "string" and title ~= "", "the console has no composed title")
    assertFalse(title:match(SCREAMING) ~= nil, "the console title rendered a raw key: " .. title)
    assertEqual(title, "Panel Master \226\128\148 Debug",
      "the composed title must be this addon's title plus the library's own suffix")
    NS.DebugLog:Hide()

    local cb = NS.DebugLog:ConsoleCheckbox()
    assertTrue(type(cb.label) == "string" and cb.label ~= "", "the checkbox has no label")
    assertFalse(cb.label:match(SCREAMING) ~= nil, "the checkbox label rendered a raw key: " .. cb.label)
    assertTrue(type(cb.tooltip) == "string" and cb.tooltip ~= "", "the checkbox has no tooltip")
    assertFalse(cb.tooltip:match(SCREAMING) ~= nil, "the checkbox tooltip rendered a raw key")
    -- The tooltip is composed from the descriptor's `slash`, so a resolved one names the command.
    assertTrue(cb.tooltip:find("/pm debug", 1, true) ~= nil,
      "the checkbox tooltip did not resolve the slash reference")

    for _, key in ipairs({ "DEBUG_ON", "DEBUG_OFF", "CLEAR", "COPY", "COPY_TITLE", "LINES",
                           "CHECKBOX_LABEL", "TITLE_SUFFIX", "LOG_ENABLED", "LOG_DISABLED" }) do
      local rendered = NS.DebugLog:Text(key)
      assertTrue(type(rendered) == "string" and rendered ~= "", key .. " resolved to nothing")
      assertFalse(rendered:match(SCREAMING) ~= nil,
        key .. " rendered as its own key: " .. rendered)
    end
  end)

-- ── Slash: the dispatcher, the help renderer and the schema CLI ────────────────

local function capture(fn)
  local before = #mocks.__chat
  fn()
  local out = {}
  for i = before + 1, #mocks.__chat do out[#out + 1] = mocks.__chat[i] end
  return out
end

test("Slash seam: the dispatcher is the library's, not a host re-implementation", function()
  local sl = mocks.LibStub("LibKa0s-Slash-1.0", true)
  assertTrue(sl ~= nil, "LibKa0s-Slash-1.0 did not register")
  assertEqual(sl.MODULES.Slash, sl.MINOR)
  -- Surfaces the old settings/Slash.lua never had. LandingRows in particular is the convergence:
  -- this addon carried two divergent formatters for NS.COMMANDS and now has one.
  for _, member in ipairs({ "LandingRows", "HelpRows", "Text" }) do
    assertTrue(type(NS.Slash[member]) == "function",
      "NS.Slash has no " .. member .. " — this is not the library dispatcher")
  end
  -- And the ones it DID have are gone rather than shadowing the library's.
  assertEqual(NS.Slash.FormatSchemaValue, nil,
    "the host's own value formatter survived — two formatters will drift")
  assertEqual(NS.Slash.LIST_GROUP_ORDER, nil,
    "the hand-maintained group-order constant survived; the library groups in declaration order")
  assertEqual(NS.Slash.FormatKV, sl.FormatKV, "FormatKV must be the library's one implementation")
end)

test("Convergence #2: the landing page and the chat help render the SAME rows", function()
  -- ADOPTED. settings/Panel.lua's landing page used to carry its own formatter for NS.COMMANDS —
  -- double spaces around the em dash, the dash white-wrapped, the description bare — beside the
  -- chat one in settings/Slash.lua. Both now come from lib.FormatRow.
  local landing = NS.Slash:LandingRows()
  local help    = NS.Slash:HelpRows()
  assertEqual(#landing, #NS.COMMANDS, "the landing page dropped or gained a row")
  assertEqual(#help, #NS.COMMANDS)
  for i = 1, #landing do
    -- Same bytes, except the chat form's two-space indent: a chat row sits under a header, a
    -- settings-panel label does not.
    assertEqual(help[i], "  " .. landing[i], "row " .. i .. " differs beyond the indent")
  end
  -- The rendered shape, pinned to bytes, because this is the user-visible half of the convergence.
  assertEqual(landing[1], "|cFFFFFF00/pm config|r \226\128\148 |cFFFFFFFFOpen settings|r",
    "the command row is no longer lib.FormatRow's shape: " .. landing[1])
  assertTrue(landing[1]:find("  ", 1, true) == nil,
    "the landing row still carries the old double spacing")
end)

test("Convergence #2: settings/Panel.lua no longer carries a second row formatter", function()
  -- A grep would answer about the NAME; this reads the render path. The landing page must reach
  -- NS.COMMANDS only through the library, so the file must not format a command row itself.
  local src = readFile("settings/Panel.lua")
  assertTrue(src:find("NS.Slash:LandingRows()", 1, true) ~= nil,
    "the landing page does not render through Sl:LandingRows()")
  assertEqual(src:find("/pm %%s|r"), nil,
    "settings/Panel.lua still formats a command row of its own")
end)

test("Convergence #1: /pm reset takes a PATH and /pm resetall is the global form", function()
  -- ADOPTED, and it was already converged before the adoption — which is not the same as "not
  -- applicable". Both verbs now delegate to the library.
  local verbs = {}
  for _, cmd in ipairs(NS.COMMANDS) do verbs[cmd[1]] = cmd[2] end
  assertTrue(verbs.reset ~= nil and verbs.resetall ~= nil, "a reset verb went missing")
  NS.Slash:CliSet("settings.gridSize 16")
  NS.Slash:CliReset("settings.gridSize")
  assertEqual(NS.Schema:Get("settings.gridSize"), 4, "path-scoped reset did not restore the default")
  -- There is deliberately no page-shaped form: a page is a property of a settings panel, not of the
  -- data, and the panel's own Defaults button is where page-scoped reset lives.
  local lines = capture(function() NS.Slash:CliReset("Moving panels") end)
  assertTrue(lines[1]:find("Setting not found", 1, true) ~= nil,
    "`/pm reset <page>` resolved something — the page-shaped form is supposed to be gone")
end)

test("L trap (Slash): the ONE overridden string lands, and nothing renders as its own key",
  function()
    local SCREAMING = "^[A-Z][A-Z0-9_]+$"
    -- This addon passes a PLAIN table holding exactly one key. The override must actually win —
    -- a descriptor L that silently did nothing is the other half of the trap.
    --
    -- Read through Text() rather than by driving CliResetAll: since options-ui-§12 the global reset
    -- is a PROFILE reset that this addon owns (Sl:DoResetAll) rather than the library's row walk,
    -- so the library no longer prints this line — but it still RESOLVES the key, and this addon
    -- still hands it the string, which is what the trap is about.
    assertEqual(NS.Slash:Text("RESET_ALL"), NS.Slash.RESET_ALL_TEXT,
      "the RESET_ALL override did not reach the library's string table")
    assertEqual(NS.Slash.RESET_ALL_TEXT, "this profile reset to defaults")

    -- And the addon's own reset prints that same string, so the two cannot drift. Driven through
    -- the popup's OnAccept, because CliResetAll only ASKS now -- the act is behind the confirm.
    local lines = capture(function()
      T.mocks.StaticPopupDialogs["KA0S_PANELMASTER_RESETALL"].OnAccept()
    end)
    assertEqual(lines[#lines], NS.PREFIX .. " " .. NS.Slash.RESET_ALL_TEXT,
      "the reset printed something other than the string it publishes")
    -- And the library's own strings still resolve for every key this addon does NOT override.
    for _, key in ipairs({ "HELP_HEADER", "LIST_HEADER", "LIST_EMPTY", "NOT_FOUND", "INVALID",
                           "ERR_BOOL", "ERR_NUMBER", "ERR_COLOR", "NONE", "USAGE_GET" }) do
      local rendered = NS.Slash:Text(key)
      assertTrue(type(rendered) == "string" and rendered ~= "", key .. " resolved to nothing")
      assertFalse(rendered:match(SCREAMING) ~= nil, key .. " rendered as its own key: " .. rendered)
    end
    -- Reached through the real render path too, not only through Text().
    for _, line in ipairs(NS.Slash:BuildListLines()) do
      assertFalse(line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match(SCREAMING) ~= nil,
        "a /pm list line rendered as a raw key: " .. line)
    end
  end)

-- ── Options: the settings canvas ───────────────────────────────────────────────

--- Fire a page's first OnShow, which is where LibKa0s-Options-1.0 builds the body.
---
--- The whole point of the deferral is that AceGUI lays children out against the panel's CURRENT
--- width, which is zero at enable time — so nothing is drawn until this fires. Before the shared
--- test kit arrived this addon's AceGUI mock returned nil from Create(), so this entire path was
--- unreachable and untested.
local function showPage(ctx)
  local onShow = ctx.panel:GetScript("OnShow")
  assertTrue(onShow ~= nil, "the page has no OnShow — SetRenderer never ran")
  onShow(ctx.panel)
end

-- The widgets ONE page's render produced, by type.
--
-- The mock's `__created` is a single cumulative list for the whole run, so a bare type count over it
-- answers "every widget any page has ever built" rather than "every widget THIS page built". That
-- read the same for as long as the Panels page never actually built itself in the harness — its
-- rebuilders only ran through settings/PanelEditor.lua's own hand-rolled refresh, which never
-- reached BuildPage because BuildPage runs from the library's renderer and nothing here fires that
-- page's OnShow. The moment the editor started routing structural refreshes through
-- O.RefreshPanel — which is the profile-switch fix — the Panels page began building its own
-- dropdown and checkboxes into the same list, and the counts below silently became wrong.
--
-- So the window is captured around the render rather than inferred afterwards.
--
-- ONE TAB AT A TIME, since the General page became a tab strip (options-ui-§13): a render draws the
-- ACTIVE group's rows and nothing else, so a single capture answers for one third of the schema.
-- Each tab is selected and the page re-rendered through the same door a tab click uses -- mark the
-- ctx dirty, fire OnShow -- and the captures are concatenated. A test that wants one tab's widgets
-- calls tabWidgets; a test that wants the page's whole vocabulary calls generalWidgets.
-- The tabs whose rows the flow engine draws. A group whose rows are ALL skipRender is drawn by a
-- host tab instead -- the Skin tab, O.AppearanceTab, keyed by the "Appearance" group -- in widgets
-- of the library's own choosing, so a one-widget-per-row count does not describe it;
-- tests/test_skinsetup.lua covers that tab.
local function generalTabs()
  local names, seen, drawn = {}, {}, {}
  for _, row in ipairs(NS.Schema.ProfileRows()) do
    if row.group and not row.skipRender then drawn[row.group] = true end
  end
  for _, row in ipairs(NS.Schema.ProfileRows()) do   -- the General page's rows (allRows)
    if row.group and drawn[row.group] and not seen[row.group] then
      seen[row.group] = true
      names[#names + 1] = row.group
    end
  end
  return names
end

-- The tab a given path is edited on. Used by the cases that reach for one named row's widget.
local function tabOf(path)
  local row = NS.Schema:FindRow(path)
  return row and row.group
end

local function tabWidgets(tab)
  local ctx = P_general()
  local created = mocks.LibStub("AceGUI-3.0", true).__created
  local from = #created + 1
  ctx.activeTab = tab
  -- The dirty flag is what SetRenderer's OnShow gate reads; without it the second show returns
  -- early and the capture below is empty, which is exactly the trap the old memo existed to avoid.
  ctx._dirty = true
  showPage(ctx)
  local out = {}
  for i = from, #created do out[#out + 1] = created[i] end
  return out
end

local generalCapture
local function generalWidgets()
  if generalCapture then return generalCapture end
  generalCapture = {}
  for _, tab in ipairs(generalTabs()) do
    for _, w in ipairs(tabWidgets(tab)) do generalCapture[#generalCapture + 1] = w end
  end
  return generalCapture
end

local function widgetsOfType(_ctx, wtype)
  local out = {}
  for _, w in ipairs(generalWidgets()) do
    if w.type == wtype then out[#out + 1] = w end
  end
  return out
end

test("Options seam: NS.Helpers IS the library instance, not a wrapper around one", function()
  local o = mocks.LibStub("LibKa0s-Options-1.0", true)
  assertTrue(o ~= nil, "LibKa0s-Options-1.0 did not register")
  assertEqual(o.MODULES.Options, o.MINOR)
  -- Three files, one major: the shell, the widget makers and the scrollbar patch each carry their
  -- own minor and each must have attached.
  assertTrue(o.MODULES.OptionsWidgets ~= nil, "OptionsWidgets.lua did not attach")
  assertTrue(o.MODULES.OptionsScroll ~= nil, "OptionsScroll.lua did not attach")
  assertFalse(NS.Helpers.__degraded == true, "the Options seam fell back to its degradation stub")
  for _, member in ipairs({ "CreatePanel", "EnsureScroll", "RenderRows", "RenderField", "Section",
                            "AttachTooltip", "SetRenderer", "RefreshScalars",
                            "PatchAlwaysShowScrollbar", "RegisterOptionsPage" }) do
    assertTrue(type(NS.Helpers[member]) == "function", "NS.Helpers has no " .. member)
  end
  -- The layout constants are the library's one copy, not a second set of numbers here.
  assertEqual(NS.Helpers.ROW_VSPACER, 8)
  assertEqual(NS.Helpers.SECTION_HEADING_H, 26)
  assertEqual(NS.Helpers.BUTTON_PAIR_REL, 0.492)
end)

test("Options seam: all four pages built, and each is registered with Blizzard", function()
  local built = {}
  for _, page in ipairs(NS.Helpers.__pages()) do built[page.key] = true end
  for _, key in ipairs({ "general", "panels", "profiles" }) do
    assertTrue(built[key], "the '" .. key .. "' page never built")
  end
  -- The library pcalls each builder SEPARATELY, so a raising one costs only itself — previously one
  -- bad builder killed every page after it with nothing naming the culprit.
  for _, name in ipairs({ "Ka0s Panel Master", "General", "Panels", "Profiles" }) do
    assertTrue(mocks.__settingsPanels[name] ~= nil, "no canvas registered as " .. name)
  end
end)

test("Options: the General page renders one widget per schema row, by type", function()
  -- The schema -> widget translation, driven for real. This is the path the old AceGUI mock made
  -- unreachable: Create() answered nil, so every maker returned early and nothing was ever built.
  assertTrue(#generalWidgets() > 0, "the page built no widgets")

  -- PER TAB, not per page, since the strip arrived. The page-wide totals below still have to add
  -- up, but they add up for the wrong reason if a row lands on the wrong tab -- a row that drifted
  -- from Moving panels to New panels moves no total at all. So each tab is asserted against the rows
  -- ITS OWN group declares, which is the assertion that actually pins the partition.
  --
  -- `bool` -> CheckBox, a `number` with min/max -> Slider, a `string` with `values` -> Dropdown.
  -- If the schema vocabulary ever drifts back to "boolean", RenderField returns nil for the type it
  -- does not know and the row VANISHES from the page — silently, and only in game.
  local WIDGET = { bool = "CheckBox", number = "Slider", string = "Dropdown" }
  local totals = { CheckBox = 0, Slider = 0, Dropdown = 0 }

  for _, tab in ipairs(generalTabs()) do
    local wanted = { CheckBox = 0, Slider = 0, Dropdown = 0 }
    for _, row in ipairs(NS.Schema.ProfileRows()) do
      if row.group == tab then
        local widget = WIDGET[row.type]
        assertTrue(widget ~= nil, row.path .. " has a type no widget maker knows: " .. row.type)
        wanted[widget] = wanted[widget] + 1
      end
    end

    local built = { CheckBox = 0, Slider = 0, Dropdown = 0 }
    for _, w in ipairs(tabWidgets(tab)) do
      if built[w.type] then built[w.type] = built[w.type] + 1 end
    end

    for widget, n in pairs(wanted) do
      assertEqual(built[widget], n,
        ("the '%s' tab built %d %s widgets for %d rows of that group")
          :format(tab, built[widget], widget, n))
      totals[widget] = totals[widget] + n
    end
  end

  -- And the page as a whole still accounts for every row, so a group nobody drew is caught too.
  assertEqual(#widgetsOfType(P_general(), "CheckBox"), totals.CheckBox,
    "a bool row did not render as a checkbox — check settings/Schema.lua's `type`")
  assertEqual(#widgetsOfType(P_general(), "Slider"), totals.Slider)
  assertEqual(#widgetsOfType(P_general(), "Dropdown"), totals.Dropdown)
end)

test("Options: Recover panels is drawn on the Master controls tab, and only there", function()
  -- "Recover panels" is the composer's `leadButton` (item 020, PAN-L03), drawn by the Master
  -- controls tab's afterGroup hook above the reset pair. `afterGroup` fires after the group's LAST
  -- row, so on a tabbed page it lands under the tab it is keyed to and nowhere else -- which is the
  -- property worth pinning, because a hook keyed to a group that no longer exists simply never
  -- fires and nothing says so.
  local function hasRecover(tab)
    for _, w in ipairs(tabWidgets(tab)) do
      if w.type == "Button" and w.text == "Recover panels" then return true end
    end
    return false
  end

  assertTrue(hasRecover(tabOf("settings.enabled")),
    "the Master controls tab drew no Recover panels button — check its leadButton in settings/Schema.lua")
  assertFalse(hasRecover(tabOf("settings.gridSize")),
    "Recover panels is still drawn on the Moving panels tab")
end)

test("Options: a widget's OnValueChanged reaches the addon's single write seam", function()
  local ctx = P_general()
  -- Find the checkbox the library built for a known row, by the label it was given.
  local row = NS.Schema:FindRow("settings.showLabels")
  local target
  for _, w in ipairs(widgetsOfType(ctx, "CheckBox")) do
    if w.labelText == row.label then target = w end
  end
  assertTrue(target ~= nil, "no checkbox carries the row's label")

  local before = NS.Schema:Get("settings.showLabels")
  -- Fired the way AceGUI fires it: fn(widget, eventName, value).
  target:__fire("OnValueChanged", not before)
  assertEqual(NS.Schema:Get("settings.showLabels"), not before,
    "the widget's write never reached NS.Schema:Set")
  target:__fire("OnValueChanged", before)
  assertEqual(NS.Schema:Get("settings.showLabels"), before)
end)

test("Options: a slider commits on release and snaps to the row's step", function()
  local row = NS.Schema:FindRow("settings.gridSize")
  local target
  for _, w in ipairs(widgetsOfType(P_general(), "Slider")) do
    if w.labelText == row.label then target = w end
  end
  assertTrue(target ~= nil, "no slider carries the grid-size label")
  assertEqual(target.min, row.min)
  assertEqual(target.max, row.max)
  target:__fire("OnMouseUp", 12)
  assertEqual(NS.Schema:Get("settings.gridSize"), 12)
  NS.Slash:CliReset("settings.gridSize")
end)

test("Options: the enum row's dropdown is populated from the schema's `values`", function()
  local row = NS.Schema:FindRow("settings.defaultStrata")
  -- Found BY LABEL, never by position. The page has two dropdowns now -- General visibility on the
  -- Master controls tab and this one on New panels -- and `[1]` silently became the wrong widget
  -- the moment the first of them arrived, with the case still passing shape checks against it.
  local dd
  for _, w in ipairs(widgetsOfType(P_general(), "Dropdown")) do
    if w.labelText == row.label then dd = w end
  end
  assertTrue(dd ~= nil, "the enum row rendered no dropdown")
  assertEqual(#dd.order, #row.values, "the dropdown lost an option")
  -- Ordered-array position IS the order, which is why the strata list reads BACKGROUND..TOOLTIP
  -- rather than alphabetically.
  assertEqual(dd.order[1], row.values[1].value)
  assertEqual(dd.list[row.values[1].value], row.values[1].text)
end)

test("Options ADAPTER: a library-built dropdown lands in this addon's open-dropdown registry",
  function()
    -- The library's makers know nothing about the registry, and should not: it is this addon's own
    -- invention, born of a real bug, and no other host has one. settings/Panel.lua wraps
    -- O.RenderField on the instance to catch every dropdown the library builds. Without the wrap
    -- the strata dropdown stays open and floating when the page is scrolled.
    -- Rendered with the dropdown's OWN tab selected, and named through the schema rather than
    -- written down here: the registry is emptied at the top of every render, so a page showing a
    -- tab with no dropdown on it holds none -- which is correct behavior and would read as this
    -- adapter being gone.
    local ctx = P_general()
    ctx.activeTab = tabOf("settings.defaultStrata")
    ctx._dirty = true
    showPage(ctx)
    assertTrue(P.__openDropdownCount(ctx) > 0,
      "no dropdown was tracked — the RenderField wrapper in settings/Panel.lua is not reached")
    local tracked = false
    for _, w in ipairs(ctx.dropdowns) do if w.type == "Dropdown" then tracked = true end end
    assertTrue(tracked, "the registry holds no stock Dropdown")
  end)

test("Options ADAPTER: the scroll frame keeps this addon's dropdown-close hooks", function()
  local ctx = P_general()
  showPage(ctx)
  assertTrue(ctx.scroll ~= nil, "the page built no scroll frame")
  assertTrue(ctx.scroll.__pmDropdownHooks == true,
    "settings/Panel.lua's dropdown-close layer is not installed over the library's patch")
  -- Layered OVER the library's MoveScroll, never replacing it: the always-shown-scrollbar patch
  -- still owns the gating, and only the extra gesture is this addon's.
  assertTrue(ctx.scroll._ka0sAlwaysScrollbar == true,
    "the library's always-shown scrollbar patch was lost")
end)

test("L trap (Options tripwire): Options reads no descriptor L", function()
  -- Options is the OTHER major that cannot express the trap, and its tripwire is deliberately NOT
  -- Core's copied across: Options.lua ships its own lib.STRINGS table, so asserting
  -- `rawget(lib, "STRINGS") == nil` would fail against a module behaving exactly as designed. The
  -- source half alone is the tripwire, and it goes red the day Options grows an `L` — which is the
  -- day the settings panel becomes the most visible place a raw SCREAMING_SNAKE key can appear.
  local o = mocks.LibStub("LibKa0s-Options-1.0", true)
  assertTrue(rawget(o, "STRINGS") ~= nil, "Options lost its STRINGS table")
  assertTrue(rawget(o, "LAYOUT") ~= nil,
    "Options lost lib.LAYOUT — `local L = lib.LAYOUT` inside that file is GEOMETRY, not a locale, " ..
    "and a source sweep for `d.L` must not be confused by it")
  -- Derived from the library's own load list, so a peel that moves code into a new Options*.lua
  -- stays swept: lib.__AttachFlow in OptionsFlow.lua receives the descriptor too.
  local swept = {}
  for _, path in ipairs(Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml")) do
    if path:match("/Options[^/]*%.lua$") then
      swept[path] = true
      local src = readFile(path)
      assertTrue(src:find("d.L", 1, true) == nil and src:find("d%.L") == nil,
        path .. " reads a descriptor L — replace this tripwire with a real rendered assertion")
    end
  end
  assertTrue(swept["libs/LibKa0s/Options.lua"] and swept["libs/LibKa0s/OptionsFlow.lua"],
    "the Options* filter no longer reaches Options.lua and OptionsFlow.lua, so it swept too little")
end)

-- ── the LSM30_Border fixup, promoted out of core/LSMPatch.lua ──────────────────

test("Options seam: the live wiring patches LSM30_Border through the library, not a private copy",
  function()
    -- AceGUI's WidgetRegistry is PROCESS-GLOBAL: one slot named "LSM30_Border" that every addon in
    -- the client shares, Ka0s or not. This addon and four siblings each carried the same wrapper in
    -- their own core/LSMPatch.lua, each registering at whatever version it found plus one, so a
    -- session running all five stacked five wrappers and the outermost belonged to whichever addon
    -- the loader happened to reach last. Not one of the five suites could see that -- each loads a
    -- single copy, registers once and passes -- and this file passed through the whole defect.
    --
    -- lib.__PatchLSM30Border (LibKa0s-Options-1.0 minor 15) is that wrapper published once, behind
    -- lib.__lsmBorderPatched. LibStub hands five vendored copies of the library the same instance,
    -- so five callers make one registration.
    --
    -- WHY A FRESH ENVIRONMENT WITH A SEEDED REGISTRY. The mock's WidgetRegistry starts empty, which
    -- models AceGUI-3.0-SharedMediaWidgets being absent: the call then finds nothing to wrap,
    -- returns false WITHOUT arming the sentinel, and proves nothing at all. The mutate hook is the
    -- one window in which a stand-in constructor can be sitting in the slot at the moment
    -- settings/OptionsSetup.lua's live arm runs.
    -- red under: dropping the lib.__PatchLSM30Border() call from the live wiring.
    local upstream = function() return { frame = {} } end
    local _, m = loadPartial({}, function(mm)
      mm.LibStub("AceGUI-3.0"):RegisterWidgetType("LSM30_Border", upstream, 20)
    end)

    local AceGUI = m.LibStub("AceGUI-3.0")
    assertTrue(AceGUI.WidgetRegistry["LSM30_Border"] ~= upstream,
      "the live wiring never called lib.__PatchLSM30Border(): the slot still holds the " ..
      "constructor the registry was seeded with")
    assertEqual(AceGUI:GetWidgetVersion("LSM30_Border"), 21,
      "the wrapper must register one version above what it wrapped, to win the race")

    -- The sentinel is armed, so a sibling addon's copy of the library -- the same instance, as far
    -- as LibStub is concerned -- registers nothing on top of it.
    local lib = m.LibStub("LibKa0s-Options-1.0")
    assertFalse(lib.__PatchLSM30Border(), "a second call must be a no-op")
    assertEqual(AceGUI:GetWidgetVersion("LSM30_Border"), 21,
      "and must leave the one registration alone")
  end)

-- ── the `L` trap ───────────────────────────────────────────────────────────────
--
-- Three of the five majors take a descriptor `L` and can render raw keys if handed a table whose
-- __index synthesizes one. Core CANNOT express the trap at all — it ships no STRINGS and reads no
-- descriptor L — so a "rendered label is prose" case there would be a case that cannot fail, which
-- is worse than no case because it reads as coverage. The stand-in is a TRIPWIRE on the library
-- itself: it passes today and goes red the day Core grows a user-visible string, which is the day
-- this repo needs a real rendered assertion instead.

test("L trap (Core tripwire): Core cannot express the trap", function()
  local core = mocks.LibStub("LibKa0s-Core-1.0", true)
  assertTrue(rawget(core, "STRINGS") == nil,
    "Core has grown a STRINGS table — replace this tripwire with a real rendered-string assertion")
  local src = readFile("libs/LibKa0s/Core.lua")
  assertTrue(src:find("STRINGS", 1, true) == nil,
    "Core.lua names STRINGS — it can now render a user-visible string and needs a real assertion")
  assertTrue(src:find("d.L", 1, true) == nil and src:find("d%.L") == nil,
    "Core.lua reads a descriptor L — the trap is now expressible there")
end)

-- The host-side guard. A descriptor field is not observable after `lib:New` returns, so the only
-- way to see one is to read the source that wrote it.
--
-- The matcher deliberately decides on what the expression EVALUATES TO rather than on one spelling:
--
--   L = NS.L                     the table itself                       OFFENDER
--   L = NS.L or { ... }          NS.L is always truthy, so: the table   OFFENDER
--   L = NS.L and { ... } or nil  evaluates to the plain table           fine
--
-- An end-of-line-anchored `L = NS.L` misses the `or` spelling completely, and never looks at the
-- third line at all — which is the legitimate form, one `and`→`or` typo away from being the trap.
local function findsLocaleTableDescriptor(src)
  for line in src:gmatch("[^\r\n]+") do
    -- Skip comments outright: this file's own explanatory prose above would otherwise match.
    if not line:match("^%s*%-%-") then
      local tail = line:match("[,{%s]L%s*=%s*(.*)$") or line:match("^L%s*=%s*(.*)$")
      if tail then
        local rest = tail:match("^NS%.L%s*(.*)$")
        -- Only `and` rescues it. Bare, or `or`-defaulted, both evaluate to the locale table.
        if rest and not rest:match("^and%f[%W]") then return true end
      end
    end
  end
  return false
end

test("L trap (matcher): the guard catches every offending spelling, not one", function()
  -- Its own case, driven against all three spellings. A matcher nothing tests can be narrowed back
  -- to a single anchored form while still reporting green — which is exactly how it got there.
  assertTrue(findsLocaleTableDescriptor("  L = NS.L,"), "bare assignment not caught")
  assertTrue(findsLocaleTableDescriptor("  L = NS.L\n"), "bare assignment at end of line not caught")
  assertTrue(findsLocaleTableDescriptor('  L = NS.L or { A = "a" },'), "the `or` spelling not caught")
  assertTrue(findsLocaleTableDescriptor('descriptor = { L = NS.L }'), "an inline table not caught")
  assertFalse(findsLocaleTableDescriptor('  L = NS.L and { A = "a" } or nil,'),
    "the legitimate `and`/`or` form must pass")
  assertFalse(findsLocaleTableDescriptor('  L = { A = NS.L["a"] },'),
    "a plain table whose VALUES come from the locale table must pass")
  assertFalse(findsLocaleTableDescriptor('  -- L = NS.L would be the trap'),
    "a comment must not trip the guard")
end)

-- ── the Bus catalog ────────────────────────────────────────────────────────────
--
-- The three message constants are declared through LibKa0s-Bus-1.0's Catalog (core/BusSetup.lua),
-- which hands back a STRICT copy: a mistyped key raises at the read instead of answering nil, which
-- a publisher's SendMessage(nil) would swallow silently (kit 26, LK-02).

test("Bus seam: a mistyped Registry message key raises at the read", function()
  local MSG = NS.Registry.MSG
  assertTrue(MSG ~= nil, "NS.Registry.MSG is not published")
  T.assertErrorMatches(function() return MSG.PANELZ end, "no bus message named PANELZ")
  assertEqual(MSG.PANELS, "Ka0s_PanelMaster_PanelsChanged")
  assertEqual(MSG.PANEL, "Ka0s_PanelMaster_PanelChanged")
end)

test("Bus seam: a mistyped Schema message key raises at the read", function()
  local MSG = NS.Schema.MSG
  assertTrue(MSG ~= nil, "NS.Schema.MSG is not published")
  T.assertErrorMatches(function() return MSG.SETTINGZ end, "no bus message named SETTINGZ")
  assertEqual(MSG.SETTINGS, "Ka0s_PanelMaster_SettingsChanged")
end)

test("Bus seam: with no library the same reads answer nil and do not raise", function()
  -- The degraded catalog is the host's plain table: a library-less install keeps the wire names
  -- and loses only the strictness.
  local degradedNS = loadPartial({ Bus = true })
  local ok, a, b = pcall(function()
    return degradedNS.Registry.MSG.PANELZ, degradedNS.Schema.MSG.SETTINGZ
  end)
  assertTrue(ok, "a degraded catalog read raised: " .. tostring(a))
  assertEqual(a, nil)
  assertEqual(b, nil)
  assertEqual(degradedNS.Registry.MSG.PANELS, "Ka0s_PanelMaster_PanelsChanged")
end)

-- Every file that builds a LibKa0s descriptor. A seam added without being listed here is a seam
-- with no guard, so the list is asserted against the filesystem rather than trusted.
local SEAM_FILES = {
  "core/CoreSetup.lua",
  "core/EnvSetup.lua",
  "core/MediaSetup.lua",
  -- LibKa0s-Bus-1.0: resolves the major for Catalog alone and builds no descriptor, so it has no
  -- `L` to get wrong. Listed because it resolves a LibKa0s major, which is the list's criterion.
  "core/BusSetup.lua",
  "core/DebugLogSetup.lua",
  "core/LauncherSetup.lua",
  "core/LifecycleSetup.lua",
  -- LibKa0s-Skin-1.0: RegisterOwner takes an opts table, never an `L` (the reload line it prints is
  -- read from NS.L by key, which is the locale table's proper use). Listed because it resolves a
  -- LibKa0s major, which is the list's criterion.
  "core/SkinSetup.lua",
  "settings/Slash.lua",
  "settings/OptionsSetup.lua",
  -- The schema runtime's seam (LibKa0s-Schema-1.0). Its descriptor DOES take an `L` -- a plain
  -- table of the two refusal texts this addon keeps -- which is exactly the field the guard above
  -- exists to check.
  "settings/Schema.lua",
}

test("L trap: no seam file hands a descriptor this addon's locale table", function()
  for _, path in ipairs(SEAM_FILES) do
    assertFalse(findsLocaleTableDescriptor(readFile(path)),
      path .. " passes NS.L as a descriptor L — every key would render as its own name")
  end
end)

test("L trap: the seam-file list covers every file that calls lib:New", function()
  -- The guard above is only worth what its list covers. Derive the real set from the TOC and
  -- compare, so a new seam cannot be added without either being guarded or failing here.
  local listed = {}
  for _, p in ipairs(SEAM_FILES) do listed[p] = true end
  local missing = {}
  for _, path in ipairs(Loader.tocFiles("PanelMaster.toc")) do
    local src = readFile(path)
    if src:find('LibStub("LibKa0s-', 1, true) and not listed[path] then
      missing[#missing + 1] = path
    end
  end
  assertEqual(#missing, 0,
    "these files resolve a LibKa0s major but are not in SEAM_FILES: " .. table.concat(missing, ", "))
end)
