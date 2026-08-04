# 01 — Current state (2026-08-04)

**Addon:** Ka0s Panel Master (`PanelMaster`), version `0.1.0` (TOC `## Version:`), unreleased.
**Repo HEAD at audit time:** `c73a636` — *"docs+i18n: adopt standard v2.17.1 — US English spelling throughout"*.
Working tree carries one untracked path, `docs/reviews/2026-08-03/` (a code-review bundle, not addon source).

---

## Standard audited against, and how it was obtained

**Ka0s WoW Addon Standard v2.17.1, dated 2026-08-03** (the version/date line at the top of
`standards/STANDARDS.md`).

**Provenance — network fetch, verified against the canonical checkout.** Contrary to the previous
run's experience, `curl` against `raw.githubusercontent.com` succeeded this time. Fetched with
`curl -fsSL --max-time 15`:

- `AUDIT.md` (the playbook) — the run is structured by it.
- `standards/STANDARDS.md` (the index) — its **Sections** list was followed rather than hard-coded.
- **All 24 section files** the Sections list links, fetched in parallel from
  `.../standards/standards/<file>.md`.

Every fetched file was then `diff`ed against the canonical checkout at
`/mnt/d/Profile/Users/Tushar/Documents/GIT/WowAddonStandards` (clean tree, HEAD `2141229` *"v2.17.1"*).
`diff -r` over the whole section directory, plus `diff` on `STANDARDS.md` and `AUDIT.md`, were all
**empty** — the raw URL and the checkout are byte-identical, so nothing in this audit rests on
reconstruction from memory. The standards repo was read only; nothing was written to it.

One apparent 24th/25th section, `tiered-layout.md`, 404s at the raw URL. It is **not** a live section:
the only occurrences of that filename in `STANDARDS.md` are inside frozen **changelog** entries
(v2.0.0 records its rename to `layout.md`, v1.5.0 and v1.2.0 quote the old name as history). The live
Sections list names 24 files, and all 24 were retrieved. **No section is unassessed.**

The 2026-07-30 audit in this repo was measured against **v2.11.0**; this run is the first against
v2.17.x, so several MUSTs below (the whole `performance` section, `documentation-§3`'s perf docs)
had no counterpart in the prior bundle.

---

## Layout (`layout`)

The modular layout is present and complete: `core/`, `defaults/`, `settings/`, `locales/`,
`modules/`, plus `libs/`, `media/`, `tests/`, `docs/`. Nothing loose at the repo root except the
sanctioned `README.md`, `CLAUDE.md`, `LICENSE`, `.luacheckrc`, `.pkgmeta` and `PanelMaster.toc`.

- `core/` — `Compat.lua`, `LSMPatch.lua`, `Constants.lua`, `Namespace.lua`, `State.lua`, `Util.lua`,
  `CoreSetup.lua`, `DebugLogSetup.lua`, `PanelMaster.lua`, `Database.lua`.
  **`core/PerfSetup.lua` does not exist** (see `02_DEVIATIONS.md` PM-001).
- `defaults/` — `Profile.lua`, `Global.lua`.
- `settings/` — `Schema.lua`, `Slash.lua`, `PanelEditor.lua`, `OptionsSetup.lua`, `Panel.lua`.
- `locales/` — `enUS.lua`, `PostLoad.lua`.
- `modules/` — `Registry.lua`, `Artwork.lua`, `SunnArtPacks.lua`, `SunnArt.lua`, `Canvas.lua`,
  `Unlock.lua`.

Casing is correct throughout (lowercase subfolders, `libs/` not `Libs/`, PascalCase `.lua`).
**No file exceeds 1500 LOC** — the largest authored source is `modules/Artwork.lua` at 1087 and
`settings/PanelEditor.lua` at 1064, both inside the 1000–1500 "on notice" band and neither a bug.

`media/` uses typed subfolders only — `media/logos/`, `media/fonts/`, `media/artwork/…`,
`media/poster/` — with nothing loose at its root (`layout-§3`).

## TOC (`toc-file`)

`PanelMaster.toc:1-12` carries the metadata block in the exact mandated field order (Interface,
Title, Notes, Author, Version, IconTexture, SavedVariables, OptionalDeps, DefaultState,
Category-enUS, X-License, X-Standard), no blank lines inside the block, single latest-Retail
`## Interface: 120007`, `X-License: MIT`, `X-Standard:` present. `X-Curse-Project-ID` is absent —
correctly, since the addon is not published (`toc-file-§1` makes it a MUST *once published*).

The file listing (`:14-78`) is `#`-sectioned in the mandated order **Libraries → Locales → Core →
Defaults → Modules → Settings**, every library listed directly (no `embeds.xml`), `libs\LibKa0s\LibKa0s.xml`
listed **once** as the single aggregate after Ace3 (`:29`), and the file ends with a single trailing
newline (verified with `tail -c 1 | xxd` → `0a`).

`## SavedVariables: PanelMasterDB` (`:7`) declares **one** global. The standard requires **two**
(`toc-file-§2`, `savedvariables-§4`) — `PanelMasterPerfDB` is missing (PM-003).

## Library stack (`library-stack`)

All eight mandatory libs plus LibSharedMedia-3.0, AceDBOptions-3.0, AceConfig-3.0 (for the Profiles
sub-page) and AceGUI-3.0-SharedMediaWidgets are vendored under `libs/` and committed. `.pkgmeta`
declares no `externals:`. No Ace lib is forked; the one third-party widget fixup
(`core/LSMPatch.lua`) sits in **addon code**, not in `libs/`, and extends through
`AceGUI:RegisterWidgetType` at `currentVer + 1` (`core/LSMPatch.lua:44,65`) — the sanctioned
mechanism (`library-stack-§5`).

`libs/LibKa0s/` holds the **whole** ship folder — all eight files of the five majors
(`Core.lua`, `DebugLog.lua`, `Slash.lua`, `Options.lua`, `OptionsWidgets.lua`, `OptionsScroll.lua`,
`Perf.lua`, `PerfPanel.lua`) plus `LibKa0s.xml` and `LICENSE` — including the two `Perf` files the
addon does not wire, which is exactly what `library-stack-§7` requires. The vendored test kit sits at
`tests/_kit/`, **not** under `libs/`.

**Vendor-sync diffs were run and are both empty** (see `03_EVIDENCE.md`) — no `#45` drift, no `#48`
partial vendoring.

## Architecture (`architecture`)

Every authored file opens `local addonName, NS = ...`; there is **no** `_G[addonName]` assignment
anywhere. `core/PanelMaster.lua:4` passes `NS` as the first argument to `:NewAddon`, and `:13`
reclaims `NS.Print` from AceConsole's `:Print` mixin via `NS.Util.print` — the `architecture-§2`
fix, pinned by a test. Modules publish idempotently (`NS.X = NS.X or {}`).

The message bus is closed and documented: three messages, `Ka0s_PanelMaster_SettingsChanged`
(sole sender `settings/Schema.lua:20`), `Ka0s_PanelMaster_PanelsChanged` and
`Ka0s_PanelMaster_PanelChanged` (sole sender `modules/Registry.lua:19-20`), each with sender/payload/
consumers tabulated in `docs/ARCHITECTURE.md:279-309`. `NS.NewBusTarget()`
(`core/PanelMaster.lua:20-26`) gives each receiver its own AceEvent embed, and `modules/Canvas.lua:705`
registers on that target rather than on the shared bus — `architecture-§4` / anti-pattern #32.

Schema-as-single-source is fully realized: `settings/Schema.lua:27-98` is the one row table, `S:Set`
(`:132-147`) is the single write seam, and boot validation walks every row against the defaults
(`:163-174`).

## SavedVariables (`savedvariables`)

`core/Database.lua:18` creates `PanelMasterDB` through AceDB with the shared "Default" profile.
`schemaVersion` lives in `global` (`NS.SCHEMA_VERSION = 2`, `core/Namespace.lua:14`) and a real
migration runner ships at `core/Database.lua:84-116` with a v1→v2 body. The diagnostics carve-out
`PanelMasterPerfDB` is **not** present (PM-003).

## Options UI (`options-ui`)

`settings/OptionsSetup.lua` is the seam: `LibStub("LibKa0s-Options-1.0", true)` at `:26`, the
descriptor at `:63-132` with `parentTitle`, `mainPanelName`, the `NS.Schema:Set` write seam, and the
`NS.Helpers = lib:New(...)` instance published **as** the library instance rather than a copy.
Each omitted descriptor field carries a written reason (`:112-131`). The library-absent branch
(`:28-61`) is the **load-completing** stub the standard documents as the one sanctioned exception —
it publishes `LSMValues` returning a closure over an empty table and no-ops the rest — and it answers
every member `settings/Panel.lua` and `settings/PanelEditor.lua` reach at file scope. Category
registration is eager (`core/PanelMaster.lua:37` plus a `PLAYER_LOGIN` retry at `:51-53`); the
combat refusal is the library's, reached at `settings/Panel.lua:488`.

## Slash commands (`slash-commands`)

`settings/Slash.lua` builds one dispatcher from `LibKa0s-Slash-1.0` (`:271,307-348`), registers
through AceConsole `:RegisterChatCommand` for `/pm` and `/panelmaster` (`:23-24`), and keeps
`NS.COMMANDS` (`:202-255`) as host-owned positional triples. `NS.PREFIX = "|cff00ffff[PM]|r"`
(`core/Namespace.lua:19`) is the mandated cyan tag. Reserved verbs present: `help`, `get`, `set`,
`list`, `reset`, `resetall`, `config`, `version`, `debug`. **`perf` is absent** (PM-002).

## Debug console (`debug-logging`)

`core/DebugLogSetup.lua` is the seam: guarded `LibStub("LibKa0s-DebugLog-1.0", true)` at `:79`, the
descriptor at `:127-182` with `name`/`title`/`font`/`isEnabled`/`setEnabled` and call-time forwarders
for `print` and `initSummary`, the bare sink bound at `:189`, and each not-passed field explained at
`:163-181`. The library-absent stub (`:81-125`) answers all eight members the addon calls, still
flips `NS.State.debug` and still prints the ack. The addon owns no console window, no formatter and
no buffer. The monospace font ships at `media/fonts/JetBrainsMono-Regular.ttf` with `OFL.txt`
(`core/Constants.lua:568`) — the sanctioned styling exception.

## Performance (`performance`)

**Entirely unadopted.** No `core/PerfSetup.lua`, no `NS.Perf`, no `perf` verb, no `PanelMasterPerfDB`,
no suspend/resume contract, no `tests/perf.lua`, no `docs/performance.md`, no `docs/perf-runs/`.
The `Perf` files *are* vendored (correctly — whole folder). The non-adoption is a recorded decision:
`CLAUDE.md:34` states *"`Perf` is declined"* and `docs/pending/LEDGER.md:117` (LIBKA0S-31) carries the
reasoning at length. The standard makes the **wiring** a MUST regardless, so it is catalogued —
see PM-001, PM-002, PM-003, PM-004, PM-005, PM-006, PM-012.

## Testing (`testing`)

`tests/_kit/` is the vendored kit (byte-identical, proven below); `tests/wow_mock.lua` is a thin
extender over `mock_base.lua`; `tests/run.lua` derives the addon's load list from the TOC. **696
cases, 0 failures.** `docs/test-cases.md` is generated and totals 696, matching the README badge
`Tests-696%2F696_passing`. The suite carries its own vendor-sync gate (`tests/test_vendor_sync.lua`)
and a spelling gate (`tests/test_spelling.lua`).

## Docs, lint, packaging, versioning

`docs/` ships the canonical trio (`ARCHITECTURE.md`, `testing.md`, `smoke-tests.md`) plus
`test-cases.md` and topic-detail docs. There is **no** `docs/agent-context.md` and `CLAUDE.md:44-59`
explicitly forbids re-creating it (anti-pattern #49 — clean). `CLAUDE.md` is a stub carrying the
verbatim `## Standards compliance (read first)` section. `.luacheckrc` and `.pkgmeta` are present and
close to the templates; `luacheck .` is 0/0. `docs/audits/2026-07-30/` and `docs/reviews/2026-07-30/`
are retained unedited.

## Not applicable

- `standalone-windows` — the addon draws **no** window of its own. Its only floating window is the
  debug console, which is `LibKa0s-DebugLog-1.0`'s frame, skinned from Core's `SKIN` with Core's
  close glyph (both hooks deliberately not overridden, `core/DebugLogSetup.lua:163-175`).
- `public-api` — nothing is exposed; there is no `NS.API` and no `_G[addonName]`.
- `preview-mode` — satisfied: `/pm preview` and the `state.preview` schema row drive three sample
  panels through the real render path (`settings/Schema.lua:43-48`, `NS.Unlock:SetPreview`).
</content>
</invoke>
