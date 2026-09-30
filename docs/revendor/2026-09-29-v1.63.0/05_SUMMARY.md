# Summary (PanelMaster)

LibKa0s v1.62.0 -> v1.63.0 from the tag: Slash 16 -> 17, every other file unchanged, kit revision 31
on both sides. Run on 2026-09-29 as plan item `SP-PM-02`, branch `feat/2026-09-29-smoke-and-profile`
from `master` @ `528ee29`. One commit carries both payloads, the provenance line and this record.
Nothing was pushed, and the addon version did not move.

- Blockers: none. The Slash parity case compares two tables this addon builds, so the copy alone
  left it green.
- Adopted: the Slash minor 17 profile surface only (`profiles`, `CliProfile`, `ProfileSwitch`), in
  `SP-PM-02`'s second commit (`03_DECISIONS.md`, `04_EXECUTION_PLAN.md`).
- Declined: none, and no issue filed.

Gate after the copy, all through `~/.claude/wow-addon/bin/ka0s-bounded`:

- tests: 964 passed, 0 failed, 0 skipped, 964 total (964 before)
- `docs/test-cases.md` regenerated with `lua tests/run.lua --list`: identical, 964 cases
- luacheck: 0 warnings / 0 errors in 68 files
- vendor gate: both payloads content- and byte-identical to the tag and to `../LibKa0s` at `dd7a774`
