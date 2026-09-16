#!/usr/bin/env bash
# A deliberately slow `team __panel-data` stand-in for the compose-pause fixture
# (pulse-console B2, tasks.md 2.5).
#
# The panel is pointed at this stub with `--team-cli`; every `__panel-data` request sleeps
# `TEAM_B2_SLOW_SLEEP` seconds (default 4) and every other request is forwarded to the real CLI
# unchanged, so the compose entry can be exercised while an assembly is genuinely in flight.
set -uo pipefail

real="${TEAM_B2_REAL_CLI:?panel-b2-slow-stub: TEAM_B2_REAL_CLI is required}"
sleep_s="${TEAM_B2_SLOW_SLEEP:-4}"

for a in "$@"; do
  if [ "$a" = "__panel-data" ]; then
    sleep "$sleep_s"
    break
  fi
done
exec bash "$real" "$@"
