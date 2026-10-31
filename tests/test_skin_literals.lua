-- tests/test_skin_literals.lua — the hard-coded color gate (PM-02; skinning's anti-pattern #107,
-- binding for this addon since it adopted skins). LootHistory's tests/test_skin_literals.lua, the
-- collection's first adopter, with this addon's allow-list.
--
-- WHAT IT PROVES. That no color this addon draws on its own chrome is a literal the skin cannot
-- reach. Two shapes are caught, in every tracked .lua file under core/, modules/ and settings/:
--
--   1. A NUMERIC LITERAL IN A COLOR POSITION of a paint call: the r, g or b argument of
--      SetTextColor, SetColorTexture, SetVertexColor, SetBackdropColor and SetBackdropBorderColor,
--      the r, g, b after AddLine's text, and the two r, g, b triples after AddDoubleLine's texts.
--      `SetTextColor(0.5, 0.5, 0.5)` fails; `SetTextColor(NS.Skin.Color("text.disabled"))` passes.
--      An ALPHA literal over token components (`SetColorTexture(r, g, b, 0.95)`) is not a color:
--      it is the surface's opacity, the same under every skin, and is left alone on purpose.
--   2. A `|cff` (any case) escape in code, i.e. markup that names a color byte for byte. Comments
--      are stripped first; NS.SkinEscape builds the escapes a token feeds.
--
-- WHAT IT DOES NOT SEE, ON PURPOSE. The panels' own fill, border, accent and artwork colors are the
-- player's per-record values (rollout E8, D1), passed as variables, so the shape never matches them.
--
-- core/SkinSetup.lua is out of scope: it IS the seam, and its host copy of the Ka0s Default tokens
-- (NS.SKIN_FALLBACK) and NS.SkinEscape's format are the literals every other file reads through.
--
-- THE ALLOW-LIST. Each entry names one file, a plain substring the offending line carries, and the
-- reason it is not chrome (the rollout's DECISIONS X7, chat output, and X9, inline content markup).
-- An entry that matches nothing fails the gate, so the list cannot outlive what it excuses.
--
-- IT FAILS RATHER THAN PASSES WHEN IT CANNOT LOOK: no io.popen, no git, or an empty file list is a
-- failure, the bargain tests/test_lintconfig.lua strikes. The fourth case proves the gate is
-- falsifiable: a planted literal of each shape is reported.

local T = _G.PM_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue, fail = T.test, T.assertEqual, T.assertTrue, T.fail
local ROOT = T.root or "."

local SEAM = "core/SkinSetup.lua"

-- call name -> the argument positions that hold color components.
local COLOR_ARGS = {
  SetTextColor = { 1, 2, 3 }, SetColorTexture = { 1, 2, 3 }, SetVertexColor = { 1, 2, 3 },
  SetBackdropColor = { 1, 2, 3 }, SetBackdropBorderColor = { 1, 2, 3 },
  AddLine = { 2, 3, 4 }, AddDoubleLine = { 3, 4, 5, 6, 7, 8 },
}

local ALLOW = {
  { file = "core/Namespace.lua", find = "NS.PREFIX",
    why = "the [PM] chat prefix: chat output, not a skinned surface (X7)" },
  { file = "modules/Unlock.lua", find = "unlock queued",
    why = "the deferred-unlock chat line: chat output (X7)" },
  { file = "settings/Schema.lua", find = "schema error",
    why = "the schema error chat line: chat output (X7)" },
  { file = "settings/Slash.lua", find = "|cff33ff99",
    why = "the /pm list and /pm panel dump headers: chat output (X7)" },
  { file = "settings/Slash.lua", find = "|cffffff00",
    why = "commands and panel names in the /pm chat lines: chat output (X7)" },
  { file = "settings/Slash.lua", find = "|cff808080",
    why = "a disabled panel's name in the /pm list dump: chat output (X7)" },
  { file = "settings/Slash.lua", find = "|cffffffff",
    why = "a panel's geometry in the /pm list dump: chat output (X7)" },
  { file = "settings/Slash.lua", find = "|cFFFFFF00",
    why = "the library's disabled line, pinned byte for byte to lib.DISABLED_LINE_FORMAT (X7)" },
  { file = "settings/PanelEditorTabs.lua", find = "|cffffff00",
    why = "inline emphasis inside the editor's tooltip bodies: content markup, as FormatRow (X9)" },
}

--- Strip a line's trailing comment. `--` never occurs inside a string in these files' color code, so
--- a plain cut is enough; a string that did hold one would only shorten what is scanned.
local function code(line) return (line:gsub("%-%-.*$", "")) end

--- Split a call's argument list at its top-level commas (parens, braces and quotes nest).
local function splitArgs(s)
  local args, depth, buf, quote = {}, 0, {}, nil
  local i = 1
  while i <= #s do
    local c = s:sub(i, i)
    if quote then
      buf[#buf + 1] = c
      if c == "\\" then buf[#buf + 1] = s:sub(i + 1, i + 1); i = i + 1
      elseif c == quote then quote = nil end
    elseif c == '"' or c == "'" then quote = c; buf[#buf + 1] = c
    elseif c == "(" or c == "{" or c == "[" then depth = depth + 1; buf[#buf + 1] = c
    elseif c == ")" or c == "}" or c == "]" then depth = depth - 1; buf[#buf + 1] = c
    elseif c == "," and depth == 0 then args[#args + 1] = table.concat(buf); buf = {}
    else buf[#buf + 1] = c end
    i = i + 1
  end
  args[#args + 1] = table.concat(buf)
  return args
end

local function isNumber(arg) return arg:match("^%s*%-?%d*%.?%d+%s*$") ~= nil end

--- Every offending line of one source text: { line = n, text = what was found }.
local function scan(src)
  local lines, hits = {}, {}
  for ln in (src .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = code(ln) end
  local stripped = table.concat(lines, "\n")
  for name, positions in pairs(COLOR_ARGS) do
    local init = 1
    while true do
      local s, e, args = stripped:find("[:%.]" .. name .. "%s*(%b())", init)
      if not s then break end
      init = e + 1
      local list = splitArgs(args:sub(2, -2))
      for _, p in ipairs(positions) do
        if list[p] and isNumber(list[p]) then
          local n = select(2, stripped:sub(1, s):gsub("\n", "")) + 1
          hits[#hits + 1] = { line = n, text = lines[n] }
          break
        end
      end
    end
  end
  for n, ln in ipairs(lines) do
    if ln:find("|c[fF][fF]") then hits[#hits + 1] = { line = n, text = ln } end
  end
  return hits
end

local function allowed(file, text, used)
  for i, a in ipairs(ALLOW) do
    if a.file == file and text:find(a.find, 1, true) then used[i] = true; return true end
  end
  return false
end

local function trackedSources()
  if not io.popen then fail("skin literal gate: io.popen is unavailable, so this gate cannot run") end
  local p = io.popen("git -C '" .. ROOT .. "' ls-files 'core/*.lua' 'modules/*.lua' 'settings/*.lua' 2>/dev/null")
  if not p then fail("skin literal gate: io.popen returned no handle") end
  local files = {}
  for path in p:lines() do if path ~= SEAM then files[#files + 1] = path end end
  p:close()
  if #files == 0 then fail("skin literal gate: git listed no source files, so nothing was scanned") end
  return files
end

local function readAll(path)
  local f = io.open(ROOT .. "/" .. path, "rb")
  if not f then fail("skin literal gate: cannot read " .. path) end
  local s = f:read("*a")
  f:close()
  return s
end

test("Skin literals: no color literal outside core/SkinSetup.lua and the named allow-list", function()
  local bad, used = {}, {}
  for _, path in ipairs(trackedSources()) do
    for _, h in ipairs(scan(readAll(path))) do
      if not allowed(path, h.text, used) then
        bad[#bad + 1] = ("%s:%d: %s"):format(path, h.line, (h.text:gsub("^%s+", "")))
      end
    end
  end
  assertEqual(#bad, 0, "hard-coded colors the skin cannot reach (read a token through NS.Skin / "
    .. "NS.SkinEscape, or add an allow-list entry with its reason):\n  "
    .. table.concat(bad, "\n  "))
  for i, a in ipairs(ALLOW) do
    assertTrue(used[i], ("stale allow-list entry: %s %q matches nothing"):format(a.file, a.find))
  end
end)

test("Skin literals: every allow-list entry carries its reason", function()
  for _, a in ipairs(ALLOW) do
    assertTrue(type(a.why) == "string" and #a.why > 10, a.file .. " " .. a.find .. ": no reason")
  end
end)

test("Skin literals: the gate is falsifiable, a planted literal of each shape is reported", function()
  local planted = table.concat({
    "local x = 1",
    "fs:SetTextColor(0.85, 0.85, 0.85)",
    "tex:SetColorTexture(r, g,",
    "  0.5, 1)",
    'tt:AddLine("n records", 0.7, 0.7, 0.7)',
    'tt:AddDoubleLine("a", "b", r, g, b, 1, 1, 1)',
    'local s = "|cff808080(disabled)|r"',
    "fs:SetTextColor(NS.Skin.Color(\"text.body\"))   -- 0.9, 0.9, 0.9 in a comment",
    "tex:SetColorTexture(r, g, b, 0.95)",
    "-- |cffffffff in a comment",
  }, "\n")
  local hits = scan(planted)
  local lines = {}
  for _, h in ipairs(hits) do lines[#lines + 1] = h.line end
  table.sort(lines)
  assertEqual(table.concat(lines, ","), "2,3,5,6,7",
    "the literal lines and only those (a token call, an alpha literal and a comment pass)")
end)

-- ── the seam's helpers and the host copy ─────────────────────────────────────────────────────

local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
local OWNER = "PanelMaster"

--- Run `fn` on `skin`, then put Ka0s Default back whatever `fn` raised.
local function onSkin(skin, fn)
  Skin:SetChoice(OWNER, "ka0s", skin)
  local ok, err = pcall(fn)
  Skin:SetChoice(OWNER, "ka0s", "ka0s")
  if not ok then error(err, 0) end
end

test("Skin literals: the host copy of Ka0s Default equals the library's Ka0s Default", function()
  onSkin("ka0s", function()
    local n = 0
    for name, c in pairs(NS.SKIN_FALLBACK) do
      n = n + 1
      local r, g, b, a = NS.Skin.Color(name)
      assertTrue(r ~= nil, name .. ": the library answers no such color token")
      assertEqual(("%.3f %.3f %.3f %.3f"):format(r, g, b, a or 1),
        ("%.3f %.3f %.3f %.3f"):format(c[1], c[2], c[3], c[4] or 1),
        name .. ": the degraded facade's copy drifted from the library")
    end
    assertTrue(n > 0, "NS.SKIN_FALLBACK is empty, but the disabled marker reads text.disabled")
  end)
end)

test("Skin literals: NS.SkinEscape keeps the bytes of the literal it replaced", function()
  onSkin("ka0s", function()
    assertEqual(NS.SkinEscape("text.disabled"), "|cff808080",
      "Ka0s Default's disabled gray is the |cff808080 the marker was typed as")
    assertEqual(NS.SkinEscape("no.such.token"), nil)
  end)
end)

-- ── the Panels page picker's "(disabled)" marker (inventory S12) ──────────────────────────────

local E = NS.PanelEditor

--- The picker's entry for a disabled panel, built on a fresh Panels page under `skin`.
local function disabledEntry(skin)
  local entry
  onSkin(skin, function()
    NS.Registry:DeleteAll()
    local rec = NS.Registry:New("Dimmed", { enabled = false })
    E.__setSelectedID(rec.id)
    local ctx = NS.Helpers.CreatePanel(nil, "Panels", { pageKey = "panels" })
    ctx.dropdowns, ctx.rebuilders = {}, {}
    ctx.refreshers = ctx.refreshers or {}
    E:BuildPage(ctx)
    E:Rebuild(ctx)
    assertTrue(ctx.__pmPicker ~= nil and ctx.__pmPicker.list ~= nil, "the page drew no panel picker")
    entry = ctx.__pmPicker.list[rec.id]
    NS.Registry:DeleteAll()
    E.__setSelectedID(nil)
  end)
  return entry
end

test("Skin literals: the picker's (disabled) marker is today's gray on Ka0s Default", function()
  assertEqual(disabledEntry("ka0s"), "Dimmed |cff808080(disabled)|r")
end)

--- Run `fn` with the owner's applied "Ignore settings panel" set to `panel`, then put back the
--- exceptions it found, whatever `fn` raised.
local function withPanelIgnored(panel, fn)
  local was, fonts = Skin:GetIgnore(OWNER)
  Skin:SetIgnore(OWNER, panel, fonts)
  local ok, err = pcall(fn)
  Skin:SetIgnore(OWNER, was, fonts)
  if not ok then error(err, 0) end
end

test("Skin literals: the picker's (disabled) marker follows the skin's text.disabled", function()
  withPanelIgnored(false, function()
    local want
    onSkin("obsidian", function() want = NS.SkinEscape("text.disabled") end)
    assertTrue(want ~= nil and want ~= "|cff808080",
      "the obsidian skin's text.disabled is Ka0s Default's, so this case could not see a miss")
    assertEqual(disabledEntry("obsidian"), "Dimmed " .. want .. "(disabled)|r")
  end)
end)

-- Change that turns this red: building the marker from NS.SkinEscape (the worn skin) instead of
-- NS.SkinPanelEscape, so the one settings-page value leaks past Ignore settings panel (review PM-02).
test("Skin literals: the picker's (disabled) marker stays today's gray while the panel is ignored",
  function()
    withPanelIgnored(true, function()
      assertEqual(disabledEntry("obsidian"), "Dimmed |cff808080(disabled)|r",
        "the ignored settings panel took the worn skin's disabled gray")
    end)
  end)
