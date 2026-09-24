# 05 — Summary: the consolidated span v1.16.0 to v1.54.2

Written 2026-09-24 as item PM-18 of the 2026-09-23 remediation plan (finding PanelMaster-A-15).
A records-only back-fill: no code, library or kit file moved, and nothing was pushed.

## Why one bundle, not 28

The re-vendor record lapsed collection-wide at once: this store stopped naming tags after
v1.34.0 while the addon kept vendoring through bulk sweeps and one-off re-vendors, and the
earlier gaps (v1.16.0 to v1.29.0) predate the convention settling. `audit-review-history` makes
the consolidated span bundle the sanctioned record for a lapsed span, and `AUDIT.md` asks for one
rolled-up remediation rather than a folder per tag, because a folder per tag would record
deliberation that never happened. So this folder holds `01_DELTA.md` and `05_SUMMARY.md` only.

The span's previous base is v1.15.0 (`01_DELTA.md`, "The true previous base"). With this folder in
place, the `AUDIT.md` re-vendor check's "vendored minus recorded" listing prints nothing.

## Per tag

- v1.16.0: carried by sweep, nothing adopted
- v1.18.0: `000372a`
- v1.18.1: carried by sweep, nothing adopted
- v1.19.0: carried by sweep, nothing adopted
- v1.23.0: `77d354a`
- v1.24.0: `081ee2c`
- v1.26.0: carried by sweep, nothing adopted
- v1.27.0: `8549ac5`
- v1.28.0: carried by sweep, nothing adopted
- v1.29.0: carried by sweep, nothing adopted
- v1.35.0: carried by sweep, nothing adopted
- v1.36.0: carried by sweep, nothing adopted
- v1.36.1: carried by sweep, nothing adopted
- v1.36.2: carried by sweep, nothing adopted
- v1.37.0: carried by sweep, nothing adopted
- v1.38.0: `5fa3af7`
- v1.39.0: `a3df89c`
- v1.42.0: `d5ed125`
- v1.43.0: carried by sweep, nothing adopted
- v1.44.0: carried by sweep, nothing adopted
- v1.45.0: carried by sweep, nothing adopted
- v1.46.1: carried by sweep, nothing adopted
- v1.47.0: carried by sweep, nothing adopted
- v1.50.0: carried by sweep, nothing adopted
- v1.51.0: carried by sweep, nothing adopted
- v1.52.0: carried by sweep, nothing adopted
- v1.53.0: carried by sweep, nothing adopted
- v1.54.2: `e30e329`

What each adopting commit took: `000372a` the confirmed `resetall` (options-ui-§12); `77d354a`
the tabbed settings pages (options-ui-§13) on v1.23.0's tab strip; `081ee2c` the settings-revamp-v2
contract; `8549ac5` the kit's working-tree line-ending suite; `5fa3af7` Slash minor 11's bare
`/pm`; `a3df89c` the LibKa0s-Launcher-1.0 object v1.39.0 introduced; `d5ed125`
LibKa0s-Lifecycle-1.0; `e30e329` the kit's US-English prose gate in place of this repo's own.
Several "nothing adopted" tags still touched this repo's files to keep a surface in step, and
their messages say so: `d0b6f3f` and `697d271` gave the Options degradation stub inert parity
members, `d8b9aa7` synced a test constant to the ASCII arrow, and `eaa7807` re-pointed
`DEPENDENCIES.md` line citations. None of those consumes a new surface.

## Checks

- `AUDIT.md` re-vendor check, run after this folder was written: the "vendored minus recorded"
  listing prints nothing.
- `ka0s-bounded lua5.1 tests/run.lua`: green; `docs/revendor/` is a skipped prose directory.
