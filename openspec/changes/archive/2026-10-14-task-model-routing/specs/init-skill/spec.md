## MODIFIED Requirements

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

### Requirement: Existing projects and running sessions see zero change

Private non-deployed source development SHALL NOT rewrite existing project configuration, ledger, skill links/copies or running processes. This routing upgrade is explicitly breaking: old worker keys require the dedicated `config upgrade-models` transaction; `init --force` and bootstrap are not model-migration shortcuts. A shared skill link reads its target's current bytes: changing that source can affect the next CLI/skill read without invoking an installer or restarting an already-running process. Guidance SHALL not claim zero shared impact merely from avoiding installers. Before product changes reach a shared source/main, the separately authorized source-isolation or explicitly approved shared-impact adoption gate specified below must be satisfied. Launch commands SHALL still use the daily skill directory and never an init-skill runtime dependency.

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
- **WHEN** `team init --session <s> --agents "dev" --vcs local --gates true --task-models 'routine=vendor/light' --pm-model vendor/strong` runs in the first, and the same
  command with `--no-skills` runs in the second
- **THEN** the first exits 0, its output carries one line containing `.pi/skills/`, `pi --approve` and `/trust`,
  and `.pi/skills/teamsmith` exists; the second exits 0, prints no such line, and has no `.pi/skills/`

#### Scenario: The rerun and the bootstrap upgrade path say it too

- **GIVEN** the first repository after one init (its entries exist, so the step reports `skip`), and a copy of it
  whose valid new-policy `.pi/team/config.sh` already exists
- **WHEN** the same `team init` runs a second time, and `team bootstrap --no-pulse --agents "dev"` runs in the copy
- **THEN** both exit 0 and both outputs carry the line — one implementation and one wording at both call points

#### Scenario: The documentation carries the fact

- **GIVEN** `skills/teamsmith-init/SKILL.md` and `skills/teamsmith-init/references/bootstrap.md`
- **WHEN** both are searched for `.pi/skills/`, `pi --approve` and `/trust`
- **THEN** both name the triggering resource and the answers, and a scratch copy with the note deleted fails the
  same search — the red side proving the check is not vacuous

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
- **`bootstrap`**: `team bootstrap` SHALL perform this same step through the same code path for fresh or valid-new-policy projects with or without `.pi/team/config.sh`; legacy model configuration SHALL refuse before this step and name the dedicated model upgrade route, not a bootstrap migration —
  and `bootstrap --print` SHALL name the step in its plan and write nothing. There MUST NOT be a second install
  semantics beside this one.
- The step SHALL print one line per skill (`link <dest> → <src>` / `copy <dest>` / `skip <dest>`), so the result
  is auditable from the command's own output.

#### Scenario: The default install links both skills into the project

- **GIVEN** a fresh git repository with one commit, and a `team` CLI running from this tree
- **WHEN** `team init --session <s> --agents "dev verify" --vcs local --gates true --task-models 'routine=vendor/light' --pm-model vendor/strong` runs in it
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

- **GIVEN** two fresh repositories and valid explicit `--task-models 'routine=vendor/light' --pm-model vendor/strong` inputs for each init
- **WHEN** `team init … --no-skills` runs in the first, and `team init … --copy` runs in the second
- **THEN** the first has no `.pi/skills/` directory at all and its output says the step was skipped, while the
  second has real directories whose `SKILL.md` bytes equal the source's and whose `scripts/team` exists
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

#### Scenario: bootstrap runs the install step on an existing project too, and --print writes nothing

- **GIVEN** an existing repository with valid new model policy — `.pi/team/config.sh` present, no `.pi/skills/` — and a
  copy of its `.pi` directory's hash taken before the run
- **WHEN** `team bootstrap --agents dev` runs in it, and then, in a second fixture, `team bootstrap --print` runs
- **THEN** the first run installs the two entries and exits 0 without rewriting the existing config
- **AND** the second run names the install step in its printed plan, creates no `.pi/skills/` entry and leaves
  every file it printed about unchanged

## ADDED Requirements

### Requirement: Initialization teaches category policy and breaking upgrades without live adoption

Fresh init/bootstrap SHALL accept `--task-models '<map>' --pm-model '<model>'` and render exactly those validated values; missing explicit model inputs refuse before config/ledger/install/worktree/pulse writes. Existing valid new-policy projects may be re-entered without supplying those inputs again and SHALL keep their policy; any explicit re-render that requires new values SHALL validate explicit inputs before replacement. Retired `--default-model` is removed with a correction. Config templates SHALL declare task map/independent PM, never retired worker keys; init/bootstrap install/protocol/ownership/task/PM/memory guidance SHALL describe task category rather than a permanent seat model. `team task --category` is the brief generator only; it is not a dispatch override. Ownership stays about files/roles, not model strength. The initial two-model example is routine=opencode-go/deepseek-v4.1-flash and analysis/verify=openai-codex/gpt-6.1-sol:high, independent PM=openai-codex/gpt-6.1-sol:high; examples are not engine defaults or a provider availability claim.

PM guidance SHALL recommend routine for bounded ordinary implementation, analysis for complex planning/judgment and verify for independent adversarial review, record category rationale in brief prose and choose configured names in other projects. Tools do not infer difficulty or phase/category equivalence. Worker guidance SHALL preserve scope, reports and disk handover through fresh takeover; independent verification cannot be waived by a strong model. Existing projects SHALL use explicit preview/upgrade, not init --force, bootstrap or auto-inference to migrate; legacy bootstrap refuses before install or other effects. Private source verification, protected-branch source landing, project configuration/fresh-launch activation and shared-source adoption SHALL be distinct recorded gates. S1→S2→S3 dependencies and shared-file handoffs SHALL use a private non-deployed integration tree that is not a target of global/project-live skill links or live CLI source paths; it is not the shared main checkout. Partial implementation SHALL NOT reach shared source/main before a separately approved safe adoption plan. Private review/handoff is not protected-branch delivery and SHALL NOT mark apply tasks done merely because they are integrated privately. Before full validated source reaches shared main, PM SHALL either obtain per-operation user authorization to isolate known shared consumers to preserved stable source and verify that isolation, or obtain explicit approval of the identified shared-source impact, including later reads by unmigrated projects. No automatic scanning/deployment system is required, and unknown consumers cannot be promised unaffected. This change does not execute link changes/installers or other-project adoption. Source changes still SHALL NOT silently rewrite live config, ledgers or running processes; project config migration, fresh launches, shared-source adoption and any other-project work each require their separate existing authorization.

#### Scenario: Fresh initialization has explicit model inputs and no retired keys
- **WHEN** scratch init and fresh bootstrap run with valid task map and PM model, then with missing/invalid inputs and retired --default-model
- **THEN** valid rendering carries only new model policy and the existing identity/layout; invalid calls refuse before any skeleton/install/pulse effect and give new input routes

#### Scenario: Legacy bootstrap is not an implicit migration
- **WHEN** bootstrap runs on legacy config even with force, or bootstrap --print previews it
- **THEN** it diagnoses upgrade before writes/install/worktree/pulse; print remains read-only; dedicated explicit config upgrade is the named migration route, not init --force

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
