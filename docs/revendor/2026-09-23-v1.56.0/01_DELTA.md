Delta: LibKa0s v1.55.0 -> v1.56.0

# 01 — Delta

Run: 2026-09-24, item RV-PM of the 2026-09-23 review and standards-audit remediation plan (the folder
carries the plan's date, as the item names it). Steps 0–4 of `/wow-addon:revendor-libka0s`, taken by
hand from the local `../wow-addon/commands/revendor-libka0s.md` as amended by WA-01. Adoption
(Steps 5–7) is **not** taken here: each consumer-side change this release asks for is its own
M3 plan item (PM-01, PM-08, PM-09 and the rest). Nothing was pushed. Target: this repo, branch
`feat/2026-09-23-review-audit-remediation` @ `7183100`.

Source: the sibling checkout `../LibKa0s`, **tag `v1.56.0` (tag object `4622018` → commit
`514fc0a`)**, resolved with `git -C ../LibKa0s tag --sort=-v:refname | head -1` and extracted with
`git -C ../LibKa0s archive v1.56.0 LibKa0s testkit | tar -x -C <scratch>/`, never the working tree.
The tag is local to `../LibKa0s` and not yet pushed; `tests/test_vendor_sync.lua` compares against
the tag the provenance line names, so the local tag is enough.

`git -C ../LibKa0s log --oneline v1.55.0..v1.56.0` lists 53 commits: 49 for `LK-01` through `LK-34`
(review follow-ups included), two consumer-sweep commits, the merge of the 2026-09-22 suite branch
and the 2026-09-23 review record.
`git -C ../LibKa0s diff --stat v1.55.0 v1.56.0 -- LibKa0s testkit` → 26 files, 2349 insertions,
844 deletions (15 library files, 11 kit files).

## Baseline, before anything moved

- `ka0s-bounded lua5.1 tests/run.lua` → **884 passed, 0 failed, 0 skipped, 884 total**.
- `ka0s-bounded luacheck .` → **0 warnings / 0 errors in 60 files**.

## Step 0 — Pre-flight

Newest single-tag bundle `docs/revendor/2026-09-23-v1.55.0/`: line 1 names base `v1.54.2`.
`git show b7edc9f^:CLAUDE.md | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'` → `v1.54.2`.
**ok**, so there is no base correction to carry.

## 3a — Claimed version

`grep -n '[Bb]undles' CLAUDE.md` → `CLAUDE.md:44`: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s)
**v1.55.0** (MIT).

Cross-check: `git log -1 --format=%H -- libs/LibKa0s tests/_kit` → `b7edc9f` ("Re-vendor LibKa0s
v1.55.0, and hand the cap gate to the kit"), whose provenance line names `v1.55.0`. The one
`CLAUDE.md` commit since (`ce0b705`) leaves the line alone. `diff -rq` of a `v1.55.0` extract against
both payloads → `payload-matches`. **The base is `v1.55.0`.**

## 3b — Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` before the
copy gave v1.55.0's version block exactly (the old column below), and kit revision **25**
(`tests/_kit/framework.lua:20`). The line and the bytes agreed.

## 3c — Per-file minor delta

File list read from the tag's `LibKa0s/LibKa0s.xml`, not from a table.

| File | Constant | v1.55.0 | v1.56.0 |
|---|---|---|---|
| Core.lua | MINOR | 7 | **8** |
| Env.lua | MINOR | 1 | 1 |
| Compat.lua | MINOR | 1 | 1 |
| Lifecycle.lua | MINOR | 1 | **2** |
| Bus.lua | MINOR | 1 | **2** |
| Schema.lua | MINOR | 1 | **2** |
| Pool.lua | MINOR | 3 | 3 |
| Item.lua | MINOR | 1 | **2** |
| Media.lua | MINOR | 3 | **4** |
| Widgets.lua | MINOR | 9 | **10** |
| WidgetsDragHandle.lua | DRAG_MINOR | 2 | 2 |
| DebugLog.lua | MINOR | 12 | **13** |
| Slash.lua | MINOR | 14 | **15** |
| Launcher.lua | MINOR | 1 | **2** |
| Options.lua | MINOR | 23 | **24** |
| OptionsWidgets.lua | WIDGETS_MINOR | 30 | **31** |
| OptionsTabs.lua | TABS_MINOR | 3 | **4** |
| OptionsCompose.lua | COMPOSE_MINOR | 7 | 7 |
| OptionsScroll.lua | SCROLL_MINOR | 3 | **4** |
| Perf.lua | MINOR | 12 | **13** |
| PerfPanel.lua | PANEL_MINOR | 5 | 5 |

No file is new and none is removed. **No cross-major skew**: every file moves together in one
whole-folder copy, and no `NEEDS_*` floor rises (the library's `CHANGELOG.md`, v1.56.0 entry).

## 3d — Both diffs, before the copy

`diff -rq --strip-trailing-cr` and `diff -rq` (tag extract against the vendored copy) agree exactly,
so neither payload has line-ending-only drift:

- `libs/LibKa0s/`: the 15 files whose minor moved differ; nothing is `Only in` either side, and
  `media/` is unchanged.
- `tests/_kit/`: `Only in <tag>: asserts.lua`, `mock_events.lua`, `prose_lists.lua`; `README.md`,
  `framework.lua`, `mock_base.lua`, `mock_record.lua`, `run-automated-tests.sh`, `test_eol.lua`,
  `test_layout_cap.lua`, `test_prose.lua` differ. Nothing is `Only in tests/_kit`.

Nothing was to be deleted inside either payload.

## 3e — Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'`:

| Major | Lookup site |
|---|---|
| Core | `core/CoreSetup.lua:34` |
| Env | `core/EnvSetup.lua:40` |
| Lifecycle | `core/LifecycleSetup.lua:68` |
| Media | `core/MediaSetup.lua:42` |
| DebugLog | `core/DebugLogSetup.lua:102` |
| Launcher | `core/LauncherSetup.lua:128` |
| Options (with Widgets, Tabs, Compose, Scroll) | `settings/OptionsSetup.lua:26` |
| Slash | `settings/Slash.lua:384` |
| Schema | `settings/Schema.lua:351` |

Unchanged from the v1.55.0 map apart from the Schema site, which the v1.55.0 adoption (`af8a935`)
added. Perf is named only in `core/LifecycleSetup.lua` comments; the addon wires no Perf harness
under its ratified `performance-§1` row. **Unadopted majors in the payload:** `Compat`, `Bus`
(declined/deferred as #53 and #52; #52 is now plan item PM-12), plus `Pool`, `Item`, `Widgets`,
reached only through the library itself.

## 3f — Kit revision, and the pairing rule

`grep -n 'Kit.VERSION' <tag>/testkit/framework.lua tests/_kit/framework.lua` → **25 → 26**. Both
payloads are copied whole in one commit, so the pairing rule (LibKa0s ≥ v1.9.0 takes kit ≥ 11 in the
same commit) holds by construction.

Revision 26's consumer-side flips (`CHANGELOG.md`, *What a consumer owes on re-vendoring v1.56.0*),
read against this repo:

- `CreateFrame` starts frames **shown**; the AceDB fake **raises** on a bad `CopyProfile` /
  `DeleteProfile` name and strips defaults on `SetProfile`; `EventRegistry` callbacks are
  **recorded**, and raw frame registration raises on a name in `M.__badEvents`; `test_eol.lua`
  counts every **lone CR**; the prose gate reads the three store-root files and lists `synchronis`.
  **None reddens a suite here** (the run below).
- Kit case names now carry `§` (`line-endings-§5`, `layout-§1`, `localization-§5`), so
  `docs/test-cases.md` is stale against the harness. It is regenerated by PM-DOCS, never by this
  commit, and the README `Tests` badge with it.
- The runner's `performance-§12` perf-skip reason (2) and headed empty watch-list tables affect the
  next automated-test bundle only (PM-DOCS).

## 3g — Contract delta

**Majors whose minor moved ∩ majors this addon looks up** = Core 8, Lifecycle 2, Media 4,
DebugLog 13, Slash 15, Launcher 2, Options `24.31.4.7.4` (from `23.30.3.7.3`), Schema 2. Each
walked old document → new document under `../LibKa0s/docs/api/<Major>/` at the two tags:

| Major | What moved | This addon |
|---|---|---|
| Core 8 | `printer.Format` survives a secret in a numeric slot; new `SafeRegisterEvent`, `SafeRegisterUnitEvent`, `SafeRegisterEvents` | Additive. The format fix arrives free. No Core degradation stub is pinned by surface parity here, so no parity red. Adopting the family is PM-08. |
| Lifecycle 2 | Documentation of the nested-edge (re-entrancy) behavior; bytes move, no behavior | Nothing. A Lifecycle stub parity case is PM-13. |
| Media 4 | `RegisterLSM` flags the face western + ruRU and counts what LSM holds | Arrives free; no host change (`CHANGELOG.md`: "none needs a code change"). |
| DebugLog 13 | Buffer trim batched at the cap | Arrives free. No host suite here asserts `#D.buffer` past 1500 lines. |
| Slash 15 | `CliSet` prints a `set` answering `false, reason[, why]` as a refusal; `CliReset` prints `NO_DEFAULT` when `applyDefault` answers `false` | The descriptor passes the runtime's own `NS.SchemaRuntime.Set` and `.ApplyDefault` (`settings/Slash.lua:555`, `:558`) and prints no refusal of its own, so the player now reads the seam's refusal once. Arrives free, and is **not** a blocker: it corrects the echo of an unchanged value. |
| Launcher 2 | Optional `isEnabled` / `disabledLine`; `NO_BROKER` / `NO_ICON` / `NO_MINIMAP` print once; the four `lib.STRINGS` drop their `[LibKa0s] ` prefix | Nothing here asserts the prefix; the suite stays green on it. The gate is opt-in. |
| Options 24 / Widgets 31 / Tabs 4 / Scroll 4 | `CreateOptionsPanel` parks under `InCombatLockdown()` and replays once at `PLAYER_REGEN_ENABLED`; `OpenOptionsPanel` answers a boolean; the drag throttles keep their own armed flag; the page chrome stops leaking; font preload moves to `OptionsScroll.lua`; `RenderTabbedSchema` moves to `OptionsTabs.lua` and takes an optional `opts` | `settings/Panel.lua:528` calls `O.CreateOptionsPanel()` and the host carries **no** park of its own, so the park arrives free and nothing needs deleting (the version 24.31.4.7.4 document, `:51`–`:52`: a host "**MUST NOT** add its own park on top"). `P:Open` (`settings/Panel.lua:536`) ignores `OpenOptionsPanel`'s new return. |
| Schema 2 | `SetMany`, `row.normalize`, `descriptor.writeThrough`; `Get(path, id)` now calls `row.get(id)` and `ApplyDefault(row, id)` forwards the id | Every row `get` in `settings/Schema.lua` (`:507`, `:512`, `:531`) ignores its argument, so the forwarding changes nothing on the live path. The **host degradation stub** lacks `SetMany` and so fails the two-level surface parity case (below). That is PM-01, with the stub's id forwarding and `normalize`. |

`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit`
→ no hits: the addon hands no member to an `__Attach*` entry point, so no host-supplied member's call
site can have moved.

### Blockers

**None.** No host-supplied member's contract tightened. The one red below is a stricter kit
assertion against this repo's own degradation stub, which the release names as the expected
re-vendor churn (`CHANGELOG.md`, *Surface-parity churn*: "A Schema **instance** stub gains
`SetMany` (... PanelMaster ...)").

## 3h — Tags vendored and never recorded

Not written by this item. The store's back-fill of the 27 tags vendored without a bundle
(`v1.16.0` .. `v1.54.2`) is its own plan item, PM-18, which writes the one consolidated span bundle.

## Step 4 — after the copy

Both payloads replaced whole from the extract (`rm -rf libs/LibKa0s tests/_kit`, then
`cp -r <scratch>/LibKa0s/. libs/LibKa0s/` and `cp -r <scratch>/testkit/. tests/_kit/`). Re-diffed
both payloads with and without `--strip-trailing-cr`: **all four empty**. The kit's
`run-automated-tests.sh` keeps mode `100755`. `CLAUDE.md:44` provenance line rolled
`v1.55.0` → `v1.56.0` in the same commit; there is no README provenance line. No other file moved.

Gates (all through `ka0s-bounded`):

- `lua5.1 tests/run.lua` → **883 passed, 1 failed, 0 skipped, 884 total**. `tests/test_vendor_sync.lua`
  passes. The one failure:
  `Parity: the Schema seam's degraded surface matches the live one, on both levels` —
  `schema instance vs host stub: the degraded stub diverges from the live surface in 1 place(s) — SetMany is missing (live: function)`.
  Cleared by PM-01.
- `luacheck .` → **0 warnings / 0 errors in 60 files**.
- `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .` → no function above CCN 15. The
  largest authored `.lua` file is `settings/PanelEditor.lua` at 1476 lines, under the 1500-line cap.
