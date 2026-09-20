## ADDED Requirements

### Requirement: The verifier of a change is not one of its authors

When `team dispatch` starts a task whose `phase:` is `verify` for change `C`, it SHALL refuse when that task's
`agent:` is also the `agent:` of a task mapped to `C` whose `phase:` is `apply` or undeclared, excluding mapped
tasks whose board status is `dropped`. The refusal MUST name the change, the agent and the apply tasks it found,
MUST NOT change any board status, and MUST come before any window is opened (and for `--print` as well). `--force`
MUST proceed with a warning and append exactly one audit line naming the agent, the change and the authored tasks.
When a mapped task has no resolvable brief, or its header records no `agent:`, the guard MUST print which signal is
missing and proceed — an unknowable author is never reported as a clean one.

#### Scenario: One agent's apply task blocks its own verification

- **GIVEN** a change `alpha` with an apply task `M1` whose `agent:` is `dev`, and a verify task `V1` for `alpha`
  whose `agent:` is also `dev`
- **WHEN** `team dispatch dev V1 <verify-brief>` runs
- **THEN** it exits non-zero and names `alpha`, `dev` and `M1`, and opens no window

#### Scenario: A different agent verifies

- **GIVEN** the same change and a verify brief whose `agent:` is `verify`
- **WHEN** `team dispatch verify V1 <verify-brief> --print` runs
- **THEN** it is not refused and prints the prompt

#### Scenario: A dropped apply task does not block

- **GIVEN** the same change, with `M1`'s board status `dropped`
- **WHEN** `team dispatch dev V1 <verify-brief>` runs
- **THEN** it is not refused, and the message names the dropped task as excluded

#### Scenario: A missing signal is loud, not silent

- **GIVEN** a change whose apply task's brief cannot be resolved (or whose header carries no `agent:`)
- **WHEN** the verify dispatch runs
- **THEN** it proceeds and prints which signal was missing

#### Scenario: `--force` records the override

- **GIVEN** the first scenario's pair
- **WHEN** `team dispatch dev V1 <verify-brief> --force` runs
- **THEN** it proceeds, warns that the verification is no longer independent, and appends exactly one line to
  `state/watchdog.log` naming `dev`, `alpha` and `M1`
