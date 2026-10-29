# V114 · Independent substantive review of the immediate-say proposal

task: V114
agent: dev3
phase: verify
category: verify
change: say-immediate-default
deltas: -
branch: task/V114-team-say
deps: exact proposal/report tip eb8250a26102; P392 author dev2 must not verify this proposal

Launch note (PM): the project's configured verify provider `cline-pass` is unavailable in current Pi. Use the one-launch explicit model `openai/gpt-6.1-sol:xhigh` authorized by PM for this review; no project config or category mapping is changed and independence is not waived.

## Verdict and scope

You did not author P390/P392. Review exact candidate **`eb8250a26102`** (proposal artifacts `b1d8e74c`). Read the user's decision, D207/D209, P390/P392 reports, `docs/team/reviews/P390.md`, all six change artifacts and the existing delivery/help/notify specs and sender implementation. Give **ACCEPT**, **NEEDS-CHANGES** or **REJECT** first in `docs/team/reports/V114-dev3.md`. This is proposal review, not implementation verification or a live say experiment.

The intended behavior is settled: valid live inbox-watch remains preferred with durable inbox+spool and zero keys; otherwise an eligible running target receives the old forced direct attempt by default, even with a draft. Public `say --now` is removed without alias. Other senders and `outbox flush --now`/`draft send --now` are unchanged.

## Substantive questions

1. **Watch/default ordering:** does the design actually avoid the old force-before-watch trap without forcing queued say entries during later drains? Check fresh-say kind intent, caller/helper responsibility and route revalidation. A selected watch route that disappears or fails persistence must not switch to typing in the same attempt.
2. **Safety and failure truth:** recipient/offline/dead-pane/empty-shell/foreign-session checks must remain immediately before direct send; moving them must not duplicate inbox fallback or skip them under `--no-verify`. Initial enqueue failure must not be reported as offline success. Direct tmux best-effort remains an attempt, not confirmed model receipt or automatic queueing. Assess whether the single bounded enqueue-failure correction is sufficient and correctly scoped.
3. **Audit and CLI:** exactly one existing-format forced line per actual direct attempt; none for watched/offline/parser-rejected calls. Both `say --now` positions reject with zero side effects; `--any`/`--no-verify` remain; bilingual help removes only say's flag while draft/outbox overrides remain.
4. **Spec coverage:** review all seven complete modified requirements and unchanged blocks. General draft protection must be narrowed only for default say, not other senders. The help-surface retirement exception must be limited to this flag. The note about aligning delivery-guard Purpose at authorized archive must not hide a universal contradictory Purpose after implementation.
5. **Test migration:** old say-based geometry/race/held/terminal tests must move to real protected draft/notify/explicit-queue entries with assertions/mutations intact, not be deleted or converted into expected dirty typing. New routing/watch failure and parser controls must be falsifiable. Real Pi must use a genuine editor draft and model-request/frame evidence, not git dirtiness, pane echo or rc=0.
6. **Feasibility and scope:** one different Apply owner, no new config/queue/scheduler/delivery framework, no Pi/provider/runtime changes. P391 shares SKILL.md and needs serialized Apply ordering. P380 remains unmerged; pinned 0.99.2 judged A/B and current 1.4.0 observation must not be mixed or cherry-picked.

Identify any concrete race, false receipt, lost fallback, spec contradiction or unimplementable acceptance as NEEDS-CHANGES with file/line evidence. Otherwise give ACCEPT and list the boundaries Apply/independent Verify must retain.

## Boundaries and acceptance

Only versioned write: `docs/team/reports/V114-dev3.md`; scratch under `$HOME/.cache/V114/`. No product/spec/change edits, no live-team say, no full gate, merge, push or release.

Run in the real available environment:

```bash
openspec status --change say-immediate-default --json
openspec validate say-immediate-default --strict
openspec validate --all --strict
openspec instructions apply --change say-immediate-default --json
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
```

Trial-archive only in a disposable copy. Commit with Conventional Commits + V114 + `Agent: dev3`, leave the branch clean and notify PM. PM will reconcile your review with the formal proposal review before any Apply.
