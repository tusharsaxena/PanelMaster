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

- **`docs/ARCHITECTURE.md`** — what this addon is: module map, settings schema, message bus, slash
  surface, event wiring, taint notes, known limitations.
- **`docs/testing.md`** — how to verify: the headless harness, lint, and the green commit gate.
- **`DEPENDENCIES.md`** (root) — what to install to build, run, test or release this addon, split
  runtime / development / release-and-assets, with WSL2-Ubuntu commands.
- Topic detail in `docs/` — **Tier 1 is always present**: `scope.md`, `module-map.md`, `schema.md`, `settings-panel.md`, `data-flow.md`, `common-tasks.md`. Conditional and addon-specific docs vary; `docs/ARCHITECTURE.md` → `## Documentation map` lists every page under `docs/` and says which conditional ones do not apply here (`documentation-§3`).

This addon vendors **[LibKa0s](https://github.com/tusharsaxena/LibKa0s)** — the Ka0s shared library
— into `libs/LibKa0s/`, and its test kit into `tests/_kit/`. Four of the five majors are adopted
(`Core`, `DebugLog`, `Slash`, `Options`); `Perf` is declined. **Never edit anything under `libs/` or
`tests/_kit/`**: a library problem is fixed in `../LibKa0s` and re-vendored back, because the next
re-vendor silently reverts a local edit. See `docs/module-map.md` for the seam files and the load
order they pin, and this repo's GitHub issues for every adoption decision.

Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.8.1 (MIT). That line is the
**provenance line**, and it is an input rather than a note: `tests/test_vendor_sync.lua` greps this
file for it and compares both vendored payloads — `libs/LibKa0s/` and `tests/_kit/` — against that
tag in the sibling checkout. So it moves in the **same commit** as the vendored bytes; a line and a
payload that disagree is the drift the gate exists to catch. It used to live in `README.md`, which
is written for players; kit revision 9 moved it here, where the build facts already are, and there
is no fallback to the old location.

The `Perf` decline is **not ratified**. It is reasoned in [`PLAN-06`](https://github.com/tusharsaxena/PanelMaster/issues/24) and
has no row in `docs/ARCHITECTURE.md` ▸ *Documented deviations*, which is the only place an audit
looks — so `performance-§1` is a genuinely open MUST here, not a recorded deviation. The
`performance-§12` no-combat-path exemption **does not apply to this addon**: `modules/Canvas.lua:577`
runs a shared 10Hz `OnUpdate`, which fails criterion (a). `docs/performance.md` carries the sweep.

Green gate before every commit: `lua tests/run.lua` and `luacheck .` (0/0). Plus, whenever
`../LibKa0s` has moved, the **vendor gate** — neither of the other two can see a stale vendored copy;
`docs/testing.md` has the four diffs and what each answer means. Never auto-stage/commit/push and
never bump the version without an explicit instruction.

At **release** — the same change that bumps the version and rolls the README forward, before the tag
— also produce a full automated-test bundle with `tests/_kit/run-automated-tests.sh` from
the repo root, read its diff, and refresh its watch list. This is a **release** step and **not** a
commit gate: nothing about it may ever block a commit (`performance-§10`; `docs/testing.md` ▸
*Automated test records*).

## The `docs/` set — there is no `agent-context.md`

The canonical `docs/` set is exactly three files: **`ARCHITECTURE.md`** (what this addon is),
**`testing.md`** (how to verify) and **`smoke-tests.md`** (in-game checks) — plus the generated
`test-cases.md` and the topic-detail docs.

**`docs/agent-context.md` does not exist in this repo and MUST NOT be created.** The standard
deleted it in **v2.17.0**; shipping it is **anti-pattern #49**. It held `NEW_ADDON_CONTEXT.md` —
the scaffolding pack — which is fetched at runtime and never stored: a copy in the repo describes
the addon on the day it was born, forever, and because it loads as *working context* a stale copy
does not go quiet, it gets **followed** (documentation-§3). This root `CLAUDE.md` is the repo's
only agent brief.

Older audit bundles, review bundles and plans under `docs/` predate v2.17.0 and still
name the file, and some describe a four-file or a pre-v2.3.0 `agent-context.md`-based set. Those
are **frozen history** — never treat them as a live requirement, and never "restore" the file.
