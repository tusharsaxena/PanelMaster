# 02 — Deviations (2026-07-30)

Measured against **Ka0s WoW Addon Standard v2.11.0**. The addon was built to the standard from the
first file rather than retrofitted, so this list is short by construction — but it is not empty, and
nothing below is hidden.

## Open items

| # | Rule | Deviation | Severity | Why it is open |
|---|---|---|---|---|
| D-001 | `toc-file-§1` | No `## X-Curse-Project-ID:` line. | **None yet** | The field is a MUST *once published on CurseForge*. There is no project yet, so a line would be a placeholder. Add it with the id at first publish. |
| D-002 | `documentation-§1` | The README badge row has **four** badges, not five: the published-version badge (`curseforge/v/<id>`) is absent. | **None yet** | Same cause as D-001 — the badge template needs a project id. A badge pointing at a non-existent project renders as an error. Added alongside D-001. |
| D-003 | `options-ui-§6` / `layout-§3` | `media/logos/panelmaster.logo.tga` does not exist. `C.LOGO_PATH` points at it and the settings landing page requests it. | **Low** | A missing texture renders nothing and raises no error, so the landing page is simply logo-less today. Art is an authoring task, not a code one. |
| D-004 | `documentation-§1` | The README's `## Screenshots` section carries a placeholder note rather than images. | **Low** | Screenshots require a live client with panels placed. Captured at first release; `.pkgmeta` already excludes `media/screenshots` from the player payload. |
| D-005 | `documentation-§1` | The README has no logo image under the title. | **Low** | Depends on D-003 and on the CurseForge CDN URL, which does not exist until first publish. |

## Accepted, documented decisions

Not deviations — deliberate choices the standard permits, recorded so a later audit does not raise
them as findings.

| # | Decision | Rationale |
|---|---|---|
| A-001 | **Per-character** AceDB profile (`:New(name, defaults)` with no `defaultProfile`), where the sibling collection addons are account-wide. | A panel layout belongs to the UI a given character runs. `savedvariables` does not mandate a scope; AceDB's profile machinery still lets a user copy one layout to an alt. |
| A-002 | Panel records live outside the settings Schema. | `architecture-§5` storage carve-out — the same shape as the sibling addon's id-lists and window geometry. A panel is a variable-length user object, not a fixed setting with a widget. Its single write seam is `Registry:Set`. |
| A-003 | Panel offsets are **not** clamped to the screen on write. | A multi-monitor layout legitimately carries large offsets; clamping on write would destroy it on the first lower-resolution login. Recovery is the explicit, opt-in `Registry:Recover`. |
| A-004 | `NS.State.unlocked` and `NS.State.preview` are session-only and never persisted. | Unlock is an editing state, not a preference. Persisting it means logging in to a screen full of drag handles. Mirrors the `debug-logging-§5` treatment of the debug flag. |
| A-005 | Panels are drawn with a background texture plus four edge textures rather than a `BackdropTemplate` backdrop. | A backdrop's `edgeSize` is tied to the edge file's geometry and renders wrong at the arbitrary border widths this addon exposes. |
| A-006 | The vendored JetBrains Mono font ships despite the Blizzard-default-font styling rule. | Sanctioned styling exception (`debug-logging-§2`) — the console's aligned columns require a fixed-width font and WoW ships no monospace font object. |
| A-007 | Only `BACKGROUND`, `LOW`, `MEDIUM` and `HIGH` strata are offered. | Anything at `DIALOG` or above covers normal UI, which is the opposite of what a backdrop is for. Asserted by test. **⚠ Superseded later the same day** at the user's request: all eight strata are now offered and the default moved from `BACKGROUND` to `LOW`. "Which layer" is a judgement about the user's own UI; the tooltip warns that `DIALOG` and above cover normal UI rather than the list hiding the option. See `ARCHITECTURE.md`. |
| A-008 | `/pm rename` and `/pm panel` address a panel by its **first word** only. | A two-name command line has no unambiguous split for names with spaces, and inventing a quoting syntax for a job the settings UI already does well was judged the worse trade. Recorded in `ARCHITECTURE.md` ▸ Known limitations and in the README's Troubleshooting section. |

## Confirmed compliant

Spot-checked, and in most cases pinned by a test that fails if it regresses:

- Single latest-Retail `## Interface:`; fixed TOC field order; `#`-sectioned file listing;
  `X-Standard` present (`toc-file-§1/§3/§5`).
- Every file opens `local addonName, NS = ...`; no `_G[addonName]`.
- MIT `LICENSE`; `X-License: MIT`.
- All libs vendored and committed, listed directly in the TOC; **no** `embeds.xml`; no `externals:`
  in `.pkgmeta` (`library-stack-§3`, `toc-file-§4`, anti-pattern #38).
- AceConsole `:RegisterChatCommand`; no raw `SLASH_*`; dispatch from a `COMMANDS` table, not an
  `if/elseif` chain.
- `NS.Print` reclaimed after the AceConsole embed (`architecture-§2`, anti-pattern #36) — **tested**.
- Secret-safe stringifier probing `table.concat`, not `..` (`events-frames-taint-§8`).
- Mandatory cyan `[PM]` tag on every line; the `slash-commands-§5` colour scheme and indentation; no
  trailing colons — **tested**.
- Required verbs `config version get set list reset resetall debug help` — **tested**.
- Locale metatable fallback; no AceLocale strict mode; stable tokens matched, never localized
  strings (`localization-§1/§4`).
- Every deprecated / varying API in `Compat`; **no** `WOW_PROJECT_ID` branching — **tested**.
- Frame pool for the dynamic panels (`hard rule #14`) — **tested** across ten create/delete cycles.
- Migration runner present and idempotent; `schemaVersion` sourced once from `NS.SCHEMA_VERSION`
  (`savedvariables-§1`) — **tested**.
- Debug console with scrollbar and `N / MAX lines` counter, using the Lua `ScrollingMessageFrameMixin`
  API and never the nil C getters (`debug-logging-§11`).
- One settings mutation logged once at the write seam (`debug-logging-§10`).
- Preview mode present for a positionable display (`preview-mode`) — **tested**.
- Root = full `README.md` + **stub** `CLAUDE.md` + `LICENSE`; the `docs/` quartet plus the generated
  `test-cases.md`.
- The four-place standards reference (`documentation-§6`): TOC `X-Standard`, README badge, the
  `CLAUDE.md` "Standards compliance (read first)" section, and `agent-context.md`'s opening
  `## Hard rules` bullet.
- No `TODO.md` (`documentation-§4`).
- No file over 1500 LOC — the largest is `settings/Panel.lua` at 657; 2,957 lines of addon source in
  total.
