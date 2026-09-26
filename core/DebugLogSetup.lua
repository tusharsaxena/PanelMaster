local addonName, NS = ...

-- LibKa0s-DebugLog-1.0 seam: the on-screen debug console (debug-logging).
--
-- This replaces modules/DebugLog.lua, which was 429 lines of a window the Ka0s standard already
-- specifies down to the hex codes — the seventh hand-transcribed copy of it in the collection. Both
-- formatters were already byte-identical to the library's, and the frame globals the descriptor
-- generates from `name` are exactly the two this addon hardcoded, so the console a user sees is the
-- same window with the same buffer, the same 1500-line cap and the same title.
--
-- WHERE THIS FILE SITS: after core/CoreSetup.lua (NS.LIBKA0S_MISSING) and after core/Constants.lua
-- (C.FONT_MONO). Nothing else pins it. Every other thing the descriptor touches — NS.State,
-- NS.InitSummary, NS.Panel, NS.Diagnostics — is reached through a CLOSURE and
-- therefore resolved at call time, which is what lets the console move out of modules/ and up into
-- core/ without inverting a single dependency. Nothing anywhere captures NS.Debug, NS.DebugBuild or
-- NS.DebugLog as a load-time upvalue, so there is no ordering hazard below this file either.

local C = NS.Constants

local UNAVAILABLE = NS.LIBKA0S_MISSING .. ", so the debug console window is unavailable."

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

  -- The diagnostics report's three members (debug-logging-§14, DebugLog 14.1). The report is the
  -- library's, so on this arm there is none to write: RunDiagnostics says so in the collection's
  -- library-absent line, naming the command as typed, writes nothing and returns 0. NS.L is
  -- resolved at CALL time, so the load order of locales/ does not bind this file.
  function D:RunDiagnostics()
    NS.Print(NS.L["%s is unavailable: the LibKa0s library did not load."]:format("/pm diagnostics"))
    return 0
  end
  -- The report as data, in the library's shape and empty, so a caller reads no report rather than
  -- raising.
  function D:BuildDiagnostics()
    return { lines = {}, dropped = 0, capped = false, capsHit = false }
  end
  -- The library's `debug` words: `diagnostics`, `on` and `off` answer true and anything else false,
  -- so the caller keeps its own fallback. Each routes to the member above that answers it here.
  function D:DebugVerb(rest)
    local word = type(rest) == "string" and rest:lower():match("^%s*(%S+)") or nil
    if word == "diagnostics" then
      self:RunDiagnostics()
      return true
    end
    if word == "on" or word == "off" then
      self:SetEnabled(word == "on")
      return true
    end
    return false
  end

  NS.DebugLog = D
  NS.Debug = function() end
  NS.DebugBuild = function() end
  return
end

NS.DebugLog = lib:New({
  -- Seeds PanelMasterDebugWindow / PanelMasterDebugCopyWindow / PanelMasterDebugCopyScroll. The
  -- first two are byte-for-byte the globals modules/DebugLog.lua hardcoded, so anything anchored to
  -- them — /framestack, a user macro, UISpecialFrames — is unaffected.
  name  = addonName,
  -- THE FOLDER NAME, which is a different question from the one above even though this addon
  -- answers both with the same string. `name` seeds frame globals; `addonName` is what the library
  -- builds a texture path from, so its own close, copy and clear controls draw this collection's
  -- art instead of a multiplication sign and two words. A vendored library cannot work that out for
  -- itself — there is no one path to it — and a host where the two strings diverge would hand it a
  -- path into nowhere, which draws nothing and raises nothing. Passed explicitly for that reason
  -- rather than left to the library to infer from `name`.
  addonName = addonName,
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

  -- The diagnostics report (debug-logging-§14, DebugLog 14.1). `brandName` heads both markers,
  -- `==== Ka0s Panel Master diagnostics begin ====`, where `title` alone would drop the Ka0s.
  -- `diagnostics` hands the library this addon's sections, and is a closure because
  -- modules/Diagnostics.lua loads after this file: the library calls it when the report runs.
  brandName   = NS.BRAND,
  diagnostics = function() return NS.Diagnostics and NS.Diagnostics.Sections() or {} end,

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
  --                wear the library's own close control rather than the flat "X" this file used to
  --                draw — and since `addonName` is passed above, that control is now the shared
  --                Ka0s close MARK on both the console and its copy window, not the multiplication
  --                sign the library falls back to when it cannot build a texture path. DebugLog
  --                minor 6 narrowed this field to a close control that is different in KIND; ours
  --                was merely our own.
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
