#!/usr/bin/env bash
# teamsmith · PM 相关：up（恢复 PM）/ resume（PM 工具）/ watch（前台巡检）/ pulse（巡检窗口）/ standby（PM 停工）
#
# 设计前提：**不依赖任何 agent（包括 PM）来负责恢复**。
#   - PM 没在跑且有待办 → pulse 用配置的 PM CLI 把它拉起来（Pi 默认 = -c，历史不丢；M8.1 起可用 TEAM_PM_CMD）
#   - agent 停了 → 不管（agent 归 PM 管：team resume）
#   - pulse 自己挂了 → 由 PM 手动 `team pulse up` 重建（**只有一个后端**：同 session 的 tmux 窗口；
#     不引入第二个运行时不代表没有恢复能力：PM 被叫醒后第一件事就是看 pulse status）
# 所有状态都在磁盘上（state/ + docs/ + git 分支），所以任何一环重启都是可续的。
# （v1.36.0 前命令组叫 `team watchdog`、窗口叫 `watchdog`：别名期旧名照用，印一行弃用提示。）

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

team_watch_lock() { # 防止两个 watchdog 打架（**自己持有**的锁不是冲突：代码漂移重启用 exec，PID 不变）
  local pid
  pid="$(cat "$TEAM_STATE_DIR/watchdog.pid" 2>/dev/null || true)"
  case "${pid:-}" in
    ''|*[!0-9]*) ;;
    "${BASHPID:-$$}"|"$$") ;;   # 上一版代码就是我们自己（exec 重启）：续用这把锁
    *) if kill -0 "$pid" 2>/dev/null; then
         team_err "巡检已在运行（pid $pid）；停止它：\`team pulse status\` 看详情，kill 掉即可"
         return 1
       fi ;;
  esac
  mkdir -p "$TEAM_STATE_DIR"
  printf '%s\n' "$$" > "$TEAM_STATE_DIR/watchdog.pid"
  return 0
}

team_watch_unlock() { rm -f "$TEAM_STATE_DIR/watchdog.pid"; }

# ---------------------------------------------------------------- 代码快照漂移（M9.8）
# 巡检进程是**长命的**：watchdog 窗口里的 `team monitor` 可以跑几天，而磁盘上的代码随时在更新
# （每次交付都在改 scripts/lib/**）。2026-09-15 的现场：窗口里的进程是前一天 14:12 起来的（v1.19.0），
# 它按旧规则算出「待复验 6」，而同一时刻新进程的 digest 清单是空的 —— 唤醒理由与 digest 分家，
# 根因不是规则写得不一样（早就是同一个函数了），而是**进程里的代码快照过期**。
# 纪律：判定「要不要叫醒 PM」必须用**磁盘上的代码**。所以每一圈先比一次指纹，变了就把自己 exec 成
# 新进程（exec 保留 PID、tmux pane 与 PM 会话，只有代码被换掉），理由写进 watchdog.log 与面板。
# 说明：指纹用文件清单（大小 + mtime + 名字）而不是版本号 —— 版本号靠人记得改，代码改了没升版就测不出来。
team_watch_lib_files() { # → "<大小> <mtime> <名字>" 每行一个（稳定排序；读不到 → 空）
  local d="$TEAM_SKILL_DIR/scripts/lib"
  [ -d "$d" ] || return 0
  ( cd "$d" && ls -l --time-style=+%s ./*.sh 2>/dev/null ) | awk '{print $5, $6, $7}' | sort
}

team_watch_code_fp() { # → 本进程加载的 lib 代码**内容**指纹（读不到 → "-"）
  # 内容而不是版本号：版本靠人记得改（改代码没升版就测不出漂移）；内容级也不漏「同一秒、同样大小的改动」。
  local d="$TEAM_SKILL_DIR/scripts/lib" fp
  [ -d "$d" ] || { printf -- '-\n'; return 0; }
  fp="$(cat "$d"/*.sh 2>/dev/null | cksum | awk '{print $1}')"
  if [ -n "$fp" ]; then printf '%s\n' "$fp"; else printf -- '-\n'; fi
}

team_watch_code_newest_mtime() { # → 磁盘上 lib 文件里最新的 mtime（读不到 → 空）
  team_watch_lib_files | awk '{ if ($2 + 0 > m) m = $2 + 0 } END { if (m > 0) print m }'
}

# <启动指纹> <子命令> [子命令参数…]：磁盘上的代码与本进程启动时不同 → 用新代码 exec 自己。
team_watch_reexec_if_stale() { # <启动指纹> <子命令> [子命令参数…]
  local fp0="${1:-}" cmd="${2:-}" fp
  [ -n "$cmd" ] || return 0
  shift 2
  fp="$(team_watch_code_fp)"
  case "${fp:-}" in ''|'-') return 0 ;; esac
  [ "$fp" = "$fp0" ] && return 0
  team_wlog "巡检进程的代码快照过期（本进程 v$TEAM_VERSION，$fp0 → 磁盘 $fp）→ 用磁盘上的代码重启本进程"
  team_warn "巡检进程的代码不是磁盘上的最新版（本进程 v$TEAM_VERSION）：用磁盘上的代码重启它，窗口与 PM 不受影响"
  exec bash "$TEAM_SKILL_DIR/scripts/team" "$cmd" "$@"
}

# 窗口里的巡检进程是什么时候起来的（watchdog-status 用它报「代码快照过旧」）。
team_watch_process_start_epoch() { # <tmux 目标> → 进程启动的 epoch 秒（判不出 → 空）
  local pid et
  pid="$(tmux display-message -p -t "$1" '#{pane_pid}' 2>/dev/null | head -1 || true)"
  case "${pid:-}" in ''|*[!0-9]*) return 0 ;; esac
  et="$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ' || true)"
  case "${et:-}" in ''|*[!0-9]*) return 0 ;; esac
  printf '%s\n' "$(( $(date +%s) - et ))"
}

team_watch_snapshot_line() { # <窗口进程启动 epoch|空> → 一行说明（空 = 判不出）
  local started="${1:-}" newest
  case "$started" in ''|*[!0-9]*) return 0 ;; esac
  newest="$(team_watch_code_newest_mtime)"
  case "$newest" in ''|*[!0-9]*) return 0 ;; esac
  if [ "$newest" -gt "$started" ]; then
    printf '★ 过旧：窗口里的巡检进程启动于 %ss 前，之后 scripts/lib 又更新过 → 唤醒理由可能比 digest 旧；跑 %s pulse restart\n' \
      "$(( $(date +%s) - started ))" "$TEAM_CLI"
  else
    printf '与磁盘上的 scripts/lib 一致（进程起来之后代码没变过）\n'
  fi
}

# ---------------------------------------------------------------- team up
# 人来跑的工具：把 PM 恢复起来。
# agent 归 PM 管，所以默认不动 agent；要顺手把停了的 agent 也续起来就加 --agents。
team_cmd_up() {
  local with_agents=0 show_prompt=0 pm_fail=0
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
    starting:*)
               # M7.2：启动在飞行中（另一支巡检/另一条 up 已经拉过它）——再 respawn 一次会杀掉正在起来的 PM
               team_warn "PM 正在启动（${pm_state#starting:}；证据：$(team_pm_evidence "$pm_state")）：不重复拉起"
               team_dim "  等它起来；若卡住：启动标记会过期（TEAM_PM_START_WAIT=${TEAM_PM_START_WAIT:-6}s + 5s），过期后再跑 $TEAM_CLI up；证据看 $TEAM_CLI pulse status" ;;
    idle:*)    team_warn "PM 没在跑（空提示符）：启动 $(team_pm_cli_name)"
               if team_pm_start; then
                 team_ok "PM 已启动（cli=$(team_pm_cli_name)，proof=$(team_pm_proof || echo '?')，model=${TEAM_PM_MODEL:-$TEAM_DEFAULT_MODEL}）"
               else
                 pm_fail=1
                 team_err "PM 启动失败：请手动到 $TEAM_SESSION:$TEAM_PM_WINDOW 里跑 $(team_pm_bin_path)；诊断见 $(team_pm_launch_failed_log)"
               fi ;;
    unknown:*)
               # 窗口里是本项目 cwd 的**非 PM** 进程（新建空窗的瞬态、sleep、编辑器…）：
               # 不是 PM 就不能压制恢复（M6.5 就是「空窗被当成 PM，up 什么也不干还说成功」）
               local _ucwd; _ucwd="$(team_pane_cwd "$(team_pm_target)" 2>/dev/null || echo '?')"
               team_warn "PM 窗口里有非 PM 进程（${pm_state#unknown:}，cwd=$_ucwd）：不算存活"
               if team_pm_start; then
                 team_ok "PM 已启动（替换了非 PM 进程；cli=$(team_pm_cli_name)，proof=$(team_pm_proof || echo '?')，model=${TEAM_PM_MODEL:-$TEAM_DEFAULT_MODEL}）"
               else
                 pm_fail=1
                 team_err "PM 启动失败：请手动到 $TEAM_SESSION:$TEAM_PM_WINDOW 里跑 $(team_pm_bin_path)；诊断见 $(team_pm_launch_failed_log)"
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
                 pm_fail=1
                 team_warn "PM 窗口 $TEAM_SESSION:$TEAM_PM_WINDOW 被不属于本项目的进程占用（cwd=$_cwd）：不覆盖、也不新开窗口"
                 team_dim "  关掉那个窗口（或改窗口名）后重跑 $TEAM_CLI up；确认要覆盖：TEAM_REPLACE_FOREIGN_PM=1 $TEAM_CLI up"
               fi ;;
    *)         pm_fail=1; team_warn "PM 窗口状态异常（$pm_state）：不抢窗口" ;;
  esac

  # 3) 可选：agent 续跑（默认不做：agent 由 PM 决定）
  if [ "$with_agents" = "1" ]; then
    team_info ""
    team_cmd_resume
  else
    team_dim "  agent 不归 pulse/up 管：需要续跑时跑 $TEAM_CLI resume [--dry-run]"
  fi

  if team_in_standby; then
    team_warn "注意：当前 standby on（原因：$(team_standby_reason || echo -)）。pulse 不会自动叫醒 PM；处理好后跑 $TEAM_CLI standby off"
  fi

  team_info ""
  team_capacity_line
  team_dim "  旁观：tmux attach -t $TEAM_SESSION ｜ 待办：$TEAM_CLI digest"
  # 状态就是承诺：PM 没起来就不许退 0（否则脚本里的 `team up && …` 会把失败当成功）
  [ "$pm_fail" = "1" ] && return 1
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
      team_cmd_thread "$a" --re "$task" "pulse 想续跑 $task，但任务书 $taskfile 不存在。请 PM 重新生成或改用 --task 指定。" >/dev/null 2>&1 || true
      team_inbox_append "$a" blocked "pulse: 任务书丢失，无法续跑 $task"
      continue
    fi
    n=$((n + 1))
    if [ "$dry" = "1" ]; then
      printf '  %s 可续跑：%s → %s\n' "$a" "$task" "$taskfile"
    else
      team_info "  续跑 $a · $task"
      # M9.3：resume / `up --agents` 与 dispatch 共用同一扇门，而它们派的**永远是这个 agent 自己
      # 记着的任务** —— 在叠任务守卫眼里就是「同一任务 = 继续」，不会被拦；要拦的是「另一个任务
      # 压着这个 agent」（state 与这次要派的 ID 不一致），那由 dispatch 里的守卫统一负责。
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
# pulse 就是“定时看看有没有活儿，并叫醒 PM”：
#   ① 每次记一行容量趋势
#   ② 算一下待办（未读通知/待复验/看板/pM 仍归它管的 agent 停了）
#   ③ 有待办 → 叫醒 PM（在跑就发一句提醒；不在跑且非待命就把它拉起来）
#      没待办 → 不叫醒、不启动（不要求 PM 一直运行）
#   ④ PM 主动 standby 期间，一律不叫醒（人处理后 standby off）
# 不管 tmux 布局（除非 TEAM_PULSE_REBUILD_TMUX=1），不管 agent（那是 PM 的事）。
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

  # ①b 延后投递：一拍排一次水（delivery-guard 的第二个调用者）。
  #     放在待办/待命判断之前：队列里的消息是人或别的路径明确要投的，不属于「待办」，
  #     也不该因为 PM standby 而烂在队列里。没有 daemon：不新建窗口、不留后台进程。
  team_outbox_drain --quiet

  # ② 待办（快速读者：与 team_pending_counts 同值，见 team_panel_pending_counts_fast）
  local counts text sig
  counts="$(team_panel_pending_counts_fast || true)"
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
      team_dim "pulse: 无待办（PM 在跑：不打扰）"
    else
      team_dim "pulse: 无待办（PM 未在跑：不启动，等有活再叫）"
    fi
    return 0
  fi

  # ③b 有待办：按**一次**状态读取定结论。以前这里是先读 team_pm_alive、③c 再读一次 team_pm_state，
  #     两次读取之间状态会变 —— 同一拍里既报「PM 在跑」又按「没在跑」去启动（M7.2 的抖动来源之一）。
  local st; st="$(team_pm_state)"
  if [ "${st%%:*}" = "running" ]; then
    local last_epoch last_sig gap now
    now="$(date +%s)"
    last_epoch="$(team_state_get _watch nudge_epoch 0)"
    last_sig="$(team_state_get _watch nudge_sig '')"
    gap="$TEAM_PULSE_NUDGE_GAP"
    if [ "$sig" != "$last_sig" ] || [ $((now - last_epoch)) -ge "$gap" ]; then
      team_nudge "$text"
      team_state_set _watch nudge_epoch "$now"
      team_state_set _watch nudge_sig "$sig"
      team_state_set _watch last_sig "$sig"
      team_wlog "叫醒 PM：$text"
      team_ok "pulse: 有待办（$text）→ 已提醒 PM"
    fi
    return 0
  fi

  # ③b' 有启动在飞行中（state/pm.pid.starting 新鲜）：既不能当它是活的去提醒，更不能当它不在再拉一个 ——
  #      再 respawn 一次会杀掉正在起来的 PM，配额也会把一次启动记成两次（M7.2 实测的根因）。
  if [ "${st%%:*}" = "starting" ]; then
    team_wlog "PM 正在启动（证据：$(team_pm_evidence "$st")）→ 不重复拉起、不计数（待办：$text）"
    team_dim "pulse: PM 正在启动（${st#starting:}）→ 不重复拉起（待办：$text）"
    return 0
  fi

  # ③c 有待办但 PM 没在跑 → 把它拉起来（除非 tmux 场地不在且不允许重建）
  #     idle（空提示符）与 unknown（本项目里的非 PM 占用者）都算「没有 PM」；foreign 不碰。
  case "$st" in
    idle:*) ;;
    unknown:*) team_wlog "PM 窗口里不是 PM（$st）：按「没有 PM」处理" ;;
    *)
      if [ "$TEAM_PULSE_REBUILD_TMUX" = "1" ]; then
        if ! team_assert_own_session "pulse 重建 tmux"; then
          team_wlog "拒绝重建：session '${TEAM_SESSION:-}' 不属于本项目（授权后加 --yes 或 TEAM_ALLOW_FOREIGN_SESSION=1）"
          return 0
        fi
        if ! team_tmux_has_session "$TEAM_SESSION"; then
          team_wlog "tmux session 丢失，重建（TEAM_PULSE_REBUILD_TMUX=1）"
          team_tmux_ensure_session
          tmux set-option -t "$TEAM_SESSION" destroy-unattached off >/dev/null 2>&1 || true
        fi
        if ! team_pm_window_exists; then
          team_wlog "PM 窗口丢失，重建（TEAM_PULSE_REBUILD_TMUX=1）"
          team_tmux_new_window "$TEAM_SESSION" "$TEAM_PM_WINDOW" || true
        fi
      else
        if [ "$sig" != "$(team_state_get _watch last_sig '')" ]; then
          team_state_set _watch last_sig "$sig"
          team_wlog "有待办（$text）但 PM 找不到（$st；证据：$(team_pm_evidence "$st")）：pulse 不管 tmux，不重建；请人工 $TEAM_CLI up"
          team_warn "pulse: 有待办（$text）但 PM 找不到（$st）—— tmux 场地不在，需要人工 $TEAM_CLI up（不想人工就设 TEAM_PULSE_REBUILD_TMUX=1）"
        fi
        return 0
      fi ;;
  esac

  # 配额只拦「真的再拉一次」；记账（pm-restarts.log）推迟到拉起成功之后 ——
  # 失败/超时不再吃掉一次配额（以前失败也记一行，日志里的「重启 N 次」就不是事实）。
  if ! team_pm_restart_allowed; then
    team_wlog "PM 拉起被配额拦下（$st；证据：$(team_pm_evidence "$st")；待办：$text）"
    team_warn "pulse: PM 拉起失败或被配额拦下（$st；待办：$text）"
    return 0
  fi
  team_pm_attempt_record "state=${st%%:*} evidence=$(team_pm_evidence "$st")"
  if team_pm_start; then
    team_pm_restart_record "state=${st%%:*} evidence=$(team_pm_evidence "$st")"
    team_state_set _watch last_sig "$sig"
    team_wlog "PM 未在运行（$st；证据：$(team_pm_evidence "$st")）→ 已拉起（待办：$text）"
    team_ok "pulse: 有待办（$text）但 PM 没在跑（$st）→ 已拉起"
    team_inbox_append pm pulse "PM 会话曾停止（状态 $st），pulse 因有待办（$text）而用 $(team_pm_cli_name) 拉起它并注入开场提示词（state/pm-prompt.md）"
  else
    team_wlog "PM 拉起失败（$st；证据：$(team_pm_evidence "$st")；未计入配额；待办：$text）"
    team_warn "pulse: PM 拉起失败（$st；待办：$text）—— 未计入重启配额（只有真的重启才计数）"
  fi
  return 0
}

team_cmd_watch() {
  local once=0 interval="$TEAM_PULSE_INTERVAL" ui=0
  local argv=("$@") fp0=""
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

  team_require_cmd tmux "pulse 需要 tmux 来拉起 PM/agent"
  team_watch_lock || return 1
  trap 'team_watch_unlock' EXIT
  # INT/TERM 必须立刻生效：sleep 放后台 + wait（被捕获的信号会立刻打断 wait），handler 里 exit 走 EXIT trap 解锁。
  # 原来是 trap '…' EXIT INT TERM 一把抓：bash 会把前台的 sleep 跑完才执行 handler，解了锁还继续巡 ——
  # Ctrl-C 和 kill 都停不下巡检循环（P8 实测：kill TERM 后 wait 永久阻塞）。
  trap 'exit 130' INT
  trap 'exit 143' TERM
  fp0="$(team_watch_code_fp)"
  team_hdr "teamsmith pulse · $TEAM_PROJECT（每 ${interval}s 一次；Ctrl-C 退出）"
  team_dim "  只做两件事：记录容量趋势 ｜ PM 没在跑就在它的窗口里把 $(team_pm_cli_name) 拉起来"
  team_dim "  不管 tmux 布局，不管 agent（agent 归 PM 管：team resume）"
  while :; do
    # M9.8：判定必须用磁盘上的代码（漂移就重启本进程）—— 否则唤醒理由可能比 digest 旧
    team_watch_reexec_if_stale "$fp0" watch ${argv[@]+"${argv[@]}"}
    team_watch_once
    sleep "$interval" & wait $!
  done
}


# ---------------------------------------------------------------- team monitor
# pulse 窗口里跑的就是它：面板是一个提交进仓库的 Ink bundle（scripts/panel/panel.js），
# 团队字段由 `team __panel-data`（bash 读者 + 队列目录，全程只读）给出，
# 活动流仍然来自数据层 monitor.mjs（--json 契约一字未动）。
#
# 四种输出模式（契约见 openspec 的 panel 能力）：
#   TUI（默认，TTY）    panel.js 自己持有刷新周期与 tick 循环：一个窗口、一个进程、一个巡检
#   --once              一帧（按同一套渲染器选择），到期就跑一次 tick —— 今天语义不变
#   --print             一帧纯文本：没有 ANSI、不 clear、不写 state、绝不 tick
#   --json              {"panel": {...}, "activity": [...]}：不写 state、绝不 tick
# 非 TTY（auto）走纯文本路径：管道里不再出现控制字节（管道里给 TUI 清屏=污染调用方的输出）。
# 没有 JS 运行时时**每一个模式**都响亮失败（一行说清修法）——空面板报成功是假绿。

# ---- 净化 + JSON：面板自己要读的字符串（分支名/任务 id/state 值/队列名）先过一遍净化。
#      数据层那条净化只覆盖数据层自己的输出；这里是第二条独立通道，也保证传输的 JSON 合法
#      （原始控制字节会让 JSON.parse 直接失败）。
team_panel_clean() { # <文本> → 去掉 C0 控制字节（\t 保留），保留可见文本
  # 注意：**不要**用 tr 删 0x80-0x9F —— 那会把 UTF-8 多字节字符的后续字节也删掉（中文直接变乱码）。
  # C1 控制符在 UTF-8 里是 0xC2 0x80-0x9F，交给 panel.js 的净化按字符处理。
  printf '%s' "${1:-}" | LC_ALL=C tr -d '\000-\010\013-\037\177'
}

team_panel_json_str() { # <文本> → JSON 字符串字面量（含引号）
  local v; v="$(team_panel_clean "${1:-}")"
  # JSON 字符串里不能有裸换行/制表符（面板的字段都是单行；这里把多行的折叠成空格）
  v="$(printf '%s' "$v" | tr '\n\t' '  ')"
  v="${v//\\/\\\\}"; v="${v//\"/\\\"}"
  printf '"%s"' "$v"
}

team_panel_num() { # <值> [默认] → 非负整数（面板字段只接受数字）
  local v="${1:-}"
  case "$v" in ''|*[!0-9]*) v="${2:-0}" ;; *) v=$((v)) ;; esac
  printf '%s' "$v"
}

# 延后投递：只读计数，**绝不创建目录、绝不排水**（排水属于 sender / tick / outbox flush）。
# 目录不存在 = 0（P5 未 apply 的项目就是这个形状，不是错误）。
team_panel_outbox_json() {
  local dir="$TEAM_STATE_DIR/outbox" queued=0 held=0 forced=0 oldest="" age="null"
  if [ -d "$dir" ]; then
    queued="$(find "$dir" -maxdepth 1 -name '*.msg' -type f 2>/dev/null | grep -c . || true)"
    held="$(find "$dir/held" -maxdepth 1 -name '*.msg' -type f 2>/dev/null | grep -c . || true)"
    oldest="$(find "$dir" -maxdepth 1 -name '*.msg' -type f 2>/dev/null | LC_ALL=C sort | head -1)"
    if [ -f "$dir/forced.log" ]; then forced="$(grep -c . "$dir/forced.log" 2>/dev/null || true)"; fi
  fi
  if [ -n "$oldest" ]; then
    local base ms now_ms
    base="$(basename "$oldest")"; ms="${base%%-*}"
    case "$ms" in
      ''|*[!0-9]*) ;;
      *) now_ms="$(date +%s%3N 2>/dev/null || printf '%s000' "$(date +%s)")"
         if [ "$now_ms" -gt "$ms" ]; then age=$(( (now_ms - ms) / 1000 )); else age=0; fi ;;
    esac
  fi
  printf '{"queued": %s, "held": %s, "oldest_age_s": %s, "forced": %s}' \
    "$(team_panel_num "$queued")" "$(team_panel_num "$held")" "$age" "$(team_panel_num "$forced")"
}

# 容量：RAM/磁盘 swap/还能再加几个 + capacity.log 尾部的迷你图。zram 物理 MB **不进面板**
# （它留在 `team pulse status`）；所以这里自己算，不直接用 team_capacity_line 的整行。
# 源不可用（没有可读、非空的 capacity.log）= 这个块降级：打印尽力而为的 JSON 并返回非 0，面板渲染 `—`。
team_panel_capacity_json() {
  local avail swapfree swaptotal diskfree disktotal zram_pct zram_phys
  read -r avail swapfree swaptotal <<< "$(team_mem_stats)"
  read -r diskfree disktotal zram_pct zram_phys <<< "$(team_swap_breakdown)"
  local f="$TEAM_STATE_DIR/capacity.log" spark="[]" ram="$avail" joined="" v degraded=1
  local -a vals=()
  if [ -r "$f" ]; then
    while IFS= read -r v; do
      [ -n "$v" ] && vals+=("$v")
    done < <(sed -n 's/.*RAM 可用 \([0-9][0-9]*\)MB.*/\1/p' "$f" | tail -40)
  fi
  if [ "${#vals[@]}" -gt 0 ]; then
    ram="${vals[${#vals[@]}-1]}"
    for v in "${vals[@]}"; do joined="${joined:+$joined, }$v"; done
    spark="[$joined]"
    degraded=0
  fi
  [ -n "${ram:-}" ] || ram=0
  printf '{"ram_avail_mb": %s, "swap_free_mb": %s, "agents": %s, "spark": %s}\n' \
    "$(team_panel_num "$ram")" "$(team_panel_num "$diskfree")" \
    "$(team_panel_num "$(team_agent_capacity)")" "$spark"
  [ "$degraded" = "0" ]
}

# agent 表：状态/任务（state 文件）+ 分支/脏/领先（team_git_cols）+ 会话规模（team_session_*）。
# elapsed/idle/事件数来自数据层（panel.js 合并，JSON 里保留，表格不显示 uptime）。
team_panel_agents_json() {
  local out="[" first=1 a state task wt cols branch dirty ahead upahead
  local model mtok mwin mbytes mfile size dirty_json ahead_json
  for a in $(team_agents); do
    if team_agent_live "$a"; then state="running"
    elif team_agent_window_exists "$a"; then state="exited"
    else state="absent"; fi
    task="$(team_state_get "$a" task '')"
    wt="$(team_agent_worktree "$a")"
    cols="$(team_git_cols "$wt")"
    IFS=$'\t' read -r branch dirty ahead upahead <<< "$cols"
    IFS=$'\t' read -r model mtok mwin mbytes mfile <<< "$(team_agent_session_cols "$a")"
    size="$(team_session_size_text "$mtok" "$mwin")"
    dirty_json="false"
    [ "$(team_panel_num "$dirty")" -gt 0 ] && dirty_json="true"
    ahead_json="null"
    case "${ahead:-}" in ''|*[!0-9]*) ;; *) ahead_json="$ahead" ;; esac
    [ "$first" = "1" ] || out="$out, "
    first=0
    out="$out{\"name\": $(team_panel_json_str "$a"), \"state\": $(team_panel_json_str "$state"), \
\"task\": $(team_panel_json_str "$task"), \"branch\": $(team_panel_json_str "$branch"), \
\"dirty\": $dirty_json, \"ahead\": $ahead_json, \"upstream_ahead\": $(team_panel_json_str "$upahead"), \
\"model\": $(team_panel_json_str "$model"), \"session_tokens\": $(team_panel_num "$mtok"), \
\"session_window\": $(team_panel_num "$mwin"), \"session_text\": $(team_panel_json_str "$size")}"
  done
  printf '%s]' "$out"
}

team_panel_recent_json() { # watchdog.log 的最后 6 行（面板右栏的审计尾巴）
  local f="$TEAM_STATE_DIR/watchdog.log" out="[" first=1 line
  if [ -f "$f" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      [ "$first" = "1" ] || out="$out, "
      first=0
      out="$out$(team_panel_json_str "$line")"
    done < <(tail -6 "$f")
  fi
  printf '%s]' "$out"
}

team_panel_pm_json() { # PM 状态用**闭集**词表：running|starting|absent|foreign|unknown
  local st state detail
  st="$(team_pm_state)"
  case "$st" in
    running:*)  state="running"; detail="${st#running:}" ;;
    starting:*) state="starting"; detail="${st#starting:}" ;;
    idle:*)     state="absent";  detail="${st#idle:}" ;;
    unknown:*)  state="unknown"; detail="${st#unknown:}" ;;
    foreign:*)  state="foreign"; detail="${st#foreign:}" ;;
    *)          state="absent";  detail="" ;;
  esac
  printf '{"state": %s, "detail": %s, "evidence": %s}' \
    "$(team_panel_json_str "$state")" "$(team_panel_json_str "$detail")" \
    "$(team_panel_json_str "$(team_pm_evidence "$st")")"
}

team_panel_standby_json() {
  if team_in_standby; then
    printf '{"on": true, "reason": %s}' "$(team_panel_json_str "$(team_standby_reason || echo '-')")"
  else
    printf '{"on": false, "reason": ""}'
  fi
}

# 面板专用的快速候选枚举：与 cmd-status.sh 的 team_report_candidates +
# team_report_primary_candidates + team_report_copy_rank 同序同集，但每个报告文件的
# basename/id/首行/看板/任务书检查全部走 bash 内建（旧路径 177 个文件 × sed|grep|awk|basename
# ≈ 4300 次进程调用，光枚举就 9s；这里是 1 次 awk + 每个工作树 1 次 git）。
# **过滤一行都不复制**：看板 done/closed、草稿、复验记录仍然交给 cmd-status.sh 的
# team_reports_pending_list --actionable。等价性由 smoke 的同夹具逐行对照断言钉住。
team_panel_report_primary_candidates_fast() { # → 每行 "<id>\t<路径>"（同序同集）
  local -A board_ids=() seen=() wt_ready=() wt_path=() wt_task=() wt_branch=()
  local board="$TEAM_DOCS_ABS/BOARD.md" f base id cand first who rank pass col
  if [ -f "$board" ]; then
    col="$(team_board_col id)"
    while IFS= read -r id; do
      [ -n "$id" ] && board_ids[$id]=1
    done < <(awk -v c="$col" 'BEGIN{FS="|"} /^\|/ { v=$(c); gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); if (v != "") print v }' "$board")
  fi
  for pass in 0 1 2; do
    for f in "$TEAM_DOCS_ABS/reports/"*.md "$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR"/*/"$TEAM_DOCS_DIR"/reports/*.md; do
      [ -f "$f" ] || continue
      case "$f" in
        "$TEAM_DOCS_ABS/reports/"*) [ "$pass" = "0" ] || continue ;;
        *) [ "$pass" != "0" ] || continue ;;
      esac
      base="${f##*/}"; base="${base%.md}"
      case "$base" in *-closure*|*-summary*|*-milestone*|*closure-*|*summary-*) continue ;; esac
      id=""
      cand="$base"
      while :; do
        if [ -n "${board_ids[$cand]:-}" ] || [ -f "$TEAM_DOCS_ABS/tasks/$cand.md" ] \
           || compgen -G "$TEAM_DOCS_ABS/tasks/$cand-*.md" >/dev/null; then
          id="$cand"; break
        fi
        case "$cand" in *-*) cand="${cand%-*}" ;; *) break ;; esac
      done
      [ -n "$id" ] || id="${base%%-*}"
      # team_report_is_task：id 形状 → 首行标题 → 看板行/任务书（与 cmd-status.sh 同顺序同判据）
      case "$id" in _*|.*) continue ;; esac
      [ -n "$id" ] || continue
      first=""
      IFS= read -r first < "$f" || true
      [ -n "$first" ] || continue
      [[ "$first" =~ ^#[[:space:]]+${id}([[:space:]]|·|:|$) ]] || continue
      if [ -z "${board_ids[$id]:-}" ] && ! compgen -G "$TEAM_DOCS_ABS/tasks/$id-*.md" >/dev/null; then continue; fi
      if [ "$pass" != "0" ]; then
        who="${f#"$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR"/}"; who="${who%%/*}"
        rank=2
        case "$base" in "$id-$who") rank=1 ;; esac
        if [ "$rank" != "1" ]; then
          if [ -z "${wt_ready[$who]:-}" ]; then
            wt_ready[$who]=1
            wt_path[$who]="$(team_agent_worktree "$who")"
            wt_task[$who]="$(team_state_get "$who" task '')"
            wt_branch[$who]="$(git -C "${wt_path[$who]}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
          fi
          [ "${wt_task[$who]:-}" = "$id" ] && rank=1
          [ "${wt_branch[$who]:-}" = "$TEAM_TASK_BRANCH_PREFIX/$id" ] && rank=1
        fi
        [ "$rank" = "$pass" ] || continue
      fi
      [ -n "${seen[$id]:-}" ] && continue
      seen[$id]=1
      printf '%s\t%s\n' "$id" "$f"
    done
  done
}

# 待复验计数（面板口径）：快速枚举 + cmd-status.sh 的同一套过滤（--actionable）。
team_panel_reports_pending_fast() { # → 与 team_reports_pending 相同的数
  local cands
  cands="$(team_panel_report_primary_candidates_fast)"
  [ -n "$cands" ] || { printf '0\n'; return 0; }
  team_reports_pending_list --actionable "$cands" | wc -l | tr -d ' '
}

# 待办计数（面板与巡检共用）：与 team_pending_counts 同值，只把待复验换成快速枚举。
# BOARD.md 存在但读不了 = 源坏：仍打印计数形状，但返回非 0（面板降级为 `—`，巡检忽略 rc）。
team_panel_pending_counts_fast() { # → "inbox reports todo wip review blocked stopped"
  local board="$TEAM_DOCS_ABS/BOARD.md" a n inbox=0 stopped=0 task board_ok=1
  if [ -e "$board" ] && [ ! -r "$board" ]; then board_ok=0; fi
  for a in $(team_inbox_recipients); do
    n="$(team_inbox_new "$a")"; inbox=$((inbox + n))
  done
  for a in $(team_agents); do
    task="$(team_state_get "$a" task '')"
    if [ -n "$task" ] && ! team_agent_live "$a"; then stopped=$((stopped + 1)); fi
  done
  local todo=0 wip=0 review=0 blocked=0 bc
  if [ "$board_ok" = "1" ]; then
    bc="$(team_board_counts)"
    read -r todo wip review blocked <<< "$bc"
  fi
  if [ "$TEAM_PULSE_PENDING_BOARD" != "1" ]; then
    # 只保留“现在就等 PM 处理”的信号：todo/wip/review 列仍会在面板与 digest 里显示
    todo=0; wip=0; review=0
  fi
  printf '%s %s %s %s %s %s %s\n' "$inbox" "$(team_panel_reports_pending_fast)" \
    "$todo" "$wip" "$review" "$blocked" "$stopped"
  [ "$board_ok" = "1" ]
}

team_panel_pending_json() {
  local counts="" rc=0
  counts="$(team_panel_pending_counts_fast)" || rc=$?
  local inbox reports todo wip review blocked stopped
  read -r inbox reports todo wip review blocked stopped <<< "$counts"
  local total=$(( $(team_panel_num "$inbox") + $(team_panel_num "$reports") + $(team_panel_num "$todo") \
                  + $(team_panel_num "$wip") + $(team_panel_num "$review") + $(team_panel_num "$blocked") \
                  + $(team_panel_num "$stopped") ))
  printf '{"inbox": %s, "reports": %s, "todo": %s, "wip": %s, "review": %s, "blocked": %s, "stopped": %s, "total": %s, "text": %s}\n' \
    "$(team_panel_num "$inbox")" "$(team_panel_num "$reports")" "$(team_panel_num "$todo")" \
    "$(team_panel_num "$wip")" "$(team_panel_num "$review")" "$(team_panel_num "$blocked")" \
    "$(team_panel_num "$stopped")" "$total" "$(team_panel_json_str "$(team_pending_text "$counts")")"
  return "$rc"
}

# frame 块：项目/时刻/巡检周期/待命/活动源（极便宜，跟每个 tick 重建）。
team_panel_frame_json() {
  printf '{"project": %s, "timestamp": %s, "interval": %s, "standby": %s, "activity_source": %s}\n' \
    "$(team_panel_json_str "$TEAM_PROJECT")" "$(team_panel_json_str "$(team_timestamp)")" \
    "$(team_panel_num "$TEAM_PULSE_INTERVAL")" "$(team_panel_standby_json)" \
    "$(team_panel_json_str "${TEAM_AGENT_LOG_GLOB:-}")"
}

team_panel_json() { # → panel 对象（严格只读：不 mkdir、不 tick、不改任何文件）
  # 兼容路径（旧 bundle / 人工调用）：与块模式同一批读者，键与顺序与 P10 的契约一致。
  printf '{ "project": %s, "timestamp": %s, "interval": %s, "standby": %s, "pm": %s, "pending": %s, "outbox": %s, "capacity": %s, "agents": %s, "recent": %s, "activity_source": %s }' \
    "$(team_panel_json_str "$TEAM_PROJECT")" "$(team_panel_json_str "$(team_timestamp)")" \
    "$(team_panel_num "$TEAM_PULSE_INTERVAL")" "$(team_panel_standby_json)" "$(team_panel_pm_json)" \
    "$(team_panel_pending_json || true)" "$(team_panel_outbox_json)" \
    "$(team_panel_capacity_json || true)" "$(team_panel_agents_json)" \
    "$(team_panel_recent_json)" "$(team_panel_json_str "${TEAM_AGENT_LOG_GLOB:-}")"
}

# 活动流：数据层的 --json 原样透传（只在本 session 有窗口时读；关闭时一个文件都不碰）。
team_panel_activity_json() { # <1|0> <events>
  local on="${1:-1}" events="${2:-4}"
  [ "$on" = "1" ] || { printf '[]'; return 0; }
  local runner js out only="" a w g=()
  runner="$(team_js_runner)"
  js="$TEAM_SKILL_DIR/scripts/monitor.mjs"
  [ -n "$runner" ] && [ -f "$js" ] || { printf '[]'; return 0; }
  for a in $(team_agents); do
    w="$(team_state_get "$a" window "$a")"
    team_tmux_has_window "$TEAM_SESSION" "$w" && only="${only:+$only,}$a"
  done
  team_pm_window_exists && only="${only:+$only,}pm"
  # 本 session 里没有任何窗口 → 不翻别人的会话（也不给 monitor.mjs 传空 --only，那等于「全都要」）
  [ -n "$only" ] || { printf '[]'; return 0; }
  [ -n "${TEAM_AGENT_LOG_GLOB:-}" ] && g=(--log-glob "$TEAM_AGENT_LOG_GLOB")
  out="$("$runner" "$js" --root "$TEAM_MAIN_ROOT" --only "$only" --events "$events" \
        ${g[@]+"${g[@]}"} --json 2>/dev/null || true)"
  case "${out:-}" in
    \[*) printf '%s' "$out" ;;
    *)   printf '[]' ;;
  esac
}

# 块分发：一个块一个子进程（panel.js 用 --block 起一片），源坏时打印尽力而为的片段并返回非 0，
# 由渲染层把那一块画成 `—`，其余块照常渲染。
team_panel_block() { # <块名> <activity 1|0> <events>
  case "$1" in
    frame)    team_panel_frame_json ;;
    pm)       team_panel_pm_json ;;
    pending)  team_panel_pending_json ;;
    outbox)   team_panel_outbox_json ;;
    capacity) team_panel_capacity_json ;;
    agents)   team_panel_agents_json ;;
    recent)   team_panel_recent_json ;;
    activity) team_panel_activity_json "${2:-1}" "${3:-4}" ;;
    *) team_usage_die "__panel-data: 未知块名 $1" ;;
  esac
}

# 内部命令：给 panel.js 一个 JSON（{panel, activity}）或一个块（--block <名>）。
# 名字带 __ 前缀 = 不是给人用的命令面。
team_cmd_panel_data() {
  local activity=1 events="${TEAM_MONITOR_EVENTS:-4}" block=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --no-activity) activity=0; shift ;;
      --activity) activity=1; shift ;;
      --events) events="${2:?__panel-data: --events 需要数字}"; shift 2 ;;
      --block) block="${2:?__panel-data: --block 需要块名}"; shift 2 ;;
      -*) team_usage_die "__panel-data: 未知参数 $1" ;;
      *) team_usage_die "__panel-data: 多余参数 $1" ;;
    esac
  done
  team_require_docs
  if [ -n "$block" ]; then
    team_panel_block "$block" "$activity" "$events"
    return $?
  fi
  printf '{"panel": %s, "activity": %s}\n' "$(team_panel_json)" "$(team_panel_activity_json "$activity" "$events")"
}

# 旧调用点（team_panel）走这里：一帧纯文本，不 tick、不写 state。
team_panel_text() {
  local runner panel
  team_require_js_runtime "team panel"
  runner="$(team_js_runner)"
  panel="$TEAM_SKILL_DIR/scripts/panel/panel.js"
  [ -f "$panel" ] || team_die "team panel: 面板 bundle 缺失（$panel）——skills/teamsmith 安装不完整"
  "$runner" "$panel" --root "$TEAM_ROOT" --team-cli "$TEAM_SKILL_DIR/scripts/team" --print "$@"
}

team_cmd_monitor() {
  local once=0 interval="${TEAM_MONITOR_REFRESH:-5}" with_pulse=1
  local mode="" width="" height="" activity_arg="" events="" state_dir=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --once) once=1; shift ;;
      --print) mode="--print"; shift ;;
      --json) mode="--json"; shift ;;
      --no-pulse) with_pulse=0; shift ;;
      --no-watchdog) with_pulse=0; shift ;;   # 旧旗标（别名期保留到 v2.0.0）：与 --no-pulse 同义
      --activity) activity_arg="--activity"; shift ;;
      --no-activity) activity_arg="--no-activity"; shift ;;
      --interval) interval="${2:?monitor: --interval 需要秒数}"; shift 2 ;;
      --events) events="${2:?monitor: --events 需要数字}"; shift 2 ;;
      --width) width="${2:?monitor: --width 需要列数}"; shift 2 ;;
      --height) height="${2:?monitor: --height 需要行数}"; shift 2 ;;
      --state-dir) state_dir="${2:?monitor: --state-dir 需要目录}"; shift 2 ;;
      -*) team_usage_die "monitor: 未知参数 $1" ;;
      *) team_usage_die "monitor: 多余参数 $1" ;;
    esac
  done
  team_require_docs
  # 运行时是硬要求：四个模式都过这一关（TEAM_REQUIRE_JS=0 只管 doctor 那一行）
  team_require_js_runtime "team monitor"
  local runner panel; runner="$(team_js_runner)"
  panel="$TEAM_SKILL_DIR/scripts/panel/panel.js"
  [ -f "$panel" ] || team_die "team monitor: 面板 bundle 缺失（$panel）——skills/teamsmith 安装不完整"
  local -a args=("$panel" --root "$TEAM_ROOT" --team-cli "$TEAM_SKILL_DIR/scripts/team"
                 --state-dir "${state_dir:-$TEAM_STATE_DIR}"
                 --events "${events:-${TEAM_MONITOR_EVENTS:-4}}" --refresh "$interval"
                 --tick-every "$TEAM_PULSE_INTERVAL" --tick-log "$TEAM_STATE_DIR/watchdog.tick.log")
  [ -n "$mode" ] && args+=("$mode")
  [ "$once" = "1" ] && args+=(--once)
  [ "$with_pulse" = "0" ] && args+=(--no-pulse)
  [ -n "$activity_arg" ] && args+=("$activity_arg")
  [ -n "$width" ] && args+=(--width "$width")
  [ -n "$height" ] && args+=(--height "$height")
  # exec：窗口里的进程就是面板本身（不是它的 bash 父进程）——kill 窗口/PID 就是 kill 面板，
  # 不会留下一个孤儿渲染进程；进程数也只多这一个。
  exec "$runner" ${args[@]+"${args[@]}"}
}

# ---------------------------------------------------------------- pulse：只有一个后端（tmux 窗口）
# 由 PM（或人）用 `team pulse up` 启动：同一个 tmux session 的 `pulse` 窗口常驻跑
# `team monitor`（上半屏团队状态，下半屏可选活动流），并按其内部节拍做定时巡检。
# 为什么不做第二个后端（容器/systemd 等）：本 skill 的底线是**依赖越少越可靠**——
# 少一个运行时、少一层 socket/权限/镜像问题，出问题时只有一个地方要查；
# 巡检的职责只是"定时看看有没有活儿、有待办就叫醒 PM"，它不需要跨 tmux server 存活
# （tmux server 没了 PM 也没了，重建时一起起来即可，`team up` / `pulse up` 都在）。
# （v1.36.0 起由 watchdog 改名 pulse：别名期旧命令/旧窗口名/TEAM_WATCH_* 照用，见下。）

# 窗口解析：TEAM_PULSE_WINDOW（＞ 别名期的 TEAM_WATCH_WINDOW）＞ 默认 pulse
team_pulse_window() { printf '%s\n' "${TEAM_PULSE_WINDOW:-pulse}"; }

# 旧名窗口探针（别名期）：解析出的窗口不在、但旧名 `watchdog` 窗口在（且解析名本身就不是 watchdog）→
# 后端就是那个旧窗口。它里面跑着**升级前的代码**：这时绝不能再开一个巡检 ——
# 两个巡检并存正是 state 文件名在别名期保持不变要防的事（它们共享 pid 锁与提醒签名，但旧进程
# 不会认识新代码的判定规则，唤醒理由会分家）。
team_pulse_legacy_window() { # → 旧窗口名（不适用/不在 → 返回 1）
  local w; w="$(team_pulse_window)"
  [ "$w" = "watchdog" ] && return 1
  team_tmux_has_window "$TEAM_SESSION" "$w" && return 1
  team_tmux_has_window "$TEAM_SESSION" watchdog || return 1
  printf 'watchdog\n'
}

# 实际当作后端的窗口：解析名在 → 解析名；不在而旧名在 → 旧名；都不在 → 解析名（缺席）。
team_pulse_backend_window() {
  local lw
  if lw="$(team_pulse_legacy_window 2>/dev/null)"; then printf '%s\n' "$lw"; else team_pulse_window; fi
}

# 统一的后端无关存活判定（ps / digest / doctor / pulse status 都用它）
# 输出 "tmux:<session>:<window>" | "fg:<pid>" | "off"
team_pulse_state() {
  local w; w="$(team_pulse_backend_window)"
  if team_tmux_has_window "$TEAM_SESSION" "$w" && team_pane_busy "$TEAM_SESSION:$w"; then
    printf 'tmux:%s:%s\n' "$TEAM_SESSION" "$w"; return 0
  fi
  # 窗口在、但前台不是我们认识的面板命令（比如 pager/子进程）→ 只要 pane 忙就算在跑，避免误报
  # （上面已覆盖；fg: 是前台 `team watch` 的存活证据）
  if team_watch_pid_alive; then printf 'fg:%s\n' "$(cat "$TEAM_STATE_DIR/watchdog.pid")"; return 0; fi
  printf 'off\n'
}

team_pulse_state_text() {
  local st; st="$(team_pulse_state)"
  case "$st" in
    tmux:*:*)
      if [ "${st##*:}" != "$(team_pulse_window)" ]; then
        printf '● tmux 窗口 %s 在跑（旧名窗口 → %s pulse restart 换成 %s）' "${st#tmux:}" "$TEAM_CLI" "$(team_pulse_window)"
      else
        printf '● tmux 窗口 %s 在跑' "${st#tmux:}"
      fi ;;
    fg:*)        printf '● 前台巡检 pid %s' "${st#fg:}" ;;
    *)           printf '○ 未在跑（%s pulse up）' "$TEAM_CLI" ;;
  esac
  return 0
}

# 解析出的窗口自己的状态（up/down 的建窗决策只看它；旧名窗口走 team_pulse_legacy_window）
team_pulse_window_state() { # running | idle | absent
  local w; w="$(team_pulse_window)"
  team_tmux_has_window "$TEAM_SESSION" "$w" || { printf 'absent'; return 0; }
  if team_pane_busy "$TEAM_SESSION:$w"; then printf 'running'; else printf 'idle'; fi
}

# tmux 后端（默认）：巡检就住在同一个 tmux session 的 `pulse` 窗口里。
# 好处：① 与开发环境同版本（tmux/ps/git/pi 都在原环境）；② 顺手就是个状态监视器（--ui 面板）；
#       ③ 少一层容器。代价：tmux server 死了它也死（但那时 PM 也死了，重建时一起起来）。
team_pulse_tmux_up() {
  team_require_cmd tmux "巡检需要 tmux（它就跑在同 session 的窗口里）"
  # 窗口里的进程就是面板：没有 JS 运行时时先拒绝，绝不建一个渲染不出来的窗口
  # （那样的窗口会被 pulse status 当成「在跑」，是 D19 明确要避免的假绿）
  team_require_js_runtime "team pulse up"
  team_tmux_ensure_session
  tmux set-option -t "$TEAM_SESSION" destroy-unattached off >/dev/null 2>&1 || true
  local w st lw; w="$(team_pulse_window)"; st="$(team_pulse_window_state)"
  if [ "$st" = "running" ]; then team_ok "巡检已在跑：$TEAM_SESSION:$w（面板：tmux attach -t $TEAM_SESSION）"; return 0; fi
  # 别名期：旧名窗口还在跑 = 后端已存在（升级前的进程）——不开第二个巡检，只指迁移路径
  lw="$(team_pulse_legacy_window 2>/dev/null || true)"
  if [ -n "$lw" ]; then
    team_warn "旧窗口 $TEAM_SESSION:$lw 仍在跑 → $TEAM_CLI pulse restart 换成 $TEAM_SESSION:$w（up 不开第二个巡检）"
    return 0
  fi
  [ "$st" = "idle" ] && { team_warn "窗口 $w 停在空提示符：重开"; tmux kill-window -t "$TEAM_SESSION:$w" 2>/dev/null || true; }
  tmux new-window -t "$TEAM_SESSION" -n "$w" -d -- bash "$TEAM_SKILL_DIR/scripts/team" monitor
  sleep 1.5
  st="$(team_pulse_window_state)"
  if [ "$st" = "running" ]; then
    team_ok "巡检已在 $TEAM_SESSION:$w 跑（每 ${TEAM_PULSE_INTERVAL}s 一屏；logs: $TEAM_CLI pulse logs）"
  else
    team_err "窗口起来了但没在跑（$st）：tmux attach -t $TEAM_SESSION 看输出"
    return 1
  fi
}

team_pulse_tmux_down() {
  local w found=0; w="$(team_pulse_window)"
  if team_tmux_has_window "$TEAM_SESSION" "$w"; then
    tmux kill-window -t "$TEAM_SESSION:$w" 2>/dev/null && { team_ok "已关掉巡检窗口：$TEAM_SESSION:$w"; found=1; } || team_warn "关窗口失败"
  fi
  # 别名期：结束巡检 = 两个名字都结束（旧窗口里可能是升级前的进程）
  if [ "$w" != "watchdog" ] && team_tmux_has_window "$TEAM_SESSION" watchdog; then
    tmux kill-window -t "$TEAM_SESSION:watchdog" 2>/dev/null && { team_ok "已关掉旧名巡检窗口：$TEAM_SESSION:watchdog"; found=1; } || team_warn "关旧名窗口失败"
  fi
  [ "$found" = "0" ] && team_dim "没有巡检窗口（$TEAM_SESSION:$w）"
  return 0
}

team_pulse_tmux_logs() { # 打印面板最近若干行（pane 快照；旧名窗口也是后端，迁移前照样能看）
  local w; w="$(team_pulse_backend_window)"
  team_tmux_has_window "$TEAM_SESSION" "$w" || { team_err "没有巡检窗口（$TEAM_SESSION:$w）；$TEAM_CLI pulse up 起一个"; return 1; }
  tmux capture-pane -p -t "$TEAM_SESSION:$w" -S -60 2>/dev/null | sed '/^$/d' | tail -60
}

team_cmd_pulse() {
  local sub="status" print_only=0
  while [ $# -gt 0 ]; do
    case "$1" in
      up|down|restart|status|logs) sub="$1"; shift ;;
      --print) print_only=1; shift ;;     # 打印它会做什么（不执行）
      --container) team_usage_die "pulse: 容器后端已移除（v1.12.0）——巡检就是同 session 的 pulse 窗口；用 team pulse up" ;;
      -*) team_usage_die "pulse: 未知参数 $1" ;;
      *) team_usage_die "pulse: 多余参数 $1" ;;
    esac
  done
  team_require_docs

  if [ "$print_only" = "1" ]; then
    printf 'tmux 窗口：%s:%s → bash %s/scripts/team monitor\n' "$TEAM_SESSION" "$(team_pulse_window)" "$TEAM_SKILL_DIR"
    local ivnote="（TEAM_PULSE_INTERVAL）"
    case " ${TEAM_PULSE_LEGACY_USED:-} " in *" TEAM_WATCH_INTERVAL "*) ivnote="（来源：TEAM_WATCH_INTERVAL，别名期兜底）" ;; esac
    printf '巡检周期：%ss%s\n' "$TEAM_PULSE_INTERVAL" "$ivnote"
    return 0
  fi
  case "$sub" in
    up)      team_pulse_tmux_up ;;
    down)    team_pulse_tmux_down ;;
    restart) team_pulse_tmux_down >/dev/null 2>&1 || true; team_pulse_tmux_up ;;
    logs)    team_pulse_tmux_logs ;;
    status)  team_cmd_pulse_status ;;
  esac
  return $?
}

# 旧命令名（别名期保留到 v2.0.0）：stdout 第一行印弃用提示，然后把活原样交给 pulse 实现。
# 内部调用者（bootstrap 等）直接调 team_cmd_pulse / team_pulse_tmux_*，不经过这里，所以不会印这行。
team_watchdog_deprecated() { printf '[deprecated] team watchdog 已改名 team pulse（别名保留到 v2.0.0）\n'; }
team_cmd_watchdog()           { team_watchdog_deprecated; team_cmd_pulse "$@"; }
team_cmd_watchdog_status()    { team_watchdog_deprecated; team_cmd_pulse_status "$@"; }
team_cmd_install_watchdog()   { team_watchdog_deprecated; team_cmd_pulse up "$@"; }
team_cmd_uninstall_watchdog() { team_watchdog_deprecated; team_cmd_pulse down "$@"; }

team_cmd_pulse_status() {
  team_hdr "teamsmith pulse · $TEAM_PROJECT"
  local w tst lw
  w="$(team_pulse_window)"; tst="$(team_pulse_window_state)"
  lw="$(team_pulse_legacy_window 2>/dev/null || true)"
  case "$tst" in
    running) team_ok "  巡检              tmux 窗口 $TEAM_SESSION:$w 在跑（--ui 面板）" ;;
    idle)    team_warn "  巡检              窗口 $w 停在空提示符 → $TEAM_CLI pulse up" ;;
    *)       if [ -n "$lw" ]; then
               team_warn "  巡检              旧窗口 $TEAM_SESSION:$lw 仍在跑 → $TEAM_CLI pulse restart 换成 $TEAM_SESSION:$w"
             else
               team_dim "  巡检              未起 → $TEAM_CLI pulse up"
             fi ;;
  esac
  printf '  后端              tmux（同 session 的窗口 —— 只有一个后端，无容器依赖）\n'
  printf '  日志              %s pulse logs ／ tmux attach -t %s\n' "$TEAM_CLI" "$TEAM_SESSION"
  printf '  巡检周期          %ss（建议 300~3600；不是心跳保活，是定时看看有没有活儿）%s\n' "$TEAM_PULSE_INTERVAL" "$(team_pulse_legacy_suffix)"
  if [ -n "${TEAM_PULSE_LEGACY_USED:-}" ]; then
    printf '  旧变量            别名期兜底生效中：%s（v2.0.0 前请改名 TEAM_PULSE_*）\n' "$TEAM_PULSE_LEGACY_USED"
  fi
  # M9.8：唤醒理由必须由磁盘上的代码算出 —— 窗口里的进程比磁盘上的 lib 旧时明说（现场：唤醒
  # 「待复验 6」而 digest 清单是空的，根因就是窗口里跑着前一天起来的进程）。
  local snap; snap="$(team_watch_snapshot_line "$(team_watch_process_start_epoch "$TEAM_SESSION:$(team_pulse_backend_window)")")"
  if [ -n "$snap" ]; then printf '  代码快照          %s\n' "$snap"
  else printf '  代码快照          判不出（窗口不在，或 ps/tmux 不可用）\n'; fi
  printf '  tmux 重建         %s\n' "$([ "$TEAM_PULSE_REBUILD_TMUX" = "1" ] && echo '允许（TEAM_PULSE_REBUILD_TMUX=1）' || echo '不接管（session/窗口没了只告警）')"
  local pm; pm="$(team_pm_state)"
  case "$pm" in
    running:*) team_ok "  PM              在运行（${pm#running:}$(team_pm_proof_suffix)）" ;;
    starting:*) team_info "  PM              正在启动（${pm#starting:}；证据：$(team_pm_evidence "$pm")）：不重复拉起，等它起来" ;;
    idle:*)    team_warn "  PM              未在跑（空提示符）；有待办时 pulse 会拉起它（$TEAM_CLI up 手动）" ;;
    unknown:*) team_warn "  PM              窗口里不是 PM（${pm#unknown:}，cwd=$(team_pane_cwd "$(team_pm_target)" 2>/dev/null || echo '?')）：**不算存活**；$TEAM_CLI up 会替换它" ;;
    foreign:*) team_warn "  PM              窗口被**不属于本项目**的进程占用（cwd=$(team_pane_cwd "$(team_pm_target)" 2>/dev/null || echo '?')）：不覆盖" ;;
    *)         team_warn "  PM              窗口缺失（有待办时：$TEAM_CLI up，或设 TEAM_PULSE_REBUILD_TMUX=1）" ;;
  esac
  local pend; pend="$(team_pending_text "$(team_panel_pending_counts_fast || true)")"
  if [ -n "$pend" ]; then
    # 同一拍里 PM 行与待办行必须一致：suffix 由那**一次** team_pm_state 读取决定（M7.2）
    printf '  待办              %s%s\n' "$pend" "$(team_pm_pending_suffix "$pm")"
  else
    printf '  待办              %s\n' "无（不叫醒 PM）"
  fi
  printf '  %s\n' "$(team_capacity_line)"
  printf '\n  职责：定时看看有没有活儿 + 容量留痕；不管 tmux 布局、不管 agent（agent 归 PM 管）\n'
  if team_in_standby; then
    printf '  待命              on（原因：%s）—— 不叫醒 PM；累积的待办仍记在 watchdog.log\n' "$(team_standby_reason || echo -)"
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
      team_ok "已进入待命：pulse 不会再叫醒 PM（原因：$reason）"
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
      local pend; pend="$(team_pending_text "$(team_panel_pending_counts_fast || true)")"
      printf '待办：%s\n' "${pend:-无}"
      ;;
  esac
  return 0
}
