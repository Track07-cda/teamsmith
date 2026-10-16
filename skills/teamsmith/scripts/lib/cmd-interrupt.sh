# teamsmith · team interrupt（P292 · change: seat-interrupt-entry · delta: boundary）
#
# 合同：openspec/changes/seat-interrupt-entry/specs/boundary/spec.md 的两条 ADDED。
# 设计：openspec/changes/seat-interrupt-entry/design.md（对象证明链 §3、判据 §4、审计行 §5、理由投递 §6）。
#
# 与既有入口的分工（既有语义一个字都不改）：
#   · reap      = 孤儿席位进程（窗口没了、进程还在），按 pid 清理；
#   · interrupt = **一个还在跑的席位回合**：对象由「席位自己的派单记录里的窗口 → pane → pid → 身份与
#                 启动时刻」证明出来，先投递理由、再发信号、然后恰好一行审计；
#   · resume    = 回来的路（语义不变；本命令只**打印**它，不替 PM 做第二步）。
#
# 三条硬边界（与 reap 同源）：
#   ① **只按 pid**：pid 只能来自该席位记录里那个窗口的 pane（前台进程，或那个本项目 agent 可执行
#      文件的直接子进程），再按普查用的**同一套身份判据**证明；没有名字/模式/父子/进程组的进程选择。
#   ② `--yes` 是**唯一**授权：没有它就是一个计划（打印对象/证据/将发的信号，零信号零写盘）；配置键、
#      环境变量、继承值都不能让一个信号默认发出（照 reap：只看这次 argv 上有没有它）。
#   ③ **跨项目零点名**：别的项目的项目名/席位名/工作树/pid 一个都不打印（这份读数会被抄进公开账本）。
#
# 与 long-job-suspend 的关系：长**作业**有账本（state/bg.log）也有叫醒；长**回合**两者都没有，本条
# 补的是后者。被打断席位的后台作业不受影响（detached），续跑后按既有纪律先查 `team bg list`。

# 新鲜窗口的秒数（判据两侧：比它更新的席位磁盘证据 → 拒绝）。它是**有界默认值**，不是契约键
# （与 TEAM_REAP_GRACE_SEC 同族：合同只要求「有界」，所以不进 cmd-config.sh 的 schema）；非数字退回默认。
team_interrupt_fresh_sec() {
  local v="${TEAM_INTERRUPT_FRESH_SEC:-3600}"
  case "$v" in ''|*[!0-9]*) v=3600 ;; esac
  printf '%s\n' "$v"
}

# SIGTERM 之后的有界等待（秒；与 reap 的 5 秒同族）。
team_interrupt_grace() {
  local v="${TEAM_INTERRUPT_GRACE_SEC:-5}"
  case "$v" in ''|*[!0-9]*) v=5 ;; esac
  printf '%s\n' "$v"
}

# 审计日志：一次**授权的**打断恰好一行（计划态与被拒绝的打断一个字都不写）。
team_interrupt_log_path() { printf '%s\n' "${TEAM_STATE_DIR:-}/interrupt.log"; }

# 一句话理由：审计行的形状是固定的，所以理由里的换行/控制字符折叠成单个空格（合同明文要求单行）。
team_interrupt_one_line() {
  printf '%s' "${1:-}" | tr '\n\r\t' '   ' | tr -d '[:cntrl:]' | tr -s ' ' | sed -e 's/^ *//' -e 's/ *$//'
}

team_interrupt_iso() { # <epoch|-> → ISO8601 Z（非数字 → -，不编造）
  local e="${1:-}"
  case "$e" in
    ''|*[!0-9]*) printf '%s\n' '-' ;;
    *) date -u -d "@$e" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf '%s\n' '-' ;;
  esac
}

team_interrupt_mtime() { # <file> → epoch 秒；读不到 → 空（调用方跳过，不填 0）
  [ -n "${1:-}" ] || return 0
  stat -c %Y -- "$1" 2>/dev/null || stat -f %m -- "$1" 2>/dev/null || true
}

# 「还在跑吗」：kill -0 成功但进程已是僵尸 → 它的回合**已经结束**（僵尸只是一个还没被回收的号）。
# 为什么本命令要认这一条：信号路径用「还在不在」决定要不要 SIGKILL、以及审计里的 outcome；把僵尸算
# 活着会让一次成功的打断被写成 still-alive（假红），而僵尸不占回合、也收不到信号。
team_interrupt_alive() { # <pid> → 0 = 还在跑
  local pid="${1:-}" st
  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  st="$(awk '{print $3}' "/proc/$pid/stat" 2>/dev/null || true)"
  [ "$st" = "Z" ] && return 1
  return 0
}

# ---------------------------------------------------------------- 对象证明链（design §3）
# 名册 → 派单记录 → 记录里的窗口 → pane 里的 pid → 身份（普查的同一套判据）+ 记录里的工作树 + 启动时刻。
# 身份判据**不新造第二套**：形状复用 team_orphan_shape_match（含 pm.pid.spawn / dispatch-*.spawn 排除），
# 归属复用进程**自己** environ 里的 TEAM_MAIN_ROOT/TEAM_ROOT（team_orphan_* 的同一份读法），再加一条本
# 入口自己的要求：TEAM_ROOT 必须等于派单记录里的工作树（记录说的是哪个席位进程，就是哪个）。
# 0 = 成立；否则 TEAM_INTERRUPT_ID 是机器可读的原因（shape|noenv|anon|foreign|other-tree|invalid）。
team_interrupt_identity() { # <pid> <记录里的 worktree>
  local pid="${1:-}" want="${2:-}" args envtext line mr r nmr nr
  TEAM_INTERRUPT_ID=""
  [ -n "$pid" ] || { TEAM_INTERRUPT_ID=invalid; return 1; }
  # 命令行快照与普查同源（真 /proc 用一次 ps；夹具根读 cmdline）——同时闭掉两次读的竞态。
  args="$(team_reap_argv_of "$pid" 2>/dev/null || true)"
  [ -n "$args" ] || { TEAM_INTERRUPT_ID=shape; return 1; }
  team_orphan_ctx_init
  if ! team_orphan_shape_match "$pid" "$args"; then TEAM_INTERRUPT_ID=shape; return 1; fi
  envtext="$(team_orphan_read_environ "$pid" 2>/dev/null || true)"
  [ -n "$envtext" ] || { TEAM_INTERRUPT_ID=noenv; return 1; }
  mr=''; r=''
  while IFS= read -r line; do
    case "$line" in
      TEAM_MAIN_ROOT=*) mr="${line#TEAM_MAIN_ROOT=}" ;;
      TEAM_ROOT=*)      r="${line#TEAM_ROOT=}" ;;
    esac
  done <<< "$envtext"
  [ -n "$mr" ] && [ -n "$r" ] || { TEAM_INTERRUPT_ID=anon; return 1; }
  nmr="$(team_orphan_norm_path "$mr" 2>/dev/null || printf '%s' "$mr")"
  nr="$(team_orphan_norm_path "$r" 2>/dev/null || printf '%s' "$r")"
  if [ -z "${TEAM_ORPHAN_SELF_MAIN:-}" ] || [ "$nmr" != "$TEAM_ORPHAN_SELF_MAIN" ]; then
    TEAM_INTERRUPT_ID=foreign; return 1
  fi
  if [ -n "$want" ] && [ "$nr" != "$(team_orphan_norm_path "$want" 2>/dev/null || printf '%s' "$want")" ]; then
    TEAM_INTERRUPT_ID=other-tree; return 1
  fi
  TEAM_INTERRUPT_ID=own
  return 0
}

# 这个席位有没有「窗口没了、进程还在」的孤儿（拒绝时要说清该走 reap 而不是 resume）。
# 判据是普查的原样输出（kind=own + seat 命中 + judge=orphan），不新造第二套**只读**。
team_interrupt_orphan_present() { # <seat> → 0 = 有
  local seat="${1:-}" rec pid kind s task start rss judge
  [ -n "$seat" ] || return 1
  team_orphan_ctx_init
  while IFS=$'\t' read -r pid kind s task start rss judge; do
    [ "$kind" = "own" ] || continue
    [ "$s" = "$seat" ] || continue
    [ "$judge" = "orphan" ] && return 0
  done < <(team_orphan_census 2>/dev/null)
  return 1
}

# ---------------------------------------------------------------- 判据的证据（design §4）
# 两份证据一次读全：①该席位那次会话的会话文件（派单记录里的 sid 解析出来的那份）的 mtime；
# ②工作树里 git 报为改动的文件（`--porcelain -z`：路径按原始字节读，重命名/复制的第二段跳掉）的
# mtime 与**条数**。同一读既给审计的 `uncommitted=` 又给新鲜窗口的判据。
team_interrupt_evidence() { # <worktree> <sid>
  local wt="${1:-}" sid="${2:-}" f m entry x y path mm
  TEAM_INTERRUPT_SESSION_FILE=""; TEAM_INTERRUPT_SESSION_LAST=""
  TEAM_INTERRUPT_UNCOMMITTED=0
  TEAM_INTERRUPT_WT_FILE=""; TEAM_INTERRUPT_WT_MTIME=""
  if [ -n "$sid" ] && [ -n "$wt" ]; then
    f="$(team_session_file "$sid" "$wt" 2>/dev/null || true)"
    if [ -n "$f" ]; then
      m="$(team_interrupt_mtime "$f")"
      TEAM_INTERRUPT_SESSION_FILE="$f"
      TEAM_INTERRUPT_SESSION_LAST="$m"
    fi
  fi
  if [ -n "$wt" ] && [ -d "$wt" ] && team_have_cmd git; then
    while IFS= read -r -d '' entry; do
      [ -n "$entry" ] || continue
      x="${entry:0:1}"; y="${entry:1:1}"; path="${entry:3}"
      # -z 的路径是原始字节；R/C 的条目后面**还有**一段「原路径」，它不是第二个文件
      case "$x$y" in *R*|*C*) IFS= read -r -d '' _ || true ;; esac
      TEAM_INTERRUPT_UNCOMMITTED=$((TEAM_INTERRUPT_UNCOMMITTED + 1))
      [ -n "$path" ] || continue
      mm="$(team_interrupt_mtime "$wt/$path")"
      [ -n "$mm" ] || continue
      if [ -z "$TEAM_INTERRUPT_WT_MTIME" ] || [ "$mm" -gt "$TEAM_INTERRUPT_WT_MTIME" ]; then
        TEAM_INTERRUPT_WT_MTIME="$mm"; TEAM_INTERRUPT_WT_FILE="$path"
      fi
    done < <(git -C "$wt" status --porcelain -z --untracked-files=all 2>/dev/null)
  fi
  return 0
}

# 两份证据里**最新**的那份比窗口更新 → 拒绝（返回 1；TEAM_INTERRUPT_FRESH_FILE / _AGE 是要点名的数）。
# 没有证据（两份都读不到）→ 放行（缺证据不编造：它正是 D188 的形状，也是本入口存在的理由）。
team_interrupt_fresh_check() { # <now> <window-sec>
  local now="${1:-0}" win="${2:-0}" m="" f=""
  TEAM_INTERRUPT_FRESH_FILE=""; TEAM_INTERRUPT_FRESH_AGE=""
  if [ -n "${TEAM_INTERRUPT_SESSION_LAST:-}" ]; then
    f="${TEAM_INTERRUPT_SESSION_FILE}"; m="$TEAM_INTERRUPT_SESSION_LAST"
  fi
  if [ -n "${TEAM_INTERRUPT_WT_MTIME:-}" ]; then
    if [ -z "$m" ] || [ "$TEAM_INTERRUPT_WT_MTIME" -gt "$m" ]; then
      m="$TEAM_INTERRUPT_WT_MTIME"; f="${TEAM_INTERRUPT_WT_FILE}"
    fi
  fi
  [ -n "$m" ] || return 0
  TEAM_INTERRUPT_FRESH_FILE="$f"
  TEAM_INTERRUPT_FRESH_AGE=$(( now - m ))
  [ "$TEAM_INTERRUPT_FRESH_AGE" -ge "$win" ] && return 0
  return 1
}

# ---------------------------------------------------------------- 发信号（与 reap 同一套纪律）
# 发信号**之前**的复验：仍是记录里那个窗口、pane 里的 agent 进程仍是同一个 pid、身份仍成立、
# 启动时刻与本次读到的计划值一致。任何一条不成立 → 拒发并给出理由（TEAM_INTERRUPT_RE）。
team_interrupt_reverify() { # <window> <pid> <planned-start> <worktree>
  local win="${1:-}" pid="${2:-}" planned="${3:-}" wt="${4:-}" now_pid now_start
  TEAM_INTERRUPT_RE=""
  if ! team_tmux_has_window "$TEAM_SESSION" "$win"; then
    TEAM_INTERRUPT_RE="窗口 $TEAM_SESSION:$win 已经不在了（回合早已结束）"
    return 1
  fi
  now_pid="$(team_pane_agent_pid "$TEAM_SESSION:$win" 2>/dev/null || true)"
  if [ "$now_pid" != "$pid" ]; then
    TEAM_INTERRUPT_RE="窗口里的 agent 进程已经不是计划时那个 pid（计划=$pid 现在=${now_pid:-无}）—— 它不再是那个被证明过的进程"
    return 1
  fi
  if ! team_interrupt_identity "$pid" "$wt"; then
    case "${TEAM_INTERRUPT_ID:-}" in
      foreign)    TEAM_INTERRUPT_RE="pid $pid 的身份在读它的时候变成了**别的项目**的（跨项目零点名）" ;;
      anon)       TEAM_INTERRUPT_RE="pid $pid 的身份读不到了（没有 teamsmith 身份）" ;;
      other-tree) TEAM_INTERRUPT_RE="pid $pid 的 TEAM_ROOT 与派单记录的工作树不一致" ;;
      *)          TEAM_INTERRUPT_RE="pid $pid 不再是席位形状的进程（命令行/身份读不到）" ;;
    esac
    return 1
  fi
  now_start="$(team_orphan_start_epoch "$pid" 2>/dev/null || true)"
  if [ -z "$now_start" ]; then
    TEAM_INTERRUPT_RE="pid $pid 的启动时刻读不到 —— 判不出就不猜"
    return 1
  fi
  if [ -n "$planned" ] && [ "$now_start" != "$planned" ]; then
    TEAM_INTERRUPT_RE="pid $pid 的启动时刻与计划时不一致（计划=$planned 现在=$now_start：pid 可能已被内核回收）"
    return 1
  fi
  return 0
}

# SIGTERM → 有界等待 → 仍活着再 SIGKILL。结果写进 TEAM_INTERRUPT_SIGNAL / TEAM_INTERRUPT_OUTCOME。
team_interrupt_signal() { # <pid> → 0 = 目标已退出
  local pid="${1:-}" grace ticks i
  grace="$(team_interrupt_grace)"
  TEAM_INTERRUPT_SIGNAL=""; TEAM_INTERRUPT_OUTCOME=""
  if ! kill -TERM "$pid" 2>/dev/null; then
    TEAM_INTERRUPT_SIGNAL="SIGTERM"; TEAM_INTERRUPT_OUTCOME="failed"
    team_err "interrupt: pid $pid 的 SIGTERM 发不出去（进程刚好消失了？）"
    return 1
  fi
  TEAM_INTERRUPT_SIGNAL="SIGTERM"
  ticks=$(( grace * 10 )); i=0
  while [ "$i" -lt "$ticks" ]; do
    team_interrupt_alive "$pid" || break
    sleep 0.1
    i=$((i + 1))
  done
  if ! team_interrupt_alive "$pid"; then TEAM_INTERRUPT_OUTCOME="gone"; return 0; fi
  TEAM_INTERRUPT_SIGNAL="SIGTERM→SIGKILL"
  if ! kill -KILL "$pid" 2>/dev/null; then
    TEAM_INTERRUPT_OUTCOME="failed"
    team_err "interrupt: pid $pid 的 SIGKILL 发不出去"
    return 1
  fi
  i=0
  while [ "$i" -lt 100 ]; do
    team_interrupt_alive "$pid" || break
    sleep 0.1
    i=$((i + 1))
  done
  if team_interrupt_alive "$pid"; then
    TEAM_INTERRUPT_OUTCOME="still-alive"
    team_err "interrupt: pid $pid 在 SIGKILL 之后仍然活着（不可中断 / D 状态？）"
    return 1
  fi
  TEAM_INTERRUPT_OUTCOME="gone"
  return 0
}

# 一行审计（design §5）：一次打断一行；`session_last` 与 `uncommitted` 是**发信号之前**读到的那一份。
team_interrupt_audit() { # <actor> <seat> <pid> <session_last> <uncommitted> <guard> <reason> <signal> <outcome>
  local f; f="$(team_interrupt_log_path)"
  printf '%s actor=%s seat=%s pid=%s session_last=%s uncommitted=%s guard=%s reason=%s signal=%s outcome=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${1:--}" "${2:--}" "${3:--}" "${4:--}" "${5:--}" "${6:--}" \
    "${7:--}" "${8:--}" "${9:--}" >> "$f" || return 1
  return 0
}

# 理由投递（design §6）：席位续跑后读的三步里，第二步就是它自己的线程（dispatch 的提示词里逐字写着
# threads/<seat>.md）；收件箱那一行是同一件事的持续通知。写不进去就返回 1 —— 调用方据此拒发。
# 它是独立的一层，为的是让「先写理由、后发信号」这条顺序能被单独推翻与验证（红侧）。
# 线程追加：单独一层。为什么不能写在一个 `if ! { …; } >> "$f"` 里 —— bash 对「复合命令的重定向失败」
# 在 `!` 位上的状态会看不见（实测：rc=1 但 `if !` 走 else，=> “写不进去”被当成写成功了）。
# 单独一层用 `||` 拿状态就没这个陷阱，也能被红侧单独推翻。
team_interrupt_thread_append() { # <线程文件> <条目文本>
  { [ -s "$1" ] && printf '\n'; printf '%s' "$2"; } >> "$1" 2>/dev/null || return 1
  return 0
}

team_interrupt_deliver_reason() { # <actor> <seat> <task> <pid> <reason> → 0 = 两处都写好了
  local actor="${1:-}" seat="${2:-}" task="${3:-}" pid="${4:-}" reason="${5:-}"
  local thread_file="$TEAM_DOCS_ABS/threads/$seat.md" inbox_file="$TEAM_DOCS_ABS/inbox/$seat.md" body entry
  body="$(printf '回合被打断（interrupt）：%s 在 %s 结束了该席位正在跑的回合（pid=%s，理由：%s）。\n磁盘状态都在：工作树里未提交的改动、它那次会话的会话文件与派单记录一个字节没动。\n先做什么：先看这一段（本线程最新一条）与 `git status`，确认打断前后的状态；再按任务书继续 %s。回到同一会话：`team resume --agent %s`；后台作业先 `team bg list`。' \
    "$actor" "$(team_timestamp)" "$pid" "$reason" "${task:-<本任务>}" "$seat")"
  entry="$(printf '### %s · from: %s · re: %s\n%s\n' "$(team_timestamp)" "$actor" "${task:--}" "$body")"
  if ! team_interrupt_thread_append "$thread_file" "$entry"; then
    team_err "interrupt: 理由写不进该席位的线程（$thread_file）—— 拒发（没有理由的打断不许发生）"
    return 1
  fi
  if ! team_inbox_append "$seat" "interrupt" "（回合被打断：$actor · pid=$pid）$reason" "$actor" 2>/dev/null; then
    team_err "interrupt: 理由写不进该席位的收件箱（$inbox_file）—— 拒发（线程里已写、信号没发）"
    return 1
  fi
  return 0
}

team_interrupt_usage() {
  printf '用法：team interrupt <seat> --reason <一句话> [--force] [--yes]\n'
  printf '  结束该席位**当前的回合**（对它自己被证明过的进程发 SIGTERM，有界等待后仍活着再 SIGKILL）；\n'
  printf '  磁盘状态保留（未提交改动 / 会话文件 / 派单记录），回来的路是 team resume --agent <seat>。\n'
  printf '  没有 --yes 是计划：打印对象、证据与将发的信号，一个信号都不发、一个字都不写。\n'
  printf '  --reason 必填：发信号**之前**写进该席位的线程（它续跑时的第二步就是读它）与收件箱。\n'
  printf '  --force 只越过「席位正在写盘」这一条：最新的磁盘证据比新鲜窗口（默认 3600s，'
  printf 'TEAM_INTERRUPT_FRESH_SEC 可调）更新时本命令拒绝，越权会写进那一行审计（guard=forced）。\n'
  printf '  --yes 是唯一授权：配置键、环境变量、继承值都不能让一个信号默认发出。\n'
  printf '  不属于本入口的：没有在跑的回合 → team resume --agent <seat>；窗口没了而进程还在（孤儿）→ team reap --orphans。\n'
}

# ---------------------------------------------------------------- 入口
team_cmd_interrupt() {
  local seat="" reason="" reason_set=0 force=0 yes=0
  # `--yes` 是**唯一**授权：只看这次 argv 上有没有它（scripts/team 的全局解析器把它落成 TEAM_YES_ARGV=1）。
  # 显式不看 TEAM_CONFIRM_WRITES / TEAM_ASSUME_YES —— 它们都不是「人这次说了要动手」的证据。
  [ "${TEAM_YES_ARGV:-0}" = "1" ] && yes=1
  while [ $# -gt 0 ]; do
    case "$1" in
      --yes)   yes=1; shift ;;
      --force) force=1; shift ;;
      --reason) [ $# -ge 2 ] || team_usage_die "interrupt: --reason 需要一句话"; reason="$2"; reason_set=1; shift 2 ;;
      --reason=*) reason="${1#*=}"; reason_set=1; shift ;;
      -h|--help) team_interrupt_usage; return 0 ;;
      -*) team_usage_die "interrupt: 未知参数 $1" ;;
      *) if [ -z "$seat" ]; then seat="$1"; shift; else team_usage_die "interrupt: 多余参数 $1"; fi ;;
    esac
  done
  [ -n "$seat" ] || team_usage_die "interrupt: 需要席位名（interrupt <seat> --reason <一句话> [--force] [--yes]）"

  # ① 理由必填：在任何写入与信号之前拒绝（没有理由就没有这一族动作 —— 与「一次打断一句话理由」同源）。
  if [ "$reason_set" != 1 ]; then
    team_err "interrupt: 缺少 --reason（每次打断都要一句话理由）—— 什么都没写、什么都没发"
    return 2
  fi
  reason="$(team_interrupt_one_line "$reason")"
  if [ -z "$reason" ]; then
    team_err "interrupt: --reason 是空的（要一句话理由）—— 什么都没写、什么都没发"
    return 2
  fi

  # ② actor 从运行时目录解析（审计的第一件事是「谁」）；解析不出来就拒绝，身份不许猜。
  local actor; actor="$(team_sender_resolve 2>/dev/null || true)"
  if [ -z "$actor" ]; then
    team_err "interrupt: actor 解析不出来（运行时目录不在本项目的工作树里）—— 审计的第一格是「谁」，不猜；什么都没写、什么都没发"
    return 2
  fi

  # ③ 名册：入口参数是**本项目的席位名**（这是唯一的「名字」，它映射到本项目自己的记录与窗口）。
  if ! team_agent_known "$seat"; then
    team_err "interrupt: 「$seat」不在名册（$(team_agents | tr '\n' ' ')）—— 名册由 team add-agent <名字> --register 维护"
    return 2
  fi

  # ④ 派单记录：窗口 / 工作树 / 会话 id 都从它来（没有记录就没有对象证明链，也没有回来的路）。
  if ! team_assignment_load "$seat"; then
    team_err "interrupt: 席位 $seat 没有可读的派单记录（state/$seat.env：${TEAM_ASSIGN_DIAGNOSTIC:-?}）—— 没有记录就没有对象证明链"
    team_dim "  它没有在跑的回合：team resume --agent $seat（或 team dispatch 重新派）" >&2
    return 2
  fi
  local wt="${TEAM_ASSIGN[worktree]:-}" win="${TEAM_ASSIGN[window]:-}" sid="${TEAM_ASSIGN[sid]:-}" \
        task="${TEAM_ASSIGN[task]:-}" mode="${TEAM_ASSIGN[mode]:-}"
  [ -n "$win" ] || win="$seat"
  local target="$TEAM_SESSION:$win"

  # ⑤ 存活与拒绝集合各自给出路：进程不在 → resume；窗口没了而进程还在（孤儿）→ reap。
  if ! team_tmux_has_window "$TEAM_SESSION" "$win"; then
    if team_interrupt_orphan_present "$seat"; then
      team_err "interrupt: 席位 $seat 的窗口 $win 没了、进程还活着（孤儿）—— 走 team reap --orphans"
    else
      team_err "interrupt: 席位 $seat 没有在跑的回合（窗口 $target 不存在）—— 走 team resume --agent $seat"
    fi
    return 2
  fi
  local pid; pid="$(team_pane_agent_pid "$target" 2>/dev/null || true)"
  if [ -z "$pid" ]; then
    team_err "interrupt: 窗口 $target 里没有证明是本项目 agent 的进程（回合已经结束了）—— 走 team resume --agent $seat"
    return 2
  fi

  # ⑥ 调用者自己与它的祖先：拒发（那不是席位，是起你的那个壳）。--force 也越不过这一条。
  if team_reap_is_self_or_ancestor "$pid"; then
    team_err "interrupt: pid $pid 是调用者自己或它的祖先 —— 拒发（本入口只结束**别的**进程的回合）"
    return 2
  fi

  # ⑦ 身份：过程自己的 TEAM_MAIN_ROOT（本项目）+ TEAM_ROOT（= 记录里的工作树）+ 形状（本项目 agent 可执行文件）。
  if ! team_interrupt_identity "$pid" "$wt"; then
    case "${TEAM_INTERRUPT_ID:-}" in
      foreign)
        team_err "interrupt: 窗口里的进程身份属于**别的项目** —— 拒发（跨项目零点名：它的项目名/席位名/工作树/pid 都不打印）" ;;
      anon)
        team_err "interrupt: 窗口里的进程没有 teamsmith 身份 —— 拒发（它可能不是任何项目的席位）" ;;
      other-tree)
        team_err "interrupt: 窗口里的进程是**本项目别的**工作树里的席位进程（与派单记录的工作树不一致）—— 拒发（对象不是记录里那个席位进程）" ;;
      *)
        team_err "interrupt: 窗口里的进程不是本项目配置的 agent 可执行文件（或它的命令行/身份读不到）—— 拒发" ;;
    esac
    return 2
  fi
  local planned_start; planned_start="$(team_orphan_start_epoch "$pid" 2>/dev/null || true)"

  # ⑧ 判据：发信号**之前**的读数（会话最后落盘 + 工作树未提交条数 + 最新那份证据）。
  team_interrupt_evidence "$wt" "$sid"
  local now fresh_sec fresh_ok=0 guard="clear"
  now="$(date +%s)"
  fresh_sec="$(team_interrupt_fresh_sec)"
  team_interrupt_fresh_check "$now" "$fresh_sec" || fresh_ok=1
  if [ "$fresh_ok" = 1 ] && [ "$force" != 1 ]; then
    team_err "interrupt: 席位 $seat 正在写盘 —— 最新的一份磁盘证据比新鲜窗口（${fresh_sec}s）更新："
    team_err "  $TEAM_INTERRUPT_FRESH_FILE（${TEAM_INTERRUPT_FRESH_AGE}s 前）"
    team_dim "  要越过它：--force + 一句话理由（越权会写进那一行审计 guard=forced）。--force 越不过身份/存活/名册/跨项目/自身。" >&2
    return 2
  fi
  [ "$fresh_ok" = 1 ] && guard="forced"

  # ── 计划态（默认）：证据全部读出来、一个信号都不发、一个字都不写 ──
  if [ "$yes" != 1 ]; then
    printf 'interrupt 计划（席位 %s；**未授权** —— 一个信号都不会发、一个字都不会写；加 --yes 执行）：\n' "$seat"
    printf '  对象：pid=%s（窗口 %s 里的 agent 进程；身份=本项目席位、TEAM_ROOT=%s）\n' "$pid" "$target" "$wt"
    printf '  启动：%s（启动时刻；发信号前会与它比对）\n' "$(team_interrupt_iso "${planned_start:--}")"
    printf '  证据：会话最后落盘=%s' "$(team_interrupt_iso "${TEAM_INTERRUPT_SESSION_LAST:--}")"
    [ -n "$TEAM_INTERRUPT_SESSION_FILE" ] && printf '（%s）' "$TEAM_INTERRUPT_SESSION_FILE"
    printf '；工作树未提交=%s 个\n' "$TEAM_INTERRUPT_UNCOMMITTED"
    if [ -n "$TEAM_INTERRUPT_FRESH_FILE" ]; then
      printf '  最新磁盘证据：%s（%ss 前；新鲜窗口 %ss，guard=%s）\n' \
        "$TEAM_INTERRUPT_FRESH_FILE" "$TEAM_INTERRUPT_FRESH_AGE" "$fresh_sec" "$guard"
    else
      printf '  最新磁盘证据：（读不到 —— 缺证据不编造；新鲜窗口 %ss，guard=%s）\n' "$fresh_sec" "$guard"
    fi
    printf '  将发信号：SIGTERM → %ss 后仍活着再 SIGKILL（只对这一个 pid）\n' "$(team_interrupt_grace)"
    printf '  理由：%s\n' "$reason"
    printf '  之后：team resume --agent %s（回到记录里的会话 sid=%s，mode=%s）\n' "$seat" "${sid:--}" "${mode:--}"
    printf '  审计：%s（执行时恰好一行；计划态不写）\n' "$(team_interrupt_log_path)"
    return 0
  fi

  # ── 执行态（--yes）────────────────────────────────────────────────────────────────────────
  # ① 复验（发信号**之前**；不过 → 拒绝，thread/inbox/审计一个字节都不动）。
  if ! team_interrupt_reverify "$win" "$pid" "$planned_start" "$wt"; then
    team_err "interrupt: 复验不过，拒发 —— $TEAM_INTERRUPT_RE"
    team_dim "  一个信号都没发；该席位的线程、收件箱与审计日志都没有变。" >&2
    return 2
  fi

  # ② 理由投递：**先写理由、后发信号**（写不进去就拒绝，绝不出现「杀了它，但它不知道为什么」）。
  #    线程是席位阅读顺序的第二步（dispatch 的提示词里逐字写着 threads/<seat>.md）。
  team_interrupt_deliver_reason "$actor" "$seat" "$task" "$pid" "$reason" || return 2

  # ③ 审计日志先就绪（授权之后才写盘；写不了就拒绝，绝不发一个没有记录可查的信号）。
  : >> "$(team_interrupt_log_path)" 2>/dev/null || {
    team_err "interrupt: 审计日志写不了（$(team_interrupt_log_path)）—— 拒发（没有记录就没有动作）"
    return 2
  }

  # ④ 信号：只对这一个 pid。
  local rc=0
  printf 'interrupt 执行（--yes；席位 %s pid=%s）：\n' "$seat" "$pid"
  printf '  理由已写进线程 %s 与收件箱 %s（在发信号之前）\n' "$TEAM_DOCS_ABS/threads/$seat.md" "$TEAM_DOCS_ABS/inbox/$seat.md"
  team_interrupt_signal "$pid" || rc=1
  if ! team_interrupt_audit "$actor" "$seat" "$pid" "$(team_interrupt_iso "${TEAM_INTERRUPT_SESSION_LAST:--}")" \
       "$TEAM_INTERRUPT_UNCOMMITTED" "$guard" "$reason" "${TEAM_INTERRUPT_SIGNAL:--}" "${TEAM_INTERRUPT_OUTCOME:--}"; then
    team_err "interrupt: 审计写不进去（$(team_interrupt_log_path)）—— 动作已经做了，但**没有记录可查**，请 PM 手工补一行"
    rc=1
  fi
  if [ "$rc" = 0 ]; then
    team_ok "interrupt: pid $pid 的回合已结束（${TEAM_INTERRUPT_SIGNAL} → ${TEAM_INTERRUPT_OUTCOME}）；审计 $(team_interrupt_log_path) 1 行"
  else
    team_err "interrupt: pid $pid 没有收干净（${TEAM_INTERRUPT_SIGNAL:--} → ${TEAM_INTERRUPT_OUTCOME:--}）；审计 $(team_interrupt_log_path) 1 行"
  fi
  printf '  之后：team resume --agent %s（回到记录里的会话 sid=%s，mode=%s）\n' "$seat" "${sid:--}" "${mode:--}"
  return "$rc"
}
