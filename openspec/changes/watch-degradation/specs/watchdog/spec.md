## ADDED Requirements

### Requirement: A live degraded channel is reported by `team doctor` and `team status`

When a live `state/inbox-watch/<key>.degraded` record exists for the project's PM target — its `pid` is alive and its
`cwd` is inside the project, the same evidence rule `.reg` and `.skip` use — `team doctor` and `team status` SHALL
print one degradation line for the wake channel carrying the token `投递通道降级`, the recorded `errno`, the recorded
quota (`watches <used>/<max>`), the fact that the channel fell back to polling (`轮询`), and the remedy
(`fs.inotify.max_user_watches=524288`). While the target has a live registration and no live degraded record, the
degradation line MUST NOT appear — the channel check may report the registration as healthy. A record whose `pid` is
dead or whose `cwd` is outside the project MUST NOT produce the line. A degraded-but-registered target MUST NOT be
reported with the missing-registration wording (`没有 inbox-watch 注册`) or with the "no registration" remedy
(restart the PM process): the registration exists and only the wake mechanism degraded.

#### Scenario: A dry host is named, not reported as healthy

- **GIVEN** a fixture project whose PM target has a live registration and a live `.degraded` record with
  `errno=ENOSPC` and `watches=65312/65536`
- **WHEN** `team doctor` and `team status` run
- **THEN** both outputs contain `投递通道降级`, `ENOSPC`, `65312/65536` and `524288`
- **AND** neither output contains `没有 inbox-watch 注册`, and the doctor check line is a warning, not a pass

#### Scenario: A stale record is not evidence

- **GIVEN** the same record whose `pid` no longer exists
- **WHEN** `team doctor` and `team status` run
- **THEN** neither output contains `投递通道降级`

#### Scenario: A healthy channel stays quiet

- **GIVEN** a fixture project whose PM target has a live registration and no `.degraded` record
- **WHEN** `team status` runs
- **THEN** the output contains no `投递通道降级` line

### Requirement: `team doctor` reports the inotify headroom of the wake channel

`team doctor` SHALL print one inotify headroom line for the wake channel carrying: the value of
`/proc/sys/fs/inotify/max_user_watches` (or that it cannot be read), the current user's counted inotify watch usage
only when a complete same-UID scope can be established (otherwise `unknown` — a partial count MUST NOT be presented
as the total), and a one-shot registration probe verdict — `ok`, the errno, or `unavailable` when no JS runtime
resolves.
The probe registers one watch on a private temporary directory and removes it; its verdict, not the counted usage,
is what decides the warning. The line MUST warn — without making `team doctor` exit non-zero — when the probe is not
`ok` or when the known headroom is below `TEAM_INOTIFY_MIN_FREE` (default 1024, non-numeric falls back), and the
warning MUST name the remedy `fs.inotify.max_user_watches=524288` together with Syncthing and VSCode as common
consumers of the quota. Raising the quota is an operator action: no command of this tool may attempt it.

#### Scenario: A working host reports the quota and the probe verdict

- **GIVEN** an environment where a watch registers and the default threshold
- **WHEN** `team doctor` runs
- **THEN** exactly one line names the inotify headroom, carries the `max_user_watches` value and the verdict `ok`
- **AND** `team doctor`'s exit status is unchanged by this check

#### Scenario: A low headroom warns with the fix

- **GIVEN** `TEAM_INOTIFY_MIN_FREE` set above the known free headroom
- **WHEN** `team doctor` runs
- **THEN** the line is a warning naming `524288`, `Syncthing` and `VSCode`
- **AND** `team doctor` does not fail on this check

#### Scenario: A probe that cannot register is a visible warning

- **GIVEN** a fixture whose resolved JS runtime makes the probe report `errno=ENOSPC`
- **WHEN** `team doctor` runs
- **THEN** the line names `ENOSPC` and the remedy, and the check is a warning rather than a pass

#### Scenario: Without a runtime the probe says unavailable, never ok

- **GIVEN** an environment where no JS runtime resolves
- **WHEN** `team doctor` runs
- **THEN** the line reports the probe as `unavailable` and warns, and it does not claim the headroom is fine
