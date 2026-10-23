# 05 — Summary: the consolidated span v1.75.1 to v1.75.2

Written 2026-10-23 by `PM-RV`. A records-only back-fill: no code, library or kit file moved
because of it, and nothing was pushed. The span's previous base is v1.75.0.

## Per tag

- v1.75.1: carried by sweep (`e24db99`), SimPanel 3 not consumed, nothing adopted
- v1.75.2: carried by sweep (`b534579`), SimPanel 4 not consumed, nothing adopted

Both re-vendors moved only `SimPanel.lua`, a file of `LibKa0s-Sim-1.0`, which PanelMaster does not
consume. Neither tag offered an adoption candidate, so no interview or issue was owed.

## Checks

- Step 3h's "vendored minus recorded" listing, run after this folder and
  `docs/revendor/2026-10-23-v1.76.0/` were written: prints nothing.
