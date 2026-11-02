## Context

See `proposal.md` for motivation and the three delta files for the behavior contract. P390 (`ec78b6c622ad`, accepted in `docs/team/reviews/P390.md`) traced the two important facts:

- `team_cmd_say` in `skills/teamsmith/scripts/lib/cmd-agents.sh` currently probes watch availability to skip tmux/offline checks, then passes a public `--now` option into `team_send_guarded`.
- `team_send_guarded` in `scripts/lib/outbox.sh` executes its force branch **before** watch routing. The queue processor separately prefers watch only without an explicit force override. Setting the parser's `now=1` would therefore bypass the preferred channel. Checking watch in the caller and again in the helper also leaves a route-loss interval after the caller skipped target checks.

The existing force branch logs before sending, tolerates tmux failures and uses a snapshot-change wait with a possible extra Enter. That is not submission proof. The existing watch writer can persist an inbox line before a spool write fails; a later retry is not a new exactly-once persistence guarantee. These boundaries determine the acknowledgements and failure tests below.

## Goals / Non-Goals

**Goals:** Make the default decision at one shared sender seam, keep target eligibility immediately ahead of any say direct attempt, and reuse the existing force action and queue pipeline. Keep the watched attempt zero-key even if its selected route disappears during handoff. Replace obsolete guard demonstrations rather than creating another delivery test family.

**Non-Goals:** No configuration switch, CLI alias, queue/header format change, daemon, new delivery framework, provider compatibility work or global forced-failure recovery. No change to ordinary drains just because an entry's kind is `say`. No hardening claim for the existing direct path's duplicate/extra-Enter window. No live team messages or credentials in fixtures.

## Decisions

### 1. Separate default say intent from the explicit shared force option

Remove `--now` handling and its local variable from `team_cmd_say`, plus usage/help entries. Keep recipient validation, one-line validation, window resolution, `--any` and `--no-verify`. Do not forward the private helper's `--now` to implement the new default.

Use the already-present `kind=say` argument at `team_send_guarded` as the local default-direct intent. Only the **fresh sender entry**, not `team_outbox_process_entry`, interprets it. This avoids a new public or hidden CLI flag and avoids making future normal drains force queued say entries.

The existing explicit helper `--now` paths remain explicit overrides for draft/Outbox and retain their priority. For default say (`kind=say`, no explicit override), select a validated watch route before choosing the direct action. Reuse the existing force block once, after that decision; do not copy its logging, typing, text conversion or Enter loop into `cmd-agents.sh`. Other sender kinds continue through their existing guarded/watch paths.

Rejected alternatives: flipping `now=0` to `1` bypasses watch; defaulting force by kind in the queue processor changes flush/tick semantics; making each caller implement tmux/queue branches duplicates the failure surface.

### 2. Move, rather than duplicate, say's pre-direct target checks

Extract the existing missing-window/dead-pane/empty-shell block into a small say-specific helper in `cmd-agents.sh` (for example `team_say_prepare_direct`). Call it from the no-watch say branch in `team_send_guarded`, using the validated recipient already passed as `--inbox`, the resolved target and payload. Preserve the existing offline inbox wording, dead-pane evidence and resume hints. The helper distinguishes a permitted running target from an already-handled offline/dead result; the caller must not append the same fallback again. Give `team_cmd_say` an explicit handled-offline outcome branch rather than falling into its old catch-all append.

The old caller-side watch probe and its conditional target-check block are removed. Thus an accepted watch route needs no pane inspection, while a rejected registration cannot cause a direct action without the moved checks. Recipient and existing target/session validation still precede any key; the force action keeps the existing runtime tmux target boundary. `--no-verify` does not skip these checks.

This is the product's routing behavior, not another independent safety framework. Dispatch's dead-pane detection and session-boundary implementation are reused, not rewritten or given new deltas.

### 3. A selected watch attempt cannot silently change transport

Use the current `team_outbox_enqueue` → `team_outbox_process_entry` → `team_inbox_watch_deliver` path, including its immutable entry and claim. Add only a private, per-call watch-only mode to the **immediate processing of a default say entry already selected for watch** (for example an internal `--watch-only` function argument). No new entry header, persisted intent, queue or configuration is needed.

Processing revalidates the route through the existing watcher predicate. In that mode a missing route returns the existing queued result without typing; inbox/spool write failure also retains the entry and returns the existing pending result. If enqueue itself fails before an entry exists, propagate a nonzero persistence error without claiming a queued entry or manufacturing an offline fallback. `team_cmd_say` must preserve that failed return/outcome instead of letting its catch-all report inbox delivery. None of these failures falls through to guarded typing or default force during that same attempt. The subsequent normal drain remains the existing guarded drain; a human's explicit flush override remains explicit. All other kinds and processor callers retain their current semantics.

This closes the newly relevant handoff interval without freezing watcher identities in queue files. Initially rejected registrations mean "no usable watcher": only a separately checked running target can take default direct fallback. A registration accepted and then lost means "selected handoff did not complete": retain pending state instead. These are not the same outcome.

The bounded failure correction is selected-watch initial enqueue failure: current `team_send_guarded` returns `TEAM_SEND_OUTCOME=offline` when enqueue produces no entry, and current `team_cmd_say`'s catch-all then calls `team_say_offline`, alleging the agent exited instead of naming the write failure (`outbox.sh`'s post-enqueue existence check; `cmd-agents.sh`'s outcome case). A test-owned failed-enqueue injection must make that one say call report the real nonzero error, with zero keys and no phantom queue/inbox success. This does not repair direct tmux failures or change other senders' failure recovery.

Keep enqueue/claim/persistence code single-sourced. This design does not promise inbox-write deduplication across a partial watch failure and retry; normal successful handoff and eventual normal receipt are tested once per unique message, and failure tests must retain the full payload without claiming success.

### 4. Preserve the force audit; stop calling an attempt a receipt

Default say's direct action calls the existing `team_outbox_force_log` exactly once, with the same timestamp and `kind=say from=pm target=<target> entry=none` fields in the same order. Do not log in both caller and helper. Watched, parser-rejected and offline/dead results add no forced line. A transport error after the force audit can still leave a line: it is an attempt audit, not a successful-submission receipt.

Scope the direct branch's warning/acknowledgement by sender kind so default say never suggests the retired flag. A suitable say result is `attempted immediate send to <target>: <message>` / `已尝试立即发送；未确认模型接收` plus the audit location. It must not use the guarded `已确认送达` acknowledgement. Keep the internal `forced` outcome if convenient; a new public status schema is unnecessary.

Successful watch acknowledgement describes inbox/spool persistence and zero keys only. For an actual watch persistence/routing queue, the existing queued outcome must not falsely assert "the target has a draft" or promise automatic delivery upon clearing it; distinguish its channel reason locally. Geometry/stall held output and ordinary protected-sender queued/confirmed output retain their existing factual distinctions.

No direct-failure repair is selected. Existing best-effort payload/Enter calls, return behavior, snapshot waiting and optional second Enter remain bounded by the old implementation. Tests inject a payload/Enter failure to ensure the wording does not claim confirmed receipt or an automatic queue fallback; they do not pretend rc=0 or forced.log is a model receipt.

### 5. Modify complete requirement blocks, preserve protected coverage

`delivery-guard` modifies five full requirements: protected-send scope; pane confirmation versus attempt acknowledgement; explicit sender/override scope; banner end-to-end caller; queue-impediment caller. Existing headings are kept as stable reference anchors, with normative protected scope explicit in the opening text. All other requirements, geometry algorithms and diagnostic/recovery invariants remain intact.

OpenSpec 1.8.0 validates preservation of existing scenario titles in MODIFIED blocks. The old `--now types into a dirty box and is logged` scenario now exercises the still-supported explicit draft/Outbox overrides. In `notify-and-inbox`, `A draft in the target's input box is not disturbed` exercises a valid watcher, and `A single-line draft queues the message` exercises failed selected-watch handoff, explicitly not draft-caused deferral. Separate new no-watch scenarios state the new direct behavior. This preserves the old anchors without retaining their obsolete unconditional default-say promise.

Fixture migration map (change the entry point and keep the original assertions/red sides):

| Existing site | Replacement / retained evidence |
|---|---|
| smoke `12b` say draft queue/clean confirmed/static footer/race/unknown-shape cases; `tests/guard-matrix.sh` | ordinary `draft send` to PM, `notify` where sender behavior is the subject, or explicit enqueue + ordinary flush to the same worker pane; keep exact zero-key, payload, FIFO, held/terminal and confirmation checks |
| smoke `42`, `44`, `12b-h0*`; `tests/pm-box-real.sh` and stored frames | retain extraction/geometry mutations unchanged; migrate say-driven protected sends to draft/explicit queue, not to forced expectations |
| `tests/delivery-truth.sh` drafts/foreign/queue/receipts | protected draft/queue entry for geometry, races, unconfirmed/stalled/held assertions; keep default say only where testing new routing or target boundary |
| smoke `12b-pi`, `12b-pi2` / existing watcher harness | retain clean/dirty watch, spool and zero-key assertions; add the selected-route-loss/persistence controls to these cases rather than invent a suite |
| `tests/help-surface.sh` executable say probe and pre-change flag baseline | remove only say's `--now`, probe the default invocation, add both rejection positions to the same fixture; retain draft/outbox probes and machine comparisons |
| `tests/fixtures/delivery-truth-real/{run-case.sh,scenario.sh,observe.ts,mock-server.py,judge-second.py,README.md}` | extend only the existing recipe where necessary for identical genuine dirty-editor A/B and receipt collection; keep its version/single-run judge restrictions |

The new routing/rejection controls replace the retired say queue/forced-flag cases. Do not add a new smoke section or process-only refusal; keep existing guard red sides falsifiable through protected entries. No test logic goes into product code.

### 6. Update active surfaces once; do not rewrite history

Edit `skills/teamsmith/scripts/strings/commands.tsv` and `help.{en,zh}.tsv`, say parser usage and sender-specific messages. Keep draft/outbox flags in manifest/help and behavior probes. Update `skills/teamsmith/SKILL.md`'s review-failure instruction, `references/config.md`'s delivery section, and `references/troubleshooting.md`'s top receipt claim, §2/§3, current geometry/recovery wording and later slow-path sections that imply say always waits behind drafts. Retain dated historical evidence as history, not as a current instruction. Scan active skill/reference/template surfaces for the same false promise; do not sweep historical reports/decisions.

P391 (`instruction-context-slimming`) also plans an instruction rewrite. PM serializes Apply owners for `SKILL.md`: rebase/reconcile the short say correction on whichever instruction version lands first, keeping the settled rule once and detailed delivery explanation in references. This change does not independently rewrite AGENTS/PM/worker prompts or add a competing long instruction block.

OpenSpec does not merge Purpose updates for existing capabilities. At authorized archive, PM separately aligns `delivery-guard`'s opening Purpose sentence with its narrowed protected-sender scope; Propose and Apply do not edit canonical requirements. The trial archive checks requirement merging now; the report calls out this required editorial alignment rather than hiding the old universal Purpose claim.

## Risks / Trade-offs

- A human draft will be submitted together with a default no-watch say → this is the user's chosen old forced behavior, demonstrated using the same draft bytes in baseline and candidate model requests, not called draft-safe.
- A watcher disappears between selection and queue processing → retain the entry via the local watch-only processing mode; no unchecked force or guarded typing during that attempt.
- Partial watch persistence may already have written an inbox line before failure → retain pending payload, make no success/exactly-once retry claim, do not add a new transaction or recovery framework.
- Direct tmux failures and a possible extra Enter remain best-effort → honest attempt wording, captured failure controls and no claim of model receipt or automatic retry.
- Replacing say guard tests could accidentally delete substantive protection → preserve geometry/race/held/terminal assertions and their existing mutations on actual protected senders; independent verification reviews the before/after test map.
- Baseline runner's `dirty` name means dirty git state, not necessarily a human editor draft → type and capture a genuine editor draft before each tested send. Do not substitute git dirtiness, stderr text in an editor, or a pane-only echo for request evidence.
- The old judge supports 0.99.2 only → use pinned 0.99.2 for reproducible judged A/B and second-message evidence; current Pi 1.4.0 is a separate direct request/frame observation, not an old-judge pass. Do not reuse P380 evidence selectively.

## Migration Plan

After formal ACCEPTED proposal review and independent substantive review, dispatch one different Apply owner. Implement the parser/sender seam, update active surfaces and migrate fixtures together. Freeze a candidate commit before running recipe archives; record the baseline and candidate SHAs. There is no persisted-state migration or live init/reload in this change.

For targeted verification, the read-only selector was exercised with `--select 6,7,11g,12b,12b-h0,12b-h0b,12b-h0c,12b-h0d,12b-pi,12b-pi2,42,44,46,47,51,57,56`. At this base it selects 29 keys including prologues and dependencies: `0,0b,0c,0d,2,4,5,3b,6,6i,7,11g,12b,12b-h0,12b-h0b,12b-h0d,12b-h0c,12b-pi,12b-pi2,42,43,44,45,46,47,51,55,56,57`. This is a minimum relevant selection, not proof of execution and not a replacement for the actual changed-path closure. Apply computes `section-select.sh --paths` from its real changed product/test paths, records every selected key and executes that closure; run the relevant cases non-FAST, then `delivery-truth.sh --section all --mutations` and real Pi A/B. FAST skips do not satisfy those cases. No full smoke gate is run during Propose.

Long verification runs use `team_bg_run`, serial gate locking and complete host-side logs with scratch under `/var/tmp`. For the container recipe, change only its test-owned `/tmp` staging/HOME defaults to `/var/tmp` and mount evidence/scratch on disk; keep `--network=none`, private tmux and the loopback mock provider, with no credential mounts or live-team targets. The independent verifier reruns the candidate from a separate checkout and repeats the three routing/parser mutations plus existing guard mutations. PM owns final full-gate/merge ordering.

Rollback before merge is simply returning the local candidate branch to the accepted base; no user data has been migrated. After an authorized merge, revert the implementation/help/test commits as one coherent behavior change, keeping historical forced logs and pending/held entries untouched. No push, merge, release or live restart is part of this proposal.
