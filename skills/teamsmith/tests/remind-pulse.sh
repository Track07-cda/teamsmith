#!/usr/bin/env bash
# P443 · both real Pulse shapes: due admission during a long patrol, coalesced recovery and child reaping.
set -uo pipefail
FLIP_CLEANUP=0
case "${1:-}" in
  '') ;;
  --flip=cleanup) FLIP_CLEANUP=1 ;;
  *) printf 'remind-pulse：不认识的参数 [%s]\n' "$1" >&2; exit 2 ;;
esac
HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$(cd -P "$HERE/.." && pwd)"
# shellcheck source=lib/tmp-root.sh
. "$HERE/lib/tmp-root.sh"
# shellcheck source=lib/main-team-fingerprint.sh
. "$HERE/lib/main-team-fingerprint.sh"
ROOT="$(tmp_root_create remind-pulse)" || exit 3
# The private root is already unique; a one-letter socket name keeps the full AF_UNIX path below 107 bytes.
SOCK="s"
cleanup() {
  TMUX_TMPDIR="$ROOT/tmux" tmux -L "$SOCK" -f /dev/null kill-server 2>/dev/null
  tmp_root_reap_all
}
trap cleanup EXIT
mkdir -p "$ROOT/home" "$ROOT/tmp" "$ROOT/tmux" "$ROOT/out" "$ROOT/bin"
export HOME="$ROOT/home" TMPDIR="$ROOT/tmp"
unset TEAM_ROOT TEAM_MAIN_ROOT TEAM_PROJECT TEAM_SESSION TEAM_SESSION_FROM TEAM_STATE_DIR TEAM_CONFIG_FILE TMUX TMUX_PANE 2>/dev/null || true
PASS=0; FAIL=0; W1_FAILURES=0
ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || bad "$1（期望 [$3]，实际 [$2]）"; }
assert_has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1（缺 [$3]）" ;; esac; }
w1_assert_eq() { if [ "$2" = "$3" ]; then ok "$1"; else W1_FAILURES=$((W1_FAILURES+1)); bad "$1（期望 [$3]，实际 [$2]）"; fi; }
new_repo() { local d="$ROOT/$1"; mkdir -p "$d/.pi/team/state" "$d/docs/team"; git -C "$d" init -q; cat > "$d/.pi/team/config.sh" <<EOF
TEAM_PROJECT='p443-$1'
TEAM_SESSION='p443-$1'
TEAM_PM_WINDOW='pm'
TEAM_AGENTS='dev'
TEAM_DOCS_DIR='docs/team'
TEAM_WORKTREES_DIR='.worktrees'
TEAM_PM_MODEL='fixture/controlled'
TEAM_TASK_MODELS='code=fixture/controlled'
TEAM_PULSE_REBUILD_TMUX=0
TEAM_PULSE_MAX_RESTARTS=5
TEAM_PULSE_INTERVAL=2
TEAM_REMIND_TICK_SECS=1
EOF
  printf '%s\n' "$d"; }
team() { local repo="$1"; shift; (cd "$repo" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_STATE_DIR -u TEAM_CONFIG_FILE -u TMUX -u TMUX_PANE HOME="$ROOT/home" TMPDIR="$ROOT/tmp" bash "$SKILL/scripts/team" --root "$repo" "$@"); }
add_due() { local repo="$1" text="$2"; team "$repo" remind add --after 2s --message "$text" > "$ROOT/out/add-$3.txt" 2>&1 || return 1; }
wait_file() { local file="$1" tries="${2:-200}"; while [ "$tries" -gt 0 ]; do [ -s "$file" ] && return 0; sleep 0.1; tries=$((tries-1)); done; return 1; }
queued_at() { node -e 'const s=require(process.argv[1]);const r=s.reminders.find(x=>x.phase==="queued"||x.phase==="intent"||x.phase==="observed");if(!r)process.exit(3);process.stdout.write(String(Date.parse(r.queuedAt)))' "$1/.pi/team/state/reminders/state.json"; }
check_order() { # <label> <repo> <patrol-log> <recovery-log>
  local label="$1" repo="$2" plog="$3" rlog="$4" q
  q="$(queued_at "$repo")" || { bad "$label 没有 queued 记录"; return; }
  Q="$q" LABEL="$label" node - "$plog" "$rlog" <<'JS'
const fs = require('fs');
const label = process.env.LABEL, q = Number(process.env.Q);
const lines = fs.readFileSync(process.argv[2], 'utf8').trim().split('\n').filter(Boolean);
let active = false, overlap = false, firstBegin = 0, firstEnd = 0, secondBegin = 0;
for (const line of lines) {
  const [kind, raw] = line.split(' '), at = Number(raw);
  if (kind === 'PATROL_BEGIN') {
    if (active) overlap = true;
    if (!firstBegin) firstBegin = at; else if (!secondBegin) secondBegin = at;
    active = true;
  }
  if (kind === 'PATROL_END') { if (!firstEnd) firstEnd = at; active = false; }
}
const recoveryAt = fs.statSync(process.argv[3]).mtimeMs;
if (!firstBegin || !firstEnd || q < firstBegin || q > firstEnd) {
  console.log(`FAIL ${label}: due ${q} was not admitted inside first patrol ${firstBegin}..${firstEnd}`); process.exit(1);
}
if (overlap) { console.log(`FAIL ${label}: a second full patrol overlapped the first`); process.exit(1); }
if (recoveryAt < firstEnd || (secondBegin && recoveryAt > secondBegin + 250)) {
  console.log(`FAIL ${label}: recovery ${recoveryAt} was not the coalesced recheck after patrol ${firstEnd} (second ${secondBegin})`); process.exit(1);
}
console.log(`PASS ${label}: due queued during long patrol; one recovery followed before the next patrol`);
JS
  RC=$?; assert_eq "$label 长巡检中入队且不重叠、结束后一次恢复" "$RC" '0'
}
check_reaped() { # <label> <patrol-log>
  local label="$1" log="$2" pid alive=0
  while read -r kind pid rest; do
    case "$kind" in PATROL_BEGIN|PATROL_SLEEP)
      if kill -0 "$pid" 2>/dev/null; then alive=$((alive+1)); fi ;;
    esac
  done < "$log"
  assert_eq "$label 停止后巡检与其外部子进程都已回收" "$alive" '0'
}
check_loop_children_reaped() { # <pid-file>：停止前由循环自己登记的全部直接子进程
  local file="$1" pid alive=0
  while read -r pid; do
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    if kill -0 "$pid" 2>/dev/null; then alive=$((alive+1)); fi
  done < "$file"
  w1_assert_eq 'headless 停止前登记的循环子进程全部消失' "$alive" '0'
}
REAL_MAIN="$(main_team_project_root "$SKILL")"
main_team_snapshot "${REAL_MAIN:-/nonexistent}/.pi/team" > "$ROOT/real-before.txt"

# A · actual `team watch` headless loop. Only the patrol body is slowed/instrumented in a scratch copy.
H="$(new_repo headless)"; cp -a "$SKILL" "$ROOT/headless-skill"
python3 - "$ROOT/headless-skill/scripts/lib/cmd-watch.sh" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read(); old = 'team_watch_once() {'
new = '''team_watch_once() {
  printf 'PATROL_BEGIN %s %s\\n' "$(date +%s%3N)" "$BASHPID" >> "$TEAM_STATE_DIR/patrol-fixture.log"
  sleep 4 & local fixture_sleep=$!
  printf 'PATROL_SLEEP %s\\n' "$fixture_sleep" >> "$TEAM_STATE_DIR/patrol-fixture.log"
  wait "$fixture_sleep"
  printf 'PATROL_END %s\\n' "$(date +%s%3N)" >> "$TEAM_STATE_DIR/patrol-fixture.log"
}
team_watch_once_real_unused() {'''
assert s.count(old) == 1
open(p, 'w').write(s.replace(old, new, 1))
PY
if [ "$FLIP_CLEANUP" = "1" ]; then
  # 恢复 V151 的旧清理：在 set -e 下，第一个非零 kill/wait 会跳过锁和剩余子进程。
  python3 - "$ROOT/headless-skill/scripts/lib/cmd-watch.sh" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace('kill "$child" 2>/dev/null || true', 'kill "$child" 2>/dev/null')
s = s.replace('kill "$pid" 2>/dev/null || true', 'kill "$pid" 2>/dev/null')
s = s.replace('wait "$pid" 2>/dev/null || true', 'wait "$pid" 2>/dev/null')
open(p, 'w').write(s)
PY
fi
add_due "$H" 'headless due during patrol' headless || bad 'headless 提醒创建失败'
(cd "$H" && exec env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_STATE_DIR -u TEAM_CONFIG_FILE -u TMUX -u TMUX_PANE \
  HOME="$ROOT/home" TMPDIR="$ROOT/tmp" TMUX_TMPDIR="$ROOT/tmux" TEAM_STATE_DIR="$H/.pi/team/state" TEAM_PULSE_INTERVAL=2 TEAM_REMIND_TICK_SECS=1 \
  bash "$ROOT/headless-skill/scripts/team" --root "$H" watch > "$ROOT/out/headless.log" 2>&1) & HPID=$!
wait_file "$H/.pi/team/state/reminders.log" 200 || bad 'headless 没等到到期入队/恢复日志'
for i in $(seq 1 100); do N=0; [ ! -f "$H/.pi/team/state/patrol-fixture.log" ] || N="$(grep -c '^PATROL_BEGIN' "$H/.pi/team/state/patrol-fixture.log" || true)"; if [ "${N:-0}" -ge 2 ]; then cp "$H/.pi/team/state/reminders.log" "$ROOT/out/headless-recovery-before-second.log"; break; fi; sleep 0.1; done
for i in $(seq 1 100); do
  ps -o pid=,args= --ppid "$HPID" > "$ROOT/out/headless-loop-children-full.txt"
  awk '$2 == "sleep" && $3 == "1" { print $1 }' "$ROOT/out/headless-loop-children-full.txt" > "$ROOT/out/headless-loop-children.txt"
  [ -s "$ROOT/out/headless-loop-children.txt" ] && break
  sleep 0.1
done
[ -s "$ROOT/out/headless-loop-children.txt" ] && ok 'headless 停止前登记了循环自己的 sleep 子进程' || w1_assert_eq 'headless 停止前必须登记循环 sleep 子进程' missing registered
kill -TERM "$HPID" 2>/dev/null; wait "$HPID"; HRC=$?
assert_eq 'headless 由 TERM 正常收口' "$HRC" '143'
[ ! -e "$H/.pi/team/state/watchdog.pid" ] && ok 'headless 停止后 watchdog.pid 不存在' || w1_assert_eq 'headless 停止后 watchdog.pid 不存在' present absent
check_loop_children_reaped "$ROOT/out/headless-loop-children.txt"
check_order headless "$H" "$H/.pi/team/state/patrol-fixture.log" "$H/.pi/team/state/reminders.log"
assert_eq 'headless 第一次长巡检与第二次巡检之间恰有一次恢复' "$(grep -c 'result=missing-window' "$ROOT/out/headless-recovery-before-second.log")" '1'
check_reaped headless "$H/.pi/team/state/patrol-fixture.log"

if [ "$FLIP_CLEANUP" = "1" ]; then
  printf '\n== remind-pulse flip cleanup：旧清理应留下锁或循环子进程 == W1 failures=%d\n' "$W1_FAILURES"
  [ "$W1_FAILURES" -gt 0 ]
  exit $?
fi

# B · actual console bundle and scheduler. A stub supplies panel data and a four-second patrol;
# due admission still uses the production authority and recovery goes through the production internal entry shape.
C="$(new_repo console)"; mkdir -p "$ROOT/console-bin"
cp "$SKILL/scripts/remind-tick.mjs" "$SKILL/scripts/state-authority.mjs" "$SKILL/scripts/remind-store.mjs" "$ROOT/console-bin/"
cat > "$ROOT/console-bin/team" <<'SH'
#!/usr/bin/env bash
set -uo pipefail
case " $* " in
  *' watch --once '*)
    printf 'PATROL_BEGIN %s %s\n' "$(date +%s%3N)" "$BASHPID" >> "$P443_PULSE_LOG"
    sleep 4 & fixture_sleep=$!
    printf 'PATROL_SLEEP %s\n' "$fixture_sleep" >> "$P443_PULSE_LOG"
    wait "$fixture_sleep"
    printf 'PATROL_END %s\n' "$(date +%s%3N)" >> "$P443_PULSE_LOG" ;;
  *' __remind-recover '*)
    printf 'RECOVERY %s\n' "$(date +%s%3N)" >> "$P443_RECOVERY_LOG" ;;
  *) exec bash "$P443_PANEL_STUB" "$@" ;;
esac
SH
chmod +x "$ROOT/console-bin/team"
add_due "$C" 'console due during patrol' console || bad 'console 提醒创建失败'
cat > "$ROOT/console-run.sh" <<EOF
#!/usr/bin/env bash
export HOME='$ROOT/home' TMPDIR='$ROOT/tmp' P443_PULSE_LOG='$C/.pi/team/state/patrol-fixture.log'
export P443_RECOVERY_LOG='$C/.pi/team/state/recovery-fixture.log' P443_PANEL_STUB='$SKILL/tests/panel-b3-stub.sh'
export TEAM_REMIND_TICK_SECS=1 TEAM_MONITOR_REFRESH=1
exec node '$SKILL/scripts/panel/panel.js' --root '$C' --team-cli '$ROOT/console-bin/team' --ui tui --interval 1 --tick-every 1 --tick-log '$C/.pi/team/state/watchdog.tick.log'
EOF
chmod +x "$ROOT/console-run.sh"
TMUX_TMPDIR="$ROOT/tmux" tmux -L "$SOCK" -f /dev/null new-session -d -s p443-console -n pulse "bash $ROOT/console-run.sh"
CPID="$(TMUX_TMPDIR="$ROOT/tmux" tmux -L "$SOCK" -f /dev/null display-message -p -t p443-console:pulse '#{pane_pid}')"
wait_file "$C/.pi/team/state/recovery-fixture.log" 200 || bad 'console 没等到第一次合并恢复'
for i in $(seq 1 100); do N=0; [ ! -f "$C/.pi/team/state/patrol-fixture.log" ] || N="$(grep -c '^PATROL_BEGIN' "$C/.pi/team/state/patrol-fixture.log" || true)"; [ "${N:-0}" -ge 2 ] && break; sleep 0.1; done
sleep 1
kill -TERM "$CPID" 2>/dev/null
for i in $(seq 1 50); do kill -0 "$CPID" 2>/dev/null || break; sleep 0.1; done
if kill -0 "$CPID" 2>/dev/null; then bad 'console SIGTERM 后仍未退出'; else ok 'console SIGTERM 后退出并执行清理'; fi
check_order console "$C" "$C/.pi/team/state/patrol-fixture.log" "$C/.pi/team/state/recovery-fixture.log"
check_reaped console "$C/.pi/team/state/patrol-fixture.log"

main_team_snapshot "${REAL_MAIN:-/nonexistent}/.pi/team" > "$ROOT/real-after.txt"
VIOL="$(main_team_violations "$ROOT/real-before.txt" "$ROOT/real-after.txt")"
[ -z "$VIOL" ] && ok '两种 Pulse 夹具均未写主项目状态' || bad "主项目状态被写入：$VIOL"
printf '\n== remind-pulse 结果 == ✓%d ✗%d SKIP0\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
