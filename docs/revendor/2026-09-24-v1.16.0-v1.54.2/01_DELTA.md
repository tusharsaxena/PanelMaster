Delta: LibKa0s v1.16.0 -> v1.54.2 (span: v1.16.0 v1.18.0 v1.18.1 v1.19.0 v1.23.0 v1.24.0 v1.26.0 v1.27.0 v1.28.0 v1.29.0 v1.35.0 v1.36.0 v1.36.1 v1.36.2 v1.37.0 v1.38.0 v1.39.0 v1.42.0 v1.43.0 v1.44.0 v1.45.0 v1.46.1 v1.47.0 v1.50.0 v1.51.0 v1.52.0 v1.53.0 v1.54.2)

# 01 — Delta: the consolidated span v1.16.0 to v1.54.2

Written 2026-09-24 as item PM-18 of the 2026-09-23 review and standards-audit remediation plan,
branch `feat/2026-09-23-review-audit-remediation`. It resolves finding PanelMaster-A-15: 28
LibKa0s tags this addon vendored between 2026-08-25 and 2026-09-22 have no bundle naming them.
This is a back-fill record in the consolidated span shape `audit-review-history` defines, not a
re-run of the re-vendor procedure. Nothing was copied, and `libs/LibKa0s/` and `tests/_kit/` did
not move.

## The true previous base

The tag vendored immediately before the span is **v1.15.0** (`b7b744c`, 2026-08-25), recorded by
the bare-dated bundle `docs/revendor/2026-08-25/`. Line 1 names the span's first tag, v1.16.0,
because the span grammar fixes it that way: it is the span, not a base-and-new pair.

The span is not contiguous with the rest of the store. Seven tags inside its range already have a
bundle and are left off line 1: v1.25.0 (`2026-09-03/`), v1.30.0 (`2026-09-12/`), v1.31.0,
v1.32.0, v1.33.0, v1.34.0 (their own single-tag folders) and v1.55.0 (`2026-09-23-v1.55.0/`,
whose base is v1.54.2). The thirteen library tags in the range this addon never vendored
(v1.17.0, v1.20.0, v1.21.0, v1.22.0, v1.40.0, v1.41.0, v1.46.0, v1.48.0, v1.48.1, v1.49.0,
v1.49.1, v1.54.0, v1.54.1) do not belong on the line either: the addon never carried them.

## The two listings

The `AUDIT.md` re-vendor check (WowAddonStandards v2.65.0), with the provenance-roll walk that
`/wow-addon:revendor-libka0s` Step 3h adds, run before this bundle existed:

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)   # 2026-08-25

tag_at() {
  git show "$1:CLAUDE.md" 2>/dev/null |
    grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+' |
    grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1
}
{ git log --since="$horizon 00:00" --format=%H -- libs/LibKa0s tests/_kit
  git log --since="$horizon 00:00" --format=%H -- CLAUDE.md | while read -r c; do
    [ "$(tag_at "$c")" != "$(tag_at "$c^")" ] && echo "$c"
  done
} | while read -r c; do tag_at "$c"; done | sed '/^$/d' | sort -uV > vendored.txt

for b in docs/revendor/*/; do
  n=$(basename "$b" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | wc -l)
  if [ "$n" -ge 2 ]; then
    head -1 "$b/01_DELTA.md" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+'
  else
    t=$(basename "$b" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    [ -n "$t" ] || t=$(head -1 "$b/01_DELTA.md" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | tail -1)
    [ -n "$t" ] && echo "$t"
  fi
done | sort -uV > recorded.txt

grep -vxF -f recorded.txt vendored.txt
```

- Vendored (37): v1.15.0, v1.16.0, v1.18.0, v1.18.1, v1.19.0, v1.23.0, v1.24.0, v1.25.0, v1.26.0,
  v1.27.0, v1.28.0, v1.29.0, v1.30.0, v1.31.0, v1.32.0, v1.33.0, v1.34.0, v1.35.0, v1.36.0,
  v1.36.1, v1.36.2, v1.37.0, v1.38.0, v1.39.0, v1.42.0, v1.43.0, v1.44.0, v1.45.0, v1.46.1,
  v1.47.0, v1.50.0, v1.51.0, v1.52.0, v1.53.0, v1.54.2, v1.55.0, v1.56.0.
- Recorded before this bundle (9): v1.15.0, v1.25.0, v1.30.0, v1.31.0, v1.32.0, v1.33.0, v1.34.0, v1.55.0, v1.56.0
  (v1.31.0 was vendored twice, `e0ec23b` and `8711c99`, and has one bundle).
- Vendored minus recorded (28): the tags on line 1. The walk over the payload folders alone and
  the walk with the provenance rolls added give the same 28; no tag here arrived as a roll alone.

## The vendoring commits

| Tag | Vendoring commit | Date |
|---|---|---|
| v1.16.0 | `eddcf3d` | 2026-08-25 |
| v1.18.0 | `000372a` | 2026-08-26 |
| v1.18.1 | `e7f1b12` | 2026-08-26 |
| v1.19.0 | `a6be219` | 2026-08-27 |
| v1.23.0 | `0221287` | 2026-09-01 |
| v1.24.0 | `081ee2c` | 2026-09-02 |
| v1.26.0 | `f58e235` | 2026-09-08 |
| v1.27.0 | `8549ac5` | 2026-09-08 |
| v1.28.0 | `b398bc9` | 2026-09-09 |
| v1.29.0 | `afaa291` | 2026-09-09 |
| v1.35.0 | `d0b6f3f` | 2026-09-14 |
| v1.36.0 | `697d271` | 2026-09-15 |
| v1.36.1 | `8fcd06b` | 2026-09-15 |
| v1.36.2 | `d8b9aa7` | 2026-09-15 |
| v1.37.0 | `274c4b4` | 2026-09-16 |
| v1.38.0 | `5fa3af7` | 2026-09-16 |
| v1.39.0 | `dd600fe` | 2026-09-16 |
| v1.42.0 | `d5ed125` | 2026-09-17 |
| v1.43.0 | `eaa7807` | 2026-09-17 |
| v1.44.0 | `82a7f80` | 2026-09-19 |
| v1.45.0 | `47dd305` | 2026-09-19 |
| v1.46.1 | `11e3d56` | 2026-09-19 |
| v1.47.0 | `cdc13ff` | 2026-09-20 |
| v1.50.0 | `10e6610` | 2026-09-21 |
| v1.51.0 | `c8d924f` | 2026-09-22 |
| v1.52.0 | `9e024d5` | 2026-09-22 |
| v1.53.0 | `f2b08e2` | 2026-09-22 |
| v1.54.2 | `e30e329` | 2026-09-22 |

Each tag is read off the `Bundles [LibKa0s](…) vX.Y.Z` provenance line in root `CLAUDE.md` at
that commit. `e30e329` carried v1.54.2 through `tests/_kit/` and `CLAUDE.md` alone: kit revision
24 changed no library file, so `libs/LibKa0s/` is byte-identical to v1.53.0 there.

Each commit's own message is the record of what that re-vendor moved and adopted; this bundle
does not restate the per-file minors, which were never captured at the time. The earlier frozen
bundles are not edited: this folder adds the missing record beside them.
