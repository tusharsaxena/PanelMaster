# 05 — Summary: LibKa0s v1.29.0 → v1.30.0

## The move

| | |
|---|---|
| From | v1.29.0 |
| To | **v1.30.0** (tag `e369e0f`) |
| Files under `LibKa0s/` that moved | **none**; every LibStub minor is unchanged |
| Kit revision | **15 → 16** (`README.md`, `framework.lua`, `mock_base.lua`, `vendor_sync.lua`) |
| Files removed upstream | none |
| Cross-major skew found | none |

## What reached this addon for free

- **#27 `AceGUI:Release`.** The kit's AceGUI now takes widgets back. Nothing here calls it, so
  nothing changed, but a future page that releases a render's widgets will not need a local shim.
- **#28 the runner-mode case.** `the automated-test runner is recorded executable (100755)` is now
  part of the vendor gate and passes. It is the one case the re-vendor alone added: 783 → 784.

## What was adopted

- **#29, the event half on an Embed target.** The local `AceEvent-3.0` override in
  `tests/wow_mock.lua` now delegates its event half to the kit's and keeps only its message
  registry. One characterization case was added (784 → 785). It is in the re-vendor commit, as the
  orchestrator asked.

## What was declined

- **#30 `Printf` (and the kit's recorded event half) on the NewAddon target: not now.** The local
  `NewAddon` override in `tests/wow_mock.lua:518-548` shadows the kit's wholesale, and retiring it is
  a harness migration (`tests/test_panel.lua:60`, `tests/test_slash.lua:22-23`, the `__badEvents`
  raise, and cancellable timers). There is no live exposure, because this addon has no `NS.Printf`.
  **No issue was filed.** It went back to the orchestrator as a proposed issue, per its standing
  instruction not to file.

## Skipped or unreached

Nothing unreached. Perf remains a settled decline (#31).

## Gates

| Stage | `lua tests/run.lua` | `luacheck .` |
|---|---|---|
| Baseline, `master` @ `dd04000` | 783 passed, 0 failed, 0 skipped | 0 / 0 in 57 files |
| After the copy, line not yet rolled | 783 passed, **1 failed** (`tests/_kit is the test kit that shipped with that release`, which is the expected red), 784 total | — |
| Copy + provenance line | 784 passed, 0 failed, 0 skipped | 0 / 0 in 57 files |
| + #29 adoption and its case | **785 passed, 0 failed, 0 skipped** | **0 / 0** in 57 files |

`luacheck` excludes `libs/` and `tests/_kit/` (`.luacheckrc:12`), so 0/0 says the **host** is clean,
`tests/wow_mock.lua` and `tests/test_harness.lua` included. The payload's own gate is upstream.

## Not pushed

Committed only, on `chore/libka0s-1.30.0-arch5`. Pushing is `/wow-addon:finalize`'s job.
