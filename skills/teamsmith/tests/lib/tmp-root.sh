#!/usr/bin/env bash
# tmp-root.sh — 夹具临时根的**唯一创建者**（change: test-tmp-hygiene · 实现：P53）
#
# 用法（夹具里）：
#   . "$SELF_DIR/lib/tmp-root.sh"
#   TMP="$(tmp_root_create <kind>)"          # → ${TMPDIR:-/tmp}/teamsmith-<kind>.XXXXXX
#   cleanup() { tmp_root_reap_all; ... }     # 正常退出 / INT / TERM 都回收；TEAM_TMP_KEEP=1 才留
#   trap cleanup EXIT
#
# 为什么要有它（design.md §D1–D3、§D8）：
#   ① 根一律建在**解析后的**临时根 `${TMPDIR:-/tmp}`（写死 `/tmp` 的模板会被 --lint 判红）；
#      名字进一个 owned 家族 `teamsmith-<kind>.XXXXXX`（sweep 只认这个前缀，别的前缀不碰）；
#   ② 根里写 owner 标记 `.teamsmith-tmp`（kind / 创建 pid / 该进程启动时间 / boot id / run id），
#      于是 killed run 的残留**可归因**，且「owner 已死」判定对 pid 复用安全；
#   ③ 每次创建追加一条 run 台账（`$TEAM_TMP_LEDGER`，默认临时根下的点开头文件）——门禁据此断言
#      「本轮创建的根一个都不许留下」，而不是去猜文件系统；
#   ④ 对出界进程（anchor / sleep）**spawn 时** `tmp_root_track_pid <pid>` 记账，cleanup **只对记录的
#      pid** 发信号（D37）：禁止按名字 / 命令行匹配 —— `--self-test` 的 `nokill` 反转钉住这一条。
#
# 关键实现事实（踩过的坑，改动前先读）：
#   - 夹具的惯用写法是 `TMP="$(tmp_root_create ...)"`：命令替换是**子 shell**，所以状态不能只放在
#     内存数组里 —— 根的归属走台账（pid + starttime），回收时按台账找自己的根；
#   - `$$` 在子 shell 里仍是**主 shell 的 pid**（bash 语义），台账因此记的是主 shell；
#   - run id 必须**跨子 shell 稳定**（同一 shell 的每次命令替换都一样），否则台账路径会漂 ——
#     所以默认 id 用 `p$$-<进程启动 jiffies>`，不用 `$RANDOM`；
#   - INT/TERM 陷阱在 **source 时**装（create 在子 shell 里装不到主 shell 上）；EXIT 兜底只在
#     调用者**还没有** EXIT trap 时装，夹具自己 `trap cleanup EXIT` 后由 cleanup 调 tmp_root_reap_all。
#
# 契约（细节见 references/protocol.md、design.md）：
#   - 正常退出与 INT/TERM 都回收；`TEAM_TMP_KEEP=1` 保留并**打印路径**；
#   - 台账 / 标记在根之外或根之内自洽；nested run 各自记账，互不收对方的根；
#   - 本文件**不改 shell 选项**、不 export 任何东西；只创建 `${TMPDIR:-/tmp}` 下的根。
#
# 自检：`bash tests/lib/tmp-root.sh --self-test [--break=<stage>]`
#   `--break=` 把某条规则变回「有缺陷的旧行为」，守门断言必须因此变红（翻转证据，复验用）。

TMP_ROOT_LIB=1
TMP_ROOT_FAMILY_PREFIX="teamsmith-"

_tmp_root_err() { printf 'tmp-root: %s\n' "$*" >&2; }

# ---------------------------------------------------------------- 基础事实
tmp_root_base() { printf '%s\n' "${TMPDIR:-/tmp}"; }

# run id：优先 TEAM_TMP_RUN_ID；嵌套夹具会清掉 TEAM_*（身份清理），所以门禁同时给非 TEAM_ 的
# SMOKE_TMP_RUN_ID（它不属于身份，清不掉的传播位）。都没有 → 本进程自己算一个（跨子 shell 稳定）。
tmp_root_run_id() {
  if [ -z "${TMP_ROOT_RUN_ID:-}" ]; then
    local id="${TEAM_TMP_RUN_ID:-${SMOKE_TMP_RUN_ID:-}}"
    if [ -z "$id" ]; then
      local st; st="$(_tmp_root_proc_start $$ 2>/dev/null || true)"
      id="p$$-${st:-0}"
    fi
    TMP_ROOT_RUN_ID="$(printf '%s' "$id" | tr -c 'A-Za-z0-9._-' '_')"
  fi
  printf '%s\n' "$TMP_ROOT_RUN_ID"
}

tmp_root_ledger() {
  printf '%s\n' "${TEAM_TMP_LEDGER:-$(tmp_root_base)/.teamsmith-tmp-ledger.$(tmp_root_run_id)}"
}

tmp_root_pidfile() {
  printf '%s\n' "${TMP_ROOT_PIDFILE:-$(tmp_root_base)/.teamsmith-tmp-pids.$(tmp_root_run_id).$$}"
}

# /proc/<pid>/stat 的 starttime（boot 后的 jiffies）：pid 复用的安全判据。读不到 → 非 0。
_tmp_root_proc_start() {
  local stat
  stat="$(LC_ALL=C cat "/proc/$1/stat" 2>/dev/null)" || return 1
  stat="${stat##*\) }"
  # shellcheck disable=SC2086
  set -- $stat
  [ -n "${20:-}" ] || return 1
  printf '%s\n' "$20"
}

# 0 = pid 活着且（给了 start 时）就是记下的那个进程；僵尸（Z）算死。
_tmp_root_proc_alive() {
  local pid="${1:-}" want="${2:-}" st state
  case "$pid" in ''|*[!0-9]*) return 1 ;; esac
  [ -r "/proc/$pid/stat" ] || return 1
  st="$(_tmp_root_proc_start "$pid")" || return 1
  [ -n "$want" ] && [ "$want" != "unknown" ] && [ "$st" != "$want" ] && return 1
  state="$(awk '{sub(/^.*\) /,""); print $1}' "/proc/$pid/stat" 2>/dev/null || true)"
  [ "$state" = "Z" ] && return 1
  return 0
}

# 路径是不是「解析后的临时根下的 owned 家族」——--lint/自检用；`--break=notmpdir` 模拟写死 /tmp 混过关。
tmp_root_path_ok() {
  if [ "${TMP_ROOT_BREAK:-}" = "notmpdir" ]; then return 0; fi
  case "${1:-}" in
    "$(tmp_root_base)"/"$TMP_ROOT_FAMILY_PREFIX"*) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------- 创建
_tmp_root_ledger_append() { # <path> <pid> <start> <kind> <created>
  local f; f="$(tmp_root_ledger)"
  if [ ! -f "$f" ]; then
    printf '# teamsmith temp ledger run=%s owner=%s started=%s\n' \
      "$(tmp_root_run_id)" "$$" "$(date +%s 2>/dev/null || printf 0)" >"$f" 2>/dev/null || return 1
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$(tmp_root_run_id)" >>"$f" 2>/dev/null || return 1
  return 0
}

# INT/TERM 的回收路径（实测过的 bash 语义，改动前先读）：
#   - INT：非交互 shell 默认**不会**因 SIGINT 而死（实测：前台 sleep 里收 INT，shell 活着、EXIT trap 不跑），
#     所以必须装 INT 陷阱；它在当前前台命令结束/`wait` 被打断时执行 → 回收。
#   - TERM：**不装陷阱**。未捕获的致命 TERM 会立即杀掉 shell 并跑 EXIT trap（实测 ~100ms），
#     装了陷阱反而被 bash 「等前台命令结束再跑」的规则推迟 —— 长前台命令（真进程夹具）里回收会晚到。
# EXIT trap 只在调用者**还没有** EXIT trap 时装 —— 夹具自己的 `trap cleanup EXIT` 之后由 cleanup
# 调 tmp_root_reap_all（构造上两种路径都收）。
_tmp_root_install_traps() {
  [ "${TMP_ROOT_TRAPS:-0}" = "1" ] && return 0
  TMP_ROOT_TRAPS=1
  trap 'tmp_root_on_signal INT' INT 2>/dev/null || true
  if [ -z "$(trap -p EXIT 2>/dev/null || true)" ]; then
    trap 'tmp_root_reap_all' EXIT
  fi
  return 0
}

# tmp_root_create <kind> → 打印根路径（stdout 只有这一行）。失败：2 非法 kind / 3 建不出来。
tmp_root_create() {
  local kind="${1:-fixture}"
  case "$kind" in
    ''|*[!A-Za-z0-9._-]*) _tmp_root_err "非法 kind [${kind}]（只允许 A-Za-z0-9._-）"; return 2 ;;
  esac
  local base; base="$(tmp_root_base)"
  if [ ! -d "$base" ]; then
    _tmp_root_err "临时根 $base 不存在（TMPDIR 指向不存在的目录？）"
    return 3
  fi
  local root
  root="$(mktemp -d "$base/$TMP_ROOT_FAMILY_PREFIX$kind.XXXXXX" 2>/dev/null)" || {
    _tmp_root_err "在 $base 下建不出根（空间/inode/权限？）"; return 3; }
  local pid=$$ start boot created run
  start="$(_tmp_root_proc_start "$pid" 2>/dev/null || true)"
  boot="$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || printf 'unknown')"
  created="$(date +%s 2>/dev/null || printf 0)"
  run="$(tmp_root_run_id)"
  if ! { printf 'kind=%s\npid=%s\nstart=%s\nboot=%s\nrun=%s\ncreated=%s\n' \
           "$kind" "$pid" "${start:-unknown}" "$boot" "$run" "$created" >"$root/.teamsmith-tmp"; }; then
    _tmp_root_err "写不了 owner 标记 $root/.teamsmith-tmp"
    rm -rf -- "$root" 2>/dev/null || true
    return 3
  fi
  _tmp_root_ledger_append "$root" "$pid" "${start:-unknown}" "$kind" "$created" || true
  printf '%s\n' "$root"
  return 0
}

# ---------------------------------------------------------------- 出界进程记账（D37）
# tmp_root_track_pid <pid> [label]：spawn 之后立刻调用；cleanup 只对这些 pid 发信号。
tmp_root_track_pid() {
  local pid="${1:-}" label="${2:-}" start pf
  case "$pid" in ''|*[!0-9]*) _tmp_root_err "track: 非法 pid [${pid}]"; return 2 ;; esac
  [ "$pid" -gt 1 ] || return 2
  start="$(_tmp_root_proc_start "$pid" 2>/dev/null || true)"
  pf="$(tmp_root_pidfile)"
  printf '%s\t%s\t%s\n' "$pid" "${start:-unknown}" "$label" >>"$pf" 2>/dev/null || return 3
  return 0
}

# tmp_root_detach <path>：把根从「本进程退出时回收」的清单里摘出来 —— 供「返回一个路径给调用方、
# 生命周期归调用方」的 fixture CLI 用（如 load-experiment 的 private-root）。根留在台账里（--status
# 仍可归因、老了也能被 --sweep 回收），但本进程的 EXIT/INT 不再删它。
tmp_root_detach() {
  local p="${1:-}"
  [ -d "$p" ] || return 2
  [ -f "$p/.teamsmith-tmp" ] || return 2
  printf 'detached=1\n' >>"$p/.teamsmith-tmp" 2>/dev/null || return 3
  return 0
}

# ---------------------------------------------------------------- 回收
_tmp_root_signal_tracked() {
  local pf; pf="$(tmp_root_pidfile)"
  [ -f "$pf" ] || return 0
  local grace="${TEAM_TMP_KILL_GRACE:-5}"
  case "$grace" in ''|*[!0-9]*) grace=5 ;; esac
  [ "$grace" -gt 60 ] && grace=60

  local pid start label
  # ① TERM（只对记录过且 starttime 对得上的 pid）
  while IFS=$'\t' read -r pid start label; do
    [ -n "$pid" ] || continue
    _tmp_root_proc_alive "$pid" "$start" || continue
    kill -TERM "$pid" 2>/dev/null || true
    # --break=nokill：把「按命令行匹配」这个旧缺陷形状放回来（自检时由夹具显式给出受害 pid，
    # 绝不做真正的 pkill/模式匹配 —— 我们只打自己 spawn 的进程）。
    if [ "${TMP_ROOT_BREAK:-}" = "nokill" ] && [ -n "${TEAM_TMP_BREAK_VICTIM:-}" ]; then
      kill -TERM "$TEAM_TMP_BREAK_VICTIM" 2>/dev/null || true
    fi
  done <"$pf"

  # ② 宽限期内等它自己走；不走 → KILL
  local i alive
  i=0
  while [ "$i" -lt $((grace * 5)) ]; do
    alive=0
    while IFS=$'\t' read -r pid start label; do
      [ -n "$pid" ] || continue
      _tmp_root_proc_alive "$pid" "$start" && alive=1
    done <"$pf"
    [ "$alive" = "0" ] && break
    sleep 0.2
    i=$((i + 1))
  done
  while IFS=$'\t' read -r pid start label; do
    [ -n "$pid" ] || continue
    _tmp_root_proc_alive "$pid" "$start" || continue
    kill -KILL "$pid" 2>/dev/null || true
  done <"$pf"
  return 0
}

_tmp_root_remove_owned() {
  local f; f="$(tmp_root_ledger)"
  [ -f "$f" ] || return 0
  local my_start; my_start="$(_tmp_root_proc_start $$ 2>/dev/null || true)"
  local keep="${TEAM_TMP_KEEP:-0}"
  local path pid start kind created run
  while IFS=$'\t' read -r path pid start kind created run; do
    case "$path" in ''|'#'*) continue ;; esac
    [ "$pid" = "$$" ] || continue                       # 别的进程（nested run）的根由它自己收
    if [ -n "$my_start" ] && [ "$start" != "unknown" ] && [ "$start" != "$my_start" ]; then
      continue                                          # pid 复用：不是我的根
    fi
    [ -d "$path" ] || continue
    # 调用方拥有生命周期的根（tmp_root_detach）：不替它收
    grep -q '^detached=1$' "$path/.teamsmith-tmp" 2>/dev/null && continue
    if [ "$keep" = "1" ]; then
      # --break=nokeeep：模拟「静默保留」（旧的死旋钮行为）——打印这条被守门断言钉住
      [ "${TMP_ROOT_BREAK:-}" = "nokeeep" ] || printf '保留临时根：%s（TEAM_TMP_KEEP=1）\n' "$path"
      continue
    fi
    # 夹具模式红侧（夹具泄漏断言用）：故意不回收，让门禁必须报红（只在 TEAM_SMOKE_FIXTURE=1 下生效）
    if [ "${TEAM_SMOKE_FIXTURE:-0}" = "1" ] && [ "${TEAM_TMP_HYGIENE_FLIP:-}" = "leak" ]; then
      printf 'FLIP(leak)：故意不回收 %s\n' "$path"
      continue
    fi
    # --break=noreap：自检的翻转开关（看门断言必须因此变红）
    [ "${TMP_ROOT_BREAK:-}" = "noreap" ] && continue
    rm -rf -- "$path" 2>/dev/null || _tmp_root_err "删不掉 $path"
  done <"$f"
  return 0
}

# owner 进程退出时收走台账（nested run 不碰别人的台账）
_tmp_root_drop_ledger_if_owner() {
  local f; f="$(tmp_root_ledger)"
  [ -f "$f" ] || return 0
  local owner
  owner="$(sed -n '1s/.* owner=\([0-9]*\).*/\1/p' "$f" 2>/dev/null | head -1)"
  [ "$owner" = "$$" ] || return 0
  [ "${TEAM_TMP_KEEP:-0}" = "1" ] && { printf '保留 run 台账：%s\n' "$f"; return 0; }
  rm -f -- "$f" 2>/dev/null || true
  return 0
}

# 正常退出 / INT 都走这里（TERM 走未捕获致命信号 → EXIT trap 的路径，见 _tmp_root_install_traps）：
# 发信号（只对记录的 pid）→ 收根 → 收台账。
tmp_root_reap_all() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0      # 子 shell 的 EXIT 不替主 shell 收（项目既有纪律）
  _tmp_root_signal_tracked
  _tmp_root_remove_owned
  rm -f -- "$(tmp_root_pidfile)" 2>/dev/null || true
  _tmp_root_drop_ledger_if_owner
  return 0
}

tmp_root_on_signal() { # <INT|TERM>
  [ "${TMP_ROOT_IN_SIGNAL:-0}" = "1" ] && return 0
  TMP_ROOT_IN_SIGNAL=1
  tmp_root_reap_all
  case "${1:-TERM}" in
    INT) exit 130 ;;
    *)   exit 143 ;;
  esac
}

# 门禁用：列出台账里**还活着**的根（path<TAB>pid<TAB>kind<TAB>size_KB<TAB>files）
tmp_root_ledger_survivors() {
  local f; f="$(tmp_root_ledger)"
  [ -f "$f" ] || return 0
  local path pid start kind created run kb files
  while IFS=$'\t' read -r path pid start kind created run; do
    case "$path" in ''|'#'*) continue ;; esac
    [ -d "$path" ] || continue
    kb="$(du -sk "$path" 2>/dev/null | awk '{print $1}' || printf 0)"
    files="$(find "$path" 2>/dev/null | wc -l | tr -d ' ' || printf 0)"
    printf '%s\t%s\t%s\t%s\t%s\n' "$path" "$pid" "${kind:-?}" "${kb:-0}" "${files:-0}"
  done <"$f"
  return 0
}

# ---------------------------------------------------------------- 自检
# `--break=<stage>`：把某条规则变回有缺陷的旧行为，守门断言必须变红（翻转）。
_tmp_root_selftest() {
  local break_stage="" a
  for a in "$@"; do
    case "$a" in
      --break=*) break_stage="${a#--break=}" ;;
      -h|--help)
        printf '用法：bash %s --self-test [--break=nokill|nokeeep|notmpdir|noreap]\n' "${BASH_SOURCE[0]}"
        return 0 ;;
      *) _tmp_root_err "不认识的自检参数 [$a]"; return 2 ;;
    esac
  done
  TMP_ROOT_BREAK="$break_stage"; export TMP_ROOT_BREAK
  local PASS=0 FAIL=0
  st_ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
  st_bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }

  local self_path
  self_path="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  local st_dir
  st_dir="$(mktemp -d "$(tmp_root_base)/teamsmith-libselftest.XXXXXX" 2>/dev/null)" || {
    _tmp_root_err "自检建不出临时目录"; return 3; }
  trap "rm -rf -- '$st_dir'" EXIT    # 路径要内嵌：trap 在函数返回后执行，local 变量那时已经不在了

  printf '\n\033[1m== tmp-root.sh 自检 ==\033[0m（break=%s）\n' "${break_stage:-none}"

  # ① 创建：路径、家族名、标记、台账
  export TMPDIR="$st_dir"
  local r; r="$(tmp_root_create selftest)"
  case "$r" in "$st_dir"/teamsmith-selftest.*) st_ok "根建在 \${TMPDIR} 下并且名字在 owned 家族（$r）" ;;
               *) st_bad "根的路径/名字不对（[$r]，期望 $st_dir/teamsmith-selftest.*）" ;; esac
  if [ -f "$r/.teamsmith-tmp" ] && grep -q "^kind=selftest$" "$r/.teamsmith-tmp" \
     && grep -q "^pid=$$$" "$r/.teamsmith-tmp" && grep -q '^run=' "$r/.teamsmith-tmp"; then
    st_ok "owner 标记写全（kind / pid / start / boot / run / created）"
  else
    st_bad "owner 标记缺字段：$(tr '\n' ' ' <"$r/.teamsmith-tmp" 2>/dev/null)"
  fi
  if [ -f "$(tmp_root_ledger)" ] && grep -qF "$r	$$" "$(tmp_root_ledger)"; then
    st_ok "run 台账里有这一条（$(tmp_root_ledger)）"
  else
    st_bad "run 台账里没有这条根"
  fi

  # ② notmpdir：写死 /tmp 的路径不许被当成合规根
  if tmp_root_path_ok /tmp/teamsmith-whatever.1234; then
    st_bad "写死 /tmp 的路径被当成合规根（notmpdir 规则失效）"
  else
    st_ok "写死 /tmp 的路径被拒（tmp_root_path_ok 非 0）"
  fi
  if tmp_root_path_ok "$st_dir/teamsmith-x.1234"; then
    st_ok "\${TMPDIR} 下的家族路径被接受"
  else
    st_bad "\${TMPDIR} 下的家族路径被误拒"
  fi

  # ③ 正常回收：子进程创建 → 退出 → 根消失
  local child_root
  child_root="$( env TMPDIR="$st_dir" bash -c '
      . "'"$self_path"'"
      tmp_root_create reaptest' )"
  if [ -n "$child_root" ] && [ ! -e "$child_root" ]; then
    st_ok "子进程正常退出后根已回收（$child_root 不在了）"
  else
    st_bad "子进程退出后根还在：[$child_root]"
  fi

  # ③b detach：生命周期归调用方的根不能被创建者的 trap 收掉
  local det_root
  det_root="$( env TMPDIR="$st_dir" bash -c '
      . "'"$self_path"'"
      r="$(tmp_root_create detachtest)"
      tmp_root_detach "$r"
      printf "%s" "$r"' )"
  if [ -n "$det_root" ] && [ -d "$det_root" ] && grep -q '^detached=1$' "$det_root/.teamsmith-tmp" 2>/dev/null; then
    st_ok "detach 过的根活过了创建者退出（$det_root）"
  else
    st_bad "detach 的根被收了或没标记（[$det_root]）"
  fi
  rm -rf -- "$det_root" 2>/dev/null || true

  # ④ nokeeep：TEAM_TMP_KEEP=1 必须**打印**路径（静默保留是缺陷）
  local keep_out keep_root
  keep_out="$( env TMPDIR="$st_dir" TEAM_TMP_KEEP=1 bash -c '
      . "'"$self_path"'"
      r="$(tmp_root_create keeptest)"
      printf "ROOT=%s\n" "$r"
    ' 2>&1 )"
  keep_root="$(printf '%s\n' "$keep_out" | sed -n 's/^ROOT=//p' | head -1)"
  case "$keep_out" in
    *"保留临时根：$keep_root"*) st_ok "TEAM_TMP_KEEP=1 打印了保留路径" ;;
    *) st_bad "TEAM_TMP_KEEP=1 没有打印保留路径（输出：$(printf '%s' "$keep_out" | tr '\n' '|')）" ;;
  esac
  if [ -n "$keep_root" ] && [ -d "$keep_root" ]; then
    st_ok "TEAM_TMP_KEEP=1 真的把根留下了（$keep_root）"
  else
    st_bad "TEAM_TMP_KEEP=1 的根不在（[$keep_root]）"
  fi
  rm -rf -- "$keep_root" 2>/dev/null || true

  # ⑤ nokill：只对记录的 pid 发信号 —— 同 argv 的无关 sleep 必须活着
  local arg="teamsmith-nokill-$$" tracked_pid="" victim_pid=""
  # 两个 argv 完全一样的 sleep（pid 不同）：一个被 track，一个是「调用者的」
  sleep 300 & tracked_pid=$!
  sleep 300 & victim_pid=$!
  sleep 0.2
  # 回收必须在**独立进程**里跑（子 shell 的 EXIT 按项目纪律不替主 shell 收，BASHPID != $$ → no-op）
  env TMPDIR="$st_dir" TEAM_TMP_BREAK_VICTIM="$victim_pid" TRACKED_PID="$tracked_pid" bash -c '
      . "'"$self_path"'"
      _r="$(tmp_root_create nokilltest)"
      tmp_root_track_pid "$TRACKED_PID" anchor
      tmp_root_reap_all
      printf "ROOT=%s\n" "$_r"
    ' >"$st_dir/nokill.out" 2>&1
  sleep 0.3
  if _tmp_root_proc_alive "$tracked_pid"; then
    st_bad "记录过的 anchor（pid $tracked_pid）没被回收"
  else
    st_ok "记录过的 anchor 被回收（只对它发了信号）"
  fi
  if _tmp_root_proc_alive "$victim_pid"; then
    st_ok "同 argv 的无关 sleep 活着（cleanup 没有按命令行匹配）"
  else
    st_bad "无关的 sleep 被信号命中（cleanup 做了命令行匹配 —— D37 违规）"
  fi
  kill -KILL "$tracked_pid" "$victim_pid" 2>/dev/null || true
  wait "$tracked_pid" "$victim_pid" 2>/dev/null || true

  # ⑥ term：TERM 中途到达 → 根消失 + 记录的 anchor 不再存在
  local term_out="$st_dir/term.out" term_pid="" term_root="" term_anchor=""
  ( export TMPDIR="$st_dir"; exec bash -c '
      . "'"$self_path"'"
      r="$(tmp_root_create termtest)"
      sleep 300 & a=$!
      tmp_root_track_pid "$a" anchor
      printf "ROOT=%s\nANCHOR=%s\n" "$r" "$a"
      wait' ) >"$term_out" 2>&1 &
  term_pid=$!
  local _i=0
  while [ "$_i" -lt 50 ]; do
    grep -q '^ANCHOR=' "$term_out" 2>/dev/null && break
    sleep 0.1; _i=$((_i + 1))
  done
  term_root="$(sed -n 's/^ROOT=//p' "$term_out" | head -1)"
  term_anchor="$(sed -n 's/^ANCHOR=//p' "$term_out" | head -1)"
  if [ -z "$term_root" ] || [ -z "$term_anchor" ]; then
    st_bad "TERM 用例的子进程没报出根/锚点 pid（$(tr '\n' '|' <"$term_out")）"
  else
    kill -TERM "$term_pid" 2>/dev/null || true
    _i=0
    while [ "$_i" -lt 100 ] && kill -0 "$term_pid" 2>/dev/null; do sleep 0.1; _i=$((_i + 1)); done
    wait "$term_pid" 2>/dev/null || true
    if [ ! -e "$term_root" ]; then
      st_ok "TERM 后根在宽限期内消失（$term_root）"
    else
      st_bad "TERM 后根还在：$term_root"
    fi
    if _tmp_root_proc_alive "$term_anchor"; then
      st_bad "TERM 后记录的 anchor（pid $term_anchor）还活着"
    else
      st_ok "TERM 后记录的 anchor 不再存在（pid $term_anchor）"
    fi
  fi
  kill -KILL "$term_pid" "$term_anchor" 2>/dev/null || true
  rm -rf -- "$term_root" 2>/dev/null || true

  # ⑥b 前台长命令里收到 TERM：默认动作杀掉 shell → EXIT trap 回收（**不能**装 TERM 陷阱，否则
  #    bash 要等前台命令结束才跑陷阱，回收会晚到）。这条钉住「长命令里也必须及时回收」。
  local fg_out="$st_dir/termfg.out" fg_pid="" fg_root=""
  ( export TMPDIR="$st_dir"; exec bash -c '
      . "'"$self_path"'"
      r="$(tmp_root_create termfg)"
      printf "ROOT=%s\n" "$r"
      sleep 30' ) >"$fg_out" 2>&1 &
  fg_pid=$!
  _i=0
  while [ "$_i" -lt 50 ]; do
    grep -q '^ROOT=' "$fg_out" 2>/dev/null && break
    sleep 0.1; _i=$((_i + 1))
  done
  fg_root="$(sed -n 's/^ROOT=//p' "$fg_out" | head -1)"
  if [ -z "$fg_root" ]; then
    st_bad "前台长命令 TERM 用例没报出根（$(tr '\n' '|' <"$fg_out" 2>/dev/null)）"
  else
    kill -TERM "$fg_pid" 2>/dev/null || true
    _i=0
    while [ "$_i" -lt 25 ] && kill -0 "$fg_pid" 2>/dev/null; do sleep 0.1; _i=$((_i + 1)); done
    if ! kill -0 "$fg_pid" 2>/dev/null && [ ! -e "$fg_root" ]; then
      st_ok "前台长命令里 TERM：shell 立即退出且根已回收（$((_i * 100))ms 内）"
    else
      st_bad "前台长命令里 TERM 没有及时回收（alive=$(kill -0 "$fg_pid" 2>/dev/null && echo yes || echo no) root=$([ -e "$fg_root" ] && echo 在 || echo 没了)）"
    fi
  fi
  kill -KILL "$fg_pid" 2>/dev/null || true
  rm -rf -- "$fg_root" 2>/dev/null || true

  printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
  [ "$FAIL" -eq 0 ] && { printf '\033[32mtmp-root.sh 自检全绿\033[0m\n'; return 0; }
  printf '\033[31mtmp-root.sh 自检有失败项（break=%s）\033[0m\n' "${break_stage:-none}"
  return 1
}

# ---------------------------------------------------------------- 入口
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-}" in
    --self-test) shift; _tmp_root_selftest "$@" ;;
    -h|--help|"") printf '用法：bash %s --self-test [--break=<stage>]\n' "${BASH_SOURCE[0]}" ;;
    *) printf 'tmp-root.sh：只支持 --self-test（被夹具 source 用）\n' >&2; exit 2 ;;
  esac
else
  # source 时：装 INT/TERM（EXIT 只在调用者还没有 EXIT trap 时装兜底）
  _tmp_root_install_traps
fi
