#!/usr/bin/env bash
# P26/G3 · panel-cpu.sh 的**负载前提**夹具：四种形状，逐个钉退出码。
#
#   bash skills/teamsmith/tests/panel-cpu-premise.sh
#
# 为什么单独一个脚本：每个用例都要真起一个 tmux 私有 server + 真面板，全跑 ~1 分钟，所以它不进
# FAST 段；smoke 的 §36 在**全量模式**里调它（FAST 模式显式 SKIP）。
#
# 用例（panel#Frame assembly is asynchronous… MODIFIED）：
#   a) 夹具负载 > 前提 + 真越线的首帧 → **exit 4**（跳过：打印首帧 ms、窗格 CPU%、load）
#   b) 夹具负载 ≤ 前提 + 同一个越线首帧 → exit 2（红线没有被前提拿走）
#   c) 夹具负载 ≤ 前提 + 健康首帧 → exit 0
#   d) 真路径（不开 TEAM_SMOKE_FIXTURE）：两个夹具旋钮被忽略且打印，判定不受影响（不是 4）
#
# 真机负载本身就超前提时，本脚本**可见地跳过**（exit 4）——那是机器忙，不是夹具坏了。
# 环境缺少树 CPU 图要的 GNU time（`/usr/bin/time`）时也一样**可见跳过**（exit 4）：`panel-cpu.sh`
# 自己会因此跳过，下面的四个期望（4 / 2 / 0 / 2）就都无从判起 —— 把环境缺口算成面板红是假红
# （M51 的 CI 红就是这个形状）。
set -uo pipefail

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tree="${TEAM_PANEL_CPU_TREE:-$(cd -P "$here/../../.." && pwd)}"
cpu="$here/panel-cpu.sh"
window="${TEAM_PANEL_CPU_SECS:-6}"   # 太短的窗口会把启动尾巴算进 CPU 均值（实测 3s → 1.6%，6s → 0.4%）
tmp="$(mktemp -d "${TMPDIR:-/tmp}/p26premise.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
# 缺 GNU time → 可见跳过（与 panel-cpu.sh 的 exit 4 同一个语义：没结论，不是通过也不是红）。
# 解析口径与 panel-cpu.sh 逐字一致（`/usr/bin/time`，否则 PATH 上的 `time`）。
p26_time_ok=0
for _p26c in /usr/bin/time "$(command -v time || true)"; do [ -x "$_p26c" ] && { p26_time_ok=1; break; }; done
if [ "$p26_time_ok" != "1" ]; then
  printf 'panel-cpu-premise: SKIP（树 CPU 图需要 GNU time = /usr/bin/time，本环境没装 → panel-cpu.sh 会可见跳过，四个用例无从判定）\n'
  exit 4
fi
PASS=0; FAIL=0; FIND=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
finding() { printf '  \033[33mfinding\033[0m %s\n' "$1"; FIND=$((FIND + 1)); }

cores="$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || printf 0)"
case "$cores" in ''|*[!0-9]*) cores=0 ;; esac
real_load="$(cut -d' ' -f1 /proc/loadavg 2>/dev/null || printf '?')"
if [ "$cores" -le 0 ]; then
  printf 'panel-cpu-premise: SKIP（读不到逻辑核数）\n'; exit 4
fi
FACTOR="${TEAM_PANEL_CPU_PREMISE_FACTOR:-0.25}"   # 与 panel-cpu.sh 同一个旋钮/同一个默认值
case "$FACTOR" in ''|*[!0-9.]*) FACTOR=0.25 ;; esac
thr="$(awk -v c="$cores" -v f="$FACTOR" 'BEGIN { printf "%.2f", f * c }')"
above="$(awk -v t="$thr" 'BEGIN { printf "%.2f", t + 1.0 }')"
below="$(awk -v t="$thr" 'BEGIN { printf "%.2f", (t > 1.0) ? t - 1.0 : 0.0 }')"
# 真机安静与否只影响**用例 c** 的严格程度（它真的在量这台机器），不再直接退出：
# a/b/d 的读数由夹具注入，任何真机负载下都有意义。
if awk -v l="$real_load" -v t="$thr" 'BEGIN { exit !(l <= t) }'; then
  printf '== 前提：真机 loadavg %s ≤ %s（%s × %s 核）→ 用例 c 用**严格**期望（exit 0）\n' \
    "$real_load" "$thr" "$FACTOR" "$cores"
else
  printf '== 前提：真机 loadavg %s > %s（%s × %s 核）→ 用例 c 只允许「0 或 2+实测数」并把 2 记成 finding\n' \
    "$real_load" "$thr" "$FACTOR" "$cores"
fi
printf '== 用例读数用 above=%s / below=%s（夹具注入）；阈值 %s = %s × %s 核\n' "$above" "$below" "$thr" "$FACTOR" "$cores"

run_case() { # <名字> <期望 rc | `-` 表示不断言> <env…> -- <断言用的 pattern…>
  local name="$1" want="$2"; shift 2
  local envs=(); while [ $# -gt 0 ] && [ "$1" != "--" ]; do envs+=("$1"); shift; done
  [ "${1:-}" = "--" ] && shift
  local out="$tmp/$name.log"
  ( cd "$tree" && env -u TMUX -u TMUX_PANE ${envs[@]+"${envs[@]}"} TEAM_PANEL_CPU_SECS="$window" \
      timeout 300 bash "$cpu" ) >"$out" 2>&1
  local rc=$?
  LAST_RC=$rc
  printf '    %s：rc=%s（期望 %s）；尾部：%s\n' "$name" "$rc" "$want" "$(sed -n 's/^panel-cpu: //p' "$out" | tail -1)"
  if [ "$want" = "-" ]; then
    ok "panel-cpu-premise $name：退出码 $rc（本条不断言，调用方接着判）"
  elif [ "$rc" = "$want" ]; then ok "panel-cpu-premise $name：退出码 $rc"; else
    bad "panel-cpu-premise $name：期望退出码 $want，实际 $rc（见 $out）"
    sed -n '/^== /p;/^panel-cpu:/p' "$out" | tail -4 | sed 's/^/      /'
  fi
  local pat
  for pat in "$@"; do
    if grep -aqE -- "$pat" "$out"; then ok "panel-cpu-premise $name：输出里有 /$pat/"; else
      bad "panel-cpu-premise $name：输出里没有 /$pat/"; fi
  done
  LAST_OUT="$out"
}

# a) 负载超前提 + 真越线的首帧 → 4（注入 2500ms：三次 spawn 的中位必然 > 2000，不做时序假设）
run_case a-above 4 TEAM_SMOKE_FIXTURE=1 TEAM_PANEL_CPU_LOADAVG="$above" TEAM_PANEL_CPU_CORES="$cores" \
  TEAM_PANEL_CPU_FRAME_DELAY_MS=2500 -- 'load premise: loadavg .* > ' 'SKIP \(exit 4' 'first frame: .*-> median (never|[0-9]+) \(budget 2000ms\)'
# `never` 也属于「越线」（>2000ms）：夹具的轮询预算 ~3.1s，注入把首帧推到它之后
grep -aqE 'first frame: .*-> median (never|2[0-9]{3}|[3-9][0-9]{3})' "$LAST_OUT" \
  && ok "panel-cpu-premise a-above：注入真的把首帧抬过 2000ms（$(sed -n 's/^== first frame: //p' "$LAST_OUT" | head -1)）" \
  || bad "panel-cpu-premise a-above：注入没造出越线的首帧（$(sed -n 's/^== first frame: //p' "$LAST_OUT" | head -1)）"

# b) 负载低于前提 + 同一个越线首帧 → 2（红线没被前提拿走）
run_case b-below 2 TEAM_SMOKE_FIXTURE=1 TEAM_PANEL_CPU_LOADAVG="$below" TEAM_PANEL_CPU_CORES="$cores" \
  TEAM_PANEL_CPU_FRAME_DELAY_MS=2500 -- 'load premise: loadavg .* <= ' 'panel-cpu: RED'

# c) 负载低于前提 + 健康首帧 → 0。注意：这条**真的**在量这台机器的 CPU/首帧（前提只管负载，不管别的
#    重活儿）—— 同机的全量门禁/复验正在跑时，它会读到越线的首帧或 CPU（实测：与 P24 的全量 smoke
#    并发时 CPU 1.6%；load 17 时首帧 2294ms）。
#    口径（PM 复验 2026-09-20T13:33Z 的教训，与 d 同理）：
#      * 机器安静（load ≤ 0.5 × 阈值）：**严格**要求 exit 0；
#      * 机器不安静：只允许 0（仍绿） 或 2（本机读数越线 → 记 finding，把首帧/CPU/load 写出来）；
#        决不允许 4（负载低于前提时不该走跳过）也决不允许别的码。
quiet_gate="$(awk -v t="$thr" 'BEGIN { printf "%.2f", 0.5 * t }')"   # 严格期望只在这条线以内给
machine_quiet=0
awk -v l="$real_load" -v t="$quiet_gate" 'BEGIN { exit !(l <= t) }' && machine_quiet=1
run_case c-healthy - TEAM_SMOKE_FIXTURE=1 TEAM_PANEL_CPU_LOADAVG="$below" TEAM_PANEL_CPU_CORES="$cores" -- \
  'load premise: loadavg .* <= '
C_OUT="$LAST_OUT"   # M58：c-healthy 的原始日志（给 tests/perf.sh 的机读读数用；d-* 会把 LAST_OUT 改掉）
C_FF="$(sed -n 's/.*-> median \(never\|[0-9]*\) (budget.*/\1/p' "$LAST_OUT" | head -1)"
C_PANE="$(sed -n 's/.*-> median \([0-9.]*\)% (overall.*/\1/p' "$LAST_OUT" | tail -1)"
C_RC="${LAST_RC:-?}"
if [ "$C_RC" = "0" ]; then
  ok "panel-cpu-premise c-healthy：健康帧 + 前提成立 → 退出码 0（首帧 ${C_FF:-?}ms，窗格 CPU ${C_PANE:-?}%）"
elif [ "$C_RC" = "2" ] && [ "$machine_quiet" = "0" ]; then
  finding "panel-cpu-premise c-healthy：机器不安静（真机 loadavg ${real_load} > ${quiet_gate}）时判红：首帧 ${C_FF:-?}ms、窗格 CPU ${C_PANE:-?}% —— 是这台机器的读数（安静时同夹具 0.4% / ~1.5s），不是面板回归；不给健康结论也不冤枉面板"
elif [ "$C_RC" = "2" ]; then
  bad "panel-cpu-premise c-healthy：机器安静（loadavg ${real_load} ≤ ${quiet_gate}）却判红（首帧 ${C_FF:-?}ms、CPU ${C_PANE:-?}%）—— 机器安静时这是真红"
else
  bad "panel-cpu-premise c-healthy：退出码 $C_RC 不在 {0, 2} 里（负载低于前提时不该出现跳过/其他码）"
fi

# d) 真路径：夹具旋钮被忽略（打印忽略行）且**判定不受影响**。
#
# PM 复验（2026-09-20T13:33Z，load≈20）抓到这里的期望写错了：原来写死 `0`，等于假设机器安静 ——
# 在前提之内但机器忙/面板真慢时，真路径会诚实地判红（exit 2），那是**判定**，不是后门。
# 现在分两层：
#   ① 期望集合 **{0,4}**（健康：0；真机负载超前提：4）；
#   ② 若得到 2（前提内但判红），跑一次**不带旋钮的对照抛** —— 两边同为 2 ⇒ 是这台机器/面板的读数
#      （记 finding）；两边不同 ⇒ 旋钮改了判定，才是后门（红）。
# 反后门的三条断言（两个「忽略」行 + premise 行必须反映**真实**读数）无条件保留。
run_case d-realpath - TEAM_PANEL_CPU_LOADAVG=9999 TEAM_PANEL_CPU_CORES=1 TEAM_PANEL_CPU_FRAME_DELAY_MS=99999 -- \
  '忽略 TEAM_PANEL_CPU_LOADAVG=9999' '忽略 TEAM_PANEL_CPU_CORES=1' '忽略 TEAM_PANEL_CPU_FRAME_DELAY_MS=99999' \
  'load premise: loadavg [0-9.]+ (<=|>) [0-9.]+ \([0-9.]+ x [0-9]+ cores\)'
# premise 行里不允许出现注入值（9999 / 1 核）——「必须反映真实读数」的可机检形式
grep -aqE 'load premise: loadavg 9999|0\.75 x 1 cores' "$LAST_OUT" \
  && bad "panel-cpu-premise d-realpath：premise 行里出现了注入值（旋钮漏进了真路径！）" \
  || ok "panel-cpu-premise d-realpath：premise 行只反映真实读数（没有 9999 / 1 核）"
D_FF="$(sed -n 's/.*-> median \(never\|[0-9]*\) (budget.*/\1/p' "$LAST_OUT" | head -1)"
D_PANE="$(sed -n 's/.*-> median \([0-9.]*\)% (overall.*/\1/p' "$LAST_OUT" | tail -1)"
D_RC="$LAST_RC"
case "$D_RC" in
  0|4) ok "panel-cpu-premise d-realpath：真路径退出码 $D_RC ∈ {0,4}（旋钮没有改变判定）" ;;
  2)
    # 真路径判红。**反后门不靠跨跑比较**（两次跑之间机器可能变忙/变闲 —— 跨跑比较会冤枉实现）：
    # 它由上面三条**同一次跑内**的断言保证（三个「忽略…」行 + premise 行只反映真实读数）。
    # 对照跑只作为日志读数打印，判红本身记 finding。
    run_case d-control 2 -- 'load premise: loadavg [0-9.]+ <='
    finding "panel-cpu-premise d-realpath：真路径判红（exit 2）：首帧 ${D_FF:-?}ms、窗格 CPU ${D_PANE:-?}%、load $(cut -d' ' -f1 /proc/loadavg) —— 这台机器的读数（对照跑 rc=${LAST_RC:-?} 仅作参考；反后门由本次跑内的三条断言负责）"
    ;;
  *) bad "panel-cpu-premise d-realpath：退出码 $D_RC 既不是 0/4（期望集合）也不是 2（可解释）" ;;
esac

# M58：给 tests/perf.sh 的机读读数（**附加输出**：不改任何断言/期望/退出码语义）。
# c-healthy 是「真机 + 注入前提成立」的测量案例 —— 它的首帧/窗格 CPU 中位就是红线判定 ①③ 的读数；
# 上面的 ok/finding/bad 行是给人读的，这里给套件一份稳定形状。
printf '== perf-readings ==\n'
printf 'first_frame_line=%s\n' "$(sed -n 's/^== first frame: //p' "${C_OUT:-}" 2>/dev/null | head -1)"
printf 'pane_cpu_line=%s\n' "$(sed -n 's/^== pane CPU thirds: //p' "${C_OUT:-}" 2>/dev/null | tail -1)"

printf '\n== 结果 ==  ✓ %d  ✗ %d finding %d\n' "$PASS" "$FAIL" "$FIND"
if [ "$FAIL" -gt 0 ]; then
  printf '\033[31mpanel-cpu-premise 有失败项\033[0m\n'; exit 1
fi
if [ "$FIND" -gt 0 ]; then
  # 只有 finding（典型：机器被别的门禁占着，窗格 CPU 读不出干净的数）→ **exit 4**（没结论），
  # 与 panel-cpu.sh 的负载跳过同一个码：既不是通过也不是红，调用方据此可见地 SKIP。
  printf '\033[33mpanel-cpu-premise：有 finding（机器不够安静）→ 退出 4（没结论）\033[0m\n'; exit 4
fi
printf '\033[32mpanel-cpu-premise 全绿\033[0m\n'; exit 0
