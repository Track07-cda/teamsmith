#!/usr/bin/env bash
# M58/B2 · 旋钮完整性（时间无关）—— 正确性门禁每轮跑的 d-realpath 承诺。
#
#   bash skills/teamsmith/tests/panel-knobs.sh          （FAST 安全：不起 tmux / node / 任何测量）
#
# 背景：`panel#Frame assembly is asynchronous…` 的「夹具旋钮不得漏进真路径」以前由面板测量夹具的
# d-realpath 用例带着一次真测量来证；M58 把测量搬进性能套件后，正确性门禁
# 只留**时间无关**的这一半：
#   ① 三个 TEAM_PANEL_CPU_* 旋钮在夹具开关关着时必须被忽略并打印；
#   ② premise 行只反映真读数（不许出现注入的 9999 / 1 核）；
#   ③ 不判任何时长（输出里没有 median / budget / pane CPU 判定行）。
# 实现走 panel-cpu.sh 的 premise-only 模式（TEAM_PANEL_CPU_PREMISE_ONLY=1）：那条路径在起 tmux/node
# 之前就退出，所以门禁不再点名任何测量夹具（守卫见 tests/gate-guard.sh）。
#
# 退出码：0 全绿；1 有失败项。输出：ok/bad + `== 结果 ==` 一行。
set -uo pipefail

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tree="${TEAM_PANEL_CPU_TREE:-$(cd -P "$here/../../.." && pwd)}"
cpu="$here/panel-cpu.sh"
PASS=0; FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
result_line() { printf '\n== 结果 ==  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"; }

if [ ! -f "$cpu" ]; then
  bad "缺 $cpu（premise-only 模式的宿主）"
  result_line; exit 1
fi
real_load="$(cut -d' ' -f1 /proc/loadavg 2>/dev/null || printf '?')"
real_cores="$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || printf 0)"
case "$real_cores" in ''|*[!0-9]*) real_cores=0 ;; esac

out="$(mktemp "${TMPDIR:-/tmp}/panel-knobs.XXXXXX")"
trap 'rm -f "$out"' EXIT
# 夹具开关**显式清掉**（继承来的 TEAM_SMOKE_FIXTURE=1 会让注入被采信，那样这条检查就假绿）；
# 三个旋钮全部注入，正是 d-realpath 的形状。
(
  cd "$tree" && env -u TEAM_SMOKE_FIXTURE -u TEAM_SMOKE_LOADAVG -u TEAM_SMOKE_CORES \
    -u TEAM_SMOKE_FRAME_DELAY_MS -u TMUX -u TMUX_PANE -u TMUX_TMPDIR \
    TEAM_PANEL_CPU_LOADAVG=9999 TEAM_PANEL_CPU_CORES=1 TEAM_PANEL_CPU_FRAME_DELAY_MS=99999 \
    TEAM_PANEL_CPU_PREMISE_ONLY=1 \
    timeout 30 bash "$cpu"
) >"$out" 2>&1
rc=$?
if [ "$rc" = 0 ]; then
  ok "premise-only 模式退出 0（它不判时长）"
else
  bad "premise-only 模式退出 $rc（期望 0）"; sed -n '1,6p' "$out" | sed 's/^/      /'
fi
for kv in 'TEAM_PANEL_CPU_LOADAVG=9999' 'TEAM_PANEL_CPU_CORES=1' 'TEAM_PANEL_CPU_FRAME_DELAY_MS=99999'; do
  if grep -qF "忽略 $kv" "$out"; then ok "注入的旋钮被忽略并打印：$kv"
  else bad "没有看到「忽略 $kv」行"; fi
done
if grep -qE 'load premise: loadavg [0-9.]+ (<=|>) [0-9.]+ \(0\.25 x [0-9]+ cores\)' "$out"; then
  ok "premise 行在，且是 0.25 × 核格式"
else
  bad "缺 premise 行（或格式不是 0.25 × 核）"; sed -n '/load premise/p' "$out" | sed 's/^/      /'
fi
if [ "$real_cores" -gt 0 ] && grep -qF "(0.25 x ${real_cores} cores)" "$out"; then
  ok "premise 行用的是真核数（${real_cores}）"
else
  bad "premise 行没有用真核数（期望 0.25 x ${real_cores} cores）"
fi
if grep -qF "loadavg ${real_load}" "$out"; then
  ok "premise 行用的是真 loadavg（${real_load}）"
else
  bad "premise 行的 loadavg 不是真读数（期望 ${real_load}）"; sed -n '/load premise/p' "$out" | sed 's/^/      /'
fi
if [ "$real_cores" != "1" ] && grep -qE 'loadavg 9999|\(0\.25 x 1 cores\)' "$out"; then
  bad "premise 行里出现了注入值（旋钮漏进了真路径！）"
else
  ok "premise 行里没有注入值（没有 9999 / 1 核）"
fi
if grep -qE 'median [0-9]|budget 2000ms|pane CPU' "$out"; then
  bad "premise-only 模式判了时长（输出里出现 median/budget/pane CPU）"
else
  ok "没有判任何时长（输出里没有 median/budget 判定行）"
fi

result_line
[ "$FAIL" -eq 0 ] && { printf '\033[32mpanel-knobs 全绿\033[0m\n'; exit 0; }
printf '\033[31mpanel-knobs 有失败项\033[0m\n'; exit 1
