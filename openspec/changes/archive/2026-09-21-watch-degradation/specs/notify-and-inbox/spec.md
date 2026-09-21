## ADDED Requirements

### Requirement: A watcher registration failure is recorded with its cause

When the inbox-watch extension cannot register its `fs.watch` watcher for the session's target, it SHALL record the
failure in two places instead of the bare line it writes today:

- one `state/inbox-watch.log` line of the form
  `watch unavailable: errno=<E> watches=<used>/<max> poll_ms=<n> fallback=polling`, where `<E>` is the error code
  (`ENOSPC`, …), `<max>` is `/proc/sys/fs/inotify/max_user_watches`, `<used>` is the user's current inotify watch
  usage only when a complete same-UID scope can be established and `unknown` otherwise, and `<n>` is the effective
  poll interval; a failure
  forced by the fixture knob (`TEAM_INBOX_WATCH_FORCE_FAIL=<E>`) MUST additionally carry `forced=1`;
- a durable KEY=VALUE record `state/inbox-watch/<key>.degraded` carrying `version=1`, `target`, `key`,
  `reason=watch-unavailable`, `errno`, `watches=<used>/<max>`, `poll_ms`, `forced`, `since`, `pid`, `cwd` and
  `heartbeat`.

The record SHALL be believed only while its `pid` is alive and its `cwd` is inside the project (the same evidence
rule `.reg` and `.skip` already use) and MUST be removed when a later registration for the same target succeeds or
the session shuts down. The failure MUST NOT delete or replace the target's `.reg`: senders keep routing to the
inbox-watch spool and MUST NOT be pushed back to the input-box paste path by this degradation. Why a second record
next to `.reg`/`.skip`, and why the usage is best-effort: `references/troubleshooting.md`.

#### Scenario: A dry host leaves both traces

- **GIVEN** a session whose watcher registration fails with `ENOSPC` and whose user holds `65312` of `65536` watches
- **WHEN** `session_start` completes
- **THEN** `state/inbox-watch.log` holds one line containing `watch unavailable: errno=ENOSPC`, `watches=65312/65536`
  and `fallback=polling`
- **AND** `state/inbox-watch/<key>.degraded` exists and carries `reason=watch-unavailable`, `errno=ENOSPC`,
  `watches=65312/65536`, `poll_ms=`, a live `pid` and a `cwd` inside the project

#### Scenario: An uncountable quota still names the failure

- **GIVEN** the same failure while the usage cannot be counted
- **WHEN** the failure is recorded
- **THEN** both traces carry `watches=unknown/65536` and the `errno` is still named

#### Scenario: The forced knob is marked as forced

- **GIVEN** `TEAM_INBOX_WATCH_FORCE_FAIL=ENOSPC`
- **WHEN** a session starts
- **THEN** the ledger line and the record carry `errno=ENOSPC` and `forced=1`, and the record's `watches` field has
  the `<used>/<max>` shape

#### Scenario: Success clears the stale record and keeps the registration

- **GIVEN** a live `<key>.degraded` record left by a previous session for the same target
- **WHEN** a session registers its watcher successfully
- **THEN** that record no longer exists
- **AND** the target's `.reg` is present, so `team_inbox_watch_route` still resolves the target

### Requirement: Delivery continues on the polling fallback while watching is unavailable

While the watcher registration has failed, a spool line appended for the target MUST still produce exactly one wake
within three effective poll intervals of its append, the wake MUST keep the shape a live-watcher session sends (one
`team-inbox` message, `triggerTurn` and `deliverAs: followUp`, the inbox path and a truncated preview, no payload
dump), and the ledger MUST name the fallback mode on the failure line and the delivery on its wake line. The
fallback MUST NOT change the default poll interval (`TEAM_INBOX_WATCH_POLL_MS`, default 5000), MUST NOT reorder or
alter spool semantics (`notify-and-inbox` owns them unchanged), and MUST NOT be reported as a delivery failure.

#### Scenario: A forced failure still wakes within the poll cadence

- **GIVEN** a session started with `TEAM_INBOX_WATCH_FORCE_FAIL=ENOSPC` and `TEAM_INBOX_WATCH_POLL_MS=200`
- **WHEN** one spool line is appended for the target
- **THEN** within 600 ms the session has received exactly one wake naming that line
- **AND** the ledger holds the failure line with `fallback=polling` and a `wake n=1 …` line for it
- **AND** the target's `.reg` is present

#### Scenario: The fallback wake is not a new message shape

- **GIVEN** the same forced-failure session
- **WHEN** the wake arrives
- **THEN** its `customType` is `team-inbox`, `opts.triggerTurn` is true and `opts.deliverAs` is `followUp`, the body
  names `docs/team/inbox/<inbox>.md`, and the payload text appears only inside the truncated preview

### Requirement: The inbox-watch gate measures an unavailable watcher visibly and has a strict path

Before judging assertions that require a working `fs.watch`, the inbox-watch harness SHALL measure one registration
on a private temporary directory and print `TEAM-IW-PREREQ watch=ok` or a line naming the errno, quota observation
and strict state. An explicit `TEAM_INBOX_WATCH_FORCE_FAIL=<E>` fixture control SHALL exercise that same unavailable
premise without registering a real watch and SHALL mark the premise `forced=1`; otherwise the preflight MUST attempt
the real registration. The harness SHALL clear inherited `TEAM_*`, `TMUX` and `TMUX_PANE` identity, then restore only
its fixed fixture-control allowlist (`TEAM_INBOX_WATCH_FORCE_FAIL`, `TEAM_IW_REQUIRE_WATCH`, `TEAM_IW_ONLY` and
`TEAM_IW_KEEP`).

When the measured premise is unavailable, every explicitly marked watcher-dependent case SHALL print
`TEAM-IW-CASE SKIP <case> :: <reason>` and count as neither PASS nor FAIL; the harness and smoke section SHALL name
the skipped cases and measured reason, rather than silently passing. Cases that prove the polling fallback SHALL still
run. With `TEAM_IW_REQUIRE_WATCH=1`, the same watcher-dependent cases MUST instead print `FAIL` naming the premise
and the harness MUST exit non-zero. The strict switch MUST NOT be inferred from `CI`, and no assertion, threshold or
red line may be weakened or made unconditionally green.

#### Scenario: A forced unavailable premise skips only the watcher path

- **GIVEN** `TEAM_INBOX_WATCH_FORCE_FAIL=ENOSPC` and `TEAM_IW_ONLY=S2,S22,S23`
- **WHEN** the harness runs
- **THEN** its prerequisite line names `ENOSPC` and `forced=1`, S2 prints `SKIP`, and the polling-fallback S22/S23
  cases print `PASS`
- **AND** the harness exits 0 and the smoke section reports S2 as skipped with that premise

#### Scenario: Strict mode refuses the same unavailable premise

- **GIVEN** the same forced premise with `TEAM_IW_REQUIRE_WATCH=1` and `TEAM_IW_ONLY=S2`
- **WHEN** the harness runs
- **THEN** S2 prints `FAIL` naming the watch premise and the harness exits non-zero

#### Scenario: A real available watcher keeps its coverage

- **GIVEN** an environment where the private preflight watch registers and no force control
- **WHEN** the harness runs
- **THEN** the prerequisite line is `watch=ok` and each watcher-dependent case reports its normal PASS or FAIL
  verdict, never `SKIP`
