#!/usr/bin/env bash
# pi-team · 保活与恢复：up / resume / watch（watchdog）/ install-watchdog / uninstall-watchdog / watchdog-status
#
# 设计前提：**不依赖任何 agent（包括 PM）来负责恢复**。
#   - PM 挂了 → watchdog 把 PM 拉起来（用 pi -c 延续原会话，历史不丢）
#   - agent 挂了 → watchdog 按 state 里记的任务/任务书重新派单（断点续跑）
#   - watchdog 自己也挂了 → 交给 systemd --user（或用户自己 cron/tmux）重启 watchdog
#   - 机器重启 → 同上：systemd 拉起 watchdog，watchdog 拉起 PM 与 agent
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
    team_err "watchdog 已在运行（pid $(cat "$TEAM_STATE_DIR/watchdog.pid")）；停止它：team watchdog-status 看详情，kill 掉即可"
    return 1
  fi
  mkdir -p "$TEAM_STATE_DIR"
  printf '%s\n' "$$" > "$TEAM_STATE_DIR/watchdog.pid"
  return 0
}

team_watch_unlock() { rm -f "$TEAM_STATE_DIR/watchdog.pid"; }

# ---------------------------------------------------------------- team up
team_cmd_up() {
  local no_agents=0 yes=0 show_prompt=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --no-agents) no_agents=1; shift ;;
      --yes|-y) yes=1; shift ;;
      --print) show_prompt=1; shift ;;
      -*) team_usage_die "up: 未知参数 $1" ;;
      *) team_usage_die "up: 多余参数 $1" ;;
    esac
  done
  [ "$yes" = "1" ] && TEAM_ASSUME_YES=1

  if [ "$show_prompt" = "1" ]; then team_pm_prompt; return 0; fi

  team_require_docs
  team_require_cmd tmux "team up 需要 tmux（PM 与 agent 都跑在窗口里）"
  team_hdr "pi-team up · $TEAM_PROJECT"

  # 1) session（tmux server 挂了就重建；重建后所有窗口都要重新拉起）
  local rebuilt=0
  if ! team_tmux_has_session "$TEAM_SESSION"; then
    team_warn "tmux session '$TEAM_SESSION' 不存在：重建（原窗口里的进程已被杀掉）"
    team_tmux_ensure_session
    rebuilt=1
  fi
  tmux set-option -t "$TEAM_SESSION" destroy-unattached off >/dev/null 2>&1 || true

  # 2) PM 窗口 + PM 进程
  if ! team_pm_window_exists; then
    tmux new-window -t "$TEAM_SESSION" -n "$TEAM_PM_WINDOW" -d >/dev/null 2>&1 || true
    team_ok "创建 PM 窗口 $TEAM_SESSION:$TEAM_PM_WINDOW"
  fi
  local pm_state; pm_state="$(team_pm_state)"
  case "$pm_state" in
    running:*) team_ok "PM 在运行（${pm_state#running:}）" ;;
    busy:*)    team_ok "PM 窗口有进程在跑（${pm_state#busy:}，视为存活；不重复启动）" ;;
    idle:*)    team_warn "PM 没在跑（空提示符）：启动 pi"
               if team_pm_start; then
                 team_ok "PM 已启动（model=${TEAM_PM_MODEL:-$TEAM_DEFAULT_MODEL}，$([ -n "$TEAM_PM_SESSION_ID" ] && echo "--session-id $TEAM_PM_SESSION_ID" || echo "-c 延续上一会话")）"
               else
                 team_err "PM 启动失败：请手动到 $TEAM_SESSION:$TEAM_PM_WINDOW 里跑 pi"
               fi ;;
    *)         team_warn "PM 窗口状态异常（$pm_state）：不抢窗口" ;;
  esac

  # 3) agent 恢复
  if [ "$no_agents" != "1" ]; then
    team_info ""
    team_cmd_resume --quiet
  fi

  team_info ""
  team_capacity_line
  team_dim "  旁观：tmux attach -t $TEAM_SESSION ｜ 待办：$TEAM_CLI digest"
  return 0
}

# ---------------------------------------------------------------- team resume
team_cmd_resume() {
  local only="" all=1 dry=0 quiet=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --agent) only="${2:?}"; all=0; shift 2 ;;
      --all) all=1; shift ;;
      --dry-run) dry=1; shift ;;
      --quiet) quiet=1; shift ;;
      -*) team_usage_die "resume: 未知参数 $1" ;;
      *) team_usage_die "resume: 多余参数 $1" ;;
    esac
  done
  team_require_docs
  [ -n "$only" ] && team_require_agent "$only"

  local a task taskfile live=0 n=0
  [ "$quiet" != "1" ] && team_hdr "pi-team resume · $TEAM_PROJECT"
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
        # 容量/并发守卫拦下：这是正常排队，不是错误
        team_warn "$a 续跑被守卫拦下（容量/并发），下一轮再试"
      fi
    fi
  done
  if [ "$n" -eq 0 ]; then
    [ "$quiet" != "1" ] && team_dim "  没有需要续跑的 agent（在跑 $live 个）"
  fi
  return 0
}

# ---------------------------------------------------------------- team watch
team_watch_once() {
  mkdir -p "$TEAM_STATE_DIR"
  local actions=0

  # 容量趋势（PM 事后可看 state/capacity.log 复盘）
  local cap; cap="$(team_capacity_line)"
  printf '%s %s\n' "$(team_timestamp)" "$cap" >> "$TEAM_STATE_DIR/capacity.log"
  if [ "$(wc -l < "$TEAM_STATE_DIR/capacity.log")" -gt 500 ]; then
    tail -n 500 "$TEAM_STATE_DIR/capacity.log" > "$TEAM_STATE_DIR/capacity.log.tmp" && \
      mv "$TEAM_STATE_DIR/capacity.log.tmp" "$TEAM_STATE_DIR/capacity.log"
  fi

  # tmux server 挂了：重建 session（原进程都没了，随后的步骤会把它们拉起来）
  if ! team_tmux_has_session "$TEAM_SESSION"; then
    team_wlog "tmux session 丢失，重建"
    team_tmux_ensure_session
    tmux set-option -t "$TEAM_SESSION" destroy-unattached off >/dev/null 2>&1 || true
  fi

  # PM 保活
  if [ "${TEAM_WATCH_PM:-1}" = "1" ]; then
    if ! team_pm_alive; then
      local st; st="$(team_pm_state)"
      case "$st" in
        idle:*|missing)
          if team_pm_can_restart; then
            if ! team_pm_window_exists; then tmux new-window -t "$TEAM_SESSION" -n "$TEAM_PM_WINDOW" -d >/dev/null 2>&1 || true; fi
            if team_pm_start; then
              team_wlog "PM 未在运行（$st）→ 已重启"
              team_ok "watchdog: PM 未在运行（$st）→ 已重启（pi -c，开场提示词在 state/pm-prompt.md）"
              team_inbox_append pm watchdog "PM 会话曾停止（状态 $st），watchdog 已用 pi -c 重启并注入开场提示词（state/pm-prompt.md）；先跑 team digest 与 team inbox --ack 恢复上下文"
              actions=$((actions + 1))
            else
              team_wlog "PM 重启失败（$st）"
              team_warn "watchdog: PM 重启失败（$st）"
            fi
          else
            team_wlog "PM 重启被配额拦下（$st）"
          fi ;;
        busy:*) team_wlog "PM 窗口有进程在跑（$st）：不动它" ;;
        *)      team_wlog "PM 窗口状态异常（$st）：不重启" ;;
      esac    fi
  fi

  # agent 续跑
  if [ "${TEAM_WATCH_RESUME:-1}" = "1" ]; then
    local before="$actions"
    team_cmd_resume --quiet
    actions=$((actions + 1))
    [ "$before" = "$actions" ] || team_wlog "resume 完成"
  fi

  printf '%s %s\n' "$(date +%s)" "$(team_timestamp)" > "$TEAM_STATE_DIR/watchdog.last"
  return 0
}

team_cmd_watch() {
  local once=0 interval="${TEAM_WATCH_INTERVAL:-60}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --once) once=1; shift ;;
      --interval) interval="${2:?}"; shift 2 ;;
      -*) team_usage_die "watch: 未知参数 $1" ;;
      *) team_usage_die "watch: 多余参数 $1" ;;
    esac
  done
  team_require_docs

  if [ "$once" = "1" ]; then
    team_watch_once
    team_ok "watch --once 完成（日志：${TEAM_STATE_DIR#"$TEAM_MAIN_ROOT"/}/watchdog.log）"
    return 0
  fi

  team_require_cmd tmux "watchdog 需要 tmux 来拉起 PM/agent"
  team_watch_lock || return 1
  trap 'team_watch_unlock' EXIT INT TERM
  team_hdr "pi-team watchdog · $TEAM_PROJECT（每 ${interval}s 一次；Ctrl-C 退出）"
  team_dim "  会做：记录容量 ｜ PM 没了就拉起 ｜ 有任务但窗口没了的 agent 续跑"
  while :; do
    team_watch_once
    sleep "$interval"
  done
}

# ---------------------------------------------------------------- systemd --user
team_watch_service_name() {
  printf '%s\n' "${TEAM_WATCH_SERVICE:-$(team_slug "$TEAM_PROJECT")-pi-team-watch}"
}

team_watch_unit_dir() { printf '%s\n' "$HOME/.config/systemd/user"; }

team_watch_unit_file() { printf '%s\n' "$(team_watch_unit_dir)/$(team_watch_service_name).service"; }

team_watch_systemd_ok() {
  team_have_cmd systemctl || return 1
  if systemctl --user is-system-running >/dev/null 2>&1; then return 0; fi
  return 1
}

team_cmd_install_watchdog() {
  local interval="${TEAM_WATCH_INTERVAL:-60}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --interval) interval="${2:?}"; shift 2 ;;
      --yes|-y) TEAM_ASSUME_YES=1; shift ;;
      *) team_usage_die "install-watchdog: 未知参数 $1" ;;
    esac
  done
  team_require_docs
  team_allow_write || return 1   # 改用户级 systemd 状态：需要显式授权

  if ! team_watch_systemd_ok; then
    team_err "systemd --user 不可用。替代方案（任选其一）："
    printf '  1) 在 tmux 里跑一个窗口：tmux new-window -n watchdog -d -- %s %s watch\n' "$TEAM_SKILL_DIR/scripts/team" "$TEAM_PROJECT"
    printf '  2) 自己写 cron：*/5 * * * * cd %s && %s watch --once\n' "$TEAM_MAIN_ROOT" "$TEAM_SKILL_DIR/scripts/team"
    printf '  3) 机器重启后手动跑一次：cd %s && %s up\n' "$TEAM_MAIN_ROOT" "$TEAM_SKILL_DIR/scripts/team"
    return 1
  fi

  mkdir -p "$(team_watch_unit_dir)"
  local unit; unit="$(team_watch_unit_file)"
  cat > "$unit" <<EOF
[Unit]
Description=pi-team watchdog for $TEAM_PROJECT
After=default.target

[Service]
Type=simple
WorkingDirectory=$TEAM_MAIN_ROOT
# 用 /usr/bin/env bash 明确解释器：脚本没 +x 也能跑（不要把权限当单点故障）
ExecStart=/usr/bin/env bash $TEAM_SKILL_DIR/scripts/team watch --interval $interval
Restart=always
RestartSec=30
# 让 watchdog 能碰到 tmux（同一个 user runtime）
Environment=TEAM_ROOT=$TEAM_MAIN_ROOT
Environment=PATH=$PATH

[Install]
WantedBy=default.target
EOF
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  if systemctl --user enable --now "$(team_watch_service_name).service" >/dev/null 2>&1; then
    team_ok "已安装并启动：$(team_watch_service_name).service（unit: $unit）"
    team_dim "  查看：systemctl --user status $(team_watch_service_name) ｜ 日志：journalctl --user -u $(team_watch_service_name) -f"
    team_dim "  需要 ssh 登录后也能跑：loginctl enable-linger $USER"
  else
    team_err "systemctl --user enable 失败；unit 已写好：$unit（可手动 systemctl --user enable --now $(team_watch_service_name)）"
    return 1
  fi
}

team_cmd_uninstall_watchdog() {
  local purge=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --purge) purge=1; shift ;;
      --yes|-y) TEAM_ASSUME_YES=1; shift ;;
      *) team_usage_die "uninstall-watchdog: 未知参数 $1" ;;
    esac
  done
  team_allow_write || return 1
  local svc; svc="$(team_watch_service_name)"
  if team_watch_systemd_ok; then
    systemctl --user disable --now "$svc.service" >/dev/null 2>&1 && team_ok "已停止 $svc.service" || team_warn "$svc.service 未在运行"
  fi
    if [ "$purge" = "1" ]; then
      rm -f "$(team_watch_unit_file)" && team_ok "删除 unit 文件"
      if team_watch_systemd_ok; then systemctl --user daemon-reload >/dev/null 2>&1 || true; fi
    fi
  if team_watch_pid_alive; then
    local pid; pid="$(cat "$TEAM_STATE_DIR/watchdog.pid")"
    kill "$pid" 2>/dev/null && team_ok "停止前台 watchdog（pid $pid）" || true
  fi
  team_dim "  数据保留：${TEAM_STATE_DIR#"$TEAM_MAIN_ROOT"/}/watchdog.log、capacity.log"
}

team_cmd_watchdog_status() {
  team_hdr "pi-team watchdog · $TEAM_PROJECT"
  local svc; svc="$(team_watch_service_name)"
  printf '  service          %s\n' "$svc"
  if team_watch_systemd_ok; then
    if systemctl --user is-active "$svc.service" >/dev/null 2>&1; then
      team_ok "  systemd 状态     active（开机自启）"
    else
      team_dim "  systemd 状态     inactive（未安装：team install-watchdog --yes）"
    fi
  else
    team_dim "  systemd 状态     不可用（用 tmux 窗口或 cron 跑 team watch）"
  fi
  if team_watch_pid_alive; then team_ok "  前台 watchdog    pid $(cat "$TEAM_STATE_DIR/watchdog.pid")"
  else team_dim "  前台 watchdog    未运行"; fi
  local last="$TEAM_STATE_DIR/watchdog.last"
  if [ -f "$last" ]; then
    local ts; ts="$(cat "$last" | awk '{print $2, $3}')"
    team_dim "  最近一次巡检     $ts（日志：${TEAM_STATE_DIR#"$TEAM_MAIN_ROOT"/}/watchdog.log）"
  else
    team_dim "  最近一次巡检     从未"
  fi
  local pm; pm="$(team_pm_state)"
  case "$pm" in
    running:*) team_ok "  PM              在运行（${pm#running:}）" ;;
    busy:*)    team_ok "  PM              窗口有进程在跑（${pm#busy:}，视为存活）" ;;
    idle:*)    team_warn "  PM              未在跑（空提示符）→ team up" ;;
    *)         team_warn "  PM              窗口缺失 → team up" ;;
  esac
  printf '  %s\n' "$(team_capacity_line)"
  printf '\n  最近 8 条巡检日志：\n'
  [ -f "$(team_watch_log)" ] && tail -8 "$(team_watch_log)" | sed 's/^/    /' || team_dim "    （无）"
  return 0
}
