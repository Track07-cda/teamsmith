#!/usr/bin/env bash
# P443 · prompt-free launch shape and recovery refusal matrix (no live team, tmux or model).
set -uo pipefail
HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$(cd -P "$HERE/.." && pwd)"
# shellcheck source=lib/tmp-root.sh
. "$HERE/lib/tmp-root.sh"
ROOT="$(tmp_root_create remind-recovery-unit)" || exit 3
trap 'tmp_root_reap_all' EXIT
mkdir -p "$ROOT/home" "$ROOT/tmp" "$ROOT/repo/.pi/team/state" "$ROOT/repo/docs/team"
export HOME="$ROOT/home" TMPDIR="$ROOT/tmp"
REPO="$ROOT/repo" STATE="$REPO/.pi/team/state"
git -C "$REPO" init -q
cat > "$REPO/.pi/team/config.sh" <<EOF
TEAM_PROJECT='p443-unit'
TEAM_SESSION='p443-unit'
TEAM_PM_WINDOW='pm'
TEAM_PM_MODEL='fixture/controlled'
TEAM_TASK_MODELS='code=fixture/controlled'
TEAM_PM_EXTRA_PI_ARGS=''
TEAM_PM_RESUME_ARGS=''
TEAM_PULSE_REBUILD_TMUX=0
TEAM_PULSE_MAX_RESTARTS=5
EOF
PASS=0; FAIL=0
ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
assert_has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1（缺 [$3]）" ;; esac; }
assert_no() { case "$2" in *"$3"*) bad "$1（不该有 [$3]）" ;; *) ok "$1" ;; esac; }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || bad "$1（期望 [$3]，实际 [$2]）"; }

# Render the real commands with the same config loader used by team up.
cd "$REPO" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_STATE_DIR -u TEAM_CONFIG_FILE \
  bash -c 'source "$1/scripts/lib/common.sh"; source "$1/scripts/lib/cmd-config.sh"; team_load_config; team_pm_launch_cmd "$2/pm-prompt.md" "$2/pm.pid.spawn"' _ "$SKILL" "$STATE" > "$ROOT/normal.launch"
cd "$REPO" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_STATE_DIR -u TEAM_CONFIG_FILE \
  bash -c 'source "$1/scripts/lib/common.sh"; source "$1/scripts/lib/cmd-config.sh"; team_load_config; TEAM_REMINDER_ONLY_RECOVERY=1 team_pm_launch_cmd "" "$2/pm.pid.spawn"' _ "$SKILL" "$STATE" > "$ROOT/reminder.launch"
NORMAL="$(cat "$ROOT/normal.launch")"; REMINDER="$(cat "$ROOT/reminder.launch")"
assert_has '普通 PM 启动仍带通用提示文件' "$NORMAL" "@$STATE/pm-prompt.md"
assert_no 'Reminder-only 启动不带 @pm-prompt' "$REMINDER" '@'
assert_no 'Reminder-only 启动不引用替代初始提示文件' "$REMINDER" 'pm-prompt'
assert_has 'Reminder-only 保留通常 -c 续跑参数' "$REMINDER" ' -c '
assert_has 'Reminder-only 保留 inbox watcher 扩展' "$REMINDER" 'extension/team-inbox-watch.ts'
assert_has 'Reminder-only 保留 PM Reminder 工具扩展' "$REMINDER" 'extension/team-remind.ts'
assert_has 'Reminder-only 给 watcher 明确的恢复标记' "$REMINDER" 'TEAM_REMINDER_ONLY_RECOVERY=1'
assert_has '普通启动会清掉继承的恢复标记' "$NORMAL" 'unset TEAM_ROOT TEAM_MAIN_ROOT TEAM_PROJECT TEAM_SESSION TEAM_SESSION_FROM TEAM_CONFIG_FILE TEAM_REMINDER_ONLY_RECOVERY'

# Recovery decisions use the real function; only PM/tmux evidence and the final spawn are controlled.
cd "$REPO" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_STATE_DIR -u TEAM_CONFIG_FILE \
  bash -c '
set -eu
source "$1/scripts/lib/common.sh"; source "$1/scripts/lib/cmd-config.sh"; source "$1/scripts/lib/cmd-remind.sh"; team_load_config
TEAM_SKILL_DIR="$1"; SKILL_PATH="$1"
team_remind_due_tick() { TEAM_REMIND_RECOVERY_REQUIRED=1; }
team_pm_evidence() { printf "controlled-evidence"; }
team_capacity_line() { printf "ram=ok swap=ok"; }
team_pm_recorded_pid() { printf "4242"; }
team_pm_attempt_record() { printf "attempt\n" >> "$TEAM_STATE_DIR/calls"; }
team_pm_restart_record() { printf "restart\n" >> "$TEAM_STATE_DIR/calls"; }
team_pm_start() {
  printf "start reminder=%s\n" "${TEAM_REMINDER_ONLY_RECOVERY:-0}" >> "$TEAM_STATE_DIR/calls"
  TEAM_PM_START_OUTCOME="${CONTROL_OUTCOME:-started}"
  [ "$TEAM_PM_START_OUTCOME" != "failed" ]
}
reset_case() {
  rm -f "$TEAM_STATE_DIR/calls" "$TEAM_STATE_DIR/reminders.log"
  TEAM_PM_CMD=""; TEAM_PULSE_REBUILD_TMUX=0; CONTROL_OUTCOME=started; TEAM_SKILL_DIR="$SKILL_PATH"
  team_pm_identity_guard() { return 0; }
  team_pm_restart_allowed() { return 0; }
}
run_case() {
  local name="$1" expected="$2" starts="$3" restarts="$4"
  reset_case
  case "$name" in
    running) team_pm_state() { printf "running:4242"; } ;;
    starting) team_pm_state() { printf "starting:2s"; } ;;
    quota) team_pm_state() { printf "idle:bash"; }; team_pm_restart_allowed() { return 1; } ;;
    identity) team_pm_state() { printf "idle:bash"; }; team_pm_identity_guard() { return 1; } ;;
    adapter) team_pm_state() { printf "idle:bash"; }; TEAM_PM_CMD="custom {prompt}" ;;
    missing-extension) team_pm_state() { printf "idle:bash"; }; TEAM_SKILL_DIR="/nonexistent" ;;
    missing-window) team_pm_state() { printf "missing"; } ;;
    started|already-starting|failed) team_pm_state() { printf "idle:bash"; } ;;
  esac
  [ "$name" = already-starting ] && CONTROL_OUTCOME=already-starting
  [ "$name" = failed ] && CONTROL_OUTCOME=failed
  team_remind_recovery > "$TEAM_STATE_DIR/result"
  local got starts_actual restarts_actual
  got="$(cat "$TEAM_STATE_DIR/result")"
  starts_actual=0; restarts_actual=0
  if [ -f "$TEAM_STATE_DIR/calls" ]; then
    starts_actual="$(grep -c "^start " "$TEAM_STATE_DIR/calls" || true)"
    restarts_actual="$(grep -c "^restart" "$TEAM_STATE_DIR/calls" || true)"
  fi
  case "$got" in *"result=$expected"*) printf "PASS recovery $name\n" ;; *) printf "FAIL recovery $name expected=$expected got=$got\n"; return 1 ;; esac
  [ "$starts_actual" = "$starts" ] && [ "$restarts_actual" = "$restarts" ] || { printf "FAIL recovery $name starts=$starts_actual restarts=$restarts_actual\n"; return 1; }
}
run_case running running 0 0
run_case starting starting 0 0
run_case quota quota-refused 0 0
run_case identity identity-refused 0 0
run_case adapter unsupported-adapter 0 0
run_case missing-extension missing-extension 0 0
run_case missing-window missing-window 0 0
run_case started started 1 1
run_case already-starting already-starting 1 0
run_case failed start-failed 1 0
[ "$(sed -n "s/^start reminder=//p" "$TEAM_STATE_DIR/calls")" = 1 ] || { printf "FAIL reminder marker did not reach team_pm_start\n"; exit 1; }
printf "PASS recovery marker reaches the one prompt-free start\n"
' _ "$SKILL" > "$ROOT/matrix.log" 2>&1
RC=$?
cat "$ROOT/matrix.log"
assert_eq '恢复拒绝矩阵与真实启动结果全部符合' "$RC" '0'
for expected in 'PASS recovery running' 'PASS recovery starting' 'PASS recovery quota' 'PASS recovery identity' \
  'PASS recovery adapter' 'PASS recovery missing-extension' 'PASS recovery missing-window' \
  'PASS recovery started' 'PASS recovery already-starting' 'PASS recovery failed' 'PASS recovery marker reaches'; do
  assert_has "矩阵含 $expected" "$(cat "$ROOT/matrix.log")" "$expected"
done
printf '\n== remind-recovery-unit 结果 == ✓%d ✗%d SKIP0\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
