#!/usr/bin/env bash
# teamsmith · 复验 / 合并 / 收尾：review / merge / pr / close
#
# 设计要点（来自 CEP 的教训）：agent 的自述不算证据，PM 必须在**独立 worktree** 上
# checkout 该分支、跑门禁、看 diff，并把结论写成 <docs>/reviews/<ID>.md。

# 解析分支：--branch > 任务在跑的 agent 的当前分支 > 唯一的 task/<ID>-* 分支
team__resolve_branch() { # <ID> → _R；rc：0=唯一命中 1=找不到 2=歧义。M50 进程内变体（永不 team_die）
  # memo **只记成功结果**（解析是 state/工作树/refs 的纯函数）；失败路径不 memo：
  # 打印版的 team_die 文案是契约，每次都该重新走完整解析。
  local id="$1" a wt b found=""
  _R=""
  if team_scan_cache_on && [ -n "${_TEAM_RESOLVE_BRANCH[$id]+x}" ]; then
    _R="${_TEAM_RESOLVE_BRANCH[$id]}"; return 0
  fi
  for a in $(team_agents); do
    team__state_get "$a" task ''
    [ "$_R" = "$id" ] || continue
    # ① state 里记的分支最可靠（task 模式切换任务后仍能定位）
    team__state_get "$a" branch ''; b="$_R"
    case "$b" in ""|HEAD|"$TEAM_PROTECTED_BRANCH") ;; *)
      _R="$b"; if team_scan_cache_on; then _TEAM_RESOLVE_BRANCH[$id]="$_R"; fi
      return 0 ;;
    esac
    wt="$(team_agent_worktree "$a")"
    [ -d "$wt" ] || continue
    team__worktree_branch "$wt"; b="$_R"   # M50：进程内缓存（原：rev-parse --abbrev-ref HEAD）
    case "$b" in ""|HEAD) ;; *)
      _R="$b"; if team_scan_cache_on; then _TEAM_RESOLVE_BRANCH[$id]="$_R"; fi
      return 0 ;;
    esac
  done
  _R=""
  while IFS= read -r b; do
    case "$b" in
      */"$id"-*|*/"$id") [ -n "$found" ] && { found="AMBIGUOUS"; break; }; found="$b" ;;
    esac
  done < <(team_ref_task_branches)   # M50：refs 一个纪元列一次（原：每个 ID 一次 for-each-ref）
  case "$found" in
    "") return 1 ;;
    AMBIGUOUS) return 2 ;;
    *)
      _R="$found"
      if team_scan_cache_on; then _TEAM_RESOLVE_BRANCH[$id]="$_R"; fi
      return 0 ;;
  esac
}

team_resolve_branch() { # <ID> [--branch b] —— 对外语义一字不变（含找不到/歧义的 team_die 原文）
  local id="$1" branch="${2:-}" rc=0
  if [ -n "$branch" ]; then printf '%s\n' "$branch"; return 0; fi
  team__resolve_branch "$id" || rc=$?   # rc 捕获必须 || 设防：裸调用在 set -e 下会直接带走进程（M50/34 实钉）
  case "$rc" in
    0) printf '%s\n' "$_R" ;;
    1) team_die "找不到 $id 的分支：用 --branch 指定" ;;
    2) team_die "$id 有多个候选分支，用 --branch 指定" ;;
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

# ---------------------------------------------------------------- 复验记录的读取与判定
# 复验记录是 PM 合并的许可证，所以它必须能被账本重新读出来：
#   · digest/status 用「判定 + 被验 HEAD」判断这条记录还新不新鲜（F3：记录只对它验过的 revision 负责）；
#   · 一条“没跑过门禁”的记录（--no-gates → SKIPPED / 未配置 → UNKNOWN）不算证据（F12）。
# 抬头里的 `分支: `x`` / `HEAD: `sha`` / `判定: **X**` 因此是稳定接口（改抬头要同步这些读取函数）。
# M9.5：新鲜度还按**阶段**取被判对象 —— verify 的记录绑定的是被验分支（抬头 `分支:`），复验者自己的
# 分支不是被判对象；其余任务仍是任务分支当前 tip。
team_review_record_path() { printf '%s\n' "$TEAM_DOCS_ABS/reviews/$1.md"; }

# 128+n → 信号名（写复验记录用；认不出来就给数字，不编名字）
team_review_signal_name() { # <signal number> → SIGTERM / SIGKILL / SIG<n>
  local n="${1:-}" name=""
  case "$n" in
    1)  name=SIGHUP ;;
    2)  name=SIGINT ;;
    3)  name=SIGQUIT ;;
    6)  name=SIGABRT ;;
    9)  name=SIGKILL ;;
    14) name=SIGALRM ;;
    15) name=SIGTERM ;;
  esac
  if [ -z "$name" ] && team_have_cmd kill; then
    name="$(kill -l "$n" 2>/dev/null | head -1 || true)"
    case "$name" in ''|*[!A-Za-z]*) name="" ;; *) name="SIG$name" ;; esac
  fi
  [ -n "$name" ] || name="SIG$n"
  printf '%s\n' "$name"
}

team_review_record_verdict() { # <ID> → PASS|FAIL|TIMEOUT|SKIPPED|UNKNOWN（没有记录 → 空）
  team__review_record_verdict "$1"; [ -n "$_R" ] && printf '%s\n' "$_R"; return 0
}

team__review_record_verdict() { # <ID> → _R（M50 进程内变体）
  # M50：纪元内缓存（判定行一个纪元批量扫一次；输出与逐文件 grep 逐字节一致）
  if team_scan_cache_on; then
    _team_rev_cache_load
    _R="${_TEAM_REV_VERDICT[$1]:-}"
    return 0
  fi
  local f v; f="$(team_review_record_path "$1")"
  _R=""
  [ -f "$f" ] || return 0
  v="$(grep -m1 -oE '判定: \*\*[A-Z]+\*\*' "$f" 2>/dev/null || true)"
  [ -n "$v" ] || return 0
  _R="$(printf '%s\n' "$v" | tr -d '*' | sed 's/^判定: //')"
}

team_review_record_head() { # <ID> → 记录里被验的 HEAD（9 位）
  team__review_record_head "$1"; [ -n "$_R" ] && printf '%s\n' "$_R"; return 0
}

team__review_record_head() { # <ID> → _R（M50 进程内变体）
  if team_scan_cache_on; then
    _team_rev_cache_load
    _R="${_TEAM_REV_HEAD[$1]:-}"
    return 0
  fi
  local f h; f="$(team_review_record_path "$1")"
  _R=""
  [ -f "$f" ] || return 0
  h="$(grep -m1 -oE 'HEAD: `[0-9a-f]{7,40}`' "$f" 2>/dev/null || true)"
  [ -n "$h" ] || return 0
  _R="$(printf '%s\n' "$h" | sed -e 's/^HEAD: //' -e 's/`//g')"
}

team_review_branch_tip() { # <ID> → 任务分支当前 tip（解析不到 → 空。分支已被合并删除时为空，不算“过期”）
  local b; b="$(team_resolve_branch "$1" 2>/dev/null || true)"
  [ -n "$b" ] || return 0
  team_branch_tip "$b"   # M50：本地分支走 refs 缓存（原：每次调用一次 rev-parse --verify）
}

# M9.5：verify 任务的被判对象是**记录验过的那个 revision**，不是复验者自己的分支。
# 复验者会把报告提交在自己的分支上（记录写完之后它还会动一格），拿它当判据会把一份「被验东西什么都没变」
# 的记录每拍标成过期 —— 真实现场：V2 的 PASS 记录绑着 P2.1 的 398716887，digest 却按 verify 自己的
# task/V2-… 分支判它 stale。记录抬头里已经写着被验分支，verify 阶段就读它。
team_review_record_branch() { # <ID> → 记录抬头 `时间: … · 分支: \`x\`` 里的分支（没有这个形状 → 空）
  team__review_record_branch "$1"; [ -n "$_R" ] && printf '%s\n' "$_R"; return 0
}

team__review_record_branch() { # <ID> → _R（M50 进程内变体）
  if team_scan_cache_on; then
    _team_rev_cache_load
    _R="${_TEAM_REV_BRANCH[$1]:-}"
    return 0
  fi
  local f b; f="$(team_review_record_path "$1")"
  _R=""
  [ -f "$f" ] || return 0
  # 只认抬头行的形状：正文里引用同一条格式（V1.1/V4.0 的报告里就有）不算
  b="$(awk -F'分支: `' '/^时间: / && NF>1 { split($2, a, "`"); print a[1]; exit }' "$f" 2>/dev/null || true)"
  [ -n "$b" ] || return 0
  _R="$b"
}

# staleness 判定用的「被判对象当前 tip」：
#   apply / 未声明 phase → 任务分支当前 tip（M6.2 的行为，逐字不变）；
#   verify             → 记录绑定的被验分支当前 tip。
# 解析不到（记录没写分支 / 写的是 HEAD / 分支已被合并删除 / 记录绑的是 sha）→ 空 = 无法判定「又动了」。
# 与既有规则一致：解析不到不算过期，否则合并后的任务会永远待办。
team__review_subject_tip() { # <ID> → _R = 被判对象的当前 tip（无法判定 → 空）。M50 进程内变体
  local id="$1" b
  _R=""
  team__task_phase "$id"
  if [ "$_R" = "verify" ]; then
    team__review_record_branch "$id"; b="$_R"
    [ -n "$b" ] || { _R=""; return 0; }
    case "$b" in HEAD|-|—) _R=""; return 0 ;; esac
    team__branch_tip "$b"   # M50：本地分支走 refs 缓存
    return 0
  fi
  # 非 verify：解析记录对应任务的活跃分支（解析不到/歧义 = 原实现子 shell 里 die → 空，不算“过期”）
  local rc=0
  team__resolve_branch "$id" || rc=$?   # 同上：|| 设防，set -e 下裸调用会死在 rc=$? 之前
  if [ "$rc" -ne 0 ]; then _R=""; return 0; fi
  b="$_R"
  [ -n "$b" ] || { _R=""; return 0; }
  team__branch_tip "$b"
}
team_review_subject_tip() { team__review_subject_tip "$1"; [ -n "$_R" ] && printf '%s\n' "$_R"; return 0; }

team_review_record_note() { # <ID> → "" / 一行标记：gates: none / stale: verified A, branch now B
  team__review_record_note "$1"; [ -n "$_R" ] && printf '%s\n' "$_R"; return 0
}

team__review_record_note() { # <ID> → _R = "" / 一行标记（M50 进程内变体；纪元内 memo）
  # note 是（记录抬头 + refs + state）在纪元内的纯函数；digest 一拍对同一 ID 问 2–3 次
  # （pending 全量 / --actionable / skipped_by_board），memo 后只算一次。
  if team_scan_cache_on && [ -n "${_TEAM_REV_NOTE[$1]+x}" ]; then
    _R="${_TEAM_REV_NOTE[$1]}"; return 0
  fi
  local id="$1" verdict rec_head tip
  team__review_record_verdict "$id"; verdict="$_R"
  _R=""
  if [ -n "$verdict" ]; then
    case "$verdict" in
      SKIPPED) _R='gates: none' ;;
      UNKNOWN) _R='gates: unconfigured' ;;
      *)
        team__review_record_head "$id"; rec_head="$_R"
        _R=""   # 捕获后必须清零：下面任何早退路径的 note 都是空（原实现 return 0 无输出）
        if [ -z "$rec_head" ]; then _R='verified revision unknown'
        else
          team__review_subject_tip "$id"; tip="$_R"; _R=""   # 进程内变体；捕获后清 _R（fresh 时 note 为空）
          if [ -n "$tip" ]; then
            case "$tip" in "$rec_head"*) ;; *)
              printf -v _R 'stale: verified %s, branch now %s' "$rec_head" "${tip:0:9}" ;;
            esac
          fi
        fi ;;
    esac
  fi
  if team_scan_cache_on; then _TEAM_REV_NOTE[$id]="$_R"; fi
  return 0
}

# ---------------------------------------------------------------- checkout 内容真相（F8/F9）
team_review_ignored_paths() { # <checkout> → 被 .gitignore 忽略、不在提交里的路径（逐行）
  local d="$1" out=""
  out="$(git -C "$d" status --porcelain --ignored=matching --untracked-files=all 2>/dev/null | sed -n 's/^!! //p' || true)"
  if [ -z "$out" ]; then
    # 老 git 不认 --ignored=matching：退回传统 --ignored（只说目录名，够用）
    out="$(git -C "$d" status --porcelain --ignored 2>/dev/null | sed -n 's/^!! //p' || true)"
  fi
  printf '%s' "$out" | sed '/^$/d'
}

team_review_artifacts() { # <checkout> → 不在提交里的产物："ignored\t<path>" / "untracked\t<path>"
  local d="$1"
  git -C "$d" status --porcelain --untracked-files=all 2>/dev/null | sed -n 's/^?? /untracked\t/p' || true
  team_review_ignored_paths "$d" | sed 's/^/ignored\t/'
}

# ---------------------------------------------------------------- P76 · 合并前的「未入账记录」检查（D45）
# 事实（D45，2026-09-22）：`git merge --squash` 只带**已提交**内容。agent 常把报告/证据包留在工作树里
# 没提交（`??`），或改了 <docs>/ 下的记录没提交（` M`）—— 合并不带它们，工作树一被复用/复位就永久
# 丢了。同一个形状当天丢了 5 次（P36/P40/P42/P65/P67）。既有防线（M31/P47 的 digest 警告）没有坏，
# 但**合并流程根本不跑 digest**：`git merge --squash` 是一条纯 git 命令，它不看 docs/team/。
# 所以合并步要有一条一条命令的自检：`team review <ID> --pre-merge`（非零退出 = 能当合并门）。
# 范围刻意窄：只查**这个任务分支的工作树**（未入账文件只存在于工作树里），只查 <docs>/ 下的记录
# （state/、构建产物等脏文件不拦路；ignored 本来就不在提交里，也不算）；**只打印，不替 agent 提交** ——
# 谁提交的必须是真的，PM 手工提交也要带 `Agent:` trailer（D45）。
team_review_unlanded_records() { # <worktree> → 每行 `<XY>\t<相对路径>`（XY = git status --porcelain 状态码）
  local wt="$1"
  git -C "$wt" status --porcelain --untracked-files=all -- "$TEAM_DOCS_DIR" 2>/dev/null \
    | sed -n 's/^\(..\) \(.*\)$/\1\t\2/p' || true
}

team_review_unlanded_label() { # <XY> → 一行说明（认识的码写清形状，别的落到兜底，不编语义）
  case "$1" in
    '??') printf '未跟踪（新文件，从未提交）' ;;
    ' M') printf '已改未提交（工作区改动）' ;;
    'M ') printf '已暂存未提交' ;;
    'MM') printf '暂存后又有改动' ;;
    'A ') printf '新文件已暂存未提交' ;;
    'AM') printf '新文件已暂存，之后又有改动' ;;
    'D ') printf '删除已暂存未提交' ;;
    ' D') printf '工作区删除未提交' ;;
    *)    printf '未提交改动' ;;
  esac
}

# P76：未入账文件只存在于工作树里，所以先定位**这个任务分支**的工作树（state 里记的分支 → refs 里的
# task/<ID>-*；再扫 .worktrees/ 里停在那个分支上的工作树）。定位不到 → 报错不猜：合并门 fail closed，
# 不能让「没检查」看起来像「没问题」。
team_review_premerge_worktree() { # <ID> → 打印 `<agent>\t<worktree>\t<branch>`；定位不到 → 1
  local id="$1" b="" wt wb rc=0
  team__resolve_branch "$id" || rc=$?
  [ "$rc" = "0" ] || return 1
  b="$_R"; _R=""
  [ -n "$b" ] || return 1
  case "$b" in HEAD|-|—) return 1 ;; esac
  for wt in "$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR"/*/; do
    [ -d "$wt" ] || continue
    wt="${wt%/}"
    [ -e "$wt/.git" ] || continue          # 陈旧目录不是工作树 → 不必花一次 git 调用
    team__worktree_branch "$wt"; wb="$_R"; _R=""
    [ "$wb" = "$b" ] || continue
    printf '%s\t%s\t%s\n' "$(basename "$wt")" "$wt" "$b"
    return 0
  done
  return 1
}

team_cmd_review_premerge() { # <ID>：合并前的未入账记录检查（只读；0=干净且零输出 / 1=有未入账 / 2=无法检查）
  local id="$1" target a wt b records n=0 code path
  local -a rels=()
  if ! target="$(team_review_premerge_worktree "$id")"; then
    team_err "review $id --pre-merge：定位不到这个任务分支的工作树，无法检查未入账记录（不猜）"
    team_err "  解析：state 里没有 task=$id 的分支记录，refs 里也没有唯一的 task/$id-* 分支；或没有工作树停在它上面"
    team_err "  → 看任务/席位/分支：$TEAM_CLI status $id"
    team_err "  → 工作树若已删除，未入账文件也随它消失了（没有内容会被这次合并漏掉）"
    return 2
  fi
  IFS=$'\t' read -r a wt b <<< "$target"
  records="$(team_review_unlanded_records "$wt")"
  [ -n "$records" ] || return 0     # 干净 → 安静（合并门：退出码 0，零输出）
  n="$(printf '%s\n' "$records" | grep -c .)"
  team_err "review $id --pre-merge：$n 份记录未入账（squash 合并只带已提交内容，它们会被留下）"
  printf '  工作树：%s（%s @ %s）\n' "$a" "$wt" "$b"
  printf '  未入账（只看 %s/ 下；ignored 与其它脏文件不算）：\n' "$TEAM_DOCS_DIR"
  while IFS=$'\t' read -r code path; do
    [ -n "$path" ] || continue
    rels+=("$path")
    printf '    %s: %s  [%s %s]\n' "$a" "$path" "$code" "$(team_review_unlanded_label "$code")"
  done <<< "$records"
  printf '  修法（PM 手工提交；skill 不替 agent 提交，提交带 `Agent:` trailer）：\n'
  printf '    git -C %s add -A --' "$wt"
  printf ' %q' "${rels[@]}"
  printf '\n'
  printf '    git -C %s commit -m "docs(team): %s 未入账记录" -m "Agent: %s"\n' "$wt" "$id" "$a"
  printf '  → 提交后重跑：%s review %s --pre-merge\n' "$TEAM_CLI" "$id"
  return 1
}

# ---------------------------------------------------------------- 强复验证据的结构化判定（F13/F14）
# 旧实现是纯关键词 grep：报告只要“提到”翻转 / 独立验证包就被判成“满足”，而 M4.1 之后的
# 英文写法（independent verification package / red before → green after）反倒判“缺”。
# 现在按结构判定，并把「看了什么、命中了哪一行、缺哪一条」写进复验记录（判定必须能解释自己）：
#   翻转   = 有「flip / 翻转 / red→green / 破坏实现」小节，且该小节里同时出现失败(red)与通过(green)结果；
#   独立包 = 报告里给出一条**指向包/脚本的路径**（只说“独立”不提路径不算）+ 独立性声明。
# 命令行、路径是否存在只作为提示项记进记录，不参与判定。
team_strong_cell() { # <"行号:文本"> → 表格单元格用的短文本（去行号、压空白、转义竖线）
  printf '%s' "$1" | sed -e 's/^[^:]*://' -e 's/[[:space:]]\{1,\}/ /g' -e 's/|/\\|/g' | cut -c1-110
}

team_strong_resolve() { # <路径tok> <checkout> <报告> → 解析到的真实路径（按报告里常见的 4 个基准依次尝试）
  local tok="$1" revdir="$2" rep="$3" cand
  for cand in "$revdir/$tok" "$(dirname "$rep")/$tok" "${rep%.md}/$tok"; do
    [ -e "$cand" ] && { printf '%s\n' "$cand"; return 0; }
  done
  if [ -n "${TEAM_MAIN_ROOT:-}" ] && [ -e "$TEAM_MAIN_ROOT/$tok" ]; then
    printf '%s\n' "$TEAM_MAIN_ROOT/$tok"
  fi
  return 0
}

# 报告候选（PM 复现过：只看 checkout 会把“报告在主工作树/agent worktree、checkout 是干净分支”
# 判成“缺证据”，而那正是 F14 这条 finding 本身）：
#   ① checkout 里的报告（在被验 revision 上，最权威）
#   ② 记录里实际会摘录的那份（team_find_report：主工作树 / agent worktree）
# 逐个候选解析，取“证据最全”的那份（翻转有+独立包有 > 一个 > 没有；并列时 checkout 优先），
# 并把候选清单/采用哪份/那份是否在 checkout 里都写进记录。
team_strong_parse() { # <报告> <checkout>；结果写入调用方的 STRONG_* 变量（动态作用域）
  local rep="$1" revdir="$2"
  STRONG_REP="$rep"; STRONG_OK=0; STRONG_SCORE=0; STRONG_IN_CHECKOUT=0
  STRONG_FLIP_HDR=""; STRONG_FLIP_LN=""; STRONG_RED=""; STRONG_RED_LN=""
  STRONG_GREEN=""; STRONG_GREEN_LN=""; STRONG_CMD=""; STRONG_CMD_LN=""
  STRONG_PATH=""; STRONG_PATH_STATE="（报告里没有给出包/脚本路径）"; STRONG_PATH_SRC=""
  STRONG_INDEP=""; STRONG_INDEP_LN=""
  STRONG_FLIP_STATUS="缺"; STRONG_PKG_STATUS="缺"; STRONG_FLIP_WHY=""; STRONG_PKG_WHY=""

  case "$rep" in
    "") STRONG_DISP="（没有找到任务报告）"; STRONG_FLIP_WHY="没有找到任务报告"; STRONG_PKG_WHY="没有找到任务报告"; return 0 ;;
    "$revdir"/*) STRONG_DISP="${rep#"$revdir"/}"; STRONG_IN_CHECKOUT=1 ;;
    *) STRONG_DISP="$rep" ;;
  esac
  [ -f "$rep" ] || { STRONG_FLIP_WHY="报告文件不存在：$rep"; STRONG_PKG_WHY="报告文件不存在"; return 0; }

  # ① 翻转小节：标题措辞对齐 templates/report.md.tmpl 与 references/protocol.md 里实际用的写法
  #    （flip evidence / flip / red before … green after / break the implementation / 翻转 / 破坏 …）
  STRONG_FLIP_HDR="$(grep -m1 -nEi '^#{1,6}[[:space:]].*(flip|red[[:space:]]+before|green[[:space:]]+after|red[[:space:]]*(->|→|/|vs)|红[[:space:]]*(→|->)|翻转|破坏|break[[:space:]]+(the[[:space:]]+)?implementation|回归|regression|guard[[:space:]]+test|守门|adversar|对抗|control[[:space:]]+experiment)' "$rep" 2>/dev/null || true)"
  local sect="" sect_end=""
  if [ -n "$STRONG_FLIP_HDR" ]; then
    STRONG_FLIP_LN="${STRONG_FLIP_HDR%%:*}"
    sect_end="$(awk -v s="$STRONG_FLIP_LN" 'NR>s && /^#{1,6}[[:space:]]/ {print NR-1; exit}' "$rep" 2>/dev/null || true)"
    [ -n "$sect_end" ] || sect_end="$(grep -c '' "$rep" 2>/dev/null || true)"
    sect="$(sed -n "${STRONG_FLIP_LN},${sect_end}p" "$rep" 2>/dev/null || true)"
    STRONG_RED="$(printf '%s\n' "$sect" | grep -m1 -nEi '(^|[^a-z])(red|fail|failed|failing|before|broken)([^a-z]|$)|✗|×|红|失败|未通过|退出码[[:space:]]*[1-9]|rc[[:space:]]*=[[:space:]]*[1-9]|exit[[:space:]]+[1-9]' 2>/dev/null || true)"
    STRONG_GREEN="$(printf '%s\n' "$sect" | grep -m1 -nEi '(^|[^a-z])(green|pass|passed|after|restore|restored)([^a-z]|$)|✓|绿|通过|恢复|退出码[[:space:]]*0|rc[[:space:]]*=[[:space:]]*0|exit[[:space:]]+0' 2>/dev/null || true)"
    STRONG_CMD="$(printf '%s\n' "$sect" | grep -m1 -nE '^[[:space:]]*(\$[[:space:]]|bash[[:space:]]|sh[[:space:]]|git[[:space:]]|team[[:space:]]|python3?[[:space:]]|node[[:space:]]|bun[[:space:]]|npm[[:space:]]|pnpm[[:space:]]|make[[:space:]]|cargo[[:space:]]|go[[:space:]]|pytest|\./|[A-Za-z0-9_.@+-]+/[A-Za-z0-9_.@+-]*\.sh)' 2>/dev/null || true)"
    [ -n "$STRONG_RED" ] && STRONG_RED_LN="$((STRONG_FLIP_LN + ${STRONG_RED%%:*} - 1))"
    [ -n "$STRONG_GREEN" ] && STRONG_GREEN_LN="$((STRONG_FLIP_LN + ${STRONG_GREEN%%:*} - 1))"
    [ -n "$STRONG_CMD" ] && STRONG_CMD_LN="$((STRONG_FLIP_LN + ${STRONG_CMD%%:*} - 1))"
  fi
  if [ -n "$STRONG_FLIP_HDR" ] && [ -n "$STRONG_RED" ] && [ -n "$STRONG_GREEN" ]; then
    STRONG_FLIP_STATUS="有"
  elif [ -z "$STRONG_FLIP_HDR" ]; then
    STRONG_FLIP_WHY="没有 flip/翻转/red before…green after/破坏实现 小节标题"
  elif [ -z "$STRONG_RED" ]; then
    STRONG_FLIP_WHY="翻转小节里没有失败(red)结果"
  else
    STRONG_FLIP_WHY="翻转小节里没有通过(green)结果"
  fi

  # ② 独立验证包：一条**路径**（不是词）+ 独立性声明
  #    路径接受：存在的脚本/目录（PM 要求：任何指向脚本/目录且真实存在的路径）、
  #    包形状路径（.../pkg/run.sh、docs/team/reports/<ID>-<agent>/pkg/...，未提交也算——
  #    记录里会注明“checkout 里没有这个路径”）。
  STRONG_INDEP="$(grep -nEi 'independent|not[[:space:]]+re(using|use)|does[[:space:]]+not[[:space:]]+reuse|from[[:space:]]+scratch|不复用|不依赖|独立(验证|复验|包|测试)|自写|从零|自有' "$rep" 2>/dev/null | grep -viE 'no[[:space:]]|没有|不存在|缺|merely|只是提到' | head -1 || true)"
  if [ -n "$STRONG_INDEP" ]; then STRONG_INDEP_LN="${STRONG_INDEP%%:*}"; fi
  local rep_rel="" tmp="" best_tok="" best_score=0 tok score pkgish script exists real
  case "$rep" in "$revdir"/*) rep_rel="${rep#"$revdir"/}" ;; esac
  tmp="$(mktemp)"
  sed 's#https\{0,1\}://[^ )]*##g' "$rep" > "$tmp" 2>/dev/null || cp "$rep" "$tmp"
  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    tok="$(printf '%s' "$tok" | sed 's/[.,;:)（(]*$//')"
    [ -n "$tok" ] || continue
    [ "$tok" = "$rep_rel" ] && continue
    local resp=""; resp="$(team_strong_resolve "$tok" "$revdir" "$rep")"
    exists=0; [ -n "$resp" ] && exists=1
    pkgish=0; script=0
    case "$tok" in
      *.sh|*.mjs|*.js|*.ts|*.py) script=1 ;;
    esac
    real=0
    # 「真实存在的脚本/目录」：目录 / 可执行 / 脚本后缀都算（`bash pkg/run.sh` 不需要 +x）
    if [ "$exists" = "1" ] && { [ -d "$resp" ] || [ -x "$resp" ] || [ "$script" = "1" ]; }; then real=1; fi
    case "$tok" in
      *pkg*|*package*|*verif*|*adversar*|*attack*|*flip*|*repro*) pkgish=1 ;;
    esac
    [ "$real" = "1" ] || [ "$pkgish" = "1" ] || [ "$script" = "1" ] || continue
    score=$((real * 4 + pkgish * 2 + script))
    if [ "$score" -gt "$best_score" ]; then best_score="$score"; best_tok="$tok"; fi
  done < <( { grep -nEo '([A-Za-z0-9_.@+-]+/)+[A-Za-z0-9_.@+-]+' "$tmp" 2>/dev/null || true; \
              grep -nEo '[A-Za-z0-9_.@+-]+\.(sh|mjs|js|ts|py)' "$tmp" 2>/dev/null || true; } | sed 's/^[0-9]*://' )
  rm -f "$tmp"
  if [ -n "$best_tok" ]; then
    STRONG_PATH="$best_tok"
    local res; res="$(team_strong_resolve "$best_tok" "$revdir" "$rep")"
    if [ -n "$res" ]; then
      case "$res" in
        "$revdir"/*) STRONG_PATH_STATE="checkout 里存在（$([ -d "$res" ] && echo 目录 || echo 文件)：${res#"$revdir"/}）" ;;
        *) STRONG_PATH_STATE="**不在 checkout 里**，但相对主工作树存在：${res#"$TEAM_MAIN_ROOT"/}（未随被验分支提交）" ;;
      esac
    else
      STRONG_PATH_STATE="**checkout 里没有这个路径（未随分支提交）**"
    fi
  fi
  if [ -n "$STRONG_PATH" ]; then
    STRONG_PKG_STATUS="有"
  else
    STRONG_PKG_WHY="报告里没有给出包/脚本的路径（只出现“独立”这种词不算；路径可以是 .../pkg/run.sh、docs/team/reports/<ID>-<agent>/pkg/… 或任何真实存在的脚本/目录）"
  fi

  [ "$STRONG_FLIP_STATUS" = "有" ] && STRONG_SCORE=$((STRONG_SCORE + 2))
  [ "$STRONG_PKG_STATUS" = "有" ] && STRONG_SCORE=$((STRONG_SCORE + 1))
  [ "$STRONG_FLIP_STATUS" = "有" ] && [ "$STRONG_PKG_STATUS" = "有" ] && STRONG_OK=1
  return 0
}

team_strong_scan() { # <checkout> <ID> → 打印复验记录用的「强复验」markdown 块
  local revdir="$1" id="$2" c r chosen="" best_rep="" best_score=-1 cand_list=""
  local -a cands=()
  for c in "$revdir/$TEAM_DOCS_DIR/reports/$id-"*.md; do [ -f "$c" ] && cands+=("$c"); done
  c="$(team_find_report "$id" 2>/dev/null || true)"
  if [ -n "$c" ] && [ -f "$c" ]; then
    local cr cd dup=0
    cr="$(readlink -f "$c" 2>/dev/null || printf '%s' "$c")"
    for cd in "${cands[@]:-}"; do
      [ -n "$cd" ] || continue
      [ "$(readlink -f "$cd" 2>/dev/null || printf '%s' "$cd")" = "$cr" ] && dup=1
    done
    [ "$dup" = "1" ] || cands+=("$c")
  fi
  for c in "${cands[@]:-}"; do
    [ -n "$c" ] || continue
    case "$c" in "$revdir"/*) cand_list="$cand_list\`${c#"$revdir"/}\`（checkout 内）　" ;; *) cand_list="$cand_list\`$c\`（主工作树/agent worktree）　" ;; esac
  done
  for c in "${cands[@]:-}"; do
    [ -n "$c" ] || continue
    team_strong_parse "$c" "$revdir"
    if [ "$STRONG_OK" = "1" ]; then chosen="$c"; best_rep="$c"; best_score=9; break; fi
    if [ "$STRONG_SCORE" -gt "$best_score" ]; then best_score="$STRONG_SCORE"; best_rep="$c"; fi
  done
  team_strong_parse "$best_rep" "$revdir"     # 重新解析被选中的那份（所有 STRONG_* 都用它渲染）

  printf '## 强复验（结构化判定：翻转证据 + 独立验证包）\n\n'
  printf -- '- 报告候选（%s）：%s\n' "${#cands[@]}" "${cand_list:-（无）}"
  if [ -n "$STRONG_REP" ]; then
    printf -- '- 采用：`%s`［%s］\n' "$STRONG_DISP" "$([ "$STRONG_IN_CHECKOUT" = "1" ] && echo '在被验的 checkout 里' || echo '不在 checkout 里（被验 revision 上没有这份报告）')"
  else
    printf -- '- 采用：（没有找到任务报告）\n'
  fi
  printf -- '- 判定规则（大小写不敏感，措辞对齐 templates/report.md.tmpl 与 references/protocol.md）：\n'
  printf -- '  **翻转** = 有「flip / flip evidence / red before…green after / break the implementation / 翻转 / 破坏」小节，且该小节里同时出现失败(red)与通过(green)结果；\n'
  printf -- '  **独立包** = 报告里给出一条**路径**（形如 `.../pkg/run.sh`、`docs/team/reports/<ID>-<agent>/pkg/...`，或任何真实存在的脚本/目录）；独立性声明只作提示项记录。\n'
  printf -- '- 命令行、路径是否存在只作提示项记录，不参与判定（避免“结论看起来比证据强”）。\n\n'
  printf '| 证据 | 结果 | 依据（文件:行 · 命中文本） |\n'
  printf '| --- | --- | --- |\n'
  printf '| 翻转小节 | %s | %s |\n' "$STRONG_FLIP_STATUS" "$([ -n "$STRONG_FLIP_LN" ] && printf '`%s:%s`「%s」' "$STRONG_DISP" "$STRONG_FLIP_LN" "$(team_strong_cell "$STRONG_FLIP_HDR")" || printf '（无）')"
  printf '| 翻转结果 red（失败侧） | %s | %s |\n' "$([ -n "$STRONG_RED" ] && echo 有 || echo 缺)" "$([ -n "$STRONG_RED_LN" ] && printf '`%s:%s`「%s」' "$STRONG_DISP" "$STRONG_RED_LN" "$(team_strong_cell "$STRONG_RED")" || printf '（无）')"
  printf '| 翻转结果 green（通过侧） | %s | %s |\n' "$([ -n "$STRONG_GREEN" ] && echo 有 || echo 缺)" "$([ -n "$STRONG_GREEN_LN" ] && printf '`%s:%s`「%s」' "$STRONG_DISP" "$STRONG_GREEN_LN" "$(team_strong_cell "$STRONG_GREEN")" || printf '（无）')"
  printf '| 可复现命令（提示项） | %s | %s |\n' "$([ -n "$STRONG_CMD" ] && echo 有 || echo 缺)" "$([ -n "$STRONG_CMD_LN" ] && printf '`%s:%s`「%s」' "$STRONG_DISP" "$STRONG_CMD_LN" "$(team_strong_cell "$STRONG_CMD")" || printf '（无：证据可以只是一个包路径，只要另一半有命令即可复核）')"
  printf '| 独立包路径 | %s | %s |\n' "$([ -n "$STRONG_PATH" ] && echo 有 || echo 缺)" "$([ -n "$STRONG_PATH" ] && printf '`%s`「%s」→ %s' "$STRONG_DISP" "$STRONG_PATH" "$STRONG_PATH_STATE" || printf '（无）')"
  printf '| 独立性声明（提示项） | %s | %s |\n' "$([ -n "$STRONG_INDEP" ] && echo 有 || echo 缺)" "$([ -n "$STRONG_INDEP" ] && printf '`%s:%s`「%s」' "$STRONG_DISP" "$STRONG_INDEP_LN" "$(team_strong_cell "$STRONG_INDEP")" || printf '（无）')"
  if [ "$STRONG_OK" = "1" ]; then
    printf '| **判定** | **满足强复验** | 翻转证据与独立包路径都可结构化复核%s |\n' "$([ -n "$STRONG_INDEP" ] && echo '' || echo '（提示：报告里没有独立性声明）')"
  else
    local why=""
    [ "$STRONG_FLIP_STATUS" = "缺" ] && why="翻转：$STRONG_FLIP_WHY"
    [ "$STRONG_PKG_STATUS" = "缺" ] && why="${why:+$why；}独立包：$STRONG_PKG_WHY"
    printf '| **判定** | **不满足（不阻塞合并，但里程碑收口前应补齐）** | 缺：%s |\n' "$why"
  fi
}

team_cmd_review() {
  team_require_docs
  local id="" branch="" no_gates=0 strong=0 revdir="" allow_unresolved=0 pre_merge=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --branch) branch="${2:?}"; shift 2 ;;
      --no-gates) no_gates=1; shift ;;
      --strong) strong=1; shift ;;          # 强复验：结构化判定对抗性验证包 + finding 翻转证据（team_strong_scan）
      --allow-unresolved-branch) allow_unresolved=1; shift ;;   # 显式覆盖：给解析不到的分支/提交盖章（会写进记录）
      --dir) revdir="${2:?}"; shift 2 ;;    # PM 准备好的独立 checkout（skill 不碰 git）
      --pre-merge) pre_merge=1; shift ;;    # P76/D45：合并前查任务工作树里未入账的 <docs>/ 记录（不跑门禁、不写记录）
      -*) team_usage_die "review: 未知参数 $1" ;;
      *) id="$1"; shift ;;
    esac
  done
  [ -n "$id" ] || team_usage_die "review <ID> --dir <独立checkout> [--no-gates] [--strong] [--allow-unresolved-branch]
  或：review <ID> --pre-merge   # 合并前查这个任务工作树里未入账的 <docs>/ 记录（D45/P76；不跑门禁、不写记录）"
  # P76/D45：--pre-merge 是合并门前置检查（只读；干净时零输出、退出码 0）。它不是一次复验：不跑门禁、
  # 不写记录、不动工作树，所以与复验专用的旋钮互斥 —— 含混用法直接拒绝，不猜。
  if [ "$pre_merge" = "1" ]; then
    [ -z "$revdir" ] || team_usage_die "review $id --pre-merge 不与 --dir 同用（它只查任务工作树，不是一次复验）"
    [ "$no_gates" = "0" ] || team_usage_die "review $id --pre-merge 不与 --no-gates 同用（它不跑门禁）"
    [ "$strong" = "0" ] || team_usage_die "review $id --pre-merge 不与 --strong 同用（它不跑门禁）"
    [ "$allow_unresolved" = "0" ] || team_usage_die "review $id --pre-merge 不与 --allow-unresolved-branch 同用"
    [ -z "$branch" ] || team_usage_die "review $id --pre-merge 不与 --branch 同用（任务分支由 state/refs 自动定位）"
    local pm_rc=0
    team_cmd_review_premerge "$id" || pm_rc=$?
    return "$pm_rc"
  fi
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
  # ── F7（V4.0·high）：--branch 解析不到时旧实现整段跳过一致性守卫 —— 任何干净的 checkout
  #    都能被盖上「分支: no-such-branch」的章，记录从此与真实验过的 revision 不符。
  #    现在默认 **fail closed**：解析不到就拒绝，并说清期望什么 ref、找到了哪些候选。
  #    合法场景（复验已删分支的历史提交）→ --allow-unresolved-branch，且写进复验记录。
  local want_head="" unresolved_override=0
  want_head="$(git -C "$TEAM_MAIN_ROOT" rev-parse --verify --quiet "$branch^{commit}" 2>/dev/null || true)"
  if [ -z "$want_head" ]; then
    if [ "$allow_unresolved" = "1" ] || [ "${TEAM_REVIEW_ALLOW_UNRESOLVED_BRANCH:-0}" = "1" ]; then
      unresolved_override=1
      team_warn "分支 $branch 在主工作树里解析不到：--allow-unresolved-branch 显式覆盖（会写进复验记录）"
    else
      local cands
      cands="$(git -C "$TEAM_MAIN_ROOT" for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null | grep -F -- "$id" | head -5 || true)"
      [ -n "$cands" ] || cands="（没有名字里带 $id 的本地分支）"
      team_die "分支解析不到（不拒绝就会盖章到一个不存在的 revision）：$branch
  期望：在 $TEAM_MAIN_ROOT 里 \`$branch^{commit}\` 能解析成一个提交；实际解析不到
  --dir 的 HEAD：$(git -C "$revdir" rev-parse --short HEAD)（checkout 现在在：$branch_now）
  名字里带 $id 的本地分支：
$(printf '%s\n' "$cands" | sed 's/^/    /')
  → 用真实存在的分支重跑：$TEAM_CLI review $id --dir $revdir --branch <existing-branch>
  → 确实要给一个解析不到的分支/提交盖章（已删分支、外部 revision）：加 --allow-unresolved-branch（会写进复验记录）"
    fi
  fi
  if [ -n "$want_head" ] && [ "$want_head" != "$head" ] && [ "${TEAM_REVIEW_ANY_DIR:-0}" != "1" ]; then
    team_die "checkout 与任务分支不一致（复验会验错东西）：分支 $branch = ${want_head:0:9}，--dir 的 HEAD = ${head:0:9}
  → 重新准备：git -C $TEAM_MAIN_ROOT worktree add --detach /tmp/review-$id $branch
  → 确实要用这个 checkout（比如复验一个历史提交）：TEAM_REVIEW_ANY_DIR=1 $TEAM_CLI review $id --dir $revdir --branch ${head:0:9}"
  fi
  # ── F8 + F9（V4.0）：“干净”必须是真的。
  #    F8：TEAM_REVIEW_ALLOW_DIRTY=1 覆盖时旧实现照样打印「干净」、记录里没有脏树标注；
  #    F9：git status --porcelain 看不见 ignored 文件，门禁能读一个不在提交里的产物而记录说 PASS。
  #    现在：脏树/被忽略产物都记进记录（数量 + 路径头部 + 用的是哪个覆盖开关）；ignored 默认拒绝。
  local dirty_n=0 dirty_override=0 ignored_n=0 ignored_override=0 ignored_list="" artifacts_before=""
  dirty_n="$(git -C "$revdir" status --porcelain 2>/dev/null | grep -c . || true)"
  ignored_list="$(team_review_ignored_paths "$revdir")"
  ignored_n="$(printf '%s' "$ignored_list" | grep -c . || true)"
  artifacts_before="$(team_review_artifacts "$revdir")"
  if [ "${dirty_n:-0}" -gt 0 ] 2>/dev/null; then
    if [ "${TEAM_REVIEW_ALLOW_DIRTY:-0}" != "1" ]; then
      team_die "checkout 有 $dirty_n 处未提交改动：复验必须在干净提交上跑（否则盖章的不是分支上的代码）
$(git -C "$revdir" status --short | head -5)
  → 看是什么：git -C $revdir status --short
  → 干净重建：git -C $TEAM_MAIN_ROOT worktree remove --force $revdir && git -C $TEAM_MAIN_ROOT worktree add --detach $revdir $branch
  → 确认要在脏树上跑：TEAM_REVIEW_ALLOW_DIRTY=1 $TEAM_CLI review $id --dir $revdir"
    fi
    dirty_override=1
  fi
  if [ "${ignored_n:-0}" -gt 0 ] 2>/dev/null; then
    if [ "${TEAM_REVIEW_ALLOW_IGNORED:-0}" != "1" ]; then
      team_die "checkout 里有 $ignored_n 个被 .gitignore 忽略、不在提交里的产物（门禁会读到它们，而 status --porcelain 看不见）：
$(printf '%s\n' "$ignored_list" | head -5)
  → 干净重建：git -C $TEAM_MAIN_ROOT worktree remove --force $revdir && git -C $TEAM_MAIN_ROOT worktree add --detach $revdir $branch
  → 确认要在这种树上跑：TEAM_REVIEW_ALLOW_IGNORED=1 $TEAM_CLI review $id --dir $revdir"
    fi
    ignored_override=1
  fi
  local dir_state=""
  if [ "$dirty_override" = "1" ]; then dir_state="dirty: $dirty_n 处未提交改动（TEAM_REVIEW_ALLOW_DIRTY=1 覆盖）"; fi
  if [ "$ignored_override" = "1" ]; then dir_state="${dir_state:+$dir_state；}ignored: $ignored_n 个未提交产物（TEAM_REVIEW_ALLOW_IGNORED=1 覆盖）"; fi
  if [ "$unresolved_override" = "1" ]; then dir_state="${dir_state:+$dir_state；}分支 $branch 未解析（--allow-unresolved-branch 覆盖）"; fi
  [ -n "$dir_state" ] || dir_state="干净"
  if [ "$dirty_override$ignored_override$unresolved_override" = "000" ]; then
    team_ok "review checkout: $revdir @ ${head:0:9}（分支 $branch，$dir_state）"
  else
    team_warn "review checkout: $revdir @ ${head:0:9}（分支 $branch，$dir_state）"
  fi

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
  local verdict="PASS" gates_out="" gate_timeout="${TEAM_REVIEW_TIMEOUT:-1800}" gates_marker="ran"
  local gate_elapsed="" gate_signal=""   # 门禁实际用时 / 被信号终止的信号名（写进复验记录）
  # G1（P26）：门禁锁的排队阶段与记账。queue_state: none（门禁没跑）/ held（祖先持有）/ queued（本
  # 次自己排队）/ noqueue（没有 flock，降级）/ cap（排队超上限，门禁没跑）。
  local queue_state="none" queue_marker="" queued_elapsed="" queue_holder="" used_lock="" lock_cap=""
  if [ "$no_gates" = "1" ]; then
    verdict="SKIPPED"; gates_marker="none"
    gates_out="（--no-gates：PM 选择人工看 diff；**没有跑过任何门禁**，本记录不是 PASS 证据）"
  elif [ -z "$TEAM_GATES" ]; then
    verdict="UNKNOWN"; gates_marker="unconfigured"
    gates_out="（TEAM_GATES 未配置：无法自动判定，只能人工评审）"
  else
    # CEP 教训：池无超时 × 测试无 --test-timeout × bash timeout 设成 1800000s → 门禁挂死 85 分钟。
    # 所以门禁一律套硬超时；超时按失败处理并明确写进复验记录。
    # F10/F11（V4.0）：判定只认 timeout **包装器**的退出码（124=TERM 生效；137=TERM 被忽略后
    # 被 kill-after KILL），绝不 grep 门禁自己的日志 —— 旧实现既漏掉真挂死（GNU timeout 默认
    # 不打字），又把「日志里恰好有 timeout 字样」的普通失败记成 TIMEOUT。
    # F15（M6.5）：124/137 只是「可能是超时」，不是证据本身 —— 门禁自己 exit 124、或套件里某个测试
    # 把 124 传上来，也会被记成「被 deadline 杀死」（实测：同一次 smoke 一次记 TIMEOUT、一次记 FAIL）。
    # 现在两条证据都要：包装器退出码 **且** 实际用时确实贴住 deadline；否则就是 FAIL（被信号终止时
    # 把信号名字也记下来，不拿「超时」顶替「被杀」）。
    local runner=() used_timeout=0
    if team_have_cmd timeout && [ "${gate_timeout:-0}" -gt 0 ] 2>/dev/null; then
      runner=(timeout --verbose --signal=TERM --kill-after=60 "$gate_timeout")
      used_timeout=1
    fi
    # M25-①：门禁子进程**不许**继承复验覆盖项（TEAM_REVIEW_*）。它们是 review 自己的旋钮，
    # 泄漏进去会让门禁里的夹具自己放行（现场：TEAM_REVIEW_ANY_DIR=1 把 smoke 里「拿错 checkout
    # 必须拒绝」的三条断言放水成绿）。这里逐个剥掉环境里实际存在的 TEAM_REVIEW_*，review 自己在
    # 父进程里照旧读得到（TEAM_REVIEW_TIMEOUT / GRACE 的行为不变）。
    local -a gate_env=() rev_var
    while IFS= read -r rev_var; do
      [ -n "$rev_var" ] && gate_env+=(-u "$rev_var")
    done < <(env | sed -n 's/^\(TEAM_REVIEW_[A-Za-z0-9_]*\)=.*$/\1/p')
    team_info "跑门禁：$TEAM_GATES（硬超时 ${gate_timeout}s；可调 TEAM_REVIEW_TIMEOUT）"
    # ── 排队阶段（P26/G1）：先拿共享门禁锁，再开硬超时时钟 ──────────────────────────────────
    # 事故（M49，2026-09-20 07:49）：门禁命令自己会在 ${TMPDIR}/teamsmith-smoke.lock 上排队
    # （smoke.sh 的 M23 互斥）—— 那一轮排了 930s、跑 870s，硬超时在 28-i 段掐断的是**运行**，
    # 记录却写成 TIMEOUT，而同一个 HEAD 在机器安静后是 PASS 的。硬超时只该量运行：排队是 review
    # 自己的、有上限、可记账的阶段。
    #   held    —— 环境里已经有 SMOKE_LOCK_WRAPPED=1（祖先持有锁）：子树已被串行化，不再二次排队
    #              （否则每一层 team review 都会和自己的祖先死锁）。
    #   noqueue —— 没有 flock：打印降级，照跑（**不是**静默跳过；见 references/protocol.md §9b）。
    # 其它用具：TEAM_SMOKE_LOCK（路径，默认同 smoke）、TEAM_SMOKE_LOCK_WAIT（上限，默认 1800s）。
    local lock="${TEAM_SMOKE_LOCK:-${TMPDIR:-/tmp}/teamsmith-smoke.lock}"
    local queue_started gate_end marker_epoch
    lock_cap="${TEAM_SMOKE_LOCK_WAIT:-1800}"
    case "$lock_cap" in ''|*[!0-9]*) lock_cap=1800 ;; esac
    queue_started="$(date +%s)"
    queue_marker="$(mktemp "${TMPDIR:-/tmp}/teamsmith-review-queue.XXXXXX" 2>/dev/null || true)"
    queue_holder="$(cat "$lock.holder" 2>/dev/null || printf '持有者未知')"
    if [ "${SMOKE_LOCK_WRAPPED:-0}" = "1" ]; then
      queue_state="held"
      team_info "门禁锁：已由祖先持有（SMOKE_LOCK_WRAPPED=1）→ 本次不排队"
    elif ! command -v flock >/dev/null 2>&1; then
      queue_state="noqueue"
      team_warn "本机没有 flock → 门禁排队未启用（并发两套门禁时可能互相干扰；见 references/protocol.md §9b）"
    elif ! mkdir -p "$(dirname "$lock")" 2>/dev/null || ! : >>"$lock" 2>/dev/null; then
      queue_state="noqueue"
      team_warn "锁文件 $lock 建不了 → 门禁排队未启用（并发两套门禁时可能互相干扰）"
    else
      queue_state="queued"
      # `flock -n` 返回 1 = 锁被别人持有（expected，不是错误）——CLI 是 `set -euo pipefail`，
      # 裸跑一条会返回 1 的命令会当场把整个 review 打断（实测：改完第一版 review 在零秒里静默退出）。
      local lock_probe=0
      flock -n "$lock" true 2>/dev/null || lock_probe=$?
      if [ "$lock_probe" -eq 1 ]; then
        team_info "门禁锁正被持有（${queue_holder}）；排队，最多等 ${lock_cap}s（TEAM_SMOKE_LOCK_WAIT 可调）"
      elif [ "$lock_probe" -gt 1 ]; then
        team_warn "flock 探锁失败（rc=${lock_probe}）→ 仍按排队路径走（拿不到锁时会报排队超限）"
      fi
      # 用 flock --close 包住「写 marker + 写持有者 + 跑门禁」整段：--close 让门禁的子孙拿不到锁 fd
      # （M23 的漏锁教训：夹具留下的后台进程继承 fd，脚本退出后锁还挂着）。marker 是「真的拿到锁」
      # 的唯一证据 —— 没有它就只有两种情况：排队被上限掐掉，或 flock 起不来。
      export SMOKE_LOCK_WRAPPED=1
      export TEAM_SMOKE_LOCK="$lock"
      used_lock="$lock"
    fi
    local gate_rc=0 gate_started grace deadline_min
    local QUEUE_WRAP='marker="$1"; holder="$2"; id="$3"; shift 3; date +%s > "$marker"; printf "%s pid=%s cmd=team review %s\n" "$(date -Is)" "$$" "$id" > "$holder" 2>/dev/null || true; exec "$@"'
    local -a gate_cmd=()
    if [ "$queue_state" = "queued" ]; then
      gate_cmd=(flock --close -w "$lock_cap" "$lock" bash -c "$QUEUE_WRAP" _ "$queue_marker" "$lock.holder" "$id")
    fi
    gate_cmd+=(${runner[@]+"${runner[@]}"} env ${gate_env[@]+"${gate_env[@]}"} bash -c "$TEAM_GATES")
    # M25-②：门禁的 stdin 必须是 /dev/null，**不能**是调用者的 tty。实测（tests/smoke.sh 6i-b）：
    # 后台进程组里的子进程一读 tty 就吃 SIGTTIN 被**停住**（STAT=TN，0% CPU，看着像挂死；
    # 登录 profile 里的 host-spawn 就会碰 tty）。复验常在后台窗口里跑，门禁不能依赖 tty。
    ( cd "$revdir" && "${gate_cmd[@]}" ) > "$log" 2>&1 < /dev/null || gate_rc=$?
    gate_end="$(date +%s)"
    if [ -n "$queue_marker" ] && [ -s "$queue_marker" ]; then
      marker_epoch="$(cat "$queue_marker" 2>/dev/null)"
      case "$marker_epoch" in ''|*[!0-9]*) marker_epoch="$(date +%s)" ;; esac
      queued_elapsed=$(( marker_epoch - queue_started ))
      [ "$queued_elapsed" -lt 0 ] && queued_elapsed=0
      gate_elapsed=$(( gate_end - marker_epoch ))
    else
      gate_elapsed=$(( gate_end - queue_started ))
    fi
    # 排队超上限：flock 没拿到锁（没有 marker）→ 门禁**没有运行**。判定 FAIL 而不是 TIMEOUT：
    # 「没跑」和「跑了被杀」必须能分开（记录里点名持锁者与上限）。
    if [ "$queue_state" = "queued" ] && [ -z "$(cat "$queue_marker" 2>/dev/null)" ]; then
      verdict="FAIL"
      gates_marker="queuecap"
      queued_elapsed=$(( gate_end - queue_started ))
      [ "$queued_elapsed" -lt 0 ] && queued_elapsed=0
      gates_out="（门禁锁排队超过上限 ${lock_cap}s：**门禁没有运行**。持锁者：${queue_holder}。这不是对代码的判定 —— 等持锁者结束，或抬 TEAM_SMOKE_LOCK_WAIT 后重跑。）"
      gate_elapsed=""
      used_timeout=0
      used_lock="$lock"
      team_err "门禁锁排队超过上限 ${lock_cap}s → 门禁没有运行（持锁者：${queue_holder}）"
    fi
    grace="${TEAM_REVIEW_TIMEOUT_GRACE:-2}"
    case "$grace" in ''|*[!0-9]*) grace=2 ;; esac
    deadline_min=$(( gate_timeout - grace ))
    [ "$deadline_min" -lt 0 ] && deadline_min=0
    if [ "$gate_rc" -eq 0 ]; then
      verdict="PASS"
    else
      verdict="FAIL"
      if [ "$used_timeout" = "1" ] && [ "$gate_elapsed" -ge "$deadline_min" ]; then
        case "$gate_rc" in
          124) verdict="TIMEOUT"
               printf '\n[teamsmith] 门禁在 %ss 未结束，被硬超时终止（timeout 包装器退出码 124：TERM 生效；实际用时 %ss；判定 TIMEOUT→按失败处理）\n' "$gate_timeout" "$gate_elapsed" >> "$log" ;;
          137) verdict="TIMEOUT"
               printf '\n[teamsmith] 门禁在 %ss 未结束，TERM 被忽略后被 kill-after KILL（timeout 包装器退出码 137；实际用时 %ss；判定 TIMEOUT→按失败处理）\n' "$gate_timeout" "$gate_elapsed" >> "$log" ;;
        esac
      fi
      if [ "$verdict" = "FAIL" ]; then
        case "$gate_rc" in
          124) printf '\n[teamsmith] 门禁退出码 124，但实际只跑了 %ss（< 硬超时 %ss − %ss 宽限）：这是门禁**自己**返回 124，不是被 deadline 杀死的 → 判定 FAIL\n' "$gate_elapsed" "$gate_timeout" "$grace" >> "$log" ;;
          137) gate_signal="SIGKILL"
               printf '\n[teamsmith] 门禁退出码 137（SIGKILL），但实际只跑了 %ss（< 硬超时 %ss − %ss 宽限）：不是被 deadline 杀死的（外部 kill -9 / OOM 也会这样） → 判定 FAIL\n' "$gate_elapsed" "$gate_timeout" "$grace" >> "$log" ;;
          125) printf '\n[teamsmith] timeout 包装器自身失败（退出码 125，如不支持 --verbose）：门禁结果未知 → 判定 FAIL（实际用时 %ss）\n' "$gate_elapsed" >> "$log" ;;
          *)   if [ "$gate_rc" -gt 128 ]; then
                 gate_signal="$(team_review_signal_name "$(( gate_rc - 128 ))")"
                 printf '\n[teamsmith] 门禁被信号终止（退出码 %s，$gate_signal；实际用时 %ss）：不是超时 → 判定 FAIL\n' "$gate_rc" "$gate_elapsed" >> "$log"
               fi ;;
        esac
      fi
    fi
    gates_out="$(tail -25 "$log")"
    team_ok "门禁输出：${log#"$TEAM_MAIN_ROOT"/}（${verdict}，${gate_elapsed}s）"
  fi

  # F9 的后半：门禁自己会在 checkout 里造东西（未跟踪/被忽略的产物）——
  # 也要记进记录（前/后对比），这样“盖章的代码”和“门禁实际读到的树”之间的差别是可见的。
  local artifacts_after="" artifacts_new=""
  artifacts_after="$(team_review_artifacts "$revdir")"
  artifacts_new="$(comm -13 <(printf '%s\n' "$artifacts_before" | sort -u) <(printf '%s\n' "$artifacts_after" | sort -u) 2>/dev/null | sed '/^$/d' || true)"

  local diffstat commits changed
  diffstat="$(git -C "$revdir" diff --stat "$TEAM_PROTECTED_BRANCH...HEAD" 2>/dev/null | tail -1 || true)"
  commits="$(git -C "$revdir" log --oneline --no-decorate "$TEAM_PROTECTED_BRANCH..HEAD" 2>/dev/null | head -40 || true)"
  changed="$(git -C "$revdir" diff --name-status "$TEAM_PROTECTED_BRANCH...HEAD" 2>/dev/null | head -200 || true)"

  # 强复验（CEP 的实践）：要求证据表明「测试真的会失败」——对抗性验证包 + finding 测试翻转。
  # F13/F14（V4.0）：旧实现是纯关键词 grep（提到就“有”，按 M4.1 的英文写法却“缺”），
  # 现在由 team_strong_scan 按结构判定，并把「看了什么、命中哪一行、缺哪一条」写进复验记录。
  local strong_lines=""
  if [ "$strong" = "1" ]; then
    strong_lines="$(team_strong_scan "$revdir" "$id")"
    # 注意：别用 `printf ... | grep -q`（grep 提前退出 + pipefail ⇒ 误报“证据不完整”）
    case "$strong_lines" in
      *'| **判定** | **满足强复验** |'*) ;;
      *) team_warn "强复验证据不完整：看复验记录里的结构化清单（缺什么、在哪一行看到的）" ;;
    esac
  fi

  local report="$TEAM_DOCS_ABS/reviews/$id.md"
  # F8/F9/F12：抬头里把这些“本记录不是在干净树上跑的门禁结果”的事实一次性标清，
  # 读到记录/摘要的人不需要再去 checkout 现场猜。
  local head_flags=""
  [ "$dirty_override" = "1" ] && head_flags="$head_flags · checkout: dirty $dirty_n file(s) (override)"
  [ "$ignored_override" = "1" ] && head_flags="$head_flags · checkout: ignored $ignored_n artifact(s) (override)"
  [ "$unresolved_override" = "1" ] && head_flags="$head_flags · branch-unresolved (override)"
  [ "$gates_marker" = "none" ] && head_flags="$head_flags · gates: none"
  [ "$gates_marker" = "queuecap" ] && head_flags="$head_flags · gate queue cap exceeded（门禁没跑）"
  # 被信号终止（不是超时）：把信号名写进抬头，别拿「超时」顶替「被杀」（M6.5 / F15）
  [ -n "$gate_signal" ] && head_flags="$head_flags · gate killed: $gate_signal"
  {
    printf '# %s · PM 独立复验\n\n' "$id"
    printf '时间: %s · 分支: `%s` · HEAD: `%s` · 判定: **%s**%s\n\n' "$(team_timestamp)" "$branch" "${head:0:9}" "$verdict" "$head_flags"
    printf '## 复验方式\n\n'
    printf -- '- 独立 checkout：`%s`（PM 提供，skill 只读；不信任 agent 工作区）\n' "$revdir"
    printf -- '- 记录绑定：本判定只对上面的 HEAD `%s` 负责（分支再动一格，digest/status 会把它重新列为待复验）\n' "${head:0:9}"
    printf -- '- 门禁命令：`%s`（硬超时 %ss%s；TIMEOUT 需要「包装器 124/137 + 用时贴住 deadline」两条证据，按失败处理）\n' \
      "${TEAM_GATES:-<未配置>}" "${TEAM_REVIEW_TIMEOUT:-1800}" "${gate_elapsed:+，实际用时 ${gate_elapsed}s}"
    # G1（P26）：排队与运行分开记账 —— 硬超时只量「运行」，排队是 review 自己的有上限阶段。
    # `limit=… queued=… ran=…` 是刻意的机器可读形（场景要的就是两个区间分开、各不相同）。
    if [ "$gates_marker" != "none" ] && [ "$gates_marker" != "unconfigured" ]; then
      local q_acc r_acc
      case "$queued_elapsed" in ''|*[!0-9]*) q_acc="?" ;; *) q_acc="$queued_elapsed" ;; esac
      case "$gate_elapsed" in ''|*[!0-9]*) r_acc="?" ;; *) r_acc="$gate_elapsed" ;; esac
      case "$queue_state" in
        queued)  if [ "$gates_marker" = "queuecap" ]; then
                   printf -- '- 门禁锁：`%s`；排队等满上限 %ss 仍未拿到（持有者：%s）\n' "${used_lock:-$lock}" "$lock_cap" "${queue_holder:-未知}"
                 else
                   printf -- '- 门禁锁：`%s`；本次排队 %ss（上限 %ss，持有者：%s）\n' "${used_lock:-$lock}" "$q_acc" "$lock_cap" "${queue_holder:-未知}"
                 fi ;;
        held)    printf -- '- 门禁锁：`%s`；**已由祖先持有**（SMOKE_LOCK_WRAPPED=1）→ 本次不排队（queued=0s；避免与自己祖先死锁）\n' "${used_lock:-$lock}" ;;
        noqueue) printf -- '- 门禁锁：**排队未启用**（本机无 flock 或锁文件建不了）→ 并发两套门禁时可能互相干扰\n' ;;
        *)       ;;
      esac
      if [ "$queue_state" = "noqueue" ]; then
        printf -- '- 闸门计时：limit=%ss ran=%ss（无排队机制，`queued` 无意义）\n' "$gate_timeout" "$r_acc"
      elif [ "$gates_marker" = "queuecap" ]; then
        printf -- '- 闸门计时：limit=%ss queued=%ss（等满上限）ran=未跑（持锁者未释放）\n' "$gate_timeout" "$q_acc"
      elif [ "$queue_state" = "held" ]; then
        printf -- '- 闸门计时：limit=%ss queued=0s ran=%ss（硬超时只量 ran；锁已由祖先持有）\n' "$gate_timeout" "$r_acc"
      else
        printf -- '- 闸门计时：limit=%ss queued=%ss ran=%ss（硬超时只量 ran；排队超限不会得到 TIMEOUT）\n' \
          "$gate_timeout" "$q_acc" "$r_acc"
      fi
      if [ "$verdict" = "TIMEOUT" ]; then
        printf -- '- 超时证据：ran=%ss（包装器退出码 %s + 用时贴住 deadline %ss）\n' "$r_acc" "${gate_rc:-?}" "$gate_timeout"
      fi
    fi
    if [ -n "$gate_signal" ]; then
      printf -- '- 门禁被信号终止：**%s**（实际用时 %ss，**不是**被 deadline 杀死 → 判定 FAIL）\n' "$gate_signal" "$gate_elapsed"
    fi
    case "$gates_marker" in
      none)         printf -- '- 门禁：**none（--no-gates：没有跑过任何门禁）** —— 本记录不是 PASS 证据，digest 会继续把它列为待复验\n' ;;
      unconfigured) printf -- '- 门禁：**unconfigured（TEAM_GATES 未配置）** —— 没有自动判定，只能人工评审\n' ;;
      queuecap)     printf -- '- 门禁：**queuecap（排队超上限，门禁没有运行）** —— 持锁者：%s；上限 %ss。这不是对代码的判定\n' "${queue_holder:-未知}" "$lock_cap" ;;
      *)            printf -- '- 门禁：ran（判定 %s）\n' "$verdict" ;;
    esac
    printf -- '- 输出：`%s`\n' "${log#"$TEAM_MAIN_ROOT"/}"
    if [ "$dirty_override" = "1" ]; then
      printf -- '- **checkout dirty: %s files (override TEAM_REVIEW_ALLOW_DIRTY=1)** —— 门禁在**脏树**上跑的，本记录的判定不可复现\n' "$dirty_n"
      printf '```\n%s\n```\n' "$(git -C "$revdir" status --short | head -10)"
    else
      printf -- '- checkout clean：`git status --porcelain` 无输出（被验内容 == 提交内容）\n'
    fi
    if [ "${ignored_n:-0}" -gt 0 ] 2>/dev/null; then
      local ignored_suffix=""
      if [ "$ignored_override" = "1" ]; then ignored_suffix="（override TEAM_REVIEW_ALLOW_IGNORED=1：门禁可能读到了它们）"; fi
      printf -- '- **ignored artifacts: %s**（不在提交里；`status --porcelain` 看不见它们）%s\n' "$ignored_n" "$ignored_suffix"
      printf '```\n%s\n```\n' "$(printf '%s\n' "$ignored_list" | head -10)"
    else
      printf -- '- ignored artifacts: 0（`git status --porcelain --ignored=matching` 无输出）\n'
    fi
    if [ -n "$artifacts_new" ]; then
      printf -- '- 门禁跑完后新增的未跟踪/忽略产物：%s 个（门禁确实在 checkout 里写了东西；下次复验前先清场）\n' "$(printf '%s\n' "$artifacts_new" | grep -c . || true)"
      printf '```\n%s\n```\n' "$(printf '%s\n' "$artifacts_new" | head -10)"
    fi
    if [ "$unresolved_override" = "1" ]; then
      printf -- '- **分支未解析（--allow-unresolved-branch）**：`%s` 在主工作树里解析不到，checkout 一致性无法自动校验\n' "$branch"
    fi
    if team_find_report "$id" >/dev/null 2>&1; then
      printf -- '- agent 报告：`%s`\n' "$(team_find_report "$id")"
    else
      printf -- '- agent 报告：**缺失**（没有报告本身就是问题）\n'
    fi
    printf '\n'
    [ -n "$strong_lines" ] && printf '%s\n' "$strong_lines"
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
      FAIL) printf -- '- [ ] 门禁失败：退回 agent（`%s say <agent> "..."`）或 PM 自行修复\n' "$TEAM_CLI"
            if [ "$gates_marker" = "queuecap" ]; then
              printf -- '- [ ] **这不是对代码的判定**：门禁因为拿不到门禁锁（上限 %ss、持锁者 %s）**根本没有跑** → 等持锁者结束，或抬 `TEAM_SMOKE_LOCK_WAIT` 后重跑\n' "$lock_cap" "${queue_holder:-未知}"
            fi
            if [ -n "$gate_signal" ]; then
              printf -- '- [ ] 门禁是被信号 %s 终止的（**不是超时**——先看是不是 OOM/外部 kill，再查门禁自己）\n' "$gate_signal"
            fi ;;
      TIMEOUT) printf -- '- [ ] 门禁被硬超时终止（TIMEOUT→按失败处理）：查门禁自己为何挂死，或调 `TEAM_REVIEW_TIMEOUT` 后重跑\n' ;;
      *)    printf -- '- [ ] 人工评审（门禁未跑/未配置：这不等于通过，digest 会继续把它列为待复验）\n' ;;
    esac
  } > "$report"
  team_scan_invalidate review   # M50：同进程里「写完再读」必须读到新记录
  [ -n "$queue_marker" ] && rm -f "$queue_marker" 2>/dev/null
  team_ok "复验记录：${report#"$TEAM_MAIN_ROOT"/}（$verdict）"

  case "$verdict" in FAIL|TIMEOUT) return 1 ;; esac
  return 0
}

team_cmd_close() {
  team_require_docs
  local id="" status="done" keep_window=0 force=0 reason=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --status) status="${2:?}"; shift 2 ;;
      --keep-window) keep_window=1; shift ;;
      --force) force=1; shift ;;
      --reason) reason="${2:?--reason 需要文本}"; shift 2 ;;
      -*) team_usage_die "close: 未知参数 $1" ;;
      *) id="$1"; shift ;;
    esac
  done
  [ -n "$id" ] || team_usage_die "close <ID> [--status done|blocked|dropped] [--keep-window] [--force --reason <文本>]"
  case "$status" in
    todo|wip|review|done|blocked|dropped) ;;
    *) team_die "状态非法：$status（todo|wip|review|done|blocked|dropped）" ;;
  esac

  # ① 「有东西可关吗」：没有的话就不是成功，而是打错字（F29 的同一个原则：no-op 不能看起来像写入）
  local a w b known=0 ids
  for a in $(team_agents); do
    [ "$(team_state_get "$a" task '')" = "$id" ] && known=1
  done
  team_board_has "$id" && known=1
  if [ "$known" != "1" ]; then
    team_err "close $id：BOARD 里没有这一行，也没有 agent 在跑这个任务（没有可关闭的东西）"
    ids="$(team_board_ids | tr '\n' ' ')"
    [ -n "${ids// /}" ] && team_err "  现有 id：${ids% }"
    team_die "  → 新增一行：$TEAM_CLI board add $id <标题>，或先用 $TEAM_CLI task 建任务书"
  fi

  # ② done 的准入证据（F1）：**先核对、后动手**；被拒时窗口与状态原样不动
  local done_ev="" done_label=""
  if [ "$force" = "1" ] && [ "$status" != "done" ]; then
    team_warn "--force/--reason 只对 --status done 有意义（当前 status=$status）：已忽略"
  fi
  if [ "$status" = "done" ]; then
    done_label="$TEAM_CLI close $id --status done"
    if [ "$force" = "1" ]; then
      [ -n "$(team_trim "$reason")" ] || team_die "--force 需要 --reason \"为什么\"：覆盖会记进 $TEAM_DOCS_DIR/reviews/$id-done.md"
      done_ev="$(TEAM_BOARD_DONE_FORCE=1 TEAM_BOARD_DONE_REASON="$reason" team_done_gate "$id" "$done_label")" || return 1
    else
      done_ev="$(team_done_gate "$id" "$done_label")" || return 1
    fi
    team_dim "  done 证据：$(printf '%s' "$done_ev" | head -1)"
  fi

  for a in $(team_agents); do
    [ "$(team_state_get "$a" task '')" = "$id" ] || continue
    w="$(team_state_get "$a" window "$a")"
    if [ "$keep_window" != "1" ] && team_tmux_has_window "$TEAM_SESSION" "$w"; then
      tmux kill-window -t "$TEAM_SESSION:$w" 2>/dev/null && team_ok "kill window $TEAM_SESSION:$w"
    fi
    team_state_set "$a" task ""
    # 分支归 PM：这里只说清楚「现在在哪、复位命令是什么」，不替 PM 切分支（见 openspec board-and-status）
    b="$(git -C "$(team_agent_worktree "$a")" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    case "$b" in
      ""|HEAD|"$TEAM_PROTECTED_BRANCH") ;;
      *)
        if team_branch_mode_is_task && [ "${TEAM_TASK_BRANCH_RESET:-1}" = "1" ]; then
          team_dim "  $a 仍在 $b 上 → 复位（git 归 PM：下面这条由你跑，CLI 不碰 git）："
          team_dim "    git -C $(team_agent_worktree "$a") switch --detach $TEAM_PROTECTED_BRANCH"
        else
          team_dim "  $a 仍在 $b 上（TEAM_TASK_BRANCH_RESET=0：CLI 不复位、也不提复位命令）"
        fi ;;
    esac
  done
  if team_board_write "$id" "$status"; then
    [ -n "$done_ev" ] && team_done_record "$id" "$done_label" "$done_ev"
  else
    team_warn "BOARD 未更新（$id 不在表里？）"
  fi
  team_ok "closed $id（status=$status）"
  if [ -f "$TEAM_DOCS_ABS/reviews/$id.md" ]; then
    team_dim "  复验记录 $TEAM_DOCS_DIR/reviews/$id.md 保留；agent worktree 保留（复用）"
  else
    team_dim "  没有复验记录（$TEAM_DOCS_DIR/reviews/$id.md 不存在）；agent worktree 保留（复用）"
  fi
}
