# Propose: `notify-sender-identity` — a notification names the sender, not the recipient

## Why

The PM's inbox cannot tell who reported: the brief records 55 `- <ts> [manual] agent:pm · …` lines whose real
authors were workers, while `docs/team/reports/**` names them correctly. The sender position is filled with
the recipient (`team_inbox_append "$agent" manual "$msg"` and `[manual] agent:$agent` with `--from "$agent"` —
`cmd-agents.sh:1141,1148,1160`, where `$agent` is `pm`), so the manual and `[auto]` paths disagree even though
`TEAM_AGENT` is empty in worker processes and their `TEAM_ROOT` points at their own worktree.

## What Changes

- `team notify` resolves the sender from the caller's runtime directory (M40: the main worktree → `pm`, a
  worktree under `<main>/<TEAM_WORKTREES_DIR>/` → that seat, cwd-first, subdirectories included), stamps it in
  the durable inbox line, the knock text and the queued entry's `from:`, and fails loudly (nothing written)
  when the directory names neither, instead of claiming `pm`. `--from <name>` is the explicit claim for that
  case; an inherited `TEAM_AGENT` never overrides the directory.
- The turn-end extension derives the same seat from the same directory (the worktree of cwd first; the tmux
  window name only corroborates and must not override), so one runtime context yields one sender on both paths.
- No migration: existing lines are not rewritten; `team say`/pulse/meeting line shapes are untouched.

## Capabilities

### Modified Capabilities

- `notify-and-inbox`: `A turn-end notification appends one inbox line and knocks once` gains the sender
  derivation for `<agent>`; a new ADDED requirement covers the manual path's resolution, refusal, `--from`,
  attribution surfaces and cross-path agreement.

## Impact

`skills/teamsmith/scripts/lib/cmd-agents.sh` (`team_cmd_notify`; `team_inbox_append` gains an optional sender),
`skills/teamsmith/extension/team-notify.ts` (agent derivation),
`skills/teamsmith/SKILL.md` + `references/{agent-adapters,protocol,troubleshooting}.md`,
`skills/teamsmith/tests/**` (new smoke section, `flip-p72.sh`). Worker-context lines/knocks change from
`agent:pm` to the worker's seat; an unclassifiable directory now fails.

## Acceptance

This propose (ran):

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
git status --porcelain
```

The apply's acceptance (planned, not runnable yet):

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
bash skills/teamsmith/tests/flip-p72.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/smoke.sh </dev/null
```

## The flip

Red before (probed on this tree in a `/tmp` fixture): from `<main>/.worktrees/dev`,
`team notify pm --from-file <file>` exits 0 and writes
`- 2026-09-22T20:30:10Z [manual] agent:pm · P72 probe: worker summary`, indistinguishable from the PM-context
line. Green after: the worker context writes `[manual] agent:dev · …`, the main worktree still writes
`agent:pm`, and an unclassifiable worktree (`git worktree add <tmp>/elsewhere`) exits non-zero with the inbox
byte-identical. `flip-p72.sh` breaks each half — recipient-as-sender, unresolved → `pm`, window over worktree —
and the matching scenario must red.

## Boundaries

Propose only: this phase writes `openspec/changes/notify-sender-identity/**` and the report, nothing under
`skills/**`. The apply needs grants for `scripts/lib/cmd-agents.sh`, `extension/team-notify.ts`,
`references/**` and `SKILL.md`; `tests/**` is `agent:dev`'s. Out of scope: `team say`/pulse/meeting line
shapes, historical lines (no rewrite), the delivery guard/outbox semantics, every other spec.

## Evidence the report must contain

The requirement→item and scenario→item→evidence maps; red-before/green-after tails for the resolution,
refusal, inherited-`TEAM_AGENT` and `--from` scenarios; the cross-path agreement fixture (manual vs `[auto]`,
mismatched window included); each `flip-p72.sh` red; validate and fast/full gate tails; the `grep` proving the
worker fixture produces no `agent:pm`.
