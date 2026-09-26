local T = _G.PM_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local R, U, S, Canvas, D = NS.Registry, NS.Unlock, NS.Schema, NS.Canvas, NS.DebugLog
local C = NS.Constants

-- tests/test_diagnostics.lua -- this addon's half of the diagnostics report (debug-logging-§14,
-- DX-PM): the sections modules/Diagnostics.lua hands the library.
--
-- WHAT IS NOT HERE, AND WHERE IT IS. The dispatcher half of the rule -- both slash forms, both of
-- them while disabled, the append, the ungated sink, the markers and `diag`/`dump` not running the
-- report -- is the kit's shared case, tests/_kit/test_diagnostics_contract.lua, run against this
-- addon's own dispatcher through `Kit.diagnostics` in tests/run.lua. The report's plumbing (the
-- markers, the cap and its reserve, the pcall per section, the escape strip) is the library's and
-- is tested in LibKa0s's own suite. What this file owns is what the sections READ and that they
-- only ever read.

-- The same stand-in for a combat secret the library's own suite uses: `..` succeeds on it and
-- table.concat raises, which is the pair of behaviors Core's SafeToString probes for.
local secretMock = setmetatable({}, { __concat = function() return "secret-propagated" end })

local function fresh()
  mocks.__inCombat = false
  U:SetUnlocked(false)
  S:Set(S.ENABLED_PATH, true)
  R:DeleteAll()
  Canvas:RenderAll()
end

--- The report as its message texts, in order, and the library's data table.
local function report(spec)
  local data = D:BuildDiagnostics(spec)
  local texts = {}
  for i, line in ipairs(data.lines) do texts[i] = line[2] end
  return texts, data
end

--- The first line holding `needle`, as (index, text), or nil.
local function find(texts, needle)
  for i, text in ipairs(texts) do
    if text:find(needle, 1, true) then return i, text end
  end
  return nil
end

local function count(texts, needle)
  local n = 0
  for _, text in ipairs(texts) do
    if text:find(needle, 1, true) then n = n + 1 end
  end
  return n
end

--- Run `fn`, then `restore`, whatever `fn` did; re-raise its error afterwards.
local function guarded(fn, restore)
  local ok, err = pcall(fn)
  restore()
  if not ok then error(err, 0) end
end

-- ── the frame of the report ────────────────────────────────────────────────────

test("Diagnostics: the report carries the brand and this addon's sections, in order", function()
  fresh()
  local texts, data = report()
  assertEqual(texts[1], "==== Ka0s Panel Master diagnostics begin ====")
  assertTrue(texts[#texts]:find("^==== Ka0s Panel Master diagnostics end: %d+ line%(s%) ====$") ~= nil,
    "the last line is not the branded end marker: " .. tostring(texts[#texts]))
  assertEqual(data.dropped, 0, "an empty profile's report hit the cap")
  local names = {}
  for i, section in ipairs(NS.Diagnostics.Sections()) do names[i] = section[1] end
  assertEqual(table.concat(names, ","),
    "state,master,unlock queue,settings,screen,panels,frames,mouseover,artwork,events")
end)

test("Diagnostics: the identity section names the schema, the profile, the switch and the latch",
  function()
    fresh()
    local texts = report()
    assertTrue(find(texts, NS.InitSummary()) ~= nil, "the library header lost the init summary")
    assertTrue(find(texts, ("schema: stored=%s code=%s"):format(
      tostring(NS.db.global.schemaVersion), tostring(NS.SCHEMA_VERSION))) ~= nil)
    assertTrue(find(texts, "profile: " .. NS.db:GetCurrentProfile()) ~= nil)
    assertTrue(find(texts, "enabled (stored)=true stood down=false") ~= nil)
    assertTrue(find(texts, "lifecycle holds: -") ~= nil, "an enabled addon reported a hold")
    assertTrue(find(texts, "test mode: none") ~= nil)
  end)

test("Diagnostics: stood down, every section still runs and the renderer says it is stood down",
  function()
    -- debug-logging-§14 / STD-05: a report taken while disabled is the report a player needs most,
    -- so nothing is skipped; the runtime half says what state it is in instead of printing nothing.
    fresh()
    R:New("Held")
    S:Set(S.ENABLED_PATH, false)
    guarded(function()
      local texts = report()
      assertTrue(find(texts, "enabled (stored)=false stood down=true") ~= nil)
      assertTrue(find(texts, "lifecycle holds: -") == nil, "a stood-down addon reported no hold")
      assertTrue(find(texts, "'Held'") ~= nil, "the records were skipped while stood down")
      assertTrue(find(texts, "renderer: stood down") ~= nil)
      assertTrue(find(texts, "rejected events") ~= nil, "a later section did not run")
    end, function() S:Set(S.ENABLED_PATH, true) end)
  end)

-- ── the master switches, the unlock state and the settings ───────────────────────

test("Diagnostics: the master switches and the individually unlocked panels", function()
  fresh()
  local rec = R:New("Loose")
  U:SetPanelUnlocked(rec.id, true)
  guarded(function()
    local texts = report()
    assertTrue(find(texts, "master: enabled=true visibility=always alpha=1 scale=1") ~= nil)
    assertTrue(find(texts, "unlock: global=false") ~= nil)
    assertTrue(find(texts, "unlocked panels: " .. rec.id) ~= nil)
  end, function() U:SetPanelUnlocked(rec.id, false) end)
end)

test("Diagnostics: the combat unlock queue is reported and left exactly as it was", function()
  fresh()
  local rec = R:New("Queued")
  mocks.__inCombat = true
  U:SetUnlocked(true)
  U:SetPanelUnlocked(rec.id, true)
  guarded(function()
    local texts = report()
    assertTrue(find(texts, "unlock queue: global=true") ~= nil)
    assertTrue(find(texts, "queued panels: " .. rec.id) ~= nil)
    -- red under: a section that replays or clears the queue it reports
    assertTrue(U.__hasPending(), "reading the report flushed the queued global unlock")
    assertTrue(U.__hasPending(rec.id), "reading the report flushed the queued panel unlock")
    assertFalse(NS.State.unlocked, "reading the report applied the queued unlock")
  end, function()
    mocks.__inCombat = false
    U:SetUnlocked(false)
  end)
end)

test("Diagnostics: settings print only where they differ, plus the two always-print rows", function()
  fresh()
  S:Set("settings.gridSize", 16)
  guarded(function()
    local texts = report()
    assertTrue(find(texts, "settings.gridSize = 16 (4)") ~= nil)
    assertTrue(find(texts, "settings.enabled = true (true)") ~= nil, "the always-print row is missing")
    assertTrue(find(texts, "state.locked = true (session-only)") ~= nil)
    assertEqual(find(texts, "settings.snapToGrid ="), nil, "a row at its default was printed")
  end, function() S:Set("settings.gridSize", 4) end)
end)

-- ── per panel ──────────────────────────────────────────────────────────────────

test("Diagnostics: each panel prints its id, name, frame name and what differs from the template",
  function()
    fresh()
    local rec = R:New("Inspected")
    R:Set(rec.id, "width", 300)
    local texts = report()
    assertTrue(find(texts, ("[%s] 'Inspected' enabled=true frame=PanelMaster_Panel_Inspected")
      :format(rec.id)) ~= nil)
    local _, diff = find(texts, "differs from template:")
    assertTrue(diff ~= nil and diff:find("width=300", 1, true) ~= nil, tostring(diff))
    assertEqual(diff:find("height=", 1, true), nil, "a field at its template value was printed")
    assertEqual(diff:find("name=", 1, true), nil, "the name is on the line above, not a diff")
  end)

test("Diagnostics: a live frame that drifted from its record is flagged", function()
  fresh()
  local rec = R:New("Drifted")
  local _, line = find(report(), "renderer:")
  assertTrue(line ~= nil and line:find("match=yes", 1, true) ~= nil, tostring(line))
  Canvas:FrameFor(rec.id):SetWidth(999)
  guarded(function()
    _, line = find(report(), "renderer:")
    assertTrue(line:find("live 999x120", 1, true) ~= nil, line)
    assertTrue(line:find("record 240x120", 1, true) ~= nil, line)
    assertTrue(line:find("match=NO", 1, true) ~= nil, line)
  end, function() Canvas:RenderAll() end)
end)

test("Diagnostics: the alpha line compares the live alpha with the mouseover target", function()
  fresh()
  R:New("Faded", { mouseover = true, mouseoverAlpha = 0.25 })
  local _, line = find(report(), "alpha: live=")
  assertTrue(line ~= nil, "no alpha line")
  assertTrue(line:find("live=0.25 target=1 floor=0.25 mouseover=true tracked=true match=yes", 1, true)
    ~= nil, line)
end)

test("Diagnostics: an anchor beyond the screen edge is flagged off-screen, without moving it",
  function()
    fresh()
    local rec = R:New("Lost")
    local live = R:Get(rec.id)
    local _, line = find(report(), "position:")
    assertTrue(line ~= nil and line:find("offscreen=no", 1, true) ~= nil, tostring(line))
    live.x = 99999
    guarded(function()
      _, line = find(report(), "position:")
      assertTrue(line:find("offscreen=yes", 1, true) ~= nil, line)
      -- red under: a section that calls R:Recover to find out
      assertEqual(live.x, 99999, "the report moved the panel it flagged")
    end, function() live.x = 0 end)
  end)

test("Diagnostics: media names report how they resolved, and the fallback when they did not",
  function()
    fresh()
    local rec = R:New("Media")
    local _, line = find(report(), "media:")
    assertTrue(line ~= nil and line:find("bgTexture=Solid (no LSM -> Solid)", 1, true) ~= nil,
      tostring(line))

    local live = R:Get(rec.id)
    mocks.__libs["LibSharedMedia-3.0"] = {
      Fetch = function(_, _, name) if name == "Solid" then return "Interface\\Solid" end end,
    }
    live.bgTexture, live.borderTexture = "Gone", C.NONE_MEDIA_NAME
    guarded(function()
      _, line = find(report(), "media:")
      assertTrue(line:find("bgTexture=Gone (missing -> Solid)", 1, true) ~= nil, line)
      assertTrue(line:find("borderTexture=None (none)", 1, true) ~= nil, line)
      assertTrue(line:find("accentBorderTexture=Solid (ok)", 1, true) ~= nil, line)
    end, function()
      mocks.__libs["LibSharedMedia-3.0"] = nil
      live.bgTexture, live.borderTexture = "Solid", "Solid"
    end)
  end)

test("Diagnostics: artwork prints a custom path verbatim and a vanished catalog id as such",
  function()
    fresh()
    local rec = R:New("Arty")
    assertTrue(find(report(), "art: none") ~= nil)
    local live = R:Get(rec.id)
    live.artTexture, live.artCustomPath = C.ARTWORK_CUSTOM, "Interface\\AddOns\\MyArt\\sigil.tga"
    guarded(function()
      local _, line = find(report(), "art: custom")
      assertTrue(line ~= nil and line:find("path=Interface\\AddOns\\MyArt\\sigil.tga", 1, true) ~= nil,
        tostring(line))
      assertTrue(line:find("resolved=yes", 1, true) ~= nil, line)
      live.artTexture = "no-such-art"
      _, line = find(report(), "art: no-such-art")
      assertTrue(line ~= nil and line:find("catalog=NO", 1, true) ~= nil, tostring(line))
      assertTrue(line:find("quads=0", 1, true) ~= nil, line)
    end, function() live.artTexture = C.ARTWORK_NONE end)
  end)

-- ── the renderer's own state ───────────────────────────────────────────────────

test("Diagnostics: frames count active, pooled and orphaned", function()
  fresh()
  R:New("Counted")
  R:New("Tallied")
  -- The pool count is how you tell a leak from healthy reuse, and a frame with no record IS the
  -- leak. The orphan is made the way a leak is: the record is lifted straight out of the array
  -- Registry owns, leaving Canvas still holding its frame.
  local pooled = Canvas.PooledCount()
  assertTrue(find(report(), ("frames: 2 active, %d pooled, 0 orphaned"):format(pooled)) ~= nil)
  local records = R:All()
  local stolen = table.remove(records)
  guarded(function()
    assertTrue(find(report(), ("frames: 2 active, %d pooled, 1 orphaned"):format(pooled)) ~= nil,
      "an orphaned frame is not counted")
  end, function()
    records[#records + 1] = stolen
    R:DeleteAll()
  end)
end)

test("Diagnostics: the mouseover ticker reports what it tracks and whether it is running", function()
  fresh()
  assertTrue(find(report(), "mouseover: tracked=0 ticker=off") ~= nil)
  R:New("Hover", { mouseover = true })
  assertTrue(find(report(), "mouseover: tracked=1 ticker=on") ~= nil)
end)

test("Diagnostics: the artwork catalog and the Sunn packs are counted", function()
  fresh()
  local texts = report()
  assertTrue(find(texts, ("artwork catalog: %d rows, 0 from Sunn packs"):format(#NS.Artwork.Catalog))
    ~= nil)
  assertTrue(find(texts, "sunn themes installed: 0") ~= nil)
end)

test("Diagnostics: the rejected-events record reads 0 rather than going quiet", function()
  fresh()
  local saved = {}
  for i, name in ipairs(NS.State.rejectedEvents) do saved[i] = name end
  for i = #NS.State.rejectedEvents, 1, -1 do NS.State.rejectedEvents[i] = nil end
  guarded(function()
    assertTrue(find(report(), "rejected events (0): -") ~= nil)
  end, function()
    for i, name in ipairs(saved) do NS.State.rejectedEvents[i] = name end
  end)
end)

-- ── the failure rules (STD-12, STD-15) ──────────────────────────────────────────

test("Diagnostics: a raising section costs exactly one line and the report goes on", function()
  fresh()
  local saved = U.PendingSnapshot
  U.PendingSnapshot = function() error("boom", 0) end
  guarded(function()
    local texts = report()
    -- red under: sections run in one pcall between them, where one raise costs every later section
    assertEqual(count(texts, "failed:"), 1)
    assertTrue(find(texts, "section unlock queue failed: boom") ~= nil)
    assertTrue(find(texts, "rejected events") ~= nil, "the sections after the raise did not run")
  end, function() U.PendingSnapshot = saved end)
end)

test("Diagnostics: one panel that raises costs one line, and the next panel still prints", function()
  fresh()
  local a = R:New("Broken")
  R:New("Healthy")
  local f = Canvas:FrameFor(a.id)
  f.GetPoint = function() error("bad frame", 0) end
  guarded(function()
    local texts = report()
    assertEqual(count(texts, "failed:"), 1)
    assertTrue(find(texts, ("section panel %s failed: bad frame"):format(a.id)) ~= nil)
    assertTrue(find(texts, "'Healthy'") ~= nil, "the panel after the raise did not print")
  end, function() f.GetPoint = nil end)
end)

test("Diagnostics: an over-cap report ends in the truncated line, then the end marker", function()
  fresh()
  for i = 1, 5 do R:New("Capped" .. i) end
  local texts, data = report({ maxLines = 12 })
  assertEqual(#texts, 12)
  assertTrue(data.dropped > 0)
  assertTrue(texts[11]:find("^truncated: %d+ line%(s%) omitted, per%-list caps hit=no$") ~= nil,
    texts[11])
  assertTrue(texts[12]:find("diagnostics end: 12 line(s)", 1, true) ~= nil, texts[12])
end)

test("Diagnostics: a secret value reads as <secret> and raises nothing", function()
  fresh()
  local rec = R:New("Secret")
  local f = Canvas:FrameFor(rec.id)
  f.GetAlpha = function() return secretMock end
  f.GetWidth = function() return secretMock end
  guarded(function()
    local texts = report()
    -- red under: arithmetic or a comparison on a value the section never proved readable
    assertEqual(count(texts, "failed"), 0, "a section raised on a secret value")
    local _, line = find(texts, "alpha: live=")
    assertTrue(line ~= nil and line:find("live=<secret>", 1, true) ~= nil, tostring(line))
    _, line = find(texts, "renderer:")
    assertTrue(line:find("live <secret>x120", 1, true) ~= nil, line)
  end, function() f.GetAlpha, f.GetWidth = nil, nil end)
end)

-- ── read-only ──────────────────────────────────────────────────────────────────

test("Diagnostics: running the report writes no setting, moves no frame and repairs nothing",
  function()
    -- DX-PM's "never" list: R:Recover, FitToArtwork, SetPoint, Show, flushing the unlock queue.
    fresh()
    local rec = R:New("Still")
    R:New("Other", { mouseover = true })
    local before = NS.Util.DeepCopy(NS.db.profile)
    local f = Canvas:FrameFor(rec.id)
    local points = f:GetNumPoints()

    local calls = {}
    local wrapped = {}
    local function watch(owner, key, label)
      local original = owner[key]
      wrapped[#wrapped + 1] = { owner, key, original }
      owner[key] = function(...)
        calls[#calls + 1] = label
        return original(...)
      end
    end
    watch(R, "Recover", "R:Recover")
    watch(R, "FitToArtwork", "R:FitToArtwork")
    watch(R, "Set", "R:Set")
    watch(Canvas, "Render", "Canvas:Render")
    watch(Canvas, "RenderAll", "Canvas:RenderAll")
    watch(U, "ResumePending", "U:ResumePending")
    watch(U, "SetUnlocked", "U:SetUnlocked")
    watch(S, "Set", "S:Set")
    guarded(function()
      D:RunDiagnostics()
      assertEqual(table.concat(calls, ", "), "", "the report called a writer")
      assertTrue(NS.Util.DeepEqual(before, NS.db.profile), "the report wrote the profile")
      assertEqual(f:GetNumPoints(), points, "the report re-anchored a panel frame")
    end, function()
      for i = #wrapped, 1, -1 do
        local w = wrapped[i]
        w[1][w[2]] = w[3]
      end
      D:Hide()
    end)
  end)

test("Diagnostics: /pm debug dump is an ordinary unknown word now, and toggles the window", function()
  -- The retired name (Q7(a)): no hint, no special case, so it takes the fallback every unknown
  -- `debug` word takes, which in this addon is the window toggle.
  fresh()
  D:Hide()
  local before = #D.buffer
  NS.Slash:OnSlash("debug dump")
  guarded(function()
    assertTrue(D:IsShown(), "`debug dump` did not fall through to the window toggle")
    for i = before + 1, #D.buffer do
      assertEqual(D.buffer[i]:find("diagnostics begin", 1, true), nil, "`debug dump` ran the report")
    end
  end, function() D:Hide() end)
end)
