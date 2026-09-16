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
#   cjk      2.1  CJK-wide cursor column + codepoint backspace (`tmux display -p '#{cursor_x}'`)
#   draft    2.2  Esc keeps the draft across a relaunch; `\r` is normalized on intake
#   editor   2.3  `C-e` relays to $EDITOR with the render callback gated; the relay is lossless
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
tree="${TEAM_B2_TREE:-$(cd -P "$here/../../.." && pwd)}"
skill="$tree/skills/teamsmith"
panel="$skill/scripts/panel/panel.js"
fake_tui="$here/fake-tui.py"

js="${TEAM_B2_JS:-$(command -v node || true)}"
[ -n "$js" ] || js="$(command -v bun || true)"
sock="p13b2-$$"
sess="p13b2-$$"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/panel-b2.XXXXXX")"
keep="${TEAM_B2_KEEP:-0}"
PASS=0
FAIL=0
ROOT=""
current=""

cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0
  tmux -L "$sock" kill-server 2>/dev/null || true
  rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$sock" 2>/dev/null || true
  if [ "$keep" = "1" ]; then
    printf '\n保留夹具目录：%s\n' "$tmp"
  else
    rm -rf "$tmp"
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
    "TEAM_JS_BIN=$(printf '%q' "$js") $extra exec bash '$skill/scripts/team' monitor --no-pulse --interval 1 ${*:-}"
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
  assert_match "$tmp/cjk/after-m.txt" '^>$' "2.1 'm' 打开底部输入行"
  type_text '中文ab'
  sleep 0.8
  cap_to after-cjk
  assert_eq "2.1 中文ab 之后 cursor_x=8（> =2 列 + 中文 4 列 + ab 2 列）" "$(cursor_x)" "8"
  assert_has "$tmp/cjk/after-cjk.txt" "> 中文ab" "2.1 输入行显示 > 中文ab"
  keys BSpace
  sleep 0.5
  assert_eq "2.1 退格删掉一个半角码点：cursor_x=7" "$(cursor_x)" "7"
  keys BSpace
  sleep 0.5
  cap_to after-bs
  assert_eq "2.1 退格删掉整个宽字符（不是半个）：cursor_x=6" "$(cursor_x)" "6"
  assert_has "$tmp/cjk/after-bs.txt" "> 中文" "2.1 宽字符被整字删除"
  keys BSpace
  sleep 0.5
  assert_eq "2.1 宽字符退格：中文 → 中，cursor_x=4" "$(cursor_x)" "4"
  # astral plane: one codepoint, two UTF-16 units — a code-unit backspace would leave half
  type_text '🙂'
  sleep 0.6
  assert_eq "2.1 星平面字符（emoji）按两个显示列计：cursor_x=6" "$(cursor_x)" "6"
  keys BSpace
  sleep 0.5
  cap_to after-emoji-bs
  assert_eq "2.1 emoji 退格整个码点删掉：cursor_x=4" "$(cursor_x)" "4"
  assert_has "$tmp/cjk/after-emoji-bs.txt" "> 中" "2.1 emoji 被整字删除（没有半个代理对）"
  assert_eq "2.1 草稿文件同步（state/draft.md）" "$(draft)" "中"
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
  section "2.3 · C-e 编辑器接力（挂起期间渲染回调门控）"
  server_up editor
  cat > "$tmp/editor.sh" <<'EOS'
#!/usr/bin/env bash
printf 'EDITOR-ACTIVE\n'
printf '\nsecond line\n' >> "$1"
sleep "${TEAM_B2_EDITOR_HOLD:-2}"
printf 'EDITOR-DONE\n'
EOS
  chmod +x "$tmp/editor.sh"
  start_pm 'PM draft' ''
  start_panel "EDITOR=$tmp/editor.sh TEAM_B2_EDITOR_HOLD=4"
  keys m
  sleep 0.6
  type_text 'raw1'
  sleep 0.5
  keys C-e
  sleep 0.7
  cap_to during-editor
  assert_has "$tmp/editor/during-editor.txt" 'EDITOR-ACTIVE' "2.3 编辑器拿到了终端"
  local c1 c2
  c1="$(cap)"
  sleep 1.3
  c2="$(cap)"
  if [ -n "$c1" ] && [ "$c2" = "$c1" ]; then
    ok "2.3 挂起期间屏幕静止（渲染回调门控生效，没有重绘）"
  else
    bad "2.3 挂起期间仍在重绘（挂起门控没生效）"
  fi
  assert_not_has "$tmp/editor/during-editor.txt" 'EDITOR-DONE' "2.3 编辑器还在跑"
  local i
  for i in $(seq 1 25); do
    cap | grep -q 'EDITOR-DONE' && break
    sleep 0.4
  done
  sleep 1
  cap_to after-editor
  assert_has "$tmp/editor/after-editor.txt" 'teamsmith pulse' "2.3 接力回来后面板帧完好"
  assert_has "$tmp/editor/after-editor.txt" '> raw1' "2.3 输入行保留 raw1"
  assert_has "$tmp/editor/after-editor.txt" 'second line' "2.3 编辑器加的第二行无损带回"
  keys Enter
  sleep 3
  cap_to after-send
  assert_has "$tmp/editor/after-send.txt" 'queued' "2.3 忙框回执 queued"
  local n e payload
  n="$(entries | wc -l | tr -d ' ')"
  assert_eq "2.3 恰好一条队列条目" "$n" "1"
  e="$(entries | head -1)"
  payload="$(payload_of "$e")"
  assert_eq "2.3 条目保住两行（无损）" "$payload" $'raw1\nsecond line'
  assert_eq "2.3 发送成功后草稿文件清空" "$(wc -c < "$(draft_file)" | tr -d ' ')" "0"

  # 真 vi（E6 drive2 T5 的形状）：在 pane 里发 G/o/文本/Esc/:wq，接力回来仍然无损。
  # 夹具用 `vi -n`（无 swap 文件），只在 vi 存在时跑。
  if command -v vi >/dev/null 2>&1; then
    start_panel "EDITOR='vi -n'"
    keys m
    sleep 0.6
    type_text 'vi draft'
    sleep 0.4
    keys C-e
    sleep 1.6
    cap_to vi-open
    assert_has "$tmp/editor/vi-open.txt" 'vi draft' "2.3 真 vi：草稿真的进了编辑器"
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
    assert_has "$tmp/editor/vi-back.txt" 'teamsmith pulse' "2.3 真 vi：退出后面板帧完好"
    assert_has "$tmp/editor/vi-back.txt" '> vi draft' "2.3 真 vi：第一行无损"
    assert_has "$tmp/editor/vi-back.txt" 'vi second line' "2.3 真 vi：新增的第二行无损带回"
    keys Enter
    sleep 3
    cap_to vi-sent
    assert_has "$tmp/editor/vi-sent.txt" 'queued' "2.3 真 vi：忙框回执 queued"
    local newest
    newest="$(entries | tail -1)"
    assert_eq "2.3 真 vi：条目保住两行" "$(payload_of "$newest")" $'vi draft\nvi second line'
  else
    cond_skip "2.3 真 vi 接力" "本机没有 vi"
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
ALL="cjk draft editor receipt pause paste actions readonly"
selected="${*:-$ALL}"
mkdir -p "$tmp"
rc=0
for name in $selected; do
  mkdir -p "$tmp/$name"
  case "$name" in
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
