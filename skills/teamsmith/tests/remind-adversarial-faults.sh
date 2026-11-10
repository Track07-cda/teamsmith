#!/usr/bin/env bash
# P444: real process-death injection around intent/observation atomic commits.
set -uo pipefail
HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$(cd -P "$HERE/.." && pwd)"
# shellcheck source=lib/main-team-fingerprint.sh
. "$HERE/lib/main-team-fingerprint.sh"
REAL_MAIN="$(main_team_project_root "$SKILL")"
STAMP="$(main_team_snapshot "${REAL_MAIN:-/nonexistent}/.pi/team")"
BEFORE="$(mktemp -p /var/tmp p444-fault-before.XXXXXX)" || exit 3
AFTER="$(mktemp -p /var/tmp p444-fault-after.XXXXXX)" || { rm -f "$BEFORE"; exit 3; }
printf '%s\n' "$STAMP" >"$BEFORE"
node "$HERE/remind-adversarial-faults.mjs" "$@"
RC=$?
main_team_snapshot "${REAL_MAIN:-/nonexistent}/.pi/team" >"$AFTER"
VIOL="$(main_team_violations "$BEFORE" "$AFTER")"
rm -f "$BEFORE" "$AFTER"
if [ -n "$VIOL" ]; then
  printf 'remind-adversarial-faults: 主项目 .pi/team 出现非白名单变化：%s\n' "$VIOL" >&2
  RC=1
elif [ "$RC" -eq 0 ]; then
  printf 'remind-adversarial-faults: isolation=ok\n'
fi
exit "$RC"
