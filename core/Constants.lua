local addonName, NS = ...   -- luacheck: ignore addonName
NS.Constants = NS.Constants or {}
local C = NS.Constants

-- ── Frame strata ────────────────────────────────────────────────────────────────
-- The strata a panel may sit in. Values are the literal WoW strata tokens and are STORED, so never
-- rename one; the list is the dropdown's option order, lowest to highest.
--
-- The full set is offered. A backdrop usually wants to be low — LOW is the default, one step above
-- BACKGROUND so a panel sits above the world/parchment art but still under essentially all
-- interface frames — but "which layer" is a judgement about the user's particular UI, not something
-- this addon can make for them. Choosing a high strata is a real choice with a real consequence
-- (the panel covers what is beneath it), and the tooltip says so rather than the list hiding the
-- option.
C.STRATA = {
  "BACKGROUND", "LOW", "MEDIUM", "HIGH",
  "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP",
}

C.STRATA_OPTIONS = {}
for _, s in ipairs(C.STRATA) do
  C.STRATA_OPTIONS[#C.STRATA_OPTIONS + 1] = { value = s, label = s }
end

-- Membership test, so a stored/CLI-supplied strata can be validated without a linear scan at every
-- call site.
C.STRATA_SET = {}
for _, s in ipairs(C.STRATA) do C.STRATA_SET[s] = true end

-- ── Anchor points ───────────────────────────────────────────────────────────────
-- The nine anchor points a panel can be pinned by. Stored values; also the dropdown order, read
-- top-left to bottom-right so the list reads like the screen it describes.
C.POINTS = {
  "TOPLEFT", "TOP", "TOPRIGHT",
  "LEFT", "CENTER", "RIGHT",
  "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT",
}

C.POINT_SET = {}
for _, p in ipairs(C.POINTS) do C.POINT_SET[p] = true end

-- ── Geometry bounds ─────────────────────────────────────────────────────────────
-- Clamps applied by the registry on every write (Registry.Sanitize), so neither the settings UI, the
-- CLI, nor a hand-edited SavedVariables file can produce a panel that cannot be seen or grabbed.
-- A zero-size panel is invisible AND unclickable, which in unlock mode means unrecoverable without
-- editing the SV file — hence a hard floor rather than a warning.
C.MIN_SIZE = 8
C.MAX_SIZE = 4096
C.MIN_BORDER = 0
C.MAX_BORDER = 32
-- How far the border sits from the panel's edge. Positive pushes it OUTWARD (a halo around the
-- panel), negative pulls it INWARD (an inset frame). Bounded symmetrically and modestly: a border
-- offset large enough to detach the border from its panel entirely is a bug report waiting to
-- happen, not a feature.
C.MIN_BORDER_OFFSET = -32
C.MAX_BORDER_OFFSET = 32
C.MIN_GRID = 1
C.MAX_GRID = 128

-- ── Panel record template ───────────────────────────────────────────────────────
-- The shipped shape of a new panel, and the source every field default is read from when an older
-- (or hand-edited) record is missing one. Registry.New copies this; Registry.Sanitize fills gaps
-- from it. There is no second list of "what a panel has" anywhere in the addon.
--
-- Colours are {r, g, b, a} arrays rather than {r=,g=,b=,a=} maps because that is the order every
-- WoW colour setter takes them in, so the record unpacks straight into SetColorTexture.
C.PANEL_TEMPLATE = {
  name        = "Panel",
  enabled     = true,
  width       = 240,
  height      = 120,
  -- CENTER at 0,0 — a new panel appears in the middle of the screen, where it is impossible to miss.
  -- That matters more than the anchor being convenient later: the very next thing a user does is
  -- unlock and drag it somewhere, and a panel that starts pinned to a screen corner can land
  -- underneath other UI and read as "nothing happened".
  point       = "CENTER",
  relPoint    = "CENTER",
  x           = 0,
  y           = 0,
  -- LOW, not BACKGROUND: one step up puts a panel above the world and Blizzard's parchment/backdrop
  -- art while staying under essentially every interface frame — which is what a backdrop wants in
  -- practice. BACKGROUND is still offered for a panel that must sit under absolutely everything.
  strata      = "LOW",
  level       = 0,
  bgColor      = { 0.05, 0.05, 0.07, 0.85 },
  borderColor  = { 0.35, 0.35, 0.40, 1.00 },
  borderSize   = 1,
  borderOffset = 0,
  alpha        = 1.0,

  -- LibSharedMedia names, resolved at render time (Compat.FetchMedia). Stored as NAMES, not paths:
  -- a path would break the moment the user uninstalled the addon that supplied the texture, whereas
  -- an unresolvable name degrades to the flat default and can be re-selected.
  bgTexture     = "Solid",
  borderTexture = "Solid",

  -- Class-colour flags. Each one overrides the RGB of its paired colour field while leaving that
  -- field's ALPHA in force — see C.COLOR_FIELDS.
  bgClassColor     = false,
  borderClassColor = false,

  -- Mouseover fade. When `mouseover` is on the panel sits at `mouseoverAlpha` until the cursor is
  -- over it, then rises to `alpha`. Off by default: a panel that hides itself is a deliberate
  -- choice, not something to surprise a new user with.
  mouseover      = false,
  mouseoverAlpha = 0.0,
}

-- Colour field → the boolean field that class-colours it.
--
-- This map is the generic seam: anything that reads a colour goes through Util.ResolveColor, which
-- consults this table. Adding a colour to a panel later means adding the two fields and ONE row
-- here — the renderer, the CLI, the settings page and the field dump all pick it up with no further
-- edit. Without it, "does this colour support class colour?" would be re-decided at every call site.
C.COLOR_FIELDS = {
  bgColor     = "bgClassColor",
  borderColor = "borderClassColor",
}

-- Field → type, for the CLI's `/pm panel set <name> <field> <value>` coercion and for validation.
-- Derived from the template's own values where the type is unambiguous; colours and media names are
-- called out because a Lua array is a `table` and a media name is a free string with a live list.
C.PANEL_FIELD_TYPE = {
  name = "string", enabled = "boolean",
  width = "number", height = "number", x = "number", y = "number",
  point = "point", relPoint = "point",
  strata = "strata", level = "number",
  borderSize = "number", borderOffset = "number", alpha = "number",
  bgColor = "color", borderColor = "color",
  bgTexture = "media", borderTexture = "media",
  bgClassColor = "boolean", borderClassColor = "boolean",
  mouseover = "boolean", mouseoverAlpha = "number",
}

-- Media field → the LibSharedMedia media type it selects from. Drives both the CLI's validation and
-- the settings page's choice of LSM30_* widget.
C.PANEL_FIELD_MEDIA = {
  bgTexture     = "background",
  borderTexture = "border",
}

-- Ordered field list for `/pm panel <name>`, so the dump reads in a stable, sensible order rather
-- than pairs() order (which is arbitrary and changes between runs).
C.PANEL_FIELD_ORDER = {
  "name", "enabled", "width", "height", "point", "relPoint", "x", "y",
  "strata", "level", "alpha",
  "bgTexture", "bgColor", "bgClassColor",
  "borderTexture", "borderSize", "borderOffset", "borderColor", "borderClassColor",
  "mouseover", "mouseoverAlpha",
}

-- ── Shared media ────────────────────────────────────────────────────────────────
-- The addon registers one entry of its own in each media type: a flat white 8x8, which is what the
-- stock look is drawn with. LSM ships a "Solid" BACKGROUND but no solid BORDER, and a plain 1px
-- outline is both this addon's default appearance and the most useful border it has — so it is
-- registered rather than left to whatever other addons happen to provide.
C.SOLID_TEXTURE = "Interface\\Buttons\\WHITE8X8"
C.SOLID_MEDIA_NAME = "Solid"
-- LibSharedMedia's convention for "draw nothing". Named here rather than spelled inline so the
-- renderer's "is this an explicit no-op?" check and the dropdown's guaranteed entry are the same
-- string.
C.NONE_MEDIA_NAME = "None"

-- What a media field falls back to when its stored name resolves to nothing — because the addon
-- that supplied the texture was uninstalled, or because LibSharedMedia is absent entirely.
C.MEDIA_FALLBACK = {
  background = C.SOLID_MEDIA_NAME,
  border     = C.SOLID_MEDIA_NAME,
}

-- ── Preview mode ────────────────────────────────────────────────────────────────
-- The placeholder panels `/pm preview` stands up (preview-mode). Deliberately three, deliberately
-- offset from centre and from each other: one panel proves the render path, three prove that
-- position, size and colour are all really being applied.
C.PREVIEW_PANELS = {
  { name = "Preview: Chat",    width = 380, height = 160, point = "BOTTOMLEFT",
    relPoint = "BOTTOMLEFT", x = 40,  y = 40,  bgColor = { 0.10, 0.14, 0.22, 0.80 } },
  { name = "Preview: Bars",    width = 460, height = 80,  point = "BOTTOM",
    relPoint = "BOTTOM",     x = 0,   y = 24,  bgColor = { 0.18, 0.10, 0.20, 0.80 } },
  { name = "Preview: Minimap", width = 180, height = 180, point = "TOPRIGHT",
    relPoint = "TOPRIGHT",   x = -30, y = -30, bgColor = { 0.10, 0.20, 0.14, 0.80 } },
}

-- ── Global frame names ──────────────────────────────────────────────────────────
-- Every panel frame is created with a deterministic global name, `PanelMaster_Panel_<slug>`, so
-- another addon (or a WeakAura, or a macro) can anchor to it by name without this addon exposing an
-- API at all:
--
--     myFrame:SetPoint("TOPLEFT", "PanelMaster_Panel_Chat_BG", "TOPLEFT", 4, -4)
--
-- The name is derived from the panel's own name (Util.Slugify), which makes it predictable from the
-- UI rather than something the user has to look up. It also makes the slug part of the addon's
-- PUBLIC contract: renaming a panel changes its frame name and breaks anything anchored to the old
-- one, which is why the settings page shows the frame name next to the panel name.
C.FRAME_NAME_PREFIX = "PanelMaster_Panel_"

-- ── Unlock-mode styling ─────────────────────────────────────────────────────────
-- The overlay a panel wears while unlocked: a gold outline and a centred name label, so a panel that
-- is otherwise near-invisible (low alpha, dark colour) can still be found and grabbed.
C.UNLOCK_OUTLINE_RGB = { 1.00, 0.82, 0.00, 0.90 }
C.UNLOCK_LABEL_RGB   = { 1.00, 0.82, 0.00 }
C.UNLOCK_OUTLINE_PX  = 2

-- ── Media ───────────────────────────────────────────────────────────────────────
-- Vendored monospace font (JetBrains Mono, OFL) used by the debug console and its copy box. A
-- sanctioned styling exception — WoW ships no monospace font object, and the console's aligned
-- `<HH:MM:SS> | [tag]` columns require a fixed-width one (debug-logging-§2).
C.FONT_MONO = "Interface\\AddOns\\PanelMaster\\media\\fonts\\JetBrainsMono-Regular.ttf"

-- Addon logo, shown on the settings landing page (options-ui-§5). WoW cannot load .jpg/.png at
-- runtime, so the shipped runtime asset must be a power-of-two .tga. A missing file renders nothing
-- and raises no error, so treat it as required rather than optional.
C.LOGO_PATH = "Interface\\AddOns\\PanelMaster\\media\\logos\\panelmaster.logo.tga"

-- Solid colour is the shipped default for both the background and the border on purpose: a backdrop
-- panel's job is to be a quiet block behind other frames, and a decorative texture fights the UI it
-- is meant to sit under. Anything else the user has installed is offered through LibSharedMedia (see
-- C.SOLID_MEDIA_NAME and Compat.FetchMedia).
