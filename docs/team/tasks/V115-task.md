# V115 · Independent architecture review of marker-based Pi key replies

task: V115
agent: dev3
phase: explore
category: verify
change: pi-marker-key-replies
deltas: -
branch: task/V115-v115
deps: exact P394 report tip 6b6aef54333ec125542100a698ed8fca86b88a48; user D213; PM independently reproduced the streaming boundary

Launch note: use the PM-authorized one-launch model `openai/gpt-6.1-sol:xhigh` because the configured verify provider `cline-pass` is unavailable. No config change and no waiver of independent review.

## Verdict and scope

You did not author P394. Read its exact report with `git show 6b6aef54333ec125542100a698ed8fca86b88a48:docs/team/reports/P394-dev2.md`, D213, current key-replies/store/extension code and Pi public extension docs/source as needed. Review the proposed marker capture and the two display-boundary options. Give **ACCEPT**, **NEEDS-CHANGES** or **REJECT-APPROACH** first in `docs/team/reports/V115-dev3.md`; this is Explore/architecture review, not proposal or implementation acceptance.

The user requires normal unmarked Pi replies to stay local, marked final assistant replies to be captured into the existing reply page, and the marker to be absent from Pulse and Pi display. Manual CLI remains backfill only. P391 is paused; P393 is unrelated.

## Independent questions

1. **Message semantics:** last-line `[[team-reply]]` / titled variant, structured code-fence/inline-code exclusion, final assistant `stopReason=stop` with no toolCall, settled+aborted gates, empty/ambiguous bodies and title derivation. Find any collision or incorrect publication case, including Magic Context `§N§`, multiple runs/messages and quoted examples.
2. **Identity/dedup/recovery:** session entry ID + session ID, message_end intent, agent_settled publish, reply-store reconciliation on busy/unconfirmed, resume/reload and crash boundaries. Can store and pending journal disagree or double-publish? Is the existing reply writer truly reused, and is ordinary Pi/foreign identity excluded? No exactly-once claim without evidence.
3. **Display truth:** `message_end` replacement cleans final transcript/stdout/history, but public `message_update` cannot transform streamed frames. Evaluate the actual raw-pty evidence and the choice between accepting a bounded flash versus requiring Pi to support message_update replacement before rendering. Storage-only cleanup is not enough. The provider_stream_event mutation is explicitly rejected as a provider-specific response-rewrite framework, not a supported solution.
4. **Minimal design:** one directed PM-only `team-reply.ts`, no second reply database, no worker injection yet, no ordinary-Pi capture, no extra model cost for unmarked replies. Injection/fingerprint/doctor/reload obligations and P391 instruction coordination must be concrete enough for Propose.
5. **Verification:** fake-host versus real Pi rendering, raw stream versus sampled screenshots, final/intermediate/aborted messages, store failures, duplicate/reload, UTF-8/code preservation, no live team impact, and real-model marker compliance still unmeasured. Identify any Apply acceptance that would be falsely green.

PM independently reran cases I/J in `$HOME/.cache/pm-skills-reviews/P394-6b6aef54/probe/`: raw pty shows the complete marker for ~187ms/~95ms before replacement; final pane is clean, but sampled frames can miss the flash (case J had zero sampled hits while raw stream had one). Treat this as direct evidence to inspect, not a reason to weaken the user's display requirement.

Finish with the smallest architecture allowed into Propose under each display option, any additional blocker, and which option you recommend with evidence. Do not make the user's A/B decision for them and do not start a proposal.

## Boundaries and acceptance

Only versioned write: `docs/team/reports/V115-dev3.md`; scratch under `$HOME/.cache/V115/`. You may rerun existing scratch probes in a private copy, but no product/spec/change edits, live-team messages, real credentials, full gate, merge, push or release.

Run `openspec validate --all --strict`, `spec-refs.sh --check`, real-project `ledger-ban.sh`, and `git diff --check`, recording actual output. Commit with V115 + `Agent: dev3`, leave the branch clean and notify PM.

## Second round after identity/recovery rework (2026-10-29)

The exact revised P394 candidate is **`40d6f63e`**. Read its appended §§一–九 with `git show 40d6f63e:docs/team/reports/P394-dev2.md`. Preserve the first-round report and append a second-round verdict at the top and bottom of `docs/team/reports/V115-dev3.md`. Use the same one-launch model override if a fresh session is needed.

D214 remains settled as A: transient stream visibility is accepted; final full control lines must be cleaned from finalized transcript/history/Pulse/store. Do not reopen B or demand zero stream flash. Review whether the revision closes the actual first-round blockers without inventing a second reply framework:

1. message_end staging → turn_end entry binding → settled eligibility; only latest current-activity candidate, later unmarked/failed/aborted supersession, branch/session scoping, and recovery of explicitly eligible-but-never-attempting records only.
2. One source tuple/record and one attempting right before spawn; writer outcome mapping, unconfirmed candidate_no, process/receipt/journal failure as uncertain with no automatic retry. Identical bodies on distinct entries remain legal; no hash/current-page ownership.
3. Cleanup on every assistant terminal state versus publication eligibility; full control lines removed on aborted/error/tool-use, partial-prefix abort boundary disclosed rather than guessed away. Parser offset fidelity, code/fence/quotation rules, multi-text-block/CRLF/UTF-8 and title derivation.
4. Directed PM-only injection, actual project/state/session/tmux/PID identity evidence, duplicate-copy owner/CAS, update fingerprint, doctor's loaded-versus-on-disk distinction, first-injection restart versus already-loaded reload, custom adapter non-support. Check whether these are necessary or can be simplified without losing isolation.
5. Required MODIFIED key-replies requirements (not contradictory ADDED-only), guide/spec/test migration, real product parser/writer/raw-stream evidence and all crash/fault cases. The new lifecycle probe is only literal API evidence, not a product implementation pass.

Give **ACCEPT FOR PROPOSE**, **NEEDS-CHANGES** or **REJECT-APPROACH**, with exact remaining corrections. This is still not proposal or implementation approval. Only the V115 report changes; no live team/product/spec writes, full gate, merge, push or release. Run the same light checks, commit with V115 + `Agent: dev3`, and notify PM.

## Third round: R1/R2 only (2026-10-29)

The final corrected P394 candidate is **`683d591a3e91`**. Its appended “V115 第二轮定点修正” section preserves the previous 467 lines and changes only the two findings from your second round. Do not reopen the accepted lifecycle/identity/recovery/injection architecture or D214's A.

Verify narrowly:

1. R1: paired maximal backtick runs, exact-length closer, cross-line and cross-text-block spans, differing lengths inside a span, escaped openers, and unmatched openers that do not protect the rest of the message. The proposed product-parser cases must prove inline-only content is unchanged/no writer, inline+real-control deletes/publishes only the real line, and mutations removing inline protection or protecting unmatched-to-EOF fail. No full Markdown AST is required.
2. R2: the future delta names the three real requirements — `Key replies are explicitly published from bounded stdin`, `Publication does not gate the normal answer or create work`, and `The key-conclusion duty is shipped on its instruction surfaces and held by the gate` — as MODIFIED. Purpose alignment must be explicitly handled outside delta-only merging, with a private trial archive and landed-text check at the authorized stage. Old manual duplicate-post/no-history-import/no-panel-session-read boundaries remain.

Append a third-round verdict at the top and bottom of `docs/team/reports/V115-dev3.md`: **ACCEPT FOR PROPOSE**, **NEEDS-CHANGES** or **REJECT-APPROACH**. If accepted, P395 may write planning-only OpenSpec artifacts; this is not Apply approval. Run the light checks, commit only the V115 report with V115 + `Agent: dev3`, and notify PM. No product/spec/change/live-team writes, full gate, merge, push or release.
