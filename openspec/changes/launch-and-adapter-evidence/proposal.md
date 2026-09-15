## Why

Nine shipped launch-and-proof behaviours have no spec (E1's `D1–D4`, `A1–A2`,
`W1–W3`; scope accepted in D15, split in D18). They are the recent false-green clusters — a dispatch reported as
sent while nothing ran, a window reported as a running PM — so the specs must forbid exactly those lies.

## What Changes

- **BREAKING (spec shape, not behaviour)**: `dispatch`'s "The adapter template contract is enforced, not guessed" is
  **REMOVED** and migrated **unchanged** into the new `agent-adapters` capability — the engine is shared with the
  PM's own adapter, and a second copy of the placeholder list would drift.
- `dispatch` gains two requirements (`D3` launch proof, `D4` session-window guard) and two scenarios inside
  `MODIFIED` requirements restated in full: the brief must live inside the project (`D2`, F15), and a worktree parked
  on another task's branch is refused (`D1`, F16).
- new capability `agent-adapters`: the migrated engine, the first word resolved on the caller's `PATH`
  (`TEAM_AGENT_BIN` > the template's first word > `TEAM_PI_BIN`) on both sides, and the PM-side adapter
  (`TEAM_PM_CMD` / `TEAM_PM_BIN` / `{resume_args}`).
- new capability `pm-lifecycle`: PM liveness as positive proof (`W1`), the six states
  `running/starting/idle/unknown/foreign/missing` (`W2`; **no `busy`** — the shipped code has no such state), and
  `team reload`'s bookkeeping semantics (`W3`).
- No code changes: a backfill ships no behaviour. Every scenario names the smoke assertion that already goes red if
  its behaviour breaks (E1 §3.1 / E2 §5); the verify phase turns that into an injection matrix.

## Capabilities

### New Capabilities

- `agent-adapters`: the template engine on both sides — the placeholder contract and its rejection rules, the first
  word resolved on the caller's `PATH`, the PM's own three keys.
- `pm-lifecycle`: the PM as a process — liveness evidence, the `starting` state, and what a reload request does and
  does not do.

### Modified Capabilities

- `dispatch`: the engine requirement leaves for `agent-adapters`; `D1`/`D2` add scenarios; `D3`/`D4` are new
  requirements.

## Impact

At archive time: `dispatch` +2 requirements and −1 moved, plus `agent-adapters` and `pm-lifecycle` created. No
command, config key, test or reference file changes.

## Acceptance (verbatim)

```sh
openspec validate --all --strict
bash skills/teamsmith/tests/spec-lint.sh
```

Plus the archive must apply exactly the promised operations on a scratch copy:

```sh
cp -r openspec /tmp/c1-archive && cd /tmp/c1-archive && openspec archive -y launch-and-adapter-evidence
```

## Boundaries

- Only `openspec/changes/launch-and-adapter-evidence/**` and the report were written; `openspec/specs/**` is
  archive's job, and no code, test or ledger file was touched.
- Out of scope: a general `team up` / `team resume` contract, a `watchdog` delta, and every E1 row owned by
  C0/C2/C3.
- **Decision for the PM:** the byte-identical default Pi path is stated over an observable surface — `team up` in a
  fixture project, then the argv of the process recorded in `state/pm.pid` (falsifier: smoke §11b2 `①b`/`③`; the
  fast net stays §6i's render comparison). No internal function, no test-only string. If the PM rejects that
  surface, the requirement keeps only the custom-CLI half and the promise stays prose in
  `references/agent-adapters.md`.
