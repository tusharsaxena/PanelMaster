# 02 — Candidates: LibKa0s v1.34.0

Sources: `git -C ../LibKa0s log --oneline v1.33.0..v1.34.0`, the v1.34.0 block of
`../LibKa0s/CHANGELOG.md`, `../LibKa0s/docs/releasing.md` ("Re-vendoring consumers"),
`../LibKa0s/docs/api/Slash/version-10-docs.md`, `../LibKa0s/docs/api/Options/version-18.15.5.3-docs.md`
and `../LibKa0s/docs/api/testkit/version-19-docs.md`.

## Class A: reached the addon on the re-vendor alone

- **The whole-value string parse (Slash minor 10).** **Reached, through the `parse` adapter.** The
  adapter (`settings/Slash.lua:428`) upper-cases the whole value of a `string` row that declares
  `values`, then delegates to `lib.ParseValue`. Minor 9 matched only the first token, so
  `/pm set settings.defaultStrata low junk` stored `LOW`. Minor 10 matches the whole string, so
  `LOW JUNK` is refused with `allowed values: …` and nothing is written. That is more correct, and it
  is kept. `low` on its own still stores `LOW`. `settings.defaultStrata` (`settings/Schema.lua:120`)
  is the schema's one declared `string` row, and its tokens are single words, so no row newly keeps a
  multi-word value. The docs describe the case-insensitive token (`docs/slash-dispatch.md:76`,
  `docs/module-map.md:32`), never the trailing-word tolerance, so they do not move. The refusal is
  pinned in its own commit (see `03_DECISIONS.md`).
- **The *Reset all settings* tooltip (Options minor 18, OptionsCompose minor 5).** **Rendered, text
  unchanged, and it overstates the act.** PanelMaster does draw the library's control: `S:InstallMaster`
  composes the block through `H.MasterControls` (`settings/Schema.lua:203`), and its `onResetAll`
  (`:228`) runs `Sl:ConfirmResetAll` → `Sl:DoResetAll` (`settings/Slash.lua:38`–`:46`). That is one
  `db:ResetProfile()` on the active profile. The descriptor supplies no `resetProfile`, so the text
  stays *"Restore every setting in this addon to its default."* This addon does ship an AceDBOptions
  Profiles page (`settings/Panel.lua:487`), so other profiles survive the reset and the text says
  more than the act does. This is not new at this release: the same text has been shown since
  minor 4. See class B for the option.
- **Kit revision 19, `OnProfileReset` without a key.** **Not reached.** The harness replaces the
  kit's AceDB with its own. That fake still fires `OnProfileReset` with `(db, M.__profileName)`
  (`tests/wow_mock.lua:453`), a key real AceDB does not pass. The handler (`core/Database.lua:102`)
  takes no arguments, so nothing reads it. **Aligned in a follow-up commit:** the fake now fires
  `(event, db)`, and no case depended on the key.
- **No surface change.** No member is added to either instance, so no surface-parity exclusion moves.

## Class B: host change required

- **`resetProfile` plus `profilesPage = true` on the Options descriptor. Adopted in a
  follow-up commit at the owner's instruction.** It would be **accurate**. The tooltip would read *"Reset the current profile to its
  defaults — the same thing Profiles → Reset Profile does. Your other profiles are not affected."*
  That is exactly what `Sl:DoResetAll` does, and the Profiles page it names exists. It would be
  **inert everywhere else**. The vendored library reads `resetProfile` in two places only:
  `O.RestoreAllDefaults` (`libs/LibKa0s/Options.lua:952`–`:975`) and the composer's tooltip.
  PanelMaster never calls `O.RestoreAllDefaults` (`settings/OptionsSetup.lua:237`), and nothing
  inside the library calls it. The value to pass is `function() NS.db:ResetProfile() end`. The
  global reset itself would stay `Sl:DoResetAll` with its bulk bracket and snapshot. The library's
  v1.34.0 CHANGELOG says the same: PanelMaster ships a Profiles page but resets through its own
  handlers and supplies no `resetProfile`.

## Class C: whole-module adoption

None. No module is new at this tag.

## Found, not from this release

- **`/pm set settings.visibility <value>` is refused for every value.** The composed visibility enum
  stores `always`, `inCombat`, `outOfCombat` and `never`. The `parse` adapter upper-cases every
  `string` row that declares `values`, not just the strata row, so `always` becomes `ALWAYS` and
  matches nothing. A probe at v1.34.0 refused all three of `always`, `always junk` and `inCombat`
  with `allowed values: always, inCombat, outOfCombat, never`. The same probe with minor 9's
  `Slash.lua` swapped in refused them too, so this predates the release. The panel dropdown is unaffected. **Fixed
  in a follow-up commit on this branch** at the owner's instruction: the adapter now matches the typed
  value against the row's own `values` in any case and hands the library the stored spelling.
