# Architecture — Ka0s Panel Master

Engineer context for the addon, and the **hub** of its doc set: each section below summarizes and
links, it does not store (`documentation-§3`).

Built to the [Ka0s WoW Addon Standard](https://github.com/tusharsaxena/WowAddonStandards). Read the
root [CLAUDE.md](../CLAUDE.md) first.

## Overview

A backdrop-panel creator, in the lineage of kgPanels and ElvUI's panels. The user creates named
rectangles with a color, a border, a size, a position and a layer, and the addon draws them behind the
rest of the UI. That is the whole product.

**It does not host anything.** A panel is scenery, not a container — which is why the addon needs no
secure frames, no combat gating on its render path, and no taint story. Full boundary in
**[scope.md](scope.md)**.

## Module Map

`core/` holds the bootstrap, the Compat firewall, the AceDB layer and four of the six LibKa0s seams;
`modules/` holds the registry, the artwork catalog, the Sunn adapter, the canvas renderer and unlock
mode; `settings/` holds the schema, the other two seams and the four panel pages. Load order is
fixed by the TOC — `core/Compat.lua` first, `settings/` last — and the LibKa0s seams pin several
steps of it.

File-by-file table and the seam/load-order contract in **[module-map.md](module-map.md)**.

## Settings Schema

Two SavedVariables scopes: `defaults/Profile.lua` carries the panel registry, `nextID` and the
settings block, all profile-scoped (every character starts on the shared "Default" profile,
`core/Database.lua:18`); `defaults/Global.lua` carries the account-wide `schemaVersion` stamp only.
`settings/Schema.lua` holds one row per setting and is the sole sender of `SettingsChanged`. It
carries **15 rows in 3 groups**, and since the tabbed-panel pass a `group` is a **tab**
(`options-ui-§13`): `H.RenderTabbedSchema` partitions the rows by `group` in declaration order, so
the array's order is the strip a player sees on the General page — `Master controls` (7),
`Editing` (4), `New panels` (4). Three of the fifteen are session-only `state.*` rows that route
through their own `get`/`set` and are never persisted.

The **first** seven are not literals in that file. `Master controls` is COMPOSED, out of
`LibKa0s-Options-1.0`'s `MasterControls` (`options-ui-§15`), and spliced at the head of the array by
`S:InstallMaster` — which `settings/OptionsSetup.lua` calls the moment the library instance exists,
because that instance is what carries the composer and it is built after this file loads. A row
carries no `widget` field: the flow engine dispatches on `type` alone, so a second field naming the
widget was a selector with no reader.

**The panel registry (`architecture-§5`).** The panel set is the addon's one structural registry:
the player creates and deletes panels at runtime, the defaults ship it empty, and no schema row
names a panel's existence.

- **Storage keys.** `db.profile.panels` is an array of records whose order is the array index, and
  `db.profile.nextID` is the monotonic id counter; each record's stamped `id` and `frameName` are
  its identity, and `name` is a unique label.
- **Writer.** `modules/Registry.lua` (`NS.Registry`) is the one registry writer: its local `create`,
  behind `New` and `NewBatch`, mints `rec.id` from `nextID`, stamps `frameName` and appends; its
  local `destroy`, behind `Delete` and `DeleteBatch`, and `DeleteAll` remove; `Rename` relabels
  `name` and leaves `id` and `frameName` alone; there is no duplicate or reorder operation.
- **Load pass.** `NS:RunMigrations` and `NS:SweepPreviewPanels`, both in `core/Database.lua`. The
  migration runner's v1 → v2 body backfills `frameName`, and it is called only from `NS:InitDB`.
  The sweep drops orphaned preview records, and it is called from `NS:InitDB`, right after the
  migrations, and from the `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset` callbacks.
  Neither is called from a slash verb or a control.

Nothing else writes membership or bookkeeping, so membership carries no `Documented deviations`
row. The one `architecture-§5` row this addon has covers the fields on a panel, below.
`/pm resetall` and Profiles → Reset Profile (`db:ResetProfile()`), and AceDB's own profile switch
and copy, replace the store wholesale, which is not a registry write; the load pass and
`NS.Registry:ReloadProfile` run after each of them. Each is logged once, by the profile handler in
`core/Database.lua` and worded by the event (`debug-logging-§10`; `docs/debug.md`).

**The fields on a panel: a ratified `architecture-§5` register row.** A panel's appearance and
position fields (`C.PANEL_FIELD_TYPE`, less `name`, which is the registry's own label and routes to
`Rename`) are preferences the player sets on a member, and none of them has a schema row. The field
controls and `/pm panel <name> set` write them through `NS.Registry:Set`, which coerces, writes,
sanitizes and sends `PanelChanged` on its own rather than through `NS.Schema:Set`. It is not the
only writer. `:SetPosition` writes `x`/`y`, and the unlock drag-stop (`modules/Unlock.lua`) writes
`point`/`relPoint` straight onto the live record before calling it, so a drag writes geometry.
`:Reset`, `:CopyFrom` and `:FitToArtwork` rewrite fields and then sanitize. `:Recover` writes
`x`/`y`, and `:ResetPositions` all four anchor fields, onto every record directly, with no
per-record sanitize, and each sends `PanelsChanged` once if anything moved. None of these is the
schema helper. The drag is part of the same set, not a separate case: every anchor field it writes
(`point`, `relPoint`, `x`, `y`) is also set by the editor or `/pm`, so they are preferences.

Since standard v2.43.0 a preference with no row is a missing row. The owner ruled on 2026-09-12
([#49](https://github.com/tusharsaxena/PanelMaster/issues/49)) for a register row rather than
instance-relative rows, because the schema helper addresses paths, not records, and
instance-addressing every per-panel field would be the largest change in the collection for fields
the Registry already validates and announces. The row is `architecture-§5` (the fields on a panel)
in [`## Documented deviations`](#documented-deviations). It retires when the schema helper gains
instance addressing for registry records (an explicit record argument on `NS.Schema:Set`). The
record-backed bind arm in `LibKa0s-Options-1.0` is not that trigger: it changes how a control
binds to a record, not where the write goes.

The panel record, every field on it, the artwork fields and the sanitizing pass are in
**[schema.md](schema.md)**; the pages that edit them in **[settings-panel.md](settings-panel.md)**;
profile behavior in **[profiles.md](profiles.md)**.

## Message bus (`architecture-§4`)

Three messages, one sender each, consumers registering on their **own** AceEvent target via
`NS.NewBusTarget()`. CallbackHandler keys callbacks by `(message, target)`, so two consumers sharing
a target would silently clobber each other.

| Message | Sender | Meaning | Consumers |
|---|---|---|---|
| `Ka0s_PanelMaster_PanelsChanged` | `modules/Registry.lua` | The **set** changed (add / delete / rename) — rebuild everything. | `Canvas`, the Panels settings page |
| `Ka0s_PanelMaster_PanelChanged` | `modules/Registry.lua` | **One** panel's fields changed — repaint just it. | `Canvas` |
| `Ka0s_PanelMaster_SettingsChanged` | `settings/Schema.lua` | An addon-level setting changed **in a way a panel can show**. | `Canvas` |

Not every row broadcasts: `settings.snapToGrid` and `settings.gridSize` carry no `onChange`, because
`Unlock.SnapPosition` reads them live at drag-stop and nothing renders from them. Announcing would
repaint every panel on each tick of the Grid size slider for no visible difference.

The split between the two panel messages is what lets a drag repaint one frame instead of all of
them. A test asserts that no other file sends any of the three.

A caller that changes the set N times at once uses the **batch seams** rather than N single calls:
`Registry:NewBatch(specs)` and `Registry:DeleteBatch(keys)` mutate N records and broadcast
`PanelsChanged` **once** — the shape `Registry:DeleteAll` already had. Preview mode is the caller
that needs them: standing up three placeholders used to rebuild every consumer three times.

`Canvas:Enable()` — which installs those subscriptions — is called from **`OnEnable`**. This is not
incidental: an early build omitted it, so every message broadcast into a bus with no listener and
nothing was live. The only repaints left were the two paths that call `Canvas:RenderAll()` directly
(lock/unlock and test mode), which is why panels appeared frozen until test mode was toggled. The
test harness hid it by calling `Canvas:Enable()` itself; it now drives the real `OnInitialize` /
`OnEnable`, so a dropped step fails the suite.

## Slash Commands

`/pm` (and the `/panelmaster` alias) via AceConsole. Every verb comes from `NS.COMMANDS` in
`settings/Slash.lua`, so the help index and the settings landing page's command list are generated
from one table and cannot drift. No hand-kept copy of the descriptions is carried anywhere: `slash-dispatch.md` names the verbs to
structure its own prose, and that is the only list of them outside the table.

Schema-driven verbs: `config version get set list reset resetall debug help` — `resetall` is a
**profile reset** (`options-ui-§12`): confirm-gated, the same act as Profiles → Reset Profile, and it
takes the player's panels with it because `db.profile.panels` is in the profile. Panel verbs: `new
delete rename panels panel unlock lock preview recover`. Verb detail and the host/library split in
**[slash-dispatch.md](slash-dispatch.md)**.

## Event Subscriptions

| Event | Handler | Why |
|---|---|---|
| `PLAYER_ENTERING_WORLD` | `Canvas:RenderAll()` | Panels are drawn here, not at `OnEnable`: `UIParent`'s size is what recovery measures against and it is not final that early. |
| `PLAYER_REGEN_ENABLED` | `Unlock:ResumePending()`, then `Canvas:RenderForCombat()` | Replays a combat-deferred unlock, and repaints if `settings.visibility` is one of the two modes that depend on the combat state. |
| `PLAYER_REGEN_DISABLED` | `Canvas:RenderForCombat()` | The other half of the general-visibility rule (`options-ui-§15`). Panels are non-secure, so showing or hiding one at the start of a pull needs no gate. |
| `PLAYER_LOGIN` | `Panel:Register()` | A second **eager** attempt at settings-category registration. Subscribed from `OnInitialize`, not `OnEnable`: AceAddon runs `OnEnable` from inside its own `PLAYER_LOGIN` handler, and subscribing mid-dispatch misses that firing. |

The render pipeline these drive, and the combat gating around unlock and the options panel, are in
**[data-flow.md](data-flow.md)**.

## Taint

There is none to speak of, and that is a design property rather than luck: the addon creates only
non-secure frames of its own, never touches a Blizzard frame, never reparents anything, and never
calls a protected API. The single protected call anywhere near it is `Settings.OpenToCategory`, which
is refused under lockdown.

## Known Limitations

Seven, each with its reasoning — CLI names with spaces, a renamed panel's frame name, frame-name
reservation across renames, no per-panel level UI, the hard-cut mouseover fade, player-class-only
coloring, and manual `/pm recover`. All in **[scope.md](scope.md)**.

## Documentation map

Every `.md` under `docs/` appears in exactly one table below (`documentation-§3`). Frozen and
generated directories are named once each and never enumerated per run: `docs/audits/`,
`docs/reviews/`, `docs/automated-tests/`, `docs/revendor/`, `docs/superpowers/`.

### Required (documentation-§3, Tier 1)

| Doc | Covers |
|---|---|
| `scope.md` | What the addon draws, and what it deliberately refuses to become |
| `module-map.md` | Every non-vendored file, what it publishes, and the load order the seams pin |
| `schema.md` | The two SavedVariables scopes, the panel record, artwork fields, sanitizing |
| `settings-panel.md` | The four canvas pages and the three AceGUI widget workarounds |
| `data-flow.md` | Record → spec → frame, the frame ladder and pool, preview mode, combat, events |
| `common-tasks.md` | Add a setting, a verb, a panel field, an artwork entry, a migration |

### Conditional (documentation-§3, Tier 2)

| Doc | Status | Trigger |
|---|---|---|
| `slash-dispatch.md` | Present | 18 verbs in `NS.COMMANDS` (threshold is 8) |
| `profiles.md` | Present | AceDB profiles are user-visible — the Profiles settings page |
| `debug.md` | Present | `D:Diagnose()` and `NS.DebugBuild` are the addon's own, beyond the library console |
| `message-bus.md` | Not applicable | Three messages; threshold is more than ten. The table lives in `ARCHITECTURE.md` → `## Message bus` |
| `midnight-quirks.md` | Not applicable | No client-version workaround of the addon's own. The one fixup this addon ever carried was for a vendored **widget**, not a client behavior, and it is no longer this addon's: `lib.__PatchLSM30Border()` (`LibKa0s-Options-1.0` minor 15) owns it for the whole collection, called from `settings/OptionsSetup.lua` |
| `compat-layer.md` | Not applicable | `core/Compat.lua` normalizes the addon roster, screen size, UI scale, LSM and class color — no addon-specific shim beyond what the row in `module-map.md` records |
| `perf-analysis/README.md` | Not applicable | `LibKa0s-Perf` is declined on structural grounds ([`LIBKA0S-31`](https://github.com/tusharsaxena/PanelMaster/issues/31)); see `## Documented deviations` and `performance.md` |

### Verification and record

| Doc | Covers |
|---|---|
| `testing.md` | How to run the harness and lint; the green commit gate |
| `smoke-tests.md` | The in-game smoke-test suite |
| `test-cases.md` | The generated case inventory (authoritative pass count) |
| `performance.md` | The performance position and the sweep behind it |
| `automated-tests/README.md` | What the automated-test record is and how to produce it |
| `automated-tests/RESULTS.md` | One row per run; generated, never hand-edited |

### Addon-specific (documentation-§3, Tier 3)

| Doc | Covers |
|---|---|
| `rendering.md` | Mouseover fade, the four accent bars, the artwork pipeline, the Sunn composite adapter |
| `artwork-spec.md` | Authoring artwork for the addon: folder tree, naming, the cleaner, source-image choice |
| `localization.md` | The `NS.L` seam, the key-is-the-string rule, and the 1.0.0 unwrapped position |
| `media.md` | What ships under `media/`, and why each asset is there |

## Documented deviations

The **single home** for a ratified deviation from the Ka0s WoW Addon Standard (`documentation-§3`).
A decision may be *reasoned* at length in this repo's GitHub issues or in a frozen
audit bundle, and the **Why** column cites that id — but a deviation that is not in this table is
**not ratified**, and an audit that cannot find it re-files it as an open MUST failure every cycle.

This is not a graveyard. A row whose cited rule the standard has since changed — so the behavior is
now mandated or permitted outright — is **retired**, not kept for the history.

**The `Perf` decline IS a row here, as of 2026-08-25, and it cites `performance-§1` directly.**
It was deliberately withheld until then, on reasoning worth keeping: the obvious row would have
cited `performance-§12`'s no-combat-path exemption, and **this addon does not qualify for it** —
criterion (a) requires no `OnUpdate` handler, and `modules/Canvas.lua:660` installs a shared 10Hz
driver the moment any panel has *Show on mouseover only* ticked, with no combat gate. A `§12` row
would have been a false row, so no row was written and an audit re-filed `performance-§1` every
cycle, which was the correct outcome for as long as the choice was unmade.

The choice is now made, and it is the other one this section allows: a **deliberate deviation from
`performance-§1` itself**, ratified by the owner on a bounded-cost argument, rather than an
exemption claimed under `§12`. `§12` remains unclaimable here and the row below does not claim it.
See [`performance.md`](performance.md) for the cost argument and the committed sweep.

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `performance-§1` (the wiring MUST) | No `core/PerfSetup.lua`, no `PanelMasterPerfDB`, no `perf` verb, no `tests/perf.lua`. The `perf` verb stays **reserved** so it can never mean anything else here. | **Ratified as a deviation from `§1`, NOT as a `§12` exemption — `§12` does not apply and is not claimed.** The addon's one in-combat path is a single shared 10Hz `OnUpdate` (`modules/Canvas.lua:644-650`) whose whole body is, per mouseover-tracked panel, one `NS.Compat.MouseIsOver` and one `SetAlpha`. The cost is bounded by a number the player sets: panels with *Show on mouseover only* ticked, which defaults to `false` (`core/Constants.lua:306`). With none ticked the driver is never created; with the set emptied afterwards the frame survives but its script does not — `SetMouseoverTracked` clears the `OnUpdate` on the untrack that empties the set, and `ensureMouseoverDriver` re-installs it when the set refills, so the dormant cost is no per-frame callback at all. There is no per-record work, no allocation, no scan that grows with saved data, and nothing whose cost a raid can change. Wiring the full harness — a setup file, a second SavedVariables global, a slash verb, a `suspend`/`resume` contract and an offline scenario — to bracket two API calls at 10Hz is a cost the measurement could not repay. Owner's decision, 2026-08-25, over [#31](https://github.com/tusharsaxena/PanelMaster/issues/31) and [#44](https://github.com/tusharsaxena/PanelMaster/issues/44). | 2026-08-25 | Any of: a second `OnUpdate` or repeating ticker; `updateMouseover` growing work that is not O(tracked panels) of two API calls; a panel count that stops being player-bounded; or `performance-§12` gaining a bounded-cost clause upstream, at which point the exemption becomes claimable and this row is replaced by one that cites it. |
| `events-frames-taint-§8` (the pre-formatting **SHOULD**) | Roughly 25 chat and slash lines build their text with `("…"):format(…)` or `..` before handing it to `NS.Print` — `settings/Slash.lua`, `settings/PanelEditor.lua`, `settings/Schema.lua` — rather than the preferred `print("count", n)` varargs form. | **The MUST does not engage here, and this was re-graded, not waived.** §8 scopes the MUST NOT to call sites whose arguments are, or derive from, a return of a named combat-protected API. This addon reads **none** of them: a whole-repo sweep of `core/ modules/ settings/ defaults/ locales/` for the trigger set (`UnitGetTotalAbsorbs`, `UnitGetTotalHealAbsorbs`, `UnitGetIncomingHeals`, `UnitHealth`, `UnitHealthMax`, `UnitThreatSituation`, `UnitDetailedThreatSituation`, the aura amount/`points` fields, `UNIT_AURA`) returns nothing, and the only unit/client APIs it calls at all are `UnitClass` and `C_AddOns.GetAddOnMetadata`. Every one of these lines formats values the addon owns — a panel name, a stored geometry field, a count it computed, a literal — so none can be handed a secret and the residue is the SHOULD, graded Info. Neither of §8's two unrelaxed points is touched: no site calls the global `print()` (every file takes `local print = NS.Print`), and the seam's guarantee is unconditional — `core/CoreSetup.lua` publishes the library's `IsConcatSafe` / `SafeToString` and builds the printer from `lib:New`, so every argument is stringified through the `table.concat` probe whatever a call site hands it. Converting the sites is therefore a readability change with no reachable behavior, and is declined at `1.0.0`. | 2026-08-05 | The first chat or debug line whose arguments include, or derive from, a return of any API in §8's trigger set — that site converts as a MUST, and an audit files it as one. Re-check also when §8's trigger list grows upstream. |
| `localization-§1` | No user-facing string routes through `NS.L`: every label, tooltip, slash line and message is hardcoded English. | `1.0.0` ships **English-only** — the second of the two terminal compliant states `localization-§3` names, not an open routing gap. Both MUSTs are met unconditionally: the `NS.L` seam is exported with the key-returning metatable fallback (`locales/enUS.lua:6`) and `enUS.lua` ships, so a later pass wraps strings without touching call sites. Reasoned at `locales/enUS.lua:8-14`. Panel **names** are user data and must never route through `NS.L`; neither must the stored `point` / `strata` tokens (`localization-§4`). | 2026-08-05 | The first non-English locale file added to `locales/` — that change routes the strings and retires this row |
| `architecture-§5` (the fields on a panel) | The per-panel appearance and position fields in `C.PANEL_FIELD_TYPE` (`core/Constants.lua`) are preferences the player sets on a member, and none has a schema row. That is every field except `name`, which routes to `R:Rename`: colors, the border, bar and bar-border blocks, textures, size, `strata`, `level`, `scale`, `alpha`, mouseover, `enabled`, the `art*` fields and the anchor (`point`, `relPoint`, `x`, `y`). They are written through `NS.Registry:Set` (the field controls in `settings/PanelEditor.lua` and `/pm panel <name> set`) and `:SetPosition`, and by the whole-record and bulk verbs: `R:Reset`, `R:CopyFrom`, `R:FitToArtwork` (through `R.ApplyArtSize`), `R:Recover`, `R:ResetPositions`, and the unlock-mode drag-stop in `modules/Unlock.lua`, which writes `point`/`relPoint` onto the live record and then calls `:SetPosition`. Each of these coerces, writes and notifies on its own (`PanelChanged` per record; `PanelsChanged` once for `Recover` and `ResetPositions`), none through `NS.Schema:Set`. | The schema helper addresses paths, not records: `NS.Schema:Set` writes a path under the profile, and a panel is a registry record reached by id. Instance-addressing every per-panel field would be the largest change in the collection, for fields the Registry already validates (the `C.PANEL_FIELD_TYPE` coercers plus `R.Sanitize`), logs once at the seam and announces on the bus. Owner's decision, 2026-09-12, over [#49](https://github.com/tusharsaxena/PanelMaster/issues/49). | 2026-09-12 | The schema helper gains instance addressing for registry records (an explicit record argument on `NS.Schema:Set`). The fields then take instance-relative rows, the verbs above become callers of the helper, and this row retires. |

**Retired on 2026-09-12, three rows for one reason: the `options-ui-§16` border, bar and bar-border
blocks.** Each row said a canonical group on the Panels page was typed out in
`settings/PanelEditor.lua`, because `O.BorderGroup` and `O.BarGroup` emitted path-keyed schema rows
and a panel is a registry record with no path, and each carried the trigger *the composer gains a
record-backed arm*. LibKa0s v1.31.0 shipped that arm (`spec.bind`, OptionsCompose minor 4, read by
OptionsWidgets minor 15), so the trigger fired. The three blocks are composed now, each from one
declaration with a `bind` over the live panel record that writes through `NS.Registry:Set`
([#48](https://github.com/tusharsaxena/PanelMaster/issues/48)). The behavior is what `§16` mandates,
and a row for it would be the graveyard `documentation-§3` forbids. `tests/test_options_groups.lua`
holds the new state: no hand-written block on the page, the three composer calls bound, no
`options-ui-§16` row in this table, and a control-by-control characterization of what the composed
blocks draw and write. The `architecture-§5` row above stays. The arm changes how a control binds to a
record, not where the write goes, and that row's trigger is deliberately the schema helper.

**Retired on 2026-09-08, three rows, three different reasons.**

- **`documentation-§4` — pending work in GitHub issues rather than a root `TODO.md`.** The row's
  Why read *"the addon is pre-release, so the rule is not yet engaged"* and its trigger read *"the
  first published release"*. `1.0.0` shipped on 2026-08-07 (`PanelMaster.toc`, `README.md`'s
  Version History, tag `1.0.0-release`), so the trigger fired that day. `documentation-§4` is
  engaged now, and this addon **satisfies it outright** — there is no `TODO.md` at the root or
  under `docs/`, and the backlog is the issue store, which is what the rule asks for. A row for
  compliant behavior is the graveyard `documentation-§3` forbids. `PM-029`.

- **`options-ui-§1` — the seven Master controls rows a library-less load does not get.** The row
  argued that the stub cannot reproduce what `H.MasterControls` emits without holding a host copy
  of the library's canonical row data, and that the copy is the thing that goes stale.
  `options-ui-§1` now rules exactly that: when the missing content is **composed** the no-copy MUST
  wins, a stub's composer members answer an empty row list, and *"this shape needs no register row,
  and the rows already written for it retire"*. The ruling's three bounds hold here — `LibKa0s` is
  vendored whole so the load that loses the composers loses the schema CLI with it, profile
  defaults merge from `defaults/Profile.lua` and are never read off the schema, and
  `tests/test_libka0s.lua`'s *"the schema loses the composed Master controls rows and NOTHING
  else"* pins the live count, the degraded count and the delta between them rather than one
  number. Nothing about the degraded load changes.

- **`line-endings-§5` — the extension-less binary mark.** The row recorded a genuine collision:
  `§4` MUSTs every binary be marked, `§5` MUSTs this file be byte-identical to the canonical body,
  and `tools/artwork/bin/realesrgan-ncnn-vulkan` has no extension for any `*.ext` line to reach.
  `§5` now carries an **appendix**: a delimited block below the canonical body, marks keyed by
  path, single paths rather than globs, each with a comment saying why no extension reaches it —
  and it says in as many words that a repo **MUST NOT** carry a register row for one, and that a
  row predating the rule is retired by bringing the block into that shape. So the block moved: it
  sat at `.gitattributes:67-71`, **inside** the body, which is the placement the appendix rule
  names as the thing it forbids, because it displaces every line after it and turns a one-decision
  diff into two. The first 81 lines are now byte-identical to the canonical client-bound body and
  the mark is below it under `# --- line-endings-§5 appendix ---`. Verified with the section's own
  check: `diff <(head -n 81 .gitattributes) <canonical>` is empty and
  `tail -n +82 .gitattributes | tr -d '\r' | grep -m1 .` is the delimiter.

## File sizes (`layout-§1`)

`layout-§1` caps every **authored** `.lua` file this repository tracks at 1500 lines — `tests/`
included, with vendored code (`libs/`, `tests/_kit/`) the only carve-out that reaches anything here;
nothing in this repo is generated non-shipping data, so the second carve-out has no instance. Files in
the **1000–1500 band are on notice**. A file **over** the cap has three terminal states and no others:
peeled, an open issue naming the seam a peel would follow, or a ratified row in
`## Documented deviations` above carrying a re-check trigger. What the rule does not allow is a file
nothing anywhere remarks on — "the count sitting in a bundle manifest that no document reads".

This table is the remark, and it is the **live** register. `docs/automated-tests/RESULTS.md` also
carries a *Files by `layout-§1` band* watch list; that one is per-run generated evidence, frozen at the
run that wrote it, and it is not hand-edited (`performance-§10`). When the two disagree, this table is
the current one and the other is a measurement of an August afternoon.

### Files by the `layout-§1` band

Measured 2026-09-11 with

```
git ls-files '*.lua' | grep -v '^libs/' | grep -v '^tests/_kit/' | xargs wc -l | sort -rn
```

| File | Lines (2026-09-11) | Disposition |
|---|---|---|
| `settings/PanelEditor.lua` | 1414 (1485 on 2026-09-12, after [#48](https://github.com/tusharsaxena/PanelMaster/issues/48) composed its three blocks; 1476 once the swatch suffix went) | **On notice, and its own trigger has fired.** Issue [#47](https://github.com/tusharsaxena/PanelMaster/issues/47) — the appearance editor (`:200-231`, `:347-1170`, ~825 lines, measured 2026-09-12) out from under the Panels page's chrome band, into a sibling under `settings/`; the issue names the four shared symbols the peel has to publish on `E` first. Not peeled this cycle by plan. |
| `tests/test_artwork.lua` | 1356 | **Accepted — it peels when `modules/Artwork.lua` does, on the same seam, in the same commit.** A mirror suite has no partition of its own: pick one before the module has, and the two files stop pairing, which is worse for a reader under failure than one long file that pairs. |
| `tests/test_panel.lua` | 1273 | **Accepted, and it is the row this census was written by finding.** It crossed 1000 at `1b8c672` (2026-09-03, 1076) and nothing anywhere said so — the watch list that should have caught it is frozen at the 1.0.0 release run, where this file was 708. It is the suite for **both** page files, so its appearance cases leave with the editor when [#47](https://github.com/tusharsaxena/PanelMaster/issues/47) peels; same seam, same commit. |
| `modules/Artwork.lua` | 1188 | **Accepted, and watch the direction.** Flat since the 1.0.0 release run (1188 at `20260807-160022`, 1087 at the baseline). Split along the catalog / geometry seam before the next feature lands in it; `tests/test_artwork.lua` peels with it. |

**Nothing is over the cap.** The largest authored file in the repository,
`settings/PanelEditor.lua`, is twenty-four lines under it (1476 lines on 2026-09-12), and
the four rows above are the whole band. `modules/Registry.lua` at 999 is the nearest file outside the
table and is now one line from needing a row of its own. `M4-18` put a private sweep in it and was
trimmed to stay under the trigger deliberately: crossing the band as a side effect of a Low-severity
boundary fix would have bought a census row that said nothing.

**The line counts are dated because they drift, and nothing asserts them.** What
`tests/test_layout_cap.lua` asserts is the *membership* of this table, in both directions: a file that
reaches 1000 lines and is not listed here turns the suite red, and so does a row for a file that has
fallen back under the band or been deleted. A figure in this column is a measurement, not a claim about
today.

**This repo gates the band; its siblings gate the cap alone, and the difference is deliberate.**
MultiMeters (fifteen files over the cap) and LibKa0s (two) run the same gate over the over-cap set and
leave the band as prose, which is right where the breaches are the subject. Here there are no breaches,
so an over-cap-only gate would assert nothing at all today and would first speak on the day
`settings/PanelEditor.lua` crossed 1500 with no row — one ordinary commit away. The subject in this
repository is the band, so the band is what is gated.

**Nothing here is peeled this cycle.** The 2026-09-07 remediation plan rules out splitting any file
(`03_SPEC.md` § C22 non-goals; `04_EXECUTION_PLAN.md` `M4-14`: *"No splits in this plan"*). The
deliverable was the disposition, and the disposition is this table plus [#47](https://github.com/tusharsaxena/PanelMaster/issues/47).

**Why `settings/PanelEditor.lua` gets an issue rather than a register row.** A register row ratifies a
**deviation**, and there is nothing to deviate from: at 1488 the file complies with `layout-§1`. A row
in `## Documented deviations` claiming otherwise would be a false row, which is the same mistake this
document already reasons about at length for the `performance-§12` exemption it declined to claim. An
open issue naming a verified seam is the honest record of a peel that is owed and not yet done.
