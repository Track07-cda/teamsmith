#!/usr/bin/env bash
# flip-p22.sh — the break/fix flips for the P22 console surface (B2 2.6, B3 3.4, B4 4.5).
#
#   bash skills/teamsmith/tests/flip-p22.sh
#
# Each flip edits the panel sources, rebuilds the committed bundle, runs one `panel-p21.sh` scenario and
# asserts it goes red, then restores the sources, rebuilds and asserts green + the bundle byte-identical.
# The worked build needs `panel/node_modules` (bun); without it the flip reports SKIP for the rebuild.
# Exit: 0 every flip behaved, 1 at least one flip did not, 3 setup failure.
set -uo pipefail

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$here/lib/tmp-root.sh"
tree="${TEAM_P21_TREE:-$(cd -P "$here/../../.." && pwd)}"
skill="$tree/skills/teamsmith"
src="$skill/scripts/panel/src"
bundle="$skill/scripts/panel/panel.js"
bun_bin="${BUN:-$(command -v bun || true)}"
[ -n "$bun_bin" ] || bun_bin="$HOME/.bun/bin/bun"
[ "${KEEP:-0}" = "1" ] && export TEAM_TMP_KEEP=1
tmp="$(tmp_root_create flip-p22)" || exit 3
PASS=0
FAIL=0
cleanup() { [ "${BASHPID:-$$}" = "$$" ] || return 0; tmp_root_reap_all; }
trap cleanup EXIT

ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }

[ -x "$bun_bin" ] || { printf 'flip-p22: bun is required (rebuilds the bundle)\n' >&2; exit 3; }
[ -d "$skill/scripts/panel/node_modules" ] || { printf 'flip-p22: run `bun install --frozen-lockfile` in scripts/panel first\n' >&2; exit 3; }

build() {
  BUN="$bun_bin" bash "$skill/scripts/panel/build.sh" >"$tmp/build.log" 2>&1 || { tail -3 "$tmp/build.log" >&2; return 1; }
}
run_scn() { # <scenario> <logfile>
  TEAM_P21_TREE="$tree" bash "$here/panel-p21.sh" "$1" >"$2" 2>&1
  return $?
}

sha_before="$(sha256sum "$bundle" | cut -d' ' -f1)"

# flip <name> <file> <python edit script> <scenario> <red assertion fragment>
flip() {
  local name="$1" file="$2" edit="$3" scn="$4" red_re="$5"
  cp "$file" "$tmp/$(basename "$file").orig"
  FLIP_EDIT="$edit" python3 - "$file" <<'PYEDIT'
import os, sys
exec(compile(os.environ["FLIP_EDIT"], "<flip>", "exec"))
PYEDIT
  if ! build; then bad "$name: 改过的源码构建失败"; cp "$tmp/$(basename "$file").orig" "$file"; build >/dev/null 2>&1; return; fi
  run_scn "$scn" "$tmp/$name-red.log"
  local rc_red=$?
  if [ "$rc_red" -ne 0 ] && grep -q '✗' "$tmp/$name-red.log"; then
    ok "$name：断掉之后 $scn 变红（rc=$rc_red）"
  else
    bad "$name：断掉之后 $scn 居然还是绿的（翻转失效）"
  fi
  if { grep -E '✗' "$tmp/$name-red.log" || true; } | grep -q -- "$red_re"; then
    ok "$name：红侧的失败点就是预期的那条（$red_re）"
  else
    bad "$name：红侧没有点到预期的那条（$red_re）"
  fi
  cp "$tmp/$(basename "$file").orig" "$file"
  if ! build; then bad "$name: 恢复后构建失败"; return; fi
  run_scn "$scn" "$tmp/$name-green.log"
  local rc_green=$?
  if [ "$rc_green" -eq 0 ]; then ok "$name：恢复之后 $scn 变绿"; else bad "$name：恢复之后 $scn 仍然红"; fi
  if [ "$(sha256sum "$bundle" | cut -d' ' -f1)" = "$sha_before" ]; then
    ok "$name：恢复后 bundle 与提交的逐字节一致"
  else
    bad "$name：恢复后 bundle 与提交的不一致"
  fi
  printf '      红侧尾部：\n'
  grep -E '✗' "$tmp/$name-red.log" | head -3 | sed 's/^/      /'
}

printf '\033[1m== flip-p22 · 三处断点（B2 2.6 / B3 3.4 / B4 4.5） ==\033[0m\n'

# 2.6 · the rejected second key table: hardcode three classes inside the bundle.
flip "2.6 键表硬编码" "$src/layout.ts" '
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "export function settingsClassLabel(s: Strings, cls: string): string {"
new = """export function settingsClassLabel(s: Strings, cls: string): string {
  // FLIP (rejected design): a second, hardcoded table inside the bundle.
  return cls"""
assert old in s
s = s.replace(old, new, 1)
open(p, "w", encoding="utf-8").write(s)
' settings 'scratch CLI 改过的类跟着变'

# 3.4 · drop the fingerprint pinned at editor-open time.
flip "3.4 丢掉指纹" "$src/main.tsx" '
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "    if (o.fingerprint) args.push(\u0027--fingerprint\u0027, o.fingerprint)\n    if (o.allowDanger) args.push(\u0027--allow-danger\u0027)"
new = "    if (o.allowDanger) args.push(\u0027--allow-danger\u0027)"
assert old in s
s = s.replace(old, new, 1)
open(p, "w", encoding="utf-8").write(s)
' conflict '回执点名指纹冲突'

# 4.5 · the rejected bare model name: print the model with no source badge.
flip "4.5 裸模型名" "$src/layout.ts" '
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "  const policy = seat.override ? s.seatOverride : s.seatFallback"
new = "  const policy = \u0027\u0027"
assert old in s
s = s.replace(old, new, 1)
s = s.replace("...settingsRight(ctx, `${model} · ${settingsSourceLabel(s, seat.source)} · ${policy}`, \u0027\u0027, \u0027dim\u0027, innerW).map((x) => x),",
              "...settingsRight(ctx, `${model}`, \u0027\u0027, \u0027dim\u0027, innerW).map((x) => x),", 1)
open(p, "w", encoding="utf-8").write(s)
' seats '历史记录'

printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0
exit 1
