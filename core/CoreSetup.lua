local addonName, NS = ...   -- luacheck: ignore addonName

-- LibKa0s-Core-1.0 seam: the secret-safe stringifier and the prefixed chat printer.
--
-- These two used to live in core/Util.lua, hand-written, in the same shape every other Ka0s addon
-- hand-wrote them. They are now the library's (library-stack). Nothing about the CALL SITES changes:
-- `NS.Print`, `NS.Util.print`, `NS.SafeToString` and `NS.IsConcatSafe` all still answer, because five
-- files take the printer as a file-scope upvalue (`local print = NS.Print`) and every one of them
-- would have to be edited otherwise.
--
-- WHY THIS FILE SITS WHERE IT DOES IN THE TOC — three constraints, all binding:
--   * AFTER core/Namespace.lua, which defines NS.PREFIX. The descriptor takes the tag verbatim, and
--     a seam loading before the constant would capture nil forever. (The library also offers a
--     function form of `prefix` for hosts that cannot satisfy this; PanelMaster can, so it passes
--     the plain string and the ordering is what makes that safe.)
--   * AFTER core/Util.lua, which still owns NS.Util (this file writes NS.Util.print into it).
--   * BEFORE core/PanelMaster.lua, whose AceConsole-3.0 embed overwrites NS.Print with AceGUI's own
--     :Print and whose reclaim line restores it FROM NS.Util.print. Publishing on both keys is what
--     keeps that reclaim load-bearing and correct — it now restores the library's printer.
--   * BEFORE every file taking the printer as a load-time upvalue: modules/Unlock.lua,
--     settings/Schema.lua, settings/Slash.lua, settings/PanelEditor.lua and settings/Panel.lua.
--     All five load after core/, so the whole core/ block satisfies this. core/DebugLogSetup.lua is
--     NOT on this list — it hands the descriptor a `function(line) NS.Print(line) end` closure
--     (core/DebugLogSetup.lua) rather than an upvalue, so it carries no ordering constraint at all.

-- The ONE cause clause every LibKa0s seam in this addon explains an absent library with. Defined
-- here because this is the first of the seams the TOC loads, and set OUTSIDE the `if not lib`
-- branch below because the later seams read it on BOTH paths. Each seam appends its own
-- consequence and its own terminal punctuation, so a degraded install says the same thing about
-- WHY at every site and a different thing about WHAT at each one.
NS.LIBKA0S_MISSING = "The LibKa0s library is missing from this installation of Ka0s Panel Master " ..
    "(expected in libs/LibKa0s)"

local lib = LibStub and LibStub("LibKa0s-Core-1.0", true)

if not lib then
  -- Degrade, never error. The addon's own function — drawing panels — has nothing to do with a
  -- shared library, so an install missing libs/ must still draw panels. The stub therefore has to
  -- answer EVERY member the addon calls, not just the printer: `grep -n "NS.SafeToString\|
  -- NS.IsConcatSafe\|NS.Print\|Util.print"` across the repo is the list, and it is these four.
  --
  -- The guard is reproduced rather than dropped. It is a MUST on the shared printer
  -- (events-frames-taint-§8) regardless of how the printer got here, and a fallback that lost it
  -- would turn a combat-protected value into a Lua error inside table.concat.
  local function probeConcat(v) return table.concat({ v }) end
  function NS.IsConcatSafe(v) return (pcall(probeConcat, v)) end
  function NS.SafeToString(v)
    if v == nil then return "nil" end
    if type(v) == "boolean" then return tostring(v) end
    if NS.IsConcatSafe(v) then return tostring(v) end
    return "<secret>"
  end

  -- Announced ONCE, on the first line the addon prints, rather than at load: a notice emitted
  -- during ADDON_LOADED lands before the chat frame exists on a cold login and is never seen.
  local announced = false
  function NS.Print(...)
    local parts = { NS.PREFIX }
    for i = 1, select("#", ...) do parts[i + 1] = NS.SafeToString((select(i, ...))) end
    if DEFAULT_CHAT_FRAME then
      if not announced then
        announced = true
        DEFAULT_CHAT_FRAME:AddMessage(NS.PREFIX .. " " .. NS.LIBKA0S_MISSING ..
          "; running on reduced built-in fallbacks.")
      end
      DEFAULT_CHAT_FRAME:AddMessage(table.concat(parts, " "))
    end
  end
  NS.Util = NS.Util or {}
  NS.Util.print = NS.Print
  return
end

NS.Core = lib

-- Republished under the addon's own long-standing names rather than renaming ~40 call sites.
NS.IsConcatSafe = lib.IsConcatSafe
NS.SafeToString = lib.SafeToString

-- The prefix is passed VERBATIM as the library requires — never synthesized. NS.PREFIX carries no
-- trailing space of its own, so the default `sep = " "` is correct and is left unstated.
--
-- `sink` is NOT passed: Core's own default is DEFAULT_CHAT_FRAME:AddMessage, which is exactly where
-- this addon's printer has always written and exactly what tests/wow_mock.lua captures.
local printer = lib:New({ prefix = NS.PREFIX })

-- Only Print is republished. The instance also carries `Format` — the same assembly with no sink —
-- and this addon has no caller for it: every printing path goes through NS.Print. Publishing it
-- would put a member on the namespace that nothing calls, and one the degraded branch above could
-- only answer by writing a function for nobody. The seam's surface is therefore exactly what the
-- addon calls, identically on both paths.
NS.Print = printer.Print

-- The real name is NS.Util.print; NS.Print is reclaimed from it after the AceConsole embed
-- (core/PanelMaster.lua, architecture-§2). Both keys point at the same library printer, so the
-- reclaim restores this one.
NS.Util = NS.Util or {}
NS.Util.print = NS.Print

-- DELIBERATELY NOT ADOPTED: Core's window-chrome half (`SKIN`, `ApplySkin`, `MakeCloseButton`).
-- PanelMaster has exactly one standalone window — the debug console — and that window is
-- LibKa0s-DebugLog-1.0's to draw, so it reaches Core's chrome from inside the library rather than
-- through this addon. A host-side re-export would have no caller. NS.Core above is the seam if one
-- ever appears.
