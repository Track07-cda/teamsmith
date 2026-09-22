# tmux-gate-grant-redesign · proposal

## Why

The destructive-tmux gate (`scripts/shim/tmux`, the `tmux` wrapper every agent window puts first on `PATH`) is
defeated by its own escape hatch: `scripts/team:19` exports `TEAM_ALLOW_DESTRUCTIVE_TMUX="${…:-1}"` while the
schema default is `0` (`cmd-config.sh:65`). tmux copies a server's environment into every new pane, so a server
started from a process carrying the variable grants it to every window of every project on that server.
`docs/team/reviews/M62.md` reproduced the chain; the seventh default-server death (2026-09-21T12:19:58Z) is two
consecutive ledger lines — `act=refused` then `act=override` — and the gate's live path holds 1 `refused`, 1
`override`, 41 `pass` destructive calls.

The user decided (2026-09-21) to redo the grant model: the verdict follows the **object a call
targets**, the only escape is a **human's explicit argv token**, and **no environment authorizes anything**.

## What Changes

Three ADDED requirements in `boundary` (which already owns tmux targets; the base spec has no gate requirement —
the two pending rows in `spec-backfill-2026-09` are superseded, design D1):

- **The object decides.** On the shared default socket `kill-server` and `kill-session -a` are refused (exit 64)
  without exception; any other destructive call is refused unless its effective `-t` names the caller's own session
  (a session component equal to a non-empty, M40-bound `TEAM_SESSION`). Private sockets pass; the M41 socket
  table and fake-isolation verdicts are untouched.
- **The escape is an argv token.** `--teamsmith-allow-destructive`, consumed and stripped before exec, never
  exported, logged `act=explicit-flag`. The `scripts/team` export is deleted, the legacy key stops authorizing and
  stays as a non-writable tombstone, and `team doctor` names the server-global residue.
- **Fixtures never aim the real tmux at the real default socket.** Refusal probes pin an argv-recording stub;
  execution uses a private socket or the container; the leak shape is reproduced in the container; the isolation
  lint sees a flagged call as mutating and never accepts the flag as isolation.

## Capabilities

### Modified Capabilities

- `boundary`: the gate's verdict, its audit vocabulary and the fixture discipline around it.

## Impact

`scripts/shim/tmux`; `scripts/team:19`; `scripts/lib/common.sh` (gate comments, launch prefix); the four CLI
destructive call sites; `cmd-config.sh`; `cmd-project.sh` (doctor); `references/config.md`;
`references/troubleshooting.md` §18; `CHANGELOG.md`; `tests/smoke.sh` §31c; `tests/tmux-lint.pl`;
`tests/container-tmux.sh`. Untouched: the lint's isolation proofs, the container contract and every other
capability.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
git status --porcelain
```

## What flips

Restoring the `TEAM_ALLOW_DESTRUCTIVE_TMUX` read in a scratch shim makes the inherited-environment probes stop
refusing; accepting any target makes the foreign-target probes execute the stub; dropping the flag stripping makes
the stub see the token; dropping the M40 binding makes an inherited `TEAM_SESSION` authorize a foreign target.

## Boundaries

Planning only: this task writes `openspec/changes/tmux-gate-grant-redesign/**` and its report; `scripts/**`,
`tests/**`, `extension/**` and `references/**` stay untouched; implementation needs the apply brief's explicit
path grants (OWNERSHIP). The `spec-backfill-2026-09` transfer of design D1 is a PM action.

## Evidence the report must contain

`openspec validate --all --strict` tails; the FAST smoke tail; `grep -n '^### Requirement'` on the base boundary
spec and the spec-backfill delta; the audit-ledger counters with their command; the requirement→task and
scenario→fixture maps.
