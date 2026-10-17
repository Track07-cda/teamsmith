#!/usr/bin/env bash
# teamsmith · init / doctor / help

team_help() { # 兼容入口：`team help` 的三级路由在 scripts/lib/cmd-help.sh（唯一渲染器）
  team_help_route 0 help "$@"
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

# ---------------------------------------------------------------- 模型策略（P235 · S3）
# 退休的席位/全局默认模型键：只要文件里还有真赋值行（注释里提不算），init/bootstrap 就停下并
# 指向唯一升级事务 —— 这不是「零变化重入」，而是未完成迁移的项目。
team_config_legacy_model_keys() { # <file> → 每行一个仍在文件里的退休键；没有则空
  local f="${1:-}" k
  [ -n "$f" ] && [ -f "$f" ] || return 0
  for k in TEAM_DEFAULT_MODEL TEAM_AGENT_MODELS; do
    grep -vE '^[[:space:]]*#' "$f" 2>/dev/null \
      | grep -Eq "(^|[^A-Za-z0-9_])$k([[:space:]]*=|[[:space:]])" && printf '%s\n' "$k"
  done
  return 0
}

# init/bootstrap 的模型输入解析：显式输入 > 文件里的合法新策略（重入）。
# 两个键都是必填；没有可继承的合法值就拒绝，拒绝发生在任何写入之前。
# 显式值用与唯一 writer 同一个校验器（team_config_validate_value）验，拒绝时给真路线。
team_init_model_policy_resolve() { # <cfg> <task_models|''> <pm_model|''> <task_models_set 0|1> <pm_model_set 0|1> <cmd 名>
  local cfg="${1:-}" in_map="${2:-}" in_pm="${3:-}" map_set="${4:-0}" pm_set="${5:-0}" cmd="${6:-init}"
  local file_map="" file_pm="" file_map_ok=0 file_pm_ok=0 reason=""
  if [ -n "$cfg" ] && [ -f "$cfg" ]; then
    file_map="$(team_config_file_value "$cfg" TEAM_TASK_MODELS 2>/dev/null || true)"
    file_pm="$(team_config_file_value "$cfg" TEAM_PM_MODEL 2>/dev/null || true)"
    team_task_map_violation "$file_map" >/dev/null 2>&1 && file_map_ok=1
    team_config_model_shape_ok "$file_pm" && file_pm_ok=1
  fi
  if [ "$map_set" = "1" ]; then
    if ! reason="$(team_config_validate_value TEAM_TASK_MODELS "$in_map")"; then
      team_err "$cmd: --task-models 不合法：$reason"
      team_dim "  形如 'routine=provider/light analysis=provider/strong verify=provider/strong'（类别 [a-z][a-z0-9-]*，模型 provider/model，第一个 / 分 provider）" >&2
      return 4
    fi
  elif [ "$file_map_ok" = "1" ]; then
    in_map="$file_map"
  else
    team_err "$cmd: 缺少 --task-models（项目类别映射是必填输入；没有默认模型可猜）"
    team_dim "  新项目：$TEAM_CLI init --task-models '<category=provider/model …>' --pm-model '<provider/model>'
  已有项目：$TEAM_CLI config set-task-model <category> <model>（或 config set TEAM_TASK_MODELS '<完整映射>' --yes；破坏式升级走 config upgrade-models）" >&2
    return 4
  fi
  if [ "$pm_set" = "1" ]; then
    if ! reason="$(team_config_validate_value TEAM_PM_MODEL "$in_pm")"; then
      team_err "$cmd: --pm-model 不合法：$reason"
      team_dim "  独立 PM 模型：provider/model（可选 :suffix），例如 provider/strong-model:high" >&2
      return 4
    fi
  elif [ "$file_pm_ok" = "1" ]; then
    in_pm="$file_pm"
  else
    team_err "$cmd: 缺少 --pm-model（独立 PM 模型是必填输入；PM 不再回落到任何 worker/默认模型）"
    team_dim "  新项目：$TEAM_CLI init --task-models '<category=provider/model …>' --pm-model '<provider/model>'
  已有项目：$TEAM_CLI config set TEAM_PM_MODEL '<provider/model>' --yes（破坏式升级走 config upgrade-models）" >&2
    return 4
  fi
  printf '%s\n%s\n' "$in_map" "$in_pm"
  return 0
}

team_cmd_init() {
  local session="" agents="" vcs="" gates="" docs="" pmwin="" force=0 install_mode=""
  local task_models="" pm_model="" task_models_set=0 pm_model_set=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --session) session="${2:?}"; shift 2 ;;
      --agents) agents="${2:?}"; shift 2 ;;
      --vcs) vcs="${2:?}"; shift 2 ;;
      --gates) gates="${2:?}"; shift 2 ;;
      --docs) docs="${2:?}"; shift 2 ;;
      --pm-window) pmwin="${2:?}"; shift 2 ;;
      --task-models) task_models="${2:?}"; task_models_set=1; shift 2 ;;
      --pm-model) pm_model="${2:?}"; pm_model_set=1; shift 2 ;;
      --model|--default-model)
        team_err "init: $1 已退休：项目不再有席位/全局默认模型"
        team_dim "  新项目：$TEAM_CLI init --task-models '<category=provider/model …>' --pm-model '<provider/model>'"
        team_dim "  已有项目升级：$TEAM_CLI config upgrade-models --task-models '<完整映射>' --pm-model '<独立模型>' --dry-run"
        return 2 ;;
      --copy) install_mode="--copy"; shift ;;
      --no-skills) install_mode="--no-skills"; shift ;;
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
  local cfg="$TEAM_MAIN_ROOT/.pi/team/config.sh" had_config=0; [ -f "$cfg" ] && had_config=1

  # 0) 模型策略闸门（P235）：退休键 / 缺输入 / 非法值都在**任何写入之前**停住。
  #    已有合法新策略允许不带输入重入（保留策略）；退休键则连 --force 都不能当迁移捷径。
  if [ "$had_config" = "1" ]; then
    local legacy_keys; legacy_keys="$(team_config_legacy_model_keys "$cfg")"
    if [ -n "$legacy_keys" ]; then
      team_err "init: $cfg 还在用退休的模型键（$(printf '%s' "$legacy_keys" | tr '\n' ' ')）—— 任何写入之前停住"
      team_dim "  项目模型策略是破坏式升级：init / init --force / bootstrap 都不是迁移路径"
      team_legacy_model_route_lines "$cfg"
      return 1
    fi
  fi
  local _policy _rc=0
  _policy="$(team_init_model_policy_resolve "$cfg" "$task_models" "$pm_model" "$task_models_set" "$pm_model_set" init)" || _rc=$?
  [ "$_rc" -eq 0 ] || return "$_rc"
  task_models="$(printf '%s\n' "$_policy" | sed -n '1p')"
  pm_model="$(printf '%s\n' "$_policy" | sed -n '2p')"
  # 已有配置（不带 --force）原样保留：显式输入与现有策略不同就拒绝，不静默忽略。
  if [ "$had_config" = "1" ] && [ "$force" != "1" ]; then
    local cur_map cur_pm
    cur_map="$(team_config_file_value "$cfg" TEAM_TASK_MODELS 2>/dev/null || true)"
    cur_pm="$(team_config_file_value "$cfg" TEAM_PM_MODEL 2>/dev/null || true)"
    if [ "$task_models_set" = "1" ] && [ "$task_models" != "$cur_map" ]; then
      team_err "init: 现有配置会被保留（skip），但 --task-models 与现有映射不同 —— 不静默忽略"
      team_dim "  改一个类别：$TEAM_CLI config set-task-model <category> <model>；整映射：$TEAM_CLI config set TEAM_TASK_MODELS '<完整映射>' --yes"
      team_dim "  或 --force 重渲染整份契约（其它键会回到模板值）"
      return 4
    fi
    if [ "$pm_model_set" = "1" ] && [ "$pm_model" != "$cur_pm" ]; then
      team_err "init: 现有配置会被保留（skip），但 --pm-model 与现有值不同 —— 不静默忽略"
      team_dim "  改 PM 模型：$TEAM_CLI config set TEAM_PM_MODEL '<provider/model>' --yes；或 --force 重渲染"
      return 4
    fi
  fi

  # --force = 重渲染整份契约：此时不把**旧契约读回来的** TEAM_GATES 当模板值 —— 它是旧值，
  # 不是这次要渲染的模板值（P99 身份 note 承诺的代价：其它键回到模板值）。真正从环境继承
  # （export 过）的值仍算显式覆盖，照旧优先。
  if [ "$force" = "1" ] && [ -z "$gates" ]; then
    local _gates_exported=0 _gates_keep="$TEAM_GATES"
    case "$(declare -p TEAM_GATES 2>/dev/null || true)" in "declare -x"*) _gates_exported=1 ;; esac
    if [ "$_gates_exported" = "1" ]; then
      gates="$TEAM_GATES"
    else
      TEAM_GATES=""
      gates="$(team_detect_gates)"
      TEAM_GATES="$_gates_keep"
    fi
  else
    gates="${gates:-$(team_detect_gates)}"
  fi

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
  local tmpl; tmpl="$(team_tmpl_dir)/config.sh.tmpl"
  if [ -f "$cfg" ] && [ "$force" != "1" ]; then
    team_dim "skip  $cfg（已存在，--force 覆盖）"
  else
    mkdir -p "$(dirname "$cfg")"
    if ! team_render "$tmpl" \
      "PROJECT=$project" "SESSION=$session" "PM_WINDOW=$pmwin" \
      "DOCS_DIR=$docs" "AGENTS=$agents" "GATES=$(team_escape_dq "$gates")" "VCS=$vcs" \
      "SKILL_DIR=$TEAM_SKILL_DIR" \
      "DETECTED_VCS=$(team_detect_vcs)" "TODAY=$(date +%F)" \
      "CONFIG_VERSION=$TEAM_CONFIG_SHAPE_CURRENT" > "$cfg"; then
      team_err "init: 渲染配置失败：$tmpl"
      rm -f "$cfg"
      return 1
    fi
    # 模型两键走同一个加固写入器（值已用同一个校验器验过）：不是模板插值、没有默认值可猜。
    # 任一步失败就删掉这次的半成品配置，绝不留下缺键的契约。
    if ! team_config_set_in_file "$cfg" TEAM_TASK_MODELS "$task_models" \
       || ! team_config_set_in_file "$cfg" TEAM_PM_MODEL "$pm_model"; then
      team_err "init: 模型策略写入失败，已删除这次的半成品配置"
      rm -f "$cfg"
      return 1
    fi
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

  # 5) 项目本地 skill（<main worktree>/.pi/skills/）：Pi 的项目级搜索路径。bootstrap 复用同一函数
  #    （见 cmd-init.sh）—— 一个实现，两个调用点；--copy/--no-skills 由 init 自己解析。
  local install_args=()
  [ -n "$install_mode" ] && install_args+=("$install_mode")
  [ "$force" = "1" ] && install_args+=("--force")
  team_init_install_skills ${install_args[@]+"${install_args[@]}"} || return 1

  printf '\n'
  team_hdr "下一步"
  printf '  1) %s doctor\n' "$TEAM_CLI"
  printf '  2) 编辑 %s/.pi/team/config.sh（名册 TEAM_AGENTS、门禁 TEAM_GATES、任务类别映射）\n' "$project"
  printf '     改一个类别：%s config set-task-model <category> <model>；整映射：%s config set TEAM_TASK_MODELS <完整映射> --yes\n' "$TEAM_CLI" "$TEAM_CLI"
  printf '  3) %s task T1.1 --title "第一个任务" --category <类别> --agent dev\n' "$TEAM_CLI"
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
  # M48：同一 ID 多行（历史遗留的共用 ID）—— 面板焦点/状态/报告都按 ID 指行，重复必须看得见。
  # 警告不是失败：旧看板本来就可能是这个形状，doctor 只要求它能被看见（处置见 troubleshooting）。
  check "BOARD 重复 ID"; local bdups; bdups="$(team_board_duplicate_ids || true)"
  if [ -z "$bdups" ]; then pass "无"
  else warn "$(printf '%s' "$bdups" | awk 'NR>1{printf "、"} {printf "%s", $0}') （同 ID 多行：焦点按行身份走，但状态/报告按 ID 指行；$TEAM_CLI board ls）"; fi
  check "bash"; if [ "${BASH_VERSINFO[0]}" -ge 5 ]; then pass "${BASH_VERSION%%(*}"; else fail "需要 bash >= 5（实测 4.0 下 help/init 退出 2）"; fi
  check "git"; if team_have_cmd git; then pass "$(git --version | awk '{print $3}')"; else fail "缺 git"; fi

  check "tmux"; if team_have_cmd tmux; then
      if team_tmux_has_session "$TEAM_SESSION"; then pass "session $TEAM_SESSION 在运行"
      else warn "tmux 在，但 session '$TEAM_SESSION' 不存在（dispatch 会创建；PM 需要在 <session>:<pm-window> 里跑）"; fi
    else warn "无 tmux：agent 无法交互旁观，仅支持 -p 非交互（不建议）"; fi

  # M67 · 退役键的 server 残留（只读探测，不建 server）：跑着的 tmux server 全局环境里还带着
  # TEAM_ALLOW_DESTRUCTIVE_TMUX 时提示一行 —— 它**不再授权任何操作**（闸门按目标判定），残留只是
  # 旧 server 启动环境的化石；重启该 server 后消失（重启会结束它上面所有会话，时机由人定）。
  if team_have_cmd tmux; then
    local retired_residue=""
    retired_residue="$(tmux show-environment -g TEAM_ALLOW_DESTRUCTIVE_TMUX 2>/dev/null | head -1 || true)"
    if [ -n "$retired_residue" ]; then
      check "tmux 闸门退役键"
      warn "运行的 tmux server 全局环境里还有 $retired_residue（M67 退役）：它不再授权任何操作（判定按目标）；重启该 server 后残留消失"
    fi
  else
    check "tmux 闸门退役键"; printf '%s\n' "SKIP：没有 tmux，无法探测 server 全局环境"
  fi

  # P304 · 本项目身份在运行中 server 全局环境里的残留（**只读**报告，绝不代改）：残留会让同一 server 上
  # **别的项目**新开的窗口继承本项目的身份（用户 2026-10-15 报的形状：server 死了重开，在别的项目里
  # 被自己的身份守卫拒掉）。本 change 落地后产品路径不再新增它；这份只读行是「人自己决定清不清」的
  # 出口（清它 = 改共享 server 的全局环境，属用户的管辖）。判据与读侧归因同源。
  if team_have_cmd tmux; then
    local id_residue="" id_vars="" id_route=""
    id_residue="$(team_identity_server_residue_vars)"
    if [ -n "$id_residue" ]; then
      id_vars="$(printf '%s\n' "$id_residue" | awk -F= 'NF { printf "%s%s", (NR > 1 ? " " : ""), $1 }')"
      id_route="$(team_identity_residue_route $id_vars)"
      check "tmux 身份残留"
      warn "运行中的 tmux server 全局环境里还有本项目的身份残留（$(printf '%s' "$id_residue" | tr '\n' ' ')）——它会让同一 server 上别的项目新开的窗口继承本项目的身份；只报告不代改，清掉（改共享 server，时机由你定）：$id_route"
    fi
  fi

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
  # M58：性能套件在不在 —— 性能判定已从正确性门禁搬到它身上；缺了是「下一步」（更新 skill），不是硬失败。
  check "perf suite"; if [ -f "$TEAM_SKILL_DIR/tests/perf.sh" ]; then
      pass "存在（$TEAM_CLI perf --container ｜ $TEAM_CLI perf --host）"
    else warn "缺 tests/perf.sh：性能判定没地方跑 → 重新安装/更新 skill（pi install 或换到含 M58 的版本）"; fi
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

  # M53 · wake 通道的 inotify 余量：额度 + **可证明**的占用 + 一次性注册探针。降级 ≠ 故障 ——
  # 这是环境事实，只警告（fails 不动）并给修法；探针不是 ok 或已知余量低于底线才开口。
  check "inotify 额度"
  local ino_status ino_text
  IFS=$'\t' read -r ino_status ino_text <<< "$(team_inotify_headroom_line)"
  if [ "$ino_status" = "ok" ]; then pass "$ino_text"; else warn "$ino_text"; fi

  # P53/P144 · 磁盘余量（与 inotify 同型的宿主资源行；只警告、不动 fails）—— 实现与读数在 cmd-status.sh：
  # 临时根 + 工作树根，每个被判的文件系统一行（同一个文件系统只印一行）
  team_disk_doctor_rows

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

  # R5（P40）：项目本地 skill 安装（team init 装到 <main>/.pi/skills/）—— 没装**不刷行**（Pi 包安装、
  # ~/.agents/skills 软链、settings 的 skills 条目都不该被唠叨）；漂移（别源软链 / 旧副本 / 读不到
  # SKILL.md）warn 并给一行修法，**永不 fail**（与「陈旧会话版本」同一条 warn-don't-fail 线）。
  local skill_row; skill_row="$(team_project_skill_install_row)"
  if [ -n "$skill_row" ]; then
    check "项目 skill 安装"
    case "$skill_row" in
      pass\ *) pass "${skill_row#pass }" ;;
      warn\ *) warn "${skill_row#warn }" ;;
    esac
  fi

  # P270：项目本地的 `/team` 扩展（同一条 warn-don't-fail 线，同一个「没装就不刷行」的口径）。
  local ext_row; ext_row="$(team_project_extension_install_row)"
  if [ -n "$ext_row" ]; then
    check "/team 扩展安装"
    case "$ext_row" in
      pass\ *) pass "${ext_row#pass }" ;;
      warn\ *) warn "${ext_row#warn }" ;;
    esac
  fi

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
