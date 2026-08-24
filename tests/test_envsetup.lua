-- tests/test_envsetup.lua — the LibKa0s-Env-1.0 seam.
--
-- What is asserted here is THE SEAM, not the library. The library's own suite covers the ladder
-- inside GetAddOnMetadata; a second copy of those cases here is exactly the consumer-side
-- duplication testing-§8 forbids. What only this repo can check is that this addon's helpers answer
-- what its deleted shim answered, that they ask about THIS addon, and that the shim is gone.

local T = _G.PM_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- Stand a recording TOC reader up for the duration of `fn`, answering a version the addon's own
-- constant is NOT. tests/wow_mock.lua answers "1.0.0" and core/Namespace.lua:7 sets NS.version to
-- "1.0.0" as well, so against the stock fixture "read the TOC" and "fell back to the constant" are
-- the same string and neither case below could tell them apart.
local function withTOC(version, fn)
  local askedName, askedField
  local saved = mocks.C_AddOns
  mocks.C_AddOns = { GetAddOnMetadata = function(name, field)
    askedName, askedField = name, field
    return field == "Version" and version or nil
  end }
  local ok, err = pcall(fn)
  mocks.C_AddOns = saved
  if not ok then error(err, 0) end
  return askedName, askedField
end

test("EnvSetup: NS.Meta reads this addon's TOC, asking about the FOLDER name", function()
  -- The one thing a vendored library cannot get right on its own. "PanelMaster",
  -- "Ka0s Panel Master" and "[PM]" are all live strings in this repo and only the first is the
  -- folder; a wrong one reads some other addon's manifest, or none, and answers nil without raising.
  assertEqual(NS.Meta("Version"), "1.0.0")
  local name, field = withTOC("9.9.9", function()
    assertEqual(NS.Meta("Version"), "9.9.9")
  end)
  assertEqual(name, "PanelMaster")
  assertEqual(field, "Version")
end)

test("EnvSetup: NS.Version answers the TOC version, preferring it over the constant", function()
  assertEqual(NS.Version(), "1.0.0")
  withTOC("9.9.9", function()
    -- A packaged addon whose TOC can be read must never report the constant somebody forgot to edit.
    assertEqual(NS.Version(), "9.9.9")
  end)
end)

test("EnvSetup: NS.Version falls back to this addon's own constant", function()
  -- The fallback lives at the call site rather than in the library, so it is the seam's job to
  -- prove it still works. Reached by removing both readers, which is what a client that cannot
  -- answer looks like.
  local savedC, savedG = mocks.C_AddOns, mocks.GetAddOnMetadata
  mocks.C_AddOns, mocks.GetAddOnMetadata = nil, nil
  local ok, v = pcall(NS.Version)
  mocks.C_AddOns, mocks.GetAddOnMetadata = savedC, savedG
  assertTrue(ok, "NS.Version raised with no manifest reader: " .. tostring(v))
  assertEqual(v, NS.version)
  assertTrue(v ~= nil and v ~= "", "a version string, never nil — it goes straight into a banner")
end)

test("EnvSetup: the deleted shim is gone from Compat", function()
  -- A seam that leaves the old copy in place is a second answer nobody removed, and the next caller
  -- reaches for whichever one autocomplete offers first.
  assertEqual(NS.Compat.GetAddOnMetadata, nil)
end)
