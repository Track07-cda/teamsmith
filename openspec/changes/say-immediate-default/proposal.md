## Why

PM instructions sent through `team say` can wait behind a target's draft unless the sender remembers an override. The user has chosen immediate-by-default say without a public `--now` flag, while retaining the existing zero-key inbox-watch channel wherever it is usable.

## What Changes

- **BREAKING**: remove `team say --now`, including both argument positions, usage and bilingual help. Reject it through the existing unknown-flag path; do not keep an alias. Preserve `--any` and `--no-verify`.
- Prefer a valid live inbox-watch route: durable inbox plus wake spool, no tmux keys, no forced audit record. If that route fails after selection, retain the ordinary queued/held failure path instead of blindly typing.
- With no usable watcher, default say to the existing forced direct attempt, including into a draft, only after the existing recipient, session, offline, dead-pane and empty-shell checks. Keep one existing-format `forced.log` line per direct attempt and describe the result as an attempt, not confirmed model receipt.
- Narrow draft-protection promises to protected senders. Migrate existing say-based guard demonstrations to draft/notify/explicit queue entries without weakening geometry, race, held, terminal or recovery assertions.
- Update current command/instruction/config/troubleshooting text that promises say waits for drafts. Coordinate the SKILL edit with instruction-context slimming instead of adding competing prose.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `delivery-guard`: scope protected senders; distinguish immediate say attempts, watched handoffs and confirmed guarded delivery; retain ordinary queues, audit format and explicit Outbox/draft overrides.
- `notify-and-inbox`: replace default say draft-queue promises with watch-first/direct-fallback cases, keeping offline and boundary behavior.
- `help-surface`: authorize retirement of only say's `--now`, preserving the remaining flag baseline, help hierarchy, locales and machine exits.

## Impact

Implementation is confined to the say/parser and shared sender seam in `scripts/lib/{cmd-agents,outbox}.sh`, command/help tables, active instruction references and existing delivery/help fixtures under `skills/teamsmith/`. No configuration key, queue format, delivery framework, runtime dependency or scheduler is added. `notify`, automatic completion knocks, meeting/Pulse, `draft send --now` and `outbox flush --now` keep their behavior; dispatch dead-pane and cross-session protections remain regression dependencies, not extra deltas.

This proposal does not repair the old forced branch's best-effort tmux failure gaps and does not promise exactly-once model execution, automatic queueing of direct-send failures, or model receipt from a CLI success. One Apply owner, different from the proposer, can implement the change; a different verifier must review real Pi dirty-box A/B evidence and replacement guard tests. No Apply before formal proposal acceptance and independent substantive review; no live-team experiment, merge, release or real archive is authorized here.
