#!/usr/bin/env bash
# section-guard.sh — 门禁每段等待的**纯逻辑**检查（change: gate-section-accounting · 实现：P70；
# P316：每段不再有预算表，只保留「等待都有上限」的循环清单检查）
#
#   bash skills/teamsmith/tests/section-guard.sh --loop-check [--tree <tests 目录>]
#
# 检查不起进程、不碰 tmux、不判时长（D33 保持）；默认对脚本自己所在目录跑，
# `--tree` 给夹具在 scratch 副本上跑翻转用。
#
#   --loop-check：`*/​*.sh` + `lib/*.sh` 里的每个 `while`+`sleep` 循环，按**文件内出现顺序**
#     与 `loop-inventory.tsv` 的行一一对应（锚点必须是 while 原文的子串；`cap=` 行还要求
#     循环体里能找到那个上限字面量）。新循环、丢上限、顺序变化都会点名 file:line 变红。
#     清单里的文件不在扫描面（`--tree` 给的是一份缺文件的副本 / 文件被删 / 已经没有循环）也算
#     红 —— 否则「副本里看不见那个文件」就会静默地让清单与真树的不同步永远看不见（P313 · V58）。
set -uo pipefail

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TREE="$here"
MODE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --loop-check)   MODE="loop"; shift ;;
    --tree)         TREE="${2:?--tree 需要目录}"; shift 2 ;;
    --tree=*)       TREE="${1#*=}"; shift ;;
    -h|--help|"")   sed -n '2,14p' "$0"; exit 0 ;;
    *) printf 'section-guard.sh：不认识的参数 %s\n' "$1" >&2; exit 2 ;;
  esac
done
[ -n "$MODE" ] || { printf 'section-guard.sh：要 --loop-check\n' >&2; exit 2; }
[ -d "$TREE" ] || { printf 'section-guard.sh：目录不存在 %s\n' "$TREE" >&2; exit 2; }

FAIL=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'bad: %s\n' "$1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------- 循环清单检查
loop_check() {
  local inv="$TREE/loop-inventory.tsv" scan="$TREE/lib/loop-scan.awk"
  [ -f "$inv" ] || { bad "缺循环清单 $inv"; return 1; }
  [ -f "$scan" ] || { bad "缺循环探针 $scan"; return 1; }
  local det="$TREE/.loop-check.detected.$$"
  : > "$det"
  local f rel
  for f in "$TREE"/*.sh "$TREE"/lib/*.sh; do
    [ -f "$f" ] || continue
    rel="${f#$TREE/}"
    awk -v REL="$rel" -f "$scan" "$f" >> "$det" || true
  done
  # 逐文件按出现顺序配对：清单行序 = 源码里循环出现的顺序
  local out rc=0
  out="$(awk -v det="$det" -v inv="$inv" '
    function flush_file(   i, n, k, bounds, pattern) {
      fc = det_n[curfile] + 0
      ic = inv_n[curfile] + 0
      if (fc != ic) {
        printf "bad: %s 的 while+sleep 循环数 %d ≠ 清单行数 %d（新循环/漏登记/顺序变化都要点名并补清单）\n", curfile, fc, ic
        problems++
      }
      n = (fc < ic ? fc : ic)
      for (i = 1; i <= n; i++) {
        k = curfile SUBSEP i
        if (index(det_raw[k], inv_anchor[k]) == 0) {
          printf "bad: %s:%s 的 while 行与清单第 %d 行的锚点不符\n     源码：%s\n     清单：%s\n", \
            curfile, det_line[k], i, det_raw[k], inv_anchor[k]
          problems++
          continue
        }
        if (det_closed[k] != "closed") {
          printf "bad: %s:%s 的 while 循环没有配对的 done（unclosed）\n", curfile, det_line[k]
          problems++
          continue
        }
        bounds = inv_bound[k]
        if (bounds ~ /^cap=/) {
          pattern = substr(bounds, 5)
          if (index(det_ext[k], pattern) == 0) {
            printf "bad: %s:%s 的循环丢了上限（清单要求循环体里出现 [%s]）\n", curfile, det_line[k], pattern
            problems++
          }
        } else if (bounds !~ /^bound=/) {
          printf "bad: %s:%s 的清单行 bound 列既不是 cap= 也不是 bound=（[%s]）\n", curfile, det_line[k], bounds
          problems++
        }
      }
      if (fc > ic) {
        for (i = ic + 1; i <= fc; i++) {
          k = curfile SUBSEP i
          printf "bad: %s:%s 是未登记的 while+sleep 循环：%s\n", curfile, det_line[k], det_raw[k]
        }
        problems++
      }
      total_matched += n
    }
    BEGIN {
      while ((getline l < inv) > 0) {
        if (l ~ /^[[:space:]]*#/) continue
        nn = split(l, a, "\t")
        if (nn != 4) { printf "bad: 清单行不是 4 列：%s\n", l; problems++; continue }
        file = a[1]
        inv_n[file]++
        k = file SUBSEP inv_n[file]
        inv_line[k] = a[2]; inv_bound[k] = a[3]; inv_anchor[k] = a[4]
        inv_files[file] = 1
        total_inv++
      }
      while ((getline l < det) > 0) {
        nn = split(l, a, "\t")
        if (nn != 5) continue
        file = a[1]
        if (!(file in det_files)) order[++nf] = file
        det_n[file]++
        k = file SUBSEP det_n[file]
        det_line[k] = a[2]; det_raw[k] = a[3]; det_closed[k] = a[4]; det_ext[k] = a[5]
        det_files[file] = 1
        total_det++
      }
      for (i = 1; i <= nf; i++) { curfile = order[i]; flush_file() }
      for (ff in inv_files) if (!(ff in det_files)) {
        printf "bad: 清单里的 %s 不在扫描面（文件被删 / 没被拷进 --tree / 已经没有 while+sleep 循环）—— 过期行，或者这是一份看不见它的副本\n", ff
        problems++
      }
      printf "ok: 扫描 %d 行清单 / %d 个 while+sleep 循环，配平 %d 个\n", total_inv, total_det, total_matched
      exit(problems > 0 ? 1 : 0)
    }
  ' 2>&1)"
  rc=$?
  printf '%s\n' "$out"
  rm -f "$det"
  [ "$rc" -eq 0 ] || FAIL=$((FAIL + 1))
  return 0
}

case "$MODE" in
  loop) loop_check ;;
esac

if [ "$FAIL" -eq 0 ]; then
  printf '\nsection-guard --%s-check: 全过\n' "$MODE"
  exit 0
fi
printf '\nsection-guard --%s-check: %d 条不成立\n' "$MODE" "$FAIL"
exit 1
