#!/usr/bin/env bash
# bounded-spin.sh — 夹具的后台「看门 / 轮询」进程的**唯一实现**（infra · 实现：P313）
#
# 现场（2026-10-18，PM 实测）：`/tmp` 显示 100% 满（64 M），`du` 只算出 9 G，`df` 说用了 15 G ——
# 差额是「**已删除但仍被持有**」的文件：78 个同一形状的进程合计持有 **11.98 GB**，运行 2 天以上：
#
#   bash -c 'log="$1"; trap "" TERM; while :; do date +%s >> "$log"; sleep 0.2; done' _ <log>
#
# 它们的父进程（一次被打断的夹具运行）早已不在、写入的目标（夹具的临时根）早已被删，而循环
# **忽略 TERM**、**从不检查父进程**、**没有上限** → 任何一次被打断的夹具运行都会永久泄漏一个。
#
# 契约（三条，缺一条就是缺陷）：
#   ① 响应 TERM：`trap` 记录收到 TERM 然后**退出**；绝不 `trap "" TERM`
#      （只有「忽略 TERM」本身是被测对象时才用 BOUNDED_SPIN_IGNORE_TERM=1，并写清理由）；
#   ② 每轮检查父进程：`while kill -0 "$parent"`，父没了就自己退（被打断的运行不留孤儿）；
#   ③ 硬上限：最大运行秒数 + 最大写入字节，到点退出并留**一行**说明（到点不是静默消失）；
#      另外：写目标已经不在了（夹具的临时根被清理）也立即退出 ——「往已删除的文件里继续写」
#      正是上一次泄漏的形状（df 与 du 的差额就是这么来的）。
#
# 用法（夹具里）：
#   . "$SELF_DIR/lib/bounded-spin.sh"
#   bounded_spin <interval_s> <cap_s> <cap_bytes|-> <log|-> [<parent_pid>] &
#     log = `-`   → 只自旋、不写日志（此时 cap_bytes 用 `-`）
#     父 pid 默认 `$PPID`；**经子 shell / setsid / tmux 间接拉起时**要显式给一个活到最后的
#     supervisor pid（否则父一退它就跟着退，那就成了它自己的缺陷）。
#   BOUNDED_SPIN_TERM="<snippet>"   TERM 到达时先跑这段（记录证据），然后退出
#   BOUNDED_SPIN_IGNORE_TERM=1      故意忽略 TERM（只给「忽略 TERM 的被测对象」，仍受 ②③ 约束）
#
# 退出行（写进日志尾部 + stderr 各一行）：
#   bounded-spin：退出（<原因>）· pid=<pid> · 父=<pid> · 轮=<n> · 用时=<s>s · 已写=<bytes>B

BS_LIB=1

# 父进程还活着吗？僵尸按「不在」算（它已经不在运行，只是还没被回收）。
# 没有 /proc 的平台退回 kill -0（拿不到僵尸判定，但边界仍在）。
_bs_parent_alive() { # <pid>
  local pid="${1:-}" st
  case "$pid" in ''|0|*[!0-9]*) return 1 ;; esac
  if [ ! -d /proc/1 ]; then kill -0 "$pid" 2>/dev/null; return; fi
  [ -r "/proc/$pid/stat" ] || return 1
  st="$(awk '{ sub(/^.*\) /, ""); print $1 }' "/proc/$pid/stat" 2>/dev/null || true)"
  [ "$st" = "Z" ] && return 1
  return 0
}

# 收口：留一行说明再退。局部变量（parent / rounds / t0 / bytes / log）由 bounded_spin 定义，
# bash 的动态作用域让这里读得到 —— 改这个函数前先确认那几个变量名没被换掉。
_bs_exit() { # <原因>
  local reason="$1" msg
  msg="$(printf 'bounded-spin：退出（%s）· pid=%s · 父=%s · 轮=%s · 用时=%ss · 已写=%sB' \
    "$reason" "$$" "${parent:-?}" "${rounds:-0}" "$(( SECONDS - ${t0:-$SECONDS} ))" "${bytes:-0}")"
  if [ "${log:--}" != "-" ] && [ -n "${log:-}" ] && [ -e "$log" ]; then
    printf '%s\n' "$msg" >> "$log" 2>/dev/null || true
  fi
  printf '%s\n' "$msg" >&2
  exit 0
}

_bs_on_term() { # TERM = 收工：先跑调用方要的证据片段，再退出（绝不忽略）
  eval "${BOUNDED_SPIN_TERM:-:}" >/dev/null 2>&1 || true
  _bs_exit "收到 TERM"
}

bounded_spin() { # <interval_s> <cap_s> <cap_bytes|-> <log|-> [<parent_pid>]
  local iv="${1:-0.2}" cap_s="${2:-1800}" cap_b="${3:--}" log="${4:--}" parent="${5:-$PPID}"
  local t0="$SECONDS" rounds=0 bytes=0 line
  case "$cap_s" in ''|*[!0-9]*) printf 'bounded-spin：cap_s 必须是正整数（收到 [%s]）\n' "$cap_s" >&2; return 2 ;; esac
  [ "$cap_s" -gt 0 ] || { printf 'bounded-spin：cap_s 必须是正整数（收到 [%s]）\n' "$cap_s" >&2; return 2; }
  if [ "${BOUNDED_SPIN_IGNORE_TERM:-0}" = "1" ]; then
    trap '' TERM                 # 只有「忽略 TERM」本身是被测对象时才允许（调用方必须写清理由）
  else
    trap '_bs_on_term' TERM
  fi
  trap '_bs_exit "收到 INT"' INT
  while _bs_parent_alive "$parent"; do
    if [ "$(( SECONDS - t0 ))" -ge "$cap_s" ]; then _bs_exit "到点（最大运行 ${cap_s}s）"; fi
    rounds=$((rounds + 1))
    if [ "$log" != "-" ]; then
      [ -e "$log" ] || _bs_exit "写目标已不在（${log}）"
      line="$(date +%s)"
      if [ "$cap_b" != "-" ] && [ "$(( bytes + ${#line} + 1 ))" -gt "$cap_b" ]; then
        _bs_exit "到点（最大写入 ${cap_b}B）"
      fi
      printf '%s\n' "$line" >> "$log" 2>/dev/null || _bs_exit "写不进去（${log}）"
      bytes=$(( bytes + ${#line} + 1 ))
    fi
    sleep "$iv"
  done
  _bs_exit "父进程 ${parent} 已不在"
}
