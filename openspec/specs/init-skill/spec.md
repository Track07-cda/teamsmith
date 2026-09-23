# init-skill Specification

## Purpose
New-project initialization guidance lives in its own `teamsmith-init` skill so the daily `teamsmith` skill stays
lean and each skill's description routes cleanly; this capability holds the split's invariants — one CLI, one
version source, an unchanged session-fingerprint scope, and zero changes for existing projects.
## Requirements
### Requirement: Initialization guidance lives in a dedicated teamsmith-init skill

The repository SHALL contain `skills/teamsmith-init/SKILL.md` (at most 100 lines) whose frontmatter names
`teamsmith-init`, and whose body is the new-project entry point in three beats: an ordered checklist of the
questions the PM must settle with the user (dependencies, session/roster, per-agent models, gates, VCS mode,
install command, ROADMAP/OWNERSHIP/AGENTS.md red lines), the instruction to run
`bash <teamsmith>/scripts/team bootstrap`, and a closing handoff sentence that points day-to-day operation at
the `teamsmith` skill. The init skill SHALL own exactly two files moved from the daily skill —
`references/bootstrap.md` and `templates/bootstrap-prompt.md.tmpl` — moved, not copied, and MUST NOT contain
`scripts/`, `extension/` or `tests/` directories, nor claim ownership of the pulse, dispatch, review or merge.

#### Scenario: The init skill exists, parses and stays small

- **WHEN** `test -f skills/teamsmith-init/SKILL.md`, `wc -l < skills/teamsmith-init/SKILL.md` and
  `bun skills/teamsmith/tests/skill-load.mjs skills/teamsmith-init` run
- **THEN** the file exists, the line count is at most 100, and the parser exits 0 with frontmatter
  `name: teamsmith-init`

#### Scenario: The body carries the three beats

- **WHEN** `skills/teamsmith-init/SKILL.md` is searched for the checklist, the bootstrap command and the handoff
- **THEN** it contains an ordered question checklist covering roster/models/gates/VCS, a line invoking
  `scripts/team bootstrap`, and a closing sentence naming `teamsmith` as the skill for day-to-day operation

#### Scenario: The two moved files have exactly one home

- **WHEN** `test -f skills/teamsmith-init/references/bootstrap.md`,
  `test -f skills/teamsmith-init/templates/bootstrap-prompt.md.tmpl`,
  `test ! -e skills/teamsmith/references/bootstrap.md` and
  `test ! -e skills/teamsmith/templates/bootstrap-prompt.md.tmpl` run
- **THEN** all four checks pass (present at the new home, absent at the old)

#### Scenario: The init skill carries no code

- **WHEN** `find skills/teamsmith-init -maxdepth 1 -type d` runs
- **THEN** no `scripts/`, `extension/` or `tests/` directory is listed

### Requirement: The daily skill no longer carries initialization guidance

`skills/teamsmith/SKILL.md` MUST NOT contain the `## New project` or `## 30-second start` sections, and SHALL
carry a pointer line sending new-project setup to the `teamsmith-init` skill. Its `description` MUST NOT contain
any of the three init phrases (`organize multiple agents into a team`,
`set up an agent collaboration protocol`, `bootstrap this skill into a new project`) and SHALL contain one clause
naming `teamsmith-init` for initialization. Stale links to the moved files MUST NOT remain: no reference to the
old in-skill paths `references/bootstrap.md` or `templates/bootstrap-prompt.md.tmpl` may survive under
`skills/teamsmith/` except inside `CHANGELOG.md` history entries.

#### Scenario: The two sections are gone and the pointer is there

- **WHEN** `grep -cE '^## (New project|30-second start)' skills/teamsmith/SKILL.md` and
  `grep -c 'teamsmith-init' skills/teamsmith/SKILL.md` run
- **THEN** the first prints `0` and the second prints at least `1`

#### Scenario: The daily description has no init phrases but names the init skill

- **WHEN** the `description` value of `skills/teamsmith/SKILL.md` is extracted and searched
- **THEN** none of the three init phrases is present, and the string `teamsmith-init` is present

#### Scenario: No stale links to the moved files

- **WHEN** `grep -rn 'references/bootstrap\.md\|templates/bootstrap-prompt\.md\.tmpl' skills/teamsmith/SKILL.md
  skills/teamsmith/references/ skills/teamsmith/templates/` runs
- **THEN** every remaining hit names the new cross-skill path (`../../teamsmith-init/…`), and
  `skills/teamsmith/SKILL.md` has no hit at all

### Requirement: Both descriptions route cleanly and both skills load

The two skills' `description` values SHALL be non-overlapping in routing vocabulary: the daily description
carries none of the init phrases (above), and the init description MUST NOT carry day-to-day operation phrases
(`dispatch tasks to worker agents`, `run the patrol`, `review an agent's work independently`). Each description
MUST stay within the 1024-character frontmatter limit, and each skill directory SHALL be loadable by Pi's own
skill parser.

#### Scenario: skill-load passes for both directories

- **WHEN** `bun skills/teamsmith/tests/skill-load.mjs skills/teamsmith` and
  `bun skills/teamsmith/tests/skill-load.mjs skills/teamsmith-init` run
- **THEN** both exit 0 and each prints its injected XML block

#### Scenario: No cross-contamination between the two descriptions

- **WHEN** both `description` values are extracted and searched
- **THEN** the daily one contains none of the three init phrases, the init one contains none of the three
  day-to-day phrases, and both lengths are at most 1024 characters

### Requirement: One CLI, one copy of every tool file

`scripts/`, `extension/` and `tests/` SHALL exist only under `skills/teamsmith/`; the `team` CLI is the single
entry point and its behavior is unchanged by the split — in particular `team bootstrap` stays a subcommand of
that same CLI, rendered templates stay anchored at the CLI's own location, and nothing under
`skills/teamsmith/scripts/` or `skills/teamsmith/extension/` references `teamsmith-init`.

#### Scenario: bootstrap still runs from the one CLI

- **WHEN** `bash skills/teamsmith/scripts/team bootstrap --print` runs in a fixture repository
- **THEN** it exits 0 and prints the plan (detect / config / docs skeleton / worktrees / pulse) exactly as before

#### Scenario: The tooling never references the init skill

- **WHEN** `grep -rn 'teamsmith-init' skills/teamsmith/scripts/ skills/teamsmith/extension/` and
  `grep -rn 'bootstrap-prompt' skills/teamsmith/scripts/` run
- **THEN** both print nothing and exit non-zero (no hits)

### Requirement: One version source, unchanged fingerprint scope

Both SKILL.md files' `metadata.version` SHALL equal `TEAM_VERSION` from `skills/teamsmith/scripts/lib/common.sh`
(the single version source), and the repository SHALL keep exactly one changelog at
`skills/teamsmith/CHANGELOG.md` whose top version equals `TEAM_VERSION` (the init skill has none). The session fingerprint `team_skill_hash` MUST keep
hashing exactly the daily `SKILL.md` and `extension/team-notify.ts`: a text change in `skills/teamsmith-init/`
MUST NOT change the fingerprint, so init edits never wake running PM sessions (why the fingerprint exists and
what a stale session does about it: `references/memory.md`, the skill-version-state rows).

#### Scenario: Four version strings are equal, one changelog exists

- **WHEN** `TEAM_VERSION` is read from `common.sh`, `metadata.version` from both SKILL.md files, the top
  version from `skills/teamsmith/CHANGELOG.md`, and `test ! -e skills/teamsmith-init/CHANGELOG.md` runs
- **THEN** all four version strings are equal and the init skill has no changelog

#### Scenario: Init-skill edits leave the fingerprint unchanged

- **GIVEN** a fixture copy of the two skill directories with the libraries sourced
- **WHEN** `team_skill_hash` is computed, a line is appended to the fixture's init SKILL.md, and the hash is
  recomputed
- **THEN** the two hashes are equal — and appending to the fixture's daily SKILL.md does change the hash
  (the flip proving the assertion is not vacuous)

### Requirement: Existing projects and running sessions see zero change

A project bootstrapped before this change MUST NOT need any edit: no new required key appears in
`templates/config.sh.tmpl`, the injected `AGENTS.md` protocol section template is unchanged, and rendered PM/agent
launch commands keep `--skill` pointed at the daily skill directory with no reference to `teamsmith-init`.

#### Scenario: Templates gain no init-skill dependency

- **WHEN** `grep -rn 'teamsmith-init' skills/teamsmith/templates/config.sh.tmpl
  skills/teamsmith/templates/AGENTS.section.md.tmpl skills/teamsmith/templates/pm-prompt.md.tmpl` runs
- **THEN** it prints nothing and exits non-zero (no hits)

#### Scenario: The rendered launch command is unchanged in shape

- **GIVEN** a fixture project with a configured agent
- **WHEN** `team dispatch <agent> <ID> <taskfile> --print` renders the launch command
- **THEN** the command contains `--skill` followed by the `skills/teamsmith` directory and does not contain the
  string `teamsmith-init`

### Requirement: The new-project questionnaire checks Pi's version and its plugins, and asks nothing about adapters

The `teamsmith-init` skill's checklist SHALL keep its detection surface to the two facts the project actually
promises: the Pi version floor (`README.md`'s requirement — Pi ≥ 0.76.0, the `--session-id` floor
`team doctor` fails on) and the plugins `team doctor` reports (`已装插件 packages`). It MUST NOT ask which
harness the user's sessions run, MUST NOT name or branch on another harness (`omp`, "another CLI"), and MUST
NOT mention the four adapter keys (`TEAM_AGENT_CMD`, `TEAM_AGENT_NOTIFY_CMD`, `TEAM_AGENT_LOG_GLOB`,
`TEAM_AGENT_BIN`) or send the reader to `references/agent-adapters.md`. The doctor rows behind the two facts
SHALL keep their behaviour: the `pi` row judges the floor by `--session-id` (a probe whose `--help` goes to
stderr, as Pi 0.76.0–0.79.0 did, still passes), and the plugin row only reports what is installed — it never
asks the user to install a third-party plugin and recommends only what teamsmith requires or ships itself.
Only questionnaire text changes: no rendered template, config key, default or command output moves, and no
existing project needs an edit.

#### Scenario: The checklist is Pi-only

- **WHEN** `skills/teamsmith-init/SKILL.md` is searched for a harness question and for the seam
  (`which harness`, `\bomp\b`, `another CLI`, `TEAM_AGENT_CMD`, `TEAM_AGENT_BIN`, `TEAM_AGENT_NOTIFY_CMD`,
  `TEAM_AGENT_LOG_GLOB`, `agent-adapters.md`)
- **THEN** the search prints nothing, while the same file names `team doctor`, the Pi floor (Pi ≥ 0.76.0) and
  the `已装插件 packages` row it prescribes
- **AND** the fixture's red side — a scratch copy with `omp` or `TEAM_AGENT_CMD` appended to the checklist —
  makes the same search print that line and exit non-zero

#### Scenario: The two doctor rows still answer the check

- **GIVEN** a stub `TEAM_PI_BIN` whose `--help` carries `--session-id` on stdout, a second stub whose
  `--help` writes to stderr (the 0.76.0–0.79.0 shape), a third stub without `--session-id`, and settings
  files naming two installed packages
- **WHEN** `team doctor` runs against each stub and against a settings file without packages
- **THEN** the first two runs pass the `pi` row, the third fails naming the missing flag, and the plugin row
  lists the installed packages (or says none were detected) without naming any third-party package to install
- **AND** the existing gate sections §15b (Pi-version probes) and §15c (harness and plugin list: inform only,
  never recommend) stay green without a test edit

#### Scenario: No rendered contract and no existing project moves

- **GIVEN** a fixture project
- **WHEN** `team bootstrap --print` runs and a rendered `.pi/team/config.sh` is compared with the previous
  revision's rendering
- **THEN** the plan still lists its five stages, the four `TEAM_AGENT_*` keys are still rendered empty, no new
  key appears, and the `config-cli.sh` completeness walk (schema ↔ template ↔ `references/config.md`) stays
  green without a test edit

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

