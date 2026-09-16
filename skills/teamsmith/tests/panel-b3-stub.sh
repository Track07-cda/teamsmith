#!/usr/bin/env bash
# A deterministic `team __panel-data` stand-in for the console-surface fixtures (pulse-console B3).
#
#   bash panel-b3-stub.sh --root DIR __panel-data --block <name> [--events N] [--no-activity]
#
# Every block is fixed data with fixed ages, so the snapshot suite can pin widths × themes byte for
# byte. `--block nope` exits 2 (the closed set), and `--block health` can be made to fail with
# B3_STUB_FAIL=health for the degraded-rendering checks.
set -uo pipefail

block=""
prev=""
for a in "$@"; do
  [ "$prev" = "--block" ] && block="$a"
  prev="$a"
done

if [ -n "${B3_STUB_FAIL:-}" ] && [ "$block" = "${B3_STUB_FAIL}" ]; then
  printf 'stub: degrading %s on purpose\n' "$block" >&2
  exit 1
fi

json_str() { printf '"%s"' "$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"; }
agents_json() { cat <<'JSON'
[
 {"name": "dev", "state": "running", "task": "P14", "branch": "task/P14-apply-pulse-console-b3", "dirty": true,
  "ahead": 3, "upstream_ahead": "", "model": "deepseek/deepseek-flash", "session_tokens": 41000,
  "session_window": 272000, "session_text": "41k/272k"},
 {"name": "verify", "state": "absent", "task": "", "branch": "-", "dirty": false,
  "ahead": null, "upstream_ahead": "", "model": "-", "session_tokens": 0,
  "session_window": 0, "session_text": "-"}
]
JSON
}

board_json() { cat <<'JSON'
{"rows": [
 {"id": "P14", "title": "控制台表面：三页/设置/鼠标/i18n/响应式", "agent": "dev", "branch": "task/P14", "deps": "-", "state": "wip"},
 {"id": "V14", "title": "独立复验：控制台表面", "agent": "verify", "branch": "-", "deps": "P14", "state": "todo"},
 {"id": "P13", "title": "消息入口与三个动作", "agent": "dev", "branch": "task/P13", "deps": "P12", "state": "done"},
 {"id": "P12", "title": "异步数据层", "agent": "dev", "branch": "task/P12", "deps": "-", "state": "done"},
 {"id": "P11", "title": "提案", "agent": "dev2", "branch": "task/P11", "deps": "-", "state": "done"},
 {"id": "P10", "title": "Ink 面板重写", "agent": "dev", "branch": "task/P10", "deps": "-", "state": "done"},
 {"id": "P9", "title": "提案", "agent": "dev2", "branch": "task/P9", "deps": "-", "state": "done"},
 {"id": "P8", "title": "pulse 改名", "agent": "dev2", "branch": "task/P8", "deps": "-", "state": "done"},
 {"id": "P7", "title": "提案", "agent": "dev2", "branch": "task/P7", "deps": "-", "state": "done"},
 {"id": "P6", "title": "延后投递", "agent": "dev", "branch": "task/P6", "deps": "-", "state": "done"},
 {"id": "V21", "title": "阻塞夹具", "agent": "verify", "branch": "-", "deps": "-", "state": "blocked"}
],
 "counts": {"todo": 1, "wip": 1, "review": 0, "done": 7, "blocked": 1, "dropped": 0},
 "total": 11,
 "deliveries": [
   {"id": "P13", "agent": "dev", "at": "2026-09-16T09:30:00Z"},
   {"id": "P12", "agent": "dev", "at": "2026-09-16T08:00:00Z"},
   {"id": "V13", "agent": "verify", "at": "2026-09-15T09:00:00Z"}
 ]}
JSON
}

changes_json() { cat <<'JSON'
{"available": true, "source": "openspec", "count": 2, "changes": [
 {"id": "pulse-console", "done": 8, "total": 28, "age": "44m ago", "phase": "apply"},
 {"id": "rename-watchdog", "done": 12, "total": 12, "age": "2d ago", "phase": "verify"}
]}
JSON
}

specs_json() { cat <<'JSON'
{"available": true, "count": 12, "requirements": 45, "specs": [
 {"name": "panel", "requirements": 12},
 {"name": "watchdog", "requirements": 10},
 {"name": "delivery-guard", "requirements": 9},
 {"name": "dispatch", "requirements": 7}
]}
JSON
}

decisions_json() { cat <<'JSON'
{"count": 40, "recent": ["D40 · 2026-09-16 · 决定 — 控制台分三批", "D39 · 2026-09-16 · 决定 — i18n 进 B3", "D38 · 2026-09-15 · 决定 — q 收起不清巡检"]}
JSON
}

outbox_list_json() { cat <<'JSON'
{"queued": 2, "held": 1, "entries": [
 {"name": "1758000000000-001-pm.msg", "state": "queued", "age_s": 42, "target": "pm-skills:pm", "kind": "notify", "from": "dev", "reason": "", "text": "第一行\n第二行"},
 {"name": "1758000001000-002-pm.msg", "state": "queued", "age_s": 7, "target": "pm-skills:pm", "kind": "say", "from": "verify", "reason": "", "text": "排队中的第二条"},
 {"name": "1757990000000-003-pm.msg", "state": "held", "age_s": 3600, "target": "pm-skills:pm", "kind": "notify", "from": "dev", "reason": "draft-raced", "text": "被扣住的副本"}
]}
JSON
}

inbox_json() { cat <<'JSON'
{"agents": [
 {"agent": "dev", "inbox_new": 1, "inbox_lines": 12, "inbox_age_s": 120, "inbox_tail": "一行简报", "thread_lines": 8, "thread_age_s": 300, "thread_tail": "一条线索"},
 {"agent": "verify", "inbox_new": 0, "inbox_lines": 3, "inbox_age_s": 900, "inbox_tail": "", "thread_lines": 2, "thread_age_s": 1200, "thread_tail": ""}
]}
JSON
}

patrol_json() { cat <<'JSON'
{"count": 5, "lines": ["10:00:00Z 容量 RAM 4040MB", "10:15:00Z 待办 3：叫醒 PM", "10:30:00Z 无待办：不叫醒 PM", "10:45:00Z 待办 1：叫醒 PM", "11:00:00Z 无待办：不叫醒 PM"]}
JSON
}

case "$block" in
  frame)
    printf '%s\n' '{"project": "fixture", "timestamp": "2026-09-16T10:00:00Z", "interval": 900, "standby": {"on": false, "reason": ""}, "activity_source": ""}'
    ;;
  pm)
    printf '%s\n' '{"state": "running", "detail": "", "evidence": "pid 12345"}'
    ;;
  pending)
    printf '%s\n' '{"inbox": 1, "reports": 2, "todo": 1, "wip": 1, "review": 0, "blocked": 1, "stopped": 0, "total": 6, "text": "未读 1 · 待复验 2 · blocked 1"}'
    ;;
  outbox)
    printf '%s\n' '{"queued": 2, "held": 1, "oldest_age_s": 42, "forced": 0}'
    ;;
  capacity)
    printf '%s\n' '{"ram_avail_mb": 4040, "swap_free_mb": 31306, "agents": 5, "spark": [4000, 4010, 4020, 4030, 4040]}'
    ;;
  agents)      agents_json ;;
  recent)
    printf '%s\n' '["10:00:01 夹具动作一", "10:00:02 夹具动作二", "10:00:03 夹具动作三"]'
    ;;
  activity)
    printf '%s\n' '[]'
    ;;
  board)       board_json ;;
  changes)     changes_json ;;
  specs)       specs_json ;;
  decisions)   decisions_json ;;
  outbox_list) outbox_list_json ;;
  inbox)       inbox_json ;;
  patrol)      patrol_json ;;
  health)
    printf '%s\n' '{"version": "1.38.0", "doc_version": "1.38.0", "doctor": "ok", "gates": "—"}'
    ;;
  *)
    printf 'panel-b3-stub: unknown block %s\n' "${block:-<none>}" >&2
    exit 2
    ;;
esac
