#!/usr/bin/env bash
# P28 · 翻转包：inbox-spool-resilience（字节真值的 offset / 证据化的缩容 / 收敛）的 red → green 证据
#
#   bash skills/teamsmith/tests/flip-p25.sh
#   TEAM_FLIP_BASE=<sha> bash skills/teamsmith/tests/flip-p25.sh    # 覆盖「修复前」的 revision
#
# 事故（2026-09-20 06:42，主树 .pi/team/state/inbox-watch.log:179-205）：生产者把预览裁在多字节字符中间
# （`LC_ALL=C cut -c1-700` 是按字节的）→ spool 行不是合法 UTF-8；读者的 `readNewLines` 用
# `Buffer.byteLength(解码结果)` 算 advance（一个非法字节 = U+FFFD = 3 字节）→ baseline = size + 1 →
# 之后每一拍都像外部缩容：`spool shrink` + `rescan lines=66 … deliver=20` 每 5 秒一轮，把 1–2 天前的
# 66 行叫了四遍（`total` 灌水），直到有人手清 spool。
#
# 本包用**同一个 harness**（tests/team-inbox-watch-harness.mjs；S18/S19 是 P28 加的用例）对五种树各跑
# 一遍（夹具不变，只换被测扩展）：
#   ① 红树（TEAM_FLIP_BASE / merge-base HEAD main 的 P28 之前扩展）→ S18 必须 FAIL（复现假缩容）
#   ② 绿树（本 worktree）→ 全 PASS
#   ③ 变异 A（绿树 + 旧 advance）→ S18 必须 FAIL（baseline = size + 1）
#   ④ 变异 B（A + 去掉 clamp/repeat 守卫）→ S18 必须 FAIL，且空闲每拍都写 `spool shrink`（2026-09-20 的循环本身）
#   ⑤ 变异 C（绿树 + 无条件 clamp）→ S19b 必须 FAIL（真重写再也读不到）
#
# 退出码：0 = 五个预期全部成立；1 = 有任何一个不成立；2 = 环境/前置不满足（不算绿也不算红）。
# 隔离：harness 自己就是隔离夹具（清 TEAM_*/TMUX 身份、临时仓库、真实仓库 state/ 前后快照反守卫），
# 本脚本只写 /tmp 临时目录，不调用 tmux。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$SELF_DIR/lib/tmp-root.sh"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { printf 'flip-p25: 找不到 git 仓库（需要 git archive 取修复前的树）\n' >&2; exit 2; }

# 能直接跑 .ts 的运行时（与 smoke.sh / flip-m43.sh 同口径）
TS_RUNNER=""
if command -v node >/dev/null 2>&1 && node -e 'process.exit(process.features.typescript?0:1)' >/dev/null 2>&1; then
  TS_RUNNER="node"
elif command -v bun >/dev/null 2>&1 && bun -e '1' >/dev/null 2>&1; then
  TS_RUNNER="bun"
elif [ -x "$HOME/.bun/bin/bun" ] && "$HOME/.bun/bin/bun" -e '1' >/dev/null 2>&1; then
  TS_RUNNER="$HOME/.bun/bin/bun"
fi
[ -n "$TS_RUNNER" ] || { printf 'flip-p25: 需要 node（类型剥离）或 bun 来跑 TS 扩展\n' >&2; exit 2; }

BASE="${TEAM_FLIP_BASE:-}"
if [ -z "$BASE" ]; then
  BASE="$(git -C "$REPO_ROOT" merge-base HEAD main 2>/dev/null || true)"
fi
[ -n "$BASE" ] || BASE="$(git -C "$REPO_ROOT" rev-parse --verify -q HEAD^ 2>/dev/null || true)"
[ -n "$BASE" ] || { printf 'flip-p25: 解析不到修复前的 revision，用 TEAM_FLIP_BASE=<sha> 指定\n' >&2; exit 2; }

[ "${KEEP:-0}" = "1" ] && export TEAM_TMP_KEEP=1
TMP="$(tmp_root_create flip-p25)" || exit 3
cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0        # 管道/命令替换的子 shell 不要重复清场
  tmp_root_reap_all
}
trap cleanup EXIT

fail() { printf '\033[31m✗\033[0m %s\n' "$*"; }
pass() { printf '\033[32m✓\033[0m %s\n' "$*"; }

GREEN_EXT="$SKILL_DIR/extension/team-inbox-watch.ts"
HARNESS="$SKILL_DIR/tests/team-inbox-watch-harness.mjs"

# ---- 红树 + 三种变异树 ---------------------------------------------------------------------
mkdir -p "$TMP/red-skill" "$TMP/mutA/extension" "$TMP/mutB/extension" "$TMP/mutC/extension"
git -C "$REPO_ROOT" archive "$BASE" skills/teamsmith | tar -x -C "$TMP/red-skill" || exit 2
RED_EXT="$TMP/red-skill/skills/teamsmith/extension/team-inbox-watch.ts"

# 前置守卫：红树必须真的还没修，绿树必须真的修了、且可变异的那一行还在
grep -q 'offset resync' "$RED_EXT" 2>/dev/null && {
  printf 'flip-p25: $BASE 已经包含 P28 的修复（不是修复前的树）——用 TEAM_FLIP_BASE=<修复前的 sha> 指定\n' >&2; exit 2; }
grep -q 'offset resync' "$GREEN_EXT" || { printf 'flip-p25: 本树扩展里没有 offset resync（P28 的修复不在？）\n' >&2; exit 2; }
grep -q 'const advance = end + 1' "$GREEN_EXT" || { printf 'flip-p25: 找不到变异锚点 const advance = end + 1\n' >&2; exit 2; }
grep -q 'headUnchanged(cur) && (repeat || regress <= clampBytes())' "$GREEN_EXT" \
  || { printf 'flip-p25: 找不到变异锚点 headUnchanged(cur) ... clampBytes()\n' >&2; exit 2; }

OLD_ADVANCE='const advance = Buffer.byteLength(win.subarray(0, end + 1).toString("utf8"), "utf8")'
mutate_advance() { # <file>
  sed -i "s@const advance = end + 1@$OLD_ADVANCE@" "$1"
  grep -qF "$OLD_ADVANCE" "$1" || { printf 'flip-p25: 旧 advance 变异没打上\n' >&2; exit 2; }
}
mutate_clamp_guard() { # <file>：去掉 clamp/repeat 守卫（shrink 一律重扫）
  sed -i 's@if (size >= 0 \&\& headUnchanged(cur) \&\& (repeat || regress <= clampBytes()))@if (false)@' "$1"
  [ "$(grep -c 'if (false) {' "$1")" = "1" ] || { printf 'flip-p25: 守卫变异没打上\n' >&2; exit 2; }
}
mutate_always_clamp() { # <file>：任何 shrink 都 clamp（重扫永远发生不了）
  sed -i 's@if (size >= 0 \&\& headUnchanged(cur) \&\& (repeat || regress <= clampBytes()))@if (size >= 0)@' "$1"
  [ "$(grep -c 'if (size >= 0) {' "$1")" = "1" ] || { printf 'flip-p25: 无条件 clamp 变异没打上\n' >&2; exit 2; }
}
cp "$GREEN_EXT" "$TMP/mutA/extension/team-inbox-watch.ts"; mutate_advance "$TMP/mutA/extension/team-inbox-watch.ts"
cp "$GREEN_EXT" "$TMP/mutB/extension/team-inbox-watch.ts"; mutate_advance "$TMP/mutB/extension/team-inbox-watch.ts"; mutate_clamp_guard "$TMP/mutB/extension/team-inbox-watch.ts"
cp "$GREEN_EXT" "$TMP/mutC/extension/team-inbox-watch.ts"; mutate_always_clamp "$TMP/mutC/extension/team-inbox-watch.ts"
# 变异只针对扩展：脚本侧（S10 的真 CLI）用本树的 scripts
for m in mutA mutB mutC; do cp -a "$SKILL_DIR/scripts" "$TMP/$m/scripts"; done

run_harness() { # <extension 路径> → stdout=日志；全局 LAST_RC
  "$TS_RUNNER" "$HARNESS" "$1" 2>&1
}

RC=0
has() { case "$2" in *"$1"*) return 0 ;; *) return 1 ;; esac; }

# ---- ① 红树：必须复现（S18 红：baseline = size + 1）----------------------------------------
RED_LOG="$(run_harness "$RED_EXT")"; RED_RC=$?
if [ "$RED_RC" -ne 0 ] \
  && has 'TEAM-IW-CASE FAIL S18 the baseline is the spool byte size' "$RED_LOG" \
  && has 'TEAM-IW-CASE FAIL S18 idle ticks after a byte-clipped line add no spool shrink' "$RED_LOG"; then
  pass "红树（$BASE）复现成功：S18 全红（baseline 被 U+FFFD 撑成 size+1，空闲每拍假缩容）"
else
  fail "红树没有复现（rc=$RED_RC；预期 S18 的 baseline 与空闲两断言 FAIL）"
  printf '%s\n' "$RED_LOG" | grep 'TEAM-IW-CASE FAIL S18' | sed 's/^/     /'
  RC=1
fi
printf '%s\n' "$RED_LOG" | grep -E 'FAIL S18 (the baseline|idle ticks)' | sed 's/^/  red: /'

# ---- ② 绿树：必须全绿 ---------------------------------------------------------------------
GREEN_LOG="$(run_harness "$GREEN_EXT")"; GREEN_RC=$?
GREEN_N="$(printf '%s\n' "$GREEN_LOG" | grep -c 'TEAM-IW-CASE PASS')"
if [ "$GREEN_RC" -eq 0 ] && has 'TEAM-IW-HARNESS OK' "$GREEN_LOG"; then
  pass "绿树（本 worktree）：harness 全绿（$GREEN_N 条用例，含 S18/S19/S20/S21）"
else
  fail "绿树不是全绿（rc=$GREEN_RC）——修复把别的用例弄红了？"
  printf '%s\n' "$GREEN_LOG" | grep 'TEAM-IW-CASE FAIL' | sed 's/^/     /'
  RC=1
fi

# ---- ③ 变异 A：旧 advance → S18 必须红（假缩容回来了）--------------------------------------
MUTA_LOG="$(run_harness "$TMP/mutA/extension/team-inbox-watch.ts")"; MUTA_RC=$?
if [ "$MUTA_RC" -ne 0 ] && has 'TEAM-IW-CASE FAIL S18 the baseline is the spool byte size' "$MUTA_LOG"; then
  pass "变异 A（旧 advance）：S18 红 —— 翻转成立（S18 真的咬在字节推进上）"
  printf '%s\n' "$MUTA_LOG" | grep 'FAIL S18 the baseline' | sed 's/^/  mutA: /'
else
  fail "变异 A 没有红（rc=$MUTA_RC；预期 S18 的 baseline 断言 FAIL）"
  printf '%s\n' "$MUTA_LOG" | grep 'TEAM-IW-CASE' | tail -8 | sed 's/^/     /'
  RC=1
fi

# ---- ④ 变异 B：A + 去掉 clamp/repeat 守卫 → S18 必须红，且是**重复**的 spool shrink（循环）----
MUTB_LOG="$(run_harness "$TMP/mutB/extension/team-inbox-watch.ts")"; MUTB_RC=$?
MUTB_IDLE="$(printf '%s\n' "$MUTB_LOG" | grep -F 'TEAM-IW-CASE FAIL S18 idle ticks after a byte-clipped line add no spool shrink' | head -1)"
MUTB_DELTA="$(printf '%s' "$MUTB_IDLE" | grep -oE 'shrink lines [0-9]+ -> [0-9]+' | head -1)"
MUTB_GROWTH="$(printf '%s' "$MUTB_DELTA" | awk '{print $5 - $3}')"
if [ "$MUTB_RC" -ne 0 ] && [ -n "$MUTB_IDLE" ] \
  && [ -n "$MUTB_GROWTH" ] && [ "${MUTB_GROWTH:-0}" -ge 2 ]; then
  pass "变异 B（旧 advance + 无守卫）：S18 红，空闲期反复写 spool shrink（$MUTB_DELTA）—— 2026-09-20 的循环复现"
else
  fail "变异 B 没有复现循环（rc=$MUTB_RC；$MUTB_DELTA）——S18/守卫可能没真的钉在收敛上"
  printf '%s\n' "$MUTB_LOG" | grep 'TEAM-IW-CASE FAIL S18' | sed 's/^/     /'
  RC=1
fi

# ---- ⑤ 变异 C：无条件 clamp → S19b 必须红（真重写永远不再被读）-----------------------------
MUTC_LOG="$(run_harness "$TMP/mutC/extension/team-inbox-watch.ts")"; MUTC_RC=$?
if [ "$MUTC_RC" -ne 0 ] && has 'TEAM-IW-CASE FAIL S19b a rewrite with a changed head is rescanned exactly once' "$MUTC_LOG"; then
  pass "变异 C（无条件 clamp）：S19b 红 —— 证据门槛真的在区分「修复」与「重写」"
  printf '%s\n' "$MUTC_LOG" | grep -E 'FAIL S19b' | sed 's/^/  mutC: /'
else
  fail "变异 C 没有红（rc=$MUTC_RC；预期 S19b 的 rescan 断言 FAIL）"
  printf '%s\n' "$MUTC_LOG" | grep 'TEAM-IW-CASE FAIL S19' | sed 's/^/     /'
  RC=1
fi

printf 'exit=%s\n' "$RC"
exit "$RC"
