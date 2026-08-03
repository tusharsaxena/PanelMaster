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
-- prefixed verb.
--
-- Two doubled-l verbs are the exception, spelled out per inflection instead of left as a bare
-- "cancell"/"totall" stem: those stems also swallow words that are correct US English, because
-- "cancellation" and "totally" keep the double l on this side of the Atlantic too. A guard that
-- fails the build on "totally" is a guard the next reader learns to work around.
--
-- The first four are written in halves on purpose. The exit criterion for this sweep is a repo-wide
-- grep for exactly those four words that must come back empty, and a guard that spells out the very
-- words it forbids would be the one file standing in its own way.
--
-- Stems ending in "-is" are matched only when a British VERB suffix follows them (see `hits`
-- below), because the bare noun is often correct US English: "analysis", "paralysis" and
-- "emphasis" are all right, and only the verb forms move. That is why the list carries "analyse"
-- and "paralyse" rather than "analys" — and why "optimis" does not fail the build on "optimistic".
--
-- The rule this guard enforces is a DIALECT, not a word list. The first pass shipped a list, and
-- the tree still carried "honoured", "honouring" and "neighbouring" the day after it went green —
-- ordinary British prose that no canonical list happened to name. So the "-our" family is guarded
-- as a family (each stem covers its own plural, participle and adverb), and the rest of the
-- ordinary British forms an addon comment plausibly reaches are named alongside it. Anything found
-- later belongs here too; the list is meant to grow, not to be complete.
--
-- Deliberately absent: "prologue", "epilogue" and "monologue", which are the standard US spellings
-- and not the British halves of anything. "catalogue"/"dialogue" are above because software US
-- English really does write "catalog"/"dialog".
local BRITISH = {
  "colo" .. "ur", "behavio" .. "ur", "recogni" .. "se", "centr" .. "e",
  "cancelled", "cancelling", "canceller", "totalled", "totalling",
  "grey", "labell", "modell", "travell", "levell", "signall", "fuell",
  "initialis", "normalis", "serialis", "synchronis", "customis", "organis", "utilis",
  "optimis", "categoris", "prioritis", "sanitis", "visualis", "minimis", "maximis",
  "summaris", "finalis", "itemis", "randomis", "tokenis", "capitalis", "localis",
  "modularis", "standardis", "specialis", "generalis", "authoris",
  "analyse", "paralyse", "catalogue", "dialogue", "licence", "favour", "defence", "programme",
  "practise", "fulfilment", "offence", "pretence", "artefact", "judgement", "acknowledgement",
  "whilst",
  -- The "-our" family, as a family.
  "honour", "neighbour", "armour", "rumour", "humour", "vigour", "rigour", "savour",
  "endeavour", "flavour", "labour", "odour", "valour", "harbour", "splendour", "ardour",
  "clamour", "candour", "demeanour", "fervour", "parlour", "saviour", "tumour",
  -- The rest of the ordinary British forms, doubled-l verbs and single-l nouns alike.
  "marvellous", "skilful", "wilful", "instalment", "enrolment", "sceptic", "aluminium",
  "focussed", "targetted", "targetting", "storey", "plough", "draught", "kerb", "mould",
  "smoulder", "manoeuvre",
}

-- One word against one lowercased file. Plain substring for almost everything — but a stem ending
-- in "-is" is the doubled-l problem in another costume: "optimis" is inside "optimistic",
-- "specialis" inside "specialist", and "organis" inside both "organist" and "organism", all of
-- which are correct US English that this guard must not fail the build on.
--
-- What separates the two is the very next letter. Every British inflection of an "-ise" verb
-- continues with e, a or i (optimise, optimised, optimises, optimising, optimisation); the US noun
-- continues with t (or m). So these stems are matched only with the verb suffix attached, which
-- costs nothing in coverage and removes the whole "-ist" family of false failures at once.
local function hits(lower, word)
  if word:sub(-2) == "is" then
    return lower:find(word .. "e", 1, true)
        or lower:find(word .. "a", 1, true)
        or lower:find(word .. "i", 1, true)
  end
  return lower:find(word, 1, true)
end

-- Read a file, or fail loudly: a renamed file must update this scan rather than quietly stop
-- being covered.
local function slurp(path)
  local f = assert(io.open(path, "r"), "missing file " .. path)
  local src = f:read("*a")
  f:close()
  return src
end

-- The addon's own sources come from the TOC (libs\ excluded — vendored code is not ours to
-- respell) and the suites come from run.lua's SUITES list, so adding a file to either list puts
-- it under the scan for free. Only the docs need naming by hand.
--
-- tests/_kit/ is excluded for exactly the same reason as libs\: it is the shared LibKa0s test kit,
-- vendored whole-folder and byte-identical to its source of truth. Respelling a word in it would
-- fork the copy, which the vendoring gate then reports as drift.
--
-- modules/SunnArtPacks.lua is excluded on a third reason, and a narrower one: every string in its
-- generated block is ANOTHER ADDON'S, reproduced verbatim so a theme reads in this dropdown the way
-- it reads in SunnArt's. Art Pack 1 ships a theme called "Grey". Respelling it would rename a thing
-- this addon does not own and does not ship, and the next generator run would put it straight back.
-- The file's own authored prose — its header comment — is not covered by this exemption in spirit,
-- so keep that prose US English by hand; the scan cannot tell the two apart, which is precisely why
-- the exemption is per-file and called out here rather than added to the word list.
--
-- docs/pending/LEDGER.md takes the narrower form of the same exemption: a table of words rather
-- than `true`, so the file IS scanned and only the one unavoidable word is waived. Row ARTWORK-11
-- records why the SunnArt exemption exists and cannot do so without naming the theme, "Grey".
-- Every other British form in that ledger is still a failure there.
local EXEMPT = {
  ["modules/SunnArtPacks.lua"] = true,
  ["docs/pending/LEDGER.md"] = { grey = true },
}

local function authoredFiles()
  local paths = {}
  for line in slurp("PanelMaster.toc"):gmatch("[^\r\n]+") do
    local rel = line:match("^([%w\\_%-%.]+%.lua)%s*$")
    rel = rel and (rel:gsub("\\", "/")) or nil
    if rel and not rel:match("^libs/") and EXEMPT[rel] ~= true then paths[#paths + 1] = rel end
  end
  paths[#paths + 1] = "PanelMaster.toc"
  paths[#paths + 1] = "tests/run.lua"
  paths[#paths + 1] = "tests/wow_mock.lua"
  -- BASENAMES since the kit's runner appends the extension itself. A suite listed in run.lua but
  -- not yet written on disk is skipped by the runner, so it is skipped here too rather than
  -- failing the scan on a file that does not exist.
  for suite in slurp("tests/run.lua"):match("local SUITES = {(.-)}"):gmatch('"([^"]+)"') do
    -- This file is the one authored source that spells the British forms on purpose.
    local path = "tests/" .. suite .. ".lua"
    if suite ~= "test_spelling" and io.open(path, "r") then paths[#paths + 1] = path end
  end
  -- .luacheckrc is authored English too. It is neither a .lua nor a .md file, which is exactly how
  -- a British-spelled "class color" comment sat in it through the sweep meant to remove it.
  --
  -- docs/artwork-spec.md is here for the same reason as the rest: it is handed to CONTRIBUTORS as
  -- the definition of an acceptable asset, and a doc that tells someone to author a "grayscale"
  -- plate while the code calls the field something else is exactly the drift this scan exists to
  -- stop. Frozen bundles under docs/audits/ and docs/reviews/ are deliberately absent — they are
  -- dated records of what was true on a past day, not living text to respell.
  --
  -- The tools/ generators are authored English too, and their docstrings are read by the same
  -- contributors as the docs. They are not .lua, so nothing else here would ever reach them.
  for _, doc in ipairs({ "README.md", "CLAUDE.md", "docs/ARCHITECTURE.md",
                         "docs/smoke-tests.md", "docs/test-cases.md", "docs/testing.md",
                         "docs/artwork-spec.md", "docs/pending/LEDGER.md", ".luacheckrc",
                         "tools/artwork/make_poster.py", "tools/artwork/artwork_cleaner.py",
                         "tools/artwork/update_catalog.py", "tools/sunn/build_manifest.py" }) do
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
                              "tests/test_panel.lua", "README.md", "docs/pending/LEDGER.md",
                              ".luacheckrc" }) do
    assertTrue(seen[expected], "the spelling scan does not cover " .. expected)
  end
  assertTrue(#paths > 30, "the spelling scan covers suspiciously few files (" .. #paths .. ")")
end)

-- The matcher's own two directions, asserted on literal strings rather than on the tree. A guard
-- that quietly stops catching things looks exactly like a clean repo, and a guard that fails on
-- correct US English is one the next reader routes around — so both halves are pinned here.
test("Spelling: the matcher catches the British verb and spares the US noun", function()
  for _, british in ipairs({ "optimise", "optimised", "optimises", "optimising", "optimisation",
                             "specialised", "organising", "capitalisation", "finalise",
                             "generalised", "localisation", "colour", "cancelled", "honoured",
                             "neighbouring" }) do
    local caught = false
    for _, word in ipairs(BRITISH) do
      if hits(british, word) then caught = true end
    end
    assertTrue(caught, "the scan would not catch '" .. british .. "'")
  end
  -- Correct US English that shares a stem with a guarded British verb. Every one of these tripped
  -- the guard before the "-is" stems learned to require the verb suffix.
  for _, us in ipairs({ "optimistic", "optimistically", "specialist", "capitalist", "finalist",
                        "generalist", "organist", "organism", "localist", "analysis", "emphasis",
                        "totally", "cancellation", "canceler", "gray", "leveled", "traveled" }) do
    for _, word in ipairs(BRITISH) do
      assertTrue(not hits(us, word), "the scan fails the build on US English '" .. us ..
                 "' (matched '" .. word .. "')")
    end
  end
end)

test("Spelling: authored English is US English", function()
  local offenders = {}
  for _, path in ipairs(authoredFiles()) do
    local lower = slurp(path):lower()
    local waived = EXEMPT[path]
    if type(waived) ~= "table" then waived = {} end
    for _, word in ipairs(BRITISH) do
      if not waived[word] and hits(lower, word) then
        offenders[#offenders + 1] = path .. " contains '" .. word .. "'"
      end
    end
  end
  assertEqual(#offenders, 0, "British spellings survive: " .. table.concat(offenders, "; "))
end)
