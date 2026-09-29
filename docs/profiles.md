# Profiles

Panel Master stores its panels in **AceDB profiles**. Every character starts on the shared
**"Default"** profile (`core/Database.lua:19`), so one layout follows the player to their alts until
a character is given a profile of its own, and profile management is its own settings page. That
makes profiles a first-class part of the addon's behavior rather than an AceDB detail.

## Where profiles sit in the data model

`defaults/Profile.lua` carries the profile defaults — the (empty) panel registry, `nextID`, and the
settings block. `defaults/Global.lua` declares `schemaVersion = 0`, the migration runner's floor
(the runner writes the real stamp), and LibDBIcon's `minimap` table. `core/Database.lua` opens
AceDB on the shared **"Default"** profile and owns the profile-change callbacks.

The split is deliberate: a panel layout is tied to a character's UI, so it belongs to a profile; the
schema stamp describes the saved file itself, so it belongs to `global` and must not fork per
profile.

## Switching a profile

A profile change is not a settings change — the entire panel **set** is different afterwards. The
callbacks in `core/Database.lua` therefore drive a full registry reload and a
`Ka0s_PanelMaster_PanelsChanged` broadcast, which rebuilds every consumer, rather than any targeted
repaint. See [data-flow.md](data-flow.md).

`NS:SweepPreviewPanels` runs on the same path: an older build's test mode wrote sample panels into
the profile, and a profile still carrying them from an interrupted session must not resurrect them
as real panels. The handler also refreshes an open General page in place (`options-ui-§11`), which
only a switch from chat can reach, since a Profiles-page switch never has that page on screen.

## Switching from chat: `/pm profile`

`/pm profile` lists the stored profiles, sorted without regard to case, with the current one marked
`(current)`. `/pm profile <name>` switches to an **existing** profile: one pair of surrounding quotes
is stripped, and case and inner spaces are kept, so `/pm profile "Raid Night"` works and
`/pm profile raid night` does not. An unknown name is refused with the list (and the one near match,
if exactly one differs only by case), and is **never created**; making a new profile stays a
Profiles-page act. A switch is refused in combat, and switching to the profile already in use says
so and does nothing.

The verb is `LibKa0s-Slash-1.0`'s `CliProfile` (Slash minor 17) behind this addon's own row, and the
switch it makes is AceDB's `SetProfile`, so it runs the same callbacks as the Profiles page above,
including the one `[Profile]` debug line. It answers while the addon is **disabled**, because a
player who turned the addon off on one profile may want to switch to one where it is on. On a
library-absent install it prints `/pm profile is unavailable: the LibKa0s library did not load.` and
switches nothing. Dispatch detail in [slash-dispatch.md](slash-dispatch.md).

## The Profiles page

Rendered from **AceDBOptions'** own options table by `AceConfigDialog`, into a container parented to
the addon's canvas. This is the **one** place `AceConfigDialog` is used, and it is a deliberate
exception rather than an oversight — see [settings-panel.md](settings-panel.md) for why `anti-patterns`
forbids it for content and permits it here.
