## MODIFIED Requirements

### Requirement: The pulse never manages tmux layout, agents or quota

The pulse SHALL NOT rebuild a missing session or window while `TEAM_PULSE_REBUILD_TMUX=0` (the default) — it
reports the state instead; it MUST NOT resume stopped agents; and it MUST NOT merge, change the board or spend model
quota. A stopped worker retains its assignment; patrol SHALL NOT reselect category policy or launch a fresh worker. A PM continuity/config refusal SHALL be reported with its explicit correction/fresh route, no PM launch and no consumed restart slot. Those are the PM's calls (`team up`, `team resume`).

#### Scenario: A missing window is reported, not rebuilt

- **GIVEN** `TEAM_PULSE_REBUILD_TMUX=0` and no PM window in the session
- **WHEN** a tick runs
- **THEN** the tick output reports the missing window and creates no new tmux window

#### Scenario: A stopped agent is not resumed

- **GIVEN** an agent with a recorded unfinished task whose window does not exist
- **WHEN** a tick runs with pending work
- **THEN** the agent is listed as pending work for the PM, and no agent window is started

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
the last error of the pi session file named by the current complete assignment SID and worktree. When both sources yield a cause,
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
current launch. Session evidence SHALL match the committed SID/worktree as well as current launch time; missing assignment/session identity is unavailable, not a reason to choose the base or latest session. After a restart (`team dispatch`, `team resume`) the seat SHALL show no cause until a
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

## ADDED Requirements

### Requirement: SID-linked evidence follows the committed launch rather than a neighboring session

Session-side size/activity/death readers SHALL identify the complete current assignment's SID and worktree and retain their existing bounded-read and nonce/time attribution rules. A newer neighboring session, oversized base SID, or another task's error SHALL not be attributed to the current launch. Missing identity/file is unavailable (size may be zero only for a known fresh SID not yet created); pane/recorded evidence remains available under its own rules. Dead/exited/absent workers do not consume running model concurrency, and patrol never chooses another worker model or resumes it. Synthetic fixture HOME/session files are allowed; tests SHALL NOT read real user history.

#### Scenario: Neighboring and base sessions cannot contaminate evidence
- **GIVEN** current SID A, larger base SID and newer neighboring SID B with quota error, under fixture HOME
- **WHEN** roster/ps, activity and death surfaces run
- **THEN** size/activity/errors come only from A; B/base cannot cause an overflow/death claim for A, and all reads stay bounded/read-only

#### Scenario: Live size is not the launch snapshot
- **GIVEN** fresh SID A with recorded sid_bytes=0
- **WHEN** A's synthetic file grows after launch and reads run twice
- **THEN** displayed current byte/token estimate grows, snapshot stays 0 and resume retains A; deleting A yields unavailable rather than choosing B

#### Scenario: Missing metadata and stopped workers stay honest
- **WHEN** assignment/SID is missing or malformed and a stopped seat retains an unfinished task
- **THEN** readers state unavailable identity, preserve task/evidence, count no running-model slot and patrol only notifies PM; explicit PM resume uses normal assignment guards
