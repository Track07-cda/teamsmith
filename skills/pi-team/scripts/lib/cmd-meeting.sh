#!/usr/bin/env bash
# pi-team · 跨项目会议（meeting mode）
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
  local parts; parts="$(team_meeting_state "$1" PARTICIPANTS '')"
  case ",$parts," in *",$TEAM_PROJECT,"*) return 0 ;; *) return 1 ;; esac
}

team_meeting_is_closed() { [ "$(team_meeting_state "$1" STATUS open)" = "closed" ]; }

team_meeting_is_expired() { # TTL 到期 → 只读
  local ttl opened now
  ttl="$(team_meeting_state "$1" TTL_HOURS "${TEAM_MEETING_TTL_HOURS:-72}")"
  opened="$(team_meeting_state "$1" OPENED_EPOCH 0)"
  [ "$ttl" -gt 0 ] 2>/dev/null || return 1
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
    [ "$2" = "read" ] && return 0
    team_die "会议 $1 已过期（TTL $(team_meeting_state "$1" TTL_HOURS)h）：先 $TEAM_CLI meeting close $1，或 open --force 续期"
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

team_meeting_participants() { team_meeting_state "$1" PARTICIPANTS ''; }

team_meeting_peer_sessions() { # <slug> → 参与方 session 映射（PROJ=session;…）
  team_meeting_state "$1" PEER_SESSIONS ''
}

team_meeting_peer_session() { # <slug> <project>
  local map; map="$(team_meeting_peer_sessions "$1")"
  local kv
  for kv in $(printf '%s' "$map" | tr ';' ' '); do
    case "$kv" in
      "$2="*) printf '%s\n' "${kv#*=}"; return 0 ;;
    esac
  done
  printf '\n'
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
    propose) team_meeting_propose "$@" ;;
    agree)   team_meeting_agree "$@" ;;
    close)   team_meeting_close "$@" ;;
    help|--help|-h) team_meeting_help ;;
    *) team_usage_die "meeting: 未知子命令 $sub（open|say|read|list|inbox|propose|agree|close）" ;;
  esac
}

team_meeting_help() {
  cat <<HELP
team meeting —— 跨项目会议（peer 交流，不是指挥通道）

  open <slug> --with <项目>[:<session>] --topic "…" [--ttl 72] [--force] [--yes]
      开会（需要 --yes：这是写共享状态）。发起方 = 当前项目（$TEAM_PROJECT）。
  say <slug> --intent <info|question|report|proposal|request> "…" [--knock]
      发言：先写共享区 transcript（唯一真相），--knock 才提醒对方 PM 窗口（需 TEAM_MEETING_KNOCK=1）。
      **没有 command/order 这类 intent** —— 机制上不提供"下令"动作。
  read <slug> [--since N] [--peek]    读发言（默认读到哪标记到哪；--peek 不标记）
  inbox                                哪些会议在等我回应
  list [--all]                         我在参与的会议
  propose <slug> "接口契约…" [--sides "我方:X / 对方:Y"]   提议一条共识
  agree <slug> <A1> [--note "我方落地：T4.2"]              对方确认（不能自己确认自己提的）
  close <slug> [--summary "结论与遗留"]

规则：只写共享区（$(team_meetings_dir)），不动对方仓库；共识由双方各自 agree；
用户是唯一能跨项目下指令的人（人类终端可 team meeting say --as-user）。
HELP
  return 0
}

team_meeting_open() {
  local slug="" peer="" topic="" ttl="${TEAM_MEETING_TTL_HOURS:-72}" force=0
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
  cat > "$d/state.env" <<EOF
SLUG=$slug
TOPIC=$topic
STATUS=open
PARTICIPANTS=$proj,$peer_proj
PEER_SESSIONS=$peers
PM_WINDOW=${TEAM_PM_WINDOW:-pm}
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
    team_meeting_knock "$slug" "$sender" "$intent"
  else
    team_dim "  未敲门（默认关）：对方 PM 下次巡检看到 $TEAM_CLI meeting inbox；紧急再加 --knock"
  fi
}

# 敲门：唯一允许的跨 session 动作 —— 只发一条"有会议消息"通知，对方自己决定怎么回
team_meeting_knock() { # <slug> <sender> <intent>
  local slug="$1" sender="$2" intent="$3"
  if [ "${TEAM_MEETING_KNOCK:-0}" != "1" ]; then
    team_dim "  --knock 被全局开关拦住（TEAM_MEETING_KNOCK=0）：只落盘不打扰对方"
    return 0
  fi
  team_have_cmd tmux || { team_warn "没有 tmux：敲门跳过（消息仍在共享区）"; return 0; }
  local peer_sess="" peer_proj="" kv map
  map="$(team_meeting_peer_sessions "$slug")"
  for kv in $(printf '%s' "$map" | tr ';' ' '); do
    case "$kv" in
      "$TEAM_PROJECT="*) ;;
      *=*) peer_proj="${kv%%=*}"; peer_sess="${kv#*=}" ;;
    esac
  done
  if [ -z "$peer_sess" ]; then
    team_dim "  对方 session 未知（open 时用 --with <项目>:<session> 登记后就能敲门）"
    return 0
  fi
  local target="$peer_sess:$(team_meeting_state "$slug" PM_WINDOW pm)"
  team_foreign_target_ok "$target" "$slug" || { team_warn "敲门被边界守卫拒绝：$target"; return 1; }
  if ! team_have_cmd tmux || ! tmux has-session -t "$peer_sess" 2>/dev/null; then
    team_dim "  对方 session 不在（$peer_sess）：只落盘"
    return 0
  fi
  if ! team_pane_busy "$target"; then
    team_dim "  对方 PM 窗口没在跑 pi（$target）：只落盘（等他起来看 inbox）"
    return 0
  fi
  local notice="[meeting:$slug] $sender 有新发言（intent=$intent）→ 跑 $TEAM_CLI meeting read $slug"
  if team_tmux_send_text "$target" "$notice" "$slug"; then
    team_ok "已敲门：$target"
    printf '%s knocked %s by %s intent=%s\n' "$(team_timestamp)" "$peer_proj" "$sender" "$intent" \
      >> "$(team_meeting_dir "$slug")/knocks.log"
  else
    team_warn "敲门失败（消息仍在共享区）"
  fi
  return 0
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
  printf '  参与方 %s ｜ 状态 %s%s ｜ TTL %sh\n' \
    "$(team_meeting_state "$slug" PARTICIPANTS -)" \
    "$(team_meeting_state "$slug" STATUS open)" \
    "$(team_meeting_is_expired "$slug" && echo '（已过期）' || true)" \
    "$(team_meeting_state "$slug" TTL_HOURS -)"
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
  [ "${1:-}" = "--all" ] && all=1
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
      "$(team_meeting_state "$slug" STATUS open)$(team_meeting_is_expired "$slug" && echo '(过期)' || true)" \
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
team_meeting_close() {
  local slug="" summary=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --summary) summary="${2:?}"; shift 2 ;;
      -*) team_usage_die "meeting close: 未知参数 $1" ;;
      *) if [ -z "$slug" ]; then slug="$1"; else summary="${summary:+$summary }$1"; fi; shift ;;
    esac
  done
  [ -n "$slug" ] || team_usage_die "meeting close <slug> [--summary \"结论与遗留\"]"
  team_meeting_require_open "$slug" say
  team_meeting_set "$slug" STATUS closed
  team_meeting_set "$slug" CLOSED_BY "$TEAM_PROJECT"
  team_meeting_set "$slug" CLOSED_AT "$(team_timestamp)"
  [ -n "$summary" ] && team_meeting_set "$slug" SUMMARY "$summary"
  printf '\n## 关闭 · %s\n\n- by: %s\n- summary: %s\n' \
    "$(team_timestamp)" "$TEAM_PROJECT" "${summary:-（无）}" >> "$(team_meeting_dir "$slug")/agenda.md"
  team_ok "会议已关闭：$slug（transcript 冻结，只读）"
  team_dim "  共识 $(ls "$(team_meeting_dir "$slug")/agreements" 2>/dev/null | grep -c '^A[0-9]*\.md$' || true) 条；各自在自己的项目里落地并记录"
}
