-- PanelMaster's WoW-API mock: an EXTENDER over the shared kit's tests/_kit/mock_base.lua, not a
-- replacement for it. Returns a builder so each run gets a fresh, isolated environment.
--
-- WHAT THE BASE GIVES US, and why it is worth extending rather than ignoring:
--   * a LibStub with a real NewLibrary, which is the only way the vendored libs/LibKa0s/*.lua
--     modules can register at all headlessly. Nothing else in this repo can supply that.
--   * a FIREABLE AceGUI-3.0 — widgets that record what was set on them and expose __fire, so the
--     schema → widget → write path is reachable. This addon's own mock handed back nil from
--     Create(), which made that whole path untestable; it is now driven for real.
--
-- WHAT WE OVERRIDE, and why each one is deliberate rather than laziness. The kit's own header names
-- the first as a divergence it knowingly keeps; the rest are PanelMaster-shaped and belong here by
-- the kit's stated scope rule ("what does not belong: anything only one addon calls").
--
--   1. stubFrame / CreateFrame / UIParent — the base's CreateTexture and CreateFontString answer
--      from the metatable and return THE FRAME ITSELF. This addon draws a background texture, a
--      border and up to four accent edges onto one frame and asserts each one's color, texture,
--      tex-coords and blend mode separately; aliasing them all onto the parent would collapse every
--      edge into one color slot and hide a whole class of border bug. The base also answers 0 from
--      GetWidth/GetHeight and models no points, and this addon's entire product is positions and
--      sizes that are persisted, snapped, restored and recovered.
--   2. Frames start SHOWN (the base starts them hidden) — 34 IsShown assertions sit on that, and a
--      real frame is shown unless something hides it.
--   3. AceDB-3.0 — this addon's suites drive __switchProfile / __db / __dbDefaultProfile, which
--      model AceDB's "swap db.profile wholesale, then fire" semantics.
--   4. AceAddon-3.0 — __badEvents (retail RAISES on an unknown event name), __chatCommands,
--      timers that can be canceled, and a Print mixin that RETURNS its string so the reclaim is
--      assertable.
--   5. AceEvent-3.0 + the bus — callbacks keyed by (message, target), so same-target clobbering
--      (architecture-§4) is catchable.
--   6. DEFAULT_CHAT_FRAME — a capture table feeding __chat. The base's is a plain stub frame whose
--      AddMessage no-ops, which would silence every chat assertion in the suite.
--   7. Settings — __settingsPanels / __openedCategory, the canvas-contract evidence (options-ui-§1).
--   8. C_AddOns and strtrim — both deliberately absent from the base. C_AddOns is re-added
--      knowingly: the kit warns a base-level stub would shadow tests/test_compat.lua's
--      `_G.C_AddOns = nil` swap, but that swap sets the GLOBAL while the loader env resolves mocks
--      first, so this addon's Compat fallback branch is driven through NS.Compat directly instead.
--   9. UnitClass (three returns, including the classID this addon reads), RAID_CLASS_COLORS,
--      MouseIsOver, BackdropTemplateMixin — none are in the base.
--  10. LibSharedMedia-3.0 stays ABSENT, as it is in the base: it is an OptionalDep and the addon
--      must run without it (library-stack-§6), so missing is the tested default.

local buildBase = dofile("tests/_kit/mock_base.lua")

local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k, v in pairs(t) do r[k] = deepcopy(v) end
  return r
end

-- A universal frame stub: any method call is a no-op that returns the frame itself. WoW frame API
-- methods are always PascalCase (SetPoint, CreateTexture, HookScript, …), so only those keys get a
-- no-op function; any other (lowercase/custom) field access misses through to nil, letting addon
-- code do `if not f.someCustomField then f.someCustomField = ... end` safely.
--
-- VISIBILITY is the one piece of frame state the stub really models. A blanket no-op makes IsShown()
-- return the frame — permanently truthy — so "the panel is hidden" is untestable and a panel that
-- never hides looks identical to one that does. Real frames start shown, and Show / Hide / SetShown
-- flip that flag, so the stub does too.
--
-- GEOMETRY is the other piece of real state. A panel's position and size are the whole product here
-- — they are persisted, restored, snapped and recovered — and a blanket no-op would make every one
-- of those round trips untestable: GetPoint() would hand back the frame itself, so "we applied the
-- stored position" and "we applied garbage" would look identical. SetPoint's overloads are modeled
-- because addon code uses both the (point, x, y) and (point, relativeTo, relativePoint, x, y) forms.
local function recordPoint(point, ...)
  local a, b, c, d = ...
  if type(a) == "number" or a == nil then
    -- (point) or (point, x, y)
    return { point = point, relativeTo = nil, relativePoint = point, x = a or 0, y = b or 0 }
  end
  -- (point, relativeTo, relativePoint[, x, y])
  return { point = point, relativeTo = a, relativePoint = b or point, x = c or 0, y = d or 0 }
end

-- Forward-declared: the method table below hands CreateTexture a FRESH stub, and it is built at file
-- load, before stubFrame's body exists.
local stubFrame

-- The three shapes almost every modeled method has, as factories over the state key they record.
-- Written once here so the two dozen recorders in METHOD are one line each and cannot drift apart.
-- A plain recorder: whatever was stored comes back, defaulting to nothing. Every value a renderer
-- can choose — 0 for a zero-thickness border, false for a flag it deliberately cleared — reads
-- back exactly as it was set, which is the bug these readers exist to make visible.
local function reader(key)
  return function(f)
    return function() return f[key] end
  end
end

local function writer(key)
  return function(f) return function(_, v) f[key] = v; return f end end
end

-- For the flags WoW itself coerces: a real frame's IsMouseEnabled answers a boolean whatever it was
-- handed, so a stub that stored a 1 would make an assertion on `true` fail against correct code.
local function boolWriter(key)
  return function(f) return function(_, v) f[key] = v and true or false; return f end end
end

local function rgbaWriter(key)
  return function(f) return function(_, r, g, b, a) f[key] = { r, g, b, a }; return f end end
end

-- Method name -> factory(f) -> the bound closure. Built ONCE at file load, so __index is a lookup
-- rather than a thirty-arm chain of string compares.
local METHOD = {}

METHOD.Show = function(f) return function() f.__shown = true; return f end end
METHOD.Hide = function(f)
  return function()
    local was = f.__shown
    f.__shown = false
    if was and f.__onHide then
      for _, fn in ipairs(f.__onHide) do fn(f) end
    end
    return f
  end
end
METHOD.SetShown = function(f)
  return function(_, v) if v then f:Show() else f:Hide() end; return f end
end
METHOD.IsShown = reader("__shown")
METHOD.IsVisible = METHOD.IsShown

METHOD.HookScript = function(f)
  return function(_, script, handler)
    if script == "OnHide" then
      f.__onHide = f.__onHide or {}
      f.__onHide[#f.__onHide + 1] = handler
    end
    return f
  end
end
-- Scripts are RECORDED rather than dropped: the drag handler and every panel OnShow are real
-- behavior, and a test that cannot invoke them can only assert that registration happened, not
-- that the handler does the right thing.
METHOD.SetScript = function(f)
  return function(_, script, handler) f.__scripts[script] = handler; return f end
end
METHOD.GetScript = function(f)
  return function(_, script) return f.__scripts[script] end
end

METHOD.SetPoint = function(f)
  return function(_, point, ...) f.__points[#f.__points + 1] = recordPoint(point, ...); return f end
end
METHOD.ClearAllPoints = function(f)
  return function() f.__points = {}; return f end
end
METHOD.GetPoint = function(f)
  return function(_, i)
    local p = f.__points[i or 1]
    if not p then return nil end
    return p.point, p.relativeTo, p.relativePoint, p.x, p.y
  end
end
METHOD.GetNumPoints = function(f) return function() return #f.__points end end

METHOD.SetSize = function(f) return function(_, w, h) f.__w, f.__h = w, h; return f end end
METHOD.SetWidth  = writer("__w")
METHOD.SetHeight = writer("__h")
METHOD.GetWidth  = reader("__w")
METHOD.GetHeight = reader("__h")
-- Recorded rather than swallowed, for the same reason as color and blend mode: a panel's own
-- scale is part of "what does this look like", and a blanket no-op would make a renderer that
-- never set one look identical to one that set it correctly. A frame nothing scaled reads 1.
METHOD.SetScale = writer("__scale")
-- The one reader with a default, and it keeps the `or` the hand-written shim used rather than an
-- `== nil` test. The two differ only for a stored `false`, and `or` is the behavior every existing
-- assertion was written against. Note that 0 is TRUTHY in Lua, so `f.__scale or 1` hands back a
-- recorded 0 untouched — only nil and false fall through to the 1.
METHOD.GetScale = function(f) return function() return f.__scale or 1 end end
METHOD.SetAlpha = writer("__alpha")
METHOD.GetAlpha = reader("__alpha")
METHOD.SetFrameStrata = writer("__strata")
METHOD.GetFrameStrata = reader("__strata")
METHOD.SetFrameLevel = writer("__level")
METHOD.GetFrameLevel = reader("__level")
METHOD.EnableMouse = boolWriter("__mouse")
METHOD.IsMouseEnabled = reader("__mouse")

-- Color is the other half of "what does this panel look like", so a texture stub records what
-- it was told to draw. Without this, every color assertion would have to trust the code.
METHOD.SetColorTexture = rgbaWriter("__color")
METHOD.SetVertexColor  = rgbaWriter("__color")

METHOD.SetText = writer("__text")
METHOD.GetText = reader("__text")
METHOD.GetName = reader("__name")

-- The backdrop the border is drawn with. Recorded rather than no-op'd: which edge texture and
-- thickness a panel asked for is exactly what the LSM border tests assert on.
METHOD.SetBackdrop = writer("__backdrop")
METHOD.GetBackdrop = reader("__backdrop")
METHOD.SetBackdropBorderColor = rgbaWriter("__backdropBorderColor")

-- The WRAP arguments are kept alongside the path, not dropped. Tiled artwork is the one thing
-- whose correctness lives entirely in them: a spec that computes coordinates past 1 but forgets
-- REPEAT clamps to the edge pixel and draws one smeared copy, and a path-only capture cannot
-- tell that apart from a correct tile.
METHOD.SetTexture = function(f)
  return function(_, path, wrapH, wrapV)
    f.__texture, f.__wrapH, f.__wrapV = path, wrapH, wrapV
    return f
  end
end
METHOD.GetTexture = reader("__texture")

-- The blend mode is part of "what does this look like" in the same way color is — ADD over a
-- dark panel is a glow and BLEND is not — so it is recorded rather than swallowed.
METHOD.SetBlendMode = writer("__blend")

-- Recorded because "artwork renders inside the panel's bounds" is asserted by asking whether the
-- art frame was ever told to clip. A stub cannot really clip anything, so the CALL is the only
-- evidence there is, and a blanket no-op would make a renderer that never asked look identical.
METHOD.SetClipsChildren = boolWriter("__clipsChildren")

-- Texture ORIENTATION, recorded for the same reason as color: which way a texture was rotated is
-- part of "what does this look like", and an accent bar on a vertical edge is drawn with the
-- 8-argument form. Stored as the flat 8-number list the caller passed, in SetTexCoord's own
-- UL, LL, UR, LR order, so a test asserts on exactly what the renderer said. The 4-argument
-- (crop) form is recorded too — nothing uses it today, but silently dropping it would make a
-- future crop look like no call at all.
METHOD.SetTexCoord = function(f)
  return function(_, ...) f.__texCoord = { ... }; return f end
end

-- Child regions are fresh stubs, not the parent: a texture that WAS the frame would make every
-- edge share one color slot and hide a whole class of border bug.
METHOD.CreateTexture = function() return function() return stubFrame() end end
METHOD.CreateFontString = METHOD.CreateTexture

function stubFrame()
  local f = { __shown = true, __points = {}, __w = 0, __h = 0,
              __alpha = 1, __scripts = {}, __mouse = false }
  setmetatable(f, { __index = function(_, k)
    local make = METHOD[k]
    if make then return make(f) end
    -- The PascalCase fall-through stays AFTER the table, and everything else is still nil: that
    -- lowercase miss is what lets addon code do `if not f.someCustomField then ... end` safely.
    if type(k) == "string" and k:match("^%u") then
      return function() return f end
    end
    return nil
  end })
  return f
end

return function()
  local M = buildBase()

  -- Override the base's frame stub wholesale (reason 1/2 in the header). Everything the base built
  -- with its own stubFrame — the AceGUI widget `frame` fields — keeps the base's, which is correct:
  -- no suite here asserts on those.
  M.__stubFrame = stubFrame

  -- time / misc
  M.__now = 1785000000
  M.time = function() return M.__now end
  M.date = os.date
  M.GetTime = function() return M.__now end
  M.GetLocale = function() return "enUS" end
  M.strtrim = function(s) return (tostring(s):gsub("^%s*(.-)%s*$", "%1")) end
  M.C_Timer = { After = function() end }

  -- Combat state. Tests flip __inCombat to exercise the unlock deferral and the options-panel
  -- refusal, which are the two combat-shaped behaviors the addon has.
  M.__inCombat = false
  M.InCombatLockdown = function() return M.__inCombat end

  -- TOC metadata, so Sl:Version() resolves the packaged version rather than the in-code fallback.
  -- The installed-addon roster, which the Sunn adapter reads to answer "is this pack's folder on
  -- disk", including for addons the player has DISABLED. Driven per case through `M.__addons`.
  --
  -- Three states, not two, because the addon code distinguishes three. A LIST is a readable roster
  -- holding exactly those folders; an empty list is a readable roster holding none; and NIL means
  -- the roster cannot be read at all, which is a real client state and the one Compat.AddOnFolders
  -- answers nil to.
  --
  -- The default is the EMPTY LIST, and that matters at bootstrap rather than in any one case: the
  -- addon injects the Sunn catalog rows from its own OnEnable, before a suite has run a line. A nil
  -- default would make that injection read "cannot tell", offer all 88 manifest themes, and leave
  -- them in the shared catalog for every bundled-artwork assertion in test_artwork.lua to trip over.
  M.__addons = {}
  M.C_AddOns = {
    GetAddOnMetadata = function(_, field)
      if field == "Version" then return "1.0.0" end
      return nil
    end,
    -- nil rather than 0 when the roster is unset: Compat.AddOnFolders guards on `tonumber(count())`
    -- and returns nil from it, which is how "cannot tell" reaches the adapter. Returning 0 here
    -- would claim a readable, empty roster and quietly test the wrong branch.
    GetNumAddOns = function() return M.__addons and #M.__addons or nil end,
    -- The real signature returns name, title, notes, loadable, reason, security — this mock
    -- supplies the first two, which is all the adapter reads.
    GetAddOnInfo = function(i)
      local name = M.__addons and M.__addons[i]
      if not name then return nil end
      return name, name
    end,
  }

  -- The client's own default face, and the one real global this mock has to plant in _G rather than
  -- answer from the mock table. core/Constants.lua spells it `_G.STANDARD_TEXT_FONT` — the form the
  -- collection uses for a global it reads once at load — and `_G` inside a sandboxed chunk is the
  -- real global table, which the mock's __index never sees. It is the fallback the whole font ladder
  -- rests on: a degraded install has no payload and therefore no JetBrains Mono, and SetFont given a
  -- path to a file that is not there draws nothing at all. Guarded so a host that already defines it
  -- keeps its own value.
  _G.STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
  M.STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT

  -- UI. UIParent carries a REAL size: the off-screen recovery measures against it, and a 0×0 screen
  -- would make Compat.GetScreenSize return nil and silently skip every recovery test.
  M.UIParent = stubFrame()
  M.UIParent:SetSize(1920, 1080)
  -- The frame NAME is recorded, because it is part of this addon's public contract: every panel
  -- frame is created as `PanelMaster_Panel_<slug>` for other addons to anchor to, and a stub that
  -- dropped the argument would make that untestable.
  M.CreateFrame = function(_, name)
    local f = stubFrame()
    f.__name = name
    return f
  end
  M.MouseIsOver = function(frame) return M.__mouseIsOver == frame end
  M.__mouseIsOver = nil
  M.UnitClass = function() return "Priest", "PRIEST", 5 end
  M.RAID_CLASS_COLORS = {
    PRIEST = { r = 1.00, g = 1.00, b = 1.00 },
    MAGE   = { r = 0.25, g = 0.78, b = 0.92 },
  }
  M.UISpecialFrames = {}
  M.BackdropTemplateMixin = {}
  M.StaticPopupDialogs = {}
  M.__popupsShown = {}
  M.StaticPopup_Show = function(name) M.__popupsShown[#M.__popupsShown + 1] = name end

  -- Chat sink for NS.Print (core/Util.lua). Records every line, so the CLI's output shape is
  -- assertable without stubbing the printer itself.
  M.__chat = {}
  M.DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, msg) M.__chat[#M.__chat + 1] = msg end,
  }

  -- Every canvas frame handed to the Settings framework, keyed by the name it was registered under.
  -- options-ui-§1 makes the frame's OnCommit/OnDefault/OnRefresh a contract with Blizzard, and the
  -- only way to assert on a contract is to keep what was actually handed over.
  M.__settingsPanels = {}
  M.__openedCategory = nil
  M.Settings = {
    RegisterCanvasLayoutCategory = function(panel, name)
      M.__settingsPanels[name] = panel
      return { GetID = function() return 1 end }
    end,
    RegisterCanvasLayoutSubcategory = function(_, panel, name)
      M.__settingsPanels[name] = panel
      return { GetID = function() return 2 end }
    end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function(id) M.__openedCategory = id end,
  }

  -- Ace library fakes. Registered INTO the base's own table (M.__libs) rather than a private one,
  -- because the base's LibStub closes over that table — and the base's LibStub is the one thing
  -- here that cannot be replaced: it carries the real NewLibrary the vendored LibKa0s modules
  -- register through. A private table would leave them registered nowhere.
  local libs = M.__libs
  -- AceDB, including its CALLBACK surface. The callbacks are modeled rather than stubbed because
  -- switching profiles swaps `db.profile` wholesale — if the addon does not react, the previous
  -- profile's panels stay on screen. `__switchProfile` reproduces exactly that: replace the table,
  -- then fire, which is what AceDB does.
  M.__profileName = nil
  M.__dbDefaultProfile = nil
  libs["AceDB-3.0"] = {
    New = function(_, _name, defaults, defaultProfile)
      local db
      local callbacks = {}
      -- AceDB's own rule, reproduced: `true` maps to the shared "Default" profile, a string is used
      -- verbatim, and nothing at all falls back to the character key. Recorded so a test can assert
      -- which of those the addon actually asked for — "every character starts on Default" is a
      -- product decision a stub returning a fixed name would quietly hide.
      M.__dbDefaultProfile = defaultProfile
      M.__profileName = (defaultProfile == true and "Default")
        or (type(defaultProfile) == "string" and defaultProfile)
        or "Mock - Realm"
      db = {
        global  = deepcopy(defaults and defaults.global or {}),
        profile = deepcopy(defaults and defaults.profile or {}),
        GetCurrentProfile = function() return M.__profileName end,
        RegisterCallback = function(target, event, fn)
          callbacks[event] = callbacks[event] or {}
          callbacks[event][target] = fn
        end,
        __fire = function(event, ...)
          for target, fn in pairs(callbacks[event] or {}) do fn(target, ...) end
        end,
      }
      -- Swap to a named profile the way AceDB does: a fresh defaults-shaped table, then the event.
      M.__switchProfile = function(name)
        M.__profileName = name
        db.profile = deepcopy(defaults and defaults.profile or {})
        db.__fire("OnProfileChanged", db, name)
      end
      M.__db = db
      return db
    end,
  }

  -- AceGUI-3.0 is the BASE's, deliberately left untouched. It used to be a dead end here
  -- (`Create = function() return nil end`) on the reasoning that panel bodies build lazily on an
  -- OnShow that never fires headless — which was true, and which is exactly why the whole
  -- schema → widget → write path had no coverage at all. The kit's widgets record what was set on
  -- them and expose __fire, so a test can fire an OnShow and then drive OnValueChanged the way a
  -- real click does.

  -- AceConfig / AceDBOptions back the Profiles page. Present so P:Register exercises the real
  -- registration path; `__profileOptions` records what was handed over, since "we registered AceDB's
  -- own options table" is the entire contract of that page.
  M.__profileOptions = nil
  libs["AceDBOptions-3.0"] = {
    GetOptionsTable = function(_, db) return { type = "group", args = {}, __db = db } end,
  }
  libs["AceConfig-3.0"] = {
    RegisterOptionsTable = function(_, name, opts) M.__profileOptions = { name = name, opts = opts } end,
  }
  M.__profileDialogOpens = 0
  libs["AceConfigDialog-3.0"] = {
    Open = function() M.__profileDialogOpens = M.__profileDialogOpens + 1 end,
  }

  -- LibSharedMedia is deliberately ABSENT from this table. It is an OptionalDep, and the addon must
  -- run without it (library-stack-§6) — so the default headless environment is the one where it is
  -- missing, which is what makes Compat.FetchTexture's nil path the tested path.

  -- Message bus modeled on CallbackHandler: callbacks keyed by (message, target). Registering the
  -- same message twice on ONE target overwrites (only the last survives); SendMessage fires to every
  -- distinct target. Mirroring the real semantics is what lets a test catch same-target clobbering
  -- (architecture-§4) — a bare no-op mock hides that whole bug class.
  local msgRegistry = {}
  M.__msgRegistry = msgRegistry
  local function embedBus(obj)
    obj.RegisterMessage = function(self, event, fn)
      msgRegistry[event] = msgRegistry[event] or {}
      msgRegistry[event][self] = fn
    end
    obj.UnregisterMessage = function(self, event)
      if msgRegistry[event] then msgRegistry[event][self] = nil end
    end
    obj.SendMessage = function(_, event, ...)
      local t = msgRegistry[event]
      if not t then return end
      for _, fn in pairs(t) do fn(event, ...) end
    end
    return obj
  end

  M.__events = {}
  libs["AceAddon-3.0"] = {
    NewAddon = function(_, target)
      target = target or {}
      local noop = function() end
      -- Modern retail RAISES on an unknown event name instead of ignoring it. Tests put names in
      -- M.__badEvents to reproduce that; a mock that silently accepted everything would hide the
      -- entire failure mode (a single retired event name unregisters the whole addon).
      target.RegisterEvent = function(_, event, handler)
        if M.__badEvents[event] then
          error("Attempt to register unknown event: " .. tostring(event), 2)
        end
        M.__events[event] = handler or true
      end
      target.UnregisterEvent = noop
      target.RegisterChatCommand = function(_, cmd) M.__chatCommands[cmd] = true end
      target.ScheduleTimer = function(_, callback, delay)
        local handle = { callback = callback, delay = delay, canceled = false }
        M.__timers[#M.__timers + 1] = handle
        return handle
      end
      target.CancelTimer = function(_, handle)
        if type(handle) == "table" then handle.canceled = true end
      end
      -- AceConsole's :Print mixin, reproduced faithfully: embedding it CLOBBERS a same-named custom
      -- NS.Print, and renders "|cff33ff99<msg>|r:" (green, trailing colon, no cyan tag). The addon
      -- reclaims its own printer right after NewAddon; without this stamp the test suite would never
      -- exercise that reclaim (architecture-§2, anti-pattern #36).
      target.Print = function(self) return "|cff33ff99" .. tostring(self) .. "|r:" end
      return embedBus(target)
    end,
  }
  M.__badEvents = {}
  M.__chatCommands = {}
  M.__timers = {}
  M.__fireTimers = function()
    local due = M.__timers
    M.__timers = {}
    local fired = 0
    for _, handle in ipairs(due) do
      if not handle.canceled then
        fired = fired + 1
        handle.callback()
      end
    end
    return fired
  end

  libs["AceEvent-3.0"] = {
    Embed = function(_, obj)
      obj.RegisterEvent = obj.RegisterEvent or function() end
      obj.UnregisterEvent = obj.UnregisterEvent or function() end
      return embedBus(obj)
    end,
  }

  -- M.LibStub is the BASE's and is deliberately NOT replaced. Two reasons, both load-bearing:
  --   * it implements NewLibrary with minor tracking, which is how libs/LibKa0s/*.lua register for
  --     real headlessly — exactly as they do in the client;
  --   * it is STRICT about the silent flag, matching the real LibStub. A lookup written without
  --     `, true` now raises instead of resolving to nil, so a soft-optional lookup that forgot the
  --     flag fails here rather than in the client.

  return M
end
