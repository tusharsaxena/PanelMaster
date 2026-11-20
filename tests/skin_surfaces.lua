-- tests/skin_surfaces.lua — this addon's painted surfaces, declared for the kit's skin-switch test
-- (tests/_kit/test_skin_switch.lua, kit revision 50, skinning-§1). tests/run.lua sets Kit.skinSwitch
-- from it. Loaded with dofile (it registers no case of its own).
--
-- WHAT IS HERE. Everything this addon's own code paints, one entry per painted object, because a
-- surface passes on any change under it and a whole page would pass on its first recolored child:
-- the unlock overlay's outline and name label, and on the settings pages the picker's "(disabled)"
-- marker, the tooltips' emphasis, and the rows the Panels page acquires itself, past the Options
-- instance's owner proxy (settings/PanelEditor.lua).
--
-- WHAT IS NOT. The panels are the player's content and no skin repaints them (cause A8), their
-- new-panel defaults included (the owner's U-23, 2026-11-20). The debug console, the first-run
-- picker and every row the Options instance draws are the library's, and its own suite holds them.
-- No surface carries a companion: nothing here has a `<key>FromSkin` row.
--
-- THE FAMILY FIELDS (kit revision 58, SD-SK-PM of Ka0sAddonsCommonTasks
-- docs/2026-11-20-LIBKA0S_94_97_99_100/). Each surface below must move every setter family it draws
-- on its own: color on all six, and the face on the unlock label (first pass) and the create box.
-- None takes `expect`, `hold` or `clear`, and each for a reason: no surface draws a texture (the
-- outline is SetColorTexture, a color; the heading's divider and the create box are SkinAce's color
-- paints), none holds a StatusBar (the addon creates none; the accent strip is a plain Texture on a
-- panel, cause A8), and no ruling keeps a family of these fixed. A surface added later that draws
-- skin art or a fill on a Texture declares `expect = "texture"`.
--
-- THE MEDIA FAKE. The skin paints a face only when LibSharedMedia resolves its key, and this
-- harness has no LibSharedMedia, so without a fake every face fell back to the stock one under
-- every skin and the font family was never asked. `begin` installs one for the surface's life that
-- answers every shipped skin's font and statusbar keys with a path of its own, as the library's own
-- switch fixture does (LibKa0s tests/fixture_skin_switch.lua), so a face that stops following fails.
--
-- Scope: every settings surface is `scope = "panel"`, since Ignore settings panel keeps it stock.
-- The unlock overlay is a surface of this addon's own and follows the skin either way.
--
-- THE FIXTURES. The kit's AceGUI widgets are recorders with no regions, so a row is dressed in the
-- frame and regions the real widget has, from the kit's paint recorder, for SkinAce to paint. The
-- recorder stays installed only while `build` and its repaints run; `reset`, which the kit runs
-- after every surface whatever it raised, takes it off and clears what the surface left.

return function(NS, mocks)
  local AceGUI = mocks.LibStub("AceGUI-3.0", true)
  local installPaint = dofile("tests/_kit/mock_paint.lua")
  local E, U, R, Canvas = NS.PanelEditor, NS.Unlock, NS.Registry, NS.Canvas

  local undo = {}
  local function later(fn) undo[#undo + 1] = fn end

  local function reset()
    for i = #undo, 1, -1 do undo[i]() end
    undo = {}
    mocks.__inCombat = false
    U:SetUnlocked(false)
    R:DeleteAll()
    E.__setSelectedID(nil)
    Canvas:RenderAll()
  end

  --- A LibSharedMedia fake answering every shipped skin's font and statusbar keys with a path of
  --- its own, installed in place of whatever the mocks hold; answers the function that puts it back.
  local function installMedia()
    local Skin, map = mocks.LibStub("LibKa0s-Skin-1.0"), {}
    local KINDS = { ["bar.texture"] = "statusbar", ["font.body"] = "font", ["font.title"] = "font",
                    ["font.mono"] = "font", ["hud.font"] = "font" }
    for _, def in ipairs(Skin:Skins()) do
      local t = Skin:ResolveSkin(def.key)
      for token, kind in pairs(KINDS) do
        local key = t[token]
        if type(key) == "string" and key ~= "" then
          map[kind .. ":" .. key] = "Interface\\AddOns\\SkinProbe\\" .. kind .. "\\" .. key
        end
      end
    end
    local saved = mocks.__libs["LibSharedMedia-3.0"]
    mocks.__libs["LibSharedMedia-3.0"] = {
      MediaType = { BACKGROUND = "background", BORDER = "border", FONT = "font",
                    STATUSBAR = "statusbar", SOUND = "sound" },
      Fetch = function(_, kind, key) return map[kind .. ":" .. tostring(key)] end,
      IsValid = function(_, kind, key) return map[kind .. ":" .. tostring(key)] ~= nil end,
      List = function() return {} end,
      HashTable = function() return {} end,
      Register = function() return true end,
    }
    return function() mocks.__libs["LibSharedMedia-3.0"] = saved end
  end

  --- One record, the editor's selection, and the recorder and the media fake on.
  local function begin(opts)
    later(installPaint(mocks))
    later(installMedia())
    local rec = R:New("Surface", opts or {})
    E.__setSelectedID(rec.id)
    return rec
  end

  --- A fresh Panels page on `tab` (tests/test_skin_settings.lua's renderEditor).
  local function page(tab)
    local ctx = NS.Helpers.CreatePanel(nil, "Panels", { pageKey = "panels" })
    ctx.dropdowns, ctx.rebuilders = {}, {}
    ctx.refreshers = ctx.refreshers or {}
    E:BuildPage(ctx)
    ctx.activeTab = tab
    E:Rebuild(ctx)
    return ctx
  end

  --- A FontString that shows a string a repaint hands it, so the kit's setter spy can read markup.
  local function textHolder()
    return mocks.CreateFrame("Frame"):CreateFontString(nil, "OVERLAY")
  end

  --- The unlocked overlay of one fresh panel.
  local function overlay()
    local rec = begin()
    U:SetPanelUnlocked(rec.id, true)
    return Canvas:FrameFor(rec.id).overlay
  end

  --- `widget` dressed as the client's: a frame for SkinAce to paint, and `parts(frame)`'s regions.
  local function dress(widget, parts)
    widget.frame = mocks.CreateFrame("Frame")
    for key, part in pairs(parts(widget.frame)) do widget[key] = part end
    NS.SkinPaintAce(widget)
    return widget
  end

  local function headingParts(frame)
    return {
      label = frame:CreateFontString(nil, "OVERLAY"),
      left = frame:CreateTexture(nil, "BACKGROUND"),
      right = frame:CreateTexture(nil, "BACKGROUND"),
    }
  end

  local function editBoxParts(frame)
    return {
      label = frame:CreateFontString(nil, "OVERLAY"),
      editbox = mocks.CreateFrame("EditBox", nil, frame),
    }
  end

  return {
    owner = "PanelMaster",
    skin = function() return mocks.LibStub("LibKa0s-Skin-1.0") end,
    reset = reset,
    surfaces = {
      { name = "the unlock outline",
        build = function()
          local e = overlay().edges
          return e.TOP, e.BOTTOM, e.LEFT, e.RIGHT
        end },

      { name = "the unlock name label",
        build = function() return overlay().label end },

      { name = "the panel picker's (disabled) marker", scope = "panel",
        build = function()
          local rec = begin({ enabled = false })
          return textHolder(), rec
        end,
        paint = function(fs, rec)
          fs:SetText(page(E.TABS[1]).__pmPicker.list[rec.id])
        end },

      { name = "an editor tooltip's emphasis", scope = "panel",
        build = function()
          begin()
          return textHolder()
        end,
        paint = function(fs)
          local from = #AceGUI.__created + 1
          page(E.TABS[1])
          local box
          for i = from, #AceGUI.__created do
            local w = AceGUI.__created[i]
            if w.labelText == "Panel name" then box = w end
          end
          local saved, body = mocks.GameTooltip, nil
          mocks.GameTooltip = setmetatable({
            AddLine = function(_, text) body = text end,
          }, { __index = function() return function() end end })
          box:__fire("OnEnter")
          mocks.GameTooltip = saved
          fs:SetText(body)
        end },

      { name = "the band's create box", scope = "panel",
        build = function()
          begin()
          local ctx = page(E.TABS[1])
          local box = dress(ctx.__pmNewBox, editBoxParts)
          later(function() box.frame, box.label, box.editbox = nil, nil, nil end)
          return box.frame, box.label, box.editbox
        end },

      { name = "an editor heading", scope = "panel",
        build = function()
          begin()
          local frame = mocks.CreateFrame("Frame")
          local parts = headingParts(frame)
          local real = AceGUI.Create
          -- Every Heading a repaint acquires is dressed in the same regions, as AceGUI's pool does.
          AceGUI.Create = function(self, wtype)
            local w = real(self, wtype)
            if wtype == "Heading" then
              w.frame, w.label, w.left, w.right = frame, parts.label, parts.left, parts.right
            end
            return w
          end
          later(function() AceGUI.Create = real end)
          return frame, parts.label, parts.left, parts.right
        end,
        paint = function() page(E.TABS[2]) end },
    },
  }
end
