## MODIFIED Requirements

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

## ADDED Requirements

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
