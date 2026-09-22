#!/usr/bin/env bash
# M28 · tmux 接触型测试的容器跑法（五次 server 全灭事故换来的纪律，见 references/troubleshooting.md §18）
#
#   bash skills/teamsmith/tests/container-tmux.sh --selftest
#   bash skills/teamsmith/tests/container-tmux.sh -- bash skills/teamsmith/tests/pm-box-real.sh --idle-secs 4
#   bash skills/teamsmith/tests/container-tmux.sh --with-pi --cmd 'bash skills/teamsmith/tests/pm-box-real.sh'
#
# 选项：
#   --selftest        容器内 tmux 生死（含裸 kill-server）+ M67 泄漏形状（退役键进 server 全局环境）
#                     + 断言宿主 server 指纹前后逐字节不变
#   --fingerprint     只打印当前 TMUX/TMUX_TMPDIR 下的宿主 tmux 指纹（不起容器、只读、不起 server）
#   --fingerprint-check
#                     指纹前提的双面夹具：客户端风暴不移动它、杀掉范围内 server 会移动它
#                     （四腿：a 风暴 / b 杀 server / c 真会话变化 / d 无 server 只读）
#
# 镜像里必须带 **procps**（V18 F-V18-2）：panel-b3 / pm-box-real 这类夹具用 `ps -o args= -p <pid>`
# 判进程身份，BusyBox 的 ps 不支持这些参数 —— 旧缓存镜像会在容器里制造 6 条假红。镜像探针
# （image_ps_caps）认出缺 procps 的旧缓存就自动重建（显式 TEAM_TMUX_IMAGE 除外，只跳过）。
#   --with-pi         运行时把宿主的 pi 包目录只读挂进去，并生成一个 `pi` 包装器（不挂 $HOME）
#   --cmd '…'         在里面跑一行 shell（否则 `-- cmd args…` 直接 exec）
#   --image NAME      覆盖镜像名     ｜ --rebuild 强制重建镜像
#   --print-runtime   只打印探测到的运行时与镜像名
#   --keep-shim       跑完不删生成的包装器目录（排查用）
#   -h|--help         这页
#
# 为什么必须进容器：tmux 选 socket 的顺序是 **`-L/-S`（命令行） > `$TMUX`（环境变量） >
# `${TMUX_TMPDIR:-/tmp}/tmux-<uid>/default`** —— 所以在 tmux 会话里跑「会自己开窗/杀 server」的夹具时，
# 任何一次没有显式隔离的 `tmux` 调用都可能落到**调用者的 server** 上（M28 探针 #4/#5 实测）。
# 容器把宿主 socket 目录整个挡在挂载之外（再叠一层 uid 差异：容器内是 root，socket 目录是 `tmux-0`，
# 宿主的在 `tmux-<uid>`）—— 于是「打不到宿主」是构造性的，不靠夹具自觉。
#
# 契约（给门禁/夹具用）：
#   exit 0  容器内命令跑完且退出码为 0
#   exit 1  容器内命令非 0（或容器本身跑不起来）
#   exit 77 容器不可用（没有 podman / 拉不下镜像 / 仓库路径不在宿主共享目录）——**不是失败**：
#           打印 SKIP 理由，门禁据此跳过
#
# 环境变量：
#   TEAM_TMUX_IMAGE        镜像名（默认 teamsmith-tmux-test:alpine；本地无则构建一次并缓存）
#   TEAM_TMUX_BASE_IMAGE   Dockerfile 的 FROM（默认 docker.io/library/alpine:latest）
#   TEAM_TMUX_RUNTIME      强制运行时命令（如 "podman" 或 "distrobox-host-exec podman"）
#   TEAM_TMUX_HOME         容器内的 HOME（默认 /root；刻意不挂宿主 $HOME，pi 拿不到密钥）
#   TEAM_TMUX_MEMORY       内存上限（默认 1g；0 = 不加限制）
#   TEAM_TMUX_TIMEOUT      容器内命令的墙钟上限秒（默认 1800）
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF_FILE="$SELF_DIR/$(basename "${BASH_SOURCE[0]}")"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
REPO_ROOT="$(cd -P "$SKILL_DIR/../.." && pwd)"
IMAGE="${TEAM_TMUX_IMAGE:-teamsmith-tmux-test:alpine}"
BASE_IMAGE="${TEAM_TMUX_BASE_IMAGE:-docker.io/library/alpine:latest}"
MEMORY="${TEAM_TMUX_MEMORY:-1g}"
CT_TIMEOUT="${TEAM_TMUX_TIMEOUT:-1800}"

SELFTEST=0; WITH_PI=0; REBUILD=0; KEEP_SHIM=0; PRINT_RUNTIME=0; CMD_STRING=""; ARGV=()
FINGERPRINT=0; FINGERPRINT_CHECK=0
while [ $# -gt 0 ]; do
  case "$1" in
    --selftest) SELFTEST=1; shift ;;
    --fingerprint) FINGERPRINT=1; shift ;;
    --fingerprint-check) FINGERPRINT_CHECK=1; shift ;;
    --with-pi) WITH_PI=1; shift ;;
    --rebuild) REBUILD=1; shift ;;
    --keep-shim) KEEP_SHIM=1; shift ;;
    --print-runtime) PRINT_RUNTIME=1; shift ;;
    --image) IMAGE="${2:?--image 需要镜像名}"; shift 2 ;;
    --image=*) IMAGE="${1#*=}"; shift ;;
    --cmd) CMD_STRING="${2:?--cmd 需要命令串}"; shift 2 ;;
    --cmd=*) CMD_STRING="${1#*=}"; shift ;;
    --) shift; ARGV=("$@"); break ;;
    -h|--help) sed -n '2,/^set -uo pipefail/p' "$0" | sed '$d'; exit 0 ;;
    *) printf 'container-tmux: 未知参数 %s（--help 看用法）\n' "$1" >&2; exit 2 ;;
  esac
done
case "$CT_TIMEOUT" in ''|*[!0-9]*) CT_TIMEOUT=1800 ;; esac

say()  { printf '%s\n' "$*"; }
note() { printf '  \033[2m·\033[0m %s\n' "$*"; }
skip() { printf 'SKIP: %s\n' "$*"; exit 77; }

# ── 运行时探测（真宿主直跑优先；在 distrobox 里经 host-exec 回宿主）─────────────────────────────
CT_RT=(); CT_RT_DESC=""
ct_resolve_runtime() {
  if [ -n "${TEAM_TMUX_RUNTIME:-}" ]; then
    # shellcheck disable=SC2206
    CT_RT=(${TEAM_TMUX_RUNTIME}); CT_RT_DESC="$TEAM_TMUX_RUNTIME（显式指定）"
    timeout 30 "${CT_RT[@]}" --version >/dev/null 2>&1 && return 0 || return 1
  fi
  if command -v podman >/dev/null 2>&1; then
    CT_RT=(podman); CT_RT_DESC="podman（本机直跑）"
    timeout 30 podman --version >/dev/null 2>&1 && return 0 || return 1
  fi
  if command -v distrobox-host-exec >/dev/null 2>&1; then
    if timeout 30 distrobox-host-exec podman --version >/dev/null 2>&1; then
      CT_RT=(distrobox-host-exec podman); CT_RT_DESC="distrobox-host-exec podman（回宿主）"
      return 0
    fi
  fi
  return 1
}

# 调用者的 tmux socket（TMUX 的第一段就是 socket 路径；没有 TMUX 时退回默认目录）
caller_socket() {
  if [ -n "${TMUX:-}" ]; then printf '%s' "${TMUX%%,*}"; else printf '%s' "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/default"; fi
}

# ── 宿主 tmux 指纹：本轮容器跑完后必须逐字节一致 ──────────────────────────────────────────────
# 只由**范围内 socket 的宿主状态**构成 —— 每个 socket 一份：磁盘身份（inode/mtime/size）+ 该 socket 上
# server 的会话表 +（有 server 应答时）它的 pid。三条纪律（D34 假红与 #1250 的教训）：
#   · 客户端 / 闸门 shim / team 命令 / **命令行里只是提到 tmux 的进程**一律不得移动它 —— 旧版的
#     whole-ps 快照正是被这些推着走了（D34 实测）；
#   · 别的项目的私有 fixture server、范围外的 session 进不来（快照能被它们推动，per-socket 查询不能）；
#   · 读取只读、不起 server：`list-sessions` 拿不到就报 no server running；`display-message -p '#{pid}'`
#     在没有 server 的 socket 上只报错退出（只创建 socket 目录，不建 socket 文件 —— design §1.1 实测）。
host_tmux_fingerprint() {
  local out="" s pid
  for s in "$(caller_socket)" "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/default" /tmp/tmux-$(id -u)/default; do
    [ -n "$s" ] || continue
    case "$out" in *"|$s|"*) continue ;; esac      # 同一个 socket 只算一次
    out="$out|$s|"
    if [ -S "$s" ]; then
      out="$out$(stat -c '%i:%Y:%s' "$s" 2>/dev/null || printf '?')|"
      out="$out$(env -u TMUX -u TMUX_PANE timeout 5 tmux -S "$s" list-sessions \
                  -F '#{session_name}:#{session_created}:#{session_windows}:#{session_attached}' 2>/dev/null | sort | tr '\n' ',')|"
      pid="$(env -u TMUX -u TMUX_PANE timeout 5 tmux -S "$s" display-message -p '#{pid}' 2>/dev/null || true)"
      out="$out${pid:-none}|"
    else
      out="$out(absent)|"
    fi
  done
  printf '%s' "$out" | md5sum | cut -d' ' -f1
}

# ── --fingerprint-check：指纹前提的双面夹具（四条腿，全在私有 default server 上）────────────────
#   (a) 客户端风暴 + 一个**命令行里带 tmux 二进制**的活 shell：前后逐字节一致（旧版 whole-ps 快照在这腿红）
#   (b) 杀掉范围内 server：值必须变（并因此非零退出）
#   (c) 真会话变化：值也变 —— 前提就是宿主 tmux 状态，真变化不是噪声
#   (d) 没有 server：两次读到同一个值、exit 0、不留下 socket 文件（只读，不起 server）
# 只碰私有 TMUX_TMPDIR 里的 default socket；结束时（含异常路径）清掉那台私有 server。
FP_DIR=""
FP_DIR2=""
fp_cleanup() { # 只碰 FP_DIR/FP_DIR2 里的私有 socket；目录丢了/空了就什么都不做（绝不回退默认 socket）
  local dps="${FP_DIR:-} ${FP_DIR2:-}" dp
  for dp in $dps; do
    [ -n "$dp" ] || continue
    if [ -S "$dp/tmux-$(id -u)/default" ]; then
      env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$dp" tmux kill-server >/dev/null 2>&1 || true
    fi
    rm -rf "$dp"
  done
}
ct_fingerprint_check() {
  local rc=0 fp1 fp2 fp3 fpa fpb sp sp2 i r1 r2 d1 d2 sock sock2 fp_bin
  if ! command -v tmux >/dev/null 2>&1; then
    say "SKIP: --fingerprint-check 需要 tmux（宿主上没有）"
    return 77
  fi
  FP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/fpcheck.XXXXXX")" || { say "✗ --fingerprint-check：建不了私有目录"; return 1; }
  sock="$FP_DIR/tmux-$(id -u)/default"
  trap 'fp_cleanup' EXIT
  # 私有 default socket 的包装（隔离证据：env -u TMUX + 私有 TMUX_TMPDIR）；真身走 PATH 里的 tmux
  fp_tmux() { env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$FP_DIR" tmux "$@"; }
  fp_read() { env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$FP_DIR" TMUX="$sock,1,0" bash "$SELF_FILE" --fingerprint; }
  say "── --fingerprint-check（私有 default socket：$sock）"
  if ! fp_tmux new-session -d -s fpcheck 'sleep 300' >/dev/null 2>&1; then
    say "✗ (a) 私有 server 起不起来"; trap - EXIT; fp_cleanup; return 1
  fi
  fp1="$(fp_read)"; r1=$?
  if [ "$r1" -ne 0 ] || [ -z "$fp1" ]; then
    say "✗ (a) 第一次读指纹失败（rc=$r1）"; trap - EXIT; fp_cleanup; return 1
  fi
  note "(a) server 活着：$fp1"
  # 风暴：读调用 + 一个**活着的** tmux 客户端（wait-for 挂着不走）+ 一个命令行里只是提到 tmux 的 shell；
  # 旧版 whole-ps 快照会被这两条 ps 行推动，新版必须逐字节不变
  fp_bin="$(command -v tmux)"
  fp_tmux wait-for fpcheck-chan >/dev/null 2>&1 &
  sp=$!
  bash -c "exec -a $fp_bin sleep 60" >/dev/null 2>&1 &
  sp2=$!
  for i in 1 2 3 4 5 6; do
    fp_tmux list-sessions >/dev/null 2>&1
    fp_tmux display-message -p '#{pid}' >/dev/null 2>&1
  done
  fp2="$(fp_read)"
  kill "$sp2" 2>/dev/null || true
  fp_tmux wait-for -S fpcheck-chan >/dev/null 2>&1 || true
  wait "$sp" 2>/dev/null || true; wait "$sp2" 2>/dev/null || true
  if [ "$fp1" = "$fp2" ]; then
    say "  ok  (a) 客户端风暴 + 客户端/命令行提到 tmux 的 shell：前后逐字节一致（$fp2）"
  else
    say "  BAD (a) 客户端风暴移动了指纹：前 $fp1 ≠ 后 $fp2（旧版 whole-ps 快照的假红形状）"
    rc=1
  fi
  # (b) 杀掉范围内 server → 值变（旧版与新版的共同底线）
  fp_tmux kill-server >/dev/null 2>&1 || true
  fp3="$(fp_read)"
  if [ "$fp2" = "$fp3" ]; then
    say "  BAD (b) 杀掉范围内 server 后指纹没变：$fp2"; rc=1
  else
    say "  ok  (b) 杀掉范围内 server → 指纹变了：$fp2 ≠ $fp3"
  fi
  # (c) 真会话变化 → 值也变
  fp_tmux new-session -d -s fpcheck2 'sleep 300' >/dev/null 2>&1
  fpa="$(fp_read)"
  fp_tmux new-session -d -s fpcheck3 'sleep 300' >/dev/null 2>&1
  fpb="$(fp_read)"
  if [ -n "$fpa" ] && [ "$fpa" != "$fpb" ]; then
    say "  ok  (c) 真会话变化 → 指纹变了（$fpa ≠ $fpb）"
  else
    say "  BAD (c) 新增会话没有移动指纹（$fpa = $fpb）"; rc=1
  fi
  fp_tmux kill-server >/dev/null 2>&1 || true
  # (d) 一个从未起过 server 的私有 TMUX_TMPDIR：读两次同值、exit 0、不冒出 socket 文件（只读，不起 server）
  FP_DIR2="$(mktemp -d "${TMPDIR:-/tmp}/fpcheck2.XXXXXX")" || { say "✗ (d) 建不了第二个私有目录"; rc=1; }
  if [ -n "${FP_DIR2:-}" ]; then
    sock2="$FP_DIR2/tmux-$(id -u)/default"
    d1="$(env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$FP_DIR2" TMUX="$sock2,1,0" bash "$SELF_FILE" --fingerprint)"; r1=$?
    d2="$(env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$FP_DIR2" TMUX="$sock2,1,0" bash "$SELF_FILE" --fingerprint)"; r2=$?
    if [ "$r1" = 0 ] && [ "$r2" = 0 ] && [ "$d1" = "$d2" ] && [ ! -e "$sock2" ]; then
      say "  ok  (d) 没有 server：两次同值、exit 0、没冒出 socket（$d1）"
    else
      say "  BAD (d) 无 server 形状不对：rc=$r1/$r2 值 '$d1'/'$d2' socket=$([ -e "$sock2" ] && printf 在 || printf 无)"; rc=1
    fi
  fi
  trap - EXIT
  fp_cleanup
  if [ "$rc" -eq 0 ]; then
    say "✓ --fingerprint-check 通过：风暴不移动、真变化（杀 server / 新会话）移动、无 server 只读"
  else
    say "✗ --fingerprint-check 失败"
  fi
  return "$rc"
}

# ── 镜像准备（本地无则构建一次；构建脚本与上下文都在 $HOME 下，镜像层里不写任何密钥）─────────────
CT_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/teamsmith/tmux-container"
image_exists() { timeout 60 "${CT_RT[@]}" image exists "$IMAGE" >/dev/null 2>&1; }
# 镜像能力探针（V18 F-V18-2）：夹具靠 `ps -o args= -p <pid>` 判进程身份，BusyBox 的 ps 不支持这些
# 参数。这一发是**只读**的（--rm，不挂任何宿主目录），只回答「镜像里的 ps 够不够用」。
image_ps_caps() {
  timeout 60 "${CT_RT[@]}" run --rm --entrypoint sh "$IMAGE" -c 'ps -o args= -p 1 >/dev/null 2>&1' >/dev/null 2>&1
}

# 仓库路径在容器里必须看得见（宿主共享目录之外 → 挂载不进去：降级跳过，不是失败）。
# 同时也能探测「podman 能查镜像但跑不起容器」这类故障。
ct_probe_mount() { ct_run test -e "$REPO_ROOT/skills/teamsmith/scripts/team" >/dev/null 2>&1; }

ensure_image() {
  if [ "$REBUILD" != "1" ] && image_exists; then
    if image_ps_caps; then return 0; fi
    # 旧缓存镜像（早于 V18 F-V18-2 构建的）缺 procps：默认镜像自动重建；显式指定的镜像不擅自重建。
    if [ -n "${TEAM_TMUX_IMAGE:-}" ]; then
      skip "镜像 $IMAGE 的 ps 不支持 -o args= -p（缺 procps）：夹具会假红，换镜像或去掉 TEAM_TMUX_IMAGE 让本脚本构建"
    fi
    say "镜像 $IMAGE 是旧缓存（ps 不支持所需参数，缺 procps）→ 自动重建（V18 F-V18-2）"
  elif [ "$REBUILD" != "1" ] && [ -n "${TEAM_TMUX_IMAGE:-}" ]; then
    skip "镜像 $IMAGE 不存在（TEAM_TMUX_IMAGE 指定了名字就不会自动构建；--rebuild 可强制构建）"
  elif [ "$REBUILD" = "1" ] && image_exists; then
    say "镜像 $IMAGE：--rebuild 强制重建（按当前 Containerfile 重新构建）"
  fi
  mkdir -p "$CT_CACHE" || skip "建不了镜像构建目录 $CT_CACHE"
  cat > "$CT_CACHE/Containerfile.tmux" <<EOF
# M28 生成的 tmux 测试镜像（一次构建、之后走本地缓存）。
# 只放测试需要的工具：tmux 做 tmux 现场，bash/git 给团队脚本与夹具，nodejs 用来在容器里跑真 pi
# （pi 是 node ESM bundle，运行时只读挂载进去），python3 给 fake-tui 一类夹具，
# procps 给「用 ps -o args= -p 判进程身份」的夹具（BusyBox 的 ps 不支持这些参数）。
# 构建期就断言 ps 参数可用：构建出来的镜像不允许缺这条能力（F-V18-2）。
FROM $BASE_IMAGE
RUN apk add --no-cache tmux bash git nodejs python3 procps \\
 && ps -o args= -p 1 >/dev/null
EOF
  say "构建 tmux 测试镜像 $IMAGE（一次，之后缓存；base=$BASE_IMAGE）…"
  if ! timeout 900 "${CT_RT[@]}" build -t "$IMAGE" -f "$CT_CACHE/Containerfile.tmux" "$CT_CACHE" >"$CT_CACHE/build.log" 2>&1; then
    say "镜像构建失败（尾 10 行，全文 $CT_CACHE/build.log）："
    tail -10 "$CT_CACHE/build.log" | sed 's/^/     /'
    skip "容器不可用：镜像 $IMAGE 构建/拉取失败"
  fi
  image_exists || skip "容器不可用：镜像 $IMAGE 构建后仍查不到"
  say "镜像就绪：$IMAGE"
  return 0
}

# ── 容器内环境与挂载 ──────────────────────────────────────────────────────────────────────────
# 关键点：
#   * TMUX/TMUX_PANE/DBUS_SESSION_BUS_ADDRESS 一律清掉（前两个是路由开关；DBUS 会让 pane 里的进程
#     去跟宿主 systemd 要 scope，报 "Couldn't move process" 噪声）。
#   * 每一个宿主挂载都用**同一个绝对路径**（夹具里的 SKILL_DIR/仓库路径不用翻译）。
#   * 宿主 socket 目录若落在挂载范围内，用 --tmpfs 盖掉（否则共享的 socket 文件仍可连接）。
CT_MOUNTS=(); CT_SOCKMASK=()
ct_build_mounts() {
  # 仓库只读 + 缓存目录（容器内要跑的自检脚本/pi 包装器都在这里；只读挂载，路径与宿主一致）
  CT_MOUNTS=(-v "$REPO_ROOT:$REPO_ROOT:ro" -v "$CT_CACHE:$CT_CACHE:ro")
  # --with-pi 时另挂 pi 自己的包目录（只有 npm 包，没有任何密钥）：~/.pi 与 auth.json 一律不进容器。
  [ -n "${CT_PI_NODE_MODULES:-}" ] && CT_MOUNTS+=(-v "$CT_PI_NODE_MODULES:$CT_PI_NODE_MODULES:ro")
  local sockdir; sockdir="$(dirname "$(caller_socket)")"
  case "$sockdir/" in
    "$REPO_ROOT/"*|"$CT_CACHE/"*) CT_SOCKMASK=(--tmpfs "$sockdir") ;;
  esac
}

# --with-pi：生成一个 pi 包装器（镜像里不带路径/密钥；运行时把宿主现有 pi 的包目录只读挂进去）
# 刻意**不挂 $HOME**：容器里的 pi 拿不到 provider 配置/密钥，也写不到宿主的 ~/.pi。
# 对投递守卫体检这类夹具来说这正好 —— 它只关心输入框的真实渲染，不需要模型。
CT_SHIM=""; CT_PI_NODE_MODULES=""
ct_make_shim() {
  local bunglobal="${BUN_INSTALL:-$HOME/.bun}/install/global/node_modules"
  local cli="$bunglobal/@earendil-works/pi-coding-agent/dist/bundle/cli.js"
  if [ ! -f "$cli" ]; then
    note "找不到 pi bundle（$cli）—— --with-pi 跳过 pi 包装器"
    return 0
  fi
  CT_PI_NODE_MODULES="$bunglobal"
  CT_SHIM="$CT_CACHE/shim"
  rm -rf "$CT_SHIM"; mkdir -p "$CT_SHIM/bin"
  cat > "$CT_SHIM/bin/pi" <<EOF
#!/bin/sh
# M28 生成：容器里的 \`pi\` = alpine 的 node 跑宿主只读挂进来的 bundle。
exec node "$cli" "\$@"
EOF
  chmod +x "$CT_SHIM/bin/pi"
  note "pi 包装器：$CT_SHIM/bin/pi → node $cli（不挂 \$HOME：容器里没有 provider 密钥）"
}

ct_run() { # <argv...>：在容器里跑（清掉继承的 tmux/dbus 身份）
  local -a cmd=("$@")
  [ "${#cmd[@]}" -gt 0 ] || return 2
  local -a mem=(); [ "$MEMORY" != "0" ] && [ -n "$MEMORY" ] && mem=(--memory "$MEMORY")
  local -a patharg=()
  [ -n "$CT_SHIM" ] && patharg=(-e "PATH=$CT_SHIM/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin")
  timeout "$CT_TIMEOUT" "${CT_RT[@]}" run --rm --workdir "$REPO_ROOT" \
    "${mem[@]}" "${CT_MOUNTS[@]}" "${CT_SOCKMASK[@]}" \
    -e "TERM=${TERM:-xterm-256color}" -e "LANG=C.UTF-8" -e "LC_ALL=C.UTF-8" \
    -e "HOME=${TEAM_TMUX_HOME:-/root}" -e "TEAM_TMUX_CONTAINER=1" -e "M28_HOST_SOCK=$(caller_socket)" \
    "${patharg[@]}" \
    "$IMAGE" env -u TMUX -u TMUX_PANE -u DBUS_SESSION_BUS_ADDRESS "${cmd[@]}" < /dev/null
}

# ── 自检：容器内 tmux 生死 + 宿主 server 指纹不变 ──────────────────────────────────────────────
ct_selftest() {
  local before after inner_log rc
  before="$(host_tmux_fingerprint)"
  say "宿主 tmux 指纹（前）：$before"
  note "调用者 socket：$(caller_socket)（容器内必须看不到它）"
  inner_log="$CT_CACHE/selftest.log"; mkdir -p "$CT_CACHE"

  # 容器内：① 身份变量必须已清 ② 宿主 socket 不可见 ③ 裸 tmux 能开窗、能杀 server（就是 M23 那种形状）
  # ④ 用的是容器自己的 socket 目录
  cat > "$CT_CACHE/selftest-inner.sh" <<'INNER'
set -u
fail=0
chk() { # <说明> <期望> <实际>
  if [ "$2" = "$3" ]; then printf '  ok   %s (%s)\n' "$1" "$3"; else printf '  BAD  %s（期望 %s，实际 %s）\n' "$1" "$2" "$3"; fail=1; fi
}
chk "容器内 tmux 可用" "yes" "$(command -v tmux >/dev/null 2>&1 && printf yes || printf no)"
chk "TMUX 已清空" "" "${TMUX:-}"
chk "TMUX_PANE 已清空" "" "${TMUX_PANE:-}"
chk "DBUS_SESSION_BUS_ADDRESS 已清空" "" "${DBUS_SESSION_BUS_ADDRESS:-}"
chk "宿主 socket 不可见（$M28_HOST_SOCK）" "no" "$([ -e "${M28_HOST_SOCK:-/nonexistent}" ] && printf yes || printf no)"
chk "容器 socket 目录里没有宿主的 tmux-1000" "no" "$([ -d /tmp/tmux-1000 ] && printf yes || printf no)"
chk "容器 uid（决定 socket 目录 = tmux-N）" "0" "$(id -u)"
# V18 F-V18-2：夹具（panel-b3 的 detail/collapse、pm-box-real）用 `ps -o args= -p <pid>` 判进程身份。
# BusyBox 的 ps 通过 /bin/ps 也在这条路径上 —— 这里同时钉「参数被接受」与「真读得出 pid 1 的 argv」。
chk "容器内 ps 支持 -o args= -p（procps）" "yes" "$(ps -o args= -p 1 >/dev/null 2>&1 && printf yes || printf no)"
chk "容器内 ps 读得出 pid 1 的 args（非空）" "yes" "$([ -n "$(ps -o args= -p 1 2>/dev/null)" ] && printf yes || printf no)"
# 裸 tmux：没有 env -u / -L —— 在宿主里这就是打向调用者 server 的那一发
if tmux new-session -d -s m28-selftest 'sleep 20' 2>/dev/null; then
  chk "裸 tmux new-session 在容器里成功" "yes" "yes"
else
  chk "裸 tmux new-session 在容器里成功" "yes" "no"
fi
sock="$(env -u TMUX -u TMUX_PANE tmux display-message -p '#{socket_path}' 2>/dev/null || true)"
printf '  info 裸 tmux 用的 socket：%s\n' "${sock:-<无>}"
case "$sock" in /tmp/tmux-0/*|"$HOME"/*|/tmp/tmux-"$(id -u)"/*) printf '  ok   socket 在容器自己的目录里\n' ;; *) printf '  BAD  socket 不在容器自己的目录（%s）\n' "${sock:-<无>}"; fail=1 ;; esac
chk "容器里看得见 1 个 session" "1" "$(tmux list-sessions -F x 2>/dev/null | wc -l | tr -d ' ')"
chk "capture-pane 能读容器内的窗格" "yes" "$(tmux capture-pane -p -t m28-selftest >/dev/null 2>&1 && printf yes || printf no)"
# 杀 server：容器内不许带任何隔离，正是要证明「裸 kill-server 伤不到宿主」
if tmux kill-server >/dev/null 2>&1; then printf '  ok   裸 tmux kill-server 成功\n'; else printf '  BAD  裸 tmux kill-server 失败\n'; fail=1; fi
chk "kill-server 后容器内没有 server" "gone" "$(tmux list-sessions >/dev/null 2>&1 && printf alive || printf gone)"
exit "$fail"
INNER

  ct_run bash "$CT_CACHE/selftest-inner.sh" >"$inner_log" 2>&1
  rc=$?
  sed 's/^/  /' "$inner_log" | head -40
  if [ "$rc" -ne 0 ]; then
    say "✗ --selftest：容器内自检失败（exit=$rc，全文 $inner_log）"
    return 1
  fi

  # M67 泄漏形状（R3 第三个 scenario）：容器里起一台 server，它的环境（会被复制进每个 pane）带着退役键
  # TEAM_ALLOW_DESTRUCTIVE_TMUX=1；从它的 pane 里经闸门跑 kill-server：无 token → exit 64 + act=refused
  # 且 server 还在；带 --teamsmith-allow-destructive → 执行、容器内 server 消失、记 act=explicit-flag。
  # 宿主侧只管指纹前后逐字节一致（容器里的默认 socket 不是宿主的）。
  cat > "$CT_CACHE/leak-inner.sh" <<'INNER'
set -u
fail=0
chk() { # <说明> <期望> <实际>
  if [ "$2" = "$3" ]; then printf '  ok   %s (%s)\n' "$1" "$3"; else printf '  BAD  %s（期望 %s，实际 %s）\n' "$1" "$2" "$3"; fail=1; fi
}
REPO_ROOT="${1:-}"
SHIM="$REPO_ROOT/skills/teamsmith/scripts/shim"
LOG=/tmp/m67-leak-calls.log
: > "$LOG"
export TEAM_ALLOW_DESTRUCTIVE_TMUX=1          # 泄漏形状：server 由带着退役键的进程启动
export PATH="$SHIM:$PATH"
export TEAM_TMUX_REAL="$(command -v tmux)"
export TEAM_TMUX_CALLS_LOG="$LOG"
unset TMUX TMUX_PANE
chk "闸门 shim 在（容器里挂的仓库路径）" "yes" "$([ -x "$SHIM/tmux" ] && printf yes || printf no)"
tmux new-session -d -s leaksrc 'sleep 120'
chk "server 全局环境带着退役键（泄漏形状成立）" "TEAM_ALLOW_DESTRUCTIVE_TMUX=1" \
    "$(tmux show-environment -g TEAM_ALLOW_DESTRUCTIVE_TMUX 2>&1)"
# ② 无 token：拒绝（exit 64），server 还活着
rm -f /tmp/m67-leak-first.txt
tmux new-window -t leaksrc -n refused -d -- bash -c 'tmux kill-server; echo "first=$?" > /tmp/m67-leak-first.txt'
i=0; while [ "$i" -lt 100 ] && [ ! -s /tmp/m67-leak-first.txt ]; do sleep 0.1; i=$((i+1)); done
chk "无 token 的 kill-server 被拒（pane 里拿到 exit 64）" "first=64" "$(cat /tmp/m67-leak-first.txt 2>/dev/null)"
chk "无 token 的 kill-server 记 act=refused" "1" "$(grep -c 'act=refused' "$LOG" 2>/dev/null)"
chk "拒绝之后 server 还在（没有真的执行）" "alive" "$(tmux ls >/dev/null 2>&1 && printf alive || printf gone)"
# ③ 带 token：执行（server 消失），记 explicit-flag（pane 随 server 一起死，rc 由 server 消失+ledger 证明）
tmux new-window -t leaksrc -n flagged -d -- bash -c 'tmux --teamsmith-allow-destructive kill-server'
i=0; while [ "$i" -lt 100 ] && tmux ls >/dev/null 2>&1; do sleep 0.1; i=$((i+1)); done
chk "带 token 的 kill-server 执行了（容器内 server 消失）" "gone" "$(tmux ls >/dev/null 2>&1 && printf alive || printf gone)"
chk "带 token 的调用记 act=explicit-flag" "1" "$(grep -c 'act=explicit-flag' "$LOG" 2>/dev/null)"
chk "ledger 里没有 act=override（该词汇退役）" "0" "$(grep -c 'act=override' "$LOG" 2>/dev/null)"
exit "$fail"
INNER
  leak_log="$CT_CACHE/leak-inner.log"
  ct_run bash "$CT_CACHE/leak-inner.sh" "$REPO_ROOT" >"$leak_log" 2>&1
  rc=$?
  say "M67 泄漏形状夹具（容器内）："
  sed 's/^/  /' "$leak_log" | head -30
  if [ "$rc" -ne 0 ]; then
    say "✗ --selftest：容器泄漏形状夹具失败（exit=$rc，全文 $leak_log）"
    return 1
  fi

  after="$(host_tmux_fingerprint)"
  say "宿主 tmux 指纹（后）：$after"
  if [ "$before" != "$after" ]; then
    say "✗ --selftest：宿主 tmux 指纹变了（前 $before ≠ 后 $after）—— 隔离没生效，先停下查"
    return 1
  fi
  say "✓ 自检通过：容器内 tmux 生死正常（含裸 kill-server），宿主 server 指纹逐字节不变（$after）"
  return 0
}

# ── main ─────────────────────────────────────────────────────────────────────────────────────
mkdir -p "$CT_CACHE" || skip "建不了缓存目录 $CT_CACHE"
# --fingerprint / --fingerprint-check 是纯宿主的只读模式：不需要容器运行时，先于运行时探测处理
if [ "$FINGERPRINT" = "1" ]; then host_tmux_fingerprint; exit 0; fi
if [ "$FINGERPRINT_CHECK" = "1" ]; then ct_fingerprint_check; exit $?; fi
if ! ct_resolve_runtime; then
  skip "找不到可用的容器运行时（podman 直接不可用，distrobox-host-exec podman 也不通）——容器不可用时门禁跳过而不是红"
fi
if [ "$PRINT_RUNTIME" = "1" ]; then say "runtime: $CT_RT_DESC"; say "image:   $IMAGE"; exit 0; fi
note "运行时：$CT_RT_DESC"
[ "$WITH_PI" = "1" ] && ct_make_shim
ct_build_mounts
ensure_image || exit $?
if ! ct_probe_mount; then
  skip "容器里看不到仓库路径 $REPO_ROOT（不在宿主共享目录里）或容器起不来 —— 降级跳过"
fi

if [ "$SELFTEST" = "1" ]; then
  ct_selftest || exit 1
  [ "$KEEP_SHIM" = "1" ] || rm -rf "$CT_SHIM" 2>/dev/null || true
  exit 0
fi

if [ -n "$CMD_STRING" ]; then
  ct_run bash -c "$CMD_STRING"
elif [ "${#ARGV[@]}" -gt 0 ]; then
  ct_run "${ARGV[@]}"
else
  printf 'container-tmux: 没有要跑的命令（--cmd "…" 或 -- cmd args…；--selftest 跑自检）\n' >&2
  exit 2
fi
rc=$?
[ "$KEEP_SHIM" = "1" ] || rm -rf "$CT_SHIM" 2>/dev/null || true
if [ "$rc" -eq 124 ]; then
  say "✗ 容器内命令超时（TEAM_TMUX_TIMEOUT=$CT_TIMEOUT）"
fi
exit "$rc"
