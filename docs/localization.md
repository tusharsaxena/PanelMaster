# Localization

`locales/enUS.lua` publishes `NS.L` with a metatable whose `__index` returns the key itself, so an
unwrapped or untranslated string renders as its English source rather than erroring or showing a raw
token (`localization-§1`). Keys **are** the English source strings (`localization-§2`), which is why
the US-English sweep mattered: a locale key is the one place a spelling is not merely cosmetic, and
renaming one later means moving every key and every call site in a single change.

`locales/PostLoad.lua` loads after every locale file and holds derived-key aliases — strings whose
translation always matches another key's — so a translator never does the same work twice.

**English-only remains the shipped scope, and `locales/enUS.lua` carries no keys.** Almost every
label, tooltip and message is hardcoded English — a scope decision rather than an oversight, and
precisely what made the US-English sweep cheap, since there were no keys to move alongside the
strings. A later pass can wrap them (`NS.L["Show names while unlocked"]`) without touching call
sites, because the seam and its key-returning metatable are already here.

**The one key that used to be here is gone, and its absence is the entry.** The **disabled-verb
refusal** (`settings/Slash.lua`) was declared in `locales/enUS.lua` in this addon's own wording.
`slash-commands-§7` then fixed that line's shape for the whole collection — `<BrandName> is disabled
— enable it with /<slash> enable` — and `LibKa0s-Slash-1.0` builds it from
`lib.DISABLED_LINE_FORMAT`. The library's own contract says the locale override a host passes **does
not reach** that line: the wording is the collection's, not the addon's, and eleven addons each
translating it slightly differently is the drift the one shared formatter exists to end. So nothing
here overrides it and the dispatcher is asked for the line rather than handed one.

What a translator gets in it instead is the **brand name** — which `launcher-§1` already forbids
escapes in, which is exactly what makes it safe to drop into a colored line — and that is a name, so
the rule below keeps it untranslated too.

Two things must **never** be routed through `NS.L`:

| Not localized | Why |
|---|---|
| Panel names | User-supplied data, not UI strings. A user's "Chat" is their text, and translating it would rename their panel — silently, behind their back, in every list and dropdown. (It would no longer move the `PanelMaster_Panel_<slug>` frame name, which is stamped at create, so external anchors would survive — but a panel that relabels itself when the client language changes is its own problem.) |
| Stored `point` / `strata` tokens | Matched on stable identifiers, never on a localized display string (`localization-§4`). A dropdown may show a translated label, but the value written to SavedVariables stays `TOPLEFT` / `LOW`. |
