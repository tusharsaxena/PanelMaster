local T = _G.PM_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- The addon ships US English everywhere a human wrote the words: labels, tooltips, chat messages,
-- identifiers, comments and the Markdown docs. That is not a taste call — a locale key IS the
-- English source string (localization-§1/§2), so the day someone wraps "Background color" in NS.L
-- the spelling is frozen into every translation file. Drifting back to a British form later would
-- silently orphan the key. This scan is the cheap guard that keeps the whole tree on one dialect.
--
-- Stored field names (bgColor, accentColor, borderColor) and Blizzard/library symbols
-- (SetTextColor, RAID_CLASS_COLORS, GRAY_FONT_COLOR) are already US-spelled, so they never trip it.

-- The British forms worth guarding. Each is a substring match against a lowercased file, so a stem
-- covers its whole family: the colo/ur stem also catches the plural, the participle and the re-
-- prefixed verb, and "cancell" catches both the -ed and the -ing form.
--
-- The first four are written in halves on purpose. The exit criterion for this sweep is a repo-wide
-- grep for exactly those four words that must come back empty, and a guard that spells out the very
-- words it forbids would be the one file standing in its own way.
local BRITISH = {
  "colo" .. "ur", "behavio" .. "ur", "recogni" .. "se", "centr" .. "e",
  "cancell", "grey", "labell", "modell",
  "initialis", "normalis", "serialis", "synchronis", "customis", "organis", "utilis",
  "analyse", "catalogue", "licence", "favourite", "defence", "programme", "whilst",
}

-- Read a file, or fail loudly: a renamed file must update this scan rather than quietly stop
-- being covered.
local function slurp(path)
  local f = assert(io.open(path, "r"), "missing file " .. path)
  local src = f:read("*a")
  f:close()
  return src
end

-- The addon's own sources come from the TOC (libs\ excluded — vendored code is not ours to
-- respell) and the suites come from run.lua's SUITE_FILES, so adding a file to either list puts
-- it under the scan for free. Only the docs need naming by hand.
local function authoredFiles()
  local paths = {}
  for line in slurp("PanelMaster.toc"):gmatch("[^\r\n]+") do
    local rel = line:match("^([%w\\_%-%.]+%.lua)%s*$")
    if rel and not rel:match("^libs\\") then paths[#paths + 1] = (rel:gsub("\\", "/")) end
  end
  paths[#paths + 1] = "PanelMaster.toc"
  paths[#paths + 1] = "tests/run.lua"
  paths[#paths + 1] = "tests/loader.lua"
  paths[#paths + 1] = "tests/wow_mock.lua"
  for suite in slurp("tests/run.lua"):match("local SUITE_FILES = {(.-)}"):gmatch('"([^"]+)"') do
    -- This file is the one authored source that spells the British forms on purpose.
    if suite ~= "test_spelling.lua" then paths[#paths + 1] = "tests/" .. suite end
  end
  -- .luacheckrc is authored English too. It is neither a .lua nor a .md file, which is exactly how
  -- a "Class colour" comment sat in it through the sweep that was meant to remove it.
  --
  -- docs/artwork-spec.md is here for the same reason as the rest: it is handed to CONTRIBUTORS as
  -- the definition of an acceptable asset, and a doc that tells someone to author a "grayscale"
  -- plate while the code calls the field something else is exactly the drift this scan exists to
  -- stop. Frozen bundles under docs/audits/ and docs/reviews/ are deliberately absent — they are
  -- dated records of what was true on a past day, not living text to respell.
  for _, doc in ipairs({ "README.md", "CLAUDE.md", "docs/ARCHITECTURE.md", "docs/agent-context.md",
                         "docs/smoke-tests.md", "docs/test-cases.md", "docs/testing.md",
                         "docs/artwork-spec.md", ".luacheckrc" }) do
    paths[#paths + 1] = doc
  end
  return paths
end

test("Spelling: the TOC and run.lua between them name every authored source", function()
  local paths = authoredFiles()
  local seen = {}
  for _, p in ipairs(paths) do seen[p] = true end
  -- Spot-check one file per layer, so a broken TOC/run.lua parse fails here rather than silently
  -- scanning nothing at all.
  for _, expected in ipairs({ "core/Constants.lua", "modules/Canvas.lua", "settings/PanelEditor.lua",
                              "tests/test_panel.lua", "README.md", ".luacheckrc" }) do
    assertTrue(seen[expected], "the spelling scan does not cover " .. expected)
  end
  assertTrue(#paths > 30, "the spelling scan covers suspiciously few files (" .. #paths .. ")")
end)

test("Spelling: authored English is US English", function()
  local offenders = {}
  for _, path in ipairs(authoredFiles()) do
    local lower = slurp(path):lower()
    for _, word in ipairs(BRITISH) do
      if lower:find(word, 1, true) then
        offenders[#offenders + 1] = path .. " contains '" .. word .. "'"
      end
    end
  end
  assertEqual(#offenders, 0, "British spellings survive: " .. table.concat(offenders, "; "))
end)
