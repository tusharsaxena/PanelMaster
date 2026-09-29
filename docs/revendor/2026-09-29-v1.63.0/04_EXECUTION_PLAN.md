# Execution plan (PanelMaster)

This run's first commit carries the copy, the provenance line and this record, and nothing else: the
copy made nothing owed (`01_DELTA.md`, *Contract delta*). The adopted candidate lands in the second
commit of `SP-PM-02`, tests first:

1. `NS.COMMANDS` gains `{ "profile", NS.L[...], function(rest) NS.Slash:CliProfile(rest) end }`
   beside the other settings verbs, and the descriptor passes `profiles = function() return NS.db end`.
2. The descriptor passes `liveVerbs`, built from `lib.LIVE_VERBS` plus `"profile"`, so the verb
   answers while the addon is disabled; `Sl.ALWAYS_LIVE` reads that same array, and the degraded
   fallback carries the same fourteen names.
3. `NS.Slash` republishes `CliProfile` and `ProfileSwitch`; the degraded stub carries both on route
   (b), printing the library-absent line for `/pm profile` and switching nothing.
4. The profile handler refreshes an open General page after a switch (options-ui-§11).
5. Tests: the COMMANDS row, the live-set pin (thirteen plus `profile`), switch, unknown name, quotes,
   combat and the degraded stub. Docs: `ARCHITECTURE.md`, `slash-dispatch.md`, `profiles.md` and
   every quoted verb count.
