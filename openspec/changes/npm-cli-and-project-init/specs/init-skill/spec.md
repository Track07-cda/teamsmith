## MODIFIED Requirements

### Requirement: Initialization guidance lives in a dedicated teamsmith-init skill

The repository SHALL contain `skills/teamsmith-init/SKILL.md` (at most 100 lines) whose frontmatter names
`teamsmith-init`, and whose body begins with the **installation beat** — install the CLI
(`npm install -g teamsmith`) and run `team init` in the project, which installs the skills into the project's
`.pi/skills/` (the "team init installs the project skills" requirement below) — and then continues the
new-project entry point in three beats: an ordered checklist of the questions the PM must settle with the user
(dependencies, session/roster, per-agent models, gates, VCS mode, install command, ROADMAP/OWNERSHIP/AGENTS.md
red lines), the instruction to run `bash <teamsmith>/scripts/team bootstrap`, and a closing handoff sentence
that points day-to-day operation at the `teamsmith` skill. The installation beat SHALL name the npm command and
`team init` before it names `team bootstrap`, SHALL name the project target `.pi/skills/`, and SHALL keep the
two alternative routes on the same page with what each is for — the Pi package install (`pi install …`, which
needs no global CLI) and `./install.sh` (a checkout, or a `~/.agents/skills` layout). The init skill SHALL own
exactly two files moved from the daily skill — `references/bootstrap.md` and
`templates/bootstrap-prompt.md.tmpl` — moved, not copied, and MUST NOT contain `scripts/`, `extension/` or
`tests/` directories, nor claim ownership of the pulse, dispatch, review or merge.

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

## ADDED Requirements

### Requirement: team init installs the project skills

`team init` SHALL install this repository's two skills into the project it initialises, in the same run and
without a second command. The target directory SHALL be `<main worktree>/.pi/skills/` — Pi's project-level
skill search path — so init run inside a linked worktree still installs for the project. Each skill SHALL land
as its own entry (`teamsmith`, and `teamsmith-init` when the installation carries it), and the source SHALL be
the running CLI's own skill directories (`$TEAM_SKILL_DIR`, and its sibling `teamsmith-init`) — never a sweep of
every directory under `skills/` — so an installation that carries only one of the two installs only that one and
says so.

- **Modes**: the default is a symlink to the source (one copy of the code; package updates are live);
  `--copy` copies the files instead, excluding `.git/` and `node_modules/` and nothing else (for an ephemeral
  source such as an `npx` cache); `--no-skills` skips this step entirely and says that it skipped.
- **Idempotence**: repeating `team init` MUST NOT install twice and MUST NOT overwrite: an entry that already
  resolves to the same source (link), or whose bytes equal the source (copy), SHALL be reported as skipped and
  the run SHALL still exit 0.
- **Conflicts**: an entry that exists and is not this source SHALL NOT be replaced silently. The run SHALL name
  the path, what it found and the routes (`team init --force` to replace it, remove it by hand, or `--no-skills`
  to skip), and SHALL exit non-zero; the entry's bytes SHALL be unchanged. `--force` SHALL replace an entry that
  is a symlink, or a directory carrying a `SKILL.md` whose frontmatter `name` is that skill; a directory that is
  not recognisable as that skill MUST NOT be deleted even with `--force` (the run exits non-zero and names the
  manual route).
- **`.gitignore`**: the install directory SHALL be added to the project's teamsmith block, once (an absolute
  symlink must not be committed, and a copy is re-creatable).
- **`bootstrap`**: `team bootstrap` SHALL perform this same step through the same code path whether or not the
  project already has `.pi/team/config.sh` — so re-running bootstrap is an existing project's upgrade route —
  and `bootstrap --print` SHALL name the step in its plan and write nothing. There MUST NOT be a second install
  semantics beside this one.
- The step SHALL print one line per skill (`link <dest> → <src>` / `copy <dest>` / `skip <dest>`), so the result
  is auditable from the command's own output.

#### Scenario: The default install links both skills into the project

- **GIVEN** a fresh git repository with one commit, and a `team` CLI running from this tree
- **WHEN** `team init --session <s> --agents "dev verify" --vcs local --gates true` runs in it
- **THEN** it exits 0, `.pi/skills/teamsmith` and `.pi/skills/teamsmith-init` are symlinks whose resolved
  targets are `$TEAM_SKILL_DIR` and its sibling, the output names both with `link`, and `.gitignore` carries
  `.pi/skills/`
- **AND** running the same init from a linked worktree of that repository puts the entries in the main
  worktree's `.pi/skills/`, not in the worktree's

#### Scenario: A second init skips instead of installing again or overwriting

- **GIVEN** the same repository after one init, with the two entries' targets and the copy's content hash
  recorded
- **WHEN** `team init …` runs a second time, and again with `--copy` against the existing links
- **THEN** the first run exits 0 and its output names both skills with `skip`, the recorded targets/hashes are
  unchanged, and `.pi/skills/` holds no third entry

#### Scenario: --no-skills skips the step; --copy copies the files without the build directory

- **GIVEN** two fresh repositories
- **WHEN** `team init … --no-skills` runs in the first, and `team init … --copy` runs in the second
- **THEN** the first has no `.pi/skills/` directory at all and its output says the step was skipped, while the
  second has real directories whose `SKILL.md` bytes equal the source's and whose `scripts/team` exists
- **AND** the second has no `scripts/panel/node_modules` and no `.git` inside either entry

#### Scenario: A conflicting entry is announced, and --force replaces only what it recognises

- **GIVEN** a fresh repository whose `.pi/skills/teamsmith` is first a directory without a `SKILL.md`, and then
  (a second fixture) a directory carrying a hand-edited `SKILL.md` that names `teamsmith`
- **WHEN** `team init …` runs against each, and then each with `--force`
- **THEN** the runs without `--force` exit non-zero, name the path and the two routes, and leave the directory's
  bytes unchanged (hash before = hash after) — including the unrecognisable one, which `--force` still refuses
  and still leaves untouched
- **AND** against the hand-edited copy, `--force` replaces it with the source's (the `SKILL.md` bytes equal the
  source's afterwards)

#### Scenario: bootstrap runs the install step on an existing project too, and --print writes nothing

- **GIVEN** a repository initialised before this change — `.pi/team/config.sh` present, no `.pi/skills/` — and a
  copy of its `.pi` directory's hash taken before the run
- **WHEN** `team bootstrap --agents dev` runs in it, and then, in a second fixture, `team bootstrap --print` runs
- **THEN** the first run installs the two entries and exits 0 without rewriting the existing config
- **AND** the second run names the install step in its printed plan, creates no `.pi/skills/` entry and leaves
  every file it printed about unchanged

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
and SHALL NOT by itself make doctor exit non-zero.

#### Scenario: A linked install is named, and no install is silent

- **GIVEN** one fixture repository initialised by `team init`, and a second left without `.pi/skills/`
- **WHEN** `team doctor` runs in each
- **THEN** the first prints a row naming `.pi/skills/teamsmith` and its link, exits 0 and warns about nothing
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
