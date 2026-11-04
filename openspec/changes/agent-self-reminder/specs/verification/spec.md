## MODIFIED Requirements

### Requirement: The record states what was verified

`docs/team/reviews/<ID>.md` SHALL name the verified revision (the checkout's HEAD), the branch, the gate command and
its timeout, the diffstat against the protected branch, the commits and the file list, the tail of the gate output
and the verdict. When the agent's report is missing from the branch, the record MUST say so explicitly instead of
omitting the section.


For self-Reminder verification the record SHALL separately name the real Pi/private-tmux controlled-model integration evidence, the fault/race and identity evidence, and any authorized real-model autonomy evidence. A controlled response or a script calling the tool MUST NOT be reported as proof that a real model autonomously created or re-created a Reminder. An unrun real-model check SHALL be reported as not run, not passed.

#### Scenario: The record pins the revision and the evidence

- **GIVEN** a task branch with two commits and a report committed on it
- **WHEN** `team review T1.1 --dir <checkout>` runs
- **THEN** the record contains the checkout's HEAD sha, the gate command string, both commit subjects, the changed
  file list and the gate output tail

#### Scenario: A missing report is recorded as a problem

- **GIVEN** a task branch with no `docs/team/reports/T1.1-<agent>.md`
- **WHEN** `team review T1.1 --dir <checkout>` runs
- **THEN** the record states that the agent report is missing

#### Scenario: Controlled Pi transport does not claim model autonomy

- **GIVEN** a real Pi integration passed with a controlled model and no authorized real-model autonomy test was run
- **WHEN** the verification record is written
- **THEN** it identifies the controlled-model scope and explicitly marks autonomous creation and repeat wake as not run
