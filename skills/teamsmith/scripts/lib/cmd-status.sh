#!/usr/bin/env bash
# teamsmith · 观察类命令：roster / status / ps / digest / inbox

team_inbox_file() { printf '%s\n' "$(team_inbox_dir)/$1.md"; }

team_inbox_total() { local f; f="$(team_inbox_file "$1")"; [ -f "$f" ] && wc -l < "$f" | tr -d ' ' || printf '0'; }

team_inbox_new() { # <agent> → 未 ack 的行数
  local total acked; total="$(team_inbox_total "$1")"; acked="$(team_state_get "$1" inbox_lines 0)"
  # 文件被截短/重建（acked > total）时 ack 基线失效：把剩下的行当未读重新展示一次。
  # 不这样，一条新消息会因为旧的 ack 计数比文件行数大而**永远看不见**（F26 的 live 现场）。
  case "$acked" in ''|*[!0-9]*) acked=0 ;; esac
  [ "$acked" -gt "$total" ] && acked=0
  [ "$total" -gt "$acked" ] && printf '%s\n' "$((total - acked))" || printf '0\n'
}

team_inbox_since() { # <agent> → 未 ack 的行
  local f start total
  f="$(team_inbox_file "$1")"
  [ -f "$f" ] || return 0
  start="$(team_state_get "$1" inbox_lines 0)"
  case "$start" in ''|*[!0-9]*) start=0 ;; esac
  total="$(team_inbox_total "$1")"
  [ "$start" -gt "$total" ] && start=0          # 与 team_inbox_new 的失效基线保持一致
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

# ---------------------------------------------------------------- 待复验清单（复验证据感知版）
# M6.2 · F3 + F12：common.sh 里那版是「reviews/<ID>.md 存在 == 已复验」，于是
#   ① 记录永远压制待办（分支后来又交付了提交，digest 也不再提示）；
#   ② --no-gates 写的 SKIPPED 记录和 PASS 一样被当成证据。
# 这里覆盖成：只有「记录有效」才算复验过 —— 判定是跑过门禁的
# （PASS/FAIL/TIMEOUT）**且**记录里的 HEAD 就是任务分支当前 tip；
# 分支已被合并删除（解析不到）时记录仍算有效，否则合并后的任务会永远待办。
# 无效的记录不会被静默藏起来：仍列在 digest [3] 里，显示名后带 gates: none / stale: … 标记，
# 这样“没跑过门禁的复验”和“分支在复验后又动了”都看得见。
# 注意：这是对 common.sh 同名函数的**覆盖**（cmd-status.sh 在它之后 source）；pending 逻辑
# 归 M6.2（见 M6.2 任务书），M6.1 负责的状态/看板函数不动。
team_reports_pending_list() { # → 每行 "<id>\t<显示名[ 标记]>\t<路径>"
  local glob base id ids=" " note
  for glob in "$TEAM_DOCS_ABS/reports/"*.md "$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR"/*/"$TEAM_DOCS_DIR"/reports/*.md; do
    [ -f "$glob" ] || continue
    base="$(basename "$glob" .md)"; id="$(team_report_task_id "$glob")"   # F6：id 可以带 '-'，按最长已知前缀取
    case "$ids" in *" $id "*) continue ;; esac
    team_report_is_task "$glob" "$id" || continue
    if [ -f "$(team_review_record_path "$id")" ]; then
      note="$(team_review_record_note "$id")"
      [ -n "$note" ] || continue          # 记录有效且新鲜 → 不算待办
      ids="$ids$id "
      printf '%s\t%s\t%s\n' "$id" "$base [$note]" "$glob"
    else
      ids="$ids$id "
      printf '%s\t%s\t%s\n' "$id" "$base" "$glob"
    fi
  done
}

# F4：push 状态必须相对 @{upstream} 量。旧实现拿保护分支当代理 —— 分支 push 过、又被 squash 合并后，
# 相对保护分支永远「领先 N」，digest 便永远喊「未 push」（头写着未 push，量的却是别的 ref）。
#   <n>  相对 @{upstream} 的领先提交数
#   -    没有 upstream（push 状态**无法判定**，不等于「未 push」）
#   ?    配了 upstream 但解析不到（例如远端分支已被删/被 prune 掉）
team_git_upstream_ahead() { # <worktree> → 见上
  local wt="$1" up
  [ -d "$wt" ] || { printf -- '-\n'; return 0; }
  up="$(git -C "$wt" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
  [ -n "$up" ] || { printf -- '-\n'; return 0; }
  git -C "$wt" rev-list --count '@{upstream}..HEAD' 2>/dev/null || printf '?\n'
}

team_git_cols() { # <worktree> → "branch dirty ahead-of-protected ahead-of-upstream"
  local wt="$1" branch dirty ahead
  [ -d "$wt" ] || { printf -- '-\t-\t-\t-\n'; return 0; }
  branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '-')"
  dirty="$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  if git -C "$wt" rev-parse --verify -q "$TEAM_PROTECTED_BRANCH" >/dev/null 2>&1; then
    ahead="$(git -C "$wt" rev-list --count "$TEAM_PROTECTED_BRANCH..HEAD" 2>/dev/null || echo '?')"
  else
    ahead="?"
  fi
  printf '%s\t%s\t%s\t%s\n' "$branch" "$dirty" "$ahead" "$(team_git_upstream_ahead "$wt")"
}

team_cmd_roster() {
  team_require_docs
  printf '%-10s %-12s %-26s %6s %6s %8s  %s\n' AGENT 状态 分支 脏 领先 未push 任务
  printf '%-10s %-12s %-26s %6s %6s %8s  %s\n' ----- ------ -------------------------- ------ ------ ------ ----
  local a w wt cols branch dirty ahead upahead task state cli
  cli="$(team_agent_cli_name)"
  for a in $(team_agents); do
    wt="$(team_agent_worktree "$a")"
    if team_agent_live "$a"; then state="● $cli 在跑"
    elif team_agent_window_exists "$a"; then state="○ $cli 已退出"
    else state="· 无窗口"; fi
    cols="$(team_git_cols "$wt")"
    IFS=$'\t' read -r branch dirty ahead upahead <<< "$cols"
    task="$(team_state_get "$a" task -)"
    printf '%-10s %-12s %-26s %6s %6s %8s  %s\n' "$a" "$state" "$branch" "$dirty" "$ahead" "$upahead" "$task"
  done
  printf '\n● %s 在跑 ｜ ○ 窗口在但 %s 已退出（team resume 可续）｜ · 无窗口\n' "$cli" "$cli"
  printf '  脏=未提交 ｜ 领先=相对 %s ｜ 未push=相对 @{upstream}（- = 没有 upstream，无法判定）\n' "$TEAM_PROTECTED_BRANCH"
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
    running:*) printf '  PM（%s）在运行（%s%s）\n' "$TEAM_PM_WINDOW" "${pm#running:}" "$(team_pm_proof_suffix)" ;;
    idle:*)    printf '  PM（%s）**未在跑**（空提示符）→ team up\n' "$TEAM_PM_WINDOW" ;;
    unknown:*) printf '  PM（%s）窗口里是**非 PM 进程**（%s，cwd=%s）：不算存活 → team up\n' \
                 "$TEAM_PM_WINDOW" "${pm#unknown:}" "$(team_pane_cwd "$(team_pm_target)" 2>/dev/null || echo '?')" ;;
    foreign:*) printf '  PM（%s）窗口被**别的项目**的进程占着（cwd=%s）：不覆盖\n' \
                 "$TEAM_PM_WINDOW" "$(team_pane_cwd "$(team_pm_target)" 2>/dev/null || echo '?')" ;;
    *)         printf '  PM 窗口缺失 → team up\n' ;;
  esac
  printf '  watchdog %s\n' "$(team_watchdog_state_text)"

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
    [ -f "$TEAM_DOCS_ABS/reviews/$id.md" ] && {
      # F12：路径旁边必须带判定（否则“没跑过门禁的 SKIPPED”和 PASS 在账本上长得一样）
      local rv rhead rnote rextra=""
      rv="$(team_review_record_verdict "$id")"
      rhead="$(team_review_record_head "$id")"
      rnote="$(team_review_record_note "$id")"
      [ -n "$rhead" ] && rextra=" · HEAD $rhead"
      [ -n "$rnote" ] && rextra="$rextra · $rnote"
      printf '  复验 %s（判定: %s%s）\n' "$TEAM_DOCS_ABS/reviews/$id.md" "${rv:-未知}" "$rextra"
    }
  else
    printf 'BOARD：\n'
    grep -E '^\|' "$TEAM_DOCS_ABS/BOARD.md" 2>/dev/null | tail -n +3 | sed 's/^/  /' || true
  fi
  return 0
}

team_cmd_digest() {
  team_require_docs
  team_hdr "teamsmith digest · $TEAM_PROJECT · $(team_timestamp)"

  local live=0 total=0 a
  for a in $(team_agents); do
    total=$((total + 1)); team_agent_live "$a" && live=$((live + 1))
  done
  # skill 版本：本会话加载的 vs 磁盘（skill 更新靠 /reload）
  printf '  %s\n' "$(team_update_notice)"

  printf '\n%s\n' "[1] 容量与存活"
  printf '  agent %s/%s 在跑 ｜ %s' "$live" "$total" "$(team_capacity_line)"
  local pm; pm="$(team_pm_state)"
  case "$pm" in
    running:*) printf '  PM ● 在运行（%s%s）' "${pm#running:}" "$(team_pm_proof_suffix)" ;;
    idle:*)    printf '  PM ○ **未在跑**（空提示符）→ team up' ;;
    unknown:*) printf '  PM ○ 窗口里是非 PM 进程（%s）→ team up' "${pm#unknown:}" ;;
    foreign:*) printf '  PM ○ 窗口被别的项目占着（不覆盖）' ;;
    *)         printf '  PM ○ 窗口缺失 → team up' ;;
  esac
  printf ' ｜ watchdog %s\n' "$(team_watchdog_state_text)"

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
  local any=0 n rlabel
  # 收件人 = 名册 + inbox/ 里实际存在的文件（含 PM 自己的收件箱与打错名字的收件箱）：
  # 写了一行却没人看见是 M6.3 F26/F18 的根因。
  for a in $(team_inbox_recipients); do
    n="$(team_inbox_new "$a")"
    if [ "$n" -gt 0 ]; then
      any=1
      rlabel=""; [ "$a" = "pm" ] && rlabel="（PM 自己的收件箱）"
      printf '  %s%s · %s 条新\n' "$a" "$rlabel" "$n"
      team_inbox_since "$a" | tail -3 | sed 's/^/      /'
    fi
  done
  [ "$any" -eq 0 ] && team_dim "  （无）"
  local ign; ign="$(team_reports_ignored || true)"
  [ -n "$ign" ] && team_dim "  忽略的非任务报告：$(printf '%s' "$ign" | tr '\n' ' ')（里程碑/结项类；要计为任务就让它出现在 BOARD 里）"

  printf '\n%s\n' "[3] 待复验（真任务报告：记录缺失 / 记录已过期（分支又动了）/ 没跑过门禁）"
  any=0
  local rid disp rep
  while IFS=$'\t' read -r rid disp rep; do
    [ -n "$disp" ] || continue
    any=1
    case "$rep" in
      "$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR/"*) 
        local who="${rep#"$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR"/}"; who="${who%%/*}"
        printf '  %s（在 %s 分支上）  →  %s review %s\n' "$disp" "$who" "$TEAM_CLI" "${rid:-${disp%%-*}}" ;;
      *) printf '  %s  →  %s review %s\n' "$disp" "$TEAM_CLI" "${rid:-${disp%%-*}}" ;;
    esac
  done < <(team_reports_pending_list)
  [ "$any" -eq 0 ] && team_dim "  （无）"
  local ign; ign="$(team_reports_ignored || true)"
  [ -n "$ign" ] && team_dim "  忽略的非任务报告：$(printf '%s' "$ign" | tr '\n' ' ')（里程碑/结项类；要计为任务就让它出现在 BOARD 里）"

  # 待收尾：agent 做了活但没收干净（脏工作区 / 相对 upstream 有未 push 的提交）——CEP 实测的盲区。
  # F4：这里只对「真的没 push 出去」报警；领先保护分支是**另一个指标**，单独标出来（旧实现混为一谈）。
  printf '\n%s\n' "[4] 待收尾（脏工作区 / 相对 upstream 未 push 的提交；领先按 $TEAM_PROTECTED_BRANCH 另计）"
  local sa swt sbranch sdirty sahead supahead stask sany=0 sfacts supnote sact
  for sa in $(team_agents); do
    swt="$(team_agent_worktree "$sa")"
    [ -d "$swt" ] || continue
    IFS=$'\t' read -r sbranch sdirty sahead supahead <<< "$(team_git_cols "$swt")"
    sfacts=""; supnote=""
    [ "${sdirty:-0}" -gt 0 ] 2>/dev/null && sfacts="脏 $sdirty"
    case "${supahead:-}" in
      -)  # 没有 upstream：push 状态无法判定，绝不冒充「未 push N」
          supnote="无 upstream（未 push 无法判定）"
          if [ "${sahead:-0}" -gt 0 ] 2>/dev/null; then
            if [ "${TEAM_VCS:-local}" = "local" ]; then supnote="$supnote · 领先 $TEAM_PROTECTED_BRANCH $sahead（本地模式：PM 合并，不需要 push）"
            else supnote="$supnote · 领先 $TEAM_PROTECTED_BRANCH $sahead（要 push 先 git push -u $TEAM_REMOTE HEAD）"; fi
          fi ;;
      '?') sfacts="${sfacts:+$sfacts · }未 push ?（upstream 解析不到）" ;;
      *)   if [ "${supahead:-0}" -gt 0 ] 2>/dev/null; then
             sfacts="${sfacts:+$sfacts · }未 push $supahead（相对 @{upstream}）· 领先 $TEAM_PROTECTED_BRANCH ${sahead:-?}"
           fi ;;
    esac
    [ -n "$sfacts" ] || [ -n "$supnote" ] || continue
    sany=1
    stask="$(team_state_get "$sa" task '-')"
    sact="${sfacts:-—}"; [ -n "$supnote" ] && sact="${sact}${sact:+ ｜ }$supnote"
    printf '  %-10s %-52s ｜ %s ｜ %s\n' "$sa" "$sact" "$sbranch" "$stask"
    if [ -n "$sfacts" ]; then
      case "${supahead:-}" in
        '?') printf '             → %s say %s "收尾：提交并 push（upstream 解析不到：先 git fetch --prune 或重设 upstream）"\n' "$TEAM_CLI" "$sa" ;;
        *)   printf '             → %s say %s "收尾：提交并 push"\n' "$TEAM_CLI" "$sa" ;;
      esac
    fi
  done
  [ "$sany" -eq 0 ] && team_dim "  （无：没有脏工作区，也没有相对 upstream 的未 push 提交）"

  printf '\n%s\n' "[5] 任务板"
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
  if [ -n "$agent" ]; then targets=("$agent"); else mapfile -t targets < <(team_inbox_recipients); fi
  local a n f label
  for a in "${targets[@]}"; do
    f="$(team_inbox_file "$a")"
    n="$(team_inbox_new "$a")"
    label=""; [ "$a" = "pm" ] && label="（PM 自己的收件箱）"
    if [ "$all" = "1" ]; then
      [ -f "$f" ] || continue
      printf '%s === %s%s（全部 %s 行）%s\n' "$C_BOLD" "$a" "$label" "$(team_inbox_total "$a")" "$C_RESET"
      sed 's/^/  /' "$f"
    else
      [ "$n" -gt 0 ] || continue
      printf '%s === %s%s（新 %s 条）%s\n' "$C_BOLD" "$a" "$label" "$n" "$C_RESET"
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
  printf '%steamsmith watchdog · %s%s  %s\n' "$C_BOLD" "$TEAM_PROJECT" "$C_RESET" "$(team_timestamp)"
  printf '%s\n' "$line"
  printf '  %-9s %ss（待办才叫醒 PM；看门狗 = 同 session 的 watchdog 窗口）\n' "巡检" "${TEAM_WATCH_INTERVAL:-900}"
  if team_in_standby; then
    printf '  %-9s %son%s（原因：%s → %s standby off）\n' "待命" "$C_YEL" "$C_RESET" "$(team_standby_reason || echo -)" "$TEAM_CLI"
  else
    printf '  %-9s off\n' "待命"
  fi
  local pm; pm="$(team_pm_state)"
  case "$pm" in
    running:*) printf '  %-9s %s●%s 在运行（%s）\n' "PM" "$C_GRN" "$C_RESET" "${pm#running:}" ;;
    idle:*)    printf '  %-9s %s○%s 未在跑（空提示符）\n' "PM" "$C_YEL" "$C_RESET" ;;
    unknown:*) printf '  %-9s %s○%s 窗口里是非 PM 进程（%s）\n' "PM" "$C_YEL" "$C_RESET" "${pm#unknown:}" ;;
    foreign:*) printf '  %-9s %s○%s 窗口被别的项目占着\n' "PM" "$C_YEL" "$C_RESET" ;;
    *)         printf '  %-9s %s○%s 窗口缺失\n' "PM" "$C_YEL" "$C_RESET" ;;
  esac
  local pend; pend="$(team_pending_text)"
  if [ -n "$pend" ]; then printf '  %-9s %s\n' "待办" "$pend"
  else printf '  %-9s %s无 —— 不叫醒 PM%s\n' "待办" "$C_DIM" "$C_RESET"; fi
  printf '  %-9s %s\n' "容量" "$(team_capacity_line)"
  local a state task cli
  cli="$(team_agent_cli_name)"
  for a in $(team_agents); do
    if team_agent_live "$a"; then state="${C_GRN}●${C_RESET} $cli 在跑"
    elif team_agent_window_exists "$a"; then state="${C_YEL}○${C_RESET} $cli 已退出"
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
