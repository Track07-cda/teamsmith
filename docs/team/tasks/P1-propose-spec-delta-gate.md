# P1 · Propose: `spec-delta-gate` (C0 — the gate-time MODIFIED-delta check)

```
task:   P1
agent:  dev2
phase:  propose
deps:   E1 (accepted: DECISIONS D15, option D with C0 first)
```

> Pipeline phase 2 (`opsx-propose`). You hold the context from E1 and you already probed the mechanics in your scratch
> copy. **Planning artifacts only** — no code, no edits to `openspec/specs/**`. When the artifacts are complete, stop:
> the PM reviews them and writes `docs/team/reviews/spec-delta-gate-proposal.md` with a verdict; nothing may be
> applied before that verdict is `ACCEPTED`.

## What this change is

C0 from E1 §5: a **gate-time check for MODIFIED deltas**, because `openspec validate --all --strict` accepts both of the
probes you ran (a `## MODIFIED Requirements` header naming a requirement that does not exist, and a `MODIFIED` block
that drops one of the base requirement's scenarios) while `openspec archive` rejects them — too late, after apply and
possibly after the code has merged. A backfill made of MODIFIED deltas would otherwise fail at phase 5.

Deliverables for the propose phase (all inside `openspec/changes/spec-delta-gate/`):

- `proposal.md` — why (the asymmetry, with your §4.2 transcripts as evidence), what changes, the acceptance commands
  **verbatim**, boundaries, and what the report must contain. Your `rules:` in `openspec/config.yaml` say what a
  proposal must carry; follow them rather than this brief.
- `specs/<capability>/spec.md` — the delta for the **promise** this adds. Decide the capability: `verification` is the
  natural home ("the gate refuses a change whose MODIFIED delta cannot be applied to the base spec") if you can state
  it as observable behavior; if you conclude it belongs elsewhere (or that it is a `MODIFIED` requirement of an
  existing one), say why in the proposal. The requirement must be falsifiable: the failure is a command exiting
  non-zero with a named reason.
- `design.md` (only if you have a real design decision to record — e.g. bash+awk with no new runtime dependency, and
  where the checker lives: `tests/` next to `spec-lint.sh`, versus inside the CLI). Do not write a design for
  ceremony's sake; if you write one, it must state the alternative you rejected.
- `tasks.md` — one verifiable item per step, ordered: implement the checker → wire it into `TEAM_GATES` (before or
  after the existing two steps — justify) → smoke coverage **including the two red probes** and a green control →
  docs (`references/openspec.md`'s gate section + `config.yaml`'s `rules`/`operations` if the check changes what the
  PM must do) → the change's own archive note.
- **The delta check's scope must be decided explicitly**: which delta operations it validates (`MODIFIED` certainly;
  what about `REMOVED`/`RENAMED`/`ADDED`?) and how it reports (`file:line: rule: detail`, exit 1; exit 2 for an
  unusable root, matching `spec-lint.sh`'s contract). Keep the two checkers' contracts consistent — a reviewer will
  compare them.

## Evidence the PM will look for in your report (`docs/team/reports/P1-dev2.md`)

- the artifacts' paths and a one-line summary each (`openspec change show spec-delta-gate`, `openspec validate --all
  --strict` including the new change, `spec-lint`);
- the two red probes and one green control, **as commands with their output**, run against the *new* checker
  (you may keep the transcripts from E1 §7 for the OpenSpec behaviour, but the new checker's behaviour needs fresh
  runs);
- what you deliberately left out of the change (with the reason), and anything the PM must decide before apply.

## Boundaries

- You may write only `openspec/changes/spec-delta-gate/**` and your report. Do **not** touch `openspec/specs/**`
  (archive does that), the CLI, templates or the ledger.
- Do not start implementation, do not run `openspec archive`, do not dispatch anyone.

## Acceptance

```sh
openspec validate --all --strict          # includes the new change; must be green
bash skills/teamsmith/tests/spec-lint.sh  # must stay green
openspec change show spec-delta-gate      # the artifacts are complete and readable
git status --porcelain                    # only openspec/changes/spec-delta-gate/** + your report
```
