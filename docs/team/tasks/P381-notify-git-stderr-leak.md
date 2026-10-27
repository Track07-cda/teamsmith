# P381 · Do not let git probe stderr become a Pi draft

task: P381
agent: dev-bob
phase: apply
category: code
change: -
specs: notify-and-inbox#A turn-end notification appends one inbox line and knocks once
anchor: none (infra) — product defect exposed by the latest-Pi runtime verification
deltas: -
branch: task/P381-notify-git-stderr-leak

## Evidence

P380's real Pi 1.4.0 delivery-truth run found that a task branch without an upstream cannot receive the second `say`: the editor stays `BUSY`, `second_received=0`. The cause is `skills/teamsmith/extension/team-notify.ts` `run()`:

```ts
return execFileSync(cmd, args, { cwd, encoding: 'utf8', timeout: 5000 }).trim()
```

The upstream probe at line ~520 runs `git rev-parse --abbrev-ref --symbolic-full-name @{upstream}`. With no upstream, git's fatal error inherits the parent stderr (the pane). Pi 1.4.0 leaves that line inside the input-box rectangle, so `team_input_box_text` sees a draft and the delivery guard queues instead of writing. The same product code on 0.99.2 passes; P380's A/B/C evidence is in `docs/team/reports/P380-dev3.md` §7 and the finding section.

## Required fix

Use explicit stdio for the helper's `execFileSync` calls so a child process's stderr never leaks into the agent pane: `stdio: ['ignore', 'pipe', 'pipe']`. Keep the existing behavior of using stdout and returning an empty value on failure; do not suppress the actual delivery-guard diagnostics or change the upstream/unpushed logic.

This is a product fix, not a test-only workaround. Do not use `P163_BRANCH_UPSTREAM=1` to hide the default no-upstream case.

## Acceptance evidence

1. Minimal reproduction on a branch without upstream: before the fix, the helper prints git's fatal error to the parent stderr; after the fix, parent stderr is empty while the helper still returns the same value.
2. A real Pi 1.4.0 delivery-truth default case with no upstream now receives the second say (or, if the candidate P380 runtime change is not merged yet, use P380's evidence runner to run the candidate product against its fixture). Record the actual Pi version and `second_received` result.
3. Add or update one behavioral assertion in the existing notify/delivery test surface that fails on the old implementation for the leaked stderr and passes on the fix. No new test framework.
4. Run affected notify/delivery sections only, plus `bash -n` where applicable, `section-select.sh --check`, ledger ban and `git diff --check`. No full gate.

Report `docs/team/reports/P381-dev-bob.md`. Do not merge, push or publish. Independent verification follows separately.
