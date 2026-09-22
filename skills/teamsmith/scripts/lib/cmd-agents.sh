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
  piargs=(--provider "$provider" --model "${model##*/}")
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
team_build_prompt() { # <agent> <ID> <taskfile-abs> <worktree> <model> [<session_id>]
  local agent="$1" id="$2" taskfile="$3" wt="$4" model="$5" sid="${6:-$TEAM_SESSION-$1}"
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
\`$wt\`; run every command there. **Do not** touch the main worktree ($TEAM_MAIN_ROOT) and **do not** switch to main or
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
  while [ $# -gt 0 ]; do
    case "$1" in
      --no-install) extra+=(--no-install); shift ;;
      --create) extra+=(--create); shift ;;          # 明确要求代建 worktree（默认只打印 git 命令）
      --print-only|--print) extra+=(--print-only); shift ;;
      -*) team_usage_die "add-agent: 未知参数 $1" ;;
      *) [ -z "$agent" ] || team_usage_die "add-agent: 多余参数 $1"
         agent="$1"; shift ;;
    esac
  done
  [ -n "$agent" ] || team_usage_die "add-agent <agent> [--create] [--no-install]"
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

# 让 agent worktree 处于「本任务的分支」上：
#   task 模式  → task/<ID>-<slug>（不存在就从保护分支新建）
#   agent 模式 → agent/<name>（长期分支）
# 有未提交改动时拒绝切换（否则会把上一个任务的活混进来）
# 分支归 PM：skill 只**检查**工作树是否处在可开工的状态，并给出该跑的 git 命令。
# 旧行为（自动 switch -c task/<ID>）已删除——git 写操作由 PM 直接执行。
team_check_worktree_for_task() { # <agent> <ID>
  local agent="$1" id="$2" wt cur dirty want prev_task
  wt="$(team_agent_worktree "$agent")"
  want="$(team_branch_for_agent "$agent" "$id")"
  cur="$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
  dirty="$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  prev_task="$(team_state_get "$agent" task '')"
  if [ "$dirty" -gt 0 ] 2>/dev/null; then
    # 同一个任务的「断点续跑」允许脏工作区：那些改动正是它没提交完的活。
    # 只有「换任务」（新的 ID）才要求先收尾，避免把上个任务的半成品带进新任务。
    if [ "$prev_task" = "$id" ]; then
      team_dim "  断点续跑：$wt 有 $dirty 个未提交改动，属于本任务（$id），允许继续"
    else
      team_err "$wt 有 $dirty 个未提交改动（属于上一个任务 ${prev_task:-?}）：先收尾（提交或丢弃），再派新任务"
      git -C "$wt" status --short | head -8 >&2
      team_dim "  想直接续跑同一个任务：$TEAM_CLI resume --agent $agent（或 dispatch 同一个 ID）" >&2
      team_dim "  （git 归 PM：skill 不替你 stash/commit）" >&2
      return 1
    fi
  fi
  case "$cur" in
    "$TEAM_PROTECTED_BRANCH")
      team_warn "$agent 的工作树还在 $TEAM_PROTECTED_BRANCH 上：PM 该先建分支再派单"
      team_dim "$(printf '  git -C %q switch -c %q %q' "$wt" "$want" "$TEAM_PROTECTED_BRANCH")"
      return 1 ;;
    HEAD)
      if [ -n "$want" ]; then
        team_warn "$agent 的工作树是 detached HEAD：先切到任务分支"
        team_dim "$(printf '  git -C %q switch -c %q %q' "$wt" "$want" "$TEAM_PROTECTED_BRANCH")"
        return 1
      fi ;;
  esac
  # M6.3 F16：工作树必须停在**这个任务**的分支上。
  # 只看「脏不脏 / 保护分支 / detached」会放过停在 task/P2-smoke 的工作树：派 P1 直接成功，
  # state 把 P2 的分支记成 P1 的复验目标，随后 review P1 在 P2 的提交上盖章。
  if [ -n "$want" ] && [ "$cur" != "$want" ]; then
    if [ "$prev_task" = "$id" ] && team_branch_is_for_task "$cur" "$agent" "$id"; then
      # 同一个任务的续跑：slug 可能因为标题改过而不一致，分支确实属于本任务，放行。
      team_dim "  续跑：$wt 的分支 $cur 属于本任务（$id；规范名 $want），继续"
    else
      team_err "$wt 停在不属于本任务（$id）的分支上："
      team_err "  现在的分支：$cur ｜ 本任务要的分支：$want"
      if git -C "$wt" show-ref --verify --quiet "refs/heads/$want"; then
        team_dim "$(printf '  切过去：git -C %q switch %q' "$wt" "$want")" >&2
      else
        team_dim "$(printf '  建好并切过去：git -C %q switch -c %q %q' "$wt" "$want" "$TEAM_PROTECTED_BRANCH")" >&2
      fi
      team_dim "  （拒绝的理由：复验/交付记录会以工作树的分支为证据，不能张冠李戴）" >&2
      return 1
    fi
  fi
  TEAM_CHECKED_BRANCH="$cur"
  return 0
}

# ---------------------------------------------------------------- 派单前的会话规模守卫（M4.3 A）
# 复用大会话 + 小窗口模型 = 必然 wedge（现场见 DECISIONS D9 事件 A：361k tok 的会话配 272k 窗口的模型
# → 立刻 Context full / 连接错误循环，而 roster 仍显示「pi 在跑」）。
# 默认**拒绝**并给出 --fresh；确实要复用（例如换成窗口更大的模型）时用 --allow-overflow 显式放行。
# 口径写入消息：token ≈ 会话 JSONL 字节 / 4（粗糙）；窗口解析不到时明说用的是保守阈值。
team_guard_resume_session() { # <agent> <model> <sid> <worktree> <fresh> <allow-overflow>
  local agent="$1" model="$2" sid="$3" wt="$4" fresh="${5:-0}" allow="${6:-0}"
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
  team_dim "  两条出路：" >&2
  team_dim "    · 换新会话（推荐；旧历史仍在原文件里）：$TEAM_CLI dispatch $agent <ID> <task-file> --fresh" >&2
  team_dim "    · 确认要复用（例如换成窗口更大的模型）：… --allow-overflow（显式放行会醒目警告）" >&2
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
team_dispatch_stack_guard() { # <agent> <ID> <force> → 0=继续 / 1=拒绝（原因已打印）
  local agent="$1" id="$2" force="${3:-0}"
  local prev wt wt_branch prev_branch reason st
  TEAM_DISPATCH_STACK_PREV=""          # 只有真的覆盖了才置位（同一进程里连续派单也不串台）
  prev="$(team_state_get "$agent" task '')"
  if [ -z "$prev" ]; then
    team_dim "  $agent 没有在飞的任务记录（state/$agent.env 的 task= 为空或文件不存在）：判不出它手上有没有没结束的活，这次不拦"
    return 0
  fi
  [ "$prev" = "$id" ] && return 0     # 同一个任务 = resume / 断点续跑：这是「继续」，不是「叠」
  wt="$(team_state_get "$agent" worktree '')"
  if [ -z "$wt" ] || [ ! -d "$wt" ]; then wt="$(team_agent_worktree "$agent")"; fi
  if [ ! -d "$wt" ]; then
    team_dim "  $agent 记着的任务 $prev 找不到工作树（$wt）：判不出它是否还压在这个任务上，这次不拦"
    return 0
  fi
  wt_branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [ -z "$wt_branch" ] || [ "$wt_branch" = "HEAD" ]; then
    team_dim "  $agent 的工作树 $wt 不在任何分支上（detached 或不是 git 仓库）：判不出它是否还压着 $prev，这次不拦"
    return 0
  fi
  if [ "$wt_branch" = "$TEAM_PROTECTED_BRANCH" ]; then
    # 保护分支上的工作树本来就不允许开工（team_check_worktree_for_task 会给出该跑的 git 命令）：
    # 这里不重复报同一件事，只把「它手上还有 X」说出来
    team_dim "  $agent 的工作树在 $TEAM_PROTECTED_BRANCH 上，而它手上还有没结束的任务 $prev：先收尾再派（下面按常规守卫处理）"
    return 0
  fi
  if reason="$(team_task_open_reason "$prev")"; then return 0; fi   # X 已结束：输出与以前逐字相同
  prev_branch="$(team_state_get "$agent" branch '')"
  st="$(team_board_status "$prev")"
  if [ "$force" = "1" ]; then
    team_warn "显式覆盖（--force）：$agent 上还有没结束的任务 $prev —— 这次派 $id 会接管它的窗口与 state"
    team_dim "  被让位的任务：$prev ｜看板：${st:-没有这一行} ｜分支：$wt_branch（state 记的是 ${prev_branch:-未记}）" >&2
    team_dim "  它还没结束：$reason" >&2
    TEAM_DISPATCH_STACK_PREV="$prev"    # 真实派单路径据此写审计（--print 不写）
    return 0
  fi
  team_err "拒绝派单：$agent 上还有一个没结束的任务（$prev）—— 这样会把这次的任务叠上去，接管它的窗口与 state"
  team_err "  任务    ：$prev（看板状态：${st:-BOARD 里没有这一行}）"
  if [ "$wt_branch" = "$prev_branch" ] || team_branch_is_for_task "$wt_branch" "$agent" "$prev"; then
    team_err "  分支    ：$wt_branch（工作树 $wt 还停在它上面）"
  else
    team_err "  分支    ：工作树 $wt 停在 $wt_branch（state 记的是 ${prev_branch:-没有记录}）"
  fi
  team_err "  没结束  ：$reason"
  team_err "  两条出路："
  team_err "    · 先收尾：$TEAM_CLI resume --agent $agent（继续 $prev；复验/合并后再 team board set $prev done）"
  team_err "    · 要它让位：$TEAM_CLI dispatch $agent $id <task-file> --force（显式覆盖，输出里会写明）"
  return 1
}

# ---------------------------------------------------------------- P23（D31）· change 为中心的派单纪律
# 四条规则一个前置块（全在开窗之前，也与叠任务守卫同一位置族）：
#   规则 1 · 一个任务最多一个 change id（没有逃生门：一个任务实现两个 change 是派错单）
#   规则 B · change-less 的任务必须声明能解析的锚（specs:#需求 或 anchor: none (infra) — 理由）
#   规则 2 · 同一 change 的两个未结束任务不得写同一个 delta 文件（单写者）
#   规则 3 · verify 任务的 agent 不能是该 change 的 apply 作者
# 拒绝时一律点名到文件/任务/看板状态；`--force` 覆盖处打印警告并往 TEAM_DISPATCH_AUDIT_LINES
# 追加**一行**审计（与叠任务守卫同一形状：真正落盘在派单成功之后，`--print` 不写 state）。
# 「判不出来」信号（兄弟的 deltas: 坏/缺 agent:）一律吵但不是拒绝 —— 不把未知冒充成干净。
team_dispatch_change_guard() { # <agent> <ID> <任务书路径> <force> → 0=继续 / 1=拒绝
  local agent="$1" id="$2" brief="$3" force="${4:-0}"
  local change out phase rel
  rel="${brief#"$TEAM_MAIN_ROOT"/}"
  TEAM_DISPATCH_AUDIT_LINES="${TEAM_DISPATCH_AUDIT_LINES:-}"

  # —— 规则 1：change: 只接受一个 token（或 `-`） ——
  if ! change="$(team_task_change_value "$brief")"; then
    team_err "拒绝派单：$id 的任务书 change: 行不合法（一个任务最多属于一个 change）"
    printf '%s\n' "$change" | sed 's/^/  /' >&2
    team_err "  接受的形式："
    team_err "    · change: <一个 change id>     例：change: change-centric-discipline"
    team_err "    · change: -                    不属于任何 change（但要在 specs:/anchor: 里声明锚）"
    team_err "  修法：编辑 $rel 的 change: 行 —— 逗号不是多个 id，两行也不行（只留一行）"
    team_err "  规则 1 没有 --force 逃生门：一个任务实现两个 change 是派错单，不是偏好。"
    return 1
  fi
  phase="$(team_brief_field "$brief" phase)"
  case "$phase" in explore|propose|apply|verify|archive) ;; *) phase="" ;; esac

  # —— 规则 B：change-less 的锚 ——
  if [ "$change" = "-" ]; then
    if out="$(team_task_anchor "$brief")"; then
      : # 有锚（specs 解析成功 / infra 带理由）
    elif [ "$force" = "1" ]; then
      team_warn "显式覆盖（--force）：$id 没有 change:，锚也缺失/不解析 —— 这次照常派单"
      printf '%s\n' "$out" | sed 's/^/    /' >&2
      TEAM_DISPATCH_AUDIT_LINES="${TEAM_DISPATCH_AUDIT_LINES}dispatch $agent: --force 覆盖锚缺失（$id 无 change 且 $rel 的 specs:/anchor: 解析不了）"$'\n'
    else
      team_err "拒绝派单：$id 没有 change: 行（或值是 \`-\`），必须声明它的锚"
      printf '%s\n' "$out" | sed 's/^/  /' >&2
      team_err "  修法：编辑 $rel 的 specs:/anchor: 行"
      team_err "  覆盖：$TEAM_CLI dispatch $agent $id $brief --force（警告 + 一行审计）"
      return 1
    fi
  fi

  # —— 规则 2：同一 change 的 delta 单写者 ——
  if [ "$change" != "-" ]; then
    local mine mine_decl mine_text sib sde sdt sib_text shared sid sphase sst sreason sbrief
    if ! mine="$(team_task_delta_targets "$brief" "$change")"; then
      team_err "拒绝派单：$id 的 deltas: 行不合法 —— 它决定 delta 单写者检查，不能静默当空集"
      printf '%s\n' "$mine" | sed 's/^/  /' >&2
      return 1
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
        team_warn "  delta 单写者检查：兄弟 $sid（看板 $sst）的 deltas: 行不合法 —— 它的目标集判不出来，不冒充干净"
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
        team_dim "  change $change 的 delta 单写者检查：兄弟 $sid（看板 $sst，$sib_text）｜本次 $mine_text → 无重叠"
        continue
      fi
      if [ "$force" = "1" ]; then
        team_warn "显式覆盖（--force）：change $change 的 delta 单写者冲突 —— $sid（看板 $sst）与 $id 都会写 $shared"
        team_dim "  $sid 的声明：$sib_text ｜ 本次声明：$mine_text" >&2
        TEAM_DISPATCH_AUDIT_LINES="${TEAM_DISPATCH_AUDIT_LINES}dispatch $agent: --force 覆盖 delta 单写者（$sid 与 $id 共享 $shared）"$'\n'
        continue
      fi
      team_err "拒绝派单：change $change 的同一个 delta 文件被两个未结束的任务声明（单写者规则）"
      team_err "  兄弟任务：$sid ｜阶段 ${sphase:--} ｜看板 $sst"
      team_err "  它没结束：$sreason"
      team_err "  共享文件：$shared"
      team_err "  它的声明：$sib_text"
      team_err "  本次声明：$mine_text"
      team_err "  两条出路："
      team_err "    · 等它结束（done/closed/交付证据）再派；或把两边的 deltas: 写成互不相交的 capability"
      team_err "    · 两边确实不会互相覆盖：$TEAM_CLI dispatch $agent $id $brief --force（一行审计）"
      return 1
    done < <(team_change_unfinished "$change")
  fi

  # —— 规则 3：verify 的 agent 不能是该 change 的 apply 作者 ——
  if [ "$phase" = "verify" ] && [ "$change" != "-" ]; then
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
    [ -n "$dropped" ] && team_dim "  已排除（看板 dropped）：$dropped"
    [ -n "$missing" ] && team_warn "  作者信号缺失：$missing —— 判不出它们的作者，不当作干净（照常派单）"
    if [ -n "$authored" ]; then
      if [ "$force" = "1" ]; then
        team_warn "显式覆盖（--force）：verification 不再独立 —— $agent 写过 change $change 的 apply 任务（$authored），又要 verify $id"
        TEAM_DISPATCH_AUDIT_LINES="${TEAM_DISPATCH_AUDIT_LINES}dispatch $agent: --force 覆盖自验（change $change 的 apply 作者 $authored 来 verify $id）"$'\n'
      else
        team_err "拒绝派单：verification 不独立 —— $agent 写过 change $change 的 apply 任务（$authored），不能自己验自己"
        team_err "  change：$change ｜ agent：$agent ｜ 它写过的任务：$authored"
        team_err "  两条出路："
        team_err "    · 换一个没写过这些 apply 任务的 agent 来 verify"
        team_err "    · 确实要自验：$TEAM_CLI dispatch $agent $id $brief --force（警告 + 一行审计）"
        return 1
      fi
    fi
  fi
  return 0
}

team_cmd_dispatch() {
  team_require_cmd tmux "agent 在 tmux 窗口里跑，PM 需要能旁观与追问"
  local agent="" id="" taskfile="" model="" fresh=0 printonly=0 overflow=0 force=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --model) model="${2:?}"; shift 2 ;;
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
    team_usage_die "dispatch <agent> <ID> <task-file> [--model m] [--fresh] [--allow-overflow] [--force] [--print]"
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

  # M9.3 ⑥：同一个 ID 有多份任务书 —— 认不出哪一份是这次的 scope。旧实现按 glob 顺序悄悄用第一份：
  # 分支名可能算成旧 slug（撞名 `fatal: a branch named … already exists`），更糟的是派错 scope。
  # 确定性做法：拒绝并列出全部（--force 不适用：认错任务不是「你说了算」的事）。
  local briefs nbrief
  briefs="$(team_task_briefs "$id")"
  nbrief="$(printf '%s\n' "$briefs" | grep -c . || true)"
  if [ "${nbrief:-0}" -gt 1 ]; then
    team_err "拒绝派单：$id 有多份任务书（$nbrief 份）—— 认不出哪一份是这次的 scope，不猜"
    while IFS= read -r b; do
      [ -n "$b" ] && team_err "    ${b#"$TEAM_MAIN_ROOT"/}"
    done <<< "$briefs"
    team_err "  旧实现按 glob 顺序取第一份：分支名可能算成旧 slug（撞名 fatal: a branch named … already exists），"
    team_err "  更糟的是把旧任务书的 scope 派出去。"
    team_err "  确定性做法：只留一份 —— 把过期的那份改名/删掉（或给它自己的 ID），再派单。"
    return 1
  fi

  # P23（D31）：change 为中心的派单纪律（规则 1/B/2/3），在所有开窗动作之前
  team_dispatch_change_guard "$agent" "$id" "$taskfile" "$force" || return 1

  # M9.3 ①-⑤：这个 agent 上是不是还压着一个没结束的任务（resume / up --agents 也走这里：
  # 它们派的永远是 agent 自己记着的任务 → 同一任务短路，所以那两扇门的语义不变）
  team_dispatch_stack_guard "$agent" "$id" "$force" || return 1

  local wt; wt="$(team_agent_worktree "$agent")"
  if [ ! -d "$wt" ]; then
    team_err "worktree 不存在：$wt（skill 不代做 git）"
    team_dim "$(printf '  先由 PM 建： git -C %q worktree add -b %q %q %q' \
      "$TEAM_MAIN_ROOT" "$(team_branch_for_agent "$agent" "$id")" "$wt" "$TEAM_PROTECTED_BRANCH")" >&2
    return 1
  fi
  # 分支准备放在守卫之前（会让 worktree 变状态，失败即停）。
  # M6.3 F16：**--print 也检查** —— 打印出来的计划里已经写着这个任务的复验目标分支，
  # 不能在别的任务的分支上生成一份“看起来对”的提示词。
  local task_branch=""
  team_check_worktree_for_task "$agent" "$id" || return 1
  task_branch="$TEAM_CHECKED_BRANCH"

  # M14：解析顺序 = --model 显式参数 ＞ 配置（TEAM_AGENT_MODELS 的 per-agent ＞ TEAM_DEFAULT_MODEL）。
  # 名册 state 里的 model 只是「上次用了什么」的展示记录（roster/ps 标注来源用），不再当默认来源 ——
  # 旧行为（state 优先）让配置改了也不生效：名册里的 deepseek 旧记录压过了新配的 k3-256k。
  local model_src="config"
  if [ -z "$model" ]; then model="$(team_agent_model "$agent")"; else model_src="explicit"; fi
  local provider="${model%%/*}"
  local sid="$TEAM_SESSION-$agent"
  [ "$fresh" = "1" ] && sid="$sid-$(date +%s)"

  team_mem_guard || return 1
  team_model_guard "$model" || return 1
  # M4.3 A：会话规模 vs 模型窗口（默认拒绝，--fresh / --allow-overflow 是出路）
  team_guard_resume_session "$agent" "$model" "$sid" "$wt" "$fresh" "$overflow" || return 1

  # agent adapter：空配置 = 内置 Pi（老路径，报错文案也不变）
  team_agent_check_launch
  # 必需依赖体检（D10）：缺依赖**不拒绝**派单（worker 照样能干活），但 PM 必须知道证据/spec 层是缺的。
  # 一行、每次派单只说一次。
  local dep_issues; dep_issues="$(team_required_dep_issues)"
  [ -n "$dep_issues" ] && team_warn "依赖缺失（不阻塞派单）：$(printf '%s' "$dep_issues" | tr '\n' '; ')"
  local agent_bin; agent_bin="$(team_agent_bin_path)"
  if [ -n "${TEAM_AGENT_CMD:-}${TEAM_AGENT_BIN:-}" ]; then
    # 自定义 adapter（codex/opencode/…）：只看配好的可执行文件能不能解析到
    case "$agent_bin" in /*) ;; *) team_warn "agent 可执行文件不是绝对路径（$agent_bin）：窗口里可能 PATH 未就绪，建议用 TEAM_AGENT_BIN 写死绝对路径";; esac
    command -v "$agent_bin" >/dev/null 2>&1 || team_die "找不到 agent 可执行文件：$agent_bin（检查 TEAM_AGENT_BIN 或 TEAM_AGENT_CMD 的首词）"
  else
    case "$agent_bin" in /*) ;; *) team_warn "TEAM_PI_BIN 不是绝对路径（$agent_bin）：窗口里可能 PATH 未就绪，建议写死绝对路径";; esac
    command -v "$TEAM_PI_BIN" >/dev/null 2>&1 || team_die "找不到 pi 可执行文件：TEAM_PI_BIN=$TEAM_PI_BIN（设成绝对路径再派单）"
  fi
  local prompt prompt_file agent_cmd inner
  prompt="$(team_build_prompt "$agent" "$id" "$taskfile" "$wt" "$model" "$sid")"
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
  team_ok "dispatched $id → $TEAM_SESSION:$agent（含启动校验：proof=spawn pid=$pid；provider=$provider model=${model##*/} session=$sid）"
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
  # P82：发送者进 durable 收件箱行（第 4 参），收件人仍是文件名
  team_inbox_append "$agent" manual "$msg" "$sender" \
    || team_warn "notify：收件箱行写不进去（$TEAM_DOCS_DIR/inbox/$agent.md）—— 下面的投递会把这条声明当已落地"
  local target="$TEAM_SESSION:$TEAM_PM_WINDOW"
  # M30 · pi 通道优先：目标有**活的**收件箱监视器时，敲门交给它（注册里的 pid+cwd 就是「PM 会话活着」
  # 的证据，比 tmux/pane 启发式直接），而且这条链不需要 tmux、不碰输入框。
  # --inbox-written pm：上面的 durable 行已经写了，通道不能再写一遍（条目头部的契约）。
  if [ "$TEAM_NOTIFY_TMUX" = "1" ] && team_inbox_watch_route "$target" >/dev/null 2>&1; then
    team_send_guarded "$target" "[manual] agent:$sender · $msg" knock --from "$sender" \
      --dedup "$(team_notify_dedup_key "$agent" "$msg")" --inbox-written pm
    case "$TEAM_SEND_OUTCOME" in
      watched) team_dim "  pi 监视通道：收件箱已写，会话里的监视扩展负责唤醒（输入框零按键）" ;;
      queued)  team_dim "  pi 监视通道投递没落地（条目入队）：$TEAM_CLI outbox list" ;;
      duplicate) team_dim "  duplicate：同一份通知在 ${TEAM_NOTIFY_DEDUP_SEC:-20}s 内已经投过（没有重复入队）" ;;
      offline|unknown-failed) team_warn "敲门没落地（pi 通道写不进去）：消息只落收件箱" ;;
    esac
  elif [ "$TEAM_NOTIFY_TMUX" = "1" ] && team_have_cmd tmux && [ -n "${TMUX:-}" ] \
     && team_pm_alive; then
    # 只给「正在跑 pi 的 PM」打字：PM 没在跑时写进 shell 会被当命令执行。
    # 敲门也走投递守卫：输入框里有草稿 → 入队，草稿不动（规格 notify-and-inbox 的 dirty-PM 场景）
    team_send_guarded "$target" "[manual] agent:$sender · $msg" knock --from "$sender" \
      --dedup "$(team_notify_dedup_key "$agent" "$msg")" --inbox-written pm
    case "$TEAM_SEND_OUTCOME" in
      queued) team_dim "  PM 输入框里有草稿：敲门入队（$TEAM_CLI outbox list），清空后自动投递" ;;
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
}

team_cmd_teardown() {
  local agent="" all=0 purge=0 force=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --agent) agent="${2:?}"; shift 2 ;;
      --all) all=1; shift ;;
      --purge) purge=1; shift ;;
      --force) force=1; shift ;;
      *) team_usage_die "teardown: 未知参数 $1" ;;
    esac
  done
  local targets=()
  if [ "$all" = "1" ]; then mapfile -t targets < <(team_agents); else
    [ -n "$agent" ] || team_usage_die "teardown --agent <a> | --all [--purge] [--force]"
    targets=("$agent")
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
