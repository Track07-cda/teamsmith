#!/usr/bin/env bash
# coverage-inventory.sh — 断言覆盖清单与两向比对（change: product-checkout-gate · verification#A gate that cannot judge says so）
#
# 用法：
#   coverage-inventory.sh --static <仓库根>        # 源码调用点清单（读 smoke.sh → C/L 行）
#   coverage-inventory.sh --runtime <门禁日志>     # 一次运行的执行清单（读日志 → R 行）
#   coverage-inventory.sh --compare <基线> <现行>  # 0 = 现行覆盖不少于基线；1 = 逐条点名缺项
#
# 清单格式（TSV；`#` 行是注释）：
#   C<TAB><段key><TAB>assert=<n><TAB>skip=<n>      # 源码里该段的断言调用点 / 跳过调用点计数
#   L<TAB><段key><TAB>assert<TAB><标签>            # 源码里该段的断言调用标签（逐字）
#   R<TAB><段key><TAB>pass=<n><TAB>fail=<n>        # 日志里该段实际执行的 ✓/✗
#
# 比对规则（方向永远保守）：
#   * 基线里的每条**断言标签**都要在现行的断言调用点里还在（同段）；
#   * 基线里每段的断言调用点计数不得下降（「旧断言被换成一次跳过」即使别处补了新断言也会被点名）；
#   * 基线里每段实际执行的通过数不得下降。
#   新增断言、新增段、新增跳过一律允许 —— 这是覆盖守卫，不是「不许改代码」。
#
# 为什么要有静态一口径：运行时只看得见「执行了什么」，看不见「有没有被换成跳过却由新断言补齐总数」；
# 为什么要有运行时一口径：静态只看得见调用点，看不见它在这次运行里到底跑没跑。
set -uo pipefail

MODE=""
ROOT=""
LOG=""
BASE=""
CUR=""

die() { printf 'coverage-inventory: %s\n' "$*" >&2; exit 2; }
usage() { sed -n '2,26p' "$0"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --static)  [ -z "$MODE" ] || die "--static 与 --$MODE 不同用"; MODE=static; shift
               [ $# -gt 0 ] || die "--static 需要仓库根"; ROOT="$1"; shift ;;
    --runtime) [ -z "$MODE" ] || die "--runtime 与 --$MODE 不同用"; MODE=runtime; shift
               [ $# -gt 0 ] || die "--runtime 需要日志"; LOG="$1"; shift ;;
    --compare) [ -z "$MODE" ] || die "--compare 与 --$MODE 不同用"; MODE=compare; shift
               [ $# -ge 2 ] || die "--compare 需要 <基线> <现行>"; BASE="$1"; CUR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "未知参数 $1（用法见 --help）" ;;
  esac
done
[ -n "$MODE" ] || { usage >&2; exit 2; }

# ── 静态：源码调用点 ─────────────────────────────────────────────────────────────────────
# 段边界与选段器同口径（`section "<id>"` 行，key = id 里第一个 " · " 之前）。
# 标签取法：断言/跳过函数各自的「标签参数」位置（按项目里的调用惯例，标签是带引号的字面量）。
# 解析不动的行（少参数 / 参数是拼接表达式）不产出 L 条目（调用点计数照收）—— 含 `$`/反引号的计算型标签
# 同样不进 L 清单（它逐字可变，不是「旧断言还在不在」的凭据）；只会让守卫更弱，不会假红。
ci_label_first() { # <行> <函数名> → CI_LABEL
  local re="(^|[^A-Za-z0-9_])${2}[[:space:]]+\"([^\"]*)\""
  [[ $1 =~ $re ]] || return 1
  CI_LABEL="${BASH_REMATCH[2]}"
}
ci_label_second() { # <行> <函数名> → CI_LABEL（第 2 个参数是标签）
  local re="(^|[^A-Za-z0-9_])${2}[[:space:]]+(\"[^\"]*\"|'[^']*'|[^[:space:]]+)[[:space:]]+\"([^\"]*)\""
  [[ $1 =~ $re ]] || return 1
  CI_LABEL="${BASH_REMATCH[3]}"
}
ci_label_third() { # <行> <函数名> → CI_LABEL（第 3 个参数是标签）
  local re="(^|[^A-Za-z0-9_])${2}[[:space:]]+(\"[^\"]*\"|'[^']*'|[^[:space:]]+)[[:space:]]+(\"[^\"]*\"|'[^']*'|[^[:space:]]+)[[:space:]]+\"([^\"]*)\""
  [[ $1 =~ $re ]] || return 1
  CI_LABEL="${BASH_REMATCH[4]}"
}
# 计算型标签（含 $ 或反引号）不进 L 清单：它在源码里逐字可变（P148 的 §36① 就把 `$(sed …)` 换成了
# `$P148_CK_SUM`），拿它当「旧断言还在不在」的凭据只会假红。调用点计数照收。
_ci_emittable() { case "$1" in *'$'*|*'`'*) return 1 ;; *) return 0 ;; esac; }

do_static() {
  local smoke="$ROOT/skills/teamsmith/tests/smoke.sh" line cur="" id re
  [ -r "$smoke" ] || die "读不到 $smoke"
  printf '# coverage inventory — static — source=skills/teamsmith/tests/smoke.sh\n'
  local -a C_KEYS=() A_LBL=() S_LBL=()
  local -a A_CNT=() S_CNT=()
  local -A A_IDX=() S_IDX=()
  local n=0
  while IFS= read -r line || [ -n "$line" ]; do
    re='^[[:space:]]*section[[:space:]]+"([^"]+)"'
    if [[ $line =~ $re ]]; then
      id="${BASH_REMATCH[1]}"; cur="${id%% · *}"
      if [ -z "${A_IDX[$cur]+x}" ]; then
        A_IDX[$cur]="$n"; S_IDX[$cur]="$n"; C_KEYS+=("$cur"); A_CNT+=("0"); S_CNT+=("0"); n=$((n + 1))
      fi
      continue
    fi
    [ -n "$cur" ] || continue
    local i="${A_IDX[$cur]}"
    if ci_label_first "$line" ok || ci_label_first "$line" bad || ci_label_first "$line" assert_eq; then
      A_CNT[i]=$((A_CNT[i] + 1)); _ci_emittable "$CI_LABEL" && A_LBL+=("$cur"$'\t'"$CI_LABEL")
    elif ci_label_second "$line" assert_file || ci_label_second "$line" assert_dir || ci_label_second "$line" assert_not_file; then
      A_CNT[i]=$((A_CNT[i] + 1)); _ci_emittable "$CI_LABEL" && A_LBL+=("$cur"$'\t'"$CI_LABEL")
    elif ci_label_third "$line" assert_has || ci_label_third "$line" assert_match || ci_label_third "$line" assert_not \
      || ci_label_third "$line" assert_has_echo || ci_label_third "$line" assert_not_echo; then
      A_CNT[i]=$((A_CNT[i] + 1)); _ci_emittable "$CI_LABEL" && A_LBL+=("$cur"$'\t'"$CI_LABEL")
    elif ci_label_first "$line" cond_skip || ci_label_first "$line" prereq_skip || ci_label_first "$line" fast_skip; then
      S_CNT[i]=$((S_CNT[i] + 1)); _ci_emittable "$CI_LABEL" && S_LBL+=("$cur"$'\t'"$CI_LABEL")
    fi
  done < "$smoke"
  local k
  for k in "${A_LBL[@]}"; do printf 'L\t%s\tassert\t%s\n' "${k%%$'\t'*}" "${k#*$'\t'}"; done
  for k in "${S_LBL[@]}"; do printf 'L\t%s\tskip\t%s\n' "${k%%$'\t'*}" "${k#*$'\t'}"; done
  local j
  for ((j = 0; j < n; j++)); do
    printf 'C\t%s\tassert=%d\tskip=%d\n' "${C_KEYS[j]}" "${A_CNT[j]}" "${S_CNT[j]}"
  done
}

# ── 运行时：一次门禁日志 ─────────────────────────────────────────────────────────────────
do_runtime() {
  [ -r "$LOG" ] || die "读不到日志 $LOG"
  printf '# coverage inventory — runtime — source=%s\n' "$LOG"
  sed 's/\x1b\[[0-9;]*m//g' "$LOG" | awk '
    /^== #[0-9]+ / {
      id = $0
      sub(/^== #[0-9]+ /, "", id)
      sub(/ ==.*$/, "", id)
      sub(/ · .*$/, "", id)
      cur = id
      if (!(cur in seen)) { seen[cur] = 1; order[++n] = cur }
      next
    }
    cur == "" { next }
    /^  ✓ / { pass[cur]++ ; next }
    /^  ✗ / { fail[cur]++ ; next }
    END {
      for (i = 1; i <= n; i++) { k = order[i]; printf "R\t%s\tpass=%d\tfail=%d\n", k, pass[k]+0, fail[k]+0 }
      exit 0
    }
  ' | sort -t$'\t' -k2,2
}

# ── 比对 ────────────────────────────────────────────────────────────────────────────────
do_compare() {
  [ -r "$BASE" ] || die "读不到基线清单 $BASE"
  [ -r "$CUR" ]  || die "读不到现行清单 $CUR"
  awk -F'\t' '
    function bad(msg) { printf "bad: %s\n", msg; badn++ }
    FNR == NR {
      if ($1 == "C") { split($3, a, "="); curA[$2] = a[2] + 0; next }
      if ($1 == "L" && $3 == "assert") { curL[$2 SUBSEP $4] = 1; next }
      if ($1 == "R") { split($3, a, "="); curR[$2] = a[2] + 0; next }
      next
    }
    $1 == "C" {
      split($3, a, "="); want = a[2] + 0
      if (!($2 in curA)) { bad("段 " $2 " 的整体断言调用点计数：基线 " want "，现行整段缺失"); }
      else if (curA[$2] < want) { bad("段 " $2 " 的断言调用点计数下降：基线 " want "，现行 " curA[$2]); }
      else okn++
      next
    }
    $1 == "L" && $3 == "assert" {
      if (($2 SUBSEP $4) in curL) okn++
      else bad("段 " $2 " 的断言标签不在现行的断言调用里了：" $4)
      next
    }
    $1 == "R" {
      split($3, a, "="); want = a[2] + 0
      if (!($2 in curR)) { bad("段 " $2 " 在现行运行里没有执行清单：基线通过 " want); }
      else if (curR[$2] < want) { bad("段 " $2 " 的通过数下降：基线 " want "，现行 " curR[$2]); }
      else okn++
      next
    }
    END { printf "== 覆盖清单比对 == ok %d bad %d\n", okn + 0, badn + 0; exit (badn > 0) ? 1 : 0 }
  ' "$CUR" "$BASE"
}

case "$MODE" in
  static)  do_static ;;
  runtime) do_runtime ;;
  compare) do_compare ;;
esac
