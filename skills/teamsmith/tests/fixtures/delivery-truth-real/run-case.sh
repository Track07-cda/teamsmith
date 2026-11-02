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
#   runtime  latest（默认）| <x.y.z> | host
#              latest = 每次证据运行现查 npm 上的最新版、装进 $E/.runtime/<版本>、记录**实际**版本；
#              <x.y.z> = 复现历史运行（同一个安装与记录路径，不叫「判据版本」）；
#              host   = 用宿主当前的 pi，**仅供人工观察，不作为判据**（judge-second.py 拒绝出判据）。
#
# 与 P147/P157 作者配方的两处有意差异（P163 的两条 finding）：
#   ① 现场重置：每个 case 先 rm -rf 自己的现场目录，再写 run.json 运行戳；scenario.sh 在判据读的
#      事件文件第一行写单次 run_start 标记；judge-second.py 拒绝缺戳 / 标记不是恰好一条 / 标记不在第一行 /
#      run-start.txt 缺失·为空·run= 不符 / 有旧文件 / 观察模式的现场。
#   ② P380：运行时不再钉死。默认解析 npm 上的最新版本（一次证据运行解析一次），装进该版本自己的目录，
#      并把**解析出的版本**写进 run.json、把容器里 `pi --version` 的**实测值**写进 pi-version.txt；
#      judge 要求这两者相等（记录的必须是真跑的），不硬编码任何版本号。解析/安装失败就非 0 退出并点名，
#      绝不悄悄回落到旧版本。宿主路线（observation）照旧不出判据。
#
# 本脚本只调 `distrobox-host-exec podman`（宿主 podman）；容器自己的 tmux server 是私有的。
set -euo pipefail
ROOT=$(git rev-parse --show-toplevel)
E="${P163_EVIDENCE:?需要 P163_EVIDENCE=<证据目录>（容器内挂成 /evidence；目录须已存在）}"
[ -d "$E" ] || { echo "P163_EVIDENCE 不是目录：$E" >&2; exit 2; }
E=$(cd -P "$E" && pwd)
CASE=${1:?case}; REV=${2:-HEAD}; LONG=${3:-0}; RUNTIME=${4:-latest}
[[ "$CASE" =~ ^(tmux|watch)-p163-[a-z0-9-]+$ ]] || { echo 'invalid P163 case name' >&2; exit 64; }
IMAGE=${P163_IMAGE:-localhost/teamsmith-gate:local}
REGISTRY=${PI_REGISTRY:-https://registry.npmjs.org}
PKG='@earendil-works/pi-coding-agent'
PODMAN=(distrobox-host-exec podman)
VERSION_RE='^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$'

case "$RUNTIME" in
  host)   MODE=observation; PI_VERSION=host ;;
  latest) MODE=verdict ;;
  *)      if [[ "$RUNTIME" =~ $VERSION_RE ]]; then MODE=verdict; PI_VERSION="$RUNTIME"
          else echo "unsupported runtime: $RUNTIME（latest（默认）| <x.y.z> | host 人工观察，不作为判据）" >&2; exit 64
          fi ;;
esac

# 读安装目录里那个包自己报的版本（宿主没有 node 也能读：用夹具镜像）。
pkg_version() { # <runtime-dir>
  "${PODMAN[@]}" run --rm -v "$1:/runtime:ro" "$IMAGE" \
    node -p "require('/runtime/node_modules/$PKG/package.json').version"
}

install_runtime() { # <version>：装进 $E/.runtime/<version>，失败点名退出，不回落
  local v="$1" rt="$E/.runtime/$1" got
  mkdir -p "$rt"
  printf 'P163 runtime: 安装 %s@%s → %s（网络只在这一步用）\n' "$PKG" "$v" "$rt"
  if ! "${PODMAN[@]}" run --rm --userns=keep-id -e HOME=/tmp -v "$rt:/runtime:rw" "$IMAGE" \
      bash -c 'npm install --prefix /runtime --no-audit --no-fund "$1" || exit 1' _ "$PKG@$v"; then
    printf 'P163 runtime: 安装 %s@%s 失败（%s）；没有回落到别的版本\n' "$PKG" "$v" "$rt" >&2
    exit 69
  fi
  got="$(pkg_version "$rt")" || { printf 'P163 runtime: 读不出 %s 里那个包的版本（安装树不完整？）\n' "$rt" >&2; exit 69; }
  if [ "$got" != "$v" ]; then
    printf 'P163 runtime: %s 里的包报版本 %s，期望 %s —— 拒绝把别的运行时当成本次判据\n' "$rt" "$got" "$v" >&2
    exit 69
  fi
}

if [ "$MODE" = verdict ]; then
  if [ "$RUNTIME" = latest ]; then
    if ! out="$("${PODMAN[@]}" run --rm "$IMAGE" npm view "$PKG" version --registry "$REGISTRY" 2>&1)"; then
      printf 'P163 runtime: 解析 %s 的最新版本失败：\n%s\n' "$PKG" "$out" >&2
      exit 69
    fi
    # V109：先按行挑出**完整的版本行**（npm 的 notice/warning 各占一行），只对选中那一行去空白。
    # 对整个输出做 `tr -d '[:space:]'` 会把 `1.4.0` 和后面那行 notice 粘成一个 token，好答案也会被拒。
    PI_VERSION="$(printf '%s\n' "$out" \
      | grep -E '^[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?[[:space:]]*$' \
      | tail -1 | tr -d '[:space:]' || true)"
    if ! [[ "$PI_VERSION" =~ $VERSION_RE ]]; then
      printf 'P163 runtime: registry 的回答不是单个版本号：%s\n' "$out" >&2
      exit 69
    fi
    printf 'P163 runtime: npm 上的最新 %s 是 %s（本次证据运行解析一次）\n' "$PKG" "$PI_VERSION"
  fi
  PI_DIR="$E/.runtime/$PI_VERSION"
  if [ -f "$PI_DIR/node_modules/$PKG/package.json" ]; then
    got="$(pkg_version "$PI_DIR")" || { printf 'P163 runtime: 读不出 %s 里那个包的版本（安装树不完整？）\n' "$PI_DIR" >&2; exit 69; }
    if [ "$got" != "$PI_VERSION" ]; then
      printf 'P163 runtime: %s 里已装的是 %s，但本次要用 %s —— 目录和版本对不上（拒绝）\n' "$PI_DIR" "$got" "$PI_VERSION" >&2
      exit 69
    fi
  else
    install_runtime "$PI_VERSION"
  fi
  PI_PKG_IN_CONTAINER="/runtime/node_modules/$PKG"
else
  MODULES=$HOME/.bun/install/global/node_modules
  if [ ! -f "$MODULES/$PKG/package.json" ]; then
    printf 'P163 runtime: 宿主观察路线找不到 %s/%s（宿主 pi 的安装位置）\n' "$MODULES" "$PKG" >&2
    exit 69
  fi
  printf '%s\n' '⚠ host 路线仅供人工观察，不作为判据；judge-second.py 会拒绝给这种现场出判据'
fi

REV_FULL=$(git rev-parse "$REV")
RUN_ID=$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')
STARTED_AT=$(date +%s)

# ① 现场重置：这一次的测量只看这一次。
L="$E/logs/$CASE"
rm -rf -- "$L"
# P393：容器的 scratch / HOME / history 落在**bind mount 的** /evidence/tmp（磁盘、宿主机可见），
# 不再只活在容器内 /tmp —— 容器结束后宿主上仍能读现场。
mkdir -p "$L" "$E/pkg" "$E/tmp"
cp -a "$(dirname "$0")/." "$E/pkg/"
P163_CASE="$CASE" P163_RUN_ID="$RUN_ID" P163_REV="$REV" P163_REV_FULL="$REV_FULL" \
P163_PI_VERSION="$PI_VERSION" P163_MODE="$MODE" P163_STARTED_AT="$STARTED_AT" \
P163_RUNTIME_REQUESTED="$RUNTIME" \
python3 - "$L/run.json" <<'PY'
import json, os, sys
keys = ('P163_CASE', 'P163_RUN_ID', 'P163_REV', 'P163_REV_FULL', 'P163_PI_VERSION', 'P163_MODE',
        'P163_STARTED_AT', 'P163_RUNTIME_REQUESTED')
run = {k[5:].lower(): os.environ[k] for k in keys}
run['started_at'] = int(run['started_at'])
with open(sys.argv[1], 'w') as f:
    json.dump(run, f, indent=1, sort_keys=True)
    f.write('\n')
PY
printf 'P163 clean case=%s run=%s revision=%s full=%s runtime=%s（requested=%s）mode=%s\n' \
  "$CASE" "$RUN_ID" "$REV" "$REV_FULL" "$PI_VERSION" "$RUNTIME" "$MODE"

args=(run --rm --network=none -i -e HOME=/tmp -e P138_CONTAINER=1 -e "P138_LONG=$LONG"
  -e "P138_OLD_NOTIFY=${P138_OLD_NOTIFY:-0}" -e "P143_DRAFT=${P143_DRAFT:-0}" -e "P138_TRACKED=${P138_TRACKED:-0}" -e "P138_SETTLE_DELAY=${P138_SETTLE_DELAY:-1}" -e "P138_SECOND=${P138_SECOND:-0}"
  -e "P163_RUN_ID=$RUN_ID" -e "P163_CASE=$CASE" -e "P163_MODE=$MODE" -e "P163_PI_VERSION=$PI_VERSION"
  -e "P163_BRANCH_UPSTREAM=${P163_BRANCH_UPSTREAM:-0}"
  -e "P163_DRAFT_AB=${P163_DRAFT_AB:-0}" -e "P163_BASELINE_NOW=${P163_BASELINE_NOW:-0}" -e "P163_DRAFT_TEXT=${P163_DRAFT_TEXT:-P163-HUMAN-DRAFT}" -e "TMPDIR=/evidence/tmp"
  -v "$ROOT:/src:ro" -v "$E:/evidence:rw" -w /src)
if [ "$MODE" = observation ]; then
  args+=(-v "$MODULES:$MODULES:ro" -e "P138_PI_PKG=$MODULES/$PKG")
else
  args+=(-v "$PI_DIR:/runtime:ro" -e "P138_PI_PKG=$PI_PKG_IN_CONTAINER")
fi
# Historical sources exist only in the disposable container; no checkout/reset of a branch.
git archive "$REV" skills | distrobox-host-exec podman "${args[@]}" "$IMAGE" bash -c '
  mkdir -p /tmp/history; tar -xf - -C /tmp/history
  if [ -e /tmp/history/skills/teamsmith/scripts/team ]; then export P138_SKILL=/tmp/history/skills/teamsmith
  else export P138_SKILL=/tmp/history/skills/pi-team; fi
  exec bash /evidence/pkg/scenario.sh "$1"
' _ "$CASE"
