## ADDED Requirements

### Requirement: A seat-death knock carries the seat, the cause and the raw evidence line, and never invents a cause

A seat-death knock SHALL be enqueued through the delivery guard as a `knock` entry — queued while the PM
window's input box is busy, never typed over a draft — with `--from pulse`, and it SHALL name the seat,
the classified cause, the source the cause was read from, and the raw evidence line, plus the command
that shows the scene (`team status <ID>`). For an `unknown` death the knock SHALL state that the cause
could not be determined and MUST NOT name any of the other categories; a knock for a `normal` exit MUST
NOT exist. The knock's dedup key SHALL be the death's identity
(`watchdog#A cause belongs to the current launch of a seat, never to a previous one`), so the delivery
guard's at-most-once delivery and the patrol's record agree on what "the same death" is.

#### Scenario: A quota knock carries the raw frame

- **GIVEN** the quota corpse fixture and an unreported `quota` death
- **WHEN** the patrol tick delivers the death knock
- **THEN** the delivered payload names the seat, `quota`, the source and the raw
  `Error: 403 permission_error: reached your weekly (7-day) usage limit` line, and it names
  `team status <ID>` as the scene command

#### Scenario: An unknown knock does not pretend

- **GIVEN** a death whose evidence is unreadable or matches no shape
- **WHEN** its knock is delivered
- **THEN** the payload carries `unknown` and a "cause could not be determined" wording, and it contains
  none of `quota`, `balance`, `rate_limit`, `window` or `auth` as a claimed category

#### Scenario: A busy PM input box queues the knock instead of gluing it

- **GIVEN** the PM window's input box holding a draft and an unreported abnormal death
- **WHEN** the patrol tick runs
- **THEN** the PM window still shows exactly that draft, the knock is one entry in the delivery queue
  (`team outbox list`), no text was typed into the PM window, and `state/deaths.log` holds the one record
  line for that death
