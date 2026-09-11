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
    # ① state 里记的分支最可靠（task 模式切换任务后仍能定位）
    b="$(team_state_get "$a" branch '')"
    case "$b" in ""|HEAD|"$TEAM_PROTECTED_BRANCH") ;; *) printf '%s\n' "$b"; return 0 ;; esac
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

team_task_title() { # <ID> → 标题（BOARD 的「任务」列，其次任务书第一行 #）
  local row t f
  row="$(team_board_row "$1" 2>/dev/null || true)"
  if [ -n "$row" ]; then
    t="$(team_board_field "$row" task)"
    case "$t" in ""|-|"—") ;; *) [ -n "$t" ] && { printf '%s\n' "$t"; return 0; } ;; esac
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
  local id="" branch="" no_gates=0 strong=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --branch) branch="${2:?}"; shift 2 ;;
      --no-gates) no_gates=1; shift ;;
      --strong) strong=1; shift ;;          # 强复验：要求对抗性验证包 + finding 翻转证据
      -*) team_usage_die "review: 未知参数 $1" ;;
      *) id="$1"; shift ;;
    esac
  done
  [ -n "$id" ] || team_usage_die "review <ID> [--branch b] [--no-gates] [--strong]"
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
  local verdict="PASS" gates_out="" gate_timeout="${TEAM_REVIEW_TIMEOUT:-1800}"
  if [ "$no_gates" = "1" ]; then
    verdict="SKIPPED"; gates_out="（--no-gates：PM 选择人工看 diff）"
  elif [ -z "$TEAM_GATES" ]; then
    verdict="UNKNOWN"; gates_out="（TEAM_GATES 未配置：无法自动判定，只能人工评审）"
  else
    # CEP 教训：池无超时 × 测试无 --test-timeout × bash timeout 设成 1800000s → 门禁挂死 85 分钟。
    # 所以门禁一律套硬超时；超时按 FAIL 处理并明确写进复验记录。
    local runner=()
    if team_have_cmd timeout && [ "${gate_timeout:-0}" -gt 0 ] 2>/dev/null; then
      runner=(timeout --signal=TERM --kill-after=60 "$gate_timeout")
    fi
    team_info "跑门禁：$TEAM_GATES（硬超时 ${gate_timeout}s；可调 TEAM_REVIEW_TIMEOUT）"
    if ( cd "$revdir" && "${runner[@]}" bash -c "$TEAM_GATES" ) > "$log" 2>&1; then
      verdict="PASS"
    else
      verdict="FAIL"
      if [ "${#runner[@]}" -gt 0 ] && grep -q "timeout" "$log" 2>/dev/null; then
        verdict="TIMEOUT"
        printf '\n[pi-team] 门禁在 %ss 未结束，被硬超时终止（判定 TIMEOUT）\n' "$gate_timeout" >> "$log"
      fi
    fi
    gates_out="$(tail -25 "$log")"
    team_ok "门禁输出：${log#"$TEAM_MAIN_ROOT"/}（${verdict}）"
  fi

  local diffstat commits changed
  diffstat="$(git -C "$revdir" diff --stat "$TEAM_PROTECTED_BRANCH...HEAD" 2>/dev/null | tail -1 || true)"
  commits="$(git -C "$revdir" log --oneline --no-decorate "$TEAM_PROTECTED_BRANCH..HEAD" 2>/dev/null | head -40 || true)"
  changed="$(git -C "$revdir" diff --name-status "$TEAM_PROTECTED_BRANCH...HEAD" 2>/dev/null | head -200 || true)"

  # 强复验（CEP 的实践）：要求证据表明「测试真的会失败」——对抗性验证包 + finding 测试翻转
  local strong_lines=""
  if [ "$strong" = "1" ]; then
    local flip=0 indep=0 notes=""
    printf '%s' "$report_excerpt" | grep -qE '翻转|会失败|破坏性验证|control experiment|guard test|regression test' \
      && flip=1
    printf '%s' "$report_excerpt" | grep -qE 'packages/verification|独立(验证)?包|independent (package|suite)' && indep=1
    strong_lines="## 强复验（对抗性验证包 / finding 翻转）\n\n"
    strong_lines="${strong_lines}- 破坏性验证证据（故意改坏实现 → 守门测试必须失败）：$([ "$flip" = 1 ] && echo '有（报告里能找到）' || echo '**缺**：要求 agent 补「修复前红 → 修复后绿」或破坏实验）')\n"
    strong_lines="${strong_lines}- 独立验证包（不复用被测夹具）：$([ "$indep" = 1 ] && echo '有' || echo '**缺**：让 verify agent 在独立包里写对抗测试')\n"
    strong_lines="${strong_lines}- 判定：$([ "$flip" = 1 ] && [ "$indep" = 1 ] && echo '满足强复验' || echo '不满足（不阻塞合并，但里程碑收口前应补齐）')\n"
    [ "$flip" = 1 ] && [ "$indep" = 1 ] || team_warn "强复验证据不完整（flip=$flip independent=$indep）：看复验记录里的清单"
  fi

  local report="$TEAM_DOCS_ABS/reviews/$id.md"
  {
    printf '# %s · PM 独立复验\n\n' "$id"
    printf '时间: %s · 分支: `%s` · HEAD: `%s` · 判定: **%s**\n\n' "$(team_timestamp)" "$branch" "${head:0:9}" "$verdict"
    printf '## 复验方式\n\n'
    printf -- '- 独立 worktree：`%s`（detached checkout，不信任 agent 工作区）\n' "${revdir#"$TEAM_MAIN_ROOT"/}"
    printf -- '- 门禁命令：`%s`（硬超时 %ss；超时判定 TIMEOUT→按 FAIL 处理）\n' "${TEAM_GATES:-<未配置>}" "${TEAM_REVIEW_TIMEOUT:-1800}"
    printf -- '- 输出：`%s`\n' "${log#"$TEAM_MAIN_ROOT"/}"
    if team_find_report "$id" >/dev/null 2>&1; then
      printf -- '- agent 报告：`%s`\n' "$(team_find_report "$id")"
    else
      printf -- '- agent 报告：**缺失**（没有报告本身就是问题）\n'
    fi
    printf '\n'
    [ -n "$strong_lines" ] && printf '%b\n' "$strong_lines"
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

# ---------------------------------------------------------------- merge：只给食谱，不执行 git
# 分工（用户定的原则）：**skill 不执行任何 git 写操作** —— 分支、squash、push、PR 全由 PM 直接用 git/gh 做。
# 这个命令负责：把该做的 git 命令按正确顺序、带好任务标题与 BOARD 收尾，打印成可直接复制的食谱。
team_cmd_merge() {
  team_require_docs
  local id="" branch="" pr="" push=1
  while [ $# -gt 0 ]; do
    case "$1" in
      --branch) branch="${2:?}"; shift 2 ;;
      --pr) pr="${2:?}"; shift 2 ;;            # 有 PR 时给出 forge-first 的顺序
      --no-push) push=0; shift ;;
      -*) team_usage_die "merge: 未知参数 $1（现在只打印食谱，不执行 git）" ;;
      *) id="$1"; shift ;;
    esac
  done
  [ -n "$id" ] || team_usage_die "merge <ID> [--branch b] [--pr N] [--no-push]"
  branch="$(team_resolve_branch "$id" "$branch")"
  if ! team_git_main rev-parse --verify --quiet "refs/heads/$branch" >/dev/null; then
    team_die "分支不存在：$branch（--branch 拼错了？现有候选：$(team_git_main branch --list "*$id*" | tr -d ' *' | tr '\n' ' ')）"
  fi
  local title; title="$(team_task_title "$id")"
  local prev_status; prev_status="$(team_board_field "$(team_board_row "$id" 2>/dev/null || true)" status 2>/dev/null || true)"
  case "$prev_status" in ""|-|"—") prev_status="review" ;; esac
  local rev; rev="$(team_find_report "$id" 2>/dev/null || true)"

  team_hdr "合并食谱 · $id（skill 不执行 git，请 PM 直接跑）"
  printf '  分支 %s → %s ｜ BOARD 当前状态：%s\n\n' "$branch" "$TEAM_PROTECTED_BRANCH" "$prev_status"

  if [ -n "$pr" ]; then
    printf '%s\n' "  ① 先合 PR/MR（forge-first —— 先本地 push 会让 PR 立刻不可合并）："
    if [ -n "$TEAM_MERGE_PR_CMD" ]; then
      printf '       %s\n' "$(team_tpl_fill "$TEAM_MERGE_PR_CMD" "branch=$branch" "base=$TEAM_PROTECTED_BRANCH" "pr=$pr" "title=$title" "remote=$TEAM_REMOTE")"
    else
      case "$TEAM_VCS" in
        github) printf '       GH_TOKEN="$(< %s)" gh pr merge --squash --delete-branch %s\n' "$(forge_github_pat 2>/dev/null || echo "$TEAM_TOKEN_FILE")" "$pr" ;;
        gitlab) printf '       glab mr merge %s --squash --remove-source-branch    # 或 team gl PUT "/projects/<id>/merge_requests/%s/merge"\n' "$pr" "$pr" ;;
        *) printf '       # 本项目不是 GitHub/GitLab：按你们 forge 的方式合并 PR/MR #%s（网页、自建脚本、SSH 都行）\n' "$pr"
           printf '       # 也可以把它写进 config：TEAM_MERGE_PR_CMD="<你们的命令> {pr}"\n' ;;
      esac
    fi
    printf '       git -C %s fetch %s %s && git -C %s merge --ff-only FETCH_HEAD\n' "$TEAM_MAIN_ROOT" "$TEAM_REMOTE" "$TEAM_PROTECTED_BRANCH" "$TEAM_MAIN_ROOT"
  else
    printf '%s\n' "  ① 在主工作树 squash 合并（先确认工作树干净、在 $TEAM_PROTECTED_BRANCH 上）："
    printf '       git -C %s status --short\n' "$TEAM_MAIN_ROOT"
    printf '       git -C %s switch %s\n' "$TEAM_MAIN_ROOT" "$TEAM_PROTECTED_BRANCH"
    printf '       git -C %s merge --squash %s\n' "$TEAM_MAIN_ROOT" "$branch"
    printf '       # 冲突时：只用 --prefer-theirs 处理 lockfile 那些“永远取分支侧”的文件：\n'
    printf '       git -C %s checkout --theirs -- pnpm-lock.yaml && git -C %s merge --continue   # 或 add 后 commit\n' "$TEAM_MAIN_ROOT" "$TEAM_MAIN_ROOT"
    printf '       git -C %s commit -m "%s: %s" -m "squash of %s"\n' "$TEAM_MAIN_ROOT" "$id" "$title" "$branch"
  fi
  if [ "$push" = "1" ]; then
    printf '\n%s\n' "  ② 推送（确认无误再推）："
    printf '       git -C %s push %s %s\n' "$TEAM_MAIN_ROOT" "$TEAM_REMOTE" "$TEAM_PROTECTED_BRANCH"
  fi
  printf '\n%s\n' "  ③ 收尾（BOARD 只在代码真的进了保护分支之后才标 done）："
  printf '       %s board set %s done\n' "$TEAM_CLI" "$id"
  [ "$prev_status" != "done" ] && printf '       # 没进 main 就别标 done：保持 %s，或 %s board set %s blocked\n' "$prev_status" "$TEAM_CLI" "$id"
  printf '\n%s\n' "  ④ 清理（可选）："
  printf '       git -C %s branch -D %s\n' "$TEAM_MAIN_ROOT" "$branch"
  [ -n "$rev" ] && printf '\n  复验记录：%s\n' "$rev"
  printf '\n%s\n' "  说明：以前这条命令会替你做①②，但 git 写操作现在归 PM —— 顺序错一次就会踩「PR 不可合并」那种坑。"
  return 0
}

# pr：同样只给食谱（创建 PR/MR 由 PM 跑）
team_cmd_pr() {
  team_require_docs
  local id="" branch="" title=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --branch) branch="${2:?}"; shift 2 ;;
      --title) title="${2:?}"; shift 2 ;;
      -*) team_usage_die "pr: 未知参数 $1（现在只打印食谱）" ;;
      *) id="$1"; shift ;;
    esac
  done
  [ -n "$id" ] || team_usage_die "pr <ID> [--branch b] [--title \"...\"]"
  branch="$(team_resolve_branch "$id" "$branch")"
  title="${title:-$id: $(team_task_title "$id")}"
  local body; body="$(forge_pr_body "$id" 2>/dev/null || true)"
  team_hdr "PR 食谱 · $id（skill 不创建 PR，请 PM 直接跑；forge 无关）"
  printf '       git -C %s push -u %s %s\n' "$TEAM_MAIN_ROOT" "$TEAM_REMOTE" "$branch"
  if [ -n "$TEAM_PR_CMD" ]; then
    printf '       %s\n' "$(team_tpl_fill "$TEAM_PR_CMD" "branch=$branch" "base=$TEAM_PROTECTED_BRANCH" "title=$title" "body=${body:-<复验记录或任务书>}" "remote=$TEAM_REMOTE")"
  else
    case "$TEAM_VCS" in
      github)
        printf '       GH_TOKEN="$(< %s)" gh pr create --base %s --head %s --title "%s" --body-file %s\n' \
          "$(forge_github_pat 2>/dev/null || echo "$TEAM_TOKEN_FILE")" "$TEAM_PROTECTED_BRANCH" "$branch" "$title" "${body:-<复验记录或任务书>}" ;;
      gitlab)
        printf '       glab mr create --source-branch %s --target-branch %s --title "%s"   # 或 team gl POST "/projects/<id>/merge_requests" --data-urlencode ...\n' "$branch" "$TEAM_PROTECTED_BRANCH" "$title" ;;
      *)
        printf '       # 本项目不是 GitHub/GitLab：按你们 forge 的方式创建 PR/MR（网页、自建脚本、SSH + 工单都行）\n'
        printf '       # 也可以把它写进 config：TEAM_PR_CMD="<你们的命令> --base {base} --head {branch} --title {title}"\n' ;;
    esac
  fi
  [ -n "$body" ] && printf '\n  body 建议用：%s\n' "$body"
  return 0
}

team_cmd_close() {
  team_require_docs
  local id="" status="done" keep_window=0 delete_branch=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --status) status="${2:?}"; shift 2 ;;
      --keep-window) keep_window=1; shift ;;
      --delete-branch) delete_branch=1; shift ;;   # 兼容旧调用：只提示，不执行 git
      -*) team_usage_die "close: 未知参数 $1" ;;
      *) id="$1"; shift ;;
    esac
  done
  [ -n "$id" ] || team_usage_die "close <ID> [--status done|blocked|dropped] [--keep-window]"

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
