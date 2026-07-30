# 03 — Evidence (2026-07-30)

The commands run and the output seen, so a later audit can reproduce this baseline rather than take
it on trust.

## Standards source

Fetched with `curl -fsSL` (not WebFetch — its summarizer rewrites and truncates, which would corrupt
the context pack that gets dropped into `docs/`):

```
RAW=https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master
$RAW/NEW_ADDON.md                      62 lines
$RAW/standards/NEW_ADDON_CONTEXT.md   582 lines   (pack v2.7.0, 2026-07-26)
$RAW/standards/STANDARDS.md           124 lines   (standard v2.11.0, 2026-07-26)
```

Section files were reached by following the index's Sections list, never by hard-coded filename.

## Green gate

```
$ lua tests/run.lua
...
237 passed, 0 failed, 237 total

$ luacheck .
Total: 0 warnings / 0 errors in 18 files
```

Both were red at least once during the build and were fixed rather than worked around:

- `Canvas: frames are pooled, not leaked` failed at first (expected 4, got 3). The **test** was
  wrong, not the pool: `Registry:New` already fires a repaint that takes a frame out of the pool, so
  a create+delete cycle nets to zero rather than +1. Replaced with the invariant that actually
  matters — total frames do not grow across ten cycles — plus a separate case pinning that a delete
  returns its frame to the pool.
- `luacheck` reported two `W432 shadowing upvalue argument self` in `modules/Unlock.lua`, where the
  drag script handlers named their frame argument `self` inside a method whose own `self` was in
  scope. Renamed to `frame`.

## Test inventory

`lua tests/run.lua --list > docs/test-cases.md`

| Suite | Cases |
|---|---:|
| test_util.lua | 24 |
| test_compat.lua | 8 |
| test_constants.lua | 10 |
| test_registry.lua | 33 |
| test_canvas.lua | 23 |
| test_unlock.lua | 22 |
| test_database.lua | 13 |
| test_debuglog.lua | 19 |
| test_schema.lua | 23 |
| test_slash.lua | 47 |
| test_panel.lua | 16 |
| **Total** | **237** |

## Rules pinned by a test rather than by inspection

These are the standard's rules that break silently, years later, when someone adds a line. Each has a
case that fails if it regresses:

| Rule | Test |
|---|---|
| `architecture-§2` — the printer survives the AceConsole embed | `NS.Print survived the AceConsole embed` |
| `architecture-§4` — one sender per bus message | `Registry: the panel messages have exactly one sender`, `Schema: the settings message has exactly one sender` (both grep the sources) |
| `architecture-§4` — consumers on their own bus target | `Canvas: consumers register on their own bus target` |
| `architecture-§5` — every schema path resolves | `Schema.Register: every path resolves against the defaults` |
| `compat` — no flavor branching | `Compat owns the deprecated-API surface` (greps all 12 sources for `WOW_PROJECT_ID`) |
| `options-ui-§1` — eager category, lazy body | `Panel.Register: the category is registered EAGERLY`, `Panel: the body is built lazily` |
| `options-ui-§1` — the framework contract | `Panel: every registered frame carries the framework contract` |
| `options-ui-§2` — config refuses in combat, no replay | `Panel.Open: refuses during combat`, `Panel.Open: does NOT defer-and-replay` |
| `options-ui-§5` / #42 — Defaults button built lazily | `Panel: the Defaults button is NOT created at registration` |
| `events-frames-taint-§2` — deferred write replays | `Unlock: the deferred unlock is replayed when combat ends` |
| `debug-logging-§5` — session-only flag, window-independent | `DebugLog: window visibility is independent of the logging flag` |
| `debug-logging-§5` — disable line lands after the flag flips | `DebugLog.SetEnabled: the disable line lands AFTER the flag flips off` |
| `debug-logging-§5/§8` — `[Init]` on enable only | `DebugLog.SetEnabled: flips the session flag and brackets the log`, `…emits no [Init] summary on disable` |
| `slash-commands-§3` — required verbs | `COMMANDS: the standard's required verbs are present` |
| `slash-commands-§4` — cyan tag, no trailing colons | `Slash: every printed line carries the shared cyan tag`, `Slash.PrintHelp: no line ends in a colon` |
| `slash-commands-§5` — output shape and colours | `Slash.BuildListLines: …` (4 cases) |
| `library-stack-§6` — soft fallback for a missing optional lib | `Compat.FetchTexture: degrades to nil when LibSharedMedia is absent` |
| `preview-mode` | `Unlock.SetPreview: …` (5 cases) |
| hard rule #14 — frame pooling | `Canvas: frames are pooled, not leaked` |
| `savedvariables-§1` — idempotent migration seam | `Database.RunMigrations: is idempotent` |
| `debug-logging-§5` — nothing session-only is persisted | `Database: the debug flag is NOT persisted`, `Database: unlock state is NOT persisted` |

## Doc / code drift checks

- `docs/test-cases.md` regenerated from the runner; README `[tests]` badge set to `237/237` in the
  same change (`testing-§5`).
- The README slash-command table, the `/pm help` index and the settings landing page all read from
  `NS.COMMANDS` — the latter two literally generate from it, and the README table was written from
  it. A test asserts every command has a name, description and function, and that names are unique.
- `Schema: the defaults match the shipped profile` asserts every row default equals the value in
  `defaults/Profile.lua`, which is the pair most likely to drift.

## Not verified here

- **In-client behaviour.** Nothing in *this bundle* was run in WoW at the time it was written.
  Rendering, dragging, layering against other addons, the console's scrollbar and the Defaults
  button's skinning are covered by [`docs/smoke-tests.md`](../../smoke-tests.md) — since executed and
  passed (see [05_EXECUTION_PLAN.md](05_EXECUTION_PLAN.md) step 1), though the page has grown
  considerably since.
- **The vendored libraries' contents** were copied wholesale from `BankLedger` and not re-read.
