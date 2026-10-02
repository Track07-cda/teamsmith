#!/usr/bin/env bash
# teamsmith · 跨项目会议（meeting mode）
#
# 定位：**peer 级交流**（接口对接、建议、问题报告），不是指挥通道。
#   - 机制里没有「下令」这个动作：intent 只有 info|question|report|proposal|request
#   - 共识必须双方各自 agree；各方在自己项目里独立决策、独立记录
#   - agent 进程不能用 --as-user（机制上不可能冒充人类下令）
#   - 只写共享区（TEAM_MEETINGS_DIR），对对方仓库零写权限
#
# 目录结构：
#   <meetings>/<slug>/state.env         参与方/发起方/TTL/状态/轮次
#   <meetings>/<slug>/agenda.md         议题
#   <meetings>/<slug>/transcript/NNN_<project>_<intent>.md   追加式发言（唯一真相）
#   <meetings>/<slug>/agreements/A<n>.md                      共识条目（双方各自 agree）
#   <meetings>/<slug>/read/<project>.seq                      各家已读位置

TEAM_MEETING_INTENTS="info question report proposal request"

team_meetings_dir() {
  printf '%s\n' "${TEAM_MEETINGS_DIR:-$HOME/.pi/team/meetings}"
}

team_meeting_dir() { # <slug>
  printf '%s/%s\n' "$(team_meetings_dir)" "$1"
}

team_meeting_validate_slug() { # <slug>
  case "$1" in
    ""|*[!a-zA-Z0-9._-]*) team_die "会议 slug 非法：'$1'（只允许字母数字 . _ -）" ;;
  esac
  return 0
}

team_meeting_state() { # <slug> <key> [default]
  local f; f="$(team_meeting_dir "$1")/state.env"
  local v=""
  [ -f "$f" ] && v="$(grep -s "^$2=" "$f" | head -1 | cut -d= -f2- || true)"
  if [ -n "$v" ]; then printf '%s\n' "$v"
  elif [ $# -ge 3 ]; then printf '%s\n' "$3"
  else printf '\n'
  fi
  return 0
}

team_meeting_set() { # <slug> <key> <value>（覆盖式，写 state.env）
  local d; d="$(team_meeting_dir "$1")"
  [ -d "$d" ] || team_die "会议不存在：$1"
  local f="$d/state.env" tmp
  tmp="$(mktemp)"
  if [ -f "$f" ]; then grep -v "^$2=" "$f" > "$tmp" || true; fi
  printf '%s=%s\n' "$2" "$3" >> "$tmp"
  mv "$tmp" "$f"
  return 0
}

team_meeting_exists() { [ -f "$(team_meeting_dir "$1")/state.env" ]; }

team_meeting_is_mine() { # <slug>
  # R1（D9）：参与方按**记录名任一并集**判定 —— 实现只有一份（team_meeting_record_is_mine）：
  # 候选记录名 = PARTICIPANTS 名单 ∪ PARTICIPANT_REPOS 的键；命中轴 = 声明名 / 主工作树 basename /
  # 记录仓库名 / 受邀 session。一个都匹配不上 → 拒绝（第三方仍被拒：这是「同一个人换拼写」，不是放行所有人）。
  local slug="$1" names n kv
  names="$(team_meeting_participants "$slug"),"
  for kv in $(printf '%s' "$(team_meeting_participant_repos "$slug")" | tr ';' ' '); do
    [ -n "$kv" ] || continue
    names="$names${kv%%=*},"
  done
  for n in $(printf '%s' "$names" | tr ',' ' '); do
    [ -n "$n" ] || continue
    team_meeting_record_is_mine "$slug" "$n" && return 0
  done
  return 1
}

# 主工作树的 basename（R1：仓库名是身份的一根轴；推导不出 → 空，绝不编）
team_meeting_repo_basename() {
  local root="${TEAM_MAIN_ROOT:-${TEAM_ROOT:-$PWD}}"
  case "$root" in ''|/) return 0 ;; esac
  basename "${root%/}"
}

team_meeting_is_closed() { [ "$(team_meeting_state "$1" STATUS open)" = "closed" ]; }

# 会议的报告状态（D1：expired 是派生值，绝不写回 state.env）。read/list/读位/状态行只用它 ——
# 旧实现把 STATUS 与 "(过期)" 拼成 open(过期)，同一场会议两个表面两种写法。
team_meeting_state_word() { # <slug> → open|expired|closed
  if team_meeting_is_closed "$1"; then printf 'closed\n'; return 0; fi
  if team_meeting_is_expired "$1"; then printf 'expired\n'; return 0; fi
  printf 'open\n'
}

team_meeting_state_text() { # <slug> → 人读形态（状态词 + 过期中文标注，旧断言仍看得见「已过期」）
  case "$(team_meeting_state_word "$1")" in
    expired) printf 'expired（已过期）\n' ;;
    closed)  printf 'closed\n' ;;
    *)       printf 'open\n' ;;
  esac
}

# F19：TTL 必须是正整数小时。旧实现里：open 不校验（`--ttl 0/-5/abc` 直接写进 state.env），
# is_expired 把 0/负数/非数字当成「永不过期」（`[ "$ttl" -gt 0 ] 2>/dev/null || return 1`），
# read 还把 'abc' 印成 "TTL abch"。这里把「有效 TTL」收成一个函数，双方都用它。
team_meeting_ttl_default() { # 文档默认值；环境变量本身非法也退回 72
  case "${TEAM_MEETING_TTL_HOURS:-}" in
    ''|*[!0-9]*) printf '72\n' ;;
    *) if [ "$TEAM_MEETING_TTL_HOURS" -gt 0 ] 2>/dev/null; then printf '%s\n' "$TEAM_MEETING_TTL_HOURS"; else printf '72\n'; fi ;;
  esac
}

team_meeting_ttl_hours() { # <slug> → 有效 TTL（正整数小时）；登记值不可用 → 文档默认值，绝不永生
  local raw; raw="$(team_meeting_state "$1" TTL_HOURS '')"
  case "$raw" in
    ''|*[!0-9]*) printf '%s\n' "$(team_meeting_ttl_default)" ;;
    *) if [ "$raw" -gt 0 ] 2>/dev/null; then printf '%s\n' "$raw"; else printf '%s\n' "$(team_meeting_ttl_default)"; fi ;;
  esac
}

team_meeting_ttl_note() { # <slug> → "" 或「登记值不可用，按默认算」的说明（read 用）
  local raw; raw="$(team_meeting_state "$1" TTL_HOURS '')"
  case "$raw" in
    ''|*[!0-9]*) printf '（登记值 %s 不可用：按文档默认 %sh 计，不会永生）' "${raw:-缺失}" "$(team_meeting_ttl_hours "$1")" ;;
    *) [ "$raw" -gt 0 ] 2>/dev/null || printf '（登记值 %s 非正：按文档默认 %sh 计，不会永生）' "$raw" "$(team_meeting_ttl_hours "$1")" ;;
  esac
}

team_meeting_is_expired() { # TTL 到期 → 只读（F19：非法/缺失 TTL 按文档默认值算，不静默变成永生）
  local ttl opened now
  ttl="$(team_meeting_ttl_hours "$1")"
  opened="$(team_meeting_state "$1" OPENED_EPOCH 0)"
  case "$opened" in ''|*[!0-9]*) opened=0 ;; esac   # 时间戳不可用 → 当 0（比任何 TTL 都早），不给永生后门
  now="$(date +%s)"
  [ $((now - opened)) -gt $((ttl * 3600)) ]
}

team_meeting_require_open() { # <slug> <动作>
  team_meeting_exists "$1" || team_die "会议不存在：$1（先 $TEAM_CLI meeting open $1 --with <项目> --yes）"
  team_meeting_is_mine "$1" || team_die "你不是会议 $1 的参与方（参与方：$(team_meeting_state "$1" PARTICIPANTS -)）"
  if team_meeting_is_closed "$1"; then
    [ "$2" = "read" ] && return 0
    team_die "会议 $1 已关闭（closed by $(team_meeting_state "$1" CLOSED_BY -)）：只读；要继续就 open --force 或新开一个"
  fi
  if team_meeting_is_expired "$1"; then
    # D7：过期 = 双方都写不了的只读会议；close 是唯一的收尾动作（旧实现把 close 一起拒了 → 死锁）。
    case "$2" in
      read|close) return 0 ;;
    esac
    team_die "会议 $1 已过期（TTL $(team_meeting_ttl_hours "$1")h）：先 $TEAM_CLI meeting close $1（或 $TEAM_CLI meeting close --stale），要续期就 open --force"
  fi
  return 0
}

team_meeting_seq() { # <slug> → 下一条发言序号
  local n
  n="$(ls "$(team_meeting_dir "$1")/transcript" 2>/dev/null | grep -c '\.md$' || true)"
  printf '%04d\n' "$((n + 1))"
}

team_meeting_turns() { # <slug> <project> → 该项目已发言条数
  ls "$(team_meeting_dir "$1")/transcript" 2>/dev/null | grep -c "_${2}_" || true
}

# 本项目的未读会议轮次（watchdog 待办 × panel 的单一读数，D2/D3）：
#   对每一场「我在参与且未关闭」的会议，取 max(0, transcript 轮数 - read/<项目>.seq) 再求和。
#   * 过期但未关闭的会议**照算**（transcript 可读）；closed 冻结、不算。
#   * `meeting say` 写自己那条发言时已推进自己的读位（D3），所以自己的发言永远不算未读。
#   * 会议根不存在 → 0（不建目录、不报错）；读位文件缺失/不可解析 → 0。
#   两个待办读者（team_pending_counts / team_panel_pending_counts_fast）都调用它 —— 值的唯一来源。
team_meetings_unread_count() {
  local root slug d last read n total=0
  root="$(team_meetings_dir)"
  [ -d "$root" ] || { printf '0\n'; return 0; }
  for slug in "$root"/*/; do
    [ -d "$slug" ] || continue
    slug="$(basename "$slug")"
    team_meeting_is_mine "$slug" || continue
    team_meeting_is_closed "$slug" && continue
    d="$(team_meeting_dir "$slug")"
    last="$(ls "$d/transcript" 2>/dev/null | grep -c '\.md$' || true)"
    read="$(cat "$d/read/$TEAM_PROJECT.seq" 2>/dev/null || echo 0)"
    case "$read" in ''|*[!0-9]*) read=0 ;; esac
    n=$((last - read)); [ "$n" -lt 0 ] && n=0
    total=$((total + n))
  done
  printf '%s\n' "$total"
}

team_meeting_participants() { team_meeting_state "$1" PARTICIPANTS ''; }

# 登记表读写（PEER_SESSIONS / PM_WINDOWS / PARTICIPANT_REPOS 共用的 `<键>=<值>;…` 串行化）
team_meeting_map_get() { # <map> <key>
  local kv
  for kv in $(printf '%s' "$1" | tr ';' ' '); do
    case "$kv" in
      "$2=") printf '\n'; return 0 ;;
      "$2="*) printf '%s\n' "${kv#*=}"; return 0 ;;
    esac
  done
  printf '\n'
}
team_meeting_map_put() { # <map> <key> <value>（保留其它行，覆盖同键行）
  local kv out=""
  for kv in $(printf '%s' "$1" | tr ';' ' '); do
    [ -n "$kv" ] || continue
    case "$kv" in "$2="*) ;; *) out="${out:+$out;}$kv" ;; esac
  done
  out="${out:+$out;}$2=$3"
  printf '%s\n' "$out"
}

team_meeting_participant_repos() { # <slug> → 参与方仓库名映射（PROJ=basename;…）
  team_meeting_state "$1" PARTICIPANT_REPOS ''
}

team_meeting_peer_sessions() { # <slug> → 参与方 session 映射（PROJ=session;…）
  team_meeting_state "$1" PEER_SESSIONS ''
}

team_meeting_peer_session() { # <slug> <project>
  team_meeting_map_get "$(team_meeting_peer_sessions "$1")" "$2"
}

# D6：每方自己的 PM 窗口（`PM_WINDOWS=<项目>=<窗口>;…`）；旧会议退回 legacy PM_WINDOW，再退回 pm。
team_meeting_pm_windows() { team_meeting_state "$1" PM_WINDOWS ''; }
team_meeting_peer_window() { # <slug> <项目> → 该项目的窗口（映射行 ＞ 旧字段 ＞ pm）
  local w
  w="$(team_meeting_map_get "$(team_meeting_pm_windows "$1")" "$2")"
  [ -n "$w" ] || w="$(team_meeting_state "$1" PM_WINDOW pm)"
  printf '%s\n' "${w:-pm}"
}
# `meeting peer` 缺省窗口：自己项目的窗口优先 TEAM_PM_WINDOW，其次当前 tmux 窗口，最后 pm；
# 给别人登记且没给 --window 时不猜对方环境（那是猜测，不是登记）→ pm。
team_meeting_window_default() { # <项目>
  if [ "$1" = "${TEAM_PROJECT:-}" ]; then
    if [ -n "${TEAM_PM_WINDOW:-}" ]; then printf '%s\n' "$TEAM_PM_WINDOW"; return 0; fi
    if [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
      local w; w="$(tmux display-message -p '#W' 2>/dev/null || true)"
      [ -n "$w" ] && { printf '%s\n' "$w"; return 0; }
    fi
  fi
  printf 'pm\n'
}

# ---------------------------------------------------------------- open
team_cmd_meeting() {
  local sub="${1:-help}"; shift || true
  case "$sub" in
    open)    team_meeting_open "$@" ;;
    say)     team_meeting_say "$@" ;;
    read)    team_meeting_read "$@" ;;
    list)    team_meeting_list "$@" ;;
    inbox)   team_meeting_inbox "$@" ;;
    peer)    team_meeting_peer "$@" ;;
    knock)   team_meeting_knock_cmd "$@" ;;
    propose) team_meeting_propose "$@" ;;
    agree)   team_meeting_agree "$@" ;;
    close)   team_meeting_close "$@" ;;
    help|--help|-h) team_meeting_help ;;
    *) team_usage_die "meeting: 未知子命令 $sub（open|say|read|list|inbox|peer|knock|propose|agree|close）" ;;
  esac
}

team_meeting_help() {
  cat <<HELP
team meeting —— 跨项目会议（peer 交流，不是指挥通道）

  open <slug> --with <项目>[:<session>] --topic "…" [--ttl 72] [--force] [--yes]
      开会（需要 --yes：这是写共享状态）。发起方 = 当前项目（$TEAM_PROJECT）。
      --ttl 是正整数小时（默认 $(team_meeting_ttl_default)，>8760 按 8760 计；非法值直接拒绝）；到期后只读。
  say <slug> --intent <info|question|report|proposal|request> "…" [--knock]
      发言：先写共享区 transcript（唯一真相），--knock 才提醒对方 PM 窗口（需 TEAM_MEETING_KNOCK=1）。
      **没有 command/order 这类 intent** —— 机制上不提供"下令"动作。
  read <slug> [--since N] [--peek]    读发言（默认读到哪标记到哪；--peek 不标记）
  inbox                                哪些会议在等我回应
  list [--all]                         我在参与的会议
  peer <slug> <项目>:<session> [--window <名>] [--repo <仓库名>]
      登记一方的 session/PM 窗口/仓库名（各管各的行；敲门按对方那一行解析目标窗口）
  knock <slug>                         重敲最后一条发言（载荷带 [meeting:<slug>#<N>]）
  propose <slug> "接口契约…" [--sides "我方:X / 对方:Y"]   提议一条共识
  agree <slug> <A1> [--note "我方落地：T4.2"]              对方确认（不能自己确认自己提的）
  close <slug> [--summary "结论与遗留"]   关闭（唯一收尾动作；过期后仍可用它收尾）
  close --stale                            关闭本项目所有“已过期未关闭”的会议；一个都没有时非 0 且不写任何东西

规则：只写共享区（$(team_meetings_dir)），不动对方仓库；共识由双方各自 agree；
用户是唯一能跨项目下指令的人（人类终端可 team meeting say --as-user）。
HELP
  return 0
}

team_meeting_open() {
  local slug="" peer="" topic="" ttl="$(team_meeting_ttl_default)" force=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --with) peer="${2:?}"; shift 2 ;;
      --topic) topic="${2:?}"; shift 2 ;;
      --ttl) ttl="${2:?}"; shift 2 ;;
      --force) force=1; shift ;;
      --yes|-y) TEAM_ASSUME_YES=1; shift ;;
      -*) team_usage_die "meeting open: 未知参数 $1" ;;
      *) slug="$1"; shift ;;
    esac
  done
  [ -n "$slug" ] || team_usage_die "meeting open <slug> --with <项目>[:<session>] --topic \"…\""
  [ -n "$peer" ] || team_usage_die "meeting open: 需要 --with <项目>[:<session>]"
  # F19：TTL 必须在开会时就校验。旧实现把 0/负数/非数字原样写进 state.env，
  # 而 is_expired 把这类值当「永不过期」——一次 --ttl 0 就得到一个永远合法的会议。
  case "$ttl" in
    ''|*[!0-9]*) team_usage_die "meeting open: --ttl 必须是正整数小时（收到 '$ttl'；不传则用默认 $(team_meeting_ttl_default)）" ;;
  esac
  [ "$ttl" -gt 0 ] 2>/dev/null || team_usage_die "meeting open: --ttl 必须是正整数小时（收到 '$ttl'；不传则用默认 $(team_meeting_ttl_default)）"
  if [ "$ttl" -gt 8760 ]; then
    team_warn "meeting open: --ttl $ttl 超过一年（8760 小时）：按 8760 计"
    ttl=8760
  fi
  team_meeting_validate_slug "$slug"
  team_allow_write || return 1     # 写共享区 = 改共享状态，需要显式授权

  local proj="$TEAM_PROJECT" psess="${TEAM_SESSION:-}"
  local peer_proj="${peer%%:*}" peer_sess=""
  case "$peer" in *:*) peer_sess="${peer#*:}" ;; esac
  [ "$peer_proj" = "$proj" ] && team_die "不能和自己开会（--with $peer）"

  local d; d="$(team_meeting_dir "$slug")"
  if [ -d "$d" ] && [ "$force" != "1" ]; then
    team_die "会议已存在：$slug（续用直接 meeting say；要重开加 --force）"
  fi
  mkdir -p "$d/transcript" "$d/agreements" "$d/read"

  local peers="${proj}=${psess}"
  [ -n "$peer_sess" ] && peers="$peers;$peer_proj=$peer_sess"
  local pmwin="${TEAM_PM_WINDOW:-pm}"
  [ -n "$pmwin" ] || pmwin="pm"
  cat > "$d/state.env" <<EOF
SLUG=$slug
TOPIC=$topic
STATUS=open
PARTICIPANTS=$proj,$peer_proj
PEER_SESSIONS=$peers
PM_WINDOWS=$proj=$pmwin
PM_WINDOW=$pmwin
PARTICIPANT_REPOS=$proj=$(team_meeting_repo_basename)
OPENED_BY=$proj
OPENED_AT=$(team_timestamp)
OPENED_EPOCH=$(date +%s)
TTL_HOURS=$ttl
MAX_TURNS=${TEAM_MEETING_MAX_TURNS:-20}
EOF
  cat > "$d/agenda.md" <<EOF
# 会议：$topic

- slug: \`$slug\`
- 发起方：$proj
- 参与方：$proj, $peer_proj
- 开启：$(team_timestamp)（TTL ${ttl}h）
- 共享区：\`$d\`

## 议题

$topic

## 边界（每次开会都适用）

会议只产出**共识 + 各自待办**，不产出对另一方的命令；共识由双方各自 \`agree\`；
落地一律由各方在自己项目内完成（谁的项目谁决定）。
EOF
  printf '# 共识（双方各自 agree 才生效）\n\n> 每条：\`A<n>\` = \\`agreements/A<n>.md\\`；提议方与确认方必须是不同参与方。\n' > "$d/agreements/INDEX.md"
  printf '0\n' > "$d/read/$proj.seq"

  team_ok "会议已开：$slug（参与方 $proj ↔ $peer_proj，TTL ${ttl}h）"
  team_dim "  下一步：$TEAM_CLI meeting say $slug --intent proposal \"<你要提的事>\""
  team_dim "  共享区：$d"
}

# ---------------------------------------------------------------- say
team_meeting_say() {
  local slug="" intent="info" text="" knock=0 as_user=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --intent) intent="${2:?}"; shift 2 ;;
      --intent=*) intent="${1#*=}"; shift ;;
      --knock) knock=1; shift ;;
      --as-user) as_user=1; shift ;;
      -*) team_usage_die "meeting say: 未知参数 $1" ;;
      *) if [ -z "$slug" ]; then slug="$1"; else text="${text:+$text }$1"; fi; shift ;;
    esac
  done
  # 允许 "meeting say <slug> --intent x 文本..."（文本是剩余位置参数）
  if [ $# -gt 0 ]; then text="$*"; fi
  [ -n "$slug" ] || team_usage_die "meeting say <slug> --intent <类型> \"<内容>\""
  [ -n "$text" ] || team_usage_die "meeting say: 内容不能为空"
  team_meeting_require_open "$slug" say

  # 身份：agent 不能冒充用户（人类终端才有资格）
  local sender
  if [ "$as_user" = "1" ]; then
    if [ ! -t 0 ] && [ ! -t 1 ]; then
      team_die "拒绝：--as-user 只允许人类在终端里使用（agent 进程不得冒充用户向其他 PM 下指令）"
    fi
    case "${TEAM_MEETING_ALLOW_USER_ID:-}" in
      1|yes|true) sender="user" ;;
      *) team_die "拒绝：--as-user 需要 TEAM_MEETING_ALLOW_USER_ID=1（由人类在终端显式开启）" ;;
    esac
  else
    sender="$TEAM_PROJECT"
  fi

  # intent 白名单：机制里没有"下令"
  case " $TEAM_MEETING_INTENTS " in
    *" $intent "*) ;;
    *) if [ "$sender" != "user" ]; then
         team_die "意图非法：$intent（允许：$TEAM_MEETING_INTENTS）。会议不提供 command/order —— 不能指挥别的 PM"
       else
         team_die "意图非法：$intent（允许：$TEAM_MEETING_INTENTS）"
       fi ;;
  esac
  if [ "$sender" != "user" ]; then
    case "$text" in
      *"[order]"*|*"[command]"*|*"[指令]"*|*"[命令]"*)
        team_die "拒绝：跨项目消息里带 [order]/[command]/[指令]/[命令] 标记 —— 会议不是下令通道" ;;
    esac
  fi

  # 轮次预算
  local max turns
  max="$(team_meeting_state "$slug" MAX_TURNS "${TEAM_MEETING_MAX_TURNS:-20}")"
  # 环境变量是硬上限（比会议里登记的更严时以它为准）
  if [ "${TEAM_MEETING_MAX_TURNS:-20}" -lt "$max" ] 2>/dev/null; then max="$TEAM_MEETING_MAX_TURNS"; fi
  turns="$(team_meeting_turns "$slug" "$TEAM_PROJECT")"
  if [ "$turns" -ge "$max" ]; then
    team_die "本侧发言已达上限（$turns/$max）：先 close 或在 state.env 调大 MAX_TURNS（防止两个 PM 互相刷额度）"
  fi

  local d seq file
  d="$(team_meeting_dir "$slug")"
  seq="$(team_meeting_seq "$slug")"
  file="$d/transcript/${seq}_${sender}_${intent}.md"
  {
    printf -- '---\n'
    printf 'seq: %s\n' "${seq#0}"
    printf 'from: %s%s\n' "$sender" "$([ "$sender" = "user" ] && echo '（人类）' || echo "/pm@${TEAM_SESSION:-?}")"
    printf 'intent: %s\n' "$intent"
    printf 'time: %s\n' "$(team_timestamp)"
    printf -- '---\n\n'
    printf '%s\n' "$text"
  } > "$file"
  printf '%s\n' "${seq#0}" > "$d/read/$TEAM_PROJECT.seq"   # 自己写的自己已读
  team_ok "已写入共享区：${file#"$(team_meetings_dir)/"}（intent=$intent）"

  if [ "$knock" = "1" ]; then
    # R2：轮次标识用十进制（transcript 文件名是零填充的 0004 → #4，两侧同号）
    team_meeting_knock "$slug" "$sender" "$intent" "$((10#${seq:-0}))"
  else
    team_dim "  未敲门（默认关）：对方 PM 下次巡检看到 $TEAM_CLI meeting inbox；紧急再加 --knock"
  fi
}

# 一条「记录名是不是本项目」的判定（R1 的单行版）：敲门的“哪一行是对方”与 peer 的“登记到哪个记录名”
# 都用它 —— 同一套身份轴（声明名 / 仓库 basename / 记录仓库名 / 受邀 session），不另写第二份。
team_meeting_record_is_mine() { # <slug> <记录里的项目名>
  local slug="$1" p="$2" proj base repos kv k v s
  proj="${TEAM_PROJECT:-}"
  base="$(team_meeting_repo_basename 2>/dev/null || true)"
  if [ -n "$proj" ] && [ "$p" = "$proj" ]; then return 0; fi
  if [ -n "$base" ] && [ "$p" = "$base" ]; then return 0; fi
  s="$(team_meeting_map_get "$(team_meeting_peer_sessions "$slug")" "$p")"
  if [ -n "${TEAM_SESSION:-}" ] && [ "$s" = "$TEAM_SESSION" ]; then return 0; fi
  repos="$(team_meeting_participant_repos "$slug")"
  for kv in $(printf '%s' "$repos" | tr ';' ' '); do
    [ -n "$kv" ] || continue
    k="${kv%%=*}"; v="${kv#*=}"
    [ "$k" = "$p" ] || continue
    if [ -n "$proj" ] && [ "$v" = "$proj" ]; then return 0; fi
    if [ -n "$base" ] && [ "$v" = "$base" ]; then return 0; fi
  done
  return 1
}

# 把 <项目> 解析为记录里的参与方名（peer 登记用）：先认名单，再认 session，再认仓库记录。
team_meeting_resolve_participant() { # <slug> <项目> <session>
  local slug="$1" want="$2" sess="$3" p parts kv k v
  parts="$(team_meeting_participants "$slug")"
  for p in $(printf '%s' "$parts" | tr ',' ' '); do
    [ "$p" = "$want" ] && { printf '%s\n' "$p"; return 0; }
  done
  if [ -n "$sess" ]; then
    for p in $(printf '%s' "$parts" | tr ',' ' '); do
      [ "$(team_meeting_map_get "$(team_meeting_peer_sessions "$slug")" "$p")" = "$sess" ] && { printf '%s\n' "$p"; return 0; }
    done
  fi
  for p in $(printf '%s' "$parts" | tr ',' ' '); do
    for kv in $(printf '%s' "$(team_meeting_participant_repos "$slug")" | tr ';' ' '); do
      [ -n "$kv" ] || continue
      k="${kv%%=*}"; v="${kv#*=}"
      [ "$k" = "$p" ] || continue
      { [ "$k" = "$want" ] || [ "$v" = "$want" ]; } && { printf '%s\n' "$p"; return 0; }
    done
  done
  return 1
}

# 敲门账本**只有这一处写法**（P160 F1）：立刻投递与排队后投递写出的行逐字节同形，
# 时间戳是**实际投递**的时刻。入队那一刻不写（共享区零写入的承诺不破）；投递确认后由
# outbox 的 `team_outbox_record_delivery_receipt` 调到这里补记同一轮次。
# 会议目录不在（会议被清掉）就什么都不写 —— 绝不凭空造出一个会议目录。
team_meeting_knock_ledger_record() { # <slug> <turn> <peer_proj> <sender> <intent>
  local slug="$1" turn="$2" proj="$3" sender="$4" intent="$5" d=""
  [ -n "$slug" ] || return 0
  case "$turn" in ''|*[!0-9]*) return 0 ;; esac
  d="$(team_meeting_dir "$slug")"
  [ -d "$d" ] || return 0
  printf '%s knocked %s by %s intent=%s [meeting:%s#%s]\n' \
    "$(team_timestamp)" "${proj:--}" "${sender:--}" "${intent:--}" "$slug" "$turn" >> "$d/knocks.log"
  return 0
}

# 敲门：唯一允许的跨 session 动作 —— 只发一条"有会议消息"通知，对方自己决定怎么回。
# 敲门走**受守卫的投递**（D5）：对方输入框有空就打字，有草稿就入队报 queued；本函数不再自己 send-keys。
# 载荷带轮次标识（R2）：[meeting:<slug>#<N>] —— 接收方只凭自己的 read/<project>.seq 就能判 stale。
team_meeting_knock_diag() { # <slug> <target> <peer_sess> [<peer_proj>]
  local slug="$1" target="$2" peer_sess="$3" peer_proj="${4:-<对方项目>}"
  local peer_win="${target#*:}"
  printf '  敲门排查（按顺序）：\n'
  printf '    1) 全局开关        %s\n' "$([ "${TEAM_MEETING_KNOCK:-0}" = "1" ] && echo "TEAM_MEETING_KNOCK=1 ✓" || echo "TEAM_MEETING_KNOCK=0 ✗ ← 用它拦住的；设 1 才允许敲门")"
  printf '    2) 对方 session    %s\n' "${peer_sess:-（未登记）← 跑 $TEAM_CLI meeting peer $slug <项目>:<session>}"
  printf '    3) session 存在    %s\n' "$(tmux has-session -t "$peer_sess" 2>/dev/null && echo "✓ $peer_sess" || echo "✗ tmux 里没有 $peer_sess")"
  printf '    4) 敲门目标        %s（%s 自己的 PM_WINDOWS 行）\n' "$target" "$peer_proj"
  printf '    5) PM 窗口在跑 pi %s\n' "$(team_pane_busy "$target" && echo "✓ $target" || echo "✗ $target 没在跑 pi（空提示符/不存在）")"
  printf '    6) 边界守卫        %s\n' "$(team_foreign_target_ok "$target" "$slug" >/dev/null 2>&1 && echo "✓ 已登记会议的敲门放行" || echo "✗ 目标 session 不在本会议登记里")"
  printf '  登记/改窗：%s meeting peer %s %s:%s --window %s\n' "$TEAM_CLI" "$slug" "$peer_proj" "$peer_sess" "${peer_win:-pm}"
  printf '  注：敲门失败不影响消息——它已经在共享区，对方 $TEAM_CLI meeting inbox 能看到。\n'
  return 0
}

team_meeting_knock() { # <slug> <sender> <intent> [<turn>]
  local slug="$1" sender="$2" intent="$3" turn="${4:-}"
  if [ "${TEAM_MEETING_KNOCK:-0}" != "1" ]; then
    team_dim "  --knock 被全局开关拦住（TEAM_MEETING_KNOCK=0）：只落盘不打扰对方"
    team_dim "  要允许敲门：在双方项目 config 里设 TEAM_MEETING_KNOCK=1（或临时 TEAM_MEETING_KNOCK=1 $TEAM_CLI meeting say … --knock）"
    return 0
  fi
  team_have_cmd tmux || { team_warn "没有 tmux：敲门跳过（消息仍在共享区）"; return 0; }
  # R2：没有可指认的轮次就不敲门（载荷里的 #N 必须真的在 transcript 里）
  case "$turn" in
    ''|*[!0-9]*) team_warn "没有可指认的发言轮次：不敲门（消息仍在共享区）"; return 0 ;;
  esac
  [ "$turn" -gt 0 ] 2>/dev/null || { team_warn "轮次标识非法（$turn）：不敲门（消息仍在共享区）"; return 0; }
  local peer_sess="" peer_proj="" kv map
  map="$(team_meeting_peer_sessions "$slug")"
  for kv in $(printf '%s' "$map" | tr ';' ' '); do
    [ -n "$kv" ] || continue
    team_meeting_record_is_mine "$slug" "${kv%%=*}" && continue
    peer_proj="${kv%%=*}"; peer_sess="${kv#*=}"
    break
  done
  if [ -z "$peer_sess" ]; then
    team_dim "  对方 session 未知 → 只落盘"
    team_dim "  登记方式：$TEAM_CLI meeting peer $slug ${peer_proj:-<对方项目>}:<对方 session>（然后重敲：$TEAM_CLI meeting knock $slug）"
    return 0
  fi
  # D6：目标是**对方自己那一行**的窗口（映射 ＞ 旧 PM_WINDOW ＞ pm），不再共用单个字段
  local peer_win target
  peer_win="$(team_meeting_peer_window "$slug" "$peer_proj")"
  target="$peer_sess:$peer_win"
  if ! team_foreign_target_ok "$target" "$slug"; then
    team_meeting_knock_diag "$slug" "$target" "$peer_sess" "$peer_proj"
    return 1
  fi
  if ! tmux has-session -t "$peer_sess" 2>/dev/null; then
    team_dim "  对方 session 不在（$peer_sess）：只落盘"
    team_meeting_knock_diag "$slug" "$target" "$peer_sess" "$peer_proj"
    return 0
  fi
  if ! team_pane_busy "$target"; then
    team_dim "  对方 PM 窗口没在跑 pi（$target）：只落盘（等他起来看 inbox）"
    team_meeting_knock_diag "$slug" "$target" "$peer_sess" "$peer_proj"
    return 0
  fi
  local notice="[meeting:$slug#$turn] $sender 有新发言（intent=$intent）→ 跑 $TEAM_CLI meeting read $slug"
  # P160 F1：`meeting-ledger` 是「真投出去了才补账本」的凭据 —— 入队时**不写**共享区（规格承诺
  # 不破），由 outbox 在投递确认后调 team_meeting_knock_ledger_record 补记同一轮次（tab 分隔字段）。
  local ledger
  ledger="$(printf '%s\t%s\t%s\t%s' "$slug" "$turn" "$peer_proj" "$intent")"
  team_send_guarded "$target" "$notice" meeting-knock --from "$sender" --meeting-ledger "$ledger"
  case "$TEAM_SEND_OUTCOME" in
    delivered|watched|unknown-sent)
      if [ "$TEAM_SEND_OUTCOME" = "unknown-sent" ]; then
        team_warn "已敲门（未确认）：$target（[meeting:$slug#$turn]）"
      else
        team_ok "已敲门：$target（[meeting:$slug#$turn]）"
      fi
      # knocks.log 记同一个轮次标识（R2：接收方不读发送方仓库也能判这条通知指的是哪一轮）
      team_meeting_knock_ledger_record "$slug" "$turn" "$peer_proj" "$sender" "$intent" ;;
    queued)
      team_dim "  敲门 queued：对方 PM 输入框里有草稿，通知已入队（$TEAM_CLI outbox list），清空后自动投递" ;;
    *)
      # offline / unknown-failed：对方不可投 —— 消息不丢（shared area），队列里也不留假承诺
      team_warn "敲门没落地（${TEAM_SEND_OUTCOME:-offline}）：消息仍在共享区"
      team_meeting_knock_diag "$slug" "$target" "$peer_sess" "$peer_proj" ;;
  esac
  return 0
}

team_meeting_peer() { # <slug> <项目>[:<session>] [--window <名>] [--repo <仓库名>]
  local slug="" win="" repo="" repo_set=0 spec=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --window) win="${2:?--window 需要窗口名}"; shift 2 ;;
      --repo) repo="${2:?--repo 需要仓库名}"; repo_set=1; shift 2 ;;
      -*) team_usage_die "meeting peer: 未知参数 $1" ;;
      *) if [ -z "$slug" ]; then slug="$1"; elif [ -z "$spec" ]; then spec="$1"; else team_usage_die "meeting peer: 多余参数 $1"; fi; shift ;;
    esac
  done
  [ -n "$slug" ] && [ -n "$spec" ] || team_usage_die "meeting peer <slug> <项目>[:<session>] [--window <名>] [--repo <仓库名>]"
  team_meeting_require_open "$slug" say
  local proj="${spec%%:*}" sess=""
  case "$spec" in *:*) sess="${spec#*:}" ;; esac
  [ -n "$sess" ] || team_die "需要 session：$TEAM_CLI meeting peer $slug $proj:<session>（用 tmux ls 看）"
  local pname
  pname="$(team_meeting_resolve_participant "$slug" "$proj" "$sess")" \
    || team_die "$proj（session $sess）不是本会议参与方（参与方：$(team_meeting_participants "$slug")）"
  # D6：窗口缺省 —— 自己项目用 TEAM_PM_WINDOW→当前 tmux 窗口→pm；给别人登记又没给 --window 用 pm
  [ -n "$win" ] || win="$(team_meeting_window_default "$pname")"
  # 仓库名：显式 --repo 优先；自己的登记缺省 = 主工作树 basename（不编别人的）
  if [ "$repo_set" != "1" ] && team_meeting_record_is_mine "$slug" "$pname"; then
    repo="$(team_meeting_repo_basename 2>/dev/null || true)"
  fi
  team_meeting_set "$slug" PEER_SESSIONS "$(team_meeting_map_put "$(team_meeting_peer_sessions "$slug")" "$pname" "$sess")"
  team_meeting_set "$slug" PM_WINDOWS "$(team_meeting_map_put "$(team_meeting_pm_windows "$slug")" "$pname" "$win")"
  if [ -n "$repo" ]; then
    team_meeting_set "$slug" PARTICIPANT_REPOS "$(team_meeting_map_put "$(team_meeting_participant_repos "$slug")" "$pname" "$repo")"
  fi
  team_ok "已登记 $pname: session=$sess window=$win${repo:+ repo=$repo}"
  [ "$pname" != "$TEAM_PROJECT" ] && team_dim "  提示：登记的是对方 session；对方也可以自己登记自己的（以他那边的为准）"
  return 0
}

team_meeting_knock_cmd() { # <slug> —— 重新敲门（登记 session 之后用）
  local slug=""
  case "${1:-}" in ''|-*) team_usage_die "meeting knock <slug>" ;; esac
  slug="$1"
  team_meeting_require_open "$slug" say
  local last_intent="" f seq="" from=""
  f="$(ls "$(team_meeting_dir "$slug")/transcript/"*.md 2>/dev/null | sort | tail -1)"
  if [ -z "$f" ]; then
    team_warn "这个会议还没有发言：先 $TEAM_CLI meeting say $slug --intent info \"…\"，再敲门"
    return 0
  fi
  from="$(grep -s '^from:' "$f" | head -1 | cut -d: -f2- | tr -d ' ')"
  last_intent="$(grep -s '^intent:' "$f" | head -1 | cut -d: -f2- | tr -d ' ')"
  seq="$(basename "$f" | cut -c1-4)"
  seq=$((10#${seq:-0}))
  team_info "重敲最后一条发言（#$seq from=${from:-?} intent=${last_intent:-?}）"
  team_meeting_knock "$slug" "${from:-$TEAM_PROJECT}" "${last_intent:-info}" "$seq"
}
# ---------------------------------------------------------------- read / list / inbox
team_meeting_read() {
  local slug="" since=0 peek=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --since) since="${2:?}"; shift 2 ;;
      --peek|--no-mark) peek=1; shift ;;
      -*) team_usage_die "meeting read: 未知参数 $1" ;;
      *) slug="$1"; shift ;;
    esac
  done
  [ -n "$slug" ] || team_usage_die "meeting read <slug> [--since N] [--peek]"
  team_meeting_require_open "$slug" read
  local d; d="$(team_meeting_dir "$slug")"
  team_hdr "meeting $slug · $(team_meeting_state "$slug" TOPIC -)"
  printf '  参与方 %s ｜ 状态 %s ｜ TTL %sh%s\n' \
    "$(team_meeting_state "$slug" PARTICIPANTS -)" \
    "$(team_meeting_state_text "$slug")" \
    "$(team_meeting_ttl_hours "$slug")" \
    "$(team_meeting_ttl_note "$slug")"
  local f n last=0
  for f in "$d/transcript/"*.md; do
    [ -f "$f" ] || continue
    n="$(basename "$f" | cut -c1-4)"; n=$((10#$n))
    [ "$n" -le "$((10#$since))" ] && continue
    printf '\n%s\n' "$(team_rule)"
    sed -n '1,5p' "$f" | sed 's/^/  /'
    printf '\n'
    sed -n '7,$p' "$f" | sed 's/^/  /'
    last="$n"
  done
  local ag
  for ag in "$d/agreements/"A*.md; do
    [ -f "$ag" ] || continue
    printf '\n%s\n' "$(team_rule)"
    printf '  %s\n' "$(basename "$ag" .md) 状态：$(team_meeting_agreement_status "$ag")"
    sed -n '1,20p' "$ag" | sed 's/^/    /'
  done
  if [ "$peek" != "1" ] && [ "$last" -gt 0 ]; then
    printf '%s\n' "$last" > "$d/read/$TEAM_PROJECT.seq"
    team_dim "  已标记读到 #$last"
  fi
  return 0
}

team_meeting_agreement_status() { # <file>
  local sides agreed
  sides="$(grep -s '^participants:' "$1" | head -1 | cut -d: -f2- | tr -d ' ' || true)"
  agreed="$(grep -c '^agreed-by:' "$1" || true)"
  # 提议方视为已同意 → 只需要其余参与方各 agree 一次
  local need; need="$(printf '%s' "$sides" | tr ',' '\n' | grep -c . || true)"
  need=$((need - 1)); [ "$need" -lt 1 ] && need=1
  if [ "$agreed" -ge "$need" ]; then printf 'agreed'; else printf 'proposed'; fi
}

team_meeting_list() {
  local all=0 slug
  while [ $# -gt 0 ]; do
    case "$1" in
      --all) all=1; shift ;;
      -*) team_usage_die "meeting list: 未知参数 $1" ;;
      *) team_usage_die "meeting list: 多余参数 $1" ;;
    esac
  done
  local root; root="$(team_meetings_dir)"
  [ -d "$root" ] || { team_dim "还没有任何会议（$TEAM_CLI meeting open …）"; return 0; }
  printf '%-24s %-10s %-8s %s\n' SLUG 状态 待读 TOPIC
  printf '%-24s %-10s %-8s %s\n' ---- ------ ----- -----
  for slug in "$root"/*/; do
    [ -d "$slug" ] || continue
    slug="$(basename "$slug")"
    if [ "$all" != "1" ] && ! team_meeting_is_mine "$slug"; then continue; fi
    local pend=0 last read
    last="$(ls "$(team_meeting_dir "$slug")/transcript" 2>/dev/null | grep -c '\.md$' || true)"
    read="$(cat "$(team_meeting_dir "$slug")/read/$TEAM_PROJECT.seq" 2>/dev/null || echo 0)"
    pend=$((last - read)); [ "$pend" -lt 0 ] && pend=0
    printf '%-24s %-10s %-8s %s\n' "$slug" \
      "$(team_meeting_state_word "$slug")" \
      "$pend" "$(team_meeting_state "$slug" TOPIC -)"
  done
  return 0
}

team_meeting_inbox() {
  local root slug pend n=0
  root="$(team_meetings_dir)"
  [ -d "$root" ] || return 0
  for slug in "$root"/*/; do
    [ -d "$slug" ] || continue
    slug="$(basename "$slug")"
    team_meeting_is_mine "$slug" || continue
    team_meeting_is_closed "$slug" && continue
    local last read
    last="$(ls "$(team_meeting_dir "$slug")/transcript" 2>/dev/null | grep -c '\.md$' || true)"
    read="$(cat "$(team_meeting_dir "$slug")/read/$TEAM_PROJECT.seq" 2>/dev/null || echo 0)"
    pend=$((last - read))
    [ "$pend" -le 0 ] && continue
    n=$((n + 1))
    printf '  %s（%s 条新发言）→ %s meeting read %s\n' "$slug" "$pend" "$TEAM_CLI" "$slug"
  done
  [ "$n" -eq 0 ] && team_dim "  （没有待回应的会议）"
  return 0
}

# 会议现场行（D4）：status 与 digest 共用的唯一实现 —— 每场会议至多一行，没有事项就一个字都不印。
#   先报到读位之后还有新发言的（含过期但未关闭的——transcript 可读，能读就能清）：
#     <slug> N 条新 → team meeting read <slug>
#   再报到过期未关闭的（read 位已清的人才需要它）：
#     <slug> 已过期未关闭 → team meeting close --stale
# 读位缺失/不可解析按 0（与未读计数同一口径：宁可多报，不许少报）。
team_meeting_status_lines() {
  local root slug d last read n
  root="$(team_meetings_dir)"
  [ -d "$root" ] || return 0
  for slug in "$root"/*/; do
    [ -d "$slug" ] || continue
    slug="$(basename "$slug")"
    team_meeting_is_mine "$slug" || continue
    team_meeting_is_closed "$slug" && continue
    d="$(team_meeting_dir "$slug")"
    last="$(ls "$d/transcript" 2>/dev/null | grep -c '\.md$' || true)"
    read="$(cat "$d/read/$TEAM_PROJECT.seq" 2>/dev/null || echo 0)"
    case "$read" in ''|*[!0-9]*) read=0 ;; esac
    n=$((last - read)); [ "$n" -lt 0 ] && n=0
    if [ "$n" -gt 0 ]; then
      printf '  %s %s 条新 → %s meeting read %s\n' "$slug" "$n" "$TEAM_CLI" "$slug"
    elif team_meeting_is_expired "$slug"; then
      printf '  %s 已过期未关闭 → %s meeting close --stale\n' "$slug" "$TEAM_CLI"
    fi
  done
  return 0
}

# ---------------------------------------------------------------- propose / agree
team_meeting_propose() {
  local slug="" text="" sides=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --sides) sides="${2:?}"; shift 2 ;;
      -*) team_usage_die "meeting propose: 未知参数 $1" ;;
      *) if [ -z "$slug" ]; then slug="$1"; else text="${text:+$text }$1"; fi; shift ;;
    esac
  done
  [ -n "$slug" ] || team_usage_die "meeting propose <slug> \"<共识内容>\" [--sides \"…\"]"
  [ -n "$text" ] || team_usage_die "meeting propose: 内容不能为空"
  team_meeting_require_open "$slug" say
  local d; d="$(team_meeting_dir "$slug")"
  local n; n="$(ls "$d/agreements" 2>/dev/null | grep -c '^A[0-9]*\.md$' || true)"
  local id="A$((n + 1))"
  local f="$d/agreements/$id.md"
  {
    printf 'id: %s\n' "$id"
    printf 'proposer: %s\n' "$TEAM_PROJECT"
    printf 'participants: %s\n' "$(team_meeting_participants "$slug" | tr -d ' ')"
    printf 'proposed-at: %s\n' "$(team_timestamp)"
    printf 'sides: %s\n' "${sides:-（待双方补充：我方落地 / 对方落地）}"
    printf -- '---\n\n%s\n' "$text"
  } > "$f"
  team_ok "已提议 $id（等对方 $TEAM_CLI meeting agree $slug $id）"
  printf '| %s | %s | proposed | %s |\n' "$id" "$(team_timestamp)" "$text" >> "$d/agreements/INDEX.md"
}

team_meeting_agree() {
  local slug="" id="" note=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --note) note="${2:?}"; shift 2 ;;
      -*) team_usage_die "meeting agree: 未知参数 $1" ;;
      *) if [ -z "$slug" ]; then slug="$1"; elif [ -z "$id" ]; then id="$1"; fi; shift ;;
    esac
  done
  [ -n "$slug" ] && [ -n "$id" ] || team_usage_die "meeting agree <slug> <A1> [--note \"我方落地：T4.2\"]"
  team_meeting_require_open "$slug" say
  local f; f="$(team_meeting_dir "$slug")/agreements/$id.md"
  [ -f "$f" ] || team_die "没有这条共识：$id"
  local proposer; proposer="$(grep -s '^proposer:' "$f" | head -1 | cut -d: -f2- | tr -d ' ')"
  [ "$proposer" = "$TEAM_PROJECT" ] && team_die "不能确认自己提的共识（$id 由 $proposer 提议，需对方 agree）"
  if grep -q "^agreed-by: $TEAM_PROJECT\b" "$f"; then
    team_warn "你已经确认过 $id"
    return 0
  fi
  printf 'agreed-by: %s at %s%s\n' "$TEAM_PROJECT" "$(team_timestamp)" "${note:+ note: $note}" >> "$f"
  team_ok "已确认 $id（$(team_meeting_agreement_status "$f")）"
  team_dim "  落地由各自在自己项目内完成：我的部分记进 DECISIONS/BOARD，对方的部分由对方 PM 决定"
}

# ---------------------------------------------------------------- close
# ---------------------------------------------------------------- close
# 一场会议的收尾写入（单场 close 与 close --stale 共用；只改 state.env + agenda，不动 transcript）。
team_meeting_do_close() { # <slug> [<summary>]
  team_meeting_set "$1" STATUS closed
  team_meeting_set "$1" CLOSED_BY "$TEAM_PROJECT"
  team_meeting_set "$1" CLOSED_AT "$(team_timestamp)"
  [ -n "${2:-}" ] && team_meeting_set "$1" SUMMARY "$2"
  printf '\n## 关闭 · %s\n\n- by: %s\n- summary: %s\n' \
    "$(team_timestamp)" "$TEAM_PROJECT" "${2:-（无）}" >> "$(team_meeting_dir "$1")/agenda.md"
  return 0
}

team_meeting_close() {
  local slug="" summary="" stale=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --summary) summary="${2:?}"; shift 2 ;;
      --stale) stale=1; shift ;;
      -*) team_usage_die "meeting close: 未知参数 $1" ;;
      *) if [ -z "$slug" ]; then slug="$1"; else summary="${summary:+$summary }$1"; fi; shift ;;
    esac
  done
  # D7：批量形式只收**过期**的会议（未过期的一律不碰：那一侧的 PM 可能还在用）。
  if [ "$stale" = "1" ]; then
    [ -z "$slug" ] || team_usage_die "meeting close --stale 不接受 slug（批量入口只关过期的）"
    team_meeting_close_stale
    return $?
  fi
  [ -n "$slug" ] || team_usage_die "meeting close <slug> [--summary \"结论与遗留\"] | meeting close --stale"
  team_meeting_require_open "$slug" close
  team_meeting_do_close "$slug" "$summary"
  team_ok "会议已关闭：$slug（transcript 冻结，只读）"
  team_dim "  共识 $(ls "$(team_meeting_dir "$slug")/agreements" 2>/dev/null | grep -c '^A[0-9]*\.md$' || true) 条；各自在自己的项目里落地并记录"
}

# close --stale（D7）：逐场报告本次项目里每个未关闭会议的去向；一个都没关 → 非 0 且什么都不写。
team_meeting_close_stale() {
  local root slug closed=0
  root="$(team_meetings_dir)"
  if [ -d "$root" ]; then
    for slug in "$root"/*/; do
      [ -d "$slug" ] || continue
      slug="$(basename "$slug")"
      team_meeting_is_mine "$slug" || continue
      if team_meeting_is_closed "$slug"; then
        team_dim "  $slug 已关闭：跳过"
        continue
      fi
      if team_meeting_is_expired "$slug"; then
        team_meeting_do_close "$slug" "过期未关闭：由 $TEAM_PROJECT 批量收尾（close --stale）"
        team_ok "  $slug 已过期：已关闭"
        closed=$((closed + 1))
      else
        team_dim "  $slug 未过期：跳过（在用）"
      fi
    done
  fi
  if [ "$closed" -eq 0 ]; then
    team_err "没有已过期未关闭的会议（$TEAM_PROJECT）：什么都没写（会议还在用就逐场 close）"
    return 1
  fi
  team_ok "close --stale：关闭了 $closed 场过期会议"
  return 0
}
