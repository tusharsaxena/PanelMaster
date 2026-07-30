-- Minimal WoW-API mock set for the headless unit tests. Returns a builder so each run gets a fresh,
-- isolated environment. Only what the addon touches at load/test time is stubbed.

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
-- stored position" and "we applied garbage" would look identical. SetPoint's overloads are modelled
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

local function stubFrame()
  local f = { __shown = true, __points = {}, __w = 0, __h = 0,
              __alpha = 1, __scripts = {}, __mouse = false }
  setmetatable(f, { __index = function(_, k)
    if k == "Show" then return function() f.__shown = true; return f end end
    if k == "Hide" then
      return function()
        local was = f.__shown
        f.__shown = false
        if was and f.__onHide then
          for _, fn in ipairs(f.__onHide) do fn(f) end
        end
        return f
      end
    end
    if k == "SetShown" then
      return function(_, v) if v then f:Show() else f:Hide() end; return f end
    end
    if k == "IsShown" or k == "IsVisible" then return function() return f.__shown end end
    if k == "HookScript" then
      return function(_, script, handler)
        if script == "OnHide" then
          f.__onHide = f.__onHide or {}
          f.__onHide[#f.__onHide + 1] = handler
        end
        return f
      end
    end
    -- Scripts are RECORDED rather than dropped: the drag handler and every panel OnShow are real
    -- behaviour, and a test that cannot invoke them can only assert that registration happened, not
    -- that the handler does the right thing.
    if k == "SetScript" then
      return function(_, script, handler) f.__scripts[script] = handler; return f end
    end
    if k == "GetScript" then return function(_, script) return f.__scripts[script] end end
    if k == "SetPoint" then
      return function(_, point, ...) f.__points[#f.__points + 1] = recordPoint(point, ...); return f end
    end
    if k == "ClearAllPoints" then
      return function() f.__points = {}; return f end
    end
    if k == "GetPoint" then
      return function(_, i)
        local p = f.__points[i or 1]
        if not p then return nil end
        return p.point, p.relativeTo, p.relativePoint, p.x, p.y
      end
    end
    if k == "GetNumPoints" then return function() return #f.__points end end
    if k == "SetSize" then return function(_, w, h) f.__w, f.__h = w, h; return f end end
    if k == "SetWidth" then return function(_, w) f.__w = w; return f end end
    if k == "SetHeight" then return function(_, h) f.__h = h; return f end end
    if k == "GetWidth" then return function() return f.__w end end
    if k == "GetHeight" then return function() return f.__h end end
    if k == "SetAlpha" then return function(_, a) f.__alpha = a; return f end end
    if k == "GetAlpha" then return function() return f.__alpha end end
    if k == "SetFrameStrata" then return function(_, s) f.__strata = s; return f end end
    if k == "GetFrameStrata" then return function() return f.__strata end end
    if k == "SetFrameLevel" then return function(_, l) f.__level = l; return f end end
    if k == "GetFrameLevel" then return function() return f.__level end end
    if k == "EnableMouse" then return function(_, v) f.__mouse = v and true or false; return f end end
    if k == "IsMouseEnabled" then return function() return f.__mouse end end
    -- Colour is the other half of "what does this panel look like", so a texture stub records what
    -- it was told to draw. Without this, every colour assertion would have to trust the code.
    if k == "SetColorTexture" then
      return function(_, r, g, b, a) f.__color = { r, g, b, a }; return f end
    end
    if k == "SetVertexColor" then
      return function(_, r, g, b, a) f.__color = { r, g, b, a }; return f end
    end
    if k == "SetText" then return function(_, t) f.__text = t; return f end end
    if k == "GetText" then return function() return f.__text end end
    if k == "GetName" then return function() return f.__name end end
    -- The backdrop the border is drawn with. Recorded rather than no-op'd: which edge texture and
    -- thickness a panel asked for is exactly what the LSM border tests assert on.
    if k == "SetBackdrop" then return function(_, b) f.__backdrop = b; return f end end
    if k == "GetBackdrop" then return function() return f.__backdrop end end
    if k == "SetBackdropBorderColor" then
      return function(_, r, g, b, a) f.__backdropBorderColor = { r, g, b, a }; return f end
    end
    if k == "SetTexture" then return function(_, path) f.__texture = path; return f end end
    if k == "GetTexture" then return function() return f.__texture end end
    -- Child regions are fresh stubs, not the parent: a texture that WAS the frame would make every
    -- edge share one colour slot and hide a whole class of border bug.
    if k == "CreateTexture" or k == "CreateFontString" then
      return function() return stubFrame() end
    end
    if type(k) == "string" and k:match("^%u") then
      return function() return f end
    end
    return nil
  end })
  return f
end

return function()
  local M = {}

  -- time / misc
  M.__now = 1785000000
  M.time = function() return M.__now end
  M.date = os.date
  M.GetTime = function() return M.__now end
  M.GetLocale = function() return "enUS" end
  M.strtrim = function(s) return (tostring(s):gsub("^%s*(.-)%s*$", "%1")) end
  M.C_Timer = { After = function() end }

  -- Combat state. Tests flip __inCombat to exercise the unlock deferral and the options-panel
  -- refusal, which are the two combat-shaped behaviours the addon has.
  M.__inCombat = false
  M.InCombatLockdown = function() return M.__inCombat end

  -- TOC metadata, so Sl:Version() resolves the packaged version rather than the in-code fallback.
  M.C_AddOns = {
    GetAddOnMetadata = function(_, field)
      if field == "Version" then return "0.1.0" end
      return nil
    end,
  }

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

  -- LibStub + Ace library mocks
  local libs = {}
  -- AceDB, including its CALLBACK surface. The callbacks are modelled rather than stubbed because
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

  -- AceGUI is present but hands back nothing: P:Register only needs the library to EXIST (the panel
  -- bodies are built lazily on first OnShow, which never fires headless), and every widget call site
  -- already guards on the create returning a usable widget. That is enough to exercise registration
  -- and the framework callback contract without modelling AceGUI's whole widget tree.
  libs["AceGUI-3.0"] = { Create = function() return nil end }

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

  -- Message bus modelled on CallbackHandler: callbacks keyed by (message, target). Registering the
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
        local handle = { callback = callback, delay = delay, cancelled = false }
        M.__timers[#M.__timers + 1] = handle
        return handle
      end
      target.CancelTimer = function(_, handle)
        if type(handle) == "table" then handle.cancelled = true end
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
      if not handle.cancelled then
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

  M.LibStub = setmetatable(
    { GetLibrary = function(_, n) return libs[n] end },
    { __call = function(_, n) return libs[n] end }
  )

  return M
end
