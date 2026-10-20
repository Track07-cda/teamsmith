#!/usr/bin/env bash
# CPU / first-frame **reference readings** (pulse-console B1, tasks.md 1.5; P316).
#
#   bash skills/teamsmith/tests/panel-cpu.sh [tree] [seconds]
#   TEAM_PANEL_CPU_PAGE=4 bash skills/teamsmith/tests/panel-cpu.sh   # park it on the board page
#   TEAM_PANEL_CPU_DETAIL=1 bash ...                                 # open the markdown detail view
#   TEAM_PANEL_CPU_COMPOSE=1 bash ...                                # hold the compose line open
#   TEAM_PANEL_CPU_VIEW=1 bash ...                                   # keep the project-settings view open
#   TEAM_PANEL_CPU_VIEW=1 TEAM_PANEL_CPU_EDIT=1 bash ...             # …and an editor holding a typed draft
#
# 用户裁定（2026-10-19，第二条）：**性能只能是参考指标，不能作为阻塞**。本夹具照旧测量首帧（三次独立
# spawn 的中位）与窗格 CPU（采样窗三等分的中位），样本与树 CPU 图都打印出来，行首是「· 参考」——
# **没有阈值判定、没有负载前提、没有 SKIP**：机器多忙都照测，数字是给人看的。
#
#   Exit: 0 测到了（读数照打，不管数值多大）
#         3 搭建失败（没有 tmux / node / 面板 bundle / 窗格没起来）
#
# 环境姿态（M51 保留）：树 CPU 图用 `/usr/bin/time -o/-f` 读；缺这个工具时只打印一行「读不到」，
# 不影响首帧/窗格 CPU 的读数，也不改变退出码（它是附带读数，本来就不是判定依据）。
set -uo pipefail

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# P53/P68：临时根的唯一创建者（固定中性测量目标就建在它下面）
. "$here/lib/tmp-root.sh"
# P162：破坏性调用（kill-server/kill-session/kill-window）动手前先证明私有 socket 生效
. "$here/lib/tmux-iso.sh"
tree="${1:-$(cd -P "$here/../../.." && pwd)}"
secs="${2:-${TEAM_PANEL_CPU_SECS:-60}}"

# ── 机器读数（P316：只打印，不判绿红，不设前提）──────────────────────────────────────────
pc_load() { cut -d' ' -f1 /proc/loadavg 2>/dev/null || printf '?'; }
pc_cores() { nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || printf '0'; }
pc_reference_machine() {
  printf '· 参考 机器：loadavg %s · %s 核 · 采样窗 %ss（本夹具不判绿红）\n' \
    "$(pc_load)" "$(pc_cores)" "$secs"
}
refresh="${TEAM_PANEL_CPU_REFRESH:-3}"
interval=5
sock="p12cpu-$$"
sess="p12cpu-$$"
js="${TEAM_JS_BIN:-$(command -v node || true)}"
[ -n "$js" ] || js="$(command -v bun || true)"

cleanup() {
  # P162：收尾先证明私有 socket 生效（不成立就拒绝；cleanup 里不许 exit）
  tmux_iso_guard_soft "panel-cpu" "收尾：私有 server" --tmpdir "${TMUX_TMPDIR:-}" --sock-name "$sock" \
    && tmux -L "$sock" kill-server 2>/dev/null || true
  # tmux 在服务器已死时会把 socket 文件留在 /tmp/tmux-<uid>/：夹具自己收干净
  rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$sock" 2>/dev/null || true
  rm -rf "${time_out:-}.state" 2>/dev/null || true
  tmp_root_reap_all   # P68：中性测量目标（owned 家族）也收掉
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
if [ -z "$time_bin" ]; then
  printf '· 参考 面板读数：没测到（缺 GNU time = /usr/bin/time；树 CPU 图是附带读数，本环境没有它）\n' >&2
  exit 0
fi

panel="$tree/skills/teamsmith/scripts/panel/panel.js"
[ -f "$panel" ] || { printf 'panel-cpu: no bundle at %s\n' "$panel" >&2; exit 3; }

# ── P68/fixture-waits-for-landed-reads：测量目标固定 ────────────────────────────────────────────
# 面板首帧取决于项目的数据量，不取决于面板代码。旧形状把 `--root` 指到**调用者的工作树**，于是同一个
# bundle 在积累态的仓库里 3683 ms、在全新项目里 391 ms（P52 F4）——数字描述那个 checkout，不是面板；
# 从两个工作树跑同一个命令会得到两个结论。现在夹具自己建一个中性参考项目（tmp-root 的 owned 家族 +
# 真 `team init`，与其它夹具同形），`--root` 只指它；bundle 与 CLI 仍来自**被测代码树**，两个名字都
# 印出来（requirement：A measuring fixture measures a fixed tree, not the caller's worktree）。
neut_root="$(tmp_root_create panel-cpu-target)" \
  || { printf 'panel-cpu: 建不出中性测量目标（tmp_root_create）\n' >&2; exit 3; }
# `team init` 不能继承调用者的团队身份（同其它夹具的首步隔离；这里只对 init 这一个子进程降掉）。
pc_init_clean=(env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_ROOT_SOURCE -u TEAM_ROOT_WAS -u TEAM_PROJECT \
  -u TEAM_SESSION -u TEAM_SESSION_FROM -u TEAM_PM_WINDOW -u TEAM_AGENTS -u TEAM_DOCS_DIR -u TEAM_WORKTREES_DIR \
  -u TEAM_GATES -u TEAM_VCS -u TEAM_CONFIG_FILE -u TEAM_ALLOW_FOREIGN_SESSION -u TEAM_PULSE_WINDOW \
  -u TEAM_WATCH_WINDOW -u TEAM_STATE_DIR -u TEAM_JS_BIN)
( cd "$neut_root" && git init -q -b main && git config user.email panel-cpu@teamsmith && git config user.name panel-cpu ) \
  >/dev/null 2>&1
( cd "$neut_root" && "${pc_init_clean[@]}" bash "$tree/skills/teamsmith/scripts/team" init \
    --session "$sess" --agents "dev verify" --vcs local --gates "true" --docs docs/team --task-models 'routine=deepseek/deepseek-flash analysis=xai/grok-4.6 verify=kimi-coding/k3-256k' --pm-model 'deepseek/deepseek-flash' ) \
  >"$neut_root/init.log" 2>&1 \
  || { printf 'panel-cpu: 中性测量目标的 team init 失败（见 %s/init.log）\n' "$neut_root" >&2; tail -3 "$neut_root/init.log" >&2; exit 3; }
printf '== measured project root: %s (neutral fixture project — not the caller worktree) ==\n' "$neut_root"
printf '== console bundle under test: %s (tree under test %s) ==\n' "$panel" "$tree"

hz="$(getconf CLK_TCK 2>/dev/null || echo 100)"
team_tmp_root_prepare >/dev/null 2>&1 || true
time_out="$(mktemp "$(team_tmp_root)/teamsmith-p12cpu.$(tmp_root_ns).XXXXXX")"
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
pane_cmd="cd '$neut_root' && ${compose_env}exec '$time_bin' -o '$time_out' -f 'P12CPU user=%U sys=%S elapsed=%e' -- '$js' '$panel' --root '$neut_root' --team-cli '$tree/skills/teamsmith/scripts/team' --no-pulse --refresh $refresh${page_flag}${state_flag}"
tmux -L "$sock" new-session -d -s "$sess" -x 140 -y 34 -c "$neut_root" "sleep 600"
pc_reference_machine    # 参考机器读数（不判绿红）
# 首帧：三次独立 spawn 各量一次「窗口创建 → 第一帧可见」，取中位（中位 of 3）。
# `never` = 300s 轮询视界内没出现（读数的一种形态），记成 9999 参与中位，但打印时保留 `never`。
first_frames=()
ff_never=0
measure_first_frame() { # → 毫秒数（没出现 → 9999）
  local ms="" t0
  tmux -L "$sock" kill-window -t "$sess:console" 2>/dev/null || true
  sleep 0.4
  t0="$(date +%s%3N)"
  tmux -L "$sock" new-window -d -t "$sess" -n console -c "$neut_root" "$pane_cmd" 2>/dev/null || true
  # F8: the interactive first frame is measured, not promised — poll the pane for the title band.
  # P316：上限 300s（只防死等）；首帧多久都照打，不判快慢。
  for _ in $(seq 1 3000); do
    sleep 0.1
    if tmux -L "$sock" capture-pane -p -t "$sess:console" 2>/dev/null | grep -q 'teamsmith pulse'; then
      ms=$(( $(date +%s%3N) - t0 )); break
    fi
  done
  if [ -z "$ms" ]; then
    sleep 1   # 最后一次确认（没等到才记 never）
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
printf '· 参考 首帧：%s -> 中位 %s%s\n' \
  "$ff_txt" "$([ "$first_frame_ms" = "9999" ] && echo never || echo "$first_frame_ms")" \
  "$([ "$ff_never" -gt 0 ] && printf ' [%s 次 never = 超过等待视界]' "$ff_never")"
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

# 窗格进程树就绪（上限 300s：只防死等，不判启动快慢；P316）
for _i in $(seq 1 3000); do
  time_pid="$(tmux -L "$sock" list-panes -t "$sess:console" -F '#{pane_pid}' 2>/dev/null | head -1)"
  pane_pid="$(ps -o pid= --ppid "${time_pid:-0}" 2>/dev/null | head -1 | tr -d ' ')"  # ps 而不是 pgrep：pgrep 是团队 shim（身份护栏），夹具里读不到子进程
  [ -n "$time_pid" ] && [ -n "$pane_pid" ] && break
  sleep 0.1
done
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
printf '· 参考 窗格 CPU 三等分：%s -> 中位 %s%%（整窗 %s%%，%ss）· 读进程树 %s%%\n' \
  "$(printf '%s ' "${sub_pcts[@]}" | sed 's/ $//')" "$pane_avg" "$pane_overall" "$((span_ms / 1000))" "$tree_avg"

# ── P316：参考读数，不是判定 ────────────────────────────────────────────────────────────
pc_target="measured root $neut_root · bundle $panel"
ff_txt="never appeared"
[ -n "$first_frame_ms" ] && ff_txt="${first_frame_ms}ms"
printf '· 参考 首帧：%s（3 次独立 spawn 的中位）｜ 窗格 CPU：%s%%（三等分中位）｜ 树 CPU：%s%%（%s）\n' \
  "$ff_txt" "$pane_avg" "$tree_avg" "$pc_target"
printf '· 参考 机器：loadavg %s · %s 核 · 采样窗 %ss\n' "$(pc_load)" "$(pc_cores)" "$secs"
exit 0
