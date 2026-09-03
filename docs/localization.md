# Localization

`locales/enUS.lua` publishes `NS.L` with a metatable whose `__index` returns the key itself, so an
unwrapped or untranslated string renders as its English source rather than erroring or showing a raw
token (`localization-§1`). Keys **are** the English source strings (`localization-§2`), which is why
the US-English sweep mattered: a locale key is the one place a spelling is not merely cosmetic, and
renaming one later means moving every key and every call site in a single change.

`locales/PostLoad.lua` loads after every locale file and holds derived-key aliases — strings whose
translation always matches another key's — so a translator never does the same work twice.

**Both files are deliberately empty of keys in 1.0.0.** No user-facing string routes through `NS.L`
yet; every label, tooltip and message is hardcoded English. That is a scope decision for the first
release rather than an oversight, and it is precisely what made the US-English sweep cheap to do —
there were no keys to move alongside the strings. The seam is kept so a later pass can wrap strings
(`NS.L["Show names while unlocked"]`) without touching call sites. There is no `local L` alias until the first
string is wrapped, so the file stays luacheck-clean.

Two things must **never** be routed through `NS.L`:

| Not localized | Why |
|---|---|
| Panel names | User-supplied data, not UI strings. A user's "Chat" is their text, and translating it would rename their panel — silently, behind their back, in every list and dropdown. (It would no longer move the `PanelMaster_Panel_<slug>` frame name, which is stamped at create, so external anchors would survive — but a panel that relabels itself when the client language changes is its own problem.) |
| Stored `point` / `strata` tokens | Matched on stable identifiers, never on a localized display string (`localization-§4`). A dropdown may show a translated label, but the value written to SavedVariables stays `TOPLEFT` / `LOW`. |
