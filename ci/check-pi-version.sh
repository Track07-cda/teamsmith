#!/usr/bin/env bash
# ci/check-pi-version.sh <expected-version> <observed-output>
#
# The one executable answer to "is this the pi this run resolved?" (P380). Both callers first capture
# the version command's output and check its own exit status; only a successful read reaches this script:
#   · `.github/workflows/gates.yml`, inside the gate container (after checking pi_rc):
#         bash ci/check-pi-version.sh "$PI_EXPECT_VERSION" "$pi_out"
#   · `ci/build-image.sh`, after building and checking observed_rc:
#         bash ci/check-pi-version.sh "$VERSION" "$observed"
# Do not inline an unchecked "$(pi --version)" argument: that would discard the runtime's failure status.
#
# Exit codes: 0 = the observed runtime is exactly the expected one (prints one line naming both);
#             3 = it is not, or nothing recognisable was observed (names both / prints what it saw);
#             2 = the call itself is wrong (missing or non-concrete expected version).
# The expected version must be concrete: comparing against `latest` would never match what pi prints,
# and comparing against an empty string would match nothing — both are wiring mistakes, not results.
#
# The observed output is searched **line by line** for a complete version line, and only that line is
# trimmed; a whole-input `tr -d '[:space:]'` would join `1.4.0` and a following notice into one token
# (V109's finding in the two resolvers, kept in one place here).
set -uo pipefail

VERSION_RE='^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$'
EXPECTED="${1:-}"
OBSERVED_INPUT="${2:-}"

usage() {
  printf 'usage: ci/check-pi-version.sh <expected-version> <observed-output>\n' >&2
  exit 2
}
[ -n "$EXPECTED" ] || usage
if ! printf '%s' "$EXPECTED" | grep -qE "$VERSION_RE"; then
  printf 'check-pi-version: 期望值是 %s，不是具体版本号（这里不接受 latest 之类的别名）\n' "$EXPECTED" >&2
  exit 2
fi

OBSERVED="$(printf '%s\n' "$OBSERVED_INPUT" \
  | grep -E '^[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?[[:space:]]*$' \
  | tail -1 | tr -d '[:space:]' || true)"
if [ -z "$OBSERVED" ]; then
  printf 'check-pi-version: 运行时没有报出可识别的 pi 版本（本次解析为 %s）：%s\n' "$EXPECTED" "$OBSERVED_INPUT" >&2
  exit 3
fi
if [ "$OBSERVED" != "$EXPECTED" ]; then
  printf 'check-pi-version: the gate image runs pi %s, but %s was resolved for this run (stale image layer or dropped build arg)\n' \
    "$OBSERVED" "$EXPECTED" >&2
  exit 3
fi
printf 'pi %s (resolved for this run: %s)\n' "$OBSERVED" "$EXPECTED"
