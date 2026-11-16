## ADDED Requirements

### Requirement: Normal configuration checks have one execution site

In a normal complete smoke run, section `33` SHALL execute the complete no-argument `config-cli.sh` entry once; `51` SHALL not repeat it. In a selected run, this entry SHALL execute only when `33` is selected, not be added to `51` or `12e`–`12k` by this rule. The standalone entry SHALL remain complete. Different product-tree mutation/restoration runs and the routes roster-promise check SHALL NOT count as this duplicate.

#### Scenario: The two affected sections retain the real checks without replay

- **WHEN** a normal complete non-FAST smoke run executes sections `33` and `51`
- **THEN** `33` runs the unchanged complete no-argument configuration entry, including its real CLI, configuration bytes, validation failures, registration/removal, CAS and audit checks; `51` runs its existing routes and help checks, including the separate roster promise, but starts no second configuration entry
- **AND** configuration child failure makes `33` and the containing smoke run fail rather than becoming a successful assertion count

#### Scenario: Independent entries keep their own execution scope

- **WHEN** `bash skills/teamsmith/tests/config-cli.sh` runs without group arguments, or smoke is independently invoked selecting `33`, `51`, or one of `12e` through `12k`
- **THEN** the standalone configuration entry and a selected `33` retain the complete default group set and existing success, assertion-failure and setup-failure exit semantics; selecting `51` or one of `12e` through `12k` does not add `33` or configuration execution merely to satisfy this rule
- **AND** real writes/refusals remain real checks, not recorded-output substitutes

#### Scenario: Changed paths still select the checks that consume them

- **WHEN** selection is requested for `skills/teamsmith/tests/config-cli.sh` or `skills/teamsmith/scripts/lib/cmd-config.sh`
- **THEN** it includes `33`; the configuration test path no longer selects `51` for the removed call, while the product configuration path still includes `51` for its separate routes promise
- **AND** a path claimed by no row still yields `FULL`

### Requirement: Change-workflow preparation does not schedule configuration execution

Each of sections `12e` through `12k` SHALL run independently with its existing real prerequisites and assertions, without executing section `33` merely to obtain preparation definitions. Each run SHALL prepare its own disposable projects; no result or writable project from another selected section SHALL supply its prerequisites. Real data dependencies SHALL remain explicit.

#### Scenario: Every affected key starts from its own preparation

- **GIVEN** no projects or preparation results from an earlier smoke run
- **WHEN** each key from `12e` through `12k` is selected in a separate smoke invocation
- **THEN** its existing CLI, git/worktree, status, refusal and applicable live-process checks execute under the existing availability rules, using fresh private projects; its selection and runtime headers contain no `33` or configuration-child execution solely for preparation
- **AND** neither a combined selection nor a normal complete run relies on a preceding configuration result to prepare these sections

#### Scenario: Missing preparation is a failure, not a vacuous pass

- **GIVEN** an isolated scratch copy in which a preparation definition required by `12e` has been removed
- **WHEN** `12e` is selected alone
- **THEN** the existing self-sufficiency check or runtime assertions fail non-zero and identify the missing preparation, and restoring the definition recovers the original result; selecting `33` is not the repair
