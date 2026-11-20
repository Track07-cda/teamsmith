#!/usr/bin/env bash
# P444: real process-death injection around intent/observation atomic commits.
set -uo pipefail
HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$(cd -P "$HERE/.." && pwd)"
# shellcheck source=lib/main-team-fingerprint.sh
. "$HERE/lib/main-team-fingerprint.sh"
# shellcheck source=lib/tmp-root.sh
. "$HERE/lib/tmp-root.sh"

ROOT= DRIVER= DRIVER_START=unknown STOP=
cleanup() {
  local rc=$?
  trap '' INT TERM
  if [[ -n "$DRIVER" ]]; then
    # Let the tracked driver finish its active synchronous command before reclaiming the work.
    if [[ "$DRIVER_START" != unknown ]] && _tmp_root_proc_alive "$DRIVER" "$DRIVER_START"; then
      kill -TERM "$DRIVER"
    fi
    # The stopped driver may return nonzero; preserve the owner's result.
    wait "$DRIVER" || :
  fi
  if [[ -n "$ROOT" ]]; then
    if [[ "$TEAM_TMP_KEEP" == 1 ]]; then printf 'kept fault evidence=%s\n' "$ROOT"; fi
    # The driver has exited; the helper must not signal the former PID.
    rm -f -- "$TMP_ROOT_PIDFILE" || exit "$((rc == 0 ? 3 : rc))"
    tmp_root_reap_all
  fi
  exit "$rc"
}
trap cleanup EXIT
# Don't enter cleanup between starting a child and recording its identity.
trap 'STOP=${STOP:-130}' INT
trap 'STOP=${STOP:-143}' TERM

TEAM_TMP_KEEP=0
if [[ -n "${P444_KEEP:-}" ]]; then TEAM_TMP_KEEP=1; fi
ROOT="$(tmp_root_create remind-faults)" || exit 3
printf 'remind-adversarial-faults: work=%s %s\n' "$ROOT" "$(team_tmp_root_note)"
TMP_ROOT_PIDFILE="$ROOT/.driver.pid"

# A direct Node invocation uses the same lifetime without the shell entry's fingerprint.
DIRECT_NODE="${_P444_NODE:-}"
unset _P444_NODE
if [[ -z "$DIRECT_NODE" ]]; then
  REAL_MAIN="$(main_team_project_root "$SKILL")"
  BEFORE="$ROOT/.main-before"
  AFTER="$ROOT/.main-after"
  main_team_snapshot "${REAL_MAIN:-/nonexistent}/.pi/team" >"$BEFORE" || exit 3
fi

[[ -z "$STOP" ]] || exit "$STOP"
_P444_WORK="$ROOT" "${DIRECT_NODE:-node}" "$HERE/remind-adversarial-faults.mjs" "$@" <&0 &
DRIVER=$!
if ! DRIVER_START="$(_tmp_root_proc_start "$DRIVER")"; then
  # A child that has already exited has no live identity to record.
  DRIVER_START=unknown
else
  tmp_root_track_pid "$DRIVER" remind-fault-driver || exit 3
fi
trap 'exit 130' INT
trap 'exit 143' TERM
[[ -z "$STOP" ]] || exit "$STOP"
RC=0
wait "$DRIVER" || RC=$?
DRIVER=
[[ -z "$DIRECT_NODE" ]] || exit "$RC"

main_team_snapshot "${REAL_MAIN:-/nonexistent}/.pi/team" >"$AFTER" || exit 3
VIOL="$(main_team_violations "$BEFORE" "$AFTER")" || exit 3
rm -f -- "$BEFORE" "$AFTER" || exit 3
if [ -n "$VIOL" ]; then
  printf 'remind-adversarial-faults: 主项目 .pi/team 出现非白名单变化：%s\n' "$VIOL" >&2
  RC=1
elif [ "$RC" -eq 0 ]; then
  printf 'remind-adversarial-faults: isolation=ok\n'
fi
exit "$RC"
