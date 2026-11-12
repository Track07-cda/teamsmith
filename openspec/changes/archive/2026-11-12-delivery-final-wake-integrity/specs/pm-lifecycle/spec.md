# Spec Delta

## ADDED Requirements

### Requirement: PM waiting reconciles durable work records

PM guidance SHALL prefer new notifications while treating project files as authoritative. Before repeating an unchanged waiting state, the PM SHALL reconcile the digest, board, task-branch report and Git log/status. An old tip, no new notice or a merged line SHALL NOT alone prove incomplete work; guidance MUST NOT require pane reading or PM reruns of assigned verification.

#### Scenario: A committed final report is found without its final wake

- **GIVEN** an isolated PM with a board task still in progress, a final report committed on that task branch, and no final notification or wake for that report
- **WHEN** the PM performs its ordinary waiting reconciliation
- **THEN** it reads the durable digest/board/report/Git evidence, recognizes the delivery and proceeds to the existing acceptance route rather than merely repeating the same waiting state or rerunning the verifier's tests

#### Scenario: A running job is not mistaken for a final delivery

- **GIVEN** an isolated PM whose seat still has a live background job and no committed final report
- **WHEN** the same reconciliation runs without a new notification
- **THEN** the PM retains or resumes the existing wait/harvest route and does not declare the task delivered from an old tip, a draft report or the absence of a notice

#### Scenario: Reconciliation adds no second scheduler or verification lane

- **WHEN** the PM prompt template, skill and workflow guidance are inspected and the isolated reconciliation is exercised
- **THEN** they use the existing notification, digest, board, task branch and patrol mechanisms, create no additional timer or notification service, and preserve the non-implementer verifier's responsibility for running acceptance gates
