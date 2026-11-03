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
-- WHAT IS NOT. The panels are the player's content and no skin repaints them (cause A8). The debug
-- console, the first-run picker and every row the Options instance draws are the library's, and
-- its own suite holds them. No surface carries a companion: nothing here has a `<key>FromSkin` row.
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

  --- One record, the editor's selection, and the recorder on.
  local function begin(opts)
    later(installPaint(mocks))
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
