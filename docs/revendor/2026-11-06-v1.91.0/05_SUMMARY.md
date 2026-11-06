# Summary, LibKa0s v1.90.0 -> v1.91.0 (FU-RV-PM)

- **Tag:** v1.90.0 -> v1.91.0 (commit `55bfbb4`, a **local** tag: `ls-remote` prints nothing, as this
  run expects). Base from the `CLAUDE.md:58` provenance line, confirmed by the last payload commit
  `127a500`.
- **Minors moved:** Core 16 -> 17, Widgets 25 -> 26, WidgetsLineChart 6 -> 7, SkinPaintExtras 18 -> 19.
  **New files:** CorePixel 1, WidgetsDropdown 1, SkinPaintHud 1, SkinAceConfirm 1, loaded through the
  vendored `LibKa0s.xml`. Kit 51, unchanged. No file behind, no skew, no `NEEDS_*` floor raised.
- **Step 0:** skipped and stated (the installed skill's roster regex matches nothing against
  ADDONS.md's `` `../../<Folder>/` `` entries; fixed upstream in `FU-DC1`). **Span bundle:** none (3h,
  run with a named-variable `tag_at`, found 65 vendored, 65 recorded). **Base correction:** none.
- **Delivered for free (A):** the line chart's physical-pixel lines (WidgetsLineChart 7; this addon
  draws no chart), and the four peels, which are pure moves with no member, option or behaviour change.
- **Contract blockers:** none. No moved document adds a MUST or a host clause; no suite lists library
  files by hand (they read `LibKa0s.xml` through the kit loader), none pins a moved minor, and no stub
  mirrors a moved `__` member.
- **Icons:** `LibKa0s icons:` line kept (twelve Open Iconic names). `tools/prune-icons.lua` printed
  `12 icon(s) declared; kept 13 file(s), removed 5827` against the whole copy; the shipped set is
  unchanged, so `media/icons/` has no diff and the README credits are untouched. No provenance split;
  no README provenance line.
- **Dead stub mirrors:** none.
- **CLAUDE.md:** provenance line rolled to v1.91.0; the majors sentence (`CLAUDE.md:45`) names the
  v1.91.0 payload (still twenty-one majors: the new files are secondaries).
- **Adopted:** nothing. **Declined / filed:** nothing (`00_PLAN.md` of the run decides).
- **Gate (after the prune and the CLAUDE.md edits):** `ka0s-bounded luacheck .` 0 warnings / 0 errors
  in 86 files; `ka0s-bounded lua tests/run.lua` 1194 passed, 0 failed, 1 skipped, 1195 total
  (`tests/test_vendor_sync.lua` included). Largest authored file 1167 lines (`tests/test_slash.lua`),
  under the 1500 cap. No authored Lua changed, so CCN is unchanged.
- **Smoke:** the owner's.
