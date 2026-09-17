# Slash dispatch

`/pm` (and the `/panelmaster` alias) via AceConsole. Every verb comes from `NS.COMMANDS` in
`settings/Slash.lua`, so the help index and the settings landing page's command list are generated
from one table and cannot drift. This file describes the dispatch, not the list: `/pm help` prints
the list itself.

A bare `/pm` (nothing typed, or only whitespace) runs the `config` row with an empty argument and
opens the settings landing page; `/pm help` prints the index (`slash-commands-§4`). That rule is the
library's dispatcher. The degraded stub in `settings/Slash.lua`, used when LibKa0s is missing, follows
it too, and prints help only if the table has no `config` row.

Schema-driven verbs: `config version get set list reset resetall debug enable disable help`.

`enable` and `disable` are **aliases, not a second switch** (`slash-commands-§2`). Both write
`NS.Schema.ENABLED_PATH` — `settings.enabled`, the very path the *Enable Ka0s Panel Master*
checkbox writes — through the very seam it writes through, and hold no state of their own. They go
through `Sl:CliSet`, so `/pm enable` is literally `/pm set settings.enabled true`: the same write
and the same canonical `path = value` echo, read back from the store after the write.

**The whole reserved surface survives the disabled state**, and that is the ruling rather than a
convenience. `Sl:Register` and `P:Register` run unconditionally from `OnInitialize`, so while the
addon is off a bare `/pm` **opens the settings panel** and `help`, `config`, `version`, `enable`,
`disable`, `debug`, `perf`, `get`, `set`, `list`, `reset` and `resetall` all answer normally —
reading and repairing settings included, which is precisely when a player most needs them.

Standard v2.56.0 narrowed that to `enable` and `help`; v2.57.0 **reversed it**, on the case that
`/pm` on a disabled addon answered with a refusal instead of the one surface a player uses to switch
it back on by hand. This addon carries the restored set and narrows nothing: the descriptor passes
**no `liveVerbs`**, so the live set is `lib.LIVE_VERBS` — the standard's twelve reserved verbs at
Slash minor 13 — and `Sl.ALWAYS_LIVE` is a *read* of that array rather than a second source for it.

**A disabled addon refuses its FEATURE verbs**, on one tagged line naming `/pm enable`, and does
nothing else (`slash-commands-§2`; a SHOULD, taken here). Everything else — `new delete rename
panels panel unlock lock recover` — refuses. **The gate is the library's**: the descriptor passes
`isEnabled` (asked at dispatch time, never cached) and `brandName`, and at Slash 13 the dispatcher
gates *after* the `COMMANDS` lookup, so only a verb this addon actually ships is refused and a
**typo still falls through** to `unknown command` and the help index (`slash-commands-§3`). The
degraded stub, which has no library to route to, keeps a host-side wrap of `NS.COMMANDS` and
reproduces the format string byte for byte; `tests/test_libka0s.lua` compares the two.

The refusal line is **the collection's, not this addon's** — `Ka0s Panel Master is disabled — enable
it with /pm enable`, built by `lib.DISABLED_LINE_FORMAT` from `NS.BRAND`, which is the same string
the LDB object takes as its `label` (`launcher-§1`). It used to be this addon's own wording routed
through `NS.L`; it is not translated now, because the library's contract is that a host locale
override does not reach it (`docs/localization.md`).

`/pm help` while disabled prints the **whole index**, headed by that same line as a state note. That
is an answer with a note above it, not a refusal.
Panel verbs: `new delete rename panels panel unlock lock recover`.

There is no `test` verb. Unlocking is this addon's test mode (`options-ui-§15`): it shows every
panel with its outline and name, so `/pm unlock` and `/pm lock` are the switch.

`lock` and `unlock` are **reserved** and the pair is a **MAY** this addon takes (`slash-commands-§8`,
the canonical full-pair shape). Like `enable` / `disable` they are aliases and hold no state of
their own: both write `state.locked` through `NS.Schema:Set` — the same path and the same seam the
Master-controls *Lock frame* checkbox and the minimap button's left click write through — so
`/pm unlock` is literally `/pm set state.locked false` and confirms in the shared `path = value`
shape. The echo is read back **after** the write, which matters here: `NS.Unlock:SetUnlocked`
defers an unlock requested in combat, so the line reports `state.locked = true` rather than claiming
something that did not happen. They are **feature verbs**, so a disabled addon refuses them —
unlocking a frame that is not drawn is not a coherent request.

`/pm panel <name> [field] [value]` inspects and edits a single panel from the command line, using the
same `Registry:Set` seam the settings widgets use (the drag handler takes `Registry:SetPosition`).

Two words in that grammar are **actions rather than fields**, and they are ordered oppositely.
`fitart` is checked *before* the field table; `deleteall` is checked *after* the panel registry. `/pm panel <name> fitart` is the CLI half of the editor's **Fit to artwork**
button; nothing is ambiguous about it because no panel field is called `fitart` and none can be.
`/pm panel deleteall` is the confirm-gated wipe of every panel, and it is the verb **only when no
panel answers to that name** — a panel someone called "deleteall" still wins, so it can be inspected
and edited from the CLI rather than being unreachable.

Output follows `slash-commands-§4/§5`: the cyan `[PM]` tag on every line, green headers, azure
`[group]` headers, gold keys, white values, no trailing colons. `Slash:BuildListLines`,
`BuildPanelLines` and `BuildPanelShowLines` return arrays rather than printing, so the output shape
is asserted in tests without capturing chat.

## The `/pm panel` fields

The fields `/pm panel` accepts are `name`, `enabled`, `width`, `height`, `point`, `relPoint`,
`x`, `y`, `strata`, `level`, `scale`, `alpha`, `bgTexture`, `bgColor`, `bgClassColor`, `borderTexture`,
`borderSize`, `borderOffset`, `borderColor`, `borderClassColor`, `mouseover`, `mouseoverAlpha`,
`accentEnabled`, `accentEdges`, `accentTexture`, `accentAlpha`, `accentThickness`, `accentOffset`,
`accentColor`, `accentClassColor`, `accentBorderTexture`, `accentBorderSize`, `accentBorderOffset`,
`accentBorderColor`, `accentBorderClassColor`, `artTexture`, `artCustomPath`, `artColor`,
`artClassColor`, `artAlpha`, `artFill`, `artPoint`, `artX`, `artY`, `artScale`, `artRotation`,
`artFlipH`, `artFlipV`, `artDesaturate`, `artBlend` and `artLayer`. So:

```
/pm panel ChatBG width 420
/pm panel ChatBG bgColor 0.1,0.1,0.12,0.8
/pm panel ChatBG bgTexture blizzard marble
/pm panel ChatBG borderClassColor on
/pm panel ChatBG strata LOW
/pm panel ChatBG accentEnabled on
/pm panel ChatBG accentEdges top,left
/pm panel ChatBG artTexture class-death-knight
/pm panel ChatBG artFill FILL
```

Colors take either `r,g,b` or `r,g,b,a`, in 0–1 or 0–255 — `1,0,0,0.5` and `255,0,0,128` both mean
half-transparent red. Which of the two scales you meant is decided by R, G and B alone; an alpha of
1 or less is read as a fraction under either, so `255,0,0,1` is opaque red rather than a red you
cannot see. Texture names are whatever LibSharedMedia has, and are matched however you type the
capitals. `accentEdges` takes a comma list of `top`, `bottom`, `left`, `right`, or `none` for no bars
at all. `artTexture` takes the id of a bundled artwork (matched however you type the capitals),
`None`, or `Custom`; the five `art*` dropdown fields refuse anything that is not one of their values
and print the real list back at you.

## What the library owns, and what stays here

`settings/Slash.lua` is the `LibKa0s-Slash-1.0` seam. The dispatcher, the generated help index, the
landing-page row formatter, the schema CLI (`list`/`get`/`set`/`reset`/`resetall`/`version`) and the
type-aware value parser are the **library's**.

**`NS.COMMANDS` stays this addon's** — positional `{ name, description, handler }` triples, passed in
rather than owned. Two reasons, and the second is structural: the settings landing page renders the
same rows, and a library that owned the table would force the options major to resolve the slash
major to read it.

Every **panel** verb stays here too — they act on registry records, not schema rows, so there is
nothing for the schema CLI to do with them.

Two descriptor adapters bridge the difference:

- **`groupKey`** — this schema groups by `row.group`; the library defaults to `row.page`.
- **`parse`** — the library matches an enum case-sensitively. This adapter matches the typed value
  against the row's own `values` without regard to case and hands the library the spelling the row
  stores, so `/pm set settings.defaultStrata low` stores `LOW` and
  `/pm set settings.visibility incombat` stores `inCombat`. The whole value must match (LibKa0s
  Slash minor 10), so `low junk` is refused rather than stored as `LOW`.
