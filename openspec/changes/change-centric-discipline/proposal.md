# Propose: `change-centric-discipline` — one task, one change; anchored briefs; one delta writer; no self-verification

## Why

The user's decision (D31): «agent 按照 change 做，不要在一个任务中包含多个 spec change。B 方案». Model:
`1 change : N tasks` (a change is the contract and the dispatch unit, a task a batch inside it) and
`1 task : 0..1 change`.

Nothing enforces it. `team_task_change` returns whatever the brief's first `change:` line says (`common.sh:2429`),
so two ids, a typo or a missing line dispatch silently. Two unfinished tasks of one change may write the same delta
(`M49` is queued for the delta `P22` just shipped), nothing relates a `phase: verify` task to the `agent:` lines of
the change's apply tasks, and the archive evidence is one directory — so the first finished task could carry it.

Policy B (D31): a rule that must hold across tasks — silent failure, destructive action, authority, identity, gate,
performance contract — needs a requirement+scenario anchor; a brief points at a change, or writes
`specs: <capability>#<requirement>`, or declares `anchor: none (infra) — <reason>`.

## What Changes

- **ADDED** — `dispatch`: a brief names **at most one** change id (one token or `-`); a comma list, two ids, a
  second `change:` line or a non-id value are refused by `team dispatch` and by `--print`, with no override.
- **ADDED** — `dispatch`: a change-less brief declares its anchor; neither form present, or a `specs:` entry that
  does not resolve in `openspec/specs/`, is refused (`--force` + one audit line as the escape).
- **ADDED** — `dispatch`: a `deltas:` declaration plus the single-writer guard: two unfinished tasks of one change
  whose declarations intersect are refused by name (both tasks, the file); `--force` + one audit line.
- **ADDED** — `verification`: a `phase: verify` task whose agent authored an `apply` task of the same change is
  refused (per change, not per task); `--force` + audit, and the fact stays visible in the change view.
- **ADDED** — `board-and-status`: `team change status <id>` (tasks, evidence, delta files; exit 0 iff every mapped
  task is finished), a digest section and panel tokens grouping tasks by change, and the archive precondition: an
  archive-phase task cannot be `done` while a sibling task of the change is unfinished.

## Capabilities

### Modified Capabilities

- `dispatch` — the brief's change key, the anchor declaration, the delta single-writer guard.
- `verification` — the verifier of a change is independent of its apply tasks.
- `board-and-status` — the change view and the archive precondition.

No new capability, and no restated requirement: each rule constrains a surface an existing capability already owns
(design §2), and the delta is ADDED-only, so nothing is superseded.

## Impact

`scripts/lib/{common,cmd-agents,cmd-status}.sh`, the `team` verb + help, `templates/task.md.tmpl`,
`references/{openspec,protocol,workflows}.md`, `SKILL.md`, `AGENTS.md` + the AGENTS/PROTOCOL templates,
`skills/teamsmith/tests/**`, and `openspec/specs/**` through archive. No new dependency, no new `TEAM_*` key, no
change to the launch proof, the send path or the panel performance contract (the new scans are in-process file
reads, never a per-file `team` subprocess).

## Acceptance

This propose task (run now, both exist):

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
git status --porcelain
```

The apply brief's acceptance (built by this change; not runnable yet):

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
```

## Boundaries

- This task writes only `openspec/changes/change-centric-discipline/**` and `docs/team/reports/P23-dev-bob.md`.
- Out of scope: any implementation, the backfill itself (design §9 has the table and the recommendation; it is a
  separate change), `docs/team/DECISIONS.md`, and any retroactive edit of the eight `change: -` briefs.
- PM-owned and needing an explicit grant in the apply brief: `skills/teamsmith/scripts/**`, `references/**`,
  `templates/**`, `SKILL.md`, `AGENTS.md`, `openspec/specs/**`. `skills/teamsmith/tests/**` is `agent:dev`'s.
- No new authority: every guard refuses by name and never widens what an agent may do.

## Evidence the report must contain

Both acceptance tails; the requirement → task map; for every scenario the observable that is red on the current tree
and the fixture that will pin it; the backfill table with its evidence command per row; the trial-archive output;
and the P18/V18 author trail the no-self-verify ruling rests on.
