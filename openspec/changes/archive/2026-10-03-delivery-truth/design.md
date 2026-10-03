## Context

See proposal.md for motivation and the three delta specs for behavior. P138's package was recovered from git object `42e364fb` into this task's own report directory; neither the main worktree nor another seat was modified. The PM's prior reproduction is `docs/team/reviews/P138.md`.

P143 independently ran the same container recipe against `ccfdf854` with the installed **Pi 0.99.2**, not P138's 0.99.1. On the new real 120×32 capture, the production box is `[21 30]`; the actual empty editor is `[28 30]`, cursor 29. A planning-only frame probe admitted the closed suffix and read EMPTY on those same real bytes; the matching real human-draft capture stayed BUSY. This is geometry feasibility evidence, not a patched sender or an end-to-end implementation-green claim. The watcher positive control received the second correction once. Evidence and provenance are in `docs/team/reports/P143-verify/`.

## Goals / Non-Goals

**Goals:** make geometry trust explicit at the existing delivery boundary; preserve content/race/confirmation safety; preserve immutable payload files while recording obstruction separately; keep notify's three durable-path values identical.

**Non-Goals:** no generic nearest-border strategy, no retry-count workaround for the real-frame geometry defect, no weakening of update-banner/rule-draft/status-row guards, no new intent/daemon, no PM-liveness change, no repaste of terminal holds, no cross-machine transport, no claim about the CEP original incident. Proposal edits are limited to this change and P143's own evidence/report. Apply requires a different owner, a PM ACCEPTED proposal review, and an explicit path grant; protected baseline specs, team ledger, other projects and credentials are not implementation targets.

## Decisions

### D1. Restrict the candidate domain only for a proved closed Pi suffix

Retain `_team_box_geometry` as the shared frame geometry source for production extraction, transcript proof and frame judgement. Add a single supported-layout admission decision before the existing highest-top/lowest-bottom ordering. Pass target context separately from captured text; fixture probes use recorded context, never a second geometry implementation.

The initially evidenced shape is the unscrolled Pi 0.99.2 editor immediately above its two-row footer:

1. The final footer pair has the runtime cwd (with the measured optional branch decoration) and the measured context/model status grammar. Validate cwd against the already resolved target process, not against a user-looking string alone. The footer is below the cursor and outside the editor.
2. The bottom is the matching full-pane-width rule directly above that footer. The top is a matching full rule strictly above the cursor. All content rows fit the measured visible-editor height (`max(5, floor(terminal_rows × .3))`) and render width. At zero horizontal padding Pi reserves one column for the cursor: text layout width is `pane_width - 1`. Cursor-highlight/trailing spaces do not create text-border candidates.
3. Enumerate rectangles satisfying the whole shape. Admit a narrowed domain only when exactly one survives. An intervening full-width transcript rule disqualifies the larger rectangle as editor content; it is not excluded merely because its text is a known reply or a blank line is near it.
4. Read every interior row; keep cursor-first status handling, banner exclusion/fallback, folded-paste settling, and pre-Enter races. The same selected rectangle bounds the transcript submission proof, otherwise the first correction could still be wrongly terminalized after actual delivery.

The renderer inspected for this feasibility argument is `@earendil-works/pi-tui/dist/components/editor.js:393–475`: layoutWidth reserves the cursor column, visible lines are capped, and two full rules bracket them. The planning probe deliberately handles ASCII text only and labels that limitation. Production must use terminal cells, not byte counts: CJK, emoji, combining marks, tabs, padding and wrapping need measured controls before extending admission. A version number, pane height, idle flag or footer alone is insufficient. A scrolled/unsupported shape keeps the original conservative domain when readable; recognised Pi with conflicting evidence becomes `geometry-untrusted` without typing. The existing non-Pi unknown-shape path remains separate.

**Rejected:** taking the nearest rule globally (reopens P67/P78 draft glue); recognising assistant text/spinner words (open text vocabulary, spoofable); stripping every rule above the cursor (drops rule-shaped drafts); adding a settle delay (same stable wrong frame); requiring inbox-watch (hides an existing supported fallback). A trusted closed layout is narrower than those strategies and has a test-process shadow that restores the exact real-frame red verdict.

### D2. Record trust and obstruction without changing the payload interface

Carry geometry verdict, trust/reason, entry id and touched-input status through the existing sender/drain result. Map the existing honest states to `delivered`, `queued` or `held`, with additive machine reason fields, not a new intent. Fix the present catch-all that collapses a held result into queued before CLI/panel mapping.

Use atomic companion observations under `state/outbox/diagnostics/<entry-id>.json`, updated under the existing entry claim. They hold schema version, target, observed verdict, geometry/trust reason, first/last observation timestamps, consecutive-empty count, durable inbox path and impediment reason. Do not rewrite `<entry-id>.msg`. Diagnostics follow TEAM_STATE_DIR, are bounded by existing entries, and are removed with an explicitly dropped or confirmed-delivered entry. Missing optional diagnostics for legacy entries mean no known impediment; unreadable/malformed diagnostics mean unavailable, not verified zero.

Count only claimed, live-target, FIFO-eligible evaluations that read a trusted EMPTY but make no progress while leaving a never-typed entry queued. The third consecutive evaluation becomes `held/queue-stalled`; a BUSY/WORKING read resets the count. This is an evaluation bound, not a wall-clock claim or an extra polling loop. Untrusted geometry holds immediately. Both have a durable inbox copy before holding and an explicit recovery command. TTL remains unchanged for ordinary drafts/offline queues. Once input was touched, existing draft-race/unconfirmed terminal behavior wins; stall-timeout resumes only its pending Enter, never a paste.

`team say`, `notify`, flush and draft receipts propagate nonzero obstruction outcomes; a pulse tick records them rather than promising future automatic delivery. `outbox list`, status/digest and the panel read companion records only. The panel's existing flush subprocess is still the sole writer on that action. New string-table keys have identical zh/en shapes and the committed bundle is rebuilt. No pane capture, process probe or observation-counter update is added to panel refreshes.

**Rejected:** relying on TTL as the first error signal (up to five minutes of false reassurance); elapsed-age-only stall detection (mislabels real drafts); changing queued to confirmed (loses payloads); reusing terminal holds as resumable (duplicates payloads); a new daemon or new status-only inference (two conflicting truths).

### D3. Separate notify's PM knock destination from its durable recipient

Keep the existing operational destination, `$TEAM_SESSION:$TEAM_PM_WINDOW`. Resolve sender exactly as P82 requires; keep the caller's recipient as the durable file. After a successful append to `<recipient>.md`, pass `--inbox-written <recipient>` through the guarded/outbox path. The watcher spool/journal and wake use that explicit durable recipient; they must not infer it from the PM target or overwrite it using the watcher registration's own inbox name. Preserve `from`, dedup and source identity. The automatic turn-end path retains its own resolved worker inbox and PM knock; test it alongside manual notify so the fix cannot silently regress it.

A failed durable append fails the command before a declaration/wake is emitted. Do not create pm.md, copy the full text to two inboxes or retarget the knock to dev to mask the mismatch. Inbox-only mode remains one append and no queue/knock. Foreign targets remain guarded.

**Rejected:** moving notify's knock to the named worker (changes the existing agent→PM operation); routing every durable notification to pm.md (changes recipient semantics); adding a second durable copy (duplicates unread work and conceals the declaration bug).

## Risks / Trade-offs

- **New Pi render layouts:** a narrow suffix may reject autocomplete, scroll or changed footers. Preserve readable conservative behavior or expose untrusted geometry with durable recovery; extend the closed set only with new real captures and draft adversaries.
- **Indistinguishable clipped frames:** raw bytes cannot prove every arbitrary TUI's editor boundary. Such frames do not qualify for the supported-renderer exception; retain the documented conservative costs. No universal monotonicity claim is added.
- **Existing baseline wording:** highest/lowest ordering still governs the legacy domain; only the proved suffix narrows candidates. All 49 scenarios in six MODIFIED blocks are retained verbatim. The pre-change stored-frame comparison remains unchanged; the new real idle-empty captures are explicitly enumerated BUSY→EMPTY exceptions, paired with real drafted controls. See P143's scenario-comparison table.
- **Concurrent drain observations:** count only under the owning claim and atomic sidecar update; contention is not evidence of a stall. Tests must prove concurrent drains cannot double-count one observation or double-send.
- **New nonzero outcomes:** scripts that previously accepted false-green queued output now see an impediment. The payload remains durable, and normal trusted-draft queueing keeps exit 0. Document the reason/recovery contract.
- **Feasibility gap:** P143 proves two real frame reads and real watcher reception, not a shipping fallback fix, Unicode support, panel reason rendering or three-attempt recovery. Apply and independent verify must provide those green results; planning checkboxes remain unchecked.

## Migration Plan

1. PM reviews this proposal, then assigns apply with explicit grants. Add regression captures and test shadows first; preserve red output before modifying product behavior.
2. Implement the shared geometry admission and diagnostics, then path propagation and CLI/panel mapping. Do not automatically repaste pre-existing terminal holds. Legacy `.msg` files remain readable without sidecars.
3. Independently verify real fallback/watch routes, draft/rule adversaries, first-message confirmation, notify paths, obstruction transitions and all preserved scenarios. Run strict validation and the full correctness gate inside a disposable full-dependency container/independent clone, never against the user's default tmux socket. Archive is a separate PM phase after confirmation.
4. Rollback code/bundle through a normal commit; keep immutable payloads/inbox lines and held reasons. Do not delete queue/journal evidence or replay terminal entries to make rollback look healthy.

## Acceptance and Evidence

Proposal-stage checks (no code edits):

```bash
PATH=<home>/.bun/bin:$PATH openspec validate --all --strict
python3 docs/team/reports/P143-verify/pkg/check-deltas.py
python3 docs/team/reports/P143-verify/pkg/shape-probe.py
```

Apply/verify must promote this recipe into skill-owned gate fixtures before archive. These copy-pasteable real-process commands cover the central flip (use fresh evidence case names on repeat runs):

```bash
P138_SECOND=1 bash docs/team/reports/P143-verify/pkg/run-case.sh tmux-delivery-truth-dirty HEAD 0 host
python3 docs/team/reports/P143-verify/pkg/judge-second.py tmux-delivery-truth-dirty
P138_SECOND=1 P143_DRAFT=1 bash docs/team/reports/P143-verify/pkg/run-case.sh tmux-delivery-truth-draft-dirty HEAD 0 host
P138_SECOND=1 bash docs/team/reports/P143-verify/pkg/run-case.sh watch-delivery-truth-dirty HEAD 0 host
python3 docs/team/reports/P143-verify/pkg/judge-second.py watch-delivery-truth-dirty
```

The report must include raw command/output tails and Pi versions; before/after frame, cursor, actual editor/idle state and model reception counts; first-send state and no duplicate; a real drafted control and test-process mutations that turn the guard red; notify recipient/declaration/wake path equality and file existence; stalled and untrusted reason/exit/sidecar evidence; panel read-only hashes and reason receipt mutation; scenario preservation table; full-gate output with any skips/failures named. Do not substitute the planning probe for production-green or cite P138 as if personally rerun.
