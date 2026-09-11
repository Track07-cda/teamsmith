#!/usr/bin/env bash
# pi-team · 复验 / 合并 / 收尾：review / merge / pr / close
#
# 设计要点（来自 CEP 的教训）：agent 的自述不算证据，PM 必须在**独立 worktree** 上
# checkout 该分支、跑门禁、看 diff，并把结论写成 <docs>/reviews/<ID>.md。

# 解析分支：--branch > 任务在跑的 agent 的当前分支 > 唯一的 task/<ID>-* 分支
team_resolve_branch() { # <ID> [--branch b]
  local id="$1" branch="${2:-}" a wt b found=""
  if [ -n "$branch" ]; then printf '%s\n' "$branch"; return 0; fi
  for a in $(team_agents); do
    [ "$(team_state_get "$a" task '')" = "$id" ] || continue
    wt="$(team_agent_worktree "$a")"
    [ -d "$wt" ] || continue
    b="$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    case "$b" in ""|HEAD) ;; *) printf '%s\n' "$b"; return 0 ;; esac
  done
  while IFS= read -r b; do
    case "$b" in
      */"$id"-*|*/"$id") [ -n "$found" ] && { found="AMBIGUOUS"; break; }; found="$b" ;;
    esac
  done < <(git -C "$TEAM_MAIN_ROOT" for-each-ref --format='%(refname:short)' "refs/heads/$TEAM_TASK_BRANCH_PREFIX/")
  case "$found" in
    "") team_die "找不到 $id 的分支：用 --branch 指定" ;;
    AMBIGUOUS) team_die "$id 有多个候选分支，用 --branch 指定" ;;
    *) printf '%s\n' "$found" ;;
  esac
}

team_task_title() { # <ID> → 标题（BOARD 行第 3 列，其次任务书第一行 #）
  local row t f
  row="$(team_board_row "$1" 2>/dev/null || true)"
  if [ -n "$row" ]; then
    t="$(printf '%s' "$row" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$3); print $3}')"
    [ -n "$t" ] && { printf '%s\n' "$t"; return 0; }
  fi
  for f in "$TEAM_DOCS_ABS/tasks/$1-"*.md; do
    [ -f "$f" ] || continue
    sed -n '1{/^#/p}' "$f" | sed -e 's/^#[[:space:]]*//' -e "s/^$1[[:space:]]*·[[:space:]]*//"
    return 0
  done
  printf '%s\n' "$1"
}

team_cmd_review() {
  team_require_docs
  local id="" branch="" no_gates=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --branch) branch="${2:?}"; shift 2 ;;
      --no-gates) no_gates=1; shift ;;
      -*) team_usage_die "review: 未知参数 $1" ;;
      *) id="$1"; shift ;;
    esac
  done
  [ -n "$id" ] || team_usage_die "review <ID> [--branch b] [--no-gates]"
  branch="$(team_resolve_branch "$id" "$branch")"

  local revdir="$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR/review-$id"
  local ref="$branch"
  if team_git_main remote get-url "$TEAM_REMOTE" >/dev/null 2>&1; then
    if team_git_main fetch --quiet "$TEAM_REMOTE" "$branch" 2>/dev/null; then
      ref="FETCH_HEAD"
      team_ok "fetched $TEAM_REMOTE/$branch"
    else
      team_warn "fetch $TEAM_REMOTE $branch 失败：用本地分支复验"
    fi
  fi
  if [ -d "$revdir" ]; then
    team_warn "清理旧复验 worktree $revdir"
    team_git_main worktree remove --force "$revdir" >/dev/null 2>&1 || rm -rf "$revdir"
  fi
  team_git_main worktree add --detach "$revdir" "$ref" >/dev/null
  local head; head="$(git -C "$revdir" rev-parse HEAD)"
  team_ok "review worktree: ${revdir#"$TEAM_MAIN_ROOT"/} @ ${head:0:9}"

  # 报告提交在 agent 分支上（合并前不出现在主工作树）：直接摘录进复验记录，
  # 不往主工作树拷文件（否则会让主工作树变脏、阻塞后续 squash merge）
  local report_excerpt="" branch_report
  for branch_report in "$revdir/$TEAM_DOCS_DIR/reports/$id-"*.md; do
    [ -f "$branch_report" ] || continue
    report_excerpt="$(cat "$branch_report")"
    team_ok "已摘录 agent 报告：${branch_report#"$revdir"/}"
  done

  mkdir -p "$TEAM_DOCS_ABS/reviews"
  local log="$TEAM_DOCS_ABS/reviews/$id-verify.log"
  local verdict="PASS" gates_out=""
  if [ "$no_gates" = "1" ]; then
    verdict="SKIPPED"; gates_out="（--no-gates：PM 选择人工看 diff）"
  elif [ -z "$TEAM_GATES" ]; then
    verdict="UNKNOWN"; gates_out="（TEAM_GATES 未配置：无法自动判定，只能人工评审）"
  else
    team_info "跑门禁：$TEAM_GATES"
    if ( cd "$revdir" && eval "$TEAM_GATES" ) > "$log" 2>&1; then
      verdict="PASS"
    else
      verdict="FAIL"
    fi
    gates_out="$(tail -25 "$log")"
    team_ok "门禁输出：${log#"$TEAM_MAIN_ROOT"/}（${verdict}）"
  fi

  local diffstat commits changed
  diffstat="$(git -C "$revdir" diff --stat "$TEAM_PROTECTED_BRANCH...HEAD" 2>/dev/null | tail -1 || true)"
  commits="$(git -C "$revdir" log --oneline --no-decorate "$TEAM_PROTECTED_BRANCH..HEAD" 2>/dev/null | head -40 || true)"
  changed="$(git -C "$revdir" diff --name-status "$TEAM_PROTECTED_BRANCH...HEAD" 2>/dev/null | head -200 || true)"

  local report="$TEAM_DOCS_ABS/reviews/$id.md"
  {
    printf '# %s · PM 独立复验\n\n' "$id"
    printf '时间: %s · 分支: `%s` · HEAD: `%s` · 判定: **%s**\n\n' "$(team_timestamp)" "$branch" "${head:0:9}" "$verdict"
    printf '## 复验方式\n\n'
    printf -- '- 独立 worktree：`%s`（detached checkout，不信任 agent 工作区）\n' "${revdir#"$TEAM_MAIN_ROOT"/}"
    printf -- '- 门禁命令：`%s`\n' "${TEAM_GATES:-<未配置>}"
    printf -- '- 输出：`%s`\n' "${log#"$TEAM_MAIN_ROOT"/}"
    if team_find_report "$id" >/dev/null 2>&1; then
      printf -- '- agent 报告：`%s`\n' "$(team_find_report "$id")"
    else
      printf -- '- agent 报告：**缺失**（没有报告本身就是问题）\n'
    fi
    printf '\n'
    printf '## 变更概览\n\n```\n%s\n```\n\n' "${diffstat:-（无）}"
    printf '## 提交\n\n```\n%s\n```\n\n' "${commits:-（无）}"
    printf '## 文件\n\n```\n%s\n```\n\n' "${changed:-（无）}"
    printf '## 门禁输出尾部\n\n```\n%s\n```\n\n' "$gates_out"
    if [ -n "$report_excerpt" ]; then
      printf '## agent 报告原文（从分支检出，供对照）\n\n%s\n\n' "$report_excerpt"
    else
      printf '## agent 报告原文\n\n**缺失**：分支上没有 `%s/reports/%s-<agent>.md`，这本身就是问题。\n\n' "$TEAM_DOCS_DIR" "$id"
    fi
    printf '## PM 结论\n\n'
    case "$verdict" in
      PASS) printf -- '- [ ] 已读 diff，与任务书交付物一致\n- [ ] 未发现「报告与实际不符」\n- [ ] 可以合并（`%s merge %s`）\n' "$TEAM_CLI" "$id" ;;
      FAIL) printf -- '- [ ] 门禁失败：退回 agent（`%s say <agent> "..."`）或 PM 自行修复\n' "$TEAM_CLI" ;;
      *)    printf -- '- [ ] 人工评审（门禁未跑/未配置）\n' ;;
    esac
  } > "$report"
  team_ok "复验记录：${report#"$TEAM_MAIN_ROOT"/}（$verdict）"

  [ "$verdict" = "FAIL" ] && return 1
  return 0
}

team_cmd_merge() {
  team_require_docs
  local id="" branch="" push=0 delete_branch=0 no_review=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --branch) branch="${2:?}"; shift 2 ;;
      --push) push=1; shift ;;
      --delete-branch) delete_branch=1; shift ;;
      --no-review-check) no_review=1; shift ;;
      -*) team_usage_die "merge: 未知参数 $1" ;;
      *) id="$1"; shift ;;
    esac
  done
  [ -n "$id" ] || team_usage_die "merge <ID> [--branch b] [--push] [--delete-branch]"
  team_allow_write || return 1
  branch="$(team_resolve_branch "$id" "$branch")"

  if [ "$no_review" != "1" ] && [ ! -f "$TEAM_DOCS_ABS/reviews/$id.md" ]; then
    team_die "没有复验记录：先跑 $TEAM_CLI review $id（或显式 --no-review-check）"
  fi
  if [ "$no_review" != "1" ] && grep -qE '判定: \*\*FAIL\*\*|判定: \*\*UNKNOWN\*\*' "$TEAM_DOCS_ABS/reviews/$id.md" 2>/dev/null; then
    team_warn "复验判定不是 PASS：确认无误后再合并（当前是 PM 的判断责任）"
  fi

  local cur; cur="$(team_git_main rev-parse --abbrev-ref HEAD)"
  [ "$cur" = "$TEAM_PROTECTED_BRANCH" ] || team_die "主工作树当前在 $cur：先 git -C $TEAM_MAIN_ROOT switch $TEAM_PROTECTED_BRANCH"
  # 只有「非文档路径」的改动会阻塞合并：PM 自己的 BOARD/reviews/inbox 不算
  local dirty; dirty="$(team_main_dirty_external 2>/dev/null)"
  if [ -n "$dirty" ]; then
    team_err "主工作树有未提交的代码改动（文档类改动已忽略）："
    printf '%s\n' "$dirty" >&2
    team_die "先提交或撤销这些改动：git -C $TEAM_MAIN_ROOT status"
  fi

  local title; title="$(team_task_title "$id")"
  if ! team_git_main merge --squash "$branch" >/dev/null 2>&1; then
    team_git_main merge --abort >/dev/null 2>&1 || team_git_main reset --merge >/dev/null 2>&1 || true
    if [ -n "$(team_git_main status --porcelain)" ]; then
      team_err "squash merge 冲突/失败，主工作树需要人工处理："
      team_git_main status --short | head -20 >&2
    fi
    team_die "squash merge 失败：$branch → $TEAM_PROTECTED_BRANCH"
  fi
  team_git_main commit -q -m "$id: $title" -m "pi-team: squash merge of $branch" || team_die "commit 失败"
  team_ok "merged $branch → $TEAM_PROTECTED_BRANCH @ $(team_git_main rev-parse --short HEAD)"

  if [ "$push" = "1" ]; then
    team_git_main push "$TEAM_REMOTE" "$TEAM_PROTECTED_BRANCH" && team_ok "pushed $TEAM_PROTECTED_BRANCH"
  else
    team_dim "  未推送：确认后执行 git -C $TEAM_MAIN_ROOT push $TEAM_REMOTE $TEAM_PROTECTED_BRANCH"
  fi
  if [ "$delete_branch" = "1" ]; then
    team_git_main branch -D "$branch" >/dev/null && team_ok "deleted branch $branch"
  fi
  team_board_set "$id" done 2>/dev/null || true
  team_ok "board $id → done"
}

team_cmd_pr() {
  team_require_docs
  local id="" branch="" title="" body=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --branch) branch="${2:?}"; shift 2 ;;
      --title) title="${2:?}"; shift 2 ;;
      --body) body="${2:?}"; shift 2 ;;
      -*) team_usage_die "pr: 未知参数 $1" ;;
      *) id="$1"; shift ;;
    esac
  done
  [ -n "$id" ] || team_usage_die "pr <ID> [--branch b] [--title ...] [--body file]"
  team_allow_write || return 1
  branch="$(team_resolve_branch "$id" "$branch")"
  title="${title:-$id: $(team_task_title "$id")}"
  body="${body:-$(forge_pr_body "$id")}"
  forge_open_pr "$branch" "$title" "$body"
}

team_cmd_close() {
  team_require_docs
  local id="" status="done" keep_window=0 delete_branch=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --status) status="${2:?}"; shift 2 ;;
      --keep-window) keep_window=1; shift ;;
      --delete-branch) delete_branch=1; shift ;;
      -*) team_usage_die "close: 未知参数 $1" ;;
      *) id="$1"; shift ;;
    esac
  done
  [ -n "$id" ] || team_usage_die "close <ID> [--status done|blocked|dropped] [--keep-window] [--delete-branch]"

  local a w b
  for a in $(team_agents); do
    [ "$(team_state_get "$a" task '')" = "$id" ] || continue
    w="$(team_state_get "$a" window "$a")"
    if [ "$keep_window" != "1" ] && team_tmux_has_window "$TEAM_SESSION" "$w"; then
      tmux kill-window -t "$TEAM_SESSION:$w" 2>/dev/null && team_ok "kill window $TEAM_SESSION:$w"
    fi
    team_state_set "$a" task ""
    if [ "$delete_branch" = "1" ]; then
      b="$(git -C "$(team_agent_worktree "$a")" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
      case "$b" in ""|HEAD|"$TEAM_PROTECTED_BRANCH") ;; *) team_git_main branch -D "$b" >/dev/null 2>&1 && team_ok "delete branch $b" ;; esac
    fi
  done
  team_board_set "$id" "$status" 2>/dev/null || team_warn "BOARD 未更新（$id 不在表里？）"
  team_ok "closed $id（status=$status）"
  team_dim "  复验记录 $TEAM_DOCS_DIR/reviews/$id.md 保留；agent worktree 保留（复用）"
}
