#!/usr/bin/env bash
# A deliberately slow `team __panel-data` stand-in for the keystroke fixture (tasks.md 1.4).
#
# The probe calls the tree's own data layer with `--team-cli` pointing here, so the refresh is a
# controlled five seconds instead of a busy repository. Both request shapes are served: the full
# object (pre-change data layer) and one block per call (post-change data layer).
set -euo pipefail

sleep "${KEYPROBE_STUB_SLEEP:-5}"

block=""
prev=""
for a in "$@"; do
  [ "$prev" = "--block" ] && block="$a"
  prev="$a"
done

emit_full() {
  cat <<'JSON'
{"panel": {"project": "keyprobe", "timestamp": "2026-01-01T00:00:00Z", "interval": 900,
 "standby": {"on": false, "reason": ""},
 "pm": {"state": "absent", "detail": "", "evidence": ""},
 "pending": {"inbox": 0, "reports": 0, "todo": 0, "wip": 0, "review": 0, "blocked": 0, "stopped": 0, "total": 0, "text": ""},
 "outbox": {"queued": 0, "held": 0, "oldest_age_s": null, "forced": 0},
 "capacity": {"ram_avail_mb": 4000, "swap_free_mb": 1024, "agents": 2, "spark": [4000, 4010]},
 "agents": [], "recent": [], "activity_source": ""}, "activity": []}
JSON
}

case "$block" in
  "")       emit_full ;;
  frame)    printf '%s\n' '{"project": "keyprobe", "timestamp": "2026-01-01T00:00:00Z", "interval": 900, "standby": {"on": false, "reason": ""}, "activity_source": ""}' ;;
  pm)       printf '%s\n' '{"state": "absent", "detail": "", "evidence": ""}' ;;
  pending)  printf '%s\n' '{"inbox": 0, "reports": 0, "todo": 0, "wip": 0, "review": 0, "blocked": 0, "stopped": 0, "total": 0, "text": ""}' ;;
  outbox)   printf '%s\n' '{"queued": 0, "held": 0, "oldest_age_s": null, "forced": 0}' ;;
  capacity) printf '%s\n' '{"ram_avail_mb": 4000, "swap_free_mb": 1024, "agents": 2, "spark": [4000, 4010]}' ;;
  agents)   printf '%s\n' '[]' ;;
  recent)   printf '%s\n' '[]' ;;
  activity) printf '%s\n' '[]' ;;
  *)        printf 'keyprobe-stub: unknown block %s\n' "$block" >&2; exit 2 ;;
esac
