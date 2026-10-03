# Summary (PanelMaster)

LibKa0s v1.67.0 -> v1.68.0 from the local annotated tag: `WidgetsDragHandle.lua` `DRAG_MINOR`
3 -> 4 (Widgets key 12.1.3 -> 12.1.4), every other file unchanged; kit revision 35 unchanged
(35 -> 35, no kit file differs). The base `v1.67.0` comes from the `CLAUDE.md` provenance line and
agrees with the last payload commit (`1c82662`) and the bytes. Run on 2026-10-02 as plan item
`TP-PM-01`, branch `feat/2026-10-02-drag-attach` from `master`. One commit carries the library file,
the `CLAUDE.md` provenance line and this record. Nothing was pushed, and the addon version did not
move.

- Span bundle: none owed (3h prints nothing). Base correction: none (Step 0 agrees).
- Delivered: WidgetsDragHandle minor 4's hook plumbing, latent here because the addon builds no
  drag handle.
- Blockers: none (`01_DELTA.md`, *Contract delta*). Widgets is not looked up by this addon.
- Adopted: nothing.
- Declined: B1, `tooltipPlace` / `place`, as not applicable. The addon has no drag strip, and unlock
  mode drags the panel frame with no tooltip (`02_CANDIDATES.md`, `03_DECISIONS.md`). No issue is
  filed, because the reason is not a gap; the Widgets major's own decline stays settled in #43.
- Skipped or unreached: none.
- Deleted from `libs/`: none (no `Only in` line).
- Live vendor stamps: only `CLAUDE.md`'s provenance line names the vendored tag. `README.md`
  carries no provenance line, so nothing was removed there.

Gate before the copy, through `~/.claude/wow-addon/bin/ka0s-bounded`: tests 1035 passed, 0 failed,
1 skipped, 1036 total.

Gate after the copy, all through `~/.claude/wow-addon/bin/ka0s-bounded`:

- tests: 1035 passed, 0 failed, 1 skipped, 1036 total, including the vendor-sync case *libs/LibKa0s
  is the LibKa0s release CLAUDE.md says this addon bundles*. No case was added, so
  `docs/test-cases.md` and the README badge (1035/1035) stay as they are
- luacheck: 0 warnings / 0 errors in 71 files (`libs/` and `tests/_kit/` are excluded by
  `.luacheckrc`, and no seam in the addon's own code changed)
- complexity, sighted (`run-automated-tests.sh --suite complexity --no-bundle`): pass, 0 warnings,
  max CCN 15, 2168 functions
- vendor parity: `diff -r` of both payloads against the tag is empty, by content and by bytes
