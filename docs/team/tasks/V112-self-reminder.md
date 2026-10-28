# V112 · Independently review the Agent Self-Reminder OpenSpec proposal

task: V112
agent: dev3
phase: verify
category: verify
change: agent-self-reminder
deltas: -
branch: task/V112-self-reminder
deps: P387 proposal/report candidate f9edff1a6c90 (spec artifacts 751ad9bb); P385/V111 accepted exploration and D204/D205

## Verdict and scope

You did not write P387. Independently review exact candidate **`f9edff1a6c90`** before PM marks `docs/team/reviews/agent-self-reminder-proposal.md` ACCEPTED. Lead and end `docs/team/reports/V112-dev3.md` with **ACCEPT**, **NEEDS-CHANGES**, or **REJECT**, each finding tied to a concrete requirement/design counterexample and saying what it changes. This is a substantive proposal review, not implementation verification and not Apply authorization.

Read the full candidate `proposal.md`, `design.md`, `tasks.md`, every delta spec, P387 report, raw user requirements/D204, final P385/V111 and the current canonical specs/source needed to test its claims. Do not rely on the proposal's summary or OpenSpec structural validation alone. The candidate adds about 1000 lines across a new capability and six modified capabilities.

Only versioned write: `docs/team/reports/V112-dev3.md`. Scratch evidence under `$HOME/.cache/V112/`. Do not modify the proposal, canonical specs, product/tests/config, live state or another task's files. No merge/push/release/Apply.

## Critical review questions

1. **D204 fidelity and the disclosed ambiguous generation.** The user requires PM-owned reminders (PM tool or user CLI) to wake during Standby and an actual wake to clear Standby, once per batch. The proposal preserves a newer G2 when it cannot prove whether G2 preceded or followed the Pi event, so an actual wake may not auto-clear in that case. Decide whether this is an honest, sufficiently narrow boundary consistent with the prior V111 allowance, or a contract failure requiring a different design. Check normal G1, G2-before-intent, delayed handler, duplicate/late batch events, manual off/re-on and crash recovery. Do not reopen the settled choice to allow reminders during Standby.

2. **Is the shared authority/minimal migration justified?** The design moves all Standby state/readers/writers into `reminders/state.json`, adds a canonical state-root locator, permanent `flock` lock, generation snapshot and quiesced migration/rollback. Assess whether this is the smallest correct mechanism or avoidable control-plane breadth. Identify concrete alternatives if simpler ones preserve the same atomicity. Check legacy marker import, old/new mixed writers, state override conflicts, corrupt/torn state and no-Reminder projects.

3. **New `flock` compatibility cost.** On hosts without it, even legacy Standby mutation must now fail visibly. Determine whether the delta and migration make that change explicit and acceptable under current environment requirements, or whether it silently breaks a supported environment. Check the proposed Bash/Node invocation, lock lifetime, owner death, `TMPDIR` independence, no Pi/model wait under lock and doctor/rollback behavior. Distinguish scratch proof from production proof.

4. **Single delivery authority and Pi observations.** Verify scheduled/due/queued/intent/observed/unknown/resolved/cancelled transitions, batch atomicity, key/id reuse, active unknown retention, terminal/audit pruning, late events and explicit `resolve --ack-unknown`. Ensure no second journal can authorize resend and no API return/message event is mislabeled model completion. Look for states that can become unrecoverable, duplicate a batch, or clear Standby twice.

5. **Prompt-free recovery and ordinary-work suppression.** Challenge the design against a stopped PM with ordinary digest/inbox backlog, existing `starting`/quota/identity guards, watcher startup, direct Reminder delivery and no generic `@pm-prompt`. Can ordinary work start before actual wake/auto-off? Are separately authorized Outbox drain/`--now` semantics preserved rather than accidentally changed? Does the cold-start scratch probe prove only what the report claims?

6. **Pulse and tool feasibility.** Both console and headless must support lightweight due admission during a long patrol without a second daemon, overlapping patrol or high-frequency full scan. The PM-only tool must not leak to workers/ordinary Pi, must handle no-unregister/reload/per-call identity and honest doctor evidence. Check that the 30-second target is scoped to durable enqueue and that no-Reminder projects incur no model/full-patrol increase.

7. **Delta/spec/task quality.** Compare every MODIFIED delta against its canonical requirement: preserve still-true scenarios, make D204's changed AC-06 explicit, and avoid parallel requirement lists. Ensure the new capability covers raw FR/AC without promising exactly-once or real-time model execution. Tasks must include all four config-key surfaces and pinned panel rebuild, private real-Pi/controlled-model adversarial tests, later authorized real-model autonomy evidence, and independent Verify. Identify any missing acceptance or implementation step that would make Apply unable to satisfy the design.

8. **Complexity discipline.** The user wants a reliable minimal MVP, not a general scheduler. Flag speculative mechanisms, unsupported new dependencies, excess state or configuration that is not needed by the raw requirements. Conversely, do not reject necessary persistence/identity/dedup merely because they add code; cite the behavior that requires them.

Finish with the smallest set of changes required before ACCEPTED, or an explicit acceptance with bounded conditions that Apply/Verify must satisfy. Do not mark proposal tasks complete and do not implement fixes yourself.

## Checks and handoff

Run and record actual output in a clean checkout of the candidate:

```bash
openspec status --change agent-self-reminder --json
openspec validate agent-self-reminder --strict
openspec validate --all --strict
openspec instructions apply --change agent-self-reminder --json   # read-only
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
```

A disposable-copy trial archive may be checked if useful; do not archive the real change. No full gate or live team experiment. Any optional probe must be isolated and controlled-model only.

Commit the report with Conventional Commits + V112 + `Agent: dev3`, leave the branch clean, and notify PM of the verdict and blocking findings. PM will independently review and reconcile before any Apply brief.
