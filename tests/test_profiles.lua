local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse, assertNear =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNear
local R, Canvas, C = NS.Registry, NS.Canvas, NS.Constants

local function fresh()
  T.mocks.__inCombat = false
  NS.Unlock:SetUnlocked(false)
  R:DeleteAll()
  Canvas:RenderAll()
end

-- ── Copy settings from another panel ────────────────────────────────────────────

test("Registry.CopyFrom: copies appearance across", function()
  fresh()
  local source = R:New("Source", {
    width = 500, height = 300, borderSize = 6, bgTexture = "None",
    accentEnabled = true, accentThickness = 9, mouseover = true, mouseoverAlpha = 0.3,
  })
  local target = R:New("Target")
  assertTrue((R:CopyFrom(target.id, source.id)))

  local after = R:Get(target.id)
  assertEqual(after.width, 500)
  assertEqual(after.height, 300)
  assertEqual(after.borderSize, 6)
  assertEqual(after.bgTexture, "None")
  assertTrue(after.accentEnabled)
  assertEqual(after.accentThickness, 9)
  assertTrue(after.mouseover)
  assertNear(after.mouseoverAlpha, 0.3)
end)

test("Registry.CopyFrom: does NOT copy position", function()
  fresh()
  local source = R:New("Source", { point = "TOPLEFT", relPoint = "TOPLEFT", x = 400, y = -200 })
  local target = R:New("Target", { point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT",
                                   x = -50, y = 50 })
  R:CopyFrom(target.id, source.id)

  local after = R:Get(target.id)
  -- The whole point of copying settings is to make this panel MATCH another while staying where it
  -- is. Copying position too would land the two exactly on top of each other.
  assertEqual(after.point, "BOTTOMRIGHT")
  assertEqual(after.relPoint, "BOTTOMRIGHT")
  assertEqual(after.x, -50)
  assertEqual(after.y, 50)
end)

test("Registry.CopyFrom: does NOT copy identity", function()
  fresh()
  local source = R:New("Source")
  local target = R:New("Target")
  local frameName = R.FrameName(target)
  R:CopyFrom(target.id, source.id)

  local after = R:Get(target.id)
  assertEqual(after.id, target.id)
  assertEqual(after.name, "Target")
  -- Identity surviving is what keeps external anchors attached.
  assertEqual(R.FrameName(after), frameName)
  -- And the source is untouched.
  assertEqual(R:Get(source.id).name, "Source")
end)

test("Registry.CopyFrom: DOES copy size", function()
  fresh()
  local source = R:New("Source", { width = 800, height = 40 })
  local target = R:New("Target")
  R:CopyFrom(target.id, source.id)
  -- Unlike position, matching dimensions is usually exactly what was wanted, and copying it cannot
  -- make either panel disappear.
  assertEqual(R:Get(target.id).width, 800)
  assertEqual(R:Get(target.id).height, 40)
end)

test("Registry.CopyFrom: colors are deep-copied, not shared", function()
  fresh()
  local source = R:New("Source", { bgColor = { 0.1, 0.2, 0.3, 1 } })
  local target = R:New("Target")
  R:CopyFrom(target.id, source.id)

  R:Get(target.id).bgColor[1] = 0.99
  -- A shared array would mean editing one panel's color silently changed the other's.
  assertNear(R:Get(source.id).bgColor[1], 0.1)
end)

test("Registry.CopyFrom: edge sets are deep-copied too", function()
  fresh()
  local source = R:New("Source", { accentEnabled = true,
                                   accentEdges = { TOP = true, LEFT = true } })
  local target = R:New("Target")
  R:CopyFrom(target.id, source.id)

  R:Get(target.id).accentEdges.BOTTOM = true
  assertEqual(R:Get(source.id).accentEdges.BOTTOM, nil)
end)

test("Registry.CopyFrom: refuses to copy from itself", function()
  fresh()
  local rec = R:New("Lonely")
  local ok, err = R:CopyFrom(rec.id, rec.id)
  assertFalse(ok)
  assertTrue(err:find("itself", 1, true) ~= nil)
end)

test("Registry.CopyFrom: an unknown panel on either side is an error", function()
  fresh()
  local rec = R:New("Real")
  assertFalse((R:CopyFrom(rec.id, "Ghost")))
  assertFalse((R:CopyFrom("Ghost", rec.id)))
end)

test("Registry.CopyFrom: reports the source's name on success", function()
  fresh()
  local source = R:New("Template Panel")
  local target = R:New("Target")
  local ok, name = R:CopyFrom(target.id, source.id)
  assertTrue(ok)
  assertEqual(name, "Template Panel")
end)

test("Registry.CopyFrom: repaints the target", function()
  fresh()
  local source = R:New("Source", { width = 700 })
  local target = R:New("Target")
  R:CopyFrom(target.id, source.id)
  assertEqual(Canvas:FrameFor(target.id):GetWidth(), 700)
end)

test("Registry.CopyFrom: the copy is sanitized", function()
  fresh()
  local source = R:New("Source")
  local target = R:New("Target")
  -- Reach past the write seam to plant a bad value, as an old or hand-edited profile could.
  R:Get(source.id).width = 99999
  R:CopyFrom(target.id, source.id)
  assertEqual(R:Get(target.id).width, C.MAX_SIZE)
end)

-- ── Profile switching ───────────────────────────────────────────────────────────

test("Database: profile callbacks are registered", function()
  -- Without these, switching profiles swaps db.profile wholesale and nothing ever looks at it
  -- again — the previous profile's panels would stay on screen forever.
  assertTrue(T.mocks.__db ~= nil, "the mock DB was never created")
  assertTrue(T.mocks.__switchProfile ~= nil)
end)

test("Database: switching profile re-renders the panels", function()
  fresh()
  local rec = R:New("In Profile A")
  assertTrue(Canvas:FrameFor(rec.id) ~= nil)

  T.mocks.__switchProfile("Other - Realm")

  -- The new profile is empty, so the old panel's frame must have been retired.
  assertEqual(R:Count(), 0)
  assertEqual(Canvas:FrameFor(rec.id), nil, "the old profile's panel stayed on screen")
  T.mocks.__switchProfile("Mock - Realm")
end)

test("Database: switching profile re-runs migrations on the incoming profile", function()
  fresh()
  T.mocks.__switchProfile("Other - Realm")
  -- The incoming profile may predate the current schema, and this is the first moment it is read.
  assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
  T.mocks.__switchProfile("Mock - Realm")
end)

test("Database: switching profile sanitizes the incoming records", function()
  fresh()
  T.mocks.__switchProfile("Other - Realm")
  local rec = R:New("Fresh")
  -- Plant a record missing a field a later build added, as a copied profile could carry.
  rec.accentThickness = nil
  NS.Registry:ReloadProfile()
  assertEqual(R:Get(rec.id).accentThickness, C.PANEL_TEMPLATE.accentThickness)
  R:DeleteAll()
  T.mocks.__switchProfile("Mock - Realm")
end)

test("Database: the profile reload goes through Registry, keeping one sender", function()
  -- architecture-§4: `PanelsChanged` must have exactly one sender. The reload lives in Registry
  -- rather than Database precisely so that stays true.
  local f = io.open("core/Database.lua", "r")
  local body = f:read("*a")
  f:close()
  assertEqual(body:find("SendMessage%s*%(%s*[\"']Ka0s_PanelMaster_Panel"), nil,
    "core/Database.lua sends a panel message directly")
  assertTrue(body:find("ReloadProfile", 1, true) ~= nil,
    "the profile callbacks do not delegate to the registry")
end)

-- ── The Profiles settings page ──────────────────────────────────────────────────

test("Panel: the Profiles subcategory is registered", function()
  assertTrue(T.mocks.__settingsPanels["Profiles"] ~= nil)
end)

test("Panel: Profiles registers AceDB's own options table", function()
  -- The page's whole contract. Reimplementing create/switch/copy/reset/delete by hand would only
  -- be distinguished by its own bugs.
  local registered = T.mocks.__profileOptions
  assertTrue(registered ~= nil, "no options table was registered")
  assertEqual(registered.name, "PanelMaster-Profiles")
  assertEqual(registered.opts.__db, NS.db, "the options table was not built from this addon's DB")
end)

test("Panel: the Profiles page carries the framework contract like every other", function()
  local panel = T.mocks.__settingsPanels["Profiles"]
  assertEqual(type(panel.OnCommit), "function")
  assertEqual(type(panel.OnRefresh), "function")
  assertEqual(type(panel.OnDefault), "function")
end)

test("Panel: the Profiles page has NO Defaults button", function()
  -- Profile management carries its own destructive controls; a second "reset" meaning something
  -- different from the page's own Reset Profile would be a trap.
  assertFalse(T.mocks.__settingsPanels["Profiles"].wantsDefaultsButton)
end)

test("Panel: the Profiles page builds lazily on OnShow", function()
  local panel = T.mocks.__settingsPanels["Profiles"]
  assertEqual(type(panel:GetScript("OnShow")), "function")
end)
