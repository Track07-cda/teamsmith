#!/usr/bin/env bash
# teamsmith · 投递守卫 + 延后队列（delivery-guard）
#
# 为什么要这一层（D20，E3 §1.1(e) 实测复现）：自动化消息用 `send-keys -l` + `Enter` 打字，
# 若人正在输入框里写草稿，草稿会被粘在消息前面、一起被 Enter 送出去 —— 人写的半句话离开输入框，
# agent 回答了一条没人写过的消息。本文件是唯一允许对 pane 打字的实现：
#
#   1. 守卫（guard）：从光标行锚定输入框的上下边框，读光标所在行及其上方的内容行；
#      有内容 = BUSY → 一个键都不发，消息进 state/outbox/ 排队。
#   2. 队列（outbox）：一条消息 = 一个不可变文件（tmp+rename），头 + `---` + 原文；FIFO 按文件名。
#   3. 排水（drain）：只有一个打字路径；先 claim 再打字（两个并发排水只投一次），
#      Enter 之后用 pane 指纹确认；确认不了就进 held/，绝不重复粘贴。
#
# 已知的诚实边界（写进 references/troubleshooting.md §3，不许静默）：
#   - 只有空白的草稿会被判成 EMPTY（光标相对检测法的实测盲区）；
#   - 找不到输入框形状（非 Pi TUI）= UNKNOWN → 按今天的行为投递 + 一行警告，绝不永久滞留；
#   - 「检查 → 打字」不是原子的：打字前会**再检查一次**，打完还会核对输入框里是否只多出我们这段；
#     残余窗口是「一次命令」，不是循环重发。
#
# 约定：函数名以 team_ 开头；不依赖 jq / python / node；mawk 下框线必须用字节正则（见 E3 §1.7）。

# ---------------------------------------------------------------- 时间 / 小工具
team_epoch_ms() {
  local ms
  ms="$(date +%s%3N 2>/dev/null || true)"
  case "$ms" in ''|*[!0-9]*) ms="$(( $(date +%s) * 1000 ))" ;; esac
  printf '%s\n' "$ms"
}

team_epoch_sec() { date +%s; }

# 文件名第一段是 enqueue 时刻的 epoch-ms（队列的年龄从文件名算，不解析时间字符串）
team_entry_created_ms() { # <entry 路径>
  local b; b="$(basename "$1")"
  case "${b%%-*}" in ''|*[!0-9]*) printf '0\n' ;; *) printf '%s\n' "${b%%-*}" ;; esac
}

team_entry_age_sec() { # <entry 路径> → 秒（负数按 0）
  local ms now age
  ms="$(team_entry_created_ms "$1")"; now="$(team_epoch_ms)"
  age=$(( (now - ms) / 1000 ))
  [ "$age" -lt 0 ] && age=0
  printf '%s\n' "$age"
}

team_defer_ttl() { # TEAM_DEFER_TTL（默认 300s）
  local t="${TEAM_DEFER_TTL:-300}"
  case "$t" in ''|*[!0-9]*) t=300 ;; esac
  printf '%s\n' "$t"
}

team_outbox_max() { # TEAM_OUTBOX_MAX（默认 200）
  local n="${TEAM_OUTBOX_MAX:-200}"
  case "$n" in ''|*[!0-9]*) n=200 ;; esac
  printf '%s\n' "$n"
}

team_dedup_sec() { # TEAM_NOTIFY_DEDUP_SEC（默认 20s）
  local n="${TEAM_NOTIFY_DEDUP_SEC:-20}"
  case "$n" in ''|*[!0-9]*) n=20 ;; esac
  printf '%s\n' "$n"
}

# ---------------------------------------------------------------- 守卫：输入框几何
# 光标锚定（E3 §1.2/§1.5）：Pi 的输入框不在 pane 底部，光标永远落在内容行上，所以
# 从光标行向下找第一条完整横线（下边框），再向上找第一条以框线开头的行（上边框 / 工作中的 spinner 行）。
# 输出每行 "OFFSET|TEXT|ROW"（TEXT 已去尾空白）；找不到边框输出 NONE。
# 陷阱（E3 §1.7）：mawk + UTF-8 下字面量框线正则永远不匹配，必须 LC_ALL=C + 字节形 \xe2\x94\x80；
# 而且必须先缓存所有行、在 END 里算行号（单遍算 bottom-offset 会得到负数）。
# 几何定位的唯一实现：stdin=capture 全文，$1=光标行（1-based）→ 输出 "top bottom"（找不到 → 空）。
_team_box_geometry() { # <cy>
  LC_ALL=C awk -v cy="$1" '
    { L[NR]=$0 }
    END {
      # 候选下边框：光标行**以下**、整行全是 ─ 的行（自下而上最近优先）。光标行自己不算：
      # 光标永远落在内容行上（E3 §1.2），光标行若整行 ─，那是草稿自己画的等宽框线（V9-A10：
      # 把它当下边框会让上方正文落进提示行槽位被排除 → 脏框判空 → 粘连）。
      nb=0
      for (i=cy+1;i<=NR;i++) if (L[i] ~ /^(\xe2\x94\x80)+$/) { nb++; B[nb]=i }
      if (!nb) exit
      t=0; b=0
      for (k=1;k<=nb;k++) {
        cand=B[k]; w=length(L[cand])   # LC_ALL=C 下 ─ 定宽 3 字节：等字节 = 等宽
        # 上边框 = 下边框以上**最高的**候选（tier1：等宽整行 ─；tier2：spinner 形态）。
        # 取最高而不是最近（V9-A4/A5/A8/A10）：草稿自己画的等宽框线/spinner 形状行
        # 若在框内，「最近优先」会把它当成上边框、把它上方的正文排除在框外 → 脏框判空
        # → 粘连（D20 损害）。取最高者时这些行落在框**内**成为内容 → BUSY（保守方向）。
        # 代价：对话区若真有等宽整行 ─，框会被算大 → BUSY——永不粘连。真实 Pi 0.85.1
        # 内容区按 119 折行（边框 120），等宽内容行不可达（V9 90.C/90.F 实测），该代价
        # 只在「裁切型」TUI 上存在。
        hi1=0; hi2=0
        for (i=cand-1;i>=1;i--) {
          if (L[i] ~ /^(\xe2\x94\x80)+$/) {
            # 向下扫、不断覆写 → 循环结束时留下的是行号最小（最高）的候选
            if (length(L[i])==w) hi1=i   # tier1：等宽整行 ─（不等宽的是草稿自己的短框线，V8-N1/N1c）
            continue
          }
          # tier2：spinner 形态（"── ⠇ …" 开头、尾部一段长 ─）。E3 实测工作中 Pi 用
          # spinner 行顶替上边框；0.85.1 改画在框上方独立一行（V9-D2，见 troubleshooting）。
          if (L[i] ~ /^\xe2\x94\x80\xe2\x94\x80 / && \
              L[i] ~ /(\xe2\x94\x80){8}[ \t]*$/) hi2=i
        }
        if (hi1) { t=hi1; b=cand; break }
        if (hi2) { t=hi2; b=cand; break }
      }
      if (t && b) printf "%d %d\n", t, b
    }'
}

team_input_box_rows() { # <target>
  local target="${1:-}" cy cap geo t b
  team_tmux_target_required "input-box" "$target" || return 1
  cy="$(tmux display-message -p -t "$target" '#{cursor_y}' 2>/dev/null || true)"
  [ -n "$cy" ] || return 1
  cy=$(( cy + 1 ))
  cap="$(tmux capture-pane -p -t "$target" 2>/dev/null)" || return 1
  geo="$(printf '%s\n' "$cap" | _team_box_geometry "$cy")"
  [ -n "$geo" ] || { printf 'NONE\n'; return 0; }
  t="${geo%% *}"; b="${geo##* }"
  printf '%s\n' "$cap" | LC_ALL=C awk -v t="$t" -v b="$b" '
    NR>t && NR<b { s=$0; sub(/[ \t]+$/, "", s); printf "%d|%s|%d\n", b-NR, s, NR }'
}

# 对话区文本（上边框以上的行）——提交证据的搜索区（V9-B5）。找不到框 → 返回 1。
team_transcript_text() { # <target>
  local target="$1" cy cap geo
  cy="$(tmux display-message -p -t "$target" '#{cursor_y}' 2>/dev/null || true)"
  [ -n "$cy" ] || return 1
  cy=$(( cy + 1 ))
  cap="$(tmux capture-pane -p -t "$target" 2>/dev/null)" || return 1
  geo="$(printf '%s\n' "$cap" | _team_box_geometry "$cy")"
  [ -n "$geo" ] || return 1
  printf '%s\n' "$cap" | LC_ALL=C awk -v t="${geo%% *}" 'NR<t'
}

# 提交证据的特征串：payload 首个非空白行，去全部空白后截 48 字节（去空白是为了穿透折行；
# 截取前 48 字节是因为气泡区可能只回显消息头部）。空白 payload 没有特征串（空串）。
# 全程 LC_ALL=C：48 字节可能正好切在多字节字符中间——C locale 下 cut/grep 都是纯字节语义，
# 半个字符的字节序列仍然是完整字符的前缀，照样匹配；UTF-8 locale 下非法模式反而匹配不上（V9 实测）。
team_payload_slice() { # <payload>
  printf '%s\n' "$1" | LC_ALL=C awk 'NF {print; exit}' | LC_ALL=C tr -d '[:space:]' | LC_ALL=C cut -c1-48
}

# 对话区里「这条 payload 被提交了」的证据数 = 特征串出现次数 + 匹配 +K 的折叠占位符出现次数
# （有的 TUI 连气泡区也折叠长粘贴，只显示 `[paste #N +K lines]`；K == payload 行数的那份才算）。
# 找不到框 → 0（没有证据概念）。
team_transcript_mentions() { # <target> <slice> <payload 行数>
  local tr n=0
  tr="$(team_transcript_text "$1" 2>/dev/null | LC_ALL=C tr -d '[:space:]')" || { printf '0\n'; return 0; }
  [ -n "$tr" ] || { printf '0\n'; return 0; }
  if [ -n "$2" ]; then
    n="$(printf '%s\n' "$tr" | LC_ALL=C grep -oF "$2" | grep -c . || true)"
  fi
  if [ "${3:-0}" -ge 2 ] 2>/dev/null; then
    # 对话区已被 tr 去空白：`[paste #1 +14 lines]` → `[paste#1+14lines]`
    n=$(( n + $(printf '%s\n' "$tr" | LC_ALL=C grep -oE '\[paste#[0-9]+\+'"$3"'lines\]' | grep -c . || true) ))
  fi
  printf '%s\n' "$n"
}

# **整个输入框**的内容行拼起来（去空白），不再只看光标行及以上（V7-F1：人的草稿以空行
# 开头、光标被 Up 移到空行上时，文字全在光标行**下方** —— 光标相对判定会漏掉它，真实 Pi
# 上不需要竞态就能复现 D20）。唯一被排除的是 OFFSET==1（紧贴下边框）那一行：
#  - 空框里包自带的提示行（" k3  Kimi Coding  max"）就画在那里 —— 它是框的 chrome，不是
#    文字区；E3/V7 的全部实测形状里草稿从不占这一行，按位置排除比按内容匹配更保守
#   （内容匹配会把「长得像提示行的草稿」漏掉，位置排除只会漏「提示行被顶掉且单行草稿恰好
#    落在那一行」—— 真实 Pi 的提示行不动，该形状不可达；残余写进 troubleshooting §3）。
team_input_box_text() { # <target>
  local rows
  rows="$(team_input_box_rows "$1" 2>/dev/null || true)"
  [ -n "$rows" ] && [ "$rows" != "NONE" ] || return 1
  printf '%s\n' "$rows" | LC_ALL=C sort -t'|' -k3,3n | LC_ALL=C awk -F'|' '
    $1+0 != 1 && $2 != "" { printf "%s", $2 }
    END { printf "\n" }'
}

# 只有空白（或什么都没画出来）时的判定：
#   EMPTY   = 框内（提示行除外）没有内容 → 可以打字
#   BUSY    = 有内容（光标上下都算）→ 一个键都不发
#   UNKNOWN = 找不到输入框（非 Pi TUI / 主题破坏了几何）→ 按今天的行为投递 + 一行警告
team_input_box_state() { # <target> → EMPTY|BUSY|UNKNOWN
  local rows text
  rows="$(team_input_box_rows "$1" 2>/dev/null || true)"
  if [ -z "$rows" ] || [ "$rows" = "NONE" ]; then printf 'UNKNOWN\n'; return 0; fi
  text="$(team_input_box_text "$1" 2>/dev/null || true)"
  if [ -n "$(printf '%s' "$text" | tr -d '[:space:]')" ]; then printf 'BUSY\n'; else printf 'EMPTY\n'; fi
}

# 「这一帧是粘贴折叠的中间渲染吗」：真实 TUI 是异步渲染的，折叠占位符不是一帧画完——
# 中间帧是 `[paste #1 +1` 这样的半成品（有前缀、没有完整占位符正则）。它既不是「框停下来了」
# 也不是「有别人的字」（V8-N3：静止判定撞上中间帧会误判竞态，干净消息被终态扣在 held/）。
# 判据是**整行匹配**（某一整行就是半成品形态），不做子串：payload 正文里写着 `[paste #`
# 字样（不含完整占位符）时，子串匹配会把我们自己的正文误判成「还在渲染」（V9-B1，
# 真实 Pi 复现：静止判定永远等不到停 → 干净消息被判竞态、终态扣在 held/）。
team_box_mid_render() { # <文本>
  printf '%s' "$1" | LC_ALL=C grep -qE '^[[:space:]]*\[paste #[0-9]+ \+[0-9]+[[:space:]]*$' || return 1
  printf '%s' "$1" | LC_ALL=C grep -qE '\[paste #[0-9]+ \+[0-9]+ lines\]' && return 1
  return 0
}

# 「pane 忙吗」+ 守卫的合并判定（投递路径唯一的入口判定）：
#   NOPANE  = 窗口不在 → 不投、留在队列
#   SHELL   = 停在空提示符 → 绝不能打字（会被 shell 当命令执行；历史上真实事故）
#   BUSY / EMPTY / UNKNOWN = 交给守卫
team_delivery_verdict() { # <target> → NOPANE|SHELL|BUSY|EMPTY|UNKNOWN
  local target="${1:-}" sess
  [ -n "$target" ] || { printf 'NOPANE\n'; return 0; }
  sess="${target%%:*}"
  team_have_cmd tmux || { printf 'NOPANE\n'; return 0; }
  team_tmux_has_session "$sess" || { printf 'NOPANE\n'; return 0; }
  tmux display-message -p -t "$target" '#{pane_id}' >/dev/null 2>&1 || { printf 'NOPANE\n'; return 0; }
  team_pane_busy "$target" || { printf 'SHELL\n'; return 0; }
  team_input_box_state "$target"
}

# 打完字之后核对：输入框里是否**只有**我们这段（框在检查时刻是 EMPTY，即除了提示行没有可见文字）。
# 不许用长度启发式（V7-F2：真实 Pi v0.85.1 把大粘贴折叠成 `[paste #N +K lines]` 占位符，
# 可见字符数远小于 payload 长度，长度判据必然放行，人的草稿就这样被粘走）。判据（顺序敏感）：
#   1. 先逐字（去空白）：可见文字 == payload → 我们的。必须先于占位符剥除——payload 自己写着
#      "[paste #1 +3 lines]" 字样时，剥除路径会把原文剥出一个洞，误判「占位符 + 别人的字」
#      （V8-N2：干净消息被终态扣在 held/，框里留下一条没人提交的自动消息）；
#   2. 空框（粘贴没落上/已被收走）→ 按 Enter 无害；
#   3. 折叠占位符：仅当**整个框**就是一个占位符、且 +K == payload 行数时才算我们的——多于一个
#      占位符（人的粘贴也被折叠；V8-N4）或 K 对不上都不是「只有我们」；
#   4. 可见区是 payload 的前缀/后缀（滚动/截断的显示窗口；V8-N6 边界记录在案）；
#   5. 其它一律返回 1（竞态期间有人打字）→ 不按 Enter。
# 纯文本判据（不读 pane，输入 = team_input_box_text 的结果）：<框文本> <payload> → 0 = 只有我们这段。
team_box_text_holds_only() { # <got> <payload>
  local got="$1" want want_lines k
  want="$(printf '%s' "$2" | tr -d '[:space:]')"
  local gotnows; gotnows="$(printf '%s' "$got" | tr -d '[:space:]')"
  [ -n "$want" ] && [ "$gotnows" = "$want" ] && return 0
  [ -z "$gotnows" ] && return 0
  if printf '%s' "$got" | LC_ALL=C grep -qE '^[[:space:]]*\[paste #[0-9]+ \+[0-9]+ lines\][[:space:]]*$'; then
    k="$(printf '%s' "$got" | LC_ALL=C sed -n 's/^[[:space:]]*\[paste #[0-9][0-9]* +\([0-9][0-9]*\) lines\][[:space:]]*$/\1/p')"
    want_lines="$(printf '%s' "$2" | grep -c '')"
    [ -n "$k" ] && [ "$k" = "$want_lines" ] && return 0
    return 1
  fi
  [ "${want%"$gotnows"}" != "$want" ] && return 0   # 可见区是 payload 的后缀（滚动了）
  [ "${want#"$gotnows"}" != "$want" ] && return 0   # 可见区是 payload 的前缀（截断/横滚窗口）
  return 1
}

team_box_holds_only() { # <target> <payload>
  local got
  got="$(team_input_box_text "$1" 2>/dev/null)" || return 0   # 读不出来：按旧语义当「只有我们」（Enter 路径）
  team_box_text_holds_only "$got" "$2"
}

# M17：放弃 Enter 之前决定「收回还是一个键都不碰」。同一份框文本上判：
#   ① 逐字 / 单占位符 +K 对得上 / 前后缀窗口 / 空框 都是我们的（team_box_text_holds_only）；
#   ② 整框就是一个我们自己的半成品占位符帧（`[paste #N +M`，V8-N3 形状）——粘贴是我们打进去的，
#      框里没有第二个东西；
#   ③ 其它（混了人的字、两个占位符、读不出框）→ 不可收回（宁留不删）。
# 空框也算「可收回」= 没有残留；清键对空框是幂等空操作（team_tmux_retract 不会为它发键）。
team_box_retract_safe() { # <target> <payload> → 0 = 框里此刻只有我们打进去的东西
  local got
  got="$(team_input_box_text "$1" 2>/dev/null)" || return 1
  team_box_text_holds_only "$got" "$2" && return 0
  team_box_mid_render "$got"
}

# pane 是否请求了 bracketed paste（DECSET 2004）。tmux 的 paste-buffer -p 只在
# 应用请求过这个模式时才加包装（tmux 3.7 手册），所以这条要先问 tmux，不能假设。
team_pane_bracketed_paste() { # <target> → 0 = 支持
  [ "$(tmux display-message -p -t "$1" '#{bracket_paste_flag}' 2>/dev/null)" = "1" ]
}

# 多行 payload 的实际投递文本：
#  - 目标支持 bracketed paste（Pi 这类 TUI）→ 原样（paste-buffer -p 会把三行当一个输入框内容）；
#  - 不支持（非 Pi TUI）→ 按今天的规矩：多行落成文件，只打一行指针（绝不拆成多条提交）。
# 警告走 stderr，所以调用方可以用 $(...) 取文本。
team_deliver_text() { # <target> <payload> → stdout: 真正要打进去的文本
  local target="$1" payload="$2" f
  case "$payload" in
    *$'\n'*)
      if ! team_pane_bracketed_paste "$target"; then
        f="$(team_state_dir)/draft/multiline-$(team_epoch_ms)-$$.md"
        mkdir -p "$(dirname "$f")"
        printf '%s\n' "$payload" > "$f"
        team_warn "目标 TUI 没开 bracketed paste（DECSET 2004）：多行内容落成文件 $f，只打一行指针" >&2
        printf '（%s draft）多行消息已存到 %s：目标 TUI 不支持 bracketed paste，请读那个文件\n' "$TEAM_CLI" "$f"
        return 0
      fi ;;
  esac
  printf '%s\n' "$payload"
}

# ---------------------------------------------------------------- 打字（唯一实现）
# 单行用 send-keys -l（今天的行为）；多行用 load-buffer + paste-buffer -p
# （E3 §3.2 实测：不加 -p 三行会被拆成三条提交，加了才有一个输入框内容）。
team_tmux_type_payload() { # <target> <payload>
  local target="${1:-}" payload="$2" buf
  case "$payload" in
    *$'\n'*)
      buf="team-outbox-$$-$RANDOM"
      printf '%s' "$payload" | tmux load-buffer -b "$buf" - 2>/dev/null || return 1
      tmux paste-buffer -p -b "$buf" -d -t "$target" 2>/dev/null || { tmux delete-buffer -b "$buf" >/dev/null 2>&1 || true; return 1; }
      return 0 ;;
    *)
      tmux send-keys -t "$target" -l "$payload" 2>/dev/null ;;
  esac
}

# 收回（M17）：把**只有我们**的那段内容从框里清掉 —— 放弃按 Enter 时不许把字留在人的框里。
# 清法是 Pi 编辑器自己的键，不是外部猜测：ctrl+a（光标到行首）+ ctrl+k（删到行尾；已在行尾就把
# 下一行并上来），两个键成对重复 —— 无论光标停在哪一行哪一列都能清空（不是只有光标在末尾才行），
# 而且编辑器已经空的时候这对键是幂等的空操作（deleteToLineStart/End 在 (0,0) 处都不动）。
# 调用前提：team_box_retract_safe 刚确认框里只有我们打进去的东西；混了人的字一个键都不发。
# 空框直接返回 0，不写键；写完轮询确认框真的空了（渲染是异步的）——没确认就返回 1，由调用方
# 把条目留在 held/ 里并说明「框里仍有内容」。
team_tmux_retract() { # <target> → 0 = 框里不再有我们的内容；1 = 没收回/无法确认
  local target="${1:-}" i got keys=()
  team_tmux_target_required "retract" "$target" || return 1
  got="$(team_input_box_text "$target" 2>/dev/null || true)"
  [ -z "$(printf '%s' "$got" | tr -d '[:space:]')" ] && return 0   # 已经空了：没有残留要收
  for i in $(seq 1 24); do keys+=(C-a C-k); done
  tmux send-keys -t "$target" ${keys[@]+"${keys[@]}"} 2>/dev/null || return 1
  for i in 1 2 3 4 5 6; do
    sleep 0.2
    got="$(team_input_box_text "$target" 2>/dev/null || true)"
    [ -z "$(printf '%s' "$got" | tr -d '[:space:]')" ] && return 0
  done
  return 1
}

# 打字 + 守卫复检 + Enter + 指纹确认。返回：
#   0 已确认送达 ｜ 2 框里有草稿（一个键都没发，交给上层排队）｜ 3 放弃 Enter，框里混了人的字（一个键都没碰）
#   7 放弃 Enter，框里只有我们的内容 → 已收回（M17：清掉框里的残留，没按 Enter）
#   1 粘贴落上了但没确认（写了 Enter 而 pane 没变化 / Enter 没发出去）：payload 已进过框一次，终态
#   4 打字本身就失败（粘贴没落上）：payload 没碰过框，可以安全重试
#   5 渲染停顿超过等待上限（旧语义，仍被 process_entry 认作可恢复；M17 起新条目不再走它）
#   6 resume 重试时框里已不只有 payload：不重贴，留在 held/
team_tmux_deliver() { # <target> <payload> [--no-verify] [--assume-free] [--resume]
  local target="$1" payload="$2"; shift 2
  local noverify=0 assume_free=0 shape_known=1 resume=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --no-verify) noverify=1; shift ;;
      --assume-free) assume_free=1; shift ;;
      --resume) resume=1; shift ;;
      *) shift ;;
    esac
  done
  local v=""
  # 先算「真正要打进去的文本」（resume 的 holds_only 要按同一份文本判 +K 行数）与 pane 快照。
  local before text
  before="$(team_pane_snapshot "$target")"
  text="$(team_deliver_text "$target" "$payload")"
  if [ "$assume_free" != "1" ]; then
    v="$(team_delivery_verdict "$target")"
    case "$v" in
      BUSY)
        # resume（held/stall-timeout 的重试）：payload 上一轮已经贴进框但没按 Enter，
        # 框里恰好只有它 → 继续补 Enter（不重贴）；否则不投（留在 held/）。
        if [ "$resume" = "1" ]; then
          team_box_holds_only "$target" "$text" || return 2
        else
          return 2
        fi ;;
      UNKNOWN) shape_known=0; team_warn "输入框形状无法识别（$target）：按今天的行为投递，这次的守卫不生效" ;;
      SHELL|NOPANE) return 2 ;;
    esac
  else
    shape_known=0
    team_warn "输入框形状无法识别（$target）：按今天的行为投递，这次的守卫不生效"
  fi
  # resume（held/stall-timeout 的重试）：先看 payload 是不是还在框里。
  #   - 还在（verbatim 或 +K 对得上的折叠占位符）→ 不重贴，直接进 Enter 阶段补上上次没发的 Enter；
  #   - 不在 → 它已经进过人的框一次（可能随人的 Enter 提交了）→ 绝不重贴（V8-F4c），返回 6；
  #     「没投出去」与「投了两遍」之间选前者：条目留在 held/ 可见，由人核实后 drop 或重发。
  local resumed=0
  if [ "$resume" = "1" ] && [ "$assume_free" != "1" ] && [ "$shape_known" = "1" ]; then
    if team_box_holds_only "$target" "$text"; then
      resumed=1
    else
      return 6
    fi
  fi
  # V9-B5 基线：打字前对话区里 payload 特征串（与匹配 +K 折叠占位符）的出现次数。
  # 送达的确认不再看「payload 离开输入框」（TUI 吞掉 Enter 也会清空框），而看「对话区里
  # 特征串出现次数变多」（真实 TUI 提交后消息进气泡区；清空只是消失）。
  local ev_slice ev_k ev_base=0
  ev_slice="$(team_payload_slice "$text")"
  ev_k="$(printf '%s' "$text" | grep -c '')"
  if [ "$shape_known" = "1" ] && [ "$noverify" != "1" ]; then
    ev_base="$(team_transcript_mentions "$target" "$ev_slice" "$ev_k")"
  fi
  if [ "$resumed" != "1" ]; then
    team_tmux_type_payload "$target" "$text" || return 4
  fi
  # Enter 之前的最后一次复检（spec：check → paste 之间的草稿要拦住，不能粘出去）。
  # 不能刚打完就判：TUI 是异步渲染的（真 Pi 折叠、夹具逐键），判据要落在「停下来的框」上——
  # 连续两次读到相同内容才算停；还在变就等一拍；4 拍还停不下来按竞态处理（保守 = 不按 Enter）。
  if [ "$shape_known" = "1" ]; then
    local prev="<unset>" tries=0 extra=0 stalled=0 now_txt want_nowsp
    want_nowsp="$(printf '%s' "$text" | tr -d '[:space:]')"
    while [ "$tries" -lt 4 ]; do
      sleep 0.2
      now_txt="$(team_input_box_text "$target" 2>/dev/null || true)"
      # payload 已逐字进框 = 渲染完成——哪怕 payload 自己写着半成品占位符字样
      # （V9-B1：那样的干净消息被中间帧判据永远等不到停、终态扣住）。先查逐字再查中间帧。
      if printf '%s' "$now_txt" | tr -d '[:space:]' | grep -qF "$want_nowsp"; then break; fi
      if team_box_mid_render "$now_txt"; then
        # 半成品占位符帧：不是「停下来了」也不是「别人的字」（V8-N3）——继续等渲染完成，
        # 最多多等 8 拍（≈1.6s）。等完还画不完不是竞态（V9-B6）：帧一直是我们的粘贴在渲染，
        # 消息不该被终态扣住 → stalled 标上，交给「可恢复的 stall-timeout」（见下）。
        extra=$((extra + 1))
        [ "$extra" -ge 8 ] && { stalled=1; tries=4; break; }
        prev="$now_txt"
        continue
      fi
      [ "$now_txt" = "$prev" ] && break
      prev="$now_txt"; tries=$((tries + 1))
    done
    if [ "$tries" -ge 4 ] || ! team_box_holds_only "$target" "$text"; then
      # 调查用的取证钩子（默认关）
      if [ -n "${TEAM_RESUME_DEBUG:-}" ]; then
        printf 'RS resumed=%s tries=%s stalled=%s holds=%s box=[%s] text=[%s]\n' "$resumed" "$tries" "$stalled" \
          "$(team_box_holds_only "$target" "$text" && printf y || printf n)" \
          "$(printf '%s' "$now_txt" | tr '\n' '|')" "$(printf '%s' "$text" | tr '\n' '|')" >> "$TEAM_RESUME_DEBUG"
      fi
      # M17：放弃 Enter 之前先「收回」——不许把我们打进去的字留在人的框里。
      # 收回的前提是**此刻**框里只有我们打进去的东西（逐字/折叠/前后缀窗口，或整框一个我们自己的
      # 半成品帧）；混进了人的字就一个键都不碰（宁留不删）。收回成功 → rc 7（框已清空）；
      # 收回失败（键被吞/形状变了）→ rc 3（框里仍有内容，绝不再发键）。
      if team_box_retract_safe "$target" "$text"; then
        if team_tmux_retract "$target"; then
          team_warn "Enter 前复检没能确认框里只有我们的 payload（$target）：已收回打进去的内容，条目转入 outbox/held/（框里已清空）"
          return 7
        fi
        team_warn "Enter 前复检没能确认框里只有我们的 payload（$target）：收回没成功（框里仍有内容）→ 一个键都不再发，消息转入 outbox/held/"
        return 3
      fi
      team_warn "打字期间输入框里多了别人的文字（$target）：框里已有人的内容，未动；不发 Enter，消息转入 outbox/held/"
      return 3
    fi
  fi
  tmux send-keys -t "$target" Enter 2>/dev/null || return 1
  [ "$noverify" = "1" ] && return 0
  # 投递确认（V9-B5）：「payload 离开输入框」**本身不算送达**——TUI 吞掉 Enter（覆盖层/转义
  # 处理/重绘）同样把框清空，旧判据在那条形状下报「已确认送达」并删除条目，消息不可恢复地丢。
  # 送达 = 框空（或只剩别人新打的字）**且** 对话区里 payload 的证据数比打字前多（真实 TUI
  # 提交后消息进气泡区；清空只是消失）。没有提交证据 → 返回 1：立即终态 held/（永不删除、
  # 永不重贴；持久副本随 hold 落进收件箱）。只有框形状读不出来（UNKNOWN）时才退回尾部指纹。
  local i after st extra=0
  for i in 1 2 3 4 5 6; do
    sleep 0.3
    if [ "$shape_known" = "1" ]; then
      st="$(team_input_box_state "$target" 2>/dev/null || printf 'UNKNOWN\n')"
      if [ -n "${TEAM_DELIVER_DEBUG:-}" ]; then
        # 调查用的取证钩子（默认关）：每拍记下框状态与证据计数
        printf 'poll=%s st=%s mentions=%s base=%s slice=[%s] k=%s\n' "$i" "$st" \
          "$(team_transcript_mentions "$target" "$ev_slice" "$ev_k")" "$ev_base" "$ev_slice" "$ev_k" >> "$TEAM_DELIVER_DEBUG"
      fi
      case "$st" in
        EMPTY)
          # 框空了不算数：要看到对话区里多出一份我们的 payload（气泡/折叠气泡）才算送达
          [ "$(team_transcript_mentions "$target" "$ev_slice" "$ev_k")" -gt "$ev_base" ] && return 0 ;;
        BUSY)
          if team_box_holds_only "$target" "$text"; then
            # 框里还只有我们这段（含折叠占位符独占）：Enter 被吞了 → 从第 2 拍起至多补一次（规格）
            if [ "$extra" = "0" ] && [ "$i" -ge 2 ]; then
              tmux send-keys -t "$target" Enter 2>/dev/null || true
              extra=1
            fi
          else
            local cbox craw ptext
            craw="$(team_input_box_text "$target" 2>/dev/null || true)"
            cbox="$(printf '%s' "$craw" | tr -d '[:space:]')"
            ptext="$(printf '%s' "$text" | tr -d '[:space:]')"
            if printf '%s' "$craw" | LC_ALL=C grep -q '\\[paste #[0-9][0-9]* +[0-9][0-9]* lines\\]'; then
              # 折叠占位符还在 = 我们的粘贴还在框里（verbatim 比对对折叠框无效），旁边多了
              # 别人的字 → 再按 Enter 会粘出去 → 部分投递，转 held（终态）
              team_warn "确认期间输入框里多了别人的文字（$target）：不再按 Enter，消息转入 outbox/held/"
              return 3
            elif printf '%s' "$cbox" | LC_ALL=C grep -qF "$ptext"; then
              # 框里 = 我们的 payload + 别人的字：同上，不再按 Enter
              team_warn "确认期间输入框里多了别人的文字（$target）：不再按 Enter，消息转入 outbox/held/"
              return 3
            else
              # 框里只剩别人的字、我们的 payload 出框了——仍要提交证据才算送达（V9-B5：
              # 人也可能清框后自己打字，那条形状下 payload 从没提交）
              [ "$(team_transcript_mentions "$target" "$ev_slice" "$ev_k")" -gt "$ev_base" ] && return 0
            fi
          fi ;;
        UNKNOWN)
          after="$(team_pane_snapshot "$target")"
          [ "$after" != "$before" ] && return 0 ;;
      esac
    else
      after="$(team_pane_snapshot "$target")"
      [ "$after" != "$before" ] && return 0
      [ "$i" = "2" ] && { tmux send-keys -t "$target" Enter 2>/dev/null || true; }
    fi
  done
  return 1
}

# ---------------------------------------------------------------- 队列：文件即契约
# $TEAM_STATE_DIR/outbox/<epoch-ms>-<seq>-<target>.msg
#   kind: say|notify|nudge|knock|draft
#   target: <session:window>
#   from: <谁发的>
#   created: <ISO8601>
#   dedup: <去重键，或 ->
#   ---
#   <payload 原文>
# 不可变：写 tmp + rename；只有排水/掉队才会移动它（held/ 保持同名，FIFO 不变）。
team_outbox_dir() { mkdir -p "$TEAM_STATE_DIR/outbox"; printf '%s\n' "$TEAM_STATE_DIR/outbox"; }
team_outbox_held_dir() { mkdir -p "$TEAM_STATE_DIR/outbox/held"; printf '%s\n' "$TEAM_STATE_DIR/outbox/held"; }
# 日志函数的目录也要先建：--now 可能在队列目录还不存在时就写 forced.log（实测：`printf >>` 失败
# 会让整个 send 在 set -e 下静默中止，一个键都没打）
team_outbox_delivered_log() { mkdir -p "$TEAM_STATE_DIR/outbox"; printf '%s\n' "$TEAM_STATE_DIR/outbox/delivered.log"; }
team_outbox_holding_log() { mkdir -p "$TEAM_STATE_DIR/outbox"; printf '%s\n' "$TEAM_STATE_DIR/outbox/HOLDING.log"; }

team_outbox_hold_reason() { # <entry> → HOLDING.log 里最后一次原因（没有则 -）
  local base r
  base="$(basename "$1")"
  r="$(grep -s "name=$base " "$(team_outbox_holding_log)" | tail -1 | sed -n 's/.*reason=\([^ ]*\).*/\1/p' || true)"
  printf '%s\n' "${r:--}"
}
team_outbox_forced_log() { mkdir -p "$TEAM_STATE_DIR/outbox"; printf '%s\n' "$TEAM_STATE_DIR/outbox/forced.log"; }

# 队列锁（mkdir 原子；拿不到就回收陈旧锁再试）。所有写队列的动作都拿它。
team_outbox_lock() {
  local dir tries=0
  dir="$(team_outbox_dir)/.lock"
  while ! mkdir "$dir" 2>/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -gt 100 ]; then
      rmdir "$dir" 2>/dev/null || true
      mkdir "$dir" 2>/dev/null && return 0
      return 1
    fi
    sleep 0.05
  done
  return 0
}
team_outbox_unlock() { rmdir "$(team_outbox_dir)/.lock" 2>/dev/null || true; }

team_outbox_header() { # <entry> <field>
  LC_ALL=C awk -v k="$2" '
    $0 == "---" { exit }
    { p=index($0, ": "); if (p > 0 && substr($0,1,p-1) == k) { print substr($0, p+2); exit } }' "$1"
}

team_outbox_payload() { # <entry> → payload（尾部换行会被命令替换 strip，投递时正是要的）
  LC_ALL=C awk 'seen { print } $0 == "---" { seen=1 }' "$1"
}

# 排队的条目（活动 + held，按文件名 FIFO 合并）
team_outbox_entries() {
  local dir; dir="$(team_outbox_dir)"
  { find "$dir" -maxdepth 1 -name '*.msg' -type f 2>/dev/null
    find "$dir/held" -maxdepth 1 -name '*.msg' -type f 2>/dev/null
  } | LC_ALL=C awk -F/ '{print $NF"\t"$0}' | LC_ALL=C sort | cut -f2-
}

team_outbox_active_entries() { find "$(team_outbox_dir)" -maxdepth 1 -name '*.msg' -type f 2>/dev/null | LC_ALL=C sort; }
team_outbox_count() { team_outbox_entries | grep -c . 2>/dev/null || true; }
team_outbox_active_count() { team_outbox_active_entries | grep -c . 2>/dev/null || true; }
team_outbox_held_count() { find "$(team_outbox_dir)/held" -maxdepth 1 -name '*.msg' -type f 2>/dev/null | grep -c . 2>/dev/null || true; }
team_outbox_is_held() { case "$1" in */held/*) return 0 ;; *) return 1 ;; esac; }

# held 条目按「框里的残留」分档（M17）：*retracted* = 我们打进去的已收回（框里无残留）；
# *left* = 没收（框里还有人的字或收回失败，宁留不删）；其它 = 从未进过框的 hold（TTL/cap/no-target）
# 或收不回但已投过 Enter 的 unconfirmed。输出 "<retracted> <left> <other>"。
team_outbox_held_residue_counts() {
  local e r retracted=0 left=0 other=0
  while IFS= read -r e; do
    [ -n "$e" ] || continue
    team_outbox_is_held "$e" || continue
    r="$(team_outbox_hold_reason "$e")"
    case "$r" in
      *retracted*) retracted=$((retracted + 1)) ;;
      *left*)      left=$((left + 1)) ;;
      *)           other=$((other + 1)) ;;
    esac
  done < <(team_outbox_entries)
  printf '%s %s %s\n' "$retracted" "$left" "$other"
}

# 可见性：status/digest 共用的一行（队列为空时返回 1，调用方不打印任何东西）。
# M17：held 非空时把「已收回 / 留在框里」的分档带在同一行 —— 人不该为了知道框里有没有残留
# 去翻 HOLDING.log。
team_outbox_status_line() { # [前缀]
  local n held oldest age detail retracted left other
  n="$(team_outbox_count)"
  case "${n:-0}" in ''|*[!0-9]*) n=0 ;; esac
  [ "$n" -gt 0 ] || return 1
  held="$(team_outbox_held_count)"
  case "${held:-0}" in ''|*[!0-9]*) held=0 ;; esac
  oldest="$(team_outbox_entries | head -1)"
  age="$(team_entry_age_sec "$oldest")"
  detail="held $held"
  if [ "$held" -gt 0 ]; then
    read -r retracted left other <<< "$(team_outbox_held_residue_counts)"
    if [ "$((retracted + left))" -gt 0 ]; then
      detail="$detail：已收回 $retracted · 留在框里 $left"
      [ "${other:-0}" -gt 0 ] && detail="$detail · 其它 $other"
    fi
  fi
  printf '%soutbox %s 条待投递（%s）· 最老 %ss · %s outbox list\n' "${1:-}" "$n" "$detail" "$age" "$TEAM_CLI"
  return 0
}

# 陈旧 claim（进程被 kill 留下的空目录）回收
team_outbox_reap_claims() {
  find "$(team_outbox_dir)" -maxdepth 2 -name '*.claim' -type d -mmin +10 -exec rmdir {} + 2>/dev/null || true
}

team_outbox_claim() { mkdir "$1.claim" 2>/dev/null; }
team_outbox_release() { rmdir "$1.claim" 2>/dev/null || true; }

# 去重：同一个 key 在 排队/held/最近投递 里出现过 → 0
team_outbox_dedup_hit() { # <key> <window-sec>
  local key="${1:-}" win="${2:-20}" e f now line ts k
  [ -n "$key" ] || return 1
  while IFS= read -r e; do
    [ -n "$e" ] || continue
    [ "$(team_outbox_header "$e" dedup)" = "$key" ] && return 0
  done < <(team_outbox_entries)
  f="$(team_outbox_delivered_log)"
  [ -f "$f" ] || return 1
  now="$(team_epoch_sec)"
  while IFS=$'\t' read -r ts k _name _outcome; do
    [ "$k" = "$key" ] || continue
    case "$ts" in ''|*[!0-9]*) continue ;; esac
    [ $(( now - ts )) -le "$win" ] && return 0
  done < <(tail -n 200 "$f" 2>/dev/null || true)
  return 1
}

team_outbox_record_delivered() { # <entry> <dedup> <outcome>
  local k="${2:--}"
  printf '%s\t%s\t%s\t%s\n' "$(team_epoch_sec)" "$k" "$(basename "$1")" "$3" >> "$(team_outbox_delivered_log)"
}

# 掉队：条目移进 held/（保持同名 → FIFO 不变），HOLDING.log 记一行（含 hold 时刻与尝试次数）
team_outbox_hold() { # <entry> <reason> [--claimed]
  local e="$1" why="${2:--}" claimed="${3:-}" held attempts t base ib
  [ -f "$e" ] || return 0
  # 别的进程正在投它（claim 目录存在）时不动它：让那一轮走完，下一拍再处理
  if [ "$claimed" != "--claimed" ] && [ -d "$e.claim" ]; then return 0; fi
  held="$(team_outbox_held_dir)"
  base="$(basename "$e")"
  attempts="$(grep -c "name=$base " "$(team_outbox_holding_log)" 2>/dev/null || true)"
  case "$attempts" in ''|*[!0-9]*) attempts=0 ;; esac
  attempts=$((attempts + 1))
  t="$(team_outbox_header "$e" target)"
  if ! team_outbox_is_held "$e"; then
    # V7-F5：入队时选了「延迟写收件箱」（--inbox-defer）的条目，在第一次真正进 held/ 的时刻
    # 把 durable 记录落盘 —— 从此它确实是「投不出去、只活在队列里」的消息了（规格 R5）。
    ib="$(team_outbox_header "$e" inbox)"
    if [ -n "$ib" ] && [ "$ib" != "-" ] && [ -z "$(team_outbox_header "$e" inbox-written)" ]; then
      team_inbox_append "$ib" "queued" "$(team_outbox_payload "$e")"
    fi
    mv -f "$e" "$held/$base" 2>/dev/null || return 0
  fi
  printf '%s name=%s reason=%s held-since=%s attempts=%s target=%s\n' \
    "$(team_timestamp)" "$base" "$why" "$(team_timestamp)" "$attempts" "${t:--}" >> "$(team_outbox_holding_log)"
  return 0
}

# 入队。返回 0 = 写入（stdout 打印 entry 路径）；3 = 重复（stdout 打印 duplicate）
# 参数：--kind K --target T [--from F] [--dedup K] [--from-file FILE | --payload TEXT]
#        [--inbox AGENT]（先落 durable 收件箱行，TTL 之后消息也不会只活在队列里）
team_outbox_enqueue() {
  local kind="" target="" from="-" dedup="" file="" payload="" payload_set=0 inbox="" inbox_defer=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --kind) kind="${2:?}"; shift 2 ;;
      --target) target="${2:?}"; shift 2 ;;
      --from) from="${2:?}"; shift 2 ;;
      --dedup) dedup="${2:?}"; shift 2 ;;
      --from-file) file="${2:?}"; shift 2 ;;
      --payload) payload="${2:-}"; payload_set=1; shift 2 ;;
      --inbox) inbox="${2:?}"; shift 2 ;;
      --inbox-defer) inbox_defer="${2:?}"; shift 2 ;;
      --durable) shift 2 ;;
      *) shift ;;
    esac
  done
  [ -n "$kind" ] && [ -n "$target" ] || team_die "outbox enqueue：需要 --kind 和 --target"
  if [ -n "$file" ]; then
    [ -f "$file" ] || team_die "outbox enqueue --from-file：文件不存在（$file）"
    payload="$(cat "$file")"
    payload_set=1
  fi
  [ "$payload_set" = "1" ] || team_die "outbox enqueue：需要 --from-file 或 --payload"
  [ -n "$(printf '%s' "$payload" | tr -d '[:space:]')" ] || team_die "outbox enqueue：payload 不能是空白"

  local dir; dir="$(team_outbox_dir)"
  if [ -n "$dedup" ] && team_outbox_dedup_hit "$dedup" "$(team_dedup_sec)"; then
    printf 'duplicate\n'
    return 3
  fi
  # durable 记录先落盘：条目可以在 TTL 之后被 hold，但消息本身绝不能只活在队列里。
  # V7-F5：--inbox 立即写（调用方已知这条消息要排队）；--inbox-defer 只记 inbox: 头，
  # 等条目真的进 held/ 那一刻才由 team_outbox_hold 落盘 —— 已确认送达的消息不写收件箱，
  # 不制造「自己叫醒自己」的假待办。
  [ -n "$inbox" ] && team_inbox_append "$inbox" "queued" "$payload"

  team_outbox_lock || team_die "outbox enqueue：拿不到队列锁（$dir/.lock）"
  local ms seq name tmp i
  ms="$(team_epoch_ms)"
  seq=0
  name=""
  for i in $(seq 1 200); do
    seq=$((seq + 1))
    name="$(printf '%s-%04d-%s.msg' "$ms" "$seq" "$(printf '%s' "$target" | tr -c 'A-Za-z0-9._:-' '_')")"
    [ -e "$dir/$name" ] || break
  done
  tmp="$dir/.$name.tmp"
  {
    printf 'kind: %s\n' "$kind"
    printf 'target: %s\n' "$target"
    printf 'from: %s\n' "$from"
    printf 'created: %s\n' "$(team_timestamp)"
    printf 'dedup: %s\n' "${dedup:--}"
    if [ -n "$inbox" ]; then
      printf 'inbox: %s\n' "$inbox"
      printf 'inbox-written: 1\n'
    elif [ -n "$inbox_defer" ]; then
      printf 'inbox: %s\n' "$inbox_defer"
    fi
    printf -- '---\n'
    printf '%s\n' "$payload"
  } > "$tmp" || { team_outbox_unlock; team_die "outbox enqueue：写临时文件失败（$tmp）"; }
  mv -f "$tmp" "$dir/$name" || { team_outbox_unlock; team_die "outbox enqueue：rename 失败（$dir/$name）"; }
  team_outbox_unlock

  # 上限（TEAM_OUTBOX_MAX，默认 200）：超了就把**最老**的活动条目升级成 held（cap 事件必须可见）
  local max oldest
  max="$(team_outbox_max)"
  while [ "$(team_outbox_active_count)" -gt "$max" ]; do
    oldest="$(team_outbox_active_entries | head -1)"
    [ -n "$oldest" ] || break
    team_outbox_hold "$oldest" "cap"
    team_warn "outbox 超过上限 TEAM_OUTBOX_MAX=$max：最老的条目转入 held/（$(basename "$oldest")）"
  done
  printf '%s\n' "$dir/$name"
  return 0
}

# 强制投递（--now）：故意重建今天的行为（往有草稿的框里打字），但留一条审计
team_outbox_force_log() { # <target> <kind> <from> <entry>
  printf '%s kind=%s from=%s target=%s entry=%s\n' "$(team_timestamp)" "$2" "$3" "$1" \
    "$(basename "${4:-none}")" >> "$(team_outbox_forced_log)"
}

# ---------------------------------------------------------------- 排水（唯一的投递路径）
# 处理一个条目。设置 TEAM_OUTBOX_RESULT=delivered|held|queued|busy|skip|offline
team_outbox_note() { # <ok|warn|plain> <文本>：--quiet 时整段静音（警告也走 stdout，才能被 quiet 压住）
  [ "${TEAM_OUTBOX_QUIET:-0}" = "1" ] && return 0
  case "${1:-plain}" in
    ok)   shift; team_ok "$*" ;;
    warn) shift; team_warn "$*" ;;
    *)    shift; printf '%s\n' "$*" ;;
  esac
}

team_outbox_process_entry() { # <entry> [--now] [--no-verify]
  local e="$1"; shift
  local now=0 noverify=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --now) now=1; shift ;;
      --no-verify) noverify=1; shift ;;
      *) shift ;;
    esac
  done
  TEAM_OUTBOX_RESULT="skip"
  local target kind from dedup age ttl payload v rc=0 resume=0
  target="$(team_outbox_header "$e" target)"
  kind="$(team_outbox_header "$e" kind)"
  from="$(team_outbox_header "$e" from)"
  dedup="$(team_outbox_header "$e" dedup)"
  [ -n "$target" ] || { team_outbox_hold "$e" "no-target"; TEAM_OUTBOX_RESULT="held"; return 0; }
  team_outbox_claim "$e" || return 0            # 并发的另一个排水已经在投它

  # V7-F3 跳投递去重：draft-raced（以及 M17 的 draft-raced-left / draft-raced-retracted）/ unconfirmed
  # 的条目 = payload 已经进过人的框一次（可能随人的提交到了 agent——unconfirmed 是 Enter 被吞后框里卡着我们
  # 的 payload，人随后自己的 Enter 就把它提交了，下一次排水再贴一遍就是同一 payload 到两遍：V8-F4c）。
  # 它们是**终态**：留在 held/ 可见，durable 副本在收件箱；要重发请显式再 say/draft send，要丢弃用 outbox drop。
  if team_outbox_is_held "$e"; then
    case "$(team_outbox_hold_reason "$e")" in
      draft-raced|draft-raced-*|unconfirmed)
        team_outbox_note warn "outbox：$(basename "$e") 是 $(team_outbox_hold_reason "$e") 终态（payload 已进过人的框一次，绝不重复粘贴）→ 留在 held/"
        TEAM_OUTBOX_RESULT="terminal"
        team_outbox_release "$e"
        return 0 ;;
    esac
  fi

  payload="$(team_outbox_payload "$e")"
  age="$(team_entry_age_sec "$e")"; ttl="$(team_defer_ttl)"


  # stall-timeout（V9-B6）是**可恢复的**：payload 已进框但没按 Enter（渲染停顿超过等待上限）。
  # 下次排水只补 Enter（--resume：框里恰好只有它时继续，绝不重贴）；条件不满足就留在 held/。
  # 必须在 verdict/BUSY 分支之前算好：BUSY 的 resume 分支要看它决定「继续投」还是「留在 held/」。
  if team_outbox_is_held "$e" && [ "$(team_outbox_hold_reason "$e")" = "stall-timeout" ]; then resume=1; fi

  if [ "$now" = "1" ]; then
    team_outbox_force_log "$target" "$kind" "$from" "$e"
    team_warn "--now：跳过守卫，直接往 $target 打字（今天的旧行为，已记入 outbox/forced.log）"
    team_tmux_type_payload "$target" "$(team_deliver_text "$target" "$payload")" 2>/dev/null || true
    tmux send-keys -t "$target" Enter 2>/dev/null || true
    rm -f "$e"
    team_outbox_record_delivered "$e" "$dedup" "forced"
    team_outbox_release "$e"
    team_outbox_note ok "outbox：--now 已投递 $(basename "$e") → $target"
    TEAM_OUTBOX_RESULT="delivered"
    return 0
  fi

  v="$(team_delivery_verdict "$target")"
  case "$v" in
    NOPANE|SHELL)
      # 目标不在跑：不投、不删。TTL 到了就 hold（消息的 durable 记录早就写了）
      if [ "$age" -ge "$ttl" ]; then
        team_outbox_hold "$e" "expired-$(printf '%s' "$v" | tr 'A-Z' 'a-z')" --claimed
        team_outbox_note warn "outbox：$(basename "$e") 目标不可投递（$v）且超过 TTL=$(team_defer_ttl)s → held/"
        TEAM_OUTBOX_RESULT="held"
      else
        TEAM_OUTBOX_RESULT="offline"
      fi
      team_outbox_release "$e"
      return 0 ;;
    BUSY)
      # stall-timeout 的重试（resume）：框里应当是我们的折叠占位符——不进这个分支的
      # 「有别人的草稿」处理，交给下面的投递路径（它自己用 holds_only 判框里是不是我们）。
      if [ "$resume" != "1" ]; then
        if [ "$age" -ge "$ttl" ]; then
          team_outbox_hold "$e" "expired-ttl" --claimed
          team_outbox_note warn "outbox：$(basename "$e") 输入框一直有草稿且超过 TTL=$(team_defer_ttl)s → held/"
          TEAM_OUTBOX_RESULT="held"
        else
          TEAM_OUTBOX_RESULT="busy"
        fi
        team_outbox_release "$e"
        return 0
      fi ;;
  esac

  # EMPTY（或 UNKNOWN = 按今天的行为投递）
  if [ "$v" = "UNKNOWN" ]; then
    team_tmux_deliver "$target" "$payload" --assume-free --no-verify || rc=$?
  elif [ "$noverify" = "1" ]; then
    team_tmux_deliver "$target" "$payload" --no-verify || rc=$?
  elif [ "$resume" = "1" ]; then
    team_tmux_deliver "$target" "$payload" --resume || rc=$?
  else
    team_tmux_deliver "$target" "$payload" || rc=$?
  fi
  case "$rc" in
    0)
      rm -f "$e"
      team_outbox_record_delivered "$e" "$dedup" "delivered"
      team_outbox_note ok "outbox：已投递 $(basename "$e") → $target"
      TEAM_OUTBOX_RESULT="delivered" ;;
    2)
      if [ "$resume" = "1" ]; then
        # stall-timeout 重试时框里不只有我们的 payload（人上手了/形状变了）→ 不投，留在 held/
        team_outbox_note warn "outbox：$(basename "$e") stall-timeout 重试：框里不只有我们的 payload → 留在 held/ 等人工核实"
        TEAM_OUTBOX_RESULT="held"
      else
        # 打字前又变忙了：一个键都没发，留在队列里（不是 held）
        team_outbox_note warn "outbox：$(basename "$e") 的目标在打字前又变成有草稿 → 留在队列"
        TEAM_OUTBOX_RESULT="busy"
      fi ;;
    3)
      team_outbox_hold "$e" "draft-raced-left" --claimed
      team_outbox_note warn "outbox：$(basename "$e") 打字期间有草稿介入（没有按 Enter，框里已有人的内容，未动）→ held/"
      TEAM_OUTBOX_RESULT="held" ;;
    7)
      # M17：复检失败但框里只有我们的内容（或只剩我们的半成品帧）——已收回，框里没有残留。
      # 收回同样是终态：payload 进过框一次，人自己的 Enter 可能在收回前提交过它（或收回的键序与人的
      # 按键交错），自动重贴有双发风险。
      team_outbox_hold "$e" "draft-raced-retracted" --claimed
      team_outbox_note warn "outbox：$(basename "$e") 复检失败后已收回框里的 payload（没有按 Enter，框里无残留）→ held/"
      TEAM_OUTBOX_RESULT="held" ;;
    1)
      # 投递未确认：payload 已经进过框一次（粘贴发生了），人之后的 Enter 可能已把它提交——再自动
      # 重贴就是第二次投递（V8-F4c）。规格逐字要求立即进 held/（V8-F4b：不能等 TTL），且与
      # draft-raced 同为终态（排水永不重贴，flush --now 也不例外）。
      team_outbox_hold "$e" "unconfirmed" --claimed
      team_outbox_note warn "outbox：$(basename "$e") 投递未确认（payload 已进框一次，终态，绝不重贴）→ held/"
      TEAM_OUTBOX_RESULT="held" ;;
    4)
      # 打字本身就失败（粘贴没落上）：payload 没碰过框，留在队列里重试是安全的
      team_outbox_note warn "outbox：$(basename "$e") 打字失败（粘贴没落上）→ 留在队列重试"
      TEAM_OUTBOX_RESULT="queued" ;;
    5)
      # V9-B6：渲染停顿超过等待上限——payload 已进框一次、Enter 没发。不是竞态，**不是终态**：
      # 原因记 stall-timeout，下个排水周期用 --resume 只补 Enter（绝不重贴）。
      team_outbox_hold "$e" "stall-timeout" --claimed
      team_outbox_note warn "outbox：$(basename "$e") 渲染停顿超过等待上限（payload 已进框、未发 Enter）→ held/（stall-timeout，下次排水只补 Enter）"
      TEAM_OUTBOX_RESULT="held" ;;
    6)
      # V9-B6 的 resume 失败分支：payload 已经不在框里（可能随人的 Enter 提交了）。
      # 绝不重贴（V8-F4c）——留在 held/ 可见，由人核实后 drop 或重发。
      team_outbox_note warn "outbox：$(basename "$e") stall-timeout 重试时 payload 已不在框里（可能已提交）→ 不再重贴，留在 held/ 等人工核实"
      TEAM_OUTBOX_RESULT="held" ;;
    *)
      if [ "$age" -ge "$ttl" ]; then
        team_outbox_hold "$e" "unconfirmed" --claimed
        team_outbox_note warn "outbox：$(basename "$e") 投递未确认且超过 TTL → held/"
        TEAM_OUTBOX_RESULT="held"
      else
        team_outbox_note warn "outbox：$(basename "$e") 投递未确认 → 留在队列重试"
        TEAM_OUTBOX_RESULT="queued"
      fi ;;
  esac
  team_outbox_release "$e"
  return 0
}

# 排水：所有调用者唯一入口（sender 的有界重试 / watchdog 一拍一次 / team outbox flush）
team_outbox_drain() { # [--now] [--quiet] [--max N]
  local now=0 quiet=0 max=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --now) now=1; shift ;;
      --quiet) quiet=1; shift ;;
      --max) max="${2:?}"; shift 2 ;;
      *) shift ;;
    esac
  done
  team_outbox_reap_claims
  TEAM_OUTBOX_QUIET=$quiet
  local e n=0 delivered=0 held=0
  while IFS= read -r e; do
    [ -n "$e" ] || continue
    [ -f "$e" ] || continue
    n=$((n + 1))
    [ "$max" -gt 0 ] && [ "$n" -gt "$max" ] && break
    if [ "$now" = "1" ]; then
      team_outbox_process_entry "$e" --now
    else
      team_outbox_process_entry "$e"
    fi
    case "$TEAM_OUTBOX_RESULT" in
      delivered) delivered=$((delivered + 1)) ;;
      held)      held=$((held + 1)) ;;
    esac
  done < <(team_outbox_entries)
  TEAM_OUTBOX_LAST_DELIVERED="$delivered"
  [ "$delivered" -gt 0 ] && team_outbox_note ok "outbox：投递 $delivered 条"
  return 0
}

# ---------------------------------------------------------------- 守卫 + 队列的对外入口
# 所有「往 TUI 输入框打字」的发送方都走这里。设置 TEAM_SEND_OUTCOME：
#   delivered（已确认送达）｜queued（进队列了）｜forced（--now）｜unknown-sent｜unknown-failed｜offline｜duplicate
team_send_guarded() { # <target> <payload> <kind> [--from F] [--dedup K] [--inbox A] [--now] [--no-verify]
  local target="$1" payload="$2" kind="$3"; shift 3
  local from="-" dedup="" inbox="" now=0 noverify=0 queue_offline=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --from) from="${2:-}"; shift 2 ;;
      --dedup) dedup="${2:-}"; shift 2 ;;
      --inbox) inbox="${2:-}"; shift 2 ;;
      --now) now=1; shift ;;
      --no-verify) noverify=1; shift ;;
      --queue-offline) queue_offline=1; shift ;;
      *) shift ;;
    esac
  done
  TEAM_SEND_OUTCOME=""
  local entry="" rc=0 v=""

  if [ "$now" = "1" ]; then
    team_outbox_force_log "$target" "$kind" "$from"
    team_warn "--now：跳过守卫，直接往 $target 打字（今天的旧行为，已记入 outbox/forced.log）"
    local before="" i after="" text
    text="$(team_deliver_text "$target" "$payload")"
    [ "$noverify" = "1" ] || before="$(team_pane_snapshot "$target")"
    team_tmux_type_payload "$target" "$text" || true
    tmux send-keys -t "$target" Enter 2>/dev/null || true
    if [ "$noverify" != "1" ]; then
      for i in 1 2 3 4; do
        sleep 0.3
        after="$(team_pane_snapshot "$target")"
        [ "$after" != "$before" ] && break
        [ "$i" = "2" ] && tmux send-keys -t "$target" Enter 2>/dev/null || true
      done
    fi
    TEAM_SEND_OUTCOME="forced"
    return 0
  fi

  # 入队的参数只构造一次：离线也排队（--queue-offline）和正常路径共用同一份参数
  local enq=(--kind "$kind" --target "$target" --from "$from")
  [ -n "$dedup" ] && enq+=(--dedup "$dedup")
  [ -n "$inbox" ] && enq+=(--inbox "$inbox")
  enq+=(--payload "$payload")

  v="$(team_delivery_verdict "$target")"
  case "$v" in
    SHELL|NOPANE)
      if [ "$queue_offline" = "1" ]; then
        # 目标没在跑，但消息是人的（草稿/敲门）：排队等它回来，同时落 durable 记录
        entry="$(team_outbox_enqueue "${enq[@]}")" || true
        if [ -n "$entry" ] && [ -f "$entry" ]; then
          TEAM_SEND_OUTCOME="queued"
        else
          TEAM_SEND_OUTCOME="offline"
        fi
        return 0
      fi
      TEAM_SEND_OUTCOME="offline"
      return 1 ;;
    UNKNOWN)
      # 形状未知：按今天的行为投递（一次警告），队列里不留条目 —— 守卫没有证据，就不假装有
      team_tmux_deliver "$target" "$payload" --assume-free --no-verify || rc=$?
      if [ "$rc" = "0" ]; then TEAM_SEND_OUTCOME="unknown-sent"; return 0; fi
      TEAM_SEND_OUTCOME="unknown-failed"
      return 1 ;;
  esac

  # EMPTY 或 BUSY 都先入队，再接一次有界排水：忙 → 留在队列报 queued；空 → 立刻投递报 delivered。
  # V7-F5：入队时已知要排队（BUSY）才立即写收件箱 durable 行；EMPTY 是「试着立刻投」，
  # 用 --inbox-defer —— 已确认送达就不写收件箱（不制造假待办）；真进了 held/ 再落盘。
  if [ "$v" = "EMPTY" ] && [ -n "$inbox" ]; then
    enq=(--kind "$kind" --target "$target" --from "$from" --inbox-defer "$inbox")
    [ -n "$dedup" ] && enq+=(--dedup "$dedup")
    enq+=(--payload "$payload")
  fi
  entry="$(team_outbox_enqueue "${enq[@]}")" || rc=$?
  if [ "$rc" = "3" ]; then
    TEAM_SEND_OUTCOME="duplicate"
    return 0
  fi
  [ -n "$entry" ] && [ -f "$entry" ] || { TEAM_SEND_OUTCOME="offline"; return 1; }
  if [ "$noverify" = "1" ]; then
    team_outbox_process_entry "$entry" --no-verify
  else
    team_outbox_process_entry "$entry"
  fi
  case "$TEAM_OUTBOX_RESULT" in
    delivered) TEAM_SEND_OUTCOME="delivered" ;;
    *)         TEAM_SEND_OUTCOME="queued" ;;
  esac
  return 0
}
