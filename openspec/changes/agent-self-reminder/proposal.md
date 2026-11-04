## Why

A PM can decide to revisit a task but currently has no durable, project-owned way to wake itself at a chosen time. The existing 15-minute patrol is too coarse, and an API call returning does not prove that Pi entered the reminder's run.

## What Changes

- Add one-shot PM Reminders, created and managed through `team remind` or a PM-only `team_remind` tool, using one durable project-state authority and full, untruncated message text.
- Add a lightweight due check to both existing Pulse shapes. It durably queues due IDs while Pulse runs; the existing PM inbox-watch sends them directly through Pi, without a Reminder Outbox or spool copy.
- Permit an eligible PM Reminder to recover or wake the PM during Standby. A positively observed Reminder message can clear only its provably bound Standby generation, once per batch; ordinary pending work remains suppressed until then. A newer generation whose ordering cannot be proven is preserved and reported, not silently cleared.
- Preserve ordinary Outbox and inbox-watch behavior, PM identity/continuity/start/capacity/quota guards, drafts, and existing `/team`'s no-tool contract. Introduce a prompt-free Reminder-only recovery handoff rather than running the normal PM startup prompt before the wake.
- Provide explicit state, bounded retention, cancellation and unknown-outcome semantics, two configurable resource limits, and honest tool-load/doctor evidence. A missing cross-process lock facility blocks the new shared Standby/Reminder mutations visibly; see the dependency delta and migration plan.

## Capabilities

### New Capabilities

- `agent-self-reminder`: PM one-shot creation, due queue, correlated delivery, lifecycle, retention, identity and diagnostics.

### Modified Capabilities

- `watchdog`: the narrow Reminder exception to Standby, lightweight Pulse scheduling and generation-safe automatic exit.
- `notify-and-inbox`: ordinary spool/journal semantics remain unchanged; Reminder's direct watcher delivery has its own single authority and Pi observation.
- `delivery-guard`: ordinary immutable Outbox entries remain separate from the direct Reminder path.
- `pm-lifecycle`: guarded, prompt-free Reminder-only recovery and starting-state behavior.
- `memory-and-deps`: diagnose the OS lock needed by the shared Standby/Reminder transaction instead of silently writing without it.
- `verification`: verify Reminder wake with a real Pi and a controlled model, separately from real-model autonomy evidence.

## Impact

The later implementation will affect `skills/teamsmith/scripts/lib/{common,cmd-watch,cmd-config}.sh`, the CLI command registration, the Pulse panel scheduler and pinned bundle, `extension/team-inbox-watch.ts`, a new PM-only extension and shared state helper, config template/reference/panel labels, doctor, and focused tests. The new OS advisory-lock requirement is `flock` for serialized Standby/Reminder mutations; it is already used elsewhere in this project but is not currently a universal hard dependency. No scheduler daemon, new scheduler library, TUI visualization, Pi-internal change, canonical-spec edit or implementation is part of this proposal.
