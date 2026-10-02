#!/usr/bin/env bash
# teamsmith · P156 翻转夹具：26-c 的归一化守卫 —— 只归一实时读数，结构照旧逐字节比
#
#   bash skills/teamsmith/tests/flip-p156.sh            # 三面：当前绿 / 旧归一化红 / 掏空的归一化红
#   bash skills/teamsmith/tests/flip-p156.sh --keep     # 保留临时根与三份日志
#   TEAM_FLIP_BASE=<sha> bash …/flip-p156.sh            # 自选基线（默认 merge-base HEAD main = 修复前）
#
# 三面跑**同一份** 26-c 聚焦探针（smoke 前导 + 26 段到 26-c；假 tmux，不碰真 session），只差 p10_norm：
#   ① current → 绿：绿侧（只动实时读数的数值 → 归一后逐字节相同）与红侧（动字段名/行数/ESC/分隔符/
#                单位 → 必须仍然不同）都成立；
#   ② base    → 红，且必须红在**绿侧**（修复前的口径把实时读数当内容比：第二段采样必然不同）；
#   ③ gutted  → 红，且必须红在**红侧**（把归一化掏空成恒等 → 结构差异也被吃掉 → 守卫没有牙）。
# 翻转证明的是「守卫真的在测这次修的那件事」：不是把断言改红，也不是让断言空跑。
#
# 只读 git（`git show BASE:…smoke.sh`）；只写 /tmp 下的临时根；探针 EXIT 时自己收干净。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$SELF_DIR/lib/tmp-root.sh"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { printf 'flip-p156: 找不到 git 仓库\n' >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { printf 'flip-p156: 需要 python3（拼接 p10_norm）\n' >&2; exit 2; }

KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --keep) KEEP=1; shift ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) printf 'flip-p156: 未知参数 %s\n' "$1" >&2; exit 2 ;;
  esac
done
[ "$KEEP" = "1" ] && export TEAM_TMP_KEEP=1
TMP="$(tmp_root_create flip-p156)" || exit 3
cleanup() { [ "${BASHPID:-$$}" = "$$" ] && [ "$KEEP" = "0" ] && tmp_root_reap_all; }
trap cleanup EXIT

CUR_SMOKE="$SKILL_DIR/tests/smoke.sh"
[ -f "$CUR_SMOKE" ] || { printf 'flip-p156: 找不到 %s\n' "$CUR_SMOKE" >&2; exit 2; }
BASE="${TEAM_FLIP_BASE:-}"
[ -n "$BASE" ] || BASE="$(git -C "$REPO_ROOT" merge-base HEAD main 2>/dev/null || true)"
[ -n "$BASE" ] || BASE="$(git -C "$REPO_ROOT" rev-parse --verify -q HEAD^ 2>/dev/null || true)"
[ -n "$BASE" ] || { printf 'flip-p156: 解析不到修复前的 revision，用 TEAM_FLIP_BASE=<sha> 指定\n' >&2; exit 2; }
git -C "$REPO_ROOT" show "$BASE:skills/teamsmith/tests/smoke.sh" > "$TMP/smoke-base.sh" 2>/dev/null \
  || { printf 'flip-p156: %s 里没有 smoke.sh\n' "$BASE" >&2; exit 2; }
sed -n '/^p10_norm()/,/^}/p' "$TMP/smoke-base.sh" > "$TMP/norm-base.sh"
[ -s "$TMP/norm-base.sh" ] || { printf 'flip-p156: 基线 %s 里没有 p10_norm\n' "$BASE" >&2; exit 2; }
if grep -q 'RAM|swap' "$TMP/norm-base.sh"; then
  printf 'flip-p156: BASE（%s）已经含 P156 的归一化（不是修复前的树）——用 TEAM_FLIP_BASE=<修复前的 sha>\n' "$BASE" >&2
  exit 2
fi
grep -q 'RAM|swap' "$CUR_SMOKE" || { printf 'flip-p156: 当前树没有 P156 的归一化（先跑修复）\n' >&2; exit 2; }
printf 'p10_norm() { :; }\n' > "$TMP/norm-gutted.sh"

# 探针 = 前导（身份隔离 / 锁 / 临时根 / helpers）+ 26 段到 26-c；SKILL_DIR 指向当前树（产品代码不变）
build_probe() { # <src-smoke> <out>
  local src="$1" out="$2"
  {
    awk '/^# -+ 0\. 仓库/{exit} {print}' "$src"
    printf '\n# —— 26-c 聚焦探针（P156）——\n'
    awk '/^section "26 · 面板（pulse-tui-panel/{f=1} /^# -+ 26-d\. --json/{exit} f{print}' "$src"
  } | sed "s|^SKILL_DIR=.*|SKILL_DIR=\"$SKILL_DIR\"|" > "$out"
  cat >> "$out" <<'EOS'
section "15 · 完成（26-c 聚焦探针）"
printf '\n== 结果 ==  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0
exit 1
EOS
}
splice_norm() { # <probe> <replacement-file>：把探针里的 p10_norm 定义整块换掉（必须正好一处）
  python3 - "$1" "$2" <<'PY'
import sys
probe, repl = sys.argv[1], sys.argv[2]
lines = open(probe, encoding='utf-8').read().split('\n')
new = open(repl, encoding='utf-8').read().rstrip('\n').split('\n')
out, i, hit = [], 0, 0
while i < len(lines):
    if lines[i].startswith('p10_norm() {'):
        j = i
        while j < len(lines) and lines[j] != '}':
            j += 1
        out.extend(new); hit += 1; i = j + 1; continue
    out.append(lines[i]); i += 1
open(probe, 'w', encoding='utf-8').write('\n'.join(out))
sys.exit(0 if hit == 1 else 1)
PY
}
probe_run() { # <tag> <replacement|-> <log> → rc（探针是夹具：假 tmux + 私有临时根，不排机器锁）
  local tag="$1" repl="$2" log="$3"
  local p="$TMP/probe-$tag.sh"
  build_probe "$CUR_SMOKE" "$p" || return 3
  if [ "$repl" != "-" ]; then
    splice_norm "$p" "$repl" || { printf 'flip-p156: %s：p10_norm 没被替换\n' "$tag" >&2; return 3; }
  fi
  TEAM_SMOKE_NO_LOCK=1 bash "$p" > "$log" 2>&1
  return $?
}
plain() { sed 's/\x1b\[[0-9;]*m//g' "$1"; }
reds() { plain "$1" | grep -a '^  ✗' | sed 's/^  ✗ //'; }
result_line() { plain "$1" | grep -a '== 结果 ==' | tail -1; }

printf 'P156 翻转：同一份 26-c 探针，只差 p10_norm 的实现\n  BASE=%s\n  当前=%s\n' "$BASE" "$CUR_SMOKE"
fails=0
probe_run current -                    "$TMP/current.log"; crc=$?
probe_run base    "$TMP/norm-base.sh"  "$TMP/base.log";    brc=$?
probe_run gutted  "$TMP/norm-gutted.sh" "$TMP/gutted.log"; grc=$?

printf '① 当前（修复后）：rc=%s %s\n' "$crc" "$(result_line "$TMP/current.log")"
reds "$TMP/current.log" | sed 's/^/    /'
[ "$crc" -eq 0 ] || { printf '✗ 修复不成立：当前树在 26-c 探针上红了（看 %s）\n' "$TMP/current.log" >&2; fails=1; }

printf '② 旧归一化（BASE）：rc=%s %s\n' "$brc" "$(result_line "$TMP/base.log")"
reds "$TMP/base.log" | sed 's/^/    /'
if [ "$brc" -ne 0 ] && reds "$TMP/base.log" | grep -qF '26-c P156 绿侧'; then
  printf '✓ 旧口径红在绿侧（把实时读数当内容比）\n'
else
  printf '✗ 旧口径没有红在绿侧 —— 翻转指错了地方（看 %s）\n' "$TMP/base.log" >&2; fails=1
fi

printf '③ 掏空的归一化：rc=%s %s\n' "$grc" "$(result_line "$TMP/gutted.log")"
reds "$TMP/gutted.log" | sed 's/^/    /'
if [ "$grc" -ne 0 ] && reds "$TMP/gutted.log" | grep -qF '26-c P156 红侧'; then
  printf '✓ 掏空归一化时红侧失败（守卫不是空跑的绿）\n'
else
  printf '✗ 掏空归一化后红侧没有失败 —— 守卫没有牙（看 %s）\n' "$TMP/gutted.log" >&2; fails=1
fi

printf 'flip-p156: 日志 %s（当前）/ %s（旧）/ %s（掏空）\n' "$TMP/current.log" "$TMP/base.log" "$TMP/gutted.log"
[ "$KEEP" = "1" ] || printf 'flip-p156: （--keep 可保留现场）\n'
if [ "$fails" = "0" ]; then printf 'flip-p156: 翻转成立（当前绿 → 旧口径红在绿侧 → 掏空红在红侧）\n'; exit 0; fi
printf 'flip-p156: 翻转不成立\n' >&2
exit 1
