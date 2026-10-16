## ADDED Requirements

### Requirement: A caution is kept only with the fact or gap it cites

The writing rule this capability ships SHALL be stated as a criterion about support, never as a preference about
tone: a sentence that hedges, qualifies, warns or sets a boundary SHALL be kept only when it names something the
reader can check — a measurement, a counterexample, a gap in the reasoning, or a boundary that was not observed —
and otherwise SHALL be deleted; when the evidence no longer supports a claim, the text SHALL say what the evidence
does support instead of narrowing the claim. The rule MUST NOT be phrased as "be more confident", "sound
assertive", or as any other instruction about tone. It MUST NOT be read as licence to delete boundary statements
that carry their evidence: such a sentence names exactly what the criterion asks for, so it SHALL survive, and the
change that ships this rule MUST NOT delete one.

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

### Requirement: A finding states what it changes, and a change-free observation stays out of the body

A finding SHALL state what it changes: the implementation, the next step, the conclusion, or nothing at all. The
consequence SHALL be written in the finding's own text and MUST NOT become a new required column, heading or
report section, because a required box turns the criterion into ceremony that can be filled without the judgement.
An observation that changes nothing SHALL NOT be carried in the body of a report, a review or an answer to the
user; if it is kept at all it goes where it does not stand between the reader and the answer.

#### Scenario: Two observations, one consequence

- **GIVEN** a delivered report with one observation that changed the implementation and one that changed nothing
- **WHEN** that report is reviewed against this requirement
- **THEN** the first names its consequence and stays in the body, while the second is reported as a finding to move out of the body or delete
- **AND** the shipped report shape gains no new required heading, column or section

### Requirement: The rule travels on its surfaces, and the review holds it rather than the gate

The rule SHALL travel with the tool instead of living in one project's memory, on the surfaces its authors read.
The worker-facing protocol section (`templates/AGENTS.section.md.tmpl`) SHALL carry a short block stating that the
brief's question is answered before its evidence, that a caution naming nothing is deleted, that a boundary is
claimed only with its evidence and kept when it carries it, and that a finding states what it changed. The prompt
template the PM is started from (`templates/pm-prompt.md.tmpl`) SHALL state the same four obligations for what the
PM writes to the user, in the section that already governs user-facing output. The protocol reference SHALL state
the criterion and its reason in its user-facing section, keeping the vocabulary rule that section already carries.
The PM's review runbook (`references/workflows.md`, its verification section) SHALL carry the reading rule: every
finding in a deliverable states what it changed, a caution with no support is a finding rather than thoroughness,
and a longer or more defensive report is not stronger evidence. The capability SHALL be held by reading rather
than by the gate: it SHALL add, change or remove no gate assertion and no exit code, because whether a sentence
earns its place is a judgement about wording. The protocol reference and the review runbook SHALL state that limit
— no tool verifies that a live author follows the rule, and the gate claims nothing about it — so a surface that
later loses the rule is caught by the review that reads the diff, never by the gate. The change that ships the rule
MUST NOT remove a sentence that carries its own evidence.

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

### Requirement: The rule's effect is judged by a human read, never by an AI reviewer's score

Whether the rule improves the delivered text SHALL be judged by a human reading two comparable deliverables, one
produced where the surfaces carry the rule and one where they do not, against a rubric fixed before the read. An
AI reviewer's score MUST NOT be the acceptance signal, and the reason SHALL stay stated with the requirement: on
the published measurements an AI reviewer scores the reviewer-oriented rewrite higher (+1.22 on a ten-point scale)
while human readers (four of them) find it harder to read (−0.70 on a seven-point scale) with comprehension
unchanged, and LLM judges prefer assertive wording in style-only pairwise comparisons (1,276 of 1,280) even where
pointwise accuracy shows no hedged-versus-assertive gap. A measurement built on AI scoring would therefore reward
the text this rule removes. The two deliverables, the rubric and the reader's sheet SHALL be kept where the record
names them, the arm-to-label mapping SHALL be recorded apart from the reader's sheet, and the comparison SHALL be
recomputable from those materials. Its outcome SHALL be recorded as one reader's judgement on one task, with that
limit stated, and MUST NOT be presented as a statistical result.

#### Scenario: The comparison is fixed before it is read

- **WHEN** the comparison is run
- **THEN** the rubric exists before the deliverables are read, the two arms differ only by the shipped rule text with the difference shown, both raw deliverables and the reader's sheet are kept at the paths the record names, and the arm-to-label mapping is recorded where the reader's sheet cannot see it
- **AND** the recipe can be repeated from those materials

#### Scenario: No AI score is the acceptance signal

- **WHEN** the comparison and its record are read
- **THEN** no model was asked to score the two deliverables and the acceptance signal is the reader's sheet
- **AND** the record states the sample's limit (one task, one reader) instead of claiming a statistical result
