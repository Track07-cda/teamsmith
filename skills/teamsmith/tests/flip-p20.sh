#!/usr/bin/env bash
# teamsmith · P20 flips: every batch's break must turn its own fixture red, and the committed bundle
# must be green — so the fixtures are provably pinned to the thing that batch changed.
#
#   bash skills/teamsmith/tests/flip-p20.sh b1        # insertion point / window
#   bash skills/teamsmith/tests/flip-p20.sh b2        # word rule / kill ring
#   bash skills/teamsmith/tests/flip-p20.sh b3        # multi-line + C-o migration
#   bash skills/teamsmith/tests/flip-p20.sh b4        # clipboard failure path
#   bash skills/teamsmith/tests/flip-p20.sh b5        # work-page detail return
#   bash skills/teamsmith/tests/flip-p20.sh b6        # rename
#   bash skills/teamsmith/tests/flip-p20.sh --keep    # keep the scratch dirs/logs
#
# Mechanics: a scratch copy of `scripts/panel/src` (with the panel's node_modules symlinked in) gets a
# small textual patch, is rebuilt with bun, and the batch's fixture scenario runs twice — against the
# flipped bundle (`TEAM_B2_PANEL` / `TEAM_B3_PANEL`) and against the committed one. The real sources
# are never touched.
#
# Exit: 0 = the flip holds (flipped red on the expected assertions, committed green)｜1 = not｜2 = env.
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$SELF_DIR/lib/tmp-root.sh"
TREE="$(cd -P "$SKILL_DIR/../.." && pwd)"
PANEL_DIR="$SKILL_DIR/scripts/panel"
PIN="$PANEL_DIR/panel.js"

batch="${1:-}"
case "$batch" in
  -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
  --keep) KEEP=1; batch="${2:-}"; [ -n "$batch" ] || { printf 'flip-p20: --keep 需要 batch\n' >&2; exit 2; } ;;
  *) KEEP=0 ;;
esac
case "$batch" in b1|b2|b3|b4|b5|b6) ;; *) printf 'flip-p20: batch 必须是 b1..b6（收到 [%s]）\n' "$batch" >&2; exit 2 ;; esac

js="$(command -v node || command -v bun || true)"
bun="${P20_FLIP_BUN:-}"
[ -n "$bun" ] || bun="$(command -v bun 2>/dev/null || true)"
[ -n "$bun" ] || bun="$HOME/.bun/bin/bun"
[ -x "$bun" ] || { printf 'flip-p20: 需要 bun 重建翻转 bundle（%s）\n' "$bun" >&2; exit 2; }
[ -n "$js" ] || { printf 'flip-p20: 本机没有 node/bun\n' >&2; exit 2; }
[ -s "$PIN" ] || { printf 'flip-p20: 找不到 bundle（%s）\n' "$PIN" >&2; exit 2; }

INK_PIN="$(sed -n 's/.*"ink": *"\([^"]*\)".*/\1/p' "$PANEL_DIR/package.json")"
REACT_PIN="$(sed -n 's/.*"react": *"\([^"]*\)".*/\1/p' "$PANEL_DIR/package.json")"

[ "${KEEP:-0}" = "1" ] && export TEAM_TMP_KEEP=1
tmp="$(tmp_root_create flip-p20)" || exit 3
cleanup() { [ "${BASHPID:-$$}" = "$$" ] && [ "${KEEP:-0}" = "0" ] && tmp_root_reap_all; }
trap cleanup EXIT

flip_apply() { # <label> <src dir>：每个 batch 的破坏点（走 Python 的字符串，避开 shell 引号地狱）
  local label="$1" d="$2"
  case "$label" in
    b1)
      # The insertion point and the window forced to the draft's end: no window at all.
      python3 - "$d" <<'PY'
import sys

d = sys.argv[1]


def edit(name, old, new):
    path = f'{d}/{name}'
    s = open(path, encoding='utf-8').read()
    if s.count(old) != 1:
        sys.exit(f'flip-p20: pattern not unique ({s.count(old)}): {old[:70]!r}')
    open(path, 'w', encoding='utf-8').write(s.replace(old, new))


edit('compose.ts', """  let visible = cap
  let start = clamp(cur - visible + 1, 0, Math.max(0, rows.length - visible))
  if (start > 0 && cap > 1) {
    visible = cap - 1
    start = clamp(cur - visible + 1, 0, Math.max(0, rows.length - visible))
  }""", """  const visible = rows.length // FLIP b1: no window
  const start = 0 // FLIP b1: no window""")
edit('compose.ts', "  const marker = start > 0 && cap > 1", "  const marker = false // FLIP b1")
edit('compose.ts', """    cursorLine: (marker ? 1 : 0) + (cur - start),
    cursorColumn: dispWidth(prefix) + dispWidth([...String(draft ?? '')].slice(row.start, at).join('')),""", """    cursorLine: lines.length - 1, // FLIP b1: cursor forced to the end
    cursorColumn: dispWidth(lines[lines.length - 1] ?? ''), // FLIP b1""")
PY
      ;;
    b2)
      # The word rule without the platform segmenter (whitespace runs only) and no ring
      # accumulation: the segmenter-sensitive punctuation case and the accumulated yank go red.
      python3 - "$d" <<'PY'
import sys

d = sys.argv[1]


def edit(name, old, new):
    path = f'{d}/{name}'
    s = open(path, encoding='utf-8').read()
    if s.count(old) != 1:
        sys.exit(f'flip-p20: pattern not unique ({s.count(old)}): {old[:70]!r}')
    open(path, 'w', encoding='utf-8').write(s.replace(old, new))


edit('compose.ts', """function segmentsOf(text: string): { segment: string; isWordLike: boolean }[] {
  if (!wordSegmenter) wordSegmenter = new Intl.Segmenter(undefined, { granularity: 'word' })
  const out: { segment: string; isWordLike: boolean }[] = []
  for (const s of wordSegmenter.segment(text)) out.push({ segment: s.segment, isWordLike: s.isWordLike === true })
  return out
}""", """function segmentsOf(text: string): { segment: string; isWordLike: boolean }[] {
  // FLIP b2: whitespace runs only, no segmenter
  const out: { segment: string; isWordLike: boolean }[] = []
  for (const m of String(text).matchAll(/\\S+|\\s+/g)) out.push({ segment: m[0], isWordLike: !/^\\s+$/.test(m[0]) })
  return out
}""")
edit('compose.ts', """  if (ring.lastDirection === direction && ring.entries.length > 0) {
    const head = direction === 'backward' ? text + ring.entries[0] : ring.entries[0] + text
    return { entries: [head, ...ring.entries.slice(1)], lastDirection: direction }
  }""", "  // FLIP b2: no ring accumulation")
PY
      ;;
    b3)
      # (a) the legacy lone `\n` submits again (today's behaviour before B3); (b) the standby
      # reason keeps its newline instead of becoming one line.
      python3 - "$d" <<'PYB3'
import sys

d = sys.argv[1]


def edit(name, old, new):
    path = f'{d}/{name}'
    s = open(path, encoding='utf-8').read()
    if s.count(old) != 1:
        sys.exit(f'flip-p20: pattern not unique ({s.count(old)}): {old[:70]!r}')
    open(path, 'w', encoding='utf-8').write(s.replace(old, new))


edit('compose.ts', "  if (ch === '\\n') return { kind: 'newline' }", "  if (ch === '\\n') return { kind: 'submit' } // FLIP b3a")
edit('App.tsx', "const flatten = (value: string): string => (mode === 'reason' ? value.replace(/\\n/g, ' ') : value)", "const flatten = (value: string): string => value // FLIP b3b")
PYB3
      ;;
    b4)
      # A failed probe clears the draft and the text fallback is gone: the no-tool and
      # text-fallback assertions must go red.
      python3 - "$d" <<'PYB4'
import sys

d = sys.argv[1]


def edit(name, old, new):
    path = f'{d}/{name}'
    s = open(path, encoding='utf-8').read()
    if s.count(old) != 1:
        sys.exit(f'flip-p20: pattern not unique ({s.count(old)}): {old[:70]!r}')
    open(path, 'w', encoding='utf-8').write(s.replace(old, new))


edit('clipboard.ts', """    const text = await run('wl-paste', ['--no-newline', '--type', 'text'], CLIPBOARD_READ_TIMEOUT_MS)
    if (text && text.rc === 0 && text.stdout.length > 0) return { kind: 'text', text: text.stdout.toString('utf8') }
    return null""", "    return null // FLIP b4: no text fallback")
edit('clipboard.ts', """    const text = await run('xclip', ['-selection', 'clipboard', '-o'], CLIPBOARD_READ_TIMEOUT_MS)
    if (text && text.rc === 0 && text.stdout.length > 0) return { kind: 'text', text: text.stdout.toString('utf8') }""", "    return null // FLIP b4: no text fallback")
edit('App.tsx', "      if (read.kind === 'none' || read.value === '') return", "      if (read.kind === 'none' || read.value === '') { updateCompose({ text: '', cursor: 0 }, mode === 'message'); return } // FLIP b4")
PYB4
      ;;
    b5)
      # The rejected implementation: the work page's enter switches to page 4 before opening the
      # detail, so closing it dumps the reader on the board page.
      python3 - "$d" <<'PYB5'
import sys

d = sys.argv[1]


def edit(name, old, new):
    path = f'{d}/{name}'
    s = open(path, encoding='utf-8').read()
    if s.count(old) != 1:
        sys.exit(f'flip-p20: pattern not unique ({s.count(old)}): {old[:70]!r}')
    open(path, 'w', encoding='utf-8').write(s.replace(old, new))


edit('App.tsx', """      if (page === 2 && key.return) {
        // The work page's board rows open the same detail view (P20/B5), on the page it was
        // opened from.
        openWorkFocused()""", """      if (page === 2 && key.return) {
        goPage(4) // FLIP b5: the rejected implementation
        openWorkFocused()""")
PYB5
      ;;
    b6)
      # The old label comes back: the messages-page frame assertion and the zh.ts grep go red.
      python3 - "$d" <<'PYB6'
import sys

d = sys.argv[1]
path = f'{d}/strings/zh.ts'
s = open(path, encoding='utf-8').read()
for old, new in (
    ("inboxHeading: '收件箱与往来',", "inboxHeading: '收件箱与线程',"),
    ("inboxLine: '收件箱 {inbox} 条 · 往来 {thread} 条 · {age}',", "inboxLine: '收件箱 {inbox} 条 · 线程 {thread} 条 · {age}',"),
    ("inboxEmpty: '（没有收件箱/往来记录）',", "inboxEmpty: '（没有收件箱/线程记录）',"),
):
    if s.count(old) != 1:
        sys.exit(f'flip-p20: pattern not unique ({s.count(old)}): {old!r}')
    s = s.replace(old, new)
open(path, 'w', encoding='utf-8').write(s)
PYB6
      if grep -q '线程' "$d/strings/zh.ts"; then
        printf '  ✓ 翻转源码：zh.ts 里 线程 回来了（grep -c = %s）\n' "$(grep -c '线程' "$d/strings/zh.ts")" >&2
      else
        printf '  ✗ 翻转源码：b6 补丁没有写进去\n' >&2
        return 1
      fi
      ;;
    *)
      printf 'flip-p20: batch %s 的破坏点还没写\n' "$label" >&2
      return 1
      ;;
  esac
}

# Build the flipped bundle from a scratch src copy (node_modules symlinked beside it).
build_flipped() { # <label>
  local label="$1" src="$tmp/$1-src"
  mkdir -p "$src"
  cp -r "$PANEL_DIR/src/." "$src/"
  ln -sfn "$PANEL_DIR/node_modules" "$src/node_modules"
  flip_apply "$label" "$src" || return 1
  ( cd "$PANEL_DIR" && "$bun" build "$src/main.tsx" --target=node --format=esm --minify \
      --define "__PIN_INK__=\"$INK_PIN\"" --define "__PIN_REACT__=\"$REACT_PIN\"" \
      --outfile "$tmp/$label-panel.js" ) >"$tmp/$label-build.log" 2>&1 || {
    printf 'flip-p20: %s 侧构建失败\n' "$label" >&2; tail -3 "$tmp/$label-build.log" >&2; return 1
  }
  printf '%s' "$tmp/$label-panel.js"
}

# The batch's scenario(s) against one bundle.
run_side() { # <bundle> <log> <scenario...>
  local bundle="$1" log="$2"; shift 2
  TEAM_B2_PANEL="$bundle" TEAM_B3_PANEL="$bundle" bash "$runner" "$@" >"$log" 2>&1
}

case "$batch" in
  b1) runner="$SELF_DIR/panel-b2.sh"; scenario=(cursor) ;;
  b2) runner="$SELF_DIR/panel-b2.sh"; scenario=(keys) ;;
  b3) runner="$SELF_DIR/panel-b2.sh"; scenario=(multiline) ;;
  b4) runner="$SELF_DIR/panel-b2.sh"; scenario=(clipboard) ;;
  b5) runner="$SELF_DIR/panel-b3.sh"; scenario=(workdetail) ;;
  b6) runner="$SELF_DIR/panel-b3.sh"; scenario=(pages) ;;
  *)  runner="$SELF_DIR/panel-b2.sh"; scenario=(cursor) ;;
esac

printf '\033[1m== flip-p20 %s · %s ==\033[0m\n' "$batch" "${scenario[*]}"
flipped="$(build_flipped "$batch")" || exit 2
printf '  翻转 bundle：%s\n' "$flipped"

run_side "$flipped" "$tmp/$batch-flipped.log" "${scenario[@]}"; flipped_rc=$?
run_side "$PIN" "$tmp/$batch-now.log" "${scenario[@]}"; now_rc=$?

strip_ansi() { sed 's/\x1b\[[0-9;]*m//g' "$1"; }
flipped_bad="$(strip_ansi "$tmp/$batch-flipped.log" | grep -aE '^  .*✗' || true)"
now_bad="$(strip_ansi "$tmp/$batch-now.log" | grep -aE '^  .*✗' || true)"

ok=1
if [ "$flipped_rc" -ne 0 ] && [ -n "$flipped_bad" ]; then
  printf '  \033[32m✓\033[0m 翻转侧红：\n'
  printf '%s\n' "$flipped_bad" | sed 's/^/      /' | head -6
else
  ok=0
  printf '  \033[31m✗\033[0m 翻转侧没有红（rc=%s）—— 夹具没在测这一批改的东西\n' "$flipped_rc"
fi
if [ "$now_rc" -eq 0 ] && [ -z "$now_bad" ]; then
  printf '  \033[32m✓\033[0m 提交的 bundle：全绿（%s）\n' "$(strip_ansi "$tmp/$batch-now.log" | grep '结果' | tail -1 | tr -d ' ')"
else
  ok=0
  printf '  \033[31m✗\033[0m 提交的 bundle 没有全绿（rc=%s）\n' "$now_rc"
  printf '%s\n' "$now_bad" | sed 's/^/      /' | head -6
fi

if [ "$ok" = "1" ]; then
  printf '\033[32mflip-p20 %s 翻转成立\033[0m\n' "$batch"
  [ "${KEEP:-0}" = "1" ] && printf '日志保留：%s\n' "$tmp"
  exit 0
fi
printf '\033[31mflip-p20 %s 翻转不成立\033[0m —— 两侧日志在 %s\n' "$batch" "$tmp"
exit 1
