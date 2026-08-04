# Ka0s Panel Master — Code Review Findings (2026-08-03)

**Verdict: minor issues.** The addon is coherent, well-layered, green on both gates
(`lua tests/run.lua` → 696/696, `luacheck .` → 0/0) and its LibKa0s adoption is real rather than
decorative. **One** defect is worth blocking a release for, and it only bites an install that is
missing `libs/LibKa0s`: the slash degradation stub omits a member five panel-CLI call sites use, so
every `/pm panel …` verb raises a Lua error there. Everything else is maintainability, dead surface
and documentation drift.

**Standards cross-check: performed.** Remediation in `02_PROPOSED_CHANGES.md` was vetted against the
Ka0s WoW Addon Standard **v2.17.1 (2026-08-03)**. The `curl` fetch from
`raw.githubusercontent.com` timed out in this environment; the standard was read instead from the
local clean `master` checkout of `WowAddonStandards` (same commit, `2141229`, working tree clean),
which is byte-identical to what the fetch would have returned. No rule was reconstructed from
memory.

**Scope:** whole repo, excluding `libs/` and `tests/_kit/` as implementation (vendored, read-only).
Their **consumption seams** — `core/CoreSetup.lua`, `core/DebugLogSetup.lua`, `settings/Slash.lua`,
`settings/OptionsSetup.lua` — were reviewed as this addon's code, which is where F-001 lives.

**No upstream (`[upstream]`) findings were raised.** Nothing defective was found inside
`libs/LibKa0s/`, `libs/Ace*`, `libs/LibSharedMedia-3.0` or `tests/_kit/`, and the vendor-sync gate
(`tests/test_vendor_sync.lua`) passes, so the vendored copy is byte-identical to LibKa0s v1.5.0.

**Areas found clean** — stated explicitly so absence of findings is not mistaken for absence of
review:

- **Taint / combat.** No protected API is called anywhere. Panels are non-secure frames, correctly
  documented as such (`modules/Canvas.lua:9-12`). The one combat gate that exists — unlock —
  is a UX gate, deferred and replayed on `PLAYER_REGEN_ENABLED` (`core/PanelMaster.lua:89-91`,
  `modules/Unlock.lua:220-239`), and `settings/Panel.lua:488` refuses rather than defers the options
  open, which is the options-ui-§2 shape. `InCombatLockdown()` is used (never
  `UnitAffectingCombat`), correctly, in all three places.
- **Secret values.** Every chat line goes through the shared `NS.Print` (a file-local `local print =
  NS.Print` in six files); no bare global `print(` survives anywhere under `core/ defaults/ locales/
  modules/ settings/`.
- **Deprecated APIs.** `core/Compat.lua` owns all of them and guards `C_AddOns.*` with a bare-global
  fallback. No `GetSpellInfo`, `UnitAura`, `GetContainerItemInfo`, `IsAddOnLoaded`,
  `InterfaceOptions_AddCategory` or `SetBackdrop`-without-`BackdropTemplate` anywhere.
- **Event registration.** Events are registered in `OnEnable`, with the one `PLAYER_LOGIN`
  subscription deliberately in `OnInitialize` and the reason written down
  (`core/PanelMaster.lua:45-50`) — that reasoning is correct.
- **Frame pooling / leaks.** `modules/Canvas.lua` pools by global frame name, releases inert (clears
  textures and backdrops, untracks the mouseover ticker), and lazily creates the accent border and
  extra art textures. No `setmetatable` on a widget. `ClearAllPoints` precedes every re-anchor.
- **Bus discipline.** Each message has exactly one sender; each receiver owns a private
  `NS.NewBusTarget()` target (`modules/Canvas.lua:698-706`, `settings/PanelEditor.lua:1029-1051`) —
  anti-pattern #32 is actively avoided.
- **Single write path.** `NS.Schema:Set` (settings) and `NS.Registry:Set` (panel records) are the
  only write seams, and both the slash CLI and the options panel are routed through them via the
  LibKa0s descriptors. No `db.profile.x = y` bypass exists outside those two files.
- **Localization.** `NS.L` metatable fallback is in place and the English-only scope decision is
  recorded (`locales/enUS.lua:8-12`). Game data is matched on `classFile`, never a localized name
  (`core/Compat.lua:86-99`). The `L` trap is guarded by a live tripwire test.
- **`COMMANDS` ↔ README.** All 18 entries of `NS.COMMANDS` appear in the README table and vice
  versa; every sub-verb (`fitart`, `deleteall`, `on`/`off`/`dump`) is named in its own `desc`.

**Observed but deliberately NOT raised** (pre-existing standard conformance, unrelated to the
defects below — that is `wow-addon:standards-audit`'s job, not this review's): several chat call
sites pre-concatenate their arguments before handing them to `NS.Print`
(e.g. `settings/Slash.lua:48`, `settings/PanelEditor.lua:91`), which events-frames-taint-§8 asks
call sites not to do; and no `core/PerfSetup.lua` exists, i.e. `LibKa0s-Perf-1.0` is vendored but
not wired (a decision recorded in `CLAUDE.md`). Neither is a bug in anything below.

---

## High

### F-001 — The slash degradation stub omits `FormatKV`, so every `/pm panel` verb crashes in a LibKa0s-less install `[design]`

**Where:** `settings/Slash.lua:273-305` (the stub) vs. `settings/Slash.lua:101`, `:156`, `:157`,
`:169`, `:176` (the callers) and `settings/Slash.lua:369` (`Sl.FormatKV = lib.FormatKV`, live path
only).

**Problem:** the `if not lib then … return end` fallback publishes `PrintHelp`, `BuildListLines`,
`CliList/Get/Set/Reset`, `LandingRows`, `HelpRows`, `CliVersion`, `CliResetAll` and `OnSlash` — but
not `FormatKV`, which is assigned **after** the early `return` and is used by the *host-owned* panel
verbs the stub's own comment promises "keep working".

**Impact:** in an install where `libs/LibKa0s` is missing or has been pruned by a repackager,
`/pm panel <name>`, `/pm panel <name> <field>`, `/pm panel <name> <field> <value>` and
`/pm panel <name> fitart` all raise `settings/Slash.lua:101: attempt to call field 'FormatKV'
(a nil value)`. This is exactly "a stub that omits a member is not a fallback — it is a crash moved
to a rarer code path" (debug-logging-§7, the same rule slash-commands-§1 states for this module).

**Evidence — reproduced headlessly** by loading the whole addon with the library files absent (the
same technique `tests/test_libka0s.lua`'s `loadDegraded` uses):

```
Slash.FormatKV = nil
Slash.Text     = nil
CliPanel dump  ok= false  err= settings/Slash.lua:101: attempt to call field 'FormatKV' (a nil value)
CliPanel field ok= false  err= settings/Slash.lua:169: attempt to call field 'FormatKV' (a nil value)
CliPanel set   ok= false  err= settings/Slash.lua:176: attempt to call field 'FormatKV' (a nil value)
```

**Secondary:** `Sl:Text` is likewise absent from the stub (`settings/Slash.lua:363` is live-path
only). It has no production caller today, so it is not a crash — but it is in the same class and
should be decided deliberately rather than left to chance.

**Why the suite did not catch it:** `tests/test_libka0s.lua:479-560` exercises the degraded path for
Core, DebugLog and Options — including a per-member sweep for the console — but has no equivalent
member sweep for the Slash stub and never drives a panel verb through it. testing-§8 requires the
degraded path be verified by *actually loading the addon with the lib missing*; that half is done,
the coverage half is not.

**Fix direction:** publish `FormatKV` from the stub. It **MUST NOT** be a copy of the library's
`key = value` rendering — slash-commands-§1 forbids "a copied `key = value` shape" in the stub
precisely because that copy is the one that goes stale — so the compliant form is a plainly
degraded, visibly different line, plus a degraded-path test that pins the stub's member set against
the call sites.

---

## Medium

### F-002 — `Registry.Sanitize` silently skips `artDesaturate` and `artBlend` `[logic]`

**Where:** `modules/Registry.lua:83-208` (the function and its "Fill every missing field from the
template" contract at `:76-82`); the two fields are declared at `core/Constants.lua:379` and `:382`,
typed at `:448`, and listed in the dump order at `:491`.

**Problem:** every other template field is normalized — the other four art enums go through
`enumMatch` at `:203-205` — but these two are never touched. `artDesaturate` is never filled from
the template and `artBlend` is never validated against `C.ART_BLEND`.

**Impact:** a record that predates those fields (an upgraded install, a profile copied from an older
build, an imported or hand-edited `SavedVariables`) reaches the UI with `artDesaturate = nil` and
whatever `artBlend` the file contained. `/pm panel <name>` prints `artDesaturate = nil`; the
editor's Desaturate checkbox reads unticked and its Blend dropdown shows no selection
(`settings/PanelEditor.lua:853`, `:858`). An illegal `artBlend` survives every write, so the stored
file is *not* "always already valid" as `modules/Registry.lua:80-82` claims. Rendering itself is
safe — `modules/Artwork.lua:1077-1078` re-guards both — which is why nothing errors and why this has
gone unnoticed.

**Evidence — reproduced headlessly:**

```
artBlend after Sanitize      = MOD      -- not a member of C.ART_BLEND
artDesaturate after Sanitize = nil
FormatField artBlend         = MOD
FormatField artDesaturate    = nil
```

**Fix direction:** normalize both in `Sanitize` alongside the other art fields — `artBlend` through
the existing `enumMatch` seam (its `C.PANEL_FIELD_ENUM` row already exists at
`core/Constants.lua:466`), `artDesaturate` with the same `and true or false` coercion the other
booleans use. This is a repair inside the existing single write path, so it introduces no new
deviation; savedvariables-§1's migration runner is deliberately **not** the right home, because
`Sanitize` is the seam every non-login write route already passes through.

### F-003 — `SunnArt.Installed()` is a dead export whose docstring claims it gates the feature `[dead-code]`

**Where:** `modules/SunnArt.lua:246-248`.

**Problem:** zero production callers (`grep` across `core/ defaults/ locales/ modules/ settings/`
returns only the definition; the seven other hits are in `tests/test_sunnart.lua`). Its own comment
says it is "Used to keep the whole feature silent on a machine without it — no category, no rows, no
settings copy about an addon the player does not have", which describes behavior nothing implements.

**Impact:** a reader trusts the comment and assumes a gate exists. It also carries a real cost if it
is ever called casually — it runs a full `S.Themes()` scan (globals merge, addon-roster read, sort)
to answer a boolean.

**Fix direction:** either give it its one intended caller, or delete it and the comment together. If
it is kept only for the suite, rename it to the `__` test-seam convention this addon already uses
deliberately for exactly this case (`modules/Unlock.lua:273-284` explains the convention and why).

### F-004 — README and smoke-test doc reference an artwork id that no longer exists `[ux]`

**Where:** `README.md:115` (`/pm panel ChatBG artTexture runic-sigil`) and
`docs/smoke-tests.md:223` (`Set Artwork to "General: Runic Sigil (B&W)"`).

**Problem:** `runic-sigil` was the seed catalog entry; the generated catalog
(`modules/Artwork.lua:54-562`) now contains only `class-*`, `expansion-*`, `faction-*`, `other-*`
and `race-*` ids, and there is no `General` category at all.

**Impact:** a user copying the README's worked example gets `unknown artwork. Available: …` — the
first artwork command in the documentation fails. The smoke-test step cannot be executed at all,
which silently weakens the manual gate.

**Fix direction:** point both at a real id (e.g. `class-mage` / `Class: Mage`). The README's
command-table conventions (documentation-§1, no `<…>` placeholders) are already correct and must
stay that way in the edit.

### F-005 — A `/pm panel set …` CLI grammar that does not exist is documented in four places `[naming]`

**Where:** `core/Util.lua:81`, `core/Constants.lua:151`, `core/Constants.lua:420`,
`modules/Artwork.lua:603`, and — the one that is user-facing — `docs/smoke-tests.md:296`.

**Problem:** the real grammar is `/pm panel <name> <field> <value>` (`settings/Slash.lua:106-177`).
There is no `set` sub-verb; `Sl:CliPanel` reads the first word as the panel key, so
`/pm panel set Chat width 400` resolves the *panel named "set"* and answers `no panel called 'set'`.

**Impact:** the smoke-test step at `docs/smoke-tests.md:296` fails for the wrong reason (a name
lookup, not the enum refusal it is testing), so it verifies nothing. The four code comments teach a
future maintainer a grammar the dispatcher does not implement.

**Fix direction:** correct the five strings to the actual grammar. No code change.

---

## Low

### F-006 — `C.MEDIA_FALLBACK` has no readers anywhere `[dead-code]`

**Where:** `core/Constants.lua:510-514`.

`grep -rn MEDIA_FALLBACK` returns exactly one hit — the definition. The rule it states ("what a media
field falls back to") is actually implemented by `Compat.FetchMedia`
(`core/Compat.lua:129-135`), which returns `C.SOLID_TEXTURE` directly. Two statements of one rule,
one of them dead and therefore free to drift.

**Fix direction:** delete it, or make `Compat.FetchMedia` read it. Deleting is the smaller change and
loses nothing.

### F-007 — `NS.Format` is published with zero callers `[dead-code]`

**Where:** `core/CoreSetup.lua:86`.

`printer.Format` is re-published on the namespace beside `NS.Print`, but nothing in the addon — or
in the suite — ever reads `NS.Format`. Note the degradation stub at `core/CoreSetup.lua:34-69` does
**not** provide it, so it is also an asymmetry between the two paths: if a caller ever appears, it
crashes in a degraded install for the same reason F-001 does.

**Fix direction:** drop it, or (if it is intended as a published seam) add it to the stub and state
the intent in the comment that already enumerates the four members the stub must answer
(`core/CoreSetup.lua:36-38`).

### F-008 — `docs/ARCHITECTURE.md` under-documents a bus message's consumers `[docs]`

**Where:** `docs/ARCHITECTURE.md:288` lists `Canvas` as the only consumer of
`Ka0s_PanelMaster_PanelChanged`; `settings/PanelEditor.lua:1045-1048` is a second consumer (it
drives the editor's in-place scalar refresh).

architecture-§4 makes documenting **all** consumers a MUST. The `PanelsChanged` row on the line above
gets this right, which is what makes the omission look like drift rather than a decision.

### F-009 — A failure reason is carried in a variable named `w` `[naming]`

**Where:** `settings/Slash.lua:152-160` and `settings/PanelEditor.lua:768-777`.

`NS.Registry:FitToArtwork` returns `(true, width, height)` or `(false, reason)`, so both call sites
end up with `print(w)` where `w` is a sentence. Both carry a comment explaining it, which is the tell
that the names are wrong rather than the code. `local ok, a, b` or an explicit
`local ok, widthOrReason, height` reads honestly.

### F-010 — Registry lookups are linear, making a full rebuild quadratic `[perf]`

**Where:** `modules/Registry.lua:248-278` (`R:Get`, `R:FindByName`, `R:Resolve`, all O(N) scans),
consumed by `modules/Canvas.lua:673-686` (`RenderAll` calls `Canvas:Render(id)` per record, each of
which calls `R:Get`) and by `R:Set` / `R:SetPosition` on every slider mouse-up and drag stop.

At realistic panel counts (the README's own framing is "a few deliberate groups") this is
unmeasurable — 30 panels is 900 integer comparisons per structural rebuild — and the file explicitly
argues against an index for the catalog for good reasons. **Recorded as a known shape, not a defect
to fix now**: it is worth knowing before anyone raises the panel cap or adds a per-frame caller. An
id→record map would have to be invalidated on every create/delete/profile-switch, which is more
machinery than the current cost justifies.
