# 04 — Execution plan

## B1 — #29, the event half on an Embed target

**Files.** `tests/wow_mock.lua` (the `AceEvent-3.0` override and item 5 of its header),
`tests/test_harness.lua` (one new case). No production file is touched.

**Change.** The local `Embed` captures the kit's Embed (`local baseEmbed = libs["AceEvent-3.0"].Embed`),
calls it first, then applies `embedBus(obj)`. The two `obj.RegisterEvent = obj.RegisterEvent or
function() end` / `obj.UnregisterEvent = … or function() end` lines are deleted. Everything the
kit's Embed wrote to the message half is overwritten by `embedBus`, so the bus still routes through
`M.__msgRegistry`.

**Characterization.** The new case is
`Harness: a bus target carries the kit's recorded event half (kit revision 16)`. It builds an
`NS.NewBusTarget()` and asserts four things: `__events` exists; `RegisterEvent` records the handler;
`UnregisterAllEvents` empties the registry; and `RegisterEvent` with no handler and no same-named
method raises. It also asserts that `RegisterMessage` still lands in `T.mocks.__msgRegistry`.

**Proof it is not vacuous.** Run against `HEAD`'s `tests/wow_mock.lua`, the case goes red with
`the bus target has no recorded event registry`, and it goes green with the change. The existing
bus cases (`tests/test_canvas.lua`'s *"OnEnable subscribes the renderer to the bus"* and *"consumers
register on their own bus target"*) stay green, so the message half did not move.

**Commit boundary.** The orchestrator asked for the re-vendor and the shim adoption as one logical
commit, so both are in the re-vendor commit, with `CLAUDE.md`'s provenance line,
`docs/test-cases.md` regenerated and the README `[tests]` badge (783 → 785).

## B2 — #30

Not implemented (declined; see `03_DECISIONS.md`).
