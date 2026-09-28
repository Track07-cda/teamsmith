#!/usr/bin/env bash
# teamsmith · 选段选择器（change: gate-runtime-budget · verification#A changed-path list selects…）
#
#   section-select.sh --paths <路径>…            路径 → decision=FULL|NONE|RUN
#   section-select.sh --select <key>[,<key>…]   显式选段（+ 前导 + needs 闭包），可重复
#   section-select.sh --check                   自检映射表与门禁源码（表腐烂 / 段读了没声明的路径 → 红）
#   section-select.sh --list                    列出映射表（key<TAB>id<TAB>patterns<TAB>needs<TAB>basis）
#   section-select.sh --root <dir>              分析另一棵树（夹具用；默认本脚本所在的仓库）
#   section-select.sh --table <file> --check    换一张表跑自检（夹具旋钮：造表腐烂的现场）
#   section-select.sh --out <file>              把 decision=RUN 的过滤副本写进 <file>（写前 bash -n 校验）
#   section-select.sh --verify-copies           对每个段键生成副本并 bash -n（结构腐烂的守门扫描）
#
# 纯逻辑：不调 git、不起 tmux/pi/门禁进程；只读映射表与 smoke.sh（--verify-copies 只写临时副本）。
# 退出码：0 = 有决定 / 自检全绿；1 = --check 有不成立项 / --verify-copies 有副本不能解析；
#         2 = 用法错误、表畸形、未知 key、路径出界。
#
# 决定语义（保守方向永远是「多跑」）：
#   NONE = 给的路径全在豁免类（docs/*，团队账本）且没有行声明它 → 没有段需要跑
#   RUN  = 给的路径每条都被某些行声明 → 这些 key + 前导段 + needs 闭包，按源序
#   FULL = 至少一条路径没有任何行声明、也不在豁免类 → 跑全套（兜底不可绕过）
set -uo pipefail

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEL_DIR="$here"

ROOT=""
MODE=""
COPY_OUT=""
PATHS=()
SEL_KEYS=()
die() { printf 'section-select: %s\n' "$*" >&2; exit 2; }
usage() { sed -n '2,21p' "$0"; }

# ── 参数 ────────────────────────────────────────────────────────────────────────────────
while [ $# -gt 0 ]; do
  case "$1" in
    --paths)
      shift; [ $# -gt 0 ] || die "--paths 需要至少一条路径"
      [ -z "$MODE" ] || [ "$MODE" = "paths" ] || die "--paths 与 --$MODE 不同用"
      MODE="paths"
      while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do PATHS+=("$1"); shift; done ;;
    --select)
      shift; [ $# -gt 0 ] || die "--select 需要至少一个 key"
      [ -z "$MODE" ] || [ "$MODE" = "select" ] || die "--select 与 --$MODE 不同用"
      MODE="select"
      IFS=',' read -r -a _k <<<"$1"
      SEL_KEYS+=("${_k[@]}"); shift ;;
    --check)   [ -z "$MODE" ] || die "--check 不与 --paths/--select 同用"; MODE="check"; shift ;;
    --list)    [ -z "$MODE" ] || die "--list 不与 --paths/--select 同用"; MODE="list"; shift ;;
    --root)    shift; [ $# -gt 0 ] || die "--root 需要目录"; ROOT="$1"; shift ;;
    --root=*)  ROOT="${1#*=}"; shift ;;
    --table)   shift; [ $# -gt 0 ] || die "--table 需要文件"; TABLE="$1"; shift ;;
    --table=*) TABLE="${1#*=}"; shift ;;
    --out)     shift; [ $# -gt 0 ] || die "--out 需要文件"; COPY_OUT="$1"; shift ;;
    --out=*)   COPY_OUT="${1#*=}"; shift ;;
    --verify-copies) [ -z "$MODE" ] || die "--verify-copies 不与其它模式同用"; MODE="verify-copies"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "未知参数 $1（用法见 --help）" ;;
  esac
done
[ -n "$MODE" ] || { usage >&2; exit 2; }
if [ -n "$COPY_OUT" ]; then
  case "$MODE" in
    paths|select) ;;
    *) die "--out 只与 --paths/--select 同用（当前是 --$MODE）" ;;
  esac
fi

if [ -z "$ROOT" ]; then
  ROOT="${TEAM_SECTION_SELECT_ROOT:-$(cd -P "$SEL_DIR/../../.." && pwd)}"
else
  ROOT="$(cd -P "$ROOT" 2>/dev/null && pwd)" || die "--root 目录不存在：$ROOT"
fi
TSV="$ROOT/skills/teamsmith/tests/section-paths.tsv"
SUITE="$ROOT/skills/teamsmith/tests/smoke.sh"
# 夹具旋钮：换一张表来跑 --check（只有夹具用；语义/格式一模一样，真路径仍是 $ROOT）
[ -z "${TABLE:-}" ] || TSV="$TABLE"

# ── 映射表（唯一声明处）──────────────────────────────────────────────────────────────────
# columns = key / id / patterns / needs / basis
#   patterns：仓库根相对路径的 case glob，空格分隔；`*` **跨 / **（bash case 语义）。
#             例：`skills/teamsmith/tests/*` 覆盖它下面任意深度；`-` = 没有声明。
#   needs   ：必须先跑的段 key（逗号分隔）；`-` = 无。选段时它们连同自己的 needs 一起进闭包。
P_EXEMPT=""
P_PROLOGUE=""
T_N=0
T_KEY=(); T_ID=(); T_PAT=(); T_NEEDS=(); T_BASIS=()

load_table() {
  [ -r "$TSV" ] || die "读不到映射表 $TSV"
  local line nf
  T_N=0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "# exempt:"*)   P_EXEMPT="${line#\# exempt:}"; P_EXEMPT="${P_EXEMPT# }"; P_EXEMPT="${P_EXEMPT% }"; continue ;;
      "# prologue:"*) P_PROLOGUE="${line#\# prologue:}"; P_PROLOGUE="${P_PROLOGUE# }"; P_PROLOGUE="${P_PROLOGUE% }"; continue ;;
      "#"*|"") continue ;;
    esac
    IFS=$'\t' read -r -a F <<<"$line"
    nf="${#F[@]}"
    [ "$nf" -eq 5 ] || die "映射表行不是 5 列（$(printf '%.60s' "$line")）"
    [ -n "${F[0]}" ] && [ -n "${F[1]}" ] && [ -n "${F[2]}" ] && [ -n "${F[3]}" ] && [ -n "${F[4]}" ] \
      || die "映射表行有空列（$(printf '%.60s' "$line")）"
    T_KEY+=("${F[0]}"); T_ID+=("${F[1]}"); T_PAT+=("${F[2]}"); T_NEEDS+=("${F[3]}"); T_BASIS+=("${F[4]}")
    T_N=$((T_N + 1))
  done < "$TSV"
  [ "$T_N" -gt 0 ] || die "映射表是空的：$TSV"
  [ -n "$P_EXEMPT" ] || die "映射表缺 exempt 头（豁免类声明）"
  [ -n "$P_PROLOGUE" ] || die "映射表缺 prologue 头（前导段声明）"
}

# ── 门禁源码里的段（顺序 = 源序）──────────────────────────────────────────────────────────
S_N=0
S_KEY=(); S_ID=(); S_LINE=()
load_suite() {
  [ -r "$SUITE" ] || die "读不到门禁源码 $SUITE"
  local line n=0 id k
  S_N=0
  while IFS= read -r line; do
    n=$((n + 1))
    case "$line" in
      *'section "'*)
        if [[ $line =~ ^[[:space:]]*section[[:space:]]+\"([^\"]+)\" ]]; then
          id="${BASH_REMATCH[1]}"; k="${id%% · *}"
          S_KEY+=("$k"); S_ID+=("$id"); S_LINE+=("$n"); S_N=$((S_N + 1))
        fi ;;
    esac
  done < "$SUITE"
  [ "$S_N" -gt 0 ] || die "门禁源码里一个 section 都没解析到：$SUITE"
}

# <key> → 源码行号（找不到 → 返回 1）
sec_line() {
  local k="$1" i
  for ((i = 0; i < S_N; i++)); do [ "${S_KEY[i]}" = "$k" ] && { printf '%s' "${S_LINE[i]}"; return 0; }; done
  return 1
}
# <key> → 行下标（找不到 → 返回 1）
row_idx() {
  local k="$1" i
  for ((i = 0; i < T_N; i++)); do [ "${T_KEY[i]}" = "$k" ] && { printf '%s' "$i"; return 0; }; done
  return 1
}
sec_id() {
  local k="$1" i
  for ((i = 0; i < S_N; i++)); do [ "${S_KEY[i]}" = "$k" ] && { printf '%s' "${S_ID[i]}"; return 0; }; done
  return 1
}

# 唯一的 matcher：<pattern> <path>；case glob，`*` 跨 `/`（保守方向 = 多选）
pat_match() {
  local pat="$1" p="$2"
  [ -n "$pat" ] || return 1
  case "$p" in $pat) return 0 ;; esac
  return 1
}
# 路径规范化：拒绝绝对路径 / `..` / `~`；去掉 `./` 前缀。结果放 NORM_P。
normalize_path() {
  local p="$1"
  case "$p" in ""|/*|~*|*//*) return 1 ;; esac
  while :; do case "$p" in ./*) p="${p#./}" ;; *) break ;; esac; done
  case "$p" in ""|..|../*|*/..|*/../*) return 1 ;; esac
  NORM_P="$p"
  return 0
}

# ── 段结构：分区与耦合组 ────────────────────────────────────────────────────────────────
# 段与段之间不总是能一刀切：构造（if/case/函数/heredoc…）可以跨段头（现场：smoke.sh 的 14c 坐在
# 14 段里的 FAST 守卫内）。这里不自己写 bash 解析器，而是让 bash 自己当裁判：一段源码文本能
# `bash -n` 通过 ⇔ 它自足（开与闭都在段内）。规则：
#   * 候选区域 = [段头, 下一个段头)；前导 = [1, 第一个段头)；收尾 = [`# __SMOKE_TAIL__`, EOF)；
#   * 前导 / 收尾不自足 → 无论怎么切都不安全：直接 die（早、响亮、可诊断）；
#   * 区域不自足 → 向右合并到能解析为止；合并出的**组**是不可拆的最小运行单元；
#   * 组是原子：选择任一成员 = 整组进运行集（run 清单如实列出全部成员），不选 = 整组不跑。
# 生成副本后再 `bash -n` 一次（emit_copy）：「副本必须永远可解析」的最后一闸。
G_N=0; G_START=(); G_END=(); G_KEYS=()
KEY_GIDX=()      # 段序号（源序）→ 组号
TAIL_LINE=""; LAST_LINE=""; groups_ready=0

key_idxs() { # <key> → 段序号（源序）；找不到 → 1
  local k="$1" i
  for ((i = 0; i < S_N; i++)); do [ "${S_KEY[i]}" = "$k" ] && { printf '%s' "$i"; return 0; }; done
  return 1
}
key_group() { # <key> → 组号；找不到 → 1
  local i
  i="$(key_idxs "$1")" || return 1
  printf '%s' "${KEY_GIDX[i]}"
}
span_parses() { # <起行> <止行（含）>；空区间 = 通过（bash -n 是结构裁判）
  local a="$1" b="$2"
  [ "$a" -le "$b" ] || return 0
  sed -n "${a},${b}p" "$SUITE" | bash -n 2>/dev/null
}
sec_region_end() { # <段序号> → 该段候选区域的止行（含）
  local i="$1" t="$TAIL_LINE"
  if [ "$i" -lt "$((S_N - 1))" ]; then printf '%s' "$((S_LINE[i + 1] - 1))"
  elif [ "$t" -gt 0 ]; then printf '%s' "$((t - 1))"
  else printf '%s' "$LAST_LINE"; fi
}
build_groups() { # 幂等；前导/收尾或任何切点无法自足 = die（无法安全切段）
  [ "$groups_ready" = 1 ] && return 0
  TAIL_LINE="$(grep -n '^# __SMOKE_TAIL__' "$SUITE" 2>/dev/null | head -1 | cut -d: -f1)"
  TAIL_LINE="${TAIL_LINE:-0}"
  LAST_LINE="$(wc -l < "$SUITE" | tr -d '[:space:]')"
  G_N=0; G_START=(); G_END=(); G_KEYS=(); KEY_GIDX=()
  if ! span_parses 1 "$((S_LINE[0] - 1))"; then
    die "前导段（源码 1..$((S_LINE[0] - 1))）按 bash -n 不自足：无法安全切段"
  fi
  if [ "$TAIL_LINE" -gt 0 ] && ! span_parses "$TAIL_LINE" "$LAST_LINE"; then
    die "收尾段（源码 $TAIL_LINE..$LAST_LINE）按 bash -n 不自足：无法安全切段"
  fi
  local i=0 j a b g k
  while [ "$i" -lt "$S_N" ]; do
    a="${S_LINE[i]}"; j="$i"; b="$(sec_region_end "$j")"
    while ! span_parses "$a" "$b"; do
      if [ "$j" -lt "$((S_N - 1))" ]; then
        j=$((j + 1)); b="$(sec_region_end "$j")"
      else
        die "段 ${S_KEY[i]}（源码行 $a）起的候选区域按 bash -n 不自足且已到末尾：无法切割"
      fi
    done
    g="$G_N"; G_N=$((G_N + 1))
    G_START+=("$a"); G_END+=("$b"); G_KEYS+=("")
    for ((k = i; k <= j; k++)); do
      G_KEYS[g]="${G_KEYS[g]}${G_KEYS[g]:+ }${S_KEY[k]}"
      KEY_GIDX[k]="$g"
    done
    i=$((j + 1))
  done
  groups_ready=1
  return 0
}

# ── 选段内核 ────────────────────────────────────────────────────────────────────────────
RUN_KEY=(); RUN_WHY=(); RUN_N=0
reset_run() { RUN_KEY=(); RUN_WHY=(); RUN_N=0; }
add_key() { # <key> <why>
  local k="$1" why="$2" i
  for ((i = 0; i < RUN_N; i++)); do
    if [ "${RUN_KEY[i]}" = "$k" ]; then
      case ", ${RUN_WHY[i]}," in *", $why,"*) ;; *) RUN_WHY[i]="${RUN_WHY[i]}, $why" ;; esac
      return 0
    fi
  done
  RUN_KEY+=("$k"); RUN_WHY+=("$why"); RUN_N=$((RUN_N + 1))
}
add_prologue() {
  local k
  for k in $P_PROLOGUE; do add_key "$k" "prologue"; done
}
add_needs_closure() { # 反复扫 needs 直到不再新增（needs 只指向更早的段 → 必然收敛）
  local i k j grew nd before pass=0 cap=$((T_N + 2))
  local NARR=()
  while [ "$pass" -lt "$cap" ]; do
    pass=$((pass + 1)); grew=0
    i=0
    while [ "$i" -lt "$RUN_N" ]; do
      k="${RUN_KEY[i]}"; i=$((i + 1))
      j="$(row_idx "$k" || true)"
      [ -n "$j" ] || continue
      [ "${T_NEEDS[j]}" = "-" ] && continue
      IFS=',' read -r -a NARR <<<"${T_NEEDS[j]}"
      for nd in "${NARR[@]}"; do
        [ -n "$nd" ] || continue
        before=$RUN_N
        add_key "$nd" "needs:$k"
        [ "$RUN_N" -ne "$before" ] && grew=1
      done
    done
    [ "$grew" = "0" ] && return 0
  done
  die "needs 闭包不收敛（表里有环？）"
}
# 运行集闭包 = needs 闭包 + 耦合组展开，反复到不动点（needs 只指向更早段、组是有限划分 → 收敛）
add_coupled() {
  local grew=1 i g m before
  build_groups
  while [ "$grew" = 1 ]; do
    grew=0
    before=$RUN_N; add_needs_closure; [ "$RUN_N" -ne "$before" ] && grew=1
    for ((i = 0; i < RUN_N; i++)); do
      g="$(key_group "${RUN_KEY[i]}" || true)"
      [ -n "$g" ] || continue
      for m in ${G_KEYS[g]}; do
        [ "$m" = "${RUN_KEY[i]}" ] && continue
        before=$RUN_N; add_key "$m" "coupled:${RUN_KEY[i]}"; [ "$RUN_N" -ne "$before" ] && grew=1
      done
    done
  done
  return 0
}
sort_run_by_source() { # 按源码行号把 RUN_KEY/RUN_WHY 插入排序（选择排序，O(n²)，n 很小）
  local i j min lmin li key why
  for ((i = 0; i < RUN_N - 1; i++)); do
    min=$i; lmin="$(sec_line "${RUN_KEY[i]}" || printf '999999999')"
    for ((j = i + 1; j < RUN_N; j++)); do
      li="$(sec_line "${RUN_KEY[j]}" || printf '999999999')"
      if [ "$li" -lt "$lmin" ]; then min=$j; lmin="$li"; fi
    done
    if [ "$min" -ne "$i" ]; then
      key="${RUN_KEY[i]}"; why="${RUN_WHY[i]}"
      RUN_KEY[i]="${RUN_KEY[min]}"; RUN_WHY[i]="${RUN_WHY[min]}"
      RUN_KEY[min]="$key"; RUN_WHY[min]="$why"
    fi
  done
}
print_run() {
  local i
  [ -z "$COPY_OUT" ] || emit_copy "$COPY_OUT" || exit 2
  printf 'decision=RUN\n'
  printf 'sections=%s\n' "$S_N"
  printf 'keys=%s\n' "$RUN_N"
  for ((i = 0; i < RUN_N; i++)); do printf 'reason=%s ← %s\n' "${RUN_KEY[i]}" "${RUN_WHY[i]}"; done
  for ((i = 0; i < RUN_N; i++)); do printf '%s\t%s\n' "${RUN_KEY[i]}" "${RUN_WHY[i]}"; done
}

# 把当前 RUN_* 集过滤成一份可解析的副本写进 <文件>：前导 + 命中的**整组** + 收尾，段正文逐字节原样。
# 返回 0 = 写好了且 bash -n 通过；1 = 副本不能解析（已点名段与源码行，调用方负责在跑段之前拒绝）。
emit_copy() { # <out>
  local out="$1" i g a b spec="" off=0 ranges="" err ln who srcline r ostart oend sstart ks
  local -a KEEP=() RARR=()
  build_groups
  for ((i = 0; i < G_N; i++)); do KEEP[i]=0; done
  for ((i = 0; i < RUN_N; i++)); do
    g="$(key_group "${RUN_KEY[i]}" || true)"
    [ -n "$g" ] || continue
    KEEP[g]=1
  done
  b=$((S_LINE[0] - 1))
  if [ "$b" -ge 1 ]; then
    spec="1,${b}p"; ranges="$(printf '%s|%s|%s|%s' "$((off + 1))" "$((off + b))" 1 前导)"; off=$((off + b))
  fi
  for ((g = 0; g < G_N; g++)); do
    [ "${KEEP[g]}" = 1 ] || continue
    a="${G_START[g]}"; b="${G_END[g]}"
    spec="${spec:+$spec;}${a},${b}p"
    ranges="${ranges:+$ranges;}$(printf '%s|%s|%s|%s' "$((off + 1))" "$((off + b - a + 1))" "$a" "${G_KEYS[g]}")"
    off=$((off + b - a + 1))
  done
  if [ "$TAIL_LINE" -gt 0 ]; then
    spec="${spec:+$spec;}${TAIL_LINE},\$p"
    ranges="${ranges:+$ranges;}$((off + 1))|-|${TAIL_LINE}|收尾"
  fi
  if [ -n "$spec" ]; then
    sed -n "$spec" "$SUITE" > "$out" || { printf 'section-select: 写副本失败：%s\n' "$out" >&2; return 1; }
  else
    : > "$out"
  fi
  if ! err="$(bash -n "$out" 2>&1)"; then
    ln="$(printf '%s\n' "$err" | head -1 | sed -n 's/^[^:]*: *line \([0-9][0-9]*\):.*/\1/p')"
    # 未闭合构造的起点（bash 消息里的 `... on line N`）比 EOF 的主报错行更能归因：优先用它
    local ln2
    ln2="$(printf '%s\n' "$err" | head -1 | sed -n 's/.*on line \([0-9][0-9]*\).*/\1/p')"
    [ -n "$ln2" ] && ln="$ln2"
    who=""; srcline=""
    if [ -n "$ln" ]; then
      IFS=';' read -r -a RARR <<<"$ranges"
      for r in "${RARR[@]}"; do
        IFS='|' read -r ostart oend sstart ks <<<"$r"
        [ "$oend" = "-" ] && oend="$ln"
        if [ "$ln" -ge "$ostart" ] && [ "$ln" -le "$oend" ]; then
          who="$ks"; srcline=$((sstart + ln - ostart)); break
        fi
      done
    fi
    printf 'section-select: 段副本不能解析（%s%s副本行 %s）：%s\n' \
      "${who:+段 $who · }" "${srcline:+源码行 $srcline · }" "${ln:-?}" "$(printf '%s' "$err" | head -1)" >&2
    printf 'section-select: 这次保留的键：%s\n' "$(printf '%s ' "${RUN_KEY[@]}")" >&2
    return 1
  fi
  return 0
}

# ── --verify-copies ─────────────────────────────────────────────────────────────────────
# 对**每个段键**：按 `--select <key>` 的口径算运行集 → 生成副本 → bash -n。结构腐烂（跨段构造没被
# 识别、段被切出孤立 fi…）会在这里成片红；emit_copy 的运行期守卫只保证单次调用在跑段之前早拒。
do_verify_copies() {
  build_groups
  local d out k n=0 bad=0 i
  d="$(mktemp -d "${TMPDIR:-/tmp}/teamsmith-select-copies.XXXXXX")" || die "建不了临时目录（TMPDIR=${TMPDIR:-/tmp}）"
  trap 'rm -rf "${d:-}"' EXIT
  printf '== 段副本 bash -n 全键扫描 ==\n'
  for ((i = 0; i < T_N; i++)); do
    k="${T_KEY[i]}"; n=$((n + 1))
    reset_run
    select_run_set "$k"
    out="$d/copy-$k.sh"
    if emit_copy "$out"; then printf 'ok: %s\n' "$k"; else bad=$((bad + 1)); printf 'bad: %s —— 副本不能解析（见上一行）\n' "$k"; fi
    rm -f "$out"
  done
  printf '== 段副本 bash -n 扫描 == ok %d bad %d\n' "$((n - bad))" "$bad"
  [ "$bad" -eq 0 ] || return 1
  return 0
}

# ── --paths ─────────────────────────────────────────────────────────────────────────────
do_paths() {
  local p i claimed pp unclaimed=() exempted=() PARR=()
  for p in "${PATHS[@]}"; do
    normalize_path "$p" || die "路径出界：$p（只接受仓库根相对路径，不允许绝对路径 / .. / ~）"
    p="$NORM_P"
    claimed=0
    for ((i = 0; i < T_N; i++)); do
      [ "${T_PAT[i]}" = "-" ] && continue
      IFS=' ' read -r -a PARR <<<"${T_PAT[i]}"
      for pp in "${PARR[@]}"; do
        if pat_match "$pp" "$p"; then
          claimed=1
          add_key "${T_KEY[i]}" "$p"
          break
        fi
      done
    done
    if [ "$claimed" = "0" ]; then
      if pat_match "$P_EXEMPT" "$p"; then exempted+=("$p"); else unclaimed+=("$p"); fi
    fi
  done
  if [ "${#unclaimed[@]}" -gt 0 ]; then
    printf 'decision=FULL\n'
    printf 'sections=%s\n' "$S_N"
    printf 'keys=0\n'
    for p in "${unclaimed[@]}"; do printf 'reason=%s ← 没有任何行声明它（也不在豁免类）\n' "$p"; done
    printf 'reason=兜底：跑全套（多跑总是安全，少跑不是）\n'
    return 0
  fi
  if [ "$RUN_N" -eq 0 ]; then
    printf 'decision=NONE\n'
    printf 'sections=%s\n' "$S_N"
    printf 'keys=0\n'
    for p in "${exempted[@]}"; do printf 'reason=%s ← 豁免类（%s）：团队账本，门禁不为它开火\n' "$p" "$P_EXEMPT"; done
    printf 'reason=没有段落需要运行（no section needs to run）\n'
    return 0
  fi
  add_prologue
  add_coupled
  sort_run_by_source
  print_run
  return 0
}

# ── --select ────────────────────────────────────────────────────────────────────────────
select_run_set() { # <key>…（显式选择）→ 填 RUN_*（不打印、不写副本）
  local k
  [ "$#" -gt 0 ] || die "--select 需要至少一个 key"
  for k in "$@"; do
    [ -n "$k" ] || die "--select 里有空的 key"
    sec_line "$k" >/dev/null || die "未知 key：$k（用 --list 看全部 key）"
    add_key "$k" "selected"
  done
  add_prologue
  add_coupled
  sort_run_by_source
}
do_select() { select_run_set "${SEL_KEYS[@]}"; print_run; }

# ── --list ──────────────────────────────────────────────────────────────────────────────
do_list() {
  local i
  for ((i = 0; i < T_N; i++)); do
    printf '%s\t%s\t%s\t%s\t%s\n' "${T_KEY[i]}" "${T_ID[i]}" "${T_PAT[i]}" "${T_NEEDS[i]}" "${T_BASIS[i]}"
  done
}

# ── --check ─────────────────────────────────────────────────────────────────────────────
# 两个方向都查：
#   ① 段 ↔ 行一一对应（段没行 / 行没段 / 重复 key）
#   ② needs 存在且指向**更早**的段
#   ③ 字面模式（无通配）存在于工作树
#   ④ 豁免类没有任何行声明
#   ⑤ 前导段的 key 都在（否则选段会少跑前导）
#   ⑥ 段正文里点名的**真实**路径 token 必须被该行的 patterns 覆盖（token 与行号都点名）；
#      豁免类（docs/**）的 token 不参与该检查 —— 按 ④ 没有任何行可以声明它们（选择器对它们的
#      回答是 NONE，不是某一段）
# 段正文的 normalizer（与 P97 探针同一口径）：$SKILL_DIR→skills/teamsmith、
#   $SKILL_INIT_DIR→skills/teamsmith-init、$SRC_ROOT/$OS_ROOT/$V94_ROOT→仓库根；
#   裸前缀 skills/ panel/ extension/ openspec/ ci/；根文件 SCOPE.md/README.md/AGENTS.md/CHANGELOG.md。
CHECK_OK=0; CHECK_BAD=0
cok()  { printf 'ok: %s\n' "$1"; CHECK_OK=$((CHECK_OK + 1)); }
cbad() { printf 'bad: %s\n' "$1"; CHECK_BAD=$((CHECK_BAD + 1)); }

# 一行 → 追加规范化 token 到全局数组 TOKS（纯内建，无 fork）
line_tokens() {
  local rest="$1" v up tail tok base depth seg
  TOKS=()
  while [[ $rest =~ \$\{?(SKILL_DIR|SKILL_INIT_DIR|SRC_ROOT|OS_ROOT|V94_ROOT)\}?((/\.\.)*)/([A-Za-z0-9._/-]+) ]]; do
    # 组号：1=变量名 2=((/..)*) 3=(/..) 里的内层 4=尾巴路径 —— 尾巴是 4，不是 3
    v="${BASH_REMATCH[1]}"; up="${BASH_REMATCH[2]}"; tail="${BASH_REMATCH[4]}"
    rest="${rest#*"${BASH_REMATCH[0]}"}"
    case "$v" in
      SKILL_DIR) base="skills/teamsmith" ;;
      SKILL_INIT_DIR) base="skills/teamsmith-init" ;;
      *) base="" ;;
    esac
    depth=0
    while [[ $up =~ /\.\. ]]; do depth=$((depth + 1)); up="${up#*/..}"; done
    for ((seg = 0; seg < depth; seg++)); do base="${base%/*}"; done
    tok="${base}/${tail}"; tok="${tok#/}"
    TOKS+=("$tok")
  done
  while [[ $rest =~ (^|[^A-Za-z0-9_./-])((skills|panel|extension|openspec|ci)/[A-Za-z0-9._/-]+) ]]; do
    tok="${BASH_REMATCH[2]}"; rest="${rest#*"$tok"}"; TOKS+=("$tok")
  done
  while [[ $rest =~ (^|[^A-Za-z0-9_./-])(SCOPE\.md|README\.md|AGENTS\.md|CHANGELOG\.md) ]]; do
    tok="${BASH_REMATCH[2]}"; rest="${rest#*"$tok"}"; TOKS+=("$tok")
  done
}
# <token> → TRIM（去掉与探针同款的行尾标点与尾斜杠）
trim_token() {
  local c
  TRIM="$1"
  while [ -n "$TRIM" ]; do
    c="${TRIM: -1}"
    case "$c" in
      '.'|','|';'|':'|')'|"'"|'"'|']'|'/') TRIM="${TRIM%?}" ;;
      *) break ;;
    esac
  done
}

do_check() {
  local i j k line n=0 pp dup="" missing_rows=() missing_rows_n=() missing_secs=()
  local nb=0 n_ok=0 lit_bad=0 lit_n=0 ex_bad=0 pro_bad=0 tok_bad=0 tok_n=0 ex_tok_n=0
  local cur="" curline=0 ri="" covered pp PARR=() TOKS=() t
  # ① 段 ↔ 行
  for ((i = 0; i < T_N; i++)); do
    for ((j = i + 1; j < T_N; j++)); do [ "${T_KEY[i]}" = "${T_KEY[j]}" ] && dup="${dup} ${T_KEY[i]}"; done
    sec_line "${T_KEY[i]}" >/dev/null || missing_secs+=("${T_KEY[i]}")
  done
  if [ -n "$dup" ]; then cbad "映射表有重复 key：$(printf '%s' "$dup")"; else cok "映射表 key 唯一（$T_N 行）"; fi
  for ((i = 0; i < S_N; i++)); do
    [ -n "$(row_idx "${S_KEY[i]}" || true)" ] || missing_rows_n+=("${S_KEY[i]}")
  done
  if [ "${#missing_rows_n[@]}" -eq 0 ] && [ "${#missing_secs[@]}" -eq 0 ]; then
    cok "段 ↔ 行一一对应（源码 $S_N 段 / 表 $T_N 行）"
  else
    [ "${#missing_rows_n[@]}" -gt 0 ] && cbad "源码里有段没有行：${missing_rows_n[*]}"
    [ "${#missing_secs[@]}" -gt 0 ] && cbad "表里有 key 在源码里找不到：${missing_secs[*]}"
  fi
  # ② needs：存在 + 更早
  for ((i = 0; i < T_N; i++)); do
    [ "${T_NEEDS[i]}" = "-" ] && continue
    local NARR=() li lj
    IFS=',' read -r -a NARR <<<"${T_NEEDS[i]}"
    for k in "${NARR[@]}"; do
      [ -n "$k" ] || continue
      nb=$((nb + 1))
      if ! sec_line "$k" >/dev/null; then cbad "行 ${T_KEY[i]} 的 needs 指向未知段：$k"; continue; fi
      li="$(sec_line "${T_KEY[i]}")"; lj="$(sec_line "$k")"
      if [ "$lj" -lt "$li" ]; then n_ok=$((n_ok + 1)); else cbad "行 ${T_KEY[i]} 的 needs:$k 不在它之前（行 $lj ≥ $li）"; fi
    done
  done
  [ "$nb" -eq "$n_ok" ] && cok "needs 声明全部存在且指向更早的段（$nb 条）"
  # ③ 字面模式存在
  for ((i = 0; i < T_N; i++)); do
    [ "${T_PAT[i]}" = "-" ] && continue
    IFS=' ' read -r -a PARR <<<"${T_PAT[i]}"
    for pp in "${PARR[@]}"; do
      case "$pp" in *'*'*) continue ;; esac
      lit_n=$((lit_n + 1))
      [ -e "$ROOT/$pp" ] || { cbad "行 ${T_KEY[i]} 的字面模式在工作树里不存在：$pp"; lit_bad=$((lit_bad + 1)); }
    done
  done
  [ "$lit_bad" -eq 0 ] && cok "字面模式全部存在于工作树（$lit_n 条）"
  # ④ 豁免类没有任何行声明
  for ((i = 0; i < T_N; i++)); do
    [ "${T_PAT[i]}" = "-" ] && continue
    IFS=' ' read -r -a PARR <<<"${T_PAT[i]}"
    for pp in "${PARR[@]}"; do
      for j in docs/team/BOARD.md docs/team/ROADMAP.md docs/team/reports/X.md docs/team/tasks/X.md \
               docs/team/threads/dev.md docs/team/inbox/dev.md docs/team/reviews/X.md \
               docs/team/OWNERSHIP.md docs/team/DECISIONS.md docs/README.md; do
        if pat_match "$pp" "$j"; then cbad "行 ${T_KEY[i]} 声明了豁免类路径：模式 $pp 覆盖 $j"; ex_bad=$((ex_bad + 1)); fi
      done
    done
  done
  [ "$ex_bad" -eq 0 ] && cok "豁免类（$P_EXEMPT）没有任何行声明"
  # ⑤ 前导段 key 都在
  for k in $P_PROLOGUE; do
    sec_line "$k" >/dev/null || { cbad "前导段 key 在源码里不存在：$k"; pro_bad=$((pro_bad + 1)); }
  done
  [ "$pro_bad" -eq 0 ] && cok "前导段声明有效（$P_PROLOGUE）"
  # ⑥ 段正文点名的真实路径 token 必须被该行覆盖
  while IFS= read -r line; do
    n=$((n + 1))
    case "$line" in
      *'section "'*)
        if [[ $line =~ ^[[:space:]]*section[[:space:]]+\"([^\"]+)\" ]]; then
          cur="${BASH_REMATCH[1]}"; cur="${cur%% · *}"; curline=$n
          ri="$(row_idx "$cur" || true)"
          continue
        fi ;;
    esac
    [ -n "$cur" ] || continue
    line_tokens "$line"
    for t in "${TOKS[@]}"; do
      trim_token "$t"; t="$TRIM"
      [ -n "$t" ] || continue
      [ -e "$ROOT/$t" ] || continue
      if pat_match "$P_EXEMPT" "$t"; then ex_tok_n=$((ex_tok_n + 1)); continue; fi
      tok_n=$((tok_n + 1))
      [ -n "$ri" ] || continue
      covered=0
      if [ "${T_PAT[ri]}" != "-" ]; then
        IFS=' ' read -r -a PARR <<<"${T_PAT[ri]}"
        for pp in "${PARR[@]}"; do pat_match "$pp" "$t" && { covered=1; break; }; done
      fi
      if [ "$covered" = "0" ]; then
        cbad "段 $cur 读了它没声明的路径：token $t（源码行 $n）—— 补进该行的 patterns"
        tok_bad=$((tok_bad + 1))
      fi
    done
  done < "$SUITE"
  [ "$tok_bad" -eq 0 ] && cok "段正文点名的真实路径 token 都被各自的行覆盖（$tok_n 个 token 检查过；$ex_tok_n 个豁免类 token 不参与）"

  printf '== 选段自检 ==  ok %d  bad %d\n' "$CHECK_OK" "$CHECK_BAD"
  [ "$CHECK_BAD" -eq 0 ] || return 1
  return 0
}

# ── main ────────────────────────────────────────────────────────────────────────────────
case "$MODE" in
  paths)          load_table; load_suite; do_paths ;;
  select)         load_table; load_suite; do_select ;;
  list)           load_table; do_list ;;
  check)          load_table; load_suite; do_check ;;
  verify-copies)  load_table; load_suite; do_verify_copies ;;
esac
