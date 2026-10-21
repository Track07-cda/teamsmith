#!/usr/bin/env bash
# teamsmith · 选段选择器（change: gate-runtime-budget · verification#A changed-path list selects…）
#
#   section-select.sh --paths <路径>…            路径 → decision=FULL|NONE|RUN
#   section-select.sh --floor [--paths <路径>…]  产品地板 ∪ 路径选集（一次回答「基线 + 这次改动」）
#   section-select.sh --slice <k>/<N>           按片切（与 --floor/--paths/不带决策正交）：own 与借来的分列
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
#         2 = 用法错误、表畸形、未知 key、路径出界、空地板。
#
# 决定语义（保守方向永远是「多跑」）：
#   NONE = 给的路径全在豁免类（docs/*，团队账本）且没有被表头 ledger-scan 归属模式覆盖
#          → 没有段需要跑
#   RUN  = 给的路径每条都被某些行声明 → 这些 key + 前导段 + needs 闭包，按源序
#   FULL = 至少一条路径没有任何行声明、也不在豁免类 → 跑全套（兜底不可绕过）
#
# 分片（P346 · CI 的分片并行）：片号 = cksum(key) % N —— 规则**只看 key**，不看它在表里的位置：按位置
# 轮转会让「第 k 片」随行的增删指不同的段（表里插一行，它之后每一段都换片），于是「重跑第 2 片」可能
# 跑的是另一批段。N 由调用方给（CI 的唯一来源是 workflow 矩阵长度），本脚本不猜也不给默认值。
# 切片后的运行集 = own（本片自己的 key）∪ 前导段 ∪ needs/耦合闭包：闭包里不属于本片的那些就是
# **为 needs 从别片借来的段**，打印时单列（reason 里的 `needs:<key>` / `coupled:<key>` 就是来历）。
# 给了 --out 时另写一份 <out>.keys（own，源序，每行一个 key）供 CI 的 coverage 作业收集 ——
# **借来的段不在里面**：那是重复覆盖，不是这一片的份额。兜底的「全套」（未声明路径 / 基点不可解析）
# 也按片切（打印 base=all），否则矩阵里每一片都要跑整套。
#
# 地板（P326 · change: behavior-focused-ci）：表头 `# gate-self-check: <key…>` 点名「主体是门禁自己的机制」
# 的段，**没被点名的段就是产品基线**（默认方向 = 在基线里）。`--floor` 的 key 集合 = 前导段 ∪ 产品基线段
# ∪ 它们的 needs 闭包，给了 `--paths` 时再并进路径选集（未声明路径照旧 FULL）。地板为空（表头把每个段都
# 点名了，或这行在却一个 key 都没有）→ die 并点名「空地板」：绝不静默退化成「只跑前导段」。
# `--floor` 与 `--select` 互斥（显式选集与基线是两种决定）；`--paths` 单独用时节义逐字不变。
#
# 账本（docs/team/**）的归属（P239）：patterns 列**不允许**声明豁免类（--check ④ 守着这条），
# 所以账本路径的归属写在表头一行 `# ledger-scan: <key> <pattern…>`：命中的路径归那一段。
# 删掉这行（或它的归属模式）→ 账本路径回到豁免类（NONE）；--check ⑦ 会对「缺头 / 指向未知段 /
# 没有模式 / 模式没盖住账本样例」逐条判红。
# P231：这行还必须**唯一**，且指向**承载账本禁令的那一段**（patterns 列声明了 $LSC_CARRIER）——
# 两份表头（旧行为：最后一行赢）或指向别的段都不再放行，**装载时就报错点名**（die，rc=2）。
set -uo pipefail

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEL_DIR="$here"

# P287：临时根名字里的项目命名空间（ns）的唯一实现在 scripts/lib/common.sh —— 独立跑本脚本时补一次。
if ! declare -F team_project_ns >/dev/null 2>&1; then
  [ -f "$here/../scripts/lib/common.sh" ] && . "$here/../scripts/lib/common.sh"
fi
section_select_ns() { team_project_ns 2>/dev/null || printf 'nosig-00000000\n'; }

ROOT=""
MODE=""
COPY_OUT=""
SLICE_K=0; SLICE_N=0     # --slice k/N（0/0 = 没给）
PATHS=()
SEL_KEYS=()
die() { printf 'section-select: %s\n' "$*" >&2; exit 2; }
usage() { sed -n '2,/^set -uo pipefail/p' "$0" | sed '$d'; }

# ── 参数 ────────────────────────────────────────────────────────────────────────────────
while [ $# -gt 0 ]; do
  case "$1" in
    --floor)
      [ -z "$MODE" ] || [ "$MODE" = "paths" ] || [ "$MODE" = "floor" ] || die "--floor 与 --$MODE 不同用"
      MODE="floor"; shift ;;
    --slice)
      shift; [ $# -gt 0 ] || die "--slice 需要 k/N"
      [ "$SLICE_N" -eq 0 ] || die "--slice 只能给一次"
      case "$1" in
        */*) _sk="${1%%/*}"; _sn="${1#*/}" ;;
        *)   die "分片要写成 k/N（收到 $1）" ;;
      esac
      case "$_sk" in ''|*[!0-9]*) die "分片 k 必须是正整数（收到 $1）" ;; esac
      case "$_sn" in ''|*[!0-9]*) die "分片 N 必须是正整数（收到 $1）" ;; esac
      [ "${#_sk}" -le 9 ] && [ "${#_sn}" -le 9 ] || die "分片 k/N 的数字太长（收到 $1）"
      SLICE_K=$((10#$_sk)); SLICE_N=$((10#$_sn)); unset _sk _sn
      [ "$SLICE_N" -ge 1 ] || die "分片要 1 ≤ k ≤ N 且 N ≥ 1：N=$SLICE_N（收到 $1）"
      [ "$SLICE_K" -ge 1 ] || die "分片要 1 ≤ k ≤ N：k=$SLICE_K（收到 $1）"
      [ "$SLICE_K" -le "$SLICE_N" ] || die "分片 k=$SLICE_K 超出 N=$SLICE_N（要 1 ≤ k ≤ N）"
      shift ;;
    --paths)
      shift; [ $# -gt 0 ] || die "--paths 需要至少一条路径"
      [ -z "$MODE" ] || [ "$MODE" = "paths" ] || [ "$MODE" = "floor" ] || die "--paths 与 --$MODE 不同用"
      [ "$MODE" = "floor" ] || MODE="paths"
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
# 分片与三种基线决策正交（--floor / --paths / 不带决策=全集）；--select 与三种自检模式不吃它 ——
# 显式选集与「从基线里切一份」是两个不同的决定，混用时读者无法说清「第 k 片」指的是谁的份额。
if [ "${SLICE_N:-0}" -gt 0 ]; then
  case "$MODE" in
    ''|floor|paths) [ -n "$MODE" ] || MODE="all" ;;
    *) die "--slice 只与 --floor / --paths / 不带决策（全集）同用（当前是 --$MODE）" ;;
  esac
fi
[ -n "$MODE" ] || { usage >&2; exit 2; }
if [ -n "$COPY_OUT" ]; then
  case "$MODE" in
    paths|select|floor|all) ;;
    *) die "--out 只与 --paths/--select/--floor/--slice 同用（当前是 --$MODE）" ;;
  esac
fi

if [ -z "$ROOT" ]; then
  ROOT="${TEAM_SECTION_SELECT_ROOT:-$(cd -P "$SEL_DIR/../../.." && pwd)}"
else
  ROOT="$(cd -P "$ROOT" 2>/dev/null && pwd)" || die "--root 目录不存在：$ROOT"
fi
TSV="$ROOT/skills/teamsmith/tests/section-paths.tsv"
SUITE="$ROOT/skills/teamsmith/tests/smoke.sh"
# ── 检出形状（change: product-checkout-gate；P222 加机器生成面）────────────────────────
# 与门禁共用同一份判据（纯文件，不看 TEAM_* / git / CI）：§③ 的字面存在性检查里，机器生成面
# （`.pi/prompts` / `.pi/skills`）整棵不在时按缺失跳过；其余字面量只有在**产品面检出**里、且落在
# 那几个**精确**内部前提上时才允许按缺失跳过。
# shellcheck source=tests/lib/checkout-shape.sh
. "$SEL_DIR/lib/checkout-shape.sh"
CHECKOUT_SHAPE="$(checkout_shape "$ROOT")"
# 夹具旋钮：换一张表来跑 --check（只有夹具用；语义/格式一模一样，真路径仍是 $ROOT）
[ -z "${TABLE:-}" ] || TSV="$TABLE"

# ── 映射表（唯一声明处）──────────────────────────────────────────────────────────────────
# columns = key / id / patterns / needs / basis
#   patterns：仓库根相对路径的 case glob，空格分隔；`*` **跨 / **（bash case 语义）。
#             例：`skills/teamsmith/tests/*` 覆盖它下面任意深度；`-` = 没有声明。
#   needs   ：必须先跑的段 key（逗号分隔）；`-` = 无。选段时它们连同自己的 needs 一起进闭包。
P_EXEMPT=""
P_PROLOGUE=""
P_LEDGER_SCAN=""   # 表头 `# ledger-scan: <key> <pattern…>`：账本（docs/team/**）的归属行（P239）
P_LEDGER_PAT=""    # 上面那行的归属模式（空格分隔，同 patterns 列的 case glob 语义）
P_LEDGER_LINE=""   # 上面那行的原文载荷（解析用；空 = 表里没有这行）
P_LEDGER_LNS=()    # 上面那行在表里的行号（P231：>1 行 = 重复声明，装载即拒绝）
P_SELF_DECLARED=0  # 表头 `# gate-self-check: <key…>` 在不在（P326）：行在 = 1
P_SELF_KEYS=""     # 上面那行点名的段 key（空格分隔）；空串 = 行在但没点名任何段
P_SELF_LNS=()      # 上面那行在表里的行号
LSC_CARRIER="skills/teamsmith/tests/ledger-ban.sh"   # 承载账本禁令的段：patterns 列里必须有它（P231）
T_N=0
T_KEY=(); T_ID=(); T_PAT=(); T_NEEDS=(); T_BASIS=()

load_table() {
  [ -r "$TSV" ] || die "读不到映射表 $TSV"
  local line nf ln=0
  T_N=0
  while IFS= read -r line || [ -n "$line" ]; do
    ln=$((ln + 1))
    case "$line" in
      "# exempt:"*)   P_EXEMPT="${line#\# exempt:}"; P_EXEMPT="${P_EXEMPT# }"; P_EXEMPT="${P_EXEMPT% }"; continue ;;
      "# prologue:"*) P_PROLOGUE="${line#\# prologue:}"; P_PROLOGUE="${P_PROLOGUE# }"; P_PROLOGUE="${P_PROLOGUE% }"; continue ;;
      "# ledger-scan:"*) P_LEDGER_LINE="${line#\# ledger-scan:}"; P_LEDGER_LINE="${P_LEDGER_LINE# }"; P_LEDGER_LINE="${P_LEDGER_LINE% }"
        P_LEDGER_SCAN="${P_LEDGER_LINE%% *}"; P_LEDGER_PAT="${P_LEDGER_LINE#"$P_LEDGER_SCAN"}"; P_LEDGER_PAT="${P_LEDGER_PAT# }"
        P_LEDGER_LNS+=("$ln")
        continue ;;
      "# gate-self-check:"*) P_SELF_KEYS="${line#\# gate-self-check:}"; P_SELF_KEYS="${P_SELF_KEYS# }"; P_SELF_KEYS="${P_SELF_KEYS% }"
        P_SELF_DECLARED=1; P_SELF_LNS+=("$ln")
        continue ;;
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
  load_table_check_ledger_head
}

# P231：ledger-scan 头的两条装载期铁律 —— 必须是**唯一**一行，且指向**承载账本禁令的那一段**
# （那一段的 patterns 列声明了 $LSC_CARRIER）。两种违反过去都能过：两份表头是最后一行赢，指向
# 别的段只看「段在不在」。现在都在装载时报错点名（文件 + 行号），不静默选一边。
load_table_check_ledger_head() {
  local row
  if [ "${#P_LEDGER_LNS[@]}" -gt 1 ]; then
    die "映射表有 ${#P_LEDGER_LNS[@]} 行 ledger-scan 头（$TSV:$(printf '%s' "${P_LEDGER_LNS[*]}" | tr ' ' ',')）—— 归属只许声明一处（旧行为是最后一行赢，已拒绝）"
  fi
  [ -n "$P_LEDGER_SCAN" ] || return 0   # 缺头不是装载错：--check ⑦ 判红（账本路径回到 NONE）
  if ! row="$(row_idx "$P_LEDGER_SCAN")"; then
    die "ledger-scan 头（$TSV:${P_LEDGER_LNS[0]}）指向未知段 [$P_LEDGER_SCAN] —— 归属必须落在承载账本禁令的那一段（patterns 里有 $LSC_CARRIER）"
  fi
  case " ${T_PAT[row]} " in
    *" $LSC_CARRIER "*) ;;
    *) die "ledger-scan 头（$TSV:${P_LEDGER_LNS[0]}）指向 [$P_LEDGER_SCAN]，但那一行的 patterns 列没有 $LSC_CARRIER —— 归属必须落在承载账本禁令的那一段" ;;
  esac
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
# ── 分片（P346）────────────────────────────────────────────────────────────────────
# 片号 = cksum(key) % N。下标是**显式传入但不参与**的：规则只许看 key（按位置轮转会让「第 k 片」随行的
# 增删漂移）。--check ⑨ 用「同一个 key 换一个下标必须留在同一片」钉死这条。
declare -A CRC_CACHE=()
key_crc() { # <key> → 十进制 CRC（POSIX cksum，纯 ASCII 输入，跨机器一致）
  local k="$1" v
  if [ -n "${CRC_CACHE[$k]:-}" ]; then printf '%s' "${CRC_CACHE[$k]}"; return 0; fi
  v="$(printf '%s' "$k" | cksum)" || return 1
  v="${v%% *}"
  case "$v" in ''|*[!0-9]*) return 1 ;; esac
  CRC_CACHE[$k]="$v"
  printf '%s' "$v"
}
slice_of_key() { # <key> <基线下标（不参与规则）> <N> → 0..N-1
  local k="$1" idx="$2" n="$3" c
  : "$idx"
  case "$n" in ''|*[!0-9]*) die "分片数 N 必须是正整数（收到 [$n]）" ;; esac
  [ "$n" -ge 1 ] || die "分片数 N 必须 ≥ 1（收到 $n）"
  c="$(key_crc "$k")" || die "算不出段 key [$k] 的分片哈希（cksum 失败）"
  printf '%s' "$(( c % n ))"
}

SLICE_BASE=""          # floor / paths / all（仅用于披露行）
SLICE_KEYS_FILE=""      # 给了 --out 时：<out>.keys 的路径
BASE_KEY=(); BASE_WHY=(); BASE_N=0
OWN_KEY=(); OWN_N=0

key_is_own() { # <key>
  local i
  for ((i = 0; i < OWN_N; i++)); do [ "${OWN_KEY[i]}" = "$1" ] && return 0; done
  return 1
}
base_from_run() { # 把切片前的决策集（RUN_*）存成 BASE_*，然后清空 RUN_*
  local i
  BASE_KEY=(); BASE_WHY=(); BASE_N=$RUN_N
  for ((i = 0; i < RUN_N; i++)); do BASE_KEY+=("${RUN_KEY[i]}"); BASE_WHY+=("${RUN_WHY[i]}"); done
  reset_run
}
slice_run_set() { # 前提：BASE_* 就绪、SLICE_K/SLICE_N 已校验 → 填 OWN_* 与 RUN_*
  local i k sh
  OWN_KEY=(); OWN_N=0
  for ((i = 0; i < BASE_N; i++)); do
    k="${BASE_KEY[i]}"
    sh="$(slice_of_key "$k" "$i" "$SLICE_N")" || exit 2
    [ "$sh" = "$((SLICE_K - 1))" ] || continue
    OWN_KEY+=("$k"); OWN_N=$((OWN_N + 1))
    add_key "$k" "${BASE_WHY[i]}, slice"
  done
  add_prologue
  add_coupled
  sort_run_by_source
}
write_slice_keys() { # 给了 --out 才写：<out>.keys（own，源序，每行一个 key）
  local f i
  SLICE_KEYS_FILE=""
  [ -n "$COPY_OUT" ] || return 0
  f="$COPY_OUT.keys"
  { for ((i = 0; i < OWN_N; i++)); do printf '%s\n' "${OWN_KEY[i]}"; done; } > "$f" \
    || { printf 'section-select: 写不了本片 key 清单：%s\n' "$f" >&2; return 1; }
  SLICE_KEYS_FILE="$f"
  return 0
}
finish() { # 决策算完（RUN_* = 未切片的决策集）→ 需要时切片 → 打印（必要时写副本与 .keys）
  if [ "${SLICE_N:-0}" -gt 0 ]; then
    base_from_run
    slice_run_set
  fi
  print_run
}

print_run() {
  local i
  [ -z "$COPY_OUT" ] || emit_copy "$COPY_OUT" || exit 2
  if [ "${SLICE_N:-0}" -gt 0 ]; then write_slice_keys || exit 2; fi
  printf 'decision=RUN\n'
  printf 'sections=%s\n' "$S_N"
  if [ "${SLICE_N:-0}" -gt 0 ]; then
    printf 'slice=%s/%s\n' "$SLICE_K" "$SLICE_N"
    printf 'base=%s\n' "${SLICE_BASE:-?}"
    printf 'own=%s\n' "$OWN_N"
    printf 'borrowed=%s\n' "$((RUN_N - OWN_N))"
    [ -z "${SLICE_KEYS_FILE:-}" ] || printf 'keys-file=%s\n' "$SLICE_KEYS_FILE"
    for ((i = 0; i < OWN_N; i++)); do printf 'own-key=%s\n' "${OWN_KEY[i]}"; done
    for ((i = 0; i < RUN_N; i++)); do
      key_is_own "${RUN_KEY[i]}" && continue
      printf 'borrowed-key=%s\n' "${RUN_KEY[i]}"
    done
  fi
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
  team_tmp_root_prepare >/dev/null 2>&1 || true
  d="$(mktemp -d "$(team_tmp_root)/teamsmith-select-copies-$(section_select_ns).XXXXXX")" || die "建不了临时目录（TMPDIR=$(team_tmp_root)）"
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

# ── --paths / --floor 共用：路径 → 归属（RUN_*）─────────────────────────────────────────
# 结果：命中的行 key 进 RUN_*；没命中的分两堆：CL_EXEMPTED（豁免类）/ CL_UNCLAIMED（谁也不同意）。
# 返回 1 = 有未声明路径（调用方照旧打印 FULL 兜底）。
CL_UNCLAIMED=(); CL_EXEMPTED=()
claim_paths() {
  local p i claimed pp PARR=()
  CL_UNCLAIMED=(); CL_EXEMPTED=()
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
      # 账本归属（P239）：patterns 列不许声明豁免类，所以账本路径的归属由表头 ledger-scan 行提供。
      if [ -n "$P_LEDGER_PAT" ]; then
        IFS=' ' read -r -a PARR <<<"$P_LEDGER_PAT"
        for pp in "${PARR[@]}"; do
          if pat_match "$pp" "$p"; then claimed=1; add_key "$P_LEDGER_SCAN" "$p"; break; fi
        done
      fi
    fi
    if [ "$claimed" = "0" ]; then
      if pat_match "$P_EXEMPT" "$p"; then CL_EXEMPTED+=("$p"); else CL_UNCLAIMED+=("$p"); fi
    fi
  done
  [ "${#CL_UNCLAIMED[@]}" -eq 0 ]
}
print_full() {
  local p
  printf 'decision=FULL\n'
  printf 'sections=%s\n' "$S_N"
  printf 'keys=0\n'
  for p in "${CL_UNCLAIMED[@]}"; do printf 'reason=%s ← 没有任何行声明它（也不在豁免类）\n' "$p"; done
  printf 'reason=兜底：跑全套（多跑总是安全，少跑不是）\n'
}
# 兜底的「跑全套」：切片时它也要**按片切**（base=all）—— 否则矩阵里每一片都得跑整套，并行等于没做；
# 不切片时行为逐字不变（decision=FULL，由 smoke 自己跑全套）。
do_full() {
  local i
  if [ "${SLICE_N:-0}" -gt 0 ]; then
    SLICE_BASE="all"
    reset_run
    for ((i = 0; i < S_N; i++)); do add_key "${S_KEY[i]}" "all"; done
    finish
    return 0
  fi
  print_full
}

# ── --paths ─────────────────────────────────────────────────────────────────────────────
do_paths() {
  local p
  claim_paths || { do_full; return 0; }
  if [ "$RUN_N" -eq 0 ]; then
    printf 'decision=NONE\n'
    printf 'sections=%s\n' "$S_N"
    printf 'keys=0\n'
    for p in "${CL_EXEMPTED[@]}"; do printf 'reason=%s ← 豁免类（%s）且没有被账本归属（ledger-scan）覆盖：门禁不为它开火\n' "$p" "$P_EXEMPT"; done
    printf 'reason=没有段落需要运行（no section needs to run）\n'
    return 0
  fi
  SLICE_BASE="paths"
  add_prologue
  add_coupled
  sort_run_by_source
  finish
  return 0
}

# ── --floor ────────────────────────────────────────────────────────────────────────────
# 地板 = 表里**没被 `# gate-self-check:` 点名的每一个段**（默认方向：新段自动在基线里）。
# 行不在 → 每个段都在地板里（安全方向）；行在却一个 key 都没有 / 每个段都被点名 → 空地板 → die。
# 地板的**声明集**：表里没被 `# gate-self-check:` 点名的每一行 key（--floor 与 --check ⑨ 的唯一来源）。
declared_floor_keys() {
  local i
  for ((i = 0; i < T_N; i++)); do
    case " $P_SELF_KEYS " in
      *" ${T_KEY[i]} "*) ;;
      *) printf '%s\n' "${T_KEY[i]}" ;;
    esac
  done
}
build_floor_run() { # [soft]：填 RUN_* = 地板 ∪ 前导 ∪ 闭包；soft = 空地板时返回 1 而不是 die
  local k soft="${1:-}" FLOOR=()
  if [ "$P_SELF_DECLARED" = 1 ] && [ -z "$P_SELF_KEYS" ]; then
    [ "$soft" = "soft" ] && return 1
    die "--floor：空地板 —— gate-self-check 行（$TSV:${P_SELF_LNS[*]}）在但没点名任何段；空行不许退化成「只跑前导段」"
  fi
  while IFS= read -r k; do FLOOR+=("$k"); done < <(declared_floor_keys)
  if [ "${#FLOOR[@]}" -eq 0 ]; then
    [ "$soft" = "soft" ] && return 1
    die "--floor：空地板 —— $T_N 个段全被 gate-self-check 行点名，没有产品基线段可跑"
  fi
  add_prologue
  for k in "${FLOOR[@]}"; do add_key "$k" "floor"; done
  add_coupled
  sort_run_by_source
  return 0
}

do_floor() {
  SLICE_BASE="floor"
  if [ "${#PATHS[@]}" -gt 0 ]; then
    claim_paths || { do_full; return 0; }
    SLICE_BASE="paths"
  fi
  build_floor_run
  finish
  return 0
}

# ── --all（不带决策 = 全集；只由 --slice 进来）─────────────────────────────────────────────
do_all() {
  local i
  SLICE_BASE="all"
  reset_run
  for ((i = 0; i < S_N; i++)); do add_key "${S_KEY[i]}" "all"; done
  finish
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
#   ④ 豁免类没有任何行声明（patterns 列）
#   ⑤ 前导段的 key 都在（否则选段会少跑前导）
#   ⑥ 段正文里点名的**真实**路径 token 必须被该行的 patterns 覆盖（token 与行号都点名）；
#      豁免类（docs/**）的 token 不参与该检查 —— 按 ④ 没有任何行可以声明它们（账本路径的归属由
#      表头 ledger-scan 行担当，不写进 patterns，所以这里也不参与；它有自己的 ⑦）
#   ⑦ 账本归属（P239）：表头 ledger-scan 行必须在、指向已存在的段、有归属模式，且模式盖住
#      每一个账本样例（缺一样 = 账本文本的改动不再选中任何段 → 红）。
#      P231：「唯一 + 指向承载禁令的段」这两条在装载期就 die（load_table_check_ledger_head），
#      走到这里时它们已经成立 —— 下面「指向未知段」那一支只是防御，不是第一道门。
#   ⑧ 地板声明（P326）：表头 `# gate-self-check:` 行里每个 key 命中恰好一行、不重复、不点名前导段。
#      行不在 = 每个段都在地板里（安全方向，不判红）；行在但为空 = 空声明，判红。
# 段正文的 normalizer（与 P97 探针同一口径）：$SKILL_DIR→skills/teamsmith、
#   $SKILL_INIT_DIR→skills/teamsmith-init、$SRC_ROOT/$OS_ROOT/$V94_ROOT→仓库根；
#   裸前缀 skills/ panel/ extension/ openspec/ ci/；根文件 SCOPE.md/README.md/AGENTS.md/CHANGELOG.md。
CHECK_OK=0; CHECK_BAD=0; CHECK_SKIP=0
cok()  { printf 'ok: %s\n' "$1"; CHECK_OK=$((CHECK_OK + 1)); }
cbad() { printf 'bad: %s\n' "$1"; CHECK_BAD=$((CHECK_BAD + 1)); }
# 前提缺失（机器生成面整棵不在；或产品面检出里刻意不存在的内部开发面）：与 ok/bad 分开点名、
# 分开计数（SKIP 不是通过，也不是失败）。行里带行 key 与精确路径 —— 读者能照着重跑、也能照着核。
csk()  { printf 'SKIP（条件不满足）: %s\n' "$1"; CHECK_SKIP=$((CHECK_SKIP + 1)); }

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
  local nb=0 n_ok=0 lit_bad=0 lit_n=0 lit_skip_c=0 ex_bad=0 pro_bad=0 tok_bad=0 tok_n=0 ex_tok_n=0
  local cur="" curline=0 ri="" covered pp PARR=() TOKS=() t _lit_why=""
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
  # ③ 字面模式存在（机器生成面整棵不在、或产品面检出里的**精确**内部前提按缺失跳过 ——
  #     不是前缀豁免、不是整表放行；其余缺失一律红）
  for ((i = 0; i < T_N; i++)); do
    [ "${T_PAT[i]}" = "-" ] && continue
    IFS=' ' read -r -a PARR <<<"${T_PAT[i]}"
    for pp in "${PARR[@]}"; do
      case "$pp" in *'*'*) continue ;; esac
      lit_n=$((lit_n + 1))
      [ -e "$ROOT/$pp" ] && continue
      if checkout_literal_skippable "$ROOT" "$CHECKOUT_SHAPE" "$pp"; then
        if checkout_generated_surface_absent "$ROOT" "$pp"; then
          _lit_why="机器生成面（工具在本机生成、不进仓库）"
        else
          _lit_why="内部开发面前提"
        fi
        csk "行 ${T_KEY[i]} 的字面模式在检出里不存在（检出形状 $CHECKOUT_SHAPE，$_lit_why）：$pp"
        lit_skip_c=$((lit_skip_c + 1))
      else
        cbad "行 ${T_KEY[i]} 的字面模式在工作树里不存在：$pp"
        lit_bad=$((lit_bad + 1))
      fi
    done
  done
  if [ "$lit_bad" -eq 0 ] && [ "$lit_skip_c" -eq 0 ]; then
    cok "字面模式全部存在于工作树（$lit_n 条）"
  elif [ "$lit_bad" -eq 0 ]; then
    cok "字面模式（$lit_n 条）里 $((lit_n - lit_skip_c)) 条在位；$lit_skip_c 条检出前提按缺失跳过（跳过不等于检查过）"
  fi
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

  # ⑦ 账本归属（P239）：表头 ledger-scan 行必须在、指向已存在的段、有归属模式，且模式盖住每个账本样例。
  #    缺一样 = 账本文本的改动不再选中任何段（回到 NONE）；这一条是它的静态牙（行为面在 §60 的夹具里）。
  local lsc_bad=0 lsc_n=0 lsc_row=""
  if [ -z "$P_LEDGER_SCAN" ]; then
    cbad "映射表缺 ledger-scan 头（账本路径没有归属声明处）"; lsc_bad=$((lsc_bad + 1))
  else
    lsc_row="$(row_idx "$P_LEDGER_SCAN" || true)"
    [ -n "$lsc_row" ] || { cbad "ledger-scan 头 [$P_LEDGER_SCAN] 不在映射表里（归属指向未知段）"; lsc_bad=$((lsc_bad + 1)); }
    [ -n "$P_LEDGER_PAT" ] || { cbad "ledger-scan 头没有归属模式（$P_LEDGER_SCAN）"; lsc_bad=$((lsc_bad + 1)); }
  fi
  if [ -n "$lsc_row" ] && [ -n "$P_LEDGER_PAT" ]; then
    IFS=' ' read -r -a LSPART <<<"$P_LEDGER_PAT"
    for j in docs/team/BOARD.md docs/team/ROADMAP.md docs/team/reports/X.md docs/team/tasks/X.md \
             docs/team/threads/dev.md docs/team/inbox/dev.md docs/team/reviews/X.md \
             docs/team/OWNERSHIP.md docs/team/DECISIONS.md; do
      covered=0
      for pp in "${LSPART[@]}"; do pat_match "$pp" "$j" && { covered=1; break; }; done
      if [ "$covered" = "0" ]; then
        cbad "ledger-scan 归属模式没有覆盖 $j（改这个路径不会选中它）"; lsc_bad=$((lsc_bad + 1))
      else
        lsc_n=$((lsc_n + 1))
      fi
    done
  fi
  [ "$lsc_bad" -eq 0 ] && cok "账本归属（ledger-scan $P_LEDGER_SCAN）声明有效：$lsc_n/9 个账本样例被它覆盖"

  # ⑧ gate-self-check 行（P326）：每个 key 命中恰好一行、不重复、不点名前导段。
  #    这一行是「哪些段不进普通入口」的唯一声明处（没点名 = 在地板里），所以一个拼错/陈旧的 key 会
  #    静静地把它指向的段换出普通的 CI —— 这一条就是它的静态牙。行不在不判红（整行删 = 每个段都在地板里，
  #    安全方向）；行在却一个 key 都没有则是空声明（--floor 会 die，这里点名）。
  local sc_bad=0 sc_n=0 sc_k sc_seen="" SCARR=()
  if [ "$P_SELF_DECLARED" != 1 ]; then
    cok "gate-self-check 行不在：每个段都在地板里（默认方向 = 多跑）"
  elif [ -z "$P_SELF_KEYS" ]; then
    cbad "gate-self-check 行在但没有点名任何段（空声明，$TSV:${P_SELF_LNS[*]}）—— --floor 会拒绝空地板"
    sc_bad=$((sc_bad + 1))
  else
    IFS=' ' read -r -a SCARR <<<"$P_SELF_KEYS"
    for sc_k in "${SCARR[@]}"; do
      [ -n "$sc_k" ] || continue
      sc_n=$((sc_n + 1))
      case " $sc_seen " in
        *" $sc_k "*) cbad "gate-self-check 行重复点名：$sc_k"; sc_bad=$((sc_bad + 1)); continue ;;
      esac
      sc_seen="${sc_seen}${sc_seen:+ }$sc_k"
      case " $P_PROLOGUE " in
        *" $sc_k "*) cbad "gate-self-check 行点名了前导段：$sc_k（前导段永远跑，不是可声明的自检段）"; sc_bad=$((sc_bad + 1)); continue ;;
      esac
      if [ -z "$(row_idx "$sc_k" || true)" ]; then
        cbad "gate-self-check 行点名了不存在的段：$sc_k（拼错/陈旧的 key 会静静地换掉普通入口）"
        sc_bad=$((sc_bad + 1))
      fi
    done
    [ "$sc_bad" -eq 0 ] && cok "gate-self-check 行有效（$sc_n 个 key：各自命中一行、无重复、不含前导段）"
  fi

  # ⑨ 分片（P346）：分片必须是地板的**精确划分**，且规则**只看 key**。具体 N 不在这一层：
  #    它抓的是「哈希退化成全落一片」与「按位置轮转」这两类形状；它证明不了「CI 真的跑了每一片」——
  #    那是 coverage 作业的事（它拿到的是各片真跑时的清单，不是这里的重算）。
  local sh_n=0 sh_i sh_sh sh_a sh_b sh_k FLOOR_N2=0
  local -a SH_NS=(2 3 4 5 6 8 12) SH_FK=() SH_CNT=()
  # 基线取地板的**声明集**（表里没被 gate-self-check 点名的行）：这就是「地板」的定义，不必为它
  # 展开耦合组（那要逐段 bash -n，秒级）；--floor 的运行集是这份声明再并前导与闭包。
  while IFS= read -r sh_k; do SH_FK+=("$sh_k"); done < <(declared_floor_keys)
  FLOOR_N2=${#SH_FK[@]}
  if [ "$FLOOR_N2" -eq 0 ]; then
    cbad "分片：地板为空（表里每一行都被 gate-self-check 点名）—— 分片无从断言"
  else
    # ① 对每个 N：每段恰好进一片（计数和 == 地板段数）、每片都非空
    local -a PER_N=()
    for sh_n in "${SH_NS[@]}"; do
      SH_CNT=()
      for ((sh_i = 0; sh_i < sh_n; sh_i++)); do SH_CNT[sh_i]=0; done
      for ((sh_i = 0; sh_i < FLOOR_N2; sh_i++)); do
        sh_k="${SH_FK[sh_i]}"
        sh_sh="$(slice_of_key "$sh_k" "$sh_i" "$sh_n")" || { PER_N+=("N=$sh_n：key $sh_k 算不出片号"); continue; }
        case "$sh_sh" in
          ''|*[!0-9]*) PER_N+=("N=$sh_n：key $sh_k 的片号不是数字（[$sh_sh]）"); continue ;;
        esac
        if [ "$sh_sh" -ge "$sh_n" ]; then PER_N+=("N=$sh_n：key $sh_k 的片号 $sh_sh 越界"); continue; fi
        SH_CNT[sh_sh]=$(( SH_CNT[sh_sh] + 1 ))
      done
      for ((sh_i = 0; sh_i < sh_n; sh_i++)); do
        [ "${SH_CNT[sh_i]}" -gt 0 ] || PER_N+=("N=$sh_n：第 $((sh_i + 1)) 片是空的（分片退化）")
      done
      local sh_sum=0
      for ((sh_i = 0; sh_i < sh_n; sh_i++)); do sh_sum=$((sh_sum + SH_CNT[sh_i])); done
      [ "$sh_sum" -eq "$FLOOR_N2" ] || PER_N+=("N=$sh_n：各片合计 $sh_sum ≠ 地板 $FLOOR_N2 段（有重复或遗漏）")
    done
    if [ "${#PER_N[@]}" -eq 0 ]; then
      cok "分片是地板的精确划分（N=${SH_NS[*]}：$FLOOR_N2 段，每片非空、无重复、无遗漏）"
    else
      cbad "分片不是地板的精确划分：${PER_N[0]}$( [ "${#PER_N[@]}" -gt 1 ] && printf '（共 %s 处，首条如上）' "${#PER_N[@]}" )"
    fi
    # ② 规则只看 key：同一个 key 在**任意**基线下标上片号都必须相同。
    #   参照点固定为 0 号位，**不是**镜像位置：以 `idx ↔ 末位-idx` 对称方式混进来的位置污染
    #   （V86 的变异 C）会同时满足镜像比较，只在「所有下标 vs 同一个参照」下露出来。
    #   覆盖面（这三条就是这条断言的全部比较范围，ok 行照抄）：
    #     (a) 表首 key 在**全部**基线下标 × 全部 N 上与 0 号位同片 —— 128 × 7 = 896 次比较；
    #     (b) 另 3 个 key（表中 / 表末 / 表倒数第二）各比首尾两点 × 全部 N；
    #     (c) 表里每个 key 各比首尾两点（N=4）。
    #   为什么不是「3 个 key × 全部下标」：`--check` 被 §36 调用 17 次，每次多 2000 次 fork 就是
    #   §36 多 5 分钟（实测 3-key 版本：§36 8→16 分钟）。全位置比较保住一条 key 就够抓实现层的位置泄漏。
    local -a POS_BAD=()
    local sh_ref sh_span=0 sh_n1=4
    if [ "$FLOOR_N2" -gt 0 ]; then
      sh_k="${SH_FK[0]}"
      for sh_n in "${SH_NS[@]}"; do
        sh_ref="$(slice_of_key "$sh_k" 0 "$sh_n")" || { POS_BAD+=("N=$sh_n：key $sh_k 算不出片号"); continue; }
        case "$sh_ref" in ''|*[!0-9]*) POS_BAD+=("N=$sh_n：key $sh_k 的片号不是数字（[$sh_ref]）"); continue ;; esac
        for ((sh_i = 1; sh_i < FLOOR_N2; sh_i++)); do
          sh_b="$(slice_of_key "$sh_k" "$sh_i" "$sh_n")" || { POS_BAD+=("N=$sh_n：key $sh_k 算不出片号"); continue; }
          sh_span=$(( sh_span + 1 ))
          [ "$sh_ref" = "$sh_b" ] || POS_BAD+=("N=$sh_n：key $sh_k 在 0 号位是第 $((sh_ref + 1)) 片、在第 $sh_i 位却是第 $((sh_b + 1)) 片")
        done
      done
    fi
    local -a POS_OTHERS=()
    [ "$FLOOR_N2" -lt 2 ] || POS_OTHERS+=("${SH_FK[$((FLOOR_N2 / 2))]}")
    [ "$FLOOR_N2" -lt 3 ] || POS_OTHERS+=("${SH_FK[$((FLOOR_N2 - 1))]}")
    [ "$FLOOR_N2" -lt 4 ] || POS_OTHERS+=("${SH_FK[$((FLOOR_N2 - 2))]}")
    for sh_n in "${SH_NS[@]}"; do
      for sh_k in "${POS_OTHERS[@]}"; do
        sh_ref="$(slice_of_key "$sh_k" 0 "$sh_n")" || { POS_BAD+=("N=$sh_n：key $sh_k 算不出片号"); continue; }
        sh_b="$(slice_of_key "$sh_k" "$((FLOOR_N2 - 1))" "$sh_n")" || { POS_BAD+=("N=$sh_n：key $sh_k 算不出片号"); continue; }
        [ "$sh_ref" = "$sh_b" ] || POS_BAD+=("N=$sh_n：key $sh_k 在第 0 位是第 $((sh_ref + 1)) 片、在末位却是第 $((sh_b + 1)) 片")
      done
    done
    if [ "$FLOOR_N2" -gt 1 ]; then
      for ((sh_i = 0; sh_i < FLOOR_N2; sh_i++)); do
        sh_k="${SH_FK[sh_i]}"
        sh_ref="$(slice_of_key "$sh_k" 0 "$sh_n1")" || { POS_BAD+=("N=$sh_n1：key $sh_k 算不出片号"); continue; }
        sh_b="$(slice_of_key "$sh_k" "$((FLOOR_N2 - 1))" "$sh_n1")" || { POS_BAD+=("N=$sh_n1：key $sh_k 算不出片号"); continue; }
        [ "$sh_ref" = "$sh_b" ] || POS_BAD+=("N=$sh_n1：key $sh_k 在第 0 位是第 $((sh_ref + 1)) 片、在末位却是第 $((sh_b + 1)) 片")
      done
    fi
    if [ "${#POS_BAD[@]}" -eq 0 ]; then
      cok "分片只依赖 key：(a) 表首 key 在全部 $FLOOR_N2 个基线下标 × ${#SH_NS[@]} 个 N 上与 0 号位同片（$sh_span 次比较）；(b) 另 ${#POS_OTHERS[@]} 个 key 各比首尾两点 × ${#SH_NS[@]} 个 N；(c) 每个 key 各比首尾两点（N=$sh_n1）—— 片号都不变，不等同于「所有 key × 所有位置」全比"
    else
      cbad "分片依赖了段在表里的位置（按位置轮转会让「第 k 片」随行的增删漂移）：${POS_BAD[0]}"
    fi
    # ③ 表里每一行的 key 都能被哈希（不是只在地板里）
    local -a HASH_BAD=()
    for ((sh_i = 0; sh_i < T_N; sh_i++)); do
      for sh_n in "${SH_NS[@]}"; do
        sh_sh="$(slice_of_key "${T_KEY[sh_i]}" "$sh_i" "$sh_n")" || { HASH_BAD+=("key ${T_KEY[sh_i]}（N=$sh_n）算不出片号"); break; }
        case "$sh_sh" in ''|*[!0-9]*) HASH_BAD+=("key ${T_KEY[sh_i]}（N=$sh_n）的片号不是数字（[$sh_sh]）"); break ;; esac
        [ "$sh_sh" -lt "$sh_n" ] || { HASH_BAD+=("key ${T_KEY[sh_i]}（N=$sh_n）的片号 $sh_sh 越界"); break; }
      done
    done
    if [ "${#HASH_BAD[@]}" -eq 0 ]; then
      cok "表里每一行的 key 都能被哈希（$T_N 个 key × ${#SH_NS[@]} 个 N 都在 0..N-1 内）"
    else
      cbad "有 key 哈希不到合法片号：${HASH_BAD[0]}"
    fi
  fi

  printf '== 选段自检 ==  ok %d  bad %d  SKIP %d\n' "$CHECK_OK" "$CHECK_BAD" "$CHECK_SKIP"
  [ "$CHECK_BAD" -eq 0 ] || return 1
  return 0
}

# ── main ────────────────────────────────────────────────────────────────────────────────
case "$MODE" in
  paths)          load_table; load_suite; do_paths ;;
  floor)          load_table; load_suite; do_floor ;;
  all)            load_table; load_suite; do_all ;;
  select)         load_table; load_suite; do_select ;;
  list)           load_table; do_list ;;
  check)          load_table; load_suite; do_check ;;
  verify-copies)  load_table; load_suite; do_verify_copies ;;
esac
