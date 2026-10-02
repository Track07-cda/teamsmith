#!/usr/bin/env bash
# teamsmith · P162 · 隔离前置的红侧探针（子进程夹具）
#
#   在**子进程**里跑一次与门禁相同的形态：证明（tmux_iso_require）→ 才动手（破坏性动作）。
#   用来在 0h 段/翻转包里造两个已知的「假隔离」形状与影子变异，断言「硬停 + 点名 + 审计 + 没动手」。
#
#   用法：
#     tmux-iso-probe.sh <tmux-iso.sh 路径> <审计日志> <破坏性动作桩> [证明参数…] [-- <动作 argv…>]
#   证明参数直接交给 tmux_iso_require（--tmpdir DIR / --sock-name NAME / --own-root DIR / --caller-tmpdir DIR …）。
#   默认「破坏性动作」= 往桩文件追加一行 DESTRUCTIVE-RAN（证明通过才写）；给 `-- <argv…>` 可换成真命令
#   （例如一个只打私有 socket 的 kill-server）。
#
#   输出：SKIP 行（前置不成立时）、硬停结论行（由库里打）；成功时无噪声。
#   exit：0 = 证明通过且动作执行了 ｜ 2 = 硬停（前置不成立）｜ 9 = 驱动自身问题（参数/库）
# shellcheck shell=bash
set -uo pipefail

LIB="${1:-}"; LOG="${2:-}"; STUB="${3:-}"; shift 3 2>/dev/null || true
if [ -z "$LIB" ] || [ ! -f "$LIB" ] || [ -z "$LOG" ] || [ -z "$STUB" ]; then
  printf 'tmux-iso-probe: 用法：%s <lib> <log> <stub> [证明参数…] [-- 动作]\n' "${0##*/}" >&2
  exit 9
fi

# 证明参数 vs 动作：`--` 之前给 tmux_iso_require，之后是动作 argv（默认动作为写桩）
PROVE=(); ACTION=(); seen_sep=0
for a in "$@"; do
  if [ "$seen_sep" = "1" ]; then ACTION+=("$a")
  elif [ "$a" = "--" ]; then seen_sep=1
  else PROVE+=("$a"); fi
done

TMUX_ISO_LOG="$LOG"; export TMUX_ISO_LOG
TEAM_TMUX_ISO_LOG="$LOG"; export TEAM_TMUX_ISO_LOG
# shellcheck source=tmux-iso.sh
. "$LIB" || exit 9

# 探针自己的 SKIP 出口：字面格式 = 任务书要求（`SKIP（前置不成立：<哪一条>）`）
tmux_iso_skip() { printf 'SKIP（前置不成立：%s） %s\n' "$2" "$1"; }

tmux_iso_require "P162 探针" "破坏性动作（探针）" ${PROVE[@]+"${PROVE[@]}"}
if [ "${#ACTION[@]}" -gt 0 ]; then
  "${ACTION[@]}" || exit 9
else
  printf 'DESTRUCTIVE-RAN\n' >>"$STUB"
fi
exit 0
