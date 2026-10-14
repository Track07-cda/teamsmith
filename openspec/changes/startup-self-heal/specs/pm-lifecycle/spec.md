## MODIFIED Requirements

### Requirement: The existing PM launcher guards its selected model before continuing

Teamsmith SHALL keep PM model handling inside its existing start/continue path and existing liveness/start-marker/spawn-proof rules. A running or starting PM is not restarted by policy edits. Required independent PM policy and rendering resolve identically for `up --print`, actual start, success message and settings policy; last selected model is separate. A successful Teamsmith PM start SHALL atomically record its selected complete model plus project/window, nonce/time and continuity mode alongside existing launch evidence. This is launch metadata, not a new task recovery system or inspection of Pi inference.

A continued built-in Pi start (default -c, explicit session id or configured resume args) SHALL require trusted same-project/window previously selected identical complete model; changed suffix counts as changed model. Launch metadata that is present but legacy, foreign, unknown or unreadable SHALL refuse continuation without reading session content. Absent metadata is not a claim about the past, so a continued start SHALL register the identity it is about to use instead of refusing, and SHALL say so in one line naming the model, the resume key and the continuity mode, with the note that changing the PM model requires `--fresh-pm`. A recorded selected model or resume key that differs from the current resolution SHALL still refuse continuation, and that refusal SHALL print both sides — the recorded and the current value of the model (the suffix explicitly) and of the resume key — SHALL name which of the two changed, and SHALL give both routes with their consequences: `--fresh-pm` (a new conversation; the ledger on disk is the handover and the Pi history stays where it is) and the explicit adoption below. `team up --adopt-pm-identity` SHALL be that one explicit, audited route: it declares the current resolution as this continuation's identity, writes the same launch metadata record plus one line in the project's existing configuration audit, needs `--yes` when a record already exists and differs, and never fires silently. `up --fresh-pm` permits a new model with new session identity, bypasses configured continue args for that start and retains historical materials. Failed proof/publication leaves prior launch metadata intact and no fictitious success; uncommitted PM start is stopped with diagnostic. Preview and refusal write no markers/prompts or process changes — the preview prints the registration the start would write and writes nothing. Patrol reports a continuity blocker but never auto-freshens, respawns or consumes a restart slot for it. None of this detects manual in-Pi model changes.

#### Scenario: Same-model continue and explicit fresh use the existing path
- **GIVEN** valid PM launch metadata and unchanged model
- **WHEN** up is previewed then starts a missing PM; later a different model is previewed with --fresh-pm and started
- **THEN** same-model arguments continue as configured; fresh start omits -c/session/resume settings and retains the existing extensions/skill/briefing and proof rules

#### Scenario: Changed or unknown identity cannot automatically continue
- **WHEN** a stopped PM's model or model suffix changes, or its launch metadata is legacy, foreign or unreadable
- **THEN** up/preview/patrol refuse guarded continuation with a concrete `up --fresh-pm` handover route, no session read, no new launch and no restart charge
- **AND** the refusal prints the recorded and the current model (suffix explicitly) and resume key and names which one changed; an explicitly authorized fresh start succeeds

#### Scenario: A missing record is registered, not refused
- **GIVEN** a continued start with no launch-metadata file at all
- **WHEN** `team up --print` runs, and then the real `team up` starts the PM
- **THEN** the preview prints what would be registered and still leaves the metadata file absent
- **AND** the real run starts, the record afterwards names the resolved model, resume key and continuity mode, the output carries the registration line with the `--fresh-pm` note, and nothing else about the start changes

#### Scenario: The adoption entry is explicit and audited
- **GIVEN** readable launch metadata whose recorded model or resume key differs from the current resolution
- **WHEN** `team up --adopt-pm-identity` runs without `--yes`, then with `--yes`, then `team up` runs again
- **THEN** the first run refuses and names the flag, the second writes the record, prints the declaration line and appends one audit line, and the third continues with the adopted identity

#### Scenario: Running and starting PM remain protected
- **WHEN** worker mapping or PM policy changes while PM is running or has fresh starting marker
- **THEN** up/patrol preserve pane/pid and do not restart; displays distinguish current selected model from future PM policy

#### Scenario: Failed PM publication is not liveness proof
- **WHEN** launch proof is absent or model metadata publication fails
- **THEN** command fails with diagnostics, previous metadata stays byte-identical, no success/model claim is emitted and any uncommitted new PM is stopped; normal proof state vocabulary is unchanged
