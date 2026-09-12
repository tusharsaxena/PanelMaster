# 01 — Delta: LibKa0s v1.31.0 → v1.32.0

Taken **from the tag**, never from the sibling working tree:
`git -C ../LibKa0s archive v1.32.0 LibKa0s testkit | tar -x -C <scratch>/`. The tag is local in
`../LibKa0s` (annotated, object `f5f41c9`), pointing at `e18dd12` ("The v1.32.0 release record,
re-taken on the final tree"). It was never pushed. `tests/test_vendor_sync.lua` resolves the **tag**
its provenance line names, so the sibling's branch does not matter. The earlier
`docs/revendor/2026-09-12-v1.31.0/` bundle is the v1.31.0 run and is frozen; this run writes its own
folder.

This run was **non-interactive**. The orchestrator of the 2026-09-12 triage, acting on the owner's
instruction, set the adoption calls in advance (the bulk-logging rollout brief) and asked that nothing
be filed and nothing pushed.

## 3a — Claimed version, before this run

```
grep -n '[Bb]undles' CLAUDE.md
```

> 44: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) **v1.31.0** (MIT).

No `README.md` line (the same grep over `README.md` returns nothing).

## 3b — Actual version, before this run

```
grep -hoE 'local (MAJOR, )?(MINOR|WIDGETS_MINOR|SCROLL_MINOR|PANEL_MINOR) *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua
grep -n 'COMPOSE_MINOR =' libs/LibKa0s/OptionsCompose.lua
```

Core 7, DebugLog 12, Env 1, Item 1, Media 3, Options 15, Perf 11, Pool 3, Slash 7, Widgets 9,
`PANEL_MINOR` 5, `SCROLL_MINOR` 3, `WIDGETS_MINOR` 15, `COMPOSE_MINOR` 4. These are the minors the
v1.31.0 release block names, so the line and the bytes **agreed**.

## 3c — Per-file minor delta

| File | Constant | v1.31.0 | v1.32.0 |
|---|---|---|---|
| `Options.lua` | `MINOR` | 15 | **16** |
| `Slash.lua` | `MINOR` | 7 | **8** |
| every other shipped file | as 3b | unchanged | unchanged |

Both moved files are in majors this addon consumes (`settings/OptionsSetup.lua`, `settings/Slash.lua`).
After the copy there is **no cross-major skew**.

## 3d — Both diffs, both directions

```
diff -rq --strip-trailing-cr <tag>/LibKa0s libs/LibKa0s   # Options.lua, Slash.lua
diff -rq                     <tag>/LibKa0s libs/LibKa0s   # the same two
diff -rq --strip-trailing-cr <tag>/testkit tests/_kit     # nothing
diff -rq                     <tag>/testkit tests/_kit     # nothing
```

Content-dirty in exactly the two files the release changed, and nowhere else. **No `Only in` lines**:
nothing was removed upstream, so nothing inside `libs/` or `tests/_kit/` is deleted by this run. The
copy was whole anyway (`rsync -a --delete` of both folders), and `tests/_kit/run-automated-tests.sh`
stays mode `100755`. Both moved files carry CRLF with CR == LF (1114 and 652).

## 3e — Consumption map

```
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v /libs/ | grep -v /tests/
```

Unchanged since v1.31.0: Core (`core/CoreSetup.lua`), DebugLog (`core/DebugLogSetup.lua`), Env
(`core/EnvSetup.lua`), Media (`core/MediaSetup.lua`), Options (`settings/OptionsSetup.lua`), Slash
(`settings/Slash.lua`), the six `CLAUDE.md` lists as adopted. Perf is a settled decline (#31, the
`performance-§1` row). The rest are reached transitively.

## 3f — Kit revision, and the pairing rule

```
grep -n 'Kit.VERSION' <tag>/testkit/framework.lua tests/_kit/framework.lua
```

`Kit.VERSION` **17 → 17**. `testkit/` did not move at this release. Both payloads are still copied
whole in one commit with the provenance line, so the pairing rule holds by construction.

## What moved, in one paragraph

`Options.lua` minor 16 and `Slash.lua` minor 8 add one optional descriptor pair, `bulkBegin(act,
scope)` and `bulkEnd(act, scope, count, err, info)`, around `O.RestoreDefaults`,
`O.RestoreAllDefaults` and the dispatcher's `CliResetAll` (`debug-logging-§10`, standard v2.44.0,
WowAddonStandards `7883278`). `info.profileReset` is `true` only when `RestoreAllDefaults` called the
host's `resetProfile` and it returned. A host that supplies neither field runs minor 15's and minor
7's exact walks with no `pcall` on the path. Nothing is removed or renamed and no member is added
(`docs/api/Options/version-16.15.4.3-docs.md`, `docs/api/Slash/version-8-docs.md` in `../LibKa0s`).
