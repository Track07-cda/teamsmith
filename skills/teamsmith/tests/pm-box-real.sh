#!/usr/bin/env bash
# M24 夹具：**真实 pi 窗格**上的投递守卫体检（空闲空框 / 粘贴后 / 收回）。
#
#   bash tests/pm-box-real.sh [--idle-secs N] [--keep] [--payload <文字>] [--expect-overlay]
#   bash tests/pm-box-real.sh --frame <帧文件> --cursor <行>       # 纯帧判定（不开 tmux / 不跑 pi）
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
# P59（信任弹窗）：项目里装着 `.pi/skills/`（Pi 的信任清单里有 `skills` 这个项目资源）时，
# 第一次交互运行的 pi 会画**项目信任弹窗**（`Trust project folder?` … `Do not trust`）——
# 一个整屏覆盖层，**弹窗里一个字都没有**。裸判据（只有 EMPTY / 非 EMPTY）会把它读成
# 「非空输入框」（找不到框 → UNKNOWN；光标落进弹窗 → 把弹窗自己的两条整行 ─ 配成框、把问题与
# 选项读成框内容 → BUSY），于是夹具对着弹窗跑投递步骤。现在：
#   · 就绪只认**判定定位到的空输入框**（连续两次静默读同一帧），不认「第一条整行 ─」；
#   · 覆盖层在场 → 打印 `overlay=trust-prompt`、保留最后一帧、非零退出，**一个键都不敲**；
#   · 夹具照旧跑在装了 `.pi/skills/` 的项目里（不 --no-skills 绕过），用**单次运行的信任覆盖**
#     （`pi --approve`）到达空框，**不写** Pi 的 trust store（收尾处断言前后指纹一致）；
#   · `--expect-overlay` 是文档化的覆盖层模式：故意**不带**覆盖启动，期待弹窗、点名它、0 退出，
#     投递步骤一步不跑；`M24_TRUST=prompt` 不带 `--expect-overlay` 就是「对着弹窗跑投递」的红侧；
#   · `--frame <文件> --cursor <行>` 是纯帧判定（同一份共享判据，FAST 门禁与翻转都走它）；
#   · `M24_OVERLAY_DETECT=0` 关掉覆盖层判据（翻转控制）：同一份真帧必须退回 `idle-read=NOT-EMPTY`。
#
# 隔离纪律（M23 事故 + PM 要求）：只用私有 tmux socket（TMUX_TMPDIR 指向本夹具的临时目录），
# 并且显式 unset TMUX/TMUX_PANE —— 否则 tmux 客户端会走 $TMUX 指的那个（真实）server。
# 脚本结尾会断言：本夹具的 session 没有出现在真实默认 server 上。
#
# 铁律：不读不写 ~/.pi 的会话文件（pi 用 --no-session + --session-dir 指向临时目录），
# 不碰真实 tmux server，不写 Pi 的 trust store。
set -uo pipefail

SKILL_DIR="${M24_SKILL_DIR:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"   # 可指向另一份 skill 副本（flip 证据用）
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$SKILL_DIR/tests/lib/tmp-root.sh"
TEAM="bash $SKILL_DIR/scripts/team"
PI_BIN="${M24_PI_BIN:-$HOME/.bun/bin/pi}"
[ -x "$PI_BIN" ] || PI_BIN="$(command -v pi 2>/dev/null || true)"
# P59：覆盖层判据 + 帧级判定（与真 pane 共用同一条实现；框几何仍来自生产 outbox.sh）
. "$SKILL_DIR/tests/lib/box-judge.sh"

IDLE_SECS=8; KEEP="${TEAM_M24_KEEP:-0}"; PAYLOAD=""; TIMELINE=0; RETRACT_MODE="${M24_RETRACT_MODE:-burst}"
# P67：就绪门的拍数上限（每拍 0.5s）。默认 120 = 60s；定格帧夹具（永远放行不了）把它调小，
# 让「拒绝」这一段不必等满 60s —— 只改测试时长，不改就绪判据。
READY_TRIES="${M24_READY_TRIES:-120}"
FRAME=""; CURSOR=""; EXPECT_OVERLAY=0; TRUST_MODE="${M24_TRUST:-approve}"
while [ $# -gt 0 ]; do
  case "$1" in
    --idle-secs) IDLE_SECS="${2:-8}"; shift 2 ;;
    --keep) KEEP=1; shift ;;
    --payload) PAYLOAD="${2:-}"; shift 2 ;;
    --timeline) TIMELINE=1; shift ;;
    --retract-mode) RETRACT_MODE="${2:-burst}"; shift 2 ;;
    --frame) FRAME="${2:-}"; shift 2 ;;
    --cursor) CURSOR="${2:-}"; shift 2 ;;
    --expect-overlay) EXPECT_OVERLAY=1; TRUST_MODE="prompt"; shift ;;
    *) shift ;;
  esac
done
case "$IDLE_SECS" in ''|*[!0-9]*) IDLE_SECS=8 ;; esac
case "$READY_TRIES" in ''|*[!0-9]*) READY_TRIES=120 ;; esac
case "$TRUST_MODE" in approve|prompt) ;; *) TRUST_MODE=approve ;; esac

# P59 纯帧模式：帧进、判定出（不开 tmux、不跑 pi；FAST 门禁与红/绿翻转都走这条路）。
if [ -n "$FRAME" ]; then
  [ -f "$FRAME" ] || { printf '✗ 帧文件不存在：%s\n' "$FRAME" >&2; exit 2; }
  case "$CURSOR" in ''|*[!0-9]*) printf '✗ --frame 需要 --cursor <光标行 1-based>\n' >&2; exit 2 ;; esac
  # P67 红侧（可证伪，**不是产品开关**）：把边框邻行谓词影子成「一律 chrome」＝ 老的槽位排除，
  # 于是 0.87.0 的单行草稿帧必须退回 idle-read=EMPTY。只作用于这条纯帧路径（真 pane 的守卫
  # 跑在 m24_guard 子进程里，不继承影子）。
  [ "${M24_SHADOW_CHROME:-0}" = "1" ] && _team_box_row_is_chrome() { return 0; } || true
  printf 'frame=%s cursor=%s mode=frame\n' "$FRAME" "$CURSOR"
  M24_FRAME_OUT="$(team_box_frame_verdict "$CURSOR" < "$FRAME")"; M24_FRAME_RC=$?
  printf '%s\n' "$M24_FRAME_OUT"
  # P67：把提取出来的框文本也打出来 —— 生产提取（_team_box_text_of_frame）与帧级判定必须
  # 同源同结果，纯帧探针靠这一行做逐字对比。覆盖层帧没有「框」可言（rc 1 → 空）。
  M24_FRAME_TEXT="$(_team_box_text_of_frame "$CURSOR" < "$FRAME" 2>/dev/null | tr '\n' '|')"
  printf 'box_text=[%s]\n' "${M24_FRAME_TEXT%|}"
  exit "$M24_FRAME_RC"
fi

[ "${KEEP:-0}" = "1" ] && export TEAM_TMP_KEEP=1
TMP="$(tmp_root_create pm-box)" || exit 3
SESS="teamsmith-pmbox-$$"
SOCKDIR="$TMP/tmux"
REPO="$TMP/proj"
mkdir -p "$SOCKDIR" "$REPO" "$TMP/pi-sessions"

cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0
  m24_tmux kill-session -t "$SESS" 2>/dev/null || true
  m24_tmux kill-server 2>/dev/null || true
  if [ "$KEEP" = "1" ]; then printf '保留临时目录：%s\n' "$TMP"; else tmp_root_reap_all; fi
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
        . "'"$SKILL_DIR"'/tests/lib/box-judge.sh"
        team_load_config 2>/dev/null || true
        T="'"$SESS"'"
        PAYLOAD="${M24_PAYLOAD:-}"
        source /dev/stdin
      ' )
}
# Pi 的 trust store 指纹（P59：夹具一个字节都不许写它；容器里是 absent）
m24_trust_fp() {
  local f="$HOME/.pi/agent/trust.json"
  if [ -e "$f" ]; then
    printf 'sha256=%s mtime=%s\n' "$(sha256sum "$f" 2>/dev/null | LC_ALL=C awk '{print $1}')" \
      "$(date -r "$f" +%s 2>/dev/null || stat -c %Y "$f" 2>/dev/null || printf '?')"
  else
    printf 'absent\n'
  fi
}

printf 'M24 真实 pi 窗格体检 · pi=%s · 私有 socket=%s · idle=%ss · trust=%s%s\n' \
  "${PI_BIN:-（找不到 pi）}" "$SOCKDIR" "$IDLE_SECS" "$TRUST_MODE" \
  "$([ "$EXPECT_OVERLAY" = 1 ] && printf ' --expect-overlay' || printf '')"
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
# P59：默认带单次运行的信任覆盖（--approve）：项目里装着 .pi/skills/（Pi 信任清单里的资源），
#      不带覆盖就画信任弹窗；覆盖只作用于这一轮，trust store 前后指纹由收尾处断言。
M24_PI_ARGS=(--no-session --session-dir "$TMP/pi-sessions")
[ "$TRUST_MODE" = "approve" ] && M24_PI_ARGS+=(--approve)
TRUST_BEFORE="$(m24_trust_fp)"
pi_cmd="HOME=$(printf '%q' "$HOME") $(printf '%q' "$PI_BIN")"
for _a in "${M24_PI_ARGS[@]}"; do pi_cmd="$pi_cmd $(printf '%q' "$_a")"; done
m24_tmux new-session -d -s "$SESS" -x 120 -y 30 -c "$REPO" "$pi_cmd" 2>/dev/null || true

# P59：就绪 = 判定**定位到输入框且框是空的**（连续两次静默读同一帧），不是「看见第一条整行 ─」——
# 信任弹窗自带两条整行 ─，裸等待会被它骗过，然后弹窗就被当成「非空输入框」。
# 覆盖层在场 → 立刻停（不等满 60s），保留最后一帧交给下面点名。
m24_cap() { m24_tmux capture-pane -p -t "$SESS" 2>/dev/null; }
m24_cy()  { m24_tmux display-message -p -t "$SESS" '#{cursor_y}' 2>/dev/null; }
READY=0; LAST_STATE=""; LAST_CAP=""; FAIL_RC=0
prev_cap=""; prev_state=""; i=0
while [ "$i" -lt "$READY_TRIES" ]; do
  cap="$(m24_cap)"; cy="$(m24_cy)"
  if [ -z "$cy" ]; then
    state="no-pane"
  else
    state="$(printf '%s\n' "$cap" | team_box_frame_verdict "$(( cy + 1 ))" 2>/dev/null || true)"
    [ -n "$state" ] || state="idle-read=NOT-EMPTY"
  fi
  LAST_CAP="$cap"; LAST_STATE="$state"
  [ "$state" = "overlay=trust-prompt" ] && break
  if [ "$state" = "idle-read=EMPTY" ] && [ "$prev_state" = "idle-read=EMPTY" ] && [ "$cap" = "$prev_cap" ]; then
    READY=1; break
  fi
  prev_cap="$cap"; prev_state="$state"
  sleep 0.5; i=$((i + 1))
done

if [ "$READY" = "1" ]; then
  printf '· 就绪：判定定位到输入框且为空（连续两次静默读同一帧），空闲 %ss（复现「PM 空闲」形状）…\n' "$IDLE_SECS"
  sleep "$IDLE_SECS"
elif [ "$LAST_STATE" = "overlay=trust-prompt" ] && [ "$EXPECT_OVERLAY" = "1" ]; then
  printf 'overlay=trust-prompt\n'
  printf '✓ 覆盖层已点名（--expect-overlay）：Pi 的项目信任弹窗 —— 一个键都没敲进它，投递步骤一步没跑（都排在就绪门之后）\n'
  RUN_STEPS=0
else
  printf '✗ 夹具：就绪门 %s 拍（约 %ss）内没有放行（最后判定=%s）—— 没有定位到空的输入框\n' \
    "$READY_TRIES" "$((READY_TRIES / 2))" "${LAST_STATE:-unknown}"
  if [ "$LAST_STATE" = "overlay=trust-prompt" ]; then
    printf 'overlay=trust-prompt\n'
    printf '✗ 覆盖层挡住了输入框：一个键都不敲，投递步骤一步不跑（要接受它请显式 --expect-overlay）\n'
  fi
  printf -- '--- 最后一帧（原样，留给报告）---\n'
  printf '%s\n' "$LAST_CAP" | cat -n | sed 's/^/     /'
  RUN_STEPS=0; FAIL_RC=1
fi
[ "$READY" = "1" ] && RUN_STEPS=1 || true

if [ "$RUN_STEPS" = "1" ]; then
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
fi

# 隔离自检：本夹具的 session 绝不能出现在真实默认 server 上
if [ -S "/tmp/tmux-$(id -u)/default" ] \
   && env -u TMUX -u TMUX_PANE tmux -S "/tmp/tmux-$(id -u)/default" has-session -t "$SESS" 2>/dev/null; then
  printf '✗ 隔离自检：夹具 session 出现在真实默认 server 上\n'
  exit 1
fi
printf '✓ 隔离自检：夹具 session 不在真实默认 server 上\n'

# P59：Pi 的 trust store 前后必须逐字节一致（单次运行的覆盖不改它；容器里的 HOME 本来就没有它）
TRUST_AFTER="$(m24_trust_fp)"
if [ "$TRUST_AFTER" != "$TRUST_BEFORE" ]; then
  printf '✗ trust store 被写了：$HOME/.pi/agent/trust.json\n  前：%s\n  后：%s\n' "$TRUST_BEFORE" "$TRUST_AFTER"
  exit 1
fi
printf '✓ trust store 未变（$HOME/.pi/agent/trust.json：%s）\n' "$TRUST_BEFORE"

if [ "$RUN_STEPS" = "1" ]; then
  # P59：现场形状的自证 —— ①这一轮从头到尾都在装了 .pi/skills 的项目里跑（没有用 --no-skills 躲开要验的形状）；
  # ②投递步骤开始时，覆盖层判据不再看到任何覆盖层（就绪门才放的行）。
  if [ -e "$REPO/.pi/skills/teamsmith" ] || [ -L "$REPO/.pi/skills/teamsmith" ]; then
    printf '✓ .pi/skills/teamsmith 仍在位（这一轮跑在 team init 装过的项目里）\n'
  else
    printf '✗ 夹具项目里 .pi/skills/teamsmith 不在了（安装被绕过？）\n'
    exit 1
  fi
  if printf '%s\n' "$(m24_cap)" | team_box_overlay_kind | grep -q .; then
    printf '✗ 就绪之后仍看到覆盖层 —— 投递步骤不该在覆盖层下跑\n'
    exit 1
  fi
  printf 'overlay_absent=ok（就绪与投递时刻都没有覆盖层）\n'
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
fi
exit "$FAIL_RC"
