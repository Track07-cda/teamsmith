#!/usr/bin/env bash
# P442: private real Pi/tmux and controlled loopback model only; never the live team or credentials.
TESTS="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read only the scenes the driver actually sent to its private pane. The launch receipt
# is written immediately before exec, so it names Pi itself, not launch.sh or tmux.
remind_tool_real_pi_writers() {
  [[ -n "$remind_root" && -f "$remind_root/.pi-scenes" ]] || return 0
  local scene root relative_receipt receipt pid started cwd uncertain=0
  while IFS=$'\t' read -r scene relative_receipt; do
    root="$(realpath -e -- "$remind_work/$scene")" || { uncertain=1; continue; }
    receipt="$root/$relative_receipt"
    if [[ ! -f "$receipt" ]] || ! IFS= read -r pid < "$receipt" || [[ ! "$pid" =~ ^[1-9][0-9]*$ || "$pid" == 1 ]]; then
      printf 'remind-tool-real: no Pi launch identity for %s\n' "$scene" >&2
      uncertain=1
      continue
    fi
    if [[ ! -d "/proc/$pid" ]]; then continue; fi
    if started="$(_tmp_root_proc_start "$pid")"; then
      if ! _tmp_root_proc_alive "$pid" "$started"; then continue; fi
      if cwd="$(team_proc_cwd "$pid")" && [[ "$cwd" == "$root" || "$cwd" == "$root/"* ]]; then
        printf '%s:%s\n' "$pid" "$started"
        continue
      fi
    fi
    # The process may have exited while we were reading its identity.
    if [[ -d "/proc/$pid" ]]; then
      printf 'remind-tool-real: cannot identify private Pi %s for %s\n' "$pid" "$scene" >&2
      uncertain=1
    fi
  done < "$remind_root/.pi-scenes"
  return "$uncertain"
}

remind_tool_real_wait_pi() {
  local pid started current deadline=$((SECONDS + 10))
  while IFS=: read -r pid started; do
    [[ -n "$pid" ]] || continue
    while [[ -d "/proc/$pid" ]]; do
      if ! current="$(_tmp_root_proc_start "$pid")"; then
        [[ ! -d "/proc/$pid" ]] && break
        printf 'remind-tool-real: cannot read exit identity of Pi %s\n' "$pid" >&2
        return 1
      fi
      [[ "$current" == "$started" ]] || break
      _tmp_root_proc_alive "$pid" "$started" || break
      if (( SECONDS >= deadline )); then
        printf 'remind-tool-real: private Pi %s has not exited\n' "$pid" >&2
        return 1
      fi
      sleep 0.05
    done
  done <<< "$1"
  return 0
}

remind_tool_real_cleanup() {
  local rc=$? failure writers uncertain=0
  trap '' INT TERM
  if [[ -n "$remind_driver" ]]; then
    # TERM works even if the background child has not installed its INT handler yet.
    if [[ "$remind_driver_start" != unknown ]] && _tmp_root_proc_alive "$remind_driver" "$remind_driver_start"; then
      kill -TERM "$remind_driver"
    fi
    # An interrupted driver returns nonzero; keep the owner's original result.
    wait "$remind_driver" || :
  fi

  # Snapshot the original Pi identities while the private pane is still addressable.
  writers="$(remind_tool_real_pi_writers)" || uncertain=1
  if [[ -S "$remind_socket" ]]; then
    if ! failure="$(env -i PATH="$remind_path" LC_ALL=C HOME="$remind_work/driver-home" TMPDIR="$remind_work" \
      tmux -S "$remind_socket" -f /dev/null kill-server 2>&1)"; then
      case "$failure" in
        'no server running on '*|'error connecting to '*' (No such file or directory)'|'error connecting to '*' (Connection refused)')
          # The last session may already have shut down the private server.
          ;;
        *)
          printf 'remind-tool-real: cannot stop private tmux at %s: %s; work=%s\n' \
            "$remind_socket" "$failure" "$remind_work" >&2
          exit "$((rc == 0 ? 1 : rc))" ;;
      esac
    fi
  fi
  # Closing the terminal starts Pi shutdown; its hooks can still write after tmux returns.
  remind_tool_real_wait_pi "$writers" || uncertain=1
  if [[ -n "$remind_socket_dir" ]]; then
    rm -rf -- "$remind_socket_dir" || rc=$((rc == 0 ? 1 : rc))
  fi
  if (( uncertain )); then
    printf 'remind-tool-real: Pi exit not proved; leaving work=%s\n' "$remind_work" >&2
    exit "$((rc == 0 ? 1 : rc))"
  fi
  if [[ -n "$remind_root" ]]; then
    if [[ -n "$remind_work" && ( "$TEAM_TMP_KEEP" == 1 || "$remind_work" != "$remind_root" ) ]]; then
      printf 'kept private fixture root=%s\n' "$remind_work"
    fi
    # The driver is already reaped, so the helper must not signal that recorded PID.
    rm -f -- "$TMP_ROOT_PIDFILE" || exit "$((rc == 0 ? 3 : rc))"
    tmp_root_reap_all
  fi
  exit "$rc"
}

remind_tool_real_prepare() {
  # shellcheck source=lib/tmp-root.sh
  . "$TESTS/lib/tmp-root.sh"
  remind_driver= remind_driver_start=unknown remind_stop= remind_socket= remind_socket_dir= remind_root= remind_work=
  trap remind_tool_real_cleanup EXIT
  # Defer an early signal until the owner knows whether a child has been started.
  trap 'remind_stop=${remind_stop:-130}' INT
  trap 'remind_stop=${remind_stop:-143}' TERM

  TEAM_TMP_KEEP=0
  if [[ -z "${P442_EVIDENCE:-}" && -n "${P442_KEEP:-}" ]]; then TEAM_TMP_KEEP=1; fi
  remind_root="$(tmp_root_create remind-real)" || return 3
  printf 'remind-tool-real: work=%s %s\n' "$remind_root" "$(team_tmp_root_note)"
  TMP_ROOT_PIDFILE="$remind_root/.driver.pid"
  remind_work="$remind_root"
  if [[ -n "${P442_EVIDENCE:-}" ]]; then
    # Match Node's lexical path.resolve, including relative caller paths.
    remind_evidence="$(realpath -ms -- "$P442_EVIDENCE")" || return 3
    mkdir -p -m 700 -- "$remind_evidence" || return 3
    if [[ -n "${P442_KEEP:-}" ]]; then
      remind_work="$(mktemp -d "$remind_evidence/run-XXXXXX")" || return 3
    fi
  else
    remind_evidence="$remind_root/evidence"
    mkdir -m 700 -- "$remind_evidence" || return 3
  fi
}

remind_tool_real_run() {
  local rc=0 pi bunbin runner="${_P442_NODE:-node}"
  unset _P442_NODE
  pi="${P442_PI:-$(command -v pi)}"
  if [[ -z "$pi" ]]; then
    printf 'remind-tool-real: Pi not found on caller PATH (or set P442_PI)\n' >&2
    return 1
  fi
  bunbin="$(dirname -- "$pi")" || return 3
  remind_path="$bunbin:/usr/local/bin:/usr/bin:/bin"
  if ! PATH="$remind_path" type -P tmux >/dev/null; then
    printf 'remind-tool-real: tmux not found on private Pi PATH\n' >&2
    return 1
  fi
  remind_socket="$remind_work/socket"
  if ! (LC_ALL=C; [[ ${#remind_socket} -le 107 ]]); then
    if ! remind_socket_dir="$(LC_ALL=C TMP_ROOT_SOCKET_FALLBACK=/var/tmp tmp_root_socket_dir tmux s)"; then
      printf 'remind-tool-real: cannot allocate a private tmux socket for %s\n' "$remind_work" >&2
      return 3
    fi
    remind_socket="$remind_socket_dir/s"
  fi

  [[ -z "$remind_stop" ]] || exit "$remind_stop"
  _P442_WORK="$remind_work" _P442_EVIDENCE="$remind_evidence" _P442_SOCKET="$remind_socket" \
    _P442_PATH="$remind_path" _P442_PI="$pi" _P442_SCENES="$remind_root/.pi-scenes" \
    "$runner" "$TESTS/remind-tool-real.mjs" "$@" <&0 &
  remind_driver=$!
  if ! remind_driver_start="$(_tmp_root_proc_start "$remind_driver")"; then
    # A child that has already exited has no live identity to record.
    remind_driver_start=unknown
  else
    tmp_root_track_pid "$remind_driver" remind-real-driver || return 3
  fi
  trap 'exit 130' INT
  trap 'exit 143' TERM
  [[ -z "$remind_stop" ]] || exit "$remind_stop"
  wait "$remind_driver" || rc=$?
  remind_driver=
  return "$rc"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -uo pipefail
  remind_tool_real_prepare || exit $?
  remind_tool_real_run "$@"
  exit $?
fi
