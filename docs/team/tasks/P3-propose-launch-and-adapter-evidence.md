# P3 · Propose: `launch-and-adapter-evidence` (C1)

```
task:   P3
agent:  dev2
phase:  propose
change: launch-and-adapter-evidence
deps:   E2 (accepted: DECISIONS D18); E1 §3.1 (the nine rows)
```

> Pipeline phase 2. You hold the context from E2 and D18 records its acceptance. **Planning artifacts only** — no
> code, no edits to `openspec/specs/**`. When complete, stop: the PM reviews the artifacts and writes
> `docs/team/reviews/launch-and-adapter-evidence-proposal.md`; nothing applies before an ACCEPTED verdict.

## What the change is

Backfill the shipped behaviours around the adapter engine and launch/liveness evidence into `openspec/specs/**`,
following E2's accepted design (D18): three delta files —

1. `dispatch`: **REMOVED** the adapter-engine requirement (with Reason/Migration), plus the ADDED ×2 (launch proof
   `D3`, session-window `D4`) and MODIFIED ×2 (brief boundary `D2`, branch guard `D1`);
2. new capability `agent-adapters`: the migrated engine (its four scenarios must survive the move byte-for-byte apart
   from the declared additions), the first-word resolution requirement, and the PM-side requirement (`TEAM_PM_CMD` /
   `TEAM_PM_BIN` / `{resume_args}`);
3. new capability `pm-lifecycle`: positive PM liveness (`W1`), the `starting` state (`W2`), `reload` semantics (`W3`).

## Binding conditions from the accepted exploration

- **W2's state list is corrected**: `running/starting/idle/unknown/foreign/missing` — there is **no `busy`** state. A
  scenario asserting one would be unfalsifiable and false.
- **A2's "the default Pi path is byte-identical"** must use an observable surface: `team up` in a fixture project,
  then the argv recorded in `state/pm.pid` (or tmux's `pane_start_command`); it must **not** name
  `team_pm_launch_cmd` or compare against a test-only string. If you conclude neither surface is acceptable in a
  scenario, keep the promise as prose in `references/agent-adapters.md` and say so in the proposal (that is a
  request to the PM, not a decision you take).
- Every requirement maps to a falsifier that exists today (E2 §5's table); every scenario names the command that
  would fail. A scenario with no runnable falsifier does not ship.
- **tasks.md is ordered** (one change, one apply brief, sequential sub-tasks — D18's binding condition): dispatch
  deltas → agent-adapters → pm-lifecycle, with the smoke-free rationale noted (a backfill ships no behaviour, so the
  smoke suite cannot catch a mistake — the verify layers are the safety net, see below).
- The proposal states the verify layers as acceptance: ① applicability (C0's lint + validate + a scratch
  `openspec archive` doing exactly the promised operations), ② **migration diff** (the pre/post move requirement
  compared byte-for-byte apart from declared additions), ③ falsifier injection (no scenario without a red).

## Evidence for the PM review

- `openspec change show launch-and-adapter-evidence`, `openspec validate --all --strict` (with the change present),
  `spec-lint.sh`, and — on a **scratch copy** — `openspec archive -y launch-and-adapter-evidence` proving the promised
  operations apply (you did this probe in E2 §5 for the shapes; redo it against the final artifacts).
- Your report (`docs/team/reports/P3-dev2.md`): the delta inventory (rows → requirements → scenarios), what you
  deliberately left out (with reasons), and anything the PM must decide before apply.

## Boundaries

- Write only `openspec/changes/launch-and-adapter-evidence/**` and your report. Never `openspec/specs/**`, never code,
  never the ledger. Do not dispatch, do not archive.

## Acceptance

```sh
openspec validate --all --strict
bash skills/teamsmith/tests/spec-lint.sh
git status --porcelain        # only openspec/changes/launch-and-adapter-evidence/** + your report
```
