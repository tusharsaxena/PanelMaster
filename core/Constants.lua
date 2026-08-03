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
  -- `text` is what LibKa0s reads (both LibKa0s-Slash-1.0's parser and the Options widget makers
  -- read an ordered enum array on { value =, text = }); `label` is what settings/PanelEditor.lua
  -- reads for the dropdowns it draws by hand. Both are written, rather than one being renamed, so
  -- neither reader has to know about the other.
  C.STRATA_OPTIONS[#C.STRATA_OPTIONS + 1] = { value = s, label = s, text = s }
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

-- ── Panel edges ─────────────────────────────────────────────────────────────────
-- The four edges an accent bar can be drawn on. Stored as the keys of a SET
-- (`accentEdges = { TOP = true }`) rather than a single value, because any combination is legal —
-- a bar on the top and the left at once is a perfectly ordinary look.
--
-- The array is the display/serialization order, so `/pm panel X accentEdges` always prints its
-- edges in the same order regardless of how the set was built.
C.EDGES = { "TOP", "BOTTOM", "LEFT", "RIGHT" }

C.EDGE_SET = {}
for _, e in ipairs(C.EDGES) do C.EDGE_SET[e] = true end

C.EDGE_LABEL = { TOP = "Top", BOTTOM = "Bottom", LEFT = "Left", RIGHT = "Right" }

-- How an accent bar's texture is oriented on each edge.
--
-- A LibSharedMedia STATUSBAR texture is authored as a HORIZONTAL bar: its height carries the bevel
-- (lit along the top, shaded along the bottom) and its width is the fill direction. Stretched into a
-- tall thin LEFT/RIGHT bar with no rotation, that bevel runs along the bar's LENGTH instead of
-- across its thickness — which is why a vertical bar used to read as a vertical smear rather than an
-- edge, while the TOP and BOTTOM bars looked correct.
--
-- These are the EIGHT-argument SetTexCoord form, which maps a texture-space coordinate to each
-- screen corner in the order UL, LL, UR, LR. That form is what makes a true rotation possible at
-- all: the familiar four-argument form can only crop and flip, never transpose the axes.
--
-- LEFT and RIGHT take the SAME rotation rather than mirrored ones, matching TOP and BOTTOM, which
-- are also drawn identically rather than flipped. Mirroring the pair would light the two sides
-- symmetrically, which is a defensible look but a different decision from this one.
C.ACCENT_TEXCOORD_FLAT  = { 0, 0, 0, 1, 1, 0, 1, 1 }   -- as authored
C.ACCENT_TEXCOORD_ROT90 = { 0, 1, 1, 1, 0, 0, 1, 0 }   -- 90 degrees clockwise

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
-- Accent-bar bounds. Thickness has a floor of 1 rather than 0 — "no bar" is what the enable switch
-- and the edge set are for, and a 0px bar would be an invisible third way of saying it.
C.MIN_ACCENT_THICKNESS = 1
C.MAX_ACCENT_THICKNESS = 32
C.MIN_ACCENT_OFFSET = -32
C.MAX_ACCENT_OFFSET = 32
C.MIN_GRID = 1
C.MAX_GRID = 128
-- The range the editor's X/Y sliders span. NOT a clamp: Registry.Sanitize deliberately does not
-- bound offsets (a multi-monitor layout legitimately carries large ones), so this is only how far
-- the slider can reach, and it is named here so the panel cannot invent its own number.
C.EDITOR_OFFSET_RANGE = 2000

-- ── Artwork ─────────────────────────────────────────────────────────────────────
-- There is deliberately no fixed category list here any more.
--
-- Categories are DERIVED from the folder a piece of art sits in under media/artwork/, by
-- tools/artwork/update_catalog.py, and are written into the catalog rows it generates:
-- media/artwork/faction/expansion/12-midnight/harati.tga becomes the category
-- "Faction -> Expansion -> 12 Midnight". A fixed list here could only ever be a second opinion
-- about the same thing, and would have to be edited every time somebody adds a folder — which is
-- exactly the drift the generator exists to remove.
--
-- Artwork.List therefore sorts categories alphabetically rather than by a declared rank. That
-- ordering is stable, needs no maintenance, and keeps a folder's children adjacent to it because
-- a child's category string starts with its parent's.

-- Where bundled artwork lives. A catalog row carries a bare file STEM and the full path is
-- rebuilt here at render time, so moving the art (or renaming the folder) is a one-line change
-- rather than an edit to every row.
C.ARTWORK_PATH_PREFIX = "Interface\\AddOns\\PanelMaster\\media\\artwork\\"

-- The two reserved artTexture values that are not catalog ids. They are stored strings like any
-- other id, so they are named here rather than spelled inline at the half-dozen places that have to
-- ask "is any artwork selected?" and "is this the user's own file?".
C.ARTWORK_NONE   = "None"
C.ARTWORK_CUSTOM = "Custom"

-- How the art is sized inside the panel. STATIC draws it at its authored pixel size, STRETCH
-- distorts it to the panel exactly, FILL covers the panel and crops the overflow, FIT contains the
-- whole image inside the panel, TILE repeats it. Stored tokens — never rename one.
--
-- STRETCH deliberately ignores artScale: stretching IS "match the panel exactly", so a scaled
-- stretch is really FILL or STATIC depending on which the user meant.
C.ART_FILL = { "STATIC", "STRETCH", "FILL", "FIT", "TILE" }

-- Quarter turns only, and NUMBERS rather than strings, because the value is arithmetic (the spec
-- applies the transpose `artRotation / 90` times) and a numeric field also survives a hand-typed
-- `/pm panel set ... artRotation 180` without a string/number mismatch.
--
-- Only quarter turns are offered. An eight-argument SetTexCoord can express an exact axis transpose
-- with no resampling; an arbitrary angle applied to a CROPPED quad samples outside 0..1 and smears
-- the edge pixels across the corners under CLAMP.
C.ART_ROTATION = { 0, 90, 180, 270 }

-- Where the art sits in the panel's frame ladder. Three choices rather than two because artwork is
-- used both as a watermark under everything and as a logo over everything, and which one a given
-- piece wants is not something the addon can guess.
C.ART_LAYER = { "BELOW_BG", "ABOVE_BG", "ABOVE_ALL" }

-- How the artwork's pixels combine with what is behind them. Two of WoW's five modes, and only two.
--
-- The full set is DISABLE, BLEND, ALPHAKEY, ADD and MOD. Three of them cannot be right for art
-- defined by its alpha channel. DISABLE ignores alpha outright and draws the whole square. MOD
-- multiplies, which needs a transparent region to be WHITE to be a no-op. ALPHAKEY thresholds alpha
-- to on/off, which both destroys the antialiased edge and defeats the opacity slider by drawing
-- whatever survives fully opaque.
--
-- This was once a hard-coded constant, on the reasoning that MOD wants transparency white while ADD
-- wants it black and one texture cannot satisfy both. That stalemate is over: every plate
-- tools/artwork/artwork_cleaner.py produces has its transparent pixels normalized to (0,0,0,0), so
-- black is the answer, ADD is correct BY CONSTRUCTION, and MOD is permanently wrong. Blizzard's own
-- UI has used only BLEND and ADD since 2.2.0, and WeakAuras ships exactly these two.
C.ART_BLEND = { "BLEND", "ADD" }

-- All four artwork enums need the same three shapes: the ordered array (dropdown order and the
-- "expected one of: ..." error text), a membership set for validation, and a {value=, label=}
-- option list for the settings widgets. Building them by hand four times over would be four chances
-- to let the three drift apart, so they are derived from one array plus one parallel label list.
local function enumTables(values, labels)
  local set, options = {}, {}
  for i = 1, #values do
    set[values[i]] = true
    options[i] = { value = values[i], label = labels[i] }
  end
  return set, options
end

C.ART_FILL_SET, C.ART_FILL_OPTIONS = enumTables(C.ART_FILL, {
  "Native size", "Stretch", "Fill (crop)", "Fit (contain)", "Tile",
})

-- The degree sign is written as its decimal escape: this file is read by tooling that does not
-- promise a UTF-8 locale, and a mangled label would ship silently.
C.ART_ROTATION_SET, C.ART_ROTATION_OPTIONS = enumTables(C.ART_ROTATION, {
  "0\194\176", "90\194\176", "180\194\176", "270\194\176",
})

C.ART_LAYER_SET, C.ART_LAYER_OPTIONS = enumTables(C.ART_LAYER, {
  "Behind background", "Above background", "Above border and accent",
})

-- Labeled for what they LOOK like rather than what the API calls them. "Glow" is the name
-- WeakAuras uses for ADD, so anyone arriving from there recognizes it immediately; "Opaque" is its
-- name for BLEND and is avoided here because standard alpha blending is not opaque at all.
C.ART_BLEND_SET, C.ART_BLEND_OPTIONS = enumTables(C.ART_BLEND, {
  "Normal", "Glow",
})

-- Artwork scale bounds. The floor is not 0: a zero-scale image is invisible, which is what
-- artTexture = "None" already says, and an invisible-but-selected artwork reads as a bug. The
-- ceiling is generous because FILL and STATIC legitimately zoom well past the panel.
C.MIN_ART_SCALE = 0.1
C.MAX_ART_SCALE = 4.0

-- The panel's frame ladder, as offsets from the panel frame's OWN GetFrameLevel(). The three
-- artwork levels are spread apart rather than consecutive because artwork has to INTERLEAVE with
-- the background, the border and the accent bars — each of the six things below needs a level of
-- its own, in this exact order, or "behind the background" and "above the accent" cannot both be
-- expressible at once. There is still only one art frame; its level is reassigned per render.
--
-- BELOW_BG is why the background fill lives on its own child frame rather than on the panel: a
-- child frame always draws above its parent's own textures whatever draw layer they use, so with
-- the fill on the panel itself there is no level a child could take to get underneath it.
C.ART_FRAME_LEVEL = { BELOW_BG = 1, ABOVE_BG = 3, ABOVE_ALL = 6 }
C.BG_FRAME_LEVEL     = 2
C.BORDER_FRAME_LEVEL = 4
C.ACCENT_FRAME_LEVEL = 5

-- The unlock overlay, above EVERY rung above — including ABOVE_ALL artwork. It has to be the top of
-- the stack by definition: its whole job is to be findable on a panel you would otherwise not be
-- able to see, so anything that could cover it defeats it. This is also the ceiling of a panel's
-- frame-level footprint, and C.PANEL_LEVEL_STRIDE is derived from it.
C.UNLOCK_FRAME_LEVEL = 7

-- How far apart two panels' frame levels are placed, so one panel's whole stack clears the next
-- one's. A panel occupies base .. base + C.UNLOCK_FRAME_LEVEL, so the stride is that plus one.
--
-- Without it the user's `level` is used as a raw frame level and the stacks INTERLEAVE: a panel at
-- level 0 puts its accent bar at base+5 while a panel at level 3 puts its background fill at the
-- same 5, and which one wins falls back to frame creation order — which, because Canvas pools
-- frames by name, is not even panel order. The level setting says "higher draws in front"; without
-- a stride that is only true when the numbers happen to differ by more than the footprint.
--
-- This was always partly broken (the old three-rung footprint made levels 1 and 2 apart collide
-- too) and artwork widened the footprint enough to matter. Multiplying is the fix for both: every
-- DISTINCT level now separates cleanly, which is what the setting has always claimed.
--
-- Bounded safely: a panel's level is clamped to 100 (Registry.Sanitize, Canvas.BuildSpec), so the
-- highest frame level this can produce is 800 — far under the client's per-strata ceiling.
C.PANEL_LEVEL_STRIDE = C.UNLOCK_FRAME_LEVEL + 1

-- ── Panel record template ───────────────────────────────────────────────────────
-- The shipped shape of a new panel, and the source every field default is read from when an older
-- (or hand-edited) record is missing one. Registry.New copies this; Registry.Sanitize fills gaps
-- from it. There is no second list of "what a panel has" anywhere in the addon.
--
-- Colors are {r, g, b, a} arrays rather than {r=,g=,b=,a=} maps because that is the order every
-- WoW color setter takes them in, so the record unpacks straight into SetColorTexture.
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
  -- No panel border out of the box. The shipped look leans on the accent bar for definition
  -- instead, and a panel wearing both an outline and a bar reads as busy rather than framed. The
  -- color above is kept so raising the size gives something sensible immediately.
  borderSize   = 0,
  borderOffset = 0,
  alpha        = 1.0,

  -- LibSharedMedia names, resolved at render time (Compat.FetchMedia). Stored as NAMES, not paths:
  -- a path would break the moment the user uninstalled the addon that supplied the texture, whereas
  -- an unresolvable name degrades to the flat default and can be re-selected.
  bgTexture     = "Solid",
  borderTexture = "Solid",

  -- Class-color flags. Each one overrides the RGB of its paired color field while leaving that
  -- field's ALPHA in force — see C.COLOR_FIELDS.
  bgClassColor     = false,
  borderClassColor = false,

  -- Mouseover fade. When `mouseover` is on the panel sits at `mouseoverAlpha` until the cursor is
  -- over it, then rises to `alpha`. Off by default: a panel that hides itself is a deliberate
  -- choice, not something to surprise a new user with.
  mouseover      = false,
  mouseoverAlpha = 0.0,

  -- ── Accent bar ──
  -- A thin detached strip along one or more of the panel's edges, in the style of BenikUI's panels.
  -- Purely decorative: it is drawn as textures on the panel's own frame, so it inherits the panel's
  -- strata, level and alpha, and it is as click-through as everything else here.
  --
  -- ON by default: the accent bar IS the shipped look. A new panel arrives as a dark block with a
  -- class-colored strip along its top rather than a plain rectangle, so the addon shows what it is
  -- for without the user having to go and find the switch. The panel's own border is off to
  -- compensate (see borderSize above) — one piece of definition, not two.
  accentEnabled   = true,
  -- A SET, not a single edge — any combination is legal. Top alone is the BenikUI look and the
  -- default. An empty set is valid and draws nothing, so unticking every edge does not silently
  -- re-tick one.
  accentEdges     = { TOP = true },
  -- Drawn from LibSharedMedia's STATUSBAR pool rather than `background`: statusbar textures are
  -- authored to be read as thin horizontal strips, which is exactly what this is, and it is the pool
  -- a user has already curated for their bars.
  --
  -- "Blizzard" is LibSharedMedia's OWN default statusbar, so it resolves on any install and gives
  -- the bar a slight sheen rather than the flat block "Solid" produces.
  accentTexture   = "Blizzard",
  accentThickness = 5,
  -- Flush against the panel by default. The bar reads as part of the panel's frame rather than as a
  -- separate floating strip; push the offset positive for the detached look instead.
  accentOffset    = 0,
  -- Class color is ON by default, so the bar picks up the wearer's color with no configuration.
  -- The stored color underneath is pure white, which is what shows the moment class color is
  -- switched off: neutral against any panel, and the honest "no color chosen yet" answer. It was
  -- the BenikUI green, which looked deliberate without anyone having chosen it.
  accentColor      = { 1.00, 1.00, 1.00, 1.00 },
  accentClassColor = true,

  -- The accent bar's OWN border, mirroring the panel's. Size 0 by default: the bar is already a
  -- decoration, and outlining it unasked would change the look of every accent bar the moment the
  -- feature shipped. Shares the panel border's bounds, so the two sliders read alike.
  accentBorderTexture   = "Solid",
  -- A 1px black outline around the bar. Black rather than the panel border's gray because its job is
  -- to SEPARATE the bar from whatever is behind it — against a bright background a bare class color
  -- bleeds into the scenery, and a dark hairline restores the edge whatever the class color is.
  accentBorderSize      = 1,
  accentBorderOffset    = 0,
  accentBorderColor     = { 0.00, 0.00, 0.00, 1.00 },
  accentBorderClassColor = false,

  -- ── Artwork ──
  -- A texture layer drawn within the panel's bounds: a bundled catalog piece, or the user's own
  -- file. Everything about it is per-panel, because artwork is the one part of a panel that is
  -- purely taste — the same layout wants a faction crest on one panel and nothing on the next.
  --
  -- Stored as a catalog ID, never as a path. A stored path is only true until the addon that
  -- supplied the file is uninstalled or its folder is renamed, and then the record points at
  -- nothing with no way back; an ID that no longer resolves degrades to "no artwork" and can be
  -- re-picked from the list. This is the same reasoning that makes bgTexture store a
  -- LibSharedMedia NAME rather than the path that name currently resolves to.
  --
  -- "None" by default, and that default is load-bearing: every panel that predates this feature —
  -- and every profile, and every copied record — gains these fields on the next Sanitize, and must
  -- look exactly as it did before. Any other default would silently restyle the user's whole UI on
  -- upgrade.
  artTexture     = "None",
  -- Only consulted when artTexture == "Custom". Kept as its own field rather than overloading
  -- artTexture so that switching to a catalog piece and back does not lose what the user typed.
  artCustomPath  = "",
  -- White, i.e. "show the art as authored" — multiplying by white is a no-op, so the tint does
  -- nothing until the user picks a color. It applies to EVERY piece now, full-color included;
  -- Desaturate is what makes that produce a clean tint rather than mud.
  artColor       = { 1, 1, 1, 1 },
  artClassColor  = false,
  -- Collapses the art to grayscale before the tint multiplies against it. Off by default: it
  -- changes how existing art looks, and no upgrade should restyle a panel the user already had.
  artDesaturate  = false,
  -- Normal alpha compositing. ADD ("Glow") adds the art's color to whatever is behind, which reads
  -- as a lit emblem over a dark panel and cannot darken anything.
  artBlend       = "BLEND",
  -- Art opacity, multiplied on top of the panel's own alpha rather than replacing it, so fading the
  -- panel fades its artwork with it.
  artAlpha       = 1.0,
  -- FIT, not STRETCH: fitting shows the whole image undistorted at any panel size, which is the
  -- only fill type that cannot make a bundled piece look broken on a panel it was not authored for.
  artFill        = "FIT",
  -- Anchor of the art within the panel. Honoured only by the fill types that leave room to move
  -- (STATIC and FIT) — STRETCH, FILL and TILE cover the panel by definition.
  artPoint       = "CENTER",
  artX           = 0,
  artY           = 0,
  artScale       = 1.0,
  artRotation    = 0,
  artFlipH       = false,
  artFlipV       = false,
  -- Above the background but under the border and the accent bar: the panel's own framing stays
  -- legible and the artwork reads as part of the fill rather than as something laid on top of it.
  artLayer       = "ABOVE_BG",
}

-- Color field → the boolean field that class-colors it.
--
-- This map is the generic seam: anything that reads a color goes through Util.ResolveColor, which
-- consults this table. Adding a color to a panel later means adding the two fields and ONE row
-- here — the renderer, the CLI, the settings page and the field dump all pick it up with no further
-- edit. Without it, "does this color support class color?" would be re-decided at every call site.
C.COLOR_FIELDS = {
  bgColor     = "bgClassColor",
  borderColor = "borderClassColor",
  accentColor = "accentClassColor",
  accentBorderColor = "accentBorderClassColor",
  -- Artwork inherits class color for the price of this one row: the tint already resolves through
  -- Util.ResolveColor, so the renderer, the CLI, the settings page and the field dump all pick it
  -- up without a line of new code anywhere.
  artColor    = "artClassColor",
}

-- Field → type, for the CLI's `/pm panel set <name> <field> <value>` coercion and for validation.
-- Derived from the template's own values where the type is unambiguous; colors and media names are
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
  accentEnabled = "boolean", accentEdges = "edges", accentTexture = "media",
  accentThickness = "number", accentOffset = "number",
  accentColor = "color", accentClassColor = "boolean",
  accentBorderTexture = "media", accentBorderSize = "number",
  accentBorderOffset = "number",
  accentBorderColor = "color", accentBorderClassColor = "boolean",
  -- "artwork" is its own kind, validated against the LIVE catalog the same way "media" is
  -- validated against the live LibSharedMedia list — a typo is refused with the real list rather
  -- than stored and silently rendered as nothing. "enum" is the generic closed-list kind; which
  -- list a field belongs to is C.PANEL_FIELD_ENUM below.
  artTexture = "artwork", artCustomPath = "string",
  artColor = "color", artClassColor = "boolean", artAlpha = "number",
  artFill = "enum", artPoint = "point", artX = "number", artY = "number",
  artScale = "number", artRotation = "enum",
  artFlipH = "boolean", artFlipV = "boolean",
  artLayer = "enum", artDesaturate = "boolean", artBlend = "enum",
}

-- Enum field → its ordered list of legal values. One generic "enum" kind driven by this table,
-- rather than five near-identical branches in Registry:Set, so the next closed-list field costs a
-- row here and nothing else. The array order is also the order the rejection message lists.
C.PANEL_FIELD_ENUM = {
  artFill     = C.ART_FILL,
  artRotation = C.ART_ROTATION,
  artLayer    = C.ART_LAYER,
  artBlend    = C.ART_BLEND,
}

-- Media field → the LibSharedMedia media type it selects from. Drives both the CLI's validation and
-- the settings page's choice of LSM30_* widget.
C.PANEL_FIELD_MEDIA = {
  bgTexture     = "background",
  borderTexture = "border",
  accentTexture = "statusbar",
  accentBorderTexture = "border",
}

-- Ordered field list for `/pm panel <name>`, so the dump reads in a stable, sensible order rather
-- than pairs() order (which is arbitrary and changes between runs).
C.PANEL_FIELD_ORDER = {
  "name", "enabled", "width", "height", "point", "relPoint", "x", "y",
  "strata", "level", "alpha",
  "bgTexture", "bgColor", "bgClassColor",
  "borderTexture", "borderSize", "borderOffset", "borderColor", "borderClassColor",
  "mouseover", "mouseoverAlpha",
  "accentEnabled", "accentEdges", "accentTexture", "accentThickness", "accentOffset",
  "accentColor", "accentClassColor",
  "accentBorderTexture", "accentBorderSize", "accentBorderOffset",
  "accentBorderColor", "accentBorderClassColor",
  "artTexture", "artCustomPath", "artColor", "artClassColor", "artAlpha",
  "artDesaturate", "artBlend",
  "artFill", "artPoint", "artX", "artY", "artScale",
  "artRotation", "artFlipH", "artFlipV", "artLayer",
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
  statusbar  = C.SOLID_MEDIA_NAME,
}

-- ── Preview mode ────────────────────────────────────────────────────────────────
-- The placeholder panels `/pm preview` stands up (preview-mode). Deliberately three, deliberately
-- offset from center and from each other: one panel proves the render path, three prove that
-- position, size and color are all really being applied.
-- The field a preview placeholder carries in the registry. Preview panels are REAL records (that is
-- what makes preview exercise the real render path, preview-mode) but they are not the user's work,
-- so they must not survive a reload. The marker is the durable half of the pair whose session half
-- is NS.State.previewIDs: ids are lost on /reload, this is not.
--
-- Deliberately absent from PANEL_FIELD_TYPE, PANEL_FIELD_ORDER and PANEL_TEMPLATE, so the CLI cannot
-- set it, `/pm panel <name>` does not print it, and a normally-created panel never carries it.
C.PREVIEW_FIELD = "preview"

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
-- The name is derived from the panel's name (Util.Slugify) AT CREATE TIME and then stored on the
-- record, which makes it predictable when you make the panel rather than something you have to look
-- up. From that moment it is identity, like the panel's id: a rename relabels the panel and leaves
-- the frame name alone, so anything anchored to it stays anchored.
--
-- The trade that buys: after a rename the frame name no longer matches the panel's name and stops
-- being derivable from it. That is deliberate. The alternative — recomputing it — is what used to
-- orphan every external anchor the moment somebody renamed a panel, silently and with no migration
-- possible, because a frame's name is immutable after CreateFrame. The settings page shows the
-- current frame name on the name box's tooltip, which is where you look it up after a rename.
C.FRAME_NAME_PREFIX = "PanelMaster_Panel_"

-- ── Unlock-mode styling ─────────────────────────────────────────────────────────
-- The overlay a panel wears while unlocked: a gold outline and a centered name label, so a panel that
-- is otherwise near-invisible (low alpha, dark color) can still be found and grabbed.
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

-- Solid color is the shipped default for both the background and the border on purpose: a backdrop
-- panel's job is to be a quiet block behind other frames, and a decorative texture fights the UI it
-- is meant to sit under. Anything else the user has installed is offered through LibSharedMedia (see
-- C.SOLID_MEDIA_NAME and Compat.FetchMedia).
