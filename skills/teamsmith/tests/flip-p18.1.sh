#!/usr/bin/env bash
# teamsmith · P18.1 翻转夹具：两栏共享预算（旧 bundle）必须让新夹具变红
#
#   bash skills/teamsmith/tests/flip-p18.1.sh                 # pre 侧 = 最近一次改过 src/layout.ts 的提交的父提交
#   bash skills/teamsmith/tests/flip-p18.1.sh --pre-rev <rev> # 指定 pre 侧 revision
#   bash skills/teamsmith/tests/flip-p18.1.sh --keep          # 保留临时目录与两侧日志
#
# 两侧跑**同一个**检查（tests/panel-snapshots.sh 的 P18.1 段），只换 bundle：
#   pre（共享记账 `used = max(两列)`）→ 新夹具红，且**只有它红**（其余 47 条照旧绿）；
#   当前树（每列独立记账）           → 全绿。
# 这样翻转证明的是「夹具真的在测这次修的那件事」，不是「有人把断言改红了/改绿了」。
#
# 退出码：0 = 翻转成立（pre 红 / 当前绿）｜1 = 期望不成立（两侧日志路径会打印）｜2 = 环境缺依赖。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
TREE="$(cd -P "$SKILL_DIR/../.." && pwd)"
PIN="$SKILL_DIR/scripts/panel/panel.js"
LAYOUT="skills/teamsmith/scripts/panel/src/layout.ts"
PRE_REV=""
KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --pre-rev) PRE_REV="${2:?--pre-rev 需要 revision}"; shift 2 ;;
    --pre-rev=*) PRE_REV="${1#*=}"; shift ;;
    --keep) KEEP=1; shift ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) printf 'flip-p18.1: 未知参数 %s\n' "$1" >&2; exit 2 ;;
  esac
done

js="$(command -v node || command -v bun || true)"
[ -n "$js" ] || { printf 'flip-p18.1: 本机没有 node/bun\n' >&2; exit 2; }
command -v git >/dev/null 2>&1 || { printf 'flip-p18.1: 本机没有 git\n' >&2; exit 2; }
[ -s "$PIN" ] || { printf 'flip-p18.1: 找不到 bundle（%s）\n' "$PIN" >&2; exit 2; }
if [ -z "$PRE_REV" ]; then
  last="$(git -C "$TREE" log -n1 --format=%H -- "$LAYOUT" 2>/dev/null)"
  [ -n "$last" ] || { printf 'flip-p18.1: git 历史里找不到 %s\n' "$LAYOUT" >&2; exit 2; }
  PRE_REV="$last^"
fi

tmp="$(mktemp -d "${TMPDIR:-/tmp}/teamsmith-flip-p18.1.XXXXXX")"
cleanup() { [ "${BASHPID:-$$}" = "$$" ] && [ "$KEEP" = "0" ] && rm -rf "$tmp"; }
trap cleanup EXIT

pre_bundle="$tmp/pre-panel.js"
if ! git -C "$TREE" show "$PRE_REV:skills/teamsmith/scripts/panel/panel.js" >"$pre_bundle" 2>"$tmp/show.err" || [ ! -s "$pre_bundle" ]; then
  printf 'flip-p18.1: 取不到 %s 的 bundle（%s）\n' "$PRE_REV" "$(head -1 "$tmp/show.err" 2>/dev/null)" >&2
  exit 2
fi
if cmp -s "$pre_bundle" "$PIN"; then
  printf 'flip-p18.1: pre 侧 bundle 与当前树逐字节相同 —— 没有东西可翻（--pre-rev 指一个旧 revision）\n' >&2
  exit 2
fi

run_side() { # <bundle> <log>
  TEAM_SNAPSHOTS_PANEL="$1" TEAM_SNAPSHOTS_JS="$js" bash "$SELF_DIR/panel-snapshots.sh" >"$2" 2>&1
}

printf '\033[1m== flip-p18.1 · pre = %s ==\033[0m\n' "$PRE_REV"
run_side "$pre_bundle" "$tmp/pre.log"; pre_rc=$?
run_side "$PIN" "$tmp/now.log"; now_rc=$?

sides_ok=1
# 只数「行首两条空格 + ✗」的真失败行：结尾的 `== 结果 == … ✗ N` 汇总行里也有 ✗。
pre_bad="$(grep -E '^  .*✗' "$tmp/pre.log" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')"
pre_p181="$(printf '%s\n' "$pre_bad" | grep -c 'P18.1' | tr -d ' ')"
pre_other="$(printf '%s\n' "$pre_bad" | grep -v 'P18.1' | grep -c '✗' | tr -d ' ')"
if [ "$pre_rc" -ne 0 ] && [ "$pre_p181" = "2" ] && [ "$pre_other" = "0" ]; then
  printf '  \033[32m✓\033[0m pre（共享记账）：P18.1 两条夹具红，其余断言全绿（%s）\n' \
    "$(printf '%s\n' "$pre_bad" | head -1 | cut -c1-90)"
else
  sides_ok=0
  printf '  \033[31m✗\033[0m pre：期望恰好 2 条 P18.1 红 + 0 条其它红，实际 rc=%s / P18.1 红=%s / 其它红=%s\n' \
    "$pre_rc" "$pre_p181" "$pre_other"
fi
if [ "$now_rc" -eq 0 ] && grep -q 'panel-snapshots 全绿' "$tmp/now.log"; then
  printf '  \033[32m✓\033[0m 当前树（每列独立记账）：%s\n' "$(grep '结果' "$tmp/now.log" | sed 's/\x1b\[[0-9;]*m//g' | tail -1)"
else
  sides_ok=0
  printf '  \033[31m✗\033[0m 当前树没有全绿（rc=%s）\n' "$now_rc"
  grep '✗' "$tmp/now.log" | sed 's/\x1b\[[0-9;]*m//g' | head -4
fi

if [ "$sides_ok" = "1" ]; then
  printf '\033[32mflip-p18.1 翻转成立\033[0m\n'
  [ "$KEEP" = "1" ] && printf '日志保留：%s\n' "$tmp"
  exit 0
fi
printf '\033[31mflip-p18.1 翻转不成立\033[0m —— 两侧日志在 %s\n' "$tmp"
exit 1
