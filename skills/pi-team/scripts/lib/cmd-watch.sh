#!/usr/bin/env bash
# pi-team · PM 相关：up（恢复 PM）/ resume（PM 工具）/ watch（前台巡检）/ watchdog（容器管理）/ standby（PM 停工）
#
# 设计前提：**不依赖任何 agent（包括 PM）来负责恢复**。
#   - PM 没在跑且有待办 → watchdog 用 pi -c 把它拉起来（历史不丢）
#   - agent 停了 → 不管（agent 归 PM 管：team resume）
#   - watchdog 自己挂了 → podman 容器（--restart=always）拉起它；机器重启后同样
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
  team_hdr "pi-team up · $TEAM_PROJECT（只负责 PM）"

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
    busy:*)    team_ok "PM 窗口有进程在跑（${pm_state#busy:}，视为存活；不重复启动）" ;;
    idle:*)    team_warn "PM 没在跑（空提示符）：启动 pi"
               if team_pm_start; then
                 team_ok "PM 已启动（model=${TEAM_PM_MODEL:-$TEAM_DEFAULT_MODEL}，$([ -n "$TEAM_PM_SESSION_ID" ] && echo "--session-id $TEAM_PM_SESSION_ID" || echo "-c 延续上一会话")）"
               else
                 team_err "PM 启动失败：请手动到 $TEAM_SESSION:$TEAM_PM_WINDOW 里跑 pi"
               fi ;;
    foreign:*)
               local _cwd; _cwd="$(team_pane_cwd "$(team_pm_target)" 2>/dev/null || echo '?')"
               if [ "${TEAM_REPLACE_FOREIGN_PM:-0}" = "1" ]; then
                 team_warn "PM 窗口被外来进程占用（cwd=$_cwd）：按 TEAM_REPLACE_FOREIGN_PM=1 覆盖"
                 if team_pm_start; then
                   team_ok "PM 已启动（覆盖了外来进程）"
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
  local st; st="$(team_pm_state)"
  case "$st" in
    idle:*) ;;
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
  team_hdr "pi-team watchdog · $TEAM_PROJECT（每 ${interval}s 一次；Ctrl-C 退出）"
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
  local runner; runner="$(team_ts_runner)"
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
  "$runner" "$js" --root "$TEAM_MAIN_ROOT" --only "$only" --events "${TEAM_MONITOR_EVENTS:-4}" 2>/dev/null || true
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
    printf '%spi-team monitor · %s%s  %s  %s(每 %ss 刷新%s)%s\n' \
      "$C_BOLD" "$TEAM_PROJECT" "$C_RESET" "$(team_timestamp)" "$C_DIM" "$interval" \
      "$([ "$with_watchdog" = 1 ] && echo "，每 ${TEAM_WATCH_INTERVAL:-900}s 跑一次巡检" || echo '')" "$C_RESET"
    team_panel | tail -n +2
    if [ "$activity" = "1" ]; then
      printf '\n  %sagent 活动%s%s（仅本 session 在跑的窗口；--no-activity 关掉）%s\n' \
        "$C_BOLD" "$C_RESET" "$C_DIM" "$C_RESET"
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

# ---------------------------------------------------------------- watchdog 后端：tmux（默认）/ 容器（可选）
# 由 PM（或人）用 `team watchdog up` 启动：一个 podman 容器常驻跑 `team watch`。
# 与 PM 的 pi 进程/会话解耦——PM 崩了、会话重启了，看门狗都还在。
# 两个关键点：
#   1) 容器必须能“看见” PM 窗口里的进程（存活判定要用 ps）：
#        在容器里（distrobox 等）→ --pid=container:<当前容器名> --cgroups=enabled
#        裸机                    → --pid=host
#   2) tmux socket 目录与项目目录按**相同绝对路径**挂进容器，脚本才照常工作。

team_podman() { # 容器内通过 distrobox-host-exec 回到宿主的 podman
  if team_have_cmd podman; then
    command podman "$@"
  elif team_have_cmd distrobox-host-exec; then
    distrobox-host-exec podman "$@"
  else
    team_die "找不到 podman（容器内需 distrobox-host-exec podman；裸机需装 podman）"
  fi
}

team_podman_ok() { team_have_cmd podman || team_have_cmd distrobox-host-exec; }

team_watch_box_name() { # 目标容器名：TEAM_WATCH_BOX 覆盖 > 当前容器（distrobox 写 /run/.containerenv）
  if [ -n "${TEAM_WATCH_BOX:-}" ]; then printf '%s\n' "$TEAM_WATCH_BOX"; return 0; fi
  local f=/run/.containerenv n
  [ -r "$f" ] || return 1
  n="$(sed -n 's/^name="\(.*\)"$/\1/p' "$f" | head -1)"
  [ -n "$n" ] || return 1
  printf '%s\n' "$n"
}

team_watch_pid_mode() { # container:<box> | host
  if [ -n "${TEAM_WATCH_PID_MODE:-}" ]; then printf '%s\n' "$TEAM_WATCH_PID_MODE"; return 0; fi
  local box; box="$(team_watch_box_name || true)"
  if [ -n "$box" ]; then printf 'container:%s\n' "$box"; else printf 'host\n'; fi
}

team_watch_container_name() {
  printf '%s\n' "${TEAM_WATCH_CONTAINER:-$(team_slug "$TEAM_PROJECT")-pi-team-watch}"
}

team_watch_image() {
  if [ -n "${TEAM_WATCH_IMAGE:-}" ]; then printf '%s\n' "$TEAM_WATCH_IMAGE"; return 0; fi
  # 默认镜像 tag 跟着 Containerfile 内容走：改了就自动重建，不会用到过期的旧镜像
  local cf="$TEAM_SKILL_DIR/container/Containerfile" tag="base"
  [ -f "$cf" ] && tag="$(team_hash "$(cat "$cf")")"
  printf 'localhost/pi-team-watch:%s\n' "$tag"
}

team_watch_container_state() { # running|exited|absent
  local cname="$1" st
  st="$(team_podman inspect "$cname" --format '{{.State.Status}}' 2>/dev/null | head -1)"
  if [ -n "$st" ]; then printf '%s\n' "$st"; else printf 'absent\n'; fi
}

team_tmux_sock_dir() {
  if [ -n "${TMUX_TMPDIR:-}" ]; then printf '%s/tmux-%s\n' "${TMUX_TMPDIR%/}" "$(id -u)"
  else printf '/tmp/tmux-%s\n' "$(id -u)"; fi
}

team_watch_ensure_image() {
  local img; img="$(team_watch_image)"
  if team_podman image exists "$img" >/dev/null 2>&1; then return 0; fi
  local ctx="$TEAM_SKILL_DIR/container"
  [ -f "$ctx/Containerfile" ] || team_die "镜像 $img 不存在，且缺 $ctx/Containerfile（可设 TEAM_WATCH_IMAGE 用现成镜像）"
  team_info "构建看门狗镜像 $img（首次需要网络）" >&2
  team_podman build -t "$img" "$ctx" >&2 || team_die "镜像构建失败"
}

team_host_podman_sock() { # 宿主 podman 的 socket 路径（问宿主 podman 自己 —— 容器里看不见宿主的 /run/user）
  local p
  p="$(team_podman info --format '{{.Host.RemoteSocket.Path}}' 2>/dev/null | head -1)"
  if [ -n "$p" ]; then printf '%s\n' "$p"; return 0; fi
  return 1
}

team_watch_build_args() { # 构造 podman run 参数数组 TEAM_WD_ARGS（两种形态见 Containerfile 顶部注释）
  local box sock proj img cname inner
  box="$(team_watch_box_name || true)"
  proj="$TEAM_MAIN_ROOT"
  img="$(team_watch_image)"
  cname="$(team_watch_container_name)"
  TEAM_WD_ARGS=(run --detach --name "$cname" --restart=always)
  if [ -n "$box" ]; then
    # 形态 A：容器只守着，真正的 watch 在开发容器里跑（tmux/ps/pi 都在那儿，版本一致）
    # 以项目属主身份进去（否则 git 会因 dubious ownership 拒绝），并带上 HOME 让 git 配置可用
    local proj_uid proj_home
    proj_uid="$(stat -c %u "$proj" 2>/dev/null || id -u)"
    proj_home="${HOME:-/root}"
    inner="while :; do podman-remote exec --user $proj_uid -e HOME=$proj_home -w $proj -e TEAM_ROOT=$proj $box bash $TEAM_SKILL_DIR/scripts/team watch; rc=\$?; echo \"[watchdog] inner watch 退出（rc=\$rc），${TEAM_WATCH_RETRY_SEC:-15}s 后重试\"; sleep ${TEAM_WATCH_RETRY_SEC:-15}; done"
    sock="$(team_host_podman_sock || true)"
    if [ -n "$sock" ]; then
      TEAM_WD_ARGS+=(--env "CONTAINER_HOST=unix://$sock" --volume "$sock:$sock")
    else
      team_warn "问不到宿主 podman socket：容器里的看门狗可能连不上 podman（可手动设 CONTAINER_HOST）"
    fi
    TEAM_WD_ARGS+=(--env "TEAM_WATCH_BOX=$box")
  else
    # 形态 B：裸机，直接在容器里跑 watch
    inner="exec bash $TEAM_SKILL_DIR/scripts/team watch"
    TEAM_WD_ARGS+=(--pid=host)
    local tmsock; tmsock="$(team_tmux_sock_dir)"
    [ -d "$tmsock" ] && TEAM_WD_ARGS+=(--volume "$tmsock:$tmsock")
    TEAM_WD_ARGS+=(-w "$proj" --env "TEAM_ROOT=$proj" --volume "$proj:$proj")
  fi
  TEAM_WD_ARGS+=(--volume "$TEAM_SKILL_DIR:$TEAM_SKILL_DIR:ro")
  TEAM_WD_ARGS+=(--entrypoint /bin/bash "$img" -c "$inner")
  TEAM_WD_BOX="$box"
  return 0
}

team_watch_run_cmd() { # 人类可读（--print 也用它）
  team_watch_build_args
  local a out="podman"
  for a in "${TEAM_WD_ARGS[@]}"; do out="$out $(printf '%q' "$a")"; done
  printf '%s\n' "$out"
}

# 统一的后端无关存活判定（ps / digest / doctor / watchdog status 都用它）
# 输出 "tmux:<session>:<window>" | "fg:<pid>" | "container:<name>" | "off"
team_watchdog_state() {
  local backend="${TEAM_WATCH_BACKEND:-tmux}" w st
  if [ "$backend" = "tmux" ]; then
    w="$(team_watch_window)"
    st="$(team_watch_window_state)"
    case "$st" in
      running) printf 'tmux:%s:%s\n' "$TEAM_SESSION" "$w"; return 0 ;;
    esac
  fi
  if team_watch_pid_alive; then printf 'fg:%s\n' "$(cat "$TEAM_STATE_DIR/watchdog.pid")"; return 0; fi
  if team_podman_ok; then
    case "$(team_watch_container_state "$(team_watch_container_name)")" in
      running) printf 'container:%s\n' "$(team_watch_container_name)"; return 0 ;;
    esac
  fi
  # 后端与预期不符时，只要任一形态在跑就算在跑（避免误报“未创建”）
  w="$(team_watch_window)"
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
    container:*) printf '● 容器 %s 在跑' "${st#container:}" ;;
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
  team_require_cmd tmux "tmux 后端需要 tmux（容器后端：team watchdog up --container）"
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
  local sub="status" print_only=0 no_build=0 cname st cmd
  local backend="${TEAM_WATCH_BACKEND:-tmux}"
  while [ $# -gt 0 ]; do
    case "$1" in
      up|down|restart|status|logs) sub="$1"; shift ;;
      --print) print_only=1; shift ;;
      --no-build) no_build=1; shift ;;
      --tmux) backend=tmux; shift ;;
      --container) backend=container; shift ;;
      -*) team_usage_die "watchdog: 未知参数 $1" ;;
      *) team_usage_die "watchdog: 多余参数 $1" ;;
    esac
  done
  team_require_docs

  if [ "$backend" = "tmux" ]; then
    case "$sub" in
      up)      team_watch_tmux_up ;;
      down)    team_watch_tmux_down ;;
      restart) team_watch_tmux_down >/dev/null 2>&1 || true; team_watch_tmux_up ;;
      logs)    team_watch_tmux_logs ;;
      status)  team_cmd_watchdog_status ;;
    esac
    return $?
  fi

  case "$sub" in
  up)
    if [ "$print_only" = "1" ]; then
      team_watch_run_cmd
      return 0
    fi
    team_podman_ok || team_die "没有 podman：容器内需 distrobox-host-exec podman；裸机请装 podman"
    cname="$(team_watch_container_name)"
    st="$(team_watch_container_state "$cname")"
    if [ "$st" = "running" ]; then team_ok "看门狗容器已在跑：$cname"; return 0; fi
    [ "$no_build" = "1" ] || team_watch_ensure_image
    if [ "$st" != "absent" ]; then
      team_warn "已有同名的停止容器：删除并按当前配置重建（$cname）"
      team_podman rm -f "$cname" >/dev/null 2>&1 || true
    fi
    cmd="$(team_watch_run_cmd)"
    team_watch_build_args
    if team_podman "${TEAM_WD_ARGS[@]}" >/dev/null 2>&1; then
      sleep 1
      st="$(team_watch_container_state "$cname")"
      if [ "$st" = "running" ]; then
        team_ok "看门狗容器已启动：$cname${TEAM_WD_BOX:+（守着 $TEAM_WD_BOX 里的 watch，每 ${TEAM_WATCH_INTERVAL:-900}s 一次）}（日志：$TEAM_CLI watchdog logs）"
      else
        team_err "容器没跑起来（状态 $st）：$TEAM_CLI watchdog logs 看原因"
        return 1
      fi
    else
      team_err "podman run 失败：podman $cmd"
      return 1
    fi
    ;;
  down)
    team_podman_ok || team_die "没有 podman"
    cname="$(team_watch_container_name)"
    if team_podman rm -f "$cname" >/dev/null 2>&1; then team_ok "已停并删除看门狗容器：$cname"
    else team_dim "没有在跑的看门狗容器（$cname）"; fi
    ;;
  restart)
    team_cmd_watchdog down >/dev/null 2>&1 || true
    team_cmd_watchdog up
    ;;
  logs)
    team_podman_ok || team_die "没有 podman"
    team_podman logs --tail 50 --follow "$(team_watch_container_name)"
    ;;
  status)
    team_cmd_watchdog_status
    ;;
  esac
  return 0
}

# 兼容旧名字：install/uninstall-watchdog 现在是 watchdog up/down 的别名
team_cmd_install_watchdog() { team_cmd_watchdog up "$@"; }
team_cmd_uninstall_watchdog() { team_cmd_watchdog down "$@"; }

team_cmd_watchdog_status() {
  team_hdr "pi-team watchdog · $TEAM_PROJECT"
  local backend="${TEAM_WATCH_BACKEND:-tmux}" cname st img
  if [ "$backend" = "tmux" ]; then
    local w tst; w="$(team_watch_window)"; tst="$(team_watch_window_state)"
    case "$tst" in
      running) team_ok "  看门狗           tmux 窗口 $TEAM_SESSION:$w 在跑（--ui 面板）" ;;
      idle)    team_warn "  看门狗           窗口 $w 停在空提示符 → $TEAM_CLI watchdog up" ;;
      *)       team_dim "  看门狗           未起 → $TEAM_CLI watchdog up（也可 --container）" ;;
    esac
    printf '  后端             tmux（同 session 的窗口；容器后端：watchdog up --container）\n'
    printf '  日志             %s watchdog logs ／ tmux attach -t %s\n' "$TEAM_CLI" "$TEAM_SESSION"
  fi
  cname="$(team_watch_container_name)"
  st="$(team_watch_container_state "$cname")"
  if [ "$backend" = "container" ]; then
    case "$st" in
      running)     team_ok "  容器             running（$cname）" ;;
      absent)      team_dim "  容器             未创建 → $TEAM_CLI watchdog up" ;;
      *)           team_warn "  容器             $st（$cname）→ $TEAM_CLI watchdog up" ;;
    esac
  fi
  img="$(team_watch_image)"
  printf '  镜像             %s%s\n' "$img" "$(team_podman_ok && echo '' || echo '（本机没 podman）')"
  local box; box="$(team_watch_box_name || true)"
  if [ -n "$box" ]; then
    printf '  运行形态         容器守着（容器内 podman-remote exec %s 跑 watch）\n' "$box"
  else
    printf '  运行形态         容器内直跑（--pid=host，需镜像里的 tmux 与宿主协议兼容）\n'
  fi
  printf '  巡检周期         %ss（建议 300~3600；不是心跳保活，是定时看看有没有活儿）\n' "${TEAM_WATCH_INTERVAL:-900}"
  printf '  tmux 重建         %s\n' "$([ "${TEAM_WATCH_REBUILD_TMUX:-0}" = "1" ] && echo '允许（TEAM_WATCH_REBUILD_TMUX=1）' || echo '不接管（session/窗口没了只告警）')"
  if team_in_standby; then
    team_warn "  待命             on（PM 主动停工，原因：$(team_standby_reason || echo -)；$TEAM_CLI standby off 恢复）"
  else
    team_dim "  待命             off"
  fi
  local last="$TEAM_STATE_DIR/watchdog.last"
  if [ -f "$last" ]; then
    team_dim "  最近一次巡检     $(cat "$last" | awk '{print $2, $3}')"
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
    idle:*)    team_warn "  PM              未在跑（空提示符）；有待办时看门狗会拉起它（$TEAM_CLI up 手动）" ;;
    *)         team_warn "  PM              窗口缺失（有待办时：$TEAM_CLI up，或设 TEAM_WATCH_REBUILD_TMUX=1）" ;;
  esac
  local pend; pend="$(team_pending_text)"
  printf '  待办             %s\n' "${pend:-无（不叫醒 PM）}"
  printf '  %s\n' "$(team_capacity_line)"
  printf '\n  职责：定时看看有没有活儿 + 容量留痕；不管 tmux 布局、不管 agent（agent 归 PM 管）\n'
  if [ "$st" = "running" ]; then
    printf '\n  容器最近输出：\n'
    team_podman logs --tail 5 "$cname" 2>/dev/null | sed 's/^/    /' || team_dim "    （无）"
  fi
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
