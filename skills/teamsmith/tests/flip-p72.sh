#!/usr/bin/env bash
# flip-p72.sh — P82（change: notify-sender-identity）的翻转包。
#
#   bash skills/teamsmith/tests/flip-p72.sh
#   bash skills/teamsmith/tests/flip-p72.sh --keep     # 保留临时目录（排查）
#
# 每个变异打在 /tmp 下的**技能树副本**上（真实工作树一个字节都不动），然后跑**聚焦探针**：
# smoke 前导（身份清洗 / 夹具 / 判据）+ 46 段（P82 的夹具）+ 结果行。三对「断掉 → 变红 → 还原 → 变绿」：
#   a 发送者退回**收件人**（旧实现：收件箱行 / knock 文本 / 条目 from: 三处都用 recipient）
#     → 1.2 / 1.5 / 1.6 的「发送者 = dev2」类断言变红
#   b 未解析的运行时目录**静默退回 pm**（缺陷本身） → 1.4 的拒绝/零写入断言变红
#   c 让**继承的 TEAM_AGENT 压过**运行时目录 → 1.3 的两条断言变红
#   d 扩展回到 `window || …`（窗口名重新决定发送者）→ 3.2 的「窗口撒谎」对断言变红（3.1 保持绿，
#     证明这一对点的就是窗口那一条）
#
# 退出码：0 = 三对全部成立；1 = 有反例；3 = 前置不满足。
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
  -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
  *) printf 'flip-p72: 未知参数 %s\n' "$1" >&2; exit 2 ;;
esac

[ -s "$SMOKE" ] || { printf 'flip-p72: 缺 %s\n' "$SMOKE" >&2; exit 3; }
grep -q '^section "46 ' "$SMOKE" || { printf 'flip-p72: smoke.sh 里没有 46 段（P82 夹具）\n' >&2; exit 3; }

# 3.x 与变异 d 要跑扩展（与 smoke.sh 同口径的 TS 运行时探测）
TS_RUNNER=""
if command -v node >/dev/null 2>&1 && node -e 'process.exit(process.features.typescript?0:1)' >/dev/null 2>&1; then
  TS_RUNNER="node"
elif command -v bun >/dev/null 2>&1 && bun -e '1' >/dev/null 2>&1; then
  TS_RUNNER="bun"
elif [ -x "$HOME/.bun/bin/bun" ] && "$HOME/.bun/bin/bun" -e '1' >/dev/null 2>&1; then
  TS_RUNNER="$HOME/.bun/bin/bun"
fi

[ "${KEEP:-0}" = "1" ] && export TEAM_TMP_KEEP=1
TMP="$(tmp_root_create flip-p72)" || exit 3
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
show_red() { sed 's/\x1b\[[0-9;]*m//g' "$1" | grep '✗' | head -5 | sed 's/^/      /'; }

# ── 聚焦探针：smoke 前导 + 46 段 + 结果行（SKILL_DIR 换成变异树）─────────────────────────────
PROBE="$TMP/probe-46.sh"
{
  awk '/^# -+ 0\. 仓库/{exit} {print}' "$SMOKE"
  awk '/^section "46 /{f=1} f{ if ($0 ~ /^section "/ && $0 !~ /^section "46 /) exit; print }' "$SMOKE"
  cat <<'EOS'
printf '\n== 结果 ==  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
printf 'PROBE-46-END\n'
[ "$FAIL" -eq 0 ] && exit 0
exit 1
EOS
} | sed "s|^SKILL_DIR=.*|SKILL_DIR=\"$MUT_SKILL\"|" > "$PROBE"
grep -q 'PROBE-46-END' "$PROBE" || { printf 'flip-p72: 探针形状不对（46 段没抽出来？）\n' >&2; exit 3; }
bash -n "$PROBE" || { printf 'flip-p72: 探针语法错\n' >&2; exit 3; }

run_probe() { # <日志>
  TEAM_SMOKE_FAST=1 TEAM_SMOKE_NO_LOCK=1 bash "$PROBE" >"$1" 2>&1
  return $?
}

# ── 变异（只动 $MUT_SKILL 里的文件）─────────────────────────────────────────────────────────
m_a() { python3 - "$MUT_SKILL" <<'PY'
import io, sys
p = sys.argv[1] + '/scripts/lib/cmd-agents.sh'
s = io.open(p, encoding='utf-8').read()
# 收件箱行的第 4 参（发送者）去掉 → team_inbox_append 回落到「owner 标签」= 收件人
old = '  team_inbox_append "$agent" manual "$msg" "$sender" \\\n'
assert s.count(old) == 1, ('a inbox anchor', s.count(old))
s = s.replace(old, '  team_inbox_append "$agent" manual "$msg" \\\n', 1)
old = '"[manual] agent:$sender · $msg" knock --from "$sender"'
assert s.count(old) == 2, ('a knock anchors', s.count(old))
s = s.replace(old, '"[manual] agent:$agent · $msg" knock --from "$agent"  # MUTATION a')
io.open(p, 'w', encoding='utf-8').write(s)
PY
}

m_b() { python3 - "$MUT_SKILL" <<'PY'
import io, sys
p = sys.argv[1] + '/scripts/lib/common.sh'
s = io.open(p, encoding='utf-8').read()
old = '  if [ -z "$dir" ]; then\n    team_err "notify：发送者无法解析'
assert s.count(old) == 1, ('b anchor', s.count(old))
s = s.replace(old,
              '  # MUTATION b: an unresolved runtime directory falls back to pm (the defect)\n'
              '  [ -n "$dir" ] || { printf \'pm\\n\'; return 0; }\n'
              + old, 1)
io.open(p, 'w', encoding='utf-8').write(s)
PY
}

m_c() { python3 - "$MUT_SKILL" <<'PY'
import io, sys
p = sys.argv[1] + '/scripts/lib/common.sh'
s = io.open(p, encoding='utf-8').read()
old = '  dir="$(team_sender_from_dir)"\n'
assert s.count(old) == 1, ('c anchor', s.count(old))
s = s.replace(old,
              old + '  if [ -n "${TEAM_AGENT:-}" ]; then dir="$TEAM_AGENT"; fi   # MUTATION c: the inherited value wins\n',
              1)
io.open(p, 'w', encoding='utf-8').write(s)
PY
}

m_d() { python3 - "$MUT_SKILL" <<'PYMUTD'
import io, sys
p = sys.argv[1] + '/extension/team-notify.ts'
s = io.open(p, encoding='utf-8').read()
old = '    const agent = senderFromDir(resolve(cwd), wtPrefix, cfg.roster)\n'
assert s.count(old) == 1, ('d anchor', s.count(old))
s = s.replace(old,
              '    const agent = window || senderFromDir(resolve(cwd), wtPrefix, cfg.roster) // MUTATION d: the window decides again\n',
              1)
io.open(p, 'w', encoding='utf-8').write(s)
PYMUTD
}

flip() { # <名字> <变异函数> <期望红断言正则...>
  local name="$1" mutfn="$2"; shift 2
  restore_skill
  if ! "$mutfn" >"$TMP/$name-mut.log" 2>&1; then
    bad "$name：变异脚本失败（锚点文本动过？见 $TMP/$name-mut.log）"
    return
  fi
  local rc
  # 变异必须是「行为断掉」而不是「脚本改坏」：语法错的树只会把 46 段整体打红，那不是翻转证据
  if ! ( for f in "$MUT_SKILL"/scripts/team "$MUT_SKILL"/scripts/lib/*.sh; do bash -n "$f" || exit 1; done ) >"$TMP/$name-syntax.log" 2>&1; then
    bad "$name：变异把脚本改出了语法错（不是行为变异）—— 见 $TMP/$name-syntax.log"
    show_red "$TMP/$name-syntax.log"
    return
  fi
  if [ -n "$TS_RUNNER" ]; then
    printf 'await import(%s)\n' "'$MUT_SKILL/extension/team-notify.ts'" > "$TMP/$name-ts-check.mjs"
    if ! "$TS_RUNNER" "$TMP/$name-ts-check.mjs" >"$TMP/$name-ts.log" 2>&1; then
      bad "$name：变异把扩展改得加载不了（不是行为变异）—— 见 $TMP/$name-ts.log"
      show_red "$TMP/$name-ts.log"
      return
    fi
  fi
  run_probe "$TMP/$name-red.log"; rc=$?
  if [ "$rc" -ne 0 ] && grep -q '✗' "$TMP/$name-red.log"; then
    ok "$name：断掉之后 46 段变红（rc=$rc）"
  else
    bad "$name：断掉之后 46 段居然还是绿的（翻转失效）"
    show_red "$TMP/$name-red.log"
  fi
  local miss="" pat
  for pat in "$@"; do
    grep -E '✗' "$TMP/$name-red.log" | grep -qE -- "$pat" || miss="$miss [$pat]"
  done
  if [ -z "$miss" ]; then ok "$name：红侧点在预期的断言上"
  else bad "$name：红侧没点到预期断言$miss"; show_red "$TMP/$name-red.log"; fi
  restore_skill
  run_probe "$TMP/$name-green.log"; rc=$?
  if [ "$rc" -eq 0 ]; then ok "$name：还原之后 46 段全绿（$(grep -ac '^  .*✓' "$TMP/$name-green.log" 2>/dev/null || echo 0) 条）"
  else bad "$name：还原之后 46 段仍然红"; show_red "$TMP/$name-green.log"; fi
}

printf '\033[1m== flip-p72 · notify-sender-identity（46 段：CLI 侧三处 + 扩展的窗口一处）==\033[0m\n'
restore_skill
run_probe "$TMP/baseline.log" || { printf '\033[31mflip-p72: 基线（未变异）就不是绿的，先修 46 段\033[0m\n'; show_red "$TMP/baseline.log"; exit 3; }
ok "基线：未变异的树上 46 段全绿"

flip a m_a 'P82 1\.2 发送者 = 工作树目录名' 'P82 1\.5 knock 文本与 from: / 收件箱行同名' 'P82 1\.6 dev 的收件箱里发送者仍是 worker'
flip b m_b 'P82 1\.4 项目外的工作树里 notify 应当拒绝' 'P82 1\.4 拒绝时零写入' 'P82 1\.4 拒绝输出点名 --from'
flip c m_c 'P82 1\.3 发送者仍是运行时目录的 dev2' 'P82 1\.3 stderr 点名被忽略的 TEAM_AGENT 值'
if [ -n "$TS_RUNNER" ]; then
  flip d m_d 'P82 3\.2 窗口撒谎（报 dev）时 \[auto\] 这一路仍是 dev2' 'P82 3\.2 两条路在对抗性窗口下仍然同名' 'P82 3\.2 窗口名没有变成发送者'
else
  printf '  \033[33mSKIP\033[0m d：本机没有 node（类型剥离）/ bun，跑不了扩展夹具\n'
fi

printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
  printf '\033[32mflip-p72 翻转成立\033[0m\n'
  [ "$KEEP" = "1" ] && printf '日志保留：%s\n' "$TMP"
  exit 0
fi
printf '\033[31mflip-p72 翻转不成立\033[0m —— 两侧日志在 %s\n' "$TMP"
exit 1
