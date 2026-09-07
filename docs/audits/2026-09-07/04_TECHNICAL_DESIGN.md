# 04 — Technical design (2026-09-07)

Remediation design for the eight root deviations in `02_DEVIATIONS.md` and the one dependent.
Every section names its deviation ID, the files it touches, the shape of the change, the risk and
the ordering constraint.

---

## PM-023 — move the Panels page's page-wide acts into the chrome band

**Files:** `settings/PanelEditor.lua` (only). Doc follow-on in `docs/settings-panel.md` (PM-023a).

### Shape

The band already exists and is already correct in every other respect — one block, unboxed, built
once from `BuildPage` and refreshed in place. The change is to widen what it holds.

Today `drawPageHeader` (`settings/PanelEditor.lua:1112`) builds a one-line Flow block containing
the create box (`:1141`) and the picker (`:1154`), sized to `H.BANNER_H` (`:1119`). It becomes a
**two-line** block:

```
  [ Create new panel        ]  [ Panel: <picker>      ]
  [Enabled] [Unlock] [Copy settings from…] [Reset] [Delete]
```

- Row 1 is unchanged: create box + picker, half-width each.
- Row 2 takes the five whole-panel acts. `Enabled` and `Unlock` stay checkboxes; `Copy settings
  from panel` stays a valueless action dropdown; `Reset` and `Delete` stay a `makePairButton` pair.
- The block's declared `height` moves from `H.BANNER_H` to `H.BANNER_H` plus one control row.
  Read the row height from the library (`H.ROW_VSPACER`, the control's own `SetHeight`), never a
  literal — `options-ui-§8` requires the number be read, not restated, and the stub answers `0` for
  all three chrome constants precisely so a caller cannot lay out against invented geometry.
- **`Panel name` (rename) stays where the design puts it, but it must be decided rather than
  defaulted.** §14 names *create*, *pick*, *enable*, *unlock*, *copy*, *reset*, *delete*. Rename is
  identity, not an act — the safest reading is that it belongs beside the picker in row 1, because
  the picker names the instance and the rename box changes that name. Recommend moving it, and
  record the choice in `docs/settings-panel.md` either way.

`sections[TAB_GENERAL]` (`:565-677`) then loses all six controls. What remains for that tab is
nothing — which is the real design question below.

### The tab that empties, and why this is not a strip regression

Removing six controls from `General` leaves it with no rows. A tab with no content is not an option:
`options-ui-§13` requires one tab per section and a section is content. Two viable answers:

1. **Drop the `General` tab and re-key the default to `Position and size`.** The tab list at
   `:164-174` loses `TAB_GENERAL`, `sections[TAB_GENERAL]` is deleted, and the fallback at `:1058`
   (`sections[ctx.activeTab] or sections[TAB_GENERAL]`) re-points at `TAB_POSITION`. Five tabs
   remain, all with real content. **This is the recommended answer** — it is the honest structural
   consequence of the move, and it shortens a six-tab strip that is the one at risk of wrapping.
2. Keep `General` and give it content that genuinely is general-and-not-act (strata, level). Both
   currently live on `Position and size`; moving them creates a thin tab and a second edit for no
   reader benefit.

Take (1).

### Refresh and lifecycle

The band is **not** released by a rebuild (`:1106-1111`, and the create box is the reason). The five
moved controls therefore cannot rely on the rebuild path:

- `Enabled` needs the in-place refresher it already has (`:643`) re-registered against the band's
  widget rather than the tab's.
- `Unlock` has, and must keep, **no** refresher — per-panel unlock is session state in
  `NS.State.unlockedPanels` and no `MSG_PANEL` describes it (`:661-662`).
- `Copy settings from panel` rebuilds its list from `panelsByName()` on every render; in the band it
  must instead be refreshed with `SetList` / `SetValue(nil)` on `MSG_PANELS`, the same path
  `ctx.__pmPicker` already takes.
- `Reset` and `Delete` are stateless buttons and need nothing.
- The selection-change path must **not** release the band. `ForgetSelection` and the picker's
  `OnValueChanged` already refresh in place; the five new controls join that fan-out.

### Risk

Medium-low, and all of it is layout. The band grows by one row on a page whose content panel is
positioned from the band's declared height, so a wrong height pushes the scroll into or off the
divider. Mitigate by reading the height from the library and by adding a case that asserts the
declared band height equals the sum of the two rows' measured heights.

**New tests required** (all in `tests/test_panel.lua`):

- the band holds exactly the seven page-wide controls, by label, after `BuildPage`;
- `sections[TAB_GENERAL]` no longer exists and the tab list is the five remaining tabs in order;
- switching the active tab does not release or re-create the band's widgets (identity, not count —
  the pattern `:973` already uses);
- `Delete` and `Reset` are reachable with `Artwork` active.

### Ordering

Independent of every other item. Land it first among the code changes, because PM-023a and the next
automated-test run both depend on it.

---

## PM-023a — `docs/settings-panel.md` follows the code

**Files:** `docs/settings-panel.md` (`:247`, `:257-261`), `docs/ARCHITECTURE.md` if the Panels page's
tab list is quoted there, `README.md:127` (the `| Page | Covers |` row names six tabs).

`docs/settings-panel.md:257-261` currently argues the placement being removed. Rewrite it to state
the `options-ui-§14` rule and what the band holds, and delete the justification for the old shape
rather than leaving it as history — a doc that argues for the code's previous state reads as a
disagreement with the standard. **Same commit as PM-023.** `documentation-§5`.

---

## PM-024 — the composed border and bar groups

**Files:** upstream `../LibKa0s/LibKa0s/OptionsCompose.lua` first; then
`settings/PanelEditor.lua:738-757`, `:770-800`, `:814-830` here.

### Why this cannot be fixed addon-side

`O.BorderGroup` / `O.BarGroup` (`libs/LibKa0s/OptionsCompose.lua:262`, `:297`) emit **schema rows** —
`{ type, label, tooltip, dialogControl, min, max, step, default }` keyed by a dotted `path` and
rendered by the flow engine. This page has no paths: it draws AceGUI widgets straight onto a
registry record (`settings/PanelEditor.lua:148-149`). Copying the composer's row data into this
file to "compose" it here would be the exact anti-pattern #47 the composer exists to end.

### Upstream shape

Give each composer an alternative binding. The row's `path` is only ever used to call the host's
`get`/`set`; so let a spec supply the pair directly:

```lua
-- today (schema-backed):     emit(spec, rows, "borderSize", { … })  -> row.path = spec.prefix.."borderSize"
-- proposed (record-backed):  spec.bind = function(key) return getter, setter end
```

A consumer with a record editor passes `bind`; a consumer with a schema passes `prefix` as now.
The row **data** — the set, the order, the labels, the ranges, the defaults — stays in one place,
which is the whole point. This is additive within the major (`library-stack-§7`: *"MUST keep a
module's descriptor / API contract additive-only within a major"*), so it costs consumers nothing
and needs a minor bump on `OptionsCompose.lua` plus a re-vendor here.

### Addon-side, after the re-vendor

Replace the three hand-written blocks with three composer calls, each taking `extra` for this
addon's own appended rows (`Border offset`; `Bar thickness` + `Bar offset`) and `show = false`
(the panel's border has no separate *Show border* toggle — thickness `0` removes it, per the
tooltip at `:746`).

### Risk

Low addon-side, moderate upstream: the composers are consumed by every addon in the collection, so
the change must be strictly additive and covered by a LibKa0s-side case that the schema-backed arm
is byte-identical before and after.

### Ordering

Upstream work. Until it lands, **write the register row** (see PM-029's design, same mechanism) so
the state is ratified rather than re-filed every cycle.

---

## PM-025 — `.pkgmeta` ignore list

**Files:** `.pkgmeta` (`:5-12`).

Three added rows and one comment, in the canonical order the standard's template uses:

```yaml
ignore:
  - .luacheckrc
  - .gitignore
  - .gitattributes   # dev-only: the repo's line-ending policy (line-endings)
  - .claude          # dev-only: agent tooling; never loaded by the client
  - .superpowers     # dev-only: agent tooling; never loaded by the client
  - docs        # holds docs/audits/ and docs/reviews/ too — all dev-only
  …
```

plus, beside `package-as:`, a one-line comment recording that `.pkgmeta` itself is the packager's
own input and is never part of the payload — which is what the strong-form check asks for and what
stops the next audit re-filing it.

`.claude` and `.superpowers` are listed although neither exists here: the enumeration is what
catches the directory the day a tool writes it, and the standard names them explicitly after five
addons shipped one.

**Risk:** none. Config only, no runtime path. **Ordering:** independent.

---

## PM-026 — renormalize the working tree

**Files:** none edited by hand.

```sh
git add --renormalize .
git status          # review
git commit
```

`--renormalize` rewrites the **index**, not the working tree. For each path still reported by the
`03_EVIDENCE.md` §5 command afterwards:

```sh
rm <path> && git checkout -- <path>
```

then re-run the count and expect `0`.

**Risk:** the diff is whitespace-only and enormous in line count. Do it as its **own commit**, on a
clean tree, with no other change riding along, so a future `git blame` is not destroyed for a
feature change. Two of the five files are frozen bundle pages under `docs/revendor/2026-08-25/`;
renormalizing them changes bytes in a frozen directory. That is acceptable — the freeze is on
*content*, and a line-ending correction is not content — but say so in the commit message.

**Ordering:** last, after every other file edit in this plan, so nothing lands on top of the
renormalization and re-introduces a straggler.

---

## PM-027 — refresh the automated-test record

**Files:** a new `docs/automated-tests/<stamp>/` bundle (generated, never hand-written) and
`docs/automated-tests/RESULTS.md`.

```sh
tests/_kit/run-automated-tests.sh
```

from the repo root. The runner writes the bundle and prepends the `RESULTS.md` row. Then, by hand,
the parts the runner does not generate:

1. Re-anchor the watch-list prose: `RESULTS.md:102` — *"Current state as of `20260807-114409`"* —
   becomes the new run.
2. Correct the stale `file:line` references in the prose: `:123-124` and `:174-175` name
   `core/Compat.lua:34` and `modules/Registry.lua:604-632` / `:639`; today the functions are at
   `core/Compat.lua:27` and `modules/Registry.lua:658`.
3. Add `tests/test_panel.lua` (1076) and `tests/test_libka0s.lua` (1064) to the
   `### Files by layout-§1 band` table with a real disposition each.
4. Resolve `settings/PanelEditor.lua`. Its own recorded condition fired: **execute the split, or
   write a new argued disposition.** After PM-023 lands the file will be shorter, so re-measure
   before deciding. The natural seam if a split is taken is `drawPageHeader` + the list/selection
   machinery (`:1060-1350`) versus the six `sections[…]` builders (`:565-1055`).
5. Delete the duplicated `### Functions lizard warned on` heading — the file carries it twice
   (`:106` and `:170`), which is a formatting defect in a generated-and-annotated document.

**Risk:** none to the addon. The risk is procedural — a run recorded against a dirty tree is not
evidence. Run it on a clean tree.

**Ordering:** **after** PM-023, PM-024's addon-side arm and PM-025, so the recorded numbers describe
the remediated code rather than an intermediate state. Before any tag.

---

## PM-028 — the two missing `ANALYSIS.md` write-ups

**Files:** `docs/automated-tests/20260807-110543/ANALYSIS.md`,
`docs/automated-tests/20260825-103450/ANALYSIS.md`.

Both bundles are frozen and their measured artifacts must not change; an `ANALYSIS.md` is a
**reading** of them, added beside them, which is what `automated-tests-§5` asks for. Write each
against that bundle's own numbers and the run before it — for `20260825-103450` the interesting
delta is 717 → 731 cases and 11061 → 11223 NLOC against the `1.0.0` release run
`20260807-160022`, both figures read from the two bundles' own `manifest.json` files.

The alternative the standard also permits: state in `docs/automated-tests/README.md` that
non-release runs may ship without a write-up. Pick one; a silent gap in an otherwise complete
series is the thing to avoid.

**Risk:** none. **Ordering:** independent; may ride the PM-027 commit.

---

## PM-029 — retire the `documentation-§4` register row

**Files:** `docs/ARCHITECTURE.md:199`.

Delete the row. The section's own preamble at `:175-176` says why this is the right act rather than
striking it through: *"This is not a graveyard. A row whose cited rule the standard has since
changed — so the behavior is now mandated or permitted outright — is **retired**, not kept for the
history."* The situation here is the sibling case: the rule did not change, the addon's release
state did, and the addon now satisfies `documentation-§4` outright.

**While in the same file, add the PM-024 row** if the upstream composer work is not being taken
immediately:

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `options-ui-§16` | The panel border, accent bar and accent-bar border groups are hand-written rather than emitted by `O.BorderGroup` / `O.BarGroup`. | The composers emit **schema rows** keyed by a dotted path; this page edits **registry records** and has no paths. There is no record-backed composer arm to call. Every mandated row is present, in the canonical order, with the canonical labels, and this addon's extras are appended after rather than interleaved. | *(date)* | `LibKa0s-Options-1.0` gaining a record-backed composer arm — at which point the three blocks are replaced by three calls and this row retires. |

**Risk:** none. **Ordering:** independent, but the PM-024 row should be written **before** the next
audit so PM-024 is not re-filed as an open MUST.

---

## PM-030 — the strip-geometry invariance case

**Files:** `tests/wow_mock.lua`, `tests/test_panel.lua`.

### Why a naive case is worthless here

`tests/_kit/mock_base.lua:97` answers `function f:GetHeight() return 0 end` for every frame and
every atlas. A case written against that harness passes whatever the library does, because the
selected and unselected art report the same height. `testing-§12`: a case that cannot fail is a
missing case.

### Shape

1. In `tests/wow_mock.lua`, extend the texture stub so `SetAtlas(name)` records the atlas and
   `GetHeight()` answers a **per-atlas** height — the selected tab atlas taller than the unselected
   one. `wow_mock` extends `mock_base` rather than replacing it (there is already a case pinning
   that), so this is an override in the consumer's mock, not an edit to the vendored kit.
2. Call `NS.Helpers.__resetTabArtHeight()` — published for exactly this
   (`settings/OptionsSetup.lua:101` stubs it, the live instance exposes it) — so the measurement is
   taken fresh per case.
3. Build the Panels page's strip at a width that forces a wrap, and assert, **for every value of
   the active tab**: the reserved band height is equal, and every row's y offset is equal.
4. Confirm the case dies under the mutation: change `TAB_ATLAS[false]` to `TAB_ATLAS[true]` at
   `libs/LibKa0s/OptionsWidgets.lua:434`, or delete the `measuredArtH` cache at `:429`. Run it once
   mutated, see red, revert. **Do not commit the mutation**, and do not edit `libs/` for anything
   other than this throwaway verification — `library-stack-§7` makes `libs/` read-only.

### Risk

The case reaches into library internals (`__tabArtHeight`, `__tabPlacement`). Those are published
`__`-prefixed members with a documented purpose ("a suite seam"), and the addon's stub already
answers all of them, so this is a sanctioned surface rather than a reach-through. Keep the
assertions on the **invariant** (equal across selections) rather than on the mechanism (which atlas
was probed) — anti-pattern #70's own advice.

### Ordering

Independent of PM-023 in principle, but write it **after** PM-023, because PM-023 changes the tab
list the case renders and a case written first would need rewriting.
