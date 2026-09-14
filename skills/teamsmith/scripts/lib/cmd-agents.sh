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
team_build_prompt() { # <agent> <ID> <taskfile-abs> <worktree> <model>
  local agent="$1" id="$2" taskfile="$3" wt="$4" model="$5"
  local issue="" cli="$TEAM_SKILL_DIR/scripts/team" rel abs_docs rel_report
  rel="$(printf '%s' "$taskfile" | sed "s|^$TEAM_MAIN_ROOT/||")"
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

  cat <<PROMPT
你是 **$TEAM_PROJECT** 项目的 agent:$agent，由 PM 通过 teamsmith 派单。工作树是 \`$wt\`，
所有命令都在这里执行；**不要**动主工作树（$TEAM_MAIN_ROOT），**不要**切到 main 或别人的分支。

开工前依次读：
1. \`AGENTS.md\`（含 teamsmith 团队协议段落）
2. 你的消息线程 \`$abs_docs/threads/$agent.md\`（PM 可能在你开工前补了指令）
3. 任务书 \`$taskfile\`${rel:+（同一文件在仓库内的相对路径：\`$rel\`）}（本任务的全部要求与验收命令）

范围纪律：只做任务书里写明的事，只改 OWNERSHIP 归属给你的目录。
需要跨目录改动时不要自己动手，在报告里写 \`BLOCKED:\` + 需要谁改什么，然后结束任务。

红线：禁止 push $TEAM_PROTECTED_BRANCH、禁止 force push、禁止 merge PR/MR、禁止 rebase/删除他人分支、
禁止改仓库设置；禁止把 token/secret 写进代码、日志、提交信息；禁止读取凭据文件（如 ~/.pi/agent/auth.json）。

**边界（跨项目一律不动手）**：只在 $TEAM_MAIN_ROOT 与自己的工作树、以及本团队 tmux session
（$TEAM_SESSION）内动作。禁止给其他项目/其他 session 的窗口发消息、禁止读写其他项目的仓库与会话文件、
禁止替其他项目改代码或合并。需要别的项目配合（跨仓库依赖、共享库改动）：在报告里写
\`BLOCKED:\` + 需要谁做什么 —— **跨项目沟通由 PM 通过 \`$cli meeting\` 进行（peer 交流：接口对接/建议/问题报告），
worker 不参会**；只有需要用户拍板的跨项目决策才经用户。

**不要在半途停下来征求确认**：只有以下两种情况才结束回合 ——
(a) 任务书验收命令全部跑完 + 报告写完 + 分支 push 完 + PR/MR 开完（或 local 模式 push 完）；
(b) 被硬阻塞（缺依赖、要权限、发现别人的 bug）：\`$cli notify $agent "<一句话>"\` 通知 PM，
    在报告里写清 \`BLOCKED:\`，然后结束任务，**不要自己越界**。

交付流程：
1. 真实执行任务书里的验收命令；**没有实际运行，不得声称通过**（PM 会独立复验，虚假报告视为任务失败）。
2. 每完成一个可验证的小步就 \`git commit\`（Conventional Commits + 任务 ID + trailer \`Agent: $agent\`${issue:+ + \`Refs #$issue\`}），不要攒到最后一次性提交。
3. 写报告 \`$rel_report\`（在你自己的分支上提交；格式见 AGENTS.md 的报告模板，含真实命令与输出尾部）。
   若是**缺陷修复**类任务，报告必须有「翻转证据」：修复前红 → 修复后绿，或"破坏实现 → 守门测试失败 → 还原"
   （PM 会用 \`$cli review $id --strong\` 检查这一节，缺了会被退回）。
4. \`git push -u $TEAM_REMOTE HEAD\`。
5. $pr_step。

任务：**$id**${issue:+（issue #$issue）}。任务书 \`$taskfile\` 是 PM 的只读文件，不要修改它。
如果是断点续跑：先 \`git status\` / \`git log --oneline -5\` 看已经做到哪，从断点继续，不要从零重做。
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
      team_dim "  git -C $wt switch -c $want $TEAM_PROTECTED_BRANCH"
      return 1 ;;
    HEAD)
      if [ -n "$want" ]; then
        team_warn "$agent 的工作树是 detached HEAD：先切到任务分支"
        team_dim "  git -C $wt switch -c $want $TEAM_PROTECTED_BRANCH"
        return 1
      fi ;;
  esac
  TEAM_CHECKED_BRANCH="$cur"
  return 0
}

team_cmd_dispatch() {
  team_require_cmd tmux "agent 在 tmux 窗口里跑，PM 需要能旁观与追问"
  local agent="" id="" taskfile="" model="" fresh=0 printonly=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --model) model="${2:?}"; shift 2 ;;
      --fresh) fresh=1; shift ;;
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
    team_usage_die "dispatch <agent> <ID> <task-file> [--model m] [--fresh] [--print]"
  team_require_agent "$agent"

  # 任务书路径：先按 cwd 解析，再按主工作树解析
  [ -f "$taskfile" ] || taskfile="$TEAM_MAIN_ROOT/$taskfile"
  [ -f "$taskfile" ] || team_die "找不到任务书：$taskfile"
  taskfile="$(cd "$(dirname "$taskfile")" && pwd)/$(basename "$taskfile")"

  local wt; wt="$(team_agent_worktree "$agent")"
  if [ ! -d "$wt" ]; then
    team_err "worktree 不存在：$wt（skill 不代做 git）"
    team_dim "  先由 PM 建： git -C $TEAM_MAIN_ROOT worktree add -b $(team_branch_for_agent "$agent" "$id") $wt $TEAM_PROTECTED_BRANCH" >&2
    return 1
  fi
  # 分支准备放在守卫之前（会让 worktree 变状态，失败即停）
  local task_branch=""
  if [ "$printonly" != "1" ]; then
    team_check_worktree_for_task "$agent" "$id" || return 1
    task_branch="$TEAM_CHECKED_BRANCH"
  fi

  model="${model:-$(team_state_get "$agent" model "$(team_agent_model "$agent")")}"
  local provider="${model%%/*}"
  local sid="$TEAM_SESSION-$agent"
  [ "$fresh" = "1" ] && sid="$sid-$(date +%s)"

  team_mem_guard || return 1
  team_model_guard "$model" || return 1

  local pi_bin; pi_bin="$(team_pi_bin_path)"
  case "$pi_bin" in /*) ;; *) team_warn "TEAM_PI_BIN 不是绝对路径（$pi_bin）：窗口里可能 PATH 未就绪，建议写死绝对路径";; esac
  command -v "$TEAM_PI_BIN" >/dev/null 2>&1 || team_die "找不到 pi 可执行文件：TEAM_PI_BIN=$TEAM_PI_BIN（设成绝对路径再派单）"
  local prompt; prompt="$(team_build_prompt "$agent" "$id" "$taskfile" "$wt" "$model")"
  local piargs inner
  piargs="$(team_pi_args "$model")"

  if [ "$printonly" = "1" ]; then
    printf '=== pi 命令 ===\n'
    printf 'cd %q && %s %s--session-id %s "$PROMPT"\n' "$wt" "$pi_bin" "$piargs" "$sid"
    printf '\n=== 提示词（%s 字） ===\n%s\n' "${#prompt}" "$prompt"
    return 0
  fi

  team_tmux_ensure_session
  if team_agent_window_exists "$agent"; then
    team_warn "窗口 $TEAM_SESSION:$agent 已存在 → 替换（旧回合会被打断）"
    tmux kill-window -t "$TEAM_SESSION:$agent" 2>/dev/null || true
    sleep 1
  fi

  # 命令里写死绝对路径 + 短暂等待（窗口 shell 可能刚起、PATH/rc 还没就绪）
  inner="$(printf 'cd %q\nfor _i in 1 2 3 4 5 6 7 8 9 10; do [ -x %q ] && break; sleep 0.3; done\nprintf "\\033[2mteamsmith agent:%s → %s\\033[0m\\n"\n%s %s--session-id %s "$0"; exec bash' \
    "$wt" "$pi_bin" "$agent" "$id" "$(printf '%q' "$pi_bin")" "$piargs" "$sid")"
  tmux new-window -t "$TEAM_SESSION" -n "$agent" -d -- bash -lc "$inner" "$prompt"

  team_state_set "$agent" model "$model"
  team_state_set "$agent" window "$agent"
  team_state_set "$agent" worktree "$wt"
  team_state_set "$agent" task "$id"
  team_state_set "$agent" taskfile "$taskfile"
  [ -n "$task_branch" ] && team_state_set "$agent" branch "$task_branch"
  team_state_set "$agent" started "$(team_timestamp)"
  team_board_set "$id" wip 2>/dev/null || true

  team_ok "dispatched $id → $TEAM_SESSION:$agent（provider=$provider model=${model##*/} session=$sid）"
  team_dim "  旁观：tmux attach -t $TEAM_SESSION ｜ 追问：$TEAM_CLI say $agent \"...\""
}

team_pane_snapshot() { # <target> → pane 内容指纹（用于确认投递真的落到 TUI）
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

team_cmd_say() {
  local agent="" msg="" verify=1
  while [ $# -gt 0 ]; do
    case "$1" in
      --no-verify) verify=0; shift ;;
      -*) team_usage_die "say: 未知参数 $1" ;;
      *) if [ -z "$agent" ]; then agent="$1"; elif [ -z "$msg" ]; then msg="$1"; else msg="$msg $1"; fi; shift ;;
    esac
  done
  [ -n "$agent" ] && [ -n "$msg" ] || team_usage_die "say <agent> <单行消息> [--no-verify]"
  case "$msg" in *$'\n'*) team_die "say 只能发单行：多行请写进文件，然后让 agent 去读" ;; esac
  local w; w="$(team_state_get "$agent" window "$agent")"
  team_tmux_has_window "$TEAM_SESSION" "$w" \
    || { team_say_offline "$agent" "$msg" "窗口 $TEAM_SESSION:$w 不在"; return 0; }
  # 安全：空提示符时把消息 send-keys 进去会被 shell 当命令执行
  if team_is_shell_cmd "$(team_pane_cmd "$TEAM_SESSION:$w")" && ! team_pane_busy "$TEAM_SESSION:$w"; then
    team_say_offline "$agent" "$msg" "pi 已退出（空提示符）"
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
  local agent="${1:?usage: notify <agent> <单行消息>}"; shift
  [ $# -gt 0 ] || team_usage_die "notify <agent> <单行消息>"
  local msg="$*"
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
