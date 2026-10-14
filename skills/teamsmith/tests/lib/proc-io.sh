#!/usr/bin/env bash
# shellcheck shell=bash
# proc-io.sh — 无编译器依赖的进程观测器（key-replies.sh 与 panel 的 reply-fixture.sh 共用）。
#
# ---------------------------------------------------------------- 内核观测器（无编译器依赖）
# 为什么不用 LD_PRELOAD 计数：门禁镜像 `ci/Containerfile` 按 M47 在编译完 tmux 后 purge 掉
# build-essential —— 镜像里永远没有编译器，shim 编不出来，本 change 登记的段在门禁环境里就会红
# （V27 的 M3）。这里改用**内核自己给出的**两个只读接口，宿主与容器一致可用：
#   /proc/<pid>/io        rchar（read 类系统调用搬进的字节数）/ syscr（read 类调用次数）
#   /proc/<pid>/fd{,info} 进程真正打开过哪些路径、以什么 flags 打开（O_PATH 在内核里不能 getdents）
# 采样在子进程存活期间**紧循环**进行（不 sleep）：读取量断言靠「最后一刻的快照」，紧循环把丢失
# 末次读的窗口压到微秒级；观测器不可用时按项目约定**可见跳过并点名**，绝不静默通过。
kr_io_why() { # 观测器不可用的原因（点名）
  if [ "${TEAM_REPLY_NO_PROC_IO:-}" = "1" ]; then printf '%s' 'TEAM_REPLY_NO_PROC_IO=1（夹具模拟缺工具）'
  elif [ ! -r /proc/self/io ]; then printf '%s' '/proc/self/io 不可读（hidepid/非 Linux？）'
  else printf '%s' 'rchar/syscr 字段不在 /proc/<pid>/io 里'
  fi
}
kr_io_supported() {
  [ "${TEAM_REPLY_NO_PROC_IO:-}" = "1" ] && return 1
  [ -r /proc/self/io ] || return 1
  grep -q '^rchar:' /proc/self/io 2>/dev/null || return 1
  return 0
}
kr_observe_py() { # 惰性写：source 时 $TMP 还不存在
  KR_OBS_PY="${TMP:?kr_observe 需要先建临时根}/kr_observe.py"
  [ -f "$KR_OBS_PY" ] && return 0
  cat >"$KR_OBS_PY" <<'PYOBS'
"""Sample /proc/<pid>/io and /proc/<pid>/fd{,info} while a child runs.

Writes <prefix>.rc, <prefix>.io (last snapshot), <prefix>.fds (one row per fd target seen:
count, flags, target) and keeps the child's stdout/stderr in <prefix>.out / <prefix>.err.
The sampling loop is tight (no sleep) so the final reads are not missed; it costs one busy
core for the duration of the observed command, which is why only the IO fixtures use it.
"""
import os, subprocess, sys

rcf, iof, fdf = (sys.argv[1], sys.argv[2], sys.argv[3])
cmd = sys.argv[4:]
child = subprocess.Popen(cmd, stdout=open(rcf + ".out", "wb"), stderr=open(rcf + ".err", "wb"))
last_io = b""
seen = {}

def sample():
    global last_io
    try:
        with open("/proc/%d/io" % child.pid, "rb") as f:
            last_io = f.read()
    except OSError:
        pass
    try:
        names = os.listdir("/proc/%d/fd" % child.pid)
    except OSError:
        return
    for name in names:
        try:
            target = os.readlink("/proc/%d/fd/%s" % (child.pid, name))
        except OSError:
            continue
        if target.startswith(("/proc", "/dev", "pipe:", "socket:", "anon_inode:", "/memfd")):
            continue
        flags = ""
        try:
            with open("/proc/%d/fdinfo/%s" % (child.pid, name)) as f:
                for line in f:
                    if line.startswith("flags:"):
                        flags = line.split(":", 1)[1].strip()
                        break
        except OSError:
            pass
        row = seen.setdefault(target, {"n": 0, "flags": flags})
        row["n"] += 1
        if flags and not row["flags"]:
            row["flags"] = flags

while child.poll() is None:
    sample()
rc = child.wait()
open(rcf, "w").write("%d\n" % rc)
open(iof, "wb").write(last_io)
with open(fdf, "w") as f:
    for target, row in sorted(seen.items()):
        f.write("%d\t%s\t%s\n" % (row["n"], row["flags"], target))
PYOBS
}
kr_observe() { # <前缀> <命令…>：跑命令并把内核计数器/打开证据落到 <前缀>.{rc,io,fds,out,err}
  kr_observe_py
  python3 "$KR_OBS_PY" "$1" "$1.io" "$1.fds" "${@:2}"
  return $?
}
kr_obs_rc()   { cat "$1.rc" 2>/dev/null | tr -d '\n'; }
kr_obs_field() { # <前缀> <rchar|syscr|…>
  awk -v k="$2:" '$1 == k { print $2 }' "$1.io" 2>/dev/null | tr -d '\n'
}
kr_obs_rchar() { local v; v="$(kr_obs_field "$1" rchar)"; printf '%s' "${v:-0}"; }
kr_obs_syscr() { local v; v="$(kr_obs_field "$1" syscr)"; printf '%s' "${v:-0}"; }
kr_obs_fd_count() { # <前缀> <路径正则> → 命中的 fd 目标个数（0 = 没看见）
  awk -F'\t' -v re="$2" '$3 ~ re { n++ } END { print n+0 }' "$1.fds" 2>/dev/null
}
kr_obs_fd_flags() { # <前缀> <路径正则> → 第一个命中目标的 flags（八进制字符串）
  awk -F'\t' -v re="$2" '$3 ~ re { print $2; exit }' "$1.fds" 2>/dev/null
}

