#!/usr/bin/env bash
# M58/B2 · 双向机械守卫：正确性门禁里没有性能判定，性能套件里必须有判定标记。
#
#   bash skills/teamsmith/tests/gate-guard.sh      （纯逻辑：只 grep 三个文件，不起任何进程）
#
# 三条（任一不成立 → 打印 `bad: …` 并退出 1）：
#   ① `smoke.sh`（门禁本体）不得含性能判定标记，也不得点名测量夹具；
#   ② `panel-knobs.sh`（时间无关的旋钮完整性助手）必须在，且走 premise-only、不驱赶测量夹具；
#   ③ `perf.sh`（性能套件）必须带着那组命名单源标记 —— 「偷懒式搬迁」（从门禁删了但没落地）会被抓住。
#
# 判定标记是一个**封闭集合**（design D6）：帧预算 / CPU 份额的单源常量名、旧判定的函数名与注入旋钮名
# （把 §27-d 原样塞回门禁就命中）、预算/份额的比较形态、以及测量夹具的点名。
#
# 注意：本文件**不是**被 grep 的对象（守卫自己要写这些字面量），被检查的只有上面三个文件。
# 守卫自己也不判时长、不读环境 —— 跑机核数/负载与它无关。
set -uo pipefail

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
smoke="$here/smoke.sh"
knobs="$here/panel-knobs.sh"
perf="$here/perf.sh"

FAILED=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'bad: %s\n' "$1"; FAILED=$((FAILED + 1)); }

# 标记（封闭集合）
MARK_RE='PERF_FRAME_BUDGET_MS|PERF_CPU_MAX_PCT|PERF_ASSEMBLY_PREMISE_FACTOR|PERF_FIRST_FRAME_PREMISE_FACTOR|PERF_CPU_PREMISE_FACTOR|p27_assembly|TEAM_SMOKE_FRAME_DELAY_MS|TEAM_SMOKE_LOADAVG|TEAM_SMOKE_CORES'
# 时长/份额比较的形态（帧预算、秒数；把 [ "$med" -le 2000 ] 这类判定塞回来就命中）
MARK_CMP_RE='(-le|-lt|-ge|-gt)[[:space:]]+2000|(>=|<=|>|<)[[:space:]]*2000[^0-9]'
# 测量夹具的点名（门禁自己不许调用它们；面板夹具只在 premise-only 模式下经 panel-knobs.sh 被用到）
FIX_RE='panel-cpu\.sh|panel-cpu-premise\.sh|perf\.sh'

need_file() { [ -f "$1" ] || bad "缺文件 $1"; }

# ① 门禁本体
if [ -f "$smoke" ]; then
  hits="$(grep -nE -- "$MARK_RE" "$smoke" || true)"
  cmps="$(grep -nE -- "$MARK_CMP_RE" "$smoke" || true)"
  fixes="$(grep -nE -- "$FIX_RE" "$smoke" || true)"
  if [ -z "$hits$cmps$fixes" ]; then
    ok "smoke.sh 里没有性能判定标记、时长/份额比较，也没有测量夹具的点名"
  else
    bad "smoke.sh 里出现了性能判定标记 / 比较 / 测量夹具点名（$(printf '%s\n%s\n%s\n' "$hits" "$cmps" "$fixes" | grep -v '^$' | head -3 | tr '\n' ';')）"
  fi
  # 门禁还得真的调用守卫与旋钮助手（否则守卫被摘掉也没人知道）
  for need in 'gate-guard\.sh' 'panel-knobs\.sh'; do
    grep -qE -- "$need" "$smoke" || bad "smoke.sh 没有调用 $need（守卫/旋钮完整性被摘掉了）"
  done
else
  bad "缺 $smoke"
fi

# ② 旋钮完整性助手
if [ -f "$knobs" ]; then
  if grep -qF 'TEAM_PANEL_CPU_PREMISE_ONLY=1' "$knobs"; then
    ok "panel-knobs.sh 存在且走 panel-cpu.sh 的 premise-only 模式"
  else
    bad "panel-knobs.sh 丢了 premise-only 调用（TEAM_PANEL_CPU_PREMISE_ONLY=1）"
  fi
  grep -qE 'panel-cpu-premise\.sh' "$knobs" \
    && bad "panel-knobs.sh 反过来驱赶测量夹具 panel-cpu-premise.sh（门禁又被测量绑上了）" \
    || ok "panel-knobs.sh 不驱赶测量夹具"
else
  bad "缺 $knobs（旋钮不得漏进真路径的检查没了）"
fi

# ③ 性能套件
if [ -f "$perf" ]; then
  PERF_MARKERS_OK=1
  for pair in 'PERF_FRAME_BUDGET_MS=2000' 'PERF_CPU_MAX_PCT=1' 'PERF_ASSEMBLY_PREMISE_FACTOR=0.75' \
              'PERF_FIRST_FRAME_PREMISE_FACTOR=0.25' 'PERF_CPU_PREMISE_FACTOR=0.25'; do
    grep -qF -- "$pair" "$perf" || { bad "perf.sh 没有带着标记 $pair（判定被删掉了？）"; PERF_MARKERS_OK=0; }
  done
  # ok 只在**全部**标记都在时打印 —— 缺任何一个都只说 bad（PM 复验 F1：bad 与「带着标记」的 ok
  # 并排是最伤信任的自相矛盾；判定 rc 一直是对的，错的是自述）。
  [ "$PERF_MARKERS_OK" = "1" ] && ok "perf.sh 带着帧预算 / CPU 份额 / 前提系数的命名单源标记"
else
  bad "缺 $perf"
fi

# ④ 计时记录不是判决（P70 / D33 的边界）：门禁里唯一可以把「测到的时长」和阈值比的模块是
#    lib/section-guard.sh（每段硬预算 = 存活检测）。标记是**比较形态**（$elapsed / $SECONDS… 与
#    -gt/-ge/-lt/-le 相邻），不是变量名本身 —— 别的模块打印时长、把时长当数据搬运都不算判定。
DUR_MOD="$here/lib/section-guard.sh"
DUR_CMP_RE='(\$elapsed|\$\{elapsed\}|\$duration|\$took|\$SECONDS)[^|;]*-(gt|ge|lt|le)([^0-9A-Za-z_]|$)'
DUR_HITS=""
for f in "$smoke" "$here"/lib/*.sh; do
  [ -f "$f" ] || continue
  [ "$f" = "$DUR_MOD" ] && continue
  h="$(grep -nE -- "$DUR_CMP_RE" "$f" 2>/dev/null | head -3 || true)"
  [ -n "$h" ] && DUR_HITS="$DUR_HITS$f: $h; "
done
if [ -z "$DUR_HITS" ]; then
  ok "门禁的时长只被记录、不被判定（lib/section-guard.sh 之外没有时长阈值比较）"
else
  bad "门禁里出现了时长阈值比较（计时记录成了判决）：$DUR_HITS"
fi
if [ -f "$DUR_MOD" ]; then
  grep -qE -- '-(ge|gt)[[:space:]]+"\$budget"' "$DUR_MOD" \
    && ok "lib/section-guard.sh 是唯一做时长比较的模块（trip 比较在位）" \
    || bad "lib/section-guard.sh 丢了 trip 比较（-ge \"\$budget\"）—— 单源边界没了"
else
  bad "缺 $DUR_MOD（每段硬预算的看门狗模块）"
fi

if [ "$FAILED" -eq 0 ]; then
  printf '\ngate-guard: 四向都过（门禁无判定、旋钮助手在岗、性能套件带标记、时长比较只在段落守卫）\n'
  exit 0
fi
printf '\ngate-guard: %d 条不成立\n' "$FAILED"
exit 1
