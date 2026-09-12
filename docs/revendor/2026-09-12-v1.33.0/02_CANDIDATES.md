# 02 — Candidates: LibKa0s v1.33.0

Sources: `git -C ../LibKa0s log --oneline v1.32.0..v1.33.0`, the v1.33.0 block of
`../LibKa0s/CHANGELOG.md`, `../LibKa0s/docs/api/Options/version-17.15.4.3-docs.md`,
`../LibKa0s/docs/api/Slash/version-9-docs.md` and `../LibKa0s/docs/api/testkit/version-18-docs.md`.

## Class A: reached the addon on the re-vendor alone

- **The font preload (Options minor 17).** **A no-op here.** The Options descriptor supplies no `getLSM` (`settings/OptionsSetup.lua:234`: the media dropdowns are per-panel pickers that `settings/PanelEditor.lua` builds itself, not `LSM30_Font` rows), so the preload returns at `type(d.getLSM) ~= "function"`. The library preload does not reach PanelEditor's own pickers; if those ever draw blank rows on a first open, this release does not change that.
- **The `count` docstrings (Options 17, Slash 9).** Comments only; nothing to adopt.
- **Kit revision 18, the `OnProfileCopied` key.** **Not reached.** PanelMaster's harness replaces the kit's AceDB with one that has no `CopyProfile` (`tests/wow_mock.lua`); `tests/test_debuglog.lua:497` fires the copy event by hand.
- **No surface change.** No member is added to either instance, so no surface-parity exclusion moves.

## Class B: host change required

None. v1.33.0 adds no descriptor field and no member to adopt.

## Class C: whole-module adoption

None. No module is new at this tag.
