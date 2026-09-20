#!/usr/bin/env bash
# M48 flips: the duplicate-id work is pinned to the thing that changed, in both halves.
#
#   bash skills/teamsmith/tests/flip-m48.sh focus   # 控制台：焦点按行身份（翻转 = 改回按 ID 比较）
#   bash skills/teamsmith/tests/flip-m48.sh add     # CLI：board add 拒绝重复（翻转 = 去掉检查）
#   bash skills/teamsmith/tests/flip-m48.sh assign  # CLI：assign 原地改 agent（翻转 = 改回「再 add 一行」）
#   bash skills/teamsmith/tests/flip-m48.sh         # 三个都跑
#   bash skills/teamsmith/tests/flip-m48.sh --keep  # 保留临时目录（排查）
#
# focus：`src` 的临时副本打补丁（焦点匹配与 ↑/↓ 走路改回裸 ID 比较）→ bun 重建翻转 bundle →
#   `tests/panel-b3.sh board` 跑两遍（翻转 bundle 应红在 M48 的重复断言上，提交的 bundle 应绿）。
#   真源码一个字节都不动。
# add：skill 树的临时副本去掉 `team_board_add` 的重复检查 → 用 smoke 的**前导 + §0/§2/§4/§4b/§4c**
#   拼出的聚焦探针（判据就是门禁里的那一份，不是抄的第二份）跑两遍：副本应红在 §4c 的
#   「重复 ID 被拒 / 文件未变」上，真树应绿。
# assign：skill 临时副本把 `team_board_assign` 的写口换成「再 add 一行」（即重复 ID 进来的老路）→
#   同一探针：副本应红在「assign 后行数不变 / T1.1 仍是两行」上，真树应绿。
#
# 退出码：0 = 翻转都成立；1 = 有预期不成立；2 = 环境/前置不满足。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
TREE="$(cd -P "$SKILL_DIR/../.." && pwd)"
SMOKE="$SKILL_DIR/tests/smoke.sh"
PANEL_DIR="$SKILL_DIR/scripts/panel"
PIN="$PANEL_DIR/panel.js"

mode=""
case "${1:-}" in
  "")        mode=all ;;
  focus|add|assign) mode="$1" ;;
  --keep)    KEEP=1; mode="${2:-all}" ;;
  -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
  *) printf 'flip-m48: 未知参数 %s（focus|add|assign|all|--keep）\n' "$1" >&2; exit 2 ;;
esac
case "$mode" in all|focus|add|assign) ;; *) printf 'flip-m48: 未知模式 %s\n' "$mode" >&2; exit 2 ;; esac
KEEP="${KEEP:-0}"

die2() { printf 'flip-m48: %s\n' "$*" >&2; exit 2; }
pass() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$*"; RC=1; }
plain() { sed 's/\x1b\[[0-9;]*m//g' "$1"; }

command -v git >/dev/null 2>&1 || die2 "需要 git"
command -v python3 >/dev/null 2>&1 || die2 "需要 python3（打补丁）"
[ -s "$SMOKE" ] || die2 "找不到 $SMOKE"
[ -s "$PIN" ] || die2 "找不到 bundle（$PIN）"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/teamsmith-flip-m48.XXXXXX")"
cleanup() { [ "${BASHPID:-$$}" = "$$" ] || return 0; [ "$KEEP" = "1" ] || rm -rf "$TMP"; return 0; }
trap cleanup EXIT
RC=0

printf '\033[1m== flip-m48 · 看板重复 ID（%s）==\033[0m\n' "$mode"

# ---------------------------------------------------------------- focus（控制台）
flip_focus() {
  local bun js ink_pin react_pin
  bun="${M48_FLIP_BUN:-}"
  [ -n "$bun" ] || bun="$(command -v bun 2>/dev/null || true)"
  [ -n "$bun" ] || bun="$HOME/.bun/bin/bun"
  js="$(command -v node || command -v bun || true)"
  [ -x "$bun" ] || { printf '  跳过 focus：需要 bun 重建翻转 bundle（%s）\n' "$bun" >&2; return 2; }
  [ -n "$js" ] || { printf '  跳过 focus：本机没有 node/bun\n' >&2; return 2; }
  command -v tmux >/dev/null 2>&1 || { printf '  跳过 focus：panel-b3 需要 tmux\n' >&2; return 2; }
  ink_pin="$(sed -n 's/.*"ink": *"\([^"]*\)".*/\1/p' "$PANEL_DIR/package.json")"
  react_pin="$(sed -n 's/.*"react": *"\([^"]*\)".*/\1/p' "$PANEL_DIR/package.json")"

  local src="$TMP/focus-src" out="$TMP/focus-panel.js"
  mkdir -p "$src"
  cp -r "$PANEL_DIR/src/." "$src/"
  ln -sfn "$PANEL_DIR/node_modules" "$src/node_modules"
  python3 - "$src" <<'PY' || return 2
import sys

d = sys.argv[1]


def edit(name, old, new):
    path = f'{d}/{name}'
    s = open(path, encoding='utf-8').read()
    if s.count(old) != 1:
        sys.exit(f'flip-m48: pattern not unique ({s.count(old)}): {old[:70]!r}')
    open(path, 'w', encoding='utf-8').write(s.replace(old, new))


# The App's kanban walk goes back to the id lookup: `findIndex` by id always answers with the first
# of two rows sharing an id, and the same-id early return then freezes the cursor on it.
edit('App.tsx', """      const row = focusRow(rows, current)
      if (!row) return
      const inLane = rows.filter((r) => r.state === current.lane)
      const idx = inLane.indexOf(row)
      const next = idx < 0 ? undefined : inLane[idx + cardDelta]
      if (!next || next === row) return""", """      const inLane = rows.filter((r) => r.state === current.lane) // FLIP m48: id lookup
      const idx = inLane.findIndex((r) => r.id === current.id) // FLIP m48
      const next = inLane[Math.max(0, Math.min(inLane.length - 1, idx + cardDelta))] // FLIP m48
      if (!next || next.id === current.id) return // FLIP m48: the freeze""")
# The card highlight goes back to comparing ids: both duplicates light up at once.
edit('layout.ts', """  for (let i = win.start; i < win.end; i++) {
    const card = cards[i]
    const focused = card === target""", """  for (let i = win.start; i < win.end; i++) {
    const card = cards[i]
    const focused = card.id === (target?.id ?? '') // FLIP m48: id match lights both rows""")
edit('layout.ts', """    for (const card of cards) {
      const focused = card === target""", """    for (const card of cards) {
      const focused = card.id === (target?.id ?? '') // FLIP m48: id match lights both rows""")
PY
  ( cd "$PANEL_DIR" && "$bun" build "$src/main.tsx" --target=node --format=esm --minify \
      --define "__PIN_INK__=\"$ink_pin\"" --define "__PIN_REACT__=\"$react_pin\"" \
      --outfile "$out" ) >"$TMP/focus-build.log" 2>&1 || {
    printf '  ✗ focus：翻转 bundle 构建失败\n' >&2; tail -5 "$TMP/focus-build.log" >&2; return 2
  }
  grep -q 'FLIP m48' "$src/App.tsx" "$src/layout.ts" || { printf '  ✗ focus：补丁没写进去\n' >&2; return 2; }

  local flipped_log="$TMP/focus-flipped.log" now_log="$TMP/focus-now.log" rc rc2
  TEAM_B3_PANEL="$out" bash "$SKILL_DIR/tests/panel-b3.sh" board >"$flipped_log" 2>&1; rc=$?
  TEAM_B3_PANEL="$PIN" bash "$SKILL_DIR/tests/panel-b3.sh" board >"$now_log" 2>&1; rc2=$?
  printf '  翻转 bundle 的 board 场景：rc=%s（✗ %s 条）｜提交 bundle：rc=%s（✗ %s 条）\n' \
    "$rc" "$(plain "$flipped_log" | grep -ac '^  .*✗' || true)" "$rc2" "$(plain "$now_log" | grep -ac '^  .*✗' || true)"

  local want_flipped="" l
  for l in '✗ M48 重复 ID：↓ 走到同 ID 的第二行（不卡死）' '✗ M48 重复 ID：焦点光标恰好一个（不是两行都亮）'; do
    plain "$flipped_log" | grep -qF -- "$l" || want_flipped="$want_flipped
     $l"
  done
  if [ -n "$want_flipped" ]; then
    fail "focus：翻转 bundle 没有红在预期断言上：$want_flipped"
    plain "$flipped_log" | grep -aE '^  .*✗' | sed 's/^/      /' | head -10
  else
    pass "focus：翻转（改回按 ID 比较）→ 重复 ID 的行走/单光标断言变红"
  fi
  if [ "$rc2" -eq 0 ] && ! plain "$now_log" | grep -q '^  .*✗'; then
    pass "focus：提交的 bundle 在同一场景全绿（同一夹具、同一判据红→绿）"
  else
    fail "focus：提交的 bundle 在 board 场景有失败项（rc=$rc2）"
    plain "$now_log" | grep -aE '^  .*✗' | sed 's/^/      /' | head -10
  fi
  return 0
}

# ---------------------------------------------------------------- add（CLI 守卫）
extract_section() { # <file> <name> → 打印该 section 的整块
  local f="$1" name="$2" start end
  start="$(grep -n -F "section \"$name\"" "$f" | head -1 | cut -d: -f1)"
  [ -n "$start" ] || return 1
  end="$(awk -v s="$start" 'NR>s && /^section "/ { print NR; exit }' "$f")"
  if [ -n "$end" ]; then sed -n "${start},$((end-1))p" "$f"; else sed -n "${start},\$p" "$f"; fi
}

build_probe() { # <out> <skill-dir>：smoke 前导 + §0/§2/§4/§4b/§4c（判据就是门禁里那一份）
  local out="$1" sk="$2"
  {
    awk '/^# -+ 0\. 仓库/{exit} {print}' "$SMOKE"
    extract_section "$SMOKE" "0 · 临时仓库"
    extract_section "$SMOKE" "2 · init"
    extract_section "$SMOKE" "4 · task + board"
    extract_section "$SMOKE" "4b · 状态诚实：未知 id 不假装写入 + done 要证据（M6.1 F29/F1）"
    extract_section "$SMOKE" "4c · 看板重复 ID（M48）：add 拒绝 / --allow-dup / 三处可见"
    cat <<'EOS'
section "PROBE-M48-END"
printf '\n== 结果 ==  ok %d  bad %d\n' "$PASS" "$FAIL"
printf 'PROBE-M48-END\n'
[ "$FAIL" -eq 0 ] && exit 0
exit 1
EOS
  } | sed "s|^SKILL_DIR=.*|SKILL_DIR=\"$sk\"|" > "$out"
  grep -q '^section "4c ' "$out" || die2 "$SMOKE 里没有 §4c（M48 的守卫不在？）"
  grep -q '^section "PROBE-M48-END"' "$out" || die2 "探针结尾没写进去"
  bash -n "$out" || die2 "探针语法不对（截取写坏了）：$out"
  return 0
}

run_probe() { # <probe> <log>
  local probe="$1" log="$2"
  TEAM_SMOKE_NO_LOCK=1 bash "$probe" > "$log" 2>&1
}

flip_add() {
  local copy="$TMP/add-tree"
  mkdir -p "$copy/skills"
  # 两个 skill 都要（SKILL_INIT_DIR 是兄弟目录）；node_modules 不需要，跳过。
  ( cd "$TREE" && tar --exclude='*/node_modules' -cf - skills ) | ( cd "$copy" && tar -xf - ) || return 2
  [ -d "$copy/skills/teamsmith-init" ] || { printf '  ✗ add：skill 副本不完整\n' >&2; return 2; }
  python3 - "$copy/skills/teamsmith/scripts/lib/common.sh" <<'PY' || return 2
import sys

path = sys.argv[1]
s = open(path, encoding='utf-8').read()
old = """  if team_board_has "$1"; then
    if [ "$allow_dup" != "1" ]; then"""
new = """  if false; then   # FLIP m48: the duplicate check removed
    if [ "$allow_dup" != "1" ]; then"""
if s.count(old) != 1:
    sys.exit(f'flip-m48: pattern not unique ({s.count(old)})')
open(path, 'w', encoding='utf-8').write(s.replace(old, new))
PY
  grep -q 'FLIP m48: the duplicate check removed' "$copy/skills/teamsmith/scripts/lib/common.sh" || { printf '  ✗ add：补丁没写进去\n' >&2; return 2; }
  bash -n "$copy/skills/teamsmith/scripts/lib/common.sh" || { printf '  ✗ add：补丁把脚本改坏了\n' >&2; return 2; }

  local mutated_log="$TMP/add-flipped.log" real_log="$TMP/add-now.log"
  build_probe "$TMP/probe-mutated.sh" "$copy/skills/teamsmith" || return 2
  build_probe "$TMP/probe-real.sh" "$SKILL_DIR" || return 2
  run_probe "$TMP/probe-mutated.sh" "$mutated_log"; local mrc=$?
  run_probe "$TMP/probe-real.sh" "$real_log"; local rrc=$?
  grep -q '^PROBE-M48-END$' "$mutated_log" || { printf '  ✗ add：翻转侧探针没跑完（%s）\n' "$(tail -1 "$mutated_log")" >&2; return 2; }
  grep -q '^PROBE-M48-END$' "$real_log" || { printf '  ✗ add：真树侧探针没跑完（%s）\n' "$(tail -1 "$real_log")" >&2; return 2; }
  printf '  翻转 skill 的 §4c：rc=%s（✗ %s 条）｜真树 §4c：rc=%s（✗ %s 条）\n' \
    "$mrc" "$(plain "$mutated_log" | grep -ac '^  .*✗' || true)" "$rrc" "$(plain "$real_log" | grep -ac '^  .*✗' || true)"

  if [ "$mrc" -ne 0 ] && plain "$mutated_log" | grep -qF '✗ M48：重复 ID 的 board add 应当被拒'; then
    pass "add：去掉检查 → §4c 的「重复 ID 应当被拒」变红（守卫测试真的咬在检查上）"
    plain "$mutated_log" | grep -aF 'M48：' | grep -aF '✗' | sed 's/^/      /' | head -5
  else
    fail "add：去掉检查后 §4c 没有红在预期断言上（rc=$mrc）"
    plain "$mutated_log" | grep -aE '^  .*✗' | sed 's/^/      /' | head -8
  fi
  if [ "$rrc" -eq 0 ] && ! plain "$real_log" | grep -q '^  .*✗'; then
    pass "add：真树（带检查）在同一探针上全绿"
  else
    fail "add：真树在 §4c 探针上有失败项（rc=$rrc）"
    plain "$real_log" | grep -aE '^  .*✗' | sed 's/^/      /' | head -8
  fi
  return 0
}

# ---------------------------------------------------------------- assign（原地指派的正门）
flip_assign() {
  local copy="$TMP/assign-tree"
  mkdir -p "$copy/skills"
  ( cd "$TREE" && tar --exclude='*/node_modules' -cf - skills ) | ( cd "$copy" && tar -xf - ) || return 2
  [ -d "$copy/skills/teamsmith-init" ] || { printf '  ✗ assign：skill 副本不完整\n' >&2; return 2; }
  # 老路：指派 = 再写一行（重复 ID 就是这么进来的）。真源码一个字节不动。
  python3 - "$copy/skills/teamsmith/scripts/lib/common.sh" <<'PY' || return 2
import sys

path = sys.argv[1]
s = open(path, encoding='utf-8').read()
old = """  team_board_write_col "$id" agent "$ag" || return 1
  return 0
}"""
new = """  team_board_add "$id" "指派 $ag" "$ag" "-" "-" 1 || return 1   # FLIP m48: assign by adding a row
  return 0
}"""
if s.count(old) != 1:
    sys.exit(f'flip-m48: pattern not unique ({s.count(old)})')
open(path, 'w', encoding='utf-8').write(s.replace(old, new))
PY
  grep -q 'FLIP m48: assign by adding a row' "$copy/skills/teamsmith/scripts/lib/common.sh" || { printf '  ✗ assign：补丁没写进去\n' >&2; return 2; }
  bash -n "$copy/skills/teamsmith/scripts/lib/common.sh" || { printf '  ✗ assign：补丁把脚本改坏了\n' >&2; return 2; }

  local mutated_log="$TMP/assign-flipped.log" real_log="$TMP/assign-now.log"
  build_probe "$TMP/probe-assign-mutated.sh" "$copy/skills/teamsmith" || return 2
  build_probe "$TMP/probe-assign-real.sh" "$SKILL_DIR" || return 2
  run_probe "$TMP/probe-assign-mutated.sh" "$mutated_log"; local mrc=$?
  run_probe "$TMP/probe-assign-real.sh" "$real_log"; local rrc=$?
  grep -q '^PROBE-M48-END$' "$mutated_log" || { printf '  ✗ assign：翻转侧探针没跑完（%s）\n' "$(tail -1 "$mutated_log")" >&2; return 2; }
  grep -q '^PROBE-M48-END$' "$real_log" || { printf '  ✗ assign：真树侧探针没跑完（%s）\n' "$(tail -1 "$real_log")" >&2; return 2; }
  printf '  翻转 skill 的 §4c：rc=%s（✗ %s 条）｜真树 §4c：rc=%s（✗ %s 条）\n' \
    "$mrc" "$(plain "$mutated_log" | grep -ac '^  .*✗' || true)" "$rrc" "$(plain "$real_log" | grep -ac '^  .*✗' || true)"

  local want="" l
  for l in '✗ M48：assign 后行数不变（不是又加一行）' '✗ M48：assign 后 T1.1 仍是两行（没有顺手改历史数据）'; do
    plain "$mutated_log" | grep -qF -- "$l" || want="$want
     $l"
  done
  if [ -n "$want" ]; then
    fail "assign：翻转（指派改成再写一行）没有红在预期断言上：$want"
    plain "$mutated_log" | grep -aE '^  .*✗' | sed 's/^/      /' | head -10
  else
    pass "assign：翻转（指派 = 再写一行）→ 行数/去重断言变红（守卫真的咬在「原地改」上）"
  fi
  if [ "$rrc" -eq 0 ] && ! plain "$real_log" | grep -q '^  .*✗'; then
    pass "assign：真树（原地改 agent）在同一探针上全绿"
  else
    fail "assign：真树在 §4c 探针上有失败项（rc=$rrc）"
    plain "$real_log" | grep -aE '^  .*✗' | sed 's/^/      /' | head -10
  fi
  return 0
}

case "$mode" in
  focus) flip_focus || RC=1 ;;
  add)   flip_add || RC=1 ;;
  assign) flip_assign || RC=1 ;;
  all)
    flip_focus || RC=1
    printf '\n'
    flip_add || RC=1
    printf '\n'
    flip_assign || RC=1
    ;;
esac

printf '\n'
if [ "$RC" -eq 0 ]; then
  printf '\033[32mflip-m48 全部成立\033[0m\n'
else
  printf '\033[31mflip-m48 有翻转不成立\033[0m\n'
fi
exit "$RC"
