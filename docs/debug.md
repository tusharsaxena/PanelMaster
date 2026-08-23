# Debug

`debug-logging`: a 700×344 `DIALOG`-strata window in JetBrains Mono at 10pt — the face now arrives
inside the LibKa0s payload rather than in this addon's own `media/` — with timestamped color-coded
`<HH:MM:SS> | [Tag] <content>` lines, a right-edge scrollbar and an `N / MAX lines` counter
(`debug-logging-§11`), a clear and a copy control, and `UISpecialFrames` for ESC.

The three title-bar controls are **marks, not words**. `core/DebugLogSetup.lua` passes `addonName`
in the descriptor, which is what lets the library build a texture path into the shared icon set and
draw the collection's own close, clear and copy art; without it the library falls back to a
multiplication sign and the words "Clear" and "Copy". They carry no tooltips, deliberately: a label
anchored under a control on a window that is 700px of text covers the first line of the log.

Logging state is **session-only** (`NS.State.debug`, never in SavedVariables) and **independent of
the window**: capture runs with the console closed, so a bug can be reproduced first and the log read
afterwards. `/pm debug` toggles the window; `/pm debug on|off` sets the flag through the single
`DebugLog:SetEnabled` seam, which also writes the console bracket and, on enable, the `[Init]`
summary.

`/pm debug dump` is the structured-dump verb (`debug-logging-§4`): it prints the registry's and the
renderer's views of the world side by side, including orphaned frames. A panel in the registry with
no frame — or the reverse — is the shape of every rendering bug this addon can have.

## `NS.DebugBuild` — the gated sink for expensive arguments

Most debug sites call `NS.Debug(tag, fmt, ...)`, which is a zero-allocation no-op when logging is
off. A site whose **arguments** cost something to produce needs more than that, because the arguments
are built before the gate is reached.

`NS.DebugBuild` is that seam, and it carries one hard requirement: **its builder must be a plain
function reference with its arguments passed unbound.** A closure would be allocated at the call
site — before the gate — which is precisely the cost being avoided. Writing
`NS.DebugBuild("Tag", function() return expensive(x) end)` looks equivalent and defeats the whole
mechanism.

`NS.Debug` carries the addon's **only** debug gate (`debug-logging-§4`). There is no second flag.
