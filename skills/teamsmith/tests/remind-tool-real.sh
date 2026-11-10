#!/usr/bin/env bash
# P442: private real Pi/tmux and controlled loopback model only; never the live team or credentials.
set -euo pipefail
TESTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec node "$TESTS/remind-tool-real.mjs" "$@"
