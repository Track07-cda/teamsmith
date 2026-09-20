#!/usr/bin/env bash
# teamsmith · 文档契约：task / board / thread / report / smoke

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
      # M48：同一 ID 多行必须看得见（面板焦点/状态/报告都按 ID 指行；重复只靠肉眼就太晚了）
      local dups; dups="$(team_board_duplicate_line || true)"
      [ -n "$dups" ] && team_warn "  $dups（board set / assign 按 ID 寻址，同 ID 的多行一起改；board add 会拒绝新重复）"
      local ign; ign="$(team_reports_ignored || true)"
      [ -n "$ign" ] && team_dim "  （reports/ 里按规则忽略的非任务报告：$(printf '%s' "$ign" | tr '\n' ' ')）"
      ;;
    add)
      # M48：--allow-dup 是显式逃生门（写进审计）；位置参数仍是 <ID> <title> [agent] [deps]
      local allow=0 args=() a
      for a in "$@"; do
        case "$a" in
          --allow-dup) allow=1 ;;
          -) args+=("-") ;;                        # deps 的「无」是裸连字符，不是选项
          --*) team_usage_die "board add: 未知参数 $a（--allow-dup = 显式允许同 ID 多行）" ;;
          *) args+=("$a") ;;
        esac
      done
      local id="${args[0]:?usage: board add <ID> <title> [agent] [deps] [--allow-dup]}" title="${args[1]:?}" agent="${args[2]:-$(team_agents | head -1)}" deps="${args[3]:--}"
      team_board_add "$id" "$title" "$agent" "-" "$deps" "$allow" || return 1
      if [ "$allow" = "1" ]; then team_ok "board add $id（--allow-dup：同 ID 多行）"; else team_ok "board add $id"; fi ;;
    assign)
      # M48：给已有行指派 agent 的正门（只改 agent 列，行数不变）。以前只能再 add 一行 → 重复 ID。
      [ -n "${1:-}" ] && [ -n "${2:-}" ] || team_usage_die "board: usage: board assign <ID> <agent>"
      team_board_assign "$1" "$2" || team_die "BOARD.md 没有改动（未知 id）"
      team_ok "board assign $1 → $2" ;;
    set)
      local id="${1:?usage: board set <ID> <status>}" st="${2:?}"
      case "$st" in todo|wip|review|done|blocked|dropped) ;; *) team_die "状态非法：$st（todo|wip|review|done|blocked|dropped）" ;; esac
      team_board_set "$id" "$st" || team_die "BOARD.md 更新失败"
      team_ok "board $id → $st" ;;
    row)
      team_board_row "${1:?usage: board row <ID>}" ;;
    *) team_usage_die "board: 未知子命令 $sub（ls|add|assign|set|row）" ;;
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
    [ -f "$f" ] && cat "$f" || team_warn "往来记录还没有内容：$f"
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
