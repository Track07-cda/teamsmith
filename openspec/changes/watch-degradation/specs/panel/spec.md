## ADDED Requirements

### Requirement: The delivery warning covers a degraded wake channel

The panel's PM block (`team __panel-data --block pm`) SHALL set `delivery_warning` in two classes: the PM target has
no live inbox-watch registration, or it has a live registration whose watcher is degraded (a live
`state/inbox-watch/<key>.degraded` record). The console SHALL render a non-empty `delivery_warning` as its own
status line carrying a text token as well as colour, and MUST omit that line while the field is empty. The warning
MUST name the consequence that matches the class: a missing registration falls back to the input-box paste path
(`delivery-guard` owns that path), while a degraded watcher keeps the spool channel and only slows the wake to the
polling cadence — the degraded class MUST NOT be described as falling back to the paste path. The wording SHALL come
from the same reader `team doctor` and `team status` use, so one condition never produces two stories.

#### Scenario: A degraded watcher is visible and named correctly

- **GIVEN** a fixture project whose PM target has a live registration and a live `.degraded` record with
  `errno=ENOSPC` and `watches=65312/65536`
- **WHEN** `team __panel-data --block pm` and `team monitor --print` run
- **THEN** `delivery_warning` is non-empty and names `ENOSPC` or the polling fallback
- **AND** the printed frame carries the delivery-degraded line with that text
- **AND** neither the field nor the line says the notification falls back to the paste path

#### Scenario: The missing-registration class keeps its own wording

- **GIVEN** a live `.skip` record with `reason=session-mismatch` and no live registration
- **WHEN** `team __panel-data --block pm` and `team monitor --print` run
- **THEN** `delivery_warning` names the session mismatch and the paste-path consequence it names today

#### Scenario: A healthy channel shows no warning line

- **GIVEN** a fixture project whose PM target has a live registration and no `.degraded` record
- **WHEN** `team monitor --print` runs
- **THEN** the frame carries no delivery warning line and `delivery_warning` is the empty string
