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
  local id="" branch="" no_gates=0 strong=0 revdir=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --branch) branch="${2:?}"; shift 2 ;;
      --no-gates) no_gates=1; shift ;;
      --strong) strong=1; shift ;;          # 强复验：要求对抗性验证包 + finding 翻转证据
      --dir) revdir="${2:?}"; shift 2 ;;    # PM 准备好的独立 checkout（skill 不碰 git）
      -*) team_usage_die "review: 未知参数 $1" ;;
      *) id="$1"; shift ;;
    esac
  done
  [ -n "$id" ] || team_usage_die "review <ID> --dir <独立checkout> [--no-gates] [--strong]"
  [ -n "$revdir" ] || team_die "review 需要 --dir <路径>：请 PM 自己准备独立 checkout（skill 不执行 git）
  例： git -C $TEAM_MAIN_ROOT worktree add --detach /tmp/review-$id <branch>
        $TEAM_CLI review $id --dir /tmp/review-$id"
  branch="$(team_resolve_branch "$id" "$branch")"

  # 用 PM 给的 checkout（只读使用：不 fetch、不 checkout、不改它）
  [ -d "$revdir" ] || team_die "目录不存在：$revdir"
  revdir="$(cd "$revdir" && pwd)"
  git -C "$revdir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || team_die "$revdir 不是 git checkout"
  local branch_now; branch_now="$(git -C "$revdir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
  [ -z "$branch" ] && branch="$branch_now"
  local head; head="$(git -C "$revdir" rev-parse HEAD)"

  # ── checkout 必须真的对应该任务分支（V1.1 对抗性复核实测：拿 main / 别的任务分支 / 子目录
  #    都能拿到 PASS，而记录抬头照样写着任务分支 —— 复验就变成了"验错东西还盖章"）
  local revroot; revroot="$(git -C "$revdir" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$revroot" ] || team_die "$revdir 不是 git checkout（没有仓库根）"
  if [ "$(cd "$revroot" && pwd -P)" != "$(cd "$revdir" && pwd -P)" ]; then
    team_die "--dir 必须是 checkout 的**根目录**：$revdir 在仓库 $revroot 的子目录里
  → 换成根目录，或重新准备：git -C $TEAM_MAIN_ROOT worktree add --detach /tmp/review-$id $branch"
  fi
  local want_head=""
  want_head="$(git -C "$TEAM_MAIN_ROOT" rev-parse --verify --quiet "$branch^{commit}" 2>/dev/null || true)"
  if [ -n "$want_head" ] && [ "$want_head" != "$head" ] && [ "${TEAM_REVIEW_ANY_DIR:-0}" != "1" ]; then
    team_die "checkout 与任务分支不一致（复验会验错东西）：分支 $branch = ${want_head:0:9}，--dir 的 HEAD = ${head:0:9}
  → 重新准备：git -C $TEAM_MAIN_ROOT worktree add --detach /tmp/review-$id $branch
  → 确实要用这个 checkout（比如复验一个历史提交）：TEAM_REVIEW_ANY_DIR=1 $TEAM_CLI review $id --dir $revdir --branch ${head:0:9}"
  fi
  # 内容校验：checkout 必须是**干净的**（复验证据要能复现；脏树可能是别人/上个任务留下的改动）
  local dirty_n dirty_list
  dirty_n="$(git -C "$revdir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  if [ "${dirty_n:-0}" -gt 0 ] 2>/dev/null && [ "${TEAM_REVIEW_ALLOW_DIRTY:-0}" != "1" ]; then
    dirty_list="$(git -C "$revdir" status --short | head -5)"
    team_die "checkout 有 $dirty_n 处未提交改动：复验必须在干净提交上跑（否则盖章的不是分支上的代码）
$dirty_list
  → 看是什么：git -C $revdir status --short
  → 干净重建：git -C $TEAM_MAIN_ROOT worktree remove --force $revdir && git -C $TEAM_MAIN_ROOT worktree add --detach $revdir $branch
  → 确认要在脏树上跑：TEAM_REVIEW_ALLOW_DIRTY=1 $TEAM_CLI review $id --dir $revdir"
  fi
  team_ok "review checkout: $revdir @ ${head:0:9}（分支 $branch，干净）"

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
    printf -- '- 独立 checkout：`%s`（PM 提供，skill 只读；不信任 agent 工作区）\n' "$revdir"
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
      PASS) printf -- '- [ ] 已读 diff，与任务书交付物一致\n- [ ] 未发现「报告与实际不符」\n- [ ] 可以合并：squash 到 `%s` 并 push 之后，再 `%s board set %s done`\n' "$TEAM_PROTECTED_BRANCH" "$TEAM_CLI" "$id" ;;
      FAIL) printf -- '- [ ] 门禁失败：退回 agent（`%s say <agent> "..."`）或 PM 自行修复\n' "$TEAM_CLI" ;;
      *)    printf -- '- [ ] 人工评审（门禁未跑/未配置）\n' ;;
    esac
  } > "$report"
  team_ok "复验记录：${report#"$TEAM_MAIN_ROOT"/}（$verdict）"

  [ "$verdict" = "FAIL" ] && return 1
  return 0
}

team_cmd_close() {
  team_require_docs
  local id="" status="done" keep_window=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --status) status="${2:?}"; shift 2 ;;
      --keep-window) keep_window=1; shift ;;
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
    # git 归 PM：这里只提示，不切分支、不删分支
    b="$(git -C "$(team_agent_worktree "$a")" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    case "$b" in
      ""|HEAD|"$TEAM_PROTECTED_BRANCH") ;;
      *) team_dim "  $a 仍在分支 $b 上：需要清理请自己跑 git -C $(team_agent_worktree "$a") switch --detach $TEAM_PROTECTED_BRANCH" ;;
    esac
  done
  team_board_set "$id" "$status" 2>/dev/null || team_warn "BOARD 未更新（$id 不在表里？）"
  team_ok "closed $id（status=$status）"
  team_dim "  复验记录 $TEAM_DOCS_DIR/reviews/$id.md 保留；agent worktree 保留（复用）"
}
