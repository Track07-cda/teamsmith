#!/usr/bin/env bash
# M12 追加 · 26-c 容量行自抖的翻转夹具（红 → 绿）
#
#   bash skills/teamsmith/tests/flip-m12-26c.sh              # 放大注入下：旧 26-c 红 / 新 26-c 绿
#   bash skills/teamsmith/tests/flip-m12-26c.sh --measure 12  # 只测：当前树 26-c 连跑 N 次报失败率（不放大）
#   bash skills/teamsmith/tests/flip-m12-26c.sh --probe base  # 只跑一面（base 或 current），自然条件
#   TEAM_FLIP_BASE=<sha> bash …/flip-m12-26c.sh               # 自选基线（默认 merge-base HEAD main）
#
# 为什么需要：26-c 的两条断言把两次**实时执行**逐字对比（`--print` vs 重定向 `--once`；`--print` vs
# `UI=text --once`），而容量数据源默认是 /proc/meminfo 与 /proc/swaps —— 数值每秒都在动
# （实测 MemAvailable ±100MB/s；面板的 `可再加 N 个` = (avail + disk_free − 512) / 6144，在边界
# 附近两次采样就能差 1）。旧 26-c 因此偶发红，且报错把原因说成「没走纯文本路径（ESC=0）」——
# ESC 是 0，误导来源就在这里。
#
# 翻转手法：探针 = smoke 的前导 + 26 段到 26-c（单跑 ~4.3s）。「放大注入」= TEAM_AGENT_MEM_MB=1：
# 分母从 6144MB 变 1MB，把「每秒 ±MB 的漂移」放大成「可再加 必差 1」，于是
#   旧 26-c（读实时值）→ 两次采样必不同 → 红；
#   新 26-c（p10cap 钉住 meminfo+swaps 夹具）→ 两次都读夹具 → 绿。
# 注入不碰被测对象（产品代码与断言都不变），只是让时间窗口里的漂移可见。
#
# 边界：只读 git（`git show BASE:…smoke.sh`），只写 /tmp 下的临时目录；截出来的 smoke 段在 EXIT 时
# 自己收干净，不碰调用者所在的仓库/session。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { printf 'flip-m12-26c: 找不到 git 仓库\n' >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { printf 'flip-m12-26c: 需要 python3（截取探针）\n' >&2; exit 2; }

MODE="flip"; MEASURE_N=0; PROBE_WHICH=""
case "${1:-}" in
  --measure) MODE="measure"; MEASURE_N="${2:-0}" ;;
  --probe)   MODE="probe";   PROBE_WHICH="${2:-}"
             case "$PROBE_WHICH" in base|current) ;; *) printf 'flip-m12-26c --probe <base|current>\n' >&2; exit 2 ;; esac ;;
  ""|-h|--help)
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then sed -n '2,22p' "$0"; exit 0; fi ;;
  *) printf 'flip-m12-26c: 未知参数 %s\n' "$1" >&2; exit 2 ;;
esac

TMP="$(mktemp -d /tmp/teamsmith-flip-m12-26c.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

CUR_SMOKE="$SKILL_DIR/tests/smoke.sh"
[ -f "$CUR_SMOKE" ] || { printf 'flip-m12-26c: 找不到 %s\n' "$CUR_SMOKE" >&2; exit 2; }
BASE="${TEAM_FLIP_BASE:-}"
[ -n "$BASE" ] || BASE="$(git -C "$REPO_ROOT" merge-base HEAD main 2>/dev/null || true)"
[ -n "$BASE" ] || BASE="$(git -C "$REPO_ROOT" rev-parse --verify -q HEAD^ 2>/dev/null || true)"
[ -n "$BASE" ] || { printf 'flip-m12-26c: 解析不到修复前的 revision，用 TEAM_FLIP_BASE=<sha> 指定\n' >&2; exit 2; }
BASE_SMOKE="$TMP/smoke-base.sh"
git -C "$REPO_ROOT" show "$BASE:skills/teamsmith/tests/smoke.sh" > "$BASE_SMOKE" 2>/dev/null \
  || { printf 'flip-m12-26c: %s 里没有 smoke.sh\n' "$BASE" >&2; exit 2; }
if grep -q '^p10cap=(' "$BASE_SMOKE"; then
  printf 'flip-m12-26c: BASE（%s）已经含 26-c 的夹具钉（不是修复前的树）——用 TEAM_FLIP_BASE=<修复前的 sha>\n' "$BASE" >&2
  exit 2
fi
grep -q '^p10cap=(' "$CUR_SMOKE" || { printf 'flip-m12-26c: 当前树没含 26-c 的夹具钉\n' >&2; exit 2; }

# 探针 = 前导（helpers/夹具函数）+ 26 段到 26-c 之前；SKILL_DIR 指向当前树（产品代码）
build_probe() { # <src-smoke> <out>
  local src="$1" out="$2"
  {
    awk '/^# -+ 0\. 仓库/{exit} {print}' "$src"
    printf '\n# —— 26-c 聚焦探针 ——\n'
    awk '/^section "26 · 面板（pulse-tui-panel/{f=1} /^# -+ 26-d\. --json/{exit} f{print}' "$src"
  } | sed "s|^SKILL_DIR=.*|SKILL_DIR=\"$SKILL_DIR\"|" > "$out"
  cat >> "$out" <<'EOS'
section "15 · 完成（26-c 聚焦探针）"
printf '\n== 结果 ==  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0
exit 1
EOS
}

probe_run() { # <src-smoke> <tag> <amp:1|0> <log> → 退出码
  local src="$1" tag="$2" amp="$3" log="$4" p
  p="$TMP/probe-$tag.sh"
  build_probe "$src" "$p"
  if [ "$amp" = "1" ]; then
    TEAM_AGENT_MEM_MB=1 bash "$p" > "$log" 2>&1      # 放大：分母 6144MB → 1MB
  else
    bash "$p" > "$log" 2>&1
  fi
  return $?
}
reds() { grep -a '✗' "$1" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -v '== 结果 =='; }
result_line() { grep -a '== 结果 ==' "$1" 2>/dev/null | tail -1 | sed 's/\x1b\[[0-9;]*m//g'; }

if [ "$MODE" = "measure" ]; then
  [ "$MEASURE_N" -gt 0 ] || { printf 'flip-m12-26c --measure <次数>\n' >&2; exit 2; }
  printf 'M12-26c 测量：当前树 26-c（聚焦探针、不放大）连跑 %s 次\n' "$MEASURE_N"
  n=0; bad=0
  while [ "$n" -lt "$MEASURE_N" ]; do
    n=$((n + 1))
    if probe_run "$CUR_SMOKE" "m$n" 0 "$TMP/measure-$n.log"; then
      printf '  run %-3s 绿  %s\n' "$n" "$(result_line "$TMP/measure-$n.log")"
    else
      bad=$((bad + 1)); printf '  run %-3s 红  %s\n' "$n" "$(result_line "$TMP/measure-$n.log")"
      reds "$TMP/measure-$n.log" | sed 's/^/      /'
    fi
  done
  printf '失败率：%s/%s\n' "$bad" "$n"
  [ "$bad" -eq 0 ] || exit 1
  exit 0
fi

if [ "$MODE" = "probe" ]; then
  src="$BASE_SMOKE"; [ "$PROBE_WHICH" = "current" ] && src="$CUR_SMOKE"
  probe_run "$src" "$PROBE_WHICH" 0 "$TMP/probe-$PROBE_WHICH.log"; rc=$?
  printf '%s：rc=%s %s\n' "$PROBE_WHICH" "$rc" "$(result_line "$TMP/probe-$PROBE_WHICH.log")"
  reds "$TMP/probe-$PROBE_WHICH.log" | sed 's/^/    /'
  exit 0   # 诊断模式：红也当输出（自然条件下旧 26-c 本来就偶尔红）
fi

printf 'M12-26c 翻转：同一放大注入（TEAM_AGENT_MEM_MB=1）下，旧 26-c 必须红、新 26-c 必须绿\n'
printf '  BASE=%s\n  当前=%s\n' "$BASE" "$CUR_SMOKE"
FAILED=0
probe_run "$BASE_SMOKE" base 1 "$TMP/base.log"; brc=$?
probe_run "$CUR_SMOKE"  cur  1 "$TMP/cur.log";  crc=$?
printf '旧 26-c（BASE，实时读数）：rc=%s %s\n' "$brc" "$(result_line "$TMP/base.log")"
reds "$TMP/base.log" | sed 's/^/    /'
printf '新 26-c（当前，夹具钉住）：rc=%s %s\n' "$crc" "$(result_line "$TMP/cur.log")"
reds "$TMP/cur.log" | sed 's/^/    /'
[ "$brc" -ne 0 ] || { printf '✗ 翻转不成立：放大注入没能让旧 26-c 红\n'; FAILED=1; }
[ "$crc" -eq 0 ] || { printf '✗ 修复不成立：同一个注入让新 26-c 红了\n'; FAILED=1; }
[ "$FAILED" -eq 0 ] && printf '翻转成立：旧 26-c 红、新 26-c 绿\n' || exit 1
