#!/usr/bin/env bash
# teamsmith · 公共库：配置解析、路径推导、tmux/git 辅助、守卫。
# 由 scripts/team 与各 cmd-*.sh source；不要直接执行。
# 约定：所有函数名以 team_ 前缀；不依赖 jq / python / node。

TEAM_VERSION="1.19.0"

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
# 查找顺序：$TEAM_CONFIG_FILE → 从 $TEAM_ROOT（没有就用 $PWD）向上找 .pi/team/config.sh
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

  team_is_git_repo || team_die "当前目录不在 git 仓库内（teamsmith 需要 git 来做 worktree 隔离）"
  TEAM_ROOT="${TEAM_ROOT:-$(team_worktree_top)}"
  TEAM_MAIN_ROOT="${TEAM_MAIN_ROOT:-$(team_main_root)}"

  TEAM_PROJECT="${TEAM_PROJECT:-$(basename "$TEAM_MAIN_ROOT")}"
  _team_session_preset="${TEAM_SESSION:-}"
  TEAM_SESSION="${TEAM_SESSION:-$TEAM_PROJECT}"
  TEAM_SESSION_FROM="${TEAM_SESSION_FROM:-$([ -n "$_team_session_preset" ] && echo explicit || echo default)}"
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
  # 项目自己的 forge 命令模板（可选）。占位符：{branch} {base} {title} {pr} {body} {remote}
  # 例（Gitea）：TEAM_PR_CMD="tea pr create --base {base} --head {branch} --title {title}"
  TEAM_PR_CMD="${TEAM_PR_CMD:-}"
  TEAM_MERGE_PR_CMD="${TEAM_MERGE_PR_CMD:-}"
  # 项目自己的 forge 命令模板（可选）。占位符：{branch} {base} {title} {pr} {body} {remote}
  # 例（Gitea）：TEAM_PR_CMD="tea pr create --base {base} --head {branch} --title {title}"
  TEAM_PR_CMD="${TEAM_PR_CMD:-}"
  TEAM_MERGE_PR_CMD="${TEAM_MERGE_PR_CMD:-}"
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
  # PM 记忆（依赖）：magic-context 让 PM 的长期会话能跨压缩/跨重启检索历史。
  # 默认要求（D10）：缺它时 PM 的记忆层是空的，doctor 会判失败。
  # TEAM_REQUIRE_MAGIC_CONTEXT=0 降级为只警告（环境特殊 / 临时验查时用）。
  TEAM_REQUIRE_MAGIC_CONTEXT="${TEAM_REQUIRE_MAGIC_CONTEXT:-1}"
  TEAM_PI_SETTINGS_FILE="${TEAM_PI_SETTINGS_FILE:-$HOME/.pi/agent/settings.json}"
  # 规格管理（依赖）：OpenSpec 负责“为什么改/改成什么”，teamsmith 不再长第二套 spec 体系。
  # 两个键分别管「CLI 能不能解析」与「项目里的 spec 根目录存不存在」。
  TEAM_REQUIRE_OPENSPEC="${TEAM_REQUIRE_OPENSPEC:-1}"
  TEAM_OPENSPEC_BIN="${TEAM_OPENSPEC_BIN:-openspec}"
  TEAM_SPEC_DIR="${TEAM_SPEC_DIR:-openspec}"
  TEAM_WATCH_INTERVAL="${TEAM_WATCH_INTERVAL:-900}"       # 巡检周期（秒）
  TEAM_WATCH_NUDGE_GAP="${TEAM_WATCH_NUDGE_GAP:-900}"      # 同一批待办最快多久再提醒一次（秒）
  TEAM_WATCH_MAX_RESTARTS="${TEAM_WATCH_MAX_RESTARTS:-5}"  # PM 每小时最多自动拉起次数（防崩溃循环）
  TEAM_WATCH_REBUILD_TMUX="${TEAM_WATCH_REBUILD_TMUX:-0}"  # 0=不管 tmux（session/窗口没了只告警）；1=允许重建 PM 窗口
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
  # 边界守卫：只允许往本团队 session 里的窗口打字。
  # 跨项目讨论走 `team meeting`（文件为真相 + 可选敲门），不允许直接给别的 PM 发消息。
  TEAM_GUARD_FOREIGN_TARGET="${TEAM_GUARD_FOREIGN_TARGET:-1}"
  # 跨项目会议：共享区、TTL、每边上限、是否允许敲门
  TEAM_MEETINGS_DIR="${TEAM_MEETINGS_DIR:-$HOME/.pi/team/meetings}"
  TEAM_MEETING_TTL_HOURS="${TEAM_MEETING_TTL_HOURS:-72}"
  TEAM_MEETING_MAX_TURNS="${TEAM_MEETING_MAX_TURNS:-20}"
  TEAM_MEETING_KNOCK="${TEAM_MEETING_KNOCK:-0}"
  TEAM_PM_START_WAIT="${TEAM_PM_START_WAIT:-6}"            # 启动 PM 后等它起来的秒数
  TEAM_NOTIFY_TMUX="${TEAM_NOTIFY_TMUX:-1}"
  TEAM_NOTIFY_DEDUP_SEC="${TEAM_NOTIFY_DEDUP_SEC:-20}"
  TEAM_NOTIFY_LOG="${TEAM_NOTIFY_LOG:-/tmp/teamsmith-notify.log}"
  TEAM_INBOX_IN_MAIN="${TEAM_INBOX_IN_MAIN:-1}"
  TEAM_INBOX_MAX_CHARS="${TEAM_INBOX_MAX_CHARS:-150}"
  TEAM_CONFIRM_WRITES="${TEAM_CONFIRM_WRITES:-1}"
  TEAM_AGENTS="${TEAM_AGENTS:-}"
  TEAM_AGENT_MODELS="${TEAM_AGENT_MODELS:-}"
  TEAM_EXTRA_PI_ARGS="${TEAM_EXTRA_PI_ARGS:-}"
  # ---- agent adapter（任意 TUI agent）：空值 = 内置 Pi 行为（历史默认，逐字节不变） ----
  # TEAM_AGENT_CMD       ：启动 agent CLI 的命令模板（占位符见 references/agent-adapters.md）
  # TEAM_AGENT_NOTIFY_CMD：非 Pi agent 在回合结束时通知 PM 的命令模板（{summary} 等占位符）
  # TEAM_AGENT_LOG_GLOB  ：可选的日志/会话文件通配（monitor --activity 用；{agent} = agent 名）
  # TEAM_AGENT_BIN       ：可选的可执行文件（doctor/dispatch 的就绪与存在性检查）；空 = 从上面推断
  TEAM_AGENT_CMD="${TEAM_AGENT_CMD:-}"
  TEAM_AGENT_NOTIFY_CMD="${TEAM_AGENT_NOTIFY_CMD:-}"
  TEAM_AGENT_LOG_GLOB="${TEAM_AGENT_LOG_GLOB:-}"
  TEAM_AGENT_BIN="${TEAM_AGENT_BIN:-}"

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

# 输出一份「可直接写进派单提示词」的路径清单（agent_adapter = 当前生效的 agent 适配器）
team_paths_json() {
  printf '{ "project": "%s", "main_root": "%s", "worktree": "%s", "docs": "%s", "worktrees": "%s", "session": "%s", "pm_window": "%s", "agent_adapter": "%s", "agent_bin": "%s", "openspec_bin": "%s", "spec_dir": "%s", "require_magic_context": "%s", "require_openspec": "%s" }\n' \
    "$(team_json_escape "$TEAM_PROJECT")" "$(team_json_escape "$TEAM_MAIN_ROOT")" "$(team_json_escape "$TEAM_ROOT")" \
    "$(team_json_escape "$TEAM_DOCS_ABS")" "$(team_json_escape "$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR")" \
    "$(team_json_escape "$TEAM_SESSION")" "$(team_json_escape "$TEAM_PM_WINDOW")" \
    "$(team_json_escape "$(team_agent_adapter_label)")" "$(team_json_escape "$(team_agent_bin_path)")" \
    "$(team_json_escape "$(team_openspec_bin_path)")" "$(team_json_escape "$(team_spec_dir_abs)")" \
    "$(team_json_escape "$TEAM_REQUIRE_MAGIC_CONTEXT")" "$(team_json_escape "$TEAM_REQUIRE_OPENSPEC")"
}

# 能跑普通 .mjs 的运行时（monitor.mjs 是普通 JS，不需要 TS 剥离能力；
# 之前复用了 team_ts_runner，于是只有“老 node、无 bun/tsx”的机器上活动流会被误判为不可用）
team_js_runner() {
  if team_have_cmd node; then printf 'node'
  elif team_have_cmd bun; then printf 'bun'
  elif team_have_cmd tsx; then printf 'tsx'
  fi
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

# 把 {KEY} 占位符替换成值（项目自定义 forge 命令模板用；bash 参数展开，不做 sed 替换）
team_tpl_fill() { # <template> KEY=VALUE ...
  local tpl="$1"; shift
  local kv k v
  for kv in "$@"; do
    k="${kv%%=*}"; v="${kv#*=}"
    tpl="${tpl//\{$k\}/$v}"
  done
  printf '%s\n' "$tpl"
}

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
  team_assert_own_session "建 tmux session" || return 1
  team_tmux_has_session "$TEAM_SESSION" && return 0
  tmux new-session -d -s "$TEAM_SESSION" -n "$TEAM_PM_WINDOW" 2>/dev/null || true
}

# 破坏性 tmux 操作前调用：只允许操作「本项目自己的 session」，且目标必须非空。
# 事故背景：tmux 的 `-t ""` 等于「当前窗口/会话」，测试里一个空变量就能把调用者的窗口打掉。
team_assert_own_session() { # <操作名>
  local op="${1:-tmux 操作}"
  if [ -z "${TEAM_SESSION:-}" ]; then
    team_err "$op 被拒：TEAM_SESSION 为空（空目标等于当前窗口/会话，禁止操作）"
    return 1
  fi
  # 「运行在本项目里」：cwd 的仓库必须就是 TEAM_ROOT —— 防止在别的项目里嵌套调用时误伤
  local _cwd_root _root_real
  _cwd_root="$(team_git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  [ -n "$_cwd_root" ] && _cwd_root="$(cd "$(dirname "$_cwd_root")" 2>/dev/null && pwd -P || echo "")"
  _root_real="$(cd "${TEAM_ROOT:-}" 2>/dev/null && pwd -P || echo "${TEAM_ROOT:-}")"
  local _root_common=""
  if [ -n "$_root_real" ]; then
    _root_common="$(team_git -C "$_root_real" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    [ -n "$_root_common" ] && _root_common="$(cd "$(dirname "$_root_common")" 2>/dev/null && pwd -P || echo "")"
  fi
  # 「同一个仓库」判定用 git common dir：这样在 worktree 里调用也算本项目的操作
  if [ -n "$_cwd_root" ] && [ -n "$_root_common" ] && [ "$_cwd_root" != "$_root_common" ] \
     && [ "${TEAM_ASSUME_YES:-0}" != "1" ] && [ "${TEAM_ALLOW_FOREIGN_SESSION:-0}" != "1" ]; then
    team_err "$op 被拒：当前目录属于 '$(basename "$_cwd_root")'，而要被操作的是 '$TEAM_PROJECT'（$_root_real）"
    team_dim "  这通常意味着继承了别的项目的 TEAM_ROOT（测试/门禁/嵌套调用）。" >&2
    team_dim "  确认要操作它：TEAM_ALLOW_FOREIGN_SESSION=1 …（或 --yes）" >&2
    return 1
  fi
  if [ "$(team_session_from 2>/dev/null || echo default)" != "explicit" ] \
     && [ "$TEAM_SESSION" != "$TEAM_PROJECT" ] \
     && [ "${TEAM_ASSUME_YES:-0}" != "1" ] && [ "${TEAM_ALLOW_FOREIGN_SESSION:-0}" != "1" ]; then
    team_err "$op 被拒：session '$TEAM_SESSION' 既不是配置/环境显式指定的，也不等于项目名 '$TEAM_PROJECT'"
    team_dim "  这通常意味着继承了别的项目的环境（TEAM_ROOT/TEAM_SESSION）。" >&2
    team_dim "  确认要操作它：TEAM_ALLOW_FOREIGN_SESSION=1 …（或 --yes）" >&2
    return 1
  fi
  return 0
}

team_session_from() { printf '%s\n' "${TEAM_SESSION_FROM:-default}"; }

# 安全包装：拒绝空目标，避免 `-t ""` 打到当前窗口/会话
team_tmux_kill_window() { # <session:window>
  local t="${1:-}"
  [ -n "$t" ] || { team_err "kill-window 被拒：目标为空（会误伤当前窗口）"; return 1; }
  tmux kill-window -t "$t" 2>/dev/null
}
team_tmux_kill_session() { # <session>
  local t="${1:-}"
  [ -n "$t" ] || { team_err "kill-session 被拒：目标为空（会误伤当前会话）"; return 1; }
  tmux kill-session -t "$t" 2>/dev/null
}
team_tmux_new_window() { # <session> <name>
  local t="${1:-}" n="${2:-}"
  [ -n "$t" ] || { team_err "new-window 被拒：session 为空"; return 1; }
  tmux new-window -t "$t" -n "$n" -d 2>/dev/null
}
team_tmux_respawn_pane() { # <pane-or-target> <cmd>
  local t="${1:-}" cmd="${2:-}"
  [ -n "$t" ] || { team_err "respawn-pane 被拒：目标为空（会误伤当前 pane：本次事故的直接原因）"; return 1; }
  tmux respawn-pane -k -t "$t" "$cmd" 2>/dev/null
}

team_target_session() { # <session:window> → session 名
  printf '%s\n' "${1%%:*}"
}

# 边界守卫：teamsmith 只在自己的 tmux session 里动作。
# 跨项目/跨 session 的沟通不是 agent 的活 —— 要走「本团队 PM → 用户 → 对方」。
team_foreign_target_ok() { # <session:window> [meeting-slug] → 0=允许
  [ "${TEAM_GUARD_FOREIGN_TARGET:-1}" = "1" ] || return 0
  local sess; sess="$(team_target_session "$1")"
  [ -n "$sess" ] || return 0
  [ -n "$TEAM_SESSION" ] || return 0
  [ "$sess" = "$TEAM_SESSION" ] && return 0
  # 例外：**已登记的会议参与方** —— 只用于会议通知（敲门），不是聊天通道
  if [ -n "${2:-}" ] && [ -n "${TEAM_MEETINGS_DIR:-$HOME/.pi/team/meetings}" ]; then
    local map kv
    map="$(grep -s '^PEER_SESSIONS=' "$(team_meetings_dir 2>/dev/null)/$2/state.env" 2>/dev/null | head -1 | cut -d= -f2- || true)"
    for kv in $(printf '%s' "$map" | tr ';' ' '); do
      case "$kv" in
        "=$sess"|*=*) [ "${kv#*=}" = "$sess" ] && return 0 ;;
      esac
    done
  fi
  team_err "拒绝跨 session 操作：目标 $1 不在本团队 session（$TEAM_SESSION）"
  team_err "边界规则：跨项目讨论走 $TEAM_CLI meeting（PM 对 PM）；不允许直接给别的 session 打字或指挥别的 PM"
  return 1
}

team_rule() { # 一条水平线（面板/阅读器用）
  local w="${1:-74}"
  printf '%.0s─' $(seq 1 "$w")
  printf '\n'
  return 0
}

team_tmux_send_text() { # <session:window> <text> [meeting-slug]
  team_foreign_target_ok "$1" "${3:-}" || return 1
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
  [ "${TEAM_DEBUG:-0}" = "1" ] && printf '[dbg]     shell_running? pid=%s args=[%s]\n' "$1" "$args" >&2
  # 窗口刚建好的一瞬间，pane_pid 可能还是 tmux 自己（args 里有 -s/-n 这类参数会被误判成"在跑命令"）
  case "${args%% *}" in
    */tmux|tmux|*/tmux:*) return 1 ;;
  esac
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

team_pane_busy() { # <session:window> → 0 = 里面有东西在跑（不是空提示符）
  local target="$1" cmd pid args first
  cmd="$(team_pane_cmd "$target")"
  [ "${TEAM_DEBUG:-0}" = "1" ] && printf '[dbg] busy? %s cmd=%s\n' "$target" "$cmd" >&2
  team_is_shell_cmd "$cmd" || return 0            # 前台不是 shell（pi/node…）→ 在跑
  pid="$(tmux display-message -p -t "$target" '#{pane_pid}' 2>/dev/null)"
  [ -n "$pid" ] || return 1
  args="$(ps -o args= -p "$pid" 2>/dev/null | head -1)"
  first="${args%% *}"
  [ "${TEAM_DEBUG:-0}" = "1" ] && printf '[dbg]   pid=%s args=[%s]\n' "$pid" "$args" >&2
  # 只有 pane_pid 真的是个 shell 才继续判；
  # 刚建窗口的一瞬间 pane_pid 可能是 tmux 自己（args 形如 "[tmux: server]"）或空，
  # 这时当成"没在跑"——否则会把刚建的窗口误判成"忙"，PM 就永远拉不起来。
  case "$(basename "${first:-}" 2>/dev/null || printf '%s' "${first:-}")" in
    bash|sh|zsh|fish|dash|ash|ksh|nu|elvish) ;;
    *) return 1 ;;
  esac
  # shell 在跑脚本/子命令：命令行里有非选项参数（如 bash -lc 'exec pi …'）
  team_shell_running_command "$pid" && return 0
  # job control：前台进程组不是这个 shell 自己 → 有前台命令
  local tpgid
  tpgid="$(ps -o tpgid= -p "$pid" 2>/dev/null | tr -d ' ')"
  if [ -n "$tpgid" ] && [ "$tpgid" != "$pid" ]; then return 0; fi
  return 1
}

# ---------------------------------------------------------------- PM 存活
team_pm_target() { printf '%s:%s\n' "$TEAM_SESSION" "$TEAM_PM_WINDOW"; }

team_pm_window_exists() { team_tmux_has_window "$TEAM_SESSION" "$TEAM_PM_WINDOW"; }

# ---------------------------------------------------------------- 进程 / 归属
# 为什么需要：`team_pm_state` 以前只看「窗口在 + 前台不是 shell」，
# 于是**任何** pi 都会被当成本项目的 PM —— 实测踩过：smoke 留下的 dummy fixture PM
# （cwd 是已删除的 /tmp/teamsmith-smoke.*/repo）在窗口里挂着，团队工具一直把它当真 PM。
team_proc_cwd() { # <pid> → 该进程的 cwd（Linux /proc；macOS 退 lsof）
  [ -n "${1:-}" ] || return 1
  if [ -e "/proc/$1/cwd" ]; then
    readlink -f "/proc/$1/cwd" 2>/dev/null && return 0
  fi
  if team_have_cmd lsof; then
    local out; out="$(lsof -a -p "$1" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)"
    [ -n "$out" ] && { printf '%s\n' "$out"; return 0; }
  fi
  return 1
}

# 窗口里的「真正在跑的进程」：前台不是 shell 就是它；是 shell 就看它的子进程（pi 常见形态）
team_pane_proc_pid() { # <session:window>
  local target="$1" pid cmd child
  pid="$(tmux display-message -p -t "$target" '#{pane_pid}' 2>/dev/null | head -1)"
  [ -n "$pid" ] || return 1
  cmd="$(team_pane_cmd "$target")"
  if [ -n "$cmd" ] && ! team_is_shell_cmd "$cmd"; then printf '%s\n' "$pid"; return 0; fi
  child="$(ps -o pid= --ppid "$pid" 2>/dev/null | head -1 | tr -d ' ')"
  [ -n "$child" ] && printf '%s\n' "$child" || printf '%s\n' "$pid"
}

team_pane_cwd() { # <session:window> → 窗口里那个进程的 cwd
  local pid; pid="$(team_pane_proc_pid "${1:-}")" || return 1
  team_proc_cwd "$pid"
}

team_cwd_in_project() { # <cwd> → 0=属于本项目（含它的 worktree）
  local c="${1:-}" common
  [ -n "$c" ] || return 1
  case "$c" in
    "$TEAM_MAIN_ROOT"|"$TEAM_MAIN_ROOT"/*) return 0 ;;
  esac
  common="$(team_git -C "$c" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  [ -n "$common" ] || return 1
  if [ "$(cd "$(dirname "$common")" 2>/dev/null && pwd -P)" = "$TEAM_MAIN_ROOT" ]; then
    return 0
  fi
  return 1
}

# missing | idle:<cmd> | busy:<cmd> | running:<cmd>
#   running = 前台不是 shell（pi 本体）
#   busy    = 前台是 shell 但有子进程（pi 是 shell wrapper 时就是这个；也包含用户在跑别的命令）
#   idle    = 空提示符（可以安全地替成 pi）
team_pm_state() {
  team_pm_window_exists || { printf 'missing'; return 0; }
  local cmd; cmd="$(team_pane_cmd "$(team_pm_target)")"
  # 归属校验：窗口里的进程 cwd 必须在本项目里（否则是别的项目/测试残留占着这个窗口）
  local cwd; cwd="$(team_pane_cwd "$(team_pm_target)" 2>/dev/null || true)"
  if [ -n "$cwd" ] && ! team_cwd_in_project "$cwd"; then
    printf 'foreign:%s' "${cmd:-unknown}"; return 0
  fi
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
    foreign:*)
      local fcwd; fcwd="$(team_pane_cwd "$target" 2>/dev/null || echo '?')"
      team_err "PM 窗口 $target 被**不属于本项目**的进程占用（cwd=$fcwd）：不覆盖它"
      team_dim "  （实测踩过：smoke 残留的 dummy PM 挂着，工具却把它当本项目的 PM）" >&2
      team_dim "  处理：关掉那个窗口/改窗口名，或用 TEAM_REPLACE_FOREIGN_PM=1 显式覆盖（会杀掉它）" >&2
      [ "${TEAM_REPLACE_FOREIGN_PM:-0}" = "1" ] || return 1 ;;
    *)         team_warn "PM 窗口状态异常（$state），不重启；处理完再跑 team up"; return 1 ;;
  esac
  pf="$(team_pm_write_prompt)"
  local pi_bin; pi_bin="$(team_pi_bin_path)"
  cmd="$(printf 'cd %q && exec %q %s @%q' "$TEAM_MAIN_ROOT" "$pi_bin" "$(team_pm_pi_args)" "$pf")"
  team_tmux_respawn_pane "$target" "$cmd" || {
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

# 模型并发计数：**只读**。窗口不在了 = 这个槽位自动释放（不计数），但绝不顺手删状态文件。
# F28 事故背景（V4.0）：这里曾经对「窗口没了」的 agent 调 team_state_clear，于是 `team ps` 这种
# 只读命令跑一次，崩溃 agent 的 task/branch/worktree 记录就没了 —— digest 报「无待办」、resume 说
# 「没有需要续跑的 agent」，工具正好在它存在的意义上瞎了。
# 现在的口径：状态文件是「这个 agent 在干什么」的持久记录（只有 dispatch/close/teardown 这类真改状态
# 的命令才写它）；「还在不在跑」是 tmux 的现场事实，每次查询现算。
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
    team_tmux_has_window "$TEAM_SESSION" "$w" && n=$((n + 1))
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
team_board_ids() { # → 表里现有的 id（每行一个，给「未知 id」的报错用）
  local f="$TEAM_DOCS_ABS/BOARD.md" col
  [ -f "$f" ] || return 0
  col="$(team_board_col id)"
  awk -v c="$col" 'BEGIN{FS="|"}
    /^\|/ { v=$(c); gsub(/^[ \t]+|[ \t]+$/,"",v)
            if (v=="" || v=="ID" || v=="编号" || v ~ /^-+$/) next
            print v }' "$f"
  return 0
}

# 注意：team_board_row 对「没有这一行」也返回 0（awk 正常结束），所以判存在必须看输出
# 是否非空 —— F29 的根因就是「写」从不检查行是否存在。
team_board_has() { # <id> → 0=表里有这一行
  [ -n "$(team_board_row "$1" 2>/dev/null || true)" ]
}

# 只写状态列（不做任何校验）。未知 id 时**不写文件**并返回 1 —— F29 之前 awk 永远「成功」，
# 于是 `board set NOSUCH done` 会打印 ✓ 而文件一个字节都没变（md5 相同）。
team_board_write() { # <id> <status> → 0=真的改了那一行；1=没有这个 id（不碰文件）
  local f="$TEAM_DOCS_ABS/BOARD.md" id="$1" st="$2" idcol stcol
  [ -f "$f" ] || return 1
  idcol="$(team_board_col id)"; stcol="$(team_board_col status)"
  awk -v id="$id" -v st="$st" -v ic="$idcol" -v sc="$stcol" 'BEGIN{FS=OFS="|"}
    /^\|/ { v=$(ic); gsub(/^[[:space:]]+|[[:space:]]+$/,"",v)
             if (v==id) { gsub(/^[[:space:]]+|[[:space:]]+$/,"",$(sc)); $(sc)=" "st" "; print; found=1; next } }
    { print }
    END { exit(found ? 0 : 1) }
  ' "$f" > "$f.tmp" || { rm -f "$f.tmp"; return 1; }
  mv "$f.tmp" "$f" || { rm -f "$f.tmp"; return 1; }
  return 0
}

# ---------------------------------------------------------------- done 的准入证据（F1）
# 「状态是承诺」：`done` 必须当场有可核对的东西（只读检查，skill 不碰 git 写操作）：
#   ① 复验记录 <docs>/reviews/<ID>.md 存在，且判定不是 FAIL/TIMEOUT；或
#   ② 任务分支的 tip 已经在保护分支里（真 merge/fast-forward）。**squash 合并不会满足 ②**，
#      所以走 squash 流程时靠 ① 解锁。
# 覆盖：PM 显式给理由（TEAM_BOARD_DONE_FORCE=1 + TEAM_BOARD_DONE_REASON="…"），并落盘审计。
team_review_verdict() { # <ID> → PASS|FAIL|TIMEOUT|SKIPPED|UNKNOWN|none|missing
  local f="$TEAM_DOCS_ABS/reviews/$1.md" v=""
  [ -f "$f" ] || { printf 'missing\n'; return 0; }
  v="$(grep -m1 -oE '判定: \*\*[A-Za-z]+\*\*' "$f" 2>/dev/null | tr -d '*' | sed 's/^判定: //' || true)"
  printf '%s\n' "${v:-none}"
  return 0
}

team_done_evidence() { # <ID> → 0=有证据（stdout 一行证据）/1=没证据（stdout 检查明细）
  local id="$1" rel="$TEAM_DOCS_DIR/reviews/$id.md" verdict branch tip detail=""
  verdict="$(team_review_verdict "$id")"
  case "$verdict" in
    PASS)    printf '复验记录 %s（判定 PASS）\n' "$rel"; return 0 ;;
    UNKNOWN) printf '复验记录 %s（判定 UNKNOWN：门禁未配置，人工评审）\n' "$rel"; return 0 ;;
    SKIPPED) printf '复验记录 %s（判定 SKIPPED：PM 选择人工看 diff）\n' "$rel"; return 0 ;;
    missing) detail="不存在" ;;
    none)    detail="存在，但没有「判定: **…**」这一行（不能当作已复验的证据）" ;;
    *)       detail="存在但判定是 $verdict（FAIL/TIMEOUT 不算证据）" ;;
  esac
  branch="$(team_resolve_branch "$id" "" 2>/dev/null || true)"
  tip=""
  if [ -n "$branch" ]; then
    tip="$(git -C "$TEAM_MAIN_ROOT" rev-parse --verify --quiet "$branch^{commit}" 2>/dev/null || true)"
  fi
  if [ -n "$tip" ] && git -C "$TEAM_MAIN_ROOT" merge-base --is-ancestor "$tip" "$TEAM_PROTECTED_BRANCH" 2>/dev/null; then
    printf '分支 %s（%s）已经是 %s 的祖先（代码真的落地了）\n' "$branch" "${tip:0:9}" "$TEAM_PROTECTED_BRANCH"
    return 0
  fi
  printf '  - ① 复验记录 %s：%s\n' "$rel" "$detail"
  if [ -z "$branch" ]; then
    printf '  - ② 分支是否已并入 %s：找不到 %s 的分支\n' "$TEAM_PROTECTED_BRANCH" "$id"
  elif [ -z "$tip" ]; then
    printf '  - ② 分支是否已并入 %s：分支 %s 解析不到 commit\n' "$TEAM_PROTECTED_BRANCH" "$branch"
  else
    printf '  - ② 分支是否已并入 %s：%s（%s）的提交还不在里面（squash 合并不会让分支 tip 变成祖先）\n' \
      "$TEAM_PROTECTED_BRANCH" "$branch" "${tip:0:9}"
  fi
  return 1
}

# done 的闸门：证据 / 显式覆盖。成功时 stdout 第一行是「判定行」（OK/FORCED），后面是证据明细；
# 失败时 stdout 空、明细与继续办法都打到 stderr（调用方照原样返回 1 即可）。
team_done_gate() { # <ID> <命令标签>
  local id="$1" label="$2" ev reason=""
  if ev="$(team_done_evidence "$id")"; then
    printf 'OK：%s\n' "$ev"
    return 0
  fi
  if [ "${TEAM_BOARD_DONE_FORCE:-0}" = "1" ]; then
    reason="${TEAM_BOARD_DONE_REASON:-}"
    if [ -z "$(team_trim "$reason")" ]; then
      team_err "TEAM_BOARD_DONE_FORCE=1 但 TEAM_BOARD_DONE_REASON 是空的：覆盖要写清楚为什么，否则审计里只有一个'forced'"
      printf '%s\n' "$ev" >&2
      return 1
    fi
    printf 'FORCED：PM 显式覆盖（理由：%s）\n%s\n' "$reason" "$ev"
    return 0
  fi
  printf '%s\n' "$ev" >&2
  team_err "没有可核对的证据（BOARD 未改动）——done 是一句承诺，不能只凭手写"
  team_err "  ① 先复验（判定 PASS）或先合并到 $TEAM_PROTECTED_BRANCH：$TEAM_CLI review $id --dir <独立checkout>"
  team_err "  ② PM 确认可以直接 done：TEAM_BOARD_DONE_FORCE=1 TEAM_BOARD_DONE_REASON=\"为什么\" $label"
  return 1
}

# 审计：每次真的写上 done 都留一条（含当时核对了什么 / 为什么覆盖）
team_done_record() { # <ID> <命令标签> <team_done_gate 的判定行及明细>
  local id="$1" label="$2" ev="$3" f
  f="$TEAM_DOCS_ABS/reviews/$id-done.md"
  mkdir -p "$(dirname "$f")"
  {
    [ -s "$f" ] && printf '\n'
    printf -- '- %s · `%s` · %s\n' "$(team_timestamp)" "$label" "$(printf '%s' "$ev" | head -1)"
    printf '%s' "$ev" | tail -n +2 | sed 's/^/  - /'
  } >> "$f"
  return 0
}

team_board_set() { # <id> <status> → 未知 id / done 无证据：返回 1 且**不写文件**
  local f="$TEAM_DOCS_ABS/BOARD.md" id="$1" st="$2" ev="" label
  [ -f "$f" ] || return 1
  if ! team_board_has "$id"; then
    team_err "BOARD 里没有 $id：没有改动，也不算「更新成功」"
    local ids; ids="$(team_board_ids | tr '\n' ' ')"
    [ -n "${ids// /}" ] && team_err "  现有 id：${ids% }"
    team_err "  新增一行：$TEAM_CLI board add $id <标题>（或先 $TEAM_CLI task $id --title …）"
    return 1
  fi
  label="$TEAM_CLI board set $id $st"
  if [ "$st" = "done" ]; then
    ev="$(team_done_gate "$id" "$label")" || return 1
    team_dim "  done 证据：$(printf '%s' "$ev" | head -1)"
  fi
  team_board_write "$id" "$st" || return 1
  [ "$st" = "done" ] && team_done_record "$id" "$label" "$ev"
  return 0
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
  # 替换用 bash 参数展开（不经过 sed —— sed 替换串里 & = 命中文本）。
  # 但 bash 5.2+ 默认打开 patsub_replacement，替换串里的 & 同样会变成"命中文本"：
  # 于是 TEAM_GATES="a && b" 会渲染成 "a {{GATES}}{{GATES}} b"（erp 实测踩过）。
  # 所以这里显式关掉它，替换完再恢复。
  local tmpl="$1"; shift
  local out kv k v had_pr=0
  if shopt -q patsub_replacement 2>/dev/null; then had_pr=1; shopt -u patsub_replacement; fi
  out="$(cat "$tmpl")"
  for kv in "$@"; do
    k="${kv%%=*}"; v="${kv#*=}"
    out="${out//\{\{$k\}\}/$v}"
  done
  [ "$had_pr" = "1" ] && shopt -s patsub_replacement
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
      "$TEAM_DOCS_DIR/"*|.pi/team/*|"${TEAM_TOKEN_FILE:-.gh-pat}"|"${TEAM_GITLAB_TOKEN_FILE:-.gitlab-pat}")
        [ "${TEAM_DEBUG:-0}" = "1" ] && printf 'ignored: %s\n' "$line" >&2 ; continue ;;
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

# ---------------------------------------------------------------- pi 可执行文件（窗口 PATH 就绪竞态，erp 实测）
# dispatch/resume 在窗口 shell 加载完 PATH 前就 exec pi → "pi: command not found"。
# 对策：解析成绝对路径写进窗口命令 + 派单前先校验存在。
# 注：team_pi_bin_path 定义在本节末尾（agent adapter 的兜底分支会调用它）。
# JSON 字符串转义（paths --json 要让机器读得懂）
team_json_escape() {
  local v="$1"
  v="${v//\\/\\\\}"
  v="${v//\"/\\\"}"
  printf '%s\n' "$v"
}

# ---------------------------------------------------------------- agent adapter（任意 TUI agent）
# 契约：teamsmith 负责「在 tmux 窗口里 cd 到 worktree、等二进制就绪、把提示词交给 agent CLI」，
# 而「agent CLI 怎么调用」由 TEAM_AGENT_CMD 模板描述；为空时走内置 Pi 命令（与历史逐字节一致）。
# 占位符清单是**唯一真相**：错误信息、校验、文档与 smoke 自测都从这几个函数取，不各写一份。
team_agent_placeholders() { # <launch|notify> → 每行一个支持的占位符
  case "${1:-launch}" in
    launch) printf '%s\n' '{cwd}' '{session_id}' '{model}' '{provider}' '{prompt_file}' '{prompt}' '{skill_dir}' '{notify_ext}' '{extra_args}' ;;
    notify) printf '%s\n' '{summary}' '{summary_file}' '{agent}' '{cwd}' '{session_id}' '{model}' '{provider}' '{skill_dir}' ;;
    *) team_die "team_agent_placeholders: 未知 kind ${1:-}（launch|notify）" ;;
  esac
}

team_trim() { # 去掉首尾空白（含换行）
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s\n' "$s"
}

team_one_line() { # <文本> → 单行（收件箱是一行一条）；不做任何 shell 解释，其余字节原样
  local s="$1"
  s="$(printf '%s' "$s" | tr -d '\r' | tr '\n' ' ')"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s\n' "$s"
}

# 模板里所有「看起来想当占位符」的 token（含畸形形态：{ cwd } / {cwd } / {{cwd}} / {cwd'}'）。
# 规则：从 { 起找到第一个 }，中间去掉首尾空白/花括号/引号后形如标识符 → 是占位符候选；
# 跳过 ${VAR}（前面是 $，那是 shell 变量展开，不是我们的占位符）。
# 用 awk 逐字符扫，是为了 catch 那些「既不展开也不报错、原样进命令行」的 typo（F4）。
team_agent_token_candidates() { # <模板> → 每行一个候选（原样，含花括号）
  printf '%s' "$1" | awk '
    { s = s $0 "\n" }
    END {
      q = sprintf("%c", 39); d = sprintf("%c", 34)
      n = length(s); i = 1
      while (i <= n) {
        if (substr(s, i, 1) == "{" && (i == 1 || substr(s, i-1, 1) != "$")) {
          rest = substr(s, i+1); j = index(rest, "}")
          if (j > 0) {
            mid = substr(rest, 1, j-1)
            if (mid ~ /^[A-Za-z_][A-Za-z0-9_]*$/) {
              print "{" mid "}"          # 正常形态：就是它，别再吞后面的引号/括号
              i = i + 1 + j
              continue
            }
            t = mid
            gsub("^[[:space:]{}]+", "", t)
            gsub("[[:space:]{}]+", "", t)
            gsub("^[" q "]+", "", t); gsub("[" q "]+$", "", t)
            if (t ~ /^[A-Za-z_][A-Za-z0-9_]*$/) {
              # 畸形写法：把紧跟其后的多余 } 与引号一起算进来，报错里原样回显他敲的东西
              ext = 0
              while (1) {
                c = substr(rest, j+1+ext, 1)
                if (c == "}" || c == q || c == d) ext++
                else break
              }
              print "{" mid substr(rest, j, 1+ext)
              i = i + 1 + j + ext
              continue
            }
            i = i + 1 + j
            continue
          }
        }
        i++
      }
    }'
}

# 不是「原样写成 {name} 且在支持集里」的候选 → 全都是错的（含只差空格/双花括号的近似写法）。
team_agent_bogus_tokens() { # <kind> <模板> → 每行一个不合法 token
  local kind="$1" tpl="$2" tok known=""
  known="$(team_agent_placeholders "$kind" | tr '\n' ' ')"
  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    case " $known" in *" $tok "*) ;; *) printf '%s\n' "$tok" ;; esac
  done < <(team_agent_token_candidates "$tpl" | sort -u)
}

team_agent_bogus_hint() { # 畸形 token 的补充说明（只差空格/花括号/引号的写法最容易被写出来）
  local tok
  for tok in $1; do
    case "$tok" in
      "{"*)
        case "$tok" in
          *" "*|*'{'*"{"*|*\'*) printf '（注意：占位符必须原样写成 {name}，不能加空格、双花括号或引号）' ;;
        esac ;;
    esac
  done
}

team_agent_kind_var() { # <launch|notify> → 对应的配置键名（错误信息用）
  case "$1" in notify) printf '%s\n' 'TEAM_AGENT_NOTIFY_CMD' ;; *) printf '%s\n' 'TEAM_AGENT_CMD' ;; esac
}

team_agent_adapter_label() { # → "built-in (Pi)" | "custom: <cmd>"
  if [ -n "${TEAM_AGENT_CMD:-}" ]; then printf 'custom: %s\n' "$TEAM_AGENT_CMD"
  else printf 'built-in (Pi)\n'; fi
}

team_agent_check_launch() { # 派单前校验 TEAM_AGENT_CMD：畸形/未知占位符、纯空白、多行 → 直接 die
  local cmd="${TEAM_AGENT_CMD-}" bad
  [ -n "$cmd" ] || return 0                       # 未配置 → 内置 Pi
  [ -n "$(team_trim "$cmd")" ] || \
    team_die "TEAM_AGENT_CMD 只有空白（配了等于没配）：找不到 agent 可执行文件；要么留空走内置 Pi，要么写一条真正的命令"
  case "$cmd" in
    *$'\n'*) team_die "TEAM_AGENT_CMD 含换行：adapter 模板必须是**一条**命令行（第二行会被窗口 shell 当新命令执行）" ;;
  esac
  bad="$(team_agent_bogus_tokens launch "$cmd")"
  if [ -n "$bad" ]; then
    team_die "TEAM_AGENT_CMD 里有未知占位符（含空格/双花括号/引号等畸形写法）：$(printf '%s' "$bad" | tr '\n' ' ')（支持：$(team_agent_support_list launch)）$(team_agent_bogus_hint "$bad")"
  fi
  return 0
}

team_agent_prompt_file() { # <agent> <ID> → 本次派单的提示词文件（{prompt_file} 与排障用）
  printf '%s\n' "$TEAM_STATE_DIR/prompt-$1-$2.md"
}

team_agent_summary_file() { # <agent> <ID> → worker 写「回合结束摘要」的文件（{summary_file} / {summary}）
  printf '%s\n' "$TEAM_STATE_DIR/summary-$1-$2.md"
}

team_agent_support_list() { # <kind> → 支持的占位符，空格分隔（错误信息用，无尾随空格）
  local s; s="$(team_agent_placeholders "$1" | tr '\n' ' ')"
  printf '%s\n' "${s% }"
}

team_agent_cli_name() { # → 给人看的 CLI 名（roster/say 的存活文案；默认仍是 pi）
  local bin
  if [ -n "$(team_trim "${TEAM_AGENT_CMD:-}${TEAM_AGENT_BIN:-}")" ]; then bin="$(team_agent_bin_path)"; basename "$bin"
  else printf 'pi'; fi
}

team_agent_unknown_placeholders() { # <kind> <模板> → 每行一个不合法占位符（空 = 全认识）
  team_agent_bogus_tokens "$1" "$2"
}

# {summary} 的安全替换文本：永远展开成「一个词」的文件读取（$(cat '<path>')），
# 所以 worker 的摘要**不可能**被当 shell 代码执行；按模板里占位符两侧的引号选形态：
#   "{summary}" → $(cat '…')      （外层双引号由模板保留）
#   '{summary}' → '"$(cat '…')'"  （闭合单引号、双引号内取值、再开单引号）
#   其余        → "$(cat '…')"    （自己带一对双引号）
team_agent_summary_ref() { # <前一个字符> <后一个字符> <summary 文件> [<摘要文本>]
  local prev="$1" next="$2" f="$3" text="${4-}" val
  # 调用方直接给了摘要文本（老签名/工具）→ 强引用成「一个词」：能单引号就单引号（可读、字节原样），
  # 含单引号/换行时退回 %q；两条路都不会让文本被 shell 解释。
  # 渲染给 worker 的提示词（没给文本）→ 读摘要文件的引用：$(cat '<path>')
  if [ -n "$text" ]; then
    case "$text" in
      *"'"*|*$'\n'*) val="$(printf '%q' "$text")" ;;
      *)              val="'${text}'" ;;
    esac
  else val="$(printf '$(cat %q)' "$f")"; fi
  if [ "$prev" = '"' ] && [ "$next" = '"' ]; then printf '%s\n' "$val"
  elif [ "$prev" = "'" ] && [ "$next" = "'" ]; then printf "'%s'\n" "\"$val\""
  else printf '"%s"\n' "$val"; fi
}

# 展开模板：值统一 %q 转义（命令一定是「可直接交给 shell 的单行」）。
# 例外：{prompt} → "$0"（窗口 harness 以 argv[0] 传提示词，避免超长命令行）；
#       {extra_args} → 原样插入（引号由模板作者负责）；
#       {summary} → 文件读取引用（见 team_agent_summary_ref，摘要永远是数据）。
# **单趟从左到右扫描**：插入的值不会再被当模板扫一遍（{extra_args} 里写 {cwd} 也不会二次展开）。
team_agent_expand() { # <kind> <模板> <agent> <session_id> <worktree> <prompt_file> [<summary_file>] [<summary_text>]
  local kind="$1" tpl="$2" agent="$3" sid="$4" wt="$5" prompt_file="$6" sfile="${7-}" stext="${8-}"
  local bad tok val model provider out="" head prev next
  bad="$(team_agent_bogus_tokens "$kind" "$tpl")"
  if [ -n "$bad" ]; then
    team_die "$(team_agent_kind_var "$kind") 里有未知占位符（含空格/双花括号/引号等畸形写法）：$(printf '%s' "$bad" | tr '\n' ' ')（支持：$(team_agent_support_list "$kind")）$(team_agent_bogus_hint "$bad")"
  fi
  model="$(team_state_get "$agent" model "$(team_agent_model "$agent")")"
  provider="${model%%/*}"
  while [ -n "$tpl" ]; do
    case "$tpl" in
      *'{'*) ;;
      *) out="$out$tpl"; break ;;
    esac
    head="${tpl%%\{*}"                 # 第一个 { 之前
    out="$out$head"
    tpl="${tpl#"$head"}"
    tok="${tpl%%\}*}"; tok="${tok}}"  # 从 { 到第一个 }（含）
    tpl="${tpl#"${tok%\}}"}"; tpl="${tpl#\}}"
    case "$tok" in
      '{cwd}')         val="$(printf '%q' "$wt")" ;;
      '{session_id}')  val="$(printf '%q' "$sid")" ;;
      '{model}')       val="$(printf '%q' "${model##*/}")" ;;
      '{provider}')    val="$(printf '%q' "$provider")" ;;
      '{prompt_file}') val="$(printf '%q' "$prompt_file")" ;;
      '{prompt}')      val='"$0"' ;;
      '{skill_dir}')   val="$(printf '%q' "$TEAM_SKILL_DIR")" ;;
      '{notify_ext}')  val="$(printf '%q' "$TEAM_SKILL_DIR/extension/team-notify.ts")" ;;
      '{extra_args}')  val="${TEAM_EXTRA_PI_ARGS:-}" ;;
      '{summary_file}') val="$(printf '%q' "$sfile")" ;;
      '{summary}')
        prev=""; next=""
        [ -n "$head" ] && prev="${head: -1}"
        [ -n "$tpl" ] && next="${tpl:0:1}"
        val="$(team_agent_summary_ref "$prev" "$next" "$sfile" "$stext")" ;;
      '{agent}')       val="$(printf '%q' "$agent")" ;;
      *) val="$tok" ;;                 # 不是占位符的花括号（JSON body、awk 程序…）原样保留
    esac
    out="$out$val"
  done
  printf '%s\n' "$out"
}

# 启动命令：空 TEAM_AGENT_CMD → 内置 Pi（默认路径，输出与历史逐字节一致）；否则展开模板。
# 提示词通过窗口 harness 的 argv[0]（shell 里的 "$0"）传入，模板里用 {prompt} 取。
team_agent_launch_cmd() { # <agent> <session_id> <worktree> <prompt_file>
  local agent="$1" sid="$2" wt="$3" prompt_file="$4" model pi_bin piargs
  if [ -n "${TEAM_AGENT_CMD:-}" ]; then
    team_agent_expand launch "$TEAM_AGENT_CMD" "$agent" "$sid" "$wt" "$prompt_file"
    return 0
  fi
  model="$(team_state_get "$agent" model "$(team_agent_model "$agent")")"
  pi_bin="$(team_pi_bin_path)"
  piargs="$(team_pi_args "$model")"
  printf '%s %s--session-id %q "$0"' "$(printf '%q' "$pi_bin")" "$piargs" "$sid"
}

# 回合结束通知命令（worker 的摘要永远走文件通道：写进 <summary_file>，命令里不含 worker 文本）。
team_agent_notify_cmd() { # <agent> <session_id> <worktree> <summary_file> [<摘要文本（会被 %q 引用，工具/测试用）>]
  [ -n "${TEAM_AGENT_NOTIFY_CMD:-}" ] || return 0
  team_agent_expand notify "$TEAM_AGENT_NOTIFY_CMD" "$1" "$2" "$3" "" "$4" "${5-}"
}

# notify 模板「看起来可用吗」：有问题时每行一条原因打到 stdout（dispatch 只警告、不阻断派单 ——
# 这是 M3.0 的契约；提示词那边会用同一个判断把整段换成「写进报告」，见 F8）。
# 检查项：① 不是纯空白；② 单行；③ 无畸形/未知占位符；④ 首词能解析到（首词带 $/{/引号时跳过，那是命令替换不是可执行名）。
team_agent_notify_issues() {
  local tpl="${TEAM_AGENT_NOTIFY_CMD:-}" bad agent first
  [ -n "$tpl" ] || return 0
  if [ -z "$(team_trim "$tpl")" ]; then printf '只有空白\n'; return 0; fi
  if [ -z "$(team_trim "${TEAM_AGENT_CMD:-}")" ]; then
    printf 'TEAM_AGENT_CMD 为空（内置 Pi 用自己的通知扩展，提示词不会带这段）：要自定义通知就同时配 TEAM_AGENT_CMD\n'
  fi
  case "$tpl" in *$'\n'*) printf '是多行模板（notify 命令必须单行）\n' ;; esac
  bad="$(team_agent_bogus_tokens notify "$tpl")"
  [ -n "$bad" ] && printf '占位符不认识：%s（支持：%s）\n' "$(printf '%s' "$bad" | tr '\n' ' ')" "$(team_agent_support_list notify)"
  agent="${TEAM_AGENTS%% *}"; agent="${agent:-dev}"
  first="$(team_agent_cmd_first_word notify "$tpl" "$agent")"
  case "$first" in
    ''|*'$'*|*'{'*|*'"'*|*"'"*) ;;      # 命令替换/占位符开头 → 无法用 command -v 判，跳过
    *) command -v "$first" >/dev/null 2>&1 || printf '首词不可执行：%s\n' "$first" ;;
  esac
  return 0
}

# 兼容旧名（M3.0 的测试与文档提到过它）：返回非 0 表示「有问题」，原因打到 stdout。
team_agent_notify_check() {
  local issues; issues="$(team_agent_notify_issues)"
  [ -z "$issues" ] && return 0
  printf '%s\n' "$issues"
  return 1
}

# adapter 的可执行文件：TEAM_AGENT_BIN > TEAM_AGENT_CMD 首词 > TEAM_PI_BIN。
# 用于 dispatch 的「窗口 PATH 就绪」等位与存在性检查，以及 doctor 的解析结论。
# 首词必须是个**裸**可执行名（不带引号）：带引号的 "my agent" 无法在 shell 外解析成可执行文件，
# 这种模板要么把名字写裸，要么用 TEAM_AGENT_BIN 显式指定。
team_agent_cmd_first_word() { # <launch|notify> <模板> [<agent>]
  local kind="${1:-launch}" tpl="$2" agent="${3:-}" expanded sfile
  [ -n "$agent" ] || { agent="${TEAM_AGENTS%% *}"; agent="${agent:-dev}"; }
  sfile="$(team_agent_summary_file "$agent" sample)"
  case "$tpl" in
    *'{'*)
      # 不合法占位符交给 team_agent_check_launch / team_agent_expand 报错（这里不抢报，避免重复刷屏）
      if [ -n "$(team_agent_bogus_tokens "$kind" "$tpl")" ]; then expanded="$tpl"
      else expanded="$(team_agent_expand "$kind" "$tpl" "$agent" "${TEAM_SESSION:-teamsmith}-$agent" "$TEAM_MAIN_ROOT" "$(team_agent_prompt_file "$agent" sample)" "$sfile")"; fi ;;
    *)     expanded="$tpl" ;;
  esac
  printf '%s' "$expanded" | awk '{print $1}'
}

team_pi_bin_path() {
  local bin="${TEAM_PI_BIN:-pi}" p
  case "$bin" in /*) printf '%s\n' "$bin"; return 0 ;; esac
  p="$(command -v "$bin" 2>/dev/null | head -1)"
  if [ -n "$p" ]; then printf '%s\n' "$p"; else printf '%s\n' "$bin"; fi
}

team_agent_bin_path() { # → 绝对路径（在 PATH 里）或原样首词
  local bin p cmd
  cmd="$(team_trim "${TEAM_AGENT_CMD:-}")"
  bin="$(team_trim "${TEAM_AGENT_BIN:-}")"
  if [ -z "$bin" ] && [ -n "$cmd" ]; then bin="$(team_agent_cmd_first_word launch "$cmd")"; fi
  if [ -z "$bin" ]; then team_pi_bin_path; return 0; fi
  case "$bin" in /*) printf '%s\n' "$bin"; return 0 ;; esac
  p="$(command -v "$bin" 2>/dev/null | head -1)"
  if [ -n "$p" ]; then printf '%s\n' "$p"; else printf '%s\n' "$bin"; fi
}

# ---------------------------------------------------------------- 必需依赖（D10）：magic-context + OpenSpec
# 两者都不是可选项：缺 magic-context → PM 的长期记忆是空的（只能靠 /compact + 落盘）；
# 缺 OpenSpec → 项目没有「为什么改/改成什么」的规格层（teamsmith 不再长第二套 spec 体系）。
# 缺它们**不阻止**派单（worker 照样能干活），但 doctor 会判失败、dispatch 会告警，让 PM 看见。

# magic-context 的版本（检测不到 → 空）：只看 Pi 的 settings.json 里有没有这个包，
# 再去包自己的 package.json 取版本。**不读任何凭据文件。**
# 包的位置跟着 settings 文件走（默认 $HOME/.pi/agent/settings.json → $HOME/.pi/agent/npm/node_modules/…），
# 所以 TEAM_PI_SETTINGS_FILE 指向别处（测试/多用户）时也能一致地找到包。
team_magic_context_version() {
  local settings="${TEAM_PI_SETTINGS_FILE:-$HOME/.pi/agent/settings.json}" pkg
  [ -f "$settings" ] || return 0
  grep -q 'pi-magic-context' "$settings" 2>/dev/null || return 0
  pkg="$(dirname "$settings")/npm/node_modules/@cortexkit/pi-magic-context/package.json"
  sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$pkg" 2>/dev/null | head -1
}

# OpenSpec CLI：绝对路径优先，否则在 PATH 里解析（与 TEAM_PI_BIN 同一套路）
team_openspec_bin_path() {
  local bin="${TEAM_OPENSPEC_BIN:-openspec}" p
  case "$bin" in /*) printf '%s\n' "$bin"; return 0 ;; esac
  p="$(command -v "$bin" 2>/dev/null | head -1)"
  if [ -n "$p" ]; then printf '%s\n' "$p"; else printf '%s\n' "$bin"; fi
}

# 项目里的 spec 根目录（TEAM_SPEC_DIR 相对路径按主工作树解析）
team_spec_dir_abs() {
  case "${TEAM_SPEC_DIR:-openspec}" in
    /*) printf '%s\n' "$TEAM_SPEC_DIR" ;;
    *)  printf '%s\n' "$TEAM_MAIN_ROOT/${TEAM_SPEC_DIR:-openspec}" ;;
  esac
}

# 必需依赖的体检：每行一个「问题 + 修复/降级说明」（空 = 都齐）。
# dispatch 用它告警、bootstrap 用它打修复命令，doctor 用上面的小函数逐项报三态。
team_required_dep_issues() {
  local bin
  if [ "${TEAM_REQUIRE_MAGIC_CONTEXT:-1}" = "1" ]; then
    [ -n "$(team_magic_context_version)" ] || \
      printf 'magic-context 没检测到：装 pi 包 @cortexkit/pi-magic-context（settings 在非标准位置时设 TEAM_PI_SETTINGS_FILE；环境特殊可 TEAM_REQUIRE_MAGIC_CONTEXT=0 降级）\n'
  fi
  if [ "${TEAM_REQUIRE_OPENSPEC:-1}" = "1" ]; then
    bin="$(team_openspec_bin_path)"
    command -v "$bin" >/dev/null 2>&1 || \
      printf 'OpenSpec CLI 找不到（%s）：装上它并确保在 PATH 里，或设 TEAM_OPENSPEC_BIN 指向绝对路径（临时可 TEAM_REQUIRE_OPENSPEC=0 降级）\n' "$bin"
    [ -d "$(team_spec_dir_abs)" ] || \
      printf 'spec 目录不存在（%s）：在项目里跑 openspec init --tools none\n' "$TEAM_SPEC_DIR"
  fi
  return 0
}

# 把值转成可以安全放进 config.sh 双引号里的形式（$ ` \ " 在 source 时会被当代码解析）
team_escape_dq() {
  local v="$1"
  v="${v//\\/\\\\}"
  v="${v//\"/\\\"}"
  v="${v//\$/\\$}"
  v="${v//\`/\\\`}"
  printf '%s\n' "$v"
}
