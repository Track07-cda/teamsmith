#!/usr/bin/env bash
# flip-p310-socket.sh — P310 ① 的翻转夹具：私有 tmux socket 的路径长度**不随临时根变长**
#
#   bash skills/teamsmith/tests/flip-p310-socket.sh [--keep]
#
# 事故形状（P288 之后）：临时根名带项目 ns（`teamsmith-<kind>-<ns>.XXXXXX`）且 socket 目录挂在临时根下
# （`$TMP/tmux`）→ 嵌套夹具再套一层 `TMPDIR=$TMP/case-*` 时 socket 到 126 字节 > AF_UNIX 的 107，
# §0c 的隔离前置硬停（exit 2），嵌套门禁一条结论都拿不到（§0i ✓2 ✗3）。
#
# 两条腿（都跑**真门禁**：嵌套的 smoke.sh --select 0b，私有 TMPDIR + FAST + 私有锁；不碰机器锁，
# 不碰调用者的默认 server；不对任何非自己 spawn 的进程发信号）：
#   leg green：TMPDIR 深到「旧形状会 >107 字节」→ 门禁必须 **rc=0**，日志里的 socket 行长度 ≤ 107
#              （实测值打印出来，供复验核对）。
#   leg red  ：同一个 TMPDIR + `TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_TMUX_UNDER_TMP=1`（把 socket 目录放回
#              临时根下 = 改动前的形状）→ §0c 的隔离前置必须**硬停**（exit 2）、点名
#              `socket 路径 N 字节 > AF_UNIX 上限 107`，且 N 恰是本夹具按旧形状算出的那个长度（>107）。
# 判绿：两条都按预期。全绿 exit 0；任何一条没按预期 → exit 1（脚本级前提不成立 → exit 2）。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
. "$SELF_DIR/lib/tmp-root.sh"
SMOKE="$SKILL_DIR/tests/smoke.sh"
[ -f "$SMOKE" ] || { printf 'flip-p310-socket: 找不到 %s\n' "$SMOKE" >&2; exit 2; }
command -v tmux >/dev/null 2>&1 || { printf 'flip-p310-socket: 没有 tmux —— 这条腿判不了（需要私有 socket）\n' >&2; exit 2; }

KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --keep) KEEP=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) printf 'flip-p310-socket: 未知参数 %s（--keep）\n' "$1" >&2; exit 2 ;;
  esac
done
[ "$KEEP" = "1" ] && export TEAM_TMP_KEEP=1

TMP="$(tmp_root_create flip-p310sock)" || exit 3
cleanup() { [ "${BASHPID:-$$}" = "$$" ] && [ "$KEEP" = "0" ] && tmp_root_reap_all; }
trap cleanup EXIT

FAILED=0
case_ok()  { printf '  \033[32m✓\033[0m %s\n' "$*"; }
case_bad() { printf '  \033[31m✗\033[0m %s\n' "$*"; FAILED=1; }
ns="$(tmp_root_ns)"; uid="$(id -u)"

# ── 现场：一个**深到旧形状必然 >107 字节**的嵌套 TMPDIR ────────────────────────────────────
# 旧形状 = <TMPDIR>/teamsmith-smoke-<ns>.XXXXXX（临时根）+ /tmux（socket 目录）+ /tmux-<uid>/default
DEEP="$TMP/case-deep"; mkdir -p "$DEEP"
old_shape_len() { # <TMPDIR>
  printf '%s' "$(( ${#1} + 1 + 16 + ${#ns} + 1 + 6 + 5 + 6 + ${#uid} + 8 ))"
}
# 每加一层 /ddddddad 加 7 字节；上限 8 层（病态长 ns 也不至于打转）
i=0
while [ "$(old_shape_len "$DEEP")" -le 110 ] && [ "$i" -lt 8 ]; do
  DEEP="$DEEP/ddddddd"; mkdir -p "$DEEP"; i=$((i + 1))
done
OLD_LEN="$(old_shape_len "$DEEP")"
if [ "$OLD_LEN" -le 107 ]; then
  printf 'flip-p310-socket: 造不出「旧形状 >107 字节」的现场（算出来 %s）—— 夹具前提不成立\n' "$OLD_LEN" >&2
  exit 2
fi
printf '\033[1m══ P310 ①：私有 socket 的路径长度不随临时根变长 ══\033[0m\n'
printf '  嵌套 TMPDIR（%s 字节）：%s\n' "${#DEEP}" "$DEEP"
printf '  旧形状（socket 挂在临时根下）在这里是：%s 字节 > 107 —— 正是 §0i 的 ✗3 现场\n' "$OLD_LEN"

# 嵌套门禁：清掉身份/锁/socket 继承位（它必须自己算自己的 socket），私有 TMPDIR + FAST（不排队）
p310s_nest() { # <日志> [extra env assignment…]
  local log="$1"; shift
  ( cd "$TMP" && env -u TMUX -u TMUX_PANE -u TMUX_TMPDIR -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT \
      -u TEAM_SESSION -u TEAM_TMUX_REAL -u SMOKE_LOCK_WRAPPED -u SMOKE_LOCK_QUEUED -u SMOKE_LOCK_MARKER \
      -u TEAM_SMOKE_LOCK -u TEAM_SMOKE_LOCK_WAIT -u TEAM_SMOKE_NO_PRIVATE_TMUX -u TEAM_SMOKE_TMUX_UNDER_TMP \
      -u TEAM_SMOKE_BREAK -u TEAM_SMOKE_FIXTURE \
      TMPDIR="$DEEP" TEAM_SMOKE_FAST=1 "$@" \
      bash "$SMOKE" --select 0b ) >"$log" 2>&1
  printf '%s\n' "$?"
}
plain() { sed 's/\x1b\[[0-9;]*m//g' "$1" 2>/dev/null || true; }
sock_len_of() { # <日志> → 日志里那行私有 socket 路径的字节数（缺 → 空）
  local p
  p="$(plain "$1" | sed -n 's/^  · tmux 私有 socket：\(.*\)（夹具与产品调用都走它.*$/\1/p' | head -1)"
  [ -n "$p" ] && printf '%s' "$p" | wc -c | tr -d ' ' || true
}

# ── leg green：新形状 —— 深 TMPDIR 下 socket 仍 ≤107，门禁跑完（0c 的隔离前置通过）──────────
printf '\n\033[1m── leg green：深嵌套 TMPDIR 下照常跑（socket 目录在临时根之外）──\033[0m\n'
G_RC="$(p310s_nest "$TMP/green.log")"
G_LEN="$(sock_len_of "$TMP/green.log")"
if [ "$G_RC" != "0" ]; then
  case_bad "leg green：嵌套门禁退出码 [$G_RC]（期望 0）"
  plain "$TMP/green.log" | grep -a '隔离前置不成立\|socket 路径' | head -3 | sed 's/^/      /'
elif [ -z "$G_LEN" ]; then
  case_bad "leg green：日志里没有「tmux 私有 socket：」那行（0c 没跑到？）"
elif [ "$G_LEN" -gt 107 ]; then
  case_bad "leg green：socket 路径 ${G_LEN} 字节 > 107（改法没生效）"
else
  case_ok "leg green：rc=0 · socket 路径 ${G_LEN} 字节 ≤ 107（临时根之外）"
fi

# ── leg red：把 socket 目录放回临时根下（改动前的形状）→ 0c 必须硬停并点名长度 ──────────────
printf '\n\033[1m── leg red：socket 目录放回临时根下（TEAM_SMOKE_TMUX_UNDER_TMP=1）→ 必须硬停 ──\033[0m\n'
R_RC="$(p310s_nest "$TMP/red.log" TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_TMUX_UNDER_TMP=1)"
R_PLAIN="$(plain "$TMP/red.log")"
R_N="$(printf '%s\n' "$R_PLAIN" | sed -n 's/.*socket 路径 \([0-9]\+\) 字节 > AF_UNIX 上限 107.*/\1/p' | head -1)"
if [ "$R_RC" != "2" ]; then
  case_bad "leg red：嵌套门禁退出码 [$R_RC]（期望 2 —— 隔离前置硬停）"
elif ! printf '%s\n' "$R_PLAIN" | grep -aq '隔离前置不成立'; then
  case_bad "leg red：日志里没有「隔离前置不成立」"
elif [ -z "$R_N" ]; then
  case_bad "leg red：硬停没有点名 socket 长度（找不到「socket 路径 N 字节 > AF_UNIX 上限 107」）"
elif [ "$R_N" != "$OLD_LEN" ]; then
  case_bad "leg red：点名的长度 [$R_N] 不是旧形状算出来的 [$OLD_LEN]（判据点到别处去了）"
elif printf '%s\n' "$R_PLAIN" | grep -aq '== 选段结果 =='; then
  case_bad "leg red：硬停之后还出了结果行（门禁应当根本没跑起来）"
else
  case_ok "leg red：rc=2 · 点名「socket 路径 ${R_N} 字节 > AF_UNIX 上限 107」= 旧形状的长度 · 没有结果行"
fi

printf '\n'
if [ "$FAILED" = "0" ]; then
  printf '\033[32mflip-p310-socket：两条腿都对上了\033[0m\n'
  exit 0
fi
printf '\033[31mflip-p310-socket：有腿没按预期\033[0m\n' >&2
[ "$KEEP" = "1" ] && printf '保留：%s\n' "$TMP"
exit 1
