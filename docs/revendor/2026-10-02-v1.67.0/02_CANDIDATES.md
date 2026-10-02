# Candidates (PanelMaster)

Sources: the `CHANGELOG.md` block for v1.67.0 at the tag, `docs/api/Core/version-10-docs.md`
(*The resize grip*) and `docs/api/Options/version-28.2.34.2.3.8.1.7.4.2-docs.md`. Not interviewed:
the census-adoption bundle (`Ka0sAddonsCommonTasks/docs/2026-10-02-LIBKA0S_CENSUS_ADOPTION/`,
`01_DESIGN.md` D1, D2, D3) already decided each one.

## A. Reached the addon on the re-vendor alone (delivered)

- **The OptionsIdList loaded-addon guard and its `Cfg` line**: library-internal. Latent here,
  because this addon builds no `O.IdList`.
- **Options 28's docblock correction**: no member, field, default or string moved.

## B. Host change required

| # | Surface | Evidence | Taken by |
|---|---|---|---|
| B1 | Options descriptor `addonName` (the folder name, the file's first vararg) | CHANGELOG v1.67.0 *OptionsIdList minor 3 and Options minor 28*, *What a consumer owes*; `settings/OptionsSetup.lua:1` discards vararg 1 (`local _, NS = ...`) and the descriptor at `:168` passes no `addonName` | **`CA-PM-NM`** (D2): two tokens, `local addonName, NS = ...` and `addonName = addonName,`. Latent here: no id list, so no help mark changes |
| B2 | `MakeResizable` opts `canResize`, `onResizeStop`, `gripParent` | CHANGELOG v1.67.0 *Core minor 10*; D1 | **none**: this addon makes no `MakeResizable` call and has no hand-rolled grip. D1's adopters are LootHistory, BankLedger and MultiMeters |

## C. Whole-module adoption

None offered. v1.67.0 adds no major and changes nothing under the ratified `Perf` decline.
