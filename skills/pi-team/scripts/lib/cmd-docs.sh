#!/usr/bin/env bash
# pi-team · 文档契约：task / board / thread / report / smoke

team_cmd_task() {
  team_require_docs
  local id="" title="" agent="" deps="-" issue="" slug=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --title) title="${2:?}"; shift 2 ;;
      --agent) agent="${2:?}"; shift 2 ;;
      --deps)  deps="${2:?}"; shift 2 ;;
      --issue) issue="${2:?}"; shift 2 ;;
      --slug)  slug="${2:?}"; shift 2 ;;
      -*) team_usage_die "task: 未知参数 $1" ;;
      *) id="$1"; shift ;;
    esac
  done
  [ -n "$id" ] || team_usage_die "task <ID> --title \"...\" [--agent a] [--deps ...] [--issue N]"
  [ -n "$title" ] || title="<未命名>"
  agent="${agent:-$(team_agents | head -1)}"
  slug="${slug:-$(team_slug "$title")}"
  [ -n "$slug" ] || slug="task"      # 非 ASCII 标题（中文）slug 会空 → 用 task 兜底，避免 "T1.1-.md"
  local file="$TEAM_DOCS_ABS/tasks/$id-$slug.md"
  [ -f "$file" ] && team_die "任务书已存在：$file"

  team_render "$(team_tmpl_dir)/task.md.tmpl" \
    "ID=$id" "TITLE=$title" "AGENT=$agent" "DEPS=$deps" "ISSUE=$issue" "SLUG=$slug" \
    "PROJECT=$TEAM_PROJECT" "DOCS_DIR=$TEAM_DOCS_DIR" "GATES=${TEAM_GATES:-<未配置：先跟 PM 约定验收命令>}" \
    "DATE=$(date +%F)" > "$file"
  team_ok "write $file"

  if [ -z "$(team_board_row "$id" 2>/dev/null || true)" ]; then
    team_board_add "$id" "$title" "$agent" "-" "$deps"
    team_ok "board add $id"
  fi
  team_dim "  下一步：编辑任务书（写清背景/交付物/边界/验收命令）→ $TEAM_CLI add-agent $agent → dispatch"
}

team_cmd_board() {
  team_require_docs
  local sub="${1:-ls}"; shift || true
  case "$sub" in
    ls)
      grep -E '^\|' "$TEAM_DOCS_ABS/BOARD.md" 2>/dev/null || team_warn "BOARD.md 还没有行"
      local warn; warn="$(team_board_layout_warning || true)"
      [ -n "$warn" ] && team_dim "  $warn"
      local ign; ign="$(team_reports_ignored || true)"
      [ -n "$ign" ] && team_dim "  （reports/ 里按规则忽略的非任务报告：$(printf '%s' "$ign" | tr '\n' ' ')）"
      ;;
    add)
      local id="${1:?usage: board add <ID> <title> [agent] [deps]}" title="${2:?}" agent="${3:-$(team_agents | head -1)}" deps="${4:--}"
      team_board_add "$id" "$title" "$agent" "-" "$deps"; team_ok "board add $id" ;;
    set)
      local id="${1:?usage: board set <ID> <status>}" st="${2:?}"
      case "$st" in todo|wip|review|done|blocked|dropped) ;; *) team_die "状态非法：$st（todo|wip|review|done|blocked|dropped）" ;; esac
      team_board_set "$id" "$st" || team_die "BOARD.md 更新失败"
      team_ok "board $id → $st" ;;
    row)
      team_board_row "${1:?usage: board row <ID>}" ;;
    *) team_usage_die "board: 未知子命令 $sub（ls|add|set|row）" ;;
  esac
}

team_cmd_thread() {
  team_require_docs
  local agent="" from="pm" re="-" body=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --from) from="${2:?}"; shift 2 ;;
      --re) re="${2:?}"; shift 2 ;;
      -*) team_usage_die "thread: 未知参数 $1" ;;
      *) if [ -z "$agent" ]; then agent="$1"; else body="$1"; fi; shift ;;
    esac
  done
  [ -n "$agent" ] || team_usage_die "thread <agent> [\"消息\"] [--from pm|agent:<a>] [--re <ID>]"
  local f="$TEAM_DOCS_ABS/threads/$agent.md"
  mkdir -p "$(dirname "$f")"
  if [ -z "$body" ]; then
    [ -f "$f" ] && cat "$f" || team_warn "线程还没有内容：$f"
    return 0
  fi
  { [ -s "$f" ] && printf '\n'; printf '### %s · from: %s · re: %s\n%s\n' "$(team_timestamp)" "$from" "$re" "$body"; } >> "$f"
  team_ok "thread $agent += 1 条（from $from）"
}

team_cmd_report() {
  team_require_docs
  local id="" agent="" force=0 status="DONE"
  while [ $# -gt 0 ]; do
    case "$1" in
      --force) force=1; shift ;;
      --status) status="${2:?}"; shift 2 ;;
      -*) team_usage_die "report: 未知参数 $1" ;;
      *) if [ -z "$id" ]; then id="$1"; else agent="$1"; fi; shift ;;
    esac
  done
  [ -n "$id" ] && [ -n "$agent" ] || team_usage_die "report <ID> <agent> [--force] [--status DONE|PARTIAL|BLOCKED]"
  local file="$TEAM_DOCS_ABS/reports/$id-$agent.md"
  if [ -f "$file" ] && [ "$force" != "1" ]; then
    team_dim "skip  $file（已存在，--force 覆盖）"; return 0
  fi
  team_render "$(team_tmpl_dir)/report.md.tmpl" \
    "ID=$id" "AGENT=$agent" "STATUS=$status" "DOCS_DIR=$TEAM_DOCS_DIR" \
    "TIME=$(team_timestamp)" "BRANCH=$(git -C "$(team_agent_worktree "$agent")" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '-')" \
    > "$file"
  team_ok "write $file"
}

team_cmd_smoke() {
  local t="$TEAM_SKILL_DIR/tests/smoke.sh"
  [ -f "$t" ] || team_die "缺 $t"
  bash "$t" "$@"
}
