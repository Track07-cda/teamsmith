#!/usr/bin/env bash
# teamsmith · PM 窗口现场的共享助手（P413）
#
# 这些助手以前定义在 §11b 的**段体里**：`smoke.sh --select <key>` 只把选中的段复制成一份独立脚本，
# 于是任何单独裁出来的段（§11b2 / §11b3 / §11b4 / §11c）调用它们就是 `command not found`，
# 随后的断言整段塌掉 —— 公开 CI shard 3 的现场：`--select` 裁出的副本第 3282 行
# `make_pm_idle: command not found`，八条 PM 交接断言红（P413）。全量按源序跑时 11b 在前、函数还在
# shell 里，所以本地看不见；分片按哈希取段，11b4 单独下发就红（同 P405 的 §2 依赖上一段 `cd`）。
#
# 判据：任意一段被单独裁出来时，要么绿、要么以「缺前置」为理由显式 SKIP，不许 command not found。
# 所以「同一段里定义的助手」只能留在段体里，「被别的段用的助手」必须放在这里 —— 本文件由 smoke.sh
# 顶部 source（前导段、任何选段都带上）。`tests/section-select.sh --self-sufficient` 静态守着这条。
#
# 这里只放**读状态 / 等条件 / 造空窗**这类现场助手：它们不写账本、不碰真实项目，调用方必须已经把
# 身份钉在夹具仓库（$REPO / $SESSION）里。段自己的夹具数据（假 pi 的 argv 日志、config 改写）留在段内。
#
# 为什么不裸调 tmux（P414）：本文件会被 `--select` 单独裁进段副本，而静态 lint 不认「运行时套件装了
# tmux() 壳」这种背书（P173：通用名 `tmux` 不给同目录别的文件背书）——裸调用就是 RED。所以这里的每次
# tmux 调用都经**专用名** `pmw_tmux`：隔离写成文本里读得出的构造（`env -u TMUX` + 本轮私有
# `TMUX_TMPDIR`），变更类先过 P162 的三条件前置；缺私有目录就响失败，绝不回落调用者的默认 server。
pmw_tmux() { # <tmux argv…>：读写都打本轮私有 server（见上一段「为什么不裸调」）
  [ -n "${TMUX_TMPDIR:-}" ] || { printf '✗ pm-window 夹具：TMUX_TMPDIR 未设 —— 拒绝回落调用者的默认 server\n' >&2; return 1; }
  tmux_iso_argv_parse "$@"
  if [ "${TMUX_ISO_ARGV_DESTRUCTIVE:-0}" = 1 ]; then pmw_tmux_require "$@" || return 1; fi
  env -u TMUX -u TMUX_PANE TMUX_TMPDIR="${TMUX_TMPDIR}" tmux "$@"
}
pmw_tmux_require() { # <tmux argv…>：变更类的 P162 前置（与套件 tmux() 壳同一份判定；不成立 → 硬停）
  tmux_iso_require "${SMOKE_SEC_OPEN_ID:-pm-window}" "PM 窗口现场：${1:-?}" \
    --tmpdir "$TMUX_TMPDIR" --own-root "${TMP:-}" --own-root "${SMOKE_TMUX_OWN_ROOT:-}" \
    --caller-tmpdir "${SMOKE_CALLER_TMUX_TMPDIR:-}"
}

# PM 窗口名：以项目配置为准（`team paths` 的 pm_window），解析不出才退回约定值 pm。
# 结果写进全局 PMW —— §11b / §11b2 / §11b3 一直按这个名字引用窗口。幂等：算过一次就复用，
# 所以轮询循环里调用它不会反复问 CLI。
pm_window_name() {
  if [ -z "${PMW:-}" ]; then
    PMW="$($TEAM paths 2>/dev/null | sed -n 's/.*"pm_window": "\([^"]*\)".*/\1/p')"
    [ -n "$PMW" ] || PMW=pm
  fi
  printf '%s' "$PMW"
}

# M9.7：这一族 fixture 以前是「动作 + 固定 sleep + 采样一次状态」——采样撞上过渡态就假红
# （实测：§11b3 ⑤ 的 attempts 行记成 state=unknown 而不是 state=idle；注入 1.2s 的窗口过渡
# 1/1 次可复现，见 docs/team/reports/M9.7-dev2/）。改成有界轮询**实际条件**（状态真的变成我们要的
# 样子），超时把「最后看到的状态」原样报出来。等待**不是**「把红等成绿」：它带 deadline，超时由
# 调用方报红（持续回归只是晚 10s 红），超时信息里带最后看到的状态，下一次发生不必再考古。
pm_state_now() { ( . "$SKILL_DIR/scripts/lib/common.sh"; team_load_config; team_pm_state ); }
pm_state_until() { # <case 模式…> [最多等秒] → 0=等到了；最后状态留在 PM_STATE_LAST
  # 多个模式是「或」关系（每个模式单独做 case 匹配：模式里的 | 在变量展开后不会被当成分隔符，
  # 所以 `pm_state_until 'unknown:tmux' 'idle:*' 10` 而不是 'unknown:tmux|idle:*'）。
  local secs="${!#:-300}" i=0 ticks p
  ticks=$(( secs * 4 ))
  PM_STATE_LAST=""
  while [ "$i" -lt "$ticks" ]; do
    PM_STATE_LAST="$(pm_state_now 2>/dev/null || true)"
    for p in "${@:1:$#-1}"; do
      case "$PM_STATE_LAST" in $p) return 0 ;; esac
    done
    sleep 0.25
    i=$((i + 1))
  done
  return 1
}
pm_state_until_not() { # <case 模式> [最多等秒] → 0=状态不再是该模式
  local avoid="$1" secs="${2:-300}" i=0 ticks
  ticks=$(( secs * 4 ))
  PM_STATE_LAST=""
  while [ "$i" -lt "$ticks" ]; do
    PM_STATE_LAST="$(pm_state_now 2>/dev/null || true)"
    case "$PM_STATE_LAST" in $avoid) ;; *) return 0 ;; esac
    sleep 0.25
    i=$((i + 1))
  done
  return 1
}
wait_session_gone() { # <session> [最多等秒]
  local s="${1:-}" secs="${2:-300}" i=0 ticks
  ticks=$(( secs * 20 ))
  while [ "$i" -lt "$ticks" ]; do
    pmw_tmux has-session -t "$s" 2>/dev/null || return 0
    sleep 0.05
    i=$((i + 1))
  done
  return 1
}
wait_window_gone() { # <窗口名> [最多等秒]（沿用夹具的 $SESSION）
  local n="${1:-}" secs="${2:-300}" i=0 ticks
  ticks=$(( secs * 20 ))
  while [ "$i" -lt "$ticks" ]; do
    pmw_tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -qx "$n" || return 0
    sleep 0.05
    i=$((i + 1))
  done
  return 1
}

# 制造“PM 窗口在、里面是空提示符”的现场（pi 退出后的样子），并用占位窗口保住 session
make_pm_idle() {   # 让 PM 窗口回到**确定性**的空 shell（等 team_pm_state 真的报 idle:*，不是赌一次 sleep）
  pm_window_name >/dev/null   # 单跑 §11b4/§11c 时 PMW 还没人设过（P413）
  # session 本身可能还不存在：单独裁出来的段前面没有 §11b2「先 kill 再 new」那一步，而 tmux new-window
  # 对不存在的 session 是直接失败 —— 于是窗口永远建不出来、状态停在 missing，这里白等 300s
  # （P413 实测：`--select 11b4` 唯一的一条红就是这个）。场景助手要把场景备齐，判据不变。
  if pmw_tmux has-session -t "$SESSION" 2>/dev/null; then
    pmw_tmux new-window -t "$SESSION" -n keep -d -c "$REPO" >/dev/null 2>&1 || true
  else
    pmw_tmux new-session -d -s "$SESSION" -n keep -c "$REPO" >/dev/null 2>&1 || true
  fi
  pmw_tmux list-windows -t "$SESSION" -F '#{window_id} #{window_name}' 2>/dev/null \
    | awk -v n="$PMW" '$2==n {print $1}' \
    | while read -r wid; do [ -n "$wid" ] && pmw_tmux kill-window -t "$wid" 2>/dev/null || true; done
  # 窗口里跑**不带 rc 的 bash**（M35）——不是任何 profile 跑完后的登录 zsh。
  # 实测（M35 注入实验）：登录 zsh 的 profile（/etc/zsh/zprofile → distrobox 的 host-spawn）
  # 在“提示符已出现”之后仍会间歇性起前台子进程；make_pm_idle 的两次采样可以落在空档里，而紧接着的
  # 那一拍（§11b3 ⑤ 的 watch）撞上子进程，于是 attempts 行如实记成 state=unknown、断言 state=idle
  # 假红（P18 B2、M34 复验两条实测）。`bash --noprofile --norc` 让“空提示符”变成**构造性**的：
  # 没有 rc、没有异步子进程、cwd 由 tmux 的 -c 钉在 $REPO。
  pmw_tmux new-window -t "$SESSION" -n "$PMW" -d -c "$REPO" bash --noprofile --norc >/dev/null 2>&1 || true
  # 旧实现轮询 pane_current_command + sleep 0.5；只采样一次 team_pm_state 也不够：
  # 窗口刚建好的一瞬间 pane 还没 exec 出前台命令，team_pm_state 会**假**报 idle（空 cmd），
  # 紧接着启动命令就把它变成 unknown:*（§11b3 ⑤ 的 attempts 行正是这么记错的；注入 1.2s 的
  # 启动命令后，在负载下这次假 idle 稳定复现）。判据：连续三次采样（间隔 0.5s，覆盖 ≥1s）都是
  # idle:*，且每次都看到前台命令是真正的 shell。
  local i=0 st="" cmd="" n=0
  while [ "$i" -lt 600 ]; do
    st="$(pm_state_now 2>/dev/null || true)"
    cmd="$(pmw_tmux display-message -p -t "$SESSION:$PMW" '#{pane_current_command}' 2>/dev/null || true)"
    case "$st" in idle:*)
      case "$cmd" in
        zsh|bash|sh|dash|ash|ksh|fish)
          n=$((n + 1))
          [ "$n" -ge 3 ] && { PM_STATE_LAST="$st"; return 0; } ;;
        *) n=0 ;;
      esac ;;
    *) n=0 ;;
    esac
    sleep 0.5
    i=$((i + 1))
  done
  PM_STATE_LAST="$st"
  bad "make_pm_idle：没等到窗口稳定在空提示符（上限 300s；最后状态 ${st:-?}，前台命令 [${cmd:-}]）"
}
