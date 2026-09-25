-- tests/prose_waivers.lua — what the kit's US-English gate MUST NOT correct here.
--
-- Read by `tests/_kit/test_prose.lua` (localization-§5). Per FILE and per WORD, never per file
-- alone: a whole-file waiver hides every OTHER British spelling in a file this repo edits often,
-- which is how a gate acquires a blind spot the size of a module.

return {
    waived = {
        -- A TEXTURE PATH INTO A THIRD-PARTY ART PACK, not prose. `SunnArtPack1\\grey` is the name
        -- SunnArt's own files carry on disk; the table maps that path to the display name "Gray",
        -- which IS this addon's English and is spelled the US way beside it. Correcting the path
        -- would not fix a word, it would be a texture the client cannot find.
        ["modules/SunnArtPacks.lua"] = { ["gr" .. "ey"] = true },
    },
}
