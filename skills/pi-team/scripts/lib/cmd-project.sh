#!/usr/bin/env bash
# pi-team · init / doctor / help

team_help() {
  cat <<'EOF'
pi-team — 用 Pi Agent 组建一个可复用的多 Agent 团队（PM 编排 + worker 并行）

用法： team <command> [args...] [--yes]

  ── 第一次使用 ─────────────────────────────────────────────
  bootstrap [--agents "dev verify"] [--print]   **推荐**：一条命令把项目初始化到可派单状态
                   （探测当前 tmux session/窗口 → 写配置 + 文档骨架 + AGENTS 段落 → 建 agent worktree
                    → 起看门狗窗口 → 打印下一步清单）；幂等，可反复跑
  init            只做配置/文档骨架（bootstrap 的其中一步）
  doctor          环境自检（git/tmux/pi/门禁/forge/容量/容器）

  ── 观察 ───────────────────────────────────────────────────
  roster          名册：agent、窗口是否在跑、分支、脏文件、领先提交数
  status [ID]     roster + 任务/report 状态；给 ID 时只显示该任务
  ps              容量：RAM/swap/还能再跑几个 agent + 模型并发占用（派单前看）
  digest          给 PM 的待办摘要：收件箱未处理项 + 待复验报告 + 任务状态
  inbox [agent]   打印收件箱（agent 在回合结束时自动追加）
  paths           打印当前解析出的路径/ session（JSON），排障用

  ── 文档契约（PM 维护） ─────────────────────────────────────
  task ID --title ... [--agent a] [--deps ...] [--issue N]
                  生成任务书 <docs>/tasks/ID-slug.md 并在 BOARD.md 建行
  board add|set|row|ls    BOARD.md 行管理（add / set ID 状态 / row ID / ls）
  thread <agent> ["msg"]   追加 / 读取消息线程（append-only）
  report ID <agent> [--force]  生成报告骨架

  ── 派单与协作 ─────────────────────────────────────────────
  add-agent <a> [--model m]    建长期 worktree（分支 agent/<a>）
  dispatch <a> <ID> <task-file> [--model m] [--fresh] [--print]
                  在 tmux 窗口起一个交互式 pi（默认复用会话，可断点续跑）
  say <a> "<一句话>"           往 agent 窗口发消息
  notify <a> "<一句话>"        agent → PM 一句话（写收件箱 + 唤醒 PM 窗口）

  ── 定时巡检与看门狗（看门狗由 PM 配置和维护） ───────────────
  watchdog up|down|restart|status|logs [--print]
                 看门狗（同 session 的 watchdog 窗口跑 monitor + 定时巡检；只有一个后端，无容器依赖）
  watchdog-status               `watchdog status` 的旧名
  monitor [--once] [--interval N] [--events K]  状态监视器（watchdog 窗口跑的就是它）：
                 团队状态 + 每个 agent 的会话活动流；按周期顺带跑巡检
  watch [--once] [--interval N] [--ui]      手动/前台巡检（--ui = monitor）
  standby [on|off|status] [--reason "..."]  PM 主动停工：on 之后看门狗不再叫醒（人处理完 off）

  ── 跨项目会议（PM 对 PM 的 peer 交流，不是指令通道） ─────────
  meeting open <slug> --with <项目>[:<session>] --topic "…" [--ttl 72] [--yes]
  meeting say <slug> --intent <info|question|report|proposal|request> "…" [--knock]
  meeting read <slug> [--since N] [--peek] ｜ meeting inbox ｜ meeting list [--all]
  meeting propose <slug> "…" ｜ meeting agree <slug> <A1> [--note "…"] ｜ meeting close <slug>
  up [--agents] [--print]      恢复 PM：建 tmux 场地 + 把 PM 拉起来（pi -c 保留历史）
  resume [--agent a] [--all] [--dry-run]   PM 的工具：把停了但没交活的 agent 续跑

  ── 复验 / 合并 / 收尾 ─────────────────────────────────────
  review ID --dir <独立checkout> [--no-gates] [--strong]
                  独立 detached worktree 上 checkout 分支 → 跑门禁 → 写
                  <docs>/reviews/ID.md（PM 复验证据，不接受 agent 自述）
  close ID                              收尾：更新 BOARD、关窗口、保留 worktree（git 由 PM 做）
  teardown [--agent a] [--all] [--purge]  关窗口 / 删 worktree（--purge 才删 worktree）

  smoke           在临时仓库里端到端自测这套工具（不碰当前项目）
  ── 版本与更新（skill 更新怎么拿到） ─────────────────────────
  mark-loaded [--version X]   记录本会话加载的 skill 版本（PM 开局跑一次）
  version [--check]           看磁盘版本 / SKILL.md 版本 / CHANGELOG / 本会话加载版本；--check 给结论
  changelog [--since X]       看 skill 变更史
  reload [--done]             请求重载（在 Pi 里 /reload 或 /pi-team-reload 立即生效）
  version / help

配置：项目根 .pi/team/config.sh（见 references/config.md）。
协议：<docs>/PROTOCOL.md 或 SKILL.md 里的一页速览。
EOF
}

# ---------------------------------------------------------------- init
team_write_section() { # <file> <begin-marker> <end-marker> <content-file>
  local target="$1" begin="$2" end="$3" content="$4"
  mkdir -p "$(dirname "$target")"
  [ -f "$target" ] || : > "$target"
  if grep -qF "$begin" "$target"; then
    awk -v b="$begin" -v e="$end" -v cf="$content" '
      $0==b { inb=1; print; while ((getline l < cf) > 0) { if (l==b || l==e) continue; print l }; close(cf); next }
      inb   { if ($0==e) { inb=0; print }; next }
      { print }
    ' "$target" > "$target.tmp" && mv "$target.tmp" "$target"
    team_ok "update $target（协议段落已刷新）"
  else
    { [ -s "$target" ] && printf '\n'; printf '%s\n' "$begin"; grep -vFxf <(printf '%s\n%s\n' "$begin" "$end") "$content"; printf '%s\n' "$end"; } >> "$target"
    team_ok "append $target（团队协议段落）"
  fi
}

team_gitignore_add() { # <entry> ...
  local f="$TEAM_MAIN_ROOT/.gitignore" e added=0
  touch "$f"
  grep -q '^# pi-team' "$f" || { printf '\n# pi-team\n' >> "$f"; }
  for e in "$@"; do
    grep -qxF "$e" "$f" && continue
    printf '%s\n' "$e" >> "$f"
    added=$((added + 1))
  done
  [ "$added" -gt 0 ] && team_ok "update .gitignore（$added 条）" || team_dim "skip  .gitignore"
  return 0
}

team_detect_gates() {
  [ -n "$TEAM_GATES" ] && { printf '%s' "$TEAM_GATES"; return; }
  local pm="-"
  [ -f "$TEAM_MAIN_ROOT/pnpm-lock.yaml" ] && pm="pnpm"
  [ -f "$TEAM_MAIN_ROOT/yarn.lock" ] && pm="yarn"
  [ -f "$TEAM_MAIN_ROOT/bun.lockb" ] && pm="bun"
  [ -f "$TEAM_MAIN_ROOT/package-lock.json" ] && pm="npm"
  if [ -f "$TEAM_MAIN_ROOT/package.json" ]; then
    if grep -q '"verify"[[:space:]]*:' "$TEAM_MAIN_ROOT/package.json"; then
      case "$pm" in pnpm) printf 'pnpm verify' ;; yarn) printf 'yarn verify' ;; bun) printf 'bun run verify' ;; *) printf 'npm run verify' ;; esac
      return
    fi
    if grep -q '"test"[[:space:]]*:' "$TEAM_MAIN_ROOT/package.json"; then
      case "$pm" in pnpm) printf 'pnpm test' ;; yarn) printf 'yarn test' ;; bun) printf 'bun test' ;; *) printf 'npm test' ;; esac
      return
    fi
  fi
  printf ''
}

team_detect_vcs() {
  local url; url="$(team_git remote get-url origin 2>/dev/null || true)"
  case "$url" in
    *github.com*) printf 'github' ;;
    *gitlab*)     printf 'gitlab' ;;
    *)            printf 'local' ;;
  esac
}

team_cmd_init() {
  local session="" agents="" vcs="" gates="" docs="" pmwin="" model="" force=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --session) session="${2:?}"; shift 2 ;;
      --agents) agents="${2:?}"; shift 2 ;;
      --vcs) vcs="${2:?}"; shift 2 ;;
      --gates) gates="${2:?}"; shift 2 ;;
      --docs) docs="${2:?}"; shift 2 ;;
      --pm-window) pmwin="${2:?}"; shift 2 ;;
      --model) model="${2:?}"; shift 2 ;;
      --force) force=1; shift ;;
      *) team_usage_die "init: 未知参数 $1" ;;
    esac
  done

  local project; project="$(basename "$TEAM_MAIN_ROOT")"
  session="${session:-$project}"
  agents="${agents:-dev verify}"
  vcs="${vcs:-$(team_detect_vcs)}"
  docs="${docs:-docs/team}"
  pmwin="${pmwin:-pm}"
  model="${model:-deepseek/deepseek-flash}"
  gates="${gates:-$(team_detect_gates)}"

  team_hdr "pi-team init → $TEAM_MAIN_ROOT"

  # 1) 配置
  TEAM_AGENTS="$agents"; TEAM_DOCS_DIR="$docs"
  local cfg="$TEAM_MAIN_ROOT/.pi/team/config.sh" tmpl; tmpl="$(team_tmpl_dir)/config.sh.tmpl"
  if [ -f "$cfg" ] && [ "$force" != "1" ]; then
    team_dim "skip  $cfg（已存在，--force 覆盖）"
  else
    mkdir -p "$(dirname "$cfg")"
    team_render "$tmpl" \
      "PROJECT=$project" "SESSION=$session" "PM_WINDOW=$pmwin" \
      "DOCS_DIR=$docs" "AGENTS=$agents" "GATES=$(team_escape_dq "$gates")" "VCS=$vcs" \
      "DEFAULT_MODEL=$model" "SKILL_DIR=$TEAM_SKILL_DIR" \
      "DETECTED_VCS=$(team_detect_vcs)" "TODAY=$(date +%F)" > "$cfg"
    team_ok "write $cfg"
  fi
  chmod 0644 "$cfg"

  # 2) 文档骨架
  local tdir; tdir="$(team_tmpl_dir)"
  TEAM_DOCS_ABS="$TEAM_MAIN_ROOT/$docs"
  mkdir -p "$TEAM_DOCS_ABS"/{tasks,reports,threads,inbox,reviews}
  team_render_to "$tdir/BOARD.md.tmpl"          "$TEAM_DOCS_ABS/BOARD.md"          "$force" "PROJECT=$project" "TODAY=$(date +%F)"
  team_render_to "$tdir/ROADMAP.md.tmpl"        "$TEAM_DOCS_ABS/ROADMAP.md"        "$force" "PROJECT=$project"
  team_render_to "$tdir/OWNERSHIP.md.tmpl"      "$TEAM_DOCS_ABS/OWNERSHIP.md"      "$force" "PROJECT=$project"
  team_render_to "$tdir/DECISIONS.md.tmpl"      "$TEAM_DOCS_ABS/DECISIONS.md"      "$force" "PROJECT=$project" "TODAY=$(date +%F)"
  team_render_to "$tdir/threads-README.md"      "$TEAM_DOCS_ABS/threads/README.md" "$force" "PROJECT=$project" "AGENTS=$agents"
  team_render_to "$tdir/PROTOCOL.md.tmpl"       "$TEAM_DOCS_ABS/PROTOCOL.md"       "$force" \
    "PROJECT=$project" "DOCS_DIR=$docs" "WORKTREES_DIR=$(basename "${TEAM_WORKTREES_DIR:-.worktrees}")" \
    "SKILL_DIR=$TEAM_SKILL_DIR" "GATES=${gates:-<未配置>}" "SESSION=$session"
  for d in tasks reports reviews; do
    [ -f "$TEAM_DOCS_ABS/$d/.gitkeep" ] || : > "$TEAM_DOCS_ABS/$d/.gitkeep"
  done
  printf '# 临时收件箱：agent 回合结束自动追加，不入库\n*\n' > "$TEAM_DOCS_ABS/inbox/.gitignore"
  printf '# 复验日志：本地证据，不入库\n*.log\n' > "$TEAM_DOCS_ABS/reviews/.gitignore"

  # 3) AGENTS.md 协议段落
  local section; section="$(mktemp)"
  team_render "$tdir/AGENTS.section.md.tmpl" \
    "PROJECT=$project" "DOCS_DIR=$docs" "SESSION=$session" "PM_WINDOW=$pmwin" \
    "SKILL_DIR=$TEAM_SKILL_DIR" "AGENTS=$agents" "GATES=${gates:-<未配置>}" \
    "WORKTREES_DIR=${TEAM_WORKTREES_DIR:-.worktrees}" "PROTECTED_BRANCH=main" > "$section"
  team_write_section "$TEAM_MAIN_ROOT/AGENTS.md" \
    "<!-- pi-team:begin -->" "<!-- pi-team:end -->" "$section"
  rm -f "$section"

  # 4) .gitignore
  # token 文件必须默认忽略（PAT 泄漏是最容易犯的事）
  team_gitignore_add ".pi/team/state/" "$docs/inbox/" "$docs/reviews/*.log" "${TEAM_WORKTREES_DIR:-.worktrees}/" \
    "${TEAM_TOKEN_FILE:-.gh-pat}" "${TEAM_GITLAB_TOKEN_FILE:-.gitlab-pat}"

  printf '\n'
  team_hdr "下一步"
  printf '  1) %s doctor\n' "$TEAM_CLI"
  printf '  2) 编辑 %s/.pi/team/config.sh（名册 TEAM_AGENTS、门禁 TEAM_GATES、模型）\n' "$project"
  printf '  3) %s task T1.1 --title "第一个任务" --agent dev\n' "$TEAM_CLI"
  printf '  4) %s dispatch dev T1.1 %s/tasks/T1.1-*.md\n' "$TEAM_CLI" "$docs"
  printf '  5) %s digest   # PM 看板\n' "$TEAM_CLI"
}

# ---------------------------------------------------------------- doctor
team_cmd_doctor() {
  local fails=0 warns=0
  check() { printf '  %-24s ' "$1"; }
  pass()  { printf '%s✓%s %s\n' "$C_GRN" "$C_RESET" "${1:-}"; }
  warn()  { printf '%s!%s %s\n' "$C_YEL" "$C_RESET" "$1"; warns=$((warns + 1)); }
  fail()  { printf '%s✗%s %s\n' "$C_RED" "$C_RESET" "$1"; fails=$((fails + 1)); }

  team_hdr "pi-team doctor · $TEAM_PROJECT"
  printf '%s\n' "  skill: $TEAM_SKILL_DIR ($TEAM_VERSION)  main: $TEAM_MAIN_ROOT"

  check "config"; if [ -n "$TEAM_CONFIG" ]; then pass "$TEAM_CONFIG"; else warn "未找到 .pi/team/config.sh（先跑 $TEAM_CLI init）"; fi
  check "docs 骨架"; if [ -d "$TEAM_DOCS_ABS" ]; then pass "$TEAM_DOCS_DIR"; else fail "缺 $TEAM_DOCS_DIR/（先跑 $TEAM_CLI init）"; fi
  check "bash"; if [ "${BASH_VERSINFO[0]}" -ge 4 ]; then pass "${BASH_VERSION%%(*}"; else fail "需要 bash >= 4"; fi
  check "git"; if team_have_cmd git; then pass "$(git --version | awk '{print $3}')"; else fail "缺 git"; fi

  check "tmux"; if team_have_cmd tmux; then
      if team_tmux_has_session "$TEAM_SESSION"; then pass "session $TEAM_SESSION 在运行"
      else warn "tmux 在，但 session '$TEAM_SESSION' 不存在（dispatch 会创建；PM 需要在 <session>:<pm-window> 里跑）"; fi
    else warn "无 tmux：agent 无法交互旁观，仅支持 -p 非交互（不建议）"; fi

  check "pi"; if team_have_cmd pi; then
      local pv; pv="$(pi --version 2>/dev/null | head -1 || true)"
      if pi --help 2>/dev/null | grep -q -- '--session-id'; then pass "${pv:-present}"; else fail "pi 版本过旧：缺 --session-id"; fi
    else fail "缺 pi（PATH 里没有）"; fi

  check "门禁 TEAM_GATES"; if [ -n "$TEAM_GATES" ]; then pass "$TEAM_GATES"; else warn "未配置门禁命令：复验无法自动判定，只能靠人读 diff"; fi
  check "名册 TEAM_AGENTS"; if [ -n "$(team_agents)" ]; then pass "$(team_agents | tr '\n' ' ')"; else fail "名册为空"; fi

  check "worktree 目录"; if [ -d "$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR" ]; then
      pass "$(ls -1 "$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR" 2>/dev/null | wc -l) 个"
    else warn "尚未创建 $TEAM_WORKTREES_DIR/（add-agent 时创建）"; fi

  check "notify 扩展"; local ext="$TEAM_SKILL_DIR/extension/team-notify.ts"
    if [ -f "$ext" ]; then
      local tsrunner; tsrunner="$(team_ts_runner)"
      if [ -n "$tsrunner" ] && $tsrunner -e "await import('$ext')" >/dev/null 2>&1; then
        pass "可加载（$tsrunner 预检通过；worktree 里需 -e 显式加载）"
      elif [ -n "$tsrunner" ]; then
        pass "存在（$tsrunner 未能预检，pi 内部用打包器，通常仍可用）"
      else
        pass "存在（本机无 node/bun/tsx 可预检）"
      fi
    else fail "缺 $ext"; fi

  # PM 记忆（可选但推荐）：magic-context 是 Pi 侧扩展（npm 包），PM 靠它做跨会话记忆/检索。
  # 这里只读 settings.json 的 packages 与包自身版本，不做任何安装/改动。
  check "PM 记忆（可选）"
  local mc_settings="$TEAM_PI_SETTINGS_FILE" mc_pkg mc_ver
  if [ -f "$mc_settings" ] && grep -q 'pi-magic-context' "$mc_settings" 2>/dev/null; then
    mc_pkg="$HOME/.pi/agent/npm/node_modules/@cortexkit/pi-magic-context/package.json"
    mc_ver="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$mc_pkg" 2>/dev/null | head -1)"
    pass "magic-context ${mc_ver:-?}（跨会话记忆可用：ctx_search / ctx_memory / ctx_note）"
  elif [ "${TEAM_REQUIRE_MAGIC_CONTEXT:-0}" = "1" ]; then
    fail "TEAM_REQUIRE_MAGIC_CONTEXT=1 但没检测到 magic-context（配置：$mc_settings）"
  else
    warn "未检测到 magic-context：PM 长会话只能靠 /compact + 落盘（不阻塞；装上更好，见 references/philosophy.md 第 6 条）"
  fi

  check "容量 / swap 底线"; local avail swapfree swaptotal
    read -r avail swapfree swaptotal <<< "$(team_mem_stats)"
    if [ -n "$avail" ] && [ "${avail:-0}" -gt 0 ] 2>/dev/null; then
      if [ "$TEAM_MIN_FREE_SWAP_MB" -gt 0 ] && [ "$swapfree" -lt "$TEAM_MIN_FREE_SWAP_MB" ]; then
        warn "空闲 swap ${swapfree}MB < 底线 ${TEAM_MIN_FREE_SWAP_MB}MB：现在派单会被拒绝"
      else
        pass "$(team_capacity_line)"
      fi
    else warn "无法探测内存/swap（可设 TEAM_MEMINFO_FILE 指定 meminfo 文件）"; fi

  check "PM 存活"; local pmstate; pmstate="$(team_pm_state)"
    case "$pmstate" in
      running:*) pass "pi 在运行（${pmstate#running:}）" ;;
      idle:*)    warn "窗口 $TEAM_SESSION:$TEAM_PM_WINDOW 停在 ${pmstate#idle:}：PM 没在跑 → team up" ;;
      *)         warn "PM 窗口 $TEAM_SESSION:$TEAM_PM_WINDOW 不存在 → team up" ;;
    esac

  check "看门狗"; case "$(team_watchdog_state)" in
      off) warn "没在跑 → $TEAM_CLI watchdog up（看门狗由 PM 配置）" ;;
      *)   pass "$(team_watchdog_state_text)" ;;
    esac

  # forge：不探测、不假设（v1.12.0 起 skill 与 forge 完全解耦）
  # PM 自己用 git / curl / gh / glab / 网页；这里只把项目登记的标签打出来，缺命令行工具不算问题。
  check "forge"; case "$TEAM_VCS" in
      local|"") pass "local（不依赖 forge；合并由 PM 用 git 完成）" ;;
      *)        pass "$TEAM_VCS（仅登记：PM 自己用 git/curl/任意 CLI 调 forge，skill 不参与）" ;;
    esac

  check "保护分支"; if team_git rev-parse --verify -q "$TEAM_PROTECTED_BRANCH" >/dev/null; then
      pass "$TEAM_PROTECTED_BRANCH @ $(team_git rev-parse --short "$TEAM_PROTECTED_BRANCH")"
    else warn "本地没有分支 $TEAM_PROTECTED_BRANCH（配置对吗？）"; fi

  check "gitignore"; local missing=0 e
    for e in ".pi/team/state/" "$TEAM_DOCS_DIR/inbox/" "${TEAM_WORKTREES_DIR}/"; do
      grep -qxF "$e" "$TEAM_MAIN_ROOT/.gitignore" 2>/dev/null || missing=$((missing + 1))
    done
    if [ "$missing" -eq 0 ]; then pass "临时目录已忽略"; else warn "$missing 条未忽略（收件箱/worktree 会被误提交）"; fi

  check "陈旧 state"; local stale=0 a w
    for a in $(team_agents); do
      w="$(team_state_get "$a" window "$a")"
      if [ -f "$TEAM_STATE_DIR/$a.env" ] && ! team_tmux_has_window "$TEAM_SESSION" "$w"; then stale=$((stale + 1)); fi
    done
    if [ "$stale" -eq 0 ]; then pass "干净"; else warn "$stale 个 agent 的 state 与 tmux 不一致（roster 会自动清理）"; fi

  printf '\n'
  if [ "$fails" -gt 0 ]; then team_err "doctor: $fails 项失败 / $warns 项警告"; return 1; fi
  if [ "$warns" -gt 0 ]; then team_warn "doctor: 0 项失败 / $warns 项警告（可继续）"; return 0; fi
  team_ok "doctor: 全部通过"
}
