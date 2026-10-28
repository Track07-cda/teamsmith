# P388 · Implement the accepted PM Agent Self-Reminder MVP

task: P388
agent: dev-bob
phase: apply
category: analysis
change: agent-self-reminder
deltas: agent-self-reminder, watchdog, notify-and-inbox, delivery-guard, pm-lifecycle, memory-and-deps, verification
branch: task/P388-agent-self-reminder-mvp
deps: exact accepted proposal/report tip f9edff1a6c90c755a147089a3be4cc008baa9b2a; D204–D206; formal proposal review ACCEPTED and V112 ACCEPT

## Start and scope

You are the implementation owner, not the proposal author or independent verifier. Work in your own seat/worktree on `task/P388-agent-self-reminder-mvp`, initially based on **the exact proposal tip `f9edff1a6c90`** so the accepted change artifacts are present. Read `AGENTS.md`, your thread, this brief, OWNERSHIP, `references/openspec.md`, the complete change proposal/design/tasks/deltas, `docs/team/reviews/agent-self-reminder-proposal.md`, and V112's report (`git show c3eb9e8bcde1:docs/team/reports/V112-dev3.md`). Use `openspec instructions apply --change agent-self-reminder --json` as the work plan.

Implement the accepted MVP, not a general scheduler. The proposal's 18 tasks are the checklist; your scope is the implementation and author-owned test evidence behind 1.1–4.4 and the controlled-integration portions of 5.1–5.3. Do **not** mark independent verification or authorized real-model autonomy as done. P388 is not the independent Verify phase and must not archive the change.

Make small, reviewable commits per verified step (Conventional Commits + P388 + `Agent: dev-bob`), keep the branch clean at delivery, and write `docs/team/reports/P388-dev-bob.md`. A fresh same-task recovery must be able to continue from the branch/report/evidence alone.

## Accepted behavior that must not be weakened

1. One durable project-scoped Reminder/Standby authority; PM-owned one-shot reminders from the verified PM tool or CLI; full text, stable IDs/keys, explicit cancellation/unknown/history and no second Outbox/spool or resend authority.
2. Lightweight due admission in both existing Pulse shapes, no second daemon or high-frequency full patrol, guarded prompt-free PM recovery, and ordinary backlog suppression until an actual correlated Reminder wake permits ordinary work to resume.
3. D204: Reminders may wake during Standby; actual ID-correlated wake clears only its provably bound current generation once per batch. Due/queued/intent/API return/failure is not a wake. Duplicate/late events cannot clear a newer generation.
4. Preserve the disclosed conservative boundary: if intent→G2→Pi ordering cannot be proven, preserve G2 and report ambiguity; do not claim unconditional auto-off. Normal G1 and G2-before-intent must work.
5. `sendMessage` return is not Pi acceptance/model start/completion. Persist whole-batch intent before the call; no blind resend after intent/unknown. Explicit whole-batch `resolve --ack-unknown` burns the right without asserting delivery.
6. Keep ordinary Outbox, `/team`, worker startup, dispatch/notify/review and non-Reminder behavior compatible, except the explicitly accepted `flock` dependency for Standby mutations. No unlocked fallback when locking/fsync/identity fails.
7. No Worker reminders, cron/recurrence, arbitrary recipients, human notifications, general workflow engine, Pi-internal patch, third-party scheduler dependency or new TUI visualization.

If implementation reveals a substantive contradiction with the accepted design, stop that path and write `BLOCKED:` with a concrete counterexample; do not silently rewrite the contract. Only the nonblocking C1 wording clarification is pre-approved: when no self-Reminders are present the feature adds no model turn, and lightweight checks do not increase full-patrol frequency; the necessary Reminder wake is allowed.

## Implementation write set

Only paths required by the accepted proposal/tasks:

- `openspec/changes/agent-self-reminder/**`: C1 wording and evidence-backed task checkoffs/report references; never edit canonical specs directly and do not mark unperformed independent/real-model verification complete.
- `skills/teamsmith/scripts/lib/{common,cmd-watch,cmd-config}.sh`, the CLI registration and a small new reminder command/state helper as justified by the design.
- `skills/teamsmith/extension/team-inbox-watch.ts` and a new PM-only reminder extension/shared helper; no tool addition to `/team` and no worker injection.
- `skills/teamsmith/scripts/panel/src/**` only for lightweight scheduling and the two config labels; rebuild `scripts/panel/panel.js` with the pinned toolchain whenever panel sources change.
- `skills/teamsmith/templates/config.sh.tmpl`, `skills/teamsmith/references/{config,workflows,memory}.md` and minimal operator/dependency documentation required by the proposal.
- Existing/new behavioral fixtures under `skills/teamsmith/tests/**` and `skills/teamsmith/tests/smoke.sh` only for the accepted behavior and regression mapping; product code must not carry test-only scaffolding.
- `docs/team/reports/P388-dev-bob.md` and host-side evidence outside Git.

Do not modify unrelated tasks/reviews/board/decisions/ownership, other changes, release files, CI schedules, or pending P379–P386 work. Do not merge, push, retry public CI or publish.

## Required engineering evidence

1. **Authority and migration:** production-helper Bash/Node contention with different `TMPDIR`, last-lock-owner death, canonical state-root mismatch, atomic rename/fsync/failure injection, corrupt/torn/unsupported state, legacy Standby reason import, no old/new mixed writers and rollback export. No live-team migration: use isolated projects/state roots.
2. **API/lifecycle:** strict times, complete UTF-8, concurrent/idempotent keys, limits/clock backward, cancel versus intent, ordered admission, retention/high-water/pruned IDs, explicit unknown resolution and no key/ID resurrection. Both config keys must cover schema, template, reference and zh/en panel labels; validate their actual runtime parsing.
3. **Pi delivery/wake:** private tmux + real Pi + controlled model, exact project/PM/session/batch/nonce/member matching, full content/details, idle and busy follow-up, draft preservation, no input typing, no blind resend and late observation. Show the actual model-visible request where controlled evidence claims it.
4. **Standby races:** pause a real earlier extension handler across G1/off/on G2 before and after event emission; test normal bound G1, G2-before-intent, ambiguous preservation, manual off/re-on, A+B duplicate/late events, whole-batch resolve and restart. Observation/off/audit must commit atomically through the production helper. No lock may wait on Pi/model.
5. **Recovery and Pulse:** running/busy/stopped/starting PM, ordinary digest/inbox backlog and journal recovery present, separately authorized Outbox preserved, no generic `@pm-prompt` or ordinary nudge before actual wake, all identity/capacity/quota/unsupported-adapter refusals. Test both Pulse shapes with a long patrol, due-during-patrol, coalesced recheck, no overlap and healthy 30-second durable enqueue; do not assert model latency as a timing guarantee.
6. **Tool/identity:** PM-only registration, hidden/refused on invalid or switched identity, reload/no-unregister behavior, per-call checks, foreign project/worker/ordinary Pi isolation, and doctor's honest not-running/unknown/explicit-failure/fresh-evidence distinctions.
7. **Compatibility:** no-Reminder project has no extra model turn or higher-frequency full patrol; ordinary Outbox `--now`, dispatch/notify/review/Standby and `/team` retain behavior. C1 must make that wording direct.

Use controlled providers and isolated real Pi for protocol tests. **Do not use real model credentials or call a real model in this task.** AC-02/09 autonomous behavior remains separately authorized later; scripted/controlled calls are not autonomy proof and must be marked not run. Do not experiment on this live team, its PM/Pulse/tmux windows or real state.

## Gates and delivery

Run focused behavioral tests as you implement, not the full suite after every commit. On the final frozen tree:

```bash
openspec validate agent-self-reminder --strict
openspec validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
```

Run the accepted controlled-integration and relevant existing smoke selections with exact commands/output, then run the full `bash skills/teamsmith/tests/smoke.sh` once on the settled tree as the delivery gate, in the background with complete host-side logs and an unchanged tree throughout. If panel source changed, first run `bun install --frozen-lockfile && bash build.sh` in `skills/teamsmith/scripts/panel` and prove the committed bundle reproduces. Any red, timeout or unrun required scenario must be reported honestly and fixed or returned as BLOCKED; never convert it to SKIP/pass or delete coverage to make the gate green.

The report leads with what is implemented and what remains unverified. Include exact commits, affected files, commands/counts, controlled Pi/runtime identities, race/fault evidence, full-gate fingerprint/result, config/panel surfaces, and explicit not-run real-model/protected-migration/public-CI boundaries. Notify PM only after the final tree/report are committed and clean. A different agent will independently Verify; no merge, push, real archive or release.
