#!/usr/bin/env bash
# P174 · pulse-nudge-key 聚焦夹具（change: pulse-nudge-key · apply）
#
#   bash skills/teamsmith/tests/pulse-nudge-key.sh [--keys|--transitions|--policy|--observers|--migration|--all]
#
# 五档（每档都能单独跑；--all = 五档顺跑）：
#   --keys        纯键（2.1）：八个位置的量级无关、集合区分与字段序、七字段兼容、停跑席位散文不进键
#   --transitions 掉转（2.2）：真 team_watch_once —— 计数变不叫 / 类别增删立刻叫 / 空拍重置 /
#                 standby 与 gap 边界；被抑制的那一拍不推进 epoch，也不多投一次
#   --policy      策略（2.4）：普通/快速两个真待办读者在 pending-board 关/开下的过滤
#                 （todo/wip/review 受策略，blocked 恒可行动，stopped/meetings 保留）
#   --observers   观察者（3.1）：真 CLI 的 __panel-data --block pending 与 monitor --print/--json ——
#                 被抑制的一拍之后计数照旧可见；读取逐字节 + mtime 不改 state
#   --migration   迁移（2.5）：旧数字签 + 新近 epoch 只叫一次、之后安静；gap 变量优先级/默认值
#
# 纯逻辑档直接 source 真库，只影子化运行时边界（扫描/容量/死亡/排水/PM 判定/投递）——绝不碰 tmux；
# observers 档在私有夹具仓库里跑真 CLI，tmux 由私有 shim 服务（只读，不碰任何真实 session）。
# 退出码：0 = 全部预期成立；1 = 有失败；2 = 用法/环境错误；3 = 临时根建不起来。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# shellcheck source=tests/lib/tmp-root.sh
. "$SELF_DIR/lib/tmp-root.sh"

MODE="all"
case "${1:-}" in
  --keys|--transitions|--policy|--observers|--migration) MODE="${1#--}"; shift ;;
  --all) MODE="all"; shift ;;
  "")    MODE="all" ;;
  -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
  *) printf 'pulse-nudge-key.sh：未知参数 %s（-h 看用法）\n' "$1" >&2; exit 2 ;;
esac
[ $# -eq 0 ] || { printf 'pulse-nudge-key.sh：多余参数 %s\n' "$1" >&2; exit 2; }

TMP="$(tmp_root_create pulse-nudge-key)" || exit 3
cleanup() { [ "${BASHPID:-$$}" = "$$" ] || return 0; tmp_root_reap_all; }
trap cleanup EXIT

PASS=0; FAIL=0; SKIP=0
ok()   { PASS=$((PASS + 1)); printf '  \033[32m✓\033[0m %s\n' "$*"; }
bad()  { FAIL=$((FAIL + 1)); printf '  \033[31m✗\033[0m %s\n' "$*"; }
skip() { SKIP=$((SKIP + 1)); printf '  \033[33mSKIP\033[0m %s\n' "$*"; }
section() { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
eq() { # <名字> <实际> <期望>
  if [ "$3" = "$2" ]; then ok "$1（=$2）"; else bad "$1：期望 [$3] 实际 [$2]"; fi
}
has() { # <名字> <文本> <子串>
  case "$2" in *"$3"*) ok "$1" ;; *) bad "$1：文本里没有 [$3]（实际：$(printf '%s' "$2" | head -c 160)）" ;; esac
}
not_has() { # <名字> <文本> <子串>
  case "$2" in *"$3"*) bad "$1：不该出现 [$3]（实际：$(printf '%s' "$2" | head -c 160)）" ;; *) ok "$1" ;; esac
}

# ---------------------------------------------------------------- 纯逻辑底座（顶层 source：函数里 source 会丢 declare -A）
PK_PURE="$TMP/pure"
PK_STATE="$PK_PURE/state"
PK_PROJ="$PK_PURE/project"
PK_SENDS="$TMP/pure/sends.log"
PK_STARTS="$TMP/pure/starts.log"
PK_COUNTS='0 0 0 0 0 0 0 0'
PK_COUNTS_MODE='stub'          # stub | real（policy 档用真读者）
PK_PM_STATE='running:fixture'
PK_NOW=100000
mkdir -p "$PK_STATE" "$PK_PROJ/docs/team" "$PK_PROJ/worktrees"

export TEAM_ROOT="$PK_PURE" TEAM_MAIN_ROOT="$PK_PROJ" TEAM_STATE_DIR="$PK_STATE" \
       TEAM_DOCS_ABS="$PK_PROJ/docs/team" TEAM_DOCS_DIR="docs/team" TEAM_SESSION="pk-fixture-session" \
       TEAM_PROJECT="pk" TEAM_AGENTS="" TEAM_WORKTREES_DIR="worktrees" TEAM_CLI="team" \
       TEAM_PM_WINDOW="pm" TEAM_PM_INBOX="pm" TEAM_PROTECTED_BRANCH="main" TEAM_SKILL_DIR="$SKILL_DIR" \
       TEAM_SCAN_CACHE=0 TEAM_PULSE_NUDGE_GAP=3600 TEAM_PULSE_PENDING_BOARD=0 TEAM_NOTIFY_TMUX=0
unset TMUX TMUX_PANE 2>/dev/null || true

# shellcheck source=scripts/lib/common.sh
. "$SKILL_DIR/scripts/lib/common.sh"
for _pk_lib in "$SKILL_DIR"/scripts/lib/cmd-*.sh; do
  # shellcheck disable=SC1090
  . "$_pk_lib" 2>/dev/null || true
done

# 真读者先改名保存，再套一层开关（policy 档切 real；其余档给确定性的向量）
eval "pk_real_pending_counts_fast() $(declare -f team_panel_pending_counts_fast | tail -n +2)"
eval "pk_real_pending_counts() $(declare -f team_pending_counts | tail -n +2)"
team_panel_pending_counts_fast() {
  if [ "$PK_COUNTS_MODE" = "real" ]; then pk_real_pending_counts_fast; else printf '%s\n' "$PK_COUNTS"; fi
}
team_pending_counts() {
  if [ "$PK_COUNTS_MODE" = "real" ]; then pk_real_pending_counts; else printf '%s\n' "$PK_COUNTS"; fi
}

# 运行时边界：只影子化「外部世界」（真库的待办/文本/签名/提醒/state 读写全部走真实现）
team_scan_refresh() { :; }
team_scan_warm() { :; }
team_scan_invalidate() { :; }
team_capacity_line() { printf 'RAM available 1000MB ｜ 磁盘 swap 空闲 1000MB ｜ 估算可再加 5 个 agent\n'; }
team_watch_deaths_step() { :; }
team_outbox_drain() { :; }
team_pm_state() { printf '%s\n' "$PK_PM_STATE"; }
team_pm_alive() { [ "${PK_PM_STATE%%:*}" = "running" ]; }
team_pm_target() { printf 'pk-fixture:pm\n'; }
team_send_guarded() { printf '%s\n' "$2" >> "$PK_SENDS"; TEAM_SEND_OUTCOME=queued; }
team_pm_start() { printf 'unexpected PM start\n' >> "$PK_STARTS"; return 1; }
tmux() { printf 'ERROR: fixture touched tmux\n' >&2; exit 99; }
date() { if [ "$*" = '+%s' ]; then printf '%s\n' "$PK_NOW"; else command date "$@"; fi; }

pk_reset() {
  rm -rf "$PK_STATE"; mkdir -p "$PK_STATE"
  : > "$PK_SENDS"; : > "$PK_STARTS"
  PK_NOW=100000; PK_COUNTS='0 0 0 0 0 0 0 0'; PK_COUNTS_MODE='stub'; PK_PM_STATE='running:fixture'
}
pk_tick() { team_watch_once >"$TMP/last-tick.log" 2>&1 || true; }
pk_lines() { if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else printf '0'; fi; }
pk_nudges() { pk_lines "$TEAM_STATE_DIR/nudges.log"; }
pk_sends() { pk_lines "$PK_SENDS"; }
pk_starts() { pk_lines "$PK_STARTS"; }
pk_key() { printf '%s\n' "${1:-}"; }
pk_state_key() { team_state_get _watch nudge_sig unset; }
pk_watch_key() { awk 'NR==1{print $2}' "$TEAM_STATE_DIR/watchdog.nudge" 2>/dev/null || true; }
pk_last_text() { tail -n 1 "$TEAM_STATE_DIR/nudges.log" 2>/dev/null | sed 's/^[^ ]* //'; }
pk_observe() { printf '  counts=%s epoch=%s sig=%s nudges=%s sends=%s\n' \
  "$PK_COUNTS" "$(team_state_get _watch nudge_epoch unset)" "$(pk_state_key)" "$(pk_nudges)" "$(pk_sends)"; }
# 键 → 该键声明的正类别（用于策略断言：键的集合必须与真实读者给出的正类别逐项一致）
pk_key_names() { local k="${1:-}"; k="${k#pending:v1:}"; [ "$k" = "none" ] && { printf '\n'; return 0; }; printf '%s\n' "$k"; }

# ---------------------------------------------------------------- --keys（2.1）
pk_mode_keys() {
  section "keys · 类别集合（量级无关 / 字段序 / 七字段兼容 / 散文不进键）"
  local names=(inbox reports todo wip review blocked stopped meetings)
  local i v k1 k4 different=0
  for i in 0 1 2 3 4 5 6 7; do
    v=(0 0 0 0 0 0 0 0); v[$i]=1
    k1="$(team_pending_nudge_key "${v[*]}")"
    v[$i]=4
    k4="$(team_pending_nudge_key "${v[*]}")"
    [ "$k1" = "$k4" ] || { different=$((different + 1)); bad "keys：位置 $i（${names[$i]}）的量级 1→4 改了键（$k1 ≠ $k4）"; }
    case "$k1" in *"${names[$i]}"*) ;; *) different=$((different + 1)); bad "keys：位置 $i 的键没有点名声明的类别（$k1）" ;; esac
    case "$k1" in pending:v1:none|"") different=$((different + 1)); bad "keys：正类别 $i 的键退化成空集（$k1）" ;; esac
  done
  eq "keys：八个类别位置全部量级无关且各自命名（noisy=$different）" "$different" "0"
  eq "keys：单类别 infix 字面量" "$(team_pending_nudge_key '1 0 0 0 0 0 0 0')" "pending:v1:inbox"
  eq "keys：字段序序列化（reports,todo）" "$(team_pending_nudge_key '0 1 1 0 0 0 0 0')" "pending:v1:reports,todo"
  eq "keys：八段全正项按序全列" "$(team_pending_nudge_key '1 1 1 1 1 1 1 1')" \
    "pending:v1:inbox,reports,todo,wip,review,blocked,stopped,meetings"
  eq "keys：空集合有明确表示" "$(team_pending_nudge_key '0 0 0 0 0 0 0 0')" "pending:v1:none"
  eq "keys：集合区分（inbox ≠ reports）" \
    "$([ "$(team_pending_nudge_key '1 0 0 0 0 0 0 0')" != "$(team_pending_nudge_key '0 1 0 0 0 0 0 0')" ] && printf diff || printf same)" "diff"
  eq "keys：七字段兼容（缺 meetings 按 0）" "$(team_pending_nudge_key '1 0 0 0 0 0 0')" "pending:v1:inbox"
  eq "keys：七字段兼容（stopped 在第七位）" "$(team_pending_nudge_key '0 0 0 0 0 0 3')" "pending:v1:stopped"
  eq "keys：停跑席位散文（quota/unknown）不进键" "$(team_pending_nudge_key '0 0 0 0 0 0 2 0')" "pending:v1:stopped"
  local stopped_key; stopped_key="$(team_pending_nudge_key '0 0 0 0 0 0 2 0')"
  not_has "keys：键里没有 quota 散文" "$stopped_key" "quota"
  not_has "keys：键里没有 unknown 散文" "$stopped_key" "unknown"
  local sig1 sig4 key1 key4
  sig1="$(team_pending_sig '1 0 0 0 0 0 0 0')"; sig4="$(team_pending_sig '4 0 0 0 0 0 0 0')"
  key1="$(team_pending_nudge_key '1 0 0 0 0 0 0 0')"; key4="$(team_pending_nudge_key '4 0 0 0 0 0 0 0')"
  eq "keys：计数签名仍区分量级（计数没被键取代）" "$([ "$sig1" != "$sig4" ] && printf diff || printf same)" "diff"
  eq "keys：叫醒键不区分量级（解耦点）" "$key1" "$key4"
}

# ---------------------------------------------------------------- --transitions（2.2）
pk_mode_transitions() {
  section "transitions · 真 team_watch_once（计数变不叫 / 类别增删立刻叫 / 空拍重置 / 边界）"
  local i v noisy

  # ① 计数 1→4、类别不变、gap 内（今天的现场）→ 不叫、不投、也不推进 epoch
  pk_reset; PK_COUNTS='1 0 0 0 0 0 0 0'; pk_tick
  local epoch0 key0 watch0 epoch1
  epoch0="$(team_state_get _watch nudge_epoch unset)"
  key0="$(pk_state_key)"; watch0="$(cat "$PK_STATE/watchdog.nudge" 2>/dev/null || true)"
  PK_NOW=100900; PK_COUNTS='4 0 0 0 0 0 0 0'; pk_tick
  pk_observe
  eq "①计数不变量级：nudges.log 仍 1 行" "$(pk_nudges)" "1"
  eq "①计数不变量级：投递仍 1 次" "$(pk_sends)" "1"
  eq "①计数不变量级：nudge_epoch 没被推进" "$(team_state_get _watch nudge_epoch unset)" "$epoch0"
  eq "①计数不变量级：nudge_sig 仍是第一拍的键" "$(pk_state_key)" "$key0"
  eq "①计数不变量级：watchdog.nudge 逐字节不变" "$(cat "$PK_STATE/watchdog.nudge" 2>/dev/null || true)" "$watch0"
  has "①计数不变量级：记录的键是类别集合形态" "$key0" "pending:v1:inbox"

  # ② 八个类别位置逐一：1→4 都不叫（F4）
  noisy=0
  for i in 0 1 2 3 4 5 6 7; do
    pk_reset
    v=(0 0 0 0 0 0 0 0); v[$i]=1; PK_COUNTS="${v[*]}"; pk_tick
    PK_NOW=100100; v[$i]=4; PK_COUNTS="${v[*]}"; pk_tick
    [ "$(pk_nudges)" = "1" ] || { noisy=$((noisy + 1)); bad "②位置 $i 的计数 1→4 多叫了（nudges=$(pk_nudges)）"; }
  done
  eq "②八个位置的计数噪声一个都不叫（noisy=$noisy）" "$noisy" "0"

  # ③ 新增一个类别 → 立刻叫，且文本/键/投递都点名它
  pk_reset; PK_COUNTS='1 0 0 0 0 0 0 0'; pk_tick
  PK_NOW=100100; PK_COUNTS='1 1 0 0 0 0 0 0'; pk_tick
  eq "③新增类别：第二行提醒" "$(pk_nudges)" "2"
  eq "③新增类别：第二次投递" "$(pk_sends)" "2"
  eq "③新增类别：提醒文本带当前计数（未读 1 + 待复验 1）" "$(pk_last_text)" "未读通知 1 · 待复验 1"
  eq "③新增类别：记录的键点名两个类别" "$(pk_state_key)" "pending:v1:inbox,reports"
  eq "③新增类别：watchdog.nudge 与 state 的键同源" "$(pk_watch_key)" "$(pk_state_key)"
  has "③新增类别：投递载荷带当前计数文本" "$(tail -n 1 "$PK_SENDS")" "未读通知 1 · 待复验 1"

  # ④ 移除一个类别 → 也算批次变了，立刻叫
  PK_NOW=100200; PK_COUNTS='1 0 0 0 0 0 0 0'; pk_tick
  eq "④移除类别：第三行提醒" "$(pk_nudges)" "3"
  eq "④移除类别：第三次投递" "$(pk_sends)" "3"
  eq "④移除类别：文本不再带待复验" "$(pk_last_text)" "未读通知 1"
  eq "④移除类别：键回到只有 inbox" "$(pk_state_key)" "pending:v1:inbox"

  # ⑤ 空拍重置（F2）：空拍不叫、之后同一类别回来要能立刻叫（不推进 gap）
  pk_reset; PK_COUNTS='1 0 0 0 0 0 0 0'; pk_tick
  epoch0="$(team_state_get _watch nudge_epoch unset)"
  PK_NOW=100100; PK_COUNTS='0 0 0 0 0 0 0 0'; pk_tick
  eq "⑤空拍：不叫" "$(pk_nudges)" "1"
  eq "⑤空拍：不投" "$(pk_sends)" "1"
  eq "⑤空拍：提醒历史被清（nudge_sig 空）" "$(team_state_get _watch nudge_sig unset)" "unset"
  PK_NOW=100200; PK_COUNTS='1 0 0 0 0 0 0 0'; pk_tick
  eq "⑤空拍回来：第二次提醒" "$(pk_nudges)" "2"
  eq "⑤空拍回来：第二次投递" "$(pk_sends)" "2"

  # ⑥ standby 下的空拍也重置（F3）：standby 空拍不叫不启，回来后立刻叫
  pk_reset; PK_COUNTS='1 0 0 0 0 0 0 0'; pk_tick
  team_standby_on 'fixture waiting'
  PK_NOW=100100; PK_COUNTS='0 0 0 0 0 0 0 0'; pk_tick
  eq "⑥standby 空拍：没有新增提醒/投递，也没启动 PM" "$(pk_nudges)/$(pk_sends)/$(pk_starts)" "1/1/0"
  team_standby_off
  PK_NOW=100200; PK_COUNTS='1 0 0 0 0 0 0 0'; pk_tick
  eq "⑥standby 回来：第二次提醒" "$(pk_nudges)" "2"
  eq "⑥standby 回来：第二次投递" "$(pk_sends)" "2"

  # ⑦ gap-1 / gap 边界：同一批的抑制拍不推进 epoch，gap 那一刻叫
  pk_reset; PK_COUNTS='1 0 0 0 0 0 0 0'; pk_tick
  epoch0="$(team_state_get _watch nudge_epoch unset)"
  PK_NOW=103599; pk_tick
  eq "⑦gap-1：仍不叫" "$(pk_nudges)" "1"
  eq "⑦gap-1：epoch 没被推进" "$(team_state_get _watch nudge_epoch unset)" "$epoch0"
  PK_NOW=103600; pk_tick
  eq "⑦gap 到：叫一次" "$(pk_nudges)" "2"
  eq "⑦gap 到：epoch 跟到这一拍" "$(team_state_get _watch nudge_epoch unset)" "103600"

  # ⑧ 无待办 + 没有 PM：完全沉默（P109 不许破）
  pk_reset; PK_PM_STATE='idle:fixture'; PK_COUNTS='0 0 0 0 0 0 0 0'; pk_tick
  eq "⑧无待办且无 PM：不叫不投不启" "$(pk_nudges)/$(pk_sends)/$(pk_starts)" "0/0/0"

  # ⑨ standby 抑制普通提醒 + 积压照记日志（P109 不许破）
  pk_reset; PK_COUNTS='1 0 0 0 0 0 0 0'; team_standby_on 'fixture waiting'; pk_tick
  eq "⑨standby：不叫不投不启" "$(pk_nudges)/$(pk_sends)/$(pk_starts)" "0/0/0"
  eq "⑨standby：积压写进巡检日志（一条）" "$(grep -c '未读通知 1' "$PK_STATE/watchdog.log")" "1"
  team_standby_off; pk_tick
  eq "⑨standby 解除：恢复叫醒" "$(pk_nudges)" "1"
}

# ---------------------------------------------------------------- --policy（2.4）
pk_policy_build() {
  local R="$TMP/policy"
  rm -rf "$R"; mkdir -p "$R/state" "$R/meetings/peer-x/transcript" "$R/meetings/peer-x/read" \
    "$R/project/docs/team/reports" "$R/project/docs/team/reviews" "$R/project/docs/team/tasks" "$R/project/docs/team/inbox"
  cat > "$R/project/docs/team/BOARD.md" <<'EOF'
| ID | 任务 | agent | 分支 | 依赖 | 状态 |
|---|---|---|---|---|---|
| P901 | todo 行 | dev | - | - | todo |
| P902 | wip 行 | dev | - | - | wip |
| P903 | review 行 | dev | - | - | review |
| P904 | blocked 行 | dev | - | - | blocked |
EOF
  printf '未读通知一行\n' > "$R/project/docs/team/inbox/pm.md"
  printf '# P905 · policy fixture 报告\n' > "$R/project/docs/team/reports/P905-dev.md"
  printf '# P905 · policy fixture 任务书\n' > "$R/project/docs/team/tasks/P905-fixture.md"
  printf 'task=P906\n' > "$R/state/dev.env"          # 停跑席位：有 task + 没在跑
  {
    printf 'PARTICIPANTS=pk\nSTATUS=open\nOPENED_EPOCH=%s\nTTL_HOURS=72\n' "$(date +%s)"
  } > "$R/meetings/peer-x/state.env"
  printf '第一轮\n' > "$R/meetings/peer-x/transcript/0001_pk_info.md"
  printf '第二轮\n' > "$R/meetings/peer-x/transcript/0002_peer_info.md"
  printf '%s\n' "$R"
}
# 键的集合必须与给定计数向量的正类别逐项一致（策略断言的核心；返回 0/1）
pk_key_matches_counts() { # <counts> <key>
  local names=(inbox reports todo wip review blocked stopped meetings)
  local v=() i want="" got
  read -r -a v <<< "$1"
  for i in 0 1 2 3 4 5 6 7; do
    case "${v[$i]:-0}" in ''|0) ;; *) want="${want:+$want,}${names[$i]}" ;; esac
  done
  [ -n "$want" ] || want="none"
  got="${2#pending:v1:}"
  [ "$got" = "$want" ]
}
# 一次策略断言：真读者（普通 + 快速）在指定开关下的计数与键
pk_policy_case() { # <名字> <board 开关> <期望计数> <期望键>
  local name="$1" board="$2" want_counts="$3" want_key="$4"
  local counts fast key fast_key
  counts="$(TEAM_PULSE_PENDING_BOARD="$board" pk_real_pending_counts)"
  fast="$(TEAM_PULSE_PENDING_BOARD="$board" pk_real_pending_counts_fast)"
  key="$(team_pending_nudge_key "$counts")"
  fast_key="$(team_pending_nudge_key "$fast")"
  eq "policy：$name 普通读者计数（$counts）" "$counts" "$want_counts"
  eq "policy：$name 快速读者与普通读者同值" "$fast" "$counts"
  eq "policy：$name 键 = $want_key" "$key" "$want_key"
  eq "policy：$name 快速读者的键同值" "$fast_key" "$key"
  if pk_key_matches_counts "$counts" "$key"; then ok "policy：$name 键与读者返回的正类别逐项一致"
  else bad "policy：$name 键与读者返回的正类别不一致（counts=$counts key=$key）"; fi
}
pk_mode_policy() {
  section "policy · 真待办读者 + pending-board 策略（todo/wip/review 受门，blocked 恒可，stopped/meetings 保留）"
  local R; R="$(pk_policy_build)"
  local old_state="$TEAM_STATE_DIR" old_docs="$TEAM_DOCS_ABS" old_main="$TEAM_MAIN_ROOT" old_root="$TEAM_ROOT" old_agents="$TEAM_AGENTS"
  TEAM_STATE_DIR="$R/state"
  TEAM_DOCS_ABS="$R/project/docs/team"
  TEAM_MAIN_ROOT="$R/project"; TEAM_ROOT="$R"
  TEAM_AGENTS="dev"
  TEAM_MEETINGS_DIR="$R/meetings"
  PK_COUNTS_MODE='real'
  team_agent_live() { return 1; }   # 夹具：席位没在跑（真判据由既有段落钉）

  # 关（默认）：todo/wip/review 清零；blocked / stopped / meetings / inbox / reports 保留
  pk_policy_case "board=0" 0 "1 1 0 0 0 1 1 2" "pending:v1:inbox,reports,blocked,stopped,meetings"
  # 开：列为正的全部加入（review 也在内）
  pk_policy_case "board=1" 1 "1 1 1 1 1 1 1 2" "pending:v1:inbox,reports,todo,wip,review,blocked,stopped,meetings"

  # 牙齿：被策略清零的类别如果混进键，一致性判据必须拒（不认「读者返回什么就信什么」）
  if pk_key_matches_counts "1 1 0 0 0 1 1 2" "pending:v1:inbox,reports,todo,blocked,stopped,meetings"; then
    bad "policy：键里混进被门掉的 todo 没有被拒（判据是橡皮章）"
  else
    ok "policy：键里混进被门掉的 todo 被拒（判据有牙齿）"
  fi
  # 牙齿：绕过策略的读者（板列照旧计入）必须被期望计数拒
  local bypass; bypass="1 1 1 1 1 1 1 2"
  if [ "$bypass" = "1 1 0 0 0 1 1 2" ]; then
    bad "policy：绕过策略的读者没有被拒"
  else
    ok "policy：绕过策略的读者（board=0 仍计 todo/wip/review）被期望计数拒"
  fi

  PK_COUNTS_MODE='stub'
  TEAM_STATE_DIR="$old_state"; TEAM_DOCS_ABS="$old_docs"; TEAM_MAIN_ROOT="$old_main"; TEAM_ROOT="$old_root"
  TEAM_AGENTS="$old_agents"
  unset TEAM_MEETINGS_DIR 2>/dev/null || true
}

# ---------------------------------------------------------------- --migration（2.5）
pk_mode_migration() {
  section "migration · 旧数字签 + 新近 epoch 只叫一次；gap 变量优先级/默认值"
  local epoch0 key0

  # 旧形态（数字签 = 计数 cksum）+ 100 秒前的 epoch → 第一次非空拍必须叫一次（新键 ≠ 旧数字签）
  pk_reset
  team_state_set _watch nudge_epoch "$((PK_NOW - 100))"
  team_state_set _watch nudge_sig "31270149"
  PK_COUNTS='1 0 0 0 0 0 0 0'; pk_tick
  eq "迁移：旧签在 gap 内也叫了这一次" "$(pk_nudges)" "1"
  has "迁移：记录改写成类别键形态" "$(pk_state_key)" "pending:v1:inbox"
  eq "迁移：watchdog.nudge 也写新形态" "$(pk_watch_key)" "$(pk_state_key)"
  PK_NOW=100010; pk_tick
  eq "迁移：之后同一批的拍安静（nudges 仍 1）" "$(pk_nudges)" "1"
  eq "迁移：安静拍没多投" "$(pk_sends)" "1"

  # 旧形态 + 空拍 → 先重置；回来再叫一次（迁移期的老历史清干净）
  pk_reset
  team_state_set _watch nudge_epoch "$((PK_NOW - 100))"
  team_state_set _watch nudge_sig "31270149"
  PK_COUNTS='0 0 0 0 0 0 0 0'; pk_tick
  eq "迁移：空拍清掉旧签" "$(team_state_get _watch nudge_sig unset)" "unset"
  PK_COUNTS='1 0 0 0 0 0 0 0'; PK_NOW=100100; pk_tick
  eq "迁移：空拍后回来叫一次" "$(pk_nudges)" "1"

  # gap 变量优先级：TEAM_PULSE_* ＞ TEAM_WATCH_* ＞ 默认 900
  eq "gap 优先级：新变量赢旧变量" \
    "$(env -u TEAM_PULSE_NUDGE_GAP -u TEAM_WATCH_NUDGE_GAP TEAM_PULSE_NUDGE_GAP=1200 TEAM_WATCH_NUDGE_GAP=600 \
        SKILL_DIR="$SKILL_DIR" bash -c '. "$SKILL_DIR/scripts/lib/common.sh"; team_pulse_var NUDGE_GAP 900')" "1200"
  eq "gap 优先级：新变量为空 → 旧变量兜底" \
    "$(env -u TEAM_PULSE_NUDGE_GAP -u TEAM_WATCH_NUDGE_GAP TEAM_PULSE_NUDGE_GAP= TEAM_WATCH_NUDGE_GAP=600 \
        SKILL_DIR="$SKILL_DIR" bash -c '. "$SKILL_DIR/scripts/lib/common.sh"; team_pulse_var NUDGE_GAP 900')" "600"
  eq "gap 优先级：两个都空 → 默认 900" \
    "$(env -u TEAM_PULSE_NUDGE_GAP -u TEAM_WATCH_NUDGE_GAP \
        SKILL_DIR="$SKILL_DIR" bash -c '. "$SKILL_DIR/scripts/lib/common.sh"; team_pulse_var NUDGE_GAP 900')" "900"

  # 有效 gap 真的落在巡检判定上：1200 秒的同一批在 1199 静、1200 叫
  pk_reset; TEAM_PULSE_NUDGE_GAP=1200
  PK_COUNTS='1 0 0 0 0 0 0 0'; pk_tick
  PK_NOW=101199; pk_tick
  eq "gap=1200：1199 秒时不叫" "$(pk_nudges)" "1"
  PK_NOW=101200; pk_tick
  eq "gap=1200：1200 秒时叫" "$(pk_nudges)" "2"
  TEAM_PULSE_NUDGE_GAP=3600
}

# ---------------------------------------------------------------- --observers（3.1）
pk_json() { # <json 文件> <python 表达式>；d=整个对象、p=panel（没有 panel 就是 d）
  python3 - "$1" "$2" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
p = d.get("panel", d)
sys.exit(0 if eval(sys.argv[2]) else 1)
PY
}
pk_mode_observers() {
  section "observers · 被抑制的一拍之后计数照旧可见（真 CLI + 私有 tmux shim）"
  local O R H SHIM S
  O="$TMP/obs"; R="$O/repo"; H="$O/home"; SHIM="$O/shim"; S="$O/repo/.pi/team/state"
  local old_state="$TEAM_STATE_DIR" old_docs="$TEAM_DOCS_ABS" old_main="$TEAM_MAIN_ROOT" old_root="$TEAM_ROOT"
  mkdir -p "$R" "$H/.pi/agent" "$SHIM"

  # 私有夹具仓库（真 team init；不碰调用方项目）
  ( cd "$R" && git init -q -b main && git config user.email pk@fixture && git config user.name pk \
      && printf '# P174 observers\n' > README.md && git add -A && git commit -qm init ) >/dev/null 2>&1 \
    || { bad "observers：建夹具仓库失败"; return; }
  ( cd "$R" && env "${pk_clean_env[@]}" bash "$SKILL_DIR/scripts/team" init \
      --session "pk-obs-$$" --agents "dev" --vcs local --gates "true" --docs docs/team ) >"$O/init.log" 2>&1 \
    || { bad "observers：team init 失败（见 $O/init.log）"; tail -3 "$O/init.log" | sed 's/^/      /'; return; }

  # 私有 tmux shim：只读，回答「没有 pm 窗口」
  cat > "$SHIM/tmux" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${PK_TMUX_LOG:-/dev/null}"
case "$*" in
  *list-windows*) printf 'dev\n' ;;
  *window_name*)  printf 'dev\n' ;;
  *has-session*)  exit 0 ;;
  *pane_current_command*) printf 'pi\n' ;;
esac
exit 0
EOF
  chmod +x "$SHIM/tmux"
  pk_cli() { ( cd "$R" && env "${pk_clean_env[@]}" "PATH=$SHIM:$PATH" "PK_TMUX_LOG=$O/tmux.log" \
      "HOME=$H" "TEAM_PI_AGENT_DIR=$H/.pi/agent" bash "$SKILL_DIR/scripts/team" "$@" ); }

  # 夹具数据：1 条未读 / 2 份待复验报告 / 1 个 blocked 行 / 3 条队列 / 40 条容量采样
  local i
  mkdir -p "$S"
  for i in $(seq 1 40); do
    printf '2026-01-01T00:00:%02dZ RAM 可用 %sMB ｜ 磁盘 swap 空闲 31306MB，zram 用 50%%/物理 6145MB ｜ 估算可再加 5 个 agent\n' \
      "$i" "$((4000 + i))" >> "$S/capacity.log"
  done
  mkdir -p "$R/docs/team/reports" "$R/docs/team/tasks" "$R/docs/team/inbox"
  printf 'P174 未读通知一行\n' > "$R/docs/team/inbox/pm.md"
  printf '# P910 · fixture A\n' > "$R/docs/team/reports/P910-dev.md"
  printf '# P910 · brief\n' > "$R/docs/team/tasks/P910-fixture.md"
  printf '# P911 · fixture B\n' > "$R/docs/team/reports/P911-dev.md"
  printf '# P911 · brief\n' > "$R/docs/team/tasks/P911-fixture.md"
  pk_cli board add P910 "P174 fixture A" dev - >/dev/null 2>&1 || true
  pk_cli board add P911 "P174 fixture B" dev - >/dev/null 2>&1 || true
  pk_cli board add P912 "P174 fixture blocked" dev - >/dev/null 2>&1 || true
  pk_cli board set P910 review >/dev/null 2>&1 || true
  pk_cli board set P911 review >/dev/null 2>&1 || true
  pk_cli board set P912 blocked >/dev/null 2>&1 || true
  mkdir -p "$S/outbox"
  for i in 001 002 003; do
    printf 'kind: notify\ntarget: pm\n---\nqueue %s\n' "$i" > "$S/outbox/$(date +%s%3N)-$i-pm.msg"
  done

  local HAVE_PY=1 HAVE_JS=0 JS=""
  command -v python3 >/dev/null 2>&1 || HAVE_PY=0
  JS="$(command -v node || command -v bun || command -v tsx || true)"
  if [ -n "${TEAM_JS_BIN:-}" ] && [ -x "${TEAM_JS_BIN}" ]; then JS="$TEAM_JS_BIN"; fi
  [ -n "$JS" ] && HAVE_JS=1
  [ "$HAVE_PY" = "1" ] || skip "observers：没有 python3——JSON 断言跳过"

  # 场景①「状态带镜像实测」（panel 基线场景，verbatim 断言）
  if [ "$HAVE_JS" = "1" ] && [ "$HAVE_PY" = "1" ]; then
    pk_cli monitor --json --no-activity >"$O/band.json" 2>"$O/band.err" || bad "observers：monitor --json rc≠0（$(tail -1 "$O/band.err")）"
    pk_cli monitor --print --no-activity >"$O/band.txt" 2>"$O/band-print.err" || bad "observers：monitor --print rc≠0（$(tail -1 "$O/band-print.err")）"
    if pk_json "$O/band.json" 'p["pm"]["state"] == "absent"'; then ok "场景①：无 PM 窗口 → panel.pm.state=absent"
    else bad "场景①：panel.pm.state ≠ absent（$(head -c 200 "$O/band.json")）"; fi
    if pk_json "$O/band.json" '(p["pending"]["inbox"], p["pending"]["reports"], p["pending"]["blocked"], p["pending"]["total"]) == (1, 2, 1, 4)'; then
      ok "场景①：待办 1/2/1 与总数 4（未读/待复验/blocked）"
    else bad "场景①：待办计数不是 1/2/1/4（$(head -c 260 "$O/band.json")）"; fi
    if pk_json "$O/band.json" 'p["outbox"]["queued"] == 3'; then ok "场景①：panel.outbox.queued=3"
    else bad "场景①：panel.outbox.queued ≠ 3"; fi
    if pk_json "$O/band.json" 'p["capacity"]["ram_avail_mb"] == 4040 and len(p["capacity"]["spark"]) >= 2'; then
      ok "场景①：RAM 采样 = 最后一条、spark ≥ 2 个值"
    else bad "场景①：容量带不是最后一条采样/spark 不足（$(head -c 260 "$O/band.json")）"; fi
    has "场景①：打印帧带 PM 状态词（闭集 token absent）" "$(cat "$O/band.txt")" "absent"
    if grep -qE '延后投递 3' "$O/band.txt"; then ok "场景①：打印帧带队列计数（延后投递 3）"
    else bad "场景①：打印帧没有延后投递 3"; fi
    if grep -qi zram "$O/band.txt"; then bad "场景①：打印帧出现 zram"; else ok "场景①：打印帧不带 zram"; fi
  fi

  # ≤174 观察者的 GIVEN：被抑制的那一拍只有 inbox 一个类别 → 把场景①的报告/blocked 行收尾掉
  # （报告文件是复验待办的真源：移出 reports/；blocked 行走 dropped，免得 done 的合并/复验证据门串进来）
  mkdir -p "$O/phase1"
  mv "$R/docs/team/reports/P910-dev.md" "$R/docs/team/reports/P911-dev.md" "$O/phase1/" 2>/dev/null || true
  pk_cli board set P912 dropped >/dev/null 2>&1 || true

  # 被抑制的一拍：先在真夹具上叫一次（count=1），计数变 4（类别不变）后 gap 内的拍必须被抑制
  TEAM_STATE_DIR="$S"; TEAM_DOCS_ABS="$R/docs/team"; TEAM_MAIN_ROOT="$R"; TEAM_ROOT="$R"
  PK_COUNTS_MODE='stub'; PK_PM_STATE='running:fixture'; PK_NOW=100000
  : > "$PK_SENDS"; : > "$PK_STARTS"
  PK_COUNTS='1 0 0 0 0 0 0 0'; pk_tick
  local epoch0 watch0
  epoch0="$(team_state_get _watch nudge_epoch unset)"
  watch0="$(cat "$S/watchdog.nudge" 2>/dev/null || true)"
  printf '第二行\n第三行\n第四行\n' >> "$R/docs/team/inbox/pm.md"
  PK_NOW=100900; PK_COUNTS='4 0 0 0 0 0 0 0'; pk_tick
  eq "观察者前提：被抑制的拍没有多叫" "$(pk_nudges)" "1"
  eq "观察者前提：被抑制的拍没有多投" "$(pk_sends)" "1"
  eq "观察者前提：被抑制的拍没有推进 epoch" "$(team_state_get _watch nudge_epoch unset)" "$epoch0"
  eq "观察者前提：被抑制的拍没有改 watchdog.nudge" "$(cat "$S/watchdog.nudge" 2>/dev/null || true)" "$watch0"

  # 观察者读取（pending 块纯 bash；monitor 需要 JS 运行时）
  local before after outbox_before outbox_after nudges_before
  before="$( (cd "$S" && find . -type f -printf '%P %T@\n' | sort; cd "$S" && find . -type f -exec sha256sum {} + | sort) )"
  outbox_before="$(find "$S/outbox" -maxdepth 1 -name '*.msg' | wc -l | tr -d ' ')"
  nudges_before="$(pk_nudges)"
  if [ "$HAVE_PY" = "1" ]; then
    pk_cli __panel-data --block pending >"$O/pending.json" 2>"$O/pending.err" \
      || bad "观察者：__panel-data --block pending rc≠0（$(tail -1 "$O/pending.err")）"
    if pk_json "$O/pending.json" 'p["inbox"] == 4 and p["total"] == 4 and "未读通知 4" in p["text"]'; then
      ok "观察者：pending 块带当前计数 inbox=4 / total=4 / 未读通知 4（不是布尔）"
    else bad "观察者：pending 块没有当前计数（$(head -c 260 "$O/pending.json")）"; fi
    if [ "$HAVE_JS" = "1" ]; then
      pk_cli monitor --json --no-activity >"$O/after.json" 2>"$O/after.err" \
        || bad "观察者：monitor --json rc≠0（$(tail -1 "$O/after.err")）"
      if pk_json "$O/after.json" 'p["pending"]["inbox"] == 4 and p["pending"]["total"] == 4 and "未读通知 4" in p["pending"]["text"]'; then
        ok "观察者：monitor --json 的 panel.pending 是当前计数（4/4）"
      else bad "观察者：monitor --json 没有当前计数（$(head -c 260 "$O/after.json")）"; fi
      pk_cli monitor --print --no-activity >"$O/after.txt" 2>"$O/after-print.err" \
        || bad "观察者：monitor --print rc≠0（$(tail -1 "$O/after-print.err")）"
      if grep -q '未读通知 4' "$O/after.txt" && ! grep -q '未读通知 1\b' "$O/after.txt"; then
        ok "观察者：monitor --print 显示当前未读数 4（不是被提醒时的 1）"
      else bad "观察者：monitor --print 没显示 4/显示了 1（$(grep -o '未读通知 [0-9]*' "$O/after.txt" | head -1)）"; fi
    else
      skip "观察者：没有 JS 运行时——monitor --print/--json 两条腿跳过（pending 块已覆盖计数口径）"
    fi
  else
    skip "观察者：没有 python3——计数/只读断言跳过"
  fi
  after="$( (cd "$S" && find . -type f -printf '%P %T@\n' | sort; cd "$S" && find . -type f -exec sha256sum {} + | sort) )"
  outbox_after="$(find "$S/outbox" -maxdepth 1 -name '*.msg' | wc -l | tr -d ' ')"
  eq "观察者：读取后 state 逐字节+mtime 不变" "$after" "$before"
  eq "观察者：没有新增 nudges.log 行" "$(pk_nudges)" "$nudges_before"
  eq "观察者：没有新增 outbox 条目" "$outbox_after" "$outbox_before"

  # 场景②「standby 在决定叫醒的地方可见」（panel 基线场景）
  if [ "$HAVE_JS" = "1" ] && [ "$HAVE_PY" = "1" ]; then
    pk_cli standby on --reason "waiting for the user" >/dev/null 2>&1 || true
    pk_cli monitor --json --no-activity >"$O/standby.json" 2>/dev/null || true
    if pk_json "$O/standby.json" 'p["standby"]["on"] is True and p["standby"]["reason"] == "waiting for the user"'; then
      ok "场景②：panel.standby.on=true 且 reason 原样"
    else bad "场景②：standby JSON 不对（$(head -c 200 "$O/standby.json")）"; fi
    pk_cli monitor --print --no-activity >"$O/standby.txt" 2>/dev/null || true
    has "场景②：打印帧带 standby 原因" "$(cat "$O/standby.txt")" "waiting for the user"
    pk_cli standby off >/dev/null 2>&1 || true
  fi

  TEAM_STATE_DIR="$old_state"; TEAM_DOCS_ABS="$old_docs"; TEAM_MAIN_ROOT="$old_main"; TEAM_ROOT="$old_root"
}

# ---------------------------------------------------------------- 驱动
# 子进程/夹具仓库里跑 CLI 前要清掉本夹具注入的团队身份（M40 的身份闸门 + 环境覆盖表都认它们）
pk_clean_env=(-u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_STATE_DIR \
  -u TEAM_DOCS_ABS -u TEAM_DOCS_DIR -u TEAM_SKILL_DIR -u TEAM_AGENTS -u TEAM_SCAN_CACHE -u TEAM_CLI \
  -u TEAM_PM_WINDOW -u TEAM_PM_INBOX -u TEAM_PROTECTED_BRANCH -u TEAM_WORKTREES_DIR \
  -u TEAM_PULSE_NUDGE_GAP -u TEAM_PULSE_PENDING_BOARD -u TEAM_NOTIFY_TMUX -u TEAM_MEETINGS_DIR)

case "$MODE" in
  keys)        pk_mode_keys ;;
  transitions) pk_mode_transitions ;;
  policy)      pk_mode_policy ;;
  migration)   pk_mode_migration ;;
  observers)   pk_mode_observers ;;
  all)         pk_mode_keys; pk_mode_transitions; pk_mode_policy; pk_mode_migration; pk_mode_observers ;;
esac

printf '\n== P174 结果 == ✓%s ✗%s SKIP%s\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
