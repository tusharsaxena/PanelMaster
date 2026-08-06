# Slash dispatch

`/pm` (and the `/panelmaster` alias) via AceConsole. Every verb comes from `NS.COMMANDS` in
`settings/Slash.lua`, so the help index, the settings landing page's command list and the README
table are all generated from one table and cannot drift.

Schema-driven verbs: `config version get set list reset resetall debug help`.
Panel verbs: `new delete rename panels panel unlock lock preview recover`.

`/pm panel <name> [field] [value]` inspects and edits a single panel from the command line, using the
same `Registry:Set` seam the settings widgets and the drag handler use.

Output follows `slash-commands-§4/§5`: the cyan `[PM]` tag on every line, green headers, azure
`[group]` headers, gold keys, white values, no trailing colons. `Slash:BuildListLines`,
`BuildPanelLines` and `BuildPanelShowLines` return arrays rather than printing, so the output shape
is asserted in tests without capturing chat.

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
