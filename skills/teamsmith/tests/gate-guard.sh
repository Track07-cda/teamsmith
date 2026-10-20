#!/usr/bin/env bash
# P316 · 正确性门禁 / 参考读数 的双向机械守卫（纯逻辑：只 grep 文件，不起任何进程、不判时长）
#
#   bash skills/teamsmith/tests/gate-guard.sh
#
# 用户裁定（2026-10-19，第二条）：**门禁的绿/红只由行为决定；时间只说给人听**。
# 三条机械边界（任一不成立 → 打印 `bad: …` 并退出 1）：
#   ① 门禁面（`smoke.sh` + `tests/lib/*.sh`）里没有**这一种**墙钟判据：`$elapsed/$duration/$took/$SECONDS`
#      与 `-gt/-ge/-lt/-le` 相邻的阈值比较。**它只证明这一种写法不在**，不证明「门禁里没有任何墙钟判据」
#      —— 参数形态（例如等待函数第 N 个参数是秒数）它看不见，那要靠调用点的单点实验。
#   ② 门禁不点名测量夹具（`perf.sh` / `panel-cpu.sh` / 已退役的 `load-experiment.sh`、`panel-cpu-premise.sh`）
#      —— 性能读数留在门禁之外，这一条编码的是用户裁定的**结构**。
#   ③ 两个参考打印器没有**判定型退出码**（`exit 2` / `exit 4`）：读不到就走 3/0，不能因为「慢」或
#      「机器忙」而失败。这是行为性质，不是措辞。
#
# 已删除（P316 返修 · V61 裁定）：原来的 ④「门禁真的调用本守卫」是自指检查，没有行为证据价值；
# 以及 ③ 里「必须带 `· 参考` 标记」那一半 —— 那是呈现契约，不是「不阻塞」的证据（「不阻塞」的证据是
# perf.sh 在 4065ms 首帧上 rc=0、CI 的 continue-on-error、panel-cpu 无工具时 exit 0）。
#
# 注意：本文件**不是**被 grep 的对象（守卫自己要写这些字面量），被检查的是上面两个面。
set -uo pipefail

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
smoke="$here/smoke.sh"
perf="$here/perf.sh"
pcpu="$here/panel-cpu.sh"

FAILED=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'bad: %s\n' "$1"; FAILED=$((FAILED + 1)); }

# ① 时长阈值比较（与旧 D33 的形态一致：变量名 + 比较符相邻；打印时长不算）
DUR_CMP_RE='(\$elapsed|\$\{elapsed\}|\$duration|\$took|\$SECONDS)[^|;]*-(gt|ge|lt|le)([^0-9A-Za-z_]|$)'
DUR_HITS=""
DUR_MOD="$here/lib/section-guard.sh"
for f in "$smoke" "$here"/lib/*.sh; do
  [ -f "$f" ] || continue
  # 段落守卫是挂住上限的唯一实现：它把 now-armed 与常量 cap 比较（防死等），另有两处纯记账
  # （秒数归零 / 取最大值）。它不是墙钟判据，单独下面一条钉住「cap 比较仍在」。
  [ "$f" = "$DUR_MOD" ] && continue
  # 注释行不算比较（本守卫自己的说明、「不要写成 X 与 -gt 相邻」这类提示都写在注释里）。
  h="$(grep -nE -- "$DUR_CMP_RE" "$f" 2>/dev/null | grep -vE '^[0-9]+:[[:space:]]*#' | head -3 || true)"
  [ -n "$h" ] && DUR_HITS="$DUR_HITS$(basename "$f"): $h; "
done
if [ -f "$DUR_MOD" ] && grep -qE -- '-(ge|gt)[[:space:]]+"\$cap"' "$DUR_MOD"; then
  ok "lib/section-guard.sh 只把时长与常量挂住上限比较（防死等）"
elif [ -f "$DUR_MOD" ]; then
  bad "lib/section-guard.sh 丢了挂住上限比较（-ge \"\$cap\"）—— 防死等没了"
fi
if [ -z "$DUR_HITS" ]; then
  ok "门禁面（smoke.sh + lib/*.sh）没有「\$elapsed 与 -gt/-ge/-lt/-le 相邻」的阈值比较"
else
  bad "门禁面里出现了这一种墙钟阈值比较（时间成了判决）：$DUR_HITS"
fi

# ② 门禁不点名测量夹具（它们只在参考读数路径里被调用）
FIX_RE='panel-cpu\.sh|panel-cpu-premise\.sh|perf\.sh|load-experiment\.sh'
if [ -f "$smoke" ]; then
  fixes="$(grep -nE -- "$FIX_RE" "$smoke" || true)"
  if [ -z "$fixes" ]; then
    ok "smoke.sh 不点名测量/参考夹具（性能读数不在正确性门禁里跑）"
  else
    bad "smoke.sh 点名了测量/参考夹具：$(printf '%s' "$fixes" | head -3 | tr '\n' ';')"
  fi
else
  bad "缺 $smoke"
fi

# ③ 参考打印器：在、没有判定型退出码
for f in "$perf" "$pcpu"; do
  if [ ! -f "$f" ]; then bad "缺参考打印器 $(basename "$f")"; continue; fi
  verdicts="$(grep -nE '(^|[^0-9A-Za-z_])exit[[:space:]]+(2|4)([^0-9]|$)' "$f" || true)"
  if [ -z "$verdicts" ]; then
    ok "$(basename "$f") 没有判定型退出码（exit 2/4）：测不出来 ≠ 性能不合格"
  else
    bad "$(basename "$f") 还有判定型退出码：$(printf '%s' "$verdicts" | head -3 | tr '\n' ';')"
  fi
done

if [ "$FAILED" -eq 0 ]; then
  printf '\ngate-guard: 三向都过（这一种墙钟比较不在门禁面、门禁不点名测量夹具、参考打印器无 2/4 退出）\n'
  exit 0
fi
printf '\ngate-guard: %d 条不成立\n' "$FAILED"
exit 1
