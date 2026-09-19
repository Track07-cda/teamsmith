#!/usr/bin/env bash
# M43 · 翻转包：inbox 唤醒重放的 red → green 证据（修复前重放整份 spool → 修复后有界+去重）
#
#   bash skills/teamsmith/tests/flip-m43.sh
#   TEAM_FLIP_BASE=<sha> bash skills/teamsmith/tests/flip-m43.sh   # 覆盖「修复前」的 revision
#
# 事故（2026-09-19T16:59Z，主树 .pi/team/state/inbox-watch.log:118-120）：外部力量把 PM 的 spool
# 原位截断又写回同一批内容（两次，间隔 6 秒；inode btime=09-18 证明不是 rename 替换；仓内写路径
# 只有 `>>` 追加）。旧 `readNewLines` 的 `size < offset → offset = 0` 静默重置 → 下一拍从 0 全量
# 重读 → 同一份 42 行被叫了两遍（wake n=42 ×2）、total 灌水 52→94。账本对重置本身一个字都没有。
#
# 本包用**同一个 harness**（tests/team-inbox-watch-harness.mjs，S11/S12/S13 是 M43 加的用例）
# 对三种树的扩展各跑一遍（夹具不变，只换被测扩展）：
#   ① 红树（TEAM_FLIP_BASE / merge-base HEAD main 的修复前扩展）→ S11/S12/S13 必须 FAIL（复现）
#   ② 绿树（本 worktree 的扩展）→ 全 PASS（修复后）
#   ③ 变异树（绿树副本把两处去重过滤改成恒真）→ S11/S13 必须 FAIL（破坏实现 → 守卫测试红）
#
# 退出码：0 = 三个预期全部成立；1 = 有任何一个不成立；2 = 环境/前置不满足（不算绿也不算红）。
# 隔离：harness 自身就是隔离夹具（清 TEAM_*/TMUX 身份、临时仓库、真实仓库 state/ 前后快照反守卫），
# 本脚本只写 /tmp 临时目录，不用 tmux（harness 是假 Pi 宿主）。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { printf 'flip-m43: 找不到 git 仓库（需要 git archive 取修复前的树）\n' >&2; exit 2; }

# 能直接跑 .ts 的运行时：node（需启用类型剥离）/ bun（与 smoke.sh 同口径）
TS_RUNNER=""
if command -v node >/dev/null 2>&1 && node -e 'process.exit(process.features.typescript?0:1)' >/dev/null 2>&1; then
  TS_RUNNER="node"
elif command -v bun >/dev/null 2>&1 && bun -e '1' >/dev/null 2>&1; then
  TS_RUNNER="bun"
elif [ -x "$HOME/.bun/bin/bun" ] && "$HOME/.bun/bin/bun" -e '1' >/dev/null 2>&1; then
  TS_RUNNER="$HOME/.bun/bin/bun"
fi
[ -n "$TS_RUNNER" ] || { printf 'flip-m43: 需要 node（类型剥离）或 bun 来跑 TS 扩展\n' >&2; exit 2; }

BASE="${TEAM_FLIP_BASE:-}"
if [ -z "$BASE" ]; then
  BASE="$(git -C "$REPO_ROOT" merge-base HEAD main 2>/dev/null || true)"
fi
[ -n "$BASE" ] || BASE="$(git -C "$REPO_ROOT" rev-parse --verify -q HEAD^ 2>/dev/null || true)"
[ -n "$BASE" ] || { printf 'flip-m43: 解析不到修复前的 revision，用 TEAM_FLIP_BASE=<sha> 指定\n' >&2; exit 2; }

TMP="$(mktemp -d /tmp/teamsmith-flip-m43.XXXXXX)"
cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0        # 管道/命令替换的子 shell 不要重复清场
  rm -rf "$TMP"
}
trap cleanup EXIT

fail() { printf '\033[31m✗\033[0m %s\n' "$*"; }
pass() { printf '\033[32m✓\033[0m %s\n' "$*"; }

# ---- 三种树：红（修复前） / 绿（本 worktree） / 变异（绿 + 去重过滤改恒真）------------------
mkdir -p "$TMP/red-skill" "$TMP/mut-skill/extension"
git -C "$REPO_ROOT" archive "$BASE" skills/teamsmith | tar -x -C "$TMP/red-skill" || exit 2
RED_EXT="$TMP/red-skill/skills/teamsmith/extension/team-inbox-watch.ts"
GREEN_EXT="$SKILL_DIR/extension/team-inbox-watch.ts"
HARNESS="$SKILL_DIR/tests/team-inbox-watch-harness.mjs"

# 前置守卫：红树必须真的还是「修复前」，绿树必须真的带着修复（否则这个包报的是假翻转）
if grep -q 'rescan' "$RED_EXT" 2>/dev/null; then
  printf 'flip-m43: $BASE 已经包含 M43 的修复（不是修复前的树）——用 TEAM_FLIP_BASE=<修复前的 sha> 指定\n' >&2
  exit 2
fi
grep -q 'rescan' "$GREEN_EXT" || { printf 'flip-m43: 本树扩展找不到 rescan（修复不在？）\n' >&2; exit 2; }

cp "$GREEN_EXT" "$TMP/mut-skill/extension/team-inbox-watch.ts"
# 变异：两处 M43 去重过滤（普通路径 + rescan 路径）改成恒真 —— 重放不再被去重约束
sed -i 's/!delivered\.has(l)/true/g' "$TMP/mut-skill/extension/team-inbox-watch.ts"
[ "$(grep -c 'filter(l => true)' "$TMP/mut-skill/extension/team-inbox-watch.ts")" = "2" ] \
  || { printf 'flip-m43: 变异没打上（去重过滤行的形状变了？）\n' >&2; exit 2; }
# 变异树也要能跑 S10（真 CLI）：借用本树的 scripts（变异只针对扩展，不是对 scripts 的回归）
cp -a "$SKILL_DIR/scripts" "$TMP/mut-skill/scripts"

run_harness() { # <label> <extension 路径> → stdout=日志；rc=harness 退出码
  local label="$1" ext="$2"
  "$TS_RUNNER" "$HARNESS" "$ext" 2>&1
}

RC=0

# ---- ① 红树：必须复现（S11/S12/S13 红） ----
RED_LOG="$(run_harness red "$RED_EXT")"; RED_RC=$?
if [ "$RED_RC" -ne 0 ] \
  && printf '%s\n' "$RED_LOG" | grep -q 'TEAM-IW-CASE FAIL S11' \
  && printf '%s\n' "$RED_LOG" | grep -q 'TEAM-IW-CASE FAIL S12' \
  && printf '%s\n' "$RED_LOG" | grep -q 'TEAM-IW-CASE FAIL S13'; then
  pass "红树（$BASE）复现成功：S11/S12/S13 全红（修复前：外部截断+重写 = 整份重放 + total 灌水）"
else
  fail "红树没有复现（rc=$RED_RC；预期 S11/S12/S13 全 FAIL）"
  printf '%s\n' "$RED_LOG" | grep 'TEAM-IW-CASE' | tail -8 | sed 's/^/     /'
  RC=1
fi
# 红树的事故签名（报告用）：重放唤醒 + total 灌水
printf '%s\n' "$RED_LOG" | grep -E 'FAIL S11 (external|total)' | sed 's/^/  red: /'

# ---- ② 绿树：必须全绿 ----
GREEN_LOG="$(run_harness green "$GREEN_EXT")"; GREEN_RC=$?
GREEN_N="$(printf '%s\n' "$GREEN_LOG" | grep -c 'TEAM-IW-CASE PASS')"
if [ "$GREEN_RC" -eq 0 ] && printf '%s\n' "$GREEN_LOG" | grep -q 'TEAM-IW-HARNESS OK'; then
  pass "绿树（本 worktree）：harness 全绿（$GREEN_N 条用例，含 S11/S12/S13）"
else
  fail "绿树不是全绿（rc=$GREEN_RC）——修复把别的用例弄红了？"
  printf '%s\n' "$GREEN_LOG" | grep 'TEAM-IW-CASE FAIL' | sed 's/^/     /'
  RC=1
fi

# ---- ③ 变异树：去重被破坏 → S11/S13 必须红（守卫测试真的咬在实现上） ----
MUT_LOG="$(run_harness mut "$TMP/mut-skill/extension/team-inbox-watch.ts")"; MUT_RC=$?
if [ "$MUT_RC" -ne 0 ] \
  && printf '%s\n' "$MUT_LOG" | grep -q 'TEAM-IW-CASE FAIL S11' \
  && printf '%s\n' "$MUT_LOG" | grep -q 'TEAM-IW-CASE FAIL S13'; then
  pass "变异树（去重过滤改恒真）：S11/S13 红 —— 翻转成立（测试咬在去重实现上）"
else
  fail "变异树没有红（rc=$MUT_RC；预期 S11/S13 FAIL）——S11/S13 可能没真的钉在去重上"
  printf '%s\n' "$MUT_LOG" | grep 'TEAM-IW-CASE' | tail -8 | sed 's/^/     /'
  RC=1
fi

printf 'exit=%s\n' "$RC"
exit "$RC"
