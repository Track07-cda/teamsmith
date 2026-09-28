## ADDED Requirements

### Requirement: A seat death has a classified cause from a closed set, and an unknown death is never given one

When a seat with an unfinished recorded task is not running (its window is gone, its agent has exited, or
a dead pane is retained), the classification SHALL answer with one category from the closed set `quota`
(quota / usage limit), `balance` (insufficient balance), `rate_limit`, `window` (context overflow),
`auth`, `normal` (clean exit) or `unknown`, and the read-only surfaces SHALL report it whenever it is an
abnormal death (any category except `normal`). A category other than `normal` and `unknown` SHALL require the
vendor error's shape on the evidence line — an error frame (a line framed as `Error:`/`error:`, an HTTP
status beside a provider error code such as `403 permission_error`, or a JSON error object) together with
that category's wording. A line that merely mentions a term (`quota`, `额度`, `rate limit`) without that
shape MUST NOT produce that category. The classification SHALL read only a bounded tail: at most
`TEAM_DEATH_SCAN_LINES` lines of the pane-side scene (default 40; a non-numeric value falls back to the
default) and a bounded tail of the pi session file.

The cause SHALL be derived from two evidence sources, naming the one it read: ① the tmux corpse scene, in
the recency order the seat's scene block already uses (a retained dead pane's screen read with its
scrollback, then `state/dispatch-<agent>-pane-dead.txt`, then `state/dispatch-<agent>-tail.txt`), and ②
the last error of the newest pi session file for the seat's worktree. When both sources yield a cause,
the more specific one SHALL win — a category other than `unknown` over `unknown`, then the newer record
time, then the session source — and the reported source SHALL name which one was read. When neither
source is readable or no shape matches, the cause SHALL be `unknown`: the surfaces MUST NOT guess a
category. The raw evidence line SHALL be kept beside the category on every surface that reports it.

`normal` SHALL require positive clean-exit evidence — the current launch's exit evidence exists with
status `0`, or the retained pane is dead with `pane_dead_status=0` — and MUST NOT be treated as an
abnormal death: it produces no cause line, no death record and no knock. A death showing a non-zero or
signal exit without a recognized error frame is `unknown`, not `normal`.

#### Scenario: A synthetic quota frame classifies as quota with its raw line

- **GIVEN** a fixture seat whose corpse scene ends with
  `Error: 403 permission_error: reached your weekly (7-day) usage limit` and whose recorded task is
  unfinished
- **WHEN** the seat surfaces run (`team status <ID>` and `team __panel-data --block agents`)
- **THEN** the cause is `quota`, the reported source is the pane, and the raw line above appears beside it

#### Scenario: A provider frame that also looks like an auth error stays quota

- **GIVEN** the fixture of the previous scenario (a `403 permission_error` carrying `usage limit`)
- **WHEN** the surfaces report the cause
- **THEN** the category is `quota` and not `auth`

#### Scenario: Prose that merely mentions a term is not a classification

- **GIVEN** a fixture seat whose corpse scene's last lines are prose containing `quota` with no error
  frame and no provider error shape
- **WHEN** the patrol classifies that death
- **THEN** the cause is `unknown`, no category is claimed, and the prose line is kept as the raw line

#### Scenario: No readable evidence is an unknown death, never a guess

- **GIVEN** a fixture seat with a recorded unfinished task, no window and no readable session file
- **WHEN** its death is read
- **THEN** the cause is `unknown`, the output states that no source could be read, and no category wording
  appears

#### Scenario: A clean exit is not an abnormal death

- **GIVEN** a fixture seat whose latest launch wrote exit evidence with status `0` and whose scene has no
  error frame, with a recorded unfinished task
- **WHEN** a patrol tick and the seat surfaces run
- **THEN** no cause line appears, `state/deaths.log` gains no record for it, and no knock is sent

### Requirement: A cause belongs to the current launch of a seat, never to a previous one

Every reported cause SHALL carry an identity of `(seat, category, anchor)`, where the anchor is the seat's
current launch nonce when the evidence belongs to that launch, else the dead pane's `pane_dead_time`, else
its pane id, else a hash of the raw line. Evidence whose record time is older than the seat's recorded
`started` — or whose exit-evidence nonce is not the current launch's — MUST NOT be attributed to the
current launch. After a restart (`team dispatch`, `team resume`) the seat SHALL show no cause until a
death of the new launch has its own evidence, and a death of the same category after a restart SHALL be a
new identity (a new record and a new knock).

#### Scenario: A restart does not inherit the old cause

- **GIVEN** a fixture seat whose current launch died with a classified `quota` cause
- **WHEN** the seat is re-dispatched (a new launch nonce and `started`) and its surfaces run
- **THEN** no cause from the previous launch is shown on `team status`, `team digest` or the agents block

#### Scenario: One death keeps one identity across ticks

- **GIVEN** the quota death of the first scenario and its record in `state/deaths.log`
- **WHEN** the patrol runs three ticks without new evidence
- **THEN** the death keeps one identity and the record file gains no second line for it

#### Scenario: A second death after a restart is a new death

- **GIVEN** the same seat, restarted, whose new launch dies with the same category and the same wording
- **WHEN** its cause is read
- **THEN** the identity differs from the previous death's (the anchor is the new launch) and the surfaces
  report the new death

### Requirement: The seat surfaces name the cause, its source and the raw evidence line

`team status <ID>` SHALL print, for the seat that records that task, the seat's condition and — when the
seat has an abnormal death — one cause line carrying the category, the source it was read from
(`pane`, `session` or `recorded`), the record time when known, and the raw evidence line. `team digest`
[1] SHALL name each stopped seat's category beside the `停了的 agent` count instead of the bare count.

These readers SHALL remain read-only — no file under `.pi/team/state/` may change contents or timestamps
because of them — and a running seat, or a seat whose task was finished (`team close --keep-window`),
SHALL show no cause. When the live evidence is no longer readable, a surface SHALL fall back to the newest
`state/deaths.log` record whose anchor belongs to the seat's current launch, labelled as recorded;
without such a record it SHALL print no cause rather than a guess.

#### Scenario: status prints the cause, its source and the raw line

- **GIVEN** the quota corpse fixture with the dead pane retained and an unfinished recorded task
- **WHEN** `team status <ID>` runs
- **THEN** the output names the seat, its condition, the cause `quota`, the source `pane` and the raw
  `403 permission_error` line

#### Scenario: digest names the category beside the count

- **GIVEN** the same fixture and one more stopped seat with no readable evidence
- **WHEN** `team digest` runs
- **THEN** the `停了的 agent` count in [1] names the first seat as `quota` and the second as `unknown`

#### Scenario: A finished or running seat shows no cause

- **GIVEN** a fixture seat whose task was closed with `team close <ID> --keep-window`, and a seat proven
  alive, both beside a corpse scene holding an error frame
- **WHEN** `team status <ID>` and `team digest` run
- **THEN** neither the closed seat nor the running seat carries a cause line

#### Scenario: The recorded fallback covers a vanished scene

- **GIVEN** a seat whose death was recorded in `state/deaths.log`, whose corpse scene was then removed
  and whose window is gone
- **WHEN** `team status <ID>` runs
- **THEN** the cause is reported with source `recorded` and the raw line from the record, and no newer
  death is invented

### Requirement: The patrol reports each abnormal death exactly once, and never a normal one

On each tick the patrol SHALL classify the current launch's death of every seat with an unfinished
recorded task that is not running. When the category is not `normal` **and at least one source is
readable** (a pane-side scene, tail or exit evidence, or a session-side error), it SHALL append one
record to `state/deaths.log` for the death's identity and enqueue exactly one knock for it, writing the record
before the knock so that a crash cannot produce a second one. A repeated tick for the same identity MUST
send nothing new; `normal` MUST produce no record and no knock; `unknown` SHALL be reported as unknown and
the knock MUST NOT name a cause. A stopped seat with no readable source SHALL still be classified and
surfaced as `unknown` and named by the pending summary, but MUST NOT produce a dedicated knock (there is
nothing to carry beyond the standing wake line). Under `team standby on` no knock is sent (the standing
rule) and the death stays unreported until a tick can deliver it, after which it is sent exactly once.
The pending summary the patrol already computes SHALL name the stopped seats with their categories, so
the existing PM start path still carries the reason.

#### Scenario: Three ticks on one death produce exactly one knock and one record

- **GIVEN** the quota corpse fixture and a PM window that is running (or absent, with the outbox draining
  later)
- **WHEN** `team watch --once` runs three times
- **THEN** `state/deaths.log` holds one record line for that identity and the delivery queue holds one
  knock for it, with no second entry after the second and third ticks

#### Scenario: A garbage frame knocks once as unknown

- **GIVEN** a fixture seat whose corpse scene's last frame is an unrecognized error line
- **WHEN** the patrol runs
- **THEN** exactly one knock is sent, it names the seat and the category `unknown`, and it names no other
  category and makes no cause claim

#### Scenario: A normal exit is silent

- **GIVEN** the clean-exit fixture of the first requirement (exit status `0`, no error frame)
- **WHEN** the patrol runs
- **THEN** no record and no knock are produced for it

#### Scenario: Standby defers the knock instead of losing it

- **GIVEN** `team standby on --reason "…"` and an unrecorded abnormal death
- **WHEN** a tick runs under standby and a later tick runs after `team standby off`
- **THEN** the standby tick sends nothing, the later tick sends exactly one knock for that death, and a
  further tick sends nothing more

#### Scenario: A death with no readable source is named, not knocked twice

- **GIVEN** a stopped seat with an unfinished task, no window, no corpse and no readable session file
- **WHEN** the patrol runs
- **THEN** the pending summary names it as `unknown`, no dedicated death knock and no `state/deaths.log`
  record are produced for it, and no category is claimed
