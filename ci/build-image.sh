#!/usr/bin/env bash
# P380 · build the gate image for one resolved pi version, then prove the image carries it.
#
#   bash ci/build-image.sh                          # latest published pi, tag teamsmith-gates:ci
#   bash ci/build-image.sh -t teamsmith-gate:local  # another tag
#   PI_VERSION=0.99.2 bash ci/build-image.sh        # reproduce a historical runtime
#
# Why this exists instead of a bare `docker build`: the Containerfile's `ARG PI_VERSION` defaults to
# `latest`, and Docker's cache key is the ARG *value* — a bare rebuild would happily reuse the layer
# that installed an older release. Resolving the version here and passing the exact version makes the
# cache invalidate exactly when the release moves, and reading `pi --version` back out of the built
# image makes a stale layer a red build instead of a silent one.
#
# The engine is `docker` by default (CI); `CONTAINER_ENGINE` may name another CLI, including a wrapper
# such as `distrobox-host-exec podman`, which is how the development machine reaches host podman.
set -euo pipefail

HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -P "$HERE/.." && pwd)"
TAG="teamsmith-gates:ci"
read -r -a ENGINE <<< "${CONTAINER_ENGINE:-docker}"

while [ $# -gt 0 ]; do
  case "$1" in
    -t|--tag) shift; [ $# -gt 0 ] || { printf 'build-image: -t 需要标签\n' >&2; exit 2; }; TAG="$1"; shift ;;
    -h|--help) sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'build-image: 不认识的参数 %s\n' "$1" >&2; exit 2 ;;
  esac
done

VERSION="$(bash "$HERE/resolve-pi-version.sh")"
if [ -n "${PI_VERSION:-}" ] && [ "$PI_VERSION" != latest ]; then
  printf 'build-image: pi %s（调用者显式指定 PI_VERSION）\n' "$VERSION"
else
  printf 'build-image: pi %s（本次解析出的最新版本）\n' "$VERSION"
fi

"${ENGINE[@]}" build -f "$HERE/Containerfile" --build-arg "PI_VERSION=$VERSION" -t "$TAG" "$ROOT"

# The comparison itself is one executable check, shared with the gate's container step (P380 rework:
# an inline comparison that only looked right in a string match was not load-bearing).
# P380 Rework 4: same defect class as the workflow (V109's third finding) — a command substitution's
# status is not checked by default, so a runtime that prints the right version and then exits non-zero
# would be compared as a success. Keep the status, refuse first, compare only what was obtained.
# `|| observed_rc=$?` 不是吞错：它把失败码原样接住，下一条 if 立刻用它拒绝（这里在 `set -e` 下，
# 裸的 `x="$(failing)"` 会让脚本静默带着那个码退出，什么也不说）。
observed_rc=0
observed="$("${ENGINE[@]}" run --rm "$TAG" pi --version 2>&1)" || observed_rc=$?
if [ "$observed_rc" -ne 0 ]; then
  printf 'build-image: 镜像 %s 里 `pi --version` 退出 %s（没有拿到可信的版本，未做比较）：\n%s\n' \
    "$TAG" "$observed_rc" "$observed" >&2
  exit 1
fi
if ! bash "$HERE/check-pi-version.sh" "$VERSION" "$observed"; then
  printf 'build-image: 镜像 %s 的 pi 与本次解析的 %s 不符（拒绝；见上一条）\n' "$TAG" "$VERSION" >&2
  exit 1
fi
printf 'build-image: %s 里的 pi 与本次解析一致（%s）\n' "$TAG" "$VERSION"
