local addonName, NS = ...

-- core/SkinSetup.lua — the LibKa0s-Skin-1.0 seam: which skin this addon wears (skinning-§3).
--
-- ── WHAT IT PUBLISHES ────────────────────────────────────────────────────────────────────────
--
--   NS.Skin                 the owner's facade, `Skin:For("PanelMaster")`: the painting vocabulary
--                           (Shell, TitleBar, Button, Text, ...) and Token / Color / Resolve /
--                           OnLooksChanged. Every surface this addon draws reads its colors here.
--   NS.SkinChoice()         the stored (source, skin) pair, read through NS.Schema:Get; "ka0s",
--                           "ka0s" before NS:InitDB has built the profile store.
--   NS.WriteSkinChoice(s,k,i,m) the write seam: every half through NS.Schema:Set, the one seam
--                           `/pm set` and the panel already write through (architecture-§5); `i`,
--                           the Scope's `{ panel, fonts }`, writes the two exceptions, and `m`, the
--                           Font and texture section's `{ font, texture }`, writes the two
--                           overrides, "" for false (the skin's own); its `outline`, when not
--                           nil, writes skin.outline (LibKa0s v1.82.0's Font outline, D-06).
--   NS.ApplySkinIgnore(p,f) moves the applied exceptions: `Skin:SetIgnore`, live; no argument
--                           applies the stored pair, a nil half keeps that half.
--   NS.SkinOverride()       the stored overrides: font, texture, each an LSM key or false for the
--                           skin's own; false, false before NS:InitDB.
--   NS.ApplySkinOverride(f,t) moves the applied overrides: `Skin:SetOverride`, live; no argument
--                           applies the stored pair, a nil half keeps that half, false or "" clears.
--   NS.SkinOutline()        the stored font outline mode: "all", "hud" or "off"; "hud" before
--                           NS:InitDB has built the profile store.
--   NS.ApplySkinOutline(m)  moves the applied font outline: `Skin:SetOutline`, live; no argument
--                           applies the stored skin.outline (LibKa0s v1.82.0, Skin minor 9, D-06).
--   NS.SKIN_OUTLINE_OPTIONS the outline row's values: "all", "hud", "off", the library's order.
--   NS.ApplySkinChoice(s,k) moves the applied skin: `Skin:SetChoice`, which resolves, repaints
--                           every frame recorded for this owner and THEN fires OnLooksChanged. No
--                           argument applies the stored pair (addon:OnInitialize, the profile
--                           events), and with it the stored exceptions, overrides and outline; a
--                           nil half keeps that half (each Skin tab row's onChange).
--   NS.SKIN_SOURCE_OPTIONS  the source row's values, and NS.SKIN_OPTIONS the skin row's (every
--   NS.SKIN_OPTIONS         registered skin, in the library's order). settings/Schema.lua reads both.
--   NS.SKIN_FALLBACK        the host copy of the Ka0s Default tokens the degraded facade answers.
--   NS.SkinColor(name)      a color token as a call site writes it (three components when opaque),
--                           so a literal that became a token keeps its arity on Ka0s Default.
--   NS.SkinEscape(name)     a color token as a "|cffrrggbb" escape, rounded to the byte, so markup
--                           written as a literal keeps its bytes on Ka0s Default (|cff808080).
--   NS.SkinPanelEscape(name) the same for markup on a settings page: Ka0s Default's escape while
--                           the owner's applied "Ignore settings panel" is on, the worn skin's off.
--   NS.SkinPaintAce(w)      an AceGUI widget this addon acquired itself, painted for this owner:
--   NS.SkinPaintAceTree(c)  `Skin:PaintAce` / `Skin:PaintAceTree` with the owner bound (the facade
--                           carries neither). The Panels editor acquires from AceGUI itself, past
--                           the Options instance's owner proxy, and AceConfigDialog draws the
--                           Profiles tree the same way. Nothing while the owner ignores its settings
--                           panel (the default here), and a widget it painted goes back stock; the
--                           release always restores stock. No widget type of this addon's own (no
--                           AliasAceType) and no host OnRelease (no Skin:OnRelease) exist to bind.
--   NS.ArmSkinPicker()      the login start of the first-run picker: once per session, two seconds
--                           in, from addon:OnEnterWorld (registered only while the addon stands up).
--   NS.MaybeShowSkinPicker() the first-run skin picker (LibKa0s OptionsSkinPicker 1): `O.SkinPicker`
--                           while the profile's `skin.pickerSeen` is false and the addon stands up;
--                           held to PLAYER_REGEN_ENABLED in combat. Answers the frame, or nil,
--                           "queued" behind another Ka0s addon's picker.
--   NS.HideSkinPicker()     takes a shown picker down (its pending preview put back) or out of the
--                           queue WITHOUT marking it seen: the stand-down, a profile that has seen
--                           it, and first on every profile event; drops a held start.
--   NS.SkinPickerSpec()     the spec MaybeShowSkinPicker hands O.SkinPicker.
--   NS.RunSkinVerb()        the reserved `/pm skin` verb's act (LibKa0s v1.82.0, O.SkinVerb, D-16):
--                           the same spec, whatever `skin.pickerSeen` says; the library-absent line
--                           when the stub answers nil, "absent".
--
-- This is LootHistory's seam (core/SkinSetup.lua there, the collection's first adopter), cut to what
-- PanelMaster draws: no owner tokens (the one color the M0 inventory found with no exact library
-- token, the tooltips' inline `|cffffff00` emphasis, stays content markup, rollout decision X9), and
-- no window of its own for a degraded Shell to route to (core/CoreSetup.lua adopts no skin half).
--
-- ── WHERE IT LOADS ───────────────────────────────────────────────────────────────────────────
--
-- After core/CoreSetup.lua and core/Namespace.lua (NS.BRAND, the owner's label) and before
-- core/DebugLogSetup.lua and every file that builds a frame, so NS.Skin exists for all of them.
-- settings/Schema.lua reads NS.SKIN_SOURCE_OPTIONS and NS.SKIN_OPTIONS at file load and is far
-- below. Registered at FILE LOAD, never at PLAYER_LOGIN (skinning-§1): the EllesmereUI provider has
-- to offer the owner to EllesmereUI before EllesmereUI dispatches its skins (skinning-§5). Nothing
-- here reads the profile at load: RegisterOwner calls `get` once, before AceDB exists, and it
-- answers Ka0s Default; the profile's pair is applied by NS.ApplySkinChoice right after NS:InitDB
-- (core/PanelMaster.lua), and again on every profile event (core/Database.lua).
--
-- ── WHY A ROW'S onChange PASSES ONE HALF ─────────────────────────────────────────────────────
--
-- The Skin tab and another addon's "Copy to every Ka0s addon" both call Skin:SetChoice FIRST and
-- write the store after, one half at a time. A row reaction that re-applied the whole stored pair
-- would apply the half-written one in between: a second repaint, to a skin the player never
-- picked. Applying only the row's own half against the applied choice makes each write a no-op
-- (SetChoice is idempotent), so a pick is ONE effective SetChoice and one repaint, while a bare
-- `/pm set skin.skin obsidian` still repaints.
--
-- Nothing skin-related keys off SETTINGS_CHANGED. A surface that has to rebuild on a skin change
-- subscribes to NS.Skin.OnLooksChanged, which fires after the new skin is resolved and the
-- recorded frames are repainted.

local Skin = LibStub and LibStub("LibKa0s-Skin-1.0", true)

local SOURCE_PATH, SKIN_PATH = "skin.source", "skin.skin"
local PANEL_PATH, FONTS_PATH = "skin.ignorePanel", "skin.ignoreFonts"
local FONT_PATH, TEXTURE_PATH = "skin.font", "skin.texture"
local OUTLINE_PATH, OUTLINE_DEFAULT = "skin.outline", "hud"
local DEFAULT = "ka0s"

-- The Ka0s Default tokens the DEGRADED facade answers, copied from the library and limited to the
-- ones this addon reads. Both arms publish the table, so tests/test_skinsetup.lua can hold each
-- entry to the live library's Ka0s Default value: a copy that drifts goes red there. A surface
-- converted to a token adds the token here in the same change. The settings pages and the debug
-- console are the library's to paint, and the panels are the player's (E8), so the list is short.
NS.SKIN_FALLBACK = {
  -- The Panels page picker's "(disabled)" marker (settings/PanelEditor.lua, PM-02): DIM, the
  -- |cff808080 it was typed as.
  ["text.disabled"] = { 0.5, 0.5, 0.5, 1 },
  -- The unlock overlay's outline (modules/Unlock.lua, PM-03): the drag target's marker, the
  -- {1, 0.82, 0, 0.9} gold it was typed as. Its label is S.Text's, which the degraded facade
  -- leaves on GameFontNormal's own gold.
  ["list.dropLine"] = { 1, 0.82, 0, 0.9 },
}

--- A color token's components AS A CALL SITE WRITES THEM: r, g, b for an opaque color and r, g, b,
--- a otherwise (the library's own text and vertex rule), so a site that passed three components
--- before it read a token still passes three on Ka0s Default. nil for a token the skin leaves alone.
--- Read through NS.Skin at call time, so it answers the live skin, or the host copy degraded.
function NS.SkinColor(name)
  local r, g, b, a = NS.Skin.Color(name)
  if r == nil then return nil end
  if a == nil or a == 1 then return r, g, b end
  return r, g, b, a
end

--- A color token as a "|cffrrggbb" escape, each channel rounded to the nearest byte (.5 is 80), so
--- markup a call site wrote as a literal keeps its bytes on Ka0s Default. nil for a token the skin
--- leaves alone. Read at call time: markup is text, so a skin change reaches it at the next build.
local function escape(r, g, b)
  if r == nil then return nil end
  local function byte(v) return math.floor(v * 255 + 0.5) end
  return ("|cff%02x%02x%02x"):format(byte(r), byte(g), byte(b))
end

function NS.SkinEscape(name)
  return escape(NS.Skin.Color(name))
end

--- NS.SkinEscape for markup ON A SETTINGS PAGE: while the owner's applied "Ignore settings panel"
--- is on (the default here) the page is the client's look, so the escape is the Ka0s Default value
--- it was typed as (NS.SKIN_FALLBACK), not the worn skin's. Off, the worn skin's, as NS.SkinEscape.
--- Asks the library's applied exceptions (Skin:GetIgnore), the same state its painters ask.
function NS.SkinPanelEscape(name)
  if Skin and type(Skin.GetIgnore) == "function" and Skin:GetIgnore(addonName) then
    local c = NS.SKIN_FALLBACK[name]
    if not c then return nil end
    return escape(c[1], c[2], c[3])
  end
  return NS.SkinEscape(name)
end

NS.SKIN_SOURCE_OPTIONS = {
  { value = "ka0s", text = "Ka0s skins" },
  { value = "eui",  text = "EllesmereUI" },
}

-- The skin row's values: every registered skin, Ka0s Default first. Without the library the one
-- skin the degraded facade can draw.
NS.SKIN_OPTIONS = {}
if Skin and type(Skin.Skins) == "function" then
  for _, def in ipairs(Skin:Skins()) do
    NS.SKIN_OPTIONS[#NS.SKIN_OPTIONS + 1] = { value = def.key, text = def.label or def.key }
  end
end
if #NS.SKIN_OPTIONS == 0 then NS.SKIN_OPTIONS[1] = { value = DEFAULT, text = "Ka0s Default" } end

-- The font outline row's values (LibKa0s-Skin-1.0 minor 9's OUTLINE_MODES, in its order), with the
-- Skin tab's words. Typed here rather than read from the library so the row validates `/pm set` on
-- a load without Skin.lua too; tests/test_skin_outline.lua holds the order to the library's.
NS.SKIN_OUTLINE_OPTIONS = {
  { value = "all", text = "All text" },
  { value = "hud", text = "HUD text only" },
  { value = "off", text = "Off" },
}

--- The stored pair, lazily and nil-safely: Ka0s Default until the profile store exists.
function NS.SkinChoice()
  local S = NS.Schema
  if not (NS.db and S and S.Get) then return DEFAULT, DEFAULT end
  return S:Get(SOURCE_PATH) or DEFAULT, S:Get(SKIN_PATH) or DEFAULT
end

--- A stored override as the profile keeps it: the LSM key, or "" for the skin's own (false, nil, "").
local function storedKey(v)
  if type(v) == "string" and v ~= "" then return v end
  return ""
end

--- The write seam: every half through NS.Schema:Set (validate, store, the [Set] line, onChange).
--- `ignore` is `{ panel = bool, fonts = bool }`, the Scope; `media` is `{ font = key|false,
--- texture = key|false, outline = mode|nil }`: the Skin tab's Font and texture pick, its Font
--- outline and another addon's copy all hand it here, after Skin:SetOverride / Skin:SetOutline
--- moved the applied state, so each row's onChange re-applies its own half as a no-op. A nil
--- `outline` leaves the stored mode alone.
function NS.WriteSkinChoice(source, skin, ignore, media)
  local S = NS.Schema
  if not (NS.db and S and S.Set) then return end
  if source ~= nil then S:Set(SOURCE_PATH, source) end
  if skin ~= nil then S:Set(SKIN_PATH, skin) end
  if type(ignore) == "table" then
    S:Set(PANEL_PATH, ignore.panel == true)
    S:Set(FONTS_PATH, ignore.fonts == true)
  end
  if type(media) == "table" then
    S:Set(FONT_PATH, storedKey(media.font))
    S:Set(TEXTURE_PATH, storedKey(media.texture))
    if media.outline ~= nil then S:Set(OUTLINE_PATH, media.outline) end
  end
end

--- The stored font outline mode, nil-safely: "hud" until the profile store exists.
function NS.SkinOutline()
  local S = NS.Schema
  if not (NS.db and S and S.Get) then return OUTLINE_DEFAULT end
  return S:Get(OUTLINE_PATH) or OUTLINE_DEFAULT
end

--- The stored overrides, nil-safely: each an LSM key, or false for the skin's own; false, false
--- until the profile store exists.
function NS.SkinOverride()
  local S = NS.Schema
  if not (NS.db and S and S.Get) then return false, false end
  local font, texture = storedKey(S:Get(FONT_PATH)), storedKey(S:Get(TEXTURE_PATH))
  return font ~= "" and font or false, texture ~= "" and texture or false
end

--- The stored exceptions, nil-safely: false, false until the profile store exists.
local function storedIgnore()
  local S = NS.Schema
  if not (NS.db and S and S.Get) then return false, false end
  return S:Get(PANEL_PATH) == true, S:Get(FONTS_PATH) == true
end

-- ── the first-run skin picker (LibKa0s OptionsSkinPicker 1, rollout rulings O3 and X6) ─────────
--
-- WHEN. Once after login (NS.ArmSkinPicker from addon:OnEnterWorld, which only an addon that
-- stands up registers), after OnInitialize applied the stored skin; and again after every profile
-- event (core/Database.lua), because a new, copied or reset profile carries its own `pickerSeen`.
-- Never while the addon stands down, and never in combat: a start in combat is held for the
-- PLAYER_REGEN_ENABLED edge on a one-shot private target, one at most (LootHistory's idiom). The
-- library's queue waits out combat before it shows the NEXT owner's picker, but a first call with
-- nothing up shows at once, whatever the lockdown, so this addon's own start is held here.
--
-- SEEN. The library calls `onClose` once per showing, by any route the player takes (Apply, its
-- close control, the gear, Escape), and once for a picker still queued behind another Ka0s addon's
-- when that addon's "Apply to all Ka0s addons" dismisses it unshown; that is the one write of
-- `skin.pickerSeen`, through NS.Schema:Set. A close this addon makes itself (NS.HideSkinPicker: the
-- stand-down, a profile event) is not the player's and writes nothing.
--
-- PREVIEW. A pick only previews: the Skin major moves and the settings pages repaint, but `set`
-- (NS.WriteSkinChoice) runs only on Apply, the gear or Apply to all; the close control and Escape
-- put back the stored choice as it reads at the close. NO EYE (X6, PanelMaster decision D6): the
-- addon has no window of its own and no test mode to preview a skin in, and the panels are the
-- player's and never wear one (D1), so `onPreview` is omitted, the library hides the button, and
-- CLAUDE.md's icon line declares only `settings`.
--
-- QUEUED. One picker is up at a time across every Ka0s addon: while another addon's is up,
-- O.SkinPicker queues this one and answers nil, "queued", which NS.MaybeShowSkinPicker passes
-- through; it shows when the other closes.

local PICKER_PATH = "skin.pickerSeen"
local PICKER_DELAY = 2   -- seconds after PLAYER_ENTERING_WORLD, off the login spike
local pickerTimer        -- its AceTimer handle, until it fires
local pickerTarget       -- the one-shot PLAYER_REGEN_ENABLED target, while a start is held
local quietClose = false -- true while NS.HideSkinPicker takes the picker down

--- The player's close: the picker seen, and nothing else. The library's put-back already wears the
--- stored choice, so the skin is not this callback's to move.
local function pickerClosed()
  if quietClose then return end
  local S = NS.Schema
  if not (NS.db and S and S.Set) then return end
  S:Set(PICKER_PATH, true)
end

function NS.SkinPickerSpec()
  return {
    owner = addonName, get = NS.SkinChoice, set = NS.WriteSkinChoice,
    -- The gear's default: O.OpenOptionsPanel("general") (the General page's own subcategory), then
    -- O.SelectTab("general", "Appearance"), the Skin tab's key (settings/Panel.lua).
    page = "general", tab = "Appearance",
    onClose = pickerClosed,
  }
end

local function dropPickerDeferral()
  if pickerTarget then pickerTarget:UnregisterAllEvents(); pickerTarget = nil end
end

-- An unfired login start goes with a stand-down, and the session's start is given back with it, so
-- the next PLAYER_ENTERING_WORLD after a re-enable arms it again.
local function dropPickerTimer()
  if not pickerTimer then return end
  if NS.addon and NS.addon.CancelTimer then NS.addon:CancelTimer(pickerTimer) end
  pickerTimer = nil
  NS.State.skinPickerArmed = false
end

--- True while this profile has not closed the picker and the addon stands up.
local function pickerDue()
  local S = NS.Schema
  if not (NS.db and S and S.Get) then return false end
  if NS.Lifecycle and NS.Lifecycle:IsDown() then return false end
  return S:Get(PICKER_PATH) == false
end

local function inLockdown()
  return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

function NS.HideSkinPicker()
  dropPickerDeferral()
  dropPickerTimer()
  local O = NS.Helpers
  if not (O and type(O.HideSkinPicker) == "function") then return end
  quietClose = true
  local ok, err = pcall(O.HideSkinPicker)
  quietClose = false
  if not ok then error(err, 0) end
end

--- Show the picker when this profile has not seen it: answers O.SkinPicker's frame, or nil, "queued"
--- while another Ka0s addon's picker is up (it shows when that one closes), or nil.
function NS.MaybeShowSkinPicker()
  local O = NS.Helpers
  if not (O and type(O.SkinPicker) == "function") then return nil end
  if not pickerDue() then
    NS.HideSkinPicker()
    return nil
  end
  if inLockdown() then
    if pickerTarget then return nil end
    pickerTarget = NS.NewBusTarget and NS.NewBusTarget()
    if not pickerTarget then return nil end
    NS.SafeRegisterEvent(pickerTarget, "PLAYER_REGEN_ENABLED", function()
      dropPickerDeferral()
      NS.MaybeShowSkinPicker()
    end, NS.State and NS.State.rejectedEvents)
    return nil
  end
  return O.SkinPicker(NS.SkinPickerSpec())
end

--- The reserved `/pm skin` verb's act (LibKa0s v1.82.0, OptionsSkinPicker minor 3, ruling D-16):
--- O.SkinVerb with the spec the first-run start builds, so it shows the picker a new profile shows
--- whatever skin.pickerSeen says. The library prints its own lines (combat on every call, queued,
--- unavailable); without LibKa0s the Options stub answers nil, "absent" and this prints the
--- collection's library-absent line. The dispatcher refuses the verb while the addon is disabled.
--- Answers the picker's frame, or nil and the reason.
function NS.RunSkinVerb()
  local O = NS.Helpers
  local win, why
  if O and type(O.SkinVerb) == "function" then
    win, why = O.SkinVerb(NS.SkinPickerSpec())
  else
    why = "absent"
  end
  if win == nil and why == "absent" and NS.Print and NS.L then
    NS.Print(NS.L["%s is unavailable: the LibKa0s library did not load."]:format("/pm skin"))
  end
  return win, why
end

--- The login start, once per session: PICKER_DELAY seconds in, on an AceTimer the stand-down
--- cancels (NS.HideSkinPicker). The fuse re-checks everything when it fires.
function NS.ArmSkinPicker()
  if NS.State.skinPickerArmed then return end
  local addon = NS.addon
  if not (addon and addon.ScheduleTimer) then return end
  NS.State.skinPickerArmed = true
  pickerTimer = addon:ScheduleTimer(function()
    pickerTimer = nil
    NS.MaybeShowSkinPicker()
  end, PICKER_DELAY)
end

-- ── the degraded arm ─────────────────────────────────────────────────────────────────────────

if not Skin then
  local function color(name)
    local c = NS.SKIN_FALLBACK[name]
    if c then return c[1], c[2], c[3], c[4] or 1 end
  end
  local function noop() end
  local S = { owner = addonName, apiVersion = 3, FROM_SKIN = "@skin" }
  -- Every vocabulary name answers, and a primitive with no host meaning is a no-op that never
  -- raises: without the library nothing this addon draws has a skin to wear, and the client's
  -- own look is what it drew before skins. The list is LibKa0s-Skin-1.0's VOCAB;
  -- tests/test_surface_parity.lua holds this table to the live facade key for key. FontFlags and
  -- HudFontSize stay listed so the copy matches VOCAB; both are overwritten with answering
  -- functions below.
  for _, name in ipairs({
    "Shell", "Panel", "Inset", "FadeRegions", "FadeNineSlice", "Button", "WhiteButtonLabel",
    "StateButtonLabel", "EditBox", "Checkbox", "Dropdown", "ScrollBar", "Tab", "SetTabSelection",
    "CloseButton", "PageButton", "SquareIcon", "SortHeaderBar", "Font", "White", "ApplyBarFill",
    "GetAccentColor", "GetPanelColor", "GetFont",
    "TitleBar", "Divider", "Footer", "Card", "Slider", "NavItem", "Drawer", "ListRow", "MenuFrame",
    "Tooltip", "Strip", "Cover", "Text", "ChartStyle", "BarStyle", "IconBorder", "GlowColor",
    "BarTexture", "FontFlags", "HudFontSize",
  }) do S[name] = noop end

  S.Token = function(name) return NS.SKIN_FALLBACK[name] end
  S.Color = color
  S.Resolve = function(kind, value, fromSkin)
    if fromSkin or value == S.FROM_SKIN then return S.Token(kind) end
    return value
  end
  S.OnLooksChanged = function(fn) return fn end   -- the skin never changes without the library
  S.IsEnabled = function() return false end
  S.GetStyle = function() return "ka0s:" .. DEFAULT end
  S.GetFont = function() return STANDARD_TEXT_FONT end
  S.ChartStyle = function() return {} end
  S.BarStyle = function() return {} end
  -- The two primitives whose answer reaches SetFont (LibKa0s v1.82.0), so a no-op's nil is not
  -- enough: FontFlags answers a picked flag as is, and for From skin "OUTLINE" on HUD text but ""
  -- on window text (`where == "window"`), the live library's answer while fonts are ignored, the
  -- closest live match for a stock-look load; HudFontSize a positive stored size as is, else 12.
  -- Nothing in this addon calls either today; they answer so a future caller degrades to a value
  -- rather than to nil.
  S.FontFlags = function(v, where)
    if type(v) == "string" and v ~= S.FROM_SKIN then return v end
    return where == "window" and "" or "OUTLINE"
  end
  S.HudFontSize = function(size)
    local n = tonumber(size)
    return (n and n > 0) and n or 12
  end

  NS.Skin = S
  function NS.ApplySkinChoice() return false, false end
  function NS.ApplySkinIgnore() return false, false end
  function NS.ApplySkinOverride() return false end
  function NS.ApplySkinOutline() return false end
  -- Nothing to paint an AceGUI row with: stock AceGUI, as the client draws it.
  function NS.SkinPaintAce() return false end
  function NS.SkinPaintAceTree() return 0 end
  return
end

-- ── the live seam ────────────────────────────────────────────────────────────────────────────

NS.Skin = Skin:For(addonName)
Skin:RegisterOwner(addonName, {
  label = NS.BRAND,
  get = NS.SkinChoice,
  set = NS.WriteSkinChoice,
})

-- The one line a reload request earns on the path that has no popup of its own (a profile event
-- leaving an EllesmereUI that painted this session). The Skin tab raises the library's popup for
-- its own picks.
local RELOAD_LINE = NS.L and NS.L["Reload your interface (/reload) to finish changing the skin."]
  or "Reload your interface (/reload) to finish changing the skin."

-- The AceGUI rows (SkinAce.lua). The Options instance's owner proxy paints what it creates; these
-- paint what this addon acquires another way: the Panels editor's raw AceGUI handle
-- (settings/PanelEditor.lua, settings/PanelEditorTabs.lua) and AceConfigDialog's Profiles tree
-- (settings/Panel.lua). Calling PaintAce again for the same owner repaints in place, which is how the
-- Panels page's session-held band follows a skin switch. Each guards on the member, so a copy whose
-- SkinAce secondary did not attach paints nothing.
function NS.SkinPaintAce(widget)
  if type(Skin.PaintAce) ~= "function" then return false end
  return Skin:PaintAce(addonName, widget)
end

function NS.SkinPaintAceTree(container)
  if type(Skin.PaintAceTree) ~= "function" then return 0 end
  return Skin:PaintAceTree(addonName, container)
end

function NS.ApplySkinIgnore(panel, fonts)
  if type(Skin.SetIgnore) ~= "function" then return false, false end
  if panel == nil and fonts == nil then panel, fonts = storedIgnore() end
  local changed, reload = Skin:SetIgnore(addonName, panel, fonts)
  if reload and NS.Print then NS.Print(RELOAD_LINE) end
  return changed, reload
end

--- No argument applies the stored overrides; a nil half keeps that half, false or "" clears it
--- (the skin's own). A copy without SetOverride (a Skin major before minor 6) moves nothing.
function NS.ApplySkinOverride(font, texture)
  if type(Skin.SetOverride) ~= "function" then return false end
  if font == nil and texture == nil then font, texture = NS.SkinOverride() end
  return Skin:SetOverride(addonName, font, texture)
end

--- The applied font outline: Skin:SetOutline, live (LibKa0s v1.82.0, Skin minor 9). No argument
--- applies the stored mode; the library reads an unknown mode as "all". A copy without SetOutline
--- (a Skin major before minor 9) moves nothing.
function NS.ApplySkinOutline(mode)
  if type(Skin.SetOutline) ~= "function" then return false end
  if mode == nil then mode = NS.SkinOutline() end
  return Skin:SetOutline(addonName, mode)
end

--- No argument applies the stored pair AND the stored exceptions, overrides and outline
--- (addon:OnInitialize, the profile events); a nil half keeps that half and leaves the rest alone
--- (each Skin tab row).
function NS.ApplySkinChoice(source, skin)
  local whole = source == nil and skin == nil
  if whole then source, skin = NS.SkinChoice() end
  local changed, reload = Skin:SetChoice(addonName, source, skin)
  if reload and NS.Print then NS.Print(RELOAD_LINE) end
  if whole then
    NS.ApplySkinIgnore()
    NS.ApplySkinOverride()
    NS.ApplySkinOutline()
  end
  return changed, reload
end
