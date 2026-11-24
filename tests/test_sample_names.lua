-- tests/test_sample_names.lua — no sample person is typed outside tests/ (FB2-PM-01, LibKa0s#104).
--
-- THE RULE. preview-mode, *Sample characters*, from standard v2.120.0 and LibKa0s v1.113.0: every
-- named sample person an addon draws (a test mode, a sim, a preview or unlock stand-in, a sample chat
-- line or toast) comes from LibKa0s-Sim-1.0, the five protagonists through `Sim.Sample(client)` and
-- everyone else from the seeded crowd `Sim.SampleCrowd`. No addon keeps a name list of its own, and a
-- suite SHOULD assert that no `Sample...`/`Mock...` person literal lives outside `tests/`.
--
-- WHY IT IS SHORT HERE. Panel Master draws no sample person at all. It has no test mode and no sim
-- (unlocking is its preview, and what an unlock shows is the player's own panels, by name), and it
-- consumes neither LibKa0s-Sim-1.0 nor the library's Widgets. So the audit moved nothing, and this
-- gate is what keeps it that way: the first hand-typed `Samplemage` or `Mockrealm` outside the suite
-- goes red here, and the fix is the library's surface, not a list beside it.
--
-- WHAT COUNTS AS A PERSON LITERAL. The convention's own shape: one capitalized word that starts
-- `Sample` or `Mock` and carries at least one more lowercase letter (a name, surname, pet or realm,
-- `Samplerealm` and `Mockrealm` included). The bare words `Sample` and `Mock` are prose ("Mock
-- fidelity", the harness's `Mock - Realm` profile key) and English inflections (`Samples`,
-- `Mocked`) are not people, so neither is flagged.
--
-- WHAT IT SCANS. Every path git tracks except `tests/` (the suite and its mocks own their fixtures),
-- `libs/` (the library is where the names live) and the frozen bundles under docs/ (audits, reviews,
-- automated-tests, perf-analysis, revendor, superpowers), which record what was true and are never
-- edited. Binary media is skipped by extension.
--
-- IT FAILS RATHER THAN PASSES WHEN IT CANNOT LOOK, the bargain tests/test_lintconfig.lua strikes: no
-- `io.popen`, no git, or an unreadable tracked file is a failure, never a skip.

local T = _G.PM_TEST
local test, fail, assertEqual, assertTrue = T.test, T.fail, T.assertEqual, T.assertTrue
local mocks = T.mocks
local ROOT = T.root or "."

local SKIPPED_PREFIXES = {
  "tests/", "libs/",
  "docs/audits/", "docs/reviews/", "docs/automated-tests/", "docs/perf-analysis/",
  "docs/revendor/", "docs/superpowers/",
}

local BINARY = { tga = true, png = true, jpg = true, blp = true, ttf = true, otf = true, ogg = true,
  mp3 = true, wav = true }

-- English words that start like a sample name and are not one.
local NOT_PEOPLE = { Samples = true, Sampled = true, Sampler = true, Sampling = true,
  Mocked = true, Mocks = true, Mocking = true, Mockup = true, Mockups = true }

--- Every sample-person literal in `line`, in order of appearance.
local function personLiterals(line)
  local found = {}
  for word in line:gmatch("%f[%w_](%u%l+)%f[^%w_]") do
    local isSample = word:match("^Sample%l+$") or word:match("^Mock%l+$")
    if isSample and not NOT_PEOPLE[word] then found[#found + 1] = word end
  end
  return found
end

--- Split a NUL-delimited blob (`git ls-files -z`).
local function splitNul(blob)
  local out, start = {}, 1
  while true do
    local i = blob:find("\0", start, true)
    if not i then break end
    if i > start then out[#out + 1] = blob:sub(start, i - 1) end
    start = i + 1
  end
  return out
end

--- Every tracked path the gate reads.
local function scannedPaths()
  if not io.popen then
    fail("sample names gate: io.popen is unavailable, so the tracked set cannot be read and this "
      .. "gate must not be reported as passing", 2)
  end
  local pipe = io.popen("git -C '" .. ROOT .. "' ls-files -z")
  if not pipe then
    fail("sample names gate: io.popen returned no handle for `git ls-files`", 2)
  end
  local blob = pipe:read("*a") or ""
  pipe:close()
  local paths = {}
  for _, path in ipairs(splitNul(blob)) do
    local skip = BINARY[(path:match("%.(%w+)$") or ""):lower()] or false
    for _, prefix in ipairs(SKIPPED_PREFIXES) do
      if path:sub(1, #prefix) == prefix then skip = true break end
    end
    if not skip then paths[#paths + 1] = path end
  end
  if #paths == 0 then
    fail("sample names gate: `git ls-files` reported nothing to scan, so git is unavailable or "
      .. "this is not a repository; the gate cannot run", 2)
  end
  return paths
end

test("Sample names: the matcher flags a person or realm literal and passes prose", function()
  local hits = personLiterals('local who = "Samplemage-Samplerealm", pet = "Mockpaw" -- Mock fidelity')
  assertEqual(table.concat(hits, ","), "Samplemage,Samplerealm,Mockpaw")
  assertEqual(table.concat(personLiterals("Samplewarlock Sampledeathknight Mockstrider"), ","),
    "Samplewarlock,Sampledeathknight,Mockstrider", "a long name is a person too; no length cap")
  assertEqual(#personLiterals("Mock - Realm; Samples were Mocked; a Sample() call; SampleCrowd"), 0,
    "the bare words, English inflections and the library's CamelCase surfaces are not people")
end)

test("Sample names: no Sample/Mock person literal lives outside tests/, libs/ and frozen docs", function()
  local offenders = {}
  for _, path in ipairs(scannedPaths()) do
    local fh = io.open(ROOT .. "/" .. path, "r")
    if not fh then
      fail("sample names gate: git tracks " .. path .. " but it could not be opened, so the scan "
        .. "is incomplete and must not be reported as passing", 2)
    end
    local lineNo = 0
    for line in fh:lines() do
      lineNo = lineNo + 1
      for _, word in ipairs(personLiterals(line)) do
        offenders[#offenders + 1] = path .. ":" .. lineNo .. " " .. word
      end
    end
    fh:close()
  end
  assertTrue(#offenders == 0, "sample people typed outside the suite; read them from Sim.Sample or "
    .. "Sim.SampleCrowd (preview-mode, Sample characters): " .. table.concat(offenders, ", "))
end)

test("Sample names: the library publishes the surfaces a future sample would read", function()
  local Sim = mocks.LibStub("LibKa0s-Sim-1.0", true)
  assertTrue(Sim ~= nil, "LibKa0s-Sim-1.0 did not register from the vendored payload")
  assertEqual(type(Sim.Sample), "function")
  assertEqual(type(Sim.SampleCrowd), "function")
  local a = Sim.SampleCrowd("retail", 3, 7)
  local b = Sim.SampleCrowd("retail", 3, 7)
  assertEqual(#a, 3)
  for i = 1, 3 do assertEqual(a[i].name, b[i].name, "a seeded crowd is deterministic") end
end)
