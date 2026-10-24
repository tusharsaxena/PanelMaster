-- tests/test_settings_guard.lua — the stored-setting guard for item 020 (settings layout).
--
-- WHAT IT PROVES. That the SET of stored setting paths, and each one's default, type and range, is
-- exactly what it was before the settings-layout pass (Ka0sAddonsCommonTasks
-- docs/2026-10-24-KEYBINDS_LAYOUT_STRATA, item PM-LY). The owner's rule for that pass is "move,
-- regroup and relabel only": rows may change tab, order, heading, label and tooltip, and nothing a
-- player has stored may move. A label change is never a migration (options-ui-§21).
--
-- WHAT IT COVERS. Every profile row (S.ProfileRows: the hand-written rows, the composed Master
-- controls rows and the minimap row), and every per-panel record field with its template default
-- (C.PANEL_FIELD_ORDER over C.PANEL_TEMPLATE) -- the Panels page's editor writes those through
-- NS.Registry:Set, and they are the stored half of that page.
--
-- WHAT IT DOES NOT COVER, ON PURPOSE. `group`, `label` and `tooltip` are the parts a layout pass is
-- allowed to change, so they are not pinned here; tests/test_schema.lua and
-- tests/test_panels_page.lua pin where each row is drawn and what it reads.
--
-- The pin was taken from the tree BEFORE the first layout edit. A diff in it is a key, default or
-- range drift, which the layout pass is not allowed to make: fix the change, never the pin, unless
-- a later item really does add or move a setting (and says so).
local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local C = NS.Constants

-- A deterministic one-line rendering of a value: tables sorted by key, numbers via %.17g so 0.05
-- and a 0.05 that drifted by a rounding step differ.
local function render(v)
  local kind = type(v)
  if kind == "number" then return ("%.17g"):format(v) end
  if kind == "string" then return ("%q"):format(v) end
  if kind ~= "table" then return tostring(v) end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. render(v[k]) end
  return "{" .. table.concat(parts, ",") .. "}"
end

-- A row's stored contract: its default, type, range and step, and its value SET (the values'
-- keys, not their display text, which a relabel may change). `sessionOnly` is carried because a row
-- turning stored (or the reverse) changes what reaches SavedVariables.
local function rowContract(row)
  local values
  local vs = row.values
  if type(vs) == "function" then vs = nil end
  if type(vs) == "table" then
    values = {}
    for k, val in pairs(vs) do
      -- An ordered option list ({ value =, label = } or { value =, text = }) is keyed by its value;
      -- a map is keyed by its key.
      if type(val) == "table" and val.value ~= nil then values[#values + 1] = tostring(val.value)
      else values[#values + 1] = tostring(k) end
    end
    table.sort(values)
    values = table.concat(values, "|")
  end
  return render({
    default = row.default, type = row.type, min = row.min, max = row.max, step = row.step,
    sessionOnly = row.sessionOnly and true or nil, values = values,
  })
end

local function currentProfileRows()
  local out, n = {}, 0
  for _, row in ipairs(NS.Schema.ProfileRows()) do
    out[row.path] = rowContract(row)
    n = n + 1
  end
  return out, n
end

local function currentPanelFields()
  local out, n = {}, 0
  for _, field in ipairs(C.PANEL_FIELD_ORDER) do
    out[field] = render(C.PANEL_TEMPLATE[field])
    n = n + 1
  end
  return out, n
end

-- path -> contract, taken at HEAD before the layout pass.
local PROFILE_PIN = {
  ["global.minimap.shown"] = "{default=true,type=\"bool\"}",
  ["settings.alpha"] = "{default=1,max=1,min=0,step=0.050000000000000003,type=\"number\"}",
  ["settings.defaultAlpha"] = "{default=1,max=1,min=0,step=0.050000000000000003,type=\"number\"}",
  ["settings.defaultHeight"] = "{default=120,max=4096,min=8,step=1,type=\"number\"}",
  ["settings.defaultStrata"] = "{default=\"LOW\",type=\"string\",values=\"BACKGROUND|DIALOG|FULLSCREEN|FULLSCREEN_DIALOG|HIGH|LOW|MEDIUM|TOOLTIP\"}",
  ["settings.defaultWidth"] = "{default=240,max=4096,min=8,step=1,type=\"number\"}",
  ["settings.enabled"] = "{default=true,type=\"bool\"}",
  ["settings.gridSize"] = "{default=4,max=64,min=1,step=1,type=\"number\"}",
  ["settings.scale"] = "{default=1,max=2,min=0.5,step=0.050000000000000003,type=\"number\"}",
  ["settings.showLabels"] = "{default=true,type=\"bool\"}",
  ["settings.snapToGrid"] = "{default=true,type=\"bool\"}",
  ["settings.unlockOutlineSize"] = "{default=2,max=12,min=1,step=1,type=\"number\"}",
  ["settings.visibility"] = "{default=\"always\",type=\"string\",values=\"always|inCombat|never|outOfCombat\"}",
  ["state.debugConsole"] = "{default=false,sessionOnly=true,type=\"bool\"}",
  ["state.locked"] = "{default=true,sessionOnly=true,type=\"bool\"}",
}

-- field -> template default, taken at HEAD before the layout pass.
local PANEL_PIN = {
  accentAlpha = "1",
  accentBorderClassColor = "false",
  accentBorderColor = "{1=0,2=0,3=0,4=1}",
  accentBorderOffset = "0",
  accentBorderSize = "1",
  accentBorderTexture = "\"Solid\"",
  accentClassColor = "true",
  accentColor = "{1=1,2=1,3=1,4=1}",
  accentEdges = "{TOP=true}",
  accentEnabled = "true",
  accentOffset = "0",
  accentTexture = "\"Blizzard\"",
  accentThickness = "5",
  alpha = "1",
  artAlpha = "1",
  artBlend = "\"BLEND\"",
  artClassColor = "false",
  artColor = "{1=1,2=1,3=1,4=1}",
  artCustomPath = "\"\"",
  artDesaturate = "false",
  artFill = "\"FIT\"",
  artFlipH = "false",
  artFlipV = "false",
  artLayer = "\"ABOVE_BG\"",
  artPoint = "\"CENTER\"",
  artRotation = "0",
  artScale = "1",
  artTexture = "\"None\"",
  artX = "0",
  artY = "0",
  bgClassColor = "false",
  bgColor = "{1=0.050000000000000003,2=0.050000000000000003,3=0.070000000000000007,4=0.84999999999999998}",
  bgTexture = "\"Solid\"",
  borderClassColor = "false",
  borderColor = "{1=0.34999999999999998,2=0.34999999999999998,3=0.40000000000000002,4=1}",
  borderOffset = "0",
  borderSize = "0",
  borderTexture = "\"Solid\"",
  enabled = "true",
  height = "120",
  level = "0",
  mouseover = "false",
  mouseoverAlpha = "0",
  name = "\"Panel\"",
  point = "\"CENTER\"",
  relPoint = "\"CENTER\"",
  scale = "1",
  strata = "\"LOW\"",
  width = "240",
  x = "0",
  y = "0",
}

local function compare(kind, pin, live)
  local problems = {}
  for k, want in pairs(pin) do
    if live[k] == nil then problems[#problems + 1] = ("%s %s is gone"):format(kind, k)
    elseif live[k] ~= want then
      problems[#problems + 1] = ("%s %s changed: %s -> %s"):format(kind, k, want, live[k])
    end
  end
  for k, got in pairs(live) do
    if pin[k] == nil then problems[#problems + 1] = ("%s %s is new: %s"):format(kind, k, got) end
  end
  table.sort(problems)
  return problems
end

test("Settings guard: every stored profile path keeps its default, type and range", function()
  local live, n = currentProfileRows()
  assertTrue(n > 0, "no profile rows were found, so the guard is looking at nothing")
  local problems = compare("profile row", PROFILE_PIN, live)
  assertEqual(#problems, 0, table.concat(problems, "\n"))
end)

test("Settings guard: every panel record field keeps its template default", function()
  local live, n = currentPanelFields()
  assertTrue(n > 0, "no panel fields were found, so the guard is looking at nothing")
  local problems = compare("panel field", PANEL_PIN, live)
  assertEqual(#problems, 0, table.concat(problems, "\n"))
end)
