#!/usr/bin/env bash
# teamsmith · `team reply` —— 关键回复（key replies）的命令面。
#
#   team reply post --from <label> --title <title> --stdin   显式发布一份正文（正文只从 stdin 来）
#   team reply list [--before <no>] [--json]                 当前页元数据（body-free）
#   team reply show <no> [--json|--raw]                      一份正文；--raw 只在非 TTY 上导出原文
#
# 存储与格式在 scripts/replies.mjs（change: pulse-key-replies · design §2/§3）。
# 身份分类：list/show 是纯观察；post 是修改入口（身份冲突时不许静默按目录动手）。
# 退出码透传 helper：0 成功 / 2 输入 / 4 存储不可用 / 5 锁竞争 / 6 已可见但持久性未确认。

team_reply_usage() {
  cat <<'EOF'
用法：
  team reply post --from <label> --title <title> --stdin
      把 stdin 的原文发布为一份关键回复。--from 是自称的平坦标识符（1–48 个 [A-Za-z0-9._-]），
      不是身份认证；--title 单行、最多 160 个码点、不含终端控制/双向控制；正文 1–131072 字节的合法
      UTF-8、不含 NUL。成功只打印 body-free 回执与编号；保存失败不阻止你照常发送答复。
      退出码：0 已持久化 / 2 输入 / 4 存储不可用 / 5 写锁竞争（≤2s） / 6 已可见但持久性未确认。
  team reply list [--before <no>] [--json]
      最新在前，每页最多 50 个编号槽位；`--before` 是排他游标（正整数）。文本模式每行
      `#no <时间> <自称发布者> <标题>`，坏槽位显示为不可用行。空存储返回 0。
  team reply show <no> [--json|--raw]
      默认打印安全显示文本（终端控制已剥除，正文以原文保存）；`--json` 给机读结构
      （display_text/bytes/sha256，标明是显示表示）；`--raw` 只在非 TTY stdout 上导出**原始字节**，
      不加换行、不执行、不跟随链接。
EOF
}

team_reply_helper_path() {
  local p="$TEAM_SKILL_DIR/scripts/replies.mjs"
  [ -f "$p" ] || p="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)/scripts/replies.mjs"
  printf '%s\n' "$p"
}

team_cmd_reply() {
  local sub="${1:-}"
  case "$sub" in
    post|list|show) shift ;;
    -h|--help|"") team_reply_usage; return 0 ;;
    *) team_usage_die "reply: 未知子命令 ${sub:-}（post|list|show；team reply --help）" ;;
  esac
  local helper; helper="$(team_reply_helper_path)"
  if [ ! -f "$helper" ]; then
    team_err "reply: 缺存储 helper（$helper）——skill 安装不完整"
    return 4
  fi
  local runner; runner="$(team_js_runner)"
  if [ -z "$runner" ]; then
    team_err "reply: 缺少 JS 运行时（node/bun/tsx 都解析不到）——装 node ≥ ${TEAM_JS_MIN_NODE_MAJOR}，或设 TEAM_JS_BIN"
    return 4
  fi

  local state_dir="${TEAM_STATE_DIR:-$TEAM_MAIN_ROOT/.pi/team/state}"
  local -a extra=()
  case "$sub" in
    post)
      # 论据透传；helper 自己校验输入（顺序也是合同的一部分：校验先于开锁）。
      exec "$runner" "$helper" post --main-root "$TEAM_MAIN_ROOT" --state-dir "$state_dir" "$@"
      ;;
    list)
      extra=(--format json)
      while [ $# -gt 0 ]; do
        case "$1" in
          # `+=` 不是 `=`：list 的默认参数已经是 `--format json`，而这里若用赋值会把先前解析到的
          # `--before` 整个丢掉（V27 实测 `--before <no> --json` 静默返回最新页）。
          --json) extra+=(--format json); shift ;;
          --before) extra+=(--before "${2:?--before 需要编号}"); shift 2 ;;
          --before=*) extra+=(--before "${1#*=}"); shift ;;
          -h|--help) team_reply_usage; return 0 ;;
          -*) team_usage_die "reply list: 未知参数 $1" ;;
          *) team_usage_die "reply list: 多余参数 $1" ;;
        esac
      done
      exec "$runner" "$helper" list --main-root "$TEAM_MAIN_ROOT" --state-dir "$state_dir" "${extra[@]}"
      ;;
    show)
      local no="" format="text"
      while [ $# -gt 0 ]; do
        case "$1" in
          --json) format="json"; shift ;;
          --raw) format="raw"; shift ;;
          -h|--help) team_reply_usage; return 0 ;;
          -*) team_usage_die "reply show: 未知参数 $1" ;;
          *) if [ -z "$no" ]; then no="$1"; shift; else team_usage_die "reply show: 多余参数 $1"; fi ;;
        esac
      done
      [ -n "$no" ] || team_usage_die "reply show: 需要编号（team reply show <no> [--json|--raw]）"
      if [ "$format" = "raw" ] && [ -t 1 ]; then
        team_err "reply show --raw 只导出到非 TTY stdout（重定向到文件或管道）"
        return 2
      fi
      exec "$runner" "$helper" show --main-root "$TEAM_MAIN_ROOT" --state-dir "$state_dir" --no "$no" --format "$format"
      ;;
  esac
}
