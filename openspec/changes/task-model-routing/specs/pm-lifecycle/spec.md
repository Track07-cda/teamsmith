
## ADDED Requirements

### Requirement: The existing PM launcher guards its selected model before continuing

Teamsmith SHALL keep PM model handling inside its existing start/continue path and existing liveness/start-marker/spawn-proof rules. A running or starting PM is not restarted by policy edits. Required independent PM policy and rendering resolve identically for `up --print`, actual start, success message and settings policy; last selected model is separate. A successful Teamsmith PM start SHALL atomically record its selected complete model plus project/window, nonce/time and continuity mode alongside existing launch evidence. This is launch metadata, not a new task recovery system or inspection of Pi inference.

A continued built-in Pi start (default -c, explicit session id or configured resume args) SHALL require trusted same-project/window previously selected identical complete model; changed suffix counts as changed model. Missing/legacy/unknown manual-start metadata refuses continuation without reading session content. `up --fresh-pm` permits a new model with new session identity, bypasses configured continue args for that start and retains historical materials. Failed proof/publication leaves prior launch metadata intact and no fictitious success; uncommitted PM start is stopped with diagnostic. Preview and refusal write no markers/prompts or process changes. Patrol reports a continuity blocker but never auto-freshens, respawns or consumes a restart slot for it. None of this detects manual in-Pi model changes.

#### Scenario: Same-model continue and explicit fresh use the existing path
- **GIVEN** valid PM launch metadata and unchanged model
- **WHEN** up is previewed then starts a missing PM; later a different model is previewed with --fresh-pm and started
- **THEN** same-model arguments continue as configured; fresh start omits -c/session/resume settings and retains the existing extensions/skill/briefing and proof rules

#### Scenario: Changed or unknown identity cannot automatically continue
- **WHEN** stopped PM model/suffix changes or launch metadata is missing/legacy/foreign/manual-unknown
- **THEN** up/preview/patrol refuse guarded continuation with concrete up --fresh-pm handover route, no session read, no new launch, no restart charge; an explicitly authorized fresh start succeeds

#### Scenario: Running and starting PM remain protected
- **WHEN** worker mapping or PM policy changes while PM is running or has fresh starting marker
- **THEN** up/patrol preserve pane/pid and do not restart; displays distinguish current selected model from future PM policy

#### Scenario: Failed PM publication is not liveness proof
- **WHEN** launch proof is absent or model metadata publication fails
- **THEN** command fails with diagnostics, previous metadata stays byte-identical, no success/model claim is emitted and any uncommitted new PM is stopped; normal proof state vocabulary is unchanged
