# safe-signal-discipline · proposal

## Why

Four incidents in one family: a process addressed by a name or a command-line pattern instead of a pid the actor
recorded; the latest killed three concurrent gate clients of other jobs and orphaned three containers. Nothing
enforces the rule, and the background lane records no pid (recon: `docs/team/reports/P154-dev-bob/recon.log`).

## What Changes

- **MODIFIED — `boundary#The gate's actions are logged, and no window carries a destructive-call grant`**: the
  launch prefix puts the whole gate family first on `PATH` and pins `TEAM_SIGNAL_CALLS_LOG`/`TEAM_SIGNAL_REAL`
  beside the tmux pair; neither gate takes an environment grant. Baseline kept.
- **ADDED — `boundary#Signals go to a recorded pid, never to a name or a pattern`**: `pkill` (any form) and
  `killall` refuse with exit 64 and the message naming the safe routes; help/version pass and are recorded; the
  reach (`kill`, `pgrep`, absolute paths, ungated shells) is a stated boundary.
- **ADDED — `boundary#The signal gate's calls are recorded, and its refusals outlive the call log's rotation`**:
  one line per call, the family's bound, `.forensics` retention of refusals.
- **ADDED — `boundary#\`team bg\` stops a job by the pid it recorded, and prints what it signalled`**: the
  spawner writes `state/bg/<id>.job` (pid, group, start-time, cwd, log, command); `team bg list|stop` verify
  `(pid, start-time)` and signal only that job's group, refusing unknown/reused/malformed/other-state ids.
- **ADDED — `boundary#Scripts select processes by recorded pid, and the lint keeps it that way`**: a lint in the
  tmux lint's family (own sha256-frozen legacy list) reddens `pkill`/`killall`, absolute paths, `xargs kill` and
  pattern-fed `kill`; the two `pkill -f` cleanups in the gate's own M25 fixture become recorded-pid kills.
- The three new seams are `refuse` schema rows with labels.

## Capabilities

### Modified Capabilities
- `boundary`: the launch-prefix requirement grows the signal family; four requirements are added in it.

## Impact

`skills/teamsmith/scripts/shim/**` (new gates), `scripts/lib/{common,cmd-bg,cmd-config,cmd-project}.sh`,
`scripts/team`, `extension/team-bg.ts`, the panel's string tables + bundle, `tests/**`,
`references/{protocol,config,troubleshooting}.md`, `SKILL.md`. Untouched: tmux verdicts, `openspec/specs/**`,
other projects.

## What flips

- Pattern selection hits both decoys and the caller's own shell today (recon 2/2b) → refused, stub uncalled,
  decoys alive. `team bg` does not exist and the ledger carries no pid (recon 3) → a job stopped by its recorded
  pid, the neighbour alive.
- The tmux lint is green while two `pkill -f` lines sit in the gate's own M25 fixture (recon 4) → the tree is
  clean, a planted `pkill -f x` is red with file and line.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
bash skills/teamsmith/tests/signal-lint.pl --selftest
bash skills/teamsmith/tests/signal-gate.sh
bash skills/teamsmith/tests/team-bg-stop.sh
bash skills/teamsmith/tests/signal-gate.sh --break=pass
bash skills/teamsmith/tests/team-bg-stop.sh --break=no-identity
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/smoke.sh </dev/null
```

The first line runs now; the rest need the apply commit, where both `--break` lines must exit non-zero.

## Boundaries

Planning only: this task writes `openspec/changes/safe-signal-discipline/**` and its report. The apply needs the
grant for the paths in `tasks.md` and must not widen a refusal into a pass, change a tmux verdict, signal an
unrecorded process, or touch `openspec/specs/**`.

## Evidence the report must contain

Propose: the validate tail, the delta→requirement map, the scenario inventory, the recon. Apply: each fixture's
green run, both `--break` red runs, the restored green run, the lint's `--selftest` and scratch-copy flip, the
launch-prefix tail, both gate tails.
