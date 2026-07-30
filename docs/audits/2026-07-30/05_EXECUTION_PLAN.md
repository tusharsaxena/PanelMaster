# 05 — Execution Plan (2026-07-30)

Ordered steps to take Ka0s Panel Master from this scaffold to a published `v0.1.0`. Nothing here is
a compliance repair to existing code — the addon is born compliant — so every step is an addition.

Green gate applies throughout: `lua tests/run.lua` and `luacheck .` must both be clean before any
commit.

## Step 0 — Roster registration *(standards repo, not this one)*

Add the Panel Master row to `WowAddonStandards/standards/ADDONS.md`. This is the one edit that brings
the addon into scope for the next standards refresh, and it lives in a **different repository**.

**Status: not done.** The scaffold run had no write access to `WowAddonStandards`. Suggested row:

```markdown
| PanelMaster | Ka0s Panel Master | Backdrop panels drawn behind the UI for visual grouping. | 0.1.0 | /pm |
```

Match the column shape of the existing rows in that file, which may have moved since.

## Step 1 — Run the smoke tests

> **✅ Done.** The smoke tests were run in a live client and passed. Note the page has grown a great
> deal since this plan was written — it now also covers LibSharedMedia textures, the colour pickers,
> border offset, the accent bar and its border, frame-name anchoring, profiles and copy-settings —
> so re-run it after any further change to the render path or the settings page.

[`docs/smoke-tests.md`](../../smoke-tests.md) had **never been executed** at the time this plan was
written — nothing in the addon had been run in a live client. Thirteen sections, roughly twenty minutes.

Pay particular attention to, because they are the parts the headless harness genuinely cannot reach:

- **§6 Layering** — a `BACKGROUND` panel must never intercept a click, a keybind or a tooltip. This
  is the addon's core promise.
- **§9.2 The Defaults button** — it must render in the standard dark/gold style, not Blizzard's red
  stone. Red means the lazy-creation fix regressed (`options-ui-§5`, anti-pattern #42).
- **§11.5 The console scrollbar** — drag and wheel must stay in sync with no Lua error. The old C
  getters are nil on the mixin and would raise (`debug-logging-§11`).
- **§5.2 Border corners** — the four edges must meet cleanly, which only shows with a translucent
  border.

Fix anything found **test-first**: add the failing headless case where the logic is testable, and
extend the smoke-test page where it is not.

## Step 2 — Logo art

Produce `media/logos/panelmaster.logo.tga` (512×512, 24-bit RLE) per
[04_TECHNICAL_DESIGN.md](04_TECHNICAL_DESIGN.md) ▸ D-003. Verify on the settings landing page — a
missing or wrongly-formatted file renders nothing and raises no error, so it must be checked by eye.

Closes **D-003**.

## Step 3 — Tag v0.1.0 and publish

1. Walk the Definition of Done at the bottom of [`docs/agent-context.md`](../../agent-context.md).
2. Commit to the default branch (trunk-based; no feature branch unless asked).
3. Tag `v0.1.0`.
4. Upload to CurseForge and note the project id.

## Step 4 — Close the publishing deviations

In **one** change, immediately after the upload:

- Add `## X-Curse-Project-ID: <id>` to the TOC (**D-001**).
- Add the `curseforge/v/<id>` badge as the second README badge (**D-002**).
- Capture the five screenshots, upload them, and replace the README placeholder (**D-004**).
- Add the logo image under the README title from its CDN URL (**D-005**).

That clears every open item in [02_DEVIATIONS.md](02_DEVIATIONS.md).

## Step 5 — Ongoing

- `wow-addon:bump-interface` every patch — and update the README `[wow]` badge in the **same** change
  (`toc-file-§3` lockstep).
- `wow-addon:bump-version` for releases — it rolls `## What's new`, the Version History row and every
  version constant together.
- Regenerate `docs/test-cases.md` and update the `[tests]` badge in the **same** change as any suite
  change (`testing-§5`).
- Re-run `wow-addon:standards-audit` after any significant feature, and whenever the standard bumps.
  The next audit compares against this bundle.
- Backlog lives in **GitHub issues**, not a `TODO.md` (`documentation-§4`).

## Deferred features (not compliance work)

Recorded so they are not mistaken for gaps: per-panel texture selection (the `Compat.FetchTexture`
seam exists), a per-panel strata *level* control in the UI, and panel-name handling for names with
spaces at the CLI. See `ARCHITECTURE.md` ▸ Known limitations.
