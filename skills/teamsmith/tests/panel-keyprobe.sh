#!/usr/bin/env bash
# Keystroke flip fixture (pulse-console B1, tasks.md 1.4).
#
#   bash skills/teamsmith/tests/panel-keyprobe.sh [tree]
#
# `tree` defaults to the repository this script lives in. The probe is built **from that tree**, so
# running the same fixture against the pre-change revision and the branch is the flip: the stub
# reader sleeps five seconds, the pty types `m`+`hello`+Enter during the refresh, and the fixture
# passes only when the compose line opened and the draft is exactly `hello`.
#
# Exit: 0 green, 2 the draft never arrived / was distorted (the red case), 3 setup failure.
set -uo pipefail

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$here/lib/tmp-root.sh"
tree="${1:-$(cd -P "$here/../../.." && pwd)}"
tmp="$(tmp_root_create panel-keyprobe)" || exit 3
log="$tmp/keyprobe.log"
out="$tmp/probe.out"
rc=3
cleanup() { tmp_root_reap_all; }
trap cleanup EXIT

bun_bin="${BUN:-}"
if [ -z "$bun_bin" ] && command -v bun >/dev/null 2>&1; then bun_bin="$(command -v bun)"; fi
[ -n "$bun_bin" ] || bun_bin="$HOME/.bun/bin/bun"
js="${TEAM_JS_BIN:-}"
if [ -z "$js" ] && command -v node >/dev/null 2>&1; then js="$(command -v node)"; fi
[ -n "$js" ] || js="$(command -v bun || echo '')"

if [ ! -x "$bun_bin" ]; then
  printf 'panel-keyprobe: bun is required to build the probe (looked at %s)\n' "$bun_bin" >&2
  exit 3
fi
if [ -z "$js" ]; then
  printf 'panel-keyprobe: no node/bun runtime to run the probe\n' >&2
  exit 3
fi
if [ ! -f "$tree/skills/teamsmith/tests/panel-keyprobe.tsx" ]; then
  printf 'panel-keyprobe: %s does not carry the fixture\n' "$tree" >&2
  exit 3
fi

stub="$tmp/keyprobe-stub.sh"
cp "$tree/skills/teamsmith/tests/panel-keyprobe-stub.sh" "$stub"
chmod +x "$stub"

# The probe is built from the tree under test: its `src/data.ts` is what the fixture exercises.
if ! "$bun_bin" build "$tree/skills/teamsmith/tests/panel-keyprobe.tsx" --target=node --format=esm \
      --outfile "$tmp/keyprobe.js" >"$tmp/build.log" 2>&1; then
  printf 'panel-keyprobe: cannot build the probe from %s\n' "$tree" >&2
  tail -5 "$tmp/build.log" >&2
  exit 3
fi

mkdir -p "$tmp/root"
printf '%s\n' "tree: $tree" >"$out"
set +e
python3 "$tree/skills/teamsmith/tests/panel-keyprobe-pty.py" --log "$log" --timeout 20 -- \
  "$js" "$tmp/keyprobe.js" --root "$tmp/root" --team-cli "$stub" --log "$log" --timeout 15000 \
  >>"$out" 2>&1
probe_rc=$?
set -e
printf 'probe rc: %s\n' "$probe_rc" >>"$out"

printf '== keyprobe.out ==\n'
cat "$out"
printf '== keyprobe.log ==\n'
cat "$log" 2>/dev/null || printf '(no log)\n'

if grep -q '^SUBMITTED draft=hello$' "$log" 2>/dev/null; then
  printf 'panel-keyprobe: OK — compose opened and the draft is exactly hello\n'
  rc=0
elif [ "$probe_rc" = "2" ]; then
  printf 'panel-keyprobe: RED — the keystrokes never opened compose / became the draft hello\n' >&2
  rc=2
else
  printf 'panel-keyprobe: FAIL — probe rc=%s\n' "$probe_rc" >&2
  rc=2
fi
exit "$rc"
