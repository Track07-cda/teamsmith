#!/usr/bin/env bash
# panel-p21.sh — pty/tmux fixtures for the project-settings view (P22 / B2-B4).
# M59: every wait releases on a settled frame, every cleanup key is state-checked, and every
# failure carries its own scene — the mechanics live in tests/lib/pty-wait.sh (sourced below).
#
#   bash skills/teamsmith/tests/panel-p21.sh                  # every scenario
#   bash skills/teamsmith/tests/panel-p21.sh settings categories    # selected scenarios
#   bash skills/teamsmith/tests/panel-p21.sh settings groups wheel   # P30: grouping + the view's wheel
#   TEAM_P21_KEEP=1 bash ...                                  # keep the fixture directory
#
# Every scenario runs in a private tmux server and a fresh git project initialised with the real
# `team init`; the panel runs the **real** CLI through a logging wrapper (`argv.log`), so "the
# console writes only through the owning command" is checked against real argv, not a stub.
# Exit: 0 every selected scenario green, 1 at least one assertion failed, 3 setup failure.
#
# P316（用户裁定第二条：性能只能是参考指标，不能阻塞）：**没有负载前提、没有 SKIP 出口**。
# 等待上限只防死等；耗尽一律红并报「没等到 X」（含最后一次状态）。机器忙不再是「没结论」。
#
# P68 / fixture-waits-for-landed-reads — 数据态等待（requirement「A fixture observes a data-derived state
# before it asserts it」）：视图行、席位行、组标题这类**断言对象本身**从异步的 settings 读来，断言前必须
# 先等那一行出现在稳定帧上（`wait_row`，pty-wait.sh 的引擎）。骨架帧不算证据；固定 `sleep` + 单次采样也
# 不算。上界与实测延迟带（P52 §C 的注入表）：settings 读延迟 0s 绿 / 2s → 1 红 / 3s → 7 红 / 6s → 9 红，
# 自然读 <1s；`wait_row` 用 30 轮基础视界（轮询 0.4s + 稳定确认 0.25s ≈ 20s，静态场景不延长），6s 慢端
# 约有 3× 余量。上界是失败探测器，不是性能阈值（D33）：慢但落在界内的读必须绿。
#
# Fixture knobs (honoured **only** under `TEAM_SMOKE_FIXTURE=1`; otherwise printed as ignored and
# the real reading is used — the panel-cpu.sh precedent):
#                                        injects the "the state never arrives" stall, so the
#                                        exhaustion path is reachable on a quiet host
#   TEAM_P21_STALL_ROUNDS=<n>            inject the progress window (PTY_STALL_ROUNDS)
#   TEAM_P21_STALL=1                     inject a needle that never appears (the exhaustion shape
#                                        on a healthy machine: it must stay a red, not a skip)
#                                        and judge nothing, exit 0 (the gate's knob-integrity check)
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
# 诊断旋钮在身份清洗之前保存（清洗会把所有 TEAM_* 一起 unset）。
_trace_arg="${TEAM_P21_TRACE:-}"
# P318（D-3）：未绑定键扫描的红侧旋钮（把一个未绑定键换成会写盘的键）。照夹具旋钮的规矩：
# 只在 TEAM_SMOKE_FIXTURE=1 下生效，否则打印忽略行 —— 环境不能悄悄拆掉判据的方向。
_fixture_arg="${TEAM_SMOKE_FIXTURE:-0}"
_sweep_write_arg="${TEAM_P21_SWEEP_WRITE:-0}"
if [ "$_sweep_write_arg" = "1" ] && [ "$_fixture_arg" != "1" ]; then
  printf 'panel-p21: TEAM_P21_SWEEP_WRITE=1 被忽略（夹具旋钮只在 TEAM_SMOKE_FIXTURE=1 下生效）\n' >&2
fi
while IFS='=' read -r _v _; do
  case "$_v" in TEAM_*) unset "$_v" 2>/dev/null || true ;; esac
done < <(env)
unset _v 2>/dev/null || true

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$here/lib/tmp-root.sh"
# P162：破坏性调用（kill-server/kill-session/kill-window）动手前先证明私有 socket 生效
. "$here/lib/tmux-iso.sh"
tree="${_tree_arg:-$(cd -P "$here/../../.." && pwd)}"
skill="$tree/skills/teamsmith"
panel="${_js_panel:-$skill/scripts/panel/panel.js}"
js="${_js_arg:-$(command -v node || true)}"
[ -n "$js" ] || js="$(command -v bun || true)"
sock="p21-$$"
sess="p21-$$"
keep="${_keep_arg:-0}"
[ "$keep" = "1" ] && export TEAM_TMP_KEEP=1 TEAM_P21_KEEP=1
tmp="$(tmp_root_create panel-p21)" || exit 3
PASS=0
FAIL=0
ROOT=""
state=""
current=""

cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0
  # P162：收尾先证明私有 socket 生效（不成立就拒绝；cleanup 里不许 exit）
  tmux_iso_guard_soft "panel-p21" "收尾：私有 server" --tmpdir "${TMUX_TMPDIR:-}" --sock-name "$sock" \
    && tmux -L "$sock" kill-server 2>/dev/null || true
  rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$sock" 2>/dev/null || true
  if [ "$keep" = "1" ]; then printf '\n保留夹具目录：%s\n' "$tmp"
  else tmp_root_reap_all; fi
}
trap cleanup EXIT

section() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }
# P48: 每个场景在自己的子 shell 里跑，计数落在文件上（断言数不随场景结束丢失）。
_p21_count="$tmp/count"
mkdir -p "$_p21_count"
p21_count_of() { local f="$1"; if [ -f "$f" ]; then wc -l < "$f" | tr -d ' '; else printf '0'; fi; }
ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; printf 'ok\n' >> "$_p21_count/ok"; pty_fail_reset; }
# M59: a failure carries its own scene (pane tail + isolated-vs-cascade); pty_bad prints it.
bad() { pty_bad "$1"; printf 'bad\n' >> "$_p21_count/bad"; }
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
# shellcheck source=lib/model-policy.sh
. "$here/lib/model-policy.sh"   # P232：完整派单记录构造器（S1 的共享夹具）
# 等待视界只防死等：默认由 tests/lib/pty-wait.sh 给（基础 100 轮、仍在绘制时最多 5 倍）。
PTY_TRACE="${_trace_arg:-0}"
PTY_SCENE_DIR=""

SECTIONS=("$@")
[ "${#SECTIONS[@]}" -gt 0 ] || SECTIONS=(settings groups wheel choices choices-schema write conflict categories policy readonly)
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
      --gates "true" --docs docs/team --task-models 'routine=deepseek/deepseek-flash analysis=xai/grok-4.6 verify=kimi-coding/k3-256k' --pm-model 'deepseek/deepseek-flash' ) >"$tmp/$1-init.log" 2>&1 \
    || { printf 'panel-p21: team init failed (%s)\n' "$1" >&2; tail -3 "$tmp/$1-init.log" >&2; exit 3; }
  state="$ROOT/.pi/team/state"
  mkdir -p "$state" "$ROOT/docs/team"
  cat > "$tmp/$1-wrapper.sh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$tmp/$1-argv.log"
exec bash "$skill/scripts/team" "\$@"
EOF
  chmod +x "$tmp/$1-wrapper.sh"
  # P162：重起私有 server 前的 kill-server 也要先证明隔离生效（不成立 → 硬停）
  tmux_iso_require "panel-p21" "重起私有 server 前的 kill-server" --tmpdir "${TMUX_TMPDIR:-}" --sock-name "$sock"
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
  local PTY_WAIT_PAUSE=0.25 PTY_SETTLE_PAUSE=0.3
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
  pty_wait_frame - "editor $1" "╭─ $(key_label "$1")" "${2:-}"
}

# Wait for the current frame to carry <text>; writes settle asynchronously. The latest capture is
# written to the assertion's file every round, so a failure shows exactly what was on screen.
wait_cap() { # <name> <text>
  local PTY_WAIT_PAUSE=0.4
  pty_wait_frame "$tmp/$current/$1.txt" "回执 $1" "$2"
}
# P68/fixture-waits-for-landed-reads：数据态等待。断言一行**从异步 settings 读来的数据**之前，先等
# 那一行自己（值也在）出现在稳定帧上；骨架帧、固定 sleep + 单次采样都不算证据。上界 30 轮基础视界
# （≈20s，静态场景不延长）与它的实测延迟带见文件头；耗尽时 pty-wait.sh 打一行归因（等待名 + 缺的
# 标记 + 轮数）。捕获仍写到 $tmp/$current/<name>.txt 供断言复用。
wait_row() { # <name> <label> <needle...>
  local _name="$1" _label="$2"; shift 2
  local PTY_WAIT_PAUSE=0.4
  pty_wait_frame "$tmp/$current/$_name.txt" "数据态：$_label" "$@"
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
# ── P318（D-3）：未绑定键扫描（从 tests/panel-b2.sh 的 `readonly` 场景搬来，原场景已删）──────────
# 那一份**没有任何门禁或 CI 执行它**；这一份跟着 §38 段跑。判据：控制台只允许写**自己的**文件 ——
# 扫过一遍未绑定键与导航键之后，state / docs / 契约里其余内容必须逐字节不变。允许集逐条从代码列：
#   ① state/draft.md         写信草稿（2.2 / 2.7 的结算面）
#   ② state/panel.conf       设置视图写下的契约覆盖
#   ③ state/panel-page       当前页（导航键的结果）
#   ④ state/panel.log        控制台自己的运行日志：scripts/panel/src/main.tsx:229 的 appendFileSync
#   ⑤ state/tmux-calls.log   它 spawn 的每个 `team` 调用的 tmux 闸门记录：scripts/lib/common.sh:3489
#                            把 TEAM_TMUX_CALLS_LOG 钉成 $TEAM_STATE_DIR/tmux-calls.log
#   ⑥ state/signal-calls.log 同一族的信号闸门记录（窗口里被 gated 的工具）
# 除这六个之外**任何**写入都算「只读面被破了」（红侧 TEAM_P21_SWEEP_WRITE：s 键写出 state/standby
# 与 watchdog.log 两处，必须红）。
sweep_manifest() { # → 一行一文件「<相对路径> <sha256>」（红的时候直接点名是谁被改了）
  ( cd "$ROOT" && find .pi/team/state docs/team .pi/team/config.sh -type f 2>/dev/null \
      | grep -vF -e '.pi/team/state/draft.md' -e '.pi/team/state/panel.conf' -e '.pi/team/state/panel-page' \
                 -e '.pi/team/state/panel.log' -e '.pi/team/state/tmux-calls.log' -e '.pi/team/state/signal-calls.log' \
      | sort | while IFS= read -r f; do printf '%s %s\n' "$f" "$(sha "$f")"; done )
}
# 键表：panel-b2 原表的未绑定键 + 只允许动「控制台自己的文件」的导航/刷新键。
# 红侧（TEAM_SMOKE_FIXTURE=1 TEAM_P21_SWEEP_WRITE=1）：把一次未绑定键换成**会写盘的键**
# （s → 一行理由 → Enter → 写 state/standby）→ 同一条断言必须变红。
sweep_keys() {
  local k
  for k in x z '?' '!' '~' 'w' '%' '&'; do type_text "$k"; done
  keys r; keys Tab; keys Up; keys Down
  if [ "$_fixture_arg" = "1" ] && [ "$_sweep_write_arg" = "1" ]; then
    keys s; sleep 0.5; type_text 'sweep write'; sleep 0.3; keys Enter
  fi
}
conf_set() { mkdir -p "$state"; printf '%s\n' "$@" > "$state/panel.conf"; }
# P232：把 fixture 契约换成新的类别策略 + 独立 PM（走真实事务入口 upgrade-models）——退休键真的
# 离开文件，视图才在「当前契约」这一档上跑；老契约的档由 scn_categories 的 legacy 段专门覆盖。
policy_new() { # <task-models> <pm-model>
  ( cd "$ROOT" && bash "$skill/scripts/team" config upgrade-models --task-models "$1" --pm-model "$2" --yes ) \
    > "$tmp/$current-upgrade.log" 2>&1
}
# 一份**完整**的已提交派单记录（tests/lib/model-policy.sh 的共享构造器；S1 的读面契约）。
record_fixture() { # <seat> <model> <sid> <task> <category>
  mkdir -p "$state"
  routing_fixture_record "$state" "$1" "$4" "$ROOT" "$ROOT/docs/team/tasks/$4-x.md" "$2" "$3" policy 2026-10-09T00:00:00Z "$5"
}
panel_pid() { tmux -L "$sock" list-panes -t "$sess:panel" -F '#{pane_pid}' 2>/dev/null | head -1; }

# Open the overlay and its project-settings navigation row (the sixth row), then wait for data.
# <marker> is the string the wait looks for: P30/D2 made the view open on the read-only skeleton,
# so the default is the first functional group heading (identity) — a class word is no longer a
# heading and, at the top of the list, would only appear on some badge (zh by default; the en pass
# passes its own marker).
open_view() {
  local marker="${1:-模型}"
  keys ,
  sleep 0.7
  keys Down Down Down Down Down
  sleep 0.5
  keys Enter
  local PTY_WAIT_PAUSE=0.4
  if pty_wait_frame - "设置视图（marker=$marker）" "$marker"; then
    sleep 0.4
    return 0
  fi
  bad "项目设置视图没等到（超过等待上限）数据（marker=$marker）"
  return 1
}

# Close the settings view and the overlay, then open the view again: entering the view is the view's
# own read (M65/D11 allows it — the interaction path is what must not read). A fixture that edits the
# contract by hand needs this to see its own bytes on screen.
reopen_view() {
  filter_clear
  if cap_now | grep -qE '╭─ (项目命令|模型记录)'; then
    keys Escape
    pty_wait_frame - "重开前返回主设置" '╭─ 项目设置' || bad "重开前未回到主设置"
    filter_clear
  fi
  pty_key_when "重开前退出主设置" '╭─ 项目设置' Escape || bad "重开前主设置不在屏幕上"
  pty_key_when "重开前关闭浮层" '› 项目设置' Escape || bad "重开前浮层不在屏幕上"
  pty_wait_frame - "重开前浮层已关闭" 'teamsmith pulse' '!› 项目设置' || bad "重开前浮层未关闭"
  open_view
}

open_secondary() { # commands|records
  filter_clear
  local label="项目命令"
  [ "$1" = records ] && label="模型记录"
  filter_to "$label"
  pty_key_when "进入 $label" "› $label" Enter || { bad "未聚焦 $label"; return 1; }
  pty_wait_frame - "打开 $label" "╭─ $label" || { bad "没有打开 $label"; return 1; }
  _p21_filter=""
}

# Labelled widgets, not raw implementation keys.
key_label() {
  case "$1" in
    TEAM_PM_MODEL) printf 'PM模型' ;;
    TEAM_MODEL_LIMITS) printf '模型同时运行任务数' ;;
    TEAM_PULSE_INTERVAL) printf '检查间隔' ;;
    TEAM_PULSE_MAX_RESTARTS) printf 'PM每小时自动恢复次数' ;;
    TEAM_UPDATE_CHECK) printf '启动时检查新版本' ;;
    TEAM_GATES) printf '验收命令' ;;
    TEAM_INSTALL_CMD) printf '安装命令' ;;
    TEAM_REVIEW_TIMEOUT) printf '验收最长时间' ;;
    *) printf '%s' "$1" ;;
  esac
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

# Wait for the choice picker (M55): its title carries the operation label, and the optional
# entry marker is what the caller asserts next. Both must be in one settled frame (M59): the title
# alone is not proof the picker is usable — Ink paints a frame line by line, so a capture can catch
# the title before the entry lines land (the PM's review run saw exactly that and cascaded).
wait_picker() { # <KEY> [entry marker]
  pty_wait_frame - "picker $1" "╭─ $(key_label "$1")" "${2:-}"
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
  pty_cleanup_esc "picker $1" "╭─ $(key_label "$1")"
}

# P30/D2: the grouping is a functional domain, the effect class lives in the row's badge. A line
# that carries nothing but a class word can only come from a class-group heading — this is the pin
# that the view did not go back to grouping by class (both languages' six words).
assert_no_class_heading() { # <capture file> [label]
  local f="$1" label="${2:-视图没有类分组标题（分组是功能域）}"
  # M59/P127: `{ … || true; } | grep -q` — the capture file can outgrow the pipe buffer; grep -q
  # exits on the first hit and sed would take SIGPIPE (rc=141 → a class heading falsely "absent").
  if { sed 's/[│|]//g' "$f" || true; } | grep -qE '^ *(立即生效|需重启|不可改|apply|restart|change in file) *$'; then
    bad "$label（捕获里出现了只有类词的行）"
  else
    ok "$label"
  fi
}

# Inject one SGR wheel notch into the pane (the same path as `click_at`: tmux writes the bytes to
# the pane's pty, where Ink parses them). 65 = wheel down, 64 = wheel up.
wheel_at() { # <down|up> <col> <row> [n]
  local btn=65 i
  [ "$1" = "up" ] && btn=64
  for i in $(seq 1 "${4:-1}"); do
    tmux -L "$sock" send-keys -t "$sess:panel" -l "$(printf '\033[<%s;%s;%sM' "$btn" "$2" "$3")" 2>/dev/null || true
    sleep 0.15
  done
}

# Same rule for the write editor's cleanup sites (the tray title is the marker).
leave_editor() { # <tray title>
  pty_cleanup_esc "editor $1" "╭─ $(key_label "$1")"
}

# Wait until the setting editor's tray is gone. The settings view's own frame also draws
# `╭─ 项目设置`, so the probe matches the tray title the setting editor uses (the raw key), not any
# box corner; the absence must be on a settled frame too (M59).
wait_no_editor() {
  pty_wait_frame - "editor closed" '!Enter 继续' '!Enter 保存 · Esc 取消'
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
  section "settings · 精选操作/入口返回/过滤/错误/短长列表/填高/点击/q"
  server_up settings
  policy_new 'routine=example/one analysis=example/two verify=example/three' 'example/pm' || bad "策略准备失败"
  start_panel
  local pref_before height stats r u d gap
  pref_before="$(sha "$state/panel.conf")"
  height="$(tmux -L "$sock" display-message -p -t "$sess:panel" '#{pane_height}')"
  open_view || return 1
  stats="$(wait_settings_frame "$height" default-count '项目设置' routine)" || { bad "未读到完整的默认设置帧"; return 1; }
  read -r r u d gap <<<"$stats"
  local default_frame="$tmp/$current/default-count.txt"
  assert_match "$default_frame" '› routine +example/one' "默认先显示实际类别"
  assert_has "$default_frame" "自动检查" "默认有自动检查用途组"
  assert_not "$default_frame" "身份与账本布局" "全表不再占据首屏"
  assert_not "$default_frame" "立即生效" "普通行没有逐行生效徽章"
  assert_not "$default_frame" "未设 · 默认" "普通行直接给有效值"
  assert_not "$default_frame" "result=" "设置不显示审计"
  assert_eq "C3默认可选行=10（包含两个入口）" "$((r+u+d))" "10"
  assert_eq "打开设置没有写偏好" "$(sha "$state/panel.conf")" "$pref_before"
  filter_to TEAM_PULSE_INTERVAL
  wait_row interval "有效值与必要生效提示" "检查间隔" "900 秒" "team pulse restart" || { bad "检查间隔未显示"; return 1; }
  stats="$(wait_settings_frame "$height" filter-fill '项目设置' '检查间隔')" || { bad "未读到完整的过滤设置帧"; return 1; }
  read -r r u d gap <<<"$stats"
  assert_eq "过滤短列表只一行" "$((r+u+d))" "1"
  [ "$gap" -le 1 ] && ok "短列表空白在卡片里" || bad "短列表卡片未填高"
  filter_to 检查间隔
  cap_to label-filter
  assert_has "$tmp/$current/label-filter.txt" "检查间隔" "标签可搜索"
  filter_to EXAMPLE/ONE
  cap_to value-filter
  assert_has "$tmp/$current/value-filter.txt" "routine" "值搜索不区分大小写"
  keys Escape
  wait_row clear "Esc清过滤但不关闭设置" "› routine" "项目命令" || bad "Esc过滤返回错误"
  # 两个入口都沿原位置返回；鼠标单击只聚焦，第二击才打开。
  local y before
  before="$(sha "$(cfg)")"
  y="$(cap_now | grep -n '项目命令' | head -1 | cut -d: -f1)"
  [ -n "$y" ] && click_at 8 "$y"
  wait_row nav-focus "单击聚焦项目命令" "› 项目命令" || bad "入口未聚焦"
  assert_eq "单击不改配置" "$(sha "$(cfg)")" "$before"
  y="$(cap_now | grep -n '› 项目命令' | head -1 | cut -d: -f1)"
  [ -n "$y" ] && click_at 8 "$y"
  wait_row commands "第二击打开命令" "╭─ 项目命令" "验收命令" || { bad "命令入口未打开"; return 1; }
  stats="$(wait_settings_frame "$height" commands-count '项目命令' '安装命令')" || { bad "未读到完整的项目命令帧"; return 1; }
  read -r r u d gap <<<"$stats"
  assert_eq "项目命令只有3项" "$((r+u+d))" "3"
  keys Escape
  wait_row commands-back "命令返回原入口" "› 项目命令" "╭─ 项目设置" || bad "命令未返回"
  open_secondary records
  wait_row records "尚无记录保留事实" "尚无派单记录" || bad "记录原因未显示"
  keys Escape
  wait_row records-back "记录返回原入口" "› 模型记录" "╭─ 项目设置" || bad "记录未返回"
  filter_clear
  # 隐藏值不因搜索而成为操作；完整CLI仍保留已有接口。
  local k
  for k in TEAM_PROJECT TEAM_TASK_MODELS TEAM_TMP_MIN_FREE_MB TEAM_TMP_MIN_FREE_INODES TEAM_DISK_STATS_FILE; do
    filter_to "$k"; cap_to "excluded-$k"
    assert_no_match "$tmp/$current/excluded-$k.txt" '^│ [› ] [^│]*[^[:space:]│]' "退出的键不会成为操作行（$k）"
  done
  filter_clear
  keys Escape
  wait_row overlay-back "Esc返回原浮层入口" "› 项目设置" || bad "浮层焦点丢失"
  keys Enter
  pty_wait_frame - "再次打开设置" "╭─ 项目设置" || bad "设置未再打开"
  keys q
  wait_argv q-collapse "pulse collapse" && ok "q保留全局收起" || bad "q未收起"

  # 真实未知键warning仍可达；不要求为该键造编辑行。
  printf '\nTEAM_HAND_ADDED=hand\n' >> "$(cfg)"
  start_panel
  open_view
  filter_to TEAM_HAND_ADDED
  wait_row unknown-warning "退出行不隐藏真实warning" "不是已知的项目设置" || bad "未知键warning未显示"
  cap_to unknown
  assert_has "$tmp/$current/unknown.txt" "只能改项目配置文件" "未知键完整修复路线仍可达"
  assert_no_match "$tmp/$current/unknown.txt" '^│ [› ] TEAM_HAND_ADDED +hand' "未知键不是配置行"
  # 长列表用实际类别而非恢复全表；每个高度只观察同一列表。
  local map='routine=example/one' i h want_count prev_rows=''
  for i in $(seq 1 60); do map="$map cat$i=example/model$i"; done
  policy_new "$map" 'example/pm' || bad "长类别准备失败"
  python3 - "$(cfg)" <<'PYCFG'
import sys
p=sys.argv[1]; s=open(p).read(); s='\n'.join(l for l in s.split('\n') if not l.startswith('TEAM_HAND_ADDED='))
open(p,'w').write(s)
PYCFG
  start_panel
  open_view
  want_count=68
  for h in 45 33 30 25; do
    resize_panel 120 "$h" || { bad "$h行resize失败"; continue; }
    if stats="$(wait_settings_frame "$h" "height$h" '项目设置' routine)"; then
      read -r r u d gap <<<"$stats"
      assert_eq "$h行：可见$r + 上方隐藏$u + 下方隐藏$d = 当前68操作" "$((r+u+d))" "$want_count"
      [ "$gap" -le 1 ] && ok "$h行卡片填高" || bad "$h行卡片未填高"
      [ "$h" = 45 ] && prev_rows="$r"
      if [ "$h" = 30 ] && [ -n "$prev_rows" ]; then
        [ "$((prev_rows-r))" -ge 8 ] && ok "45比30至少多8行" || bad "窗口没有随高度增长"
      fi
    else bad "$h行完整设置帧未落定（卡片、焦点或设置键栏未读到）"; fi
  done
  # 同批英文窄屏：只走入口与返回，不重复整套。
  conf_set "lang=en" "page=1" "activity=1" "mouse=1" "density=comfortable"
  start_panel
  resize_panel 70 25 || bad "英文窄屏resize失败"
  open_view Models
  filter_to 'Project commands'; keys Enter
  wait_row en-commands "英文命令入口" "╭─ Project commands" "Acceptance command" || bad "英文命令入口失败"
  keys Escape
  wait_row en-back "英文入口返回" "Project settings" "Project commands" || bad "英文返回失败"
  filter_to 'Model records'; keys Enter
  wait_row en-records "英文记录入口" "╭─ Model records" "No dispatch record" || bad "英文记录入口失败"
  keys Escape
  wait_row en-records-back "英文记录返回" "Project settings" "Model records" || bad "英文记录返回失败"
}

scn_choices() {
  section "choices · 原选择保存/取消/范围/危险/响应性与模型数量字段草稿"
  server_up choices
  local map='routine=example/m0 analysis=example/m1' i
  for i in $(seq 2 28); do map="$map cat$i=example/m$i"; done
  policy_new "$map" 'example/pm' || bad "策略准备失败"
  python3 - "$(cfg)" <<'PYCFG'
import re,sys
p=sys.argv[1]; s=open(p).read()
s=re.sub(r'^TEAM_UPDATE_CHECK=.*\n?', '', s, flags=re.M)
s=re.sub(r'^TEAM_PULSE_INTERVAL=.*\n?', '', s, flags=re.M)
s=re.sub(r'^TEAM_REVIEW_TIMEOUT=.*$', 'TEAM_REVIEW_TIMEOUT=30', s, flags=re.M)
s=re.sub(r'^TEAM_MODEL_LIMITS=.*$', "TEAM_MODEL_LIMITS='example/m0=2  example/*=1 example/m0=4'", s, flags=re.M)
open(p,'w').write(s)
PYCFG
  local home="$tmp/$current-home"
  mkdir -p "$home/.pi/agent"
  printf '%s\n' '{"machine-only":{"models":{"unrelated":{}}}}' > "$home/.pi/agent/models-store.json"
  P21_REFRESH=3600 P21_HOME="$home" start_panel
  open_view
  filter_to TEAM_UPDATE_CHECK
  wait_row bool-row "bool默认有效值" "启动时检查新版本" "开" || bad "bool未落定"
  local gap0 before audit0
  before="$(sha "$(cfg)")"; audit0="$(audit_lines)"; gap0="$(argv_count)"
  keys Enter
  wait_picker TEAM_UPDATE_CHECK "› 保持默认值" || bad "bool选择器未打开"
  argv_since "$gap0" "$tmp/$current/open.log"
  assert_eq "打开选择器零读取零子进程" "$(wc -l < "$tmp/$current/open.log")" "0"
  cap_to bool
  assert_has "$tmp/$current/bool.txt" "开 · 默认" "bool默认标记"
  assert_has "$tmp/$current/bool.txt" "关" "bool另一规范值"
  assert_not "$tmp/$current/bool.txt" "输入其它值" "bool不提供自由输入"
  keys Enter
  wait_row keep-default "保持默认只取消" "╭─ 项目设置" "启动时检查新版本" || bad "保持默认未返回"
  assert_eq "保持默认配置不变" "$(sha "$(cfg)")" "$before"
  assert_eq "保持默认不增审计" "$(audit_lines)" "$audit0"
  assert_eq "保持默认没有临时文件" "$(find "$ROOT/.pi/team" -name 'config.sh.tmp.*' | wc -l)" "0"
  keys Enter
  wait_picker TEAM_UPDATE_CHECK "关" || bad "第二次bool未打开"
  gap0="$(argv_count)"
  pick_option 关 || bad "找不到关"
  wait_cap bool-written "已保存启动时检查新版本" || bad "bool直写没有回执"
  assert_match "$(cfg)" "^TEAM_UPDATE_CHECK=.0.$" "bool落规范0"
  assert_eq "一次accept审计一行" "$(audit_lines)" "$((audit0+1))"
  argv_since "$gap0" "$tmp/$current/accept.log"
  assert_match "$tmp/$current/accept.log" 'config set TEAM_UPDATE_CHECK 0 --actor panel --dry-run --fingerprint [0-9a-f]{64}' "dry-run带actor和原指纹"
  assert_match "$tmp/$current/accept.log" 'config set TEAM_UPDATE_CHECK 0 --actor panel --yes --fingerprint [0-9a-f]{64}' "直写带actor和原指纹"
  assert_not "$tmp/$current/bool-written.txt" "原值" "普通选择不多一轮确认"
  wait_row bool-new "后台读回规范0" "启动时检查新版本" "关" || bad "bool没有读回"
  keys Enter
  wait_picker TEAM_UPDATE_CHECK "关 · 当前" || bad "bool当前标记错误"
  before="$(sha "$(cfg)")"; audit0="$(audit_lines)"
  local y
  y="$(cap_now | grep -n '开 · 默认' | head -1 | cut -d: -f1)"
  [ -n "$y" ] && click_at 5 "$y"
  wait_row click-first "单击选择" "› 开" || bad "单击未选择"
  assert_eq "单击未写" "$(sha "$(cfg)")" "$before"
  y="$(cap_now | grep -n '› 开' | head -1 | cut -d: -f1)"
  [ -n "$y" ] && click_at 5 "$y"
  wait_cap click-written "已保存启动时检查新版本" || bad "二击未直写"
  assert_eq "二击只增一次审计" "$(audit_lines)" "$((audit0+1))"
  wait_row bool-one "bool读回1" "启动时检查新版本" "开" || bad "bool读回失败"
  keys Enter; wait_picker TEAM_UPDATE_CHECK "开 · 当前" || bad "取消picker未打开"
  before="$(sha "$(cfg)")"; audit0="$(audit_lines)"; gap0="$(argv_count)"
  leave_picker TEAM_UPDATE_CHECK || bad "picker取消失败"
  assert_eq "取消不写" "$(sha "$(cfg)")" "$before"
  assert_eq "取消不增审计" "$(audit_lines)" "$audit0"
  argv_since "$gap0" "$tmp/$current/cancel.log"
  assert_not "$tmp/$current/cancel.log" "config set" "取消不调用writer"
  PTY_TRACE=1 pty_cleanup_esc "已关闭的选择器" "╭─ 启动时检查新版本" > "$tmp/$current/cleanup-trace.txt" 2>&1
  assert_has "$tmp/$current/cleanup-trace.txt" "action=none" "已关闭选择器清理不发Esc"
  assert_has "$tmp/$current/cleanup-trace.txt" "reason=not-settled" "清理依据稳定帧而非等待上限"
  cap_to cleanup
  assert_has "$tmp/$current/cleanup.txt" "╭─ 项目设置" "清理未穿透设置"
  keys Enter
  PTY_TRACE=1 wait_picker TEAM_UPDATE_CHECK '开 · 当前' > "$tmp/$current/wait-trace.txt" 2>&1 || bad "正常trace选择器未打开"
  assert_match "$tmp/$current/wait-trace.txt" 'wait picker TEAM_UPDATE_CHECK rounds=[0-9]+ settled=1' "正常等待放行仍来自稳定帧"
  leave_picker TEAM_UPDATE_CHECK || bad "正常trace选择器未关闭"

  filter_to TEAM_PULSE_INTERVAL; keys Enter
  wait_picker TEAM_PULSE_INTERVAL "保持默认值" || bad "数值未打开"
  cap_to numeric
  assert_has "$tmp/$current/numeric.txt" "60–" "原读的最小值可见"
  assert_has "$tmp/$current/numeric.txt" "900 秒 · 默认" "原默认值及单位可见"
  assert_has "$tmp/$current/numeric.txt" "1800" "原建议值可见"
  pick_option 输入其它值 || bad "没有自由输入"
  wait_editor TEAM_PULSE_INTERVAL "900" || bad "原有效值不可编辑"
  keys C-u; sleep 0.3; type_text 30; sleep 0.3; keys Enter
  wait_cap invalid "最小 60" || bad "真实范围错误消失"
  assert_eq "非法值保留配置" "$(sha "$(cfg)")" "$before"
  assert_eq "非法值没有审计" "$(audit_lines)" "$audit0"
  leave_editor TEAM_PULSE_INTERVAL || bad "非法草稿取消失败"
  filter_to TEAM_PULSE_INTERVAL; keys Enter
  wait_picker TEAM_PULSE_INTERVAL "1800" || bad "数值重开失败"
  pick_option 1800 || bad "建议值不可选择"
  wait_cap suggestion "已保存检查间隔" || bad "建议值没有直写"
  assert_has "$tmp/$current/suggestion.txt" "team pulse restart" "间隔保存提示真实重启条件"
  assert_match "$(cfg)" "^TEAM_PULSE_INTERVAL=.1800.$" "建议值落盘"

  filter_to TEAM_PM_MODEL; keys Enter
  wait_picker TEAM_PM_MODEL "↓" || bad "长模型词表未打开"
  cap_to wheel-before
  for i in $(seq 1 35); do wheel_at down 20 12; done
  wait_row wheel-after "长模型词表末尾" "输入其它值" "↑" || bad "长词表不能滚到尾部"
  assert_not "$tmp/$current/wheel-before.txt" "machine-only" "开屏词表不列机器目录模型"
  assert_not "$tmp/$current/wheel-after.txt" "machine-only" "项目选项不读机器目录"
  ( cd "$ROOT" && HOME="$home" bash "$skill/scripts/team" config list --json ) > "$tmp/$current/read-json.json" 2>&1
  assert_not "$tmp/$current/read-json.json" "machine-only" "同一机器目录下的实际读也只含项目词表"
  if wait_picker_quick TEAM_PM_MODEL "不存在的条目"; then bad "缺条目仍被当作已到达"; else ok "等待须命中实际条目"; fi
  leave_picker TEAM_PM_MODEL || bad "长词表退出失败"

  open_secondary commands || return 1
  filter_to TEAM_GATES
  wait_row gates-row "命令页的验收命令" "╭─ 项目命令" "› 验收命令" "true" || { bad "未聚焦验收命令"; return 1; }
  gap0="$(argv_count)"; keys Enter
  wait_editor TEAM_GATES "true" || { bad "命令原值未打开"; return 1; }
  argv_since "$gap0" "$tmp/$current/command-open.log"
  assert_eq "命令自由输入打开零读取" "$(argv_reads "$tmp/$current/command-open.log")" "0"
  leave_editor TEAM_GATES || { bad "命令取消失败"; return 1; }
  filter_to TEAM_REVIEW_TIMEOUT
  wait_row timeout-row "命令页的验收最长时间" "╭─ 项目命令" "› 验收最长时间" "30 秒" || { bad "危险测试的初值或焦点不正确"; return 1; }
  keys Enter
  wait_picker TEAM_REVIEW_TIMEOUT "› 30 秒 · 当前" || { bad "危险的当前选项未打开"; return 1; }
  before="$(sha "$(cfg)")"; audit0="$(audit_lines)"; gap0="$(argv_count)"
  keys Enter
  wait_row danger "危险当前值需要额外确认" "╭─ 验收最长时间" "› 30 秒 · 当前" "危险：" "Enter 确认" || { bad "危险未要求确认"; return 1; }
  assert_eq "危险首次accept不写" "$(sha "$(cfg)")" "$before"
  assert_eq "危险首次accept无审计" "$(audit_lines)" "$audit0"
  argv_since "$gap0" "$tmp/$current/danger.log"
  assert_has "$tmp/$current/danger.log" "config set TEAM_REVIEW_TIMEOUT 30 --actor panel --dry-run --fingerprint $before" "危险首次accept验证原值和指纹"
  assert_not "$tmp/$current/danger.log" "--yes" "危险首次accept没有yes"
  gap0="$(argv_count)"; keys Enter
  wait_row danger-saved "额外确认后返回命令页" "╭─ 项目命令" "已保存验收最长时间" || { bad "危险确认未保存"; return 1; }
  argv_since "$gap0" "$tmp/$current/danger-write.log"
  assert_has "$tmp/$current/danger-write.log" "config set TEAM_REVIEW_TIMEOUT 30 --actor panel --yes --fingerprint $before --allow-danger" "危险确认使用原指纹及allow-danger"
  assert_eq "危险确认只调用一次writer" "$(grep -cF 'config set TEAM_REVIEW_TIMEOUT ' "$tmp/$current/danger-write.log")" "1"
  assert_eq "危险确认只增一条审计" "$(audit_lines)" "$((audit0+1))"
  assert_match "$(cfg)" "^TEAM_REVIEW_TIMEOUT='30'\$" "危险确认后仍为30秒"
  filter_clear; keys Escape
  wait_row choices-main "命令页返回项目设置" "╭─ 项目设置" "› 项目命令" || { bad "规则测试未返回设置入口"; return 1; }

  # 规则从主设置的可选行打开；字段修改只留草稿，完整旧/新确认后才写回。
  filter_to TEAM_MODEL_LIMITS
  wait_row limits-row "主设置的模型规则" "╭─ 项目设置" "› 模型同时运行任务数" || { bad "未聚焦模型规则"; return 1; }
  keys Enter
  wait_row rules "规则字段入口" "╭─ 模型同时运行任务数" "› example/m0" "example/*" "添加限制" || { bad "规则列表未打开"; return 1; }
  before="$(sha "$(cfg)")"; audit0="$(audit_lines)"; gap0="$(argv_count)"
  keys Enter
  wait_row fields "模型数量字段" "╭─ 编辑限制" "适用模型" "同时运行数量" "删除限制" || { bad "未显示两个字段"; return 1; }
  keys Down
  pty_key_when "打开数量字段" '› 同时运行数量' Enter || { bad "未聚焦数量字段"; return 1; }
  wait_editor 同时运行数量 "2" || { bad "数量字段没有原值"; return 1; }
  keys C-u; sleep 0.3; type_text -1; sleep 0.3; keys Enter
  wait_cap count-invalid "请输入非负整数" || { bad "数量字段非法值未保留"; return 1; }
  assert_eq "字段非法配置不变" "$(sha "$(cfg)")" "$before"
  keys C-u; sleep 0.3; type_text 0; sleep 0.3; keys Enter
  wait_row unlimited "0的业务标签" "╭─ 编辑限制" "此项不限制" || { bad "0未显示此项不限制"; return 1; }
  assert_eq "字段完成仍未写" "$(sha "$(cfg)")" "$before"
  keys Escape
  wait_row rules-back "字段返回规则列表" "╭─ 模型同时运行任务数" "添加限制" || { bad "字段未返回规则列表"; return 1; }
  focus_row '› 保存' || { bad "保存行不可达"; return 1; }
  keys Enter
  wait_row rules-confirm "完整旧新规则" "╭─ 模型同时运行任务数" "原值" "新值" "example/*" "此项不限制" || { bad "完整规则确认未显示"; return 1; }
  assert_eq "整组确认阶段不写" "$(sha "$(cfg)")" "$before"
  assert_eq "整组确认阶段无审计" "$(audit_lines)" "$audit0"
  keys Enter
  wait_row rules-written "规则保存后返回主设置" "╭─ 项目设置" "已保存模型同时运行任务数" || { bad "完整规则未保存"; return 1; }
  assert_match "$(cfg)" "^TEAM_MODEL_LIMITS='example/m0=0 example/\*=1 example/m0=4'$" "只改一个token，重复及顺序保留"
  assert_eq "完整规则只审计一行" "$(audit_lines)" "$((audit0+1))"
  argv_since "$gap0" "$tmp/$current/rules-write.log"
  local value='example/m0=0 example/*=1 example/m0=4'
  assert_has "$tmp/$current/rules-write.log" "config set TEAM_MODEL_LIMITS $value --actor panel --dry-run --fingerprint $before" "完整新值经原指纹验证"
  assert_has "$tmp/$current/rules-write.log" "config set TEAM_MODEL_LIMITS $value --actor panel --yes --fingerprint $before" "完整新值经原指纹写入"
  assert_eq "完整规则一次验证一次写入" "$(grep -cF 'config set TEAM_MODEL_LIMITS ' "$tmp/$current/rules-write.log")" "2"
  # 添加/删除/取消与冲突：不另写每模型文件，也不碰原配置。
  filter_to TEAM_MODEL_LIMITS
  pty_key_when "重开模型规则" "› 模型同时运行任务数" Enter || { bad "重开前未聚焦模型规则"; return 1; }
  wait_row rules-again "规则重新打开并读到保存结果" "╭─ 模型同时运行任务数" "此项不限制" "添加限制" || { bad "规则未重开或未读到保存结果"; return 1; }
  before="$(sha "$(cfg)")"; audit0="$(audit_lines)"
  focus_row '› 添加限制' || { bad "添加限制行不可达"; return 1; }
  keys Enter
  wait_row added "新增草稿字段" "╭─ 编辑限制" "› 适用模型" "同时运行数量" || { bad "新增字段未打开"; return 1; }
  keys Enter
  wait_picker 适用模型 "example/m0" || { bad "适用模型picker未打开"; return 1; }
  for i in $(seq 1 35); do wheel_at down 20 12; done
  wait_row model-other "长词表中的其它适用模型" "› 其它适用模型" || { bad "其它适用模型不可达"; return 1; }
  keys Enter
  wait_editor 适用模型 || { bad "表达式输入未打开"; return 1; }
  type_text 'example/new*'; sleep 0.3; keys Enter
  wait_row added-model "新增表达式只改草稿" "╭─ 编辑限制" "example/new*" || { bad "表达式草稿未显示"; return 1; }
  focus_row '› 删除限制' || { bad "删除限制行不可达"; return 1; }
  keys Enter
  wait_row deleted "删除返回列表" "╭─ 模型同时运行任务数" "添加限制" '!example/new*' || { bad "删除未返回列表"; return 1; }
  keys Escape
  wait_row rules-cancel "整组取消" "╭─ 项目设置" "› 模型同时运行任务数" || { bad "整组取消未返回"; return 1; }
  assert_eq "新增删除取消保留字节" "$(sha "$(cfg)")" "$before"
  assert_eq "新增删除取消无审计" "$(audit_lines)" "$audit0"
  keys Enter
  wait_row rules-stale "冲突规则列表" "╭─ 模型同时运行任务数" "添加限制" || { bad "冲突规则未打开"; return 1; }
  printf '# other writer\n' >> "$(cfg)"
  local other; other="$(sha "$(cfg)")"
  focus_row '› 保存' || { bad "冲突样本的保存行不可达"; return 1; }
  keys Enter
  wait_row rules-stale-confirm "旧指纹确认页" "╭─ 模型同时运行任务数" "── 原值" "── 新值" "设置已被修改，未保存" || { bad "规则旧指纹未提示冲突"; return 1; }
  keys Enter
  wait_row rules-stale-result "旧指纹写入被拒并返回规则列表" "╭─ 模型同时运行任务数" "添加限制" '!── 原值' "设置已被修改，未保存" || { bad "规则冲突未保留"; return 1; }
  assert_eq "规则CAS保住另一个写者字节" "$(sha "$(cfg)")" "$other"
  assert_eq "规则冲突只增一条审计" "$(audit_lines)" "$((audit0+1))"
  assert_match "$(audit_log)" 'result=conflict actor=panel key=TEAM_MODEL_LIMITS' "规则冲突有原审计"
  assert_not "$(argv_log)" "pulse restart" "设置未执行重启命令"
  # 同批英文窄屏只走字段/非法/返回，不重复完整保存场景。
  conf_set "lang=en" "page=1" "activity=1" "mouse=1" "density=comfortable"
  start_panel
  resize_panel 70 25 || { bad "英文表单resize失败"; return 1; }
  open_view Models || return 1
  filter_to TEAM_MODEL_LIMITS
  pty_key_when "英文规则行" "› Concurrent tasks by model" Enter || { bad "未聚焦英文规则"; return 1; }
  wait_row en-rules "英文规则入口" "╭─ Concurrent tasks by model" "Add limit" || { bad "英文规则未打开"; return 1; }
  before="$(sha "$(cfg)")"
  keys Enter
  wait_row en-fields "英文规则字段" "╭─ Edit limit" "Applicable model" "Simultaneous quantity" || { bad "英文规则字段缺失"; return 1; }
  keys Down
  pty_key_when "打开英文数量字段" '› Simultaneous quantity' Enter || { bad "未聚焦英文数量字段"; return 1; }
  wait_editor "Simultaneous quantity" || { bad "英文数量字段未打开"; return 1; }
  keys C-u; sleep 0.3; type_text -1; sleep 0.3; keys Enter
  wait_cap en-invalid "Enter a non-negative integer" || { bad "英文真实字段错误未显示"; return 1; }
  keys Escape
  wait_row en-field-back "英文字段返回" "Applicable model" "Simultaneous quantity" '!╭─ Simultaneous quantity' || { bad "英文字段未返回"; return 1; }
  keys Escape
  wait_row en-rules-back "返回英文规则列表" "╭─ Concurrent tasks by model" "Add limit" || { bad "未返回英文规则列表"; return 1; }
  keys Escape
  wait_row en-cancel "英文草稿取消" "╭─ Project settings" || { bad "英文草稿未取消"; return 1; }
  assert_eq "英文非法与取消保留原字节" "$(sha "$(cfg)")" "$before"
}

scn_choices_schema() {
  section "choices-schema · 新键不自动显示；保留键选项/权限/异常整值仍来自真实CLI"
  server_up choices-schema
  policy_new 'routine=example/one' 'example/pm' || bad "策略准备失败"
  local scratch="$tmp/$current/scratch"
  mkdir -p "$scratch/skills/teamsmith"
  cp -a "$skill/scripts" "$scratch/skills/teamsmith/scripts"
  cp -a "$skill/templates" "$skill/references" "$scratch/skills/teamsmith/"
  python3 - "$scratch/skills/teamsmith/scripts/lib/cmd-config.sh" <<'PYCFG'
import sys
p=sys.argv[1]; s=open(p).read()
anchor='TEAM_INSTALL_CMD|apply|cmd||plain||-|||workflow'
assert anchor in s
s=s.replace(anchor,'TEAM_ZZZ_MODE|apply|enum|red,blue|plain|red|-|||workflow\n'+anchor)
old='TEAM_PULSE_INTERVAL|restart|seconds|60,|plain|900|低于 60 秒 = 巡检转成忙等||300,900,1800,3600|panel'
assert old in s
s=s.replace(old,old.replace('300,900,1800,3600','300,900,1800,3600,7200'))
open(p,'w').write(s)
PYCFG
  cat > "$tmp/$current-scratch-wrapper.sh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$tmp/$current-scratch-argv.log"
exec bash "$scratch/skills/teamsmith/scripts/team" "\$@"
EOF
  chmod +x "$tmp/$current-scratch-wrapper.sh"
  P21_CLI="$tmp/$current-scratch-wrapper.sh" start_panel
  open_view
  filter_to TEAM_ZZZ_MODE; cap_to excluded
  assert_no_match "$tmp/$current/excluded.txt" '^│ [› ] [^│]*[^[:space:]│]' "新enum键不成为设置操作"
  filter_to TEAM_PULSE_INTERVAL; keys Enter
  wait_picker TEAM_PULSE_INTERVAL "7200" || bad "保留键新choice没有出现"
  cap_to choices
  assert_has "$tmp/$current/choices.txt" "7200" "保留键choices变更无需重建bundle"
  leave_picker TEAM_PULSE_INTERVAL
  # 源不能表示成字段时完整保留原值，交原writer校验；不丢弃坏token。
  python3 - "$(cfg)" <<'PYCFG'
import re,sys
p=sys.argv[1]; s=open(p).read()
s,n=re.subn(r'^TEAM_MODEL_LIMITS=.*$', "TEAM_MODEL_LIMITS='example/one=2 malformed example/*=1'", s, flags=re.M)
assert n == 1, '异常样例必须替换唯一原配置行'
open(p,'w').write(s)
PYCFG
  ( cd "$ROOT" && bash "$scratch/skills/teamsmith/scripts/team" config list --json ) > "$tmp/$current/malformed-read.json"
  assert_eq "异常整值确实从原配置行读出" "$(python3 - "$tmp/$current/malformed-read.json" <<'PYVALUE'
import json,sys
j=json.load(open(sys.argv[1]))
print(next(k['value'] for k in j['keys'] if k['name'] == 'TEAM_MODEL_LIMITS'))
PYVALUE
)" 'example/one=2 malformed example/*=1'
  start_panel; open_view
  filter_to TEAM_MODEL_LIMITS; keys Enter
  wait_editor TEAM_MODEL_LIMITS "malformed" || bad "异常完整值没有进入原输入器"
  local before; before="$(sha "$(cfg)")"
  keys Enter
  wait_cap malformed "malformed" || bad "整值校验错误消失"
  assert_eq "异常原值非法提交保持字节" "$(sha "$(cfg)")" "$before"
  leave_editor TEAM_MODEL_LIMITS
  unset P21_CLI
}

scn_write() {
  section "write · 一行 diff / 注释保留 / 两次确认 / 取消 / 非法保留草稿 / danger 两步 / restart 不谎报（B3）"
  server_up write
  python3 - "$(cfg)" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = re.sub(r'^TEAM_PULSE_INTERVAL=.*$', 'TEAM_PULSE_INTERVAL="900"  # 15min', s, count=1, flags=re.M)
open(p, 'w', encoding='utf-8').write(s)
PY
  conf_set "lang=zh" "page=1" "activity=1" "mouse=1" "density=comfortable" "theme=auto"
  start_panel
  open_view
  cp "$(cfg)" "$tmp/$current/before.cfg"
  filter_to TEAM_PULSE_INTERVAL
  sleep 0.5
  keys Enter
  # M55：数值键现在先开选择器（建议值 + 输入其它值），写路径本身没变 —— 走进输入其它值那一项。
  wait_picker TEAM_PULSE_INTERVAL '· 当前' || bad "写用例的选择器没有打开"
  pick_option '输入其它值' || bad "写用例的选择器里没有输入其它值项"
  wait_editor TEAM_PULSE_INTERVAL || bad "写用例的编辑器没有打开"
  cap_has "检查间隔" editor
  keys BSpace BSpace BSpace
  sleep 0.3
  type_text "1200"
  sleep 0.4
  keys Enter
  if wait_cap confirm "新值  1200"; then ok "第一次 Enter 只给确认行（没写）"; else bad "确认行没有出现（见 confirm.txt）"; fi
  assert_eq "确认阶段契约未变" "$(sha "$(cfg)")" "$(sha "$tmp/$current/before.cfg")"
  keys Enter
  if wait_cap written "已保存检查间隔"; then
    ok "第二次 Enter 的回执说已写入"
  else
    bad "第二次 Enter 的回执没有出现（见 written.txt）"
  fi
  assert_eq "只改了一行" "$(diff "$tmp/$current/before.cfg" "$(cfg)" | grep -c '^[<>]' || true)" "2"
  assert_eq "注释原样保留" "$(grep -c "^TEAM_PULSE_INTERVAL='1200'  # 15min\$" "$(cfg)" || true)" "1"
  ( cd "$ROOT" && bash -n .pi/team/config.sh ) && ok "写入后 bash -n 通过" || bad "写入后 bash -n 失败"
  assert_match "$(argv_log)" 'config set TEAM_PULSE_INTERVAL 1200 --actor panel --dry-run --fingerprint [0-9a-f]{64}' "wrapper 记录了 --dry-run 调用"
  assert_match "$(argv_log)" 'config set TEAM_PULSE_INTERVAL 1200 --actor panel --yes --fingerprint [0-9a-f]{64}' "wrapper 记录了写入调用"
  # Cancel: esc writes nothing and audits nothing.
  local a0 b0
  a0="$(audit_lines)"
  b0="$(sha "$(cfg)")"
  filter_to TEAM_PULSE_INTERVAL
  sleep 0.5
  keys Enter
  wait_picker TEAM_PULSE_INTERVAL '· 当前' || bad "取消用例的选择器没有打开"
  pick_option '输入其它值' || bad "取消用例的选择器里没有输入其它值项"
  wait_editor TEAM_PULSE_INTERVAL || bad "取消用例的编辑器没有打开"
  type_text "x"
  sleep 0.4
  leave_editor TEAM_PULSE_INTERVAL || bad "取消用例的 esc 发了但编辑器还在"
  wait_no_editor || bad "取消用例的编辑器没有关干净"
  assert_eq "取消后契约不变" "$(sha "$(cfg)")" "$b0"
  assert_eq "取消后审计不增长" "$(audit_lines)" "$a0"
  assert_eq "取消后没有临时文件" "$(ls "$ROOT/.pi/team/"config.sh.tmp.* 2>/dev/null | wc -l)" "0"
  # Invalid: TEAM_PULSE_INTERVAL=0 → refusal names the range, sha unchanged, editor keeps the draft.
  filter_to TEAM_PULSE_INTERVAL
  sleep 0.5
  keys Enter
  wait_picker TEAM_PULSE_INTERVAL '· 当前' || bad "非法值用例的选择器没有打开"
  pick_option '输入其它值' || bad "非法值用例的选择器里没有输入其它值项"
  wait_editor TEAM_PULSE_INTERVAL || bad "非法值用例的编辑器没有打开"
  keys BSpace BSpace BSpace BSpace
  sleep 0.3
  type_text "0"
  sleep 0.4
  local b1; b1="$(sha "$(cfg)")"
  keys Enter
  if wait_cap invalid "最小 60"; then ok "越界数值的拒绝点名最小 60"; else bad "越界数值的拒绝没出现"; fi
  assert_eq "非法值契约不变" "$(sha "$(cfg)")" "$b1"
  cap_has "检查间隔" draft-kept
  leave_editor TEAM_PULSE_INTERVAL || bad "非法值用例的 esc 发了但编辑器还在"
  wait_no_editor || bad "非法值用例的编辑器没有关干净"
  # Danger: TEAM_REVIEW_TIMEOUT=30 needs one more Enter.
  open_secondary commands
  filter_to TEAM_REVIEW_TIMEOUT
  sleep 0.5
  keys Enter
  wait_picker TEAM_REVIEW_TIMEOUT '· 当前' || bad "danger 用例的选择器没有打开"
  pick_option '输入其它值' || bad "danger 用例的选择器里没有输入其它值项"
  wait_editor TEAM_REVIEW_TIMEOUT || bad "danger 用例的编辑器没有打开"
  keys BSpace BSpace BSpace BSpace
  sleep 0.3
  type_text "30"
  sleep 0.4
  local b2; b2="$(sha "$(cfg)")"
  keys Enter
  if wait_cap danger "危险："; then ok "危险值先要一个额外确认"; else bad "危险值的确认提示没出现"; fi
  assert_eq "危险确认前契约不变" "$(sha "$(cfg)")" "$b2"
  keys Enter
  if wait_cap danger-written "已保存验收最长时间"; then
    ok "第二次 Enter 写入危险值"
  else
    bad "危险值的第二次 Enter 没有落盘（见 danger-written.txt）"
  fi
  # 保存间隔不重启Pulse；新读值可见。
  filter_clear; keys Escape; sleep 0.4
  local pid_args_before
  pid_args_before="$(tr '\0' ' ' < "/proc/$(panel_pid)/cmdline")"
  filter_to TEAM_PULSE_INTERVAL; keys Enter
  wait_picker TEAM_PULSE_INTERVAL '· 当前' || bad "restart选择器未打开"
  pick_option 输入其它值
  wait_editor TEAM_PULSE_INTERVAL || bad "restart编辑器未打开"
  keys C-u; sleep 0.3; type_text 1500; sleep 0.3; keys Enter
  wait_cap restart-confirm "新值  1500" || bad "restart未确认"
  keys Enter
  wait_cap restart "已保存检查间隔" || bad "restart未保存"
  assert_has "$tmp/$current/restart.txt" "team pulse restart" "回执点名Pulse实际生效条件"
  assert_eq "现有面板argv没有变化" "$(tr '\0' ' ' < "/proc/$(panel_pid)/cmdline")" "$pid_args_before"
  assert_match "$(cfg)" "^TEAM_PULSE_INTERVAL=.1500." "新读者看见1500"
  assert_not "$(argv_log)" "pulse restart" "设置没有自动重启"
  # 真实文件故障，非伪造失败退出码：writer无法把目录作为配置文件。
  filter_to TEAM_PULSE_INTERVAL; keys Enter
  wait_picker TEAM_PULSE_INTERVAL '· 当前' || bad "失败用例未打开"
  pick_option 输入其它值; wait_editor TEAM_PULSE_INTERVAL || bad "失败输入未打开"
  keys C-u; sleep 0.3; type_text 1600; sleep 0.3; keys Enter
  wait_cap failure-confirm "新值  1600" || bad "失败前确认缺失"
  mv "$(cfg)" "$tmp/$current/saved.cfg"; mkdir "$(cfg)"
  keys Enter
  wait_cap write-failed "保存失败：" || bad "真实writer失败未显示"
  cap_to failure-draft
  assert_has "$tmp/$current/failure-draft.txt" "1600" "失败仍保留草稿"
  rmdir "$(cfg)"; mv "$tmp/$current/saved.cfg" "$(cfg)"
  leave_editor TEAM_PULSE_INTERVAL

}

scn_conflict() {
  section "conflict · 编辑器开着时另一个写者改文件：指纹拒绝、字节是对方的、视图重读、审计一行 conflict（B3）"
  server_up conflict
  python3 - "$(cfg)" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = re.sub(r'^TEAM_PULSE_INTERVAL=.*$', 'TEAM_PULSE_INTERVAL="900"  # 15min', s, count=1, flags=re.M)
open(p, 'w', encoding='utf-8').write(s)
PY
  start_panel
  open_view
  filter_to TEAM_PULSE_INTERVAL
  sleep 0.5
  keys Enter
  wait_picker TEAM_PULSE_INTERVAL '· 当前' || bad "冲突用例的选择器没有打开"
  pick_option '输入其它值' || bad "冲突用例的选择器里没有输入其它值项"
  wait_editor TEAM_PULSE_INTERVAL || bad "冲突用例的编辑器没有打开"
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
  if wait_cap conflict "设置已被修改，未保存"; then ok "回执点名指纹冲突"; else bad "冲突的回执没出现"; fi
  assert_eq "对方的字节被保住" "$(sha "$(cfg)")" "$other"
  assert_match "$(audit_log)" 'result=conflict actor=panel key=TEAM_PULSE_INTERVAL' "审计增了一行 conflict"
  # 后台读回另一个写者的900；必要生效信息仍在，未保存的1200不能变成行值。
  leave_editor TEAM_PULSE_INTERVAL
  if wait_cap reloaded "900"; then ok "视图重读后显示对方的 900"; else bad "视图重读后没有显示对方的 900"; fi
  assert_match "$tmp/$current/reloaded.txt" '检查间隔 +900' "视图重读后显示对方的 900（标签 + 值）"
  assert_not "$tmp/$current/reloaded.txt" "检查间隔 +1200" "视图没有显示未写入的 1200"
  assert_has "$tmp/$current/reloaded.txt" "team pulse restart" "必要生效条件仍可见"
}

# ---------------------------------------------------------------- P232（类别策略 vs 已派记录）
# 窄判据：类别行 + 策略/实际分离 + 一次类别直写。flip 段把它当靶子（把写入路由或显示规则弄坏，
# 这一段必须红）。它刻意只走一条路径，好让红侧点名到具体的断言。
scn_policy() {
  section "policy · 类别行 / 策略 vs 实际 / 类别直写走 set-task-model（P232 的窄判据）"
  server_up policy "dev verify"
  policy_new 'routine=kimi-coding/k3-256k analysis=openai-codex/gpt-5.6-terra:xhigh' 'openai-codex/gpt-6.1-sol:high' \
    || bad "策略升级事务没有跑通（见 $tmp/$current-upgrade.log）"
  record_fixture dev 'xai/grok-4.6' sid-dev-232 T232-x routine
  conf_set "lang=zh" "page=1" "activity=1" "mouse=1" "density=comfortable" "theme=auto"
  start_panel
  open_view
  # ① 类别行：未来策略模型；选中后显示新任务生效。
  filter_clear
  wait_row policy-cat "routine 行（未来策略模型）" '模型' 'routine' 'kimi-coding/k3-256k' \
    || bad "类别行没等到（超过等待上限）"
  # 视图的快照行、命令行提示行都跟着**焦点**走：先把光标移到类别行，再看这一行的两半（M49）。
  if focus_row '› routine'; then :; else bad "没能把焦点移到routine 行"; fi
  cap_to policy-cat
  assert_match "$tmp/$current/policy-cat.txt" '› routine +kimi-coding/k3-256k' "类别行 = 类别 + 策略模型"
  assert_has "$tmp/$current/policy-cat.txt" "新任务生效" "类别选中显示实际生效时间"
  # ② 策略 ≠ 实际：dev 的只读行显示**记录**里的模型，行里不出现策略模型
  open_secondary records
  filter_to dev
  wait_row policy-dev "dev 的只读派单行" '模型记录' 'xai/grok-4.6' \
    || bad "dev 的派单行没等到（超过等待上限）"
  if focus_row '› dev '; then :; else bad "没能把焦点移到 dev 的派单行"; fi
  cap_to policy-dev
  assert_match "$tmp/$current/policy-dev.txt" 'dev +T232-x +xai/grok-4.6' "记录模型逐字显示（不是策略模型）"
  assert_not "$tmp/$current/policy-dev.txt" "kimi-coding/k3-256k" "派单行里不出现未来策略的模型"
  assert_has "$tmp/$current/policy-dev.txt" "会话编号: sid-dev-232" "派单行带已提交的会话号"
  # ③ 没有记录的席位：不借策略模型
  filter_to verify
  wait_row policy-verify "verify 的「尚无派单记录」行" 'verify' '尚无派单记录' \
    || bad "无记录席位行没等到（超过等待上限）"
  assert_not "$tmp/$current/policy-verify.txt" "kimi-coding/k3-256k" "无记录席位行不借未来策略的模型"
  # ③b P266（设计表的红侧第二格）：同一个席位换成一份「存在、但读不出来」的记录（旧格式：版本不是 1）
  # → 说法换成另一句。面板从读侧的 record_present 事实选措辞（无文件 = 没派过；有文件 = 读不出来），
  # 不解析诊断字符串。
  printf 'assignment_version=0\nseat=verify\nmodel=vendor/legacy\n' > "$state/verify.env"
  reopen_view
  open_secondary records
  filter_to verify
  wait_row policy-unreadable "record_present=true：有记录但读不出来" 'verify' '记录读取失败' \
    || bad "「读不出来」的席位行没等到（超过等待上限）"
  assert_not "$tmp/$current/policy-unreadable.txt" "尚无派单记录" "P266：有记录但读不出来时不说「还没派过任务」（两个原因分得开）"
  assert_not "$tmp/$current/policy-unreadable.txt" "legacy/unknown assignment_version" "P266：命令的诊断字符串不上屏"
  local pol_json_verify
  pol_json_verify="$( ( cd "$ROOT" && bash "$skill/scripts/team" config list --json ) \
    | python3 -c 'import json,sys; d=json.load(sys.stdin); r=[a for a in d["models"]["assignments"] if a["agent"]=="verify"][0]; print("assigned=%s record_present=%s diagnostic=%s" % (r["assigned"], r.get("record_present"), r.get("diagnostic")))' )"
  assert_eq "P266：读侧把这一行报成 assigned=false 且 record_present=true（诊断只留给机器）" \
    "$pol_json_verify" "assigned=False record_present=True diagnostic=legacy/unknown assignment_version"
  rm -f "$state/verify.env"
  filter_clear; keys Escape; sleep 0.4
  # ④ 一次类别直写：picker 用项目自己的词表，写走 set-task-model 的 dry-run → --yes
  filter_clear
  sleep 0.5
  if focus_row '› routine'; then keys Enter; else bad "没能把焦点移到类别行"; fi
  if pty_wait_frame "$tmp/$current/policy-picker.txt" "类别 picker" "╭─ routine" "输入其它值"; then
    ok "类别 picker 打开（标题点名类别 + 自由输入项）"
  else
    bad "类别 picker 没有打开"
  fi
  cap_to policy-picker
  assert_has "$tmp/$current/policy-picker.txt" "kimi-coding/k3-256k · 当前" "picker 标出策略的当前值"
  assert_has "$tmp/$current/policy-picker.txt" "xai/grok-4.6" "picker 列出项目自己的已知模型"
  assert_not "$tmp/$current/policy-picker.txt" "移除" "类别 picker 没有移除项（写者没有删除操作，面板不发明它）"
  local pol_sha pol_audit pol_argv pol_pid_args pol_record
  pol_sha="$(sha "$(cfg)")"; pol_audit="$(audit_lines)"; pol_argv="$(argv_count)"
  pol_record="$(sha "$state/dev.env")"
  pol_pid_args="$(tr '\0' ' ' < "/proc/$(panel_pid)/cmdline" 2>/dev/null || true)"
  cp "$(cfg)" "$tmp/$current/before-cat.cfg"
  pick_option 'xai/grok-4.6' || bad "picker 里没有 xai/grok-4.6"
  if wait_cap policy-written "已保存routine模型"; then
    ok "类别直写的回执"
  else
    bad "类别直写的回执没有出现"
  fi
  cap_to policy-written
  assert_not "$tmp/$current/policy-written.txt" "确认：" "值条目直写没有确认帧"
  assert_has "$tmp/$current/policy-written.txt" "新任务生效" "回执说明只影响以后派的新任务"
  argv_since "$pol_argv" "$tmp/$current/policy-argv.log"
  assert_match "$tmp/$current/policy-argv.log" 'config set-task-model routine xai/grok-4.6 --actor panel --dry-run --fingerprint [0-9a-f]{64}' "argv 记录 set-task-model --dry-run"
  assert_match "$tmp/$current/policy-argv.log" 'config set-task-model routine xai/grok-4.6 --actor panel --yes --fingerprint [0-9a-f]{64}' "argv 记录 set-task-model 的写入"
  assert_not "$tmp/$current/policy-argv.log" "set-agent-model" "argv 里没有退休的席位写入"
  assert_eq "类别写入审计长一行" "$(audit_lines)" "$((pol_audit + 1))"
  assert_match "$(cfg)" '^TEAM_TASK_MODELS=.*routine=xai/grok-4.6' "契约里类别映射落盘（完整三段 id 逐字）"
  assert_has "$(cfg)" "xai/grok-4.6" "契约里写的是完整 id"
  assert_eq "契约只改了一行" "$(diff "$tmp/$current/before-cat.cfg" "$(cfg)" | grep -c '^[<>]' || true)" "2"
  assert_match "$(cfg)" "^TEAM_PM_MODEL=" "PM 行没有被类别写碰"
  assert_eq "派单记录 state/dev.env 未被碰" "$(sha "$state/dev.env")" "$pol_record"
  assert_not "$tmp/$current/policy-argv.log" "dispatch" "写入窗口里没有 dispatch"
  assert_not "$tmp/$current/policy-argv.log" "resume" "写入窗口里没有 resume"
  assert_not "$tmp/$current/policy-argv.log" "restart" "写入窗口里没有 restart"
  assert_eq "面板进程 argv 不变（没有重启）" "$(tr '\0' ' ' < "/proc/$(panel_pid)/cmdline" 2>/dev/null || true)" "$pol_pid_args"
}

scn_categories() {
  section "categories · picker 条目与取消 / PM 编辑 / 陈旧指纹 / 删类别后的保留恢复 / 遗留配置 / 无 spawn（P232）"
  server_up categories "dev verify"
  policy_new 'routine=kimi-coding/k3-256k analysis=openai-codex/gpt-5.6-terra:xhigh verify=deepseek/deepseek-flash' \
    'openai-codex/gpt-6.1-sol:high' || bad "策略升级事务没有跑通（见 $tmp/$current-upgrade.log）"
  record_fixture dev 'xai/grok-4.6' sid-dev-232 T232-x routine
  printf 'metadata_version=1\nproject=%s\nwindow=pm\nmodel=example/last-pm\nnonce=p471-fixture\ntime=2026-11-17T00:00:00Z\nmode=fresh\nresume_key=default\nidentity_via=provider,model,session_id\n' "$ROOT" > "$state/pm-launch.env"
  conf_set "lang=zh" "page=1" "activity=1" "mouse=1" "density=comfortable" "theme=auto"
  local scn_argv scn_windows
  scn_argv="$(argv_count)"
  start_panel
  scn_windows="$(tmux -L "$sock" list-windows -t "$sess" -F '#{window_name}' 2>/dev/null | sort | tr '\n' ',')"
  open_view
  # ① 类别 picker 的条目顺序（当前 → 已知模型（去重）→ 自由输入），没有任何移除/整映射组合项
  filter_clear
  sleep 0.5
  if focus_row '› routine'; then keys Enter; else bad "没能把焦点移到routine 行"; fi
  if pty_wait_frame "$tmp/$current/cat-picker.txt" "类别 picker" "╭─ routine" "输入其它值"; then
    ok "类别 picker 打开"
  else
    bad "类别 picker 没有打开"
  fi
  cap_to cat-picker
  assert_has "$tmp/$current/cat-picker.txt" "kimi-coding/k3-256k · 当前" "条目：策略当前值带「当前」标记"
  assert_not "$tmp/$current/cat-picker.txt" "routing=" "picker 不组合整张映射"
  local cat_sha cat_audit
  cat_sha="$(sha "$(cfg)")"; cat_audit="$(audit_lines)"
  # ② esc 取消：什么都不写、不留审计
  pty_key_when "类别 picker 的 esc" "╭─ routine" Escape || bad "类别 picker 不在稳定帧上，esc 没有发"
  wait_row cat-picker-closed "一次 esc 关掉类别 picker" '!╭─ routine' '╭─ 项目设置' \
    || bad "一次 esc 没有关掉类别 picker"
  assert_not "$tmp/$current/cat-picker-closed.txt" "╭─ routine" "一次 esc 关掉 picker"
  assert_eq "取消后契约不变" "$(sha "$(cfg)")" "$cat_sha"
  assert_eq "取消后审计不增长" "$(audit_lines)" "$cat_audit"
  # ③ PM 编辑：自由输入 + 两次确认；回执点名 team up / fresh；一行 diff；argv 走 config set
  local pm_before; pm_before="$(grep '^TEAM_PM_MODEL=' "$(cfg)")"
  local pm_audit; pm_audit="$(audit_lines)"
  filter_to TEAM_PM_MODEL
  sleep 0.5
  keys Enter
  wait_picker TEAM_PM_MODEL '· 当前' || bad "PM 行的选择器没有打开"
  pick_option '输入其它值' || bad "PM 行没有自由输入项"
  wait_editor TEAM_PM_MODEL || bad "PM 行的编辑器没有打开"
  keys C-u; sleep 0.3
  type_text "kimi-coding/k3-256k"; sleep 0.4
  keys Enter
  if wait_cap pm-confirm "新值  kimi-coding/k3-256k"; then ok "PM 编辑先给确认行"; else bad "PM 的确认行没有出现"; fi
  keys Enter
  if wait_cap pm-written "已保存PM模型"; then ok "PM 编辑落盘"; else bad "PM 的写入回执没有出现"; fi
  cap_to pm-written
  assert_has "$tmp/$current/pm-written.txt" "fresh-pm" "PM 回执点名换模型的 fresh-pm 守卫"
  assert_match "$(argv_log)" 'config set TEAM_PM_MODEL kimi-coding/k3-256k --actor panel --dry-run --fingerprint [0-9a-f]{64}' "argv 记录 PM 的 --dry-run"
  assert_match "$(argv_log)" 'config set TEAM_PM_MODEL kimi-coding/k3-256k --actor panel --yes --fingerprint [0-9a-f]{64}' "argv 记录 PM 的写入"
  assert_eq "PM 写入审计长一行" "$(audit_lines)" "$((pm_audit + 1))"
  if [ "$(grep '^TEAM_PM_MODEL=' "$(cfg)")" != "$pm_before" ]; then
    ok "PM 行确实变了"
  else
    bad "PM 行没有变"
  fi
  assert_has "$(cfg)" "kimi-coding/k3-256k" "PM 的新模型在文件里"
  # ④ 陈旧指纹：picker 开着时另一个写者改契约 → accept 判冲突、对方字节保住、审计一行 conflict
  filter_clear
  sleep 0.5
  if focus_row '› analysis'; then keys Enter; else bad "没能把焦点移到analysis 行"; fi
  pty_wait_frame - "类别 picker（冲突用例）" "╭─ analysis" || bad "冲突用例的 picker 没有打开"
  printf '# other writer\n' >> "$(cfg)"
  local other_sha; other_sha="$(sha "$(cfg)")"
  pick_option 'deepseek/deepseek-flash' || bad "冲突用例的 picker 里没有 deepseek/deepseek-flash"
  if wait_cap cat-conflict "设置已被修改，未保存"; then ok "陈旧指纹被命令拒绝（回执点名冲突）"; else bad "陈旧指纹的冲突回执没有出现"; fi
  assert_eq "对方的字节被保住" "$(sha "$(cfg)")" "$other_sha"
  assert_match "$(audit_log)" 'result=conflict actor=panel key=TEAM_TASK_MODELS' "审计增了一行 conflict（actor=panel）"
  # ⑤ 删掉未来类别：策略行消失，已提交记录的模型/SID 原样保留（恢复不看映射成员）
  ( cd "$ROOT" && bash "$skill/scripts/team" config set TEAM_TASK_MODELS 'analysis=openai-codex/gpt-5.6-terra:xhigh verify=deepseek/deepseek-flash' --yes ) >/dev/null 2>&1 \
    || bad "整映射删除 routine 失败"
  reopen_view
  open_secondary records
  filter_to dev
  wait_row cat-kept "删类别后 dev 的派单行仍在" 'xai/grok-4.6' '会话编号: sid-dev-232' \
    || bad "删类别后派单行没等到（超过等待上限）"
  assert_match "$tmp/$current/cat-kept.txt" 'dev +T232-x +xai/grok-4.6' "删类别后记录模型仍是记录里的值"
  assert_has "$tmp/$current/cat-kept.txt" "会话编号: sid-dev-232" "删类别后会话号原样"
  filter_clear
  pty_key_when "删类别后返回主设置" '╭─ 模型记录' Escape || bad "删类别后记录页不在屏幕上"
  pty_wait_frame - "删类别后主设置" '╭─ 项目设置' || bad "删类别后未回主设置"
  filter_clear
  cap_to cat-deleted
  assert_not "$tmp/$current/cat-deleted.txt" "routine" "被删的类别不再有策略行"
  assert_match "$tmp/$current/cat-deleted.txt" '(analysis|verify)' "其余类别照旧在策略块里"
  assert_match "$tmp/$current/cat-deleted.txt" '^│ ── 模型 ─+' "类别块本身还在（只删了 routine）"
  # PM记录只报告上次启动，不把未来策略当成运行模型。
  open_secondary records
  filter_to PM上次启动
  wait_row pm-record "上次PM记录与未来策略分离" "PM上次启动" "example/last-pm" || bad "PM上次启动记录缺失"
  keys Enter
  wait_row pm-record-detail "原PM启动字段" "2026-11-17T00:00:00Z" "全新启动" || bad "PM启动详细字段缺失"
  keys Escape; sleep 0.4
  filter_clear; keys Escape; sleep 0.4
  # ⑥ 无 spawn/重启：整段没有任何 dispatch/resume/restart，窗口集合不变
  argv_since "$scn_argv" "$tmp/$current/categories-argv.log"
  assert_not "$tmp/$current/categories-argv.log" "dispatch" "整个场景没有 dispatch"
  assert_not "$tmp/$current/categories-argv.log" "resume" "整个场景没有 resume"
  assert_not "$tmp/$current/categories-argv.log" "restart" "整个场景没有 restart"
  assert_not "$tmp/$current/categories-argv.log" "set-agent-model" "整个场景没有退休的席位写入"
  assert_eq "tmux 窗口集合不变（没有 spawn 席位）" \
    "$(tmux -L "$sock" list-windows -t "$sess" -F '#{window_name}' 2>/dev/null | sort | tr '\n' ',')" "$scn_windows"
  # 遗留配置保留完整诊断/修复路径，但退休键没有编辑行。
  server_up categories-legacy "dev verify"
  printf "\nTEAM_DEFAULT_MODEL=example/legacy\n" >> "$(cfg)"
  start_panel; open_view
  wait_row legacy "真实迁移诊断" "配置需要更新" "含退休键" || bad "迁移诊断未显示"
  focus_row '› .*upgrade-models' || bad "迁移命令行不可达"
  keys Enter
  wait_row legacy-detail "完整迁移路线" "upgrade-models" "--task-models" "--dry-run" || bad "迁移路线不可达"
  cap_to legacy-detail
  keys Escape; sleep 0.4
  filter_to TEAM_DEFAULT_MODEL; cap_to legacy-key
  assert_has "$tmp/$current/legacy-key.txt" "TEAM_DEFAULT_MODEL" "诊断保留原退休键事实"
  assert_no_match "$tmp/$current/legacy-key.txt" '^│ [› ] TEAM_DEFAULT_MODEL +' "退休键没有编辑行"
  assert_not "$tmp/$current/legacy-key.txt" "set-agent-model" "没有退休写路线"
}

scn_flip() {
  section "flip · 写入路由改成席位写入 / 把未来策略当实际显示 → policy 段必须红；还原 → 绿（P232 对抗控制）"
  local ft="$tmp/flip"
  mkdir -p "$ft"
  cp "$panel" "$ft/panel-route.js"
  cp "$panel" "$ft/panel-actual.js"
  python3 - "$ft/panel-route.js" "$ft/panel-actual.js" <<'PYPATCH'
import sys
route, actual = sys.argv[1], sys.argv[2]
s = open(route, encoding='utf-8').read()
old = '"config","set-task-model"'
assert old in s, "找不到面板的 set-task-model 路由字节"
open(route, 'w', encoding='utf-8').write(s.replace(old, '"config","set-agent-model"', 1))
a = open(actual, encoding='utf-8').read()
old2 = 'B.assigned?B.model||J.dash:B.record_present===!1?J.settingsAssignmentNone:J.settingsAssignmentUnreadable'
assert a.count(old2) == 1, "找不到唯一派单行的显示规则字节"
open(actual, 'w', encoding='utf-8').write(a.replace(old2, 'I.blocks.settings.models.policy.categories[0].model', 1))
PYPATCH
  # 红侧 ①：面板的写入路由改成退休的席位写入 → 写路径的 argv 断言必须红
  TEAM_P21_PANEL="$ft/panel-route.js" bash "$here/panel-p21.sh" policy > "$tmp/flip-route-red.log" 2>&1
  local rc_red=$?
  if [ "$rc_red" -eq 1 ] && grep -a '✗' "$tmp/flip-route-red.log" | grep -q 'set-task-model'; then
    ok "红侧①：路由改成席位写入后 argv 断言红且点名 set-task-model（rc=$rc_red）"
  else
    bad "红侧①：路由改了却没人红（rc=$rc_red）"
  fi
  # 红侧 ②：把未来策略的模型当实际显示 → 策略/实际分离的断言必须红
  TEAM_P21_PANEL="$ft/panel-actual.js" bash "$here/panel-p21.sh" policy > "$tmp/flip-actual-red.log" 2>&1
  rc_red=$?
  if [ "$rc_red" -eq 1 ] && grep -a '✗' "$tmp/flip-actual-red.log" | grep -q '策略'; then
    ok "红侧②：把策略模型当实际显示后分离断言红且点名策略（rc=$rc_red）"
  else
    bad "红侧②：显示规则改了却没人红（rc=$rc_red）"
  fi
  # 绿侧：真树的 bundle（两个靶子的字节都还原）跑同一段必须全绿
  bash "$here/panel-p21.sh" policy > "$tmp/flip-green.log" 2>&1
  local rc_green=$?
  [ "$rc_green" -eq 0 ] && ok "绿侧：真树 bundle 跑 policy 段全绿" || bad "绿侧：真树也红了（rc=$rc_green）"
  { grep -a '== 结果 ==' "$tmp/flip-route-red.log" || true; } | grep -q '✗ 0$' && bad "红侧①的结果行是全绿（判据没抓住破坏）" || ok "红侧①的结果行确实不是全绿"
  printf '    --- 红侧①尾部 ---\n'
  { grep -aE '✗|== 结果' "$tmp/flip-route-red.log" || true; } | tail -5 | sed 's/^/    /'
  printf '    --- 红侧②尾部 ---\n'
  { grep -aE '✗|== 结果' "$tmp/flip-actual-red.log" || true; } | tail -5 | sed 's/^/    /'
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
  open_secondary records
  local records_before; records_before="$(sha "$(cfg)")"
  keys Enter; sleep 0.4; keys Escape; sleep 0.4
  assert_eq "记录打开与返回不写配置" "$(sha "$(cfg)")" "$records_before"
  keys Escape; sleep 0.4
  open_secondary commands
  filter_to TEAM_GATES
  sleep 0.5
  keys Enter
  wait_editor TEAM_GATES "true" || bad "readonly 用例的编辑器没有打开"
  type_text "changed"
  sleep 0.3
  # The three unwind escs are the test action, but each is still state-checked (M59): a drifted
  # scene gets a named red instead of a blind key closing whatever happens to be on screen.
  leave_editor TEAM_GATES || bad "readonly：编辑器 esc 后还在"
  filter_clear
  pty_key_when "readonly 返回主设置" '╭─ 项目命令' Escape || bad "readonly：命令页不在屏幕上"
  pty_wait_frame - "readonly 主设置" '╭─ 项目设置' || bad "readonly：未回主设置"
  filter_clear
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

  # ── P318（D-3）：未绑定键扫一遍 ───────────────────────────────────────────────────────────────
  # 键打完之后**除控制台自己的三个文件之外**零写入；再加一条正向对照，证明这个签名不是恒真。
  local sweep_before sweep_after
  sweep_before="$(sweep_manifest)"
  sweep_keys
  sleep 0.6
  sweep_after="$(sweep_manifest)"
  if [ "$sweep_after" = "$sweep_before" ]; then
    ok "未绑定键扫一遍：除控制台自己的三个文件外，state / docs / 契约零改动"
  else
    bad "未绑定键扫一遍：控制台动了别人的文件：$(diff <(printf '%s\n' "$sweep_before") <(printf '%s\n' "$sweep_after") | sed -n 's/^[<>] //p' | awk '{print $1}' | sort -u | tr '\n' ' ')"
  fi
  # 正向对照（与 D-2 同一口径：仪器不许静默瞎掉）：在允许集之外造一次写入，同一个 sweep_manifest 必须看见。
  : > "$state/zz-p318-probe"
  assert_eq "正向对照：sweep_manifest 看得见允许集之外的写入" \
    "$([ "$(sweep_manifest)" = "$sweep_before" ] && echo blind || echo sees)" "sees"
  rm -f "$state/zz-p318-probe"
  if pty_wait_frame "$tmp/$current/readonly-sweep.txt" "未绑定键之后控制台还在" 'teamsmith pulse'; then
    ok "未绑定键扫一遍之后控制台仍是活的（帧还在画）"
  else
    bad "未绑定键扫一遍之后控制台不在了（某个键被当成了动作）"
  fi
}

# ---------------------------------------------------------------- P30（settings-view-groups）

# P32：分组标题是**分节线**（`│ ── 身份与账本布局 ─────… │`），不再是缩进的文本行 —— 所以
# 「这一行恰好等于标题词」不再是标题的判据。这里找的是带分节线的标题行；返回行号（0 = 找不到）。
cap_line_heading() { # <file> <label>
  python3 - "$1" "$2" <<'PY'
import sys
lines = open(sys.argv[1], encoding='utf-8', errors='replace').read().split('\n')
label = sys.argv[2]
for i, line in enumerate(lines):
    if line.startswith('\u2502') and label in line and '\u2500' in line:
        print(i + 1)
        break
else:
    print(0)
PY
}

# P32：标题可辨认 + 组间可见分隔（两条断言合一）。标题行必须是分节线，且它的上一行是上一组的
# 最后一条、下一行是本组的第一条 —— 标题自己承担分隔，不另花一行。
assert_heading_rule() { # <file> <label> <上一组最后一条> <本组第一条> <message>
  local msg="$5" out rc
  out="$(python3 - "$1" "$2" "$3" "$4" <<'PY'
import sys
cap, label, before, after = sys.argv[1:5]
lines = open(cap, encoding='utf-8', errors='replace').read().split('\n')
hit = [i for i, l in enumerate(lines) if l.startswith('\u2502') and label in l and '\u2500' in l]
if not hit:
    print('%r 不是分节线标题（没有带 ─ 的标题行）' % label); sys.exit(1)
i = hit[0]
prev = lines[i - 1] if i > 0 else ''
nxt = lines[i + 1] if i + 1 < len(lines) else ''
if before not in prev:
    print('标题上一行不是上一组的最后一条（%r 不在 %r）' % (before, prev.strip('\u2502 ').rstrip())); sys.exit(1)
if after not in nxt:
    print('标题下一行不是本组的第一条（%r 不在 %r）' % (after, nxt.strip('\u2502 ').rstrip())); sys.exit(1)
print('%s 是分节线标题，夹在 %s 与 %s 之间' % (label, before, after))
PY
)"
  rc=$?
  if [ "$rc" -eq 0 ]; then ok "$msg（$out）"; else bad "$msg：$out"; fi
}

# P32：把设置视图的**可见**面板缩到 <cols>×<rows>（会话是 window-size manual，所以窗口随我们），
# 并等到 tmux 报出这个 pane 高度 —— 之后 capture-pane（不带 -S）的每一行就是屏幕上的每一行。
resize_panel() { # <cols> <rows>
  tmux -L "$sock" resize-window -t "$sess:panel" -x "$1" -y "$2" 2>/dev/null || true
  local i h
  for i in $(seq 1 25); do
    h="$(tmux -L "$sock" display-message -p -t "$sess:panel" '#{pane_height}' 2>/dev/null)"
    [ "$h" = "$2" ] && return 0
    sleep 0.2
  done
  return 1
}

# P32：缩完 tmux 可能裁剪旧画面；两次截图一致还不够。保留可见帧，只有当前设置卡片、焦点和
# 专用键栏都完整时才返回可见/隐藏行数及卡片外空行；读不到就返回失败，不产生行数。
wait_settings_frame() { # <rows> <cap name> <title> <focused label>
  local rows="$1" file="$tmp/$current/$2.txt" title="$3" focus="$4" i a b stats
  for i in $(seq 1 30); do
    a="$(cap_now | sed -E 's/[0-9]{2}:[0-9]{2}:[0-9]{2}/HH:MM:SS/g')" || continue
    sleep 0.25
    b="$(cap_now)" || continue
    printf '%s\n' "$b" > "$file"
    [ "$(printf '%s\n' "$b" | sed -E 's/[0-9]{2}:[0-9]{2}:[0-9]{2}/HH:MM:SS/g')" = "$a" ] || continue
    if stats="$(settings_window_stats "$file" "$rows" "$title" "$focus")"; then
      printf '%s\n' "$stats"
      return 0
    fi
  done
  return 1
}

settings_window_stats() { # <file> <height> <title> <focus> → visible above below gap
  python3 - "$@" <<'PY'
import re, sys
path, height, title, focus = sys.argv[1:]
with open(path, encoding='utf-8') as f:
    lines = [line.rstrip() for line in f]
if len(lines) != int(height):
    sys.exit(1)
top = next((i for i, l in enumerate(lines) if re.fullmatch(r'╭─ ' + re.escape(title) + r' ─+╮', l)), -1)
bot = next((i for i, l in enumerate(lines) if i > top and re.fullmatch(r'╰─+╯', l)), -1)
keys = r'Esc 返回 · ↑/↓ 行 · Enter (?:编辑|打开) · / 筛选|Esc back · ↑/↓ rows · Enter (?:edit|open) · / filter'
foot = next((i for i, l in enumerate(lines) if i > bot and re.fullmatch(keys, l.strip())), -1)
body = lines[top + 1:bot]
if not (0 <= top < bot < foot) or not all(l.startswith('│') and l.endswith('│') for l in body):
    sys.exit(1)
if not any(l.startswith(f'│ › {focus} ') for l in body):
    sys.exit(1)
rows = up = down = 0
for line in body:
    text = line[1:-1].strip()
    m = re.fullmatch(r'([↑↓])(\d+)', text)
    if m:
        if m[1] == '↑': up = int(m[2])
        else: down = int(m[2])
    elif re.match(r'^│ [› ] [^\s│]', line):
        rows += 1   # cursor column; headings, hint text and blank fill use different prefixes
print(rows, up, down, foot - bot - 1)
PY
}

# 含 <text> 的第一行行号（0 = 找不到）。
cap_line_of() { # <file> <substring>
  local n
  n="$(grep -nF -- "$2" "$1" 2>/dev/null | head -1 | cut -d: -f1)"
  printf '%s\n' "${n:-0}"
}

# P68/fixture-waits-for-landed-reads：等含 <needle> 的那一行行号**超过** <阈值>（滚轮把光标推下去）。
# 这是交互重绘的等待（不是异步读），但守同一套纪律：计数轮 + 上界 + 耗尽时一行归因（等待名/轮数/最后读数）。
# 上界 15 轮 ×（轮询 0.25s + 稳定确认 0.25s）≈ 7s；原来是一个固定 sleep + 单次采样。
wait_line_gt() { # <name> <label> <needle> <threshold>
  local _name="$1" _label="$2" _needle="$3" _thr="$4" _i=1 _c _line
  while [ "$_i" -le 15 ]; do
    _c="$(cap)"
    printf '%s\n' "$_c" > "$tmp/$current/$_name.txt"
    _line="$(cap_line_of "$tmp/$current/$_name.txt" "$_needle")"
    if [ "${_line:-0}" -gt "$_thr" ] && pty_frame_settled "$_c"; then return 0; fi
    sleep 0.25
    _i=$((_i + 1))
  done
  printf '  \033[33m·\033[0m 等待超时：%s（%s 轮/%s；等 [%s] 的行号 > %s，最后读到 %s）\n' \
    "$_label" "$((_i - 1))" 15 "$_needle" "$_thr" "${_line:-?}" >&2
  return 1
}

# The same capture with SGR runs (`capture-pane -e`): tmux restores each cell's truecolor
# sequence, which is what the tone assertion reads (without rebuilding the bundle by hand).
assert_no_match() { # <file> <ere> <message>
  grep -qE -- "$2" "$1" 2>/dev/null && bad "$3（不该匹配 [$2]）" || ok "$3"
}

scn_groups() {
  section "groups · 用途标题/源顺序类别/非交互标题/新键隐藏/保留键权限"
  server_up groups
  policy_new 'custom=example/custom routine=example/one verify=example/two' 'example/pm' || bad "策略准备失败"
  start_panel; open_view
  cap_to view
  assert_has "$tmp/$current/view.txt" "模型" "第一用途模型"
  assert_heading_rule "$tmp/$current/view.txt" "自动检查" "模型同时运行任务数" "检查间隔" "两个用途用分节线隔开"
  assert_no_class_heading "$tmp/$current/view.txt"
  assert_match "$tmp/$current/view.txt" '› custom +example/custom' "自定义类别按源顺序先显示"
  keys Down
  wait_row next-category "标题不是焦点停点" "› routine" || bad "类别焦点越过标题失败"
  cap_to order
  assert_match "$tmp/$current/order.txt" '› routine' "第二类别是实际源的routine"
  local before y
  before="$(sha "$(cfg)")"; y="$(cap_line_heading "$tmp/$current/view.txt" 模型)"
  click_at 8 "$y"; sleep 0.4; cap_to heading-click
  assert_match "$tmp/$current/heading-click.txt" '› routine' "标题不是点击目标"
  assert_eq "标题点击不写" "$(sha "$(cfg)")" "$before"
  local scratch="$tmp/$current/scratch"
  mkdir -p "$scratch/skills/teamsmith"
  cp -a "$skill/scripts" "$scratch/skills/teamsmith/scripts"
  cp -a "$skill/templates" "$skill/references" "$scratch/skills/teamsmith/"
  python3 - "$scratch/skills/teamsmith/scripts/lib/cmd-config.sh" <<'PYCFG' || { bad "未能在副本里准备 CLI 分组变更"; return 1; }
import re, sys
p=sys.argv[1]; s=open(p).read()
gates='TEAM_GATES|apply|cmd||plain||-|||workflow'; assert gates in s
s=s.replace(gates,'TEAM_GATES|refuse|cmd||plain||-|change acceptance in config||meeting')
s, moved = re.subn(r'^(TEAM_PULSE_INTERVAL\|[^\n]+)\|panel$', r'\1|meeting', s, flags=re.M)
assert moved == 1, '预期仅修改检查间隔的 CLI 分组'
anchor='TEAM_INSTALL_CMD|apply|cmd||plain||-|||workflow'; assert anchor in s
assert '|p492-hidden\n' not in s
s=s.replace(anchor,'TEAM_ZZZ_TEST|apply|text||plain|zzz|-|||p492-hidden\n'+anchor)
# 取消fixture标记也不能使未精选键变成操作。
s=s.replace('fixture-only: 只在测试套件里用（磁盘读数夹具）','')
open(p,'w').write(s)
PYCFG
  cat > "$tmp/$current-scratch-wrapper.sh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$tmp/$current-scratch-argv.log"
exec bash "$scratch/skills/teamsmith/scripts/team" "\$@"
EOF
  chmod +x "$tmp/$current-scratch-wrapper.sh"
  P21_CLI="$tmp/$current-scratch-wrapper.sh" start_panel
  open_view || return 1
  wait_row changed-groups "CLI 分组变化后的设置首页" "╭─ 项目设置" "› custom" "自动检查" "检查间隔" || { bad "修改 CLI 分组后的设置首页未读到"; return 1; }
  assert_heading_rule "$tmp/$current/changed-groups.txt" "自动检查" "模型同时运行任务数" "检查间隔" "CLI 分组变化不移动检查间隔"
  assert_eq "未展示的 CLI 分组不增加用途标题" "$(grep -c '^│ ── ' "$tmp/$current/changed-groups.txt")" "2"
  for k in TEAM_ZZZ_TEST TEAM_DISK_STATS_FILE; do
    filter_to "$k"; cap_to "$k"
    assert_no_match "$tmp/$current/$k.txt" '^│ [› ] [^│]*[^[:space:]│]' "新键或取消标记不会自动显示（$k）"
  done
  open_secondary commands
  filter_to TEAM_GATES
  wait_row permission "保留键仍跟源权限/route" "验收命令" "change acceptance in config" || bad "原权限/route未显示"
  local h; h="$(sha "$(cfg)")"
  keys Enter
  wait_cap refused "change acceptance in config" || bad "refuse没有真实route"
  assert_eq "refuse没有写" "$(sha "$(cfg)")" "$h"
  cap_to refusal
  assert_not "$tmp/$current/refusal.txt" "Enter 继续" "refuse没有可写输入"
  unset P21_CLI
}

scn_wheel_settings() {
  section "wheel · 设置视图自己的窗口（P30/D5）：一格一行/焦点不动/计数行跟随/不穿透页面/焦点推窗/两个 picker"
  server_up settings-wheel
  # P232：类别 picker 用例要有类别可开。
  policy_new 'routine=kimi-coding/k3-256k analysis=openai-codex/gpt-5.6-terra:xhigh' 'openai-codex/gpt-6.1-sol:high' \
    || bad "策略升级事务没有跑通"
  local map='routine=kimi-coding/k3-256k analysis=openai-codex/gpt-5.6-terra:xhigh' k
  for k in $(seq 1 60); do map="$map cat$k=example/model$k"; done
  policy_new "$map" 'openai-codex/gpt-6.1-sol:high' || bad "长列表准备失败"
  # 页面（page 3 的巡检块）要真的滚得动，「页面没被穿透」才有可观察的对照：写满 12 行巡检日志。
  mkdir -p "$state"
  python3 - "$state/watchdog.log" <<'PY'
import sys
with open(sys.argv[1], 'w', encoding='utf-8') as f:
    for i in range(1, 13):
        f.write('P-%02d patrol tick marker\n' % i)
PY
  conf_set "lang=zh" "page=3" "activity=1" "mouse=1" "density=comfortable" "theme=auto"
  start_panel
  # ① 页面自己的滚轮还活着（对照 + 不回归钉）：先滚 3 格，P-01 出屏、P-04 进屏。
  wheel_at down 100 8 3
  # P68：等页面滚动的结果（P-04 进屏、P-01 出屏）在稳定帧上，不用固定 sleep 采样。
  wait_row page-scrolled "页面滚轮 3 格后的巡检窗口" 'P-04' '!P-01' \
    || bad "页面滚轮 3 格后的窗口没有落定（P-04 未进屏或 P-01 未出屏）"
  assert_not "$tmp/$current/page-scrolled.txt" "P-01" "页面滚轮 3 格：P-01 已出屏（页面确实滚得动）"
  assert_has "$tmp/$current/page-scrolled.txt" "P-04" "页面滚轮 3 格：P-04 进屏"
  # ② 视图里的滚轮：一格一行、焦点不动、顶部计数行跟随（先下滚 3 格，再上滚回顶部）。
  open_view
  cap_to wheel-before
  assert_match "$tmp/$current/wheel-before.txt" '› routine +kimi-coding/k3-256k' "视图开屏焦点在第一个任务类别"
  wheel_at down 20 10 3
  local i
  for i in $(seq 1 20); do
    cap_to wheel-down
    grep -qE '↑3' "$tmp/$current/wheel-down.txt" && break
    sleep 0.25
  done
  assert_match "$tmp/$current/wheel-down.txt" '↑3' "下滚 3 格：顶部计数行读出 ↑3（窗口正好移 3 行）"
  assert_not "$tmp/$current/wheel-down.txt" "routine" "下滚 3 格：原本第一行（routine）已出窗"
  assert_has "$tmp/$current/wheel-down.txt" "cat2" "下滚 3 格：后面的行进窗（窗口第一行 = 第 4 条）"
  assert_no_match "$tmp/$current/wheel-down.txt" '›' "下滚 3 格：焦点没动（光标落在已出窗的routine上，窗口里没有光标行）"
  assert_has "$tmp/$current/wheel-down.txt" "新任务生效" "下滚 3 格：命令行提示仍在"
  wheel_at up 20 10 3
  for i in $(seq 1 20); do
    cap_to wheel-up
    grep -qE '↑[0-9]+' "$tmp/$current/wheel-up.txt" || break
    sleep 0.25
  done
  assert_match "$tmp/$current/wheel-up.txt" '› routine' "上滚 3 格：窗口回到顶部，第一行回来"
  assert_no_match "$tmp/$current/wheel-up.txt" '↑[0-9]+' "上滚 3 格：顶部计数行消失"
  # ③ 焦点键把窗口推到聚焦行（滚开之后 enter 打开的就是命令行点名的那一行）。
  wheel_at down 20 10 3
  for i in $(seq 1 20); do
    cap_to wheel-push-pre
    grep -qE '↑3' "$tmp/$current/wheel-push-pre.txt" && break
    sleep 0.25
  done
  keys Down
  # P68：等窗口被推到聚焦行（↑1 + 光标在analysis）在稳定帧上，不用固定 sleep 采样。
  wait_row wheel-push "↓ 之后窗口被推到聚焦行（↑1 + › analysis）" '↑1' '› analysis' \
    || bad "↓ 之后窗口没有被推到聚焦行上"
  assert_match "$tmp/$current/wheel-push.txt" '↑1' "↓ 之后窗口被推到聚焦行上（顶部计数行 = ↑1）"
  assert_match "$tmp/$current/wheel-push.txt" '› analysis' "光标落在下一条（analysis）"
  assert_has "$tmp/$current/wheel-push.txt" "新任务生效" "命令行提示与光标同一屏（焦点在analysis上）"
  keys Up
  # `↑` 计数行消失（字面 needle：`!↑1` = 刚才那条 ↑1 不再在屏幕上；pty-wait 是 grep -F，不吃正则，
  # 所以不能用原断言的 `↑[0-9]+`；下面的 assert_no_match 仍守住正则面）。
  wait_row wheel-push-back "↑ 之后窗口回到顶部（↑1 计数行消失）" '› routine' '!↑1' \
    || bad "↑ 之后窗口没有回到顶部"
  assert_match "$tmp/$current/wheel-push-back.txt" '› routine' "↑ 之后光标回到第一条"
  assert_no_match "$tmp/$current/wheel-push-back.txt" '↑[0-9]+' "窗口跟着回到顶部（计数行消失）"
  keys Enter
  wait_picker routine "kimi-coding/k3-256k" || bad "Enter没有打开聚焦类别"
  leave_picker routine || bad "类别picker未返回"
  # ④ 选择器开着时滚轮走条目、页面不动；esc 之后选择器是关着的（一次 esc 就够）。
  filter_to TEAM_PULSE_INTERVAL
  sleep 0.5
  keys Enter
  wait_picker TEAM_PULSE_INTERVAL '300' || bad "选择器没有打开（滚轮用例前提）"
  cap_to picker-wheel-before
  local sel_before sel_after
  sel_before="$(cap_line_of "$tmp/$current/picker-wheel-before.txt" '›')"
  wheel_at down 20 12 2
  # P68：等选中行真的被滚轮推下去（计数轮 + 上界 + 归因），不用固定 sleep 采样。
  wait_line_gt picker-wheel-after "选择器滚轮把选中行推下去" '›' "${sel_before:-0}" \
    || bad "选择器里的滚轮没有走条目（选中行停在 $sel_before）"
  sel_after="$(cap_line_of "$tmp/$current/picker-wheel-after.txt" '›')"
  if [ "$sel_before" -gt 0 ] && [ "$sel_after" -gt "$sel_before" ]; then
    ok "选择器开着时滚轮走条目（选中行 $sel_before → $sel_after）"
  else
    bad "选择器里的滚轮没有走条目（选中行 $sel_before → $sel_after）"
  fi
  pty_key_when "选选择器的 esc" '╭─ 检查间隔' Escape || bad "选择器不在稳定帧上，esc 没有发"
  # P68：等 esc 的效果（选择器关掉、仍在设置视图里）在稳定帧上。
  wait_row picker-closed "一次 esc 关掉选择器且仍在设置视图里" '!╭─ 检查间隔' '╭─ 项目设置' \
    || bad "一次 esc 没有关掉选择器（或不在设置视图里了）"
  assert_not "$tmp/$current/picker-closed.txt" "╭─ 检查间隔" "一次 esc 就把选择器关掉（不穿透）"
  assert_has "$tmp/$current/picker-closed.txt" "╭─ 项目设置" "关闭后仍在设置视图里"
  # ⑤ 类别 picker 走同一套 widget（条目滚动已在 ④ 证过）。P232：席位 picker 随席位模型一起退休，
  #    类别 picker 是它的接任者 —— 这里守两件事：它自己的条目列表在滚轮下会走，且页面不因此滚动
  #    （⑥ 关掉视图后仍断言页面停在这一屏）。
  filter_to routine
  if focus_row '› routine'; then
    keys Enter
  else
    bad "没能把焦点移到routine 行"
  fi
  # 类别 picker 的首屏用类别作标题，并标明当前模型。
  if pty_wait_frame "$tmp/$current/cat-picker.txt" "类别 picker" "╭─ routine" "· 当前"; then
    ok "类别 picker 打开（标题 + 当前项）"
  else
    bad "类别 picker 没有打开"
  fi
  cap_to cat-wheel-before
  sel_before="$(cap_line_of "$tmp/$current/cat-wheel-before.txt" '›')"
  wheel_at down 20 12 2
  sleep 0.6
  cap_to cat-wheel-after
  assert_has "$tmp/$current/cat-wheel-after.txt" "╭─ routine" "滚轮之后类别 picker 还开着（没穿透）"
  pty_key_when "类别 picker 的 esc" '╭─ routine' Escape || bad "类别 picker 不在稳定帧上，esc 没有发"
  # P68：等类别 picker 关掉（仍在设置视图里）在稳定帧上。
  wait_row cat-picker-closed "一次 esc 关掉类别 picker" '!╭─ routine' '╭─ 项目设置' \
    || bad "一次 esc 没有关掉类别 picker"
  assert_not "$tmp/$current/cat-picker-closed.txt" "╭─ routine" "一次 esc 关掉类别 picker"
  # ⑥ 回到页面：视图把滚轮吃掉了 —— 页面还是进视图前的那一屏（P-01 出屏、P-04 可见）。
  filter_clear
  pty_key_when "关设置视图" '╭─ 项目设置' Escape || bad "关闭视图前它不在稳定帧上"
  # P68：等浮层自己回到稳定帧上再发第二个 esc（原来是两个固定 sleep 给按键让路）。
  pty_wait_frame - "关设置视图后的浮层" '› 项目设置' '!╭─ 项目设置' \
    || bad "关掉设置视图后浮层没有回到「项目设置」那行"
  pty_key_when "关浮层" '项目设置' Escape || bad "浮层不在稳定帧上"
  # P68：等回到页面的那一屏（仍是进视图前那一屏）在稳定帧上。
  wait_row page-back "回到页面：仍是进视图前那一屏（P-04 可见、P-01 出屏）" '!P-01' 'P-04' \
    || bad "回到页面后那一屏变了"
  assert_not "$tmp/$current/page-back.txt" "P-01" "视图里的滚轮没有穿透页面（P-01 仍在屏外）"
  assert_has "$tmp/$current/page-back.txt" "P-04" "页面窗口还是进视图前的那一屏（P-04 仍可见）"
}

# ---------------------------------------------------------------- run

printf '\033[1m== panel-p21 · 项目设置视图（P22） ==\033[0m\n'
for s in "${SECTIONS[@]}"; do
  mkdir -p "$tmp/$s"
  # 每个场景在自己的子 shell 里跑（父 shell 的 EXIT 清扫有自己的 BASHPID 守卫，不会被重复触发）。
  (
    trap - EXIT INT TERM
    case "$s" in
      settings) scn_settings ;;
      groups) scn_groups ;;
      wheel) scn_wheel_settings ;;
      choices) scn_choices ;;
      choices-schema) scn_choices_schema ;;
      write) scn_write ;;
      conflict) scn_conflict ;;
      categories) scn_categories ;;
      policy) scn_policy ;;
      flip) scn_flip ;;
      readonly) scn_readonly ;;
      *) printf 'panel-p21: 未知场景 %s\n' "$s" >&2; exit 3 ;;
    esac
  )
  rc=$?
  case "$rc" in
    0) ;;
    3) exit 3 ;;                                          # 搭建失败（server_up/未知场景）
    *) ;;                                                 # 1 = 断言失败，最后按 FAIL 退出
  esac
done

PASS="$(p21_count_of "$_p21_count/ok")"
FAIL="$(p21_count_of "$_p21_count/bad")"
printf '\n\033[1m== 结果 ==\033[0m  ✓ %s  ✗ %s\n' "$PASS" "$FAIL"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
