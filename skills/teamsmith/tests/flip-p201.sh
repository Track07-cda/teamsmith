#!/usr/bin/env bash
# flip-p201.sh — P201（发送者身份：主检出 + 席位线索必须**拒绝**）的翻转包。
#
#   bash skills/teamsmith/tests/flip-p201.sh
#   bash skills/teamsmith/tests/flip-p201.sh --keep     # 保留临时目录（排查）
#
# 事故（P155 实测，PM 读码定位到 team_sender_from_dir）：worker 的 cwd 落在**主检出**里时，旧实现直接
# 返回 `pm` —— 不看任何会话线索、零告警、与 PM 自己的合法调用逐字节相同。账本记的是**作者**，所以
# P201 的裁定是「主检出 + 本名册的席位线索 → 拒绝」，只有无线索的主检出才是 PM 自己。
#
# P205 把 P204 delta 的新 scenario 变成红侧：影子共四个，各在 /tmp 的技能树副本里只改一处 ——
#   A 冲突判定永不成立（主检出 + 线索照旧 pm）：①② 的拒绝断言必须变红，③ 全部仍绿（对照）；
#   B 去掉名册过滤（任何非空窗口名 / TEAM_AGENT 都算线索）：③d/③e（名册外名字）必须变红，①② 仍拒绝；
#   C 把冲突拒绝挪到显式 --from 之前（声明不再优先）：③g 必须变红，无线索 / 名册外 / 席位工作树仍绿；
#   D 去掉拒绝的目录前提（任何目录 + 线索都拒）：③f（席位工作树 + 名册线索）必须变红。
# 每个影子先证明变异命中锚点一次、语法仍合法，再跑聚焦探针（smoke 前导 + §47 + 结果行），点到预期的
# 红行；随后还原，§47 必须全绿 —— 红（变异）与绿（还原）两侧都要有。
#
# 退出码：0 = 影子与还原两面对上；1 = 有反例；3 = 前置不满足（探针/树形状不对）。
# 安全性：探针只跑 §47（纯逻辑 + 假 tmux shim + 自己的临时仓库），不碰真实 tmux；本脚本自己也**不**调 tmux。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$SELF_DIR/lib/tmp-root.sh"
SMOKE="$SKILL_DIR/tests/smoke.sh"

KEEP=0
case "${1:-}" in
  "") ;;
  --keep) KEEP=1 ;;
  # 头注到 set 之前（头注长度改过也不用手工对行号）
  -h|--help) sed -n '2,/^set -uo pipefail/p' "$0" | sed '$d'; exit 0 ;;
  *) printf 'flip-p201: 未知参数 %s\n' "$1" >&2; exit 2 ;;
esac

[ -s "$SMOKE" ] || { printf 'flip-p201: 缺 %s\n' "$SMOKE" >&2; exit 3; }
grep -q '^section "47 ' "$SMOKE" || { printf 'flip-p201: smoke.sh 里没有 47 段（notify 发送者夹具）\n' >&2; exit 3; }
grep -q 'P201 ① 主检出 + 窗口 dev' "$SMOKE" || { printf 'flip-p201: smoke.sh 里没有 P201 的断言（先做夹具）\n' >&2; exit 3; }
grep -q 'team_sender_seat_clues' "$SKILL_DIR/scripts/lib/common.sh" \
  || { printf 'flip-p201: 本树没有 P201 的实现（team_sender_seat_clues）——先做修复\n' >&2; exit 3; }
grep -q 'P201 ③ 名册外的窗口名' "$SMOKE" || { printf 'flip-p201: smoke.sh 里没有 ③d–③g（P205 的夹具还没加）\n' >&2; exit 3; }

[ "${KEEP:-0}" = "1" ] && export TEAM_TMP_KEEP=1
TMP="$(tmp_root_create flip-p201)" || exit 3
cleanup() { [ "${BASHPID:-$$}" = "$$" ] || return 0; [ "$KEEP" = "1" ] || tmp_root_reap_all; return 0; }
trap cleanup EXIT

TREE="$TMP/tree"; mkdir -p "$TREE/skills"
cp -a "$SKILL_DIR" "$TREE/skills/teamsmith"
MUT_SKILL="$TREE/skills/teamsmith"

PASS=0
FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }

restore_skill() { rm -rf "$MUT_SKILL"; cp -a "$SKILL_DIR" "$MUT_SKILL"; }
# 去色后的 ✗ 行落成文件（P202 的教训：pipefail 下 `… | grep -q` 的早退会让 sed 吃 SIGPIPE，
# 把「匹配到」读成「没匹配到」——判据不许走管道，一律先落盘再 grep 文件）。
red_file() { local f="$1.red"; sed 's/\x1b\[[0-9;]*m//g' "$1" 2>/dev/null | grep '✗' > "$f" || true; printf '%s\n' "$f"; }
show_red() { sed -n '1,12p' "$(red_file "$1")" | sed 's/^/      /'; }

# require_red/require_green：红侧必须点到这些断言；绿侧这些断言一行都不许红。
require_red() { # <log> <描述> <pattern...>
  local log="$1" desc="$2"; shift 2
  local miss="" pat reds; reds="$(red_file "$log")"
  for pat in "$@"; do
    grep -qE -- "$pat" "$reds" || miss="$miss [$pat]"
  done
  if [ -z "$miss" ]; then ok "$desc"; else bad "$desc —— 没点到$miss"; show_red "$log"; fi
}
require_green() { # <log> <描述> <pattern...>
  local log="$1" desc="$2"; shift 2
  local hit="" pat reds; reds="$(red_file "$log")"
  for pat in "$@"; do
    grep -qE -- "$pat" "$reds" && hit="$hit [$pat]"
  done
  if [ -z "$hit" ]; then ok "$desc"; else bad "$desc —— 不该红的红了$hit"; show_red "$log"; fi
}

# ── 聚焦探针：smoke 前导 + 47 段 + 结果行（SKILL_DIR 换成被测的树）─────────────────────────────
PROBE="$TMP/probe-47.sh"
{
  awk '/^# -+ 0\. 仓库/{exit} {print}' "$SMOKE"
  awk '/^section "47 /{f=1} f{ if ($0 ~ /^section "/ && $0 !~ /^section "47 /) exit; print }' "$SMOKE"
  cat <<'EOS'
printf '\n== 结果 ==  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
printf 'PROBE-47-END\n'
[ "$FAIL" -eq 0 ] && exit 0
exit 1
EOS
} | sed "s|^SKILL_DIR=.*|SKILL_DIR=\"$MUT_SKILL\"|" > "$PROBE"
grep -q 'PROBE-47-END' "$PROBE" || { printf 'flip-p201: 探针形状不对（47 段没抽出来？）\n' >&2; exit 3; }
grep -q 'P201 ① 主检出 + 窗口 dev' "$PROBE" || { printf 'flip-p201: 探针里没有 P201 的断言\n' >&2; exit 3; }
bash -n "$PROBE" || { printf 'flip-p201: 探针语法错\n' >&2; exit 3; }

run_probe() { # <日志>
  TEAM_SMOKE_FAST=1 TEAM_SMOKE_NO_LOCK=1 bash "$PROBE" >"$1" 2>&1
  return $?
}

# ── 变异体（每个只改一处；python 里 count==1 是锚点契约：文本一漂就以「变异脚本失败」报错，不假装）──
mut_A() { # A：冲突分支永不成立 → 主检出 + 线索照旧 pm（P201 的反面）
  python3 - "$MUT_SKILL" <<'PY'
import io, sys
p = sys.argv[1] + '/scripts/lib/common.sh'
s = io.open(p, encoding='utf-8').read()
old = '  if [ "$dir" = "pm" ] && team_sender_is_main_checkout; then\n'
assert s.count(old) == 1, ('P201 anchor', s.count(old))
s = s.replace(old,
              '  if false; then   # MUTATION p201-A: the conflict refusal is gone (the main checkout is "pm" again)\n',
              1)
io.open(p, 'w', encoding='utf-8').write(s)
PY
}

mut_B() { # B：去掉名册过滤 → 任何非空窗口名 / TEAM_AGENT 都算线索
  python3 - "$MUT_SKILL" <<'PY'
import io, sys
p = sys.argv[1] + '/scripts/lib/common.sh'
s = io.open(p, encoding='utf-8').read()
pairs = [
    ('&& team_agent_known "$w"; then',
     '&& [ -n "$w" ]; then   # MUTATION p201-B: the roster filter is gone'),
    ('  if [ -n "$a" ] && team_agent_known "$a"; then',
     '  if [ -n "$a" ]; then   # MUTATION p201-B: the roster filter is gone'),
]
for old, new in pairs:
    assert s.count(old) == 1, ('p201-B anchor', old, s.count(old))
    s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8').write(s)
PY
}

mut_C() { # C：把冲突拒绝挪到显式 --from 分支之前（声明不再优先）
  python3 - "$MUT_SKILL" <<'PY'
import io, sys
p = sys.argv[1] + '/scripts/lib/common.sh'
s = io.open(p, encoding='utf-8').read()
claim_start = s.index('  if [ -n "$claim" ]; then\n')
claim_end = s.index('  if [ -z "$dir" ]; then\n', claim_start)
p201_start = s.index('  # P201：主检出（目录声称 pm）+ 本名册的席位线索')
p201_end = s.index('  # 继承来的 TEAM_AGENT（dispatch/install 都不设它）', p201_start)
assert claim_start < claim_end < p201_start < p201_end, ('p201-C anchors', claim_start, claim_end, p201_start, p201_end)
claim = s[claim_start:claim_end]
p201 = s[p201_start:p201_end]
s = (s[:claim_start] + p201
     + '  # MUTATION p201-C: the conflict refusal now runs above the --from claim\n'
     + claim + s[claim_end:])
io.open(p, 'w', encoding='utf-8').write(s)
PY
}

mut_D() { # D：去掉拒绝的目录前提（任何目录 + 线索 → 拒绝；比 trait 宽，只看新断言是否红）
  python3 - "$MUT_SKILL" <<'PY'
import io, sys
p = sys.argv[1] + '/scripts/lib/common.sh'
s = io.open(p, encoding='utf-8').read()
old = '  if [ "$dir" = "pm" ] && team_sender_is_main_checkout; then\n'
assert s.count(old) == 1, ('p201-D anchor', s.count(old))
s = s.replace(old,
              "  if true; then   # MUTATION p201-D: the refusal's directory precondition is gone\n",
              1)
io.open(p, 'w', encoding='utf-8').write(s)
PY
}

# ── 各影子的红/绿判据（只在对应日志上判）────────────────────────────────────────────────────
check_A_red() {
  require_red "$1" "影子 A：红侧点在 ①② 的预期断言上（7 条）" \
    'P201 ① 主检出 \+ 窗口 dev 应当拒绝' \
    'P201 ① 拒绝时零写入' \
    'P201 ① 拒绝输出点名线索说的名字（dev）' \
    'P201 ① 拒绝输出给出出路：--from' \
    'P201 ② 主检出 \+ TEAM_AGENT=dev 应当拒绝' \
    'P201 ② 拒绝时零写入' \
    'P201 ② 拒绝输出点名线索说的名字（TEAM_AGENT dev）'
}
check_A_green() { require_green "$1" "影子 A：③ 全部仍绿（窗口 pm / 无线索 / 别的会话 / 名册外 / 席位工作树 / --from）" 'P201 ③'; }

check_B_red() {
  require_red "$1" "影子 B：名册过滤被拿掉后 ③d/③e（名册外名字）的断言变红" \
    'P201 ③ 名册外的窗口名' \
    'P201 ③ 名册外的 TEAM_AGENT'
}
check_B_green() { require_green "$1" "影子 B：①② 仍拒绝（红的是名册过滤，不是拒绝机制本身）" 'P201 ①' 'P201 ②'; }

check_C_red() {
  require_red "$1" "影子 C：拒绝挪到声明之前后 ③g（--from 带线索）的断言变红" \
    'P201 ③ 带线索的显式 --from 被拒' \
    'P201 ③ 显式 --from 原样记录'
}
check_C_green() { require_green "$1" "影子 C：无线索 / 名册外 / 席位工作树 / 窗口 pm / 别的会话仍绿" \
    'P201 ③ 名册外的' 'P201 ③ 席位工作树' 'P201 ③ 窗口 pm 与目录一致' 'P201 ③ 无线索的主检出' 'P201 ③ 别的会话'; }

check_D_red() {
  require_red "$1" "影子 D：目录前提被拿掉后 ③f（席位工作树 + 名册线索）的断言变红" \
    'P201 ③ 席位工作树'
}
check_D_green() { require_green "$1" "影子 D：①② 仍拒绝、③g 声明仍胜（变异只放宽目录前提）" 'P201 ①' 'P201 ②' 'P201 ③ 显式 --from'; }

# ── 影子驱动：变异 → 红探针 → 判据 → 还原 → 绿探针 ─────────────────────────────────────────
run_shadow() { # <id> <mutator> <变异描述> <红判据> <绿判据>
  local id="$1" mut="$2" mdesc="$3" redcheck="$4" greencheck="$5" rc f
  restore_skill
  if ! "$mut" >"$TMP/mut-$id.log" 2>&1; then
    bad "影子 $id：变异脚本失败（锚点文本动过？见 $TMP/mut-$id.log）"; show_red "$TMP/mut-$id.log"; return 0
  fi
  ok "影子 $id：$mdesc"
  if ! ( for f in "$MUT_SKILL"/scripts/team "$MUT_SKILL"/scripts/lib/*.sh; do bash -n "$f" || exit 1; done ) >"$TMP/mut-$id-syntax.log" 2>&1; then
    bad "影子 $id：变异把脚本改出了语法错（不是行为变异）—— 见 $TMP/mut-$id-syntax.log"; show_red "$TMP/mut-$id-syntax.log"; return 0
  fi
  run_probe "$TMP/red-$id.log"; rc=$?
  if [ "$rc" -ne 0 ] && grep -q '✗' "$TMP/red-$id.log"; then
    ok "影子 $id：变异之后 47 段变红（rc=$rc）"
  else
    bad "影子 $id：变异之后 47 段居然还是绿的（翻转失效）"; show_red "$TMP/red-$id.log"
  fi
  "$redcheck" "$TMP/red-$id.log"
  "$greencheck" "$TMP/red-$id.log"
  restore_skill
  run_probe "$TMP/green-$id.log"; rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "影子 $id：还原后 47 段全绿（$(grep -ac '✓' "$TMP/green-$id.log" 2>/dev/null || echo 0) 条）"
  else
    bad "影子 $id：还原后 47 段仍然红"; show_red "$TMP/green-$id.log"
  fi
}

printf '\033[1m== flip-p201 · 发送者身份：主检出 + 席位线索必须拒绝（47 段，四个影子）==\033[0m\n'
restore_skill
run_probe "$TMP/baseline.log" || { printf '\033[31mflip-p201: 基线（未变异）就不是绿的，先修 47 段\033[0m\n'; show_red "$TMP/baseline.log"; exit 3; }
ok "基线：未变异的树上 47 段全绿"

run_shadow A mut_A "变异只把冲突分支改成永不成立（锚点命中一次）" check_A_red check_A_green
run_shadow B mut_B "变异只去掉 team_sender_seat_clues 的名册过滤（锚点各命中一次）" check_B_red check_B_green
run_shadow C mut_C "变异只把冲突拒绝挪到显式 --from 之前（锚点命中一次）" check_C_red check_C_green
run_shadow D mut_D "变异只去掉拒绝的目录前提 [ \"\$dir\" = \"pm\" ]（锚点命中一次）" check_D_red check_D_green

printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
  printf '\033[32mflip-p201 翻转成立（四个影子 + 还原）\033[0m\n'
  [ "$KEEP" = "1" ] && printf '日志保留：%s\n' "$TMP"
  exit 0
fi
printf '\033[31mflip-p201 翻转不成立\033[0m —— 两侧日志在 %s\n' "$TMP"
exit 1
