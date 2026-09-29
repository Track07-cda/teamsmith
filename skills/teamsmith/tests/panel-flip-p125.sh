#!/usr/bin/env bash
# panel-flip-p125.sh — the break/fix flips for P125 (change panel-board-cards, panel delta).
#
#   bash skills/teamsmith/tests/panel-flip-p125.sh                 # both flips
#   bash skills/teamsmith/tests/panel-flip-p125.sh F-INPLACE      # selected flips
#
# Each flip copies `panel/src` to a scratch tree, patches it, builds a mutant bundle with the pinned
# bun, and runs the same P125 frame checks against the mutant (they must go red) and against the
# committed bundle (they must be green). The working tree's sources are never touched — the mutant
# lives in the scratch tree, and the committed `panel.js` is compared byte for byte at the end.
#
# Flips:
#   F-INPLACE    the side-by-side tier keeps the pre-P125 in-place folded line (natural width, no
#                three-column frame) → "folding gives the columns back" reds.
#   F-FRAME99    the grouped tier draws the three-column frame instead of the in-place single line
#                → "a narrow pane saves rows" reds.
#
# Exit: 0 every selected flip behaved, 1 at least one flip did not, 3 setup failure.
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
tmp="$(tmp_root_create panel-flip-p125)" || exit 3
PASS=0
FAIL=0
cleanup() { [ "${BASHPID:-$$}" = "$$" ] || return 0; tmp_root_reap_all; }
trap cleanup EXIT

ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }

SECTIONS=("$@")
[ "${#SECTIONS[@]}" -gt 0 ] || SECTIONS=(F-INPLACE F-FRAME99)
want() { local s; for s in "${SECTIONS[@]}"; do [ "$s" = "$1" ] && return 0; done; return 1; }

[ -x "$bun_bin" ] || { printf 'panel-flip-p125: bun is required (rebuilds the mutant bundle)\n' >&2; exit 3; }
[ -n "$js" ] || { printf 'panel-flip-p125: node or bun is required (runs the frames)\n' >&2; exit 3; }
[ -d "$panel_dir/node_modules" ] || { printf 'panel-flip-p125: run `bun install --frozen-lockfile` in scripts/panel first\n' >&2; exit 3; }
[ -f "$stub" ] || { printf 'panel-flip-p125: missing %s\n' "$stub" >&2; exit 3; }

ink_pin="$(sed -n 's/.*"ink": *"\([^"]*\)".*/\1/p' "$panel_dir/package.json")"
react_pin="$(sed -n 's/.*"react": *"\([^"]*\)".*/\1/p' "$panel_dir/package.json")"
[ -n "$ink_pin" ] && [ -n "$react_pin" ] || { printf 'panel-flip-p125: cannot read the pins\n' >&2; exit 3; }

committed_sha_before="$(sha256sum "$committed" | cut -d' ' -f1)"

# ---------------------------------------------------------------- the P125 frame checks
# The probe is one python program over a rendered `--snapshot` frame; each mode prints `ok` or the
# concrete problem, so the same function is the green side (committed bundle) and the red side
# (mutant) — a flip cannot pass by moving the yardstick.
p125_probe() {
  python3 - "$@" <<'PYP'
import re, sys

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

def slice_dw(text, start, n):
    out, pos = [], 0
    for ch in text:
        w = chw(ch)
        if start <= pos < start + n:
            out.append(ch)
        pos += w
        if pos >= start + n:
            break
    return "".join(out)

def read(path):
    return [l.rstrip("\n") for l in open(path, encoding="utf-8")]

mode = sys.argv[1]
problems = []

if mode == "wide":
    path, limit, folded, shown_w = sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
    rows = read(path)
    over = [(i + 1, dw(r)) for i, r in enumerate(rows) if dw(r) > limit]
    if over:
        problems.append(f"行超过 {limit} 列：{over[:2]}")
    top = next((i for i, r in enumerate(rows) if "╭─" in r), -1)
    if top < 0:
        problems.append("没有车道行（找不到 ╭─）")
    else:
        row = rows[top]
        frames = [dw(row[:m.start()]) for m in re.finditer("╭─╮", row)]
        if len(frames) != folded:
            problems.append(f"三列小框 {len(frames)} 个，期望 {folded}")
        if "（已折叠）" in row:
            problems.append("宽档还画了原地折叠行")
        for x in frames:
            cells, i = [], top
            while i < len(rows):
                cells.append(slice_dw(rows[i], x, 3))
                i += 1
                if cells[-1] == "╰─╯":
                    break
            if cells[0] != "╭─╮" or cells[-1] != "╰─╯":
                problems.append(f"框的角落 {cells[0]!r}..{cells[-1]!r}")
            body = cells[1:-1]
            if not body or not all(c in ("│…│", "│⋮│", "│›│") for c in body):
                problems.append(f"框体 {set(body)}")
            mid = [j for j, c in enumerate(body) if c == "│⋮│"]
            want = (len(body) - 1) // 2
            if mid != [want]:
                problems.append(f"竖省略号在 {mid} 行，期望 [{want}]（共 {len(body)} 行）")
        if shown_w > 0:
            m = re.search("╭─ ▾ 完成", row)
            if not m:
                problems.append("没有展开的 done 盒子")
            else:
                x = dw(row[:m.start()])
                j = next(j for j in range(x, dw(row)) if slice_dw(row, j, 1) == "╮")
                if j - x + 1 != shown_w:
                    problems.append(f"展开车道宽 {j - x + 1}，期望 {shown_w}")

elif mode == "grouped":
    path, limit = sys.argv[2], int(sys.argv[3])
    rows = read(path)
    over = [(i + 1, dw(r)) for i, r in enumerate(rows) if dw(r) > limit]
    if over:
        problems.append(f"行超过 {limit} 列：{over[:2]}")
    if any("╭" in r for r in rows):
        problems.append("分组档出现了三列小框的圆角")
    if not any("（已折叠）" in r for r in rows):
        problems.append("没有原地折叠行")

elif mode == "focus":
    rows = read(sys.argv[2])
    top = next((i for i, r in enumerate(rows) if "╭─" in r), -1)
    if top < 0:
        problems.append("没有车道行")
    else:
        cells, i = [], top
        while i < len(rows):
            cells.append(slice_dw(rows[i], 0, 3))
            i += 1
            if cells[-1] == "╰─╯":
                break
        if not cells or cells[0] != "╭─╮":
            problems.append("首车道不是三列小框")
        elif cells[1] != "│›│":
            problems.append(f"聚焦框内第一行为 {cells[1]!r}，期望 │›│")
    if sum(r.count("›") for r in rows) != 1:
        problems.append("焦点光标不是恰好一个")
    if "待办 1" not in rows[-1]:
        problems.append("底栏没有给出被聚焦折叠车道的标签与计数")
    if any("V14" in r for r in rows):
        problems.append("折叠车道仍渲染卡片")

elif mode == "rows":
    folded, unfolded = read(sys.argv[2]), read(sys.argv[3])
    if any("╭" in r for r in folded):
        problems.append("分组档的折叠车道画了三列小框（那里折叠要省行）")
    if not any("已放弃" in r for r in folded):
        problems.append("折叠 done 后「已放弃」没有进入窗口（没有省下行）")
    if any("已放弃" in r for r in unfolded):
        problems.append("展开 done 时「已放弃」也在窗口里（对照无效）")

print("ok" if not problems else "；".join(problems))
PYP
}

frame_checks() { # <panel.js> <dir>
  local p="$1" d="$2" rc=0 verdict
  mkdir -p "$d/root/state"
  render() { # <out> <w> <h> [conf...]
    local out="$1" w="$2" h="$3"; shift 3
    rm -f "$d/root/state/panel.conf"
    [ $# -gt 0 ] && printf '%s\n' "$@" >"$d/root/state/panel.conf"
    # Redirect + sed, never a pipe: the panel exits right after its write and a piped reader can
    # lose the tail. The assertions read visible text, so the tone SGR bytes are stripped here.
    ( cd "$d" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
        "$js" "$p" --snapshot --root "$d/root" --state-dir "$d/root/state" \
        --team-cli "$stub" --lang zh --theme dark --width "$w" --height "$h" --page 4 ) >"$out.raw" 2>/dev/null
    sed 's/\x1b\[[0-9;]*m//g' "$out.raw" >"$out"
  }
  check() { # <probe...> <label>
    local label="${*: -1}" out
    local probe=("${@:1:$#-1}")
    out="$(p125_probe "${probe[@]}")"
    if [ "$out" = "ok" ]; then
      printf '  \033[32m✓\033[0m %s\n' "$label"
    else
      printf '  \033[31m✗\033[0m %s（%s）\n' "$label" "$out"; rc=1
    fi
  }
  # 1) the wide tier: two empty lanes folded by default = two three-column frames; the four shown
  # lanes take (185 - 3*2)/4 = 44 columns each (the even share is 30) and no line overruns 190.
  render "$d/w190.txt" 190 32
  check wide "$d/w190.txt" 190 2 44 "宽档 190：两个三列小框、四条展开车道各 44 列、不超宽"
  # 2) all six folded: six frames, still bounded.
  render "$d/w190all.txt" 190 32 "boardFold=todo,wip,review,done,blocked,dropped"
  check wide "$d/w190all.txt" 190 6 -1 "宽档 190 全折叠：六个三列小框、行不超宽"
  # 3) the grouped tier keeps the in-place single line and never draws the frame.
  render "$d/g99.txt" 99 32
  check grouped "$d/g99.txt" 99 "窄档 99：原地一行、无三列小框、行不超宽"
  # 4) a narrow pane saves rows: with done holding 20 cards the fold lets `已放弃` into the window.
  export B3_STUB_DONE=20
  render "$d/n99show.txt" 99 32 "boardShow=done"
  render "$d/n99fold.txt" 99 32 "boardFold=done"
  unset B3_STUB_DONE
  check rows "$d/n99fold.txt" "$d/n99show.txt" "窄屏省行：折叠 done（20 卡）让「已放弃」进入窗口，展开时进不来"
  # 5) a focused folded lane in the wide tier: the frame carries the cursor, the band names it.
  render "$d/focus.txt" 190 32 "boardFold=todo"
  check focus "$d/focus.txt" "聚焦折叠车道：框内 │›│、恰好一个光标、底栏「待办 1」、卡片不渲染"
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

# ---------------------------------------------------------------- the flips
if want F-INPLACE; then
  flip F-INPLACE 'p = f"{tree}/layout.ts"
s = open(p, encoding="utf-8").read()
old = "    return foldedLaneFrame(ctx, lane, focused, slots + 2)"
new = """    const out: PlacedLine[] = [foldedLaneLine(ctx, lane, cards.length, width, focused)] // FLIP P125
    while (out.length < slots + 2) out.push({ line: [] })
    return out"""
assert s.count(old) == 1, "anchor: the folded frame branch"
s = s.replace(old, new)
old2 = """    for (const lane of foldedLanes) widths.set(lane, FOLD_FRAME_W)
    const eachShown = Math.max(8, Math.floor((usable - FOLD_FRAME_W * foldedLanes.length) / shownLanes.length))"""
new2 = """    let spent = 0 // FLIP P125: the pre-frame algorithm — folded lanes take their line s width
    for (const lane of foldedLanes) {
      const w = Math.max(1, Math.min(dispWidth(foldedLaneHead(ctx.s, lane, laneCards(rows, lane).length)) + 2, 30))
      widths.set(lane, w)
      spent += w
    }
    const eachShown = Math.max(1, Math.floor((usable - spent) / shownLanes.length))"""
assert s.count(old2) == 1, "anchor: the folded width share"
open(p, "w", encoding="utf-8").write(s.replace(old2, new2))
' "宽档强行用原地一行（自然宽 11–12 列）"
fi

if want F-FRAME99; then
  flip F-FRAME99 'p = f"{tree}/layout.ts"
s = open(p, encoding="utf-8").read()
old = "      all.push(foldedLaneLine(ctx, lane, cards.length, width, focused))"
new = "      for (const l of foldedLaneFrame(ctx, lane, focused, 3)) all.push(l) // FLIP P125: the grouped tier draws the frame"
assert s.count(old) == 1, "anchor: the grouped fold branch"
open(p, "w", encoding="utf-8").write(s.replace(old, new))
' "窄档强行用三列小框（不再省行）"
fi

# ---------------------------------------------------------------- the committed bundle must be untouched
committed_sha_after="$(sha256sum "$committed" | cut -d' ' -f1)"
if [ "$committed_sha_before" = "$committed_sha_after" ]; then
  ok "翻转全程没有碰提交的 panel.js（sha256 不变）"
else
  bad "翻转改动了提交的 panel.js（$committed_sha_before → $committed_sha_after）"
fi

printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && { printf '\033[32mpanel-flip-p125 全绿\033[0m\n'; exit 0; }
printf '\033[31mpanel-flip-p125 有失败项\033[0m\n'
exit 1
