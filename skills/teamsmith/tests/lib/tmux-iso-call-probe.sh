#!/usr/bin/env bash
# teamsmith · P180 · 「调用形态 → 前置」探针（子进程夹具）
#
#   在**子进程**里装上与门禁**同一份**壳函数（lib/tmux-iso.sh 的 tmux_iso_install_suite_guards），
#   然后执行一段给定的调用形态，用**记录桩**量出两件事：
#     ① 这条形态有没有硬停（exit 2 = 前置不成立，调用绝不执行）；
#     ② 记录桩收到了什么 argv（收到 = 这条调用真的被执行了）。
#   这就是 P180 要求的红侧口径：「每一种绕过形态 → 必须硬停 + 记录桩为空」；反向的「正常形态照常
#   执行」也由同一个记录桩量（收到 = 放行了）。
#
#   记录桩（本脚本生成，放在私有桩目录里当 PATH 里的 `tmux`）：
#     · **只记「要动手」的调用**（写进 <记录桩文件>）—— 红侧要求它为空，就是「没有一条调用被放行」；
#     · 一份只读动词白名单（证明要看 tmux 自己解析出的 socket：ls / display-message …）另记到
#       <记录桩文件>.ro 并交给 `--real` 指的真 tmux —— 那是前置自己的观察，不算被保护的调用；
#     · 白名单之外**一律只记录、绝不动手** —— 影子/破损形态下也不许真杀。
#   破坏性调用**永远不会**被桩执行：本探针构造上打不到任何真 server。
#
#   用法：
#     tmux-iso-call-probe.sh <lib> <记录桩文件> <桩目录> <形态> \
#         --real <真 tmux 路径> [--tmpdir <本轮声称的 TMUX_TMPDIR> | --no-tmpdir] \
#         [--own-root R] [--caller-tmpdir C] [--label L]
#     形态：一段 shell 代码（在壳函数装好之后 eval）——
#       'tmux -S /tmp/tmux-$(id -u)/default kill-server'
#       'command tmux -L default kill-server'
#       '\tmux kill-session -t x'          # 反斜杠引号：bash 对函数照查（不是绕过）
#       'true; tmux -f /dev/null kill-server'
#
#   退出码：0 = 没硬停（调用执行了，或本来就不是破坏性调用）｜2 = 硬停（前置不成立）｜9 = 驱动自身问题
# shellcheck shell=bash
set -uo pipefail

LIB="${1:-}"; RECORD="${2:-}"; STUBDIR="${3:-}"; FORM="${4:-}"; shift 4 2>/dev/null || true
REAL=""; DIR=""; OWN=""; CALLER=""; LABEL="P180 探针"; NO_TMPDIR=0
while [ $# -gt 0 ]; do
  case "$1" in
    --real)          [ $# -ge 2 ] || exit 9; REAL="$2"; shift 2 ;;
    --tmpdir)        [ $# -ge 2 ] || exit 9; DIR="$2"; shift 2 ;;
    --no-tmpdir)     NO_TMPDIR=1; shift ;;
    --own-root)      [ $# -ge 2 ] || exit 9; OWN="$2"; shift 2 ;;
    --caller-tmpdir) [ $# -ge 2 ] || exit 9; CALLER="$2"; shift 2 ;;
    --label)         [ $# -ge 2 ] || exit 9; LABEL="$2"; shift 2 ;;
    *) exit 9 ;;
  esac
done
[ -f "$LIB" ] || exit 9
[ -n "$RECORD" ] && [ -n "$STUBDIR" ] && [ -n "$FORM" ] && [ -n "$REAL" ] || exit 9

# ── 记录桩：写在桩目录里，PATH 最前 ─────────────────────────────────────────────────────────
mkdir -p "$STUBDIR" || exit 9
: > "$RECORD"; : > "$RECORD.ro"
cat > "$STUBDIR/tmux" <<EOF
#!/usr/bin/env bash
# P180 探针的记录桩（生成物，不是仓库脚本）：只记**要动手**的调用；只读白名单另记 <记录>.ro。
case "\${1:-}" in
  ls|list-sessions|list-windows|list-panes|display-message|has-session|show-options|show-messages|show-environment)
    printf '%s\n' "\$*" >> "$RECORD.ro"    # 前置观察 socket 用的只读调用：留证，不算「动手」
    # 只读也算「打到 server 上」：目标不可用（会静默回退共享默认 socket）时一律不交真身（#1794）
    case "\${TMUX_TMPDIR:-}" in
      ''|/tmp|/tmp/) exit 0 ;;
    esac
    [ -d "\${TMUX_TMPDIR:-}" ] || exit 0
    exec "$REAL" "\$@" ;;
esac
printf '%s\n' "\$*" >> "$RECORD"                # 其余都记（影子/破损形态下这些就是「真的执行了」的证据）
exit 0
EOF
chmod +x "$STUBDIR/tmux" || exit 9
PATH="$STUBDIR:$PATH"; export PATH
STUB="$STUBDIR/tmux"

# ── 与门禁同一份壳（lib 里装）：先剥掉调用者的 tmux 身份，只留本轮声称的 TMUX_TMPDIR ──────────
unset TMUX TMUX_PANE 2>/dev/null || true
# shellcheck source=tmux-iso.sh
. "$LIB" || exit 9
tmux_iso_skip() { printf 'SKIP（前置不成立：%s） %s\n' "$2" "$1"; }
if [ "$NO_TMPDIR" = "1" ]; then unset TMUX_TMPDIR 2>/dev/null || true; else TMUX_TMPDIR="$DIR"; export TMUX_TMPDIR; fi
TMP="$OWN"; SMOKE_SEC_OPEN_ID="$LABEL"; SMOKE_CALLER_TMUX_TMPDIR="$CALLER"; export TMP SMOKE_SEC_OPEN_ID SMOKE_CALLER_TMUX_TMPDIR
tmux_iso_install_suite_guards "$STUB"

# ── 执行形态（硬停时 exit 2 就从这里直接离开本进程）────────────────────────────────────────
eval "$FORM"
