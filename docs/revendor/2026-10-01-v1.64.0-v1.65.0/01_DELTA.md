Delta: LibKa0s v1.64.0 -> v1.65.0 (span: v1.64.0 v1.65.0)

# 01 — Delta: the consolidated span v1.64.0 to v1.65.0

Written 2026-10-01 by plan item `GI-PM-RV` (`Ka0sAddonsCommonTasks/docs/2026-10-01-GITHUB_ISSUE_PASS/`),
beside `docs/revendor/2026-10-01-v1.66.0/`. Two tags this addon vendored on 2026-09-30 and 2026-10-01
have no bundle naming them. This is a back-fill record in the consolidated span shape, not a re-run
of the re-vendor procedure: nothing here was copied.

The tag vendored immediately before the span is v1.63.0 (`ada4eee`), recorded by
`docs/revendor/2026-09-29-v1.63.0/`.

## The two listings

`/wow-addon:revendor-libka0s` Step 3h, run before this bundle existed:

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

- Vendored: 45 tags. Recorded: 43.
- Vendored minus recorded: `v1.64.0`, `v1.65.0`, the tags on line 1.

## The vendoring commits

| Tag | Vendoring commit | Date |
|---|---|---|
| v1.64.0 | `9f7ca36` (re-cut of the same tag in `29dc70d`) | 2026-09-30 |
| v1.65.0 | `a0d81a9` | 2026-10-01 |

Each tag is read off the `Bundles [LibKa0s](…) vX.Y.Z` provenance line in root `CLAUDE.md` at that
commit. Each commit's own message is the record of what that re-vendor moved; the earlier frozen
bundles are not edited.
