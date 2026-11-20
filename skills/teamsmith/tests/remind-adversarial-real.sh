#!/usr/bin/env bash
# P444: private real Pi/tmux controlled-model event, replay and process-death acceptance.
set -uo pipefail
HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$(cd -P "$HERE/.." && pwd)"
# shellcheck source=lib/main-team-fingerprint.sh
. "$HERE/lib/main-team-fingerprint.sh"
# shellcheck source=remind-tool-real.sh
. "$HERE/remind-tool-real.sh"

remind_tool_real_prepare || exit $?
REAL_MAIN="$(main_team_project_root "$SKILL")"
BEFORE="$remind_root/.main-before"
AFTER="$remind_root/.main-after"
main_team_snapshot "${REAL_MAIN:-/nonexistent}/.pi/team" >"$BEFORE" || exit 3
remind_tool_real_run --select=adversarial,death "$@"
RC=$?
# Setup errors also return through the owner's EXIT cleanup.
main_team_snapshot "${REAL_MAIN:-/nonexistent}/.pi/team" >"$AFTER" || exit 3
VIOL="$(main_team_violations "$BEFORE" "$AFTER")" || exit 3
rm -f -- "$BEFORE" "$AFTER" || exit 3
if [ -n "$VIOL" ]; then
  printf 'remind-adversarial-real: 主项目 .pi/team 出现非白名单变化：%s\n' "$VIOL" >&2
  RC=1
elif [ "$RC" -eq 0 ]; then
  printf 'remind-adversarial-real: isolation=ok evidence=%s\n' "$remind_evidence"
fi
exit "$RC"
