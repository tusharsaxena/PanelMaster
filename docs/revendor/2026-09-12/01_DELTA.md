# 01 — Delta: LibKa0s v1.29.0 → v1.30.0

Taken **from the tag**, never from the sibling working tree:
`git -C ../LibKa0s archive v1.30.0 LibKa0s testkit`. The sibling sits on branch
`fix/kit-27-30` with v1.30.0 tagged at `e369e0f` and not yet merged to `master`. That does not
matter here, because `tests/test_vendor_sync.lua` resolves the **tag** its provenance line names.

## 3a — Claimed version, before this run

```
grep -n '[Bb]undles' CLAUDE.md
```

> 44: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) **v1.29.0** (MIT).

## 3b — Actual version, before this run

```
grep -hoE 'local (MAJOR, )?(MINOR|WIDGETS_MINOR|SCROLL_MINOR|PANEL_MINOR) *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua
```

Core 7, DebugLog 12, Env 1, Item 1, Media 3, Options 15, Perf 10, Pool 3, Slash 7, Widgets 9,
`PANEL_MINOR` 5, `SCROLL_MINOR` 3, `WIDGETS_MINOR` 14 (`OptionsCompose.lua`'s `COMPOSE_MINOR` 3).
These are the minors the v1.29.0 release block names, so the line and the bytes **agreed**.

## 3c — Per-file minor delta

Read from the tag's `LibKa0s/LibKa0s.xml`: Core, Env, Pool, Item, Media, Widgets, DebugLog, Slash,
Options, OptionsWidgets, OptionsCompose, OptionsScroll, Perf, PerfPanel.

| File | v1.29.0 | v1.30.0 |
|---|---|---|
| every shipped file | as 3b | **unchanged** |

**No file under `LibKa0s/` moved**, so LibStub sees no difference between the two releases, and there
is **no cross-major skew**. The release is kit revision 16 alone.

## 3d — Both diffs, both directions

```
diff -rq --strip-trailing-cr <tag>/LibKa0s libs/LibKa0s   # empty
diff -rq                     <tag>/LibKa0s libs/LibKa0s   # empty
diff -rq --strip-trailing-cr <tag>/testkit tests/_kit     # README.md, framework.lua, mock_base.lua, vendor_sync.lua
diff -rq                     <tag>/testkit tests/_kit     # the same four
```

The kit is content-dirty in exactly the four files the release changed. **No `Only in` lines**:
nothing was removed upstream, so nothing inside `libs/` or `tests/_kit/` is deleted by this run.

## 3e — Consumption map

```
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v /libs/ | grep -v /tests/
```

Majors reached from this addon's own source: Core (`core/CoreSetup.lua:34`), DebugLog
(`core/DebugLogSetup.lua:102`), Env (`core/EnvSetup.lua:40`), Media (`core/MediaSetup.lua:42`),
Options (`settings/OptionsSetup.lua:26`), Slash (`settings/Slash.lua:344`). That matches the six
`CLAUDE.md` lists as adopted. Perf is declined on structural grounds (#31, and the
`performance-§1` row in `docs/ARCHITECTURE.md`). The rest are reached transitively.

## 3f — Kit revision, and the pairing rule

```
grep -n 'Kit.VERSION' <tag>/testkit/framework.lua tests/_kit/framework.lua
```

`Kit.VERSION` **15 → 16**. Both payloads are copied whole in the same commit. That is the pairing
rule (a consumer on v1.9.0 or newer takes kit 11 or later with it), and it is satisfied by
construction.

The runner is already recorded `100755`:
`git ls-files -s tests/_kit/run-automated-tests.sh` → `100755 f6cd8b0a… tests/_kit/run-automated-tests.sh`.
So the case kit 16's `VendorSync.register` adds passes here.
