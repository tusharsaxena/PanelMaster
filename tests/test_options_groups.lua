-- tests/test_options_groups.lua — the `options-ui-§16` register gate over the Panels page.
--
-- WHAT IT PROVES. That every hand-written border, bar or font block in `settings/PanelEditor.lua`
-- is named by a ratified row in `docs/ARCHITECTURE.md` ▸ `## Documented deviations` citing
-- `options-ui-§16`, that each such row carries a re-check trigger, and that no row outlives the
-- block it was written for. It reads the blocks from the editor's own source and the rows from the
-- register, and compares them in BOTH directions.
--
-- WHY IT EXISTS. `options-ui-§16` says the border, bar and font blocks are COMPOSED — the library
-- emits each from one declaration, and a hand-written copy is anti-pattern #73. Three of this
-- addon's blocks are typed out, and they have a reason: `O.BorderGroup` and `O.BarGroup` emit
-- path-keyed SCHEMA rows, and the Panels page edits registry RECORDS, which carry no path. There is
-- no arm of either composer this page could call. The reason is good and it is still a deviation,
-- so it belongs in the register with a trigger rather than in a comment — which is the ruling this
-- gate was added with. `docs/settings-panel.md` argued the same case for a month while the register
-- said nothing, and an audit re-filed it every cycle because a deviation that is not in the table is
-- not ratified.
--
-- WHAT THE GATE IS FOR, once the rows exist. The rows are the easy part; keeping them true is not.
-- Two things can rot here and both are silent:
--
--   * a FOURTH hand-written block. Someone adds a font group to the Artwork tab, honors the row set
--     by hand because that is what the file already does, and the register never hears about it.
--   * a block that goes AWAY. The library gains a record-backed arm, the block is composed, the
--     hand-written copy is deleted — and the row stays behind claiming a deviation this addon no
--     longer has. `## Documented deviations` says in as many words that it is not a graveyard.
--
-- HOW A BLOCK IS RECOGNIZED. By its LEADING row, which `options-ui-§16` names: `Font`, `Border
-- style`, `Bar texture`. Each is a shared-media picker, and every one on this page is built by
-- `makeMediaDropdown`, so the leading rows are exactly the `makeMediaDropdown` calls carrying one of
-- those three labels. `Background texture` is deliberately not among them: a group over a background
-- is not a bar group (`options-ui-§16`), it takes the swatch and its companion and nothing else, and
-- this page's background group does exactly that.
--
-- The block's IDENTITY is the stored field the picker writes — `borderTexture`, `accentTexture`,
-- `accentBorderTexture` — and that is what a register row has to name, backticked, in its *What
-- differs* cell. A field key is the one name here that neither a re-label nor a line-number drift
-- can move, and it is how the two directions below are matched up. Line numbers are prose in this
-- repository and this gate does not read them, for the reason `tests/test_layout_cap.lua` gives
-- about the figures in its own census.
--
-- IT FAILS RATHER THAN PASSES WHEN IT CANNOT LOOK. No editor source, no ARCHITECTURE.md, no
-- register heading, no blocks found at all — every one of those is a failure, not a skip. A gate
-- that goes quiet when it is blind reports success, which is worse than not existing.

local T = _G.PM_TEST
local test, fail = T.test, T.fail

local EDITOR       = "settings/PanelEditor.lua"
local ARCHITECTURE = "docs/ARCHITECTURE.md"
local REGISTER     = "## Documented deviations"
-- The rule id, with the section sign written as its two UTF-8 bytes so this file stays ASCII the way
-- its siblings are. Split at the escape because Lua reads up to three digits after a backslash, and
-- `\16716` would otherwise have to be counted out by whoever reads it next.
local RULE         = "options-ui-\194\167" .. "16"

-- The three block-leading labels `options-ui-§16` mandates. A media picker carrying one of these is
-- the head of a canonical block; one carrying anything else is a media row standing alone, which the
-- rule says is a finder rather than a finding.
local BLOCK_HEADS = {
  ["Font"]         = "the font block",
  ["Border style"] = "the border block",
  ["Bar texture"]  = "the bar block",
}

--- Read a whole file, or fail naming it. Never returns nil.
local function readOrFail(path, why)
  local fh = io.open(path, "r")
  if not fh then fail("optionsgroups: " .. path .. " could not be opened, so " .. why) end
  local body = fh:read("*a") or ""
  fh:close()
  return (body:gsub("\r\n", "\n"))
end

--- Every hand-written canonical block on the Panels page, as { field, label } in source order.
---
--- `%b()` rather than a line pattern: the calls wrap, and their tooltips run to several lines. The
--- two quoted strings after `rec,` are the stored field and the row's label, in that order, and the
--- helper's own signature at the top of the file pins that order.
local function handWrittenBlocks()
  local src = readOrFail(EDITOR, "the blocks this gate compares against cannot be read")

  local blocks = {}
  for call in src:gmatch("makeMediaDropdown%b()") do
    local field, label = call:match('rec%s*,%s*"([%w_]+)"%s*,%s*"([^"]+)"')
    if field and BLOCK_HEADS[label] then
      blocks[#blocks + 1] = { field = field, label = label }
    end
  end

  if #blocks == 0 then
    fail("optionsgroups: no canonical block was found in " .. EDITOR .. " at all. Either every one "
      .. "of them is composed now — in which case delete the `" .. RULE .. "` rows from "
      .. ARCHITECTURE .. " and this gate with them — or `makeMediaDropdown` has been renamed and "
      .. "this gate has gone blind, which it must not do quietly")
  end
  return blocks
end

--- The `options-ui-§16` rows of the deviation register, as { differs, trigger, fields } .
---
--- A row is a table line inside the register section; the header and the `|---|` separator carry
--- fewer than the five cells a row has and fall out on their own. Reading stops at the next heading
--- of any level, so a later table cannot leak into this one.
local function registerRows()
  local body = readOrFail(ARCHITECTURE, "this gate cannot tell a ratified deviation from an "
    .. "unratified one")

  local rows, inside, found = {}, false, false
  for line in (body .. "\n"):gmatch("([^\n]*)\n") do
    if line == REGISTER then
      inside, found = true, true
    elseif inside and line:sub(1, 1) == "#" then
      break
    elseif inside and line:sub(1, 1) == "|" then
      local cells = {}
      for cell in line:gmatch("|([^|]*)") do cells[#cells + 1] = cell end
      -- Five cells and a trailing empty one from the closing pipe: rule, what differs, why,
      -- decided, re-check trigger.
      if #cells >= 5 and cells[1]:find(RULE, 1, true) then
        local fields = {}
        for token in cells[2]:gmatch("`([%w_]+)`") do fields[token] = true end
        rows[#rows + 1] = {
          differs = (cells[2]:gsub("^%s*(.-)%s*$", "%1")),
          trigger = (cells[5]:gsub("^%s*(.-)%s*$", "%1")),
          fields  = fields,
        }
      end
    end
  end

  if not found then
    fail("optionsgroups: " .. ARCHITECTURE .. " carries no '" .. REGISTER .. "' section. That "
      .. "table is the single home for a ratified deviation (`documentation-§3`), and it must not "
      .. "be removed or renamed while this gate names it")
  end
  return rows
end

-- ---------------------------------------------------------------------------
-- The two directions, and the trigger
-- ---------------------------------------------------------------------------

test("optionsgroups: every hand-written canonical block is ratified in the deviation register",
function()
  local rows = registerRows()

  local unratified = {}
  for _, block in ipairs(handWrittenBlocks()) do
    local named = false
    for _, row in ipairs(rows) do
      if row.fields[block.field] then named = true break end
    end
    if not named then
      unratified[#unratified + 1] = block.field .. " (" .. BLOCK_HEADS[block.label] .. ")"
    end
  end

  if #unratified > 0 then
    fail("optionsgroups: hand-written `" .. RULE .. "` blocks with no row in " .. ARCHITECTURE
      .. " \226\150\184 " .. REGISTER .. ": " .. table.concat(unratified, ", ")
      .. " — either compose the block, or add a row citing `" .. RULE .. "` that names the stored "
      .. "field in backticks, says why the composer cannot be called, and carries a re-check "
      .. "trigger. A deviation that is not in that table is not ratified, and an audit re-files it "
      .. "every cycle")
  end
end)

test("optionsgroups: no register row outlives the block it records", function()
  local live = {}
  for _, block in ipairs(handWrittenBlocks()) do live[block.field] = true end

  local spent = {}
  for i, row in ipairs(registerRows()) do
    local names = false
    for field in pairs(row.fields) do
      if live[field] then names = true break end
    end
    if not names then
      spent[#spent + 1] = "row " .. i .. " (" .. row.differs:sub(1, 60) .. "\226\128\166)"
    end
  end

  if #spent > 0 then
    fail("optionsgroups: `" .. RULE .. "` rows in " .. ARCHITECTURE .. " naming no block that is "
      .. "still hand-written in " .. EDITOR .. ": " .. table.concat(spent, ", ")
      .. " — if the block is composed now the row has done its work and is retired, not kept for "
      .. "the history; if the row is about a block that is still there, name that block's stored "
      .. "field in backticks so this gate and the next auditor can both find it")
  end
end)

test("optionsgroups: every " .. RULE .. " register row carries a re-check trigger",
function()
  local triggerless = {}
  for i, row in ipairs(registerRows()) do
    -- An em-dash, a "—" alone or an empty cell are all the same thing: a row nothing will ever
    -- retire. `layout-§1`'s three terminal states and `documentation-§3`'s register both turn on
    -- the trigger being followable, so a placeholder is worse than no row.
    local trigger = row.trigger:gsub("\226\128\148", ""):gsub("%s", "")
    if trigger == "" then
      triggerless[#triggerless + 1] = "row " .. i .. " (" .. row.differs:sub(1, 60) .. "\226\128\166)"
    end
  end

  if #triggerless > 0 then
    fail("optionsgroups: `" .. RULE .. "` rows with an empty re-check trigger: "
      .. table.concat(triggerless, ", ") .. " — a ratified deviation says what would make it stop "
      .. "being one, or it is a permanent exemption wearing a deviation's clothes")
  end
end)
