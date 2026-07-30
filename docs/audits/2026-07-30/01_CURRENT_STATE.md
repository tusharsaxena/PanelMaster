# 01 — Current State (2026-07-30)

**Scaffold audit.** Ka0s Panel Master was created on 2026-07-30 by `/wow-addon:new-addon`, built to
the **Ka0s WoW Addon Standard v2.11.0** with **context pack v2.7.0**, both fetched from
`WowAddonStandards` at scaffold time. This is the born-compliant baseline every later audit compares
against.

## Identity

| | |
|---|---|
| Folder / addon name | `PanelMaster` |
| TOC Title | `Ka0s Panel Master` |
| Version | 0.1.0 |
| Interface | 120007 (single, latest Retail) |
| SavedVariables | `PanelMasterDB` |
| Slash | `/pm`, alias `/panelmaster` |
| Chat tag | `\|cff00ffff[PM]\|r` |
| Author / License | add1kted2ka0s / MIT |
| Substrate | Ace3 |

## What it does

Creates user-defined backdrop panels — coloured rectangles with a border, size, position and layer —
drawn behind the rest of the UI as a visual grouping device. It hosts nothing and touches no other
frame. Conceptually a kgPanels / ElvUI-panels equivalent.

## Layout

The single modular layout, in TOC load order:

```
PanelMaster.toc
core/       Compat, Constants, Namespace, State, Util, PanelMaster, Database
defaults/   Profile, Global
locales/    enUS, PostLoad
modules/    Registry, Canvas, Unlock, DebugLog
settings/   Schema, Slash, Panel
libs/       9 vendored libraries
tests/      run, loader, wow_mock, 11 suites
docs/       agent-context, ARCHITECTURE, testing, smoke-tests, test-cases, audits/
media/      fonts/ logos/ screenshots/
README.md   CLAUDE.md   LICENSE   .luacheckrc   .pkgmeta
```

## Vendored libraries

Copied from the sibling Ka0s addon `BankLedger` so versions stay consistent across the collection
(`library-stack-§3`). All committed; none fetched as `.pkgmeta` externals.

`LibStub`, `CallbackHandler-1.0`, `AceAddon-3.0`, `AceEvent-3.0`, `AceTimer-3.0`, `AceConsole-3.0`,
`AceDB-3.0`, `AceGUI-3.0`, `LibSharedMedia-3.0`.

LibSharedMedia is an `OptionalDeps` soft dependency — `Compat.FetchTexture` degrades to a flat colour
fill when it is absent, and the headless mock deliberately omits it so that path is the tested one.

## Green gate

| Check | Result |
|---|---|
| `lua tests/run.lua` | **237 passed, 0 failed** |
| `luacheck .` | **0 warnings, 0 errors** in 18 files |
| `docs/test-cases.md` | generated, 237 cases, in sync |
| README `[tests]` badge | `237/237`, in sync |

## Architecture summary

- **Schema-as-single-source** — one `S.Schema` table drives the AceDB defaults check, the panel
  widgets and the slash `get/set/list/reset`. One write seam (`Schema:Set`).
- **Panel records are a storage carve-out** (`architecture-§5`) — variable-length user-created
  objects with no fixed widget, owned by `NS.Registry` with its own single write seam (`Registry:Set`).
- **Closed message bus** — three `Ka0s_PanelMaster_*` messages, one sender each, consumers on their
  own `NS.NewBusTarget()` targets. Asserted by test.
- **Non-secure frames only** — no taint surface; the render path is not combat-gated.
- **Combat**: unlock defers and replays (`events-frames-taint-§2`); the options panel refuses without
  replaying (`options-ui-§2`). Both asserted by test.
- **Options UI**: eager category registration, lazy body, lazy Defaults button (`options-ui-§1/§5`,
  anti-pattern #42). All three asserted by test.
- **Debug console**: on-screen, monospace, scrollbar + line counter (`debug-logging-§11`),
  session-only logging flag decoupled from window visibility, `[Init]` summary on enable, `dump`
  structured-dump verb.
