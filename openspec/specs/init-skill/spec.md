# init-skill Specification

## Purpose
New-project initialization guidance lives in its own `teamsmith-init` skill so the daily `teamsmith` skill stays
lean and each skill's description routes cleanly; this capability holds the split's invariants — one CLI, one
version source, an unchanged session-fingerprint scope, and zero changes for existing projects.
## Requirements
### Requirement: Initialization guidance lives in a dedicated teamsmith-init skill

The repository SHALL contain `skills/teamsmith-init/SKILL.md` (at most 100 lines) whose frontmatter names
`teamsmith-init`, and whose body begins with the **installation beat** — install the CLI
(`npm install -g teamsmith`) and run `team init` in the project, which installs the skills into the project's
`.pi/skills/` (the "team init installs the project skills" requirement below) — and then continues the
new-project entry point in three beats: an ordered checklist of the questions the PM must settle with the user
(dependencies, session/roster, project category mapping and independent PM model, gates, VCS mode, install command, ROADMAP/OWNERSHIP/AGENTS.md
red lines), the instruction to run `bash <teamsmith>/scripts/team bootstrap`, and a closing handoff sentence
that points day-to-day operation at the `teamsmith` skill. The installation beat SHALL name the npm command and
`team init` before it names `team bootstrap`, SHALL name the project target `.pi/skills/`, and SHALL keep the
two alternative routes on the same page with what each is for — the Pi package install (`pi install …`, which
needs no global CLI) and `./install.sh` (a checkout, or a `~/.agents/skills` layout). The init skill SHALL own
exactly two files moved from the daily skill — `references/bootstrap.md` and
`templates/bootstrap-prompt.md.tmpl` — moved, not copied, and MUST NOT contain `scripts/`, `extension/` or
`tests/` directories, nor claim ownership of the pulse, dispatch, review or merge.

The checklist's roster bullet SHALL name the route that really changes the roster: `team add-agent <name>
--register` to grow it and `team teardown --agent <name> --register` to shrink it, each write audited. It MUST NOT
promise that a bare `team add-agent <name>` changes the roster — that command refuses a seat the roster does not
carry — and its claim SHALL stay true for the tree that ships it (the command it names is the one the route walk
of `dispatch` proves works in a fixture).

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

#### Scenario: The installation beat comes first, on every installation-facing surface

- **GIVEN** the line number of the first `npm install -g teamsmith` hit, of the first `team init` hit and of the
  first `team bootstrap` hit in `skills/teamsmith-init/SKILL.md`
- **WHEN** the install beat is compared with the beats after it, and the same routes are searched on the other
  surfaces
- **THEN** the npm line and the `team init` line are both above the `team bootstrap` line, the body names
  `.pi/skills/`, and the body still carries both alternatives (`pi install` and `install.sh`)
- **AND** README §Install names the npm route above the two alternative routes, `team help`'s `init` line names
  `.pi/skills`, `--copy` and `--no-skills`, and the daily skill's command table row for `init` names the project
  skill install

#### Scenario: The roster sentence names the register route

- **WHEN** the roster bullet of `skills/teamsmith-init/SKILL.md` is read and searched for `team add-agent` and
  `--register`
- **THEN** the bullet names `team add-agent <name> --register` (and `team teardown --agent <name> --register`),
  says the write is audited, and no sentence in the file promises that a bare `team add-agent <name>` changes the
  roster
- **AND** the pre-change sentence is the red side of this check: it read "`team add-agent <name>` adds more at any
  time", which the measured tool refused with `未知 agent` when the seat was not in the roster

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

Private non-deployed source development SHALL NOT rewrite existing project configuration, ledger, skill links/copies or running processes. This routing upgrade is explicitly breaking: a project still carrying the retired worker keys is migrated by the startup transaction or the dedicated `config upgrade-models` transaction; `init --force` and bootstrap are not model-migration shortcuts. A shared skill link reads its target's current bytes: changing that source can affect the next CLI/skill read without invoking an installer or restarting an already-running process. Guidance SHALL not claim zero shared impact merely from avoiding installers. Before product changes reach a shared source/main, the separately authorized source-isolation or explicitly approved shared-impact adoption gate specified below must be satisfied. Launch commands SHALL still use the daily skill directory and never an init-skill runtime dependency.

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
The questionnaire SHALL ask for an explicit category mapping and independent PM model; rendering is covered by the task-policy initialization requirement. This does not change the Pi-version/plugin checks or advertise the adapter seam.

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
  never recommend) retain the same floor/stdout/stderr/report-only assertions and adversarial controls; fixtures may adopt valid new model configuration/assignment inputs, but no safety assertion may be weakened, deleted or skipped

#### Scenario: No rendered contract and no existing project moves

- **GIVEN** a fixture project
- **WHEN** `team bootstrap --print` runs and a rendered `.pi/team/config.sh` is compared with the previous
  revision's rendering
- **THEN** the plan still lists its five stages, the four `TEAM_AGENT_*` keys are still rendered empty, the new task mapping and required PM key appear and retired worker keys do not; the updated `config-cli.sh` completeness walk (schema ↔ template ↔ `references/config.md`) stays green

### Requirement: The project-local install names Pi's trust consequence

When the install step leaves the project-local entries present under `<main worktree>/.pi/skills/` and
`<main worktree>/.pi/extensions/` — installed by this run, or already there and reported `skip` — the command
SHALL print one line naming the consequence: because `.pi/skills/` and `.pi/extensions/` are project resources Pi
asks about, the first interactive `pi` run in this project shows a project-trust prompt. The line SHALL name how to answer it — `pi --approve` for a single run, `/trust` in Pi to
save the decision, and `team init --no-skills` to skip the install — and it MUST NOT change the step's exit
status. It SHALL come from the one install implementation that both `team init` and `team bootstrap` call
(including bootstrap's existing-config upgrade path), and it MUST NOT be printed when nothing is installed
(`--no-skills`). The `teamsmith-init` skill's install beat and `references/bootstrap.md`'s project-skills row
SHALL carry the same fact: the triggering resource and the answers.

#### Scenario: A fresh init prints the consequence, --no-skills stays silent

- **GIVEN** two fresh git repositories with one commit
- **WHEN** `team init --session <s> --agents "dev" --vcs local --gates true --task-models 'routine=vendor/light' --pm-model vendor/strong` runs in the first, and the same
  command with `--no-skills` runs in the second
- **THEN** the first exits 0, its output carries one line containing `.pi/skills/`, `.pi/extensions/`,
  `pi --approve` and `/trust`, and both `.pi/skills/teamsmith` and `.pi/extensions/team.ts` exist; the second
  exits 0, prints no such line, and has neither `.pi/skills/` nor `.pi/extensions/`

#### Scenario: The rerun and the bootstrap upgrade path say it too

- **GIVEN** the first repository after one init (its entries exist, so the step reports `skip`), and a copy of it
  whose valid new-policy `.pi/team/config.sh` already exists
- **WHEN** the same `team init` runs a second time, and `team bootstrap --no-pulse --agents "dev"` runs in the copy
- **THEN** both exit 0 and both outputs carry the line — one implementation and one wording at both call points

#### Scenario: The documentation carries the fact

- **GIVEN** `skills/teamsmith-init/SKILL.md` and `skills/teamsmith-init/references/bootstrap.md`
- **WHEN** both are searched for `.pi/skills/`, `.pi/extensions/`, `pi --approve` and `/trust`
- **THEN** both name the triggering resources and the answers, and a scratch copy with the note deleted fails the
  same search — the red side proving the check is not vacuous

### Requirement: team init installs the project skills

`team init` SHALL install this repository's two skills into the project it initialises, in the same run and
without a second command, and SHALL install this repository's `/team` extension with them. The target
directories SHALL be `<main worktree>/.pi/skills/` — Pi's project-level skill search path — and
`<main worktree>/.pi/extensions/` with the entry `team.ts` — Pi's project-level extension search path — so init
run inside a linked worktree still installs for the project. Each skill SHALL land as its own entry
(`teamsmith`, and `teamsmith-init` when the installation carries it), and the source SHALL be the running CLI's
own skill directories (`$TEAM_SKILL_DIR`, and its sibling `teamsmith-init`) — never a sweep of every directory
under `skills/` — so an installation that carries only one of the two installs only that one and says so. The
extension's source SHALL be the running CLI's own `extension/team.ts`; it MUST NOT be a second, independently
maintained copy of that file.

- **Modes**: the default is a symlink to the source (one copy of the code; package updates are live);
  `--copy` copies the files instead, excluding `.git/` and `node_modules/` and nothing else (for an ephemeral
  source such as an `npx` cache); `--no-skills` skips this step entirely and says that it skipped. The `/team`
  extension follows the same mode in the same run: a symlink to the source by default, a copy under `--copy`, and
  skipped with the rest under `--no-skills`.
- **Idempotence**: repeating `team init` MUST NOT install twice and MUST NOT overwrite: an entry that already
  resolves to the same source (link), or whose bytes equal the source (copy), SHALL be reported as skipped and
  the run SHALL still exit 0. This holds for the extension entry as for a skill: a symlink to its source, or a
  regular file whose bytes equal the source's, is skipped, not reinstalled.
- **Conflicts**: an entry that exists and is not this source SHALL NOT be replaced silently. The run SHALL name
  the path, what it found and the routes (`team init --force` to replace it, remove it by hand, or `--no-skills`
  to skip), and SHALL exit non-zero; the entry's bytes SHALL be unchanged. `--force` SHALL replace an entry that
  is a symlink, or a directory carrying a `SKILL.md` whose frontmatter `name` is that skill; a directory that is
  not recognisable as that skill MUST NOT be deleted even with `--force` (the run exits non-zero and names the
  manual route). For the extension entry, `--force` SHALL replace an entry that is a symlink or a regular file
  carrying the source's marker line, and a regular file that does not carry it MUST NOT be deleted even with
  `--force` (the run exits non-zero and names the manual route).
- **`.gitignore`**: each install directory (`.pi/skills/`, `.pi/extensions/`) SHALL be added to the project's
  teamsmith block, once (an absolute symlink must not be committed, and a copy is re-creatable).
- **`bootstrap`**: `team bootstrap` SHALL perform this same step through the same code path for fresh or valid-new-policy projects with or without `.pi/team/config.sh`; legacy model configuration SHALL refuse before this step and name the dedicated model upgrade route, not a bootstrap migration —
  and `bootstrap --print` SHALL name the step in its plan and write nothing. There MUST NOT be a second install
  semantics beside this one.
- The step SHALL print one line per installed entry — each skill and the extension
  (`link <dest> → <src>` / `copy <dest>` / `skip <dest>`) — so the result is auditable from the command's own
  output.

#### Scenario: The default install links both skills into the project

- **GIVEN** a fresh git repository with one commit, and a `team` CLI running from this tree
- **WHEN** `team init --session <s> --agents "dev verify" --vcs local --gates true --task-models 'routine=vendor/light' --pm-model vendor/strong` runs in it
- **THEN** it exits 0, `.pi/skills/teamsmith` and `.pi/skills/teamsmith-init` are symlinks whose resolved
  targets are `$TEAM_SKILL_DIR` and its sibling, `.pi/extensions/team.ts` is a symlink to that skill's
  `extension/team.ts`, the output names all three with `link`, and `.gitignore` carries `.pi/skills/` and
  `.pi/extensions/`
- **AND** running the same init from a linked worktree of that repository puts the entries in the main
  worktree's `.pi/skills/` and `.pi/extensions/`, not in the worktree's

#### Scenario: A second init skips instead of installing again or overwriting

- **GIVEN** the same repository after one init, with the two entries' targets and the copy's content hash
  recorded
- **WHEN** `team init …` runs a second time, and again with `--copy` against the existing links
- **THEN** the first run exits 0 and its output names both skills and the extension with `skip`, the recorded
  targets/hashes are unchanged, `.pi/skills/` holds no third entry, and `.pi/extensions/` holds only `team.ts`

#### Scenario: --no-skills skips the step; --copy copies the files without the build directory

- **GIVEN** two fresh repositories and valid explicit `--task-models 'routine=vendor/light' --pm-model vendor/strong` inputs for each init
- **WHEN** `team init … --no-skills` runs in the first, and `team init … --copy` runs in the second
- **THEN** the first has no `.pi/skills/` and no `.pi/extensions/` directory at all and its output says the step
  was skipped, while the second has real directories whose `SKILL.md` bytes equal the source's, whose
  `scripts/team` exists, and an `.pi/extensions/team.ts` whose bytes equal the source extension's
- **AND** the second has no `scripts/panel/node_modules` and no `.git` inside either entry

#### Scenario: A conflicting entry is announced, and --force replaces only what it recognises

- **GIVEN** valid explicit task mapping/PM init inputs and a fresh repository whose `.pi/skills/teamsmith` is first a directory without a `SKILL.md`, and then
  (a second fixture) a directory carrying a hand-edited `SKILL.md` that names `teamsmith`
- **WHEN** `team init …` runs against each, and then each with `--force`
- **THEN** the runs without `--force` exit non-zero, name the path and the two routes, and leave the directory's
  bytes unchanged (hash before = hash after) — including the unrecognisable one, which `--force` still refuses
  and still leaves untouched
- **AND** against the hand-edited copy, `--force` replaces it with the source's (the `SKILL.md` bytes equal the
  source's afterwards)
- **AND** the same two runs against a `.pi/extensions/team.ts` that is first a hand-written file without the
  source's marker and then (a second fixture) a copy carrying it: the unmarked file is refused by `--force` too
  and its bytes are unchanged, while the marked copy is replaced by the source's bytes

#### Scenario: bootstrap runs the install step on an existing project too, and --print writes nothing

- **GIVEN** an existing repository with valid new model policy — `.pi/team/config.sh` present, no `.pi/skills/` — and a
  copy of its `.pi` directory's hash taken before the run
- **WHEN** `team bootstrap --agents dev` runs in it, and then, in a second fixture, `team bootstrap --print` runs
- **THEN** the first run installs the two skills and the extension entry and exits 0 without rewriting the
  existing config
- **AND** the second run names the install step in its printed plan, creates no `.pi/skills/` or
  `.pi/extensions/` entry and leaves every file it printed about unchanged

### Requirement: The CLI ships as one npm bin entry and the package carries what it runs

`package.json` SHALL declare exactly one `bin` entry, `team`, pointing at `bin/team.mjs` — a Node ESM file with
the `#!/usr/bin/env node` shebang — and the package's `files` whitelist SHALL carry `bin/` next to `skills/` and
`install.sh`, so `npm pack` ships the entry together with both skills and `install.sh`. The wrapper SHALL be a
transparent entry point: it runs the bash CLI (`skills/teamsmith/scripts/team`) with the caller's argv, stdio and
environment and exits with the CLI's own status (a signal is reported as `128 + signo`), so `team help`,
`team version` and a failing subcommand are byte- and exit-code-identical to invoking the bash CLI directly —
including through the shim npm generates in a global prefix. The wrapper MUST NOT implement, wrap or reinterpret
any subcommand.

#### Scenario: The packed tarball carries the entry and the two skills, and nothing of the ledger

- **WHEN** `npm pack --dry-run --json` runs from the repository root and its file list is walked
- **THEN** it lists `bin/team.mjs`, both `SKILL.md` files and `install.sh`
- **AND** it lists no path under `docs/team/`, `.pi/`, `openspec/` or `node_modules/`
- **AND** removing `bin/` from `files` makes the walk red, naming the missing `bin/team.mjs`

#### Scenario: The entry is the wrapper, and it is transparent through npm's own shim

- **GIVEN** the tarball from the walk above and a private npm prefix
- **WHEN** `node bin/team.mjs version`, `node bin/team.mjs help` and an unknown subcommand run, and then
  `npm install -g --prefix <T> ./teamsmith-<version>.tgz` is followed by `<T>/bin/team version` and
  `<T>/bin/team help`
- **THEN** the two `version` invocations print the same `teamsmith <version>` line as
  `bash skills/teamsmith/scripts/team version`, the two `help` outputs are byte-identical to the bash CLI's, and
  the unknown subcommand exits with the CLI's own exit code (2)
- **AND** `package.json`'s `bin` object has exactly one key, `team`, whose value is `bin/team.mjs`

### Requirement: The project-local install is visible in team doctor, and repairable with team init

`team doctor` SHALL report the project-local teamsmith install when the project has one, and MUST stay silent
when it has none (a project using the Pi package, a `~/.agents/skills` link or a settings `skills` entry must not
be nagged). The row SHALL name what is installed: an entry that is a symlink to the running skill directory, or
a directory whose `SKILL.md` version equals the running CLI's, SHALL be informational (doctor's exit code
unchanged); an entry that is a copy from another version, a symlink to another source, or carries no readable
`SKILL.md` SHALL be a warning naming the found version or target and the one-line repair (`team init --force`),
and SHALL NOT by itself make doctor exit non-zero. The same run SHALL report the `/team` extension whenever the
project has a project-local install: `.pi/extensions/team.ts` as a symlink to the running skill's
`extension/team.ts`, or as a file whose bytes equal that source's, is informational; a missing entry is a warning
naming the path and the repair `team init`; a symlink elsewhere or a file whose bytes differ from the running
skill's is a warning naming what was found and the repair `team init --force`. When the project has no
project-local install, neither row is printed.

#### Scenario: A linked install is named, and no install is silent

- **GIVEN** one fixture repository initialised by `team init`, and a second left without `.pi/skills/`
- **WHEN** `team doctor` runs in each
- **THEN** the first prints a row naming `.pi/skills/teamsmith` and its link and a row naming
  `.pi/extensions/team.ts` and its link, exits 0 and warns about nothing
- **AND** the second prints no teamsmith-install row and exits 0

#### Scenario: A copy from another version is warned with its repair

- **GIVEN** a fixture whose `.pi/skills/teamsmith` is a copy of the skill with `SKILL.md`'s
  `metadata.version` edited to a different value
- **WHEN** `team doctor` runs, and then `team init --force` runs and `team doctor` runs again
- **THEN** the first run prints a warning naming the found version and `team init --force` and exits 0
- **AND** the second run's row names the running version and warns about nothing

#### Scenario: An entry pointing elsewhere is warned, and --force repairs it

- **GIVEN** a fixture whose `.pi/skills/teamsmith` is a symlink into another directory
- **WHEN** `team doctor` runs, then `team init --force` runs, then `team doctor` runs again
- **THEN** the first run warns naming both paths and the repair, and exits 0
- **AND** the second run repoints the entry at the running skill directory (the resolved target equals
  `$TEAM_SKILL_DIR`), and the third run warns about nothing

#### Scenario: The extension entry's absence and drift are warned with a repair that runs

- **GIVEN** a fixture repository initialised by `team init` whose `.pi/extensions/team.ts` is first removed, and
  then (a second fixture) a copy of it with one line edited
- **WHEN** `team doctor` runs in each, and then `team init` (the first) and `team init --force` (the second) run
  and `team doctor` runs again
- **THEN** the first run prints a warning naming the missing `.pi/extensions/team.ts` and the repair `team init`
  and exits 0
- **AND** the second fixture's first run warns naming the drifted copy and the repair `team init --force`, and
  after that run its row warns about nothing (the file's bytes equal the source's)

### Requirement: Initialization teaches category policy and breaking upgrades without live adoption

Fresh init/bootstrap SHALL accept `--task-models '<map>' --pm-model '<model>'` and render exactly those validated values; missing explicit model inputs refuse before config/ledger/install/worktree/pulse writes. Existing valid new-policy projects may be re-entered without supplying those inputs again and SHALL keep their policy; any explicit re-render that requires new values SHALL validate explicit inputs before replacement. Retired `--default-model` is removed with a correction. Config templates SHALL declare task map/independent PM, never retired worker keys; init/bootstrap install/protocol/ownership/task/PM/memory guidance SHALL describe task category rather than a permanent seat model. `team task --category` is the brief generator only; it is not a dispatch override. Ownership stays about files/roles, not model strength. The initial two-model example is routine=opencode-go/deepseek-v4.1-flash and analysis/verify=openai-codex/gpt-6.1-sol:high, independent PM=openai-codex/gpt-6.1-sol:high; examples are not engine defaults or a provider availability claim.

PM guidance SHALL recommend routine for bounded ordinary implementation, analysis for complex planning/judgment and verify for independent adversarial review, record category rationale in brief prose and choose configured names in other projects. Tools do not infer difficulty or phase/category equivalence. Worker guidance SHALL preserve scope, reports and disk handover through fresh takeover; independent verification cannot be waived by a strong model. An existing project's retired model keys SHALL be migrated by the mechanical startup transaction the next requirement defines, or by the explicit `team config upgrade-models` transaction; `init --force` and bootstrap MUST NOT migrate them, and legacy bootstrap refuses before install or other effects naming both routes. Auto-inference MUST NOT invent a model value or a category's meaning beyond that declared table. A write path that refuses a project for carrying the retired keys SHALL print the repair advice derived from that project's own configuration — once per run, above unrelated blockers — and SHALL print a paste-ready command only when the derivation is unambiguous. Private source verification, protected-branch source landing, project configuration/fresh-launch activation and shared-source adoption SHALL be distinct recorded gates. S1→S2→S3 dependencies and shared-file handoffs SHALL use a private non-deployed integration tree that is not a target of global/project-live skill links or live CLI source paths; it is not the shared main checkout. Partial implementation SHALL NOT reach shared source/main before a separately approved safe adoption plan. Private review/handoff is not protected-branch delivery and SHALL NOT mark apply tasks done merely because they are integrated privately. Before full validated source reaches shared main, PM SHALL either obtain per-operation user authorization to isolate known shared consumers to preserved stable source and verify that isolation, or obtain explicit approval of the identified shared-source impact, including later reads by unmigrated projects. No automatic scanning/deployment system is required, and unknown consumers cannot be promised unaffected. This change does not execute link changes/installers or other-project adoption. Source changes still SHALL NOT silently rewrite live config, ledgers or running processes; project config migration, fresh launches, shared-source adoption and any other-project work each require their separate existing authorization.

#### Scenario: Fresh initialization has explicit model inputs and no retired keys
- **WHEN** scratch init and fresh bootstrap run with valid task map and PM model, then with missing/invalid inputs and retired --default-model
- **THEN** valid rendering carries only new model policy and the existing identity/layout; invalid calls refuse before any skeleton/install/pulse effect and give new input routes

#### Scenario: Legacy bootstrap is not an implicit migration
- **WHEN** bootstrap runs on legacy config even with force, or bootstrap --print previews it
- **THEN** it diagnoses upgrade before writes/install/worktree/pulse; print remains read-only; the named migration routes are the startup transaction (`team up`, which migrates the mechanical shape) and the dedicated explicit config upgrade, never init --force

#### Scenario: The legacy refusal carries a command derived from the project's own configuration
- **GIVEN** a legacy configuration the derivation can locate, met by a write path that is not `team up` (`team dispatch … --print`, `team config set`, `team init`)
- **WHEN** each command refuses the project
- **THEN** the output carries one pastable `team config upgrade-models --task-models '…' --pm-model '…'` command whose category pairs are exactly the retired keys' pairs (fallback included), printed once per run and above the unrelated blockers, and pasting it with `--dry-run` in that project exits 0
- **AND** a shape the derivation cannot locate falls back to the placeholder route and names the obstacle instead of printing a command

#### Scenario: Templates and guidance change without touching history
- **WHEN** completeness/guidance fixtures inspect config/task/ownership/PM/protocol/bootstrap/memory templates and both skills/references
- **THEN** no active worker default/seat policy remains, category/independent PM and original-vs-recovery guidance appear, historical reports/changelog examples are not rewritten and independence/authorization boundaries remain

#### Scenario: Private slice integration leaves shared source unchanged
- **GIVEN** scratch global/project skill links pointing at a preserved main source, and an unlinked private integration tree
- **WHEN** S1 is privately integrated and handed off to S2/S3 for tests and independent verification
- **THEN** shared source/link/consumer configuration hashes remain unchanged, no live installer/restart/other-project action occurs, and handoff evidence records the private commit and released paths while apply tasks remain unfinished until authorized protected-branch delivery

#### Scenario: A source-target change is shared adoption even without an installer
- **GIVEN** fixture skills linked to a source main, as opposed to an unlinked private clone
- **WHEN** rollout guidance and ownership/acceptance evidence are checked
- **THEN** they identify changing that target as affecting later shared reads, prohibit premature partial-main landing, and require either separately authorized and verified stable-source isolation or explicit approval of the identified shared impact before full validated source landing
- **AND** approval of private source tests or this project's config transaction alone does not authorize that shared-source change, link replacement, installation, process restart or another project's adoption; no zero-impact guarantee is made for unknown consumers

#### Scenario: Model-use guidance is not an engine classifier
- **WHEN** a project defines maintenance and audit instead of the initial labels
- **THEN** guidance directs PM to choose configured names and state rationale, the CLI accepts mapped legal names and phase/seat never automatically picks a model

### Requirement: Retired model keys migrate on the startup path with their values unchanged

`team up` SHALL migrate a project whose configuration still carries the retired worker keys (`TEAM_AGENT_MODELS`,
`TEAM_DEFAULT_MODEL`) before it guards the launch identity, before it builds the tmux site and before it starts the
PM: it SHALL print the plan, write a timestamped backup of the configuration under the project's runtime state
directory, commit the migration through the same checked writer the explicit transaction uses (temporary file,
`bash -n`, fingerprint compare-and-swap, atomic rename, one audit line), print the result, and then continue the
same startup against the migrated file — re-entering itself so that every later guard reads the new bytes. No
model value SHALL change: every model string held by the retired keys SHALL appear byte-identical in the project's
new task map or PM model, and the run SHALL print the pairs before → after with the values visible, the backup
path and the command that restores it.

The derivation is a declared table, not a guess. Each `TEAM_AGENT_MODELS` `<seat>=<model>` becomes a category named
after that seat, normalized to `[a-z][a-z0-9-]*` (lower-cased, other characters folded to `-`, a leading
non-letter removed, printed with both spellings when normalization changed it); `TEAM_DEFAULT_MODEL` becomes the
category `default`; `TEAM_PM_MODEL` carries over unchanged, and when that key is absent or empty the value of
`TEAM_DEFAULT_MODEL` SHALL be used and the run SHALL say so. A configuration carrying a retired key next to a
contradicting new value SHALL be refused.

The migration SHALL fail closed — no configuration byte, no backup, no audit line — on every shape it cannot
locate: a relevant line that is not a top-level single-line literal, a duplicate key, an expanding value, a model
value that is not a valid model, a category name that cannot be normalized, a normalized category colliding with
another, the fallback name `default` colliding with a seat-derived category, a retired key present in the
environment instead of the file (whose route is `unset`), or a configuration shape newer than this tool knows. A
refusal SHALL name the file and the exact obstacle; when the derivation itself is unambiguous it SHALL also print
one paste-ready `team config upgrade-models --task-models '<derived map>' --pm-model '<derived model>'` command,
and when it is not, it SHALL print no such command.

Detection SHALL be a version table with one row per migration — the shape it matches, the transform it applies,
the version that introduced it — applied in order and idempotently. A freshly initialised project SHALL carry the
current shape number (`TEAM_CONFIG_VERSION`) and a migration SHALL write it; a configuration without that key
SHALL be classified by its keys; a shape number higher than the newest known one SHALL be refused rather than
migrated with an older row.

`team up --print` SHALL write nothing (no configuration byte, no backup, no audit line, no cache) and SHALL print
the same prediction — the pairs it would write and the backup path it would use — exiting zero when the migration
is available or not needed, and refusing when it is not. `team up --no-migrate` SHALL write nothing and refuse,
naming the manual transaction; against an already-current configuration it is a no-op. When a migration ran and a
later step of the same startup fails, the run SHALL name the backup path and the restore command alongside that
failure. `init` and `bootstrap` SHALL NOT migrate: they keep refusing a retired-config project, naming the startup
route next to the manual one.

#### Scenario: An old project migrates on the next start, values unchanged

- **GIVEN** a fixture project whose configuration carries `TEAM_AGENT_MODELS='dev=vendor/light verify=vendor/strong:high'`, `TEAM_DEFAULT_MODEL=vendor/base` and no new-policy keys
- **WHEN** `team up` runs in it
- **THEN** it exits 0, the resulting configuration lists the pairs `dev=vendor/light`, `verify=vendor/strong:high` (retired keys gone) plus the fallback pair, byte-identical to the old values, the run prints each pair before → after, the backup path and the restore command, `team config list` exits 0 afterwards, and `team dispatch <agent> <ID> <brief> --print` renders the fallback model for a brief whose `category:` is the fallback name

#### Scenario: A shape that cannot be located is refused with zero bytes written

- **GIVEN** configurations whose relevant line is not a top-level single-line literal (a duplicate key, an expanding value, a key set through an exported environment variable) and a configuration whose seat-derived category normalizes onto the fallback name
- **WHEN** `team up` runs against each
- **THEN** each run exits non-zero, the configuration file's hash is unchanged, no backup and no audit line was added, and the output names the file plus the exact obstacle (the line and its shape) or the colliding fallback name

#### Scenario: The preview predicts, and --no-migrate returns to the manual route

- **GIVEN** the old-project fixture above
- **WHEN** `team up --print` runs, then `team up --no-migrate` runs on the same starting bytes, then the real `team up` runs
- **THEN** the preview exits 0, prints the pairs it would write and the backup path, and leaves the configuration's hash, the audit file and the backup directory unchanged
- **AND** `--no-migrate` exits non-zero, prints the paste-ready derived command and writes nothing; the following real run applies exactly the pairs the preview printed

#### Scenario: An unknown shape is neither passed through nor guessed

- **GIVEN** a configuration carrying a shape number higher than this tool's newest known shape
- **WHEN** `team up` runs in it
- **THEN** it exits non-zero, names the shape number it read and the newest one it knows, writes nothing and applies no older migration row

### Requirement: The startup path reports a newer tool release without installing it

`team up` SHALL compare its own version with the version published for `teamsmith` on the npm registry at most
once per 24 hours: the lookup is bounded — abandoned after two seconds — and its result is cached in the project's
runtime state directory as the check time, the version found and the local version at check time. When the local
version is older than the published one, the run SHALL print exactly one line naming both versions, the pastable
upgrade command (`npm i -g teamsmith@<published> --registry https://registry.npmjs.org` followed by the installed
package's `install.sh`) and the fact that the tool never installs itself. Every other outcome — no npm, no
network, a timeout, a failing or unparsable answer, an equal or older published version — SHALL print nothing and
SHALL NOT change `team up`'s exit code or whether the PM is started.

The lookup SHALL run after the start decision, and a failed lookup SHALL be remembered for the same window so an
offline project does not pay it on every start. `TEAM_UPDATE_CHECK=0` SHALL suppress the lookup entirely. `team up
--print` SHALL perform no lookup and write no cache, and SHALL say that the check was skipped.

#### Scenario: Only a newer published version prints the line

- **GIVEN** a scratch project and a stub npm on `PATH` answering (a) a newer version, (b) the same version, (c) an older version, (d) a failing command and (e) an unparsable answer
- **WHEN** `team up` runs against each with no cache
- **THEN** only (a) prints a line, and that line carries the local version, the published version and the pastable upgrade command; (b) to (e) print nothing
- **AND** in all five runs the exit code and the start decision equal a run with `TEAM_UPDATE_CHECK=0`

#### Scenario: The cache bounds the lookups and the escape hatch removes them

- **GIVEN** a stub npm counting its invocations, and a cache recording the check time
- **WHEN** `team up` runs twice with a fresh cache row, twice with an expired one, and once with `TEAM_UPDATE_CHECK=0`, all against the newer-version stub
- **THEN** the first two runs invoke the stub zero times, the next two exactly once each, and the last zero times and prints nothing

#### Scenario: The preview says it skipped the check

- **WHEN** `team up --print` runs with an expired cache and the stub npm on `PATH`
- **THEN** the stub is invoked zero times, the cache file's bytes are unchanged, and the output says the check was skipped

