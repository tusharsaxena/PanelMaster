Delta: LibKa0s v1.67.0 -> v1.68.0

# The delta (PanelMaster)

Copied from the local annotated tag `v1.68.0` (on `cc9f5eb`). The LibKa0s checkout's `HEAD` equals
`v1.68.0^{commit}` and `git -C ../LibKa0s diff --quiet v1.68.0 -- LibKa0s testkit` is clean, and the
payload was taken with `git archive v1.68.0 LibKa0s testkit`, never from a moving branch tip. Plan
item `TP-PM-01` (`Ka0sAddonsCommonTasks/docs/2026-10-02-LIBKA0S_TOOLTIP_PLACE/`). The run was
non-interactive: the owner delegated every decision, and each one is reasoned in `03_DECISIONS.md`.

## The base

```sh
grep -n '[Bb]undles' CLAUDE.md                        # :45 Bundles [LibKa0s](...) v1.67.0 (MIT).
git log -1 --format=%h -- libs/LibKa0s tests/_kit     # 1c82662 (CA-PM-RV), whose CLAUDE.md names v1.67.0
git log --format=%h 1c82662..HEAD -- CLAUDE.md        # (empty: no roll since)
git -C ../LibKa0s archive v1.67.0 LibKa0s testkit | tar -x -C <claimed>
diff -rq <claimed>/LibKa0s libs/LibKa0s && diff -rq <claimed>/testkit tests/_kit && echo payload-matches
                                                      # payload-matches
```

The line, the last payload commit and the bytes agree, so the base is `v1.67.0`.

Step 0 pre-flight for this addon: the newest bundle, `docs/revendor/2026-10-02-v1.67.0/`, states
`v1.66.0 -> v1.67.0` on line 1, and the provenance line at its commit's parent (`1c82662^`) names
`v1.66.0`. They agree, so no base correction is owed.

## Unrecorded tags (3h)

The audit's walk over `libs/LibKa0s`, `tests/_kit` and the `CLAUDE.md` rolls since the store's
horizon (`2026-08-25`), against the tags the store's bundles record, prints nothing. No span bundle
is owed.

## Range

```sh
git -C ../LibKa0s log --oneline v1.67.0..v1.68.0
```

Eight `DA-LK-*` commits (`2cc8a03` DA-LK-01 *WidgetsDragHandle minor 4 - tooltipPlace* through
`cc9f5eb` DA-LK-07R), on top of the v1.67.0 census merge. Of the 45 files `git diff --stat
v1.67.0 v1.68.0` names, one is in the ship payload (`LibKa0s/WidgetsDragHandle.lua`, +84/-) and none
is in `testkit/`; the rest are the library's own docs, tests and release records.

## Per-file minors (3b, 3c)

```sh
for f in $(git -C ../LibKa0s show v1.68.0:LibKa0s/LibKa0s.xml | grep -oE 'file="[^"]+\.lua"' | cut -d'"' -f2); do ...; done
```

| File | Constant | v1.67.0 (vendored) | v1.68.0 |
|---|---|---|---|
| `WidgetsDragHandle.lua` | `DRAG_MINOR` | 3 | 4 |

Every other file's constant is equal on both sides, and the vendored minors match the v1.67.0 tag
the line claims, so line and bytes agree. No file is added or removed in `LibKa0s.xml`, and no
`NEEDS_*` floor rises. The Widgets version key moves `12.1.3 -> 12.1.4`.

## Both diffs, before the copy (3d)

```sh
diff -rq --strip-trailing-cr <tag>/LibKa0s libs/LibKa0s   # Files .../WidgetsDragHandle.lua differ
diff -rq                     <tag>/LibKa0s libs/LibKa0s   # the same single line
diff -rq --strip-trailing-cr <tag>/testkit tests/_kit     # empty
diff -rq                     <tag>/testkit tests/_kit     # empty
```

Content and bytes name the same one file, so no line-ending drift hid under it. No `Only in` line
on either side, so nothing is deleted here.

## Kit revision (3f)

```sh
grep -n 'Kit.VERSION' <tag>/testkit/framework.lua tests/_kit/framework.lua   # 35 and 35
```

`Kit.VERSION` stays at 35 and no kit file differs. The pairing rule (LibKa0s v1.9.0 or newer
travels with kit revision 11 or newer, in the same commit) holds by construction, because both
payloads are copied whole.

## Consumption map (3e)

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -vE '^(\./)?(libs|tests)/'
```

Unchanged: ten majors are looked up, one site each (`Core`, `Env`, `Media`, `DebugLog`, `Slash`,
`Options`, `Launcher`, `Lifecycle`, `Schema`, `Bus`). `Perf`, `Widgets`, `Pool`, `Item` and `Compat`
have no lookup in the addon's own code. `Widgets` is reached only inside the payload
(`libs/LibKa0s/DebugLog.lua:33`, for `CopyWindow`), never for `DragHandle`.

## Contract delta (3g): blockers

**None.** The one major whose minor moved is `Widgets`, and this addon does not look it up, so the
intersection of 3c and 3e is empty. Read anyway for the one indirect path:

- `docs/api/Widgets/version-12.1.4-docs.md:20-46` (*What changed at 12.1.4*): `tooltipPlace`
  (spec) and `place` (tooltip descriptor) are optional and **Since 4**; "Without a hook nothing
  changes. A host that sets neither field gets minor 3's calls in minor 3's order", and "What a
  host must change: nothing." No member, `DRAG_HANDLE` field or handle method moves.
- `version-12.1.3-docs.md` is superseded only by that row ("no tooltip placement hook"), and
  `Widgets.lua` stays at minor 12, so `DebugLog`'s `CopyWindow` path is byte-identical.

```sh
grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit
                                                      # (empty: no host-supplied callback seam)
grep -rn 'DragHandle\|tooltipPlace' core modules settings   # (empty)
```

The addon builds no `lib.DragHandle`, so no host-supplied member's call site can have moved.
