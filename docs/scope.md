# Scope

What Panel Master is for, and — the load-bearing half — what it deliberately is not for.

## In scope

A backdrop-panel creator, in the lineage of kgPanels and ElvUI's panels. The user creates named
rectangles with a color, a border, a size, a position and a layer, and the addon draws them behind
the rest of the UI. That is the whole product.

**It does not host anything.** A panel is not a container: nothing is reparented into it, no other
addon's frames are moved, and no Blizzard frame is touched. It is scenery — a visual grouping cue
behind frames that stay exactly where their own addons put them. This constraint is why the addon
needs no secure frames, no combat gating on its render path, and no taint story.

## Explicitly out of scope

Each of these is a decision that would still hold tomorrow, not a gap waiting to be filled.

- **Hosting frames.** A panel is not a container. Nothing is reparented into it, no other addon's
  frames are moved, and no Blizzard frame is touched. This single constraint is what buys the addon
  no secure frames, no combat gating on the render path, and no taint story — so anything that would
  make a panel a parent gives all three back.
- **Shipping Sunn pack bytes.** `modules/SunnArt.lua` is a **discovery adapter** for user-installed
  *Sunn - Viewport Art* packs: it reads another addon's globals and synthesizes catalog rows. It
  draws nothing and ships no pack content.
- **Editing the vendored library.** `libs/LibKa0s/` is whole-folder vendored and never edited here. A
  library problem is fixed in `../LibKa0s` and re-vendored, because the next re-vendor silently
  reverts a local edit and the revert reads as a regression with no cause anywhere in this history.
- **`AceConfigDialog` for content.** It is used in exactly one place — the Profiles page, rendering
  AceDBOptions' own table. See [settings-panel.md](settings-panel.md).
- **Quoting syntax at the CLI.** `/pm rename` and `/pm panel` take the name as the first word, so a
  panel called "Chat BG" can be created and renamed *to*, but not addressed by its full name from the
  command line. Inventing a quoting syntax for a job the settings UI already does well was judged the
  worse trade.
- **Login-time off-screen recovery.** `/pm recover` is manual and never runs at login: a panel
  deliberately parked mostly off-screen is a legitimate layout, and a login-time sweep would silently
  rearrange it.
- **Per-target class color.** The class-color flag reads `UnitClass("player")`. There is no "color by
  target's class" and no per-panel override.

## Known limitations (current, not decisions)

- **Panel names with spaces are awkward at the CLI.** `/pm rename` and `/pm panel` take the name as
  the first word, so a panel called "Chat BG" can be created and renamed *to*, but not addressed by
  its full name from the command line. Inventing a quoting syntax for a job the settings UI already
  does well was judged the worse trade.
- **A renamed panel's frame name no longer matches its name.** The frame name is stamped at create
  and is identity from then on, so a rename cannot break an anchor — but it also cannot be worked
  out from the panel's current name. The name box's tooltip shows it. This is the deliberate half of
  the trade described in *Frame names and the pool*, not an oversight.
- **A panel name can be refused because a renamed panel still holds its frame name.** Creating
  "Alpha" fails while a panel created as "Alpha" and since renamed still carries
  `PanelMaster_Panel_Alpha`. The refusal names the holder. Refusing is correct — two frames cannot
  share a global — but the reason is not obvious from the panel list.
- **No per-panel strata *level* UI.** `level` is in the record and settable from the CLI, but the
  settings page exposes only the strata dropdown. Two panels sharing a strata *and* a level are
  ordered by frame creation, which the name-keyed pool does not keep in panel order; distinct
  levels order cleanly (see *Panel levels are strided*).
- **The mouseover fade is a hard cut, not a smooth fade.** Alpha snaps between the two values at the
  10Hz poll. An animated transition is a natural refinement.
- **Class color is the player's own class only.** There is no "color by target's class" or
  per-panel class override; the flag reads `UnitClass("player")`.
- **`/pm recover` is manual.** It never runs at login, because a panel deliberately parked mostly
  off-screen is a legitimate layout and a login-time sweep would silently rearrange it.
