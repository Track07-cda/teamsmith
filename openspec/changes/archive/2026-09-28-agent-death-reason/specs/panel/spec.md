## ADDED Requirements

### Requirement: The agents block carries each seat's death cause

`team __panel-data --block agents` (and through it the `agents` block of `team monitor --json`) SHALL add,
for every seat whose current launch has an abnormal death, `cause` (the category), `cause_source`
(`pane`, `session` or `recorded`) and `cause_line` (the raw evidence line, sanitized), plus `cause_time`
when the record time is known. A seat without an abnormal death SHALL carry none of these keys, and the
new keys MUST NOT change the existing `state` vocabulary or the `pane`/`pane_exit` keys. A running seat
MUST NOT carry a cause. The block SHALL stay read-only: no file under `.pi/team/state/` may change
contents or timestamps because of it.

The printed agent table SHALL append the category to the seat's state cell (for example
`▲ 已死 signal=9 · quota`) whenever the table renders its full state text; in its minimal layout the
token may drop with the state text, and `cause_line` stays available through the block and
`team status <ID>`.

#### Scenario: The block carries the cause for a quota corpse

- **GIVEN** the quota corpse fixture (a dead pane whose scene ends with the `403 permission_error`
  frame) with an unfinished recorded task
- **WHEN** `team __panel-data --block agents` runs
- **THEN** that seat's entry carries `cause` `quota`, `cause_source` `pane`, and a `cause_line` holding
  the raw frame — while its `state` stays `exited`, its `pane` stays `dead` and its `pane_exit` keeps the
  exit evidence

#### Scenario: A running seat carries no cause key

- **GIVEN** a seat proven alive beside the corpse of the previous scenario
- **WHEN** the agents block is read
- **THEN** the running seat's entry has no `cause`, `cause_source`, `cause_line` or `cause_time` key

#### Scenario: The printed row shows the token and the machine block keeps the raw line

- **GIVEN** the quota corpse fixture and a panel width that renders the full agent table
- **WHEN** the panel's agent table is printed
- **THEN** that seat's state cell carries `quota`, and the block's `cause_line` still carries the full raw
  frame
