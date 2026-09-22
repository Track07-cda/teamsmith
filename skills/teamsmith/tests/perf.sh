#!/usr/bin/env bash
# teamsmith · 性能套件（M58 · perf-suite-split；用户决定 D33「性能判定与正确性门禁分开」）
#
#   bash skills/teamsmith/tests/perf.sh                    # 默认：参考环境（钉死镜像）——同 --container
#   bash skills/teamsmith/tests/perf.sh --container        # 参考环境：ci/Containerfile 的钉死镜像
#   bash skills/teamsmith/tests/perf.sh --in-container     # 镜像内自述（外层容器调用的内部形状）：只认镜像
#                                                          # 自身的身份证明（M66→M69→M73）：ENV 身份信号
#                                                          # TEAM_PERF_PINNED_CONTAINER=1 + rootfs 标识文件
#                                                          # /etc/teamsmith-gate-image（内容逐字节等于封闭 token，
#                                                          # 且不得是挂载点 —— 挂来的不算镜像烘焙的），
#                                                          # 缺哪个/错哪个点名哪个 → 可见拒绝 exit 3
#   bash skills/teamsmith/tests/perf.sh --host             # 宿主：明确标注「非参考环境」
#   bash skills/teamsmith/tests/perf.sh --tree DIR         # 测哪棵树（默认：本文件所在的 checkout）
#
# 三条判定（红线数值与语义**逐字**保持拆分前：2000ms / 2000ms / 1% 单核，前提 0.75 / 0.25，
# 中位 of 5 / 中位 of 3，可见 SKIP 与 exit 4）：
#   ① 交互首帧      < PERF_FRAME_BUDGET_MS（前提 PERF_FIRST_FRAME_PREMISE_FACTOR，中位 of 3）
#   ② 帧装配线      ≤ PERF_FRAME_BUDGET_MS（前提 PERF_ASSEMBLY_PREMISE_FACTOR，5 次采样的中位）
#   ③ 稳态窗格 CPU  < PERF_CPU_MAX_PCT 单核（前提 PERF_CPU_PREMISE_FACTOR，采样窗三等分取中位）
# ①③ 由 tests/panel-cpu-premise.sh 驱赶（它的四个期望、finding→exit 4 语义与反后门断言不变），
# ② 由本套件直接测（夹具仓库里 5 次 `team monitor --print --no-activity`）。
#
# 退出码：**0** 全部判定都跑了且绿；**2** ≥1 红（红压过跳过）；**4** 没有红但 ≥1 可见 SKIP
#         （含裁决环境缺引擎/镜像时的降级）——没结论；**3** 搭建失败（缺 tmux / JS 运行时 / 面板 bundle）
#         或 --in-container 的身份证明缺失/不符（M66→M69：拒绝以参考环境自居）。
#
# 环境姿态（design D4）：
#   · 参考环境 = `ci/Containerfile` 的钉死镜像；`--host` 明确标注「非参考环境」。
#   · --in-container 只信镜像自身的身份证明（M66 · M64 F2 → M69 → M73）：① 镜像 ENV 的身份信号
#     TEAM_PERF_PINNED_CONTAINER=1（单独不够 —— 导出的变量宿主也能伪造，M64 F2 复验成立）；
#     ② rootfs 标识文件 /etc/teamsmith-gate-image 内容逐字节等于封闭 token（/run/.containerenv
#     不能当证据：开发宿主本身就是 distrobox，那文件在宿主也存在）；③ 该标识文件**不得是挂载点**
#     （M73 · M64 F2 第三轮：token 写在公开的 ci/Containerfile 里，谁都能挂一份同内容文件进容器 ——
#     内容对只证明文件对，证明不了「来自镜像 rootfs」；真镜像里它在 overlayfs 上，/proc/self/mounts
#     没有它的条目；套件自己的 wrapper 只挂 /work 与主仓，从不挂它）。缺哪个/错哪个点名哪个，
#     可见拒绝 exit 3，宿主读数绝不记在参考环境名下；老镜像（无标识文件）同样 exit 3 并点名重建。
#   · 引擎/镜像缺失 → 打印原因 + 精确的 build/run 命令 + 「参考环境不可用，本次为宿主判定，结论不作为
#     验收依据」，宿主读数照打但**不计成结论**（全部记 SKIP）→ exit 4。绝不静默把宿主数当参考。
#   · 锁：自己的 TEAM_PERF_LOCK（flock --close -w + holder）；**从不**拿正确性门禁的 TEAM_SMOKE_LOCK，
#     只在测量前对它做一次**只读**非阻塞探活（有人持锁就打印持有者与提示）。
#   · 夹具旋钮（只在 TEAM_PERF_FIXTURE=1 时生效，真路径一律忽略并打印）：TEAM_PERF_LOADAVG /
#     TEAM_PERF_CORES / TEAM_PERF_FRAME_DELAY_MS。
set -uo pipefail

# ── 命名单源常量（守卫 tests/gate-guard.sh 按它们做进出检查：门禁里不许有、这里必须有）──────────
PERF_FRAME_BUDGET_MS=2000
PERF_CPU_MAX_PCT=1
PERF_ASSEMBLY_PREMISE_FACTOR=0.75
PERF_FIRST_FRAME_PREMISE_FACTOR=0.25
PERF_CPU_PREMISE_FACTOR=0.25
PERF_SAMPLES=5

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
self="$here/perf.sh"
ORIG_ARGS=("$@")
tree=""
MODE=""                 # host | container | 空=默认（container，缺参考环境时可见降级）
IN_CONTAINER=0

usage() {
  cat <<'EOF'
用法：bash skills/teamsmith/tests/perf.sh [--host | --container] [--tree DIR]

  --container   在参考环境（ci/Containerfile 的钉死镜像）里跑；默认就是它。
  --in-container （镜像内部用）声明「我在钉死镜像里」：必须带着镜像自身的身份证明
                 —— ① 镜像 ENV 的身份信号 TEAM_PERF_PINNED_CONTAINER=1；② rootfs 标识文件
                 /etc/teamsmith-gate-image（内容逐字节等于封闭 token）；③ 该文件不得是挂载点
                 （挂载来的不是镜像烘焙的，M73）。缺哪个/错哪个点名哪个，可见拒绝 exit 3（M66→M69→M73）。
  --host        在宿主上跑，并标注「非参考环境」。
  --tree DIR    被测 checkout（默认：本文件所在的 checkout）。
  --help        这一屏。

退出码：0 全绿 ｜ 2 ≥1 红 ｜ 4 没结论（可见 SKIP，含参考环境不可用）｜ 3 搭建失败 / 身份信号拒绝。
旋钮：TEAM_PERF_IMAGE / TEAM_PERF_ENGINE / TEAM_PERF_LOCK / TEAM_PERF_LOCK_WAIT /
      TEAM_PERF_FIXTURE=1 + TEAM_PERF_LOADAVG / TEAM_PERF_CORES / TEAM_PERF_FRAME_DELAY_MS
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --host) MODE=host; shift ;;
    --container) MODE=container; shift ;;
    --in-container) MODE=container; IN_CONTAINER=1; shift ;;
    --tree) tree="${2:?--tree 需要一个目录}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'perf.sh: 未知参数 %s（--host | --container | --tree DIR）\n' "$1" >&2; exit 3 ;;
  esac
done
tree="${tree:-$(cd -P "$here/../../.." && pwd)}"
team_bin="$tree/skills/teamsmith/scripts/team"
panel_bundle="$tree/skills/teamsmith/scripts/panel/panel.js"
panel_fixture="$tree/skills/teamsmith/tests/panel-cpu-premise.sh"

say()  { printf '%s\n' "$*"; }
hdr()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
note() { printf '  \033[33mℹ\033[0m %s\n' "$*"; }

# ── 钉死镜像的身份证明（M66 · M64 F2 → M69 → M73：--in-container 不得把宿主谎报成参考环境）──
# 校验的三份证据都必须来自镜像自身，缺哪个/错哪个点名哪个（exit 3）：
#   ① 环境信号 TEAM_PERF_PINNED_CONTAINER=1 —— ci/Containerfile 的 ENV。单独它**不够**：导出的
#      变量宿主也能伪造（M64 F2 复验：宿主导出信号后套件把宿主 node 自述成「参考环境」）。
#   ② 标识文件 PERF_IMAGE_IDENTITY_FILE —— ci/Containerfile 的 RUN 落在镜像 rootfs 里，内容必须
#      逐字节等于封闭 token PERF_IMAGE_IDENTITY_TOKEN（版本变动时跟着变）。宿主没有它；
#      /run/.containerenv 不能顶它（开发宿主本身是 distrobox，那文件宿主也有 —— PM 实测）。
#   ③ 标识文件**不得是挂载点** —— token 写在公开的 ci/Containerfile 里，谁都能 `-v` 挂一份同内容
#      文件进容器（M64 F2 第三轮：foreign 镜像 + 挂载 token + ENV=1 自称参考环境还跑绿了）。
#      真镜像里它落在 overlayfs 的 / 上，/proc/self/mounts 没有它的条目；套件自己的 wrapper
#      （perf_run_in_container）只挂 /work 与主仓，从不挂它。
# 信任边界（PM 裁定，详见 references/troubleshooting.md）：防的是**非故意**误用的一切形状
# （裸宿主/导出变量/陈旧镜像/内容被改/挂载伪造）；调用者**控制容器运行时、故意**把公开 token
# 烘进自建镜像（或伪装 mounts 表）在边界外 —— 容器内自检有硬上限，可疑结论的复核永远能看环境自述。
# 信号必须在拿锁/搭建**之前**验：宿主误叫连锁都不沾。
PERF_IMAGE_IDENTITY_FILE=/etc/teamsmith-gate-image
PERF_IMAGE_IDENTITY_TOKEN='teamsmith-gate:1'
perf_pinned_signal_rc() { [ "${TEAM_PERF_PINNED_CONTAINER:-}" = "1" ]; }
# 标识文件：0 = 存在且内容逐字节等于 token；1 = 缺失/不可读；2 = 内容不符。
perf_image_identity_rc() { # [file]（参数仅供自检；真路径用上面的硬编码常量）
  local f="${1:-$PERF_IMAGE_IDENTITY_FILE}"
  [ -r "$f" ] || return 1
  printf '%s\n' "$PERF_IMAGE_IDENTITY_TOKEN" | cmp -s - "$f" || return 2
  return 0
}
# ③ 标识文件不得是挂载点（M73）：0 = 是挂载目标（伪造形状）；1 = 不是。读 /proc/self/mounts
# 第 2 列（挂载目标；特殊字符八进制转义，如空格 = \040，先解开再逐字节比）。读不到 mounts 表
# → 这一条判不了，不据此拒绝（伪装 mounts 表需要控制容器运行时，已在信任边界外）。
perf_image_identity_mounted_rc() { # [mounts_file]（参数仅供自检；真路径读 /proc/self/mounts）
  local mf="${1:-/proc/self/mounts}" mp
  [ -r "$mf" ] || return 1
  while read -r _ mp _; do
    mp="$(printf '%b' "$mp")"
    [ "$mp" = "$PERF_IMAGE_IDENTITY_FILE" ] && return 0
  done < "$mf"
  return 1
}
perf_require_pinned_container() {
  local fail=0 cur id_rc=0
  if ! perf_pinned_signal_rc; then
    cur="缺失"
    [ -n "${TEAM_PERF_PINNED_CONTAINER:-}" ] && cur="值是「${TEAM_PERF_PINNED_CONTAINER}」而不是 1"
    printf 'perf: 身份证明 ① 不符 —— 环境身份信号 TEAM_PERF_PINNED_CONTAINER=1（当前：%s）；它只能由镜像 ENV 带着，调用者 -e/导进来的不算数。\n' "$cur" >&2
    fail=1
  fi
  perf_image_identity_rc || id_rc=$?
  case "$id_rc" in
    0) ;;
    1) printf 'perf: 身份证明 ② 缺失 —— 镜像标识文件 %s 不存在/不可读；钉死镜像的 rootfs 里带着它（ci/Containerfile 的 RUN）。老镜像没有它 → 请按下面命令重建镜像。\n' "$PERF_IMAGE_IDENTITY_FILE" >&2
       fail=1 ;;
    2) printf 'perf: 身份证明 ② 不符 —— 标识文件 %s 的内容不是期望的封闭 token「%s」（逐字节比较）；这不是本套件认的钉死镜像。\n' "$PERF_IMAGE_IDENTITY_FILE" "$PERF_IMAGE_IDENTITY_TOKEN" >&2
       fail=1 ;;
  esac
  if [ "$id_rc" != "1" ] && perf_image_identity_mounted_rc; then
    printf 'perf: 身份证明 ③ 不符 —— 标识文件 %s 是一个**挂载点**（/proc/self/mounts 里有它的条目）：标识文件是挂载的，不是镜像烘焙的（token 是公开的，谁都能挂一份同内容文件，M64 F2 第三轮）；这不是本套件认的钉死镜像。\n' "$PERF_IMAGE_IDENTITY_FILE" >&2
    fail=1
  fi
  [ "$fail" = "0" ] && return 0
  printf 'perf: 拒绝以参考环境自居 —— --in-container 要求身份证明都在且都来自镜像自身（① 环境信号 + ② 标识文件内容逐字节等于 token + ③ 标识文件不是挂载点），上面点名的就是缺的/错的。\n' >&2
  printf '      不在钉死容器里：要么进镜像跑（--container 会自己起容器，缺镜像时打印 build/run 命令；或 CI 形状\n' >&2
  printf '      podman run … bash -c '"'"'… perf.sh --in-container'"'"'），要么改用 --host（非参考环境，结论不作为验收依据）。\n' >&2
  printf '      重建参考镜像：<engine> build -f ci/Containerfile -t teamsmith-gate:local . ；宿主读数绝不记在参考环境名下。（exit 3）\n' >&2
  exit 3
}

# ── 锁：自己一把（TEAM_PERF_LOCK），绝不拿门禁锁 ─────────────────────────────────────────────
# 两次性能运行必须串行（夹具量的是真 pane / CPU 份额，互相测量会让数字失去意义）。
# 用与 smoke 同形的 `flock --close` 包住整个脚本（重新 exec 自己）：锁挂在 flock 那个父进程上，
# 套件与它的子孙都不继承 fd —— 夹具留下的后台进程也就不会漏锁。
perf_lock_or_continue() {
  [ "${TEAM_PERF_LOCK_WRAPPED:-0}" = "1" ] && return 0
  [ "${TEAM_PERF_NO_LOCK:-0}" = "1" ] && { note "TEAM_PERF_NO_LOCK=1 → 不与别的性能运行串行（自担并发干扰）"; return 0; }
  if ! command -v flock >/dev/null 2>&1; then
    note "本机没有 flock → 不与别的性能运行串行（自担并发干扰）"
    return 0
  fi
  local lock="${TEAM_PERF_LOCK:-${TMPDIR:-/tmp}/teamsmith-perf.lock}" wait_s="${TEAM_PERF_LOCK_WAIT:-1800}"
  case "$wait_s" in ''|*[!0-9]*) wait_s=1800 ;; esac
  mkdir -p "$(dirname "$lock")" 2>/dev/null || true
  : >>"$lock" 2>/dev/null || { note "锁文件 $lock 建不了 → 不串行"; return 0; }
  if ! flock -n "$lock" true 2>/dev/null; then
    say "另一个性能运行正在跑（$(cat "$lock.holder" 2>/dev/null || printf '持有者未知')）；本次排队，最多等 ${wait_s}s"
  fi
  export TEAM_PERF_LOCK_WRAPPED=1
  # 用 flock 包住**重新执行的自己**（--close：子进程不继承 fd，夹具留下的后台进程不会漏锁）。
  # 不用 exec：等待上限到了要留一句可读的话（exec 之后脚本已经不在了）。性能套件自己的退出码是
  # 0/2/3/4，所以 flock 的 1 只可能是「等锁超时」。
  local rc=0
  flock --close -w "$wait_s" "$lock" bash "$self" "${ORIG_ARGS[@]}" || rc=$?
  if [ "$rc" = "1" ]; then
    # 套件自己的退出码只有 0/2/3/4 —— 1 只可能是「等锁超时」（无并发测量，视作没结论）→ exit 3。
    printf 'perf: 等待 %ss 仍拿不到性能锁（持有者：%s）—— 另一个性能运行还没结束；不并发测量（exit 3）\n' \
      "$wait_s" "$(cat "$lock.holder" 2>/dev/null || printf '未知')" >&2
    exit 3
  fi
  exit "$rc"
}
# --in-container 先验身份信号：缺了在这里就 exit 3，锁、临时目录、测量一样不沾。
if [ "$IN_CONTAINER" = "1" ]; then perf_require_pinned_container; fi
perf_lock_or_continue
if [ "${TEAM_PERF_LOCK_WRAPPED:-0}" = "1" ]; then
  PERF_LOCK="${TEAM_PERF_LOCK:-${TMPDIR:-/tmp}/teamsmith-perf.lock}"
  printf '%s pid=%s cmd=perf.sh\n' "$(date -Is)" "$$" > "$PERF_LOCK.holder" 2>/dev/null || true
fi

# 只读探活门禁锁：门禁在跑时性能读数会被它影响，打印持有者；**不排队等它**（性能锁独立）。
perf_smoke_lock_probe() {
  local lock="${TEAM_SMOKE_LOCK:-${TMPDIR:-/tmp}/teamsmith-smoke.lock}"
  [ -e "$lock" ] || return 0
  if command -v flock >/dev/null 2>&1 && ! flock -n "$lock" true 2>/dev/null; then
    note "正确性门禁正在跑（$(cat "$lock.holder" 2>/dev/null || printf '持有者未知')）—— 本次性能读数可能受它影响（性能锁独立，不等它）"
  fi
}

# ── 夹具旋钮（只在 TEAM_PERF_FIXTURE=1 时生效；真路径忽略且打印）────────────────────────────
perf_fixture_on() { [ "${TEAM_PERF_FIXTURE:-0}" = "1" ]; }
perf_notice() { printf '  忽略 %s=%s（只有夹具模式 TEAM_PERF_FIXTURE=1 接受注入；真路径读真值）\n' "$1" "$2" >&2; }
perf_load_reading() {
  if [ -n "${TEAM_PERF_LOADAVG:-}" ]; then
    if perf_fixture_on; then printf '%s\n' "$TEAM_PERF_LOADAVG"; return 0; fi
    perf_notice TEAM_PERF_LOADAVG "$TEAM_PERF_LOADAVG"
  fi
  cut -d' ' -f1 /proc/loadavg 2>/dev/null || printf '?'
}
perf_cores() {
  if [ -n "${TEAM_PERF_CORES:-}" ]; then
    if perf_fixture_on; then printf '%s\n' "$TEAM_PERF_CORES"; return 0; fi
    perf_notice TEAM_PERF_CORES "$TEAM_PERF_CORES"
  fi
  nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || printf '0'
}
perf_inject_ms() {
  local v="${TEAM_PERF_FRAME_DELAY_MS:-}"
  if [ -n "$v" ]; then
    if perf_fixture_on; then printf '%s\n' "$v"; return 0; fi
    perf_notice TEAM_PERF_FRAME_DELAY_MS "$v"
  fi
  printf '0\n'
}
perf_median() { printf '%s\n' "$@" | sort -n | awk '{a[NR] = $1} END {print a[int((NR + 1) / 2)]}'; }

# ── 判定（纯逻辑；真实路径与自检用**同一组**函数，所以自检不是另写一套）──────────────────────
# 前提：loadavg_1m ≤ factor × 逻辑核数（核数/读数不可用一律算不成立 —— 测不准就不判红）。
perf_premise_rc() { # <load> <cores> <factor> → 0 成立 / 1 不成立
  local load="$1" cores="$2" factor="$3" thr
  case "$load" in ''|*[!0-9.]*) return 1 ;; esac
  case "$cores" in ''|*[!0-9]*) return 1 ;; esac
  [ "$cores" -gt 0 ] 2>/dev/null || return 1
  thr="$(awk -v c="$cores" -v f="$factor" 'BEGIN { printf "%.2f", f * c }')"
  awk -v l="$load" -v t="$thr" 'BEGIN { exit !(l <= t) }'
}
# 帧预算判定：mode=le（装配，≤ 绿）或 lt（交互首帧，< 绿，≥ 红）。
perf_budget_rc() { # <值> <load> <cores> <factor> <le|lt> → 0 绿 / 1 红 / 2 SKIP
  perf_premise_rc "$2" "$3" "$4" || return 2
  if [ "$5" = "lt" ]; then
    awk -v v="$1" -v b="$PERF_FRAME_BUDGET_MS" 'BEGIN { exit !(v < b) }'
  else
    awk -v v="$1" -v b="$PERF_FRAME_BUDGET_MS" 'BEGIN { exit !(v <= b) }'
  fi
}
# 稳态窗格 CPU：< 1% 单核为绿。
perf_cpu_rc() { # <百分比> <load> <cores> <factor> → 0 / 1 / 2
  perf_premise_rc "$2" "$3" "$4" || return 2
  awk -v v="$1" -v b="$PERF_CPU_MAX_PCT" 'BEGIN { exit !(v < b) }'
}

# ── 引擎 / 镜像（参考环境）──────────────────────────────────────────────────────────────────
PERF_ENGINE=()
PERF_IMAGE=""
perf_engine_label() { printf '%s' "${PERF_ENGINE[*]}"; }
perf_detect_engine() {
  if [ -n "${TEAM_PERF_ENGINE:-}" ]; then
    # 允许带命令前缀（distrobox 场景：TEAM_PERF_ENGINE="distrobox-host-exec podman"）
    read -r -a PERF_ENGINE <<<"$TEAM_PERF_ENGINE"
    return 0
  fi
  if command -v podman >/dev/null 2>&1; then PERF_ENGINE=(podman); return 0; fi
  if command -v docker >/dev/null 2>&1; then PERF_ENGINE=(docker); return 0; fi
  if command -v distrobox-host-exec >/dev/null 2>&1; then
    if distrobox-host-exec podman --version >/dev/null 2>&1; then PERF_ENGINE=(distrobox-host-exec podman); return 0; fi
    if distrobox-host-exec docker --version >/dev/null 2>&1; then PERF_ENGINE=(distrobox-host-exec docker); return 0; fi
  fi
  return 1
}
perf_engine_is_podman() { [ "$(basename "${PERF_ENGINE[${#PERF_ENGINE[@]}-1]}")" = "podman" ]; }
perf_image_exists() { "${PERF_ENGINE[@]}" image exists "$1" >/dev/null 2>&1; }
perf_detect_image() {
  local cand
  if [ -n "${TEAM_PERF_IMAGE:-}" ]; then
    perf_image_exists "$TEAM_PERF_IMAGE" && { PERF_IMAGE="$TEAM_PERF_IMAGE"; return 0; }
    return 1
  fi
  for cand in localhost/teamsmith-gate:local teamsmith-gate:local localhost/teamsmith-gate:m51 \
              localhost/teamsmith-gate:latest teamsmith-gates:ci; do
    perf_image_exists "$cand" && { PERF_IMAGE="$cand"; return 0; }
  done
  return 1
}
perf_print_build_run() {
  local eng; eng="$(perf_engine_label)"
  say "  构建参考镜像：${eng:-<engine>} build -f ci/Containerfile -t teamsmith-gate:local ."
  say "  在参考环境里跑：${eng:-<engine>} run --rm --userns=keep-id --pid=host --cgroups=enabled -e HOME=/tmp \\"
  say "      -v \"$tree:/work:ro\" -w /work teamsmith-gate:local \\"
  say "      bash -c 'bash /work/skills/teamsmith/tests/perf.sh --in-container'"
  say "  （--in-container 只认镜像自身的身份证明：ENV 信号 TEAM_PERF_PINNED_CONTAINER=1 + 标识文件 /etc/teamsmith-gate-image（镜像烘焙的，挂载的不算）；缺哪个/错哪个 → 可见拒绝 exit 3；宿主判定用 --host）"
  say "  （放行引擎/镜像也可显式指定：TEAM_PERF_ENGINE、TEAM_PERF_IMAGE）"
}
perf_main_repo() { # → 工作树之外的 git common dir 的父目录（容器里挂上它，worktree 的 .git 才解析得动）
  local common main
  common="$(git -C "$tree" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  [ -n "$common" ] || return 0
  main="$(cd -P "$(dirname "$common")" 2>/dev/null && pwd || true)"
  [ -n "$main" ] || return 0
  [ "$main" = "$tree" ] && return 0                 # 主工作树：本身就在挂载里
  case "$main" in "$tree"/*) return 0 ;; esac        # 主仓在 tree 里（子模块等）：没有可挂的
  printf '%s\n' "$main"
}
perf_run_in_container() {
  local -a eng_env=()
  local mainrepo; mainrepo="$(perf_main_repo)"
  local -a mounts=(-v "$tree:/work:ro")
  [ -n "$mainrepo" ] && mounts+=(-v "$mainrepo:$mainrepo:ro")
  local -a opts=()
  if perf_engine_is_podman; then
    opts=(--userns=keep-id --pid=host --cgroups=enabled)
  else
    opts=(--pid=host --user "$(id -u):$(id -g)")
  fi
  eng_env=(-e HOME=/tmp -e TEAM_PERF_MODE=container -e "TEAM_PERF_REV=$(git -C "$tree" rev-parse --short HEAD 2>/dev/null || printf 'unknown')")
  # 夹具旋钮与锁身份透传进容器（A1 的注入翻转就在容器里跑）。
  local k
  for k in TEAM_PERF_FIXTURE TEAM_PERF_LOADAVG TEAM_PERF_CORES TEAM_PERF_FRAME_DELAY_MS \
           TEAM_PERF_LOCK_WRAPPED TEAM_PERF_NO_LOCK TEAM_PANEL_CPU_SECS; do
    [ -n "${!k:-}" ] && eng_env+=(-e "$k=${!k}")
  done
  say "参考环境：镜像 $PERF_IMAGE（引擎 ${PERF_ENGINE[*]}）"
  # 身份证明（ENV 身份信号 TEAM_PERF_PINNED_CONTAINER=1 + rootfs 标识文件
  # /etc/teamsmith-gate-image）由镜像自己带着（ci/Containerfile 的 ENV 与 RUN）—— 故意**不**用
  # -e/挂载透传任何一个：那是镜像的身份证明，调用者传进来的不算数（宿主可以伪造，M64 F2；
  # 挂载透传的还会被内层 M73 的挂载点检查直接拒绝）。
  # 旧镜像没这两行 → 内层 --in-container 可见拒绝 exit 3 并点名，重建镜像即可。
  "${PERF_ENGINE[@]}" run --rm "${opts[@]}" "${eng_env[@]}" "${mounts[@]}" -w /work "$PERF_IMAGE" \
    bash -c 'bash /work/skills/teamsmith/tests/perf.sh --in-container --tree /work'
}

# ── 搭建与测量 ─────────────────────────────────────────────────────────────────────────────
PERF_TMP="$(mktemp -d "${TMPDIR:-/tmp}/teamsmith-perf.XXXXXX")" || { printf 'perf: 建不了临时目录\n' >&2; exit 3; }
perf_cleanup() { rm -rf "$PERF_TMP" 2>/dev/null || true; }
trap perf_cleanup EXIT

PERF_FIX=""
perf_setup_fixture() { # 夹具仓库（装配判定测的是面板装配，不是真项目的文档量）
  PERF_FIX="$PERF_TMP/repo"
  mkdir -p "$PERF_FIX"
  ( cd "$PERF_FIX" && git init -q -b main && git config user.email perf@teamsmith \
      && git config user.name perf && printf '# perf fixture\n' > README.md && git add -A && git commit -qm init ) >/dev/null 2>&1 || return 1
  mkdir -p "$PERF_FIX/openspec" "$PERF_FIX/.pi/team/state" "$PERF_FIX/docs/team/reports" "$PERF_FIX/docs/team/reviews"
  ( cd "$PERF_FIX" && perf_team_env_init bash "$team_bin" init --session "teamsmith-perf-$$" \
      --agents "dev verify" --vcs local --gates "true" --docs docs/team ) >"$PERF_TMP/init.log" 2>&1 || return 1
  printf '2026-01-01T00:00:01Z RAM 可用 4000MB ｜ 磁盘 swap 空闲 3000MB ｜ 估算可再加 5 个 agent\n' \
    > "$PERF_FIX/.pi/team/state/capacity.log"
  return 0
}
# 夹具仓库里的 team 调用：清掉继承的团队身份与所有夹具旋钮（身份隔离，M7.2 纪律）。
perf_team_env_init() { env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
  -u TEAM_STATE_DIR -u TEAM_JS_BIN -u TEAM_REQUIRE_JS -u TEAM_MONITOR_ACTIVITY -u TEAM_MONITOR_UI \
  -u TEAM_AGENT_LOG_GLOB -u TEAM_SMOKE_FIXTURE -u TEAM_SMOKE_LOADAVG -u TEAM_SMOKE_CORES \
  -u TEAM_SMOKE_FRAME_DELAY_MS -u TEAM_PANEL_CPU_LOADAVG -u TEAM_PANEL_CPU_CORES \
  -u TEAM_PANEL_CPU_FRAME_DELAY_MS -u TEAM_PANEL_CPU_PREMISE_ONLY "$@"; }
perf_team() { ( cd "$PERF_FIX" && perf_team_env_init bash "$team_bin" "$@" ); }

perf_measure_assembly() { # → PERF_OBS 数组 + PERF_ASM_MEDIAN
  local inject_ms inject_s t0 i
  inject_ms="$(perf_inject_ms)"
  case "$inject_ms" in ''|*[!0-9]*) inject_ms=0 ;; esac
  inject_s="$(awk -v ms="$inject_ms" 'BEGIN { printf "%.3f", ms / 1000 }')"
  PERF_OBS=()
  for ((i = 1; i <= PERF_SAMPLES; i++)); do
    t0="$(date +%s%3N)"
    perf_team monitor --print --no-activity >/dev/null 2>&1
    [ "$inject_ms" -gt 0 ] && sleep "$inject_s"   # 注入落在测量窗口里
    PERF_OBS+=("$(( $(date +%s%3N) - t0 ))")
  done
  PERF_ASM_MEDIAN="$(perf_median "${PERF_OBS[@]}")"
}

# ── 汇总状态 ────────────────────────────────────────────────────────────────────────────────
J_FIRST_VERDICT=""; J_FIRST_MEDIAN="?"; J_FIRST_READ=""; J_FIRST_PREMISE=""
J_ASM_VERDICT="";   J_ASM_MEDIAN="?";   J_ASM_READ="";   J_ASM_PREMISE=""
J_CPU_VERDICT="";   J_CPU_MEDIAN="?";   J_CPU_READ="";   J_CPU_PREMISE=""
SELFTEST_FAIL=0
UNAVAILABLE=0

perf_premise_text() { # <factor> → 「0.75 × 32 = 24.00 成立/不成立（loadavg X）」
  local factor="$1" cores="$2" load="$3" thr
  case "$cores" in ''|*[!0-9]*) cores=0 ;; esac
  thr="$(awk -v c="$cores" -v f="$factor" 'BEGIN { printf "%.2f", f * c }')"
  if perf_premise_rc "$load" "$cores" "$factor"; then
    printf '%s × %s = %s 成立（loadavg %s）' "$factor" "$cores" "$thr" "$load"
  else
    printf '%s × %s = %s **不成立**（loadavg %s）' "$factor" "$cores" "$thr" "$load"
  fi
}

# ── 环境自述（判定之前）────────────────────────────────────────────────────────────────────
perf_env_description() { # <mode-label> <reference yes|no>
  local mode_label="$1" reference="$2" cores load quota js tmux rev
  cores="$(perf_cores)"; load="$(perf_load_reading)"
  if [ -r /sys/fs/cgroup/cpu.max ]; then
    quota="$(head -1 /sys/fs/cgroup/cpu.max 2>/dev/null)"; [ -n "$quota" ] || quota="（读不到）"
  else
    quota="无（没有 cpu.max）"
  fi
  js="${TEAM_JS_BIN:-$(command -v node 2>/dev/null || command -v bun 2>/dev/null || true)}"
  js="$js $("$js" --version 2>/dev/null | head -1 || true)"
  tmux="$(command -v tmux 2>/dev/null || printf '缺') $(tmux -V 2>/dev/null || true)"
  rev="$(git -C "$tree" rev-parse --short HEAD 2>/dev/null || printf '%s' "${TEAM_PERF_REV:-unknown}")"
  hdr "环境自述（performance suite）"
  say "  模式          : $mode_label（$([ "$reference" = yes ] && printf '参考环境' || printf '非参考环境：结论不作为验收依据')）"
  say "  可见逻辑核数   : ${cores}$([ -n "${TEAM_PERF_CORES:-}" ] && printf '（TEAM_PERF_CORES 注入）' || printf '（nproc）')"
  say "  CPU 配额       : $quota"
  say "  loadavg (1m)   : $load$([ -n "${TEAM_PERF_LOADAVG:-}" ] && printf '（TEAM_PERF_LOADAVG 注入）' || true)"
  say "  JS 运行时      : ${js:-缺}"
  say "  tmux          : ${tmux:-缺}"
  say "  被测版本       : $rev（$tree）"
  say "  前提线         : 装配 0.75 × ${cores} = $(awk -v c="$cores" 'BEGIN{printf "%.2f", 0.75*c}') ｜ 首帧/CPU 0.25 × ${cores} = $(awk -v c="$cores" 'BEGIN{printf "%.2f", 0.25*c}')"
}

# ── 判定 ②：帧装配线（本套件直接测）──────────────────────────────────────────────────────────
perf_judge_assembly() {
  local load cores rc=0
  perf_measure_assembly
  load="$(perf_load_reading)"; cores="$(perf_cores)"
  J_ASM_PREMISE="$(perf_premise_text "$PERF_ASSEMBLY_PREMISE_FACTOR" "$cores" "$load")"
  J_ASM_READ="$(printf '%s, ' "${PERF_OBS[@]}")"; J_ASM_READ="${J_ASM_READ%, }"
  J_ASM_MEDIAN="$PERF_ASM_MEDIAN"
  perf_budget_rc "$PERF_ASM_MEDIAN" "$load" "$cores" "$PERF_ASSEMBLY_PREMISE_FACTOR" le || rc=$?
  case "$rc" in
    0) J_ASM_VERDICT=OK ;;
    1) J_ASM_VERDICT=RED ;;
    *) J_ASM_VERDICT=SKIP ;;
  esac
  if [ "$UNAVAILABLE" = "1" ]; then
    J_ASM_VERDICT=SKIP
    say "  ② 帧装配线：宿主中位 ${J_ASM_MEDIAN}ms（样本 $J_ASM_READ）—— 参考环境不可用，不计成结论"
  else
    say "  ② 帧装配线：${PERF_SAMPLES} 次采样 $J_ASM_READ → 中位 ${J_ASM_MEDIAN}ms ≤ ${PERF_FRAME_BUDGET_MS}ms ｜ $J_ASM_PREMISE → $J_ASM_VERDICT"
  fi
}

# ── 判定 ①③：交互首帧 + 稳态窗格 CPU（由 panel-cpu-premise 夹具驱赶）────────────────────────
perf_judge_panel() {
  local out="$PERF_TMP/panel-premise.log" rc=0 line ff_line pc_line reason
  TEAM_PANEL_CPU_SECS="${TEAM_PANEL_CPU_SECS:-6}" bash "$panel_fixture" >"$out" 2>&1 || rc=$?
  PERF_PANEL_RC="$rc"
  line="$(grep -a '== 结果 ==' "$out" 2>/dev/null | tail -1 | sed 's/\x1b\[[0-9;]*m//g')"
  PERF_PANEL_RESULT_LINE="$line"
  ff_line="$(sed -n 's/^first_frame_line=//p' "$out" | tail -1)"
  pc_line="$(sed -n 's/^pane_cpu_line=//p' "$out" | tail -1)"
  J_FIRST_READ="$ff_line"; J_CPU_READ="$pc_line"
  J_FIRST_MEDIAN="$(printf '%s' "$ff_line" | sed -n 's/.*-> median \([0-9]*\|never\).*/\1/p')"
  J_CPU_MEDIAN="$(printf '%s' "$pc_line" | sed -n 's/.*-> median \([0-9.]*\)%.*/\1/p')"
  [ -n "$J_FIRST_MEDIAN" ] || J_FIRST_MEDIAN="?"
  [ -n "$J_CPU_MEDIAN" ] || J_CPU_MEDIAN="?"
  case "$rc" in
    0) J_FIRST_VERDICT=OK; J_CPU_VERDICT=OK ;;
    4) J_FIRST_VERDICT=SKIP; J_CPU_VERDICT=SKIP ;;
    *) J_FIRST_VERDICT=RED; J_CPU_VERDICT=RED ;;
  esac
  local pload pcores
  pload="$(perf_load_reading)"; pcores="$(perf_cores)"
  J_FIRST_PREMISE="$(perf_premise_text "$PERF_FIRST_FRAME_PREMISE_FACTOR" "$pcores" "$pload")"
  J_CPU_PREMISE="$(perf_premise_text "$PERF_CPU_PREMISE_FACTOR" "$pcores" "$pload")"
  if [ "$UNAVAILABLE" = "1" ]; then
    J_FIRST_VERDICT=SKIP; J_CPU_VERDICT=SKIP
    say "  ① 交互首帧：宿主读数 ${J_FIRST_READ:-无} —— 参考环境不可用，不计成结论"
    say "  ③ 稳态窗格 CPU：宿主读数 ${J_CPU_READ:-无} —— 参考环境不可用，不计成结论"
    return 0
  fi
  if [ "$rc" = "1" ]; then
    reason="$(sed 's/\x1b\[[0-9;]*m//g' "$out" | grep -a '✗' | head -1)"
    say "  ①③ 面板夹具失败（rc=1）：${reason:-见下方日志}"
  elif [ "$rc" = "4" ]; then
    reason="$(sed 's/\x1b\[[0-9;]*m//g' "$out" | grep -aE 'SKIP|finding' | head -1)"
    say "  ①③ 面板夹具可见 SKIP（rc=4 = 没结论）：${reason:-负载前提不成立或环境缺 GNU time}"
  fi
  say "  ① 交互首帧：${J_FIRST_READ:-无读数} ｜ $J_FIRST_PREMISE → $J_FIRST_VERDICT"
  say "  ③ 稳态窗格 CPU：${J_CPU_READ:-无读数} ｜ $J_CPU_PREMISE → $J_CPU_VERDICT"
}

# ── 自检（判定不许烂掉：同一组判定函数 + 真路径的旋钮忽略）─────────────────────────────────
perf_self_tests() {
  local st_rc
  hdr "自检（判定函数与夹具旋钮）"
  st() { # <名字> <期望 rc> <实际 rc>
    if [ "$2" = "$3" ]; then
      printf '  \033[32m✓\033[0m 自检 · %s（实际 %s）\n' "$1" "$3"
    else
      printf '  \033[31m✗\033[0m 自检 · %s（期望 %s，实际 %s）\n' "$1" "$2" "$3"; SELFTEST_FAIL=$((SELFTEST_FAIL + 1))
    fi
  }
  local C=32
  # 前提边界：== 阈值算成立（≤）；阈值 + 0.1 算不成立。两个系数都测（0.75 装配 / 0.25 首帧·CPU）。
  st_rc=0; perf_budget_rc 1200 "$(awk -v c=$C 'BEGIN{printf "%.2f", 0.75*c}')" "$C" 0.75 le || st_rc=$?
  st "前提边界 0.75：loadavg == 阈值算成立" 0 "$st_rc"
  st_rc=0; perf_budget_rc 1200 "$(awk -v c=$C 'BEGIN{printf "%.2f", 0.75*c+0.1}')" "$C" 0.75 le || st_rc=$?
  st "前提边界 0.75：阈值 +0.1 算不成立" 2 "$st_rc"
  st_rc=0; perf_cpu_rc 0.5 "$(awk -v c=$C 'BEGIN{printf "%.2f", 0.25*c}')" "$C" 0.25 || st_rc=$?
  st "前提边界 0.25：loadavg == 阈值算成立" 0 "$st_rc"
  st_rc=0; perf_cpu_rc 0.5 "$(awk -v c=$C 'BEGIN{printf "%.2f", 0.25*c+0.1}')" "$C" 0.25 || st_rc=$?
  st "前提边界 0.25：阈值 +0.1 算不成立" 2 "$st_rc"
  # 注入的慢帧 → **红**（证明套件不是永远绿）；超前提负载 + 同一个慢帧 → 可见 SKIP（前提不是逃逸门）。
  st_rc=0; perf_budget_rc 2600 0.50 "$C" 0.75 le || st_rc=$?
  st "注入慢帧（2600ms）+ 安静 → 红" 1 "$st_rc"
  st_rc=0; perf_budget_rc 2600 "$(awk -v c=$C 'BEGIN{printf "%.2f", 0.75*c+0.1}')" "$C" 0.75 le || st_rc=$?
  st "注入慢帧 + 超前提负载 → 可见 SKIP" 2 "$st_rc"
  st_rc=0; perf_budget_rc 1200 0.50 "$C" 0.75 le || st_rc=$?
  st "健康帧 + 安静 → 绿" 0 "$st_rc"
  # 首帧的红线是 < 2000（1900 绿、2000 红）；CPU 是 < 1（0.99 绿、1.00 红）。
  st_rc=0; perf_budget_rc 1900 0.50 "$C" 0.25 lt || st_rc=$?
  st "首帧 1900ms + 安静 → 绿" 0 "$st_rc"
  st_rc=0; perf_budget_rc 2000 0.50 "$C" 0.25 lt || st_rc=$?
  st "首帧 2000ms + 安静 → 红（< 2000 才算绿）" 1 "$st_rc"
  st_rc=0; perf_cpu_rc 0.99 0.50 "$C" 0.25 || st_rc=$?
  st "窗格 CPU 0.99% → 绿" 0 "$st_rc"
  st_rc=0; perf_cpu_rc 1.00 0.50 "$C" 0.25 || st_rc=$?
  st "窗格 CPU 1.00% → 红（< 1% 才算绿）" 1 "$st_rc"
  # 中位本体（拆分前 smoke 的判定自检，原样搬来）：单次越线仍绿、中位越线才红。
  if [ "$(perf_median 1240 1417 2030 1400 1500)" -le 2000 ] && [ "$(perf_median 2100 2050 2200 1900 2300)" -gt 2000 ]; then
    printf '  \033[32m✓\033[0m 自检 · 中位：单次越线（2030ms）仍绿、中位越线（2100ms）判红\n'
  else
    printf '  \033[31m✗\033[0m 自检 · 中位判定坏了（%s / %s）\n' "$(perf_median 1240 1417 2030 1400 1500)" "$(perf_median 2100 2050 2200 1900 2300)"
    SELFTEST_FAIL=$((SELFTEST_FAIL + 1))
  fi
  # 身份证明（M66 · M64 F2 → M69）：双重校验。① ENV 信号 =1 才通过，缺失/其它值一律拒绝；
  # ② 标识文件存在且内容逐字节等于封闭 token —— --in-container 的谎报守卫用的就是同一组函数；
  # 接线（入口先验证明再碰锁）用真 CLI 子进程钉，拒绝必须瞬时（timeout 10：若接线被改回
  # 「信了口头声明」，子进程会走进锁/套件被杀 → rc≠3 → 红）。
  st_rc=0; ( TEAM_PERF_PINNED_CONTAINER=1; perf_pinned_signal_rc ) || st_rc=$?
  st "身份信号：=1 → 通过" 0 "$st_rc"
  st_rc=0; ( unset TEAM_PERF_PINNED_CONTAINER; perf_pinned_signal_rc ) || st_rc=$?
  st "身份信号：缺失 → 拒绝" 1 "$st_rc"
  st_rc=0; ( TEAM_PERF_PINNED_CONTAINER=0; perf_pinned_signal_rc ) || st_rc=$?
  st "身份信号：=0（被改）→ 拒绝" 1 "$st_rc"
  # ② 标识文件本体（函数级，夹具文件）：逐字节相等才算数 —— 缺尾换行/多加内容都是「不符」。
  local idf="$PERF_TMP/identity-token"
  printf '%s\n' "$PERF_IMAGE_IDENTITY_TOKEN" > "$idf"
  st_rc=0; perf_image_identity_rc "$idf" || st_rc=$?
  st "标识文件：内容逐字节等于 token → 通过" 0 "$st_rc"
  st_rc=0; perf_image_identity_rc "$PERF_TMP/identity-absent" || st_rc=$?
  st "标识文件：缺失 → 拒绝（缺失）" 1 "$st_rc"
  printf 'teamsmith-gate:999\n' > "$idf"
  st_rc=0; perf_image_identity_rc "$idf" || st_rc=$?
  st "标识文件：token 被改 → 拒绝（不符）" 2 "$st_rc"
  printf '%s' "$PERF_IMAGE_IDENTITY_TOKEN" > "$idf"
  st_rc=0; perf_image_identity_rc "$idf" || st_rc=$?
  st "标识文件：缺尾换行（非逐字节相等）→ 拒绝（不符）" 2 "$st_rc"
  # ③ 挂载点判定（M73 · M64 F2 第三轮）：挂载来的正确 token 也是伪造。夹具 mounts 表：
  local mtf="$PERF_TMP/mounts-fixture"
  : > "$mtf"
  st_rc=0; perf_image_identity_mounted_rc "$mtf" || st_rc=$?
  st "挂载判定：空 mounts 表 → 不算挂载" 1 "$st_rc"
  { printf '%s\n' 'proc /proc proc rw,nosuid,nodev,noexec,relatime 0 0'
    printf '%s\n' 'overlay / overlay rw,lowerdir=/l/1,upperdir=/l/2,workdir=/l/3 0 0'
    printf '%s\n' '/dev/sda1 /work ext4 rw,relatime 0 0'
    printf '%s\n' 'tmpfs /etc/resolv.conf tmpfs rw 0 0'; } > "$mtf"
  st_rc=0; perf_image_identity_mounted_rc "$mtf" || st_rc=$?
  st "挂载判定：真镜像形状（overlayfs / + /work + resolv.conf，无标识文件条目）→ 不算挂载" 1 "$st_rc"
  printf '%s\n' '/dev/sda1 /etc/teamsmith-gate-image ext4 ro,relatime 0 0' >> "$mtf"
  st_rc=0; perf_image_identity_mounted_rc "$mtf" || st_rc=$?
  st "挂载判定：标识文件是挂载目标（伪造形状）→ 判挂载" 0 "$st_rc"
  printf '%s\n' '/dev/sda1 /etc/teamsmith-gate-image\040bak ext4 ro 0 0' > "$mtf"
  st_rc=0; perf_image_identity_mounted_rc "$mtf" || st_rc=$?
  st "挂载判定：转义路径（\\040 解开后是别的文件）→ 不误判" 1 "$st_rc"
  st_rc=0; perf_image_identity_mounted_rc "$PERF_TMP/mounts-absent" || st_rc=$?
  st "挂载判定：mounts 表读不到 → 这一条判不了，不据此拒绝" 1 "$st_rc"
  local wir_rc wir_log="$PERF_TMP/m66-wiring.log"
  wir_rc=0
  timeout 10 env -u TEAM_PERF_PINNED_CONTAINER -u TEAM_PERF_LOCK_WRAPPED -u TEAM_PERF_NO_LOCK \
    bash "$self" --in-container >"$wir_log" 2>&1 || wir_rc=$?
  st "入口接线：缺信号 → 真 CLI 可见拒绝 exit 3" 3 "$wir_rc"
  if [ "$wir_rc" = "3" ] && grep -q 'TEAM_PERF_PINNED_CONTAINER' "$wir_log" && grep -q -- '--host' "$wir_log"; then
    printf '  \033[32m✓\033[0m 自检 · 入口接线：拒绝点名身份信号与 --host 出路\n'
  else
    printf '  \033[31m✗\033[0m 自检 · 入口接线：拒绝信息没点名信号/--host（rc=%s）\n' "$wir_rc"
    SELFTEST_FAIL=$((SELFTEST_FAIL + 1))
  fi
  wir_rc=0
  timeout 10 env -u TEAM_PERF_LOCK_WRAPPED -u TEAM_PERF_NO_LOCK TEAM_PERF_PINNED_CONTAINER=0 \
    bash "$self" --in-container >"$wir_log" 2>&1 || wir_rc=$?
  st "入口接线：错信号（=0）→ 真 CLI 可见拒绝 exit 3" 3 "$wir_rc"
  # M69 接线：ENV 信号齐全但标识文件缺失/不符（= M64 F2 的宿主伪造形状）也必须瞬时拒绝。
  # 在真镜像里文件本就在 —— 换成钉「镜像里的文件逐字节等于 token」（镜像构建错了在这里红）。
  if [ ! -e "$PERF_IMAGE_IDENTITY_FILE" ]; then
    wir_rc=0
    timeout 10 env -u TEAM_PERF_LOCK_WRAPPED -u TEAM_PERF_NO_LOCK TEAM_PERF_PINNED_CONTAINER=1 \
      bash "$self" --in-container >"$wir_log" 2>&1 || wir_rc=$?
    st "入口接线：有 ENV 信号但缺标识文件（宿主伪造形状）→ 真 CLI 可见拒绝 exit 3" 3 "$wir_rc"
    if [ "$wir_rc" = "3" ] && grep -q 'teamsmith-gate-image' "$wir_log"; then
      printf '  \033[32m✓\033[0m 自检 · 入口接线：拒绝点名缺镜像标识文件\n'
    else
      printf '  \033[31m✗\033[0m 自检 · 入口接线：拒绝没点名标识文件（rc=%s）\n' "$wir_rc"
      SELFTEST_FAIL=$((SELFTEST_FAIL + 1))
    fi
  else
    st_rc=0; perf_image_identity_rc || st_rc=$?
    st "入口接线：本机即钉死镜像 —— 标识文件逐字节等于 token" 0 "$st_rc"
  fi
  # M73 接线：perf_require_pinned_container 真的会查挂载点 —— ①② 都齐但标识文件是挂载的也必须
  # 瞬时拒绝。测试里造不了真挂载（要特权），用函数覆盖造同一判定面（真挂载的端到端翻转 = podman
  # 实跑，见 M73 报告）；再放行形一条：①②③ 全齐 → rc=0（覆盖全在子壳里，不影响外层）。
  local m73_out
  m73_out="$( { perf_pinned_signal_rc() { return 0; }; perf_image_identity_rc() { return 0; };
               perf_image_identity_mounted_rc() { return 0; }; perf_require_pinned_container; } 2>&1 )"; wir_rc=$?
  st "入口接线：信号+内容齐但标识文件是挂载的（伪造形状）→ 可见拒绝 exit 3" 3 "$wir_rc"
  if [ "$wir_rc" = "3" ] && printf '%s' "$m73_out" | grep -q '挂载' && printf '%s' "$m73_out" | grep -q 'teamsmith-gate-image'; then
    printf '  \033[32m✓\033[0m 自检 · 入口接线：拒绝点名「标识文件是挂载的，不是镜像烘焙的」\n'
  else
    printf '  \033[31m✗\033[0m 自检 · 入口接线：挂载拒绝没点名挂载/标识文件（rc=%s）\n' "$wir_rc"
    SELFTEST_FAIL=$((SELFTEST_FAIL + 1))
  fi
  m73_out="$( { perf_pinned_signal_rc() { return 0; }; perf_image_identity_rc() { return 0; };
               perf_image_identity_mounted_rc() { return 1; }; perf_require_pinned_container; } 2>&1 )"; wir_rc=$?
  st "入口接线：信号+内容齐且不是挂载（真镜像形状）→ 放行 rc=0" 0 "$wir_rc"
  # 真路径：夹具开关关着时，三个注入旋钮都被忽略且打印，读数不变。
  if perf_fixture_on; then
    note "自检 · 真路径旋钮忽略：跳过（TEAM_PERF_FIXTURE=1 夹具模式开着，注入按设计生效）"
    return 0
  fi
  local real_load real_cores fake_load fake_cores fake_inj notices
  real_load="$(cut -d' ' -f1 /proc/loadavg 2>/dev/null || printf '?')"
  real_cores="$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || printf '0')"
  export TEAM_PERF_LOADAVG=9999 TEAM_PERF_CORES=1 TEAM_PERF_FRAME_DELAY_MS=99999
  fake_load="$(perf_load_reading 2>/dev/null)"; fake_cores="$(perf_cores 2>/dev/null)"; fake_inj="$(perf_inject_ms 2>/dev/null)"
  notices="$( { perf_load_reading >/dev/null; perf_cores >/dev/null; perf_inject_ms >/dev/null; } 2>&1 )"
  unset TEAM_PERF_LOADAVG TEAM_PERF_CORES TEAM_PERF_FRAME_DELAY_MS
  st "真路径：注入的 loadavg 被忽略（读到真值 ${real_load}）" "$real_load" "$fake_load"
  st "真路径：注入的核数被忽略（读到真值 ${real_cores}）" "$real_cores" "$fake_cores"
  st "真路径：注入的慢帧拆成 0" "0" "$fake_inj"
  if printf '%s' "$notices" | grep -q '忽略 TEAM_PERF_LOADAVG=9999' \
     && printf '%s' "$notices" | grep -q '忽略 TEAM_PERF_CORES=1' \
     && printf '%s' "$notices" | grep -q '忽略 TEAM_PERF_FRAME_DELAY_MS=99999'; then
    printf '  \033[32m✓\033[0m 自检 · 真路径：三个注入旋钮都被忽略并打印\n'
  else
    printf '  \033[31m✗\033[0m 自检 · 真路径：旋钮忽略没有打印出来\n'; SELFTEST_FAIL=$((SELFTEST_FAIL + 1))
  fi
}

# ── 汇总与退出码 ────────────────────────────────────────────────────────────────────────────
perf_summary() {
  local reds=0 skips=0
  hdr "判定汇总（perf suite）"
  printf '  %-26s | %-6s | %-10s | %s\n' "判定" "结论" "中位" "读数 / 前提"
  printf '  %s\n' "---------------------------+--------+------------+----------------------------------"
  printf '  %-26s | %-6s | %-10s | %s\n' "① 交互首帧 (< ${PERF_FRAME_BUDGET_MS}ms)" "$J_FIRST_VERDICT" "${J_FIRST_MEDIAN}ms" "$J_FIRST_READ ｜ $J_FIRST_PREMISE"
  printf '  %-26s | %-6s | %-10s | %s\n' "② 帧装配线 (≤ ${PERF_FRAME_BUDGET_MS}ms)" "$J_ASM_VERDICT" "${J_ASM_MEDIAN}ms" "$J_ASM_READ ｜ $J_ASM_PREMISE"
  printf '  %-26s | %-6s | %-10s | %s\n' "③ 稳态窗格 CPU (< ${PERF_CPU_MAX_PCT}%)" "$J_CPU_VERDICT" "${J_CPU_MEDIAN}%" "$J_CPU_READ ｜ $J_CPU_PREMISE"
  local v
  for v in "$J_FIRST_VERDICT" "$J_ASM_VERDICT" "$J_CPU_VERDICT"; do
    [ "$v" = "RED" ] && reds=$((reds + 1))
    [ "$v" = "SKIP" ] && skips=$((skips + 1))
  done
  printf '\n== 结果 ==  ✓ %d 绿  ✗ %d 红  SKIP %d 没结论（自检失败 %d）；参考环境：%s；面板夹具：%s\n' \
    "$((3 - reds - skips))" "$reds" "$skips" "$SELFTEST_FAIL" "$([ "$PERF_REFERENCE" = yes ] && printf '是' || printf '否')" "${PERF_PANEL_RESULT_LINE:-无}"
  if [ "$SELFTEST_FAIL" -gt 0 ]; then
    printf '\033[31mperf: 自检失败 %d 条 → exit 2（套件自己的判定坏了，不能给结论）\033[0m\n' "$SELFTEST_FAIL"
    return 2
  fi
  if [ "$reds" -gt 0 ]; then
    printf '\033[31mperf: %d 条红 → exit 2\033[0m\n' "$reds"
    return 2
  fi
  if [ "$skips" -gt 0 ]; then
    printf '\033[33mperf: 没有红，但有 %d 条可见 SKIP → exit 4（没结论；不是通过）\033[0m\n' "$skips"
    return 4
  fi
  printf '\033[32mperf: 三条判定全绿 → exit 0\033[0m\n'
  return 0
}

# ── 套件主体 ────────────────────────────────────────────────────────────────────────────────
perf_run_suite() { # <mode-label> <reference yes|no> [unavailable]
  local mode_label="$1" reference="$2"
  PERF_REFERENCE="$reference"
  UNAVAILABLE="${3:-0}"
  local js=""
  if ! command -v tmux >/dev/null 2>&1; then
    printf 'perf: 搭建失败 —— 面板判定要真 tmux 窗格，本机没有 tmux（exit 3）\n' >&2; return 3
  fi
  js="${TEAM_JS_BIN:-$(command -v node 2>/dev/null || command -v bun 2>/dev/null || true)}"
  if [ -z "$js" ]; then
    printf 'perf: 搭建失败 —— 没有 node/bun，面板跑不起来（exit 3）\n' >&2; return 3
  fi
  if [ ! -f "$panel_bundle" ]; then
    printf 'perf: 搭建失败 —— 树里没有面板 bundle（%s）（exit 3）\n' "$panel_bundle" >&2; return 3
  fi
  if [ ! -f "$panel_fixture" ]; then
    printf 'perf: 搭建失败 —— 缺面板夹具（%s）（exit 3）\n' "$panel_fixture" >&2; return 3
  fi
  perf_env_description "$mode_label" "$reference"
  perf_smoke_lock_probe
  if [ "$UNAVAILABLE" = "1" ]; then
    printf '\n\033[33m!!! 参考环境不可用，本次为宿主判定，结论不作为验收依据（exit 4）!!!\033[0m\n'
  fi
  if ! perf_setup_fixture; then
    printf 'perf: 搭建失败 —— 夹具仓库 init 没成功（见 %s）（exit 3）\n' "$PERF_TMP/init.log" >&2
    tail -3 "$PERF_TMP/init.log" 2>/dev/null | sed 's/^/    /'
    return 3
  fi
  perf_judge_assembly
  perf_judge_panel
  perf_self_tests
  perf_summary
}

# ── 入口 ────────────────────────────────────────────────────────────────────────────────────
rc=0
if [ "$MODE" = "host" ]; then
  perf_run_suite "host（--host：非参考环境）" no || rc=$?
elif [ "$IN_CONTAINER" = "1" ]; then
  # 显式声明 + 双重身份证明已验（入口在拿锁之前查过 ENV 信号与 rootfs 标识文件，缺失/不符早已
  # exit 3 并点名）——走到这里才算真的在钉死镜像里。仍**不**用 /.dockerenv、/run/.containerenv
  # 自动判断：distrobox 也是容器（/run/.containerenv 在开发宿主上就存在，PM 实测），那样会把开发
  # 容器误当参考镜像（实测过：宿主路径与宿主 tmux 混进了「参考环境」的自述里）。
  perf_run_suite "container（参考环境：钉死镜像）" yes || rc=$?
else
  # 默认（含 --container）：参考环境；引擎/镜像不可用时**可见降级**（A2）——宿主读数照打、
  # 结论全部记 SKIP、打印「参考环境不可用，本次为宿主判定，结论不作为验收依据」并 exit 4。
  if perf_detect_engine && perf_detect_image; then
    perf_run_in_container || rc=$?
  else
    if perf_detect_engine; then
      say "perf: 参考环境不可用 —— 引擎 $(perf_engine_label) 在，但镜像候选都不在（TEAM_PERF_IMAGE=${TEAM_PERF_IMAGE:-未设}）"
    else
      say "perf: 参考环境不可用 —— 没有解析到容器引擎（podman / docker / distrobox-host-exec）"
    fi
    perf_print_build_run
    perf_run_suite "host（参考环境不可用：降级运行）" no 1 || rc=$?
  fi
fi
exit "$rc"
