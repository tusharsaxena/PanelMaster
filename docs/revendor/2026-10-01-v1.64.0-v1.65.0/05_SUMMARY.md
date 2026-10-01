# 05 — Summary: the consolidated span v1.64.0 to v1.65.0

Written 2026-10-01 by `GI-PM-RV`. A records-only back-fill: no code, library or kit file moved
because of it, and nothing was pushed. The span's previous base is v1.63.0.

## Per tag

- v1.64.0: carried by sweep, nothing adopted
- v1.65.0: `911e6ab`

`9f7ca36` and `29dc70d` carried v1.64.0 (Core minor 9's `MakeResizable`, DebugLog 15 -> 17,
DebugLogDiagnostics 2, kit 33 -> 34); the descriptor kept the library's defaults, so nothing was
adopted. `911e6ab` adopted v1.65.0's library debug lines (the Slash and Lifecycle sinks, the
console change gate and the at-enable queue) and dropped the duplicate host lines.

## Checks

- Step 3h's "vendored minus recorded" listing, run after this folder and
  `docs/revendor/2026-10-01-v1.66.0/` were written: prints nothing.
