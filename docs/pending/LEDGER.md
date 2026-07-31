# Pending ledger

The record of what `/wow-addon:pending-audit` has already asked about and what was decided, so a
settled item stops re-surfacing on every sweep. **Maintained by `/wow-addon:pending-audit`** — merge,
never clobber.

Each row is matched on **ID + evidence hash** together. The hash is the first 8 characters of `sha1`
over the item's verbatim evidence text, so if the underlying comment, plan row or issue title is
*edited*, the hash changes, the match fails, and the item is correctly interviewed again.

**What counts as "the evidence text"** — pinned down here because it was not, and the 2026-07-31
sweep could not reproduce a single `DOC` or `CODE` hash from the run before it. The algorithm was
never in doubt; the *input* was. A hash nobody can recompute silently turns every settled item back
into an open question, which is the one failure this file exists to prevent. UTF-8, no trailing
newline, `.strip()` applied:

| Source | Evidence text is… |
|---|---|
| `ISS` | the issue title alone — no `#N`, no labels, no body |
| `DOC` | the whole bullet, first line through last continuation line, newlines intact |
| `CODE` | the marker comment and its continuation lines, as written, including the `--` |
| `PLAN` | the plan row or deviation entry as the frozen bundle words it |
| `GIT` | the single `git status --porcelain` / `git stash list` / `git log --oneline` line |

Where a hash in the table below is known not to reproduce from its own evidence, it has been
corrected in place and the correction noted in the rationale. A hash is a lookup key, not history.

Sources: `CODE` (source markers), `DOC` (documentation prose), `PLAN` (audit/review execution plans
and deviation tables), `GIT` (working tree, stashes, commit subjects), `ISS` (GitHub issues), `MEM`
(Claude memory).

## Decision notation

| Marker | Value | Meaning | Re-surfaces? |
|---|---|---|---|
| 🟢 | `done` | Implemented, or otherwise resolved, in the run that recorded it | No — closed |
| 🔵 | `wont-do` | Deliberately closed; the user decided it will never be done | No — closed |
| 🟡 | `deferred` | Not now; still on the books | Yes, as a collapsed count |
| ⚪ | `untriaged` | Found and recorded, but never put to the user | Yes — interviewed in full next run |

Green is the resolved outcome, blue a settled and final close, yellow a decision still asking for
attention, white the absence of any decision at all — a column of yellow is this file telling you
what is left, and a column of white is telling you what nobody has looked at yet. There is
deliberately no red: nothing here is an error state. The **word** is the data and the **marker** is
the affordance, so both are always written; the marker alone is invisible to a screen reader and to
`grep wont-do`.

Three of the four are decisions. **`untriaged` is not** — it records only that an item was seen, and
must never be read as agreement, refusal or postponement. It is the one value that gets fully
re-interviewed rather than collapsed.

The **Issue** column holds the GitHub issue number when the item was deferred with an issue filed,
or when an existing issue was found to already cover it; `—` otherwise. It is what stops the same
pending work being counted twice once the issue comes back through the GitHub sweep.

| ID | Evidence hash | Source | Decision | Issue | Date | Rationale |
|---|---|---|---|---|---|---|
| DOC-03 | 15ebfadf | `docs/ARCHITECTURE.md` ▸ Known limitations | 🟢 done | #6 | 2026-07-31 | Filed as issue #6 to make it visible in the backlog rather than only to ARCHITECTURE readers. Not fixed — growth is per-session and bounded in practice. |
| DOC-02 | a531cf09 | `docs/ARCHITECTURE.md` ▸ Known limitations | 🟢 done | #7 | 2026-07-31 | Filed as issue #7. Cannot be fixed (frame names are immutable) but can stop being silent; the issue proposes a rename-time notice. |
| DOC-05 | c296d286 | `docs/ARCHITECTURE.md` ▸ Known limitations | 🟢 done | #8 | 2026-07-31 | Filed as issue #8. The only limitation whose own text proposes the fix; self-contained in the existing ticker. |
| DOC-04 | 10a1babb | `docs/ARCHITECTURE.md` ▸ Known limitations | 🟡 deferred | — | 2026-07-31 | Deferral re-affirmed. Hash moved from `904842e7` because the entry's text was corrected once panel levels became strided — the *limitation* is unchanged (still no level UI, `level` still CLI-only), only its description of cross-panel ordering. |
| DOC-06 | 83f2b5e1 | `docs/ARCHITECTURE.md` ▸ Known limitations | 🟡 deferred | — | 2026-07-31 | Documented design decision. Class color reads `UnitClass("player")` by design. |
| DOC-07 | b724af28 | `docs/ARCHITECTURE.md` ▸ Known limitations | 🟡 deferred | — | 2026-07-31 | Documented design decision — a login-time sweep would silently rearrange a deliberately-parked panel. |
| DOC-01 | d49eaf1f | `docs/ARCHITECTURE.md` ▸ Known limitations | 🟡 deferred | — | 2026-07-31 | Already accepted deviation A-008 in the audit bundle and recorded in the README's Troubleshooting section. Not re-litigated. |
| DOC-08 | dd887a8b | `docs/agent-context.md` (US-English sweep) | 🟡 deferred | — | 2026-07-31 | "Skip this." Left as respelled; still undecided whether the change belongs upstream in WowAddonStandards or the local copy should be restored as vendored text. |
| PLAN-01 | 4a9fdd91 | `docs/audits/2026-07-30/05_EXECUTION_PLAN.md` ▸ Step 0 | 🟡 deferred | — | 2026-07-31 | Release held. Roster registration lives in the WowAddonStandards repo and moves with the release. |
| PLAN-02 | 4b2d92a2 | `docs/audits/2026-07-30/05_EXECUTION_PLAN.md` ▸ Step 3 | 🟡 deferred | — | 2026-07-31 | Release held pending an in-client check of the accent-bar rotation. |
| PLAN-03 | a17b259f | `docs/audits/2026-07-30/02_DEVIATIONS.md` ▸ D-001 | 🟡 deferred | — | 2026-07-31 | Blocked on a CurseForge project id that does not exist until first upload. Not actionable until PLAN-02. |
| PLAN-04 | 089573f0 | `docs/audits/2026-07-30/02_DEVIATIONS.md` ▸ D-002 | 🟡 deferred | — | 2026-07-31 | Same blocker as PLAN-03; the bundle defines the two as one atomic change. |
| PLAN-05 | f99a1c4b | `docs/audits/2026-07-30/02_DEVIATIONS.md` ▸ D-004 | 🟡 deferred | #1 | 2026-07-31 | Bundled with the next live-client session, alongside the accent-rotation check. Tracked by issue #1. |
| PLAN-06 | 4cf84dd8 | `docs/reviews/2026-07-30/05_FINAL_SUMMARY.md` ▸ Known follow-ups | 🟡 deferred | — | 2026-07-31 | "Defer for now." The audit bundle was measured against standard v2.11.0; `performance-§1`–`§4` are MUST as of v2.13.1 with no counterpart in this addon. Deliberately carried, not overlooked. |
| PLAN-07 | 55b62116 | `docs/reviews/2026-07-30/05_FINAL_SUMMARY.md` ▸ Known follow-ups | 🟡 deferred | — | 2026-07-31 | "Keep them open, no plan." Baselines for future comparison, not pass/fail checks; nothing depends on them. |
| GIT-01 | 6d67c2c6 | `git log origin/master..HEAD` | 🟢 done | — | 2026-07-31 | Deferred as "release held — three commits stay local until the in-client check is done", then resolved by the user pushing by hand: `git rev-list --left-right --count origin/master...HEAD` reports `0 0`. Closed, not re-deferred; the deferral was about *when* to push, and the push happened. The branch was `origin/main` when this row was written; renamed to `origin/master` 2026-07-31, locator updated to stay reproducible. Evidence hash unchanged — the locator is not the evidence text. |
| GIT-02 | 28026602 | `git status --porcelain` ▸ `?? docs/pending/` | 🟢 done | — | 2026-07-31 | "Leave it for you to commit." No staging or commit performed here — that is `/wow-addon:commit`'s job. The ledger is reviewed and committed by hand. |
| ISS-01 | 2ebf52d9 | GitHub #1 | 🟡 deferred | #1 | 2026-07-31 | Same item as PLAN-05. Issue stays open as the single tracker; bundled with the next client session. |
| ISS-02 | 0c338158 | GitHub #2 | 🟡 deferred | #2 | 2026-07-31 | "We'll build this later." Filed deliberately as future work, not as a gap. |
| ISS-03 | b0234046 | GitHub #3 | 🟢 done | #3 | 2026-07-31 | Filing the issue *was* the decision — moved out of the frozen review bundle so it is visible in the backlog. |
| ISS-04 | 4cd5816a | GitHub #4 | 🟢 done | #4 | 2026-07-31 | As ISS-03. |
| ISS-05 | 4120e93f | GitHub #5 | 🟢 done | #5 | 2026-07-31 | As ISS-03. Hash corrected from `49dec1eb`, which does not reproduce from the issue title; the GitHub timeline shows no rename, so the prior value was simply wrong. The decision — filing the issue — is independently verifiable: #5 exists. Not re-interviewed. |
| ISS-06 | f661d445 | GitHub #9 | 🟢 done | #9 | 2026-07-31 | Implemented on `feat/panel-artwork`: catalog, pure `BuildArtSpec` geometry, editor and slash surface, four bundled pieces, 79 tests. Issue closed on GitHub with a comment recording the three departures from the issue as written (blend mode removed, quarter-turns only, per-category art partial). Supersedes the earlier deferral. |
| CODE-01 | 854e4bc3 | `locales/enUS.lua:8-11` | 🟡 deferred | — | 2026-07-31 | "Defer for now." English-only is a stated scope decision for 0.1.0, not an oversight, and the `NS.L` seam is already wired so the pass can happen later without touching call sites. |
| GIT-03 | 9f4990c7 | `git status --porcelain` ▸ `?? modules/Artwork.lua` | 🟢 done | — | 2026-07-31 | "Defer — you commit by hand." Same posture as GIT-02: committing is `/wow-addon:commit`'s job and this command is barred from it. Resolved the same day — the 25 paths carrying the artwork feature landed in `47f507a feat(artwork): draw per-panel artwork inside a panel's bounds`, and the working tree is clean. Closed rather than left deferred: an untracked-file item whose file is now tracked has no pending work behind it. |
| ISS-07 | 7663a77d | GitHub #6 | 🟡 deferred | #6 | 2026-07-31 | Tracker for a decision already recorded under DOC-03 — filed to make the limitation visible in the backlog, explicitly not fixed. A real fix means anonymous pooled frames plus `_G` aliases, which breaks the deterministic frame-name contract. |
| ISS-08 | b535e138 | GitHub #7 | 🟡 deferred | #7 | 2026-07-31 | Tracker for a decision already recorded under DOC-02. Unfixable as such (frame names are immutable); the issue's own proposal is a rename-time notice, which stays available as future work. |
| ISS-09 | 839d9274 | GitHub #8 | 🟡 deferred | #8 | 2026-07-31 | Tracker for a decision already recorded under DOC-05. Self-contained in the shared mouseover ticker whenever it is picked up; the 10Hz interval would need revisiting for an animation. |
| ISS-10 | 9fd018f2 | GitHub #10 | 🟡 deferred | #10 | 2026-07-31 | "Defer — ledger only." Interviewed after the inventory-only pass that first recorded it. Issue #10 already existed and stays open as the single tracker; no duplicate filed. Two gates sit in front of any work here, both named by the issue itself: the resident-memory premise is unmeasured (`UpdateAddOnMemoryUsage` / `GetAddOnMemoryUsage` first), and LoadOnDemand sub-addons have no definition in the Ka0s WoW Addon Standard, so the layout question goes upstream or becomes an accepted deviation before code is written. |
