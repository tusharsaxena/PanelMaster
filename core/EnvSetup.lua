local addonName, NS = ...

-- core/EnvSetup.lua — wires the addon into LibKa0s-Env-1.0 (library-stack-§7).
--
-- The seam where this addon's own version comes from: `/pm version`, the help header and the
-- database's debug summary all resolve through here.
--
-- ── WHAT THIS REPLACED ──────────────────────────────────────────────────────────
--
-- One shim out of core/Compat.lua: the TOC-metadata reader. It had been written ELEVEN times across
-- nine addons before the library had it — six copies in a core/Compat.lua in four different
-- spellings, and five more inlined straight at the call site where no audit of the shim files would
-- ever have found them. Not one of the eleven behaved differently from any other, and that sameness
-- is the whole case: it is what makes the reader the library's business rather than this addon's,
-- and it is why Compat KEEPS its addon-roster, screen-geometry, class-color and shared-media
-- readers, which are genuinely PanelMaster's and behave like nobody else's.
--
-- ── WHY THE LIBRARY HAS TO BE TOLD OUR NAME ─────────────────────────────────────
--
-- Same reason core/MediaSetup.lua passes it: LibKa0s is VENDORED, so a copy cannot work out which
-- addon folder it sits in. `addonName` is the FIRST VARARG every TOC-loaded file gets — not
-- NS.PREFIX, not the `## Title`, and not a hand-typed literal. Here those three read "PanelMaster",
-- "[PM]" and "Ka0s Panel Master", and only the first is the folder. A wrong name reads some other
-- addon's manifest, or none at all, and answers nil without raising a thing.
--
-- ── WHY THE FALLBACKS ARE WRITTEN OUT RATHER THAN LEFT TO ANSWER nil ────────────
--
-- Because this is a seam, not a feature. An install missing LibKa0s must get exactly what this
-- addon got before the library existed: each helper below repeats the ladder the deleted shim ran,
-- so such an install still reads its own TOC. Nothing here resolves anything at load beyond the
-- LibStub lookup, so this file's TOC position is conventional rather than load-bearing — unlike
-- core/MediaSetup.lua's, which is, and says so.
--
-- ── WHAT THE SEAM MUST NOT CHANGE ───────────────────────────────────────────────
--
-- Any answer. The deleted shim already agreed with the library rung for rung, so a difference in
-- what comes back here is a defect in the adoption rather than an improvement.
-- tests/test_envsetup.lua pins it.

local Env = LibStub and LibStub("LibKa0s-Env-1.0", true)

--- One field of this addon's TOC manifest, or nil.
---
--- NIL IS A REAL ANSWER, twice over: the library may be absent AND the client may expose no reader
--- at all. A field the TOC does not carry also answers nil on a perfectly healthy client. Callers
--- that need a value supply their own.
---
--- @param field string  a TOC key: "Version", "Title", "Notes", "Author", …
--- @return string|nil
function NS.Meta(field)
  if Env then return Env.GetAddOnMetadata(addonName, field) end
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    return C_AddOns.GetAddOnMetadata(addonName, field)
  end
  if type(GetAddOnMetadata) == "function" then
    return GetAddOnMetadata(addonName, field)
  end
  return nil
end

--- This addon's version string, preferring the TOC over the fallback constant. Never nil.
---
--- The fallback stays visible HERE rather than inside the library because which constant this addon
--- falls back to is genuinely its own business — and because a packaged addon whose TOC can be read
--- should never report the constant somebody forgot to edit.
---
--- `NS.version` is read at CALL time, not captured as an upvalue: core/Namespace.lua publishes it
--- and loads after this file.
---
--- @return string
function NS.Version()
  if Env then return Env.Version(addonName, NS.version) or "?" end
  return NS.Meta("Version") or NS.version or "?"
end
