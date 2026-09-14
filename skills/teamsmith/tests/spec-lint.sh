#!/usr/bin/env bash
# spec-lint.sh — the falsifiability companion to `openspec validate` (M5.3)
#
# Why this exists: `openspec validate --all --strict` checks structure and strict-mode wording, but it does
# not check that a requirement carries a scenario, that a scenario carries both a trigger and an assertion,
# or that either one says anything. Deleting a scenario's THEN, deleting the scenario, or emptying a whole
# spec.md keeps `openspec validate --all --strict` green — the gate then passes with an unfalsifiable spec.
# This checker makes those deletions red.
#
# Language: bash + awk on purpose. The gates, the smoke suite and `team` itself are bash, and the rules are
# line-based (headings + bullets); awk is enough and adds no runtime dependency. A node script would add a
# second runtime (this box has no usable node type-stripping) for no gain.
#
# Usage:
#   bash skills/teamsmith/tests/spec-lint.sh [spec-root]   # spec-root default: $TEAM_SPEC_DIR, else openspec
#
# Rules (violation codes are stable — the smoke suite asserts them):
#   no-specs                        no specs/*/spec.md under the root (a gate that checks nothing is not a gate)
#   no-requirements                 a spec file with no `### Requirement:` block at all
#   requirement-without-scenario    a `### Requirement:` block with no `#### Scenario:` block
#   scenario-without-when           a scenario with no WHEN bullet (a trigger-less assertion)
#   scenario-without-then           a scenario with no THEN/AND bullet (an assertion-less trigger)
#   scenario-placeholder            a WHEN/THEN whose text is empty or vacuous (`THEN it works`)
#   change-incomplete               a change directory without specs/ delta, proposal.md or tasks.md
#   delta-requirement-without-scenario   an ADDED/MODIFIED delta requirement with no scenario
#   (REMOVED/RENAMED delta requirements are allowed to have no scenario — they are not new promises.)
#
# Changes are *proposals*: the checker is deliberately tolerant there (no `no-requirements`, lenient
# REMOVED/RENAMED sections). `openspec validate --all --strict` owns the structural half; this owns the
# "can it fail?" half.
#
# Exit codes: 0 = clean, 1 = violations found, 2 = spec root missing / unusable (usage error).
set -uo pipefail

case "${1:-}" in
  -h|--help)
    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
esac

ROOT="${1:-${TEAM_SPEC_DIR:-openspec}}"
if [ ! -d "$ROOT" ]; then
  printf 'spec-lint: spec root not found: %s（跑 `openspec init --tools none`，或用 TEAM_SPEC_DIR 指定）\n' "$ROOT" >&2
  exit 2
fi
if [ ! -d "$ROOT/specs" ]; then
  printf 'spec-lint: no specs/ under %s（spec 根目录应当包含 specs/ 与 changes/）\n' "$ROOT" >&2
  exit 2
fi

VIOLATIONS=""
FILES=0
REQS=0
SCENS=0

# scan_file <file> <is_delta 0|1>
scan_file() {
  local f="$1" delta="$2" out
  FILES=$((FILES + 1))
  REQS=$((REQS + $(grep -c '^### Requirement:' "$f" 2>/dev/null || true)))
  SCENS=$((SCENS + $(grep -c '^#### Scenario:' "$f" 2>/dev/null || true)))
  out="$(awk -v is_delta="$delta" '
function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
function viol(line, code, detail) {
  printf "%s:%d: %s: %s\n", FILENAME, line, code, detail
}
# A scenario line is only evidence if it says something a run can refute: empty text, or one of the
# vacuous phrases the spec rules already forbid ("works correctly", "behaves as expected"), is not.
function vacuous(t,   s) {
  s = tolower(t)
  gsub(/[`*_]/, "", s)
  gsub(/[[:space:]]+/, " ", s)
  s = trim(s)
  if (s == "") return 1
  if (s ~ /as expected|works correctly|behaves correctly|behaves as expected/) return 1
  if (s ~ /^(it|this|that|everything)? ?just ?works( fine| ok| okay)?$/) return 1
  if (s ~ /^(it|this|that|everything)? ?(works|succeeds|passes|is correct|is fine|is ok|is okay)$/) return 1
  return 0
}
function flush_scenario(   i) {
  if (!in_scen) return
  if (nw == 0) viol(scen_line, "scenario-without-when", "scenario has no WHEN bullet: " scen_title)
  for (i = 1; i <= nw; i++)
    if (vacuous(w_txt[i])) viol(w_line[i], "scenario-placeholder", "WHEN text is empty or vacuous: [" w_txt[i] "]")
  if (nt == 0) viol(scen_line, "scenario-without-then", "scenario has no THEN bullet: " scen_title)
  for (i = 1; i <= nt; i++)
    if (vacuous(t_txt[i])) viol(t_line[i], "scenario-placeholder", "THEN text is empty or vacuous: [" t_txt[i] "]")
  in_scen = 0
}
function flush_requirement() {
  if (!in_req) return
  flush_scenario()
  if (!has_scen && !req_lenient)
    viol(req_line, (is_delta ? "delta-requirement-without-scenario" : "requirement-without-scenario"),
         "requirement has no scenario: " req_title)
  in_req = 0
}
# `### Requirement:` starts a requirement; `#### Scenario:` starts a scenario inside it.
/^####[[:space:]]+Scenario:/ {
  flush_scenario()
  in_scen = 1; has_scen = 1; scen_line = NR; nw = 0; nt = 0; cur = ""
  scen_title = trim(substr($0, index($0, "Scenario:") + 9))
  next
}
/^###[[:space:]]+Requirement:/ {
  flush_requirement()
  nreq++; in_req = 1; req_line = NR; has_scen = 0
  req_title = trim(substr($0, index($0, "Requirement:") + 12))
  req_lenient = (is_delta && delta_kind != "ADDED" && delta_kind != "MODIFIED")
  next
}
# Delta files carry their promises under `## ADDED/MODIFIED/REMOVED/RENAMED Requirements`.
/^##[[:space:]]+(ADDED|MODIFIED|REMOVED|RENAMED)/ { flush_requirement(); delta_kind = $2; next }
# Any other level-1..3 heading closes the current requirement.
/^#{1,3}[[:space:]]/ { flush_requirement(); next }
# Bullets: WHEN is the trigger, THEN/AND is the assertion, GIVEN is setup, anything else is prose.
/^[[:space:]]*[-*][[:space:]]+/ {
  if (!in_scen) next
  raw = $0
  sub(/^[[:space:]]*[-*][[:space:]]+/, "", raw)
  key = raw; gsub(/[*_`]/, "", key)
  if (key ~ /^WHEN([[:space:]:]|$)/) {
    nw++; w_txt[nw] = trim(substr(key, 5)); w_line[nw] = NR; cur = "w"; cur_i = nw; next
  }
  if (key ~ /^(THEN|AND)([[:space:]:]|$)/) {
    nt++; t_txt[nt] = trim(substr(key, 5)); t_line[nt] = NR; cur = "t"; cur_i = nt; next
  }
  cur = ""   # a plain bullet ends the marker text
  next
}
# Continuation lines (a wrapped WHEN/THEN) extend the current marker text.
{
  if (in_scen && cur == "w") w_txt[cur_i] = w_txt[cur_i] " " trim($0)
  else if (in_scen && cur == "t") t_txt[cur_i] = t_txt[cur_i] " " trim($0)
}
END {
  flush_requirement()
  if (!is_delta && nreq == 0)
    viol(1, "no-requirements", "spec file has no `### Requirement:` block (a heading-only spec cannot fail)")
}
' "$f")"
  [ -n "$out" ] && VIOLATIONS="${VIOLATIONS}${out}"$'\n'
}

SPEC_FILES=0
for f in "$ROOT"/specs/*/spec.md; do
  [ -f "$f" ] || continue
  SPEC_FILES=$((SPEC_FILES + 1))
  scan_file "$f" 0
done
if [ "$SPEC_FILES" -eq 0 ]; then
  VIOLATIONS="${VIOLATIONS}${ROOT}/specs/1: no-specs: no specs/*/spec.md under ${ROOT}（没有 spec 的绿灯不是绿灯）"$'\n'
fi

# Changes are proposals: a change dir must carry a delta, a proposal or a task list; its deltas get the
# scenario rules, but a REMOVED/RENAMED section is allowed to be scenario-less. `changes/archive/` is
# history, not a promise — it is skipped.
if [ -d "$ROOT/changes" ]; then
  for d in "$ROOT"/changes/*/; do
    [ -d "$d" ] || continue
    [ "$(basename "$d")" = archive ] && continue
    has=0
    [ -f "${d}proposal.md" ] && has=1
    [ -f "${d}tasks.md" ] && has=1
    deltas=""
    if [ -d "${d}specs" ]; then
      deltas="$(find "${d}specs" -type f -name '*.md' | sort)"
      [ -n "$deltas" ] && has=1
    fi
    if [ "$has" -eq 0 ]; then
      VIOLATIONS="${VIOLATIONS}${d%/}/1: change-incomplete: no specs/ delta, proposal.md or tasks.md"$'\n'
    fi
    [ -n "$deltas" ] || continue
    while IFS= read -r df; do
      [ -n "$df" ] || continue
      scan_file "$df" 1
    done <<< "$deltas"
  done
fi

if [ -n "$VIOLATIONS" ]; then
  printf '%s' "$VIOLATIONS"
  printf 'spec-lint: FAIL — %d violation(s) under %s\n' "$(printf '%s' "$VIOLATIONS" | grep -c .)" "$ROOT"
  exit 1
fi
printf 'spec-lint: OK — %d spec file(s), %d requirement(s), %d scenario(s) under %s\n' \
  "$FILES" "$REQS" "$SCENS" "$ROOT"
exit 0
