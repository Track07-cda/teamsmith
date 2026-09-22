#!/usr/bin/env bash
# load-experiment.sh — P48's safe primitives for machine-side load experiments (freeze, load, probe)
# and the falsifiable guard test of the rule they must obey.
#
#   bash skills/teamsmith/tests/load-experiment.sh --guard-test          # the rule's own guard test
#   bash skills/teamsmith/tests/load-experiment.sh freeze <s> <owner> <pid>…   # SIGSTOP a subtree
#   bash skills/teamsmith/tests/load-experiment.sh storm <workers> <s> [tree]  # owned fork/exec load
#   bash skills/teamsmith/tests/load-experiment.sh burn <n> <s>                # owned CPU load
#   bash skills/teamsmith/tests/load-experiment.sh probe <rounds> [tree]       # code-independent ms
#   bash skills/teamsmith/tests/load-experiment.sh private-root <label>        # private temp root
#   bash skills/teamsmith/tests/load-experiment.sh socket-name <label>         # private tmux socket
#
# The rule: `verification#A load experiment signals only the processes it started` (the 2026-09-22
# incident — a host-wide **name pattern** was used to pick signal targets and froze the PM's P42
# verification fixture, and two other seats' panels besides; the rule came out of the brief's append):
#   1. ownership — a signal target must be the owner PID the experiment itself spawned, or a
#      descendant of it (the ppid chain is walked through /proc/<pid>/stat). There is **no code
#      path in this file that selects a target by command line, name or any other host-wide
#      pattern**: a PID is required, and a pattern-shaped, empty, non-numeric or self target is
#      refused with exit **2 before any signal is sent**.
#   2. release — every `SIGSTOP` is paired with a `CONT` from the `EXIT/INT/TERM` trap, so a script
#      killed mid-hold leaves nothing in state `T`; the hold is `sleep & wait`, because a foreground
#      `sleep` defers bash's traps until it returns.
#   3. owned load — `storm`/`burn` start their own workers, count them and reclaim them on exit;
#      whole-machine load is never another seat's processes.
#   4. private fixtures — `private-root` and `socket-name` mint this experiment's own temp root and
#      tmux socket name, so two seats' experiments coexist.
# Exit: 0 the requested experiment ran (or the guard test is green) | 1 a guard side was wrong |
#       2 a target or the usage was refused (nothing was signalled) | 3 the fixture could not run.
set -uo pipefail

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
self="${BASH_SOURCE[0]}"

le_usage() {
  printf 'usage: load-experiment.sh --guard-test | freeze <s> <owner_pid> <pid>… | storm <workers> <s> [tree] | burn <n> <s> | probe <rounds> [tree] | private-root <label> | socket-name <label>\n' >&2
}
le_load1() { cut -d' ' -f1 /proc/loadavg 2>/dev/null || printf '?'; }
le_ppid() { awk '{print $4}' "/proc/$1/stat" 2>/dev/null || true; }
le_state() { ps -o stat= -p "$1" 2>/dev/null | head -1 | cut -c1; }   # T = stopped, S = sleeping, '' = gone
le_probe_ms() { # <rounds> [tree] — the code-independent probe, ms per round (P44's probe.sh shape)
  local n="${1:-5}" tree="${2:-$PWD}" i t0
  t0="$(date +%s%3N)"
  for i in $(seq 1 "$n"); do
    python3 -c 'pass' >/dev/null 2>&1
    bash -c 'true' >/dev/null 2>&1
    git -C "$tree" rev-parse --quiet HEAD >/dev/null 2>&1
  done
  printf '%s\n' $(( ($(date +%s%3N) - t0) / n ))
}

# ── ownership and the release trap ───────────────────────────────────────────────────────────────
le_is_owned() { # <pid> <owner_pid> → 0 when <pid> is the owner or a descendant of it
  local p="$1" owner="$2" hops=0
  while [ -n "$p" ] && [ "$p" != "0" ] && [ "$hops" -lt 64 ]; do
    [ "$p" = "$owner" ] && return 0
    p="$(le_ppid "$p")"; hops=$((hops + 1))
  done
  return 1
}

LE_FROZEN=()
LE_SPAWNED=()
le_cleanup() { # one trap for both duties: CONT everything stopped, reclaim everything spawned
  [ "${BASHPID:-$$}" = "$$" ] || return 0
  local p
  for p in ${LE_FROZEN[@]+"${LE_FROZEN[@]}"}; do kill -CONT "$p" 2>/dev/null || true; done
  if [ "${#LE_FROZEN[@]}" -gt 0 ]; then
    printf 'load-experiment: released %s stopped PID(s)\n' "${#LE_FROZEN[@]}" >&2
    LE_FROZEN=()
  fi
  for p in ${LE_SPAWNED[@]+"${LE_SPAWNED[@]}"}; do kill -TERM "$p" 2>/dev/null || true; done
  LE_SPAWNED=()
}
trap le_cleanup EXIT INT TERM

# ── freeze: SIGSTOP/SIGCONT on the experiment's own subtree ──────────────────────────────────────
le_cmd_freeze() { # <seconds> <owner_pid> <pid>…
  local secs="${1:-}" owner="${2:-}" p
  [ -n "$secs" ] && [ -n "$owner" ] && [ "$#" -gt 2 ] || { printf 'load-experiment: freeze needs <seconds> <owner_pid> <pid>…\n' >&2; return 2; }
  case "$secs" in ''|*[!0-9]*) printf 'load-experiment: refusing non-numeric seconds [%s]\n' "$secs" >&2; return 2 ;; esac
  case "$owner" in ''|*[!0-9]*) printf 'load-experiment: refusing non-numeric owner [%s]\n' "$owner" >&2; return 2 ;; esac
  shift 2
  # Validation happens BEFORE any signal: every target must be a live PID in the owner's subtree.
  for p in "$@"; do
    case "$p" in
      ''|*[!0-9]*)
        printf 'load-experiment: refusing target [%s] — a target is a PID, never a pattern; no host-wide name/command matching exists in this file\n' "$p" >&2
        return 2 ;;
    esac
    if [ "$p" = "$$" ]; then
      printf 'load-experiment: refusing to signal itself (%s)\n' "$$" >&2
      return 2
    fi
    if ! le_is_owned "$p" "$owner"; then
      printf 'load-experiment: refusing %s — not the owner (%s) nor a descendant of it; this experiment signals only what it started\n' "$p" "$owner" >&2
      return 2
    fi
  done
  for p in "$@"; do
    if kill -STOP "$p" 2>/dev/null; then LE_FROZEN+=("$p")
    else printf 'load-experiment: cannot stop %s\n' "$p" >&2; fi
  done
  if [ "${#LE_FROZEN[@]}" -eq 0 ]; then
    printf 'load-experiment: freeze failed — no target could be stopped\n' >&2
    return 2
  fi
  printf 'load-experiment: froze [%s] for %ss (loadavg %s, probe %sms)\n' \
    "${LE_FROZEN[*]}" "$secs" "$(le_load1)" "$(le_probe_ms 5)"
  # The hold must stay interruptible: `sleep & wait` lets the EXIT/INT/TERM trap run immediately.
  sleep "$secs" & local holder=$!
  wait "$holder" 2>/dev/null || true
  return 0
}

# ── owned load: storm (fork/exec shape) and burn (CPU shape) ─────────────────────────────────────
le_cmd_storm() { # <workers> <seconds> [tree]
  local workers="${1:-8}" secs="${2:-60}" tree="${3:-$PWD}" i p start n iters=0 tmpd
  case "$workers" in ''|*[!0-9]*) printf 'load-experiment: refusing non-numeric workers [%s]\n' "$workers" >&2; return 2 ;; esac
  case "$secs" in ''|*[!0-9]*) printf 'load-experiment: refusing non-numeric seconds [%s]\n' "$secs" >&2; return 2 ;; esac
  start="$(date +%s)"
  tmpd="$(mktemp -d "${TMPDIR:-/tmp}/load-experiment.storm.XXXXXX")" || return 3
  le_storm_worker() {
    local n=0
    while [ $(( $(date +%s) - start )) -lt "$secs" ]; do
      git -C "$tree" status --porcelain >/dev/null 2>&1
      python3 -c 'import json; json.dumps([1,2,3])' >/dev/null 2>&1
      bash -c 'true' >/dev/null 2>&1
      n=$((n + 1))
      sleep 0.02
    done
    printf '%s\n' "$n"
  }
  for i in $(seq 1 "$workers"); do
    le_storm_worker > "$tmpd/w$i.iters" & p="$!"; LE_SPAWNED+=("$p")
  done
  for p in ${LE_SPAWNED[@]+"${LE_SPAWNED[@]}"}; do wait "$p" 2>/dev/null || true; done
  LE_SPAWNED=()
  for i in $(seq 1 "$workers"); do [ -f "$tmpd/w$i.iters" ] && iters=$((iters + $(cat "$tmpd/w$i.iters" 2>/dev/null || echo 0))); done
  local el=$(( $(date +%s) - start ))
  printf 'storm: workers=%s seconds=%s iterations=%s rate=%.1f iters/s (each = git+python3+bash; loadavg %s)\n' \
    "$workers" "$el" "$iters" "$(awk -v i="$iters" -v e="$el" 'BEGIN{print (e>0?i/e:0)}')" "$(le_load1)"
  rm -rf "$tmpd"
  return 0
}

le_cmd_burn() { # <n> <seconds>
  local n="${1:-24}" secs="${2:-60}" i p end
  case "$n" in ''|*[!0-9]*) printf 'load-experiment: refusing non-numeric count [%s]\n' "$n" >&2; return 2 ;; esac
  case "$secs" in ''|*[!0-9]*) printf 'load-experiment: refusing non-numeric seconds [%s]\n' "$secs" >&2; return 2 ;; esac
  end=$(( $(date +%s) + secs ))
  for i in $(seq 1 "$n"); do
    ( while [ "$(date +%s)" -lt "$end" ]; do :; done ) & p="$!"; LE_SPAWNED+=("$p")
  done
  printf 'burn: %s owned CPU burners for %ss (loadavg %s)\n' "$n" "$secs" "$(le_load1)"
  for p in ${LE_SPAWNED[@]+"${LE_SPAWNED[@]}"}; do wait "$p" 2>/dev/null || true; done
  LE_SPAWNED=()
  return 0
}

# ── the private-fixture convention ───────────────────────────────────────────────────────────────
le_cmd_private_root() { # <label> → a fresh private temp root on stdout
  local label="${1:-exp}"
  case "$label" in ''|*[!A-Za-z0-9._-]*) printf 'load-experiment: invalid label [%s]\n' "$label" >&2; return 2 ;; esac
  mktemp -d "${TMPDIR:-/tmp}/load-experiment-$label.XXXXXX" || return 3
}
le_cmd_socket_name() { # <label> → a private tmux socket name (never the default server)
  local label="${1:-exp}"
  case "$label" in ''|*[!A-Za-z0-9._-]*) printf 'load-experiment: invalid label [%s]\n' "$label" >&2; return 2 ;; esac
  printf 'le-%s-%s\n' "$label" "$$"
}

# ── the guard test: every side of the rule, falsifiable ──────────────────────────────────────────
le_guard_test() {
  local pass=0 fail=0
  le_skipped=0
  le_ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; pass=$((pass + 1)); }
  le_bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; fail=$((fail + 1)); }
  printf '\033[1m== load-experiment 守卫自检（只发自己 spawn 的信号）==\033[0m\n'

  printf '\n== 1 · 绿侧：自有子进程可冻结、hold 结束即释放 ==\n'
  sleep 60 & local own=$!
  bash "$self" freeze 2 $$ "$own" >/dev/null 2>&1 & local bpid=$!
  sleep 0.8
  [ "$(le_state "$own")" = "T" ] && le_ok "自有子进程在 hold 期间是 T（$$ → $own）" \
    || le_bad "自有子进程没有被停住（state '$(le_state "$own")'）"
  wait "$bpid" 2>/dev/null
  [ "$(le_state "$own")" != "T" ] && le_ok "hold 正常结束时已释放（state '$(le_state "$own")'）" \
    || le_bad "hold 结束后还停在 T（CONT 释放没跑）"
  kill "$own" 2>/dev/null

  printf '\n== 2 · hold 可中断：TERM / INT 中途被杀也必须释放（不留 T）==\n'
  # 非交互 shell 的后台任务继承 SIGINT=SIG_IGN，那种环境下 INT 陷阱根本不会跑；要真收到
  # SIGINT 就得先把处置复位（env --default-signal，coreutils ≥ 8.31）。缺这个能力时这一面
  # **可见跳过**，不假绿也不假红。
  local sig own2 bpid2 env_ds=""
  if env --default-signal=INT true 2>/dev/null; then env_ds=1; fi
  for sig in TERM INT; do
    local launcher=(bash)
    if [ "$sig" = "INT" ]; then
      if [ -n "$env_ds" ]; then launcher=(env --default-signal=INT bash)
      else printf '  \033[33mSKIP\033[0m INT 中途被杀这一面：env --default-signal 不可用（后台任务继承 SIG_IGN，INT 陷阱收不到）\n'; le_skipped=$((le_skipped + 1)); continue; fi
    fi
    sleep 60 & own2=$!
    "${launcher[@]}" "$self" freeze 30 $$ "$own2" >/dev/null 2>&1 & bpid2=$!
    sleep 0.8
    if [ "$(le_state "$own2")" = "T" ]; then le_ok "hold 中途自有子进程是 T（信号 $sig）"
    else le_bad "hold 中途没停住（信号 $sig）"; fi
    kill -"$sig" "$bpid2" 2>/dev/null
    sleep 0.6
    [ "$(le_state "$own2")" != "T" ] && le_ok "$sig 中途被杀也释放了（state '$(le_state "$own2")'）" \
      || le_bad "$sig 留下了 T —— 前台 sleep 会推迟 trap；必须 sleep & wait"
    kill "$own2" 2>/dev/null
  done

  printf '\n== 3 · 红侧：不是自己启动的进程在发信号之前就被拒绝 ==\n'
  sleep 60 & local owner=$!
  if command -v setsid >/dev/null 2>&1; then setsid sleep 60 & else sleep 60 & fi
  local foreign=$!
  sleep 0.2
  local out rc
  out="$(bash "$self" freeze 5 "$owner" "$foreign" 2>&1)"; rc=$?
  [ "$rc" -eq 2 ] && le_ok "非自有目标被拒绝（status 2）" || le_bad "期望 status 2，实际 $rc"
  printf '%s' "$out" | grep -q 'not the owner' && le_ok "拒绝理由点名归属：$(printf '%s' "$out" | tail -1)" \
    || le_bad "拒绝理由没有点名归属"
  [ "$(le_state "$foreign")" != "T" ] && le_ok "非自有进程没被动过（state '$(le_state "$foreign")'）" \
    || le_bad "非自有进程被停住了"
  kill "$owner" "$foreign" 2>/dev/null

  printf '\n== 4 · 红侧：模式形状 / 空列表 / 非数字 / 自己 都在发信号前被拒绝 ==\n'
  out="$(bash "$self" freeze 5 $$ 'panel.js.*--root /tmp/panel-p21' 2>&1)"; rc=$?
  [ "$rc" -eq 2 ] && le_ok "模式形状的目标被拒绝（status 2：这个文件里没有主机级名字/命令行匹配）" \
    || le_bad "模式目标期望 status 2，实际 $rc"
  printf '%s' "$out" | grep -q 'never a pattern' && le_ok "拒绝行说明原因是「目标必须是 PID，不是模式」" \
    || le_bad "拒绝行没有说明模式不可用"
  out="$(bash "$self" freeze 5 2>&1)"; rc=$?
  [ "$rc" -eq 2 ] && le_ok "空目标列表被拒绝（status 2）" || le_bad "空列表期望 status 2，实际 $rc"
  out="$(bash "$self" freeze 5 $$ '' 2>&1)"; rc=$?
  [ "$rc" -eq 2 ] && le_ok "空 PID 被拒绝（status 2）" || le_bad "空 PID 期望 status 2，实际 $rc"
  rc=0; bash -c 'exec bash "$1" freeze 5 "$$" "$$"' _ "$self" >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 2 ] && le_ok "给自己发信号被拒绝（status 2）" || le_bad "自信号期望 status 2，实际 $rc"

  printf '\n== 5 · 结构钉：文件里没有主机级模式选择，只有 PID ==\n'
  # 模式自己不能以明文出现在被 grep 的文件里（否则这条钉会匹配到自己），所以用拆分字面量拼。
  local pat
  pat='p'"gre"'p|p'"kil"'l|pid'"of"
  if grep -qE "(^|[^a-zA-Z_])($pat)([^a-zA-Z_]|$)" "$self"; then
    le_bad "文件里出现了主机级名字/命令行选择（$pat）—— 这种能力本身就是违规的"
  else
    le_ok "没有主机级名字/命令行选择：目标只能作为 PID 传进来（模式形状在发信号前即拒绝）"
  fi

  printf '\n== 6 · 私有夹具：两套实验各有各的临时根与 socket 名 ==\n'
  local r1 r2 s1 s2
  r1="$(bash "$self" private-root a)"; r2="$(bash "$self" private-root b)"
  if [ -d "$r1" ] && [ -d "$r2" ] && [ "$r1" != "$r2" ] && [ -w "$r1" ] && [ -w "$r2" ]; then
    le_ok "私有临时根可写且互不相同（$(basename "$r1") / $(basename "$r2")）"
  else
    le_bad "私有临时根不对（$r1 / $r2）"
  fi
  rm -rf "$r1" "$r2"
  s1="$(bash "$self" socket-name a)"; s2="$(bash "$self" socket-name b)"
  if [ "$s1" != "$s2" ] && [ "$s1" != "default" ] && [ "$s2" != "default" ]; then
    le_ok "私有 socket 名带实验标签与 PID，且不是默认 server（$s1 / $s2）"
  else
    le_bad "私有 socket 名不对（$s1 / $s2）"
  fi

  printf '\n== 结果 ==  ✓ %d  ✗ %d  SKIP %d\n' "$pass" "$fail" "${le_skipped:-0}"
  [ "$fail" -eq 0 ] || return 1
  return 0
}

cmd="${1:-}"; shift 2>/dev/null || true
case "$cmd" in
  --guard-test|guard-test) le_guard_test ;;
  freeze)   le_cmd_freeze "$@" ;;
  storm)    le_cmd_storm "$@" ;;
  burn)     le_cmd_burn "$@" ;;
  probe)    le_probe_ms "${1:-5}" "${2:-$PWD}" ;;
  private-root) le_cmd_private_root "$@" ;;
  socket-name)  le_cmd_socket_name "$@" ;;
  *) le_usage; exit 2 ;;
esac
