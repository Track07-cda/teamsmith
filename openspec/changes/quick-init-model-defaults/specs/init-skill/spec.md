## MODIFIED Requirements

### Requirement: Initialization guidance lives in a dedicated teamsmith-init skill

The repository SHALL contain `skills/teamsmith-init/SKILL.md` (at most 100 lines) whose frontmatter names
`teamsmith-init`, and whose body begins with the **installation beat** — install the CLI
(`npm install -g teamsmith`) and run `team init` in the project, which installs the skills into the project's
`.pi/skills/` (the "team init installs the project skills" requirement below) — and then continues the
new-project entry point in three beats: an ordered checklist that requires the PM to settle dependencies,
session/roster, gates, VCS mode, install command and ROADMAP/OWNERSHIP/AGENTS.md red lines with the user and
also covers model setup (task categories and a separate PM model); the instruction to run
`bash <teamsmith>/scripts/team bootstrap`; and a closing handoff sentence
that points day-to-day operation at the `teamsmith` skill. The installation beat SHALL name the npm command and
`team init` before it names `team bootstrap`, SHALL name the project target `.pi/skills/`, and SHALL keep the
two alternative routes on the same page with what each is for — the Pi package install (`pi install …`, which
needs no global CLI) and `./install.sh` (a checkout, or a `~/.agents/skills` layout). The init skill SHALL own
exactly two files moved from the daily skill — `references/bootstrap.md` and
`templates/bootstrap-prompt.md.tmpl` — moved, not copied, and MUST NOT contain `scripts/`, `extension/` or
`tests/` directories, nor claim ownership of the pulse, dispatch, review or merge.

The checklist SHALL explain the Pi-user default model and optional overrides, and MUST NOT ask for model inputs
up front when the saved default provides them and the user has not requested an override.

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
- **THEN** it contains an ordered checklist covering roster/models/gates/VCS, a line invoking
  `scripts/team bootstrap`, and a closing sentence naming `teamsmith` as the skill for day-to-day operation
- **AND** the model item explains the saved default and optional overrides without asking for model inputs up
  front when the default is usable and the user has not requested an override

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

### Requirement: One CLI, one copy of every tool file

`scripts/`, `extension/` and `tests/` SHALL exist only under `skills/teamsmith/`; the `team` CLI is the single
entry point and its behavior is unchanged by the split — in particular `team bootstrap` stays a subcommand of
that same CLI, rendered templates stay anchored at the CLI's own location, and nothing under
`skills/teamsmith/scripts/` or `skills/teamsmith/extension/` references `teamsmith-init`.

#### Scenario: bootstrap still runs from the one CLI

- **WHEN** `bash skills/teamsmith/scripts/team bootstrap --print` runs in a fresh fixture repository without invalid explicit inputs or an unusable selected config path
- **THEN** it exits 0 and keeps the plan's five stages (detect / config / docs skeleton / worktrees / pulse); the
  model information follows the initialization model requirement below

#### Scenario: The tooling never references the init skill

- **WHEN** `grep -rn 'teamsmith-init' skills/teamsmith/scripts/ skills/teamsmith/extension/` and
  `grep -rn 'bootstrap-prompt' skills/teamsmith/scripts/` run
- **THEN** both print nothing and exit non-zero (no hits)

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
The questionnaire SHALL explain the task map and separate PM model. It SHALL ask for a model input only if that
input has not already been provided and either the user wants to override its default or the saved Pi user default
cannot supply it; rendering is covered by the task-policy initialization requirement. This does not change the Pi-version/plugin
checks or advertise the adapter seam.

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

### Requirement: Initialization teaches category policy and breaking upgrades without live adoption

On a fresh project, `team init` and `team bootstrap` SHALL resolve two values before writing: a complete task-model map and a separate PM model. Valid explicit `--task-models` replaces the entire map; valid explicit `--pm-model` sets only the PM model. For each missing input on the first-run path, use the default model actually saved in Pi's user settings: a missing map gets exactly `routine`, `analysis`, `verify` with that model, and a missing PM input gets that same model separately. When both are explicit, there is no Pi default lookup. Invalid explicit inputs or a configuration-path refusal MUST NOT trigger a default lookup, including in preview. Existing plugin and dependency checks do not take part in model selection and SHALL remain unchanged.

The only file consulted for a Pi model SHALL be user `settings.json` under `PI_CODING_AGENT_DIR` or, if unset, `~/.pi/agent`. Use only the saved `defaultProvider` and `defaultModel` and the optional saved thinking level. Prefer the saved level for that exact model, then the saved general level; use only a level that can be appended unambiguously using the existing suffix syntax and can be stored in every field it supplies. Otherwise retain the original saved model ID unchanged. Selection MUST NOT require a Pi executable or process, read project Pi settings, trust, credentials, the model catalog or sessions, or run Pi or its extensions. Do not guess a provider/model or claim authentication or availability.

If a fresh project still lacks either value, real init/bootstrap SHALL refuse before any config/ledger/install/worktree/pulse write. Bootstrap preview SHALL keep the read-only plan and show values actually resolved, explicitly mark unresolved inputs and not present the incomplete plan as runnable. Both missing-input diagnostics SHALL name the current command and only the missing flags as alternatives to saving a Pi default; they MUST NOT suggest a migration for a fresh project.

An unavailable selected configuration or an unusable existing init target MUST NOT be treated as a fresh project. The affected entry point, including bootstrap preview, SHALL name the path and stop before effects, even when both model flags are present; it MUST NOT create configuration elsewhere. If bootstrap finds no config while its init target already exists, it SHALL stop and point to that path instead of calling fresh init. Readable configuration links remain valid. An existing configuration, including an incomplete or damaged one, MUST NOT use Pi defaults. Valid existing projects may re-enter without model inputs and SHALL retain both saved values, even if the Pi default changes; bootstrap preview SHALL show the configuration will be retained, not print an init command it will not run. An explicit re-render SHALL use only valid existing values and validated explicit replacements; it is not a first-run default or migration path. Retired model flags are refused with a correction appropriate to new or existing configuration, without looking up a Pi default. Config templates SHALL declare task map/independent PM, never retired worker keys; init/bootstrap install/protocol/ownership/task/PM/memory guidance SHALL describe task category rather than a permanent seat model. `team task --category` is the brief generator only; it is not a dispatch override. Ownership stays about files/roles, not model strength. The explicit two-model example is routine=opencode-go/deepseek-v4.1-flash and analysis/verify=openai-codex/gpt-6.1-sol:high, independent PM=openai-codex/gpt-6.1-sol:high; examples are not engine defaults or a provider availability claim.

PM guidance SHALL recommend routine for bounded ordinary implementation, analysis for complex planning/judgment and verify for independent adversarial review, record category rationale in brief prose and choose configured names in other projects. Tools do not infer difficulty or phase/category equivalence. Worker guidance SHALL preserve scope, reports and disk handover through fresh takeover; independent verification cannot be waived by a strong model. An existing project's retired model keys SHALL be migrated by the mechanical startup transaction the next requirement defines, or by the explicit `team config upgrade-models` transaction; `init --force` and bootstrap MUST NOT migrate them, and legacy bootstrap refuses before install or other effects naming both routes. Auto-inference MUST NOT invent a model value or a category's meaning beyond that declared table. A write path that refuses a project for carrying the retired keys SHALL print the repair advice derived from that project's own configuration — once per run, above unrelated blockers — and SHALL print a paste-ready command only when the derivation is unambiguous. Private source verification, protected-branch source landing, project configuration/fresh-launch activation and shared-source adoption SHALL be distinct recorded gates. S1→S2→S3 dependencies and shared-file handoffs SHALL use a private non-deployed integration tree that is not a target of global/project-live skill links or live CLI source paths; it is not the shared main checkout. Partial implementation SHALL NOT reach shared source/main before a separately approved safe adoption plan. Private review/handoff is not protected-branch delivery and SHALL NOT mark apply tasks done merely because they are integrated privately. Before full validated source reaches shared main, PM SHALL either obtain per-operation user authorization to isolate known shared consumers to preserved stable source and verify that isolation, or obtain explicit approval of the identified shared-source impact, including later reads by unmigrated projects. No automatic scanning/deployment system is required, and unknown consumers cannot be promised unaffected. This change does not execute link changes/installers or other-project adoption. Source changes still SHALL NOT silently rewrite live config, ledgers or running processes; project config migration, fresh launches, shared-source adoption and any other-project work each require their separate existing authorization.

#### Scenario: A fresh project saves the Pi user default and exactly three task types
- **GIVEN** a private Git project with no team configuration and a Pi user settings file saving `vendor/nested/model` with thinking level `high`
- **WHEN** init runs without model flags, with no Pi executable on PATH
- **THEN** config readback contains exactly `routine`, `analysis`, `verify` and a separate PM value, all `vendor/nested/model:high`, with no retired keys and the existing identity/layout

#### Scenario: Bootstrap preview and actual initialization use the same inputs
- **GIVEN** a fresh private project with a saved default and no saved thinking level
- **WHEN** bootstrap is previewed and then run without model flags, with no change to those inputs
- **THEN** the preview changes no project files or processes, and shows the same three task-model values and separate PM value that the real run writes, with no inserted thinking suffix

#### Scenario: Fresh initialization has explicit model inputs and no retired keys
- **GIVEN** fresh private projects with a different saved Pi default
- **WHEN** init or bootstrap runs with an explicit PM model only, an explicit task map only, or both
- **THEN** only the supplied value overrides the default in the first two cases, the explicit map contains exactly its supplied categories, and supplying both persists just those explicit values without a Pi default lookup
- **AND** the rendered configuration contains only the new model keys and retains the existing identity/layout
- **AND** a supplied invalid map or PM model is refused before effects even with a usable saved default, including in bootstrap preview; retired `--default-model` is still rejected with a correction

#### Scenario: Missing models do not create a project
- **GIVEN** a fresh private project without a usable saved default
- **WHEN** init or bootstrap lacks one or both model inputs, or bootstrap previews that plan
- **THEN** a real run refuses before any writes and the preview exits successfully as a read-only plan, showing only the unresolved inputs as missing and not printing a runnable init command with placeholders
- **AND** the next step names the invoked command and only the missing flags, not an already supplied flag or a migration

#### Scenario: Existing project model values do not follow the Pi default
- **GIVEN** an existing valid project and a different saved Pi user default
- **WHEN** init or bootstrap is re-entered without model flags, or bootstrap previews the existing configuration
- **THEN** the existing model values and categories remain unchanged with no Pi default lookup; preview says that configuration will be retained and does not print an init step as an executable command
- **AND** an existing incomplete project is not automatically repaired by Pi defaults, and explicit re-render keeps its existing rules without a Pi default lookup

#### Scenario: An unavailable selected config is not a first run
- **GIVEN** a private Git project, a path explicitly selected with `--config` that does not exist, a usable Pi default and two valid explicit model flags
- **WHEN** init, bootstrap and bootstrap preview are called against that path
- **THEN** they name the selected path and refuse before effects without looking up a Pi default, creating the selected path or writing under the main checkout

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
