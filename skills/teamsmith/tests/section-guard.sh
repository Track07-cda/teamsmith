#!/usr/bin/env bash
# section-guard.sh — 门禁每段预算/等待的**纯逻辑**检查（change: gate-section-accounting · 实现：P70）
#
#   bash skills/teamsmith/tests/section-guard.sh --budget-check [--tree <tests 目录>]
#   bash skills/teamsmith/tests/section-guard.sh --loop-check   [--tree <tests 目录>]
#
# 两个检查都不起进程、不碰 tmux、不判时长（D33 保持）；默认对脚本自己所在目录跑，
# `--tree` 给夹具在 scratch 副本上跑翻转用。
#
#   --budget-check：`smoke.sh` 里每个 `section "…"` 都在 `section-budgets.tsv` 里有行；
#     每行的 `budget_s >= max(ceil(band_s × factor), floor)`（factor=4、floor=60，写在表头里）、
#     `band_s == max(host_s, container_s, ci_s)`、provenance 非空；band 列至少有一个实测值。
#   --loop-check：`*/​*.sh` + `lib/*.sh` 里的每个 `while`+`sleep` 循环，按**文件内出现顺序**
#     与 `loop-inventory.tsv` 的行一一对应（锚点必须是 while 原文的子串；`cap=` 行还要求
#     循环体里能找到那个上限字面量）。新循环、丢上限、顺序变化都会点名 file:line 变红。
set -uo pipefail

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TREE="$here"
MODE=""
BACKUP_BUDGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --budget-check) MODE="budget"; shift ;;
    --loop-check)   MODE="loop"; shift ;;
    --tree)         TREE="${2:?--tree 需要目录}"; shift 2 ;;
    --tree=*)       TREE="${1#*=}"; shift ;;
    --backup-budget) BACKUP_BUDGET="${2:?--backup-budget 需要文件}"; shift 2 ;;
    -h|--help|"")   sed -n '2,16p' "$0"; exit 0 ;;
    *) printf 'section-guard.sh：不认识的参数 %s\n' "$1" >&2; exit 2 ;;
  esac
done
[ -n "$MODE" ] || { printf 'section-guard.sh：要 --budget-check 或 --loop-check\n' >&2; exit 2; }
[ -d "$TREE" ] || { printf 'section-guard.sh：目录不存在 %s\n' "$TREE" >&2; exit 2; }

FACTOR=4
FLOOR=60
FAIL=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'bad: %s\n' "$1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------- 预算检查
budget_check() {
  local table="$TREE/section-budgets.tsv" smoke="$TREE/smoke.sh"
  [ -f "$table" ] || { bad "缺预算表 $table"; return 1; }
  [ -f "$smoke" ] || { bad "缺门禁本体 $smoke"; return 1; }
  # 表头必须记录推导（系数/下限），否则检查用的数字与表自己写明的漂开也没人知道
  local head
  head="$(sed -n '1,12p' "$table")"
  case "$head" in
    *"factor=$FACTOR"*) ok "表头记录了 factor=$FACTOR" ;;
    *) bad "预算表头没有 factor=$FACTOR（推导必须写进文件）" ;;
  esac
  case "$head" in
    *"floor=$FLOOR"*) ok "表头记录了 floor=$FLOOR" ;;
    *) bad "预算表头没有 floor=$FLOOR（推导必须写进文件）" ;;
  esac
  # smoke.sh 里的每个 section id
  local ids id
  ids="$(grep -oE '^[[:space:]]*section "[^"]+"' "$smoke" | sed -e 's/^[[:space:]]*section "//' -e 's/"$//')"
  local n_ids=0 n_rows=0
  n_ids="$(printf '%s\n' "$ids" | grep -c . || true)"
  [ "$n_ids" -gt 0 ] || { bad "$smoke 里没找到 section 声明"; return 1; }
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    local row
    row="$(awk -F'\t' -v id="$id" '!/^[[:space:]]*#/ && $1 == id { print; found = 1; exit }' "$table")"
    if [ -z "$row" ]; then
      bad "预算表没有段落「$id」的行（每个 section 都要有行；未列出的新段落运行时用默认预算）"
      continue
    fi
    local band budget host hload ctr cload ci prov
    band="$(printf '%s' "$row" | cut -f2)"
    budget="$(printf '%s' "$row" | cut -f3)"
    host="$(printf '%s' "$row" | cut -f4)"; hload="$(printf '%s' "$row" | cut -f5)"
    ctr="$(printf '%s' "$row" | cut -f6)";  cload="$(printf '%s' "$row" | cut -f7)"
    ci="$(printf '%s' "$row" | cut -f8)"
    prov="$(printf '%s' "$row" | cut -f9)"
    local cols; cols="$(printf '%s' "$row" | awk -F'\t' '{print NF}')"
    [ "$cols" -eq 9 ] || { bad "段落「$id」的行有 $cols 列（要 9 列）"; continue; }
    case "$budget" in ''|*[!0-9]*) bad "段落「$id」的 budget_s=[$budget] 不是正整数"; continue ;; esac
    [ -n "$prov" ] || { bad "段落「$id」没有 provenance（修订/镜像/日期）"; continue; }
    # 三个 band 列至少一个是实测数字；band_s 必须等于它们的最大者
    local bnum max n
    bnum=0; max=0; n=0
    for bnum in "$host" "$ctr" "$ci"; do
      case "$bnum" in ''|-|*) case "$bnum" in ''|-) continue ;; esac ;; esac
      case "$bnum" in *[!0-9.]*) bad "段落「$id」的 band 列 [$bnum] 不是数字/-"; continue 2 ;; esac
      n=$((n + 1))
      awk -v a="$bnum" -v b="$max" 'BEGIN { exit !(a + 0 > b + 0) }' && max="$bnum"
    done
    [ "$n" -gt 0 ] || { bad "段落「$id」三个 band 列全是「-」：没有实测基础"; continue; }
    if ! awk -v a="$band" -v b="$max" 'BEGIN { exit !(a + 0 == b + 0) }'; then
      bad "段落「$id」band_s=$band ≠ max(host/container/ci)=$max（导出值与实测列不符）"
      continue
    fi
    local need
    need="$(awk -v b="$band" -v f="$FACTOR" -v fl="$FLOOR" 'BEGIN {
      x = b * f; y = int(x); if (x > y) y++;
      if (y < fl) y = fl;
      printf "%d", y
    }')"
    if [ "$budget" -lt "$need" ]; then
      bad "段落「$id」budget_s=$budget 低于 max(ceil(band×$FACTOR), $FLOOR)=$need（不许收到实测带以下）"
      continue
    fi
    n_rows=$((n_rows + 1))
  done <<<"$ids"
  # 重复 id（表里同一段两行会让查表结果不确定）
  local dups
  dups="$(awk -F'\t' '!/^[[:space:]]*#/ && NF { print $1 }' "$table" | sort | uniq -d)"
  [ -z "$dups" ] || bad "预算表有重复 id：$(printf '%s' "$dups" | tr '\n' ' ')"
  # 表里多出来的行（对应不上任何 section）只是提示，不算红
  local extra
  extra="$(awk -F'\t' '!/^[[:space:]]*#/ && NF { print $1 }' "$table" | sort | while IFS= read -r id; do
    printf '%s\n' "$ids" | grep -qxF -- "$id" || printf '%s\n' "$id"
  done | tr '\n' ' ')"
  [ -n "$extra" ] && printf 'note: 预算表里这些行对应不到 section（历史/新段落预留）：%s\n' "$extra"
  if [ "$n_rows" = "$n_ids" ]; then
    ok "预算表覆盖 $n_ids/$n_ids 个 section 且每行都满足 max(ceil(band×$FACTOR), $FLOOR)"
  else
    bad "预算表只通过了 $n_rows/$n_ids 个 section"
  fi
  return 0
}

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
      for (ff in inv_files) if (!(ff in det_files)) printf "note: 清单里的 %s 不在扫描面（过期行？）\n", ff
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
  budget) budget_check ;;
  loop)   loop_check ;;
esac

if [ "$FAIL" -eq 0 ]; then
  printf '\nsection-guard --%s-check: 全过\n' "$MODE"
  exit 0
fi
printf '\nsection-guard --%s-check: %d 条不成立\n' "$MODE" "$FAIL"
exit 1
