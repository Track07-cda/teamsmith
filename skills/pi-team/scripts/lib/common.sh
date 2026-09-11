#!/usr/bin/env bash
# pi-team · 公共库：配置解析、路径推导、tmux/git 辅助、守卫。
# 由 scripts/team 与各 cmd-*.sh source；不要直接执行。
# 约定：所有函数名以 team_ 前缀；不依赖 jq / python / node。

TEAM_VERSION="1.1.0"

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
  local src="${BASH_SOURCE[0]}" dir
  while [ -L "$src" ]; do
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    case "$src" in /*) ;; *) src="$dir/$src" ;; esac
  done
  ( cd -P "$(dirname "$src")/../.." && pwd )
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
  local common
  common="$(team_git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 1
  [ -n "$common" ] || return 1
  ( cd "$(dirname "$common")" && pwd )
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
    set +u
    # shellcheck disable=SC1090
    . "$TEAM_CONFIG"
    set -u
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
  TEAM_PROTECTED_BRANCH="${TEAM_PROTECTED_BRANCH:-main}"
  TEAM_REMOTE="${TEAM_REMOTE:-origin}"
  TEAM_VCS="${TEAM_VCS:-local}"
  TEAM_TOKEN_FILE="${TEAM_TOKEN_FILE:-.gh-pat}"
  TEAM_GITLAB_HOST="${TEAM_GITLAB_HOST:-}"
  TEAM_GITLAB_PROJECT="${TEAM_GITLAB_PROJECT:-}"
  TEAM_GITLAB_TOKEN_FILE="${TEAM_GITLAB_TOKEN_FILE:-$HOME/.gitlab-pa-token}"
  TEAM_GATES="${TEAM_GATES:-}"
  TEAM_PI_BIN="${TEAM_PI_BIN:-pi}"
  TEAM_INSTALL_CMD="${TEAM_INSTALL_CMD:-}"
  TEAM_DEFAULT_MODEL="${TEAM_DEFAULT_MODEL:-deepseek/deepseek-flash}"
  TEAM_MODEL_LIMITS="${TEAM_MODEL_LIMITS:-}"
  TEAM_MIN_FREE_MB="${TEAM_MIN_FREE_MB:-0}"
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
  local f="$TEAM_STATE_DIR/$1.env"
  [ -f "$f" ] || { [ $# -ge 3 ] && printf '%s\n' "$3"; return 0; }
  local v
  v="$(grep -s "^$2=" "$f" | head -1 | cut -d= -f2- || true)"
  if [ -n "$v" ]; then printf '%s\n' "$v"; else [ $# -ge 3 ] && printf '%s\n' "$3"; fi
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

# ---------------------------------------------------------------- 门禁
# 内存守卫：避免在机器已经很吃紧时再起一个 agent（OOM 的代价远高于排队）。
team_available_mb() {
  if team_have_cmd free; then
    free -m | awk '/^Mem:/ {print $7}'
    return 0
  fi
  if team_have_cmd vm_stat; then
    vm_stat | awk '/page size/ {ps=$8} /Pages free/ {gsub(/\./,"",$3); printf "%d", $3*ps/1048576}'
    return 0
  fi
  printf '0'
}

team_mem_guard() {
  [ "${TEAM_MIN_FREE_MB:-0}" -le 0 ] && return 0
  local avail; avail="$(team_available_mb)"
  [ -n "$avail" ] || return 0
  if [ "$avail" -lt "$TEAM_MIN_FREE_MB" ]; then
    team_err "可用内存 ${avail}MB < TEAM_MIN_FREE_MB=${TEAM_MIN_FREE_MB}MB，拒绝派单（OOM 比排队更贵）"
    team_err "确认要继续：TEAM_MIN_FREE_MB=0 team dispatch ..."
    return 1
  fi
  return 0
}

# 模型并发守卫：TEAM_MODEL_LIMITS="kimi-coding/k3=2 openai-codex/gpt-5.6-sol=1"
team_model_limit() {
  local want="$1" pair
  for pair in $(printf '%s' "$TEAM_MODEL_LIMITS" | tr '\n\t' '  '); do
    case "$pair" in
      "$want"=*) printf '%s\n' "${pair#*=}"; return 0 ;;
    esac
  done
  printf '0'
}

team_model_running() { # 统计「活着且用了该模型」的 agent 数
  local want="$1" n=0 a w m
  for a in $(team_agents); do
    m="$(team_state_get "$a" model '')"
    [ "$m" = "$want" ] || continue
    w="$(team_state_get "$a" window "$a")"
    if team_tmux_has_window "$TEAM_SESSION" "$w"; then n=$((n + 1)); else team_state_clear "$a"; fi
  done
  printf '%s\n' "$n"
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
  local f="$TEAM_DOCS_ABS/BOARD.md" id="$1" st="$2"
  [ -f "$f" ] || return 1
  awk -v id="$id" -v st="$st" 'BEGIN{FS=OFS="|"}
    /^\|/ && $2 ~ "^[[:space:]]*"id"[[:space:]]*$" { n=NF; gsub(/^[[:space:]]+|[[:space:]]+$/,"",$(n-1)); $(n-1)=" "st" "; print; found=1; next }
    { print }
  ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

team_board_add() { # <id> <title> <agent> <branch> <deps>
  local f="$TEAM_DOCS_ABS/BOARD.md"
  [ -f "$f" ] || return 1
  printf '| %s | %s | %s | %s | %s | todo |\n' "$1" "$2" "$3" "$4" "${5:--}" >> "$f"
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
team_board_row() { # <id> → 整行
  local f="$TEAM_DOCS_ABS/BOARD.md"
  [ -f "$f" ] || return 1
  awk -v id="$1" 'BEGIN{FS="|"} /^\|/ && $2 ~ "^[[:space:]]*"id"[[:space:]]*$" {print}' "$f"
}
