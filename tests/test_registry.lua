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
  -- If New handed out a reference to C.PANEL_TEMPLATE, editing A's color would have poisoned the
  -- template and B would come out with A's color.
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

test("Registry.DeleteAll: drops the session state keyed on the panels it removed (F-020)", function()
  fresh()
  local a, b = R:New("A"), R:New("B")
  NS.State.unlockedPanels[a.id] = true
  NS.State.unlockedPanels[b.id] = true
  NS.State.previewIDs = { a.id, b.id }
  R:DeleteAll()
  -- Ids are never reused, so a stale entry is never read again — but it accumulates for the session
  -- and shows up in a debug dump as an unlocked panel that does not exist. R:Delete already sweeps;
  -- DeleteAll must too, and for the same reason.
  assertEqual(NS.State.unlockedPanels[a.id], nil, "a deleted panel is still marked unlocked")
  assertEqual(NS.State.unlockedPanels[b.id], nil, "a deleted panel is still marked unlocked")
  assertEqual(#NS.State.previewIDs, 0, "preview still claims ids that no longer exist")
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

test("Registry.Set: an unreadable boolean is refused, not stored as false (F-023)", function()
  fresh()
  local rec = R:New("Typoed")
  local ok, err = R:Set(rec.id, "enabled", "ture")
  assertFalse(ok, "'ture' was accepted")
  assertTrue(err:find("expected true/false", 1, true) ~= nil, "the error does not list the tokens")
  -- The regression that matters: the old coercion turned every unrecognized word into `false`, so a
  -- typo switched the panel OFF and echoed that as though it had been asked for.
  assertTrue(R:Get(rec.id).enabled, "a typo turned the panel off")
end)

test("Registry.Set: parses a color string", function()
  fresh()
  local rec = R:New("Colored")
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

test("Registry.CopyFrom: never spreads the preview marker onto a real panel", function()
  fresh()
  local ghost = R:New("Ghost", { [C.PREVIEW_FIELD] = true })
  local mine  = R:New("Mine")
  assertTrue(R:CopyFrom(mine.id, ghost.id))
  -- Copying appearance from a placeholder must not make the target disappear on the next sweep.
  assertEqual(R:Get(mine.id)[C.PREVIEW_FIELD], nil, "the preview marker was copied across")
end)

test("Registry.NewBatch: creates every spec and broadcasts once", function()
  fresh()
  local target, count = {}, 0
  NS.bus.RegisterMessage(target, R.MSG_PANELS, function() count = count + 1 end)

  local recs = R:NewBatch({ { name = "Batch One" }, { name = "Batch Two" } })
  assertEqual(#recs, 2)
  assertEqual(R:Count(), 2)
  assertEqual(count, 1, "a batch create broadcast once per record")

  NS.bus.UnregisterMessage(target, R.MSG_PANELS)
end)

test("Registry.NewBatch: skips a spec whose name is taken, keeping the rest", function()
  fresh()
  R:New("Batch One")
  local recs = R:NewBatch({ { name = "Batch One" }, { name = "Batch Two" } })
  -- A name collision is the user's, not ours: skip that one rather than refuse the whole batch.
  assertEqual(#recs, 1)
  assertEqual(recs[1].name, "Batch Two")
end)

test("Registry.Recover: leaves an on-screen TOPLEFT panel alone", function()
  fresh()
  -- The bug this guards: a CENTER-shaped bound (±w/2) called this panel lost and dragged it to 960.
  R:New("Corner", { point = "TOPLEFT", relPoint = "TOPLEFT", x = 1000, y = -300 })
  assertEqual(R:Recover(), 0, "a fully on-screen TOPLEFT panel was moved")
end)

test("Registry.Recover: still rescues a genuinely off-screen TOPLEFT panel", function()
  fresh()
  local rec = R:New("Gone", { point = "TOPLEFT", relPoint = "TOPLEFT", x = 9000, y = 9000 })
  assertEqual(R:Recover(), 1)
  local moved = R:Get(rec.id)
  assertEqual(moved.x, 1920)   -- the mock's full screen width: a LEFT anchor runs 0..w
  assertEqual(moved.y, 0)      -- and a TOP anchor runs -h..0
end)

test("Registry.Recover: survives a record whose anchor is missing or junk (F-006)", function()
  fresh()
  -- Nothing sanitizes records at login — Sanitize runs per write and on a profile switch — so a
  -- hand-edited or pre-anchor SavedVariables file can hand the sweep a nil (or non-string)
  -- relPoint. Indexing it would abort the loop half-written: the panels already visited would have
  -- had x/y rewritten in the DB with no broadcast and no repaint, and the rest never looked at.
  local broken = R:New("No anchor", { x = 9000, y = 9000 })
  broken.relPoint = nil
  local junk = R:New("Junk anchor", { x = 9000, y = 9000 })
  junk.relPoint = 5
  local ok = R:New("Also lost", { x = 9000, y = 9000 })

  assertEqual(R:Recover(), 3, "the sweep gave up before it reached every panel")
  -- All three fall back to the template's CENTER anchor, like Canvas.BuildSpec already does.
  for _, rec in ipairs({ broken, junk, ok }) do
    local moved = R:Get(rec.id)
    assertEqual(moved.x, 960, rec.name .. " was not bounded as a CENTER anchor")
    assertEqual(moved.y, 540, rec.name .. " was not bounded as a CENTER anchor")
  end
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
    "core/DebugLogSetup.lua", "settings/Schema.lua", "settings/Slash.lua", "settings/Panel.lua",
  }
  for _, path in ipairs(files) do
    local f = io.open(path, "r")
    local body = f:read("*a")
    f:close()
    assertEqual(body:find("SendMessage%s*%(%s*[\"']Ka0s_PanelMaster_Panel"), nil,
      path .. " sends a panel message; only modules/Registry.lua may")
  end
end)
