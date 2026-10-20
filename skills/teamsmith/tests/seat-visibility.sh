#!/usr/bin/env bash
# P276 · 孤儿席位可见性夹具（change: orphan-visibility · apply）
#
#   bash skills/teamsmith/tests/seat-visibility.sh                       # 全部组
#   bash skills/teamsmith/tests/seat-visibility.sh --select census,judge # 只跑指定组
#   bash skills/teamsmith/tests/seat-visibility.sh --flip                # 逐条红侧（破坏 → 指定用例必红 → 还原 → 绿）
#
# 组：census（1.1–1.4）/ judge（2.1–2.4）/ naming（3.1–3.4）/ reading（4.1–4.5）
#     hint（5.1–5.2）/ seams（4.3 的四种边界）/ reap（6.1–6.7）
#
# 判据（合同）：openspec/changes/orphan-visibility/specs/{seat-visibility,boundary}/spec.md。
# 退出码：0 = 全部预期成立；1 = 有失败；3 = 临时根建不起来。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# shellcheck source=tests/lib/tmp-root.sh
. "$SELF_DIR/lib/tmp-root.sh"

MODE="all"; SEL_GROUPS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --select) shift; IFS=',' read -r -a _g <<< "${1:-}"; SEL_GROUPS+=("${_g[@]}"); shift ;;
    --flip) MODE="flip"; shift ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) printf 'seat-visibility.sh：未知参数 %s\n' "$1" >&2; exit 2 ;;
  esac
done
want() { [ "$MODE" = "flip" ] && return 1; [ "${#SEL_GROUPS[@]}" -eq 0 ] && return 0; local g; for g in "${SEL_GROUPS[@]}"; do [ "$g" = "$1" ] && return 0; done; return 1; }

TMP="$(tmp_root_create seat-visibility)" || exit 3
export HOME="$TMP/home"; mkdir -p "$HOME"
cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0
  # 真进程现场留下的假孤儿：夹具自己收干净（绝不靠被测工具兜底）
  local p
  for p in ${OC_SPAWNED:-}; do kill -KILL "$p" 2>/dev/null || true; done
  tmp_root_reap_all
}
trap cleanup EXIT

PASS=0; FAIL=0; SKIP=0
ok()   { PASS=$((PASS + 1)); printf '  \033[32m✓\033[0m %s\n' "$*"; }
bad()  { FAIL=$((FAIL + 1)); printf '  \033[31m✗\033[0m %s\n' "$*"; }
skip() { SKIP=$((SKIP + 1)); printf '  \033[33mSKIP\033[0m %s\n' "$*"; }
section() { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
td_eq() { if [ "$2" = "$3" ]; then ok "$1（=$2）"; else bad "$1：期望 [$2] 实际 [$3]"; fi; }
td_has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1：文本里没有 [$3]（实际：$(printf '%s' "$2" | head -c 300)）" ;; esac; }
td_not_has() { case "$2" in *"$3"*) bad "$1：不该出现 [$3]（实际：$(printf '%s' "$2" | head -c 300)）" ;; *) ok "$1" ;; esac; }
td_ne() { if [ "$2" != "$3" ]; then ok "$1"; else bad "$1：期望不等于 [$2]"; fi; }

# ---------------------------------------------------------------- 夹具骨架
T="$TMP/repo"                     # 纯逻辑夹具项目（假进程记录写在这里）
PROC="$TMP/proc"                  # 假 /proc（TEAM_ORPHAN_PROC_ROOT 的接缝）
PROC2="$TMP/proc2"                # 第二棵假 /proc（TOCTOU 的 FIFO 现场）
BIN="$TMP/bin"                    # 桩 tmux（不碰真 tmux server）
PANES="$TMP/panes"
mkdir -p "$T/.pi/team/state" "$T/worktrees/dev" "$T/worktrees/dev2" "$T/docs/team" "$T/openspec/specs" \
         "$PROC" "$PROC2" "$BIN" "$PANES" "$TMP/home" "$TMP/pi-agent" "$TMP/meetings"
printf 'btime 1700000000\n' > "$PROC/stat"
printf 'btime 1700000000\n' > "$PROC2/stat"
printf '#!/bin/sh\nexit 0\n' > "$BIN/pi"; chmod +x "$BIN/pi"
# 真 ps 的路径：必须在 $BIN/ps 垫片出现**之前**解析（否则解析到垫片自己，垫片再 exec 自己 → 无限递归）。
OC_PS_REAL="$(command -v ps)"

# 桩 tmux：只回答 `list-panes -a -F '#{pane_id}'`，pane 集合来自 $OC_PANES_DIR/<socket 转写>；
# 其余动词一律失败（夹具不碰任何真 server）。socket 没有对应文件 → 退出 1 → 「查询不到」。
cat > "$BIN/tmux" <<'STUB'
#!/usr/bin/env bash
sock=""
case " $* " in *" list-panes "*) ;; *) exit 1 ;; esac
while [ $# -gt 0 ]; do
  case "$1" in -S) sock="${2:-}"; shift 2 ;; *) shift ;; esac
done
case "$sock" in ""|-) key="_default" ;; *) key="$(printf '%s' "$sock" | tr -c 'A-Za-z0-9' '_')" ;; esac
f="${OC_PANES_DIR:-/nonexistent}/$key"
[ -f "$f" ] || exit 1
cat "$f"
STUB
chmod +x "$BIN/tmux"
oc_panes() { # <socket> <pane-id…>（socket 为 "-" = 默认 server）
  local sock="$1"; shift
  local key; case "$sock" in ""|-) key="_default" ;; *) key="$(printf '%s' "$sock" | tr -c 'A-Za-z0-9' '_')" ;; esac
  : > "$PANES/$key"
  local p; for p in "$@"; do printf '%s\n' "$p" >> "$PANES/$key"; done
}
oc_panes - '%1' '%2'                       # 默认 server：%1 %2

export PATH="$BIN:$PATH" OC_PANES_DIR="$PANES"
export SKILL_DIR T PROC PROC2 BIN PANES TMP T2 OC_PS_REAL
export TEAM_ROOT="$T" TEAM_MAIN_ROOT="$T" TEAM_STATE_DIR="$T/.pi/team/state" \
       TEAM_DOCS_ABS="$T/docs/team" TEAM_DOCS_DIR="docs/team" TEAM_SESSION="oc-fixture" TEAM_PROJECT="oc" \
       TEAM_AGENTS="dev dev2" TEAM_WORKTREES_DIR="worktrees" TEAM_PI_AGENT_DIR="$T/pi" TEAM_CLI="team" \
       TEAM_PM_WINDOW="pm" TEAM_PM_INBOX="pm" TEAM_PROTECTED_BRANCH="main" TEAM_SKILL_DIR="$SKILL_DIR" \
       TEAM_TASK_MODELS='code=oc/fast' TEAM_PM_MODEL='oc/pm' TEAM_PI_BIN="$BIN/pi" \
       TEAM_ORPHAN_PROC_ROOT="$PROC" TEAM_SCAN_CACHE=0
unset TMUX TMUX_PANE TEAM_AGENT_BIN TEAM_AGENT_CMD TEAM_PM_BIN TEAM_PM_CMD TEAM_ORPHAN_SCAN TEAM_ORPHAN_WARN_MB 2>/dev/null || true

# 顶层 source（库里有 declare -A；函数里 source 会变成函数局部）
# shellcheck source=scripts/lib/common.sh
. "$SKILL_DIR/scripts/lib/common.sh"
for _oc_lib in "$SKILL_DIR"/scripts/lib/cmd-*.sh; do . "$_oc_lib" 2>/dev/null || true; done

# 假进程：<pid>/{cmdline,environ,stat,status}（与真 /proc 同形状）
oc_mkproc() { # <pid> <argv> <environ 文本> [tick] [rss_kb] [root]
  local pid="$1" argv="$2" env="$3" tick="${4:-12345}" rss="${5:-4096}" root="${6:-$PROC}" d
  d="$root/$pid"; rm -rf "$d"; mkdir -p "$d"
  printf '%s' "$argv" | tr ' ' '\0' > "$d/cmdline"; printf '\0' >> "$d/cmdline"
  : > "$d/environ"
  local l; while IFS= read -r l; do [ -n "$l" ] && printf '%s\0' "$l" >> "$d/environ"; done <<< "$env"
  # stat：`<pid> (pi) S` 之后第 20 个字段是 starttime（字段 22）
  printf '%s (pi) S 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 %s 1 1\n' "$pid" "$tick" > "$d/stat"
  printf 'Name:\tpi\nVmRSS:\t  %s kB\n' "$rss" > "$d/status"
}
oc_env_own()     { printf 'TEAM_MAIN_ROOT=%s\nTEAM_ROOT=%s\n' "$T" "$T/worktrees/${1:-dev2}"; }
oc_env_foreign() { printf 'TEAM_MAIN_ROOT=%s\nTEAM_ROOT=%s\n' "$TMP/other-proj" "$TMP/other-proj/worktrees/dev"; }
oc_env_own2() { # $T2（真项目）的席位身份：TEAM_MAIN_ROOT 必须是 CLI 解析出来的**物理**路径
  local mr wt; mr="$(cd "$T2" && pwd -P)"; wt="${2:-dev2}"
  printf 'TEAM_MAIN_ROOT=%s\nTEAM_ROOT=%s\n' "$mr" "$mr/.worktrees/$wt"
}
oc_field() { # <pid> <列号>
  team_orphan_census | awk -F'\t' -v p="$1" -v n="$2" '$1==p{print $n}'
}

# 1.1 的 fork 读数：`ps` 垫片 —— 只记一次调用（一行一次），然后交给真 ps。装/卸都由夹具自己做，
# 别的组不装它（垫片会给每次 ps 多一个 fork）。
oc_mk_ps_shim() {
  cat > "$BIN/ps" <<SHIM
#!/usr/bin/env bash
[ -n "\${OC_PS_LOG:-}" ] && printf '%s\n' "\$*" >>"\$OC_PS_LOG"
exec "$OC_PS_REAL" "\$@"
SHIM
  chmod +x "$BIN/ps"
}
oc_rm_ps_shim() { rm -f "$BIN/ps"; }

# 4.2 的归一化（夹具与逐条红侧共用同一份，免得两边判据漂）：
#   ① 取读数块**之前**的既有行 —— 这同时钉住「读数整块在最后」（插进中间/开头会把既有块截掉）；
#   ② 抹平容量行里每轮都变的实时数字（RAM 可用 / 临时根 / inode）。
oc42_before() { printf '%s\n' "$1" | sed '/^孤儿席位进程/,$d'; }
oc42_nums()   { sed -E 's/[0-9]+/N/g'; }
oc_record() { team_orphan_census | grep -P "^$1\t" || true; }
oc_mkfifo_proc() { # <root> <pid> <environ|stat> <payload1> <payload2>
  local root="$1" pid="$2" which="$3" p1="$4" p2="$5" d
  d="$root/$pid"; rm -rf "$d"; mkdir -p "$d"
  printf '%s' "pi" | tr ' ' '\0' > "$d/cmdline"; printf '\0' >> "$d/cmdline"
  printf 'Name:\tpi\nVmRSS:\t  2048 kB\n' > "$d/status"
  # FIFO 写者必须离开调用者的 stdio：否则它会攥着那条管道，调用方等不到 EOF
  if [ "$which" = "environ" ]; then
    mkfifo "$d/environ"
    # 两次写之间必须等第一次的读者读到 EOF：否则 FIFO 会把两段并进**同一次**读（现场就不再是两次）
    ( printf '%s\0' "$p1" > "$d/environ"; sleep 0.3; printf '%s\0' "$p2" > "$d/environ" ) >/dev/null 2>&1 &
    OC_SPAWNED="${OC_SPAWNED:-} $!"
  else
    : > "$d/environ"
    local l; while IFS= read -r l; do [ -n "$l" ] && printf '%s\0' "$l" >> "$d/environ"; done <<< "$(oc_env_own2 dev2)"
    mkfifo "$d/stat"
    ( printf '%s (pi) S 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 %s 1 1\n' "$pid" "$p1" > "$d/stat"
      sleep 0.3
      printf '%s (pi) S 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 %s 1 1\n' "$pid" "$p2" > "$d/stat" ) >/dev/null 2>&1 &
    OC_SPAWNED="${OC_SPAWNED:-} $!"
  fi
}

oc_reset_proc() { # 每个组用自己的现场：清空假 /proc（组之间不互相依赖）
  rm -rf "$PROC"; mkdir -p "$PROC"
  printf 'btime 1700000000\n' > "$PROC/stat"
}

printf 'task=P276\ntaskfile=docs/team/tasks/P276-orphan-visibility-apply.md\n' > "$T/.pi/team/state/dev2.env"

# 真进程现场：<argv0=pi> 的替身（真 /proc、真 pid），夹具自己负责收尾
oc_spawn_orphan() { # <main-root> <worktree> → pid
  # 子进程的 stdio 必须离开命令替换的管道，否则 `$(oc_spawn_orphan …)` 会一直等它退出
  env -u TMUX -u TMUX_PANE TEAM_MAIN_ROOT="$1" TEAM_ROOT="$2" bash -c 'exec -a pi sleep 600' >/dev/null 2>&1 &
  local p=$!
  OC_SPAWNED="${OC_SPAWNED:-} $p"
  sleep 0.3
  printf '%s\n' "$p"
}

# 真实项目（CLI 端到端）：进程身份与 pid 用真 /proc；假根只用于确定性的 TOCTOU 现场
T2="$TMP/repo2"
oc_project2_setup() {
  [ -f "$T2/.pi/team/config.sh" ] && return 0
  mkdir -p "$T2"
  ( cd "$T2" && git init -q -b main && git config user.email oc@fixture && git config user.name oc \
      && printf '{"name":"repo2","scripts":{"verify":"true"}}\n' > package.json \
      && git add -A && git commit -qm init ) >/dev/null 2>&1
  oc_cli_skill "$SKILL_DIR" "$T2" init --no-skills --session OC2 --agents "dev verify" --vcs local \
    --gates true --docs docs/team --task-models 'code=oc/fast' --pm-model 'oc/pm' --pm-window pm \
    >"$TMP/init2.log" 2>&1 || return 1
  mkdir -p "$T2/.pi/team/state" "$T2/.worktrees/dev2"
  printf 'task=P276\ntaskfile=docs/team/tasks/P276-x.md\n' > "$T2/.pi/team/state/dev2.env"
  return 0
}
oc_cli_skill() { # <skill 目录> <项目目录> <argv…>
  local sk="$1" d="$2"; shift 2
  ( cd "$d" && env -u TMUX -u TMUX_PANE -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
        -u TEAM_STATE_DIR -u TEAM_DOCS_ABS -u TEAM_DOCS_DIR -u TEAM_AGENTS -u TEAM_PM_WINDOW -u TEAM_SKILL_DIR \
        PATH="$BIN:$PATH" HOME="$TMP/home" TEAM_PI_AGENT_DIR="$TMP/pi-agent" TEAM_MEETINGS_DIR="$TMP/meetings" \
        TEAM_PI_BIN="$BIN/pi" TEAM_ORPHAN_PROC_ROOT="${OC_PROC_ROOT:-/proc}" OC_PANES_DIR="$PANES" \
        ${OC_ENV:-} bash "$sk/scripts/team" "$@" 2>&1 )
}
oc_cli() { local d="$1"; shift; oc_cli_skill "$SKILL_DIR" "$d" "$@"; }

export -f oc_panes oc_mkproc oc_env_own oc_env_own2 oc_env_foreign oc_field oc_record oc_mkfifo_proc oc_cli oc_cli_skill oc_spawn_orphan oc_project2_setup oc_mk_ps_shim oc_rm_ps_shim oc42_before oc42_nums

# ================================================================ census
if want census; then
section "census · 身份从进程自己身上读 + 形状复用既有解析（1.1–1.4）"
oc_reset_proc
oc_mkproc 1001 "pi --model x" "$(oc_env_own dev2)" 12345 4096
td_eq "own：kind" own "$(oc_field 1001 2)"
td_eq "own：seat 由进程自己的 TEAM_ROOT 推出" dev2 "$(oc_field 1001 3)"
td_eq "own：task 取自 state/dev2.env" P276 "$(oc_field 1001 4)"
td_eq "own：start = btime + tick/HZ" 1700000123 "$(oc_field 1001 5)"
td_eq "own：rss = VmRSS/1024" 4 "$(oc_field 1001 6)"
td_eq "own：无 TMUX_PANE → orphan" orphan "$(oc_field 1001 7)"

# 1.3 记录读不到 / 字段读不到 → 不写占位（`-`），绝不填 0
oc_mkproc 1002 "pi" "$(oc_env_own dev3)" 999 1024
td_eq "没有派单记录 → task 是 '-'" - "$(oc_field 1002 4)"
rm -f "$PROC/1002/stat" "$PROC/1002/status"
td_eq "start 读不到 → '-'" - "$(oc_field 1002 5)"
td_eq "rss 读不到 → '-'" - "$(oc_field 1002 6)"

# 1.1 形状：argv 不命中 agent/PM 可执行文件 → 不是席位
oc_mkproc 1003 "node panel.js" "$(oc_env_own dev2)" 100 1024
td_eq "argv 不命中 agent（面板）→ 不是席位" "" "$(oc_field 1003 1)"

# 1.4 旧形状（P103）的假阳性：命令行**提到** agent 路径的启动壳
oc_mkproc 1004 "bash -lc exec $BIN/pi --provider x -e $SKILL_DIR/extension/team-bg.ts dispatch-dev.spawn" "$(oc_env_own dev2)" 100 1024
oc_mkproc 1005 "bash -c cd $T && printf %s 1 > $T/.pi/team/state/pm.pid.spawn && exec $BIN/pi -c" "$(oc_env_own dev2)" 100 1024
td_eq "dispatch-*.spawn 启动壳 → 不是席位" "" "$(oc_field 1004 1)"
td_eq "pm.pid.spawn 启动壳 → 不是席位" "" "$(oc_field 1005 1)"

# 1.2 归属按进程自己的 TEAM_MAIN_ROOT（调用者的身份不参与）
oc_mkproc 1006 "pi" "$(oc_env_foreign)" 100 1024
td_eq "进程属于别的项目 → kind=foreign" foreign "$(oc_field 1006 2)"
td_eq "foreign 记录不带席位名" - "$(oc_field 1006 3)"
out="$(TEAM_MAIN_ROOT="$TMP/other-proj" TEAM_ROOT="$TMP/other-proj" team_orphan_census | awk -F'\t' '$1==1001{print $2}')"
td_eq "从别的项目调用：进程仍按自己的 TEAM_MAIN_ROOT 归类" foreign "$out"

# 1.1 身份为空（读得到但一个身份键都没有）→ anon（只计数）
oc_mkproc 1007 "pi" "PATH=/usr/bin" 100 1024
td_eq "空身份的同形状进程 → kind=anon" anon "$(oc_field 1007 2)"

# 1.1 argv[0] 是**全路径**的席位进程（真实派单/启动就是这种形状：`exec /path/to/pi …`）——
# 粗筛按 basename 子串，不许要求两侧有空格，否则真席位会被整批漏掉。
oc_mkproc 1008 "$BIN/pi --provider oc --model fast" "$(oc_env_own dev2)" 100 1024
td_eq "argv[0] 是全路径的 agent → 仍是席位" own "$(oc_field 1008 2)"
oc_mkproc 1009 "$BIN/pi -c" "$(printf 'TEAM_MAIN_ROOT=%s\nTEAM_ROOT=%s\n' "$T" "$T")" 100 1024
td_eq "PM（TEAM_ROOT = 主检出）→ 席位名是 PM 窗口名" pm "$(oc_field 1009 3)"

# 1.1 第三段：一次普查的 fork 与耗时读数（**真 /proc** 路径 —— 夹具根不走 ps，那次机器级粗筛只在这里发生）。
# 判据可证伪：候选粗筛只许 fork 一次 ps（机器级快照），不是每个 pid 一次；反例见 --flip 的 p276-flip-one-ps。
oc_mk_ps_shim
export OC_PS_LOG="$TMP/ps-calls.log"; : > "$OC_PS_LOG"
npid="$(ls -1 /proc 2>/dev/null | grep -cE '^[0-9]+$' || true)"; npid="${npid:-0}"
rc=0; t0="$(date +%s%N)"
TEAM_ORPHAN_PROC_ROOT=/proc team_orphan_census >"$TMP/census-real.log" 2>/dev/null || rc=$?
t1="$(date +%s%N)"
calls="$(grep -c . "$OC_PS_LOG" 2>/dev/null || true)"; calls="${calls:-0}"
cands="$(TEAM_ORPHAN_PROC_ROOT=/proc team_orphan_candidates 2>/dev/null | grep -c . || true)"; cands="${cands:-0}"
recs="$(grep -c . "$TMP/census-real.log" 2>/dev/null || true)"; recs="${recs:-0}"
ms=$(( (t1 - t0) / 1000000 ))
unset OC_PS_LOG; oc_rm_ps_shim
td_eq "1.1 一次普查（真 /proc）退出 0" 0 "$rc"
td_eq "1.1 一次普查只 fork 一次 ps（机器级粗筛，不是每个 pid 一次）" 1 "$calls"
td_has "1.1 那次 ps 的形态是候选粗筛（-eo pid=,args=）" "$(head -1 "$TMP/ps-calls.log")" "-eo pid=,args="
ok "1.1 一次普查的读数：/proc 下 ${npid} 个 pid → 粗筛候选 ${cands} 个 → 记录 ${recs} 条；ps 调用 ${calls} 次；耗时 ${ms}ms"
fi

# ================================================================ judge
if want judge; then
section "judge · 孤儿 = 没有活着的 pane，且按进程自己那个 server 判（2.1–2.4）"
oc_reset_proc
oc_panes /tmp/oc-sockA '%5' '%7'
oc_panes /tmp/oc-sockB '%9'
oc_panes /tmp/oc-gone '%3'
rm -f "$PANES/$(printf '%s' /tmp/oc-missing | tr -c 'A-Za-z0-9' '_')"

oc_mkproc 1101 "pi" "$(oc_env_own dev2)
TMUX=/tmp/oc-sockA,111,0
TMUX_PANE=%5" 100 1024
td_eq "自己窗口里的活 pane → 不是孤儿" live "$(oc_field 1101 7)"
oc_mkproc 1102 "pi" "$(oc_env_own dev2)
TMUX=/tmp/oc-sockA,111,0
TMUX_PANE=%7" 100 1024
td_eq "同一个 server 上别的 session 的活 pane → 不是孤儿" live "$(oc_field 1102 7)"
oc_mkproc 1103 "pi" "$(oc_env_own dev2)
TMUX=/tmp/oc-sockA,111,0
TMUX_PANE=%9" 100 1024
td_eq "pane id 只存在于**另一个** server → 是孤儿（不许拿别的 server 的表比）" orphan "$(oc_field 1103 7)"
oc_mkproc 1104 "pi" "$(oc_env_own dev2)
TMUX=/tmp/oc-gone,111,0
TMUX_PANE=%9" 100 1024
td_eq "窗口已死（同 server 别的 pane 还活着）→ 是孤儿" orphan "$(oc_field 1104 7)"
oc_mkproc 1105 "pi" "$(oc_env_own dev2)
TMUX=/tmp/oc-missing,111,0
TMUX_PANE=%1" 100 1024
td_eq "server 查询不到 → unjudged（绝不猜成孤儿）" unjudged "$(oc_field 1105 7)"
oc_mkproc 1106 "pi" "$(oc_env_own dev2)" 100 1024
td_eq "完全没有 TMUX_PANE → 是孤儿" orphan "$(oc_field 1106 7)"
fi

# ================================================================ naming
if want naming; then
section "naming · 本项目的孤儿点名 + 可复制命令；别的只计数（3.1–3.4）"
oc_reset_proc
oc_mkproc 1001 "pi --model x" "$(oc_env_own dev2)" 12345 4096
oc_mkproc 1006 "pi" "$(oc_env_foreign)" 100 4096
oc_mkproc 1007 "pi" "PATH=/usr/bin" 100 4096
oc_mkproc 1105 "pi" "$(oc_env_own dev2)
TMUX=/tmp/oc-missing,111,0
TMUX_PANE=%1" 100 4096
out="$(team_orphan_reading)"
td_has "点名本项目的孤儿（pid）" "$out" "1001"
td_has "点名里带席位" "$out" "席位=dev2"
td_has "点名里带**记录任务**并标明来源" "$out" "记录任务=P276"
td_has "点名里带内存" "$out" "4MB"
td_has "点名里带启动时间" "$out" "2023-11-14T22:15:23Z"
td_has "每条孤儿给一条可复制的清理命令" "$out" "team reap 1001 --yes"
td_not_has "别的项目的 pid 不出现" "$out" "1006"
td_not_has "身份为空的 pid 不出现" "$out" "1007"
td_not_has "别的项目的路径不出现" "$out" "$TMP/other-proj"
td_has "别的项目/身份为空只给计数" "$out" "别的项目/身份不明：2 个"
td_has "合计标成下限（≥）" "$out" "合计 ≥ 8MB"
td_has "未判定单独计数" "$out" "未判定：1 个"

# 没有本项目孤儿时：恰好一行、零命令
rm -rf "$PROC"/1001 "$PROC"/1105
one="$(team_orphan_reading)"
td_eq "没有本项目孤儿 → 恰好一行" 1 "$(printf '%s\n' "$one" | grep -c .)"
td_has "那一行说「无本项目孤儿」" "$one" "无本项目孤儿"
td_not_has "零清理命令" "$one" "reap"
rm -rf "$PROC"/1006 "$PROC"/1007
one="$(team_orphan_reading)"
td_eq "全机无孤儿 → 恰好一行「无」" "孤儿席位进程：无" "$one"
fi

# ================================================================ reading
if want reading; then
section "reading · 只增、有界、只读、可关、不进面板（4.1–4.5）"
oc_reset_proc
oc_mkproc 1201 "pi" "$(oc_env_own dev2)" 500 2048
oc_mkproc 1202 "pi" "$(oc_env_foreign)" 500 2048

# 4.3 只读：普查一个文件都不写（连 state 目录都不创建）
rm -rf "$TMP/ro-state"
team_orphan_census >/dev/null
[ -e "$TMP/ro-state" ] && bad "夹具自检失败" || ok "夹具自检：假 state 不存在"
rm -rf "$TMP/ro-state"
TEAM_STATE_DIR="$TMP/ro-state" team_orphan_census >/dev/null
[ -e "$TMP/ro-state" ] && bad "普查创建了 state 目录（只读契约）" || ok "普查不创建 state 目录（只读契约）"
before="$(find "$T" -printf '%P %s\n' 2>/dev/null | sort | sha256sum)"
team_orphan_reading >/dev/null
team_orphan_up_line >/dev/null
after="$(find "$T" -printf '%P %s\n' 2>/dev/null | sort | sha256sum)"
td_eq "读数不写盘（树指纹前后一致）" "$before" "$after"

# 4.1 up 一行 / 4.2 可关
u="$(team_orphan_up_line)"
td_eq "team up 的读数恰好一行" 1 "$(printf '%s\n' "$u" | grep -c .)"
td_has "up 行给计数 + 合计 + 可复制命令" "$u" "team reap --orphans --yes"
off="$(TEAM_ORPHAN_SCAN=0 team_orphan_reading)"
td_eq "TEAM_ORPHAN_SCAN=0 → 一行点名的跳过" 1 "$(printf '%s\n' "$off" | grep -c .)"
td_has "跳过行点名那个键" "$off" "TEAM_ORPHAN_SCAN=0"
off="$(TEAM_ORPHAN_SCAN=0 team_orphan_up_line)"
td_has "up 的跳过行也点名" "$off" "TEAM_ORPHAN_SCAN=0"
td_eq "TEAM_ORPHAN_SCAN=0 时 digest 不加提示" "" "$(TEAM_ORPHAN_SCAN=0 team_orphan_digest_hint)"

# 4.2 只增不改：**既有的每一个块**都必须在读数之前且逐字节不变。两处归一化（先拆 / 后数字）：
#   ① 从读数标记行起截断 —— 这同时钉住「读数整块在最后」（插到开头/中间就会把既有块一起截掉）；
#   ② 抹平容量行里每轮都变的实时数字（RAM 可用 / 临时根 / inode）。
# 既有两组分别给块名哨兵：光比两边相等不够 —— 「插到开头」会把两边都截成空、照样相等（P284 的假阴性）。
oc_project2_setup || bad "夹具项目 2 建不起来：$(tail -1 "$TMP/init2.log")"
ocr() { OC_PROC_ROOT="$PROC" oc_cli "$T2" "$@"; }
# 让假根里的「本项目」就是 $T2（CLI 的 TEAM_MAIN_ROOT 是 $T2 的物理路径）
rm -f "$PROC"/1201
oc_mkproc 1201 "pi" "$(printf 'TEAM_MAIN_ROOT=%s\nTEAM_ROOT=%s\n' "$(cd "$T2" && pwd -P)" "$(cd "$T2" && pwd -P)/.worktrees/dev2")" 500 2048
ps_on_raw="$(oc42_before "$(ocr ps)")"
ps_off_raw="$(oc42_before "$(OC_PROC_ROOT="$PROC" OC_ENV="TEAM_ORPHAN_SCAN=0" oc_cli "$T2" ps)")"
td_eq "4.2 ps 的既有每一行逐字节不变（开/关普查；容量行在内的全部既有块）" \
      "$(printf '%s\n' "$ps_on_raw" | oc42_nums)" "$(printf '%s\n' "$ps_off_raw" | oc42_nums)"
for _blk in 'RAM 可用' '存活：' 'MODEL' 'agent 会话' '活跃窗口'; do
  td_has "4.2 ps 既有块【$_blk】在读数之前（读数整块在最后）" "$ps_on_raw" "$_blk"
done
st_on_raw="$(oc42_before "$(ocr status)")"
st_off_raw="$(oc42_before "$(OC_PROC_ROOT="$PROC" OC_ENV="TEAM_ORPHAN_SCAN=0" oc_cli "$T2" status)")"
td_eq "4.2 status 的既有每一行逐字节不变（开/关普查）" \
      "$(printf '%s\n' "$st_on_raw" | oc42_nums)" "$(printf '%s\n' "$st_off_raw" | oc42_nums)"
for _blk in 'AGENT' 'session: OC2' 'BOARD：'; do
  td_has "4.2 status 既有块【$_blk】在读数之前" "$st_on_raw" "$_blk"
done
td_has "4.1 ps 追加了读数块" "$(ocr ps)" "孤儿席位进程"
td_has "4.1 status 追加了读数块" "$(ocr status)" "孤儿席位进程"
blk_ps="$(ocr ps | sed -n '/^孤儿席位进程/,$p')"
blk_st="$(ocr status | sed -n '/^孤儿席位进程/,$p')"
td_eq "4.1 ps/status 的读数块逐字节一致" "$blk_ps" "$blk_st"
td_has "4.1 点名本项目的孤儿并给可复制命令" "$blk_ps" "team reap 1201 --yes"

# 4.4 面板数据面不变（普查开/关）
pd1="$(OC_PROC_ROOT="$PROC" oc_cli "$T2" __panel-data --no-activity)"
pd2="$(OC_PROC_ROOT="$PROC" OC_ENV="TEAM_ORPHAN_SCAN=0" oc_cli "$T2" __panel-data --no-activity)"
td_not_has "4.4 面板数据面里没有普查读数" "$pd1" "孤儿席位进程"
pd1n="$(printf '%s' "$pd1" | sed -E 's/[0-9]+/N/g')"
pd2n="$(printf '%s' "$pd2" | sed -E 's/[0-9]+/N/g')"
if [ "$pd1n" = "$pd2n" ]; then ok "4.4 面板数据面在普查开/关下一致（抹去数字）"; else bad "4.4 面板数据面在普查开/关下不一致"; fi
fi

# ================================================================ hint
if want hint; then
section "hint · digest 容量行行尾的阈值提示（5.1–5.2）"
oc_reset_proc
oc_project2_setup || bad "夹具项目 2 建不起来"
oc_mkproc 1301 "pi" "$(oc_env_own dev2)" 500 1048576    # 1 GiB
h="$(team_orphan_digest_hint)"
td_has "合计 ≥ 阈值 → 有提示" "$h" "孤儿席位进程合计"
td_has "提示带本项目份额" "$h" "本项目 1024MB"
td_has "提示带可复制命令" "$h" "team reap --orphans --yes"
td_eq "阈值调高到 2048 → 一个字都不加" "" "$(TEAM_ORPHAN_WARN_MB=2048 team_orphan_digest_hint)"
td_eq "阈值正好等于合计（1024）→ 加提示" "$h" "$(TEAM_ORPHAN_WARN_MB=1024 team_orphan_digest_hint)"
td_eq "低于阈值 → 空" "" "$(TEAM_ORPHAN_WARN_MB=1025 team_orphan_digest_hint)"
# 5.2 提示必须落在容量行**行尾**（不新开行）：M50 的归一化只滤 `RAM 可用` 那一行
dg="$(OC_PROC_ROOT="$PROC" oc_cli "$T2" digest 2>/dev/null)"
cap="$(printf '%s\n' "$dg" | grep 'RAM 可用')"
td_has "5.1 digest 的容量行带着提示" "$cap" "孤儿席位进程合计"
td_eq "5.1 提示不新开行（含 RAM 可用的行只有一条）" 1 "$(printf '%s\n' "$dg" | grep -c 'RAM 可用')"
rc=0; OC_PROC_ROOT="$PROC" OC_ENV="TEAM_ORPHAN_WARN_MB=99999999" oc_cli "$T2" digest >/dev/null 2>&1 || rc=$?
td_eq "5.1 阈值之上/之下退出码都是 0" 0 "$rc"
cap2="$(OC_PROC_ROOT="$PROC" OC_ENV="TEAM_ORPHAN_WARN_MB=99999999" oc_cli "$T2" digest 2>/dev/null | grep 'RAM 可用')"
td_not_has "5.1 低于阈值时容量行一个字都不加" "$cap2" "孤儿席位进程合计"
fi

# ================================================================ seams
if want seams; then
section "seams · /proc 读不到的四种边界一律跳过、绝不猜（4.3）"
oc_reset_proc
oc_mkproc 1401 "pi" "$(oc_env_own dev2)" 100 1024
chmod 000 "$PROC/1401/environ"
if [ "$(id -u)" = "0" ]; then
  skip "以 root 跑：chmod 000 挡不住读 → 「权限拒绝」这一臂跳过"
else
  td_eq "environ 读不到（权限拒绝）→ 跳过，不点名也不计数" "" "$(oc_field 1401 1)"
fi
chmod 644 "$PROC/1401/environ"
oc_mkproc 1402 "pi" "$(oc_env_own dev2)" 100 1024
rm -f "$PROC/1402/environ"; ln -s "$TMP/does-not-exist" "$PROC/1402/environ"
td_eq "environ 中途消失（悬空软链）→ 跳过" "" "$(oc_field 1402 1)"
oc_mkproc 1403 "pi" "$(oc_env_own dev2)" 100 1024
: > "$PROC/1403/environ"
td_eq "空 environ（读得到、没身份）→ anon，不是跳过" anon "$(oc_field 1403 2)"
oc_mkproc 1404 "pi" "$(oc_env_own dev2)" 100 1024
rm -f "$PROC/1404/status" "$PROC/1404/stat"
rec="$(oc_record 1404)"
td_eq "缺字段仍是一条记录（start/rss = '-'）" "$(printf '1404\town\tdev2\tP276\t-\t-\torphan')" "$rec"
oc_mkproc 1405 "pi" "$(oc_env_own dev2)" 100 1024
rm -f "$PROC/1405/cmdline"
td_eq "cmdline 读不到 → 跳过" "" "$(oc_field 1405 1)"
n="$(team_orphan_census | wc -l | tr -d ' ')"
team_orphan_census >/dev/null
td_eq "普查有界且不因边界条目失败（行数稳定）" "$n" "$(team_orphan_census | wc -l | tr -d ' ')"
fi

# ================================================================ reap
if want reap; then
section "reap · 只按 pid、发信号前复验、有审计、--yes 是唯一授权（6.1–6.7）"
if ! oc_project2_setup; then
  bad "夹具项目 2 建不起来：$(tail -1 "$TMP/init2.log")"
else
  log="$T2/.pi/team/state/reap.log"

  # ── 6.1 计划态：一个信号都不发、reap.log 不增长、退 0 ──
  rp="$(oc_spawn_orphan "$T2" "$T2/.worktrees/dev2")"
  n0=0; [ -f "$log" ] && n0="$(wc -l < "$log")"
  plan="$(oc_cli "$T2" reap --orphans)"; prc=$?
  td_eq "6.1 计划态退 0" 0 "$prc"
  td_has "6.1 计划点名真 pid" "$plan" "$rp"
  td_has "6.1 计划说将发 SIGTERM" "$plan" "SIGTERM"
  kill -0 "$rp" 2>/dev/null && ok "6.1 计划态一个信号都没发（进程还活着）" || bad "6.1 计划态把进程杀了"
  n1=0; [ -f "$log" ] && n1="$(wc -l < "$log")"
  td_eq "6.1 reap.log 未增长" "$n0" "$n1"

  # ── 6.5 授权矩阵：环境变量/配置键都不能授权 ──
  for v in "TEAM_ASSUME_YES=1" "TEAM_CONFIRM_WRITES=0" "TEAM_CONFIRM_WRITES=1" "TEAM_ASSUME_YES=1 TEAM_CONFIRM_WRITES=0"; do
    OC_ENV="$v" oc_cli "$T2" reap --orphans >/dev/null 2>&1
    kill -0 "$rp" 2>/dev/null && ok "6.5 [$v] 不能让信号默认发出" || bad "6.5 [$v] 竟然授权了"
  done

  # ── 6.2 授权执行：SIGTERM → 有界等待 → 审计一行 ──
  out="$(oc_cli "$T2" reap --orphans --yes)"; yrc=$?
  td_eq "6.2 执行态退 0" 0 "$yrc"
  td_has "6.2 打印它发了什么（信号）" "$out" "SIGTERM"
  gone=0; for _i in $(seq 1 3000); do kill -0 "$rp" 2>/dev/null || { gone=1; break; }; sleep 0.1; done
  td_eq "6.2 目标已退出" 1 "$gone"
  td_eq "6.2 审计恰好一行" "$((n0 + 1))" "$(wc -l < "$log")"
  aline="$(tail -1 "$log")"
  td_has "6.2 审计带 pid" "$aline" "pid=$rp"
  td_has "6.2 审计带席位" "$aline" "seat=dev2"
  td_has "6.2 审计带信号" "$aline" "signal=SIGTERM"
  td_has "6.2 审计带结果" "$aline" "outcome=gone"

  # ── 6.3 拒绝集合 ──
  anon="$(env -i PATH=/usr/bin:/bin bash -c 'exec -a pi sleep 600' >/dev/null 2>&1 & echo $!)"; sleep 0.2
  OC_SPAWNED="${OC_SPAWNED:-} $anon"
  o="$(oc_cli "$T2" reap "$anon" --yes)"; rc=$?
  td_ne "6.3 身份为空的 pid → 拒发（退非 0）" 0 "$rc"
  td_has "6.3 拒发点名理由" "$o" "没有 teamsmith 身份"
  kill -0 "$anon" 2>/dev/null && ok "6.3 身份为空的进程没被碰" || bad "6.3 身份为空的进程被杀了"
  kill -KILL "$anon" 2>/dev/null || true
  o="$(oc_cli "$T2" reap 1 --yes)"; rc=$?
  td_ne "6.3 不是席位形状的 pid → 拒发" 0 "$rc"
  # 名字/模式不是目标：argv 上给名字 → 拒收；而机器上那些**名字像**的进程一个都不许被碰
  decoy="$(env -i PATH=/usr/bin:/bin bash -c 'exec -a pi sleep 600' >/dev/null 2>&1 & echo $!)"; sleep 0.2
  OC_SPAWNED="${OC_SPAWNED:-} $decoy"
  o="$(oc_cli "$T2" reap pi --yes)"; rc=$?
  td_ne "6.3 argv 给名字 → 拒收（本命令只按 pid 选）" 0 "$rc"
  td_has "6.3 拒收理由点明不接受名字/模式" "$o" "不接受名字或模式"
  kill -0 "$decoy" 2>/dev/null && ok "6.3 「名字像」的进程没被碰（$decoy 还活着）" || bad "6.3 名字像的进程被杀了"
  kill -KILL "$decoy" 2>/dev/null || true
  o="$(oc_cli "$T2" reap --orphans --yes)"; rc=$?
  td_eq "6.3 没有本项目孤儿时执行态退 0" 0 "$rc"
  td_has "6.3 并说明没有目标" "$o" "没有本项目孤儿"

  # ── 6.4 复验（TOCTOU）：真进程 + 假根；FIFO 让「第一次读」与「第二次读」给出不同现场 ──
  ap="$(oc_spawn_orphan "$T2" "$T2/.worktrees/dev2")"
  oc_panes /tmp/oc-sockA '%5'      # 复验时它自己那个 server 上有 %5 活着
  rm -rf "$PROC2"; mkdir -p "$PROC2"; printf 'btime 1700000000\n' > "$PROC2/stat"
  oc_mkfifo_proc "$PROC2" "$ap" environ "$(oc_env_own2 dev2)" "$(oc_env_own2 dev2)
TMUX=/tmp/oc-sockA,111,0
TMUX_PANE=%5"
  o="$(OC_PROC_ROOT="$PROC2" oc_cli "$T2" reap "$ap" --yes 2>&1)"; rc=$?
  td_ne "6.4a pane 回来了 → 拒发（退非 0）" 0 "$rc"
  td_has "6.4a 拒发点名理由（不是孤儿了）" "$o" "pane 又活了"
  kill -0 "$ap" 2>/dev/null && ok "6.4a 目标活着（没发信号）" || bad "6.4a 目标被杀了"
  kill -KILL "$ap" 2>/dev/null || true

  bp="$(oc_spawn_orphan "$T2" "$T2/.worktrees/dev2")"
  rm -rf "$PROC2"; mkdir -p "$PROC2"; printf 'btime 1700000000\n' > "$PROC2/stat"
  oc_mkfifo_proc "$PROC2" "$bp" stat 12345 99999
  o="$(OC_PROC_ROOT="$PROC2" oc_cli "$T2" reap "$bp" --yes 2>&1)"; rc=$?
  td_ne "6.4b 启动时刻变了（pid 被回收）→ 拒发（退非 0）" 0 "$rc"
  td_has "6.4b 拒发点名理由（启动时刻不一致）" "$o" "启动时刻与计划时不一致"
  kill -0 "$bp" 2>/dev/null && ok "6.4b 目标活着（没发信号）" || bad "6.4b 目标被杀了"
  kill -KILL "$bp" 2>/dev/null || true

  # ── 6.3 别的项目的席位：真进程 + 假根（foreign）──
  fp="$(oc_spawn_orphan "$TMP/other-proj" "$TMP/other-proj/worktrees/dev")"
  rm -rf "$PROC2"; mkdir -p "$PROC2"; printf 'btime 1700000000\n' > "$PROC2/stat"
  oc_mkproc "$fp" "pi" "$(oc_env_foreign)" 12345 2048 "$PROC2"
  o="$(OC_PROC_ROOT="$PROC2" oc_cli "$T2" reap "$fp" --yes 2>&1)"; rc=$?
  td_ne "6.3 别的项目的席位 → 拒发" 0 "$rc"
  td_has "6.3 拒发理由" "$o" "别的项目"
  td_not_has "6.3 跨项目零点名（不打印它的项目名/路径）" "$o" "other-proj"
  kill -0 "$fp" 2>/dev/null && ok "6.3 别的项目的进程没被碰" || bad "6.3 别的项目的进程被杀了"
  kill -KILL "$fp" 2>/dev/null || true

  # ── 6.7 静态纪律：不许按名字/模式选进程 ──
  if grep -vE '^[[:space:]]*#' "$SKILL_DIR/scripts/lib/cmd-reap.sh" \
       | grep -nE '(^|[^A-Za-z_])(pkill|killall|pgrep)([^A-Za-z_]|$)' >/dev/null 2>&1; then
    bad "6.7 cmd-reap.sh 里出现了按名字/模式的进程选择"
  else
    ok "6.7 cmd-reap.sh 里没有 pkill/killall/pgrep"
  fi
fi
fi

# ---------------------------------------------------------------- 变异树（逐条红侧）
# 把追加片段写进**最后被 source** 的 cmd-watch.sh：于是任何函数都能被覆盖，而 common.sh 里
# 的原实现仍在（覆盖语义与真实加载顺序一致）。
oc_mutant() { # <名字> <追加定义…> → 变异树的 skill 目录
  local name="$1"; shift
  local mut="$TMP/mut-$name"
  rm -rf "$mut"; mkdir -p "$mut"
  cp -a "$SKILL_DIR/scripts" "$mut/scripts"
  local d; for d in "$@"; do printf '%s\n' "$d" >> "$mut/scripts/lib/cmd-watch.sh"; done
  printf '%s' "$mut"
}
# 在给定库里跑一段片段（夹具的 env 与函数全部继承；$OC_MUT 是这棵树自己的路径）
oc_sh() { # <skill 目录> <bash 片段>
  local lib="$1" code="$2"
  OC_LIB="$lib" OC_CODE="$code" bash -c '
    set -uo pipefail
    . "$OC_LIB/scripts/lib/common.sh"
    for f in "$OC_LIB"/scripts/lib/cmd-*.sh; do . "$f" 2>/dev/null || true; done
    eval "$OC_CODE"
  '
}

# ================================================================ flip
if [ "$MODE" = "flip" ]; then
section "flip · 逐条红侧（破坏 → 指定用例必红 → 还原 → 绿）"
flip_case() { # <名字> <绿片段> <红片段> <变异追加…>
  local name="$1" green="$2" red="$3"; shift 3
  local mut; mut="$(oc_mutant "$name" "$@")"
  local g r
  g="$(OC_MUT="$SKILL_DIR" oc_sh "$SKILL_DIR" "$green" 2>/dev/null)"
  r="$(OC_MUT="$mut" oc_sh "$mut" "$red" 2>/dev/null)"
  if [ "$g" = "GREEN" ]; then ok "$name：还原 → 绿"; else bad "$name：绿侧不成立（$g）"; fi
  if [ "$r" = "RED" ]; then ok "$name：破坏 → 指定用例红"; else bad "$name：破坏后用例没有红（$r）"; fi
}

flip_case p276-flip-shape \
  'oc_mkproc 1004 "bash -lc exec $BIN/pi dispatch-dev.spawn" "$(oc_env_own dev2)" 100 1024; [ -z "$(oc_field 1004 1)" ] && printf GREEN || printf RED' \
  'oc_mkproc 1004 "bash -lc exec $BIN/pi dispatch-dev.spawn" "$(oc_env_own dev2)" 100 1024; [ -n "$(oc_field 1004 1)" ] && printf RED || printf GREEN' \
  'team_orphan_shape_match() { case "${2:-}" in *"${TEAM_ORPHAN_AGENT_BIN:-pi}"*) return 0 ;; esac; return 1; }'

flip_case p276-flip-current-window \
  'oc_panes /tmp/oc-sockA "%5"; oc_mkproc 1101 "pi" "$(oc_env_own dev2)
TMUX=/tmp/oc-sockA,111,0
TMUX_PANE=%5" 100 1024; [ "$(oc_field 1101 7)" = live ] && printf GREEN || printf RED' \
  'oc_panes /tmp/oc-sockA "%5"; oc_mkproc 1101 "pi" "$(oc_env_own dev2)
TMUX=/tmp/oc-sockA,111,0
TMUX_PANE=%5" 100 1024; [ "$(oc_field 1101 7)" = orphan ] && printf RED || printf GREEN' \
  'team_orphan_judge() { if [ "${2:-}" = "${TMUX_PANE:-}" ]; then printf "live\n"; else printf "orphan\n"; fi; }'

flip_case p276-flip-default-server \
  'oc_panes /tmp/oc-sockA "%5"; oc_panes - "%1"; oc_mkproc 1101 "pi" "$(oc_env_own dev2)
TMUX=/tmp/oc-sockA,111,0
TMUX_PANE=%5" 100 1024; [ "$(oc_field 1101 7)" = live ] && printf GREEN || printf RED' \
  'oc_panes /tmp/oc-sockA "%5"; oc_panes - "%1"; oc_mkproc 1101 "pi" "$(oc_env_own dev2)
TMUX=/tmp/oc-sockA,111,0
TMUX_PANE=%5" 100 1024; [ "$(oc_field 1101 7)" = orphan ] && printf RED || printf GREEN' \
  'team_orphan_judge() { local pane="${2:-}" panes; [ -n "$pane" ] || { printf "orphan\n"; return 0; }; panes="$(cat "${OC_PANES_DIR:-/nonexistent}/_default" 2>/dev/null)" || { printf "unjudged\n"; return 0; }; case $'"'"'\n'"'"'"$panes"$'"'"'\n'"'"' in *$'"'"'\n'"'"'"$pane"$'"'"'\n'"'"'*) printf "live\n" ;; *) printf "orphan\n" ;; esac; }'

flip_case p276-flip-unjudged \
  'rm -f "$OC_PANES_DIR/$(printf "%s" /tmp/oc-missing | tr -c "A-Za-z0-9" "_")"; oc_mkproc 1105 "pi" "$(oc_env_own dev2)
TMUX=/tmp/oc-missing,111,0
TMUX_PANE=%1" 100 1024; [ "$(oc_field 1105 7)" = unjudged ] && printf GREEN || printf RED' \
  'rm -f "$OC_PANES_DIR/$(printf "%s" /tmp/oc-missing | tr -c "A-Za-z0-9" "_")"; oc_mkproc 1105 "pi" "$(oc_env_own dev2)
TMUX=/tmp/oc-missing,111,0
TMUX_PANE=%1" 100 1024; [ "$(oc_field 1105 7)" = orphan ] && printf RED || printf GREEN' \
  'team_orphan_judge() { local tmx="${1:-}" pane="${2:-}" sock panes; [ -n "$pane" ] || { printf "orphan\n"; return 0; }; [ -n "$tmx" ] || { printf "orphan\n"; return 0; }; sock="${tmx%%,*}"; if ! panes="$(team_orphan_server_panes "$sock")"; then printf "orphan\n"; return 0; fi; case $'"'"'\n'"'"'"$panes"$'"'"'\n'"'"' in *$'"'"'\n'"'"'"$pane"$'"'"'\n'"'"'*) printf "live\n" ;; *) printf "orphan\n" ;; esac; }'

flip_case p276-flip-naming \
  'oc_mkproc 1006 "pi" "$(oc_env_foreign)" 100 1024; case "$(team_orphan_reading)" in *1006*) printf RED ;; *) printf GREEN ;; esac' \
  'oc_mkproc 1006 "pi" "$(oc_env_foreign)" 100 1024; case "$(team_orphan_reading)" in *1006*) printf RED ;; *) printf GREEN ;; esac' \
  'team_orphan_reading() { team_orphan_scan; local r pid; for r in "${TEAM_ORPHAN_OTHER_LINES[@]}"; do IFS=$'"'"'\t'"'"' read -r pid _ <<< "$r"; printf "  别的项目：%s\n" "$pid"; done; }'

flip_case p276-flip-panel \
  'oc_project2_setup >/dev/null 2>&1; case "$(oc_cli_skill "$OC_MUT" "$T2" __panel-data --no-activity 2>/dev/null)" in *"孤儿席位进程"*) printf RED ;; *) printf GREEN ;; esac' \
  'oc_project2_setup >/dev/null 2>&1; case "$(oc_cli_skill "$OC_MUT" "$T2" __panel-data --no-activity 2>/dev/null)" in *"孤儿席位进程"*) printf RED ;; *) printf GREEN ;; esac' \
  'eval "team_cmd_panel_data__p276() $(declare -f team_cmd_panel_data | tail -n +2)"' \
  'team_cmd_panel_data() { team_cmd_panel_data__p276 "$@"; team_orphan_reading; }'

flip_case p276-flip-hint-line \
  'oc_mkproc 1301 "pi" "$(oc_env_own dev2)" 500 1048576; h="$(team_orphan_digest_hint)"; case "$h" in $'"'"'\n'"'"'*) printf RED ;; *) printf GREEN ;; esac' \
  'oc_mkproc 1301 "pi" "$(oc_env_own dev2)" 500 1048576; h="$(team_orphan_digest_hint)"; case "$h" in $'"'"'\n'"'"'*) printf RED ;; *) printf GREEN ;; esac' \
  'team_orphan_digest_hint() { printf "\n  ｜ 孤儿席位进程合计（独立一行：M50 的归一化会漏掉它）"; }'

# 4.2 的红侧：把读数**插进容量行**（不再整块在最后）→ 「既有块都在读数之前」必须红。
# 变异形态 = 原实现包一层：每打完一行，碰到容量行就把读数插进去（管道的子壳继承所有函数定义）。
flip_case p276-flip-into-capacity \
  'oc_project2_setup >/dev/null 2>&1; on="$(OC_PROC_ROOT="$PROC" oc_cli_skill "$OC_MUT" "$T2" ps 2>/dev/null)"; off="$(OC_PROC_ROOT="$PROC" OC_ENV="TEAM_ORPHAN_SCAN=0" oc_cli_skill "$OC_MUT" "$T2" ps 2>/dev/null)"; v=0; [ "$(oc42_before "$on" | oc42_nums)" = "$(oc42_before "$off" | oc42_nums)" ] || v=1; for w in "RAM 可用" "存活：" "MODEL" "agent 会话" "活跃窗口"; do case "$(oc42_before "$on")" in *"$w"*) ;; *) v=1 ;; esac; done; [ "$v" = 0 ] && printf GREEN || printf RED' \
  'oc_project2_setup >/dev/null 2>&1; on="$(OC_PROC_ROOT="$PROC" oc_cli_skill "$OC_MUT" "$T2" ps 2>/dev/null)"; off="$(OC_PROC_ROOT="$PROC" OC_ENV="TEAM_ORPHAN_SCAN=0" oc_cli_skill "$OC_MUT" "$T2" ps 2>/dev/null)"; v=0; [ "$(oc42_before "$on" | oc42_nums)" = "$(oc42_before "$off" | oc42_nums)" ] || v=1; for w in "RAM 可用" "存活：" "MODEL" "agent 会话" "活跃窗口"; do case "$(oc42_before "$on")" in *"$w"*) ;; *) v=1 ;; esac; done; [ "$v" = 0 ] && printf GREEN || printf RED' \
  'eval "team_cmd_ps__p276() $(declare -f team_cmd_ps | tail -n +2)"' \
  'team_cmd_ps() { team_cmd_ps__p276 "$@" | while IFS= read -r l; do printf "%s\n" "$l"; case "$l" in *"RAM 可用"*) team_orphan_reading ;; esac; done; }'

# 1.1 的红侧：把实现改成「每个 pid 调一次 ps」（丢掉机器级粗筛）→ 「一次普查只 fork 一次 ps」必须红。
flip_case p276-flip-one-ps \
  'oc_mk_ps_shim; l="$TMP/flip-ps.log"; : > "$l"; export OC_PS_LOG="$l"; TEAM_ORPHAN_PROC_ROOT=/proc team_orphan_census >/dev/null 2>&1; n="$(grep -c . "$l" 2>/dev/null || true)"; n="${n:-0}"; unset OC_PS_LOG; oc_rm_ps_shim; [ "$n" = 1 ] && printf GREEN || printf RED' \
  'oc_mk_ps_shim; l="$TMP/flip-ps.log"; : > "$l"; export OC_PS_LOG="$l"; TEAM_ORPHAN_PROC_ROOT=/proc team_orphan_census >/dev/null 2>&1; n="$(grep -c . "$l" 2>/dev/null || true)"; n="${n:-0}"; unset OC_PS_LOG; oc_rm_ps_shim; [ "$n" = 1 ] && printf GREEN || printf RED' \
  'team_orphan_candidates() { local root base_a base_p p args d; root="$(team_orphan_proc_root)"; base_a="$(basename -- "$(team_agent_bin_path 2>/dev/null || true)")"; [ -n "$base_a" ] || base_a=pi; base_p="$(basename -- "$(team_pm_bin_path 2>/dev/null || true)")"; [ -n "$base_p" ] || base_p="$base_a"; for d in "$root"/*/; do [ -d "$d" ] || continue; p="$(basename -- "${d%/}")"; case "$p" in ""|*[!0-9]*) continue ;; esac; args="$(ps -o args= -p "$p" 2>/dev/null | head -1)"; [ -n "$args" ] || continue; case "$args" in *"$base_a"*|*"$base_p"*) ;; *) continue ;; esac; printf "%s\t%s\n" "$p" "$args"; done; }'

flip_case p276-flip-verify \
  'oc_mkproc 1501 "pi" "$(oc_env_own dev2)" 12345 1024; team_reap_verify 1501 99999 >/dev/null 2>&1 && printf RED || printf GREEN' \
  'oc_mkproc 1501 "pi" "$(oc_env_own dev2)" 12345 1024; team_reap_verify 1501 99999 >/dev/null 2>&1 && printf RED || printf GREEN' \
  'team_reap_verify() { REAP_REASON=""; REAP_SEAT="dev2"; return 0; }'
fi

printf '\n\033[1m== 结果 ==\033[0m  ✓ %s  ✗ %s  SKIP %s\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
