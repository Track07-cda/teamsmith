# spec-backfill-2026-09 · spec backfill (policy B)

## Why

The user approved **spec policy B** (2026-09-20): a cross-task rule — silent failure, destructive action,
authority, identity, gate, performance contract — must have a requirement with a scenario. Six such rules
hardened last week and live only in tests and `references/`: the spec library has no home for them, so the tests
became the only source of truth. This change backfills contracts for behavior that has **already landed**; it
changes no code.

## What Changes

- **ADDED — `boundary`**: the tmux runtime gate — fallback-faithful socket resolution, destructive `kill-*` calls
  refused on the shared default socket (exit 64, nothing executed), private sockets and read-only calls pass,
  `TEAM_ALLOW_DESTRUCTIVE_TMUX=1` is the audited override, every call is logged (bounded) and the gate is injected
  into PM/worker windows; destructive tmux fixtures run in the container.
- **ADDED — `verification`**: the gate fails on conflict markers left in **tracked** files (working tree and
  index), naming `file:line`; untracked, `.worktrees/**` and binary files are out of scope.
- **ADDED — `delivery-guard`**: the input-box verdict tolerates pi's update banner — idle stays `EMPTY`, a real
  draft stays `HOLDS_ONLY=yes`, retraction stays `RETRACT=ok` — without turning pi's update check
off.
- **ADDED — `board-and-status`**: duplicate board ids (`board add` refuses and names the existing row,
  `--allow-dup` is audited, `board assign` is the in-place way, `board ls`/`digest`/`doctor` name duplicates) and
  the read budget (`board row` ≤ 1 git call, `digest` ≤ 50, with the cache-off direct parse equal to the cached
  output).
- **MODIFIED — `panel`** (two requirements): both pages track focus by **row identity** (id plus occurrence), not
  the bare entry id — the base sentence describes the pre-M48 behavior in which duplicate rows both highlighted
  and the cursor froze.
- **Item 6 is covered**: watch degradation is owned by `watch-degradation` — its deltas on this branch's base,
  and after main's archive commit `829dc19` the `notify-and-inbox`/`watchdog` specs — so this change adds nothing
  and the archives cannot collide.
- No new capability; no `## REMOVED` requirement.

## Capabilities

### Modified Capabilities

- `boundary`: the tmux runtime gate and the container discipline for destructive fixtures.
- `verification`: the conflict-marker guard.
- `delivery-guard`: update-banner tolerance.
- `board-and-status`: duplicate-id semantics and the read budget.
- `panel`: focus is addressed by row identity.

## Impact

Planning only: this task writes `openspec/changes/spec-backfill-2026-09/**` and its report, nothing else.
Landed behavior is the evidence: every scenario can fail against a named section. `apply` is a verification pass
over those citations (planned in `tasks.md`); `archive` merges after independent verification and the user's
confirmation.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
git status --porcelain
```

## Boundaries

Never edit `skills/teamsmith/{scripts,tests,extension,references}/**`; a behavior that
disagrees with a delta is a `BLOCKED:` report, not a fix. Do not restate watch-degradation. A
requirement may not promise more than the cited evidence already asserts.

## Evidence the report must contain

The three acceptance tails; the per-rule "requirement → evidence file:line → review method" table; and the
item-6 coverage check.
