local addonName, NS = ...   -- luacheck: ignore addonName
NS.SunnArt = NS.SunnArt or {}
local S = NS.SunnArt

-- The adapter for user-installed **Sunn - Viewport Art** packs (issue #12).
--
-- Nothing here is redistributed. The player installs SunnArt and whichever art packs they want from
-- CurseForge; this module only DISCOVERS what is already on their disk and offers it in the artwork
-- dropdown. That is why this route carries none of the licensing weight the bundled set does
-- (ARTWORK-01, closed issue #34): we never ship, copy or host a single pack byte.
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
-- So the aspect is a FALLBACK, and it is only ever reached for a theme nothing has measured.
--
-- SunnArt hard-codes 2:1 for every section of every theme, on all four bars
-- (SunnArt_Core.lua:259):
--
--     h = w * self.db.profile.bar[i].scale / 2
--
-- That `/ 2` is where 512x256 comes from, and it is right for the overwhelming majority — 250 of
-- the 262 section files across the twelve official packs. But it is NOT universally true of the
-- art: eight official themes are authored at something else, five of them SQUARE at 512x512
-- (Pack 6's Fractal, StreamBlue and StreamRed; Pack 9's Wrath and Frostrock) and three at 1024
-- wide. SunnArt draws those squashed, because its own arithmetic cannot express them.
--
-- This is why modules/SunnArtPacks.lua carries MEASURED dimensions and `sectionSize` prefers them
-- for every theme it knows, however that theme was discovered: registration never states a size, so
-- measuring is the only way to draw those eight as authored. These two numbers remain for a theme
-- no one has measured — a community pack, or an official one added after the manifest was last
-- generated — where the format's own assumption is the best available answer.
--
-- Only the ASPECT is consumed either way, since STATIC/FIT/TILE divide panel size by native size
-- and only the ratio survives.
S.SECTION_W = 512
S.SECTION_H = 256

-- ── What `overlap` actually is ──────────────────────────────────────────────────
--
-- Not the overlap BETWEEN sections. Sections are laid flush: SunnArt_Core.lua:322 anchors section
-- n to section n-1's TOPRIGHT, edge to edge, with nothing between them.
--
-- It is the transparent band at the TOP of the artwork, as a percentage of the art's height
-- (CustomTheme.lua:28-33, whose own worked example is 75 transparent pixels of 256 -> 29.297).
-- SunnArt uses it to push that dead band off the panel and over the game world:
--
--     olr = 100 / (100 - overlap)      h = w * scale / 2 * olr      anchor y = h - h / olr
--
-- A PanelMaster panel has no viewport to hang it over, so the band would simply render as nothing.
-- We therefore CROP it instead: a theme declaring 29.297 has an effective native height of
-- 256 * (1 - 0.29297), and its content starts at v = 0.29297 in the file. Nothing visible is lost —
-- the band is transparent by the pack author's own declaration — but autosize, FIT and STATIC then
-- size to the art a player can actually see, rather than reserving 29% of the panel for nothing.
--
-- That is an INTERPRETATION rather than a reproduction of SunnArt, and it is recorded as one in
-- ARTWORK-08, closed issue #39.
--
-- SunnArt's own slider is `min = 0, max = 100, step = 0.01` (SunnArt_Options.lua:799-807), so the
-- stored number is a percentage and is normalized to a fraction here. The clamp is below 1 because
-- 100 is a legal slider value that would crop the art out of existence.
S.MAX_OVERLAP = 0.9

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
    out[#out + 1] = pack.theme
  end

  -- SunnArt/CustomTheme.lua, hand-edited by the player.
  local custom = rawget(_G, "SunnCustomTheme")
  if type(custom) == "table" then
    out[#out + 1] = custom
  end

  local sunn = rawget(_G, "SunnArt")
  if type(sunn) == "table" then
    -- The official packs' registration surface: SunnArtPack2.lua is five lines of
    -- `SunnArt.options.args.theme.values[path] = "Name"` and nothing else.
    local opts = sunn.options and sunn.options.args and sunn.options.args.theme
    if opts and type(opts.values) == "table" then
      out[#out + 1] = opts.values
    end
    -- Themes the player built in SunnArt's own Advanced options screen.
    if type(sunn.db) == "table" and type(sunn.db.global) == "table"
      and type(sunn.db.global.themes) == "table" then
      out[#out + 1] = sunn.db.global.themes
    end
  end

  return out
end

-- Section counts and overlaps merge on their OWN order, which is not the name order above.
--
-- SunnArt itself uses two different orders, and matching only one of them would be wrong half the
-- time. GetThemeList merges NAMES with SunnArtPack first and db.global last (SunnArt_Core.lua:123),
-- while ImportThemes merges panels/overlap the other way round — db.global.panels first, then
-- SunnArtPack.panels OVERWRITING it (SunnArt_Core.lua:132-152). So a pack's declared section count
-- beats a stale entry in the player's saved globals, even though the player's theme NAME wins.
-- Pairing each count table with its name table, as this module first did, silently inverted that.
--
-- SunnCustomPanels / SunnCustomOverlap are last, and that is a deliberate DIVERGENCE from SunnArt
-- rather than a match. CustomTheme.lua:2-3 declares both globals and invites the player to fill
-- them in, and ImportThemes then never reads either — so a player who writes
-- `SunnCustomPanels["SunnArt\\MyArtWork"] = 5` is silently given 3 sections. We honor it, and we
-- honor it last, because a hand-edited file is the only source a human actually typed.
local function meta()
  local panels, overlap = {}, {}

  local function absorb(p, o)
    if type(p) == "table" then for file, v in pairs(p) do panels[file] = v end end
    if type(o) == "table" then for file, v in pairs(o) do overlap[file] = v end end
  end

  local sunn = rawget(_G, "SunnArt")
  if type(sunn) == "table" then
    -- Whatever SunnArt has already merged for itself, if its options screen has ever been opened.
    -- A base rather than an authority: ThemeDB is empty until GetThemeList runs, which is exactly
    -- why this module does not call it.
    if type(sunn.ThemeDB) == "table" then absorb(sunn.ThemeDB.panels, sunn.ThemeDB.overlap) end
    if type(sunn.db) == "table" and type(sunn.db.global) == "table" then
      absorb(sunn.db.global.panels, sunn.db.global.overlaps)   -- `overlaps`, plural, is SunnArt's spelling
    end
  end

  local pack = rawget(_G, "SunnArtPack")
  if type(pack) == "table" then absorb(pack.panels, pack.overlap) end

  absorb(rawget(_G, "SunnCustomPanels"), rawget(_G, "SunnCustomOverlap"))

  return panels, overlap
end

-- The pack folder a theme lives in, which is what groups the dropdown: `SunnArtPack2\blackrock`
-- gives "SunnArtPack2". It is the only grouping key a theme carries — there is no pack metadata to
-- read — and it is stable, because it IS the addon folder name. It is also the ADDON FOLDER NAME,
-- which is what lets the known-pack fallback below ask whether a pack is installed at all.
local function folderOf(file)
  return file:match("^([^\\/]+)") or "Sunn"
end

-- ── The known-pack fallback ─────────────────────────────────────────────────────
--
-- Everything above reads what the packs REGISTERED, which requires their Lua to have run. Every
-- official pack TOC carries `## Dependencies: SunnArt`, and the client enforces that before any Lua
-- executes — so with SunnArt disabled, or broken by a patch, not one theme registers and the whole
-- feature goes quiet. The textures are unaffected: they are ordinary files under
-- `Interface\Addons\`, and drawing one needs no Sunn code at all.
--
-- modules/SunnArtPacks.lua is the list that restores the knowledge, and this is where it is
-- consulted. Two rules keep it from being a second, competing opinion:
--
--   * live registration WINS, per theme. A player who renamed a theme or changed its section count
--     in SunnArt's own options sees their version, not ours.
--   * a theme is offered only when its pack's FOLDER is actually installed. Otherwise the dropdown
--     would advertise 88 themes to someone who has none of them.
--
-- ── The folder gate applies to LIVE discovery too ──────────────────────────────
--
-- Which is not obvious, because a theme that registered must have had its Lua run, so surely its
-- folder is there. Two of the four sources break that:
--
--   * `SunnArt.db.global.themes` is SAVED VARIABLES. A theme the player built in SunnArt's Advanced
--     options survives the pack being deleted, so an uninstalled pack keeps naming itself long
--     after its textures are gone.
--   * `SunnCustomTheme` is a hand-edited file and can name anything at all, including a folder that
--     was never installed or a stem whose files were removed.
--
-- Both produce a dropdown entry that draws nothing, which reads to a player as the addon being
-- broken rather than the art being absent. The roster is the only evidence available — WoW exposes
-- no way to ask whether a texture FILE exists — so the pack folder is checked, and for a manifest
-- theme that is a real check, since the generator verified the files at the time it measured them.
--
-- The gate degrades to "offer it" when the roster cannot be read at all, which is the honest
-- reading of a nil from Compat.AddOnFolders: on a client that cannot answer, offering a theme whose
-- textures may be missing merely draws nothing, while withholding every theme would disable a
-- working feature outright.
local function folderInstalled(folders, file)
  if not folders then return true end
  return folders[folderOf(file)] and true or false
end

local function addonFolders()
  return NS.Compat and NS.Compat.AddOnFolders and NS.Compat.AddOnFolders() or nil
end

-- Is anything Sunn-shaped installed at all? Used to keep the whole feature silent on a machine
-- without it — no category, no rows, no settings copy about an addon the player does not have.
--
-- Defined as "does this yield anything to offer" rather than as its own inspection of the globals,
-- so it cannot answer yes to a question the dropdown then answers no to. That drift was reachable:
-- the earlier version returned true whenever any Sunn global existed, including for a SunnArt whose
-- every theme named an uninstalled pack.
function S.Installed()
  return #S.Themes() > 0
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

-- A stored overlap percentage -> the fraction of the art's height that is transparent padding.
--
-- Anything unusable — absent, not a number, negative, or beyond the clamp — reads as 0, which is
-- the identity everywhere downstream. A theme with a broken overlap value draws its full art
-- rather than an empty panel.
local function overlapFraction(value)
  local n = tonumber(value)
  if not n or n <= 0 then return 0 end
  n = n / 100
  if n > S.MAX_OVERLAP then return S.MAX_OVERLAP end
  return n
end

-- A theme's section dimensions: measured if the manifest knows this theme, declared otherwise.
--
-- Consulted for EVERY theme, not just the ones the fallback supplied, because the measurement is
-- the one fact registration never carries. SunnArt hard-codes 2:1 and most sections are 512x256 —
-- but eight official themes are not, five of them square, and those are drawn squashed by SunnArt
-- itself. Reading the manifest here is what lets a theme it knows about be drawn at the shape it
-- was actually authored at, however the theme was discovered.
local function sectionSize(file)
  local manifest = NS.SunnArtPacks
  local row = type(manifest) == "table" and manifest[file] or nil
  local w = row and tonumber(row.w)
  local h = row and tonumber(row.h)
  if w and h and w > 0 and h > 0 then return w, h end
  return S.SECTION_W, S.SECTION_H
end

-- A stored section count -> a usable one. Written once because BOTH collection passes below need
-- it, and it used to be written out twice in two different spellings — the same result reached two
-- ways is two things to keep in step.
local function clampSections(value)
  local n = math.floor(tonumber(value) or DEFAULT_SECTIONS)
  if n < 1 then return 1 elseif n > MAX_SECTIONS then return MAX_SECTIONS end
  return n
end

-- Is this (file, name) pair a theme that can be offered at all? A registration is a raw table from
-- another addon, so every part of it is checked: a usable key, not one of SunnArt's own reserved
-- rows, a usable label, and a folder actually on disk.
local function isRegisterable(file, name, folders)
  return type(file) == "string" and file ~= "" and not RESERVED[file] and type(name) == "string"
    and folderInstalled(folders, file)
end

-- Pass one: every theme anything registered live, merged across the sources.
local function collectRegistered(seen, list, folders, panels, overlaps)
  for _, names in ipairs(sources()) do
    for file, name in pairs(names) do
      if isRegisterable(file, name, folders) then
        -- Later sources win, matching SunnArt's own NAME merge order, so a player's in-game
        -- override of a pack theme is what they see here too. Sections and overlap do not vary by
        -- source at all — they come from their own merge, for the reasons at `meta`.
        if seen[file] then
          seen[file].name = name
        else
          seen[file] = {
            file     = file,
            name     = name,
            sections = clampSections(panels[file]),
            overlap  = overlapFraction(overlaps[file]),
            folder   = folderOf(file),
          }
          list[#list + 1] = seen[file]
        end
      end
    end
  end
end

-- Pass two: the known-pack fallback, added only for themes nothing registered. `seen` is the whole
-- test: a theme that registered is already in it, so live registration wins by construction rather
-- than by an ordering rule that could be got backwards.
local function collectKnownPacks(seen, list, folders)
  local manifest = NS.SunnArtPacks
  if type(manifest) ~= "table" then return end
  for file, row in pairs(manifest) do
    if not seen[file] and type(row) == "table" and folderInstalled(folders, file) then
      seen[file] = {
        file     = file,
        name     = type(row.name) == "string" and row.name or file,
        sections = clampSections(row.sections),
        overlap  = overlapFraction(row.overlap),
        folder   = folderOf(file),
        -- Marked so a reader of a theme — and the suite — can tell a live discovery from a
        -- remembered one. Nothing downstream branches on it; the two shapes are identical.
        known    = true,
      }
      list[#list + 1] = seen[file]
    end
  end
end

-- Hoisted out of S.Themes so it is created once at load rather than on every enumeration.
local function byFolderNameFile(a, b)
  if a.folder ~= b.folder then return a.folder < b.folder end
  if a.name ~= b.name then return a.name < b.name end
  return a.file < b.file
end

-- Every theme installed, as {file, name, sections, overlap, folder}, in a fixed order.
--
-- Sorted by (folder, name, file) for the same reason the catalog sorts by (category, label, id):
-- these come out of hash tables, whose iteration order is an accident that can differ between
-- sessions, and a dropdown that reshuffles itself between logins looks broken.
function S.Themes()
  local panels, overlaps = meta()
  local folders = addonFolders()
  local seen, list = {}, {}
  collectRegistered(seen, list, folders, panels, overlaps)
  collectKnownPacks(seen, list, folders)
  table.sort(list, byFolderNameFile)
  return list
end

-- The absolute texture path of one section. Extensionless and rooted at Interface\Addons, which is
-- the form SunnArt itself uses and the form WoW resolves against any addon's folder.
function S.SectionPath(file, index)
  return "Interface\\Addons\\" .. file .. index
end

-- Every installed theme as catalog rows, ready to append to Artwork.Catalog.
--
-- ONE row per theme: the whole bar, wearing the theme's own name.
--
-- Each theme used to yield both shapes — the bar plus one row per section, "Blackrock (left)" and
-- friends — on the reasoning that a player might want a single strip. In a dropdown that is not a
-- choice, it is clutter: the twelve official packs are 88 themes, and per-section rows turned that
-- into 270 entries, four fifths of them fragments of something else listed three lines above. The
-- bar is what a Sunn theme IS; anyone who genuinely wants one strip can point Custom path at it, and
-- the path is right there in this file.
--
-- Composed rows carry `sections`, the ordered section path list, and are the only row shape in the
-- addon that is not a single texture. That path stays scoped to them alone: a bundled piece or a
-- Custom path never reaches it. A one-section theme is a composite of one and carries no `sections`
-- at all, so it takes the ordinary single-texture route.
function S.Rows(themes)
  local rows = {}
  for _, theme in ipairs(themes or S.Themes()) do
    local category = "Sunn -> " .. prettyFolder(theme.folder)
    local stem = S.ID_PREFIX .. slug(theme.file)

    local paths = {}
    for i = 1, theme.sections do paths[i] = S.SectionPath(theme.file, i) end

    -- The overlap crop, expressed the way modules/Artwork.lua consumes it: `h` is the CONTENT
    -- height, and contentV0 says where that content starts in the file. Both halves have to move
    -- together or the art is drawn at the right size from the wrong part of the texture.
    --
    -- Omitted rather than set to 0 when there is no overlap, so a row that does not crop carries no
    -- field to reason about and takes the identity path by absence.
    local sectionW, sectionH = sectionSize(theme.file)
    local contentH = sectionH * (1 - theme.overlap)
    local contentV0 = theme.overlap > 0 and theme.overlap or nil

    -- The row wears the theme's BARE name: the bar is the thing the theme was drawn to be, so
    -- scanning the dropdown for "Blackrock" finds it and nothing else.
    --
    -- The `-bar` suffix on a multi-section id is kept even though nothing needs disambiguating any
    -- more. Ids are the saved-variables contract (modules/Artwork.lua ▸ Catalog), and dropping it
    -- would silently reset every panel already pointing at a bar to "no artwork" — a rename is a
    -- breaking change whether or not the reason for the name still holds.
    rows[#rows + 1] = {
      id        = stem .. (theme.sections > 1 and "-bar" or ""),
      category  = category,
      label     = theme.name,
      path      = paths[1],
      -- The composed row's native size is the bar's, not a section's: sections sit FLUSH, side by
      -- side (SunnArt_Core.lua:322 anchors each to the previous one's TOPRIGHT), so the width
      -- multiplies and the height does not. Getting this wrong would make FIT and TILE treat a 3:1
      -- bar as a 2:1 strip.
      w         = sectionW * theme.sections,
      h         = contentH,
      contentV0 = contentV0,
      sections  = theme.sections > 1 and paths or nil,
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
