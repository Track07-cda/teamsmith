#!/usr/bin/env bash
# teamsmith · 后台作业车道：按**记录过的 pid** 看/停作业（P159 · safe-signal-discipline）
#
#   team bg list        读本项目 state 目录（$TEAM_STATE_DIR/bg/*.job）里的作业记录，一行一个作业；
#                       **不发任何信号**；记录里的身份（pid + 启动时间指纹）成不成立逐行标出。
#   team bg stop <id>   只停这个 id 记录到的那一个作业：先证明身份，再发信号；每次拒绝都**什么都没发**。
#
# 身份 = (pid, 启动时间指纹)：pid 会被复用，所以「活着」不是身份。指纹取自 /proc/<pid>/stat 第 22 字段，
# 由 spawner（extension/team-bg.ts）在返回 job id 之前写进 state/bg/<id>.job。
#
# 退出码（机器契约）：
#   0 已停 / 进程早就不在（什么都没发）｜2 用法 ｜3 本项目 state 里没有这个 id 的记录
#   4 记录畸形/读不了 ｜5 身份对不上（pid 复用等）｜6 信号发了但进程还活着
# 每个拒绝路径都**不搜索**：不看别的 state 目录、不看别的项目/会话、不按名字或命令行找进程，
# 也不追猎已结束 leader 的子孙（子孙的 pid 没有记录，找它们就又是「按模式选进程」）。
set -uo pipefail

team_bg_dir() { local d; d="$(team_state_dir)"; printf '%s\n' "$d/bg"; }

# 记录是 key=value 行（值里可能有 =，只取第一个 = 之后的全部）
team_bg_record_get() { # <file> <key> → 值（缺失 → 非 0）
  local _f="$1" _k="$2" _l
  while IFS= read -r _l || [ -n "$_l" ]; do
    case "$_l" in "$_k"=*) printf '%s\n' "${_l#*=}"; return 0 ;; esac
  done < "$_f"
  return 1
}

team_bg_pid_alive() { kill -0 "$1" 2>/dev/null; }

# /proc/<pid>/stat 的 comm 之后第 <i> 个词（0 起）：i=2 是进程组（字段 5），i=19 是启动时间（字段 22）。
# comm 可能带空格/括号，所以按**最后一个** `)` 切开。读不到 → 非 0。
team_bg_proc_stat_word() { # <pid> <i>
  local _pid="$1" _i="$2" _stat _rest; local -a _f=()
  [ -r "/proc/$_pid/stat" ] || return 1
  _stat="$(cat "/proc/$_pid/stat" 2>/dev/null)" || return 1
  _rest="${_stat##*)}"
  read -r -a _f <<< "$_rest"
  printf '%s\n' "${_f[$_i]:-}"
}
team_bg_pgid_of()  { team_bg_proc_stat_word "$1" 2; }
team_bg_start_of() { team_bg_proc_stat_word "$1" 19; }

team_bg_ledger() { # <id> <signal> <result> <pid> <pgid>
  local _d; _d="$(team_state_dir)"
  if ! printf '%s stop id=%s signal=%s result=%s pid=%s pgid=%s by=%s cwd=%s\n' \
      "$(team_timestamp)" "$1" "$2" "$3" "$4" "$5" "$$" "${PWD:-?}" >> "$_d/bg.log" 2>/dev/null; then
    team_warn "bg: 账本 $_d/bg.log 写不进去（作业状态不受影响，但这次 stop 没有留痕）"
  fi
  return 0
}

# ── list：只读本项目 state 目录里的记录，一行一个作业 ────────────────────────────────────────────
team_bg_list() {
  local d f id pid pgid start state n=0
  d="$(team_bg_dir)"
  if [ ! -d "$d" ]; then
    team_dim "（本项目 state 里还没有后台作业记录：$d）"
    return 0
  fi
  for f in "$d"/*.job; do
    [ -f "$f" ] || continue
    id="$(team_bg_record_get "$f" id || true)"
    [ -n "$id" ] || id="$(basename "$f" .job)"
    pid="$(team_bg_record_get "$f" pid || true)"
    pgid="$(team_bg_record_get "$f" pgid || true)"
    start="$(team_bg_record_get "$f" start || true)"
    case "$pid" in
      ''|*[!0-9]*) state="malformed" ;;
      *)
        if ! team_bg_pid_alive "$pid"; then state="gone"
        elif [ -n "$start" ] && [ "$(team_bg_start_of "$pid")" = "$start" ]; then state="holds"
        else state="mismatch"
        fi ;;
    esac
    printf '%-16s pid=%-8s pgid=%-8s identity=%-9s cmd=%s\n' \
      "$id" "${pid:--}" "${pgid:--}" "$state" "$(team_bg_record_get "$f" cmd || true)"
    n=$((n + 1))
  done
  [ "$n" -gt 0 ] || team_dim "（state 里还没有作业记录：$d）"
  return 0
}

# ── stop：只按记录停这一个作业 ──────────────────────────────────────────────────────────────────
team_bg_stop() { # <id>
  local id="${1:-}" d f pid pgid start cmd grace sig target ticks i now_start
  [ -n "$id" ] || team_usage_die "bg stop: 需要一个 job id（team bg list 看全部）"
  d="$(team_bg_dir)"; f="$d/$id.job"
  if [ ! -e "$f" ]; then
    team_err "bg stop: 本项目 state 里没有作业 '$id' 的记录（找过：$f）—— 不按名字/命令行/进程树找进程"
    return 3
  fi
  if [ ! -r "$f" ]; then
    team_err "bg stop: 记录 '$f' 读不了 —— 什么都没发"
    return 4
  fi
  pid="$(team_bg_record_get "$f" pid || true)"
  pgid="$(team_bg_record_get "$f" pgid || true)"
  start="$(team_bg_record_get "$f" start || true)"
  cmd="$(team_bg_record_get "$f" cmd || true)"
  case "$pid" in
    ''|*[!0-9]*) team_err "bg stop: 记录 $f 的 pid 不是数字（'${pid:-<缺失>}'）—— 记录畸形，什么都没发"; return 4 ;;
    *) [ "$pid" -gt 0 ] || { team_err "bg stop: 记录 $f 的 pid 是 0 —— 记录畸形，什么都没发"; return 4; } ;;
  esac
  case "$pgid" in
    ''|*[!0-9]*) team_err "bg stop: 记录 $f 的 pgid 不是数字（'${pgid:-<缺失>}'）—— 记录畸形，什么都没发"; return 4 ;;
  esac
  team_bg_record_get "$f" start >/dev/null \
    || { team_err "bg stop: 记录 $f 没有启动时间指纹（start=）—— 记录畸形，什么都没发"; return 4; }

  if ! team_bg_pid_alive "$pid"; then
    team_info "bg stop: job=$id 记录的进程 $pid 已经不在（什么都没发信号）"
    team_dim "  已结束 leader 的子孙不会被追猎（本车道从不按名字/命令行/进程树找进程）"
    team_bg_ledger "$id" "none" "already-gone" "$pid" "$pgid"
    return 0
  fi

  now_start="$(team_bg_start_of "$pid")"
  if [ -z "$start" ] || [ "$now_start" != "$start" ]; then
    team_err "bg stop: pid $pid 的启动时间指纹对不上（记录 '${start:-<空>}' ≠ 现在 '${now_start:-<读不到>}'）—— 身份不成立（pid 复用？），什么都没发"
    return 5
  fi

  grace="${TEAM_BG_STOP_GRACE:-5}"
  case "$grace" in ''|*[!0-9]*) grace=5 ;; esac
  ticks=$((grace * 10))
  if [ "$pgid" = "$pid" ]; then
    target="group $pgid"
    sig="TERM"
    kill -TERM -- "-$pgid" 2>/dev/null || true
    i=0
    while [ "$i" -lt "$ticks" ] && team_bg_pid_alive "$pid"; do sleep 0.1; i=$((i + 1)); done
    if team_bg_pid_alive "$pid"; then
      kill -KILL -- "-$pgid" 2>/dev/null || true
      sig="TERM,KILL"
      # KILL 之后进程要真的**消失**才算停掉：刚发完信号那一瞬它可能还是僵尸（kill -0 仍为真），
      # 直接判 still-alive 会把「正在死」误报成「停不掉」（exit 6）。最多再等 2s（与宽限无关）。
      i=0
      while [ "$i" -lt 20 ] && team_bg_pid_alive "$pid"; do sleep 0.1; i=$((i + 1)); done
    fi
  else
    target="pid $pid（记录里的 pgid=$pgid ≠ pid：只发这个 pid，**子孙没有被触及**）"
    sig="TERM"
    kill -TERM "$pid" 2>/dev/null || true
    i=0
    while [ "$i" -lt "$ticks" ] && team_bg_pid_alive "$pid"; do sleep 0.1; i=$((i + 1)); done
    if team_bg_pid_alive "$pid"; then
      kill -KILL "$pid" 2>/dev/null || true
      sig="TERM,KILL"
      i=0
      while [ "$i" -lt 20 ] && team_bg_pid_alive "$pid"; do sleep 0.1; i=$((i + 1)); done
    fi
  fi

  if team_bg_pid_alive "$pid"; then
    team_err "bg stop: job=$id 已发 $sig 到 $target，但 pid $pid 仍活着 —— 停止失败"
    team_bg_ledger "$id" "$sig" "still-alive" "$pid" "$pgid"
    return 6
  fi
  team_info "bg stop: job=$id signal=$sig target=$target result=stopped"
  team_dim "  cmd: ${cmd:-<未记录>}"
  team_bg_ledger "$id" "$sig" "stopped" "$pid" "$pgid"
  return 0
}

team_cmd_bg() {
  local sub="${1:-}"
  case "$sub" in
    list)      shift 2>/dev/null || true; team_bg_list ;;
    stop)      shift; team_bg_stop "${1:-}" ;;
    -h|--help) printf '用法：team bg list ｜ team bg stop <id>\n'; return 0 ;;
    '')        team_usage_die "bg: 需要一个子命令（list ｜ stop <id>）" ;;
    *)         team_usage_die "bg: 未知子命令 '$sub'（可用：list ｜ stop <id>）" ;;
  esac
}
