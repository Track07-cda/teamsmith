#!/usr/bin/env bash
# teamsmith · P168 翻转夹具：反向守卫的排除面 = 后台作业并发车道（bg/ 与 bg.log），一条不多一条不少
#
#   bash skills/teamsmith/tests/flip-p168.sh          # 四面：车道绿 / 车道外红 / 变异红 / 还原绿
#   bash skills/teamsmith/tests/flip-p168.sh --keep   # 保留临时根与四份日志
#
# 现场（P168，2026-10-02 实测）：PM 用 `team_bg_run` 跑门禁 → runner 在门禁**跑动中**往
# `.pi/team/state/bg.log` 追加一行账本 → signal-gate.sh 的反向守卫在两次快照之间看到它变了 →
# 整段唯一一条红是**假红**（同一个夹具在没有 bg.log 的干净克隆里是绿的：是排除面不够，不是产品）。
#
# 本夹具在 `tests/signal-gate.sh` + 它依赖的 `tests/lib/tmp-root.sh` / `scripts/shim/` 的**副本**里跑真
# 夹具（当前树一个字节不动），且写入发生在夹具**跑动中**：等夹具建出自己私有根里的 `logs/` 再写。
# 源码顺序：REAL_BEFORE 快照（第一段之前）→ … → `LOGD=mkdir -p logs` → RA1/RA2 → REAL_AFTER 快照，
# 所以等到 logs/ 之后的写入必然夹在两个快照之间（写入后夹具还要跑完 RA1/RA2，实测 ≥300ms）。
# 四面：
#   ① 车道绿：跑动中追加 `state/bg.log` → 夹具必须全绿（今天的现场，修好后就是这个形状）；
#   ② 车道外红：跑动中写 `state/other.log` → 必须红，且红的差异行点名 other.log（排除面不是「什么都放过」）；
#   ③ 变异红：把副本的 `BG_LANE_PATHS` 改回修复前的 `(bg)` → **同样**的写入必须红（排除面承重；同时这也是
#      「①的写入确实落在窗口里」的证据 —— 写入若落在窗口外，③不可能红）；
#   ④ 还原绿：把清单还原 → 同样的写入又绿（证明③的红来自那一处改动，不是夹具自己坏）。
#
# 退出码：0 = 四面都符合预期 ｜ 1 = 期望不成立（四份日志路径会打印）｜ 2 = 环境/锚点不成立。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# shellcheck source=lib/tmp-root.sh
. "$SELF_DIR/lib/tmp-root.sh"

KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --keep) KEEP=1; shift ;;
    -h|--help) sed -n '2,23p' "$0"; exit 0 ;;
    *) printf 'flip-p168: 未知参数 %s\n' "$1" >&2; exit 2 ;;
  esac
done
[ "$KEEP" = "1" ] && export TEAM_TMP_KEEP=1
TMP="$(tmp_root_create flip-p168)" || exit 3
cleanup() { [ "${BASHPID:-$$}" = "$$" ] && [ "$KEEP" = "0" ] && tmp_root_reap_all; }
trap cleanup EXIT

PASS=0
FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
hdr() { printf '\n== %s ==\n' "$1"; }
plain() { sed 's/\x1b\[[0-9;]*m//g' "$1"; }
reds()  { plain "$1" | grep -a '^  ✗'; }
has()   { plain "$1" | grep -aqF -- "$2"; }
rc_is() { [ "$2" = "$3" ] && ok "$1" || bad "$1（期望 rc=$3，实际 rc=$2）"; }
rc_not() { [ "$2" != "$3" ] && ok "$1" || bad "$1（不该是 rc=$3）"; }

# ── 副本：夹具 + 它依赖的 lib / shim（当前树一个字节不动）──────────────────────────────────────
SCRATCH="$TMP/tree"
STATE="$SCRATCH/.pi/team/state"
FIXTURE="$SCRATCH/skills/teamsmith/tests/signal-gate.sh"
mkdir -p "$SCRATCH/skills/teamsmith/tests/lib" "$SCRATCH/skills/teamsmith/scripts" "$STATE" || exit 2
cp -a "$SKILL_DIR/scripts/shim" "$SCRATCH/skills/teamsmith/scripts/shim" || exit 2
cp -a "$SKILL_DIR/tests/lib/tmp-root.sh" "$SCRATCH/skills/teamsmith/tests/lib/tmp-root.sh" || exit 2
cp -a "$SKILL_DIR/tests/signal-gate.sh" "$FIXTURE" || exit 2
for f in "$FIXTURE" "$SCRATCH/skills/teamsmith/scripts/shim/signal-gate" \
         "$SCRATCH/skills/teamsmith/scripts/shim/pkill" "$SCRATCH/skills/teamsmith/scripts/shim/killall" \
         "$SCRATCH/skills/teamsmith/tests/lib/tmp-root.sh"; do
  [ -e "$f" ] || { printf 'flip-p168: 副本缺 %s\n' "$f" >&2; exit 2; }
done

# 每个用例都从同一份干净 state 起步（只有 sentinel.txt；两份快照都含它 → 它不该造成红）
reset_state() {
  rm -rf "$STATE"; mkdir -p "$STATE" || return 1
  printf 'untouched\n' > "$STATE/sentinel.txt"
}
reset_state || { printf 'flip-p168: 造不出 %s\n' "$STATE" >&2; exit 2; }

# 变异锚点：修好后的清单必须**逐字**长这样，翻转脚本才敢只改这一行
LANE_FIXED='BG_LANE_PATHS=(bg bg.log)'
LANE_OLD='BG_LANE_PATHS=(bg)'
grep -qx "$LANE_FIXED" "$FIXTURE" || {
  printf 'flip-p168: 副本里没有锚点 %s（夹具的清单写法变了？）\n' "$LANE_FIXED" >&2; exit 2; }

# ── 写入窗口 ──────────────────────────────────────────────────────────────────────────────────
CASE_LOG=""
CASE_AFTER_MS=0
# 等夹具建出自己私有根里的 logs/ —— 源码顺序保证此刻 REAL_BEFORE 已经拍完、REAL_AFTER 还早
wait_for_window() { # <fixture-tmpdir> <fixture-pid> → 0 = 窗口开着
  local tdir="$1" pid="$2" i; local -a hits
  for ((i = 0; i < 6000; i++)); do            # 上限 ~60s（夹具正常 ~2s）
    hits=("$tdir"/teamsmith-signal-gate.*/logs)
    [ -d "${hits[0]}" ] && return 0
    kill -0 "$pid" 2>/dev/null || return 1    # 夹具提前死了 → 这一跑作废
    sleep 0.01
  done
  return 1
}

# run_case <名字> <相对 state 的写入路径> <写入内容> → 夹具退出码；日志在 $CASE_LOG
run_case() {
  local name="$1" target="$2" content="$3" pid t0 t1
  local tdir="$TMP/window-$name"
  CASE_LOG="$TMP/$name.log"; CASE_AFTER_MS=0
  rm -rf "$tdir"; mkdir -p "$tdir"
  reset_state
  ( cd "$SCRATCH" && TMPDIR="$tdir" bash "$FIXTURE" ) >"$CASE_LOG" 2>&1 &
  pid=$!
  if ! wait_for_window "$tdir" "$pid"; then
    printf 'flip-p168: %s 的写入窗口没等到（夹具没建出 logs/ 或提前退出）——本跑作废\n' "$name" >&2
    kill -TERM "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    return 99
  fi
  t0="$(date +%s%3N)"
  printf '%s\n' "$content" >> "$STATE/$target"
  if ! kill -0 "$pid" 2>/dev/null; then
    printf 'flip-p168: %s 写入时夹具已经退出（刚好压线跑完）——本跑作废\n' "$name" >&2
    wait "$pid" 2>/dev/null || true
    return 98
  fi
  wait "$pid"; CASE_RC=$?
  t1="$(date +%s%3N)"; CASE_AFTER_MS=$((t1 - t0))
  return "$CASE_RC"
}

# 反向守卫那条断言的固定子串（夹具的括号里写了排除面，翻转脚本只认前半句，免得文案一动就脆）
GUARD='真实仓库 state/ 前后一致'

# ── ① 车道绿 ─────────────────────────────────────────────────────────────────────────────────
hdr "① 车道绿：跑动中追加 state/bg.log → 反向守卫必须仍然绿（修好后的形状）"
run_case lane-green 'bg.log' "$(date -u +%FT%TZ) settled-with-unharvested=1 jobs=gate:running"
RC=$?; LOG="$CASE_LOG"
printf '  夹具 rc=%s；写入后夹具又跑了 %s ms；日志 %s\n' "$RC" "$CASE_AFTER_MS" "$LOG"
rc_is "夹具全绿（rc=0）" "$RC" "0"
[ -s "$STATE/bg.log" ] && ok "写入确实发生了（state/bg.log 非空）" || bad "state/bg.log 不在/是空的（写入没生效）"
has "$LOG" "✓ $GUARD" && ok "反向守卫那条断言是 ✓" || bad "反向守卫那条断言不是 ✓"
[ -z "$(reds "$LOG")" ] && ok "整段零 ✗" || bad "整段有红：$(reds "$LOG" | head -3 | tr '\n' '|')"
[ "$CASE_AFTER_MS" -ge 100 ] && ok "写入后夹具还跑了 ${CASE_AFTER_MS} ms（不是收尾压线写的）" \
  || bad "写入后夹具只跑了 ${CASE_AFTER_MS} ms —— 窗口证据太薄"

# ── ② 车道外红 ───────────────────────────────────────────────────────────────────────────────
hdr "② 车道外红：跑动中写 state/other.log → 必须红，且差异行点名 other.log"
run_case outside-red 'other.log' 'outside the lane — the snapshot must observe this'
RC=$?; LOG="$CASE_LOG"
printf '  夹具 rc=%s；日志 %s\n' "$RC" "$LOG"
rc_not "夹具非 0 退出" "$RC" "0"
RED_LINE="$(reds "$LOG" | grep -aF "$GUARD" | head -1)"
case "$RED_LINE" in
  *"$GUARD"*) ok "红的是反向守卫那条断言" ;;
  *) bad "反向守卫没有变红（红的行：${RED_LINE:-无}）" ;;
esac
case "$RED_LINE" in
  *"other.log"*) ok "差异行点名 other.log（排除面不是「什么都放过」）" ;;
  *) bad "差异行没点名 other.log：${RED_LINE:-无}" ;;
esac

# ── ③ 变异红：排除面退回修复前 ────────────────────────────────────────────────────────────────
hdr "③ 变异红：副本的清单改回 $LANE_OLD（修复前的排除面）→ 同样的写入必须红"
sed -i "s|^$LANE_FIXED\$|$LANE_OLD|" "$FIXTURE"
grep -qx "$LANE_OLD" "$FIXTURE" || { printf 'flip-p168: 变异没生效（%s 没被改掉）\n' "$LANE_FIXED" >&2; exit 2; }
run_case mutated-red 'bg.log' "$(date -u +%FT%TZ) settled-with-unharvested=1 jobs=gate:running"
RC=$?; LOG="$CASE_LOG"
printf '  夹具 rc=%s；日志 %s\n' "$RC" "$LOG"
rc_not "修复前的排除面下，同样的写入变红（rc≠0）" "$RC" "0"
RED_LINE="$(reds "$LOG" | grep -aF "$GUARD" | head -1)"
case "$RED_LINE" in
  *"bg.log"*) ok "差异行点名 bg.log（排除面确实是这次修的那件事）" ;;
  *) bad "差异行没点名 bg.log：${RED_LINE:-无}" ;;
esac

# ── ④ 还原绿 ─────────────────────────────────────────────────────────────────────────────────
hdr "④ 还原绿：清单还原成 $LANE_FIXED → 同样的写入又绿（③的红来自那一处改动）"
sed -i "s|^$LANE_OLD\$|$LANE_FIXED|" "$FIXTURE"
grep -qx "$LANE_FIXED" "$FIXTURE" || { printf 'flip-p168: 还原没生效（%s 没被写回）\n' "$LANE_FIXED" >&2; exit 2; }
run_case restored-green 'bg.log' "$(date -u +%FT%TZ) settled-with-unharvested=1 jobs=gate:running"
RC=$?; LOG="$CASE_LOG"
printf '  夹具 rc=%s；日志 %s\n' "$RC" "$LOG"
rc_is "夹具又全绿（rc=0）" "$RC" "0"
has "$LOG" "✓ $GUARD" && ok "反向守卫那条断言是 ✓" || bad "反向守卫那条断言不是 ✓"
[ -z "$(reds "$LOG")" ] && ok "整段零 ✗" || bad "整段有红：$(reds "$LOG" | head -3 | tr '\n' '|')"

# ── 结果 ─────────────────────────────────────────────────────────────────────────────────────
printf '\n== flip-p168 结果 == ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
  printf '\033[32m四面都符合预期（车道绿 / 车道外红 / 变异红 / 还原绿）\033[0m\n'
  [ "$KEEP" = "1" ] && printf '现场保留在 %s\n' "$TMP"
  exit 0
fi
printf '\033[31m有 %d 条不符合预期（日志在 %s）\033[0m\n' "$FAIL" "$TMP"
exit 1
