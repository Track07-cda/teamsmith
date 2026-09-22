## ADDED Requirements

### Requirement: The project-local install names Pi's trust consequence

When the install step leaves the project-local skills present under `<main worktree>/.pi/skills/` — installed by
this run, or already there and reported `skip` — the command SHALL print one line naming the consequence:
because `.pi/skills/` is a project resource Pi asks about, the first interactive `pi` run in this project shows a
project-trust prompt. The line SHALL name how to answer it — `pi --approve` for a single run, `/trust` in Pi to
save the decision, and `team init --no-skills` to skip the install — and it MUST NOT change the step's exit
status. It SHALL come from the one install implementation that both `team init` and `team bootstrap` call
(including bootstrap's existing-config upgrade path), and it MUST NOT be printed when nothing is installed
(`--no-skills`). The `teamsmith-init` skill's install beat and `references/bootstrap.md`'s project-skills row
SHALL carry the same fact: the triggering resource and the answers.

#### Scenario: A fresh init prints the consequence, --no-skills stays silent

- **GIVEN** two fresh git repositories with one commit
- **WHEN** `team init --session <s> --agents "dev" --vcs local --gates true` runs in the first, and the same
  command with `--no-skills` runs in the second
- **THEN** the first exits 0, its output carries one line containing `.pi/skills/`, `pi --approve` and `/trust`,
  and `.pi/skills/teamsmith` exists; the second exits 0, prints no such line, and has no `.pi/skills/`

#### Scenario: The rerun and the bootstrap upgrade path say it too

- **GIVEN** the first repository after one init (its entries exist, so the step reports `skip`), and a copy of it
  whose `.pi/team/config.sh` already exists
- **WHEN** the same `team init` runs a second time, and `team bootstrap --no-pulse --agents "dev"` runs in the copy
- **THEN** both exit 0 and both outputs carry the line — one implementation and one wording at both call points

#### Scenario: The documentation carries the fact

- **GIVEN** `skills/teamsmith-init/SKILL.md` and `skills/teamsmith-init/references/bootstrap.md`
- **WHEN** both are searched for `.pi/skills/`, `pi --approve` and `/trust`
- **THEN** both name the triggering resource and the answers, and a scratch copy with the note deleted fails the
  same search — the red side proving the check is not vacuous
