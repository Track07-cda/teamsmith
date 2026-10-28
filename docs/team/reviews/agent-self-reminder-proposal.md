# agent-self-reminder · Formal proposal review

Candidate: `f9edff1a6c90` (spec artifacts `751ad9bb`) · Status: **UNDER REVIEW — no Apply authorized**

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

No Apply brief, product implementation, live Reminder, merge, push or release has been authorized. V112 is the independent substantive proposal reviewer; its findings and the final PM verdict will be appended here.
