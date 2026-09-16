# Localization

`locales/enUS.lua` publishes `NS.L` with a metatable whose `__index` returns the key itself, so an
unwrapped or untranslated string renders as its English source rather than erroring or showing a raw
token (`localization-§1`). Keys **are** the English source strings (`localization-§2`), which is why
the US-English sweep mattered: a locale key is the one place a spelling is not merely cosmetic, and
renaming one later means moving every key and every call site in a single change.

`locales/PostLoad.lua` loads after every locale file and holds derived-key aliases — strings whose
translation always matches another key's — so a translator never does the same work twice.

**English-only remains the shipped scope, and one string now routes through the seam.** Almost every
label, tooltip and message is still hardcoded English — a scope decision rather than an oversight,
and precisely what made the US-English sweep cheap, since there were no keys to move alongside the
strings. The exception is the **disabled-verb refusal** (`settings/Slash.lua`, `slash-commands-§2`),
declared in `locales/enUS.lua` as:

```lua
NS.L["the addon is disabled \226\128\148 %s turns it back on"]
```

It is listed there rather than left to the metatable — which would resolve it identically — because
it is the only entry a translator has to find, and because the `%s` is a **contract**: the call site
substitutes the gold-wrapped `/pm enable`, so a translation that drops the placeholder loses the one
thing the line exists to name. The slash command is not part of the key for the same reason. The
seam is otherwise unchanged, and a later pass can wrap the rest
(`NS.L["Show names while unlocked"]`) without touching call sites.

Two things must **never** be routed through `NS.L`:

| Not localized | Why |
|---|---|
| Panel names | User-supplied data, not UI strings. A user's "Chat" is their text, and translating it would rename their panel — silently, behind their back, in every list and dropdown. (It would no longer move the `PanelMaster_Panel_<slug>` frame name, which is stamped at create, so external anchors would survive — but a panel that relabels itself when the client language changes is its own problem.) |
| Stored `point` / `strata` tokens | Matched on stable identifiers, never on a localized display string (`localization-§4`). A dropdown may show a translated label, but the value written to SavedVariables stays `TOPLEFT` / `LOW`. |
