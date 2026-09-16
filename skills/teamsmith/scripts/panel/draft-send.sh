#!/usr/bin/env bash
# teamsmith · panel send bridge (pulse-console B2)
#
#   bash scripts/panel/draft-send.sh <draft-file> [extra args to `team draft send`...]
#
# Why this exists: `team draft send` reports its machine outcome in the shell variables
# `TEAM_SEND_OUTCOME` / `TEAM_OUTBOX_RESULT`, which a caller cannot read across a process boundary
# — and the console's receipt contract forbids parsing the human prose (`✓ draft：已确认送达 …`)
# that the CLI prints next to them. The bridge therefore runs the **same guarded send function**
# in its own shell and prints exactly one machine line:
#
#   rc=<n> outcome=<token> result=<token>
#
# `outcome` is `TEAM_SEND_OUTCOME` (delivered|queued|forced|unknown-sent|duplicate|offline|…),
# `result` is the finer `TEAM_OUTBOX_RESULT` (delivered|held|busy|queued|offline|terminal|skip).
# The prose goes to stderr unchanged so the console can show it as the receipt's detail.
#
# The bridge is panel code on purpose: it lives under `scripts/panel/**` and changes nothing in
# the CLI's own files. If the CLI ever grows a machine-readable send output (the `[v1.1]`
# `team draft send --json`), this bridge is the one file that goes away.
set -uo pipefail

self="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill="$(cd -P "$self/../.." && pwd)"
file="${1:-}"
if [ -n "$file" ]; then shift || true; fi

emit() { printf 'rc=%s outcome=%s result=%s\n' "${1:-1}" "${TEAM_SEND_OUTCOME:-}" "${TEAM_OUTBOX_RESULT:-}"; }

if [ -z "$file" ] || [ ! -f "$file" ]; then
  printf 'draft-send: 草稿文件不存在（%s）\n' "${file:--}" >&2
  emit 2
  exit 2
fi

log="$(mktemp "${TMPDIR:-/tmp}/panel-draft-send.XXXXXX")"
trap 'rm -f "$log"' EXIT

TEAM_SKILL_DIR="${TEAM_SKILL_DIR:-$skill}"; export TEAM_SKILL_DIR
TEAM_CLI="${TEAM_CLI:-team}"; export TEAM_CLI

rc=0
. "$skill/scripts/lib/common.sh" >>"$log" 2>&1 || rc=$?
if [ "$rc" = "0" ]; then
  for f in "$skill"/scripts/lib/cmd-*.sh; do
    # shellcheck disable=SC1090
    . "$f" >>"$log" 2>&1 || rc=$?
    [ "$rc" = "0" ] || break
  done
fi
if [ "$rc" = "0" ]; then
  team_load_config >>"$log" 2>&1 || rc=$?
fi
if [ "$rc" = "0" ]; then
  # The CLI's own command handler (`team draft send`), one layer below the `team` wrapper's arg
  # parsing: same dispatch, same guarded path, but the outcome variables stay readable here.
  team_cmd_draft send "$file" "$@" >>"$log" 2>&1 || rc=$?
fi

cat "$log" >&2
emit "$rc"
exit "$rc"
