# Profiles

Panel Master stores its panels **per character**, through AceDB profiles, and surfaces profile
management as its own settings page. That makes profiles a first-class part of the addon's behavior
rather than an AceDB detail.

## Where profiles sit in the data model

`defaults/Profile.lua` carries the per-character defaults — the (empty) panel registry, `nextID`, and
the settings block. `defaults/Global.lua` carries the one account-wide value, the `schemaVersion`
stamp. `core/Database.lua` opens AceDB on the shared **"Default"** profile and owns the
profile-change callbacks.

The split is deliberate: a panel layout is tied to a character's UI, so it belongs to a profile; the
schema stamp describes the saved file itself, so it belongs to `global` and must not fork per
profile.

## Switching a profile

A profile change is not a settings change — the entire panel **set** is different afterwards. The
callbacks in `core/Database.lua` therefore drive a full registry reload and a
`Ka0s_PanelMaster_PanelsChanged` broadcast, which rebuilds every consumer, rather than any targeted
repaint. See [data-flow.md](data-flow.md).

`NS:SweepPreviewPanels` runs on the same path: preview placeholders are session scaffolding, and a
profile carrying orphaned preview records from an interrupted session must not resurrect them as real
panels.

## The Profiles page

Rendered from **AceDBOptions'** own options table by `AceConfigDialog`, into a container parented to
the addon's canvas. This is the **one** place `AceConfigDialog` is used, and it is a deliberate
exception rather than an oversight — see [settings-panel.md](settings-panel.md) for why `anti-patterns`
forbids it for content and permits it here.
