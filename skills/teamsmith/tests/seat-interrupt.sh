#!/usr/bin/env bash
# P292 · 「打断席位长回合」入口夹具（change: seat-interrupt-entry · apply）
#
#   bash skills/teamsmith/tests/seat-interrupt.sh                        # 全部组
#   bash skills/teamsmith/tests/seat-interrupt.sh --select plan,audit    # 只跑指定组
#   bash skills/teamsmith/tests/seat-interrupt.sh --flip                 # 逐条红侧（破坏 → 必红 → 还原 → 绿）
#
# 组：plan / target / execute / audit / refuse / reason / guard / survive / read / route / hygiene / live
#
# 判据（合同）：openspec/changes/seat-interrupt-entry/specs/boundary/spec.md 的两条 ADDED。
# 现场：真 git 项目（team init）+ **真进程**（stub agent：argv 的形状命中本项目配置的 agent 可执行
#   文件，身份写在它自己的 environ 里）+ 私有 tmux 桩（PATH 最前，只回答 list-windows / list-panes /
#   display-message 三个**只读**查询）——「名册 → 记录里的窗口 → pane → pid → 身份与启动时刻」这条
#   证明链因此可以逐条造现场（pane 死掉、pid 被回收、身份属于别的项目…），全程不碰真 server。
#   另有一组 `live` 用**真私有 tmux server**（私有 TMUX_TMPDIR）跑端到端，没有 tmux 时可见 SKIP。
# 退出码：0 = 全部预期成立；1 = 有失败；3 = 临时根建不起来。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# shellcheck source=tests/lib/tmp-root.sh
. "$SELF_DIR/lib/tmp-root.sh"
# P162：破坏性 tmux 调用（new-session / kill-server）动手前先证明私有 socket 生效
# shellcheck source=tests/lib/tmux-iso.sh
. "$SELF_DIR/lib/tmux-iso.sh"

MODE="all"; SEL_GROUPS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --select) shift; IFS=',' read -r -a _g <<< "${1:-}"; SEL_GROUPS+=("${_g[@]}"); shift ;;
    --flip) MODE="flip"; shift ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) printf 'seat-interrupt.sh：未知参数 %s\n' "$1" >&2; exit 2 ;;
  esac
done
want() {
  [ "$MODE" = "flip" ] && return 1
  [ "${#SEL_GROUPS[@]}" -eq 0 ] && return 0
  local g; for g in "${SEL_GROUPS[@]}"; do [ "$g" = "$1" ] && return 0; done
  return 1
}

OC_CALLER_TMUX_TMPDIR="${TMUX_TMPDIR:-/tmp}"     # 收尾证明「不是调用者那个 server」用
export OC_CALLER_TMUX_TMPDIR
OC_LIVE_UP=0
export OC_LIVE_UP
TMP="$(tmp_root_create seat-interrupt)" || exit 3
TMP="$(cd -P "$TMP" && pwd)"                    # 物理路径（身份判据里的路径比较要它）
export HOME="$TMP/home"; mkdir -p "$HOME"
cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0
  local p
  for p in ${OC_SPAWNED:-}; do kill -KILL "$p" 2>/dev/null || true; done
  if [ -f "${OC_PIDFILE:-}" ]; then
    while IFS= read -r p; do case "$p" in ''|*[!0-9]*) continue ;; esac; kill -KILL "$p" 2>/dev/null || true; done < "$OC_PIDFILE"
  fi
  # 真私有 server：先证明 socket 私有了再收（收尾路径不许 exit）
  if [ -n "${OC_REAL_TMUX:-}" ] && [ "${OC_LIVE_UP:-0}" = "1" ]; then
    PATH="${REAL_PATH:-$PATH}" tmux_iso_guard_soft "seat-interrupt" "收尾：销毁本轮私有 server" \
      --tmpdir "${TMUX_TMPDIR:-}" --own-root "$TMP" --caller-tmpdir "$OC_CALLER_TMUX_TMPDIR" \
      && env -u TMUX -u TMUX_PANE TMUX_TMPDIR="${TMUX_TMPDIR:-}" "$OC_REAL_TMUX" kill-server 2>/dev/null || true
  fi
  tmp_root_reap_all
  # 收尾自检（PM 2026-10-16 的提醒）：根没被回收就**大声报错并退非 0** —— 静默泄漏是实缺陷，
  # 不是「小事」：一次 1.6 GB，残留还会让 --sweep 的「占用」判据与磁盘预算失真。
  if [ -e "$TMP" ]; then
    printf '\n\033[31m✗ 收尾：临时根没有回收（%s）\033[0m\n' "$TMP" >&2
    printf '   契约：tests/lib/tmp-root.sh 的 tmp_root_reap_all（台账基 = 创建时的 $(team_tmp_root)）\n' >&2
    exit 1
  fi
  return 0
}
trap cleanup EXIT

PASS=0; FAIL=0; SKIP=0
ok()   { PASS=$((PASS + 1)); printf '  \033[32m✓\033[0m %s\n' "$*"; }
bad()  { FAIL=$((FAIL + 1)); printf '  \033[31m✗\033[0m %s\n' "$*"; }
skip() { SKIP=$((SKIP + 1)); printf '  \033[33mSKIP\033[0m %s\n' "$*"; }
section() { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
td_eq() { if [ "$2" = "$3" ]; then ok "$1（=$2）"; else bad "$1：期望 [$2] 实际 [$3]"; fi; }
td_has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1：文本里没有 [$3]（实际：$(printf '%s' "$2" | head -c 400)）" ;; esac; }
td_not_has() { case "$2" in *"$3"*) bad "$1：不该出现 [$3]（实际：$(printf '%s' "$2" | head -c 400)）" ;; *) ok "$1" ;; esac; }
td_ne() { if [ "$2" != "$3" ]; then ok "$1"; else bad "$1：期望不等于 [$2]"; fi; }
td_alive() { if kill -0 "$2" 2>/dev/null; then ok "$1（pid $2 还活着）"; else bad "$1：pid $2 已经不在"; fi; }

# ---------------------------------------------------------------- 夹具骨架
T2="$TMP/repo"                     # 真 git 项目（team init）
BIN="$TMP/bin"                     # 私有桩：tmux（只读查询）+ agent（stub pi）
PANES="$TMP/panes"                 # 每个窗口一份 pane 记录：<pane_pid> <pane_dead> <pane_current_command>
PI_AGENT_DIR="$TMP/pi-agent"       # 会话文件的根（TEAM_PI_AGENT_DIR 接缝）
mkdir -p "$T2" "$BIN" "$PANES" "$PI_AGENT_DIR" "$TMP/home" "$TMP/tmux" "$TMP/meetings"

# tmux 桩：**只**回答只读查询（夹具绝不碰任何真 server）。窗口表 = $OC_WINDOWS；pane 表 = $OC_PANES_DIR/<窗口名>。
cat > "$BIN/tmux" <<'STUB'
#!/usr/bin/env bash
# 全局选项（`-S <socket>` / `-L <name>` / `-f <file>` / `-2` / `-u`）可以排在动词前面：先跳过它们，
# `verb` 才是动词 —— `team_orphan_server_panes` 发的是 `tmux -S <sock> list-panes -a -F …`，
# 不认这一点的话它每次都落到 *) exit 1（孤儿判据变成 unjudged，而不是 live/orphan）。
while [ $# -gt 0 ]; do
  case "$1" in
    -S|-L|-f) shift; [ $# -gt 0 ] && shift ;;
    -2|-u|-q|-N) shift ;;
    *) break ;;
  esac
done
verb="${1:-}"
[ -n "${OC_CALL_LOG:-}" ] && printf '%s\n' "$verb" >> "$OC_CALL_LOG"
case "$verb" in
  list-windows)
    [ -f "${OC_WINDOWS:-/nonexistent}" ] || exit 1
    cat "$OC_WINDOWS"; exit 0 ;;
  list-panes)
    # OC_PANES_BUDGET（一个装整数的小文件）：用完了就报「找不到 pane」—— 造「第一次读到了、
    # 复验时 pane 已经变了」这条确定性 TOCTOU 现场
    if [ -n "${OC_PANES_BUDGET:-}" ] && [ -f "$OC_PANES_BUDGET" ]; then
      n="$(cat "$OC_PANES_BUDGET" 2>/dev/null || printf 0)"
      case "$n" in ''|*[!0-9]*) n=0 ;; esac
      [ "$n" -gt 0 ] || exit 1
      printf '%s\n' "$((n - 1))" > "$OC_PANES_BUDGET"
    fi
    target=""; fmt=""; all=0
    while [ $# -gt 0 ]; do
      case "$1" in
        -t) target="${2:-}"; shift 2 ;;
        -F) fmt="${2:-}"; shift 2 ;;
        -a) all=1; shift ;;
        *) shift ;;
      esac
    done
    if [ "$all" = 1 ]; then
      # 孤儿普查（team reap / team ps 的判据）问的是「这个 server 上有哪些 pane」：夹具的 pane 表
      # （OC_PANES_DIR 的每个文件）就是答案 —— pane id 取窗口名的 `%名字` 形状。
      for f in "${OC_PANES_DIR:-/nonexistent}"/*; do
        [ -f "$f" ] || continue
        printf '%%%s\n' "$(basename "$f")"
      done
      exit 0
    fi
    key="${target##*:}"
    f="${OC_PANES_DIR:-/nonexistent}/$key"
    [ -f "$f" ] || exit 1
    read -r pane dead cmd < "$f"
    case "$fmt" in
      *pane_dead*) printf '1 %s %s %s\n' "$pane" "$dead" "${cmd:-bash}" ;;
      *pane_active*) printf '1 %s\n' "$pane" ;;
      *) printf '%s\n' "$pane" ;;
    esac
    exit 0 ;;
  display-message)
    fmt=""; target=""
    while [ $# -gt 0 ]; do
      case "$1" in
        -t) target="${2:-}"; shift 2 ;;
        -p) ;;
        *) fmt="$1" ;;
      esac
      shift
    done
    key="${target##*:}"
    f="${OC_PANES_DIR:-/nonexistent}/$key"
    [ -f "$f" ] || exit 1
    read -r pane dead cmd < "$f"
    case "$fmt" in
      *pane_current_command*) printf '%s\n' "${cmd:-bash}" ;;
      *window_name*)          printf '%s\n' "$key" ;;
      *session_name*)         printf '%s\n' "${TEAM_SESSION:-oc2}" ;;
      *pane_pid*)             printf '%s\n' "$pane" ;;
      *) exit 1 ;;
    esac
    exit 0 ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$BIN/tmux"

# stub agent：argv[0] 的 basename 是 `pi`（形状命中本项目配置的 agent 可执行文件），行为按 argv[1]。
# P313：循环由 lib/bounded-spin.sh 一处实现三条边界（TERM 就退 / 父没了就退 / 硬上限 1800s）。
# `stubborn` 那一档**故意**忽略 TERM（它就是「TERM 不生效 → 升级 KILL」的被测对象），但仍受
# 父进程与硬上限约束 —— 被 KILL 掉的夹具运行不会再留下一个永久自旋的席位进程。
{
  printf '#!/usr/bin/env bash\n'
  printf '. %q\n' "$SKILL_DIR/tests/lib/bounded-spin.sh"
  cat <<'STUB'
mode="${1:-term}"
case "$mode" in
  stubborn) BOUNDED_SPIN_IGNORE_TERM=1 ;;       # 被测对象：忽略 TERM（TERM→KILL 升级那一档）
  touch)    BOUNDED_SPIN_TERM='touch "$OC_SESSION_FILE" 2>/dev/null' ;;
  order)    BOUNDED_SPIN_TERM='if [ -n "$OC_REASON" ] && [ -f "$OC_THREAD" ] && grep -qF -- "$OC_REASON" "$OC_THREAD" 2>/dev/null; then printf "ordered\n" > "$OC_ORDER_FILE"; else printf "unordered\n" > "$OC_ORDER_FILE"; fi' ;;
  hold)     shift; "$OC_TEAM_CLI" "$@"; exit $? ;;   # 让 CLI 成为**本进程的子进程**（「调用者的祖先」那一条）
esac
export BOUNDED_SPIN_IGNORE_TERM BOUNDED_SPIN_TERM
bounded_spin 0.2 1800 - - "${OC_STUB_PARENT:-$PPID}"
STUB
} > "$BIN/pi"
chmod +x "$BIN/pi"

REAL_PATH="$PATH"                  # 真 PATH 先留一份（live 组要绕开桩）
OC_REAL_TMUX="$(PATH="$REAL_PATH" command -v tmux 2>/dev/null || true)"   # 真要用的 tmux（不是桩）
export PATH="$BIN:$PATH" OC_PANES_DIR="$PANES" OC_WINDOWS="$TMP/windows"
export SKILL_DIR T2 TMP BIN PANES PI_AGENT_DIR REAL_PATH OC_CHILD_TMPDIR
# 子进程的私有 TMPDIR：**不能**在夹具自己的 shell 里 export TMPDIR —— tmp-root.sh 的台账与回收都按
# 「创建时的 ${TMPDIR:-/tmp}」算，中途改基就找不到自己的台账，`tmp_root_reap_all` 静默什么都不收
# （实测：34 个根、	1.6 GB 留在 /tmp；P292 的实体教训）。所以只给**子进程**传。
OC_CHILD_TMPDIR="$TMP/tmp"; mkdir -p "$OC_CHILD_TMPDIR"
# 夹具自己的 tmux 调用必须落在**私有** server 上（M28/#1250）：顶层 unset TMUX + 私有 TMUX_TMPDIR。
unset TMUX TMUX_PANE 2>/dev/null || true
# P309：socket 目录不挂临时根下（临时根名带项目 ns 后，<run>/tmux/tmux-<uid>/... 会越过 AF_UNIX 的
# 107 字节，隔离前置直接硬停）。基址取短的：先试解析出的临时根，放不下退平台默认（tmp-root.sh 一处实现）。
TMUX_TMPDIR="$(tmp_root_socket_dir tmux "tmux-$(id -u)/default")" || TMUX_TMPDIR="$TMP/tmux"
export TMUX_TMPDIR
OC_ENV=""; export OC_ENV

oc_win_set() { printf '%s\n' "$@" > "$TMP/windows"; }
oc_pane_set() { # <窗口名> <pane_pid> [pane_dead] [前台命令]
  printf '%s %s %s\n' "$2" "${3:-0}" "${4:-bash}" > "$PANES/$1"
}
oc_pane_del() { rm -f "$PANES/$1"; }

# ---------------------------------------------------------------- 项目与席位现场
WT="$T2/.worktrees/dev2"
SID="p292-fixture-sid"
BRIEF="docs/team/tasks/P292-fixture.md"
ST="$T2/.pi/team/state"
LOG="$ST/interrupt.log"
TH="$T2/docs/team/threads/dev2.md"
IN="$T2/docs/team/inbox/dev2.md"
export WT SID BRIEF ST LOG TH IN

oc_run_cli() { # <从哪个目录跑> <PATH> <argv…>（子进程私有 TMPDIR：只给子进程，不动自己的基）
  local d="$1" p="$2"; shift 2
  ( cd "$d" && env -u TMUX -u TMUX_PANE -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
      -u TEAM_STATE_DIR -u TEAM_DOCS_ABS -u TEAM_DOCS_DIR -u TEAM_AGENTS -u TEAM_PM_WINDOW -u TEAM_SKILL_DIR \
      -u TEAM_AGENT_CMD -u TEAM_AGENT_BIN \
      PATH="$p" HOME="$TMP/home" TMPDIR="$OC_CHILD_TMPDIR" \
      TEAM_PI_AGENT_DIR="$PI_AGENT_DIR" TEAM_PI_BIN="$BIN/pi" \
      TEAM_MEETINGS_DIR="$TMP/meetings" ${OC_ENV:-} bash "$SKILL_DIR/scripts/team" "$@" 2>&1 )
}
oc_cli()      { oc_run_cli "$1" "$BIN:$REAL_PATH" "${@:2}"; }
oc_cli_real() { oc_run_cli "$1" "$REAL_PATH" "${@:2}"; }

oc_session_file_for() { # <sid> → 该会话在夹具 PI_AGENT_DIR 里的文件（Pi 的 cwd 编码规则）
  local sid="$1" safe
  safe="$(printf '%s' "$WT" | sed -e 's|^/||' -e 's|[/\\:]|-|g')"
  printf '%s/sessions/--%s--/2026-01-01T00-00-00-000Z_%s.jsonl\n' "$PI_AGENT_DIR" "$safe" "$sid"
}
oc_session_write() { # <sid> <epoch> → 会话文件（内容已知，mtime 就是证据）；stdout = 路径
  local f; f="$(oc_session_file_for "$1")"
  mkdir -p "$(dirname "$f")"
  printf '{"session":"%s"}\n' "$1" > "$f"
  touch -d "@${2:-1700000000}" "$f"
  printf '%s\n' "$f"
}
oc_level() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
oc_log_n() { if [ -f "$LOG" ]; then wc -l < "$LOG" | tr -d ' '; else printf '0'; fi; }
oc_reap_n() { if [ -f "$ST/reap.log" ]; then wc -l < "$ST/reap.log" | tr -d ' '; else printf '0'; fi; }
oc_fp() { if [ -e "$1" ]; then sha256sum "$1" | cut -d' ' -f1; else printf 'absent\n'; fi; }
oc_wt_fp() { ( cd "$WT" && find . -printf '%P %s\n' 2>/dev/null | sort | sha256sum | cut -d' ' -f1 ); }
oc_wt_reset() { git -C "$WT" checkout -q -- . 2>/dev/null || true; git -C "$WT" clean -qfdx 2>/dev/null || true; }
oc_th_n() { grep -c '^### ' "$TH" 2>/dev/null || true; }
oc_in_n() { grep -c '^- ' "$IN" 2>/dev/null || true; }

oc_setup_project() { # 一次把项目 + 席位现场建起来（幂等）
  [ -f "$T2/.pi/team/config.sh" ] && return 0
  ( cd "$T2" && git init -q -b main && git config user.email oc@fixture && git config user.name oc \
      && printf '{"name":"repo","scripts":{"verify":"true"}}\n' > package.json \
      && git add -A && git commit -qm init ) >/dev/null 2>&1
  oc_cli "$T2" init --no-skills --session OC2 --agents "dev dev2 verify" --vcs local --gates true \
    --docs docs/team --task-models 'code=oc/fast' --pm-model 'oc/pm' --pm-window pm \
    >"$TMP/init.log" 2>&1 || { printf 'seat-interrupt：team init 失败：\n%s\n' "$(tail -3 "$TMP/init.log")" >&2; return 1; }
  mkdir -p "$ST" "$T2/docs/team/threads" "$T2/docs/team/inbox" "$T2/docs/team/tasks"
  # 席位工作树：真实 git worktree + 本任务的规范分支（dispatch 的分支守卫认得它）
  git -C "$T2" worktree add -q -b task/P292-x "$WT" main >/dev/null 2>&1
  printf '# P292 夹具任务\n\ncategory: code\nanchor: none (infra) — 夹具的锚点\n' > "$T2/$BRIEF"
  # 席位派单记录：完整 v1（team_assignment_parse 的必需字段一个不少）
  printf 'assignment_version=1\ntask=P292\ntaskfile=%s\ncategory=code\nbranch=task/P292-x\nworktree=%s\nwindow=dev2\nseat=dev2\nmodel=oc/fast\nselected_via=policy\nlaunch_via=assignment\nsid=%s\nlaunch_nonce=oc-nonce\nstarted=2026-01-01T00:00:00Z\nsid_bytes=0\nmode=continued\n' \
    "$T2/$BRIEF" "$WT" "$SID" > "$ST/dev2.env"
  printf '### 2026-01-01T00:00:00Z · from: pm · re: -\n夹具线程的既有内容。\n' > "$TH"
  printf -- '- 2026-01-01T00:00:00Z [manual] agent:pm · 夹具收件箱的既有内容\n' > "$IN"
  oc_session_write "$SID" 1700000000 >/dev/null
  oc_win_set dev2
  oc_pane_del dev2
  return 0
}

oc_seat_track() {
  OC_SPAWNED="${OC_SPAWNED:-} $1"
  [ -n "${OC_PIDFILE:-}" ] && printf '%s\n' "$1" >> "$OC_PIDFILE"
  return 0
}
oc_spawn_seat() { # <mode> [额外 argv…] → pid（真进程；身份写在它自己的 environ 里）
  local mode="$1"; shift
  # 后台起、 stdout 写进 /dev/null：**不能**用命令替换包一个后台作业（bash 会等它，夹具会挂）
  ( cd "$WT" && exec env -u TMUX -u TMUX_PANE TEAM_MAIN_ROOT="$T2" TEAM_ROOT="$WT" \
      TMPDIR="$OC_CHILD_TMPDIR" \
      OC_REASON="${OC_REASON:-}" OC_THREAD="$TH" OC_ORDER_FILE="$TMP/order" \
      OC_SESSION_FILE="$(oc_session_file_for "$SID")" OC_TEAM_CLI="$SKILL_DIR/scripts/team" \
      OC_STUB_PARENT="$$" "$BIN/pi" "$mode" "$@" ) >/dev/null 2>&1 &
  printf '%s\n' "$!"
}
oc_spawn_identity_seat() { # <environ 文本> → pid（身份可以被故意写错，用来造「不是记录里那个工作树」）
  local envtext="$1"
  ( cd "$T2" && exec env -u TMUX -u TMUX_PANE TMPDIR="$OC_CHILD_TMPDIR" $(printf '%s' "$envtext" | tr '\n' ' ') "$BIN/pi" term ) >/dev/null 2>&1 &
  printf '%s\n' "$!"
}
oc_foreign_seat() { # 另一个项目的席位进程（真进程；身份指向别处）
  mkdir -p "$TMP/other-proj/.worktrees/dev"
  ( cd "$TMP" && exec env -u TMUX -u TMUX_PANE TMPDIR="$OC_CHILD_TMPDIR" TEAM_MAIN_ROOT="$TMP/other-proj" \
      TEAM_ROOT="$TMP/other-proj/.worktrees/dev" "$BIN/pi" term ) >/dev/null 2>&1 &
  printf '%s\n' "$!"
}

# 变异树（逐条红侧）：把追加片段写进**最后被 source** 的 cmd-watch.sh —— 任何函数都能被覆盖，
# 而原实现仍在（覆盖语义与真实加载顺序一致）。
oc_mutant() { # <名字> <追加定义…> → 变异树的 skill 目录
  local name="$1"; shift
  local mut="$TMP/mut-$name"
  rm -rf "$mut"; mkdir -p "$mut"
  cp -a "$SKILL_DIR/scripts" "$mut/scripts"
  local d; for d in "$@"; do printf '%s\n' "$d" >> "$mut/scripts/lib/cmd-watch.sh"; done
  printf '%s' "$mut"
}
oc_sh() { # <skill 目录> <bash 片段>（夹具的 env 与函数全部继承）
  local lib="$1" code="$2"
  OC_LIB="$lib" OC_CODE="$code" TMPDIR="$OC_CHILD_TMPDIR" bash -c '
    set -uo pipefail
    . "$OC_LIB/scripts/lib/common.sh"
    for f in "$OC_LIB"/scripts/lib/cmd-*.sh; do . "$f" 2>/dev/null || true; done
    eval "$OC_CODE"
  '
}
oc_cli_mut() { # <变异树> <argv…>：用同一套夹具现场跑那棵树里的 CLI
  local lib="$1"; shift
  ( cd "$T2" && env -u TMUX -u TMUX_PANE -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
      -u TEAM_STATE_DIR -u TEAM_DOCS_ABS -u TEAM_DOCS_DIR -u TEAM_AGENTS -u TEAM_PM_WINDOW -u TEAM_SKILL_DIR \
      -u TEAM_AGENT_CMD -u TEAM_AGENT_BIN \
      PATH="$BIN:$REAL_PATH" HOME="$TMP/home" TMPDIR="$OC_CHILD_TMPDIR" \
      TEAM_PI_AGENT_DIR="$PI_AGENT_DIR" TEAM_PI_BIN="$BIN/pi" \
      TEAM_MEETINGS_DIR="$TMP/meetings" ${OC_ENV:-} bash "$lib/scripts/team" "$@" 2>&1 )
}

export -f oc_win_set oc_pane_set oc_pane_del oc_run_cli oc_cli oc_cli_real oc_session_file_for \
  oc_session_write oc_level oc_log_n oc_reap_n oc_fp oc_wt_fp oc_wt_reset oc_th_n oc_in_n oc_setup_project \
  oc_seat_track oc_spawn_seat oc_spawn_identity_seat oc_foreign_seat oc_mutant oc_sh \
  oc_cli_mut

oc_probe() { # <bash 片段>（在夹具项目里、加载完整配置后）：直接断言库函数（找硬目标）
  local code="$1"
  ( cd "$T2" && env -u TMUX -u TMUX_PANE -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
      -u TEAM_STATE_DIR -u TEAM_DOCS_ABS -u TEAM_DOCS_DIR -u TEAM_AGENTS -u TEAM_PM_WINDOW -u TEAM_SKILL_DIR \
      -u TEAM_AGENT_CMD -u TEAM_AGENT_BIN \
      PATH="$BIN:$REAL_PATH" HOME="$TMP/home" TEAM_PI_AGENT_DIR="$PI_AGENT_DIR" TEAM_PI_BIN="$BIN/pi" \
      TEAM_MEETINGS_DIR="$TMP/meetings" ${OC_ENV:-} OC_LIB="${2:-$SKILL_DIR}" OC_CODE="$code" bash -c '
        set -uo pipefail
        . "$OC_LIB/scripts/lib/common.sh"
        for f in "$OC_LIB"/scripts/lib/cmd-*.sh; do . "$f" 2>/dev/null || true; done
        team_load_config >/dev/null 2>&1
        eval "$OC_CODE"
      ' 2>&1 )
}
export -f oc_probe

oc_setup_project || { printf 'seat-interrupt：现场建不起来\n' >&2; exit 3; }

# ================================================================ plan（1.1）
if want plan; then
section "plan · 计划态：打印对象/证据/信号，一个信号都不发、一个字都不写（1.1）"
oc_wt_reset; oc_session_write "$SID" 1700000000 >/dev/null
p="$(oc_spawn_seat term)"; oc_seat_track "$p"
oc_win_set dev2; oc_pane_set dev2 "$p" 0 bash
sleep 0.3
th0="$(oc_fp "$TH")"; in0="$(oc_fp "$IN")"; n0="$(oc_log_n)"
plan="$(oc_cli "$T2" interrupt dev2 --reason "plan only, no signal")"; prc=$?
td_eq "计划态退 0" 0 "$prc"
td_has "计划点名席位" "$plan" "dev2"
td_has "计划点名 pid（就是那个 stub 进程）" "$plan" "pid=$p"
td_has "计划说将发 SIGTERM" "$plan" "SIGTERM"
td_has "计划带未授权的字样" "$plan" "未授权"
td_has "计划给出回来的路" "$plan" "team resume --agent dev2"
td_has "计划点名记录的会话 id" "$plan" "sid=$SID"
td_has "计划里说 mode=continued" "$plan" "mode=continued"
td_alive "计划态一个信号都没发" "$p"
td_eq "计划态 interrupt.log 未增长" "$n0" "$(oc_log_n)"
td_eq "计划态线程逐字节不变" "$th0" "$(oc_fp "$TH")"
td_eq "计划态收件箱逐字节不变" "$in0" "$(oc_fp "$IN")"
kill -KILL "$p" 2>/dev/null || true
oc_pane_del dev2
fi

# ================================================================ target（1.2）
if want target; then
section "target · 对象证明链：名册 → 记录里的窗口 → pane → pid → 身份（1.2）"
oc_wt_reset; oc_session_write "$SID" 1700000000 >/dev/null
p="$(oc_spawn_seat term)"; oc_seat_track "$p"
oc_win_set dev2; oc_pane_set dev2 "$p" 0 bash
sleep 0.3
td_has "pid 自己的 environ 里 TEAM_MAIN_ROOT 是本项目（/proc 直读）" \
  "$(tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null | grep '^TEAM_MAIN_ROOT=' || true)" "TEAM_MAIN_ROOT=$T2"
td_has "pid 自己的 environ 里 TEAM_ROOT 是记录里的工作树" \
  "$(tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null | grep '^TEAM_ROOT=' || true)" "TEAM_ROOT=$WT"
plan="$(oc_cli "$T2" interrupt dev2 --reason "target")"
td_has "计划打印的 pid 就是那个 stub 的 pid" "$plan" "pid=$p"
# 窗口存在但这个席位没有 agent 进程（回合已经结束 → resume），不是身份失败
oc_pane_set dev2 999999 0 bash
o="$(oc_cli "$T2" interrupt dev2 --reason "target" 2>&1)"; rc=$?
td_ne "窗口在、pane 里没有本项目的 agent 进程 → 拒绝" 0 "$rc"
td_has "拒绝点名 team resume" "$o" "team resume --agent dev2"
td_alive "那个 pid 没被碰（计划/拒绝都不发信号）" "$p"
# 记录里的工作树与进程的 TEAM_ROOT 不一致 → 拒绝（对象不是记录里那个席位进程）
q="$(oc_spawn_identity_seat "TEAM_MAIN_ROOT=$T2
TEAM_ROOT=$T2/.worktrees/elsewhere")"; oc_seat_track "$q"
oc_pane_set dev2 "$q" 0 bash
sleep 0.3
o="$(oc_cli "$T2" interrupt dev2 --reason "target" 2>&1)"; rc=$?
td_ne "TEAM_ROOT 与派单记录的工作树不一致 → 拒绝" 0 "$rc"
td_has "拒绝理由点名不一致" "$o" "与派单记录的工作树不一致"
td_alive "那个进程没被碰" "$q"
# TOCTOU ①：计划之后 pane 没了 → 拒绝（退非 0），而且一个信号也不发
oc_pane_del dev2
n0="$(oc_log_n)"
o="$(oc_cli "$T2" interrupt dev2 --reason "target" --yes 2>&1)"; rc=$?
td_ne "执行前 pane 死了 → 拒绝" 0 "$rc"
td_has "拒绝如实说回合已经结束、点名 resume" "$o" "回合已经结束了"
td_alive "pane 死了也不碰那个 pid" "$p"
td_eq "pane 死了被拒 → 审计不增长" "$n0" "$(oc_log_n)"
# TOCTOU ②（执行态真路径）：第一次读到了 pid，复验时 pane 已经变了 → 复验拒发
oc_pane_set dev2 "$p" 0 bash
printf '1\n' > "$TMP/panes-budget"
n1="$(oc_log_n)"; th1="$(oc_fp "$TH")"; in1="$(oc_fp "$IN")"
OC_ENV="OC_PANES_BUDGET=$TMP/panes-budget"
o="$(oc_cli "$T2" interrupt dev2 --reason "pane changed under us" --yes 2>&1)"; rc=$?
OC_ENV=""
td_ne "复验时 pane 已经变了 → 拒绝" 0 "$rc"
td_has "拒绝点名复验不过" "$o" "复验不过"
td_has "拒绝点名「进程已经不是计划时那个 pid」" "$o" "已经不是计划时那个 pid"
td_alive "复验不过 → 目标没被碰" "$p"
td_eq "复验不过 → 审计不增长" "$n1" "$(oc_log_n)"
td_eq "复验不过 → 线程逐字节不变" "$th1" "$(oc_fp "$TH")"
td_eq "复验不过 → 收件箱逐字节不变（理由不得先写）" "$in1" "$(oc_fp "$IN")"
rm -f "$TMP/panes-budget"
# 复验的另两条分支（库层直调同一个函数：对象证明链的每一环都有硬目标）
real_start="$(oc_probe "team_orphan_start_epoch $p" | tail -1)"
case "$real_start" in ''|*[!0-9]*) bad "探针拿不到真启动时刻（$real_start）" ;; *) ok "探针拿到真启动时刻（$real_start）" ;; esac
res="$(oc_probe "team_interrupt_reverify dev2 $p 1 '$WT'; printf 'rc=%s re=%s\n' \"\$?\" \"\$TEAM_INTERRUPT_RE\"" | tail -1)"
td_has "复验：计划里的启动时刻与现在不一致 → 拒发" "$res" "rc=1 re="
td_has "复验：理由点名启动时刻不一致（pid 可能被回收）" "$res" "启动时刻与计划时不一致"
res="$(oc_probe "team_interrupt_reverify dev2 $p $real_start '$WT'; printf 'rc=%s re=%s\n' \"\$?\" \"\$TEAM_INTERRUPT_RE\"" | tail -1)"
td_has "复验：启动时刻一致 → 通过（rc=0）" "$res" "rc=0 re="
oc_pane_del dev2
res="$(oc_probe "team_interrupt_reverify dev2 $p $real_start '$WT'; printf 'rc=%s re=%s\n' \"\$?\" \"\$TEAM_INTERRUPT_RE\"" | tail -1)"
td_has "复验：pane 里的 agent 进程已经不是那个 pid → 拒发" "$res" "已经不是计划时那个 pid"
oc_win_set
res="$(oc_probe "team_interrupt_reverify dev2 $p $real_start '$WT'; printf 'rc=%s re=%s\n' \"\$?\" \"\$TEAM_INTERRUPT_RE\"" | tail -1)"
td_has "复验：窗口已经不在了 → 拒发" "$res" "已经不在了"
oc_win_set dev2
kill -KILL "$p" "$q" 2>/dev/null || true
oc_pane_del dev2
fi

# ================================================================ execute（1.4）
if want execute; then
section "execute · SIGTERM → 有界 → 仍活着再 SIGKILL（1.4）"
oc_wt_reset; oc_session_write "$SID" 1700000000 >/dev/null
# ① 正常退出
p="$(oc_spawn_seat term)"; oc_seat_track "$p"
oc_win_set dev2; oc_pane_set dev2 "$p" 0 bash
sleep 0.3
n0="$(oc_log_n)"
OC_ENV='TEAM_INTERRUPT_GRACE_SEC=1'
out="$(oc_cli "$T2" interrupt dev2 --reason "authorized" --yes)"; rc=$?
OC_ENV=""
td_eq "执行态退 0" 0 "$rc"
td_has "打印它发了什么（信号）" "$out" "SIGTERM"
td_has "打印回来的路" "$out" "team resume --agent dev2"
gone=0; for _i in $(seq 1 3000); do kill -0 "$p" 2>/dev/null || { gone=1; break; }; sleep 0.1; done
td_eq "目标已退出" 1 "$gone"
td_eq "审计恰好一行" "$((n0 + 1))" "$(oc_log_n)"
# ② 忽略 SIGTERM → SIGKILL
q="$(oc_spawn_seat stubborn)"; oc_seat_track "$q"
oc_pane_set dev2 "$q" 0 bash
sleep 0.3
n1="$(oc_log_n)"
OC_ENV='TEAM_INTERRUPT_GRACE_SEC=1'
out="$(oc_cli "$T2" interrupt dev2 --reason "stubborn seat" --yes)"; rc=$?
OC_ENV=""
td_eq "倔强的目标：执行态仍退 0（SIGKILL 收干净）" 0 "$rc"
td_has "输出点名 SIGKILL 那一步" "$out" "SIGKILL"
gone=0; for _i in $(seq 1 3000); do kill -0 "$q" 2>/dev/null || { gone=1; break; }; sleep 0.1; done
td_eq "倔强的目标已退出" 1 "$gone"
td_has "审计里的信号序列是 SIGTERM→SIGKILL" "$(tail -1 "$LOG")" "signal=SIGTERM→SIGKILL"
td_eq "审计只多一行" "$((n1 + 1))" "$(oc_log_n)"
oc_pane_del dev2
fi

# ================================================================ audit（1.5）
if want audit; then
section "audit · 一行一打断；字段与**发信号之前**的读数一致（1.5）"
oc_wt_reset; oc_session_write "$SID" 1700000000 >/dev/null
p="$(oc_spawn_seat touch)"; oc_seat_track "$p"
oc_win_set dev2; oc_pane_set dev2 "$p" 0 bash
# 三份未提交文件（mtime 是旧的，免得落进新鲜窗口）
printf 'alpha\n' > "$WT/oc-alpha.txt"; printf 'beta\n'  > "$WT/oc-beta.txt"; printf 'gamma\n' > "$WT/oc-gamma.txt"
touch -d "@1700000000" "$WT/oc-alpha.txt" "$WT/oc-beta.txt" "$WT/oc-gamma.txt"
# 会话文件：打断前 = 1700000000；stub 收到 SIGTERM 后把它 touch 成**现在**
# （用现在而不是一个远期时间戳：远期 mtime 会把临时根的年龄算成负数，`tmp-hygiene --sweep`
#  就永远认为它「太新」而不收 —— 被杀的轮次会永远留下根）
sess="$(oc_session_write "$SID" 1700000000)"
sess_before="$(stat -c %Y "$sess")"
sleep 0.3
n0="$(oc_log_n)"
NL="$(printf 'audit fields; line1\nline2')"
out="$(oc_cli "$T2" interrupt dev2 --reason "$NL" --yes)"; rc=$?
td_eq "执行态退 0" 0 "$rc"
td_eq "审计恰好一行" "$((n0 + 1))" "$(oc_log_n)"
line="$(tail -1 "$LOG")"
td_has "审计带时间戳" "$line" "$(date -u +%Y-%m-%dT)"
td_has "审计带 actor（运行时目录解析）" "$line" "actor=pm"
td_has "审计带席位" "$line" "seat=dev2"
td_has "审计带 pid" "$line" "pid=$p"
td_has "审计的 session_last 是**发信号之前**那一份（stub 在 TERM 里把它摸新了）" \
  "$line" "session_last=$(oc_level 1700000000)"
td_has "审计带打断前的未提交条数" "$line" "uncommitted=3"
td_has "审计带 guard=clear" "$line" "guard=clear"
td_has "审计带一句话理由（换行折叠成一行）" "$line" "reason=audit fields; line1 line2"
td_has "审计带信号序列" "$line" "signal=SIGTERM"
td_has "审计带结果" "$line" "outcome=gone"
td_eq "审计行没有控制字符（理由里的换行被折掉）" \
  "$(grep -c -P '[\x00-\x08\x0b\x0c\x0e-\x1f]' "$LOG" 2>/dev/null || true)" "0"
td_eq "会话文件在打断后确实被 stub 摸新了（证明上面的 session_last 是打断前的读数）" \
  "$([ "$(stat -c %Y "$sess")" -gt "$sess_before" ] && echo newer || echo not-newer)" "newer"
# 被拒绝的打断不写审计：缺理由
n1="$(oc_log_n)"
oc_cli "$T2" interrupt dev2 --yes >/dev/null 2>&1
td_eq "缺理由被拒 → 审计不增长" "$n1" "$(oc_log_n)"
# actor 解析不出来 → 拒绝且什么都不写（在项目之外的一个 worktree 里调用：目录给不出席位名）
rm -rf "$TMP/not-a-seat"
git -C "$T2" worktree add -q --detach "$TMP/not-a-seat" main >/dev/null 2>&1
mkdir -p "$TMP/not-a-seat/.pi/team"; cp "$T2/.pi/team/config.sh" "$TMP/not-a-seat/.pi/team/config.sh"
w="$(oc_spawn_seat term)"; oc_seat_track "$w"
oc_win_set dev2; oc_pane_set dev2 "$w" 0 bash
sleep 0.3
n2="$(oc_log_n)"; th0="$(oc_fp "$TH")"
o="$(oc_cli "$TMP/not-a-seat" interrupt dev2 --reason "actor unknown" --yes 2>&1)"; rc=$?
td_ne "actor 解析不出来 → 拒绝" 0 "$rc"
td_has "拒绝点名 actor" "$o" "actor 解析不出来"
td_eq "actor 拒绝 → 审计不增长" "$n2" "$(oc_log_n)"
td_eq "actor 拒绝 → 线程不变" "$th0" "$(oc_fp "$TH")"
td_alive "actor 拒绝 → 一个信号都没发" "$w"
kill -KILL "$w" 2>/dev/null || true
kill -KILL "$p" 2>/dev/null || true
oc_pane_del dev2
fi

# ================================================================ refuse（1.6）
if want refuse; then
section "refuse · 拒绝集合各自给路；跨项目零点名（1.6）"
oc_wt_reset; oc_session_write "$SID" 1700000000 >/dev/null
# ① 进程不在 → team resume
oc_win_set dev2; oc_pane_del dev2
o="$(oc_cli "$T2" interrupt dev2 --reason "stopped" --yes 2>&1)"; rc=$?
td_ne "没有在跑的回合 → 拒绝" 0 "$rc"
td_has "点名 team resume" "$o" "team resume --agent dev2"
# ② 窗口没了而进程还在（孤儿）→ team reap --orphans
p="$(oc_spawn_seat term)"; oc_seat_track "$p"
sleep 0.3
oc_win_set; oc_pane_del dev2
n0="$(oc_log_n)"
o="$(oc_cli "$T2" interrupt dev2 --reason "orphan" --yes 2>&1)"; rc=$?
td_ne "孤儿席位 → 拒绝" 0 "$rc"
td_has "点名 team reap --orphans" "$o" "team reap --orphans"
td_alive "孤儿进程没被碰" "$p"
td_eq "拒绝不写审计" "$n0" "$(oc_log_n)"
# ③ 名字不在名册 → 名册
o="$(oc_cli "$T2" interrupt nosuch --reason "roster" --yes 2>&1)"; rc=$?
td_ne "不在名册 → 拒绝" 0 "$rc"
td_has "点名名册" "$o" "不在名册"
# ④ 另一个项目的席位 → 拒发、零点名
f="$(oc_foreign_seat)"; oc_seat_track "$f"
oc_win_set dev2; oc_pane_set dev2 "$f" 0 bash
sleep 0.3
o="$(oc_cli "$T2" interrupt dev2 --reason "foreign" --yes 2>&1)"; rc=$?
td_ne "别的项目的席位身份 → 拒绝" 0 "$rc"
td_has "拒绝理由点名「别的项目」" "$o" "别的项目"
td_not_has "跨项目零点名：不打印它的项目名/路径" "$o" "other-proj"
td_not_has "跨项目零点名：不打印它的 pid" "$o" "$f"
td_alive "别的项目的进程没被碰" "$f"
kill -KILL "$f" "$p" 2>/dev/null || true
oc_pane_del dev2
# ⑤ 调用者自己/它的祖先 → 拒发（把 CLI 挂在 stub agent 的子进程位上；pane pid 就是那个祖先）
oc_session_write "$SID" 1700000000 >/dev/null
a=""
( cd "$WT" && exec env -u TMUX -u TMUX_PANE -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT \
    -u TEAM_SESSION -u TEAM_STATE_DIR -u TEAM_DOCS_ABS -u TEAM_DOCS_DIR -u TEAM_AGENTS \
    -u TEAM_PM_WINDOW -u TEAM_SKILL_DIR -u TEAM_AGENT_CMD -u TEAM_AGENT_BIN \
    PATH="$BIN:$REAL_PATH" HOME="$TMP/home" \
    TEAM_MAIN_ROOT="$T2" TEAM_ROOT="$WT" TEAM_PI_AGENT_DIR="$PI_AGENT_DIR" TEAM_PI_BIN="$BIN/pi" \
    OC_TEAM_CLI="$SKILL_DIR/scripts/team" "$BIN/pi" hold interrupt dev2 --reason "self" --yes ) >"$TMP/self.log" 2>&1 &
a="$!"
oc_seat_track "$a"
oc_win_set dev2; oc_pane_set dev2 "$a" 0 bash
sleep 0.8
n1="$(oc_log_n)"
o="$(cat "$TMP/self.log" 2>/dev/null)"
td_has "调用者的祖先 → 拒绝并点名「祖先」" "$o" "祖先"
td_eq "祖先那一条：审计未增长" "$n1" "$(oc_log_n)"
kill -KILL "$a" 2>/dev/null || true
oc_pane_del dev2
# ⑥ 活席位上调 reap → 拒发，并点名**另一条入口**（protocol §4a「每个拒绝都点名另一个入口」；V52 的 F2）。
#    现场：真进程（身份在它自己的 environ 里）+ 真 pane 表；TMUX/TMUX_PANE 让孤儿判据答 live（不是 unjudged）。
oc_session_write "$SID" 1700000000 >/dev/null
s="$(oc_spawn_identity_seat "TEAM_MAIN_ROOT=$T2
TEAM_ROOT=$WT
TMUX=fixture-sock,1,0
TMUX_PANE=%dev2")"
oc_seat_track "$s"
oc_win_set dev2; oc_pane_set dev2 "$s" 0 bash
sleep 0.3
r0="$(oc_reap_n)"
o="$(oc_cli "$T2" reap "$s" --yes 2>&1)"; rc=$?
td_ne "活席位上 reap → 拒绝" 0 "$rc"
td_has "reap 的拒绝点名 team interrupt" "$o" "team interrupt"
td_alive "reap 拒绝时一个信号都没发" "$s"
td_eq "reap 的拒绝不写审计" "$r0" "$(oc_reap_n)"
kill -KILL "$s" 2>/dev/null || true
oc_pane_del dev2
fi

# ================================================================ reason（2.1）
if want reason; then
section "reason · 理由必填、先写理由后发信号、写不进去就拒发（2.1）"
oc_wt_reset; oc_session_write "$SID" 1700000000 >/dev/null
OC_REASON="reason lands before the signal"
p="$(oc_spawn_seat order)"; oc_seat_track "$p"
oc_win_set dev2; oc_pane_set dev2 "$p" 0 bash
sleep 0.3
th0="$(oc_fp "$TH")"; in0="$(oc_fp "$IN")"; n0="$(oc_log_n)"; thn0="$(oc_th_n)"; inn0="$(oc_in_n)"
o="$(oc_cli "$T2" interrupt dev2 --yes 2>&1)"; rc=$?
td_ne "缺 --reason → 拒绝（退非 0）" 0 "$rc"
td_has "拒绝点名缺理由" "$o" "缺少 --reason"
o="$(oc_cli "$T2" interrupt dev2 --reason "" --yes 2>&1)"; rc=$?
td_ne "空 --reason → 拒绝" 0 "$rc"
td_has "拒绝点名空理由" "$o" "--reason 是空的"
td_eq "两次拒绝都没动线程" "$th0" "$(oc_fp "$TH")"
td_eq "两次拒绝都没动收件箱" "$in0" "$(oc_fp "$IN")"
td_eq "两次拒绝都没写审计" "$n0" "$(oc_log_n)"
td_alive "两次拒绝都没发信号" "$p"
# 授权打断：理由必须在信号**之前**就在席位线程里（stub 收到 TERM 时现场检查）
rm -f "$TMP/order"
oc_cli "$T2" interrupt dev2 --reason "$OC_REASON" --yes >/dev/null 2>&1 || true
sleep 0.5
td_eq "stub 在 TERM 里看到线程已有理由（写序：线程先、信号后）" "ordered" "$(cat "$TMP/order" 2>/dev/null)"
td_eq "线程恰好 +1 条" "$((thn0 + 1))" "$(oc_th_n)"
td_has "线程条目点名谁打断的" "$(tail -4 "$TH")" "from: pm"
td_has "线程条目点名为什么" "$(tail -4 "$TH")" "$OC_REASON"
td_has "线程条目点名先做什么" "$(tail -4 "$TH")" "先做什么"
td_eq "收件箱恰好 +1 行" "$((inn0 + 1))" "$(oc_in_n)"
td_has "收件箱那行是同一次打断的持久通知" "$(tail -1 "$IN")" "[interrupt]"
# thread 写不进去 → 拒发（把线程文件换成一个目录）
q="$(oc_spawn_seat term)"; oc_seat_track "$q"
oc_pane_set dev2 "$q" 0 bash
sleep 0.3
rm -f "$TH"; mkdir -p "$TH"
n1="$(oc_log_n)"; in1="$(oc_fp "$IN")"
o="$(oc_cli "$T2" interrupt dev2 --reason "thread unwritable" --yes 2>&1)"; rc=$?
td_ne "线程写不进去 → 拒绝" 0 "$rc"
td_has "拒绝点名线程写不进去" "$o" "写不进该席位的线程"
td_alive "线程写不进去 → 一个信号都没发" "$q"
td_eq "线程写不进去 → 审计不增长" "$n1" "$(oc_log_n)"
td_eq "线程写不进去 → 收件箱不变" "$in1" "$(oc_fp "$IN")"
rmdir "$TH"; printf '### 2026-01-01T00:00:00Z · from: pm · re: -\n夹具线程的既有内容。\n' > "$TH"
kill -KILL "$q" 2>/dev/null || true
oc_pane_del dev2
fi

# ================================================================ guard（2.2 / 2.3）
if want guard; then
section "guard · 正在写盘的席位被拒绝，点名证据与窗口；--force 才越过（2.2/2.3）"
oc_wt_reset
p="$(oc_spawn_seat term)"; oc_seat_track "$p"
oc_win_set dev2; oc_pane_set dev2 "$p" 0 bash
# ① 会话文件新鲜
sess="$(oc_session_write "$SID" 1700000000)"; touch "$sess"
sleep 0.3
n0="$(oc_log_n)"; th0="$(oc_fp "$TH")"; thn0="$(oc_th_n)"
o="$(oc_cli "$T2" interrupt dev2 --reason "fresh session" --yes 2>&1)"; rc=$?
td_ne "会话文件比窗口新 → 拒绝" 0 "$rc"
td_has "拒绝点名读到的文件" "$o" "$SID"
td_has "拒绝点名岁数" "$o" "s 前）"
td_has "拒绝点名窗口" "$o" "3600s"
td_alive "拒绝 → 进程还活着" "$p"
td_eq "拒绝 → 审计不增长" "$n0" "$(oc_log_n)"
td_eq "拒绝 → 线程不变" "$th0" "$(oc_fp "$TH")"
# ② 只有未提交文件新鲜
touch -d "@1700000000" "$sess"
printf 'fresh\n' > "$WT/oc-fresh.txt"
o="$(oc_cli "$T2" interrupt dev2 --reason "fresh worktree file" --yes 2>&1)"; rc=$?
td_ne "工作树里只有未提交文件新鲜 → 也拒绝" 0 "$rc"
td_has "拒绝点名那个文件" "$o" "oc-fresh.txt"
rm -f "$WT/oc-fresh.txt"
# ③ 非数字窗口值退回默认（会话文件重新摸新，否则这一段会放行）
touch "$sess"
OC_ENV='TEAM_INTERRUPT_FRESH_SEC=not-a-number'
o="$(oc_cli "$T2" interrupt dev2 --reason "bad window" --yes 2>&1)"; rc=$?
OC_ENV=""
td_ne "非数字窗口值：仍按默认 3600 判（会话文件新鲜 → 拒绝）" 0 "$rc"
td_has "拒绝里点名默认窗口 3600s" "$o" "3600s"
# ④ 缺证据（会话文件不存在、工作树干净）→ 放行（缺证据不编造）
rm -f "$sess"
o="$(oc_cli "$T2" interrupt dev2 --reason "no evidence" 2>&1)"; rc=$?
td_eq "会话文件不存在 + 工作树干净 → 计划态放行（退 0）" 0 "$rc"
td_has "计划里如实写「读不到」" "$o" "缺证据不编造"
# ⑤ --force 越过新鲜窗口，审计记 forced
oc_session_write "$SID" 1700000000 >/dev/null
touch "$(oc_session_file_for "$SID")"
n1="$(oc_log_n)"
out="$(oc_cli "$T2" interrupt dev2 --reason "forced override" --force --yes 2>&1)"; rc=$?
td_eq "--force 越过新鲜窗口 → 执行成功" 0 "$rc"
gone=0; for _i in $(seq 1 3000); do kill -0 "$p" 2>/dev/null || { gone=1; break; }; sleep 0.1; done
td_eq "--force：目标已退出" 1 "$gone"
td_has "--force：审计记 guard=forced" "$(tail -1 "$LOG")" "guard=forced"
td_has "--force：审计仍带同一份打断前读数（工作树干净 → uncommitted=0）" "$(tail -1 "$LOG")" "uncommitted=0"
td_eq "--force：审计恰好一行" "$((n1 + 1))" "$(oc_log_n)"
td_eq "--force：线程也确实 +1 条（理由投递没被越过）" "$((thn0 + 1))" "$(oc_th_n)"
# ⑥ --force 越不过身份：别的项目的进程照样拒发
f="$(oc_foreign_seat)"; oc_seat_track "$f"
oc_pane_set dev2 "$f" 0 bash
sleep 0.3
n2="$(oc_log_n)"
o="$(oc_cli "$T2" interrupt dev2 --reason "force cannot cross identity" --force --yes 2>&1)"; rc=$?
td_ne "--force + 别的项目身份 → 仍然拒绝" 0 "$rc"
td_alive "--force 越不过身份：那个进程没被碰" "$f"
td_eq "--force 越不过身份：审计不增长" "$n2" "$(oc_log_n)"
kill -KILL "$f" 2>/dev/null || true
oc_pane_del dev2
fi

# ================================================================ survive（2.4）
if want survive; then
section "survive · 磁盘逐字节幸存、树指纹不变、只对那一个 pid 发过信号（2.4）"
oc_wt_reset; oc_session_write "$SID" 1700000000 >/dev/null
p="$(oc_spawn_seat term)"; oc_seat_track "$p"
oc_win_set dev2; oc_pane_set dev2 "$p" 0 bash
decoy="$(oc_spawn_seat term)"; oc_seat_track "$decoy"
sleep 0.3
printf 'keep-me-exactly\n' > "$WT/oc-keep.txt"
touch -d "@1700000000" "$WT/oc-keep.txt"
sess="$(oc_session_file_for "$SID")"
rec0="$(oc_fp "$ST/dev2.env")"; wt0="$(oc_wt_fp)"
keep0="$(oc_fp "$WT/oc-keep.txt")"; sess0="$(oc_fp "$sess")"
n0="$(oc_log_n)"; thn0="$(oc_th_n)"; inn0="$(oc_in_n)"
out="$(oc_cli "$T2" interrupt dev2 --reason "survive" --yes 2>&1)"; rc=$?
td_eq "执行态退 0" 0 "$rc"
td_eq "未提交文件逐字节不变" "$keep0" "$(oc_fp "$WT/oc-keep.txt")"
td_has "未提交文件的内容也还是那一行" "$(cat "$WT/oc-keep.txt")" "keep-me-exactly"
td_eq "会话文件仍在且字节不变" "$sess0" "$(oc_fp "$sess")"
td_eq "派单记录逐字节不变" "$rec0" "$(oc_fp "$ST/dev2.env")"
td_eq "工作树树指纹前后一致" "$wt0" "$(oc_wt_fp)"
td_eq "打断只改了 thread / inbox / interrupt.log：线程 +1" "$((thn0 + 1))" "$(oc_th_n)"
td_eq "打断只改了 thread / inbox / interrupt.log：收件箱 +1" "$((inn0 + 1))" "$(oc_in_n)"
td_eq "打断只改了 thread / inbox / interrupt.log：审计 +1" "$((n0 + 1))" "$(oc_log_n)"
td_alive "只对一个 pid 发过信号：同身份的另一条进程还在（$decoy）" "$decoy"
kill -KILL "$decoy" 2>/dev/null || true
oc_pane_del dev2
fi

# ================================================================ read（1.7）
if want read; then
section "read · 读命令永不结束回合、也不写审计（1.7）"
oc_wt_reset; oc_session_write "$SID" 1700000000 >/dev/null
p="$(oc_spawn_seat term)"; oc_seat_track "$p"
oc_win_set dev2; oc_pane_set dev2 "$p" 0 bash
sleep 0.3
n0="$(oc_log_n)"; thn0="$(oc_th_n)"
for c in ps status roster digest; do
  oc_cli "$T2" "$c" >/dev/null 2>&1 || true
  td_alive "team $c 之后席位仍活着" "$p"
done
td_eq "四个读命令之后 interrupt.log 未增长" "$n0" "$(oc_log_n)"
td_eq "读命令没有生成线程的新条目" "$thn0" "$(oc_th_n)"
kill -KILL "$p" 2>/dev/null || true
oc_pane_del dev2
fi

# ================================================================ route（2.5）
if want route; then
section "route · 回来的路：resume 列成可续跑、计划点名 sid/continued、提示词点名线程（2.5）"
oc_wt_reset; oc_session_write "$SID" 1700000000 >/dev/null
p="$(oc_spawn_seat term)"; oc_seat_track "$p"
oc_win_set dev2; oc_pane_set dev2 "$p" 0 bash
sleep 0.3
out="$(oc_cli "$T2" interrupt dev2 --reason "route" --yes 2>&1)"; rc=$?
td_eq "执行态退 0" 0 "$rc"
td_has "输出打印回来的路" "$out" "team resume --agent dev2"
td_has "输出的路线点名记录的会话 id" "$out" "sid=$SID"
td_has "输出的路线点名 continued 模式" "$out" "mode=continued"
oc_pane_del dev2; oc_win_set dev2
r="$(oc_cli "$T2" resume --agent dev2 --dry-run 2>&1 || true)"
td_has "resume --dry-run 列出该席位可续跑（回来的路是开的）" "$r" "dev2 可续跑"
td_has "resume --dry-run 的同一任务计划点名记录里的 sid" "$r" "sid=$SID"
td_has "同一任务计划点名 continued 模式" "$r" "mode=continued"
td_has "渲染出的提示词里有阅读顺序的第二步 threads/dev2.md" "$r" "threads/dev2.md"
fi

# ================================================================ hygiene（收尾清理）
if want hygiene; then
section "hygiene · 收尾清理：跑完不留根（PM 2026-10-16 的提醒）"
# 实测教训：夹具在 `tmp_root_create` 之后改了自己的 ${TMPDIR:-/tmp}，台账基就漂了 ——
# `tmp_root_reap_all` 在**新基**找不到自己的台账，静默什么都不收（34 个根 / 1.6 GB 留在 /tmp）。
# 这一组用**隔离的基**跑同一个脚本，把「跑完不留根」本身变成断言：
HB="$TMP/hyg-base"; rm -rf "$HB"; mkdir -p "$HB"
HG_RC=0
TMPDIR="$HB" bash "$SELF_DIR/seat-interrupt.sh" --select plan >"$TMP/hyg-green.log" 2>&1 || HG_RC=$?
td_eq "绿：被跑的那一轮自己退 0（它自己的收尾自检也过了）" 0 "$HG_RC"
td_has "绿：那一轮真的跑了组（结果行在）" "$(cat "$TMP/hyg-green.log")" "== 结果 =="
td_eq "绿：隔离基里没有留下任何根" "0" "$(ls -d "$HB"/teamsmith-* 2>/dev/null | wc -l | tr -d ' ')"
td_eq "绿：它的 run 台账 / pid 记录也撤了" "0" "$(ls -d "$HB"/.teamsmith-tmp-* 2>/dev/null | wc -l | tr -d ' ')"
# 红侧：库自己那个「静默泄漏」旋钮（TEAM_SMOKE_FIXTURE=1 + TEAM_TMP_HYGIENE_FLIP=leak）
# → 根留下 → 夹具的收尾自检必须大声报错并退非 0（静默泄漏正是要防的那个缺陷类）。
HB2="$TMP/hyg-base-leak"; rm -rf "$HB2"; mkdir -p "$HB2"
HG2_RC=0
o="$(TMPDIR="$HB2" TEAM_SMOKE_FIXTURE=1 TEAM_TMP_HYGIENE_FLIP=leak bash "$SELF_DIR/seat-interrupt.sh" --select plan 2>&1)" || HG2_RC=$?
td_ne "红：坏收尾的那一轮退非 0" 0 "$HG2_RC"
td_has "红：库的泄漏旋钮确实生效（静默不回收）" "$o" "FLIP(leak)"
td_has "红：收尾自检点名「临时根没有回收」" "$o" "临时根没有回收"
td_eq "红：根确实留下了（所以上面那条不是空断言）" "1" "$(ls -d "$HB2"/teamsmith-* 2>/dev/null | wc -l | tr -d ' ')"
rm -rf "${HB2:?}" 2>/dev/null || true
td_eq "收尾：红侧现场自己也清清（不留痕）" "0" "$(ls -d "$HB2" 2>/dev/null | wc -l | tr -d ' ')"
fi

# ================================================================ live（真私有 tmux server）
if want live; then
section "live · 真私有 tmux server 上的真回合：端到端打断"
if [ -z "$OC_REAL_TMUX" ]; then
  skip "没有 tmux：真回合那一段跳过（桩 tmux 的组已覆盖证明链）"
else
  PATH="$REAL_PATH"                     # 隔离前置要真 tmux（桩只回答三个只读查询）
  export PATH
  if ! tmux_iso_guard_soft "seat-interrupt" "live 组：建本轮私有 server" \
       --tmpdir "$TMUX_TMPDIR" --own-root "$TMP" --caller-tmpdir "$OC_CALLER_TMUX_TMPDIR"; then
    skip "隔离前置不成立（私有 socket 没证明）——真回合那一段跳过（绝不碰非私有 server）"
  else
  "$OC_REAL_TMUX" new-session -d -s OC2 -n dev2 -c "$WT" \
    "exec env TEAM_MAIN_ROOT='$T2' TEAM_ROOT='$WT' '$BIN/pi' term" 2>/dev/null || true
  OC_LIVE_UP=1
  sock="$("$OC_REAL_TMUX" display-message -p '#{socket_path}' 2>/dev/null || true)"
  case "$sock" in
    "$TMUX_TMPDIR"/*)
      lpid=""
      for _i in $(seq 1 3000); do
        lpid="$("$OC_REAL_TMUX" list-panes -t OC2:dev2 -F '#{pane_pid}' 2>/dev/null | head -1)"
        [ -n "$lpid" ] && break
        sleep 0.1
      done
      if [ -z "$lpid" ]; then
        bad "真回合：窗口里没有起得来的 agent 进程"
      else
        oc_seat_track "$lpid"
        n0="$(oc_log_n)"
        out="$(oc_cli_real "$T2" interrupt dev2 --reason "live real turn" --yes 2>&1)"; rc=$?
        td_eq "真回合：执行态退 0" 0 "$rc"
        td_has "真回合：输出点名 pid" "$out" "pid=$lpid"
        td_eq "真回合：审计恰好 +1 行" "$((n0 + 1))" "$(oc_log_n)"
        td_has "真回合：审计的 pid 就是 pane 里那个进程" "$(tail -1 "$LOG")" "pid=$lpid"
        gone=0; for _i in $(seq 1 3000); do kill -0 "$lpid" 2>/dev/null || { gone=1; break; }; sleep 0.1; done
        td_eq "真回合：pane 里的 agent 进程已退出" 1 "$gone"
        td_has "真回合：审计里的信号是 SIGTERM" "$(tail -1 "$LOG")" "SIGTERM"
      fi ;;
    *) skip "私有 socket 没生效（报出 ${sock:-?}）——真回合那一段跳过（绝不碰非私有 server）" ;;
  esac
  fi
  PATH="$BIN:$REAL_PATH"; export PATH
fi
fi

# ================================================================ flip
if [ "$MODE" = "flip" ]; then
section "flip · 逐条红侧（破坏 → 指定用例必红 → 还原 → 绿）"
OC_PIDFILE="$TMP/flip-pids"; : > "$OC_PIDFILE"; export OC_PIDFILE
# 红侧的统一形状：同一段片段在两棵树上跑，绿树必须给 GREEN、变异树必须给 RED。
flip_case() { # <名字> <片段> <变异追加…>
  local name="$1" code="$2"; shift 2
  local mut; mut="$(oc_mutant "$name" "$@")"
  local g r
  g="$(OC_MUT="$SKILL_DIR" oc_sh "$SKILL_DIR" "$code" 2>/dev/null)"
  r="$(OC_MUT="$mut" oc_sh "$mut" "$code" 2>/dev/null)"
  if [ "$g" = "GREEN" ]; then ok "$name：还原 → 绿"; else bad "$name：绿侧不成立（$g）"; fi
  if [ "$r" = "RED" ]; then ok "$name：破坏 → 指定用例红"; else bad "$name：破坏后用例没有红（$r）"; fi
}

# ① 计划态零信号：变异 = 计划态也执行（信号被发出去）
flip_case p292-flip-plan-signals \
  'oc_wt_reset; oc_session_write "$SID" 1700000000 >/dev/null
   p="$(oc_spawn_seat term)"; oc_seat_track "$p"; oc_win_set dev2; oc_pane_set dev2 "$p" 0 bash; sleep 0.3
   oc_cli_mut "$OC_MUT" interrupt dev2 --reason "flip plan" >/dev/null 2>&1
   kill -0 "$p" 2>/dev/null && printf GREEN || printf RED' \
  'eval "team_cmd_interrupt__p292() $(declare -f team_cmd_interrupt | tail -n +2)"
   team_cmd_interrupt() { team_cmd_interrupt__p292 "$@" --yes; }'

# ② 审计字段与打断前读数一致：变异 = 审计时才现读证据（session_last 变成打断后的读数）
flip_case p292-flip-audit-post \
  'oc_wt_reset; oc_session_write "$SID" 1700000000 >/dev/null
   p="$(oc_spawn_seat touch)"; oc_seat_track "$p"; oc_win_set dev2; oc_pane_set dev2 "$p" 0 bash; sleep 0.3
   oc_cli_mut "$OC_MUT" interrupt dev2 --reason "flip audit" --yes >/dev/null 2>&1
   # 绿：审计里的 session_last 就是打断前那个值；破坏（审计时才现读）= 变成打断后的、不等于它
   case "$(tail -1 "$LOG")" in *"session_last=$(oc_level 1700000000)"*) printf GREEN ;; *) printf RED ;; esac' \
  'eval "team_interrupt_audit__p292() $(declare -f team_interrupt_audit | tail -n +2)"
   team_interrupt_audit() { team_interrupt_evidence "$WT" "$SID"
     team_interrupt_audit__p292 "$1" "$2" "$3" "$(team_interrupt_iso "${TEAM_INTERRUPT_SESSION_LAST:--}")" "$TEAM_INTERRUPT_UNCOMMITTED" "$6" "$7" "$8" "$9"; }'

# ③ 对象不再是那个进程 → 拒绝：变异 = 拆掉复验（用 pane 预算造「早读到了、复验时变了」）
flip_case p292-flip-reverify \
  'oc_wt_reset; oc_session_write "$SID" 1700000000 >/dev/null
   p="$(oc_spawn_seat term)"; oc_seat_track "$p"; oc_win_set dev2; oc_pane_set dev2 "$p" 0 bash; sleep 0.3
   printf "1\n" > "$TMP/panes-budget"
   OC_ENV="OC_PANES_BUDGET=$TMP/panes-budget" oc_cli_mut "$OC_MUT" interrupt dev2 --reason "flip reverify" --yes >/dev/null 2>&1
   OC_ENV=""; rm -f "$TMP/panes-budget"
   kill -0 "$p" 2>/dev/null && printf GREEN || printf RED' \
  'team_interrupt_reverify() { TEAM_INTERRUPT_RE=""; return 0; }'

# ④ 正在写盘的席位被拒绝：变异 = 新鲜窗口判据永远放行
flip_case p292-flip-fresh \
  'oc_wt_reset; oc_session_write "$SID" 1700000000 >/dev/null; touch "$(oc_session_file_for "$SID")"
   p="$(oc_spawn_seat term)"; oc_seat_track "$p"; oc_win_set dev2; oc_pane_set dev2 "$p" 0 bash; sleep 0.3
   oc_cli_mut "$OC_MUT" interrupt dev2 --reason "flip fresh" --yes >/dev/null 2>&1
   kill -0 "$p" 2>/dev/null && printf GREEN || printf RED' \
  'team_interrupt_fresh_check() { TEAM_INTERRUPT_FRESH_FILE=""; TEAM_INTERRUPT_FRESH_AGE=""; return 0; }'

# ⑤ 理由落在席位的阅读顺序、且在信号之前：变异 = 理由延迟投递（TERM 时线程里还没有）
flip_case p292-flip-reason-order \
  'oc_wt_reset; oc_session_write "$SID" 1700000000 >/dev/null; rm -f "$TMP/order"
   printf "### baseline · from: pm\n基线\n" > "$TH"
   OC_REASON="flip reason order"
   p="$(oc_spawn_seat order)"; oc_seat_track "$p"; oc_win_set dev2; oc_pane_set dev2 "$p" 0 bash; sleep 0.3
   oc_cli_mut "$OC_MUT" interrupt dev2 --reason "$OC_REASON" --yes >/dev/null 2>&1
   sleep 0.5
   [ "$(cat "$TMP/order" 2>/dev/null)" = ordered ] && printf GREEN || printf RED' \
  'team_interrupt_deliver_reason() { ( sleep 1; printf "### deferred\n" >> "$TH" ) >/dev/null 2>&1 & return 0; }'

# ⑥ 工作树逐字节不变：变异 = 打断后往席位工作树里写一个文件
flip_case p292-flip-worktree \
  'oc_wt_reset; oc_session_write "$SID" 1700000000 >/dev/null
   p="$(oc_spawn_seat term)"; oc_seat_track "$p"; oc_win_set dev2; oc_pane_set dev2 "$p" 0 bash; sleep 0.3
   rm -f "$WT/oc-mut-left.txt"
   oc_cli_mut "$OC_MUT" interrupt dev2 --reason "flip worktree" --yes >/dev/null 2>&1
   [ -e "$WT/oc-mut-left.txt" ] && printf RED || printf GREEN' \
  'eval "team_cmd_interrupt__p292w() $(declare -f team_cmd_interrupt | tail -n +2)"
   team_cmd_interrupt() { team_cmd_interrupt__p292w "$@"; local _r=$?; printf "mut\n" > "$WT/oc-mut-left.txt"; return $_r; }'

# ⑦ 读命令不写任何东西：变异 = ps 变成打断
flip_case p292-flip-read-writes \
  'oc_wt_reset; oc_session_write "$SID" 1700000000 >/dev/null
   p="$(oc_spawn_seat term)"; oc_seat_track "$p"; oc_win_set dev2; oc_pane_set dev2 "$p" 0 bash; sleep 0.3
   n0="$(oc_log_n)"
   oc_cli_mut "$OC_MUT" ps >/dev/null 2>&1
   kill -0 "$p" 2>/dev/null && [ "$(oc_log_n)" = "$n0" ] && printf GREEN || printf RED' \
  'eval "team_cmd_ps__p292() $(declare -f team_cmd_ps | tail -n +2)"
   team_cmd_ps() { team_cmd_ps__p292 "$@"; team_cmd_interrupt dev2 --reason "flip read" --yes >/dev/null 2>&1 || true; }'

# ⑧ 跨项目零点名：变异 = foreign 判据放行（并拆掉复验，于是真的发信号）
flip_case p292-flip-foreign \
  'oc_wt_reset; oc_session_write "$SID" 1700000000 >/dev/null
   f="$(oc_foreign_seat)"; oc_seat_track "$f"; oc_win_set dev2; oc_pane_set dev2 "$f" 0 bash; sleep 0.3
   oc_cli_mut "$OC_MUT" interrupt dev2 --reason "flip foreign" --yes >/dev/null 2>&1
   kill -0 "$f" 2>/dev/null && printf GREEN || printf RED' \
  'eval "team_interrupt_identity__p292() $(declare -f team_interrupt_identity | tail -n +2)"
   team_interrupt_identity() { TEAM_INTERRUPT_ID=own; return 0; }
   team_interrupt_reverify() { TEAM_INTERRUPT_RE=""; return 0; }'

# ⑨ 继承值不能授权：变异 = 不看 argv、一律补 --yes
flip_case p292-flip-yes-inherited \
  'oc_wt_reset; oc_session_write "$SID" 1700000000 >/dev/null
   p="$(oc_spawn_seat term)"; oc_seat_track "$p"; oc_win_set dev2; oc_pane_set dev2 "$p" 0 bash; sleep 0.3
   OC_ENV="TEAM_ASSUME_YES=1 TEAM_CONFIRM_WRITES=1"
   oc_cli_mut "$OC_MUT" interrupt dev2 --reason "flip inherited yes" >/dev/null 2>&1
   OC_ENV=""
   kill -0 "$p" 2>/dev/null && printf GREEN || printf RED' \
  'eval "team_cmd_interrupt__p292y() $(declare -f team_cmd_interrupt | tail -n +2)"
   team_cmd_interrupt() { local _a=("$@") _i _has=0; for _i in "${_a[@]}"; do [ "$_i" = "--yes" ] && _has=1; done; [ "$_has" = 1 ] || _a+=("--yes"); team_cmd_interrupt__p292y "${_a[@]}"; }'

# ⑩ 活席位拒绝必须点名另一条入口：变异 = 把产品里那句指向删掉（同一断言在两棵树上跑）。
#    cmd-watch.sh 是**最后**被 source 的文件，但 sed 改的是它之前就加载好的 cmd-reap.sh ——
#    只改文件不重载，当前进程里的函数仍是旧的那份，变异不会生效（所以片段里多一句 `.`）。
flip_case p292-flip-reap-pointer \
  'oc_wt_reset; oc_session_write "$SID" 1700000000 >/dev/null
   s="$(oc_spawn_identity_seat "TEAM_MAIN_ROOT=$T2
TEAM_ROOT=$WT
TMUX=fixture-sock,1,0
TMUX_PANE=%dev2")"
   oc_seat_track "$s"; oc_win_set dev2; oc_pane_set dev2 "$s" 0 bash; sleep 0.3
   o="$(oc_cli_mut "$OC_MUT" reap "$s" --yes 2>&1)"; rc=$?
   kill -KILL "$s" 2>/dev/null || true
   oc_pane_del dev2
   [ "$rc" != 0 ] || { printf RED; exit 0; }          # 拒绝本身必须还在（不然红的是别的东西）
   case "$o" in *"team interrupt"*) printf GREEN ;; *) printf RED ;; esac' \
  '# 变异：活席位拒绝里的那句指向删掉（只落在变异树里），再把改过的文件重新加载一次
   _oc_reap_src="$(dirname "${BASH_SOURCE[0]}")/cmd-reap.sh"
   sed -i "s/ team interrupt [^ ]* --reason//" "$_oc_reap_src"
   . "$_oc_reap_src"'
fi

printf '\n\033[1m== 结果 ==\033[0m  ✓ %s  ✗ %s  SKIP %s\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
