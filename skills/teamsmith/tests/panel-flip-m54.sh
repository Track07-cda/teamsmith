#!/usr/bin/env bash
# panel-flip-m54.sh — the break/fix flips for M55's console half (`settings-choice-editors`, panel delta).
#
#   bash skills/teamsmith/tests/panel-flip-m54.sh                 # every flip
#   bash skills/teamsmith/tests/panel-flip-m54.sh F-B A2-enum     # selected flips
#
# Each flip edits the panel sources, rebuilds the committed bundle, runs one `panel-p21.sh` scenario
# and asserts it goes red, then restores the sources, rebuilds and asserts green plus the bundle
# byte-identical. The worked build needs `panel/scripts/node_modules` (bun); without it the flip
# reports the rebuild as a setup failure (exit 3), like flip-p22.sh.
#
# F-B     — the bundle's `choices` reader is disabled (the console keeps its own option table) → the
#           picker never opens → the choices scenario red.
# F-C     — the machine's Pi model catalogue becomes an option (the retired `sub2api` provider) →
#           the picker's model list carries a provider the project never configured → red.
# A2-enum — a hardcoded key table names the enums it knows (`TEAM_ZZZ_MODE`, added only to a scratch
#           CLI's schema, is not among them) → the zero-rebuild scenario red; restored, the very
#           same committed bundle offers the new key's `constraints` and degrades visibly when they
#           are removed.
#
# Exit: 0 every selected flip behaved, 1 at least one flip did not, 3 setup failure.
set -uo pipefail

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tree="${TEAM_P21_TREE:-$(cd -P "$here/../../.." && pwd)}"
skill="$tree/skills/teamsmith"
src="$skill/scripts/panel/src"
bundle="$skill/scripts/panel/panel.js"
bun_bin="${BUN:-$(command -v bun || true)}"
[ -n "$bun_bin" ] || bun_bin="$HOME/.bun/bin/bun"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/panel-flip-m54.XXXXXX")"
PASS=0
FAIL=0
cleanup() { [ "${BASHPID:-$$}" = "$$" ] || return 0; rm -rf "$tmp"; }
trap cleanup EXIT

ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }

SECTIONS=("$@")
[ "${#SECTIONS[@]}" -gt 0 ] || SECTIONS=(F-B F-C A2-enum)
want() { local s; for s in "${SECTIONS[@]}"; do [ "$s" = "$1" ] && return 0; done; return 1; }

[ -x "$bun_bin" ] || { printf 'panel-flip-m54: bun is required (rebuilds the bundle)\n' >&2; exit 3; }
[ -d "$skill/scripts/panel/node_modules" ] || { printf 'panel-flip-m54: run `bun install --frozen-lockfile` in scripts/panel first\n' >&2; exit 3; }

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
  if ! FLIP_EDIT="$edit" python3 - "$file" <<'PYEDIT'
import os, sys
exec(compile(os.environ["FLIP_EDIT"], "<flip>", "exec"))
PYEDIT
  then
    bad "$name: 源码断点没打上（edit 脚本失败）"
    cp "$tmp/$(basename "$file").orig" "$file"
    return
  fi
  if ! build; then bad "$name: 改过的源码构建失败"; cp "$tmp/$(basename "$file").orig" "$file"; build >/dev/null 2>&1; return; fi
  run_scn "$scn" "$tmp/$name-red.log"
  local rc_red=$?
  if [ "$rc_red" -ne 0 ] && grep -q '✗' "$tmp/$name-red.log"; then
    ok "$name：断掉之后 $scn 变红（rc=$rc_red）"
  else
    bad "$name：断掉之后 $scn 居然还是绿的（翻转失效）"
  fi
  # M59: `{ … || true; } | grep -q` — grep -q exits on the first match and grep(1) then dies on
  # SIGPIPE; under `set -o pipefail` the pipeline would report 141 and a REAL match would read as
  # a miss (exposed by the bigger red logs M59's failure scenes produce).
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
  { grep -E '✗' "$tmp/$name-red.log" || true; } | head -3 | sed 's/^/      /'
}

printf '\033[1m== panel-flip-m54 · 控制台三处断点（F-B choices 读取 / F-C 机器目录 / A2 硬编码键表） ==\033[0m\n'

# F-B · the rejected design: the bundle ignores the command's `choices` object.
if want F-B; then
  flip "F-B choices 读取被断掉" "$src/App.tsx" '
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "  const ch = key.choices\n  if (!ch || typeof ch !== \u0027object\u0027 || !Array.isArray(ch.values)) return false"
new = "  const ch = key.choices\n  if (true) return false // FLIP(F-B): the rejected design — the bundle keeps its own option table"
assert old in s, "找不到 choices 读取那一行"
s = s.replace(old, new, 1)
open(p, "w", encoding="utf-8").write(s)
' choices '保持未设'
fi

# F-C · the rejected source: the machine Pi catalogue becomes an option.
if want F-C; then
  flip "F-C 机器目录泄漏进选择器" "$src/App.tsx" '
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "      const base = key.set ? key.value : \u0027\u0027"
new = """      const base = key.set ? key.value : \u0027\u0027
      if (kind === \u0027model\u0027) { out.push({ value: \u0027sub2api/gpt-5.6-luna\u0027, kind: \u0027value\u0027 }); seen.add(\u0027sub2api/gpt-5.6-luna\u0027) } // FLIP(F-C)"""
assert old in s, "找不到 buildChoiceEntries 的 base 行"
s = s.replace(old, new, 1)
open(p, "w", encoding="utf-8").write(s)
' choices 'sub2api'
fi

# A2-enum · the rejected design: a per-key option table inside the bundle (a new enum key gets none).
if want A2-enum; then
  flip "A2 硬编码键表" "$src/App.tsx" '
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "      const values = (Array.isArray(ch.values) ? ch.values : []).map((v) => String(v))"
new = """      const values = (Array.isArray(ch.values) ? ch.values : []).map((v) => String(v))
      // FLIP(A2): the rejected design — a hardcoded key table inside the bundle
      if (kind === \u0027enum\u0027 && ![\u0027TEAM_MONITOR_UI\u0027, \u0027TEAM_BRANCH_MODE\u0027, \u0027TEAM_VCS\u0027].includes(key.name)) return []"""
assert old in s, "找不到 values 行"
s = s.replace(old, new, 1)
open(p, "w", encoding="utf-8").write(s)
' choices-schema '新增 enum 键的选择器没有打开'
fi

printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0
exit 1
