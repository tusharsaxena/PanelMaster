-- tests/test_layout_cap.lua — the `layout-§1` size gate (the 1500-line cap, and the band below it).
--
-- WHAT IT PROVES. That no authored `.lua` file this repository tracks sits over `layout-§1`'s
-- 1500-line cap without a disposition, that no file has entered the 1000-1500 on-notice band
-- unremarked, and that no census row outlives the file it was written for. It reads the tracked set
-- from git and the census table from `docs/ARCHITECTURE.md`, and compares them in BOTH directions.
--
-- WHY IT EXISTS. `layout-§1` was revised this cycle to say what the cap binds — every authored file
-- the repository tracks, `tests/` included, with vendored code the only carve-out that reaches here
-- — and to name the three terminal states a file over it may be in: peeled, an open issue naming the
-- seam a peel would follow, or a ratified register row with a re-check trigger. What it refuses is
-- silence: "the count sitting in a bundle manifest that no document reads".
--
-- That sentence describes this addon exactly. The band dispositions lived in
-- `docs/automated-tests/RESULTS.md`'s watch list, which is per-run generated evidence, frozen at the
-- run that wrote it. Its row for `settings/PanelEditor.lua` reads 1091 and carries the commitment "if
-- the next change also grows it, execute the split rather than re-accept". The file is 1488 today.
-- It grew twice — 1091 -> 1350 -> 1488 — and the trigger it grew past could not fire, because the
-- only place it was written down is a document that describes a run in August and is never re-read.
--
-- WHY THIS REPO GATES THE BAND AND ITS SIBLINGS DO NOT. MultiMeters and LibKa0s carry the same gate
-- over the over-cap set alone, and record the 1000-1500 band as prose — the right call there, where
-- fifteen and two files respectively are over the cap and the band is a footnote. Here nothing is
-- over the cap at all, so an over-cap-only gate would assert nothing whatsoever today and would first
-- speak on the day the largest file crossed 1500 with no row: twelve lines away, one ordinary commit.
-- The band IS the subject in this repository, so the band is what is gated. The cost is one census
-- row the day a file crosses 1000, which is what "on notice" is supposed to mean.
--
-- WHAT IT DOES NOT ASSERT: the line figures printed in the census. They are dated measurements, and
-- pinning them would redden the suite on every ordinary edit to a large file — a gate with a standing
-- reason to be switched off stops being run. Membership is the invariant; the numbers are prose.
--
-- IT FAILS RATHER THAN PASSES WHEN IT CANNOT LOOK. No `io.popen`, no git, no ARCHITECTURE.md, no
-- census heading — every one of those is a failure, not a skip. A gate that goes quiet when it is
-- blind reports success, which is worse than not existing. Same bargain `tests/_kit/test_eol.lua`
-- strikes.

local T = _G.PM_TEST
local test, fail = T.test, T.fail

local CAP  = 1500   -- `layout-§1`: over this is a bug, and needs one of the three terminal states
local BAND = 1000   -- `layout-§1`: at or above this a file is "on notice", and needs a row

local ARCHITECTURE    = "docs/ARCHITECTURE.md"
local CENSUS_HEADING  = "### Files by the `layout-§1` band"

--- Split a NUL-delimited blob.
---
--- `git ls-files -z` because a path may contain anything but NUL, and the line-oriented form quotes
--- such a path instead of printing it — a quoted path would not match a file on disk, and this gate
--- would then report a breach that is really a parse failure.
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

--- Every authored `.lua` path git tracks, in git's order.
---
--- The tracked set rather than a directory walk: Lua 5.1 has no directory API, nothing in this
--- collection depends on LuaFileSystem, and an untracked scratch file is not something the cap has an
--- opinion about. `libs/` and `tests/_kit/` are dropped because they are the one carve-out that
--- reaches this repository — vendored code arrives by whole-folder copy and is audited where it is
--- written, so neither the cap nor the band binds a file this repo MUST NOT edit. The second
--- carve-out, generated non-shipping data, has no instance here; if one ever arrives it needs a rule
--- in this function, and a red is the prompt to write it.
local function trackedAuthoredLua()
  if not io.popen then
    fail("layoutcap: io.popen is unavailable, so the tracked set cannot be read and this gate must "
      .. "not be reported as passing")
  end
  local pipe = io.popen("git ls-files -z -- '*.lua'")
  if not pipe then fail("layoutcap: `git ls-files` returned no handle, so this gate cannot run") end
  local blob = pipe:read("*a") or ""
  pipe:close()

  local paths = {}
  for _, path in ipairs(splitNul(blob)) do
    if not (path:find("^libs/") or path:find("^tests/_kit/")) then
      paths[#paths + 1] = path
    end
  end
  if #paths == 0 then
    fail("layoutcap: `git ls-files` reported no tracked .lua files, which cannot be true here")
  end
  return paths
end

--- Lines in `path`, counted the way `wc -l` counts them plus a final unterminated line if there is
--- one. Returns nil when the file cannot be opened, which every caller reports rather than skips.
local function countLines(path)
  local fh = io.open(path, "r")
  if not fh then return nil end
  local body = fh:read("*a") or ""
  fh:close()
  if body == "" then return 0 end
  local n = 0
  for _ in body:gmatch("\n") do n = n + 1 end
  if body:sub(-1) ~= "\n" then n = n + 1 end
  return n
end

--- The census table under CENSUS_HEADING in `docs/ARCHITECTURE.md`, as { path, disposition } rows.
---
--- A row is a table line whose first cell is a single backticked path; the header row and the
--- `|---|` separator carry no backticks and fall out on their own. Reading stops at the next heading
--- of any level, so a later section growing a table of its own cannot leak into this one.
local function censusRows()
  local fh = io.open(ARCHITECTURE, "r")
  if not fh then fail("layoutcap: " .. ARCHITECTURE .. " could not be opened") end
  local body = fh:read("*a") or ""
  fh:close()

  local text = body:gsub("\r\n", "\n")
  local rows, inside, found = {}, false, false
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    if line == CENSUS_HEADING then
      inside, found = true, true
    elseif inside and line:sub(1, 1) == "#" then
      break
    elseif inside then
      local path, _, disposition = line:match("^|%s*`([^`]+)`%s*|%s*(.-)%s*|%s*(.-)%s*|%s*$")
      if path then
        rows[#rows + 1] = { path = path, disposition = disposition }
      end
    end
  end

  if not found then
    fail("layoutcap: " .. ARCHITECTURE .. " carries no '" .. CENSUS_HEADING .. "' section; that "
      .. "census is where every file at or over the band is remarked on, and it must not be removed "
      .. "or renamed while this gate names it")
  end
  return rows
end

-- ---------------------------------------------------------------------------
-- The two directions
-- ---------------------------------------------------------------------------

test("layoutcap: every authored file at or over 1000 lines is named in the ARCHITECTURE.md census",
function()
  local listed = {}
  for _, row in ipairs(censusRows()) do listed[row.path] = true end

  local unremarked = {}
  for _, path in ipairs(trackedAuthoredLua()) do
    local n = countLines(path)
    if n == nil then
      fail("layoutcap: git tracks " .. path .. " but it cannot be opened")
    elseif n >= BAND and not listed[path] then
      unremarked[#unremarked + 1] = path .. " (" .. n .. ")"
    end
  end

  if #unremarked > 0 then
    fail("layoutcap: at or over `layout-§1`'s " .. BAND .. "-line on-notice band and remarked on "
      .. "nowhere: " .. table.concat(unremarked, ", ") .. " — add a row to "
      .. ARCHITECTURE .. "'s '" .. CENSUS_HEADING .. "' census saying what is to be done about it. "
      .. "A file over the " .. CAP .. "-line cap needs one of `layout-§1`'s three terminal states "
      .. "first: peel it, open an issue naming the seam a peel would follow, or ratify a register "
      .. "row with a re-check trigger")
  end
end)

test("layoutcap: no census row outlives the file it records", function()
  local spent = {}
  for _, row in ipairs(censusRows()) do
    local n = countLines(row.path)
    if n == nil then
      spent[#spent + 1] = row.path .. " (no such file)"
    elseif n < BAND then
      spent[#spent + 1] = row.path .. " (" .. n .. ", back under the band)"
    end
  end

  if #spent > 0 then
    fail("layoutcap: " .. ARCHITECTURE .. "'s census carries rows for files that are no longer in "
      .. "the band: " .. table.concat(spent, ", ") .. " — delete the row, and close the issue or "
      .. "retire the register row that backs it. The census must not become a graveyard")
  end
end)

test("layoutcap: every file over the 1500-line cap carries a disposition that can be followed",
function()
  local unfollowable = {}
  for _, row in ipairs(censusRows()) do
    local n = countLines(row.path)
    -- The followability rule binds the BREACH rows only. A band row is a note by design — the file
    -- is compliant and the row records what is being watched — but `layout-§1`'s terminal states are
    -- not notes, so a row for a file over the cap has to name an issue number or the register above.
    if n and n > CAP
      and not (row.disposition:find("#%d") or row.disposition:find("[Rr]egister row")) then
      unfollowable[#unfollowable + 1] = row.path .. " (" .. n .. ")"
    end
  end

  if #unfollowable > 0 then
    fail("layoutcap: census rows for files over the " .. CAP .. "-line cap whose disposition names "
      .. "neither an issue nor the register row: " .. table.concat(unfollowable, ", ")
      .. " — `layout-§1` allows peeled, an open issue naming the seam, or a ratified register row, "
      .. "and a note is none of the three")
  end
end)
