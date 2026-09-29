#!/usr/bin/env bash
# panel-flip-p128.sh — the break/fix flip for P128 (change panel-board-cards, panel delta).
#
#   bash skills/teamsmith/tests/panel-flip-p128.sh                 # the flip
#   bash skills/teamsmith/tests/panel-flip-p128.sh F-COLUMN        # same, named
#
# Copies `panel/src` to a scratch tree, patches the grouped tier's in-place folded line back to the
# lane-header column (the pre-P128 shape), builds the mutant bundle with the pinned bun, and runs
# the P128 checks against the mutant (they must go red) and against the committed bundle (they must
# be green). The working tree's sources are never touched — the mutant lives in the scratch tree —
# and the committed `panel.js` is compared byte for byte at the end.
#
# The checks are the delta scenario "The in-place folded line lines up with the cards it replaces"
# (the folded line's marker in the cards' state-glyph column, the focus cursor in the cards' cursor
# column, the lane header still in its own column) plus the existing narrow-tier shape checks
# (in place, no three-column frame, rows bounded) as the control group.
#
# Flip:
#   F-COLUMN   the folded line hangs at the lane-header column again (no leading indent, no cursor
#              column) → the two alignment checks red, the narrow shape checks stay green.
#
# Exit: 0 the flip behaved, 1 it did not, 3 setup failure.
set -uo pipefail

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$here/lib/tmp-root.sh"
tree="$(cd -P "$here/../../.." && pwd)"
skill="$tree/skills/teamsmith"
panel_dir="$skill/scripts/panel"
src="$panel_dir/src"
stub="$here/panel-b3-stub.sh"
committed="$panel_dir/panel.js"
bun_bin="${BUN:-$(command -v bun || true)}"
[ -n "$bun_bin" ] || bun_bin="$HOME/.bun/bin/bun"
js="$(command -v node || command -v bun || true)"
tmp="$(tmp_root_create panel-flip-p128)" || exit 3
PASS=0
FAIL=0
cleanup() { [ "${BASHPID:-$$}" = "$$" ] || return 0; tmp_root_reap_all; }
trap cleanup EXIT

ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }

SECTIONS=("$@")
[ "${#SECTIONS[@]}" -gt 0 ] || SECTIONS=(F-COLUMN)
want() { local s; for s in "${SECTIONS[@]}"; do [ "$s" = "$1" ] && return 0; done; return 1; }

[ -x "$bun_bin" ] || { printf 'panel-flip-p128: bun is required (rebuilds the mutant bundle)\n' >&2; exit 3; }
[ -n "$js" ] || { printf 'panel-flip-p128: node or bun is required (runs the frames)\n' >&2; exit 3; }
[ -d "$panel_dir/node_modules" ] || { printf 'panel-flip-p128: run `bun install --frozen-lockfile` in scripts/panel first\n' >&2; exit 3; }
[ -f "$stub" ] || { printf 'panel-flip-p128: missing %s\n' "$stub" >&2; exit 3; }

ink_pin="$(sed -n 's/.*"ink": *"\([^"]*\)".*/\1/p' "$panel_dir/package.json")"
react_pin="$(sed -n 's/.*"react": *"\([^"]*\)".*/\1/p' "$panel_dir/package.json")"
[ -n "$ink_pin" ] && [ -n "$react_pin" ] || { printf 'panel-flip-p128: cannot read the pins\n' >&2; exit 3; }

committed_sha_before="$(sha256sum "$committed" | cut -d' ' -f1)"

# ---------------------------------------------------------------- the P128 frame checks
# One python program over a rendered `--snapshot` frame; each mode prints `ok` or the concrete
# problem, so the same function is the green side (committed bundle) and the red side (mutant) —
# the flip cannot pass by moving the yardstick. Columns are display columns (CJK = 2).
p128_probe() {
  python3 - "$@" <<'PYP'
import sys

WIDE = [(0x1100, 0x115f), (0x2e80, 0x303e), (0x3041, 0x33ff), (0x3400, 0x4dbf), (0x4e00, 0x9fff),
        (0xa000, 0xa4cf), (0xac00, 0xd7a3), (0xf900, 0xfaff), (0xfe10, 0xfe19), (0xfe30, 0xfe6f),
        (0xff00, 0xff60), (0xffe0, 0xffe6), (0x1f300, 0x1f64f), (0x1f900, 0x1f9ff)]

def chw(ch):
    cp = ord(ch)
    if cp in (0x200d, 0xfe0f) or 0x0300 <= cp <= 0x036f:
        return 0
    return 2 if any(a <= cp <= b for a, b in WIDE) else 1

def dw(text):
    return sum(chw(c) for c in text)

def col_of(row, ch):
    pos = 0
    for c in row:
        if c == ch:
            return pos
        pos += chw(c)
    return -1

def read(path):
    return [l.rstrip("\n") for l in open(path, encoding="utf-8")]

mode = sys.argv[1]
problems = []

if mode == "grouped":
    path, limit = sys.argv[2], int(sys.argv[3])
    rows = read(path)
    over = [(i + 1, dw(r)) for i, r in enumerate(rows) if dw(r) > limit]
    if over:
        problems.append(f"行超过 {limit} 列：{over[:2]}")
    if any("╭" in r for r in rows):
        problems.append("分组档出现了三列小框的圆角")
    if not any("（已折叠）" in r for r in rows):
        problems.append("没有原地折叠行")

elif mode == "align":
    path, kind = sys.argv[2], sys.argv[3]
    rows = read(path)
    folded = [r for r in rows if "（已折叠）" in r]

    def find(sub):
        return next((r for r in rows if sub in r), "")

    # ① the unfolded lane header keeps its own marker column (`' ' + ▾`).
    head = find("▾ 进行")
    if not head:
        problems.append("没有展开的 `▾ 进行` 车道头")
    elif col_of(head, "▾") != 1:
        problems.append(f"车道头 ▾ 在第 {col_of(head, '▾')} 列，期望 1：{head!r}")
    # ② an unfocused card's state glyph sits in column 3.
    card = find("P14")
    if not card:
        problems.append("没有 P14 卡片行")
    elif col_of(card, "▸") != 3:
        problems.append(f"卡片 ▸ 在第 {col_of(card, '▸')} 列，期望 3：{card!r}")
    # ③ every in-place folded line's marker sits in column 3 (the cards' glyph column).
    if not folded:
        problems.append("没有原地折叠行")
    for r in folded:
        at = col_of(r, "▸")
        if at != 3:
            problems.append(f"折叠行 ▸ 在第 {at} 列，期望 3（卡片字形列）：{r!r}")
    # ④ exactly one focus cursor; its column matches the focused card's cursor column.
    cursors = sum(r.count("›") for r in rows)
    if cursors != 1:
        problems.append(f"焦点光标应当恰好一个，实际 {cursors}")
    if kind == "plain":
        v14 = find("V14")
        if not v14:
            problems.append("plain 帧没有 V14 聚焦卡片行")
        elif col_of(v14, "›") != 1 or col_of(v14, "·") != 3:
            problems.append(f"聚焦卡片 › 在第 {col_of(v14, '›')} 列 / · 在第 {col_of(v14, '·')} 列，期望 1/3：{v14!r}")
    else:
        fr = next((r for r in folded if "›" in r), "")
        if not fr:
            problems.append("focus 帧的折叠行没有光标（焦点没落在折叠车道上）")
        elif col_of(fr, "›") != 1:
            problems.append(f"聚焦折叠行 › 在第 {col_of(fr, '›')} 列，期望 1（与聚焦卡片同列）：{fr!r}")
        if "待办 1" not in fr:
            problems.append(f"聚焦折叠行没有标签与计数：{fr!r}")

print("ok" if not problems else "；".join(problems))
PYP
}

frame_checks() { # <panel.js> <dir>
  local p="$1" d="$2" rc=0 verdict
  mkdir -p "$d/root/state"
  render() { # <out> <w> <conf line…>
    local out="$1" w="$2"; shift 2
    rm -f "$d/root/state/panel.conf"
    [ $# -gt 0 ] && printf '%s\n' "$@" >"$d/root/state/panel.conf"
    ( cd "$d" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
        "$js" "$p" --snapshot --root "$d/root" --state-dir "$d/root/state" \
        --team-cli "$stub" --lang zh --theme dark --width "$w" --height 32 --page 4 ) >"$out.raw" 2>/dev/null
    sed 's/\x1b\[[0-9;]*m//g' "$out.raw" >"$out"
  }
  check() { # <probe…> <label>
    local label="${*: -1}" out
    local probe=("${@:1:$#-1}")
    out="$(p128_probe "${probe[@]}")"
    if [ "$out" = "ok" ]; then
      printf '  \033[32m✓\033[0m %s\n' "$label"
    else
      printf '  \033[31m✗\033[0m %s（%s）\n' "$label" "$out"; rc=1
    fi
  }
  # The control group: the existing narrow-tier shape checks (in place, no frame, bounded).
  render "$d/plain99.txt" 99
  check grouped "$d/plain99.txt" 99 "窄档 99：原地一行、无三列小框、行不超宽（既有场景复跑）"
  render "$d/plain60.txt" 60
  check grouped "$d/plain60.txt" 60 "窄档 60（PM 现场档）：原地一行、无三列小框、行不超宽"
  # The scenario under test: the folded line's columns. Plain frame: the focus is on V14's card.
  check align "$d/plain99.txt" plain "对齐 99：车道头 ▾ 第 1 列 / 卡片字形第 3 列 / 折叠行标记第 3 列"
  check align "$d/plain60.txt" plain "对齐 60：同 99 —— 折叠行落在卡片列"
  # A folded lane the focus lives in: the cursor takes the card rows' cursor column.
  render "$d/focus99.txt" 99 "boardFold=todo"
  check align "$d/focus99.txt" focus "聚焦折叠行：光标第 1 列（与聚焦卡片同列）、标记第 3 列、恰好一个光标"
  return $rc
}

# ---------------------------------------------------------------- the mutant build
build_mutant() { # <name> <edit script>
  local name="$1" edit="$2" tree="$tmp/$1"
  rm -rf "$tree"; mkdir -p "$tree"
  cp -r "$src/." "$tree/"
  ln -sfn "$panel_dir/node_modules" "$tree/node_modules"
  if ! FLIP_EDIT="$edit" FLIP_TREE="$tree" python3 - <<'PYEDIT'
import os
tree = os.environ["FLIP_TREE"]
exec(compile(os.environ["FLIP_EDIT"], "<flip>", "exec"))
PYEDIT
  then
    printf '  \033[31m✗\033[0m %s：源码断点没打上\n' "$name"
    return 1
  fi
  ( cd "$panel_dir" && "$bun_bin" build "$tree/main.tsx" --target=node --format=esm --minify \
      --define "__PIN_INK__=\"$ink_pin\"" --define "__PIN_REACT__=\"$react_pin\"" \
      --outfile "$tmp/$name.js" ) >"$tmp/$name-build.log" 2>&1 || {
    printf '  \033[31m✗\033[0m %s：突变的 bundle 构建失败\n' "$name"; tail -3 "$tmp/$name-build.log" >&2; return 1
  }
  return 0
}

# <name> <edit script> <what the flip breaks>
flip() {
  local name="$1" edit="$2" what="$3"
  printf '\n\033[1m== %s：%s ==\033[0m\n' "$name" "$what"
  build_mutant "$name" "$edit" || { FAIL=$((FAIL + 1)); return; }
  local green="$tmp/$name-green.log" red="$tmp/$name-red.log"
  frame_checks "$committed" "$tmp/$name-green-dir" >"$green" 2>&1; local green_rc=$?
  frame_checks "$tmp/$name.js" "$tmp/$name-red-dir" >"$red" 2>&1; local red_rc=$?
  if [ "$green_rc" -eq 0 ]; then
    ok "$name：提交的 bundle 上同一组检查绿"
  else
    bad "$name：提交的 bundle 上基线就红了（检查本身坏了）"; sed 's/^/      /' "$green" | grep '✗' | head -3
  fi
  if [ "$red_rc" -ne 0 ] && grep -q '✗' "$red"; then
    ok "$name：突变之后变红（$(grep -c '✗' "$red") 条；$(grep '✗' "$red" | head -1 | sed 's/^ *✗ *//' | cut -c1-70)）"
  else
    bad "$name：突变之后居然还是绿的（翻转失效）"; sed 's/^/      /' "$red"
  fi
}

# ---------------------------------------------------------------- the flip
if want F-COLUMN; then
  flip F-COLUMN 'p = f"{tree}/layout.ts"
s = open(p, encoding="utf-8").read()
old = """    seg(\x27 \x27),
    seg(focused ? `${FOCUS_CURSOR} ` : \x27  \x27, focused ? \x27selected\x27 : \x27dim\x27),"""
new = """    seg(focused ? `${FOCUS_CURSOR} ` : \x27\x27, \x27selected\x27), // FLIP P128: back to the lane-header column"""
assert s.count(old) == 1, "anchor: the card-column indent"
open(p, "w", encoding="utf-8").write(s.replace(old, new))
' "把折叠行改回车道头那一列（去掉卡片列缩进与光标列）"
fi

# ---------------------------------------------------------------- the committed bundle must be untouched
committed_sha_after="$(sha256sum "$committed" | cut -d' ' -f1)"
if [ "$committed_sha_before" = "$committed_sha_after" ]; then
  ok "翻转全程没有碰提交的 panel.js（sha256 不变）"
else
  bad "翻转改动了提交的 panel.js（$committed_sha_before → $committed_sha_after）"
fi

printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && { printf '\033[32mpanel-flip-p128 全绿\033[0m\n'; exit 0; }
printf '\033[31mpanel-flip-p128 有失败项\033[0m\n'
exit 1
