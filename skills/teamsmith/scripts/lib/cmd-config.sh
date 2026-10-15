#!/usr/bin/env bash
# teamsmith · 项目契约（.pi/team/config.sh）的读写面：team config list|set|log|set-agent-model
#
# 这一层拥有三件事，别的层不许再写一遍：
#   * **schema**：每个键的 class（apply/restart/refuse）、kind（值域校验）、form（plain/export）、
#     默认值与 danger 规则。表就是真相，`team config list --json` 与面板的类徽章都读它；
#     完整性（模板键 / references/config.md 的键 ↔ schema）是测试，不是承诺（tests/config-cli.sh）。
#   * **写路径**：值校验 → danger → 指纹 CAS → 加固 writer（cmd-bootstrap.sh 的
#     team_config_set_in_file，唯一底层写入口）→ 原子 mv；每次尝试一行审计。
#   * **模型席位**：TEAM_AGENT_MODELS / TEAM_PM_MODEL 按席位读写（set-agent-model），来源三态与
#     team_agent_model_src 同口径，读侧给面板 models 块。
#
# 退出码是机器契约（面板/测试都按它分支，不解析人话）：
#   0 写入成功（--dry-run 也是 0 = 校验通过）/ 3 指纹冲突（什么都没写）/
#   4 值不合法（什么都没写）/ 5 键不可改（未知键或 refuse 类）/ 6 写失败（原字节未动）/
#   7 危险值，需要 --allow-danger（什么都没写）。
#
# 契约的路径：显式 TEAM_CONFIG_FILE > 目录推导（team_load_config 已经算好 TEAM_CONFIG）。
# 没有契约 = 项目还没 init → 报错点名 `team init`，绝不悄悄造一个。

# ---------------------------------------------------------------- schema（唯一真相）
# 行格式：KEY|class|kind|spec|form|default|danger|route|suggest|group
#   group：**第 10 列**，功能域 token（封闭词表，^[a-z][a-z0-9-]*$，每行必填）。它是 schema 数据，
#         不是从 `# ----` 分节注释解析出来的（注释是散文，不是语法）：`team config list --json`
#         把 token 逐字放进记录，视图分组的标签从 zh/en 表的 group_<token> 查。词表封闭由
#         「schema 行用的 token ⇄ 标签」双向相等这条门禁保证（tests/panel-strings.mjs）。
#         无 token 的行是畸形行：config-cli.sh 的 groups 走查点名该键判红（视图侧同时可见降级到「未分组」）。
#   kind：bool / int / seconds / mb / pct / enum / text / list / path / cmd / tpl / model /
#         pairlist / pattern / winlist / bytes
#   spec：int/seconds/mb/pct/bytes 是「min,max」（空 = 无边）；enum 是逗号分隔的值域；
#         path 是 file|dir|exec|any 加「,opt」（空值有意义）；tpl 是 launch|notify|pm
#   danger：'-' 或一行理由（命中即需要 --allow-danger）
#   route：自由文本说明列 —— refuse 类的用法指引，以及 apply 类（frozen 接缝）的备注（面板把它原样展示）
#   suggest：**可选的第 9 列**，数值类键的建议值（逗号分隔的整值；仍是 schema 数据，不是选项表）；
#         没有建议的行保持 8 列（读者两形状都认）。读侧（team_config_choices）与写入校验的一致性
#         由 tests/panel-choices.sh 的走查夹具钉住：读给出的每个值都必须被 team config set 接受。
team_config_schema() {
  cat <<'EOF'
# ---- 身份与账本布局（refuse：控制台不得改身份、不得搬走它正在读的账本）----
TEAM_PROJECT|refuse|text||plain||-|身份：手改 .pi/team/config.sh（team init 不改它）；team init --force 会重渲染整份契约||identity
TEAM_SESSION|refuse|text||plain||-|身份：手改 .pi/team/config.sh（team init 不改它）；team init --force 会重渲染整份契约||identity
TEAM_PM_WINDOW|refuse|text||plain|pm|-|身份：手改 .pi/team/config.sh（team init 不改它）；team init --force 会重渲染整份契约||identity
TEAM_AGENTS|refuse|list||plain||-|名册：team add-agent <a> --register / team teardown --agent <a> --register（都走审计写入器）||identity
TEAM_DOCS_DIR|refuse|path|dir,opt|plain|docs/team|-|账本布局：手改 .pi/team/config.sh||identity
TEAM_WORKTREES_DIR|refuse|text||plain|.worktrees|-|账本布局：手改 .pi/team/config.sh||identity
TEAM_STATE_DIR|refuse|path|dir,opt|plain|.pi/team/state|-|账本布局：手改 .pi/team/config.sh||identity
TEAM_MEETINGS_DIR|refuse|path|dir,opt|plain|~/.pi/team/meetings|-|账本布局：手改 .pi/team/config.sh||identity
TEAM_SPEC_DIR|refuse|path|dir,opt|plain|openspec|-|账本布局：手改 .pi/team/config.sh||identity
TEAM_ROOT|refuse|path|dir,opt|plain||-|环境定位：用 --root 或手改 .pi/team/config.sh||identity
TEAM_MAIN_ROOT|refuse|path|dir,opt|plain||-|环境定位：用 --root 或手改 .pi/team/config.sh||identity
TEAM_CONFIG_FILE|refuse|path|file,opt|plain||-|环境定位：用 --config 或手改 .pi/team/config.sh||identity
# ---- 分支与 forge（refuse：它们定义「已落地」与凭据位置）----
TEAM_BRANCH_MODE|refuse|enum|task,agent|plain|task|-|分支语义（定义「已落地」）：手改 .pi/team/config.sh||branch
TEAM_TASK_BRANCH_PREFIX|refuse|text||plain|task|-|分支语义：手改 .pi/team/config.sh||branch
TEAM_AGENT_BRANCH_PREFIX|refuse|text||plain|agent|-|分支语义：手改 .pi/team/config.sh||branch
TEAM_PROTECTED_BRANCH|refuse|text||plain|main|-|分支语义：手改 .pi/team/config.sh||branch
TEAM_REMOTE|refuse|text||plain|origin|-|分支语义：手改 .pi/team/config.sh||branch
TEAM_VCS|refuse|enum|local,github,gitlab,other|plain|local|-|分支语义/forge：手改 .pi/team/config.sh||branch
TEAM_TOKEN_FILE|refuse|path|file,opt|plain|.gh-pat|-|凭据位置：手改 .pi/team/config.sh||branch
TEAM_GITLAB_HOST|refuse|text||plain||-|凭据位置：手改 .pi/team/config.sh||branch
TEAM_GITLAB_PROJECT|refuse|text||plain||-|凭据位置：手改 .pi/team/config.sh||branch
TEAM_GITLAB_TOKEN_FILE|refuse|path|file,opt|plain||-|凭据位置：手改 .pi/team/config.sh||branch
TEAM_MERGE_PREFER_THEIRS|apply|text||plain||-|||branch
# ---- 权限与依赖策略（refuse：控制台不得给自己扩权）----
TEAM_CONFIRM_WRITES|refuse|bool||plain|1|-|权限守卫：控制台不给自己扩权；手改 .pi/team/config.sh||policy
TEAM_ALLOW_FOREIGN_IDENTITY|refuse|bool||plain|0|-|权限守卫：手改 .pi/team/config.sh||policy
TEAM_ALLOW_FOREIGN_SESSION|refuse|bool||plain|0|-|权限守卫：手改 .pi/team/config.sh||policy
TEAM_GUARD_FOREIGN_TARGET|refuse|bool||plain|1|-|权限守卫：手改 .pi/team/config.sh||policy
TEAM_REPLACE_FOREIGN_PM|refuse|bool||plain|0|-|权限守卫：手改 .pi/team/config.sh||policy
TEAM_ALLOW_DESTRUCTIVE_TMUX|refuse|bool||plain|0|-|权限守卫（M67 退役）：不再授权任何操作（判定按目标）；保留为不接受写入的只读墓碑，手改 .pi/team/config.sh||policy
TEAM_ASSUME_YES|refuse|bool||plain|0|-|权限守卫：手改 .pi/team/config.sh||policy
TEAM_REQUIRE_JS|refuse|bool||plain|1|-|依赖策略：手改 .pi/team/config.sh||policy
TEAM_REQUIRE_OPENSPEC|refuse|bool||plain|1|-|依赖策略：手改 .pi/team/config.sh||policy
TEAM_REQUIRE_MAGIC_CONTEXT|refuse|bool||plain|1|-|依赖策略：手改 .pi/team/config.sh||policy
TEAM_PI_AGENT_DIR|refuse|path|dir,opt|plain||-|机器路径：手改 .pi/team/config.sh||policy
TEAM_PI_SETTINGS_FILE|refuse|path|file,opt|plain|$HOME/.pi/agent/settings.json|-|机器路径：手改 .pi/team/config.sh||policy
TEAM_MEMINFO_FILE|refuse|path|file,opt|plain||-|机器路径：手改 .pi/team/config.sh||policy
TEAM_DISK_STATS_FILE|refuse|path|file,opt|plain||-|测试旋钮：磁盘读数夹具（TEAM_MEMINFO_FILE 同族）；只在夹具里用||policy
TEAM_SMOKE_FAST|refuse|bool||plain|0|-|测试旋钮：环境变量或手改 .pi/team/config.sh||policy
TEAM_INBOX_WATCH_FORCE_FAIL|refuse|text||plain||-|测试旋钮（M53）：强制 watcher 注册失败路径，记录标 forced=1；只在夹具里用||policy
TEAM_IW_REQUIRE_WATCH|refuse|bool||plain|0|-|测试旋钮（M53）：inbox-watch 门禁严格模式——不可用的前提判红而不是可见 SKIP||policy
# ---- 名册、模型解析与适配器（apply：下一个读契约的进程就生效）----
TEAM_MODEL_LIMITS|apply|pattern||plain|kimi-coding/k3=2 openai-codex/*=1|-|||roster
TEAM_MODEL_WINDOWS|apply|winlist||plain||-|||roster
TEAM_SESSION_WARN_TOKENS|apply|int|0,|plain|200000|-||100000,200000,400000|roster
TEAM_EXTRA_PI_ARGS|apply|cmd||plain||-|||roster
TEAM_AGENT_CMD|apply|tpl|launch|plain||-|内部接缝（frozen）：为将来非 Pi 适配预留，不承诺兼容；不在 init 问卷里问||roster
TEAM_AGENT_NOTIFY_CMD|apply|tpl|notify|plain||-|内部接缝（frozen）：为将来非 Pi 适配预留，不承诺兼容；不在 init 问卷里问||roster
TEAM_AGENT_LOG_GLOB|apply|text||plain||-|内部接缝（frozen）：为将来非 Pi 适配预留，不承诺兼容；不在 init 问卷里问||roster
TEAM_PI_BIN|apply|path|exec|plain|pi|-|||roster
TEAM_AGENT_BIN|apply|path|exec,opt|plain||-|内部接缝（frozen）：为将来非 Pi 适配预留，不承诺兼容；不在 init 问卷里问||roster
TEAM_OPENSPEC_BIN|apply|path|exec|plain|openspec|-|||roster
TEAM_JS_BIN|apply|path|exec,opt|plain||-|||roster
# ---- Future policy, separate from committed assignments ----
TEAM_TASK_MODELS|apply|task-model-map|req|plain||-|新任务类别：team config set-task-model <category> <model>；恢复保留已派身份||task-model
TEAM_PM_MODEL|restart|model|req|plain||-|独立 PM 模型：team up 启动受 fresh-pm 守卫；team up 缺失/不一致的就身记录按 pm-lifecycle 合同处理||task-model
# ---- 工具自身（配置形状号与版本提示；P261 · startup-self-heal）----
TEAM_CONFIG_VERSION|refuse|int|1,|plain|2|-|配置形状号（工具写、控制台不写）：新项目由 init/bootstrap 写，旧项目由启动事务（见 references/migration.md）迁移时写；高于本工具已知最新的形状号直接拒绝。行为证据：tests/task-model-routing.sh 的 heal 组||task-model
TEAM_UPDATE_CHECK|apply|bool||plain|1|-|启动路径上的 npm 版本提示：0 = 连查询都不发生（不读不写缓存）；只有本地落后时打一行，工具从不自己安装。行为证据：tests/task-model-routing.sh 的 updatecheck 组||workflow
# ---- 工作流与门禁（apply）----
TEAM_GATES|apply|cmd||plain||-|||workflow
TEAM_INSTALL_CMD|apply|cmd||plain||-|||workflow
TEAM_TASK_BRANCH_RESET|apply|bool||plain|1|-|||workflow
TEAM_DISPATCH_VERIFY_SEC|apply|seconds|0,|plain|8|-|||workflow
TEAM_DISPATCH_ALIVE_SEC|apply|seconds|0,|plain|1|-|||workflow
TEAM_SQUASH_LOOKBACK|apply|int|0,|plain|200|0 = 「已 squash 合并」的回看数为零|||workflow
TEAM_REVIEW_TIMEOUT|apply|seconds|0,|plain|1800|低于 60 秒 = 门禁会被超时掐死||600,1800,3600|workflow
TEAM_REVIEW_TIMEOUT_GRACE|apply|seconds|0,|plain|2|-|||workflow
TEAM_REVIEW_ALLOW_DIRTY|apply|bool||plain|0|1 = 复验放行脏工作树|||workflow
TEAM_REVIEW_ALLOW_IGNORED|apply|bool||plain|0|1 = 复验放行被忽略产物|||workflow
TEAM_REVIEW_ALLOW_UNRESOLVED_BRANCH|apply|bool||plain|0|1 = 给解析不到的分支盖章|||workflow
TEAM_REVIEW_ANY_DIR|apply|bool||plain|0|1 = 跳过 checkout HEAD == 分支 tip 守卫|||workflow
TEAM_BOARD_DONE_FORCE|apply|bool||plain|0|1 = 绕过 done 的证据闸门|||workflow
TEAM_BOARD_DONE_REASON|apply|text||plain||-|||workflow
# ---- 容量与投递通知（apply）----
TEAM_MIN_FREE_SWAP_MB|apply|mb|0,|plain|1024|0 = 磁盘 swap 底线关闭||512,1024,2048|delivery
TEAM_MIN_TOTAL_MB|apply|mb|0,|plain|512|0 = RAM+swap 绝对底线关闭||256,512,1024|delivery
TEAM_MIN_AVAIL_MB|apply|mb|0,|plain|1024|0 = MemAvailable 底线关闭||512,1024,2048|delivery
TEAM_TMP_MIN_FREE_MB|apply|mb|0,|plain|1024|0 = 临时根可用空间底线关闭||512,1024,2048|delivery
TEAM_TMP_MIN_FREE_INODES|apply|int|0,|plain|100000|0 = 临时根 inode 底线关闭||50000,100000,200000|delivery
TEAM_WARN_AVAIL_MB|apply|mb|0,|plain|2048|0 = 内存只警告的水位关闭||1024,2048,4096|delivery
TEAM_ZRAM_WARN_PCT|apply|pct|0,100|plain|85|-||70,80,85,90|delivery
TEAM_AGENT_MEM_MB|apply|mb|1,|plain|6144|-||2048,4096,6144|delivery
TEAM_NOTIFY_TMUX|apply|bool||plain|1|-|||delivery
TEAM_NOTIFY_DEDUP_SEC|apply|seconds|0,|plain|20|-|||delivery
TEAM_INBOX_MAX_CHARS|apply|int|1,|plain|150|-||100,150,300|delivery
TEAM_NOTIFY_DETAIL_MAX|apply|int|1,|plain|2048|state/notify.log 的事件上界：越界轮转到 state/notify.log.1（只留一代）||512,2048,8192|delivery
TEAM_NOTIFY_LOG|apply|path|file,opt|plain|/tmp/teamsmith-notify.log|-|||delivery
TEAM_DEFER_TTL|apply|seconds|0,|plain|300|0 = 投递队列入队即过期||60,300,900|delivery
TEAM_OUTBOX_MAX|apply|int|0,|plain|200|0 = 队列不设上限（无界）||50,200,1000|delivery
TEAM_PANEL_DETAIL_CAP|apply|bytes|1024,|plain|131072|-||65536,131072,262144|delivery
# ---- 巡检与面板（restart：运行中的 pulse/面板拿着启动时的值）----
TEAM_PULSE_INTERVAL|restart|seconds|60,|plain|900|低于 60 秒 = 巡检转成忙等||300,900,1800,3600|panel
TEAM_MONITOR_REFRESH|restart|seconds|1,|plain|3|-||2,3,5|panel
TEAM_MONITOR_EVENTS|restart|int|1,|plain|4|-||2,4,8|panel
TEAM_MONITOR_UI|restart|enum|auto,tui,text|plain|auto|-|||panel
TEAM_MONITOR_ACTIVITY|restart|bool||export|1|-|||panel
TEAM_AGENT_LOG_TAIL_BYTES|restart|bytes|0,1048576|export||-|||panel
TEAM_PULSE_WINDOW|restart|text||plain|pulse|改的是运行中后端的窗口名：team pulse down（旧名）→ 改 → team pulse up|||panel
# ---- 巡检策略（apply：一拍一个 team watch --once 子进程）----
TEAM_PULSE_NUDGE_GAP|apply|seconds|0,|plain|900|-||300,900,1800|patrol
TEAM_PULSE_PENDING_BOARD|apply|bool||plain|0|-|||patrol
TEAM_PULSE_REBUILD_TMUX|apply|bool||plain|0|-|||patrol
TEAM_PULSE_MAX_RESTARTS|apply|int|0,|plain|5|0 = PM 崩溃后不再自动拉起|||patrol
# ---- PM 生命周期（restart：运行中的 PM 拿着旧参数，team up 用新的）----
TEAM_PM_SESSION_ID|restart|text||plain||-|||pm-lifecycle
TEAM_PM_CMD|restart|tpl|pm|plain||-|||pm-lifecycle
TEAM_PM_BIN|restart|path|exec,opt|plain||-|||pm-lifecycle
TEAM_PM_EXTRA_PI_ARGS|restart|cmd||plain||-|||pm-lifecycle
TEAM_PM_RESUME_ARGS|restart|cmd||plain||-|||pm-lifecycle
TEAM_PM_START_WAIT|apply|seconds|0,|plain|6|-|||pm-lifecycle
# ---- 活着的会话（restart：扩展在运行中的进程里读环境）----
TEAM_INBOX_WATCH_MAX_BYTES|restart|bytes|1024,|export|131072|-|||session
TEAM_INBOX_WATCH_PREVIEW|restart|int|16,|export|160|-|||session
TEAM_INBOX_WATCH_REPLAY_MAX|restart|int|1,|export|20|-|||session
TEAM_INBOX_WATCH_SEEN_MAX|restart|int|32,|export|512|-|||session
TEAM_INBOX_WATCH_STALE|restart|seconds|1,|export|300|-|||session
TEAM_INBOX_WATCH_STALE_SEC|restart|seconds|1,|export|900|-|||session
TEAM_INBOX_WATCH_POLL_MS|restart|int|100,|export|5000|-|||session
TEAM_INBOX_WATCH_HEARTBEAT_MS|restart|int|100,|export|5000|-|||session
TEAM_INBOX_WATCH_TARGET|restart|text||export||-|||session
TEAM_BG_LOG_MAX_BYTES|restart|bytes|1024,|export|524288|-|||session
# ---- 信号纪律（P159 · refuse：闸门接缝与宽限由手改契约控制）----
TEAM_SIGNAL_CALLS_LOG|refuse|path|file,opt|plain||-|P159 信号闸门：每次调用一行（拒绝另存 <log>.forensics，熬得过轮转）；窗口启动时由闸门前缀钉值，要改就手改 .pi/team/config.sh||policy
TEAM_SIGNAL_REAL|refuse|path|exec,opt|plain||-|P159 信号闸门的真身路径（夹具钉桩用；拒绝不依赖它能否解析）；手改 .pi/team/config.sh||policy
TEAM_BG_STOP_GRACE|refuse|seconds|0,|plain|5|-|P159 team bg stop 的宽限：组 TERM 之后等这么多秒再 KILL（0 = 不等待，立刻升级）；手改 .pi/team/config.sh||policy
# ---- 跨项目会议（apply）----
TEAM_MEETING_TTL_HOURS|apply|int|1,|plain|72|-||24,72,168|meeting
TEAM_MEETING_MAX_TURNS|apply|int|1,|plain|20|-||5,20,50|meeting
TEAM_MEETING_KNOCK|apply|bool||plain|0|-|||meeting
TEAM_MEETING_ALLOW_USER_ID|apply|text||plain||非空 = 放开谁能敲门（扩大权限）|||meeting
EOF
}

# 契约文件定位：没有就点名 team init（绝不悄悄造一个）。
team_config_contract_path() {
  local p="${TEAM_CONFIG:-}"
  if [ -z "$p" ] && [ -n "${TEAM_CONFIG_FILE:-}" ]; then p="$TEAM_CONFIG_FILE"; fi
  if [ -z "$p" ] && [ -n "${TEAM_MAIN_ROOT:-}" ] && [ -f "$TEAM_MAIN_ROOT/.pi/team/config.sh" ]; then
    p="$TEAM_MAIN_ROOT/.pi/team/config.sh"
  fi
  if [ -z "$p" ] || [ ! -f "$p" ]; then
    team_err "找不到项目契约 .pi/team/config.sh（$p）"
    team_dim "  这个项目还没初始化：先跑 $TEAM_CLI init（或 $TEAM_CLI bootstrap）" >&2
    return 1
  fi
  printf '%s\n' "$p"
}

team_config_field() { # <row> <n:1..10> → 字段（第 9 列 suggest / 第 10 列 group 无默认；畸形行返回空串）
  local row="$1" n="$2"
  local -a f=()
  IFS='|' read -r -a f <<< "$row"
  printf '%s\n' "${f[$((n-1))]:-}"
}

team_config_row() { # <KEY> → schema 行（找不到返回 1）
  local want="$1" row
  while IFS= read -r row; do
    case "$row" in \#*|'') continue ;; esac
    [ "${row%%|*}" = "$want" ] && { printf '%s\n' "$row"; return 0; }
  done < <(team_config_schema)
  return 1
}

team_config_choices_set() { # <row> [known models: 每行一个] → CFG_CHOICES_JSON（读路径无子 shell）
  # 唯一来源是 schema 行（加 models 块的 known）：bool 的两个规范值、enum 的 constraints、数值类的
  # suggest 列、模型类的 known。面板读这个对象画选择器，因此它绝不能是第二张选项表。
  # empty = 写入者是否接受空值（与 team_config_validate_value 的 '' 判定同口径；走查夹具比对两者）。
  # note = 该键域的解释（今天只有 path 类用它携带存在性检查的类型 file|dir|exec|any），无话可说时为空。
  local row="${1-}" known="${2-}"
  local -a f=()
  IFS='|' read -r -a f <<< "$row"
  local kind="${f[2]:-}" spec="${f[3]:-}" suggest="${f[8]:-}"
  local src="none" min="" max="" empty="false" note="" val_list=""
  case "$kind" in
    bool)
      src="schema"; val_list=$'1\n0' ;;
    enum)
      src="schema"; val_list="${spec//,/$'\n'}" ;;
    int|seconds|mb|bytes|pct)
      src="schema"
      IFS=, read -r min max _ <<< "$spec"
      val_list="${suggest//,/$'\n'}" ;;
    model|task-model-map|pairlist|winlist|pattern)
      src="known"; val_list="$known" ;;
    path)
      local typ="${spec%%,*}"; note="${typ:-any}" ;;
  esac
  case "$kind" in
    bool|int|seconds|mb|bytes|pct) empty="false" ;;
    enum) case ",$spec," in *",,"*) empty="true" ;; esac ;;
    path) case "$spec" in *,opt) empty="true" ;; esac ;;
    model) [ "$spec" = "opt" ] && empty="true" ;;
    pairlist|pattern|winlist|tpl|list|cmd|text) empty="true" ;;
  esac
  local values_json="" v first=1
  while IFS= read -r v; do
    [ -n "$v" ] || continue
    [ "$first" = "1" ] || values_json="$values_json,"
    first=0
    team_config_json_escape_set "$v"
    values_json="$values_json\"$CFG_ESC\""
  done <<< "$val_list"
  team_config_json_escape_set "$min"; local min_json="$CFG_ESC"
  team_config_json_escape_set "$max"; local max_json="$CFG_ESC"
  team_config_json_escape_set "$note"; local note_json="$CFG_ESC"
  CFG_CHOICES_JSON="{\"source\":\"$src\",\"values\":[$values_json],\"min\":\"$min_json\",\"max\":\"$max_json\",\"empty\":$empty,\"note\":\"$note_json\"}"
}

team_config_choices() { # <row> [known models] → 打印对象（兼容包装；读热路径用 _set，省一次 fork）
  team_config_choices_set "${1-}" "${2-}"
  printf '%s\n' "$CFG_CHOICES_JSON"
}
team_config_key_form() { # <KEY> → plain|export（未知键 = plain）
  local row; row="$(team_config_row "$1" 2>/dev/null || true)"
  [ -n "$row" ] || { printf 'plain\n'; return 0; }
  local form; form="$(team_config_field "$row" 5)"
  printf '%s\n' "${form:-plain}"
}

# notify 扩展用扁平 KEY="value" 读取器解析的八个键：值里出现 ' 就没有转义可用 → 拒写（设计 §4）。
TEAM_CONFIG_FLAT_KEYS=" TEAM_SESSION TEAM_PM_WINDOW TEAM_WORKTREES_DIR TEAM_DOCS_DIR TEAM_NOTIFY_TMUX TEAM_NOTIFY_DEDUP_SEC TEAM_INBOX_MAX_CHARS TEAM_NOTIFY_LOG TEAM_NOTIFY_DETAIL_MAX "
team_config_flat_key() { # <KEY> → 0 = 扁平读取器的键
  case "$TEAM_CONFIG_FLAT_KEYS" in *" $1 "*) return 0 ;; esac
  return 1
}

# ---------------------------------------------------------------- 契约文件的小工具
team_config_trim() { team_trim "${1-}"; }

team_config_file_line() { # <file> <KEY> → 该键在文件里的整行（无 → 返回 1）
  local f="$1" k="$2"
  grep -E "^[[:space:]]*(export[[:space:]]+)?$k=" "$f" 2>/dev/null | head -1
}

team_config_file_value() { # <file> <KEY> → 文件里的字面值（去引号/行内注释；无 → 返回 1）
  local f="$1" k="$2" line rest comment
  line="$(team_config_file_line "$f" "$k")" || return 1
  [ -n "$line" ] || return 1
  rest="${line#*=}"
  comment="$(printf '%s' "$line" | team_config_inline_comment_of_line)"
  [ -n "$comment" ] && rest="${rest%"$comment"}"
  rest="$(team_config_trim "$rest")"
  case "$rest" in
    \"*\") rest="${rest#\"}"; rest="${rest%\"}" ;;
    \'*\') rest="${rest#\'}"; rest="${rest%\'}" ;;
  esac
  printf '%s\n' "$rest"
}

team_config_file_comment() { # <file> <KEY> → 行内注释（含 #；无 → 空）
  local f="$1" k="$2" line
  line="$(team_config_file_line "$f" "$k")" || return 0
  [ -n "$line" ] || return 0
  printf '%s' "$line" | team_config_inline_comment_of_line
}

team_config_fingerprint() { # <file> → sha256
  local out
  out="$(sha256sum "$1" 2>/dev/null | awk '{print $1}')" || true
  if [ -z "$out" ]; then out="$(shasum -a 256 "$1" 2>/dev/null | awk '{print $1}')" || true; fi
  printf '%s\n' "$out"
}

team_config_mtime() { # <file> → UTC ISO-8601
  date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || stat -c %y "$1" 2>/dev/null | cut -c1-19 | tr ' ' 'T' \
    || printf '\n'
}

team_config_json_escape() { # JSON 字符串转义（含控制字符）
  team_config_json_escape_set "${1-}"
  printf '%s' "$CFG_ESC"
}

# 读路径的无子 shell 版本（M65/Q3）：`team config list --json` 每个键、每个字段一次 `$(...)`
# 就是一次 fork —— 108 键的契约里命令替换是扫描之外的主要残余成本。结果落在 CFG_ESC。
team_config_json_escape_set() { # <text> → CFG_ESC
  local v="${1-}"
  v="${v//\\/\\\\}"
  v="${v//\"/\\\"}"
  v="${v//$'\t'/\\t}"
  v="${v//$'\r'/\\r}"
  v="${v//$'\n'/\\n}"
  CFG_ESC="$v"
}

# ---------------------------------------------------------------- 值的校验（唯一校验器）
# team_config_validate_value <KEY> <value> → 0 合法；非 0 时把「接受域」打进 stdout（调用方转 exit 4）
team_config_validate_value() {
  local key="$1" val="${2-}" row class kind spec form
  row="$(team_config_row "$key" 2>/dev/null || true)"
  if [ -z "$row" ]; then
    printf '不是已知的项目设置键（references/config.md 是清单）；自定义键请手改 .pi/team/config.sh\n'
    return 1
  fi
  class="$(team_config_field "$row" 2)"; kind="$(team_config_field "$row" 3)"
  spec="$(team_config_field "$row" 4)"; form="$(team_config_field "$row" 5)"
  if [ "$class" = "refuse" ]; then
    printf '只读键（%s）\n' "$(team_config_field "$row" 8)"
    return 1
  fi
  case "$val" in
    *$'\n'*) printf '值不能含换行（契约是单行 KEY=value）\n'; return 1 ;;
    *'#'*)   printf '值不能含 #（notify 扩展的扁平读取器会从这里截断）\n'; return 1 ;;
  esac
  if team_config_flat_key "$key" && case "$val" in *"'"*) true ;; *) false ;; esac; then
    printf '%s 由 notify 扩展的扁平读取器解析，值里不能有单引号（那个读取器没有转义）\n' "$key"
    return 1
  fi
  local min max n
  case "$kind" in
    bool)
      case "$val" in
        0|1|true|false|yes|no|on|off) return 0 ;;
        *) printf '只接受 0/1（也认 true/false/yes/no/on/off）\n'; return 1 ;;
      esac ;;
    int|seconds|mb|bytes|pct)
      case "$val" in
        ''|*[!0-9]*) printf '只接受非负整数\n'; return 1 ;;
      esac
      IFS=, read -r min max <<< "$spec"
      if [ -n "$min" ] && [ "$val" -lt "$min" ]; then
        printf '超出范围：最小 %s%s\n' "$min" "$([ -n "$max" ] && printf -- '，最大 %s' "$max")"; return 1
      fi
      if [ -n "$max" ] && [ "$val" -gt "$max" ]; then
        printf '超出范围：最小 %s，最大 %s\n' "${min:-0}" "$max"; return 1
      fi
      return 0 ;;
    enum)
      case ",$spec," in *",$val,"*) return 0 ;; esac
      printf '只接受：%s\n' "$(printf '%s' "$spec" | tr ',' '|')"; return 1 ;;
    path)
      local typ="${spec%%,*}" opt=0
      case "$spec" in *,opt) opt=1 ;; esac
      [ -n "$val" ] && return 0
      if [ "$opt" = "1" ]; then return 0; fi
      printf '路径不能为空\n'; return 1 ;;
    model)
      local optm=0; [ "$spec" = "opt" ] && optm=1
      [ -z "$val" ] && { [ "$optm" = "1" ] && return 0; printf '必须形如 provider/model\n'; return 1; }
      local mwhy
      if mwhy="$(team_config_model_violation "$val")"; then return 0; fi
      printf '%s\n' "$mwhy"; return 1 ;;
    task-model-map)
      team_task_map_violation "$val" ;;
    pairlist)
      local tok seat model r mwhy; r=0
      for tok in $val; do
        case "$tok" in
          *=*) seat="${tok%%=*}"; model="${tok#*=}" ;;
          *) printf '只接受 seat=provider/model 空格分隔（%s 没有 =）\n' "$tok"; return 1 ;;
        esac
        if ! team_config_seat_known "$seat"; then
          printf '席位 %s 不在名册（%s）也不叫 pm\n' "$seat" "$(team_config_roster_text)"; return 1
        fi
        local mwhy
        if ! mwhy="$(team_config_model_violation "$model")"; then
          printf '席位 %s 的模型：%s\n' "$seat" "$mwhy"; return 1
        fi
      done
      return 0 ;;
    pattern)
      local t p num
      for t in $val; do
        p="${t%%=*}"
        if [ "$p" = "$t" ] || [ -z "$p" ]; then printf '只接受 pattern=N 空格分隔（%s 没有 =）\n' "$t"; return 1; fi
        num="${t#*=}"
        case "$num" in ''|*[!0-9]*) printf '只接受 pattern=N（N 为非负整数，%s）\n' "$t"; return 1 ;; esac
      done
      return 0 ;;
    winlist)
      local t p num
      for t in $val; do
        p="${t%%=*}"
        if [ "$p" = "$t" ] || [ -z "$p" ]; then printf '只接受 model=N 空格分隔（%s 没有 =）\n' "$t"; return 1; fi
        num="${t#*=}"
        case "$num" in ''|*[!0-9]*) printf '只接受 model=N（N 为正整数，%s）\n' "$t"; return 1 ;; esac
      done
      return 0 ;;
    tpl)
      local kind_name="$2"
      case "$spec" in launch|notify|pm) kind_name="$spec" ;; esac
      [ -z "$val" ] && return 0
      if [ -z "$(team_trim "$val")" ]; then
        printf '只有空白（配了等于没配）：要么留空（走内置 Pi），要么写一条真正的命令\n'; return 1
      fi
      case "$val" in *$'\n'*) printf '模板必须是**一条**命令行（第二行会被窗口 shell 当新命令执行）\n'; return 1 ;; esac
      local bad; bad="$(team_agent_bogus_tokens "$kind_name" "$val" 2>/dev/null || true)"
      if [ -n "$bad" ]; then
        printf '有未知占位符：%s（支持：%s）\n' "$(printf '%s' "$bad" | tr '\n' ' ')" "$(team_agent_support_list "$kind_name")"
        return 1
      fi
      return 0 ;;
    list)
      # 名册（唯一 list 类键）的席位名规则：token 会成为 .worktrees/ 目录名、tmux 窗口名、state 文件名
      # 与分支名 —— 形状不是装饰。读（team config list --json 的 warning）与写共用这一个判定，
      # 不许长第二份（P99/R1）。合法时返回 0；不合法时把原因打进 stdout（调用方转 exit 4）。
      local lwhy
      if lwhy="$(team_config_list_violation "$val")"; then return 0; fi
      printf '%s\n' "$lwhy"; return 1 ;;
    cmd|text)
      return 0 ;;
    *)
      printf '内部错误：未知 kind %s\n' "$kind"; return 1 ;;
  esac
}

# 值的规范化（写进文件的形式）：bool → 1/0，其余原样。
team_config_canonical_value() { # <KEY> <value> → 规范值
  local key="$1" val="${2-}" row kind
  row="$(team_config_row "$key" 2>/dev/null || true)"
  kind="$(team_config_field "$row" 3)"
  if [ "$kind" = "bool" ]; then
    case "$val" in
      1|true|yes|on) printf '1\n'; return 0 ;;
      0|false|no|off) printf '0\n'; return 0 ;;
    esac
  fi
  printf '%s\n' "$val"
}

# 模型值形状的**一处判定**（change: model-id-shape R1）：provider = 第一个 `/` 之前（非空、不含 `:`），
# model = 之后全部（先剥第一个 `:` 起的思考档后缀再判：body 非空、每段非空），整体不含空白。
# 合法 → 返回 0、无输出；不合法 → 返回 1、stdout 是**点名段落**（provider/model）的原因。
# model kind、pairlist token、set-agent-model 与 add-agent --model 全走这里，不许长第二份。
team_config_model_violation() { # <model> → 0 合法；1 时 stdout 是原因
  local val="${1-}" prov body
  case "$val" in
    */*) ;;
    *) printf 'provider 缺失：需要 provider/model 形状（没有 /）\n'; return 1 ;;
  esac
  prov="${val%%/*}"; body="${val#*/}"
  case "$val" in *[[:space:]]*)
      case "$prov" in *[[:space:]]*) printf 'provider 含空白（空格/制表符/换行）\n'; return 1 ;; esac
      printf 'model 含空白（空格/制表符/换行）\n'; return 1 ;; esac
  [ -n "$prov" ] || { printf 'provider 为空（/ 前没有内容）\n'; return 1; }
  case "$prov" in *:*) printf 'provider 不能含 :（:思考档 后缀只属于 model 段）\n'; return 1 ;; esac
  body="${body%%:*}"    # 后缀先剥再判形状；调用方写盘的值仍保留后缀
  [ -n "$body" ] || { printf 'model 为空（/ 后没有内容，或 :思考档 后缀前为空）\n'; return 1; }
  case "/$body/" in
    *//*) printf 'model 有空段（/ 分隔的每一段都必须非空）\n'; return 1 ;;
  esac
  return 0
}

# 布尔包装（面板与旧调用方问「行不行」）：判定本体在 team_config_model_violation。
team_config_model_shape_ok() { # <model> → 0 合法 / 1 不合法
  team_config_model_violation "${1-}" >/dev/null 2>&1
}

# 名册值规则（唯一一份）：空格分隔的席位名，每个匹配 [A-Za-z0-9][A-Za-z0-9._-]*、只出现一次、
# 且不是 pm（PM 席位不是名册成员）。合法 → 返回 0；不合法 → 打印原因（点名 token 与接受形状）返回 1。
team_config_list_violation() { # <value> → 0 合法；1 时 stdout 是原因
  local val="${1-}" tok shape='[A-Za-z0-9][A-Za-z0-9._-]*' seen=" "
  for tok in $val; do
    if [ "$tok" = "pm" ]; then
      printf '席位名 pm 非法：pm 是 PM 席位，不是名册成员（接受 %s）\n' "$shape"; return 1
    fi
    case "$tok" in
      [!A-Za-z0-9]*) printf '席位名 %s 非法：接受 %s（首字符必须是字母或数字）\n' "$tok" "$shape"; return 1 ;;
    esac
    case "${tok#?}" in
      *[!A-Za-z0-9._-]*) printf '席位名 %s 非法：接受 %s\n' "$tok" "$shape"; return 1 ;;
    esac
    case "$seen" in *" $tok "*) printf '席位名 %s 重复出现：名册里每个席位只能出现一次\n' "$tok"; return 1 ;; esac
    seen="$seen$tok "
  done
  return 0
}

# 席位名（**单个** token）的规则：名册值规则管的是**结果值**，而写入器把席位名当一个 token 追加 ——
# `api 1` 加进去会变成两个各自合法的 token，值规则不会响（P105/F1 实测：名册被写脏 + 一行 result=ok，
# 命令随后才在 worktree 步骤以「未知 agent」失败）。所以 add 路径在任何写入之前先在这一层拒：空、
# 含空白（空格/制表符/换行）、以及单 token 上跑列表规则的一切（形状、pm、斜杠）—— 一条规则，读写同源。
# 合法 → 0；不合法 → stdout 是原因，返回 1。remove 路径不查：移掉手改出来的非法 token 是合法的。
team_config_seat_violation() { # <seat> → 0 合法；1 时 stdout 是原因
  local seat="${1-}" why shape='[A-Za-z0-9][A-Za-z0-9._-]*'
  case "$seat" in
    '') printf '席位名不能为空\n'; return 1 ;;
    *[[:space:]]*)
      printf '席位名 %s 非法：席位名是一个 token，不能含空白（空格/制表符）；接受 %s\n' "$seat" "$shape"; return 1 ;;
  esac
  if ! why="$(team_config_list_violation "$seat")"; then printf '%s\n' "$why"; return 1; fi
  return 0
}

# danger：合法的值也会关掉已发布的守卫（设计 §5）。命中 → stdout 一行理由，返回 1。
team_config_danger_reason() { # <KEY> <value>
  local key="$1" val="${2-}"
  case "$key" in
    TEAM_MIN_FREE_SWAP_MB|TEAM_MIN_TOTAL_MB|TEAM_MIN_AVAIL_MB|TEAM_WARN_AVAIL_MB|TEAM_TMP_MIN_FREE_MB|TEAM_TMP_MIN_FREE_INODES)
      [ "$val" = "0" ] && { printf '容量底线归零（守卫失效）\n'; return 1; } ;;
    TEAM_SQUASH_LOOKBACK)
      [ "$val" = "0" ] && { printf '「已 squash 合并」判定关闭\n'; return 1; } ;;
    TEAM_REVIEW_TIMEOUT)
      case "$val" in ''|*[!0-9]*) ;; *) [ "$val" -lt 60 ] && { printf '门禁超时低于 60 秒（正常门禁会被掐死）\n'; return 1; } ;; esac ;;
    TEAM_PULSE_INTERVAL)
      case "$val" in ''|*[!0-9]*) ;; *) [ "$val" -lt 60 ] && { printf '巡检周期低于 60 秒（转成忙等）\n'; return 1; } ;; esac ;;
    TEAM_PULSE_MAX_RESTARTS)
      [ "$val" = "0" ] && { printf 'PM 崩溃后不再自动拉起\n'; return 1; } ;;
    TEAM_DEFER_TTL|TEAM_OUTBOX_MAX)
      [ "$val" = "0" ] && { printf '投递队列的守卫关闭\n'; return 1; } ;;
    TEAM_REVIEW_ALLOW_DIRTY|TEAM_REVIEW_ALLOW_IGNORED|TEAM_REVIEW_ALLOW_UNRESOLVED_BRANCH|TEAM_REVIEW_ANY_DIR)
      [ "$val" = "1" ] && { printf '复验守卫的旁路被打开\n'; return 1; } ;;
    TEAM_BOARD_DONE_FORCE)
      [ "$val" = "1" ] && { printf 'done 的证据闸门被绕过\n'; return 1; } ;;
    TEAM_MEETING_ALLOW_USER_ID)
      [ -n "$val" ] && { printf '放开了一个扩权入口（谁能敲门）\n'; return 1; } ;;
    TEAM_PULSE_WINDOW)
      local old; old="$(team_config_file_value "$(team_config_contract_path 2>/dev/null || true)" "$key" 2>/dev/null || true)"
      [ -z "$old" ] && old="$(team_config_field "$(team_config_row "$key")" 6)"
      if [ "$val" != "$old" ] && [ -n "${TEAM_SESSION:-}" ] && team_have_cmd tmux \
         && tmux has-session -t "$TEAM_SESSION" 2>/dev/null; then
        printf '运行中的 pulse 后端还在旧窗口 %s：先 team pulse down 再改，然后 team pulse up\n' "$old"
        return 1
      fi ;;
  esac
  return 0
}

# ---------------------------------------------------------------- 审计（state/config.log）
team_config_audit_file() { printf '%s\n' "${TEAM_STATE_DIR:-.pi/team/state}/config.log"; }

team_config_audit_quote() { # 单引号形态，保证一行
  local v="${1-}"
  v="$(printf '%s' "$v" | sed -e "s/'/'\\\\''/g")"
  printf '%s' "$v"
}

team_config_audit_write() { # <result> <actor> <key> <old> <new> [expected] [actual]
  local result="$1" actor="$2" key="$3" old="$4" new="$5" expected="${6:-}" actual="${7:-}"
  local f; f="$(team_config_audit_file)"
  mkdir -p "$(dirname "$f")" 2>/dev/null || true
  local line
  line="$(date -u +%Y-%m-%dT%H:%M:%SZ) result=$result actor=$(team_config_audit_quote "$actor") key=$key old='$(team_config_audit_quote "$old")' new='$(team_config_audit_quote "$new")'"
  if [ -n "$expected" ] || [ -n "$actual" ]; then
    line="$line expected=${expected:-} actual=${actual:-}"
  fi
  if ! printf '%s\n' "$line" >> "$f" 2>/dev/null; then
    team_warn "审计写不进 $f：本次写入结果照旧报告（缺审计行不等于写失败）"
    return 1
  fi
  return 0
}

# 最多读最后 16 KiB，打印最新 N 行（时间顺序：旧的在前）。
team_config_audit_tail() { # [N=10]
  local n="${1:-10}" f; f="$(team_config_audit_file)"
  [ -f "$f" ] || return 0
  tail -c 16384 "$f" 2>/dev/null | tail -n "$n" 2>/dev/null
}

# ---------------------------------------------------------------- 席位（models 块）
team_config_roster_text() { team_agents | tr '\n' ' ' | sed -e 's/[[:space:]]*$//'; }

team_config_seat_known() { # <seat> → 0 = 名册席位或 pm
  local seat="$1"
  [ "$seat" = "pm" ] && return 0
  team_agent_known "$seat"
}

# 已记录但名册不再承认的席位（typo dev4=… 不得静默失效）
team_config_pairlist_unknown_seats() { # <value> → 每行一个未知席位
  local tok seat
  for tok in ${1-}; do
    case "$tok" in
      *=*) seat="${tok%%=*}" ;;
      *) seat="$tok" ;;
    esac
    team_config_seat_known "$seat" || printf '%s\n' "$seat"
  done
}

# 席位行的字段安全拆读：`IFS=$'\t' read` 会把**前导空字段**当分隔空白吃掉 —— 空模型（`dev=` 且回退
# 也为空，或 pm 席位无模型）时 read 会把 source 标签读成 model、把 override 读成 source，最后吐出一个
# 无值字段（`"override":}`）让整个文档失解。这里按字节切，空字段原样保留。
team_config_seat_split() { # <model<TAB>source<TAB>override> <var_model> <var_src> <var_override>
  local line="$1" rest
  case "$line" in *$'\t'*) rest="${line#*$'\t'}" ;; *) rest="" ;; esac
  printf -v "$4" '%s' "${rest#*$'\t'}"
  printf -v "$3" '%s' "${rest%%$'\t'*}"
  printf -v "$2" '%s' "${line%%$'\t'*}"
}

# 席位显示口径与 team ps 同源：有记录用记录，没记录用配置解析；来源 = team_agent_model_src。
team_config_seat_state() { # <seat> → model<TAB>source<TAB>override
  local seat="$1" model src override="false"
  if [ "$seat" = "pm" ]; then
    local pmv; pmv="$(team_config_file_value "$(team_config_contract_path 2>/dev/null || true)" TEAM_PM_MODEL 2>/dev/null || true)"
    [ -n "$pmv" ] && override="true"
    # P58/F1：模型与 PM 的启动解析**同源**（team_pm_model_resolve == team_pm_pi_args 用的那一行）：
    # 空 TEAM_DEFAULT_MODEL 时启动回退到 schema 默认，席位行也必须回退 —— 否则它会在空默认角落说 ""，
    # 与「实际会用的模型」分叉（P54 的 F1）。
    model="$(team_pm_model_resolve)"
    src="$(team_agent_model_src pm 2>/dev/null || printf '配置')"
    printf '%s\t%s\t%s\n' "${model:-}" "$src" "$override"
    return 0
  fi
  if [[ " ${TEAM_AGENT_MODELS:-} " == *" $seat="* ]]; then override="true"; fi
  model="$(team_state_get "$seat" model "$(team_agent_model "$seat")")"
  src="$(team_agent_model_src "$seat")"
  printf '%s\t%s\t%s\n' "$model" "$src" "$override"
}

team_config_seat_source_token() { # <中文标签> → config|explicit|record
  case "$1" in
    显式) printf 'explicit\n' ;;
    历史记录) printf 'record\n' ;;
    *) printf 'config\n' ;;
  esac
}

# ---------------------------------------------------------------- list
# ---------------------------------------------------------------- 读路径：契约的一次性扫描（M65/D11 · M2）
# `team config list --json` 的成本原来全在 fan-out：每个已知键两次 `grep|head`+`awk`（值 + 注释），
# 未知键的扫描再**每文件行** spawn 一个 `sed`。108 键的契约实测 ~600 个子进程、~3.5 s，而面板每次"
# 进视图/开行/选项"都同步调它。这里一次 awk 过契约，得到「赋值行的出现顺序」+「每个键第一次出现的
# 值/行内注释」；下面的两个循环只在 bash 里查表。语义逐字对齐 team_config_file_line/_value/_comment：
# 同名取第一行、引号内的 # 不是注释（双引号里的反斜杠转义也照旧）、值去首尾空白与一层引号、
# 注释含 # 前的空白并原样保留。
CFG_SCAN_ORDER=""
declare -gA CFG_SCAN_VALUE=()
declare -gA CFG_SCAN_COMMENT=()
team_config_scan() { # <file> → 填 CFG_SCAN_*（一次 awk；值/注释取首次出现，顺序含重复行）
  local f="$1" k v c
  CFG_SCAN_ORDER=""
  CFG_SCAN_VALUE=()
  CFG_SCAN_COMMENT=()
  while IFS=$'\x1f' read -r k v c; do
    [ -n "$k" ] || continue
    CFG_SCAN_ORDER="$CFG_SCAN_ORDER$k"$'\n'
    if [ -z "${CFG_SCAN_VALUE[$k]+x}" ]; then
      CFG_SCAN_VALUE["$k"]="$v"
      CFG_SCAN_COMMENT["$k"]="$c"
    fi
  done < <(awk '
  /^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=/ {
    line = $0
    p = index(line, "=")
    head = substr(line, 1, p - 1)
    gsub(/^[[:space:]]*/, "", head)
    sub(/^export[[:space:]]+/, "", head)
    gsub(/[[:space:]]+$/, "", head)
    s = substr(line, p + 1)
    n = length(s); q = 0; i = 1; comment = ""
    while (i <= n) {
      ch = substr(s, i, 1)
      if (q == 0) {
        if (ch == "\"") q = 2
        else if (ch == sprintf("%c", 39)) q = 1
        else if (ch == "#") {
          g = i; while (g > 1 && (substr(s, g-1, 1) == " " || substr(s, g-1, 1) == "\t")) g--
          comment = substr(s, g); s = substr(s, 1, g - 1); break
        }
      } else if (q == 1) { if (ch == sprintf("%c", 39)) q = 0 }
      else if (q == 2) { if (ch == "\\") i++; else if (ch == "\"") q = 0 }
      i++
    }
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
    if (s ~ /^".*"$/ || s ~ /^\047.*\047$/) s = substr(s, 2, length(s) - 2)
    printf "%s%c%s%c%s\n", head, 31, s, 31, comment
  }' "$f")
}

# P30/R1：每条记录带 `group`——schema 行的第 10 列逐字（畸形行也照实输出空串，绝不造默认组）；
# 文件里 schema 不认识的键 group 为空串。字段是加法的：既有字段名/类型/顺序与 human 表、其它机器出口都不动。
team_config_list_json() {
  local path; path="$(team_config_contract_path)" || return 1
  local fingerprint mtime
  fingerprint="$(team_config_fingerprint "$path")"
  mtime="$(team_config_mtime "$path")"

  # M65/D11（M2 的修法）：一次扫描 + 纯 bash 查表与拼 JSON。命令替换 `$(...)` 也是一次 fork，
  # 所以读路径用 *_set 写变量的孪生函数（json escape / choices），键行只用一次 `read -a` 拆。
  local out="" first=1 row key class kind form def
  local value comment set warning
  team_config_scan "$path"
  # models 块的 known 先算：它也是模型类键的 choices 词表（choices 必须随键记录一起输出，所以
  # 不能等键循环结束）。token 与顺序和原来逐字一致；每个席位的**显示**模型也在表里（R2）。
  local known_models="" known_list="" seen=' ' tok a
  local categories='' assignments='' policy_pm='' pm_launch='{}'
  if team_task_map_violation "${TEAM_TASK_MODELS:-}" >/dev/null; then
    for tok in $TEAM_TASK_MODELS; do
      team_config_json_escape_set "${tok%%=*}"; local ec="$CFG_ESC"
      team_config_json_escape_set "${tok#*=}"; local em="$CFG_ESC"
      categories="${categories:+$categories,}{\"category\":\"$ec\",\"model\":\"$em\"}"
      known_models="$known_models${tok#*=}"$'\n'
    done
  fi
  if team_config_model_shape_ok "${TEAM_PM_MODEL:-}"; then
    policy_pm="$TEAM_PM_MODEL"; known_models="$known_models$policy_pm"$'\n'
  fi
  for a in $(team_agents); do
    local assigned=false diagnostic='' fields='' field val
    if team_assignment_load "$a"; then
      assigned=true
      # P228/R6（OBS1）：未交付的模型不进「已知模型」，也不当成该席位的模型
      if team_identity_delivered model; then known_models="$known_models${TEAM_ASSIGN[model]}"$'\n'
      else diagnostic='template delivered no model identity'; fi
    else diagnostic="$TEAM_ASSIGN_DIAGNOSTIC"; fi
    for field in task category model selected_via launch_via sid; do
      val=''; [ "$assigned" = false ] || val="${TEAM_ASSIGN[$field]}"
      if [ "$field" = model ] && ! team_identity_delivered model; then val=''; fi
      team_config_json_escape_set "$val"; fields="$fields,\"$field\":\"$CFG_ESC\""
    done
    val=''; [ "$assigned" = false ] || val="$(team_identity_delivered_set)"
    team_config_json_escape_set "$val"; fields="$fields,\"identity_via\":\"$CFG_ESC\""
    team_config_json_escape_set "$diagnostic"; local ed="$CFG_ESC"
    team_config_json_escape_set "$a"
    assignments="${assignments:+$assignments,}{\"agent\":\"$CFG_ESC\",\"assigned\":$assigned$fields,\"diagnostic\":\"$ed\"}"
  done
  if team_pm_metadata_load; then
    pm_launch="$TEAM_PM_METADATA_JSON"; known_models="$known_models$TEAM_PM_SELECTED_MODEL"$'\n'
  fi
  local dedup=''
  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    case "$seen" in *" $tok "*) continue ;; esac
    seen="$seen$tok "; dedup="$dedup$tok"$'\n'
    team_config_json_escape_set "$tok"; known_list="${known_list:+$known_list,}\"$CFG_ESC\""
  done <<< "$known_models"
  known_models="$dedup"

  local schema_keys="|"
  local -a f=()
  while IFS= read -r row; do
    case "$row" in \#*|'') continue ;; esac
    f=()
    IFS='|' read -r -a f <<< "$row"
    key="${f[0]:-}"; class="${f[1]:-}"; kind="${f[2]:-}"; form="${f[4]:-}"; def="${f[5]:-}"
    schema_keys="$schema_keys$key|"
    value=""; set="false"; comment=""; warning=""
    if [ -n "${CFG_SCAN_VALUE[$key]+x}" ]; then
      value="${CFG_SCAN_VALUE[$key]}"
      comment="${CFG_SCAN_COMMENT[$key]}"
      set="true"
    fi
    if [ "$key" = TEAM_TASK_MODELS ]; then
      local why; if ! why="$(team_task_map_violation "$value")"; then warning="$why"; fi
    elif [ "$key" = TEAM_PM_MODEL ]; then
      local why; if ! why="$(team_config_model_violation "$value")"; then warning="$why"; fi
    fi
    # P99/R1：名册的读侧 warning 与写侧的值规则是同一份判定（team_config_list_violation）——
    # 手改出一个非法 token 时，读给出警告、写入器拒绝的是同一条规则。
    if [ "$key" = "TEAM_AGENTS" ] && [ -n "$value" ]; then
      local rwhy
      if ! rwhy="$(team_config_list_violation "$value")"; then warning="$rwhy"; fi
    fi
    team_config_choices_set "$row" "$known_models"
    team_config_json_escape_set "${f[9]:-}"; local e_group="$CFG_ESC"
    team_config_json_escape_set "$key"; local e_key="$CFG_ESC"
    team_config_json_escape_set "$value"; local e_value="$CFG_ESC"
    team_config_json_escape_set "$def"; local e_def="$CFG_ESC"
    team_config_json_escape_set "$comment"; local e_comment="$CFG_ESC"
    team_config_json_escape_set "$warning"; local e_warning="$CFG_ESC"
    team_config_json_escape_set "${f[7]:-}"; local e_route="$CFG_ESC"
    [ "$first" = "1" ] || out="$out,"
    first=0
    out="$out{\"name\":\"$e_key\",\"class\":\"$class\",\"kind\":\"$kind\",\"form\":\"$form\",\"value\":\"$e_value\",\"default\":\"$e_def\",\"set\":$set,\"comment\":\"$e_comment\",\"warning\":\"$e_warning\",\"route\":\"$e_route\",\"choices\":$CFG_CHOICES_JSON,\"group\":\"$e_group\",\"known\":true}"
  done < <(team_config_schema)

  # 文件里 schema 不认识的键：照实列出（面板只读展示「不是已知项目设置」），文件顺序、重复行各一条
  local k v c
  while IFS= read -r k; do
    [ -n "$k" ] || continue
    case "$schema_keys" in *"|$k|"*) continue ;; esac
    v="${CFG_SCAN_VALUE[$k]-}"
    c="${CFG_SCAN_COMMENT[$k]-}"
    team_config_json_escape_set "$k"; local u_key="$CFG_ESC"
    team_config_json_escape_set "$v"; local u_val="$CFG_ESC"
    team_config_json_escape_set "$c"; local u_com="$CFG_ESC"
    team_config_choices_set ""
    out="$out,{\"name\":\"$u_key\",\"class\":\"refuse\",\"kind\":\"text\",\"form\":\"plain\",\"value\":\"$u_val\",\"default\":\"\",\"set\":true,\"comment\":\"$u_com\",\"warning\":\"不是已知的项目设置（见 references/config.md）；手改 .pi/team/config.sh\",\"choices\":$CFG_CHOICES_JSON,\"group\":\"\",\"known\":false}"
  done <<< "$CFG_SCAN_ORDER"


  local audit="" firsta=1 l
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    [ "$firsta" = "1" ] || audit="$audit,"
    firsta=0
    team_config_json_escape_set "$l"; audit="$audit\"$CFG_ESC\""
  done < <(team_config_audit_tail 10)

  team_config_json_escape_set "$path"; local e_path="$CFG_ESC"
  team_config_json_escape_set "$policy_pm"; local e_pm="$CFG_ESC"
  team_config_json_escape_set "$(team_model_policy_issues)"; local e_diag="$CFG_ESC"
  printf '{"path":"%s","fingerprint":"%s","mtime":"%s","keys":[%s],"models":{"policy":{"categories":[%s],"pm":"%s"},"assignments":[%s],"pm_launch":%s,"known":[%s],"diagnostic":"%s"},"audit":[%s]}\n' \
    "$e_path" "$fingerprint" "$mtime" "$out" "$categories" "$e_pm" "$assignments" "$pm_launch" "$known_list" "$e_diag" "$audit"
}

team_cmd_config_list() {
  local json=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --json) json=1; shift ;;
      -*) team_usage_die "config list: 未知参数 $1" ;;
      *) team_usage_die "config list: 多余参数 $1" ;;
    esac
  done
  local path; path="$(team_config_contract_path)" || return 1
  if [ "$json" = "1" ]; then team_config_list_json; return $?; fi

  local fingerprint mtime row key class kind def value set
  fingerprint="$(team_config_fingerprint "$path")"
  mtime="$(team_config_mtime "$path")"
  printf '契约   %s\n' "$path"
  printf '指纹   %s\n' "$fingerprint"
  printf 'mtime  %s\n\n' "$mtime"
  printf '%-42s %-8s %-10s %s\n' KEY CLASS KIND VALUE
  while IFS= read -r row; do
    case "$row" in \#*|'') continue ;; esac
    key="$(team_config_field "$row" 1)"; class="$(team_config_field "$row" 2)"
    kind="$(team_config_field "$row" 3)"; def="$(team_config_field "$row" 6)"
    if value="$(team_config_file_value "$path" "$key")"; then set=1; else value="$def"; set=0; fi
    printf '%-42s %-8s %-10s %s%s\n' "$key" "$class" "$kind" "$value" "$([ "$set" = "0" ] && printf '  (unset · default)')"
  done < <(team_config_schema)
  local issues; issues="$(team_model_policy_issues)"
  [ -z "$issues" ] || printf '\n%s\n' "$issues"
  printf '\n审计   %s\n' "$(team_config_audit_file)"
  team_config_audit_tail 5 | sed 's/^/       /'
}

team_cmd_config_log() {
  local n=10
  case "${1:-}" in
    ''|--) ;;
    *[!0-9]*) team_usage_die "config log: N 必须是数字（默认 10）" ;;
    *) n="$1"; shift ;;
  esac
  [ $# -eq 0 ] || team_usage_die "config log: 多余参数 $1"
  team_config_audit_tail "$n"
}

# ---------------------------------------------------------------- set
TEAM_CONFIG_EXIT_CONFLICT=3
TEAM_CONFIG_EXIT_INVALID=4
TEAM_CONFIG_EXIT_REFUSE=5
TEAM_CONFIG_EXIT_WRITE=6
TEAM_CONFIG_EXIT_DANGER=7

# 共用的写路径：<KEY> <value> <actor> <dry> <fp> <allow_danger>
# 返回值就是机器契约的退出码。
team_config_locked_call() { local TEAM_CONFIG_LOCKED=1; "$@"; }
team_config_write_checked() {
  if [ "${4:-0}" = 1 ] || [ "${TEAM_CONFIG_LOCKED:-0}" = 1 ]; then team_config_write_checked_unlocked "$@"
  else
    local path; path="$(team_config_contract_path)" || return 1
    team_with_lock "config:$path" team_config_locked_call team_config_write_checked_unlocked "$@"
  fi
}
team_config_write_checked_unlocked() { # <KEY> <value> <actor> <dry> <fp> <allow_danger>
  local key="$1" val="$2" actor="$3" dry="$4" fp="$5" allow_danger="$6"
  local path; path="$(team_config_contract_path)" || return 1
  local row; row="$(team_config_row "$key" 2>/dev/null || true)"
  local old; old="$(team_config_file_value "$path" "$key" 2>/dev/null || true)"

  # P261（返修 O1）· 退休配置上的 config 写路径：任何字节之前拒绝并指向升级。写下去会留下半迁移状态
  # （退休键还在、新键也写了，而新引擎只读新键）；建议命令与自动迁移共用同一张推导表（design §3），
  # 所以这里没有第二份文案。拒绝不发审计行：这不是对某个值的拒绝，是这个项目还没迁移（前扪 init/bootstrap
  # 的「任何写入之前停住」同一口径）。
  local legacy_keys; legacy_keys="$(team_config_retired_keys_in_file "$path")"
  if [ -n "$legacy_keys" ]; then
    team_err "$key：$path 还在用退休的模型键（$(printf '%s' "$legacy_keys" | tr '\n' ' ')）—— 写盘之前停住"
    team_dim "  项目模型策略是破坏式升级：config set 不是迁移路径" >&2
    team_legacy_model_route_lines "$path" >&2
    return "$TEAM_CONFIG_EXIT_REFUSE"
  fi

  if [ -z "$row" ]; then
    team_err "$key 不是已知的项目设置键"
    case "$key" in TEAM_DEFAULT_MODEL|TEAM_AGENT_MODELS)
      team_dim "  retired: $TEAM_CLI config set-task-model <category> <model>；config set TEAM_PM_MODEL <model>；config upgrade-models" >&2 ;;
      *) team_dim "  已知键：$TEAM_CLI config list；自定义键请手改 $path" >&2 ;; esac
    [ "$dry" = "1" ] || team_config_audit_write refused "$actor" "$key" "$old" "$val" || true
    return "$TEAM_CONFIG_EXIT_REFUSE"
  fi
  local class kind; class="$(team_config_field "$row" 2)"; kind="$(team_config_field "$row" 3)"
  if [ "$class" = "refuse" ]; then
    team_err "$key 是只读键，控制台不改它"
    team_dim "  $(team_config_field "$row" 8)" >&2
    [ "$dry" = "1" ] || team_config_audit_write refused "$actor" "$key" "$old" "$val" || true
    return "$TEAM_CONFIG_EXIT_REFUSE"
  fi

  local canonical; canonical="$(team_config_canonical_value "$key" "$val")"
  local reason
  if ! reason="$(team_config_validate_value "$key" "$canonical")"; then
    team_err "$key=$val 不合法：$reason"
    [ "$dry" = "1" ] || team_config_audit_write invalid "$actor" "$key" "$old" "$val" || true
    return "$TEAM_CONFIG_EXIT_INVALID"
  fi

  local danger=""
  if ! danger="$(team_config_danger_reason "$key" "$canonical")"; then
    if [ "$allow_danger" != "1" ]; then
      team_err "$key=$val 是危险值：$danger（确认要写就加 --allow-danger）"
      [ "$dry" = "1" ] || team_config_audit_write danger-refused "$actor" "$key" "$old" "$val" || true
      return "$TEAM_CONFIG_EXIT_DANGER"
    fi
  fi

  if [ -n "$fp" ]; then
    local actual; actual="$(team_config_fingerprint "$path")"
    if [ "$actual" != "$fp" ]; then
      team_err "$key：文件在读取之后变过（指纹不符）—— 什么都没写"
      team_dim "  expected=$fp actual=$actual；重读 $TEAM_CLI config list 后再试" >&2
      [ "$dry" = "1" ] || team_config_audit_write conflict "$actor" "$key" "$old" "$val" "$fp" "$actual" || true
      return "$TEAM_CONFIG_EXIT_CONFLICT"
    fi
  fi

  if [ "$dry" = "1" ]; then
    printf 'ok: %s=%s（dry-run，未写契约、未写审计）\n' "$key" "$canonical"
    return 0
  fi

  if ! team_config_set_in_file "$path" "$key" "$canonical" 2>/tmp/.team-config-writer.$$; then
    local werr; werr="$(cat /tmp/.team-config-writer.$$ 2>/dev/null || true)"; rm -f /tmp/.team-config-writer.$$
    team_err "$key 写入失败（原文件未动）：$werr"
    team_config_audit_write write-error "$actor" "$key" "$old" "$canonical" || true
    return "$TEAM_CONFIG_EXIT_WRITE"
  fi
  rm -f /tmp/.team-config-writer.$$
  team_config_audit_write ok "$actor" "$key" "$old" "$canonical" || true
  return 0
}

# 名册的授权写入器（P99/R1）：它是 TEAM_AGENTS 唯一的读-改-写入口，team config set 到不了这里
# （类检查在前）。退出码与 team config set 同族：0（写成；含「已在名册」的可见 no-op，不写不审计）/
# 3 指纹冲突 / 4 值不合法 / 5 remove 的席位不在名册 / 6 写失败。
# 席位名合法性只对**结果值**判：移掉一个手改进来的非法 token 是合法的（结果干净），
# 加进去才非法 —— 一条规则，读写同一份（team_config_list_violation）。
team_config_write_roster() {
  if [ "${4:-0}" = 1 ] || [ "${TEAM_CONFIG_LOCKED:-0}" = 1 ]; then team_config_write_roster_unlocked "$@"
  else
    local path; path="$(team_config_contract_path)" || return 1
    local rc=0
    team_with_lock "config:$path" team_config_locked_call team_config_write_roster_unlocked "$@" || rc=$?
    [ "$rc" != 0 ] || TEAM_AGENTS="$(team_config_file_value "$path" TEAM_AGENTS)"
    return "$rc"
  fi
}
team_config_write_roster_unlocked() { # <add|remove> <seat> [fingerprint] [dry]
  local op="$1" seat="$2" fp="${3:-}" dry="${4:-0}"
  local path; path="$(team_config_contract_path)" || return 1
  local old; old="$(team_config_file_value "$path" TEAM_AGENTS 2>/dev/null || true)"
  local old_fp; old_fp="$(team_config_fingerprint "$path")"

  local present=0 t
  # present 按 token 精确匹配：`case " $old " in *" $seat "*)` 会在 seat 含空白时**跨 token** 命中
  # —— 名册里的 api + 1 两个 token 会让 `api 1` 冒充「已在名册」（P105/F1 的另一半）。
  for t in $old; do [ "$t" = "$seat" ] && { present=1; break; }; done
  local new="" tok
  case "$op" in
    add)
      # 席位名自己先是一个合法 token（P105/F1）：任何写入之前拒，名册字节不动、不写 ok 审计。
      local seat_why
      if ! seat_why="$(team_config_seat_violation "$seat")"; then
        team_err "TEAM_AGENTS：$seat_why"
        return "$TEAM_CONFIG_EXIT_INVALID"
      fi
      if [ "$present" = "1" ]; then
        # 「已在名册」不豁免值规则（P99 spec 的第三条）：手改出来的重复/非法 token 不能因为
        # 一次 no-op 就继续冒充健康状态 —— `dev api api` 上再加 api 也是 exit 4 并点名重复 token。
        # 合法值才是真 no-op（重复跑 --register 补齐半成品仍按 D2 的幂等承诺返回 0）。
        local pwhy
        if ! pwhy="$(team_config_list_violation "$old")"; then
          team_err "TEAM_AGENTS=$old 不合法：$pwhy"
          [ "$dry" = "1" ] || team_config_audit_write invalid cli TEAM_AGENTS "$old" "$old" || true
          return "$TEAM_CONFIG_EXIT_INVALID"
        fi
        team_dim "席位 $seat 已在名册里（--register 不重复写）"
        return 0
      fi
      new="${old:+$old }$seat" ;;
    remove)
      if [ "$present" != "1" ]; then
        team_err "席位 $seat 不在名册里：名册是（$(team_config_roster_text)）"
        [ "$dry" = "1" ] || team_config_audit_write refused cli TEAM_AGENTS "$old" "$seat" || true
        return "$TEAM_CONFIG_EXIT_REFUSE"
      fi
      for tok in $old; do [ "$tok" = "$seat" ] || new="${new:+$new }$tok"; done ;;
    *)
      team_err "内部错误：未知的名册操作 $op"
      return 1 ;;
  esac

  local why
  if ! why="$(team_config_list_violation "$new")"; then
    team_err "TEAM_AGENTS=$new 不合法：$why"
    [ "$dry" = "1" ] || team_config_audit_write invalid cli TEAM_AGENTS "$old" "$new" || true
    return "$TEAM_CONFIG_EXIT_INVALID"
  fi

  # CAS：调用方的 --fingerprint 与它读到的字节比；写前再核一次读到的指纹（读-改-写的窗口）。
  if [ -n "$fp" ] && [ "$fp" != "$old_fp" ]; then
    team_err "TEAM_AGENTS：指纹不符（expected=$fp actual=$old_fp）—— 什么都没写"
    [ "$dry" = "1" ] || team_config_audit_write conflict cli TEAM_AGENTS "$old" "$new" "$fp" "$old_fp" || true
    return "$TEAM_CONFIG_EXIT_CONFLICT"
  fi
  local now_fp; now_fp="$(team_config_fingerprint "$path")"
  if [ "$now_fp" != "$old_fp" ]; then
    team_err "TEAM_AGENTS：文件在读取之后变过（指纹不符）—— 什么都没写"
    team_dim "  expected=$old_fp actual=$now_fp；重读 $TEAM_CLI config list 后再试" >&2
    [ "$dry" = "1" ] || team_config_audit_write conflict cli TEAM_AGENTS "$old" "$new" "$old_fp" "$now_fp" || true
    return "$TEAM_CONFIG_EXIT_CONFLICT"
  fi

  if [ "$dry" = "1" ]; then
    printf 'ok: TEAM_AGENTS=%s（dry-run，未写契约、未写审计）\n' "$new"
    return 0
  fi

  if ! team_config_set_in_file "$path" TEAM_AGENTS "$new" 2>/tmp/.team-config-roster.$$; then
    local werr; werr="$(cat /tmp/.team-config-roster.$$ 2>/dev/null || true)"; rm -f /tmp/.team-config-roster.$$
    team_err "TEAM_AGENTS 写入失败（原文件未动）：$werr"
    team_config_audit_write write-error cli TEAM_AGENTS "$old" "$new" || true
    return "$TEAM_CONFIG_EXIT_WRITE"
  fi
  rm -f /tmp/.team-config-roster.$$
  # 同进程后续步骤（worktree add / state / roster 文本）读的就是这个变量：写盘成功后同步刷新。
  TEAM_AGENTS="$new"
  team_config_audit_write ok cli TEAM_AGENTS "$old" "$new" || true
  return 0
}

team_cmd_config_set() {
  local key="" val="" have_val=0 dry=0 fp="" actor="${TEAM_ACTOR:-cli}" allow_danger=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) dry=1; shift ;;
      --allow-danger) allow_danger=1; shift ;;
      --fingerprint) fp="${2:?--fingerprint 需要 sha256}"; shift 2 ;;
      --fingerprint=*) fp="${1#*=}"; shift ;;
      --actor) actor="${2:?--actor 需要名字}"; shift 2 ;;
      --actor=*) actor="${1#*=}"; shift ;;
      --yes|-y) shift ;;
      -*) team_usage_die "config set: 未知参数 $1" ;;
      *) if [ -z "$key" ]; then key="$1"; elif [ "$have_val" = "0" ]; then val="$1"; have_val=1; else team_usage_die "config set: 多余参数 $1"; fi; shift ;;
    esac
  done
  [ -n "$key" ] && [ "$have_val" = "1" ] || team_usage_die "config set: 用法 team config set <KEY> <VALUE> [--dry-run] [--fingerprint <sha256>] [--actor <name>] [--allow-danger]"
  local rc=0
  team_config_write_checked "$key" "$val" "$actor" "$dry" "$fp" "$allow_danger" || rc=$?
  return $rc
}

# ---------------------------------------------------------------- set-agent-model
# 值变换（parser/serializer 只在这里）：upsert/remove 一个 seat=model token。
team_config_pairlist_upsert() { # <value> <seat> <model|-> → 新值
  local val="${1-}" seat="$2" model="$3" out="" tok found=0
  for tok in $val; do
    case "$tok" in
      "$seat"=*) found=1; [ -n "$model" ] && out="${out:+$out }$seat=$model" ;;
      *) out="${out:+$out }$tok" ;;
    esac
  done
  if [ "$found" = "0" ] && [ -n "$model" ]; then out="${out:+$out }$seat=$model"; fi
  printf '%s\n' "$out"
}

team_cmd_config_set_agent_model() {
  local seat="" model="" dry=0 fp="" actor="${TEAM_ACTOR:-cli}" allow_danger=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) dry=1; shift ;;
      --allow-danger) allow_danger=1; shift ;;
      --fingerprint) fp="${2:?--fingerprint 需要 sha256}"; shift 2 ;;
      --fingerprint=*) fp="${1#*=}"; shift ;;
      --actor) actor="${2:?--actor 需要名字}"; shift 2 ;;
      --actor=*) actor="${1#*=}"; shift ;;
      --yes|-y) shift ;;
      -) if [ -z "$seat" ]; then seat="$1"; elif [ -z "$model" ]; then model="$1"; else team_usage_die "config set-agent-model: 多余参数 $1"; fi; shift ;;
      -*) team_usage_die "config set-agent-model: 未知参数 $1" ;;
      *) if [ -z "$seat" ]; then seat="$1"; elif [ -z "$model" ]; then model="$1"; else team_usage_die "config set-agent-model: 多余参数 $1"; fi; shift ;;
    esac
  done
  [ -n "$seat" ] && [ -n "$model" ] || team_usage_die "config set-agent-model: 用法 team config set-agent-model <seat> <model|->"

  local path; path="$(team_config_contract_path)" || return 1
  local audit_key="TEAM_AGENT_MODELS"
  [ "$seat" = "pm" ] && audit_key="TEAM_PM_MODEL"
  if ! team_config_seat_known "$seat"; then
    team_err "未知席位 $seat：名册是（$(team_config_roster_text)）加 pm"
    team_dim "  名册的键是 TEAM_AGENTS（只读）：$TEAM_CLI add-agent $seat --register（或 team teardown --agent $seat --register）" >&2
    [ "$dry" = "1" ] || team_config_audit_write refused "$actor" "$audit_key" "$seat" "$model" || true
    return "$TEAM_CONFIG_EXIT_REFUSE"
  fi
  if [ "$model" != "-" ] && ! team_config_model_shape_ok "$model"; then
    team_err "模型必须是 provider/model 形状（$(team_config_model_violation "$model")）：$model"
    [ "$dry" = "1" ] || team_config_audit_write invalid "$actor" "$audit_key" "$seat" "$model" || true
    return "$TEAM_CONFIG_EXIT_INVALID"
  fi
  local remove=0; [ "$model" = "-" ] && remove=1

  if [ "$seat" = "pm" ]; then
    # pm 席位就是 TEAM_PM_MODEL 一行；'-' 清空 = 回到 TEAM_DEFAULT_MODEL
    local newval="$model"
    [ "$remove" = "1" ] && newval=""
    local rc=0
    team_config_write_checked TEAM_PM_MODEL "$newval" "$actor" "$dry" "$fp" "$allow_danger" || rc=$?
    # 同进程刷新（与名册写入器的 TEAM_AGENTS="$new" 同一纪律，P105/F2）：写盘后的后续步骤
    # 必须读到这个新值，不能留一个「写盘前的旧值」冒充配置解析。
    if [ "$rc" -eq 0 ] && [ "$dry" != "1" ]; then TEAM_PM_MODEL="$newval"; fi
    return $rc
  fi

  # 名册席位：解析并重排 TEAM_AGENT_MODELS（调用方永不自己拼 pair list）
  local old; old="$(team_config_file_value "$path" TEAM_AGENT_MODELS 2>/dev/null || true)"
  local newval; newval="$(team_config_pairlist_upsert "$old" "$seat" "$([ "$remove" = "1" ] && printf '' || printf '%s' "$model")")"
  local rc=0
  team_config_write_checked TEAM_AGENT_MODELS "$newval" "$actor" "$dry" "$fp" "$allow_danger" || rc=$?
  # 同进程刷新（P105/F2）：add-agent --model 写完后走同一个进程的 worktree/state 记录步骤，
  # 不刷新的话 state 记的是写盘前的旧模型，而配置已经有 override —— 席位行自相矛盾。
  if [ "$rc" -eq 0 ] && [ "$dry" != "1" ]; then TEAM_AGENT_MODELS="$newval"; fi
  return $rc
}

# Category edit is a read/modify/write under the SAME file lock as whole-map writes.
team_cmd_config_set_task_model() {
  local cat='' model='' dry=0 fp='' allow_danger=0 actor="${TEAM_ACTOR:-cli}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) dry=1; shift ;; --yes|-y) shift ;;
      --fingerprint) fp="${2:?}"; shift 2 ;; --fingerprint=*) fp="${1#*=}"; shift ;;
      --actor) actor="${2:?}"; shift 2 ;; --actor=*) actor="${1#*=}"; shift ;;
      --allow-danger|--allow-dangerous) allow_danger=1; shift ;;
      -) if [ -z "$cat" ]; then cat='-'; elif [ -z "$model" ]; then model='-'; else team_usage_die 'set-task-model: 多余参数'; fi; shift ;;
      -*) team_usage_die "set-task-model: 未知参数 $1" ;;
      *) if [ -z "$cat" ]; then cat="$1"; elif [ -z "$model" ]; then model="$1"; else team_usage_die 'set-task-model: 多余参数'; fi; shift ;;
    esac
  done
  local path reason; path="$(team_config_contract_path)" || return 1
  if ! team_category_valid "$cat" || [[ "$model" == *=* ]]; then reason='set-task-model requires category provider/model (no removal/fallback)'
  elif ! reason="$(team_config_model_violation "$model")"; then :
  else reason=''; fi
  if [ -n "$reason" ]; then
    team_err "$reason"
    [ "$dry" = 1 ] || team_config_audit_write invalid "$actor" TEAM_TASK_MODELS "$(team_config_file_value "$path" TEAM_TASK_MODELS)" "$cat=$model" "$(team_config_fingerprint "$path")" || true
    return 4
  fi
  if [ "$dry" = 1 ]; then team_config_task_upsert "$path" "$cat" "$model" "$actor" "$dry" "$fp" "$allow_danger"
  else team_with_lock "config:$path" team_config_locked_call team_config_task_upsert "$path" "$cat" "$model" "$actor" "$dry" "$fp" "$allow_danger"; fi
}
team_config_task_upsert() {
  local path="$1" cat="$2" model="$3" actor="$4" dry="$5" fp="$6" allow_danger="${7:-0}" old new
  old="$(team_config_file_value "$path" TEAM_TASK_MODELS)"
  [ -z "$old" ] || team_task_map_violation "$old" >/dev/null || { team_err '现有映射非法；请 config set TEAM_TASK_MODELS <完整映射> 修复'; return 4; }
  new="$(team_config_pairlist_upsert "$old" "$cat" "$model")"
  team_config_write_checked TEAM_TASK_MODELS "$new" "$actor" "$dry" "$fp" "$allow_danger"
}

# Only the four relevant keys are located; unsafe Bash shapes are NOT rewritten.
team_config_model_source_shape() {
  local path="$1" line n=0 key rhs comment quote ch i depth=0 seen=' '
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    case "$line" in *TEAM_DEFAULT_MODEL*|*TEAM_AGENT_MODELS*|*TEAM_TASK_MODELS*|*TEAM_PM_MODEL*) ;;
      *)
        [[ "$line" =~ ^[[:space:]]*(if|case|for|while|until|function)[[:space:]] ]] && depth=$((depth+1))
        [[ "$line" =~ ^[[:space:]]*(fi|esac|done)([[:space:];]|$) ]] && depth=$((depth>0 ? depth-1 : 0))
        continue ;;
    esac
    if ! [[ "$line" =~ ^(TEAM_DEFAULT_MODEL|TEAM_AGENT_MODELS|TEAM_TASK_MODELS|TEAM_PM_MODEL)= ]] || [ "$depth" -gt 0 ]; then
      team_err "$path:$n: unsupported relevant source shape；请手工规范为顶层唯一 KEY='literal' 后重试"; return 5
    fi
    key="${BASH_REMATCH[1]}"
    case "$seen" in *" $key "*) team_err "$path:$n: duplicate $key；请手工规范"; return 5 ;; esac
    seen="$seen$key "
    comment="$(printf '%s' "$line" | team_config_inline_comment_of_line)"
    rhs="${line#*=}"; [ -z "$comment" ] || rhs="${rhs%"$comment"}"
    rhs="$(team_trim "$rhs")"
    quote=''; i=0
    if [[ "$rhs" == \"* ]]; then
      [[ "$rhs" == *\" ]] && [ "${#rhs}" -ge 2 ] || { team_err "$path:$n: multiline/unclosed literal"; return 5; }
      rhs="${rhs:1:${#rhs}-2}"
      case "$rhs" in *'$'*|*'`'*|*'\\'*|*'"'*) team_err "$path:$n: expanding double quote；请规范单行 literal"; return 5 ;; esac
    elif [[ "$rhs" == "'"* ]]; then
      while [ "$i" -lt "${#rhs}" ]; do
        ch="${rhs:i:1}"
        if [ "$quote" = single ]; then [ "$ch" != "'" ] || quote=''
        else
          if [ "$ch" = "'" ]; then quote=single
          elif [ "${rhs:i:2}" = "\\'" ]; then i=$((i+1))
          else team_err "$path:$n: unsupported literal concatenation"; return 5; fi
        fi
        i=$((i+1))
      done
      [ -z "$quote" ] || { team_err "$path:$n: multiline/unclosed literal"; return 5; }
    elif ! [[ "$rhs" =~ ^[a-zA-Z0-9_./:=+-]+$ ]]; then
      team_err "$path:$n: dynamic/indirect value；请规范顶层单行 literal"; return 5
    fi
  done < "$path"
}
# ---------------------------------------------------------------- 迁移决策（唯一推导表；P261 · startup-self-heal）
# 纯决策层：读文件、算计划、给拒绝理由 —— 一个字节都不写。编排（打印/备份/写入/exec）在 cmd-watch.sh 的
# team_cmd_up，拒绝建议在 common.sh 的 team_model_policy_issues —— 三处**共用**本节的推导表，不许长第二份。
# 形状判定顺序（design §2）：标记（TEAM_CONFIG_VERSION）→ 键（有退休键 = 1）→ 表；标记高于已知最新 → 拒绝。
TEAM_CONFIG_SHAPE_RETIRED=1
TEAM_CONFIG_SHAPE_CURRENT=2
team_config_migration_table() { # 一行一条迁移：id|from|to|introduced；加一条迁移 = 加一行 + 一个 transform + 一组夹具
  cat <<'EOF'
m1|1|2|0.2.0
EOF
}
team_config_migration_introduced() { # <from> → 引入该行的工具版本（备份名与 --print 预告用）
  local id from to introduced
  while IFS='|' read -r id from to introduced; do
    case "$id" in ''|'#'*) continue ;; esac
    [ "$1" = "$from" ] && { printf '%s\n' "$introduced"; return 0; }
  done < <(team_config_migration_table)
  printf '%s\n' '0.0.0'
}
# 文件里有没有某个键的赋值行（注释行不算）；与 team_model_policy_issues 的旧判据同一形状。
team_config_file_key_present() { # <path> <KEY> → 0 = 在文件里有赋值行
  grep -vE '^[[:space:]]*#' "$1" 2>/dev/null | grep -Eq "(^|[^A-Za-z0-9_])$2([[:space:]]*=|[[:space:]])"
}
team_config_retired_keys_in_file() { # <path> → 每行一个文件里的退休键（TEAM_AGENT_MODELS / TEAM_DEFAULT_MODEL）
  local key
  for key in TEAM_AGENT_MODELS TEAM_DEFAULT_MODEL; do
    team_config_file_key_present "$1" "$key" && printf '%s\n' "$key"
  done
  return 0
}
team_config_shape_read() { # <path> → 0/5；形状号在 TEAM_CONFIG_SHAPE，原因在 TEAM_CONFIG_SHAPE_WHY
  local path="$1" marker
  TEAM_CONFIG_SHAPE=''; TEAM_CONFIG_SHAPE_WHY=''
  marker="$(team_config_file_value "$path" TEAM_CONFIG_VERSION 2>/dev/null || true)"
  if [ -n "$marker" ]; then
    case "$marker" in
      *[!0-9]*) TEAM_CONFIG_SHAPE_WHY="TEAM_CONFIG_VERSION 不是整数：$marker"; return 5 ;;
    esac
    if [ "$marker" -gt "$TEAM_CONFIG_SHAPE_CURRENT" ]; then
      TEAM_CONFIG_SHAPE_WHY="这个项目的配置形状号是 $marker，本工具只知道到 $TEAM_CONFIG_SHAPE_CURRENT（不拿旧行去套新形状）"
      return 5
    fi
    TEAM_CONFIG_SHAPE="$marker"; return 0
  fi
  if [ -n "$(team_config_retired_keys_in_file "$path")" ]; then
    TEAM_CONFIG_SHAPE="$TEAM_CONFIG_SHAPE_RETIRED"; return 0
  fi
  TEAM_CONFIG_SHAPE="$TEAM_CONFIG_SHAPE_CURRENT"
}
# 类别名规范化（design §3 的唯一规则）：小写、其它字符折成 `-`、折叠并修剪 `-`；结果必须匹配
# `^[a-z][a-z0-9-]*$`，否则**拒绝**（不偷偷加前缀 —— 静默改值就是另一条口径）。
team_config_category_normalize() { # <旧席位名> → stdout 规范化结果（调用方再用 team_category_valid 判）
  printf '%s' "${1-}" | tr 'A-Z' 'a-z' | sed -E 's/[^a-z0-9-]+/-/g; s/-+/-/g; s/^-+//; s/-+$//'
}
# 迁移决策：action=none（已是当前形状）/ action=apply（有可套用的迁移行）/ 非 0 = 拒绝。
# 拒绝时 TEAM_MIGRATION_WHY 是点名障碍的人话，TEAM_MIGRATION_SHAPE 是分类名（design §4 八类）。
team_config_migration_decide() { # <path>
  local path="$1" shape=''
  TEAM_MIGRATION_ACTION=''; TEAM_MIGRATION_WHY=''; TEAM_MIGRATION_SHAPE=''
  if [ -n "${TEAM_MODEL_RETIRED_ENV:-}" ]; then
    TEAM_MIGRATION_SHAPE='retired-key-in-env'
    TEAM_MIGRATION_WHY="退休键在**环境**里（$(printf '%s' "$TEAM_MODEL_RETIRED_ENV" | paste -sd'、' -)），文件里改不掉；修法：unset $TEAM_MODEL_RETIRED_ENV"
    return 1
  fi
  if ! team_config_shape_read "$path"; then
    TEAM_MIGRATION_SHAPE='unknown-shape'; TEAM_MIGRATION_WHY="${TEAM_CONFIG_SHAPE_WHY:-配置形状读不出来}"; return 1
  fi
  shape="$TEAM_CONFIG_SHAPE"
  if [ "$shape" = "$TEAM_CONFIG_SHAPE_CURRENT" ]; then
    if [ -n "$(team_config_retired_keys_in_file "$path")" ]; then
      TEAM_MIGRATION_SHAPE='contradictory-shape'
      TEAM_MIGRATION_WHY="文件里带着形状号 $TEAM_CONFIG_SHAPE_CURRENT 却还有退休键 $(team_config_retired_keys_in_file "$path" | paste -sd'、' -)：先手工决定留哪一套"
      return 1
    fi
    TEAM_MIGRATION_ACTION='none'; return 0
  fi
  # shape < 当前：按表找 from 匹配的行；缺行 / 更高都拒绝（绝不猜）。
  local id from to introduced matched=''
  while IFS='|' read -r id from to introduced; do
    case "$id" in ''|'#'*) continue ;; esac
    if [ "$shape" = "$from" ]; then matched="$id|$from|$to|$introduced"; break; fi
    if [ "$shape" -lt "$from" ]; then
      TEAM_MIGRATION_SHAPE='missing-migration-row'
      TEAM_MIGRATION_WHY="形状 $shape 在迁移表里没有对应的行（表的下一行从 $from 起）：本工具不知道该怎么补中间这一步"
      return 1
    fi
  done < <(team_config_migration_table)
  if [ -z "$matched" ]; then
    TEAM_MIGRATION_SHAPE='missing-migration-row'
    TEAM_MIGRATION_WHY="形状 $shape 在迁移表里没有对应的行"
    return 1
  fi
  TEAM_MIGRATION_ACTION='apply'
  TEAM_MIGRATION_ROW="${matched%%|*}"; local rest="${matched#*|}"
  TEAM_MIGRATION_FROM="${rest%%|*}"; rest="${rest#*|}"
  TEAM_MIGRATION_TO="${rest%%|*}"; TEAM_MIGRATION_INTRODUCED="${rest#*|}"
  return 0
}
# 拒绝建议里的「其余对仍然给出」（design §4）：已通过校验的对原样保留，非法的那一对用占位符补位。
team_migration_partial_map() { # <已推导出的对…>
  local pairs="${1:-}"
  if [ -n "$pairs" ]; then printf '%s <非法那一对用占位符>' "$pairs"; else printf '<完整映射>'; fi
}
# 推导表（design §3）：旧键 → 新键。值一个都不改；每条规范化改过名字的、兜底取默认值的都进 notes。
# 成功 → 0：TEAM_MIGRATION_MAP / PM / NOTES / ROWS（old_key|old_value|new_key|new_value|note）就绪。
# 失败 → 1：TEAM_MIGRATION_WHY 点名障碍，TEAM_MIGRATION_SHAPE 是分类名；TEAM_MIGRATION_ROWS 为空。
team_config_migration_plan() { # <path>
  local path="$1" nl=$'\n'
  TEAM_MIGRATION_MAP=''; TEAM_MIGRATION_PM=''; TEAM_MIGRATION_NOTES=''; TEAM_MIGRATION_ROWS=''
  TEAM_MIGRATION_WHY=''; TEAM_MIGRATION_SHAPE=''; TEAM_MIGRATION_PARTIAL_MAP=''
  team_config_migration_decide "$path" || return 1
  [ "$TEAM_MIGRATION_ACTION" = 'apply' ] || return 0
  local shape_err
  if ! shape_err="$(C_RED='' C_RESET='' team_config_model_source_shape "$path" 2>&1)"; then
    shape_err="$(printf '%s' "$shape_err" | head -1)"; shape_err="${shape_err#✗ }"
    TEAM_MIGRATION_SHAPE='shape-not-locatable'
    TEAM_MIGRATION_WHY="旧键的形状 upgrade-models 定位不了（${shape_err:-不是顶层单行字面量}）；先手工规范那一行，本工具一个字节都不写"
    return 1
  fi
  local seats='' default='' pm='' pm_from_default=0
  seats="$(team_config_file_value "$path" TEAM_AGENT_MODELS 2>/dev/null || true)"
  default="$(team_config_file_value "$path" TEAM_DEFAULT_MODEL 2>/dev/null || true)"
  pm="$(team_config_file_value "$path" TEAM_PM_MODEL 2>/dev/null || true)"
  # 新旧值同时存在且矛盾：文件里既有退休键，又有**非空的新映射键** TEAM_TASK_MODELS —— 迁移会覆盖它，
  # 所以先手工决定留哪一套。（TEAM_PM_MODEL 不矛盾：design §3 的规则就是原样带过去，存在即沿用。）
  local newmap; newmap="$(team_config_file_value "$path" TEAM_TASK_MODELS 2>/dev/null || true)"
  if [ -n "$newmap" ]; then
    TEAM_MIGRATION_SHAPE='contradictory-values'
    TEAM_MIGRATION_WHY="文件里既有退休键 $(team_config_retired_keys_in_file "$path" | paste -sd'、' -)，又有非空的新键 TEAM_TASK_MODELS='$newmap'：先手工决定留哪一套"
    return 1
  fi
  local tok seat model category note taken=' ' map='' notes='' rows='' reason
  for tok in $seats; do
    case "$tok" in
      *=*) seat="${tok%%=*}"; model="${tok#*=}" ;;
      *) TEAM_MIGRATION_SHAPE='unparsable-seat-token'
         TEAM_MIGRATION_WHY="旧 TEAM_AGENT_MODELS 里有一个解不开的 token：$tok"; return 1 ;;
    esac
    if [ -z "$seat" ] || [ -z "$model" ]; then
      TEAM_MIGRATION_SHAPE='unparsable-seat-token'
      TEAM_MIGRATION_WHY="旧 TEAM_AGENT_MODELS 的 token 缺席位名或模型：$tok"; return 1
    fi
    if ! reason="$(team_config_model_violation "$model")"; then
      TEAM_MIGRATION_SHAPE='invalid-model-value'
      TEAM_MIGRATION_PARTIAL_MAP="$(team_migration_partial_map "$map")"
      TEAM_MIGRATION_WHY="席位 $seat 的旧模型值不合法（$reason）：$model"
      return 1
    fi
    category="$(team_config_category_normalize "$seat")"
    if ! team_category_valid "$category"; then
      TEAM_MIGRATION_SHAPE='category-not-normalizable'
      TEAM_MIGRATION_WHY="席位名 $seat 规范化成 '$category'，不是合法类别名（^[a-z][a-z0-9-]*$）：先手工选一个类别名"
      return 1
    fi
    note=''
    [ "$category" = "$seat" ] || note="席位 $seat 规范化成类别 $category"
    case "$taken" in
      *" $category "*)
        TEAM_MIGRATION_SHAPE='category-collision'
        TEAM_MIGRATION_WHY="两个席位规范化后都叫类别 $category：先手工选名字（本工具不偷偷加后缀）"
        return 1 ;;
    esac
    taken="$taken$category "
    map="${map:+$map }$category=$model"
    rows="${rows:+$rows$nl}TEAM_AGENT_MODELS|$seat=$model|TEAM_TASK_MODELS|$category=$model|$note"
    [ -z "$note" ] || notes="${notes:+$notes；}$note"
  done
  if [ -n "$default" ]; then
    if ! reason="$(team_config_model_violation "$default")"; then
      TEAM_MIGRATION_SHAPE='invalid-model-value'
      TEAM_MIGRATION_PARTIAL_MAP="$(team_migration_partial_map "$map")"
      TEAM_MIGRATION_WHY="旧 TEAM_DEFAULT_MODEL 不合法（$reason）：$default"; return 1
    fi
    case "$taken" in
      *' default '*)
        TEAM_MIGRATION_SHAPE='fallback-name-collision'
        TEAM_MIGRATION_WHY='席位派生的类别里已经有一个叫 default：兜底名与它撞名，先手工给旧默认值选一个类别名'; return 1 ;;
    esac
    taken="$taken default "
    map="${map:+$map }default=$default"
    rows="${rows:+$rows$nl}TEAM_DEFAULT_MODEL|$default|TEAM_TASK_MODELS|default=$default|"
  fi
  if [ -z "$pm" ]; then
    if [ -n "$default" ]; then
      pm="$default"; pm_from_default=1
      notes="${notes:+$notes；}TEAM_PM_MODEL 缺失或为空 → 取旧 TEAM_DEFAULT_MODEL 的值"
    else
      TEAM_MIGRATION_SHAPE='pm-model-underivable'
      TEAM_MIGRATION_WHY='推不出 PM 模型：TEAM_PM_MODEL 为空，且没有 TEAM_DEFAULT_MODEL 可兜底'; return 1
    fi
  fi
  if ! reason="$(team_config_model_violation "$pm")"; then
    TEAM_MIGRATION_SHAPE='invalid-model-value'
    TEAM_MIGRATION_WHY="PM 模型不合法（$reason）：$pm"; return 1
  fi
  if [ -z "$seats" ] && [ -z "$default" ]; then
    TEAM_MIGRATION_SHAPE='nothing-to-derive'
    TEAM_MIGRATION_WHY='退休键里没有可推导的值（TEAM_AGENT_MODELS 与 TEAM_DEFAULT_MODEL 都是空的）'; return 1
  fi
  if ! reason="$(team_task_map_violation "$map")"; then
    TEAM_MIGRATION_SHAPE='invalid-derived-map'
    TEAM_MIGRATION_WHY="推导出的类别映射过不了既有校验器（$reason）：$map"; return 1
  fi
  if [ "$pm_from_default" = 1 ]; then
    rows="${rows:+$rows$nl}TEAM_PM_MODEL|（缺失）|TEAM_PM_MODEL|$pm|取旧 TEAM_DEFAULT_MODEL 的值"
  else
    rows="${rows:+$rows$nl}TEAM_PM_MODEL|$pm|TEAM_PM_MODEL|$pm|"
  fi
  rows="${rows:+$rows$nl}（迁移）|-|TEAM_CONFIG_VERSION|$TEAM_CONFIG_SHAPE_CURRENT|删除两个退休键，并记下新形状号"
  TEAM_MIGRATION_MAP="$map"; TEAM_MIGRATION_PM="$pm"; TEAM_MIGRATION_NOTES="$notes"; TEAM_MIGRATION_ROWS="$rows"
  return 0
}
# 备份路径：$TEAM_STATE_DIR/config-backups/config.sh.pre-<引入版本>-<UTC 时间戳>（design §5）。
team_config_backup_dir() { printf '%s\n' "${TEAM_STATE_DIR:-.pi/team/state}/config-backups"; }
team_config_backup_name() { # <path> <时间戳> → 备份文件名
  printf 'config.sh.pre-%s-%s\n' "$(team_config_migration_introduced "$TEAM_MIGRATION_FROM")" "$2"
}
# 写一份带时间戳的备份，保留最新 5 份（备份是恢复手段不是档案）。
team_config_backup_write() { # <path> <时间戳> → stdout 备份的绝对路径
  local path="$1" ts="$2" dir name
  dir="$(team_config_backup_dir)"; name="$(team_config_backup_name "$path" "$ts")"
  mkdir -p "$dir" || return 1
  cp -p "$path" "$dir/$name" || return 1
  local keep=5 n f
  n="$(find "$dir" -maxdepth 1 -type f -name 'config.sh.pre-*' | wc -l | tr -d ' ')"
  if [ "$n" -gt "$keep" ]; then
    find "$dir" -maxdepth 1 -type f -name 'config.sh.pre-*' -printf '%f\n' | sort | head -n "$((n - keep))" \
      | while IFS= read -r f; do [ -n "$f" ] && rm -f "$dir/$f"; done
  fi
  printf '%s\n' "$dir/$name"
}
team_cmd_config_upgrade_models() {
  local map='' pm='' dry=1 yes="${TEAM_UPGRADE_CONFIRMED:-0}" fp='' actor="${TEAM_ACTOR:-cli}"
  [ "$yes" != 1 ] || dry=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --task-models) map="${2:?}"; shift 2 ;; --pm-model) pm="${2:?}"; shift 2 ;;
      --dry-run) dry=1; shift ;; --yes|-y) yes=1; dry=0; shift ;;
      --fingerprint) fp="${2:?}"; shift 2 ;; --fingerprint=*) fp="${1#*=}"; shift ;;
      --actor) actor="${2:?}"; shift 2 ;; *) team_usage_die "upgrade-models: 未知参数 $1" ;;
    esac
  done
  [ -n "$map" ] && [ -n "$pm" ] || { team_err 'upgrade-models requires --task-models <完整映射> --pm-model <独立模型>；默认 preview，--yes 才写'; return 4; }
  local path; path="$(team_config_contract_path)" || return 1
  if [ "$dry" = 1 ]; then team_config_upgrade_transaction "$path" "$map" "$pm" "$dry" "$fp" "$actor"
  else team_with_lock "config:$path" team_config_locked_call team_config_upgrade_transaction "$path" "$map" "$pm" "$dry" "$fp" "$actor"; fi
}
# <path> <map> <pm> <dry> <fp> <actor> [KEY=VALUE…（附加键，默认空；手工入口不受影响）]
team_config_upgrade_transaction() {
  local path="$1" map="$2" pm="$3" dry="$4" fp="$5" actor="$6" before after tmp rc=0
  shift 6 || true
  local extra_key=; local extra_keys=("$@")
  before="$(team_config_fingerprint "$path")"
  if ! team_task_map_violation "$map" || ! team_config_model_violation "$pm"; then
    [ "$dry" = 1 ] || team_config_audit_write invalid "$actor" model-upgrade "$before" '' || true
    return 4
  fi
  if [ -n "$fp" ] && [ "$before" != "$fp" ]; then
    [ "$dry" = 1 ] || team_config_audit_write conflict "$actor" model-upgrade "$before" '' "$fp" "$before" || true
    team_err 'upgrade-models: 指纹不符，未写'; return 3
  fi
  if ! team_config_model_source_shape "$path"; then
    [ "$dry" = 1 ] || team_config_audit_write refused "$actor" model-upgrade "$before" '' || true
    return 5
  fi
  # 启动迁移（actor=up-migration）自己打印逐键表，这里不再重复同一条；手工入口照旧打印这一行。
  [ "$actor" = 'up-migration' ] || printf 'upgrade-models: remove TEAM_DEFAULT_MODEL TEAM_AGENT_MODELS; TEAM_TASK_MODELS=%s; TEAM_PM_MODEL=%s; before=%s\n' "$map" "$pm" "$before"
  [ "$dry" != 1 ] || { printf 'dry-run: no config/audit mutation; --yes to commit\n'; return 0; }
  tmp="$(mktemp "$(dirname "$path")/.model-upgrade.XXXXXX")" || {
    team_config_audit_write write-error "$actor" model-upgrade "$before" '' || true; return 6;
  }
  cp -p "$path" "$tmp" || {
    rm -f "$tmp"; team_config_audit_write write-error "$actor" model-upgrade "$before" '' || true; return 6;
  }
  local wrote=0
  team_config_set_in_file "$tmp" TEAM_DEFAULT_MODEL '' remove &&
    team_config_set_in_file "$tmp" TEAM_AGENT_MODELS '' remove &&
    team_config_set_in_file "$tmp" TEAM_TASK_MODELS "$map" &&
    team_config_set_in_file "$tmp" TEAM_PM_MODEL "$pm" || rc=6
  if [ "$rc" = 0 ]; then
    # 附加键（自动迁移写形状号）：**逐个显式校验**后才写，写失败整体失败（不做半套迁移）。
    local pair
    for pair in "${extra_keys[@]}"; do
      [ -n "$pair" ] || continue
      extra_key="${pair%%=*}"
      # 只允许形状号（refuse 类键由**工具**写；控制台的写路径仍然拒绝它）—— 别的键一律写失败。
      case "$extra_key" in
        TEAM_CONFIG_VERSION) case "${pair#*=}" in ''|*[!0-9]*) rc=6; break ;; esac ;;
        *) rc=6; break ;;
      esac
      team_config_set_in_file "$tmp" "$extra_key" "${pair#*=}" || { rc=6; break; }
      wrote=1
    done
  fi
  [ "$rc" != 0 ] || bash -n "$tmp" || rc=6
  if [ "$rc" = 0 ] && [ "$(team_config_fingerprint "$path")" != "$before" ]; then rc=3; fi
  if [ "$rc" = 0 ]; then mv -f "$tmp" "$path" || rc=6; fi
  rm -f "$tmp"
  if [ "$rc" != 0 ]; then
    local result=write-error; [ "$rc" != 3 ] || result=conflict
    team_config_audit_write "$result" "$actor" model-upgrade "$before" '' || true
    return "$rc"
  fi
  after="$(team_config_fingerprint "$path")"
  local audit_keys='TEAM_DEFAULT_MODEL,TEAM_AGENT_MODELS,TEAM_TASK_MODELS,TEAM_PM_MODEL' pair
  for pair in "${extra_keys[@]}"; do [ -n "$pair" ] && audit_keys="$audit_keys,${pair%%=*}"; done
  team_config_audit_write ok "$actor" "$audit_keys" "$before" "$after" "$before" "$after" || true
  printf 'committed: before=%s after=%s\n' "$before" "$after"
}

# ---------------------------------------------------------------- 子命令分发
team_cmd_config() {
  local sub="${1:-}"
  [ $# -gt 0 ] && shift
  case "$sub" in
    list) team_cmd_config_list "$@" ;;
    set) team_cmd_config_set "$@" ;;
    log) team_cmd_config_log "$@" ;;
    set-task-model) team_cmd_config_set_task_model "$@" ;;
    upgrade-models) team_cmd_config_upgrade_models "$@" ;;
    set-agent-model) team_err "retired: use $TEAM_CLI config set-task-model <category> <model> or config set TEAM_PM_MODEL <model>"; return 5 ;;
    ''|help|-h|--help)
      cat <<EOF
用法： $TEAM_CLI config <list|set|log|set-task-model|upgrade-models> …

  $TEAM_CLI config list [--json]                     列出契约里每个键（class/kind/当前值/默认值）与
                                                 models 块（未来策略与已提交启动身份）
  $TEAM_CLI config set <KEY> <VALUE> [--dry-run]     唯一写入口：校验 → 指纹 CAS → 原子写 → 审计
                     [--fingerprint <sha256>] [--actor <name>] [--allow-danger]
  $TEAM_CLI config set-task-model <category> <model>  新增/修改类别模型，不改已派身份
  $TEAM_CLI config upgrade-models --task-models <map> --pm-model <model> [--dry-run] [--yes]
                     [--fingerprint <sha256>] [--actor <name>] 显式四键事务升级
  $TEAM_CLI config log [N]                           审计尾部（默认 10 行）

退出码： 0 写入/校验通过 ｜ 3 指纹冲突 ｜ 4 值不合法 ｜ 5 键只读 ｜ 6 写失败 ｜ 7 危险值需 --allow-danger
EOF
      ;;
    *) team_usage_die "config: 未知子命令 $sub（list|set|log|set-task-model|upgrade-models）" ;;
  esac
}
