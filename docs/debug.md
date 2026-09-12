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

## Bulk copy and reset — one `[Set]` line (`debug-logging-§10`)

A bulk copy or reset logs **one** `[Set]` line naming the act, its scope and how much it actually
changed, and never a line per field or per row (standard v2.44.0). The lines, exactly:

| Act | Line |
|---|---|
| Panel editor ▸ Reset (`R:Reset`) | `[Set] reset '<panel>': N rows` |
| Panel editor ▸ copy settings from another panel (`R:CopyFrom`) | `[Set] copy from '<src>' to '<dst>': N rows` |
| Master controls ▸ Reset position (`R:ResetPositions`) | `[Set] reset positions: N panels` |
| Recover panels, `/pm recover` (`R:Recover`) | `[Set] recover positions: N panels` |
| Reset all settings, `/pm resetall`, the header Defaults (`Sl:DoResetAll`) | `[Set] reset profile '<name>' to defaults (N rows)` |
| Profiles ▸ Reset Profile | `[Set] reset profile '<name>' to defaults`, with no count |
| Profiles ▸ Copy From | `[Set] copied profile '<src>' → '<dst>'` |
| Profiles ▸ switch | `[Profile] switched to '<name>', N panels`, unchanged |

**N is what the act changed**, not what it covered: a field already at its default, a field already
equal to the source's, a panel already where it belongs is not counted. An act that changes nothing
still logs its line, with `0`. For the record verbs N comes from `Util.CountChanged` over a copy of
the record taken before the act; for `resetall` it is the persisted schema rows that read back
differently from the snapshot `Sl:DoResetAll` takes before `db:ResetProfile()`. The Profiles page's
own Reset Profile takes no snapshot, so its line carries no count, which the rule permits.

**The three profile events are logged by the handler**, once each, worded by the event
(`core/Database.lua`). A reset or copy is AceDB replacing the profile wholesale, not a batch through
the write seam. `Registry:ReloadProfile` logs nothing, so a reset is not also reported as a switch.

**One bracket, in `settings/Schema.lua`.** `S.BulkBegin` / `S.BulkEnd` is the pair the Options
descriptor hands LibKa0s (minor 16) for `O.RestoreDefaults` and `O.RestoreAllDefaults`, and
`S.BulkLine` is how the Registry's verbs log. While a bracket is open, `S:Set` mutes its per-row line
and tallies a write only when the row reads back differently, so the library's own `count` (every
row `applyDefault` returned) is never used as N. Brackets nest by depth over one shared tally, and
only the **outermost** act emits: an act run inside another adds to its total. If any level reports
`info.profileReset`, nothing is emitted, because the profile handler logs that reset. The Options
pair is defensive: no control in this addon reaches a library walk today.

Reactor lines are not `[Set]` lines and stay: a reset that repaints the canvas still logs
`[Canvas] rendered N panels` after its one `[Set]` line.

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
