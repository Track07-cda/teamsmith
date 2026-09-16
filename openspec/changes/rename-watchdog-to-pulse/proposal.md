## Why

D22 (user pick, 2026-09-15): `watchdog` names behavior this skill deliberately does not have — a daemon that keeps
a process alive. What exists is a metronome that wakes the PM only when there is work. The name is part of the
contract (`team watchdog`, the `watchdog` window, `TEAM_WATCH_*`), and D19's
dashboard rewrite must start from the new names. This change is the migration design.

## What Changes

- **New surface**: `team pulse up|down|restart|status|logs` (bare `team pulse` = status), default window
  `TEAM_PULSE_WINDOW=pulse`, `TEAM_PULSE_*` variables. `team watch` (manual tick), `team monitor` (panel) and
  `TEAM_MONITOR_*` keep their names — D22 scoped the rename to the command group, the window and the env prefix.
- **Aliases for one major version (v1.32.0 → v2.0.0)**: `team watchdog …`, `watchdog-status`,
  `install-/uninstall-watchdog` and the `--no-watchdog` flags keep working and print one deprecation line; legacy
  `TEAM_WATCH_*` values stay readable with precedence new > old > default, and the legacy variable in use is named
  by `team pulse status`, `team doctor` and `team paths`.
- **State files keep their names** (`state/watchdog.log|pid|last|nudge|tick.log`) for the alias period: a window
  still running pre-upgrade code shares the pid lock and the nudge signature with the new one, and two lock names
  would let two patrols run. The alias-drop change renames them.
- **Existing projects migrate explicitly**: `status`/`logs`/`doctor` recognize a running `teamsmith:watchdog`
  window as legacy; `team pulse up` refuses to add a second patrol and points at `team pulse restart`, which leaves
  exactly one window named `pulse`.
- **The spec capability stays `watchdog`** — all six requirements get MODIFIED deltas that rename the surface, and
  the alias/legacy/migration promises are ADDED inside it. `design.md` records the tested alternative (new `pulse`
  capability + `retire_capabilities`) and why it was rejected.
- **Apply phase** (two briefs): A1 behavior (dispatch, resolution, window migration, doctor/paths, help, templates,
  smoke); A2 docs + CHANGELOG + version. CHANGELOG history keeps the old name.

## Impact

Archive restates six requirements and adds four inside the same capability; none is created or deleted. The
Purpose and title of `openspec/specs/watchdog/spec.md` are the PM's edit in the archive commit — archive refuses
with "delta Purpose ignored … edit … directly". No code, test or doc file changes in this phase.

## Acceptance (verbatim)

```sh
openspec validate --all --strict
bash skills/teamsmith/tests/spec-lint.sh
rm -rf /tmp/p7-archive && mkdir -p /tmp/p7-archive && cp -r openspec /tmp/p7-archive/ && (cd /tmp/p7-archive && openspec archive -y rename-watchdog-to-pulse)
git status --porcelain
```

## Boundaries

- Only `openspec/changes/rename-watchdog-to-pulse/**` and `docs/team/reports/P7-dev2.md` (plus its evidence
  directory) may be written in this phase; `openspec/specs/**`, code, tests and docs belong to the apply phase,
  behind the PM's ACCEPTED proposal review.
- Out of scope: the D19 dashboard rewrite, P5's delivery guard, renames of `team watch`/`team monitor`/
  `TEAM_MONITOR_*`, and the follow-up change that drops the aliases and renames the state files.

## Evidence the report must contain

The surface inventory with its grep commands and counts, the six archive probes behind the capability decision
(`design.md` §2), the scratch archive output, and the gate tails.
