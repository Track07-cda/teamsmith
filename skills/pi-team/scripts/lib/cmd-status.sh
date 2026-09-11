#!/usr/bin/env bash
# pi-team · 观察类命令：roster / status / ps / digest / inbox

team_inbox_file() { printf '%s\n' "$(team_inbox_dir)/$1.md"; }

team_inbox_total() { local f; f="$(team_inbox_file "$1")"; [ -f "$f" ] && wc -l < "$f" | tr -d ' ' || printf '0'; }

team_inbox_new() { # <agent> → 未 ack 的行数
  local total acked; total="$(team_inbox_total "$1")"; acked="$(team_state_get "$1" inbox_lines 0)"
  [ "$total" -gt "$acked" ] && printf '%s\n' "$((total - acked))" || printf '0\n'
}

team_inbox_since() { # <agent> → 未 ack 的行
  local f start; f="$(team_inbox_file "$1")"
  [ -f "$f" ] || return 0
  start="$(team_state_get "$1" inbox_lines 0)"
  [ "$start" -gt 0 ] && tail -n +"$((start + 1))" "$f" || cat "$f"
}

team_agent_live() { # <agent> → 0/1：窗口存在**且**里面有进程在跑（空提示符 = pi 已退出）
  local w; w="$(team_state_get "$1" window "$1")"
  team_tmux_has_window "$TEAM_SESSION" "$w" || return 1
  team_pane_busy "$TEAM_SESSION:$w"
}

team_agent_window_exists() { # <agent> → 0/1：只看窗口存在
  local w; w="$(team_state_get "$1" window "$1")"
  team_tmux_has_window "$TEAM_SESSION" "$w"
}

team_git_cols() { # <worktree> → "branch dirty ahead"
  local wt="$1" branch dirty ahead
  [ -d "$wt" ] || { printf -- '-\t-\t-\n'; return 0; }
  branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '-')"
  dirty="$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  if git -C "$wt" rev-parse --verify -q "$TEAM_PROTECTED_BRANCH" >/dev/null 2>&1; then
    ahead="$(git -C "$wt" rev-list --count "$TEAM_PROTECTED_BRANCH..HEAD" 2>/dev/null || echo '?')"
  else
    ahead="?"
  fi
  printf '%s\t%s\t%s\n' "$branch" "$dirty" "$ahead"
}

team_cmd_roster() {
  team_require_docs
  printf '%-10s %-12s %-26s %6s %6s  %s\n' AGENT 状态 分支 脏 领先 任务
  printf '%-10s %-12s %-26s %6s %6s  %s\n' ----- ------ -------------------------- ------ ------ ----
  local a w wt cols branch dirty ahead task state
  for a in $(team_agents); do
    wt="$(team_agent_worktree "$a")"
    if team_agent_live "$a"; then state="● pi 在跑"
    elif team_agent_window_exists "$a"; then state="○ pi 已退出"
    else state="· 无窗口"; fi
    cols="$(team_git_cols "$wt")"
    IFS=$'\t' read -r branch dirty ahead <<< "$cols"
    task="$(team_state_get "$a" task -)"
    printf '%-10s %-12s %-26s %6s %6s  %s\n' "$a" "$state" "$branch" "$dirty" "$ahead" "$task"
  done
  printf '\n● pi 在跑 ｜ ○ 窗口在但 pi 已退出（team resume 可续）｜ · 无窗口 ｜ 脏=未提交 领先=相对 %s\n' "$TEAM_PROTECTED_BRANCH"
  [ -n "$TEAM_SESSION" ] && team_dim "session: $TEAM_SESSION（attach: tmux attach -t $TEAM_SESSION）"
  return 0
}

team_cmd_ps() {
  team_hdr "容量 · $TEAM_PROJECT"
  printf '  %s\n' "$(team_capacity_line)"
  printf '  底线：空闲 swap ≥ %sMB、RAM+swap ≥ %sMB（低于则拒绝派单）；RAM < %sMB 只警告（卡顿）\n' \
    "$TEAM_MIN_FREE_SWAP_MB" "$TEAM_MIN_TOTAL_MB" "$TEAM_WARN_AVAIL_MB"

  printf '\n存活：\n'
  local pm; pm="$(team_pm_state)"
  case "$pm" in
    running:*) printf '  PM（%s）在运行（%s）\n' "$TEAM_PM_WINDOW" "${pm#running:}" ;;
    busy:*)    printf '  PM（%s）窗口有进程在跑（%s，视为存活，不打扰）\n' "$TEAM_PM_WINDOW" "${pm#busy:}" ;;
    idle:*)    printf '  PM（%s）**未在跑**（空提示符）→ team up\n' "$TEAM_PM_WINDOW" ;;
    *)         printf '  PM 窗口缺失 → team up\n' ;;
  esac
  if team_watch_pid_alive; then printf '  watchdog 在跑（pid %s）\n' "$(cat "$TEAM_STATE_DIR/watchdog.pid")"
  else printf '  watchdog 未在跑（team watch / team install-watchdog --yes）\n'; fi

  printf '\n%-30s %8s %8s\n' MODEL RUNNING LIMIT
  printf '%-30s %8s %8s\n' ----- ------- -----
  local m limit running seen=" "
  for m in $TEAM_DEFAULT_MODEL $TEAM_AGENT_MODELS; do
    case "$m" in *=*) m="${m#*=}" ;; esac
    [ -n "$m" ] || continue
    case "$seen" in *" $m "*) continue ;; esac
    seen="$seen$m "
    running="$(team_model_running "$m")"
    limit="$(team_model_limit "$m")"; [ "$limit" = "0" ] && limit="-"
    printf '%-30s %8s %8s\n' "$m" "$running" "$limit"
  done
  printf '\n活跃窗口（%s）：\n' "$TEAM_SESSION"
  team_tmux_windows "$TEAM_SESSION" 2>/dev/null | sed 's/^/  - /' || team_dim "  session 不存在"
  return 0
}

team_cmd_status() {
  team_require_docs
  local id="${1:-}"
  team_cmd_roster
  printf '\n'
  if [ -n "$id" ]; then
    printf '任务 %s：\n' "$id"
    team_board_row "$id" | sed 's/^/  /' || true
    if team_find_report "$id" >/dev/null 2>&1; then
      printf '  报告 %s（%s 行）\n' "$(team_find_report "$id")" "$(wc -l < "$(team_find_report "$id")" | tr -d ' ')"
    else
      printf '  报告：缺失\n'
    fi
    [ -f "$TEAM_DOCS_ABS/reviews/$id.md" ] && printf '  复验 %s\n' "$TEAM_DOCS_ABS/reviews/$id.md"
  else
    printf 'BOARD：\n'
    grep -E '^\|' "$TEAM_DOCS_ABS/BOARD.md" 2>/dev/null | tail -n +3 | sed 's/^/  /' || true
  fi
  return 0
}

team_cmd_digest() {
  team_require_docs
  team_hdr "pi-team digest · $TEAM_PROJECT · $(team_timestamp)"

  local live=0 total=0 a
  for a in $(team_agents); do
    total=$((total + 1)); team_agent_live "$a" && live=$((live + 1))
  done
  printf '\n%s\n' "[1] 容量与存活"
  printf '  agent %s/%s 在跑 ｜ %s' "$live" "$total" "$(team_capacity_line)"
  local pm; pm="$(team_pm_state)"
  case "$pm" in
    running:*) printf '  PM ● 在运行（%s）' "${pm#running:}" ;;
    busy:*)    printf '  PM ● 窗口有进程在跑（%s）' "${pm#busy:}" ;;
    idle:*)    printf '  PM ○ **未在跑**（空提示符）→ team up' ;;
    *)         printf '  PM ○ 窗口缺失 → team up' ;;
  esac
  local wd_state="未配置"
  if team_podman_ok; then
    case "$(team_watch_container_state "$(team_watch_container_name)")" in
      running) wd_state="● 容器在跑" ;;
      absent)  wd_state="○ 容器未创建（$TEAM_CLI watchdog up）" ;;
      *)       wd_state="! 容器 $(team_watch_container_state "$(team_watch_container_name)")（$TEAM_CLI watchdog up）" ;;
    esac
  elif team_watch_pid_alive; then
    wd_state="● 前台 watchdog pid $(cat "$TEAM_STATE_DIR/watchdog.pid")"
  fi
  printf ' ｜ watchdog %s\n' "$wd_state"

  # 待办：这是 watchdog 判断“要不要叫醒 PM”的依据
  local pend; pend="$(team_pending_text || true)"
  if team_in_standby; then
    printf '  待命             on（原因：%s）→ watchdog 不会叫醒 PM；%s standby off 恢复\n' "$(team_standby_reason || echo -)" "$TEAM_CLI"
  fi
  if [ -n "$pend" ]; then
    printf '  待办             %s%s\n' "$pend" "$(team_pm_alive && echo '' || echo '（PM 未在跑：watchdog 会拉起）')"
  else
    printf '  待办             无（watchdog 不会打扰 PM）\n'
  fi

  printf '\n%s\n' "[2] 待处理通知"
  local any=0 n
  for a in $(team_agents); do
    n="$(team_inbox_new "$a")"
    if [ "$n" -gt 0 ]; then
      any=1
      printf '  %s · %s 条新\n' "$a" "$n"
      team_inbox_since "$a" | tail -3 | sed 's/^/      /'
    fi
  done
  [ "$any" -eq 0 ] && team_dim "  （无）"

  printf '\n%s\n' "[3] 待复验（有报告、无复验记录）"
  any=0
  local rep base id
  for rep in "$TEAM_DOCS_ABS/reports/"*.md; do
    [ -f "$rep" ] || continue
    base="$(basename "$rep" .md)"; id="${base%%-*}"
    if [ ! -f "$TEAM_DOCS_ABS/reviews/$id.md" ]; then
      any=1
      printf '  %s  →  %s review %s\n' "$base" "$TEAM_CLI" "$id"
    fi
  done
  # 报告常常还在 agent 分支上（合并前不入主工作树）
  local a wt
  for a in $(team_agents); do
    wt="$(team_agent_worktree "$a")"
    [ -d "$wt/$TEAM_DOCS_DIR/reports" ] || continue
    for rep in "$wt/$TEAM_DOCS_DIR/reports/"*.md; do
      [ -f "$rep" ] || continue
      base="$(basename "$rep" .md)"; id="${base%%-*}"
      [ -f "$TEAM_DOCS_ABS/reviews/$id.md" ] && continue
      any=1
      printf '  %s（在 %s 分支上）  →  %s review %s\n' "$base" "$a" "$TEAM_CLI" "$id"
    done
  done
  [ "$any" -eq 0 ] && team_dim "  （无）"

  printf '\n%s\n' "[4] 任务板"
  grep -E '^\|' "$TEAM_DOCS_ABS/BOARD.md" 2>/dev/null | tail -n +3 | awk -F'|' 'NF>2{
    st=$(NF-1); gsub(/^[ \t]+|[ \t]+$/,"",st);
    if (st=="done") d++; else if (st=="wip") w++; else if (st=="review") r++; else if (st=="blocked") b++; else t++
  } END{printf "  todo=%d wip=%d review=%d blocked=%d done=%d\n", t, w, r, b, d}' || true
  grep -E '^\|' "$TEAM_DOCS_ABS/BOARD.md" 2>/dev/null | tail -n +3 | grep -Ev '\|[[:space:]]*done[[:space:]]*\|' | sed 's/^/  /' || true

  printf '\n%s\n' "[5] 建议"
  local suggestion=0
  for a in $(team_agents); do
    if ! team_agent_live "$a"; then
      local task; task="$(team_state_get "$a" task '')"
      [ -n "$task" ] && { printf '  · %s 未在跑但仍有任务 %s → %s dispatch 续跑，或 close %s\n' "$a" "$task" "$TEAM_CLI" "$task"; suggestion=1; }
    fi
  done
  [ "$suggestion" -eq 0 ] && team_dim "  （无）"
  printf '\n'
}

team_cmd_inbox() {
  local agent="" ack=0 all=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --ack) ack=1; shift ;;
      --all) all=1; shift ;;
      -*) team_usage_die "inbox: 未知参数 $1" ;;
      *) agent="$1"; shift ;;
    esac
  done
  local targets=()
  if [ -n "$agent" ]; then targets=("$agent"); else mapfile -t targets < <(team_agents); fi
  local a n f
  for a in "${targets[@]}"; do
    f="$(team_inbox_file "$a")"
    n="$(team_inbox_new "$a")"
    if [ "$all" = "1" ]; then
      [ -f "$f" ] || continue
      printf '%s === %s（全部 %s 行）%s\n' "$C_BOLD" "$a" "$(team_inbox_total "$a")" "$C_RESET"
      sed 's/^/  /' "$f"
    else
      [ "$n" -gt 0 ] || continue
      printf '%s === %s（新 %s 条）%s\n' "$C_BOLD" "$a" "$n" "$C_RESET"
      team_inbox_since "$a" | sed 's/^/  /'
    fi
    if [ "$ack" = "1" ]; then
      team_state_set "$a" inbox_lines "$(team_inbox_total "$a")"
    fi
  done
  [ "$ack" = "1" ] && team_ok "已标记为已读（--ack）"
  return 0
}

# ---------------------------------------------------------------- 状态面板（watchdog --ui 用）
team_panel() {
  local W=74 line
  line="$(printf '%.0s─' $(seq 1 $W))"
  printf '%spi-team watchdog · %s%s  %s\n' "$C_BOLD" "$TEAM_PROJECT" "$C_RESET" "$(team_timestamp)"
  printf '%s\n' "$line"
  printf '  %-9s %ss（待办才叫醒 PM）｜ 后端 %s\n' "巡检" "${TEAM_WATCH_INTERVAL:-900}" "${TEAM_WATCH_BACKEND:-tmux}"
  if team_in_standby; then
    printf '  %-9s %son%s（原因：%s → %s standby off）\n' "待命" "$C_YEL" "$C_RESET" "$(team_standby_reason || echo -)" "$TEAM_CLI"
  else
    printf '  %-9s off\n' "待命"
  fi
  local pm; pm="$(team_pm_state)"
  case "$pm" in
    running:*) printf '  %-9s %s●%s 在运行（%s）\n' "PM" "$C_GRN" "$C_RESET" "${pm#running:}" ;;
    busy:*)    printf '  %-9s %s●%s 窗口有进程在跑（%s）\n' "PM" "$C_GRN" "$C_RESET" "${pm#busy:}" ;;
    idle:*)    printf '  %-9s %s○%s 未在跑（空提示符）\n' "PM" "$C_YEL" "$C_RESET" ;;
    *)         printf '  %-9s %s○%s 窗口缺失\n' "PM" "$C_YEL" "$C_RESET" ;;
  esac
  local pend; pend="$(team_pending_text)"
  if [ -n "$pend" ]; then printf '  %-9s %s\n' "待办" "$pend"
  else printf '  %-9s %s无 —— 不叫醒 PM%s\n' "待办" "$C_DIM" "$C_RESET"; fi
  printf '  %-9s %s\n' "容量" "$(team_capacity_line)"
  local a state task
  for a in $(team_agents); do
    if team_agent_live "$a"; then state="${C_GRN}●${C_RESET} pi 在跑"
    elif team_agent_window_exists "$a"; then state="${C_YEL}○${C_RESET} pi 已退出"
    else state="${C_DIM}·${C_RESET} 无窗口"; fi
    task="$(team_state_get "$a" task -)"
    printf '  %-9s %s ｜ %s\n' "$a" "$state" "$task"
  done
  printf '%s\n' "$line"
  printf '  最近动作\n'
  if [ -f "$TEAM_STATE_DIR/watchdog.log" ]; then
    tail -6 "$TEAM_STATE_DIR/watchdog.log" | sed -e 's/^\([0-9-]*\)T\([0-9:]*\)Z /    \2 /'
  else
    printf '    %s（还没有动作记录）%s\n' "$C_DIM" "$C_RESET"
  fi
  printf '%s\n' "$line"
  return 0
}
