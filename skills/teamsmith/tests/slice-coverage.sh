#!/usr/bin/env bash
# slice-coverage.sh · CI 的 coverage 作业：各片 own 的并集必须**恰好**是这次决策的基线（P346）
#
# 为什么它是一个**独立作业**而不是矩阵里的一个步骤：`--slice k/N`（选择器）与 `--check ⑨`（静态）都只能
# 证明「规则今天没坏」，证明不了「N 片真的都跑了」。矩阵会因为 fail-fast、并发组、配额、取消而少片，
# 那是这套方案真正会丢覆盖的唯一入口 —— 只有拿各片**真跑时写出的清单**来对账才能发现它。
#
# 它做四件事（全部可执行，不读 YAML 的语义，不猜矩阵）：
#   ① N 与片号只从工作流矩阵读一次（matrix.slice 的**流动列表**，只允许一行）：N 的唯一来源是矩阵长度；
#   ② 逐片把清单与**自己的重算**逐字比对（重算 = 同一个选择器的同一条命令），某片静默收窄会在这里红；
#   ③ 各片 own 的并集 vs 基线（地板 ∪ 改动路径；没有 --paths 时是全集）：缺的段**逐个**进 ::error::；
#      同一段出现在两片的 own 里也算红（重复是覆盖的超集，但不许静默）；
#   ④ 任一片失败或被取消（`--shards-result` 不是 success）就红；缺清单的片按重算点名它 own 的段。
#
# 用法：
#   slice-coverage.sh --keys-dir <dir> --matrix-file <gates.yml> --shards-result <success|failure|cancelled|…>
#                     [--paths <改动路径>…] [--selector <section-select.sh>]
# 退出码：0 = 并集恰好等于基线且每片与重算一致；1 = 有不成立项（逐条 ::error:: 点名）；2 = 用法/前提错。
#
# 本地也能跑（对着一个假 keys 目录）：这就是「某片被取消」这类形状的翻面证据所在，不必真跑 CI。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYS_DIR=""
MATRIX_FILE=""
SHARDS_RESULT=""
PATH_ARGS=(); HAVE_PATHS=0
SELECTOR="$SELF_DIR/section-select.sh"
die() { printf 'slice-coverage: %s\n' "$*" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --keys-dir) shift; [ $# -gt 0 ] || die "--keys-dir 需要目录"; KEYS_DIR="$1"; shift ;;
    --matrix-file) shift; [ $# -gt 0 ] || die "--matrix-file 需要文件"; MATRIX_FILE="$1"; shift ;;
    --shards-result) shift; [ $# -gt 0 ] || die "--shards-result 需要作业结果"; SHARDS_RESULT="$1"; shift ;;
    --selector) shift; [ $# -gt 0 ] || die "--selector 需要文件"; SELECTOR="$1"; shift ;;
    --paths)
      HAVE_PATHS=1; shift
      [ $# -gt 0 ] || die "--paths 需要至少一条路径"
      while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do PATH_ARGS+=("$1"); shift; done ;;
    -h|--help) sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "未知参数 $1（用法见 --help）" ;;
  esac
done
[ -n "$KEYS_DIR" ] || die "缺 --keys-dir（各片 .keys 的目录）"
[ -n "$MATRIX_FILE" ] || die "缺 --matrix-file（工作流：矩阵长度的唯一来源）"
[ -n "$SHARDS_RESULT" ] || die "缺 --shards-result（门禁矩阵的作业结果：不是 success 就必须红）"
[ -r "$MATRIX_FILE" ] || die "读不到工作流：$MATRIX_FILE"
[ -f "$SELECTOR" ] || die "读不到选择器：$SELECTOR"

C_OK=0; C_BAD=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$*"; C_OK=$((C_OK + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$*"; C_BAD=$((C_BAD + 1)); }
# 缺的段要能被 CI 的注释区直接看到：一条一个 ::error::（读者不必打开日志去数）。
ann() { printf '::error::%s\n' "$*"; }

# ── ① 矩阵：N 与片号（唯一来源）────────────────────────────────────────────────────────────
# 只认矩阵里那一行 `slice: [1, 2, 3, 4]`（流动列表）。找不到 / 找到多行 / 元素不是整数 / 不是 1..N ——
# 一律红并停：N 与片号解析不出来时，「并集等于基线」这句话就没有定义，猜一个只会把红说成绿。
mapfile -t _slice_lines < <(grep -nE '^[[:space:]]+slice:[[:space:]]*\[' "$MATRIX_FILE" || true)
if [ "${#_slice_lines[@]}" -ne 1 ]; then
  ann "工作流里的 slice 矩阵行必须恰好一行（在 $MATRIX_FILE 找到 ${#_slice_lines[@]} 行）—— N 的唯一来源是矩阵长度，解析不出来就不猜"
  printf '== 分片覆盖 == ok 0 bad 1\n'
  exit 1
fi
SLICE_LINE_NO="${_slice_lines[0]%%:*}"
SLICE_RAW="$(sed -n "${SLICE_LINE_NO}p" "$MATRIX_FILE" | sed 's/^[[:space:]]*slice:[[:space:]]*\[\(.*\)\].*$/\1/')"
SHARD_IDS=()
while IFS= read -r _v; do
  _v="${_v//[[:space:]]/}"
  [ -n "$_v" ] || continue
  SHARD_IDS+=("$_v")
done < <(printf '%s\n' "$SLICE_RAW" | tr ',' '\n')
N="${#SHARD_IDS[@]}"
SHARD_BAD=0
[ "$N" -ge 1 ] || { ann "矩阵 slice 列表是空的（$MATRIX_FILE:$SLICE_LINE_NO）—— 没有片就没有覆盖"; SHARD_BAD=1; }
_seen=""
for _id in "${SHARD_IDS[@]}"; do
  case "$_id" in ''|*[!0-9]*) ann "矩阵 slice 元素不是正整数：[$_id]（$MATRIX_FILE:$SLICE_LINE_NO）"; SHARD_BAD=1; continue ;; esac
  [ "$_id" -ge 1 ] && [ "$_id" -le "$N" ] || { ann "矩阵 slice 元素 $_id 不在 1..$N 里（选择器只接受 1 ≤ k ≤ N）"; SHARD_BAD=1; }
  case " $_seen " in *" $_id "*) ann "矩阵 slice 元素重复：$_id"; SHARD_BAD=1 ;; esac
  _seen="$_seen $_id"
done
unset _seen _id _v
if [ "$SHARD_BAD" -ne 0 ]; then
  printf '== 分片覆盖 == ok 0 bad 1\n'
  exit 1
fi
printf '  · 矩阵：%s 片（%s）← %s:%s\n' "$N" "${SHARD_IDS[*]}" "$MATRIX_FILE" "$SLICE_LINE_NO"

# ── ④ 作业结果：任一片失败/被取消 → 红（清单对账照旧跑，读者能同时看到缺的是哪几段）────────────
if [ "$SHARDS_RESULT" != "success" ]; then
  ann "门禁矩阵的结果是 [$SHARDS_RESULT]（不是 success）：任一片失败或被取消，这条覆盖断言就必须红"
  bad "门禁矩阵结果 [$SHARDS_RESULT] ≠ success"
else
  ok "门禁矩阵 ${N} 片全部成功（--shards-result success）"
fi

# ── 基线与各片的重算（同一个选择器、同一条命令）────────────────────────────────────────────
sel() { bash "$SELECTOR" "$@"; }
BASE_ARGS=()
[ "$HAVE_PATHS" = 0 ] || BASE_ARGS=(--floor --paths "${PATH_ARGS[@]}")
# 基线 = 同一决策下的「单片」：--slice 1/1 的 own 就是这条决策的完整集合（与各片切片用的是同一条规则）。
base_out="$(sel "${BASE_ARGS[@]}" --slice 1/1 2>&1)" || {
  printf '%s\n' "$base_out" | sed 's/^/    /' >&2
  ann "基线算不出来（选择器退非 0）：${BASE_ARGS[*]:-<无决策：全集>}"
  printf '== 分片覆盖 == ok %d bad %d\n' "$C_OK" "$((C_BAD + 1))"
  exit 1
}
BASE_KEYS=()
while IFS= read -r _k; do BASE_KEYS+=("$_k"); done \
  < <(printf '%s\n' "$base_out" | sed -n 's/^own-key=//p')
[ "${#BASE_KEYS[@]}" -gt 0 ] || {
  ann "基线是空的（选择器没给出任何 own 段）：${BASE_ARGS[*]:-<无决策：全集>}"
  printf '== 分片覆盖 == ok %d bad %d\n' "$C_OK" "$((C_BAD + 1))"
  exit 1
}
ok "基线：${#BASE_KEYS[@]} 段（$([ "$HAVE_PATHS" = 0 ] && printf '全集，基点不可解析的兜底' || printf '地板 ∪ 改动路径')）"

# ── ②③ 逐片：清单 == 重算；并集 == 基线；跨片不许重复 ─────────────────────────────────────
UNION_FILE="$(mktemp "${TMPDIR:-/var/tmp}/slice-coverage-union.XXXXXX")" || die "建不了临时文件"
SEEN_FILE="$(mktemp "${TMPDIR:-/var/tmp}/slice-coverage-seen.XXXXXX")" || die "建不了临时文件"
# P346/F4：整片缺清单时它 own 的段已经在「片级 1 条 + 一个段落组」里点过名了，并集那一层不再逐段重复。
GROUPED_FILE="$(mktemp "${TMPDIR:-/var/tmp}/slice-coverage-grouped.XXXXXX")" || die "建不了临时文件"
trap 'rm -f "$UNION_FILE" "$SEEN_FILE" "$GROUPED_FILE"' EXIT
: > "$UNION_FILE"; : > "$SEEN_FILE"; : > "$GROUPED_FILE"

if [ ! -d "$KEYS_DIR" ]; then
  ann "各片清单的目录不存在：$KEYS_DIR（download-artifact 没拿到任何一片）"
  bad "清单目录不存在：$KEYS_DIR"
fi

for _id in "${SHARD_IDS[@]}"; do
  _keyfile="$KEYS_DIR/shard-$_id.keys"
  _status="?"; [ -r "$KEYS_DIR/shard-$_id.status" ] && _status="$(tr -d '[:space:]' < "$KEYS_DIR/shard-$_id.status")"
  _out="$(sel "${BASE_ARGS[@]}" --slice "$_id/$N" 2>&1)" || {
    printf '%s\n' "$_out" | sed 's/^/    /' >&2
    ann "片 $_id/$N 的重算退非 0（选择器拒绝这条命令）"
    bad "片 $_id/$N：重算失败"
    continue
  }
  EXPECT_FILE="$(mktemp "${TMPDIR:-/var/tmp}/slice-coverage-expect-$_id.XXXXXX")" || die "建不了临时文件"
  printf '%s\n' "$_out" | sed -n 's/^own-key=//p' > "$EXPECT_FILE"
  _n_expect="$(grep -c . "$EXPECT_FILE" || true)"
  if [ ! -r "$_keyfile" ]; then
    # 被取消的那一片：**片级 1 条 + 一个段落组**（P346/F4）。逐段各发一条会把 31 段变成 31 条注释，
    # 读者要的不是 31 行，而是「哪一片整片没跑、它的份额是哪些段」。
    ann "片 $_id/$N（作业结果 [$_status]）：整片缺清单（$_keyfile）—— 它 own 的 $_n_expect 段这次没有任何片跑到"
    _grp="$(tr '\n' ' ' < "$EXPECT_FILE" | sed 's/ *$//')"
    [ -z "$_grp" ] || ann "片 $_id/$N 的份额（整组 $_n_expect 段）：$_grp"
    cat "$EXPECT_FILE" >> "$GROUPED_FILE"
    bad "片 $_id/$N：缺清单（作业结果 [$_status]），$_n_expect 段没有跑到"
    rm -f "$EXPECT_FILE"
    continue
  fi
  if cmp -s "$EXPECT_FILE" "$_keyfile"; then
    ok "片 $_id/$N：清单与重算逐字一致（$_n_expect 段 · 作业结果 [$_status]）"
  else
    _got_n="$(grep -c . "$_keyfile" || true)"
    _first="$(diff "$EXPECT_FILE" "$_keyfile" | sed -n 's/^[<>] //p' | head -1)"
    ann "片 $_id/$N：清单与重算不一致（规则算 $_n_expect 段，清单 $_got_n 段；首个差异 ${_first:-行序不同}）—— 某片静默收窄会让并集对上、覆盖对不上"
    bad "片 $_id/$N：清单 ≠ 重算（$_n_expect vs $_got_n）"
  fi
  # 跨片重复：同一段落在两片的 own 里 = 有一片没跑到本该属于它的份额（重复是超集，但不许静默）
  while IFS= read -r _k; do
    [ -n "$_k" ] || continue
    if cut -f2 "$SEEN_FILE" | grep -qxF "$_k"; then
      _who="$(grep -F $'\t'"$_k" "$SEEN_FILE" | head -1 | cut -f1)"
      ann "段 [$_k]：同时出现在片 ${_who:-?} 与片 $_id 的 own 清单里（同段重复 ≠ 覆盖）"
      bad "段 [$_k] 出现在两片"
    fi
    printf '%s\t%s\n' "$_id" "$_k" >> "$SEEN_FILE"
    printf '%s\n' "$_k" >> "$UNION_FILE"
  done < "$_keyfile"
  rm -f "$EXPECT_FILE"
done

# 并集 vs 基线：缺的段逐个点名（这是「某片被取消」最直接的读者信号）
sort -u "$UNION_FILE" > "$UNION_FILE.sorted"
printf '%s\n' "${BASE_KEYS[@]}" | sort -u > "$UNION_FILE.base"
MISSING="$(comm -13 "$UNION_FILE.sorted" "$UNION_FILE.base")"
EXTRA="$(comm -23 "$UNION_FILE.sorted" "$UNION_FILE.base")"
_n_union="$(grep -c . "$UNION_FILE.sorted" || true)"
if [ -n "$MISSING" ]; then
  _n_missing="$(printf '%s\n' "$MISSING" | grep -c . || true)"
  # 分两拨：已被「整片缺清单」按组点名的（只汇总一行）与真正没人认领的（逐段点名）。
  _UNEXPLAINED="$(printf '%s\n' "$MISSING" | grep -vxF -f "$GROUPED_FILE" || true)"
  _n_explained=$(( _n_missing - $(printf '%s\n' "$_UNEXPLAINED" | grep -c . || true) ))
  if [ "$_n_explained" -gt 0 ]; then
    ann "并集缺 $_n_explained 段，全部来自上面「整片缺清单」的那些片（已按片成组点名，这里不重复）"
  fi
  while IFS= read -r _k; do [ -n "$_k" ] || continue; ann "段 [$_k]：没有任何一片 own 它（这次运行的覆盖缺口）"; done <<< "$_UNEXPLAINED"
  bad "并集缺 $_n_missing 段（基线 ${#BASE_KEYS[@]} 段，并集 $_n_union 段）"
elif [ -n "$EXTRA" ]; then
  while IFS= read -r _k; do [ -n "$_k" ] || continue; ann "段 [$_k]：清单里有，但不在这次决策的基线里（清单不是基线的子集）"; done <<< "$EXTRA"
  bad "并集多出 $(printf '%s\n' "$EXTRA" | grep -c . || true) 段（不是基线的子集）"
else
  # 「无重复」不在这里说：跨片重复由上面逐条判红并点名，这一行只负责「没有遗漏」这个断言。
  ok "并集 == 基线（$_n_union 段 = ${N} 片 own 的去重并集；无遗漏）"
fi
printf '  · 各片 own：%s\n' "$(sort "$SEEN_FILE" | awk -F'\t' '{c[$1]++} END{for (k in c) printf "片 %s=%s 段  ", k, c[k]}')"
rm -f "$UNION_FILE.sorted" "$UNION_FILE.base"

printf '== 分片覆盖 == ok %d bad %d\n' "$C_OK" "$C_BAD"
[ "$C_BAD" -eq 0 ] || exit 1
exit 0
