# sender-identity-refusal · proposal

## Why

`openspec/specs/notify-and-inbox/spec.md` still promises the sender rule the tool retired: the main worktree
resolves to `pm`, and an inherited `TEAM_AGENT` only earns a warning. Since P201 (commit `05b90f4`) the main
worktree resolves to `pm` only while nothing names a roster seat; with a seat clue the call exits non-zero,
writes nothing, and names both the directory's `pm` and the clue. P203's independent verification found the
drift: the next archive would keep shipping the promise whose silent `pm` fallback once recorded a seat's work as
the PM's.

## What Changes

- **MODIFIED — `notify-and-inbox#A manual notification is attributed to its sender, not its recipient`** (delta:
  `specs/notify-and-inbox/spec.md`). The runtime-directory bullet resolves the main worktree to `pm` only while
  no seat clue is present. A new paragraph defines a seat clue (a roster name: the caller's own pane's window
  name in this project's `TEAM_SESSION`, or an inherited `TEAM_AGENT`; names outside the roster, other sessions'
  windows and `pm` itself are not conflicts) and the refusal (non-zero, no inbox line, no knock, both names and
  both ways out on stderr); the `TEAM_AGENT` sentence gains the same exception. Eleven baseline scenarios are
  kept, seven added (`design.md` has the count table).
- No `skills/**` changes: the behaviour shipped with P201. The apply re-baselines the delta, proves scenario
  preservation and the trial archive, adds the missing fixture pair (the roster filter's red side), and runs the
  gates (`tasks.md`).

## Capabilities

### Modified Capabilities
- `notify-and-inbox` — one requirement; the `meeting` union and every other requirement are untouched.

## Impact

`openspec/changes/sender-identity-refusal/**`, and at archive one requirement of
`openspec/specs/notify-and-inbox/spec.md`. Untouched: `skills/teamsmith/scripts/**`, every other capability, the
panel, tmux.

## What flips

- **A dropped baseline scenario is red**: delete one preserved scenario from the delta and `openspec validate
  --all --strict` fails, naming it; intact, the run is green (`docs/team/reports/P204-dev2/trial-*.log`).
- **The archive lands the new text**: on a scratch copy `openspec archive -y sender-identity-refusal` reports
  `~ 1 modified`; the base requirement then carries the refusal paragraph and 18 scenarios, and the retired
  sentence is gone (same logs).
- **The behaviour the delta records is pinned**: `flip-p201.sh` reddens the refusal assertions when the conflict
  branch is removed, keeping the no-misfire control green. The "non-roster name must not refuse" clause still
  lacks a red side; the apply adds it.

## Acceptance

```sh
# propose
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
PATH="$HOME/.bun/bin:$PATH" bash skills/teamsmith/tests/spec-refs.sh --check

# apply
bash docs/team/reports/P204-dev2/trial.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 47 </dev/null
bash skills/teamsmith/tests/flip-p201.sh
```

## Boundaries

Propose writes this change's directory. The apply may touch
`skills/teamsmith/tests/{smoke.sh,flip-p201.sh,section-budgets.tsv}` only for the missing red side:
`skills/teamsmith/scripts/**` carries the shipped behaviour, and `openspec/specs/**` is written by the archive
only. Out of scope: `meeting`, `team say`, the `[auto]` path's resolution. A contradiction between the delta and
the code is a `BLOCKED:`, not an edit here.

## Evidence the report must contain

The validate tails (green, the dropped-scenario red, the post-archive run), the scenario title diff (11/18), the
`spec-refs.sh --check` tail, both shadows' flip outputs, and the exact changed-path list.
