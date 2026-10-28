# V111 · Independent architecture review of the Self-Reminder exploration

task: V111
agent: dev3
phase: explore
category: verify
change: agent-self-reminder
deltas: -
branch: task/V111-self-reminder
deps: P385 exploration report commit 1465ca96b983e17b9b5201cb17f7ac18216e0e4c

## Purpose and verdict

You did not author P385. Give an independent adversarial architecture review before PM accepts an approach or allows a proposal. The user's raw v0.1 requirement is in `docs/team/threads/dev2.md` under the user/P385 entry; read it fully. Read the P385 report with `git show 1465ca96b983e17b9b5201cb17f7ac18216e0e4c:docs/team/reports/P385-dev2.md` (it is intentionally not merged into main). Inspect the actual source/specs/Pi docs for any claim you rely on.

Write only `docs/team/reports/V111-dev3.md`. Lead with **ACCEPT**, **NEEDS-CHANGES** or **REJECT-APPROACH**, then concrete findings with source/spec counterevidence. This is a report-only independent review within Explore, not the later proposal review or implementation verification. Do not create an OpenSpec change, specs, code, tests or configuration.

The explorer recommends a persistent reminder store, lightweight due scheduling in both pulse shapes, a Reminder-specific Outbox handoff, watcher changes, a separate PM-only tool extension, several delivery states and resource limits. It estimates 7–13 implementation days plus 2–3 independent-verification days. Treat that as a hypothesis to challenge, not the approved architecture.

## Questions to resolve independently

1. **Is Outbox actually necessary for every running-PM delivery, or does it duplicate the durable Reminder store and create a second status authority?** Compare at least:
   - the report's store → Outbox → watcher design;
   - a direct PM-only inbox-watch/tool extension reading the durable due store and using Pi `sendMessage`, with Pulse only handling stopped-PM recovery;
   - a hybrid that keeps reminders in the store until standby/watcher/PM readiness permits one existing Outbox handoff.
   Judge against all AC scenarios, existing message identity/journal semantics and the requirement to prefer existing mechanisms. A simpler design that preserves safety is stronger than faithfully elaborating the report. Do not choose by component count alone: identify the actual crash and recovery evidence each option needs.

2. **Standby linearization.** The report puts Reminder checks at every Outbox/watcher exit. Evaluate the simpler rule “due reminders stay in the store and are not enqueued while standby is on”, including the race where standby changes during enqueue/send. Determine the smallest correct guard and which existing generic paths truly need modification. Ordinary Outbox behavior must not change, `--now` must not force a Reminder into the input box, and an already Pi-accepted turn cannot be retroactively cancelled.

3. **Minimal state and exactly-once honesty.** Challenge whether `scheduled/due/queued/spooled/accepted/unknown` must all be persisted separately or can be derived from the store plus existing journal. Distinguish API return from model execution. Check the report's claims about baseline, freshness, `read/intent/sent/failed`, floor compaction and uncertain recovery against `team-inbox-watch.ts`. Any automatic resend must have positive evidence; unknown must not be presented as successful delivery.

4. **Timing without a second runtime.** Verify the console and headless pulse implementations. Can one existing pulse backend provide the 30-second due-enqueue target without high-frequency full patrol, overlapping ticks or a new daemon? Assess the report's proposed short-lived patrol/lightweight tick coordination and identify any simpler shape that still handles a long patrol. No live changes to this team's pulse.

5. **Tool/identity feasibility.** Check the separate PM-only extension recommendation against the existing `/team` no-tool contract, PM/worker injection, `ctx.cwd`/tmux identity, reload and doctor diagnosis. Identify any proposed check Pi cannot actually expose. Do not accept environment variables or owner arguments as authorization.

6. **MVP scope and limits.** Assess whether two configurable storage limits plus fixed minimum/rate/batch bounds are sufficient and minimally explainable, or whether the report is growing a quota/state framework. Check the four-surface config and panel implications. Worker/cron/TUI must remain future scope; the data shape merely must not prevent them.

7. **Acceptance and effort.** Find any AC that the recommended design cannot prove, especially PM restart, standby at every stage, busy/draft safety, repeated scans/crashes, self-follow-up reminders and cross-project isolation. Identify which claims need real Pi versus fake host evidence. Say whether the estimate/slicing is a consequence of real requirements or avoidable design breadth.

Finish with the smallest architecture you would allow into Propose, concrete changes required to P385, and any genuine user-level trade-off. Do not invent a parallel specification or restate all FR/AC text; cite IDs and evidence.

## Boundaries and acceptance

- Only versioned write: `docs/team/reports/V111-dev3.md`; scratch under `$HOME/.cache/V111/`.
- No implementation, spec/change artifacts, live PM/pulse/tmux experiments, installs, dependency changes, merges, pushes or releases.
- No full gate. Run and record:

```bash
openspec validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
git status --short
```

Commit with Conventional Commits + V111 + `Agent: dev3`, leave the branch clean, and notify PM of the verdict. PM will reconcile P385 and this review before deciding whether a Propose brief is warranted.

## Second round: final Standby semantics and automatic exit (2026-10-28)

The revised P385 candidate is **`0791c7f5c29e`**; read its report with `git show 0791c7f5c29e:docs/team/reports/P385-dev2.md`, especially §§9–11. Preserve your original NEEDS-CHANGES review and add a second-round verdict at the top and bottom of `docs/team/reports/V111-dev3.md`. Your previous session exceeds the model window, so this is a fresh same-task review using the branch/report on disk.

The user has now settled the product semantics in D204; do not reopen them as an A/B/C question:

- Standby may be entered immediately.
- PM-owned Reminders may wake PM during Standby, whether created by the PM Agent or the user through CLI.
- An actual Reminder wake automatically clears Standby and ordinary work may resume; due/queued/failed delivery without a wake does not clear it.
- A batch clears once, with Reminder ID/source audit. Worker reminders remain future scope.

Review whether P385 is now technically ready for Propose under those rules:

1. Check that the narrow Standby recovery exception is limited to due PM-owned Reminders and that ordinary pending work cannot wake until an actual Reminder wake clears Standby. Ordinary Outbox behavior must remain unchanged.
2. Challenge the proposed `agent run + custom message with exact Reminder ID` observation as the definition of “actual wake”. Use the recorded idle/busy/settled-abort probe evidence and Pi public events to determine what it proves and what it misses. It must not be presented as model completion or a universal exactly-once receipt.
3. Challenge the generation/compare-and-clear design for automatic Standby off: manual off, re-on before observation/off, batch handling, crash before/after observation, pending off and marker deletion, unknown session/identity, and cross-process Bash/Node locking. Identify any concrete counterexample that must be settled in Propose. Do not demand strict no-wake semantics the user has explicitly removed.
4. Reconcile the revised single-store/direct-watcher design with your original findings: no mandatory Outbox/spool copy, one authoritative resend record, bounded history/floor, tool identity/doctor limitations, and no second scheduler runtime. State whether any original blocker remains.
5. Give a focused verdict: **ACCEPT FOR PROPOSE**, **NEEDS-CHANGES**, or **REJECT-APPROACH**, with the exact remaining proposal questions and verification requirements. This is not an implementation approval or final spec review.

Only `docs/team/reports/V111-dev3.md` may change. Run the same light OpenSpec/spec-refs/ledger/diff checks; no live team experiment, product/spec/change writes, full gate, merge, push or release. Commit with V111 + `Agent: dev3` and notify PM.
