#!/usr/bin/env bash
# teamsmith · bootstrap：一条命令把项目初始化到“可以派单”的状态（幂等，可反复跑）
#
# 设计给 PM 用：PM 在新项目里被启动后的第一件事就是跑它。它会
#   ① 探测当前 tmux session（PM 自己就在里面）→ 写进配置；PM 窗口名一律用约定（pm，M11）   ② init 配置 + 文档骨架 + AGENTS 段落
#   ③ 按名册建 agent worktree                                    ④ 起巡检窗口（PM 负责配置 pulse）
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

# 把「当前窗口」改名成 PM 窗口名（M11）。只在已经证明过这个窗口属于本项目、且目标名没被别的窗口占着时
# 才调用；空目标一律拒绝 —— tmux 的 `-t ""` 等于「当前窗口」，一个空变量就能改错别人的窗口（M6.3 那族）。
team_bootstrap_rename_pm_window() { # <session> <from> <to>
  local sess="${1:-}" from="${2:-}" to="${3:-}"
  [ -n "$sess" ] && [ -n "$from" ] && [ -n "$to" ] || return 1
  tmux rename-window -t "$sess:$from" "$to" 2>/dev/null
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
  local agents="" session="" pmwin="" with_pulse=1 print_only=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --agents) agents="${2:?}"; shift 2 ;;
      --create-worktrees) TEAM_CREATE_WORKTREE=1; shift ;;
      --session) session="${2:?}"; shift 2 ;;
      --pm-window) pmwin="${2:?}"; shift 2 ;;
      --no-pulse) with_pulse=0; shift ;;
      --no-watchdog) with_pulse=0; shift ;;   # 旧旗标（别名期保留到 v2.0.0）：与 --no-pulse 同义
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
  # M11：PM 窗口名是**约定**（TEAM_PM_WINDOW，默认 pm），不是「当前窗口碰巧叫什么」。
  # 旧写法 ${pmwin:-${det_win:-$TEAM_PM_WINDOW}} 把现场当成了约定：配置里写下「当时正好是这样」的名字
  # （本项目实测写进去过 pi），窗口后来一改名，配置和现场就互相撒谎 —— 面板报「PM 窗口缺失」而 PM
  # 明明活着，照着提示 up 还会另开一个窗口（两个 PM）。--pm-window 是人给的约定，照给。
  pmwin="${pmwin:-${TEAM_PM_WINDOW:-pm}}"
  # 现场对齐：当前窗口不叫 pmwin 时把账当场结清 —— 属于本项目、目标名没被占、而且目标就是约定名 pm
  # 时顺手改名；其它情形只把确切的命令打出来，不替人搬窗口。
  local rename_cmd="" rename_note=""
  if [ -n "$det_win" ] && [ "$det_win" != "$pmwin" ]; then
    rename_cmd="tmux rename-window -t $session:$det_win $pmwin"
    if [ "$print_only" = "1" ]; then
      rename_note="当前窗口叫 $det_win ≠ PM 窗口 $pmwin（--print：只看计划）"
    elif [ "$det_sess" != "$session" ]; then
      rename_note="当前窗口叫 $det_win（属于 $det_sess），不是要写的 $session：不代改"
    elif team_tmux_has_window "$session" "$pmwin"; then
      rename_note="当前窗口叫 $det_win，但 $session:$pmwin 已经有窗口了：不代改"
    elif [ "$pmwin" != "pm" ]; then
      rename_note="当前窗口叫 $det_win ≠ 配置里的 PM 窗口 $pmwin：不代改（约定名是 pm）"
    elif team_bootstrap_rename_pm_window "$session" "$det_win" pm; then
      rename_note="当前窗口 $det_win → pm（PM 窗口名是约定，不跟着现场走）"
      rename_cmd=""
    else
      rename_note="当前窗口叫 $det_win，改名失败：请手动改名"
    fi
  fi
  agents="${agents:-${TEAM_AGENTS:-dev}}"
  local gates; gates="$(team_detect_gates)"
  local install_cmd; install_cmd="$(team_detect_install_cmd)"
  local vcs; vcs="$(team_detect_vcs)"

  team_hdr "teamsmith bootstrap · $project"
  printf '  仓库        %s\n' "$TEAM_MAIN_ROOT"
  printf '  tmux        %s:%s%s\n' "$session" "$pmwin" \
     "$([ -n "$det_sess" ] && echo '（探测自当前窗口）' || ([ -n "${TMUX:-}" ] && echo '（当前窗口不属于本项目 → 用配置/项目名）' || echo ''))"
  if [ -n "$rename_note" ]; then printf '      %s\n' "$rename_note"; fi
  if [ -n "$rename_cmd" ]; then printf '      %s\n' "改名：$rename_cmd"; fi
  printf '  名册        %s\n' "$agents"
  printf '  版本控制    %s ｜ 门禁 %s ｜ 安装 %s\n' "$vcs" "${gates:-<无>}" "${install_cmd:-<无>}"
  printf '  巡检        %s\n' "$([ "$with_pulse" = "1" ] && echo "tmux 窗口 $(team_slug "$session" 2>/dev/null || echo ''):$(team_pulse_window)（同 session）" || echo '跳过')"

  if [ "$print_only" = "1" ]; then
    printf '\n（--print：只看计划，什么都没改）\n'
    printf '计划步骤：\n'
    printf '  1. %s init --session %s --pm-window %s --agents "%s" --vcs %s\n' "$TEAM_CLI" "$session" "$pmwin" "$agents" "$vcs"
    printf '  2. 把门禁/安装命令写进 .pi/team/config.sh（%s / %s）\n' "${gates:-无}" "${install_cmd:-无}"
    printf '  3. 为每个 agent 建 worktree：%s\n' "$(printf 'add-agent %s; ' $agents)"
    printf '  4. %s pulse up（巡检窗口：同 session 的 %s 窗口跑 monitor + 定时巡检）\n' "$TEAM_CLI" "$(team_pulse_window)"
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

  # ②b 必需依赖体检（D10）：配置写完后立即查 magic-context 与 OpenSpec；
  # 缺了不阻塞 bootstrap，但每一条都把确切的修复/降级命令打出来。
  local dep_issues; dep_issues="$(team_required_dep_issues)"
  if [ -n "$dep_issues" ]; then
    team_info ""
    team_warn "必需依赖还没就绪（不阻塞 bootstrap；装好之前 doctor 会失败）："
    printf '%s\n' "$dep_issues" | sed 's/^/      - /'
  fi

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

  # ④ 巡检（PM 负责配置；失败不算致命，只提示）
  if [ "$with_pulse" = "1" ]; then
    team_info ""
    team_cmd_pulse up || team_warn "巡检没起来：稍后再跑 $TEAM_CLI pulse up（不影响派单）"
  fi

  # ⑤ 下一步清单
  printf '\n'
  team_hdr "下一步（PM 的活）"
  printf '  1) 填 %s/ROADMAP.md（目标/里程碑/退出标准）与 OWNERSHIP.md（目录归属）\n' "$TEAM_DOCS_DIR"
  printf '  2) 建第一个任务：%s task T1.1 --title "…" --agent %s\n' "$TEAM_CLI" "$(printf '%s' "$agents" | awk '{print $1}')"
  printf '     → 编辑任务书（背景/交付物/边界/可复制验收命令）\n'
  printf '  3) 派单：%s dispatch %s T1.1 %s/tasks/T1.1-*.md\n' "$TEAM_CLI" "$(printf '%s' "$agents" | awk '{print $1}')" "$TEAM_DOCS_DIR"
  printf '  4) 看板：%s digest ｜ 巡检：%s pulse status\n' "$TEAM_CLI" "$TEAM_CLI"
  printf '  5) 建议把脚手架提交：git add -A && git commit -m "chore: teamsmith 初始化"\n'
  printf '\n  约定：pulse 由 PM 配置并维护（%s pulse up/status/logs）；agent 归 PM 管（%s resume）。\n' "$TEAM_CLI" "$TEAM_CLI"
  return 0
}
