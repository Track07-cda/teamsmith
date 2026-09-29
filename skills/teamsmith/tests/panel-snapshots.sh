#!/usr/bin/env bash
# Snapshot suite for the console layout (pulse-console B3, tasks.md 5.3 / the spec's "The layout is
# a pure function of geometry with four width tiers").
#
#   bash skills/teamsmith/tests/panel-snapshots.sh            # compare against tests/snapshots/
#   bash skills/teamsmith/tests/panel-snapshots.sh --update   # re-pin the snapshots (maintainer)
#
# Four widths — 160 (two columns), 120 (compact two columns), 99 (one column) and 59 (the minimal
# form) — × both themes, each rendered through `panel.js --snapshot` against the deterministic block
# stub (fixed timestamp, fixed ages) and compared byte for byte. A themed frame carries its SGR
# bytes, so the two palettes are pinned too, not just the text.
#
# Exit: 0 every snapshot matches, 1 at least one mismatch, 3 setup failure.
set -uo pipefail

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$here/lib/tmp-root.sh"
tree="${TEAM_SNAPSHOTS_TREE:-$(cd -P "$here/../../.." && pwd)}"
panel="${TEAM_SNAPSHOTS_PANEL:-$tree/skills/teamsmith/scripts/panel/panel.js}"
stub="$here/panel-b3-stub.sh"
snapdir="$here/snapshots"
js="${TEAM_SNAPSHOTS_JS:-$(command -v node || command -v bun || true)}"
tmp="$(tmp_root_create panel-snapshots)" || exit 3
update=0
[ "${1:-}" = "--update" ] && update=1
PASS=0
FAIL=0
cleanup() { tmp_root_reap_all; }
trap cleanup EXIT

ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }

[ -n "$js" ] || { printf 'panel-snapshots: no node/bun runtime\n' >&2; exit 3; }
[ -f "$panel" ] || { printf 'panel-snapshots: no bundle at %s\n' "$panel" >&2; exit 3; }
[ -f "$stub" ] || { printf 'panel-snapshots: no stub at %s\n' "$stub" >&2; exit 3; }
mkdir -p "$snapdir"

# M21 item 5: the two body columns must end on the same row in a bounded frame — the last row that
# closes a card closes both. Before the flush rule the short column's card ended earlier and
# everything below it was blank page.
flush_check() { # <frame> <label>
  local frame="$1" label="$2" got
  got="$(python3 - "$frame" <<'PY'
import re, sys

rows = [re.sub(r"\x1b\[[0-9;]*m", "", l.rstrip("\n")) for l in open(sys.argv[1], encoding="utf-8")]
last = next((r for r in reversed(rows) if "╰" in r), "")
n = last.count("╰")
print("ok" if n >= 2 else f"the last card-closing row closes {n} card(s): {last!r}")
PY
)"
  if [ "$got" = "ok" ]; then
    ok "$label：两列 body 底边齐平（最后一行同时收两个卡片）"
  else
    bad "$label：两列底边不齐（$got）"
  fi
}

printf '\033[1m== snapshots · 4 widths × 2 themes ==\033[0m\n'
for width in 160 120 99 59; do
  for theme in dark light; do
    name="zh-$theme-$width"
    actual="$tmp/$name.txt"
    "$js" "$panel" --snapshot --root "$tmp" --state-dir "$tmp/state" --team-cli "$stub" \
      --width "$width" --height 32 --theme "$theme" --lang zh --page 1 >"$actual" 2>"$tmp/$name.err"
    rc=$?
    if [ "$rc" != "0" ] || [ ! -s "$actual" ]; then
      bad "$name：--snapshot 失败（rc=$rc）"; tail -2 "$tmp/$name.err"; continue
    fi
    if [ "$update" = "1" ]; then
      cp "$actual" "$snapdir/$name.txt"
      ok "$name：已重新钉住（$(wc -c < "$snapdir/$name.txt" | tr -d ' ') 字节）"
    fi
    if [ ! -f "$snapdir/$name.txt" ]; then
      bad "$name：没有钉住的快照（先跑 --update）"; continue
    fi
    if [ "$update" != "1" ]; then
      if cmp -s "$actual" "$snapdir/$name.txt"; then
        ok "$name：与钉住的快照逐字节一致"
      else
        bad "$name：与钉住的快照不一致（首个差异如下）"
        diff <(sed 's/\x1b\[[0-9;]*m//g' "$snapdir/$name.txt") <(sed 's/\x1b\[[0-9;]*m//g' "$actual") | head -4
      fi
    fi
    # 追加 3/4：四档宽度下会话值完整；表头/数据同一份列计划（起点相等、单元格不跨列）。
    colchk="$tmp/$name.cols"
    if python3 - "$actual" <<'PY' >"$colchk" 2>&1
import re, sys
WIDE = [(0x1100, 0x115f), (0x2e80, 0x303e), (0x3041, 0x33ff), (0x3400, 0x4dbf), (0x4e00, 0x9fff),
        (0xa000, 0xa4cf), (0xac00, 0xd7a3), (0xf900, 0xfaff), (0xfe10, 0xfe19), (0xfe30, 0xfe6f),
        (0xff00, 0xff60), (0xffe0, 0xffe6), (0x1f300, 0x1f64f), (0x1f900, 0x1f9ff)]

def strip(s):
    return re.sub(r"\x1b\[[0-9;]*m", "", s)

def dwidth(text):
    total = 0
    for ch in text:
        cp = ord(ch)
        if cp in (0x200d, 0xfe0f) or 0x0300 <= cp <= 0x036f:
            continue
        total += 2 if any(a <= cp <= b for a, b in WIDE) else 1
    return total

def offset_of(line, needle):
    idx = line.find(needle)
    if idx < 0:
        return -1
    return dwidth(line[:idx])

rows = [strip(l.rstrip("\n")) for l in open(sys.argv[1], encoding="utf-8")]
joined = "\n".join(rows)
if "41k/272k" not in joined:
    print("session value 41k/272k missing (truncated?)")
    sys.exit(1)
header = next((r for r in rows if "会话" in r and "代理" in r), None)
data = next((r for r in rows if "41k/272k" in r and "dev" in r), None)
if not header:
    print("agents header not found")
    sys.exit(1)
if not data:
    print("agents data row not found")
    sys.exit(1)
hs = offset_of(header, "会话")
ds = offset_of(data, "41k/272k")
if hs != ds:
    print(f"session column start header={hs} data={ds}")
    sys.exit(1)
if "任务" in header:
    ht = offset_of(header, "任务")
    dt = offset_of(data, "P14")
    if ht != dt:
        print(f"task column start header={ht} data={dt}")
        sys.exit(1)
    nxt = [offset_of(header, n) for n in ("分支", "会话") if n in header]
    nxt = [x for x in nxt if x > ht]
    if nxt and dt + dwidth("P14") > min(nxt):
        print("task cell crosses into the next column")
        sys.exit(1)
if "分支" in header:
    hb = offset_of(header, "分支")
    # data branch starts after the task cell (or state if no task); the fixture branch is unique.
    db = offset_of(data, "P14-apply-pulse-console-b3")
    if db >= 0 and hb != db:
        print(f"branch column start header={hb} data={db}")
        sys.exit(1)
print("ok")
PY
    then
      ok "$name：会话列完整且表头/数据列起点对齐"
    else
      bad "$name：会话列或列对齐失败（$(tr '\n' ' ' < "$colchk")）"
    fi
    # M21 item 5: in the two-column tiers the two bodies end on the same row (see flush_check).
    if [ "$width" -ge 100 ]; then
      flush_check "$actual" "$name"
    fi
  done
done

# The same rule on the other two pages, where the user saw it (board beside decisions, queue beside
# the right stack) — rendered on the fly, not pinned: the flush is the property under test, not the
# exact rows.
for page in 2 3; do
  pageframe="$tmp/flush-page$page.txt"
  "$js" "$panel" --snapshot --root "$tmp" --state-dir "$tmp/state" --team-cli "$stub" \
    --width 160 --height 32 --theme dark --lang zh --page "$page" >"$pageframe" 2>/dev/null
  flush_check "$pageframe" "page $page (160)"
done

# ---------------------------------------------------------------- P18.1: 两栏各记各的预算
# The user's live report (270x66 pane): the work page showed only the left column's board —
# changes/specs/decisions were not degraded to `—`, they were gone. The placement pass deducted
# from one shared budget (`used = max(columns[0].length, columns[1].length)`), and B1 grows the board
# to the whole body height, so every right-column card saw `remaining = 0` and `pickChrome` dropped
# it. V18's fixture had a small folded pool and could not starve; this one must (done = 95 → 91
# folded rows) and is checked at both geometries the user's report names.
printf '\n\033[1m== P18.1 · 大折叠池的 work 页：board 不许饿死右栏（270x66 / 120x40）==\033[0m\n'
p181_uncapped="$tmp/p181-uncapped.txt"
env B3_STUB_DONE=95 "$js" "$panel" --snapshot --root "$tmp" --state-dir "$tmp/state" --team-cli "$stub" \
  --width 120 --theme dark --lang zh --page 2 >"$p181_uncapped" 2>/dev/null
for p181_spec in "270 66" "120 40"; do
  set -- $p181_spec
  p181_frame="$tmp/p181-$1x$2.txt"
  env B3_STUB_DONE=95 "$js" "$panel" --snapshot --root "$tmp" --state-dir "$tmp/state" --team-cli "$stub" \
    --width "$1" --height "$2" --theme dark --lang zh --page 2 >"$p181_frame" 2>"$tmp/p181-$1x$2.err"
  p181_got="$(python3 - "$p181_frame" "$p181_uncapped" "$1" "$2" <<'PYB'
import re, sys

def strip(s):
    return re.sub(r"\x1b\[[0-9;]*m", "", s)

frame = [strip(l.rstrip("\n")) for l in open(sys.argv[1], encoding="utf-8")]
uncapped = [strip(l.rstrip("\n")) for l in open(sys.argv[2], encoding="utf-8")]
height = int(sys.argv[4])

def folded(rows):
    for r in rows:
        m = re.search(r"其余 (\d+) 条 done/dropped", r)
        if m:
            return int(m.group(1))
    return None

problems = []
if len(frame) != height:
    problems.append(f"帧高 {len(frame)} != {height}")
body = frame[:-1]
if not body or "写信" not in frame[-1]:
    problems.append("末行不是键位带")
if not any("╭─ 任务看板" in r for r in body):
    problems.append("左栏没有 board 卡片")
for title in ("活动变更", "规格", "最近决策"):
    if not any(f"╭─ {title}" in r for r in body):
        problems.append(f"右栏缺「{title}」卡片")
last = body[-1] if body else ""
if not last.startswith("╰") or last.count("╰") != 2:
    problems.append("最后一列身体行没有同时收下两栏的卡片底（board 没填满/两列不同底）")
grown, natural = folded(body), folded(uncapped)
if natural is None:
    problems.append("未封顶夹具没有折叠行（夹具坏了）")
elif grown is None:
    problems.append("board 没有折叠行")
elif grown >= natural:
    problems.append(f"board 折叠数 {grown} 没小于自然值 {natural}（余高没花在历史上）")
print("ok" if not problems else "；".join(problems))
PYB
)"
  if [ "$p181_got" = "ok" ]; then
    ok "P18.1 $1x$2：右栏三卡都在 + board 仍填满左栏（两列同底）+ 帧高恰好 $2 行"
  else
    bad "P18.1 $1x$2：$p181_got"
  fi
done

# B1 must not regress while the budget accounting changes: every page fills a bounded frame
# *exactly* (`height` rows, footer on the last one) and no row outruns the width, on the large-pool
# fixture (the worst case for the board's growth) at four geometries.
for p181_wh in "160 32" "120 40" "99 50" "60 8"; do
  set -- $p181_wh
  for p181_page in 1 2 3 4; do
    env B3_STUB_DONE=95 "$js" "$panel" --snapshot --root "$tmp" --state-dir "$tmp/state" --team-cli "$stub" \
      --width "$1" --height "$2" --page "$p181_page" --theme dark --lang zh \
      >"$tmp/p181-sweep-$1x$2-p$p181_page.txt" 2>/dev/null
  done
done
p181_sweep="$(python3 - "$tmp" <<'PYC'
import glob, os, re, sys

WIDE = [(0x1100, 0x115f), (0x2e80, 0x303e), (0x3041, 0x33ff), (0x3400, 0x4dbf), (0x4e00, 0x9fff),
        (0xa000, 0xa4cf), (0xac00, 0xd7a3), (0xf900, 0xfaff), (0xfe10, 0xfe19), (0xfe30, 0xfe6f),
        (0xff00, 0xff60), (0xffe0, 0xffe6)]

def strip(s):
    return re.sub(r"\x1b\[[0-9;?]*[a-zA-Z]", "", s)

def dwidth(text):
    total = 0
    for ch in text:
        cp = ord(ch)
        if cp in (0x200d, 0xfe0f) or 0x0300 <= cp <= 0x036f:
            continue
        total += 2 if any(a <= cp <= b for a, b in WIDE) else 1
    return total

problems = []
for path in sorted(glob.glob(os.path.join(sys.argv[1], "p181-sweep-*.txt"))):
    m = re.search(r"p181-sweep-(\d+)x(\d+)-p(\d+)\.txt$", path)
    width, height, page = int(m.group(1)), int(m.group(2)), m.group(3)
    rows = [strip(l.rstrip("\n")) for l in open(path, encoding="utf-8")]
    if not rows or "teamsmith pulse" not in rows[0]:
        problems.append(f"{width}x{height} p{page}: 帧没渲染出来")
        continue
    if len(rows) != height:
        problems.append(f"{width}x{height} p{page}: {len(rows)} 行 != {height}")
    elif "写信" not in rows[-1]:
        problems.append(f"{width}x{height} p{page}: 末行不是键位带")
    over = [i + 1 for i, r in enumerate(rows) if dwidth(r) > width]
    if over:
        problems.append(f"{width}x{height} p{page}: 第 {over[0]} 行超宽")
print("ok" if not problems else "；".join(problems[:4]))
PYC
)"
if [ "$p181_sweep" = "ok" ]; then
  ok "P18.1 B1 不回归：四页 × 四档几何（160x32/120x40/99x50/60x8）都恰好 height 行、末行键位带、不超宽"
else
  bad "P18.1 B1 不回归：$p181_sweep"
fi

# ---------------------------------------------------------------- M34: 活跃态置顶（用户拍板）
# 用户实机看 work 页后拍板：活跃任务应当排在顶部。夹具的 BOARD.md 文件序故意把 8 条 done 放在前、
# 2 条活跃（wip + blocked）放在最后 —— 旧实现（行按文件序原样渲染）会把活跃行压到卡片最底，正是
# 用户看到的样子。窄档（120x14）里折叠还在（keep 5 + 其余 3），宽档（120x40）里余高把折叠放满
# （P18.1 的那条放宽规则）：两档都要求活跃两行在最顶，keep 的 done 随后、显示序仍是文件序（老→新），
# 折叠计数与隐藏条数一致。计数行、keep 规则、kanban 页都不归这条断言管。
printf '\n\033[1m== M34 · work 页看板卡：活跃态置顶 ==\033[0m\n'
m34_board="$tmp/m34-board.json"
cat > "$m34_board" <<'JSON'
{"rows": [
 {"id": "D01", "title": "历史条目 01", "agent": "dev2", "branch": "task/D01", "deps": "-", "state": "done"},
 {"id": "D02", "title": "历史条目 02", "agent": "dev2", "branch": "task/D02", "deps": "-", "state": "done"},
 {"id": "D03", "title": "历史条目 03", "agent": "dev2", "branch": "task/D03", "deps": "-", "state": "done"},
 {"id": "D04", "title": "历史条目 04", "agent": "dev2", "branch": "task/D04", "deps": "-", "state": "done"},
 {"id": "D05", "title": "历史条目 05", "agent": "dev2", "branch": "task/D05", "deps": "-", "state": "done"},
 {"id": "D06", "title": "历史条目 06", "agent": "dev2", "branch": "task/D06", "deps": "-", "state": "done"},
 {"id": "D07", "title": "历史条目 07", "agent": "dev2", "branch": "task/D07", "deps": "-", "state": "done"},
 {"id": "D08", "title": "历史条目 08", "agent": "dev2", "branch": "task/D08", "deps": "-", "state": "done"},
 {"id": "A1", "title": "活跃夹具一", "agent": "dev", "branch": "task/A1", "deps": "-", "state": "wip"},
 {"id": "A2", "title": "活跃夹具二", "agent": "verify", "branch": "-", "deps": "A1", "state": "blocked"}
],
 "counts": {"todo": 0, "wip": 1, "review": 0, "done": 8, "blocked": 1, "dropped": 0},
 "total": 10,
 "deliveries": [
   {"id": "D08", "agent": "dev2", "at": "2026-09-16T09:30:00Z"}
 ]}
JSON
m34_check() { # <width> <height> <label>
  local width="$1" height="$2" label="$3" frame="$tmp/m34-$1x$2.txt" got
  env B3_STUB_BOARD_FILE="$m34_board" "$js" "$panel" --snapshot --root "$tmp" --state-dir "$tmp/state" \
    --team-cli "$stub" --width "$width" --height "$height" --theme dark --lang zh --page 2 \
    >"$frame" 2>"$tmp/m34-$1x$2.err"
  if [ ! -s "$frame" ]; then
    bad "M34 $label：没有渲染出帧"; tail -2 "$tmp/m34-$1x$2.err"; return
  fi
  got="$(python3 - "$frame" <<'PYM'
import re, sys

rows = [re.sub(r"\x1b\[[0-9;]*m", "", l.rstrip("\n")) for l in open(sys.argv[1], encoding="utf-8")]
ACTIVE = ["A1", "A2"]                      # 文件序里的两条活跃行（wip + blocked）
HISTORY = [f"D{i:02d}" for i in range(1, 9)]  # 文件序里的 8 条 done（老→新）


def cell_row(cid):  # the first row whose id cell renders this id (the id column is 10 cells wide)
    pat = re.compile(re.escape(cid) + r"\s")
    for i, r in enumerate(rows):
        if pat.search(r):
            return i
    return -1


problems = []
if not any("任务看板" in r for r in rows):
    problems.append("没有 board 卡片")
at = {c: cell_row(c) for c in ACTIVE}
short = [c for c, i in at.items() if i < 0]
if short:
    problems.append("活跃行没渲染出来：" + "/".join(short))
ht = {c: cell_row(c) for c in HISTORY}
visible = [c for c in HISTORY if ht[c] >= 0]      # rendered history rows, in file order
folded = None
for r in rows:
    m = re.search(r"其余\s*(\d+)\s*条", r)
    if m:
        folded = int(m.group(1))
        break
hidden = len(HISTORY) - len(visible)
if folded is None and hidden != 0:
    problems.append(f"折叠行缺失（应有 {hidden} 条隐藏在卡片里）")
elif folded is not None and folded != hidden:
    problems.append(f"折叠计数 {folded} != 实际隐藏的历史行 {hidden}")
if visible != HISTORY[len(HISTORY) - len(visible):]:
    problems.append("keep 的 done 不是最新的连续后缀（老→新）：" + "/".join(visible))
if [ht[c] for c in visible] != sorted(ht[c] for c in visible):
    problems.append("keep 的 done 没有保持文件序（老→新）：" + str([ht[c] for c in visible]))
if not short and visible and max(at.values()) > min(ht[c] for c in visible):
    problems.append(
        f"活跃行不在最顶：A1@{at['A1']} A2@{at['A2']}，而 done 行在 {sorted(ht[c] for c in visible)}"
    )
if not short and [at[c] for c in ACTIVE] != sorted(at[c] for c in ACTIVE):
    problems.append(f"活跃行没有保持文件序（A1@{at['A1']} A2@{at['A2']}）")
print("ok" if not problems else "；".join(problems))
PYM
)"
  if [ "$got" = "ok" ]; then
    ok "M34 $label：活跃行在最顶（A1→A2 文件序），keep 的 done 随后且保持文件序"
  else
    bad "M34 $label：$got"
  fi
}
m34_check 120 14 "120x14（history 折叠：keep 5 + 其余 3）"
m34_check 120 40 "120x40（余高把折叠放满：8 条历史全在）"

# The settings overlay's column plan (V16 F-V16-4/5's layout half + the user's report of
# 2026-09-17): with `lang=en` the key column was a hardcoded 12 cells with no separator, so
# `default page` (exactly 12) glued its value (`default pageoverview`) and `activity column` was cut
# into the value (`activity co…on`). The plan now reserves the widest key of *either* language
# inside the card's chrome and writes a real gap between the two columns. Checked structurally —
# per width, zh and en must land on the same columns:
#   full     (160/120/99/59): the bilingual key column, every key and value complete, gap of two
#   degraded (24, below the documented tiers): the key column gives first — cut with `…`, never
#            touching the value — and at least one key is actually cut
printf '\n\033[1m== settings overlay · both languages × four widths ==\033[0m\n'
overlay_frame() { # <lang> <width>
  local lang="$1" width="$2"
  "$js" "$panel" --snapshot --overlay --root "$tmp" --state-dir "$tmp/state" --team-cli "$stub" \
    --width "$width" --height 32 --theme dark --lang "$lang" --page 1 >"$tmp/ov-$lang-$width.txt" 2>"$tmp/ov-$lang-$width.err"
}
overlay_pair_check() { # <width> <full|degraded>
  local width="$1" mode="$2" got
  overlay_frame zh "$width"
  overlay_frame en "$width"
  if [ ! -s "$tmp/ov-zh-$width.txt" ] || [ ! -s "$tmp/ov-en-$width.txt" ]; then
    bad "overlay $width：--snapshot --overlay 没有产出帧"; tail -2 "$tmp/ov-en-$width.err"; return
  fi
  got="$(python3 - "$tmp/ov-zh-$width.txt" "$tmp/ov-en-$width.txt" "$width" "$mode" <<'PY'
import re, sys

zh_path, en_path, width, mode = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
LABELS = {
    "zh": ["语言", "默认页面", "活动列", "鼠标", "密度"],
    "en": ["language", "default page", "activity column", "mouse", "density"],
}
TITLE = {"zh": "设置", "en": "settings"}
CURSOR_W, GAP_W, CHROME_W = 4, 2, 4  # cursor column, separator, and the card's border+padding
WIDE = [(0x1100, 0x115f), (0x2e80, 0x303e), (0x3041, 0x33ff), (0x3400, 0x4dbf), (0x4e00, 0x9fff),
        (0xa000, 0xa4cf), (0xac00, 0xd7a3), (0xf900, 0xfaff), (0xfe10, 0xfe19), (0xfe30, 0xfe6f),
        (0xff00, 0xff60), (0xffe0, 0xffe6), (0x1f300, 0x1f64f), (0x1f900, 0x1f9ff)]


def fail(msg):
    print(msg)
    sys.exit(1)


def strip(s):
    return re.sub(r"\x1b\[[0-9;]*m", "", s)


def dwidth(text):
    total = 0
    for ch in text:
        cp = ord(ch)
        if cp in (0x200d, 0xfe0f) or 0x0300 <= cp <= 0x036f:
            continue
        total += 2 if any(a <= cp <= b for a, b in WIDE) else 1
    return total


def dslice(text, start, end):  # display-column slice (CJK-aware)
    out, col = "", 0
    for ch in text:
        w = dwidth(ch)
        if col >= end:
            break
        if col >= start and col + w <= end:
            out += ch
        col += w
    return out


def cell(text, w):  # what the plan renders in the key cell: pad it, or cut it with …
    if dwidth(text) > w:
        out, used = "", 0
        for ch in text:
            cw = dwidth(ch)
            if used + cw > w - 1:
                break
            out += ch
            used += cw
        return out + "…"
    return text + " " * (w - dwidth(text))


plan_key = max(dwidth(x) for labels in LABELS.values() for x in labels)
geometry = {}
cuts = {}
for lang, path in (("zh", zh_path), ("en", en_path)):
    rows = [strip(l.rstrip("\n")) for l in open(path, encoding="utf-8")]
    if TITLE[lang] not in "\n".join(rows):
        fail(f"{lang}: the overlay did not render (no title)")
    # The plan under test, restated from the implementation: the key column holds the widest label
    # of either language inside the chrome the card adds.
    framed = any(r.startswith("╭") for r in rows)
    avail = max(1, width - (CHROME_W if framed else 0))
    keyw = max(1, min(plan_key, avail - CURSOR_W - GAP_W - 1))
    if mode == "full" and keyw != plan_key:
        fail(f"{lang}: width {width} cannot hold the bilingual key column ({keyw} < {plan_key})")
    if mode == "degraded" and keyw >= plan_key:
        fail(f"{lang}: width {width} did not reach the degraded key column ({keyw})")
    cut = 0
    key_x = value_x = None
    for label in LABELS[lang]:
        want = cell(label, keyw).rstrip()
        hit = None
        for line in rows:
            i = line.find(want)
            if i >= 0:
                hit = (line, dwidth(line[:i]))
                break
        if hit is None:
            shown = [r for r in rows if any(l[:2] in r for l in LABELS[lang])][:3]
            fail(f"{lang}: no row carries the key {label!r} as {want!r} (key column {keyw}); rendered: {shown!r}")
        line, x = hit
        if key_x is None:
            key_x, value_x = x, x + keyw + GAP_W
        elif x != key_x:
            fail(f"{lang}: {label!r} starts at column {x}, not {key_x} — the keys are not one column")
        gap = dslice(line, x + keyw, x + keyw + GAP_W)
        if gap != " " * GAP_W:
            fail(
                f"{lang}: {label!r}: no {GAP_W} blank columns after the {keyw}-column key cell "
                f"(columns {x + keyw}..{x + keyw + GAP_W} read {gap!r}) — the value column is not "
                f"clear of the key: {line.rstrip()!r}"
            )
        value = dslice(line, value_x, 10 ** 6).rstrip()
        if not value:
            fail(f"{lang}: {label!r} has an empty value column")
        if dwidth(line) > width:
            fail(f"{lang}: a row is {dwidth(line)} columns wide (limit {width})")
        if mode == "full" and "…" in value:
            fail(f"{lang}: {label!r} lost its value in the full plan ({value!r})")
        if "…" in want:
            cut += 1
    geometry[lang] = (key_x, value_x, keyw)
    cuts[lang] = cut
if geometry["zh"][:2] != geometry["en"][:2]:
    fail(f"the plan is not bilingual at width {width}: zh {geometry['zh']}, en {geometry['en']}")
if mode == "degraded" and not any(cuts.values()):
    # The plan is degraded because the column is narrower than the bilingual maximum; at least one
    # of the two languages must therefore show a cut key (zh's labels are all shorter than the
    # maximum, so a zero here would mean the tier never actually degraded).
    fail(f"the degraded tier cut no key in either language (key column {geometry['zh'][2]})")
print("ok")
PY
)"
  if [ "$got" = "ok" ]; then
    ok "overlay $width（zh+en 同列）：键值两列、间隔 2 列、$mode"
  else
    bad "overlay $width：列计划检查失败（$got）"
  fi
}
for width in 160 120 99 59; do
  overlay_pair_check "$width" full
done
# One tier below the documented four: the key column itself has to give (cut with `…`, still
# separated from the value) — the shape a narrow pane hits.
overlay_pair_check 24 degraded

# ---------------------------------------------------------------- the board page (page 4, P18/B2)
# Four widths × both themes, pinned byte for byte like page 1; then the kanban's own invariants: the
# six lanes in BOARD.md legend order, an empty lane's dim marker, the phase token on a card, and
# exactly one focus cursor.
printf '\n\033[1m== board page (page 4) · 4 widths × 2 themes ==\033[0m\n'
for width in 160 120 99 59; do
  for theme in dark light; do
    name="zh-$theme-$width-p4"
    actual="$tmp/$name.txt"
    "$js" "$panel" --snapshot --root "$tmp" --state-dir "$tmp/state" --team-cli "$stub" \
      --width "$width" --height 32 --theme "$theme" --lang zh --page 4 >"$actual" 2>"$tmp/$name.err"
    rc=$?
    if [ "$rc" != "0" ] || [ ! -s "$actual" ]; then
      bad "$name：--snapshot 失败（rc=$rc）"; tail -2 "$tmp/$name.err"; continue
    fi
    if [ "$update" = "1" ]; then
      cp "$actual" "$snapdir/$name.txt"
      ok "$name：已重新钉住（$(wc -c < "$snapdir/$name.txt" | tr -d ' ') 字节）"
      continue
    fi
    if [ ! -f "$snapdir/$name.txt" ]; then
      bad "$name：没有钉住的快照（先跑 --update）"; continue
    fi
    if cmp -s "$actual" "$snapdir/$name.txt"; then
      ok "$name：与钉住的快照逐字节一致"
    else
      bad "$name：与钉住的快照不一致（首个差异如下）"
      diff <(sed 's/\x1b\[[0-9;]*m//g' "$snapdir/$name.txt") <(sed 's/\x1b\[[0-9;]*m//g' "$actual") | head -4
    fi
  done
done
# The wide frame's invariants (the kanban's own order/marker/phase/focus rules).
p4="$tmp/zh-dark-160-p4.txt"
[ -f "$p4" ] && p4_check="$(python3 - "$p4" <<'PY4'
import re, sys

rows = [re.sub(r"\x1b\[[0-9;]*m", "", l.rstrip("\n")) for l in open(sys.argv[1], encoding="utf-8")]
lane_labels = ["待办", "进行", "待复验", "完成", "阻塞", "已放弃"]
head = next((r for r in rows if "已放弃" in r), "")
pos = [head.find(l) for l in lane_labels]
problems = []
if not head or -1 in pos or pos != sorted(pos):
    problems.append(f"车道顺序不对：{pos}")
if len([p for p in pos if p >= 0]) != 6:
    problems.append(f"六条车道没有全部渲染：{pos}")
# P123：卡片行只留序号+标题（agent/phase 不上卡片），键位带带焦点卡的对。
card_rows = [r for r in rows if re.search(r"[·▸◆✓✗—]\s+[PV]\d+\s", r)]
for r in card_rows:
    if " apply " in r or " verify " in r or " dev " in r or " dev2 " in r:
        problems.append(f"卡片行仍带 agent/phase：{r.strip()[:70]}")
if "verify · verify" not in rows[-1]:
    problems.append("键位带没有焦点卡 V14 的 agent · phase 对")
cursors = sum(r.count("›") for r in rows)
if cursors != 1:
    problems.append(f"焦点光标应当恰好一个，实际 {cursors}")
print("ok" if not problems else "；".join(problems))
PY4
)"
if [ "${p4_check:-}" = "ok" ]; then
  ok "page4 160：六车道顺序 / 卡片只留序号+标题 / 键位带带焦点卡的对 / 只有一个焦点光标"
else
  bad "page4 160：${p4_check:-没有渲染出 page4 帧}"
fi
# The narrow tiers: the same lane order, a single column (no lane box side by side).
for w in 99 59; do
  f="$tmp/zh-dark-$w-p4.txt"
  [ -f "$f" ] || { bad "page4 $w：没有渲染出帧"; continue; }
  p4n="$(python3 - "$f" <<'PY5'
import re, sys

rows = [re.sub(r"\x1b\[[0-9;]*m", "", l.rstrip("\n")) for l in open(sys.argv[1], encoding="utf-8")]
labels = ["待办", "进行", "待复验", "完成", "阻塞", "已放弃"]
# P123: a lane title now wears the state marker (`▾` unfolded / `▸ …（已折叠）` folded).
idx = [next((i for i, r in enumerate(rows) if re.search(rf"[▾▸]\s*{re.escape(l)}\s", r)), -1) for l in labels]
problems = []
if -1 in idx or idx != sorted(idx):
    problems.append(f"车道标题顺序不对：{idx}")
# Every lane header renders; with the empty-lane default on, a lane whose count is 0 is folded to
# its one line (marker + count + folded token) and no dim empty marker follows. An explicitly
# unfolded empty lane (the `boardEmptyFold=0` fixture) still shows the dim marker on the next row.
for i, at in enumerate(idx):
    if at < 0:
        continue
    head = rows[at]
    m = re.search(r"\s(\d+)\s*$", head)
    if not m or m.group(1) != "0":
        continue
    if "（已折叠）" in head:
        continue
    nxt = next((r for r in rows[at + 1 :] if r.strip()), "")
    if "·" not in nxt:
        problems.append(f"{labels[i]} 空车道既没折叠也没有空标记：{nxt!r}")
print("ok" if not problems else "；".join(problems))
PY5
)"
  [ "$p4n" = "ok" ] && ok "page4 $w：单列按车道顺序分组、空车道默认折叠（显式展开才有空标记）" || bad "page4 $w：$p4n"
done

# The minimal tier must not overrun a tiny pane (the spec's "A tiny pane is not overrun"): rows are
# counted on the ANSI frame (one row per newline) and widths on the stripped text.
tiny="$tmp/tiny.txt"
"$js" "$panel" --snapshot --root "$tmp" --state-dir "$tmp/state" --team-cli "$stub" \
  --width 60 --height 8 --theme dark --lang zh --page 1 >"$tiny" 2>/dev/null
rows="$(wc -l < "$tiny" | tr -d ' ')"
# Display width, not bytes: a CJK glyph occupies two columns (the layout's own unit).
overrun="$(python3 - "$tiny" <<'PY'
import re, sys
WIDE = [(0x1100, 0x115f), (0x2e80, 0x303e), (0x3041, 0x33ff), (0x3400, 0x4dbf), (0x4e00, 0x9fff),
        (0xa000, 0xa4cf), (0xac00, 0xd7a3), (0xf900, 0xfaff), (0xfe10, 0xfe19), (0xfe30, 0xfe6f),
        (0xff00, 0xff60), (0xffe0, 0xffe6), (0x1f300, 0x1f64f), (0x1f900, 0x1f9ff)]

def width(text):
    total = 0
    for ch in text:
        cp = ord(ch)
        if cp in (0x200d, 0xfe0f) or 0x0300 <= cp <= 0x036f:
            continue
        total += 2 if any(a <= cp <= b for a, b in WIDE) else 1
    return total

bad = 0
for line in open(sys.argv[1], encoding="utf-8"):
    line = re.sub(r"\x1b\[[0-9;?]*[a-zA-Z]", "", line.rstrip("\n"))
    if width(line) > 60:
        bad += 1
print(bad)
PY
)"
# P18/B1: the bounded-frame red line's smallest case — the key band is the last non-empty row, so a
# tiny pane never strands the footer mid-frame (the pre-fix frame ended on content and padded below).
tiny_tail="$(sed 's/\x1b\[[0-9;]*m//g' "$tiny" | awk 'NF' | tail -1)"
if [ "$rows" -le 8 ] && [ "$overrun" = "0" ]; then
  ok "tiny：60x8 的快照 $rows 行、没有一行超过 60 列"
else
  bad "tiny：60x8 的帧 $rows 行、$overrun 行超宽"
fi
case "$tiny_tail" in
  *写信*) ok "tiny：60x8 的最后一个非空行是键位带（有界帧钉底）" ;;
  *) bad "tiny：60x8 的最后非空行不是键位带（$(printf '%s' "$tiny_tail" | cut -c1-40)）" ;;
esac

# ---------------------------------------------------------------- the detail view (page 4, P18/B3)
# 9.5: one fixture document, two widths × both themes, pinned byte for byte; then the renderer's
# structural invariants (the tab row, the heading without its marker, the aligned table, and a
# narrow tier where the long paragraph wraps instead of overrunning).
printf '\n\033[1m== detail view (page 4 + --detail) · 2 widths × 2 themes ==\033[0m\n'
for width in 120 59; do
  for theme in dark light; do
    name="zh-$theme-$width-detail"
    actual="$tmp/$name.txt"
    "$js" "$panel" --snapshot --root "$tmp" --state-dir "$tmp/state" --team-cli "$stub" \
      --width "$width" --height 32 --theme "$theme" --lang zh --page 4 --detail V14 >"$actual" 2>"$tmp/$name.err"
    rc=$?
    if [ "$rc" != "0" ] || [ ! -s "$actual" ]; then
      bad "$name：--snapshot 失败（rc=$rc）"; tail -2 "$tmp/$name.err"; continue
    fi
    if [ "$update" = "1" ]; then
      cp "$actual" "$snapdir/$name.txt"
      ok "$name：已重新钉住（$(wc -c < "$snapdir/$name.txt" | tr -d ' ') 字节）"
      continue
    fi
    if [ ! -f "$snapdir/$name.txt" ]; then
      bad "$name：没有钉住的快照（先跑 --update）"; continue
    fi
    if cmp -s "$actual" "$snapdir/$name.txt"; then
      ok "$name：与钉住的快照逐字节一致"
    else
      bad "$name：与钉住的快照不一致（首个差异如下）"
      diff <(sed 's/\x1b\[[0-9;]*m//g' "$snapdir/$name.txt") <(sed 's/\x1b\[[0-9;]*m//g' "$actual") | head -4
    fi
  done
done
# 8.1: the renderer's structural invariants on the wide pin — the subset's elements are *readable*:
# the tab row names the four discovered files in order with the first active, the ATX heading lost
# its `#`, the fence body is verbatim, and the pipe table's columns are display-width aligned (every
# `│` lands on one column for header, separator and body).
dv="$tmp/zh-dark-120-detail.txt"
dv_check="$(python3 - "$dv" <<'PYD'
import re, sys

rows = [re.sub(r"\x1b\[[0-9;]*m", "", l.rstrip("\n")) for l in open(sys.argv[1], encoding="utf-8")]
joined = "\n".join(rows)
problems = []
tab_row = next((r for r in rows if "brief" in r and "report:dev" in r), "")
order = [tab_row.find(t) for t in ("[brief]", "report:dev", "review", "review:done")]
if -1 in order or order != sorted(order):
    problems.append(f"tab row order/active wrong: {order}")
if "# V14" in joined or "# P1" in joined:
    problems.append("an ATX heading kept its # marker")
if "verbatim fence body" not in joined:
    problems.append("the fence body is not verbatim")
if "fixture brief" not in joined:
    problems.append("the document body is missing")
# Table columns: the separator row's `┼` columns must equal the header/body `│` columns.
header = next((r for r in rows if "id" in r and "state" in r and "note" in r), "")
sep = next((r for r in rows if "┼" in r), "")
body = next((r for r in rows if "P22" in r), "")
if not (header and sep and body):
    problems.append("the pipe table did not render")
else:
    def marks(row, chars):
        return [i for i, ch in enumerate(row) if ch in chars]
    # The frame's card border `│` sits at the row's first and last column; the table's own
    # separators are the inner marks.
    hx, sx, bx = marks(header, "│")[1:-1], marks(sep, "┼"), marks(body, "│")[1:-1]
    if not (hx == sx == bx) or len(hx) != 2:
        problems.append(f"table columns misaligned: header {hx}, separator {sx}, body {bx}")
print("ok" if not problems else "；".join(problems))
PYD
)"
[ "$dv_check" = "ok" ] && ok "detail 120：tab 次序 / 标题去标记 / 围栏原样 / 表格列对齐" \
  || bad "detail 120：${dv_check:-没有渲染出详情帧}"
# 59 columns: nothing may overrun the pane (the long paragraph wraps), and the tabs still render.
nd="$tmp/zh-dark-59-detail.txt"
nd_over="$(python3 - "$nd" <<'PY'
import re, sys
WIDE = [(0x1100, 0x115f), (0x2e80, 0x303e), (0x3041, 0x33ff), (0x3400, 0x4dbf), (0x4e00, 0x9fff),
        (0xa000, 0xa4cf), (0xac00, 0xd7a3), (0xf900, 0xfaff), (0xfe10, 0xfe19), (0xfe30, 0xfe6f),
        (0xff00, 0xff60), (0xffe0, 0xffe6)]

def width(text):
    total = 0
    for ch in text:
        cp = ord(ch)
        if cp in (0x200d, 0xfe0f) or 0x0300 <= cp <= 0x036f:
            continue
        total += 2 if any(a <= cp <= b for a, b in WIDE) else 1
    return total

bad = 0
for line in open(sys.argv[1], encoding="utf-8"):
    line = re.sub(r"\x1b\[[0-9;?]*[a-zA-Z]", "", line.rstrip("\n"))
    if width(line) > 59:
        bad += 1
print(bad)
PY
)"
if [ "$nd_over" = "0" ]; then
  ok "detail 59：没有一行超过 59 列（长段落换行）"
else
  bad "detail 59：$nd_over 行超过 59 列"
fi
if grep -qF '[brief]' "$nd"; then
  ok "detail 59：tab 行仍渲染（首个 active）"
else
  bad "detail 59：tab 行没有渲染"
fi
printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && { printf '\033[32mpanel-snapshots 全绿\033[0m\n'; exit 0; }
printf '\033[31mpanel-snapshots 有失败项\033[0m\n'
exit 1
