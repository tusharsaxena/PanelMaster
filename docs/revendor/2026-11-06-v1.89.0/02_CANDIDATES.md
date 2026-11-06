# Candidates, v1.85.0 -> v1.89.0

Sources: `git -C ../LibKa0s log --oneline v1.85.0..v1.89.0` (27 commits), the tag's `CHANGELOG.md`
blocks v1.86.0 (`:82`), v1.87.0 (`:58`), v1.88.0 (`:35`) and v1.89.0 (`:13`), and the `docs/api/`
documents of every major whose minor moved.

## Class A: delivered on the re-vendor, not offered

- **DebugLogDiagnostics 6 -> 7** (v1.86.0). The `LibKa0s running:` report line lists IconBrowser when it
  runs. "No member change" (`docs/api/DebugLog/version-22.7.1.4-docs.md:21`). The addon's `/pm`
  diagnostics report carries it for free; no suite pins minor 6.
- **Kit 50 -> 51** (v1.89.0). `mock_ace.lua`'s unregister clears only a registration that exists, as
  CallbackHandler does (`docs/api/testkit/version-51-docs.md:23-25`). A flake fix under the headless suite.
- **Widgets 22 -> 23** (v1.87.0), for the flat menus the library itself opens (the sim strip's
  right-click, `Widgets.lua`'s `W.TestStrip`): "Flat menus draw what 22 drew"
  (`docs/api/Widgets/version-23.5.12.6.7.5-docs.md:36`). PanelMaster has no sim, so nothing visible moves.

## Class B: host change required

- **Widgets 23 `submenu` / `radio` / `selected` / `opts.check` on `W.ContextMenu`**
  (`docs/api/Widgets/version-23.5.12.6.7.5-docs.md:27-29`). **Not applicable**: PanelMaster opens no
  `W.ContextMenu` (`grep -rnE 'Widgets|ContextMenu' core settings modules` finds only a comment at
  `settings/OptionsSetup.lua:130`). Blast radius: none. Recommendation: record, no issue.
- **Toast 4 stack** (`SetStack`, `Visible`, `FrameFor`; `docs/api/Toast/version-4-docs.md:26-32`).
  **Not applicable**: PanelMaster looks up no Toast major (3e) and has no toast stub, so no stub is owed.
  Recommendation: record, no issue.

## Class C: whole-module adoption

- **`LibKa0s-IconBrowser-1.0`** (v1.86.0; `docs/api/IconBrowser/version-1.1.1-docs.md`). A browser over
  the icon catalogs, for an addon whose UI lets the player choose an icon. PanelMaster has no icon
  chooser: its icons are a closed list of twelve chrome marks (`CLAUDE.md:59`), resolved through
  `NS.Icon` (`core/MediaSetup.lua:57`). Adopting it would be additive but has no surface to serve.
  Recommendation: settled, no issue (owner ruling).
