# 02 — Candidates

Sources: `git -C ../LibKa0s log --oneline v1.58.0..v1.60.0`, the `CHANGELOG.md` blocks for v1.59.0 and
v1.60.0 at the tag, and the `Since` markers in `docs/api/DebugLog/version-14.1-docs.md`,
`docs/api/Slash/version-16-docs.md` and `docs/api/Widgets/version-10.3-docs.md`. The re-pins and stub
members `01_DELTA.md` 3g lists were owed by the copy and are not candidates.

## A. Reached the addon on the re-vendor alone (delivered)

- **The console keeps 3000 lines** (DebugLog 14: `lib.MAX_BUFFER` 1500 → 3000, `lib.BUFFER_SLACK`
  64 → 128; `version-14.1-docs.md:50-54`). The message frame and the copy window read the same
  constant, so `/pm debug` keeps twice the trace with no host change.
- **`lib.TIME_COPY`** (DebugLog 14), a by-hand copy-timing switch, off at load. Available to anyone
  who types the `/run` line; nothing in this addon reads it.
- **`diagnostics` is live while disabled** on the library arm (Slash 16, `lib.LIVE_VERBS`). This
  addon passes no `liveVerbs`, so the gate already exempts the verb. No `diagnostics` verb is
  registered yet, so today it falls through to `unknown command` as before.

## B. Host change required

| # | Candidate | Evidence | Would touch | Blast radius | Recommendation |
|---|---|---|---|---|---|
| B1 | **The diagnostics report**: `D:RunDiagnostics` / `D:BuildDiagnostics` / `D:DebugVerb`, the `brandName` and `diagnostics` descriptor fields, both slash forms (`/pm debug diagnostics`, `/pm diagnostics`), and `Kit.diagnostics` for the kit's `test_diagnostics_contract.lua` | `version-14.1-docs.md:56-126`, `:525-526`; CHANGELOG v1.60.0 *DebugLogDiagnostics minor 1* and *Test kit revision 27* | `core/DebugLogSetup.lua`, a new `modules/Diagnostics.lua`, `settings/Slash.lua`, `tests/run.lua`, tests | **Replaces** host code: `/pm debug dump` and `D:Diagnose` retire, because they are this report under another name | **Adopt**, in DR-PM-03 (see `03_DECISIONS.md`). `debug-logging-§14` (standard v2.68.0) makes it a MUST. |

`WidgetsDragHandle` minor 3's `spec.onClose` (v1.59.0) is **not a candidate**: this addon builds no
drag strip (`grep -rn DragHandle core settings modules` is empty).

## C. Whole-module adoption

No major moved a minor in this range that this addon does not consume, apart from Widgets'
`WidgetsDragHandle.lua` above. The standing position is unchanged: `Perf` is declined and ratified
(`docs/ARCHITECTURE.md` ▸ *Documented deviations*, `performance-§1`), and nothing in v1.59.0 or
v1.60.0 touches `Perf.lua` or `PerfPanel.lua`, so no premise moved. Not re-offered.
