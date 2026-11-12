# Proposal

## Why

A final report can be committed without producing a new PM wake-up. The accepted V153 investigation found two causes: a job run in an independent checkout was not attributed to the session that started it, and a later delivered revision was merged into an earlier line without another wake. PM guidance also lacks a required disk reconciliation step when no new notice arrives.

## What Changes

- Record the initiating session directory separately from the job's execution directory. Attribute suspension by the initiating session while retaining the existing live `(pid, start-time)` check. Accept a legacy record only when its execution directory unambiguously matches the seat worktree; otherwise attribute it to no seat.
- **BREAKING:** Start a new inbox line and one wake for each distinct delivered tip. Keep same-tip delivered events merged and deduplicated, allow suspended progress revisions to merge without waking, and keep the existing suspended-to-delivered line transition. Senders without a provable revision stamp retain the existing no-revision merge behavior.
- Update the PM prompt template, skill and workflow guidance to prefer notifications but treat files as authoritative. Before repeating an unchanged waiting report, reconcile the digest, board, task-branch report and Git state; neither an old tip, an absent notice nor a merged line proves that work is unfinished.
- Reuse the existing background lane, notification writer, watcher and ledger harness. Add no notification channel, polling service, manual duplicate-notification duty or PM-run verification requirement.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `notify-and-inbox`: separate job initiator identity from execution cwd and replace unconditional cross-revision merging with delivered-revision boundaries.
- `background-jobs`: define the durable initiating-session field and legacy-record compatibility without changing process identity checks or restart behavior.
- `pm-lifecycle`: require file-based reconciliation during ordinary PM waiting, without adding a scheduler or changing PM liveness and recovery rules.

## Impact

Implementation will affect `skills/teamsmith/extension/team-bg.ts`, `skills/teamsmith/extension/team-notify.ts`, `skills/teamsmith/scripts/lib/cmd-agents.sh`, `skills/teamsmith/tests/bg-ledger-harness.mjs`, `skills/teamsmith/tests/bg-ledger.sh`, `skills/teamsmith/templates/pm-prompt.md.tmpl`, `skills/teamsmith/SKILL.md`, `skills/teamsmith/references/workflows.md`, and `skills/teamsmith/references/protocol.md`. Existing job records remain readable under the bounded legacy rule. Existing watcher `read`/`intent`/`sent` evidence and its API-accepted-not-model-read boundary remain unchanged. Verification uses focused structural checks, the registered background-ledger section and real notification paths, plus one isolated real-PM guidance exercise; no full, nightly or section-61b run is planned by this proposal.
