# Compat layer

`core/Compat.lua` is the one file in PanelMaster allowed to call a version-variant or optional client
API. Every other file calls `NS.Compat.X` and never the raw global. It publishes **nine** shims,
counted the way documentation-§3 counts them:

```
grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua   # 9
```

Nine is over the trigger's threshold of three, so this page exists and the `compat-layer.md` row in
`docs/ARCHITECTURE.md` ▸ `## Documentation map` reads *Present*.

## Why the file is required here

compat's applicability condition (standard v2.65.0) requires `core/Compat.lua` of an addon that calls
any deprecated or version-variant client API outside `LibKa0s`'s majors, and exempts an addon with
none. PanelMaster is not exempt: it owns the addon-roster read, the combat-state read, the cursor
test and the optional LibSharedMedia calls below, so the file is required and those calls live in it.

## Why eight stay addon-owned

`LibKa0s-Compat-1.0` is consumed for one member only: `Compat.IsSecret` routes to the library's
`IsSecret`, with the library-absent stub arm the major requires (a guard's stub re-implements the
body, because "the library is missing" is not "the client has no secrets system"). The WoW Forever
port added it for the unlock code's strata read (`U.PanelStrata`, `docs/ARCHITECTURE.md` ▸
*Per-client features*). The rest of the major was weighed and declined in
[#53](https://github.com/tusharsaxena/PanelMaster/issues/53): no other member answers any of
the other eight questions the way this addon needs them answered, so those shims are PanelMaster's own
and none of them re-documents a library shim. The TOC-metadata reader that once headed this file is
the library's now (`LibKa0s-Env-1.0`, reached through `core/EnvSetup.lua`), and so is the class-color
lookup (`LibKa0s-Core-1.0` minor 7, reached through `Util.ResolveColor`). Neither counts here.

All of them follow one rule: a capability is probed by **presence** (`type(X) == "function"`,
`C_AddOns and C_AddOns.GetNumAddOns`), never by asking which game flavor is running. The addon serves
Retail and WoW Forever with no `WOW_PROJECT_ID` branching, and `tests/test_compat.lua` asserts that.

| Shim | Defined as | Question it answers | API absent |
|---|---|---|---|
| `AddOnFolders` | `Compat.AddOnFolders` | Which addon folders are installed | `nil` ("cannot tell") |
| `GetScreenSize` | `Compat.GetScreenSize` | The screen size in UI units | `nil` |
| `GetUIScale` | `Compat.GetUIScale` | The effective UI scale | `1` |
| `InCombat` | `Compat.InCombat` | Is the player fighting | `false` |
| `RegisterMedia` | `Compat.RegisterMedia` | Contribute the addon's own LSM entries | `false` (no-op) |
| `FetchMedia` | `Compat.FetchMedia` | LSM name to texture path | the built-in flat texture |
| `MediaList` | `Compat.MediaList` | LSM names for a settings dropdown | `None` and `Solid` only |
| `MouseIsOver` | `Compat.MouseIsOver` | Is the cursor over this frame | `false` |
| `IsSecret` | `Compat.IsSecret` | Is this value secret (`LibKa0s-Compat-1.0`'s guard) | the stub arm: `issecretvalue`, else `false` |

## `AddOnFolders` — `core/Compat.lua`

**What varies.** The installed-addon roster. It reads `C_AddOns.GetNumAddOns` / `C_AddOns.GetAddOnInfo`
and nothing else: the bare `GetNumAddOns` / `GetAddOnInfo` globals went in the 11.0 AddOns purge and
exist on no Interface 120100 client, so there is no fallback rung. It answers the INSTALLED list, not the loaded one, because the
Sunn adapter needs to know whether a pack folder exists on disk even when the pack's own Lua never ran.

**When the API is absent.** `nil` when either `C_AddOns` member is missing or the count is not a number. It never
answers an empty table, because "cannot tell" and "nothing installed" must stay distinguishable: an
empty table would drop every known pack.

**Who calls it.** `modules/SunnArt.lua` (`addonFolders`), whose `folderInstalled` gate reads `nil`
as "offer the theme".

## `GetScreenSize` — `core/Compat.lua`

**What varies.** Whether `UIParent` can report its size at all. It is a real frame in-game and a stub
headlessly, and the stub reports 0×0.

**When the API is absent.** `nil` when `UIParent` or its `GetWidth` / `GetHeight` is missing, or when
either reading is not a positive number. A zero reading is "cannot tell", not a tiny screen.
Otherwise the recovery pass would drag every panel to the origin.

**Who calls it.** `modules/Registry.lua` (`R:Recover`, which on `nil` moves nothing and refuses with the reason `cannot measure the screen`) and
`modules/Diagnostics.lua` (`screenSection` and `positionLine`: the diagnostics report's screen
section and its per-panel position line).

## `GetUIScale` — `core/Compat.lua`

**What varies.** Whether `UIParent:GetEffectiveScale` exists and answers a positive number.

**When the API is absent.** `1`, the identity scale, which is always safe to multiply by.

**Who calls it.** `modules/Diagnostics.lua` (`screenSection`, the diagnostics report's screen section).

## `InCombat` — `core/Compat.lua`

**What varies.** Which combat API the client offers. The ladder reads the combat flag,
`UnitAffectingCombat("player")`, first, then falls back to `InCombatLockdown()`, then answers `false`.
This is a display question ("is the player fighting?"), and combat-reactive display reads the combat
flag (events-frames-taint-§2). Lockdown starts after `PLAYER_REGEN_DISABLED`, so a render at combat
start that asked lockdown drew the out-of-combat look for the whole fight. The combat-transition
render does not ask this shim at all: `Canvas:RenderForCombat` takes the REGEN event's own answer.

**When the API is absent.** `false` when neither API exists. That is the answer that keeps a panel on
screen: `true` on a client that cannot answer would hide every "Only out of combat" backdrop for the
session with nothing said.

**Who calls it.** `modules/Canvas.lua` (`Canvas:Render` when no `inCombat` is passed, which is how `Canvas:RenderAll` calls it) and
`modules/Diagnostics.lua` (`panelLines`: the diagnostics report builds each panel's spec with it). The
unlock deferral in `modules/Unlock.lua` deliberately asks `InCombatLockdown` directly instead, because
lockdown is the question an unlock has to ask.

## `RegisterMedia` — `core/Compat.lua`

**What varies.** Whether LibSharedMedia-3.0 is loaded. It is an optional dependency. When it is there,
this registers the addon's `Solid` texture as a `border`, a `background` and a `statusbar`, because LSM
ships no solid border and a plain 1px outline is the addon's default look.

**When the API is absent.** Returns `false` and registers nothing. Registering twice is harmless.

**Who calls it.** `core/PanelMaster.lua` (`addon:OnInitialize`), before the first render, so the shipped
default resolves on the first frame.

## `FetchMedia` — `core/Compat.lua`

**What varies.** Whether LSM is loaded, and whether a stored media name still belongs to an installed
addon.

**When the API is absent.** The built-in flat texture (`NS.Constants.SOLID_TEXTURE`), both without LSM
and for a name LSM cannot resolve, so a panel with a missing texture looks plain, not invisible
(library-stack-§6). It returns `nil` only for the explicit `None` entry, which is the user's choice to
draw nothing.

**Who calls it.** `modules/Canvas.lua`'s `applyAccentBorder`, `applyAccents`, `applyBackground` and `applyBorder`
(accent border, accent bar, background and border, at render time).

## `MediaList` — `core/Compat.lua`

**What varies.** Whether LSM is loaded, and which names other addons have registered so far this
session. It is queried at click time rather than cached for that reason.

**When the API is absent.** `None` and `Solid`, in that order. `None` always comes first, whether or
not LSM ships it, because "draw no border" is a choice this addon's UI must always be able to offer.

**Who calls it.** `settings/PanelEditor.lua` (`makeMediaDropdown`) and `settings/PanelEditorTabs.lua` (`mediaValues`) (the media dropdowns) and
`settings/PanelSchema.lua` (`COERCE.media`, matching a name typed on the command line against the live list).

## `MouseIsOver` — `core/Compat.lua`

**What varies.** Whether the global `MouseIsOver` exists, and whether it accepts the frame in hand.
The call is wrapped in `pcall`.

**When the API is absent.** `false` when the global is missing, the frame is `nil` or the call errors.

**Who calls it.** `modules/Canvas.lua`'s `updateMouseover`, the mouseover fade. The panel never enables mouse input,
because a backdrop that took the mouse would stop being click-through; this shim answers the question
without claiming the input.

## What is deliberately not here

There is no backdrop-support shim. Whether `BackdropTemplateMixin` exists says nothing about the frame
in hand, so `modules/Canvas.lua` checks the frame's own `SetBackdrop` method instead, and no deprecated
API is being wrapped.

Tests: `tests/test_compat.lua` covers the degraded answers of five shims (`GetUIScale`, `FetchMedia`,
`MediaList`, `RegisterMedia` and `InCombat`, including all three rungs of the `InCombat` ladder).
`AddOnFolders`' `nil` answer is covered in `tests/test_sunnart.lua`, where the gate that reads it
lives. `GetScreenSize` and `MouseIsOver` are tested on their normal answers only; nothing yet
covers `GetScreenSize`'s `nil` or `MouseIsOver`'s missing-global, nil-frame or error `false`.
