local addonName, NS = ...

-- LibKa0s-DebugLog-1.0 seam: the on-screen debug console (debug-logging).
--
-- This replaces modules/DebugLog.lua, which was 429 lines of a window the Ka0s standard already
-- specifies down to the hex codes — the seventh hand-transcribed copy of it in the collection. Both
-- formatters were already byte-identical to the library's, and the frame globals the descriptor
-- generates from `name` are exactly the two this addon hardcoded, so the console a user sees is the
-- same window with the same buffer, the same 500-line cap and the same title.
--
-- WHERE THIS FILE SITS: after core/CoreSetup.lua (NS.LIBKA0S_MISSING) and after core/Constants.lua
-- (C.FONT_MONO). Nothing else pins it. Every other thing the descriptor touches — NS.State,
-- NS.InitSummary, NS.Panel, NS.Registry, NS.Canvas, NS.Unlock — is reached through a CLOSURE and
-- therefore resolved at call time, which is what lets the console move out of modules/ and up into
-- core/ without inverting a single dependency. Nothing anywhere captures NS.Debug, NS.DebugBuild or
-- NS.DebugLog as a load-time upvalue, so there is no ordering hazard below this file either.

local C = NS.Constants

local UNAVAILABLE = NS.LIBKA0S_MISSING .. ", so the debug console window is unavailable."

-- ── Diagnose: the structured dump verb (debug-logging-§4) ──────────────────────
--
-- No library equivalent, and there should not be one: it reports what THIS addon believes is on
-- screen right now. Attached to the instance on BOTH paths below, because it reads the addon's own
-- state and has nothing to do with whether a console window exists — `/pm debug dump` answers in a
-- degraded install too.
--
-- The registry's view and the renderer's view are printed together on purpose: a panel that is in
-- the registry but has no frame (or the reverse) is the exact shape of every rendering bug this
-- addon can have. Everything is resolved at CALL time, which is what lets this file sit in core/.
--
-- The three writers below — addHeader, addPanel, addFrames — are file-local rather than nested
-- inside attachDiagnose: they capture nothing, so hoisting them means they are built once at load
-- rather than once per attachDiagnose call — and attachDiagnose runs on the library path OR the
-- degraded one. Each still resolves every module through NS at CALL time, which is the property
-- that lets this file sit in core/.

-- The two lines describing the addon's own switches and the screen they are drawn on.
local function addHeader(add)
  local settings = (NS.db and NS.db.profile and NS.db.profile.settings) or {}
  add("master=%s unlocked=%s preview=%s snap=%s/%s",
    tostring(settings.enabled), tostring(NS.State.unlocked), tostring(NS.State.preview),
    tostring(settings.snapToGrid), tostring(settings.gridSize))

  local w, h = NS.Compat.GetScreenSize()
  add("screen=%s x %s scale=%s", tostring(w), tostring(h), tostring(NS.Compat.GetUIScale()))
end

-- One record, as two lines: its geometry, and its identity plus the media it draws with.
local function addPanel(add, rec)
  local f = NS.Canvas and NS.Canvas:FrameFor(rec.id)
  add("  [%s] '%s' %sx%s @%s %s,%s %s a=%s frame=%s",
    tostring(rec.id), tostring(rec.name),
    tostring(rec.width), tostring(rec.height), tostring(rec.point),
    tostring(rec.x), tostring(rec.y), tostring(rec.strata),
    NS.Registry.FormatField(rec, "alpha"),
    f and "yes" or "NO")
  -- The global name is the addon's public anchor contract, and the media names are the two
  -- values most likely to be the reason a panel "looks wrong" — both belong in a pasted log.
  add("        %s  bg=%s border=%s/%s%s%s",
    NS.Registry.FrameName(rec),
    tostring(rec.bgTexture), tostring(rec.borderTexture), tostring(rec.borderSize),
    (rec.bgClassColor or rec.borderClassColor) and " classcolor" or "",
    NS.Unlock and NS.Unlock:IsPanelUnlocked(rec.id) and " UNLOCKED" or "")
end

-- A frame with no record is a leak; the pool count is how you tell a leak from healthy reuse. Both
-- numbers come off one pass over the renderer's live frame map, which is read straight here — an
-- empty table when Canvas has not loaded, so the loop runs zero times rather than erroring.
local function addFrames(add)
  local orphans, count = 0, 0
  for id in pairs((NS.Canvas and NS.Canvas.__active) or {}) do
    count = count + 1
    if not NS.Registry:Get(id) then orphans = orphans + 1 end
  end
  add("frames: %d active, %d pooled, %d orphaned", count,
    (NS.Canvas and NS.Canvas.PooledCount and NS.Canvas.PooledCount()) or 0, orphans)
end

local function attachDiagnose(D)
  function D:Diagnose()
    local out = {}
    local function add(fmt, ...)
      out[#out + 1] = select("#", ...) > 0 and fmt:format(...) or fmt
    end

    addHeader(add)

    local records = NS.Registry:All()
    add("registry: %d panels", #records)
    for _, rec in ipairs(records) do
      addPanel(add, rec)
    end

    addFrames(add)

    return out
  end
end

local lib = LibStub and LibStub("LibKa0s-DebugLog-1.0", true)

if not lib then
  -- Degrade, never error. `/pm debug` is registered unconditionally and settings/Schema.lua's
  -- console row calls IsShown on every panel refresh, so every member the addon actually calls has
  -- to answer. The list is `grep -n "NS.DebugLog" -r` plus NS.Debug and NS.DebugBuild.
  --
  -- SetEnabled still really flips the flag and still acknowledges: logging is a session flag the
  -- addon owns, and it is only the WINDOW that has gone away. Everything that would have drawn
  -- something says why instead.
  local D = { buffer = {} }
  local said = false
  local function explainOnce()
    if said then return end
    said = true
    NS.Print(UNAVAILABLE)
  end

  function D:IsShown() return false end
  function D:Show() explainOnce() end
  function D:Hide() end
  function D:Toggle() explainOnce() end
  function D:ShowCopy() explainOnce() end
  function D:Add() end
  function D:Clear() end
  function D:BufferSize() return 0 end
  function D:LastLine() return nil end
  function D:FindLine() return nil end
  function D:UpdateScrollBar() end
  function D:UpdateStatus() end
  function D:RefreshHeader() end
  function D:IsEnabled() return (NS.State and NS.State.debug) and true or false end
  function D:SetEnabled(on)
    on = not not on
    if NS.State then NS.State.debug = on end
    -- The ack itself is required (debug-logging-§7): logging is a session flag the ADDON owns, so a
    -- degraded install that flipped it silently would look like the flag was stuck off.
    --
    -- It is deliberately NOT the library's line. This used to hand-copy the library's ACK format
    -- ("debug logging %s") and both of its state hexes — ON green, OFF red — which is exactly the
    -- transcription this file exists to end (anti-pattern #47), and it is a copy that cannot be kept
    -- true: on this path the library is ABSENT, so nothing here can read lib.STRINGS, and nothing
    -- would notice the day the library restyles its own ack. So the stub states the same fact in its
    -- own plain words, and explainOnce says why the window is not there to match.
    NS.Print(on and "debug logging is on" or "debug logging is off")
    explainOnce()
  end

  NS.DebugLog = D
  NS.Debug = function() end
  NS.DebugBuild = function() end
  -- Diagnose is defined once, below, and attached on both paths: it reads the addon's own state and
  -- has nothing to do with whether a window exists. `/pm debug dump` still answers.
  attachDiagnose(D)
  return
end

NS.DebugLog = lib:New({
  -- Seeds PanelMasterDebugWindow / PanelMasterDebugCopyWindow / PanelMasterDebugCopyScroll. The
  -- first two are byte-for-byte the globals modules/DebugLog.lua hardcoded, so anything anchored to
  -- them — /framestack, a user macro, UISpecialFrames — is unaffected.
  name  = addonName,
  -- The library appends its own " — Debug", giving "Panel Master — Debug": the exact title this
  -- console has always carried.
  title = "Panel Master",
  font  = C.FONT_MONO,

  -- The enable flag stays the HOST's. Both are closures rather than direct references because
  -- core/State.lua is not guaranteed to have loaded when this file does, and because a library that
  -- kept its own copy would leave two truths about whether logging is on.
  isEnabled  = function() return NS.State and NS.State.debug end,
  setEnabled = function(on) if NS.State then NS.State.debug = on end end,

  -- Through a closure, not `print = NS.Print`: core/PanelMaster.lua's AceConsole embed replaces
  -- NS.Print and its reclaim puts it back, and resolving at call time is immune to that whole
  -- sequence rather than merely surviving it by load order.
  print = function(line) NS.Print(line) end,

  -- core/Database.lua defines NS.InitSummary and loads after this file.
  initSummary = function() return NS.InitSummary() end,

  -- Keeps the settings panel's "Debug console" checkbox in step with the window. The library fires
  -- this from the frame's own OnShow AND OnHide, which is strictly better than what the old console
  -- did: it called its sync inline from D:Show()/D:Hide(), so closing the window with Esc — which
  -- this frame is registered in UISpecialFrames for, and which never goes through D:Hide — left the
  -- checkbox stale. That has been true since the console was written.
  onVisibilityChanged = function()
    if NS.Panel and NS.Panel.Refresh then NS.Panel:Refresh() end
  end,

  -- Composes the console checkbox tooltip's "<slash> debug" reference.
  slash = "/pm",

  -- DELIBERATELY NOT PASSED, and each omission is a decision:
  --
  --   applySkin  — the console now wears Core.SKIN: a flat 1px black edge with a 1px light-gray inner
  --                highlight, a gold title and a gray divider. The old local SKIN here was a bare
  --                background texture with a border color it never actually applied. As of Core
  --                minor 3 the Ka0s window edge is the LIBRARY's, not each host's, precisely so the
  --                collection's consoles read as one suite of addons (standalone-windows). Taking
  --                the hook to keep this addon's older look is the thing that release exists to
  --                undo.
  --   makeCloseButton — same reasoning, one field along. These are the library's windows, so they
  --                wear the library's × (Core's 18x18, gray, red on hover) rather than the flat
  --                "X" this file used to draw. DebugLog minor 6 narrowed this field to a close
  --                control that is different in KIND; ours was merely our own.
  --   L          — this addon translates nothing (locales/enUS.lua ships English-only by an
  --                explicit 1.0.0 scope decision), so there is no override to pass. Passing NS.L
  --                would be the `L` trap: its metatable answers every key with the key itself, so
  --                the console would render DEBUG_ON, COPY_TITLE and LINES as literal text.
  --   safeToString — the library's default is Core's, which is already exactly NS.SafeToString.
  --   skin       — see applySkin.
})

-- ── the two survivors ──────────────────────────────────────────────────────────

-- The gated sink, bound BARE off the instance (it is a plain function, not a method) so all 35
-- existing `NS.Debug("Tag", "fmt %s", v)` call sites are untouched. Zero-allocation when off: the
-- library returns before building the argument table.
NS.Debug = NS.DebugLog.Debug

-- NS.Debug for a call site whose arguments are not free to produce — a scan over every panel, a
-- formatted or concatenated string. `build(...)` is called only AFTER the gate, and whatever it
-- returns becomes the message's arguments. No library equivalent, and it is this addon's own idiom
-- at 14 call sites.
--
-- `build` MUST be a plain function reference and its arguments MUST travel separately, exactly as
-- they do here — never `function() return f(x) end`. A closure capturing upvalues is allocated at
-- the CALL SITE, before this function is entered, so the closure form would pay the very cost the
-- deferral exists to avoid and would be strictly worse than the gate it replaced. Passing the
-- function unbound keeps the off case at one call and one boolean test, allocating nothing.
function NS.DebugBuild(tag, fmt, build, ...)
  if not (NS.State and NS.State.debug) then return end
  return NS.Debug(tag, fmt, build(...))
end

attachDiagnose(NS.DebugLog)
