# LibKa0s v1.62.0 -> v1.63.0: the delta (PanelMaster)

Copied from the tag `v1.63.0` (annotated, on `dd7a774`; `git archive v1.63.0 LibKa0s testkit`),
never from a working tree. Plan item `SP-PM-02`
(`Ka0sAddonsCommonTasks/docs/2026-09-29-SMOKE_REWORK_AND_PROFILE_VERB/`, spec S3 step 1). The base is
the tag the `CLAUDE.md` provenance line named before the copy, `v1.62.0`, which is also the new tag of
this repo's newest bundle (`docs/revendor/2026-09-26-v1.62.0/`), so no tag went unrecorded and no span
bundle is owed.

## libs/LibKa0s (`diff -rq --strip-trailing-cr`, before the copy)

```
Files <tag>/LibKa0s/Slash.lua and libs/LibKa0s/Slash.lua differ
```

No `Only in libs/LibKa0s` line: nothing was removed upstream, so nothing is deleted here. The byte
diff (`diff -rq`, no `--strip-trailing-cr`) names the same one file, so no line-ending drift was
hiding under it.

| File | Constant | v1.62.0 | v1.63.0 |
|---|---|---|---|
| `Slash.lua` | `MINOR` | 16 | 17 |

Every other file is unchanged. No `NEEDS_*` floor rises and no major is added.

## tests/_kit (`diff -rq --strip-trailing-cr`, before the copy)

Empty. `Kit.VERSION` is 31 on both sides; the kit payload is copied anyway, whole, because the
pairing rule moves both payloads together in one commit.

## Consumption map

Unchanged: the same ten majors are looked up (`Core`, `Env`, `Media`, `DebugLog`, `Slash`, `Options`,
`Launcher`, `Lifecycle`, `Schema`, `Bus`), and `Perf` stays declined.

## Contract delta (blockers)

None. Slash minor 17 is additive (`docs/api/Slash/version-17-docs.md`, *Compatibility*): one optional
descriptor field (`profiles`), two instance members (`CliProfile`, `ProfileSwitch`), one lib-level
function (`ProfileNames`) and nine `PROFILE_*` strings. `lib.LIVE_VERBS` is unchanged, so the
thirteen-verb pin in `tests/test_slash.lua` stays green. A host that passes no `profiles` and ships no
`profile` row sees no change in the client.

The one gate the version 17 document says can go red on the copy alone, the kit's by-name
`T.assertSurfaceParity(<stub>, "LibKa0s-Slash-1.0", ignore)`, is not the form this repo uses for Slash:
`tests/test_surface_parity.lua` compares the live `NS.Slash` against the degraded `NS.Slash`, two
tables this addon builds itself, so the two new instance members do not reach it until the host
republishes them. The suite stayed green on the copy (964/964), as the document's 2026-09-29
measurement predicted for PanelMaster.
