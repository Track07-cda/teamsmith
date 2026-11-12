## MODIFIED Requirements

### Requirement: A caution is kept only with the fact or gap it cites
The writing rule SHALL judge each caution, qualification, warning or boundary by the evidence it names. It SHALL keep a sentence that names a checkable measurement, counterexample, reasoning gap or unobserved boundary, and SHALL delete one that names none. When evidence no longer supports a claim, the text SHALL state what the evidence does support instead of narrowing the claim.

#### Scenario: A caution that names nothing is a finding; one that names a gap stays

- **GIVEN** a delivered text carrying one caution that names a measurement or an unobserved boundary, and one caution that names nothing at all
- **WHEN** the rule is applied to that text
- **THEN** the first sentence is kept and the second is reported as a finding to delete
- **AND** the finding names the sentence, not the author's tone, and no sentence that carries its fact or gap is removed

#### Scenario: The rule cannot be read as a tone instruction

- **WHEN** the shipped text of the rule is read
- **THEN** it states the support test (a measurement, a counterexample, a reasoning gap, an unobserved boundary)
- **AND** it carries no instruction about sounding more confident or more assertive, and no claim that shorter or
  more forceful prose is the goal

#### Scenario: An evidence-backed boundary survives the rewrite
- **WHEN** the shipped rule and its change are read
- **THEN** no instruction to "be more confident", "sound assertive", or otherwise adjust tone replaces the support test
- **AND** no evidence-backed boundary is deleted, and an unsupported claim is rewritten to state only what its evidence supports

### Requirement: A finding states what it changes, and a change-free observation stays out of the body
A finding SHALL state in its own text what it changes: the implementation, the next step, the conclusion, or nothing. This consequence MUST NOT become a required column, heading or report section. An observation that changes nothing SHALL NOT appear in the body of a report, review or user answer; if retained, it SHALL be placed where it does not precede or obscure the answer.

#### Scenario: Two observations, one consequence

- **GIVEN** a delivered report with one observation that changed the implementation and one that changed nothing
- **WHEN** that report is reviewed against this requirement
- **THEN** the first names its consequence and stays in the body, while the second is reported as a finding to move out of the body or delete
- **AND** the shipped report shape gains no new required heading, column or section

### Requirement: The rule travels on its surfaces, and the review holds it rather than the gate
The writing rule SHALL travel with the tool on the worker template, PM template, protocol reference and PM review runbook rather than living only in project memory. Those surfaces SHALL state the answer-first, evidence-backed-caution and finding-consequence obligations assigned to them. Human review SHALL hold the rule; no gate assertion or exit code SHALL claim to judge live wording.

#### Scenario: Each surface carries what it owes

- **WHEN** the worker template, the PM template, the protocol reference and the review runbook are read
- **THEN** each states the obligations listed for it, and the protocol's user-facing section still carries the vocabulary rule it already had
- **AND** no gate section holds this wording, so the correctness gate is green whether or not those sentences are present

#### Scenario: A surface that loses the rule is a reading finding, not a silent pass

- **WHEN** a later change removes the block from one of the surfaces and its diff is reviewed
- **THEN** the reviewer reports the surface that lost the rule, because reading — not the gate — is what holds this requirement
- **AND** the shipped text states that limit instead of claiming a check that does not exist

#### Scenario: Evidence-backed boundary statements survive the change

- **WHEN** the change's diff over the shipped surfaces is read
- **THEN** every deleted sentence is shown to name no fact or gap
- **AND** no sentence that carries its evidence is removed

#### Scenario: The named surfaces carry their distinct obligations
- **WHEN** `templates/AGENTS.section.md.tmpl`, `templates/pm-prompt.md.tmpl`, the protocol reference's user-facing section and `references/workflows.md`'s verification section are read
- **THEN** the worker template answers the brief's question before its evidence, deletes unsupported cautions, keeps evidence-backed boundaries and states what each finding changed
- **AND** the PM template carries those four obligations in its existing user-facing-output section
- **AND** the protocol reference states the criterion and its reason while preserving its vocabulary rule
- **AND** the review runbook requires every finding to state its consequence and rejects unsupported cautions and the idea that longer or more defensive reports are stronger evidence

#### Scenario: Review owns the wording judgement
- **WHEN** the protocol reference, review runbook and gate are inspected
- **THEN** the reference and runbook state that no tool verifies a live author's compliance and the gate claims nothing about it
- **AND** the capability adds, changes or removes no gate assertion or exit code, so a later wording loss is a review finding rather than a gate result

### Requirement: The rule's effect is judged by a human read, never by an AI reviewer's score
Whether the rule improves delivered text SHALL be judged by a human reading two comparable deliverables against a rubric fixed before the read. An AI reviewer's score MUST NOT be the acceptance signal. The deliverables, rubric, reader sheet and separately recorded arm-to-label mapping SHALL make the comparison recomputable; its outcome SHALL be presented as one reader's judgement on one task, not a statistical result.

#### Scenario: The comparison is fixed before it is read

- **WHEN** the comparison is run
- **THEN** the rubric exists before the deliverables are read, the two arms differ only by the shipped rule text with the difference shown, both raw deliverables and the reader's sheet are kept at the paths the record names, and the arm-to-label mapping is recorded where the reader's sheet cannot see it
- **AND** the recipe can be repeated from those materials

#### Scenario: No AI score is the acceptance signal

- **WHEN** the comparison and its record are read
- **THEN** no model was asked to score the two deliverables and the acceptance signal is the reader's sheet
- **AND** the record states the sample's limit (one task, one reader) instead of claiming a statistical result

#### Scenario: Published measurements explain why AI scoring is excluded
- **WHEN** the requirement's text, or the record it points to, states why AI scoring is excluded
- **THEN** it cites the reviewer-oriented rewrite's +1.22 AI score on a ten-point scale, four human readers' −0.70 readability result on a seven-point scale with unchanged comprehension, and LLM judges' 1,276-of-1,280 preference for assertive wording in style-only pairwise comparisons despite no pointwise accuracy gap
- **AND** it explains that AI scoring would therefore reward the text this rule removes, without turning those measurements into the acceptance signal
