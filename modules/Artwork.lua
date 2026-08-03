local addonName, NS = ...   -- luacheck: ignore addonName
NS.Artwork = NS.Artwork or {}
local Artwork = NS.Artwork
local C = NS.Constants
local Util = NS.Util

-- The artwork catalog and the record-to-geometry math behind the per-panel art layer.
--
-- Two things live here and nothing else: the list of bundled artwork, and BuildArtSpec — the pure
-- function that turns a panel record plus a panel size into "what rectangle, what texture
-- coordinates, what tint". It touches NO frames and calls NO WoW API; it is data and arithmetic.
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

-- ── Geometry ────────────────────────────────────────────────────────────────────

-- A strictly-positive dimension, or nil. Every fill divides by at least one of W, H, w or h, so a
-- nil, a non-number, a zero or a negative has to be caught ONCE here and turned into "draw nothing"
-- rather than being allowed to reach a division and produce inf/nan coordinates — which WoW accepts
-- silently and renders as a garbage smear.
local function positive(n)
  n = tonumber(n)
  if not n or n <= 0 then return nil end
  return n
end

local function pickEnum(value, set, fallback)
  if set and set[value] then return value end
  return fallback
end

-- The four UV corners of a crop rectangle, in the order SetTexCoord's eight-argument form names
-- them. Each corner is a {u, v} pair, which is what makes flip and rotation plain table swaps
-- instead of index arithmetic on a flat list of eight numbers.
local function corners(u0, v0, u1, v1)
  return { u0, v0 }, { u0, v1 }, { u1, v0 }, { u1, v1 }   -- UL, LL, UR, LR
end

-- Compose crop, flip and rotation onto those corners, in that fixed order, and emit the flat eight.
--
-- Order matters and is part of the contract: flipping then rotating is not the same transform as
-- rotating then flipping, and picking one and stating it is the only way the settings UI's two
-- checkboxes and its dropdown mean something stable together.
--
-- Quarter turns are an exact axis TRANSPOSE, not a resampling rotation: each screen corner is just
-- handed a different one of the four texture corners, so there is no interpolation, no edge smear
-- and no sampling outside 0-1. That last point is why arbitrary angles were rejected — rotating a
-- CROPPED quad samples beyond the crop, and under CLAMP that drags the edge pixels across the
-- corners. It is also the same trick C.ACCENT_TEXCOORD_ROT90 already uses for vertical accent bars.
--
-- Verified: applying this permutation ONCE to the identity quad (UL=(0,0) LL=(0,1) UR=(1,0)
-- LR=(1,1)) yields UL=(0,1) LL=(1,1) UR=(0,0) LR=(1,0), which flattens to
-- { 0,1, 1,1, 0,0, 1,0 } — exactly C.ACCENT_TEXCOORD_ROT90. The two rotations are one rotation.
local function composeUV(u0, v0, u1, v1, flipH, flipV, rotation)
  local ul, ll, ur, lr = corners(u0, v0, u1, v1)

  -- Mirroring swaps which SIDE of the quad each screen corner samples: horizontally that is the
  -- left/right pair, vertically the top/bottom pair.
  if flipH then ul, ur, ll, lr = ur, ul, lr, ll end
  if flipV then ul, ll, ur, lr = ll, ul, lr, ur end

  local turns = (rotation or 0) / 90
  for _ = 1, turns do
    ul, ll, ur, lr = ll, lr, ul, ur
  end

  return { ul[1], ul[2], ll[1], ll[2], ur[1], ur[2], lr[1], lr[2] }
end

-- The record-to-geometry function. PURE: a record and a panel size in, a plain table out, no frame
-- ever touched. Returns nil for "this panel draws no artwork", which is the default and must stay
-- the cheapest possible answer.
--
-- The size arguments are the panel's ALREADY-CLAMPED render size (Canvas passes spec.width/height,
-- The artwork's NATIVE pixel size for a record, or nil when it draws nothing.
--
-- The one place that answers "how big is this piece, really", so the autosize seam in the registry
-- and the fill math below cannot disagree about it. Both readings are the same three cases: a
-- catalog row's declared w/h, the nominal square for a Custom path whose size nothing can know, and
-- nil for "no art", which is what makes autosize a no-op rather than a divide-by-zero when a panel
-- names a piece that is not installed.
function Artwork.NativeSize(rec)
  local path, row = resolve(rec)
  if not path then return nil end
  local w = positive(row and row.w or Artwork.CUSTOM_NATIVE_SIZE)
  local h = positive(row and row.h or Artwork.CUSTOM_NATIVE_SIZE)
  if not w or not h then return nil end
  return w, h
end

-- not rec.width/height), so the art is fitted to the rectangle that will actually be on screen.
function Artwork.BuildArtSpec(rec, panelW, panelH)
  local path, row = resolve(rec)
  if not path then return nil end

  local W, H = positive(panelW), positive(panelH)
  if not W or not H then return nil end

  -- Native size: declared by the catalog row, or the nominal fallback for a custom path. Guarded
  -- the same way as the panel size, because a catalog row with a typo'd `w` must not divide by
  -- zero either.
  local w = positive(row and row.w or Artwork.CUSTOM_NATIVE_SIZE)
  local h = positive(row and row.h or Artwork.CUSTOM_NATIVE_SIZE)
  if not w or not h then return nil end

  local T = C.PANEL_TEMPLATE
  local fill  = pickEnum(rec.artFill,  C.ART_FILL_SET,  T.artFill)
  local layer = pickEnum(rec.artLayer, C.ART_LAYER_SET, T.artLayer)
  local rotation = pickEnum(tonumber(rec.artRotation), C.ART_ROTATION_SET, T.artRotation)
  local s = Util.Clamp(rec.artScale, C.MIN_ART_SCALE, C.MAX_ART_SCALE, T.artScale)

  -- A quarter turn TRANSPOSES the texture's axes against the screen: afterwards the screen's
  -- horizontal extent is sampled along the texture's v axis and its vertical extent along u. Every
  -- fill but STRETCH reasons about "how big is this art on screen", so each has to see the art's
  -- dimensions the way the turn will actually present them rather than the way they were authored.
  --
  -- Getting this wrong is invisible on square art and catastrophic on anything else: a 512x128
  -- piece at FIT and 90 degrees was sized into a rect for the UNturned art and then drawn turned,
  -- squashing it 16:1. Square art hides it completely, which is why the whole fill matrix below is
  -- run against wide and tall art on both sides.
  local turned = (rotation == 90 or rotation == 270)
  local ew, eh = w, h                       -- the art's extent AS PRESENTED, after the turn
  if turned then ew, eh = h, w end

  -- Map a pair of SCREEN-space spans onto the texture's own axes. The one place the transpose is
  -- applied, so FILL and TILE state their spans in screen terms and stay readable.
  local function toTextureAxes(screenH, screenV)
    if turned then return screenV, screenH end
    return screenH, screenV
  end

  -- Declared without a default on purpose: every one of the five branches below sets both, so an
  -- initial value here would only hide a future branch that forgot to.
  local width, height
  local u0, v0, u1, v1 = 0, 0, 1, 1
  local tile = false

  if fill == "STRETCH" then
    -- Stretch IS "fill the panel exactly", so scale is deliberately ignored rather than quietly
    -- applied: a scaled stretch is either FILL (still covers, crops instead of distorting) or
    -- STATIC (keeps the aspect, does not cover), and honouring scale here would produce art that
    -- no longer matches the panel while still claiming to be stretched to it. The tooltip says so.
    width, height = W, H

  elseif fill == "FIT" then
    -- Contain: the larger of the two shortfalls decides, so the whole image is inside the panel and
    -- the aspect is preserved. Scale then shrinks or grows that result about the anchor.
    local r = math.min(W / ew, H / eh) * s
    width, height = ew * r, eh * r

  elseif fill == "STATIC" then
    width, height = ew * s, eh * s

  elseif fill == "FILL" then
    -- Cover. The frame is the whole panel, and the overflow comes off the TEXTURE COORDINATES
    -- rather than off the frame size — that is the whole point. Cover has to fill the panel exactly
    -- AND preserve the art's aspect, and those two demands cannot both be met by resizing a
    -- rectangle: something has to be thrown away, and throwing it away in UV space crops the image
    -- while leaving the drawn rectangle flush with the panel. Resizing instead would letterbox
    -- (that is FIT) or distort (that is STRETCH).
    --
    -- a compares the panel's aspect to the art's AS PRESENTED. a > 1 means the panel is relatively
    -- wider, so the horizontal axis is the binding one and the vertical is cropped to 1/a;
    -- otherwise the reverse. Both spans are in SCREEN terms and are transposed onto the texture's
    -- axes at the end, which is what keeps cover honest under a quarter turn.
    width, height = W, H
    local a = (W / H) / (ew / eh)
    local spanH, spanV = 1, 1
    if a > 1 then spanV = 1 / a else spanH = a end
    -- Scale tightens BOTH surviving ranges, so s > 1 samples less of the texture across the same
    -- rectangle, which reads as zooming in. Dividing (rather than multiplying) is what makes the
    -- slider's direction agree with every other fill, where s > 1 also makes the art bigger.
    spanH, spanV = spanH / s, spanV / s
    local uSpan, vSpan = toTextureAxes(spanH, spanV)
    u0, u1 = 0.5 - uSpan / 2, 0.5 + uSpan / 2
    v0, v1 = 0.5 - vSpan / 2, 0.5 + vSpan / 2

  else -- TILE
    -- The texture repeats at its native size (times scale) across the whole panel, so the UV range
    -- is "how many copies fit" rather than a 0-1 crop. Values above 1 are the point here, and they
    -- only mean anything because the renderer sets wrap mode REPEAT — hence the flag, which is the
    -- one bit of this spec the renderer cannot infer from the numbers.
    -- Counted in SCREEN terms — "how many copies fit across the panel, and how many down it" —
    -- then transposed, so a quarter turn re-tiles rather than stretching each tile.
    width, height = W, H
    u1, v1 = toTextureAxes(W / (ew * s), H / (eh * s))
    tile = true
  end

  -- Position is honoured only by the two fills that do not cover the panel. STRETCH, FILL and TILE
  -- all draw a rectangle exactly the size of the panel, so an anchor or an offset could only push
  -- that rectangle off the panel and leave a bare strip — the setting would be actively harmful
  -- rather than merely inert. Forcing center here means the spec always states where the art really
  -- sits, instead of the renderer having to know which fills to ignore the record for.
  local point, x, y = "CENTER", 0, 0
  if fill == "STATIC" or fill == "FIT" then
    point = Util.IsPoint(rec.artPoint) and rec.artPoint or T.artPoint
    x = tonumber(rec.artX) or 0
    y = tonumber(rec.artY) or 0
  end

  -- Through the shared resolver, so class color cost one C.COLOR_FIELDS row and no code here.
  -- artAlpha then multiplies the resolved alpha rather than replacing it, so the color picker's own
  -- alpha and the opacity slider compose instead of one silently winning.
  local color = Util.ResolveColor(rec, "artColor")
  local alpha = color[4] * Util.Clamp(rec.artAlpha, 0, 1, T.artAlpha)
  -- The tint applies to EVERY piece, full-color included. It used to be forced to white for art the
  -- catalog declared full-color, on the reasoning that multiplying finished art by a color can only
  -- muddy it — which is true, and is why Desaturate exists: collapsing the art to grayscale first
  -- means the tint multiplies against neutral gray and comes back as a clean, saturated version of
  -- the chosen color rather than a darkened average of the original hues.
  --
  -- The default tint is white, which is a no-op, so nothing changes for anyone who has not asked
  -- for a color.
  color = { color[1], color[2], color[3], alpha }

  return {
    path   = path,
    layer  = layer,
    -- The frame level the renderer must put the single art frame at for this layer choice. Resolved
    -- here so the ladder is stated once, in Constants, rather than re-derived by the renderer.
    level  = C.ART_FRAME_LEVEL[layer],
    color  = color,
    -- Resolved here rather than read off the record by the renderer, so "what does this panel draw"
    -- stays a question BuildArtSpec answers completely and the headless suite can assert on.
    desaturate = rec.artDesaturate and true or false,
    blend  = C.ART_BLEND_SET[rec.artBlend] and rec.artBlend or C.PANEL_TEMPLATE.artBlend,
    tile   = tile,
    width  = width,
    height = height,
    point  = point,
    x      = x,
    y      = y,
    uv     = composeUV(u0, v0, u1, v1, rec.artFlipH and true or false,
      rec.artFlipV and true or false, rotation),
  }
end
