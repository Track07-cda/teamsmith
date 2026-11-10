#!/usr/bin/env bash
# P443: stopped-PM recovery and immediate tool withdrawal in private real Pi/tmux + controlled model.
set -euo pipefail
TESTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec node "$TESTS/remind-tool-real.mjs" --select=recovery,withdrawal "$@"
