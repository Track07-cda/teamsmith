# P387 · Propose the PM Agent Self-Reminder MVP

task: P387
agent: dev2
phase: propose
category: analysis
change: agent-self-reminder
deltas: agent-self-reminder, watchdog, notify-and-inbox, delivery-guard, pm-lifecycle, memory-and-deps, verification
branch: task/P387-agent-self-reminder-openspec
deps: accepted exploration P385 0791c7f5c29e; independent V111 second-round ACCEPT FOR PROPOSE 543b447a642d; user semantics D204

## Phase boundary and inputs

You explored this capability and now hold the **planning-only Propose** phase. You will not implement this proposal. PM accepted the exploration only after V111's independent second-round review. Read:

- `AGENTS.md`, your thread (including the raw v0.1 requirement and subsequent user rulings), this brief and `docs/team/OWNERSHIP.md`;
- `skills/teamsmith/references/openspec.md` and the generated propose workflow;
- final exploration `git show 0791c7f5c29e:docs/team/reports/P385-dev2.md`;
- independent review `git show 543b447a642d:docs/team/reports/V111-dev3.md`, especially second-round §5.2–5.3;
- `docs/team/reviews/P385.md`, `docs/team/reviews/V111.md`, D204/D205, and every existing capability spec you delta.

Write only `openspec/changes/agent-self-reminder/{proposal.md,design.md,tasks.md}`, the declared delta specs under that change, and `docs/team/reports/P387-dev2.md`. Do not edit canonical specs, product code, tests, configuration, README, live state or another change. Do not create implementation branches/tasks, merge, push or release. PM will run a formal proposal review; `docs/team/reviews/agent-self-reminder-proposal.md` must be ACCEPTED before any Apply brief exists.

## Settled product direction — do not reopen

1. MVP is one-shot reminders owned by **PM**, created either by the PM Agent through a structured tool or by the user through `team remind` CLI. Record creator/source for audit. Workers, arbitrary recipients, cron/recurrence, human desktop/mail notifications and a general workflow engine are not MVP.
2. D204 is authoritative: Standby may be entered immediately; PM-owned Reminders may wake PM during Standby. An **actual Reminder wake automatically clears Standby**, after which ordinary work resumes. Due/queued/intent/API return/failed delivery without a wake does not clear it. A batch clears once, with Reminder ID/source/batch audit. This supersedes raw FR-06; do not resurrect A/B/C or require Standby to wait for Pi/model completion.
3. Leading architecture: a single durable project-scoped Reminder store; lightweight due detection/queueing in the existing Pulse runtime; PM's existing inbox-watch/tool extension delivers directly through Pi. No mandatory Outbox/spool copy, no second scheduler daemon, no high-frequency full patrol, no in-memory-only timer and no third-party scheduler runtime dependency. Ordinary Outbox, `/team`, dispatch/notify/review and non-Reminder Standby behavior remain compatible.
4. `sendMessage` returning is not acceptance, model start or work completion. The controlled Pi probe and V111's evidence remain binding. Do not promise end-to-end exactly-once; unknown outcomes must not be blindly resent.

## What the proposal must decide concretely

This is not a restatement of the exploration or a list of open questions. Choose the smallest coherent design and specify it in `design.md` + delta scenarios.

### A. Store, API and lifecycle

Define the versioned record, stable ID/key semantics, absolute/relative time parsing, state transitions, cancellation results, ordering, atomic writes/locking, crash recovery, bounded history/audit and the one authoritative delivery/resend record. CLI and tool must share one implementation/store and derive owner/project from verified runtime context, not caller-supplied identity. Preserve complete message text; reject limits explicitly rather than truncating.

Distinguish scheduled/due/queued/intent/observed/unknown/held/cancelled or a smaller equivalent model. Show which states are durable facts versus derived views. Address batch intent before send, floor/retention and late events; two journals must not independently authorize resend.

### B. Standby wake and automatic exit — close V111's counterexamples

Specify a linearization/order that handles G1 → wake observation → G2 and G2 → wake observation correctly. Reading the current generation only when the event callback runs is explicitly insufficient. Evaluate the simpler direction of **binding the Standby generation in the durable pre-send intent**, then using that bound generation at the observed wake, rather than sampling it later; if another mechanism is chosen, prove it against the same interleavings.

Define batch membership and one durable automatic-off right across messages/restarts, manual off/re-on, repeated/late events, crash before/after observation/off/audit, and unknown identity. Ordinary success must not be unnecessarily degraded to unknown, but an unprovable order must conservatively preserve the newer Standby state and show why. Locks must be at a canonical project-state path shared by Bash/Node regardless of `TMPDIR`, cover every production writer, and protect only short state transactions — never wait on Pi/model while holding them. Do not claim Bash/Node lock interoperability without a concrete feasible protocol.

Define the exact public Pi observation used as “actual wake” (for example an ID-correlated message entering the PM's run) and its limits. It is not model completion. Explain idle, busy/follow-up and deferred cases; unrelated existing runs must not count.

### C. Recovery without ordinary-work bypass

Show how a stopped PM is recovered only because an eligible Reminder exists, while identity/starting/continuity/capacity/quota remain enforced. The existing Standby early return cannot simply be removed. Ordinary pending digest/inbox must not nudge/start PM before the actual Reminder wake. Address the current generic `@pm-prompt` startup path explicitly: if it would perform ordinary first moves before Reminder delivery, propose a concrete reminder-only recovery/handoff that prevents that, rather than assuming existing startup is safe.

After the observed wake and generation-checked Standby off, ordinary work resumes by existing rules. No wake means no automatic off and no ordinary-work bypass. Preserve ordinary Outbox's separately authorized behavior; do not conflate it with patrol pending work.

### D. Timing, tool loading and minimal resource bounds

Specify lightweight scheduling for both console and headless Pulse shapes, including a due Reminder arriving during a long patrol, non-overlap, merged recheck and shutdown. The 30-second target is durable enqueue under stated normal conditions, not model start/completion or operation with Pulse stopped. No Reminder means no extra model token or high-frequency full scan.

Choose a PM-only tool injection/loading design and per-call identity/exposure checks. Account for Pi having no unregister API, `exposure: hidden`, reload and doctor's inability to query another process's in-memory tools directly. Doctor evidence must distinguish not running, stale/missing evidence and explicit load failure.

Use the requested small set of limits (configurable active/message-size bounds plus explainable minimum/create/delivery/batch rules) without building a quota framework. Cover total terminal history/audit growth and explicit retention behavior. If new config keys are chosen, tasks must include all four existing contract surfaces — schema, template, config reference and panel zh/en labels — plus the pinned panel bundle rebuild. Do not add new TUI visualization in MVP.

## Delta and acceptance planning

Create the new `agent-self-reminder` capability and only justified MODIFIED deltas for existing capabilities. In particular cover the actual changes to watchdog/Standby, notify/inbox delivery evidence, PM recovery and verification; `extension-slash` currently scopes its no-tool rule to `/team`, so do not modify it merely to say a separate extension exists. Do not copy FR/AC lists into a parallel spec: write observable ADDED/MODIFIED requirements and WHEN/THEN scenarios.

`tasks.md` must map the original AC-01…AC-12 with D204's revised AC-06, V111's counterexamples and failure injection to small implementation slices. Include real Pi/private-tmux controlled-model tests for protocol boundaries, and distinguish those from the later real-model autonomous-create/re-follow-up checks that need the appropriate environment authorization. A scripted tool call must not be presented as a model choosing autonomously. Include compatibility with no-Reminder projects, identity isolation, drafts/busy turns, cancellation, restart/floor, both Pulse shapes and full-text/no-blind-resend behavior.

Give concrete implementation ordering, affected files and independent-verification handoffs. Do not create Apply tasks now. The proposal must be implementable without changing Pi internals; if a necessary public capability is still unproven, use only a scratch-controlled probe and report the blocker rather than hiding it in tasks.

## Acceptance and delivery

Use the installed OpenSpec 1.8.0 and project-generated propose workflow. Before delivery run and record actual output for:

```bash
openspec status agent-self-reminder --json
openspec validate agent-self-reminder --strict
openspec validate --all --strict
openspec instructions apply --change agent-self-reminder --json   # planning review only; do not apply
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
```

Also perform a trial archive in a disposable copy outside the repository and validate the resulting all-spec state; do not archive the real change. Confirm the write set is only the change artifacts and P387 report. No full gate or live team experiment.

The report leads with the chosen architecture, exact artifact paths, how each V111 second-round blocker is resolved, validation results and remaining evidence boundaries. Commit with Conventional Commits + P387 + `Agent: dev2`, leave the branch clean, and notify PM for formal proposal review. No implementation is authorized by this brief.
