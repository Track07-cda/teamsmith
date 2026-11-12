## Why

A PM needs a durable, project-owned way to revisit work at a chosen time. The existing 15-minute patrol is too coarse, and an API call returning does not prove that Pi entered the reminder's run. The shared state, CLI, Standby migration and minimal direct delivery are now implemented; the PM-only tool and prompt-free recovery remain unfinished.

The user's latest decision supersedes the resource-limit decision in the previously accepted proposal: provide the minimal tool without Reminder quotas. This revision changes planning artifacts only; it does not alter the landed CLI, state, Standby or minimal delivery code. A non-author must review this revision and the PM must accept it before the next Apply is dispatched.

## What Changes

- Add one-shot PM Reminders, created and managed through `team remind` or a PM-only `team_remind` tool, using one durable project-state authority and full, untruncated message text.
- Add a lightweight due check to both existing Pulse shapes. It durably queues due IDs while Pulse runs; the existing PM inbox-watch sends them directly through Pi, without a Reminder Outbox or spool copy.
- Permit an eligible PM Reminder to recover or wake the PM during Standby. A positively observed Reminder message can clear only its provably bound Standby generation, once per batch; ordinary pending work remains suppressed until then. A newer generation whose ordering cannot be proven is preserved and reported, not silently cleared.
- Preserve ordinary Outbox and inbox-watch behavior, PM identity/continuity/start/capacity/quota guards, drafts, and existing `/team`'s no-tool contract. Introduce a prompt-free Reminder-only recovery handoff rather than running the normal PM startup prompt before the wake.
- Provide the minimal `team_remind` add/list/show/cancel tool without Reminder configuration keys or quotas: no creation-rate, active-count, message-byte, batch-size, batch-spacing or forced minimum-delay limits. Keep valid future time, complete nonempty UTF-8 text without NUL, active-key idempotency, monotone IDs and state consistency. Repeated scheduling uses the same key after observation releases it, allocating a new ID each time.
- Preserve bounded terminal-history retention, cancellation, unknown-outcome handling and honest tool-load/doctor evidence. Retention never evicts active/unknown records or their unspent rights and is not a creation quota. A missing cross-process lock facility blocks shared Standby/Reminder mutations visibly; see the dependency delta and migration plan.

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

The remaining implementation will reuse the landed shared state helper, CLI and watcher, add a PM-only extension, finish guarded prompt-free recovery and diagnostics, and update focused tests and operator documentation. Removing the landed batch-size and spacing checks belongs to a later authorized Apply, not this revision. No Reminder quota keys, config schema/template/reference entries or panel labels are planned; panel scheduler work and a pinned bundle rebuild remain relevant only where the remaining Pulse behavior requires them. The shared `flock` dependency and its migration/rollback semantics are unchanged. No scheduler daemon, new scheduler library, TUI visualization, Pi-internal change, canonical-spec edit or implementation is part of this revision.
