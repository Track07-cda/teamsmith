#!/usr/bin/env bash
# M24 夹具：**真实 pi 窗格**上的投递守卫体检（空闲空框 / 粘贴后 / 收回）。
#
#   bash tests/pm-box-real.sh [--idle-secs N] [--keep] [--payload <文字>]
#
# 为什么要真实 pi（brief 要求）：M17 的 fake-tui.py 把所有已知形状都建模了，门禁全绿，
# 而真实现网里 draft-raced-left 仍在发生 —— 差别只能在真实 TUI 上找。这个夹具用真实 `pi`
# 起一个窗格，把**守卫看到的原始帧**和它做的判定一起打出来，让「空闲空框被判忙 / 粘贴后
# 判成混了别人的字 / 收回失败」这三类误判可以在真实现场复现与回归。
#
# 注意：tmux 3.7 的 base-index 是 1 —— 夹具一律用 session 级目标（`-t $SESS`），
# 不要写 `$SESS:0`（那是「窗口 0 不存在」，所有查询都会静默失败 → 守卫会报 UNKNOWN）。
#
# M45（更新横幅）：pi 启动时会去 pi.dev 查最新版本，一旦有新版本就在**输入框上方**画
# 「Update Available / New version … is available. Run pi update」横幅（chat 区的 DynamicBorder
# 与输入框边框同形等宽）—— **用户指令：不关它**（不用 `PI_OFFLINE`/`PI_SKIP_VERSION_CHECK`），
# 判据层必须容忍横幅。所以夹具照常起 pi（更新检查开），并把两个东西打出来：
#   · banner=present|absent   这轮的帧里到底有没有横幅
#   · M45 idle-read=EMPTY    空闲空框必须读成空（横幅在场时这点就是判据层的考试），非 0 = 夹具红
# 证据轮次要求「这轮真的有横幅」时用 `M45_REQUIRE_BANNER=1`（没横幅就直接红，不冒充现场证据）：
#   M45_REQUIRE_BANNER=1 bash tests/pm-box-real.sh --idle-secs 20
#
# 隔离纪律（M23 事故 + PM 要求）：只用私有 tmux socket（TMUX_TMPDIR 指向本夹具的临时目录），
# 并且显式 unset TMUX/TMUX_PANE —— 否则 tmux 客户端会走 $TMUX 指的那个（真实）server。
# 脚本结尾会断言：本夹具的 session 没有出现在真实默认 server 上。
#
# 铁律：不读不写 ~/.pi 的会话文件（pi 用 --no-session + --session-dir 指向临时目录），
# 不碰真实 tmux server。
set -uo pipefail

SKILL_DIR="${M24_SKILL_DIR:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"   # 可指向另一份 skill 副本（flip 证据用）
TEAM="bash $SKILL_DIR/scripts/team"
PI_BIN="${M24_PI_BIN:-$HOME/.bun/bin/pi}"
[ -x "$PI_BIN" ] || PI_BIN="$(command -v pi 2>/dev/null || true)"

IDLE_SECS=8; KEEP="${TEAM_M24_KEEP:-0}"; PAYLOAD=""; TIMELINE=0; RETRACT_MODE="${M24_RETRACT_MODE:-burst}"
while [ $# -gt 0 ]; do
  case "$1" in
    --idle-secs) IDLE_SECS="${2:-8}"; shift 2 ;;
    --keep) KEEP=1; shift ;;
    --payload) PAYLOAD="${2:-}"; shift 2 ;;
    --timeline) TIMELINE=1; shift ;;
    --retract-mode) RETRACT_MODE="${2:-burst}"; shift 2 ;;
    *) shift ;;
  esac
done
case "$IDLE_SECS" in ''|*[!0-9]*) IDLE_SECS=8 ;; esac

TMP="$(mktemp -d /tmp/teamsmith-pmbox.XXXXXX)"
SESS="teamsmith-pmbox-$$"
SOCKDIR="$TMP/tmux"
REPO="$TMP/proj"
mkdir -p "$SOCKDIR" "$REPO" "$TMP/pi-sessions"

cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0
  m24_tmux kill-session -t "$SESS" 2>/dev/null || true
  m24_tmux kill-server 2>/dev/null || true
  if [ "$KEEP" = "1" ]; then printf '保留临时目录：%s\n' "$TMP"; else rm -rf "$TMP"; fi
}
trap cleanup EXIT

# 私有 socket + 不继承调用者的 tmux 身份（两条都要，见 M23）
m24_tmux() { env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$SOCKDIR" tmux "$@"; }
# 在夹具项目里跑一段用到投递守卫的 bash（片段从 stdin 进来；$T=目标、$PAYLOAD 可用）
m24_guard() {
  ( cd "$REPO" && env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$SOCKDIR" TEAM_SESSION="$SESS" M24_PAYLOAD="$PAYLOAD" \
      bash -c '
        set -u
        . "'"$SKILL_DIR"'/scripts/lib/common.sh"
        . "'"$SKILL_DIR"'/scripts/lib/outbox.sh"
        team_load_config 2>/dev/null || true
        T="'"$SESS"'"
        PAYLOAD="${M24_PAYLOAD:-}"
        source /dev/stdin
      ' )
}

printf 'M24 真实 pi 窗格体检 · pi=%s · 私有 socket=%s · idle=%ss\n' "${PI_BIN:-（找不到 pi）}" "$SOCKDIR" "$IDLE_SECS"
if [ -z "${PI_BIN:-}" ] || [ ! -x "$PI_BIN" ]; then
  printf 'SKIP：找不到可执行的 pi（%s）—— 真实现场夹具需要真 pi\n' "${PI_BIN:-无}"
  exit 0
fi
( cd "$REPO" && git init -q -b main && git config user.email pmbox@teamsmith && git config user.name pmbox \
  && echo "# pmbox" > README.md && git add -A && git commit -qm init )
( cd "$REPO" && env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$SOCKDIR" TEAM_SESSION="$SESS" \
    $TEAM init --session "$SESS" --agents "dev" --vcs local --gates "true" --docs docs/team ) >"$TMP/init.log" 2>&1 \
  || { printf '夹具 init 失败\n'; tail -3 "$TMP/init.log"; }

# 真 pi：真 HOME（沿用使用者的 provider/配置）+ 临时 session 目录（不碰真实会话文件）
# M45：**不关** pi 的更新检查（用户指令）—— 横幅该出现就让它出现，判据层负责容忍它
m24_tmux new-session -d -s "$SESS" -x 120 -y 30 -c "$REPO" \
  "HOME=$HOME $PI_BIN --no-session --session-dir $TMP/pi-sessions" 2>/dev/null || true

box_ready() { m24_tmux capture-pane -p -t "$SESS" 2>/dev/null | grep -qE '^(─)+$'; }
i=0; while [ "$i" -lt 120 ]; do box_ready && break; sleep 0.5; i=$((i + 1)); done
if ! box_ready; then
  printf '✗ 夹具：60s 内没看到输入框边框（pi 没起来？）\n'
  m24_tmux capture-pane -p -t "$SESS" 2>/dev/null | tail -12 | sed 's/^/     /'
  exit 1
fi
printf '· 输入框已画出，空闲 %ss（复现「PM 空闲」形状）…\n' "$IDLE_SECS"
sleep "$IDLE_SECS"

# M45：这轮 pi 真的有没有画更新横幅（决定下面的帧里能不能看到那个形状）
#   默认：有没有都行（判据层两条路都得对；门禁不因“今天有没有新版本”变红）
#   M45_REQUIRE_BANNER=1：要求必须有（证据轮次用；没横幅就红，不冒充现场证据）
M45_BANNER=absent
if m24_tmux capture-pane -p -t "$SESS" 2>/dev/null | grep -qE '^[[:space:]]*(Update Available|Package Updates Available)[[:space:]]*$'; then
  M45_BANNER=present
fi
if [ "$M45_BANNER" = "present" ]; then
  printf '· banner=present（输入框上方有更新横幅：这轮的空框判据就在这个形状上受考）\n'
elif [ "${M45_REQUIRE_BANNER:-0}" = "1" ]; then
  printf '· banner=absent（M45_REQUIRE_BANNER=1 但版本检查没拿到新版本/网络不通 —— 这轮不构成横幅现场证据）\n'
else
  printf '· banner=absent（今天没有新版本或网络不通；判据层在这里走的是无横幅分支）\n'
fi

snapshot() { # <标签>：原始帧（光标上下 4 行起）+ 守卫看到的东西
  local label="$1" cap cy from
  cap="$(m24_tmux capture-pane -p -t "$SESS" 2>/dev/null)"
  cy="$(m24_tmux display-message -p -t "$SESS" '#{cursor_y}' 2>/dev/null)"
  from=$(( ${cy:-0} - 4 )); [ "$from" -lt 1 ] && from=1
  printf '\n--- %s ---\n' "$label"
  printf '%s\n' "$cap" | cat -n | sed -n "${from},\$p" | sed 's/^/     /'
  m24_guard <<'EOS' | sed 's/^/  /'
printf 'verdict=%s state=%s\n' "$(team_delivery_verdict "$T")" "$(team_input_box_state "$T")"
printf 'box_rows=[%s]\n' "$(team_input_box_rows "$T" 2>/dev/null | tr '\n' '|')"
printf 'box_text=[%s]\n' "$(team_input_box_text "$T" 2>/dev/null | tr '\n' '|')"
EOS
}

snapshot "空闲空框（真实 pi）"

# M45：空闲帧必须是 EMPTY（pi 的更新横幅若被当成框内容，这里就是 BUSY）。
# 这一发的判定决定夹具退出码 —— 回归了就当场红，不只靠调用方 grep 日志。
m24_guard <<'EOS' | sed 's/^/  /' | tee "$TMP/m45-idle.log"
cy=$(( $(tmux display-message -p -t "$T" '#{cursor_y}' 2>/dev/null || printf '0') + 1 ))
cap="$(tmux capture-pane -p -t "$T" 2>/dev/null)"
printf 'M45 banner_rows=[%s]\n' "$(printf '%s\n' "$cap" | _team_box_banner_rows "$cy")"
if [ "$(team_delivery_verdict "$T")" = EMPTY ] && [ -z "$(team_input_box_text "$T" 2>/dev/null | tr -d '[:space:]')" ]; then
  printf 'M45 idle-read=EMPTY ok\n'
else
  printf 'M45 idle-read=NOT-EMPTY BAD\n'
fi
EOS

PAYLOAD="${PAYLOAD:-[auto] agent:dev2 · M24 · branch=task/M24-pm-draft-race · 状态=fixture
第二行：payload 的第二行
第三行：payload 的第三行}"
export PAYLOAD
m24_guard <<'EOS' | sed 's/^/  /'
text="$(team_deliver_text "$T" "$PAYLOAD")"
printf 'deliver_text_lines=%s bracketed=%s\n' "$(printf '%s' "$text" | grep -c '')" \
  "$(team_pane_bracketed_paste "$T" && printf yes || printf no)"
team_tmux_type_payload "$T" "$text" || printf '打字失败\n'
EOS
sleep 1.5
snapshot "粘贴之后（守卫的复检视角）"

if [ "$TIMELINE" = "1" ]; then
  # 投递路径的真实复检循环：paste 之后最多 4 拍 ×0.2s，每拍读框；读到的帧必须「停下来」且
  # holds_only。这里把每一拍的框文本与耗时打出来 —— 复检超时就是「明明是我们的粘贴却被判 race」。
  printf '\n--- 复检时间线（每次粘贴后重跑；4 拍 ×0.2s 是真实投递的预算）---\n'
  m24_guard <<'EOS' | sed 's/^/  /'
# 先按「一次一对」把框清干净，再粘贴（否则这次粘贴会追加到上一次的内容后面）
for _k in $(seq 1 60); do
  [ -z "$(team_input_box_text "$T" 2>/dev/null | tr -d '[:space:]')" ] && break
  tmux send-keys -t "$T" C-a C-k 2>/dev/null || true
  sleep 0.1
done
t0="$(date +%s%3N)"
text="$(team_deliver_text "$T" "$PAYLOAD")"
team_tmux_type_payload "$T" "$text" >/dev/null 2>&1 || true
prev="<unset>"; stable=0
for i in 1 2 3 4 5 6 7 8 9 10; do
  sleep 0.2
  now="$(team_input_box_text "$T" 2>/dev/null || true)"
  ho="$(team_box_holds_only "$T" "$text" && printf yes || printf no)"
  mr="$(team_box_mid_render "$now" && printf yes || printf no)"
  [ "$now" = "$prev" ] && stable=1 || stable=0
  printf 't=%sms try=%s stable=%s holds_only=%s mid_render=%s box=[%s]\n' \
    "$(( $(date +%s%3N) - t0 ))" "$i" "$stable" "$ho" "$mr" "$(printf '%s' "$now" | tr '\n' '|')"
  prev="$now"
done
# 收尾：把这次时间线实验留下的内容清掉（pacd 模式）
for _k in $(seq 1 30); do tmux send-keys -t "$T" C-a C-k 2>/dev/null || true; sleep 0.1; done
EOS
fi
m24_guard <<'EOS' | sed 's/^/  /'
printf 'HOLDS_ONLY=%s MID_RENDER=%s RETRACT_SAFE=%s\n' \
  "$(team_box_holds_only "$T" "$PAYLOAD" && printf yes || printf no)" \
  "$(team_box_mid_render "$(team_input_box_text "$T" 2>/dev/null)" && printf yes || printf no)" \
  "$(team_box_retract_safe "$T" "$PAYLOAD" && printf yes || printf no)"
if team_tmux_retract "$T" "$PAYLOAD"; then printf 'RETRACT=ok\n'; else printf 'RETRACT=failed\n'; fi
printf 'BOX_AFTER=[%s]\n' "$(team_input_box_text "$T" 2>/dev/null | tr '\n' '|')"
EOS

# 隔离自检：本夹具的 session 绝不能出现在真实默认 server 上
if [ -S "/tmp/tmux-$(id -u)/default" ] \
   && env -u TMUX -u TMUX_PANE tmux -S "/tmp/tmux-$(id -u)/default" has-session -t "$SESS" 2>/dev/null; then
  printf '✗ 隔离自检：夹具 session 出现在真实默认 server 上\n'
  exit 1
fi
printf '✓ 隔离自检：夹具 session 不在真实默认 server 上\n'
# M45：空闲空框读成 BUSY 是「更新横幅被当成框内容」的现场（真实现场：main 上 M28 段两红）
if ! grep -q 'M45 idle-read=EMPTY' "$TMP/m45-idle.log" 2>/dev/null; then
  printf '✗ M45：空闲空框没被判成 EMPTY（看上面的 M45 行 —— 横幅文字被读成了框内容？）\n'
  exit 1
fi
# 证据轮次：要求这轮真的有横幅（否则上面的绿不算横幅现场的绿）
if [ "${M45_REQUIRE_BANNER:-0}" = "1" ] && [ "$M45_BANNER" != "present" ]; then
  printf '✗ M45：M45_REQUIRE_BANNER=1 但这一轮没有横幅 —— 不能当作「判据层容忍横幅」的现场证据\n'
  exit 1
fi
