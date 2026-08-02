# CLAUDE.md — Ka0s Panel Master

**Ka0s WoW addon.** Adheres to the **Ka0s WoW Addon Standard** —
https://github.com/tusharsaxena/WowAddonStandards

## Standards compliance (read first)

This repo is built to the **Ka0s WoW Addon Standard**
(https://github.com/tusharsaxena/WowAddonStandards). All development here — features, refactors,
doc changes — MUST conform to it. The standard is the source of truth for layout, TOC shape, the
Ace substrate, schema-driven settings, slash/prefix conventions, locales, Compat, tests/lint, and
doc structure.

**If a change would deviate from the standard, STOP and flag the deviation explicitly.** Do not
silently deviate and do not silently "fix" to match. Surface it and let the user decide which of
two things it is:

1. **An accepted deviation** — this addon intentionally differs; record it as a documented
   deviation (e.g. in the TOC/README/`docs/` and in the audit bundle), with the reason.
2. **A change to the standard itself** — the standard's definition should evolve; the update
   belongs upstream in the WowAddonStandards repo, after which this addon conforms to the new rule.

When in doubt, treat standard conformance as a hard requirement and ask.

Start here, then read the docs:

- **`docs/agent-context.md`** — the full agent brief (stack, layout, hard rules, invariants,
  the `NS` bus, working environment, response style).
- **`docs/ARCHITECTURE.md`** — module map, settings schema, message bus, slash surface, event
  wiring, taint notes, known limitations.
- **`docs/testing.md`** — how to verify: the headless harness, lint, and the green commit gate.
- Topic detail in `docs/` as needed (`smoke-tests.md`, `test-cases.md`, …).

This addon vendors **[LibKa0s](https://github.com/tusharsaxena/LibKa0s)** — the Ka0s shared library
— into `libs/LibKa0s/`, and its test kit into `tests/_kit/`. Four of the five majors are adopted
(`Core`, `DebugLog`, `Slash`, `Options`); `Perf` is declined. **Never edit anything under `libs/` or
`tests/_kit/`**: a library problem is fixed in `../LibKa0s` and re-vendored back, because the next
re-vendor silently reverts a local edit. See `docs/ARCHITECTURE.md` ▸ *The LibKa0s seams* for the
seam files and the load order they pin, and `docs/pending/LEDGER.md` for every adoption decision.

Green gate before every commit: `lua tests/run.lua` and `luacheck .` (0/0). Plus, whenever
`../LibKa0s` has moved, the **vendor gate** — neither of the other two can see a stale vendored copy;
`docs/testing.md` has the four diffs and what each answer means. Never auto-stage/commit/push and
never bump the version without an explicit instruction.
