local addonName, NS = ...   -- luacheck: ignore addonName
NS.DebugLog = NS.DebugLog or {}
local D = NS.DebugLog
local frame
local print = NS.Print   -- secret-safe, [PM]-prefixed shared printer (events-frames-taint-§8)

-- The on-screen debug console (debug-logging). Debug output goes HERE, never to the chat frame: the
-- console is monospace, timestamped and tagged, so a pasted log reconstructs what the addon did.

-- Plain-text mirror of the log (no color codes), for the Copy window. Capped like the log.
D.buffer = D.buffer or {}
local MAX_BUFFER = 500

local STATUS_H = 16   -- height reserved at the window bottom for the line-counter status bar
local BAR_W    = 8    -- scrollbar track width

-- The console's own skin seam (standalone-windows). PanelMaster has no other standalone window, so
-- the seam lives here; a future window reuses it rather than re-deriving these colors.
local SKIN = {
  backdrop = { 0.05, 0.05, 0.07, 0.94 },
  border   = { 0.24, 0.24, 0.27, 1.00 },
  divider  = { 0.24, 0.24, 0.27, 0.85 },
}
D.SKIN = SKIN

function D:ApplySkin(f)
  if not (f and f.CreateTexture) then return end
  if not f.__skinBG then
    f.__skinBG = f:CreateTexture(nil, "BACKGROUND")
    f.__skinBG:SetAllPoints(f)
  end
  f.__skinBG:SetColorTexture(SKIN.backdrop[1], SKIN.backdrop[2], SKIN.backdrop[3], SKIN.backdrop[4])
end

-- Small flat text button for the title bar (Copy / Clear).
local function makeTextButton(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width, 18)
  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetPoint("CENTER")
  fs:SetText(text)
  fs:SetTextColor(0.7, 0.7, 0.72)
  b:SetScript("OnEnter", function() fs:SetTextColor(1, 0.82, 0) end)
  b:SetScript("OnLeave", function() fs:SetTextColor(0.7, 0.7, 0.72) end)
  b:SetScript("OnClick", onClick)
  return b
end

local function EnsureFrame()
  if frame then return frame end

  frame = CreateFrame("Frame", "PanelMasterDebugWindow", UIParent, "BackdropTemplate")
  frame:SetSize(700, 344)   -- the Ka0s reference console size (debug-logging-§1)
  frame:SetPoint("CENTER", 220, -80)
  frame:SetFrameStrata("DIALOG")   -- above every panel strata this addon offers
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)

  local titleBar = CreateFrame("Frame", nil, frame)
  titleBar:SetPoint("TOPLEFT", 1, -1)
  titleBar:SetPoint("TOPRIGHT", -1, -1)
  titleBar:SetHeight(26)
  titleBar:EnableMouse(true)
  titleBar:RegisterForDrag("LeftButton")
  titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
  titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

  local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("CENTER")
  title:SetText("Panel Master \226\128\148 Debug")
  frame.title = title

  local divider = frame:CreateTexture(nil, "ARTWORK")
  divider:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
  divider:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
  divider:SetHeight(1)
  divider:SetColorTexture(SKIN.divider[1], SKIN.divider[2], SKIN.divider[3], SKIN.divider[4])

  local close = makeTextButton(titleBar, "X", 18, function() D:Hide() end)
  close:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)

  local clear = makeTextButton(titleBar, "Clear", 42, function() D:Clear() end)
  clear:SetPoint("RIGHT", close, "LEFT", -6, 0)

  local copy = makeTextButton(titleBar, "Copy", 40, function() D:ShowCopy() end)
  copy:SetPoint("RIGHT", clear, "LEFT", -6, 0)

  -- Left-aligned debug on/off toggle. Same flat look as Copy/Clear, but its resting color reflects
  -- state (green ON / red OFF); clicking flips state through the shared SetEnabled seam.
  local toggleBtn = CreateFrame("Button", nil, titleBar)
  toggleBtn:SetSize(80, 18)
  toggleBtn:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
  local toggleFS = toggleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  toggleFS:SetPoint("LEFT")
  toggleBtn:SetScript("OnEnter", function() toggleFS:SetTextColor(1, 0.82, 0) end)
  toggleBtn:SetScript("OnLeave", function() D:RefreshHeader() end)
  local function onToggleClick() D:SetEnabled(not (NS.State and NS.State.debug)) end
  toggleBtn:SetScript("OnClick", onToggleClick)
  frame.debugToggle = toggleFS
  frame.debugToggleBtn = toggleBtn
  D._toggleClickForTest = onToggleClick   -- test seam (the headless mock stubs GetScript)

  local log = CreateFrame("ScrollingMessageFrame", nil, frame)
  log:SetPoint("TOPLEFT", 8, -(26 + 6))
  -- The right inset clears the scrollbar gutter; the bottom inset clears the status bar.
  log:SetPoint("BOTTOMRIGHT", -(BAR_W + 8), STATUS_H + 4)
  log:SetFont(NS.Constants.FONT_MONO, 10, "")
  log:SetJustifyH("LEFT")
  log:SetFading(false)
  log:SetMaxLines(MAX_BUFFER)
  log:EnableMouseWheel(true)
  log:SetScript("OnMouseWheel", function(self, delta)
    if delta > 0 then self:ScrollUp() else self:ScrollDown() end
    D:UpdateScrollBar()   -- keep the thumb in step with wheel scrolling
  end)
  frame.log = log

  -- Thin flat scrollbar synced to the message frame's offset (debug-logging-§11). A
  -- ScrollingMessageFrame has no native scrollbar — it is wheel-only — so a plain Slider drives its
  -- scroll offset. Always shown, and inert when everything fits, matching the settings panel
  -- (options-ui-§10). Vertical Slider convention: value 0 = thumb at top = oldest. The message-frame
  -- offset is inverted (0 = newest/bottom), so offset = maxOffset - value.
  local bar = CreateFrame("Slider", nil, frame)
  bar:SetOrientation("VERTICAL")
  bar:SetWidth(BAR_W)
  bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -(26 + 6))
  bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, STATUS_H + 4)
  bar:SetMinMaxValues(0, 0)
  bar:SetValueStep(1)
  bar:SetObeyStepOnDrag(true)
  bar:SetValue(0)
  local track = bar:CreateTexture(nil, "BACKGROUND")
  track:SetAllPoints()
  track:SetColorTexture(0.24, 0.24, 0.27, 0.30)
  local thumb = bar:CreateTexture(nil, "ARTWORK")
  thumb:SetColorTexture(0.5, 0.5, 0.55, 0.85)
  thumb:SetSize(BAR_W, 36)
  bar:SetThumbTexture(thumb)
  bar:SetScript("OnValueChanged", function(_, value)
    if frame._syncing then return end   -- suppress the sync → OnValueChanged feedback loop
    local l = frame.log
    if not (l.GetMaxScrollRange and l.SetScrollOffset) then return end
    local maxOffset = l:GetMaxScrollRange()
    if type(maxOffset) ~= "number" then return end
    l:SetScrollOffset(maxOffset - math.floor(value + 0.5))
  end)
  frame.scrollBar = bar

  -- Bottom status bar: a thin divider + a right-aligned "N / MAX lines" counter.
  local statusDivider = frame:CreateTexture(nil, "ARTWORK")
  statusDivider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, STATUS_H)
  statusDivider:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, STATUS_H)
  statusDivider:SetHeight(1)
  statusDivider:SetColorTexture(SKIN.divider[1], SKIN.divider[2], SKIN.divider[3], SKIN.divider[4])

  local lineCount = frame:CreateFontString(nil, "OVERLAY")
  lineCount:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 3)
  lineCount:SetFont(NS.Constants.FONT_MONO, 10, "")
  lineCount:SetJustifyH("RIGHT")
  lineCount:SetTextColor(0.6, 0.6, 0.62)
  frame.lineCount = lineCount

  D:ApplySkin(frame)

  frame:HookScript("OnShow", function() D:RefreshHeader() end)
  D:RefreshHeader()

  frame:Hide()
  if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, "PanelMasterDebugWindow")
  end

  -- Initial scrollbar/counter sync LAST, so a surprise from the frame API can never abort the
  -- header/ESC/hide wiring above (debug-logging-§11).
  D:UpdateScrollBar()
  D:UpdateStatus()
  return frame
end

-- Pure plain-text line formatter (no frames, no color codes): "<ts> | [<tag>] <msg>". This is what
-- the Copy buffer mirrors — clean text with the tag rendered verbatim.
function D.FormatPlain(ts, tag, msg)
  return ("%s | [%s] %s"):format(tostring(ts), tostring(tag or ""), tostring(msg))
end

-- Pure color-coded line formatter for the console view. The timestamp is muted steel-blue (6f8faf)
-- and the [tag] muted tan/gold (c9a66b); the "|" separator and the message stay the frame's default
-- color. "||" renders one literal pipe inside a color-coded string.
function D.FormatColored(ts, tag, msg)
  return ("|cff6f8faf%s|r || |cffc9a66b[%s]|r %s"):format(
    tostring(ts), tostring(tag or ""), tostring(msg))
end

function D:Add(tag, msg)
  local f = EnsureFrame()
  local ts = date("%H:%M:%S")
  f.log:AddMessage(D.FormatColored(ts, tag, msg))
  D.buffer[#D.buffer + 1] = D.FormatPlain(ts, tag, msg)
  if #D.buffer > MAX_BUFFER then table.remove(D.buffer, 1) end
  D:UpdateScrollBar()
  D:UpdateStatus()
end

-- Sync the scrollbar thumb/range to the message frame's offset. Uses the Lua
-- ScrollingMessageFrameMixin API (GetMaxScrollRange / GetScrollOffset / SetScrollOffset), where
-- offset 0 = bottom (newest) and offset == maxRange = top (oldest). The old C getters
-- (GetNumLinesDisplayed / GetCurrentScroll) are nil on this mixin and would raise, so they are never
-- called. Method-presence + type guards keep this a clean no-op under the headless mock, whose stub
-- frame returns itself rather than a number (debug-logging-§11).
function D:UpdateScrollBar()
  if not (frame and frame.log and frame.scrollBar) then return end
  local log, bar = frame.log, frame.scrollBar
  if not (log.GetMaxScrollRange and log.GetScrollOffset) then return end
  local maxOffset, off = log:GetMaxScrollRange(), log:GetScrollOffset()
  if type(maxOffset) ~= "number" or type(off) ~= "number" then return end
  frame._syncing = true
  bar:SetMinMaxValues(0, maxOffset)
  bar:SetValue(maxOffset - off)
  frame._syncing = false
  bar:EnableMouse(maxOffset > 0)   -- inert (but still shown) when everything fits
end

-- Update the bottom status bar's line counter. #D.buffer is the live line count, capped at
-- MAX_BUFFER in lock-step with the log's SetMaxLines.
function D:UpdateStatus()
  if frame and frame.lineCount then
    frame.lineCount:SetText(("%d / %d lines"):format(#D.buffer, MAX_BUFFER))
  end
end

-- Clear both the visible log and the copy buffer, and reset the counter.
function D:Clear()
  if frame and frame.log then frame.log:Clear() end
  for i = #D.buffer, 1, -1 do D.buffer[i] = nil end
  D:UpdateScrollBar()
  D:UpdateStatus()
end

-- ── Copy window ────────────────────────────────────────────────────────────────
-- WoW exposes no clipboard API, so a read-through EditBox the user Ctrl+C's is the only copy path.
local copyFrame
local function EnsureCopyFrame()
  if copyFrame then return copyFrame end

  copyFrame = CreateFrame("Frame", "PanelMasterDebugCopyWindow", UIParent, "BackdropTemplate")
  copyFrame:SetSize(560, 360)
  copyFrame:SetPoint("CENTER")
  copyFrame:SetFrameStrata("FULLSCREEN")   -- above the DIALOG-strata console
  copyFrame:EnableMouse(true)
  copyFrame:SetMovable(true)
  copyFrame:SetClampedToScreen(true)

  local tbar = CreateFrame("Frame", nil, copyFrame)
  tbar:SetPoint("TOPLEFT", 1, -1)
  tbar:SetPoint("TOPRIGHT", -1, -1)
  tbar:SetHeight(26)
  tbar:EnableMouse(true)
  tbar:RegisterForDrag("LeftButton")
  tbar:SetScript("OnDragStart", function() copyFrame:StartMoving() end)
  tbar:SetScript("OnDragStop", function() copyFrame:StopMovingOrSizing() end)
  local t = tbar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  t:SetPoint("CENTER")
  t:SetText("Copy log \226\128\148 Ctrl+C, then Esc")
  copyFrame.title = t

  local cclose = makeTextButton(tbar, "X", 18, function() copyFrame:Hide() end)
  cclose:SetPoint("RIGHT", tbar, "RIGHT", -6, 0)

  local scroll = CreateFrame("ScrollFrame", nil, copyFrame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, -30)
  scroll:SetPoint("BOTTOMRIGHT", -28, 10)
  copyFrame.scroll = scroll

  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetFont(NS.Constants.FONT_MONO, 10, "")   -- same monospace font, so the copy matches the view
  edit:SetAutoFocus(false)
  edit:SetWidth(510)
  edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); copyFrame:Hide() end)
  scroll:SetScrollChild(edit)
  copyFrame.edit = edit

  D:ApplySkin(copyFrame)
  copyFrame:Hide()
  if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, "PanelMasterDebugCopyWindow")
  end
  return copyFrame
end

function D:ShowCopy()
  local f = EnsureCopyFrame()
  f.edit:SetWidth(f.scroll:GetWidth() > 0 and f.scroll:GetWidth() or 510)
  f.edit:SetText(table.concat(D.buffer, "\n"))
  f.edit:SetCursorPosition(0)
  f:Show()
  f.edit:SetFocus()
  f.edit:HighlightText()
end

-- Keep the settings panel's "Debug console" checkbox in step with the window's visibility. A direct
-- call, not a bus message — the closed bus carries only the three Ka0s_PanelMaster_* messages.
local function syncPanel()
  if NS.Panel and NS.Panel.Refresh then NS.Panel:Refresh() end
end

-- Window visibility, which is DISTINCT from the NS.State.debug logging flag: capture runs whether or
-- not the console is open, so a bug can be reproduced first and the log read afterwards.
function D:IsShown() return frame ~= nil and frame:IsShown() and true or false end
function D:Show() EnsureFrame():Show(); syncPanel() end
function D:Hide() if frame then frame:Hide() end; syncPanel() end
function D:Toggle() if D:IsShown() then D:Hide() else D:Show() end end

-- The single seam for changing debug state (debug-logging-§5): the slash command and the header
-- toggle both call this, so the flag, the header label, the chat ack and the console bracket can
-- never diverge. Session-only — NS.State.debug resets on every reload and is never in SavedVariables.
function D:SetEnabled(on)
  on = not not on
  NS.State.debug = on
  D:RefreshHeader()
  -- Color-coded chat ack: ON green (40ff40) / OFF red (ff4040), mirroring the title-bar toggle so
  -- the flag reads identically in chat and on the console header.
  print("debug logging " .. (on and "|cff40ff40ON|r" or "|cffff4040OFF|r"))
  -- A console line at BOTH transitions, so the log itself records when capture started and stopped.
  -- Written through the raw append (D:Add), never the flag-gated NS.Debug sink: the disable line has
  -- to land AFTER the flag flipped off, which the gated sink would swallow.
  D:Add("Debug", on and "logging enabled" or "logging disabled")
  if on then
    -- [Init] session summary immediately after the enable bracket. Emitted here on enable — NOT at
    -- login — because the flag is session-only and off at login, so a load-time summary would always
    -- be gated off and never render (debug-logging-§5/§8).
    D:Add("Init", NS.InitSummary())
  end
end

-- Update the header toggle label to match NS.State.debug.
function D:RefreshHeader()
  if not (frame and frame.debugToggle) then return end
  local on = NS.State and NS.State.debug
  frame.debugToggle:SetText(on and "Debug: ON" or "Debug: OFF")
  if on then frame.debugToggle:SetTextColor(0.30, 0.85, 0.30)
  else frame.debugToggle:SetTextColor(0.90, 0.30, 0.30) end
end

-- Structured dump verb (debug-logging-§4): what the addon believes is on screen right now, written
-- through the RAW append so it works whether or not logging is enabled. The registry's view and the
-- renderer's view are printed together on purpose — a panel that is in the registry but has no frame
-- (or the reverse) is the exact shape of every rendering bug this addon can have.
function D:Diagnose()
  local out = {}
  local function add(fmt, ...)
    out[#out + 1] = select("#", ...) > 0 and fmt:format(...) or fmt
  end

  local settings = (NS.db and NS.db.profile and NS.db.profile.settings) or {}
  add("master=%s unlocked=%s preview=%s snap=%s/%s",
    tostring(settings.enabled), tostring(NS.State.unlocked), tostring(NS.State.preview),
    tostring(settings.snapToGrid), tostring(settings.gridSize))

  local w, h = NS.Compat.GetScreenSize()
  add("screen=%s x %s scale=%s", tostring(w), tostring(h), tostring(NS.Compat.GetUIScale()))

  local records = NS.Registry:All()
  add("registry: %d panels", #records)
  for _, rec in ipairs(records) do
    local f = NS.Canvas and NS.Canvas:FrameFor(rec.id)
    add("  [%s] '%s' %sx%s @%s %s,%s %s a=%s frame=%s",
      tostring(rec.id), tostring(rec.name),
      tostring(rec.width), tostring(rec.height), tostring(rec.point),
      tostring(rec.x), tostring(rec.y), tostring(rec.strata),
      NS.Registry.FormatField(rec, "alpha"),
      f and "yes" or "NO")
    -- The global name is the addon's public anchor contract, and the media names are the two values
    -- most likely to be the reason a panel "looks wrong" — both belong in a pasted log.
    add("        %s  bg=%s border=%s/%s%s%s",
      NS.Registry.FrameName(rec),
      tostring(rec.bgTexture), tostring(rec.borderTexture), tostring(rec.borderSize),
      (rec.bgClassColor or rec.borderClassColor) and " classcolor" or "",
      NS.Unlock and NS.Unlock:IsPanelUnlocked(rec.id) and " UNLOCKED" or "")
  end

  -- A frame with no record is a leak; the pool count is how you tell a leak from healthy reuse.
  local orphans = 0
  for id in pairs((NS.Canvas and NS.Canvas.__active) or {}) do
    if not NS.Registry:Get(id) then orphans = orphans + 1 end
  end
  add("frames: %d active, %d pooled, %d orphaned",
    (function() local n = 0 for _ in pairs((NS.Canvas and NS.Canvas.__active) or {}) do n = n + 1 end return n end)(),
    (NS.Canvas and NS.Canvas.PooledCount and NS.Canvas.PooledCount()) or 0, orphans)

  return out
end

-- The global debug sink. A no-op — and zero-allocation — when debug is off: the gate is the very
-- first line, before any format, concat or table build. Every arg is routed through NS.SafeToString
-- BEFORE it reaches string.format, so a combat-protected "secret" value logs as "<secret>" instead
-- of raising the format call (events-frames-taint-§8). Because every arg arrives as a string, the
-- sink's format strings use %s for every placeholder — never %d/%f.
--
-- This is the ONLY gate (debug-logging-§4). Call sites must not re-spell `if NS.State.debug then`
-- around a NS.Debug call — the invariant restated is the invariant that drifts. There are no
-- exceptions: a site whose ARGUMENTS cost something to build uses NS.DebugBuild below, which defers
-- that cost past this same gate instead of growing a second one.
function NS.Debug(tag, fmt, ...)
  if not (NS.State and NS.State.debug) then return end
  local n = select("#", ...)
  local msg = fmt
  if n > 0 then
    local parts = {}
    for i = 1, n do parts[i] = NS.SafeToString((select(i, ...))) end
    msg = fmt:format(unpack(parts))
  end
  D:Add(tag, msg)
end

-- NS.Debug for a call site whose arguments are not free to produce — a scan over every panel, a
-- formatted or concatenated string. `build(...)` is called only AFTER the gate, and whatever it
-- returns becomes the message's arguments.
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
