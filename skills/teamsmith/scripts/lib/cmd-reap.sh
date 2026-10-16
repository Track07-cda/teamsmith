# teamsmith · team reap（P276 · change: orphan-visibility · delta: boundary）
#
# 合同：openspec/changes/orphan-visibility/specs/boundary/spec.md 的
#   `Orphan seat processes of this project are reaped by pid, with an audit and no pattern`。
#
# 为什么它是一个**独立命令**而不是 `ps`/`status` 的副作用：读命令一个信号都不发。清理是破坏性动作，
# 只能由人在 argv 上显式授权（`--yes`），并且在每个目标**发信号之前**再验一遍——从普查到发信号之间
# 有 TOCTOU 窗口，一个刚被回收的 pid 可能是别人的进程、一个刚被重派的席位可能已经有活 pane。
# 既有纪律（`boundary#Signals go to a recorded pid, never to a name or a pattern`）要的正是「对象是
# 证明过的那个」，所以复验是**判据的一部分**，不是防御性装饰。
#
# 三条硬边界：
#   ① **只按 pid 选**：没有 pkill/killall/名字/模式匹配；argv 里给的永远是显式 pid（或 `--orphans`
#      这一条由普查列出的计划），发信号永远 `kill <pid>`。
#   ② `--yes` 是**唯一**授权：不看 TEAM_CONFIRM_WRITES、不看 TEAM_ASSUME_YES、不看任何继承值——
#      环境变量与配置键都不能让一个信号默认发出（合同明文）。
#   ③ 跨项目零点名：别的项目的 pid/项目名/席位名/路径一个都不打印（这份读数会被抄进公开账本）。

# 审计日志的行格式：时间戳 / pid / 席位 / 信号 / 结果。**每个信号恰好一行**（SIGTERM 一行；有界等待后
# 仍活着才再发 SIGKILL，那也是一行）。计划态**不写**这个文件。
team_reap_log_path() { printf '%s\n' "${TEAM_STATE_DIR:-}/reap.log"; }

# 有界等待的秒数（SIGTERM 之后等这么久，然后再 SIGKILL）。它是个**有界**上界，不是睡眠：进程一退出
# 就立刻返回。合同只要求「有界」，没给它一个契约键，所以留在实现里（写进命令页）。
team_reap_grace() { printf '%s\n' "${TEAM_REAP_GRACE_SEC:-5}"; }

team_reap_log_open() { # 授权后打开审计日志（创建 state/ 与 reap.log；计划态绝不调它）
  local d f
  d="$(team_state_dir)"
  f="$d/reap.log"
  : >> "$f" 2>/dev/null || { team_err "reap: 审计日志写不了（$f）—— 没有授权就没有动作"; return 1; }
  return 0
}

team_reap_log_line() { # <pid> <seat> <signal> <outcome>
  local f; f="$(team_reap_log_path)"
  printf '%s pid=%s seat=%s signal=%s outcome=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${1:-?}" "${2:--}" "${3:-?}" "${4:-?}" >> "$f"
}

# 调用者自己或它的祖先（/proc/<pid>/stat 第 4 字段是 ppid）。**自己与祖先**永远不许杀：那是自杀/杀
# 起它的那个壳，与「孤儿」无关。走 /proc，不依赖 ps 的格式。
team_reap_is_self_or_ancestor() { # <pid>
  local p="${1:-}" cur="$$" depth=0
  case "$p" in ''|*[!0-9]*) return 1 ;; esac
  [ "$p" = "$$" ] && return 0
  while [ "$depth" -lt 64 ]; do
    cur="$(awk '{print $4}' "/proc/$cur/stat" 2>/dev/null || true)"
    case "$cur" in ''|*[!0-9]*) break ;; esac
    [ "$cur" = "0" ] && break
    [ "$cur" = "$p" ] && return 0
    depth=$((depth + 1))
  done
  return 1
}

# 一个 pid 的 argv 快照（真 /proc 用一次 ps；夹具根读 cmdline）。形状判据自己也会读，但复验要的是
# **同一次**读到的快照——两次读之间有 execve 的窗口（M39 的既有教训）。
team_reap_argv_of() { # <pid> → argv 快照
  local pid="${1:-}" root out
  [ -n "$pid" ] || return 1
  root="$(team_orphan_proc_root)"
  if [ "$root" = "/proc" ]; then
    out="$(ps -ww -o args= -p "$pid" 2>/dev/null | head -1)"
    [ -n "$out" ] || return 1
    printf '%s\n' "$out"
    return 0
  fi
  team_orphan_read_cmdline "$pid"
}

team_reap_usage() {
  printf '用法：team reap --orphans [--yes] ｜ team reap <pid> [--yes]\n'
  printf '  计划态（没有 --yes）：打印目标与将发的信号，一个信号都不发，退 0。\n'
  printf '  执行态（--yes）：每个目标发信号前**再验一遍**（仍是本项目席位 / 仍没有活 pane / 启动时刻\n'
  printf '  与计划时一致），先 SIGTERM，有界等待后仍活着才 SIGKILL；每个信号一行 state/reap.log。\n'
  printf '  --yes 是唯一授权：配置键、TEAM_ASSUME_YES、继承的环境变量都不能让它默认开。\n'
}

# 目标的第一段判定：这个 pid 现在是什么（own/foreign/anon/orphan/live/unjudged）。印出记录或非 0。
team_reap_target_record() { # <pid> → 一条普查记录
  local pid="${1:-}" args
  args="$(team_reap_argv_of "$pid" 2>/dev/null || true)"
  [ -n "$args" ] || return 1
  team_orphan_record_for "$pid" "$args"
}

# 复验：发信号**之前**，用与普查同一个判据再读一次；任何一条不成立都拒发并说明原因（写进 REAP_REASON）。
team_reap_verify() { # <pid> <计划时的 start> → 0 = 复验通过
  local pid="${1:-}" planned="${2:-}" rec kind seat task start rss judge
  REAP_REASON=""
  rec="$(team_reap_target_record "$pid" 2>/dev/null || true)"
  if [ -z "$rec" ]; then
    REAP_REASON="它不再是席位形状的进程（命令行不再命中本项目配置的 agent/PM 可执行文件，或身份/命令行读不到）"
    return 1
  fi
  IFS=$'\t' read -r _ kind seat task start rss judge <<< "$rec"
  case "$kind" in
    foreign) REAP_REASON="它的身份属于**别的项目**（跨项目零点名：这里不打印它的项目名）"; return 1 ;;
    anon)    REAP_REASON="它没有 teamsmith 身份（可能是人工起的同形进程）"; return 1 ;;
    own)     ;;
    *)       REAP_REASON="它的归属判不出来（$kind）"; return 1 ;;
  esac
  case "$judge" in
    live)     REAP_REASON="它的 pane 又活了——现在不是孤儿了"; return 1 ;;
    unjudged) REAP_REASON="它自己那个 tmux server 查询不到——判不了就不猜（未判定）"; return 1 ;;
    orphan)   ;;
    *)        REAP_REASON="它的孤儿判据给不出结论（$judge）"; return 1 ;;
  esac
  if [ "$start" != "$planned" ]; then
    REAP_REASON="进程启动时刻与计划时不一致（计划=$planned 现在=$start：pid 可能已被内核回收）"
    return 1
  fi
  REAP_SEAT="$seat"
  return 0
}

# 发信号：SIGTERM → 有界等待 → 仍活着再 SIGKILL。每个信号一行审计。
team_reap_signal() { # <pid> <seat> → 0 = 目标已退出
  local pid="${1:-}" seat="${2:--}" grace ticks i alive=0
  grace="$(team_reap_grace)"
  case "$grace" in ''|*[!0-9]*) grace=5 ;; esac
  if ! kill -TERM "$pid" 2>/dev/null; then
    team_reap_log_line "$pid" "$seat" SIGTERM "failed"
    team_err "reap: pid $pid（席位=$seat）SIGTERM 发不出去（进程刚好消失了？）"
    return 1
  fi
  ticks=$(( grace * 10 ))
  i=0
  while [ "$i" -lt "$ticks" ]; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
    i=$((i + 1))
  done
  if ! kill -0 "$pid" 2>/dev/null; then
    team_reap_log_line "$pid" "$seat" SIGTERM gone
    team_ok "reap: pid $pid（席位=$seat）SIGTERM → 已退出"
    return 0
  fi
  team_reap_log_line "$pid" "$seat" SIGTERM "alive→SIGKILL"
  if ! kill -KILL "$pid" 2>/dev/null; then
    team_reap_log_line "$pid" "$seat" SIGKILL failed
    team_err "reap: pid $pid（席位=$seat）SIGKILL 发不出去"
    return 1
  fi
  i=0
  while [ "$i" -lt 100 ]; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
    i=$((i + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    team_reap_log_line "$pid" "$seat" SIGKILL "still-alive"
    team_err "reap: pid $pid（席位=$seat）SIGKILL 之后仍然活着（不可中断/D 状态？）"
    return 1
  fi
  team_reap_log_line "$pid" "$seat" SIGKILL gone
  team_ok "reap: pid $pid（席位=$seat）SIGTERM 之后仍活着 → SIGKILL → 已退出"
  return 0
}

team_cmd_reap() {
  # `--yes` 是**唯一**授权：只看这一次 argv 上有没有它（scripts/team 的全局解析器把 TEAM_YES_ARGV 落成 1）。
  # 显式不看 TEAM_CONFIRM_WRITES、不看继承来的 TEAM_ASSUME_YES——它们都不是「人这次说了要动手」的证据。
  local yes=0 orphans=0 pid="" a
  [ "${TEAM_YES_ARGV:-0}" = "1" ] && yes=1
  while [ $# -gt 0 ]; do
    case "$1" in
      --yes) yes=1; shift ;;
      --orphans) orphans=1; shift ;;
      -h|--help) team_reap_usage; return 0 ;;
      -*) team_usage_die "reap: 未知参数 $1" ;;
      *)
        case "$1" in *[!0-9]*) team_usage_die "reap: 目标只能是显式 pid 或 --orphans（收到 '$1'）——本命令不接受名字或模式" ;; esac
        [ -z "$pid" ] || team_usage_die "reap: 多余参数 $1"
        pid="$1"; shift ;;
    esac
  done
  if [ "$orphans" = 1 ] && [ -n "$pid" ]; then team_usage_die "reap: --orphans 与 <pid> 不同用"; fi
  if [ "$orphans" != 1 ] && [ -z "$pid" ]; then
    team_usage_die "reap: 需要 --orphans 或一个 pid（team reap --orphans [--yes] ｜ team reap <pid> [--yes]）"
  fi
  if [ "$orphans" = 1 ] && [ "${TEAM_ORPHAN_SCAN:-1}" != "1" ]; then
    team_err "reap: 普查被关闭（TEAM_ORPHAN_SCAN=0）——列不出孤儿；用显式 pid（team reap <pid>）"
    return 2
  fi

  team_orphan_ctx_init
  local -a tpids=() tseats=() tmems=() tstarts=()

  if [ -n "$pid" ]; then
    # ── 单个 pid：先把它读成一条记录（拒绝集合在这里就落地） ──
    local rec="" kind seat task start rss judge
    rec="$(team_reap_target_record "$pid" 2>/dev/null || true)"
    if [ -z "$rec" ]; then
      team_err "reap: pid $pid 不是席位形状的进程（命令行不命中本项目配置的 agent/PM 可执行文件，或它的身份/命令行读不到）——一个信号都不发"
      return 2
    fi
    IFS=$'\t' read -r _ kind seat task start rss judge <<< "$rec"
    case "$kind" in
      foreign) team_err "reap: pid $pid 属于**别的项目**的席位——拒发（跨项目零点名：它的项目名/席位名/路径都不打印）"; return 2 ;;
      anon)    team_err "reap: pid $pid 没有 teamsmith 身份——拒发（它可能不是任何项目的席位）"; return 2 ;;
    esac
    if team_reap_is_self_or_ancestor "$pid"; then
      team_err "reap: pid $pid 是调用者自己或它的祖先——拒发（那不是孤儿，是起你的那个壳）"
      return 2
    fi
    if [ "$judge" != "orphan" ]; then
      case "$judge" in
        live)
          # F2（V52 返修轮次 1）：这句拒绝必须**点名另一条入口** —— protocol §4a 的合约是「每个拒绝都
          # 点名另一个入口」（interrupt 侧早已指向 `team reap --orphans`），而 reap 侧此前全文件
          # `grep -c interrupt` = 0：一个活着的席位上被拒，用户拿着一个正确的拒绝却不知道该换哪条命令。
          # 席位名读得到就给具体的（`team interrupt dev --reason …`），读不到（`-`）给占位。
          local who="$seat"; [ "$who" != "-" ] || who="<seat>"
          team_err "reap: pid $pid 不是孤儿（它的 pane 还活着）——它在跑一个回合，要结束它走 team interrupt $who --reason <一句话>；一个信号都不发" ;;
        unjudged) team_err "reap: pid $pid 判不了（它自己那个 tmux server 查询不到）——不猜、不发" ;;
        *)        team_err "reap: pid $pid 的孤儿判据给不出结论（$judge）——不发" ;;
      esac
      return 2
    fi
    tpids+=("$pid"); tseats+=("$seat"); tmems+=("$rss"); tstarts+=("$start")
  else
    # ── --orphans：普查列出的**本项目**孤儿就是计划 ──
    while IFS=$'\t' read -r p kind seat task start rss judge; do
      [ -n "$p" ] || continue
      [ "$kind" = "own" ] || continue
      [ "$judge" = "orphan" ] || continue
      if team_reap_is_self_or_ancestor "$p"; then
        team_warn "reap: 跳过 pid $p——它是调用者自己或它的祖先（不是孤儿）"
        continue
      fi
      tpids+=("$p"); tseats+=("$seat"); tmems+=("$rss"); tstarts+=("$start")
    done < <(team_orphan_census)
  fi

  local n=${#tpids[@]} i
  local grace; grace="$(team_reap_grace)"
  case "$grace" in ''|*[!0-9]*) grace=5 ;; esac

  if [ "$n" -eq 0 ]; then
    if [ "$yes" = 1 ]; then
      team_reap_log_open || return 1
      team_info "reap：没有本项目孤儿席位进程（一个信号都没发；审计日志 $(team_reap_log_path) 已就绪）"
    else
      team_info "reap：没有本项目孤儿席位进程（计划为空；一个信号都不会发）"
    fi
    return 0
  fi

  if [ "$yes" != 1 ]; then
    printf 'reap 计划（%s 个目标；**未授权**——一个信号都不会发；加 --yes 执行）：\n' "$n"
    for i in "${!tpids[@]}"; do
      printf '  %s  席位=%s  内存=%s  启动=%s  → 先 SIGTERM，%ss 后仍活着再 SIGKILL\n' \
        "${tpids[$i]}" "${tseats[$i]}" "$(team_orphan_rss_text "${tmems[$i]}")" \
        "$(team_orphan_ts "${tstarts[$i]}")" "$grace"
    done
    printf '  审计：%s（执行时每个信号一行）\n' "$(team_reap_log_path)"
    return 0
  fi

  # ── 执行态：先开审计日志（授权之后才写盘），然后逐个「复验 → 发信号」 ──
  team_reap_log_open || return 1
  printf 'reap 执行（--yes；%s 个目标；每个目标发信号前**再验一遍**）：\n' "$n"
  local rc=0 seat2
  for i in "${!tpids[@]}"; do
    if ! team_reap_verify "${tpids[$i]}" "${tstarts[$i]}"; then
      team_err "reap: pid ${tpids[$i]} 复验不过，拒发：$REAP_REASON"
      rc=1
      continue
    fi
    seat2="${REAP_SEAT:-${tseats[$i]}}"
    team_reap_signal "${tpids[$i]}" "$seat2" || rc=1
  done
  [ "$rc" = 0 ] || team_err "reap: 有目标没有收干净（见上面的逐条结论）"
  return "$rc"
}
