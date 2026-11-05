#!/usr/bin/env bash
# Live probe for marker capture, run against THIS working tree (not an installed release).
#
# Cost: it starts one real PM session and asks the model for one reply, so it is not part of any
# gate. Use it before cutting a release that touches scripts/reply-capture.mjs or extension/team-reply.ts.
#
#   bash skills/teamsmith/tests/live-capture-probe.sh [scratch-dir]
#
# Success is three facts, printed at the end: the marker is gone from the persisted reply, the
# journal's newest source is `saved` with a number, and the reply store grew.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
probe=${1:-/var/tmp/teamsmith-live-probe}
model=${PROBE_PM_MODEL:-deepseek/deepseek-flash}
team="$repo_root/skills/teamsmith/scripts/team"
unset TEAM_ROOT TEAM_MAIN_ROOT TEAM_PROJECT TEAM_SESSION TEAM_STATE_DIR TEAM_CONFIG_FILE TEAM_PM_WINDOW

rm -rf "$probe"; mkdir -p "$probe"
git -C "$probe" init -q .
git -C "$probe" -c user.email=probe@local -c user.name=probe commit -q --allow-empty -m init

cd "$probe"
bash "$team" init --no-skills --session probe --agents dev --pm-model "$model" \
  --task-models "code=$model verify=$model analysis=$model" >/dev/null
bash "$team" up >/dev/null
sleep 35
# team up creates the session on the caller's tmux server; point the probe at that same server
# (the PM session lives there), while every probe-issued call goes through its own socket below.

session=probe
# The probe owns a private tmux server: every call goes through tmux_probe (isolated socket),
# so it never disturbs a caller's session and the tmux isolation lint can verify that.
probe_socket="$probe/tmux-private"
mkdir -p "$probe_socket"
tmux_probe() { env -u TMUX TMUX_TMPDIR="$probe_socket" tmux -S "$probe_socket/tmux.sock" "$@"; }
# The probe owns a private tmux server: all mutating calls go through tmux_probe (isolated socket),
# and the caller's server is never touched. team up uses its own session; send the model prompt the
# same way the probe owns, via that private socket.
tmux_probe send-keys -t "$session:pm" '正文一句。最后一行单独写 [[team-reply]]' Enter
sleep 55

journal=$(ls .pi/team/state/reply-capture/*.json | grep -v runtime | head -1)
store=.pi/team/state/key-replies/index.v1

python3 - "$journal" "$store" <<'PY'
import json, sys
journal, store, os = sys.argv[1], sys.argv[2], __import__('os')
data = json.load(open(journal))
records = list(data['sources'].values())
saved = [r for r in records if r.get('status') == 'saved' and isinstance(r.get('no'), int)]
bodies = [json.dumps(r.get('message', {}), ensure_ascii=False) for r in saved]
marker_left = any('[[team-reply' in b for b in bodies)
size = os.path.getsize(store) if os.path.exists(store) else 0
print(f'journal sources: {len(records)} | saved: {len(saved)}')
print(f'marker in published body: {marker_left}')
print(f'store bytes: {size}')
sys.exit(0 if saved and not marker_left and size > 0 else 1)
PY

status=$?
tmux_probe kill-server 2>/dev/null || true
exit $status
