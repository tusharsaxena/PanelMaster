local T = _G.PM_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local P = NS.Panel

-- Resolved at CALL time, not captured: P.general is assigned inside the page builder the library
-- runs, so a file-scope capture here would be nil.
local function P_general() return P.general end

-- The LibKa0s adoption's own suite: the seams, the degradation, and the `L` trap.
--
-- Everything here answers one of three questions that no other suite in this repo can:
--   * is the addon actually running the LIBRARY, or has a seam silently fallen back? Every
--     degradation stub is written to keep working, which is exactly what makes a failed adoption
--     invisible — the addon behaves, the suite passes, and the library is dead weight in libs/.
--   * does the DEGRADED install still work, said once, in the collection's shared wording?
--   * can a descriptor render raw SCREAMING_SNAKE keys in place of English?

local Loader = dofile("tests/_kit/loader.lua")
local buildMocks = dofile("tests/wow_mock.lua")

-- Derived from LibKa0s.xml, exactly as tests/run.lua derives it. This was the SECOND hand-typed
-- copy of the vendored library's load list, and it was short by the same two files — so the case
-- below asserted that "the vendored library" was present while never looking at Perf.lua or
-- PerfPanel.lua. Loader.xmlFiles raises on an XML path it cannot open, so a typo here cannot
-- degrade into an empty list that reads as a clean run.
local LIB_FILES = Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml")

local function readFile(path)
  local f = assert(io.open(path, "r"), "missing file " .. path)
  local src = f:read("*a")
  f:close()
  return src
end

--- Load the WHOLE addon into a fresh environment from a PARTIAL library file list.
---
--- `omit` names LibKa0s basenames to leave out (`{ Slash = true }`). Everything else in
--- LibKa0s.xml still loads, so `LibStub("LibKa0s-Slash-1.0", true)` answers nil for exactly the
--- one major under test while the rest of the addon runs on the real library — which is what an
--- install with a truncated libs/ folder looks like, and what a per-seam parity assertion needs.
---
--- The degraded arm is built THIS WAY on purpose. Hand-stubbing `lib = nil` inside a seam tests a
--- branch rather than an install, and never catches a seam that raises at load before it reaches
--- its own guard; hand-stubbing the member under test asserts the test's own typing.
local function loadPartial(omit)
  local m = buildMocks()
  local ns = {}
  Loader.addonName = "PanelMaster"
  local libs = {}
  for _, path in ipairs(LIB_FILES) do
    if not omit[path:match("([^/]+)%.lua$")] then libs[#libs + 1] = path end
  end
  Loader.loadAll(libs, ns, m)
  Loader.loadAll(Loader.tocFiles("PanelMaster.toc"), ns, m)
  ns.addon:OnInitialize()
  ns.addon:OnEnable()
  return ns, m
end

--- The whole library absent — the empty end of the same partial list, and the state a player who
--- never copied libs/ is actually in.
local function loadDegraded()
  local everything = {}
  for _, path in ipairs(LIB_FILES) do everything[path:match("([^/]+)%.lua$")] = true end
  return loadPartial(everything)
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
  assertTrue(type(NS.DebugLog.Diagnose) == "function", "D:Diagnose has no library equivalent")
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
  -- reading the word. So this case is the headless half of the smoke test: a -78 here means
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
  local lines = capture(function() NS.Slash:CliReset("Editing") end)
  assertTrue(lines[1]:find("Setting not found", 1, true) ~= nil,
    "`/pm reset <page>` resolved something — the page-shaped form is supposed to be gone")
end)

test("L trap (Slash): the ONE overridden string lands, and nothing renders as its own key",
  function()
    local SCREAMING = "^[A-Z][A-Z0-9_]+$"
    -- This addon passes a PLAIN table holding exactly one key. The override must actually win —
    -- a descriptor L that silently did nothing is the other half of the trap.
    local lines = capture(function() NS.Slash:CliResetAll() end)
    assertEqual(lines[#lines], NS.PREFIX .. " all settings reset to defaults (your panels are " ..
      "untouched)", "the RESET_ALL override did not reach the rendered line")
    assertEqual(NS.Slash:Text("RESET_ALL"),
      "all settings reset to defaults (your panels are untouched)")
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
-- So the window is captured around the render rather than inferred afterwards. Memoized because the
-- render only happens ONCE: SetRenderer's OnShow gate returns early on every later show, so a second
-- capture would be empty and every case after the first would find nothing.
local generalCapture
local function generalWidgets()
  if generalCapture then return generalCapture end
  local created = mocks.LibStub("AceGUI-3.0", true).__created
  local from = #created + 1
  showPage(P_general())
  generalCapture = {}
  for i = from, #created do generalCapture[#generalCapture + 1] = created[i] end
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

  local wanted = { bool = 0, number = 0, string = 0 }
  for _, row in ipairs(NS.Schema.Schema) do wanted[row.type] = (wanted[row.type] or 0) + 1 end
  -- `bool` -> CheckBox, a `number` with min/max -> Slider, a `string` with `values` -> Dropdown.
  -- If the schema vocabulary ever drifts back to "boolean", RenderField returns nil for the type it
  -- does not know and the row VANISHES from the page — silently, and only in game.
  assertEqual(#widgetsOfType(P_general(), "CheckBox"), wanted.bool,
    "a bool row did not render as a checkbox — check settings/Schema.lua's `type`")
  assertEqual(#widgetsOfType(P_general(), "Slider"), wanted.number)
  assertEqual(#widgetsOfType(P_general(), "Dropdown"), wanted.string)
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
  local dd = widgetsOfType(P_general(), "Dropdown")[1]
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
    local ctx = P_general()
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
  for _, path in ipairs({ "libs/LibKa0s/Options.lua", "libs/LibKa0s/OptionsWidgets.lua",
                          "libs/LibKa0s/OptionsScroll.lua" }) do
    local src = readFile(path)
    assertTrue(src:find("d.L", 1, true) == nil and src:find("d%.L") == nil,
      path .. " reads a descriptor L — replace this tripwire with a real rendered assertion")
  end
end)

-- ── degradation ────────────────────────────────────────────────────────────────

test("Degraded install: the addon loads with no LibKa0s at all", function()
  local ns = loadDegraded()
  assertTrue(ns.Print ~= nil, "the fallback printer is missing")
  assertTrue(ns.Util.print ~= nil, "NS.Util.print is missing, so the AceConsole reclaim would break")
  assertEqual(ns.Print, ns.Util.print)
  assertTrue(ns.SafeToString ~= nil and ns.IsConcatSafe ~= nil,
    "the degraded stub must answer every member the addon calls, not just the printer")
end)

test("Degraded install: the shared cause clause is set on BOTH paths", function()
  -- Set OUTSIDE the `if not lib` branch, because the later seams append their own consequence to
  -- it whether or not the library is present. The wording is the whole Ka0s collection's and is
  -- not this addon's to reword.
  local EXPECTED = "The LibKa0s library is missing from this installation of Ka0s Panel Master " ..
    "(expected in libs/LibKa0s)"
  assertEqual(NS.LIBKA0S_MISSING, EXPECTED, "the cause clause must be set on the present-library " ..
    "path too — the later seams read it either way")
  local ns = loadDegraded()
  assertEqual(ns.LIBKA0S_MISSING, EXPECTED)
end)

test("Degraded install: the notice is announced exactly ONCE, before the first line", function()
  local ns, m = loadDegraded()
  local before = #m.__chat
  ns.Print("first")
  ns.Print("second")
  ns.Print("third")
  local lines = {}
  for i = before + 1, #m.__chat do lines[#lines + 1] = m.__chat[i] end
  local notices = 0
  for _, line in ipairs(lines) do
    if line:find("running on reduced built-in fallbacks.", 1, true) then notices = notices + 1 end
  end
  assertEqual(notices, 1, "the degraded notice must be said once per session, not per line")
  assertEqual(lines[1], ns.PREFIX .. " " .. ns.LIBKA0S_MISSING ..
    "; running on reduced built-in fallbacks.",
    "the notice must lead with the shared cause clause and this seam's own consequence")
  -- And it must not have eaten the line the user actually asked for.
  assertEqual(lines[2], ns.PREFIX .. " first")
  assertEqual(lines[#lines], ns.PREFIX .. " third")
end)

test("Degraded install: the console explains itself once and every member still answers", function()
  local ns, m = loadDegraded()
  local D = ns.DebugLog
  assertTrue(D ~= nil, "NS.DebugLog is nil in a degraded install — settings/Schema.lua's console " ..
    "row calls IsShown on every panel refresh")
  -- Every member the addon actually calls, per `grep -n "NS.DebugLog" -r`.
  for _, member in ipairs({ "IsShown", "Show", "Hide", "Toggle", "SetEnabled", "Add", "Diagnose" }) do
    assertTrue(type(D[member]) == "function", "the degraded console cannot answer " .. member)
  end
  assertFalse(D:IsShown())
  assertTrue(type(ns.Debug) == "function" and type(ns.DebugBuild) == "function")

  ns.Print("warm up the Core notice")
  local before = #m.__chat
  D:Show(); D:Toggle(); D:ShowCopy()
  local notices = 0
  for i = before + 1, #m.__chat do
    if m.__chat[i]:find("so the debug console window is unavailable.", 1, true) then
      notices = notices + 1
    end
  end
  assertEqual(notices, 1, "the console's absence must be explained once, not on every call")
  -- The consequence is appended to the SHARED cause clause, so a degraded install says the same
  -- thing about why at every site and a different thing about what at each one.
  local found = false
  for i = before + 1, #m.__chat do
    if m.__chat[i]:find(ns.LIBKA0S_MISSING, 1, true) then found = true end
  end
  assertTrue(found, "the console's notice does not carry the shared cause clause")
end)

test("Degraded install: /pm debug on|off still flips the flag and acknowledges", function()
  -- Logging is a session flag the ADDON owns; only the window went away. A stub that swallowed
  -- SetEnabled would make the degraded install look like the flag was stuck off.
  local ns, m = loadDegraded()
  ns.Print("warm up the notice")

  local before = #m.__chat
  ns.DebugLog:SetEnabled(true)
  assertTrue(ns.State.debug, "the degraded console did not set the logging flag")

  local ackOn
  for i = before + 1, #m.__chat do
    if m.__chat[i]:lower():find("debug logging", 1, true) then ackOn = m.__chat[i] end
  end
  assertTrue(ackOn ~= nil, "the degraded console flipped the flag without acknowledging it")

  before = #m.__chat
  ns.DebugLog:SetEnabled(false)
  assertFalse(ns.State.debug)

  local ackOff
  for i = before + 1, #m.__chat do
    if m.__chat[i]:lower():find("debug logging", 1, true) then ackOff = m.__chat[i] end
  end
  assertTrue(ackOff ~= nil, "the degraded console flipped the flag off without acknowledging it")
  assertTrue(ackOn ~= ackOff, "the ack says the same thing on and off")

  -- And the ack must be the STUB's own line, not a hand-copy of the library's. The library owns
  -- `ACK` and the ON/OFF state hexes (libs/LibKa0s/DebugLog.lua); this path runs with the library
  -- ABSENT, so a copy of either is a transcription that nothing can keep in step (anti-pattern #47).
  for _, line in ipairs({ ackOn, ackOff }) do
    assertEqual(line:find("cff40ff40", 1, true), nil, "the stub re-implements the library's ON hex")
    assertEqual(line:find("cffff4040", 1, true), nil, "the stub re-implements the library's OFF hex")
  end
end)

test("Degraded install: /pm debug dump still answers", function()
  -- Diagnose reads the addon's own state and has nothing to do with whether a window exists, so it
  -- is attached on both paths from one definition.
  local ns = loadDegraded()
  local lines = ns.DebugLog:Diagnose()
  assertTrue(type(lines) == "table" and #lines > 0, "Diagnose returned nothing in a degraded install")
end)

test("Degraded install: the fallback printer renders the same bytes as the library's", function()
  local ns, m = loadDegraded()
  ns.Print("warm up the notice")
  local before = #m.__chat
  ns.Print("a", "b")
  assertEqual(m.__chat[#m.__chat], ns.PREFIX .. " a b")
  assertEqual(#m.__chat, before + 1)
  assertEqual(ns.SafeToString(nil), "nil")
  assertEqual(ns.SafeToString(true), "true")
end)

-- ── stub-surface parity, one case per adopted seam (testing-§8) ────────────────
--
-- Four seams are adopted — Core, DebugLog, Slash, Options — and each has an `if not lib then`
-- branch whose member set is what a degraded install runs on. A member the live path publishes and
-- the branch forgets is not a degraded feature, it is a Lua error on a verb the branch was written
-- to keep working: `Sl.FormatKV` was assigned at settings/Slash.lua:381 and not in the branch, so
-- `/pm panel <name>` raised "attempt to call field 'FormatKV' (a nil value)" at
-- settings/Slash.lua:101. A presence check on the members someone remembered misses that exactly as
-- the branch did. Only a SET comparison catches it, which is Kit.assertSurfaceParity.
--
-- Each degraded arm comes from loadPartial() — the real loader, fed a partial file list, omitting
-- only the library file for the seam under test. Nothing here is hand-stubbed.
--
-- Each `ignore` entry is a member the LIVE path publishes on purpose and no addon code path calls,
-- so the branch has nothing to answer with. They are listed as data with the reason beside them,
-- because without that an intentional omission and a bug read the same.

local assertSurfaceParity = T.assertSurfaceParity

test("Parity: the Core seam's degraded surface matches the live one", function()
  -- Core publishes onto NS itself rather than onto one table, so both arms are PROJECTED over the
  -- names the seam assigns. Keys from the source, values from the two loads:
  --   grep -nE "^NS\.[A-Za-z]+ *=|^  function NS\.[A-Za-z]+" core/CoreSetup.lua
  local PUBLISHED = { "Core", "IsConcatSafe", "SafeToString", "Print", "MakeCloseButton" }
  local degradedNS = loadPartial({ Core = true })
  local live, degraded = {}, {}
  for _, name in ipairs(PUBLISHED) do
    assertTrue(NS[name] ~= nil, "core/CoreSetup.lua no longer publishes NS." .. name ..
      " — update PUBLISHED from the grep above rather than deleting the name")
    live[name], degraded[name] = NS[name], degradedNS[name]
  end
  assertSurfaceParity(live, degraded, "Core stub", {
    -- The library instance itself. Its absence IS the degraded state; a stub standing in for it
    -- would be a second LibKa0s.
    "Core",
    -- The close-button wrapper. Its whole body is a call into the library that is not there, and
    -- nothing in this addon calls it yet — a stub answering it would be a frame factory that
    -- cannot make a frame.
    "MakeCloseButton",
  })
  -- NS.Util.print is the real name NS.Print is reclaimed from after the AceConsole embed, and it
  -- has to survive on both paths or the reclaim in core/PanelMaster.lua restores nil.
  assertTrue(type(degradedNS.Util.print) == "function", "the degraded NS.Util.print is missing")
  assertEqual(degradedNS.Util.print, degradedNS.Print)
end)

test("Parity: the DebugLog seam's degraded surface matches the live one", function()
  -- Members from: grep -rn "NS\.DebugLog[:.]" core modules settings
  local degradedNS = loadPartial({ DebugLog = true })
  assertTrue(NS.DebugLog ~= nil and degradedNS.DebugLog ~= nil, "a DebugLog arm is missing")
  assertSurfaceParity(NS.DebugLog, degradedNS.DebugLog, "DebugLog stub", {
    -- Window internals with no addon caller: the console is what went away, so a stub that
    -- answered them would be pretending to own a frame it never built.
    "ConsoleCheckbox", "CopyText", "MakeCloseButton",
    -- The library's line formatters. Reproducing them in the branch is the debug-logging-§7
    -- defect, not the fix — a stub with the right member set and a hand-copied line format is
    -- exactly what a parity case cannot catch, so it is kept out rather than faked.
    "FormatColored", "FormatPlain",
    -- D.Debug is the instance method; the addon calls the BARE NS.Debug, which the branch assigns
    -- itself (core/DebugLogSetup.lua) and which is asserted below.
    "Debug",
    -- The descriptor's string accessor, forwarded on the live path for this suite's L-trap probe.
    -- No addon code path calls it; a stub member with no caller is the anti-pattern.
    "Text",
    -- The library's own test affordances, which it attaches to the live instance the first time
    -- the console is built — so they are present here only because an earlier case in this suite
    -- called Show(). They are hooks for a test, not members the addon calls.
    "_frameForTest", "_toggleClickForTest",
  })
  assertTrue(type(degradedNS.Debug) == "function", "the degraded NS.Debug is missing")
  assertTrue(type(degradedNS.DebugBuild) == "function", "the degraded NS.DebugBuild is missing")
end)

test("Parity: the Slash seam's degraded surface matches the live one", function()
  -- Members from:
  --   grep -rn "Slash[:.]\|Sl[:.]" core modules settings \
  --     | grep -oE "(NS\.Slash|Sl)[:.][A-Za-z_]+" | sort -u
  local degradedNS = loadPartial({ Slash = true })
  local Sl = degradedNS.Slash
  assertTrue(NS.Slash ~= nil and Sl ~= nil, "a Slash arm is missing")
  assertSurfaceParity(NS.Slash, Sl, "Slash stub", {
    -- The descriptor's string accessor, forwarded on the live path for this suite's L-trap probe
    -- and called by no addon code path.
    "Text",
  })

  -- The other direction, which the primitive does not walk: a stub that grew a member the live
  -- path does not have is a divergence too, and it is how a branch quietly re-implements the
  -- library.
  local extra = {}
  for name, value in pairs(Sl) do
    if type(value) == "function" and NS.Slash[name] == nil then extra[#extra + 1] = name end
  end
  table.sort(extra)
  assertEqual(#extra, 0, "the degraded slash surface grew members the live one lacks (" ..
    table.concat(extra, ", ") .. ")")

  -- And the limit the primitive states in its own docs: it cannot see a stub with the right member
  -- set and a WRONG implementation. FormatKV has no library to route to on this path, so its one
  -- line is reproduced — and pinned against the library's own so the two cannot drift.
  local libSlash = mocks.LibStub("LibKa0s-Slash-1.0", true)
  assertTrue(libSlash ~= nil, "LibKa0s-Slash-1.0 did not register on the live path")
  assertEqual(Sl.FormatKV("a.b", "7"), libSlash.FormatKV("a.b", "7"))
  assertEqual(Sl.FormatKV("a.b", "7"), "|cFFFFFF00a.b|r = |cFFFFFFFF7|r")
end)

test("Parity: the Options seam's degraded surface matches the live one", function()
  -- Members from: grep -rn "NS\.Helpers[:.]\|\bO[:.]" core modules settings
  -- Options is one major over three files, so all three come out of the partial list together.
  local degradedNS = loadPartial({ Options = true, OptionsWidgets = true, OptionsScroll = true })
  assertTrue(NS.Helpers ~= nil and degradedNS.Helpers ~= nil, "an Options arm is missing")
  assertTrue(degradedNS.Helpers.__degraded == true, "the Options arm did not take its stub branch")
  assertSurfaceParity(NS.Helpers, degradedNS.Helpers, "Options stub", {
    -- The library's AceGUI handle. The branch sets the key to nil ON PURPOSE: handing back a real
    -- AceGUI with no panel to build into is worse than a nil a caller must guard.
    "AceGUI",
    -- Library-side page builders and layout this addon never calls: its landing page is its own
    -- (settings/Panel.lua), and the three layout constants it DOES read are answered by the branch
    -- as zero rather than as plausible geometry.
    "BuildLandingPage", "TextRow", "PADDING_X",
  })
  -- The three layout constants the addon reads are present and are ZERO, not the library's values:
  -- a stub reporting plausible geometry lets a caller lay something out against numbers no widget
  -- was ever built from.
  for _, k in ipairs({ "ROW_VSPACER", "SECTION_HEADING_H", "BUTTON_PAIR_REL" }) do
    assertEqual(degradedNS.Helpers[k], 0, "the Options stub reports a real-looking " .. k)
  end
end)

test("Degraded install: /pm config answers on EVERY invocation, not once", function()
  -- PM-R-07. The stub latched its explanation behind a `said` flag, so the first `/pm config`
  -- printed why the panel was unavailable and every one after it did nothing at all — which reads
  -- as the command being broken rather than as the panel being missing.
  --
  -- The once-per-session latches elsewhere in this addon are correct and stay: they sit on notices
  -- that ride other output. This line rides nothing; it IS the answer to a verb the user invoked.
  local ns, m = loadPartial({ Options = true, OptionsWidgets = true, OptionsScroll = true })
  ns.Print("warm up the Core notice")
  local before = #m.__chat
  ns.Helpers.OpenOptionsPanel()
  ns.Helpers.OpenOptionsPanel()
  ns.Helpers.OpenOptionsPanel()
  local said = 0
  for i = before + 1, #m.__chat do
    if m.__chat[i]:find("so the settings panel is unavailable.", 1, true) then said = said + 1 end
  end
  assertEqual(said, 3, "`/pm config` went silent after the first invocation")
  -- It carries the collection's shared cause clause, like every other degraded notice here.
  assertTrue(m.__chat[before + 1]:find(ns.LIBKA0S_MISSING, 1, true) ~= nil,
    "the /pm config notice does not lead with the shared cause clause")
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

-- Every file that builds a LibKa0s descriptor. A seam added without being listed here is a seam
-- with no guard, so the list is asserted against the filesystem rather than trusted.
local SEAM_FILES = {
  "core/CoreSetup.lua",
  "core/MediaSetup.lua",
  "core/DebugLogSetup.lua",
  "settings/Slash.lua",
  "settings/OptionsSetup.lua",
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
