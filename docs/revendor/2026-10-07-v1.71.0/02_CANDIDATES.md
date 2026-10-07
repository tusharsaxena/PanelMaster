# 02 — Candidates (PanelMaster)

Sources: `git -C ../LibKa0s log --oneline v1.70.0..v1.71.0`, the library's `CHANGELOG.md` v1.71.0
block at the tag, and `tests/_kit/secrets.lua`'s header. Owner ruling 5 of the 2026-10-07 plan makes
this run mechanical: every candidate is listed and **not adopted in this run**, with no interview and
no issue filed.

- **`Kit.secret` / `Kit.isSecret` / `Kit.reveal` / `Kit.installSecretValue` (kit 38)**: not adopted
  in this run. A shared secret-value simulator for suites. PanelMaster's combat paths read no secret
  values today, so no suite has a simulator to replace; adoption would be a new test, not a swap.
- **`ChartMath.ClipSegment`, the LineChart segment clip and hover re-sync (WidgetsLineChart 3)**: not
  adopted in this run. PanelMaster does not consume `Widgets` (#43).
- **WidgetsAutocomplete 2's generation-guarded re-hook and floored `maxRows`**: not adopted in this
  run. Same reason, `Widgets` not consumed.
- **`ParseValue`'s nan/inf refusal (SlashParse 2)**: class A, delivered on the copy; nothing for the
  host to adopt.
- **Env 2 / OptionsIdList 4 dropping the bare-global rungs**: class A, delivered on the copy. The
  matching host-side cleanup (`core/EnvSetup.lua`) is plan item PM-09, not an adoption.
- **`--list` Totals counting only cases that run (kit 38)**: class A, delivered on the copy;
  `docs/test-cases.md` is regenerated in the same commit.

Class C (whole module): none offered. The unconsumed majors keep their settled declines (`Widgets`
#43, `Perf` ratified, `Pool` #46, `Item` #45); v1.71.0 moves no premise of any of them.
