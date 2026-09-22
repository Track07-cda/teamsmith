#!/usr/bin/env bash
# Compose-entry fixtures (pulse-console B2, P13): the pty/tmux proofs for tasks.md items 2.1–2.6
# and 3.1–3.2.
#
#   bash skills/teamsmith/tests/panel-b2.sh                 # every scenario
#   bash skills/teamsmith/tests/panel-b2.sh cjk draft       # selected scenarios
#   TEAM_B2_KEEP=1 bash skills/teamsmith/tests/panel-b2.sh  # keep the fixture directory
#
# Every scenario runs in a **private tmux server** (`-L p13b2-$$`) and a fresh fixture project, so
# the real team session is never touched. The private server's panes inherit the server
# environment, which is why the identity isolation below is the first thing the script does.
#
# Scenarios
#   cursor   P20/B1  insertion-point cursor: codepoint steps, wide glyphs, line breaks, the window
#   keys     P20/B2  pi's key map: word/line/forward-delete, kill ring, Kitty encodings, undo
#   multiline P20/B3  ctrl+j inserts a break, enter submits, Kitty shift+enter, single-line reason
#   clipboard P20/B4  C-v: the image probe order, text fallback, the bounds, the temp file
#   cjk      2.1  CJK-wide cursor column + codepoint backspace (`tmux display -p '#{cursor_x}'`)
#   draft    2.2  Esc keeps the draft across a relaunch; `\r` is normalized on intake
#   editor   B3   `C-o` relays to $EDITOR (C-e is the line-end key); the relay is lossless
#   receipt  2.4  the three honest receipts: busy → queued, empty → delivered, eaten Enter → held
#   pause    2.5  a refresh completes mid-compose: the draft survives, the frame advanced
#   paste    2.6  plain and bracketed three-line pastes are one message each
#   actions  3.1  `f` runs `team outbox flush`; `s` toggles standby with a reason line
#   readonly 3.2  the write sweep: only the console's own files may change
#
# Exit: 0 every selected scenario green, 1 at least one assertion failed, 3 setup failure.
set -uo pipefail

# ── identity isolation (must be first): never inherit the caller's team identity ────────────────
unset TEAM_ROOT TEAM_MAIN_ROOT TEAM_ROOT_SOURCE TEAM_ROOT_WAS TEAM_PROJECT TEAM_SESSION TEAM_SESSION_FROM \
      TEAM_PM_WINDOW TEAM_AGENTS TEAM_DOCS_DIR TEAM_WORKTREES_DIR TEAM_GATES TEAM_VCS TEAM_CONFIG_FILE \
      TEAM_ALLOW_FOREIGN_SESSION TEAM_PULSE_WINDOW TEAM_WATCH_WINDOW TEAM_STATE_DIR TEAM_JS_BIN \
      TEAM_MONITOR_REFRESH TEAM_MONITOR_UI TEAM_MONITOR_ACTIVITY TEAM_AGENT_LOG_GLOB 2>/dev/null || true

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$here/lib/tmp-root.sh"
tree="${TEAM_B2_TREE:-$(cd -P "$here/../../.." && pwd)}"
skill="$tree/skills/teamsmith"
panel="${TEAM_B2_PANEL:-$skill/scripts/panel/panel.js}"
fake_tui="$here/fake-tui.py"

js="${TEAM_B2_JS:-$(command -v node || true)}"
[ -n "$js" ] || js="$(command -v bun || true)"
sock="p13b2-$$"
sess="p13b2-$$"
keep="${TEAM_B2_KEEP:-0}"
[ "$keep" = "1" ] && export TEAM_TMP_KEEP=1
tmp="$(tmp_root_create panel-b2)" || exit 3
PASS=0
FAIL=0
ROOT=""
current=""

# TEAM_B2_PANEL=<bundle>：翻转夹具用。启动器只会跑 $TEAM_SKILL_DIR/scripts/panel/panel.js，
# 所以把 skill 目录硬链成一份、换掉那个 bundle，再把 TEAM_SKILL_DIR 指过去。
if [ -n "${TEAM_B2_PANEL:-}" ]; then
  mkdir -p "$tmp/skill-flip"
  cp -al "$skill/." "$tmp/skill-flip/" 2>/dev/null || cp -r "$skill/." "$tmp/skill-flip/"
  rm -f "$tmp/skill-flip/scripts/panel/panel.js"
  cp "$TEAM_B2_PANEL" "$tmp/skill-flip/scripts/panel/panel.js"
  skill="$tmp/skill-flip"
  panel="$skill/scripts/panel/panel.js"
  skill_env="TEAM_SKILL_DIR=$(printf '%q' "$skill") "
fi

cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0
  tmux -L "$sock" kill-server 2>/dev/null || true
  rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$sock" 2>/dev/null || true
  if [ "$keep" = "1" ]; then
    printf '\n保留夹具目录：%s\n' "$tmp"
  else
    tmp_root_reap_all
  fi
}
trap cleanup EXIT

section() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }
ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || bad "$1（期望 [$3]，实际 [$2]）"; }
assert_has() { grep -qF -- "$2" "$1" 2>/dev/null && ok "$3" || bad "$3（$1 里找不到 [$2]）"; }
cond_skip() { printf '  \033[33mSKIP（条件不满足）\033[0m %s\n' "$1${2:+ —— $2}"; }
assert_match() { grep -qE -- "$2" "$1" 2>/dev/null && ok "$3" || bad "$3（$1 里没有匹配 [$2]）"; }
assert_not_has() { grep -qF -- "$2" "$1" 2>/dev/null && bad "$3（不该出现 [$2]）" || ok "$3"; }

if ! command -v tmux >/dev/null 2>&1; then
  printf 'panel-b2: tmux is required (the fixtures drive real panes)\n' >&2
  exit 3
fi
if ! command -v python3 >/dev/null 2>&1; then
  printf 'panel-b2: python3 is required (the fake PM pane)\n' >&2
  exit 3
fi
if [ -z "$js" ]; then
  printf 'panel-b2: no node/bun runtime for the console bundle\n' >&2
  exit 3
fi
[ -f "$panel" ] || { printf 'panel-b2: no bundle at %s\n' "$panel" >&2; exit 3; }
[ -f "$fake_tui" ] || { printf 'panel-b2: no fake TUI at %s\n' "$fake_tui" >&2; exit 3; }

# ---------------------------------------------------------------- fixture plumbing
server_up() { # <name> → fresh project + private tmux session
  current="$1"
  ROOT="$tmp/$1/root"
  mkdir -p "$ROOT"
  ( cd "$ROOT" && git init -q -b main && git config user.email b2@teamsmith && git config user.name b2 \
    && echo "# $1" > README.md && git add -A && git commit -qm init ) >/dev/null 2>&1
  mkdir -p "$ROOT/docs/team" "$ROOT/.pi/team/state"
  tmux -L "$sock" kill-server 2>/dev/null || true
  rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$sock" 2>/dev/null || true
  ( cd "$ROOT" && bash "$skill/scripts/team" init --session "$sess" --agents "dev verify" --vcs local \
      --gates "true" --docs docs/team ) >"$tmp/$1/init.log" 2>&1 \
    || { printf 'panel-b2: team init failed\n' >&2; tail -3 "$tmp/$1/init.log" >&2; exit 3; }
  mkdir -p "$ROOT/.pi/team/state" "$ROOT/docs/team"
  # The private server: the panes inherit its environment, and its `TMUX` routes every `team`
  # subprocess the console spawns back to this server (never the real session).
  tmux -L "$sock" new-session -d -s "$sess" -x 120 -y 30 -n bootstrap -c "$ROOT" 'sleep 600'
  # P20: the cursor/window scenarios resize their window; a manual window size keeps the resize
  # (no client is attached, so tmux would otherwise re-fit the session's default).
  tmux -L "$sock" set -g window-size manual 2>/dev/null || true
}

start_pm() { # <draft> [extra env string]
  local draft="$1" extra="${2:-}"
  tmux -L "$sock" kill-window -t "$sess:pm" 2>/dev/null || true
  tmux -L "$sock" new-window -d -t "$sess" -n pm -c "$ROOT" \
    "FAKE_TUI_DRAFT=$(printf '%q' "$draft") FAKE_TUI_COLS=100 FAKE_TUI_SUBMIT_LOG=$(printf '%q' "$tmp/$current/submit.log") $extra python3 '$fake_tui'"
  sleep 1
}

start_panel() { # [extra env string] [panel args...]
  local extra="${1:-}"
  [ $# -gt 0 ] && shift
  tmux -L "$sock" kill-window -t "$sess:panel" 2>/dev/null || true
  tmux -L "$sock" new-window -d -t "$sess" -n panel -c "$ROOT" \
    "TEAM_JS_BIN=$(printf '%q' "$js") ${skill_env:-}$extra exec bash '$skill/scripts/team' monitor --no-pulse --interval 1 ${*:-}"
  wait_panel
}

wait_panel() { # the first frame is on screen
  local i
  for i in $(seq 1 40); do
    if tmux -L "$sock" capture-pane -p -t "$sess:panel" 2>/dev/null | grep -qF 'teamsmith pulse'; then
      sleep 0.4
      return 0
    fi
    sleep 0.25
  done
  printf 'panel-b2: the console pane never rendered (%s)\n' "$current" >&2
  tmux -L "$sock" capture-pane -p -t "$sess:panel" 2>/dev/null | tail -5 >&2
  return 1
}

cap() { tmux -L "$sock" capture-pane -p -t "$sess:panel" -S -400 2>/dev/null; }
cap_to() { cap > "$tmp/$current/${1:-cap}.txt"; }
cap_has() { local f="$tmp/$current/${2:-cap}.txt"; cap >"$f"; assert_has "$f" "$1" "捕获里有 [$1]"; }
cap_not_has() { local f="$tmp/$current/${2:-cap}.txt"; cap >"$f"; assert_not_has "$f" "$1" "捕获里没有 [$1]"; }
pm_cap() { tmux -L "$sock" capture-pane -p -t "$sess:pm" -S -1000 2>/dev/null; }
keys() { tmux -L "$sock" send-keys -t "$sess:panel" "$@" 2>/dev/null; }
type_text() { tmux -L "$sock" send-keys -l -t "$sess:panel" "$1" 2>/dev/null; }
cursor_x() { tmux -L "$sock" display -p -t "$sess:panel" '#{cursor_x}' 2>/dev/null | tr -d ' '; }
cursor_y() { tmux -L "$sock" display -p -t "$sess:panel" '#{cursor_y}' 2>/dev/null | tr -d ' '; }
# The visible pane only (no scrollback): tmux's `#{cursor_y}` is 0-based over exactly these rows.
cap_visible() { tmux -L "$sock" capture-pane -p -t "$sess:panel" 2>/dev/null; }
# The 0-based visible row of the first line matching <pattern> (-1 when absent).
vis_row() { cap_visible | grep -nF -- "$1" | head -1 | cut -d: -f1 | awk '{print ($1 == "" ? -1 : $1 - 1)}'; }
# Draft rows as drawn in the boxed tray (`│ > …` / `│   …`; the hidden-rows marker has neither).
draft_rows() { cap_visible | grep -cE '^│ (>|  )'; }
# The number the hidden-rows marker counts, or 0 when the window hides nothing above.
marker_n() { cap_visible | sed -n 's/.*↑\([0-9][0-9]*\) 行.*/\1/p' | head -1; }
resize_pane() { tmux -L "$sock" resize-window -t "$sess:panel" -x "$1" -y "$2" 2>/dev/null || true; sleep 1.4; }
draft_lines_count() { grep -c '' "$(draft_file)" 2>/dev/null || printf '0'; }
stamp() { cap | grep -oE '[0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1; }
draft_file() { printf '%s\n' "$ROOT/.pi/team/state/draft.md"; }
draft() { cat "$(draft_file)" 2>/dev/null || true; }
entries() { find "$ROOT/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' -type f 2>/dev/null | LC_ALL=C sort; }
held_entries() { find "$ROOT/.pi/team/state/outbox/held" -maxdepth 1 -name '*.msg' -type f 2>/dev/null | LC_ALL=C sort; }
payload_of() { awk 'seen{print} $0=="---"{seen=1}' "$1" 2>/dev/null | sed -e '$ { /^$/d }'; }
submits() {
  local log="$tmp/$current/submit.log"
  if [ -f "$log" ]; then grep -c '^SUBMIT:' "$log" 2>/dev/null; else printf '0'; fi
}
last_submit() { sed -n 's/^SUBMIT://p' "$tmp/$current/submit.log" 2>/dev/null | tail -1; }
snapshot() { ( cd "$ROOT" && find .pi/team/state docs/team -type f 2>/dev/null | sort \
  | while IFS= read -r f; do printf '%s ' "$f"; md5sum "$f" | cut -d' ' -f1; done ) 2>/dev/null; }

# ---------------------------------------------------------------- 2.1 CJK cursor and backspace
scenario_cjk() {
  section "2.1 · m 打开输入行，中文宽字符光标与按码点退格"
  server_up cjk
  start_pm '' ''
  start_panel
  keys m
  sleep 0.8
  cap_to after-m
  assert_match "$tmp/cjk/after-m.txt" '│ >' "2.1 'm' 打开底部输入行（带框托盘）"
  type_text '中文ab'
  sleep 0.8
  cap_to after-cjk
  assert_eq "2.1 中文ab 之后 cursor_x=10（托盘 │ + 空格 =2 列，> =2 列 + 中文 4 列 + ab 2 列）" "$(cursor_x)" "10"
  assert_has "$tmp/cjk/after-cjk.txt" "> 中文ab" "2.1 输入行显示 > 中文ab"
  keys BSpace
  sleep 0.5
  assert_eq "2.1 退格删掉一个半角码点：cursor_x=9" "$(cursor_x)" "9"
  keys BSpace
  sleep 0.5
  cap_to after-bs
  assert_eq "2.1 退格删掉整个宽字符（不是半个）：cursor_x=8" "$(cursor_x)" "8"
  assert_has "$tmp/cjk/after-bs.txt" "> 中文" "2.1 宽字符被整字删除"
  keys BSpace
  sleep 0.5
  assert_eq "2.1 宽字符退格：中文 → 中，cursor_x=6" "$(cursor_x)" "6"
  # astral plane: one codepoint, two UTF-16 units — a code-unit backspace would leave half
  type_text '🙂'
  sleep 0.6
  assert_eq "2.1 星平面字符（emoji）按两个显示列计：cursor_x=8" "$(cursor_x)" "8"
  keys BSpace
  sleep 0.5
  cap_to after-emoji-bs
  assert_eq "2.1 emoji 退格整个码点删掉：cursor_x=6" "$(cursor_x)" "6"
  assert_has "$tmp/cjk/after-emoji-bs.txt" "> 中" "2.1 emoji 被整字删除（没有半个代理对）"
  assert_eq "2.1 草稿文件同步（state/draft.md）" "$(draft)" "中"
}

# ---------------------------------------------------------------- P20/B1 the insertion-point cursor
# The model's headless sibling first: the pure cases exit non-zero and name the failing case, so a
# pty-green bundle with a broken model cannot pass this scenario.
scenario_cursor() {
  section "B1 · 插入点：码点移动 / 宽字形 / 换行与软换行 / 草稿窗口"
  local bunbin=""
  bunbin="$(command -v bun 2>/dev/null || true)"
  [ -n "$bunbin" ] || { [ -x "$HOME/.bun/bin/bun" ] && bunbin="$HOME/.bun/bin/bun"; }
  if [ -n "$bunbin" ]; then
    if ( cd "$here" && "$bunbin" build panel-compose-model.ts --target=node --format=esm --outfile "$tmp/panel-compose-model.js" ) >"$tmp/cursor/model-build.log" 2>&1; then
      ok "B1 模型夹具：bun 构建成功"
    else
      bad "B1 模型夹具：bun 构建失败"; tail -3 "$tmp/cursor/model-build.log"
    fi
    if "$js" "$tmp/panel-compose-model.js" >"$tmp/cursor/model.log" 2>&1; then
      ok "B1 模型夹具：$(tail -1 "$tmp/cursor/model.log")"
    else
      bad "B1 模型夹具：纯模型用例失败"; grep -A1 '^FAIL' "$tmp/cursor/model.log" | head -6
    fi
  else
    cond_skip "B1 模型夹具" "本机没有 bun（模型夹具要构建 .ts）"
  fi

  server_up cursor
  start_pm '' ''
  start_panel
  # ① `ad` → ← → 中文 → ← → Backspace：编辑发生在插入点，宽字形是一步、整字删除
  keys m; sleep 0.8
  type_text 'ad'; sleep 0.5
  keys Left; sleep 0.4
  type_text '中文'; sleep 0.5
  keys Left; sleep 0.4
  keys BSpace; sleep 0.6
  cap_to after-bs
  assert_has "$tmp/cursor/after-bs.txt" '> a文d' "B1 插入点 Backspace：草稿 a文d"
  assert_eq "B1 草稿文件 a文d" "$(draft)" "a文d"
  assert_eq "B1 cursor_x=5（托盘 2 + 提示 2 + a）" "$(cursor_x)" "5"
  keys Right; sleep 0.5
  assert_eq "B1 跨宽字形一步 → cursor_x=7" "$(cursor_x)" "7"
  keys BSpace; sleep 0.6
  cap_to after-wide-bs
  assert_has "$tmp/cursor/after-wide-bs.txt" '> ad' "B1 宽字形整字删除（不剩半个）"
  assert_eq "B1 草稿回到 ad" "$(draft)" "ad"

  # ② 40 列 pane：40 个 x 的草稿，插入点在软换行的第二行；Home + Z 落回第一行
  keys Escape; sleep 0.4
  python3 -c 'import sys; sys.stdout.write("x"*40)' > "$(draft_file)"
  resize_pane 40 30
  keys m; sleep 0.9
  assert_eq "B1 软换行：插入点在第二绘制行 cursor_x=8" "$(cursor_x)" "8"
  keys Home; sleep 0.5
  type_text 'Z'; sleep 0.6
  cap_to wrap
  assert_eq "B1 Home 到逻辑行首：cursor_x=5" "$(cursor_x)" "5"
  assert_eq "B1 cursor_y 指向绘制 Z 的软换行第一行" "$(cursor_y)" "$(vis_row '> Zxxxx')"
  assert_eq "B1 草稿 = Z + 40 个 x（插入在插入点，不在末尾）" "$(draft)" "Z$(python3 -c 'import sys; sys.stdout.write("x"*40)')"

  # ③ 同一 40 列 pane：ab\nXXXXXXXX，↑ 钳到较短行
  keys Escape; sleep 0.4
  printf 'ab\nXXXXXXXX' > "$(draft_file)"
  keys m; sleep 0.9
  assert_eq "B1 换行草稿：插入点在第二行 cursor_x=12" "$(cursor_x)" "12"
  keys Up; sleep 0.6
  cap_to clamp
  assert_eq "B1 ↑ 钳到较短行 cursor_x=6" "$(cursor_x)" "6"
  assert_eq "B1 cursor_y 指向 ab 行" "$(cursor_y)" "$(vis_row '> ab')"
  assert_has "$tmp/cursor/clamp.txt" 'XXXXXXXX' "B1 另一行原样还在"

  # ④ 120x30：alpha\nbeta，Home/End/↑/X
  keys Escape; sleep 0.4
  resize_pane 120 30
  printf 'alpha\nbeta' > "$(draft_file)"
  keys m; sleep 0.9
  keys Home; sleep 0.4
  keys End; sleep 0.4
  keys Up; sleep 0.5
  type_text 'X'; sleep 0.6
  cap_to rows
  assert_eq "B1 Home+End+↑+X → alphXa\\nbeta" "$(draft)" "$(printf 'alphXa\nbeta')"
  assert_eq "B1 cursor_x=9（托盘+提示+alphX）" "$(cursor_x)" "9"
  assert_eq "B1 cursor_y 指向 alpha 行" "$(cursor_y)" "$(vis_row '> alphXa')"

  # ⑤ 120x20 + 30 行草稿：窗口 ≤ 10 行、含插入点行、顶沿计数隐藏行
  keys Escape; sleep 0.4
  resize_pane 120 20
  python3 -c 'import sys; sys.stdout.write("\n".join("L%02d" % i for i in range(1, 31)))' > "$(draft_file)"
  keys m; sleep 0.9
  cap_to window
  local rows_n marker1
  rows_n="$(draft_rows)"
  if [ "$rows_n" -le 10 ] && [ "$rows_n" -ge 1 ]; then
    ok "B1 窗口：草稿行 $rows_n ≤ 10（半屏）"
  else
    bad "B1 窗口：草稿行 $rows_n 不在 1..10"
  fi
  assert_has "$tmp/cursor/window.txt" 'L30' "B1 窗口：插入点所在行 L30 在画面里"
  marker1="$(marker_n)"
  if [ -n "$marker1" ] && [ "$marker1" -gt 0 ]; then
    ok "B1 窗口：顶沿标记隐藏行数（↑$marker1 行）"
  else
    bad "B1 窗口：没有隐藏行标记（$(head -1 "$tmp/cursor/window.txt" | cut -c1-40)）"
  fi
  assert_eq "B1 窗口：文件里仍是 30 行" "$(draft_lines_count)" "30"

  # ⑥ 窗口跟随插入点：↑ 12 次到 L18，标记计数变小
  local i
  for i in $(seq 1 12); do keys Up; sleep 0.15; done
  sleep 0.6
  cap_to window-follow
  local marker2
  assert_has "$tmp/cursor/window-follow.txt" 'L18' "B1 窗口跟随：插入点行 L18 可见"
  marker2="$(marker_n)"
  if [ -n "$marker2" ] && [ "$marker1" -gt "$marker2" ] && [ "$marker2" -gt 0 ]; then
    ok "B1 窗口跟随：上方隐藏行减少（↑$marker1 → ↑$marker2）"
  else
    bad "B1 窗口跟随：标记没有变小（↑$marker1 → ↑${marker2:-无}）"
  fi
}

# ---------------------------------------------------------------- P20/B2 the pi key map
scenario_keys() {
  section "B2 · pi 键位：词/行/前向删除、kill ring、Kitty 编码、undo"
  server_up keys
  start_pm '' ''
  start_panel
  # ① 词/行/前向删除：alpha beta gamma → ctrl+w alt+b ctrl+d ctrl+k ctrl+a Z
  keys m; sleep 0.8
  type_text 'alpha beta gamma'; sleep 0.5
  keys C-w; sleep 0.4        # 切 ` gamma`
  keys M-b; sleep 0.4        # 词左移到 beta 开头
  keys C-d; sleep 0.4        # 删前向一个码点（b）
  keys C-k; sleep 0.4        # 删到逻辑行尾
  keys C-a; sleep 0.4        # 逻辑行首
  type_text 'Z'; sleep 0.6
  cap_to words
  assert_eq "B2 词/行/前向删除 → Zalpha " "$(draft)" "Zalpha "
  assert_eq "B2 cursor_x=5（托盘+提示+Z）" "$(cursor_x)" "5"
  assert_eq "B2 没按过 Enter（未提交）" "$(submits)" "0"

  # ② 逻辑行边界：45 字符行 + second，↑ ctrl+a ctrl+k → \nsecond
  keys Escape; sleep 0.4
  resize_pane 40 30
  python3 -c 'import sys; sys.stdout.write("x"*45 + "\nsecond")' > "$(draft_file)"
  keys m; sleep 0.9
  keys Up; sleep 0.4
  keys C-a; sleep 0.4
  keys C-k; sleep 0.5
  cap_to line
  assert_eq "B2 ctrl+k 删的是逻辑行（整行 45 字符），不是绘制行" "$(draft)" "$(printf '\nsecond')"
  assert_eq "B2 cursor_x=4（托盘+提示，在已空的第一绘制行）" "$(cursor_x)" "4"

  # ③ Kitty 编码：ctrl+b ×3 + alt+b 与 legacy 字节落在同一插入点
  # （spec 原写 cursor_x 12；实测/算术都是 10 —— alpha beta 末尾 3×← 到 index 7、再一词到 6，
  #  `│ > alpha ` 共 10 列。两种编码必须一致，这条断言是硬约束，数值随实测修正。）
  keys Escape; sleep 0.4
  resize_pane 120 30
  printf 'alpha beta' > "$(draft_file)"
  keys m; sleep 0.9
  type_text $'\x1b[98;5u\x1b[98;5u\x1b[98;5u'; sleep 0.5
  type_text $'\x1b[98;3u'; sleep 0.6
  local kitty_x
  kitty_x="$(cursor_x)"
  assert_eq "B2 Kitty ctrl+b×3 + alt+b 后 cursor_x=10（alpha |beta）" "$kitty_x" "10"
  assert_eq "B2 Kitty 编码移动不改草稿" "$(draft)" "alpha beta"
  # 同一条序列的 legacy 字节（ctrl+b = 0x02 单独发；alt+b = ESC b）必须落在同一处。
  keys Escape; sleep 0.4
  printf 'alpha beta' > "$(draft_file)"
  keys m; sleep 0.9
  keys C-b; sleep 0.25; keys C-b; sleep 0.25; keys C-b; sleep 0.25
  keys M-b; sleep 0.5
  assert_eq "B2 legacy 字节复跑同一条序列落点与 Kitty 相同" "$(cursor_x)" "$kitty_x"

  # ④ kill ring：ctrl+w ctrl+a ctrl+k ctrl+y alt+y → ` gamma`
  keys Escape; sleep 0.4
  printf 'alpha beta gamma' > "$(draft_file)"
  keys m; sleep 0.9
  keys C-w; sleep 0.4
  keys C-a; sleep 0.4
  keys C-k; sleep 0.4
  keys C-y; sleep 0.4
  keys M-y; sleep 0.6
  cap_to ring
  assert_eq "B2 ring：ctrl+y 放回新的，alt+y 换成旧的 → 空格+gamma" "$(draft)" " gamma"

  # ⑦ 词边界用平台的 word segmenter（标点在 pi 里是停点）：alt+b/alt+d 不能把 alpha-beta 当一个词
  keys Escape; sleep 0.4
  printf 'alpha-beta gamma' > "$(draft_file)"
  keys m; sleep 0.9
  keys C-w; sleep 0.4        # 切 ` gamma`
  keys M-b; sleep 0.4        # 词左移：pi 停在 beta 开头（不是 alpha-beta 的开头）
  keys M-d; sleep 0.5        # 删 beta（alpha- 后停，不跨过标点）
  cap_to punctuation
  assert_eq "B2 标点是词停点：alpha-beta gamma → alpha-" "$(draft)" "alpha-"
  assert_eq "B2 标点停点后 cursor_x=10" "$(cursor_x)" "10"

  # ⑦半 word segmenter 对 CJK 真的分词（pi 用 Intl.Segmenter；「白空格规则」会把整串当一个词）
  keys Escape; sleep 0.4
  printf '中文中文' > "$(draft_file)"
  keys m; sleep 0.9
  keys M-b; sleep 0.4        # 词左移：pi 切出两个「中文」，回到后一个的开头
  type_text 'X'; sleep 0.5
  cap_to cjk-word
  assert_eq "B2 CJK 词边界：alt+b 只回上一个词（中文X中文）" "$(draft)" "中文X中文"
  assert_eq "B2 CJK 词边界后 cursor_x=9" "$(cursor_x)" "9"

  # ⑧ kill ring 累积：同方向连续切合并成一条（ctrl+w ×2 → ` beta gamma`）
  keys Escape; sleep 0.4
  printf 'alpha beta gamma' > "$(draft_file)"
  keys m; sleep 0.9
  keys C-w; sleep 0.3; keys C-w; sleep 0.4
  assert_eq "B2 两次 ctrl+w 后只剩 alpha" "$(draft)" "alpha"
  keys C-a; sleep 0.3
  keys C-k; sleep 0.4
  keys C-y; sleep 0.4
  keys M-y; sleep 0.6
  cap_to ring-accum
  assert_eq "B2 ring 累积：alt+y 换回合并的一条（空格+beta+空格+gamma）" "$(draft)" " beta gamma"

  # ⑤ undo：Z 之后 Kitty ctrl+- 恢复草稿与插入点，再按一次不变
  keys Escape; sleep 0.4
  printf 'ad' > "$(draft_file)"
  keys m; sleep 0.9
  keys Left; sleep 0.4
  type_text 'Z'; sleep 0.5
  type_text $'\x1b[45;5u'; sleep 0.6
  cap_to undo
  assert_eq "B2 ctrl+- 恢复草稿 ad" "$(draft)" "ad"
  assert_eq "B2 ctrl+- 同时恢复插入点 cursor_x=5" "$(cursor_x)" "5"
  type_text $'\x1b[45;5u'; sleep 0.6
  cap_to undo-empty
  assert_eq "B2 历史空了再按 ctrl+- 不变" "$(draft)" "ad"
  assert_has "$tmp/keys/undo-empty.txt" '> ad' "B2 undo 后帧仍完好"

  # ⑥ 未绑定的修饰键不插字母、不收控制台（P20 新断言：ctrl+c）
  keys C-c; sleep 0.6
  cap_to ctrlc
  assert_eq "B2 ctrl+c 不把 c 插进草稿" "$(draft)" "ad"
  assert_has "$tmp/keys/ctrlc.txt" 'teamsmith pulse' "B2 ctrl+c 没有收起控制台"
  local pane_pid args
  pane_pid="$(tmux -L "$sock" list-panes -t "$sess:panel" -F '#{pane_pid}' | head -1)"
  args="$(ps -o args= -p "$pane_pid" 2>/dev/null || true)"
  if printf '%s' "$args" | grep -q 'panel.js' && ! printf '%s' "$args" | grep -q -- '--headless'; then
    ok "B2 ctrl+c 之后窗口仍是渲染器（没被收起）"
  else
    bad "B2 ctrl+c 之后窗口进程不是渲染器：$args"
  fi
}

# ---------------------------------------------------------------- P20/B3 multi-line editing
scenario_multiline() {
  section "B3 · 多行编辑：C-j 插换行、Enter 仍提交、shift+enter、standby 理由单行化"
  server_up multiline
  start_pm 'PM draft' ''
  start_panel

  # ① legacy `\n`（= ctrl+j）插换行；Enter 仍提交，一条两行的消息
  keys m; sleep 0.7
  type_text 'ad'; sleep 0.4
  type_text $'\n'; sleep 0.5
  cap_to after-lf
  assert_eq "B3 legacy \\n 插入换行而不是提交（草稿 ad+LF）" "$(draft)" "$(printf 'ad\n')"
  assert_has "$tmp/multiline/after-lf.txt" '> ad' "B3 换行后第一行还在"
  type_text 'b'; sleep 0.5
  cap_to two-lines
  assert_has "$tmp/multiline/two-lines.txt" '  b' "B3 第二行带续行前缀渲染（同一草稿）"
  keys Enter; sleep 3
  assert_eq "B3 Enter 仍提交：恰好一条条目" "$(entries | wc -l | tr -d ' ')" "1"
  assert_eq "B3 条目保住两行" "$(payload_of "$(entries | head -1)")" $'ad\nb'
  assert_eq "B3 换行键没有直接提交（忙框下一次都没到 PM 框）" "$(submits)" "0"

  # ② Kitty ctrl+j（CSI 106;5u）与 shift+enter（CSI 13;2u）都插换行、都不提交
  printf 'ad' > "$(draft_file)"
  keys m; sleep 0.7
  type_text $'\x1b[106;5u'; sleep 0.4
  type_text 'b'; sleep 0.3
  type_text $'\x1b[13;2u'; sleep 0.4
  type_text 'c'; sleep 0.5
  cap_to kitty
  assert_eq "B3 Kitty ctrl+j + shift+enter → ad\\nb\\nc" "$(draft)" "$(printf 'ad\nb\nc')"
  assert_eq "B3 Kitty 两个换行键都没有提交" "$(submits)" "0"

  # ③ 粘贴三行仍是"一条草稿、一条消息"
  keys Escape; sleep 0.4
  printf '' > "$(draft_file)"
  keys m; sleep 0.7
  type_text $'p-one\np-two\np-three'; sleep 0.6
  keys Enter; sleep 3
  assert_eq "B3 粘贴三行 → 新增恰好一条条目" "$(entries | wc -l | tr -d ' ')" "2"
  assert_eq "B3 粘贴条目保住三行" "$(payload_of "$(entries | tail -1)")" $'p-one\np-two\np-three'

  # ④ standby 理由单行化：三行粘贴 → 一个空格分隔的参数；消息草稿不被动
  keys Escape; sleep 0.4
  printf 'half a thought' > "$(draft_file)"
  local wrapper="$tmp/multiline/team-wrap.sh"
  cat > "$wrapper" <<EOS
#!/usr/bin/env bash
printf 'INVOKE %s\n' "\$(printf '%q ' "\$@")" >> "$tmp/multiline/team.log"
exec "$skill/scripts/team" "\$@"
EOS
  chmod +x "$wrapper"
  rm -f "$tmp/multiline/team.log"
  tmux -L "$sock" kill-window -t "$sess:panel" 2>/dev/null || true
  tmux -L "$sock" new-window -d -t "$sess" -n panel -c "$ROOT" \
    "TEAM_JS_BIN=$(printf '%q' "$js") exec '$js' '$panel' --root '$ROOT' --team-cli '$wrapper' --state-dir '$ROOT/.pi/team/state' --no-pulse --interval 1"
  wait_panel
  keys s; sleep 0.9
  cap_to reason-open
  assert_has "$tmp/multiline/reason-open.txt" '待命原因' "B3 s 打开理由输入行"
  type_text $'one\ntwo\nthree'; sleep 0.6
  cap_to reason-typed
  assert_has "$tmp/multiline/reason-typed.txt" 'one two three' "B3 三行粘贴在理由里变成一行（空格分隔）"
  assert_not_has "$tmp/multiline/reason-typed.txt" '  two' "B3 理由区没有出现第二绘制行"
  keys Enter; sleep 3
  cap_to reason-sent
  assert_has "$tmp/multiline/reason-sent.txt" '待命 on' "B3 理由提交后显示待命 on"
  if grep -qF -- '--reason one\ two\ three' "$tmp/multiline/team.log"; then
    ok "B3 CLI 拿到一个参数 one two three（%q 里没有换行转义）"
  else
    bad "B3 CLI 没有拿到单行理由"; grep -m2 'reason' "$tmp/multiline/team.log" | head -2
  fi
  if grep -qF "\$'\\n'" "$tmp/multiline/team.log"; then
    bad "B3 理由参数里出现了换行转义"
  else
    ok "B3 理由参数里没有换行转义"
  fi
  assert_eq "B3 理由没有覆盖消息草稿" "$(draft)" "half a thought"
  ( cd "$ROOT" && bash "$skill/scripts/team" standby status ) > "$tmp/multiline/status.txt" 2>&1 || true
  assert_has "$tmp/multiline/status.txt" 'one two three' "B3 待命状态里也是单行理由"
}

# ---------------------------------------------------------------- P20/B4 the clipboard paste
scenario_clipboard() {
  section "B4 · 剪贴板图片：C-v → 临时文件、Wayland→X11、文本回退、无工具/挂死、理由、只读"
  server_up clipboard
  local fx="$tmp/clipboard"
  mkdir -p "$fx/fakebin" "$fx/tmpdir"

  # The probe's headless sibling first (the pure order/MIME/bounds).
  local bunbin=""
  bunbin="$(command -v bun 2>/dev/null || true)"
  [ -n "$bunbin" ] || { [ -x "$HOME/.bun/bin/bun" ] && bunbin="$HOME/.bun/bin/bun"; }
  if [ -n "$bunbin" ]; then
    if ( cd "$here" && "$bunbin" build panel-clipboard-model.ts --target=node --format=esm --outfile "$tmp/panel-clipboard-model.js" ) >"$fx/model-build.log" 2>&1; then
      ok "B4 模型夹具：bun 构建成功"
    else
      bad "B4 模型夹具：bun 构建失败"; tail -3 "$fx/model-build.log"
    fi
    if "$js" "$tmp/panel-clipboard-model.js" >"$fx/model.log" 2>&1; then
      ok "B4 模型夹具：$(tail -1 "$fx/model.log")"
    else
      bad "B4 模型夹具：纯模型用例失败"; grep -A1 '^FAIL' "$fx/model.log" | head -6
    fi
  else
    cond_skip "B4 模型夹具" "本机没有 bun"
  fi

  # The fake tools: each call is logged; the mode comes from the panel's environment.
  cat > "$fx/fakebin/wl-paste" <<'EOWS'
#!/usr/bin/env bash
printf 'wl-paste %s\n' "$*" >> "$P20_CLIP_LOG"
case "${P20_WL_MODE:-image}" in
  image)
    case "$1" in
      --list-types) printf 'text/plain;charset=utf-8\nimage/png\n' ;;
      --type) if [ "${2:-}" = "image/png" ]; then printf 'PNGDATA8'; else exit 1; fi ;;
      *) exit 1 ;;
    esac ;;
  text)
    case "$1" in
      --list-types) printf 'text/plain;charset=utf-8\n' ;;
      --no-newline) printf 'from the clipboard' ;;
      *) exit 1 ;;
    esac ;;
  hang) exec /bin/sleep 60 ;;
  *) exit 1 ;;
esac
EOWS
  cat > "$fx/fakebin/xclip" <<'EOXC'
#!/usr/bin/env bash
printf 'xclip %s\n' "$*" >> "$P20_CLIP_LOG"
case "${P20_X_MODE:-image}" in
  image) case "$*" in *TARGETS*) printf 'image/png\n' ;; *) printf 'XCLIPDATA' ;; esac ;;
  *) exit 1 ;;
esac
EOXC
  chmod +x "$fx/fakebin/wl-paste" "$fx/fakebin/xclip"

  clip_env() { # <wl mode> <x mode> [extra]
    printf 'PATH=%s:%s TMPDIR=%s P20_CLIP_LOG=%s P20_WL_MODE=%s P20_X_MODE=%s %s' \
      "$fx/fakebin" "$PATH" "$fx/tmpdir" "$fx/calls.log" "$1" "$2" "${3:-}"
  }
  pasted_file() { ls "$fx/tmpdir"/teamsmith-paste-* 2>/dev/null | head -1; }
  paste_count() { ls "$fx/tmpdir" 2>/dev/null | grep -c 'teamsmith-paste-' || true; }
  reset_clip() { rm -f "$fx/tmpdir"/teamsmith-paste-*; : > "$fx/calls.log"; }

  # ① 图片 → 临时文件路径，插在插入点；Wayland 优先且 xclip 不被调用
  printf 'ad' > "$(draft_file)"
  reset_clip
  start_pm '' ''
  start_panel "$(clip_env image image)"
  keys m; sleep 0.8
  keys Left; sleep 0.4
  keys C-v; sleep 1.5
  cap_to image
  local file
  file="$(pasted_file)"
  assert_eq "B4 TMPDIR 里恰好一个 teamsmith-paste-*.png" "$(paste_count)" "1"
  if [ -n "$file" ]; then
    ok "B4 文件名形状：$(basename "$file")"
  else
    bad "B4 没有写出 teamsmith-paste-*.png"
  fi
  assert_eq "B4 文件内容就是剪贴板的 8 字节" "$(cat "$file" 2>/dev/null)" "PNGDATA8"
  assert_eq "B4 路径插在插入点（a<path>d）" "$(draft)" "a${file}d"
  assert_has "$tmp/clipboard/image.txt" "$file" "B4 画面里也有这条路径"
  assert_match "$fx/calls.log" '^wl-paste --list-types$' "B4 探测先问 wl-paste"
  if grep -q '^xclip' "$fx/calls.log"; then bad "B4 Wayland 命中时不该调用 xclip"; else ok "B4 Wayland 命中时 xclip 没有被调用"; fi
  type_text 'Z'; sleep 0.5
  assert_eq "B4 粘贴后继续打字落到草稿（插入点之后）" "$(draft)" "a${file}Zd"

  # ② Wayland 失败 → X11：仍成图，调用日志里 wl-paste 在 xclip 之前
  keys Escape; sleep 0.4
  printf 'ad' > "$(draft_file)"
  reset_clip
  start_panel "$(clip_env fail image)"
  keys m; sleep 0.8
  keys Left; sleep 0.4
  keys C-v; sleep 1.5
  cap_to x11
  file="$(pasted_file)"
  assert_eq "B4 X11 回退：文件内容 XCLIPDATA" "$(cat "$file" 2>/dev/null)" "XCLIPDATA"
  assert_eq "B4 X11 回退：路径进草稿" "$(draft)" "a${file}d"
  local wl_line x_line
  wl_line="$(grep -n '^wl-paste' "$fx/calls.log" | head -1 | cut -d: -f1)"
  x_line="$(grep -n '^xclip' "$fx/calls.log" | head -1 | cut -d: -f1)"
  if [ -n "$wl_line" ] && [ -n "$x_line" ] && [ "$wl_line" -lt "$x_line" ]; then
    ok "B4 调用顺序：wl-paste($wl_line) 先于 xclip($x_line)"
  else
    bad "B4 调用顺序不对（wl=$wl_line x=$x_line）"; head -4 "$fx/calls.log"
  fi

  # ③ 无图片 → 文本回退，且不调用 xclip
  keys Escape; sleep 0.4
  printf 'ad' > "$(draft_file)"
  reset_clip
  start_panel "$(clip_env text image)"
  keys m; sleep 0.8
  keys Left; sleep 0.4
  keys C-v; sleep 1.5
  cap_to text-fallback
  assert_eq "B4 文本回退：afrom the clipboardd" "$(draft)" "afrom the clipboardd"
  assert_eq "B4 文本回退不写临时文件" "$(paste_count)" "0"
  if grep -q '^xclip' "$fx/calls.log"; then bad "B4 文本回退不该调用 xclip"; else ok "B4 文本回退不调用 xclip"; fi

  # ④ 两个工具都不给东西：什么都不变；挂死的工具在界内被放弃
  keys Escape; sleep 0.4
  printf 'half a thought' > "$(draft_file)"
  reset_clip
  start_panel "$(clip_env fail fail)"
  keys m; sleep 0.8
  keys C-v; sleep 1.5
  cap_to no-tool
  assert_eq "B4 无工具：草稿不变" "$(draft)" "half a thought"
  assert_eq "B4 无工具：没有文件" "$(paste_count)" "0"
  assert_has "$tmp/clipboard/no-tool.txt" '> half a thought' "B4 无工具：帧照常、没有错误行"
  type_text 'Z'; sleep 0.5
  assert_eq "B4 无工具后仍能打字" "$(draft)" "half a thoughtZ"

  keys Escape; sleep 0.4
  printf 'half a thought' > "$(draft_file)"
  reset_clip
  start_panel "$(clip_env hang fail)"
  keys m; sleep 0.8
  keys C-v; sleep 5
  cap_to hang
  assert_eq "B4 挂死工具 5s 内：草稿不变" "$(draft)" "half a thought"
  assert_eq "B4 挂死工具：没有文件" "$(paste_count)" "0"
  type_text 'Z'; sleep 0.5
  assert_eq "B4 挂死工具期间仍能打字" "$(draft)" "half a thoughtZ"
  keys Escape; sleep 0.5
  assert_eq "B4 Esc 仍关掉输入行并保留草稿" "$(draft)" "half a thoughtZ"

  # ⑤ 理由模式：路径进理由行，消息草稿不动
  printf 'half a thought' > "$(draft_file)"
  reset_clip
  start_panel "$(clip_env image image)"
  keys s; sleep 0.9
  type_text 'why'; sleep 0.4
  keys C-v; sleep 1.5
  cap_to reason
  file="$(pasted_file)"
  assert_has "$tmp/clipboard/reason.txt" "$file" "B4 理由行里有图片路径"
  assert_eq "B4 理由模式仍不写 state/draft.md" "$(draft)" "half a thought"

  # ⑥ 只读扫描：C-v 不调用任何 team 动作（数据读者不算动作）
  cat > "$fx/teamwrap.sh" <<EOS
#!/usr/bin/env bash
for a in "\$@"; do [ "\$a" = "__panel-data" ] && exit 0; done
printf '%s\n' "\$*" >> "$fx/team.log"
exec "$skill/scripts/team" "\$@"
EOS
  chmod +x "$fx/teamwrap.sh"
  keys Escape; sleep 0.4
  printf 'ad' > "$(draft_file)"
  reset_clip
  : > "$fx/team.log"
  tmux -L "$sock" kill-window -t "$sess:panel" 2>/dev/null || true
  tmux -L "$sock" new-window -d -t "$sess" -n panel -c "$ROOT" \
    "TEAM_JS_BIN=$(printf '%q' "$js") $(clip_env image image) exec '$js' '$panel' --root '$ROOT' --team-cli '$fx/teamwrap.sh' --state-dir '$ROOT/.pi/team/state' --no-pulse --interval 1"
  wait_panel
  keys m; sleep 0.8
  keys Left; sleep 0.4
  : > "$fx/team.log"
  keys C-v; sleep 1.5
  assert_eq "B4 只读：C-v 没有触发任何 team 动作" "$(wc -l < "$fx/team.log" 2>/dev/null | tr -d ' ')" "0"
  assert_eq "B4 只读：临时文件仍写在 TMPDIR 里" "$(paste_count)" "1"

  # ⑦ 不按 C-v 就绝不起剪贴板工具：5s 空闲（写信关着、开着各一段）调用日志为空
  reset_clip
  : > "$fx/calls.log"
  start_panel "$(clip_env image image)"
  sleep 5
  assert_eq "B4 空闲 5s（未写信号）没有调用剪贴板工具" "$(wc -l < "$fx/calls.log" | tr -d ' ')" "0"
  keys m; sleep 5
  assert_eq "B4 空闲 5s（写信中）没有调用剪贴板工具" "$(wc -l < "$fx/calls.log" | tr -d ' ')" "0"
}

# ---------------------------------------------------------------- 2.2 draft persistence / \r
scenario_draft() {
  section "2.2 · Esc 保留草稿、重开带出、\\r 归一"
  server_up draft
  start_pm '' ''
  start_panel
  keys m
  sleep 0.6
  type_text 'half a thought'
  sleep 0.5
  keys Escape
  sleep 0.6
  assert_eq "2.2 Esc 后 state/draft.md 保留草稿" "$(draft)" "half a thought"
  keys q
  sleep 1.2
  start_panel
  keys m
  sleep 0.8
  cap_to restored
  assert_has "$tmp/draft/restored.txt" "> half a thought" "2.2 重启后 m 带出草稿"
  # \r 归一：用带 CR 的粘贴进草稿（bracketed paste 里的 CR 是换行，不是提交）
  keys Escape
  sleep 0.4
  keys q
  sleep 1.2
  rm -f "$(draft_file)"
  start_panel
  keys m
  sleep 0.6
  type_text $'\x1b[200~cr-one\rcr-two\rcr-three\x1b[201~'
  sleep 0.8
  cap_to cr
  assert_eq "2.2 CR 归一为换行（三行草稿）" "$(draft)" $'cr-one\ncr-two\ncr-three'
  if printf '%s' "$(draft)" | grep -q $'\r'; then
    bad "2.2 草稿里不该留下 CR"
  else
    ok "2.2 草稿里没有 CR 字节"
  fi
  assert_has "$tmp/draft/cr.txt" "  cr-three" "2.2 三行都渲染在输入区"
}

# ---------------------------------------------------------------- 2.3 the editor relay
scenario_editor() {
  section "B3 · C-o 编辑器接力（C-e 迁到行尾；挂起期间渲染回调门控）"
  server_up editor

  # ── 迁移（spec scenario）：草稿 ad、插入点在两字之间；C-e 到行尾，绝不启动编辑器。
  cat > "$tmp/editor.sh" <<'EOS'
#!/usr/bin/env bash
printf 'EDITOR-ACTIVE\n'
printf 'ran\n' >> "${TEAM_B2_EDITOR_MARKER:?}"
printf '\nsecond line\n' >> "$1"
sleep "${TEAM_B2_EDITOR_HOLD:-2}"
printf 'EDITOR-DONE\n'
EOS
  chmod +x "$tmp/editor.sh"
  rm -f "$tmp/editor/marker"
  printf 'ad' > "$(draft_file)"
  start_pm 'PM draft' ''
  start_panel "EDITOR=$tmp/editor.sh TEAM_B2_EDITOR_HOLD=4 TEAM_B2_EDITOR_MARKER=$tmp/editor/marker"
  keys m
  sleep 0.7
  keys Left
  sleep 0.4
  assert_eq "B3 夹具：插入点在 ad 中间（cursor_x=5）" "$(cursor_x)" "5"
  keys C-e
  sleep 0.7
  assert_eq "B3 C-e 到行尾（cursor_x=6），不是编辑器" "$(cursor_x)" "6"
  assert_eq "B3 C-e 后草稿仍是 ad" "$(draft)" "ad"
  if [ -f "$tmp/editor/marker" ]; then
    bad "B3 C-e 竟然启动了编辑器（marker 存在）"
  else
    ok "B3 C-e 没有启动编辑器（marker 不存在）"
  fi
  cap_to c-e-line-end
  assert_not_has "$tmp/editor/c-e-line-end.txt" 'EDITOR-ACTIVE' "B3 C-e 没有把终端交给编辑器"
  keys Escape
  sleep 0.4

  # The handoff's raw bytes (design §6): `tmux pipe-pane` records everything the pane writes.
  rm -f "$tmp/editor/pane-bytes.log"
  tmux -L "$sock" pipe-pane -t "$sess:panel" -o "cat >> '$tmp/editor/pane-bytes.log'" 2>/dev/null || true

  # ── 接力本体：C-o 跑一次脚本，挂起期间不重绘，回来无损。
  printf '' > "$(draft_file)"
  keys m
  sleep 0.6
  type_text 'raw1'
  sleep 0.5
  keys C-o
  local saw_editor=1 i
  for i in $(seq 1 25); do
    if cap | grep -q 'EDITOR-ACTIVE'; then saw_editor=0; break; fi
    sleep 0.2
  done
  cap_to during-editor
  assert_eq "B3 C-o 把终端交给了编辑器" "$saw_editor" "0"
  local c1 c2
  c1="$(cap)"
  sleep 1.3
  c2="$(cap)"
  if [ -n "$c1" ] && [ "$c2" = "$c1" ]; then
    ok "B3 挂起期间屏幕静止（渲染回调门控生效，没有重绘）"
  else
    bad "B3 挂起期间仍在重绘（挂起门控没生效）"
  fi
  assert_not_has "$tmp/editor/during-editor.txt" 'EDITOR-DONE' "B3 编辑器还在跑"
  for i in $(seq 1 25); do
    cap | grep -q 'EDITOR-DONE' && break
    sleep 0.4
  done
  sleep 1
  cap_to after-editor
  assert_has "$tmp/editor/after-editor.txt" 'teamsmith pulse' "B3 接力回来后面板帧完好"
  assert_has "$tmp/editor/after-editor.txt" '> raw1' "B3 输入行保留 raw1"
  assert_has "$tmp/editor/after-editor.txt" 'second line' "B3 编辑器加的第二行无损带回"
  assert_eq "B3 C-o 只跑了恰好一次编辑器（marker 一行）" "$(grep -c '^ran$' "$tmp/editor/marker" 2>/dev/null || printf 0)" "1"
  # Kitty 协议的关/开字节（design §6）：handoff 前 `CSI < u`，编辑器退出后 `CSI > 1 u`。
  if [ -s "$tmp/editor/pane-bytes.log" ] \
     && LC_ALL=C grep -qF $'\x1b[<u' "$tmp/editor/pane-bytes.log" \
     && LC_ALL=C grep -qF $'\x1b[>1u' "$tmp/editor/pane-bytes.log"; then
    ok "B3 handoff 前写入 CSI < u、回来后 CSI > 1 u（pane 原始字节）"
  else
    bad "B3 Kitty 关/开字节缺失（pane-bytes.log $(wc -c < "$tmp/editor/pane-bytes.log" 2>/dev/null | tr -d ' ') 字节）"
  fi
  keys Enter
  sleep 3
  cap_to after-send
  assert_has "$tmp/editor/after-send.txt" 'queued' "B3 忙框回执 queued"
  local n e payload
  n="$(entries | wc -l | tr -d ' ')"
  assert_eq "B3 恰好一条队列条目" "$n" "1"
  e="$(entries | head -1)"
  payload="$(payload_of "$e")"
  assert_eq "B3 条目保住两行（无损）" "$payload" $'raw1\nsecond line'
  assert_eq "B3 发送成功后草稿文件清空" "$(wc -c < "$(draft_file)" | tr -d ' ')" "0"

  # 真 vi（E6 drive2 T5 的形状）：在 pane 里发 G/o/文本/Esc/:wq，接力回来仍然无损。
  # 夹具用 `vi -n`（无 swap 文件），只在 vi 存在时跑。
  if command -v vi >/dev/null 2>&1; then
    start_panel "EDITOR='vi -n'"
    keys m
    sleep 0.6
    type_text 'vi draft'
    sleep 0.4
    keys C-o
    sleep 1.6
    cap_to vi-open
    assert_has "$tmp/editor/vi-open.txt" 'vi draft' "B3 真 vi：草稿真的进了编辑器"
    keys G
    sleep 0.3
    keys o
    sleep 0.3
    type_text 'vi second line'
    sleep 0.3
    keys Escape
    sleep 0.3
    type_text ':wq'
    sleep 0.2
    keys Enter
    sleep 2.5
    cap_to vi-back
    assert_has "$tmp/editor/vi-back.txt" 'teamsmith pulse' "B3 真 vi：退出后面板帧正常"
    assert_has "$tmp/editor/vi-back.txt" '> vi draft' "B3 真 vi：第一行无损"
    assert_has "$tmp/editor/vi-back.txt" 'vi second line' "B3 真 vi：新增的第二行无损带回"
    keys Enter
    sleep 3
    cap_to vi-sent
    assert_has "$tmp/editor/vi-sent.txt" 'queued' "B3 真 vi：忙框回执 queued"
    local newest
    newest="$(entries | tail -1)"
    assert_eq "B3 真 vi：条目保住两行" "$(payload_of "$newest")" $'vi draft\nvi second line'
  else
    cond_skip "B3 真 vi 接力" "本机没有 vi"
  fi
}

# ---------------------------------------------------------------- 2.4 the three receipts
scenario_receipt() {
  section "2.4 · Enter 走守卫发送，回执三态"
  server_up receipt
  # ① busy box → queued；PM 草稿逐字节不变；渲染器一个键都没打
  start_pm '半句草稿 half a sentence' ''
  start_panel
  local before after
  before="$(pm_cap)"
  keys m
  sleep 0.6
  type_text 'hello'
  sleep 0.4
  keys Enter
  sleep 3
  cap_to busy
  assert_has "$tmp/receipt/busy.txt" 'queued' "2.4 忙框回执 queued"
  assert_eq "2.4 忙框：恰好一条队列条目" "$(entries | wc -l | tr -d ' ')" "1"
  assert_eq "2.4 忙框：条目 payload 是 hello" "$(payload_of "$(entries | head -1)")" "hello"
  after="$(pm_cap)"
  if [ "$before" = "$after" ]; then ok "2.4 忙框：PM 输入框逐字节不变（渲染器没打字）"; else bad "2.4 忙框：PM 输入框变了"; fi
  assert_eq "2.4 忙框：没有发生提交" "$(submits)" "0"

  # ② empty box → delivered
  tmux -L "$sock" kill-window -t "$sess:pm" 2>/dev/null || true
  rm -rf "$ROOT/.pi/team/state/outbox"
  start_pm '' ''
  keys m
  sleep 0.6
  type_text 'hello2'
  sleep 0.4
  keys Enter
  sleep 3
  cap_to delivered
  assert_has "$tmp/receipt/delivered.txt" 'delivered' "2.4 空框回执 delivered"
  assert_eq "2.4 空框：恰好一次提交" "$(submits)" "1"
  assert_eq "2.4 空框：提交内容是 hello2" "$(last_submit)" "hello2"
  assert_eq "2.4 空框：没有留下队列条目" "$(entries | wc -l | tr -d ' ')" "0"

  # ③ eaten Enter → held（payload 进过框一次：进 held/，绝不重贴）
  tmux -L "$sock" kill-window -t "$sess:pm" 2>/dev/null || true
  rm -rf "$ROOT/.pi/team/state/outbox"
  start_pm '' 'FAKE_TUI_EAT_ENTER=1 FAKE_TUI_STATIC_FOOTER=1'
  keys m
  sleep 0.6
  type_text 'held candidate'
  sleep 0.4
  keys Enter
  sleep 9
  cap_to held
  assert_has "$tmp/receipt/held.txt" 'held' "2.4 未确认投递回执 held"
  assert_eq "2.4 held：条目进了 outbox/held/" "$(held_entries | wc -l | tr -d ' ')" "1"
  assert_has "$ROOT/.pi/team/state/outbox/HOLDING.log" 'reason=unconfirmed' "2.4 held：HOLDING.log 记下 unconfirmed"
  assert_eq "2.4 held：活动队列为空" "$(entries | wc -l | tr -d ' ')" "0"
}

# ---------------------------------------------------------------- 2.5 compose pause
scenario_pause() {
  section "2.5 · 写信期间输入区暂停刷新、其余区照刷（慢读者）"
  server_up pause
  start_pm 'PM draft' ''
  local stub="$here/panel-b2-slow-stub.sh"
  tmux -L "$sock" kill-window -t "$sess:panel" 2>/dev/null || true
  tmux -L "$sock" new-window -d -t "$sess" -n panel -c "$ROOT" \
    "TEAM_JS_BIN=$(printf '%q' "$js") TEAM_B2_REAL_CLI=$(printf '%q' "$skill/scripts/team") TEAM_B2_SLOW_SLEEP=4 exec '$js' '$panel' --root '$ROOT' --team-cli '$stub' --state-dir '$ROOT/.pi/team/state' --no-pulse --refresh 1"
  wait_panel || return 1
  keys m
  sleep 0.6
  type_text 'before'
  sleep 0.6
  local ts1 ts2
  ts1="$(stamp)"
  sleep 6
  ts2="$(stamp)"
  if [ -n "$ts1" ] && [ "$ts2" != "$ts1" ]; then
    ok "2.5 写信期间别的区块刷新了（时间戳 $ts1 → $ts2）"
  else
    bad "2.5 写信期间没有刷新（$ts1 → $ts2）"
  fi
  type_text 'after'
  sleep 0.6
  cap_to pause
  assert_has "$tmp/pause/pause.txt" '> beforeafter' "2.5 草稿跨刷新存活（beforeafter）"
  assert_eq "2.5 草稿文件也是 beforeafter" "$(draft)" "beforeafter"
  keys Enter
  sleep 3
  assert_eq "2.5 跨刷新后的草稿仍作为一条消息入队" "$(payload_of "$(entries | head -1)")" "beforeafter"
}

# ---------------------------------------------------------------- 2.6 paste is one message
scenario_paste() {
  section "2.6 · 粘贴（plain / bracketed）三行 = 一条消息"
  server_up paste
  start_pm 'PM draft' ''
  start_panel
  # ① plain paste：一行 write 里带 LF
  keys m
  sleep 0.6
  type_text $'line one\nline two\nline three'
  sleep 0.6
  cap_to plain
  assert_has "$tmp/paste/plain.txt" '  line three' "2.6 plain 粘贴三行都在草稿里"
  keys Enter
  sleep 3
  assert_eq "2.6 plain：恰好一条条目" "$(entries | wc -l | tr -d ' ')" "1"
  assert_eq "2.6 plain：条目保住三行" "$(payload_of "$(entries | head -1)")" $'line one\nline two\nline three'
  # ② bracketed paste：DECSET 标记包裹，里面是 CR
  keys m
  sleep 0.6
  type_text $'\x1b[200~b-one\rb-two\rb-three\x1b[201~'
  sleep 0.6
  cap_to bracket
  assert_has "$tmp/paste/bracket.txt" '  b-three' "2.6 bracketed 粘贴三行都在草稿里"
  keys Enter
  sleep 3
  assert_eq "2.6 bracketed：两条条目（每次粘贴一条）" "$(entries | wc -l | tr -d ' ')" "2"
  assert_eq "2.6 bracketed：条目保住三行" "$(payload_of "$(entries | tail -1)")" $'b-one\nb-two\nb-three'
  assert_eq "2.6 两次粘贴都没有产生提交（忙框守卫）" "$(submits)" "0"
}

# ---------------------------------------------------------------- 3.1 the action layer
scenario_actions() {
  section "3.1 · f 冲刷走 CLI、s 待命开关（开时要一行理由）"
  server_up actions
  start_pm '' ''
  start_panel
  # 先留一份消息草稿，证明「理由」不会覆盖它
  keys m
  sleep 0.6
  type_text 'draft kept'
  sleep 0.4
  keys Escape
  sleep 0.5
  # 队列里放两条（目标窗口就是 fixture 的 PM，空框 → flush 可投）
  ( cd "$ROOT" && bash "$skill/scripts/team" outbox enqueue --kind say --target "$sess:pm" --from pm --payload 'q one' >/dev/null 2>&1
    bash "$skill/scripts/team" outbox enqueue --kind say --target "$sess:pm" --from pm --payload 'q two' >/dev/null 2>&1 )
  assert_eq "3.1 夹具：队列里两条" "$(entries | wc -l | tr -d ' ')" "2"
  keys f
  sleep 5
  cap_to flush
  assert_has "$tmp/actions/flush.txt" 'outbox' "3.1 f 的回执带 flush 自己的日志行"
  assert_eq "3.1 f 之后队列空了（flush 真跑了）" "$(entries | wc -l | tr -d ' ')" "0"
  assert_eq "3.1 flush 投了两条" "$(submits)" "2"
  # s：关 → 开（要理由）
  keys s
  sleep 0.8
  cap_to reason-input
  assert_has "$tmp/actions/reason-input.txt" '>' "3.1 s 打开理由输入行"
  type_text 'lunch'
  sleep 0.4
  keys Enter
  sleep 3
  cap_to standby-on
  assert_has "$tmp/actions/standby-on.txt" '待命 on' "3.1 s 之后回执显示待命 on"
  ( cd "$ROOT" && bash "$skill/scripts/team" standby status ) > "$tmp/actions/status-on.txt" 2>&1 || true
  assert_has "$tmp/actions/status-on.txt" 'standby: on' "3.1 CLI 报告 standby on"
  assert_has "$tmp/actions/status-on.txt" 'lunch' "3.1 CLI 记下理由 lunch"
  assert_eq "3.1 理由没有覆盖消息草稿" "$(draft)" "draft kept"
  keys s
  sleep 3
  cap_to standby-off
  assert_has "$tmp/actions/standby-off.txt" '待命 off' "3.1 再按 s 回执显示待命 off"
  ( cd "$ROOT" && bash "$skill/scripts/team" standby status ) > "$tmp/actions/status-off.txt" 2>&1 || true
  assert_has "$tmp/actions/status-off.txt" 'standby: off' "3.1 CLI 报告 standby off"
}

# ---------------------------------------------------------------- 3.2 the write sweep
scenario_readonly() {
  section "3.2 · 只读扫描：只有面板自己的文件会变"
  server_up readonly
  start_pm '' ''
  start_panel
  local before after
  before="$(snapshot)"
  printf '%s\n' "$before" > "$tmp/readonly/before.txt"
  keys r
  keys Up
  keys Down
  keys Tab
  type_text '1'
  type_text '2'
  type_text '3'
  for k in x z '?' '!' '~' 'w' '%' '&'; do type_text "$k"; done
  sleep 0.5
  keys m
  sleep 0.5
  type_text 'sweep draft'
  sleep 0.4
  keys Escape
  sleep 0.6
  keys q
  sleep 1
  after="$(snapshot)"
  printf '%s\n' "$after" > "$tmp/readonly/after.txt"
  local changed
  changed="$(diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | sed -n 's/^[<>] //p' | awk '{print $1}' | sort -u | tr '\n' ' ')"
  printf '   变化过的路径：%s\n' "${changed:-（无）}" >> "$tmp/readonly/after.txt"
  local off=""
  local p
  for p in $changed; do
    case "$p" in
      .pi/team/state/draft.md|.pi/team/state/panel.conf|.pi/team/state/panel-page) ;;
      *) off="$off $p" ;;
    esac
  done
  if [ -z "$off" ]; then
    ok "3.2 只读扫描：只变了面板自己的文件（${changed:-无}）"
  else
    bad "3.2 只读扫描：面板动了别人的文件：$off"
  fi
  assert_has "$(draft_file)" 'sweep draft' "3.2 草稿（允许写的文件之一）确实写了"
  assert_eq "3.2 文档/收件箱零改动" "$(printf '%s\n' "$after" | grep -c '^docs/team')" "$(printf '%s\n' "$before" | grep -c '^docs/team')"
}

# ---------------------------------------------------------------- runner
if [ "${BASH_SOURCE[0]}" != "$0" ]; then
  return 0 2>/dev/null || exit 0
fi
ALL="cursor keys multiline clipboard cjk draft editor receipt pause paste actions readonly"
selected="${*:-$ALL}"
mkdir -p "$tmp"
rc=0
for name in $selected; do
  mkdir -p "$tmp/$name"
  case "$name" in
    cursor) scenario_cursor ;;
    keys) scenario_keys ;;
    multiline) scenario_multiline ;;
    clipboard) scenario_clipboard ;;
    cjk) scenario_cjk ;;
    draft) scenario_draft ;;
    editor) scenario_editor ;;
    receipt) scenario_receipt ;;
    pause) scenario_pause ;;
    paste) scenario_paste ;;
    actions) scenario_actions ;;
    readonly) scenario_readonly ;;
    *) printf 'panel-b2: unknown scenario %s（known: %s）\n' "$name" "$ALL" >&2; rs=3 ;;
  esac || rc=$?
done

printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
if [ "$FAIL" -ne 0 ]; then
  printf '\033[31mpanel-b2 有失败项\033[0m\n'
  exit 1
fi
printf '\033[32mpanel-b2 全绿\033[0m\n'
exit "$rc"
