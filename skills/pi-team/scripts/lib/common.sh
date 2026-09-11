#!/usr/bin/env bash
# pi-team · 公共库：配置解析、路径推导、tmux/git 辅助、守卫。
# 由 scripts/team 与各 cmd-*.sh source；不要直接执行。
# 约定：所有函数名以 team_ 前缀；不依赖 jq / python / node。

TEAM_VERSION="1.7.2"

# ---------------------------------------------------------------- 输出
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'; C_CYA=$'\033[36m'
else
  C_RESET=; C_BOLD=; C_DIM=; C_RED=; C_GRN=; C_YEL=; C_CYA=
fi

team_info() { printf '%s\n' "$*"; }
team_ok()   { printf '%s✓%s %s\n' "$C_GRN" "$C_RESET" "$*"; }
team_warn() { printf '%s!%s %s\n' "$C_YEL" "$C_RESET" "$*" >&2; }
team_err()  { printf '%s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
team_die()  { team_err "$*"; exit 1; }
team_hdr()  { printf '%s%s%s\n' "$C_BOLD" "$*" "$C_RESET"; }
team_dim()  { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }

team_usage_die() { team_err "$*"; printf 'run: %s help\n' "$TEAM_CLI" >&2; exit 2; }

# ---------------------------------------------------------------- skill 目录
# 解析 symlink 链，得到 skill 根目录（无论本文件被 source 还是被 -e 加载）。
team_skill_dir() {
  local src="${BASH_SOURCE[0]}" dir root
  while [ -L "$src" ]; do
    dir="$(cd -P "$(dirname "$src")" && pwd)" || return 1
    src="$(readlink "$src")"
    case "$src" in /*) ;; *) src="$dir/$src" ;; esac
  done
  root="$(cd -P "$(dirname "$src")/../.." && pwd)" || return 1
  printf '%s\n' "$root"
}

# ---------------------------------------------------------------- git 路径
team_git() { command git -C "${TEAM_CWD:-$PWD}" "$@"; }
# 仓库级操作（worktree add/merge/push/branch）一律锚定主工作树，避免从 worktree 调用时作用域错位
team_git_main() { command git -C "$TEAM_MAIN_ROOT" "$@"; }

team_is_git_repo() { team_git rev-parse --show-toplevel >/dev/null 2>&1; }

# 当前工作树顶层（在 linked worktree 里就是那个 worktree）
team_worktree_top() { team_git rev-parse --show-toplevel 2>/dev/null; }

# 主工作树顶层（worktree 的 `.git` 文件指向主仓库的 .git 目录）
team_main_root() {
  local common d root
  common="$(team_git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 1
  [ -n "$common" ] || return 1
  d="$(dirname "$common")"
  root="$(cd "$d" && pwd)" || return 1
  printf '%s\n' "$root"
}

# ---------------------------------------------------------------- 配置
# 查找顺序：$TEAM_CONFIG_FILE → 从 $TEAM_ROOT/$PWD 向上找 .pi/team/config.sh
team_find_config() {
  if [ -n "${TEAM_CONFIG_FILE:-}" ]; then
    [ -f "$TEAM_CONFIG_FILE" ] && { printf '%s\n' "$TEAM_CONFIG_FILE"; return 0; }
    return 1
  fi
  local d="${TEAM_ROOT:-$PWD}"
  d="$(cd "$d" 2>/dev/null && pwd)" || return 1
  while :; do
    [ -f "$d/.pi/team/config.sh" ] && { printf '%s\n' "$d/.pi/team/config.sh"; return 0; }
    [ "$d" = "/" ] && break
    d="$(dirname "$d")"
  done
  return 1
}

# 载入配置 + 填默认值。TEAM_CWD 固定为调用时的工作目录（后续 cd 不影响 git 定位）。
team_load_config() {
  TEAM_CWD="${TEAM_CWD:-$PWD}"
  TEAM_SKILL_DIR="${TEAM_SKILL_DIR:-$(team_skill_dir)}"
  TEAM_CONFIG="$(team_find_config || true)"

  if [ -n "$TEAM_CONFIG" ]; then
    # 环境变量优先于配置文件：用户临时覆盖（TEAM_MIN_FREE_SWAP_MB=0 team dispatch …）
    # 必须能赢过文件里的值，否则文档里的“临时绕过”根本不生效。
    local _env_pairs=() _k
    for _k in ${!TEAM_@}; do
      case "$_k" in TEAM_CONFIG_FILE|TEAM_ASSUME_YES|TEAM_CLI) continue ;; esac
      _env_pairs+=("$_k=${!_k}")
    done
    set +u
    # shellcheck disable=SC1090
    . "$TEAM_CONFIG"
    set -u
    for _k in "${_env_pairs[@]:-}"; do
      [ -n "$_k" ] || continue
      printf -v "${_k%%=*}" '%s' "${_k#*=}"
    done
  fi

  team_is_git_repo || team_die "当前目录不在 git 仓库内（pi-team 需要 git 来做 worktree 隔离）"
  TEAM_ROOT="${TEAM_ROOT:-$(team_worktree_top)}"
  TEAM_MAIN_ROOT="${TEAM_MAIN_ROOT:-$(team_main_root)}"

  TEAM_PROJECT="${TEAM_PROJECT:-$(basename "$TEAM_MAIN_ROOT")}"
  TEAM_SESSION="${TEAM_SESSION:-$TEAM_PROJECT}"
  TEAM_PM_WINDOW="${TEAM_PM_WINDOW:-pm}"
  TEAM_DOCS_DIR="${TEAM_DOCS_DIR:-docs/team}"
  TEAM_WORKTREES_DIR="${TEAM_WORKTREES_DIR:-.worktrees}"
  TEAM_AGENT_BRANCH_PREFIX="${TEAM_AGENT_BRANCH_PREFIX:-agent}"
  TEAM_TASK_BRANCH_PREFIX="${TEAM_TASK_BRANCH_PREFIX:-task}"
  # 分支模型：task（默认，一任务一分支，复验/合并/回滚的单位都是任务）| agent（一 agent 一长期分支）
  TEAM_BRANCH_MODE="${TEAM_BRANCH_MODE:-task}"
  TEAM_TASK_BRANCH_RESET="${TEAM_TASK_BRANCH_RESET:-1}"     # close 后把 agent worktree 切回保护分支（task 模式）
  TEAM_PROTECTED_BRANCH="${TEAM_PROTECTED_BRANCH:-main}"
  TEAM_REMOTE="${TEAM_REMOTE:-origin}"
  TEAM_VCS="${TEAM_VCS:-local}"
  TEAM_TOKEN_FILE="${TEAM_TOKEN_FILE:-.gh-pat}"
  TEAM_GITLAB_HOST="${TEAM_GITLAB_HOST:-}"
  TEAM_GITLAB_PROJECT="${TEAM_GITLAB_PROJECT:-}"
  TEAM_GITLAB_TOKEN_FILE="${TEAM_GITLAB_TOKEN_FILE:-$HOME/.gitlab-pa-token}"
  TEAM_GATES="${TEAM_GATES:-}"
  TEAM_PI_BIN="${TEAM_PI_BIN:-pi}"
  TEAM_MEMINFO_FILE="${TEAM_MEMINFO_FILE:-}"
  TEAM_INSTALL_CMD="${TEAM_INSTALL_CMD:-}"
  TEAM_DEFAULT_MODEL="${TEAM_DEFAULT_MODEL:-deepseek/deepseek-flash}"
  # PM 自己的启动参数（team up / watchdog 用）
  TEAM_PM_MODEL="${TEAM_PM_MODEL:-}"          # 空 = 用 TEAM_DEFAULT_MODEL
  TEAM_PM_SESSION_ID="${TEAM_PM_SESSION_ID:-}" # 空 = 用 pi -c 延续本目录上一个会话（保住历史）
  TEAM_PM_EXTRA_PI_ARGS="${TEAM_PM_EXTRA_PI_ARGS:-}"
  # 模型并发上限：支持通配（如 openai-codex/*=1）。默认给低额度订阅留出安全边界。
  TEAM_MODEL_LIMITS="${TEAM_MODEL_LIMITS:-kimi-coding/k3=2 openai-codex/*=1}"
  # 容量硬线（zram 页存在 RAM 里，不能当并发额度；所以「磁盘 swap 空闲」单独算）
  TEAM_MIN_FREE_SWAP_MB="${TEAM_MIN_FREE_SWAP_MB:-1024}"    # 磁盘 swap 空闲底线（不含 zram）
  TEAM_MIN_AVAIL_MB="${TEAM_MIN_AVAIL_MB:-1024}"            # MemAvailable 底线（CEP 用的 4096）
  TEAM_ZRAM_WARN_PCT="${TEAM_ZRAM_WARN_PCT:-85}"            # zram 占用超过该百分比只警告
  TEAM_MIN_TOTAL_MB="${TEAM_MIN_TOTAL_MB:-512}"            # RAM+swap 的绝对底线
  TEAM_WARN_AVAIL_MB="${TEAM_WARN_AVAIL_MB:-2048}"         # RAM 低于此值：只警告（允许卡顿）
  TEAM_AGENT_MEM_MB="${TEAM_AGENT_MEM_MB:-6144}"           # 单个 agent 的经验占用（估算用）
  # 保活 watchdog
  # 定时巡检（叫醒 PM 的节拍；不是心跳保活）——默认 15 分钟，推荐 5~60 分钟
  TEAM_WATCH_INTERVAL="${TEAM_WATCH_INTERVAL:-900}"       # 巡检周期（秒）
  TEAM_WATCH_NUDGE_GAP="${TEAM_WATCH_NUDGE_GAP:-900}"      # 同一批待办最快多久再提醒一次（秒）
  TEAM_WATCH_MAX_RESTARTS="${TEAM_WATCH_MAX_RESTARTS:-5}"  # PM 每小时最多自动拉起次数（防崩溃循环）
  TEAM_WATCH_REBUILD_TMUX="${TEAM_WATCH_REBUILD_TMUX:-0}"  # 0=不管 tmux（session/窗口没了只告警）；1=允许重建 PM 窗口
  TEAM_WATCH_BACKEND="${TEAM_WATCH_BACKEND:-tmux}"         # tmux（默认：同 session 的窗口 + 状态面板）| container
  TEAM_WATCH_WINDOW="${TEAM_WATCH_WINDOW:-watchdog}"       # tmux 后端的窗口名
  TEAM_REVIEW_TIMEOUT="${TEAM_REVIEW_TIMEOUT:-1800}"       # team review 跑门禁的硬超时（秒）
  TEAM_MONITOR_REFRESH="${TEAM_MONITOR_REFRESH:-5}"        # 监视器刷新间隔（秒）
  TEAM_MONITOR_EVENTS="${TEAM_MONITOR_EVENTS:-4}"          # 打开活动流时，每个 agent 显示最近几条事件
  # 活动流（读各 agent 的 Pi 会话 JSONL）默认**关闭**：
  # 看门狗只服务当前 tmux session（窗口/任务/待办/容量）；翻别人的会话既吵又贵（几 MB/次 × 每几秒）。
  # 需要时显式打开：team monitor --activity 或 TEAM_MONITOR_ACTIVITY=1
  TEAM_MONITOR_ACTIVITY="${TEAM_MONITOR_ACTIVITY:-0}"
  # 看板里的 todo/wip 算不算“要叫醒 PM 的活”：默认不算（backlog 长期存在，不该每 15 分钟敲一次）；
  # blocked / 未读通知 / 待复验 / 停了的 agent 仍然算。想连 backlog 一起提醒就设 1。
  TEAM_WATCH_PENDING_BOARD="${TEAM_WATCH_PENDING_BOARD:-0}"
  TEAM_WATCH_IMAGE="${TEAM_WATCH_IMAGE:-}"                 # 看门狗容器镜像，空=localhost/pi-team-watch:1
  TEAM_WATCH_BOX="${TEAM_WATCH_BOX:-}"                     # 目标开发容器名，空=自动（当前容器）
  TEAM_WATCH_RETRY_SEC="${TEAM_WATCH_RETRY_SEC:-15}"       # 内层 watch 退出后的重试间隔（秒）
  TEAM_WATCH_PID_MODE="${TEAM_WATCH_PID_MODE:-}"           # 空=自动（容器内 --pid=container:<当前容器>；裸机 --pid=host）
  TEAM_WATCH_CONTAINER="${TEAM_WATCH_CONTAINER:-}"         # 空=<project>-pi-team-watch
  TEAM_PM_START_WAIT="${TEAM_PM_START_WAIT:-6}"            # 启动 PM 后等它起来的秒数
  TEAM_NOTIFY_TMUX="${TEAM_NOTIFY_TMUX:-1}"
  TEAM_NOTIFY_DEDUP_SEC="${TEAM_NOTIFY_DEDUP_SEC:-20}"
  TEAM_NOTIFY_LOG="${TEAM_NOTIFY_LOG:-/tmp/pi-team-notify.log}"
  TEAM_INBOX_IN_MAIN="${TEAM_INBOX_IN_MAIN:-1}"
  TEAM_INBOX_MAX_CHARS="${TEAM_INBOX_MAX_CHARS:-150}"
  TEAM_CONFIRM_WRITES="${TEAM_CONFIRM_WRITES:-1}"
  TEAM_AGENTS="${TEAM_AGENTS:-}"
  TEAM_AGENT_MODELS="${TEAM_AGENT_MODELS:-}"
  TEAM_EXTRA_PI_ARGS="${TEAM_EXTRA_PI_ARGS:-}"

  TEAM_DOCS_ABS="$TEAM_MAIN_ROOT/$TEAM_DOCS_DIR"
  TEAM_STATE_DIR="$TEAM_MAIN_ROOT/.pi/team/state"
  TEAM_CLI="${TEAM_CLI:-team}"
}

team_docs_abs() { printf '%s\n' "$TEAM_DOCS_ABS"; }
team_inbox_dir() { printf '%s\n' "$TEAM_DOCS_ABS/inbox"; }

# 找报告：主工作树 → 各 agent worktree → 复验 worktree（报告提交在 agent 分支上，
# 合并前不会出现在主工作树，所以不能只看主工作树）
team_find_report() { # <ID> → 路径（无则返回 1）
  local id="$1" f a wt
  for f in "$TEAM_DOCS_ABS/reports/$id-"*.md; do [ -f "$f" ] && { printf '%s\n' "$f"; return 0; }; done
  for a in $(team_agents); do
    wt="$(team_agent_worktree "$a")"; [ -d "$wt" ] || continue
    for f in "$wt/$TEAM_DOCS_DIR/reports/$id-"*.md; do [ -f "$f" ] && { printf '%s\n' "$f"; return 0; }; done
  done
  for f in "$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR/review-$id/$TEAM_DOCS_DIR/reports/$id-"*.md; do
    [ -f "$f" ] && { printf '%s\n' "$f"; return 0; }
  done
  return 1
}
team_agent_worktree() { printf '%s\n' "$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR/$1"; }
team_agent_branch() { printf '%s\n' "$TEAM_AGENT_BRANCH_PREFIX/$1"; }

team_branch_slug() { # <文本> → 分支名用的 slug（非 ASCII 直接退化为空）
  printf '%s' "$1" | tr 'A-Z' 'a-z' | sed -e 's/[^a-z0-9]\+/-/g' -e 's/^-\+//' -e 's/-\+$//' | cut -c1-28
}

team_task_branch_for_id() { # <ID> [title] → task/<ID>-<slug>
  local id="$1" title="${2:-}" slug
  [ -n "$title" ] || title="$(team_task_title "$id" 2>/dev/null || true)"
  slug="$(team_branch_slug "$title")"
  [ -n "$slug" ] || slug="$(team_branch_slug "$id")"
  printf '%s/%s-%s\n' "$TEAM_TASK_BRANCH_PREFIX" "$id" "${slug:-task}"
}

team_branch_mode_is_task() { [ "${TEAM_BRANCH_MODE:-task}" = "task" ]; }

team_branch_for_agent() { # <agent> <ID> → 该 agent 在这个任务上应该用的分支名
  if team_branch_mode_is_task; then team_task_branch_for_id "$2"
  else team_agent_branch "$1"; fi
}

# 输出一份「可直接写进派单提示词」的路径清单
team_paths_json() {
  printf '{ "project": "%s", "main_root": "%s", "worktree": "%s", "docs": "%s", "worktrees": "%s", "session": "%s", "pm_window": "%s" }\n' \
    "$TEAM_PROJECT" "$TEAM_MAIN_ROOT" "$TEAM_ROOT" "$TEAM_DOCS_ABS" "$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR" "$TEAM_SESSION" "$TEAM_PM_WINDOW"
}

# 能直接 import .ts 的运行时（node 需启用类型剥离，否则用 bun/tsx）
team_ts_runner() {
  if team_have_cmd node && node -e 'process.exit(process.features.typescript?0:1)' >/dev/null 2>&1; then
    printf 'node'
  elif team_have_cmd bun; then
    printf 'bun'
  elif team_have_cmd tsx; then
    printf 'tsx'
  fi
}

# ---------------------------------------------------------------- 小工具
team_slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/[^a-z0-9]\+/-/g' -e 's/^-//' -e 's/-$//' | cut -c1-48
}

team_hash() { printf '%s' "$1" | cksum | awk '{print $1}'; }

team_require_cmd() {
  command -v "$1" >/dev/null 2>&1 || team_die "缺少命令：$1（$2）"
}

team_have_cmd() { command -v "$1" >/dev/null 2>&1; }

team_agents() {
  # 名册：TEAM_AGENTS 空格分隔；也兼容换行
  local a
  for a in $(printf '%s' "$TEAM_AGENTS" | tr '\n\t' '  '); do
    [ -n "$a" ] && printf '%s\n' "$a"
  done
}

team_agent_known() {
  local a
  for a in $(team_agents); do [ "$a" = "$1" ] && return 0; done
  return 1
}

team_agent_model() {
  local want="$1" pair
  for pair in $(printf '%s' "$TEAM_AGENT_MODELS" | tr '\n\t' '  '); do
    case "$pair" in
      "$want"=*) printf '%s\n' "${pair#*=}"; return 0 ;;
    esac
  done
  printf '%s\n' "$TEAM_DEFAULT_MODEL"
}

team_require_agent() {
  team_agent_known "$1" || team_die "未知 agent：$1（名册：$(team_agents | tr '\n' ' ')）"
}

# ---------------------------------------------------------------- 状态（PM 的仪表盘）
team_state_dir() { mkdir -p "$TEAM_STATE_DIR"; printf '%s\n' "$TEAM_STATE_DIR"; }

team_state_set() { # <agent> <key> <value>
  local dir; dir="$(team_state_dir)"
  local k esc
  esc="$(printf '%s' "$3" | sed -e 's/[&\\|]/\\&/g')"
  k="$(grep -s "^$2=" "$dir/$1.env" 2>/dev/null | head -1 | cut -d= -f1 || true)"
  if [ -n "$k" ]; then
    sed -i "s|^$2=.*|$2=$esc|" "$dir/$1.env"
  else
    printf '%s=%s\n' "$2" "$3" >> "$dir/$1.env"
  fi
}

team_state_get() { # <agent> <key> [default]
  local f="$TEAM_STATE_DIR/$1.env" v=""
  if [ -f "$f" ]; then
    v="$(grep -s "^$2=" "$f" | head -1 | cut -d= -f2- || true)"
  fi
  if [ -n "$v" ]; then printf '%s\n' "$v"
  elif [ $# -ge 3 ]; then printf '%s\n' "$3"
  else printf '\n'
  fi
  return 0
}

team_state_clear() { rm -f "$TEAM_STATE_DIR/$1.env"; }

# ---------------------------------------------------------------- tmux
team_tmux_enabled() { [ "$TEAM_NOTIFY_TMUX" = "1" ] && team_have_cmd tmux && [ -n "${TMUX:-}" ]; }

team_tmux_has_session() { tmux has-session -t "$1" 2>/dev/null; }

team_tmux_windows() { tmux list-windows -t "$1" -F '#{window_name}' 2>/dev/null; }

team_tmux_has_window() { team_tmux_windows "$1" | grep -qx "$2"; }

team_tmux_ensure_session() {
  team_tmux_has_session "$TEAM_SESSION" && return 0
  tmux new-session -d -s "$TEAM_SESSION" -n "$TEAM_PM_WINDOW" 2>/dev/null || true
}

team_tmux_send_text() { # <session:window> <text>
  tmux send-keys -t "$1" -l "$2" 2>/dev/null || return 1
  tmux send-keys -t "$1" Enter 2>/dev/null || return 1
}

# 只有目标窗口在跑 pi 时才敢打字：往停在提示符的 shell 里 send-keys 等于把那串文本
# 当命令执行（真实事故）。这种情况只写收件箱，不敲键盘。
team_tmux_send_to_pi() { # <session:window> <text>
  team_pane_busy "$1" || return 1
  team_tmux_send_text "$1" "$2"
}

team_pane_cmd() { # <session:window> → 前台命令名
  tmux display-message -p -t "$1" '#{pane_current_command}' 2>/dev/null || true
}

team_is_shell_cmd() { # 空/常见 shell → 窗口可能停在提示符，也可能是 shell 脚本在跑（需再查子进程）
  case "${1:-}" in
    bash|sh|zsh|fish|dash|ash|ksh|nu|elvish|'') return 0 ;;
    *) return 1 ;;
  esac
}

# pane 里是否有东西在跑（≠ 空提示符）。
# 为什么不能只看 pane_current_command：pi 若用 shell wrapper 启动（或自测用假 pi 脚本），
# 前台名会显示 bash。为什么不能只看“shell 有子进程”：用户 rc 钩子（如 conda shell hook）
# 会常驻一个子进程，导致空提示符被误判成忙。所以看三点：
#   1) 前台不是 shell → 在跑
#   2) pane_pid 的命令行里有非选项参数（shell 在跑脚本/子命令）→ 在跑
#   3) 前台进程组不是 pane_pid 自己（job control：子命令被放到新进程组）→ 在跑
team_shell_running_command() { # <pid> → 0 表示这个 shell 进程在跑脚本/子命令
  local args toks=() tok
  args="$(ps -o args= -p "$1" 2>/dev/null | head -1)"
  [ -n "$args" ] || return 1
  read -r -a toks <<< "$args"
  local i=1
  while [ "$i" -lt "${#toks[@]}" ]; do
    tok="${toks[$i]}"
    case "$tok" in
      -*) ;;
      *) return 0 ;;
    esac
    i=$((i + 1))
  done
  return 1
}

team_pgroup_has_process() { # <pgid> → 0 表示这个进程组里还有活进程
  local g="${1:-}"
  [ -n "$g" ] || return 1
  if team_have_cmd ps; then
    [ -n "$(ps -eo pgid=,pid= 2>/dev/null | awk -v g="$g" '$1==g {print $2; exit}')" ] && return 0
  fi
  if team_have_cmd pgrep; then
    [ -n "$(pgrep -g "$g" 2>/dev/null | head -1)" ] && return 0
  fi
  return 1
}

team_pane_busy() { # <session:window> → 0 = 里面有东西在跑
  local target="$1" cmd pid tpgid
  cmd="$(team_pane_cmd "$target")"
  team_is_shell_cmd "$cmd" || return 0
  pid="$(tmux display-message -p -t "$target" '#{pane_pid}' 2>/dev/null)"
  [ -n "$pid" ] || return 1
  team_shell_running_command "$pid" && return 0
  tpgid="$(ps -o tpgid= -p "$pid" 2>/dev/null | tr -d ' ')"
  if [ -n "$tpgid" ] && [ "$tpgid" != "$pid" ]; then
    # 前台进程组不是 shell 自己，但那个组得真有活进程才算“忙”——
    # 刚被杀掉的命令会留下陈旧的 tpgid，不排除掉会误判成“还在跑”。
    team_pgroup_has_process "$tpgid" && return 0
  fi
  return 1
}

# ---------------------------------------------------------------- PM 存活
team_pm_target() { printf '%s:%s\n' "$TEAM_SESSION" "$TEAM_PM_WINDOW"; }

team_pm_window_exists() { team_tmux_has_window "$TEAM_SESSION" "$TEAM_PM_WINDOW"; }

# missing | idle:<cmd> | busy:<cmd> | running:<cmd>
#   running = 前台不是 shell（pi 本体）
#   busy    = 前台是 shell 但有子进程（pi 是 shell wrapper 时就是这个；也包含用户在跑别的命令）
#   idle    = 空提示符（可以安全地替成 pi）
team_pm_state() {
  team_pm_window_exists || { printf 'missing'; return 0; }
  local cmd; cmd="$(team_pane_cmd "$(team_pm_target)")"
  if ! team_is_shell_cmd "$cmd"; then printf 'running:%s' "$cmd"; return 0; fi
  if team_pane_busy "$(team_pm_target)"; then printf 'busy:%s' "${cmd:-shell}"; return 0; fi
  printf 'idle:%s' "${cmd:-shell}"
}

team_pm_alive() {
  case "$(team_pm_state)" in running:*|busy:*) return 0 ;; *) return 1 ;; esac
}

team_pm_prompt() { # PM 开场/恢复提示词（模板在 skill 内，可随 skill 升级）
  local tmpl="$TEAM_SKILL_DIR/templates/pm-prompt.md.tmpl"
  if [ ! -f "$tmpl" ]; then
    printf '你是 %s 的 PM。工具：bash %s/scripts/team help；开局先跑 `team digest` 与 `team inbox --ack`，再继续调度。\n' \
      "$TEAM_PROJECT" "$TEAM_SKILL_DIR"
    return 0
  fi
  team_render "$tmpl" \
    "PROJECT=$TEAM_PROJECT" "MAIN_ROOT=$TEAM_MAIN_ROOT" "SKILL_DIR=$TEAM_SKILL_DIR" \
    "DOCS_DIR=$TEAM_DOCS_DIR" "SESSION=$TEAM_SESSION" "PM_WINDOW=$TEAM_PM_WINDOW" \
    "AGENTS=$(team_agents | tr '\n' ' ')" "GATES=${TEAM_GATES:-<未配置>}" \
    "PROTECTED_BRANCH=$TEAM_PROTECTED_BRANCH" "WORKTREES_DIR=$TEAM_WORKTREES_DIR"
}

team_pm_pi_args() { # PM 不加载 notify 扩展（它就是收件人）；默认 -c 延续本目录上一个会话以保住历史
  local model="${TEAM_PM_MODEL:-$TEAM_DEFAULT_MODEL}" args=()
  args=(--provider "${model%%/*}" --model "${model##*/}")
  [ -d "$TEAM_SKILL_DIR" ] && args+=(--skill "$TEAM_SKILL_DIR")
  if [ -n "${TEAM_PM_SESSION_ID:-}" ]; then args+=(--session-id "$TEAM_PM_SESSION_ID")
  else args+=(-c); fi
  [ -n "${TEAM_PM_EXTRA_PI_ARGS:-}" ] && args+=($TEAM_PM_EXTRA_PI_ARGS)
  printf '%q ' "${args[@]}"
}

# 启动命令里不把提示词直接塞进命令行：一行命令太长会被 TTY 的 4096 字节规范输入限制截断。
# 改成写文件 + `pi @file`（pi 支持 @file 作为初始消息），命令行保持短。
team_pm_prompt_file() { printf '%s\n' "$TEAM_STATE_DIR/pm-prompt.md"; }

team_pm_write_prompt() {
  mkdir -p "$TEAM_STATE_DIR"
  team_pm_prompt > "$(team_pm_prompt_file)"
  printf '%s\n' "$(team_pm_prompt_file)"
}

# 在 PM 窗口启动 PM。
# 用 respawn-pane 把 pane 的进程直接换成我们的命令，而不是把命令“打字”进去：
#   - 打字受 TTY 行长限制（4KB）和 shell wrapper/rc 钩子/按键时序影响，不可靠；
#   - respawn 是确定性的：同一个 pane，命令就是我们要的。
# 只在 pane 里没有东西在跑（idle/missing）时才 respawn；busy/running 一律不抢。
team_pm_start() {
  local target state cmd pf i wait
  target="$(team_pm_target)"
  team_pm_window_exists || return 1
  state="$(team_pm_state)"
  case "$state" in
    running:*) team_dim "  PM 已在运行（${state#running:}）"; return 0 ;;
    busy:*)    team_dim "  PM 窗口里有进程在跑（${state#busy:}）：不动它"
               return 1 ;;
    idle:*)    ;;
    *)         team_warn "PM 窗口状态异常（$state），不重启；处理完再跑 team up"; return 1 ;;
  esac
  pf="$(team_pm_write_prompt)"
  cmd="$(printf 'cd %q && exec %q %s @%q' "$TEAM_MAIN_ROOT" "$TEAM_PI_BIN" "$(team_pm_pi_args)" "$pf")"
  tmux respawn-pane -k -t "$target" "$cmd" >/dev/null 2>&1 || {
    team_err "respawn-pane 失败：$target"
    return 1
  }
  wait="${TEAM_PM_START_WAIT:-6}"
  i=0
  while [ "$i" -lt "$wait" ]; do
    [ "${i}" -gt 0 ] && sleep 1
    team_pm_alive && return 0
    i=$((i + 1))
  done
  team_err "PM 启动后 ${wait}s 内没看到 pi 在跑：检查窗口输出与 $pf"
  return 1
}

# 重启配额：防止 PM 反复崩溃把机器打爆（1 小时内最多 TEAM_WATCH_MAX_RESTARTS 次）
team_pm_can_restart() {
  local log="$TEAM_STATE_DIR/pm-restarts.log" now win max n
  now="$(date +%s)"; win=3600; max="${TEAM_WATCH_MAX_RESTARTS:-5}"
  mkdir -p "$TEAM_STATE_DIR"
  if [ -f "$log" ]; then
    n="$(awk -v now="$now" -v win="$win" '$1 > now - win' "$log" | wc -l | tr -d ' ')"
    if [ "$n" -ge "$max" ]; then
      team_err "PM 在 1 小时内已被重启 $n 次（上限 $max）：先排查崩溃原因（state/watchdog.log、PM 窗口输出）"
      return 1
    fi
  fi
  printf '%s %s\n' "$now" "$(team_timestamp)" >> "$log"
  return 0
}

# ---------------------------------------------------------------- 门禁
# 内存守卫（底线 = 不把 RAM/zram 一起打满）：
#   swap 见底 → 拒绝派单（一打满就会被 OOM killer 杀进程，连带 PM 一起挂）
#   RAM 紧张 → 只警告，允许继续（代价是卡顿，不是崩）
# 数据源：TEAM_MEMINFO_FILE（测试/容器显式覆盖）> /proc/meminfo > macOS sysctl > free
# 输出 "avail_mb swap_free_mb swap_total_mb"
team_mem_stats() {
  local f="${TEAM_MEMINFO_FILE:-/proc/meminfo}"
  if [ -r "$f" ] && grep -q '^MemTotal' "$f" 2>/dev/null; then
    awk '/^MemAvailable/{a=$2} /^MemFree/{if(a=="")a=$2} /^SwapFree/{s=$2} /^SwapTotal/{t=$2}
         END{printf "%d %d %d\n", a/1024, s/1024, t/1024}' "$f"
    return 0
  fi
  if team_have_cmd sysctl; then   # macOS
    local avail swap
    avail="$(vm_stat 2>/dev/null | awk '/page size/ {ps=$8} /Pages free/ {gsub(/\./,"",$3); printf "%d", $3*ps/1048576}')"
    swap="$(sysctl -n vm.swapusage 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="free"){gsub(/M/,"",$(i+2)); print $(i+2)}}')"
    [ -n "$avail" ] && { printf '%s %s 0\n' "$avail" "${swap:-0}"; return 0; }
  fi
  if team_have_cmd free; then
    free -m | awk '/^Mem:/{a=$7} /^Swap:/{s=$4; t=$2} END{printf "%d %d %d\n", a, s, t}'
    return 0
  fi
  printf '0 0 0\n'
}

team_available_mb() { team_mem_stats | awk '{print $1}'; }
team_swap_free_mb() { team_mem_stats | awk '{print $2}'; }

# zram / 磁盘 swap 分账（CEP 的教训：zram 的页存在 RAM 里，空闲 swap 里混着被压缩的 RAM）
# 输出 "disk_free disk_total zram_used_pct zram_phys_mb"
team_swap_breakdown() {
  local swapfile="${TEAM_SWAPFILE_PATH:-/proc/swaps}"
  local zram_used=0 zram_total=0 zram_pct=0 zram_phys=0
  local disk_free=0 disk_total=0
  if [ -r "$swapfile" ]; then
    # 逐行看 /proc/swaps：Filename Type Size Used Priority
    while read -r dev type size used prio; do
      case "$dev" in Filename*) continue ;; esac
      # /proc/swaps 的单位是 KB → 统一换成 MB
      size=$((size / 1024)); used=$((used / 1024))
      case "$dev" in
        /dev/zram*) zram_used=$((zram_used + used)); zram_total=$((zram_total + size)) ;;
        *) disk_free=$((disk_free + size - used)); disk_total=$((disk_total + size)) ;;
      esac
    done < "$swapfile"
  fi
  [ "$zram_total" -gt 0 ] && zram_pct=$((zram_used * 100 / zram_total))
  # zram 物理占用（mm_stat 的 mem_used，优先原值 mem_used，其次 mem_used_total）
  local d mm
  for d in /sys/block/zram*/mm_stat; do
    [ -r "$d" ] || continue
    mm="$(awk '{for(i=1;i<=NF;i++) if ($i ~ /^mem_used/) {print $(i+1); exit}}' "$d" 2>/dev/null || true)"
    if [ -n "$mm" ] && [ "$mm" -gt 0 ] 2>/dev/null; then zram_phys=$((zram_phys + mm / 1048576))
    else
      mm="$(awk '{print $3}' "$d" 2>/dev/null || true)"
      [ -n "$mm" ] && [ "$mm" -gt 0 ] 2>/dev/null && zram_phys=$((zram_phys + mm / 1048576))
    fi
  done
  printf '%s %s %s %s\n' "$disk_free" "$disk_total" "$zram_pct" "$zram_phys"
}

team_mem_guard() {
  local avail swapfree swaptotal min_swap min_total warn_avail min_avail zram_warn
  read -r avail swapfree swaptotal <<< "$(team_mem_stats)"
  local diskfree disktotal zram_pct zram_phys
  read -r diskfree disktotal zram_pct zram_phys <<< "$(team_swap_breakdown)"
  min_swap="${TEAM_MIN_FREE_SWAP_MB:-1024}"
  min_total="${TEAM_MIN_TOTAL_MB:-512}"
  warn_avail="${TEAM_WARN_AVAIL_MB:-4096}"
  min_avail="${TEAM_MIN_AVAIL_MB:-1024}"
  zram_warn="${TEAM_ZRAM_WARN_PCT:-85}"
  [ -n "$avail" ] || return 0

  # 硬线 ①：MemAvailable（zram 里的页也算在 RAM 里，所以这条最能反映真实余量）
  if [ "$min_avail" -gt 0 ] && [ "$avail" -lt "$min_avail" ]; then
    team_err "MemAvailable 只剩 ${avail}MB（底线 ${min_avail}MB）：拒绝派单（机上有 zram=${zram_pct}%）"
    team_err "处理：等一个 agent 结束；或显式冒险 TEAM_MIN_AVAIL_MB=0 team dispatch …"
    return 1
  fi
  # 硬线 ②：磁盘 swap 空闲（**不计 zram** —— zram 占的是 RAM，不是安全网）
  if [ "$disktotal" -gt 0 ] && [ "$min_swap" -gt 0 ] && [ "$diskfree" -lt "$min_swap" ]; then
    team_err "磁盘 swap 只剩 ${diskfree}MB（底线 ${min_swap}MB，不计 zram）：拒绝派单"
    return 1
  fi
  # 硬线 ③：RAM + 磁盘 swap 的总余量
  if [ "$min_total" -gt 0 ] && [ "$((avail + diskfree))" -lt "$min_total" ]; then
    team_err "MemAvailable + 磁盘 swap 空闲仅 $((avail + diskfree))MB < 底线 ${min_total}MB，拒绝派单"
    return 1
  fi
  if [ "$warn_avail" -gt 0 ] && [ "$avail" -lt "$warn_avail" ]; then
    team_warn "MemAvailable ${avail}MB < ${warn_avail}MB：新 agent 会开始吃 swap/zram，机器会变卡（允许，继续）"
  fi
  if [ "$zram_warn" -gt 0 ] && [ "$zram_pct" -ge "$zram_warn" ]; then
    team_warn "zram 已用 ${zram_pct}%（≥${zram_warn}%，物理 ${zram_phys}MB 压在 RAM 里）：zram 满后基本常满，注意 RAM"
  fi
  return 0
}

# 粗略估算还能再加几个 agent（team ps 显示用；TEAM_AGENT_MEM_MB 是经验值）
team_agent_capacity() {
  local avail swapfree per min_total n diskfree
  read -r avail swapfree _ <<< "$(team_mem_stats)"
  read -r diskfree _ _ _ <<< "$(team_swap_breakdown)"
  swapfree="$diskfree"   # 只把磁盘 swap 当余量
  per="${TEAM_AGENT_MEM_MB:-6144}"; min_total="${TEAM_MIN_TOTAL_MB:-512}"
  [ "$per" -gt 0 ] || { printf '?'; return 0; }
  n=$(( (avail + swapfree - min_total) / per ))
  [ "$n" -lt 0 ] && n=0
  printf '%s' "$n"
}

team_capacity_line() {
  local avail swapfree swaptotal diskfree disktotal zram_pct zram_phys
  read -r avail swapfree swaptotal <<< "$(team_mem_stats)"
  read -r diskfree disktotal zram_pct zram_phys <<< "$(team_swap_breakdown)"
  local zram_note=""
  [ "$zram_pct" -gt 0 ] && zram_note="，zram 用 ${zram_pct}%${zram_phys:+/物理 ${zram_phys}MB}"
  printf 'RAM 可用 %sMB%s ｜ 磁盘 swap 空闲 %sMB%s ｜ 估算可再加 %s 个 agent\n' \
    "$avail" "" "${diskfree}" "$zram_note" "$(team_agent_capacity)"
}

# ---------------------------------------------------------------- 巡检待办
# “有没有值得把 PM 叫醒的事”——只统计团队需要 PM 处理的事，
# 不把 watchdog 自己写的记录算进去（否则会造成“自己叫醒自己”的循环）。
# 报告算不算“待复验”：必须像一份**任务**报告 ——
#   ① 文件名前缀是任务 ID，且 ② 该 ID 在 BOARD 里有行（或 docs/<docs>/tasks/<ID>-*.md 存在）
# 这样 PM 自己的里程碑/结项报告（reports/P2-closure.md 之类）不会被一直当成待复验。
team_report_is_task() { # <file> <id>
  local f="$1" id="$2"
  [ -n "$id" ] || return 1
  case "$id" in _*|.*) return 1 ;; esac
  case "$(basename "$f")" in
    *-closure*|*-summary*|*-milestone*|*closure-*|*summary-*) return 1 ;;
  esac
  # 标题必须是 "# <ID> · …"（ID 打头），否则视为非任务报告
  sed -n '1{/^#[[:space:]]/p}' "$f" | grep -qE "^#[[:space:]]+$id([[:space:]]|·|:|$)" || return 1
  if team_board_row "$id" >/dev/null 2>&1; then return 0; fi
  local t
  for t in "$TEAM_DOCS_ABS/tasks/$id-"*.md; do [ -f "$t" ] && return 0; done
  return 1
}

team_reports_pending_list() { # → 每行 "<显示名>\t<路径>"，只列**真任务**报告（主工作树 + 各 agent worktree）
  local glob base id ids=" "
  for glob in "$TEAM_DOCS_ABS/reports/"*.md "$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR"/*/"$TEAM_DOCS_DIR"/reports/*.md; do
    [ -f "$glob" ] || continue
    base="$(basename "$glob" .md)"; id="${base%%-*}"
    [ -f "$TEAM_DOCS_ABS/reviews/$id.md" ] && continue
    case "$ids" in *" $id "*) continue ;; esac
    team_report_is_task "$glob" "$id" || continue
    ids="$ids$id "
    printf '%s\t%s\n' "$base" "$glob"
  done
}

team_reports_pending() { # 报告已交但未复验的**任务**数
  team_reports_pending_list | wc -l | tr -d ' '
}

team_reports_ignored() { # 被上面规则排除掉的报告（供 digest 提示，不静默丢）
  local f base id glob
  for glob in "$TEAM_DOCS_ABS/reports/"*.md; do
    [ -f "$glob" ] || continue
    base="$(basename "$glob" .md)"; id="${base%%-*}"
    [ -f "$TEAM_DOCS_ABS/reviews/$id.md" ] && continue
    team_report_is_task "$glob" "$id" || printf '%s\n' "$(basename "$glob")"
  done
}

team_board_counts() { # → "todo wip review blocked"
  local f="$TEAM_DOCS_ABS/BOARD.md"
  [ -f "$f" ] || { printf '0 0 0 0\n'; return 0; }
  awk -F'|' -v sc="$(team_board_col status)" 'NF>2 { st=$(sc); gsub(/^[ \t]+|[ \t]+$/, "", st);
      if (st=="todo") t++; else if (st=="wip") w++; else if (st=="review") r++; else if (st=="blocked") b++ }
    END { printf "%d %d %d %d\n", t+0, w+0, r+0, b+0 }' "$f"
}

team_pending_counts() { # → "inbox reports todo wip review blocked stopped"
  local a n inbox=0 stopped=0 task
  for a in $(team_agents); do
    n="$(team_inbox_new "$a")"; inbox=$((inbox + n))
    task="$(team_state_get "$a" task '')"
    if [ -n "$task" ] && ! team_agent_live "$a"; then stopped=$((stopped + 1)); fi
  done
  local bc; bc="$(team_board_counts)"
  local todo wip review blocked; read -r todo wip review blocked <<< "$bc"
  if [ "${TEAM_WATCH_PENDING_BOARD:-0}" != "1" ]; then
    # 只保留“现在就等 PM 处理”的信号：todo/wip/review 列仍会在面板与 digest 里显示
    todo=0; wip=0; review=0
  fi
  printf '%s %s %s %s %s %s %s\n' "$inbox" "$(team_reports_pending)" "$todo" "$wip" "$review" "$blocked" "$stopped"
}

team_pending_text() { # <counts> → 人类可读摘要（空字符串 = 无待办）
  local inbox reports todo wip review blocked stopped
  read -r inbox reports todo wip review blocked stopped <<< "${1:-$(team_pending_counts)}"
  local parts=()
  [ "$inbox" -gt 0 ] && parts+=("未读通知 ${inbox}")
  [ "$reports" -gt 0 ] && parts+=("待复验 ${reports}")
  [ "$todo" -gt 0 ] && parts+=("todo ${todo}")
  [ "$wip" -gt 0 ] && parts+=("wip ${wip}")
  [ "$review" -gt 0 ] && parts+=("review ${review}")
  [ "$blocked" -gt 0 ] && parts+=("blocked ${blocked}" "需 PM 处理")
  [ "$stopped" -gt 0 ] && parts+=("停了的 agent ${stopped}")
  [ "${#parts[@]}" -eq 0 ] && return 0
  local out="" p
  for p in "${parts[@]}"; do out="${out}${out:+ · }$p"; done
  printf '%s\n' "$out"
}

team_pending_sig() { team_hash "${1:-$(team_pending_counts)}"; }

# ---------------------------------------------------------------- 待命（PM 主动停工）
team_standby_file() { printf '%s\n' "$TEAM_STATE_DIR/standby"; }
team_standby_on() { # <reason>
  mkdir -p "$TEAM_STATE_DIR"
  printf '%s %s\n' "$(team_timestamp)" "${1:--}" > "$(team_standby_file)"
}
team_standby_off() { rm -f "$(team_standby_file)"; }
team_standby_reason() {
  local f; f="$(team_standby_file)"
  [ -f "$f" ] || return 1
  sed -n '1p' "$f" | cut -d' ' -f2-
}
team_in_standby() { [ -f "$(team_standby_file)" ]; }

# 提醒（叫醒）PM：只写记录 + 尽力敲一下窗口，不靠它保证送达
team_nudge() { # <摘要文本>
  local text="$1" msg
  mkdir -p "$TEAM_STATE_DIR"
  printf '%s %s\n' "$(team_timestamp)" "$text" >> "$TEAM_STATE_DIR/nudges.log"
  printf '%s %s\n' "$(date +%s)" "$(team_pending_sig)" > "$TEAM_STATE_DIR/watchdog.nudge"
  msg="[watchdog] 待办：$text → 跑 $TEAM_CLI digest 看详情；若确实没活可推或需人工介入，跑 $TEAM_CLI standby on --reason \"…\" 让自己停下（之后不会再叫醒你）"
  if team_pm_alive; then team_tmux_send_to_pi "$(team_pm_target)" "$msg" >/dev/null 2>&1 || true; fi
  return 0
}

# 模型并发守卫：TEAM_MODEL_LIMITS="kimi-coding/k3=2 openai-codex/gpt-5.6-sol=1"
team_model_limit() {
  local want="$1" pair pat
  local best=0
  for pair in $(printf '%s' "$TEAM_MODEL_LIMITS" | tr '\n\t' '  '); do
    case "$pair" in *=*) ;; *) continue ;; esac
    pat="${pair%=*}"
    case "$want" in
      "$pat") printf '%s\n' "${pair#*=}"; return 0 ;;     # 精确匹配优先
    esac
    # 通配（openai-codex/*=1 这种）：取满足的最严格（最小）上限
    case "$want" in
      $pat)
        if [ "$best" -eq 0 ] || [ "${pair#*=}" -lt "$best" ]; then best="${pair#*=}"; fi ;;
    esac
  done
  printf '%s\n' "$best"
}

team_model_running() { # 统计「活着且用了该模型」的 agent 数（支持通配上限的归组统计）
  local want="$1" n=0 a w m
  for a in $(team_agents); do
    m="$(team_state_get "$a" model '')"
    if [ "$m" != "$want" ]; then
      # 同一个通配上限下的其它模型也算进并发（例如 openai-codex/* = 1）
      local pat; pat="$(team_model_limit_pattern_for "$want")"
      [ -n "$pat" ] && [ "$pat" != "$want" ] || continue
      case "$m" in $pat) ;; *) continue ;; esac
    fi
    w="$(team_state_get "$a" window "$a")"
    if team_tmux_has_window "$TEAM_SESSION" "$w"; then n=$((n + 1)); else team_state_clear "$a"; fi
  done
  printf '%s\n' "$n"
}

team_model_limit_pattern_for() { # <model> → 命中的通配模式（没有则是空）
  local want="$1" pair pat
  for pair in $(printf '%s' "$TEAM_MODEL_LIMITS" | tr '\n\t' '  '); do
    case "$pair" in *=*) ;; *) continue ;; esac
    pat="${pair%=*}"
    case "$pat" in *\**) ;; *) continue ;; esac
    case "$want" in $pat) printf '%s\n' "$pat"; return 0 ;; esac
  done
  return 1
}

team_model_guard() {
  local model="$1" limit running
  limit="$(team_model_limit "$model")"
  [ "$limit" -le 0 ] && return 0
  running="$(team_model_running "$model")"
  if [ "$running" -ge "$limit" ]; then
    team_err "模型 ${model} 并发上限 ${limit}，当前已运行 ${running} 个，拒绝派单"
    team_err "空闲后重试，或临时放宽：TEAM_MODEL_LIMITS=\"\" team dispatch ..."
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------- 写操作确认
# 所有改变远端/共享状态的操作都必须 --yes（用户显式授权），skill 不替用户做主。
team_allow_write() {
  [ "$TEAM_CONFIRM_WRITES" = "1" ] || return 0
  [ "${TEAM_ASSUME_YES:-0}" = "1" ] && return 0
  team_err "该操作会改变共享/远端状态，需要显式授权：加 --yes（或 TEAM_ASSUME_YES=1）"
  return 1
}

# ---------------------------------------------------------------- 文档骨架
team_docs_file() { printf '%s\n' "$TEAM_DOCS_ABS/$1"; }

team_require_docs() {
  [ -d "$TEAM_DOCS_ABS" ] || team_die "未初始化：缺 $TEAM_DOCS_DIR/（先跑 $TEAM_CLI init）"
}

team_touch_file() { # 不存在才创建，内容从 stdin
  [ -f "$1" ] && { cat >/dev/null; return 0; }
  mkdir -p "$(dirname "$1")"
  cat > "$1"
}

# 往文件追加一段（自动补空行，保持 append-only 语义）
team_append() { # <file> <block>
  local f="$1"; shift
  mkdir -p "$(dirname "$f")"
  [ -s "$f" ] && printf '\n' >> "$f"
  printf '%s\n' "$*" >> "$f"
}

team_timestamp() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# BOARD.md 行更新：| ID | 任务 | Agent | 分支 | 依赖 | 状态 |
team_board_set() { # <id> <status>
  local f="$TEAM_DOCS_ABS/BOARD.md" id="$1" st="$2" idcol stcol
  [ -f "$f" ] || return 1
  idcol="$(team_board_col id)"; stcol="$(team_board_col status)"
  if awk -v id="$id" -v st="$st" -v ic="$idcol" -v sc="$stcol" 'BEGIN{FS=OFS="|"}
    /^\|/ { v=$(ic); gsub(/^[[:space:]]+|[[:space:]]+$/,"",v)
             if (v==id) { gsub(/^[[:space:]]+|[[:space:]]+$/,"",$(sc)); $(sc)=" "st" "; print; next } }
    { print }
  ' "$f" > "$f.tmp"; then
    mv "$f.tmp" "$f"
    return 0
  fi
  rm -f "$f.tmp"
  return 1
}

team_board_add() { # <id> <title> <agent> <branch> <deps>
  local f="$TEAM_DOCS_ABS/BOARD.md"
  [ -f "$f" ] || return 1
  # 与文件现有列数对齐：额外的列填 -（这样加了自定义列也不会错位）
  local ncols idcol taskcol agentcol branchcol depscol stcol cells=() i
  # 列数取「任务表表头行」的列数（文件里可能还有别的表，取最后一行会数错）
  ncols="$(awk 'BEGIN{FS="|"} /^\|/ { v=$2; gsub(/^[ \t]+|[ \t]+$/,"",v); if (v=="ID") { print NF; exit } }' "$f")"
  [ -n "$ncols" ] || ncols=8
  idcol="$(team_board_col id)"; taskcol="$(team_board_col task)"; agentcol="$(team_board_col agent)"
  branchcol="$(team_board_col branch)"; depscol="$(team_board_col deps)"; stcol="$(team_board_col status)"
  for ((i=1;i<ncols;i++)); do cells+=( " " ); done
  cells[$((idcol-1))]=" $1 "; cells[$((taskcol-1))]=" $2 "; cells[$((agentcol-1))]=" $3 "
  cells[$((branchcol-1))]=" $4 "; cells[$((depscol-1))]=" ${5:--} "; cells[$((stcol-1))]=" todo "
  # 字段 1 是行首的空单元（在第一个 | 之前），要打印的是字段 2..ncols-1 → cells[1..ncols-2]
  local row="|"
  for ((i=1;i<ncols-1;i++)); do row="$row${cells[$i]:- }|"; done
  # 插到「任务表」的最后一行之后（模板末尾还有别的表：直接 append 会跑到别的表里去）
  local hdr last
  hdr="$(awk 'BEGIN{FS="|"} /^\|/ { v=$'"$idcol"'; gsub(/^[ \t]+|[ \t]+$/,"",v); if (v=="ID") { print NR; exit } }' "$f")"
  if [ -n "$hdr" ]; then
    last="$(awk -v start="$hdr" 'NR>=start { if ($0 ~ /^\|/) last=NR; else if (last) exit } END{print last}' "$f")"
  else
    last="$(awk '/^\|/ { last=NR } END{print last}' "$f")"
  fi
  if [ -n "$last" ]; then
    awk -v at="$last" -v row="$row" 'NR==at { print; print row; next } { print }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  else
    printf '%s\n' "$row" >> "$f"
  fi
}

# ---------------------------------------------------------------- 模板渲染
# 模板里用 {{KEY}} 占位；值里的 sed 元字符会被转义。
team_render() { # <template-file> [KEY=VALUE ...]
  local tmpl="$1"; shift
  local out kv k v esc
  out="$(cat "$tmpl")"
  for kv in "$@"; do
    k="${kv%%=*}"; v="${kv#*=}"
    esc="$(printf '%s' "$v" | sed -e 's/[&|\\]/\\\\&/g')"
    out="$(printf '%s\n' "$out" | sed -e "s|{{$k}}|$esc|g")"
  done
  printf '%s\n' "$out"
}

# 渲染到目标文件；已存在且无 --force 则跳过（cat 掉 stdin，避免 SIGPIPE）
team_render_to() { # <template> <dest> <force:0|1> [KEY=VALUE ...]
  local tmpl="$1" dest="$2" force="$3"; shift 3
  if [ -f "$dest" ] && [ "$force" != "1" ]; then
    team_dim "skip  $dest（已存在）"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  team_render "$tmpl" "$@" > "$dest"
  team_ok "write $dest"
}

team_tmpl_dir() { printf '%s\n' "$TEAM_SKILL_DIR/templates"; }

# 主工作树里「与代码无关」的脏文件：PM 自己的文档/看板/复验记录不阻塞合并
# （gitignored 的 inbox/state 本来就不在 status 里）
team_main_dirty_external() {
  local line path
  team_git_main status --porcelain | while IFS= read -r line; do
    [ -n "$line" ] || continue
    path="${line:3}"; path="${path##* -> }"
    case "$path" in
      "$TEAM_DOCS_DIR/"*|.pi/team/*) [ "${TEAM_DEBUG:-0}" = "1" ] && printf 'ignored: %s\n' "$line" >&2 ; continue ;;
      *) printf '%s\n' "$line" ;;
    esac
  done
}

# ---------------------------------------------------------------- BOARD
# BOARD.md 行更新：| ID | 任务 | Agent | 分支 | 依赖 | 状态 |

# ---------------------------------------------------------------- BOARD 列映射（②）
# BOARD 的列必须可容忍额外列：按表头名字定位，而不是硬编码列号。
# 输出 "<id> <task> <agent> <branch> <deps> <status>"（1-based 列号；缺表头时用默认 2 3 4 5 6 7）
team_board_cols() {
  local f="$TEAM_DOCS_ABS/BOARD.md"
  if [ -f "$f" ]; then
    awk 'BEGIN{FS="|"}
      /^\|/ {
        line=$0
        if (line !~ /[Ii][Dd]/) next
        n=NF
        for (i=2;i<n;i++) { name=$(i); gsub(/^[ \t]+|[ \t]+$/,"",name)
          if (name=="ID"||name=="编号") id=i
          else if (name=="任务"||name=="标题"||name=="Title"||name=="Task") task=i
          else if (name ~ /^[Aa]gent$/) agent=i
          else if (name=="分支"||name=="Branch") branch=i
          else if (name=="依赖"||name=="Deps"||name=="Depends") deps=i
          else if (name=="状态"||name=="Status") status=i
        }
        if (id && task && status) { printf "%d %d %d %d %d %d\n", id, task, agent?agent:0, branch?branch:0, deps?deps:0, status; exit }
      }' "$f"
  fi
}

team_board_col() { # <name> → 列号（找不到时给默认）
  local name="$1" cols
  cols="$(team_board_cols)"
  if [ -n "$cols" ]; then
    local id task agent branch deps status
    read -r id task agent branch deps status <<< "$cols"
    case "$name" in
      id) printf '%s\n' "$id"; return 0 ;;
      task) printf '%s\n' "$task"; return 0 ;;
      agent) [ "$agent" -gt 0 ] && { printf '%s\n' "$agent"; return 0; }; printf '4\n'; return 0 ;;
      branch) [ "$branch" -gt 0 ] && { printf '%s\n' "$branch"; return 0; }; printf '5\n'; return 0 ;;
      deps) [ "$deps" -gt 0 ] && { printf '%s\n' "$deps"; return 0; }; printf '6\n'; return 0 ;;
      status) printf '%s\n' "$status"; return 0 ;;
    esac
  fi
  case "$name" in
    id) printf '2\n' ;; task) printf '3\n' ;; agent) printf '4\n' ;;
    branch) printf '5\n' ;; deps) printf '6\n' ;; status) printf '7\n' ;;
  esac
}

team_board_field() { # <row-line> <name> → 值（去掉首尾空白）
  local line="$1" name="$2" col
  col="$(team_board_col "$name")"
  printf '%s\n' "$line" | awk -v c="$col" 'BEGIN{FS="|"} { v=$(c); gsub(/^[ \t]+|[ \t]+$/,"",v); print v }'
}

# 表头与期望列不一致时给出提醒（board ls / digest 用）
team_board_layout_warning() {
  local f="$TEAM_DOCS_ABS/BOARD.md"
  [ -f "$f" ] || return 1
  local cols; cols="$(team_board_cols)"
  [ -n "$cols" ] || { printf 'BOARD.md 找不到带 ID/任务/状态 的表头行：列解析会退回默认位置\n'; return 0; }
  local id task agent branch deps status
  read -r id task agent branch deps status <<< "$cols"
  if [ "$id" != "2" ] || [ "$task" != "3" ] || [ "$status" != "7" ]; then
    printf 'BOARD.md 是非标准列布局（ID=%s 任务=%s 状态=%s）：按表头名解析，能容忍额外列\n' "$id" "$task" "$status"
  fi
  return 0
}

team_board_row() { # <id> → 整行（列位置由表头决定）
  local f="$TEAM_DOCS_ABS/BOARD.md" col
  [ -f "$f" ] || return 1
  col="$(team_board_col id)"
  awk -v id="$1" -v c="$col" 'BEGIN{FS="|"}
    /^\|/ { v=$(c); gsub(/^[[:space:]]+|[[:space:]]+$/,"",v); if (v==id) { print; exit } }' "$f"
}
