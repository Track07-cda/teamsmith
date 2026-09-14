#!/usr/bin/env bash
# pi-team · bootstrap：一条命令把项目初始化到“可以派单”的状态（幂等，可反复跑）
#
# 设计给 PM 用：PM 在新项目里被启动后的第一件事就是跑它。它会
#   ① 探测当前 tmux session/窗口（PM 自己就在里面）→ 写进配置   ② init 配置 + 文档骨架 + AGENTS 段落
#   ③ 按名册建 agent worktree                                    ④ 起看门狗窗口（PM 负责配置看门狗）
#   ⑤ 打印“下一步清单”（PM 照做即可开始派单）
#
# 不碰远端：不 push、不建 issue、不改仓库设置。

team_config_set_in_file() { # <file> <KEY> <value>
  local f="$1" k="$2" v="$3"
  if grep -q "^$k=" "$f" 2>/dev/null; then
    local esc; esc="$(printf '%s' "$v" | sed -e 's/[&\\|]/\\&/g')"
    sed -i "s|^$k=.*|$k=\"$esc\"|" "$f"
  else
    printf '%s="%s"\n' "$k" "$v" >> "$f"
  fi
}

team_detect_install_cmd() {
  [ -n "${TEAM_INSTALL_CMD:-}" ] && { printf '%s' "$TEAM_INSTALL_CMD"; return 0; }
  local root="$TEAM_MAIN_ROOT"
  if [ -f "$root/pnpm-lock.yaml" ]; then printf 'pnpm install --frozen-lockfile'
  elif [ -f "$root/yarn.lock" ]; then printf 'yarn install --frozen-lockfile'
  elif [ -f "$root/bun.lockb" ] || [ -f "$root/bun.lock" ]; then printf 'bun install --frozen-lockfile'
  elif [ -f "$root/package-lock.json" ]; then printf 'npm ci'
  elif [ -f "$root/pyproject.toml" ] || [ -f "$root/requirements.txt" ]; then printf 'pip install -e . 2>/dev/null || pip install -r requirements.txt'
  elif [ -f "$root/go.mod" ]; then printf 'go mod download'
  else printf ''
  fi
}

team_cmd_bootstrap() {
  local agents="" session="" pmwin="" with_watchdog=1 print_only=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --agents) agents="${2:?}"; shift 2 ;;
      --create-worktrees) TEAM_CREATE_WORKTREE=1; shift ;;
      --session) session="${2:?}"; shift 2 ;;
      --pm-window) pmwin="${2:?}"; shift 2 ;;
      --no-watchdog) with_watchdog=0; shift ;;
      --print) print_only=1; shift ;;
      -*) team_usage_die "bootstrap: 未知参数 $1" ;;
      *) team_usage_die "bootstrap: 多余参数 $1" ;;
    esac
  done

  team_git rev-parse --show-toplevel >/dev/null 2>&1 || team_die "当前目录不在 git 仓库内"
  local project; project="$(basename "$TEAM_MAIN_ROOT")"
  local had_config=0; [ -n "$TEAM_CONFIG" ] && had_config=1

  # ① 探测 PM 自己所在的 tmux session/窗口
  local det_sess="" det_win="" det_cwd=""
  if [ -n "${TMUX:-}" ] && team_have_cmd tmux; then
    det_sess="$(tmux display-message -p '#{session_name}' 2>/dev/null || true)"
    det_win="$(tmux display-message -p '#{window_name}' 2>/dev/null || true)"
    det_cwd="$(tmux display-message -p '#{pane_current_path}' 2>/dev/null || true)"
    # 探测守卫：只有当「当前 tmux pane 的目录就在本项目里」时才认这个 session。
    # 否则（例如测试/门禁在别的项目的 pane 里跑）会把别人的 session 当成自己的场地 ——
    # v1.11.3 实测：smoke 因此把 PM 自己的 session 当成了测试目标。
    case "${det_cwd:-}" in
      "$TEAM_MAIN_ROOT"/*|"$TEAM_MAIN_ROOT") ;;
      *) [ -n "$det_cwd" ] && { det_sess=""; det_win=""; } ;;
    esac
  fi
  session="${session:-${det_sess:-$TEAM_SESSION}}"
  pmwin="${pmwin:-${det_win:-$TEAM_PM_WINDOW}}"
  agents="${agents:-${TEAM_AGENTS:-dev}}"
  local gates; gates="$(team_detect_gates)"
  local install_cmd; install_cmd="$(team_detect_install_cmd)"
  local vcs; vcs="$(team_detect_vcs)"

  team_hdr "pi-team bootstrap · $project"
  printf '  仓库        %s\n' "$TEAM_MAIN_ROOT"
  printf '  tmux        %s:%s%s\n' "$session" "$pmwin" \
     "$([ -n "$det_sess" ] && echo '（探测自当前窗口）' || ([ -n "${TMUX:-}" ] && echo '（当前窗口不属于本项目 → 用配置/项目名）' || echo ''))"
  printf '  名册        %s\n' "$agents"
  printf '  版本控制    %s ｜ 门禁 %s ｜ 安装 %s\n' "$vcs" "${gates:-<无>}" "${install_cmd:-<无>}"
  printf '  看门狗      %s\n' "$([ "$with_watchdog" = "1" ] && echo "tmux 窗口 $(team_slug "$session" 2>/dev/null || echo ''):watchdog（同 session）" || echo '跳过')"

  if [ "$print_only" = "1" ]; then
    printf '\n（--print：只看计划，什么都没改）\n'
    printf '计划步骤：\n'
    printf '  1. %s init --session %s --pm-window %s --agents "%s" --vcs %s\n' "$TEAM_CLI" "$session" "$pmwin" "$agents" "$vcs"
    printf '  2. 把门禁/安装命令写进 .pi/team/config.sh（%s / %s）\n' "${gates:-无}" "${install_cmd:-无}"
    printf '  3. 为每个 agent 建 worktree：%s\n' "$(printf 'add-agent %s; ' $agents)"
    printf '  4. %s watchdog up（看门狗窗口：同 session 的 watchdog 窗口跑 monitor + 定时巡检）\n' "$TEAM_CLI"
    printf '  5. 打印下一步清单\n'
    return 0
  fi

  # ② init（幂等：已有配置不动，只补文档骨架/AGENTS 段落/.gitignore）
  if [ "$had_config" = "1" ]; then
    team_dim "  配置已存在：$TEAM_CONFIG（保留你的设置）"
  else
    team_cmd_init --session "$session" --pm-window "$pmwin" --agents "$agents" --vcs "$vcs" ${gates:+--gates "$gates"}
    team_load_config   # 重新加载（init 刚写了配置）
  fi
  team_require_docs
  [ -n "$TEAM_GATES" ] || { [ -n "$gates" ] && team_config_set_in_file "$TEAM_CONFIG" TEAM_GATES "$gates" && team_info "  写入 TEAM_GATES=$gates"; }
  [ -n "$TEAM_INSTALL_CMD" ] || { [ -n "$install_cmd" ] && team_config_set_in_file "$TEAM_CONFIG" TEAM_INSTALL_CMD "$install_cmd" && team_info "  写入 TEAM_INSTALL_CMD=$install_cmd"; }

  # ③ agent worktree（git 归 PM：默认只打印命令，--create-worktrees 才代建）
  local a
  if [ "${TEAM_CREATE_WORKTREE:-0}" = "1" ]; then
    for a in $agents; do team_worktree_add "$a" --create; done
  else
    team_info ""
    team_info "  ③ 请 PM 执行这些 git 命令（skill 不代做 git；想让它代建就加 --create-worktrees）："
    for a in $agents; do
      local wt; wt="$TEAM_MAIN_ROOT/$(team_agent_worktree "$a" | sed "s|^$TEAM_MAIN_ROOT/||")"
      printf '      git -C %s worktree add -b %s %s %s\n' "$TEAM_MAIN_ROOT" "$(team_agent_branch "$a")" "$wt" "$TEAM_PROTECTED_BRANCH"
    done
  fi

  # ④ 看门狗（PM 负责配置；失败不算致命，只提示）
  if [ "$with_watchdog" = "1" ]; then
    team_info ""
    team_cmd_watchdog up || team_warn "看门狗没起来：稍后再跑 $TEAM_CLI watchdog up（不影响派单）"
  fi

  # ⑤ 下一步清单
  printf '\n'
  team_hdr "下一步（PM 的活）"
  printf '  1) 填 %s/ROADMAP.md（目标/里程碑/退出标准）与 OWNERSHIP.md（目录归属）\n' "$TEAM_DOCS_DIR"
  printf '  2) 建第一个任务：%s task T1.1 --title "…" --agent %s\n' "$TEAM_CLI" "$(printf '%s' "$agents" | awk '{print $1}')"
  printf '     → 编辑任务书（背景/交付物/边界/可复制验收命令）\n'
  printf '  3) 派单：%s dispatch %s T1.1 %s/tasks/T1.1-*.md\n' "$TEAM_CLI" "$(printf '%s' "$agents" | awk '{print $1}')" "$TEAM_DOCS_DIR"
  printf '  4) 看板：%s digest ｜ 看门狗：%s watchdog status\n' "$TEAM_CLI" "$TEAM_CLI"
  printf '  5) 建议把脚手架提交：git add -A && git commit -m "chore: pi-team 初始化"\n'
  printf '\n  约定：看门狗由 PM 配置并维护（%s watchdog up/status/logs）；agent 归 PM 管（%s resume）。\n' "$TEAM_CLI" "$TEAM_CLI"
  return 0
}
