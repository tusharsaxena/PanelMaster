local _, NS = ...
NS.Artwork = NS.Artwork or {}
local Artwork = NS.Artwork
local C = NS.Constants

-- The artwork catalog and the record-to-geometry math behind the per-panel art layer.
--
-- Two things live here and nothing else: the list of bundled artwork, and the lookups over it —
-- Entry, List and the record-to-path resolver. BuildArtSpec, the PURE function that turns a panel
-- record plus a panel size into "what rectangle, what texture coordinates, what tint", and the fill
-- math under it live in modules/ArtworkGeometry.lua, peeled out along the catalog / geometry seam
-- (layout-§1, anti-pattern #53). Neither file touches a frame or calls a WoW API; both are data and
-- arithmetic, and both extend the one NS.Artwork table.
--
-- The geometry deliberately does NOT live in Canvas. Canvas.BuildSpec is pure and frame-free on
-- purpose, so the whole question "what does this panel render as" can be answered headlessly. Fill
-- math is the part of artwork most likely to be wrong and hardest to eyeball in-game — a FILL crop
-- that is off by half a pixel of texture space looks fine until the panel is resized — so extending
-- that same property to artwork is what makes all five fill types verifiable against resize in the
-- test harness, with no game client anywhere near it. Putting the math in the renderer would have
-- made it reachable only by launching WoW and squinting.
--
-- The catalog is the other half of the same bargain: adding artwork later is one row here plus a
-- .tga file, and no code change anywhere else.

-- ── Catalog ───────────────────────────────────────────────────────────────────
-- `id` is the STORED value and part of the saved-variables contract: never rename one, or every
-- panel using it silently falls back to "no artwork" on the next load.
--
-- `file` is a bare stem, never a full path. The path is derived at render time from
-- C.ARTWORK_PATH_PREFIX, so it survives the addon folder being moved or renamed — the reasoning
-- that makes the existing media fields store LibSharedMedia NAMES rather than paths.
--
-- `w`/`h` are the AUTHORED pixel dimensions, declared rather than measured. Texture:GetWidth()
-- returns 0 until the file has actually loaded, which is not guaranteed on the first render pass,
-- and STATIC, FIT and TILE cannot compute anything at all without a native size. A declared number
-- is also what keeps this module free of frames.
--
-- There is no `tintable` field any more. Every piece takes the per-panel tint, and the default tint
-- is white, which is a no-op. Multiplying finished full-color art by a color does muddy it — that
-- has not stopped being true — but the answer is `artDesaturate`, which drains the art to grayscale
-- first so the tint comes back clean, rather than refusing the tint and hiding the control.
--
-- `category` is likewise derived, from the folder the file sits in under media/artwork/ — so
-- media/artwork/faction/expansion/12-midnight/harati.tga becomes "Faction -> Expansion ->
-- 12 Midnight". The folder tree is the only place that decides; there is no fixed category list.
--
-- EVERY ROW BELOW IS GENERATED. Do not hand-edit them: `tools/artwork/update_catalog.py` rewrites
-- the whole block from what is actually on disk, so an edit here survives exactly until the next
-- run. To change a label, rename the file; to change a category, move it. The generator is the
-- single opinion about what shipped, which is what keeps this table from drifting away from the
-- files it names.
--
-- Rows are generated in display order (category, then label) purely so a diff of this file reads
-- sensibly. Artwork.List sorts independently for the dropdown and does not rely on it.
Artwork.Catalog = {
  -- BEGIN GENERATED CATALOG (tools/artwork/update_catalog.py) -- do not edit by hand
  { id       = "class-death-knight",
    category = "Class",
    label    = "Death Knight",
    file     = "class\\death-knight",
    w        = 1024, h = 1024 },
  { id       = "class-demon-hunter",
    category = "Class",
    label    = "Demon Hunter",
    file     = "class\\demon-hunter",
    w        = 1024, h = 1024 },
  { id       = "class-druid",
    category = "Class",
    label    = "Druid",
    file     = "class\\druid",
    w        = 1024, h = 1024 },
  { id       = "class-evoker",
    category = "Class",
    label    = "Evoker",
    file     = "class\\evoker",
    w        = 1024, h = 1024 },
  { id       = "class-hunter",
    category = "Class",
    label    = "Hunter",
    file     = "class\\hunter",
    w        = 1024, h = 1024 },
  { id       = "class-mage",
    category = "Class",
    label    = "Mage",
    file     = "class\\mage",
    w        = 1024, h = 1024 },
  { id       = "class-monk",
    category = "Class",
    label    = "Monk",
    file     = "class\\monk",
    w        = 1024, h = 1024 },
  { id       = "class-paladin",
    category = "Class",
    label    = "Paladin",
    file     = "class\\paladin",
    w        = 1024, h = 1024 },
  { id       = "class-priest",
    category = "Class",
    label    = "Priest",
    file     = "class\\priest",
    w        = 1024, h = 1024 },
  { id       = "class-rogue",
    category = "Class",
    label    = "Rogue",
    file     = "class\\rogue",
    w        = 1024, h = 1024 },
  { id       = "class-shaman",
    category = "Class",
    label    = "Shaman",
    file     = "class\\shaman",
    w        = 1024, h = 1024 },
  { id       = "class-warlock",
    category = "Class",
    label    = "Warlock",
    file     = "class\\warlock",
    w        = 1024, h = 1024 },
  { id       = "class-warrior",
    category = "Class",
    label    = "Warrior",
    file     = "class\\warrior",
    w        = 1024, h = 1024 },
  { id       = "expansion-01-vanilla",
    category = "Expansion",
    label    = "01 Vanilla",
    file     = "expansion\\01-vanilla",
    w        = 1024, h = 1024 },
  { id       = "expansion-02-the-burning-crusade",
    category = "Expansion",
    label    = "02 The Burning Crusade",
    file     = "expansion\\02-the-burning-crusade",
    w        = 1024, h = 1024 },
  { id       = "expansion-03-wrath-of-the-lich-king",
    category = "Expansion",
    label    = "03 Wrath of the Lich King",
    file     = "expansion\\03-wrath-of-the-lich-king",
    w        = 1024, h = 1024 },
  { id       = "expansion-04-cataclysm",
    category = "Expansion",
    label    = "04 Cataclysm",
    file     = "expansion\\04-cataclysm",
    w        = 1024, h = 1024 },
  { id       = "expansion-05-mists-of-pandaria",
    category = "Expansion",
    label    = "05 Mists of Pandaria",
    file     = "expansion\\05-mists-of-pandaria",
    w        = 1024, h = 1024 },
  { id       = "expansion-06-warlords-of-draenor",
    category = "Expansion",
    label    = "06 Warlords of Draenor",
    file     = "expansion\\06-warlords-of-draenor",
    w        = 1024, h = 1024 },
  { id       = "expansion-07-legion",
    category = "Expansion",
    label    = "07 Legion",
    file     = "expansion\\07-legion",
    w        = 1024, h = 1024 },
  { id       = "expansion-08-battle-for-azeroth",
    category = "Expansion",
    label    = "08 Battle for Azeroth",
    file     = "expansion\\08-battle-for-azeroth",
    w        = 1024, h = 1024 },
  { id       = "expansion-09-shadowlands",
    category = "Expansion",
    label    = "09 Shadowlands",
    file     = "expansion\\09-shadowlands",
    w        = 1024, h = 1024 },
  { id       = "expansion-10-dragonflight",
    category = "Expansion",
    label    = "10 Dragonflight",
    file     = "expansion\\10-dragonflight",
    w        = 1024, h = 1024 },
  { id       = "expansion-11-the-war-within",
    category = "Expansion",
    label    = "11 The War Within",
    file     = "expansion\\11-the-war-within",
    w        = 1024, h = 1024 },
  { id       = "expansion-12-midnight",
    category = "Expansion",
    label    = "12 Midnight",
    file     = "expansion\\12-midnight",
    w        = 1024, h = 1024 },
  { id       = "expansion-13-the-last-titan",
    category = "Expansion",
    label    = "13 The Last Titan",
    file     = "expansion\\13-the-last-titan",
    w        = 1024, h = 1024 },
  { id       = "faction-expansion-09-shadowlands-kyrian",
    category = "Faction -> Expansion -> 09 Shadowlands",
    label    = "Kyrian",
    file     = "faction\\expansion\\09-shadowlands\\kyrian",
    w        = 1024, h = 1024 },
  { id       = "faction-expansion-09-shadowlands-necrolord",
    category = "Faction -> Expansion -> 09 Shadowlands",
    label    = "Necrolord",
    file     = "faction\\expansion\\09-shadowlands\\necrolord",
    w        = 1024, h = 1024 },
  { id       = "faction-expansion-09-shadowlands-night-fae",
    category = "Faction -> Expansion -> 09 Shadowlands",
    label    = "Night Fae",
    file     = "faction\\expansion\\09-shadowlands\\night-fae",
    w        = 1024, h = 1024 },
  { id       = "faction-expansion-09-shadowlands-venthyr",
    category = "Faction -> Expansion -> 09 Shadowlands",
    label    = "Venthyr",
    file     = "faction\\expansion\\09-shadowlands\\venthyr",
    w        = 1024, h = 1024 },
  { id       = "faction-expansion-10-dragonflight-dragonscale-expedition",
    category = "Faction -> Expansion -> 10 Dragonflight",
    label    = "Dragonscale Expedition",
    file     = "faction\\expansion\\10-dragonflight\\dragonscale-expedition",
    w        = 1024, h = 1024 },
  { id       = "faction-expansion-10-dragonflight-dream-wardens",
    category = "Faction -> Expansion -> 10 Dragonflight",
    label    = "Dream Wardens",
    file     = "faction\\expansion\\10-dragonflight\\dream-wardens",
    w        = 1024, h = 1024 },
  { id       = "faction-expansion-10-dragonflight-iskaara-tuskarr",
    category = "Faction -> Expansion -> 10 Dragonflight",
    label    = "Iskaara Tuskarr",
    file     = "faction\\expansion\\10-dragonflight\\iskaara-tuskarr",
    w        = 1024, h = 1024 },
  { id       = "faction-expansion-10-dragonflight-loamm-niffen",
    category = "Faction -> Expansion -> 10 Dragonflight",
    label    = "Loamm Niffen",
    file     = "faction\\expansion\\10-dragonflight\\loamm-niffen",
    w        = 1024, h = 1024 },
  { id       = "faction-expansion-10-dragonflight-maruuk-centaur",
    category = "Faction -> Expansion -> 10 Dragonflight",
    label    = "Maruuk Centaur",
    file     = "faction\\expansion\\10-dragonflight\\maruuk-centaur",
    w        = 1024, h = 1024 },
  { id       = "faction-expansion-10-dragonflight-valdrakken-accord",
    category = "Faction -> Expansion -> 10 Dragonflight",
    label    = "Valdrakken Accord",
    file     = "faction\\expansion\\10-dragonflight\\valdrakken-accord",
    w        = 1024, h = 1024 },
  { id       = "faction-expansion-11-the-war-within-assembly-of-the-deeps",
    category = "Faction -> Expansion -> 11 The War Within",
    label    = "Assembly of the Deeps",
    file     = "faction\\expansion\\11-the-war-within\\assembly-of-the-deeps",
    w        = 1024, h = 1024 },
  { id       = "faction-expansion-11-the-war-within-cartels-of-undermine",
    category = "Faction -> Expansion -> 11 The War Within",
    label    = "Cartels of Undermine",
    file     = "faction\\expansion\\11-the-war-within\\cartels-of-undermine",
    w        = 1024, h = 1024 },
  { id       = "faction-expansion-11-the-war-within-council-of-dornogal",
    category = "Faction -> Expansion -> 11 The War Within",
    label    = "Council of Dornogal",
    file     = "faction\\expansion\\11-the-war-within\\council-of-dornogal",
    w        = 1024, h = 1024 },
  { id       = "faction-expansion-11-the-war-within-flames-radiance",
    category = "Faction -> Expansion -> 11 The War Within",
    label    = "Flames Radiance",
    file     = "faction\\expansion\\11-the-war-within\\flames-radiance",
    w        = 1024, h = 1024 },
  { id       = "faction-expansion-11-the-war-within-gallagio-loyalty-rewards-club",
    category = "Faction -> Expansion -> 11 The War Within",
    label    = "Gallagio Loyalty Rewards Club",
    file     = "faction\\expansion\\11-the-war-within\\gallagio-loyalty-rewards-club",
    w        = 1024, h = 1024 },
  { id       = "faction-expansion-11-the-war-within-hallowfall-arathi",
    category = "Faction -> Expansion -> 11 The War Within",
    label    = "Hallowfall Arathi",
    file     = "faction\\expansion\\11-the-war-within\\hallowfall-arathi",
    w        = 1024, h = 1024 },
  { id       = "faction-expansion-11-the-war-within-manaforge-vandals",
    category = "Faction -> Expansion -> 11 The War Within",
    label    = "Manaforge Vandals",
    file     = "faction\\expansion\\11-the-war-within\\manaforge-vandals",
    w        = 1024, h = 1024 },
  { id       = "faction-expansion-11-the-war-within-severed-threads",
    category = "Faction -> Expansion -> 11 The War Within",
    label    = "Severed Threads",
    file     = "faction\\expansion\\11-the-war-within\\severed-threads",
    w        = 1024, h = 1024 },
  { id       = "faction-expansion-11-the-war-within-the-karesh-trust",
    category = "Faction -> Expansion -> 11 The War Within",
    label    = "The Karesh Trust",
    file     = "faction\\expansion\\11-the-war-within\\the-karesh-trust",
    w        = 1024, h = 1024 },
  { id       = "faction-expansion-12-midnight-amani-tribe",
    category = "Faction -> Expansion -> 12 Midnight",
    label    = "Amani Tribe",
    file     = "faction\\expansion\\12-midnight\\amani-tribe",
    w        = 1024, h = 1024 },
  { id       = "faction-expansion-12-midnight-harati",
    category = "Faction -> Expansion -> 12 Midnight",
    label    = "Harati",
    file     = "faction\\expansion\\12-midnight\\harati",
    w        = 1024, h = 1024 },
  { id       = "faction-expansion-12-midnight-ritual-sites",
    category = "Faction -> Expansion -> 12 Midnight",
    label    = "Ritual Sites",
    file     = "faction\\expansion\\12-midnight\\ritual-sites",
    w        = 1024, h = 1024 },
  { id       = "faction-expansion-12-midnight-silvermoon-court",
    category = "Faction -> Expansion -> 12 Midnight",
    label    = "Silvermoon Court",
    file     = "faction\\expansion\\12-midnight\\silvermoon-court",
    w        = 1024, h = 1024 },
  { id       = "faction-expansion-12-midnight-singularity",
    category = "Faction -> Expansion -> 12 Midnight",
    label    = "Singularity",
    file     = "faction\\expansion\\12-midnight\\singularity",
    w        = 1024, h = 1024 },
  { id       = "faction-major-alliance-crest",
    category = "Faction -> Major",
    label    = "Alliance Crest",
    file     = "faction\\major\\alliance-crest",
    w        = 1024, h = 1024 },
  { id       = "faction-major-alliance-logo",
    category = "Faction -> Major",
    label    = "Alliance Logo",
    file     = "faction\\major\\alliance-logo",
    w        = 1024, h = 1024 },
  { id       = "faction-major-alliance-symbol",
    category = "Faction -> Major",
    label    = "Alliance Symbol",
    file     = "faction\\major\\alliance-symbol",
    w        = 1024, h = 1024 },
  { id       = "faction-major-horde-crest",
    category = "Faction -> Major",
    label    = "Horde Crest",
    file     = "faction\\major\\horde-crest",
    w        = 1024, h = 1024 },
  { id       = "faction-major-horde-logo",
    category = "Faction -> Major",
    label    = "Horde Logo",
    file     = "faction\\major\\horde-logo",
    w        = 1024, h = 1024 },
  { id       = "faction-major-horde-symbol",
    category = "Faction -> Major",
    label    = "Horde Symbol",
    file     = "faction\\major\\horde-symbol",
    w        = 1024, h = 1024 },
  { id       = "other-blackrock",
    category = "Other",
    label    = "Blackrock",
    file     = "other\\blackrock",
    w        = 1024, h = 1024 },
  { id       = "other-bleeding-hollow",
    category = "Other",
    label    = "Bleeding Hollow",
    file     = "other\\bleeding-hollow",
    w        = 1024, h = 1024 },
  { id       = "other-combat",
    category = "Other",
    label    = "Combat",
    file     = "other\\combat",
    w        = 1024, h = 1024 },
  { id       = "other-cult-of-the-damned",
    category = "Other",
    label    = "Cult of the Damned",
    file     = "other\\cult-of-the-damned",
    w        = 1024, h = 1024 },
  { id       = "other-demon",
    category = "Other",
    label    = "Demon",
    file     = "other\\demon",
    w        = 1024, h = 1024 },
  { id       = "other-drust",
    category = "Other",
    label    = "Drust",
    file     = "other\\drust",
    w        = 1024, h = 1024 },
  { id       = "other-frostwolf",
    category = "Other",
    label    = "Frostwolf",
    file     = "other\\frostwolf",
    w        = 1024, h = 1024 },
  { id       = "other-highmountain-tauren-legion",
    category = "Other",
    label    = "Highmountain Tauren Legion",
    file     = "other\\highmountain-tauren-legion",
    w        = 1024, h = 1024 },
  { id       = "other-icon-of-blood",
    category = "Other",
    label    = "Icon of Blood",
    file     = "other\\icon-of-blood",
    w        = 1024, h = 1024 },
  { id       = "other-icon-of-defeat",
    category = "Other",
    label    = "Icon of Defeat",
    file     = "other\\icon-of-defeat",
    w        = 1024, h = 1024 },
  { id       = "other-mogu",
    category = "Other",
    label    = "Mogu",
    file     = "other\\mogu",
    w        = 1024, h = 1024 },
  { id       = "other-nightborne-legion",
    category = "Other",
    label    = "Nightborne Legion",
    file     = "other\\nightborne-legion",
    w        = 1024, h = 1024 },
  { id       = "other-ogre",
    category = "Other",
    label    = "Ogre",
    file     = "other\\ogre",
    w        = 1024, h = 1024 },
  { id       = "other-scourge",
    category = "Other",
    label    = "Scourge",
    file     = "other\\scourge",
    w        = 1024, h = 1024 },
  { id       = "other-shadowmoon",
    category = "Other",
    label    = "Shadowmoon",
    file     = "other\\shadowmoon",
    w        = 1024, h = 1024 },
  { id       = "other-shattered-hand",
    category = "Other",
    label    = "Shattered Hand",
    file     = "other\\shattered-hand",
    w        = 1024, h = 1024 },
  { id       = "other-thunderlord",
    category = "Other",
    label    = "Thunderlord",
    file     = "other\\thunderlord",
    w        = 1024, h = 1024 },
  { id       = "other-twilights-hammer",
    category = "Other",
    label    = "Twilights Hammer",
    file     = "other\\twilights-hammer",
    w        = 1024, h = 1024 },
  { id       = "other-vrykul",
    category = "Other",
    label    = "Vrykul",
    file     = "other\\vrykul",
    w        = 1024, h = 1024 },
  { id       = "other-warsong",
    category = "Other",
    label    = "Warsong",
    file     = "other\\warsong",
    w        = 1024, h = 1024 },
  { id       = "race-dark-iron",
    category = "Race",
    label    = "Dark Iron",
    file     = "race\\dark-iron",
    w        = 1024, h = 1024 },
  { id       = "race-dracthyr",
    category = "Race",
    label    = "Dracthyr",
    file     = "race\\dracthyr",
    w        = 1024, h = 1024 },
  { id       = "race-draenei",
    category = "Race",
    label    = "Draenei",
    file     = "race\\draenei",
    w        = 1024, h = 1024 },
  { id       = "race-dwarf",
    category = "Race",
    label    = "Dwarf",
    file     = "race\\dwarf",
    w        = 1024, h = 1024 },
  { id       = "race-earthen",
    category = "Race",
    label    = "Earthen",
    file     = "race\\earthen",
    w        = 1024, h = 1024 },
  { id       = "race-forsaken",
    category = "Race",
    label    = "Forsaken",
    file     = "race\\forsaken",
    w        = 1024, h = 1024 },
  { id       = "race-gnome",
    category = "Race",
    label    = "Gnome",
    file     = "race\\gnome",
    w        = 1024, h = 1024 },
  { id       = "race-goblin",
    category = "Race",
    label    = "Goblin",
    file     = "race\\goblin",
    w        = 1024, h = 1024 },
  { id       = "race-haranir",
    category = "Race",
    label    = "Haranir",
    file     = "race\\haranir",
    w        = 1024, h = 1024 },
  { id       = "race-highmountain-tauren",
    category = "Race",
    label    = "Highmountain Tauren",
    file     = "race\\highmountain-tauren",
    w        = 1024, h = 1024 },
  { id       = "race-human",
    category = "Race",
    label    = "Human",
    file     = "race\\human",
    w        = 1024, h = 1024 },
  { id       = "race-kul-tiran",
    category = "Race",
    label    = "Kul Tiran",
    file     = "race\\kul-tiran",
    w        = 1024, h = 1024 },
  { id       = "race-lightforged-draenei",
    category = "Race",
    label    = "Lightforged Draenei",
    file     = "race\\lightforged-draenei",
    w        = 1024, h = 1024 },
  { id       = "race-maghar",
    category = "Race",
    label    = "Maghar",
    file     = "race\\maghar",
    w        = 1024, h = 1024 },
  { id       = "race-mechagnome",
    category = "Race",
    label    = "Mechagnome",
    file     = "race\\mechagnome",
    w        = 1024, h = 1024 },
  { id       = "race-night-elf",
    category = "Race",
    label    = "Night Elf",
    file     = "race\\night-elf",
    w        = 1024, h = 1024 },
  { id       = "race-nightborne",
    category = "Race",
    label    = "Nightborne",
    file     = "race\\nightborne",
    w        = 1024, h = 1024 },
  { id       = "race-orc",
    category = "Race",
    label    = "Orc",
    file     = "race\\orc",
    w        = 1024, h = 1024 },
  { id       = "race-pandaren",
    category = "Race",
    label    = "Pandaren",
    file     = "race\\pandaren",
    w        = 1024, h = 1024 },
  { id       = "race-tauren",
    category = "Race",
    label    = "Tauren",
    file     = "race\\tauren",
    w        = 1024, h = 1024 },
  { id       = "race-troll",
    category = "Race",
    label    = "Troll",
    file     = "race\\troll",
    w        = 1024, h = 1024 },
  { id       = "race-void-elf",
    category = "Race",
    label    = "Void Elf",
    file     = "race\\void-elf",
    w        = 1024, h = 1024 },
  { id       = "race-vulpera",
    category = "Race",
    label    = "Vulpera",
    file     = "race\\vulpera",
    w        = 1024, h = 1024 },
  { id       = "race-worgen",
    category = "Race",
    label    = "Worgen",
    file     = "race\\worgen",
    w        = 1024, h = 1024 },
  { id       = "race-zandalari",
    category = "Race",
    label    = "Zandalari",
    file     = "race\\zandalari",
    w        = 1024, h = 1024 },
  -- END GENERATED CATALOG
}

-- Categories are alphabetical rather than ranked against a declared list.
--
-- They are derived from the artwork's own folder path ("Faction -> Expansion -> 12 Midnight"), so
-- there is no fixed set to rank against and any list here would need editing every time a folder
-- appears. Alphabetical is stable, needs no maintenance, and happens to keep a folder's children
-- adjacent to it: a child's category string starts with its parent's, so the two sort together.
--
-- A row with no category at all still sorts (last) rather than erroring, because a bad catalog row
-- should degrade the dropdown's order, not break the dropdown.
local UNRANKED = "\255"

-- A user pointing at their own file gives us a path and nothing else — there is no way to learn its
-- pixel size without a frame and a load round-trip, which is exactly what this module will not do.
-- So a nominal native size is assumed, and it only matters for the three fills that need one
-- (STATIC, FIT, TILE); STRETCH and FILL cover the panel regardless of what the number is. 256 is a
-- middling power of two: big enough that FIT does not blow a small icon up to a blurry wall, small
-- enough that TILE produces visible tiles rather than one clipped copy.
Artwork.CUSTOM_NATIVE_SIZE = 256

-- The ceiling on how many textures one panel's artwork may cost.
--
-- Only TILE can approach it, and only on a composed row: a tiled composite repeats the WHOLE bar,
-- which is `copies x sections` textures, and a 5-section bar at the minimum scale would otherwise
-- ask for several hundred on a single panel. Over budget, the copy count is reduced and each tile
-- grown to match, so the panel stays COVERED rather than going partly bare — a smaller number of
-- larger tiles is a compromise a player can see and understand; a bald strip looks broken.
--
-- 24 is four copies of the widest bar SunnArt allows, which is more repeats than the fill is
-- legible at anyway.
Artwork.MAX_ART_QUADS = 24

-- ── Lookup ──────────────────────────────────────────────────────────────────────

-- Find a catalog row by id.
--
-- A linear scan rather than a prebuilt index, deliberately: the catalog is a handful of rows, and
-- an index would go stale the moment anything appended to Artwork.Catalog at runtime — which is
-- precisely the extension path this table exists to offer.
--
-- The case-insensitive second pass is for the CLI: `/pm panel set art runic-Sigil` should find the
-- row rather than refuse it, mirroring how the "media" field kind already forgives case.
function Artwork.Entry(id)
  if type(id) ~= "string" then return nil end
  for _, row in ipairs(Artwork.Catalog) do
    if row.id == id then return row end
  end
  local lowered = id:lower()
  for _, row in ipairs(Artwork.Catalog) do
    if type(row.id) == "string" and row.id:lower() == lowered then return row end
  end
  return nil
end

-- Resolve a record to (path, row). `row` is nil for the "Custom" case, which has no catalog entry
-- and is therefore drawn at the nominal native size above.
--
-- Both reserved ids and an unknown id resolve to no path, which is what makes "the art this panel
-- names no longer exists" degrade to drawing nothing instead of erroring on a bad texture.
local function resolve(rec)
  if type(rec) ~= "table" then return nil, nil end
  local id = rec.artTexture
  if type(id) ~= "string" or id == "" or id == C.ARTWORK_NONE then return nil, nil end

  if id == C.ARTWORK_CUSTOM then
    local path = rec.artCustomPath
    if type(path) ~= "string" then return nil, nil end
    path = path:match("^%s*(.-)%s*$")
    if path == "" then return nil, nil end
    return path, nil
  end

  local row = Artwork.Entry(id)
  if not row then return nil, nil end
  -- An ABSOLUTE path on the row wins over the bundled derivation. Rows injected by the Sunn adapter
  -- (modules/SunnArt.lua) live in someone else's addon folder, which C.ARTWORK_PATH_PREFIX cannot
  -- reach by construction — it is rooted at this addon. Bundled rows carry `file` and no `path`, so
  -- they take the branch below exactly as before.
  if type(row.path) == "string" and row.path ~= "" then return row.path, row end
  if type(row.file) ~= "string" then return nil, nil end
  return C.ARTWORK_PATH_PREFIX .. row.file .. ".tga", row
end

-- Published for modules/ArtworkGeometry.lua, whose NativeSize and BuildArtSpec resolve a record the
-- same way. The double underscore marks it as a seam between the two halves of this module, not API,
-- the way settings/PanelEditor.lua publishes E.__pageActions for its peeled tabs.
Artwork.__resolve = resolve

-- ── Dropdown list ───────────────────────────────────────────────────────────────

-- The ordered option list: "None" first, the catalog in category-then-label order, "Custom" last.
--
-- The two reserved entries bracket the list rather than sitting inside it because they are not art:
-- one is the off switch and the other is an escape hatch — and a user scanning for either wants it
-- at a predictable end, not sorted in among the "G"s. They carry no `category` field for the same
-- reason: they belong to no category, and giving them a fake one would put them in a group.
--
-- Catalog labels carry their category as a prefix ("General: Runic Sigil") because the widget is
-- a FLAT list. That is honest at this catalog size; a grouped widget can replace it when there is
-- enough art to need one, and the prefix is what keeps the flat list readable until then.
function Artwork.List()
  local rows = {}
  for _, row in ipairs(Artwork.Catalog) do
    rows[#rows + 1] = row
  end

  -- Sorted by category, then label, then id. The id tie-break is not cosmetic: table.sort is
  -- NOT stable, so two rows comparing equal could otherwise swap places between sessions and make
  -- the dropdown reorder itself for no reason.
  table.sort(rows, function(a, b)
    local ra = a.category or UNRANKED
    local rb = b.category or UNRANKED
    if ra ~= rb then return ra < rb end
    local la, lb = a.label or a.id or "", b.label or b.id or ""
    if la ~= lb then return la < lb end
    return (a.id or "") < (b.id or "")
  end)

  local list = { { id = C.ARTWORK_NONE, label = "None" } }
  for _, row in ipairs(rows) do
    list[#list + 1] = {
      id = row.id,
      label = (row.category or "?") .. ": " .. (row.label or row.id),
      category = row.category,
    }
  end
  list[#list + 1] = { id = C.ARTWORK_CUSTOM, label = "Custom path\226\128\166" }
  return list
end
