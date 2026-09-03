local addonName, NS = ...   -- luacheck: ignore addonName

-- Per-character defaults. Everything the user configures lives here; `global` (defaults/Global.lua)
-- carries only the schema stamp.
NS.defaults = NS.defaults or {}
NS.defaults.profile = {
  -- The panel registry: an array of panel records, in creation order. Ships EMPTY on purpose — a
  -- fresh install draws nothing until the user makes a panel, because an addon whose whole job is
  -- putting opaque blocks on the screen must never put one there uninvited. `/pm preview` is how a
  -- new user sees what a panel looks like without committing to one.
  --
  -- A storage carve-out (architecture-§5): panel records are mutated through NS.Registry, not
  -- through Schema:Set, because each one is a variable-length user-created object rather than a
  -- fixed setting with a widget.
  panels = {},

  -- Monotonic id source for panel records. Kept rather than derived from #panels so an id is never
  -- reused after a delete — a stale reference then resolves to nothing instead of silently
  -- resolving to whatever panel happens to occupy that slot now.
  nextID = 1,

  settings = {
    -- ── The Master controls tab's stored half (options-ui-§15) ──
    -- Declared by LibKa0s-Options-1.0's `MasterControls` composer rather than by a literal row in
    -- settings/Schema.lua; the values live here, which is where savedvariables-§2 says a default
    -- is declared. `locked` is NOT here: it is the session-only unlock state (NS.State.unlocked),
    -- inverted, and is never persisted.

    -- Master switch. Off hides every panel without deleting anything, which is the fast way to see
    -- the UI underneath.
    enabled     = true,

    -- When the panels are drawn at all: "always" / "inCombat" / "outOfCombat" / "never".
    -- "always" is what this addon has always done, so no existing install changes behavior — and
    -- there is no boolean to migrate, because this addon never shipped a "show only in combat"
    -- checkbox for one to be written into.
    visibility  = "always",

    -- Addon-wide multipliers over every panel's OWN scale and opacity. 1 is the identity in both
    -- cases, so an upgrade moves nothing on screen. They are deliberately not folded into the
    -- per-panel fields: the editor's sliders keep showing what the player typed for that panel,
    -- and these two move all of them together.
    scale       = 1.0,
    alpha       = 1.0,

    -- Snap-to-grid for the unlock-mode drag. gridSize is in UI units; 1 means no snapping.
    snapToGrid  = true,
    gridSize    = 4,

    -- How thick the gold outline around an unlocked panel is. Ships at C.UNLOCK_OUTLINE_PX, the
    -- number that used to be the only answer, so nothing an existing install draws moves.
    unlockOutlineSize = 2,

    -- Show each panel's name in the middle of it while unlocked. On by default: with several
    -- similar dark rectangles on screen, the label is what tells you which one you have hold of.
    showLabels  = true,

    -- Applied to newly created panels, so a user who has settled on a house style does not re-set
    -- the same four fields on every panel. Existing panels are never touched by a change here.
    -- Width and height ship at C.PANEL_TEMPLATE's own 240x120, so a panel made by someone who
    -- never opens this tab is exactly the panel this addon always made.
    defaultWidth  = 240,
    defaultHeight = 120,
    defaultStrata = "LOW",
    defaultAlpha  = 1.0,
  },
  -- debug is session-only (NS.State.debug), never persisted here (debug-logging-§5). So is unlock
  -- state (NS.State.unlocked) — see core/State.lua for why.
}
