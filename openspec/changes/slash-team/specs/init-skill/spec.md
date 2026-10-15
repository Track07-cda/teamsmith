## MODIFIED Requirements

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

