#!/usr/bin/env bash
# P426: exercise the actual isolation predicates without starting tmux or writing to a live team.
# --ref <commit> runs the same expectations against the old predicates (expected red).
set -euo pipefail
SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF_DIR/../../.." && pwd)"
REF=""
if [ "${1:-}" = --ref ] && [ "$#" = 2 ]; then REF="$2"
elif [ "$#" != 0 ]; then printf 'usage: isolation-ledger.sh [--ref <commit>]\n' >&2; exit 2; fi
# P427：临时根走夹具的**唯一创建者**（tests/lib/tmp-root.sh：owned 家族 + 项目 ns + 落盘台账 + 退出回收）。
# 不自己算基准、也不写死 /var/tmp —— section 40 的临时根 lint 对这两件事都会点名（旧写法是
# `mktemp -d -p /var/tmp p426-isolation.XXXXXX`）。
. "$SELF_DIR/lib/tmp-root.sh"
TMP="$(tmp_root_create isolation)" || { printf 'isolation-ledger: 建不了临时根\n' >&2; exit 2; }
trap 'tmp_root_reap_all' EXIT
for file in smoke.sh tmux-identity-leak.sh; do
  if [ -n "$REF" ]; then git -C "$ROOT" show "$REF:skills/teamsmith/tests/$file" > "$TMP/$file"
  else cp "$SELF_DIR/$file" "$TMP/$file"; fi
done
# Extract the checked-in functions and the actual closing verdict, not a second implementation.
python3 - "$TMP" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
for file, name in [('smoke.sh', 'real_ledger_hits'), ('tmux-identity-leak.sh', 'ledger_manifest')]:
    text = (root / file).read_text()
    body = re.search(r'^' + name + r'\(\).*?^}', text, re.M | re.S)
    if not body:
        raise SystemExit('missing predicate: ' + name)
    (root / (name + '.sh')).write_text(body[0] + '\n')
text = (root / 'tmux-identity-leak.sh').read_text()
start = text.index('LEDGER_AFTER=')
end = text.index('ROOTS_AFTER=', start)
(root / 'verdict.sh').write_text(text[start:end])
PY
. "$SELF_DIR/lib/main-team-fingerprint.sh"
. "$TMP/real_ledger_hits.sh"
. "$TMP/ledger_manifest.sh"
PASS=0; FAIL=0
ok() { printf 'ok: %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf 'bad: %s\n' "$1"; FAIL=$((FAIL + 1)); }
expect() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected=$3 actual=$2)"; fi; }

SCAN="$TMP/scan"
mkdir -p "$SCAN/docs/team/inbox" "$SCAN/.pi/team/state"
# Reports may quote old sessions, old temp roots, family prefixes and fixture aliases in any file.
printf '%s\n' 'Old incident: teamsmith-smoke-758714; teamsmith-smoke-p10-1; teamsmith-smoke-m16-2; teamsmith-smoke-m98-3; teamsmith-smoke-pm_skills-deb708fe.OLDROOT' \
  'P10 夹具阻塞行 / P10Z / $P10SESS / M16A / M98G / never lands / held body / OB-EXT-KNOCK' \
  > "$SCAN/docs/team/inbox/history.md"
cp "$SCAN/docs/team/inbox/history.md" "$SCAN/.pi/team/state/notify.log"
cp "$SCAN/docs/team/inbox/history.md" "$SCAN/.pi/team/state/history.env"
for session in "teamsmith-smoke-$$" "teamsmith-smoke-p10-$$" "teamsmith-smoke-m16-$$" "teamsmith-smoke-m98-$$"; do
  pats="$(printf '%s\n' "$session" "${TMP##*/}")"
  expect "scanner [$session]: historical messages and old aliases are not this run's leakage" \
    "$(real_ledger_hits "$pats" "$SCAN" | wc -l | tr -d ' ')" 0
  printf 'fixture session: %s:dev\n' "$session" > "$SCAN/docs/team/inbox/current.md"
  current_hits="$(real_ledger_hits "$pats" "$SCAN")"
  printf 'current-session hits: %s\n' "$current_hits"
  expect "scanner [$session]: this run's session written into inbox must be caught" \
    "$(printf '%s\n' "$current_hits" | grep -c 'inbox/current.md$')" 1
  rm "$SCAN/docs/team/inbox/current.md"
  printf 'fixture root: %s/fixture\n' "$TMP" > "$SCAN/.pi/team/state/current.env"
  cp "$SCAN/.pi/team/state/current.env" "$SCAN/.pi/team/state/notify-current.log"
  expect "scanner [$session]: this run's temp root in state and notify must be caught" \
    "$(real_ledger_hits "$pats" "$SCAN" | wc -l | tr -d ' ')" 2
  rm "$SCAN/.pi/team/state/current.env" "$SCAN/.pi/team/state/notify-current.log"
done

# Same before/after manifest and closing branch used by the identity fixture, on a nonempty live shape.
for mode in telemetry inbox unknown-state; do
  REPO_ROOT="$TMP/$mode"
  REAL_INBOX="$REPO_ROOT/docs/team/inbox"; REAL_STATE="$REPO_ROOT/.pi/team/state"
  mkdir -p "$REAL_INBOX" "$REAL_STATE"
  printf 'original\n' > "$REAL_INBOX/dev.md"
  printf 'tick\n' > "$REAL_STATE/watchdog.log"
  printf 'delivery\n' > "$REAL_STATE/notify.log"
  LEDGER_BEFORE="$(ledger_manifest "$REAL_INBOX" "$REAL_STATE")"
  LEDGER_N="$(printf '%s\n' "$LEDGER_BEFORE" | wc -l)"
  case "$mode" in
    telemetry) printf 'next tick\n' >> "$REAL_STATE/watchdog.log"; printf 'next delivery\n' >> "$REAL_STATE/notify.log"; expected=0 ;;
    inbox) printf 'unintended write\n' >> "$REAL_INBOX/dev.md"; expected=1 ;;
    unknown-state) mkdir "$REAL_STATE/unregistered"; printf 'unintended write\n' > "$REAL_STATE/unregistered/new.log"; expected=1 ;;
  esac
  # The verdict functions print their real lines, while this subshell's result counts rejected writes.
  actual="$(FAIL=0; . "$TMP/verdict.sh"; printf '\nrejected=%s\n' "$FAIL")"
  printf '%s\n' "$actual"
  expect "identity ledger: $mode" "${actual##*rejected=}" "$expected"
done
printf 'isolation-ledger: pass=%s fail=%s\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ]
