local addonName, NS = ...   -- luacheck: ignore addonName
NS.Compat = NS.Compat or {}
local Compat = NS.Compat

-- Retail-only addon: no game-flavor branching (compat). Every varying / deprecated API is gated by a
-- direct C_*/global presence check here, so a shim degrades to nil/false when its API is absent —
-- never by reading a game-flavor project id. Feature modules call NS.Compat.X, never the raw API.

-- ── Addon roster ────────────────────────────────────────────────────────────────

-- NOTE: the TOC-metadata reader that used to head this file is gone. It now lives in
-- core/EnvSetup.lua as NS.Meta / NS.Version, over LibKa0s-Env-1.0 — it was the same eleven-times
-- duplicated ladder in every addon of this collection, which is what made it the library's rather
-- than ours. The readers below stay: they are PanelMaster's own.

-- Every addon folder present on disk, as a set of folder names, or nil when the roster cannot be
-- read at all.
--
-- Deliberately the INSTALLED list rather than the loaded one: this answers "does this folder exist",
-- which is the only question the Sunn adapter can ask about a pack whose own Lua never ran. A pack
-- is hard-dependent on SunnArt, so a disabled SunnArt means the pack never loads and registers
-- nothing — but its textures are still on disk and still drawable, and this is what tells us so.
--
-- nil, not an empty table, when the API is missing: "cannot tell" and "nothing installed" have to
-- stay distinguishable, or a flavor without the roster would read as a machine with no addons and
-- silently drop every known pack.
function Compat.AddOnFolders()
  local count = C_AddOns and C_AddOns.GetNumAddOns
  local info  = C_AddOns and C_AddOns.GetAddOnInfo
  if type(count) ~= "function" or type(info) ~= "function" then
    count = type(GetNumAddOns) == "function" and GetNumAddOns or nil
    info  = type(GetAddOnInfo) == "function" and GetAddOnInfo or nil
  end
  if not count or not info then return nil end

  local n = tonumber(count())
  if not n then return nil end

  local folders = {}
  for i = 1, n do
    local name = info(i)
    if type(name) == "string" and name ~= "" then folders[name] = true end
  end
  return folders
end

-- ── Screen geometry ─────────────────────────────────────────────────────────────

-- The effective screen size a panel's position is expressed against, in UI units. Used by the
-- registry's off-screen recovery (Registry.Recover) to decide whether a stored offset still lands
-- somewhere the user can reach.
--
-- Guarded rather than assumed: UIParent is a real frame in-game and a stub headlessly, and the stub
-- reports 0×0. A zero reading must read as "cannot tell" (nil) rather than as a genuinely tiny
-- screen, or recovery would drag every panel to the origin the first time it ran headlessly.
function Compat.GetScreenSize()
  if not (UIParent and UIParent.GetWidth and UIParent.GetHeight) then return nil end
  local w, h = UIParent:GetWidth(), UIParent:GetHeight()
  if type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then return nil end
  return w, h
end

-- The UI scale, for translating a drag in screen pixels into the UI units a panel is stored in.
-- Defaults to 1 when unavailable, which is the identity transform and therefore always safe.
function Compat.GetUIScale()
  if UIParent and UIParent.GetEffectiveScale then
    local s = UIParent:GetEffectiveScale()
    if type(s) == "number" and s > 0 then return s end
  end
  return 1
end

-- Is the player in combat? Defaults to FALSE when the API is unavailable, which is the answer that
-- keeps a panel on screen: a general visibility of "Only out of combat" reading `true` on a client
-- that cannot answer would hide the player's whole backdrop for the session with nothing said.
--
-- Read through this seam rather than calling InCombatLockdown at the render site, so the renderer's
-- spec builder stays pure and the headless suite can drive both answers.
function Compat.InCombat()
  if type(InCombatLockdown) ~= "function" then return false end
  return InCombatLockdown() and true or false
end

-- ── Class color ────────────────────────────────────────────────────────────────
--
-- GONE, and deliberately: `Compat.GetClassColor` read `RAID_CLASS_COLORS` here, and
-- `LibKa0s-Core-1.0` minor 7 now owns that lookup for the whole collection as `lib.ClassColor`
-- (options-ui-§17: one resolver, never a fifth private copy). This addon's recorded argument is the
-- one the library adopted -- RAID_CLASS_COLORS is the table every other UI on the player's screen
-- is already reading -- so the source did not change, only who owns it. Core also memoizes the
-- PLAYER's answer on success, which this copy never did.
--
-- Reached through `NS.Core.ClassColor` / `NS.Core.ResolveColor`, from `Util.ResolveColor`, which is
-- still this addon's single color seam. Nothing else in the addon asks for a class color.

-- ── Shared media ────────────────────────────────────────────────────────────────

-- Register the addon's own media entries. LibSharedMedia ships a "Solid" BACKGROUND but no solid
-- BORDER, and a plain 1px outline is this addon's default look, so it is contributed rather than
-- depended on. Registering is idempotent and harmless if another addon already did the same.
--
-- Called from OnInitialize. A no-op without LSM, which is the OptionalDep case.
function Compat.RegisterMedia()
  local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
  if not (LSM and LSM.Register) then return false end
  local C = NS.Constants
  LSM:Register("border", C.SOLID_MEDIA_NAME, C.SOLID_TEXTURE)
  LSM:Register("background", C.SOLID_MEDIA_NAME, C.SOLID_TEXTURE)
  -- LSM ships a "Solid" statusbar, but registering is a no-op when the name is taken and this way
  -- the accent bar's default resolves even against a build that drops it.
  LSM:Register("statusbar", C.SOLID_MEDIA_NAME, C.SOLID_TEXTURE)
  return true
end

-- Resolve a LibSharedMedia name of a given media type ("background" / "border") to a texture path.
--
-- Two independent failure modes, both of which must degrade rather than render nothing
-- (library-stack-§6): LibSharedMedia may be absent entirely, and a stored name may belong to an
-- addon the user has since uninstalled. Either way this returns the built-in flat white, which is
-- exactly the stock look — so a panel with a missing texture looks plain, not invisible.
--
-- `nil` is returned only for the explicit "None" entry, which is a real user choice meaning "draw
-- nothing here".
function Compat.FetchMedia(mediaType, name)
  if name == NS.Constants.NONE_MEDIA_NAME then return nil end
  local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
  if not (LSM and LSM.Fetch) then return NS.Constants.SOLID_TEXTURE end
  local path = name and LSM:Fetch(mediaType, name, true)
  return path or NS.Constants.SOLID_TEXTURE
end

-- The names registered for a media type, for the settings dropdowns. Queried at click time rather
-- than cached, because other addons register media throughout the session.
--
-- "None" is guaranteed to be in the list. LibSharedMedia ships it for both media types today, but
-- "draw no border" / "draw no fill" is a choice this addon's UI must always be able to offer, and
-- depending on a third-party lib's default registrations for it would make that a promise this addon
-- does not control.
function Compat.MediaList(mediaType)
  local out, seen = {}, {}
  local function add(name)
    if name and not seen[name] then
      seen[name] = true
      out[#out + 1] = name
    end
  end

  add(NS.Constants.NONE_MEDIA_NAME)

  local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
  local list = (LSM and LSM.List) and LSM:List(mediaType) or nil
  if list then
    for _, name in ipairs(list) do add(name) end
  end
  -- Without LSM there is still exactly one real texture to offer: the built-in flat fill.
  add(NS.Constants.SOLID_MEDIA_NAME)
  return out
end

-- Is the cursor over this frame? Used by the mouseover fade, which deliberately does NOT enable
-- mouse input on the panel: a panel that took the mouse would stop being click-through, which is
-- the one thing a backdrop must never do. `MouseIsOver` answers the question without claiming the
-- input.
function Compat.MouseIsOver(frame)
  if type(MouseIsOver) ~= "function" or not frame then return false end
  local ok, result = pcall(MouseIsOver, frame)
  return ok and result and true or false
end

-- NOTE: there is deliberately no backdrop-support shim here. Asking whether BackdropTemplateMixin
-- exists says nothing about the frame in hand; modules/Canvas.lua guards on the frame instance's own
-- SetBackdrop method instead, which is the stronger check and the only one it can act on
-- (anti-patterns #10 — no deprecated API is being wrapped, so nothing belongs in Compat).
