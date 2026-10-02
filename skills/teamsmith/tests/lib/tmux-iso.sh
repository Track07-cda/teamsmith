#!/usr/bin/env bash
# teamsmith · P162 · 破坏性 tmux 调用的隔离前置（共享库）
#
#   背景：2026-10-02 共享 tmux server 一天消失四次，全部与门禁运行重合，而 tmux 审计里零 kill
#   类调用 —— 最可能的形状是某个破坏性夹具的**私有 socket 静默未生效**：
#     · `TMUX_TMPDIR` 指向不存在的目录 → 真 tmux 静默回退 `/tmp/tmux-<uid>/default`（#1250）；
#     · socket 路径超过 AF_UNIX 上限 107 字节 → 私有 server 绑不上（P115/P120）。
#   两种形状下 `tmux kill-server` 打的是**共享默认 socket**。
#
#   纪律（可证伪）：任何会 kill server / kill session / kill window 的段或夹具，**动手之前**逐条证明：
#     ① 目标 socket 路径存在且属于本轮：TMUX_TMPDIR 目录已 mkdir -p（-d）、期望路径 ≤ 107 字节、
#        给了 --own-root 时必须在它之下；server 活着时 socket 文件（-S）必须在。
#     ② 实际使用的 server 就是它：观察 tmux **自己**解析出的 socket（`display-message -p '#{socket_path}'`；
#        server 不在时读真 tmux 的报错文案里它尝试连接的路径）并与期望逐字节比较。
#     ③ 与共享默认 socket（/tmp/tmux-<uid>/default）不同（另可给 --caller-tmpdir：调用者那份默认 socket
#        也要不同）。
#   三条有一条不成立 → **硬停**：一行醒目结论 + 一行审计（段号 / 哪一条不成立 / 实际 socket 路径）+
#   `SKIP（前置不成立：<哪一条>）` + `exit 2`，破坏性调用**绝不执行**。
#
#   没有绕过路径：判定只读环境与文件系统，不认任何 TEAM_* 旋钮，不认 --force（未知参数按 bad-option
#   硬停）。唯一的旋钮 TEAM_TMUX_ISO_LOG 只决定审计行写哪（不改判定；自检 0h 正面钉住）。
#
#   入口：
#     tmux_iso_prove       [--tmpdir D] [--sock-name N] [--own-root R] [--caller-tmpdir C]  → 0/1（判定）
#     tmux_iso_require     <段> <用途> [同上]      → 证明通过则静默返回；不通过则硬停（exit 2）
#     tmux_iso_guard_soft  <段> <用途> [同上]      → 不通过则「响亮拒绝但不 exit」（收尾路径用）
#     tmux_iso_hard_stop / tmux_iso_audit / tmux_iso_skip  → 硬停、审计、SKIP 三个组件（可被套件覆盖 SKIP）
#
# shellcheck shell=bash

TMUX_ISO_AF_UNIX_MAX="${TMUX_ISO_AF_UNIX_MAX:-107}"   # Linux sun_path 全 108 字节（含 NUL）→ 可用 107
TMUX_ISO_STOP_CODE="${TMUX_ISO_STOP_CODE:-2}"

tmux_iso_uid() { id -u; }

tmux_iso_default_sock() { # 共享默认 socket（固定靶，写死 /tmp；不许被环境改写）
  printf '/tmp/tmux-%s/default' "$(tmux_iso_uid)"
}

tmux_iso_norm() { # <路径> → 规范化（不存在也能算：realpath -m）；失败原样
  local p="$1" r=""
  r="$(realpath -m -- "$p" 2>/dev/null)" || r="$p"
  printf '%s' "${r:-$p}"
}

tmux_iso_log() { # 审计行落点（只影响落点，不影响判定）
  printf '%s' "${TEAM_TMUX_ISO_LOG:-${TMPDIR:-/tmp}/teamsmith-tmux-iso-guard.$$.log}"
}

tmux_iso_audit() { # <段> <用途> <不成立> <细节> <期望 socket> <实际 socket>
  local f; f="$(tmux_iso_log)"
  mkdir -p "$(dirname "$f")" 2>/dev/null || true
  printf '%s · 段=%s · 用途=%s · 不成立=%s · 期望 socket=%s · 实际 socket=%s · TMUX_TMPDIR=%s · %s\n' \
    "$(date -Is 2>/dev/null || date)" "${1:--}" "${2:--}" "${3:--}" "${5:--}" "${6:--}" \
    "${TMUX_ISO_EFFECTIVE_TMPDIR:-${TMUX_TMPDIR:-(未设)}}" "${4:--}" >>"$f" 2>/dev/null || true
  return 0
}

tmux_iso_skip() { # <段> <细节>：套件可以覆盖它把 SKIP 记进账本；默认出口就打印任务书要求的字面格式
  printf '  \033[33mSKIP（前置不成立：%s）\033[0m %s\n' "$2" "$1"
}

# ── 观察：真 tmux **自己**解析出的 socket（清掉 $TMUX/$TMUX_PANE，只留 TMUX_TMPDIR；-L 用名字）
#    成功 → 打印 "<alive|absent>\t<实际 socket>"（server 活没活 / 它会连哪条路径）；读不出 → 返回 1。
#    注意：本函数常被命令替换调用（子 shell），所以状态必须走 stdout，不能靠变量传回去。
tmux_iso_observe() { # <base dir> <sock name>
  local base="$1" name="${2:-default}" out rc actual="" state="absent"
  command -v tmux >/dev/null 2>&1 || return 1
  local -a tcmd=(tmux)
  [ "$name" = "default" ] || tcmd=(tmux -L "$name")
  out="$(env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$base" "${tcmd[@]}" ls 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ]; then
    state="alive"
    actual="$(env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$base" "${tcmd[@]}" display-message -p '#{socket_path}' 2>/dev/null)"
    [ -n "$actual" ] || return 1
    printf '%s\t%s' "$state" "$actual"
    return 0
  fi
  # server 不在：真 tmux 的报错里就有它要连的路径（这就是 kill 会打到的地方）。两种已知文案：
  #   socket 子目录都没有 → `error connecting to <path> (<errno>)`
  #   目录在但 server 不在（收尾形状）→ `no server running on <path>`
  actual="$(printf '%s\n' "$out" | sed -n 's/^error connecting to \(.*\) ([^()]*)$/\1/p' | head -1)"
  [ -n "$actual" ] || actual="$(printf '%s\n' "$out" | sed -n 's/^no server running on \(.*\)$/\1/p' | head -1)"
  [ -n "$actual" ] || return 1
  printf '%s\t%s' "$state" "$actual"
  return 0
}

# ── 三条件判定：只读；成功 0，失败 1（原因在 TMUX_ISO_REASON / 细节在 TMUX_ISO_DETAIL）
tmux_iso_prove() { # [--tmpdir D] [--sock-name N] [--own-root R] [--caller-tmpdir C]
  TMUX_ISO_REASON=""; TMUX_ISO_DETAIL=""; TMUX_ISO_EXPECTED=""; TMUX_ISO_ACTUAL=""; TMUX_ISO_SERVER="absent"
  TMUX_ISO_EFFECTIVE_TMPDIR=""
  local dir="" name="default" own="" caller=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --tmpdir)        dir="${2-}"; shift 2 ;;
      --sock-name)     name="${2-}"; [ -n "$name" ] || name="default"; shift 2 ;;
      --own-root)      own="${2-}"; shift 2 ;;
      --caller-tmpdir) caller="${2-}"; shift 2 ;;
      *) TMUX_ISO_REASON="bad-option"
         TMUX_ISO_DETAIL="前置不接受参数 ${1:-}（没有 --force/环境变量绕过路径）"
         return 1 ;;
    esac
  done
  [ -n "$dir" ] || dir="${TMUX_TMPDIR:-}"
  local uid base expected default_sock
  uid="$(tmux_iso_uid)"
  base="${dir:-/tmp}"                                  # 空值 = tmux 自己也会用 /tmp
  TMUX_ISO_EFFECTIVE_TMPDIR="$base"
  expected="$base/tmux-$uid/$name"
  default_sock="$(tmux_iso_default_sock)"
  TMUX_ISO_EXPECTED="$expected"

  # 先观察（best effort）：早退的分支也要在审计里如实写下「kill 会打到哪条路径」
  local obs="" actual=""
  obs="$(tmux_iso_observe "$base" "$name" || true)"
  if [ -n "$obs" ]; then
    IFS=$'\t' read -r TMUX_ISO_SERVER actual <<<"$obs"
  fi
  [ "$TMUX_ISO_SERVER" = "alive" ] || TMUX_ISO_SERVER="absent"
  TMUX_ISO_ACTUAL="$actual"

  # ① 目标路径存在且属于本轮（-L 私有名 + TMUX_TMPDIR 未设 → 目录就是 /tmp，仍是私有 server）
  if [ -z "$dir" ] && [ "$name" = "default" ]; then
    TMUX_ISO_REASON="target-is-default"
    TMUX_ISO_DETAIL="TMUX_TMPDIR 未设 → 目标就是共享默认 socket（$default_sock）"
    return 1
  fi
  if [ -n "$dir" ] && [ ! -e "$dir" ]; then
    TMUX_ISO_REASON="tmpdir-missing"
    TMUX_ISO_DETAIL="TMUX_TMPDIR=$dir 指向不存在的目录（真 tmux 会静默回退默认 socket）"
    return 1
  fi
  if [ -n "$dir" ] && [ ! -d "$dir" ]; then
    TMUX_ISO_REASON="tmpdir-not-dir"
    TMUX_ISO_DETAIL="TMUX_TMPDIR=$dir 不是目录（真 tmux 到不了私有 socket）"
    return 1
  fi
  if [ "${#expected}" -gt "$TMUX_ISO_AF_UNIX_MAX" ]; then
    TMUX_ISO_REASON="sock-path-too-long"
    TMUX_ISO_DETAIL="socket 路径 ${#expected} 字节 > AF_UNIX 上限 $TMUX_ISO_AF_UNIX_MAX（私有 server 绑不上）"
    return 1
  fi
  if [ -n "$own" ]; then
    case "$(tmux_iso_norm "$expected")" in
      "$(tmux_iso_norm "$own")"/*) ;;
      *) TMUX_ISO_REASON="outside-own-root"
         TMUX_ISO_DETAIL="目标 socket 不在本轮自有目录 $own 之下（$expected）"
         return 1 ;;
    esac
  fi
  # ③ 不许是共享默认 socket（或调用者原来那份默认 socket）
  if [ "$(tmux_iso_norm "$expected")" = "$(tmux_iso_norm "$default_sock")" ]; then
    TMUX_ISO_REASON="target-is-default"
    TMUX_ISO_DETAIL="目标就是共享默认 socket（$default_sock）"
    return 1
  fi
  if [ -n "$caller" ]; then
    case "$(tmux_iso_norm "$expected")" in
      "$(tmux_iso_norm "$caller")"/tmux-"$uid"/default|"$(tmux_iso_norm "$caller")"/tmux-"$uid"/default/)
        TMUX_ISO_REASON="target-is-caller-default"
        TMUX_ISO_DETAIL="目标就是调用者那份默认 socket（${caller}/tmux-$uid/default）"
        return 1 ;;
    esac
  fi

  # ② 实际 server 就是它（用刚才观察到的那条路径）
  if [ -z "$actual" ]; then
    TMUX_ISO_REASON="resolution-unobservable"
    TMUX_ISO_DETAIL="读不出 tmux 解析的 socket 路径（没有 tmux？）"
    return 1
  fi
  if [ "$(tmux_iso_norm "$actual")" != "$(tmux_iso_norm "$expected")" ]; then
    if [ "$TMUX_ISO_SERVER" = "alive" ]; then
      TMUX_ISO_REASON="server-mismatch"
      TMUX_ISO_DETAIL="实际 server 的 socket（$actual）不是本轮私有 socket（$expected）"
    else
      TMUX_ISO_REASON="resolution-mismatch"
      TMUX_ISO_DETAIL="tmux 解析出的 socket（$actual）不是本轮私有 socket（$expected）"
    fi
    return 1
  fi
  if [ "$TMUX_ISO_SERVER" = "alive" ] && [ ! -S "$expected" ]; then
    TMUX_ISO_REASON="sock-missing"
    TMUX_ISO_DETAIL="server 报的 socket 是 $expected，但该路径不是 socket 文件"
    return 1
  fi
  return 0
}

# ── 硬停：一行醒目结论 + 一行审计 + SKIP + exit（不返回）
tmux_iso_hard_stop() { # <段> <用途> [<不成立> <细节> <期望> <实际>]
  local label="${1:-?}" purpose="${2:-破坏性 tmux 调用}"
  local reason="${3:-$TMUX_ISO_REASON}" detail="${4:-$TMUX_ISO_DETAIL}"
  local expected="${5:-$TMUX_ISO_EXPECTED}" actual="${6:-$TMUX_ISO_ACTUAL}"
  tmux_iso_audit "$label" "$purpose" "$reason" "$detail" "$expected" "$actual"
  printf '\n  \033[31m✗ 隔离前置不成立\033[0m：%s\n' "$detail"
  printf '     段 %s · 用途 %s · 实际 socket %s（期望 %s）· 审计 %s\n' \
    "$label" "$purpose" "${actual:-（未解析出）}" "${expected:-（未算出）}" "$(tmux_iso_log)"
  printf '     硬停（exit %s）：这条破坏性 tmux 调用绝不执行\n' "$TMUX_ISO_STOP_CODE"
  tmux_iso_skip "$label" "$detail"
  if declare -F smoke_section_close >/dev/null 2>&1; then smoke_section_close 2>/dev/null || true; fi
  # 硬停 = 现场：保留本轮临时根（审计行在它里面）
  KEEP=1; TEAM_TMP_KEEP=1
  exit "$TMUX_ISO_STOP_CODE"
}

tmux_iso_require() { # <段> <用途> [证明参数…]：通过 → 静默 0；不通过 → 硬停（exit）
  local label="${1:-?}" purpose="${2:-破坏性 tmux 调用}"; shift 2 || true
  tmux_iso_prove "$@" && return 0
  tmux_iso_hard_stop "$label" "$purpose"
}

tmux_iso_guard_soft() { # <段> <用途> [证明参数…]：通过 → 0；不通过 → 响亮拒绝 + 审计并返回 1（不 exit）
  local label="${1:-?}" purpose="${2:-破坏性 tmux 调用}"; shift 2 || true
  tmux_iso_prove "$@" && return 0
  tmux_iso_audit "$label" "$purpose" "$TMUX_ISO_REASON" "$TMUX_ISO_DETAIL" "$TMUX_ISO_EXPECTED" "$TMUX_ISO_ACTUAL"
  printf '  \033[31m✗\033[0m 隔离前置不成立（拒绝执行）：%s（段 %s；实际 socket %s；审计 %s）\n' \
    "$TMUX_ISO_DETAIL" "$label" "${TMUX_ISO_ACTUAL:-（未解析出）}" "$(tmux_iso_log)"
  return 1
}
