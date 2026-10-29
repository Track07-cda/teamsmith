# P393 · Implement watch-first, immediate-by-default `team say`

task: P393
agent: dev
phase: apply
category: analysis
change: say-immediate-default
deltas: delivery-guard, notify-and-inbox, help-surface
branch: task/P393-team-say
deps: exact accepted proposal/report tip eb8250a261027ddb570a29478b08ca3a9db4059c; D207/D209/D210; formal proposal review ACCEPTED and V114 ACCEPT

## Start and scope

You are the implementation owner, not the explorer/proposer or independent reviewer. Work in your own seat/worktree on `task/P393-team-say`, based initially on **exact proposal tip `eb8250a261027ddb570a29478b08ca3a9db4059c`** so the accepted change artifacts are present. Read `AGENTS.md`, your thread, this brief, OWNERSHIP, `references/openspec.md`, the complete proposal/design/tasks/deltas, `docs/team/reviews/say-immediate-default-proposal.md`, and V114's report (`git show 6f20747eb2ba:docs/team/reports/V114-dev3.md`). Use `openspec instructions apply --change say-immediate-default --json` as the work plan.

Implement the accepted 23 tasks, with small reviewable commits and your own report `docs/team/reports/P393-dev.md`. Do not implement unrelated P391/P388 work. P391 will serialize its SKILL.md edit after your candidate is settled; keep your SKILL change small and localized. Do not mark independent Verify or real archive complete and do not self-verify as the independent reviewer.

## Behavior that must land

1. Valid live inbox-watch remains preferred for default `team say`: durable inbox + spool, zero tmux keys, no forced audit, existing draft safety. A selected watch route that disappears or fails persistence cannot switch to guarded typing/forced direct in that same attempt.
2. Without a usable watcher, only after existing recipient/session/missing-window/dead-pane/empty-shell checks, default say performs the existing forced direct attempt even into a draft. Move those checks immediately before the direct action without duplicating offline inbox handling; `--no-verify` does not skip them.
3. Remove public `say --now` parser/usage/help in both flag positions and bilingual surfaces, with unknown-flag exit before any side effects. Keep `--any` and `--no-verify`; do not add an alias. `outbox flush --now` and `draft send --now` remain.
4. Default direct intent applies only to fresh `kind=say`, not ordinary later drains. Reuse the single force action/audit implementation; do not duplicate enqueue/tmux code or add a config/header/queue/daemon/framework. Exactly one existing-format forced line per actual direct attempt; none for watched/offline/rejected calls.
5. Selected-watch initial enqueue failure before an entry exists returns a real nonzero persistence error, not an offline/queued/inbox success. Existing pending-entry failures retain their entry. Do not turn a route failure into blind direct send.
6. Direct acknowledgement is an unconfirmed immediate attempt, without the retired flag, not “已确认送达” or an automatic queue promise. The old best-effort tmux gaps are disclosed, not silently repaired or presented as model receipt.
7. Other senders (notify, completion/meeting/Pulse knocks, ordinary draft/Outbox) keep their existing guard and explicit-override behavior. Ordinary Outbox/held/queued recovery remains.

If the accepted design proves contradictory, stop with `BLOCKED:` and a concrete counterexample; do not rewrite the behavior silently.

## Write set

Only the accepted proposal surfaces:

- `openspec/changes/say-immediate-default/**` for evidence-backed task checkoffs; never canonical specs and no real archive.
- `skills/teamsmith/scripts/lib/{cmd-agents,outbox}.sh`;
- `skills/teamsmith/scripts/strings/{commands,help.en,help.zh}.tsv`;
- active `skills/teamsmith/SKILL.md` and `references/{config,troubleshooting}.md`, plus any current skill/reference/template surface with the same false say-draft promise (not historical reports/decisions);
- existing fixtures/tests identified by the design: `tests/smoke.sh`, `guard-matrix.sh`, `delivery-truth.sh`, `help-surface.sh`, `routes.sh`, watcher harnesses, `fixtures/delivery-truth-real/**` and directly related existing files;
- `docs/team/reports/P393-dev.md` and host-side evidence outside Git.

Do not edit AGENTS/PM/worker launch prompts, P391 files, P388 files, unrelated tasks/reviews/board/decisions/ownership, release/CI files or live team state. No merge, push, real archive or release.

## Test migration and required evidence

Follow design decision 5 and tasks 4–6 exactly. Move old say-driven draft/geometry/race/unknown/unconfirmed/stalled/terminal cases to actual protected draft/notify/explicit-queue entries with their assertions and mutations intact; do not simply expect dirty typing or delete old red sides. Add the new default-direct/watch/parser cases in the same existing fixtures, not a new smoke section/framework.

Required author evidence on the final frozen candidate:

1. **Parser/help:** both `say --now dev "message"` and `say dev "message" --now` exit 2 with unknown flag and byte-identical keys/inbox/spool/forced/active+held queue snapshots. Bilingual help hides only this flag; draft/outbox flags still work. `--any`/`--no-verify` remain.
2. **No-watch direct:** same genuine dirty editor on baseline default, baseline `--now`, candidate default. Baseline default queues; the other two produce equivalent draft+message in actual model requests without a flush, one forced line and no active queue entry. Preserve exact request/frame/cursor evidence, not pane echo or rc=0. Include `--no-verify` and recorded payload/Enter failure honesty.
3. **Watcher:** clean/dirty valid watch has durable+spool, zero keys, unchanged draft, one eventual model receipt and no forced record. Invalid/stale/dead/foreign registration does not count as success; accepted-then-lost route and inbox/spool failures never type in that attempt. Initial enqueue failure is nonzero with no phantom queue/offline success.
4. **Safety:** offline/missing-window/dead-pane/empty-shell, unknown recipient/`--any`, cross-session and dispatch dead-pane regressions remain. Other senders' draft protection and explicit Outbox override/terminal no-repaste behavior remain.
5. **Mutations:** in scratch copies, removing default direct intent, moving force ahead of watch and restoring the public parser flag each produce a named red; restoration is green. Migrated guard mutations still produce their original red/green contrasts. Prove each mutation actually landed.
6. **Real Pi versions:** use pinned Pi 0.99.2 for the reproducible judged A/B and second-correction evidence. Run current Pi 1.4.0 separately with the same mock backend and genuine draft for direct/watch request/frame observation; demonstrate the old judge rejects it rather than claiming it passes. Do not cherry-pick P380, mix versions, use real credentials or message this live team. Move test-owned scratch/HOME/history to `/var/tmp` and keep full host-bind-mounted logs.
7. **Scope:** compute the actual changed-path selector closure and execute it non-FAST, plus the minimum relevant closure and `delivery-truth.sh --section all --mutations` from accepted tasks 6.1–6.2. FAST skips are not passes. If selector returns FULL, stop and hand PM the full-gate scheduling decision rather than silently narrowing.

Use long jobs in the background with full logs, one gate at a time, and never write/commit the tree during a fingerprinted run. Keep performance measurements informational only.

## Final checks and handoff

Run on the settled tree:

```bash
openspec validate say-immediate-default --strict
openspec validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
```

Run all accepted selected/non-FAST/real-Pi checks above with exact commands and complete logs. The full suite/PM merge gate is not replaced by these targeted results. Do not run live-team say, protected merge/push, real archive or release.

The report leads with the implemented behavior and remaining boundaries. Include exact commits, changed files, parser/audit/queue before-after evidence, selected closure and actual not-run scope, mutation reds/restored greens, version-separated real-Pi requests/frames, and P391 ordering. Mark every accepted task done only with its evidence; independent verification remains unmarked for the later verifier. Commit with Conventional Commits + P393 + `Agent: dev`, leave the branch clean and notify PM. A different agent will independently Verify.
