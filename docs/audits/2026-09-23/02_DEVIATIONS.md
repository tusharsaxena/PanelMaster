# 02 — Deviations (2026-09-23)

Measured against **Ka0s WoW Addon Standard v2.64.0 (2026-09-23)**: the index, all 27 linked
section files and `AUDIT.md` at WowAddonStandards `e68795f`. Tree: `afb30d7`. Provenance is in
`01_CURRENT_STATE.md` and evidence in `03_EVIDENCE.md`.

**ID scheme.** The per-addon prefix **`PM-`** is reused. `PM-031` and `PM-033` persist and keep
their IDs. This run adds **`PM-034` … `PM-048`** and two dependents, `PM-034a` and `PM-038a`.

**This file and `05_EXECUTION_PLAN.md` are one document.** Every figure that appears in both was
reconciled after both were written (`03_EVIDENCE.md` §12).

## Counts, with their basis

| | Count | Basis |
|---|---|---|
| **Headline tally (roots only)** | **17** | `PM-031`, `PM-033`, `PM-034` … `PM-048`. Excludes the `derived from` dependents and the gaps already ratified in `## Documented deviations` (the *Recorded deviations* table below). |
| **Total including dependents** | **19** | The 17 roots plus `PM-034a` and `PM-038a`. |
| **MUST failures (roots only)** | **15** | Every root except the two Info observations `PM-033` and `PM-047`. |
| **MUST failures including dependents** | **17** | Both dependents fail a MUST of their own (`slash-commands-§7`'s conformance-suite MUST, `documentation-§5`). |

**Impact grades, roots:** High 1 · Medium 0 · Low 14 · Info 2.
**Impact grades, including dependents:** High 1 · Medium 0 · Low 16 · Info 2.

Fourteen of the fifteen root MUST failures are graded **Low**, because each is a doc, a config, a
test or a latent risk that no player reaches in the current code. The grade measures impact. Every
entry still names its MUST.

The **one High** is new code behavior, not a doc. The disabled state stops hiding panels once they
are unlocked (`PM-034`).

---

## High

### PM-034 — `slash-commands-§7` (*What MUST stand down*: every frame hidden, enforced at the source) — High — **new**

**MUST. An unlocked panel stays drawn, outlined and mouse-interactive while the addon is disabled.**

The stand-down rung sits where the section asks for it: `modules/Canvas.lua:802` sets
`spec.shown = false` whenever `NS.Lifecycle:IsDown()`. One line later it is undone.
`Canvas:Render` calls `NS.Unlock:Decorate(f, rec)` after every render (`:823`). For any panel that
`U:IsPanelUnlocked` answers true for (`modules/Unlock.lua:123-126`: the global `NS.State.unlocked`,
or a per-panel unlock), `Decorate` calls `f:Show()` (`:176`) and `U:ArmDrag(f)` (`:177`), which
does `EnableMouse(true)` and `SetMovable(true)`. It never consults the latch.

Reproduced headlessly against this tree (`03_EVIDENCE.md` §1). There are three routes, and all are
reachable today on a default profile:

| Route | Result on a disabled addon |
|---|---|
| **A.** Unlock (`/pm unlock`, the launcher's left-click, or untick *Lock frame*), then disable (`/pm disable` or the checkbox) | `IsDown=true`, and **every panel is still shown and takes the mouse** |
| **B.** While disabled, untick *Lock frame* on General → Master controls, or run `/pm set state.locked false` (both are live surfaces while disabled) | every panel **comes back**, outlined and mouse-enabled |
| **C.** While disabled, tick a panel's own *Unlock* on the Panels page | that panel comes back |

**Why High.** The player turned the addon off, and full-size, click-eating rectangles stay on
their screen. The rectangles carry drag handles and name labels over their action bars and chat.
The verbs that would put them away are refused while the addon is off: `/pm lock` is a feature verb
and the launcher's left-click is refused. What remains is to find the *Lock frame* checkbox or to
re-enable the addon. This is a user-visible wrong state that also swallows clicks, reached through
ordinary use.

**Fix direction.** Make the latch outrank the editing state at the one show decision.
`Canvas:Render` should skip `Decorate` and strip the overlay (`U:StripOverlay(f)`) while
`NS.Lifecycle:IsDown()`. Alternatively, `U:Decorate` can return early on the latch; that is the same
rung, read once. Keep the session unlock state as it is, so that standing up re-renders from
current state (`performance-§6`) and brings the outlines back exactly as the player left them.
Land it test-first with `PM-034a`.

#### PM-034a — `slash-commands-§7` (*The conformance test every addon ships*) with `testing-§12` — *derived from PM-034* — Low

**MUST.** `tests/test_disabled.lua` passes against the defect above. Step 5
(`tests/test_disabled.lua:221-251`) asserts zero shown panels after disable, after the three
repaint paths, and under the `perf` hold. It never puts a panel in the **unlocked** state, which is
the one state that re-shows a frame. A conformance suite that stays green against a frame drawn
while stood down is the second draw gate `testing-§12` names.

**Why it does not graduate.** It has the same single fix as its root, applied in the same change.
No user reaches it separately, and its grade (Low) is below the root's.

**Fix direction.** Extend step 5 with routes A, B and C. Assert zero shown frames **and** zero
mouse-enabled panel frames, and add `-- red under: drop the IsDown check before Unlock:Decorate in Canvas:Render`.
Watch it go red against today's tree before the fix lands.

---

## Low

### PM-035 — `events-frames-taint-§1` (*An unknown event name raises*) — Low — **new**

**MUST ×2.** Event registration is not isolated per event, and a rejected name is recorded
nowhere.

`NS.StandUp` registers three events with three bare calls (`core/LifecycleSetup.lua:126-129`), and
`OnInitialize` registers `PLAYER_LOGIN` bare (`core/PanelMaster.lua:63`). On modern retail an
unknown name **raises**. A throw at `:127` would leave `:128-129`, `Canvas:Enable()` and the
repaint unbound, and nothing a player can see would say so. The section requires two things: every
`RegisterEvent` goes through one `pcall`ed helper, and the rejected names are reachable through the
`debug` verb or the console. Neither exists.

**Grade.** No event this addon registers is retired, so nothing is reachable today. It is Low and
latent: it arrives the patch that retires one.

**Fix direction.** Add one file-local `safeRegister(event, handler)` in `core/LifecycleSetup.lua`
that `pcall`s `NS.addon:RegisterEvent`, records failures in `NS.State.rejectedEvents`, and surfaces
them in `D:Diagnose()`'s header (`core/DebugLogSetup.lua`), which `/pm debug` already reaches. Route
the four registrations through it. `C_EventUtils.IsEventValid` in front of the `pcall` is the
SHOULD, and is optional.

### PM-036 — `toc-file-§5` — Low — **new**

**MUST.** `settings\Slash.lua` (`PanelMaster.toc:97`) is a **load-bearing** position with no
comment.

The file builds its dispatcher at file scope (`settings/Slash.lua:532`) from
`NS.SchemaRuntime.Get / Set / FindRow / AllRows / ApplyDefault` (`:554-558`). `settings/Schema.lua`
publishes `NS.SchemaRuntime` (`:375`), and it must have loaded first. Only the
`settings\OptionsSetup.lua` comment (`:99-102`) states the Schema ordering, and that comment is
about its own line. The position became load-bearing with today's Schema adoption (`af8a935`,
per the re-vendor bundle).

**Fix direction.** Add a comment above `PanelMaster.toc:97` naming what resolves:
`# After Schema.lua: the dispatcher descriptor takes NS.SchemaRuntime's members as values at FILE LOAD`.

### PM-037 — `toc-file-§5` — Low — **new**

**MUST.** `core\Util.lua` (`PanelMaster.toc:56`) is a **load-bearing** position with no comment.

`core/Util.lua:4` captures `local C = NS.Constants` at file scope, and `C.EDGE_SET`, `C.EDGES` and
`C.FRAME_NAME_PREFIX` are read through that upvalue (`:138`, `:153`, `:167`, `:207`). If the line
moved above `core\Constants.lua` (`:53`), the upvalue would be `nil` forever. The comment at
`:57-58` names Util only as a predecessor of CoreSetup.

**SHOULD, noted and not filed separately.** The conventional group `core\Namespace.lua`,
`core\State.lua`, `core\PanelMaster.lua`, `core\Database.lua` and the `# Defaults` / `# Modules`
groups carry no "conventional" note. `toc-file-§5` grades that as one SHOULD row per file, and it
is folded into this fix.

**Fix direction.** Add one comment above `:56` naming `NS.Constants`, and a single "conventional
from here" note for the remaining core group.

### PM-031 — `documentation-§3` (Tier 2 `compat-layer.md`) — Low — **carried from 2026-09-08**

**MUST.** `docs/compat-layer.md` is still absent while its trigger has fired, and the map still
asserts *Not applicable*.

documentation-§3's own grep over `core/Compat.lua` returns **8** (`:27`, `:56`, `:65`, `:79`,
`:103`, `:124`, `:139`, `:164`) against a threshold of three. The standard's own rationale names
this file and this count. `docs/ARCHITECTURE.md:327` reads *"Not applicable | `core/Compat.lua`
normalizes the addon roster, screen size, UI scale and LSM … no addon-specific shim beyond what the
row in `module-map.md` records"*. The row was edited since the last run (it now mentions Core minor
7) and is still false. The playbook grades a *Not applicable* row over a fired trigger **above** a
bare omission. The impact grade stays Low because the defect is in a doc.

The 2026-09-23 re-vendor settled that `LibKa0s-Compat-1.0` has no member for these eight (#53).
That makes all eight addon-specific, which is exactly what the trigger counts.

**Fix direction.** Write `docs/compat-layer.md` with one section per shim: what varies, what the
guard answers when the API is absent, and who calls it. Flip the map row to
`| Present | 8 shims in core/Compat.lua (threshold is 3) |`.

### PM-038 — `toc-file-§2` / `savedvariables-§1` (declare `schemaVersion` in the defaults), with `documentation-§3` (the register) — Low — **new**

**MUST.** `schemaVersion` is deliberately not declared in `NS.defaults.global`, and that decision
has no register row.

`defaults/Global.lua:8-20` argues the omission in a code comment. An AceDB default is served for
any key the file lacks, so seeding the stamp read every unstamped account as current, and the v1→v2
body could never run. That is the hard case `open-evolutions` (*Migration-stamp ownership*) records
as unruled. The reasoning is sound, but it is recorded only in code. `toc-file-§2` and
`savedvariables-§1` still read "MUST declare a `schemaVersion` integer in defaults", and a
deliberate departure from a MUST lives in the register or is not ratified
(`audit-review-history`, first MUST). The stamp is still written at runtime by the runner
(`core/Database.lua:132`, `:158`), so the `global` namespace does carry it.

**Grade.** No player reaches it; the code does the safer thing. Low.

**Fix direction.** Add a register row:
`| toc-file-§2 / savedvariables-§1 | schemaVersion is written by the runner, not declared in defaults | AceDB backfills a declared default as current, masking legacy accounts; open-evolutions "Migration-stamp ownership" (M4-22, febf108) | 2026-08-05 | The standard rules on migration-stamp ownership |`.
The better long-term answer is upstream: a ruling in `open-evolutions` that sanctions
"stamped by the runner, never declared" for AceDB hosts.

#### PM-038a — `documentation-§5` — *derived from PM-038* — Low

**MUST.** Two live docs say the opposite of the code. `docs/ARCHITECTURE.md:34` says
`defaults/Global.lua` *"carries the account-wide `schemaVersion` stamp"*, and
`docs/common-tasks.md:12-13` says `defaults/Global.lua` holds values like it (*"today only
`schemaVersion` qualifies"*). `defaults/Global.lua:73-76` declares `minimap` alone. The fix belongs
to the same change as the row, so this does not graduate.

**Fix direction.** Reword both lines to "written by the migration runner, deliberately not declared
(see the register)".

### PM-039 — `audit-review-history` (third MUST: evaluate every re-check trigger) — Low — **new**

**MUST.** The `architecture-§5` row (the fields on a panel, `docs/ARCHITECTURE.md:378`) has a
trigger that is met at the library layer, and the row has not been re-decided.

The trigger reads *"The schema helper gains instance addressing for registry records (an explicit
record argument on `NS.Schema:Set`)."* Today's Schema adoption made the helper `NS.SchemaRuntime`,
whose `S.Set(path, value, instanceId)` (`libs/LibKa0s/Schema.lua:432`) passes an instance id to the
host's `resolveRoot(parts, instanceId)` (`:236`, `:339-342`). The host's resolver ignores it
(`settings/Schema.lua:360`, `resolveRoot = function() return NS.db and NS.db.profile, 1 end`), and
the colon wrappers do not forward it. The re-vendor bundle states this itself
(`docs/revendor/2026-09-23-v1.55.0/05_SUMMARY.md:94-98`: *"which is that capability … the row
stands. Retiring it is a separate, larger change that needs the owner's decision"*). No open issue
carries that decision. #49, the row's evidence, is closed.

An auditor cannot tell from the trigger text whether the deviation has ended. Its capability clause
is met, and its parenthetical (`NS.Schema:Set`) is not.

**Fix direction.** Owner's call, recorded either way. **(a)** Adopt instance addressing:
`resolveRoot` maps an `instanceId` to the panel record, `Registry:Set` routes field writes through
`NS.SchemaRuntime.Set(path, v, id)`, and the row retires. **(b)** Keep the row, but re-word the
trigger to a host-side condition ("the host's resolver maps a panel id and `Registry:Set` routes
through it"), re-date the row, and cite a new `state:triaged` issue.

### PM-040 — `testing-§8` (stub-surface parity, per adopted module) — Low — **new**

**MUST.** The Lifecycle seam has a degradation stub and no parity case, and two documents say it
has one.

`core/LifecycleSetup.lua:149-190` is a hand-built latch table with nine members (`Hold`, `Release`,
`Set`, `IsHeld`, `IsDown`, `Holds`, `Reevaluate`, `PrintHolds`, `name`). `tests/test_surface_parity.lua`
has six cases (`:59`, `:103`, `:136`, `:154`, `:190`, `:226`: Core, DebugLog, Launcher, Slash,
Options, Schema) and none for Lifecycle. Its own header counts "six" (`:3`). Yet
`core/LifecycleSetup.lua:147-148` claims *"tests/test_surface_parity.lua compares the two member
sets so it cannot drift"*, and `docs/module-map.md:19` repeats the claim.

**Grade.** The host calls `IsDown`, `Set`, `Reevaluate` and `Holds` (the census in
`03_EVIDENCE.md` §6), and the stub answers all four today, so nothing is reachable. Low. The false
coverage claim is the sharper half.

Env and Media are **not** filed. Their seams have no separate stub table: each function branches on
the library internally (`core/EnvSetup.lua`, `core/MediaSetup.lua`), so the degraded and live
surfaces are the same set of names.

**Fix direction.** Add `Parity: the Lifecycle seam's degraded surface matches the live one`, with
the degraded arm built by `tests/degraded_env.lua` omitting `Lifecycle.lua`, the grep named in the
comment, and the library's `Lifecycle` instance added to `Kit.setSurfaceSource`. Update
`tests/test_surface_parity.lua:3`, `docs/testing.md` and the two claims.

### PM-041 — `localization-§5` (frozen records are not rewritten; exclusions named in the gate) — Low — **new**

**MUST.** Two frozen dated specs were rewritten by the spelling sweep, and the rewrite produced a
non-word.

`e30e329` (2026-09-22, the adoption of the kit's prose gate) changed
`docs/superpowers/specs/2026-07-31-panel-artwork-design.md:5` and
`docs/superpowers/specs/2026-08-02-wiki-artwork-import-design.md:5` from *"catalogued by"* to
*"**catalogd** by"*, a mechanical respelling that dropped the `e`. `docs/superpowers/` is a frozen
store by `documentation-§3`'s list, and this repo's own map names it so
(`docs/ARCHITECTURE.md:305`). localization-§5 excludes frozen dated bundles from the gate as
*"the record and … not rewritten"*.

**Root cause upstream.** The kit's gate (`tests/_kit/test_prose.lua:209-213`, kit revision 25)
names `docs/audits/`, `docs/automated-tests/`, `docs/perf-analysis/`, `docs/reviews/` and
`docs/revendor/`. It omits `docs/superpowers/` and `docs/investigations/`, both of which
documentation-§3 lists as frozen. So the gate reddened on a frozen record, and the frozen record was
"fixed". The prior audit (2026-09-08, `PM-032a`) had named these two lines and declined to touch
them for exactly this reason.

**Fix direction.** **Upstream first:** add `docs/superpowers/` and `docs/investigations/` to the
kit's `SKIPPED_DIRS` in LibKa0s `testkit/test_prose.lua`, which is a kit revision. Then re-vendor
the whole LibKa0s. In the meantime the host can add
`skipDirs = { "docs/superpowers/" }` to `tests/prose_waivers.lua`, since the gate permits a named
directory. After that, restore line 5 of both specs to their pre-`e30e329` text (`git show e30e329^:<path>`).

### PM-042 — `documentation-§3` (the hub and its spill rule) — Low — **new**

**MUST (spill) and SHOULD (length).** `docs/ARCHITECTURE.md` has outgrown its hub shape.

- The file is **471** lines, against the ~400 SHOULD.
- `## Settings Schema` runs **102** lines (`:30-131`), against the ~60 at which a mandated section
  MUST spill to `schema.md`, leaving a summary and one link. It holds the schema-runtime adoption
  narrative (`:47-71`) and the Master controls composition note (`:73-78`), both of which belong in
  `schema.md`. The registry naming (`:80-103`) is mandated here and stays, trimmed.
- The register carries **49** lines of prose about retired rows (`:380-428`). The rule keeps rows
  out of a graveyard; narratives about retirements belong in the audit bundle or the issue that
  retired them.
- Two mandated headings drift from the canonical names: `## Message bus (architecture-§4)` (`:132`)
  and `## Taint` (`:288`), where the canonical names are *Message Bus* and *Taint Notes*.

**Fix direction.** Move `:47-78` into `docs/schema.md` and keep a three-to-five-line summary plus
the registry naming. Replace the retired-row narratives with one line each that cite the bundle or
issue. Rename the two headings. The target is under 400 lines.

### PM-043 — `documentation-§3` (Tier 1 `module-map.md`: "every non-vendored file") — Low — **new**

**MUST.** `docs/module-map.md` does not cover `tests/` or three of the four `tools/` generators.

A check of each tracked non-vendored `.lua`/`.py` file's basename against the doc finds **28 of 32**
authored `tests/` files unmentioned (every `test_*.lua` except `test_envsetup`, `test_harness`,
`test_libka0s` and `test_surface_parity`, plus `run.lua`, `wow_mock.lua`, `degraded_env.lua` and
`prose_waivers.lua`). `tools/artwork/artwork_cleaner.py`, `make_poster.py` and `update_catalog.py`
are also unmentioned (`03_EVIDENCE.md` §10).

**Fix direction.** Add a `tests/` table (the runner, the extender, the partial-load helper, the
waiver file, and one line per suite, or one line per suite family) and a `tools/` table (four
generators, what each writes). `docs/testing.md` can keep the detail. The map needs the row.

### PM-044 — `documentation-§5` (keep docs in sync) — Low — **new**

**MUST.** Inventory counts and code comments have gone stale, with every item re-derived from the
tree:

| Where | Says | Tree says |
|---|---|---|
| `docs/ARCHITECTURE.md:21-24` | "six of the eight LibKa0s seams" in `core/`, "the other two seams" in `settings/` | **nine** seams: six in `core/` and three in `settings/` (`Slash`, `OptionsSetup`, `Schema`) |
| `docs/testing.md:106` | "Nine of the ten majors resolve `LibKa0s-Core-1.0`" | **fourteen of fifteen** floor on Core at v1.55.0 (`library-stack-§7`) |
| `docs/testing.md:340`, `:347-350` | "Four LibKa0s seams are adopted — Core, DebugLog, Slash and Options"; "One case per seam … Two of the four" | **nine** adopted and **six** parity cases |
| `docs/module-map.md:69-70` | "`Core` resolves LibStub; the other nine resolve `LibKa0s-Core-1.0`" | **fourteen** |
| `docs/ARCHITECTURE.md:339` | `RESULTS.md` is "generated, never hand-edited" | the watch list's `Disposition` column is authored (`automated-tests-§4`) |
| `settings/PanelEditor.lua:178-190`, `:1191-1223` | *"`General` is GONE"*; *"EVERYTHING that acts on the panel as a whole lives here, in the band"*; *"THREE EXPLICIT ROWS"*; re-pointing by `refreshHeaderActs` | `General` is back and first (`:191-199`, `:209-211`); the band is one row (`:1229-1236`); `refreshHeaderActs` no longer exists |
| `.gitignore:6` | "state from `tools/artwork/wiki_import.py`" | there is no such tracked script |

**Fix direction.** A single doc-and-comment sweep. Recount against `grep -c` rather than editing
the numbers by hand.

### PM-045 — `documentation-§7` (`DEPENDENCIES.md` MUST NOT drift; evidence-based) — Low — **new**

**MUST.** `DEPENDENCIES.md:63` cites `tests/_kit/framework.lua:515-516` for the `ls -A` / `dir /b`
suite listing and `framework.lua:498-500` for the LuaFileSystem note. In the kit-25 payload those
lines are doc comments; the listing is at `:643-644` and the note at `:627-628`. The shape of the
dependency is unchanged, but the evidence no longer points at it. The `loader.lua:68/72` and
`vendor_sync.lua:126/194/195` citations were re-read and still resolve.

**Fix direction.** Re-point the two citations, and cite by function name (`Kit.assertSuiteInventory`,
`listDir`) next to the line so the next re-vendor does not break them again.

### PM-046 — `documentation-§1` (README shipped content; Usage close) — Low — **new**

**MUST ×2.**

1. **Angle-bracket placeholders in shipped README content**: `README.md:51` `` `/pm delete <name>` ``,
   and `:79-80` `` `/pm get <setting>` ``, `` `/pm reset <setting>` ``. CurseForge strips these as
   unknown HTML, even inside backticks, so players on the project page read `/pm delete`,
   `/pm get` and `/pm reset` with the argument gone. That is the surface where players read the
   README.
2. **Usage does not close on the configuration line.** The signpost is mid-section (`:67-69`), and
   the section ends on the disabled-state paragraph (`:90-95`). The section is nine paragraphs
   against "aim for five or fewer", which is guidance and not a breach.

**Fix direction.** Write the arguments bare (`/pm delete ChatBG`, `/pm get settings.gridSize`), move
the one-line configuration pointer to be Usage's last line, and fold the disabled-state paragraphs
into one. Run the de-AI pass the section MUSTs on README edits.

### PM-048 — `audit-review-history` (*A re-vendor commit implies a bundle*) — Low — **new**

**MUST.** Twenty-five LibKa0s tags were vendored after the store's first bundle, and no bundle
names them. No `## Documented deviations` row says why.

The playbook's two-listing check was run verbatim (`03_EVIDENCE.md` §11). The horizon is
`2026-08-25`, the store's first bundle. **32** commits since then touch `libs/LibKa0s/`, and
between them they vendor **31** distinct tags, read from each commit's `CLAUDE.md` provenance line.
Bundles record **8** tags: `v1.15.0`, `v1.25.0`, `v1.30.0`–`v1.34.0` and `v1.55.0`, with
bare-dated folders read from their `01_DELTA.md` first line. That leaves **25** vendored and
unrecorded: `v1.18.0`, `v1.18.1`, `v1.19.0`, `v1.23.0`, `v1.24.0`, `v1.26.0`–`v1.29.0`,
`v1.35.0`–`v1.39.0` (including `v1.36.1` and `v1.36.2`), `v1.42.0`, `v1.44.0`, `v1.45.0`, `v1.46.1`,
`v1.47.0` and `v1.50.0`–`v1.53.0`. Today's `v1.55.0` bundle names its span as
`v1.54.2 → v1.55.0` (`docs/revendor/2026-09-23-v1.55.0/01_DELTA.md:1`), so it does not discharge
the backlog.

**Grade, and a note on the playbook.** `AUDIT.md`'s check text calls an unrecorded tag a
**High** finding, while its own step-5 table grades a missing record, which no player, save file or
session can reach, as **Low**. This run applies step 5, the rule both this playbook and the agent
brief say governs grading. The discrepancy is reported for the documentation-lane audit of
`WowAddonStandards` rather than resolved here.

**Fix direction.** Write **one** consolidated bundle,
`docs/revendor/<date>-v1.18.0-to-v1.53.0/`, containing `01_DELTA.md` and `05_SUMMARY.md` and naming
the span and the commits that carried it. The standard names that as the compliant answer to a
backlog. Do not write a folder per tag, which would invent deliberation that never happened.

---

## Info

### PM-033 — `automated-tests-§4` (anti-pattern #51) — Info — **carried**

**Observation. The record is stale between releases, as expected, and one release went
unrecorded.**

The newest bundle, `docs/automated-tests/20260916-184500` (sha `3c4005a`, clean), is **29**
commits behind HEAD. Re-measured at HEAD with the verbatim invocation:

| Figure | Recorded `20260916-184500` | HEAD `afb30d7` |
|---|---|---|
| tests (passed/skipped/total) | 834/0/834 | 884/0/884 |
| luacheck files | 59 | 60 |
| lizard NLOC | 13887 | 14325 |
| lizard functions | 1624 | 1687 |
| avg NLOC / avg CCN / max CCN / warnings | 7.4 / 2.0 / 15 / 0 | 7.4 / 2.0 / 15 / 0 |

Nothing crossed a threshold. The same two functions sit at CCN 15 (`R.ApplyArtSize`,
`Compat.AddOnFolders`), and the four band files are unchanged in both membership and line count.
The row predates kit revision 25, so its commit cells are *unknown* by rule; that is not a finding.

**Also recorded here:** the **1.1.1** tag (`1.1.1-release` on `dd04000`, a re-triggered build of
1.1.0) has no release bundle. `automated-tests-§6` wants one per release, and `§5` forbids
backfilling it. The TOC was bumped to 1.1.1 after the tag (`940bb11`). No shelf-life breach
(anti-pattern #53): two release runs exist (`20260807-160022` for 1.0.0, `20260910-234511` for
1.1.0), so no *Accepted* entry has three.

**Fix direction.** At the next release, run `tests/_kit/run-automated-tests.sh` as a release run,
carry the four dispositions forward, and let kit 25 emit the commit cells. Note the unrecorded
1.1.1 in that bundle's `ANALYSIS.md`, once.

### PM-047 — `audit-review-history` (the issue store is the backlog) — Info — **new**

**Observation.** Five open `state:triaged` issues describe work whose premise has already
resolved. The store reads as carrying a backlog it does not have.

| Issue | Premise | Now |
|---|---|---|
| #19 | respelling of `docs/agent-context.md` | the file was deleted (anti-pattern #49); `CLAUDE.md:83` says it does not exist and must not be created |
| #20 | roster registration in WowAddonStandards | registered, `ADDONS.md:26` |
| #22 | D-001: no `X-Curse-Project-ID` until first upload | `PanelMaster.toc:13` is `1642836` |
| #23 | D-002: no CurseForge version badge | `README.md:4` carries it |
| #24 | `performance-§1–§4` has no counterpart | ratified row `docs/ARCHITECTURE.md:375` (#31, #44) |

**Fix direction.** Close each one with a one-line comment citing the evidence. #19, #20, #22 and
#23 take `state:done`. #24 takes `state:will-not-do`, pointing at the row.

---

## Recorded deviations — accepted, not counted

Each row below is a gap this run would otherwise file, matched to a ratified row in
`docs/ARCHITECTURE.md` → `## Documented deviations`. None counts toward either tally. Triggers were
evaluated against `afb30d7` and every cited id was resolved (`03_EVIDENCE.md` §7).

| Rule | Row | Decided | Trigger evaluated | Evidence ids |
|---|---|---|---|---|
| `performance-§1` | `docs/ARCHITECTURE.md:375` — Perf wiring declined, **not** a §12 exemption | 2026-08-25 | **Not fired.** One `OnUpdate` (`modules/Canvas.lua:666`); the only AceTimer use is a one-shot color-picker throttle (`settings/OptionsSetup.lua:249`); `updateMouseover` is still one `MouseIsOver` and one `SetAlpha` per tracked panel (`:632-645`); performance-§12 has gained no bounded-cost clause at v2.64.0 | #31 (closed, will-not-do), #44 (closed, done) — resolve |
| `events-frames-taint-§8` (pre-formatting SHOULD) | `:376` | 2026-08-05 | **Not fired.** The trigger-set API sweep over the authored source returns 0; the only Unit API is `UnitClass` | — |
| `localization-§1` | `:377` — English-only, localization-§3's second terminal state | 2026-08-05 | **Not fired.** `locales/` holds `enUS.lua` and `PostLoad.lua` only | `locales/enUS.lua:6`, `:8-14` resolve |
| `architecture-§5` (fields on a panel) | `:378` | 2026-09-12 | **Capability met at the library layer; not re-decided** — filed as `PM-039` | #49 (closed, done) resolves |

**No row's cited rule has changed under it** at v2.64.0. `performance-§1` and `§12` are unchanged
in substance, `events-frames-taint-§8`'s trigger list is unchanged, `localization-§1` and `§3` are
unchanged, and `architecture-§5` (v2.44.0 text) still requires a row for a preference with no
schema row.

**Declines with no row, checked by inverse.** The closed `state:will-not-do` issues #27–#31, #43,
#45, #46, #51 and #53 were cross-read. #31 has its row. #51 (the drag-stop row) is folded into the
`architecture-§5` row, which names the drag-stop writer. The rest decline **optional** adoptions
(`library-stack-§7`: adoption is per module; Compat, Bus and Schema are optional from v2.64.0) and
owe no row. The one reasoned decline with no row is `PM-038`.

**Not filed, on purpose.**
- The Panels page's two live refresh subscriptions surviving the stand-down. `open-evolutions`
  records the question and rules neither reading.
- `lock`/`unlock` as verbs (a MAY, present and compliant).
- `docs/localization.md`, `media.md` and `rendering.md` are Tier 3 names, not non-canonical Tier
  1/2 names.
- The self-row for `ARCHITECTURE.md` in the map (a MAY, and filed in neither state).

---

## Closed since 2026-09-08

| ID | Rule | Status | Evidence |
|---|---|---|---|
| PM-030 | `options-ui-§13` (+ `testing-§12`) | **Closed, by the rule's owner.** The wrap-stability invariant is the library's, and LibKa0s v1.55.0 pins it: `tests/test_options_tabs.lua:573` *"a wrapped strip's geometry is IDENTICAL for every value of the selection"*, plus `:636` (pitch measured off the inactive family, cached). `testing-§8` forbids the addon from keeping a duplicate. |
| PM-031 | `documentation-§3` | **Open**, carried above. | `docs/ARCHITECTURE.md:327` |
| PM-032 | `localization-§5` | **Closed** (`e30e329`). `tests/test_spelling.lua` is deleted; the kit's `test_prose` is wired by the pair form (`tests/run.lua:104`); an independent sweep with the canonical lists returns only the waived texture path and the waiver file's own comment. |
| PM-032a | `localization-§5` | **Closed.** `docs/performance.md` reads `artifact`. |
| PM-033 | `automated-tests-§4` | **Open**, refreshed above. | |
