# agent-self-reminder · Formal proposal review

Candidate: `f9edff1a6c90` (spec artifacts `751ad9bb`) · verdict: **ACCEPTED**

PM has read the complete proposal, design, tasks and all seven delta specs. This file is the formal review checkpoint; the final ACCEPTED/REWORK verdict will be recorded after independent V112 is reconciled.

## Independently reproduced hygiene

In clean clone `$HOME/.cache/pm-skills-reviews/P387-f9edff1a/candidate`, PM ran:

- `openspec status --change agent-self-reminder --json`: planning artifacts complete;
- `openspec validate agent-self-reminder --strict`: valid;
- `openspec validate --all --strict`: 20/20;
- `openspec instructions apply --change agent-self-reminder --json`: 18 tasks, all incomplete (read-only);
- `spec-refs.sh --check`, real-names `ledger-ban.sh`, and `git diff --check`: pass;
- disposable-copy `openspec archive agent-self-reminder --yes` followed by all-spec validation: 20/20; real candidate change remains present and checkout clean.

Logs: `$HOME/.cache/pm-skills-reviews/P387-f9edff1a/static-checks.log` and `trial-archive.log`. These prove structural/merge hygiene, not product correctness.

## Product/spec review checklist

- D204 is represented explicitly: PM-owned Reminders from PM tool or CLI may wake during Standby; actual correlated wake can clear a bound generation once; ordinary work stays suppressed until then.
- Single durable store/direct watcher replaces mandatory Outbox/spool; ordinary Outbox and `/team` contracts remain separate.
- Pi API return, run-entry observation, model request and work completion are distinguished; unknown does not authorize blind resend.
- Prompt-free stopped-PM recovery, both Pulse shapes, full text, bounded retention, two config keys plus fixed rate/batch rules, tool identity/doctor evidence, and real-Pi versus real-model verification are all present in design/tasks.
- Existing modified requirements retain their original scenarios while adding the Reminder exception. Trial archive validates the combined 20-capability state.

## Substantive questions being reconciled with V112

1. **Disclosed generation ambiguity:** design §3 preserves a newer G2 when public observations cannot order intent→G2→Pi event. An actual wake in that hidden ordering may therefore not auto-exit. This is explicit and narrower than making all wakes unknown, but the final review must judge whether the boundary is acceptable under D204 and sufficiently testable.
2. **Compatibility cost:** design §1 and `memory-and-deps` require `flock` for all Standby mutations after upgrade, even without Reminders. This is disclosed with migration/doctor/rollback and no unlocked fallback; it is not “zero dependency change”. The final verdict must weigh it against the existing supported environments and the need for one Bash/Node transaction order.
3. **Busy-PM availability:** design §2 allows one outstanding batch and marks it unknown after 60 seconds without observation; subsequent batches wait for observation or explicit unknown acknowledgment. A busy follow-up may later strengthen unknown to observed. The review must decide whether this conservative serialization is acceptable MVP backpressure or creates unnecessary manual blockage under normal long-running PM turns. It must not be hidden by the structural green.
4. **Migration breadth:** all Standby readers/writers move into one versioned snapshot with a canonical state-root locator and quiesced old-writer migration. The review must confirm this is the minimum necessary shared authority and that legacy reason/state, mixed writers, state overrides and rollback are covered without breaking no-Reminder projects.

## Final PM verdict — ACCEPTED for local Apply

V112's independent substantive review at `c3eb9e8bcde1` is **ACCEPT**, with no blocking findings. PM reconciles it with the complete read-through and independently reproduced checks above and formally accepts this exact proposal.

The accepted boundaries are explicit and must survive implementation and verification:

1. A newer G2 whose order relative to the Pi event cannot be proven is preserved and reported; an actual wake in that hidden ordering may not auto-exit. Normal bound G1 and G2-before-intent must still exit correctly.
2. After migration, a host without usable `flock` cannot perform Standby mutation, even without Reminders. This is a disclosed compatibility cost, with doctor/migration/rollback and no unlocked fallback.
3. One outstanding unknown batch is deliberate backpressure: later batches wait for a late valid observation or explicit whole-batch acknowledgment. It is not silent loss or a claim of guaranteed delivery, and must be covered under long busy turns.
4. Shared Standby/Reminder state, canonical locator, prompt-free recovery and lightweight Pulse are accepted as necessary to make observation/off/audit atomic and prevent ordinary backlog bypass. They are not license for a second runtime or general scheduler.

V112's nonblocking C1 clarification will be applied in P388: when no self-Reminders are present the feature adds no model turn, and lightweight checks do not increase full-patrol frequency; the necessary Reminder wake itself is not prohibited.

P388 may implement this proposal on a local task branch based on `f9edff1a6c90`, with a different author and subsequent independent verification. This verdict does **not** authorize protected-branch merge/push, live-team state migration/restart, real-model autonomy calls, archive or release. Those retain their separate gates.
