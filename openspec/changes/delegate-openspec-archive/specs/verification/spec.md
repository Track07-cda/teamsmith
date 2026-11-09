## ADDED Requirements

### Requirement: Verification and archive are delegated phases

Teamsmith's default guidance SHALL assign `opsx-verify` and `opsx-archive` to non-PM workers who did not implement the change. The verifier MAY also archive. The PM SHALL dispatch, independently review evidence/revisions/diffs, communicate and merge; it MUST NOT execute either phase or its gates, including through PM-owned background jobs.

#### Scenario: The default covers all shipped entry points

- **WHEN** AGENTS, PM-prompt, PROTOCOL, OWNERSHIP and memory-seed templates, the daily skill, workflow/OpenSpec/protocol/troubleshooting references, README and the init skill are read
- **THEN** operative role rows, hard rules, command tables, daily loops, background examples and delivery promises consistently assign verify/archive execution to workers and acceptance/merge to PM
- **AND** refreshing the managed AGENTS section uses this default while preserving outside project rules byte for byte

#### Scenario: A nonempty PM owner is still the wrong owner

- **GIVEN** clean shipped guidance passing smoke section `19`
- **WHEN** a verify/archive phase owner or operative template instruction is changed to PM while unrelated independent-review words remain
- **THEN** the existing section identifies the changed file/role rather than accepting a nonempty cell or unrelated keyword; restoring the worker owner removes that finding

#### Scenario: Delegation needs no permanent extra seat

- **GIVEN** a dev implemented a change and another worker verified it
- **WHEN** PM assigns archive to that verifier or another eligible non-implementer worker
- **THEN** the default needs no new roster role, category, configuration key or workflow state; PM or implementer execution does not satisfy it

### Requirement: Delegated reviews record their actual executor and narrow ledger authority

The PM SHALL prepare the independent checkout and the assigned verifier SHALL execute `team review`. The verify brief and OWNERSHIP MUST authorize the tool's named main-checkout review record and companion gate log as a narrow ledger exception. The record MUST identify the actual executor separately from checkout preparation and PM acceptance. This MUST NOT grant general worker access to main.

#### Scenario: A verifier produces truthful centralized evidence

- **GIVEN** PM prepared a clean detached checkout and a non-implementer verifier has a brief naming the reviewed task ID, revision, `docs/team/reviews/<ID>.md` and `<ID>-verify.log`
- **WHEN** that verifier runs `team review <ID> --dir <checkout>` with the target revision explicitly bound where needed
- **THEN** the named main-checkout record/log contain the real verifier identity, reviewed SHA, actual commands/results and evidence; the title/body do not falsely attribute execution to PM or the implementation task's author
- **AND** only the tool writes the named central record/log and its existing runtime bookkeeping; the worker's report remains on its branch and the grant excludes manual main edits, unrelated records, code/spec changes, merges and protected-branch pushes
- **AND** when verify and implementation task IDs differ, PM writes the verify task's own done-evidence record as explicitly titled PM acceptance, linking the implementation-ID tool record, verifier report and verified merged SHA without claiming execution; archive reads the execution record and completed assessment rather than substituting this acceptance record

#### Scenario: Gate evidence does not invent a completed assessment

- **GIVEN** a generated review records shell-gate PASS
- **WHEN** archive evidence is inspected
- **THEN** PASS alone does not assert zero CRITICAL findings or completed OpenSpec verification; the worker's completed assessment report is required and PM acceptance remains a separate decision
- **AND** replacing actual-executor attribution with hard-coded PM in the review generator makes the existing review evidence test fail; restoring attribution makes it pass

### Requirement: The same verifier checks the merged revision before done and archive

After the PM merges the candidate, the same verifier MUST resume verification on the merged revision, recording its identity, revision, applicable gate commands/results and OpenSpec assessment. The PM MUST accept passing post-merge evidence before marking the work done or proceeding to archive. Pre-merge evidence or the inspection-only `team review --post-merge` MUST NOT substitute for that run.

#### Scenario: A merge creates a new verification target

- **GIVEN** a verifier completed the candidate review and PM merged the implementation
- **WHEN** the merged revision is ready for final verification
- **THEN** PM supplies a clean detached checkout of that revision and the same verifier resumes its assignment, runs the applicable gates and assessment, and retains both candidate and merged revision receipts in its report
- **AND** the latest centralized review identifies the verified merged SHA; a failed or incomplete result keeps the work pending and prevents archive authorization

#### Scenario: Execution ownership is consistent at each merged-tree instruction

- **WHEN** the merged-tree instructions in `references/workflows.md` phase 4 and `references/openspec.md` phase 4 and PM verify-checklist row are followed
- **THEN** all three name the same verifier as executor and PM as acceptance/done owner, without a PM-run gate or a missing post-merge check
- **AND** local/forge examples place done/close after accepted evidence; selected/full/milestone coverage semantics are preserved, and the two currently authorized changes require no retrospective rerun

### Requirement: Archive uses completed OpenSpec assessment and valid confirmation

Before archive the owner MUST check independent verification for the accepted merged baseline, zero unresolved CRITICAL findings, recorded WARNING/unverified checks, completed sibling/checklist evidence and valid confirmation. The assessment MUST follow `openspec-verify-change` definitions and fixed CRITICAL/WARNING/SUGGESTION/Final assessment sections. User confirmation or the existing narrowly qualified, recorded PM-proxy confirmation SHALL remain valid.

#### Scenario: Verification is not structural validation or prompt availability

- **GIVEN** an implementation passed `openspec validate` but has no completed independent OpenSpec verification
- **WHEN** the archive worker checks prerequisites
- **THEN** archive stops despite board completion or a successful trial; verification must assess completeness, requirement/scenario correctness and design coherence with revision/command evidence
- **AND** a missing generated `/opsx-verify` prompt or `openspec-verify-change` skill requires the documented equivalent review with the limitation disclosed, not a waiver or invalid `openspec instructions verify` command

#### Scenario: Findings retain the upstream meanings and report sections

- **WHEN** the verifier writes its report using the report template
- **THEN** CRITICAL covers incomplete tasks, missing implementations, removed behavior still implemented and renamed behavior lost; WARNING covers spec/design divergence and missing scenario coverage; SUGGESTION covers pattern/minor improvements, following the existing workflow rather than a local classifier
- **AND** the report contains CRITICAL, WARNING, SUGGESTION and Final assessment sections, its completeness/correctness/coherence scorecard and every unverified applicable check/reason; final assessment retains the upstream counts/readiness rules and does not call skipped checks passing

#### Scenario: Limited PM-proxy confirmation is retained

- **GIVEN** completed merged-revision verification, zero unresolved CRITICAL findings and reconciled sibling/checklist evidence
- **WHEN** confirmation is inspected
- **THEN** the worker accepts user confirmation or explicit PM-proxy confirmation only for a small, reversible change already covered by the approved approach, with confirmer and reason recorded; an unexplained proxy claim or PM evidence acceptance alone is insufficient
- **AND** WARNING findings and unverified checks/reasons are disclosed before confirmation and remain recorded afterwards, never converted to passes; unresolved CRITICAL findings always stop archive

#### Scenario: Guidance permitting missing verification or CRITICAL findings is red

- **GIVEN** shipped guidance passing smoke `19`
- **WHEN** its operative archive prerequisite is changed to allow absent completed verification or unresolved CRITICAL findings
- **THEN** the existing section identifies that file/prerequisite despite unrelated verification words elsewhere, and restoring the prerequisite removes the finding

### Requirement: Archive writes only the assigned worktree and task branch

The archive brief MUST temporarily grant only its selected change/archive destination, enumerated affected capability specs and worker report in the worker's own worktree/branch. The worker MUST trial archive in a private disk-backed copy, then commit native archive and its evidence without writing main, merging or pushing the protected branch. The PM SHALL inspect and integrate the result. Native synchronization MUST preserve existing capability Purpose text.

#### Scenario: Archive and Purpose follow-up are separately reviewable

- **GIVEN** prerequisites and the archive path grant are met on the accepted baseline
- **WHEN** the worker trials a private disk-backed copy and performs native archive on its own branch
- **THEN** the archive commit includes updated specs, archived change and baseline/command evidence while existing Purpose remains unchanged; main is untouched until PM accepts/integrates
- **AND** the stale verification Purpose is updated only afterwards in a separately authorized Purpose-only documentation commit with its explicit before/after diff, separately reviewed and kept distinct on integration, not silently altered by native archive

#### Scenario: The archive task recognizes only its exact self blocker

- **GIVEN** an active archive task whose brief explicitly declares the literal header `phase: archive` and output from `team change status <change>`, which prints the brief's phase verbatim
- **WHEN** readiness is checked before archive
- **THEN** the only permitted self blocker is the row whose literal phase is `archive` and whose task ID equals this brief's ID; `opsx-archive` (the command name) or `-` is not the required header value, and a nonzero result with only the exact self row does not block archive or require an exit-zero workaround
- **AND** any other task/checklist blocker still stops archive; archive is not an unchecked implementation item that can only be completed after itself, and PM closes the task after accepted integration

### Requirement: Dependent archives use the predecessor's merged baseline

When one change depends on another, the predecessor's archive MUST be accepted and merged before the successor archive starts. The successor MUST use that baseline and reconcile complete `MODIFIED` blocks against it. An obsolete block or change invalidating verification MUST return to its authorized owner for correction and independent re-verification instead of overwriting accepted behavior.

#### Scenario: The successor preserves predecessor behavior and scenarios

- **GIVEN** alpha and beta modify one requirement and beta depends on alpha
- **WHEN** alpha's worker archive is accepted/merged, then beta is prepared and archived from that updated baseline
- **THEN** the final requirement retains accepted alpha behavior/scenarios plus beta's additions, and beta's report identifies the merged predecessor and reconciliation evidence
- **AND** successful trial archive on an older baseline is not evidence of the required order

#### Scenario: An old complete block cannot silently undo an earlier archive

- **GIVEN** beta's complete block omits an accepted alpha scenario or alpha's archive remains unmerged
- **WHEN** beta's archive worker checks its baseline/delta
- **THEN** it stops, reports the missing merged predecessor or stale block and leaves main unchanged; authorized delta correction and necessary independent re-verification precede a new archive attempt
