# 01 — Delta: LibKa0s v1.30.0 → v1.31.0

Taken **from the tag**, never from the sibling working tree:
`git -C ../LibKa0s archive v1.31.0 LibKa0s testkit | tar -x -C <scratch>/`. The tag is local in
`../LibKa0s` at `7cb70a0` (annotated), pointing at `30db4ed` ("The v1.31.0 release record").
`tests/test_vendor_sync.lua` resolves the **tag** its provenance line names, so the sibling's branch
does not matter. The earlier `docs/revendor/2026-09-12/` bundle is the v1.30.0 run and is frozen;
this run writes its own folder.

## 3a — Claimed version, before this run

```
grep -n '[Bb]undles' CLAUDE.md
```

> 44: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) **v1.30.0** (MIT).

No `README.md` line (the same grep over `README.md` returns nothing).

## 3b — Actual version, before this run

```
grep -hoE 'local (MAJOR, )?(MINOR|WIDGETS_MINOR|SCROLL_MINOR|PANEL_MINOR) *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua
grep -n 'COMPOSE_MINOR =' libs/LibKa0s/OptionsCompose.lua
```

Core 7, DebugLog 12, Env 1, Item 1, Media 3, Options 15, Perf 10, Pool 3, Slash 7, Widgets 9,
`PANEL_MINOR` 5, `SCROLL_MINOR` 3, `WIDGETS_MINOR` 14, `COMPOSE_MINOR` 3. These are the minors the
v1.30.0 release block names, so the line and the bytes **agreed**.

## 3c — Per-file minor delta

File list read from the tag's `LibKa0s/LibKa0s.xml`: Core, Env, Pool, Item, Media, Widgets,
DebugLog, Slash, Options, OptionsWidgets, OptionsCompose, OptionsScroll, Perf, PerfPanel.

| File | Constant | v1.30.0 | v1.31.0 |
|---|---|---|---|
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 14 | **15** |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 3 | **4** |
| every other shipped file | as 3b | unchanged | unchanged |

This addon is **behind on two files before the copy**, both in the `Options` major it consumes. That
is the ordinary before-state of a re-vendor, not skew inside the payload: the vendored copy is the
whole v1.30.0 folder, internally consistent. After the copy there is **no cross-major skew**.

## 3d — Both diffs, both directions

```
diff -rq --strip-trailing-cr <tag>/LibKa0s libs/LibKa0s   # OptionsCompose.lua, OptionsWidgets.lua
diff -rq                     <tag>/LibKa0s libs/LibKa0s   # the same two
diff -rq --strip-trailing-cr <tag>/testkit tests/_kit     # README.md, framework.lua, mock_base.lua
diff -rq                     <tag>/testkit tests/_kit     # the same three
```

Content-dirty in exactly the files the release changed, and nowhere else. **No `Only in` lines**:
nothing was removed upstream, so nothing inside `libs/` or `tests/_kit/` is deleted by this run.

## 3e — Consumption map

```
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v /libs/ | grep -v /tests/
```

Unchanged since v1.30.0: Core (`core/CoreSetup.lua`), DebugLog (`core/DebugLogSetup.lua`), Env
(`core/EnvSetup.lua`), Media (`core/MediaSetup.lua`), Options (`settings/OptionsSetup.lua`), Slash
(`settings/Slash.lua`) — the six `CLAUDE.md` lists as adopted. Perf is a settled decline (#31, the
`performance-§1` row). The rest are reached transitively.

## 3f — Kit revision, and the pairing rule

```
grep -n 'Kit.VERSION' <tag>/testkit/framework.lua tests/_kit/framework.lua
```

`Kit.VERSION` **16 → 17**. Both payloads are copied whole in one commit with the provenance line, so
the pairing rule (a consumer on v1.9.0 or newer takes kit 11 or later with it) holds by construction.

## Addendum: the tag was re-taken during this run

```
git -C ../LibKa0s rev-parse v1.31.0^{commit}   # e7e1962 now; 30db4ed when 3a-3f were taken
git -C ../LibKa0s log --oneline 30db4ed..v1.31.0
```

At 15:18 the library re-took `v1.31.0` on its review-fixed tree (`bab743c` Perf minor 11, `1f1790c`
the review, `e7e1962` the release record). Against the first copy, five files differ:
`Perf.lua` (**MINOR 10 → 11**), `OptionsCompose.lua` and `OptionsWidgets.lua` (changed **inside**
minors 4 and 15, which did not move), `testkit/mock_base.lua` and `testkit/README.md` (changed inside
kit revision 17). This addon's own vendor gate caught it: `test_vendor_sync` went red on the stale
bytes after the #50 commit. `05_SUMMARY.md` records the second copy.
