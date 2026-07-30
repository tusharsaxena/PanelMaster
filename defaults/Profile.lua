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
    -- Master switch. Off hides every panel without deleting anything, which is the fast way to see
    -- the UI underneath.
    enabled     = true,

    -- Snap-to-grid for the unlock-mode drag. gridSize is in UI units; 1 means no snapping.
    snapToGrid  = true,
    gridSize    = 4,

    -- Show each panel's name in the middle of it while unlocked. On by default: with several
    -- similar dark rectangles on screen, the label is what tells you which one you have hold of.
    showLabels  = true,

    -- Applied to newly created panels, so a user who has settled on a house style does not re-set
    -- the same two fields on every panel. Existing panels are never touched by a change here.
    defaultStrata = "LOW",
    defaultAlpha  = 1.0,
  },
  -- debug is session-only (NS.State.debug), never persisted here (debug-logging-§5). So is unlock
  -- state (NS.State.unlocked) — see core/State.lua for why.
}
