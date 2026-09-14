#!/usr/bin/env bash
# teamsmith · PM 相关：up（恢复 PM）/ resume（PM 工具）/ watch（前台巡检）/ watchdog（看门狗窗口）/ standby（PM 停工）
#
# 设计前提：**不依赖任何 agent（包括 PM）来负责恢复**。
#   - PM 没在跑且有待办 → watchdog 用 pi -c 把它拉起来（历史不丢）
#   - agent 停了 → 不管（agent 归 PM 管：team resume）
#   - watchdog 自己挂了 → 由 PM 手动 `team watchdog up` 重建（**只有一个后端**：同 session 的 tmux 窗口；
#     不引入第二个运行时不代表没有恢复能力：PM 被叫醒后第一件事就是看 watchdog-status）
# 所有状态都在磁盘上（state/ + docs/ + git 分支），所以任何一环重启都是可续的。

team_watch_log() { printf '%s\n' "$TEAM_STATE_DIR/watchdog.log"; }

team_wlog() { # <line>
  mkdir -p "$TEAM_STATE_DIR"
  printf '%s %s\n' "$(team_timestamp)" "$1" >> "$(team_watch_log)"
  # 只保留最近 500 行，避免无限长大
  # （注意：必须写成 if 块并显式 return 0——函数最后一条命令失败会让调用方在 set -e 下直接退出）
  local f; f="$(team_watch_log)"
  if [ "$(wc -l < "$f")" -gt 500 ]; then
    tail -n 500 "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  fi
  return 0
}

team_watch_pid_alive() {
  local pidf="$TEAM_STATE_DIR/watchdog.pid" pid
  [ -f "$pidf" ] || return 1
  pid="$(cat "$pidf" 2>/dev/null)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then return 0; fi
  return 1
}

team_watch_lock() { # 防止两个 watchdog 打架
  if team_watch_pid_alive; then
    team_err "watchdog 已在运行（pid $(cat "$TEAM_STATE_DIR/watchdog.pid")）；停止它：`team watchdog status` 看详情，kill 掉即可"
    return 1
  fi
  mkdir -p "$TEAM_STATE_DIR"
  printf '%s\n' "$$" > "$TEAM_STATE_DIR/watchdog.pid"
  return 0
}

team_watch_unlock() { rm -f "$TEAM_STATE_DIR/watchdog.pid"; }

# ---------------------------------------------------------------- team up
# 人来跑的工具：把 PM 恢复起来。
# agent 归 PM 管，所以默认不动 agent；要顺手把停了的 agent 也续起来就加 --agents。
team_cmd_up() {
  local with_agents=0 show_prompt=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --agents) with_agents=1; shift ;;
      --print) show_prompt=1; shift ;;
      -*) team_usage_die "up: 未知参数 $1" ;;
      *) team_usage_die "up: 多余参数 $1" ;;
    esac
  done

  if [ "$show_prompt" = "1" ]; then team_pm_prompt; return 0; fi

  team_require_docs
  team_require_cmd tmux "team up 需要 tmux（PM 跑在 tmux 窗口里）"
  team_assert_own_session "team up" || team_die "team up 拒绝在「不属于本项目的 session」上动手（见上）"
  team_hdr "teamsmith up · $TEAM_PROJECT（只负责 PM）"

  # 1) tmux 场地：人跑 up 就是明确要求“把工地建起来”，所以这里允许建 session/窗口
  if ! team_tmux_has_session "$TEAM_SESSION"; then
    team_warn "tmux session '$TEAM_SESSION' 不存在：重建"
    team_tmux_ensure_session
    tmux set-option -t "$TEAM_SESSION" destroy-unattached off >/dev/null 2>&1 || true
  fi
  if ! team_pm_window_exists; then
    team_tmux_new_window "$TEAM_SESSION" "$TEAM_PM_WINDOW" || true
    team_ok "创建 PM 窗口 $TEAM_SESSION:$TEAM_PM_WINDOW"
  fi

  # 2) PM 进程
  local pm_state; pm_state="$(team_pm_state)"
  case "$pm_state" in
    running:*) team_ok "PM 在运行（${pm_state#running:}）" ;;
    idle:*)    team_warn "PM 没在跑（空提示符）：启动 pi"
               if team_pm_start; then
                 team_ok "PM 已启动（proof=$(team_pm_proof || echo '?')，model=${TEAM_PM_MODEL:-$TEAM_DEFAULT_MODEL}，$([ -n "$TEAM_PM_SESSION_ID" ] && echo "--session-id $TEAM_PM_SESSION_ID" || echo "-c 延续上一会话")）"
               else
                 team_err "PM 启动失败：请手动到 $TEAM_SESSION:$TEAM_PM_WINDOW 里跑 pi"
               fi ;;
    unknown:*)
               # 窗口里是本项目 cwd 的**非 PM** 进程（新建空窗的瞬态、sleep、编辑器…）：
               # 不是 PM 就不能压制恢复（M6.5 就是「空窗被当成 PM，up 什么也不干还说成功」）
               local _ucwd; _ucwd="$(team_pane_cwd "$(team_pm_target)" 2>/dev/null || echo '?')"
               team_warn "PM 窗口里有非 PM 进程（${pm_state#unknown:}，cwd=$_ucwd）：不算存活"
               if team_pm_start; then
                 team_ok "PM 已启动（替换了非 PM 进程；proof=$(team_pm_proof || echo '?')，model=${TEAM_PM_MODEL:-$TEAM_DEFAULT_MODEL}）"
               else
                 team_err "PM 启动失败：请手动到 $TEAM_SESSION:$TEAM_PM_WINDOW 里跑 pi"
               fi ;;
    foreign:*)
               local _cwd; _cwd="$(team_pane_cwd "$(team_pm_target)" 2>/dev/null || echo '?')"
               if [ "${TEAM_REPLACE_FOREIGN_PM:-0}" = "1" ]; then
                 team_warn "PM 窗口被外来进程占用（cwd=$_cwd）：按 TEAM_REPLACE_FOREIGN_PM=1 覆盖"
                 if team_pm_start; then
                   team_ok "PM 已启动（覆盖了外来进程；proof=$(team_pm_proof || echo '?')）"
                 else
                   team_err "覆盖失败：看上面的原因"
                 fi
               else
                 team_warn "PM 窗口 $TEAM_SESSION:$TEAM_PM_WINDOW 被不属于本项目的进程占用（cwd=$_cwd）：不覆盖、也不新开窗口"
                 team_dim "  关掉那个窗口（或改窗口名）后重跑 $TEAM_CLI up；确认要覆盖：TEAM_REPLACE_FOREIGN_PM=1 $TEAM_CLI up"
               fi ;;
    *)         team_warn "PM 窗口状态异常（$pm_state）：不抢窗口" ;;
  esac

  # 3) 可选：agent 续跑（默认不做：agent 由 PM 决定）
  if [ "$with_agents" = "1" ]; then
    team_info ""
    team_cmd_resume
  else
    team_dim "  agent 不归 watchdog/up 管：需要续跑时跑 $TEAM_CLI resume [--dry-run]"
  fi

  if team_in_standby; then
    team_warn "注意：当前 standby on（原因：$(team_standby_reason || echo -)）。watchdog 不会自动叫醒 PM；处理好后跑 $TEAM_CLI standby off"
  fi

  team_info ""
  team_capacity_line
  team_dim "  旁观：tmux attach -t $TEAM_SESSION ｜ 待办：$TEAM_CLI digest"
  return 0
}

# ---------------------------------------------------------------- team resume（PM 的工具）
# 注意：watchdog 不调用这个。agent 的启停由 PM 决定（PM 开场会 --dry-run 看一眼）。
team_cmd_resume() {
  local only="" all=1 dry=0 quiet=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --agent) only="${2:?}"; all=0; shift 2 ;;
      --all) all=1; shift ;;
      --dry-run) dry=1; shift ;;
      --quiet) quiet=1; shift ;;
      -*) team_usage_die "resume: 未知参数 $1" ;;
      # 位置参数也当 agent 名（erp 反馈：team resume dev 应该能用）
      *) if [ -z "$only" ]; then only="$1"; all=0; shift; else team_usage_die "resume: 多余参数 $1"; fi ;;
    esac
  done
  team_require_docs
  [ -n "$only" ] && team_require_agent "$only"

  local a task taskfile live=0 n=0
  [ "$quiet" != "1" ] && team_hdr "teamsmith resume · $TEAM_PROJECT"
  for a in $(team_agents); do
    [ -n "$only" ] && [ "$a" != "$only" ] && continue
    task="$(team_state_get "$a" task '')"
    [ -n "$task" ] || continue
    if team_agent_live "$a"; then live=$((live + 1)); continue; fi
    taskfile="$(team_state_get "$a" taskfile '')"
    if [ ! -f "$taskfile" ]; then
      team_warn "$a：任务 $task 的任务书不见了（$taskfile）→ 写 thread，跳过"
      team_cmd_thread "$a" --re "$task" "watchdog 想续跑 $task，但任务书 $taskfile 不存在。请 PM 重新生成或改用 --task 指定。" >/dev/null 2>&1 || true
      team_inbox_append "$a" blocked "watchdog: 任务书丢失，无法续跑 $task"
      continue
    fi
    n=$((n + 1))
    if [ "$dry" = "1" ]; then
      printf '  %s 可续跑：%s → %s\n' "$a" "$task" "$taskfile"
    else
      team_info "  续跑 $a · $task"
      if team_cmd_dispatch "$a" "$task" "$taskfile"; then
        team_wlog "resume agent=$a task=$task"
      else
        # 常见两类：容量/并发排队（正常），或工作树状态不允许（需要 PM 处理）
        team_warn "$a 续跑没成功：看上面一行原因（容量/并发属正常排队；工作树脏/分支不对要 PM 处理）"
      fi
    fi
  done
  if [ "$n" -eq 0 ]; then
    [ "$quiet" != "1" ] && team_dim "  没有需要续跑的 agent（在跑 $live 个）"
  fi
  return 0
}

# ---------------------------------------------------------------- team watch
# watchdog 就是“定时看看有没有活儿，并叫醒 PM”：
#   ① 每次记一行容量趋势
#   ② 算一下待办（未读通知/待复验/看板/pM 仍归它管的 agent 停了）
#   ③ 有待办 → 叫醒 PM（在跑就发一句提醒；不在跑且非待命就把它拉起来）
#      没待办 → 不叫醒、不启动（不要求 PM 一直运行）
#   ④ PM 主动 standby 期间，一律不叫醒（人处理后 standby off）
# 不管 tmux 布局（除非 TEAM_WATCH_REBUILD_TMUX=1），不管 agent（那是 PM 的事）。
team_watch_once() {
  mkdir -p "$TEAM_STATE_DIR"

  # ① 容量留痕（只观察，不干预）
  local cap; cap="$(team_capacity_line)"
  printf '%s %s\n' "$(team_timestamp)" "$cap" >> "$TEAM_STATE_DIR/capacity.log"
  if [ "$(wc -l < "$TEAM_STATE_DIR/capacity.log")" -gt 500 ]; then
    tail -n 500 "$TEAM_STATE_DIR/capacity.log" > "$TEAM_STATE_DIR/capacity.log.tmp" && \
      mv "$TEAM_STATE_DIR/capacity.log.tmp" "$TEAM_STATE_DIR/capacity.log"
  fi
  printf '%s %s\n' "$(date +%s)" "$(team_timestamp)" > "$TEAM_STATE_DIR/watchdog.last"

  # ② 待办
  local counts text sig
  counts="$(team_pending_counts)"
  text="$(team_pending_text "$counts")"
  sig="$(team_pending_sig "$counts")"

  # ④ 待命：PM 明确说了不要叫醒它
  if team_in_standby; then
    local sbreason; sbreason="$(team_standby_reason || echo -)"
    if [ "$sig" != "$(team_state_get _watch last_sig '')" ] || [ -n "$text" ]; then
      team_state_set _watch last_sig "$sig"
      team_wlog "standby 中：不叫醒 PM（原因：$sbreason）${text:+；待办积压：$text}"
    fi
    return 0
  fi

  # ③a 没待办：不叫醒、不启动（不要求 PM 一直跑）
  if [ -z "$text" ]; then
    if [ "$(team_state_get _watch last_sig '')" != "$sig" ]; then
      team_state_set _watch last_sig "$sig"
      team_wlog "无待办：不叫醒 PM"          # 日志去重（避免每 15 分钟刷一行）
    fi
    # CLI 每次都明确说结论（便于人看、便于脚本断言）
    if team_pm_alive; then
      team_dim "watchdog: 无待办（PM 在跑：不打扰）"
    else
      team_dim "watchdog: 无待办（PM 未在跑：不启动，等有活再叫）"
    fi
    return 0
  fi

  # ③b 有待办
  if team_pm_alive; then
    local last_epoch last_sig gap now
    now="$(date +%s)"
    last_epoch="$(team_state_get _watch nudge_epoch 0)"
    last_sig="$(team_state_get _watch nudge_sig '')"
    gap="${TEAM_WATCH_NUDGE_GAP:-900}"
    if [ "$sig" != "$last_sig" ] || [ $((now - last_epoch)) -ge "$gap" ]; then
      team_nudge "$text"
      team_state_set _watch nudge_epoch "$now"
      team_state_set _watch nudge_sig "$sig"
      team_state_set _watch last_sig "$sig"
      team_wlog "叫醒 PM：$text"
      team_ok "watchdog: 有待办（$text）→ 已提醒 PM"
    fi
    return 0
  fi

  # ③c 有待办但 PM 没在跑 → 把它拉起来（除非 tmux 场地不在且不允许重建）
  #     idle（空提示符）与 unknown（本项目里的非 PM 占用者）都算「没有 PM」；foreign 不碰。
  local st; st="$(team_pm_state)"
  case "$st" in
    idle:*) ;;
    unknown:*) team_wlog "PM 窗口里不是 PM（$st）：按「没有 PM」处理" ;;
    *)
      if [ "${TEAM_WATCH_REBUILD_TMUX:-0}" = "1" ]; then
        if ! team_assert_own_session "watchdog 重建 tmux"; then
          team_wlog "拒绝重建：session '${TEAM_SESSION:-}' 不属于本项目（授权后加 --yes 或 TEAM_ALLOW_FOREIGN_SESSION=1）"
          return 0
        fi
        if ! team_tmux_has_session "$TEAM_SESSION"; then
          team_wlog "tmux session 丢失，重建（TEAM_WATCH_REBUILD_TMUX=1）"
          team_tmux_ensure_session
          tmux set-option -t "$TEAM_SESSION" destroy-unattached off >/dev/null 2>&1 || true
        fi
        if ! team_pm_window_exists; then
          team_wlog "PM 窗口丢失，重建（TEAM_WATCH_REBUILD_TMUX=1）"
          team_tmux_new_window "$TEAM_SESSION" "$TEAM_PM_WINDOW" || true
        fi
      else
        if [ "$sig" != "$(team_state_get _watch last_sig '')" ]; then
          team_state_set _watch last_sig "$sig"
          team_wlog "有待办（$text）但 PM 找不到（$st）：watchdog 不管 tmux，不重建；请人工 $TEAM_CLI up"
          team_warn "watchdog: 有待办（$text）但 PM 找不到（$st）—— tmux 场地不在，需要人工 $TEAM_CLI up（不想人工就设 TEAM_WATCH_REBUILD_TMUX=1）"
        fi
        return 0
      fi ;;
  esac

  if team_pm_can_restart && team_pm_start; then
    team_state_set _watch last_sig "$sig"
    team_wlog "PM 未在运行（$st）→ 已拉起（待办：$text）"
    team_ok "watchdog: 有待办（$text）但 PM 没在跑（$st）→ 已拉起"
    team_inbox_append pm watchdog "PM 会话曾停止（状态 $st），watchdog 因有待办（$text）而用 pi -c 拉起它并注入开场提示词（state/pm-prompt.md）"
  else
    team_wlog "PM 拉起失败或被配额拦下（$st；待办：$text）"
    team_warn "watchdog: PM 拉起失败或被配额拦下（$st；待办：$text）"
  fi
  return 0
}

team_cmd_watch() {
  local once=0 interval="${TEAM_WATCH_INTERVAL:-900}" ui=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --once) once=1; shift ;;
      --ui) ui=1; shift ;;
      --interval) interval="${2:?}"; shift 2 ;;
      -*) team_usage_die "watch: 未知参数 $1" ;;
      *) team_usage_die "watch: 多余参数 $1" ;;
    esac
  done
  team_require_docs

  if [ "$ui" = "1" ]; then team_cmd_monitor ${once:+--once}; return $?; fi

  if [ "$once" = "1" ]; then
    team_watch_once
    team_ok "watch --once 完成（日志：${TEAM_STATE_DIR#"$TEAM_MAIN_ROOT"/}/watchdog.log）"
    return 0
  fi

  team_require_cmd tmux "watchdog 需要 tmux 来拉起 PM/agent"
  team_watch_lock || return 1
  trap 'team_watch_unlock' EXIT INT TERM
  team_hdr "teamsmith watchdog · $TEAM_PROJECT（每 ${interval}s 一次；Ctrl-C 退出）"
  team_dim "  只做两件事：记录容量趋势 ｜ PM 没在跑就在它的窗口里把 pi 拉起来"
  team_dim "  不管 tmux 布局，不管 agent（agent 归 PM 管：team resume）"
  while :; do
    team_watch_once
    sleep "$interval"
  done
}


# ---------------------------------------------------------------- team monitor
# tmux 窗口里的「状态监视器」：上面是团队状态（PM/待办/容量），下面是每个 agent 的会话活动流。
# 顺带按 TEAM_WATCH_INTERVAL 跑看门狗 tick —— 所以一个窗口同时是显示器 + 看门狗。
team_monitor_activity() { # 可选：只渲染「当前 tmux session 里正在跑的窗口」的会话活动
  local runner; runner="$(team_js_runner)"
  local js="$TEAM_SKILL_DIR/scripts/monitor.mjs"
  if [ -z "$runner" ] || [ ! -f "$js" ]; then
    team_dim "  （本机没有 node/bun/tsx：活动流不可用）"
    return 0
  fi
  # 只监视本 session 里活着的人：不在这个 session / 窗口没了的 agent 一律不看（不翻别人的会话）
  local only="" a w
  for a in $(team_agents); do
    w="$(team_state_get "$a" window "$a")"
    if team_tmux_has_window "$TEAM_SESSION" "$w"; then only="${only:+$only,}$a"; fi
  done
  team_pm_window_exists && only="${only:+$only,}pm"
  if [ -z "$only" ]; then
    team_dim "  （本 session 里没有在跑的窗口）"
    return 0
  fi
  # 非 Pi agent：可选的日志/会话文件通配（TEAM_AGENT_LOG_GLOB）→ 显示最新匹配文件的尾部
  local globargs=()
  [ -n "${TEAM_AGENT_LOG_GLOB:-}" ] && globargs=(--log-glob "$TEAM_AGENT_LOG_GLOB")
  "$runner" "$js" --root "$TEAM_MAIN_ROOT" --only "$only" --events "${TEAM_MONITOR_EVENTS:-4}" \
    ${globargs[@]+"${globargs[@]}"} 2>/dev/null || true
}

team_cmd_monitor() {
  local once=0 interval="${TEAM_MONITOR_REFRESH:-5}" with_watchdog=1 activity="${TEAM_MONITOR_ACTIVITY:-0}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --once) once=1; shift ;;
      --no-watchdog) with_watchdog=0; shift ;;
      --activity) activity=1; shift ;;
      --no-activity) activity=0; shift ;;
      --interval) interval="${2:?}"; shift 2 ;;
      --events) TEAM_MONITOR_EVENTS="${2:?}"; shift 2 ;;
      -*) team_usage_die "monitor: 未知参数 $1" ;;
      *) team_usage_die "monitor: 多余参数 $1" ;;
    esac
  done
  team_require_docs
  local ticklog="$TEAM_STATE_DIR/watchdog.tick.log" last_tick=0 now
  while :; do
    clear
    printf '%steamsmith monitor · %s%s  %s  %s(每 %ss 刷新%s)%s\n' \
      "$C_BOLD" "$TEAM_PROJECT" "$C_RESET" "$(team_timestamp)" "$C_DIM" "$interval" \
      "$([ "$with_watchdog" = 1 ] && echo "，每 ${TEAM_WATCH_INTERVAL:-900}s 跑一次巡检" || echo '')" "$C_RESET"
    team_panel | tail -n +2
    if [ "$activity" = "1" ]; then
      printf '\n  %sagent 活动%s%s（仅本 session 在跑的窗口；--no-activity 关掉）%s\n' \
        "$C_BOLD" "$C_RESET" "$C_DIM" "$C_RESET"
      [ -n "${TEAM_AGENT_LOG_GLOB:-}" ] && \
        printf '  %s源：TEAM_AGENT_LOG_GLOB=%s（非 Pi agent 显示最新日志尾部）%s\n' "$C_DIM" "$TEAM_AGENT_LOG_GLOB" "$C_RESET"
      team_monitor_activity
    fi
    printf '%s  Ctrl-C 退出本窗口（不影响 PM）｜ %s watchdog status / logs / down%s\n' \
      "$C_DIM" "$TEAM_CLI" "$C_RESET"
    printf '%s  看门狗只服务本 session：窗口/任务/待办/容量；巡检每 %ss，面板每 %ss%s\n' \
      "$C_DIM" "${TEAM_WATCH_INTERVAL:-900}" "$interval" "$C_RESET"
    if [ "$with_watchdog" = "1" ]; then
      now="$(date +%s)"
      if [ $((now - last_tick)) -ge "${TEAM_WATCH_INTERVAL:-900}" ]; then
        last_tick="$now"
        mkdir -p "$TEAM_STATE_DIR"
        team_watch_once >>"$ticklog" 2>&1
        if [ "$(wc -l < "$ticklog" 2>/dev/null || echo 0)" -gt 200 ]; then
          tail -n 200 "$ticklog" > "$ticklog.tmp" && mv "$ticklog.tmp" "$ticklog"
        fi
      fi
    fi
    [ "$once" = "1" ] && break
    sleep "$interval"
  done
  return 0
}

# ---------------------------------------------------------------- watchdog：只有一个后端（tmux 窗口）
# 由 PM（或人）用 `team watchdog up` 启动：同一个 tmux session 的 `watchdog` 窗口常驻跑
# `team monitor`（上半屏团队状态，下半屏可选活动流），并按其内部节拍做定时巡检。
# 为什么不做第二个后端（容器/systemd 等）：本 skill 的底线是**依赖越少越可靠**——
# 少一个运行时、少一层 socket/权限/镜像问题，出问题时只有一个地方要查；
# 看门狗的职责只是"定时看看有没有活儿、有待办就叫醒 PM"，它不需要跨 tmux server 存活
# （tmux server 没了 PM 也没了，重建时一起起来即可，`team up` / `watchdog up` 都在）。

# 统一的后端无关存活判定（ps / digest / doctor / watchdog status 都用它）
# 输出 "tmux:<session>:<window>" | "fg:<pid>" | "container:<name>" | "off"
team_watchdog_state() {
  local w st
  w="$(team_watch_window)"
  st="$(team_watch_window_state)"
  case "$st" in
    running) printf 'tmux:%s:%s\n' "$TEAM_SESSION" "$w"; return 0 ;;
  esac
  if team_watch_pid_alive; then printf 'fg:%s\n' "$(cat "$TEAM_STATE_DIR/watchdog.pid")"; return 0; fi
  # 窗口在、但前台不是我们认识的面板命令（比如 pager/子进程）→ 只要 pane 忙就算在跑，避免误报
  if team_tmux_has_window "$TEAM_SESSION" "$w" && team_pane_busy "$TEAM_SESSION:$w"; then
    printf 'tmux:%s:%s\n' "$TEAM_SESSION" "$w"; return 0
  fi
  printf 'off\n'
}

team_watchdog_state_text() {
  local st; st="$(team_watchdog_state)"
  case "$st" in
    tmux:*:*)    printf '● tmux 窗口 %s 在跑' "${st#tmux:}" ;;
    fg:*)        printf '● 前台 watchdog pid %s' "${st#fg:}" ;;

    *)           printf '○ 未在跑（%s watchdog up）' "$TEAM_CLI" ;;
  esac
  return 0
}

# tmux 后端（默认）：看门狗就住在同一个 tmux session 的 `watchdog` 窗口里。
# 好处：① 与开发环境同版本（tmux/ps/git/pi 都在原环境）；② 顺手就是个状态监视器（--ui 面板）；
#       ③ 少一层容器。代价：tmux server 死了它也死（但那时 PM 也死了，重建时一起起来）。
team_watch_window() { printf '%s\n' "${TEAM_WATCH_WINDOW:-watchdog}"; }

team_watch_window_state() { # running:<cmd> | idle:<cmd> | absent
  local w; w="$(team_watch_window)"
  team_tmux_has_window "$TEAM_SESSION" "$w" || { printf 'absent'; return 0; }
  if team_pane_busy "$TEAM_SESSION:$w"; then printf 'running'; else printf 'idle'; fi
}

team_watch_tmux_up() {
  team_require_cmd tmux "看门狗需要 tmux（它就跑在同 session 的窗口里）"
  team_tmux_ensure_session
  tmux set-option -t "$TEAM_SESSION" destroy-unattached off >/dev/null 2>&1 || true
  local w st; w="$(team_watch_window)"; st="$(team_watch_window_state)"
  if [ "$st" = "running" ]; then team_ok "看门狗已在跑：$TEAM_SESSION:$w（面板：tmux attach -t $TEAM_SESSION）"; return 0; fi
  [ "$st" = "idle" ] && { team_warn "窗口 $w 停在空提示符：重开"; tmux kill-window -t "$TEAM_SESSION:$w" 2>/dev/null || true; }
  tmux new-window -t "$TEAM_SESSION" -n "$w" -d -- bash "$TEAM_SKILL_DIR/scripts/team" monitor
  sleep 1.5
  st="$(team_watch_window_state)"
  if [ "$st" = "running" ]; then
    team_ok "看门狗已在 $TEAM_SESSION:$w 跑（每 ${TEAM_WATCH_INTERVAL:-900}s 一屏；logs: $TEAM_CLI watchdog logs）"
  else
    team_err "窗口起来了但没在跑（$st）：tmux attach -t $TEAM_SESSION 看输出"
    return 1
  fi
}

team_watch_tmux_down() {
  local w; w="$(team_watch_window)"
  if team_tmux_has_window "$TEAM_SESSION" "$w"; then
    tmux kill-window -t "$TEAM_SESSION:$w" 2>/dev/null && team_ok "已关掉看门狗窗口：$TEAM_SESSION:$w" || team_warn "关窗口失败"
  else
    team_dim "没有看门狗窗口（$TEAM_SESSION:$w）"
  fi
}

team_watch_tmux_logs() { # 打印面板最近若干行（pane 快照）
  local w; w="$(team_watch_window)"
  team_tmux_has_window "$TEAM_SESSION" "$w" || { team_err "没有看门狗窗口（$TEAM_SESSION:$w）；$TEAM_CLI watchdog up 起一个"; return 1; }
  tmux capture-pane -p -t "$TEAM_SESSION:$w" -S -60 2>/dev/null | sed '/^$/d' | tail -60
}

team_cmd_watchdog() {
  local sub="status" print_only=0
  while [ $# -gt 0 ]; do
    case "$1" in
      up|down|restart|status|logs) sub="$1"; shift ;;
      --print) print_only=1; shift ;;     # 打印它会做什么（不执行）
      --container) team_usage_die "watchdog: 容器后端已移除（v1.12.0）——看门狗就是同 session 的 watchdog 窗口；用 team watchdog up" ;;
      -*) team_usage_die "watchdog: 未知参数 $1" ;;
      *) team_usage_die "watchdog: 多余参数 $1" ;;
    esac
  done
  team_require_docs

  if [ "$print_only" = "1" ]; then
    printf 'tmux 窗口：%s:%s → bash %s/scripts/team monitor\n' "$TEAM_SESSION" "$(team_watch_window)" "$TEAM_SKILL_DIR"
    printf '巡检周期：%ss（TEAM_WATCH_INTERVAL）\n' "${TEAM_WATCH_INTERVAL:-900}"
    return 0
  fi
  case "$sub" in
    up)      team_watch_tmux_up ;;
    down)    team_watch_tmux_down ;;
    restart) team_watch_tmux_down >/dev/null 2>&1 || true; team_watch_tmux_up ;;
    logs)    team_watch_tmux_logs ;;
    status)  team_cmd_watchdog_status ;;
  esac
  return $?
}

# 兼容旧名字：install/uninstall-watchdog 现在是 watchdog up/down 的别名
team_cmd_install_watchdog() { team_cmd_watchdog up "$@"; }
team_cmd_uninstall_watchdog() { team_cmd_watchdog down "$@"; }

team_cmd_watchdog_status() {
  team_hdr "teamsmith watchdog · $TEAM_PROJECT"
  local w tst
  w="$(team_watch_window)"; tst="$(team_watch_window_state)"
  case "$tst" in
    running) team_ok "  看门狗           tmux 窗口 $TEAM_SESSION:$w 在跑（--ui 面板）" ;;
    idle)    team_warn "  看门狗           窗口 $w 停在空提示符 → $TEAM_CLI watchdog up" ;;
    *)       team_dim "  看门狗           未起 → $TEAM_CLI watchdog up" ;;
  esac
  printf '  后端             tmux（同 session 的窗口 —— 只有一个后端，无容器依赖）\n'
  printf '  日志             %s watchdog logs ／ tmux attach -t %s\n' "$TEAM_CLI" "$TEAM_SESSION"
  printf '  巡检周期         %ss（建议 300~3600；不是心跳保活，是定时看看有没有活儿）\n' "${TEAM_WATCH_INTERVAL:-900}"
  printf '  tmux 重建         %s\n' "$([ "${TEAM_WATCH_REBUILD_TMUX:-0}" = "1" ] && echo '允许（TEAM_WATCH_REBUILD_TMUX=1）' || echo '不接管（session/窗口没了只告警）')"
  local pm; pm="$(team_pm_state)"
  case "$pm" in
    running:*) team_ok "  PM              在运行（${pm#running:}$(team_pm_proof_suffix)）" ;;
    idle:*)    team_warn "  PM              未在跑（空提示符）；有待办时看门狗会拉起它（$TEAM_CLI up 手动）" ;;
    unknown:*) team_warn "  PM              窗口里不是 PM（${pm#unknown:}，cwd=$(team_pane_cwd "$(team_pm_target)" 2>/dev/null || echo '?')）：**不算存活**；$TEAM_CLI up 会替换它" ;;
    foreign:*) team_warn "  PM              窗口被**不属于本项目**的进程占用（cwd=$(team_pane_cwd "$(team_pm_target)" 2>/dev/null || echo '?')）：不覆盖" ;;
    *)         team_warn "  PM              窗口缺失（有待办时：$TEAM_CLI up，或设 TEAM_WATCH_REBUILD_TMUX=1）" ;;
  esac
  local pend; pend="$(team_pending_text)"
  printf '  待办             %s\n' "${pend:-无（不叫醒 PM）}"
  printf '  %s\n' "$(team_capacity_line)"
  printf '\n  职责：定时看看有没有活儿 + 容量留痕；不管 tmux 布局、不管 agent（agent 归 PM 管）\n'
  if team_in_standby; then
    printf '  待命             on（原因：%s）—— 不叫醒 PM；累积的待办仍记在 watchdog.log\n' "$(team_standby_reason || echo -)"
  fi
  return 0
}

team_cmd_standby() {
  local action="status" reason="-"
  while [ $# -gt 0 ]; do
    case "$1" in
      on|off|status) action="$1"; shift ;;
      --reason) reason="${2:?}"; shift 2 ;;
      -*) team_usage_die "standby: 未知参数 $1" ;;
      *) team_usage_die "standby: 多余参数 $1" ;;
    esac
  done
  case "$action" in
    on)
      team_standby_on "$reason"
      team_wlog "standby on（原因：$reason）"
      team_ok "已进入待命：watchdog 不会再叫醒 PM（原因：$reason）"
      team_dim "  待办不会丢：积压会记进 ${TEAM_STATE_DIR#"$TEAM_MAIN_ROOT"/}/watchdog.log；恢复用 $TEAM_CLI standby off"
      ;;
    off)
      team_standby_off
      team_wlog "standby off"
      team_ok "已退出待命：下个巡检周期起，有待办就会叫醒/拉起 PM"
      ;;
    *)
      if team_in_standby; then
        local since; since="$(awk '{print $1}' "$(team_standby_file)" 2>/dev/null)"
        printf 'standby: on（自 %s，原因：%s）\n' "${since:--}" "$(team_standby_reason || echo -)"
      else
        printf 'standby: off\n'
      fi
      local pend; pend="$(team_pending_text)"
      printf '待办：%s\n' "${pend:-无}"
      ;;
  esac
  return 0
}
