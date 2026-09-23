# dispatch-verify-seat-guard · proposal

## Why

`docs/team/OWNERSHIP.md` says the verification seat does not change implementation — that is where its independence
comes from — but `team dispatch` does not enforce it: the PM dispatched an apply task to the `verify` seat twice
(M53, then P36); both times the seat refused it by hand (`BLOCKED`) and the work moved. Human memory failed twice;
D36 turns the rule into a dispatch guard. Alternatives: `design.md` §1–§5.

## What Changes

- **ADDED — `dispatch`**: a fifth pre-window guard. `team dispatch` refuses implementation work for the project's
  verification seat (`TEAM_VERIFY_SEAT`, default `verify`) before any window is opened and for `--print` as well:
  a brief with `phase: apply`, or an undeclared phase whose `grant:` names implementation paths. The other four
  phases, an undeclared phase without such a grant, and any non-verify seat proceed. The refusal names the seat,
  `OWNERSHIP.md`'s verification row and both ways out, opens no window and changes no board row; `--force`
  proceeds with a warning and exactly one audit line.
- **ADDED — `verification`**: the role boundary next to "The verifier of a change is not one of its authors" — the
  verification seat's independence also means it does not implement; `TEAM_VERIFY_SEAT` names it (default
  `verify`), and its ledger/reconnaissance work (`docs/team/**`, `openspec/**`) stays allowed.
- **Docs**: `references/protocol.md` §5b gains the fifth guard; `OWNERSHIP.md`'s verify row points at it; the brief
  template declares the `grant:` line the guard reads; the AGENTS/PROTOCOL paragraphs list the fifth refusal.

## Capabilities

### New Capabilities

- (none)

### Modified Capabilities

- `dispatch`: a verification seat is never dispatched implementation work (refusal, `--print`, `--force` audit).
- `verification`: the verification seat's independence includes not implementing (seat identity + boundary).

## Impact

Under `skills/teamsmith/`: `scripts/lib/{cmd-agents,common,cmd-config}.sh`, `references/{config,protocol}.md`,
`templates/{task.md.tmpl,config.sh.tmpl,AGENTS.section.md.tmpl,PROTOCOL.md.tmpl}`, `tests/smoke.sh` (one section);
plus `AGENTS.md` and `docs/team/OWNERSHIP.md`. Untouched: the four existing guards, `team review`, roster
semantics, this project's `.pi/team/config.sh`.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
```

(The third line is the full gate, once before delivery.)

## What flips

Neutering the refusal branch (dropping the guard call, or its `phase: apply` check) → the new smoke section's
apply case goes red: a window is requested where the fixture expects none. Restoring it → green. The
`phase: verify`, ledger-only-grant and non-verify-seat cases stay green through both revisions, so the fixture
separates "refuses implementation" from "refuses everything".

## Boundaries

Planning only: this task writes `openspec/changes/dispatch-verify-seat-guard/**` and its report. Apply may touch
only the paths under Impact — several are PM-owned and need the brief's explicit grant, and
`skills/teamsmith/tests/**` belongs to `agent:dev` — and must not weaken the four existing guards, change
`team review`, edit this project's `.pi/team/config.sh`, or write another change's delta set.

## Evidence the report must contain

Both acceptance tails; the delta→requirement→item maps; every scenario's fixture; the flip tails (guard broken →
red, restored → green, allow cases green in both); the fixture census (refuse / allow / force); and the paths the
diff touched.
