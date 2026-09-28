#!/usr/bin/env bash
# section-guard.sh — 门禁的**每段自述 + 硬预算 + 现场**（change: gate-section-accounting · 实现：P70）
#
# 被 `tests/smoke.sh` source（也支持 `bash tests/lib/section-guard.sh --self-test` 自检）。
# 契约见 `openspec/changes/gate-section-accounting/specs/verification/spec.md`：
#   * 每段开跑前打印 `== #<N> <id> == <ISO-8601> · 预算 <B>s`；结束时打印 `#<N>` + 用时；
#     每段一行进 `<run tmp>/sections.tsv`（`no id start elapsed_s ticks`）。
#   * 每段有一个来自 `tests/section-budgets.tsv` 的硬预算（表里没有 → 有界默认值，并在开跑行里说明）；
#     第一段超预算 → **停跑**：看门狗打印一行点名该段（`#<N>` + id + 预算 + 实际用时）、写现场、
#     然后才发信号；套件在自己的安全点看到 trip 标记 → exit 2。
#   * 看门狗是**双重 fork**（不进作业表：裸 `wait` 不会被它卡住），只对进程树里的子孙发信号，
#     **绝不** `kill -- -$pgid`（门禁的进程组里有 team review / CI / 启动它的席位）。
#   * 超预算 = **存活检测**，不是性能判定：段内只要在预算内跑完，机器再慢也绿（D33 保持）。
#   * 夹具旋钮只在 `TEAM_SMOKE_FIXTURE=1` 下生效，否则**打印忽略行**（环境不能悄悄拆掉边界）。
#
# 现场（trip 时）：`${TMPDIR:-/tmp}/.teamsmith-smoke-scene.<pid>/`，点开头、在 run 自己的临时根**之外**
# —— 套件的清理（含失败时删根）带不走它，CI 的 `docker cp <容器>:/tmp/.` 原样收走（D39 通道不动）。

SG_SECTION_GUARD_LIB=1

# ---------------------------------------------------------------- 状态（全部有默认值：smoke 是 set -u）
SG_ENABLED=0
SG_ARMED=0
SG_TRIPPED=0
SG_SEC_NO=0
SG_SEC_ID=""
SG_SEC_START=""
SG_BUDGET=""
SG_BAND=""
SG_BUDGET_SOURCE=""
SG_ARMED_EPOCH=0
SG_ARMED_SECONDS=0
SG_TICKS=0
SG_ELAPSED=0
SG_OWNER_PID="$$"
SG_OWNER_START=""
SG_BASE="${TMPDIR:-/tmp}"
SG_RUN_TMP=""
SG_BUDGETS=""
SG_TIMING=""
SG_LOG=""
SG_HEARTBEAT=""
SG_MARKER=""
SG_SCENE=""
SG_STOP=""
SG_ACK=""
SG_WATCHDOG_PIDFILE=""
SG_POLL=1
SG_DESC_GRACE=6
SG_SUITE_GRACE=2
SG_PROGRESS_INTERVAL=60
SG_DEFAULT_BUDGET=900
SG_FIXTURE="${TEAM_SMOKE_FIXTURE:-0}"
SG_STUCK_SECTION=""
SG_BUDGET_OVERRIDE=""
SG_FAST="${TEAM_SMOKE_FAST:-0}"
SG_LOCK_NOTE=""

_sg_now() { date +%s; }

_sg_proc_start() { # /proc/<pid>/stat 的 starttime：pid 复用安全的判据
  local st; st="$(LC_ALL=C cat "/proc/$1/stat" 2>/dev/null)" || return 1
  st="${st##*\) }"; set -- $st
  [ -n "${20:-}" ] || return 1
  printf '%s\n' "${20}"
}

_sg_pid_alive() { # <pid> [<starttime>] → 0 活着且（给了 starttime 时）还是那个进程
  local pid="${1:-}" want="${2:-}" st
  case "$pid" in ''|*[!0-9]*) return 1 ;; esac
  [ "$pid" -gt 1 ] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  if [ -n "$want" ]; then
    st="$(_sg_proc_start "$pid" 2>/dev/null || true)"
    [ "$st" = "$want" ] || return 1
  fi
  return 0
}

# ---------------------------------------------------------------- 初始化
# section_guard_init <run tmp> [--poll <s>] [--progress <s>] [--suite-grace <s>]
#                              [--desc-grace <n>] [--default-budget <s>] [--budgets <file>]
section_guard_init() {
  SG_RUN_TMP="${1:-}"; shift || true
  while [ $# -gt 0 ]; do
    case "$1" in
      --poll)            SG_POLL="${2:-1}"; shift 2 ;;
      --progress)        SG_PROGRESS_INTERVAL="${2:-60}"; shift 2 ;;
      --suite-grace)     SG_SUITE_GRACE="${2:-2}"; shift 2 ;;
      --desc-grace)      SG_DESC_GRACE="${2:-6}"; shift 2 ;;
      --default-budget)  SG_DEFAULT_BUDGET="${2:-900}"; shift 2 ;;
      --budgets)         SG_BUDGETS="${2:-}"; shift 2 ;;
      *) printf 'section-guard: 不认识的参数 %s\n' "$1" >&2; return 2 ;;
    esac
  done
  SG_BASE="${TMPDIR:-/tmp}"
  SG_FIXTURE="${TEAM_SMOKE_FIXTURE:-0}"
  SG_OWNER_PID="${BASHPID:-$$}"
  SG_OWNER_START="$(_sg_proc_start "$SG_OWNER_PID" 2>/dev/null || true)"
  SG_HEARTBEAT="$SG_BASE/.teamsmith-smoke-heartbeat.$SG_OWNER_PID"
  SG_MARKER="$SG_BASE/.teamsmith-smoke-trip.$SG_OWNER_PID"
  SG_SCENE="$SG_BASE/.teamsmith-smoke-scene.$SG_OWNER_PID"
  SG_STOP="$SG_BASE/.teamsmith-smoke-guard-stop.$SG_OWNER_PID"
  SG_ACK="$SG_BASE/.teamsmith-smoke-guard-ack.$SG_OWNER_PID"
  SG_WATCHDOG_PIDFILE="$SG_BASE/.teamsmith-smoke-guard.pid.$SG_OWNER_PID"
  SG_TIMING="$SG_RUN_TMP/sections.tsv"
  SG_LOG="$SG_RUN_TMP/sections.log"
  [ -n "$SG_BUDGETS" ] || SG_BUDGETS="${SG_SKILL_DIR:-}/tests/section-budgets.tsv"
  _sg_parse_knobs
  if [ ! -s "$SG_TIMING" ]; then
    printf 'no\tid\tstart\telapsed_s\tticks\n' > "$SG_TIMING" 2>/dev/null || true
  fi
  : > "$SG_LOG" 2>/dev/null || true
  return 0
}

_sg_knob_note() { # <name> <value>：非夹具路径下的忽略行（旋钮不许从环境拆掉边界）
  printf '  \033[2m·\033[0m 注意：%s=%s 只给夹具路径用；非夹具路径忽略它\n' "$1" "$2"
}

_sg_parse_knobs() {
  local k v
  SG_STUCK_SECTION=""
  SG_BUDGET_OVERRIDE=""
  SG_POLL="${SG_POLL:-1}"
  SG_PROGRESS_INTERVAL="${SG_PROGRESS_INTERVAL:-60}"
  if [ "${SG_FIXTURE:-0}" = "1" ]; then
    SG_STUCK_SECTION="${TEAM_SMOKE_STUCK_SECTION:-}"
    SG_BUDGET_OVERRIDE="${TEAM_SMOKE_SECTION_BUDGET:-}"
    [ -n "${TEAM_SMOKE_PROGRESS_INTERVAL:-}" ] && SG_PROGRESS_INTERVAL="$TEAM_SMOKE_PROGRESS_INTERVAL"
    [ -n "${TEAM_SMOKE_GUARD_POLL:-}" ] && SG_POLL="$TEAM_SMOKE_GUARD_POLL"
    return 0
  fi
  for k in TEAM_SMOKE_STUCK_SECTION TEAM_SMOKE_SECTION_BUDGET TEAM_SMOKE_PROGRESS_INTERVAL TEAM_SMOKE_GUARD_POLL SMOKE_PROGRESS_INTERVAL; do
    case "$k" in
      TEAM_SMOKE_STUCK_SECTION)     v="${TEAM_SMOKE_STUCK_SECTION:-}" ;;
      TEAM_SMOKE_SECTION_BUDGET)    v="${TEAM_SMOKE_SECTION_BUDGET:-}" ;;
      TEAM_SMOKE_PROGRESS_INTERVAL) v="${TEAM_SMOKE_PROGRESS_INTERVAL:-}" ;;
      TEAM_SMOKE_GUARD_POLL)        v="${TEAM_SMOKE_GUARD_POLL:-}" ;;
      SMOKE_PROGRESS_INTERVAL)      v="${SMOKE_PROGRESS_INTERVAL:-}" ;;
    esac
    [ -n "$v" ] && _sg_knob_note "$k" "$v"
  done
  SG_PROGRESS_INTERVAL=60
  SG_POLL=1
  return 0
}

# ---------------------------------------------------------------- 预算表
# section_guard_budget_for <id> → 设置 SG_BUDGET / SG_BAND / SG_BUDGET_SOURCE
section_guard_budget_for() {
  local id="$1" row=""
  if [ -n "$SG_BUDGETS" ] && [ -r "$SG_BUDGETS" ]; then
    row="$(awk -F'\t' -v id="$id" '
      /^[[:space:]]*#/ { next }
      $1 == id { print $2 "\t" $3; found = 1; exit }
      END { if (!found) exit 1 }
    ' "$SG_BUDGETS" 2>/dev/null || true)"
  fi
  # 行必须在、band 可以是 "-"（没测过），budget 必须是正整数
  case "$row" in
    *$'\t'*) SG_BAND="${row%%	*}"; SG_BUDGET="${row##*	}" ;;
    *)       SG_BAND=""; SG_BUDGET="" ;;
  esac
  case "${SG_BUDGET:-x}" in ''|*[!0-9]*) row="" ;; esac
  if [ -n "$row" ]; then
    SG_BUDGET_SOURCE="table"
  else
    SG_BAND=""
    SG_BUDGET="$SG_DEFAULT_BUDGET"
    SG_BUDGET_SOURCE="default"
  fi
  # 夹具的预算覆盖：只作用于被点名的 stuck 段；没点名就作用于每段（自检/夹具用）
  if [ "${SG_FIXTURE:-0}" = "1" ] && [ -n "$SG_BUDGET_OVERRIDE" ]; then
    case "${SG_BUDGET_OVERRIDE:-x}" in *[!0-9]*) ;; *)
      if [ -z "$SG_STUCK_SECTION" ] || _sg_id_matches "$SG_STUCK_SECTION" "$id"; then
        SG_BUDGET="$SG_BUDGET_OVERRIDE"
        SG_BUDGET_SOURCE="fixture"
      fi
      ;;
    esac
  fi
  return 0
}

_sg_id_matches() { # <knob> <id>：完整 id 或「前缀 + 空格」都算
  local knob="$1" id="$2"
  case "$id" in
    "$knob"|"$knob "*) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------- 心跳 / 安全点
section_guard_write_heartbeat() {
  [ "$SG_ENABLED" = "1" ] || return 0
  if [ -z "$SG_SEC_ID" ]; then
    printf 'disarm\n' > "$SG_HEARTBEAT" 2>/dev/null || true
    return 0
  fi
  SG_ELAPSED=$(( SECONDS - SG_ARMED_SECONDS ))
  printf '%s|%s|%s|%s|%s|%s\n' \
    "$SG_SEC_NO" "$SG_ARMED_EPOCH" "$SG_BUDGET" "$SG_ELAPSED" "$SG_TICKS" "$SG_SEC_ID" \
    > "$SG_HEARTBEAT" 2>/dev/null || true
  return 0
}

section_guard_progress_tick() {
  [ "$SG_ENABLED" = "1" ] || return 0
  [ "$SG_ARMED" = "1" ] || return 0
  SG_TICKS=$((SG_TICKS + 1))
  section_guard_write_heartbeat
  return 0
}

# 安全点：trip 标记在 → 停跑（看门狗已经打印过点名行；这里只退出，不重复点名）
_sg_check_trip() {
  [ "$SG_ENABLED" = "1" ] || return 0
  if [ -e "$SG_MARKER" ]; then
    SG_TRIPPED=1
    _sg_exit_trip
  fi
  return 0
}

# ok()/bad()/skip/等待轮都调用它：先看 trip，再把 ticks/elapsed 写回心跳（纯内建写入）
section_guard_check() {
  [ "$SG_ENABLED" = "1" ] || return 0
  _sg_check_trip
  [ "$SG_ARMED" = "1" ] || return 0
  section_guard_progress_tick
  return 0
}

_sg_exit_trip() {
  trap - TERM 2>/dev/null || true
  if [ "${BASHPID:-$$}" = "$$" ]; then
    # 主 shell：先收看门狗，别让它在 cleanup 之后继续打；EXIT trap 照常收临时根
    section_guard_stop_watchdog
  fi
  exit 2
}

section_guard_on_term() { # 看门狗对我们的 TERM：trip → exit 2；否则恢复默认动作重新自杀
  if [ -e "$SG_MARKER" ]; then
    _sg_exit_trip
  fi
  trap - TERM 2>/dev/null || true
  kill -TERM "${BASHPID:-$$}" 2>/dev/null || true
  exit 143
}

# ---------------------------------------------------------------- 段落开闭
_sg_start_line() {
  local src=""
  case "$SG_BUDGET_SOURCE" in
    default) src="（默认：预算表没有这段）" ;;
    fixture) src="（夹具覆盖）" ;;
  esac
  printf '== #%s %s == %s · 预算 %ss%s' "$SG_SEC_NO" "$SG_SEC_ID" "$SG_SEC_START" "$SG_BUDGET" "$src"
}

_sg_close_current() {
  [ "$SG_ARMED" = "1" ] || return 0
  local elapsed now
  now="$(_sg_now)"; elapsed=$(( now - SG_ARMED_EPOCH ))
  [ "$elapsed" -lt 0 ] && elapsed=0
  printf '  #%s 用时 %ss · ticks %s\n' "$SG_SEC_NO" "$elapsed" "$SG_TICKS"
  printf '#%s %s 用时 %ss · ticks %s\n' "$SG_SEC_NO" "$SG_SEC_ID" "$elapsed" "$SG_TICKS" >> "$SG_LOG" 2>/dev/null || true
  printf '%s\t%s\t%s\t%s\t%s\n' "$SG_SEC_NO" "$SG_SEC_ID" "$SG_SEC_START" "$elapsed" "$SG_TICKS" >> "$SG_TIMING" 2>/dev/null || true
  case "${SG_BAND:-}" in
    ''|*[!0-9]*) ;;
    *) if [ "$elapsed" -gt "$SG_BAND" ]; then
         printf '  \033[33m⚠\033[0m #%s 用时 %ss，超过实测带 %ss（这是记录，不是判定）\n' \
           "$SG_SEC_NO" "$elapsed" "$SG_BAND"
       fi ;;
  esac
  SG_ARMED=0
  SG_SEC_ID=""
  printf 'disarm\n' > "$SG_HEARTBEAT" 2>/dev/null || true
  return 0
}

section_guard_begin() { # <id>：收上一段 → 开这一段（含夹具注入）
  local id="$1" line
  [ "$SG_ENABLED" = "1" ] || return 0
  _sg_check_trip
  [ "$SG_ARMED" = "1" ] && _sg_close_current
  SG_SEC_NO=$((SG_SEC_NO + 1))
  SG_SEC_ID="$id"
  SG_SEC_START="$(date -Is)"
  SG_ARMED_EPOCH="$(_sg_now)"
  SG_ARMED_SECONDS="$SECONDS"
  SG_TICKS=0
  section_guard_budget_for "$id"
  SG_ARMED=1
  section_guard_write_heartbeat
  line="$(_sg_start_line)"
  printf '\n\033[1m%s\033[0m\n' "$line"
  printf '%s\n' "$line" >> "$SG_LOG" 2>/dev/null || true
  # 夹具注入：被点名的段落永不返回（预算到点必须点名 + 停跑 + 留现场）
  if [ "${SG_FIXTURE:-0}" = "1" ] && [ -n "$SG_STUCK_SECTION" ] && _sg_id_matches "$SG_STUCK_SECTION" "$id"; then
    printf '  \033[35m[fixture]\033[0m 注入永不返回的段落（%s，预算 %ss）\n' "$id" "$SG_BUDGET"
    local stuck_log="$SG_RUN_TMP/fixture-stuck-$SG_SEC_NO.log"
    printf 'fixture 注入：段落 #%s（%s）永不返回（预算 %ss）\n' "$SG_SEC_NO" "$id" "$SG_BUDGET" > "$stuck_log" 2>/dev/null || true
    bash -c 'log="$1"; trap "" TERM; while :; do date +%s >> "$log"; sleep 0.2; done' _ "$stuck_log" &
    local child=$!
    command -v tmp_root_track_pid >/dev/null 2>&1 && tmp_root_track_pid "$child" "section-guard-stuck" || true
    wait "$child" 2>/dev/null || true
    _sg_check_trip
    printf '  \033[35m[fixture]\033[0m 注入的段落返回了（trip 标记没出现？）\n'
  fi
  return 0
}

section_guard_finish() { # 结果行之前：收最后一段 + 关看门狗
  [ "$SG_ENABLED" = "1" ] || return 0
  [ "$SG_ARMED" = "1" ] && _sg_close_current
  section_guard_stop_watchdog
  SG_ENABLED=0
  return 0
}

# ---------------------------------------------------------------- 看门狗
section_guard_arm() {
  SG_ENABLED=1
  SG_ARMED=0
  SG_TRIPPED=0
  SG_SEC_NO=0
  printf 'disarm\n' > "$SG_HEARTBEAT" 2>/dev/null || true
  rm -f "$SG_MARKER" "$SG_STOP" "$SG_ACK" "$SG_WATCHDOG_PIDFILE" 2>/dev/null || true
  ( section_guard_watchdog & )
  # 起 TERM 陷阱：trip 的 TERM → exit 2；别的 TERM → 恢复默认动作（见 section_guard_on_term）
  trap 'section_guard_on_term' TERM
  local i=0
  for i in $(seq 1 50); do
    [ -s "$SG_WATCHDOG_PIDFILE" ] && break
    sleep 0.02
  done
  if [ ! -s "$SG_WATCHDOG_PIDFILE" ]; then
    printf '  \033[31m✗\033[0m section-guard：看门狗没起来（%s）—— 本套**没有**每段硬预算\n' "$SG_WATCHDOG_PIDFILE"
  fi
  return 0
}

section_guard_stop_watchdog() {
  : > "$SG_STOP" 2>/dev/null || true
  local i wpid wstart
  for i in $(seq 1 25); do [ -e "$SG_ACK" ] && break; sleep 0.02; done
  wpid="$(awk -F'\t' 'NR==1{print $1}' "$SG_WATCHDOG_PIDFILE" 2>/dev/null || true)"
  wstart="$(awk -F'\t' 'NR==1{print $2}' "$SG_WATCHDOG_PIDFILE" 2>/dev/null || true)"
  if [ ! -e "$SG_ACK" ] && [ -n "$wpid" ]; then
    # 没握手（比如看门狗卡在写现场）：按 pid + starttime 有界地收，绝不按名字/进程组
    _sg_pid_alive "$wpid" "${wstart:-}" && kill -TERM "$wpid" 2>/dev/null || true
    for i in $(seq 1 25); do
      _sg_pid_alive "$wpid" "${wstart:-}" || break
      sleep 0.02
    done
    _sg_pid_alive "$wpid" "${wstart:-}" && kill -KILL "$wpid" 2>/dev/null || true
  fi
  rm -f "$SG_STOP" "$SG_ACK" "$SG_WATCHDOG_PIDFILE" 2>/dev/null || true
  return 0
}

# 收尾（cleanup 里调用）：干净跑把哨兵的兄弟文件收掉；trip 过 → 现场留着（那是证据）
section_guard_sweep() {
  rm -f "$SG_STOP" "$SG_ACK" "$SG_WATCHDOG_PIDFILE" 2>/dev/null || true
  [ "$SG_TRIPPED" = "1" ] && return 0
  rm -f "$SG_HEARTBEAT" "$SG_MARKER" 2>/dev/null || true
  return 0
}

_sg_descendants() { # <pid> <exclude> → 叶子优先
  local pid="$1" exclude="$2" f c
  for f in /proc/"$pid"/task/*/children; do
    [ -r "$f" ] || continue
    for c in $(cat "$f" 2>/dev/null); do
      [ -n "$c" ] || continue
      [ "$c" = "$exclude" ] && continue
      _sg_descendants "$c" "$exclude"
      printf '%s\n' "$c"
    done
  done
}

section_guard_watchdog() {
  local me="$BASHPID"
  printf '%s\t%s\n' "$me" "$(_sg_proc_start "$me" 2>/dev/null || true)" > "$SG_WATCHDOG_PIDFILE" 2>/dev/null || true
  local line no armed budget elapsed ticks id now last_seen=0 last_progress=0
  while :; do
    [ -e "$SG_STOP" ] && break
    _sg_pid_alive "$SG_OWNER_PID" "$SG_OWNER_START" || break
    line="$(cat "$SG_HEARTBEAT" 2>/dev/null || true)"
    case "$line" in ''|disarm*) sleep "$SG_POLL"; continue ;; esac
    IFS='|' read -r no armed budget elapsed ticks id <<<"$line"
    case "${no:-x}${armed:-x}${budget:-x}" in *[!0-9]*) sleep "$SG_POLL"; continue ;; esac
    now="$(_sg_now)"
    case "${elapsed:-0}" in ''|*[!0-9]*) elapsed=0 ;; esac
    [ "${elapsed}" -gt "$last_seen" ] && last_seen="$elapsed"
    case "${SG_PROGRESS_INTERVAL:-60}" in ''|*[!0-9]*) SG_PROGRESS_INTERVAL=60 ;; esac
    if [ "$SG_PROGRESS_INTERVAL" -gt 0 ] \
       && [ "$(( now - armed ))" -ge "$SG_PROGRESS_INTERVAL" ] \
       && [ "$(( now - last_progress ))" -ge "$SG_PROGRESS_INTERVAL" ]; then
      _sg_progress_line "$no" "$id" "$(( now - armed ))" "$budget"
      last_progress=$now
    fi
    if [ "$(( now - armed ))" -ge "$budget" ]; then
      _sg_trip "$no" "$id" "$armed" "$budget" "$ticks" "$last_seen" "$now"
      break
    fi
    sleep "$SG_POLL"
  done
  rm -f "$SG_WATCHDOG_PIDFILE" 2>/dev/null || true
  : > "$SG_ACK" 2>/dev/null || true
  exit 0
}

_sg_progress_line() {
  local no="$1" id="$2" elapsed="$3" budget="$4" slow=""
  slow="$(awk -F'\t' 'NR > 1 && $4 ~ /^[0-9]+$/ { printf "%s\t#%s %s\n", $4, $1, $2 }' "$SG_TIMING" 2>/dev/null \
    | sort -rn 2>/dev/null | head -3 | cut -f2 | tr '\n' ' ' || true)"
  printf '  \033[2m… 段落 #%s（%s）已运行 %ss（预算 %ss）%s\033[0m\n' \
    "$no" "$id" "$elapsed" "$budget" "${slow:+；最慢：$slow}"
  printf '… 段落 #%s（%s）已运行 %ss（预算 %ss）%s\n' \
    "$no" "$id" "$elapsed" "$budget" "${slow:+；最慢：$slow}" >> "$SG_LOG" 2>/dev/null || true
  return 0
}

_sg_trip() { # <no> <id> <armed> <budget> <ticks> <last_seen> <now>
  local no="$1" id="$2" armed="$3" budget="$4" ticks="$5" last_seen="$6" now="$7"
  local elapsed="$(( now - armed ))" i=0
  printf '\n  \033[31m✗\033[0m 段落 #%s（%s）超时：预算 %ss，实际 %ss，最后进度 %ss → 停跑（exit 2），现场 %s\n' \
    "$no" "$id" "$budget" "$elapsed" "$last_seen" "$SG_SCENE"
  : > "$SG_MARKER" 2>/dev/null || true
  _sg_scene_write "$no" "$id" "$budget" "$elapsed" "$last_seen" "$ticks" "$armed"
  _sg_stop_children "$no"
  # 给套件一个**有界**的机会自己走到安全点退出（exit 2）；它不走才 TERM/KILL
  while [ "$i" -lt $(( SG_SUITE_GRACE * 5 )) ]; do
    _sg_pid_alive "$SG_OWNER_PID" "$SG_OWNER_START" || return 0
    sleep 0.2; i=$((i + 1))
  done
  kill -TERM "$SG_OWNER_PID" 2>/dev/null || true
  i=0
  while [ "$i" -lt 25 ]; do
    _sg_pid_alive "$SG_OWNER_PID" "$SG_OWNER_START" || return 0
    sleep 0.2; i=$((i + 1))
  done
  kill -KILL "$SG_OWNER_PID" 2>/dev/null || true
  return 0
}

_sg_stop_children() { # <no>：只停这个套件进程树里的子孙（不含看门狗），TERM → 有界宽限 → KILL
  local no="$1" p grace=0
  while :; do
    p="$(_sg_descendants "$SG_OWNER_PID" "$BASHPID" | tac)"
    [ -n "$p" ] || break
    [ "$grace" -ge "$SG_DESC_GRACE" ] && break
    printf '%s\n' "$p" | xargs -r kill -TERM 2>/dev/null || true
    sleep 0.2; grace=$((grace + 1))
  done
  if [ "$grace" -ge "$SG_DESC_GRACE" ]; then
    p="$(_sg_descendants "$SG_OWNER_PID" "$BASHPID" | tac)"
    if [ -n "$p" ]; then
      printf '%s\n' "$p" | xargs -r kill -KILL 2>/dev/null || true
      printf 'escalation: 段落 #%s 的子孙忽略 TERM → 已对它们发 KILL\n' "$no" >> "$SG_SCENE/summary.txt" 2>/dev/null || true
      printf '  \033[31m✗\033[0m 看门狗：段落 #%s 的子孙忽略 TERM → 已发 KILL（现场 %s）\n' "$no" "$SG_SCENE"
    fi
  fi
  return 0
}

_sg_recent_files() { # <root> <min_epoch> <max>：窗口内动过的文件，**按 mtime 从新到旧**（有界）
  # 不按 find 的目录顺序：正在被写的那份（挂住段落的夹具日志）必须排在最前，否则 12 个名额会被
  # 窗口里更早、目录顺序靠前的文件占满 —— 2026-09-28 容器实测：0f 现场收进 .git/hooks/*.sample，
  # 挂住的夹具日志一条都没有（宿主 tmpfs 的目录顺序恰好是新文件在前，所以只在容器里现形）。
  find "$1" -type f -newermt "@$2" -printf '%T@\t%p\n' 2>/dev/null \
    | sort -rn | head -n "$3" | cut -f2-
}

_sg_scene_write() { # <no> <id> <budget> <elapsed> <last_seen> <ticks> <armed>
  local no="$1" id="$2" budget="$3" elapsed="$4" last_seen="$5" ticks="$6" armed="$7"
  mkdir -p "$SG_SCENE/logs" 2>/dev/null || return 0
  {
    printf 'section: #%s\nid: %s\nbudget: %ss\nelapsed: %ss\nlast progress: %ss\nticks: %s\n' \
      "$no" "$id" "$budget" "$elapsed" "$last_seen" "$ticks"
    printf 'watchdog pid: %s\n' "${BASHPID:-?}"
    printf 'suite pid: %s\n' "$SG_OWNER_PID"
    printf 'mode: FAST=%s fixture=%s\n' "${SG_FAST:-0}" "${SG_FIXTURE:-0}"
    printf 'knobs: stuck=%s budget_override=%s progress=%s poll=%s\n' \
      "${SG_STUCK_SECTION:-}" "${SG_BUDGET_OVERRIDE:-}" "$SG_PROGRESS_INTERVAL" "$SG_POLL"
    printf 'lock: %s\n' "$([ -n "$SG_LOCK_NOTE" ] && printf '%s holder=%s' "$SG_LOCK_NOTE" "$(cat "$SG_LOCK_NOTE.holder" 2>/dev/null || true)" || printf '（无）')"
    printf 'machine: nproc=%s loadavg=%s run_tmp=%s\n' \
      "$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || printf '?')" \
      "$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null || printf '?')" "$SG_RUN_TMP"
    printf -- '-- 子孙进程树（叶子优先）--\n'
    local p; p="$(_sg_descendants "$SG_OWNER_PID" "$BASHPID" | paste -sd, - 2>/dev/null || true)"
    if [ -n "$p" ]; then
      ps -o pid,ppid,pgid,stat,etime,args -p "$p" 2>/dev/null || true
    else
      printf '（无子孙）\n'
    fi
    printf -- '-- 进程表快照（有界 tail）--\n'
    ps -eo pid,ppid,pgid,stat,etime,args 2>/dev/null | tail -60
  } > "$SG_SCENE/summary.txt" 2>&1 || true
  {
    printf -- '-- 本段窗口内动过的文件（$TMP 下，有界 tail；按 mtime 从新到旧）--\n'
    local n=0 f
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      n=$((n + 1))
      [ "$n" -gt 12 ] && break
      printf '== %s ==\n' "${f#$SG_RUN_TMP/}"
      tail -c 4096 "$f" 2>/dev/null | tail -20 || true
    done < <(_sg_recent_files "$SG_RUN_TMP" "$((armed - 1))" 12)
    [ "$n" -eq 0 ] && printf '（本段窗口内没有 $TMP 下的新文件）\n'
  } > "$SG_SCENE/logs/tails.txt" 2>&1 || true
  if command -v tmux >/dev/null 2>&1; then
    {
      printf -- '-- 本 run 私有 tmux server 的 pane 尾屏（有界）--\n'
      local pane
      while IFS= read -r pane; do
        [ -n "$pane" ] || continue
        printf '== %s ==\n' "$pane"
        tmux capture-pane -p -t "$pane" 2>/dev/null | tail -15 || true
      done < <(tmux list-panes -a -F '#{session_name}:#{window_name}.#{pane_index}' 2>/dev/null | head -8)
    } > "$SG_SCENE/panes.txt" 2>&1 || true
  fi
  cp "$SG_TIMING" "$SG_SCENE/sections.tsv.partial" 2>/dev/null || true
  return 0
}

# ---------------------------------------------------------------- 有界等待助手
# section_guard_wait <name> <cap> <interval> <state> <reader|-> <predicate...>
#   每一轮刷新心跳/ticks；到顶打印一行归因（名字、n/cap、等什么、最后一次读数）并返回非 0。
section_guard_wait() {
  local name="$1" cap="$2" interval="$3" state="$4" reader="$5"; shift 5
  case "${cap:-x}" in ''|*[!0-9]*) printf 'section_guard_wait: cap 必须是正整数（收到 [%s]）\n' "${cap:-}" >&2; return 2 ;; esac
  [ "$cap" -gt 0 ] || { printf 'section_guard_wait: cap 必须是正整数（收到 %s）\n' "$cap" >&2; return 2; }
  local round=0 reading="（无读数）"
  while [ "$round" -lt "$cap" ]; do
    round=$((round + 1))
    section_guard_check
    if [ "$reader" != "-" ] && [ -n "$reader" ] && command -v "$reader" >/dev/null 2>&1; then
      reading="$("$reader" "$round" 2>/dev/null || true)"
      [ -n "$reading" ] || reading="（读数命令没有输出）"
    fi
    if "$@"; then
      return 0
    fi
    sleep "$interval"
  done
  printf '  \033[33m等待到顶\033[0m %s：%s/%s 轮；在等「%s」；最后一次读数：%s\n' \
    "$name" "$round" "$cap" "$state" "$reading"
  return 1
}

# ---------------------------------------------------------------- 自检（模块自己的五形状）
_sg_selftest_case() { # <name> <shape> <want:0|2|!0> <want_scene:0|1>
  local name="$1" shape="$2" want="$3" want_scene="$4"
  local dir="$ST_ROOT/$name"; mkdir -p "$dir/run-tmp"
  local rc=0
  (
    export TMPDIR="$dir"
    section_guard_init "$dir/run-tmp" --poll 0.2 --progress 300 --suite-grace 1 --desc-grace 2 --default-budget 2
    section_guard_arm
    section_guard_begin "selftest-$name"
    wait
    printf 'BARE_WAIT_RETURNED\n'
    case "$shape" in
      stuck)      eval 'sleep infinity' ;;
      stubborn)   bash -c 'trap "" TERM; while :; do sleep 0.2; done' ;;
      spin)       while :; do :; done ;;
      deadspin)   trap '' TERM; while :; do :; done ;;
      clean)      SG_BAND=0; SG_ARMED_EPOCH="$(( $(date +%s) - 5 ))" ;;
    esac
    section_guard_check
    section_guard_finish
    printf 'SECTION_DONE\n'
    exit 0
  ) >"$dir/out.log" 2>&1
  rc=$?
  case "$want" in
    0)  [ "$rc" = "0" ] && st_ok "$name：套件 exit 0" || st_bad "$name：套件 exit $rc（期望 0）" ;;
    2)  [ "$rc" = "2" ] && st_ok "$name：套件 exit 2（trip 路径）" || st_bad "$name：套件 exit $rc（期望 2）" ;;
    !0) [ "$rc" != "0" ] && st_ok "$name：套件 exit $rc（非零，KILL 路径）" || st_bad "$name：套件 exit 0" ;;
  esac
  local scene
  scene="$(ls -d "$dir"/.teamsmith-smoke-scene.* 2>/dev/null | head -1 || true)"
  if [ "$want_scene" = "1" ]; then
    if [ -n "$scene" ] && [ -s "$scene/summary.txt" ]; then
      st_ok "$name：现场存在且有摘要（${scene#$ST_ROOT/}）"
      grep -qF "selftest-$name" "$scene/summary.txt" && st_ok "$name：现场点名该段" || st_bad "$name：现场没点名该段"
      grep -qF '超时' "$dir/out.log" && st_ok "$name：stdout 有一行点名超时" || st_bad "$name：stdout 没有点名超时"
      grep -qF 'SECTION_DONE' "$dir/out.log" && st_bad "$name：套件居然跑完了整段" || st_ok "$name：套件没有跑完整段"
    else
      st_bad "$name：没有现场（期望有）"
    fi
  else
    [ -z "$scene" ] && st_ok "$name：干净路径没有现场" || st_bad "$name：干净路径留下了现场"
  fi
  # 现场要活过 run 自己的临时根（trip 路径：run-tmp 被删，现场还在）
  if [ "$want_scene" = "1" ] && [ -n "$scene" ]; then
    rm -rf -- "$dir/run-tmp" 2>/dev/null || true
    [ -d "$scene" ] && [ -s "$scene/summary.txt" ] \
      && st_ok "$name：现场活过了 run 临时根被删（清理带不走）" \
      || st_bad "$name：run 临时根删掉后现场也丢了"
  fi
  grep -qF 'BARE_WAIT_RETURNED' "$dir/out.log" && st_ok "$name：裸 wait 没被看门狗卡住" || st_bad "$name：裸 wait 没返回"
  if [ "$shape" = "clean" ]; then
    grep -qF '超过实测带' "$dir/out.log" && st_ok "$name：超过实测带时打一行警告（记录，不是判定）" \
                                          || st_bad "$name：超过实测带没有警告行"
  fi
  local i pidfile
  for i in $(seq 1 25); do
    pidfile="$(ls "$dir"/.teamsmith-smoke-guard.pid.* 2>/dev/null | head -1 || true)"
    [ -z "$pidfile" ] && break
    sleep 0.1
  done
  [ -z "$pidfile" ] && st_ok "$name：看门狗随套件退场（pidfile 已收）" || { st_bad "$name：看门狗 pidfile 还在：$pidfile"; rm -f "$pidfile"; }
  return 0
}

_sg_selftest() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --help|-h) printf '用法：bash %s --self-test\n' "${BASH_SOURCE[0]}"; return 0 ;;
      *) printf 'section-guard: 自检不认识的参数 %s\n' "$arg" >&2; return 2 ;;
    esac
  done
  local PASS=0 FAIL=0
  st_ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
  st_bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
  local ST_ROOT
  ST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/teamsmith-sg-selftest.XXXXXX" 2>/dev/null)" || {
    printf 'section-guard 自检：建不出临时根\n' >&2; return 3; }
  local pgid_before pgid_after
  pgid_before="$(ps -o pgid= -p "$$" 2>/dev/null | tr -d ' ')"
  printf '\n\033[1m== section-guard.sh 自检（五形状 + 现场顺序 + 进程组）==\033[0m\n'
  SG_FIXTURE=1
  TEAM_SMOKE_FIXTURE=1
  _sg_selftest_case clean     clean     0  0
  _sg_selftest_case stuck     stuck     2  1
  _sg_selftest_case stubborn  stubborn  2  1
  _sg_selftest_case spin      spin      2  1
  _sg_selftest_case deadspin  deadspin  '!0' 1
  # 现场尾巴的收集顺序 = mtime 降序，不是 find 的目录顺序（容器实测：目录顺序把挂住的夹具日志
  # 挤出了 12 个名额）。夹具反向：先建 live 文件，再建 15 个「目录顺序更靠前但 mtime 更旧」的。
  local cd="$ST_ROOT/recent"; mkdir -p "$cd"
  : > "$cd/live.txt"
  local i
  for i in $(seq 1 15); do : > "$cd/old-$i.txt"; done
  touch -d '2020-01-01 00:00:00' "$cd"/old-*.txt
  local recent_first recent_n
  recent_first="$(_sg_recent_files "$cd" 0 12 | head -1)"
  recent_n="$(_sg_recent_files "$cd" 0 12 | wc -l | tr -d ' ')"
  [ "$(basename "$recent_first")" = "live.txt" ] \
    && st_ok "现场尾巴：按 mtime 从新到旧（正在被写的那份在最前）" \
    || st_bad "现场尾巴：最新被写的文件不在最前（第一行 ${recent_first:-空}）"
  [ "$recent_n" = "12" ] && st_ok "现场尾巴：名额有界（16 个候选只收 12 个）" \
                          || st_bad "现场尾巴：条数 $recent_n ≠ 12"
  pgid_after="$(ps -o pgid= -p "$$" 2>/dev/null | tr -d ' ')"
  [ "$pgid_before" = "$pgid_after" ] && st_ok "调用者的进程组没变（没有进程组信号）" \
                                     || st_bad "调用者的进程组变了（$pgid_before → $pgid_after）"
  printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
  if [ "$FAIL" -eq 0 ]; then
    rm -rf -- "$ST_ROOT" 2>/dev/null || true
    printf '\033[32msection-guard 自检全绿\033[0m\n'
    return 0
  fi
  printf '\033[31msection-guard 自检有失败项（现场保留 %s）\033[0m\n' "$ST_ROOT"
  return 1
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-}" in
    --self-test) shift; _sg_selftest "$@" ;;
    --help|-h|"") printf '用法：bash %s --self-test（被 smoke.sh source 用）\n' "${BASH_SOURCE[0]}" ;;
    *) printf 'section-guard.sh：只支持 --self-test（被 smoke.sh source 用）\n' >&2; exit 2 ;;
  esac
fi
