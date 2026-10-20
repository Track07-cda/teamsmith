#!/usr/bin/env bash
# flip-p309-p162-deep.sh — P309 的跨任务修复红侧：段 0h（P162 深路径硬停）必须**确定**，不是靠路径恰好够长
#
#   bash skills/teamsmith/tests/flip-p309-p162-deep.sh [--keep]
#
# 背景：段 0h 的端到端夹具要求「超深 TMPDIR → 嵌套 smoke 的私有 tmux server 绑不上 → 0c 硬停、0c 记 SKIP」。
# 这个前提本来由「临时根足够长」偶然提供；P310（提交 57efe1cb）让 socket 目录在路径太长时退到 /tmp 之后，
# 深 TMPDIR 不再必然导致超长 —— 深路径必须**显式造出来**（用 P310 自己的红侧旋钮
# TEAM_SMOKE_FIXTURE=1 + TEAM_SMOKE_TMUX_UNDER_TMP=1）。本脚本证明新写法是确定性的：
#
#   leg green：现树 `--select 0h` → 该段 ✓ 且 0 失败（5 秒级，不是 60 秒超时）。
#   leg red  ：把那条 env 行删掉的**副本**（= 改动前的形状，靠临时根恰好很长）→ 该段必须不再绿：
#              嵌套 smoke 整轮跑下去、60 秒预算到点被停（exit 2），该段记 ✗。
#
# 不碰机器锁（私有 TMPDIR + 私有 tmux，`env -u` 清掉继承位），不碰调用者的默认 server。
# 判绿：两条都按预期。全绿 exit 0 / 没按预期 exit 1 / 脚本级前提不成立 exit 2。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
. "$SELF_DIR/lib/tmp-root.sh"
SMOKE="$SKILL_DIR/tests/smoke.sh"
[ -f "$SMOKE" ] || { printf 'flip-p309-p162-deep: 找不到 %s\n' "$SMOKE" >&2; exit 2; }
command -v tmux >/dev/null 2>&1 || { printf 'flip-p309-p162-deep: 没有 tmux —— 这条腿判不了（0h 要真 tmux）\n' >&2; exit 2; }

KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --keep) KEEP=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) printf 'flip-p309-p162-deep: 未知参数 %s（--keep）\n' "$1" >&2; exit 2 ;;
  esac
done
[ "$KEEP" = "1" ] && export TEAM_TMP_KEEP=1

TMP="$(tmp_root_create flip-p309p162)" || exit 3
cleanup() { [ "${BASHPID:-$$}" = "$$" ] && [ "$KEEP" = "0" ] && tmp_root_reap_all; }
trap cleanup EXIT

FAILED=0
case_ok()  { printf '  \033[32m✓\033[0m %s\n' "$*"; }
case_bad() { printf '  \033[31m✗\033[0m %s\n' "$*"; FAILED=1; }
plain() { sed 's/\x1b\[[0-9;]*m//g' "$1" 2>/dev/null || true; }
# 本段那一行的收口：`#N 0h · … · 用时 Xs · ✓a ✗b SKIPc · ticks d`
sec_line() { # <日志>
  plain "$1" | sed -n 's/^#\([0-9]\+\) \(0h · .*· 用时 [0-9]\+s · .*\)$/\1 \2/p' | head -1
}
sec_fail() { # <日志> → 该段 ✗ 数（缺 → 空）
  local l; l="$(sec_line "$1")"; [ -n "$l" ] || return 0
  printf '%s\n' "$l" | sed -n 's/.*✗\([0-9]\+\) SKIP.*/\1/p'
}

# ── 副本：删掉 0h 里那条显式造深路径的 env 行（改动前的形状）─────────────────────────────────
# 副本要落在 `<假项目>/skills/teamsmith`：套件按 `$SEL_DIR/../../..` 找选段表（section-paths.tsv），
# 平铺在别处会让 --select 直接找不到表（rc=2，看着像「段失败」其实根本没跑）。
MUT_ROOT="$TMP/mut-project"; MUT="$MUT_ROOT/skills/teamsmith"; mkdir -p "$MUT"
cp -a "$SKILL_DIR"/. "$MUT"/ 2>/dev/null || { printf 'flip-p309-p162-deep: 复制 skill 树失败\n' >&2; exit 2; }
MUT_SMOKE="$MUT/tests/smoke.sh"
grep -qF 'TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_TMUX_UNDER_TMP=1' "$MUT_SMOKE" \
  || { printf 'flip-p309-p162-deep: 副本里找不到那两条旋钮（夹具改形了？）\n' >&2; exit 2; }
sed -i '/TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_TMUX_UNDER_TMP=1/d' "$MUT_SMOKE"
if grep -qF 'TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_TMUX_UNDER_TMP=1' "$MUT_SMOKE"; then
  printf 'flip-p309-p162-deep: 变异没落地（旋钮还在副本里）\n' >&2; exit 2
fi
cmp -s "$SMOKE" "$MUT_SMOKE" && { printf 'flip-p309-p162-deep: 副本与原件相同（变异无效）\n' >&2; exit 2; }
bash -n "$MUT_SMOKE" 2>/dev/null || { printf 'flip-p309-p162-deep: 变异副本语法坏\n' >&2; exit 2; }

# 嵌套门禁：清掉身份/锁/socket 继承位。TMPDIR **不设** —— 嵌套跑按产品默认解析（socket 基址带长度
# 检查、太长会自动退 /tmp），0h 段自己再造那条超深路径。本脚本的 $TMP 反而太深，会让「正常隔离」
# 那条反向断言先被硬停（实测过：leg green 的 P162 反向 ✗2）。
# FAST + 私有锁：这是一条夹具腿，不参与机器锁排队，也不该卡住别人的门禁。
p309p162_nest() { # <skill-dir> <日志>
  local skill="$1" log="$2"
  ( cd "$TMP" && env -u TMPDIR -u TMUX -u TMUX_PANE -u TMUX_TMPDIR -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT \
      -u TEAM_SESSION -u TEAM_TMUX_REAL -u SMOKE_LOCK_WRAPPED -u SMOKE_LOCK_QUEUED -u SMOKE_LOCK_MARKER \
      -u TEAM_SMOKE_LOCK_WAIT -u TEAM_SMOKE_NO_PRIVATE_TMUX -u TEAM_SMOKE_TMUX_UNDER_TMP \
      -u TEAM_SMOKE_BREAK -u TEAM_SMOKE_FIXTURE -u SMOKE_SEL_CHILD -u SMOKE_SEL_COPY -u SMOKE_SEL_SKILL_DIR \
      TEAM_SMOKE_FAST=1 TEAM_SMOKE_LOCK="$TMP/nest.lock" \
      bash "$skill/tests/smoke.sh" --select 0h ) >"$log" 2>&1
  printf '%s\n' "$?"
}

printf '\033[1m══ P309 跨任务修复：0h（P162 深路径硬停）必须确定 ══\033[0m\n'

# ── leg green：现树 —— 该段 ✓ 且 0 失败 ────────────────────────────────────────────────────
printf '\n\033[1m── leg green：现树 --select 0h（深路径显式造出来）──\033[0m\n'
G_RC="$(p309p162_nest "$SKILL_DIR" "$TMP/green.log")"
G_LINE="$(sec_line "$TMP/green.log")"
G_FAIL="$(sec_fail "$TMP/green.log")"
if [ "$G_RC" != "0" ]; then
  case_bad "leg green：嵌套门禁退出码 [$G_RC]（期望 0）"
  plain "$TMP/green.log" | grep -a '✗' | head -3 | sed 's/^/      /'
elif [ -z "$G_LINE" ]; then
  case_bad "leg green：日志里没有 0h 的收口行（该段没跑到？）"
elif [ "${G_FAIL:-x}" != "0" ]; then
  case_bad "leg green：0h 段有失败（✗$G_FAIL）：$G_LINE"
else
  case_ok "leg green：rc=0 · 0h 段 ✗0 · $G_LINE"
fi

# ── leg red：副本（把深路径交回「临时根恰好很长」）→ 该段必须不再绿 ─────────────────────────
printf '\n\033[1m── leg red：删掉显式深路径的副本 → 0h 必须不再绿 ──\033[0m\n'
R_RC="$(p309p162_nest "$MUT" "$TMP/red.log")"
R_LINE="$(sec_line "$TMP/red.log")"
R_FAIL="$(sec_fail "$TMP/red.log")"
R_STUCK="$(plain "$TMP/red.log" | grep -ac '挂住' || true)"
if [ "$R_RC" = "0" ]; then
  case_bad "leg red：副本 rc=0 —— 0h 在新写法之外仍然绿（红侧不承重：断言可能是白删的）"
elif [ "${R_STUCK:-0}" = "0" ] && [ "${R_FAIL:-0}" = "0" ]; then
  case_bad "leg red：副本失败了，但既不是段挂住也不是段内失败（rc=$R_RC）：$R_LINE"
else
  case_ok "leg red：rc=$R_RC · 0h 不再绿（段挂住 ${R_STUCK:-0} 条 · 段内 ✗${R_FAIL:-无收口行（被挂住停跑）}）"
fi

printf '\n'
if [ "$FAILED" = "0" ]; then
  printf '\033[32mflip-p309-p162-deep：两条腿都对上了\033[0m\n'
  exit 0
fi
printf '\033[31mflip-p309-p162-deep：有腿没按预期\033[0m\n' >&2
[ "$KEEP" = "1" ] && printf '保留：%s\n' "$TMP"
exit 1
