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

Two SavedVariables scopes: `defaults/Profile.lua` carries the per-character panel registry, `nextID`
and the settings block; `defaults/Global.lua` carries the account-wide `schemaVersion` stamp only.
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
`settings/Slash.lua`, so the help index, the settings landing page's command list and the README
table are generated from one table and cannot drift.

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
| `midnight-quirks.md` | Not applicable | No client-version workaround of the addon's own. `core/LSMPatch.lua` fixes a vendored **widget**, not a client behavior, and is documented in `module-map.md` |
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
criterion (a) requires no `OnUpdate` handler, and `modules/Canvas.lua:646` installs a shared 10Hz
driver the moment any panel has *Show on mouseover only* ticked, with no combat gate. A `§12` row
would have been a false row, so no row was written and an audit re-filed `performance-§1` every
cycle, which was the correct outcome for as long as the choice was unmade.

The choice is now made, and it is the other one this section allows: a **deliberate deviation from
`performance-§1` itself**, ratified by the owner on a bounded-cost argument, rather than an
exemption claimed under `§12`. `§12` remains unclaimable here and the row below does not claim it.
See [`performance.md`](performance.md) for the cost argument and the committed sweep.

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `performance-§1` (the wiring MUST) | No `core/PerfSetup.lua`, no `PanelMasterPerfDB`, no `perf` verb, no `tests/perf.lua`. The `perf` verb stays **reserved** so it can never mean anything else here. | **Ratified as a deviation from `§1`, NOT as a `§12` exemption — `§12` does not apply and is not claimed.** The addon's one in-combat path is a single shared 10Hz `OnUpdate` (`modules/Canvas.lua:642-653`) whose whole body is, per mouseover-tracked panel, one `NS.Compat.MouseIsOver` and one `SetAlpha`. The cost is bounded by a number the player sets: panels with *Show on mouseover only* ticked, which defaults to `false` (`core/Constants.lua:306`). With none ticked the driver is never created; with the set emptied afterwards it accumulates `delta` and returns. There is no per-record work, no allocation, no scan that grows with saved data, and nothing whose cost a raid can change. Wiring the full harness — a setup file, a second SavedVariables global, a slash verb, a `suspend`/`resume` contract and an offline scenario — to bracket two API calls at 10Hz is a cost the measurement could not repay. Owner's decision, 2026-08-25, over [#31](https://github.com/tusharsaxena/PanelMaster/issues/31) and [#44](https://github.com/tusharsaxena/PanelMaster/issues/44). | 2026-08-25 | Any of: a second `OnUpdate` or repeating ticker; `updateMouseover` growing work that is not O(tracked panels) of two API calls; a panel count that stops being player-bounded; or `performance-§12` gaining a bounded-cost clause upstream, at which point the exemption becomes claimable and this row is replaced by one that cites it. |
| `documentation-§1` (item 5) | `README.md` carries no `## What's new` section. `## Version History` (item 12) is present. | **`1.0.0` is the initial public release, so there is nothing new to report yet.** The section's job is to tell a returning player what changed since the build they already had; on a first release every reader is a new one, and the whole README is the answer. The section it would duplicate — the feature list — already sits above it. `0.1.0` was the development version across all 108 commits and was never published (CurseForge reported no file), so `1.0.0` is genuinely the first thing anyone can install. Owner's decision, 2026-08-07. | 2026-08-07 | The first release **after** `1.0.0` — not the next version bump, which is what an earlier wording of this trigger said and which fired on `1.0.0` itself. `/wow-addon:bump-version` rolls this section with `## Version History`, so that command retires this row on the release that actually has something to report |
| `events-frames-taint-§8` (the pre-formatting **SHOULD**) | Roughly 25 chat and slash lines build their text with `("…"):format(…)` or `..` before handing it to `NS.Print` — `settings/Slash.lua`, `settings/PanelEditor.lua`, `settings/Schema.lua` — rather than the preferred `print("count", n)` varargs form. | **The MUST does not engage here, and this was re-graded, not waived.** §8 scopes the MUST NOT to call sites whose arguments are, or derive from, a return of a named combat-protected API. This addon reads **none** of them: a whole-repo sweep of `core/ modules/ settings/ defaults/ locales/` for the trigger set (`UnitGetTotalAbsorbs`, `UnitGetTotalHealAbsorbs`, `UnitGetIncomingHeals`, `UnitHealth`, `UnitHealthMax`, `UnitThreatSituation`, `UnitDetailedThreatSituation`, the aura amount/`points` fields, `UNIT_AURA`) returns nothing, and the only unit/client APIs it calls at all are `UnitClass` and `C_AddOns.GetAddOnMetadata`. Every one of these lines formats values the addon owns — a panel name, a stored geometry field, a count it computed, a literal — so none can be handed a secret and the residue is the SHOULD, graded Info. Neither of §8's two unrelaxed points is touched: no site calls the global `print()` (every file takes `local print = NS.Print`), and the seam's guarantee is unconditional — `core/CoreSetup.lua` publishes the library's `IsConcatSafe` / `SafeToString` and builds the printer from `lib:New`, so every argument is stringified through the `table.concat` probe whatever a call site hands it. Converting the sites is therefore a readability change with no reachable behavior, and is declined at `1.0.0`. | 2026-08-05 | The first chat or debug line whose arguments include, or derive from, a return of any API in §8's trigger set — that site converts as a MUST, and an audit files it as one. Re-check also when §8's trigger list grows upstream. |
| `localization-§1` | No user-facing string routes through `NS.L`: every label, tooltip, slash line and message is hardcoded English. | `1.0.0` ships **English-only** — the second of the two terminal compliant states `localization-§3` names, not an open routing gap. Both MUSTs are met unconditionally: the `NS.L` seam is exported with the key-returning metatable fallback (`locales/enUS.lua:6`) and `enUS.lua` ships, so a later pass wraps strings without touching call sites. Reasoned at `locales/enUS.lua:8-14`. Panel **names** are user data and must never route through `NS.L`; neither must the stored `point` / `strata` tokens (`localization-§4`). | 2026-08-05 | The first non-English locale file added to `locales/` — that change routes the strings and retires this row |
| `line-endings-§5` | `.gitattributes` carries one extra block — `tools/artwork/bin/realesrgan-ncnn-vulkan binary` — so it is not byte-identical to the canonical client-bound body. | **Two MUSTs collide and only one can hold.** `line-endings-§4` requires every binary to be marked `binary`; `line-endings-§5` requires this file to match the canonical body byte-for-byte. The canonical list is an **extension** census, and this repo vendors an **extensionless** ELF executable (the Real-ESRGAN upscaler behind `tools/artwork/`), which no `*.ext` rule can ever match. Left unmarked it is the sole working-tree stray `line-endings-§7` reports for this addon — a real §4 failure, not a false positive, and one that would be re-filed every cycle. The block is scoped to the single path rather than a `tools/**` glob so it cannot silently swallow a future text file. Nothing about the pin, the `*.sh` carve-out or the shared binary list changes; the deviation is additive and comment-documented in the file itself. | 2026-08-07 | `line-endings-§4`/`§5` gaining any provision for extensionless or path-marked binaries upstream — at which point this block moves into the canonical body and the row retires. Re-check also if `tools/artwork/bin/` stops being vendored. |
| `options-ui-§1` (the degradation rule) | With `libs/LibKa0s/` absent the schema loses its seven **Master controls** rows — the composed block — so a library-less install's `/pm list`, `get`, `set` and `reset` reach the *Editing* and *New panels* rows only. Every other member of the stub is answered and the addon loads, runs and draws panels exactly as before. | **The stub cannot answer this one honestly, and a dishonest answer is worse than a narrower CLI.** `§1` requires the stub to publish every member a page file touches at load, real enough for the file to finish — which it does: `S:InstallMaster` returns false and the array keeps the rows it declared itself. What it cannot do is *reproduce* what `H.MasterControls` emits, because that is the library's canonical row data (the set, the order, the labels, the ranges, the defaults) and a hand-copied set in the stub is the copy that goes stale — which is `§1`'s own MUST NOT against carrying library code into the stub, and anti-pattern #47. The cost is therefore taken deliberately and MEASURED rather than assumed, as `§1` requires: `tests/test_libka0s.lua` pins the degraded row count at exactly *live minus the composed block* and asserts every surviving row still resolves against the defaults, so the loss can never widen without somebody deciding to widen it. Owner's decision, 2026-09-02. | 2026-09-02 | `LibKa0s-Options-1.0` gaining a composer form that can run without the library — or `options-ui-§1` gaining a rule for composed rows in the degraded arm, at which point this row retires. Re-check also the day a row the block emits becomes the ONLY way to reach something a player in this state needs — the master switch is the closest, and today `/pm delete` still removes a panel outright without it. |
| `documentation-§4` | Pending work lives in this repo's GitHub issues, which also function as a backlog, rather than in a root `TODO.md`. | `documentation-§4` forbids a `TODO.md` **once released**; it does not mandate one before. An issue is the better shape for the job — it records the *decision* and its rationale per item, with a re-surface rule, which a bare checklist cannot. The addon is pre-release, so the rule is not yet engaged. | 2026-08-05 | The first published release, which is when `documentation-§4` engages |
