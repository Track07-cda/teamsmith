#!/usr/bin/env bash
# teamsmith · P171 翻转夹具：真实仓库 state/ 的反向守卫是**白名单**（只看夹具产品自己那族日志
# `signal-calls.log*`），不是 P168 那种「整份 state/ 前后逐字节相同 + 逐条排除活车道」——
# 后者在活仓库里不可满足：巡检每拍都往 state/capacity.log 追加，P168 把 bg.log 补进排除名单后，
# 下一个 tick 就轮到 capacity.log（PM 2026-10-02 的现场：合并 P168 后 `--select 58` 仍红 1 条）。
#
#   bash skills/teamsmith/tests/flip-p171.sh          # 七面
#   bash skills/teamsmith/tests/flip-p171.sh --keep   # 保留临时根与七份日志
#
# 本夹具在「真夹具 + 它依赖的 lib/shim/common.sh」的**副本**里跑真夹具（当前树一个字节不动），
# 副本自带一个 fake 仓库根，`.pi/team/state/` 就在副本里 —— 所有写入都落副本。
# 七面：
#   ① 受看面红：副本里插一腿「漏钉」的闸门调用（TEAM_SIGNAL_CALLS_LOG 指到真实 state 的配置路径）
#      → 必须红，且差异行点名 signal-calls.log（白名单承重：产品真写进来就看得见）；
#   ② 活车道绿：夹具跑动中往 capacity.log / nudges.log / bg.log / panel.log / dev.env /
#      inbox-watch/* 写（今天的现场）→ 必须全绿（白名单只认产品那族，活运行时的车道不进判据）；
#   ③ 整份快照变异红：把受看面放大成 `*`（修复前那种「整份 state/」判据的最小形状）+ **同一批**写入
#      → 必须红，且差异行点名活车道（证明 ② 的写入确实落在两次快照之间，也证明这次修的是承重的那条）；
#   ④ 还原绿：受看面还原 → 同一批写入又绿（证伪「③的红是夹具自己坏」）；
#   ⑤ 签名红：往真实 state 的**族外**文件里种诱饵名 → 签名断言必须红（签名扫全树，白名单外也管）；
#   ⑥ runner 车道里的签名绿：种进 bg/<id>.log → 必须绿（runner 抄的正是本夹具自己的 stdout，
#      不是夹具写了账本；这条就是 P168 那个假红的边界）；
#   ⑦ 受看面空转变异红：受看面改成一个不存在的名字 → 段尾 watch-shape 探针必须红（判据不是橡皮章）。
# 退出码：0 = 七面都符合预期 ｜ 1 = 期望不成立（日志路径会打印）｜ 2 = 环境/锚点不成立。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# shellcheck source=lib/tmp-root.sh
. "$SELF_DIR/lib/tmp-root.sh"

KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --keep) KEEP=1; shift ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    *) printf 'flip-p171: 未知参数 %s\n' "$1" >&2; exit 2 ;;
  esac
done
[ "$KEEP" = "1" ] && export TEAM_TMP_KEEP=1
TMP="$(tmp_root_create flip-p171)" || exit 3
WRITER_PID=""
cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0
  [ -n "$WRITER_PID" ] && kill -TERM "$WRITER_PID" 2>/dev/null || true
  [ "$KEEP" = "0" ] && tmp_root_reap_all
  return 0
}
trap cleanup EXIT

PASS=0
FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
hdr() { printf '\n== %s ==\n' "$1"; }
plain() { sed 's/\x1b\[[0-9;]*m//g' "$1"; }
reds()  { plain "$1" | grep -a '^  ✗'; }
has()   { plain "$1" | grep -aqF -- "$2"; }
has_re() { plain "$1" | grep -aEq -- "$2"; }
rc_is() { [ "$2" = "$3" ] && ok "$1" || bad "$1（期望 rc=$3，实际 rc=$2）"; }
rc_not() { [ "$2" != "$3" ] && ok "$1" || bad "$1（不该是 rc=$3）"; }

# ── 副本：真夹具 + 它依赖的 lib / shim / common.sh（当前树一个字节不动）────────────────────────
SCRATCH="$TMP/tree"
STATE="$SCRATCH/.pi/team/state"
FIXTURE="$SCRATCH/skills/teamsmith/tests/signal-gate.sh"
FIXTURE_SRC="$SKILL_DIR/tests/signal-gate.sh"
mkdir -p "$SCRATCH/skills/teamsmith/tests/lib" "$SCRATCH/skills/teamsmith/scripts/lib" || exit 2
cp -a "$SKILL_DIR/scripts/shim" "$SCRATCH/skills/teamsmith/scripts/shim" || exit 2
cp -a "$SKILL_DIR/scripts/lib/common.sh" "$SCRATCH/skills/teamsmith/scripts/lib/common.sh" || exit 2
cp -a "$SKILL_DIR/tests/lib/tmp-root.sh" "$SCRATCH/skills/teamsmith/tests/lib/tmp-root.sh" || exit 2
for f in "$FIXTURE_SRC" "$SCRATCH/skills/teamsmith/scripts/shim/signal-gate" \
         "$SCRATCH/skills/teamsmith/scripts/shim/pkill" "$SCRATCH/skills/teamsmith/scripts/shim/killall" \
         "$SCRATCH/skills/teamsmith/scripts/lib/common.sh" "$SCRATCH/skills/teamsmith/tests/lib/tmp-root.sh"; do
  [ -e "$f" ] || { printf 'flip-p171: 副本缺 %s\n' "$f" >&2; exit 2; }
done
copy_fixture() { cp -a "$FIXTURE_SRC" "$FIXTURE" || return 1; }
# 只改**这一整行**（逐字比较，不用正则 —— 名单那行自带 `*`，sed/grep 的模式会把 `g*` 当成量词）
mutate_fixture() { # <旧整行> <新整行>
  awk -v old="$1" -v new="$2" '$0 == old { $0 = new; n++ } { print } END { exit (n == 1 ? 0 : 1) }' \
    "$FIXTURE" > "$TMP/fixture-mut.sh" || return 1
  cp -a "$TMP/fixture-mut.sh" "$FIXTURE"
}
line_is() { grep -qxF -- "$1" "$FIXTURE"; }

# 每个用例都从同一份干净 fake state 起步（sentinel.txt 两份快照都含它 —— 它不该造成红）
reset_state() {
  rm -rf "$STATE"; mkdir -p "$STATE/bg" "$STATE/inbox-watch" || return 1
  printf 'untouched\n' > "$STATE/sentinel.txt"
}

# ── 锚点：白名单那一行与「私有根」那一行都必须**逐字**长这样，翻转才敢只改/只插一处 ──────────
WATCH_FIXED="FIXTURE_WRITE_WATCH='signal-calls.log*'"
WATCH_BLANKET="FIXTURE_WRITE_WATCH='*'"
WATCH_VACUOUS="FIXTURE_WRITE_WATCH='no-such-watch-family*'"
LEAK_ANCHOR='LOGD="$TMP/logs"; mkdir -p "$LOGD"'
copy_fixture || exit 2
line_is "$WATCH_FIXED" || {
  printf 'flip-p171: 副本里没有锚点 %s（夹具的白名单写法变了？）\n' "$WATCH_FIXED" >&2; exit 2; }
line_is "$LEAK_ANCHOR" || {
  printf 'flip-p171: 副本里没有锚点 %s（夹具的私有根那一行变了？）\n' "$LEAK_ANCHOR" >&2; exit 2; }

# ── 活车道写入器：夹具跑动中，活着的运行时每拍都在写这些东西（名字取自真仓库的 state/）──────
writer_start() {
  mkdir -p "$TMP/writer" || return 1
  (
    local i=0
    while [ "$i" -lt 3000 ]; do
      printf '%s ram=512MB swap=1GB\n' "$(date -u +%FT%TZ)" >> "$STATE/capacity.log"
      printf '%s nudge seat=dev\n' "$(date -u +%FT%TZ)" >> "$STATE/nudges.log"
      printf '%s wake count=1 ids=w0\n' "$(date -u +%FT%TZ)" >> "$STATE/bg.log"
      printf '%s panel page=1\n' "$(date -u +%FT%TZ)" >> "$STATE/panel.log"
      printf 'model=x\nwindow=w0\ntask=P171\nbranch=task/P171-apply\n' > "$STATE/dev.env"
      printf 'msg %s\n' "$i" >> "$STATE/inbox-watch/w0.msg"
      i=$((i + 1)); sleep 0.01
    done
  ) &
  WRITER_PID=$!
}
writer_stop() { # 只收自己 spawn 时记下的那个 pid（纪律：不按名字/模式选进程）
  [ -n "$WRITER_PID" ] || return 0
  kill -TERM "$WRITER_PID" 2>/dev/null || true
  wait "$WRITER_PID" 2>/dev/null || true
  WRITER_PID=""
}

# ── 三种跑法 ──────────────────────────────────────────────────────────────────────────────────
CASE_LOG=""
run_fixture() { # <名字> → 夹具退出码；stdout+stderr 在 $CASE_LOG
  CASE_LOG="$TMP/$1.log"
  local tdir="$TMP/window-$1"; rm -rf "$tdir"; mkdir -p "$tdir"
  ( cd "$SCRATCH" && TMPDIR="$tdir" bash "$FIXTURE" ) >"$CASE_LOG" 2>&1
  return $?
}
run_plain() { # <名字> <plant: none|outside|lane>
  reset_state || return 99
  case "$2" in
    outside) printf 'planted %s here\n' "$SIG" >> "$STATE/capacity.log" ;;
    lane)    printf 'planted %s here\n' "$SIG" >> "$STATE/bg/run-1.log" ;;
  esac
  run_fixture "$1"
}
run_with_writer() { # <名字>（活车道写入器全程在写）
  reset_state || return 99
  writer_start || return 99
  local rc=0
  run_fixture "$1" || rc=$?
  writer_stop
  return "$rc"
}

SIG="p159-""decoy-"
GUARD='真实仓库 state/ 受看面'

# ── ① 受看面红：插一腿「漏钉」的闸门调用 ───────────────────────────────────────────────────────
hdr "① 受看面红：副本里插一腿漏钉的闸门调用（写进真实 state 的 signal-calls.log）→ 必须红"
LEAK_LEG='env PATH="$GATE_DIR:$PATH" TEAM_SIGNAL_REAL="$STUB" TEAM_SIGNAL_CALLS_LOG="$REAL_STATE/signal-calls.log" STUB_LOG="$LOGD/stub-leak.log" "$GATE_DIR/pkill" -f p171-leak >/dev/null 2>&1 || true'
awk -v anchor="$LEAK_ANCHOR" -v leg="$LEAK_LEG" '$0 == anchor { print; print leg; next } { print }' \
  "$FIXTURE" > "$TMP/fixture-leak.sh" && cp -a "$TMP/fixture-leak.sh" "$FIXTURE"
grep -qxF "$LEAK_LEG" "$FIXTURE" || { printf 'flip-p171: 漏钉那一腿没插进去\n' >&2; exit 2; }
RC=0; run_plain leak-red none || RC=$?
printf '  夹具 rc=%s；日志 %s\n' "$RC" "$CASE_LOG"
rc_not "漏钉的闸门调用让夹具非 0 退出" "$RC" "0"
case "$(reds "$CASE_LOG")" in
  *"$GUARD"*) ok "红的是反向守卫那条断言" ;;
  *) bad "反向守卫没有变红（红的行：$(reds "$CASE_LOG" | head -2 | tr '\n' '|')）" ;;
esac
has_re "$CASE_LOG" '[0-9a-f]{64}  signal-calls\.log' \
  && ok "快照的「实际」一侧带着 signal-calls.log 的哈希行（白名单确实盯着产品那族）" \
  || bad "快照里没有 signal-calls.log 的哈希行"
copy_fixture; RC=0; run_plain leak-restored none || RC=$?
rc_is "把漏钉那一腿去掉（同一份 state）→ 又绿（①的红来自那一腿）" "$RC" "0"
[ -z "$(reds "$CASE_LOG")" ] && ok "还原后整段零 ✗" || bad "还原后还有红：$(reds "$CASE_LOG" | head -3 | tr '\n' '|')"

# ── ② 活车道绿（今天的现场）───────────────────────────────────────────────────────────────────
hdr "② 活车道绿：夹具跑动中写 capacity.log / nudges.log / bg.log / panel.log / dev.env / inbox-watch/* → 必须全绿"
RC=0; run_with_writer lanes-green || RC=$?
printf '  夹具 rc=%s；日志 %s\n' "$RC" "$CASE_LOG"
rc_is "夹具全绿（rc=0）" "$RC" "0"
[ -s "$STATE/capacity.log" ] && ok "写入确实发生了（state/capacity.log 非空）" || bad "capacity.log 不在/是空的（写入没生效）"
has "$CASE_LOG" "✓ $GUARD" && ok "反向守卫那条断言是 ✓" || bad "反向守卫那条断言不是 ✓"
[ -z "$(reds "$CASE_LOG")" ] && ok "整段零 ✗" || bad "整段有红：$(reds "$CASE_LOG" | head -3 | tr '\n' '|')"

# ── ③ 整份快照变异红：受看面放大成 `*` ────────────────────────────────────────────────────────
hdr "③ 整份快照变异红：受看面放大成 $WATCH_BLANKET（修复前那种判据）+ 同一批写入 → 必须红"
mutate_fixture "$WATCH_FIXED" "$WATCH_BLANKET" && line_is "$WATCH_BLANKET" \
  || { printf 'flip-p171: 变异没生效\n' >&2; exit 2; }
RC=0; run_with_writer blanket-red || RC=$?
printf '  夹具 rc=%s；日志 %s\n' "$RC" "$CASE_LOG"
rc_not "「整份 state/」判据下，同一批写入变红（rc≠0）" "$RC" "0"
case "$(reds "$CASE_LOG")" in
  *"$GUARD"*) ok "红的是反向守卫那条断言（放大成 * 之后它把活车道也看进去了）" ;;
  *) bad "反向守卫没有变红" ;;
esac
has_re "$CASE_LOG" '[0-9a-f]{64}  capacity\.log' \
  && ok "快照的「实际」一侧带着 capacity.log 的哈希行（② 的写入确实落在两次快照之间）" \
  || bad "快照里没有 capacity.log 的哈希行（② 的写入没落在窗口里）"

# ── ④ 还原绿 ─────────────────────────────────────────────────────────────────────────────────
hdr "④ 还原绿：受看面还原成 $WATCH_FIXED → 同一批写入又绿"
mutate_fixture "$WATCH_BLANKET" "$WATCH_FIXED" && line_is "$WATCH_FIXED" \
  || { printf 'flip-p171: 还原没生效\n' >&2; exit 2; }
RC=0; run_with_writer lanes-green-again || RC=$?
printf '  夹具 rc=%s；日志 %s\n' "$RC" "$CASE_LOG"
rc_is "夹具又全绿（rc=0）" "$RC" "0"
has "$CASE_LOG" "✓ $GUARD" && ok "反向守卫那条断言是 ✓" || bad "反向守卫那条断言不是 ✓"
[ -z "$(reds "$CASE_LOG")" ] && ok "整段零 ✗" || bad "整段有红：$(reds "$CASE_LOG" | head -3 | tr '\n' '|')"

# ── ⑤ 签名红：族外文件里种诱饵名 ──────────────────────────────────────────────────────────────
hdr "⑤ 签名红：往真实 state 的族外文件（capacity.log）里种诱饵名 → 签名断言必须红"
RC=0; run_plain signature-outside outside || RC=$?
printf '  夹具 rc=%s；日志 %s\n' "$RC" "$CASE_LOG"
rc_not "种了诱饵名 → 夹具非 0 退出" "$RC" "0"
RED_LINE="$(reds "$CASE_LOG" | grep -aF '诱饵名签名' | head -1)"
case "$RED_LINE" in
  *"capacity.log"*) ok "签名断言红且点名 capacity.log（签名扫全树，白名单之外也管）" ;;
  *) bad "签名断言没按预期红/点名：${RED_LINE:-无}" ;;
esac

# ── ⑥ runner 车道里的签名绿 ───────────────────────────────────────────────────────────────────
hdr "⑥ runner 车道绿：诱饵名种进 bg/<id>.log（runner 抄的是夹具自己的 stdout）→ 必须绿"
RC=0; run_plain signature-lane lane || RC=$?
printf '  夹具 rc=%s；日志 %s\n' "$RC" "$CASE_LOG"
rc_is "夹具全绿（rc=0）" "$RC" "0"
has "$CASE_LOG" "✓ 真实 state（不含 runner 自己的作业车道" && ok "签名断言是 ✓（bg 车道被放过）" \
  || bad "签名断言不是 ✓"
[ -z "$(reds "$CASE_LOG")" ] && ok "整段零 ✗" || bad "整段有红：$(reds "$CASE_LOG" | head -3 | tr '\n' '|')"

# ── ⑦ 受看面空转变异红 ────────────────────────────────────────────────────────────────────────
hdr "⑦ 受看面空转变异红：受看面改成 $WATCH_VACUOUS → watch-shape 探针必须红（判据不是橡皮章）"
mutate_fixture "$WATCH_FIXED" "$WATCH_VACUOUS" && line_is "$WATCH_VACUOUS" \
  || { printf 'flip-p171: 空转变异没生效\n' >&2; exit 2; }
RC=0; run_plain vacuous-red none || RC=$?
printf '  夹具 rc=%s；日志 %s\n' "$RC" "$CASE_LOG"
rc_not "受看面空转 → 夹具非 0 退出" "$RC" "0"
RED_LINE="$(reds "$CASE_LOG" | grep -aF '判据空转' | head -1)"
[ -n "$RED_LINE" ] && ok "形状探针红并点名「判据空转」：${RED_LINE#  ✗ }" \
  || bad "形状探针没红（受看面空转没被发现）：$(reds "$CASE_LOG" | head -2 | tr '\n' '|')"
copy_fixture; line_is "$WATCH_FIXED" || { printf 'flip-p171: 收尾还原没生效\n' >&2; exit 2; }

# ── 结果 ─────────────────────────────────────────────────────────────────────────────────────
printf '\n== flip-p171 结果 == ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
  printf '\033[32m七面都符合预期（受看面红 / 活车道绿 / 整份快照变异红 / 还原绿 / 签名红 / runner 车道绿 / 空转红）\033[0m\n'
  [ "$KEEP" = "1" ] && printf '现场保留在 %s\n' "$TMP"
  exit 0
fi
printf '\033[31m有 %d 条不符合预期（日志在 %s）\033[0m\n' "$FAIL" "$TMP"
exit 1
