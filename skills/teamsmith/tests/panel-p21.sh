#!/usr/bin/env bash
# panel-p21.sh — pty/tmux fixtures for the project-settings view (P22 / B2-B4).
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
ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || bad "$1（期望 [$3]，实际 [$2]）"; }
assert_has() { grep -qF -- "$2" "$1" 2>/dev/null && ok "$3" || bad "$3（$1 里找不到 [$2]）"; }
assert_not() { grep -qF -- "$2" "$1" 2>/dev/null && bad "$3（不该出现 [$2]）" || ok "$3"; }
assert_match() { grep -qE -- "$2" "$1" 2>/dev/null && ok "$3" || bad "$3（$1 里没有匹配 [$2]）"; }

if ! command -v tmux >/dev/null 2>&1; then printf 'panel-p21: tmux is required\n' >&2; exit 3; fi
if [ -z "$js" ]; then printf 'panel-p21: no node/bun runtime\n' >&2; exit 3; fi
[ -f "$panel" ] || { printf 'panel-p21: no bundle at %s\n' "$panel" >&2; exit 3; }

SECTIONS=("$@")
[ "${#SECTIONS[@]}" -gt 0 ] || SECTIONS=(settings write conflict seats readonly)
want() { local s; for s in "${SECTIONS[@]}"; do [ "$s" = "$1" ] && return 0; done; return 1; }

# ---------------------------------------------------------------- fixture plumbing
server_up() { # <name> [agents] → fresh project + private tmux session + argv-logging wrapper
  current="$1"
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
}

start_panel() {
  local cli="${P21_CLI:-$tmp/$current-wrapper.sh}"
  tmux -L "$sock" kill-window -t "$sess:panel" 2>/dev/null || true
  tmux -L "$sock" new-window -d -t "$sess" -n panel -c "$ROOT" \
    "TEAM_JS_BIN=$(printf '%q' "$js") exec '$js' '$panel' --root '$ROOT' --state-dir '$state' \
      --team-cli '$cli' --no-pulse --interval 3 ${*:-}"
  wait_panel
}

wait_panel() {
  local i
  for i in $(seq 1 60); do
    if tmux -L "$sock" capture-pane -p -t "$sess:panel" 2>/dev/null | grep -qF 'teamsmith pulse'; then
      sleep 0.5
      return 0
    fi
    sleep 0.25
  done
  printf 'panel-p21: the console pane never rendered (%s)\n' "$current" >&2
  tmux -L "$sock" capture-pane -p -t "$sess:panel" 2>/dev/null | tail -5 >&2
  return 1
}

cap() { tmux -L "$sock" capture-pane -p -t "$sess:panel" -S -400 2>/dev/null; }
cap_now() { tmux -L "$sock" capture-pane -p -t "$sess:panel" 2>/dev/null; }
# Wait (up to ~8s) for the setting editor's tray to appear (the fingerprint is read fresh, so the
# editor opens a beat after Enter/click).
wait_editor() { # <tray title>
  local i
  for i in $(seq 1 24); do
    cap | grep -qF "╭─ $1" && { sleep 0.4; return 0; }
    sleep 0.3
  done
  return 1
}

# Wait (up to ~8s) for the current frame to carry <text>; writes settle asynchronously.
wait_cap() { # <name> <text>
  local i
  for i in $(seq 1 20); do
    cap > "$tmp/$current/$1.txt"
    grep -qF -- "$2" "$tmp/$current/$1.txt" && return 0
    sleep 0.4
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
  local i
  for i in $(seq 1 30); do
    cap | grep -qF "$marker" && { sleep 0.4; return 0; }
    sleep 0.4
  done
  cap | tail -5 >&2
  bad "项目设置视图没有在 12s 内出现数据"
  return 1
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
  sleep 0.9
  _p21_filter="$1"
}
# Clear an applied filter: open the line and esc it (the spec's clear rule).
filter_clear() {
  keys /
  sleep 0.4
  keys Escape
  sleep 0.9
  _p21_filter=""
}

# Focus the row whose capture line matches <regex> and contains the cursor glyph.
focus_row() { # <grep -E pattern>
  local i
  for i in $(seq 1 40); do
    if cap | grep -E -- "$1" | grep -q '›'; then
      sleep 0.3
      return 0
    fi
    keys Down
    sleep 0.25
  done
  return 1
}

# Walk the picker's cursor to the option whose line contains <text> (grep -F) and press Enter.
pick_option() {
  local i
  for i in $(seq 1 12); do
    if cap | grep -F -- "$1" | grep -q '›'; then
      keys Enter
      sleep 1.3
      return 0
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
  sleep 1.2
  cap_to window
  assert_match "$tmp/$current/window.txt" '↑[0-9]+' "窗口顶部显示被隐藏的行数"
  # A click moves the focus to an unfocused row; the second click opens that row's editor. M49：行
  # 按**标签**认，原始键从第一次点击后的 CLI 提示行读（标签用来看，键用来敲）。
  local target_line label keyname
  target_line="$(cap | grep -n '· 立即生效' | grep -v '›' | grep -v '命令行：' | head -1 | cut -d: -f1)"
  if [ -n "$target_line" ]; then
    label="$(cap | sed -n "${target_line}p" | sed 's/^│//' | sed -E 's/^ +//' | sed -E 's/  +.*//')"
    click_at 20 "$target_line"
    sleep 0.9
    cap_to click
    assert_has "$tmp/$current/click.txt" "› $label" "第一次点击把光标放到那一行（按标签认行）"
    keyname="$(cap | grep -F 'team config set' | grep -oE 'TEAM_[A-Z0-9_]+' | head -1)"
    assert_has "$tmp/$current/click.txt" "team config set $keyname" "CLI 提示行跟着焦点换到该行的原始键"
    # The window may have scrolled with the focus: click the row the cursor is on now.
    target_line="$(cap | grep -n '› .*· 立即生效' | head -1 | cut -d: -f1)"
    [ -n "$target_line" ] && click_at 20 "$target_line"
    if wait_editor "$keyname"; then
      cap_to click2
      assert_has "$tmp/$current/click2.txt" "╭─ $keyname" "第二次点击打开该行的编辑器（标题点名原始键）"
    else
      cap_to click2
      bad "第二次点击没有打开该行的编辑器"
    fi
    if cap | grep -qF "╭─ $keyname"; then keys Escape; sleep 0.9; fi
  else
    cap | tail -5 >&2
    bad "窗口里没有找到可点击的 apply 行"
  fi
  # A refuse row opens no editor: the route is surfaced and the contract is untouched.
  local before; before="$(sha "$(cfg)")"
  filter_to TEAM_SESSION
  sleep 0.6
  focus_row '会话名 +.*只读' || bad "没能把焦点移到 refuse 行"
  keys Enter
  sleep 1.2
  cap_to refuse-route
  assert_has "$tmp/$current/refuse-route.txt" "手改" "refuse 行的回执点名路线"
  assert_eq "refuse 行没有写契约" "$(sha "$(cfg)")" "$before"
  keys Escape
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
  sleep 3
  # `q` keeps its global meaning: the collapse path runs (the argv log is the observable).
  local q0; q0="$(wc -l < "$(argv_log)" 2>/dev/null || echo 0)"
  keys q
  sleep 1.5
  assert_match "$(argv_log)" 'pulse collapse' "q 仍然触发全局的收起动作"
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
  wait_editor TEAM_PULSE_NUDGE_GAP || bad "写用例的编辑器没有打开"
  cap_has "TEAM_PULSE_NUDGE_GAP" editor
  keys BSpace BSpace BSpace
  sleep 0.3
  type_text "1200"
  sleep 0.4
  keys Enter
  sleep 2
  cap_to confirm
  assert_has "$tmp/$current/confirm.txt" "→ 1200" "第一次 Enter 只给确认行（没写）"
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
  wait_editor TEAM_PULSE_NUDGE_GAP || bad "取消用例的编辑器没有打开"
  type_text "x"
  sleep 0.4
  keys Escape
  sleep 0.9
  assert_eq "取消后契约不变" "$(sha "$(cfg)")" "$b0"
  assert_eq "取消后审计不增长" "$(audit_lines)" "$a0"
  assert_eq "取消后没有临时文件" "$(ls "$ROOT/.pi/team/"config.sh.tmp.* 2>/dev/null | wc -l)" "0"
  # Invalid: TEAM_PULSE_INTERVAL=0 → refusal names the range, sha unchanged, editor keeps the draft.
  filter_to TEAM_PULSE_INTERVAL
  sleep 0.5
  keys Enter
  wait_editor TEAM_PULSE_INTERVAL || bad "非法值用例的编辑器没有打开"
  keys BSpace BSpace BSpace BSpace
  sleep 0.3
  type_text "0"
  sleep 0.4
  local b1; b1="$(sha "$(cfg)")"
  keys Enter
  sleep 2
  cap_to invalid
  assert_has "$tmp/$current/invalid.txt" "不合法" "非法值的回执说明被拒"
  assert_match "$tmp/$current/invalid.txt" '最小 60' "回执点名接受域（最小 60）"
  assert_eq "非法值契约不变" "$(sha "$(cfg)")" "$b1"
  cap_has "TEAM_PULSE_INTERVAL" draft-kept
  keys Escape
  sleep 0.9
  # Danger: TEAM_MIN_FREE_SWAP_MB=0 needs one more Enter.
  filter_to TEAM_MIN_FREE_SWAP_MB
  sleep 0.5
  keys Enter
  wait_editor TEAM_MIN_FREE_SWAP_MB || bad "danger 用例的编辑器没有打开"
  keys BSpace BSpace BSpace BSpace
  sleep 0.3
  type_text "0"
  sleep 0.4
  local b2; b2="$(sha "$(cfg)")"
  keys Enter
  sleep 2
  cap_to danger
  assert_has "$tmp/$current/danger.txt" "危险：" "危险值先要一个额外确认"
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
  wait_editor TEAM_MONITOR_REFRESH || bad "restart 用例的编辑器没有打开"
  keys BSpace
  sleep 0.3
  type_text "7"
  sleep 0.4
  keys Enter
  sleep 1.5
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
  sleep 2.5
  cap_to conflict
  assert_has "$tmp/$current/conflict.txt" "指纹不符" "回执点名指纹冲突"
  assert_eq "对方的字节被保住" "$(sha "$(cfg)")" "$other"
  assert_match "$(audit_log)" 'result=conflict actor=panel key=TEAM_PULSE_NUDGE_GAP' "审计增了一行 conflict"
  # The view reloaded and shows the other writer's value (1200 was never written). M49：行上是标签，
  # 原始键在 CLI 提示行里（重读后仍与命令对齐）。
  sleep 1
  cap_to reloaded
  assert_match "$tmp/$current/reloaded.txt" "重复提醒间隔 +900" "视图重读后显示对方的 900"
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
  focus_row 'dev +xai/grok-4.6' || bad "没能把焦点移到 dev 席位行"
  keys Enter
  sleep 1.2
  cap_to picker
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
  sleep 2
  cap_to seat-confirm
  assert_has "$tmp/$current/seat-confirm.txt" "确认席位 dev" "确认行点名席位"
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
  sleep 0.5
  focus_row 'dev +xai/grok-4.6' || bad "移除前没能把焦点移到 dev 席位行"
  keys Enter
  sleep 1.3
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
  filter_to dev
  sleep 0.5
  focus_row 'dev +xai/grok-4.6' || bad "拒绝用例没能把焦点移到 dev 席位行"
  keys Enter
  sleep 1.3
  pick_option '自由输入' || bad "picker 里没有自由输入项"
  wait_editor dev || bad "自由输入用例的 seat 编辑器没有打开"
  type_text "deepseek-flash"
  sleep 0.3
  keys Enter
  sleep 2
  cap_to shapeless
  assert_has "$tmp/$current/shapeless.txt" "provider/model" "没有 provider 的模型被命令拒绝"
  keys Escape
  sleep 0.7
  assert_eq "被拒后契约 sha 不变" "$(sha "$(cfg)")" "$sha_b"
  # The running seat's window keeps its model; the next dispatch would use the new one.
  printf '# P22-x fixture brief\n' > "$ROOT/docs/team/tasks/P22-x.md"
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
  sleep 1.2
  type_text "changed"
  sleep 0.3
  keys Escape
  sleep 0.9
  keys Escape
  sleep 0.6
  keys Escape
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
