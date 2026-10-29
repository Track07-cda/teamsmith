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
