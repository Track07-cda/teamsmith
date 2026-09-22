# Propose: `gate-isolation-scan-scope` — the isolation scan reads ledger state, not the gate's own traffic records

## Why

The gate's fixture-trace scan greps the caller's whole `docs/team/inbox` and `.pi/team/state` (only `state/bg/`
is excluded) and treats any hit as a leak. One file in scope is the tmux call audit log `state/tmux-calls.log`,
whose content is **by design** the caller's own argv — session names, targets, payloads. So every legitimate
fixture that makes a gated tmux call (P67's private `p67faketui-*` sessions) writes its own name into the real
project's log, and the next `12b-j` assertion goes red: PM measured `✓2394 ✗1` on main, the only red naming
`…/state/tmux-calls.log`. The scan is self-poisoning, and because the file is append-only until its bound the red
is sticky until someone deletes lines by hand — the PM did exactly that. Separately, the log's truncation is
silent: the live file is 1780 lines today, and a probe (2100 seeded lines + one gated call) leaves 1000 lines with
first line `seed 1102` and nothing saying history was dropped.

## What Changes

- **ADDED — `verification`**: the scan's scope becomes a contract. Ledger state is in scope; traffic records are
  not. Exactly two exclusions: `state/bg/**` and the exact path `state/tmux-calls.log`. Anything else under the
  two roots stays in scope — including a file nested in a subdirectory or one that merely shares the log's name —
  and the negative control (a trace planted in the ledger) stays red.
- **MODIFIED — `boundary`**: the log's hygiene requirement states what the log is (a traffic record, excluded
  from that scan), keeps the bound (past 2000 call lines the oldest go, the newest 1000 stay) and closes the
  silence: when the bound is enforced the surviving file starts with a rotation marker carrying the ISO time, the
  word `rotation` and `dropped=<N>`, the cumulative count of call lines no longer in the file. The four-value
  `act=` vocabulary and the newest-lines-survive guarantee do not change.

## Capabilities

### Modified Capabilities

- `verification` — ADDED requirement: the fixture-trace scan's scope.
- `boundary` — MODIFIED requirement: the audit log as a traffic record, and the self-describing rotation.

## Impact

`skills/teamsmith/tests/smoke.sh` (the shared scan function and its comment, 12b-j, M16's double control, 31c ⑤)
and `skills/teamsmith/scripts/shim/tmux` (rotation marker only). No new `TEAM_*` key; the socket table, verdict
table and argv pass-through are untouched. Out of scope: the log's line content (the full argv is its forensic
value), `ob_hash_real`'s informational fingerprint, time-based rotation, per-session/per-caller sharding, the
panel, the CI workflow.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/smoke.sh </dev/null
perl skills/teamsmith/tests/tmux-lint.pl
```

The first line runs now; the rest need the apply commit.

## What flips

- **Scan**: planting a fixture trace into `state/tmux-calls.log` makes the scan red today (reproduced in this
  propose); after the change the same plant is silent, while a trace in `docs/team/inbox/**` or any other
  `state/**` file is still named.
- **Rotation**: 2101 lines become 1000 with no marker today (first line `seed 1102`); after the change the first
  line is the marker with `dropped=1101` and the newest call line is still last.

## Boundaries

The apply may touch `skills/teamsmith/tests/**` (agent-owned) and, only for the rotation marker,
`skills/teamsmith/scripts/shim/tmux` — the brief grants that file explicitly. `openspec/specs/**`,
`docs/team/tasks/**` and the scan's roots/patterns stay untouched.

## Evidence the report must contain

The red and green plant for each scope leg (audit log, inbox, other state file, name-sharing sibling, nested path,
`bg/`), the first and second rotation probes, the negative-control outputs, and the tails of
`openspec validate --all --strict`, the FAST and full smoke and the lint.
