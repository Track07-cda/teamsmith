#!/usr/bin/env bash
# panel-p21.sh — pty/tmux fixtures for the project-settings view (P22 / B2-B4).
# M59: every wait releases on a settled frame, every cleanup key is state-checked, and every
# failure carries its own scene — the mechanics live in tests/lib/pty-wait.sh (sourced below).
#
#   bash skills/teamsmith/tests/panel-p21.sh                  # every scenario
#   bash skills/teamsmith/tests/panel-p21.sh settings seats    # selected scenarios
#   bash skills/teamsmith/tests/panel-p21.sh settings groups wheel   # P30: grouping + the view's wheel
#   TEAM_P21_KEEP=1 bash ...                                  # keep the fixture directory
#
# Every scenario runs in a private tmux server and a fresh git project initialised with the real
# `team init`; the panel runs the **real** CLI through a logging wrapper (`argv.log`), so "the
# console writes only through the owning command" is checked against real argv, not a stub.
# Exit: 0 every selected scenario green, 1 at least one assertion failed, 3 setup failure,
#       4 a scenario was visibly SKIPPED (see the premise below): no failure, no conclusion.
#
# P48 / D33 — `panel#The project-settings pty fixture judges under a machine premise` (the gate
# rule is `verification#The correctness gate judges correctness only`): the wait horizons stay
# failure detectors, never judgments. Every scenario prints a **premise line** before its first
# assertion (real `loadavg_1m`/`loadavg_5m`, the logical core count and a **code-independent probe**
# — `python3 -c pass` + `bash -c true` + `git rev-parse`, in ms), and when a wait runs out of its
# (progress-extended) horizon the engine attributes the verdict from the machine's own readings:
# still painting / probe over its ceiling / load over the coarse guard -> one visible SKIP line and
# the scenario stops there (fixture exit 4, the gate stays 0); a static scene with the readings
# under their ceilings -> the ordinary red with its M59 scene (a regression is a code verdict).
# Constants and their measured bands: probe ceiling 120 ms (measured 12-34 ms across loadavg
# 8.4-42.4 on 32 cores), coarse load guard 2.0 x cores (the highest measured green load is 1.33 x
# cores) — both sit **outside** the band where this fixture judges. Re-derivation recipe:
# `tests/load-experiment.sh {storm,burn,probe}` (the safe harness: owned load, owned targets) +
# design.md §3/§4;  the raw calibration table is in docs/team/reports/P48-dev3.md.
#
# Fixture knobs (honoured **only** under `TEAM_SMOKE_FIXTURE=1`; otherwise printed as ignored and
# the real reading is used — the panel-cpu.sh precedent):
#   TEAM_P21_PREMISE_PROBE_MS=<ms>       inject the probe reading; over its ceiling the fixture also
#                                        injects the "the state never arrives" stall, so the
#                                        exhaustion path is reachable on a quiet host
#   TEAM_P21_PREMISE_LOADAVG=<n>         inject loadavg_1m
#   TEAM_P21_PREMISE_LOAD_FACTOR=<f>     inject the coarse entry guard's factor
#   TEAM_P21_PREMISE_PROBE_CEIL_MS=<ms>  inject the probe ceiling
#   TEAM_P21_STALL_ROUNDS=<n>            inject the progress window (PTY_STALL_ROUNDS)
#   TEAM_P21_STALL=1                     inject a needle that never appears (the exhaustion shape
#                                        on a healthy machine: it must stay a red, not a skip)
#   TEAM_P21_PREMISE_ONLY=1              print the premise line + the ignore notices, build no tmux
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
# P48: the premise knobs (and the fixture switch itself) are saved before the identity wipe, which
# would otherwise unset every TEAM_* — including TEAM_SMOKE_FIXTURE, the only switch that makes an
# injected reading count.
_smoke_fixture_arg="${TEAM_SMOKE_FIXTURE:-0}"
_premise_probe_arg="${TEAM_P21_PREMISE_PROBE_MS:-}"
_premise_load_arg="${TEAM_P21_PREMISE_LOADAVG:-}"
_premise_factor_arg="${TEAM_P21_PREMISE_LOAD_FACTOR:-}"
_premise_ceil_arg="${TEAM_P21_PREMISE_PROBE_CEIL_MS:-}"
_premise_stall_arg="${TEAM_P21_STALL_ROUNDS:-}"
_stall_arg="${TEAM_P21_STALL:-}"
_premise_only_arg="${TEAM_P21_PREMISE_ONLY:-0}"
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
SKIP=0
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

# ── 前提（P48 / D33，panel#The project-settings pty fixture judges under a machine premise）────
# 视界是失败探测器：等待耗尽那一刻由 tests/lib/pty-wait.sh 调 pty_premise_over（下面）按机器读数
# 归因 —— 超前提 → 一行可见 SKIP 并把当前场景停在原地（整体退出 4）；静态场景 + 前提之内 → 红。
# 前提本身在**入口不判定**（只有粗闸门跳过整体超载的机器），所以前提行只是把真读数打出来。
P21_PREMISE_PROBE_CEIL_MS_DEFAULT=120
P21_PREMISE_LOAD_FACTOR_DEFAULT=2.0
P21_PREMISE_REASON=""
P21_NOTICED=""
p21_fixture_on() { [ "${_smoke_fixture_arg:-0}" = "1" ]; }
p21_notice() { # 每个旋钮只打一次忽略行（同一个值会被几个读数点重复请求）
  case " ${P21_NOTICED:-} " in *" $1 "*) return 0 ;; esac
  P21_NOTICED="${P21_NOTICED:-} $1"
  printf '  忽略 %s=%s（只有 TEAM_SMOKE_FIXTURE=1 时夹具旋钮才生效；真实路径读真值）\n' "$1" "$2" >&2
}
p21_cores() { nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || printf '0'; }
p21_load5() { cut -d' ' -f2 /proc/loadavg 2>/dev/null || printf '?'; }
p21_load1() {
  if [ -n "${_premise_load_arg:-}" ]; then
    if p21_fixture_on; then printf '%s\n' "$_premise_load_arg"; return 0; fi
    p21_notice TEAM_P21_PREMISE_LOADAVG "$_premise_load_arg"
  fi
  cut -d' ' -f1 /proc/loadavg 2>/dev/null || printf '?'
}
# 代码无关探针（P44 的 probe.sh 口径）：只起进程，永远不碰面板；5 轮均值，毫秒。
p21_probe_ms() {
  local n=5 i t0
  t0="$(date +%s%3N)"
  for i in $(seq 1 "$n"); do
    python3 -c 'pass' >/dev/null 2>&1
    bash -c 'true' >/dev/null 2>&1
    git -C "$tree" rev-parse --quiet HEAD >/dev/null 2>&1
  done
  printf '%s\n' $(( ($(date +%s%3N) - t0) / n ))
}
p21_probe_reading() {
  if [ -n "${_premise_probe_arg:-}" ]; then
    if p21_fixture_on; then printf '%s\n' "$_premise_probe_arg"; return 0; fi
    p21_notice TEAM_P21_PREMISE_PROBE_MS "$_premise_probe_arg"
  fi
  p21_probe_ms
}
p21_factor() {
  if [ -n "${_premise_factor_arg:-}" ]; then
    if p21_fixture_on; then printf '%s\n' "$_premise_factor_arg"; return 0; fi
    p21_notice TEAM_P21_PREMISE_LOAD_FACTOR "$_premise_factor_arg"
  fi
  printf '%s\n' "$P21_PREMISE_LOAD_FACTOR_DEFAULT"
}
p21_probe_ceil() {
  if [ -n "${_premise_ceil_arg:-}" ]; then
    if p21_fixture_on; then printf '%s\n' "$_premise_ceil_arg"; return 0; fi
    p21_notice TEAM_P21_PREMISE_PROBE_CEIL_MS "$_premise_ceil_arg"
  fi
  printf '%s\n' "$P21_PREMISE_PROBE_CEIL_MS_DEFAULT"
}
p21_load_threshold() { awk -v c="$(p21_cores)" -v f="$(p21_factor)" 'BEGIN { printf "%.2f", f * c }'; }
p21_premise_line() { # <场景名>：真读数 + 两个顶（只打，不判）
  local label="${1:-?}" load1 load5 cores probe factor ceil
  load1="$(p21_load1)"; load5="$(p21_load5)"; cores="$(p21_cores)"
  probe="$(p21_probe_reading)"; factor="$(p21_factor)"; ceil="$(p21_probe_ceil)"
  printf '== 前提 %s：loadavg_1m %s / loadavg_5m %s · 逻辑核 %s · 代码无关探针 %sms（顶 %sms）· 粗闸门 %s = %s×%s 核 ==\n' \
    "$label" "$load1" "$load5" "$cores" "$probe" "$ceil" \
    "$(p21_load_threshold)" "$factor" "$cores"
}
# 入口粗闸门：0 = 前提之内（照跑）/ 1 = 负载超顶（在第一个等待之前 SKIP 整个场景）。
# 它故意取在实测绿带**之外**（最高实测绿 1.33×核），只是别在严重过载的宿主上白烧几分钟，
# 不是「绿/红交叉点」（P44 的结论：负载平均没有实测交叉点）。
p21_entry_guard() {
  local load1 cores thr
  load1="$(p21_load1)"; cores="$(p21_cores)"; thr="$(p21_load_threshold)"
  case "$cores" in ''|*[!0-9]*) return 0 ;; esac
  [ "$cores" -gt 0 ] || return 0
  if awk -v l="$load1" -v t="$thr" 'BEGIN { exit !(l <= t) }'; then return 0; fi
  return 1
}
p21_entry_skip_line() {
  printf '  \033[33mSKIP\033[0m 入口粗闸门：loadavg_1m %s > %s（%s×%s 核）—— 场景 %s 在第一个等待之前就停下（无失败、无结论，exit 4）\n' \
    "$(p21_load1)" "$(p21_load_threshold)" "$(p21_factor)" "$(p21_cores)" "${1:-?}"
}
# 引擎在耗尽那一刻调的两个钩子（tests/lib/pty-wait.sh）：超前提 → 引擎打 SKIP 行并调 pty_on_skip。
pty_on_skip() { exit 4; }
pty_premise_over() { # 0 = 机器超前提（归因给机器）/ 1 = 前提之内（代码判决）
  local load1 cores probe ceil thr factor
  load1="$(p21_load1)"; cores="$(p21_cores)"; probe="$(p21_probe_reading)"
  ceil="$(p21_probe_ceil)"; factor="$(p21_factor)"; thr="$(p21_load_threshold)"
  P21_PREMISE_REASON="loadavg_1m ${load1} vs 粗闸门 ${thr}（${factor}×${cores} 核）；探针 ${probe}ms vs 顶 ${ceil}ms"
  case "$probe" in ''|*[!0-9]*) probe=0 ;; esac
  case "$ceil" in ''|*[!0-9]*) ceil=120 ;; esac
  [ "$probe" -le "$ceil" ] || return 0
  case "$cores" in ''|*[!0-9]*) return 1 ;; esac
  [ "$cores" -gt 0 ] || return 1
  awk -v l="$load1" -v t="$thr" 'BEGIN { exit !(l > t) }' && return 0
  return 1
}
pty_premise_reason() { printf '%s' "${P21_PREMISE_REASON:-（没有读数）}"; }

# ── 前提自述模式（M58/panel-knobs 的先例 + P48）：只打前提行与每个注入旋钮的忽略行，不建 tmux、
# 不起面板、不判任何时长 —— 门禁每轮用它证明「旋钮不得漏进真路径」（时间无关）。
if [ "${_premise_only_arg:-0}" = "1" ]; then
  _only_sections=("$@")
  [ "${#_only_sections[@]}" -gt 0 ] || _only_sections=(premise-only)
  for _only_s in "${_only_sections[@]}"; do p21_premise_line "$_only_s"; done
  printf 'panel-p21: premise-only 模式（裸读数 + 旋钮忽略声明；除代码无关探针外没有起进程、没有建 tmux、没有判定；exit 0）\n'
  exit 0
fi

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
# P48: 延长窗口与上限由夹具钉住（默认 8 / 3）；夹具旋钮只在 TEAM_SMOKE_FIXTURE=1 下覆盖。
# 注入读数超顶时同时注入「状态永不到来」的针：那是夹具在模拟「这台机器交不出这一帧」，
# 让耗尽路径在安静机上可达（真路径下没有针，也没有注入）。
PTY_STALL_ROUNDS=8
PTY_EXT_FACTOR=3
if p21_fixture_on; then
  case "${_premise_stall_arg:-}" in ''|*[!0-9]*) ;; *) PTY_STALL_ROUNDS="$_premise_stall_arg" ;; esac
  case "${_premise_probe_arg:-}" in
    ''|*[!0-9]*) ;;
    *) [ "$_premise_probe_arg" -gt "$(p21_probe_ceil)" ] && PTY_INJECT_NEEDLE='◊P48-注入：状态永不到来◊' ;;
  esac
  [ "${_stall_arg:-0}" = "1" ] && PTY_INJECT_NEEDLE='◊P48-注入：状态永不到来◊'
fi

SECTIONS=("$@")
[ "${#SECTIONS[@]}" -gt 0 ] || SECTIONS=(settings groups wheel choices choices-schema write conflict seats readonly)
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
# <marker> is the string the wait looks for: P30/D2 made the view open on the read-only skeleton,
# so the default is the first functional group heading (identity) — a class word is no longer a
# heading and, at the top of the list, would only appear on some badge (zh by default; the en pass
# passes its own marker).
open_view() {
  local marker="${1:-身份与账本布局}"
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

# P30/D2: the grouping is a functional domain, the effect class lives in the row's badge. A line
# that carries nothing but a class word can only come from a class-group heading — this is the pin
# that the view did not go back to grouping by class (both languages' six words).
assert_no_class_heading() { # <capture file> [label]
  local f="$1" label="${2:-视图没有类分组标题（分组是功能域）}"
  if sed 's/[│|]//g' "$f" | grep -qE '^ *(立即生效|需要重启|只读|Takes effect now|Needs a restart|Read-only) *$'; then
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
  local fstats
  open_view
  assert_eq "导航行打开视图没有写 panel.conf" "$(sha "$state/panel.conf" 2>/dev/null || echo none)" "$conf_before"
  cap_to view
  # P30/D2：分组 = schema 第 10 列的功能域。视图开屏在只读骨架（identity），标题就是功能域名；
  # 旧的三条类分组标题（立即生效 / 需要重启 / 只读）不再是标题（徽章词仍在，见类徽章段）。
  assert_has "$tmp/$current/view.txt" "身份与账本布局" "功能域分组标题（identity，开屏即见）"
  assert_no_class_heading "$tmp/$current/view.txt"
  # 行文本是人话标签（不是裸键），开屏聚焦行是 identity 的第一条 schema 键。
  assert_match "$tmp/$current/view.txt" '› 项目名 +.*只读' "开屏聚焦行是 identity 第一条（标签 + 只读 徽章）"
  assert_not "$tmp/$current/view.txt" "TEAM_GATES" "行里不再出现裸键 TEAM_GATES"
  # 组内保持 schema 顺序（项目名 在 会话名 之前）。
  local n_first n_second
  n_first="$(grep -n '项目名' "$tmp/$current/view.txt" | head -1 | cut -d: -f1)"
  n_second="$(grep -n '会话名' "$tmp/$current/view.txt" | head -1 | cut -d: -f1)"
  if [ -n "$n_first" ] && [ -n "$n_second" ] && [ "$n_first" -lt "$n_second" ]; then
    ok "同一组内保持 schema 顺序（项目名 在第 $n_first 行，会话名 在第 $n_second 行）"
  else
    bad "组内顺序不对（项目名=$n_first 会话名=$n_second）"
  fi
  # 类徽章是词（P30/D4）：过滤到一条 apply 行看它的徽章。
  filter_to 模型并发上限
  cap_to badge-apply
  assert_match "$tmp/$current/badge-apply.txt" '模型并发上限 +.*立即生效' "apply 行：人话标签 + 立即生效 徽章（词仍在）"
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
  # P32：短列表（一条过滤结果）也把卡片填满 —— 空白留在卡片**里面**，卡片下边框仍紧贴键栏。
  cap_visible_to filter-fill
  fstats="$(settings_window_stats "$tmp/$current/filter-fill.txt")"
  IFS=' ' read -r _fr _fu _fd fgap <<<"$fstats"
  if [ "${_fr:-0}" -ge 1 ] && [ "${fgap:-9}" -le 1 ]; then
    ok "过滤到一条时卡片仍填满窗口（行=$_fr 空白=$fgap）"
  else
    bad "过滤到一条时卡片没有填满窗口（$fstats）"
  fi
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
  assert_has "$tmp/$current/cleared.txt" "项目名" "esc 清过滤后全部行回来（回到未过滤列表的顶部）"
  assert_has "$tmp/$current/cleared.txt" "身份与账本布局" "清过滤后第一组标题也回来"
  assert_has "$tmp/$current/cleared.txt" "项目设置" "esc 没有关掉视图"
  # The focus window moves with the keys and counts what it hides at the top.
  local i
  for i in $(seq 1 40); do keys Down; sleep 0.02; done
  if wait_cap window "↑"; then ok "窗口顶部出现被隐藏的行数计数行"; else bad "窗口滚动后没有出现 ↑N 计数行"; fi
  assert_match "$tmp/$current/window.txt" '↑[0-9]+' "窗口顶部显示被隐藏的行数"
  # A click moves the focus to an unfocused row; the second click opens that row's editor. M49：行
  # 按**标签**认，原始键从第一次点击后的 CLI 提示行读（标签用来看，键用来敲）。
  # P30：视图开屏在只读骨架上，先过滤出**多条** apply 行（「上限」命中模型并发上限 / 席位内存上限 /
  # 详情文件读取上限…）——点击用例需要一条未聚焦的 apply 行。
  filter_to 上限
  cap_to click-set
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
              'TEAM_ZZZ_TEST|apply|text||plain|zzz-default|-|||workflow\nTEAM_DEFAULT_MODEL|restart|model|req|plain|deepseek/deepseek-flash|-|')
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
  open_view 'Identity & ledger layout'
  filter_to TEAM_PULSE_INTERVAL
  cap_to en
  assert_match "$tmp/$current/en.txt" '› Patrol interval' "en 行的人话标签（行不是裸键）"
  assert_has "$tmp/$current/en.txt" "CLI: team config set TEAM_PULSE_INTERVAL <value>" "en 的 CLI 提示行同样点名原始键"

  # ── P32：视图用满窗口高度（用户实测 45 行里 16 行空白）+ 行数记账诚实 ──
  # 同一条契约、同一个面板，只改 pane 行高：① 内容结尾（卡片下边框）到键栏的空白 ≤1 行；
  # ② 画出的行数随行高长（45 vs 30 的差 ≥8）；③ rows + ↑N + ↓N 恰好等于命令报的键+席位总数
  # （窗口的计数行必须与窗口实际画出的行数一致 —— P30/D5 的成本模型曾经按「带注释的行占两行」
  # 记账，虚报了 15 行，那 15 行就是用户看到的空白）。
  conf_set "lang=zh" "page=1" "activity=1" "mouse=1" "density=comfortable" "theme=auto"
  unset P21_CLI
  start_panel
  open_view
  local want_count
  want_count="$( (cd "$ROOT" && bash "$skill/scripts/team" config list --json) \
    | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d["keys"]) + len(d.get("models",{}).get("seats",[])))' )"
  [ "${want_count:-0}" -gt 0 ] || bad "读数拿不到键数（前提不成立）"
  local h s rows up down gap prev_rows=""
  for h in 45 33 30 25; do
    if resize_panel 120 "$h"; then
      if wait_settings_frame "$h" "height$h"; then
        s="$(settings_window_stats "$tmp/$current/height$h.txt")"
        IFS=' ' read -r rows up down gap <<<"$s"
        # ① 内容结束到键栏的空白 ≤1 行（P32 前：45 行里 16 行）
        if [ "$gap" -le 1 ]; then ok "${h} 行：内容结尾到键栏只剩 $gap 行空白（≤1）"; else bad "${h} 行：内容结尾到键栏还有 $gap 行空白"; fi
        # ③ 记账诚实：窗口画出的行 + 两条计数 = 命令报的总行数
        assert_eq "${h} 行：rows($rows) + ↑($up) + ↓($down) = 命令报的键+席位（$want_count）" \
          "$((rows + up + down))" "$want_count"
        case "$h" in
          45) prev_rows="$rows" ;;
          30) if [ -n "$prev_rows" ] && [ "$((prev_rows - rows))" -ge 8 ]; then
                ok "窗口随行高长：45 行 $prev_rows → 30 行 $rows（差 $((prev_rows - rows)) ≥ 8）"
              else
                bad "窗口没有随行高长：45 行 $prev_rows → 30 行 $rows"
              fi ;;
        esac
      else
        cap_visible_to "height$h-fail"
        bad "缩到 120×${h} 之后没有画出完整的设置视图帧（$(settings_window_stats "$tmp/$current/height$h-fail.txt")）"
      fi
    else
      bad "pane 缩到 120×${h} 没有生效"
    fi
  done
  resize_panel 160 40 || true
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
new = "TEAM_ZZZ_MODE|apply|enum|red,blue|plain|red|scratch 夹具：验证 schema 新增 enum 键零改动出现|||workflow\nTEAM_MEETING_ALLOW_USER_ID|"
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

cap_visible_to() { tmux -L "$sock" capture-pane -p -t "$sess:panel" > "$tmp/$current/${1:-visible}.txt" 2>/dev/null; }

# P32：等新行高下的**完整**一帧。只等「settle」不够：缩完 tmux 立刻按新尺寸裁剪旧帧，而 Ink 还没重画，
# 两张连续捕获可能一致却是旧内容。所以判据是结构：可见帧行数等于新 pane 高度、且能认出卡片的
# 上/下边框与键栏（settings_window_stats 的两个非 -1），并把那帧写进 <cap name>.txt。
wait_settings_frame() { # <rows> <cap name> → 0 = 帧按新行高画完整
  local rows="$1" name="${2:-height}" i a b st lines r u d g
  for i in $(seq 1 30); do
    a="$(cap_now | sed -E 's/[0-9]{2}:[0-9]{2}:[0-9]{2}/HH:MM:SS/g')"
    sleep 0.25
    b="$(cap_now)"
    [ "$(printf '%s\n' "$b" | sed -E 's/[0-9]{2}:[0-9]{2}:[0-9]{2}/HH:MM:SS/g')" = "$a" ] || continue
    lines="$(printf '%s\n' "$b" | wc -l)"
    printf '%s\n' "$b" > "$tmp/$current/$name.txt"
    st="$(settings_window_stats "$tmp/$current/$name.txt")"
    IFS=' ' read -r r u d g <<<"$st"
    [ "$lines" = "$rows" ] || continue
    [ "${r:-0}" -ge 0 ] && [ "${g:-0}" -ge 0 ] && return 0
  done
  return 1
}

# P32：一帧里视图的**行数记账**：窗口里画出的行数、上下两条隐藏计数、以及内容结尾（卡片下边框）到
# 键栏之间的空白行数。打印 "<rows> <hidden_up> <hidden_down> <gap>"（认不出来打印 "-1 -1 -1 -1"）。
settings_window_stats() { # <capture file>
  python3 - "$1" <<'PY'
import re, sys
lines = open(sys.argv[1], encoding='utf-8', errors='replace').read().split('\n')
top = next((i for i, l in enumerate(lines) if l.lstrip().startswith('\u256d\u2500 项目设置') or l.lstrip().startswith('\u256d\u2500 Project settings')), -1)
bot = next((i for i, l in enumerate(lines) if i > top and l.lstrip().startswith('\u2570')), -1)
foot = next((i for i, l in enumerate(lines) if i > bot and ('\u5199\u4fe1' in l or 'compose' in l)), -1)
if top < 0 or bot < 0 or foot < 0:
    print('-1 -1 -1 -1'); sys.exit(0)
interior = lines[top + 1:bot]
audit = next((i for i, l in enumerate(interior) if '\u5ba1\u8ba1\uff08\u6700\u8fd1\uff09' in l or 'Audit' in l), -1)
if audit < 3:
    print('-1 -1 -1 -1'); sys.exit(0)
# 尾部固定占位：CLI 提示行、空行、审计标题（audit-2 起），所以行只可能在 audit-2 之前。
tail_start = audit - 2
rows = up = down = 0
for i, l in enumerate(interior):
    b = l.strip('\u2502 ').rstrip()
    m = re.fullmatch(r'([\u2191\u2193])(\d+)', b)
    if m:
        if m.group(1) == '\u2191': up = int(m.group(2))
        else: down = int(m.group(2))
        continue
    if i >= tail_start or not b or '\u2500' in b:
        continue
    rows += 1
print('%d %d %d %d' % (rows, up, down, foot - bot - 1))
PY
}

# 含 <text> 的第一行行号（0 = 找不到）。
cap_line_of() { # <file> <substring>
  local n
  n="$(grep -nF -- "$2" "$1" 2>/dev/null | head -1 | cut -d: -f1)"
  printf '%s\n' "${n:-0}"
}

# The same capture with SGR runs (`capture-pane -e`): tmux restores each cell's truecolor
# sequence, which is what the tone assertion reads (without rebuilding the bundle by hand).
cap_e_to() { tmux -L "$sock" capture-pane -p -e -t "$sess:panel" > "$tmp/$current/${1:-cap-e}.txt" 2>/dev/null; }

assert_no_match() { # <file> <ere> <message>
  grep -qE -- "$2" "$1" 2>/dev/null && bad "$3（不该匹配 [$2]）" || ok "$3"
}

# P30/D4 tone: the badge's colour must be the class's tone **and** the value beside it must stay in
# the palette's text tone. Colours come from the bundle's own `--palette` (nothing hardcoded; the
# active theme is identified by which palette's text tone the value's colour is).
assert_badge_tone() { # <capture-e file> <row label> <badge word> <tone key> <message>
  local msg="$5" out rc
  out="$(python3 - "$1" "$2" "$3" "$4" "$tmp/$current/palette.json" <<'PY'
import json, re, sys
cap_file, label, badge, tone_key, palette_file = sys.argv[1:6]
SGR = re.compile(r'\x1b\[[0-9;]*m')

def runs(line):
    out, last, pos = [], '', 0
    for m in SGR.finditer(line):
        if line[pos:m.start()]:
            out.append((last, line[pos:m.start()]))
        last = m.group(0)
        pos = m.end()
    if line[pos:]:
        out.append((last, line[pos:]))
    return out

def color(sgr):
    m = re.search(r'38;2;(\d+);(\d+);(\d+)', sgr)
    return '#%02x%02x%02x' % tuple(int(x) for x in m.groups()) if m else 'default'

line = next((l for l in open(cap_file, encoding='utf-8', errors='replace') if label in l and badge in l), '')
if not line:
    print('找不到同时含 %r 与 %r 的行' % (label, badge)); sys.exit(1)
rs = runs(line)
li = next((i for i, (_, t) in enumerate(rs) if label in t), None)
bi = next((i for i, (_, t) in enumerate(rs) if badge in t), None)
if li is None or bi is None or bi <= li:
    print('run 结构不对（label=%s badge=%s）' % (li, bi)); sys.exit(1)
vi = next((i for i in range(li + 1, bi) if rs[i][1].strip()), bi)
value_color, badge_color = color(rs[vi][0]), color(rs[bi][0])
palettes = json.load(open(palette_file, encoding='utf-8'))['palettes']
active = next((p for p in palettes.values() if p['tones']['text'].lower() == value_color), None)
if active is None:
    print('值的颜色 %s 不在任何调色板的 text tone 里' % value_color); sys.exit(1)
want = active['tones'][tone_key].lower()
if badge_color != want:
    print('badge 颜色 %s ≠ %s tone %s（调色板 %s）' % (badge_color, tone_key, want, active['name'])); sys.exit(1)
print('%s badge=%s value=%s（text）palette=%s' % (badge, badge_color, value_color, active['name']))
PY
)"
  rc=$?
  if [ "$rc" -eq 0 ]; then ok "$msg（$out）"; else bad "$msg：$out"; fi
}

# 把焦点走到列表末尾（窗口跟着焦点走），让尾部的「未分组」与席位块同一屏 —— 这两样都在
# 「分组之后」，是场景要看的相对顺序。
walk_to_tail() { # <capture name>
  local i attempt name="${1:-tail}" hit=0
  for attempt in $(seq 1 6); do
    for i in $(seq 1 140); do keys Down; sleep 0.01; done
    for i in $(seq 1 12); do
      cap_to "$name"
      if grep -q '席位' "$tmp/$current/$name.txt" && grep -q '›' "$tmp/$current/$name.txt"; then hit=1; break; fi
      sleep 0.4   # 块被 TTL 重读换成摘要行（已知现象）→ 等它回来，必要时再走一轮
    done
    [ "$hit" = 1 ] && break
  done
  return 0
}

scn_groups() {
  section "groups · 记录带 group、视图按功能域分组（P30/D1-D3）：功能域标题/读取顺序/schema 序/未分组降级/无键→域表/徽章词+tone"
  server_up groups
  # 契约里手加一个 schema 不认识的键：它必须落在可见的「未分组」组里（和缺 token 的 schema 行同一条降级路径）。
  printf 'TEAM_HAND_ADDED="hand"\n' >> "$(cfg)"
  conf_set "lang=zh" "page=1" "activity=1" "mouse=1" "density=comfortable" "theme=auto"
  start_panel
  local bundle_sha; bundle_sha="$(sha "$panel")"
  "$js" "$panel" --palette > "$tmp/$current/palette.json" 2>/dev/null
  open_view
  cap_to view
  # ① 标题 = 功能域、按读取顺序；类词只活在行徽章里（没有「只有类词」的行）。
  assert_has "$tmp/$current/view.txt" "身份与账本布局" "第一组标题是 identity 的功能域名"
  # P32（用户的第一条反馈）：标题与选项行必须在渲染上可区分。标题是分节线（── 标题 ────），
  # 键行不带分节线；标题行同时把两组隔开（上一行=上一组最后一条，下一行=本组第一条）。
  assert_match "$tmp/$current/view.txt" '^│ ── 身份与账本布局 ─+' "分组标题是分节线（不是缩进的普通行）"
  assert_no_match "$tmp/$current/view.txt" '^│ [› ] 项目名.*─' "键行不带分节线（标题/行在渲染上可区分）"
  assert_heading_rule "$tmp/$current/view.txt" "分支与 forge" "契约文件" "分支命名模式" "组间可见分隔：标题是分节线且夹在两组之间"
  # 读取顺序：identity 的 12 条走完，下一组标题就是 branch（窗口跟着焦点，标题只在它的行进窗时画）。
  # 带注释的行是两行，窗口按**画出的行数**装（P30/D5 的账），所以这里一步一步走，不假设一屏能装两组。
  local k
  for k in $(seq 1 12); do keys Down; sleep 0.05; done
  sleep 0.4
  cap_to group-order
  assert_has "$tmp/$current/group-order.txt" "分支与 forge" "第 13 行进窗时出现下一组标题（读取顺序 identity → branch）"
  for k in $(seq 1 12); do keys Up; sleep 0.05; done
  sleep 0.4
  assert_no_class_heading "$tmp/$current/view.txt"
  # ② 组内保持 schema 顺序（identity：项目名 → 会话名 → PM 窗口）。
  local n_proj n_sess n_pm
  n_proj="$(cap_line_of "$tmp/$current/view.txt" '项目名')"
  n_sess="$(cap_line_of "$tmp/$current/view.txt" '会话名')"
  n_pm="$(cap_line_of "$tmp/$current/view.txt" 'PM 窗口')"
  if [ "$n_proj" -gt 0 ] && [ "$n_proj" -lt "$n_sess" ] && [ "$n_sess" -lt "$n_pm" ]; then
    ok "组内是 schema 顺序（项目名=$n_proj < 会话名=$n_sess < PM 窗口=$n_pm）"
  else
    bad "组内顺序不对（项目名=$n_proj 会话名=$n_sess PM 窗口=$n_pm）"
  fi
  # ③ 类徽章是词 + tone（D4）：三类各过滤一行；词在，tone = 调色板里该类的 tone，值必须是 text tone。
  filter_to TEAM_MODEL_LIMITS
  sleep 0.4
  cap_to tone-apply; cap_e_to tone-apply-e
  assert_match "$tmp/$current/tone-apply.txt" '模型并发上限 +.*立即生效' "apply 行的徽章词仍在（颜色不是唯一通道）"
  assert_badge_tone "$tmp/$current/tone-apply-e.txt" '模型并发上限' '立即生效' 'text' "apply 徽章 = 普通文本 tone"
  filter_to TEAM_PULSE_INTERVAL
  sleep 0.4
  cap_to tone-restart; cap_e_to tone-restart-e
  assert_match "$tmp/$current/tone-restart.txt" '巡检周期 +.*需重启' "restart 行的徽章词仍在"
  assert_badge_tone "$tmp/$current/tone-restart-e.txt" '巡检周期' '需重启' 'warn' "restart 徽章 = warn tone"
  filter_to TEAM_PROJECT
  sleep 0.4
  cap_to tone-refuse; cap_e_to tone-refuse-e
  assert_match "$tmp/$current/tone-refuse.txt" '项目名 +root · 只读' "refuse 行的徽章词仍在"
  assert_badge_tone "$tmp/$current/tone-refuse-e.txt" '项目名' '只读' 'dim' "refuse 徽章 = dim tone"
  # ④ 可见降级：schema 不认识的键落在「未分组」，且「未分组」在席位块之前（走到列表末尾看）。
  filter_to TEAM_HAND_ADDED
  sleep 0.4
  cap_to hand-added
  assert_match "$tmp/$current/hand-added.txt" 'TEAM_HAND_ADDED +hand · 未知键' "未知键的行仍在（没有消失）"
  assert_has "$tmp/$current/hand-added.txt" "未知键：TEAM_HAND_ADDED" "未知键仍按原始键点名"
  [ "$(cap_line_heading "$tmp/$current/hand-added.txt" '未分组')" -gt 0 ] \
    && ok "未知键落在可见的「未分组」标题下" || bad "未知键没有落在「未分组」标题下"
  assert_match "$tmp/$current/hand-added.txt" '^│ ── 未分组 ─+' "降级组标题也是同一种分节线（标题体系一致）"
  filter_clear
  sleep 0.4
  walk_to_tail tail
  local n_ungrouped n_seats
  n_ungrouped="$(cap_line_heading "$tmp/$current/tail.txt" '未分组')"
  n_seats="$(cap_line_heading "$tmp/$current/tail.txt" '席位')"
  if [ "$n_ungrouped" -gt 0 ] && [ "$n_seats" -gt 0 ] && [ "$n_ungrouped" -lt "$n_seats" ]; then
    ok "「未分组」在席位块之前（未分组=$n_ungrouped < 席位=$n_seats）"
  else
    bad "尾部顺序不对（未分组=$n_ungrouped 席位=$n_seats）"
  fi
  assert_match "$tmp/$current/tail.txt" '^│ ── 席位 ─+' "席位块标题也是同一种分节线（标题体系一致）"
  # ⑤ 无键→域表：scratch CLI 让 TEAM_ZZZ_TEST 带 workflow、把 TEAM_GATES 移到 meeting；
  #    提交的那份 bundle 必须跟着两个标题走（bundle 里没有第二张键表/组表）。
  local scratch="$tmp/$current/scratch"
  mkdir -p "$scratch/skills/teamsmith"
  cp -a "$skill/scripts" "$scratch/skills/teamsmith/scripts"
  cp -a "$skill/templates" "$skill/references" "$scratch/skills/teamsmith/"
  python3 - "$scratch/skills/teamsmith/scripts/lib/cmd-config.sh" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
gates = 'TEAM_GATES|apply|cmd||plain||-|||workflow'
assert gates in s, '找不到 TEAM_GATES 的 10 列 schema 行'
s = s.replace(gates, gates.replace('|workflow', '|meeting'), 1)
anchor = 'TEAM_INSTALL_CMD|apply|cmd||plain||-|||workflow'
assert anchor in s, '找不到 TEAM_INSTALL_CMD 的 schema 行'
s = s.replace(anchor, 'TEAM_ZZZ_TEST|apply|text||plain|zzz-default|-|||workflow\n' + anchor, 1)
open(p, 'w', encoding='utf-8').write(s)
PY
  cat > "$tmp/$current-scratch-wrapper.sh" <<EOF2
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$tmp/$current-scratch-argv.log"
exec bash "$scratch/skills/teamsmith/scripts/team" "\$@"
EOF2
  chmod +x "$tmp/$current-scratch-wrapper.sh"
  # `VAR=x func` 的赋值只活到函数返回 —— 本段要起两次面板（同 scn_choices_schema 的教训）。
  P21_CLI="$tmp/$current-scratch-wrapper.sh"
  start_panel
  open_view
  filter_to TEAM_ZZZ_TEST
  sleep 0.5
  cap_to zzz-group
  assert_has "$tmp/$current/zzz-group.txt" "工作流与门禁" "schema 新增键落在它声明的 workflow 域下（bundle 未重建）"
  assert_match "$tmp/$current/zzz-group.txt" 'TEAM_ZZZ_TEST +未设 · 默认 zzz-default' "新键的行完整（值/默认来自 schema）"
  filter_to TEAM_GATES
  sleep 0.5
  cap_to gates-moved
  assert_has "$tmp/$current/gates-moved.txt" "跨项目会议" "TEAM_GATES 的 token 改成 meeting 后跟到新标题下（bundle 里没有键→域表）"
  assert_match "$tmp/$current/gates-moved.txt" '门禁命令 +true · 立即生效' "同一行仍按 schema 渲染（标签/值/徽章）"
  assert_eq "三次运行之间 bundle 逐字节不变" "$(sha "$panel")" "$bundle_sha"
  # ⑥ 第 10 列缺失 = 畸形行：走查那边判红（config-cli.sh 的 groups 段），视图这边可见降级到「未分组」，
  #    行本身（标签/值/徽章/命令行）一个字不少。
  python3 - "$scratch/skills/teamsmith/scripts/lib/cmd-config.sh" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
row = 'TEAM_GATES|apply|cmd||plain||-|||meeting'
assert row in s, '找不到移动后的 TEAM_GATES 行'
s = s.replace(row, 'TEAM_GATES|apply|cmd||plain||-|', 1)
open(p, 'w', encoding='utf-8').write(s)
PY
  start_panel
  open_view
  filter_to TEAM_GATES
  sleep 0.5
  cap_to gates-fallback
  unset P21_CLI
  assert_has "$tmp/$current/gates-fallback.txt" "未分组" "第 10 列缺失的 schema 行落在可见的降级组里（不消失）"
  assert_match "$tmp/$current/gates-fallback.txt" '门禁命令 +true · 立即生效' "降级组里的行仍完整（标签/值/徽章）"
  assert_has "$tmp/$current/gates-fallback.txt" "命令行：team config set TEAM_GATES <新值>" "降级组里的行仍给出命令行"
  # 同一个 scratch 树里，「未分组」现在同时装着手加的未知键与畸形行：走到末尾，两者同屏且在席位之前。
  filter_clear
  sleep 0.4
  walk_to_tail tail-scratch
  assert_has "$tmp/$current/tail-scratch.txt" "TEAM_HAND_ADDED" "降级组里未知键与畸形行同屏（未知键可见）"
  assert_has "$tmp/$current/tail-scratch.txt" "门禁命令" "降级组里畸形行同屏（schema 行可见）"
  local n_u n_s
  n_u="$(cap_line_heading "$tmp/$current/tail-scratch.txt" '未分组')"
  n_s="$(cap_line_heading "$tmp/$current/tail-scratch.txt" '席位')"
  if [ "$n_u" -gt 0 ] && [ "$n_s" -gt 0 ] && [ "$n_u" -lt "$n_s" ]; then
    ok "scratch 尾部：「未分组」仍在席位块之前（$n_u < $n_s）"
  else
    bad "scratch 尾部顺序不对（未分组=$n_u 席位=$n_s）"
  fi
}

scn_wheel_settings() {
  section "wheel · 设置视图自己的窗口（P30/D5）：一格一行/焦点不动/计数行跟随/不穿透页面/焦点推窗/两个 picker"
  server_up settings-wheel
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
  sleep 0.7
  cap_to page-scrolled
  assert_not "$tmp/$current/page-scrolled.txt" "P-01" "页面滚轮 3 格：P-01 已出屏（页面确实滚得动）"
  assert_has "$tmp/$current/page-scrolled.txt" "P-04" "页面滚轮 3 格：P-04 进屏"
  # ② 视图里的滚轮：一格一行、焦点不动、顶部计数行跟随（先下滚 3 格，再上滚回顶部）。
  open_view
  cap_to wheel-before
  assert_match "$tmp/$current/wheel-before.txt" '› 项目名 +.*只读' "视图开屏焦点在第一行（identity 第一条）"
  wheel_at down 20 10 3
  local i
  for i in $(seq 1 20); do
    cap_to wheel-down
    grep -qE '↑3' "$tmp/$current/wheel-down.txt" && break
    sleep 0.25
  done
  assert_match "$tmp/$current/wheel-down.txt" '↑3' "下滚 3 格：顶部计数行读出 ↑3（窗口正好移 3 行）"
  assert_not "$tmp/$current/wheel-down.txt" "项目名" "下滚 3 格：原本第一行（项目名）已出窗"
  assert_has "$tmp/$current/wheel-down.txt" "名册" "下滚 3 格：后面的行进窗（窗口第一行 = 第 4 条）"
  assert_has "$tmp/$current/wheel-down.txt" "只读：手改 .pi/team/config.sh 里的 TEAM_PROJECT" "下滚 3 格：焦点没动（命令行仍点名 TEAM_PROJECT）"
  wheel_at up 20 10 3
  for i in $(seq 1 20); do
    cap_to wheel-up
    grep -qE '↑[0-9]+' "$tmp/$current/wheel-up.txt" || break
    sleep 0.25
  done
  assert_match "$tmp/$current/wheel-up.txt" '› 项目名' "上滚 3 格：窗口回到顶部，第一行回来"
  assert_no_match "$tmp/$current/wheel-up.txt" '↑[0-9]+' "上滚 3 格：顶部计数行消失"
  # ③ 焦点键把窗口推到聚焦行（滚开之后 enter 打开的就是命令行点名的那一行）。
  wheel_at down 20 10 3
  for i in $(seq 1 20); do
    cap_to wheel-push-pre
    grep -qE '↑3' "$tmp/$current/wheel-push-pre.txt" && break
    sleep 0.25
  done
  keys Down
  sleep 0.5
  cap_to wheel-push
  assert_match "$tmp/$current/wheel-push.txt" '↑1' "↓ 之后窗口被推到聚焦行上（顶部计数行 = ↑1）"
  assert_match "$tmp/$current/wheel-push.txt" '› 会话名' "光标落在下一条（会话名）"
  assert_has "$tmp/$current/wheel-push.txt" "只读：手改 .pi/team/config.sh 里的 TEAM_SESSION" "命令行与光标同一行（焦点在会话名上）"
  keys Up
  sleep 0.5
  cap_to wheel-push-back
  assert_match "$tmp/$current/wheel-push-back.txt" '› 项目名' "↑ 之后光标回到第一条"
  assert_no_match "$tmp/$current/wheel-push-back.txt" '↑[0-9]+' "窗口跟着回到顶部（计数行消失）"
  keys Enter
  if wait_cap wheel-enter "只读：手改 .pi/team/config.sh 里的 TEAM_PROJECT"; then
    ok "enter 打开的行 = 命令行点名的行（TEAM_PROJECT 的只读路线）"
  else
    bad "enter 之后没有出现聚焦行的路线回执"
  fi
  # ④ 选择器开着时滚轮走条目、页面不动；esc 之后选择器是关着的（一次 esc 就够）。
  filter_to TEAM_PULSE_INTERVAL
  sleep 0.5
  keys Enter
  wait_picker TEAM_PULSE_INTERVAL '300' || bad "选择器没有打开（滚轮用例前提）"
  cap_to picker-wheel-before
  local sel_before sel_after
  sel_before="$(cap_line_of "$tmp/$current/picker-wheel-before.txt" '›')"
  wheel_at down 20 12 2
  sleep 0.6
  cap_to picker-wheel-after
  sel_after="$(cap_line_of "$tmp/$current/picker-wheel-after.txt" '›')"
  if [ "$sel_before" -gt 0 ] && [ "$sel_after" -gt "$sel_before" ]; then
    ok "选择器开着时滚轮走条目（选中行 $sel_before → $sel_after）"
  else
    bad "选择器里的滚轮没有走条目（选中行 $sel_before → $sel_after）"
  fi
  pty_key_when "选选择器的 esc" ' · TEAM_PULSE_INTERVAL' Escape || bad "选择器不在稳定帧上，esc 没有发"
  sleep 0.8
  cap_to picker-closed
  assert_not "$tmp/$current/picker-closed.txt" " · TEAM_PULSE_INTERVAL" "一次 esc 就把选择器关掉（不穿透）"
  assert_has "$tmp/$current/picker-closed.txt" "╭─ 项目设置" "关闭后仍在设置视图里"
  # ⑤ 席位 picker 的滚轮同样走条目（这一支原来会穿透到页面）。
  filter_to dev
  sleep 0.5
  if focus_row 'dev +deepseek'; then
    keys Enter
  else
    bad "没能把焦点移到 dev 席位行"
  fi
  # 席位 picker 的标题是「选择 <seat> 的模型」（没有 ` · KEY` 后缀），所以用 pty_wait_frame 等它。
  if pty_wait_frame "$tmp/$current/seat-picker.txt" "seat picker dev" "选择 dev 的模型" "回退默认"; then
    ok "席位 picker 打开（标题 + 已知模型）"
  else
    bad "席位 picker 没有打开"
  fi
  cap_to seat-wheel-before
  sel_before="$(cap_line_of "$tmp/$current/seat-wheel-before.txt" '›')"
  wheel_at down 20 12 2
  sleep 0.6
  cap_to seat-wheel-after
  sel_after="$(cap_line_of "$tmp/$current/seat-wheel-after.txt" '›')"
  if [ "$sel_before" -gt 0 ] && [ "$sel_after" -gt "$sel_before" ]; then
    ok "席位 picker 里的滚轮走条目（$sel_before → $sel_after）"
  else
    bad "席位 picker 里的滚轮没有走条目（$sel_before → $sel_after）"
  fi
  pty_key_when "席位 picker 的 esc" '选择 dev 的模型' Escape || bad "席位 picker 不在稳定帧上，esc 没有发"
  sleep 0.8
  cap_to seat-closed
  assert_not "$tmp/$current/seat-closed.txt" "选择 dev 的模型" "一次 esc 关掉席位 picker"
  # ⑥ 回到页面：视图把滚轮吃掉了 —— 页面还是进视图前的那一屏（P-01 出屏、P-04 可见）。
  pty_key_when "关设置视图" '╭─ 项目设置' Escape || bad "关闭视图前它不在稳定帧上"
  sleep 1
  pty_key_when "关浮层" '项目设置' Escape || bad "浮层不在稳定帧上"
  sleep 1
  cap_to page-back
  assert_not "$tmp/$current/page-back.txt" "P-01" "视图里的滚轮没有穿透页面（P-01 仍在屏外）"
  assert_has "$tmp/$current/page-back.txt" "P-04" "页面窗口还是进视图前的那一屏（P-04 仍可见）"
}

# ---------------------------------------------------------------- run

printf '\033[1m== panel-p21 · 项目设置视图（P22） ==\033[0m\n'
for s in "${SECTIONS[@]}"; do
  mkdir -p "$tmp/$s"
  # P48：每个场景在自己的子 shell 里跑。等待耗尽且归因于机器时 pty_on_skip 直接 exit 4，只结束
  # 这个场景（后面的场景照跑）；父 shell 的 EXIT 清扫有自己的 BASHPID 守卫，不会被重复触发。
  (
    trap - EXIT INT TERM
    p21_premise_line "$s"          # 前提行：每个场景第一个断言之前（真读数；只打不判）
    if ! p21_entry_guard; then      # 粗闸门：超顶就在第一个等待之前停下这个场景
      p21_entry_skip_line "$s"
      exit 4
    fi
    case "$s" in
      settings) scn_settings ;;
      groups) scn_groups ;;
      wheel) scn_wheel_settings ;;
      choices) scn_choices ;;
      choices-schema) scn_choices_schema ;;
      write) scn_write ;;
      conflict) scn_conflict ;;
      seats) scn_seats ;;
      readonly) scn_readonly ;;
      *) printf 'panel-p21: 未知场景 %s\n' "$s" >&2; exit 3 ;;
    esac
  )
  rc=$?
  case "$rc" in
    0) ;;
    3) exit 3 ;;                                          # 搭建失败（server_up/未知场景）照旧
    4) SKIP=$((SKIP + 1)) ;;                              # 可见 SKIP：无失败、无结论
    *) ;;                                                 # 1 = 断言失败，最后按 FAIL 退出
  esac
done

PASS="$(p21_count_of "$_p21_count/ok")"
FAIL="$(p21_count_of "$_p21_count/bad")"
printf '\n\033[1m== 结果 ==\033[0m  ✓ %s  ✗ %s  SKIP %s\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -gt 0 ] && exit 1
[ "$SKIP" -gt 0 ] && exit 4
exit 0
