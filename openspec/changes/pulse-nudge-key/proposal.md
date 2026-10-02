## Why

With a 3600-second reminder gap, count changes still wake the PM on successive 900-second patrol ticks. The current key hashes the pending **count vector**, not the reminder text; an observed empty tick also fails to rearm the same returning category.

**Flip:** the isolated baseline reports `FAIL F1-count-only actual=2/100900 expected=1/100000` and `FAIL F2-empty-return actual=1 expected=2`. After apply, both must pass; category changes must still wake immediately. This proposal contains no implementation or claimed post-fix green.

## What Changes

- Identify a running PM's reminder batch by the stable set of positive pending categories, excluding their counts and descriptive text.
- Rate-limit count-only changes; do not move the last-reminder time on suppressed ticks.
- Remind immediately when the category set changes (addition or removal); an observed empty tick rearms the next nonempty batch, including emptiness observed under standby.
- Keep current counts in reminders, logs and the read-only panel. Keep standby, no-work silence, PM startup, delivery guard and restart quota behavior.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `watchdog`: clarify “same batch” in the existing rate-limit requirement, retain its baseline scenarios, and specify category transitions and empty rearming.
- `panel`: extend the existing status-band requirement with current-count visibility independent of reminder suppression; retain both baseline scenarios verbatim.

## Impact

Apply is one developer-owned slice, followed by independent verification. Expected implementation surface: `skills/teamsmith/scripts/lib/common.sh`, `skills/teamsmith/scripts/lib/cmd-watch.sh`, focused fixtures under `skills/teamsmith/tests/**`, and the existing gap documentation in `skills/teamsmith/references/config.md` if needed. No new setting or runtime dependency; the default remains 900, and configured/legacy gaps remain effective. The wake key is not a public JSON field.

**Boundaries:** propose edits only this change and P172's report/evidence. Apply must not change `.pi/**`, `AGENTS.md`, task/board/review records, main capability specs, other changes, PM liveness/start/quota logic, meeting/death notifications, delivery/outbox semantics, panel TSX/bundle or other repositories. No shared tmux socket, production patrol manipulation or model call. Existing overlapping `meeting-liveness` deltas remain untouched.

### Acceptance commands

Run from the task worktree:

```bash
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
bash docs/team/reports/P172-verify/pkg/check-baseline.sh
bash docs/team/reports/P172-verify/pkg/run.sh --expect-current-red
bash docs/team/reports/P172-verify/pkg/run.sh --mutations
bash docs/team/reports/P172-verify/pkg/gate.sh
```

After apply, replace the baseline-red command with:

```bash
bash docs/team/reports/P172-verify/pkg/run.sh --assert-fixed
```

### Required evidence

The report must include real commands, exit codes and output tails; source line references correcting the key hypothesis; baseline-scenario comparisons; both pre-fix failures; mutation failures for immediate category wakes and panel count visibility; post-fix output only after apply; and isolated gate logs. A probe stubs external runtime boundaries and is not proof of live PM delivery.
