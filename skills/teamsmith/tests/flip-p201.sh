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
# 影子（任务书 ④）：把「拒绝」改回「直接 pm」—— 即在 /tmp 下的技能树副本里把冲突分支改成永不成立，
# 然后跑**聚焦探针**（smoke 前导 + §47 + 结果行）：
#   红侧：P201 ①（主检出 + 窗口 dev）与 ②（主检出 + TEAM_AGENT=dev）的断言必须变红（非 0 / 零写入 /
#         点名两个名字 / 两条出路）；
#   对照：P201 ③（窗口 pm / 无线索 / 别的会话的同名窗口 → 照旧 pm）在影子里必须**仍然绿** ——
#         它证明红的是「冲突判定」，不是整段坏了；
#   还原：把副本还原回本树 → §47 全绿。
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
  -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
  *) printf 'flip-p201: 未知参数 %s\n' "$1" >&2; exit 2 ;;
esac

[ -s "$SMOKE" ] || { printf 'flip-p201: 缺 %s\n' "$SMOKE" >&2; exit 3; }
grep -q '^section "47 ' "$SMOKE" || { printf 'flip-p201: smoke.sh 里没有 47 段（notify 发送者夹具）\n' >&2; exit 3; }
grep -q 'P201 ① 主检出 + 窗口 dev' "$SMOKE" || { printf 'flip-p201: smoke.sh 里没有 P201 的断言（先做夹具）\n' >&2; exit 3; }
grep -q 'team_sender_seat_clues' "$SKILL_DIR/scripts/lib/common.sh" \
  || { printf 'flip-p201: 本树没有 P201 的实现（team_sender_seat_clues）——先做修复\n' >&2; exit 3; }

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
show_red() { sed 's/\x1b\[[0-9;]*m//g' "$1" | grep '✗' | head -12 | sed 's/^/      /'; }

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

# ── 影子：把「主检出 + 线索 → 拒绝」改回「直接 pm」（冲突分支永不成立）────────────────────────
mut_silent_pm() {
  python3 - "$MUT_SKILL" <<'PY'
import io, sys
p = sys.argv[1] + '/scripts/lib/common.sh'
s = io.open(p, encoding='utf-8').read()
old = '  if [ "$dir" = "pm" ] && team_sender_is_main_checkout; then\n'
assert s.count(old) == 1, ('P201 anchor', s.count(old))
s = s.replace(old,
              '  if false; then   # MUTATION p201: the conflict refusal is gone (the main checkout is "pm" again)\n',
              1)
io.open(p, 'w', encoding='utf-8').write(s)
PY
}

printf '\033[1m== flip-p201 · 发送者身份：主检出 + 席位线索必须拒绝（47 段）==\033[0m\n'
restore_skill
run_probe "$TMP/baseline.log" || { printf '\033[31mflip-p201: 基线（未变异）就不是绿的，先修 47 段\033[0m\n'; show_red "$TMP/baseline.log"; exit 3; }
ok "基线：未变异的树上 47 段全绿"

if ! mut_silent_pm >"$TMP/mut.log" 2>&1; then
  bad "影子：变异脚本失败（锚点文本动过？见 $TMP/mut.log）"; show_red "$TMP/mut.log"
else
  ok "影子：变异只把冲突分支改成永不成立（锚点命中一次）"
  if ! ( for f in "$MUT_SKILL"/scripts/team "$MUT_SKILL"/scripts/lib/*.sh; do bash -n "$f" || exit 1; done ) >"$TMP/mut-syntax.log" 2>&1; then
    bad "影子：变异把脚本改出了语法错（不是行为变异）—— 见 $TMP/mut-syntax.log"; show_red "$TMP/mut-syntax.log"
  else
    run_probe "$TMP/red.log"; RC=$?
    if [ "$RC" -ne 0 ] && grep -q '✗' "$TMP/red.log"; then
      ok "影子：拒绝被拿掉之后 47 段变红（rc=$RC）"
    else
      bad "影子：拒绝被拿掉之后 47 段居然还是绿的（翻转失效）"; show_red "$TMP/red.log"
    fi
    MISS=""
    for PAT in \
      'P201 ① 主检出 \+ 窗口 dev 应当拒绝' \
      'P201 ① 拒绝时零写入' \
      'P201 ① 拒绝输出点名线索说的名字（dev）' \
      'P201 ① 拒绝输出给出出路：--from' \
      'P201 ② 主检出 \+ TEAM_AGENT=dev 应当拒绝' \
      'P201 ② 拒绝时零写入' \
      'P201 ② 拒绝输出点名线索说的名字（TEAM_AGENT dev）'
    do
      { grep -E '✗' "$TMP/red.log" || true; } | grep -qE -- "$PAT" || MISS="$MISS [$PAT]"
    done
    if [ -z "$MISS" ]; then ok "影子：红侧点在 ①② 的预期断言上（7 条）"
    else bad "影子：红侧没点到预期断言$MISS"; show_red "$TMP/red.log"; fi
    if { grep -E '✗' "$TMP/red.log" || true; } | grep -qE 'P201 ③'; then
      bad "影子：③（反向：不许误伤）也红了 —— 说明红的是整段而不是冲突判定"; show_red "$TMP/red.log"
    else
      ok "影子：③（窗口 pm / 无线索 / 别的会话 → 照旧 pm）仍然全绿（红的是冲突判定）"
    fi
  fi
fi

restore_skill
run_probe "$TMP/green.log"; RC=$?
if [ "$RC" -eq 0 ]; then
  ok "还原：47 段全绿（$(grep -ac '^  .*✓' "$TMP/green.log" 2>/dev/null || echo 0) 条）"
else
  bad "还原：47 段仍然红"; show_red "$TMP/green.log"
fi

printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
  printf '\033[32mflip-p201 翻转成立\033[0m\n'
  [ "$KEEP" = "1" ] && printf '日志保留：%s\n' "$TMP"
  exit 0
fi
printf '\033[31mflip-p201 翻转不成立\033[0m —— 两侧日志在 %s\n' "$TMP"
exit 1
