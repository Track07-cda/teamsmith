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
#     tmux_iso_prove       [--tmpdir D] [--sock-name N] [--own-root R] [--caller-tmpdir C] [--argv <tmux argv…>]  → 0/1（判定）
#     tmux_iso_require     <段> <用途> [同上]      → 证明通过则静默返回；不通过则硬停（exit 2）
#     tmux_iso_guard_soft  <段> <用途> [同上]      → 不通过则「响亮拒绝但不 exit」（收尾路径用）
#     tmux_iso_argv_parse  <argv…>                 → 解析动词/显式目标（只吃逐词 argv，产出见下）
#     tmux_iso_install_suite_guards <真 tmux>      → 装上 tmux() 与 command() 两个壳（套件与探针同一份代码）
#     tmux_iso_hard_stop / tmux_iso_audit / tmux_iso_skip  → 硬停、审计、SKIP 三个组件（可被套件覆盖 SKIP）
#
#   P180（返工）：P162 的“破坏性”判定原本只看 argv 第一个词（`case "${1:-}"`），于是
#     tmux -S /tmp/tmux-<uid>/default kill-server   # 显式指共享默认 socket
#     tmux -L default kill-server                   # 等价写法
#     tmux -f /dev/null kill-server                 # 其它前置选项
#   都**不进前置**、原样执行 —— 与“私有 socket 静默没生效”叠加时正是打死共享 server 的形状。
#   现在动词按 **argv 逐词**解析（契约同 M36/M67 的 shim：先跳过全局选项及其值，取第一个非选项词；
#   见 tmux_iso_argv_scan），并且 **argv 里显式给的 -S/-L 目标必须仍是本轮的私有 socket**：
#   指共享默认 socket（或任何别处）→ 直接硬停，哪怕三条件都成立。
#
#   P180 的射程边界（与 M41 的 shim 同一条已知盲区，别把它当保证）：
#     · 绝对路径（`/usr/bin/tmux kill-server`）不经 PATH、也不经壳函数 —— 射程外（设计如此，
#       仓库脚本/fixture 里禁止这么写，tmux-lint 的 M41 规则静态拦）；
#     · **子进程**（`env tmux …` / `bash -c 'tmux …'` / 窗口 harness）不继承壳函数（不 export -f），
#       它们按 PATH 解析 —— 窗口里那一层由 M36/M67 的运行时闸门管，本库管的是**本 shell 自己的**调用。
#     · `\tmux` / `"tmux"` **不**是绕过：bash 对函数照查（0h 段有记录桩断言钉住这条）。
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

# ── P180 · argv 解析（逐词；契约同 M36/M67 的 shim scripts/shim/tmux 的 _parse_globals）──────
# 跳过全局选项及其值，取第一个**非选项**词作为动词；顺带取出显式目标 -S <路径> / -L <名字>。
# 全局选项的闭集（与 shim 逐条同源）：值类 -L -S -c -f -T（含 -Lx/-Sx 粘连、组合簇里的 c/f/T/L/S），
# 无值开关 -2 -8 -C -D -l -u -v -V -N，`--` 之后第一个词是子命令，其余 `-*` 按开关跳过。
# 缺值 / 认不出的组合 → TMUX_ISO_ARGV_UNCERTAIN=1（不装懂）；
# **绝不**用“整条命令行包含某串”当判据（#1529：模式字符串会命到自己）。
# 产出（调用方读这五个全局）：
#   TMUX_ISO_ARGV_VERB          动词（第一个非选项词；没有则空）
#   TMUX_ISO_ARGV_SOCKPATH      -S 的值（最后一个胜出）
#   TMUX_ISO_ARGV_SOCKNAME      -L 的值（最后一个胜出）
#   TMUX_ISO_ARGV_UNCERTAIN     0/1（解析不确定）
#   TMUX_ISO_ARGV_DESTRUCTIVE   0/1（破坏性；由 tmux_iso_argv_parse 分类）
tmux_iso_argv_scan() { # <argv…>
  TMUX_ISO_ARGV_VERB=""; TMUX_ISO_ARGV_SOCKPATH=""; TMUX_ISO_ARGV_SOCKNAME=""
  TMUX_ISO_ARGV_UNCERTAIN=0
  local -a a=("$@")
  local n=$# i=0 w rest ch
  while [ "$i" -lt "$n" ]; do
    w="${a[$i]}"
    case "$w" in
      -L|-S|-c|-f|-T)
        if [ $((i + 1)) -lt "$n" ]; then
          case "$w" in
            -L) TMUX_ISO_ARGV_SOCKNAME="${a[$((i + 1))]}" ;;
            -S) TMUX_ISO_ARGV_SOCKPATH="${a[$((i + 1))]}" ;;
          esac
          i=$((i + 2))
        else
          TMUX_ISO_ARGV_UNCERTAIN=1; i=$((i + 1))     # 缺值：不装懂（真 tmux 自己会报错）
        fi ;;
      -L*) TMUX_ISO_ARGV_SOCKNAME="${w#-L}"; i=$((i + 1)) ;;
      -S*) TMUX_ISO_ARGV_SOCKPATH="${w#-S}"; i=$((i + 1)) ;;
      --) i=$((i + 1)); [ "$i" -lt "$n" ] && TMUX_ISO_ARGV_VERB="${a[$i]}"; break ;;
      -) TMUX_ISO_ARGV_UNCERTAIN=1; i=$((i + 1)) ;;
      -*)  # 组合簇：逐字符走；值类字符吃掉本词剩余部分或下一个词（同 M67 的 _parse_target 口径）
        rest="${w#-}"
        while [ -n "$rest" ]; do
          ch="${rest%"${rest#?}"}"; rest="${rest#?}"
          case "$ch" in
            c|f|T)
              if [ -z "$rest" ]; then
                if [ $((i + 1)) -lt "$n" ]; then i=$((i + 1)); else TMUX_ISO_ARGV_UNCERTAIN=1; fi
              fi
              rest="" ;;
            L|S)
              if [ -n "$rest" ]; then
                case "$ch" in L) TMUX_ISO_ARGV_SOCKNAME="$rest" ;; S) TMUX_ISO_ARGV_SOCKPATH="$rest" ;; esac
              elif [ $((i + 1)) -lt "$n" ]; then
                case "$ch" in L) TMUX_ISO_ARGV_SOCKNAME="${a[$((i + 1))]}" ;; S) TMUX_ISO_ARGV_SOCKPATH="${a[$((i + 1))]}" ;; esac
                i=$((i + 1))
              else
                TMUX_ISO_ARGV_UNCERTAIN=1
              fi
              rest="" ;;
            2|8|C|D|l|u|v|V|N) : ;;
            *) TMUX_ISO_ARGV_UNCERTAIN=1 ;;
          esac
        done
        i=$((i + 1)) ;;
      *) TMUX_ISO_ARGV_VERB="$w"; break ;;
    esac
  done
  return 0
}

# 分类：动词属于 kill-server|kill-session|kill-window|kill-pane（含 tmux 允许的前缀写法，多候选也认）
# → 破坏性；解析不确定（认不出的全局选项/缺值）也按破坏性对待 —— 不装懂，交给前置判定（健康轮次零代价）。
tmux_iso_argv_parse() { # <argv…>
  tmux_iso_argv_scan "$@"
  TMUX_ISO_ARGV_DESTRUCTIVE=0
  case "$TMUX_ISO_ARGV_VERB" in
    kill-*)
      local c
      for c in kill-server kill-session kill-window kill-pane; do
        case "$c" in "$TMUX_ISO_ARGV_VERB"*) TMUX_ISO_ARGV_DESTRUCTIVE=1; break ;; esac
      done ;;
  esac
  [ "$TMUX_ISO_ARGV_UNCERTAIN" = "1" ] && TMUX_ISO_ARGV_DESTRUCTIVE=1
  return 0
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
  TMUX_ISO_CALL_ARGV=()
  # 值类选项缺值时**立刻**以 bad-option 退出（M36 的教训：`shift 2` 在 $#<2 上失败会让 while
  # 原地打转 → 挂死；这里每条路径都 shift ≥1 或 break）。
  while [ $# -gt 0 ]; do
    case "$1" in
      --tmpdir)        [ $# -ge 2 ] || { TMUX_ISO_REASON="bad-option"; TMUX_ISO_DETAIL="--tmpdir 缺值"; return 1; }; dir="${2-}"; shift 2 ;;
      --sock-name)     [ $# -ge 2 ] || { TMUX_ISO_REASON="bad-option"; TMUX_ISO_DETAIL="--sock-name 缺值"; return 1; }; name="${2-}"; [ -n "$name" ] || name="default"; shift 2 ;;
      --own-root)      [ $# -ge 2 ] || { TMUX_ISO_REASON="bad-option"; TMUX_ISO_DETAIL="--own-root 缺值"; return 1; }; own="${2-}"; shift 2 ;;
      --caller-tmpdir) [ $# -ge 2 ] || { TMUX_ISO_REASON="bad-option"; TMUX_ISO_DETAIL="--caller-tmpdir 缺值"; return 1; }; caller="${2-}"; shift 2 ;;
      --argv)          shift; TMUX_ISO_CALL_ARGV=("$@"); break ;;
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

  # ── P180：调用方在 argv 里**显式**给了目标（-S <路径> / -L <名字>）→ 它必须仍是本轮的私有 socket ──
  # -S/-L 是 tmux 的命令行显式目标，优先级高于 TMUX_TMPDIR：即使上面三条都成立，显式指到别处
  # （尤其是共享默认 socket）也不许动手。判据只有逐词解析出的目标，不做任何子串匹配（#1529）。
  if [ "${#TMUX_ISO_CALL_ARGV[@]}" -gt 0 ]; then
    tmux_iso_argv_parse ${TMUX_ISO_CALL_ARGV[@]+"${TMUX_ISO_CALL_ARGV[@]}"}
    local want=""
    if [ -n "$TMUX_ISO_ARGV_SOCKPATH" ]; then
      want="$(tmux_iso_norm "$TMUX_ISO_ARGV_SOCKPATH")"
    elif [ -n "$TMUX_ISO_ARGV_SOCKNAME" ]; then
      want="$(tmux_iso_norm "$base/tmux-$uid/$TMUX_ISO_ARGV_SOCKNAME")"
    fi
    if [ -n "$want" ]; then
      TMUX_ISO_EXPECTED="$expected"; TMUX_ISO_ACTUAL="$want"
      if [ "$want" = "$(tmux_iso_norm "$default_sock")" ]; then
        TMUX_ISO_REASON="explicit-target-is-default"
        TMUX_ISO_DETAIL="argv 里的 -S/-L 直接指向共享默认 socket（$default_sock）"
        return 1
      fi
      if [ "$want" != "$(tmux_iso_norm "$expected")" ]; then
        TMUX_ISO_REASON="explicit-target-mismatch"
        TMUX_ISO_DETAIL="argv 里的 -S/-L 指向 $want，不是本轮的私有 socket（$expected）"
        return 1
      fi
    fi
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

# ── P180 · 套件的壳函数（tmux / command tmux）：两个壳共用同一条入口 ───────────────────────────
# 非破坏性调用原样透传（PATH 解析与改动前一致）；破坏性调用先过前置（不成立 → 硬停），再按 M23 的
# 形态执行（env -u TMUX -u TMUX_PANE + 本轮私有 TMUX_TMPDIR）—— 那也是 tmux-lint 认的隔离证据形态。
tmux_iso_suite_call() { # <段> [--tmpdir D --own-root R --caller-tmpdir C] -- <argv…>
  local label="${1:-?}"; shift || true
  local dir="" own="" caller=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --tmpdir)        [ $# -ge 2 ] || break; dir="${2-}"; shift 2 ;;
      --own-root)      [ $# -ge 2 ] || break; own="${2-}"; shift 2 ;;
      --caller-tmpdir) [ $# -ge 2 ] || break; caller="${2-}"; shift 2 ;;
      --) shift; break ;;
      *) break ;;
    esac
  done
  tmux_iso_argv_parse "$@"
  if [ "$TMUX_ISO_ARGV_DESTRUCTIVE" = "1" ]; then
    tmux_iso_require "$label" "tmux $*" --tmpdir "$dir" --own-root "$own" \
      --caller-tmpdir "$caller" --argv "$@" || return 1
    env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$dir" "${TMUX_ISO_REAL_TMUX:-tmux}" "$@"
  else
    # 非破坏性：PATH 解析原样（`builtin command` 跳壳函数，但不跳 PATH；与 P180 之前一致）
    builtin command tmux "$@"
  fi
}

# 装壳（<真 tmux 路径>）：两个壳只在**本 shell 内**生效 —— 刻意**不** export -f：子进程按 PATH 解析
# （与改动前一致），窗口/子进程那一层由 M36/M67 的运行时闸门管。
#   `tmux …` / `\tmux …` / `"tmux" …` → 壳函数（bash 对函数照查；见 0h 段的记录桩断言）
#   `command tmux …`             → command() 壳（P180：它与裸 tmux 是同一条 PATH 解析，必须同源纳入）
#   `command <其它>`             → builtin command 原样
#   `env tmux …` / 绝对路径 / 子进程 → 不在本壳射程内（边界见文件头）
tmux_iso_install_suite_guards() { # <真 tmux 路径>
  TMUX_ISO_REAL_TMUX="${1:-}"
  tmux() {
    tmux_iso_suite_call "${SMOKE_SEC_OPEN_ID:-?}" --tmpdir "${TMUX_TMPDIR:-}" --own-root "${TMP:-}" \
      --caller-tmpdir "${SMOKE_CALLER_TMUX_TMPDIR:-}" -- "$@"
  }
  command() {
    case "${1:-}" in
      tmux) shift; tmux "$@" ;;
      *) builtin command "$@" ;;
    esac
  }
}
