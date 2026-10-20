#!/usr/bin/env bash
# teamsmith · 性能**参考读数**（M58 · perf-suite-split；P316 按用户裁定改成「只参考、不阻塞」）
#
#   bash skills/teamsmith/tests/perf.sh                    # 默认：参考环境（钉死镜像）——同 --container
#   bash skills/teamsmith/tests/perf.sh --container        # 参考环境：ci/Containerfile 的钉死镜像
#   bash skills/teamsmith/tests/perf.sh --in-container     # 镜像内部用：必须带镜像自身的身份证明
#                                                          # （ENV 信号 + rootfs 标识文件 + 非挂载点）
#   bash skills/teamsmith/tests/perf.sh --host             # 宿主：明确标注「非参考环境」
#   bash skills/teamsmith/tests/perf.sh --tree DIR         # 测哪棵树（默认：本文件所在的 checkout）
#
# 用户裁定（2026-10-19，第二条）：「性能只能作为参考指标，不能作为阻塞」。本套件只**测量并打印**：
#   ① 交互首帧（三次独立 spawn 的中位，由 tests/panel-cpu.sh 量）
#   ② 帧装配线（夹具仓库里 5 次 `team monitor --print --no-activity` 的中位）
#   ③ 稳态窗格 CPU（同一个采样窗三等分的中位，由 tests/panel-cpu.sh 量）
# 以及 loadavg / 核数 / CPU 配额 / JS 运行时 / tmux / 被测版本。行首一律是「· 参考」；
# **没有阈值红线、没有负载前提、没有 SKIP 结论**：机器多忙都照打数字，数字多大都不改变退出码。
#
# 退出码：**0** 读数都打完了；**3** 搭建失败（缺 tmux / JS 运行时 / 面板 bundle）或 --in-container
#         的身份证明缺失/不符（M66→M69→M73：拒绝以参考环境自居）。没有 2/4。
#   · 参考环境 = `ci/Containerfile` 的钉死镜像；引擎/镜像不可用时照打宿主读数，只标注「非参考环境」。
#   · 锁：自己的 TEAM_PERF_LOCK（flock --close -w + holder），两次读数不重叠；运行期间互斥被破坏时
#     打一行「读数可能受并发影响」，**不改变退出码**（它不是对产品的判定）。
set -uo pipefail

# ── 读数参数（P316：这些数字只是采样方式，不是阈值）───────────────────────────────────────
PERF_SAMPLES=5

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$here/lib/tmp-root.sh"
# P287：门禁锁的伴生锁路径与「记录读哪一份」只在 scripts/lib/gate-lock.sh 里实现一次 ——
# 只读探活要按新位置读（互斥在伴生锁上，发布路径是兼容声明；旧写入者的记录仍在发布路径边上）
if [ -f "$here/../scripts/lib/gate-lock.sh" ]; then
  # shellcheck source=../scripts/lib/gate-lock.sh
  . "$here/../scripts/lib/gate-lock.sh"
fi
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

退出码：0 读数打完了（性能不参与绿红）｜ 3 搭建失败 / --in-container 身份证明拒绝。
旋钮：TEAM_PERF_IMAGE / TEAM_PERF_ENGINE / TEAM_PERF_LOCK / TEAM_PERF_LOCK_WAIT / TEAM_PANEL_CPU_SECS
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
panel_cpu="$tree/skills/teamsmith/tests/panel-cpu.sh"

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
# P287（D4 裁定「性能套件那把锁一并」）：与正确性门禁**同一套锁机器** ——
#   ① 两把锁、顺序固定（发布路径 = 兼容声明 → 伴生锁 = 运行互斥；同行同目录、`.machine`、点开头）；
#      性能锁没有外部旧写入者，但同一套纪律买的是同一件事：别人的清理命令够不着互斥。
#   ② 取锁的进程自己握 fd，套件跑在它的**子进程**里、两个锁 fd 关掉（`8>&- 9>&-`）——
#      M23 的漏锁教训在这里同样是构造性关掉的；收尾只删**自己的记录**，锁文件永不 unlink。
#   ③ 记录写在伴生锁边上（`<companion>.holder`），带 `lock_identity=fd|path` 与 `lock_dev_ino`。
#   ④ 运行期间互斥被破坏（伴生锁被删/被换）⇒ 只打印一行「读数可能受并发影响」（P316：不判红）。
perf_lock_companion() { printf '%s\n' "$(gate_lock_companion_path "${1:-${TEAM_PERF_LOCK:-$(team_tmp_root)/teamsmith-perf.lock}}")"; }
perf_lock_or_continue() {
  [ "${PERF_LOCK_TAKEN:-0}" = "1" ] && return 0     # 子进程（真正跑套件的那个）：锁由父进程取到了
  # 容器里的那一层由**宿主这一层**持锁（引擎是 P0 的子进程，锁 fd 已被 8>&- 9>&- 关掉）：
  # 不再取锁、也不认领（认领判据在宿主那层已经判过）。
  [ "${TEAM_PERF_LOCK_HELD_BY_RUNNER:-0}" = "1" ] && { note "性能锁由调用方（宿主运行）持有 → 容器内不再取锁"; return 0; }
  [ "${TEAM_PERF_NO_LOCK:-0}" = "1" ] && { note "TEAM_PERF_NO_LOCK=1 → 不与别的性能运行串行（自担并发干扰）"; return 0; }
  if ! command -v flock >/dev/null 2>&1; then
    note "本机没有 flock → 不与别的性能运行串行（自担并发干扰）"
    return 0
  fi
  local lock="${TEAM_PERF_LOCK:-$(team_tmp_root)/teamsmith-perf.lock}" wait_s="${TEAM_PERF_LOCK_WAIT:-1800}"
  case "$wait_s" in ''|*[!0-9]*) wait_s=1800 ;; esac
  local comp; comp="$(perf_lock_companion "$lock")"
  mkdir -p "$(dirname "$lock")" 2>/dev/null || true
  : >>"$lock" 2>/dev/null || { note "锁文件 $lock 建不了 → 不串行"; return 0; }
  # 有界轮询取两把锁（每轮重算上限：持有者公布的 expected 优先，缺则 wait_s）——
  # 上限到点留下可读的一句（性能套件的退出码是 0/2/3/4，拿不到锁 = 没结论 → exit 3）。
  local rc=0 t0 queued=0 cap wait_used=0
  t0="$(date +%s)"
  while :; do
    rc=0; gate_lock_acquire_pair "$lock" || rc=$?
    [ "$rc" = "0" ] && break
    if [ "$rc" = "2" ]; then
      note "锁文件 $lock 建不了 → 不串行"; return 0
    fi
    IFS=$'\t' read -r cap _ _ _ < <(gate_lock_cap_pair "$lock" "$wait_s")
    case "$cap" in ''|*[!0-9]*) cap="$wait_s" ;; esac
    if [ "$queued" = "0" ]; then
      queued=1
      say "另一个性能运行正在跑（$(gate_lock_describe_pair "$lock")）；本次排队，最多等 ${cap}s"
    fi
    wait_used=$(( $(date +%s) - t0 ))
    if [ "$wait_used" -ge "$cap" ]; then
      printf 'perf: 等待 %ss 仍拿不到性能锁（持有者：%s）—— 另一个性能运行还没结束；不并发测量（exit 3）\n' \
        "$wait_used" "$(gate_lock_describe_pair "$lock")" >&2
      exit 3
    fi
    sleep 1
  done
  # 记录由**取锁的进程**（本 shell）写；两把锁的 mtime 刷一次（按 age 的清理器不该删活锁）
  touch "$lock" "$comp" 2>/dev/null || true
  local ident ino
  IFS=$'\t' read -r ident ino < <(gate_lock_claim_identity "$comp")
  gate_lock_write_holder "$comp" "$$" top "perf.sh" "perf" "$PWD" "$(date +%s)" - - - 0 - - "$ident" "$ino" || true
  export PERF_LOCK_TAKEN=1 PERF_LOCK_CLAIMER_PID="$$" PERF_LOCK_CLAIMER_IDENTITY="$ident" PERF_LOCK_CLAIMER_DEV_INO="$ino"
  export PERF_LOCK="$lock" PERF_LOCK_COMPANION="$comp"
  local rc2=0
  bash "$self" "${ORIG_ARGS[@]}" 8>&- 9>&- || rc2=$?
  # 收尾：只删自己的记录；两把锁文件都留着（unlink 一个还有等待者阻塞在它 inode 上的锁，正是要消灭的静默分裂）
  if gate_lock_holder_claimable "$comp" "$$"; then gate_lock_remove_holder "$comp"; fi
  rmdir "$comp.runs" 2>/dev/null || true
  exit "$rc2"
}
# 子进程认领：两条独立证据（记录里活着的是它 / 它的 /proc 里真有一个身份相符的锁描述符），
# 环境变量单独不作数；认领人还必须是**我的严格祖辈**（子套件那一层）。
perf_lock_claim_from_parent() {
  [ "${PERF_LOCK_TAKEN:-0}" = "1" ] || return 0
  [ -n "${PERF_LOCK_CLAIMER_PID:-}" ] || return 0
  PERF_LOCK="${PERF_LOCK:-${TEAM_PERF_LOCK:-$(team_tmp_root)/teamsmith-perf.lock}}"
  PERF_LOCK_COMPANION="$(perf_lock_companion "$PERF_LOCK")"
  local p q ok=0
  for q in $(gate_lock_ancestry_chain "$$"); do [ "$q" = "$PERF_LOCK_CLAIMER_PID" ] && ok=1 && break; done
  [ "$ok" = "1" ] || { printf 'perf: 锁认领人 pid=%s 不在我的进程链上 → 按未持锁处理\n' "$PERF_LOCK_CLAIMER_PID" >&2; PERF_LOCK_TAKEN=0; return 0; }
  if [ -s "$(gate_lock_holder_file "$PERF_LOCK_COMPANION")" ] \
     && [ "$(gate_lock_record_get "$(gate_lock_holder_file "$PERF_LOCK_COMPANION")" pid)" = "$PERF_LOCK_CLAIMER_PID" ] \
     && gate_lock_record_live "$(gate_lock_holder_file "$PERF_LOCK_COMPANION")"; then
    PERF_LOCK_DEV_INO="$(gate_lock_record_get "$(gate_lock_holder_file "$PERF_LOCK_COMPANION")" lock_dev_ino)"
    PERF_LOCK_IDENTITY="$(gate_lock_record_get "$(gate_lock_holder_file "$PERF_LOCK_COMPANION")" lock_identity)"
  elif [ -n "${PERF_LOCK_CLAIMER_DEV_INO:-}" ] \
       && gate_lock_pid_holds_path "$PERF_LOCK_CLAIMER_PID" "$PERF_LOCK_COMPANION" "$PERF_LOCK_CLAIMER_DEV_INO"; then
    PERF_LOCK_DEV_INO="$PERF_LOCK_CLAIMER_DEV_INO"; PERF_LOCK_IDENTITY="${PERF_LOCK_CLAIMER_IDENTITY:-fd}"
  else
    printf 'perf: 自述持锁（pid=%s）但记录与 /proc 都对不上 → 按未持锁处理（不并发测量）\n' "$PERF_LOCK_CLAIMER_PID" >&2
    PERF_LOCK_TAKEN=0
  fi
}
# 运行期间互斥被破坏 ⇒ 读数可能受并发影响（P316：只提示，不改变退出码）
perf_lock_identity_check() {
  [ "${PERF_LOCK_TAKEN:-0}" = "1" ] && [ -n "${PERF_LOCK_DEV_INO:-}" ] || return 0
  local r; r="$(gate_lock_snapshot "$PERF_LOCK_COMPANION" "${PERF_LOCK_IDENTITY:-fd}" "$PERF_LOCK_DEV_INO" "$PERF_LOCK_CLAIMER_PID")"
  case "$r" in
    ok|'') return 0 ;;
    *) printf '\n  · 参考 注意：运行期间性能锁的互斥被破坏（%s）—— 读数可能受并发影响（性能不参与绿红）\n' "$(printf '%s' "$r" | tr '\t' ' ')"
       return 0 ;;
  esac
}
if [ "${PERF_LOCK_TAKEN:-0}" = "1" ]; then perf_lock_claim_from_parent; fi
# --in-container 先验身份信号：缺了在这里就 exit 3，锁、临时目录、测量一样不沾。
if [ "$IN_CONTAINER" = "1" ]; then perf_require_pinned_container; fi
perf_lock_or_continue
if [ "${PERF_LOCK_TAKEN:-0}" = "1" ]; then
  printf '  · 性能锁：互斥在伴生锁 %s（发布路径 %s 是兼容声明；两把都永不 unlink）\n' \
    "$PERF_LOCK_COMPANION" "$PERF_LOCK"
fi

# 只读探活门禁锁：门禁在跑时性能读数会被它影响，打印持有者；**不排队等它**（性能锁独立）。
perf_smoke_lock_probe() {
  local lock="${TEAM_SMOKE_LOCK:-$(team_tmp_root)/teamsmith-smoke.lock}" comp probe busy=0
  comp="$lock"
  if declare -F gate_lock_companion_path >/dev/null 2>&1; then comp="$(gate_lock_companion_path "$lock")"; fi
  if ! command -v flock >/dev/null 2>&1; then return 0; fi
  # P287：互斥在**伴生锁**上（发布路径是兼容声明，P287 之前的写入者只认它）—— 两把都只读探一次，
  # 任一把被持有就算「门禁在跑」；记录按 pair 读（伴生锁边上优先，退回发布路径那条并标 version=legacy）。
  for probe in "$comp" "$lock"; do
    [ -e "$probe" ] || continue
    flock -n "$probe" true 2>/dev/null || { busy=1; break; }
  done
  [ "$busy" = "1" ] || return 0
  local who
  if declare -F gate_lock_describe_pair >/dev/null 2>&1; then
    who="$(gate_lock_describe_pair "$lock")"
  else
    who="$(cat "$lock.holder" 2>/dev/null || printf '持有者未知')"
  fi
  note "正确性门禁正在跑（$who）—— 本次性能读数可能受它影响（性能锁独立，不等它）"
}

# ── 机器读数（P316：只打印，不设前提、不判绿红）──────────────────────────────────────────
perf_load_reading() { cut -d' ' -f1 /proc/loadavg 2>/dev/null || printf '?'; }
perf_cores() { nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || printf '0'; }
perf_median() { printf '%s\n' "$@" | sort -n | awk '{a[NR] = $1} END {print a[int((NR + 1) / 2)]}'; }

# ── 判定（纯逻辑；真实路径与自检用**同一组**函数，所以自检不是另写一套）──────────────────────
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
  # 锁的身份**不**透传：容器那一层不取锁（宿主持有），只带一句「锁由调用方持有」。
  TEAM_PERF_LOCK_HELD_BY_RUNNER=1
  local k
  for k in TEAM_PANEL_CPU_SECS TEAM_PERF_LOCK_HELD_BY_RUNNER; do
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
PERF_TMP="$(tmp_root_create perf)" || { printf 'perf: 建不了临时根\n' >&2; exit 3; }
perf_cleanup() { tmp_root_reap_all; }
trap perf_cleanup EXIT

PERF_FIX=""
perf_setup_fixture() { # 夹具仓库（装配判定测的是面板装配，不是真项目的文档量）
  PERF_FIX="$PERF_TMP/repo"
  mkdir -p "$PERF_FIX"
  ( cd "$PERF_FIX" && git init -q -b main && git config user.email perf@teamsmith \
      && git config user.name perf && printf '# perf fixture\n' > README.md && git add -A && git commit -qm init ) >/dev/null 2>&1 || return 1
  mkdir -p "$PERF_FIX/openspec" "$PERF_FIX/.pi/team/state" "$PERF_FIX/docs/team/reports" "$PERF_FIX/docs/team/reviews"
  ( cd "$PERF_FIX" && perf_team_env_init bash "$team_bin" init --session "teamsmith-perf-$$" \
      --agents "dev verify" --vcs local --gates "true" --docs docs/team --task-models 'routine=deepseek/deepseek-flash analysis=xai/grok-4.6 verify=kimi-coding/k3-256k' --pm-model 'deepseek/deepseek-flash' ) >"$PERF_TMP/init.log" 2>&1 || return 1
  printf '2026-01-01T00:00:01Z RAM 可用 4000MB ｜ 磁盘 swap 空闲 3000MB ｜ 估算可再加 5 个 agent\n' \
    > "$PERF_FIX/.pi/team/state/capacity.log"
  return 0
}
# 夹具仓库里的 team 调用：清掉继承的团队身份与所有夹具旋钮（身份隔离，M7.2 纪律）。
perf_team_env_init() { env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
  -u TEAM_STATE_DIR -u TEAM_JS_BIN -u TEAM_REQUIRE_JS -u TEAM_MONITOR_ACTIVITY -u TEAM_MONITOR_UI \
  -u TEAM_AGENT_LOG_GLOB -u TEAM_SMOKE_FIXTURE -u TEAM_PANEL_CPU_LOADAVG \
  -u TEAM_PANEL_CPU_CORES "$@"; }   # P316：前提/帧时注入旋钮已随红线一起退役，名字一并清掉
perf_team() { ( cd "$PERF_FIX" && perf_team_env_init bash "$team_bin" "$@" ); }

perf_measure_assembly() { # → PERF_OBS 数组 + PERF_ASM_MEDIAN
  local t0 i
  PERF_OBS=()
  for ((i = 1; i <= PERF_SAMPLES; i++)); do
    t0="$(date +%s%3N)"
    perf_team monitor --print --no-activity >/dev/null 2>&1
    PERF_OBS+=("$(( $(date +%s%3N) - t0 ))")
  done
  PERF_ASM_MEDIAN="$(perf_median "${PERF_OBS[@]}")"
}

# ── 汇总状态 ────────────────────────────────────────────────────────────────────────────────
J_FIRST_MEDIAN="?"; J_FIRST_READ=""
J_ASM_MEDIAN="?";   J_ASM_READ=""
J_CPU_MEDIAN="?";   J_CPU_READ=""
UNAVAILABLE=0

# ── 环境自述────────────────────────────────────────────────────────────────────
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
  say "  读数用途       : · 参考（性能不参与绿红；没有阈值，也不因负载跳过）"
}

# ── 读数 ②：帧装配线（只打印）─────────────────────────────────────────────────────────────
perf_report_assembly() {
  perf_measure_assembly
  J_ASM_READ="$(printf '%s, ' "${PERF_OBS[@]}")"; J_ASM_READ="${J_ASM_READ%, }"
  J_ASM_MEDIAN="$PERF_ASM_MEDIAN"
  if [ "$UNAVAILABLE" = "1" ]; then
    say "  · 参考 帧装配线：宿主 ${PERF_SAMPLES} 次采样 $J_ASM_READ → 中位 ${J_ASM_MEDIAN}ms（非参考环境）"
  else
    say "  · 参考 帧装配线：${PERF_SAMPLES} 次采样 $J_ASM_READ → 中位 ${J_ASM_MEDIAN}ms（不比阈值）"
  fi
}

# ── 读数 ①③：交互首帧 + 稳态窗格 CPU（由 tests/panel-cpu.sh 量；它只打印参考行）──────────
perf_report_panel() {
  local out="$PERF_TMP/panel-cpu.log" rc=0
  if [ ! -f "$panel_cpu" ]; then
    say "  · 参考 面板读数：没测到（缺 $panel_cpu）"
    return 0
  fi
  TEAM_PANEL_CPU_SECS="${TEAM_PANEL_CPU_SECS:-6}" bash "$panel_cpu" >"$out" 2>&1 || rc=$?
  # P316 · V61 D1：此前单引号里又双写了反斜杠（模式永远匹配不到 → 汇总表打 `?ms`/`无读数`），
  # 且中位值里已经带着单位、表格又补了一次（`4065msms`）。这里只取数字，单位由表格那一列给。
  J_FIRST_MEDIAN="$(sed -n 's/^.*· 参考 首帧：\([0-9][0-9.]*\)ms（3 次独立 spawn.*$/\1/p' "$out" | tail -1)"
  J_CPU_MEDIAN="$(sed -n 's/^.*窗格 CPU：\([0-9][0-9.]*\)%（三等分中位）.*$/\1/p' "$out" | tail -1)"
  # 说明列不再从上面那一行里二次解析：cut -d 只收单字节分隔符（多字节「｜」直接报错），而 C locale
  # 下 sed 的 `.*`/`[^x]` 跨多字节回溯会静默失败（V61 D1 的同一类坑，本地实测三种写法都空）。
  # 逐次读数与三等分已经原样打印在表上方，这里只写它们是什么。
  J_FIRST_READ="3 次独立 spawn 的中位（上面逐次读数）"
  J_CPU_READ="三等分中位（上面三等分读数）"
  if [ "$rc" != "0" ]; then
    say "  · 参考 面板读数：没测到（panel-cpu rc=$rc）；尾部：$(tail -1 "$out" | sed 's/^ *//')"
    return 0
  fi
  sed 's/\\x1b\\[[0-9;]*m//g' "$out" | grep -a '· 参考' | sed 's/^ *//; s/^/  /'
}

# ── 参考读数汇总（没有判定，没有退出码）─────────────────────────────────────────────────────
perf_report() {
  hdr "参考读数汇总（perf suite）"
  printf '  读数                     | 中位         | 样本 / 说明\n'
  printf '  -------------------------+--------------+--------------------------------\n'
  printf '  ① 交互首帧               | %-12s | %s\n' "${J_FIRST_MEDIAN:+${J_FIRST_MEDIAN}ms}" "${J_FIRST_READ:-没测到}"
  printf '  ② 帧装配线               | %-12s | %s\n' "${J_ASM_MEDIAN:+${J_ASM_MEDIAN}ms}" "${J_ASM_READ:-没测到}"
  printf '  ③ 稳态窗格 CPU           | %-12s | %s\n' "${J_CPU_MEDIAN:+${J_CPU_MEDIAN}%}" "${J_CPU_READ:-没测到}"
  local ref="否（非参考环境）"
  [ "${PERF_REFERENCE:-no}" = yes ] && ref="是（钉死镜像）"
  printf '\n== 结果 ==  · 参考（性能不参与绿红；参考环境：%s）；没有红/绿/SKIP 结论\n' "$ref"
  return 0
}

# ── 套件主体 ────────────────────────────────────────────────────────────────────────────────
perf_run_suite() { # <mode-label> <reference yes|no> [unavailable]
  local mode_label="$1" reference="$2"
  PERF_REFERENCE="$reference"
  UNAVAILABLE="${3:-0}"
  local js=""
  if ! command -v tmux >/dev/null 2>&1; then
    printf 'perf: 搭建失败 —— 面板读数要真 tmux 窗格，本机没有 tmux（exit 3）\n' >&2; return 3
  fi
  js="${TEAM_JS_BIN:-$(command -v node 2>/dev/null || command -v bun 2>/dev/null || true)}"
  if [ -z "$js" ]; then
    printf 'perf: 搭建失败 —— 没有 node/bun，面板跑不起来（exit 3）\n' >&2; return 3
  fi
  if [ ! -f "$panel_bundle" ]; then
    printf 'perf: 搭建失败 —— 树里没有面板 bundle（%s）（exit 3）\n' "$panel_bundle" >&2; return 3
  fi
  if [ ! -f "$panel_cpu" ]; then
    printf 'perf: 搭建失败 —— 缺面板读数夹具（%s）（exit 3）\n' "$panel_cpu" >&2; return 3
  fi
  perf_env_description "$mode_label" "$reference"
  perf_smoke_lock_probe
  if [ "$UNAVAILABLE" = "1" ]; then
    printf '\n  · 参考 注意：参考环境不可用，本次是宿主读数（只作参考，不是验收依据）\n'
  fi
  if ! perf_setup_fixture; then
    printf 'perf: 搭建失败 —— 夹具仓库 init 没成功（见 %s）（exit 3）\n' "$PERF_TMP/init.log" >&2
    tail -3 "$PERF_TMP/init.log" 2>/dev/null | sed 's/^/    /'
    return 3
  fi
  perf_report_assembly
  perf_report_panel
  perf_lock_identity_check || true
  perf_report
  return 0
}

# ── 入口 ────────────────────────────────────────────────────────────────────────────────────
rc=0
if [ "$MODE" = "host" ]; then
  perf_run_suite "host（--host：非参考环境）" no || rc=$?
elif [ "$IN_CONTAINER" = "1" ]; then
  # 身份证明已验（入口在拿锁之前查过 ENV 信号与 rootfs 标识文件，缺失/不符早已 exit 3 并点名）。
  perf_run_suite "container（参考环境：钉死镜像）" yes || rc=$?
else
  # 默认（含 --container）：参考环境；引擎/镜像不可用时照打宿主读数，只标注「非参考环境」。
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
