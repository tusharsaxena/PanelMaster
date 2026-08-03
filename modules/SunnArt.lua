local addonName, NS = ...   -- luacheck: ignore addonName
NS.SunnArt = NS.SunnArt or {}
local S = NS.SunnArt

-- The adapter for user-installed **Sunn - Viewport Art** packs (issue #12).
--
-- Nothing here is redistributed. The player installs SunnArt and whichever art packs they want from
-- CurseForge; this module only DISCOVERS what is already on their disk and offers it in the artwork
-- dropdown. That is why this route carries none of the licensing weight the bundled set does
-- (ARTWORK-01 in docs/pending/LEDGER.md): we never ship, copy or host a single pack byte.
--
-- Discovery, not rendering. This file produces catalog rows and stops; modules/Artwork.lua resolves
-- them and modules/Canvas.lua draws them, through the same seams the bundled catalog uses.
--
-- ── How a Sunn theme is put together ────────────────────────────────────────────
--
-- A theme is a path PREFIX plus a section count. `SunnArtPack2\blackrock` with 3 sections means
-- the files blackrock1.tga, blackrock2.tga and blackrock3.tga, which SunnArt draws edge to edge to
-- make one wide bar. Verified against SunnArt 4.01 (SunnArt_Core.lua:309):
--
--     SetTexture("Interface\\Addons\\" .. themefile .. art)
--
-- Extensionless, and rooted at Interface\Addons rather than at this addon — which is exactly why
-- Artwork's rows grew an absolute `path` field: C.ARTWORK_PATH_PREFIX cannot reach another addon's
-- folder, and a pack lives in its own.
--
-- ── Why the section size is DECLARED ────────────────────────────────────────────
--
-- No pack states its pixel dimensions and no WoW API reports a texture file's source size — the
-- same wall documented at Artwork.CUSTOM_NATIVE_SIZE. SunnArt does not know either: its `length`
-- field is a percentage for pushing art off-screen, not a measurement, and it simply stretches each
-- section to fill whatever bar the user sized.
--
-- So the aspect is an assumption, and it is stated here rather than buried. Every section of every
-- pack inspected is 2:1 — SunnArt 4.01's own five themes and Art Pack 2's five are all 512x256
-- (30 files), and the community SunnArtErgoZPack is 512x256 and 1024x256. 512x256 is therefore the
-- declared native size: right for all of them in ASPECT, which is the only thing the fill math
-- actually consumes, since STATIC/FIT/TILE divide panel size by native size and only the ratio
-- survives. A 4:1 pack would tile at half the frequency a purist wants and nothing worse.
S.SECTION_W = 512
S.SECTION_H = 256

-- Ids are SAVED VARIABLES. `sunn-` namespaces them away from the bundled catalog's derived ids for
-- good, so a bundled piece can never be added later that collides with a pack theme a player has
-- already chosen.
S.ID_PREFIX = "sunn-"

-- SunnArt's own reserved pseudo-theme: a flat color fill, not artwork, and it has no files behind
-- it. Offering it would produce a row whose texture never resolves.
local RESERVED = { solid = true }

-- SunnArt's default when a theme declares no section count (SunnArt_Core.lua:300, `or 3`). Matched
-- rather than chosen, so a theme we discover splits into exactly the sections SunnArt would draw.
local DEFAULT_SECTIONS = 3

local MAX_SECTIONS = 5   -- SunnArt's documented ceiling: "1, 2, 3, 4 or 5 separate sections"

-- Section names read POSITIONALLY, because that is what a section is: SunnArt lays the files out
-- left to right into one bar, so "Blackrock (left)" tells a player which piece they are picking in
-- the only terms that mean anything. "Blackrock 2/3" made them count.
--
-- Only the ends have names that are always true. With more than three sections there is more than
-- one middle, and calling both "(middle)" would put two identical labels in the dropdown — so the
-- middles are numbered from the left once there is any ambiguity to resolve.
local function sectionSuffix(index, total)
  if total <= 1 then return nil end
  if index == 1 then return "left" end
  if index == total then return "right" end
  if total == 3 then return "middle" end
  return "middle " .. (index - 1)
end

-- ── Reading what is installed ───────────────────────────────────────────────────

-- The four places a theme can be registered, read directly rather than through
-- `SunnArt:GetThemeList()`.
--
-- Calling SunnArt's own builder would be the shorter line and is the wrong call: it MUTATES
-- SunnArt.ThemeDB, sorts its index and fires ImportThemes as a side effect. Reading another addon's
-- state is safe; driving its rebuild from our load path makes us a participant in its lifecycle,
-- and a bug there becomes a bug here. The four sources are merged the same way it merges them
-- (SunnArt_Core.lua:110-129), later sources winning, so the result agrees without the coupling.
--
-- Each source is independently optional, which is the whole reason this is a list and not one
-- lookup: community packs self-initialize `SunnArtPack` and work with no SunnArt installed at all,
-- while the official packs 1-6 write into SunnArt's options table and hard-depend on it.
local function sources()
  local out = {}

  -- Community packs (SunnArtErgoZPack and friends): `if not SunnArtPack then SunnArtPack = ... end`
  local pack = rawget(_G, "SunnArtPack")
  if type(pack) == "table" and type(pack.theme) == "table" then
    out[#out + 1] = { names = pack.theme, panels = pack.panels }
  end

  -- SunnArt/CustomTheme.lua, hand-edited by the player.
  local custom = rawget(_G, "SunnCustomTheme")
  if type(custom) == "table" then
    out[#out + 1] = { names = custom, panels = rawget(_G, "SunnCustomPanels") }
  end

  local sunn = rawget(_G, "SunnArt")
  if type(sunn) == "table" then
    local db = type(sunn.ThemeDB) == "table" and sunn.ThemeDB or nil
    -- The official packs' registration surface: SunnArtPack2.lua is five lines of
    -- `SunnArt.options.args.theme.values[path] = "Name"` and nothing else.
    local opts = sunn.options and sunn.options.args and sunn.options.args.theme
    if opts and type(opts.values) == "table" then
      out[#out + 1] = { names = opts.values, panels = db and db.panels }
    end
    -- Themes the player built in SunnArt's own Advanced options screen.
    if type(sunn.db) == "table" and type(sunn.db.global) == "table"
      and type(sunn.db.global.themes) == "table" then
      out[#out + 1] = { names = sunn.db.global.themes, panels = sunn.db.global.panels }
    end
  end

  return out
end

-- Is anything Sunn-shaped installed at all? Used to keep the whole feature silent on a machine
-- without it — no category, no rows, no settings copy about an addon the player does not have.
function S.Installed()
  return #sources() > 0
end

-- The pack folder a theme lives in, which is what groups the dropdown: `SunnArtPack2\blackrock`
-- gives "SunnArtPack2". It is the only grouping key a theme carries — there is no pack metadata to
-- read — and it is stable, because it IS the addon folder name.
local function folderOf(file)
  return file:match("^([^\\/]+)") or "Sunn"
end

-- `SunnArtPack2` -> "Sunn: Art Pack 2". Cosmetic only: the folder name is what the dropdown would
-- otherwise show, and "SunnArtPack2" reads like a path rather than a group.
local function prettyFolder(folder)
  local n = folder:match("^SunnArtPack(%d+)$")
  if n then return "Art Pack " .. n end
  if folder == "SunnArt" then return "Built in" end
  return (folder:gsub("^SunnArt", ""):gsub("Pack$", " Pack"))
end

-- ── Row synthesis ───────────────────────────────────────────────────────────────

-- A theme path -> the id stem it contributes. Lowercased and punctuation-collapsed exactly the way
-- the bundled catalog's ids are built (tools/artwork/update_catalog.py's slug), so both halves of
-- the dropdown read as one id scheme rather than two.
local function slug(file)
  local s = file:gsub("[^%w]+", "-")
  return s:gsub("%-+", "-"):gsub("^%-", ""):gsub("%-$", ""):lower()
end

-- Every theme installed, as {file, name, sections, folder}, in a fixed order.
--
-- Sorted by (folder, name, file) for the same reason the catalog sorts by (category, label, id):
-- these come out of hash tables, whose iteration order is an accident that can differ between
-- sessions, and a dropdown that reshuffles itself between logins looks broken.
function S.Themes()
  local seen, list = {}, {}
  for _, src in ipairs(sources()) do
    for file, name in pairs(src.names) do
      if type(file) == "string" and file ~= "" and not RESERVED[file] and type(name) == "string" then
        local sections = tonumber(src.panels and src.panels[file]) or DEFAULT_SECTIONS
        sections = math.floor(sections)
        if sections < 1 then sections = 1 elseif sections > MAX_SECTIONS then sections = MAX_SECTIONS end
        -- Later sources win, matching SunnArt's own merge order, so a player's in-game override of
        -- a pack theme is what they see here too.
        if seen[file] then
          seen[file].name, seen[file].sections = name, sections
        else
          seen[file] = { file = file, name = name, sections = sections, folder = folderOf(file) }
          list[#list + 1] = seen[file]
        end
      end
    end
  end

  table.sort(list, function(a, b)
    if a.folder ~= b.folder then return a.folder < b.folder end
    if a.name ~= b.name then return a.name < b.name end
    return a.file < b.file
  end)
  return list
end

-- The absolute texture path of one section. Extensionless and rooted at Interface\Addons, which is
-- the form SunnArt itself uses and the form WoW resolves against any addon's folder.
function S.SectionPath(file, index)
  return "Interface\\Addons\\" .. file .. index
end

-- Every installed theme as catalog rows, ready to append to Artwork.Catalog.
--
-- Each theme yields BOTH shapes, which is the decision this feature was built around:
--
--   * one row PER SECTION — "Blackrock 1/3" — each a plain single texture that every existing fill,
--     rotation, flip and tint path already handles with no special case whatsoever.
--   * one COMPOSED row — "Blackrock (full bar)" — carrying `sections` and the section path list, so
--     the renderer can lay the strips out edge to edge and reproduce the bar the theme was drawn to
--     be. This is the only row shape in the addon that is not one texture, and the composite path
--     is scoped to it alone: a bundled piece or a Custom path never reaches it.
--
-- A one-section theme yields only the composed row's equivalent — the single section IS the whole
-- bar, and offering the same texture twice under two names would be noise.
function S.Rows(themes)
  local rows = {}
  for _, theme in ipairs(themes or S.Themes()) do
    local category = "Sunn -> " .. prettyFolder(theme.folder)
    local stem = S.ID_PREFIX .. slug(theme.file)

    local paths = {}
    for i = 1, theme.sections do paths[i] = S.SectionPath(theme.file, i) end

    if theme.sections > 1 then
      for i = 1, theme.sections do
        rows[#rows + 1] = {
          id       = stem .. "-" .. i,
          category = category,
          label    = ("%s (%s)"):format(theme.name, sectionSuffix(i, theme.sections)),
          path     = paths[i],
          w        = S.SECTION_W,
          h        = S.SECTION_H,
        }
      end
    end

    -- The composed row wears the theme's BARE name, so the whole bar is what a player finds when
    -- they scan for "Blackrock" and the pieces read as qualified variants of it. That is the right
    -- way round: the bar is the thing the theme was drawn to be, and the sections are the parts.
    rows[#rows + 1] = {
      id       = stem .. (theme.sections > 1 and "-bar" or ""),
      category = category,
      label    = theme.name,
      path     = paths[1],
      -- The composed row's native size is the bar's, not a section's: sections sit side by side, so
      -- the width multiplies and the height does not. Getting this wrong would make FIT and TILE
      -- treat a 3:1 bar as a 2:1 strip.
      w        = S.SECTION_W * theme.sections,
      h        = S.SECTION_H,
      sections = theme.sections > 1 and paths or nil,
    }
  end
  return rows
end

-- Append every discovered row to the artwork catalog.
--
-- Idempotent: a second call replaces the previously injected rows rather than duplicating them, so
-- a re-scan after the player enables a pack and reloads cannot grow the dropdown twice. The bundled
-- rows are identified by NOT carrying our prefix, so nothing but our own additions is ever removed.
function S.Inject()
  local catalog = NS.Artwork and NS.Artwork.Catalog
  if type(catalog) ~= "table" then return 0 end

  for i = #catalog, 1, -1 do
    local id = catalog[i].id
    if type(id) == "string" and id:sub(1, #S.ID_PREFIX) == S.ID_PREFIX then
      table.remove(catalog, i)
    end
  end

  local themes = S.Themes()
  local rows = S.Rows(themes)
  for _, row in ipairs(rows) do catalog[#catalog + 1] = row end

  NS.Debug("Artwork", "Sunn adapter: %d themes, %d rows", #themes, #rows)
  return #rows
end
