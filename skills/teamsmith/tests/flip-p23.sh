#!/usr/bin/env bash
# flip-p23.sh — P24（change-centric-discipline）的翻转包（tasks.md §8.2）。
#
#   bash skills/teamsmith/tests/flip-p23.sh
#   bash skills/teamsmith/tests/flip-p23.sh --keep     # 保留临时目录（排查）
#
# 九对「断掉 → 变红 → 还原 → 变绿」，每对都跑**对应段落的聚焦探针**（smoke 前导 + P24 夹具助手 + 那一段）：
#   1.6  让就绪判据忽略未结束的兄弟                  → 12e 变红
#   3.7a 严格读取器退回「取第一行」的旧行为            → 12g 的 two-id 用例变红
#   3.7b 锚守卫变成 no-op                            → 12g 的 change-less 用例变红
#   4.6a 缺失的 deltas: 行读成空集（而不是 unknown）    → 12h 的缺声明用例变红
#   4.6b 交集只比 dispatched agent 自己的记录任务       → 12h 的跨 agent 用例变红
#   5.5a 作者集合只看 dispatched agent 的记录任务       → 12i 的跨 agent 拒绝变红
#   5.5b 缺作者信号静默通过                           → 12i 的「缺信号很吵」变红
#   6.4  归档路线不再要求 change 就绪                  → 12j 的阻塞/一致用例变红
#   7.5  删掉清单第 10 点                             → 12k 的 7.2 断言变红
# §2.4（digest/面板归组）属 B2，本任务**明确不做**（M48/M49/M50 正在动那些文件），因此不在此包内。
#
# 变异只打在 /tmp 下的**技能树副本**上（真实工作树一个字节都不动）；探针用 TEAM_SMOKE_FAST=1 跑纯逻辑，
# 不建 tmux、不起进程。退出码：0=九对全部成立；1=有反例；3=前置不满足。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$SELF_DIR/lib/tmp-root.sh"
SMOKE="$SKILL_DIR/tests/smoke.sh"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"

KEEP=0
case "${1:-}" in
  "") ;;
  --keep) KEEP=1 ;;
  -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
  *) printf 'flip-p23: 未知参数 %s\n' "$1" >&2; exit 2 ;;
esac

[ -s "$SMOKE" ] || { printf 'flip-p23: 缺 %s\n' "$SMOKE" >&2; exit 3; }
[ -n "$REPO_ROOT" ] || { printf 'flip-p23: %s 不在 git 工作树里\n' "$SKILL_DIR" >&2; exit 3; }

[ "${KEEP:-0}" = "1" ] && export TEAM_TMP_KEEP=1
TMP="$(tmp_root_create flip-p23)" || exit 3
cleanup() { [ "${BASHPID:-$$}" = "$$" ] || return 0; [ "$KEEP" = "1" ] || tmp_root_reap_all; return 0; }
trap cleanup EXIT

TREE="$TMP/tree"
mkdir -p "$TREE/skills"
cp -a "$SKILL_DIR" "$TREE/skills/teamsmith"
[ -d "$REPO_ROOT/skills/teamsmith-init" ] && cp -a "$REPO_ROOT/skills/teamsmith-init" "$TREE/skills/teamsmith-init"
cp -a "$REPO_ROOT/AGENTS.md" "$TREE/AGENTS.md"
MUT_SKILL="$TREE/skills/teamsmith"

PASS=0
FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }

restore_skill() { rm -rf "$MUT_SKILL"; cp -a "$SKILL_DIR" "$MUT_SKILL"; }

# ── 聚焦探针：smoke 前导（身份清洗/夹具/判据）+ P24 助手 + 指定段落 + 结果行 ─────────────────────
build_probe() { # <段名前缀（12e|12g|...）>
  local seg="$1" out
  out="$TMP/probe-$seg.sh"
  {
    awk '/^# -+ 0\. 仓库/{exit} {print}' "$SMOKE"
    awk '/^# 12e–12j · change/{f=1} f&&/^section "12e /{exit} f{print}' "$SMOKE"
    awk -v seg="$seg" '
      $0 ~ ("^section \"" seg " ") { f=1 }
      f { if ($0 ~ /^section "/ && $0 !~ ("^section \"" seg " ")) exit; print }' "$SMOKE"
    cat <<'EOS'
printf '\n== 结果 ==  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
printf 'PROBE-12-END\n'
[ "$FAIL" -eq 0 ] && exit 0
exit 1
EOS
  } | sed "s|^SKILL_DIR=.*|SKILL_DIR=\"$MUT_SKILL\"|" > "$out"
  grep -q 'PROBE-12-END' "$out" || { printf 'flip-p23: 探针 %s 形状不对\n' "$seg" >&2; exit 3; }
  grep -q '^p24_project()' "$out" || { printf 'flip-p23: 探针 %s 缺夹具助手\n' "$seg" >&2; exit 3; }
  bash -n "$out" || { printf 'flip-p23: 探针 %s 语法错\n' "$seg" >&2; exit 3; }
}
for _seg in 12e 12g 12h 12i 12j 12k; do build_probe "$_seg"; done

run_probe() { # <段> <日志>
  TEAM_SMOKE_FAST=1 TEAM_SMOKE_NO_LOCK=1 bash "$TMP/probe-$1.sh" >"$2" 2>&1
  return $?
}

show_red() { sed 's/\x1b\[[0-9;]*m//g' "$1" | grep '✗' | head -4 | sed 's/^/      /'; }

flip() { # <名字> <段> <变异函数> <期望红断言正则...>
  local name="$1" seg="$2" mutfn="$3"; shift 3
  restore_skill
  if ! "$mutfn"; then bad "$name：变异脚本失败（锚点文本动过？）"; return; fi
  local rc
  run_probe "$seg" "$TMP/$name-red.log"; rc=$?
  if [ "$rc" -ne 0 ] && grep -q '✗' "$TMP/$name-red.log"; then
    ok "$name：断掉之后 $seg 变红（rc=$rc）"
  else
    bad "$name：断掉之后 $seg 居然还是绿的（翻转失效）"
    show_red "$TMP/$name-red.log"
  fi
  local miss="" pat
  for pat in "$@"; do
    { grep -E '✗' "$TMP/$name-red.log" || true; } | grep -qE -- "$pat" || miss="$miss [$pat]"
  done
  if [ -z "$miss" ]; then ok "$name：红侧点在预期的断言上"
  else bad "$name：红侧没点到预期断言$miss"; show_red "$TMP/$name-red.log"; fi
  restore_skill
  run_probe "$seg" "$TMP/$name-green.log"; rc=$?
  if [ "$rc" -eq 0 ]; then ok "$name：还原之后 $seg 变绿（✓ $(grep -ac '✓' "$TMP/$name-green.log" 2>/dev/null || echo 0) 条）"
  else bad "$name：还原之后 $seg 仍然红"; show_red "$TMP/$name-green.log"; fi
}

# ── 变异（只动 $MUT_SKILL 里的文件） ───────────────────────────────────────────────────────────
m_16() { python3 - "$MUT_SKILL" <<'PY'
import sys, io
p = sys.argv[1] + "/scripts/lib/common.sh"
s = io.open(p, encoding="utf-8").read()
old = '  team_change_blockers "$id" "$skip"\n'
assert s.count(old) == 1, "1.6 anchor not found"
s = s.replace(old, '  return 0  # MUTATION 1.6: ignore unfinished siblings\n', 1)
io.open(p, "w", encoding="utf-8").write(s)
PY
}
m_37a() { python3 - "$MUT_SKILL" <<'PY'
import sys, io
p = sys.argv[1] + "/scripts/lib/common.sh"
s = io.open(p, encoding="utf-8").read()
old = '  vals="$(team_brief_field_raw "$f" change)"\n'
assert s.count(old) == 1, "3.7a anchor not found"
ins = (old +
       '  local _mut\n  _mut="$(printf \'%s\\n\' "$vals" | head -1)"\n'
       '  if [ -z "$_mut" ]; then printf -- \'-\\n\'; return 0; fi\n'
       '  if [ "$_mut" != "-" ]; then printf \'%s\\n\' "$_mut"; return 0; fi  # MUTATION 3.7a: old first-line behaviour\n')
s = s.replace(old, ins, 1)
io.open(p, "w", encoding="utf-8").write(s)
PY
}
m_37b() { python3 - "$MUT_SKILL" <<'PY'
import sys, io
p = sys.argv[1] + "/scripts/lib/cmd-agents.sh"
s = io.open(p, encoding="utf-8").read()
old = '    if out="$(team_task_anchor "$brief")"; then\n'
assert s.count(old) == 1, "3.7b anchor not found"
s = s.replace(old, '    if out=""; then  # MUTATION 3.7b: anchor guard is a no-op\n', 1)
io.open(p, "w", encoding="utf-8").write(s)
PY
}
m_46a() { python3 - "$MUT_SKILL" <<'PY'
import sys, io
p = sys.argv[1] + "/scripts/lib/common.sh"
s = io.open(p, encoding="utf-8").read()
old = '  [ "${n:-0}" -eq 0 ] && { printf \'*\\n\'; return 0; }\n'
assert s.count(old) == 1, "4.6a anchor not found"
s = s.replace(old, '  [ "${n:-0}" -eq 0 ] && { return 0; }  # MUTATION 4.6a: absent reads as empty\n', 1)
io.open(p, "w", encoding="utf-8").write(s)
PY
}
m_46b() { python3 - "$MUT_SKILL" <<'PY'
import sys, io
p = sys.argv[1] + "/scripts/lib/cmd-agents.sh"
s = io.open(p, encoding="utf-8").read()
old = '      [ "$sid" = "$id" ] && continue\n'
assert s.count(old) == 1, "4.6b anchor not found"
ins = old + '      [ "$(team_brief_field_raw "$sbrief" agent | head -1)" = "$agent" ] || continue  # MUTATION 4.6b: agent-local only\n'
s = s.replace(old, ins, 1)
io.open(p, "w", encoding="utf-8").write(s)
PY
}
m_55a() { python3 - "$MUT_SKILL" <<'PY'
import sys, io
p = sys.argv[1] + "/scripts/lib/cmd-agents.sh"
s = io.open(p, encoding="utf-8").read()
old = '        agent)   [ "$aauth" = "$agent" ] && authored="${authored:+$authored、}$aid" ;;\n'
assert s.count(old) == 1, "5.5a anchor not found"
new = '        agent)   [ "$aid" = "$(team_state_get "$agent" task \'\')" ] && [ -n "$aid" ] && authored="${authored:+$authored、}$aid" ;;  # MUTATION 5.5a\n'
s = s.replace(old, new, 1)
io.open(p, "w", encoding="utf-8").write(s)
PY
}
m_55b() { python3 - "$MUT_SKILL" <<'PY'
import sys, io
p = sys.argv[1] + "/scripts/lib/cmd-agents.sh"
s = io.open(p, encoding="utf-8").read()
old = '    [ -n "$missing" ] && team_warn "  作者信号缺失：$missing'
assert s.count(old) == 1, "5.5b anchor not found"
s = s.replace(old, '    true # MUTATION 5.5b: missing signal passes silently\n    [ -n "$missing" ] && false && team_warn "  作者信号缺失：$missing', 1)
io.open(p, "w", encoding="utf-8").write(s)
PY
}
m_64() { python3 - "$MUT_SKILL" <<'PY'
import sys, io
p = sys.argv[1] + "/scripts/lib/common.sh"
s = io.open(p, encoding="utf-8").read()
old = '          if [ -z "${TEAM_CHANGE_READY_GATE:-}" ]; then\n'
assert s.count(old) == 1, "6.4 anchor not found"
s = s.replace(old, '          if false; then  # MUTATION 6.4: archive route drops the readiness requirement\n', 1)
io.open(p, "w", encoding="utf-8").write(s)
PY
}
m_75() { python3 - "$MUT_SKILL" <<'PY'
import sys, io, re
p = sys.argv[1] + "/references/openspec.md"
s = io.open(p, encoding="utf-8").read()
m = re.search(r'\n10\. \*\*The anchor exists\*\*.*?(?=\n## 5\.)', s, re.S)
assert m, "7.5 anchor not found"
s = s[:m.start()] + "\n" + s[m.end():]
io.open(p, "w", encoding="utf-8").write(s)
PY
}

printf '\033[1m== flip-p23 · 九对断点（§1.6 / §3.7a-b / §4.6a-b / §5.5a-b / §6.4 / §7.5） ==\033[0m\n'
printf '  （§2.4 digest/面板归组属 B2，本任务不做 —— 不在包内，见报告）\n'

flip "1.6 就绪忽略未结束兄弟" 12e m_16 '12e 有未结束兄弟' '12e blocker' '12e --json 未就绪'
flip "3.7a 读取器退回第一行" 12g m_37a '12g G1 的拒绝来自规则 1' '12g G2 的拒绝来自规则 1' '12g G3 的拒绝来自规则 1'
flip "3.7b 锚守卫 no-op" 12g m_37b '12g N1 的拒绝来自锚守卫' '12g N2 的拒绝来自锚守卫' '12g N3 的拒绝来自锚守卫' '12g N4 的拒绝来自锚守卫'
flip "4.6a 缺失声明读成空集" 12h m_46a '12h 说明缺行被读作全量'
flip "4.6b 交集只比本 agent 记录" 12h m_46b '12h 拒绝来自 delta 单写者守卫' '12h --force 打印冲突'
flip "5.5a 作者集合只看记录任务" 12i m_55a '12i 拒绝来自作者守卫' '12i --force 打印自验'
flip "5.5b 缺信号静默通过" 12i m_55b '12i 缺信号很吵'
flip "6.4 归档不要求 change 就绪" 12j m_64 '12j 未结束兄弟' '12j 拒绝'
flip "7.5 删掉清单第 10 点" 12k m_75 '7.2 checklist gains point 10' '7.2 checklist now has exactly ten points'

printf '\n== 结果 ==  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
