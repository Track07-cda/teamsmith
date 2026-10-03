#!/usr/bin/env bash
# P163 · delivery-truth 的**真实 Pi/model/tmux** 配方（P147/P157 授权配方的夹具版）。
#
#   用法（仓库根）：
#     P163_EVIDENCE="$PWD/docs/team/reports/P163-dev-bob" \
#       bash skills/teamsmith/tests/fixtures/delivery-truth-real/run-case.sh \
#         <case> [rev] [long] [runtime]
#
#   case     必须形如 tmux-p163-… / watch-p163-…（夹具只碰自己的 case 目录）
#   rev      要测的提交（默认 HEAD）；源码用 git archive 进容器，绝不 checkout 切分支
#   long     1 = 二投递用长消息（P138_LONG）
#   runtime  0.99.2（默认，**判据版本**）| host（**仅供人工观察，不作为判据**）
#
# 与 P147/P157 作者配方的两处有意差异（P163 的两条 finding）：
#   ① 现场重置：每个 case 先 rm -rf 自己的现场目录，再写 run.json 运行戳；scenario.sh 在判据读的
#      事件文件第一行写单次 run_start 标记；judge-second.py 拒绝缺戳 / 标记不是恰好一条 / 标记不在第一行 /
#      run-start.txt 缺失·为空·run= 不符 / 有旧文件 / 观察模式的现场。
#   ② 版本钉死：判决路线只有容器里的 0.99.2；宿主路线（当前 1.0.0）在 run.json 里标 observation，
#      judge-second.py 拒绝给它出判据 —— 避免把「宿主版本差异」当产品红绿。
#
# 本脚本只调 `distrobox-host-exec podman`（宿主 podman）；容器自己的 tmux server 是私有的。
set -euo pipefail
ROOT=$(git rev-parse --show-toplevel)
E="${P163_EVIDENCE:?需要 P163_EVIDENCE=<证据目录>（容器内挂成 /evidence；目录须已存在）}"
[ -d "$E" ] || { echo "P163_EVIDENCE 不是目录：$E" >&2; exit 2; }
E=$(cd -P "$E" && pwd)
CASE=${1:?case}; REV=${2:-HEAD}; LONG=${3:-0}; PI_VERSION=${4:-0.99.2}
[[ "$CASE" =~ ^(tmux|watch)-p163-[a-z0-9-]+$ ]] || { echo 'invalid P163 case name' >&2; exit 64; }
case "$PI_VERSION" in
  0.99.2) MODE=verdict ;;
  host)   MODE=observation ;;
  *) echo "unsupported runtime: use 0.99.2 (verdict) or host (人工观察，不作为判据)" >&2; exit 64 ;;
esac
MODULES=$HOME/.bun/install/global/node_modules
PINNED="$E/.runtime/node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js"
if [ "$MODE" = verdict ]; then
  [ -f "$PINNED" ] || { echo "pinned 0.99.2 runtime missing: $PINNED（安装见 fixtures/delivery-truth-real/README.md）" >&2; exit 69; }
else
  printf '%s\n' '⚠ host 路线仅供人工观察，不作为判据：宿主当前 1.0.0 会把夹具自造的框内行当草稿，judge-second.py 会拒绝出判据'
fi
REV_FULL=$(git rev-parse "$REV")
RUN_ID=$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')
STARTED_AT=$(date +%s)

# ① 现场重置：这一次的测量只看这一次。
L="$E/logs/$CASE"
rm -rf -- "$L"
mkdir -p "$L" "$E/pkg"
cp -a "$(dirname "$0")/." "$E/pkg/"
P163_CASE="$CASE" P163_RUN_ID="$RUN_ID" P163_REV="$REV" P163_REV_FULL="$REV_FULL" \
P163_PI_VERSION="$PI_VERSION" P163_MODE="$MODE" P163_STARTED_AT="$STARTED_AT" \
python3 - "$L/run.json" <<'PY'
import json, os, sys
keys = ('P163_CASE', 'P163_RUN_ID', 'P163_REV', 'P163_REV_FULL', 'P163_PI_VERSION', 'P163_MODE', 'P163_STARTED_AT')
run = {k[5:].lower(): os.environ[k] for k in keys}
run['started_at'] = int(run['started_at'])
with open(sys.argv[1], 'w') as f:
    json.dump(run, f, indent=1, sort_keys=True)
    f.write('\n')
PY
printf 'P163 clean case=%s run=%s revision=%s full=%s runtime=%s mode=%s\n' \
  "$CASE" "$RUN_ID" "$REV" "$REV_FULL" "$PI_VERSION" "$MODE"

args=(run --rm --network=none -i -e HOME=/tmp -e P138_CONTAINER=1 -e "P138_LONG=$LONG"
  -e "P138_OLD_NOTIFY=${P138_OLD_NOTIFY:-0}" -e "P143_DRAFT=${P143_DRAFT:-0}" -e "P138_TRACKED=${P138_TRACKED:-0}" -e "P138_SETTLE_DELAY=${P138_SETTLE_DELAY:-1}" -e "P138_SECOND=${P138_SECOND:-0}"
  -e "P163_RUN_ID=$RUN_ID" -e "P163_CASE=$CASE" -e "P163_MODE=$MODE" -e "P163_PI_VERSION=$PI_VERSION"
  -v "$ROOT:/src:ro" -v "$E:/evidence:rw" -w /src)
if [ "$PI_VERSION" = host ]; then
  args+=(-v "$MODULES:$MODULES:ro" -e "P138_PI_CLI=$MODULES/@earendil-works/pi-coding-agent/dist/bundle/cli.js")
else
  args+=(-v "$E/.runtime:/runtime:ro" -e P138_PI_CLI=/runtime/node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js)
fi
# Historical sources exist only in the disposable container; no checkout/reset of a branch.
git archive "$REV" skills | distrobox-host-exec podman "${args[@]}" localhost/teamsmith-gate:local bash -c '
  mkdir -p /tmp/history; tar -xf - -C /tmp/history
  if [ -e /tmp/history/skills/teamsmith/scripts/team ]; then export P138_SKILL=/tmp/history/skills/teamsmith
  else export P138_SKILL=/tmp/history/skills/pi-team; fi
  exec bash /evidence/pkg/scenario.sh "$1"
' _ "$CASE"
