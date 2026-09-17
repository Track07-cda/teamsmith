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
tree="${TEAM_SNAPSHOTS_TREE:-$(cd -P "$here/../../.." && pwd)}"
panel="$tree/skills/teamsmith/scripts/panel/panel.js"
stub="$here/panel-b3-stub.sh"
snapdir="$here/snapshots"
js="${TEAM_SNAPSHOTS_JS:-$(command -v node || command -v bun || true)}"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/panel-snapshots.XXXXXX")"
update=0
[ "${1:-}" = "--update" ] && update=1
PASS=0
FAIL=0
cleanup() { rm -rf "$tmp"; }
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
if [ "$rows" -le 8 ] && [ "$overrun" = "0" ]; then
  ok "tiny：60x8 的快照 $rows 行、没有一行超过 60 列"
else
  bad "tiny：60x8 的帧 $rows 行、$overrun 行超宽"
fi

printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && { printf '\033[32mpanel-snapshots 全绿\033[0m\n'; exit 0; }
printf '\033[31mpanel-snapshots 有失败项\033[0m\n'
exit 1
