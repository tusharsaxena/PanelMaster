local addonName, NS = ...

-- LibKa0s-Media-1.0 seam: where this addon's shared art and its monospace face come from.
--
-- ── THE FONT USED TO BE OURS, AND THAT WAS THE PROBLEM ──────────────────────────
--
-- PanelMaster shipped its own copy of JetBrains Mono under `media/fonts/`, beside its
-- own copy of the OFL text. So did every other addon in this collection, because the
-- second Ka0s console to want a fixed-width face copied the first one's file. Two
-- copies of a font are two licenses to track, two provenance stories, and a
-- collection whose addons stop looking like one author's work the first time one copy
-- is regenerated and the other is not. The face — and the icon set the library's own
-- windows draw with — now ship inside LibKa0s and arrive with the vendored payload.
--
-- `media/` here is untouched by that move and stays large: the 101-piece artwork
-- catalog, the landing-page logo and the project-page plates are this addon's own
-- product, not chrome, and nothing in the library has an equivalent of them.
--
-- ── WHY THE LIBRARY HAS TO BE TOLD OUR NAME ─────────────────────────────────────
--
-- A texture path is absolute from `Interface\AddOns\`, and LibKa0s is VENDORED: every
-- consumer has its own copy at its own path, and a copy cannot work out which addon
-- folder it was copied into. So the library asks, and this file is where the answer
-- lives — `addonName`, the first vararg every TOC-loaded file gets. It is the FOLDER
-- name and nothing else: not the `## Title`, not a frame-name prefix, not a hand-typed
-- constant that would go stale the day the folder is renamed.
--
-- ── WHY THIS LOADS BEFORE core/Constants.lua ────────────────────────────────────
--
-- `C.FONT_MONO` is resolved from `NS.MediaFont` at FILE LOAD, so the seam has to be
-- published first; a seam loading later would leave the constant holding nil forever.
-- That is why this file's TOC position is load-bearing rather than conventional, and
-- why the TOC line says so.
--
-- ── WHAT A DEGRADED INSTALL GETS ────────────────────────────────────────────────
--
-- No LibKa0s means no art and no face, because both are inside the payload that is
-- missing. `NS.Icon` answers nil, which is a value a caller can branch on; `NS.MediaFont`
-- answers nil, which core/Constants.lua turns into the client's own STANDARD_TEXT_FONT.
-- Neither is an error: the console loses its columns and keeps its words.

local Media = LibStub and LibStub("LibKa0s-Media-1.0", true)

--- The texture path for one shipped icon, or nil.
---
--- EXTENSIONLESS by design: the library answers `...\media\icons\close`, and the client
--- appends the extension itself. A path carrying `.tga` is one of the two spellings that
--- draws nothing and raises nothing.
---
--- NIL IS A REAL ANSWER, twice over — the library may be absent, and the name may not be
--- one it ships. Both mean the same thing to a caller, which is "draw something else",
--- and both are far better than a plausible path to a texture that is not there.
---
--- @param name string  an entry of the library's `ICONS` catalog, e.g. "close"
--- @return string|nil
function NS.Icon(name)
  if not Media then return nil end
  return Media.Icon(addonName, name)
end

--- The path of one shipped font face, or nil when the library is absent.
---
--- Font paths KEEP their extension where icon paths lose theirs: `SetFont` is handed a
--- file, not a texture name, and a path with the extension stripped draws nothing.
---
--- @param name string  a key of the library's `FONTS`, e.g. "JetBrains Mono"
--- @return string|nil
function NS.MediaFont(name)
  if not Media then return nil end
  return Media.Font(addonName, name)
end

-- REGISTERED AT FILE LOAD, not at PLAYER_LOGIN. LibSharedMedia is vendored under libs/
-- and has therefore already run by the time the TOC reaches core/, while
-- defaults/Profile.lua names its media at load time too; deferring would open a window
-- in which a shipped default named something LSM had never heard of.
--
-- THIS IS A VISIBLE PRODUCT CHANGE and it is deliberate. PanelMaster had never registered
-- a font with LSM — core/Compat.lua registers this addon's solid texture and nothing else
-- — so the first run after this lands adds "JetBrains Mono" to every font dropdown and the
-- library's seven bar textures ("Ka0s Underline 2" and its siblings) to the accent-bar
-- dropdown, which reads from LSM's STATUSBAR pool by design. Nothing already chosen moves:
-- registration only adds names, and the shipped default is still a texture LSM itself
-- always ships. See docs/smoke-tests.md.
--
-- What registration buys over the bare path is the settings panel: a registered face
-- appears in the dropdown beside every other font the player has, and a profile then
-- stores the NAME — portable across installs — rather than a path naming one addon's
-- folder. The library's call is idempotent and points every consumer at one set of bytes
-- under one key, which is what makes two Ka0s addons registering "JetBrains Mono" agree
-- rather than collide.
if Media then Media.RegisterLSM(addonName) end
