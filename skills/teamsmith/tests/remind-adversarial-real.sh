#!/usr/bin/env bash
# P444: private real Pi/tmux controlled-model event, replay and process-death acceptance.
set -uo pipefail
HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$(cd -P "$HERE/.." && pwd)"
# shellcheck source=lib/main-team-fingerprint.sh
. "$HERE/lib/main-team-fingerprint.sh"
REAL_MAIN="$(main_team_project_root "$SKILL")"
STAMP="$(main_team_snapshot "${REAL_MAIN:-/nonexistent}/.pi/team")"
BEFORE="$(mktemp -p /var/tmp p444-real-before.XXXXXX)" || exit 3
AFTER="$(mktemp -p /var/tmp p444-real-after.XXXXXX)" || { rm -f "$BEFORE"; exit 3; }
printf '%s\n' "$STAMP" >"$BEFORE"
export P442_EVIDENCE="${P442_EVIDENCE:-$(mktemp -d -p /var/tmp p444-real-evidence.XXXXXX)}"
node "$HERE/remind-tool-real.mjs" --select=adversarial,death "$@"
RC=$?
main_team_snapshot "${REAL_MAIN:-/nonexistent}/.pi/team" >"$AFTER"
VIOL="$(main_team_violations "$BEFORE" "$AFTER")"
rm -f "$BEFORE" "$AFTER"
if [ -n "$VIOL" ]; then
  printf 'remind-adversarial-real: 主项目 .pi/team 出现非白名单变化：%s\n' "$VIOL" >&2
  RC=1
elif [ "$RC" -eq 0 ]; then
  printf 'remind-adversarial-real: isolation=ok evidence=%s\n' "$P442_EVIDENCE"
fi
exit "$RC"
