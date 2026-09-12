# 05 — Summary: LibKa0s v1.33.0 → v1.34.0

**Tag moved v1.33.0 → v1.34.0 (`9165044` → `33bae81`).** Three library files moved: `Slash.lua`
(minor 9 → 10), `Options.lua` (minor 17 → 18) and `OptionsCompose.lua` (minor 4 → 5). The kit moved
revision 18 → 19. Every other file keeps its minor. The per-file table is in `01_DELTA.md`. Nothing
was deleted inside either payload.

**Reached the addon for free (class A).** The whole-value string parse, which makes the strata
adapter refuse a token followed by extra words, and the tooltip, whose text does not move. See
`02_CANDIDATES.md` for what each means here. Kit revision 19 is not reached.

**References rolled.**

- `CLAUDE.md:44`, the provenance line.

**Comments corrected.** None.

**Adopted:** the strata refusal, pinned by a test in the commit after the re-vendor.
**Adopted in follow-ups:** the enum-case fix, then `resetProfile` with `profilesPage = true` and the
AceDB fake's keyless `OnProfileReset`. **Not now:** none. **Declined:** none.
**Skipped or unreached:** none.

**Gates.**

| Point | `lua tests/run.lua` | `luacheck .` | `lizard -C 15` |
|---|---|---|---|
| Before the copy | 807 passed, 0 failed, 0 skipped, 807 total | 0 / 0 in 57 files | clean, no function above CCN 15 |
| After the copy, the roll and this bundle | 807 passed, 0 failed, 0 skipped, 807 total | 0 / 0 in 57 files | clean, no function above CCN 15 |
| After the adoption (the strata refusal test) | 808 passed, 0 failed, 0 skipped, 808 total | 0 / 0 in 57 files | clean, no function above CCN 15 |
| After the follow-up (the enum-case fix) | 809 passed, 0 failed, 0 skipped, 809 total | 0 / 0 in 57 files | clean, no function above CCN 15 |
| After the follow-up (Reset-all tooltip, AceDB fake aligned) | 812 passed, 0 failed, 0 skipped, 812 total | 0 / 0 in 57 files | clean, no function above CCN 15 |

The vendored-payload pair ran rather than skipped, against `../LibKa0s` at `v1.34.0`, and passed.
No suite total moved at the re-vendor. The adoption adds one case, confirmed red with minor 9's
`Slash.lua` swapped in (it stored `LOW`), and moves the total to 808; `docs/test-cases.md` and the
README badge move with it. Nothing was pushed, and no issue was filed.
