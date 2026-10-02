# dispatch-friction · proposal

## Why

Two users lost up to five dispatch round-trips each to four frictions (re-measured in
`docs/team/reports/P136-dev2/recon.log`):

1. A branch that **is this task's own** is refused for a slug difference (`task/P134-p134` vs
   `task/P134-p134-dispatch-friction-propo`); `--branch` is `未知参数`.
2. `change: panel（说明）` is refused with a first line that shows no legal form and states the wrong reason.
3. A `quota` death record leaves the next dispatch silent about it.
4. A corrected task costs **4 refusals across 5 attempts**.

No guard's judgement is wrong; the handover guesses the name, does not teach the syntax, and drips.

## What Changes

- **MODIFIED — `One task branch per task`**: `team task` writes the canonical `branch:` line into the brief;
  dispatch resolves `--branch <name>` (new, validated task-scoped) > that line > today's derivation, prints the
  name and source, and accepts another slug of this task's branch; another task's branch stays refused.
- **MODIFIED — `A brief names at most one change id` / `Two unfinished tasks … one delta file`**: a malformed
  `change:`/`deltas:` refusal leads with a legal example **and** the reason (comma is the separator, `·` is not),
  plus the exact replacement line.
- **ADDED — `A refused dispatch hands over every blocker, once, with a fix that runs`**: every pre-launch guard is
  judged in one pass before any window; one refusal lists each blocker with `修法：<command>` or
  `改行：<exact line>`; `--force` and its audits keep today's meaning.
- **MODIFIED — `The printed route is a route that works`**: the route walk also applies the refusal fixes and
  reddens when a fix stops clearing its blocker.
- **ADDED — `A dispatch warns before a seat that burned its last round`**: a `quota`/`balance` death record or an
  output-less previous round prints a visible non-blocking hint; missing evidence means silence.

## Capabilities

### Modified Capabilities
- `dispatch`: the five bullets above.

## Impact

`skills/teamsmith/scripts/lib/{common.sh,cmd-agents.sh,cmd-docs.sh}`, `templates/task.md.tmpl`,
`tests/{smoke.sh,routes.sh,section-budgets.tsv}`, `references/{protocol,troubleshooting}.md`, `SKILL.md`.
Untouched: guard judgements and `--force` (D16 · M6.3 · D24 · D36 · D40), the death vocabulary, tmux, `docs/team/**`
formats.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/routes.sh
```

## What flips

Branch: `task/P134-p134` is refused and `--branch` unknown today (measured) → accepted with the name and source
printed. Wording: no example and a wrong reason on the first line → example + reason. Retries: 4 refusals over 5
attempts → one refusal listing all, and a mutated fix reddens the walk. Hint: a `quota` record leaves the plan
silent (measured) → hint printed, exit code unchanged.

## Boundaries

Planning only: this task writes `openspec/changes/dispatch-friction/**` and its report. The apply needs the
brief's grant for `skills/**` and `tests/**`. Out of scope: loosening guards, unaudited bypasses, `docs/team/**`
formats, the death vocabulary, tmux.

## Evidence the report must contain

Propose: the validate tail, the delta→requirement map, the scenario inventory, the rulings and the recon log.
Apply: gate/FAST/walk tails, every flip's red and green tail, the one-pass refusal and the hint's silence
controls.
