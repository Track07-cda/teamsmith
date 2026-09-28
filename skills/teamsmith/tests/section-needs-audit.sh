#!/usr/bin/env bash
# teamsmith · 逐键 needs 自足审计（change: gate-runtime-budget · P117/V2）
#
#   对每个段键 K：跑一遍 `smoke.sh --select K`（FAST / 私有 TMPDIR / 不排队），断言：
#     ① K 自己的段落**真的跑了**（有收口行）——没有就是 bad；
#     ② K 自己的段落 ✗0；同时整条选集的退出码必须是 0。
#   为什么要逐键：`--paths` 的结论是若干键的并集，一个键缺前提会被别的键的绿遮住；
#   逐键跑才能把「这条 needs 够不够」钉在数据上（P112 §5.2：3b 缺 5、6 缺 5、10 缺 4b/5/9、28 缺 26）。
#
#   用法：section-needs-audit.sh [--keys <k1,k2,…>] [--root <树>] [--keep]
#     --keys   只审计这几个键（默认：表里的全部键）
#     --root   在另一棵树上跑（默认本脚本所在的仓库；夹具/复验用）
#     --keep   保留日志与临时根（打印路径），便于诊断
#   退出码：0 = 被判定的键全部绿；1 = 有键红 / 没跑；2 = 用法或环境错误。
#
#   纪律：**顺序执行**。夹具会在树内注入→还原；并发跑同一棵树会互相掀桌子
#   （P117 实测：-P2 两次运行把注入写进对方现场，之后的每一键都大面积假红）。
set -uo pipefail

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${TEAM_NEEDS_AUDIT_ROOT:-$(cd -P "$here/../../.." && pwd)}"
KEYS=""
KEEP=0

usage() { sed -n '2,21p' "$0"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --keys)   shift; [ $# -gt 0 ] || { printf 'section-needs-audit: --keys 需要值\n' >&2; exit 2; }; KEYS="$1"; shift ;;
    --keys=*) KEYS="${1#*=}"; shift ;;
    --root)   shift; [ $# -gt 0 ] || { printf 'section-needs-audit: --root 需要目录\n' >&2; exit 2; }; ROOT="$1"; shift ;;
    --root=*) ROOT="${1#*=}"; shift ;;
    --keep)   KEEP=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'section-needs-audit: 未知参数 %s（用法见 --help）\n' "$1" >&2; exit 2 ;;
  esac
done

ROOT="$(cd -P "$ROOT" 2>/dev/null && pwd)" || { printf 'section-needs-audit: --root 目录不存在\n' >&2; exit 2; }
SUITE="$ROOT/skills/teamsmith/tests/smoke.sh"
SEL="$ROOT/skills/teamsmith/tests/section-select.sh"
[ -r "$SUITE" ] || { printf 'section-needs-audit: 读不到 %s\n' "$SUITE" >&2; exit 2; }
[ -r "$SEL" ] || { printf 'section-needs-audit: 读不到 %s\n' "$SEL" >&2; exit 2; }
[ -n "$KEYS" ] || { KEYS="$(bash "$SEL" --list | awk -F'\t' '{printf "%s,", $1}')"; KEYS="${KEYS%,}"; }
[ -n "$KEYS" ] || { printf 'section-needs-audit: 表里一个键都没有\n' >&2; exit 2; }

# owned 家族口径（section 40 的 lint）：根建在 ${TMPDIR:-/tmp}/teamsmith-<kind>.XXXXXX 下；
# 长度仍然够短 —— 嵌套 run 的私有 tmux socket = len($TMP)+22，本例约 90 < 107（AF_UNIX 上限）。
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/teamsmith-needs-audit.XXXXXX")" || { printf 'section-needs-audit: 建不了临时根\n' >&2; exit 2; }
if [ "$KEEP" = 1 ]; then
  printf 'section-needs-audit: 日志留在 %s\n' "$TMPROOT"
else
  trap 'rm -rf "$TMPROOT"' EXIT
fi

# <日志> <key> → 该键自己的收口行（剥 ANSI）；没有 = 空
own_line() {
  sed 's/\x1b\[[0-9;]*m//g' "$1" | awk -v k="$2" '$1 ~ /^#[0-9]+$/ && $2 == k && /用时/ { print; exit }'
}
# <收口行> → ✗ 数（解不出 = 空）
own_fail() {
  printf '%s' "$1" | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^✗[0-9]+$/) { f = $i; gsub(/[^0-9]/, "", f); print f; exit } }'
}

N=0; NPASS=0; NBAD=0
printf '== needs 逐键审计 ==\n'
printf '树：%s\n' "$ROOT"
for k in $(printf '%s' "$KEYS" | tr ',' ' '); do
  [ -n "$k" ] || continue
  N=$((N + 1))
  d="$TMPROOT/$k"; log="$TMPROOT/$k.log"
  mkdir -p "$d"
  ( cd "$ROOT" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_AGENT_MODEL \
      -u TEAM_SKILL_DIR -u TEAM_DOCS_DIR -u TEAM_AGENT -u SMOKE_TMP_RUN_ID -u SMOKE_TMP_LEDGER \
      -u TEAM_SMOKE_KEEP -u TEAM_TMP_KEEP -u SMOKE_SEL_CHILD -u SMOKE_SEL_SKILL_DIR \
      -u SMOKE_SEL_DECISION -u SMOKE_SEL_COPY -u TEAM_SMOKE_LOCK_WAIT \
      TMPDIR="$d" TEAM_SMOKE_FAST=1 TEAM_SMOKE_NO_LOCK=1 \
      bash "$SUITE" --select "$k" ) >"$log" 2>&1
  rc=$?
  line="$(own_line "$log" "$k")"; f="$(own_fail "$line")"
  if [ -z "$line" ]; then
    printf 'bad  %-8s rc=%-3s own=没有收口行（段没跑）\n' "$k" "$rc"
    NBAD=$((NBAD + 1)); continue
  fi
  if [ "$rc" -eq 0 ] && [ "${f:-1}" = "0" ]; then
    printf 'ok   %-8s rc=0  %s\n' "$k" "$line"
    NPASS=$((NPASS + 1))
  else
    printf 'bad  %-8s rc=%-3s %s\n' "$k" "$rc" "$line"
    NBAD=$((NBAD + 1))
  fi
done
printf '== needs 逐键审计结果 ==  pass %d  bad %d  （共 %d 键）\n' "$NPASS" "$NBAD" "$N"
[ "$NBAD" -eq 0 ] || exit 1
exit 0
