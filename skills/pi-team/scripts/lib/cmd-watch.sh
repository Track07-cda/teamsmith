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
  team_hdr "pi-team up · $TEAM_PROJECT（只负责 PM）"

  # 1) tmux 场地：人跑 up 就是明确要求“把工地建起来”，所以这里允许建 session/窗口
  if ! team_tmux_has_session "$TEAM_SESSION"; then
    team_warn "tmux session '$TEAM_SESSION' 不存在：重建"
    team_tmux_ensure_session
    tmux set-option -t "$TEAM_SESSION" destroy-unattached off >/dev/null 2>&1 || true
  fi
  if ! team_pm_window_exists; then
    tmux new-window -t "$TEAM_SESSION" -n "$TEAM_PM_WINDOW" -d >/dev/null 2>&1 || true
    team_ok "创建 PM 窗口 $TEAM_SESSION:$TEAM_PM_WINDOW"
  fi

  # 2) PM 进程
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
      team_wlog "无待办：不叫醒 PM"
      if ! team_pm_alive; then team_dim "无待办，PM 未在跑：不启动（有活出现时再叫醒）"; fi
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
  local st; st="$(team_pm_state)"
  case "$st" in
    idle:*) ;;
    *)
      if [ "${TEAM_WATCH_REBUILD_TMUX:-0}" = "1" ]; then
        if ! team_tmux_has_session "$TEAM_SESSION"; then
          team_wlog "tmux session 丢失，重建（TEAM_WATCH_REBUILD_TMUX=1）"
          team_tmux_ensure_session
          tmux set-option -t "$TEAM_SESSION" destroy-unattached off >/dev/null 2>&1 || true
        fi
        if ! team_pm_window_exists; then
          team_wlog "PM 窗口丢失，重建（TEAM_WATCH_REBUILD_TMUX=1）"
          tmux new-window -t "$TEAM_SESSION" -n "$TEAM_PM_WINDOW" -d >/dev/null 2>&1 || true
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
  team_dim "  只做两件事：记录容量趋势 ｜ PM 没在跑就在它的窗口里把 pi 拉起来"
  team_dim "  不管 tmux 布局，不管 agent（agent 归 PM 管：team resume）"
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
  printf '  巡检周期         %ss（建议 300~3600；不是心跳保活，是定时看看有没有活儿）\n' "${TEAM_WATCH_INTERVAL:-900}"
  printf '  tmux 重建         %s\n' "$([ "${TEAM_WATCH_REBUILD_TMUX:-0}" = "1" ] && echo '允许（TEAM_WATCH_REBUILD_TMUX=1）' || echo '不接管（session/窗口没了只告警）')"
  if team_in_standby; then
    team_warn "  待命             on（PM 主动停工，原因：$(team_standby_reason || echo -)；$TEAM_CLI standby off 恢复）"
  else
    team_dim "  待命             off"
  fi
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
  if [ -f "$TEAM_STATE_DIR/nudges.log" ]; then
    team_dim "  最近一次提醒     $(tail -1 "$TEAM_STATE_DIR/nudges.log" | cut -d' ' -f1-2)"
  else
    team_dim "  最近一次提醒     无"
  fi
  local pm; pm="$(team_pm_state)"
  case "$pm" in
    running:*) team_ok "  PM              在运行（${pm#running:}）" ;;
    busy:*)    team_ok "  PM              窗口有进程在跑（${pm#busy:}，视为存活）" ;;
    idle:*)    team_warn "  PM              未在跑（空提示符）→ team up" ;;
    *)         team_warn "  PM              窗口缺失 → team up" ;;
  esac
  printf '  %s\n' "$(team_capacity_line)"
  local pend; pend="$(team_pending_text)"
  printf '  待办             %s\n' "${pend:-无（不叫醒 PM）}"
  printf '\n  职责：定时看看有没有活儿 + 容量留痕；不管 tmux 布局、不管 agent（agent 归 PM 管）\n'
  printf '\n  最近 8 条巡检日志：\n'
  [ -f "$(team_watch_log)" ] && tail -8 "$(team_watch_log)" | sed 's/^/    /' || team_dim "    （无）"
  return 0
}

# ---------------------------------------------------------------- team standby
# PM（或用户）主动停工："确实没活可推" 或 "需要人工介入" 时调它，watchdog 就不再叫醒。
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
