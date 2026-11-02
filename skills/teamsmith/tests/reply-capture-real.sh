#!/usr/bin/env bash
# Private real Pi + loopback model only; no live socket, credentials, shared models or team state.
set -euo pipefail
TESTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec node "$TESTS/reply-capture-real.mjs" "$@"
