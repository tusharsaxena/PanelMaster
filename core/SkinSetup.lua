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
--                           overrides, "" for false (the skin's own).
--   NS.ApplySkinIgnore(p,f) moves the applied exceptions: `Skin:SetIgnore`, live; no argument
--                           applies the stored pair, a nil half keeps that half.
--   NS.SkinOverride()       the stored overrides: font, texture, each an LSM key or false for the
--                           skin's own; false, false before NS:InitDB.
--   NS.ApplySkinOverride(f,t) moves the applied overrides: `Skin:SetOverride`, live; no argument
--                           applies the stored pair, a nil half keeps that half, false or "" clears.
--   NS.ApplySkinChoice(s,k) moves the applied skin: `Skin:SetChoice`, which resolves, repaints
--                           every frame recorded for this owner and THEN fires OnLooksChanged. No
--                           argument applies the stored pair (addon:OnInitialize, the profile
--                           events), and with it the stored exceptions and overrides; a nil half
--                           keeps that half (each Skin tab row's onChange).
--   NS.SKIN_SOURCE_OPTIONS  the source row's values, and NS.SKIN_OPTIONS the skin row's (every
--   NS.SKIN_OPTIONS         registered skin, in the library's order). settings/Schema.lua reads both.
--   NS.SKIN_FALLBACK        the host copy of the Ka0s Default tokens the degraded facade answers.
--   NS.SkinColor(name)      a color token as a call site writes it (three components when opaque),
--                           so a literal that became a token keeps its arity on Ka0s Default.
--   NS.SkinEscape(name)     a color token as a "|cffrrggbb" escape, rounded to the byte, so markup
--                           written as a literal keeps its bytes on Ka0s Default (|cff808080).
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
function NS.SkinEscape(name)
  local r, g, b = NS.Skin.Color(name)
  if r == nil then return nil end
  local function byte(v) return math.floor(v * 255 + 0.5) end
  return ("|cff%02x%02x%02x"):format(byte(r), byte(g), byte(b))
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
--- texture = key|false }`: the Skin tab's Font and texture pick and another addon's copy both hand
--- it here, after Skin:SetOverride moved the applied pair, so each row's onChange re-applies its
--- own half as a no-op.
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
  end
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
  -- tests/test_surface_parity.lua holds this table to the live facade key for key.
  for _, name in ipairs({
    "Shell", "Panel", "Inset", "FadeRegions", "FadeNineSlice", "Button", "WhiteButtonLabel",
    "StateButtonLabel", "EditBox", "Checkbox", "Dropdown", "ScrollBar", "Tab", "SetTabSelection",
    "CloseButton", "PageButton", "SquareIcon", "SortHeaderBar", "Font", "White", "ApplyBarFill",
    "GetAccentColor", "GetPanelColor", "GetFont",
    "TitleBar", "Divider", "Footer", "Card", "Slider", "NavItem", "Drawer", "ListRow", "MenuFrame",
    "Tooltip", "Strip", "Cover", "Text", "ChartStyle", "BarStyle", "IconBorder", "GlowColor",
    "BarTexture",
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

  NS.Skin = S
  function NS.ApplySkinChoice() return false, false end
  function NS.ApplySkinIgnore() return false, false end
  function NS.ApplySkinOverride() return false end
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

--- No argument applies the stored pair AND the stored exceptions and overrides (addon:OnInitialize,
--- the profile events); a nil half keeps that half and leaves the rest alone (each Skin tab row).
function NS.ApplySkinChoice(source, skin)
  local whole = source == nil and skin == nil
  if whole then source, skin = NS.SkinChoice() end
  local changed, reload = Skin:SetChoice(addonName, source, skin)
  if reload and NS.Print then NS.Print(RELOAD_LINE) end
  if whole then
    NS.ApplySkinIgnore()
    NS.ApplySkinOverride()
  end
  return changed, reload
end
