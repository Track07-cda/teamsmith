#!/usr/bin/env bash
# CPU red-line fixture (pulse-console B1, tasks.md 1.5).
#
#   bash skills/teamsmith/tests/panel-cpu.sh [tree] [seconds]
#   TEAM_PANEL_CPU_PAGE=4 bash skills/teamsmith/tests/panel-cpu.sh   # park it on the board page
#   TEAM_PANEL_CPU_DETAIL=1 bash skills/teamsmith/tests/panel-cpu.sh # open the markdown detail view
#   TEAM_PANEL_CPU_COMPOSE=1 bash skills/teamsmith/tests/panel-cpu.sh # hold the compose line open
#   TEAM_PANEL_CPU_VIEW=1 bash skills/teamsmith/tests/panel-cpu.sh   # keep the project-settings view open
#   TEAM_PANEL_CPU_VIEW=1 TEAM_PANEL_CPU_EDIT=1 bash ...             # …and an editor holding a typed draft
#
# P26/G3（panel#Frame assembly is asynchronous… MODIFIED）：2000ms 与 1% 是**面板**的判定，不是机器的
# 判定 —— 它们只在**测量前提**成立时判：`loadavg_1m ≤ factor × 逻辑核数`（核数取 `nproc`，否则
# `getconf _NPROCESSORS_ONLN`）。前提不成立就打印实测的三个数（首帧 ms、窗格 CPU%、load）并退出 **4**。
#
# **本文件用 factor = 0.25**（`TEAM_PANEL_CPU_PREMISE_FACTOR` 可覆盖）—— 与 smoke 27-d 的 0.75 不同，
# 因为两者量的东西不同：27-d 是 5 次采样的**中位**（实测到 0.62 × 核仍 1.2–1.7s，M49 的红在
# 0.81–1.0 × 核），而这里的交互首帧是**单进程冷启动**量出来的，实测（32 核机器，median-of-3）：
#   0.22 × 核（load 6.9）首帧中位 1542ms ✓ ｜ 0.40 × 核（load 13.0）2005ms ✗ ｜ 0.71 × 核（load 22.8）3919ms ✗
# 也就是绿→红的交叉在 0.22–0.40 × 核之间；取 0.25 × 核（本机 load 8）落在交叉之下、实测绿之上。
# 代价说明：机器忙时这条断言会可见地 SKIP（退出 4），而不是给出一个机器欠的假红。
# 红线本身**没有动**：前提成立时判法与阈值与以前逐字一致（超 2000ms 或 CPU ≥ 1% → 退出 2）。
#
# **中位 of 3**（PM 口径决定，2026-09-20 第二批返工）：首帧与窗格 CPU% 都取三次测量的中位，三个样本
# 都打印出来 —— 单次采样把机器自己的启动抖动算进了面板的账（实测：安静时 ~1.5s，load 4.5 时单次
# 2141ms，load 13 时 2279ms；同一台机器同一天里 1.697% 与 0.399% 都出现过）。首帧是三次**独立 spawn**
# （每次都是「窗口创建 → 第一帧可见」）；CPU% 是把同一个采样窗口**三等分**后的三个子窗均值（不额外
# 加长采样时间）。阈值不缩放：中位 ≥ 2000ms 或中位 ≥ 1% 仍是红。
#
#   Exit: 0 窗格进程 < 1% 单核且首帧在预算内
#         2 红线破了（首帧 ≥ 2000ms 或窗格进程 ≥ 1%）
#         3 搭建失败（没有 tmux / node / bundle）
#         4 **因负载前提不成立而跳过**（既不是通过也不是红；包装器不能把 4 当成 0）
#
# 夹具旋钮（**只在 `TEAM_SMOKE_FIXTURE=1` 时生效**，裸设一律忽略并打印）：
#   TEAM_PANEL_CPU_LOADAVG=<数>      替掉 /proc/loadavg 的读数
#   TEAM_PANEL_CPU_CORES=<整数>      替掉核数
#   TEAM_PANEL_CPU_FRAME_DELAY_MS=<ms>  在面板进程启动前睡一觉（造一个真越线的首帧）
set -uo pipefail

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tree="${1:-$(cd -P "$here/../../.." && pwd)}"
secs="${2:-${TEAM_PANEL_CPU_SECS:-60}}"

# ── 测量前提（P26/G3）───────────────────────────────────────────────────────────────────────
# 夹具旋钮只有在 TEAM_SMOKE_FIXTURE=1 时被采信 —— 否则“负载前提”会退化成“想跳就跳”的后门
# （PM 审查要点②：真路径下的 TEAM_PANEL_CPU_* 注入不得改变判定）。
PREMISE_FACTOR="${TEAM_PANEL_CPU_PREMISE_FACTOR:-0.25}"
case "$PREMISE_FACTOR" in ''|*[!0-9.]*) PREMISE_FACTOR=0.25 ;; esac
pc_fixture_on() { [ "${TEAM_SMOKE_FIXTURE:-0}" = "1" ]; }
pc_notice() { printf '  忽略 %s=%s（只有 TEAM_SMOKE_FIXTURE=1 时夹具旋钮才生效；真实路径读真值）\n' "$1" "$2" >&2; }
pc_load() {
  if [ -n "${TEAM_PANEL_CPU_LOADAVG:-}" ]; then
    if pc_fixture_on; then printf '%s\n' "$TEAM_PANEL_CPU_LOADAVG"; return 0; fi
    pc_notice TEAM_PANEL_CPU_LOADAVG "$TEAM_PANEL_CPU_LOADAVG"
  fi
  cut -d' ' -f1 /proc/loadavg 2>/dev/null || printf '?'
}
pc_cores() {
  if [ -n "${TEAM_PANEL_CPU_CORES:-}" ]; then
    if pc_fixture_on; then printf '%s\n' "$TEAM_PANEL_CPU_CORES"; return 0; fi
    pc_notice TEAM_PANEL_CPU_CORES "$TEAM_PANEL_CPU_CORES"
  fi
  nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || printf '0'
}
# → 0 前提成立（照判）/ 1 不成立（跳过）。同时把前提一行打给人看。
pc_premise() {
  local load cores thr
  load="$(pc_load)"; cores="$(pc_cores)"
  case "$cores" in ''|*[!0-9]*) cores=0 ;; esac
  thr="$(awk -v c="$cores" -v f="$PREMISE_FACTOR" 'BEGIN { printf "%.2f", f * c }')"
  if [ "$cores" -gt 0 ] && awk -v l="$load" -v t="$thr" 'BEGIN { exit !(l <= t) }'; then
    printf '== load premise: loadavg %s <= %s (%s x %s cores) -> hold (judging)\n' "$load" "$thr" "$PREMISE_FACTOR" "$cores"
    return 0
  fi
  printf '== load premise: loadavg %s > %s (%s x %s cores) -> NOT held (skip)\n' "$load" "$thr" "$PREMISE_FACTOR" "$cores"
  return 1
}
refresh="${TEAM_PANEL_CPU_REFRESH:-3}"
interval=5
sock="p12cpu-$$"
sess="p12cpu-$$"
js="${TEAM_JS_BIN:-$(command -v node || true)}"
[ -n "$js" ] || js="$(command -v bun || true)"
rc=3

cleanup() {
  tmux -L "$sock" kill-server 2>/dev/null || true
  # tmux 在服务器已死时会把 socket 文件留在 /tmp/tmux-<uid>/：夹具自己收干净
  rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$sock" 2>/dev/null || true
  rm -rf "${time_out:-}.state" 2>/dev/null || true
}
trap cleanup EXIT

if ! command -v tmux >/dev/null 2>&1; then
  printf 'panel-cpu: tmux is required (the fixture needs a real pane)\n' >&2
  exit 3
fi
if [ -z "$js" ]; then
  printf 'panel-cpu: no node/bun runtime\n' >&2
  exit 3
fi
time_bin=""
for cand in /usr/bin/time "$(command -v time || true)"; do
  [ -x "$cand" ] && { time_bin="$cand"; break; }
done
[ -n "$time_bin" ] || { printf 'panel-cpu: /usr/bin/time is required for the tree figure\n' >&2; exit 3; }

panel="$tree/skills/teamsmith/scripts/panel/panel.js"
[ -f "$panel" ] || { printf 'panel-cpu: no bundle at %s\n' "$panel" >&2; exit 3; }

hz="$(getconf CLK_TCK 2>/dev/null || echo 100)"
time_out="$(mktemp "${TMPDIR:-/tmp}/p12cpu.XXXXXX")"
# TEAM_PANEL_CPU_PAGE=<1|2|3|4> parks the measured console on that page (the board page's kanban is
# the heaviest layout, so the red line is checked there too — P18/B2 item 6.4).
page_flag=""
case "${TEAM_PANEL_CPU_PAGE:-}" in 1|2|3|4) page_flag=" --page ${TEAM_PANEL_CPU_PAGE}" ;; esac
# TEAM_PANEL_CPU_DETAIL=1 measures the markdown detail view's own steady state (P18/B3): the knob
# opens page 4 + the focused card's detail after warm-up. It runs with a private state dir, because
# sending keys must never write the real project's panel-page/panel.conf files.
# TEAM_PANEL_CPU_COMPOSE=1 (P20/B1 1.8) keeps the compose line open with a typed draft for the
# sampling window: the insertion point, the window and the cursor placement must not cost more than
# the idle console (same private state dir — the draft must never land in the real project).
detail_flag=""
compose_flag=""
state_flag=""
compose_env=""
if [ "${TEAM_PANEL_CPU_DETAIL:-0}" = "1" ] || [ "${TEAM_PANEL_CPU_COMPOSE:-0}" = "1" ]; then
  [ "${TEAM_PANEL_CPU_DETAIL:-0}" = "1" ] && detail_flag=1
  [ "${TEAM_PANEL_CPU_COMPOSE:-0}" = "1" ] && compose_flag=1
  state_dir="${time_out}.state"
  mkdir -p "$state_dir"
  state_flag=" --state-dir $state_dir"
fi
if [ -n "$compose_flag" ]; then
  # The C-v press must not read the real clipboard: a failing fake pair keeps the probe local and
  # instant (the red line is about the frame, not about what the clipboard holds).
  fakebin="${time_out}.fakebin"
  mkdir -p "$fakebin"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$fakebin/wl-paste"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$fakebin/xclip"
  chmod +x "$fakebin/wl-paste" "$fakebin/xclip"
  compose_env="PATH=$fakebin:\$PATH "
fi
pane_cmd="cd '$tree' && ${compose_env}exec '$time_bin' -o '$time_out' -f 'P12CPU user=%U sys=%S elapsed=%e' -- '$js' '$panel' --root '$tree' --team-cli '$tree/skills/teamsmith/scripts/team' --no-pulse --refresh $refresh${page_flag}${state_flag}"
# 夹具注入（P26/G3）：在面板进程启动前睡一觉 → 造一个**真越线**的首帧（只在夹具模式下）
if [ -n "${TEAM_PANEL_CPU_FRAME_DELAY_MS:-}" ]; then
  if pc_fixture_on; then
    case "$TEAM_PANEL_CPU_FRAME_DELAY_MS" in
      ''|*[!0-9]*) : ;;
      *) pane_cmd="$(awk -v ms="$TEAM_PANEL_CPU_FRAME_DELAY_MS" 'BEGIN { printf "sleep %.2f\n", ms / 1000 }')"$'\n'"$pane_cmd" ;;
    esac
  else
    pc_notice TEAM_PANEL_CPU_FRAME_DELAY_MS "$TEAM_PANEL_CPU_FRAME_DELAY_MS"
  fi
fi
tmux -L "$sock" new-session -d -s "$sess" -x 140 -y 34 -c "$tree" "sleep 600"
pc_premise || true    # 前提一行先打（不成立也照测，因为退出 4 时要把实测三个数一起打出来）
# 首帧：三次独立 spawn 各量一次「窗口创建 → 第一帧可见」，取中位（中位 of 3）。
# `never` = 轮询预算内没出现（> 2000ms 的一种形态），记成 9999 参与中位，但打印时保留 `never`。
first_frames=()
ff_never=0
measure_first_frame() { # → 毫秒数（没出现 → 9999）
  local ms="" t0
  tmux -L "$sock" kill-window -t "$sess:console" 2>/dev/null || true
  sleep 0.4
  t0="$(date +%s%3N)"
  tmux -L "$sock" new-window -d -t "$sess" -n console -c "$tree" "$pane_cmd" 2>/dev/null || true
  # F8: the interactive first frame is measured, not promised — poll the pane for the title band.
  for _ in $(seq 1 20); do
    sleep 0.1
    if tmux -L "$sock" capture-pane -p -t "$sess:console" 2>/dev/null | grep -q 'teamsmith pulse'; then
      ms=$(( $(date +%s%3N) - t0 )); break
    fi
  done
  if [ -z "$ms" ]; then
    sleep 1   # one last look before judging it `never`
    tmux -L "$sock" capture-pane -p -t "$sess:console" 2>/dev/null | grep -q 'teamsmith pulse' \
      && ms=$(( $(date +%s%3N) - t0 ))
  fi
  if [ -z "$ms" ]; then printf '9999\n'; else printf '%s\n' "$ms"; fi
}
for _ffi in 1 2 3; do
  ff="$(measure_first_frame)"
  first_frames+=("$ff")
done
first_frame_ms="$(printf '%s\n' "${first_frames[@]}" | sort -n | awk '{a[NR] = $1} END {print a[int((NR + 1) / 2)]}')"
for f in "${first_frames[@]}"; do [ "$f" = "9999" ] && ff_never=$((ff_never + 1)); done
ff_txt="$(printf '%s ' "${first_frames[@]}" | sed 's/9999/never/g; s/ $//')"
printf '== first frame: %s -> median %s (budget 2000ms)%s ==\n' \
  "$ff_txt" "$([ "$first_frame_ms" = "9999" ] && echo never || echo "$first_frame_ms")" \
  "$([ "$ff_never" -gt 0 ] && printf ' [%s 次 never = 超过轮询预算]' "$ff_never")"
sleep 8  # warm-up: Ink startup, the first assembly, the first TTL cycle

if [ -n "$detail_flag" ]; then
  tmux -L "$sock" send-keys -t "$sess:console" 4 2>/dev/null || true
  sleep 1
  tmux -L "$sock" send-keys -t "$sess:console" Enter 2>/dev/null || true
  sleep 3
  printf '== detail view open for the sampling window (page 4 + Enter; %s) ==\n' \
    "$(tmux -L "$sock" capture-pane -p -t "$sess:console" 2>/dev/null | grep -c '详情' | tr -d ' ')"
fi

# P22/B2-B3: the project-settings view's own steady state (and its editor's) — the same red line.
if [ "${TEAM_PANEL_CPU_VIEW:-0}" = "1" ]; then
  tmux -L "$sock" send-keys -t "$sess:console" , 2>/dev/null || true
  sleep 0.8
  tmux -L "$sock" send-keys -t "$sess:console" Down Down Down Down Down 2>/dev/null || true
  sleep 0.6
  tmux -L "$sock" send-keys -t "$sess:console" Enter 2>/dev/null || true
  sleep 3
  if [ "${TEAM_PANEL_CPU_EDIT:-0}" = "1" ]; then
    tmux -L "$sock" send-keys -t "$sess:console" / 2>/dev/null || true
    sleep 0.5
    tmux -L "$sock" send-keys -l -t "$sess:console" 'TEAM_PULSE_NUDGE_GAP' 2>/dev/null || true
    sleep 0.5
    tmux -L "$sock" send-keys -t "$sess:console" Enter 2>/dev/null || true
    sleep 0.9
    tmux -L "$sock" send-keys -t "$sess:console" Enter 2>/dev/null || true
    sleep 1.2
    tmux -L "$sock" send-keys -l -t "$sess:console" '1200' 2>/dev/null || true
    sleep 0.6
  fi
  printf '== project-settings view open for the sampling window (%s)%s ==\n' \
    "$(tmux -L "$sock" capture-pane -p -t "$sess:console" 2>/dev/null | grep -c '项目设置' | tr -d ' ')" \
    "$([ "${TEAM_PANEL_CPU_EDIT:-0}" = "1" ] && printf ' + an editor holding a typed draft (nothing written)')"
fi

if [ -n "$compose_flag" ]; then
  tmux -L "$sock" send-keys -t "$sess:console" m 2>/dev/null || true
  sleep 1
  tmux -L "$sock" send-keys -l -t "$sess:console" 'a draft used to hold the compose line open for the red-line sample' 2>/dev/null || true
  sleep 1
  tmux -L "$sock" send-keys -t "$sess:console" C-v 2>/dev/null || true
  sleep 1
  printf '== compose line open for the sampling window (draft typed; %s) ==\n' \
    "$(tmux -L "$sock" capture-pane -p -t "$sess:console" 2>/dev/null | grep -c 'Enter 发送' | tr -d ' ')"
fi

time_pid="$(tmux -L "$sock" list-panes -t "$sess:console" -F '#{pane_pid}' 2>/dev/null | head -1)"
pane_pid="$(pgrep -P "${time_pid:-0}" 2>/dev/null | head -1)"
if [ -z "$time_pid" ] || [ -z "$pane_pid" ]; then
  printf 'panel-cpu: the console pane did not start (time=%s node=%s)\n' "$time_pid" "$pane_pid" >&2
  exit 3
fi

cpu_ticks_of() { # <pid>
  local f="/proc/$1/stat"
  [ -r "$f" ] || { printf '0'; return; }
  awk '{print $14 + $15}' "$f" 2>/dev/null || printf '0'
}

printf '== console CPU over %ss (pane %s → node %s, refresh %ss, hz %s; three equal sub-windows) ==\n' \
  "$secs" "$time_pid" "$pane_pid" "$refresh" "$hz"
printf '== measured process: %s\n' "$(ps -o args= -p "$pane_pid" 2>/dev/null | cut -c1-120)"
printf '%s\n' "   t   ps_lifetime%  pane_delta%  tree_now%"
t0="$(date +%s%3N)"
pane_prev="$(cpu_ticks_of "$pane_pid")"
pane_total=0
# 三等分：每个子窗算自己的均值（同一个采样总时长，不额外加长），中位 of 3 就是判红用的数。
secs_third=$(( secs / 3 )); [ "$secs_third" -lt 1 ] && secs_third=1
sub_pcts=()
for _sub in 1 2 3; do
  sub_end=$(( $(date +%s%3N) + secs_third * 1000 ))
  sub_start="$(date +%s%3N)"
  sub_ticks=0
  while :; do
    now="$(date +%s%3N)"
    remain_ms=$(( sub_end - now ))
    [ "$remain_ms" -le 0 ] && break
    nap="$(awk -v r="$remain_ms" -v i="$(( interval * 1000 ))" 'BEGIN { printf "%.1f", (r < i ? r : i) / 1000 }')"
    sleep "$nap"
    now="$(date +%s%3N)"
    pane_now="$(cpu_ticks_of "$pane_pid")"
    dt=$(( now - sub_start )); [ "$dt" -gt 0 ] || dt=1
    pane_pct="$(awk -v d="$((pane_now - pane_prev))" -v hz="$hz" -v ms="$dt" 'BEGIN{printf "%.2f", (d/hz)/(ms/1000)*100}')"
    ps_pct="$(ps -o %cpu= -p "$pane_pid" 2>/dev/null | tr -d ' ' || echo '?')"
    printf '%4ss   %-12s  %-11s  %s\n' "$(( (now - t0) / 1000 ))" "$ps_pct" "$pane_pct" "$pane_pct"
    sub_ticks=$(( sub_ticks + (pane_now - pane_prev) ))
    pane_total=$(( pane_total + (pane_now - pane_prev) ))
    pane_prev="$pane_now"
    sub_start="$now"
  done
  sub_span=$(( $(date +%s%3N) - (sub_end - secs_third * 1000) ))
  [ "$sub_span" -gt 0 ] || sub_span=$(( secs_third * 1000 ))
  sub_pcts+=("$(awk -v d="$sub_ticks" -v hz="$hz" -v ms="$sub_span" 'BEGIN{printf "%.2f", (d/hz)/(ms/1000)*100}')")
done
span_ms=$(( $(date +%s%3N) - t0 ))

# Ask the console to quit so `/usr/bin/time` can report the tree total. `q` collapses the window into
# the headless loop (B3), which leaves the wrapper killed by the respawn and the summary unwritten —
# so the fixture signals the console process directly instead of relying on a key.
for _ in $(seq 1 20); do
  kill -TERM "$pane_pid" 2>/dev/null || true
  sleep 0.5
  pgrep -P "$time_pid" >/dev/null 2>&1 || break
done
sleep 1
summary="$(grep -m1 'P12CPU' "$time_out" 2>/dev/null || true)"
printf '== /usr/bin/time (%s) ==\n%s\n' "$time_out" "${summary:-（no summary line）}"

pane_avg="$(printf '%s\n' "${sub_pcts[@]}" | sort -n | awk '{a[NR] = $1} END {print a[int((NR + 1) / 2)]}')"
pane_overall="$(awk -v d="$pane_total" -v hz="$hz" -v ms="$span_ms" 'BEGIN{printf "%.3f", (d/hz)/(ms/1000)*100}')"
tree_avg="?"
if [ -n "$summary" ]; then
  user="$(sed -n 's/.*user=\([0-9.]*\).*/\1/p' <<< "$summary")"
  sys="$(sed -n 's/.*sys=\([0-9.]*\).*/\1/p' <<< "$summary")"
  elapsed="$(sed -n 's/.*elapsed=\([0-9.]*\).*/\1/p' <<< "$summary")"
  if [ -n "$user" ] && [ -n "$sys" ] && [ -n "$elapsed" ]; then
    tree_avg="$(awk -v u="$user" -v s="$sys" -v e="$elapsed" 'BEGIN{printf "%.3f", (u+s)/e*100}')"
  fi
fi
printf '== pane CPU thirds: %s -> median %s%% (overall %s%% over %ss) of one core · reader tree %s%% ==\n' \
  "$(printf '%s ' "${sub_pcts[@]}" | sed 's/ $//')" "$pane_avg" "$pane_overall" "$((span_ms / 1000))" "$tree_avg"

# ── P26/G3：前提先于判定。不成立就打印实测三数并退出 4（既不是通过也不是红）。
# 注意：前提一行在**采样前**就打过一次；这里再打一次结果行，让日志尾部自带结论。
if ! pc_premise >/dev/null 2>&1; then
  printf '== load premise: loadavg %s > %s x %s cores -> SKIP (exit 4; the red line was not judged)\n' \
    "$(pc_load)" "$PREMISE_FACTOR" "$(pc_cores)" >&2
  ff_txt="never appeared"   # 顶层语句：不能用 local（只在函数里合法）
  [ -n "$first_frame_ms" ] && ff_txt="${first_frame_ms}ms"
  printf 'panel-cpu: SKIP — first frame %s, pane CPU %s%%, loadavg %s over the premise (%s x %s cores); the 2000ms / 1%% thresholds are unchanged\n' \
    "$ff_txt" "$pane_avg" "$(pc_load)" "$PREMISE_FACTOR" "$(pc_cores)" >&2
  exit 4
fi

if [ -z "$first_frame_ms" ]; then
  printf 'panel-cpu: RED — the first frame never appeared within 2.1s of the window spawn\n' >&2
  rc=2
elif [ "$first_frame_ms" -ge 2000 ]; then
  printf 'panel-cpu: RED — the interactive first frame took %sms (budget 2000ms, the 2s assembly line)\n' "$first_frame_ms" >&2
  rc=2
elif awk -v v="$pane_avg" 'BEGIN{exit !(v < 1)}'; then
  printf 'panel-cpu: OK — the pane process is under 1%% of one core and the first frame is in budget\n'
  rc=0
else
  printf 'panel-cpu: RED — the pane process is %s%% of one core (red line: <1%%)\n' "$pane_avg" >&2
  rc=2
fi
exit "$rc"
