#!/usr/bin/env bash
# CPU red-line fixture (pulse-console B1, tasks.md 1.5).
#
#   bash skills/teamsmith/tests/panel-cpu.sh [tree] [seconds]
#
# Runs the console in a fixture pane of a **private tmux server** (`-L p12cpu-$$`, the team session is
# never touched) and reports three numbers over the window:
#   * the interactive first frame — ms from the window spawn to the first visible title band
#     (V15/F8: the interactive path had no number at all; budget 2000ms, aligned with the spec's
#     "an uncached frame assembles within 2 seconds" red line);
#   * the console pane's own process — the red line ("less than 1% of one core in steady state"),
#     measured as /proc utime+stime deltas over the sampling window;
#   * the whole reader tree — the pane process **and every block reader it reaps**, from
#     `/usr/bin/time`'s user+sys for the command, which is what the reader trim is judged on.
#
# Exit: 0 the pane process is under 1% of one core and the first frame made its budget; 2 either
# red line broke; 3 setup failure.
set -uo pipefail

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tree="${1:-$(cd -P "$here/../../.." && pwd)}"
secs="${2:-${TEAM_PANEL_CPU_SECS:-60}}"
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
pane_cmd="cd '$tree' && exec '$time_bin' -o '$time_out' -f 'P12CPU user=%U sys=%S elapsed=%e' -- '$js' '$panel' --root '$tree' --team-cli '$tree/skills/teamsmith/scripts/team' --no-pulse --refresh $refresh"
tmux -L "$sock" new-session -d -s "$sess" -x 140 -y 34 -c "$tree" "sleep 600"
first_frame_ms=""
spawn_ms="$(date +%s%3N)"
tmux -L "$sock" new-window -d -t "$sess" -n console -c "$tree" "$pane_cmd"
# F8: the interactive first frame is measured, not promised — poll the pane for the title band.
for _ in $(seq 1 20); do
  sleep 0.1
  if tmux -L "$sock" capture-pane -p -t "$sess:console" 2>/dev/null | grep -q 'teamsmith pulse'; then
    first_frame_ms=$(( $(date +%s%3N) - spawn_ms ))
    break
  fi
done
if [ -z "$first_frame_ms" ]; then
  # one last look before the slow warm-up path judges the process instead
  sleep 1
  tmux -L "$sock" capture-pane -p -t "$sess:console" 2>/dev/null | grep -q 'teamsmith pulse' \
    && first_frame_ms=$(( $(date +%s%3N) - spawn_ms ))
fi
printf '== first frame: %s (budget 2000ms) ==\n' "${first_frame_ms:-never}"
sleep 8  # warm-up: Ink startup, the first assembly, the first TTL cycle

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

printf '== console CPU over %ss (pane %s → node %s, refresh %ss, hz %s) ==\n' \
  "$secs" "$time_pid" "$pane_pid" "$refresh" "$hz"
printf '== measured process: %s\n' "$(ps -o args= -p "$pane_pid" 2>/dev/null | cut -c1-120)"
printf '%s\n' "   t   ps_lifetime%  pane_delta%  tree_now%"
t0="$(date +%s%3N)"
pane_prev="$(cpu_ticks_of "$pane_pid")"
t_prev="$t0"
pane_total=0
while :; do
  sleep "$interval"
  now="$(date +%s%3N)"
  pane_now="$(cpu_ticks_of "$pane_pid")"
  dt=$((now - t_prev)); [ "$dt" -gt 0 ] || dt=1
  pane_pct="$(awk -v d="$((pane_now - pane_prev))" -v hz="$hz" -v ms="$dt" 'BEGIN{printf "%.2f", (d/hz)/(ms/1000)*100}')"
  ps_pct="$(ps -o %cpu= -p "$pane_pid" 2>/dev/null | tr -d ' ' || echo '?')"
  printf '%4ss   %-12s  %-11s  %s\n' "$(( (now - t0) / 1000 ))" "$ps_pct" "$pane_pct" "$pane_pct"
  pane_total=$((pane_total + (pane_now - pane_prev)))
  pane_prev="$pane_now"
  t_prev="$now"
  [ $(( (now - t0) / 1000 )) -ge "$secs" ] && break
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

pane_avg="$(awk -v d="$pane_total" -v hz="$hz" -v ms="$span_ms" 'BEGIN{printf "%.3f", (d/hz)/(ms/1000)*100}')"
tree_avg="?"
if [ -n "$summary" ]; then
  user="$(sed -n 's/.*user=\([0-9.]*\).*/\1/p' <<< "$summary")"
  sys="$(sed -n 's/.*sys=\([0-9.]*\).*/\1/p' <<< "$summary")"
  elapsed="$(sed -n 's/.*elapsed=\([0-9.]*\).*/\1/p' <<< "$summary")"
  if [ -n "$user" ] && [ -n "$sys" ] && [ -n "$elapsed" ]; then
    tree_avg="$(awk -v u="$user" -v s="$sys" -v e="$elapsed" 'BEGIN{printf "%.3f", (u+s)/e*100}')"
  fi
fi
printf '== summary over %ss: console pane process %s%% of one core · reader tree %s%% of one core ==\n' \
  "$((span_ms / 1000))" "$pane_avg" "$tree_avg"

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
