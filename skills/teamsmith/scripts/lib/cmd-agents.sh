#!/usr/bin/env bash
# teamsmith · agent 生命周期：add-agent / dispatch / say / notify / teardown

team_worktree_add() { # <agent> [--create] [--no-install]
  local agent="$1"; shift || true
  local noinstall=0 do_create="${TEAM_CREATE_WORKTREE:-0}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --create) do_create=1; shift ;;
      --print-only|--print) do_create=0; shift ;;
      --no-install) noinstall=1; shift ;;
      *) team_usage_die "add-agent: 未知参数 $1" ;;
    esac
  done
  team_require_agent "$agent"
  local wt branch; wt="$(team_agent_worktree "$agent")"; branch="$(team_agent_branch "$agent")"

  # 幂等的 git worktree add —— 由 PM 执行（skill 不碰 git）；--create 才代建
  if [ "$do_create" != "1" ]; then
    team_dim "  需要 PM 执行（本命令不代做 git）："
    if [ -d "$wt" ]; then
      printf '    （已存在，无需创建）%s\n' "$wt"
    else
      printf '    git -C %s worktree add -b %s %s %s\n' "$TEAM_MAIN_ROOT" "$branch" "$wt" "$TEAM_PROTECTED_BRANCH"
    fi
    team_state_set "$agent" model "$(team_agent_model "$agent")"
    team_state_set "$agent" model_src config
    team_state_set "$agent" window "$agent"
    team_state_set "$agent" worktree "$wt"
    return 0
  fi
  mkdir -p "$(dirname "$wt")"
  if [ -d "$wt" ]; then
    team_ok "worktree 已存在：$wt"
  elif team_branch_mode_is_task; then
    # task 模式：worktree 先 detached 在保护分支上（`git switch -c task/<ID>-…` 由 dispatch 做）；
    # 不能直接 checkout 保护分支 —— 主工作树已经占着它。
    team_git_main worktree add --detach "$wt" "$TEAM_PROTECTED_BRANCH" >/dev/null
    team_ok "worktree $wt ← detached@$TEAM_PROTECTED_BRANCH（任务分支由 dispatch 建）"
  else
    if team_git_main show-ref --verify -q "refs/heads/$branch"; then
      team_git_main worktree add "$wt" "$branch" >/dev/null
    else
      team_git_main worktree add -b "$branch" "$wt" "$TEAM_PROTECTED_BRANCH" >/dev/null
    fi
    team_ok "worktree $wt ← 分支 $branch"
  fi
  team_scan_invalidate git   # M50：工作树集变了，同进程后续读必须重列

  if [ "$noinstall" != "1" ] && [ -n "$TEAM_INSTALL_CMD" ]; then
    team_info "install: $TEAM_INSTALL_CMD（在 $wt）"
    ( cd "$wt" && eval "$TEAM_INSTALL_CMD" ) || team_warn "install 失败，先手动装依赖再派单"
  fi

  team_state_set "$agent" model "$(team_agent_model "$agent")"
  team_state_set "$agent" model_src config
  team_state_set "$agent" window "$agent"
  team_state_set "$agent" worktree "$wt"
  return 0
}

team_pi_args() { # <model> → 打印已转义的 pi 参数
  local model="$1" provider piargs=()
  provider="${model%%/*}"
  piargs=(--provider "$provider" --model "${model#*/}")
  piargs+=(-e "$TEAM_SKILL_DIR/extension/team-notify.ts")
  # M27：团队后台车道与 notify 并列注入（worker 的长门禁/长构建用它，收割纪律写在提示词里）
  piargs+=(-e "$TEAM_SKILL_DIR/extension/team-bg.ts")
  # M30：投递换道 —— 收件箱监视唤醒（worker 也收 `team say`；装了它就不再有任何输入框粘贴）
  piargs+=(-e "$TEAM_SKILL_DIR/extension/team-inbox-watch.ts")
  [ -d "$TEAM_SKILL_DIR" ] && piargs+=(--skill "$TEAM_SKILL_DIR")
  if [ -n "$TEAM_EXTRA_PI_ARGS" ]; then
    # 允许项目追加参数（空格分隔，不支持带空格的值）
    # shellcheck disable=SC2206
    piargs+=($TEAM_EXTRA_PI_ARGS)
  fi
  printf '%q ' "${piargs[@]}"
}

# 派单提示词：把 CEP 的「不半途停、小步提交、必写报告、被阻塞就 notify」固化成模板。
# P140：第 7/8 参可给本次**解析出的任务分支**与它的来源（dispatch 传入；其它调用方留空则不提）。
team_build_prompt() { # <agent> <ID> <taskfile-abs> <worktree> <model> [<session_id>] [<branch>] [<branch-source>]
  local agent="$1" id="$2" taskfile="$3" wt="$4" model="$5" sid="${6:-$TEAM_SESSION-$1}" br="${7:-}" br_src="${8:-}"
  local issue="" cli="$TEAM_SKILL_DIR/scripts/team" rel abs_docs rel_report rel_note notify_block="" bg_block=""
  case "$taskfile" in
    "$TEAM_MAIN_ROOT"/*) rel="${taskfile#"$TEAM_MAIN_ROOT"/}" ;;
    *) rel="" ;;
  esac
  # 只有真的在项目里才敢叫它 repo-relative（M6.3 F15：绝对路径被标成 repo-relative，
  # 而同一份提示词又命令 worker 只在本项目里干活）。
  if [ -n "$rel" ]; then rel_note=" (same file, repo-relative path: \`$rel\`)"
  else rel_note=" (absolute path; it is outside the project main worktree)"; fi
  abs_docs="$TEAM_DOCS_ABS"
  rel_report="$TEAM_DOCS_DIR/reports/$id-$agent.md"
  grep -qE '^[[:space:]]*issue:' "$taskfile" 2>/dev/null && \
    issue="$(grep -E '^[[:space:]]*issue:' "$taskfile" | head -1 | grep -oE '[0-9]+' | head -1 || true)"

  # 交付步骤与 forge 无关：skill 不假设任何 forge CLI（gh/glab/tea/curl 都行，由 PM 决定）
  local pr_step
  case "$TEAM_VCS" in
    local|"") pr_step="本仓库是 local 模式（没有远端）：**不用 push**，把分支留在本地即可，PM 复验后本地合并" ;;
    *)        pr_step="交付方式由 PM 决定：把分支 push 到你们的远端（如有），开 PR/MR 与否听 PM 安排
     （skill 不代做、也不假设 gh/glab；需要你手动调 API 时按 PM 给的方式做，token 不要读进上下文）" ;;
  esac

  # 通知段（F1/F7/F8）：worker 的摘要是**数据**，永远走文件通道 —— 提示词里不含任何 worker 文本，
  # 而 worker 要跑的命令是 teamsmith 渲染好的固定行（无需替换/引号/加参数）。
  # 「不是 Pi、没有自动通知」只属于自定义 adapter（F7：内置 Pi 路径下这句话就是诳 worker）。
  # 模板不可用（坏占位符/多行/纯空白/首词不可执行）时整段换成「写进报告」，不给半截命令（F8）。
  # 只有「启动命令也是自定义 adapter」时才需要 worker 手动通知：内置 Pi 有自己的扩展，
  # 把额外命令塞给它只会诱导重复通知（F7 / V3.0 d6）；那种配置由 dispatch/doctor 警告「没生效」。
  if [ -n "${TEAM_AGENT_NOTIFY_CMD:-}" ] && [ -n "$(team_trim "${TEAM_AGENT_CMD:-}")" ]; then
    local notify_issues="" sfile why ncmd
    notify_issues="$(team_agent_notify_issues)"
    if [ -n "$notify_issues" ]; then
      notify_block="$(printf '\n**Notify the PM when your turn ends**: the notify configuration of this project is unusable (%s), so there is\nnothing for you to run. Put your one-line summary (what you delivered / status / next step) into the report\n`%s` instead -- the PM reads reports.\n' \
        "$(printf '%s' "$notify_issues" | tr '\n' '; ')" "$rel_report")"
    else
      sfile="$(team_agent_summary_file "$agent" "$id")"
      if [ -n "${TEAM_AGENT_CMD:-}" ]; then
        why="This project runs a custom agent CLI, not Pi, so there is no automatic notification."
      else
        why="Your CLI is the built-in Pi, whose notify extension already tells the PM when your turn ends; run the command below only if the PM asked you to."
      fi
      ncmd="$(team_agent_notify_cmd "$agent" "$sid" "$wt" "$sfile")"
      notify_block="$(printf '\n**Notify the PM when your turn ends.** %s Write your one-line summary (what you delivered /\nstatus / next step) into this file with whatever file-writing you normally do (create or overwrite it):\n\n    %s\n\nthen run exactly this command, with no substitutions, no extra arguments and no quotes:\n\n    %s\n' \
        "$why" "$sfile" "$ncmd")"
    fi
  fi

  # M27 · 后台车道纪律：只在「这个 harness 真的会拿到 team-bg 扩展」时说 ——
  # 内置 Pi（TEAM_AGENT_CMD 空）由 teamsmith 挂 -e；自定义模板写了 {bg_ext} 的算作者已经挂上。
  # 其它 adapter 不提：工具不存在，教了只会让 worker 白找。
  case "${TEAM_AGENT_CMD:-}" in
    ''|*'{bg_ext}'*)
      bg_block="$(printf '\n**Long jobs (a gate, a build)**: start them with `team_bg_run` (it returns a job id immediately and keeps\nworking while you go on), then harvest with `team_bg_wait <id>` (the result comes back inline). **Harvest every job\nbefore your turn ends** -- an unharvested job wakes you once when it finishes, and that costs a turn.\n')" ;;
  esac

  cat <<PROMPT
You are agent:$agent for the **$TEAM_PROJECT** project, dispatched by the PM through teamsmith. Your worktree is
\`$wt\`; run every command there.${br:+
Your task branch is \`$br\` (source: $br_src) -- stay on it, do not switch branches.} **Do not** touch the main worktree ($TEAM_MAIN_ROOT) and **do not** switch to main or
anyone else's branch.

Read these first, in order:
1. \`AGENTS.md\` (contains the teamsmith team protocol section)
2. Your thread \`$abs_docs/threads/$agent.md\` (the PM may have added instructions before you started)
3. The task brief \`$taskfile\`$rel_note -- the single source of scope and acceptance commands

Scope discipline: do only what the brief says, and only change directories that OWNERSHIP assigns to you.
For cross-directory work, do not do it yourself: write \`BLOCKED:\` in your report naming who should change what,
then end the turn.

Red lines: never push $TEAM_PROTECTED_BRANCH, never force-push, never merge PR/MRs, never rebase or delete other
branches, never change repository settings. Never write tokens/secrets into code, logs or commit messages; never
read credential files (such as ~/.pi/agent/auth.json).

**Cross-project boundary (never act outside this project)**: work only inside $TEAM_MAIN_ROOT, your own worktree,
and this team's tmux session ($TEAM_SESSION). Do not message windows in other projects or sessions, do not read or
write other projects' repositories or session files, and do not change or merge other projects' code. If you need
another project's help (cross-repo dependency, shared library change), write \`BLOCKED:\` in your report naming who
needs to do what -- **cross-project communication is the PM's job via \`$cli meeting\` (peer exchange: interfaces,
advice, problem reports); workers do not attend**. Only decisions that need the user's call go through the user.

**Never stop mid-task to ask for confirmation**: end the turn in exactly two situations --
(a) every acceptance command in the brief has been run + the report is written + the branch is pushed + the PR/MR is
    open (or, in local mode, the branch state is settled);
(b) you are hard-blocked (missing dependency, missing permission, someone else's bug): notify the PM with
    \`$cli notify $agent "<one line>"\`, state \`BLOCKED:\` clearly in the report, then end the turn.
    **Never work around a boundary on your own.**

Delivery process:
1. Actually run the acceptance commands from the brief. **Never claim something passed without running it** (the PM
   re-verifies independently; a false report fails the task).
2. Commit every verifiable small step (\`git commit\`, Conventional Commits + task ID + trailer \`Agent: $agent\`${issue:+ + \`Refs #$issue\`}); never one big dump at the end.
3. Write the report \`$rel_report\` and commit it on your branch (format: the AGENTS.md report template; include the
   real commands and their output tails).
   For **defect-fix** tasks the report must contain **flip evidence**: red before -> green after, or
   "break the implementation -> the guard test must fail -> restore it"
   (the PM checks this section with \`$cli review $id --strong\` and will send it back if missing).
4. \`git push -u $TEAM_REMOTE HEAD\`.
5. $pr_step.

Task: **$id**${issue:+ (issue #$issue)}. The brief \`$taskfile\` is the PM's read-only file -- do not modify it.${bg_block}${notify_block}
If this is a resumed run: start with \`git status\` / \`git log --oneline -5\` to see how far you got, and continue
from that point instead of starting over.
PROMPT
}

team_cmd_add_agent() {
  local agent="" extra=()
  local register=0 has_model=0 model="" fp=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --register) register=1; shift ;;
      --model) model="${2:?--model 需要 <provider/model> 或 -}"; has_model=1; shift 2 ;;
      --model=*) model="${1#*=}"; has_model=1; shift ;;
      --fingerprint) fp="${2:?--fingerprint 需要 sha256}"; shift 2 ;;
      --fingerprint=*) fp="${1#*=}"; shift ;;
      --no-install) extra+=(--no-install); shift ;;
      --create) extra+=(--create); shift ;;          # 明确要求代建 worktree（默认只打印 git 命令）
      --print-only|--print) extra+=(--print-only); shift ;;
      -*) team_usage_die "add-agent: 未知参数 $1" ;;
      *) [ -z "$agent" ] || team_usage_die "add-agent: 多余参数 $1"
         agent="$1"; shift ;;
    esac
  done
  [ -n "$agent" ] || team_usage_die "add-agent <agent> [--register] [--model <provider/model>|-] [--fingerprint <sha256>] [--create] [--no-install] [--print]"

  # ① 模型形状先判：可预测的错误写不进任何东西（P99/D2 的写序）
  if [ "$has_model" = "1" ] && [ "$model" != "-" ] && ! team_config_model_shape_ok "$model"; then
    team_err "add-agent --model：模型必须是 provider/model 形状（$(team_config_model_violation "$model")）：$model"
    return "$TEAM_CONFIG_EXIT_INVALID"
  fi

  # ①′ 席位名是一个 token（P105/F1）：名册值规则判的是**结果值**，而 `api 1` 加进去会变成两个各自
  # 合法的 token（value rule 不会响）—— 必须在任何写入之前先拒。写入器里有同一份守卫（team_config_
  # seat_violation）；这里提前一层是为了给出两条真能用的路线而不是一个干巴巴的 4。
  local seat_why
  if ! seat_why="$(team_config_seat_violation "$agent")"; then
    team_err "add-agent：$seat_why"
    team_dim "  席位名要能当工作树目录名/窗口名/state 文件名，接受形状 [A-Za-z0-9][A-Za-z0-9._-]*（一个 token）。两条真能用的路线：" >&2
    team_dim "    · 换成形状合法的名字再跑：$TEAM_CLI add-agent <名字> --register" >&2
    team_dim "    · 或手改 $TEAM_MAIN_ROOT/.pi/team/config.sh 里的 TEAM_AGENTS（名字同样要匹配这个形状）" >&2
    return "$TEAM_CONFIG_EXIT_INVALID"
  fi

  # ② 名册：--register 走契约的审计写入器（唯一授权入口）；没有旗标的未知席位 → exit 5 +
  # 两条真能用的路线，且不碰窗口/worktree/state/契约（P99/R2）。
  if [ "$register" = "1" ]; then
    local rrc=0
    team_config_write_roster add "$agent" "$fp" 0 || rrc=$?
    [ "$rrc" -eq 0 ] || return "$rrc"
  elif ! team_agent_known "$agent"; then
    team_err "未知 agent：$agent（名册：$(team_config_roster_text)）"
    team_dim "  名册只由显式入口改，两条真能用的路线：" >&2
    team_dim "    · $TEAM_CLI add-agent $agent --register（走契约的审计写入器）" >&2
    team_dim "    · 或手改 $TEAM_MAIN_ROOT/.pi/team/config.sh 里的 TEAM_AGENTS" >&2
    team_dim "  本次什么都没做：没有开窗、没有工作树、没有 state、契约未动" >&2
    return "$TEAM_CONFIG_EXIT_REFUSE"
  fi

  # ③ 席位模型（--model）：同一个写入器 + 同一个 pairlist 序列化器（D4）
  if [ "$has_model" = "1" ]; then
    local mrc=0
    team_cmd_config_set_agent_model "$agent" "$model" || mrc=$?
    [ "$mrc" -eq 0 ] || return "$mrc"
  fi

  # ④ 既有工作树步骤
  if [ "${#extra[@]}" -gt 0 ]; then team_worktree_add "$agent" "${extra[@]}"; else team_worktree_add "$agent"; fi
}

# 这个分支属不属于这个任务：
#   task 模式  → task/<ID>-<任意 slug>（slug 由标题生成、可能改过，所以不要求逐字符相等）
#   agent 模式 → agent/<name>（长期分支，就是 team_branch_for_agent 算出来的那个）
# 注意：只接受**同一个 ID**；task/P2-smoke 永远不会被当成 P1 的分支。
team_branch_is_for_task() { # <branch> <agent> <ID>
  local br="$1" agent="$2" id="$3" want
  [ -n "$br" ] || return 1
  want="$(team_branch_for_agent "$agent" "$id")"
  [ "$br" = "$want" ] && return 0
  if team_branch_mode_is_task; then
    case "$br" in "task/$id-"*) return 0 ;; esac
  fi
  return 1
}

# P140（dispatch-friction · R1）：本次派单期望分支的**一条声明**与它的来源。
# 解析顺序（design D2）：--branch <name>（PM 显式声明，最高优先）＞ 任务书 `branch:` 行 ＞ 由标题推导。
# 推导本身只有一份（team_task_branch_for_id / team_agent_branch），不与 `team task` 各算各的。
# → 0 = stdout `<name>\x1f<来源>`；1 = stdout 一行拒绝原因（名字不属于本任务）。
# 来源文本：`--branch` / `任务书 branch: 行` / `由标题 "<title>" 推导` / `agent 模式：agent/<agent>`。
team_dispatch_branch_decl() { # <agent> <ID> <任务书> <--branch 值>
  local agent="$1" id="$2" brief="$3" flag="${4:-}" name="" src="" raw="" title=""
  if [ -n "$flag" ]; then
    name="$flag"; src="--branch"
  else
    raw="$(team_brief_field_raw "$brief" branch | head -1)"
    if [ -n "$raw" ]; then
      name="$raw"; src="任务书 branch: 行"
    elif team_branch_mode_is_task; then
      title="$(team_task_title "$id" 2>/dev/null || true)"
      name="$(team_task_branch_for_id "$id")"
      src="由标题 \"$title\" 推导"
    else
      name="$(team_agent_branch "$agent")"; src="agent 模式：agent/<agent>"
    fi
  fi
  if ! team_branch_is_for_task "$name" "$agent" "$id"; then
    printf '%s 不属于本任务（%s）\n' "$name" "$id"
    return 1
  fi
  printf '%s\x1f%s\n' "$name" "$src"
  return 0
}

# ---------------------------------------------------------------- P140 · 工作树判定（finding 产出器）
# 两个判定分开（dispatch-friction · R4/R5）：脏工作树、分支身份各自是一个阻塞项；
# 工作树不存在时 driver 不调这两个（前提缺失 → 说明项，不冒充“查过了”）。
# 脏工作树：同一任务的断点续跑允许脏；换任务先收尾（原文案与字段不变，只多了 修法： 行）。
team_dispatch_judge_worktree_dirty() { # <agent> <ID> <wt>
  local agent="$1" id="$2" wt="$3" dirty prev_task dl
  dirty="$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  [ "${dirty:-0}" -gt 0 ] 2>/dev/null || return 0
  prev_task="$(team_state_get "$agent" task '')"
  if [ "$prev_task" = "$id" ]; then
    # 同一个任务的「断点续跑」允许脏工作区：那些改动正是它没提交完的活。
    team_df_dim "  断点续跑：$wt 有 $dirty 个未提交改动，属于本任务（$id），允许继续"
    return 0
  fi
  team_df_err "$wt 有 $dirty 个未提交改动（属于上一个任务 ${prev_task:-?}）：先收尾（提交或丢弃），再派新任务"
  dl="$(git -C "$wt" status --short 2>/dev/null | head -8 || true)"
  [ -n "$dl" ] && team_df_lines_raw_err "$dl"
  team_df_dim "  想直接续跑同一个任务：$TEAM_CLI resume --agent $agent（或 dispatch 同一个 ID）"
  team_df_dim "  （git 归 PM：skill 不替你 stash/commit）"
  team_df_dim "$(printf '  修法：git -C %q stash push -u -m %q' "$wt" "收尾：上一个任务 ${prev_task:-?} 的未提交改动")"
  return 1
}

# 分支身份（M6.3 F16 + P140）：
#   · 保护分支 / detached HEAD：先切到任务分支；
#   · `--branch` 的显式声明：工作树必须正好停在它上面（同任务的另一个 slug 也不静默替换）；
#   · 任务书 branch: 行 / 标题推导：工作树停在**本任务**的任意分支都放行（slug 是显示细节），
#     两个名字都打印；别的任务的分支照旧拒绝。
# 成功时把实际检查到的分支写进 TEAM_CHECKED_BRANCH（state/审核的目标）。
team_dispatch_judge_worktree_branch() { # <agent> <ID> <wt> <声明分支> <来源>
  local agent="$1" id="$2" wt="$3" want="$4" decl_src="$5" cur
  cur="$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
  case "$cur" in
    "$TEAM_PROTECTED_BRANCH")
      team_df_warn "$agent 的工作树还在 $TEAM_PROTECTED_BRANCH 上：PM 该先建分支再派单"
      team_df_dim "$(printf '  修法：git -C %q switch -c %q %q' "$wt" "$want" "$TEAM_PROTECTED_BRANCH")"
      return 1 ;;
    HEAD)
      if [ -n "$want" ]; then
        team_df_warn "$agent 的工作树是 detached HEAD：先切到任务分支"
        team_df_dim "$(printf '  修法：git -C %q switch -c %q %q' "$wt" "$want" "$TEAM_PROTECTED_BRANCH")"
        return 1
      fi ;;
  esac
  if [ -n "$want" ] && [ "$cur" != "$want" ]; then
    if [ "$decl_src" = "--branch" ]; then
      # P140：显式声明赢 —— 同任务的另一个 slug 也不静默替换。
      team_df_err "$wt 不在 --branch 声明的分支上："
      team_df_err "  现在的分支：$cur ｜ --branch 声明：$want"
      if git -C "$wt" show-ref --verify --quiet "refs/heads/$want"; then
        team_df_dim "$(printf '  修法：git -C %q switch %q' "$wt" "$want")"
      else
        team_df_dim "$(printf '  修法：git -C %q switch -c %q %q' "$wt" "$want" "$TEAM_PROTECTED_BRANCH")"
        team_df_dim "       （替代方案：让 --branch 指向一条已存在的本任务分支；显式声明赢）"
      fi
      return 1
    fi
    if team_branch_is_for_task "$cur" "$agent" "$id"; then
      # P140：同一个任务的续跑 —— slug 可能因为标题改过而不一致（实测摩擦：task/P134-p134 vs 推导名）；
      # 分支确实属于本任务（同一 ID）就放行，两个名字都打印出来。
      team_df_dim "  续跑：$wt 的分支 $cur 属于本任务（$id；解析名 $want），继续"
      if [ -n "$want" ] && git -C "$wt" show-ref --verify --quiet "refs/heads/$want"; then
        team_df_dim "$(printf '  （想让工作树也叫解析名：git -C %q switch %q）' "$wt" "$want")"
      fi
    else
      team_df_err "$wt 停在不属于本任务（$id）的分支上："
      team_df_err "  现在的分支：$cur ｜ 本任务要的分支：$want"
      if git -C "$wt" show-ref --verify --quiet "refs/heads/$want"; then
        team_df_dim "$(printf '  修法：git -C %q switch %q' "$wt" "$want")"
      else
        team_df_dim "$(printf '  修法：git -C %q switch -c %q %q' "$wt" "$want" "$TEAM_PROTECTED_BRANCH")"
      fi
      team_df_dim "  （拒绝的理由：复验/交付记录会以工作树的分支为证据，不能张冠李戴）"
      return 1
    fi
  fi
  TEAM_CHECKED_BRANCH="$cur"
  return 0
}

# 工作树存在（不存在 = 阻塞项，修法是 PM 该跑的那条 git 命令）。
team_dispatch_judge_worktree_present() { # <agent> <声明分支>
  local agent="$1" decl="$2" wt
  wt="$(team_agent_worktree "$agent")"
  [ -d "$wt" ] && return 0
  team_df_err "worktree 不存在：$wt（skill 不代做 git）"
  team_df_dim "$(printf '  修法：git -C %q worktree add -b %q %q %q' "$TEAM_MAIN_ROOT" "$decl" "$wt" "$TEAM_PROTECTED_BRANCH")"
  return 1
}

# ---------------------------------------------------------------- 派单前的会话规模守卫（M4.3 A）
# 复用大会话 + 小窗口模型 = 必然 wedge（现场见 DECISIONS D9 事件 A：361k tok 的会话配 272k 窗口的模型
# → 立刻 Context full / 连接错误循环，而 roster 仍显示「pi 在跑」）。
# 默认**拒绝**并给出 --fresh；确实要复用（例如换成窗口更大的模型）时用 --allow-overflow 显式放行。
# 口径写入消息：token ≈ 会话 JSONL 字节 / 4（粗糙）；窗口解析不到时明说用的是保守阈值。
team_guard_resume_session() { # <agent> <model> <sid> <worktree> <fresh> <allow-overflow> [<ID> <task-file>]
  local agent="$1" model="$2" sid="$3" wt="$4" fresh="${5:-0}" allow="${6:-0}" id="${7:-}" taskfile="${8:-}"
  [ "$fresh" = "1" ] && return 0                # --fresh = 新会话，历史留在旧文件里
  local f b t w limit note mb
  f="$(team_session_file "$sid" "$wt" 2>/dev/null || true)"
  [ -n "$f" ] || return 0                         # 没有历史会话：没什么可复用的
  b="$(team_file_bytes "$f")"
  t="$(team_session_tokens_est "$b")"
  [ "$t" -gt 0 ] || return 0
  mb="$(awk -v b="$b" 'BEGIN{printf "%.1f", b/1048576}')"
  w="$(team_model_window "$model")"
  if [ -n "$w" ]; then
    limit="$w"; note="模型 $model 的窗口 $w tok"
  else
    limit="${TEAM_SESSION_WARN_TOKENS:-200000}"
    case "$limit" in ''|*[!0-9]*) limit=200000 ;; esac   # 配置写成垃圾值时退回默认，而不是静默不守
    note="解析不到 $model 的窗口（Pi 的模型目录里没有它）→ 保守阈值 $limit tok"
  fi
  [ "$t" -gt "$limit" ] || return 0
  local size="~$(team_tokens_human "$t") tok（估算：JSONL ${mb}MB ÷ 4，粗糙）"
  if [ "$allow" = "1" ]; then
    team_warn "你显式放行了偏大的会话：$size > $note"
    team_dim "  若它 wedge（Context full / 连接错误循环）：杀掉窗口后用 --fresh 重派（roster 仍会显示「pi 在跑」）"
    return 0
  fi
  team_err "拒绝复用这个会话：$size > $note"
  team_dim "  会话文件：$f" >&2
  team_dim "  复用它极可能直接 Context full / 连接错误循环，而 roster 还会显示「pi 在跑」" >&2
  team_dim "  两条出路（P140：带具体 ID/任务书的可粘命令）" >&2
  if [ -n "$id" ] && [ -n "$taskfile" ]; then
    team_dim "    修法：$TEAM_CLI dispatch $agent $id $taskfile --fresh" >&2
    team_dim "          （换新会话，推荐；旧历史仍在原文件里）" >&2
    team_dim "    修法：$TEAM_CLI dispatch $agent $id $taskfile --allow-overflow" >&2
    team_dim "          （确认要复用；显式放行会醒目警告）" >&2
  else
    # 没有具体 ID/任务书时给的是**模板**，不是可粘路线 —— 因此不带 `修法：` 标记（不许把占位符
    # 冒充成一条能跑的命令）。
    team_dim "    · 换新会话（推荐；旧历史仍在原文件里）：$TEAM_CLI dispatch <agent> <ID> <task-file> --fresh" >&2
    team_dim "    · 确认要复用（例如换成窗口更大的模型）：$TEAM_CLI dispatch <agent> <ID> <task-file> --allow-overflow" >&2
  fi
  return 1
}

# ---------------------------------------------------------------- 派单启动校验（M4.3 B）
# 启动证据：窗口里的 harness 在**跑 agent 之前**把 "<nonce> <pane-shell-pid>" 写进这个文件。
# 为什么需要：旧实现只要 `tmux new-window` 返回 0 就报成功 —— 命令要是被一个卡死的进程的输入缓冲
# 吃掉（现场 D9 事件 B：新 session id 从未出现、什么都没跑），派单照样「成功」。
# nonce 只在**我们的 harness 真的在窗口里执行了**时才出现：换窗口、打字进旧进程、别的进程占着
# 窗口都不会产生它（F30 的 spawn 证据同源）。
team_dispatch_spawn_file() { printf '%s\n' "$TEAM_STATE_DIR/dispatch-$1.spawn"; }

# 退出证据：窗口 harness 在 agent 进程返回后立刻把 "<本轮 nonce> <退出码>" 写进这个文件。
# 为什么需要它（M7.5 的 flake）：旧实现是「睡 ALIVE_SEC 后**采样一次** team_pane_busy」——
# 那是一个瞬时判断，而 agent 退出后窗口要经过一段**非确定性的 shell 回退过程**
# （本容器实测：bash -lc → 交互 bash 读 ~/.bashrc → `exec /usr/bin/zsh -l` → 登录 zsh 启动
#  churn：conda hook / 前台子进程换进程组），期间 pane_current_command 与前台进程组来回变；
# 采样点落进那一段就会把「已经退出」误报成「还在跑」→ 通知整条消失（同一提交 904/2 与 906/0
# 交替出现）。退出码由 agent 的**父 shell** 亲手写下，是事件而不是采样：与 shell 启动快慢无关。
team_dispatch_exit_file() { printf '%s\n' "$TEAM_STATE_DIR/dispatch-$1.exit"; }

# 等退出证据。成功 → stdout 打印退出码；窗口里还没退出（或本轮没写）→ 非 0。
team_wait_agent_exit() { # <agent> <nonce> [秒]
  local agent="$1" nonce="$2" wait="${3:-${TEAM_DISPATCH_ALIVE_SEC:-1}}" steps got code i=0
  case "$wait" in ''|*[!0-9]*) wait=1 ;; esac
  [ "$wait" -gt 0 ] || return 1
  steps=$((wait * 20)); [ "$steps" -gt 0 ] || steps=20
  while [ "$i" -lt "$steps" ]; do
    [ "$i" -gt 0 ] && sleep 0.05
    got="$(head -1 "$(team_dispatch_exit_file "$agent")" 2>/dev/null || true)"
    case "$got" in
      "$nonce "*) code="${got#* }"
        case "$code" in ''|*[!0-9]*) : ;; *) printf '%s\n' "$code"; return 0 ;; esac ;;
    esac
    i=$((i + 1))
  done
  return 1
}

# 等启动证据。成功 → stdout 打印 pane shell 的 pid；失败 → 非 0。
team_wait_launch_proof() { # <agent> <nonce> [秒]
  local agent="$1" nonce="$2" wait="${3:-${TEAM_DISPATCH_VERIFY_SEC:-8}}" steps got pid i=0
  case "$wait" in ''|*[!0-9]*) wait=8 ;; esac
  steps=$((wait * 4)); [ "$steps" -gt 0 ] || steps=4
  while [ "$i" -lt "$steps" ]; do
    [ "$i" -gt 0 ] && sleep 0.25
    got="$(head -1 "$(team_dispatch_spawn_file "$agent")" 2>/dev/null || true)"
    case "$got" in
      "$nonce "*) pid="${got#* }"
        case "$pid" in ''|*[!0-9]*) : ;; *) printf '%s\n' "$pid"; return 0 ;; esac ;;
    esac
    i=$((i + 1))
  done
  return 1
}

# ---------------------------------------------------------------- 启动失败诊断（M8.2）
# 尾屏：harness 在 agent 退出那一刻自己抓一份（见 team_cmd_dispatch 里的 inner）——
# CLI 退出后容器 shell 的启动链可能清屏，事后再从外面 capture 也许只剩空屏（PM 侧 M8.1 实测过）。
team_dispatch_tail_file() { printf '%s\n' "$TEAM_STATE_DIR/dispatch-$1-tail.txt"; }

# 启动失败诊断：worker 侧的 sibling of state/pm-launch-failed.log（M8.1）。按 agent 分文件，
# 两个 worker 同时失败不会互相覆盖。
team_dispatch_launch_failed_log() { printf '%s\n' "$TEAM_STATE_DIR/dispatch-$1-launch-failed.log"; }

# worker 窗口的尾屏（M8.2）：与 PM 侧 team_pm_pane_tail 同一形状（有界重试 + 归一化），
# 只是目标是 worker 窗口。窗口不存在/始终空白 → 空（不编造内容）。
team_agent_pane_tail() { # <agent> [<重试次数>] → stdout
  local agent="${1:-}" tries="${2:-12}" i=0 out="" t
  [ -n "$agent" ] || return 0
  team_agent_window_exists "$agent" || return 0
  t="$TEAM_SESSION:$agent"
  while :; do
    out="$(tmux capture-pane -p -t "$t" -S -200 2>/dev/null || true)"
    team_text_has_content "$out" && break
    [ "$i" -ge "$tries" ] && break
    i=$((i + 1)); sleep 0.1
  done
  team_text_has_content "$out" || return 0
  printf '%s\n' "$out" | team_pane_tail_normalize
  return 0
}

# 把「agent 没跑起来」的现场写进 state/dispatch-<agent>-launch-failed.log（PM 侧 pm-launch-failed.log 的 sibling）：
# 渲染出的命令 + 解析到的可执行文件 + harness 记下的退出码 + 窗口尾屏（优先用 harness 自抓的那份）。
team_dispatch_launch_diag() { # <agent> <ID> <渲染出的命令> <解析到的可执行文件> <退出码> → 诊断文件路径（追加）
  local agent="$1" id="$2" cmd="$3" bin="$4" rc="$5" f tailf pane src i=0
  f="$(team_dispatch_launch_failed_log "$agent")"; mkdir -p "$TEAM_STATE_DIR"
  tailf="$(team_dispatch_tail_file "$agent")"; pane=""; src=""
  # harness 写下退出证据**之后**才抓尾屏（事件语义优先：退出码不能等抓屏），所以文件可能还差一拍：
  # 有界等它出现（最多 ~1s）——那一份是 agent 退出那一刻的屏幕；始终没有则从外面重抓（见下）。
  while [ "$i" -lt 20 ]; do
    if [ -s "$tailf" ] && grep -q '[^[:space:]]' "$tailf" 2>/dev/null; then break; fi
    i=$((i + 1)); sleep 0.05
  done
  {
    printf '==== %s · agent 启动失败 ====\n' "$(team_timestamp)"
    printf 'agent  : %s\n' "$agent"
    printf 'task   : %s\n' "$id"
    printf 'target : %s:%s\n' "$TEAM_SESSION" "$agent"
    printf 'cmd    : TEAM_AGENT_CMD=%s\n' "$(printf '%q' "${TEAM_AGENT_CMD:-}")"
    printf 'bin    : %s\n' "$bin"
    printf 'exit   : %s（窗口 harness 记录的 agent 退出码）\n' "$rc"
    [ -n "$cmd" ] && printf 'render : %s\n' "$cmd"
    printf 'pane   : %s（%s 字节）\n' "$tailf" "$(wc -c < "$tailf" 2>/dev/null | tr -dc '0-9' || echo 0)"
    if [ -s "$tailf" ] && grep -q '[^[:space:]]' "$tailf" 2>/dev/null; then
      src="agent 退出那一刻，harness 自抓"
      pane="$(team_pane_tail_normalize < "$tailf")"
    else
      src="重新抓取"
      pane="$(team_agent_pane_tail "$agent")"
    fi
    if team_text_has_content "$pane"; then
      printf -- '--- pane（%s）---\n%s\n--- end ---\n' "$src" "$pane"
    else
      printf -- '--- pane ---\n（窗口已不存在或始终空白：用上面的 render 命令手工跑一次看它的报错）\n'
    fi
  } >> "$f"
  printf '%s\n' "$f"
}

# ---------------------------------------------------------------- P55 · 死 pane：座位状况，不是活座位
# 判据与证据字段全部来自 tmux 的 pane census（pane_dead / pane_dead_status / pane_dead_signal /
# pane_dead_time），实测记录见 openspec/changes/agent-pane-survivability/design.md D3/D6 与
# docs/team/reports/P49/。两条纪律：
#   ① 读 pane census 一律用 list-panes：目标不存在 = 报错 = 空输出 = 失败关闭；display-message
#     对坏目标会静默回退到当前窗口（M6.3 6k⑤ 的教训），绝不用它当证据。
#   ② 死 pane 永不以「活座位」身份出现（running 仍要 M6.5/M37 的 pane 进程树证明），也永不是
#     投递目标（send-keys 对遗体返回 0 但文字落进虚空 —— 探针 P5）。

# 字段间用 | 分隔：pane_dead_status/pane_dead_signal 互斥为空，空白分隔会让 read 串列（空字段被吃掉）
team_pane_dead_fields() { # <session:window> → "dead|status|signal|time"；目标不在/读不到 → 非 0、无输出
  local t="${1:-}" out
  [ -n "$t" ] || return 1
  out="$(tmux list-panes -t "$t" -F '#{pane_dead}|#{pane_dead_status}|#{pane_dead_signal}|#{pane_dead_time}' 2>/dev/null | head -1)"
  [ -n "$out" ] || return 1
  printf '%s\n' "$out"
}

team_pane_evidence_text() { # <status> <signal> → "signal=9" / "status=3" / 空（证据未知时绝不编）
  if [ -n "${2:-}" ]; then printf 'signal=%s\n' "$2"
  elif [ -n "${1:-}" ]; then printf 'status=%s\n' "$1"
  fi
}

team_pane_dead_time_text() { # <epoch> → 人读时间；取不到 → 空
  local t="${1:-}"
  case "$t" in ''|*[!0-9]*) return 0 ;; esac
  date -d "@$t" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || true
}

team_agent_scene_lines() { # → 现场行数（TEAM_AGENT_SCENE_LINES，默认 40；非数字回落 40）
  local n="${TEAM_AGENT_SCENE_LINES:-40}"
  case "$n" in ''|*[!0-9]*) n=40 ;; esac
  printf '%s\n' "$n"
}

team_agent_pane_dead_file() { printf '%s\n' "$TEAM_STATE_DIR/dispatch-$1-pane-dead.txt"; }

team_agent_pane_dead() { # <agent> → 0=该席位的窗口在、且 pane 已死（遗体）；窗口不在/活着 → 1
  local a="${1:-}" w f
  [ -n "$a" ] || return 1
  w="$(team_state_get "$a" window "$a")"
  team_tmux_has_window "$TEAM_SESSION" "$w" || return 1
  f="$(team_pane_dead_fields "$TEAM_SESSION:$w" 2>/dev/null || true)"
  if [ "${f%%|*}" = "1" ]; then return 0; fi
  return 1
}

team_agent_pane_evidence() { # <agent> → 死 pane 的退出证据（"signal=9"）；不是死 pane/证据未知 → 非 0、无输出
  local a="${1:-}" w f dead status signal dtime ev
  [ -n "$a" ] || return 1
  w="$(team_state_get "$a" window "$a")"
  f="$(team_pane_dead_fields "$TEAM_SESSION:$w" 2>/dev/null || true)"
  [ -n "$f" ] || return 1
  IFS='|' read -r dead status signal dtime <<< "$f"
  [ "$dead" = "1" ] || return 1
  ev="$(team_pane_evidence_text "$status" "$signal")"
  [ -n "$ev" ] || return 1
  printf '%s\n' "$ev"
}

# 死 pane 的画面抓取（唯一实现：复用留证与 status 的现场块共用）：capture-pane -S -
# （可见屏幕可能丢最后一行，scrollback 才是全量 —— 探针 P10），逐行去尾空白、丢掉 tmux 自己画在
# 屏幕上的「Pane is dead (…)」通知行（它是元数据，退出证据与时刻由 census 单列），再去掉末尾空行，
# 最后截到 TEAM_AGENT_SCENE_LINES 行 —— 于是「最后 N 行」落在 agent 的真实内容上。
team_agent_corpse_scene() { # <session:window> → 最后 N 行画面（抓不到 → 空）
  local t="${1:-}"
  [ -n "$t" ] || return 1
  tmux capture-pane -p -S - -t "$t" 2>/dev/null \
    | sed -e 's/[[:space:]]*$//' -e '/^Pane is dead (/d' \
    | awk '{ if (NF) last=NR; line[NR]=$0 } END { for (i=1; i<=last; i++) print line[i] }' \
    | tail -n "$(team_agent_scene_lines)"
}

# 复用留证（design D5）：替换遗体窗口之前，先把「座位/窗口/时刻/退出证据/最后画面」落盘。
# 文件格式：头部五行 + "--- scene ---" + 画面行（status <ID> 的现场块按这个结构回读）。
team_agent_capture_corpse() { # <agent> → 打印落盘路径；不是死 pane/写不出 → 非 0
  local a="${1:-}" w f dead status signal dtime out
  w="$(team_state_get "$a" window "$a")"
  team_tmux_has_window "$TEAM_SESSION" "$w" || return 1
  f="$(team_pane_dead_fields "$TEAM_SESSION:$w" 2>/dev/null || true)"
  IFS='|' read -r dead status signal dtime <<< "${f:- }"
  [ "$dead" = "1" ] || return 1
  out="$(team_agent_pane_dead_file "$a")"
  {
    printf 'seat: %s\n' "$a"
    printf 'window: %s:%s\n' "$TEAM_SESSION" "$w"
    printf 'captured: %s\n' "$(date -Is)"
    printf 'exit: %s\n' "$(team_pane_evidence_text "$status" "$signal")"
    printf 'dead_time: %s\n' "$(team_pane_dead_time_text "$dtime")"
    printf '%s\n' '--- scene ---'
    team_agent_corpse_scene "$TEAM_SESSION:$w"
  } > "$out" 2>/dev/null || return 1
  printf '%s\n' "$out"
}

# ---------------------------------------------------------------- 派单不许叠任务（M9.3 / DECISIONS D16）
# 现场（PM 自己的事故）：M9.2 还在 dev 手上，PM 又把 P2 派给同一个 agent —— 新派单接管了它的窗口与 state，
# M9.2 只好临时换人交接。工具当时**知道**那个 agent 的任务与分支（state/<agent>.env、BOARD、工作树），
# 却什么都没说。这条守卫把「派单前先看它手上有没有没结束的活」从纪律变成机制（D16 的工具侧）。
# 三条信号同时成立才拒绝（缺一条就照旧派单，不猜）：
#   ① state 记着这个 agent 的另一个任务 X（`task=`）；
#   ② X 还没结束（M9.2 的交付证据 + 看板裁决 —— team_task_open_reason）；
#   ③ 工作树能定位，且确实停在一条任务分支上（不是保护分支、不是 detached）。
# 不拦：派的就是 X 自己（resume / 断点续跑是「继续」，不是「叠」）；X 已经结束；判不出来（说清缺哪个信号）。
# `--force` 是显式覆盖：把「覆盖了什么」打进输出（不静默接管），真实派单时再落一条审计日志。
# ---------------------------------------------------------------- P140（dispatch-friction · R4/R5）· 一次派单前检查
# 所有「无需副作用即可判定」的守卫都产出 finding；driver 把整趟跑完，输出**一份**拒绝：
#   · 守卫用 df_err/df_warn/df_dim 写缓冲区（不是终端）→ 消息体逐字节保留；
#   · 守卫 rc≠0 = 阻塞项，rc=0 = 说明/警告（不阻塞）；
#   · 报告顺序：阻塞项（守卫顺序）→ 说明 → 计行；第一行就是第一个阻塞项自己的首行（没有额外横幅）；
#   · 只有报告没有阻塞项时，driver 才允许写 state / 打计划 / 开窗。
# 数组元素编码：<stderr 文本>\x1f<stdout 文本>（两个流分开保留，重放时各回各的流）。
_TEAM_DF_BLOCKS=()
_TEAM_DF_NOTES=()
_TEAM_DF_N=0
_TEAM_DF_RUN_RC=0
_TEAM_DF_ERR=""
_TEAM_DF_OUT=""
team_df_reset() { _TEAM_DF_BLOCKS=(); _TEAM_DF_NOTES=(); _TEAM_DF_N=0; _TEAM_DF_RUN_RC=0; _TEAM_DF_ERR=""; _TEAM_DF_OUT=""; }
team_df_err()  { _TEAM_DF_ERR="${_TEAM_DF_ERR}$(printf '%s✗%s' "$C_RED" "$C_RESET") $*"$'\n'; }
team_df_warn() { _TEAM_DF_ERR="${_TEAM_DF_ERR}$(printf '%s!%s' "$C_YEL" "$C_RESET") $*"$'\n'; }
team_df_dim()  { _TEAM_DF_OUT="${_TEAM_DF_OUT}$(printf '%s%s%s' "$C_DIM" "$*" "$C_RESET")"$'\n'; }
team_df_hint() { _TEAM_DF_OUT="${_TEAM_DF_OUT}$(printf '%s⚠%s' "$C_YEL" "$C_RESET") $*"$'\n'; }
team_df_raw_err() { _TEAM_DF_ERR="${_TEAM_DF_ERR}${1:-}"$'\n'; }
# 整段多行文本按行进缓冲（行内已有前缀时不再加）——**不用管道**：管道子 shell 改不到全局。
team_df_lines_raw_err() { local t="${1:-}" line; [ -n "$t" ] || return 0; while IFS= read -r line; do team_df_raw_err "$line"; done <<< "$t"; }
team_df_lines_err() { local t="${1:-}" line; [ -n "$t" ] || return 0; while IFS= read -r line; do team_df_err "$line"; done <<< "$t"; }
team_df_lines_dim() { local t="${1:-}" line; [ -n "$t" ] || return 0; while IFS= read -r line; do team_df_dim "$line"; done <<< "$t"; }
# 一个守卫跑一趟：_TEAM_DF_RUN_RC = 这次守卫的 rc（driver 据此判「前提缺失 → 判不了」，不冒充查过）。
team_df_run() { # <守卫函数> [参数…]
  _TEAM_DF_ERR=""; _TEAM_DF_OUT=""
  local rc=0; "$@" || rc=$?
  _TEAM_DF_RUN_RC="$rc"
  if [ "$rc" -eq 0 ]; then _TEAM_DF_NOTES+=("$_TEAM_DF_ERR"$'\x1f'"$_TEAM_DF_OUT")
  else _TEAM_DF_BLOCKS+=("$_TEAM_DF_ERR"$'\x1f'"$_TEAM_DF_OUT"); _TEAM_DF_N=$((_TEAM_DF_N + 1)); fi
  return 0
}
# 库守卫（team_mem_guard / team_model_guard / team_guard_resume_session / team_agent_check_launch）：
# 它们没有必须留在父进程的副作用，输出用命令替换捕获（子 shell 里 team_die 不会带走派单）。
team_df_run_lib() { # <函数> [参数…]
  _TEAM_DF_ERR=""; _TEAM_DF_OUT=""
  local rc=0 out=""
  out="$("$@" 2>&1)" || rc=$?
  _TEAM_DF_RUN_RC="$rc"
  [ -n "$out" ] && out="$out"$'\n'
  if [ "$rc" -eq 0 ]; then _TEAM_DF_NOTES+=("$out"$'\x1f'"")
  else _TEAM_DF_BLOCKS+=("$out"$'\x1f'""); _TEAM_DF_N=$((_TEAM_DF_N + 1)); fi
  return 0
}
# driver 自己的说明行（“判不了”“adapter 配置坏了 → 可执行文件判不了”）。
team_df_say() { # <一行说明>
  _TEAM_DF_ERR=""; _TEAM_DF_OUT=""
  team_df_dim "$*"
  _TEAM_DF_NOTES+=("$_TEAM_DF_ERR"$'\x1f'"$_TEAM_DF_OUT")
  _TEAM_DF_ERR=""; _TEAM_DF_OUT=""
}
# 一份拒绝：阻塞项 → 说明 → 计行（末行）；没有阻塞项时只重放说明并返回 0。
team_df_report() { # → 0=继续 / 1=拒绝
  local rec err out
  for rec in ${_TEAM_DF_BLOCKS[@]+"${_TEAM_DF_BLOCKS[@]}"}; do
    err="${rec%%$'\x1f'*}"; out="${rec#*$'\x1f'}"
    [ -n "$err" ] && printf '%s' "$err" >&2
    [ -n "$out" ] && printf '%s' "$out"
  done
  for rec in ${_TEAM_DF_NOTES[@]+"${_TEAM_DF_NOTES[@]}"}; do
    err="${rec%%$'\x1f'*}"; out="${rec#*$'\x1f'}"
    [ -n "$err" ] && printf '%s' "$err" >&2
    [ -n "$out" ] && printf '%s' "$out"
  done
  [ "$_TEAM_DF_N" -gt 0 ] || return 0
  team_err "共 $_TEAM_DF_N 个阻塞项 —— 修好上面每一项后重新派单（--force 只覆盖允许覆盖的项）"
  return 1
}

# 叠任务判定（原 team_dispatch_stack_guard；P140 起是一个 finding 产出器，rc=1 = 阻塞项）。
# 判定与消息体逐字不变，只多了两条 `修法：` 路线（resume / --force，带具体 ID 与任务书路径）。
team_dispatch_judge_stack() { # <agent> <ID> <任务书> <force> → 0=继续 / 1=拒绝（原因已写入收集器）
  local agent="$1" id="$2" brief="$3" force="${4:-0}"
  local prev wt wt_branch prev_branch reason st
  TEAM_DISPATCH_STACK_PREV=""          # 只有真的覆盖了才置位（同一进程里连续派单也不串台）
  prev="$(team_state_get "$agent" task '')"
  if [ -z "$prev" ]; then
    team_df_dim "  $agent 没有在飞的任务记录（state/$agent.env 的 task= 为空或文件不存在）：判不出它手上有没有没结束的活，这次不拦"
    return 0
  fi
  [ "$prev" = "$id" ] && return 0     # 同一个任务 = resume / 断点续跑：这是「继续」，不是「叠」
  wt="$(team_state_get "$agent" worktree '')"
  if [ -z "$wt" ] || [ ! -d "$wt" ]; then wt="$(team_agent_worktree "$agent")"; fi
  if [ ! -d "$wt" ]; then
    team_df_dim "  $agent 记着的任务 $prev 找不到工作树（$wt）：判不出它是否还压在这个任务上，这次不拦"
    return 0
  fi
  wt_branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [ -z "$wt_branch" ] || [ "$wt_branch" = "HEAD" ]; then
    team_df_dim "  $agent 的工作树 $wt 不在任何分支上（detached 或不是 git 仓库）：判不出它是否还压着 $prev，这次不拦"
    return 0
  fi
  if [ "$wt_branch" = "$TEAM_PROTECTED_BRANCH" ]; then
    # 保护分支上的工作树本来就不允许开工（工作树判定会给出该跑的 git 命令）：
    # 这里不重复报同一件事，只把「它手上还有 X」说出来
    team_df_dim "  $agent 的工作树在 $TEAM_PROTECTED_BRANCH 上，而它手上还有没结束的任务 $prev：先收尾再派（下面按常规守卫处理）"
    return 0
  fi
  if reason="$(team_task_open_reason "$prev")"; then return 0; fi   # X 已结束：输出与以前逐字相同
  prev_branch="$(team_state_get "$agent" branch '')"
  st="$(team_board_status "$prev")"
  if [ "$force" = "1" ]; then
    team_df_warn "显式覆盖（--force）：$agent 上还有没结束的任务 $prev —— 这次派 $id 会接管它的窗口与 state"
    team_df_dim "  被让位的任务：$prev ｜看板：${st:-没有这一行} ｜分支：$wt_branch（state 记的是 ${prev_branch:-未记}）"
    team_df_dim "  它还没结束：$reason"
    TEAM_DISPATCH_STACK_PREV="$prev"    # 真实派单路径据此写审计（--print 不写）
    return 0
  fi
  team_df_err "拒绝派单：$agent 上还有一个没结束的任务（$prev）—— 这样会把这次的任务叠上去，接管它的窗口与 state"
  team_df_err "  任务    ：$prev（看板状态：${st:-BOARD 里没有这一行}）"
  if [ "$wt_branch" = "$prev_branch" ] || team_branch_is_for_task "$wt_branch" "$agent" "$prev"; then
    team_df_err "  分支    ：$wt_branch（工作树 $wt 还停在它上面）"
  else
    team_df_err "  分支    ：工作树 $wt 停在 $wt_branch（state 记的是 ${prev_branch:-没有记录}）"
  fi
  team_df_err "  没结束  ：$reason"
  team_df_err "  修法：$TEAM_CLI resume --agent $agent"
  team_df_err "        （先收尾 $prev；复验/合并后再 team board set $prev done）"
  team_df_err "  修法：$TEAM_CLI dispatch $agent $id $brief --force"
  team_df_err "        （显式覆盖：警告 + 一行审计）"
  return 1
}

# 任务书歧义（M9.3 ⑥；P140 起是 finding 产出器）：同一个 ID 有多份任务书 = 认不出这次的 scope。
# 判定与消息体逐字保留；修法是「把过期的那份改名出 glob」——保留历史，也不动正在派的那一份。
team_dispatch_judge_briefs() { # <ID> <briefs（每行一个）> <数量> <本次要派的那一份>
  local id="$1" briefs="$2" n="${3:-0}" want="${4:-}" b rel stale=""
  [ "${n:-0}" -gt 1 ] || return 0
  team_df_err "拒绝派单：$id 有多份任务书（$n 份）—— 认不出哪一份是这次的 scope，不猜"
  while IFS= read -r b; do
    [ -n "$b" ] || continue
    rel="${b#"$TEAM_MAIN_ROOT"/}"
    team_df_err "    $rel"
  done <<< "$briefs"
  team_df_err "  旧实现按 glob 顺序取第一份：分支名可能算成旧 slug（撞名 fatal: a branch named … already exists），"
  team_df_err "  更糟的是把旧任务书的 scope 派出去。"
  # 修法：把本次**不是**的那份改名出 glob（保留历史）；一份一条可粘贴命令。
  while IFS= read -r b; do
    [ -n "$b" ] || continue
    [ "$b" = "$want" ] && continue
    [ -n "$stale" ] && continue
    stale="$b"
  done <<< "$briefs"
  [ -n "$stale" ] && team_df_dim "$(printf '  修法：git -C %q mv %q %q' "$TEAM_MAIN_ROOT" "$stale" "$stale.bak")"
  [ -n "$stale" ] && team_df_dim "       （把过期的那份改名出 glob；保留历史）"
  team_df_err "  确定性做法：只留一份 —— 把过期的那份改名/删掉（或给它自己的 ID），再派单。"
  return 1
}

# ---------------------------------------------------------------- P23（D31）· change 为中心的派单纪律（P140：finding 化）
# 四条规则各自是一个 finding 产出器（原 team_dispatch_change_guard 的判定、覆盖闀与审计不变）：
#   规则 1 · 一个任务最多一个 change id（没有逃生门：一个任务实现两个 change 是派错单）
#   规则 B · change-less 的任务必须声明能解析的锚（specs:#需求 或 anchor: none (infra) — 理由）
#   规则 2 · 同一 change 的两个未结束任务不得写同一个 delta 文件（单写者）
#   规则 3 · verify 任务的 agent 不能是该 change 的 apply 作者
# driver 把规则 1 的结果（change）传给 B/2/3；规则 1 失败就不调它们（判不出的事在报告里说清）。
# `--force` 覆盖处打印警告并往 TEAM_DISPATCH_AUDIT_LINES 追加**一行**审计
# （真正落盘在派单成功之后，`--print` 不写 state）。
# 「判不出来」信号（兄弟的 deltas: 坏/缺 agent:）一律吵但不是拒绝 —— 不把未知冒充成干净。
team_dispatch_judge_change_shape() { # <ID> <任务书>；合法 → _TEAM_DF_CHANGE=<值>
  local id="$1" brief="$2" val lead example body raw1
  _TEAM_DF_CHANGE=""
  if val="$(team_task_change_value "$brief")"; then _TEAM_DF_CHANGE="$val"; return 0; fi
  # P140（R2）：第一行就带合法示例（值里第一个合法 id 前缀，否则 `-`）与具体原因。
  raw1="$(team_brief_field_raw "$brief" change | head -1)"
  lead="$(printf '%s' "$raw1" | sed -n 's/^\([A-Za-z0-9][A-Za-z0-9._-]*\).*/\1/p')"
  if [ -n "$lead" ]; then example="change: $lead（或 change: -）"; else example="change: -"; fi
  team_df_err "拒绝派单：$id 的任务书 change: 行不合法 —— $(printf '%s' "$val" | head -1)；合法示例：$example"
  body="$(printf '%s\n' "$val" | tail -n +2 | sed 's/^/  /')"
  [ -n "$body" ] && team_df_lines_raw_err "$body"
  team_df_err "  接受的形式："
  team_df_err "    · change: <一个 change id>     例：change: change-centric-discipline"
  team_df_err "    · change: -                    不属于任何 change（但要在 specs:/anchor: 里声明锚）"
  team_df_err "  改行：change: ${lead:--}"
  team_df_err "  规则 1 没有 --force 逃生门：一个任务实现两个 change 是派错单，不是偏好。"
  return 1
}

team_dispatch_judge_anchor() { # <agent> <ID> <任务书> <change> <force>
  local agent="$1" id="$2" brief="$3" change="$4" force="${5:-0}" out body rel
  [ "$change" = "-" ] || return 0
  rel="${brief#"$TEAM_MAIN_ROOT"/}"
  if out="$(team_task_anchor "$brief")"; then return 0; fi
  if [ "$force" = "1" ]; then
    team_df_warn "显式覆盖（--force）：$id 没有 change:，锚也缺失/不解析 —— 这次照常派单"
    body="$(printf '%s\n' "$out" | sed 's/^/    /')"
    team_df_lines_raw_err "$body"
    TEAM_DISPATCH_AUDIT_LINES="${TEAM_DISPATCH_AUDIT_LINES}dispatch $agent: --force 覆盖锚缺失（$id 无 change 且 $rel 的 specs:/anchor: 解析不了）"$'\n'
    return 0
  fi
  team_df_err "拒绝派单：$id 没有 change: 行（或值是 \`-\`），必须声明它的锚"
  body="$(printf '%s\n' "$out" | sed 's/^/  /')"
  team_df_lines_raw_err "$body"
  team_df_err "  编辑 $rel 的 specs:/anchor: 行（specs: <capability>#<requirement> 或 anchor: none (infra) — <非空理由>；改完重派）"
  team_df_err "  修法：$TEAM_CLI dispatch $agent $id $brief --force"
  team_df_err "        （警告 + 一行审计：覆盖的是「没有 change 也没有锚」这一项）"
  return 1
}

team_dispatch_judge_deltas_shape() { # <ID> <任务书>
  local id="$1" brief="$2" out body sug
  if out="$(team_task_deltas "$brief")"; then return 0; fi
  sug="$(team_task_deltas_suggestion "$brief")"
  # P140（R3）：第一行就带合法示例与具体原因（哪个分隔符 / 哪一项为空）。
  team_df_err "拒绝派单：$id 的 deltas: 行不合法 —— $(printf '%s' "$out" | head -1)；合法示例：deltas: panel, verification（或 deltas: -）"
  body="$(printf '%s\n' "$out" | tail -n +2)"
  [ -n "$body" ] && team_df_lines_raw_err "$body"
  team_df_err "  改行：deltas: $sug"
  team_df_err "  （deltas: 决定 delta 单写者检查，不能静默当空集；缺行 = 读作整个 change 的 delta 集）"
  return 1
}

team_dispatch_judge_delta_writer() { # <agent> <ID> <任务书> <change> <force>
  local agent="$1" id="$2" brief="$3" change="$4" force="${5:-0}"
  [ "$change" != "-" ] || return 0
  local mine mine_decl mine_text sib sde sdt sib_text shared sid sphase sst sreason sbrief
  local -a conf_items=()
  if ! mine="$(team_task_delta_targets "$brief" "$change")"; then
    team_df_dim "  deltas: 行不合法 → change $change 的 delta 单写者检查判不了（见上一项）"
    return 0
  fi
  mine_decl="$(team_task_deltas "$brief")"
  case "$mine_decl" in
    '*') mine_text='（没有 deltas: 行 → 读作整个 change 的 delta 集）' ;;
    '')  mine_text='deltas: -（不写 delta）' ;;
    *)   mine_text="deltas: $(printf '%s' "$mine_decl" | tr '\n' ',')" ;;
  esac
  while IFS=$'\t' read -r sid sphase sst sreason sbrief; do
    [ -n "$sid" ] || continue
    [ "$sid" = "$id" ] && continue
    if ! sde="$(team_task_delta_targets "$sbrief" "$change")"; then
      team_df_warn "  delta 单写者检查：兄弟 $sid（看板 $sst）的 deltas: 行不合法 —— 它的目标集判不出来，不冒充干净"
      continue
    fi
    sdt="$(team_task_deltas "$sbrief")"
    case "$sdt" in
      '*') sib_text='（没有 deltas: 行 → 读作整个 change 的 delta 集）' ;;
      '')  sib_text='deltas: -（不写 delta）' ;;
      *)   sib_text="deltas: $(printf '%s' "$sdt" | tr '\n' ',')" ;;
    esac
    shared=""
    while IFS= read -r sib; do
      [ -n "$sib" ] || continue
      if printf '%s\n' "$mine" | grep -qxF -- "$sib"; then shared="${shared:+$shared }$sib"; fi
    done <<< "$sde"
    if [ -z "$shared" ]; then
      team_df_dim "  change $change 的 delta 单写者检查：兄弟 $sid（看板 $sst，$sib_text）｜本次 $mine_text → 无重叠"
      continue
    fi
    if [ "$force" = "1" ]; then
      team_df_warn "显式覆盖（--force）：change $change 的 delta 单写者冲突 —— $sid（看板 $sst）与 $id 都会写 $shared"
      team_df_dim "  $sid 的声明：$sib_text ｜ 本次声明：$mine_text"
      TEAM_DISPATCH_AUDIT_LINES="${TEAM_DISPATCH_AUDIT_LINES}dispatch $agent: --force 覆盖 delta 单写者（$sid 与 $id 共享 $shared）"$'\n'
      continue
    fi
    # F4：不在第一个冲突兄弟处 return —— 先收集，循环结束后**一次列全**
    #（编号 i/n 与总数 n 同源，逐条数与总数自洽）。
    conf_items+=("$(printf '兄弟任务：%s ｜阶段 %s ｜看板 %s\n它没结束：%s\n共享文件：%s\n它的声明：%s\n本次声明：%s' \
      "$sid" "${sphase:--}" "$sst" "$sreason" "$shared" "$sib_text" "$mine_text")")
  done < <(team_change_unfinished "$change")
  if [ "${#conf_items[@]}" -gt 0 ]; then
    local n="${#conf_items[@]}" i=0 item line
    team_df_err "拒绝派单：change $change 的同一个 delta 文件被 $n 个未结束的兄弟任务声明（单写者规则）"
    for item in "${conf_items[@]}"; do
      i=$((i + 1))
      while IFS= read -r line; do
        [ -n "$line" ] && team_df_err "  冲突 $i/$n：$line"
      done <<< "$item"
    done
    team_df_err "  列全自对账：上面的编号 1..$n 与计数 $n 同源（逐条数 = 总数）"
    team_df_err "  等这些兄弟结束（done/closed/交付证据）再派，或把两边的 deltas: 写成互不相交的 capability"
    team_df_err "  修法：$TEAM_CLI dispatch $agent $id $brief --force"
    team_df_err "        （显式覆盖：警告 + 一行审计；每个冲突兄弟一行审计）"
    return 1
  fi
  return 0
}

team_dispatch_judge_verify_seat() { # <agent> <ID> <任务书> <change> <phase> <force>
  local agent="$1" id="$2" brief="$3" change="$4" phase="$5" force="${6:-0}"
  [ "$phase" = "verify" ] && [ "$change" != "-" ] || return 0
  local authors kind aid aauth authored="" dropped="" missing=""
  authors="$(team_change_apply_authors "$change")"
  while IFS=$'\t' read -r kind aauth aid _why; do
    [ -n "$kind" ] || continue
    case "$kind" in
      agent)   [ "$aauth" = "$agent" ] && authored="${authored:+$authored、}$aid" ;;
      dropped) dropped="${dropped:+$dropped、}$aid" ;;
      missing) missing="${missing:+$missing、}$aid（${_why:-缺 agent:}）" ;;
    esac
  done <<< "$authors"
  [ -n "$dropped" ] && team_df_dim "  已排除（看板 dropped）：$dropped"
  [ -n "$missing" ] && team_df_warn "  作者信号缺失：$missing —— 判不出它们的作者，不当作干净（照常派单）"
  if [ -n "$authored" ]; then
    if [ "$force" = "1" ]; then
      team_df_warn "显式覆盖（--force）：verification 不再独立 —— $agent 写过 change $change 的 apply 任务（$authored），又要 verify $id"
      TEAM_DISPATCH_AUDIT_LINES="${TEAM_DISPATCH_AUDIT_LINES}dispatch $agent: --force 覆盖自验（change $change 的 apply 作者 $authored 来 verify $id）"$'\n'
    else
      team_df_err "拒绝派单：verification 不独立 —— $agent 写过 change $change 的 apply 任务（$authored），不能自己验自己"
      team_df_err "  change：$change ｜ agent：$agent ｜ 它写过的任务：$authored"
      team_df_err "  换一个没写过这些 apply 任务的 agent 来 verify（独立验证不换人就不成立）"
      team_df_err "  修法：$TEAM_CLI dispatch $agent $id $brief --force"
      team_df_err "        （显式覆盖：警告 + 一行审计）"
      return 1
    fi
  fi
  return 0
}

# 分支声明不合法（--branch 或任务书 branch: 行不属于本任务）：拒绝 + 一条可粘的修法。
team_dispatch_judge_branch_decl() { # <agent> <ID> <任务书> <原因行> <--branch 值>
  local agent="$1" id="$2" brief="$3" reason="$4" flag="${5:-}" derived
  derived="$(team_branch_for_agent "$agent" "$id")"
  team_df_err "拒绝派单：分支声明不属于本任务（$id）—— $reason"
  team_df_err "  接受形状：task/$id-<slug>（或 agent/$agent）"
  if [ -n "$flag" ]; then
    team_df_err "  修法：$TEAM_CLI dispatch $agent $id $brief --branch $derived"
  else
    team_df_err "  改行：branch: $derived"
  fi
  return 1
}

# agent 可执行文件可解析（P140：原 team_die 变成阻塞项，与其他判定同一份报告）。
team_dispatch_judge_agent_bin() { # <agent>
  local agent_bin probe
  if [ -n "${TEAM_AGENT_CMD:-}${TEAM_AGENT_BIN:-}" ]; then
    # 自定义 adapter（codex/opencode/…）：只看配好的可执行文件能不能解析到
    agent_bin="$(team_agent_bin_path)"
    case "$agent_bin" in /*) ;; *) team_df_warn "agent 可执行文件不是绝对路径（$agent_bin）：窗口里可能 PATH 未就绪，建议用 TEAM_AGENT_BIN 写死绝对路径";; esac
    if ! command -v "$agent_bin" >/dev/null 2>&1; then
      probe="${TEAM_AGENT_CMD%% *}"; [ -n "$probe" ] || probe="$(basename "$agent_bin")"
      team_df_err "找不到 agent 可执行文件：$agent_bin（检查 TEAM_AGENT_BIN 或 TEAM_AGENT_CMD 的首词）"
      team_df_err "  修法：$TEAM_CLI config set TEAM_AGENT_BIN \"$(command -v "$probe")\""
      team_df_err "        （把可执行文件指到真的路径；command -v $probe 找不到就得先装/先修 PATH）"
      return 1
    fi
  else
    agent_bin="$TEAM_PI_BIN"
    case "$agent_bin" in /*) ;; *) team_df_warn "TEAM_PI_BIN 不是绝对路径（$agent_bin）：窗口里可能 PATH 未就绪，建议写死绝对路径";; esac
    if ! command -v "$TEAM_PI_BIN" >/dev/null 2>&1; then
      team_df_err "找不到 pi 可执行文件：TEAM_PI_BIN=$TEAM_PI_BIN（设成绝对路径再派单）"
      team_df_err "  修法：$TEAM_CLI config set TEAM_PI_BIN \"$(command -v pi)\""
      team_df_err "        （指向真的 pi；command -v 找不到就得先装/先修 PATH）"
      return 1
    fi
  fi
  return 0
}

# ---------------------------------------------------------------- P151（F3）· 容量拒绝的可粘修法
# 容量守卫（team_mem_guard）只做判定与诊断，不知道自己在为谁派单 —— 修法要含真的 agent / ID /
# 任务书路径，所以由 driver 这侧补上（判定与覆盖语义一字不动：这里只是多打印两条能跑的命令，
# 且只打开真正拦住的那条硬线）。
team_dispatch_mem_fix_cmd() { # <agent> <ID> <任务书> <守卫输出> → 覆盖命令
  local agent="$1" id="$2" taskfile="$3" out="$4" knobs=""
  case "$out" in *"MemAvailable 只剩"*) knobs="$knobs TEAM_MIN_AVAIL_MB=0" ;; esac
  case "$out" in *"磁盘 swap 只剩"*) knobs="$knobs TEAM_MIN_FREE_SWAP_MB=0" ;; esac
  case "$out" in *"MemAvailable + 磁盘 swap 空闲仅"*) knobs="$knobs TEAM_MIN_TOTAL_MB=0" ;; esac
  [ -n "$knobs" ] || knobs=" TEAM_MIN_AVAIL_MB=0 TEAM_MIN_FREE_SWAP_MB=0 TEAM_MIN_TOTAL_MB=0"
  printf '%s %s dispatch %s %s %s\n' "${knobs# }" "$TEAM_CLI" "$agent" "$id" "$(printf '%q' "$taskfile")"
}

team_dispatch_judge_mem() { # <agent> <ID> <任务书>（team_df_run_lib 守卫：透传 team_mem_guard 的判定）
  local agent="$1" id="$2" taskfile="$3" out rc=0
  out="$(team_mem_guard 2>&1)" || rc=$?
  [ -n "$out" ] && printf '%s\n' "$out"
  [ "$rc" -eq 0 ] && return 0
  local override_line override_note
  override_line="  修法：$(team_dispatch_mem_fix_cmd "$agent" "$id" "$taskfile" "$out")"
  override_note="        （显式降低底线：拿机器稳定性冒险；确认余量真的够再用）"
  printf '%s\n' "  等一个席位结束后再重派（$TEAM_CLI ps 看谁在跑；这行不是可粘路线，只是建议）" \
                 "$override_line" "$override_note"
  return 1
}

# ---------------------------------------------------------------- P140（dispatch-friction · R6）· 席位上一轮预提示
# 两条腿各自独立、都可缺（判不出来一律沉默，不猜）：
#   · 死因腿：agent-death-reason 的读取器给出 quota/balance —— 点名分类、来源、时间与原文；
#   · 零产出腿：state/<agent>.env 里上一轮记的 sid/sid_bytes 与同一个会话文件**现在的字节数相等**
#     （启动时记下的值，下一轮没长过）—— 用工具自己的粗粒度词汇 `0 bytes ≈ 0 tokens`。
# 永远不阻断、不改退出码；两个腿都判不出来 → 一行都不打印。
team_dispatch_judge_seat_hint() { # <agent> <worktree>
  local agent="$1" wt="$2" fields cat source time raw sid rec_bytes f now_bytes
  fields="$(team_seat_death_fields "$agent" 2>/dev/null || true)"
  if [ -n "$fields" ]; then
    IFS=$'\t' read -r cat source time raw <<< "$fields"
    case "$cat" in
      quota|balance)
        if [ -n "$time" ] && [ "$time" != "-" ]; then
          team_df_hint "这个席位上一次死于 $cat（来源：$source · $time）· 原文：${raw:--} —— 重派前先确认额度/余额（或换模型）"
        else
          team_df_hint "这个席位上一次死于 $cat（来源：$source）· 原文：${raw:--} —— 重派前先确认额度/余额（或换模型）"
        fi ;;
    esac
  fi
  sid="$(team_state_get "$agent" sid '')"
  rec_bytes="$(team_state_get "$agent" sid_bytes '')"
  if [ -n "$sid" ] && [ -n "$rec_bytes" ]; then
    f="$(team_session_file "$sid" "$wt" 2>/dev/null || true)"
    if [ -n "$f" ] && [ -f "$f" ]; then
      now_bytes="$(team_file_bytes "$f")"
      case "$rec_bytes" in ''|*[!0-9]*) : ;; *)
        if [ "$now_bytes" = "$rec_bytes" ]; then
          team_df_hint "这个席位上一轮没有产出：0 bytes ≈ 0 tokens（上一轮会话 $sid 的文件 $f 从启动起一个字节没长）"
        fi ;;
      esac
    fi
  fi
  return 0
}

team_cmd_dispatch() {
  team_require_cmd tmux "agent 在 tmux 窗口里跑，PM 需要能旁观与追问"
  local agent="" id="" taskfile="" model="" branch_flag="" fresh=0 printonly=0 overflow=0 force=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --model) model="${2:?}"; shift 2 ;;
      --branch)
        [ $# -ge 2 ] || team_usage_die "dispatch: --branch 需要 <分支名>"
        [ -n "$2" ] || team_usage_die "dispatch: --branch 需要 <分支名>"
        branch_flag="$2"; shift 2 ;;
      --branch=*)
        [ -n "${1#*=}" ] || team_usage_die "dispatch: --branch 需要 <分支名>"
        branch_flag="${1#*=}"; shift ;;
      --fresh) fresh=1; shift ;;
      --allow-overflow) overflow=1; shift ;;
      --force) force=1; shift ;;
      --print) printonly=1; shift ;;
      -*) team_usage_die "dispatch: 未知参数 $1" ;;
      *) if [ -z "$agent" ]; then agent="$1"
         elif [ -z "$id" ]; then id="$1"
         elif [ -z "$taskfile" ]; then taskfile="$1"
         else team_usage_die "dispatch: 多余参数 $1"; fi
         shift ;;
    esac
  done
  [ -n "$agent" ] && [ -n "$id" ] && [ -n "$taskfile" ] || \
    team_usage_die "dispatch <agent> <ID> <task-file> [--model m] [--branch <name>] [--fresh] [--allow-overflow] [--force] [--print]"
  team_require_agent "$agent"

  # 任务书路径：先按 cwd 解析，再按主工作树解析
  [ -f "$taskfile" ] || taskfile="$TEAM_MAIN_ROOT/$taskfile"
  [ -f "$taskfile" ] || team_die "找不到任务书：$taskfile"
  taskfile="$(cd "$(dirname "$taskfile")" && pwd)/$(basename "$taskfile")"
  # M6.3 F15：任务书必须在项目主工作树里。提示词命令 worker「work only inside <project>」，
  # 却把 /tmp/... 称为 "repo-relative path"（自相矛盾）；而且项目外的文件不归项目管。
  case "$taskfile" in
    "$TEAM_MAIN_ROOT"/*) ;;
    *)
      team_err "任务书不在本项目里：$taskfile"
      team_dim "  项目主工作树：$TEAM_MAIN_ROOT"
      team_dim "  把任务书放进项目再派单（例如 $TEAM_DOCS_DIR/tasks/）：worker 只被授权在项目内工作" >&2
      return 1 ;;
  esac

  # M9.3 ⑥ + P140（dispatch-friction · R4/R5）：认错任务书与所有“无需副作用即可判定”的守卫
  # 在一趟里判完，输出**一份**拒绝（--force 不适用认错任务：认错 scope 不是「你说了算」的事）。
  local briefs nbrief
  briefs="$(team_task_briefs "$id")"
  nbrief="$(printf '%s\n' "$briefs" | grep -c . || true)"

  team_df_reset
  TEAM_CHECKED_BRANCH=""
  TEAM_DISPATCH_AUDIT_LINES=""
  TEAM_DISPATCH_STACK_PREV=""

  # ① 任务书歧义
  team_df_run team_dispatch_judge_briefs "$id" "$briefs" "$nbrief" "$taskfile"

  # ② 分支声明（--branch ＞ 任务书 branch: 行 ＞ 由标题推导）
  local br_out="" br_name="" br_src="" br_decl_ok=1
  if br_out="$(team_dispatch_branch_decl "$agent" "$id" "$taskfile" "$branch_flag")"; then
    br_name="${br_out%%$'\x1f'*}"; br_src="${br_out#*$'\x1f'}"
  else
    br_decl_ok=0
    team_df_run team_dispatch_judge_branch_decl "$agent" "$id" "$taskfile" "$(printf '%s' "$br_out" | head -1)" "$branch_flag"
  fi

  # ③ 头部规则（change 形状 / 锚 / deltas 形状 / 单写者 / verify 席位）
  team_df_run team_dispatch_judge_change_shape "$id" "$taskfile"
  local df_change="${_TEAM_DF_CHANGE:-}"
  local df_phase; df_phase="$(team_brief_field "$taskfile" phase)"
  case "$df_phase" in explore|propose|apply|verify|archive) ;; *) df_phase="" ;; esac
  team_df_run team_dispatch_judge_anchor "$agent" "$id" "$taskfile" "$df_change" "$force"
  team_df_run team_dispatch_judge_deltas_shape "$id" "$taskfile"
  team_df_run team_dispatch_judge_delta_writer "$agent" "$id" "$taskfile" "$df_change" "$force"
  team_df_run team_dispatch_judge_verify_seat "$agent" "$id" "$taskfile" "$df_change" "$df_phase" "$force"

  # ④ 叠任务（resume / up --agents 也走这里：同一任务短路，那两扇门的语义不变）
  team_df_run team_dispatch_judge_stack "$agent" "$id" "$taskfile" "$force"

  # ⑤ 工作树存在 / 脏 / 分支身份（前提缺失时后面的判定说「判不了」，不冒充查过）
  local wt; wt="$(team_agent_worktree "$agent")"
  team_df_run team_dispatch_judge_worktree_present "$agent" "${br_name:-$(team_branch_for_agent "$agent" "$id")}"
  if [ "$_TEAM_DF_RUN_RC" -ne 0 ]; then
    team_df_say "  工作树不在 → 脏工作树与分支身份判不了（先按上面的修法建工作树）"
  else
    team_df_run team_dispatch_judge_worktree_dirty "$agent" "$id" "$wt"
    if [ "$br_decl_ok" = "1" ]; then
      team_df_run team_dispatch_judge_worktree_branch "$agent" "$id" "$wt" "$br_name" "$br_src"
    else
      team_df_say "  分支声明不合法 → 工作树的分支身份判不了（见上面那一项）"
    fi
  fi

  # ⑥ 启动前置（容量 / 模型并发 / 会话 vs 窗口 / agent 可执行文件）
  # M14：解析顺序 = --model 显式参数 ＞ 配置（TEAM_AGENT_MODELS 的 per-agent ＞ TEAM_DEFAULT_MODEL）。
  # 名册 state 里的 model 只是「上次用了什么」的展示记录（roster/ps 标注来源用），不再当默认来源 ——
  # 旧行为（state 优先）让配置改了也不生效：名册里的 deepseek 旧记录压过了新配的 k3-256k。
  local model_src="config"
  if [ -z "$model" ]; then model="$(team_agent_model "$agent")"; else model_src="explicit"; fi
  local provider="${model%%/*}"
  local sid="$TEAM_SESSION-$agent"
  [ "$fresh" = "1" ] && sid="$sid-$(date +%s)"

  team_df_run_lib team_dispatch_judge_mem "$agent" "$id" "$taskfile"
  # P144：磁盘/inode 腿 —— 判的是这个 worker 真正要写的两个文件系统（临时根 + 它的工作树，
  # 不是共享的 worktrees 根），在**任何开窗动作之前**（--print 也在内），并且是 P140 的启动前
  # 那一趟里的一个 finding（拒绝时和别的阻塞项一起交底，不抢自己的单独出口）。
  local disk_tmp="${TMPDIR:-/tmp}"
  team_df_run_lib team_disk_guard "$disk_tmp" "$wt"
  # 读数是一条「说明」（rc=0 的 finding）：放行时在启动前那一趟里打印；被拒时由拒绝本身带读数。
  if [ "$_TEAM_DF_RUN_RC" -eq 0 ]; then team_df_run_lib team_capacity_line "$disk_tmp" "$wt"; fi
  team_df_run_lib team_model_guard "$model"
  # M4.3 A：会话规模 vs 模型窗口（默认拒绝，--fresh / --allow-overflow 是出路）
  team_df_run_lib team_guard_resume_session "$agent" "$model" "$sid" "$wt" "$fresh" "$overflow" "$id" "$taskfile"
  # agent adapter：空配置 = 内置 Pi（老路径，报错文案也不变）；die 被捕获成阻塞项，不带走其他判定
  team_df_run_lib team_agent_check_launch
  if [ "$_TEAM_DF_RUN_RC" -eq 0 ]; then
    team_df_run team_dispatch_judge_agent_bin "$agent"
  else
    team_df_say "  adapter 配置不合法 → agent 可执行文件判不了（见上面那一项）"
  fi

  # ⑦ R6 席位预提示（⚠ 行；只有判得出来才打印，不阻断、不改退出码）
  team_df_run team_dispatch_judge_seat_hint "$agent" "$wt"

  # ⑧ 报告：一份拒绝（阻塞项 → 说明 → 计行）；通过才继续
  if ! team_df_report; then
    return 1
  fi

  # 报告通过：这时才允许写 state / 打计划 / 开窗
  # 必需依赖体检（D10）：缺依赖**不拒绝**派单（worker 照样能干活），但 PM 必须知道证据/spec 层是缺的。
  # 一行、每次派单只说一次。
  local dep_issues; dep_issues="$(team_required_dep_issues)"
  [ -n "$dep_issues" ] && team_warn "依赖缺失（不阻塞派单）：$(printf '%s' "$dep_issues" | tr '\n' '; ')"
  local agent_bin; agent_bin="$(team_agent_bin_path)"
  # W3：提示词必须写守卫**实际接受**的那条分支（工作树已属于本任务时就是它），并与 state 的
  # `branch=` 同源；解析名与来源照旧单独打印（R1 的可观测面不变）。
  local task_branch="${TEAM_CHECKED_BRANCH:-$br_name}" task_branch_src="$br_src"
  if [ -n "$task_branch" ] && [ "$task_branch" != "$br_name" ]; then
    task_branch_src="worktree (this task's other slug; resolved name $br_name via $br_src)"
  fi
  # P140：解析出的分支名与来源（--branch / 任务书 branch: 行 / 由标题推导）在开窗前可见；--print 同样有。
  team_info "  分支：$br_name（来源：$br_src）"
  [ -n "$task_branch" ] && [ "$task_branch" != "$br_name" ] \
    && team_info "  工作树实际分支：$task_branch（守卫接受的是它；提示词与 state 都按它写）"
  local prompt prompt_file agent_cmd inner
  prompt="$(team_build_prompt "$agent" "$id" "$taskfile" "$wt" "$model" "$sid" "$task_branch" "$task_branch_src")"
  # 提示词落盘：模板里的 {prompt_file} 用它，排查“到底派了什么”也看它（state/ 已 gitignore）
  prompt_file="$(team_agent_prompt_file "$agent" "$id")"
  mkdir -p "$TEAM_STATE_DIR"
  printf '%s\n' "$prompt" > "$prompt_file"
  agent_cmd="$(team_agent_launch_cmd "$agent" "$sid" "$wt" "$prompt_file" "$model")"

  # notify 模板坏掉时不阻塞派单，但必须说清楚（否则 worker 回合结束没人知道）；
  # 提示词那侧会用同一个判断把通知段换成「写进报告」（F8）。
  if [ -n "${TEAM_AGENT_NOTIFY_CMD:-}" ]; then
    local nre=""
    if ! nre="$(team_agent_notify_check)"; then
      team_warn "TEAM_AGENT_NOTIFY_CMD 看起来不可用：$(printf '%s' "$nre" | tr '\n' '; ')（提示词会把通知段换成「写进报告」）"
    fi
  fi

  if [ "$printonly" = "1" ]; then
    printf '=== agent 命令（adapter: %s）===\n' "$(team_agent_adapter_label)"
    # M40：身份环境单独一行（真窗口里它在 cd 之前执行；这里不许破 `^cd ` 的行契约）
    printf '身份环境（启动前先执行）：%s\n' "$(team_identity_env_prefix "$wt")"
    printf 'cd %q && %s\n' "$wt" "$agent_cmd"
    printf '   （命令里的 "$0" = 窗口 harness 以 argv[0] 传入的提示词；模板里写 {prompt} 就是它）\n'
    printf '   prompt file（模板里的 {prompt_file}）：%s\n' "$prompt_file"
    if [ -n "${TEAM_AGENT_NOTIFY_CMD:-}" ]; then
      local nfile; nfile="$(team_agent_summary_file "$agent" "$id")"
      printf '   回合结束通知（TEAM_AGENT_NOTIFY_CMD；worker 先把摘要写进 %s，再原样跑下面这条）：\n     %s\n' \
        "$nfile" "$(team_agent_notify_cmd "$agent" "$sid" "$wt" "$nfile")"
    fi
    printf '\n=== 提示词（%s 字） ===\n%s\n' "${#prompt}" "$prompt"
    return 0
  fi

  # F5：取字节的时点必须在 **worker 能跑之前**（这时同会话文件还是上一轮结束时的大小）。旧实现把它
  # 放在 respawn 之后 —— 新一轮已经写进去的字节被算成「上一轮的产出」，上一轮真算出东西的席位会被
  # 说成 0 bytes（假陈述）。读不到就记空：下一轮的零产出腿要求非空记录，空 = 沉默，不猜。
  local sid_bytes_at_launch=""
  sid_bytes_at_launch="$(team_session_bytes "$sid" "$wt" 2>/dev/null || true)"
  team_tmux_ensure_session
  # 启动 + 校验（M4.3 B）：最多两次（第一次没证据 → 杀窗口重试一次）。
  # 只有拿到**本轮 nonce** 的启动证据才算「发出去了」；失败则如实报告并杀掉窗口（不留半启动现场）。
  local marker exitfile nonce inner pid="" attempt=0 exit_code="" observed=0 tailfile
  marker="$(team_dispatch_spawn_file "$agent")"
  exitfile="$(team_dispatch_exit_file "$agent")"
  tailfile="$(team_dispatch_tail_file "$agent")"
  mkdir -p "$TEAM_STATE_DIR"
  while [ "$attempt" -lt 2 ] && [ -z "$pid" ]; do
    attempt=$((attempt + 1))
    if team_agent_window_exists "$agent"; then
      if [ "$attempt" = "1" ]; then
        # P55（遗体复用留证）：窗口还在但 pane 已死 = 上一轮死在里面 —— 先把现场落盘再替换
        # （那次事故「死因不明」的直接原因就是现场没了；探针 P6：kill-window 才真的带走遗体）。
        if team_agent_pane_dead "$agent"; then
          local corpse_f; corpse_f="$(team_agent_capture_corpse "$agent" 2>/dev/null || true)"
          team_warn "窗口 $TEAM_SESSION:$agent 已存在：上一个 pane 已死（$(team_agent_pane_evidence "$agent" 2>/dev/null || echo '证据缺失')）→ 替换${corpse_f:+（现场已存 $corpse_f）}"
        else
          team_warn "窗口 $TEAM_SESSION:$agent 已存在 → 替换（旧回合会被打断）"
        fi
      else team_dim "  （重试：窗口还在 → 先杀掉）"; fi
      team_tmux_kill_window "$TEAM_SESSION:$agent" >/dev/null 2>&1 || true
      sleep 0.5
    fi
    # 每轮换 nonce：证据必须来自这一轮的启动（上一轮留在盘上的不算数）
    nonce="$(date +%s)-$$-$RANDOM-$attempt"
    rm -f "$marker" "$exitfile" "$tailfile"
    # 命令里写死绝对路径 + 短暂等待（窗口 shell 可能刚起、PATH/rc 还没就绪）；
    # 拿到可执行文件后先写下 (nonce, pid)，再跑 agent —— 这一行就是「harness 真的执行了」的证据。
    # agent 返回后**立刻**把 (nonce, $?) 写进退出证据文件，然后才 exec 回 shell：
    # 证据属于「agent 退了」这个事件（M7.5），不依赖窗口回 shell 的快慢。
    # M8.2：退出那一刻再自抓一份尾屏（有界重试到非空白）—— CLI 退出后 shell 启动链可能清屏，
    # 事后再从外面 capture 也许只剩空屏（PM 侧 M8.1 实测过）；失败诊断靠它保留 CLI 自己的报错。
    inner="$(printf '%scd %q\nfor _i in 1 2 3 4 5 6 7 8 9 10; do [ -x %q ] && break; sleep 0.3; done\nprintf "%%s %%s\\n" %s %s > %q\nprintf "\\033[2mteamsmith agent:%s → %s\\033[0m\\n"\n%s\nprintf "%%s %%s\\n" %s "$?" > %q\nif [ -n "${TMUX_PANE:-}" ] && command -v tmux >/dev/null 2>&1; then _n=0; while [ "$_n" -lt 10 ]; do tmux capture-pane -p -t "$TMUX_PANE" -S -200 > %q 2>/dev/null; grep -q "[^[:space:]]" %q && break; _n=$((_n + 1)); sleep 0.1; done; fi\nexec bash' \
      "$(team_identity_env_prefix "$wt")" "$wt" "$agent_bin" "$(printf '%q' "$nonce")" '$$' "$marker" "$agent" "$id" "$agent_cmd" "$(printf '%q' "$nonce")" "$exitfile" "$(printf '%q' "$tailfile")" "$(printf '%q' "$tailfile")")"
    # P55（remain-on-exit 的时机是红线）：占位命令先持窗 → 设选项并读回 → 才把 pane 交给 harness。
    # 顺序不能反：harness 先跑时它若秒退，窗口在设选项之前就没了（探针 P1/P3 = 2026-09-22 事故形状）。
    # respawn-pane 用 argv 形式（不经 shell 解析）：harness 原样保留「bash -lc $inner $prompt-as-$0」。
    tmux new-window -t "$TEAM_SESSION" -n "$agent" -d 'sleep 30' >/dev/null 2>&1 || true
    if team_agent_window_exists "$agent"; then
      tmux set-window-option -t "$TEAM_SESSION:$agent" remain-on-exit on >/dev/null 2>&1 || true
      local roe; roe="$(tmux show-options -w -v -t "$TEAM_SESSION:$agent" remain-on-exit 2>/dev/null || true)"
      if [ "$roe" = "on" ]; then
        tmux respawn-pane -k -t "$TEAM_SESSION:$agent" bash -lc "$inner" "$prompt" >/dev/null 2>&1 || true
      else
        # 读回失败 = 这一轮的启动作废：窗口留给下一轮的重用分支杀（没有下一轮则由失败路径杀），
        # 绝不 return —— 否则「重试一次 + 失败诊断」的既有契约会被这条新守卫短路。
        team_err "窗口 $TEAM_SESSION:$agent 的 remain-on-exit 没设上（读回是 ${roe:-空}）：不留遗体的窗口不派单，本轮作废"
      fi
    fi
    pid="$(team_wait_launch_proof "$agent" "$nonce" 2>/dev/null || true)"
    # 额外观察（不复报成功就完事）：启动证据拿到后，agent 可能立刻退出（可执行文件/模型/provider 起不来）。
    # M8.2：**adapter 路径也看这条事件** —— 裸名字解析失败（exit 127）时 harness 确实跑了，
    # 但 agent 没跑起来；旧实现只给内置 Pi 路径一句提醒，adapter 连提醒都没有（派单照样 ✓）。
    if [ -n "$pid" ]; then
      local alive_sec="${TEAM_DISPATCH_ALIVE_SEC:-1}"
      case "$alive_sec" in ''|*[!0-9]*) alive_sec=1 ;; esac
      # 等的是「agent 进程返回」这条事件（上一条证据行），不是「看一眼 pane 忙不忙」的采样；
      # ALIVE_SEC 现在= 最多等它多久（0 = 不等，直接按「还在跑」报）。
      [ "$alive_sec" -gt 0 ] && exit_code="$(team_wait_agent_exit "$agent" "$nonce" "$alive_sec" 2>/dev/null || true)"
      observed=1
    fi
  done
  if [ -z "$pid" ]; then
    team_err "派单已发出但未能确认启动：${TEAM_DISPATCH_VERIFY_SEC:-8} s 内没等到窗口里的启动证据（$marker 里没有本轮 nonce）"
    # 终态必须已知且是真的：把残留窗口真的杀掉（不是只在文案里说「已杀掉」——
    # 「状态即承诺」同样适用于失败路径）。
    if team_agent_window_exists "$agent"; then
      team_tmux_kill_window "$TEAM_SESSION:$agent" >/dev/null 2>&1 || true
      team_warn "已重试 1 次，并把窗口 $TEAM_SESSION:$agent 杀掉：不留半启动的现场（roster 会显示「无窗口」）"
    else
      team_warn "已重试 1 次；没有留下半启动的窗口（roster 会显示「无窗口」）"
    fi
    team_dim "  排查：tmux 里手动跑一次 —— cd $wt 然后跑 dispatch --print 打出的那条命令；看 agent 自己的报错"
    team_dim "  常见原因：可执行文件/模型/provider 不可用；旧会话楔死（换新会话：--fresh）；内存/磁盘不足"
    team_dim "  重派：$TEAM_CLI dispatch $agent $id $taskfile --fresh"
    return 1
  fi

  # 「harness 起来了」≠「agent 跑起来了」（M8.2）：自定义 adapter 立刻以非 0 退出就是派单失败。
  # 为什么只对 adapter 严格：内置 Pi 路径的契约允许启动用例指向短命 CLI（M4.3 B3：假 pi `exit 3`
  # 仍算派单成立，只如实提醒退出码）；而 adapter 模板跑的就是**要干活的 CLI**，它秒退非 0
  # 只能意味着没跑起来（裸名字 127、参数错、CLI 自己拒绝启动）。
  # 为什么秒退但 0 不算失败：脚本型 adapter 干完活就退是正常的（下面如实说出来，不假装它还在跑）。
  if [ -n "$pid" ] && [ -n "${TEAM_AGENT_CMD:-}" ] && [ -n "$exit_code" ] && [ "$exit_code" != "0" ]; then
    local diag
    diag="$(team_dispatch_launch_diag "$agent" "$id" "$agent_cmd" "$agent_bin" "$exit_code")"
    team_err "派单失败：harness 起来了，但 agent 立刻退出了（exit=$exit_code）—— agent 没跑起来"
    team_dim "  不写任务/分支记录（roster 不会显示它接过这个任务）；窗口保留，CLI 自己的报错还在屏幕上"
    team_err "  诊断（窗口尾屏 + 渲染出的命令 + 解析到的可执行文件）已写入：$diag"
    team_dim "  手工复现：cd $(printf '%q' "$wt") && $agent_cmd"
    team_dim "  常见原因：首词不在窗口（登录 bash）的 PATH 里（现在会被解析成绝对路径，除非 TEAM_AGENT_BIN 指向别的名字）；CLI 参数/认证被拒"
    team_dim "  重派：$TEAM_CLI dispatch $agent $id $taskfile"
    return 1
  fi

  team_state_set "$agent" model "$model"
  team_state_set "$agent" model_src "$model_src"
  team_state_set "$agent" window "$agent"
  team_state_set "$agent" worktree "$wt"
  team_state_set "$agent" task "$id"
  team_state_set "$agent" taskfile "$taskfile"
  [ -n "$task_branch" ] && team_state_set "$agent" branch "$task_branch"
  team_state_set "$agent" started "$(team_timestamp)"
  # P140（R6）/ P151（F5）：记下这一轮的会话 id 与**启动时**（worker 能跑之前）的会话文件字节数
  # —— 下一轮据此判「一个字节没长」。只在派单真的成功之后才落盘。
  team_state_set "$agent" sid "$sid"
  team_state_set "$agent" sid_bytes "$sid_bytes_at_launch"
  team_board_set "$id" wip 2>/dev/null || true

  # M9.3：`--force` 接管了另一个没结束的任务 —— 审计里留一条（输出里已经写明，这里落盘）
  if [ -n "${TEAM_DISPATCH_STACK_PREV:-}" ]; then
    team_wlog "dispatch $agent: 显式覆盖叠任务（${TEAM_DISPATCH_STACK_PREV} 让位给 $id）"
  fi
  # P23：change 守卫的 --force 覆盖（规则 B/2/3）逐条落盘（每处一行；输出里已经写明）
  if [ -n "${TEAM_DISPATCH_AUDIT_LINES:-}" ]; then
    while IFS= read -r _p23line; do
      [ -n "$_p23line" ] && team_wlog "$_p23line"
    done <<< "$TEAM_DISPATCH_AUDIT_LINES"
    TEAM_DISPATCH_AUDIT_LINES=""
  fi
  team_ok "dispatched $id → $TEAM_SESSION:$agent（含启动校验：proof=spawn pid=$pid；provider=$provider model=${model#*/} session=$sid）"
  # 观察结论也要说出来（不是只报“成功”）：内建 Pi 路径下，agent 是「已经退出」还是「还在跑」，
  # PM 都要拿到**观察到的事实**（退出码来自窗口 harness 写下的事件证据，不是猜的；也不再假设
  # 「窗口一定已经回到 shell」——那正是 M7.5 里被环境 churn 打脸的那句话）。
  if [ "$observed" = "1" ]; then
    if [ -n "$exit_code" ]; then
      if [ -n "${TEAM_AGENT_CMD:-}" ]; then
        # adapter 秒退但 0：脚本型 CLI 干完活就退是正常的 —— 如实说出来（不假装它还在跑，也不算失败）
        team_dim "  窗口里的 agent 已经跑完并退出（exit code 0）：$TEAM_CLI roster 会显示「$(team_agent_cli_name) 已退出」"
      else
        team_warn "但窗口里的 agent 已经退出（exit code $exit_code）：$TEAM_CLI roster 会显示「$(team_agent_cli_name) 已退出」（续跑：$TEAM_CLI resume --agent $agent）"
      fi
    else
      team_dim "  窗口里的 agent 还在跑（${TEAM_DISPATCH_ALIVE_SEC:-1}s 内没等到退出证据）"
    fi
  fi
  team_dim "  旁观：tmux attach -t $TEAM_SESSION ｜ 追问：$TEAM_CLI say $agent \"...\""
}

team_pane_snapshot() { # <target> → pane 内容指纹（用于确认投递真的落到 TUI）
  team_tmux_target_required "capture-pane" "${1:-}" || return 1
  tmux capture-pane -p -t "$1" 2>/dev/null | tail -c 400 | cksum | tr -d ' \n'
}

# agent 没在跑时：消息仍然要落到收件箱（durable），但绝不打字（空提示符会当命令执行）
team_say_offline() { # <agent> <msg> <原因>
  local agent="$1" msg="$2" why="$3"
  team_inbox_append "$agent" pm "（PM 消息，agent 未在跑：$why）$msg"
  team_warn "say: $agent 没在跑（$why）—— 消息已落收件箱（$TEAM_DOCS_DIR/inbox/$agent.md）"
  team_dim "  他起来后（或 $TEAM_CLI resume --agent $agent 续跑后）会读到；要立刻投递先让他跑起来"
  return 0
}

# 收件人必须是名册里的 agent，或者特殊收件人 pm（PM 自己的收件箱）。
# 为什么：say devv 会把消息写进 inbox/devv.md，而那个名字从来没窗口、没人读 ——
# 打错一个字母就等于消息静默蒸发（M6.3 F18）。--any 是显式越权：允许，但必须留痕。
team_require_recipient() { # <recipient> <是否 --any> <命令名>
  local r="$1" any="${2:-0}" what="${3:-say}"
  [ -n "$r" ] || return 0
  [ "$r" = "pm" ] && return 0
  team_agent_known "$r" && return 0
  if [ "$any" = "1" ]; then
    printf '%s %s -> %s（非名册收件人，--any 强制）\n' "$(team_timestamp)" "$what" "$r" >> "$(team_state_dir)/inbox-unknown.log"
    team_warn "$what：$r 不在名册里 —— --any 已按要求投递，并记入 state/inbox-unknown.log"
    return 0
  fi
  team_err "$what：收件人 '$r' 不在名册里（没有它的窗口，也没有人会读它的收件箱 → 消息会变成死信）"
  team_dim "  名册：$(team_agents | tr '\n' ' ')｜ PM 自己的收件箱：pm" >&2
  team_dim "  确认要投给这个名字：$TEAM_CLI $what $r --any \"...\"（越权投递会记进 state/inbox-unknown.log）" >&2
  return 1
}

team_cmd_say() {
  local agent="" msg="" verify=1 any=0 now=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --no-verify) verify=0; shift ;;
      --any) any=1; shift ;;
      --now) now=1; shift ;;
      -*) team_usage_die "say: 未知参数 $1" ;;
      *) if [ -z "$agent" ]; then agent="$1"; elif [ -z "$msg" ]; then msg="$1"; else msg="$msg $1"; fi; shift ;;
    esac
  done
  [ -n "$agent" ] && [ -n "$msg" ] || team_usage_die "say <agent> <单行消息> [--no-verify] [--any] [--now]"
  case "$msg" in *$'\n'*) team_die "say 只能发单行：多行请写进文件，然后让 agent 去读" ;; esac
  team_require_recipient "$agent" "$any" say || return 1
  local w; w="$(team_state_get "$agent" window "$agent")"
  local target="$TEAM_SESSION:$w"
  # M30 · pi 通道不经过 tmux：有活的收件箱监视器（inbox-watch 扩展）时，窗口/pane 的检查都不必要
  # —— 「pi 通道零 tmux 调用」是 M30 的验收判据之一（消息写 durable 收件箱 + spool，由扩展唤醒）。
  if ! team_inbox_watch_route "$target" >/dev/null 2>&1; then
    team_tmux_has_window "$TEAM_SESSION" "$w" \
      || { team_say_offline "$agent" "$msg" "窗口 $TEAM_SESSION:$w 不在"; return 0; }
    # P55（投递换道）：死 pane 不是投递目标 —— send-keys 返回 0 但文字落进虚空（探针 P5），
    # 「提示框非空确认送达」永远等不到（画面不再变）。消息走收件箱，输出点名座位已死与退出证据。
    if team_agent_pane_dead "$agent"; then
      local ev; ev="$(team_agent_pane_evidence "$agent" 2>/dev/null || echo '证据未知')"
      team_inbox_append "$agent" pm "（PM 消息，座位已死：$ev）$msg"
      team_warn "say: $agent 的 pane 已死（$ev）—— 没有按任何键；消息已落 $TEAM_DOCS_DIR/inbox/$agent.md"
      team_dim "  现场：$TEAM_CLI status <ID>（或 tmux capture-pane -p -S - -t $target）；恢复：$TEAM_CLI resume --agent $agent（会先抓现场再替换遗体）"
      return 0
    fi
    # 安全：空提示符时把消息 send-keys 进去会被 shell 当命令执行
    if team_is_shell_cmd "$(team_pane_cmd "$TEAM_SESSION:$w")" && ! team_pane_busy "$TEAM_SESSION:$w"; then
      team_say_offline "$agent" "$msg" "$(team_agent_cli_name) 已退出（空提示符）"
      return 0
    fi
  fi

  # 投递一律走守卫（delivery-guard）：输入框里有草稿 → 不写一个键，消息进 state/outbox/ 排队。
  # --now 是人的显式逃生门（故意重建旧行为，留审计）；--no-verify 保留旧语义。
  local sargs=()
  [ "$verify" = "1" ] || sargs+=(--no-verify)
  [ "$now" = "1" ] && sargs+=(--now)
  team_send_guarded "$target" "$msg" say --from pm --inbox "$agent" ${sargs[@]+"${sargs[@]}"}
  case "$TEAM_SEND_OUTCOME" in
    delivered)
      team_ok "said to $target: $msg（已确认送达）"
      return 0 ;;
    watched)
      # M30 · pi 监视通道：durable 收件箱行已写，spool 指针已落；会话里的扩展读到就唤醒
      team_ok "said to $target: $msg（pi 监视通道：已写收件箱 $TEAM_DOCS_DIR/inbox/$agent.md + 唤醒指针；输入框零按键）"
      return 0 ;;
    queued)
      # 契约：排队 ≠ 送达 —— 输出里只许有 queued，绝不能写「已确认送达」
      team_ok "queued for $target: $msg（目标输入框里有草稿：没有写任何键；条目已入 state/outbox/，清空后自动投递）"
      team_dim "  原因/条目：$TEAM_CLI outbox list ｜ 投递未确认的兜底：消息已在 $TEAM_DOCS_DIR/inbox/$agent.md"
      return 0 ;;
    held)
      # delivery-truth D1/D2：geometry-untrusted / queue-stalled —— 一个键都没发，报 held + 原因 +
      # durable 条目 + 恢复命令并非零退出（“退出 0 + 永不兑现的承诺”就是本 change 要消灭的假绿）。
      team_err "held for $target: $msg（reason=${TEAM_SEND_REASON:--}：目标框的几何/进展无法可信确认，没有写任何键）"
      team_dim "  条目：$(basename "${TEAM_SEND_ENTRY:--}")｜durable 全文：$(team_outbox_durable_path "${TEAM_SEND_ENTRY:--}" 2>/dev/null || printf '%s' -)（payload 与条目头未改）｜原因：$TEAM_CLI outbox list ｜恢复：$(team_outbox_recovery_hint "${TEAM_SEND_REASON:--}")"
      return 1 ;;
    forced)
      team_ok "said to $target: $msg（--now：跳过守卫直投，记入 outbox/forced.log）"
      return 0 ;;
    unknown-sent)
      team_ok "said to $target: $msg（输入框形状未知：按旧行为投递）"
      return 0 ;;
    unknown-failed)
      team_inbox_append "$agent" pm "（PM 消息，投递未确认）$msg"
      team_err "投递未确认：$target（输入框形状未知且 pane 无变化；消息已写入收件箱 $TEAM_DOCS_DIR/inbox/$agent.md）"
      return 1 ;;
    *)
      team_say_offline "$agent" "$msg" "$(team_agent_cli_name) 已退出（空提示符）"
      return 0 ;;
  esac
}

team_inbox_append() { # <agent> <tag> <msg> [<sender>]
  local dir; dir="$(team_inbox_dir)"
  mkdir -p "$dir"
  # P82：第 4 参可选 = **发送者**（notify 传解析出来的发送者，收件人只当文件名）；
  # say/draft/pulse 不传，沿用「owner 标签」（它们另有 --from/标签语义，本次不动）。
  printf -- '- %s [%s] agent:%s · %s\n' "$(team_timestamp)" "$2" "${4:-$1}" "$3" >> "$dir/$1.md"
}

# notify 的去重键：内容 + 长度（同一份通知在 TEAM_NOTIFY_DEDUP_SEC 内只入队/投递一次）。
# 扩展走的是它自己的键（<agent>|<tag>|<summary>|<len>:<hash>），两边都进同一个队列条目。
team_notify_dedup_key() { # <agent> <msg>
  local len sum
  len="$(printf '%s' "$2" | wc -c | tr -d ' ')"
  sum="$(printf '%s' "$2" | cksum | awk '{print $1}')"
  printf 'notify|%s|%s:%s\n' "$1" "$len" "$sum"
}

# P160 F3 · 任务标识的证据：<ID> 必须在 state/<sender>.env 的 task=、看板行或任务书里真的存在。
#   席位名（agent/<席位> 这类分支的后缀）不是任务 —— 没有证据就什么都不盖（不编造）。
team_notify_task_proven() { # <sender> <id> → 0 = 这个 ID 有任务证据
  local sender="$1" id="$2" cur=""
  [ -n "$id" ] || return 1
  cur="$(team_state_get "$sender" task '' 2>/dev/null || true)"
  if [ -n "$cur" ] && [ "$cur" = "$id" ]; then return 0; fi
  if team_board_has "$id"; then return 0; fi
  if [ -n "$(team_task_briefs "$id")" ]; then return 0; fi
  return 1
}

# R2/P160 · 发送方工作树里的修订标识（<ID> 取自分支，tip 取自 HEAD）：
#   只有**能证明**是任务分支才盖：分支形如 task/<ID>-…（agent/* 与其它分支没有任务语义，一律不盖），
#   且 <ID> 在 state/<sender>.env 的 task=、看板行或任务书里存在；推不出来就什么都不写。
#   绝不编造：工作树外的手工 notify 没有标识，不是「按收件人猜一个」。
#   P160 F2：tip = HEAD 的**前 12 个十六进制字符**，工具自己截 —— 不用 `--short`（它服从 core.abbrev
#   与对象数，同一 HEAD 会在 CLI 与扩展两处盖出不同拼写）。接收方不需要 checkout：reviews/<ID>.md 里记的
#   HEAD 与 tip **互为前缀**（两边指向同一个 revision）就算这个修订已经判过（`team review` 今天写 9 位，
#   12 位的 wire 形状让这个判定不受 Git 设置影响），见 references/protocol.md 与 change 的 notify-and-inbox 规格。
team_notify_rev_stamp() { # <sender> → "task=<ID> tip=<12-hex>" | 空
  local sender="${1:-}" wt="" branch="" task="" id="" tip=""
  case "$sender" in
    ""|-) return 0 ;;
    pm) wt="$TEAM_MAIN_ROOT" ;;
    *) wt="$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR/$sender" ;;
  esac
  [ -d "$wt" ] || return 0
  branch="$(team_worktree_branch "$wt" 2>/dev/null || true)"
  case "$branch" in
    task/*) ;;
    *) return 0 ;;
  esac
  task="${branch#task/}"
  id="${task%%-*}"
  team_notify_task_proven "$sender" "$id" || return 0
  tip="$(git -C "$wt" rev-parse HEAD 2>/dev/null | cut -c1-12 || true)"
  [ -n "$id" ] && [ -n "$tip" ] && printf 'task=%s tip=%s\n' "$id" "$tip"
  return 0
}

team_cmd_notify() {
  local from_file="" msg="" agent="" any=0 claim="" claim_set=0 have_msg=0
  # P82：--from <名字> 是**发送者**的显式声明（收件人永远只是收件人）。参数顺序自由，
  # 其余位置参数拼成摘要（保持「notify <收件人> <单行消息>」的老形状）。
  while [ $# -gt 0 ]; do
    case "$1" in
      --any) any=1; shift ;;
      --from) [ $# -ge 2 ] || team_usage_die "notify --from 需要发送者名字"; claim="$2"; claim_set=1; shift 2 ;;
      --from=*) claim="${1#*=}"; claim_set=1; shift ;;
      --from-file) [ $# -ge 2 ] || team_usage_die "notify --from-file 需要摘要文件路径"; from_file="$2"; shift 2 ;;
      --from-file=*) from_file="${1#*=}"; shift ;;
      -*) team_usage_die "notify: 未知参数 $1" ;;
      *) if [ -z "$agent" ]; then agent="$1"; else msg="${msg:+$msg }$1"; have_msg=1; fi; shift ;;
    esac
  done
  [ -n "$agent" ] || team_usage_die "notify <agent> <单行消息> | notify <agent> --from-file <摘要文件> [--from <发送者>]"
  # 名字是一个词（席位名/目录名）：空白/换行会把 `agent:<名字> ·` 这行弄成两行（账本行的形状要守得住）
  if [ "$claim_set" = "1" ]; then
    case "$claim" in
      "") team_usage_die "notify --from 的发送者名字不能为空" ;;
      *[[:space:]]*) team_usage_die "notify --from 的发送者名字里有空白（'$claim'）：名字是一个词，摘要请走 --from-file" ;;
    esac
  fi
  # 摘要只有一个来源：位置文本与 --from-file 同时给 = 含糊输入，拒绝（不静默挑一个）
  if [ -n "$from_file" ] && [ "$have_msg" = "1" ]; then
    team_usage_die "notify：位置摘要与 --from-file 不能同时给（摘要只有一个来源，请二选一）"
  fi
  # 发送者先解析（fail closed）：未解析就在这里停住 —— 收件箱行、knock、outbox 条目一个都不写。
  local sender; sender="$(team_sender_resolve "$claim")" || return 1
  [ -n "$sender" ] || return 1
  # 摘要始终是**数据**：--from-file 从文件读（worker 的文本不经过 shell）；两种路径都归一化成单行，
  # 但除换行/回车/尾部空白外**逐字节保留**（引号、$、反引号、{} 都原样进收件箱）。
  if [ -n "$from_file" ]; then
    [ -f "$from_file" ] || team_die "notify --from-file：文件不存在（$from_file）——worker 要先把摘要写进去"
    msg="$(team_one_line "$(cat "$from_file")")"
  else
    [ "$have_msg" = "1" ] || team_usage_die "notify <agent> <单行消息> | notify <agent> --from-file <摘要文件> [--from <发送者>]"
    msg="$(team_one_line "$msg")"
  fi
  if [ -z "$(team_trim "$msg")" ]; then
    if [ -n "$from_file" ]; then team_die "notify --from-file：摘要文件是空的（$from_file）"
    else team_die "notify：摘要不能为空（收到空参数；如果用 \"\$(cat <摘要文件>)\" 取摘要，先确认那个文件写好且非空）"; fi
  fi
  team_require_recipient "$agent" "$any" notify || return 1
  # R2：能证明就带修订标识（inbox 行与 knock 载荷同一个后缀；摘要本身逐字节不变）
  local stamp="" revsuffix=""
  stamp="$(team_notify_rev_stamp "$sender")"
  [ -n "$stamp" ] && revsuffix=" · $stamp"
  local knock_payload="[manual] agent:$sender · $msg$revsuffix"
  # P82：发送者进 durable 收件箱行（第 4 参），收件人仍是文件名
  # delivery-truth D3（P147）：durable 写入是**声明的前提** —— 写不进去就在这里非零退出，
  # 不敲门、不写任何 inbox-written 声明（否则 wake 会指向一个不存在的文件）。
  team_inbox_append "$agent" manual "$msg$revsuffix" "$sender" || {
    team_err "notify：收件箱行写不进去（$TEAM_DOCS_DIR/inbox/$agent.md）—— 不敲门、不声明已写（退出非零）"
    return 1
  }
  local target="$TEAM_SESSION:$TEAM_PM_WINDOW"
  local knock_rc=0
  # M30 · pi 通道优先：目标有**活的**收件箱监视器时，敲门交给它（注册里的 pid+cwd 就是「PM 会话活着」
  # 的证据，比 tmux/pane 启发式直接），而且这条链不需要 tmux、不碰输入框。
  # delivery-truth D3：--inbox-written <recipient> = 上面写的就是收件人的 durable 文件；wake 的
  # 全文路径必须指同它（旧实现写死 pm → 收件人 dev 时 wake 指向不存在的 pm.md）。
  if [ "$TEAM_NOTIFY_TMUX" = "1" ] && team_inbox_watch_route "$target" >/dev/null 2>&1; then
    team_send_guarded "$target" "$knock_payload" knock --from "$sender" \
      --dedup "$(team_notify_dedup_key "$agent" "$msg$revsuffix")" --inbox-written "$agent"
    case "$TEAM_SEND_OUTCOME" in
      watched) team_dim "  pi 监视通道：收件箱已写，会话里的监视扩展负责唤醒（输入框零按键）" ;;
      queued)  team_dim "  pi 监视通道投递没落地（条目入队）：$TEAM_CLI outbox list" ;;
      held)    knock_rc=1; team_warn "  敲门被阻碍（reason=${TEAM_SEND_REASON:--}）：held/，唤醒未发；消息仍在 docs/team/inbox/$agent.md" ;;
      duplicate) team_dim "  duplicate：同一份通知在 ${TEAM_NOTIFY_DEDUP_SEC:-20}s 内已经投过（没有重复入队）" ;;
      offline|unknown-failed) team_warn "敲门没落地（pi 通道写不进去）：消息只落收件箱" ;;
    esac
  elif [ "$TEAM_NOTIFY_TMUX" = "1" ] && team_have_cmd tmux && [ -n "${TMUX:-}" ] \
     && team_pm_alive; then
    # 只给「正在跑 pi 的 PM」打字：PM 没在跑时写进 shell 会被当命令执行。
    # 敲门也走投递守卫：输入框里有草稿 → 入队，草稿不动（规格 notify-and-inbox 的 dirty-PM 场景）
    team_send_guarded "$target" "$knock_payload" knock --from "$sender" \
      --dedup "$(team_notify_dedup_key "$agent" "$msg$revsuffix")" --inbox-written "$agent"
    case "$TEAM_SEND_OUTCOME" in
      queued) team_dim "  PM 输入框里有草稿：敲门入队（$TEAM_CLI outbox list），清空后自动投递" ;;
      held)   knock_rc=1; team_warn "  敲门被阻碍（reason=${TEAM_SEND_REASON:--}）：held/，唤醒未发；消息仍在 docs/team/inbox/$agent.md" ;;
      duplicate) team_dim "  duplicate：同一份通知在 ${TEAM_NOTIFY_DEDUP_SEC:-20}s 内已经投过（没有重复入队）" ;;
      offline|unknown-failed) team_warn "敲门没落地（PM 窗口不可投）：消息只落收件箱" ;;
    esac
  elif [ "$TEAM_NOTIFY_TMUX" = "1" ] && [ -n "${TMUX:-}" ] && team_have_cmd tmux && ! team_pm_alive; then
    team_warn "PM 不在运行：消息只落收件箱（pulse 会把 PM 拉起后读到）"
  elif [ "$TEAM_NOTIFY_TMUX" = "1" ] && { [ -z "${TMUX:-}" ] || ! team_have_cmd tmux; }; then
    # V7-F6：敲门依赖 TMUX 环境变量——不设就静默整条跳过是不行的；明说，收件箱记录不受影响
    team_warn "不在 tmux 会话里（TMUX 未设置）：敲门不试、不入队，消息只落收件箱"
  fi
  team_ok "notified pm: $msg"
  return "$knock_rc"
}

team_cmd_teardown() {
  local agent="" all=0 purge=0 force=0 register=0 fp=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --agent) agent="${2:?}"; shift 2 ;;
      --all) all=1; shift ;;
      --purge) purge=1; shift ;;
      --force) force=1; shift ;;
      --register) register=1; shift ;;
      --fingerprint) fp="${2:?--fingerprint 需要 sha256}"; shift 2 ;;
      --fingerprint=*) fp="${1#*=}"; shift ;;
      *) team_usage_die "teardown: 未知参数 $1" ;;
    esac
  done
  if [ "$register" = "1" ] && [ "$all" = "1" ]; then
    team_usage_die "teardown: --all 不能和 --register 一起用（一次只从名册移除一个席位）"
  fi
  local targets=()
  if [ "$all" = "1" ]; then mapfile -t targets < <(team_agents); else
    [ -n "$agent" ] || team_usage_die "teardown --agent <a> | --all [--purge] [--force]"
    targets=("$agent")
  fi
  # P99/R2：--register 先缩名册（审计写入器），再走今天的窗口/state/worktree 清理；
  # 名册里没有这个席位就 exit 5、什么都不动。不带旗标时名册逐字节不变（今天的行为是默认）。
  if [ "$register" = "1" ]; then
    local rrc=0
    team_config_write_roster remove "$agent" "$fp" 0 || rrc=$?
    [ "$rrc" -eq 0 ] || return "$rrc"
  fi
  local a w wt
  for a in "${targets[@]}"; do
    w="$(team_state_get "$a" window "$a")"
    if team_tmux_has_window "$TEAM_SESSION" "$w"; then
      tmux kill-window -t "$TEAM_SESSION:$w" 2>/dev/null && team_ok "kill window $TEAM_SESSION:$w"
    fi
    team_state_clear "$a"
    if [ "$purge" = "1" ]; then
      wt="$(team_agent_worktree "$a")"
      if [ -d "$wt" ]; then
        if [ "$force" != "1" ] && [ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]; then
          team_warn "worktree 有未提交改动，保留：$wt（要强删：--force）"
          continue
        fi
        team_git worktree remove --force "$wt" 2>/dev/null && team_ok "remove worktree $wt" || team_warn "worktree 删除失败：$wt"
        team_scan_invalidate git   # M50
      fi
    fi
  done
  [ "$purge" != "1" ] && team_dim "worktree 仍保留（加 --purge 删除）；分支保留，需要时 git branch -d"
  return 0
}
