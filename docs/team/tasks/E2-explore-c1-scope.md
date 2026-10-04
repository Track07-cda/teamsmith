# E2 · Explore: scope and split for change C1 `launch-and-adapter-evidence`

```
task:   E2
agent:  dev2
phase:  explore
change: launch-and-adapter-evidence
deps:   E1 (inventory, accepted: DECISIONS D15), v1.29.0
```

> Phase 1 of the pipeline for the **second** change. E1 surveyed the whole backlog and recommended four changes; this
> task designs **only C1** — its scope, its option set, its task split and its risks — starting from E1's inventory rows
> rather than re-surveying the tree. Output is a report; no change artifacts, no code.

## What C1 is (from E1 §5, option D)

The first *backfill* change: the behaviours around adapters and launch/liveness evidence that shipped in M3/M6/M7/M8 and
never reached `openspec/specs/**`. E1's inventory rows in these groups:

- **B — a new capability `agent-adapters`**: A1 (the template engine: placeholders, malformed/blank/multi-line
  rejection, first-word resolution, out-of-band prompt) and A2 (the PM side: `TEAM_PM_CMD`/`TEAM_PM_BIN`/
  `{resume_args}`, byte-identical default, malformed templates loud);
- **launch/liveness evidence** (E1's D3/W1): `proof=spawn` semantics, "harness came up" ≠ "agent came up", the exit
  event file, positive PM liveness (`state/pm.pid` + cwd), a wrapper CLI counting as the PM;
- **W2 (`starting`)** and the six states — decide whether these belong to C1 or to the `pm-lifecycle` change (C2/C3
  boundary), and say why.

## Deliverable — `docs/team/reports/E2-dev2.md`

1. **Row-level scope**: for each candidate row (E1's A1, A2, D3, W1, W2 …): keep-in-C1 / move-to-`pm-lifecycle` /
   move-to-C2 (`review-evidence-integrity`) / out of scope, with a one-line reason. **Do not widen**: C1 is one change,
   not the whole backfill.
2. **Options for the split** (2–3), each with: task count, which capability files the deltas touch, what the verify
   phase would have to check, and the failure modes. Recommend one and name the tasks (phase, owner, deps).
3. **The structural decision to settle before propose**: does `agent-adapters` become a new capability with the
   adapter requirement **REMOVED + migrated** out of `dispatch` (E1 §3.1 B's note), and what does that do to the
   existing `dispatch` spec's numbering/cross-references? You tested `archive` behaviour for a new capability in E1
   §4.2; state what the delta operations must look like for a move of this shape, and whether `MODIFIED`/`REMOVED`
   ordering matters.
4. **Risks**: which of these requirements can be stated as a *falsifiable* scenario today (name the command that would
   fail), and which cannot (say why — e.g. "the default Pi path is byte-identical" is falsifiable only by comparing a
   rendered command string, which is exactly the kind of evidence `M8.1` produced: name how the scenario should read).
5. **What the verify phase must do** for C1 — the differential/ adversarial angle that fits this change (for C0 it was
   the archive-parity matrix; here it is something else — say what, and why that is the strongest available check).

## Boundaries

- Write only `docs/team/reports/E2-dev2.md`. No `openspec/changes/**`, no spec edits, no code, no dispatch.
- Base your inventory numbers on E1's rows and `openspec/specs/**` as it stands today (post-M9.x), and cite the commands
  you ran.

## Acceptance

```sh
openspec list --specs        # paste it: the capability set C1 will touch
openspec list                # the open changes (C0 is one of them until it archives)
git status --porcelain       # only your report
```
