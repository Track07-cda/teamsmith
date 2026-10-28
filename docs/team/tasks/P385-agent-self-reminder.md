# P385 · Explore a minimal PM Agent Self-Reminder capability

task: P385
agent: dev2
phase: explore
category: analysis
change: agent-self-reminder
deltas: -
branch: task/P385-agent-self-reminder
deps: current main 9c5d24903e49e4edca360cf3d91e2128b0194ec5; pending P379–P384 branches are read-only context, not the implementation base

## Input and phase boundary

The user supplied **Teamsmith — Agent Self-Reminder 需求说明 v0.1**, P1, explicitly as requirements input rather than an approved technical design. The complete raw input is preserved in `docs/team/threads/dev2.md` under the user/P385 entry; a non-ledger backup is `$HOME/.cache/pm-skills-requests/agent-self-reminder-v0.1.md`. Read that input fully. Do not ask the user to restate it.

This is **Explore only**. Use the OpenSpec explore workflow and produce `docs/team/reports/P385-dev2.md`; do not create `openspec/changes/agent-self-reminder/`, delta specs, a proposal, product code, tests or configuration. PM will review the exploration and record an approach decision before a separate propose brief. You may hold context for that later propose task, but you will not implement your own proposal.

The requested MVP is PM-only, one-shot self-reminders with absolute/relative times, list/show/cancel, persistence/recovery, safe delivery and audit. Worker reminders, cron/recurrence, human notifications, a general workflow engine and a second runtime are not MVP scope. These are scope boundaries from the raw input, not a license to copy its FR/AC lists into reports or briefs. The eventual observable contract belongs in the later OpenSpec change.

## Current-state facts to check, not assumptions to inherit

- `openspec list` currently reports no active changes. Relevant existing capabilities include `watchdog`, `notify-and-inbox`, `delivery-guard`, `pm-lifecycle`, `extension-slash`, `memory-and-deps`, `boundary` and `verification`.
- `extension-slash` currently says that extension registers no model-callable tool. The requested `team_remind` therefore needs an explicit boundary decision: a separate PM-only injected extension versus modifying an existing contract. Do not silently add a tool to the existing `/team` extension.
- Existing Outbox/inbox-watch delivery has several distinct records and confirmation levels. “Queued”, “accepted by Pi”, and “the agent did the work” are not interchangeable; do not invent exactly-once semantics.
- Standby currently suppresses automatic wake/start behavior. Verify where Outbox drains and inbox-watch delivery sit relative to that check; a reminder-specific bypass is unacceptable.
- The current full patrol interval is not a 30-second timer. The requested target is bounded due detection/enqueue without making the full project patrol high-frequency or spending idle model tokens.
- P380/P381/P382/P384 are verified but unmerged candidates; P379 is accepted exploration only; P383 is still being finalized. Do not describe their branch changes as current-main behavior. In particular, inspect P381 only if needed to avoid conflicting with its notify fix, and mark it candidate-only.

## Reading and investigation

1. Read `AGENTS.md`, your thread (including the raw requirement), this brief, `docs/team/OWNERSHIP.md`, and `skills/teamsmith/references/openspec.md`. Use the generated explore prompt/skill if present; otherwise use the installed OpenSpec 1.8.0 `context`/`instructions` read-only. Do not run init, install, upgrade or reload anything.
2. Read the relevant capability specs before judging conflicts, especially `watchdog`, `notify-and-inbox`, `delivery-guard`, `pm-lifecycle` and `extension-slash`; follow into `memory-and-deps`, `boundary` or `verification` where the evidence requires it. Name exact existing requirements that a later proposal would need to ADD/MODIFY, not parallel copies.
3. Trace the real implementation: pulse/watch and PM start/resume, standby, `outbox.sh`/`cmd-outbox.sh`, `team-inbox-watch.ts`, `team-notify.ts`, PM/worker extension injection, project/seat identity resolution, runtime-state write/lock conventions and existing test harnesses. Provide a concise current-state flow from due-like pending work to PM model delivery.
4. Read the Pi extension documentation completely before drawing the tool interface: `$HOME/.bun/install/global/node_modules/@earendil-works/pi-coding-agent/docs/extensions.md` and the linked SDK/custom-tool material it relies on. Use the repository's actual installed Pi source only as supporting evidence. Do not guess tool registration, injection or confirmation APIs from memory.
5. Compare the requested behavior with existing mechanisms and, only if useful, inspect third-party scheduling approaches read-only. Do not adopt `pi-schedule-prompt` as a runtime dependency, install it, or let an in-memory extension timer become the durable store.

## Questions the report must resolve

These are investigation questions, not a second requirements list:

- **Timing:** recommend one minimal integration that meets the requested due-enqueue target while leaving the full patrol cadence unchanged. Compare using the existing pulse window/lightweight next-due scheduling against faster full patrol and a separate scheduler. Explain idle cost, restart behavior and why the recommendation is not another runtime.
- **Delivery and state:** map the existing message identity/dedup/delivery evidence onto reminder transitions. Show where a reminder store is needed, how it links to an Outbox/spool identity, and what happens at each crash/retry boundary. Distinguish durable enqueue, Pi acceptance and actual work; do not claim end-to-end exactly-once if the existing channel cannot prove it.
- **Standby/recovery:** determine the correct gate for due reminders during standby, how held/overdue reminders resume, and how PM stopped/restart quota/extension readiness interact. Address backlog bounds and uncertainty without blind repaste or duplicate model turns.
- **Tool and identity:** recommend the smallest PM-only tool/CLI shape sharing one store and CLI implementation. Resolve the current no-model-tool contract explicitly. Show how ordinary Pi sessions, workers and foreign projects are excluded by runtime identity rather than user-supplied owner/project arguments. Include doctor/load-missing diagnosis without a fake success tool call.
- **Persistence and future shape:** recommend a simple atomic/locked runtime layout and id/key/cancellation semantics. Account for CLI/tool/pulse concurrency and restart. Keep owner/task fields extensible for later workers without implementing worker scheduling now. Runtime state must not become ledger or Git content.
- **Limits and compatibility:** evaluate the requested minimum interval, count/content/rate/backlog bounds against the project's subtractive complexity discipline. Prefer a small number of explainable rules over a quota framework. If new config keys are genuinely needed, note this repository's four-surface contract (schema, config template, config reference, panel zh/en labels) and committed panel rebuild; do not create speculative knobs in this exploration.
- **Verification and effort:** map the user's AC-01…AC-12 to existing harnesses and real Pi/tmux integration evidence, identifying what can be fake-clock tested and what needs a real runtime. Reuse existing gate sections rather than building a second scheduler test framework. Give an implementation split, rough effort, regression risks and which facts remain unmeasured.

Finish with one recommended approach, its alternatives and trade-offs, and any genuine product-boundary decision that needs the user. Make reasonable technical choices yourself; do not turn the report into a checklist of questions the PM could answer from the code.

## Constraints

- Only versioned write: `docs/team/reports/P385-dev2.md`. Scratch/logs belong outside the repository under `$HOME/.cache/P385/` or the declared companion evidence directory.
- No code, tests, canonical specs, change artifacts, OpenSpec config, README, product docs, task/board/decision/review/ownership edits.
- No live PM/pulse/tmux experiments, session interruption, reminders actually delivered to this team, global installs, dependency changes, shared/remote writes, merge, push or release. Use existing evidence and read-only probes; if a runtime experiment is essential, explain the missing evidence instead of touching the live stack.
- Do not run the full gate or expensive smoke suite for this exploration. Do not implement the recommendation or start propose/apply.

## Acceptance and handoff

Run and record actual output for:

```bash
openspec validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
bash skills/teamsmith/tests/section-select.sh --paths docs/team/reports/P385-dev2.md
git diff --check
git status --short
```

Confirm `openspec list` still has no `agent-self-reminder` change and that the only task-authored file is the report. Commit with Conventional Commits + P385 + `Agent: dev2`, leave the branch clean, and notify PM with the recommendation and any true blocker. PM will judge the exploration; no proposal or implementation is authorized by this brief.

## PM/V111 rework: single-store design and isolated Pi API feasibility (2026-10-28)

PM review `docs/team/reviews/P385.md` is **REWORK REQUIRED**. Independent review V111 at `c341d96694fc` found blocking counterevidence; read it with `git show c341d96694fc:docs/team/reports/V111-dev3.md`. PM reproduced the central fact on installed Pi 1.4.0: `sendMessage` returns `void`, its internal `sendCustomMessage` is asynchronous, errors are caught separately, and delivery can be deferred during `agent_settled`. The original report's `sent = Pi accepted` and mandatory Outbox design are not accepted. **Do not start Propose.**

Preserve the original report and append a dated rework section. Your previous session exceeds the model window, so this is a fresh same-task recovery: use branch `task/P385-agent-self-reminder`, inspect its existing report and `$HOME/.cache/P385/` evidence, and continue without deleting or rewriting history. The only new versioned file change allowed is `docs/team/reports/P385-dev2.md`.

### Architecture corrections to work out

1. Withdraw “every Reminder must cross Outbox/spool” and `sent = accepted`. Evaluate as the leading hypothesis: Pulse's lightweight tick persists a due-to-queued transition and ordering in the **single Reminder store** even while PM is stopped; existing PM recovery remains the only recovery path; PM's inbox-watch reads that durable queue and uses Pi directly. Ordinary Outbox and its `--now` behavior remain unchanged. Compare this against any materially simpler alternative, but do not keep duplicate delivery/status authorities merely for symmetry.
2. Define one authoritative intent/unknown/positive-observation record per stable Reminder ID. Explain how it reuses watcher logic without letting store and journal independently decide resend. Cover floor compaction, long-held items, historical query/retention and atomic batch intent before any batched send. API-call return, custom-message observation, run start and completed work must have distinct names and evidence.
3. Resolve or honestly bound Standby races at enqueue, intent and Pi's asynchronous/deferred execution. A pre-call Standby check is insufficient by itself. Any cross-process serialization must use a project-stable lock path independent of caller `TMPDIR`; do not claim a Bash/Node lock interoperates without evidence. If Pi cannot expose a suitable boundary, give the exact interleaving and semantic alternatives rather than promising cancellation or exactly-once delivery.
4. Address V111's tool/diagnostic/history findings: no unregister API, exposure-hidden and per-call identity checks, doctor's inability to query another session's in-memory tools, and bounded terminal/audit history rather than only a cap on active reminders. Re-estimate implementation only after this simplification; do not invent a smaller number without evidence.

### Bounded isolated Pi API probe

Before calling the revised design feasible, run a small **scratch-only** probe against installed Pi 1.4.0 using an existing controlled/fake-model harness where possible. Keep all scripts, fixture sessions, logs and raw event traces under `$HOME/.cache/P385/probe/`. Do not install dependencies, spend external model tokens, modify Pi or teamsmith, or touch the live team/Pulse/Outbox. A fixture-owned private tmux/socket is allowed only inside the existing harness; never message another real team window.

The probe must answer with timestamped raw evidence:

- For `pi.sendMessage(..., { triggerTurn: true })`, what is the observed order of the API call returning, custom-message/session observation, `before_agent_start` with `messageType: custom`, and the controlled backend receiving a model request? Use a unique Reminder-like ID in `customType`/`details` and test whether public event data can correlate that exact ID.
- Run idle, genuinely busy, and a call made from `agent_settled`/deferred execution. Show which cases merely queue/defer and which actually start a run. `ctx.isIdle()` alone is not proof of acceptance.
- Use the controlled backend to make the post-message model request fail. Distinguish message acceptance/run start from model failure; record whether any public extension event exposes asynchronous send failure. A synchronous `try/catch` around a void call is not evidence.
- Determine whether `before_agent_start` or another documented public event provides a usable positive boundary for a Reminder ID, what it proves, and what remains unknowable if it never arrives. This probe does not authorize changing Standby or implementing a watcher; it supplies evidence for the report's design choice.

If a needed observation cannot be produced with the public API, record that limitation and the smallest real counterexample. Do not patch Pi internals to manufacture a success and do not turn the probe into a Reminder implementation.

### Revised report and acceptance

The appended report must lead with the revised recommendation, cite probe raw logs/commands and V111 findings, state exactly which Standby/delivery guarantees are now proven or still open, and give a PM decision: ready for Propose, or blocked on a genuine user/Pi semantic boundary. Preserve AC-01…AC-12 coverage and the no-second-runtime/no-high-frequency-full-patrol constraints. If a user trade-off is necessary, present concrete alternatives with a recommendation; otherwise do not manufacture a question.

Run from the final report candidate and record actual output:

```bash
openspec validate --all --strict
openspec list   # still no agent-self-reminder change
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
bash skills/teamsmith/tests/section-select.sh --paths docs/team/reports/P385-dev2.md
git diff --check
git status --short
```

Confirm the only versioned task-authored change remains the P385 report. Commit with Conventional Commits + P385 + `Agent: dev2`, leave the branch clean, and notify PM with the revised recommendation and probe evidence. PM and independent review must close the rework before any Propose brief; implementation remains unauthorized.

## Final user Standby ruling: PM-owned Reminders are exempt (2026-10-28)

The user has now explicitly superseded the original FR-06 restriction and the unresolved A/B/C framing: **Standby may be entered immediately, and a Reminder owned by PM is allowed to wake PM during Standby. This applies both when the PM Agent created it through the tool and when the user created it through the CLI.** Other ordinary patrol/notification wake-ups remain suppressed. D204 records the authoritative decision; the earlier tentative B selection is not the final contract.

Concrete acceptance example: PM enters Standby at 17:00; a PM-owned Reminder due at 18:00 is still eligible for controlled recovery/delivery and may wake PM at 18:00. It need not wait for Standby off. There is no special “only already in-flight” exception. Record creator/source (`pm` or `user`) for audit, while authorization/ownership remains PM; Worker reminders remain out of MVP scope.

Append a short final report section (preserve all earlier exploration and probe evidence) that:

1. Adopts this Reminder exemption, withdraws the need for the user to choose A/B/C, and revises the former Standby analysis/AC-06 accordingly. Do not keep recommending strict Standby gating for Reminders.
2. Keeps the single Reminder store/direct-watcher recommendation and all delivery/evidence/idempotency findings. The Pi asynchronous race is no longer a permission conflict for Reminders, because their wake is allowed during Standby; do not claim it proves exactly-once or model completion.
3. Keeps ordinary Standby and PM recovery rules unchanged for non-Reminder work. Delivery still obeys existing identity, safe-start/recovery and resource constraints; no arbitrary other-agent target or human notification is added.
4. States whether the exploration is now ready for focused V111 re-review and a subsequent OpenSpec Propose. No new probe is needed for this semantic ruling.

This remains a report-only task. Run the existing light acceptance checks, commit only `docs/team/reports/P385-dev2.md` with P385 + `Agent: dev2`, and notify PM. No implementation/change/spec writes, merge, push or release.
