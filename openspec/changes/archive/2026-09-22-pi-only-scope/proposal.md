# pi-only-scope · proposal

## Why

The contract promises more than the project has ever kept: `README.md:5` ("designed to adapt to any TUI
agent"), the daily `SKILL.md` description and its `## Agent adapters` heading, `references/agent-adapters.md`
("run workers (and the PM) with any TUI agent"), `references/config.md`, `references/migration.md`,
`templates/config.sh.tmpl` (an opencode example in every new contract) and `scripts/monitor.mjs`'s
degradation message — all resting on two probes (M3.0/M8.1), never a tested second harness. The user's call
(D35): promise **Pi only**; keep the seam (L2) as an internal frozen seam reserved for a future non-Pi
adapter; no code or Pi behaviour change; defer M3/M8.1/C1 rather than delete them. Evidence: design.md §1.

## What Changes

- **ADDED — `agent-adapters`**: Pi is the only supported harness; the seam is internal and frozen. The
  claimed surface (nine named files) MUST NOT claim another harness; every non-Pi mention carries the frozen
  wording; the seam stays writable and diagnosed `custom: …`; the built-in Pi commands stay byte-identical
  (M27 extension set included). The three existing requirements stay unmodified — the seam's
  verified mechanics.
- **ADDED — `init-skill`**: the questionnaire checks Pi's version (≥ 0.76.0) and the installed plugins
  `team doctor` reports; no harness question, no `omp` branch, no adapter keys. M26/M29's information-only
  plugin rule stays verbatim.
- **ADDED — `memory-and-deps`**: the four worker keys keep class `apply` and every behaviour; their schema
  row's free-text column and `references/config.md` carry the frozen marking, so `team config list --json`
  reports it on all four records.

## Capabilities

### Modified Capabilities

- `agent-adapters`: the promise is Pi; the seam is frozen and internal.
- `init-skill`: the questionnaire checks Pi's version and plugins, nothing else.
- `memory-and-deps`: the four worker keys are marked as an internal frozen seam.

## Impact

Docs, one schema column, one message string: `README.md`, `skills/teamsmith/SKILL.md`,
`skills/teamsmith-init/SKILL.md`, `references/{agent-adapters,config,migration,troubleshooting}.md`,
`templates/config.sh.tmpl`, `scripts/lib/cmd-config.sh` (four rows' free-text column + its header comment),
`scripts/monitor.mjs` (one sentence). Untouched: every code path, every test, the placeholder engine, the
writer, the built-in Pi commands, the keys' class and domains, the ROADMAP (the PM marks M3/M8.1/C1 deferred).

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
git status --porcelain
```

## What flips

Appending a banned phrase to a scratch `README.md` → red naming the line; removing it → green. Blanking one
adapter row's marking (`TEAM_CONFIG_TREE`) → red naming the key; restoring → green. Appending `omp` /
`TEAM_AGENT_CMD` to the init checklist → red. The built-in commands rendered on this tree and the pre-change
revision → byte-identical; §6i's recorded PM literal stays green.

## Boundaries

Planning only: this task writes `openspec/changes/pi-only-scope/**` and its report. Apply may touch only the
paths under Impact (PM-owned; needs an explicit grant) and must not touch `tests/**` (no test edit), the
writer, the placeholder engine, dispatch or any Pi behaviour. D35 conflicts go back to the PM as `BLOCKED:`.

## Evidence the report must contain

Both acceptance tails; the three delta→requirement maps; requirement→item and scenario→fixture maps; every
flip's red/green tail; the four-key class census; and the paths the diff touched.
