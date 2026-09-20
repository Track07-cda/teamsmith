#!/usr/bin/env bash
# teamsmith · 观察类命令：roster / status / ps / digest / inbox

team_inbox_file() { printf '%s\n' "$(team_inbox_dir)/$1.md"; }

team_inbox_total() { local f; f="$(team_inbox_file "$1")"; [ -f "$f" ] && wc -l < "$f" | tr -d ' ' || printf '0'; }

team_inbox_new() { # <agent> → 未 ack 的行数
  local total acked; total="$(team_inbox_total "$1")"; acked="$(team_state_get "$1" inbox_lines 0)"
  # 文件被截短/重建（acked > total）时 ack 基线失效：把剩下的行当未读重新展示一次。
  # 不这样，一条新消息会因为旧的 ack 计数比文件行数大而**永远看不见**（F26 的 live 现场）。
  case "$acked" in ''|*[!0-9]*) acked=0 ;; esac
  [ "$acked" -gt "$total" ] && acked=0
  [ "$total" -gt "$acked" ] && printf '%s\n' "$((total - acked))" || printf '0\n'
}

team_inbox_since() { # <agent> → 未 ack 的行
  local f start total
  f="$(team_inbox_file "$1")"
  [ -f "$f" ] || return 0
  start="$(team_state_get "$1" inbox_lines 0)"
  case "$start" in ''|*[!0-9]*) start=0 ;; esac
  total="$(team_inbox_total "$1")"
  [ "$start" -gt "$total" ] && start=0          # 与 team_inbox_new 的失效基线保持一致
  [ "$start" -gt 0 ] && tail -n +"$((start + 1))" "$f" || cat "$f"
}

# worker 存活判据（team_agent_live / team_agent_window_exists）在 common.sh —— digest 的「停了的 agent」
# （team_pending_counts）与 roster / resume / 面板 agents 块必须共用同一份判据（M37）。

# ---------------------------------------------------------------- M4.3 C：报告草稿 vs 已交付
# `team review` 从任务分支的 checkout 里**摘录**报告，所以工作区里的草稿根本摘不到：
# 旧实现对草稿也喊「→ team review」，PM 于是收到一个**还不能执行**的待办（DECISIONS D9 事件 C）。
# 判定「在 HEAD 里」：跟踪了、且工作区与 HEAD 一致（改过/只 staged 的都算草稿）。
team_report_committed() { # <报告路径>
  local f="$1" dir
  [ -f "$f" ] || return 1
  if team_scan_cache_on; then
    # M50：工作树归属走缓存的工作树清单（原来每份报告一次 rev-parse --show-toplevel），
    # 跟踪/差异判定走每工作树一次的批量集合（ls-files + diff --name-only HEAD）。
    # 不在任何已知工作树 / 不在其 reports 目录里 → 落回直读（语义逐字节不变）。
    local wt rel
    wt="$(team_worktree_of "$f")"
    if [ -n "$wt" ]; then
      case "$f" in "$wt/${TEAM_DOCS_DIR:-docs/team}/reports/"*) ;; *) wt="" ;; esac
    fi
    if [ -n "$wt" ]; then
      _team_wtrep_load "$wt"
      rel="${f#"$wt"/}"
      [ "${_TEAM_WTREP_TRACKED[$wt|$rel]:-}" = "1" ] || return 1
      [ "${_TEAM_WTREP_BROKEN[$wt]:-}" = "1" ] && return 1   # diff 失败：原实现对每份文件都判「不算已提交」
      [ "${_TEAM_WTREP_DIRTY[$wt|$rel]:-}" = "1" ] && return 1
      return 0
    fi
  fi
  dir="$(git -C "$(dirname "$f")" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$dir" ] || return 1
  git -C "$dir" ls-files --error-unmatch -- "$f" >/dev/null 2>&1 || return 1
  git -C "$dir" diff --quiet HEAD -- "$f" 2>/dev/null || return 1
  return 0
}

# M9.8：**草稿**（agent 工作树里还没提交的报告）= 太早的信号：PM 现在动不了它，digest [3] 也只说
# 「先等 agent 交付」。所以这个判据只写一遍，**列表显示**与**唤醒计数**共用它 —— 两处各判一次
# 就是 M9.8 的现场（唤醒理由「待复验 6」而 digest 清单空）的温床。
# 只对 agent 工作树里的报告这么判：主工作树里的是 PM 侧副本，`team review` 的候选链本来就会回退到它
# （cmd-review.sh 的 F14 设计），那里「文件存在」就是可用的。
team_report_is_draft() { # <报告路径> → 0=草稿
  case "$1" in
    "$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR/"*) ;;
    *) return 1 ;;
  esac
  team_report_committed "$1" && return 1
  return 0
}

# ---------------------------------------------------------------- M4.3 D：squash 合并后的分支
# PM 在 local 模式 squash 合并后，agent 分支仍持有原提交：`领先 N` 与「收尾：提交并 push」会永远留着噪音。
# 判据是**启发式**且很便宜：分支 tip 的 tree 出现在保护分支最近 TEAM_SQUASH_LOOKBACK 个提交的 tree 里
# （squash 合并且没有别的改动时正是这个形状：内容相同、却没有共同提交）。
# 窗口外/部分 squash 会落回诚实的「领先 N」；文档里写明这是启发式（references/workflows.md）。
team_branch_squash_merged() { # <worktree> → 0=内容已在保护分支里
  local wt="${1:-}" tree lookback="${TEAM_SQUASH_LOOKBACK:-200}"
  [ -d "$wt" ] || return 1
  case "$lookback" in ''|*[!0-9]*) lookback=200 ;; esac
  tree="$(git -C "$wt" rev-parse 'HEAD^{tree}' 2>/dev/null || true)"
  [ -n "$tree" ] || return 1
  # M50：保护分支的 tree 清单一个纪元读一次（原来每个工作树一次 git log）
  if team_scan_cache_on; then
    _team_prot_trees_load
    printf '%s\n' "$_TEAM_PROT_TREES" | grep -qx "$tree"
    return
  fi
  git -C "$wt" log --format=%T --max-count="$lookback" "$TEAM_PROTECTED_BRANCH" 2>/dev/null | grep -qx "$tree"
}

# 这个 worktree 是不是「已 squash 合并、且没有别的未收尾信号」：脏工作区/真的未 push 优先说了算。
team_wrapup_is_squash_merged() { # <worktree> <dirty> <ahead> <upstream-ahead>
  local wt="$1" dirty="${2:-0}" ahead="${3:-0}" upahead="${4:--}"
  [ "${dirty:-0}" -eq 0 ] 2>/dev/null || return 1
  [ "${ahead:-0}" -gt 0 ] 2>/dev/null || return 1
  case "${upahead:-}" in ''|-) ;; *) return 1 ;; esac
  team_branch_squash_merged "$wt"
}

# ---------------------------------------------------------------- 待复验清单（复验证据 + 看板感知版）
# M6.2 · F3 + F12：common.sh 里那版是「reviews/<ID>.md 存在 == 已复验」，于是
#   ① 记录永远压制待办（分支后来又交付了提交，digest 也不再提示）；
#   ② --no-gates 写的 SKIPPED 记录和 PASS 一样被当成证据。
# 这里覆盖成：只有「记录有效」才算复验过 —— 判定是跑过门禁的
# （PASS/FAIL/TIMEOUT）**且**记录里的 HEAD 就是任务分支当前 tip；
# 分支已被合并删除（解析不到）时记录仍算有效，否则合并后的任务会永远待办。
# 无效的记录不会被静默藏起来：仍列在 digest [3] 里，显示名后带 gates: none / stale: … 标记，
# 这样“没跑过门禁的复验”和“分支在复验后又动了”都看得见。
# 注意：这是对 common.sh 同名函数的**覆盖**（cmd-status.sh 在它之后 source）；pending 逻辑
# 归 M6.2（见 M6.2 任务书），M6.1 负责的状态/看板函数不动。
# M9.4 再加两条（都是真实假信号：P1 已 done 还每拍被列出来）：
#   ③ **看板已裁决的不列**：done/closed 的行不能同时又「等 PM 复验」——证据是在看板转变那一刻
#      核对的（M9.2 的 team_done_evidence），清单不得反过来质疑看板。跳过的报告不静默丢：
#      digest 用一行点名（team_reports_skipped_by_board），team status <ID> 也说明为什么；
#   ④ **副本归属**：叠分支（apply 建在 propose 上，DECISIONS D16）会把 propose 阶段的报告带进
#      apply 的工作树。同一个 id 有多份副本时先归属副本、后继承副本，digest 也不会把继承副本
#      说成「在 <别人的> 分支上」。
# 候选清单可以**传进来**：digest 在同一拍里要问两遍（列出来的 + 被看板跳过的），
# 传进来就只解析一轮 BOARD/工作树（几十个文件 × awk + git，不复用就是白花一倍时间）。
team_reports_pending_list() { # [候选清单] [--actionable] → 每行 "<id>\t<显示名[ 标记]>\t<路径>"
  # --actionable = 只要**现在能动的**（草稿要等交付，PM 动不了）：digest [3] 用全量（草稿照旧列出来并
  # 标注），唤醒计数用 --actionable。两边是**同一个函数**、同一套过滤，唯一差别是这一个开关。
  local cands="" only_actionable=0 arg id path base note
  for arg in "$@"; do
    case "$arg" in
      --actionable) only_actionable=1 ;;
      --*) ;;
      *) [ -n "$cands" ] || cands="$arg" ;;
    esac
  done
  [ -n "$cands" ] || cands="$(team_report_primary_candidates)"
  while IFS=$'\t' read -r id path; do
    [ -n "$id" ] || continue
    # M9.4 ③：看板已裁决（done/closed）→ 不列。跳过的那些由 team_reports_skipped_by_board 点名。
    team__board_status "$id"; case "$_R" in done|closed) continue ;; esac
    # M9.8：草稿不叫醒（标注但不计数）。
    if [ "$only_actionable" = "1" ] && team_report_is_draft "$path"; then continue; fi
    base="${path##*/}"; base="${base%.md}"
    if [ -f "$TEAM_DOCS_ABS/reviews/$id.md" ]; then
      team__review_record_note "$id"; note="$_R"
      [ -n "$note" ] || continue          # 记录有效且新鲜 → 不算待办
      printf '%s\t%s [%s]\t%s\n' "$id" "$base" "$note" "$path"
    else
      printf '%s\t%s\t%s\n' "$id" "$base" "$path"
    fi
  done <<< "$cands"
}

# 报告候选：主工作树 + 各 agent 工作树（**全部**目录，不只名册：叠分支的副本会落在别人的工作树里）。
# 输出顺序即优先级（team_report_primary_candidates 的去重取第一个）：主工作树 → 归属副本 → 继承副本。
team_report_candidates() { # → 每行 "<id>\t<路径>"
  local glob base id rank pass
  for glob in "$TEAM_DOCS_ABS/reports/"*.md; do
    [ -f "$glob" ] || continue
    base="${glob##*/}"; base="${base%.md}"; team__report_task_id "$glob"; id="$_R"   # F6：id 可以带 '-'，按最长已知前缀取
    team_report_is_task "$glob" "$id" || continue
    printf '%s\t%s\n' "$id" "$glob"
  done
  for pass in 1 2; do
    for glob in "$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR"/*/"$TEAM_DOCS_DIR"/reports/*.md; do
      [ -f "$glob" ] || continue
      base="${glob##*/}"; base="${base%.md}"; team__report_task_id "$glob"; id="$_R"
      team_report_is_task "$glob" "$id" || continue
      team__report_copy_rank "$glob" "$id"; rank="$_R"
      [ "$rank" = "$pass" ] || continue
      printf '%s\t%s\n' "$id" "$glob"
    done
  done
}

# M9.4 ④：这份工作树里的报告是**本任务的**（正本），还是叠分支带过来的旧拷贝？
#   0 = 主工作树（PM 侧副本，本来就不是「在谁的分支上」）
#   1 = 归属工作树：报告文件名里的作者就是这份工作树的主人（<ID>-<agent>.md 在 .worktrees/<agent>/），
#       或派单记录说它现在的任务就是这个（team_state_get），或它 HEAD 就是 task/<ID>
#   2 = 继承副本：以上都不是 —— 文件是历史/叠分支带过来的（apply 分支建在 propose 分支上，D16）
team_report_copy_rank() { # <报告路径> <id> → 0|1|2
  team__report_copy_rank "$@"; printf '%s\n' "$_R"
}

team__report_copy_rank() { # <报告路径> <id> → _R = 0|1|2（M50 进程内变体）
  local rep="$1" id="$2" who wt branch
  case "$rep" in
    "$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR/"*) ;;
    *) _R=0; return 0 ;;
  esac
  # M50：纪元内 memo（digest 对同一（报告， id) 在两个 pass 与各显示段落里重复问）
  if team_scan_cache_on && [ -n "${_TEAM_REP_RANK[$rep|$id]+x}" ]; then
    _R="${_TEAM_REP_RANK[$rep|$id]}"; return 0
  fi
  local rank=2 base
  who="${rep#"$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR"/}"; who="${who%%/*}"
  base="${rep##*/}"; base="${base%.md}"
  case "$base" in "$id-$who") rank=1 ;; esac
  if [ "$rank" != "1" ]; then
    team__state_get "$who" task ''
    [ "$_R" = "$id" ] && rank=1
  fi
  if [ "$rank" != "1" ]; then
    wt="$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR/$who"   # = team_agent_worktree（一行 printf，热循环里省下 fork）
    team__worktree_branch "$wt"; branch="$_R"   # M50：进程内缓存（原来是每份报告一次 rev-parse）
    case "$branch" in "$TEAM_TASK_BRANCH_PREFIX/$id") rank=1 ;; esac
  fi
  if team_scan_cache_on; then _TEAM_REP_RANK[$rep|$id]="$rank"; fi
  _R="$rank"
}

# 每个任务只留一份副本（优先级见 team_report_candidates）；返回的这份就是 digest / status 说的那份。
team_report_primary_candidates() { # → 每行 "<id>\t<路径>"
  # M50：纪元内 memo（digest 一拍里 pending 计数、[3] 清单、看板跳过清单共用同一份扫描）
  if team_scan_cache_on && [ "${_TEAM_CANDS_EPOCH:-}" = "$_TEAM_SCAN_EPOCH" ]; then
    printf '%s' "$_TEAM_CANDS_OUT"; return 0
  fi
  local id path ids=" " out=""
  while IFS=$'\t' read -r id path; do
    [ -n "$id" ] || continue
    case "$ids" in *" $id "*) continue ;; esac
    ids="$ids$id "
    out="${out}${id}"$'\t'"${path}"$'\n'
  done < <(team_report_candidates)
  if team_scan_cache_on; then _TEAM_CANDS_OUT="$out"; _TEAM_CANDS_EPOCH="$_TEAM_SCAN_EPOCH"; fi
  printf '%s' "$out"
}

# M9.8：唤醒判定的「待复验」= digest [3] **可行动**列表的行数：同一个函数、同一套过滤
# （看板 done/closed 跳过、草稿标注但不计数、verify 任务按绑定 revision 判）。
# 这是对 common.sh 同名实现的**覆盖**（cmd-status.sh 在它之后 source）：旧实现自己数一遍报告数，
# M9.4 给清单加上看板/副本过滤之后就分家了 —— 现场 2026-09-15：watchdog 的唤醒理由「待复验 6」，
# 同一时刻 digest [3] 的清单是空的（那 6 份全是看板已裁决的）。改这里的过滤 = 同时改唤醒理由与
# digest 清单，这正是要的：一份判据，两个出口。
team_reports_pending() { team_reports_pending_list --actionable | wc -l | tr -d ' '; }

# <ID> → 0=这份报告在「看板没裁决」时会列为待复验（M6.2 的记录规则：没有记录 / 记录过期 / 没跑门禁）
team_report_unverified() { # <ID>
  [ -f "$(team_review_record_path "$1")" ] || return 0
  [ -n "$(team_review_record_note "$1")" ] || return 1
  return 0
}

# M9.4：待复验条目给的「下一步」。声明了 phase 的任务里，explore/propose/archive 的交付**不在代码分支上**
# （探索结论 / 提案审查记录 / 归档目录），那句通用的 `team review <ID>` 会让 PM 去验错东西；
# 这三类阶段给出阶段证据（M9.2 的 team_done_phase_evidence）与下一步。apply/verify 的交付就是代码与复验
# 记录本身，动作与未声明 phase 的任务逐字一致（不借 phase 把行动搅浑）。
team_report_pending_action() { # <ID> → 一行「下一步」
  local id="$1" phase change pev
  phase="$(team_task_phase "$id")"
  case "$phase" in
    explore|propose|archive)
      change="$(team_task_change "$id")"
      if pev="$(team_done_phase_evidence "$id" "$phase" "$change")"; then
        printf '阶段证据已就绪（%s）→ 等 PM 把看板移入 done\n' "$pev"
      else
        printf '阶段 %s 证据未就绪：%s\n' "$phase" "$pev"
      fi
      return 0 ;;
  esac
  printf '→  %s review %s\n' "$TEAM_CLI" "$id"
}

# M9.4 ③：因为看板已裁决而**不列**、但本来会被列出来的报告（digest 用一行点名；静默跳过 = 假阴性藏身处）。
team_reports_skipped_by_board() { # [候选清单] → 每行 "<id>\t<显示名>\t<路径>"
  local cands="${1:-}" id path st
  [ -n "$cands" ] || cands="$(team_report_primary_candidates)"
  while IFS=$'\t' read -r id path; do
    [ -n "$id" ] || continue
    st="$(team_board_status "$id")"
    case "$st" in done|closed) ;; *) continue ;; esac
    team_report_unverified "$id" || continue
    printf '%s\t%s\t%s\n' "$id" "$(basename "$path" .md)" "$path"
  done <<< "$cands"
}

# F4：push 状态必须相对 @{upstream} 量。旧实现拿保护分支当代理 —— 分支 push 过、又被 squash 合并后，
# 相对保护分支永远「领先 N」，digest 便永远喊「未 push」（头写着未 push，量的却是别的 ref）。
#   <n>  相对 @{upstream} 的领先提交数
#   -    没有 upstream（push 状态**无法判定**，不等于「未 push」）
#   ?    配了 upstream 但解析不到（例如远端分支已被删/被 prune 掉）
team_git_upstream_ahead() { # <worktree> → 见上
  local wt="$1" up
  [ -d "$wt" ] || { printf -- '-\n'; return 0; }
  up="$(git -C "$wt" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
  [ -n "$up" ] || { printf -- '-\n'; return 0; }
  git -C "$wt" rev-list --count '@{upstream}..HEAD' 2>/dev/null || printf '?\n'
}

team_git_cols() { # <worktree> → "branch dirty ahead-of-protected ahead-of-upstream"
  local wt="$1" branch dirty ahead
  [ -d "$wt" ] || { printf -- '-\t-\t-\t-\n'; return 0; }
  branch="$(team_worktree_branch "$wt")"   # M50：进程内缓存（原：rev-parse --abbrev-ref HEAD）
  [ -n "$branch" ] || branch="-"
  dirty="$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  # M50：保护分支存在性走纪元内的 refs 缓存（原：rev-parse --verify）
  if team_scan_cache_on; then
    _team_ref_cache_load
    if [ -n "${_TEAM_REF_TIP[$TEAM_PROTECTED_BRANCH]:-}" ]; then
      ahead="$(git -C "$wt" rev-list --count "$TEAM_PROTECTED_BRANCH..HEAD" 2>/dev/null || echo '?')"
    else
      ahead="?"
    fi
  elif git -C "$wt" rev-parse --verify -q "$TEAM_PROTECTED_BRANCH" >/dev/null 2>&1; then
    ahead="$(git -C "$wt" rev-list --count "$TEAM_PROTECTED_BRANCH..HEAD" 2>/dev/null || echo '?')"
  else
    ahead="?"
  fi
  printf '%s\t%s\t%s\t%s\n' "$branch" "$dirty" "$ahead" "$(team_git_upstream_ahead "$wt")"
}

# ---------------------------------------------------------------- M16：代号必须随身带人话名字
# 面向用户的输出里，代号（M12 / P14 / V15 / T1.1）单独出现 = 让读者自己去翻台账："P14 要决" 这种话
# 让人先查文件才知道 P14 是什么。规则（用户反馈 2026-09-17）：**同一处必须带短名字**（`M12（修冒烟抖动）`）——
# 代号是台账的钥匙（命令里照旧原样用），名字是给人读的，两者不许分家。
# 名字来源（按可信度）：① BOARD 的「任务」列（PM 维护的正式短名）→ ② 任务书 H1（`# M16 · …`）
# → ③ 该任务的报告 H1（`# M16-dev2 · …`；叠分支、任务书还没写名字时的兜底）。
# 查不到名字就返回空，调用方只印代号 —— **绝不编名字，也绝不因为查不到名字就不打印代号**：
# 代号丢失比名字缺失更糟（账本就靠它对上人）。
team_task_name() { # <ID> → 一行短名字（没有 → 空）
  local id="${1:-}" t f title
  [ -n "$id" ] || return 0
  t="$(team_task_title "$id" 2>/dev/null || true)"        # ① 看板 → ② 任务书（team_task_title 的实现）
  if [ -n "$t" ] && [ "$t" != "$id" ]; then printf '%s\n' "$t"; return 0; fi
  f="$(team_find_report "$id" 2>/dev/null || true)"
  if [ -n "$f" ] && [ -f "$f" ]; then                     # ③ 报告 H1 的兜底
    title="$(sed -n '1{/^#[[:space:]]/p}' "$f" 2>/dev/null | sed -e 's/^#[[:space:]]*//')"
    # `# M16 · title` / `# M16-dev2 · title`：吃掉代号（含 "-<agent>" 后缀）与后随的分隔符
    title="$(printf '%s' "$title" | sed -E "s@^$(team_regex_escape "$id")([-[:alnum:]_]+)?[[:space:]]*[·:—–-][[:space:]]*@@")"
    if [ -n "$title" ] && [ "$title" != "$id" ]; then printf '%s\n' "$title"; return 0; fi
  fi
  return 0
}

team_task_label() { # <ID> → "M16（沟通纪律：代号必须随身带人话名字）"；查不到名字 → 原样 <ID>
  local id="${1:-}" name
  [ -n "$id" ] || return 0
  name="$(team_task_name "$id" 2>/dev/null || true)"
  if [ -n "$name" ]; then printf '%s（%s）\n' "$id" "$name"; else printf '%s\n' "$id"; fi
  return 0
}

team_task_name_suffix() { # <ID> → "（短名字）"；查不到 → 空（贴在已显示的名字/代号后面，不重复代号）
  local name
  name="$(team_task_name "${1:-}" 2>/dev/null || true)"
  [ -n "$name" ] && printf '（%s）\n' "$name"
  return 0
}

team_cmd_roster() {
  team_require_docs
  printf '%-10s %-12s %-26s %4s %8s %7s  %-34s %-16s %s\n' AGENT 状态 分支 脏 领先 未push 模型 会话 任务
  printf '%-10s %-12s %-26s %4s %8s %7s  %-34s %-16s %s\n' ----- ------ -------------------------- ---- ------ ------- ---------------------------------- ---------------- ----
  local a w wt cols branch dirty ahead upahead task state cli model msrc mtok mwin mbytes mfile size
  cli="$(team_agent_cli_name)"
  for a in $(team_agents); do
    wt="$(team_agent_worktree "$a")"
    if team_agent_live "$a"; then state="● $cli 在跑"
    elif team_agent_window_exists "$a"; then state="○ $cli 已退出"
    else state="· 无窗口"; fi
    cols="$(team_git_cols "$wt")"
    IFS=$'\t' read -r branch dirty ahead upahead <<< "$cols"
    # M4.3 D：内容已在保护分支里的分支不再计「领先 N」（squash 合并的形状）
    if [ "${ahead:-0}" -gt 0 ] 2>/dev/null && team_branch_squash_merged "$wt"; then ahead="已合并"; fi
    # M4.3 A：会话大小 vs 模型窗口（只 stat 字节数，不读内容）
    IFS=$'\t' read -r model mtok mwin mbytes mfile <<< "$(team_agent_session_cols "$a")"
    size="$(team_session_size_text "$mtok" "$mwin")"
    # M14：模型列带来源标注 —— 名册旧记录不再冒充当前配置（历史记录 = 配置在它之后改了）
    msrc="$(team_agent_model_src "$a")"
    # M16：任务列不再只印代号 —— 名字跟在代号后面（查不到名字时原样只印代号）
    task="$(team_task_label "$(team_state_get "$a" task -)")"
    printf '%-10s %-12s %-26s %4s %8s %7s  %-34s %-16s %s\n' "$a" "$state" "$branch" "$dirty" "$ahead" "$upahead" "$model·$msrc" "$size" "$task"
  done
  printf '\n● %s 在跑 ｜ ○ 窗口在但 %s 已退出（team resume 可续）｜ · 无窗口\n' "$cli" "$cli"
  printf '  脏=未提交 ｜ 领先=相对 %s（已合并=squash 后的内容已在 %s 里）｜ 未push=相对 @{upstream}（- = 没有 upstream，无法判定）\n' "$TEAM_PROTECTED_BRANCH" "$TEAM_PROTECTED_BRANCH"
  printf '  会话=估算 tok/模型窗口（JSONL 字节÷4，粗糙；窗口 ? = 解析不到 → 派单用保守阈值 %s）⚠=已超窗口\n' "${TEAM_SESSION_WARN_TOKENS:-200000}"
  printf '  模型·来源：配置=当前配置解析（或无记录，取配置）｜显式=上次 --model 指定｜历史记录=名册旧记录，配置已改 → 下次派单用新配置\n'
  [ -n "$TEAM_SESSION" ] && team_dim "session: $TEAM_SESSION（attach: tmux attach -t $TEAM_SESSION）"
  return 0
}

team_cmd_ps() {
  team_hdr "容量 · $TEAM_PROJECT"
  printf '  %s\n' "$(team_capacity_line)"
  printf '  底线：空闲 swap ≥ %sMB、RAM+swap ≥ %sMB（低于则拒绝派单）；RAM < %sMB 只警告（卡顿）\n' \
    "$TEAM_MIN_FREE_SWAP_MB" "$TEAM_MIN_TOTAL_MB" "$TEAM_WARN_AVAIL_MB"

  printf '\n存活：\n'
  local pm; pm="$(team_pm_state)"
  case "$pm" in
    running:*) printf '  PM（%s）在运行（%s%s）\n' "$TEAM_PM_WINDOW" "${pm#running:}" "$(team_pm_proof_suffix)" ;;
    starting:*) printf '  PM（%s）正在启动（%s；证据：%s）：不重复拉起\n' \
                 "$TEAM_PM_WINDOW" "${pm#starting:}" "$(team_pm_evidence "$pm")" ;;
    idle:*)    printf '  PM（%s）**未在跑**（空提示符）→ team up\n' "$TEAM_PM_WINDOW" ;;
    unknown:*) printf '  PM（%s）窗口里是**非 PM 进程**（%s，cwd=%s）：不算存活 → team up\n' \
                 "$TEAM_PM_WINDOW" "${pm#unknown:}" "$(team_pane_cwd "$(team_pm_target)" 2>/dev/null || echo '?')" ;;
    foreign:*) printf '  PM（%s）窗口被**别的项目**的进程占着（cwd=%s）：不覆盖\n' \
                 "$TEAM_PM_WINDOW" "$(team_pane_cwd "$(team_pm_target)" 2>/dev/null || echo '?')" ;;
    *)         printf '  PM 窗口缺失 → team up\n' ;;
  esac
  printf '  pulse %s\n' "$(team_pulse_state_text)"

  printf '\n%-30s %8s %8s %9s\n' MODEL RUNNING LIMIT WINDOW
  printf '%-30s %8s %8s %9s\n' ----- ------- ----- ---------
  local m limit running seen=" " win
  for m in $TEAM_DEFAULT_MODEL $TEAM_AGENT_MODELS; do
    case "$m" in *=*) m="${m#*=}" ;; esac
    [ -n "$m" ] || continue
    case "$seen" in *" $m "*) continue ;; esac
    seen="$seen$m "
    running="$(team_model_running "$m")"
    limit="$(team_model_limit "$m")"; [ "$limit" = "0" ] && limit="-"
    win="$(team_model_window "$m")"
    [ -n "$win" ] && win="$(team_tokens_human "$win")" || win="?"
    printf '%-30s %8s %8s %9s\n' "$m" "$running" "$limit" "$win"
  done
  team_dim "  WINDOW = 模型上下文窗口（? = 解析不到：TEAM_MODEL_WINDOWS 或 Pi 的模型目录里没有它）"
  # M4.3 A：每个 agent 的会话大小 vs 它当前模型的窗口（只 stat 字节数，不读内容）
  # M14：模型带 ·来源标注（配置/显式/历史记录；历史记录 = 名册旧记录，下次派单用新配置）
  printf '\nagent 会话（估算 tok / 模型窗口）：\n'
  local asess any_sess=0 amodel asrc atok awin abytes afile atext a
  for a in $(team_agents); do
    IFS=$'\t' read -r amodel atok awin abytes afile <<< "$(team_agent_session_cols "$a")"
    case "$atok" in ''|*[!0-9]*) continue ;; esac
    [ "$atok" -gt 0 ] || continue
    any_sess=1
    asrc="$(team_agent_model_src "$a")"
    atext="$(team_session_size_text "$atok" "$awin")"
    printf '  %-10s %-34s %10s' "$a" "$amodel·$asrc" "$atext"
    if [ -n "$awin" ] && [ "$atok" -gt "$awin" ]; then
      printf '  ← 超过窗口：复用会被 dispatch 拒绝（--fresh / --allow-overflow）'
    fi
    printf '\n'
  done
  [ "$any_sess" -eq 0 ] && team_dim "  （无：还没有 agent 会话文件）"
  printf '\n活跃窗口（%s）：\n' "$TEAM_SESSION"
  team_tmux_windows "$TEAM_SESSION" 2>/dev/null | sed 's/^/  - /' || team_dim "  session 不存在"
  return 0
}

team_cmd_status() {
  team_require_docs
  team_scan_warm   # M50：宽度档（不扫报告）——roster 的 $(…) 子壳经 fork 继承热缓存，免 5×loader 重装
  local id="${1:-}"
  team_cmd_roster
  # 延后队列非空时补一行（delivery-guard 的可见性；空队列不打印任何东西）
  team_outbox_status_line "" || true
  # M46：投递通道降级（没有 inbox-watch 注册时绝不静默退回慢路径；没降级就一个字都不加）
  local dbg; dbg="$(team_inbox_watch_degraded_line 2>/dev/null || true)"
  [ -n "$dbg" ] && team_warn "$dbg"
  printf '\n'
  if [ -n "$id" ]; then
    # M16：抬头行也带名字（`任务 M16：沟通纪律…`）—— 保持 `任务 <ID>：` 前缀不变（既有断言/习惯），
    # 名字直接跟在冒号后面（查不到名字时就是原来的行为）。
    printf '任务 %s：%s\n' "$id" "$(team_task_name "$id")"
    team_board_row "$id" | sed 's/^/  /' || true
    if team_find_report "$id" >/dev/null 2>&1; then
      printf '  报告 %s（%s 行）\n' "$(team_find_report "$id")" "$(wc -l < "$(team_find_report "$id")" | tr -d ' ')"
    else
      printf '  报告：缺失\n'
    fi
    [ -f "$TEAM_DOCS_ABS/reviews/$id.md" ] && {
      # F12：路径旁边必须带判定（否则“没跑过门禁的 SKIPPED”和 PASS 在账本上长得一样）
      local rv rhead rnote rextra=""
      rv="$(team_review_record_verdict "$id")"
      rhead="$(team_review_record_head "$id")"
      rnote="$(team_review_record_note "$id")"
      [ -n "$rhead" ] && rextra=" · HEAD $rhead"
      [ -n "$rnote" ] && rextra="$rextra · $rnote"
      printf '  复验 %s（判定: %s%s）\n' "$TEAM_DOCS_ABS/reviews/$id.md" "${rv:-未知}" "$rextra"
    }
    # M9.4：看板已裁决（done/closed）→ 这份报告不列在待复验里。为什么必须说出来：
    # 静默跳过是假阴性藏身的地方，PM 看不到“它没被列”就只能猜。
    local bst brp
    bst="$(team_board_status "$id")"
    case "$bst" in
      done|closed)
        brp="$(team_find_report "$id" 2>/dev/null || true)"
        if [ -n "$brp" ] && team_report_unverified "$id"; then
          printf '  待复验：**不列**（看板是 %s；报告的证据在看板转变时核对，见 %s/reviews/%s-done.md）\n' \
            "$bst" "$TEAM_DOCS_DIR" "$id"
        fi ;;
    esac
  else
    printf 'BOARD：\n'
    grep -E '^\|' "$TEAM_DOCS_ABS/BOARD.md" 2>/dev/null | tail -n +3 | sed 's/^/  /' || true
  fi
  return 0
}

# M31（V18 F-V18-4）：复验/交付记录写在**主仓工作区**却没入账 —— `team review` 把记录写进
# `$TEAM_DOCS_ABS/reviews/`（主仓），而 PM 的 squash 合并只带分支内容：这些文件会原地悬置
# （M22/M28/M30/P18 的 reviews 全部 untracked）。digest 必须让 PM 在合并流里立刻看见。
# 只读：一次 `git status --porcelain`（`--untracked-files=all` 让报告包目录里的文件也点名），
# 不写任何东西。只看**主仓**：agent 工作树里的未提交报告是草稿，[3] 已解释「先等交付」，不重复。
team_untracked_records() { # → 未跟踪的复验/报告记录（相对主仓路径，一行一个）；没有/读不出 → 返回 1
  local out
  out="$(git -C "$TEAM_MAIN_ROOT" status --porcelain --untracked-files=all -- \
        "$TEAM_DOCS_DIR/reviews" "$TEAM_DOCS_DIR/reports" 2>/dev/null)" || return 1
  [ -n "$out" ] || return 1
  # 过滤脚手架文件（.gitkeep/.gitignore）：它们不是记录，只是 docs/team 的目录占位（每个项目 init 时就有）。
  printf '%s\n' "$out" | sed -n 's/^?? //p' | awk -F/ '$NF !~ /^\./'
}

# M31 × M16：记录文件名里带着任务代号，警告行必须随身带名字（与 [3]/[4]/[5] 同一口径）。
# 从路径尽力而为地取候选 id（reviews/<ID>[-suffix].{md,log} / reports/<ID>-<agent>[/…]），
# 逐段往前试「已知任务」；都不认识时退回第一段 —— 查不到名字时调用方只印路径，不编名字。
team_record_task_id() { # <相对主仓路径> → 候选任务 id（取不到 → 空）
  local rel="${1:-}" base comp p
  [ -n "$rel" ] || return 0
  case "$rel" in
    "$TEAM_DOCS_DIR/reviews/"*) base="$(basename "$rel")"; base="${base%.md}"; base="${base%.log}" ;;
    "$TEAM_DOCS_DIR/reports/"*) comp="${rel#"$TEAM_DOCS_DIR/reports/"}"; comp="${comp%%/*}"; base="${comp%.md}" ;;
    *) return 0 ;;
  esac
  p="$base"
  while [ -n "$p" ]; do
    team_task_id_known "$p" && { printf '%s\n' "$p"; return 0; }
    case "$p" in *-*) p="${p%-*}" ;; *) break ;; esac
  done
  printf '%s\n' "${base%%-*}"
}

team_cmd_digest() {
  team_require_docs
  team_scan_warm --reports   # M50：全量档 —— [3] 逐份迭代报告，预热后所有判定函数吃热缓存（判定逻辑不变）
  team_hdr "teamsmith digest · $TEAM_PROJECT · $(team_timestamp)"

  local live=0 total=0 a
  for a in $(team_agents); do
    total=$((total + 1)); team_agent_live "$a" && live=$((live + 1))
  done
  # skill 版本：本会话加载的 vs 磁盘（skill 更新靠 /reload）
  printf '  %s\n' "$(team_update_notice)"

  printf '\n%s\n' "[1] 容量与存活"
  printf '  agent %s/%s 在跑 ｜ %s' "$live" "$total" "$(team_capacity_line)"
  local pm; pm="$(team_pm_state)"
  case "$pm" in
    running:*) printf '  PM ● 在运行（%s%s）' "${pm#running:}" "$(team_pm_proof_suffix)" ;;
    starting:*) printf '  PM ○ 正在启动（%s；不重复拉起）' "${pm#starting:}" ;;
    idle:*)    printf '  PM ○ **未在跑**（空提示符）→ team up' ;;
    unknown:*) printf '  PM ○ 窗口里是非 PM 进程（%s）→ team up' "${pm#unknown:}" ;;
    foreign:*) printf '  PM ○ 窗口被别的项目占着（不覆盖）' ;;
    *)         printf '  PM ○ 窗口缺失 → team up' ;;
  esac
  printf ' ｜ pulse %s\n' "$(team_pulse_state_text)"
  # 延后投递：队列非空才打印（delivery-guard：排队/held 必须看得见；空队列一个字都不加）
  team_outbox_status_line "  " || true
  # M46：投递通道降级（PM 的一行视角；`team_pm_state` 已经在手，复用同一次读取）
  local dbg; dbg="$(team_inbox_watch_degraded_line "$(team_pm_target)" "$pm" 2>/dev/null || true)"
  [ -n "$dbg" ] && team_warn "  $dbg"

  # 待办：这是 pulse 判断“要不要叫醒 PM”的依据
  local pend; pend="$(team_pending_text || true)"
  if team_in_standby; then
    printf '  待命             on（原因：%s）→ pulse 不会叫醒 PM；%s standby off 恢复\n' "$(team_standby_reason || echo -)" "$TEAM_CLI"
  fi
  if [ -n "$pend" ]; then
    # 同一拍里 PM 行与待办行必须一致：suffix 由那**一次** team_pm_state 读取决定（M7.2）
    printf '  待办             %s%s\n' "$pend" "$(team_pm_pending_suffix "$pm")"
  else
    printf '  待办             无（pulse 不会打扰 PM）\n'
  fi

  printf '\n%s\n' "[2] 待处理通知"
  local any=0 n rlabel
  # 收件人 = 名册 + inbox/ 里实际存在的文件（含 PM 自己的收件箱与打错名字的收件箱）：
  # 写了一行却没人看见是 M6.3 F26/F18 的根因。
  for a in $(team_inbox_recipients); do
    n="$(team_inbox_new "$a")"
    if [ "$n" -gt 0 ]; then
      any=1
      rlabel=""; [ "$a" = "pm" ] && rlabel="（PM 自己的收件箱）"
      printf '  %s%s · %s 条新\n' "$a" "$rlabel" "$n"
      team_inbox_since "$a" | tail -3 | sed 's/^/      /'
    fi
  done
  [ "$any" -eq 0 ] && team_dim "  （无）"
  local ign; ign="$(team_reports_ignored || true)"
  [ -n "$ign" ] && team_dim "  忽略的非任务报告：$(printf '%s' "$ign" | tr '\n' ' ')（里程碑/结项类；要计为任务就让它出现在 BOARD 里）"

  printf '\n%s\n' "[3] 待复验（真任务报告：记录缺失 / 记录已过期（分支又动了）/ 没跑过门禁；草稿另标；看板已 done/closed 的不列）"
  any=0
  # M9.4：候选清单只解析一轮，列清单与被看板跳过的清单共用它（这个段落每次巡检都跑）
  local cands; cands="$(team_report_primary_candidates)"
  local rid disp rep where act
  while IFS=$'\t' read -r rid disp rep; do
    [ -n "$disp" ] || continue
    any=1
    where=""
    case "$rep" in
      "$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR/"*)
        local who="${rep#"$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR"/}"; who="${who%%/*}"
        # M9.4 ④：叠分支会把别的任务的报告带进这个工作树 —— 那是副本，不是「在它的分支上」。
        if [ "$(team_report_copy_rank "$rep" "${rid:-${disp%%-*}}")" = "1" ]; then
          where="（在 $who 分支上）"
        else
          where="（副本：在 $who 的工作树里，本任务自己的工作树里没有它）"
        fi ;;
    esac
    # M4.3 C：`team review` 从任务分支的 checkout 里摘录报告 —— 还在 agent 工作区里的草稿摘不到，
    # 所以草稿不能指向 review（“signal 早于可操作”的现场），只说明等交付；仍然列出来（不静默丢）。
    # M9.8：草稿判据只有一份实现（team_report_is_draft）—— 它同时决定「算不算唤醒」（不算）；
    # 两边各判一次就会分家：digest 说「等交付」、watchdog 却按它叫醒你。
    if team_report_is_draft "$rep"; then
      act="report 未提交：先等 agent 交付（不指 review：这份报告还不在任务分支的 HEAD 里）"
    else
      # M9.4：声明了 phase 的任务按 M9.2 的阶段证据给下一步（不是那句通用的 team review）
      act="$(team_report_pending_action "${rid:-${disp%%-*}}")"
    fi
    # M16：待复验清单的每个代号都要在同一行带名字。名字贴在**整条显示单元的最后**
    # （`<报告名> [标记]（归属）（名字）`）：前面的报告名/标记/归属是既有回归断言钉住的产物，
    # 名字加在后面既让同一行有名字，也不动那些历史的守门断言。
    printf '  %s%s%s  %s\n' "$disp" "$where" "$(team_task_name_suffix "${rid:-${disp%%-*}}")" "$act"
  done < <(team_reports_pending_list "$cands")
  [ "$any" -eq 0 ] && team_dim "  （无）"
  local ign; ign="$(team_reports_ignored || true)"
  [ -n "$ign" ] && team_dim "  忽略的非任务报告：$(printf '%s' "$ign" | tr '\n' ' ')（里程碑/结项类；要计为任务就让它出现在 BOARD 里）"
  # M9.4 ③：被看板跳过的要点名（静默跳过 = 假阴性藏身处）。只报「本来会被列出来」的那些：
  # 有有效记录的报告本来也不列，把它们混进来只会制造新噪音。
  local sskip sid sname spath sname_list="" sn=0
  sskip="$(team_reports_skipped_by_board "$cands" || true)"
  while IFS=$'\t' read -r sid sname spath; do
    [ -n "$sid" ] || continue
    # M16：跳过行同样要点到名字（这一行是 PM 唯一能看到「它为什么没列」的地方）
    sn=$((sn + 1)); sname_list="${sname_list:+$sname_list、}${sname}$(team_task_name_suffix "$sid")"
  done <<< "$sskip"
  if [ "$sn" -gt 0 ]; then
    team_dim "  已按看板跳过 ${sn} 份报告（任务已 done/closed）：$sname_list · 证据在 board set 时核对（M9.2），这里不重复质疑"
  fi

  # 待收尾：agent 做了活但没收干净（脏工作区 / 相对 upstream 有未 push 的提交）——CEP 实测的盲区。
  # F4：这里只对「真的没 push 出去」报警；领先保护分支是**另一个指标**，单独标出来（旧实现混为一谈）。
  printf '\n%s\n' "[4] 待收尾（脏工作区 / 相对 upstream 未 push 的提交；领先按 $TEAM_PROTECTED_BRANCH 另计；squash 已合并单独标注）"
  local sa swt sbranch sdirty sahead supahead stask sany=0 sfacts supnote sact
  for sa in $(team_agents); do
    swt="$(team_agent_worktree "$sa")"
    [ -d "$swt" ] || continue
    IFS=$'\t' read -r sbranch sdirty sahead supahead <<< "$(team_git_cols "$swt")"
    # M4.3 D：squash 合并后的分支不是「待收尾」（内容已在保护分支里）：不喊 push、不给 say 建议。
    # 脏工作区 / 真的未 push 优先：那种情况下这个判定不成立，走下面的旧逻辑。
    if team_wrapup_is_squash_merged "$swt" "$sdirty" "$sahead" "$supahead"; then
      sany=1
      stask="$(team_task_label "$(team_state_get "$sa" task '-')")"
      printf '  %-10s %-52s ｜ %s ｜ %s\n' "$sa" "已合并（squash，内容一致）· 无需 push" "$sbranch" "$stask"
      printf '             %s\n' "（启发式：tip 的 tree 出现在 $TEAM_PROTECTED_BRANCH 最近 ${TEAM_SQUASH_LOOKBACK:-200} 个提交里；不放心就 git diff $TEAM_PROTECTED_BRANCH..$sbranch）"
      continue
    fi
    sfacts=""; supnote=""
    [ "${sdirty:-0}" -gt 0 ] 2>/dev/null && sfacts="脏 $sdirty"
    case "${supahead:-}" in
      -)  # 没有 upstream：push 状态无法判定，绝不冒充「未 push N」
          supnote="无 upstream（未 push 无法判定）"
          if [ "${sahead:-0}" -gt 0 ] 2>/dev/null; then
            if [ "${TEAM_VCS:-local}" = "local" ]; then supnote="$supnote · 领先 $TEAM_PROTECTED_BRANCH $sahead（本地模式：PM 合并，不需要 push）"
            else supnote="$supnote · 领先 $TEAM_PROTECTED_BRANCH $sahead（要 push 先 git push -u $TEAM_REMOTE HEAD）"; fi
          fi ;;
      '?') sfacts="${sfacts:+$sfacts · }未 push ?（upstream 解析不到）" ;;
      *)   if [ "${supahead:-0}" -gt 0 ] 2>/dev/null; then
             sfacts="${sfacts:+$sfacts · }未 push $supahead（相对 @{upstream}）· 领先 $TEAM_PROTECTED_BRANCH ${sahead:-?}"
           fi ;;
    esac
    [ -n "$sfacts" ] || [ -n "$supnote" ] || continue
    sany=1
    stask="$(team_task_label "$(team_state_get "$sa" task '-')")"
    sact="${sfacts:-—}"; [ -n "$supnote" ] && sact="${sact}${sact:+ ｜ }$supnote"
    printf '  %-10s %-52s ｜ %s ｜ %s\n' "$sa" "$sact" "$sbranch" "$stask"
    if [ -n "$sfacts" ]; then
      case "${supahead:-}" in
        '?') printf '             → %s say %s "收尾：提交并 push（upstream 解析不到：先 git fetch --prune 或重设 upstream）"\n' "$TEAM_CLI" "$sa" ;;
        *)   printf '             → %s say %s "收尾：提交并 push"\n' "$TEAM_CLI" "$sa" ;;
      esac
    fi
  done
  # M31（V18 F-V18-4）：记录只在工作区、没进任何提交 —— squash 合并带不走它们（归档时才发现就晚了）。
  # M16：路径里带代号 → 每条记录自己一行并随身带名字（不同记录不共行：某条查不到名字时
  # 不能因为同行别处的括号看起来像“给它编了名字”）。
  local recs nrecs total r
  recs="$(team_untracked_records || true)"
  if [ -n "$recs" ]; then
    total="$(printf '%s\n' "$recs" | grep -c .)"
    sany=1
    printf '  %s记录未入账%s       %s 份 untracked（squash 合并只带分支内容，先提交再合并/归档）：\n' \
      "$C_YEL" "$C_RESET" "$total"
    nrecs=0
    while IFS= read -r r; do
      [ -n "$r" ] || continue
      nrecs=$((nrecs + 1))
      if [ "$nrecs" -gt 8 ]; then printf '    · …（另有 %s 份，%s status 看全量）\n' "$((total - 8))" "$TEAM_CLI"; break; fi
      printf '    · %s%s\n' "$r" "$(team_task_name_suffix "$(team_record_task_id "$r")")"
    done <<< "$recs"
  fi
  [ "$sany" -eq 0 ] && team_dim "  （无：没有脏工作区，也没有相对 upstream 的未 push 提交）"

  printf '\n%s\n' "[5] 任务板"
  grep -E '^\|' "$TEAM_DOCS_ABS/BOARD.md" 2>/dev/null | tail -n +3 | awk -F'|' 'NF>2{
    st=$(NF-1); gsub(/^[ \t]+|[ \t]+$/,"",st);
    if (st=="done") d++; else if (st=="wip") w++; else if (st=="review") r++; else if (st=="blocked") b++; else t++
  } END{printf "  todo=%d wip=%d review=%d blocked=%d done=%d\n", t, w, r, b, d}' || true
  grep -E '^\|' "$TEAM_DOCS_ABS/BOARD.md" 2>/dev/null | tail -n +3 | grep -Ev '\|[[:space:]]*done[[:space:]]*\|' | sed 's/^/  /' || true

  printf '\n%s\n' "[5] 建议"
  local suggestion=0
  for a in $(team_agents); do
    if ! team_agent_live "$a"; then
      local task; task="$(team_state_get "$a" task '')"
      [ -n "$task" ] && { printf '  · %s 未在跑但仍有任务 %s → %s dispatch 续跑，或 close %s\n' "$a" "$(team_task_label "$task")" "$TEAM_CLI" "$task"; suggestion=1; }
    fi
  done
  [ "$suggestion" -eq 0 ] && team_dim "  （无）"
  printf '\n'
}

team_cmd_inbox() {
  local agent="" ack=0 all=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --ack) ack=1; shift ;;
      --all) all=1; shift ;;
      -*) team_usage_die "inbox: 未知参数 $1" ;;
      *) agent="$1"; shift ;;
    esac
  done
  local targets=()
  if [ -n "$agent" ]; then targets=("$agent"); else mapfile -t targets < <(team_inbox_recipients); fi
  local a n f label
  for a in "${targets[@]}"; do
    f="$(team_inbox_file "$a")"
    n="$(team_inbox_new "$a")"
    label=""; [ "$a" = "pm" ] && label="（PM 自己的收件箱）"
    if [ "$all" = "1" ]; then
      [ -f "$f" ] || continue
      printf '%s === %s%s（全部 %s 行）%s\n' "$C_BOLD" "$a" "$label" "$(team_inbox_total "$a")" "$C_RESET"
      sed 's/^/  /' "$f"
    else
      [ "$n" -gt 0 ] || continue
      printf '%s === %s%s（新 %s 条）%s\n' "$C_BOLD" "$a" "$label" "$n" "$C_RESET"
      team_inbox_since "$a" | sed 's/^/  /'
    fi
    if [ "$ack" = "1" ]; then
      team_state_set "$a" inbox_lines "$(team_inbox_total "$a")"
    fi
  done
  [ "$ack" = "1" ] && team_ok "已标记为已读（--ack）"
  return 0
}

# ---------------------------------------------------------------- 状态面板（pulse 窗口跑的就是它）
# 真正的渲染在 scripts/panel/panel.js（Ink bundle；纯文本模式 = --print）。这里保留函数名，
# 因为它是面板的文本入口：spawn/诊断不需要知道 bundle 的位置。
team_panel() { team_panel_text "$@"; }
