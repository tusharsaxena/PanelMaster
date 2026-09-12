# 04 — Execution plan

1. **Copy.** `libs/LibKa0s/` and `tests/_kit/` come whole from `git archive v1.34.0`. Afterwards both
   diffs are empty in content and in bytes.
2. **Ripple.** Roll every live reference to the bundled version:
   - `CLAUDE.md:44`, the provenance line;

   Dated records (reviews, audits, earlier revendor bundles) stay as they are. The test total does
   not move, so `docs/test-cases.md` and the README test badge do not move in this commit.
3. **Gate.** `lua tests/run.lua`, `luacheck .` and `lizard -C 15`, all green; CR == LF on every
   edited and new file.
4. **Commit.** One commit carrying both payloads, the provenance line and this bundle.
5. **Adopt, in its own commit.** Add one `tests/test_slash.lua` case.
   `set settings.defaultStrata low junk` is refused, names the path and the allowed values, and
   writes nothing. `low` alone then stores `LOW`. Confirm it red against minor 9's `Slash.lua`, then
   regenerate `docs/test-cases.md`, move the README badge and gate again.
