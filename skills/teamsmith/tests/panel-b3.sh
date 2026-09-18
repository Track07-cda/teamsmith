#!/usr/bin/env bash
# Console-surface fixtures (pulse-console B3, P14): the pty/tmux proofs for tasks.md items
# 4.1 pages/panel-page, 4.3 the queue list and full view, 5.1 settings/panel.conf, 5.2 resize,
# 6.2 language switch, 6.3 SGR mouse (direct pty + the tmux chain), 7.1 the q collapse.
#
#   bash skills/teamsmith/tests/panel-b3.sh                 # every scenario
#   bash skills/teamsmith/tests/panel-b3.sh pages settings  # selected scenarios
#   TEAM_B3_KEEP=1 bash skills/teamsmith/tests/panel-b3.sh  # keep the fixture directory
#
# Every scenario runs in a private tmux server (`-L p14b3-$$`) and a fresh fixture project; the
# data path is the deterministic `panel-b3-stub.sh`, so assertions never depend on this repo.
# Exit: 0 every selected scenario green, 1 at least one assertion failed, 3 setup failure.
set -uo pipefail

# ── identity isolation (must be first): never inherit the caller's team identity ────────────────
unset TEAM_ROOT TEAM_MAIN_ROOT TEAM_ROOT_SOURCE TEAM_ROOT_WAS TEAM_PROJECT TEAM_SESSION TEAM_SESSION_FROM \
      TEAM_PM_WINDOW TEAM_AGENTS TEAM_DOCS_DIR TEAM_WORKTREES_DIR TEAM_GATES TEAM_VCS TEAM_CONFIG_FILE \
      TEAM_ALLOW_FOREIGN_SESSION TEAM_PULSE_WINDOW TEAM_WATCH_WINDOW TEAM_STATE_DIR TEAM_JS_BIN \
      TEAM_MONITOR_REFRESH TEAM_MONITOR_UI TEAM_MONITOR_ACTIVITY TEAM_AGENT_LOG_GLOB TEAM_PULSE_INTERVAL \
      TEAM_WATCH_INTERVAL 2>/dev/null || true

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tree="${TEAM_B3_TREE:-$(cd -P "$here/../../.." && pwd)}"
skill="$tree/skills/teamsmith"
panel="$skill/scripts/panel/panel.js"
stub="$here/panel-b3-stub.sh"
pty_direct="$here/panel-b3-pty-mouse.py"
pty_tmux="$here/panel-b3-pty-tmux-mouse.py"

js="${TEAM_B3_JS:-$(command -v node || true)}"
[ -n "$js" ] || js="$(command -v bun || true)"
sock="p14b3-$$"
sess="p14b3-$$"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/panel-b3.XXXXXX")"
keep="${TEAM_B3_KEEP:-0}"
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
assert_not() { grep -qF -- "$2" "$1" 2>/dev/null && bad "$3（不该出现 [$2]）" || ok "$3"; }
assert_match() { grep -qE -- "$2" "$1" 2>/dev/null && ok "$3" || bad "$3（$1 里没有匹配 [$2]）"; }
cond_skip() { printf '  \033[33mSKIP（条件不满足）\033[0m %s\n' "$1${2:+ —— $2}"; }

if ! command -v tmux >/dev/null 2>&1; then
  printf 'panel-b3: tmux is required (the fixtures drive real panes)\n' >&2
  exit 3
fi
if ! command -v python3 >/dev/null 2>&1; then
  printf 'panel-b3: python3 is required (the pty drivers)\n' >&2
  exit 3
fi
if [ -z "$js" ]; then
  printf 'panel-b3: no node/bun runtime for the console bundle\n' >&2
  exit 3
fi
[ -f "$panel" ] || { printf 'panel-b3: no bundle at %s\n' "$panel" >&2; exit 3; }
[ -f "$stub" ] || { printf 'panel-b3: no stub at %s\n' "$stub" >&2; exit 3; }

# ---------------------------------------------------------------- fixture plumbing
server_up() { # <name> → fresh project + private tmux session
  current="$1"
  ROOT="$tmp/$1/root"
  mkdir -p "$ROOT"
  ( cd "$ROOT" && git init -q -b main && git config user.email b3@teamsmith && git config user.name b3 \
    && echo "# $1" > README.md && git add -A && git commit -qm init ) >/dev/null 2>&1
  mkdir -p "$ROOT/docs/team" "$ROOT/.pi/team/state"
  tmux -L "$sock" kill-server 2>/dev/null || true
  rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$sock" 2>/dev/null || true
  ( cd "$ROOT" && bash "$skill/scripts/team" init --session "$sess" --agents "dev verify" --vcs local \
      --gates "true" --docs docs/team ) >"$tmp/$1/init.log" 2>&1 \
    || { printf 'panel-b3: team init failed\n' >&2; tail -3 "$tmp/$1/init.log" >&2; exit 3; }
  mkdir -p "$ROOT/.pi/team/state" "$ROOT/docs/team"
  tmux -L "$sock" new-session -d -s "$sess" -x 120 -y 32 -n bootstrap -c "$ROOT" 'sleep 900'
  tmux -L "$sock" set -g window-size manual 2>/dev/null || true
  state="$ROOT/.pi/team/state"
}

start_panel() { # [extra env assignments] [panel args...]
  local extra="${1:-}"
  [ $# -gt 0 ] && shift
  tmux -L "$sock" kill-window -t "$sess:panel" 2>/dev/null || true
  tmux -L "$sock" new-window -d -t "$sess" -n panel -c "$ROOT" \
    "TEAM_JS_BIN=$(printf '%q' "$js") $extra exec '$js' '$panel' --root '$ROOT' --state-dir '$state' \
      --team-cli '$stub' --no-pulse --interval 1 ${*:-}"
  wait_panel
}

wait_panel() {
  local i
  for i in $(seq 1 60); do
    if tmux -L "$sock" capture-pane -p -t "$sess:panel" 2>/dev/null | grep -qF 'teamsmith pulse'; then
      sleep 0.4
      return 0
    fi
    sleep 0.25
  done
  printf 'panel-b3: the console pane never rendered (%s)\n' "$current" >&2
  tmux -L "$sock" capture-pane -p -t "$sess:panel" 2>/dev/null | tail -5 >&2
  return 1
}

cap() { tmux -L "$sock" capture-pane -p -t "$sess:panel" -S -400 2>/dev/null; }
cap_to() { cap > "$tmp/$current/${1:-cap}.txt"; }
cap_has() { local f="$tmp/$current/${2:-cap}.txt"; cap >"$f"; assert_has "$f" "$1" "捕获里有 [$1]"; }
cap_not() { local f="$tmp/$current/${2:-cap}.txt"; cap >"$f"; assert_not "$f" "$1" "捕获里没有 [$1]"; }
keys() { tmux -L "$sock" send-keys -t "$sess:panel" "$@" 2>/dev/null; }
conf() { printf '%s/panel.conf' "$state"; }
page_file() { printf '%s/panel-page' "$state"; }
conf_set() { mkdir -p "$state"; printf '%s\n' "$@" > "$(conf)"; }
page_of() { cat "$(page_file)" 2>/dev/null | tr -d '\n'; }
conf_of() { cat "$(conf)" 2>/dev/null || true; }
hash_state() { ( cd "$ROOT" && find .pi/team/state -type f | sort | while IFS= read -r f; do printf '%s ' "$f"; md5sum "$f" | cut -d' ' -f1; done ) | md5sum; }


# Which card id sits under the focus cursor (the board page's `›`), or `-` when there is none.
focused_id() { # <capture file>
  python3 - "$1" <<'PYF'
import re, sys

rows = [re.sub(r"\x1b\[[0-9;]*m", "", l.rstrip("\n")) for l in open(sys.argv[1], encoding="utf-8")]
ids = []
for r in rows:
    if "›" not in r:
        continue
    hit = re.search(r"›[^A-Za-z0-9]*([A-Za-z]+[0-9][0-9-]*)", r)
    if hit:
        ids.append(hit.group(1))
print(ids[0] if len(ids) == 1 else (",".join(ids) if ids else "-"))
PYF
}
# The ids visible in the lane whose column contains <col> (1-based display column).
lane_ids() { # <capture file> <col>
  python3 - "$1" "$2" <<'PYL'
import re, sys

WIDE = [(0x1100,0x115f),(0x2e80,0x303e),(0x3041,0x33ff),(0x3400,0x4dbf),(0x4e00,0x9fff),(0xa000,0xa4cf),(0xac00,0xd7a3),(0xf900,0xfaff),(0xfe10,0xfe19),(0xfe30,0xfe6f),(0xff00,0xff60),(0xffe0,0xffe6)]

def cells(text):
    out = []
    for ch in text:
        out.append(ch)
        if any(a <= ord(ch) <= b for a, b in WIDE):
            out.append("")
    return out

rows = [re.sub(r"\x1b\[[0-9;]*m", "", l.rstrip("\n")) for l in open(sys.argv[1], encoding="utf-8")]
col = int(sys.argv[2])
ids = []
for r in rows:
    c = cells(r)
    win = "".join(c[col - 1 : col + 20]) if col - 1 < len(c) else ""
    hit = re.search(r"([A-Za-z]+[0-9][0-9-]*)", win)
    if hit:
        ids.append(hit.group(1))
print(",".join(ids))
PYL
}

# ---------------------------------------------------------------- scenarios

scn_pages() {
  section "pages · 三页 + panel-page 记忆（4.1）"
  server_up pages
  start_panel
  cap_has "项目进度" p1.txt
  cap_has "代理" p1.txt
  keys 2
  sleep 1
  cap_has "任务看板" p2.txt
  cap_has "活动变更" p2.txt
  assert_eq "按 2 后 panel-page=2" "$(page_of)" "2"
  # The compose line opens from every page (B2's requirement, kept by the console).
  keys m
  sleep 0.5
  cap_has "Enter 发送" p2-compose.txt
  keys Escape
  sleep 0.3
  keys 3
  sleep 1
  cap_has "延后队列" p3.txt
  assert_eq "按 3 后 panel-page=3" "$(page_of)" "3"
  keys m
  sleep 0.5
  cap_has "Enter 发送" p3-compose.txt
  keys Escape
  sleep 0.3
  # Relaunch: the page is restored (no key sent).
  start_panel
  cap_has "延后队列" p3-relaunch.txt
  assert_eq "重启后打开上次的页（panel-page=3）" "$(page_of)" "3"
  keys 1
  sleep 1
  cap_has "项目进度" p1-again.txt
  assert_eq "按 1 回总览" "$(page_of)" "1"
}

scn_settings() {
  section "settings · 设置浮层 + panel.conf（5.1/6.2）"
  server_up settings
  conf_set "lang=zh" "page=1" "activity=1" "mouse=1" "density=comfortable" "theme=auto"
  start_panel
  keys ,
  sleep 0.8
  cap_has "设置" overlay.txt
  # The selected row is language: Enter switches zh -> en and it applies on the next frame.
  keys Enter
  sleep 0.8
  cap_has "language" lang-en.txt
  assert_has "$(conf)" "lang=en" "切换语言写进 panel.conf"
  # Down three rows to the mouse preference and toggle it off.
  keys Down Down Down
  sleep 0.3
  keys Enter
  sleep 0.8
  assert_has "$(conf)" "mouse=0" "鼠标开关写进 panel.conf"
  keys Down
  sleep 0.2
  keys Enter
  sleep 0.6
  assert_has "$(conf)" "density=compact" "密度开关写进 panel.conf"
  keys ,
  sleep 0.5
  cap_not "设置" overlay-closed.txt
  # Relaunch keeps the preferences (English + the overlay values).
  start_panel
  cap_has "progress" relaunch.txt
  assert_match "$(conf)" '^lang=en$' "重启后语言偏好仍在"
  # defaultPage cycles over the four pages and wraps (P18/B2 left the cycle over three: 4 fell
  # through to 5 and the next launch reset the page silently — fixed and pinned in B3).
  keys ,
  sleep 0.6
  keys Down
  sleep 0.3
  local cyc
  for cyc in 2 3 4 1; do
    keys Enter
    sleep 0.5
    assert_eq "defaultPage 循环到 $cyc（四页 + 回绕）" "$(sed -n 's/^page=//p' "$(conf)" | tr -d '\n')" "$cyc"
  done
  keys Escape
  sleep 0.4
}

scn_conf() {
  section "settings · 坏/缺 panel.conf 走默认，机读出口不受影响（5.1）"
  server_up conf
  local -a cap_env=(TEAM_MEMINFO_FILE="$tmp/meminfo" TEAM_SWAPFILE_PATH="$tmp/swaps")
  printf 'MemTotal: 1000000 kB\nMemAvailable: 4040000 kB\nSwapFree: 0 kB\n' > "$tmp/meminfo"
  printf 'Filename Type Size Used Priority\n' > "$tmp/swaps"
  ( cd "$ROOT" && env "${cap_env[@]}" bash "$skill/scripts/team" monitor --print --width 120 --height 20 ) >"$tmp/$current/print-a.txt" 2>/dev/null
  mkdir -p "$state"; printf '\000\001garbage\377\n' > "$(conf)"
  ( cd "$ROOT" && env "${cap_env[@]}" bash "$skill/scripts/team" monitor --print --width 120 --height 20 ) >"$tmp/$current/print-b.txt" 2>/dev/null
  RC=$?
  assert_eq "坏 panel.conf 下 --print 退出 0" "$RC" "0"
  norm() { sed -E 's/[0-9]{2}:[0-9]{2}:[0-9]{2}/TIME/' "$1"; }
  if diff <(norm "$tmp/$current/print-a.txt") <(norm "$tmp/$current/print-b.txt") >/dev/null; then
    ok "坏 panel.conf 与无 panel.conf 的 --print 逐字一致（除时间戳）"
  else
    bad "坏 panel.conf 改变了 --print 的内容"; diff <(norm "$tmp/$current/print-a.txt") <(norm "$tmp/$current/print-b.txt") | head -4
  fi
  # The TUI falls back to the defaults (zh).
  start_panel
  cap_has "项目进度" tui-defaults.txt
}

scn_queue() {
  section "queue · 队列列表 + 全文只读（4.3）"
  server_up queue
  local ob="$state/outbox"
  mkdir -p "$ob/held"
  printf 'kind: notify\ntarget: pm\n---\n第一行\n第二行\n' > "$ob/1758000000000-001-pm.msg"
  printf 'kind: say\ntarget: pm\n---\n排队中的第二条\n' > "$ob/1758000001000-002-pm.msg"
  printf 'kind: notify\ntarget: pm\n---\n被扣住的副本\n' > "$ob/held/1757990000000-003-pm.msg"
  local before after
  before="$(hash_state)"
  start_panel
  keys 3
  sleep 1
  cap_has "延后队列 2" queue-list.txt
  cap_has "1758000001000-002-pm.msg" queue-list.txt
  cap_has "滞留" queue-list.txt
  cap_has "扣住原因：draft-raced" queue-list.txt
  keys Enter
  sleep 0.8
  cap_has "条目全文" queue-view.txt
  cap_has "第一行" queue-view.txt
  cap_has "第二行" queue-view.txt
  keys Escape
  sleep 0.4
  cap_has "延后队列 2" queue-back.txt
  after="$(hash_state)"
  # The page/conf files are the console's own; the queue must be byte-identical.
  local qbefore qafter
  qbefore="$(cd "$ROOT" && find .pi/team/state/outbox -type f | sort | xargs -r md5sum | md5sum)"
  keys 1
  sleep 0.8
  qafter="$(cd "$ROOT" && find .pi/team/state/outbox -type f | sort | xargs -r md5sum | md5sum)"
  assert_eq "查看全文/翻页后队列逐字节不变" "$qafter" "$qbefore"
  [ "$before" != "$after" ] && ok "夹具自检：state 的指纹确实变了（面板写了 page/conf 这两处）" \
    || bad "夹具自检：state 指纹没变（断言可能是空的）"
}

scn_mouse() {
  section "mouse · SGR 直驱 + tmux 全链路（6.3）"
  server_up mouse
  conf_set "lang=zh" "page=1" "activity=1" "mouse=1" "density=comfortable" "theme=dark"
  # (a) direct pty with the preference on: enable sequence + a click on the 工作 tab switches the page.
  python3 "$pty_direct" --js "$js" --panel "$panel" --root "$ROOT" --state-dir "$state" --team-cli "$stub" \
    --out "$tmp/$current/direct-on.bin" --expect-enable yes --expect-page 2 --click-col 12 --click-row 2 \
    >"$tmp/$current/direct-on.log" 2>&1
  assert_eq "直驱 pty：鼠标开 → 有 enable 序列且点页签切到 P2" "$?" "0"
  # (b) preference off: no sequence at all, and the click does nothing.
  conf_set "lang=zh" "page=1" "activity=1" "mouse=0" "density=comfortable" "theme=dark"
  rm -f "$(page_file)"
  python3 "$pty_direct" --js "$js" --panel "$panel" --root "$ROOT" --state-dir "$state" --team-cli "$stub" \
    --out "$tmp/$current/direct-off.bin" --expect-enable no --expect-page "" --click-col 12 --click-row 2 \
    >"$tmp/$current/direct-off.log" 2>&1
  assert_eq "直驱 pty：鼠标关 → 0 个鼠标序列" "$?" "0"
  if [ "$(page_of)" = "2" ]; then
    bad "鼠标关时点击页签仍然切了页（click 不该生效）"
  else
    ok "鼠标关时点击页签没有切页"
  fi
  if grep -qF $'\033[?1000h' "$tmp/$current/direct-off.bin"; then
    bad "鼠标关时仍写了 1000h"
  else
    ok "鼠标关的原始字节里没有 1000h/1006h"
  fi
  # (d) the overlay's mouse toggle takes effect on the next frame: after toggling it off the console
  # emits the disable sequence (and no new enable), and the tab click no longer switches pages.
  conf_set "lang=zh" "page=1" "activity=1" "mouse=1" "density=comfortable" "theme=dark"
  rm -f "$(page_file)"
  python3 "$pty_direct" --js "$js" --panel "$panel" --root "$ROOT" --state-dir "$state" --team-cli "$stub" \
    --out "$tmp/$current/toggle.bin" --expect-enable yes --toggle-mouse-off --click-col 12 --click-row 2 \
    >"$tmp/$current/toggle.log" 2>&1
  assert_eq "直驱 pty：浮层里关掉鼠标 → 下一帧发出 disable 序列" "$?" "0"
  if [ "$(page_of)" = "2" ]; then
    bad "关掉鼠标后点击页签仍切页"
  else
    ok "关掉鼠标后点击页签无效（偏好已即时生效）"
  fi
  assert_has "$(conf)" "mouse=0" "浮层写回 panel.conf"

  # (c) the full chain: a real terminal clicks the m hint and the compose line opens.
  conf_set "lang=zh" "page=1" "activity=1" "mouse=1" "density=comfortable" "theme=dark"
  start_panel
  python3 "$pty_tmux" --sock "$sock" --session "$sess" --pane "$sess:panel" --hint "m 写信" \
    --out "$tmp/$current/chain.bin" --rows 32 --cols 120 >"$tmp/$current/chain.log" 2>&1
  assert_eq "tmux 全链路：点在 m 提示上" "$?" "0"
  sleep 0.6
  cap_has "Enter 发送" chain-compose.txt
}

scn_wheel() {
  section "mouse · 滚轮滚动（6.3）"
  server_up wheel
  conf_set "lang=zh" "page=3" "activity=1" "mouse=1" "density=comfortable" "theme=dark"
  # The wheel shifts the patrol block's visible window (the stub has five lines). tmux keeps wheel
  # events for itself even when the pane has requested reporting (measured), so the wheel is driven
  # the same way the reference measurement was: directly on the pty (the click chain keeps tmux).
  python3 "$pty_direct" --js "$js" --panel "$panel" --root "$ROOT" --state-dir "$state" --team-cli "$stub" \
    --out "$tmp/$current/wheel.bin" --out2 "$tmp/$current/wheel-after.bin" --expect-enable yes \
    --click-col 72 --click-row 6 --wheel down --wheel-clicks 3 >"$tmp/$current/wheel.log" 2>&1
  assert_eq "直驱 pty：滚轮事件已注入且退出 0" "$?" "0"
  if grep -qF '10:00:00Z' "$tmp/$current/wheel-after.bin"; then
    bad "滚轮后滚出的帧里还有 10:00:00Z（窗口没有后移）"
  elif grep -qF '10:45:00Z' "$tmp/$current/wheel-after.bin"; then
    ok "滚轮下滚 3 格：可见窗口后移（10:00:00Z 移出、10:45:00Z 进入）"
  else
    bad "滚轮后滚出的帧里没有 10:45:00Z（滚动没生效）"; head -c 300 "$tmp/$current/wheel-after.bin" | cat -v
  fi
}

scn_resize() {
  section "layout · resize 实时重排（5.2）"
  server_up resize
  tmux -L "$sock" resize-window -t "$sess:panel" -x 99 -y 32 2>/dev/null || true
  start_panel
  tmux -L "$sock" resize-window -t "$sess:panel" -x 99 -y 32 2>/dev/null || true
  sleep 0.6
  cap_to narrow
  assert_has "$tmp/$current/narrow.txt" "代理" "99 列：单列仍渲染 agent 表"
  # Reflow to the wide tier: the agent table and the right block share a row.
  tmux -L "$sock" resize-window -t "$sess:panel" -x 160 -y 32 2>/dev/null || true
  sleep 1.2
  cap_to wide
  if grep -qE '代理.*活动（仅本 session' "$tmp/$current/wide.txt"; then
    ok "160 列：重排成双列（表头与右栏同一行）"
  else
    bad "160 列：没有重排成双列"; sed -n '1,3p' "$tmp/$current/wide.txt"
  fi
  # Boundary captures at the four tiers (the real pane is resized for each).
  for w in 160 100 99 60 59; do
    tmux -L "$sock" resize-window -t "$sess:panel" -x "$w" -y 32 2>/dev/null || true
    sleep 0.9
    cap_to "w$w"
    if ! grep -q 'teamsmith pulse' "$tmp/$current/w$w.txt"; then
      bad "$w 列：帧是空的"
      continue
    fi
    if [ "$w" = "160" ] || [ "$w" = "100" ]; then
      if grep -qE '代理.*活动（仅本 session' "$tmp/$current/w$w.txt"; then
        ok "$w 列：双列（表头与右栏同一行）"
      else
        bad "$w 列：应为双列"
      fi
    elif [ "$w" = "99" ] || [ "$w" = "60" ]; then
      if grep -qE '代理.*活动（仅本 session' "$tmp/$current/w$w.txt"; then
        bad "$w 列：不该是双列"
      else
        ok "$w 列：单列"
      fi
    else
      if grep -q '●在' "$tmp/$current/w$w.txt" && grep -qF '41k/272k' "$tmp/$current/w$w.txt"; then
        ok "$w 列：最小档（状态缩写、会话列完整）"
      else
        bad "$w 列：最小档没有生效"; sed -n '6,9p' "$tmp/$current/w$w.txt"
      fi
    fi
  done
}

scn_collapse() {
  section "collapse · q 收起后巡检仍在跑（7.1）"
  server_up collapse
  # The patrol interval is 2s so the tick's capacity line grows inside the fixture window. It must
  # live in the project config, not the launcher's shell: `respawn-window` starts the headless loop
  # from the tmux server's environment, not from the collapsing pane's.
  printf 'TEAM_PULSE_INTERVAL=2\n' >> "$ROOT/.pi/team/config.sh"
  tmux -L "$sock" new-window -d -t "$sess" -n cmd -c "$ROOT" \
    "bash '$skill/scripts/team' pulse up > '$tmp/$current/up.log' 2>&1; sleep 1"
  sleep 5
  assert_has "$tmp/$current/up.log" "巡检已在" "pulse up 起了窗口"
  local wins_before; wins_before="$(tmux -L "$sock" list-windows -t "$sess" | wc -l | tr -d ' ')"
  tmux -L "$sock" capture-pane -p -t "$sess:pulse" > "$tmp/$current/console.txt" 2>/dev/null
  assert_has "$tmp/$current/console.txt" "teamsmith pulse" "pulse 窗口里是控制台"
  # q collapses: same window, a headless tick loop, capacity.log keeps gaining lines.
  tmux -L "$sock" send-keys -t "$sess:pulse" q
  sleep 3
  local wins_after; wins_after="$(tmux -L "$sock" list-windows -t "$sess" | wc -l | tr -d ' ')"
  assert_eq "收前后窗口数不变（一个后端、一个窗口）" "$wins_after" "$wins_before"
  local pane_pid args
  pane_pid="$(tmux -L "$sock" list-panes -t "$sess:pulse" -F '#{pane_pid}' | head -1)"
  args="$(ps -o args= -p "$pane_pid" 2>/dev/null || true)"
  if printf '%s' "$args" | grep -q -- '--headless'; then
    ok "窗口里跑的是无界面巡检（$(printf '%s' "$args" | tr -s ' ' | cut -c1-80)）"
  else
    bad "窗口里的进程不是 --headless：$args"
  fi
  local c1 c2
  c1="$(grep -c . "$state/capacity.log" 2>/dev/null || echo 0)"
  sleep 5
  c2="$(grep -c . "$state/capacity.log" 2>/dev/null || echo 0)"
  if [ "${c2:-0}" -gt "${c1:-0}" ]; then
    ok "收起后巡检仍在跑（capacity.log $c1 → $c2 行）"
  else
    bad "收起后巡检停了（capacity.log $c1 → $c2 行）"
  fi
  tmux -L "$sock" new-window -d -t "$sess" -n cmd2 -c "$ROOT" \
    "bash '$skill/scripts/team' pulse status > '$tmp/$current/status-headless.log' 2>&1; sleep 0.3; \
     bash '$skill/scripts/team' pulse up > '$tmp/$current/up2.log' 2>&1"
  sleep 6
  assert_has "$tmp/$current/status-headless.log" "无界面 tick" "pulse status 报无界面形态"
  assert_has "$tmp/$current/up2.log" "恢复成控制台" "pulse up 原地恢复控制台"
  tmux -L "$sock" capture-pane -p -t "$sess:pulse" > "$tmp/$current/restored.txt" 2>/dev/null
  assert_has "$tmp/$current/restored.txt" "teamsmith pulse" "恢复后同一窗口里又是控制台"
}

scn_board() {
  section "board · 看板页：第四页记忆 / 焦点随重排 / 车道滚动 / 鼠标（4.2/5.3/5.4/6.1/6.2）"
  server_up board
  bcap() { cap > "$tmp/$current/$1.txt"; }               # write a capture under the fixture dir
  bfile() { printf '%s/%s.txt' "$tmp/$current" "$1"; }   # read it back
  conf_set "lang=zh" "page=1" "activity=1" "mouse=1" "density=comfortable" "theme=dark"
  rm -f "$(page_file)"
  start_panel
  # 4.2: `4` switches, the file remembers it, a relaunch restores it.
  keys 4
  sleep 1
  bcap p4
  assert_has "$(bfile p4)" "已放弃" "按 4 切到看板页（六车道在场）"
  assert_eq "按 4 后 panel-page=4" "$(page_of)" "4"
  start_panel
  bcap relaunch
  assert_has "$(bfile relaunch)" "已放弃" "重启后仍在看板页（panel-page 记忆）"
  assert_eq "重启后 panel-page 仍是 4" "$(page_of)" "4"
  # 4.2: an out-of-range file falls back to the default page, never an error.
  printf '9\n' > "$(page_file)"
  start_panel
  bcap oob
  assert_has "$(bfile oob)" "项目进度" "panel-page=9 时回落到默认页（总览）"
  assert_not "$(bfile oob)" "已放弃" "panel-page=9 时没有渲染看板页"
  # 5.3: the focus is keyed by entry id — a reorder keeps it, a removal falls back inside the lane.
  board_a="$tmp/$current/board-a.json"
  board_b="$tmp/$current/board-b.json"
  board_c="$tmp/$current/board-c.json"
  python3 - "$board_a" "$board_b" "$board_c" <<'PYB'
import json, sys

def row(i, state, title):
    return {"id": i, "title": title, "agent": "dev", "branch": "-", "deps": "-", "state": state, "phase": "apply"}

a = [row("M9", "todo", "聚焦的卡片"), row("M8", "todo", "第二条"), row("M7", "wip", "进行中的一条")]
b = [row("M8", "todo", "第二条"), row("M9", "todo", "聚焦的卡片"), row("M7", "wip", "进行中的一条")]
c = [row("M7", "wip", "进行中的一条"), row("M9", "todo", "聚焦的卡片")]
for path, rows in ((sys.argv[1], a), (sys.argv[2], b), (sys.argv[3], c)):
    json.dump({"rows": rows, "counts": {}, "total": len(rows), "deliveries": []}, open(path, "w"))
PYB
  printf '4\n' > "$(page_file)"
  start_panel "B3_STUB_BOARD_FILE='$board_a'"
  sleep 1
  bcap focus-a
  assert_eq "初始焦点在 M9（首条非空车道的第一张）" "$(focused_id "$(bfile focus-a)")" "M9"
  keys Down
  sleep 0.6
  bcap focus-m8
  assert_eq "↓ 把焦点移到 M8" "$(focused_id "$(bfile focus-m8)")" "M8"
  cp "$board_b" "$board_a.tmp" && mv "$board_a.tmp" "$board_a"
  keys r
  sleep 1
  bcap focus-reordered
  assert_eq "重排后焦点仍在 M8（按 id 跟踪，不按行号）" "$(focused_id "$(bfile focus-reordered)")" "M8"
  cp "$board_c" "$board_a.tmp" && mv "$board_a.tmp" "$board_a"
  keys r
  sleep 1
  bcap focus-vanished
  assert_eq "M8 离开看板后焦点落到该车道第一条（M9）" "$(focused_id "$(bfile focus-vanished)")" "M9"
  # 5.4: a 20-card done lane anchors on the newest and counts what it hides; the wheel scrolls it.
  start_panel "B3_STUB_DONE=20"
  sleep 1
  bcap lane-first
  assert_has "$(bfile lane-first)" "↓" "20 张 done：第一帧在底边报出隐藏数量"
  assert_has "$(bfile lane-first)" "D20" "20 张 done：第一帧锚定最新（D20 可见）"
  assert_has "$(bfile lane-first)" "D01" "20 张 done：车道窗口里能看到更旧的卡片"
  done_col="$(python3 - "$(bfile lane-first)" <<'PYC'
import re, sys

WIDE = [(0x1100,0x115f),(0x2e80,0x303e),(0x3041,0x33ff),(0x3400,0x4dbf),(0x4e00,0x9fff),(0xa000,0xa4cf),(0xac00,0xd7a3),(0xf900,0xfaff),(0xfe10,0xfe19),(0xfe30,0xfe6f),(0xff00,0xff60),(0xffe0,0xffe6)]

def disp(text):
    return sum(2 if any(a <= ord(ch) <= b for a, b in WIDE) else 1 for ch in text)

rows = [re.sub(r"\x1b\[[0-9;]*m", "", l.rstrip("\n")) for l in open(sys.argv[1], encoding="utf-8")]
head = next((r for r in rows if "完成" in r), "")
print(disp(head.split("完成")[0]) + 3 if head else 63)
PYC
)"
  # The wheel is injected into its own pty instance (tmux keeps wheel events for itself, measured in
  # this suite's other wheel scenario), so the evidence is that instance's own byte stream: the rows
  # Ink rewrites when the lane window moves hold ids that were hidden before.
  B3_STUB_DONE=20 python3 "$pty_direct" --js "$js" --panel "$panel" --root "$ROOT" --state-dir "$state" \
    --team-cli "$stub" --out "$tmp/$current/wheel-lane.bin" --out2 "$tmp/$current/wheel-lane-after.bin" \
    --expect-enable yes --click-col "${done_col:-63}" --click-row 6 --wheel up --wheel-clicks 3 \
    --cols 120 --rows 32 >"$tmp/$current/wheel-lane.log" 2>&1
  assert_eq "直驱 pty：车道内滚轮事件注入成功（6.2）" "$?" "0"
  if grep -qE 'D0[1-5]' "$tmp/$current/wheel-lane-after.bin" 2>/dev/null; then
    ok "车道内滚轮上滚：done 窗口移到更旧的卡片（原先隐藏的 D01–D05 进入视图）"
  else
    bad "车道内滚轮上滚后没有看到原先隐藏的 done 卡片（车道没有滚动）"
  fi

  # 6.1: a click on a card focuses it — in the injected instance's own bytes, the focus cursor has
  # to move onto the clicked card (the start of the frame puts it on the first card of `todo`).
  B3_STUB_DONE=20 python3 "$pty_direct" --js "$js" --panel "$panel" --root "$ROOT" --state-dir "$state" \
    --team-cli "$stub" --out "$tmp/$current/click-card.bin" --expect-enable yes \
    --click-col 25 --click-row 4 --cols 120 --rows 32 >"$tmp/$current/click-card.log" 2>&1
  assert_eq "直驱 pty：卡片点击注入成功（6.1）" "$?" "0"
  click_moved="$(python3 - "$tmp/$current/click-card.bin" <<'PYM'
import re, sys

raw = open(sys.argv[1], "rb").read().decode("utf-8", "replace")
clean = re.sub(r"\x1b\[[0-9;?]*[A-Za-z]", "", raw)
# The cursor glyph followed by the clicked card's id on the same written row.
print("ok" if re.search(r"›\s*(?:[·▸◆✓✗—]\s*)?P14", clean) else "no")
PYM
)"
  if [ "$click_moved" = "ok" ]; then
    ok "点击 wip 车道第一张卡后焦点光标落在 P14 上（点击 = 聚焦）"
  else
    bad "点击卡片后焦点没有移到被点的卡（$click_moved）"
  fi
}

scn_detail() {
  section "detail · 详情视图：打开/返回 / tab / 滚动 / 只读 / 首帧（9.1–9.4）"
  server_up detail
  dcap() { cap > "$tmp/$current/$1.txt"; }
  dfile() { printf '%s/%s.txt' "$tmp/$current" "$1"; }
  local docs_before other_before
  # Real files under docs/ so the read-only proof has something to hash; the data itself is the stub.
  mkdir -p "$ROOT/docs/team/tasks" "$ROOT/docs/team/reports" "$ROOT/docs/team/reviews"
  printf '# fixture board\n' > "$ROOT/docs/team/BOARD.md"
  printf '# V14 · real brief\n\nhand-written\n' > "$ROOT/docs/team/tasks/V14-a.md"
  printf '# V14 · real report\n' > "$ROOT/docs/team/reports/V14-dev.md"
  printf '# V14 · real review\n' > "$ROOT/docs/team/reviews/V14.md"
  printf '# V14 · real review (done)\n' > "$ROOT/docs/team/reviews/V14-done.md"
  conf_set "lang=zh" "page=4" "activity=1" "mouse=1" "density=comfortable" "theme=dark"
  printf '4\n' > "$(page_file)"
  # 9.3's baseline: everything under docs/ plus every state file except the console's own three
  # (draft.md / panel.conf / panel-page — the console is allowed to write exactly those).
  docs_before="$(cd "$ROOT" && find docs -type f | sort | xargs -r md5sum | md5sum)"
  other_before="$(cd "$ROOT" && find .pi/team/state -type f ! -name draft.md ! -name panel.conf ! -name panel-page | sort | xargs -r md5sum | md5sum)"
  start_panel
  dcap board
  assert_has "$(dfile board)" "已放弃" "夹具：控制台停在看板页（六车道在场）"

  # 9.1 + 9.4: Enter opens the focused card's detail; the first detail frame is timed from the key,
  # then the view is waited for (the first frame is the loading state — the block is one child away).
  local t0 t1 opened=1 i
  t0="$(date +%s.%N)"
  keys Enter
  for i in $(seq 1 40); do
    if cap | grep -qF '详情'; then opened=0; break; fi
    sleep 0.03
  done
  t1="$(date +%s.%N)"
  assert_eq "Enter 后 1.2s 内出现详情视图" "$opened" "0"
  printf '  \033[36m·\033[0m 首帧耗时（Enter→详情标题上屏）：%ss\n' "$(awk -v a="$t0" -v b="$t1" 'BEGIN { printf "%.3f", b - a }')"
  for i in $(seq 1 40); do
    if cap | grep -qF '[brief]'; then break; fi
    sleep 0.05
  done
  dcap open
  assert_has "$(dfile open)" "详情 V14" "详情视图打开（卡片聚焦的入口）"
  assert_has "$(dfile open)" "[brief]" "第一个文件 tab 默认打开"
  assert_has "$(dfile open)" "fixture brief" "详情视图渲染了 brief 的正文"
  assert_has "$(dfile open)" "verbatim fence body" "围栏代码块正文原样上屏"
  assert_not "$(dfile open)" "已放弃" "详情视图替换了看板块（替换块不留内容）"

  # 9.2: ←/→ switch files, ↑/↓ scroll the document.
  keys Right
  sleep 0.8
  dcap report
  assert_has "$(dfile report)" "[report:dev]" "→ 切到第二个文件 tab"
  assert_has "$(dfile report)" "report line 01" "报告的正文从第一行开始"
  for i in 1 2 3 4 5 6 7 8; do keys Down; sleep 0.08; done
  sleep 0.6
  dcap scrolled
  assert_has "$(dfile scrolled)" "report line 09" "↓×8 把文档窗口后移（第 9 行进入视图）"
  assert_not "$(dfile scrolled)" "report line 01" "滚动后第 1 行移出窗口"
  keys Up
  sleep 0.5
  dcap scrolled-back
  assert_has "$(dfile scrolled-back)" "report line 08" "↑ 往回滚一行（第 8 行回到视图）"

  # 9.1: q and Esc both return to the board page without collapsing the console.
  keys q
  sleep 0.8
  dcap back-q
  assert_has "$(dfile back-q)" "已放弃" "q 返回看板页"
  assert_not "$(dfile back-q)" "详情 V14" "q 之后详情视图关闭"
  local pane_pid args
  pane_pid="$(tmux -L "$sock" list-panes -t "$sess:panel" -F '#{pane_pid}' | head -1)"
  args="$(ps -o args= -p "$pane_pid" 2>/dev/null || true)"
  if printf '%s' "$args" | grep -q 'panel.js' && ! printf '%s' "$args" | grep -q -- '--headless'; then
    ok "q 没有收起控制台（窗口进程仍是渲染器：$(printf '%s' "$args" | tr -s ' ' | cut -c1-60)）"
  else
    bad "q 之后窗口进程不是渲染器：$args"
  fi
  keys Enter
  sleep 0.8
  keys Escape
  sleep 0.8
  dcap back-esc
  assert_has "$(dfile back-esc)" "已放弃" "Esc 返回看板页"
  assert_not "$(dfile back-esc)" "详情 V14" "Esc 之后详情视图关闭"

  # 9.3: read-only — only the console's own three state files may differ after the session.
  local docs_after other_after
  docs_after="$(cd "$ROOT" && find docs -type f | sort | xargs -r md5sum | md5sum)"
  other_after="$(cd "$ROOT" && find .pi/team/state -type f ! -name draft.md ! -name panel.conf ! -name panel-page | sort | xargs -r md5sum | md5sum)"
  assert_eq "详情会话没有写 docs/ 下任何文件" "$docs_before" "$docs_after"
  assert_eq "详情会话没有写 state/ 下除控制台自有三文件之外的任何文件" "$other_before" "$other_after"

  # 9.2 [real] mouse: a click on a tab switches files; the wheel scrolls the document (the driver's
  # own byte stream is the evidence, because tmux keeps wheel events for itself — measured in the
  # board scenario).
  python3 "$pty_direct" --js "$js" --panel "$panel" --root "$ROOT" --state-dir "$state" --team-cli "$stub" \
    --out "$tmp/$current/detail-open.bin" --out2 "$tmp/$current/detail-click.bin" --expect-enable yes --no-click \
    --send enter --click2-col 27 --click2-row 4 --cols 120 --rows 32 >"$tmp/$current/detail-click.log" 2>&1
  assert_eq "直驱 pty：详情视图里点 review tab 注入成功" "$?" "0"
  detail_clean() { python3 - "$1" <<'PYD'
import re, sys
raw = open(sys.argv[1], "rb").read().decode("utf-8", "replace")
print(re.sub(r"\x1b\[[0-9;?]*[A-Za-z]", "", raw))
PYD
}
  # A redirect, not a pipe: `grep -q` exits early and a piped python would die with SIGPIPE under
  # `set -o pipefail`, turning a match into a failure (measured while writing this fixture).
  detail_clean "$tmp/$current/detail-click.bin" > "$tmp/$current/detail-click.txt"
  assert_has "$tmp/$current/detail-click.txt" '[review]' "点击 tab 行切到 review（[review] 高亮）"
  python3 "$pty_direct" --js "$js" --panel "$panel" --root "$ROOT" --state-dir "$state" --team-cli "$stub" \
    --out "$tmp/$current/detail-wheel.bin" --out2 "$tmp/$current/detail-wheel-after.bin" --expect-enable yes --no-click \
    --send enter,right --wheel down --wheel-clicks 6 --click-col 60 --click-row 8 --cols 120 --rows 32 \
    >"$tmp/$current/detail-wheel.log" 2>&1
  assert_eq "直驱 pty：详情视图里滚轮注入成功" "$?" "0"
  detail_clean "$tmp/$current/detail-wheel-after.bin" > "$tmp/$current/detail-wheel.txt"
  if grep -qE 'report line (09|1[0-9])' "$tmp/$current/detail-wheel.txt"; then
    ok "滚轮把详情文档窗口后移（更靠后的报告行上屏）"
  else
    bad "滚轮没有让详情文档滚动"
  fi

  # 8.2 [real]: a hostile fixture text embedding ESC [2J cannot inject escape sequences into the
  # pane — the reader strips the raw control byte and the panel's sanitizer drops the CSI sequence,
  # so the frame survives and only the fence's visible text shows (the plain capture carries no
  # 0x1b byte, and the -e capture carries no injected clear).
  python3 - "$tmp/$current/hostile.json" <<'PYX'
import json, sys

doc = "```\nBEFORE\u001b[2JAFTER\n```\n"
json.dump({"id": "X3", "count": 1, "file": "docs/team/tasks/X3-a.md", "text": doc, "truncated": False,
           "files": [{"tab": "brief", "name": "X3-a.md", "path": "docs/team/tasks/X3-a.md", "size": 40, "truncated": False}]},
          open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False)
PYX
  start_panel "B3_STUB_DETAIL_FILE='$tmp/$current/hostile.json'"
  keys Enter
  sleep 1.0
  cap > "$tmp/$current/hostile-plain.txt"
  tmux -L "$sock" capture-pane -p -e -t "$sess:panel" > "$tmp/$current/hostile-esc.txt" 2>/dev/null
  assert_has "$tmp/$current/hostile-plain.txt" "BEFORE" "敌意字节：围栏前的可见文本仍在（帧没被清屏）"
  assert_has "$tmp/$current/hostile-plain.txt" "AFTER" "敌意字节：围栏后的可见文本仍在"
  if LC_ALL=C grep -q $'\x1b' "$tmp/$current/hostile-plain.txt"; then
    bad "敌意字节：纯文本捕获里出现了 0x1b"
  else
    ok "敌意字节：纯文本捕获里没有 0x1b 字节"
  fi
  if grep -qF '[2J' "$tmp/$current/hostile-esc.txt"; then
    bad "敌意字节：带转义的捕获里出现了注入的 [2J"
  else
    ok "敌意字节：带转义的捕获里没有注入的清屏序列"
  fi
}

# ---------------------------------------------------------------- run
want=("$@")
run_scn() {
  local name="$1"
  if [ ${#want[@]} -gt 0 ]; then
    local w
    for w in "${want[@]}"; do [ "$w" = "$name" ] && { "$2"; return; }; done
    return
  fi
  "$2"
}

run_scn pages scn_pages
run_scn settings scn_settings
run_scn conf scn_conf
run_scn queue scn_queue
run_scn board scn_board
run_scn detail scn_detail
run_scn mouse scn_mouse
run_scn wheel scn_wheel
run_scn resize scn_resize
run_scn collapse scn_collapse

printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && { printf '\033[32mpanel-b3 全绿\033[0m\n'; exit 0; }
printf '\033[31mpanel-b3 有失败项（TEAM_B3_KEEP=1 保留现场）\033[0m\n'
exit 1
