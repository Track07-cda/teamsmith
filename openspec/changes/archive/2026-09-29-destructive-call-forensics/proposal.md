# destructive-call-forensics · proposal

## Why

The 8th default-tmux-server death (2026-09-29) was investigated in the window that recorded it: the `act=refused` /
`allowed-owned` / `explicit-flag` lines had been pushed out of the bounded `tmux-calls.log` by later `pass`
traffic, so *what* was attempted was unrecoverable — twice in one day. The user's ruling (D60 #3A): destructive
records get **long retention** (bounded but durable), and a failed retention must not be silent.

## What Changes

- **ADDED — `boundary`** (*A destructive call's record outlives the call log's rotation*): every call whose action
  is not `pass` is copied **byte for byte** into a long-retention file beside the call log, at
  `$TEAM_TMUX_CALLS_LOG.forensics`; `pass` calls are never copied. It obeys the call log's own bound (past 2000
  lines the oldest go, the newest 1000 stay, the same `· rotation · dropped=<N>` marker). A failed retention is
  visible: a `✗` diagnostic on stderr naming the path, plus `retention=failed` on the call's own line; the verdict
  still decides the exit status.
- **MODIFIED — `boundary`** (*The gate's actions are logged…*): one line per call still holds, that line may carry
  `retention=failed`, and the scan exclusion covers both gate-written files; bound, vocabulary and launch command
  unchanged.
- **MODIFIED — `verification`** (*The fixture-trace scan reads ledger state, not traffic records*): the retention
  file joins the exact-path exclusions; name-sharing decoys stay in scope.

## Capabilities

### Modified Capabilities

- `boundary`: the logging requirement gains the retention field and the second excluded path; a new requirement
  defines the long-retention file, its bound and its failure visibility.
- `verification`: the fixture-trace scan's exact-path exclusion set grows by the retention file.

## Impact

`skills/teamsmith/scripts/shim/tmux` (logging block), `skills/teamsmith/tests/smoke.sh` (§31c; `real_ledger_hits` +
§12b-j + M16), `skills/teamsmith/references/troubleshooting.md` §18. Untouched: the verdict and socket tables,
fake-isolation rules, argv pass-through, the launch environment, the call log's bound and `dropped=N`, the
`state/` layout beyond the new sibling file.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
# apply, in one batch:
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/smoke.sh </dev/null
perl skills/teamsmith/tests/tmux-lint.pl
```

## What flips

A refused call now writes `<log>.forensics` (red before: it never exists); a `pass` flood drops the call log's copy
but leaves the retained record byte-identical; a `pass` call adds no line; a directory target leaves
`retention=failed` on the call's line and a `✗` on stderr; a trace in the retention file is not a leak while
`tmux-calls.log.forensics.1` is reported.

## Boundaries

Planning only: this task writes `openspec/changes/destructive-call-forensics/**` and this report. The apply needs
the brief's grant for the shim's logging block and `references/troubleshooting.md` §18 (both PM-owned); `tests/**`
is agent-owned. Out of scope: the verdict logic (M67/D36), the default-socket and fake-isolation rules, the launch
command's pins, the call log's own bound/marker contract, any external environment change (D57).

## Evidence the report must contain

Propose: the validate tail, the delta→requirement map, the scenario inventory, the trade-off rulings. Apply: gate/FAST/lint tails, every flip's red and green tail, the retained line's
byte-identity against the call log's, the failure probe, the scan legs with decoys, the untouched-contract
statement.
