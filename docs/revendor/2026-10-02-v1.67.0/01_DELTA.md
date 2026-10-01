# LibKa0s v1.66.0 -> v1.67.0: the delta (PanelMaster)

Copied from the local tag `v1.67.0` (annotated, on `0bccf4c`). The LibKa0s checkout was clean and
its `HEAD` equalled `v1.67.0^{commit}`, so the copy came from that tree, never from a moving branch
tip. Plan item `CA-PM-RV` (`Ka0sAddonsCommonTasks/docs/2026-10-02-LIBKA0S_CENSUS_ADOPTION/`). There
is no adoption interview this cycle: `02_CANDIDATES.md` names the census-adoption item that takes
each new surface.

## The base

```sh
grep -n '[Bb]undles' CLAUDE.md          # Bundles [LibKa0s](...) v1.66.0 (MIT).
git log -1 --format=%h -- libs/LibKa0s tests/_kit   # 406aa2c (GI-PM-RV), whose CLAUDE.md names v1.66.0
```

The two agree, and the newest bundle (`docs/revendor/2026-10-01-v1.66.0/`) records that tag, so the
base is `v1.66.0` and no span bundle is owed.

## libs/LibKa0s (`diff -rq --strip-trailing-cr`, before the copy)

```
Files <tag>/LibKa0s/Core.lua and libs/LibKa0s/Core.lua differ
Files <tag>/LibKa0s/Options.lua and libs/LibKa0s/Options.lua differ
Files <tag>/LibKa0s/OptionsIdList.lua and libs/LibKa0s/OptionsIdList.lua differ
```

No `Only in` line on either side: nothing was added or removed upstream, so nothing is deleted
here and the payload stays at 32 files. The byte diff names the same three files, so no
line-ending drift hid under it.

| File | Constant | v1.66.0 | v1.67.0 |
|---|---|---|---|
| `Core.lua` | `MINOR` | 9 | 10 |
| `Options.lua` | `MINOR` | 27 | 28 |
| `OptionsIdList.lua` | `IDLIST_MINOR` | 2 | 3 |

Every other file is unchanged. No `NEEDS_*` floor rises, no major is added and no member moves.
The Options key moves 27.2.34.2.2.8.1.7.4.2 -> 28.2.34.2.3.8.1.7.4.2.

## tests/_kit (`diff -rq --strip-trailing-cr`, before the copy)

Empty. `Kit.VERSION` stays at 35, so the kit payload is unchanged and no suite is wired or
unwired. The pairing rule holds: both payloads are at `v1.67.0` after this commit.

## Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' core modules settings
```

Unchanged: ten majors are looked up (`Core`, `Env`, `Media`, `DebugLog`, `Slash`, `Options`,
`Launcher`, `Lifecycle`, `Schema`, `Bus`). `Perf`, `Widgets`, `Pool`, `Item` and `Compat` have no
lookup; `Perf` stays declined (ratified, `docs/ARCHITECTURE.md` > *Documented deviations*).

## Contract delta (blockers)

None. Read against the two consumed majors whose minor moved:

- **Core 10** (`docs/api/Core/version-10-docs.md`, *The resize grip*): `MakeResizable` gains three
  optional opts, `canResize`, `onResizeStop` and `gripParent`. A caller passing none behaves as on
  v1.66.0, and no member is added. This addon makes no `MakeResizable` call (`grep -rn
  MakeResizable core modules settings` is empty), so nothing it does changes.
- **Options 28 / OptionsIdList 3** (`docs/api/Options/version-28.2.34.2.3.8.1.7.4.2-docs.md`): the
  `O.IdList` help-art ladder accepts the descriptor's `addonName` only when the client reports
  that addon loaded, and writes one `Cfg` line per instance when it falls past that rung. This
  addon builds no `O.IdList` (`grep -rn IdList core modules settings` is empty), so no help mark is
  drawn and no line is written. Options 28 itself is a docblock correction. The degraded stub in
  `settings/OptionsSetup.lua` keeps the same members.

No consumer test broke: the suite went 1032 / 0 / 1 / 1033 before the copy and after it, once the
provenance line had rolled. Between the copy and the roll the kit's provenance case (`tests/_kit/vendor_sync.lua`,
*libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles*) failed, as it should.

## Complexity (kit 35, sighted)

`run-automated-tests.sh --suite complexity --no-bundle`: pass, 0 warnings, max CCN 15, 2161
functions.
