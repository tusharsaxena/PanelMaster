# Debug

`debug-logging`: a `DIALOG`-strata window, 700×344 by default and resizable from a bottom-right grip
(LibKa0s v1.64.0; the size is kept on the window for the session only and never saved, so a
`/reload` restores the default), in JetBrains Mono at 10pt — the face now arrives
inside the LibKa0s payload rather than in this addon's own `media/` — with timestamped color-coded
`<HH:MM:SS> | [Tag] <content>` lines, a right-edge scrollbar and an `N / MAX lines` counter
(`debug-logging-§11`), a clear and a copy control, and `UISpecialFrames` for ESC.

The three title-bar controls on the right are **marks, not words**. `core/DebugLogSetup.lua` passes
`addonName` in the descriptor, which is what lets the library build a texture path into the shared
icon set and draw the collection's own close, clear and copy art; without it the library falls back
to a multiplication sign and the words "Clear" and "Copy". They carry no tooltips, deliberately: a
label anchored under a control on a window that is 700px of text covers the first line of the log.

On the left, beside the `Debug: ON` / `OFF` toggle and a small gap after it, the library draws an
orange **Diagnostics** link (DebugLog minor 16, LibKa0s v1.64.0): plain text like the toggle, no
frame art, brighter under the pointer. A click runs the report exactly as `/pm diagnostics` does
(below). It is drawn because the vendored `DebugLogDiagnostics.lua` gives the console its
`RunDiagnostics`; this addon adds nothing for it.

Logging state is **session-only** (`NS.State.debug`, never in SavedVariables) and **independent of
the window**: capture runs with the console closed, so a bug can be reproduced first and the log read
afterwards. `/pm debug` toggles the window; `/pm debug on|off` sets the flag through the single
`DebugLog:SetEnabled` seam, which also writes the console bracket and, on enable, the `[Init]`
summary.

The buffer is the library's (`lib.MAX_BUFFER`, 3000 lines at LibKa0s v1.60.0); nothing in this
addon sets or repeats the number.

## `/pm diagnostics`: the report (`debug-logging-§14`)

The report replaced `/pm debug dump`, which was the same idea without markers, a cap or a `pcall`
per section. Run it **after** reproducing the problem, not before: it is appended below whatever the
console already holds, so the trace you just produced and the state it left behind travel in one
**Copy**. That is what the README's *Reporting a bug* steps do.

**Two forms, no third.** `/pm diagnostics` and `/pm debug diagnostics` (either case, and through
`/panelmaster` as well as `/pm`) are the same call. The first is its own `diagnostics` row in
`settings/Slash.lua`; the second is the `debug` row, which hands its rest to the library's
`NS.DebugLog:DebugVerb` before anything else. There is no `diag`, `dump` or `dx` alias:
`/pm debug dump` and `/pm debug diag` are ordinary unknown words, and like any other they toggle the
console.

**It turns debug logging on for the session.** Running the report (either form, or the console's
**Diagnostics** link) first turns logging on, when it is off, through the flag's one seam
(`DebugLog:SetEnabled(true)`, `debug-logging-§14` at v2.71.0, DebugLogDiagnostics minor 2), so the
`[Debug] logging enabled` line and the `[Init]` summary land above the report and the next
reproduction is traced without a separate `/pm debug on`. It never turns logging off, and with
logging already on it adds no second enable line. The flag is session-only, so a `/reload` turns it
off again; `/pm debug off` does too. This addon keeps the library's default: the descriptor in
`core/DebugLogSetup.lua` does not set `diagnosticsEnablesLogging = false`. The sections only read;
the run is the one thing that touches the flag.

**What it does to the console.** It writes through the library's raw append, not the gated sink
`NS.Debug`, so it lands in full whatever the flag said. It never clears the console, and it shows
the console if it was hidden. Then it prints one chat line: *Diagnostic report written to the debug
console: N lines. Use Copy to share it.*
`debug` and `diagnostics` are both reserved verbs (`slash-commands-§2`), so both forms answer while
the addon is **disabled**.

**The shape.** The library writes the frame; `modules/Diagnostics.lua` writes the sections, handed
over as `Dx.Sections()` in the `diagnostics` field of `core/DebugLogSetup.lua`'s descriptor. Every
line of the report carries the `[Diag]` tag.

| Part | Written by | What it holds |
|---|---|---|
| Begin marker | the library | `==== Ka0s Panel Master diagnostics begin ====` |
| Identity header | the library | The `[Init]` summary line, the client version, build, date and interface, the locale, the debug flag, the two combat flags, and every LibKa0s file **running** in the client with its minor (running, because under LibStub another addon's newer copy may be the one loaded) |
| `state` | this addon | The schema version stored and in code, the current profile, the stored `settings.enabled` against the stand-down latch, the Lifecycle holds, and test mode (unlock mode is this addon's test mode, `options-ui-§15`) |
| `master` | this addon | The master switches (`enabled`, `visibility`, `alpha`, `scale`), global unlock with snap, grid, outline and labels, and the ids of the individually unlocked panels |
| `unlock queue` | this addon | The unlock requests combat deferred: the global request and the queued panel ids, read through `NS.Unlock:PendingSnapshot()`, which returns a copy, so reading it can never flush or replay the queue |
| `settings` | this addon | Every schema row that differs from its default, `settings.enabled` always, `state.locked` (session-only, so the walk skips it and it is printed by hand), then how many rows printed |
| `screen` | this addon | Screen size and UI scale |
| `panels` | this addon | `registry: N panels`, then each panel under its own `pcall` (below) |
| `frames` | this addon | `frames: N active, M pooled, K orphaned`: a frame with no record is a leak, and the pool count tells a leak from healthy reuse |
| `mouseover` | this addon | How many panels the mouseover fade tracks, and whether its ticker is running |
| `artwork` | this addon | The artwork catalog's rows, how many came from Sunn packs, and how many Sunn themes are installed |
| `events` | this addon | `rejected events (N):` and the names, or `-` when there are none (below) |
| `truncated` line | the library | Only when a cap bit: `truncated: N line(s) omitted, per-list caps hit=yes/no` |
| End marker | the library | `==== Ka0s Panel Master diagnostics end: N line(s) ====`, counting both markers |

**One panel** prints these lines, in order:

| Line | What it says |
|---|---|
| `[<id>] '<name>' enabled=… frame=… unlocked=…` | The record's identity and its frame name (`PanelMaster_Panel_<slug>`, stamped at create) |
| `differs from template:` | Every field that differs from `C.PANEL_TEMPLATE`, keys sorted so two reports diff cleanly, or `-` for a panel still on the template |
| `renderer: frame=… shown=… want=… live WxH record WxH match=…` | The renderer against the record. `frame=NO` means the record has no frame |
| `alpha: live=… target=… floor=… mouseover=… tracked=… match=…` | The live alpha against the alpha the panel should hold, or its mouseover floor |
| `position: record … live … offscreen=…` | The record's anchor, the frame's live anchor, and whether `/pm recover` would move it. `offscreen` is recover's own test (`R.IsOffScreen`), asked without recovering anything |
| `media:` | Each of the four media fields with how it resolved: `ok`, `none`, `missing -> Solid` or `no LSM -> Solid` |
| `art:` | `none`; a custom path **verbatim** and whether it resolved; or a catalog id, whether the catalog still has it, the path and the quad count |

A number read off a frame is compared only when `out:readable` says it can be, so an unreadable one
prints `match=unknown` rather than a false mismatch.

**Reading it for a rendering bug.** Look at `frame=` on each panel and at the `frames:` line. A
panel in the registry with no frame (`frame=NO`), or a frame with no panel (a non-zero orphan
count), is the shape of every rendering bug this addon can have. `match=NO` narrows it to size or
alpha, `offscreen=yes` says `/pm recover` would help, and a `missing -> Solid` names the texture
that went away.

**Stood down.** While the addon is disabled every section still runs. Each panel's renderer line
reads `renderer: stood down` and its live anchor `no frame`, rather than describing released frames
as if they were broken. Stored configuration prints as normal.

**Caps.**

- The whole report: at most `min(lib.DIAG_MAX_LINES, lib.MAX_BUFFER - 100)` lines, markers
  included. That is **1200** at LibKa0s v1.60.0 (`min(1200, 3000 - 100)`), so a full report leaves at
  least 1800 lines of trace above it in a full console. Two lines stay reserved for the `truncated`
  line and the end marker, so a capped report still ends properly.
- Each id list (unlocked panels, queued panels, rejected events): 40 entries, the library's default,
  then `(+N more)`.
- A long line (the holds, a template difference) wraps onto indented continuation lines at 200
  characters rather than being cut.

**What it deliberately never does.** It writes no setting, and it never calls `R:Recover`,
`FitToArtwork`, `SetPoint` or `Show`, never replays the combat unlock queue, and never probes another
addon's frames. Every question the addon could answer by acting is answered by the pure half of the
code that acts: `R.IsOffScreen`, `Canvas.BuildSpec`, `Artwork.BuildArtSpec` and
`Unlock:PendingSnapshot`. It calls no protected API, so it is safe in combat. Every value reaches a
line through the library's `out:add`, which stringifies it through `SafeToString` before any format
sees it, so a secret value prints as `<secret>` instead of raising. The library runs each section
under its own `pcall`, and `panels` runs each panel under another, so one that raises costs exactly
one line (`section <name> failed: <err>`) and the next one still prints.

**Without LibKa0s** there is no report to write: both forms print `/pm diagnostics is unavailable:
the LibKa0s library did not load.` and write nothing (`core/DebugLogSetup.lua`'s degraded arm).

Nothing is redacted: the report goes to the maintainer privately with a bug report, so it prints what
reproducing a bug needs, custom artwork paths included. Report lines are English diagnostic text and
do not go through `NS.L`; the one chat line is the library's.

### The rejected-events record

The report's last section, `events`, prints `rejected events (<n>): <names>`, or
`rejected events (0): -` when the list is empty (`events-frames-taint-§1`). Every game-event
registration goes through `NS.SafeRegisterEvent` (`core/CoreSetup.lua`, LibKa0s-Core's pcalled
helper, or a one-rung pcall stub when the library is absent), so a name the client refuses costs
only itself and is appended once to the session-only `NS.State.rejectedEvents`. A stand-up that
meets one also logs `[Events] rejected <name>` while logging is on.

## Bulk copy and reset — one `[Set]` line (`debug-logging-§10`)

A bulk copy or reset logs **one** `[Set]` line naming the act, its scope and how many rows it
actually changed, and never a line per field or per row (standard v2.44.0). The lines, exactly:

| Act | Line |
|---|---|
| Panel editor ▸ Reset (`R:Reset`) | `[Set] reset '<panel>': N rows` |
| Panel editor ▸ copy settings from another panel (`R:CopyFrom`) | `[Set] copy from '<src>' to '<dst>': N rows` |
| Master controls ▸ Reset position (`R:ResetPositions`) | `[Set] reset positions: N rows` |
| Recover panels, `/pm recover` (`R:Recover`) | `[Set] recover positions: N rows` |
| A library page Defaults (`O.RestoreDefaults`), the defensive walk: no control reaches it today | `[Set] reset <pageKey>: N rows` |
| Reset all settings, `/pm resetall`, the header Defaults (`Sl:DoResetAll`) | `[Set] reset profile '<name>' to defaults (N rows)` |
| The same, when `db:ResetProfile()` raises | `[Set] reset all: N rows (stopped by an error)` |
| Profiles ▸ Reset Profile | `[Set] reset profile '<name>' to defaults`, with no count |
| Profiles ▸ Copy From | `[Set] copied profile '<src>' → '<dst>'` |
| Profiles ▸ switch | `[Profile] switched to '<name>', N panels`, unchanged |

**N is the rows the act changed**, not what it covered: a field already at its default, a field
already equal to the source's, a position field already at the new-panel template is not counted. An
act that changes nothing still logs its line, with `0`. For `R:Reset` and `R:CopyFrom` N is the schema
runtime's read-back tally over the `panel.<field>` writes (plus, for a reset, the undeclared keys an
older build left on the record, which the reset drops). The two position verbs count
the `point` / `relPoint` / `x` / `y` fields they rewrote, across every panel (`R:Recover` only ever
clamps `x` and `y`); they still return the panels moved, which is what their callers print. For
`resetall` N is the persisted schema rows that read back differently from the snapshot
`Sl:DoResetAll` takes before `db:ResetProfile()`. The Profiles page's own Reset Profile takes no
snapshot, so its line carries no count, which the rule permits.

**The reset-all count covers settings rows only, not panels.** The reset takes the profile's panel
records with it, but a record is not a settings row, so neither the `reset profile …` line nor the
`reset all` line counts them.

**An act that raises still logs its one line**, with ` (stopped by an error)` appended and N the
rows it changed before it stopped. The mute is released and the error is re-raised unchanged: the
library's bracket re-raises after `bulkEnd`, and `Sl:DoResetAll` after its own. A reset-all that
raised never reached `OnProfileReset`, which is why the bracket logs `reset all` instead.

**The three profile events are logged by the handler**, once each, worded by the event
(`core/Database.lua`). A reset or copy is AceDB replacing the profile wholesale, not a batch through
the write seam. `Registry:ReloadProfile` logs nothing, so a reset is not also reported as a switch.

**One bracket, the schema runtime's.** `LibKa0s-Schema-1.0`'s instance (`NS.SchemaRuntime`, built
in `settings/Schema.lua`) owns it. `S.BulkBegin` / `S.BulkEnd` are its members, the pair the Options
descriptor hands LibKa0s (Options minor 16) for `O.RestoreDefaults` and `O.RestoreAllDefaults`, and
the Registry's verbs open it through `SetMany`'s `act` or the instance's `BulkRun` (PanelMaster#54). While a bracket is open,
the write seam mutes its per-row line and tallies a write only when the row reads back differently,
so the library's own `count` (every row `applyDefault` returned) is never used as N. Brackets nest by depth over one shared tally, and
only the **outermost** act emits: an act run inside another adds to its total. If any level reports
`info.profileReset`, nothing is emitted, because the profile handler logs that reset. The Options
pair is defensive: no control in this addon reaches a library walk today.

Reactor lines are not `[Set]` lines and stay: a reset that repaints the canvas still logs
`[Canvas] rendered N panels, M shown` after its one `[Set]` line.

## Coverage — what the log carries, by tag (`debug-logging-§8`, `§9`)

The test the log has to pass is "could a support read of a pasted log reconstruct what happened".
The flows say what the addon did; the diagnosis lines say why it did something else: the edges it
reacted to, the work it held and flushed, the guard that refused, the dependencies it found and the
errors it swallowed. Every line is one gated `NS.Debug` call per event, with any string-building
behind the gate. `tests/test_debuglog.lua` ▸ *Coverage* pins the diagnosis lines and the quiet
steady state; `tests/test_library_debug.lua` pins the lines LibKa0s writes into this log and that
none of them is written twice.

Logging is off at login (`debug-logging-§5`), so the lines written while the addon loads (a
migration, the preview sweep, the Sunn scan) render only in the rare session that turns logging on
before them. What they found reaches the log anyway, through the `[Init]` summary and
`/pm diagnostics`, which turns logging on for the rest of the session. The two **state** lines
OnEnable writes, the launcher's registration and the Sunn scan, go through the console's at-enable
queue (`NS.DebugAtEnable`, over `D.DebugAtEnable`, LibKa0s v1.65.0): held while logging is off and
written after the `[Init]` summary the first time it is turned on, once per session.

**Which lines are the library's.** Since LibKa0s v1.65.0 every LibKa0s module this addon adopts
logs its own refusals and edges through the gated sink the addon passes as the descriptor's `debug`
(Slash, Lifecycle, Options and Launcher all take it). The tags the library writes are `Debug`,
`Init`, `Diag`, `Cmd`, `Lifecycle`, `Cfg` and `Launcher`, plus the schema seam's per-write `Set`
line; this addon writes none of those lines itself, so each refusal or edge is one line, not two.
Every other tag below is this addon's own.

| Tag | Emitted by | When |
|---|---|---|
| `Debug` | the library (`SetEnabled`) | `logging enabled` / `logging disabled`, at each flip of the flag, including the enable a `/pm diagnostics` run makes when logging was off |
| `Init` | the library, with `NS.InitSummary` (`core/Database.lua`) | Once per enable: addon and version, schema, profile, panel count, then the optional dependencies: `LSM yes/no, LibDBIcon yes/no, Sunn themes N` |
| `Diag` | the library and `modules/Diagnostics.lua` | Every line of a `/pm diagnostics` report, written in full through the ungated append |
| `Set` | the library's schema seam; `core/Database.lua` | `[Set] <path> = <value>` once per settings write, and `[Set] panel.<field> = <value> on '<panel>'` once per panel field write (the editor, `/pm panel`, a drag-stop's four fields, a fit's two); one line per bulk copy or reset; one per profile reset or copy (see *Bulk copy and reset*) |
| `Profile` | `core/Database.lua` | `switched to '<name>', N panels`, on a profile switch |
| `Migrate` | `core/Database.lua` | A schema migration, only when one runs (at load) |
| `Preview` | `core/Database.lua` | `swept N orphaned preview panel(s)`, at load, only when there were some |
| `Lifecycle` | the library (Lifecycle), through `core/LifecycleSetup.lua`'s `debug` | `stood down: added <key> (holds: <set>)` and `stood up: released <key> (holds: none)`, one line per stand-down or stand-up edge, before the callback runs. A call that fires no edge writes nothing. `NS.StandDown` and `NS.StandUp` write no line of their own |
| `Cmd` | the library (Slash), through `settings/Slash.lua`'s `debug` | `refused <verb>[ <arg>]: <guard>` after the chat line, for every refusal the dispatcher decides: `disabled` (a feature verb while the addon is off), `unknown verb`, `usage`, `not found`, `parse`, `write refused`, `no default`, and the profile verb's `unavailable`, `already current`, `in combat` and `unknown profile` |
| `Events` | `core/LifecycleSetup.lua` | `rejected <name>`, an event name the client refused at a stand-up |
| `Panel` | `modules/Registry.lua` | Every structural panel mutation: created, deleted, deleted all, renamed. A field write is the seam's `[Set]` line, never a second `[Panel]` one |
| `Panel` | `modules/Registry.lua` (`refuse`) | `<verb> refused: <reason>` for create, delete, reset, copy, rename, fit, set and move, and `set '<panel>'.<field> refused: <reason>` for a value the field's coercer rejected. The reason is the one the caller prints |
| `Panel` | `modules/Registry.lua` (`R:Recover`, through `refuse`) | `recover refused: cannot measure the screen`, when the client reports no screen size and `/pm recover` moves nothing. The slash prints the same reason rather than "every panel is already on screen" |
| `Panel` | `settings/Slash.lua` (`Sl:CliPanel`, through `R.Refuse`) | `panel refused: no panel called '<name>'` and `panel refused: unknown field '<field>'`, the two `/pm panel` refusals made before any Registry verb runs |
| `Panel` | `settings/Panel.lua` (`safeRun`) | `<closure> failed: <error>`, a settings-page closure that raised, once per closure and distinct error per logging session |
| `Canvas` | `modules/Canvas.lua` | `rendered N panels, M shown`, once per full rebuild. M is how many the show ladder left visible, so a hidden panel reads differently from a missing one |
| `Canvas` | `modules/Canvas.lua` (`RenderForCombat`) | `combat entered` / `combat left: repainting for visibility '<mode>'`, only when the visibility setting depends on combat. Under `Always` or `Never` the renderer ignores the edge, so it writes nothing |
| `Canvas` | `core/PanelMaster.lua` (`OnEnterWorld`) | `entered world: repainting`, on every loading screen, ahead of the rebuild it causes |
| `Canvas` | `core/Compat.lua` | `MouseIsOver failed: <error>`, once per distinct error the mouseover tick's `pcall` swallows; `<type> texture '<name>' not found: drawn as Solid`, once per media type and name |
| `Unlock` | `modules/Unlock.lua` | `panels unlocked` / `panels locked` (with `, N held unlock(s) dropped` when a lock discarded combat-held requests), and `'<panel>' unlocked` / `locked` per panel |
| `Unlock` | `modules/Unlock.lua` | The combat hold: `unlock all held: in combat`, `'<panel>' unlock held: in combat`. The flush: `combat over: flushed held unlocks (all=yes/no, N panel(s), M gone)`, only when something was held. A drop: `dropped N held panel unlock(s): profile changed` |
| `Artwork` | `modules/SunnArt.lua` | `Sunn adapter: N themes, M rows`, found at OnEnable and written through the at-enable queue, so it lands the first time logging is turned on |
| `Cfg` | the library (Options), through `settings/OptionsSetup.lua`'s `debug` | `register parked (in combat)` and `register flushed (combat ended)`, `open refused (in combat)`, `opened`, and the combat lock's `<what> refused (in combat)` for a write, a Defaults, a button, a tab, a rail or banner click, an id-list change or a page shown under the lock, once per text per combat |
| `Launcher` | the library (Launcher), through `core/LauncherSetup.lua`'s `debug` and `debugAtEnable` | Its state lines (`registered`, a broker library absent, no minimap table) through the at-enable queue; its events (`shown`, `hidden`, a menu refusal, a raise) as they happen |

**Repeating paths.** The only steady-state repeating path is the shared 10Hz mouseover `OnUpdate`
(`modules/Canvas.lua`). It writes nothing per tick, and the one error it can swallow is a single
line (`NS.DebugOnce`). The other repeats are driven by the player or by edges: a slider drag writes
one `[Set]` line per applied step, each with its new value, followed by the `[Canvas]` rebuild it
caused; a combat edge or a loading screen writes its edge line and one rebuild. None of them logs
when nothing happened.

**Not logged here, on purpose.** A `/pm set` the dispatcher refuses and a feature verb refused
while the addon is disabled are the library's `[Cmd]` lines, so this addon adds none: the host puts
no wrapper in front of either seam (`settings/Slash.lua`). The disabled state itself is in the log
as the `[Lifecycle] stood down: added disabled (holds: disabled)` line, and in the report's `state`
section. The client state edges this addon does not react to (group roster, spec, addon
restriction) have no line: an edge the addon ignores needs none.

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

`NS.DebugOnce(site, key, tag, fmt, ...)` is the third seam, for a line that must land **once per
distinct key** however often its site runs: an error a `pcall` swallows on the mouseover tick, a media
name that falls back to Solid on every repaint, a settings-page closure that raises on every refresh.
It reads the same flag first, and the memory is the **console's** change gate (`D.DebugOnce`,
LibKa0s v1.65.0), which remembers nothing while logging is off, so a key met then still logs the
first time logging is on. The console re-arms it on every logging enable **and on Clear**, so the
support sequence of turning logging on (or clearing), reproducing and copying shows an error that
still recurs, even if an earlier session already logged it. This addon kept a seen-set of its own
until then, which a Clear could not reach; it was deleted with the adoption. `site` and `key` are
separate arguments so that a site erroring on every pass builds no string while logging is off:
they are joined into the gate's one key only past the flag test.
