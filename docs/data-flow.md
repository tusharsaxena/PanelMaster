# Data flow

Record → spec → frame: how a stored panel record becomes something on screen, the frame ladder it is
placed in, the pool that owns the frames, and the events that drive a render. The stored shape is
[schema.md](schema.md); the artwork and accent-bar drawing detail is [rendering.md](rendering.md).

The README's player-facing description of how panels work is the same pipeline one level up; the two
must not contradict each other.

`Canvas.BuildSpec(record, settings, inCombat)` is **pure**: record + settings + the combat state →
exactly what the frame should look like, with every value already validated and clamped. All of
"what does this panel render as" is therefore unit-testable headlessly, and `applySpec` is a thin,
uninteresting application of the result. `spec.shown` folds **three** independent switches into one
answer so no call site has to remember them: the addon-wide master (`settings.enabled`), the
addon-wide general-visibility rule (`settings.visibility`, decided by the separately published and
equally pure `Canvas.VisibilityShows(mode, inCombat)`), and the panel's own `enabled`. `inCombat` is
an input rather than something read inside, which is what keeps the rule assertable; a caller that
omits it gets the out-of-combat answer, which is what every profile written before `visibility`
existed already meant.

The other two addon-wide rows on the **Master controls** tab are honored in the same place, as
**multipliers** rather than replacements: `settings.scale` multiplies each panel's own `scale` and
`settings.alpha` its own `alpha`, so the editor's per-panel sliders keep showing what the player
typed for that panel. All three degrade to the identity, so a profile written before they existed
renders exactly as it did.

A panel is drawn as a background **texture** (an LSM `background` name, tinted with the resolved
color) plus a `BackdropTemplate` **edge** (an LSM `border` name at the user's thickness). The
backdrop's `bgFile` is deliberately unused — it insets under the edge, and a panel wants its fill to
run to the frame's actual bounds.

That fill texture lives on its **own child frame** (`f.bgFrame`, `SetAllPoints`), not on the panel
frame itself. The reason is artwork: a child frame always draws above its parent's textures whatever
draw layer those use, so with the fill on the panel there is **no** frame level a child could take
to get underneath it, and `artLayer = "BELOW_BG"` would be unreachable. The texture keeps the field
name `f.bg`, so every call site and test that paints it is unchanged; only what it hangs off moved.

The border lives on its **own child frame** (`f.borderFrame`), not on the panel frame itself. A
backdrop is always drawn at its own frame's bounds, so moving the border in or out relative to the
panel — `borderOffset` — is only possible by moving the frame that carries it. Being a child, it
inherits the panel's strata, level and alpha automatically, so the border can never end up on a
different layer from the panel it belongs to.

`SetBackdropBorderColor` **must** follow `SetBackdrop`: applying a backdrop resets its border color
to white, so coloring first is silently undone. A test asserts the recorded color survives.

#### The frame ladder

Everything a panel draws sits on a child frame with an explicitly assigned level, seven slots deep,
stated once in `core/Constants.lua` (`C.ART_FRAME_LEVEL`, `C.BG_FRAME_LEVEL`,
`C.BORDER_FRAME_LEVEL`, `C.ACCENT_FRAME_LEVEL`, `C.UNLOCK_FRAME_LEVEL`) and applied in `applySpec`
— except the last, which `modules/Unlock.lua` builds lazily and sets itself:

```
f                       base          the panel frame
  f.artFrame  BELOW_BG  base + 1
  f.bgFrame             base + 2      background fill
  f.artFrame  ABOVE_BG  base + 3      ← artLayer default
  f.borderFrame         base + 4
  f.accentFrame         base + 5
  f.artFrame  ABOVE_ALL base + 6
  f.overlay.frame       base + 7      unlock outline and name label
```

The unlock overlay is on the ladder at all because of this change. It used to be textures on the
panel frame itself, kept above the panel's art by *draw layer*; that works only while the art is
also a region of `f`. Once the fill became a child frame, frame level took precedence over draw
layer and the fill drew straight over the outline — so on every unlock and every preview, the gold
outline and the panel name vanished under the panel's own 85%-opaque background. It now has its own
frame above every other rung, which is what its job requires: nothing may cover the thing that makes
an invisible panel findable.

#### Panel levels are strided

`scale` is the panel's own frame scale, applied by `applySpec` **before** the size and the anchor —
that order is load-bearing, because a frame's scale is the unit both `SetSize` and `SetPoint`'s
offsets are expressed in, so setting it afterwards leaves the panel sized and placed in the previous
scale's units until some unrelated write repaints it. It is deliberately not folded into
`width`/`height`: the stored size is what the user typed and what the editor's sliders show. Bounded
by `C.MIN_PANEL_SCALE`/`C.MAX_PANEL_SCALE` (0.25–4.0) rather than by the artwork's own scale range
(0.1–4.0), because `artScale` resizes a texture inside a panel whose clickable area is unchanged
while this resizes the frame itself — a floor of 0.1 would walk straight around the `C.MIN_SIZE`
floor that exists to keep a panel findable and grabbable. One consequence worth knowing: because
`SetPoint` offsets are in the frame's own scaled units, changing the scale also moves the panel
relative to its anchor.

A panel's own frame level is `level × C.PANEL_LEVEL_STRIDE`, not `level`. A panel occupies eight
rungs, so consecutive raw levels would *interleave* — one panel's accent bar landing on the same
frame level as the next panel's background fill, with the winner decided by frame creation order,
which the name-keyed pool does not keep in panel order. The `level` setting means "higher draws in
front"; the stride is what makes that true for every distinct value rather than only for values far
enough apart to clear the footprint.

The levels are **spread out** rather than consecutive because the artwork has to *interleave* with
the other three: three of the six slots are the same single `f.artFrame`, whose level is reassigned
per render from `C.ART_FRAME_LEVEL[art.layer]`. Frame levels are mutable at any time, so one frame
covers all three choices — three art frames per panel would be two created to sit hidden forever.
This is also the only arrangement in which "behind the background" and "above the accent bar" are
both expressible.

Left alone, every child frame merely defaults to `parent + 1`, which would pile the fill, the border
and the accent onto one level and leave their order to creation sequence. `base` is read back with
`GetFrameLevel()` rather than reusing `spec.level`, since the client clamps a frame's level and the
value that landed may not be the one asked for.

#### Frame names and the pool

Every panel frame is created under a global name, `PanelMaster_Panel_<slug>`, derived from the
panel's name by `Util.Slugify` **at create time and then stored on the record** as `rec.frameName`.
That is a **public contract**: another addon or a WeakAura anchors to it by name with no API call.

The frame name is **identity, like the id** — `Registry.FrameName` reads the stored field and never
recomputes it. `R:Reset` preserves it alongside `id` and `name`; `COPY_EXCLUDED` keeps `CopyFrom`
from smearing one panel's global onto another; and `R:Rename` does not touch it at all.

Three consequences follow, and all are load-bearing:

- **A rename is a relabel.** The panel keeps the frame it already had, so nothing anchored to it
  moves and no frame is abandoned. This is the fix for the pair of bugs (#6, #7) that the derived
  frame name caused: a frame's name is immutable after `CreateFrame`, so recomputing it meant a
  rename had to retire the old frame and stand up a new one — silently orphaning every external
  anchor, with no migration possible, and leaking one frame per distinct name typed.
- **Frame names must be unique on create, and only on create.** "Chat BG" and "Chat-BG" are two
  legal panel names wanting one frame name, and two frames cannot share a global. `Registry` refuses
  the second at create. It does **not** check on rename, because a rename claims no new global. A
  name that looks free can still be refused: a panel created as "Alpha" and later renamed still
  holds `PanelMaster_Panel_Alpha`, and the refusal names it.
- **The pool is keyed by frame name, not a flat stack.** A released frame can only be reused by a
  panel wanting that same name. Delete a panel and re-create it with the same name and you get the
  same frame back.

Frames are pooled rather than leaked (`hard rule #14`) — a user with thirty panels toggling the
master switch twice would otherwise leak sixty frames permanently — and the bound is now "one frame
per distinct frame name used this session", which renaming no longer grows.

The trade this buys, stated plainly: after a rename the frame name no longer matches the panel's
name and stops being derivable from it. Predictability at create was judged the lesser half of the
contract — you look the name up once, when you wire something to the panel, and the settings page's
name-box tooltip is where. Anchors that silently stop tracking, days later, are the worse failure.

The alternative considered and rejected: anonymous pooled frames plus `_G` aliases. It keeps a flat
pool, but hands out frames whose `GetName()` is `nil`, which breaks every consumer expecting a real
named frame.

`NS.SCHEMA_VERSION` is **2** for this: the v1 → v2 migration stamps `frameName` onto every panel by
deriving it from the name, which reproduces exactly the global that build already gave the frame, so
the upgrade moves nobody's anchors. `R.Sanitize` fills the field the same way for a record arriving
by another route (an imported profile, a test), which is what covers profiles other than the one
active when the migration ran.

Preview writes its placeholders into the registry as **real records**, which is what makes the
preview exercise the real render path rather than a mock that can drift from it. Two things track
them, and both are needed:

| Half | Lives in | Survives a `/reload`? |
|---|---|---|
| `NS.State.previewIDs` | session state | no — the fast in-session path |
| `rec[C.PREVIEW_FIELD]` (`preview = true`) | the record itself | yes — the recovery path |

`NS:SweepPreviewPanels()` walks `db.profile.panels` backwards, removes every marked record and
returns the count. It runs from `NS:InitDB` — after `NS:RunMigrations`, before
`NS:RegisterProfileCallbacks`, therefore before `Canvas:Enable` and the first `RenderAll`, so an
orphan is never drawn — and again on the profile-reload path, since a copied profile can carry
someone else's orphans. It is idempotent, and the marker is additive, so it needed no schema bump of
its own.

The marker is deliberately **not** in `PANEL_FIELD_TYPE`, `PANEL_FIELD_ORDER` or `PANEL_TEMPLATE` —
the CLI cannot set it, `/pm panel <name>` does not print it, and a normally-created panel never has
it — and it is in the registry's `COPY_EXCLUDED`, so `CopyFrom` cannot smear it onto a real panel.

`R:Reset` **refuses** a marked record outright, with a reason the caller prints. It rewrites the
record from `C.PANEL_TEMPLATE`, which carries no marker, so a reset used to strip it and promote a
throwaway placeholder into a permanent panel the user then had to delete by hand — the one remaining
path by which preview could leave litter in a saved layout. Refusing rather than re-stamping:
resetting a placeholder to the shipped template is not a meaningful thing to want, and a tagged
notice explains why more usefully than silently doing nothing. With that closed, the marker survives
every registry write seam, which is what makes "preview off removes exactly what preview added" true
unconditionally.

Both transitions go through `U:SetUnlocked`, never a direct write to `NS.State.unlocked`, so leaving
preview clears the per-panel unlock and pending sets the same way any other lock does. The order is
**registry first, lock second**: `SetUnlocked` repaints, so the placeholders have to exist before it
runs. Preview's implied unlock passes `SetUnlocked`'s private `immediate` flag, which skips the
combat gate: the placeholders are non-secure frames preview has just created itself, so no secure
write is involved, and deferring only that half would leave the user mid-pull with three anonymous,
mouse-transparent rectangles under a message that never mentions preview.

Panels are **non-secure** frames, so the render path is not combat-gated at all: creating, moving,
recoloring and hiding a plain backdrop frame is legal in combat, and gating it would mean a panel
that visibly failed to follow a settings change mid-pull. That is also what lets the combat
transition itself drive a repaint — `Canvas:RenderForCombat` runs on both regen events and repaints
**only** when `settings.visibility` is `inCombat` or `outOfCombat`, since `Always` and `Never`
answer the same thing either side of a pull and the common case is meant to cost one table read.

Two things are gated, in the two different shapes the standard defines:

- **Unlock defers** (`events-frames-taint-§2`). Unlocking hands the user draggable frames, which is a
  bad thing to do mid-pull. `/pm unlock` in combat queues, prints a gray notice, and is replayed from
  `PLAYER_REGEN_ENABLED`. **Locking is never deferred** — it only makes the UI quieter, so refusing
  it would be the one case where the gate made things worse. An explicit lock also clears a queued
  unlock, or the queue would undo the user's own decision the moment combat ended. Per-panel unlocks
  queue and replay the same way, and a panel deleted mid-combat is dropped from the queue rather
  than resurrecting an unlock entry for a record that has gone. **Preview is the one documented
  bypass** — see the preview section above.
- **The options panel refuses** (`options-ui-§2`). `Settings.OpenToCategory` is protected, so
  `/pm config` in combat prints a gray notice and returns. It does **not** replay: a panel that pops
  itself open the instant combat drops steals focus during recovery.

| Event | Handler | Why |
|---|---|---|
| `PLAYER_ENTERING_WORLD` | `Canvas:RenderAll()` | Panels are drawn here, not at `OnEnable`: `UIParent`'s size is what recovery measures against and it is not final that early. |
| `PLAYER_REGEN_ENABLED` | `Unlock:ResumePending()`, then `Canvas:RenderForCombat()` | Replays a combat-deferred unlock, and repaints for the general-visibility rule. |
| `PLAYER_REGEN_DISABLED` | `Canvas:RenderForCombat()` | The entering-combat half of the same rule. |
| `PLAYER_LOGIN` | `Panel:Register()` | A second **eager** attempt at settings-category registration, for the load order where `Settings`/AceGUI were not there yet in `OnInitialize`. `Register` is idempotent, so it is a no-op on a normal login. Not a deferral to first `/pm config` (anti-pattern #22). Subscribed from `OnInitialize`, not `OnEnable`: AceAddon runs `OnEnable` from inside its own `PLAYER_LOGIN` handler, and subscribing mid-dispatch misses that firing — the only one a non-LoD addon gets. |
