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

`core/` holds the bootstrap, the Compat firewall, the AceDB layer and two of the four LibKa0s seams;
`modules/` holds the registry, the artwork catalog, the Sunn adapter, the canvas renderer and unlock
mode; `settings/` holds the schema, the other two seams and the four panel pages. Load order is
fixed by the TOC — `core/Compat.lua` first, `settings/` last — and the LibKa0s seams pin several
steps of it.

File-by-file table and the seam/load-order contract in **[module-map.md](module-map.md)**.

## Settings Schema

Two SavedVariables scopes: `defaults/Profile.lua` carries the per-character panel registry, `nextID`
and the settings block; `defaults/Global.lua` carries the account-wide `schemaVersion` stamp only.
`settings/Schema.lua` holds one row per setting and is the sole sender of `SettingsChanged`.

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

Schema-driven verbs: `config version get set list reset resetall debug help`. Panel verbs: `new
delete rename panels panel unlock lock preview recover`. Verb detail and the host/library split in
**[slash-dispatch.md](slash-dispatch.md)**.

## Event Subscriptions

| Event | Handler | Why |
|---|---|---|
| `PLAYER_ENTERING_WORLD` | `Canvas:RenderAll()` | Panels are drawn here, not at `OnEnable`: `UIParent`'s size is what recovery measures against and it is not final that early. |
| `PLAYER_REGEN_ENABLED` | `Unlock:ResumePending()` | Replays a combat-deferred unlock. |
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
`docs/reviews/`, `docs/automated-tests/`, `docs/superpowers/`.

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
| `compat-layer.md` | Not applicable | `core/Compat.lua` normalizes metadata, screen size, UI scale, LSM and class color — no addon-specific shim beyond what the row in `module-map.md` records |
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
| `localization.md` | The `NS.L` seam, the key-is-the-string rule, and the 0.1.0 unwrapped position |
| `media.md` | What ships under `media/`, and why each asset is there |

## Documented deviations

The **single home** for a ratified deviation from the Ka0s WoW Addon Standard (`documentation-§3`).
A decision may be *reasoned* at length in this repo's GitHub issues or in a frozen
audit bundle, and the **Why** column cites that id — but a deviation that is not in this table is
**not ratified**, and an audit that cannot find it re-files it as an open MUST failure every cycle.

This is not a graveyard. A row whose cited rule the standard has since changed — so the behavior is
now mandated or permitted outright — is **retired**, not kept for the history.

**The `Perf` decline is deliberately NOT a row here.** It is recorded in
[`PLAN-06`](https://github.com/tusharsaxena/PanelMaster/issues/24), and an issue without a register row is exactly what this section says is *not*
ratified — so an audit will keep re-filing `performance-§1` against this addon, and that is the
correct outcome today. The obvious row to write would cite `performance-§12`'s no-combat-path
exemption, and **this addon does not qualify for it**: criterion (a) requires no `OnUpdate` handler,
and `modules/Canvas.lua:577` installs a shared 10Hz `OnUpdate` driver — `updateMouseover`, one
`MouseIsOver` call per mouseover-tracked panel — the moment any panel has *Show on mouseover only*
ticked, with no combat gate. Criterion (b) fails with it: a bucket around that loop would not read
`0.000` by construction. See [`performance.md`](performance.md) for the committed sweep. Claiming
the exemption anyway is a decision only the owner can make, and it needs the wiring or a different
rule, not a row.

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `documentation-§1` (item 6) | `README.md` ▸ `## Screenshots` carries a placeholder line rather than images. | The section is a SHOULD that becomes a MUST **once published**, and this addon is unreleased at `0.1.0`. Reasoned in [`PLAN-05`](https://github.com/tusharsaxena/PanelMaster/issues/1) (also recorded as `ISS-01`, the same item), and bundled with the next live-client session. Screenshots of an unreleased UI would be re-taken before the first upload anyway. | 2026-08-05 | The first published release — the same change that uploads the package fills the section |
| `toc-file-§1` | `PanelMaster.toc` carries no `## X-Curse-Project-ID:`, and the README's badge row has four badges rather than five (no published-version badge). | Both are due **only once published**. A CurseForge project id does not exist until the first upload, so the field cannot be filled with a true value and would have to be filled with a placeholder or a lie. Reasoned in [`PLAN-03`](https://github.com/tusharsaxena/PanelMaster/issues/22) / [`PLAN-04`](https://github.com/tusharsaxena/PanelMaster/issues/23), which the audit bundle defines as one atomic change. | 2026-08-05 | The first CurseForge upload, which is what mints the project id — add the field and the badge in that same change |
| `events-frames-taint-§8` (the pre-formatting **SHOULD**) | Roughly 25 chat and slash lines build their text with `("…"):format(…)` or `..` before handing it to `NS.Print` — `settings/Slash.lua`, `settings/PanelEditor.lua`, `settings/Schema.lua` — rather than the preferred `print("count", n)` varargs form. | **The MUST does not engage here, and this was re-graded, not waived.** §8 scopes the MUST NOT to call sites whose arguments are, or derive from, a return of a named combat-protected API. This addon reads **none** of them: a whole-repo sweep of `core/ modules/ settings/ defaults/ locales/` for the trigger set (`UnitGetTotalAbsorbs`, `UnitGetTotalHealAbsorbs`, `UnitGetIncomingHeals`, `UnitHealth`, `UnitHealthMax`, `UnitThreatSituation`, `UnitDetailedThreatSituation`, the aura amount/`points` fields, `UNIT_AURA`) returns nothing, and the only unit/client APIs it calls at all are `UnitClass` and `C_AddOns.GetAddOnMetadata`. Every one of these lines formats values the addon owns — a panel name, a stored geometry field, a count it computed, a literal — so none can be handed a secret and the residue is the SHOULD, graded Info. Neither of §8's two unrelaxed points is touched: no site calls the global `print()` (every file takes `local print = NS.Print`), and the seam's guarantee is unconditional — `core/CoreSetup.lua` publishes the library's `IsConcatSafe` / `SafeToString` and builds the printer from `lib:New`, so every argument is stringified through the `table.concat` probe whatever a call site hands it. Converting the sites is therefore a readability change with no reachable behavior, and is declined at `0.1.0`. | 2026-08-05 | The first chat or debug line whose arguments include, or derive from, a return of any API in §8's trigger set — that site converts as a MUST, and an audit files it as one. Re-check also when §8's trigger list grows upstream. |
| `localization-§1` | No user-facing string routes through `NS.L`: every label, tooltip, slash line and message is hardcoded English. | `0.1.0` ships **English-only** — the second of the two terminal compliant states `localization-§3` names, not an open routing gap. Both MUSTs are met unconditionally: the `NS.L` seam is exported with the key-returning metatable fallback (`locales/enUS.lua:6`) and `enUS.lua` ships, so a later pass wraps strings without touching call sites. Reasoned at `locales/enUS.lua:8-14`. Panel **names** are user data and must never route through `NS.L`; neither must the stored `point` / `strata` tokens (`localization-§4`). | 2026-08-05 | The first non-English locale file added to `locales/` — that change routes the strings and retires this row |
| `line-endings-§5` | `.gitattributes` carries one extra block — `tools/artwork/bin/realesrgan-ncnn-vulkan binary` — so it is not byte-identical to the canonical client-bound body. | **Two MUSTs collide and only one can hold.** `line-endings-§4` requires every binary to be marked `binary`; `line-endings-§5` requires this file to match the canonical body byte-for-byte. The canonical list is an **extension** census, and this repo vendors an **extensionless** ELF executable (the Real-ESRGAN upscaler behind `tools/artwork/`), which no `*.ext` rule can ever match. Left unmarked it is the sole working-tree stray `line-endings-§7` reports for this addon — a real §4 failure, not a false positive, and one that would be re-filed every cycle. The block is scoped to the single path rather than a `tools/**` glob so it cannot silently swallow a future text file. Nothing about the pin, the `*.sh` carve-out or the shared binary list changes; the deviation is additive and comment-documented in the file itself. | 2026-08-07 | `line-endings-§4`/`§5` gaining any provision for extensionless or path-marked binaries upstream — at which point this block moves into the canonical body and the row retires. Re-check also if `tools/artwork/bin/` stops being vendored. |
| `documentation-§4` | Pending work lives in this repo's GitHub issues, which also function as a backlog, rather than in a root `TODO.md`. | `documentation-§4` forbids a `TODO.md` **once released**; it does not mandate one before. An issue is the better shape for the job — it records the *decision* and its rationale per item, with a re-surface rule, which a bare checklist cannot. The addon is pre-release, so the rule is not yet engaged. | 2026-08-05 | The first published release, which is when `documentation-§4` engages |
