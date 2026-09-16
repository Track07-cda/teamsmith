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
