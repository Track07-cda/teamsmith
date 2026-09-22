#!/usr/bin/env bash
# panel-p21.sh — pty/tmux fixtures for the project-settings view (P22 / B2-B4).
# M59: every wait releases on a settled frame, every cleanup key is state-checked, and every
# failure carries its own scene — the mechanics live in tests/lib/pty-wait.sh (sourced below).
#
#   bash skills/teamsmith/tests/panel-p21.sh                  # every scenario
#   bash skills/teamsmith/tests/panel-p21.sh settings seats    # selected scenarios
#   TEAM_P21_KEEP=1 bash ...                                  # keep the fixture directory
#
# Every scenario runs in a private tmux server and a fresh git project initialised with the real
# `team init`; the panel runs the **real** CLI through a logging wrapper (`argv.log`), so "the
# console writes only through the owning command" is checked against real argv, not a stub.
# Exit: 0 every selected scenario green, 1 at least one assertion failed, 3 setup failure.
set -uo pipefail

# ── 身份隔离（必须最先做）：绝不继承调用者的团队身份 ──────────────────────────────
# （自己声明的旋钮先存下来：下面的清理会把 TEAM_* 全清掉）
_tree_arg="${TEAM_P21_TREE:-}"
_keep_arg="${TEAM_P21_KEEP:-0}"
# M59: TEAM_P21_TRACE=1 prints every wait/cleanup decision to stderr (fixture diagnostics, saved
# before the TEAM_* wipe below so the knob is honored when passed from outside).
_trace_arg="${TEAM_P21_TRACE:-}"
_js_arg="${TEAM_P21_JS:-}"
_js_panel="${TEAM_P21_PANEL:-}"
while IFS='=' read -r _v _; do
  case "$_v" in TEAM_*) unset "$_v" 2>/dev/null || true ;; esac
done < <(env)
unset _v 2>/dev/null || true

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tree="${_tree_arg:-$(cd -P "$here/../../.." && pwd)}"
skill="$tree/skills/teamsmith"
panel="${_js_panel:-$skill/scripts/panel/panel.js}"
js="${_js_arg:-$(command -v node || true)}"
[ -n "$js" ] || js="$(command -v bun || true)"
sock="p21-$$"
sess="p21-$$"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/panel-p21.XXXXXX")"
keep="${_keep_arg:-0}"
PASS=0
FAIL=0
ROOT=""
state=""
current=""

cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0
  tmux -L "$sock" kill-server 2>/dev/null || true
  rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$sock" 2>/dev/null || true
  if [ "$keep" = "1" ]; then printf '\n保留夹具目录：%s\n' "$tmp"
  else rm -rf "$tmp"; fi
}
trap cleanup EXIT

section() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }
ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); pty_fail_reset; }
# M59: a failure carries its own scene (pane tail + isolated-vs-cascade); pty_bad prints it.
bad() { pty_bad "$1"; FAIL=$((FAIL + 1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || bad "$1（期望 [$3]，实际 [$2]）"; }
assert_has() { grep -qF -- "$2" "$1" 2>/dev/null && ok "$3" || bad "$3（$1 里找不到 [$2]）"; }
assert_not() { grep -qF -- "$2" "$1" 2>/dev/null && bad "$3（不该出现 [$2]）" || ok "$3"; }
assert_match() { grep -qE -- "$2" "$1" 2>/dev/null && ok "$3" || bad "$3（$1 里没有匹配 [$2]）"; }

if ! command -v tmux >/dev/null 2>&1; then printf 'panel-p21: tmux is required\n' >&2; exit 3; fi
if [ -z "$js" ]; then printf 'panel-p21: no node/bun runtime\n' >&2; exit 3; fi
[ -f "$panel" ] || { printf 'panel-p21: no bundle at %s\n' "$panel" >&2; exit 3; }

# M59: the settled-frame waits, the state-checked cleanup keys and the failure scenes live in the
# shared helper (its --self-test injects the incident's mid-frame; smoke §38-c runs it).
# shellcheck source=lib/pty-wait.sh
. "$here/lib/pty-wait.sh"
# Fixture-wide knobs. PTY_WAIT_ITERS is a failure-detector horizon, never spent on a green run (a
# green wait returns on the first settled frame, usually rounds 1-3); per-wait overrides use local.
PTY_TRACE="${_trace_arg:-0}"
PTY_SCENE_DIR=""

SECTIONS=("$@")
[ "${#SECTIONS[@]}" -gt 0 ] || SECTIONS=(settings choices choices-schema write conflict seats readonly)
want() { local s; for s in "${SECTIONS[@]}"; do [ "$s" = "$1" ] && return 0; done; return 1; }

# ---------------------------------------------------------------- fixture plumbing
server_up() { # <name> [agents] → fresh project + private tmux session + argv-logging wrapper
  current="$1"
  PTY_SCENE_DIR="$tmp/$1"   # M59: a timed-out wait saves its two captures here for post-mortem
  local agents="${2:-dev verify}"
  ROOT="$tmp/$1/root"
  mkdir -p "$ROOT"
  ( cd "$ROOT" && git init -q -b main && git config user.email p21@teamsmith && git config user.name p21 \
      && printf '{"name":"%s","scripts":{"verify":"true"}}\n' "$1" > package.json \
      && git add -A && git commit -qm init ) >/dev/null 2>&1
  ( cd "$ROOT" && bash "$skill/scripts/team" init --session "$sess" --agents "$agents" --vcs local \
      --gates "true" --docs docs/team ) >"$tmp/$1-init.log" 2>&1 \
    || { printf 'panel-p21: team init failed (%s)\n' "$1" >&2; tail -3 "$tmp/$1-init.log" >&2; exit 3; }
  state="$ROOT/.pi/team/state"
  mkdir -p "$state" "$ROOT/docs/team"
  cat > "$tmp/$1-wrapper.sh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$tmp/$1-argv.log"
exec bash "$skill/scripts/team" "\$@"
EOF
  chmod +x "$tmp/$1-wrapper.sh"
  tmux -L "$sock" kill-server 2>/dev/null || true
  rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$sock" 2>/dev/null || true
  tmux -L "$sock" new-session -d -s "$sess" -x 160 -y 40 -n bootstrap -c "$ROOT" 'sleep 900'
  tmux -L "$sock" set -g window-size manual 2>/dev/null || true
  # A pane that dies keeps its last frame (capturable), and tmux writes its own "Pane is dead
  # (status N)" line into it: a fixture failure names a dead panel instead of comparing empty
  # captures. #{pane_dead_status} still answers for the one-line note below.
  tmux -L "$sock" set -g remain-on-exit on 2>/dev/null || true
}

start_panel() {
  local cli="${P21_CLI:-$tmp/$current-wrapper.sh}"
  local home_prefix=""
  # M55/R2：选择器用例把面板放在 scratch HOME 下 —— 机器目录里的 provider 不许成为选项。
  [ -n "${P21_HOME:-}" ] && home_prefix="HOME=$(printf '%q' "$P21_HOME") "
  tmux -L "$sock" kill-window -t "$sess:panel" 2>/dev/null || true
  tmux -L "$sock" new-window -d -t "$sess" -n panel -c "$ROOT" \
    "${home_prefix}TEAM_JS_BIN=$(printf '%q' "$js") exec '$js' '$panel' --root '$ROOT' --state-dir '$state' \
      --team-cli '$cli' --no-pulse --refresh ${P21_REFRESH:-3} ${*:-}"
  wait_panel
}

wait_panel() {
  # The panel's first frame must be settled too (the first paint also arrives line by line).
  local PTY_WAIT_ITERS=80 PTY_WAIT_PAUSE=0.25 PTY_SETTLE_PAUSE=0.3
  if pty_wait_frame - "面板首帧（$current）" 'teamsmith pulse'; then
    sleep 0.5
    return 0
  fi
  printf 'panel-p21: the console pane never rendered (%s)\n' "$current" >&2
  return 1
}

cap() { tmux -L "$sock" capture-pane -p -t "$sess:panel" -S -400 2>/dev/null; }
cap_now() { tmux -L "$sock" capture-pane -p -t "$sess:panel" 2>/dev/null; }
# The lib's sinks (M59): waits settle on the pty_cap stream; cleanup keys go through pty_keys.
pty_cap() { cap; }
pty_keys() { keys "$@"; }
pty_pane_state() { tmux -L "$sock" list-panes -t "$sess:panel" -F '#{pane_dead}:#{pane_dead_status}' 2>/dev/null | head -1; }

# Wait for the setting editor's tray. The optional body marker is what the caller is about to
# assert next: the tray title alone can be on screen while the body has not been painted (Ink
# paints line by line), so the frame must be settled — needles present + two consecutive captures
# identical (title clock masked) — before the wait releases (M59).
wait_editor() { # <tray title> [body marker]
  pty_wait_frame - "editor $1" "╭─ $1" "${2:-}"
}

# Wait for the current frame to carry <text>; writes settle asynchronously. The latest capture is
# written to the assertion's file every round, so a failure shows exactly what was on screen.
wait_cap() { # <name> <text>
  local PTY_WAIT_ITERS=30 PTY_WAIT_PAUSE=0.4
  pty_wait_frame "$tmp/$current/$1.txt" "回执 $1" "$2"
}

# Poll the wrapper's argv log (a file, not the pane — no frames involved) until it carries <text>.
wait_argv() { # <name> <text>
  local i
  for i in $(seq 1 30); do
    tail -n 50 "$(argv_log)" > "$tmp/$current/$1.txt" 2>/dev/null || true
    grep -qF -- "$2" "$tmp/$current/$1.txt" && return 0
    sleep 0.3
  done
  return 1
}
cap_to() { cap > "$tmp/$current/${1:-cap}.txt"; }
cap_has() { local f="$tmp/$current/${2:-cap}.txt"; cap >"$f"; assert_has "$f" "$1" "捕获里有 [$1]"; }
cap_not() { local f="$tmp/$current/${2:-cap}.txt"; cap >"$f"; assert_not "$f" "$1" "捕获里没有 [$1]"; }
cap_match() { local f="$tmp/$current/${2:-cap}.txt"; cap >"$f"; assert_match "$f" "$1" "$3"; }
keys() { tmux -L "$sock" send-keys -t "$sess:panel" "$@" 2>/dev/null; }
type_text() { tmux -L "$sock" send-keys -t "$sess:panel" -l "$1" 2>/dev/null; }
click_at() { tmux -L "$sock" send-keys -t "$sess:panel" -l "$(printf '\033[<0;%s;%sM' "$1" "$2")" 2>/dev/null; }
argv_log() { printf '%s/%s-argv.log' "$tmp" "$current"; }
# M65（直写 / 交互路径无读取）：wrapper 的 argv 日志按行切片 —— 一次交互 spawn 了哪些子进程。
argv_count() { wc -l < "$(argv_log)" 2>/dev/null || echo 0; }
argv_since() { # <start-lines> <file>：第 start 行之后的全部（start=0 就是从头）
  tail -n +$(( $1 + 1 )) "$(argv_log)" > "$2" 2>/dev/null || : > "$2"
}
# 读路径的两个子进程形态：`config list` / `__panel-data`（M65/D11 的判据）。
argv_reads() { grep -cE 'config list|__panel-data' "$1" 2>/dev/null || true; }
cfg() { printf '%s/.pi/team/config.sh' "$ROOT"; }
audit_log() { printf '%s/config.log' "$state"; }
audit_lines() { [ -f "$(audit_log)" ] && wc -l < "$(audit_log)" || echo 0; }
sha() { sha256sum "$1" 2>/dev/null | awk '{print $1}'; }
tree_hash() { ( cd "$ROOT" && find "$@" -type f 2>/dev/null | sort | while IFS= read -r f; do printf '%s ' "$f"; sha "$f"; done ) | sha256sum | awk '{print $1}'; }
conf_set() { mkdir -p "$state"; printf '%s\n' "$@" > "$state/panel.conf"; }
panel_pid() { tmux -L "$sock" list-panes -t "$sess:panel" -F '#{pane_pid}' 2>/dev/null | head -1; }

# Open the overlay and its project-settings navigation row (the sixth row), then wait for data.
# <marker> is the badge the wait looks for (zh by default; the en pass passes its own).
open_view() {
  local marker="${1:-立即生效}"
  keys ,
  sleep 0.7
  keys Down Down Down Down Down
  sleep 0.5
  keys Enter
  local PTY_WAIT_ITERS=40 PTY_WAIT_PAUSE=0.4
  if pty_wait_frame - "设置视图（marker=$marker）" "$marker"; then
    sleep 0.4
    return 0
  fi
  bad "项目设置视图没有在预算内出现数据（marker=$marker）"
  return 1
}

# Close the settings view and the overlay, then open the view again: entering the view is the view's
# own read (M65/D11 allows it — the interaction path is what must not read). A fixture that edits the
# contract by hand needs this to see its own bytes on screen.
reopen_view() {
  keys Escape
  sleep 0.5
  keys Escape
  sleep 0.5
  open_view
}

# Filter the view to <text> (the `/` line, then Enter applies). The editor opens holding the
# previous filter, so the seed is cleared first (Backspace per codepoint).
_p21_filter=""
filter_to() {
  keys /
  sleep 0.4
  # pi's `ctrl+u` kills to the line start: the seed (the previous filter) goes in one key.
  keys C-u
  sleep 0.3
  type_text "$1"
  sleep 0.4
  keys Enter
  # M59: conditional — the applied filter closes the compose tray. Wait for that settled absence
  # (both language titles) instead of a fixed sleep; the filtered rows repaint in the same commit.
  local PTY_WAIT_ITERS=8
  pty_wait_frame - "筛选已应用：$1" '!╭─ 筛选设置' '!╭─ Filter settings' || true
  _p21_filter="$1"
}
# Clear an applied filter: open the line and esc it (the spec's clear rule).
filter_clear() {
  keys /
  sleep 0.4
  # M59: the cancel esc is state-checked (zh or en filter tray must be on a settled frame).
  pty_key_when "清除筛选" '╭─ 筛选设置' Escape || pty_key_when "clear filter" '╭─ Filter settings' Escape || true
  local PTY_WAIT_ITERS=8
  pty_wait_frame - "筛选已清除" '!╭─ 筛选设置' '!╭─ Filter settings' || true
  _p21_filter=""
}

# Focus the row whose capture line matches <regex> and contains the cursor glyph.
# The row set can be asynchronously REPLACED by a contract-change re-read (M55's lesson) or dropped
# entirely while a block rebuild fails and re-tries on its TTL (the panel renders an empty list
# until the next good read — observed as a 40s blank after a seat write under load). M59: only
# press Down when the row is NOT on screen; when it is but the frame is still repainting, re-check
# instead of walking past it; Downs on an empty list are harmless no-ops, so the walk resumes
# cleanly when the rows come back.
focus_row() { # <grep -E pattern>
  local i c matched
  for i in $(seq 1 80); do
    c="$(cap)"
    matched="$({ printf '%s\n' "$c" | grep -E -- "$1" || true; })"
    if [ -n "$matched" ] && printf '%s\n' "$matched" | grep -q '›'; then
      if pty_frame_settled "$c"; then
        sleep 0.3
        return 0
      fi
      sleep 0.25   # the row is on screen but the frame is still moving — re-check, don't walk
    else
      keys Down
      sleep 0.25
    fi
  done
  return 1
}

# Wait for the choice picker (M55): its title carries the raw key after a ` · `, and the optional
# entry marker is what the caller asserts next. Both must be in one settled frame (M59): the title
# alone is not proof the picker is usable — Ink paints a frame line by line, so a capture can catch
# the title before the entry lines land (the PM's review run saw exactly that and cascaded).
wait_picker() { # <KEY> [entry marker]
  pty_wait_frame - "picker $1" " · $1" "${2:-}"
}
# The regression pin uses a short budget: a missing marker must fail fast, not burn the full one.
wait_picker_quick() {
  local PTY_WAIT_ITERS=6 PTY_WAIT_PAUSE=0.25 PTY_SETTLE_PAUSE=0.2
  wait_picker "$@"
}

# Cleanup escs are state-checked (M59): the widget's marker must be on a settled frame, and the
# esc is confirmed afterwards. A widget that is not there gets NO key — so one missed wait can no
# longer turn the next esc into "leave the settings view" (the §38-b cascade's first casualty).
# Returns 0 when the widget is gone afterwards (closed by this esc, or already gone — no key sent),
# 1 when an esc went out but the widget is still on screen.
leave_picker() { # <KEY>
  pty_cleanup_esc "picker $1" " · $1"
}

# Same rule for the write editor's cleanup sites (the tray title is the marker).
leave_editor() { # <tray title>
  pty_cleanup_esc "editor $1" "╭─ $1"
}

# Wait until the setting editor's tray is gone. The settings view's own frame also draws
# `╭─ 项目设置`, so the probe matches the tray title the setting editor uses (the raw key), not any
# box corner; the absence must be on a settled frame too (M59).
wait_no_editor() {
  pty_wait_frame - "editor closed" '!╭─ TEAM_'
}

# Walk the picker's cursor to the option whose line contains <text> (grep -F) and press Enter —
# releasing only once the option line with the cursor is on a settled frame (M59).
pick_option() {
  local i c
  for i in $(seq 1 12); do
    c="$(cap)"
    # M59: `{ … || true; } | grep -q` — same SIGPIPE-under-pipefail guard as focus_row.
    if { printf '%s\n' "$c" | grep -F -- "$1" || true; } | grep -q '›'; then
      if pty_frame_settled "$c"; then
        keys Enter
        sleep 1.3
        return 0
      fi
    fi
    keys Down
    sleep 0.3
  done
  return 1
}

# ---------------------------------------------------------------- scenarios

scn_settings() {
  section "settings · 标签/类徽章/默认值/过滤/窗口/点击/CLI 对齐/refuse 路由/q（B2 + M49）"
  server_up settings
  python3 - "$(cfg)" <<'PYFIX'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = re.sub(r'^TEAM_PULSE_NUDGE_GAP=.*$', 'TEAM_PULSE_NUDGE_GAP="900"  # 15min', s, count=1, flags=re.M)
# M49：文件里手加一个 schema 不认识的键（命令报 known=false）—— 它没有标签可用，行回退显示原始键。
s = s.rstrip('\n') + '\nTEAM_HAND_ADDED="hand"\n'
open(p, 'w', encoding='utf-8').write(s)
PYFIX
  start_panel
  local conf_before; conf_before="$(sha "$state/panel.conf" 2>/dev/null || echo none)"
  open_view
  assert_eq "导航行打开视图没有写 panel.conf" "$(sha "$state/panel.conf" 2>/dev/null || echo none)" "$conf_before"
  cap_to view
  # M49：行的主标识是人话标签（来自字符串表），裸键不作为行的文本出现。
  assert_match "$tmp/$current/view.txt" '模型并发上限 +.*立即生效' "apply 行显示人话标签 + 立即生效 徽章"
  assert_match "$tmp/$current/view.txt" '› 冲突默认取分支侧' "聚焦行的主文本是标签，不是裸键"
  assert_not "$tmp/$current/view.txt" "TEAM_MODEL_LIMITS" "行里不再出现裸键 TEAM_MODEL_LIMITS"
  assert_not "$tmp/$current/view.txt" "TEAM_GATES" "行里不再出现裸键 TEAM_GATES"
  assert_has "$tmp/$current/view.txt" "立即生效" "apply 组标题"
  cap_has "↑/↓ 行 · Enter 打开 · / 筛选" keyband
  # One filter per class: the badge, the unset marker and the line's own comment (all unchanged).
  filter_to TEAM_PULSE_INTERVAL
  cap_to restart
  assert_match "$tmp/$current/restart.txt" '巡检周期 +900 · 需重启' "restart 行的标签 + 需重启 徽章"
  assert_has "$tmp/$current/restart.txt" "命令行：team config set TEAM_PULSE_INTERVAL <新值>" "CLI 提示行点名原始键（照敲命令用）"
  filter_to TEAM_PROJECT
  cap_to refuse
  assert_match "$tmp/$current/refuse.txt" '项目名 +root · 只读' "refuse 行的标签 + 只读 徽章"
  assert_has "$tmp/$current/refuse.txt" "手改 .pi/team/config.sh 里的 TEAM_PROJECT" "refuse 提示行点名原始键与手改路线"
  filter_to TEAM_PANEL_DETAIL_CAP
  cap_to unset
  assert_match "$tmp/$current/unset.txt" '详情文件读取上限 +未设 · 默认 131072' "未设的键显示 schema 默认值 + unset 标记"
  filter_to TEAM_PULSE_NUDGE_GAP
  cap_to comment
  assert_match "$tmp/$current/comment.txt" '重复提醒间隔 +900 · 立即生效 +# 15min' "行内注释原样渲染"
  # M49 回退：schema 不认识的键没有标签 → 行的主文本就是原始键（未知键徽章 + 未知键提示）。
  filter_to TEAM_HAND_ADDED
  cap_to unknown
  assert_match "$tmp/$current/unknown.txt" 'TEAM_HAND_ADDED +hand · 未知键' "schema 不认识的键回退显示原始键"
  assert_has "$tmp/$current/unknown.txt" "未知键：TEAM_HAND_ADDED" "未知键的提示行说清楚为什么没有标签"
  # The filter matches the label (M49), key or value; esc clears it without closing the view.
  filter_to 巡检周期
  cap_to filter-label
  assert_has "$tmp/$current/filter-label.txt" "巡检周期" "按标签搜到该行"
  assert_not "$tmp/$current/filter-label.txt" "模型并发上限" "按标签过滤掉不匹配的行"
  filter_to pulse
  cap_to filter
  assert_has "$tmp/$current/filter.txt" "巡检周期" "按原始键 pulse 仍能找到（行上仍是标签）"
  assert_not "$tmp/$current/filter.txt" "模型并发上限" "过滤掉不匹配的行"
  filter_clear
  cap_to cleared
  assert_has "$tmp/$current/cleared.txt" "模型并发上限" "esc 清过滤后全部行回来"
  assert_has "$tmp/$current/cleared.txt" "项目设置" "esc 没有关掉视图"
  # The focus window moves with the keys and counts what it hides at the top.
  local i
  for i in $(seq 1 40); do keys Down; sleep 0.02; done
  if wait_cap window "↑"; then ok "窗口顶部出现被隐藏的行数计数行"; else bad "窗口滚动后没有出现 ↑N 计数行"; fi
  assert_match "$tmp/$current/window.txt" '↑[0-9]+' "窗口顶部显示被隐藏的行数"
  # A click moves the focus to an unfocused row; the second click opens that row's editor. M49：行
  # 按**标签**认，原始键从第一次点击后的 CLI 提示行读（标签用来看，键用来敲）。
  local target_line label keyname
  target_line="$(cap | grep -n '· 立即生效' | grep -v '›' | grep -v '命令行：' | head -1 | cut -d: -f1)"
  if [ -n "$target_line" ]; then
    label="$(cap | sed -n "${target_line}p" | sed 's/^│//' | sed -E 's/^ +//' | sed -E 's/  +.*//')"
    click_at 20 "$target_line"
    if wait_cap click "› $label"; then ok "第一次点击把光标放到那一行（按标签认行）"; else bad "第一次点击后光标没有落到那一行"; fi
    keyname="$(cap | grep -F 'team config set' | grep -oE 'TEAM_[A-Z0-9_]+' | head -1)"
    assert_has "$tmp/$current/click.txt" "team config set $keyname" "CLI 提示行跟着焦点换到该行的原始键"
    # The window may have scrolled with the focus: click the row the cursor is on now.
    target_line="$(cap | grep -n '› .*· 立即生效' | head -1 | cut -d: -f1)"
    [ -n "$target_line" ] && click_at 20 "$target_line"
    # M55：有选择集的键打开选择器（标题 `选择 … 的值 · KEY`），没有的仍是 compose 托盘。
    # M59: wait for THIS row's widget (tray or picker title) on a settled frame — the view can sit
    # settled *before* the editor paints (the row's data is re-read on open), so a settle-only
    # probe misjudges; the pre-M59 serial `wait_editor || wait_picker` burned two full budgets.
    local opened="" _probe_i c_probe
    for _probe_i in $(seq 1 24); do
      c_probe="$(cap)"
      if { printf '%s\n' "$c_probe" | grep -qF "╭─ $keyname" || printf '%s\n' "$c_probe" | grep -qF " · $keyname"; } \
         && pty_frame_settled "$c_probe"; then
        opened="$c_probe"; break
      fi
      sleep 0.3
    done
    [ -n "$opened" ] || opened="$c_probe"
    printf '%s\n' "$opened" > "$tmp/$current/click2.txt"
    if grep -qF "╭─ $keyname" "$tmp/$current/click2.txt"; then
      assert_has "$tmp/$current/click2.txt" "╭─ $keyname" "第二次点击打开该行的编辑器（compose 托盘，标题点名原始键）"
    elif grep -qF " · $keyname" "$tmp/$current/click2.txt"; then
      assert_has "$tmp/$current/click2.txt" " · $keyname" "第二次点击打开该行的编辑器（选择器，标题点名原始键）"
    else
      bad "第二次点击没有打开该行的编辑器"
    fi
    # M59: state-checked cleanup — whichever widget is on a settled frame gets the esc (at most one
    # sends; a widget that is not there gets no key, so the view can never be the esc's casualty).
    leave_editor "$keyname"
    leave_picker "$keyname"
  else
    cap | tail -5 >&2
    bad "窗口里没有找到可点击的 apply 行"
  fi
  # A refuse row opens no editor: the route is surfaced and the contract is untouched.
  local before; before="$(sha "$(cfg)")"
  filter_to TEAM_SESSION
  sleep 0.3
  if focus_row '会话名 +.*只读'; then
    keys Enter
  else
    bad "没能把焦点移到 refuse 行"
  fi
  if wait_cap refuse-route "手改"; then ok "refuse 行的回执点名路线"; else bad "refuse 行的回执没出现"; fi
  assert_eq "refuse 行没有写契约" "$(sha "$(cfg)")" "$before"
  # M59: the navigation esc is state-checked too — it fires only while the settings view is on a
  # settled frame, so a drifted scene gets a named red instead of a blind key.
  pty_key_when "esc 回浮层" '╭─ 项目设置' Escape || bad "esc 前设置视图已经不在屏幕上"
  sleep 1
  # The origin is remembered (esc back to the overlay's navigation row).
  cap_to overlay-back
  assert_has "$tmp/$current/overlay-back.txt" "项目设置" "esc 回到设置浮层"
  assert_match "$tmp/$current/overlay-back.txt" '› 项目设置' "回到浮层时仍选中那一行"
  # The current frame minus its last line (the status/receipt row, which may quote the key the user
  # just tried to edit): the overlay itself must list no contract key.
  cap_now | sed '$d' > "$tmp/$current/overlay-now.txt"
  assert_not "$tmp/$current/overlay-now.txt" "TEAM_" "当前这一帧的浮层没有契约的 TEAM_* 键"
  keys Enter
  pty_wait_frame - "q 用例的设置视图" '╭─ 项目设置' || bad "q 用例的设置视图没有打开"
  # `q` keeps its global meaning: the collapse path runs (the argv log is the observable).
  local q0; q0="$(wc -l < "$(argv_log)" 2>/dev/null || echo 0)"
  keys q
  if wait_argv q-collapse 'pulse collapse'; then ok "q 仍然触发全局的收起动作"; else bad "q 的收起动作没有进 argv 日志"; fi
  # The bundle carries no second key table (P22/B2): a scratch CLI whose schema gains TEAM_ZZZ_TEST
  # and whose TEAM_GATES class is refuse shows both through the same committed panel.js.
  local scratch="$tmp/$current/scratch"
  mkdir -p "$scratch/skills/teamsmith"
  cp -a "$skill/scripts" "$scratch/skills/teamsmith/scripts"
  cp -a "$skill/templates" "$skill/references" "$scratch/skills/teamsmith/"
  python3 - "$scratch/skills/teamsmith/scripts/lib/cmd-config.sh" <<'PYFIX'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = s.replace('TEAM_GATES|apply|cmd||plain||-|', 'TEAM_GATES|refuse|cmd||plain||-|改门禁请手改（scratch 夹具）')
s = s.replace('TEAM_DEFAULT_MODEL|restart|model|req|plain|deepseek/deepseek-flash|-|',
              'TEAM_ZZZ_TEST|apply|text||plain|zzz-default|-|\nTEAM_DEFAULT_MODEL|restart|model|req|plain|deepseek/deepseek-flash|-|')
open(p, 'w', encoding='utf-8').write(s)
PYFIX
  cat > "$tmp/$current-scratch-wrapper.sh" <<EOF2
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$tmp/$current-scratch-argv.log"
exec bash "$scratch/skills/teamsmith/scripts/team" "\$@"
EOF2
  chmod +x "$tmp/$current-scratch-wrapper.sh"
  P21_CLI="$tmp/$current-scratch-wrapper.sh" start_panel
  # The view opens on the overview: reach the overlay again (the panel was restarted).
  open_view
  filter_to TEAM_ZZZ_TEST
  sleep 0.5
  cap_to scratch-key
  assert_match "$tmp/$current/scratch-key.txt" 'TEAM_ZZZ_TEST +未设 · 默认 zzz-default' "scratch CLI 新增的键出现在视图里（不重建 panel.js；无标签→回退裸键）"
  filter_to TEAM_GATES
  sleep 0.5
  cap_to scratch-class
  assert_match "$tmp/$current/scratch-class.txt" '门禁命令 +true · 只读' "scratch CLI 改过的类跟着变（bundle 没有第二张键表）"
  assert_has "$tmp/$current/scratch-class.txt" "手改 .pi/team/config.sh 里的 TEAM_GATES" "scratch CLI 的拒统路线也点名原始键"
  # M49：另一种语言的人话标签（同一张表切换，标签不是渲染时的硬编码）。
  conf_set "lang=en" "page=1" "activity=1" "mouse=1" "density=comfortable" "theme=auto"
  start_panel
  open_view 'Takes effect now'
  filter_to TEAM_PULSE_INTERVAL
  cap_to en
  assert_match "$tmp/$current/en.txt" '› Patrol interval' "en 行的人话标签（行不是裸键）"
  assert_has "$tmp/$current/en.txt" "CLI: team config set TEAM_PULSE_INTERVAL <value>" "en 的 CLI 提示行同样点名原始键"
}

scn_choices() {
  section "choices · 选择器（M55 的选项 + M65 的直写：一次 accept = 校验+写入 / 交互路径零读取 / 危险值一次确认 / 只有自由输入进编辑器）"
  local agents="dev verify" i
  for i in $(seq 2 28); do agents="$agents dev$i"; done
  server_up choices "$agents"
  python3 - "$(cfg)" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
# 未设的 bool（默认 1）/ seconds（默认 300）/ 数值（默认 900）：删掉模板里的行，让前提真的成立。
s = re.sub(r'^TEAM_NOTIFY_TMUX=.*\n?', '', s, flags=re.M)
s = re.sub(r'^TEAM_DEFER_TTL=.*\n?', '', s, flags=re.M)
s = re.sub(r'^TEAM_PULSE_INTERVAL=.*\n?', '', s, flags=re.M)
# path exec,opt 指向一个不存在的文件：存在性标记要看得见。
s = re.sub(r'^TEAM_AGENT_BIN=.*$', 'TEAM_AGENT_BIN="/nonexistent/m55-agent"', s, count=1, flags=re.M)
# 危险值当「当前」选项：M65 的危险例外必须对来自选项的值同样生效（第一次 accept 只警告、不写）。
s = re.sub(r'^TEAM_MIN_FREE_SWAP_MB=.*$', 'TEAM_MIN_FREE_SWAP_MB="0"', s, count=1, flags=re.M)
open(p, 'w', encoding='utf-8').write(s)
PY
  # 席位模型：28 个记录 → known 变长，滚轮用例的条目列表会超出可视预算（不需要改 pane 几何）。
  mkdir -p "$state"
  for i in $(seq 2 28); do printf 'model=provider/m%s\n' "$i" > "$state/dev$i.env"; done
  conf_set "lang=zh" "page=1" "activity=1" "mouse=1" "density=comfortable" "theme=auto"
  # R2 的机器目录夹具：scratch HOME 里放一个含 sub2api（已下线的 provider）与 openrouter 的 Pi 模型
  # 目录 —— 读与选择器都不许出现它们（真实的 models-store.json 是活缓存，绝不能被当成选项来源）。
  local home="$tmp/$current-home"
  mkdir -p "$home/.pi/agent"
  cat > "$home/.pi/agent/models-store.json" <<'JSON'
{ "sub2api": { "models": { "gpt-5.6-luna": { "name": "gpt-5.6-luna", "baseUrl": "http://<internal>/v1" } } },
  "openrouter": { "models": { "anthropic/claude-x": { "name": "claude-x" } } } }
JSON
  # M65/D11：读取窗口的判据是「按键与帧之间没有读取」。后台节拍（activity 块 3s TTL）会无关地
  # spawn `__panel-data` —— 本段的面板跑在 P21_REFRESH=3600 下（`--refresh` 才是 panel 自己的刷新
  # 区间；`--interval` 是 `team monitor` 的旗标，panel 忽略它），窗口里出现的任何子进程都是这次
  # 交互因果产生的。
  P21_REFRESH=3600 P21_HOME="$home" start_panel
  open_view
  local gap0 acc0

  # ── (1) bool：两个带标签的条目；一次 accept = 校验 + 直写（无确认帧、无编辑器） ──
  filter_to TEAM_NOTIFY_TMUX
  sleep 0.5
  cap_to bool-row
  assert_match "$tmp/$current/bool-row.txt" '走 tmux 投递 +未设 · 默认 1' "未设的 bool 行显示 未设 · 默认 1"
  gap0="$(argv_count)"
  keys Enter
  wait_picker TEAM_NOTIFY_TMUX '› 保持未设' || bad "bool 的选择器没有打开"
  argv_since "$gap0" "$tmp/$current/gap-open.log"
  local gap_reads gap_total
  gap_reads="$(argv_reads "$tmp/$current/gap-open.log")"; [ -n "$gap_reads" ] || gap_reads=0
  gap_total="$(wc -l < "$tmp/$current/gap-open.log")"
  if [ "$gap_reads" = "0" ] && [ "$gap_total" = "0" ]; then
    ok "打开选择器：按键→帧之间零读取、零子进程（编辑器只用屏幕上的 settings 块）"
  else
    bad "打开选择器：按键→帧之间零读取、零子进程（读=$gap_reads 总=$gap_total）：$(head -3 "$tmp/$current/gap-open.log" 2>/dev/null | tr '\n' ';')"
  fi
  cap_to bool
  assert_match "$tmp/$current/bool.txt" '› 保持未设' "未设键的首个条目是保持未设（并且是焦点）"
  assert_has "$tmp/$current/bool.txt" "开（1） · 默认" "1 是默认条目，带表里的 on 词"
  assert_has "$tmp/$current/bool.txt" "关（0）" "0 是另一个条目，带表里的 off 词"
  assert_not "$tmp/$current/bool.txt" "…（自由输入）" "bool 是封闭域：没有自由输入项"
  local bool_sha bool_audit
  bool_sha="$(sha "$(cfg)")"; bool_audit="$(audit_lines)"
  acc0="$(argv_count)"
  pick_option '关（0）' || bad "bool 选择器里没有 关（0）"
  if wait_cap bool-written "已写入 TEAM_NOTIFY_TMUX = 0"; then ok "bool 选项在一次 accept 上写入（直写）"; else bad "bool 的直写回执没出现"; fi
  cap_to bool-written
  assert_not "$tmp/$current/bool-written.txt" "确认：" "直写没有确认帧"
  assert_not "$tmp/$current/bool-written.txt" "╭─ TEAM_NOTIFY_TMUX" "直写没有打开编辑器"
  assert_not "$tmp/$current/bool-written.txt" " · TEAM_NOTIFY_TMUX" "直写之后选择器已关闭"
  assert_match "$(cfg)" "^TEAM_NOTIFY_TMUX=.0.\$" "契约里落了规范值 0"
  assert_eq "直写让审计长一行" "$(audit_lines)" "$((bool_audit + 1))"
  argv_since "$acc0" "$tmp/$current/bool-argv.log"
  assert_eq "accept 的第 1 个子进程是 --dry-run（校验）" "$(sed -n '1p' "$tmp/$current/bool-argv.log" | grep -c -- '--dry-run')" "1"
  assert_eq "accept 的第 2 个子进程是 --yes 写入" "$(sed -n '2p' "$tmp/$current/bool-argv.log" | grep -c -- '--yes')" "1"
  assert_eq "accept 之前没有读子进程（第 1 行不是 config list/__panel-data）" "$(sed -n '1p' "$tmp/$current/bool-argv.log" | grep -cE 'config list|__panel-data' || true)" "0"
  local accept_tail
  accept_tail="$(tail -n +3 "$tmp/$current/bool-argv.log" 2>/dev/null | grep -v -- '__panel-data --block settings' || true)"
  if [ -z "$accept_tail" ]; then
    ok "accept 之后只剩 settings 块的 settle 重读（没有别的块、没有第二次写）"
  else
    bad "accept 之后还有别的子进程：$(printf '%s' "$accept_tail" | head -3 | tr '\n' ';')"
  fi
  filter_to TEAM_NOTIFY_TMUX
  sleep 0.5
  keys Enter
  wait_picker TEAM_NOTIFY_TMUX '关（0） · 当前' || bad "bool 选择器第二次没有打开"
  cap_to bool-set
  assert_has "$tmp/$current/bool-set.txt" "关（0） · 当前" "已设的 bool 把文件里的值标成当前"
  assert_has "$tmp/$current/bool-set.txt" "开（1） · 默认" "默认标记移到 1 上"
  assert_not "$tmp/$current/bool-set.txt" "保持未设" "已设的键没有保持未设条目"
  leave_picker TEAM_NOTIFY_TMUX
  # 非规范拼写（手改出来的 true）：当前条目原样显示，不许被贴成「关（0）」（命令写入时才 canonical 化）。
  python3 - "$(cfg)" <<'PY2'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = re.sub(r'^TEAM_NOTIFY_TMUX=.*$', 'TEAM_NOTIFY_TMUX=true', s, count=1, flags=re.M)
open(p, 'w', encoding='utf-8').write(s)
PY2
  # 手改之后要用视图自己的读取把它读进来（M65/D11：进入视图是视图自己的读取；交互路径没有读取）
  reopen_view
  filter_to TEAM_NOTIFY_TMUX
  sleep 0.5
  keys Enter
  wait_picker TEAM_NOTIFY_TMUX 'true · 当前' || bad "非规范 bool 的选择器没有打开"
  cap_to bool-spelling
  assert_has "$tmp/$current/bool-spelling.txt" "true · 当前" "非规范拼写的手改值原样显示成当前条目"
  assert_not "$tmp/$current/bool-spelling.txt" "关（0） · 当前" "非规范拼写不许被贴成规范值的标签"
  assert_has "$tmp/$current/bool-spelling.txt" "开（1） · 默认" "规范默认值仍在"
  leave_picker TEAM_NOTIFY_TMUX

  # ── (2) enum：只给 constraints 里的取值，原序；接受即写（直写，restart 回执说明时机） ──
  filter_to TEAM_MONITOR_UI
  sleep 0.5
  keys Enter
  wait_picker TEAM_MONITOR_UI 'auto · 默认' || bad "enum 的选择器没有打开"
  cap_to enum
  assert_match "$tmp/$current/enum.txt" '› 保持未设' "未设的 enum 也以保持未设开头"
  assert_has "$tmp/$current/enum.txt" "auto · 默认" "默认标记在 auto 上"
  assert_has "$tmp/$current/enum.txt" "tui" "enum 给出 constraints 里的 tui"
  assert_has "$tmp/$current/enum.txt" "text" "enum 给出 constraints 里的 text"
  assert_not "$tmp/$current/enum.txt" "…（自由输入）" "enum 是封闭域：没有自由输入项"
  local enum_sha enum_audit
  enum_sha="$(sha "$(cfg)")"; enum_audit="$(audit_lines)"
  pick_option 'tui' || bad "enum 选择器里没有 tui"
  if wait_cap enum-written "已写入 TEAM_MONITOR_UI = tui"; then ok "enum 选项在一次 accept 上写入（直写）"; else bad "enum 的直写回执没出现"; fi
  cap_to enum-written
  assert_has "$tmp/$current/enum-written.txt" "需要重启才生效" "restart 类的回执说明重启时机"
  assert_not "$tmp/$current/enum-written.txt" "确认：" "enum 直写没有确认帧"
  assert_not "$tmp/$current/enum-written.txt" "╭─ TEAM_MONITOR_UI" "enum 直写没有编辑器"
  assert_eq "enum 一次 accept 只审计一行" "$(audit_lines)" "$((enum_audit + 1))"
  assert_match "$(argv_log)" 'config set TEAM_MONITOR_UI tui --actor panel --dry-run --fingerprint [0-9a-f]{64}' "wrapper 记录了 --dry-run"
  assert_match "$(argv_log)" 'config set TEAM_MONITOR_UI tui --actor panel --yes --fingerprint [0-9a-f]{64}' "wrapper 记录了 --yes + 指纹"

  # ── (3) 未设键：编辑器开在「保持未设」上，接受 = 取消（不写、不留审计、不留临时文件）；再接受 300 = 直写 ──
  filter_to TEAM_DEFER_TTL
  sleep 0.5
  cap_to defer-row
  assert_match "$tmp/$current/defer-row.txt" '排队过期时间 +未设 · 默认 300' "未设键的行显示 未设 · 默认 300"
  local defer_sha defer_audit
  defer_sha="$(sha "$(cfg)")"; defer_audit="$(audit_lines)"
  keys Enter
  wait_picker TEAM_DEFER_TTL '› 保持未设' || bad "未设键的选择器没有打开"
  cap_to defer
  assert_match "$tmp/$current/defer.txt" '› 保持未设' "未设键的编辑器开在保持未设上"
  keys Enter
  # M59: conditional — 保持未设 accepts = the picker closes with no editor; wait for BOTH the tray
  # and the picker title to be absent on a settled frame, instead of a fixed sleep.
  pty_wait_frame "$tmp/$current/defer-cancel.txt" "保持未设接受（无编辑器无选择器）" '!╭─ TEAM_DEFER_TTL' '! · TEAM_DEFER_TTL' \
    || bad "保持未设没有干净地回到行列表"
  assert_not "$tmp/$current/defer-cancel.txt" "╭─ TEAM_DEFER_TTL" "保持未设不打开写编辑器"
  assert_not "$tmp/$current/defer-cancel.txt" " · TEAM_DEFER_TTL" "保持未设关掉了选择器（回到行列表）"
  assert_eq "保持未设后契约不变" "$(sha "$(cfg)")" "$defer_sha"
  assert_eq "保持未设后审计不增长" "$(audit_lines)" "$defer_audit"
  assert_eq "保持未设后没有临时文件" "$(ls "$ROOT/.pi/team/"config.sh.tmp.* 2>/dev/null | wc -l)" "0"
  # 再开一次：接受「300」这一项 → 一次 accept 直写（M65/D10；视图不说这是 unset）
  filter_to TEAM_DEFER_TTL
  sleep 0.5
  keys Enter
  wait_picker TEAM_DEFER_TTL '› 保持未设' || bad "未设键的选择器第二次没有打开"
  pick_option '300' || bad "未设键的选择器里没有 300 项"
  if wait_cap defer-written "已写入 TEAM_DEFER_TTL = 300"; then
    ok "未设键选默认值 = 一次 accept 直写（视图没有把这次写入说成 unset）"
  else
    bad "未设键选默认值的直写回执没出现"
  fi
  cap_to defer-written
  assert_not "$tmp/$current/defer-written.txt" "确认：" "未设键直写没有确认帧"
  assert_not "$tmp/$current/defer-written.txt" "╭─ TEAM_DEFER_TTL" "未设键直写没有编辑器"
  assert_match "$(cfg)" "^TEAM_DEFER_TTL=.300.\$" "契约里显式写上 300"
  assert_eq "未设键直写审计长一行" "$(audit_lines)" "$((defer_audit + 1))"

  # ── (4) 数值键：区间 + 建议值 + 自由输入（唯一进编辑器的路径）；非法值被拒且保留草稿；建议值直写 ──
  filter_to TEAM_PULSE_INTERVAL
  sleep 0.5
  keys Enter
  wait_picker TEAM_PULSE_INTERVAL '› 保持未设' || bad "数值键的选择器没有打开"
  cap_to numeric
  assert_has "$tmp/$current/numeric.txt" "接受区间 60–∞" "数值键显示命令给的接受区间（上界空 = 无界）"
  assert_match "$tmp/$current/numeric.txt" '› 保持未设' "未设的数值键也以保持未设开头"
  assert_has "$tmp/$current/numeric.txt" "900 · 默认" "建议值里的默认值带默认标记"
  assert_has "$tmp/$current/numeric.txt" "1800" "建议值原样给出"
  assert_has "$tmp/$current/numeric.txt" "…（自由输入）" "数值键有自由输入项"
  local num_sha num_audit
  num_sha="$(sha "$(cfg)")"; num_audit="$(audit_lines)"
  pick_option '自由输入' || bad "数值选择器里没有自由输入项"
  wait_editor TEAM_PULSE_INTERVAL || bad "数值自由输入没有打开写编辑器"
  keys C-u; sleep 0.3
  type_text "30"; sleep 0.4
  keys Enter
  if wait_cap numeric-invalid "最小 60"; then ok "越界的数值被命令拒绝并点名最小 60"; else bad "越界数值的拒绝没出现"; fi
  assert_eq "被拒后契约不变" "$(sha "$(cfg)")" "$num_sha"
  cap_has "TEAM_PULSE_INTERVAL" numeric-draft
  leave_editor TEAM_PULSE_INTERVAL
  # 4b）建议值也是值条目：一次 accept 直写，不进编辑器（M65/D10）
  filter_to TEAM_PULSE_INTERVAL
  sleep 0.5
  keys Enter
  wait_picker TEAM_PULSE_INTERVAL '› 保持未设' || bad "数值键的选择器第二次没有打开"
  pick_option '1800' || bad "数值选择器里没有 1800"
  if wait_cap num-written "已写入 TEAM_PULSE_INTERVAL = 1800"; then ok "建议值条目一次 accept 直写"; else bad "建议值条目的直写回执没出现"; fi
  cap_to num-written
  assert_not "$tmp/$current/num-written.txt" "确认：" "建议值直写没有确认帧"
  assert_not "$tmp/$current/num-written.txt" "╭─ TEAM_PULSE_INTERVAL" "建议值直写没有编辑器"
  assert_eq "建议值直写审计长一行" "$(audit_lines)" "$((num_audit + 1))"

  # ── (5) path：存在性标记 / 只有命令接受空值时才给清空项 / 清空也是直写 / 自由输入的确认行重复标记 ──
  filter_to TEAM_AGENT_BIN
  sleep 0.5
  keys Enter
  wait_picker TEAM_AGENT_BIN 'nonexistent/m55-agent' || bad "path 选择器没有打开"
  cap_to path
  assert_match "$tmp/$current/path.txt" '/nonexistent/m55-agent · 当前 · 不存在' "path 当前值带着缺失标记"
  assert_has "$tmp/$current/path.txt" "清空（写入空值）" "exec,opt 的 path 给出清空项"
  assert_has "$tmp/$current/path.txt" "…（自由输入）" "path 给出自由输入项"
  local path_audit
  path_audit="$(audit_lines)"
  pick_option '清空（写入空值）' || bad "path 选择器里没有清空项"
  if wait_cap path-cleared "已写入 TEAM_AGENT_BIN"; then ok "清空项也是一次 accept 直写"; else bad "清空项的直写回执没出现"; fi
  cap_to path-cleared
  assert_not "$tmp/$current/path-cleared.txt" "确认：" "清空直写没有确认帧"
  assert_not "$(cfg)" "/nonexistent/m55-agent" "清空把文件里的当前值写掉"
  assert_eq "清空直写审计长一行" "$(audit_lines)" "$((path_audit + 1))"
  filter_to TEAM_PI_BIN
  sleep 0.5
  keys Enter
  wait_picker TEAM_PI_BIN '· 当前' || bad "必填 path 的选择器没有打开"
  cap_to path-required
  assert_not "$tmp/$current/path-required.txt" "清空" "必填 path 不给清空项（命令不接受空值）"
  pick_option '自由输入' || bad "必填 path 没有自由输入项"
  wait_editor TEAM_PI_BIN || bad "必填 path 的自由输入没有打开写编辑器"
  keys C-u; sleep 0.3
  type_text "/nonexistent/m55-pi"; sleep 0.4
  keys Enter
  if wait_cap path-confirm "不存在"; then ok "确认行重复存在性标记（命令不拒写，视图也不谎称拒绝）"; else bad "确认行的存在性标记没出现"; fi
  leave_editor TEAM_PI_BIN
  wait_no_editor || bad "path 编辑器没有关干净"

  # ── (6) 没有选项集的 kind：打开自由输入并写明原因，不渲染条目列表 ──
  filter_to TEAM_GATES
  sleep 0.5
  gap0="$(argv_count)"
  keys Enter
  wait_editor TEAM_GATES "没有选项集" || bad "cmd 键没有打开自由输入"
  argv_since "$gap0" "$tmp/$current/gap-editor.log"
  local ed_reads
  ed_reads="$(argv_reads "$tmp/$current/gap-editor.log")"; [ -n "$ed_reads" ] || ed_reads=0
  assert_eq "打开自由输入：按键→帧之间零读取（现场：$(head -2 "$tmp/$current/gap-editor.log" 2>/dev/null | tr '\n' ';')）" "$ed_reads" "0"
  cap_to no-choice
  assert_has "$tmp/$current/no-choice.txt" "╭─ TEAM_GATES" "cmd 键直接打开自由输入"
  assert_has "$tmp/$current/no-choice.txt" "没有选项集" "编辑器上方写明原因（kind 没有选项集，写入仍由命令校验）"
  leave_editor TEAM_GATES
  wait_no_editor || bad "cmd 编辑器没有关干净"

  # ── (7) pairlist：Enter 把焦点移到席位块，绝不在这里组合（不读、不开编辑器） ──
  filter_to TEAM_AGENT_MODELS
  sleep 0.5
  keys Enter
  if wait_cap pairlist "席位块就是这一行的编辑器"; then ok "pairlist 行把焦点交给席位块"; else bad "pairlist 路由的说明行没出现"; fi
  cap_to pairlist
  assert_not "$tmp/$current/pairlist.txt" "╭─ TEAM_AGENT_MODELS" "pairlist 不开写编辑器"
  assert_not "$tmp/$current/pairlist.txt" " · TEAM_AGENT_MODELS" "pairlist 不开选择器"
  assert_match "$tmp/$current/pairlist.txt" '› dev +' "焦点移到席位块的第一行"
  assert_has "$tmp/$current/pairlist.txt" "team config set-agent-model" "命令行点名 set-agent-model（唯一写者）"

  # ── (8) 鼠标：第一次点击只移光标（不写）；第二次点击 = 接受并直写；esc 什么都不写 ──
  wait_no_editor || bad "点击用例开始前还有编辑器开着"
  filter_to TEAM_MONITOR_UI
  sleep 0.5
  keys Enter
  wait_picker TEAM_MONITOR_UI 'tui · 当前' || bad "点击用例的选择器没有打开"
  local click_sha click_audit target_line
  click_sha="$(sha "$(cfg)")"; click_audit="$(audit_lines)"
  target_line="$(cap | grep -n 'text' | grep -v '›' | head -1 | cut -d: -f1)"
  [ -n "$target_line" ] || bad "选择器里找不到可点击的 text 条目"
  [ -n "$target_line" ] && click_at 4 "$target_line"
  sleep 0.8
  cap_to click-move
  assert_match "$tmp/$current/click-move.txt" '› text' "第一次点击把光标移到该条目（D7 的规矩）"
  assert_eq "第一次点击不写契约" "$(sha "$(cfg)")" "$click_sha"
  assert_eq "第一次点击不增审计" "$(audit_lines)" "$click_audit"
  click_at 4 "$target_line"
  if wait_cap click-written "已写入 TEAM_MONITOR_UI = text"; then ok "第二次点击与 Enter 一样接受并直写"; else bad "第二次点击的直写回执没出现"; fi
  assert_eq "第二次点击审计长一行" "$(audit_lines)" "$((click_audit + 1))"
  assert_match "$(argv_log)" 'config set TEAM_MONITOR_UI text --actor panel --yes --fingerprint [0-9a-f]{64}' "第二次点击走了直写（--yes + 指纹）"
  # esc：打开选择器 → esc → 什么都不写
  filter_to TEAM_MONITOR_UI
  sleep 0.5
  local esc_audit esc0 esc_sha
  esc_audit="$(audit_lines)"; esc0="$(argv_count)"; esc_sha="$(sha "$(cfg)")"
  keys Enter
  wait_picker TEAM_MONITOR_UI 'text · 当前' || bad "esc 用例的选择器没有打开"
  # M59: the test-action esc is also state-checked — if the picker is not on a settled frame the
  # key is not sent and the miss is named, instead of the esc closing whatever is underneath.
  pty_key_when "esc 用例" " · TEAM_MONITOR_UI" Escape || bad "esc 用例：选择器不在稳定帧上，esc 没有发"
  sleep 0.9
  cap_to picker-esc
  assert_not "$tmp/$current/picker-esc.txt" " · TEAM_MONITOR_UI" "esc 关掉选择器"
  assert_has "$tmp/$current/picker-esc.txt" "team config set TEAM_MONITOR_UI" "回到行列表且焦点仍在原来那一行"
  assert_eq "esc 后契约不变" "$(sha "$(cfg)")" "$esc_sha"
  assert_eq "esc 后审计不增长" "$(audit_lines)" "$esc_audit"
  argv_since "$esc0" "$tmp/$current/esc-argv.log"
  assert_not "$tmp/$current/esc-argv.log" "config set" "esc 的窗口里没有 config set"
  assert_not "$tmp/$current/esc-argv.log" "set-agent-model" "esc 的窗口里没有席位写"
  # M59 判据②（真实场景）：此刻选择器已被上面那条 esc 关掉 —— 清理点的 esc 必须先确认状态。
  # 旧写法的裸 esc 在这里会把设置视图整个关掉，之后每段都在错的视图里跑（§38-b 的级联入口）。
  PTY_TRACE=1 pty_cleanup_esc "回归钉：已关闭的选择器" " · TEAM_MONITOR_UI" > "$tmp/$current/cleanup-trace.txt" 2>&1
  assert_has "$tmp/$current/cleanup-trace.txt" "action=none" "已关闭的选择器：清理守卫一个键都不发"
  assert_has "$tmp/$current/cleanup-trace.txt" "reason=not-settled" "  守卫的理由是「标记不在稳定帧上」，不是预算"
  cap_to cleanup-after
  assert_has "$tmp/$current/cleanup-after.txt" "╭─ 项目设置" "设置视图还开着（没有裸 esc 打到它身上）"
  # M59 判据①的 trace 面：一次正常等待的放行点在 trace 里可见（命中 + 稳定确认，轮数自适应）。
  keys Enter
  PTY_TRACE=1 wait_picker TEAM_MONITOR_UI 'text · 当前' > "$tmp/$current/wait-trace.txt" 2>&1 \
    || bad "trace 探针的选择器没有打开"
  assert_match "$tmp/$current/wait-trace.txt" 'wait picker TEAM_MONITOR_UI rounds=[0-9]+ settled=1' "正常等待放行在稳定帧上（trace 可见轮数）"
  leave_picker TEAM_MONITOR_UI || bad "trace 探针的选择器没有关掉"

  # ── (9) 滚轮：条目列表比可视预算长时滚得动（焦点走过的就是列表滚过的） ──
  wait_no_editor || bad "滚轮用例开始前还有编辑器开着"
  filter_to TEAM_DEFAULT_MODEL
  sleep 0.5
  keys Enter
  wait_picker TEAM_DEFAULT_MODEL '↓' || bad "长列表选择器没有打开"
  cap_to wheel-before
  local before_hidden
  before_hidden="$(grep -oE '↓[0-9]+' "$tmp/$current/wheel-before.txt" | head -1 | tr -d '↓' || true)"
  [ -n "$before_hidden" ] && ok "长列表在可视预算之外还有 $before_hidden 个条目（计数行）" \
    || bad "长列表没有被窗口截断（滚轮用例前提不成立）"
  assert_not "$tmp/$current/wheel-before.txt" "…（自由输入）" "滚动前看不到列表末尾的自由输入项"
  local w
  for w in $(seq 1 32); do
    tmux -L "$sock" send-keys -t "$sess:panel" -l "$(printf '\033[<65;20;20M')" 2>/dev/null || true
    sleep 0.1
  done
  # M59: conditional — wait for the wheel's repaint to settle AND the hidden count to drop.
  local after_hidden=""
  for w in $(seq 1 20); do
    cap_to wheel-after
    after_hidden="$(grep -oE '↓[0-9]+' "$tmp/$current/wheel-after.txt" | head -1 | tr -d '↓' || true)"
    { [ -n "$after_hidden" ] && [ "$after_hidden" -lt "$before_hidden" ]; } && break
    sleep 0.2
  done
  if [ -n "$before_hidden" ] && [ "${after_hidden:-0}" -lt "$before_hidden" ]; then
    ok "滚轮把可见窗口往下推了（↓$before_hidden → ↓${after_hidden:-0}）"
  else
    bad "滚轮没有推动可见窗口（↓$before_hidden → ↓${after_hidden:-0}）"
  fi
  assert_has "$tmp/$current/wheel-after.txt" "…（自由输入）" "滚轮一直滚到列表末尾（自由输入项可见）"
  assert_match "$tmp/$current/wheel-after.txt" "↑[0-9]+" "滚过之后列表上方也有被隐藏的条目"
  # R2 的入口断言：scratch HOME 的目录（sub2api / openrouter）不在选择器里，也不在读里。
  assert_not "$tmp/$current/wheel-before.txt" "sub2api" "选择器开屏不列机器目录里的 sub2api（词表只有项目数据）"
  assert_not "$tmp/$current/wheel-after.txt" "sub2api" "滚到底也不列机器目录里的 sub2api"
  assert_not "$tmp/$current/wheel-after.txt" "openrouter" "选择器不列机器目录里的 openrouter"
  ( cd "$ROOT" && HOME="$home" bash "$skill/scripts/team" config list --json ) > "$tmp/$current/read-json.json" 2>&1
  assert_not "$tmp/$current/read-json.json" "sub2api" "同一 scratch HOME 下的读也不含目录 provider"
  # 硬化自检（M55 第一次复验 FAIL 的回归钉 + M59 判据①/③）……
  if wait_picker_quick TEAM_DEFAULT_MODEL '这条目不存在-硬线自检'; then
    bad "wait_picker 只凭标题就放行了（条目标记/稳定帧没起作用）"
  else
    ok "wait_picker 要的条目不在稳定帧里时判负（标题命中不算，现场见上面的黄点场景）"
  fi
  # 清理守卫把 esc 只打在真开着的选择器上（这里选择器确实开着 → 恰好一个 esc）。
  leave_picker TEAM_DEFAULT_MODEL || bad "回归钉之后的选择器没有关掉"

  # ── (10) 危险值来自选项：第一次 accept 只给警告（不写、不审计），第二次才带 danger allowance 写入 ──
  filter_to TEAM_MIN_FREE_SWAP_MB
  sleep 0.5
  keys Enter
  wait_picker TEAM_MIN_FREE_SWAP_MB '0 · 当前' || bad "danger 用例的选择器没有打开"
  cap_to danger
  assert_has "$tmp/$current/danger.txt" "0 · 当前" "文件里的 0 在选项里就是「当前」（选项也可以是危险值）"
  local d_sha d_audit d0
  d_sha="$(sha "$(cfg)")"; d_audit="$(audit_lines)"; d0="$(argv_count)"
  pick_option '0 · 当前' || bad "danger 用例里没有 0 条目"
  if wait_cap danger-warn "危险："; then ok "选项里的危险值先要一次确认（第一次 accept 不写）"; else bad "危险值的警告没出现"; fi
  assert_eq "警告后契约不变" "$(sha "$(cfg)")" "$d_sha"
  assert_eq "警告后审计不增长" "$(audit_lines)" "$d_audit"
  cap_to danger-warn
  assert_has "$tmp/$current/danger-warn.txt" " · TEAM_MIN_FREE_SWAP_MB" "警告之后选择器还开着（第二次 accept 在同一处）"
  argv_since "$d0" "$tmp/$current/danger-argv.log"
  assert_not "$tmp/$current/danger-argv.log" "--yes" "警告这一次没有 --yes（什么都没写）"
  keys Enter
  if wait_cap danger-written "已写入 TEAM_MIN_FREE_SWAP_MB = 0"; then ok "第二次 accept 带 danger allowance 写入"; else bad "危险值的第二次 accept 没有落盘"; fi
  assert_match "$(argv_log)" 'config set TEAM_MIN_FREE_SWAP_MB 0 --actor panel --yes --fingerprint [0-9a-f]{64} --allow-danger' "写入带 --allow-danger（命令的 danger 例外）"
  assert_eq "危险值第二次 accept 审计长一行" "$(audit_lines)" "$((d_audit + 1))"
}

scn_choices_schema() {
  section "choices-schema · 新增 enum 键零代码出现 / 去掉 constraints 可见降级（M55 的核心卖点）"
  server_up choices-schema "dev verify"
  conf_set "lang=zh" "page=1" "activity=1" "mouse=1" "density=comfortable" "theme=auto"
  # scratch CLI：schema 里临时加一个 enum 键 TEAM_ZZZ_MODE —— bundle 就是提交的那份（不重建、不改一行 TS）。
  local scratch="$tmp/$current/scratch"
  mkdir -p "$scratch/skills/teamsmith"
  cp -a "$skill/scripts" "$scratch/skills/teamsmith/scripts"
  cp -a "$skill/templates" "$skill/references" "$scratch/skills/teamsmith/"
  python3 - "$scratch/skills/teamsmith/scripts/lib/cmd-config.sh" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = "TEAM_MEETING_ALLOW_USER_ID|"
new = "TEAM_ZZZ_MODE|apply|enum|red,blue|plain|red|scratch 夹具：验证 schema 新增 enum 键零改动出现\nTEAM_MEETING_ALLOW_USER_ID|"
assert old in s, "找不到 schema 尾部锚"
open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
PY
  cat > "$tmp/$current-scratch-wrapper.sh" <<EOF2
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$tmp/$current-scratch-argv.log"
exec bash "$scratch/skills/teamsmith/scripts/team" "\$@"
EOF2
  chmod +x "$tmp/$current-scratch-wrapper.sh"
  # 注意：`VAR=x func` 的赋值只活到函数返回 —— 本场景要起两次面板，所以先赋再调，末尾清掉。
  P21_CLI="$tmp/$current-scratch-wrapper.sh"
  start_panel
  open_view
  filter_to TEAM_ZZZ_MODE
  sleep 0.5
  cap_to zzz-row
  assert_has "$tmp/$current/zzz-row.txt" "TEAM_ZZZ_MODE" "scratch CLI 新增的 enum 键出现在视图里（无标签→回退裸键）"
  assert_has "$tmp/$current/zzz-row.txt" "未设 · 默认 red" "新键的默认值来自 schema"
  keys Enter
  wait_picker TEAM_ZZZ_MODE 'red · 默认' || bad "新增 enum 键的选择器没有打开（要重建 bundle = 反硬编码判据失败）"
  cap_to zzz-picker
  assert_match "$tmp/$current/zzz-picker.txt" '› 保持未设' "未设的新键也以保持未设开头"
  assert_has "$tmp/$current/zzz-picker.txt" "red · 默认" "constraints 里的 red 是默认条目"
  assert_has "$tmp/$current/zzz-picker.txt" "blue" "constraints 里的 blue 也在（原序，零代码改动）"
  assert_not "$tmp/$current/zzz-picker.txt" "自由输入" "enum 是封闭域：没有自由输入项"
  leave_picker TEAM_ZZZ_MODE
  # 去掉 constraints：同一个 bundle 必须可见地退回自由输入并写明原因（不是静默空白框）。
  python3 - "$scratch/skills/teamsmith/scripts/lib/cmd-config.sh" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = "TEAM_ZZZ_MODE|apply|enum|red,blue|plain|red|scratch 夹具：验证 schema 新增 enum 键零改动出现"
new = "TEAM_ZZZ_MODE|apply|enum||plain|red|scratch 夹具：验证 schema 新增 enum 键零改动出现"
assert old in s, "找不到刚加的 scratch 行"
open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
PY
  start_panel
  open_view
  filter_to TEAM_ZZZ_MODE
  sleep 0.5
  cap_to zzz-row2
  assert_has "$tmp/$current/zzz-row2.txt" "TEAM_ZZZ_MODE" "第二次起的面板仍用 scratch CLI（新键还在）"
  keys Enter
  wait_editor TEAM_ZZZ_MODE "没有选项集" || bad "去掉 constraints 后没有打开自由输入"
  cap_to zzz-noconstraints
  assert_has "$tmp/$current/zzz-noconstraints.txt" "╭─ TEAM_ZZZ_MODE" "enum 没有选项集时打开自由输入"
  assert_has "$tmp/$current/zzz-noconstraints.txt" "没有选项集" "降级是可见的并写明原因（kind 没有选项集）"
  leave_editor TEAM_ZZZ_MODE
  wait_no_editor || bad "降级用例的编辑器没有关干净"
  P21_CLI=""
}

scn_write() {
  section "write · 一行 diff / 注释保留 / 两次确认 / 取消 / 非法保留草稿 / danger 两步 / restart 不谎报（B3）"
  server_up write
  python3 - "$(cfg)" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = re.sub(r'^TEAM_PULSE_NUDGE_GAP=.*$', 'TEAM_PULSE_NUDGE_GAP="900"  # 15min', s, count=1, flags=re.M)
open(p, 'w', encoding='utf-8').write(s)
PY
  conf_set "lang=zh" "page=1" "activity=1" "mouse=1" "density=comfortable" "theme=auto"
  start_panel
  open_view
  cp "$(cfg)" "$tmp/$current/before.cfg"
  filter_to TEAM_PULSE_NUDGE_GAP
  sleep 0.5
  keys Enter
  # M55：数值键现在先开选择器（建议值 + 自由输入），写路径本身没变 —— 走进自由输入那一项。
  wait_picker TEAM_PULSE_NUDGE_GAP '· 当前' || bad "写用例的选择器没有打开"
  pick_option '自由输入' || bad "写用例的选择器里没有自由输入项"
  wait_editor TEAM_PULSE_NUDGE_GAP || bad "写用例的编辑器没有打开"
  cap_has "TEAM_PULSE_NUDGE_GAP" editor
  keys BSpace BSpace BSpace
  sleep 0.3
  type_text "1200"
  sleep 0.4
  keys Enter
  if wait_cap confirm "→ 1200"; then ok "第一次 Enter 只给确认行（没写）"; else bad "确认行没有出现（见 confirm.txt）"; fi
  assert_has "$tmp/$current/confirm.txt" "下一个读取它的进程生效" "确认行说明 apply 的时机"
  assert_eq "确认阶段契约未变" "$(sha "$(cfg)")" "$(sha "$tmp/$current/before.cfg")"
  keys Enter
  if wait_cap written "✓ 已写入 TEAM_PULSE_NUDGE_GAP = 1200"; then
    ok "第二次 Enter 的回执说已写入"
  else
    bad "第二次 Enter 的回执没有出现（见 written.txt）"
  fi
  assert_eq "只改了一行" "$(diff "$tmp/$current/before.cfg" "$(cfg)" | grep -c '^[<>]' || true)" "2"
  assert_eq "注释原样保留" "$(grep -c "^TEAM_PULSE_NUDGE_GAP='1200'  # 15min\$" "$(cfg)" || true)" "1"
  ( cd "$ROOT" && bash -n .pi/team/config.sh ) && ok "写入后 bash -n 通过" || bad "写入后 bash -n 失败"
  assert_match "$(argv_log)" 'config set TEAM_PULSE_NUDGE_GAP 1200 --actor panel --dry-run --fingerprint [0-9a-f]{64}' "wrapper 记录了 --dry-run 调用"
  assert_match "$(argv_log)" 'config set TEAM_PULSE_NUDGE_GAP 1200 --actor panel --yes --fingerprint [0-9a-f]{64}' "wrapper 记录了写入调用"
  # Cancel: esc writes nothing and audits nothing.
  local a0 b0
  a0="$(audit_lines)"
  b0="$(sha "$(cfg)")"
  filter_to TEAM_PULSE_NUDGE_GAP
  sleep 0.5
  keys Enter
  wait_picker TEAM_PULSE_NUDGE_GAP '· 当前' || bad "取消用例的选择器没有打开"
  pick_option '自由输入' || bad "取消用例的选择器里没有自由输入项"
  wait_editor TEAM_PULSE_NUDGE_GAP || bad "取消用例的编辑器没有打开"
  type_text "x"
  sleep 0.4
  leave_editor TEAM_PULSE_NUDGE_GAP || bad "取消用例的 esc 发了但编辑器还在"
  wait_no_editor || bad "取消用例的编辑器没有关干净"
  assert_eq "取消后契约不变" "$(sha "$(cfg)")" "$b0"
  assert_eq "取消后审计不增长" "$(audit_lines)" "$a0"
  assert_eq "取消后没有临时文件" "$(ls "$ROOT/.pi/team/"config.sh.tmp.* 2>/dev/null | wc -l)" "0"
  # Invalid: TEAM_PULSE_INTERVAL=0 → refusal names the range, sha unchanged, editor keeps the draft.
  filter_to TEAM_PULSE_INTERVAL
  sleep 0.5
  keys Enter
  wait_picker TEAM_PULSE_INTERVAL '· 当前' || bad "非法值用例的选择器没有打开"
  pick_option '自由输入' || bad "非法值用例的选择器里没有自由输入项"
  wait_editor TEAM_PULSE_INTERVAL || bad "非法值用例的编辑器没有打开"
  keys BSpace BSpace BSpace BSpace
  sleep 0.3
  type_text "0"
  sleep 0.4
  local b1; b1="$(sha "$(cfg)")"
  keys Enter
  if wait_cap invalid "最小 60"; then ok "越界数值的拒绝点名最小 60"; else bad "越界数值的拒绝没出现"; fi
  assert_has "$tmp/$current/invalid.txt" "不合法" "非法值的回执说明被拒"
  assert_eq "非法值契约不变" "$(sha "$(cfg)")" "$b1"
  cap_has "TEAM_PULSE_INTERVAL" draft-kept
  leave_editor TEAM_PULSE_INTERVAL || bad "非法值用例的 esc 发了但编辑器还在"
  wait_no_editor || bad "非法值用例的编辑器没有关干净"
  # Danger: TEAM_MIN_FREE_SWAP_MB=0 needs one more Enter.
  filter_to TEAM_MIN_FREE_SWAP_MB
  sleep 0.5
  keys Enter
  wait_picker TEAM_MIN_FREE_SWAP_MB '· 当前' || bad "danger 用例的选择器没有打开"
  pick_option '自由输入' || bad "danger 用例的选择器里没有自由输入项"
  wait_editor TEAM_MIN_FREE_SWAP_MB || bad "danger 用例的编辑器没有打开"
  keys BSpace BSpace BSpace BSpace
  sleep 0.3
  type_text "0"
  sleep 0.4
  local b2; b2="$(sha "$(cfg)")"
  keys Enter
  if wait_cap danger "危险："; then ok "危险值先要一个额外确认"; else bad "危险值的确认提示没出现"; fi
  assert_eq "危险确认前契约不变" "$(sha "$(cfg)")" "$b2"
  keys Enter
  if wait_cap danger-written "已写入 TEAM_MIN_FREE_SWAP_MB = 0"; then
    ok "第二次 Enter 写入危险值"
  else
    bad "危险值的第二次 Enter 没有落盘（见 danger-written.txt）"
  fi
  # Restart honesty: the running console keeps its argv while a fresh reader sees the new value.
  local pid_args_before
  pid_args_before="$(tr '\0' ' ' < "/proc/$(panel_pid)/cmdline" 2>/dev/null || true)"
  filter_to TEAM_MONITOR_REFRESH
  sleep 0.5
  keys Enter
  wait_picker TEAM_MONITOR_REFRESH '· 当前' || bad "restart 用例的选择器没有打开"
  pick_option '自由输入' || bad "restart 用例的选择器里没有自由输入项"
  wait_editor TEAM_MONITOR_REFRESH || bad "restart 用例的编辑器没有打开"
  keys BSpace
  sleep 0.3
  type_text "7"
  sleep 0.4
  keys Enter
  if wait_cap restart-confirm "→ 7"; then ok "restart 值先给确认行"; else bad "restart 的确认行没出现"; fi
  keys Enter
  if wait_cap restart "已写入 TEAM_MONITOR_REFRESH = 7"; then
    ok "restart 值已写入"
  else
    bad "restart 值没有写进去（见 restart.txt）"
  fi
  assert_eq "运行中的控制台仍拿着旧 argv" "$(tr '\0' ' ' < "/proc/$(panel_pid)/cmdline" 2>/dev/null || true)" "$pid_args_before"
  ( cd "$ROOT" && bash "$skill/scripts/team" monitor --json ) > "$tmp/$current/monitor.json" 2>/dev/null
  assert_has "$tmp/$current/monitor.json" '"refresh_s":7' "下一个读契约的进程看到 7（team monitor --json）"
}

scn_conflict() {
  section "conflict · 编辑器开着时另一个写者改文件：指纹拒绝、字节是对方的、视图重读、审计一行 conflict（B3）"
  server_up conflict
  python3 - "$(cfg)" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = re.sub(r'^TEAM_PULSE_NUDGE_GAP=.*$', 'TEAM_PULSE_NUDGE_GAP="900"  # 15min', s, count=1, flags=re.M)
open(p, 'w', encoding='utf-8').write(s)
PY
  start_panel
  open_view
  filter_to TEAM_PULSE_NUDGE_GAP
  sleep 0.5
  keys Enter
  wait_picker TEAM_PULSE_NUDGE_GAP '· 当前' || bad "冲突用例的选择器没有打开"
  pick_option '自由输入' || bad "冲突用例的选择器里没有自由输入项"
  wait_editor TEAM_PULSE_NUDGE_GAP || bad "冲突用例的编辑器没有打开"
  keys BSpace BSpace BSpace
  sleep 0.3
  type_text "1200"
  sleep 0.4
  # The other writer changes the contract (any byte counts) while the editor is open.
  printf '\n# other writer\n' >> "$(cfg)"
  local other; other="$(sha "$(cfg)")"
  keys Enter
  sleep 2
  keys Enter
  # M59: conditional — the conflict receipt must land on a settled frame (was: fixed 2.5s).
  if wait_cap conflict "指纹不符"; then ok "回执点名指纹冲突"; else bad "冲突的回执没出现"; fi
  assert_eq "对方的字节被保住" "$(sha "$(cfg)")" "$other"
  assert_match "$(audit_log)" 'result=conflict actor=panel key=TEAM_PULSE_NUDGE_GAP' "审计增了一行 conflict"
  # The view reloaded and shows the other writer's value (1200 was never written). M49：行上是标签，
  # 原始键在 CLI 提示行里（重读后仍与命令对齐）。M59: wait_cap 的字面针用「值 · 立即生效」，
  # 行标签与值之间的留白宽度交给后面的 assert_match（ERE）去验。
  if wait_cap reloaded "900 · 立即生效"; then ok "视图重读后显示对方的 900"; else bad "视图重读后没有显示对方的 900"; fi
  assert_match "$tmp/$current/reloaded.txt" '重复提醒间隔 +900' "视图重读后显示对方的 900（标签 + 值）"
  assert_not "$tmp/$current/reloaded.txt" "重复提醒间隔 +1200" "视图没有显示未写入的 1200"
  assert_has "$tmp/$current/reloaded.txt" "team config set TEAM_PULSE_NUDGE_GAP" "视图仍点名原始键（照敲命令用）"
}

scn_seats() {
  section "seats · 来源三态 / picker / 一 token diff / 移除回退 / 运行中的席位不变（B4）"
  server_up seats "dev verify dev2"
  python3 - "$(cfg)" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = s.replace('TEAM_AGENT_MODELS=""', 'TEAM_AGENT_MODELS="dev=deepseek/deepseek-flash"')
open(p, 'w', encoding='utf-8').write(s)
PY
  mkdir -p "$state"
  printf 'model=xai/grok-4.6\n' > "$state/dev.env"
  printf 'model=deepseek/deepseek-flash\n' > "$state/verify.env"
  printf 'model=kimi-coding/k3-256k\nmodel_src=explicit\n' > "$state/dev2.env"
  start_panel
  open_view
  filter_to verify
  sleep 0.5
  cap_to seats-verify
  assert_match "$tmp/$current/seats-verify.txt" 'verify +deepseek/deepseek-flash · 配置' "配置解析 → 配置"
  filter_to dev2
  sleep 0.5
  cap_to seats-dev2
  assert_match "$tmp/$current/seats-dev2.txt" 'dev2 +kimi-coding/k3-256k · 显式' "显式记录 → 显式"
  filter_to dev
  sleep 0.5
  cap_to seats
  assert_match "$tmp/$current/seats.txt" 'dev +xai/grok-4.6 · 历史记录' "记录与配置不一致 → 历史记录 + 记录的模型"
  ( cd "$ROOT" && bash "$skill/scripts/team" roster ) > "$tmp/$current/roster.txt" 2>/dev/null
  assert_match "$tmp/$current/roster.txt" 'xai/grok-4\.6·历史记录' "team roster 的标签与 models 块同口径"
  # Focus the dev seat row (its line carries the record's model) and open the picker.
  # M59: Enter only follows a successful walk (focus_row tolerates the row set being replaced).
  sleep 0.3
  if focus_row 'dev +xai/grok-4.6'; then
    keys Enter
  else
    bad "没能把焦点移到 dev 席位行"
  fi
  # M59: conditional — wait for the seat picker on a settled frame (title + a known entry).
  pty_wait_frame "$tmp/$current/picker.txt" "seat picker dev" "选择 dev 的模型" "kimi-coding/k3-256k" \
    || bad "seat picker 没有打开（标题或已知模型不在稳定帧上）"
  assert_match "$tmp/$current/picker.txt" '选择 dev 的模型' "picker 打开并点名席位"
  assert_has "$tmp/$current/picker.txt" "kimi-coding/k3-256k" "picker 列出命令报告的已知模型"
  assert_has "$tmp/$current/picker.txt" "-（移除覆盖，回退默认）" "picker 有移除项"
  assert_has "$tmp/$current/picker.txt" "自由输入" "picker 有自由输入项"
  # Choose a known model that differs from the seat's displayed one, then confirm through the editor.
  pick_option 'kimi-coding/k3-256k' || bad "picker 里没有 kimi-coding/k3-256k"
  wait_editor dev || bad "seat 编辑器没有打开"
  sleep 0.3
  local line_before; line_before="$(grep '^TEAM_AGENT_MODELS=' "$(cfg)")"
  keys Enter
  if wait_cap seat-confirm "确认席位 dev"; then ok "确认行点名席位"; else bad "确认行没有出现"; fi
  assert_has "$tmp/$current/seat-confirm.txt" "下次 dispatch/resume 生效" "确认行说明下次 spawn 生效"
  keys Enter
  if wait_cap seat-written "✓ 已写入席位 dev = "; then
    cap_to seat-written
    assert_match "$tmp/$current/seat-written.txt" '✓ 已写入席位 dev = .* · 下次 dispatch/resume 生效' "写入回执点名席位与规则"
  else
    bad "席位写入的回执没有出现（见 seat-written.txt）"
  fi
  assert_match "$(cfg)" '^TEAM_AGENT_MODELS=.*dev=.*' "契约里 dev 的 token 落盘"
  assert_eq "契约行只改了一行" "$(diff <(printf '%s\n' "$line_before") <(grep '^TEAM_AGENT_MODELS=' "$(cfg)") | grep -c '^[<>]' || true)" "2"
  assert_match "$(argv_log)" 'config set-agent-model dev .* --actor panel --dry-run --fingerprint [0-9a-f]{64}' "wrapper 记录了 set-agent-model 的 --dry-run"
  assert_match "$(argv_log)" 'config set-agent-model dev .* --actor panel --yes --fingerprint [0-9a-f]{64}' "wrapper 记录了 set-agent-model 的写入"
  assert_eq "席位记录 state/dev.env 未被碰" "$(cat "$state/dev.env")" "model=xai/grok-4.6"
  # Removal: the picker's `-` row falls back to TEAM_DEFAULT_MODEL.
  filter_to dev
  # M55/M59：刚写过的席位让视图异步重读合同（行集会被整批替换、甚至整段空缺等块重建）。
  # focus_row 自己容忍这个窗口；Enter 只跟在成功的走位后（盲发 Enter 实测打到 dev2 行）。
  sleep 0.3
  if focus_row 'dev +xai/grok-4.6'; then
    keys Enter
  else
    bad "移除前没能把焦点移到 dev 席位行"
  fi
  pty_wait_frame - "seat picker dev（移除用例）" "选择 dev 的模型" || bad "移除用例的 seat picker 没有打开"
  pick_option '-（移除覆盖' || bad "picker 里没有移除项"
  wait_editor dev || bad "移除用例的 seat 编辑器没有打开"
  keys Enter
  sleep 2
  keys Enter
  if wait_cap removed "已移除席位 dev 的覆盖"; then
    ok "移除回执说回到默认"
  else
    bad "移除回执没有出现（见 removed.txt）"
  fi
  assert_eq "dev 的 token 离开契约行" "$(grep '^TEAM_AGENT_MODELS=' "$(cfg)")" "TEAM_AGENT_MODELS=''"
  # A shapeless model is refused by the owning command (free-text row → deepseek-flash).
  local sha_b; sha_b="$(sha "$(cfg)")"
  # 刚写过的席位：视图会重读合同（行上的“覆盖”变成“回退默认”）。等它落定再走位，否则走位可能在
  # 一个正在被替换的行集上做过（实测：拿旧帧算出 40 步，新帧一到就冲过 dev 行）。
  wait_cap removed-fresh 'xai/grok-4.6 · 历史记录 · 回退默认' || bad "移除后视图没有重读合同"
  filter_to dev
  sleep 0.3
  if focus_row 'dev +xai/grok-4.6'; then
    keys Enter
  else
    bad "拒绝用例没能把焦点移到 dev 席位行"
  fi
  pty_wait_frame - "seat picker dev（拒绝用例）" "选择 dev 的模型" || bad "拒绝用例的 seat picker 没有打开"
  pick_option '自由输入' || bad "picker 里没有自由输入项"
  wait_editor dev || bad "自由输入用例的 seat 编辑器没有打开"
  type_text "deepseek-flash"
  sleep 0.3
  keys Enter
  if wait_cap shapeless "provider/model"; then ok "没有 provider 的模型被命令拒绝"; else bad "拒绝回执没有出现"; fi
  leave_editor dev || bad "拒绝用例的 esc 发了但 seat 编辑器还在"
  assert_eq "被拒后契约 sha 不变" "$(sha "$(cfg)")" "$sha_b"
  # The running seat's window keeps its model; the next dispatch would use the new one.
  local sha_b; sha_b="$(sha "$(cfg)")"
  # P24 起 dispatch 要求任务书声明锚（change: 或 anchor:）——夹具的 P22-x 也补上，否则
  # `dispatch --print` 在渲染启动命令前就被拒（与面板无关的夹具漂移）。
  cat > "$ROOT/docs/team/tasks/P22-x.md" <<'BRIEF'
# P22-x fixture brief

```
task:   P22-x
agent:  dev
issue:  -
change: -
specs:  -
phase:  apply
deps:   -
anchor: none (infra) — panel-p21 夹具：只为 dispatch --print 渲染启动命令
status: todo
budget: -
```

body
BRIEF
  tmux -L "$sock" new-window -d -t "$sess" -n dev -c "$ROOT" 'sleep 900'
  # A stub `pi` so `dispatch --print` can render the command it would run.
  printf '#!/bin/sh\nexit 0\n' > "$tmp/$current-pi.sh"; chmod +x "$tmp/$current-pi.sh"
  ( cd "$ROOT" && bash "$skill/scripts/team" config set TEAM_PI_BIN "$tmp/$current-pi.sh" --yes ) >/dev/null 2>&1
  sleep 0.5
  local win_before; win_before="$(tmux -L "$sock" list-panes -t "$sess:dev" -F '#{pane_start_command}' 2>/dev/null)"
  ( cd "$ROOT" && bash "$skill/scripts/team" config set-agent-model dev kimi-coding/k3-256k --yes ) >/dev/null 2>&1
  sleep 0.5
  assert_eq "运行中的 dev 窗口参数不变" "$(tmux -L "$sock" list-panes -t "$sess:dev" -F '#{pane_start_command}' 2>/dev/null)" "$win_before"
  ( cd "$ROOT" && bash "$skill/scripts/team" dispatch dev P22-x "$ROOT/docs/team/tasks/P22-x.md" --print ) > "$tmp/$current/dispatch.txt" 2>&1
  local wtcmd
  wtcmd="$(sed -n 's/^  先由 PM 建： //p' "$tmp/$current/dispatch.txt" | head -1)"
  [ -n "$wtcmd" ] && eval "$wtcmd" >/dev/null 2>&1
  ( cd "$ROOT" && bash "$skill/scripts/team" dispatch dev P22-x "$ROOT/docs/team/tasks/P22-x.md" --print ) > "$tmp/$current/dispatch.txt" 2>&1
  assert_has "$tmp/$current/dispatch.txt" "--model k3-256k" "下一次 dispatch --print 用新模型（--provider kimi-coding --model k3-256k）"
}

scn_readonly() {
  section "readonly · 契约与审计不动 / 只读导航与取消的编辑什么都不写（B5 的只读纪律）"
  server_up readonly
  start_panel
  local h_docs h_cfg a0
  h_docs="$(tree_hash docs)"
  h_cfg="$(sha "$(cfg)")"
  a0="$(audit_lines)"
  keys 2; sleep 0.5
  keys 4; sleep 0.5
  keys 3; sleep 0.5
  keys 1; sleep 0.5
  open_view
  filter_to TEAM_GATES
  sleep 0.5
  keys Enter
  wait_editor TEAM_GATES "没有选项集" || bad "readonly 用例的编辑器没有打开"
  type_text "changed"
  sleep 0.3
  # The three unwind escs are the test action, but each is still state-checked (M59): a drifted
  # scene gets a named red instead of a blind key closing whatever happens to be on screen.
  leave_editor TEAM_GATES || bad "readonly：编辑器 esc 后还在"
  pty_key_when "readonly 退回浮层" '╭─ 项目设置' Escape || bad "readonly：esc 前设置视图不在屏幕上"
  sleep 0.6
  pty_key_when "readonly 关闭浮层" '› 项目设置' Escape || bad "readonly：第二次 esc 前浮层不在屏幕上"
  sleep 0.6
  assert_eq "契约没被控制台碰过" "$(sha "$(cfg)")" "$h_cfg"
  assert_eq "审计没长" "$(audit_lines)" "$a0"
  assert_eq "docs 没被动" "$(tree_hash docs)" "$h_docs"
  if [ -d "$state/outbox" ]; then
    assert_eq "outbox 目录没有新增条目" "$(find "$state/outbox" -type f | wc -l)" "0"
  else
    ok "outbox 目录不存在（控制台没有创建它）"
  fi
  # The only `team` invocations the wrapper logged are reads (the block readers).
  assert_not "$(argv_log)" "config set" "wrapper 里没有 config set（这一轮没有写动作）"
}

# ---------------------------------------------------------------- run

printf '\033[1m== panel-p21 · 项目设置视图（P22） ==\033[0m\n'
for s in "${SECTIONS[@]}"; do
  mkdir -p "$tmp/$s"
  case "$s" in
    settings) scn_settings ;;
    choices) scn_choices ;;
    choices-schema) scn_choices_schema ;;
    write) scn_write ;;
    conflict) scn_conflict ;;
    seats) scn_seats ;;
    readonly) scn_readonly ;;
    *) printf 'panel-p21: 未知场景 %s\n' "$s" >&2; exit 3 ;;
  esac
done

printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0
exit 1
