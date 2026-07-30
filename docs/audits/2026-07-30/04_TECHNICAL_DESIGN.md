# 04 — Technical Design (2026-07-30)

What would have to change to close the open deviations in
[02_DEVIATIONS.md](02_DEVIATIONS.md). All five are publishing and art tasks; none needs a code
change beyond adding lines.

## D-001 / D-002 — CurseForge project id and version badge

Both wait on the same fact: a CurseForge project id, which does not exist until the addon is
uploaded once.

**`PanelMaster.toc`** — insert after `X-Standard`, keeping the metadata block's declared field order
(Curse → Wago → WoWI):

```
## X-Curse-Project-ID: <id>
```

`X-Wago-ID` and `X-WoWI-ID` stay omitted: they are `MAY` as of standard v2.8.0, and the collection
distributes through CurseForge only.

**`README.md`** — insert the published-version badge as the **second** badge, between `[wow]` and
`[license]`, per `documentation-§1`'s fixed order:

```markdown
![CurseForge Version](https://img.shields.io/curseforge/v/<id>)
```

This is the one **live** badge in the row and needs no upkeep afterwards.

## D-003 / D-005 — the logo

`core/Constants.lua` already points `C.LOGO_PATH` at
`Interface\AddOns\PanelMaster\media\logos\panelmaster.logo.tga`, and `settings/Panel.lua` requests it
at 300px on the landing page. Only the file is missing.

Requirements, mirroring the sibling addons:

- **Runtime asset: `media/logos/panelmaster.logo.tga`**, 512×512, 24-bit RLE TGA. The dimensions
  must be a power of two — the client rescales anything else — and WoW cannot load `.jpg`/`.png` at
  runtime at all. A missing file renders nothing and raises **no error**, which is exactly how a
  sibling addon shipped a blank landing page for a while, so treat the `.tga` as required rather
  than optional.
- **Source art**: keep the master alongside it (`.png`, square, ≥1024×1024).
- **README image**: a `.jpg` uploaded to the CurseForge CDN at first publish, linked under the title
  as `![Logo](https://media.forgecdn.net/…)`.

No code change: the path is already wired and the texture call already tolerates absence.

## D-004 — screenshots

Capture in a live client once panels are placed, into `media/screenshots/` as
`panelmaster.screenshot.NN.png`. `.pkgmeta` already excludes that folder from the player payload —
they are project-page art served from the CDN, never downloaded by a player.

Worth showing, in this order:

1. A finished UI with two or three panels doing their job (the "why" shot).
2. The same screen with `/pm unlock` on — outlines and name labels visible (the "how" shot).
3. The **Panels** settings page with a couple of editors expanded.
4. The **General** settings page.
5. The debug console with a few `[Panel]` lines in it.

Then replace the placeholder note in the README's `## Screenshots` section with the CDN links.

## Sequencing

D-003 (logo `.tga`) is independent and can be done now. D-001, D-002, D-004 and D-005 all depend on
the first CurseForge upload and should be done together, in one change, immediately after it — which
is also when the `[wow]` and `[tests]` badges get their first routine re-check.

## Explicitly not planned

- **Texture selection per panel.** `Compat.FetchTexture` and `C.DEFAULT_TEXTURE` are already the
  seam for it, and LibSharedMedia is already vendored, but exposing a texture dropdown is a feature
  for a later version, not a compliance gap.
- **Automatic off-screen recovery at login.** Deliberately absent — see A-003.
- **A CI workflow.** Out of scope for the collection by standing decision (`testing-§5`); the gate is
  local and hand-run.
