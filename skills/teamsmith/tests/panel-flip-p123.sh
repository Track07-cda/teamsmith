#!/usr/bin/env bash
# panel-flip-p123.sh — the break/fix flips for P123 (change panel-board-cards, panel delta).
#
#   bash skills/teamsmith/tests/panel-flip-p123.sh            # every flip
#   bash skills/teamsmith/tests/panel-flip-p123.sh F-ORDER    # selected flips
#
# Each flip copies `panel/src` to a scratch tree, patches it, builds a mutant bundle with the pinned
# bun, and runs the same P123 frame checks against the mutant (they must go red) and against the
# committed bundle (they must be green). The working tree's sources are never touched — the mutant
# lives in the scratch tree, and the committed `panel.js` is compared byte for byte at the end.
#
# Flips:
#   F-ORDER    the card line carries the agent again before the title (the pre-P123 line) → the
#              card-line check reds.
#   F-CARDS    the fold branch falls through to the card loop (folded lanes render cards) → the
#              folded-lane check reds.
#   F-PERSIST  the `c` toggle writes nothing to panel.conf → the b3 restart assertion reds.
#   F-MACHINE  the machine text frame reads panel.conf's fold keys → the two prints differ.
#   F-EMPTY    DEFAULT_SETTINGS.boardEmptyFold=false → the empty-lane default check reds.
#   F-WIDTH    the width algorithm ignores the fold (every lane keeps the even share) → the width
#              re-share check reds.
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
src_tree="$tree/skills/teamsmith/tests"
stub="$src_tree/panel-b3-stub.sh"
committed="$panel_dir/panel.js"
bun_bin="${BUN:-$(command -v bun || true)}"
[ -n "$bun_bin" ] || bun_bin="$HOME/.bun/bin/bun"
js="$(command -v node || command -v bun || true)"
tmp="$(tmp_root_create panel-flip-p123)" || exit 3
PASS=0
FAIL=0
cleanup() { [ "${BASHPID:-$$}" = "$$" ] || return 0; tmp_root_reap_all; }
trap cleanup EXIT

ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }

SECTIONS=("$@")
[ "${#SECTIONS[@]}" -gt 0 ] || SECTIONS=(F-ORDER F-CARDS F-PERSIST F-MACHINE F-EMPTY F-WIDTH)
want() { local s; for s in "${SECTIONS[@]}"; do [ "$s" = "$1" ] && return 0; done; return 1; }

[ -x "$bun_bin" ] || { printf 'panel-flip-p123: bun is required (rebuilds the mutant bundle)\n' >&2; exit 3; }
[ -n "$js" ] || { printf 'panel-flip-p123: node or bun is required (runs the frames)\n' >&2; exit 3; }
[ -d "$panel_dir/node_modules" ] || { printf 'panel-flip-p123: run `bun install --frozen-lockfile` in scripts/panel first\n' >&2; exit 3; }
[ -f "$stub" ] || { printf 'panel-flip-p123: missing %s\n' "$stub" >&2; exit 3; }

ink_pin="$(sed -n 's/.*"ink": *"\([^"]*\)".*/\1/p' "$panel_dir/package.json")"
react_pin="$(sed -n 's/.*"react": *"\([^"]*\)".*/\1/p' "$panel_dir/package.json")"
[ -n "$ink_pin" ] && [ -n "$react_pin" ] || { printf 'panel-flip-p123: cannot read the pins\n' >&2; exit 3; }

committed_sha_before="$(sha256sum "$committed" | cut -d' ' -f1)"

# ---------------------------------------------------------------- the P123 frame checks
# <panel.js> <workdir> → prints one ✓/✗ line per property; exit 1 when any property is red. The
# same function is the green side (committed bundle) and the red side (mutant), so a flip cannot
# pass by changing the yardstick.
frame_checks() { # <panel.js> <dir>
  local p="$1" d="$2" rc=0
  mkdir -p "$d/root/state"
  render() { # <out> <w> <h> <conf...>
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
  machine() { # <out> <conf>
    local out="$1"
    printf '%s\n' "$2" >"$d/root/state/panel.conf"
    ( cd "$d" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
        "$js" "$p" --print --page 4 --root "$d/root" --state-dir "$d/root/state" --team-cli "$stub" ) >"$out.raw" 2>/dev/null
    sed -E 's/[0-9]{2}:[0-9]{2}:[0-9]{2}/TT/g' "$out.raw" >"$out"
  }
  local row band wip_before wip_after
  # 1) the card line: no agent/phase field, the pair on the key band (the degradation order's head).
  render "$d/default.txt" 160 32
  row="$(grep -a 'V14' "$d/default.txt" | head -1)"
  if printf '%s' "$row" | grep -qE ' (verify|apply) '; then
    printf '  \033[31m✗\033[0m 卡片行仍带 agent/phase：%s\n' "$(printf '%s' "$row" | cut -c1-80)"; rc=1
  elif grep -aqF 'verify · verify' "$d/default.txt"; then
    printf '  \033[32m✓\033[0m 卡片只留序号+标题，焦点卡的对在键位带上\n'
  else
    printf '  \033[31m✗\033[0m 键位带没有焦点卡的 agent · phase 对\n'; rc=1
  fi
  # 2) folding builds no card rows (and the folded line carries the count).
  render "$d/folddone.txt" 160 32 "boardFold=done"
  if grep -aqF '▸ 完成 8（已折叠）' "$d/folddone.txt" && ! grep -aqF 'P13' "$d/folddone.txt"; then
    printf '  \033[32m✓\033[0m 折叠的 done 一行带计数 8、没有建卡片行\n'
  else
    printf '  \033[31m✗\033[0m 折叠的 done 仍建了卡片行或没渲染折叠行\n'; rc=1
  fi
  # 3) the width re-share: folding a lane widens the unfolded ones.
  render "$d/width.txt" 160 32 "boardFold=done"
  wip() { python3 - "$1" <<'PYW'
import re, sys

row = re.sub(r"\x1b\[[0-9;]*m", "", open(sys.argv[1], encoding="utf-8").read()).split("\n")[2]
i = row.find("▾ 进行")
left, right = row.rfind("╭", 0, i), row.find("╮", i)
print(right - left + 1 if i >= 0 and left >= 0 and right >= 0 else -1)
PYW
  }
  wip_before="$(wip "$d/default.txt")"; wip_after="$(wip "$d/width.txt")"
  if [ "$wip_before" -gt 0 ] && [ "$wip_after" -gt "$wip_before" ]; then
    printf '  \033[32m✓\033[0m 折叠让出宽度（wip 盒 %s → %s）\n' "$wip_before" "$wip_after"
  else
    printf '  \033[31m✗\033[0m 折叠没有让出宽度（wip 盒 %s → %s）\n' "$wip_before" "$wip_after"; rc=1
  fi
  # 4) empty lanes fold by default; 5) an explicit show keeps an empty lane unfolded.
  if grep -aqF '▸ 待复验 0（已折叠）' "$d/default.txt"; then
    printf '  \033[32m✓\033[0m 空车道默认折叠\n'
  else
    printf '  \033[31m✗\033[0m 空车道没有按默认折叠\n'; rc=1
  fi
  render "$d/show.txt" 99 40 "boardShow=review"
  if grep -aqF '▾ 待复验 0' "$d/show.txt"; then
    printf '  \033[32m✓\033[0m 显式展开的空车道保持展开\n'
  else
    printf '  \033[31m✗\033[0m 显式展开的空车道仍被折叠\n'; rc=1
  fi
  # 6) the machine frame never reads the fold keys (two confs print byte-identically).
  machine "$d/machine-a.txt" "boardFold=done"
  machine "$d/machine-b.txt" "lang=en"
  if cmp -s "$d/machine-a.txt" "$d/machine-b.txt"; then
    printf '  \033[32m✓\033[0m 机读帧忽略折叠键\n'
  else
    printf '  \033[31m✗\033[0m 机读帧读了面板 conf 的折叠键\n'; rc=1
  fi
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
      --outfile "$tmp/$1.js" ) >"$tmp/$1-build.log" 2>&1 || {
    printf '  \033[31m✗\033[0m %s：突变的 bundle 构建失败\n' "$name"; tail -3 "$tmp/$1-build.log" >&2; return 1
  }
  return 0
}

# <name> <edit script> <run the red side> <red-side description>
flip() {
  local name="$1" edit="$2" runner="$3" what="$4"
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
  if [ -n "$runner" ]; then
    # The interaction half: the mutant bundle runs the b3 fold scenario; the named assertion must
    # fail there even though the frame checks are (by design) still green — a persistence flip is
    # not observable on one frame.
    TEAM_B3_PANEL="$tmp/$name.js" bash "$src_tree/panel-b3.sh" fold >"$tmp/$name-b3.log" 2>&1 || true
    if sed 's/\x1b\[[0-9;]*m//g' "$tmp/$name-b3.log" | grep -qF "✗ $runner"; then
      ok "$name：b3 fold 场景点名红了「$runner」"
    else
      bad "$name：b3 fold 场景没有点名红「$runner」"; sed 's/\x1b\[[0-9;]*m//g' "$tmp/$name-b3.log" | grep '✗' | head -3
    fi
  elif [ "$red_rc" -ne 0 ] && grep -q '✗' "$red"; then
    ok "$name：突变之后变红（$(grep -c '✗' "$red") 条；$(grep '✗' "$red" | head -1 | sed 's/^ *✗ *//' | cut -c1-70)）"
  else
    bad "$name：突变之后居然还是绿的（翻转失效）"; sed 's/^/      /' "$red"
  fi
}

# ---------------------------------------------------------------- the flips
if want F-ORDER; then
  flip F-ORDER 'p = f"{tree}/layout.ts"
s = open(p, encoding="utf-8").read()
old = "  return truncLine(ln(seg(cursor, cursorTone), seg(`${glyph} `, tone), seg(`${card.id} `, idTone), seg(card.title)), width)"
new = "  return truncLine(ln(seg(cursor, cursorTone), seg(`${glyph} `, tone), seg(`${card.id} `, idTone), seg(`${card.agent} `, \"dim\"), seg(card.title)), width) // FLIP P123"
assert s.count(old) == 1, "anchor"
open(p, "w", encoding="utf-8").write(s.replace(old, new))
' "" "把 agent 放回卡片行（降级序倒过来）"
fi

if want F-CARDS; then
  flip F-CARDS 'p = f"{tree}/layout.ts"
s = open(p, encoding="utf-8").read()
old = "laneColumn(ctx, lane, widths.get(lane) ?? 8, slots, target, ordinals, windows, foldedLanes.includes(lane))"
new = "laneColumn(ctx, lane, widths.get(lane) ?? 8, slots, target, ordinals, windows, false /* FLIP P123: the fold branch never runs */)"
assert s.count(old) == 1, "anchor"
open(p, "w", encoding="utf-8").write(s.replace(old, new))
' "" "折叠分支不生效（折叠车道照旧建卡片行）"
fi

if want F-PERSIST; then
  flip F-PERSIST 'p = f"{tree}/settings.ts"
s = open(p, encoding="utf-8").read()
old = """    `boardFold=${BOARD_LANES.filter((lane) => s.boardFold.includes(lane)).join(\u0027,\u0027)}`,
    `boardShow=${BOARD_LANES.filter((lane) => s.boardShow.includes(lane)).join(\u0027,\u0027)}`,
"""
new = "    // FLIP P123: the fold state is never written to the file\n"
assert s.count(old) == 1, "anchor"
open(p, "w", encoding="utf-8").write(s.replace(old, new))
' "重启后面板仍折叠 todo（显式状态持久）" "折叠状态不落盘（重启断言红）"
fi

if want F-MACHINE; then
  flip F-MACHINE 'p = f"{tree}/main.tsx"
s = open(p, encoding="utf-8").read()
old = "view: defaultView(\u0027zh\u0027, machinePage) } as LayoutInput)\n      out(\u0060${renderPlain(themed).join(\u0027\\n\u0027)}\\n\u0060)\n      if (once) await runTickIfDue()"
new = "view: { ...defaultView(\u0027zh\u0027, machinePage), boardFold: readSettings(confFile).boardFold } } as LayoutInput) // FLIP P123\n      out(\u0060${renderPlain(themed).join(\u0027\\n\u0027)}\\n\u0060)\n      if (once) await runTickIfDue()"
assert s.count(old) == 1, "anchor"
open(p, "w", encoding="utf-8").write(s.replace(old, new))
' "" "机读帧读 panel.conf 的折叠键"
fi

if want F-EMPTY; then
  flip F-EMPTY 'p = f"{tree}/settings.ts"
s = open(p, encoding="utf-8").read()
old = "  boardEmptyFold: true,"
new = "  boardEmptyFold: false, // FLIP P123"
assert s.count(old) == 1, "anchor"
open(p, "w", encoding="utf-8").write(s.replace(old, new))
' "" "空车道默认折叠关掉"
fi

if want F-WIDTH; then
  flip F-WIDTH 'p = f"{tree}/layout.ts"
s = open(p, encoding="utf-8").read()
old = """  const widths = new Map<string, number>()
  if (!foldedLanes.length || !shownLanes.length) {"""
new = """  const widths = new Map<string, number>()
  if (foldedLanes.length >= 0 || shownLanes.length >= 0) { // FLIP P123: every lane keeps the even share"""
assert s.count(old) == 1, "anchor"
open(p, "w", encoding="utf-8").write(s.replace(old, new))
' "" "宽度不随折叠再分配"
fi

# ---------------------------------------------------------------- the committed bundle must be untouched
committed_sha_after="$(sha256sum "$committed" | cut -d' ' -f1)"
if [ "$committed_sha_before" = "$committed_sha_after" ]; then
  ok "翻转全程没有碰提交的 panel.js（sha256 不变）"
else
  bad "翻转改动了提交的 panel.js（$committed_sha_before → $committed_sha_after）"
fi

printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && { printf '\033[32mpanel-flip-p123 全绿\033[0m\n'; exit 0; }
printf '\033[31mpanel-flip-p123 有失败项\033[0m\n'
exit 1
