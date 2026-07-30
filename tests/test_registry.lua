local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse, assertNear =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNear
local R = NS.Registry
local C = NS.Constants

-- Every case starts from an empty registry: the suites share one addon environment, so a test that
-- inherited the previous one's panels would pass or fail depending on the order it ran in.
local function fresh()
  R:DeleteAll()
end

test("Registry.New: creates a panel with the template's shape", function()
  fresh()
  local rec = R:New("Chat BG")
  assertTrue(rec ~= nil)
  assertEqual(rec.name, "Chat BG")
  assertEqual(rec.width, C.PANEL_TEMPLATE.width)
  assertEqual(rec.point, C.PANEL_TEMPLATE.point)
  assertEqual(R:Count(), 1)
end)

test("Registry.New: rejects an empty name", function()
  fresh()
  local rec, err = R:New("   ")
  assertEqual(rec, nil)
  assertTrue(err:find("name", 1, true) ~= nil)
end)

test("Registry.New: rejects a duplicate name, case-insensitively", function()
  fresh()
  R:New("Chat BG")
  local rec, err = R:New("chat bg")
  assertEqual(rec, nil)
  assertTrue(err:find("already exists", 1, true) ~= nil)
  assertEqual(R:Count(), 1)
end)

test("Registry.New: ids are never reused after a delete", function()
  fresh()
  local first = R:New("One")
  R:Delete("One")
  local second = R:New("Two")
  -- A reused id would let a stale reference (a settings widget closure, a pooled frame) silently
  -- resolve to a different panel than the one it was built for.
  assertTrue(second.id > first.id, "id was reused after a delete")
end)

test("Registry.New: applies the profile's default strata and alpha", function()
  fresh()
  NS.db.profile.settings.defaultStrata = "LOW"
  NS.db.profile.settings.defaultAlpha = 0.5
  local rec = R:New("Defaulted")
  assertEqual(rec.strata, "LOW")
  assertNear(rec.alpha, 0.5)
  NS.db.profile.settings.defaultStrata = "BACKGROUND"
  NS.db.profile.settings.defaultAlpha = 1.0
end)

test("Registry.New: overrides are applied but cannot set the id", function()
  fresh()
  local rec = R:New("Wide", { width = 500, id = 999 })
  assertEqual(rec.width, 500)
  assertTrue(rec.id ~= 999, "an override was allowed to choose the id")
end)

test("Registry.New: does not alias the shared template", function()
  fresh()
  local a = R:New("A")
  a.bgColor[1] = 0.99
  local b = R:New("B")
  -- If New handed out a reference to C.PANEL_TEMPLATE, editing A's colour would have poisoned the
  -- template and B would come out with A's colour.
  assertNear(b.bgColor[1], C.PANEL_TEMPLATE.bgColor[1])
end)

test("Registry.Delete: removes the panel and reports its name", function()
  fresh()
  R:New("Doomed")
  local ok, name = R:Delete("Doomed")
  assertTrue(ok)
  assertEqual(name, "Doomed")
  assertEqual(R:Count(), 0)
end)

test("Registry.Delete: an unknown panel is an error, not a silent no-op", function()
  fresh()
  local ok, err = R:Delete("Nope")
  assertFalse(ok)
  assertTrue(err:find("no panel", 1, true) ~= nil)
end)

test("Registry.DeleteAll: empties the registry and reports the count", function()
  fresh()
  R:New("A"); R:New("B"); R:New("C")
  assertEqual(R:DeleteAll(), 3)
  assertEqual(R:Count(), 0)
end)

test("Registry.Resolve: finds by name and by id", function()
  fresh()
  local rec = R:New("Findable")
  assertEqual(R:Resolve("Findable").id, rec.id)
  assertEqual(R:Resolve("findable").id, rec.id)
  assertEqual(R:Resolve(rec.id).id, rec.id)
  assertEqual(R:Resolve("missing"), nil)
end)

test("Registry.Resolve: a name wins over an id that looks like it", function()
  fresh()
  local first = R:New("First")          -- takes some id
  local numeric = R:New(tostring(first.id))   -- a panel literally named "<that id>"
  -- A user who named a panel "3" means that panel, not whichever panel happens to hold id 3.
  assertEqual(R:Resolve(tostring(first.id)).id, numeric.id)
end)

test("Registry.Rename: renames and reports the old name", function()
  fresh()
  R:New("Old")
  local ok, old = R:Rename("Old", "New")
  assertTrue(ok)
  assertEqual(old, "Old")
  assertTrue(R:FindByName("New") ~= nil)
  assertEqual(R:FindByName("Old"), nil)
end)

test("Registry.Rename: re-casing a panel's own name is allowed", function()
  fresh()
  R:New("chat bg")
  local ok = R:Rename("chat bg", "Chat BG")
  -- The collision check must exclude the panel being renamed, or a pure case change would be
  -- rejected as a duplicate of itself.
  assertTrue(ok, "re-casing was rejected as a duplicate")
  assertEqual(R:FindByName("Chat BG").name, "Chat BG")
end)

test("Registry.Rename: rejects a collision with a different panel", function()
  fresh()
  R:New("A"); R:New("B")
  local ok, err = R:Rename("A", "B")
  assertFalse(ok)
  assertTrue(err:find("already exists", 1, true) ~= nil)
end)

test("Registry.Sanitize: clamps size into range", function()
  local rec = R.Sanitize({ width = -50, height = 99999 })
  assertEqual(rec.width, C.MIN_SIZE)
  assertEqual(rec.height, C.MAX_SIZE)
end)

test("Registry.Sanitize: repairs invalid anchor and strata tokens", function()
  local rec = R.Sanitize({ point = "MIDDLE", strata = "PARCHMENT" })
  assertEqual(rec.point, C.PANEL_TEMPLATE.point)
  assertEqual(rec.strata, C.PANEL_TEMPLATE.strata)
end)

test("Registry.Sanitize: a string size from a hand-edited SV becomes a number", function()
  local rec = R.Sanitize({ width = "300" })
  assertEqual(type(rec.width), "number")
  assertEqual(rec.width, 300)
end)

test("Registry.Sanitize: does NOT clamp offsets to the screen", function()
  -- A legitimate multi-monitor layout carries large offsets; clamping on every write would destroy
  -- it the first time the user logged in at a lower resolution. Recovery is opt-in (R:Recover).
  local rec = R.Sanitize({ x = -5000, y = 5000 })
  assertEqual(rec.x, -5000)
  assertEqual(rec.y, 5000)
end)

test("Registry.Sanitize: enabled defaults to true, and only explicit false disables", function()
  assertTrue(R.Sanitize({}).enabled)
  assertTrue(R.Sanitize({ enabled = nil }).enabled)
  assertFalse(R.Sanitize({ enabled = false }).enabled)
end)

test("Registry.Set: writes a number field", function()
  fresh()
  local rec = R:New("Sized")
  assertTrue(R:Set(rec.id, "width", 400))
  assertEqual(R:Get(rec.id).width, 400)
end)

test("Registry.Set: coerces a CLI string to the field's type", function()
  fresh()
  local rec = R:New("Coerced")
  R:Set(rec.id, "width", "350")
  assertEqual(R:Get(rec.id).width, 350)
  R:Set(rec.id, "enabled", "off")
  assertFalse(R:Get(rec.id).enabled)
end)

test("Registry.Set: parses a colour string", function()
  fresh()
  local rec = R:New("Coloured")
  assertTrue(R:Set(rec.id, "bgColor", "1,0,0,0.5"))
  local c = R:Get(rec.id).bgColor
  assertNear(c[1], 1)
  assertNear(c[4], 0.5)
end)

test("Registry.Set: rejects an unknown field", function()
  fresh()
  local rec = R:New("Strict")
  local ok, err = R:Set(rec.id, "sparkles", true)
  assertFalse(ok)
  assertTrue(err:find("unknown field", 1, true) ~= nil)
end)

test("Registry.Set: rejects an invalid anchor with a helpful message", function()
  fresh()
  local rec = R:New("Anchored")
  local ok, err = R:Set(rec.id, "point", "MIDDLE")
  assertFalse(ok)
  assertTrue(err:find("TOPLEFT", 1, true) ~= nil, "the error should list the valid anchors")
end)

test("Registry.Set: accepts a lower-case anchor and stores it upper-case", function()
  fresh()
  local rec = R:New("Cased")
  assertTrue(R:Set(rec.id, "point", "topleft"))
  assertEqual(R:Get(rec.id).point, "TOPLEFT")
end)

test("Registry.Set: writing `name` routes through Rename's uniqueness check", function()
  fresh()
  R:New("A")
  local b = R:New("B")
  local ok = R:Set(b.id, "name", "A")
  -- A direct field write would have produced two panels called "A" and broken every by-name lookup.
  assertFalse(ok, "name was written without the uniqueness check")
end)

test("Registry.Set: clamps out-of-range input rather than rejecting it", function()
  fresh()
  local rec = R:New("Clamped")
  R:Set(rec.id, "alpha", 5)
  assertEqual(R:Get(rec.id).alpha, 1)
end)

test("Registry.SetPosition: writes both coordinates at once", function()
  fresh()
  local rec = R:New("Moved")
  assertTrue(R:SetPosition(rec.id, 120, -80))
  assertEqual(R:Get(rec.id).x, 120)
  assertEqual(R:Get(rec.id).y, -80)
end)

test("Registry.FormatField: renders each field type readably", function()
  fresh()
  local rec = R:New("Formatted")
  assertEqual(R.FormatField(rec, "enabled"), "true")
  assertEqual(R.FormatField(rec, "width"), tostring(C.PANEL_TEMPLATE.width))
  assertEqual(R.FormatField(rec, "alpha"), "1.00")
  assertTrue(R.FormatField(rec, "bgColor"):find(",", 1, true) ~= nil)
end)

test("Registry.Recover: leaves on-screen panels alone", function()
  fresh()
  R:New("Fine", { x = 100, y = 100 })
  assertEqual(R:Recover(), 0)
end)

test("Registry.Recover: pulls an off-screen panel back into view", function()
  fresh()
  local rec = R:New("Lost", { x = 9000, y = -9000 })
  assertEqual(R:Recover(), 1)
  local moved = R:Get(rec.id)
  assertEqual(moved.x, 960)    -- half of the mock's 1920 screen width
  assertEqual(moved.y, -540)   -- half of its 1080 height
end)

test("Registry: the panel messages have exactly one sender", function()
  -- architecture-§4: one sender per bus message. Asserted against the sources because a second
  -- sender is added by a well-meaning edit in another file and is invisible until two consumers
  -- disagree about what a message means.
  local files = {
    "core/PanelMaster.lua", "core/Database.lua", "modules/Canvas.lua", "modules/Unlock.lua",
    "modules/DebugLog.lua", "settings/Schema.lua", "settings/Slash.lua", "settings/Panel.lua",
  }
  for _, path in ipairs(files) do
    local f = io.open(path, "r")
    local body = f:read("*a")
    f:close()
    assertEqual(body:find("SendMessage%s*%(%s*[\"']Ka0s_PanelMaster_Panel"), nil,
      path .. " sends a panel message; only modules/Registry.lua may")
  end
end)
