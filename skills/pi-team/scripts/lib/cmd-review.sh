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

team_cmd_merge() {
  team_require_docs
  local id="" branch="" push=0 delete_branch=0 no_review=0 pr="" no_renames="${TEAM_MERGE_NO_RENAMES:-0}"
  local prefer="${TEAM_MERGE_PREFER_THEIRS:-}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --branch) branch="${2:?}"; shift 2 ;;
      --push) push=1; shift ;;
      --delete-branch) delete_branch=1; shift ;;
      --pr) pr="${2:?}"; shift 2 ;;          # 合并后顺手合 PR/MR；403 就自动本地兜底
      --no-renames) no_renames=1; shift ;;   # 关掉 merge 的 rename 检测（add/add 误配对时用）
      --prefer-theirs) prefer="${prefer:+$prefer,}${2:?}"; shift 2 ;;   # 冲突时这些路径取分支侧（lockfile 常用）
      --no-review-check) no_review=1; shift ;;
      -*) team_usage_die "merge: 未知参数 $1" ;;
      *) id="$1"; shift ;;
    esac
  done
  [ -n "$id" ] || team_usage_die "merge <ID> [--branch b] [--push] [--delete-branch] [--pr N] [--no-renames] [--prefer-theirs <path>]"
  team_allow_write || return 1
  branch="$(team_resolve_branch "$id" "$branch")"
  # 分支必须真实存在：否则 git 会说 "not something we can merge"，看起来像冲突
  if ! team_git_main rev-parse --verify --quiet "refs/heads/$branch" >/dev/null; then
    team_die "分支不存在：$branch（--branch 拼错了？现有候选：$(team_git_main branch --list "*$id*" | tr -d ' *' | tr '\n' ' ')）"
  fi

  if [ "$no_review" != "1" ] && [ ! -f "$TEAM_DOCS_ABS/reviews/$id.md" ]; then
    team_die "没有复验记录：先跑 $TEAM_CLI review $id（或显式 --no-review-check）"
  fi
  if [ "$no_review" != "1" ] && grep -qE '判定: \*\*(FAIL|UNKNOWN|TIMEOUT)\*\*' "$TEAM_DOCS_ABS/reviews/$id.md" 2>/dev/null; then
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

  # --pr：**forge-first**。
  # CEP 实测（2026-09-11）：旧顺序是"先本地 squash + push main，再合 PR"，主分支一被本地提交推进，
  # PR 立刻不可合并（内容等价但提交不同），API 拒绝——而错误提示却甩锅给权限（细粒度 PAT 其实有 pull-requests: write）。
  # 正确顺序：先让 forge 合（历史里保留真合并提交与 PR 链接），成功后 `git fetch && merge --ff-only` 更新本地。
  # 失败时要把 BOARD 还原成合并前的状态（不能“没进 main 却写 done”）
  local prev_status; prev_status="$(team_board_field "$(team_board_row "$id" 2>/dev/null || true)" status 2>/dev/null || true)"
  case "$prev_status" in ""|-|"—") prev_status="review" ;; esac
  local title merge_log; title="$(team_task_title "$id")"
  merge_log="$(mktemp)"

  # ---------- forge-first：有 --pr 时先合 PR ----------
  if [ -n "$pr" ]; then
    local flog; flog="$(mktemp)"
    team_info "先合 PR/MR #$pr（forge-first）："
    if forge_merge_pr "$pr" > "$flog" 2>&1; then
      team_ok "PR/MR #$pr 已由 forge 合并（squash）"
      if team_git_main fetch --quiet "$TEAM_REMOTE" "$TEAM_PROTECTED_BRANCH" 2>/dev/null \
         && team_git_main merge --ff-only FETCH_HEAD >/dev/null 2>&1; then
        team_ok "本地 $TEAM_PROTECTED_BRANCH 已快进到 $(team_git_main rev-parse --short HEAD)"
      else
        team_warn "本地没快进（有本地提交或 fetch 失败）：手工 git -C $TEAM_MAIN_ROOT pull --ff-only $TEAM_REMOTE $TEAM_PROTECTED_BRANCH"
      fi
      if [ "$push" = "1" ]; then :; fi   # forge 侧已经更新了远端
      if [ "$delete_branch" = "1" ]; then
        team_git_main branch -D "$branch" >/dev/null 2>&1 && team_ok "deleted 本地分支 $branch"
      fi
      rm -f "$flog" "$merge_log"
      team_board_set "$id" done 2>/dev/null || true
      team_ok "board $id → done（PR #$pr 已合并）"
      return 0
    fi
    # 失败：把 forge 的**真实错误**打出来，别再猜权限
    team_warn "forge 合并 PR/MR #$pr 失败，输出如下："
    tail -8 "$flog" | sed 's/^/    /' >&2
    case "$(cat "$flog" 2>/dev/null)" in
      *"not mergeable"*|*"405"*|*"422"*|*"conflict"*|*"不可合并"*)
        team_dim "  这通常是「PR 与 base 分支冲突 / 已不可合并」，不是权限问题（细粒度 PAT 也可能有 pull-requests: write）" >&2 ;;
      *"403"*|*"Forbidden"*|*"not authorized"*)
        team_dim "  这看起来是权限/授权问题（检查 PAT scope 与仓库权限）" >&2 ;;
    esac
    team_dim "  回落到本地路径：squash → push → 留言记录 → 关闭该 PR" >&2
    rm -f "$flog"
    push=1
  fi
  local merge_args=(merge --squash)
  [ "$no_renames" = "1" ] && merge_args=(-c merge.renames=false merge --squash)
  # 失败收口：还原 BOARD 状态 + 给可复制粘贴的恢复步骤
  local install_hint="${TEAM_INSTALL_CMD:-pnpm install --lockfile-only}"
  merge_fail() { # <原因>
    rm -f "$merge_log"
    team_git_main merge --abort >/dev/null 2>&1 || team_git_main reset --merge >/dev/null 2>&1 || true
    team_board_set "$id" "$prev_status" 2>/dev/null || true
    team_err "合并未完成：$1"
    team_dim "  BOARD 保持「$prev_status」（没进 $TEAM_PROTECTED_BRANCH 就不算 done）" >&2
    printf '%s\n' "" "  恢复步骤（复制粘贴）：" \
      "    git -C $TEAM_MAIN_ROOT merge --squash $branch        # 重跑，保留冲突现场" \
      "    git -C $TEAM_MAIN_ROOT status --short | grep '^U'     # 看冲突文件" \
      "    # lockfile 类（pnpm-lock.yaml / package-lock.json / yarn.lock）：取分支侧再装依赖" \
      "    git -C $TEAM_MAIN_ROOT checkout --theirs -- pnpm-lock.yaml && (cd $TEAM_MAIN_ROOT && $install_hint)" \
      "    git -C $TEAM_MAIN_ROOT add -A && git -C $TEAM_MAIN_ROOT commit -m \"$id: $title\"" \
      "    git -C $TEAM_MAIN_ROOT push $TEAM_REMOTE $TEAM_PROTECTED_BRANCH   # 需要时" \
      "    $TEAM_CLI board set $id done                        # 确认进了保护分支再标 done" \
      "" "  或者一条命令重试（自动取分支侧 lockfile + 关掉 rename 检测）：" \
      "    $TEAM_CLI merge $id --no-renames --prefer-theirs pnpm-lock.yaml" >&2
    team_die "$1（BOARD 保持 $prev_status）"
  }

  if ! team_git_main "${merge_args[@]}" "$branch" > "$merge_log" 2>&1; then
    team_err "squash merge 失败：$branch → $TEAM_PROTECTED_BRANCH"
    # 先按 --prefer-theirs 自动解决指定路径（lockfile 这类“永远取分支侧”的文件）
    if [ -n "$prefer" ]; then
      local one
      for one in $(printf '%s' "$prefer" | tr ',' ' '); do
        [ -n "$one" ] || continue
        if team_git_main checkout --theirs -- "$one" >/dev/null 2>&1; then
          team_git_main add -- "$one" >/dev/null 2>&1 || true
          team_ok "冲突文件 $one → 取分支侧（--prefer-theirs）"
        fi
      done
    fi
    # 列出仍未合并的文件（UU/AA/DU/UD/AU/UA/DD）——不列的话 PM 只能手工重跑才知道是哪个文件
    local conflicts
    conflicts="$(team_git_main status --porcelain 2>/dev/null | grep -E '^(UU|AA|DD|AU|UA|DU|UD) ' || true)"
    if [ -n "$conflicts" ]; then
      team_err "冲突文件："
      printf '%s\n' "$conflicts" | sed 's/^/  /' >&2
      case "$conflicts" in
        *AA*)
          # add/add 常常是 git 的 rename 检测把两个不同路径配成了一对
          team_dim "  （AA=两边都新增。若是 docs 下的 reports/reviews 被误配对：重试加 --no-renames）" >&2 ;;
      esac
      merge_fail "有未解决的冲突"
    fi
    # 冲突都按 --prefer-theirs 解决完了：继续走 commit
    team_ok "冲突已按 --prefer-theirs 全部解决（分支侧优先）"
  fi
  rm -f "$merge_log"
  team_git_main commit -q -m "$id: $title" -m "pi-team: squash merge of $branch" \
    || merge_fail "squash 提交失败"
  local squashed; squashed="$(team_git_main rev-parse --short HEAD)"
  team_ok "merged $branch → $TEAM_PROTECTED_BRANCH @ $squashed"

  if [ "$push" = "1" ]; then
    if team_git_main push "$TEAM_REMOTE" "$TEAM_PROTECTED_BRANCH"; then
      team_ok "pushed $TEAM_PROTECTED_BRANCH"
    else
      # 本地已合并但远端没更新：不能标 done（否则远端 main 永远缺这段代码）
      merge_fail "push $TEAM_REMOTE/$TEAM_PROTECTED_BRANCH 失败（本地已 squash 到 $squashed）"
    fi
  else
    team_dim "  未推送：确认后执行 git -C $TEAM_MAIN_ROOT push $TEAM_REMOTE $TEAM_PROTECTED_BRANCH"
  fi
  if [ "$delete_branch" = "1" ]; then
    team_git_main branch -D "$branch" >/dev/null && team_ok "deleted branch $branch"
  fi
  # 只有「合并 + 推送」都成功才标 done
  team_board_set "$id" done 2>/dev/null || true
  team_ok "board $id → done"

  if [ -n "$pr" ]; then
    # 走到这里说明 forge-first 已经失败过（前面已打印真实错误并回落到本地路径）
    forge_pr_record_and_close "$pr" "$(team_git_main rev-parse --short HEAD)" "$branch" || true
  fi
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

# PR/MR 合不动时的本地兜底（CEP 的 PAT 没有 pull-requests: write）：
#   local squash merge → push → 在 PR 上留言记录 squash commit → 关闭 PR
team_pr_local_fallback() { # <ID> <pr> <branch>
  local id="$1" pr="$2" branch="$3" sha
  team_warn "走本地兜底（PAT 缺 pull-requests: write）：squash merge → push → 留言 → 关 PR"
  team_cmd_merge "$id" --branch "$branch" --push || return 1
  sha="$(team_git_main rev-parse --short HEAD)"
  forge_pr_record_and_close "$pr" "$sha" "$branch" || true
  team_ok "兜底完成：$TEAM_PROTECTED_BRANCH @ $sha（PR #$pr 已记录并关闭）"
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
