#!/usr/bin/env bash
# Build the committed single-file panel bundle.
#
#   bun install --frozen-lockfile && bash skills/teamsmith/scripts/panel/build.sh
#
# The build is deterministic: same lockfile + same sources + same Bun version produce the same
# bytes, which is what makes "rebuild reproduces the committed panel.js" a checkable promise.
# `panel.js` is committed because an installation of the skill must run with no node_modules and no
# network; this script is only run by a maintainer (it needs the registry).
set -euo pipefail
cd "$(dirname "$0")"

BUN="${BUN:-}"
if [ -z "$BUN" ]; then
  for cand in bun "$HOME/.bun/bin/bun"; do
    if command -v "$cand" >/dev/null 2>&1; then BUN="$cand"; break; fi
  done
fi
if [ -z "$BUN" ]; then
  printf 'build.sh: bun is required to rebuild the panel bundle (https://bun.sh)\n' >&2
  exit 1
fi

INK_PIN="$(sed -n 's/.*"ink": *"\([^"]*\)".*/\1/p' package.json)"
REACT_PIN="$(sed -n 's/.*"react": *"\([^"]*\)".*/\1/p' package.json)"
[ -n "$INK_PIN" ] && [ -n "$REACT_PIN" ] || { printf 'build.sh: cannot read the pins from package.json\n' >&2; exit 1; }
BUILD_CMD='bun install --frozen-lockfile && bash skills/teamsmith/scripts/panel/build.sh'

TMP="panel.js.tmp"
"$BUN" build src/main.tsx \
  --target=node --format=esm --minify \
  --define "__PIN_INK__=\"$INK_PIN\"" \
  --define "__PIN_REACT__=\"$REACT_PIN\"" \
  --define "__BUILD_CMD__=\"$BUILD_CMD\"" \
  --outfile "$TMP"

# Provenance header (a stale bundle is detectable without a network rebuild). Kept free of
# timestamps/hosts so the rebuild stays byte-identical.
{
  printf '// teamsmith pulse panel — generated bundle; do not edit by hand\n'
  printf '// built from src/*.tsx by: %s\n' "$BUILD_CMD"
  printf '// pinned: ink %s · react %s · runtime floor: node >=20 | bun >=1.3\n' "$INK_PIN" "$REACT_PIN"
  printf '// size and sha256: README.md\n'
  cat "$TMP"
} > panel.js
rm -f "$TMP"
printf 'panel.js written (%s bytes, sha256 %s)\n' "$(wc -c < panel.js | tr -d ' ')" "$(sha256sum panel.js | cut -d' ' -f1)"
