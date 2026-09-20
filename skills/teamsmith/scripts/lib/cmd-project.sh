#!/usr/bin/env bash
# teamsmith · init / doctor / help

team_help() {
  cat <<'EOF'
teamsmith — 用 Pi Agent 组建一个可复用的多 Agent 团队（PM 编排 + worker 并行）

用法： team <command> [args...] [--yes]

  ── 第一次使用 ─────────────────────────────────────────────
  bootstrap [--agents "dev verify"] [--print]   **推荐**：一条命令把项目初始化到可派单状态
                   （探测当前 tmux session/窗口 → 写配置 + 文档骨架 + AGENTS 段落 → 建 agent worktree
                    → 起巡检窗口 → 打印下一步清单）；幂等，可反复跑
  init            只做配置/文档骨架（bootstrap 的其中一步）
  doctor          环境自检（git/tmux/pi/门禁/forge/容量/容器）

  ── 观察 ───────────────────────────────────────────────────
  roster          名册：agent、窗口是否在跑、分支、脏文件、领先提交数
  status [ID]     roster + 任务/report 状态；给 ID 时只显示该任务
  ps              容量：RAM/swap/还能再跑几个 agent + 模型并发占用（派单前看）
  digest          给 PM 的待办摘要：收件箱未处理项 + 待复验报告 + 任务状态
  inbox [agent]   打印收件箱（agent 在回合结束时自动追加）
  paths           打印当前解析出的路径/ session（JSON），排障用
  config list|set|log|set-agent-model
                  项目契约（.pi/team/config.sh）的读写面：list 列每个键的效果类（apply/restart/refuse）
                  与默认值；set 是**唯一写入口**（值校验 + sha256 指纹 CAS + 原子写 + 审计）；
                  log 看审计尾部；set-agent-model 按席位改模型（- 移除覆盖）

  ── 文档契约（PM 维护） ─────────────────────────────────────
  task ID --title ... [--agent a] [--deps ...] [--issue N]
                  生成任务书 <docs>/tasks/ID-slug.md 并在 BOARD.md 建行
  board add|set|row|ls    BOARD.md 行管理（add / set ID 状态 / row ID / ls）
  thread <agent> ["msg"]   追加 / 读取往来记录（append-only）
  report ID <agent> [--force]  生成报告骨架

  ── 派单与协作 ─────────────────────────────────────────────
  add-agent <a> [--model m]    建长期 worktree（分支 agent/<a>）
  dispatch <a> <ID> <task-file> [--model m] [--fresh] [--allow-overflow] [--print]
                  在 tmux 窗口起一个交互式 pi（默认复用会话，可断点续跑）
  say <a> "<一句话>" [--now]      往 agent 窗口发消息；目标输入框里有草稿就**延后投递**（state/outbox/
                   + 返回 queued）；--now = 故意跳过守卫粘字（记入 outbox/forced.log）
  notify <a> "<一句话>"        agent → PM 一句话（写收件箱 + 唤醒 PM 窗口；草稿窗口忙则入队）
  draft [pm]                  人的草稿入口：开/复用 draft 窗口跑 $EDITOR，保存退出后自动入队（不抢焦点）
  draft send [<文件>] [--now] 无头形式：把草稿文件整段投递（守卫路径）
  outbox [list]               延后队列：待投递条目（活动 + held，编号供 drop）
  outbox flush [--now]        立刻排水（--now = 跳过守卫直投，留审计）
  outbox drop <n|all>        人显式丢弃队列条目

  ── 定时巡检（pulse 由 PM 配置和维护） ────────────────────
  pulse up|down|restart|status|logs [--print]
                 巡检（同 session 的 pulse 窗口跑 monitor + 定时巡检；只有一个后端，无容器依赖）
  watchdog …／watchdog-status／install-watchdog／uninstall-watchdog
                 pulse 的旧名（别名期保留到 v2.0.0；先印一行弃用提示，再转交 pulse）
  monitor [--once] [--print|--json] [--width N] [--height N] [--interval N] [--events K] [--no-pulse]
                 状态面板（pulse 窗口跑的就是它）：默认 TUI（Ink），管道/--print 出纯文本，--json 出机读对象；
                 非 TTY 自动走纯文本；按周期顺带跑巡检（--no-pulse = 只看不巡）。需要 node/bun/tsx（D19）
  watch [--once] [--interval N] [--ui]      手动/前台巡检（--ui = monitor）
  standby [on|off|status] [--reason "..."]  PM 主动停工：on 之后 pulse 不再叫醒（人处理完 off）

  ── 跨项目会议（PM 对 PM 的 peer 交流，不是指令通道） ─────────
  meeting open <slug> --with <项目>[:<session>] --topic "…" [--ttl 72] [--yes]
  meeting say <slug> --intent <info|question|report|proposal|request> "…" [--knock]
  meeting read <slug> [--since N] [--peek] ｜ meeting inbox ｜ meeting list [--all]
  meeting propose <slug> "…" ｜ meeting agree <slug> <A1> [--note "…"] ｜ meeting close <slug>
  up [--agents] [--print]      恢复 PM：建 tmux 场地 + 把 PM 拉起来（pi -c 保留历史）
  resume [--agent a] [--all] [--dry-run]   PM 的工具：把停了但没交活的 agent 续跑

  ── 复验 / 合并 / 收尾 ─────────────────────────────────────
  review ID --dir <独立checkout> [--no-gates] [--strong] [--allow-unresolved-branch]
                  独立 detached worktree 上 checkout 分支 → 跑门禁 → 写
                  <docs>/reviews/ID.md（PM 复验证据，不接受 agent 自述）
                  脏树 / 被忽略产物 / --branch 解析不到 → 默认拒绝（覆盖开关 TEAM_REVIEW_ALLOW_*）
  close ID                              收尾：更新 BOARD、关窗口、保留 worktree（git 由 PM 做）
  teardown [--agent a] [--all] [--purge]  关窗口 / 删 worktree（--purge 才删 worktree）

  smoke           在临时仓库里端到端自测这套工具（不碰当前项目）
  ── 版本与更新（skill 更新怎么拿到） ─────────────────────────
  mark-loaded [--version X]   记录本会话加载的 skill 版本（PM 开局跑一次）
  version [--check]           看磁盘版本 / SKILL.md 版本 / CHANGELOG / 本会话加载版本；--check 给结论
  changelog [--since X]       看 skill 变更史
  reload [--done]             请求重载（在 Pi 里 /reload 或 /teamsmith-reload 立即生效）
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
  grep -q '^# teamsmith' "$f" || { printf '\n# teamsmith\n' >> "$f"; }
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

  # 门禁值是契约里的一个键（P21 任务 1.7）：写入前用唯一校验器验一遍。旧行为是把它塞进模板就完事，
  # 值里带 `#` 时 notify 读取器会截断、带换行时契约直接坏掉，而 init 照样报成功。
  if [ -n "$gates" ]; then
    local gates_reason
    if ! gates_reason="$(team_config_validate_value TEAM_GATES "$gates")"; then
      team_err "init: --gates 的值不能写进契约（$gates_reason）"
      team_dim "  契约是单行 KEY='value' 文件：不能含换行或 #；要么换一个能表示的值，要么手改 .pi/team/config.sh"
      return 1
    fi
  fi

  team_hdr "teamsmith init → $TEAM_MAIN_ROOT"

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
  # 旧名标记迁移（<=1.12 的项目 AGENTS.md 里是 pi-team:begin/end）：
  # 就地换成新标记，这样 team_write_section 认得出"段落已存在"，不会重复注入。
  local _agents="$TEAM_MAIN_ROOT/AGENTS.md"
  if [ -f "$_agents" ] \
     && grep -qF '<!-- pi-team:begin -->' "$_agents" \
     && ! grep -qF '<!-- teamsmith:begin -->' "$_agents"; then
    sed -i 's|<!-- pi-team:begin -->|<!-- teamsmith:begin -->|; s|<!-- pi-team:end -->|<!-- teamsmith:end -->|' "$_agents"
  fi
  team_write_section "$TEAM_MAIN_ROOT/AGENTS.md" \
    "<!-- teamsmith:begin -->" "<!-- teamsmith:end -->" "$section"
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
# M7.1：这个项目要不要读迁移指南？两个判据都来自可查的真实状态，不猜：
#   ① AGENTS.md 里还是旧名标记 <!-- pi-team:begin -->（init/bootstrap 会就地改写；改写后不再触发）
#   ② 本会话加载的 skill 比磁盘旧（mark-loaded 记的版本/指纹与磁盘不一致）—— 与 version --check 同口径
# 干净项目上保持静默（doctor 不该多刷一行）；返回原因字符串，没有原因则返回空。
team_migration_reasons() {
  local reasons="" f="$TEAM_MAIN_ROOT/AGENTS.md" loaded
  if [ -f "$f" ] && grep -qF '<!-- pi-team:begin -->' "$f"; then
    reasons="AGENTS.md 还是旧名标记"
  fi
  loaded="$(team_loaded_version 2>/dev/null || true)"
  if [ -n "$loaded" ] \
     && { [ "$loaded" != "$TEAM_VERSION" ] || [ "$(team_loaded_hash 2>/dev/null || true)" != "$(team_skill_hash 2>/dev/null || true)" ]; }; then
    reasons="${reasons:+$reasons；}本会话加载 $loaded、磁盘 $TEAM_VERSION"
  fi
  [ -n "$reasons" ] && printf '%s' "$reasons"
  return 0
}

# ---------------------------------------------------------------- PM 窗口名漂移（M11）
# 「配置里的 PM 窗口名」与「现场窗口」不符时，医生必须把这句人话说出来：
# 事故（本项目实测）：bootstrap 把当时窗口碰巧的名字写进配置（写成 pi），窗口后来被改回 pm、配置不改 ——
# 面板报「PM 窗口缺失」而 PM 明明活着；更糟的是照着「→ team up」会照配置另开一个窗口（两个 PM）。
# 判据与 team_pm_state 的「人工启动的 PM」同一标准（argv 命中配置的 PM CLI + cwd 在本项目里），
# 再排掉名册 / 巡检 / 草稿窗口（它们跑的是同一个 agent 可执行文件）。认不出来就返回空 ——
# 这条检查宁可沉默，也不许猜一个窗口名字出来。
team_is_agentish_window() { # <窗口名> → 0 = 名册 / 巡检 / 草稿窗口（不能当成 PM 现场）
  local w="${1:-}" a
  [ -n "$w" ] || return 1
  [ "$w" = "$(team_pulse_window)" ] && return 0
  case "$w" in pulse|watchdog|draft) return 0 ;; esac
  for a in $(team_agents); do
    [ "$w" = "$a" ] && return 0
    [ "$w" = "$(team_state_get "$a" window "$a")" ] && return 0
  done
  return 1
}

team_pm_window_drift() { # → 现场像 PM 的窗口名（空格分隔，可能多个）；没有则空
  local w pid cwd out=""
  team_have_cmd tmux || return 0
  team_tmux_has_session "$TEAM_SESSION" || return 0
  while IFS= read -r w; do
    [ -n "$w" ] || continue
    [ "$w" = "$TEAM_PM_WINDOW" ] && continue
    team_is_agentish_window "$w" && continue
    pid="$(team_pm_pane_agent_pid "$TEAM_SESSION:$w" 2>/dev/null || true)"
    [ -n "$pid" ] || continue
    cwd="$(team_proc_cwd "$pid" 2>/dev/null || true)"
    [ -n "$cwd" ] || continue
    team_cwd_in_project "$cwd" || continue
    out="${out:+$out }$w"
  done < <(team_tmux_windows "$TEAM_SESSION")
  [ -n "$out" ] && printf '%s\n' "$out"
  return 0
}

team_cmd_doctor() {
  local fails=0 warns=0
  check() { printf '  %-24s ' "$1"; }
  pass()  { printf '%s✓%s %s\n' "$C_GRN" "$C_RESET" "${1:-}"; }
  warn()  { printf '%s!%s %s\n' "$C_YEL" "$C_RESET" "$1"; warns=$((warns + 1)); }
  fail()  { printf '%s✗%s %s\n' "$C_RED" "$C_RESET" "$1"; fails=$((fails + 1)); }

  team_hdr "teamsmith doctor · $TEAM_PROJECT"
  printf '%s\n' "  skill: $TEAM_SKILL_DIR ($TEAM_VERSION)  main: $TEAM_MAIN_ROOT"

  check "config"; if [ -n "$TEAM_CONFIG" ]; then pass "$TEAM_CONFIG"; else warn "未找到 .pi/team/config.sh（先跑 $TEAM_CLI init）"; fi
  check "docs 骨架"; if [ -d "$TEAM_DOCS_ABS" ]; then pass "$TEAM_DOCS_DIR"; else fail "缺 $TEAM_DOCS_DIR/（先跑 $TEAM_CLI init）"; fi
  check "bash"; if [ "${BASH_VERSINFO[0]}" -ge 4 ]; then pass "${BASH_VERSION%%(*}"; else fail "需要 bash >= 4"; fi
  check "git"; if team_have_cmd git; then pass "$(git --version | awk '{print $3}')"; else fail "缺 git"; fi

  check "tmux"; if team_have_cmd tmux; then
      if team_tmux_has_session "$TEAM_SESSION"; then pass "session $TEAM_SESSION 在运行"
      else warn "tmux 在，但 session '$TEAM_SESSION' 不存在（dispatch 会创建；PM 需要在 <session>:<pm-window> 里跑）"; fi
    else warn "无 tmux：agent 无法交互旁观，仅支持 -p 非交互（不建议）"; fi

  check "pi"; if [ -n "${TEAM_AGENT_CMD:-}" ]; then
      pass "本项目用自定义 agent adapter：不需要 pi"
    elif team_have_cmd pi; then
      local pv; pv="$(pi --version 2>/dev/null | head -1 || true)"
      if pi --help 2>&1 | grep -q -- '--session-id'; then pass "${pv:-present}"; else fail "pi 版本过旧：缺 --session-id"; fi
    else fail "缺 pi（PATH 里没有）"; fi

  # agent adapter：空 TEAM_AGENT_CMD = 内置 Pi（默认）；配了就用任意 TUI agent 的命令模板。
  # 判定口径：只有「配了但可执行文件根本解析不到」才算 fail；默认路径仍然由上面那条 pi 检查负责。
  check "agent adapter"
  local adapt_bin; adapt_bin="$(team_agent_bin_path)"
  if [ -z "${TEAM_AGENT_CMD:-}${TEAM_AGENT_BIN:-}" ]; then pass "$(team_agent_adapter_label) → $adapt_bin"
  elif command -v "$adapt_bin" >/dev/null 2>&1; then pass "$(team_agent_adapter_label) → $adapt_bin"
  else fail "$(team_agent_adapter_label) → 解析不到可执行文件：$adapt_bin（看 TEAM_AGENT_BIN / TEAM_AGENT_CMD 首词）"; fi

  check "agent notify"
  if [ -z "${TEAM_AGENT_NOTIFY_CMD:-}" ]; then
    if [ -n "${TEAM_AGENT_CMD:-}" ]; then warn "自定义 adapter 但没配 TEAM_AGENT_NOTIFY_CMD：worker 回合结束不会自动通知 PM"
    else pass "Pi notify 扩展（内置）"; fi
  else
    local nre=""
    if nre="$(team_agent_notify_check)"; then pass "$TEAM_AGENT_NOTIFY_CMD"
    else warn "$TEAM_AGENT_NOTIFY_CMD（$nre）"; fi
  fi

  # M26（E8 P1）建、M29（用户拍板）改写：harness 行保留（omp 会话自带后台，文案不同）；
  # 插件行只**告知已装什么** —— 永不推荐第三方功能包（推荐只限 teamsmith 必需/自带的东西）。
  # 判定次序：配的 harness 就是 omp ≫ PATH 里有 omp（但本项目配的可能是 pi）≫ pi ≫ 都不在。
  check "harness"
  local h_bin h_name omp_on_path=0
  h_bin="$(team_pi_bin_path)"
  h_name="$(basename "$h_bin")"
  if team_have_cmd omp; then omp_on_path=1; fi
  if [ -n "${TEAM_AGENT_CMD:-}" ]; then
    warn "自定义 adapter（TEAM_AGENT_CMD）：后台任务能力取决于该 harness，无法探测"
  elif [ "$h_name" = "omp" ] && command -v "$h_bin" >/dev/null 2>&1; then
    warn "omp 自带后台任务（bash 后台派发 / hub wait·cancel / /jobs）"
  elif [ "$omp_on_path" = "1" ]; then
    warn "PATH 里有 omp（自带后台任务：bash 后台派发 / hub wait·cancel / /jobs）；本项目配的是 $h_name（内置无后台 bash）"
  elif team_have_cmd pi; then
    pass "pi（内置无后台 bash：团队会话的长任务由自带的 team-bg 覆盖）"
  else
    warn "pi/omp 都不在 PATH：harness 无法判定（先看上面 pi 那一行）"
  fi

  # 已装插件（M29：信息行，只告知不推荐）。读两份设置文件（项目 + 用户），**不 spawn harness**：
  # doctor 在巡检面板 health 块的等待路径上（panel/src/data.ts: ttl 600s / timeout 30s），
  # spawn 在 TEAM_PI_BIN 不响应时会白等满超时 —— M26 实测过一次。
  check "已装插件 packages"
  local plug_all plug_shown plug_name plug_lvl plug_n=0
  plug_all="$(team_plugin_list)"
  if [ -z "$plug_all" ]; then
    warn "未检测到插件（teamsmith 不依赖第三方插件；团队会话的后台任务由自带 team-bg 覆盖）"
  else
    plug_shown=""
    while IFS=$'\t' read -r plug_name plug_lvl; do
      [ -n "$plug_name" ] || continue
      plug_n=$((plug_n + 1))
      [ "$plug_n" -le 3 ] && plug_shown="$plug_shown${plug_shown:+、}$plug_name（$plug_lvl）"
    done <<< "$plug_all"
    if [ "$plug_n" -gt 3 ]; then pass "$plug_shown 等 $plug_n 个"; else pass "$plug_shown"; fi
  fi

  check "门禁 TEAM_GATES"; if [ -n "$TEAM_GATES" ]; then pass "$TEAM_GATES"; else warn "未配置门禁命令：复验无法自动判定，只能靠人读 diff"; fi
  # M29：名册为空不再是失败（PM-only 开局合法）；真正拦住的是 dispatch（没有 agent 可用）。
  check "名册 TEAM_AGENTS"
  if [ -n "$(team_agents)" ]; then pass "$(team_agents | tr '\n' ' ')"
  else warn "名册为空：可以 PM-only 开局；要派单先 $TEAM_CLI add-agent <name>"; fi

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

  # PM 记忆（必需依赖，D10）：magic-context 是 Pi 侧扩展（npm 包），PM 靠它做跨会话记忆/检索。
  # 只读 settings.json 与包自身的 package.json，不做任何安装/改动，也不读凭据文件。
  check "PM 记忆 magic-context"
  local mc_settings="$TEAM_PI_SETTINGS_FILE" mc_ver
  mc_ver="$(team_magic_context_version)"
  if [ -n "$mc_ver" ]; then
    pass "magic-context $mc_ver（跨会话记忆可用：ctx_search / ctx_memory / ctx_note）"
  elif [ "${TEAM_REQUIRE_MAGIC_CONTEXT:-1}" = "1" ]; then
    fail "没检测到：装 pi 包 @cortexkit/pi-magic-context（settings 在别处时设 TEAM_PI_SETTINGS_FILE；环境特殊可 TEAM_REQUIRE_MAGIC_CONTEXT=0 降级）"
  else
    warn "没检测到（TEAM_REQUIRE_MAGIC_CONTEXT=0 已降级）：PM 长会话只能靠 /compact + 落盘"
  fi

  # 规格层（必需依赖，D10）：OpenSpec 管「为什么改/改成什么」；缺 CLI 或缺 spec 目录都算失败
  check "OpenSpec CLI"
  local os_bin os_ver
  os_bin="$(team_openspec_bin_path)"
  if command -v "$os_bin" >/dev/null 2>&1; then
    os_ver="$("$os_bin" --version 2>/dev/null | head -1)"
    pass "${os_ver:-已解析}（$os_bin）"
  elif [ "${TEAM_REQUIRE_OPENSPEC:-1}" = "1" ]; then
    fail "找不到：$os_bin（装上 OpenSpec CLI 并确保在 PATH 里，或设 TEAM_OPENSPEC_BIN；临时可 TEAM_REQUIRE_OPENSPEC=0 降级）"
  else
    warn "找不到：$os_bin（TEAM_REQUIRE_OPENSPEC=0 已降级）"
  fi
  check "OpenSpec 规格目录"
  if [ -d "$(team_spec_dir_abs)" ]; then
    pass "$TEAM_SPEC_DIR"
  elif [ "${TEAM_REQUIRE_OPENSPEC:-1}" = "1" ]; then
    fail "缺 $TEAM_SPEC_DIR/：在项目里跑 openspec init --tools none"
  else
    warn "缺 $TEAM_SPEC_DIR/（TEAM_REQUIRE_OPENSPEC=0 已降级）：跑 openspec init --tools none"
  fi

  # JS 运行时（必需依赖，D19）：面板是提交进仓库的 Ink bundle（scripts/panel/panel.js），
  # 跑它要 node/bun/tsx 之一。失败行必须点名解析到的东西（路径或版本），不能把「PATH 里没有」报成「没装」。
  check "JS 运行时 node/bun"
  local js_st js_path js_ver js_detail js_fix
  IFS=$'\t' read -r js_st js_path js_ver js_detail <<< "$(team_js_check)"
  js_fix="装 node ≥ ${TEAM_JS_MIN_NODE_MAJOR} 或 bun ≥ ${TEAM_JS_MIN_BUN_MINOR}；已装但不在 PATH 就设 TEAM_JS_BIN 指向绝对路径；临时可 TEAM_REQUIRE_JS=0 降级 doctor 这一行（面板仍需运行时）"
  case "$js_st" in
    ok) pass "$js_path ($js_ver)" ;;
    missing)
      if [ "${TEAM_REQUIRE_JS:-1}" = "1" ]; then fail "解析不到 node/bun/tsx：$js_fix"
      else warn "解析不到（TEAM_REQUIRE_JS=0 已降级）：$js_fix"; fi ;;
    bad)
      if [ "${TEAM_REQUIRE_JS:-1}" = "1" ]; then fail "TEAM_JS_BIN=$js_path $js_detail：修好它，或改指向可执行的 node/bun"
      else warn "TEAM_JS_BIN=$js_path $js_detail（TEAM_REQUIRE_JS=0 已降级）"; fi ;;
    old)
      if [ "${TEAM_REQUIRE_JS:-1}" = "1" ]; then fail "版本过低：$js_path $js_ver（$js_detail）——升级 node 或 bun"
      else warn "版本过低：$js_path $js_ver（$js_detail；TEAM_REQUIRE_JS=0 已降级）"; fi ;;
    *)
      warn "找到了但版本判不出：${js_path:-?} ${js_ver:-}${js_detail:+（$js_detail）}——确认它能跑 --version" ;;
  esac

  check "容量 / swap 底线"; local avail swapfree swaptotal
    read -r avail swapfree swaptotal <<< "$(team_mem_stats)"
    if [ -n "$avail" ] && [ "${avail:-0}" -gt 0 ] 2>/dev/null; then
      if [ "$TEAM_MIN_FREE_SWAP_MB" -gt 0 ] && [ "$swapfree" -lt "$TEAM_MIN_FREE_SWAP_MB" ]; then
        warn "空闲 swap ${swapfree}MB < 底线 ${TEAM_MIN_FREE_SWAP_MB}MB：现在派单会被拒绝"
      else
        pass "$(team_capacity_line)"
      fi
    else warn "无法探测内存/swap（可设 TEAM_MEMINFO_FILE 指定 meminfo 文件）"; fi

  # M11：PM 窗口名漂移（配置说 A、现场的 PM 在 B）。只在真看得见漂移时开口（干净项目不刷行，
  # 与「迁移指引」同一风格），而且必须把话说到底：up 只认配置，会另开一个 A 窗口 → 两个 PM。
  local pmwin_drift=""
  if team_have_cmd tmux && team_tmux_has_session "$TEAM_SESSION" \
     && ! team_tmux_has_window "$TEAM_SESSION" "$TEAM_PM_WINDOW"; then
    pmwin_drift="$(team_pm_window_drift)"
    if [ -n "$pmwin_drift" ]; then
      check "PM 窗口名"
      warn "配置写的是 '$TEAM_PM_WINDOW'，但 $TEAM_SESSION 里在跑 PM 的窗口叫 '$pmwin_drift'（改名漂移）：先对齐名字再动手 —— $TEAM_CLI up 只认配置，会另开一个 '$TEAM_PM_WINDOW' 窗口（两个 PM）。二选一：tmux rename-window -t $TEAM_SESSION:${pmwin_drift%% *} $TEAM_PM_WINDOW ／ 把配置改成 TEAM_PM_WINDOW=\"${pmwin_drift%% *}\""
    fi
  fi

  check "PM 存活"; local pmstate; pmstate="$(team_pm_state)"
    case "$pmstate" in
      running:*) pass "pi 在运行（${pmstate#running:}）" ;;
      idle:*)    warn "窗口 $TEAM_SESSION:$TEAM_PM_WINDOW 停在 ${pmstate#idle:}：PM 没在跑 → team up" ;;
      unknown:*) warn "窗口 $TEAM_SESSION:$TEAM_PM_WINDOW 里不是 PM（${pmstate#unknown:}）：不算存活 → team up（会替换它）" ;;
      foreign:*) warn "窗口 $TEAM_SESSION:$TEAM_PM_WINDOW 被别的项目的进程占着（cwd=$(team_pane_cwd "$(team_pm_target)" 2>/dev/null || echo '?')）：不覆盖" ;;
      *) if [ -n "$pmwin_drift" ]; then
           warn "PM 窗口 $TEAM_SESSION:$TEAM_PM_WINDOW 不存在，但 '$pmwin_drift' 里跑着 PM（见上一条「PM 窗口名」）→ 先对齐名字，别直接 up"
         else
           warn "PM 窗口 $TEAM_SESSION:$TEAM_PM_WINDOW 不存在 → team up"
         fi ;;
    esac

  # M46 · 投递通道：PM 没有 inbox-watch 注册时，通知会退回输入框粘贴慢路径 —— 这条降级必须看得见。
  # 只在「内置 Pi 的 PM」这条 lane 上判（自定义 PM CLI 不吃这个扩展，绝不劝告）；PM 没在跑且
  # 没有活痕迹时不刷行（没有可降级的目标）；注册在 → pass 一行，让人知道快路径真的连着。
  if [ -z "${TEAM_PM_CMD:-}${TEAM_PM_BIN:-}" ]; then
    local watch_dbg
    watch_dbg="$(team_inbox_watch_degraded_line "$(team_pm_target)" "$pmstate" 2>/dev/null || true)"
    if [ -n "$watch_dbg" ]; then
      check "投递通道 inbox-watch"; warn "$watch_dbg"
    elif [ "${pmstate#running:}" != "$pmstate" ]; then
      check "投递通道 inbox-watch"; pass "PM 会话已注册（通知走收件箱唤醒，不碰输入框）"
    fi
  fi

  check "巡检（pulse）"; local legacy_note; legacy_note="$(team_pulse_legacy_suffix)"
    case "$(team_pulse_state)" in
      off) warn "没在跑 → $TEAM_CLI pulse up（pulse 由 PM 配置）$legacy_note" ;;
      *)   pass "$(team_pulse_state_text)$legacy_note" ;;
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

  # 迁移/升级指引（M7.1）：只在真的需要迁移时多打一行，指向 references/migration.md（不新增子命令）。
  local mig; mig="$(team_migration_reasons)"
  if [ -n "$mig" ]; then
    check "迁移指引"; warn "$mig：读 $TEAM_SKILL_DIR/references/migration.md（重命名 / 已删命令 / 必需依赖 / 行为变更 / 升级配方 / 回滚）"
  fi


  printf '\n'
  if [ "$fails" -gt 0 ]; then team_err "doctor: $fails 项失败 / $warns 项警告"; return 1; fi
  if [ "$warns" -gt 0 ]; then team_warn "doctor: 0 项失败 / $warns 项警告（可继续）"; return 0; fi
  team_ok "doctor: 全部通过"
}
