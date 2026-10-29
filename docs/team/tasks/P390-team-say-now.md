# P390 · Explore immediate-by-default `team say` without `--now`

task: P390
agent: dev2
phase: explore
category: analysis
change: say-immediate-default
deltas: -
branch: task/P390-team-say-now
deps: user product decision 2026-10-29; current main 0875e5c0; P389 is a separate instruction-slimming exploration

## User decision and phase boundary

The user observed that PM's `team say <agent> <message>` without `--now` can be delayed and explicitly requested: **make `team say` default to the existing `--now` behavior and remove the `--now` parameter from `team say`.** This is the product direction, not something to re-vote in exploration.

This brief is **Explore only**. Write `docs/team/reports/P390-dev2.md`; do not edit product/specs/change artifacts/tests yet. A separate proposal and formal review precede Apply.

## Current evidence

- `cmd-agents.sh:1624` initializes `now=0`, parses `--now`, and appends it to `team_send_guarded`; the `queued` arm reports a draft and no keys, while `forced` reports the `--now` direct path.
- `delivery-guard` currently has a general “no automated sender types into a non-empty box” purpose, plus “Which senders defer is explicit, and `--now` is the audited override” with a dirty-box `team say ... --now` scenario.
- `notify-and-inbox` “Messages to a stopped agent fall back to the inbox” currently says a running target with a draft queues the say message and has scenarios proving the draft is untouched.
- `outbox.sh` documents `say --now` as an explicit escape and logs forced sends. `team outbox flush --now` is a separate human escape and is **not** in this removal scope.
- The M30 inbox-watch path can deliver `say` through durable inbox + spool with zero tmux keys; it is already immediate and should not be regressed into pane typing. Offline/dead-pane/shell-prompt checks must still prevent typing into a shell.

## Required investigation

1. Trace the exact existing `say --now` behavior and propose the smallest change that makes it the default and rejects/removes `--now` from `team say` help/parsing. Do not remove `--now` from `outbox flush` or silently change other senders. Determine how the `forced` result/audit should read when immediacy is normal rather than an override.
2. Bound the semantic change precisely: ordinary watched-channel delivery, offline/dead-pane/shell protection, recipient validation, cross-session refusal, `--any` and `--no-verify` behavior must remain intact unless a concrete dependency requires otherwise. `notify`, worker completion knocks, meeting knocks and Pulse must retain their existing draft protection. Ordinary Outbox remains for actual failures, held entries and explicit other flows.
3. Identify every active contract, help surface, PM/worker instruction and test that assumes default `say` defers on a draft or requires `--now`. Do not rewrite historical reports/decisions. The later proposal must modify the general delivery-guard purpose narrowly enough to permit immediate `say` while preserving it for other senders; update the notify-and-inbox say scenarios accordingly.
4. Plan falsifiable before/after evidence with real Pi/tmux fixtures: default `say` into a dirty box now produces the exact old `--now` result and one forced audit record; `say ... --now` is rejected as an unknown parameter; watched-channel say remains zero-key; offline say still uses inbox and never reaches a shell; other senders' dirty-box behavior is unchanged. Include removal-mutation and restoration checks.
5. Note pending-branch interactions without merging them: P381 changes notify's git probe only, P388 keeps ordinary Outbox unchanged, and P389 may slim prose that mentions say. Keep this change independent and do not use those unmerged branches as current-main behavior.
6. Recommend the smallest delta set, implementation files, selected gates and independent verification focus. No new delivery framework, config key, compatibility alias or queue mechanism should be added for this default change. The user explicitly asked to remove the parameter, not retain a hidden alias.

## Boundaries

- Only versioned write: `docs/team/reports/P390-dev2.md`; scratch under `$HOME/.cache/P390/`.
- No code/spec/change edits, no live-team `say` experiments, no actual messages to this team's seats, no full gate, merge, push or release.
- Do not weaken offline/dead-pane/foreign-session protections or broaden the change to notify/meeting/pulse/outbox flush.

## Acceptance and handoff

Run and record:

```bash
openspec validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
bash skills/teamsmith/tests/section-select.sh --paths docs/team/reports/P390-dev2.md
git diff --check
git status --short
```

The report leads with the exact minimal behavior/spec change, affected surfaces and real-Pi verification plan. Commit with Conventional Commits + P390 + `Agent: dev2`, leave the branch clean and notify PM for approach review.
