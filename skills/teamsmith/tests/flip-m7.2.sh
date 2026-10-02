#!/usr/bin/env bash
# M7.2 · 独立验证包：watchdog 的「启动在飞行中」误判（红）→ starting 状态（绿）
#
#   bash skills/teamsmith/tests/flip-m7.2.sh                 # 红 = 与 main 的分叉点，绿 = 当前树
#   TEAM_FLIP_BASE=<sha> bash skills/teamsmith/tests/flip-m7.2.sh
#   bash skills/teamsmith/tests/flip-m7.2.sh --probe         # 只打印两份逐拍采样表（诊断证据）
#
# 为什么需要：从 `respawn-pane` 到「拿到启动证据」之间，PM 窗口里是一个正在跑启动命令的 shell
# （项目内、非 agent，`team_pm_state` 只能报 unknown/idle）。旧实现没有「正在启动」这个状态，
# 于是**另一拍**（同一个 watchdog 窗口的下一拍、并发的 `watch --once`、人跑的 `team up`）把它当成
# 「没有 PM」再 respawn 一次：刚起来的 PM 被这一下杀掉，`pm-restarts.log` 把一次启动记成两次。
#
# 这里把这一格**确定性**地造出来，对「修复前 / 修复后」两份 skill 跑同一条命令：
#   * 假 agent = wrapper（sleep 3 再 exec 真 agent），所以启动证据（spawn 文件 / argv）要等一拍才有；
#   * 第一拍在后台跑；pane 一换进程（respawn 完成）就立刻打第二拍，落在那 ~1s 的窗口里；
#   * 旧树：第二拍又拉起一次（1 个活 PM、2 行配额、argv 里两次 @pm-prompt.md），且 pane 被换掉；
#   * 新树：第二拍报「PM 正在启动 → 不重复拉起」：不拉起、不计数、不动 pane。
#
# 只写 /tmp 下的临时目录，只动自己起的 tmux session（结束时清理）；不碰调用者所在的仓库/session。
set -uo pipefail

# 身份隔离（与 smoke 一样的坑）：绝不继承调用者的团队身份。
# 实测踩过：TEAM_MAIN_ROOT 留在调用者仓库上，夹具仓库（/tmp 下）会被判成 foreign，整场复现不动作。
unset TEAM_ROOT TEAM_MAIN_ROOT TEAM_ROOT_SOURCE TEAM_ROOT_WAS TEAM_PROJECT \
      TEAM_SESSION TEAM_SESSION_FROM TEAM_PM_WINDOW TEAM_AGENTS TEAM_DOCS_DIR \
      TEAM_WORKTREES_DIR TEAM_GATES TEAM_VCS TEAM_CONFIG_FILE TEAM_ALLOW_FOREIGN_SESSION 2>/dev/null || true

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$SELF_DIR/lib/tmp-root.sh"
# P162：破坏性调用（kill-server/kill-session/kill-window）动手前先证明私有 socket 生效
. "$SELF_DIR/lib/tmux-iso.sh"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { printf 'flip-m7.2: 找不到 git 仓库（本脚本需要 git archive 取修复前的树）\n' >&2; exit 2; }
command -v tmux >/dev/null 2>&1 || { printf 'flip-m7.2: 需要 tmux（本复现是 tmux 现场的）\n' >&2; exit 2; }

MODE="flip"
[ "${1:-}" = "--probe" ] && MODE="probe"
TRIES="${TEAM_FLIP_TRIES:-3}"

BASE="${TEAM_FLIP_BASE:-}"
if [ -z "$BASE" ]; then
  BASE="$(git -C "$REPO_ROOT" merge-base HEAD main 2>/dev/null || true)"
fi
[ -n "$BASE" ] || BASE="$(git -C "$REPO_ROOT" rev-parse --verify -q HEAD^ 2>/dev/null || true)"
[ -n "$BASE" ] || { printf 'flip-m7.2: 解析不到修复前的 revision，用 TEAM_FLIP_BASE=<sha> 指定\n' >&2; exit 2; }

[ "${KEEP:-0}" = "1" ] && export TEAM_TMP_KEEP=1
TMP="$(tmp_root_create flip-m7.2)" || exit 3
SESS_RED="teamsmith-flip-m72-red-$$"
SESS_GREEN="teamsmith-flip-m72-green-$$"

# M28：夹具自己的 tmux 调用要有隔离证据（裸 tmux 按 $TMUX 打到调用者 server —— M23 事故形状）。
# unset TMUX + 私有 TMUX_TMPDIR；工具在私有 server 的窗口里跑，继承同一套环境。口径见 tests/tmux-lint.pl。
unset TMUX TMUX_PANE 2>/dev/null || true
TMUX_TMPDIR="$TMP/tmux"; mkdir -p "$TMUX_TMPDIR"; export TMUX_TMPDIR
cleanup() {
  # P162：收尾先证明私有 socket 生效（不成立就拒绝；cleanup 里不许 exit）
  if tmux_iso_guard_soft "flip-m7.2" "收尾：私有 session" --tmpdir "${TMUX_TMPDIR:-}" --own-root "$TMP"; then
    tmux kill-session -t "$SESS_RED" 2>/dev/null || true
    tmux kill-session -t "$SESS_GREEN" 2>/dev/null || true
  fi
  if [ "${TEAM_FLIP_KEEP:-0}" = "1" ]; then printf '\n保留现场：%s\n' "$TMP"
  else tmp_root_reap_all; fi
}
trap cleanup EXIT

# 沙箱/反向守卫（M7.2 现场教训）：夹具绝不能碰真实账本。
# 事故：夹具在调用者的 cwd 里跑 `team`，TEAM_MAIN_ROOT 落回真实仓库，于是 `notify dev` 把 9 条
# 幻影待办写进真实 `docs/team/inbox/dev.md`（watchdog 因此把 PM 叫醒 9 次）。两道守卫：
#   ① 正向：每个写盘命令前先断言 `team paths` 的 main_root 就是夹具仓库（不是才允许写）；
#   ② 反向：跑前/跑后取真实仓库 inbox+state 的指纹，并搜索本轮夹具的**唯一签名**（$SLUG）——
#      出现签名 = 真泄漏（FAIL）；指纹变了但没有签名 = 真实团队自己在写（如实报告，不算本夹具的错）。
SLUG="$(basename "$TMP")"
REAL_MAIN_ROOT="$(cd "$(dirname "$(git -C "$REPO_ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)")" 2>/dev/null && pwd || printf '%s' "$REPO_ROOT")"
ledger_manifest() { # <root>：inbox/state 下的文件指纹（路径 + md5），供前/后对比
  local root="$1" d f
  for d in "$root/docs/team/inbox" "$root/.pi/team/state"; do
    [ -d "$d" ] || continue
    find "$d" -type f 2>/dev/null | sort | while IFS= read -r f; do
      printf '%s %s\n' "$f" "$(md5sum "$f" 2>/dev/null | cut -d' ' -f1)"
    done
  done
}
REAL_LEDGER_BEFORE="$TMP/real-ledger-before.txt"
ledger_manifest "$REAL_MAIN_ROOT" > "$REAL_LEDGER_BEFORE"
printf '真实账本（反向守卫）：%s（指纹 %s）\n夹具签名：%s\n' \
  "$REAL_MAIN_ROOT" "$(md5sum "$REAL_LEDGER_BEFORE" | cut -d' ' -f1)" "$SLUG"


mkdir -p "$TMP/red-skill"
git -C "$REPO_ROOT" archive "$BASE" skills/teamsmith | tar -x -C "$TMP/red-skill" || exit 2
RED_SKILL="$TMP/red-skill/skills/teamsmith"
# 守卫：传进来的 base 必须真的还是「修复前」（否则这个包会报一个假的「翻转」）
if grep -q 'team_pm_starting' "$RED_SKILL/scripts/lib/common.sh" 2>/dev/null; then
  printf 'flip-m7.2: $BASE 已经包含 M7.2 的修复（不是修复前的树）—— 用 TEAM_FLIP_BASE=<修复前的 sha> 指定\n' >&2
  exit 2
fi
printf '修复前 revision: %s（%s）\n修复后 skill:  %s\n' \
  "$BASE" "$(git -C "$REPO_ROOT" log -1 --format=%s "$BASE" 2>/dev/null)" "$SKILL_DIR"

ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
info() { printf '    %s\n' "$1"; }
FAIL=0

# ---- 夹具：一份独立仓库（每个 tag 一份，互不干扰） --------------------------------
make_fixture() { # <tag>
  local tag="$1" repo="$TMP/repo-$1" fake="$TMP/fake-$1"
  mkdir -p "$repo" "$fake"
  # 假 agent：wrapper 先报一行再睡 3s，然后 exec 真 agent（再报一行）——
  # 「启动证据」（spawn 文件 / argv）不会顷刻间就绪，「启动在飞行中」的窗口足够宽，
  # 第二拍能稳定落进去；同时 wrapper-start 的行数就是**拉起尝试次数**（不依赖 3s 后的 exec）。
  cat > "$fake/pi-slow" <<EOF
#!/usr/bin/env bash
printf 'agent-start %s\n' "\$*" >> "$TMP/pm-args-$tag.log"
sleep 600
EOF
  cat > "$fake/pi-wrapper" <<EOF
#!/usr/bin/env bash
printf 'wrapper-start %s\n' "\$*" >> "$TMP/pm-args-$tag.log"
sleep 3
exec "$fake/pi-slow" "\$@"
EOF
  chmod +x "$fake/pi-slow" "$fake/pi-wrapper"
  ( cd "$repo" || exit 2
    git init -q .; git config user.email t@t; git config user.name t
    echo hi > README.md; git add -A; git commit -qm init >/dev/null; git branch -m main
    TEAM_SESSION="$2" bash "$3/scripts/team" init --yes >/dev/null 2>&1
    sed -i "s|^TEAM_PI_BIN=.*|TEAM_PI_BIN=\"$fake/pi-wrapper\"|" .pi/team/config.sh
    if grep -q '^TEAM_AGENT_BIN=' .pi/team/config.sh; then
      sed -i "s|^TEAM_AGENT_BIN=.*|TEAM_AGENT_BIN=\"$fake/pi-slow\"|" .pi/team/config.sh
    else
      printf 'TEAM_AGENT_BIN="%s"\n' "$fake/pi-slow" >> .pi/team/config.sh
    fi ) || exit 2
  # 正向沙箱断言：配置解析必须真的落在这份夹具仓库上（否则后面任何写盘命令都是污染真账本）
  local mr
  mr="$(cd "$repo" && TEAM_SESSION="$2" bash "$3/scripts/team" paths 2>/dev/null \
        | sed -n 's/.*"main_root": "\([^"]*\)".*/\1/p')"
  if [ "$mr" != "$repo" ]; then
    printf 'flip-m7.2: 沙箱断言失败：team paths 的 main_root=%s（应为夹具 %s）—— 拒绝继续\n' "$mr" "$repo" >&2
    exit 3
  fi
  printf '沙箱 %s：main_root=%s\n' "$tag" "$mr"
  printf '%s\n' "$repo"
}

# ---- 一次现场：第一拍在后台，窗口里立刻打第二拍 --------------------------------
run_once() { # <tag> <skill-dir> <session> <attempt> → 打印 "second_started restarts starts pane_changed starting_seen sandbox"
  local tag="$1" sk="$2" sess="$3" n="$4"
  local repo="$TMP/repo-$tag" work="$TMP/run-$tag-$n"
  mkdir -p "$work"
  # 必须在夹具仓库里跑：TEAM_MAIN_ROOT 是从**调用时的 cwd** 算出来的（TEAM_ROOT 只用来找配置），
  # 从别的仓库调用会把夹具判成 foreign（实测踩过：整场复现不动作，而且写盘落到真账本）。
  cd "$repo" || exit 2
  export TEAM_ROOT="$repo" TEAM_SESSION="$sess"
  local TEAM="bash $sk/scripts/team"
  # 正向沙箱断言（写盘之前）：`team paths` 必须解析到夹具仓库，否则整轮作废、什么都不写。
  bash "$sk/scripts/team" paths > "$work/paths.json" 2>&1 || true
  local mr; mr="$(sed -n 's/.*"main_root": "\([^"]*\)".*/\1/p' "$work/paths.json" | head -1)"
  if [ "$mr" != "$repo" ]; then
    printf 'flip-m7.2: 沙箱断言失败（拒绝任何写盘）：main_root=%s，应为夹具 %s\n' "$mr" "$repo" >&2
    printf 'sandbox-fail main_root=%s\n' "$mr" >> "$TMP/sandbox-fail.log"
    printf '0 0 0 0 0 0\n'
    return 0
  fi

  tmux has-session -t "$sess" 2>/dev/null || tmux new-session -d -s "$sess" -n keep -c "$repo" >/dev/null 2>&1
  # 「PM 窗口在、里面是空提示符」的现场（pi 退出后的样子）
  tmux new-window -t "$sess" -n keep -d -c "$repo" >/dev/null 2>&1 || true
  tmux list-windows -t "$sess" -F '#{window_id} #{window_name}' 2>/dev/null \
    | awk '$2=="pm" {print $1}' \
    | while read -r wid; do [ -n "$wid" ] && { tmux_iso_require "flip-m7.2" "收掉重建的 pm 窗口" --tmpdir "${TMUX_TMPDIR:-}" --own-root "$TMP"; tmux kill-window -t "$wid" 2>/dev/null || true; }; done
  tmux new-window -t "$sess" -n pm -d -c "$repo" >/dev/null 2>&1 || true
  local i cmd=""
  for i in $(seq 1 20); do
    cmd="$(tmux display-message -p -t "$sess:pm" '#{pane_current_command}' 2>/dev/null || true)"
    case "$cmd" in zsh|bash|sh|dash|ash|ksh|fish) break ;; esac
    sleep 0.3
  done
  sleep 0.5
  rm -f "$repo/.pi/team/state/pm-restarts.log" "$repo/.pi/team/state/pm.pid" \
        "$repo/.pi/team/state/pm.pid.proof" "$repo/.pi/team/state/pm.pid.spawn" \
        "$repo/.pi/team/state/pm.pid.starting"
  $TEAM notify dev "M7.2 flip $SLUG：有待办" >/dev/null 2>&1 || true
  # 正向证据：这条待办真的落在**夹具仓库**的收件箱里（而不是别处）
  local sandbox=1
  grep -qF "M7.2 flip $SLUG" "$repo/docs/team/inbox/dev.md" 2>/dev/null || sandbox=0
  # 逐拍采样（诊断证据；每 0.2s 记一行）
  local samples="$work/samples.csv" stop="$work/stop"
  ( . "$sk/scripts/lib/common.sh"; team_load_config >/dev/null 2>&1
    t="$(team_pm_target)"
    : > "$samples"
    while [ ! -f "$stop" ]; do
      ts="$(date +%s.%N)"; st="$(team_pm_state)"
      al=0; team_pm_alive && al=1
      bs=0; team_pane_busy "$t" && bs=1
      c="$(team_pane_cmd "$t")"
      pp="$(tmux display-message -p -t "$t" '#{pane_pid}' 2>/dev/null || true)"
      rp="$(team_pm_recorded_pid 2>/dev/null || echo -)"; rk="-"; rc="-"
      if [ "$rp" != "-" ]; then
        kill -0 "$rp" 2>/dev/null && rk=1 || rk=0
        rc="$(team_proc_cwd "$rp" 2>/dev/null || echo '?')"
      fi
      sp="$(team_pm_spawn_pid 2>/dev/null || echo -)"
      mk=0; [ -f "$repo/.pi/team/state/pm.pid.starting" ] && mk=1
      printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
        "$ts" "$st" "$al" "$bs" "$c" "$pp" "$rp" "$rk" "$rc" "$sp" "$mk" >> "$samples"
      sleep 0.2
    done ) &
  local SAMPLER=$!
  sleep 0.3

  local pre mid post wrapper_before
  wrapper_before="$(grep -c '^wrapper-start' "$TMP/pm-args-$tag.log" 2>/dev/null || true)"
  pre="$(tmux display-message -p -t "$sess:pm" '#{pane_pid}' 2>/dev/null || true)"
  $TEAM watch --once >"$work/tick1.log" 2>&1 &
  local TICK1=$!
  # 等「启动在飞行中」的证据出现：新树是标记文件，旧树只有 pane 换进程
  i=0
  while [ "$i" -lt 60 ]; do
    [ -f "$repo/.pi/team/state/pm.pid.starting" ] && break
    [ "$(tmux display-message -p -t "$sess:pm" '#{pane_pid}' 2>/dev/null || true)" != "$pre" ] && break
    sleep 0.05; i=$((i + 1))
  done
  mid="$(tmux display-message -p -t "$sess:pm" '#{pane_pid}' 2>/dev/null || true)"
  $TEAM watch --once >"$work/tick2.log" 2>&1 || true
  wait "$TICK1" 2>/dev/null || true
  sleep 1
  post="$(tmux display-message -p -t "$sess:pm" '#{pane_pid}' 2>/dev/null || true)"
  touch "$stop"; wait "$SAMPLER" 2>/dev/null || true

  local second_started restarts starts pane_changed starting_seen wrapper_after
  second_started="$(grep -c '已拉起' "$work/tick2.log" 2>/dev/null || true)"
  starting_seen="$(grep -c 'PM 正在启动' "$work/tick2.log" 2>/dev/null || true)"
  restarts="$(cat "$repo/.pi/team/state/pm-restarts.log" 2>/dev/null | wc -l | tr -d ' ')"
  wrapper_after="$(grep -c '^wrapper-start' "$TMP/pm-args-$tag.log" 2>/dev/null || true)"
  starts=$(( ${wrapper_after:-0} - ${wrapper_before:-0} ))
  if [ "$post" != "$mid" ]; then pane_changed=1; else pane_changed=0; fi
  printf '%s %s %s %s %s %s\n' "${second_started:-0}" "${restarts:-0}" "${starts:-0}" "$pane_changed" "${starting_seen:-0}" "$sandbox"
}

show_changes() { # <csv>：只打印状态发生变化的那几拍（报告用的紧凑表）
  awk -F'|' 'NR==1 || ($2"|"$3"|"$4"|"$5"|"$7"|"$10"|"$11)!=prev {
      printf "  %-17s | %-16s | %-5s %-4s | %-9s | rec=%-7s | spawn=%-9s | mark=%s\n", $1, $2, $3, $4, $5, $7, $10, $11
      prev=$2"|"$3"|"$4"|"$5"|"$7"|"$10"|"$11 }' "$2"
}

red_repro=0; green_viol=0; sandbox_bad=0
make_fixture red "$SESS_RED" "$RED_SKILL" || exit 3
make_fixture green "$SESS_GREEN" "$SKILL_DIR" || exit 3
printf '\n== 场景：第一拍启动中，第二拍在同一秒里到达 ==\n'
for n in $(seq 1 "$TRIES"); do
  R="$(run_once red "$RED_SKILL" "$SESS_RED" "$n")"
  G="$(run_once green "$SKILL_DIR" "$SESS_GREEN" "$n")"
  set -- $R;  R_2ND="$1"; R_RST="$2"; R_START="$3"; R_PANE="$4"; R_STARTING="$5"; R_SB="${6:-0}"
  set -- $G;  G_2ND="$1"; G_RST="$2"; G_START="$3"; G_PANE="$4"; G_STARTING="$5"; G_SB="${6:-0}"
  printf '  第 %s 轮：修复前 { 第二拍已拉起=%s 配额行=%s 启动次数=%s pane被换=%s 正在启动=%s 沙箱=%s } ｜ 修复后 { 第二拍已拉起=%s 配额行=%s 启动次数=%s pane被换=%s 正在启动=%s 沙箱=%s }\n' \
    "$n" "$R_2ND" "$R_RST" "$R_START" "$R_PANE" "$R_STARTING" "$R_SB" \
    "$G_2ND" "$G_RST" "$G_START" "$G_PANE" "$G_STARTING" "$G_SB"
  [ "$R_2ND" -ge 1 ] && red_repro=$((red_repro + 1))
  if [ "$G_2ND" -ge 1 ] || [ "$G_RST" != "1" ] || [ "$G_START" != "1" ] || [ "$G_PANE" != "0" ] || [ "$G_SB" != "1" ]; then
    green_viol=$((green_viol + 1))
  fi
  [ "$R_SB" = "1" ] || sandbox_bad=$((sandbox_bad + 1))
  if [ "$MODE" = "probe" ]; then
    show_changes "$R" "$TMP/run-red-$n/samples.csv"
    printf '  修复前 tick2：%s\n' "$(grep -E '已拉起|已提醒|正在启动' "$TMP/run-red-$n/tick2.log" | head -1 | sed 's/^[[:space:]]*//')"
    show_changes x "$TMP/run-green-$n/samples.csv"
    printf '  修复后 tick2：%s\n' "$(grep -E '已拉起|已提醒|正在启动' "$TMP/run-green-$n/tick2.log" | head -1 | sed 's/^[[:space:]]*//')"
  fi
done

# ---- 反向守卫：真实账本没被夹具碰过 ----------------------------------------------
REAL_LEDGER_AFTER="$TMP/real-ledger-after.txt"
ledger_manifest "$REAL_MAIN_ROOT" > "$REAL_LEDGER_AFTER"
REAL_BEFORE_FP="$(md5sum "$REAL_LEDGER_BEFORE" | cut -d' ' -f1)"
REAL_AFTER_FP="$(md5sum "$REAL_LEDGER_AFTER" | cut -d' ' -f1)"
REAL_LEAK_HITS="$(grep -rlF "$SLUG" "$REAL_MAIN_ROOT/docs/team/inbox" "$REAL_MAIN_ROOT/.pi/team/state" 2>/dev/null | head -3 || true)"
REAL_LEDGER_DIFF="$(diff "$REAL_LEDGER_BEFORE" "$REAL_LEDGER_AFTER" 2>/dev/null || true)"

printf '\n== 判定 ==\n'
info "沙箱：team paths 的 main_root（见各轮 run-*/paths.json）必须等于 /tmp 下的夹具仓库"
if [ "$sandbox_bad" -eq 0 ] && [ ! -s "$TMP/sandbox-fail.log" ]; then
  ok "正向断言：$((TRIES * 2)) 次现场全部在夹具仓库里跑（main_root = /tmp/teamsmith-flip-m7.2.*，每次写入前都验过）"
else
  bad "正向断言失败：$sandbox_bad 轮没有落在夹具仓库（见 $TMP/sandbox-fail.log）"
fi
if [ -n "$REAL_LEAK_HITS" ]; then
  bad "反向守卫：夹具的签名（$SLUG）出现在真实账本里：$REAL_LEAK_HITS"
else
  ok "反向守卫：真实账本（$REAL_MAIN_ROOT）里搜不到本轮夹具签名 $SLUG"
fi
if [ "$REAL_BEFORE_FP" = "$REAL_AFTER_FP" ]; then
  ok "反向守卫：真实账本 inbox+state 一个字节没变（指纹 $REAL_AFTER_FP）"
else
  info "反向守卫：真实账本在跑动期间有别的写入（指纹 $REAL_BEFORE_FP → $REAL_AFTER_FP，无夹具签名）"
  printf '%s\n' "$REAL_LEDGER_DIFF" | sed 's/^/    /' | head -12
fi
info "隔离证据：$(cat "$TMP/run-green-1/paths.json" 2>/dev/null | head -1)"
info "真实 inbox 指纹：$(md5sum "$REAL_MAIN_ROOT/docs/team/inbox"/*.md 2>/dev/null | md5sum | cut -d' ' -f1)"

if [ "$MODE" = "probe" ]; then
  printf '  （--probe：只打印诊断表，不做翻转判定）\n'
  exit 0
fi
if [ "$red_repro" -ge 1 ]; then
  ok "修复前：$red_repro/$TRIES 轮复现「第二拍又拉起一次」（刚起来的 PM 被杀、配额记两次）"
else
  bad "修复前：$TRIES 轮都没复现（夹具没造出那一格）"
fi
if [ "$green_viol" -eq 0 ]; then
  ok "修复后：$TRIES 轮第二拍都报「PM 正在启动」——不重复拉起、不计数、不动 pane"
else
  bad "修复后：$green_viol/$TRIES 轮仍然重复拉起/多计数/pane 被换"
fi
printf '\n'
[ "$FAIL" -eq 0 ] && { printf '\033[32mflip-m7.2：翻转已复现（红 → 绿）\033[0m\n'; exit 0; }
printf '\033[31mflip-m7.2：没有观察到预期的翻转（%d 条失败）\033[0m\n' "$FAIL"
exit 1
