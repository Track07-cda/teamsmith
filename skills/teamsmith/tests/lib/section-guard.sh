#!/usr/bin/env bash
# section-guard.sh — 门禁的**每段自述 + 硬预算 + 现场**（change: gate-section-accounting · 实现：P70）
#
# 被 `tests/smoke.sh` source（也支持 `bash tests/lib/section-guard.sh --self-test` 自检）。
# 契约见 `openspec/changes/gate-section-accounting/specs/verification/spec.md`：
#   * 每段开跑前打印 `== #<N> <id> == <ISO-8601> · 预算 <B>s`；结束时打印**唯一**的收口行
#     `#<N> <id> · 用时 <S>s · <✓/✗/SKIP 增量> · ticks <T>`（stdout 与 sections.log 逐字节一致；
#     增量由 P98 账本经 SG_CLOSE_COUNTS 注入，没有账本时是 `-`）；
#     每段一行进 `<run tmp>/sections.tsv`（`no id start elapsed_s ticks`）。
#   * 每段有一个来自 `tests/section-budgets.tsv` 的硬预算（表里没有 → 有界默认值，并在开跑行里说明）；
#     第一段超预算 → **停跑**：看门狗打印一行点名该段（`#<N>` + id + 预算 + 实际用时）、写现场、
#     然后才发信号；套件在自己的安全点看到 trip 标记 → exit 2。
#   * 看门狗是**双重 fork**（不进作业表：裸 `wait` 不会被它卡住），只对进程树里的子孙发信号，
#     **绝不** `kill -- -$pgid`（门禁的进程组里有 team review / CI / 启动它的席位）。
#   * 超预算 = **存活检测**，不是性能判定：段内只要在预算内跑完，机器再慢也绿（D33 保持）。
#   * 夹具旋钮只在 `TEAM_SMOKE_FIXTURE=1` 下生效，否则**打印忽略行**（环境不能悄悄拆掉边界）。
#
# 现场（trip 时）：`${TMPDIR:-/tmp}/.teamsmith-smoke-scene.<pid>/`，点开头、在 run 自己的临时根**之外**
# —— 套件的清理（含失败时删根）带不走它，CI 的 `docker cp <容器>:/tmp/.` 原样收走（D39 通道不动）。

SG_SECTION_GUARD_LIB=1

# P287：ns（临时根名字里的项目命名空间）的唯一实现在 scripts/lib/common.sh —— 本库被 smoke 前导段
# source（tmp-root.sh 已经带进来了），独立跑 --self-test 时自己补一次。
# P309：库位置可以显式给（`TEAM_SG_SKILL_DIR`）—— 自检的**变异副本**被复制到临时根下运行，它自己
# 数不出 skill 树在哪；不显式给就会找不到解析器，红侧因此「红错原因」。给了之后仍然只有一处解析实现。
if ! declare -F team_project_ns >/dev/null 2>&1; then
  _sg_ns_lib="${TEAM_SG_SKILL_DIR:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)}/scripts/lib/common.sh"
  [ -f "$_sg_ns_lib" ] && . "$_sg_ns_lib"
  unset _sg_ns_lib
fi
if ! declare -F team_tmp_root >/dev/null 2>&1; then
  printf 'section-guard: 缺少解析器 team_tmp_root（scripts/lib/common.sh 没被 source 进来，可给 TEAM_SG_SKILL_DIR）\n' >&2
fi

# ---------------------------------------------------------------- 状态（全部有默认值：smoke 是 set -u）
SG_ENABLED=0
SG_ARMED=0
SG_TRIPPED=0
SG_SEC_NO=0
SG_SEC_ID=""
SG_SEC_START=""
SG_BUDGET=""
SG_BAND=""
SG_BUDGET_SOURCE=""
SG_ARMED_EPOCH=0
SG_ARMED_SECONDS=0
SG_TICKS=0
SG_ELAPSED=0
SG_OWNER_PID="$$"
SG_OWNER_START=""
SG_BASE="$(team_tmp_root)"
SG_RUN_TMP=""
SG_BUDGETS=""
SG_TIMING=""
SG_LOG=""
SG_HEARTBEAT=""
SG_MARKER=""
SG_SCENE=""
SG_STOP=""
SG_ACK=""
SG_WATCHDOG_PIDFILE=""
SG_POLL=1
SG_DESC_GRACE=6
SG_SUITE_GRACE=2
SG_PROGRESS_INTERVAL=60
SG_DEFAULT_BUDGET=900
SG_FIXTURE="${TEAM_SMOKE_FIXTURE:-0}"
SG_STUCK_SECTION=""
SG_BUDGET_OVERRIDE=""
SG_FAST="${TEAM_SMOKE_FAST:-0}"
SG_LOCK_NOTE=""
SG_CLOSE_COUNTS=""   # P98 账本：本段收口行里的 ✓/✗/SKIP 增量（关段前注入；空 → 行里打 `-`）
SG_NESTED=0          # P281：本 run 是不是**证明得了祖辈持锁**的嵌套运行（只有嵌套运行才对齐祖辈期限）
SG_ANCESTOR_HEARTBEAT=""   # P281：祖辈公布的心跳文件（读它拿到 armed_epoch + budget）

_sg_now() { date +%s; }

# P281：心跳文件的路径**只在这里拼一次**（门禁锁的记录要公布它，嵌套运行要靠它找祖辈的武装段）
section_guard_heartbeat_path() { # [<owner pid>] → <TMPDIR>/.teamsmith-smoke-heartbeat.<pid>
  printf '%s\n' "$(team_tmp_root)/.teamsmith-smoke-heartbeat.${1:-$$}"
}

# P281：祖辈当前武装段的到期时刻（armed_epoch + budget）；读不到/未武装 → 空
_sg_ancestor_deadline() {
  local hb="${SG_ANCESTOR_HEARTBEAT:-}" line no armed budget
  [ -n "$hb" ] && [ -r "$hb" ] || return 1
  line="$(head -1 "$hb" 2>/dev/null || true)"
  case "$line" in ''|disarm*) return 1 ;; esac
  IFS='|' read -r no armed budget _ _ _ <<<"$line"
  case "${armed:-}" in ''|*[!0-9]*) return 1 ;; esac
  case "${budget:-}" in ''|*[!0-9]*) return 1 ;; esac
  printf '%s\n' "$(( armed + budget ))"
}

_sg_proc_start() { # /proc/<pid>/stat 的 starttime：pid 复用安全的判据
  local st; st="$(LC_ALL=C cat "/proc/$1/stat" 2>/dev/null)" || return 1
  st="${st##*\) }"; set -- $st
  [ -n "${20:-}" ] || return 1
  printf '%s\n' "${20}"
}

_sg_pid_alive() { # <pid> [<starttime>] → 0 活着且（给了 starttime 时）还是那个进程
  local pid="${1:-}" want="${2:-}" st
  case "$pid" in ''|*[!0-9]*) return 1 ;; esac
  [ "$pid" -gt 1 ] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  if [ -n "$want" ]; then
    st="$(_sg_proc_start "$pid" 2>/dev/null || true)"
    [ "$st" = "$want" ] || return 1
  fi
  return 0
}

# P281：僵尸（Z）已经跑完了（只等被 wait 收尸）—— 收尾等待时不能把它当「还活着」（否则白等满宽限）
_sg_pid_running() { # <pid> → 0 = 存在且不是僵尸
  local pid="${1:-}" st
  case "$pid" in ''|*[!0-9]*) return 1 ;; esac
  st="$(awk '{print $3}' "/proc/$pid/stat" 2>/dev/null || true)"
  [ -n "$st" ] && [ "$st" != "Z" ]
}

# ---------------------------------------------------------------- 初始化
# section_guard_init <run tmp> [--poll <s>] [--progress <s>] [--suite-grace <s>]
#                              [--desc-grace <n>] [--default-budget <s>] [--budgets <file>]
section_guard_init() {
  SG_RUN_TMP="${1:-}"; shift || true
  while [ $# -gt 0 ]; do
    case "$1" in
      --poll)            SG_POLL="${2:-1}"; shift 2 ;;
      --progress)        SG_PROGRESS_INTERVAL="${2:-60}"; shift 2 ;;
      --suite-grace)     SG_SUITE_GRACE="${2:-2}"; shift 2 ;;
      --desc-grace)      SG_DESC_GRACE="${2:-6}"; shift 2 ;;
      --default-budget)  SG_DEFAULT_BUDGET="${2:-900}"; shift 2 ;;
      --budgets)         SG_BUDGETS="${2:-}"; shift 2 ;;
      *) printf 'section-guard: 不认识的参数 %s\n' "$1" >&2; return 2 ;;
    esac
  done
  SG_BASE="$(team_tmp_root)"
  SG_FIXTURE="${TEAM_SMOKE_FIXTURE:-0}"
  SG_OWNER_PID="${BASHPID:-$$}"
  SG_OWNER_START="$(_sg_proc_start "$SG_OWNER_PID" 2>/dev/null || true)"
  SG_HEARTBEAT="$(section_guard_heartbeat_path "$SG_OWNER_PID")"
  SG_MARKER="$SG_BASE/.teamsmith-smoke-trip.$SG_OWNER_PID"
  SG_SCENE="$SG_BASE/.teamsmith-smoke-scene.$SG_OWNER_PID"
  SG_STOP="$SG_BASE/.teamsmith-smoke-guard-stop.$SG_OWNER_PID"
  SG_ACK="$SG_BASE/.teamsmith-smoke-guard-ack.$SG_OWNER_PID"
  SG_WATCHDOG_PIDFILE="$SG_BASE/.teamsmith-smoke-guard.pid.$SG_OWNER_PID"
  SG_TIMING="$SG_RUN_TMP/sections.tsv"
  SG_LOG="$SG_RUN_TMP/sections.log"
  [ -n "$SG_BUDGETS" ] || SG_BUDGETS="${SG_SKILL_DIR:-}/tests/section-budgets.tsv"
  _sg_parse_knobs
  if [ ! -s "$SG_TIMING" ]; then
    printf 'no\tid\tstart\telapsed_s\tticks\n' > "$SG_TIMING" 2>/dev/null || true
  fi
  : > "$SG_LOG" 2>/dev/null || true
  return 0
}

_sg_knob_note() { # <name> <value>：非夹具路径下的忽略行（旋钮不许从环境拆掉边界）
  printf '  \033[2m·\033[0m 注意：%s=%s 只给夹具路径用；非夹具路径忽略它\n' "$1" "$2"
}

_sg_parse_knobs() {
  local k v
  SG_STUCK_SECTION=""
  SG_BUDGET_OVERRIDE=""
  SG_POLL="${SG_POLL:-1}"
  SG_PROGRESS_INTERVAL="${SG_PROGRESS_INTERVAL:-60}"
  if [ "${SG_FIXTURE:-0}" = "1" ]; then
    SG_STUCK_SECTION="${TEAM_SMOKE_STUCK_SECTION:-}"
    SG_BUDGET_OVERRIDE="${TEAM_SMOKE_SECTION_BUDGET:-}"
    [ -n "${TEAM_SMOKE_PROGRESS_INTERVAL:-}" ] && SG_PROGRESS_INTERVAL="$TEAM_SMOKE_PROGRESS_INTERVAL"
    [ -n "${TEAM_SMOKE_GUARD_POLL:-}" ] && SG_POLL="$TEAM_SMOKE_GUARD_POLL"
    return 0
  fi
  for k in TEAM_SMOKE_STUCK_SECTION TEAM_SMOKE_SECTION_BUDGET TEAM_SMOKE_PROGRESS_INTERVAL TEAM_SMOKE_GUARD_POLL SMOKE_PROGRESS_INTERVAL; do
    case "$k" in
      TEAM_SMOKE_STUCK_SECTION)     v="${TEAM_SMOKE_STUCK_SECTION:-}" ;;
      TEAM_SMOKE_SECTION_BUDGET)    v="${TEAM_SMOKE_SECTION_BUDGET:-}" ;;
      TEAM_SMOKE_PROGRESS_INTERVAL) v="${TEAM_SMOKE_PROGRESS_INTERVAL:-}" ;;
      TEAM_SMOKE_GUARD_POLL)        v="${TEAM_SMOKE_GUARD_POLL:-}" ;;
      SMOKE_PROGRESS_INTERVAL)      v="${SMOKE_PROGRESS_INTERVAL:-}" ;;
    esac
    [ -n "$v" ] && _sg_knob_note "$k" "$v"
  done
  SG_PROGRESS_INTERVAL=60
  SG_POLL=1
  return 0
}

# ---------------------------------------------------------------- 预算表
# section_guard_budget_for <id> → 设置 SG_BUDGET / SG_BAND / SG_BUDGET_SOURCE
section_guard_budget_for() {
  local id="$1" row=""
  if [ -n "$SG_BUDGETS" ] && [ -r "$SG_BUDGETS" ]; then
    row="$(awk -F'\t' -v id="$id" '
      /^[[:space:]]*#/ { next }
      $1 == id { print $2 "\t" $3; found = 1; exit }
      END { if (!found) exit 1 }
    ' "$SG_BUDGETS" 2>/dev/null || true)"
  fi
  # 行必须在、band 可以是 "-"（没测过），budget 必须是正整数
  case "$row" in
    *$'\t'*) SG_BAND="${row%%	*}"; SG_BUDGET="${row##*	}" ;;
    *)       SG_BAND=""; SG_BUDGET="" ;;
  esac
  case "${SG_BUDGET:-x}" in ''|*[!0-9]*) row="" ;; esac
  if [ -n "$row" ]; then
    SG_BUDGET_SOURCE="table"
  else
    SG_BAND=""
    SG_BUDGET="$SG_DEFAULT_BUDGET"
    SG_BUDGET_SOURCE="default"
  fi
  # 夹具的预算覆盖：只作用于被点名的 stuck 段；没点名就作用于每段（自检/夹具用）
  if [ "${SG_FIXTURE:-0}" = "1" ] && [ -n "$SG_BUDGET_OVERRIDE" ]; then
    case "${SG_BUDGET_OVERRIDE:-x}" in *[!0-9]*) ;; *)
      if [ -z "$SG_STUCK_SECTION" ] || _sg_id_matches "$SG_STUCK_SECTION" "$id"; then
        SG_BUDGET="$SG_BUDGET_OVERRIDE"
        SG_BUDGET_SOURCE="fixture"
      fi
      ;;
    esac
  fi
  return 0
}

_sg_id_matches() { # <knob> <id>：完整 id 或「前缀 + 空格」都算
  local knob="$1" id="$2"
  case "$id" in
    "$knob"|"$knob "*) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------- 心跳 / 安全点
section_guard_write_heartbeat() {
  [ "$SG_ENABLED" = "1" ] || return 0
  if [ -z "$SG_SEC_ID" ]; then
    printf 'disarm\n' > "$SG_HEARTBEAT" 2>/dev/null || true
    return 0
  fi
  SG_ELAPSED=$(( SECONDS - SG_ARMED_SECONDS ))
  printf '%s|%s|%s|%s|%s|%s\n' \
    "$SG_SEC_NO" "$SG_ARMED_EPOCH" "$SG_BUDGET" "$SG_ELAPSED" "$SG_TICKS" "$SG_SEC_ID" \
    > "$SG_HEARTBEAT" 2>/dev/null || true
  return 0
}

section_guard_progress_tick() {
  [ "$SG_ENABLED" = "1" ] || return 0
  [ "$SG_ARMED" = "1" ] || return 0
  SG_TICKS=$((SG_TICKS + 1))
  section_guard_write_heartbeat
  return 0
}

# 安全点：trip 标记在 → 停跑（看门狗已经打印过点名行；这里只退出，不重复点名）
_sg_check_trip() {
  [ "$SG_ENABLED" = "1" ] || return 0
  if [ -e "$SG_MARKER" ]; then
    SG_TRIPPED=1
    _sg_exit_trip
  fi
  return 0
}

# ok()/bad()/skip/等待轮都调用它：先看 trip，再把 ticks/elapsed 写回心跳（纯内建写入）
section_guard_check() {
  [ "$SG_ENABLED" = "1" ] || return 0
  _sg_check_trip
  [ "$SG_ARMED" = "1" ] || return 0
  section_guard_progress_tick
  return 0
}

_sg_exit_trip() {
  trap - TERM 2>/dev/null || true
  if [ "${BASHPID:-$$}" = "$$" ]; then
    # 主 shell：先收看门狗，别让它在 cleanup 之后继续打；EXIT trap 照常收临时根
    section_guard_stop_watchdog
  fi
  exit 2
}

section_guard_on_term() { # 看门狗对我们的 TERM：trip → exit 2；否则恢复默认动作重新自杀
  if [ -e "$SG_MARKER" ]; then
    _sg_exit_trip
  fi
  trap - TERM 2>/dev/null || true
  kill -TERM "${BASHPID:-$$}" 2>/dev/null || true
  exit 143
}

# ---------------------------------------------------------------- 段落开闭
_sg_start_line() {
  local src=""
  case "$SG_BUDGET_SOURCE" in
    default)  src="（默认：预算表没有这段）" ;;
    fixture)  src="（夹具覆盖）" ;;
    ancestor) src="（嵌套运行：对齐祖辈剩余预算）" ;;
    # 返修轮次 1 · F1：读不到祖辈公布的 heartbeat → 退回自己的表预算。退回必须**可见**，
    # 不许无声占着（V43 的 F1：旧实现只把环境变量当来源，环境一清就静默退回）。
    nested-fallback)         src="（嵌套运行：没有可读的祖辈心跳 → 按本段预算）" ;;
    fixture-nested-fallback) src="（夹具覆盖；嵌套运行：没有可读的祖辈心跳 → 按本段预算）" ;;
  esac
  printf '== #%s %s == %s · 预算 %ss%s' "$SG_SEC_NO" "$SG_SEC_ID" "$SG_SEC_START" "$SG_BUDGET" "$src"
}

# _sg_band_over <elapsed> <band> → 0 当且仅当 band 是数字且 elapsed 超过它（**记录**，不是判定）。
# band 是小数也必须比 —— 表的 110/112 行是 `0.02 … 44.00`（P108 F2：旧的 `case ''|*[!0-9]*`
# 整数守卫把带小数点的带全落进空分支，规范承诺的「超过实测带打一行警告」对它们永不可达）。
# 空 / `-` = 表里没有实测带 → 不比较；非数字（表坏了）由 `section-guard.sh --budget-check` 点名。
_sg_band_over() {
  local elapsed="$1" band="${2:-}"
  case "$band" in
    ''|-) return 1 ;;          # 没有实测带（表里写「-」）→ 不比较
    *[!0-9.]*) return 1 ;;     # 非数字（表坏了，由 --budget-check 点名）→ 不比较
  esac
  awk -v a="$elapsed" -v b="$band" 'BEGIN { exit !(a + 0 > b + 0) }'
}

_sg_close_current() {
  [ "$SG_ARMED" = "1" ] || return 0
  local elapsed now counts
  now="$(_sg_now)"; elapsed=$(( now - SG_ARMED_EPOCH ))
  [ "$elapsed" -lt 0 ] && elapsed=0
  SG_ELAPSED="$elapsed"   # P98 账本读回：收口行与 sections.tsv 用同一个数，不再各量一次
  counts="${SG_CLOSE_COUNTS:--}"; SG_CLOSE_COUNTS=""
  # 唯一收口行（gate-section-accounting × gate-runtime-budget 的合并形态）：P70 的用时/ticks 与
  # P98 账本的增量同形同一行。stdout 与 sections.log 逐字节一致；行不带门禁红标、不缩进。
  printf '\033[2m#%s\033[0m %s · 用时 %ss · %s · ticks %s\n' \
    "$SG_SEC_NO" "$SG_SEC_ID" "$elapsed" "$counts" "$SG_TICKS"
  printf '#%s %s · 用时 %ss · %s · ticks %s\n' \
    "$SG_SEC_NO" "$SG_SEC_ID" "$elapsed" "$counts" "$SG_TICKS" >> "$SG_LOG" 2>/dev/null || true
  printf '%s\t%s\t%s\t%s\t%s\n' "$SG_SEC_NO" "$SG_SEC_ID" "$SG_SEC_START" "$elapsed" "$SG_TICKS" >> "$SG_TIMING" 2>/dev/null || true
  if _sg_band_over "$elapsed" "${SG_BAND:-}"; then
    printf '  \033[33m⚠\033[0m #%s 用时 %ss，超过实测带 %ss（这是记录，不是判定）\n' \
      "$SG_SEC_NO" "$elapsed" "$SG_BAND"
  fi
  # P281：本段收口后，本夹具登记过的嵌套运行还不许活着（只对自己登记过的 pid 发信号，D37）
  section_guard_check_orphans "${SG_LOCK_NOTE:-}"
  SG_ARMED=0
  SG_SEC_ID=""
  printf 'disarm\n' > "$SG_HEARTBEAT" 2>/dev/null || true
  return 0
}

section_guard_close() { # 公共收口入口（P98 账本用）：调用方先给 SG_CLOSE_COUNTS 注入本段增量
  _sg_close_current
  SG_CLOSE_COUNTS=""   # 就算没武装（无收口行）也清掉：不让一次注入粘到下一段
  return 0
}

section_guard_begin() { # <id>：收上一段 → 开这一段（含夹具注入）
  local id="$1" line
  [ "$SG_ENABLED" = "1" ] || return 0
  _sg_check_trip
  [ "$SG_ARMED" = "1" ] && _sg_close_current
  SG_SEC_NO=$((SG_SEC_NO + 1))
  SG_SEC_ID="$id"
  SG_SEC_START="$(date -Is)"
  SG_ARMED_EPOCH="$(_sg_now)"
  SG_ARMED_SECONDS="$SECONDS"
  SG_TICKS=0
  section_guard_budget_for "$id"
  # P281：嵌套运行的期限 = min(自己的表预算, 祖辈武装段的剩余)。到点走**既有** trip 路径
  # （点名段号 + 预算 + 实际、写现场、停跑）——不许无声占着（EXP2 那次 1h16m 的形状）。
  if [ "${SG_NESTED:-0}" = "1" ]; then
    local adl rem
    adl="$(_sg_ancestor_deadline 2>/dev/null || true)"
    if [ -n "$adl" ]; then
      rem=$(( adl - $(_sg_now) ))
      [ "$rem" -lt 0 ] && rem=0
      if [ "$rem" -lt "$SG_BUDGET" ]; then SG_BUDGET="$rem"; SG_BUDGET_SOURCE="ancestor"; fi
    else
      # F1：祖辈心跳读不到 → 退回**自己的**表预算，但必须可见（开跑行的来源里说清楚）。
      case "${SG_BUDGET_SOURCE:-default}" in
        fixture) SG_BUDGET_SOURCE="fixture-nested-fallback" ;;
        *)       SG_BUDGET_SOURCE="nested-fallback" ;;
      esac
    fi
  fi
  SG_ARMED=1
  section_guard_write_heartbeat
  line="$(_sg_start_line)"
  printf '\n\033[1m%s\033[0m\n' "$line"
  printf '%s\n' "$line" >> "$SG_LOG" 2>/dev/null || true
  # 夹具注入：被点名的段落永不返回（预算到点必须点名 + 停跑 + 留现场）
  if [ "${SG_FIXTURE:-0}" = "1" ] && [ -n "$SG_STUCK_SECTION" ] && _sg_id_matches "$SG_STUCK_SECTION" "$id"; then
    printf '  \033[35m[fixture]\033[0m 注入永不返回的段落（%s，预算 %ss）\n' "$id" "$SG_BUDGET"
    local stuck_log="$SG_RUN_TMP/fixture-stuck-$SG_SEC_NO.log"
    printf 'fixture 注入：段落 #%s（%s）永不返回（预算 %ss）\n' "$SG_SEC_NO" "$id" "$SG_BUDGET" > "$stuck_log" 2>/dev/null || true
    # P313：这个「永不返回」是**夹具造的现场**，不是永不退出的进程。旧形状
    #   `bash -c 'trap "" TERM; while :; do date +%s >> $log; sleep 0.2; done'`
    # 在被打断的运行里会永久泄漏（现场：78 个孤儿合计持有 11.98 GB 已删除文件）。现在由
    # lib/bounded-spin.sh 一处实现三条边界：父进程没了就退、到点（段落预算 + 120s 宽限）就退
    # 并留一行、写目标被删就退。cap 永远大于段落预算 → 合法运行不会被它截断。
    # 它**响应** TERM（P313 的硬要求：看门/轮询进程不再 `trap "" TERM`）。因此段落 0f 的现场
    # 不会记 `escalation:` —— 段 0f 反过来断言「没有升级」，那条断言就是「有人把忽略 TERM 放回来」
    # 的守卫；「真要升级时现场照写」由自检的 F1 夹具（P110）负责。
    local _sg_spin_lib; _sg_spin_lib="$(_sg_spin_lib_path)"
    local _sg_spin_cap=$(( SG_BUDGET + 120 ))
    [ -f "$_sg_spin_lib" ] || printf '  \033[31m✗\033[0m 夹具：缺 %s（心跳循环起不来）\n' "$_sg_spin_lib"
    bash -c 'lib="$1"; shift; . "$lib"; bounded_spin "$@"' _ "$_sg_spin_lib" \
      0.2 "$_sg_spin_cap" "$(( _sg_spin_cap * 64 + 65536 ))" "$stuck_log" "$BASHPID" &
    local child=$!
    command -v tmp_root_track_pid >/dev/null 2>&1 && tmp_root_track_pid "$child" "section-guard-stuck" || true
    wait "$child" 2>/dev/null || true
    _sg_check_trip
    printf '  \033[35m[fixture]\033[0m 注入的段落返回了（trip 标记没出现？）\n'
  fi
  return 0
}

section_guard_finish() { # 结果行之前：收最后一段 + 关看门狗
  [ "$SG_ENABLED" = "1" ] || return 0
  [ "$SG_ARMED" = "1" ] && _sg_close_current
  section_guard_stop_watchdog
  SG_ENABLED=0
  return 0
}

# ---------------------------------------------------------------- 看门狗
section_guard_arm() {
  SG_ENABLED=1
  SG_ARMED=0
  SG_TRIPPED=0
  SG_SEC_NO=0
  printf 'disarm\n' > "$SG_HEARTBEAT" 2>/dev/null || true
  rm -f "$SG_MARKER" "$SG_STOP" "$SG_ACK" "$SG_WATCHDOG_PIDFILE" 2>/dev/null || true
  ( section_guard_watchdog & )
  # 起 TERM 陷阱：trip 的 TERM → exit 2；别的 TERM → 恢复默认动作（见 section_guard_on_term）
  trap 'section_guard_on_term' TERM
  local i=0
  for i in $(seq 1 50); do
    [ -s "$SG_WATCHDOG_PIDFILE" ] && break
    sleep 0.02
  done
  if [ ! -s "$SG_WATCHDOG_PIDFILE" ]; then
    printf '  \033[31m✗\033[0m section-guard：看门狗没起来（%s）—— 本套**没有**每段硬预算\n' "$SG_WATCHDOG_PIDFILE"
  fi
  return 0
}

section_guard_stop_watchdog() {
  : > "$SG_STOP" 2>/dev/null || true
  local i wpid wstart
  for i in $(seq 1 25); do [ -e "$SG_ACK" ] && break; sleep 0.02; done
  wpid="$(awk -F'\t' 'NR==1{print $1}' "$SG_WATCHDOG_PIDFILE" 2>/dev/null || true)"
  wstart="$(awk -F'\t' 'NR==1{print $2}' "$SG_WATCHDOG_PIDFILE" 2>/dev/null || true)"
  if [ ! -e "$SG_ACK" ] && [ -n "$wpid" ]; then
    # 没握手（比如看门狗卡在写现场）：按 pid + starttime 有界地收，绝不按名字/进程组
    _sg_pid_alive "$wpid" "${wstart:-}" && kill -TERM "$wpid" 2>/dev/null || true
    for i in $(seq 1 25); do
      _sg_pid_alive "$wpid" "${wstart:-}" || break
      sleep 0.02
    done
    _sg_pid_alive "$wpid" "${wstart:-}" && kill -KILL "$wpid" 2>/dev/null || true
  fi
  rm -f "$SG_STOP" "$SG_ACK" "$SG_WATCHDOG_PIDFILE" 2>/dev/null || true
  return 0
}

# 收尾（cleanup 里调用）：干净跑把哨兵的兄弟文件收掉；trip 过 → 现场留着（那是证据）
section_guard_sweep() {
  rm -f "$SG_STOP" "$SG_ACK" "$SG_WATCHDOG_PIDFILE" 2>/dev/null || true
  [ "$SG_TRIPPED" = "1" ] && return 0
  rm -f "$SG_HEARTBEAT" "$SG_MARKER" 2>/dev/null || true
  return 0
}

_sg_descendants() { # <pid> <exclude> → 叶子优先
  local pid="$1" exclude="$2" f c
  for f in /proc/"$pid"/task/*/children; do
    [ -r "$f" ] || continue
    for c in $(cat "$f" 2>/dev/null); do
      [ -n "$c" ] || continue
      [ "$c" = "$exclude" ] && continue
      _sg_descendants "$c" "$exclude"
      printf '%s\n' "$c"
    done
  done
}

section_guard_watchdog() {
  local me="$BASHPID"
  printf '%s\t%s\n' "$me" "$(_sg_proc_start "$me" 2>/dev/null || true)" > "$SG_WATCHDOG_PIDFILE" 2>/dev/null || true
  local line no armed budget elapsed ticks id now last_seen=0 last_progress=0
  while :; do
    [ -e "$SG_STOP" ] && break
    _sg_pid_alive "$SG_OWNER_PID" "$SG_OWNER_START" || break
    line="$(cat "$SG_HEARTBEAT" 2>/dev/null || true)"
    case "$line" in ''|disarm*) sleep "$SG_POLL"; continue ;; esac
    IFS='|' read -r no armed budget elapsed ticks id <<<"$line"
    case "${no:-x}${armed:-x}${budget:-x}" in *[!0-9]*) sleep "$SG_POLL"; continue ;; esac
    now="$(_sg_now)"
    case "${elapsed:-0}" in ''|*[!0-9]*) elapsed=0 ;; esac
    [ "${elapsed}" -gt "$last_seen" ] && last_seen="$elapsed"
    case "${SG_PROGRESS_INTERVAL:-60}" in ''|*[!0-9]*) SG_PROGRESS_INTERVAL=60 ;; esac
    if [ "$SG_PROGRESS_INTERVAL" -gt 0 ] \
       && [ "$(( now - armed ))" -ge "$SG_PROGRESS_INTERVAL" ] \
       && [ "$(( now - last_progress ))" -ge "$SG_PROGRESS_INTERVAL" ]; then
      _sg_progress_line "$no" "$id" "$(( now - armed ))" "$budget"
      last_progress=$now
    fi
    if [ "$(( now - armed ))" -ge "$budget" ]; then
      _sg_trip "$no" "$id" "$armed" "$budget" "$ticks" "$last_seen" "$now"
      break
    fi
    sleep "$SG_POLL"
  done
  rm -f "$SG_WATCHDOG_PIDFILE" 2>/dev/null || true
  : > "$SG_ACK" 2>/dev/null || true
  exit 0
}

_sg_progress_line() {
  local no="$1" id="$2" elapsed="$3" budget="$4" slow=""
  slow="$(awk -F'\t' 'NR > 1 && $4 ~ /^[0-9]+$/ { printf "%s\t#%s %s\n", $4, $1, $2 }' "$SG_TIMING" 2>/dev/null \
    | sort -rn 2>/dev/null | head -3 | cut -f2 | tr '\n' ' ' || true)"
  printf '  \033[2m… 段落 #%s（%s）已运行 %ss（预算 %ss）%s\033[0m\n' \
    "$no" "$id" "$elapsed" "$budget" "${slow:+；最慢：$slow}"
  printf '… 段落 #%s（%s）已运行 %ss（预算 %ss）%s\n' \
    "$no" "$id" "$elapsed" "$budget" "${slow:+；最慢：$slow}" >> "$SG_LOG" 2>/dev/null || true
  return 0
}

_sg_trip() { # <no> <id> <armed> <budget> <ticks> <last_seen> <now>
  local no="$1" id="$2" armed="$3" budget="$4" ticks="$5" last_seen="$6" now="$7"
  local elapsed="$(( now - armed ))" i=0
  printf '\n  \033[31m✗\033[0m 段落 #%s（%s）超时：预算 %ss，实际 %ss，最后进度 %ss → 停跑（exit 2），现场 %s\n' \
    "$no" "$id" "$budget" "$elapsed" "$last_seen" "$SG_SCENE"
  : > "$SG_MARKER" 2>/dev/null || true
  _sg_scene_write "$no" "$id" "$budget" "$elapsed" "$last_seen" "$ticks" "$armed"
  _sg_stop_children "$no"
  # 给套件一个**有界**的机会自己走到安全点退出（exit 2）；它不走才 TERM/KILL
  while [ "$i" -lt $(( SG_SUITE_GRACE * 5 )) ]; do
    _sg_pid_alive "$SG_OWNER_PID" "$SG_OWNER_START" || return 0
    sleep 0.2; i=$((i + 1))
  done
  kill -TERM "$SG_OWNER_PID" 2>/dev/null || true
  i=0
  while [ "$i" -lt 25 ]; do
    _sg_pid_alive "$SG_OWNER_PID" "$SG_OWNER_START" || return 0
    sleep 0.2; i=$((i + 1))
  done
  kill -KILL "$SG_OWNER_PID" 2>/dev/null || true
  return 0
}

_sg_stop_children() { # <no>：只停这个套件进程树里的子孙（不含看门狗），TERM → 有界宽限 → KILL
  local no="$1" p grace=0 _sg_p
  while :; do
    p="$(_sg_descendants "$SG_OWNER_PID" "$BASHPID" | tac)"
    [ -n "$p" ] || break
    [ "$grace" -ge "$SG_DESC_GRACE" ] && break
    # 信号只发给 _sg_descendants 从 /proc 里**读出来并记下的 pid**（P159：xargs 的 stdin 是选择，禁止）
    for _sg_p in $p; do kill -TERM "$_sg_p" 2>/dev/null || true; done
    sleep 0.2; grace=$((grace + 1))
  done
  if [ "$grace" -ge "$SG_DESC_GRACE" ]; then
    p="$(_sg_descendants "$SG_OWNER_PID" "$BASHPID" | tac)"
    if [ -n "$p" ]; then
      for _sg_p in $p; do kill -KILL "$_sg_p" 2>/dev/null || true; done
      # 只声明确实知道的：grace 用尽 + 已发 KILL。谁真的扛过了 TERM 是**现场判定**的事
      # （P108 F1：套件退出路径持续产出短命子进程时，「子孙忽略 TERM」是与现场矛盾的归因）。
      printf 'escalation: 段落 #%s 的 grace 用尽（仍有子孙存活）→ 已对它们发 KILL（归因以现场为准）\n' "$no" >> "$SG_SCENE/summary.txt" 2>/dev/null || true
      printf '  \033[31m✗\033[0m 看门狗：段落 #%s 的 grace 用尽（仍有子孙存活）→ 已发 KILL（归因以现场为准；现场 %s）\n' "$no" "$SG_SCENE"
    fi
  fi
  return 0
}

# P281（change: gate-lock-hygiene）：本夹具登记过的嵌套运行在**生它的那一段收口后**还不许活着。
# 只对记录里 `ancestor=<本 run 的 pid>` 且 pid 仍活着的条目动手；只对**那个 pid** 发信号（D37：
# 不按名字、不按进程组）。没有锁路径 / 没有 gate-lock.sh / 没有记录 → 静默不动。
section_guard_check_orphans() { # <lock>
  local lock="${1:-}" f pid st pids="" n=0 p i alive
  [ -n "$lock" ] || return 0
  command -v gate_lock_record_get >/dev/null 2>&1 || return 0
  for f in "$lock.runs"/*.run; do
    [ -f "$f" ] || continue
    [ "$(gate_lock_record_get "$f" ancestor)" = "$SG_OWNER_PID" ] || continue
    pid="$(gate_lock_record_get "$f" pid)"; st="$(gate_lock_record_get "$f" start)"
    case "$st" in ''|'-') st="" ;; esac
    _sg_pid_alive "$pid" "$st" || continue
    _sg_pid_running "$pid" || continue
    printf '  \033[31m✗\033[0m 嵌套运行在生它的那一段收口后仍活着：pid=%s %s → 只对这个登记过的 pid 发信号收尾\n' \
      "$pid" "$(gate_lock_describe_one "$f")"
    pids="$pids $pid"; n=$((n + 1))
  done
  [ "$n" -eq 0 ] && return 0
  for p in $pids; do kill -TERM "$p" 2>/dev/null || true; done
  for i in $(seq 1 25); do
    alive=0
    for p in $pids; do _sg_pid_running "$p" && alive=1; done
    [ "$alive" -eq 0 ] && break
    sleep 0.2
  done
  for p in $pids; do kill -KILL "$p" 2>/dev/null || true; done
  return 0
}

_sg_recent_files() { # <root> <min_epoch> <max>：窗口内动过的文件，**按 mtime 从新到旧**（有界）
  # 不按 find 的目录顺序：正在被写的那份（挂住段落的夹具日志）必须排在最前，否则 12 个名额会被
  # 窗口里更早、目录顺序靠前的文件占满 —— 2026-09-28 容器实测：0f 现场收进 .git/hooks/*.sample，
  # 挂住的夹具日志一条都没有（宿主 tmpfs 的目录顺序恰好是新文件在前，所以只在容器里现形）。
  find "$1" -type f -newermt "@$2" -printf '%T@\t%p\n' 2>/dev/null \
    | sort -rn | head -n "$3" | cut -f2-
}

_sg_scene_write() { # <no> <id> <budget> <elapsed> <last_seen> <ticks> <armed>
  local no="$1" id="$2" budget="$3" elapsed="$4" last_seen="$5" ticks="$6" armed="$7"
  mkdir -p "$SG_SCENE/logs" 2>/dev/null || return 0
  {
    printf 'section: #%s\nid: %s\nbudget: %ss\nelapsed: %ss\nlast progress: %ss\nticks: %s\n' \
      "$no" "$id" "$budget" "$elapsed" "$last_seen" "$ticks"
    printf 'watchdog pid: %s\n' "${BASHPID:-?}"
    printf 'suite pid: %s\n' "$SG_OWNER_PID"
    printf 'mode: FAST=%s fixture=%s\n' "${SG_FAST:-0}" "${SG_FIXTURE:-0}"
    printf 'knobs: stuck=%s budget_override=%s progress=%s poll=%s\n' \
      "${SG_STUCK_SECTION:-}" "${SG_BUDGET_OVERRIDE:-}" "$SG_PROGRESS_INTERVAL" "$SG_POLL"
    printf 'lock: %s\n' "$([ -n "$SG_LOCK_NOTE" ] && printf '%s holder=%s' "$SG_LOCK_NOTE" "$(cat "$SG_LOCK_NOTE.holder" 2>/dev/null || true)" || printf '（无）')"
    printf 'machine: nproc=%s loadavg=%s run_tmp=%s\n' \
      "$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || printf '?')" \
      "$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null || printf '?')" "$SG_RUN_TMP"
    printf -- '-- 子孙进程树（叶子优先）--\n'
    local p; p="$(_sg_descendants "$SG_OWNER_PID" "$BASHPID" | paste -sd, - 2>/dev/null || true)"
    if [ -n "$p" ]; then
      ps -o pid,ppid,pgid,stat,etime,args -p "$p" 2>/dev/null || true
    else
      printf '（无子孙）\n'
    fi
    printf -- '-- 进程表快照（有界 tail）--\n'
    ps -eo pid,ppid,pgid,stat,etime,args 2>/dev/null | tail -60
  } > "$SG_SCENE/summary.txt" 2>&1 || true
  {
    printf -- '-- 本段窗口内动过的文件（$TMP 下，有界 tail；按 mtime 从新到旧）--\n'
    local n=0 f
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      n=$((n + 1))
      [ "$n" -gt 12 ] && break
      printf '== %s ==\n' "${f#$SG_RUN_TMP/}"
      tail -c 4096 "$f" 2>/dev/null | tail -20 || true
    done < <(_sg_recent_files "$SG_RUN_TMP" "$((armed - 1))" 12)
    [ "$n" -eq 0 ] && printf '（本段窗口内没有 $TMP 下的新文件）\n'
  } > "$SG_SCENE/logs/tails.txt" 2>&1 || true
  if command -v tmux >/dev/null 2>&1; then
    {
      printf -- '-- 本 run 私有 tmux server 的 pane 尾屏（有界）--\n'
      local pane
      while IFS= read -r pane; do
        [ -n "$pane" ] || continue
        printf '== %s ==\n' "$pane"
        tmux capture-pane -p -t "$pane" 2>/dev/null | tail -15 || true
      done < <(tmux list-panes -a -F '#{session_name}:#{window_name}.#{pane_index}' 2>/dev/null | head -8)
    } > "$SG_SCENE/panes.txt" 2>&1 || true
  fi
  cp "$SG_TIMING" "$SG_SCENE/sections.tsv.partial" 2>/dev/null || true
  return 0
}

# ---------------------------------------------------------------- 有界等待助手
# section_guard_wait <name> <cap> <interval> <state> <reader|-> <predicate...>
#   每一轮刷新心跳/ticks；到顶打印一行归因（名字、n/cap、等什么、最后一次读数）并返回非 0。
section_guard_wait() {
  local name="$1" cap="$2" interval="$3" state="$4" reader="$5"; shift 5
  case "${cap:-x}" in ''|*[!0-9]*) printf 'section_guard_wait: cap 必须是正整数（收到 [%s]）\n' "${cap:-}" >&2; return 2 ;; esac
  [ "$cap" -gt 0 ] || { printf 'section_guard_wait: cap 必须是正整数（收到 %s）\n' "$cap" >&2; return 2; }
  local round=0 reading="（无读数）"
  while [ "$round" -lt "$cap" ]; do
    round=$((round + 1))
    section_guard_check
    if [ "$reader" != "-" ] && [ -n "$reader" ] && command -v "$reader" >/dev/null 2>&1; then
      reading="$("$reader" "$round" 2>/dev/null || true)"
      [ -n "$reading" ] || reading="（读数命令没有输出）"
    fi
    if "$@"; then
      return 0
    fi
    sleep "$interval"
  done
  printf '  \033[33m等待到顶\033[0m %s：%s/%s 轮；在等「%s」；最后一次读数：%s\n' \
    "$name" "$round" "$cap" "$state" "$reading"
  return 1
}

# ---------------------------------------------------------------- 自检（形状 + 现场顺序 + 红侧翻转）
_sg_selftest_case() { # <name> <shape> <want:0|2|!0> <want_scene:0|1>
  local name="$1" shape="$2" want="$3" want_scene="$4"
  local dir="$ST_ROOT/$name"; mkdir -p "$dir/run-tmp"
  local rc=0
  (
    export TMPDIR="$dir"
    section_guard_init "$dir/run-tmp" --poll 0.2 --progress 300 --suite-grace 1 --desc-grace 2 --default-budget 2
    section_guard_arm
    section_guard_begin "selftest-$name"
    wait
    printf 'BARE_WAIT_RETURNED\n'
    case "$shape" in
      stuck)      eval 'sleep infinity' ;;
      stubborn)   bash -c 'trap "" TERM; while :; do sleep 0.2; done' ;;
      spin)       while :; do :; done ;;
      deadspin)   trap '' TERM; while :; do :; done ;;
      clean)      SG_BAND=0; SG_ARMED_EPOCH="$(( $(date +%s) - 5 ))" ;;
      decimal)    SG_BAND=0.19; SG_ARMED_EPOCH="$(( $(date +%s) - 5 ))" ;;
    esac
    section_guard_check
    section_guard_finish
    printf 'SECTION_DONE\n'
    exit 0
  ) >"$dir/out.log" 2>&1
  rc=$?
  case "$want" in
    0)  [ "$rc" = "0" ] && st_ok "$name：套件 exit 0" || st_bad "$name：套件 exit $rc（期望 0）" ;;
    2)  [ "$rc" = "2" ] && st_ok "$name：套件 exit 2（trip 路径）" || st_bad "$name：套件 exit $rc（期望 2）" ;;
    !0) [ "$rc" != "0" ] && st_ok "$name：套件 exit $rc（非零，KILL 路径）" || st_bad "$name：套件 exit 0" ;;
  esac
  local scene
  scene="$(ls -d "$dir"/.teamsmith-smoke-scene.* 2>/dev/null | head -1 || true)"
  if [ "$want_scene" = "1" ]; then
    if [ -n "$scene" ] && [ -s "$scene/summary.txt" ]; then
      st_ok "$name：现场存在且有摘要（${scene#$ST_ROOT/}）"
      grep -qF "selftest-$name" "$scene/summary.txt" && st_ok "$name：现场点名该段" || st_bad "$name：现场没点名该段"
      grep -qF '超时' "$dir/out.log" && st_ok "$name：stdout 有一行点名超时" || st_bad "$name：stdout 没有点名超时"
      grep -qF 'SECTION_DONE' "$dir/out.log" && st_bad "$name：套件居然跑完了整段" || st_ok "$name：套件没有跑完整段"
    else
      st_bad "$name：没有现场（期望有）"
    fi
  else
    [ -z "$scene" ] && st_ok "$name：干净路径没有现场" || st_bad "$name：干净路径留下了现场"
  fi
  # 现场要活过 run 自己的临时根（trip 路径：run-tmp 被删，现场还在）
  if [ "$want_scene" = "1" ] && [ -n "$scene" ]; then
    rm -rf -- "$dir/run-tmp" 2>/dev/null || true
    [ -d "$scene" ] && [ -s "$scene/summary.txt" ] \
      && st_ok "$name：现场活过了 run 临时根被删（清理带不走）" \
      || st_bad "$name：run 临时根删掉后现场也丢了"
  fi
  grep -qF 'BARE_WAIT_RETURNED' "$dir/out.log" && st_ok "$name：裸 wait 没被看门狗卡住" || st_bad "$name：裸 wait 没返回"
  if [ "$shape" = "clean" ]; then
    grep -qF '超过实测带' "$dir/out.log" && st_ok "$name：整数 band 超过时打一行警告（记录，不是判定）" \
                                          || st_bad "$name：超过实测带没有警告行"
  fi
  if [ "$shape" = "decimal" ]; then
    grep -qF '超过实测带 0.19s' "$dir/out.log" \
      && st_ok "$name：小数 band（0.19）超过时也打警告（P108 F2）" \
      || st_bad "$name：小数 band 超过时没有警告行（规范承诺对 110/112 行不可达）"
    grep -qF '这是记录，不是判定' "$dir/out.log" \
      && st_ok "$name：小数 band 的警告仍是记录、不是判定（D33）" \
      || st_bad "$name：小数 band 的警告丢了「记录，不是判定」"
  fi
  local i pidfile
  for i in $(seq 1 25); do
    pidfile="$(ls "$dir"/.teamsmith-smoke-guard.pid.* 2>/dev/null | head -1 || true)"
    [ -z "$pidfile" ] && break
    sleep 0.1
  done
  [ -z "$pidfile" ] && st_ok "$name：看门狗随套件退场（pidfile 已收）" || { st_bad "$name：看门狗 pidfile 还在：$pidfile"; rm -f "$pidfile"; }
  return 0
}

# F1 夹具（P110）：`--desc-grace 2` + 一个**响应 TERM**的子进程。套件的退出路径会持续产出短命
# 子进程（P108 的现场形状），所以 grace 用尽时仍有子孙存活 —— 但没有任何证据能说它们「忽略了
# TERM」。归因行只许说「grace 用尽 → 已发 KILL」；旧措辞「子孙忽略 TERM」是与现场矛盾的断言。
_sg_selftest_f1() {
  local dir="$ST_ROOT/f1-escalation"
  local scene="$dir/scene"
  mkdir -p "$scene"
  local out="$dir/stop.log"
  # 假套件（= `_sg_stop_children` 看到的 $SG_OWNER_PID 树）：每个后台 `sleep 1` 都是响应 TERM 的
  # 普通子进程，新的不断出生 —— grace 用尽时总有子孙在，但没有一个 pid 能证明自己忽略了 TERM。
  # 收尾只动我们自己 spawn 的 pid（D37：TERM 陷阱让假套件带走自己的 jobs；绝不按名字杀）。
  bash -c '
    trap "kill \$(jobs -p) 2>/dev/null; exit 0" TERM
    for i in $(seq 1 400); do sleep 1 & sleep 0.05; done
    wait
  ' 2>"$dir/suite.err" &
  local suite=$!
  # 等第一个孩子出生：否则 `_sg_stop_children` 的第一轮可能看到空树直接退出（夹具抖动）。
  local i=0
  while [ "$i" -lt 40 ]; do
    [ -n "$(_sg_descendants "$suite" "$BASHPID")" ] && break
    sleep 0.05; i=$((i + 1))
  done
  SG_OWNER_PID="$suite"
  SG_SCENE="$scene"
  SG_DESC_GRACE=2
  _sg_stop_children 99 >"$out" 2>&1 || true
  # 现场仍然要留（KILL 照发、现场照写；改的只是归因）
  grep -qF 'escalation:' "$scene/summary.txt" 2>/dev/null \
    && st_ok "F1 夹具：grace 用尽时现场记录了 KILL 升级" \
    || st_bad "F1 夹具：现场没有记录 escalation（KILL 现场不许被删）"
  grep -qF '已发 KILL' "$out" \
    && st_ok "F1 夹具：stdout 有一行 KILL 升级（只改归因，不删行）" \
    || st_bad "F1 夹具：stdout 的 KILL 升级行不见了"
  # 归因诚实：两个现场都不得出现旧措辞的因果断言（是否忽略 TERM 未验证）
  if grep -qF '忽略 TERM' "$out" "$scene/summary.txt" 2>/dev/null; then
    st_bad "F1 夹具：归因仍声称「子孙忽略 TERM」（现场里没有这个证据）"
  else
    st_ok "F1 夹具：归因只说「grace 用尽」，没有「忽略 TERM」的断言"
  fi
  grep -qF 'grace 用尽' "$out" \
    && st_ok "F1 夹具：归因行点名真正的原因（grace 用尽）" \
    || st_bad "F1 夹具：归因行没有说明是 grace 用尽"
  # 收尾：只对我们 spawn 的假套件发信号；它的 TERM 陷阱带走自己的 jobs
  kill -TERM "$suite" 2>/dev/null || true
  local j
  for j in $(seq 1 25); do
    kill -0 "$suite" 2>/dev/null || break
    sleep 0.05
  done
  kill -KILL "$suite" 2>/dev/null || true
  wait "$suite" 2>/dev/null || true
  return 0
}

# ---------------------------------------------------------------- P313：心跳循环的三条边界
# 用**真**父进程造现场（不真留两天）：
#   ① 父进程被 KILL -9（来不及通知任何人）→ 心跳必须在 ~3s 内自己退；
#   ② 对心跳直接发 TERM → 必须有界退出；
#   ③ 硬上限：cap=2s、父还活着、没人发 TERM → 到点自己退，日志尾部留一行说明；
#   ④ 写目标被删（夹具的临时根被清理）→ 不再往已删除的文件里写，立即退。
# 四条都是这个函数自己收尾（变异副本让某条失效时，剩下的进程由这里 KILL —— 夹具自己也不许泄漏）。
_sg_selftest_orphan() {
  local lib dir log pid n i gone parent hp cp
  lib="$(_sg_spin_lib_path)"
  dir="$ST_ROOT/spin"; mkdir -p "$dir"
  if [ ! -f "$lib" ]; then st_bad "P313：心跳循环的实现不在（$lib）"; return 0; fi

  # ① 父进程没了就退：中间的 bash 起心跳（父 = 它自己）后自旋；我们对它 KILL -9
  log="$dir/parent.log"; : > "$log"
  bash -c '. "$1"; shift; bounded_spin 0.2 30 - "$1" "$$" & echo "$!" > "$2"; sleep 120' _ \
    "$lib" "$log" "$dir/parent.pid" 2>"$dir/parent.err" &
  parent=$!
  for n in $(seq 1 50); do [ -s "$dir/parent.pid" ] && break; sleep 0.1; done
  pid="$(cat "$dir/parent.pid" 2>/dev/null || true)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    st_ok "P313①：心跳先起来了（pid=$pid）"
    [ "$(grep -c '^[0-9]\{10\}$' "$log" 2>/dev/null || true)" -ge 1 ] \
      && st_ok "P313①：心跳真的在写（日志里有时间戳）" \
      || st_bad "P313①：心跳没有写日志（夹具失效）"
    kill -KILL "$parent" 2>/dev/null || true; wait "$parent" 2>/dev/null || true
    gone=0
    for i in $(seq 1 30); do kill -0 "$pid" 2>/dev/null || { gone=1; break; }; sleep 0.1; done
    if [ "$gone" = "1" ]; then
      st_ok "P313①：父进程被 KILL 后心跳自己退了（≤3s）"
    else
      st_bad "P313①：心跳活过了父进程（去掉父进程检查就是这个形状）"
      kill -KILL "$pid" 2>/dev/null || true
    fi
    grep -qF '父进程' "$log" 2>/dev/null && st_ok "P313①：日志里有一行说明原因（父进程已不在）" \
                                          || st_bad "P313①：日志里没有说明为什么退"
  else
    st_bad "P313①：心跳没起来（夹具失效）"
    kill -KILL "$parent" 2>/dev/null || true; wait "$parent" 2>/dev/null || true
  fi

  # ② TERM 就让路：父（本 shell）还活着，直接给心跳发 TERM
  log="$dir/term.log"; : > "$log"
  bash -c '. "$1"; shift; bounded_spin 0.2 30 - "$1" "$2"' _ "$lib" "$log" "$$" 2>"$dir/term.err" &
  hp=$!
  sleep 0.5
  if kill -0 "$hp" 2>/dev/null; then
    kill -TERM "$hp" 2>/dev/null || true
    gone=0
    for i in $(seq 1 30); do kill -0 "$hp" 2>/dev/null || { gone=1; break; }; sleep 0.1; done
    if [ "$gone" = "1" ]; then
      st_ok "P313②：TERM 让心跳退出（≤3s）"
    else
      st_bad "P313②：心跳扛住了 TERM（trap \"\" TERM 就是这个形状）"
      kill -KILL "$hp" 2>/dev/null || true
    fi
    grep -qF '收到 TERM' "$log" 2>/dev/null && st_ok "P313②：日志里有一行点名收到 TERM" \
                                            || st_bad "P313②：日志里没有点名 TERM"
  else
    st_bad "P313②：心跳没起来（夹具失效）"
  fi
  wait "$hp" 2>/dev/null || true

  # ③ 硬上限：2s 到点自己退（父一直活着、没人发信号）
  log="$dir/cap.log"; : > "$log"
  bash -c '. "$1"; shift; bounded_spin 0.2 2 - "$1" "$2"' _ "$lib" "$log" "$$" 2>"$dir/cap.err" &
  cp=$!
  gone=0
  for i in $(seq 1 80); do kill -0 "$cp" 2>/dev/null || { gone=1; break; }; sleep 0.1; done
  if [ "$gone" = "1" ]; then
    st_ok "P313③：到点（2s 上限）自己退"
  else
    st_bad "P313③：到了上限还在跑（硬上限被拿走就是这个形状）"
    kill -KILL "$cp" 2>/dev/null || true
  fi
  grep -qF '到点（最大运行 2s）' "$log" 2>/dev/null && st_ok "P313③：日志里有一行点名上限" \
                                                      || st_bad "P313③：日志里没有提到点退出"
  wait "$cp" 2>/dev/null || true

  # ④ 写目标被删：夹具的临时根被清理后不许再往已删除的文件里写
  log="$dir/gone.log"; : > "$log"
  bash -c '. "$1"; shift; bounded_spin 0.2 30 - "$1" "$2"' _ "$lib" "$log" "$$" 2>"$dir/gone.err" &
  cp=$!
  sleep 0.4; rm -f -- "$log"
  gone=0
  for i in $(seq 1 30); do kill -0 "$cp" 2>/dev/null || { gone=1; break; }; sleep 0.1; done
  if [ "$gone" = "1" ]; then
    st_ok "P313④：写目标被删后心跳自己退（不再往已删除的文件里写）"
  else
    st_bad "P313④：写目标已删，心跳还在写（11.98 GB 那个形状）"
    kill -KILL "$cp" 2>/dev/null || true
  fi
  wait "$cp" 2>/dev/null || true
  return 0
}

# 红侧翻转：把实现变异回旧形状（f2 = 整数守卫；f1 = 「子孙忽略 TERM」措辞）。
# 这是「破坏实现 → 守卫测试必须红」的前半：变异后的副本由 _sg_selftest_flips 跑。
_sg_skill_dir() { # 本库所属的 skill 树（变异副本靠它拿到真正的解析器）
  if [ -n "${TEAM_SG_SKILL_DIR:-}" ]; then printf '%s' "$TEAM_SG_SKILL_DIR"; return 0; fi
  ( cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd )
}

# P313：心跳循环的唯一实现（红侧变异副本靠 SG_SPIN_LIB 指到别处；默认是本 skill 树里的那一份）
_sg_spin_lib_path() {
  if [ -n "${SG_SPIN_LIB:-}" ]; then printf '%s' "$SG_SPIN_LIB"; return 0; fi
  printf '%s' "$(_sg_skill_dir)/tests/lib/bounded-spin.sh"
}

_sg_selftest_mutate() { # <src> <dst> <f2|f1|f3|f4|f5> → 0 = 变异落地
  local src="$1" dst="$2" kind="$3"
  case "$kind" in
    f2) awk '
      /^_sg_band_over\(\) \{/ { inband = 1 }
      inband && /^  case "\$band" in/ {
        print "  case \"$band\" in   # P110_F2 红侧：旧整数守卫（小数落空分支）"
        print "    \047\047|*[!0-9]*) return 1 ;;"
        print "  esac"
        skipping = 1; inband = 0; next
      }
      skipping { if ($0 == "  esac") skipping = 0; next }
      { print }
    ' "$src" > "$dst" ;;
    f1) sed 's/的 grace 用尽（仍有子孙存活）→ 已/的子孙忽略 TERM → 已/g' "$src" > "$dst" ;;
    # P313：心跳循环的三条边界。变异的是 lib/bounded-spin.sh（一个文件、三条各自可辨的行）。
    f3) sed 's|^  while _bs_parent_alive "\$parent"; do$|  while :; do   # P313-F3 红侧：父进程检查被拿掉|' "$src" > "$dst" ;;
    f4) sed "s|^    trap '_bs_on_term' TERM$|    trap '' TERM   # P313-F4 红侧：忽略 TERM|" "$src" > "$dst" ;;
    f5) sed 's|^    if \[ "\$(( SECONDS - t0 ))" -ge "\$cap_s" \]; then _bs_exit "到点（最大运行 \${cap_s}s）"; fi$|    : # P313-F5 红侧：硬上限被拿掉|' "$src" > "$dst" ;;
    *) return 1 ;;
  esac
  # 变异必须真的改变文件（拿标记 grep 会被变异代码自身的存在骗过），且副本仍然可解析。
  [ -s "$dst" ] || { rm -f "$dst"; return 1; }
  cmp -s "$src" "$dst" && { rm -f "$dst"; return 1; }
  bash -n "$dst" 2>/dev/null || { rm -f "$dst"; return 1; }
  return 0
}

# 两个红侧翻转（只在完整自检里跑；`--self-test <形状>` 只跑形状，避免递归）：
#   F2：小数值 band 的警告 —— 变异回整数守卫 → decimal 夹具必须红；
#   F1：grace 用尽的归因 —— 变异回「子孙忽略 TERM」→ f1 夹具必须红。
# 变异副本跑在自己的私有 TMPDIR 下，跑完连根删掉（失败也不留现场）。
_sg_selftest_flips() {
  local dir="$ST_ROOT/flips" self mut rc out
  self="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  mkdir -p "$dir/f2-tmp" "$dir/f1-tmp"
  # --- F2 ---
  mut="$dir/f2-legacy-guard.sh"; out="$dir/f2-mutated.log"
  if _sg_selftest_mutate "$self" "$mut" f2; then
    TEAM_SG_SKILL_DIR="$(_sg_skill_dir)" TMPDIR="$dir/f2-tmp" bash "$mut" --self-test decimal >"$out" 2>&1; rc=$?
    [ "$rc" -ne 0 ] && st_ok "F2 红侧：还原成整数守卫 → decimal 夹具红（rc=$rc）" \
                    || st_bad "F2 红侧：还原成整数守卫后 decimal 夹具仍绿（守卫没被证到）"
    grep -qF '超过实测带' "$out" && st_bad "F2 红侧：整数守卫下居然打了「超过实测带」行" \
                                  || st_ok "F2 红侧：整数守卫下没有「超过实测带」警告行（规范承诺回到不可达）"
    grep -qF '小数 band 超过时没有警告行' "$out" \
      && st_ok "F2 红侧：红的是那条夹具断言本身（不是别的原因）" \
      || st_bad "F2 红侧：红的原因不是「小数 band 没有警告行」"
  else
    st_bad "F2 红侧：变异没落到 _sg_band_over（夹具失效）"
  fi
  # --- F1 ---
  mut="$dir/f1-legacy-wording.sh"; out="$dir/f1-mutated.log"
  if _sg_selftest_mutate "$self" "$mut" f1; then
    TEAM_SG_SKILL_DIR="$(_sg_skill_dir)" TMPDIR="$dir/f1-tmp" bash "$mut" --self-test f1 >"$out" 2>&1; rc=$?
    [ "$rc" -ne 0 ] && st_ok "F1 红侧：还原成「子孙忽略 TERM」措辞 → f1 夹具红（rc=$rc）" \
                    || st_bad "F1 红侧：还原措辞后 f1 夹具仍绿（归因守卫没被证到）"
    grep -qF '归因仍声称' "$out" \
      && st_ok "F1 红侧：红的是那条夹具断言本身（不是别的原因）" \
      || st_bad "F1 红侧：红的原因不是「归因仍声称忽略 TERM」"
  else
    st_bad "F1 红侧：变异没落到归因措辞（夹具失效）"
  fi
  # --- P313①/②/③：心跳循环的父进程检查 / TERM / 硬上限 ---
  local spin_src mutant
  spin_src="$(_sg_spin_lib_path)"
  if [ -f "$spin_src" ]; then
    local -a _p313_kinds=(f3 f4 f5)
    local -a _p313_want=("P313①：心跳活过了父进程" "P313②：心跳扛住了 TERM" "P313③：到了上限还在跑")
    local _k _want _j
    for _j in 0 1 2; do
      _k="${_p313_kinds[$_j]}"; _want="${_p313_want[$_j]}"
      mkdir -p "$dir/$_k-tmp"
      mutant="$dir/$_k-bounded-spin.sh"; out="$dir/$_k-mutated.log"
      if _sg_selftest_mutate "$spin_src" "$mutant" "$_k"; then
        TEAM_SG_SKILL_DIR="$(_sg_skill_dir)" SG_SPIN_LIB="$mutant" TMPDIR="$dir/$_k-tmp" \
          bash "$self" --self-test orphan >"$out" 2>&1; rc=$?
        [ "$rc" -ne 0 ] && st_ok "P313 $_k 红侧：变异后心跳边界自检红（rc=$rc）" \
                        || st_bad "P313 $_k 红侧：变异后心跳边界自检仍绿（守卫没被证到）"
        grep -qF "$_want" "$out" \
          && st_ok "P313 $_k 红侧：红的是那条边界断言本身（$_want）" \
          || st_bad "P313 $_k 红侧：红的原因不是「$_want」"
      else
        st_bad "P313 $_k 红侧：变异没落到 bounded-spin.sh（夹具失效）"
      fi
    done
  else
    st_bad "P313 红侧：找不到心跳循环实现（$spin_src）"
  fi
  rm -rf -- "$dir" 2>/dev/null || true
  return 0
}

_sg_selftest() {
  local arg shape shapes want_all=1
  local only=()
  for arg in "$@"; do
    case "$arg" in
      --help|-h) printf '用法：bash %s --self-test [形状…]\n        形状：clean stuck stubborn spin deadspin decimal orphan f1（不带形状 = 全部 + 红侧翻转）\n' "${BASH_SOURCE[0]}"; return 0 ;;
      -*) printf 'section-guard: 自检不认识的参数 %s\n' "$arg" >&2; return 2 ;;
      *) only+=("$arg"); want_all=0 ;;
    esac
  done
  local PASS=0 FAIL=0
  st_ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
  st_bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
  local ST_ROOT
  team_tmp_root_prepare >/dev/null 2>&1 || true
  ST_ROOT="$(mktemp -d "$(team_tmp_root)/teamsmith-sg-selftest-$(team_project_ns).XXXXXX" 2>/dev/null)" || {
    printf 'section-guard 自检：建不出临时根\n' >&2; return 3; }
  local pgid_before pgid_after
  pgid_before="$(ps -o pgid= -p "$$" 2>/dev/null | tr -d ' ')"
  printf '\n\033[1m== section-guard.sh 自检（形状 + 现场顺序 + 进程组 + 红侧翻转）==\033[0m\n'
  SG_FIXTURE=1
  TEAM_SMOKE_FIXTURE=1
  if [ "$want_all" = "1" ]; then
    shapes="clean stuck stubborn spin deadspin decimal orphan"
  else
    shapes="${only[*]}"
  fi
  for shape in $shapes; do
    case "$shape" in
      clean)    _sg_selftest_case clean     clean     0  0 ;;
      stuck)    _sg_selftest_case stuck     stuck     2  1 ;;
      stubborn) _sg_selftest_case stubborn  stubborn  2  1 ;;
      spin)     _sg_selftest_case spin      spin      2  1 ;;
      deadspin) _sg_selftest_case deadspin  deadspin  '!0' 1 ;;
      decimal)  _sg_selftest_case decimal   decimal   0  0 ;;
      orphan)   _sg_selftest_orphan ;;
      f1)       _sg_selftest_f1 ;;
      *)        st_bad "自检：不认识的形状「$shape」（可用：clean stuck stubborn spin deadspin decimal orphan f1）"; break ;;
    esac
  done
  # 现场尾巴的收集顺序 = mtime 降序，不是 find 的目录顺序（容器实测：目录顺序把挂住的夹具日志
  # 挤出了 12 个名额）。夹具反向：先建 live 文件，再建 15 个「目录顺序更靠前但 mtime 更旧」的。
  local cd="$ST_ROOT/recent"; mkdir -p "$cd"
  : > "$cd/live.txt"
  local i
  for i in $(seq 1 15); do : > "$cd/old-$i.txt"; done
  touch -d '2020-01-01 00:00:00' "$cd"/old-*.txt
  local recent_first recent_n
  recent_first="$(_sg_recent_files "$cd" 0 12 | head -1)"
  recent_n="$(_sg_recent_files "$cd" 0 12 | wc -l | tr -d ' ')"
  [ "$(basename "$recent_first")" = "live.txt" ] \
    && st_ok "现场尾巴：按 mtime 从新到旧（正在被写的那份在最前）" \
    || st_bad "现场尾巴：最新被写的文件不在最前（第一行 ${recent_first:-空}）"
  [ "$recent_n" = "12" ] && st_ok "现场尾巴：名额有界（16 个候选只收 12 个）" \
                          || st_bad "现场尾巴：条数 $recent_n ≠ 12"
  pgid_after="$(ps -o pgid= -p "$$" 2>/dev/null | tr -d ' ')"
  [ "$pgid_before" = "$pgid_after" ] && st_ok "调用者的进程组没变（没有进程组信号）" \
                                     || st_bad "调用者的进程组变了（$pgid_before → $pgid_after）"
  if [ "$want_all" = "1" ]; then
    _sg_selftest_f1
    _sg_selftest_flips
  fi
  printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
  if [ "$FAIL" -eq 0 ]; then
    rm -rf -- "$ST_ROOT" 2>/dev/null || true
    printf '\033[32msection-guard 自检全绿\033[0m\n'
    return 0
  fi
  printf '\033[31msection-guard 自检有失败项（现场保留 %s）\033[0m\n' "$ST_ROOT"
  return 1
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-}" in
    --self-test) shift; _sg_selftest "$@" ;;
    --help|-h|"") printf '用法：bash %s --self-test（被 smoke.sh source 用）\n' "${BASH_SOURCE[0]}" ;;
    *) printf 'section-guard.sh：只支持 --self-test（被 smoke.sh source 用）\n' >&2; exit 2 ;;
  esac
fi
