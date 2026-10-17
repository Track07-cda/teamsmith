#!/usr/bin/env bash
# flip-p304-read-side.sh — P304「读侧」的翻转夹具（change: tmux-identity-scope，apply-2）
#
#   bash skills/teamsmith/tests/flip-p304-read-side.sh [--self-test|--keep]
#
# 三条红侧，每条只让**一条**规则失效，改的是产品源码的**副本**（`tests/tmux-identity-leak.sh --break=`，
# 本树从不改动），每条后面紧跟一条还原腿（不带 --break 再跑一次）；红侧还必须**点名**具体那条断言：
#
#   refuse        可归因路径退回「直接拒绝」   → ⑤（读侧自愈）必须红：rc=1 + ⑤c/⑤d/⑤e 被点名
#   attrib-any    归因不看来源（有冲突就放行） → ⑥（守卫保留）必须红：⑥a/⑥b 放行了不可归因的现场
#   doctor-write  doctor 那行不再是只读          → ⑦（doctor 只读）必须红：全局环境被改 + state 被写
#
# 判绿规则：三条红各出 rc=1 且 ✗>0、三条还原各出 rc=0 且 ✗=0；全绿 exit 0，否则 exit 1。
# 只写自己的临时根（点开头 + 项目 ns，tmp-hygiene 的 owned 家族），--keep 才留现场。
set -uo pipefail

FLIP_SKILL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEEP=0
case "${1:-}" in
  --self-test|"") ;;
  --keep)         KEEP=1 ;;
  *) printf 'flip-p304-read-side: 不认识的参数 %s（只认 --self-test / --keep）\n' "$1" >&2; exit 2 ;;
esac

FIX="$FLIP_SKILL/tests/tmux-identity-leak.sh"
[ -f "$FIX" ] || { printf 'flip-p304-read-side: 找不到 %s\n' "$FIX" >&2; exit 2; }
# shellcheck source=../scripts/lib/common.sh
. "$FLIP_SKILL/scripts/lib/common.sh" 2>/dev/null \
  || { printf 'flip-p304-read-side: 找不到 %s/scripts/lib/common.sh（skill 树不全）\n' "$FLIP_SKILL" >&2; exit 2; }
NS="$(team_project_ns 2>/dev/null || printf 'nosig-00000000')"
BASE="${TMPDIR:-/tmp}"
ROOT="$(mktemp -d "$BASE/.teamsmith-p304flip-$NS.XXXXXX")" || exit 2

FLIP_RC=0
note()     { printf '%s\n' "$*"; }
line_ok()  { note "  ✓ $*"; }
line_bad() { note "  ✗ $*"; FLIP_RC=1; }

# 一条腿：跑夹具，抓 rc 与末行 ✓/✗ 计数。期望 rc：红侧 1、还原 0。
leg() { # <名字> <期望 rc> <选择> <break 值|-> <必须点名的 ✗ 文本|-> …
  local name="$1" want="$2" sel="$3" brk="$4"; shift 4
  local log="$ROOT/$name.log" rc=0 want_flip=0 x=""
  [ "$want" = "1" ] && want_flip=1
  if [ "$brk" = "-" ]; then
    ( cd "$FLIP_SKILL" && bash "$FIX" --select "$sel" ) >"$log" 2>&1 || rc=$?
  else
    ( cd "$FLIP_SKILL" && bash "$FIX" --select "$sel" --break="$brk" ) >"$log" 2>&1 || rc=$?
  fi
  # 夹具的结果行带 ANSI 颜色（`✓ 15  ✗ 0`）——先剥色再取 ✗ 计数；剥色后的副本也用作点名判据（grep -a 在二进制风险上更稳）
  sed -e 's/\x1b\[[0-9;]*m//g' "$log" > "$log.clean" 2>/dev/null || : > "$log.clean"
  x="$(sed -n 's/.*结果 ==.*✗[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$log.clean" | tail -1)"
  note "leg $name：rc=$rc ✗=${x:-?}（$sel${brk:+/--break=$brk}）"
  [ "$rc" = "$want" ] || line_bad "$name：退出码应当 $want，实际 $rc"
  if [ -z "$x" ]; then
    line_bad "$name：日志里没有结果行（夹具没跑到收口）"
  elif [ "$want_flip" = "1" ] && [ "$x" = "0" ]; then
    line_bad "$name：红侧一条 ✗ 都没有（守卫没被证到）"
  elif [ "$want_flip" = "0" ] && [ "$x" != "0" ]; then
    line_bad "$name：还原后仍有 $x 条 ✗"
  fi
  local pat
  for pat in ${1+"$@"}; do
    [ -n "$pat" ] || continue
    if grep -aqF -- "✗ $pat" "$log.clean"; then line_ok "$name：点名了「$pat」"
    else line_bad "$name：没有点名「$pat」（红侧不够具体）"; fi
  done
}

note "== flip-p304-read-side（P304 读侧三条红 + 三条还原）=="
note "临时根：$ROOT"
note "夹具：$FIX"

# ⑤ 读侧自愈：可归因路径退回「直接拒绝」→ 自愈不成立
leg red-refuse      1 residue    refuse \
  '⑤c 残留形状下 team up 退出码 0（自愈：不再拒绝）' \
  '⑤e stderr 一行点名来源：运行中的 tmux server 的全局环境'
leg green-residue   0 residue    -

# ⑥ 守卫保留：归因不看来源 → 不可归因的现场被放行
leg red-attrib-any  1 guard-kept attrib-any \
  '⑥a 显式外来环境仍被拒（rc=1）' \
  '⑥b 半可归因仍被拒（rc=1）'
leg green-guard-kept 0 guard-kept -

# ⑦ doctor 只读：那一行开始写盘 / 写共享 server 全局环境
leg red-doctor-write 1 doctor    doctor-write \
  '⑦c 跑完全局环境逐字节未变（只读，不代改）' \
  '⑦c 项目 state 里一个文件都没多/没变（产品自己不写盘）'
leg green-doctor    0 doctor     -

note ""
if [ "$FLIP_RC" = "0" ]; then
  note "FLIP 全绿：三条红各自点名、三条还原各自回绿（证据：$ROOT）"
else
  note "FLIP 有未达预期的腿（证据：$ROOT）"
fi
[ "$KEEP" = "1" ] || rm -rf "$ROOT"
exit "$FLIP_RC"
