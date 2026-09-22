# roster-writer-and-route-truth · proposal

## Why

The tool prints a roster route that does not exist. On a fixture whose roster is `dev verify` (repro:
`docs/team/reports/P46/repro.sh`): the `TEAM_AGENTS` schema note and the `team config set TEAM_AGENTS` refusal
both name `team add-agent / team teardown`, but `team add-agent dev2` dies `未知 agent：dev2` (exit 1),
`team teardown` leaves the key byte-identical, and no CLI path writes it — only the `bootstrap` template renders
it. `team config set-agent-model dev2 …` repeats the dead route (exit 5), so an about-to-join seat cannot get its
model; `team help` prints `add-agent <a> [--model m]` while the parser answers `未知参数 --model` (exit 2); and
`teamsmith-init` promises `team add-agent <name>` "adds more at any time" — false today. A PM in the `do` project
hit this and correctly refused to patch the tool by hand: the tool must carry a real route, and the gate must catch
the next fake one before a field incident does.

## What Changes

- **ADDED — `dispatch`**: exactly one authorized roster entry — `team add-agent <a> --register` (and
  `team teardown --agent <a> --register`), written through the contract writer (token validation, fingerprint CAS,
  one audit line); without it the refusal names two routes that really work. `add-agent --model m` becomes real
  (the seat's configured model — the write `set-agent-model` already performs). `TEAM_AGENTS` keeps class `refuse`.
- **ADDED — `dispatch`**: a route-sincerity walk in the gate — every `--flag` `team help` prints is accepted by
  that command's own parser (measured: 62 printed flag claims over 41 distinct flags, one fake), every flag-printing command refuses an unknown
  flag (`version` and `meeting list` swallow it today), and every schema note naming a `team` command names one
  that exists and does what the sentence promises in a fixture.
- **MODIFIED — `memory-and-deps`**: the contract's one writer covers the roster entry, its CAS and its audit; the
  identity note stops promising a `team init` re-run that changes nothing (measured: `skip`); the roster value gets
  a seat-name rule.
- **MODIFIED — `init-skill`**: the roster bullet names the register flag instead of promising flagless growth.

## Capabilities

Modified: `dispatch` (two ADDED requirements), `memory-and-deps` (one MODIFIED), `init-skill` (one MODIFIED).

## Impact

`scripts/lib/{cmd-agents,cmd-config,cmd-project}.sh`; new `tests/routes.sh` plus one `smoke.sh` section;
`skills/teamsmith/{SKILL.md,references/{config,protocol,workflows,troubleshooting}.md}`; `skills/teamsmith-init/SKILL.md`.
Out of scope: the panel, a `--json` help dump, malformed hand-edited rosters beyond the register refusal, and
`team init --force`.
## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
bash skills/teamsmith/tests/routes.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/smoke.sh </dev/null
```

The last three need the apply commit; the first runs on this proposal.

## What flips

- **Roster**: today `team add-agent dev2` cannot grow the roster and the config refusal names a dead route; after
  the fix `--register` changes the line, audits it, and the flagless refusal names the flag.
- **Help and schema notes**: today a printed `[--model m]` answers `未知参数` and the identity note's `team init`
  re-run is a silent no-op; after the fix the printed flag writes the seat's model, and the walk goes red on a
  printed flag the parser refuses, on a command that swallows unknown flags, and on a named route that cannot do
  what its sentence promises.

## Evidence the report must carry

The four reproductions before/after; the register write's `diff`, audit line and stale-fingerprint conflict; the
flagless refusal's two routes; `bash -n` after a register write; `tests/routes.sh` green plus its flip outputs;
the gate tails.
