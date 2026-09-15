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

  if [ "$noinstall" != "1" ] && [ -n "$TEAM_INSTALL_CMD" ]; then
    team_info "install: $TEAM_INSTALL_CMD（在 $wt）"
    ( cd "$wt" && eval "$TEAM_INSTALL_CMD" ) || team_warn "install 失败，先手动装依赖再派单"
  fi

  team_state_set "$agent" model "$(team_agent_model "$agent")"
  team_state_set "$agent" window "$agent"
  team_state_set "$agent" worktree "$wt"
  return 0
}

team_pi_args() { # <model> → 打印已转义的 pi 参数
  local model="$1" provider piargs=()
  provider="${model%%/*}"
  piargs=(--provider "$provider" --model "${model##*/}")
  piargs+=(-e "$TEAM_SKILL_DIR/extension/team-notify.ts")
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
  local issue="" cli="$TEAM_SKILL_DIR/scripts/team" rel abs_docs rel_report rel_note notify_block=""
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

Task: **$id**${issue:+ (issue #$issue)}. The brief \`$taskfile\` is the PM's read-only file -- do not modify it.${notify_block}
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

team_cmd_dispatch() {
  team_require_cmd tmux "agent 在 tmux 窗口里跑，PM 需要能旁观与追问"
  local agent="" id="" taskfile="" model="" fresh=0 printonly=0 overflow=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --model) model="${2:?}"; shift 2 ;;
      --fresh) fresh=1; shift ;;
      --allow-overflow) overflow=1; shift ;;
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
    team_usage_die "dispatch <agent> <ID> <task-file> [--model m] [--fresh] [--allow-overflow] [--print]"
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

  model="${model:-$(team_state_get "$agent" model "$(team_agent_model "$agent")")}"
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
      if [ "$attempt" = "1" ]; then team_warn "窗口 $TEAM_SESSION:$agent 已存在 → 替换（旧回合会被打断）"
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
    inner="$(printf 'cd %q\nfor _i in 1 2 3 4 5 6 7 8 9 10; do [ -x %q ] && break; sleep 0.3; done\nprintf "%%s %%s\\n" %s %s > %q\nprintf "\\033[2mteamsmith agent:%s → %s\\033[0m\\n"\n%s\nprintf "%%s %%s\\n" %s "$?" > %q\nif [ -n "${TMUX_PANE:-}" ] && command -v tmux >/dev/null 2>&1; then _n=0; while [ "$_n" -lt 10 ]; do tmux capture-pane -p -t "$TMUX_PANE" -S -200 > %q 2>/dev/null; grep -q "[^[:space:]]" %q && break; _n=$((_n + 1)); sleep 0.1; done; fi\nexec bash' \
      "$wt" "$agent_bin" "$(printf '%q' "$nonce")" '$$' "$marker" "$agent" "$id" "$agent_cmd" "$(printf '%q' "$nonce")" "$exitfile" "$(printf '%q' "$tailfile")" "$(printf '%q' "$tailfile")")"
    tmux new-window -t "$TEAM_SESSION" -n "$agent" -d -- bash -lc "$inner" "$prompt" >/dev/null 2>&1 || true
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
  team_state_set "$agent" window "$agent"
  team_state_set "$agent" worktree "$wt"
  team_state_set "$agent" task "$id"
  team_state_set "$agent" taskfile "$taskfile"
  [ -n "$task_branch" ] && team_state_set "$agent" branch "$task_branch"
  team_state_set "$agent" started "$(team_timestamp)"
  team_board_set "$id" wip 2>/dev/null || true

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
  local agent="" msg="" verify=1 any=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --no-verify) verify=0; shift ;;
      --any) any=1; shift ;;
      -*) team_usage_die "say: 未知参数 $1" ;;
      *) if [ -z "$agent" ]; then agent="$1"; elif [ -z "$msg" ]; then msg="$1"; else msg="$msg $1"; fi; shift ;;
    esac
  done
  [ -n "$agent" ] && [ -n "$msg" ] || team_usage_die "say <agent> <单行消息> [--no-verify] [--any]"
  case "$msg" in *$'\n'*) team_die "say 只能发单行：多行请写进文件，然后让 agent 去读" ;; esac
  team_require_recipient "$agent" "$any" say || return 1
  local w; w="$(team_state_get "$agent" window "$agent")"
  team_tmux_has_window "$TEAM_SESSION" "$w" \
    || { team_say_offline "$agent" "$msg" "窗口 $TEAM_SESSION:$w 不在"; return 0; }
  # 安全：空提示符时把消息 send-keys 进去会被 shell 当命令执行
  if team_is_shell_cmd "$(team_pane_cmd "$TEAM_SESSION:$w")" && ! team_pane_busy "$TEAM_SESSION:$w"; then
    team_say_offline "$agent" "$msg" "$(team_agent_cli_name) 已退出（空提示符）"
    return 0
  fi

  local target="$TEAM_SESSION:$w"
  local before=""; [ "$verify" = "1" ] && before="$(team_pane_snapshot "$target")"
  team_tmux_send_text "$target" "$msg" || team_die "发送失败"
  if [ "$verify" != "1" ]; then
    team_ok "said to $target: $msg"
    return 0
  fi
  # 投递校验（CEP 实测：agent 刚 settle 时 send-keys 可能被 TUI 吃掉——文本进去了/Enter 太早）
  local i after
  for i in 1 2 3 4 5 6; do
    sleep 0.3
    after="$(team_pane_snapshot "$target")"
    [ "$after" != "$before" ] && { team_ok "said to $target: $msg（已确认送达）"; return 0; }
    # 2、4 次没动静就补一次 Enter（TUI 有时只吃了文本）
    case "$i" in 2|4) tmux send-keys -t "$target" Enter 2>/dev/null || true ;; esac
  done
  # 最后再整条重发一次
  team_warn "第一次投递没看到 pane 变化，重发一次…"
  team_tmux_send_text "$target" "$msg" || true
  for i in 1 2 3 4; do
    sleep 0.3
    after="$(team_pane_snapshot "$target")"
    [ "$after" != "$before" ] && { team_ok "said to $target: $msg（重发后确认送达）"; return 0; }
    [ "$i" = "2" ] && tmux send-keys -t "$target" Enter 2>/dev/null || true
  done
  team_inbox_append "$agent" pm "（PM 消息，投递未确认）$msg"
  team_err "投递未确认：$target 的 pane 没有变化（消息已写入收件箱 $TEAM_DOCS_DIR/inbox/$agent.md）"
  team_dim "  手工兜底：tmux send-keys -t $target -l \"<消息>\"; tmux send-keys -t $target Enter" >&2
  return 1
}

team_inbox_append() { # <agent> <tag> <msg>
  local dir; dir="$(team_inbox_dir)"
  mkdir -p "$dir"
  printf -- '- %s [%s] agent:%s · %s\n' "$(team_timestamp)" "$2" "$1" "$3" >> "$dir/$1.md"
}

team_cmd_notify() {
  local from_file="" msg any=0
  while [ "${1:-}" = "--any" ]; do any=1; shift; done
  local agent="${1:?usage: notify <agent> <单行消息> | notify <agent> --from-file <摘要文件>}"; shift
  while [ "${1:-}" = "--any" ]; do any=1; shift; done
  if [ "${1:-}" = "--from-file" ]; then
    from_file="${2:?notify --from-file 需要摘要文件路径}"; shift 2
  fi
  while [ "${1:-}" = "--any" ]; do any=1; shift; done
  # 摘要始终是**数据**：--from-file 从文件读（worker 的文本不经过 shell）；两种路径都归一化成单行，
  # 但除换行/回车/尾部空白外**逐字节保留**（引号、$、反引号、{} 都原样进收件箱）。
  if [ -n "$from_file" ]; then
    [ -f "$from_file" ] || team_die "notify --from-file：文件不存在（$from_file）——worker 要先把摘要写进去"
    msg="$(team_one_line "$(cat "$from_file")")"
  else
    [ $# -gt 0 ] || team_usage_die "notify <agent> <单行消息> | notify <agent> --from-file <摘要文件>"
    msg="$(team_one_line "$*")"
  fi
  if [ -z "$(team_trim "$msg")" ]; then
    if [ -n "$from_file" ]; then team_die "notify --from-file：摘要文件是空的（$from_file）"
    else team_die "notify：摘要不能为空（收到空参数；如果用 \"\$(cat <摘要文件>)\" 取摘要，先确认那个文件写好且非空）"; fi
  fi
  team_require_recipient "$agent" "$any" notify || return 1
  team_inbox_append "$agent" manual "$msg"
  local target="$TEAM_SESSION:$TEAM_PM_WINDOW"
  if [ "$TEAM_NOTIFY_TMUX" = "1" ] && team_have_cmd tmux && [ -n "${TMUX:-}" ] \
     && team_pm_alive; then
    # 只给「正在跑 pi 的 PM」打字：PM 没在跑时写进 shell 会被当命令执行
    team_tmux_send_to_pi "$target" "[manual] agent:$agent · $msg" || true
  elif [ "$TEAM_NOTIFY_TMUX" = "1" ] && [ -n "${TMUX:-}" ] && team_have_cmd tmux && ! team_pm_alive; then
    team_warn "PM 不在运行：消息只落收件箱（watchdog 会把 PM 拉起后读到）"
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
      fi
    fi
  done
  [ "$purge" != "1" ] && team_dim "worktree 仍保留（加 --purge 删除）；分支保留，需要时 git branch -d"
  return 0
}
