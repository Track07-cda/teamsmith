#!/usr/bin/env bash
# P380 · the one place that answers "which pi version should this run use?"
#
#   bash ci/resolve-pi-version.sh                  # the latest published version
#   PI_VERSION=0.99.2 bash ci/resolve-pi-version.sh # an explicit version, echoed unchanged
#
# Three callers share it, so "latest" means the same thing in all of them: the workflow's
# `resolve-pi` job (resolved once per run, every shard consumes that one output), the local build
# entry `ci/build-image.sh`, and anyone asking what latest is right now.
#
# Exit non-zero and say why when the registry cannot answer. There is deliberately no remembered
# fallback: a build that silently used the previous version would make every downstream
# `pi --version` assertion agree with a lie.
set -euo pipefail

PKG='@earendil-works/pi-coding-agent'
REGISTRY="${PI_REGISTRY:-https://registry.npmjs.org}"
VERSION="${PI_VERSION:-latest}"

if [ "$VERSION" != latest ]; then
  printf '%s\n' "$VERSION"
  exit 0
fi

command -v npm >/dev/null 2>&1 || {
  printf 'resolve-pi-version: 需要 npm 才能查 %s 的最新版本（或设 PI_VERSION=<x.y.z> 显式指定）\n' "$PKG" >&2
  exit 2
}

if ! out="$(npm view "$PKG" version --registry "$REGISTRY" 2>&1)"; then
  printf 'resolve-pi-version: 查不到 %s 的最新版本（registry=%s）：\n%s\n' "$PKG" "$REGISTRY" "$out" >&2
  exit 1
fi
# `npm view <pkg> version` answers `1.4.0` for one version and one line per version when several
# match; `latest` cannot be a range. npm may also print notices/warnings, each on its own line, so
# the version is selected **line by line** and only the selected line is trimmed: a whole-output
# `tr -d '[:space:]'` joins `1.4.0` and a following notice into one token and rejects a perfectly
# good answer (V109). No complete version line → the error below prints the registry's whole answer.
latest="$(printf '%s\n' "$out" \
  | grep -E '^[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?[[:space:]]*$' \
  | tail -1 | tr -d '[:space:]' || true)"
if ! printf '%s' "$latest" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$'; then
  printf 'resolve-pi-version: registry 的回答不是单个版本号：%s\n' "$out" >&2
  exit 1
fi
printf '%s\n' "$latest"
