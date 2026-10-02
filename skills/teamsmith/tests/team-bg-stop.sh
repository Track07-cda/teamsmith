#!/usr/bin/env bash
# P159 · `team bg stop` 夹具（safe-signal-discipline · RA3）
#
#   bash skills/teamsmith/tests/team-bg-stop.sh [--break=no-identity|no-boundary|no-dir-boundary] [--keep]
#
# 证明什么（每条断言都对着 RA3 的 scenario）：
#   · 真作业按**记录里的 (pid, 启动时间指纹)** 停掉：组 TERM（leader 是组头 → 组内子孙一起），
#     job 死了、**没有记录过的邻居活着**、`state/bg.log` 留下 stop 行（RA3 的 happy path）；
#   · 四种拒绝都**什么都没发**：无记录 3 / 记录畸形 4 / pid 复用（指纹对不上）5 / 用法 2；
#   · 记录只认本项目 state 目录：兄弟 state 目录里的 id 不会被找到，也不会去别处搜进程；
#   · 状态边界（P169 · F1，CRITICAL）：id 是平坦名字（路径语义不在语法里）、记录必须是本项目
#     bg 目录里的正规文件 —— 穿越 id 2 / 软链 4 / pgid=0 4 / FIFO 4（读取前就拒，不许挂住），
#     三种畸形都零信号、邻居全活；反向：本项目自己的正规记录照常收（`job.2-fine` 那种名字不误伤）；
#   · 目录边界（P187 · F1'，CRITICAL）：**bg 目录自身**也必须在项目 state 内 —— `state/bg` 是软链时
#     读写两侧都拒绝（stop/list 同一条规则），点名 `state/bg` 的解析目标；反向：真目录照常收作业；
#   · 已结束的 leader 不追猎：rc=0 + 明说子孙不会被找（活着的子孙留在原地）；
#   · `team bg list` 一行一作业，身份成不成立逐行标出（holds/gone/mismatch/malformed）。
#
# 红侧（默认不跑）：`--break=no-identity` 把 cmd-bg.sh 的指纹核对那一行改成 `if false` 的**副本**
# —— 「pid 复用必须被拒」与「邻居必须活着」必须变红；`--break=no-boundary` 把记录解析器短路的
# 副本 —— 「穿越 id / 软链记录必须被拒且邻居活着」必须变红；`--break=no-dir-boundary` 把「bg 目录
# 自身也在项目内」的检查短路的副本 —— 「软链目录必须被拒且邻居活着」必须变红。这是断侧，
# 用来证明断言不是空转。
#
# 纪律：清掉继承的团队身份与 tmux 身份；产物落 tmp_root_create 的私有根；每个作业/邻居都是夹具
# spawn、pid 记录在案，收尾**只按记录的 pid** 发信号（绝不按名字/模式）。夹具不起 tmux、不进容器。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
REPO_ROOT="$(cd -P "$SKILL_DIR/../.." && pwd)"
# shellcheck source=lib/tmp-root.sh
. "$SELF_DIR/lib/tmp-root.sh"

BREAK=""; KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --break=*) BREAK="${1#--break=}"; shift ;;
    --keep)    KEEP=1; shift ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    *) printf 'team-bg-stop: 未知参数 %s\n' "$1" >&2; exit 2 ;;
  esac
done
case "$BREAK" in ''|no-identity|no-boundary|no-dir-boundary) ;; *) printf 'team-bg-stop: --break 只认 no-identity / no-boundary / no-dir-boundary（收到 %s）\n' "$BREAK" >&2; exit 2 ;; esac
[ "$KEEP" = "1" ] && export TEAM_TMP_KEEP=1

# ── 身份隔离：绝不继承调用者的团队/tmux 身份 ─────────────────────────────────────────────────
for _v in $(env | sed -n 's/^\(TEAM_[A-Za-z0-9_]*\)=.*/\1/p'); do
  case "$_v" in TEAM_TMP_KEEP|TEAM_TMP_RUN_ID|TEAM_TMP_LEDGER) ;; *) unset "$_v" ;; esac
done
unset TMUX TMUX_PANE TMUX_TMPDIR 2>/dev/null || true

TMP="$(tmp_root_create team-bg-stop)" || exit 3
FAIL=0; PASS=0; FAILED=""
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); FAILED="${FAILED:+$FAILED, }$1"; }
hdr() { printf '\n== %s ==\n' "$1"; }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || bad "$1（期望 [$3]，实际 [$2]）"; }
assert_has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1（[$2] 里没有 [$3]）" ;; esac; }
assert_alive() { kill -0 "$2" 2>/dev/null && ok "$1" || bad "$1（pid $2 不在）"; }
assert_gone() { kill -0 "$2" 2>/dev/null && bad "$1（pid $2 还活着）" || ok "$1"; }

# ── 被夹具 spawn 的进程登记（收尾只按这些 pid 发信号）───────────────────────────────────────
SPAWNED=()
spawn_group_job() { # <child-pid-file> → leader pid（新会话：pgid == pid）；组里再留一个真子孙
  setsid bash -c 'sleep 300 & echo $! > "$1"; wait' _ "$1" >/dev/null 2>&1 &
  printf '%s\n' "$!"
}
spawn_neighbour() { # → pid（登记在案、**不写进任何记录**的邻居）
  setsid sleep 300 >/dev/null 2>&1 &
  printf '%s\n' "$!"
}
cleanup() {
  local p
  for p in ${SPAWNED[@]+"${SPAWNED[@]}"}; do
    [ -n "$p" ] && kill -KILL "$p" 2>/dev/null || true
  done
  [ "$KEEP" = "1" ] || tmp_root_reap_all
}
trap cleanup EXIT

# /proc/<pid>/stat 的 comm 之后第 <i> 个词（0 起）：i=2 是 pgid（字段 5），i=19 是启动时间（字段 22）
proc_word() {
  local _stat _rest; local -a _f=()
  _stat="$(cat "/proc/$1/stat" 2>/dev/null)" || return 1
  _rest="${_stat##*)}"; read -r -a _f <<< "$_rest"
  printf '%s\n' "${_f[$2]:-}"
}
now_start() { proc_word "$1" 19; }

# ── 夹具项目：一个真 git 仓库 + .pi/team/config.sh（state 就在它下面）─────────────────────────
ROOT="$TMP/repo"; STATE="$ROOT/.pi/team/state"; BGD="$STATE/bg"
mkdir -p "$ROOT" "$BGD"
( cd "$ROOT" && git init -q -b main ) >/dev/null 2>&1 || true
printf 'TEAM_PROJECT="p159-bg-stop"\n' > "$ROOT/.pi/team/config.sh"
# 兄弟 state 目录：里面也有一个 id 相同的记录 —— 本项目**不许**看见它（RA3 的边界）
OTHER="$TMP/other"; OTHER_BGD="$OTHER/.pi/team/state/bg"
mkdir -p "$OTHER_BGD"
printf 'TEAM_PROJECT="p159-other"\n' > "$OTHER/.pi/team/config.sh"

TEAM="$SKILL_DIR/scripts/team"
if [ -n "$BREAK" ]; then
  # 红侧：scripts/ 的副本 + 只改一处（每个 --break 一个断点）
  MUT="$TMP/skill"; mkdir -p "$MUT"
  cp -a "$SKILL_DIR/scripts" "$MUT/scripts"
  case "$BREAK" in
    no-identity)
      sed -i 's/^  if \[ -z "\$start" \] || \[ "\$now_start" != "\$start" \]; then$/  if false; then/' "$MUT/scripts/lib/cmd-bg.sh"
      if grep -qx '  if false; then' "$MUT/scripts/lib/cmd-bg.sh"; then
        printf '红侧：cmd-bg.sh 副本的指纹核对已改成 if false（%s）\n' "$MUT/scripts/lib/cmd-bg.sh"
      else
        printf '✗ 红侧不成立：sed 没改到指纹核对那一行\n' >&2; exit 2
      fi ;;
    no-boundary)
      # 把记录解析器短路：不再要求「平坦 id / 本项目 bg 目录里的正规文件 / realpath 仍在目录内」
      sed -i 's#^  local _id="\$1" _d="\$2" _f _dreal _freal$#  printf "%s" "$2/$1.job"; return 0#' "$MUT/scripts/lib/cmd-bg.sh"
      if grep -q 'printf "%s" "\$2/\$1.job"; return 0' "$MUT/scripts/lib/cmd-bg.sh"; then
        printf '红侧：cmd-bg.sh 副本的记录边界解析已短路（%s）\n' "$MUT/scripts/lib/cmd-bg.sh"
      else
        printf '✗ 红侧不成立：sed 没改到 team_bg_record_resolve 的第一行\n' >&2; exit 2
      fi ;;
    no-dir-boundary)
      # 把「bg 目录自身也必须在项目 state 内」短路成恒真：软链目录里的记录照常被解析、被停
      sed -i 's#^  local _d="\$1" _sreal _dreal$#  printf "%s" "$1"; return 0#' "$MUT/scripts/lib/cmd-bg.sh"
      if grep -q 'printf "%s" "\$1"; return 0' "$MUT/scripts/lib/cmd-bg.sh"; then
        printf '红侧：cmd-bg.sh 副本的 bg 目录边界检查已短路（%s）\n' "$MUT/scripts/lib/cmd-bg.sh"
      else
        printf '✗ 红侧不成立：sed 没改到 team_bg_dir_resolve 的第一行\n' >&2; exit 2
      fi ;;
  esac
  TEAM="$MUT/scripts/team"
fi

write_record() { # <id> <pid> <pgid> <start> [cmd]
  printf 'id=%s\npid=%s\npgid=%s\nstart=%s\ncwd=%s\nlog=%s\ncmd=%s\n' \
    "$1" "$2" "$3" "$4" "$ROOT" "$BGD/$1.log" "${5:-sleep 300}" > "$BGD/$1.job"
}
bg() { ( cd "$ROOT" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_STATE_DIR \
          "$TEAM" --root "$ROOT" bg "$@" ) 2>&1; }
bg_rc() { ( cd "$ROOT" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_STATE_DIR \
          "$TEAM" --root "$ROOT" bg "$@" ) >/dev/null 2>&1; printf '%s\n' "$?"; }
bg_timeout() { # <秒> <bg 参数…>：给「非正规记录不许挂住」这条腿一个硬上界
  local _t="$1"; shift
  ( cd "$ROOT" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_STATE_DIR \
      timeout "$_t" "$TEAM" --root "$ROOT" bg "$@" ) 2>&1
}

# ══════════════════════════════════════════════════════════════════════════════════════════════
hdr "RA3 · 真作业按记录停掉：job 死、邻居活、账本留痕"
JOB="job1"; CHILD_PID_FILE="$TMP/job1-child.pid"
JPID="$(spawn_group_job "$CHILD_PID_FILE")"; SPAWNED+=("$JPID")
NPID="$(spawn_neighbour)"; SPAWNED+=("$NPID")
sleep 0.3
JPGID="$(proc_word "$JPID" 2)"; JSTART="$(now_start "$JPID")"
JCHILD="$(cat "$CHILD_PID_FILE" 2>/dev/null || true)"
assert_alive "夹具前提：作业 leader 活着" "$JPID"
assert_eq "夹具前提：leader 是组头（pgid == pid）" "$JPGID" "$JPID"
assert_alive "夹具前提：组里的子孙也活着" "${JCHILD:-0}"
assert_alive "夹具前提：邻居活着" "$NPID"
write_record "$JOB" "$JPID" "$JPGID" "$JSTART" "sleep 300"
SPAWNED+=("${JCHILD:-0}")

LIST="$(bg list)"
assert_has "list 里作业行标 identity=holds" "$LIST" "identity=holds"
assert_has "list 行带 pid 与 cmd" "$LIST" "pid=$JPID"
BEFORE_LOG_LINES="$(wc -l < "$STATE/bg.log" 2>/dev/null | tr -dc '0-9' || true)"
BEFORE_LOG_LINES="${BEFORE_LOG_LINES:-0}"
OUT="$(bg stop "$JOB")"; RC=$?
assert_eq "team bg stop job1 退出 0" "$RC" "0"
assert_has "输出点名 job/signal/result" "$OUT" "signal=TERM"
assert_has "输出说 result=stopped" "$OUT" "result=stopped"
assert_has "输出点名被停的命令" "$OUT" "cmd: sleep 300"
assert_gone "作业 leader 已被停掉" "$JPID"
assert_alive "没有记录的邻居仍然活着（只停了记录里的那个）" "$NPID"
assert_has "state/bg.log 记下 stop 行（job/signal/result）" "$(cat "$STATE/bg.log" 2>/dev/null)" " stop id=$JOB signal=TERM result=stopped "
AFTER_LOG_LINES="$(wc -l < "$STATE/bg.log" 2>/dev/null | tr -dc '0-9' || true)"
AFTER_LOG_LINES="${AFTER_LOG_LINES:-0}"
assert_eq "stop 只追了 1 行账本" "$((AFTER_LOG_LINES - BEFORE_LOG_LINES))" "1"
sleep 0.3

hdr "RA3 · 无记录 → 3，什么都没发"
OUT="$(bg stop nope)"; RC=$?
assert_eq "无记录的 id 退出 3" "$RC" "3"
assert_has "理由点名 state 里的路径" "$OUT" "$BGD/nope.job"
assert_has "理由说清不按名字/进程树找" "$OUT" "不按名字/命令行/进程树找进程"
assert_alive "邻居照旧活着" "$NPID"

hdr "RA3 · 记录畸形 → 4，什么都没发"
printf 'id=bad\npid=abc\npgid=1\nstart=1\n' > "$BGD/bad.job"
OUT="$(bg stop bad)"; RC=$?
assert_eq "pid 不是数字 → 4" "$RC" "4"
assert_has "理由点名记录畸形" "$OUT" "记录畸形"
assert_alive "邻居照旧活着" "$NPID"

hdr "RA3 · pid 复用（指纹对不上）→ 5，什么都没发"
write_record reused "$NPID" "$NPID" "1" "sleep 300"
OUT="$(bg stop reused)"; RC=$?
assert_eq "指纹对不上 → 5" "$RC" "5"
assert_has "理由点名启动时间指纹" "$OUT" "启动时间指纹对不上"
assert_alive "记录里的 pid 指向的**真进程**没有被误杀" "$NPID"

hdr "RA3 · 记录只认本项目 state：兄弟目录里的 id 找不到"
OTHER_PID="$(spawn_neighbour)"; SPAWNED+=("$OTHER_PID")
printf 'id=sibling\npid=%s\npgid=%s\nstart=%s\ncwd=%s\nlog=%s\ncmd=sleep 300\n' \
  "$OTHER_PID" "$(proc_word "$OTHER_PID" 2)" "$(now_start "$OTHER_PID")" "$OTHER" "$OTHER_BGD/sibling.log" > "$OTHER_BGD/sibling.job"
OUT="$(bg stop sibling)"; RC=$?
assert_eq "兄弟 state 里的 id 在本项目 → 3" "$RC" "3"
assert_alive "兄弟记录的进程没有被本项目动到" "$OTHER_PID"
case "$(bg list)" in *sibling*) bad "list 里出现了兄弟 state 目录的作业" ;; *) ok "list 不列兄弟 state 目录的作业" ;; esac

hdr "F1 · 记录必须留在本项目里：穿越 id / 软链都拒，邻居活着"
# ① 邻居的记录 + id 里带路径（PM 的形状）：id 不是平坦名字 → 2，记录没有被解析
OUT_PID="$(spawn_neighbour)"; SPAWNED+=("$OUT_PID")
printf 'id=outside\npid=%s\npgid=%s\nstart=%s\ncwd=%s\nlog=%s\ncmd=sleep 300\n' \
  "$OUT_PID" "$(proc_word "$OUT_PID" 2)" "$(now_start "$OUT_PID")" "$OTHER" "$OTHER_BGD/outside.log" > "$OTHER_BGD/outside.job"
TRAV_ID="$(realpath --relative-to="$BGD" "$OTHER_BGD" 2>/dev/null)/outside"
case "$TRAV_ID" in */*) ok "夹具前提：穿越 id 带路径分隔符（$TRAV_ID）" ;; *) bad "夹具前提：没算出带路径的 id" ;; esac
OUT="$(bg stop "$TRAV_ID")"; RC=$?
assert_eq "① 路径穿越的 id → 2（id 没有路径语义）" "$RC" "2"
assert_has "① 诊断点名「平坦名字」" "$OUT" "平坦名字"
assert_alive "① 邻居记录没有被本项目执行（pid 活着）" "$OUT_PID"
# ② 软链记录（PM 的形状）：bg/ 里一个指向邻居记录的软链 → 4，邻居活着
LINK_PID="$(spawn_neighbour)"; SPAWNED+=("$LINK_PID")
printf 'id=linked-target\npid=%s\npgid=%s\nstart=%s\ncwd=%s\nlog=%s\ncmd=sleep 300\n' \
  "$LINK_PID" "$(proc_word "$LINK_PID" 2)" "$(now_start "$LINK_PID")" "$OTHER" "$OTHER_BGD/linked.log" > "$OTHER_BGD/linked.job"
ln -s "$OTHER_BGD/linked.job" "$BGD/linked.job"
OUT="$(bg stop linked)"; RC=$?
assert_eq "② 软链记录 → 4（不是本项目的正规文件）" "$RC" "4"
assert_has "② 诊断点名「正规记录」" "$OUT" "正规记录"
assert_alive "② 软链指向的邻居进程没有被误杀" "$LINK_PID"
LIST_SKIP="$(bg list)"
if printf '%s\n' "$LIST_SKIP" | grep -q '^linked '; then
  bad "list 列出了软链记录（越界的记录不许出现在本项目视图里）"
else
  ok "list 不列软链记录（只有跳过告警）"
fi
# ③ 反向：本项目自己的正规记录照常收（名字里带 . 与 - 也不误伤）
FLAT_JOB="job.2-fine"; FLATF="$TMP/flat-child.pid"
FPID="$(spawn_group_job "$FLATF")"; SPAWNED+=("$FPID")
sleep 0.3
write_record "$FLAT_JOB" "$FPID" "$FPID" "$(now_start "$FPID")" "sleep 300"
OUT="$(bg stop "$FLAT_JOB")"; RC=$?
assert_eq "③ 平坦名字（含 . 与 -）的正规记录照常收作业 → 0" "$RC" "0"
assert_has "③ 输出说 result=stopped" "$OUT" "result=stopped"
assert_gone "③ 作业被停掉" "$FPID"

hdr "F2 · 畸形记录一致 fail-closed：pgid=0 与 FIFO 都拒、有界"
# pgid=0（Linux 的进程组 id 必为正）：pid/start 都对，只有 pgid 畸形 → 4，零信号
write_record zero "$NPID" "0" "$(now_start "$NPID")" "sleep 300"
OUT="$(bg stop zero)"; RC=$?
assert_eq "pgid=0 → 4（pid/pgid 必须正整数）" "$RC" "4"
assert_has "诊断点名 pgid" "$OUT" "pgid"
assert_alive "记录里的真进程没有被误杀" "$NPID"
# FIFO 记录：读取之前就要拒（`-f` 且非 FIFO），不许挂住
mkfifo "$BGD/fifo.job"
OUT="$(bg_timeout 5 stop fifo)"; RC=$?
assert_eq "FIFO 记录 → 4（拒绝在读之前，rc 不是 124）" "$RC" "4"
assert_has "诊断点名「正规记录」" "$OUT" "正规记录"
case "$(bg list)" in *fifo*) bad "list 列出了 FIFO 记录" ;; *) ok "list 不列 FIFO 记录" ;; esac

hdr "F1' · bg 目录自身必须在项目内：软链目录读写两侧都拒，兄弟进程活着"
# 现场（P175 的 finding F1'）：state/bg 指到兄弟项目的 bg 目录 —— 记录解析两侧 realpath 一起落到
# 同一处，「在 bg 目录内」自洽通过。目录这一层单独收口：stop 与 list 同一条规则，都拒绝并点名目标。
SYM_PID="$(spawn_neighbour)"; SPAWNED+=("$SYM_PID")
printf 'id=symdir\npid=%s\npgid=%s\nstart=%s\ncwd=%s\nlog=%s\ncmd=sleep 300\n' \
  "$SYM_PID" "$(proc_word "$SYM_PID" 2)" "$(now_start "$SYM_PID")" "$OTHER" "$OTHER_BGD/symdir.log" > "$OTHER_BGD/symdir.job"
rm -rf "$BGD"; ln -s "$OTHER_BGD" "$BGD"
assert_eq "夹具前提：state/bg 现在是指向兄弟 bg 目录的软链" "$(readlink "$BGD")" "$OTHER_BGD"
assert_alive "夹具前提：兄弟记录里的进程活着" "$SYM_PID"
SYM_LOG_BEFORE="$(wc -l < "$STATE/bg.log" 2>/dev/null | tr -dc '0-9' || true)"; SYM_LOG_BEFORE="${SYM_LOG_BEFORE:-0}"
OUT="$(bg stop symdir)"; RC=$?
assert_eq "① 软链 bg 目录里的记录 → 4（目录自身越界）" "$RC" "4"
assert_has "① 诊断点名 state/bg 的解析目标" "$OUT" "$OTHER_BGD"
assert_alive "① 兄弟项目的真进程仍然活着（目录越界 → 什么都没发）" "$SYM_PID"
SYM_LOG_AFTER="$(wc -l < "$STATE/bg.log" 2>/dev/null | tr -dc '0-9' || true)"; SYM_LOG_AFTER="${SYM_LOG_AFTER:-0}"
assert_eq "① 拒绝没有写账本（没有 stop 行）" "$SYM_LOG_AFTER" "$SYM_LOG_BEFORE"
OUT="$(bg list)"; RC=$?
assert_eq "② bg list 同一收口 → 4（不列软链目录里的记录）" "$RC" "4"
assert_has "② list 的诊断同样点名解析目标" "$OUT" "$OTHER_BGD"
case "$OUT" in *symdir*) bad "② list 列出了软链目录里的兄弟记录" ;; *) ok "② list 不列软链目录里的记录" ;; esac
# 反向：恢复真目录 → 照常收作业（新检查不许误伤正常形态）
rm -f "$BGD"; mkdir -p "$BGD"
REV_JOB="job.3-rev"; REVF="$TMP/rev-child.pid"
RPID="$(spawn_group_job "$REVF")"; SPAWNED+=("$RPID")
sleep 0.3
write_record "$REV_JOB" "$RPID" "$RPID" "$(now_start "$RPID")" "sleep 300"
OUT="$(bg stop "$REV_JOB")"; RC=$?
assert_eq "③ 反向：真目录（非软链）照常收作业 → 0" "$RC" "0"
assert_has "③ 输出说 result=stopped" "$OUT" "result=stopped"
assert_gone "③ 作业被停掉" "$RPID"

hdr "RA3 · 已结束的 leader：rc=0，不追猎活着的子孙"
GONE_JOB="gone1"; GCPIDF="$TMP/gone1-child.pid"
GPID="$(spawn_group_job "$GCPIDF")"; SPAWNED+=("$GPID")
sleep 0.3
GCHILD="$(cat "$GCPIDF" 2>/dev/null || true)"; SPAWNED+=("${GCHILD:-0}")
write_record "$GONE_JOB" "$GPID" "$GPID" "$(now_start "$GPID")" "sleep 300"
kill -KILL "$GPID" 2>/dev/null || true; sleep 0.2
assert_gone "夹具前提：leader 已经不在了" "$GPID"
OUT="$(bg stop "$GONE_JOB")"; RC=$?
assert_eq "leader 已走 → 0（什么都没发）" "$RC" "0"
assert_has "明说子孙不会被追猎" "$OUT" "子孙不会被追猎"
assert_alive "活着的子孙留在原地（本车道不搜索进程）" "${GCHILD:-0}"
case "$(bg list)" in *"$GONE_JOB"*identity=gone*) ok "list 把这个作业标成 identity=gone" ;; *) bad "list 没有把已走 leader 标成 identity=gone" ;; esac

hdr "RA3 · 用法：没有子命令 / stop 缺 id → 2"
OUT="$(bg 2>&1)"; RC=$?
assert_eq "team bg 无子命令 → 2" "$RC" "2"
assert_has "打用法行（点名两个子命令）" "$OUT" "需要一个子命令"
assert_has "用法行里给出 list" "$OUT" "list ｜ stop"
OUT="$(bg stop)"; RC=$?
assert_eq "team bg stop 缺 id → 2" "$RC" "2"
assert_has "用法行点名 job id 从哪来" "$OUT" "team bg list 看全部"

# ══════════════════════════════════════════════════════════════════════════════════════════════
if [ -n "$BREAK" ]; then
  printf '\n== 红侧（--break=%s）==\n' "$BREAK"
  if [ "$FAIL" -gt 0 ]; then
    printf '红侧成立：%d 条断言变红 —— %s\n' "$FAIL" "$FAILED"
    case "$BREAK" in
      no-identity) printf '（跳过指纹核对后，记录里的 pid 被直接当身份：pid 复用场景不再被拒、邻居被误杀）\n' ;;
      no-boundary) printf '（短路记录边界解析后，穿越 id / 软链记录都能走到邻居的记录并停掉它）\n' ;;
      no-dir-boundary) printf '（短路 bg 目录边界检查后，软链目录里的兄弟记录被接受并真的停掉了兄弟进程）\n' ;;
    esac
    exit 1
  fi
  printf '✗ 红侧不成立：动了副本（%s）之后，夹具居然还是绿的\n' "$BREAK"
  exit 1
fi

printf '\n== team-bg-stop 结果 == ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && { printf '\033[32mteam-bg-stop 全绿\033[0m\n'; exit 0; }
printf '\033[31mteam-bg-stop 有失败项（--keep 保留现场 %s）\033[0m\n' "$TMP"
exit 1
