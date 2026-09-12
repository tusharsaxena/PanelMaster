# Slash dispatch

`/pm` (and the `/panelmaster` alias) via AceConsole. Every verb comes from `NS.COMMANDS` in
`settings/Slash.lua`, so the help index and the settings landing page's command list are generated
from one table and cannot drift. This file describes the dispatch, not the list: `/pm` prints the
list itself.

Schema-driven verbs: `config version get set list reset resetall debug help`.
Panel verbs: `new delete rename panels panel unlock lock preview recover`.

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
- **`parse`** — the library matches an enum case-sensitively, and
  `/pm set settings.defaultStrata low` has always worked here.
