# Automated test records

Every run of the four out-of-game suites, recorded. The normative rules are the standard's
[`automated-tests`](https://github.com/tusharsaxena/WowAddonStandards/blob/master/standards/standards/automated-tests.md)
section; this file is the local how-to.

## Running

```sh
tests/_kit/run-automated-tests.sh                            # all four, writes a bundle
tests/_kit/run-automated-tests.sh --suite complexity          # a subset
tests/_kit/run-automated-tests.sh --suite lint --suite tests --no-bundle   # the green gate; writes nothing
```

The runner is **vendored** from `LibKa0s`'s `testkit/` and is byte-identical in every Ka0s addon.
Never edit `tests/_kit/` — a kit fix goes upstream and is re-vendored, and a local patch is reverted
silently by the next re-vendor.

## What gates, and what only records

**Name the checkpoint or the answer is a half-truth.** There are two — the commit and the tag — and
`perf` and `complexity` answer differently at each.

| Suite | Command | Gates the commit? | Gates the tag? |
|---|---|---|---|
| `lint` | `luacheck .` | **yes** | **yes** |
| `tests` | `lua tests/run.lua` | **yes** | **yes** |
| `perf` | `lua tests/perf.lua` | no — recorded only | **yes** |
| `complexity` | `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` | no — recorded only | **yes** |

`perf` and `complexity` are **measured, recorded and diffed — they never fail a run and never block
a commit** (`testing-§4`). A threshold on every commit teaches everyone to reach for `--no-verify`,
after which the gate protects nothing and the habit remains. They contribute `amber`, which is a
signal rather than a stop.

**The tag is a stricter gate**: all four suites at `pass` plus **zero** functions above CCN 15
(`automated-tests-§3`, *The release gate*), evaluated by `/wow-addon:bump-version` from this run's
`manifest.json` — never by the runner, whose exit code is unchanged because the same script is the
commit gate. The manifest's `suites.<name>.gates` object describes both checkpoints; nothing reads
it, and nothing should.

**A missing tool is a skip, not a failure**, and the skip is recorded with its reason — so a green
run that measured nothing cannot be mistaken for a green run that measured everything. At the
release gate a skip is **NOT EVALUATED** rather than passed. The one exception is an addon that
ships no `tests/perf.lua`, which is this one: `perf: skip` passes the release gate and **must** be
stated in the release notes.

## What is here

- **`RESULTS.md`** — one row per run across all four suites, plus the current complexity watch list.
  **One file, overwritten in place**: the git history of that single path is the trend line.
- **`<YYYYMMDD-HHMMSS>/`** — one frozen bundle per run: `manifest.json`, one file per suite, and
  `ANALYSIS.md` (the write-up). Bundles are **never edited** once written and **never pruned**.

Offline perf records live in the bundle with the run that produced them. **In-game** captures cannot
be produced by a script — a human runs the `perf` verb in a live client and exports the record — so
they keep their own standing store at [`../perf-runs/`](../perf-runs/).
