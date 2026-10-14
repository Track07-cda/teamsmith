#!/usr/bin/env bash
# A deterministic `team __panel-data` stand-in for the console-surface fixtures (pulse-console B3).
#
#   bash panel-b3-stub.sh --root DIR __panel-data --block <name> [--events N] [--no-activity]
#
# Every block is fixed data with fixed ages, so the snapshot suite can pin widths × themes byte for
# byte. `--block nope` exits 2 (the closed set), and `--block health` can be made to fail with
# B3_STUB_FAIL=health for the degraded-rendering checks.
#
# Two deterministic size knobs (used by the bounded-frame flip, which needs an overview whose
# natural content is ~30 rows): B3_STUB_AGENTS=N widens the agent table, B3_STUB_RECENT=N lengthens
# the recent-events block (pass the matching `--events N` to the panel). Both default to the
# original fixture, so the pinned snapshots are untouched.
set -uo pipefail

block=""
prev=""
detail_id=""
detail_file=""
detail_source=""
for a in "$@"; do
  [ "$prev" = "--block" ] && block="$a"
  [ "$prev" = "--id" ] && detail_id="$a"
  [ "$prev" = "--file" ] && detail_file="$a"
  [ "$prev" = "--source" ] && detail_source="$a"
  prev="$a"
done

if [ -n "${B3_STUB_FAIL:-}" ] && [ "$block" = "${B3_STUB_FAIL}" ]; then
  printf 'stub: degrading %s on purpose\n' "$block" >&2
  exit 1
fi

# P18/B3: append every block name this stub is asked for, so a test can prove which children a
# frame really spawned (the detail reader must be absent while the view is closed).
if [ -n "${B3_STUB_SPAWN_LOG:-}" ]; then
  printf '%s\n' "$block" >> "$B3_STUB_SPAWN_LOG" 2>/dev/null || true
fi

json_str() { printf '"%s"' "$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"; }
# Multiline-safe variant: the whole text is slurped first, then escaped (backslash, quote, CR,
# tab, newline — in that order, so an escape added by one step is never re-escaped by the next).
json_str_ml() {
  printf '"%s"' "$(printf '%s' "$1" | sed -e ':a' -e 'N' -e '$!ba' -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\r//g' -e 's/\t/\\t/g' -e 's/\n/\\n/g')"
}
agents_json() {
  if [ "${B3_STUB_AGENTS:-2}" != "2" ]; then
    # N deterministic agent rows (the tall-overview fixture); row 1 is the base fixture's running
    # dev, the rest are idle fixture agents.
    local n="${B3_STUB_AGENTS}" i
    printf '[\n'
    printf ' {"name": "dev", "state": "running", "task": "P14", "branch": "task/P14-apply-pulse-console-b3", "dirty": true, "ahead": 3, "upstream_ahead": "", "model": "deepseek/deepseek-flash", "session_tokens": 41000, "session_window": 272000, "session_text": "41k/272k"}'
    for ((i = 2; i <= n; i++)); do
      printf ',\n {"name": "dev%s", "state": "absent", "task": "", "branch": "-", "dirty": false, "ahead": null, "upstream_ahead": "", "model": "-", "session_tokens": 0, "session_window": 0, "session_text": "-"}' "$i"
    done
    printf '\n]\n'
    return 0
  fi
  cat <<'JSON'
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

recent_json() { # B3_STUB_RECENT lines, deterministic timestamps; unset = the original fixture
  if [ -z "${B3_STUB_RECENT:-}" ]; then
    printf '%s\n' '["10:00:01 夹具动作一", "10:00:02 夹具动作二", "10:00:03 夹具动作三"]'
    return 0
  fi
  local n="${B3_STUB_RECENT}" i out=""
  for ((i = 1; i <= n; i++)); do
    # Row 1 is 10:00:01 — the base fixture's first timestamp, so the default output is unchanged.
    printf -v t '%02d:%02d:%02d' 10 $((i / 60)) $((i % 60))
    out="$out${out:+, }\"$t 夹具动作$i\""
  done
  printf '[%s]\n' "$out"
}

board_json() {
  # B3_STUB_BOARD_EMPTY=1: no rows, so the work page's preview blocks are the only possible rows.
  if [ "${B3_STUB_BOARD_EMPTY:-0}" = "1" ]; then
    printf '%s\n' '{"rows": [], "counts": {"todo": 0, "wip": 0, "review": 0, "done": 0, "blocked": 0, "dropped": 0}, "total": 0, "deliveries": []}'
    return 0
  fi
  # B3_STUB_BOARD_FILE=<path>: serve that file verbatim — the board-page fixtures rewrite it between
  # refreshes to prove the focus survives a reorder and falls back when the entry leaves the board.
  if [ -n "${B3_STUB_BOARD_FILE:-}" ] && [ -r "${B3_STUB_BOARD_FILE}" ]; then
    cat "${B3_STUB_BOARD_FILE}"
    return 0
  fi
  if [ -z "${B3_STUB_DONE:-}" ]; then
    cat <<'JSON'
{"rows": [
 {"id": "P14", "title": "控制台表面：三页/设置/鼠标/i18n/响应式", "agent": "dev", "branch": "task/P14", "deps": "-", "state": "wip", "phase": "apply"},
 {"id": "V14", "title": "独立复验：控制台表面", "agent": "verify", "branch": "-", "deps": "P14", "state": "todo", "phase": "verify"},
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
    return 0
  fi
  # B3_STUB_DONE=N: the same head plus N generated `done` rows (newest first) and a dropped pair —
  # the fixture the folded-history growth and the kanban's long-lane scroll are checked against.
  local n="${B3_STUB_DONE}" i
  printf '{"rows": [\n'
  printf ' {"id": "P14", "title": "控制台表面", "agent": "dev", "branch": "task/P14", "deps": "-", "state": "wip", "phase": "apply"},\n'
  printf ' {"id": "V14", "title": "独立复验", "agent": "verify", "branch": "-", "deps": "P14", "state": "todo", "phase": "verify"},\n'
  for ((i = 1; i <= n; i++)); do
    printf ' {"id": "D%02d", "title": "历史条目 %02d", "agent": "dev2", "branch": "task/D%02d", "deps": "-", "state": "done"},\n' "$i" "$i" "$i"
  done
  printf ' {"id": "X1", "title": "被放弃的条目", "agent": "dev2", "branch": "-", "deps": "-", "state": "dropped"},\n'
  printf ' {"id": "V21", "title": "阻塞夹具", "agent": "verify", "branch": "-", "deps": "-", "state": "blocked"}\n'
  printf '],\n "counts": {"todo": 1, "wip": 1, "review": 0, "done": %s, "blocked": 1, "dropped": 1},\n "total": %s,\n "deliveries": [\n   {"id": "P14", "agent": "dev", "at": "2026-09-16T09:30:00Z"}\n ]}\n' "$n" "$((n + 4))"
}

# P249: the preview sources' stand-in (`--source spec|change|decision`). One fixed capability
# `demo`, one fixed change `demo` (its three artifacts) and one fixed decision `D7`; any other id
# answers the real reader's empty file list + reason, and `--file` must be one of the discovered
# paths (anything else exits non-zero). `B3_STUB_PREVIEWS=empty` empties the three preview blocks
# themselves, for the work page's no-dead-item fixture.
preview_json() { # <source> <id> [file]
  local source="$1" id="$2" want="${3:-}"
  local file="" text="" files="" reason=""
  case "$source" in
    spec)
      if [ "$id" = "demo" ] || [ "$id" = "panel" ]; then
        file="openspec/specs/$id/spec.md"
        files="$(printf '[{"tab": "spec", "name": "spec.md", "path": "openspec/specs/%s/spec.md", "size": 64, "truncated": false}]' "$id")"
        if [ "${B3_STUB_PREVIEW_LONG:-0}" -gt 0 ] 2>/dev/null; then
          local i
          text="# $id spec

### Requirement: One

body"
          for ((i = 1; i <= B3_STUB_PREVIEW_LONG; i++)); do printf -v line 'spec line %02d with a few words to read' "$i"; text="$text
$line"; done
        else
          text="# $id spec

### Requirement: One

body"
        fi
      else
        reason="openspec/specs/$id/spec.md 不存在"
      fi
      ;;
    change)
      if [ "$id" = "demo" ] || [ "$id" = "pulse-console" ]; then
        files="$(printf '[{"tab": "proposal", "name": "proposal.md", "path": "openspec/changes/%s/proposal.md", "size": 30, "truncated": false}, {"tab": "design", "name": "design.md", "path": "openspec/changes/%s/design.md", "size": 30, "truncated": false}, {"tab": "tasks", "name": "tasks.md", "path": "openspec/changes/%s/tasks.md", "size": 30, "truncated": false}]' "$id" "$id" "$id")"
        case "$want" in
          ''|"openspec/changes/$id/proposal.md") file="openspec/changes/$id/proposal.md"; text="# $id proposal

the proposal body" ;;
          "openspec/changes/$id/design.md") file="$want"; text="# $id design

the design body" ;;
          "openspec/changes/$id/tasks.md") file="$want"; text="# $id tasks

- [ ] 1.1 the task body" ;;
          *) printf 'panel-b3-stub: --file not in the discovered set: %s\n' "$want" >&2; return 1 ;;
        esac
      else
        reason="openspec/changes/$id/ 下没有 proposal/design/tasks"
      fi
      ;;
    decision)
      case "$id" in
        D40|D39|D38)
          file="docs/team/DECISIONS.md"
          files="$(printf '[{"tab": "%s", "name": "DECISIONS.md", "path": "docs/team/DECISIONS.md", "size": 40, "truncated": false}]' "$id")"
          text="## $id · fixture decision

$id body

### $id 补记

deeper addendum"
          ;;
        *) reason="DECISIONS.md 里没有 $id" ;;
      esac
      ;;
    *)
      printf 'panel-b3-stub: unknown --source %s\n' "$source" >&2
      return 2
      ;;
  esac
  # The single-file sources serve exactly their discovered path.
  case "$source" in
    spec|decision)
      if [ -n "$want" ] && [ "$want" != "$file" ]; then
        printf 'panel-b3-stub: --file not in the discovered set: %s\n' "$want" >&2
        return 1
      fi
      ;;
  esac
  if [ -z "$file" ]; then
    printf '{"id": %s, "count": 0, "file": "", "text": "", "truncated": false, "files": [], "reason": %s}\n' \
      "$(json_str "$id")" "$(json_str "$reason")"
    return 0
  fi
  printf '{"id": %s, "count": 1, "file": %s, "text": %s, "truncated": false, "files": %s}\n' \
    "$(json_str "$id")" "$(json_str "$file")" "$(json_str_ml "$text")" "$files"
}

changes_json() {
  case "${B3_STUB_PREVIEWS:-}" in
    empty|specs-only) printf '%s\n' '{"available": true, "source": "dir", "count": 0, "changes": []}'; return 0 ;;
  esac
  cat <<'JSON'
{"available": true, "source": "openspec", "count": 2, "changes": [
 {"id": "pulse-console", "done": 8, "total": 28, "age": "44m ago", "phase": "apply"},
 {"id": "rename-watchdog", "done": 12, "total": 12, "age": "2d ago", "phase": "verify"}
]}
JSON
}

specs_json() {
  if [ "${B3_STUB_PREVIEWS:-}" = "empty" ]; then printf '%s\n' '{"available": true, "count": 0, "requirements": 0, "specs": []}'; return 0; fi
  cat <<'JSON'
{"available": true, "count": 12, "requirements": 45, "specs": [
 {"name": "panel", "requirements": 12},
 {"name": "watchdog", "requirements": 10},
 {"name": "delivery-guard", "requirements": 9},
 {"name": "dispatch", "requirements": 7}
]}
JSON
}

decisions_json() {
  case "${B3_STUB_PREVIEWS:-}" in
    empty|specs-only) printf '%s\n' '{"count": 0, "recent": []}'; return 0 ;;
  esac
  cat <<'JSON'
{"count": 40, "recent": ["D40 · 2026-09-16 · 决定 — 控制台分三批", "D39 · 2026-09-16 · 决定 — i18n 进 B3", "D38 · 2026-09-15 · 决定 — q 收起不清巡检"]}
JSON
}

outbox_list_json() { cat <<'JSON'
{"queued": 2, "held": 1, "entries": [
 {"name": "1758000000000-001-pm.msg", "state": "queued", "age_s": 42, "target": "this-project:pm", "kind": "notify", "from": "dev", "reason": "", "text": "第一行\n第二行"},
 {"name": "1758000001000-002-pm.msg", "state": "queued", "age_s": 7, "target": "this-project:pm", "kind": "say", "from": "verify", "reason": "", "text": "排队中的第二条"},
 {"name": "1757990000000-003-pm.msg", "state": "held", "age_s": 3600, "target": "this-project:pm", "kind": "notify", "from": "dev", "reason": "draft-raced", "text": "被扣住的副本"}
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

# ---- the detail reader's stand-in (P18/B3): per-id discovered files, four per entry.
detail_brief() { # <id>
  printf '# %s · fixture brief\n\n' "$1"
  cat <<'MD'
A paragraph with **bold**, `code` and a [link](https://example.invalid/x).

- first bullet
- second bullet with enough words to wrap inside a narrow pane

> a quoted line

```sh
echo "verbatim fence body"
```

| id | state | note |
|:---|:------:|-----:|
| P1 | wip | short |
| P22 | done | a longer note |

---

closing paragraph
MD
}

# The report grows with B3_STUB_DETAIL_LONG (default 40) so the detail window has rows to scroll.
detail_report() { # <id>
  local i n="${B3_STUB_DETAIL_LONG:-40}"
  printf '# %s · fixture report\n\n' "$1"
  for ((i = 1; i <= n; i++)); do printf 'report line %02d with a few words to read\n' "$i"; done
}

# detail_json <id> <file>: every entry except the empty `Z9` has the four discovered files
# (brief/report/review/review:done), so the focused board card always opens something. `--file` must
# be one of that entry's discovered paths (anything else exits non-zero, exactly like the real
# reader). B3_STUB_DETAIL_FILE=<json> serves a whole block verbatim (the hostile/truncated fixtures).
detail_json() {
  if [ -n "${B3_STUB_DETAIL_FILE:-}" ] && [ -r "${B3_STUB_DETAIL_FILE}" ]; then
    cat "${B3_STUB_DETAIL_FILE}"
    return 0
  fi
  local id="${1:-}" want="${2:-}"
  if [ -z "$id" ] || [ "$id" = "Z9" ]; then
    printf '{"id": %s, "count": 0, "file": "", "text": "", "truncated": false, "files": []}\n' "$(json_str "$id")"
    return 0
  fi
  local p_brief="docs/team/tasks/$id-a.md" p_report="docs/team/reports/$id-dev.md" \
        p_review="docs/team/reviews/$id.md" p_done="docs/team/reviews/$id-done.md"
  local files
  files="$(printf '[{"tab": "brief", "name": "%s-a.md", "path": "%s", "size": 420, "truncated": false}, {"tab": "report:dev", "name": "%s-dev.md", "path": "%s", "size": 1400, "truncated": false}, {"tab": "review", "name": "%s.md", "path": "%s", "size": 90, "truncated": false}, {"tab": "review:done", "name": "%s-done.md", "path": "%s", "size": 120, "truncated": false}]' \
    "$id" "$p_brief" "$id" "$p_report" "$id" "$p_review" "$id" "$p_done")"
  local file="$p_brief" text
  text="$(detail_brief "$id")"
  case "$want" in
    ''|"$p_brief") ;;
    "$p_report") file="$want"; text="$(detail_report "$id")" ;;
    "$p_review") file="$want"; text="# $id · fixture review

the independent check found nothing" ;;
    "$p_done") file="$want"; text="# $id · fixture review (done)

closed" ;;
    *) printf 'panel-b3-stub: --file not in the discovered set: %s\n' "$want" >&2; return 1 ;;
  esac
  printf '{"id": %s, "count": 4, "file": %s, "text": %s, "truncated": false, "files": %s}\n' \
    "$(json_str "$id")" "$(json_str "$file")" "$(json_str_ml "$text")" "$files"
}

# pulse-key-replies 的固定回复块（stub 面；见上面的三条 case）。
reply_entry_json() {
  printf '{"no": 1, "available": true, "title": "固定关键回复", "from": "dev2", "at": "2026-09-16T09:59:00Z", "bytes": 24, "sha256": "%s"}' "$(printf 'a%.0s' {1..64})"
}
reply_summary_json() {
  case "${B3_STUB_REPLY:-empty}" in
    empty)   printf '%s\n' '{"available": true, "state": "empty", "total_slots": 0, "warnings": []}' ;;
    corrupt) printf '%s\n' '{"available": true, "state": "unavailable", "total_slots": 1, "warnings": [], "reason": "checksum mismatch"}' ;;
    *)       printf '{"available": true, "state": "ok", "total_slots": 1, "warnings": [], "entry": %s}\n' "$(reply_entry_json)" ;;
  esac
}
reply_list_json() {
  case "${B3_STUB_REPLY:-empty}" in
    empty)   printf '%s\n' '{"available": true, "state": "empty", "total_slots": 0, "entries": [], "next_before": null, "warnings": []}' ;;
    corrupt) printf '%s\n' '{"available": true, "state": "ok", "total_slots": 1, "entries": [{"no": 1, "available": false, "reason": "checksum mismatch"}], "next_before": null, "warnings": []}' ;;
    *)       printf '{"available": true, "state": "ok", "total_slots": 1, "entries": [%s], "next_before": null, "warnings": []}\n' "$(reply_entry_json)" ;;
  esac
}
reply_body_json() {
  printf '%s\n' '{"no": 1, "available": true, "title": "固定关键回复", "from": "dev2", "at": "2026-09-16T09:59:00Z", "bytes": 24, "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "text_kind": "safe-display", "display_text": "固定回复正文\n第二行\n"}'
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
  recent)      recent_json ;;
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
  detail)      if [ -n "$detail_source" ]; then preview_json "$detail_source" "$detail_id" "$detail_file"; else detail_json "$detail_id" "$detail_file"; fi ;;
  # pulse-key-replies：三个回复块也是固定数据（默认「显式空」，B3_STUB_REPLY=1 → 一条 1 号回复，
  # =corrupt → 最新槽位不可用），这样第 5 页与总览的摘要行在快照里逐字节可复现。
  reply_summary) reply_summary_json ;;
  reply_list)    reply_list_json ;;
  reply_body)    reply_body_json ;;
  health)
    printf '%s\n' '{"version": "1.38.0", "doc_version": "1.38.0", "doctor": "ok", "gates": "—"}'
    ;;
  *)
    printf 'panel-b3-stub: unknown block %s\n' "${block:-<none>}" >&2
    exit 2
    ;;
esac
